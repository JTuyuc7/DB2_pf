-- ============================================================
-- PostgreSQL 16 — Sucursal Occidente (Inventario)
-- TecnoChapina S.A.
-- Ejecutar como admin_inventario
-- ============================================================

-- 1. Esquema dedicado (separa las tablas del esquema public por defecto)
CREATE SCHEMA IF NOT EXISTS inventario;

-- 2. Rol con permisos sobre el esquema
CREATE ROLE rol_inventario;

GRANT USAGE  ON SCHEMA inventario TO rol_inventario;
GRANT CREATE ON SCHEMA inventario TO rol_inventario;
GRANT ALL PRIVILEGES ON ALL TABLES    IN SCHEMA inventario TO rol_inventario;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA inventario TO rol_inventario;

-- Permisos para objetos futuros (tablas que se creen después)
ALTER DEFAULT PRIVILEGES IN SCHEMA inventario
  GRANT ALL ON TABLES    TO rol_inventario;
ALTER DEFAULT PRIVILEGES IN SCHEMA inventario
  GRANT ALL ON SEQUENCES TO rol_inventario;

-- Asignar el rol al usuario que ya existe
GRANT rol_inventario TO admin_inventario;

-- ============================================================
-- 3. Tablas en el esquema inventario
-- ============================================================

CREATE TABLE inventario.categorias (
  id_categoria  SERIAL PRIMARY KEY,
  nombre        VARCHAR(80)  NOT NULL,
  descripcion   VARCHAR(300)
);

-- ----

CREATE TABLE inventario.productos (
  id_producto     SERIAL PRIMARY KEY,
  nombre          VARCHAR(150) NOT NULL,
  descripcion     VARCHAR(500),
  precio_unitario DECIMAL(10,2),
  id_categoria    INTEGER NOT NULL REFERENCES inventario.categorias(id_categoria),
  id_proveedor    INTEGER  -- Ref. lógica → Oracle.proveedores (sin FK real: cross-motor)
);

COMMENT ON COLUMN inventario.productos.id_proveedor
  IS 'Referencia lógica a Oracle.proveedores — la integridad la mantiene la aplicación Python';

-- ----

CREATE TABLE inventario.inventario (
  id_inventario       SERIAL PRIMARY KEY,
  id_producto         INTEGER NOT NULL REFERENCES inventario.productos(id_producto),
  bodega              VARCHAR(60),
  cantidad_disponible INTEGER   DEFAULT 0,
  fecha_actualizacion TIMESTAMP DEFAULT NOW()
);
