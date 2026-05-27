-- ============================================================
-- SQL Server — Fragmentación Horizontal en tabla ventas
-- TecnoChapina S.A. — Día 4
-- Ejecutar como sa, en contexto de ventas_db
-- ============================================================
USE ventas_db;
GO

-- ──────────────────────────────────────────────
-- Vistas que simulan los "fragmentos" físicos
-- En un sistema real cada vista viviría en un
-- servidor diferente. Aquí lo simulamos con
-- filtros sobre sucursal_id.
-- ──────────────────────────────────────────────

-- Fragmento 1: Sucursal Capital (Zona 10, Guatemala)
CREATE OR ALTER VIEW dbo.ventas_capital AS
SELECT * FROM dbo.ventas WHERE sucursal_id = 1;
GO

-- Fragmento 2: Sucursal Occidente (Quetzaltenango)
CREATE OR ALTER VIEW dbo.ventas_occidente AS
SELECT * FROM dbo.ventas WHERE sucursal_id = 2;
GO

-- ──────────────────────────────────────────────
-- Verificación: resumen por fragmento
-- ──────────────────────────────────────────────
SELECT
    'Capital'         AS sucursal,
    COUNT(*)          AS total_ventas,
    SUM(total)        AS ingresos_total,
    MIN(fecha_venta)  AS primera_venta,
    MAX(fecha_venta)  AS ultima_venta
FROM dbo.ventas WHERE sucursal_id = 1
UNION ALL
SELECT
    'Occidente'       AS sucursal,
    COUNT(*)          AS total_ventas,
    SUM(total)        AS ingresos_total,
    MIN(fecha_venta)  AS primera_venta,
    MAX(fecha_venta)  AS ultima_venta
FROM dbo.ventas WHERE sucursal_id = 2;
GO

-- Consultar cada fragmento por separado (como si fueran tablas distintas)
SELECT 'CAPITAL'   AS fragmento, id_venta, id_cliente, total, fecha_venta FROM dbo.ventas_capital;
SELECT 'OCCIDENTE' AS fragmento, id_venta, id_cliente, total, fecha_venta FROM dbo.ventas_occidente;
GO
