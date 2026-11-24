CREATE OR REPLACE FUNCTION IT.fug_con_blo_session (
    p_tab_nombres IN VARCHAR2,
    p_tie_espera   IN NUMBER
) RETURN NUMBER
IS
    v_int_inicial   NUMBER := 0;
    v_int_maximo    NUMBER := 5;
    v_bloqueado     NUMBER := 0;
BEGIN
    WHILE (v_int_inicial < v_int_maximo) LOOP
        v_int_inicial := NVL(v_int_inicial, 0) + 1;
        EXECUTE IMMEDIATE
          'SELECT COUNT(*)
             FROM v$locked_object lo
             JOIN dba_objects o ON lo.object_id = o.object_id
            WHERE o.object_name IN (' || p_tab_nombres || ')'
        INTO v_bloqueado;
        IF NVL(v_bloqueado, 0) > 0 THEN
            DBMS_LOCK.SLEEP(p_tie_espera);
        ELSE
            -- Salir del bucle si no hay bloqueos
            EXIT;
        END IF;
    END LOOP;

    -- Retornar si hay bloqueos (1) o no (0)
    RETURN CASE WHEN v_bloqueado > 0 THEN 1 ELSE 0 END;
  EXCEPTION
     WHEN INVALID_NUMBER THEN
       v_bloqueado:=0;
       RETURN v_bloqueado; 
     WHEN NO_DATA_FOUND THEN
       v_bloqueado:=0;
       RETURN v_bloqueado; 
     WHEN OTHERS THEN
      v_bloqueado:=0;
      RETURN v_bloqueado;
END;
/
