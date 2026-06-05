-- ============================================================
-- PostgreSQL — Dejar solo 5 ventas de Occidente para la demo
-- ============================================================

-- Detalle primero (FK hacia ventas)
DELETE FROM inventario.detalle_ventas
WHERE id_venta NOT IN (
    SELECT id_venta FROM inventario.ventas WHERE sucursal_id = 2 ORDER BY id_venta ASC LIMIT 5
);

-- Luego las ventas
DELETE FROM inventario.ventas
WHERE sucursal_id = 2
  AND id_venta NOT IN (
    SELECT id_venta FROM inventario.ventas WHERE sucursal_id = 2 ORDER BY id_venta ASC LIMIT 5
);

-- Verificar resultado
SELECT id_venta, id_cliente, id_empleado, fecha_venta, total, estado FROM inventario.ventas WHERE sucursal_id = 2 ORDER BY id_venta;
SELECT COUNT(*) AS ventas_restantes FROM inventario.ventas WHERE sucursal_id = 2;
