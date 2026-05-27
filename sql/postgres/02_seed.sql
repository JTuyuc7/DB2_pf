-- ============================================================
-- PostgreSQL 16 — Datos seed
-- TecnoChapina S.A.
-- Ejecutar como admin_inventario
-- ============================================================

-- ============================================================
-- CATEGORIAS (5 registros)
-- ============================================================

INSERT INTO inventario.categorias (nombre, descripcion) VALUES
  ('Celulares y Smartphones', 'Teléfonos móviles de todas las marcas y gamas'),
  ('Laptops y Computadoras',  'Equipos portátiles y de escritorio para trabajo y estudio'),
  ('Accesorios y Periféricos','Audífonos, cargadores, fundas y complementos'),
  ('Tablets',                 'Tabletas Android e iOS para consumo y productividad'),
  ('Componentes y Partes',    'Memoria RAM, almacenamiento, procesadores y repuestos');

-- ============================================================
-- PRODUCTOS (15 registros)
-- id_categoria: 1=Celulares, 2=Laptops, 3=Accesorios, 4=Tablets, 5=Componentes
-- id_proveedor: 1=Samsung, 2=iDistribuidores, 3=Lenovo, 4=HP, 5=Xiaomi
-- ============================================================

INSERT INTO inventario.productos (nombre, descripcion, precio_unitario, id_categoria, id_proveedor) VALUES
  ('Samsung Galaxy A54 5G',
   'Pantalla 6.4" Super AMOLED, 128GB almacenamiento, triple cámara 50MP',
   1850.00, 1, 1),

  ('Samsung Galaxy S24',
   'Gama alta 2024, pantalla Dynamic AMOLED 6.2", Exynos 2400, 256GB',
   6500.00, 1, 1),

  ('iPhone 15',
   'Chip A16 Bionic, pantalla 6.1" Super Retina XDR, cámara 48MP, USB-C',
   8200.00, 1, 2),

  ('iPhone 15 Pro',
   'Chip A17 Pro, titanio, pantalla 6.1" ProMotion 120Hz, triple cámara',
   11500.00, 1, 2),

  ('Xiaomi Redmi Note 13',
   'Pantalla AMOLED 6.67" 120Hz, Snapdragon 685, 128GB, cámara 108MP',
   1200.00, 1, 5),

  ('Lenovo IdeaPad 3',
   'Ryzen 5 7520U, 8GB RAM, SSD 512GB, pantalla 15.6" FHD, Windows 11',
   3800.00, 2, 3),

  ('HP Laptop 15',
   'Intel Core i5-1235U, 8GB RAM, SSD 256GB, pantalla 15.6" FHD',
   4200.00, 2, 4),

  ('MacBook Air M2',
   'Chip Apple M2, 8GB RAM unificada, SSD 256GB, pantalla Liquid Retina 13.6"',
   9500.00, 2, 2),

  ('HP EliteBook 840 G10',
   'Intel Core i7-1355U, 16GB RAM, SSD 512GB, pantalla 14" IPS, empresarial',
   7800.00, 2, 4),

  ('Samsung Galaxy Tab A8',
   'Pantalla TFT 10.5" WUXGA, 3GB RAM, 32GB, Android 11, WiFi',
   2100.00, 4, 1),

  ('iPad Air (5ta generación)',
   'Chip M1, pantalla Liquid Retina 10.9", 64GB, WiFi, USB-C',
   5800.00, 4, 2),

  ('Audífonos Samsung Galaxy Buds2',
   'True wireless, cancelación activa de ruido, autonomía 8h, IPX2',
   450.00, 3, 1),

  ('Cargador USB-C 65W Lenovo',
   'GaN compacto, carga rápida, compatible con laptops y móviles USB-C',
   185.00, 3, 3),

  ('RAM DDR4 8GB 3200MHz',
   'Memoria SODIMM para laptop, compatible con Intel y AMD, sin buffer',
   320.00, 5, 4),

  ('SSD SATA 256GB',
   'Factor de forma 2.5", velocidad lectura 550 MB/s, escritura 520 MB/s',
   580.00, 5, 4);

-- ============================================================
-- INVENTARIO (15 registros — uno por producto, bodega Quetzaltenango)
-- ============================================================

INSERT INTO inventario.inventario (id_producto, bodega, cantidad_disponible, fecha_actualizacion) VALUES
  (1,  'Bodega Quetzaltenango', 45, '2025-11-01 08:00:00'),
  (2,  'Bodega Quetzaltenango', 18, '2025-11-01 08:00:00'),
  (3,  'Bodega Quetzaltenango', 22, '2025-11-05 09:30:00'),
  (4,  'Bodega Quetzaltenango',  8, '2025-11-05 09:30:00'),
  (5,  'Bodega Quetzaltenango', 60, '2025-11-10 10:00:00'),
  (6,  'Bodega Quetzaltenango', 15, '2025-11-10 10:00:00'),
  (7,  'Bodega Quetzaltenango', 20, '2025-11-12 11:00:00'),
  (8,  'Bodega Quetzaltenango',  5, '2025-11-12 11:00:00'),
  (9,  'Bodega Quetzaltenango', 10, '2025-11-15 08:30:00'),
  (10, 'Bodega Quetzaltenango', 12, '2025-11-15 08:30:00'),
  (11, 'Bodega Quetzaltenango',  7, '2025-11-18 14:00:00'),
  (12, 'Bodega Quetzaltenango', 80, '2025-11-18 14:00:00'),
  (13, 'Bodega Quetzaltenango',120, '2025-11-20 09:00:00'),
  (14, 'Bodega Quetzaltenango', 35, '2025-11-20 09:00:00'),
  (15, 'Bodega Quetzaltenango', 28, '2025-11-22 10:00:00');
