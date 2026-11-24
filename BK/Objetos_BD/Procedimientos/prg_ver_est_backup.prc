CREATE OR REPLACE PROCEDURE IT.PRG_VER_EST_BACKUP IS
  v_estado  tm_backup.estado%TYPE;
  v_db_name VARCHAR2(20);
BEGIN
  -- Obtiene el SID de la base de dato
  SELECT UPPER(SYS_CONTEXT('USERENV', 'DB_NAME'))
    INTO v_db_name
    FROM dual;

  IF v_db_name = 'REGIONAL' THEN
    -- Obtiene el estado del backup
    BEGIN
      SELECT estado
        INTO v_estado
        FROM tm_backup;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        v_estado := 1;
    END;
    
    -- Puede continuar solo despues de realizar el backup
    IF v_estado <> 2 THEN
      raise_application_error(-20000, 'Realice el BACKUP antes de continuar');
    END IF;
    
    -- Actualiza el estado del backup a 1 (no realizado)
    UPDATE tm_backup 
       SET estado = 1, 
           fecha  = SYSDATE;
  END IF;
END;
/

