-- ============================================================
-- PostgreSQL 16 — Fragmento de ventas: Sucursal Occidente
-- TecnoChapina S.A.
-- Ejecutar como admin_inventario, en inventario_db
-- Fragmento físico: sucursal_id = 2 (Occidente)
-- ============================================================

-- ventas — fragmento Occidente
-- Los registros de Capital (sucursal_id=1) viven en SQL Server.
CREATE TABLE IF NOT EXISTS inventario.ventas (
  id_venta    SERIAL PRIMARY KEY,
  id_cliente  INT          NOT NULL,           -- Ref. lógica → SS.clientes
  id_empleado INT,                             -- Ref. lógica → Oracle.empleados
  fecha_venta TIMESTAMP    DEFAULT NOW(),
  total       DECIMAL(12,2),
  sucursal_id INT          DEFAULT 2,
  estado      VARCHAR(20)  DEFAULT 'completada',
  CONSTRAINT chk_ventas_sucursal CHECK (sucursal_id = 2)
);

COMMENT ON TABLE  inventario.ventas IS
  'Fragmento horizontal de ventas — Sucursal Occidente (sucursal_id=2). Capital vive en SQL Server.';
COMMENT ON COLUMN inventario.ventas.id_cliente IS
  'Referencia lógica a SQL Server.clientes — sin FK real por ser cross-motor';
COMMENT ON COLUMN inventario.ventas.id_empleado IS
  'Referencia lógica a Oracle.empleados — sin FK real por ser cross-motor';

-- detalle_ventas — fragmento Occidente
CREATE TABLE IF NOT EXISTS inventario.detalle_ventas (
  id_detalle      SERIAL PRIMARY KEY,
  id_venta        INT          NOT NULL REFERENCES inventario.ventas(id_venta),
  id_producto     INT,                         -- Ref. lógica → inventario.productos
  cantidad        INT,
  precio_unitario DECIMAL(10,2),
  subtotal        DECIMAL(12,2)
);

COMMENT ON TABLE  inventario.detalle_ventas IS
  'Detalle de ventas Occidente — FK interna a inventario.ventas dentro de PostgreSQL.';
COMMENT ON COLUMN inventario.detalle_ventas.id_producto IS
  'Referencia a inventario.productos (mismo motor — FK lógica para consistencia cross-motor)';

-- Permisos para el rol existente
GRANT ALL PRIVILEGES ON inventario.ventas          TO rol_inventario;
GRANT ALL PRIVILEGES ON inventario.detalle_ventas  TO rol_inventario;
GRANT USAGE, SELECT, UPDATE ON SEQUENCE inventario.ventas_id_venta_seq             TO rol_inventario;
GRANT USAGE, SELECT, UPDATE ON SEQUENCE inventario.detalle_ventas_id_detalle_seq   TO rol_inventario;
