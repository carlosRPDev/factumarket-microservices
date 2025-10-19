-- Crear usuario y base de datos para clients_service
CREATE USER clients_user IDENTIFIED BY clients_123;

GRANT CONNECT,
RESOURCE,
CREATE SESSION,
CREATE TABLE,
CREATE VIEW,
CREATE SEQUENCE,
CREATE TRIGGER TO clients_user;

ALTER USER clients_user QUOTA UNLIMITED ON USERS;

-- Crear usuario y base de datos para invoices_service
CREATE USER invoices_user IDENTIFIED BY invoices_123;

GRANT CONNECT,
RESOURCE,
CREATE SESSION,
CREATE TABLE,
CREATE VIEW,
CREATE SEQUENCE,
CREATE TRIGGER TO invoices_user;

ALTER USER invoices_user QUOTA UNLIMITED ON USERS;

-- Confirmar
SELECT username
FROM all_users
WHERE
    username IN (
        'CLIENTS_USER',
        'INVOICES_USER'
    );