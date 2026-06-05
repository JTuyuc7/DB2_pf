-- ============================================================
-- Oracle XE 21c — Tablas de backup para failover
-- TecnoChapina S.A.
-- Ejecutar como admin_central / AdminPass123
-- Compatible con DBeaver: todo en un bloque PL/SQL + DDL separado
-- ============================================================

-- ── Paso 1: Eliminar objetos previos (idempotente) ─────────
-- Seleccionar este bloque completo y ejecutar con Ctrl+Enter
BEGIN
  BEGIN EXECUTE IMMEDIATE 'DROP TABLE detalle_ventas_backup'; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN EXECUTE IMMEDIATE 'DROP TABLE ventas_backup';         EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE ventas_backup_seq';              EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE detalle_ventas_backup_seq';      EXCEPTION WHEN OTHERS THEN NULL; END;
END;

-- ── Paso 2: Crear tabla ventas_backup ──────────────────────
CREATE TABLE ventas_backup (
  id_venta    NUMBER        PRIMARY KEY,
  id_cliente  NUMBER        NOT NULL,
  id_empleado NUMBER,
  fecha_venta TIMESTAMP,
  total       NUMBER(12,2),
  sucursal_id NUMBER        DEFAULT 1,
  estado      VARCHAR2(20)  DEFAULT 'completada',
  backup_ts   TIMESTAMP     DEFAULT SYSTIMESTAMP
) TABLESPACE ts_central;

-- ── Paso 3: Crear tabla detalle_ventas_backup ──────────────
CREATE TABLE detalle_ventas_backup (
  id_detalle      NUMBER PRIMARY KEY,
  id_venta        NUMBER NOT NULL,
  id_producto     NUMBER,
  cantidad        NUMBER,
  precio_unitario NUMBER(10,2),
  subtotal        NUMBER(12,2)
) TABLESPACE ts_central;

-- ── Paso 4: Crear sequences para inserts en failover ───────
CREATE SEQUENCE ventas_backup_seq
  START WITH 10001 INCREMENT BY 1 NOCACHE;

CREATE SEQUENCE detalle_ventas_backup_seq
  START WITH 10001 INCREMENT BY 1 NOCACHE;

-- ── Paso 5: Comentarios ────────────────────────────────────
COMMENT ON TABLE ventas_backup IS
  'Backup de SQL Server ventas (sucursal_id=1). Se rellena via POST /backup-oracle.';

COMMENT ON TABLE detalle_ventas_backup IS
  'Backup de SS.detalle_ventas para ventas de Capital.';
