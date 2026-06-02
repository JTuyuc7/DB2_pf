-- ============================================================
-- PostgreSQL 16 — Sucursal Occidente (Inventario)
-- TecnoChapina S.A.
-- Conexión: admin_inventario/PostgresPass123 → inventario_db (puerto 5432)
-- Esquema: inventario  |  Tablas: categorias, productos, inventario
-- ============================================================

-- ─────────────────────────────────
-- CATEGORÍAS
-- ─────────────────────────────────

-- Todas las categorías
SELECT * FROM inventario.categorias ORDER BY id_categoria;

-- Categorías con conteo de productos
SELECT
    c.id_categoria,
    c.nombre              AS categoria,
    c.descripcion,
    COUNT(p.id_producto)  AS total_productos
FROM inventario.categorias c
LEFT JOIN inventario.productos p ON c.id_categoria = p.id_categoria
GROUP BY c.id_categoria, c.nombre, c.descripcion
ORDER BY total_productos DESC;

-- ─────────────────────────────────
-- PRODUCTOS
-- ─────────────────────────────────

-- Todos los productos
SELECT * FROM inventario.productos ORDER BY id_producto;

-- Productos con nombre de categoría
SELECT
    p.id_producto,
    p.nombre              AS producto,
    p.descripcion,
    p.precio_unitario,
    c.nombre              AS categoria,
    p.id_proveedor
FROM inventario.productos p
JOIN inventario.categorias c ON p.id_categoria = c.id_categoria
ORDER BY c.nombre, p.nombre;

-- Productos por categoría
SELECT
    c.nombre AS categoria,
    COUNT(*) AS total_productos,
    MIN(p.precio_unitario) AS precio_min,
    MAX(p.precio_unitario) AS precio_max,
    ROUND(AVG(p.precio_unitario), 2) AS precio_promedio
FROM inventario.productos p
JOIN inventario.categorias c ON p.id_categoria = c.id_categoria
GROUP BY c.nombre
ORDER BY total_productos DESC;

-- Productos más caros (top 10)
SELECT
    p.nombre,
    p.precio_unitario,
    c.nombre AS categoria
FROM inventario.productos p
JOIN inventario.categorias c ON p.id_categoria = c.id_categoria
ORDER BY p.precio_unitario DESC
LIMIT 10;

-- Productos más baratos (top 10)
SELECT
    p.nombre,
    p.precio_unitario,
    c.nombre AS categoria
FROM inventario.productos p
JOIN inventario.categorias c ON p.id_categoria = c.id_categoria
ORDER BY p.precio_unitario ASC
LIMIT 10;

-- Buscar producto por nombre (parcial, case-insensitive)
-- Reemplazar 'laptop' con el término a buscar
SELECT p.*, c.nombre AS categoria
FROM inventario.productos p
JOIN inventario.categorias c ON p.id_categoria = c.id_categoria
WHERE LOWER(p.nombre) LIKE LOWER('%laptop%');

-- Productos de un proveedor específico (por id_proveedor)
-- Reemplazar 1 con el id del proveedor
SELECT * FROM inventario.productos WHERE id_proveedor = 1;

-- ─────────────────────────────────
-- INVENTARIO (STOCK)
-- ─────────────────────────────────

-- Todo el inventario
SELECT * FROM inventario.inventario ORDER BY id_inventario;

-- Inventario con nombre de producto y categoría
SELECT
    i.id_inventario,
    p.nombre              AS producto,
    c.nombre              AS categoria,
    i.bodega,
    i.cantidad_disponible,
    p.precio_unitario,
    ROUND(i.cantidad_disponible * p.precio_unitario, 2) AS valor_stock,
    i.fecha_actualizacion
FROM inventario.inventario i
JOIN inventario.productos p  ON i.id_producto  = p.id_producto
JOIN inventario.categorias c ON p.id_categoria = c.id_categoria
ORDER BY c.nombre, p.nombre;

-- Inventario por bodega
SELECT bodega, COUNT(*) AS productos, SUM(cantidad_disponible) AS unidades_totales
FROM inventario.inventario
GROUP BY bodega
ORDER BY unidades_totales DESC;

-- Stock bajo (menos de 5 unidades)
SELECT
    p.nombre AS producto,
    i.bodega,
    i.cantidad_disponible
FROM inventario.inventario i
JOIN inventario.productos p ON i.id_producto = p.id_producto
WHERE i.cantidad_disponible < 5
ORDER BY i.cantidad_disponible ASC;

-- Productos sin stock
SELECT
    p.nombre AS producto,
    i.bodega
FROM inventario.inventario i
JOIN inventario.productos p ON i.id_producto = p.id_producto
WHERE i.cantidad_disponible = 0;

-- Valor total del inventario
SELECT
    SUM(i.cantidad_disponible * p.precio_unitario) AS valor_total_inventario
FROM inventario.inventario i
JOIN inventario.productos p ON i.id_producto = p.id_producto;

-- Valor de inventario por bodega
SELECT
    i.bodega,
    SUM(i.cantidad_disponible)                            AS unidades,
    ROUND(SUM(i.cantidad_disponible * p.precio_unitario), 2) AS valor_total
FROM inventario.inventario i
JOIN inventario.productos p ON i.id_producto = p.id_producto
GROUP BY i.bodega
ORDER BY valor_total DESC;

-- ─────────────────────────────────
-- REPLICACIÓN — productos_replica
-- (tabla creada por backend/replicacion.py)
-- ─────────────────────────────────
-- Nota: esta tabla vive en SQL Server, no en PostgreSQL.
-- Ver sqlserver_queries.sql para consultarla.

-- ─────────────────────────────────
-- ESTADÍSTICAS GENERALES
-- ─────────────────────────────────

-- Resumen de registros por tabla
SELECT 'categorias' AS tabla, COUNT(*) AS total FROM inventario.categorias UNION ALL
SELECT 'productos'  AS tabla, COUNT(*) AS total FROM inventario.productos   UNION ALL
SELECT 'inventario' AS tabla, COUNT(*) AS total FROM inventario.inventario;
