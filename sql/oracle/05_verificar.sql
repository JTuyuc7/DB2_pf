-- ============================================================
-- Oracle XE — Verificación de tablas propias + backup
-- TecnoChapina S.A.
-- Ejecutar en DBeaver → conexión Oracle (admin_central / XEPDB1)
-- ============================================================

-- ── 1. Resumen de tablas propias de Oracle ──────────────────
SELECT 'empleados'   AS tabla, COUNT(*) AS registros FROM empleados
UNION ALL
SELECT 'proveedores',          COUNT(*) FROM proveedores
UNION ALL
SELECT 'auditoria',            COUNT(*) FROM auditoria;

-- ── 2. Estado de las tablas de backup (antes del backup: vacías) ──
--    Ejecutar ANTES de POST /backup-oracle para ver que están vacías.
--    Ejecutar DESPUÉS para confirmar que se llenaron.
SELECT
    'ventas_backup'             AS tabla,
    COUNT(*)                    AS registros,
    CASE
        WHEN COUNT(*) = 0 THEN 'SIN BACKUP — ejecutar POST /backup-oracle'
        ELSE 'CON BACKUP — ' || COUNT(*) || ' ventas copiadas desde SQL Server'
    END                         AS estado
FROM ventas_backup
UNION ALL
SELECT
    'detalle_ventas_backup',
    COUNT(*),
    CASE
        WHEN COUNT(*) = 0 THEN 'SIN BACKUP'
        ELSE 'CON BACKUP — ' || COUNT(*) || ' detalles copiados'
    END
FROM detalle_ventas_backup;

-- ── 3. Contenido del backup (si existe) ─────────────────────
--    Muestra las últimas 5 ventas copiadas a Oracle.
SELECT
    id_venta,
    id_cliente,
    id_empleado,
    sucursal_id,
    'Capital (Oracle backup)' AS fragmento_fisico,
    fecha_venta,
    total,
    estado,
    backup_ts
FROM ventas_backup
ORDER BY fecha_venta DESC;
-- FETCH FIRST 5 ROWS ONLY;

-- ── 4. Verificar que el backup cubre todas las ventas de Capital ──
--    Después del backup, este número debe coincidir con SQL Server.
SELECT
    COUNT(*)                    AS ventas_en_backup,
    MIN(fecha_venta)            AS primera_venta,
    MAX(fecha_venta)            AS ultima_venta,
    SUM(total)                  AS ingresos_totales
FROM ventas_backup
WHERE sucursal_id = 1;

-- ── 5. Sequences — ver próximos IDs para inserts en failover ─
SELECT
    sequence_name,
    last_number             AS ultimo_id_generado,
    increment_by
FROM user_sequences
WHERE sequence_name IN ('VENTAS_BACKUP_SEQ', 'DETALLE_VENTAS_BACKUP_SEQ');
