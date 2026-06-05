-- ============================================================
-- SQL Server — Dejar solo 5 ventas de Capital para la demo
-- ============================================================
USE ventas_db;

-- Detalle primero (FK hacia ventas)
DELETE FROM detalle_ventas
WHERE id_venta NOT IN (
    SELECT TOP 5 id_venta FROM ventas WHERE sucursal_id = 1 ORDER BY id_venta ASC
);

-- Luego las ventas
DELETE FROM ventas
WHERE sucursal_id = 1
  AND id_venta NOT IN (
    SELECT TOP 5 id_venta FROM ventas WHERE sucursal_id = 1 ORDER BY id_venta ASC
);

-- Verificar resultado
SELECT id_venta, id_cliente, id_empleado, fecha_venta, total, estado FROM ventas WHERE sucursal_id = 1 ORDER BY id_venta;
SELECT COUNT(*) AS ventas_restantes FROM ventas WHERE sucursal_id = 1;
