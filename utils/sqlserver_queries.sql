-- ============================================================
-- SQL Server 2022 — Sucursal Capital (Ventas)
-- TecnoChapina S.A.
-- Conexión: sa/SqlServerPass123! → ventas_db (puerto 1433)
-- Tablas: clientes, ventas, detalle_ventas, productos_replica
-- Vistas: ventas_capital, ventas_occidente
-- ============================================================

USE ventas_db;
GO

-- ─────────────────────────────────
-- CLIENTES
-- ─────────────────────────────────

-- Todos los clientes
SELECT * FROM clientes ORDER BY id_cliente;

-- Clientes con nombre completo
SELECT
    id_cliente,
    nombre + ' ' + apellido AS nombre_completo,
    email,
    telefono,
    direccion,
    nit
FROM clientes
ORDER BY apellido, nombre;

-- Buscar cliente por nombre o NIT
-- Reemplazar 'López' con el término a buscar
SELECT *
FROM clientes
WHERE nombre  LIKE '%López%'
   OR apellido LIKE '%López%'
   OR nit      LIKE '%López%';

-- Clientes con más compras
SELECT
    c.id_cliente,
    c.nombre + ' ' + c.apellido AS cliente,
    COUNT(v.id_venta)            AS total_compras,
    SUM(v.total)                 AS monto_total
FROM clientes c
LEFT JOIN ventas v ON c.id_cliente = v.id_cliente
GROUP BY c.id_cliente, c.nombre, c.apellido
ORDER BY total_compras DESC;

-- ─────────────────────────────────
-- VENTAS
-- ─────────────────────────────────

-- Todas las ventas
SELECT * FROM ventas ORDER BY fecha_venta DESC;

-- Ventas con nombre del cliente
SELECT
    v.id_venta,
    c.nombre + ' ' + c.apellido AS cliente,
    v.fecha_venta,
    v.total,
    v.sucursal_id,
    CASE v.sucursal_id
        WHEN 1 THEN 'Capital'
        WHEN 2 THEN 'Occidente'
        ELSE 'Desconocida'
    END AS sucursal,
    v.estado,
    v.id_empleado
FROM ventas v
JOIN clientes c ON v.id_cliente = c.id_cliente
ORDER BY v.fecha_venta DESC;

-- Ventas del último mes
SELECT v.*, c.nombre + ' ' + c.apellido AS cliente
FROM ventas v
JOIN clientes c ON v.id_cliente = c.id_cliente
WHERE v.fecha_venta >= DATEADD(MONTH, -1, GETDATE())
ORDER BY v.fecha_venta DESC;

-- Resumen de ventas por mes
SELECT
    YEAR(fecha_venta)  AS anio,
    MONTH(fecha_venta) AS mes,
    COUNT(*)           AS total_ventas,
    SUM(total)         AS ingresos
FROM ventas
GROUP BY YEAR(fecha_venta), MONTH(fecha_venta)
ORDER BY anio DESC, mes DESC;

-- Resumen de ventas por sucursal
SELECT
    CASE sucursal_id
        WHEN 1 THEN 'Capital'
        WHEN 2 THEN 'Occidente'
    END AS sucursal,
    COUNT(*)   AS total_ventas,
    SUM(total) AS ingresos_total,
    AVG(total) AS ticket_promedio
FROM ventas
GROUP BY sucursal_id
ORDER BY ingresos_total DESC;

-- ─────────────────────────────────
-- FRAGMENTACIÓN HORIZONTAL
-- (vistas ventas_capital / ventas_occidente)
-- ─────────────────────────────────

-- Fragmento Capital (sucursal_id = 1)
SELECT * FROM ventas_capital ORDER BY fecha_venta DESC;

-- Fragmento Occidente (sucursal_id = 2)
SELECT * FROM ventas_occidente ORDER BY fecha_venta DESC;

-- Comparativo entre fragmentos
SELECT
    'Capital'         AS sucursal,
    COUNT(*)          AS total_ventas,
    SUM(total)        AS ingresos_total,
    MIN(fecha_venta)  AS primera_venta,
    MAX(fecha_venta)  AS ultima_venta
FROM ventas_capital
UNION ALL
SELECT
    'Occidente'       AS sucursal,
    COUNT(*)          AS total_ventas,
    SUM(total)        AS ingresos_total,
    MIN(fecha_venta)  AS primera_venta,
    MAX(fecha_venta)  AS ultima_venta
FROM ventas_occidente;
GO

-- ─────────────────────────────────
-- DETALLE DE VENTAS
-- ─────────────────────────────────

-- Todo el detalle de ventas
SELECT * FROM detalle_ventas ORDER BY id_detalle;

-- Detalle con venta y cliente
SELECT
    dv.id_detalle,
    v.id_venta,
    c.nombre + ' ' + c.apellido AS cliente,
    v.fecha_venta,
    dv.id_producto,
    dv.cantidad,
    dv.precio_unitario,
    dv.subtotal
FROM detalle_ventas dv
JOIN ventas   v ON dv.id_venta   = v.id_venta
JOIN clientes c ON v.id_cliente  = c.id_cliente
ORDER BY v.fecha_venta DESC;

-- Productos más vendidos (por cantidad)
SELECT
    id_producto,
    SUM(cantidad)   AS unidades_vendidas,
    SUM(subtotal)   AS ingresos_generados,
    COUNT(id_venta) AS num_ventas
FROM detalle_ventas
GROUP BY id_producto
ORDER BY unidades_vendidas DESC;

-- Ticket promedio por venta
SELECT
    AVG(total)  AS ticket_promedio,
    MIN(total)  AS venta_minima,
    MAX(total)  AS venta_maxima,
    SUM(total)  AS ingresos_totales
FROM ventas;

-- ─────────────────────────────────
-- REPLICACIÓN — productos_replica
-- (copia snapshot desde PostgreSQL, creada por backend/replicacion.py)
-- ─────────────────────────────────

-- Ver productos replicados desde PostgreSQL
SELECT * FROM productos_replica ORDER BY id_producto;

-- Comparar conteo: replicados vs origen PostgreSQL
-- (ejecutar en PostgreSQL para el origen)
-- SELECT COUNT(*) FROM inventario.productos;
SELECT COUNT(*) AS productos_replicados FROM productos_replica;

-- ─────────────────────────────────
-- ESTADÍSTICAS GENERALES
-- ─────────────────────────────────

-- Resumen de registros por tabla
SELECT 'clientes'          AS tabla, COUNT(*) AS total FROM clientes          UNION ALL
SELECT 'ventas'            AS tabla, COUNT(*) AS total FROM ventas             UNION ALL
SELECT 'detalle_ventas'    AS tabla, COUNT(*) AS total FROM detalle_ventas     UNION ALL
SELECT 'productos_replica' AS tabla, COUNT(*) AS total FROM productos_replica;
GO
