-- ============================================================
-- Oracle XE 21c — Datos seed
-- TecnoChapina S.A.
-- PASO 3: Ejecutar como admin_central / AdminPass123
-- ============================================================

-- ============================================================
-- EMPLEADOS (10 registros: 3 Central, 4 Occidente, 3 Capital)
-- Los supervisores se insertan primero para que las FK funcionen
-- ============================================================

-- Gerentes / Supervisores (sin id_supervisor)
INSERT INTO empleados (nombre, apellido, email, telefono, puesto, sede, id_supervisor, fecha_contratacion)
VALUES ('Carlos', 'Ajú Pérez', 'caju@tecnochapina.gt', '502-2200-1001', 'Gerente General', 'Central', NULL, DATE '2019-03-10');

INSERT INTO empleados (nombre, apellido, email, telefono, puesto, sede, id_supervisor, fecha_contratacion)
VALUES ('Ana', 'Xuya Coy', 'axuya@tecnochapina.gt', '502-2200-1004', 'Supervisora de Sucursal', 'Occidente', 1, DATE '2020-06-01');

INSERT INTO empleados (nombre, apellido, email, telefono, puesto, sede, id_supervisor, fecha_contratacion)
VALUES ('Elena', 'Boc Yat', 'eboc@tecnochapina.gt', '502-2200-1008', 'Supervisora de Sucursal', 'Capital', 1, DATE '2020-08-15');

-- Empleados Central (id_supervisor = 1 = Carlos)
INSERT INTO empleados (nombre, apellido, email, telefono, puesto, sede, id_supervisor, fecha_contratacion)
VALUES ('María', 'López Tzoc', 'mlopez@tecnochapina.gt', '502-2200-1002', 'Contadora', 'Central', 1, DATE '2021-01-20');

INSERT INTO empleados (nombre, apellido, email, telefono, puesto, sede, id_supervisor, fecha_contratacion)
VALUES ('Pedro', 'Caal Mux', 'pcaal@tecnochapina.gt', '502-2200-1003', 'Técnico', 'Central', 1, DATE '2021-07-05');

-- Empleados Occidente (id_supervisor = 2 = Ana)
INSERT INTO empleados (nombre, apellido, email, telefono, puesto, sede, id_supervisor, fecha_contratacion)
VALUES ('Luis', 'Tuyuc Batz', 'ltuyuc@tecnochapina.gt', '502-2200-1005', 'Vendedor', 'Occidente', 2, DATE '2022-02-14');

INSERT INTO empleados (nombre, apellido, email, telefono, puesto, sede, id_supervisor, fecha_contratacion)
VALUES ('Rosa', 'Choc Caal', 'rchoc@tecnochapina.gt', '502-2200-1006', 'Vendedora', 'Occidente', 2, DATE '2022-05-30');

INSERT INTO empleados (nombre, apellido, email, telefono, puesto, sede, id_supervisor, fecha_contratacion)
VALUES ('Jorge', 'Mó Tux', 'jmo@tecnochapina.gt', '502-2200-1007', 'Vendedor', 'Occidente', 2, DATE '2023-01-10');

-- Empleados Capital (id_supervisor = 3 = Elena)
INSERT INTO empleados (nombre, apellido, email, telefono, puesto, sede, id_supervisor, fecha_contratacion)
VALUES ('Andrés', 'Pop Choc', 'apop@tecnochapina.gt', '502-2200-1009', 'Vendedor', 'Capital', 3, DATE '2022-09-01');

INSERT INTO empleados (nombre, apellido, email, telefono, puesto, sede, id_supervisor, fecha_contratacion)
VALUES ('Diana', 'Cuc Ich', 'dcuc@tecnochapina.gt', '502-2200-1010', 'Vendedora', 'Capital', 3, DATE '2023-03-22');

COMMIT;

-- ============================================================
-- PROVEEDORES (5 registros)
-- ============================================================

INSERT INTO proveedores (nombre, contacto, email, telefono, pais)
VALUES ('Samsung Electronics Guatemala', 'Roberto Kim', 'rkim@samsung.gt', '502-2300-2001', 'Corea del Sur');

INSERT INTO proveedores (nombre, contacto, email, telefono, pais)
VALUES ('iDistribuidores S.A.', 'Patricia Menéndez', 'pmenendez@idist.gt', '502-2300-2002', 'Guatemala');

INSERT INTO proveedores (nombre, contacto, email, telefono, pais)
VALUES ('Lenovo Centroamérica', 'David Chen', 'dchen@lenovo.com', '502-2300-2003', 'Guatemala');

INSERT INTO proveedores (nombre, contacto, email, telefono, pais)
VALUES ('HP Guatemala', 'Fernando Ramos', 'framos@hp.gt', '502-2300-2004', 'Guatemala');

INSERT INTO proveedores (nombre, contacto, email, telefono, pais)
VALUES ('Xiaomi Latam Guatemala', 'Chen Wei', 'cwei@xiaomi.gt', '502-2300-2005', 'Guatemala');

COMMIT;

-- ============================================================
-- AUDITORIA (10 registros de ejemplo — operaciones simuladas)
-- ============================================================

INSERT INTO auditoria (tabla_afectada, operacion, id_registro, usuario_db, fecha_hora, detalle)
VALUES ('empleados', 'INSERT', 1, 'admin_central', TIMESTAMP '2025-01-15 08:30:00', 'Alta de empleado Carlos Ajú Pérez como Gerente General');

INSERT INTO auditoria (tabla_afectada, operacion, id_registro, usuario_db, fecha_hora, detalle)
VALUES ('empleados', 'INSERT', 2, 'admin_central', TIMESTAMP '2025-01-15 08:35:00', 'Alta de empleado Ana Xuya Coy como Supervisora Occidente');

INSERT INTO auditoria (tabla_afectada, operacion, id_registro, usuario_db, fecha_hora, detalle)
VALUES ('proveedores', 'INSERT', 1, 'admin_central', TIMESTAMP '2025-01-16 09:00:00', 'Registro de proveedor Samsung Electronics Guatemala');

INSERT INTO auditoria (tabla_afectada, operacion, id_registro, usuario_db, fecha_hora, detalle)
VALUES ('proveedores', 'UPDATE', 3, 'admin_central', TIMESTAMP '2025-02-10 14:20:00', 'Actualización de teléfono de Lenovo Centroamérica');

INSERT INTO auditoria (tabla_afectada, operacion, id_registro, usuario_db, fecha_hora, detalle)
VALUES ('empleados', 'UPDATE', 5, 'admin_central', TIMESTAMP '2025-03-05 10:15:00', 'Cambio de puesto de Pedro Caal Mux a Técnico Senior');

INSERT INTO auditoria (tabla_afectada, operacion, id_registro, usuario_db, fecha_hora, detalle)
VALUES ('empleados', 'INSERT', 9, 'admin_central', TIMESTAMP '2025-04-01 08:00:00', 'Alta de empleado Andrés Pop Choc en Sucursal Capital');

INSERT INTO auditoria (tabla_afectada, operacion, id_registro, usuario_db, fecha_hora, detalle)
VALUES ('proveedores', 'INSERT', 5, 'admin_central', TIMESTAMP '2025-04-15 11:30:00', 'Registro de proveedor Xiaomi Latam Guatemala');

INSERT INTO auditoria (tabla_afectada, operacion, id_registro, usuario_db, fecha_hora, detalle)
VALUES ('empleados', 'INSERT', 10, 'admin_central', TIMESTAMP '2025-05-10 09:45:00', 'Alta de empleada Diana Cuc Ich en Sucursal Capital');

INSERT INTO auditoria (tabla_afectada, operacion, id_registro, usuario_db, fecha_hora, detalle)
VALUES ('proveedores', 'UPDATE', 2, 'admin_central', TIMESTAMP '2025-06-20 16:00:00', 'Actualización de email de iDistribuidores S.A.');

INSERT INTO auditoria (tabla_afectada, operacion, id_registro, usuario_db, fecha_hora, detalle)
VALUES ('empleados', 'UPDATE', 1, 'admin_central', TIMESTAMP '2025-11-01 08:00:00', 'Actualización de salario anual Gerente General');

COMMIT;
