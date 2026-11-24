CREATE OR REPLACE FUNCTION IT.fug_obt_con_columnas(p_filas IN VARCHAR2) RETURN VARCHAR2 IS
  v_variable1  VARCHAR2(4000);
  v_variable2 VARCHAR2(4000);
  v_cursor  sys_refcursor;
BEGIN
  OPEN v_cursor FOR p_filas;
  LOOP
    FETCH v_cursor INTO v_variable2;
    EXIT WHEN v_cursor%NOTFOUND;
    IF v_variable1 IS NULL THEN
      v_variable1 := v_variable2;
    ELSE
      v_variable1 := v_variable1 || ', ' || v_variable2;
    END IF;
  END LOOP;
  RETURN v_variable1;
END;
/

