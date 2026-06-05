-- ============================================================
-- SQL Server — Verificación de fragmento Capital
-- TecnoChapina S.A.
-- Ejecutar en DBeaver → conexión SQL Server (ventas_db)
-- ============================================================

USE ventas_db;

-- ── 1. Conteo por motor ─────────────────────────────────────
SELECT
    'SQL Server'           AS motor,
    'dbo.ventas'           AS tabla,
    COUNT(*)               AS total_registros,
    MIN(fecha_venta)       AS primera_venta,
    MAX(fecha_venta)       AS ultima_venta,
    SUM(total)             AS ingresos_totales
FROM ventas
WHERE sucursal_id = 1;

-- ── 2. Últimas 5 ventas insertadas en este motor ───────────
SELECT
    id_venta,
    id_cliente,
    id_empleado,
    sucursal_id,
    'Capital (SQL Server)' AS fragmento_fisico,
    fecha_venta,
    total,
    estado
FROM ventas
WHERE sucursal_id = 1
ORDER BY fecha_venta DESC;

-- ── 3. Confirmar que NO existen registros de Occidente ──────
SELECT
    CASE
        WHEN COUNT(*) = 0
        THEN 'OK — SQL Server NO tiene ventas de Occidente (sucursal_id=2)'
        ELSE 'ERROR — Se encontraron ' + CAST(COUNT(*) AS VARCHAR) + ' registros de Occidente aqui'
    END AS verificacion_fragmentacion
FROM ventas
WHERE sucursal_id = 2;

-- ── 4. Detalle de ventas en este fragmento ──────────────────
SELECT
    dv.id_venta,
    dv.id_producto,
    dv.cantidad,
    dv.precio_unitario,
    dv.subtotal
FROM detalle_ventas dv
JOIN ventas v ON dv.id_venta = v.id_venta
WHERE v.sucursal_id = 1
ORDER BY dv.id_venta;
