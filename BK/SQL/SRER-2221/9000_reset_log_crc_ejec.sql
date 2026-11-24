BEGIN
  PRE_INI_APLICACION;
  PAE_CNF.G_COD_MODULO := 1;
END;
/
-------------------------------------------------------------------------------
-- 1) Limpiar tabla de log
-------------------------------------------------------------------------------
TRUNCATE TABLE IT.GE_LOG_CRC_EJEC;

-------------------------------------------------------------------------------
-- 2) Reiniciar secuencia
-------------------------------------------------------------------------------
DECLARE
  v_nextval NUMBER;
BEGIN
  SELECT IT.S_GE_LOG_CRC_EJEC.NEXTVAL
    INTO v_nextval
    FROM DUAL;

  EXECUTE IMMEDIATE
    'ALTER SEQUENCE IT.S_GE_LOG_CRC_EJEC INCREMENT BY -' || TO_CHAR(v_nextval - 1);

  SELECT IT.S_GE_LOG_CRC_EJEC.NEXTVAL
    INTO v_nextval
    FROM DUAL;

  EXECUTE IMMEDIATE
    'ALTER SEQUENCE IT.S_GE_LOG_CRC_EJEC INCREMENT BY 1';
END;
/
-------------------------------------------------------------------------------
-- 3) Verificación
-------------------------------------------------------------------------------
SELECT COUNT(*) AS CANT_LOG
  FROM IT.GE_LOG_CRC_EJEC;