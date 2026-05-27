-- ============================================================
-- SQL Server 2022 — Sucursal Capital (Ventas)
-- TecnoChapina S.A.
-- Ejecutar como sa
-- ============================================================

-- 1. Base de datos
CREATE DATABASE ventas_db;
GO

USE ventas_db;
GO

-- 2. Login a nivel de servidor (acceso al motor)
CREATE LOGIN usr_ventas WITH PASSWORD = 'VentasPass123!';
GO

-- 3. Usuario dentro de ventas_db (mapea el login a la base de datos)
CREATE USER usr_ventas FOR LOGIN usr_ventas;
GO

-- 4. Rol con permisos de operación sobre el esquema dbo
CREATE ROLE rol_ventas;
GO

GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::dbo TO rol_ventas;
GO

ALTER ROLE rol_ventas ADD MEMBER usr_ventas;
GO

-- ============================================================
-- 5. Tablas
-- ============================================================

CREATE TABLE clientes (
  id_cliente  INT IDENTITY(1,1) PRIMARY KEY,
  nombre      VARCHAR(100) NOT NULL,
  apellido    VARCHAR(100) NOT NULL,
  email       VARCHAR(150),
  telefono    VARCHAR(20),
  direccion   VARCHAR(250),
  nit         VARCHAR(20)
);
GO

CREATE TABLE ventas (
  id_venta    INT IDENTITY(1,1) PRIMARY KEY,
  id_cliente  INT          NOT NULL REFERENCES clientes(id_cliente),
  id_empleado INT,                        -- Ref. lógica → Oracle.empleados
  fecha_venta DATETIME2    DEFAULT GETDATE(),
  total       DECIMAL(12,2),
  sucursal_id INT,                        -- 1=Capital | 2=Occidente (fragmentación horizontal)
  estado      VARCHAR(20)  DEFAULT 'completada'
);
GO

-- Documentar las referencias lógicas como propiedades extendidas
EXEC sp_addextendedproperty
  @name       = N'MS_Description',
  @value      = N'Referencia lógica a Oracle.empleados — sin FK real por ser cross-motor',
  @level0type = N'SCHEMA', @level0name = N'dbo',
  @level1type = N'TABLE',  @level1name = N'ventas',
  @level2type = N'COLUMN', @level2name = N'id_empleado';
GO

EXEC sp_addextendedproperty
  @name       = N'MS_Description',
  @value      = N'1=Capital | 2=Occidente — fragmentación horizontal de ventas por sucursal',
  @level0type = N'SCHEMA', @level0name = N'dbo',
  @level1type = N'TABLE',  @level1name = N'ventas',
  @level2type = N'COLUMN', @level2name = N'sucursal_id';
GO

CREATE TABLE detalle_ventas (
  id_detalle      INT IDENTITY(1,1) PRIMARY KEY,
  id_venta        INT          NOT NULL REFERENCES ventas(id_venta),
  id_producto     INT,                    -- Ref. lógica → PostgreSQL.productos
  cantidad        INT,
  precio_unitario DECIMAL(10,2),
  subtotal        DECIMAL(12,2)
);
GO

EXEC sp_addextendedproperty
  @name       = N'MS_Description',
  @value      = N'Referencia lógica a PostgreSQL.productos — sin FK real por ser cross-motor',
  @level0type = N'SCHEMA', @level0name = N'dbo',
  @level1type = N'TABLE',  @level1name = N'detalle_ventas',
  @level2type = N'COLUMN', @level2name = N'id_producto';
GO
