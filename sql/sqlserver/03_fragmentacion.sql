-- ============================================================
-- SQL Server 2022 — Fragmentación horizontal de ventas
-- TecnoChapina S.A.
-- ============================================================
-- ARQUITECTURA ACTUALIZADA:
--   Fragmento Capital   (sucursal_id=1) → SQL Server  ← este archivo
--   Fragmento Occidente (sucursal_id=2) → PostgreSQL  ← sql/postgres/03_ventas.sql
--
-- El backend (FastAPI) orquesta el routing: inserts y queries
-- se dirigen al motor correcto según sucursal_id.
-- En modo failover, SQL Server se reemplaza por Oracle (backup).
-- ============================================================

USE ventas_db;
GO

-- ──────────────────────────────────────────────────────────
-- Vista: fragmento Capital (sucursal_id = 1)
-- Útil para verificar el fragmento en DBeaver
-- ──────────────────────────────────────────────────────────

CREATE OR ALTER VIEW dbo.ventas_capital AS
SELECT * FROM dbo.ventas WHERE sucursal_id = 1;
GO

-- Occidente ya no vive en SQL Server — eliminar vista si existía
IF OBJECT_ID('dbo.ventas_occidente', 'V') IS NOT NULL
    DROP VIEW dbo.ventas_occidente;
GO

-- ──────────────────────────────────────────────────────────
-- Verificación: resumen del fragmento Capital
-- ──────────────────────────────────────────────────────────
SELECT
    'Capital (SQL Server)'        AS fragmento,
    COUNT(*)                      AS total_ventas,
    SUM(total)                    AS ingresos_total,
    MIN(fecha_venta)              AS primera_venta,
    MAX(fecha_venta)              AS ultima_venta
FROM dbo.ventas
WHERE sucursal_id = 1;
GO

-- Nota: el fragmento Occidente (sucursal_id=2) se verifica en PostgreSQL:
--   SELECT COUNT(*), SUM(total) FROM inventario.ventas WHERE sucursal_id = 2;
GO
