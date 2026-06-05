-- ============================================================
-- PostgreSQL 16 — Seed de ventas Sucursal Occidente
-- TecnoChapina S.A.
-- Ejecutar como admin_inventario, en inventario_db
-- SOLO para instalaciones limpias. Contenedores existentes
-- deben usar backend/migracion_ventas.py en su lugar.
-- ============================================================

-- 10 ventas de Occidente (sucursal_id = 2)
-- id_cliente  → referencia lógica a SS.clientes
-- id_empleado → referencia lógica a Oracle.empleados (Ana=2, Luis=6, Rosa=7, Jorge=8, Pedro=4? wait)
-- Empleados Occidente: Luis(6), Rosa(7), Jorge(8), Ana supervisora(2), Pedro(4)
-- Usando los mismos empleados que el seed de SS original

INSERT INTO inventario.ventas (id_cliente, id_empleado, fecha_venta, total, sucursal_id, estado) VALUES
  (4,  6,  '2025-11-03 10:00:00', 3800.00,  2, 'completada'),
  (5,  7,  '2025-11-06 14:00:00', 1385.00,  2, 'completada'),
  (8,  4,  '2025-11-09 09:45:00', 2100.00,  2, 'completada'),
  (10, 6,  '2025-11-11 12:00:00', 7800.00,  2, 'completada'),
  (13, 7,  '2025-11-14 16:30:00',  450.00,  2, 'completada'),
  (1,  4,  '2025-11-17 10:15:00', 1200.00,  2, 'completada'),
  (3,  6,  '2025-11-21 13:00:00', 6500.00,  2, 'completada'),
  (5,  7,  '2025-11-24 15:30:00',  900.00,  2, 'anulada'),
  (8,  4,  '2025-11-26 09:00:00', 4785.00,  2, 'completada'),
  (10, 6,  '2025-11-29 11:45:00',11500.00,  2, 'completada');

-- Detalle de ventas Occidente
-- Las ventas reciben IDs 1-10 por SERIAL; el detalle los referencia.
INSERT INTO inventario.detalle_ventas (id_venta, id_producto, cantidad, precio_unitario, subtotal) VALUES
  -- Venta 1: Lenovo IdeaPad 3 (prod 6)
  (1,  6,  1, 3800.00,  3800.00),

  -- Venta 2: Cargador USB-C (prod 13) + RAM DDR4 ×4 (prod 14)
  (2,  13, 1,  185.00,   185.00),
  (2,  14, 4,  320.00,  1280.00),

  -- Venta 3: Galaxy Tab A8 (prod 10)
  (3,  10, 1, 2100.00,  2100.00),

  -- Venta 4: HP EliteBook 840 (prod 9)
  (4,  9,  1, 7800.00,  7800.00),

  -- Venta 5: Galaxy Buds2 (prod 12)
  (5,  12, 1,  450.00,   450.00),

  -- Venta 6: Xiaomi Redmi Note 13 (prod 5)
  (6,  5,  1, 1200.00,  1200.00),

  -- Venta 7: Galaxy S24 (prod 2)
  (7,  2,  1, 6500.00,  6500.00),

  -- Venta 8: anulada — SSD (prod 15) + RAM (prod 14)
  (8,  15, 1,  580.00,   580.00),
  (8,  14, 1,  320.00,   320.00),

  -- Venta 9: HP Laptop 15 (prod 7) + SSD (prod 15) + RAM (prod 14)
  (9,  7,  1, 4200.00,  4200.00),
  (9,  15, 1,  580.00,   580.00),
  (9,  14, 1,  320.00,   320.00),

  -- Venta 10: iPhone 15 Pro (prod 4)
  (10, 4,  1,11500.00, 11500.00);
