-- ============================================================
-- PostgreSQL — Verificación de fragmento Occidente
-- TecnoChapina S.A.
-- Ejecutar en DBeaver → conexión PostgreSQL (inventario_db)
-- ============================================================

-- ── 1. Conteo por motor ─────────────────────────────────────
SELECT
    'PostgreSQL'                    AS motor,
    'inventario.ventas'             AS tabla,
    COUNT(*)                        AS total_registros,
    MIN(fecha_venta)                AS primera_venta,
    MAX(fecha_venta)                AS ultima_venta,
    SUM(total)                      AS ingresos_totales
FROM inventario.ventas
WHERE sucursal_id = 2;

-- ── 2. Últimas 5 ventas insertadas en este motor ───────────
SELECT
    id_venta,
    id_cliente,
    id_empleado,
    sucursal_id,
    'Occidente (PostgreSQL)'        AS fragmento_fisico,
    fecha_venta,
    total,
    estado
FROM inventario.ventas
WHERE sucursal_id = 2
ORDER BY fecha_venta DESC;
-- LIMIT 5;

-- ── 3. Confirmar que NO existen registros de Capital ────────
SELECT
    CASE
        WHEN COUNT(*) = 0
        THEN 'OK — PostgreSQL NO tiene ventas de Capital (sucursal_id=1)'
        ELSE 'ERROR — Se encontraron ' || COUNT(*) || ' registros de Capital aquí'
    END AS verificacion_fragmentacion
FROM inventario.ventas
WHERE sucursal_id = 1;

-- ── 4. Detalle de ventas en este fragmento ──────────────────
SELECT
    dv.id_venta,
    dv.id_producto,
    dv.cantidad,
    dv.precio_unitario,
    dv.subtotal
FROM inventario.detalle_ventas dv
JOIN inventario.ventas v ON dv.id_venta = v.id_venta
WHERE v.sucursal_id = 2
ORDER BY dv.id_venta;

-- ── 5. Resumen completo de tablas en este motor ─────────────
SELECT 'inventario.categorias'   AS tabla, COUNT(*) AS registros FROM inventario.categorias
UNION ALL
SELECT 'inventario.productos',           COUNT(*) FROM inventario.productos
UNION ALL
SELECT 'inventario.inventario',          COUNT(*) FROM inventario.inventario
UNION ALL
SELECT 'inventario.ventas (id=2)',        COUNT(*) FROM inventario.ventas WHERE sucursal_id = 2
UNION ALL
SELECT 'inventario.detalle_ventas',       COUNT(*) FROM inventario.detalle_ventas;
