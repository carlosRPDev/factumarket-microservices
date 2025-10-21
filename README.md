# 🧾 Prueba Técnica — Implementación de Microservicios para Facturación Electrónica

Este proyecto corresponde a la **implementación de una arquitectura de microservicios** para un sistema de facturación electrónica, aplicando principios de **Clean Architecture**, **MVC**, y comunicación entre servicios mediante **HTTP y Jobs asíncronos (Sidekiq + Redis)**.

Cada microservicio está desarrollado en **Ruby on Rails 8.0.3**, con bases de datos **Oracle** (para `clients_service` e `invoices_service`) y **MongoDB** (para `audit_service`).

---

## 🧱 Estructura general del proyecto

```bash
factumarket-microservices/
├── audit_service/
├── clients_service/
├── invoices_service/
├── oracle_init/
│   └── create_users.sql
├── docker-compose.yml
├── .env
└── README.md
```

- **audit_service/** → Maneja los eventos de auditoría en MongoDB.
- **clients_service/** → Administra la creación y gestión de clientes.
- **invoices_service/** → Gestiona la emisión de facturas y registra auditorías.
- **oracle_init/** → Contiene el script SQL para crear los usuarios en Oracle.
- **docker-compose.yml** → Orquesta todos los servicios (Oracle, Redis, Mongo, microservicios y Sidekiq).
- **.env** → Define las variables de entorno globales del sistema.

---

## ⚙️ Requisitos previos

- Docker ≥ 24.x
- Docker Compose ≥ 2.x
- Git ≥ 2.30
- Ruby ≥ 3.2.8 (solo si deseas correr servicios fuera de contenedores)

---

## 🚀 Instalación y ejecución

### 1️⃣ Clonar el repositorio

```bash
git clone --recurse-submodules git@github.com:carlosRPDev/factumarket-microservices.git
cd factumarket-microservices
```

> ⚠️ Este proyecto utiliza **submódulos Git**, por lo que el flag `--recurse-submodules` es necesario.

### 2️⃣ Crear archivo `.env` (ya incluido)

El archivo `.env` contiene las variables necesarias para los contenedores, incluyendo Oracle, Redis, MongoDB y URLs de los servicios.

Ejemplo:

```bash
DATABASE_HOST=oracle
ORACLE_PASSWORD=oracle
ORACLE_USER=system
ORACLE_USER_CLIENTS=clients_user
ORACLE_PASSWORD_CLIENTS=clients_123
ORACLE_USER_INVOICES=invoices_user
ORACLE_PASSWORD_INVOICES=invoices_123
CLIENTS_URL=http://clients:3000
INVOICES_URL=http://invoices:3001
AUDIT_URL=http://audit:3002
MONGODB_URL=mongodb://mongo:27017/audit_db
REDIS_URL=redis://redis:6379/0
```

### 3️⃣ Levantar el entorno completo

```bash
docker-compose up --build
```

Esto iniciará los siguientes servicios:

- **Oracle XE 18c**
- **Redis 7**
- **MongoDB 6**
- **clients_service (Rails API + Sidekiq)**
- **invoices_service (Rails API + Sidekiq)**
- **audit_service (Rails API)**

Una vez iniciados:

### 4️⃣ Correr las migraciones

```bash
docker compose exec invoices rails db:migrate
docker compose exec clients rails db:migrate 
```

URLs bases:

- **Clients API** → <http://localhost:3000>
- **Invoices API** → <http://localhost:3001>
- **Audit API** → <http://localhost:3002>

---

## 🧩 Principios de Diseño Aplicados

### 🧠 Clean Architecture

- Separación entre **lógica de negocio**, **infraestructura** y **framework**.
- Independencia de frameworks y bases de datos.
- Comunicación entre capas mediante interfaces bien definidas.

### 🏗️ MVC (Model-View-Controller)

- Los controladores exponen endpoints REST.
- Los modelos representan entidades persistentes (clientes, facturas, auditorías).
- Las vistas se utilizan para layouts básicos o respuestas de correo (mailer).

### 🌐 Microservicios

- Cada servicio se despliega de forma **independiente**.
- Comunicación entre servicios mediante **HTTP (HTTParty)**.
- Uso de **Jobs en background** para registrar eventos en el servicio de auditoría (`register_event_audit_job`).
- Bases de datos **autónomas** y **desacopladas** (Oracle / MongoDB)

---

## 🧠 Aplicación de Clean Architecture y MVC

Cada microservicio mantiene una estructura modular separada en capas:

| Capa                  | Descripción                                      | Ejemplo (`invoices_service`)                                   |
| --------------------- | ------------------------------------------------ | -------------------------------------------------------------- |
| **Domain**            | Define entidades puras del dominio               | `domain/entities/invoice.rb`                                   |
| **Application**       | Casos de uso y lógica de negocio                 | `application/use_cases/create_invoice.rb`                      |
| **Infrastructure**    | Conexión a bases de datos y servicios externos   | `infrastructure/repositories/oracle_invoice_repository.rb`     |
| **Controllers (API)** | Exposición de endpoints HTTP                     | `controllers/api/v1/invoices_controller.rb`                    |
| **Jobs / Services**   | Procesamiento asíncrono y conexión con auditoría | `jobs/register_event_audit_job.rb`, `services/audit_client.rb` |

---

## 🧾 Endpoints principales

| Servicio             | Endpoint                                                      | Método | Descripción                        |
| -------------------- | ------------------------------------------------------------- | ------ | ---------------------------------- |
| **Clients Service**  | `/api/v1/clients`                                             | GET    | Lista todos los clientes           |
| **Clients Service**  | `/api/v1/clients`                                             | POST   | Crea un nuevo cliente              |
| **Clients Service**  | `/api/v1/clients/:id`                                         | GET    | Obtiene un cliente por ID          |
| **Clients Service**  | `/api/v1/clients/:id`                                         | DELETE | Elimina un cliente                 |
| **Invoices Service** | `/api/v1/invoices`                                            | POST   | Crea una nueva factura             |
| **Invoices Service** | `/api/v1/invoices/:id`                                        | GET    | Consulta una factura               |
| **Invoices Service** | `/api/v1/invoices?fechaInicio=2025-10-01&fechaFin=2025-10-30` | GET    | Lista facturas por rango de fechas |
| **Audit Service**    | `/api/v1/audit/events`                                        | POST   | Registra un evento de auditoría    |
| **Audit Service**    | `/api/v1/audit/:id`                                           | GET    | Consulta un evento de auditoría    |

---

## 🧮 Ejemplo de flujo end-to-end

### 1️⃣ Crear cliente

```bash
curl -X POST http://localhost:3000/api/v1/clients \
  -H "Content-Type: application/json" \
  -d '{"name":"Carlos","email":"carlos@test.com"}'
```

### 2️⃣ Crear factura

```bash
curl -X POST http://localhost:3001/api/v1/invoices \
  -H "Content-Type: application/json" \
  -d '{"client_id":1,"total":2500,"issued_at":"2025-10-18"}'
```

### 3️⃣ Consultar registro de auditoría

```bash
curl -X GET http://localhost:3002/api/v1/audit/events
```

Cada evento queda registrado automáticamente mediante **Sidekiq**, enviando el log correspondiente al `audit_service`.

---

## 🧰 Inicialización de base de datos Oracle

El archivo `oracle_init/create_users.sql` se ejecuta automáticamente al levantar los contenedores.
Crea los usuarios y permisos necesarios para los microservicios:

```sql
CREATE USER clients_user IDENTIFIED BY clients_123;
CREATE USER invoices_user IDENTIFIED BY invoices_123;
GRANT CONNECT, RESOURCE, CREATE SESSION, CREATE TABLE, CREATE VIEW, CREATE SEQUENCE, CREATE TRIGGER TO clients_user;
GRANT CONNECT, RESOURCE, CREATE SESSION, CREATE TABLE, CREATE VIEW, CREATE SEQUENCE, CREATE TRIGGER TO invoices_user;
```

Si se desea ejecutar manualmente:

```bash
docker exec -it oracle sqlplus system/oracle@//localhost:1521/XE @/container-entrypoint-initdb.d/create_users.sql
```

---

## 🧪 Pruebas unitarias

Cada microservicio incluye **RSpec** para pruebas unitarias en la capa de dominio.

Ejemplo de ejecución:

```bash
docker exec -it clients bundle exec rspec
docker exec -it invoices bundle exec rspec
docker exec -it audit bundle exec rspec
```

Las pruebas cubren las entidades, casos de uso y validaciones de negocio.

---

## ⚠️ Manejo de errores y respuestas HTTP

Cada microservicio incluye un módulo `ApiResponder` que unifica las respuestas en formato JSON:

```ruby
render_success(data:, status: :ok)
render_error(message:, status: :unprocessable_entity)
render_not_found(resource)
```

Además, los `ApplicationController` manejan excepciones comunes como:

- `ActiveRecord::RecordNotFound`
- `StandardError`
- Validaciones de dominio

---

## 🧩 Componentes asíncronos

- **Redis** → Cola de mensajes central.
- **Sidekiq** → Ejecución de Jobs (como `RegisterEventAuditJob`).
- **AuditService** → Procesa y guarda auditorías en MongoDB.

Cada microservicio tiene su propio proceso de Sidekiq definido en `docker-compose.yml`:

- `clients_sidekiq`
- `invoices_sidekiq`

---

## 📄 Licencia

Proyecto desarrollado como parte de una **prueba técnica profesional**.
Uso educativo y demostrativo.

---

**Autor**: Carlos Rodríguez
**Fecha**: Octubre 2025
**Versión Ruby**: 3.2.8
**Versión Rails**: 8.0.3
