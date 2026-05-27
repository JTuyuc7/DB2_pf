-- ============================================================
-- Oracle XE 21c — Sede Central (Administrativo)
-- TecnoChapina S.A.
-- PASO 1: Ejecutar como SYSTEM
-- ============================================================

-- 1. Tablespace dedicado para la sede central
--    Path real del contenedor gvenzl/oracle-xe (verificado con dba_data_files).
--    OMF no está habilitado en esta imagen, se requiere path absoluto.
CREATE TABLESPACE ts_central
  DATAFILE '/opt/oracle/oradata/XE/XEPDB1/ts_central.dbf'
  SIZE 50M
  AUTOEXTEND ON NEXT 10M
  MAXSIZE 200M;

-- 2. El usuario admin_central ya existe (creado por Docker via APP_USER).
--    Solo ajustamos tablespace por defecto y cuota.
ALTER USER admin_central DEFAULT TABLESPACE ts_central;
ALTER USER admin_central QUOTA UNLIMITED ON ts_central;

-- 3. Permisos necesarios para operar
GRANT CREATE SESSION  TO admin_central;
GRANT CREATE TABLE    TO admin_central;
GRANT CREATE SEQUENCE TO admin_central;
GRANT CREATE VIEW     TO admin_central;
GRANT CREATE TRIGGER  TO admin_central;
