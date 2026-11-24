CREATE OR REPLACE FUNCTION IT.fug_obt_cli_telefono(p_cod_area     IN ba_telefonos.area%TYPE,
                                                p_nro_telefono IN ba_telefonos.telefono%TYPE) RETURN VARCHAR2 IS
  v_result ba_telefonos.cod_persona%TYPE;
BEGIN
   SELECT t.cod_persona
     INTO v_result
     FROM ba_telefonos t
    WHERE t.area = p_cod_area
      AND t.telefono = p_nro_telefono
      AND t.principal = 'S'
      AND rownum = 1;
  RETURN v_result;
EXCEPTION
   WHEN OTHERS THEN
      RETURN NULL;
END;
/

