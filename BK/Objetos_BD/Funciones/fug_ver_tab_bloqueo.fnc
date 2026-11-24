CREATE OR REPLACE FUNCTION it.fug_ver_tab_bloqueo(p_tabla IN VARCHAR2,
                                                  p_campo        VARCHAR,
                                                  p_valor        NUMBER)
  RETURN BOOLEAN IS
  v_situacion VARCHAR2(1);
BEGIN
  -- Intenta seleccionar una fila de la tabla con NOWAIT para p_tabla con un bloqueo de fila.
  -- Si la tabla está bloqueada por DDL o un bloqueo de tabla, esto fallará.
  EXECUTE IMMEDIATE 'SELECT 1 FROM ' || p_tabla || ' WHERE ' ||P_CAMPO || ' = ' || P_VALOR || ' FOR UPDATE NOWAIT'
    INTO v_situacion;
  RETURN FALSE;
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE = -54 THEN
      RETURN TRUE;
    ELSE
      RAISE;
    END IF;
END;
 
/