-- =============================================================================
-- SRER-5499: ALTER TABLE GE_ARCHIVOS - agrega columna DIRECT_PATH
-- Requerido para soportar carga con DIRECT PATH en sqlldr (BCP_PERSONAS_REF)
-- =============================================================================
BEGIN
  EXECUTE IMMEDIATE 'ALTER TABLE IT.GE_ARCHIVOS ADD DIRECT_PATH VARCHAR2(1) DEFAULT ''N''';
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE = -1430 THEN NULL;  -- ORA-01430: columna ya existe, OK
    ELSE RAISE;
    END IF;
END;
/
