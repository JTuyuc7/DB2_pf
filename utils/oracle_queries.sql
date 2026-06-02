-- ============================================================
-- Oracle XE 21c — Sede Central (Administrativo)
-- TecnoChapina S.A.
-- Conexión: system/OraclePass123 o admin_central/AdminPass123 → XEPDB1 (puerto 1521)
-- Tablas: empleados, proveedores, auditoria
-- ============================================================

-- ─────────────────────────────────
-- EMPLEADOS
-- ─────────────────────────────────

-- Todos los empleados
SELECT * FROM empleados ORDER BY id_empleado;

-- Empleados con nombre completo y sede
SELECT
    id_empleado,
    nombre || ' ' || apellido AS nombre_completo,
    email,
    puesto,
    sede,
    fecha_contratacion
FROM empleados
ORDER BY sede, apellido;

-- Empleados por sede
SELECT sede, COUNT(*) AS total
FROM empleados
GROUP BY sede
ORDER BY sede;

-- Empleados de Sede Central
SELECT * FROM empleados WHERE sede = 'Central';

-- Empleados de Sucursal Occidente
SELECT * FROM empleados WHERE sede = 'Occidente';

-- Empleados de Sucursal Capital
SELECT * FROM empleados WHERE sede = 'Capital';

-- Empleados con su supervisor (auto-join)
SELECT
    e.id_empleado,
    e.nombre || ' ' || e.apellido          AS empleado,
    e.puesto,
    s.nombre || ' ' || s.apellido          AS supervisor,
    s.puesto                               AS puesto_supervisor
FROM empleados e
LEFT JOIN empleados s ON e.id_supervisor = s.id_empleado
ORDER BY e.id_empleado;

-- Empleados sin supervisor (jefes / directivos)
SELECT id_empleado, nombre, apellido, puesto, sede
FROM empleados
WHERE id_supervisor IS NULL;

-- Buscar empleado por nombre (parcial, case-insensitive)
-- Reemplazar 'García' con el nombre a buscar
SELECT * FROM empleados
WHERE UPPER(nombre) LIKE UPPER('%García%')
   OR UPPER(apellido) LIKE UPPER('%García%');

-- Empleados contratados en el último año
SELECT * FROM empleados
WHERE fecha_contratacion >= ADD_MONTHS(SYSDATE, -12)
ORDER BY fecha_contratacion DESC;

-- ─────────────────────────────────
-- PROVEEDORES
-- ─────────────────────────────────

-- Todos los proveedores
SELECT * FROM proveedores ORDER BY nombre;

-- Proveedores con contacto y país
SELECT id_proveedor, nombre, contacto, email, telefono, pais
FROM proveedores
ORDER BY pais, nombre;

-- Proveedores por país
SELECT pais, COUNT(*) AS total
FROM proveedores
GROUP BY pais
ORDER BY total DESC;

-- Proveedores de Guatemala
SELECT * FROM proveedores WHERE pais = 'Guatemala';

-- ─────────────────────────────────
-- AUDITORÍA
-- ─────────────────────────────────

-- Todos los registros de auditoría (más recientes primero)
SELECT * FROM auditoria ORDER BY fecha_hora DESC;

-- Auditoría de los últimos 7 días
SELECT * FROM auditoria
WHERE fecha_hora >= SYSTIMESTAMP - INTERVAL '7' DAY
ORDER BY fecha_hora DESC;

-- Auditoría por operación (INSERT / UPDATE / DELETE)
SELECT operacion, COUNT(*) AS total
FROM auditoria
GROUP BY operacion
ORDER BY total DESC;

-- Auditoría por tabla afectada
SELECT tabla_afectada, operacion, COUNT(*) AS total
FROM auditoria
GROUP BY tabla_afectada, operacion
ORDER BY tabla_afectada, operacion;

-- Últimos 20 registros de auditoría
SELECT * FROM (
    SELECT * FROM auditoria ORDER BY fecha_hora DESC
) WHERE ROWNUM <= 20;

-- ─────────────────────────────────
-- ESTADÍSTICAS GENERALES
-- ─────────────────────────────────

-- Resumen de registros por tabla
SELECT 'empleados'   AS tabla, COUNT(*) AS total FROM empleados   UNION ALL
SELECT 'proveedores' AS tabla, COUNT(*) AS total FROM proveedores UNION ALL
SELECT 'auditoria'   AS tabla, COUNT(*) AS total FROM auditoria;
