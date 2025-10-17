# Parte 1 – Diseño de Arquitectura (Teórico–Práctico)

## 1. Definición de Microservicios Principales

El sistema se compondrá de tres microservicios independientes, cada uno con su propia base de datos y lógica de negocio.

| Microservicio        | Responsabilidad Principal                       | Base de Datos      | Lenguaje Sugerido   |
|---------------------|------------------------------------------------|------------------|------------------|
| **Clientes Service** | Registro, actualización y consulta de clientes.| Oracle           | Ruby on Rails     |
| **Facturas Service** | Creación y gestión de facturas electrónicas.   | Oracle           | Ruby on Rails     |
| **Auditoría Service**| Registro de eventos del sistema (creaciones, consultas, errores). | MongoDB (NoSQL) | Ruby on Rails |

Cada servicio puede escalarse, desplegarse y versionarse de manera independiente.

---

## 2. Responsabilidad e Interacción entre Microservicios

### 🔹 Servicio de Clientes

- Registra y mantiene la información de los clientes.
- Expone endpoints REST para registrar y consultar clientes.
- Cada acción genera un evento de auditoría (por ejemplo: “Cliente creado”).
- Comunica estos eventos al servicio de Auditoría (vía ActiveJob + Sidekiq + Redis).

### 🔹 Servicio de Facturas

- Se encarga de emitir facturas electrónicas.
- Valida la existencia del cliente mediante una llamada REST al Servicio de Clientes.
- Al crear o consultar una factura, genera también un evento de auditoría.
- Almacena las facturas en Oracle.

### 🔹 Servicio de Auditoría

- Recibe y guarda los eventos provenientes de los otros microservicios.
- Los eventos se almacenan en MongoDB para permitir búsquedas rápidas.
- Permite consultar los eventos por ID de factura o cliente.

---

## 3. Flujo de Comunicación entre Servicios

### 🔹 Tipo de Comunicación

El sistema utilizará una combinación de **comunicación síncrona y asíncrona**, según la naturaleza de las operaciones:

#### 1. Comunicación Síncrona (REST HTTP)

- Se utiliza para las operaciones que requieren una respuesta inmediata.
- Ejemplo:  
  El servicio de **Facturas** valida la existencia de un cliente consultando al servicio de **Clientes** mediante un `GET /clientes/{id}` antes de emitir una factura.

#### 2. Comunicación Asíncrona (Eventos / Colas)

- Se utiliza para el **registro de auditoría** y otras operaciones que no necesitan respuesta inmediata.
- Cada vez que se crea, consulta o actualiza un cliente o factura, se genera un evento que se envía al microservicio de **Auditoría** de manera asíncrona.

### 🔹 Implementación propuesta: ActiveJob + Sidekiq + Redis

Para la comunicación asíncrona entre servicios (por ejemplo, “Cliente creado”, “Factura emitida”, “Error de validación”), se implementará una **cola interna de procesamiento** utilizando:

- **ActiveJob**: interfaz nativa de Rails para encolar tareas.
- **Sidekiq**: manejador de *background jobs* basado en hilos.
- **Redis**: almacén de datos en memoria que actúa como *message broker*.

Esto permite que los microservicios envíen los eventos a la cola sin bloquear la operación principal, y Sidekiq los procese posteriormente enviando el evento al microservicio de Auditoría mediante una llamada HTTP.

### 🔹 Ejemplo de Flujo Asíncrono

1. El servicio de **Facturas** crea una nueva factura en Oracle.
2. Una vez creada, se encola un *job* (`RegistrarEventoAuditoriaJob`) con los datos del evento.
3. Sidekiq procesa el *job* en segundo plano.
4. El *job* realiza una llamada HTTP (`POST /auditoria/eventos`) al servicio de **Auditoría** enviando el evento en formato JSON.

El servicio de Auditoría almacena el evento en MongoDB.

### 🔹 Ejemplo de estructura del evento enviado

```json
{
  "timestamp": "2025-10-16T12:00:00Z",
  "servicio_origen": "facturas",
  "accion": "CREAR_FACTURA",
  "detalle": {
    "factura_id": 103,
    "cliente_id": 45,
    "monto": 2500.00
  },
  "estado": "OK"
}
```

### 🔹 Ventajas de esta implementación

- **Asincronía real**: evita bloquear el flujo de negocio principal.
- **Simplicidad**: utiliza herramientas nativas de Rails (ActiveJob) con mínima configuración adicional.
- **Escalabilidad**: Sidekiq puede ejecutarse con múltiples workers.
- **Resiliencia**: Redis almacena los jobs hasta que sean procesados, evitando pérdida de eventos si el servicio de Auditoría está temporalmente fuera de línea.
- **Fácil mantenimiento**: no requiere infraestructura compleja como Kafka o RabbitMQ.

### 🔹 Consideraciones de consistencia

- Se adopta un modelo de **consistencia eventual**:
las transacciones principales (Clientes y Facturas) se confirman en Oracle inmediatamente, mientras que los eventos de auditoría pueden registrarse unos segundos después.
- Si el microservicio de Auditoría no está disponible, Sidekiq reintentará automáticamente el envío del evento hasta que sea exitoso.

### 🔹 Resumen del flujo

| Tipo de Comunicación      | Servicios Involucrados          | Tecnología                  | Propósito                      |
| ------------------------- | ------------------------------- | --------------------------- | ------------------------------ |
| Síncrona (REST)           | Facturas → Clientes             | HTTP REST                   | Validar existencia del cliente |
| Asíncrona (Colas/Eventos) | Clientes / Facturas → Auditoría | ActiveJob + Sidekiq + Redis | Registrar eventos en MongoDB   |

### 🔹 Diagrama de Flujo Simplificado

```text
        ┌──────────────┐
        │   Clientes   │
        │ (Oracle DB)  │
        └─────┬────────┘
              │   (Evento asíncrono)
              ▼
        ┌──────────────┐
        │   Sidekiq    │──► POST /auditoria/eventos
        │   (Redis)    │
        └─────┬────────┘
              │
        ┌──────────────┐
        │  Auditoría   │
        │ (MongoDB)    │
        └──────────────┘
```

## 4. Estrategia de Persistencia

| Tipo de Dato / Evento | Base de Datos | Descripción                             |
| --------------------- | ------------- | --------------------------------------- |
| Clientes              | Oracle        | Información transaccional               |
| Facturas              | Oracle        | Facturas emitidas y su estado           |
| Auditoría             | MongoDB       | Logs de operaciones, errores y acciones |

Ejemplo de documento en MongoDB:

```json
  {
  "timestamp": "2025-10-16T12:00:00Z",
  "servicio_origen": "facturas",
  "accion": "CREAR_FACTURA",
  "detalle": {
    "factura_id": 105,
    "cliente_id": 12,
    "monto": 2500.00
  },
  "estado": "OK"
}
```

## 5. Aplicación de Principios Arquitectónicos

### 🔹 Microservicios

- Cada servicio es **independiente, desplegable individualmente y autónomo**.
- Comunicación vía HTTP (REST) o colas.
- Cada uno tiene su **propia base de datos** (evitando acoplamiento).

### 🔹 Clean Architecture

Cada servicio se organiza en capas bien definidas:

```bash
  app/
  ├── controllers/        # Interfaz con el mundo exterior (API REST)
  ├── services/ (o use_cases/)  # Casos de uso del dominio (lógica de negocio)
  ├── models/             # Entidades y reglas de dominio
  ├── repositories/       # Interfaces para persistencia (Oracle o Mongo)
  └── infrastructure/     # Adaptadores de base de datos, HTTP clients, etc.
```

- **Dominio**: contiene las entidades puras (`Cliente`, `Factura`, `EventoAuditoria`).
- **Aplicación (use_cases)**: orquesta los casos de uso (crear cliente, emitir factura).
- **Infraestructura**: implementa persistencia y adaptadores externos.
- **Interfaces (controllers)**: exponen endpoints REST (MVC).

### 🔹 MVC en la capa de exposición

- **Model**: representa las entidades principales (`Cliente`, `Factura`).
- **View**: en este contexto, responde con JSON (no vistas HTML).
- **Controller**: expone endpoints y delega la lógica al dominio.

## 6. Diagrama de Alto Nivel

```text
                ┌────────────────────────────┐
                │        API Gateway         │
                └────────────┬───────────────┘
                             │
          ┌──────────────────┼──────────────────┐
          │                  │                  │
┌────────────────┐   ┌────────────────┐   ┌────────────────┐
│ Servicio de    │   │ Servicio de    │   │ Servicio de    │
│   Clientes     │   │   Facturas     │   │   Auditoría    │
│----------------│   │----------------│   │----------------│
│ REST /clientes │   │ REST /facturas │   │ REST /auditoria│
│ Oracle DB      │   │ Oracle DB      │   │ MongoDB        │
└────────────────┘   └────────────────┘   └────────────────┘
        │                   │                   ▲
        │                   └───────► Enviar eventos (ActiveJob + Sidekiq + Redis)
        │                                       │
        └───────────────────────────────────────┘

```
