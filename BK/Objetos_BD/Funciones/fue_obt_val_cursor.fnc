CREATE OR REPLACE FUNCTION IT.FUE_OBT_VAL_CURSOR(P_CURSOR     IN NUMBER,
                                              P_COLUMNAS   IN dbms_sql.desc_tab2,
                                              P_SEP_CAMPOS IN VARCHAR2,
                                              P_SEP_TEXTO  IN VARCHAR2)
RETURN VARCHAR2 IS
  v_cadena VARCHAR2(2000) := '';
  v_valor  VARCHAR2(300);
BEGIN
  FOR i IN p_columnas.FIRST .. p_columnas.LAST LOOP
    dbms_sql.column_value(p_cursor, i, v_valor);
    v_cadena := v_cadena || p_sep_texto || v_valor || p_sep_texto || p_sep_campos;
  END LOOP;
  IF p_sep_campos IS NOT NULL THEN
    v_cadena := substr(v_cadena, 1, length(v_cadena) - 1);
  END IF;

  RETURN v_cadena;
END;
/

