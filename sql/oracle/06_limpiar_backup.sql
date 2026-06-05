-- ============================================================
-- Oracle XE — Limpiar tablas de backup
-- TecnoChapina S.A.
-- Usar para resetear el estado antes de la demo.
-- ============================================================

-- Detalle primero (no tiene FK definida pero por orden lógico)
DELETE FROM detalle_ventas_backup;

-- Luego ventas
DELETE FROM ventas_backup;

COMMIT;

-- Verificar que quedaron vacías
SELECT 'ventas_backup'          AS tabla, COUNT(*) AS registros FROM ventas_backup
UNION ALL
SELECT 'detalle_ventas_backup',            COUNT(*) FROM detalle_ventas_backup;
