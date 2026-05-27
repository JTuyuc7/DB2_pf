-- ============================================================
-- SQL Server 2022 — Datos seed
-- TecnoChapina S.A.
-- Ejecutar como sa (o usr_ventas)
-- ============================================================

USE ventas_db;
GO

-- ============================================================
-- CLIENTES (15 registros)
-- ============================================================

INSERT INTO clientes (nombre, apellido, email, telefono, direccion, nit) VALUES
  ('Juan Carlos', 'García Pérez',    'jcgarcia@gmail.com',      '502-5500-3001', 'Zona 1, Ciudad de Guatemala',    '1234567-8'),
  ('María Fernanda','López Ajú',     'mflopez@hotmail.com',     '502-5500-3002', 'Zona 10, Ciudad de Guatemala',   '2345678-9'),
  ('Roberto',      'Tzoc Choc',      'rtzoc@gmail.com',         '502-5500-3003', 'Zona 11, Ciudad de Guatemala',   '3456789-0'),
  ('Lucía',        'Caal Tuyuc',     'lcaal@yahoo.com',         '502-5500-3004', 'Zona 4, Quetzaltenango',         '4567890-1'),
  ('Diego Alejandro','Mó Batz',      'dmo@gmail.com',           '502-5500-3005', 'Zona 3, Quetzaltenango',         '5678901-2'),
  ('Ana Sofía',    'Xuya Pop',       'axuya@gmail.com',         '502-5500-3006', 'Zona 2, Ciudad de Guatemala',    'CF'),
  ('Carlos Enrique','Ajú Cuc',       'caju@empresa.gt',         '502-5500-3007', 'Zona 13, Ciudad de Guatemala',   '6789012-3'),
  ('Patricia',     'Menéndez Boc',   'pmenendez@gmail.com',     '502-5500-3008', 'Zona 15, Ciudad de Guatemala',   '7890123-4'),
  ('Fernando',     'Ramos Ich',      'framos@outlook.com',      '502-5500-3009', 'Zona 5, Quetzaltenango',         '8901234-5'),
  ('Claudia',      'Pérez Xuy',      'cperez@gmail.com',        '502-5500-3010', 'Zona 7, Ciudad de Guatemala',    'CF'),
  ('Mario Antonio','Tun Caal',       'mtun@hotmail.com',        '502-5500-3011', 'Zona 12, Ciudad de Guatemala',   '9012345-6'),
  ('Gabriela',     'Pop Choc',       'gpop@gmail.com',          '502-5500-3012', 'Zona 8, Ciudad de Guatemala',    'CF'),
  ('Héctor',       'Yat López',      'hyat@empresa.gt',         '502-5500-3013', 'Zona 6, Quetzaltenango',         '0123456-7'),
  ('Verónica',     'Cuc Pérez',      'vcuc@gmail.com',          '502-5500-3014', 'Zona 16, Ciudad de Guatemala',   '1122334-5'),
  ('Kevin',        'Boc Tuyuc',      'kboc@gmail.com',          '502-5500-3015', 'Zona 9, Ciudad de Guatemala',    'CF');
GO

-- ============================================================
-- VENTAS (20 registros)
-- sucursal_id 1 = Capital  → empleados 8, 9, 10 (Elena, Andrés, Diana)
-- sucursal_id 2 = Occidente → empleados 4, 6, 7  (Ana, Rosa, Jorge)
-- Fragmentación horizontal visible: mitad de ventas por cada sucursal
-- ============================================================

INSERT INTO ventas (id_cliente, id_empleado, fecha_venta, total, sucursal_id, estado) VALUES
  -- Sucursal Capital (sucursal_id = 1)
  (1,  9,  '2025-11-02 10:15:00', 8200.00,  1, 'completada'),
  (2,  10, '2025-11-05 14:30:00', 6500.00,  1, 'completada'),
  (3,  8,  '2025-11-08 09:00:00', 19700.00, 1, 'completada'),
  (6,  9,  '2025-11-10 11:45:00', 1850.00,  1, 'completada'),
  (7,  10, '2025-11-12 16:00:00', 9500.00,  1, 'completada'),
  (9,  8,  '2025-11-15 10:30:00', 4200.00,  1, 'completada'),
  (11, 9,  '2025-11-18 13:15:00', 11500.00, 1, 'completada'),
  (12, 10, '2025-11-20 15:00:00', 2370.00,  1, 'completada'),
  (14, 8,  '2025-11-25 09:30:00', 5800.00,  1, 'completada'),
  (15, 9,  '2025-11-28 11:00:00', 1200.00,  1, 'completada'),

  -- Sucursal Occidente (sucursal_id = 2)
  (4,  6,  '2025-11-03 10:00:00', 3800.00,  2, 'completada'),
  (5,  7,  '2025-11-06 14:00:00', 1385.00,  2, 'completada'),
  (8,  4,  '2025-11-09 09:45:00', 2100.00,  2, 'completada'),
  (10, 6,  '2025-11-11 12:00:00', 7800.00,  2, 'completada'),
  (13, 7,  '2025-11-14 16:30:00', 450.00,   2, 'completada'),
  (1,  4,  '2025-11-17 10:15:00', 1200.00,  2, 'completada'),
  (3,  6,  '2025-11-21 13:00:00', 6500.00,  2, 'completada'),
  (5,  7,  '2025-11-24 15:30:00', 900.00,   2, 'anulada'),
  (8,  4,  '2025-11-26 09:00:00', 4785.00,  2, 'completada'),
  (10, 6,  '2025-11-29 11:45:00', 11500.00, 2, 'completada');
GO

-- ============================================================
-- DETALLE_VENTAS (~35 registros)
-- id_producto referencia lógica a PostgreSQL.productos (IDs 1-15)
-- ============================================================

INSERT INTO detalle_ventas (id_venta, id_producto, cantidad, precio_unitario, subtotal) VALUES
  -- Venta 1: iPhone 15 (prod 3)
  (1,  3,  1, 8200.00,  8200.00),

  -- Venta 2: Galaxy S24 (prod 2)
  (2,  2,  1, 6500.00,  6500.00),

  -- Venta 3: iPhone 15 Pro + MacBook Air M2 (prods 4 + 8)
  (3,  4,  1, 11500.00, 11500.00),
  (3,  8,  1, 9500.00,   9500.00),

  -- Venta 4: Galaxy A54 (prod 1)
  (4,  1,  1, 1850.00,  1850.00),

  -- Venta 5: MacBook Air M2 (prod 8)
  (5,  8,  1, 9500.00,  9500.00),

  -- Venta 6: HP Laptop 15 (prod 7)
  (6,  7,  1, 4200.00,  4200.00),

  -- Venta 7: iPhone 15 Pro (prod 4)
  (7,  4,  1, 11500.00, 11500.00),

  -- Venta 8: Galaxy Buds2 + Cargador USB-C (prods 12 + 13)
  (8,  12, 1, 450.00,   450.00),
  (8,  13, 1, 185.00,   185.00),
  (8,  13, 9, 185.00,   1665.00),

  -- Venta 9: iPad Air (prod 11)
  (9,  11, 1, 5800.00,  5800.00),

  -- Venta 10: Xiaomi Redmi Note 13 (prod 5)
  (10, 5,  1, 1200.00,  1200.00),

  -- Venta 11: Lenovo IdeaPad 3 (prod 6)
  (11, 6,  1, 3800.00,  3800.00),

  -- Venta 12: Cargador USB-C + RAM DDR4 (prods 13 + 14)
  (12, 13, 1, 185.00,   185.00),
  (12, 14, 4, 320.00,   1280.00),

  -- Venta 13: Galaxy Tab A8 (prod 10)
  (13, 10, 1, 2100.00,  2100.00),

  -- Venta 14: HP EliteBook 840 (prod 9)
  (14, 9,  1, 7800.00,  7800.00),

  -- Venta 15: Galaxy Buds2 (prod 12)
  (15, 12, 1, 450.00,   450.00),

  -- Venta 16: Xiaomi Redmi Note 13 (prod 5)
  (16, 5,  1, 1200.00,  1200.00),

  -- Venta 17: Galaxy S24 (prod 2)
  (17, 2,  1, 6500.00,  6500.00),

  -- Venta 18: anulada — SSD + RAM (prods 15 + 14)
  (18, 15, 1, 580.00,   580.00),
  (18, 14, 1, 320.00,   320.00),

  -- Venta 19: HP Laptop 15 + SSD (prods 7 + 15)
  (19, 7,  1, 4200.00,  4200.00),
  (19, 15, 1, 580.00,   580.00),
  (19, 14, 1, 320.00,   320.00),

  -- Venta 20: iPhone 15 Pro (prod 4)
  (20, 4,  1, 11500.00, 11500.00);
GO
