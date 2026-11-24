CREATE OR REPLACE FUNCTION IT.fug_obt_plz_descripcion(p_can_dias IN ge_plz_contables.can_dias%TYPE)
   RETURN VARCHAR2 IS
   v_plazo     ge_plz_contables.descripcion%TYPE;
   v_cod_plazo ge_plz_contables.cod_plazo%TYPE;
BEGIN
   SELECT descripcion, to_char(cod_plazo)
     INTO v_plazo, v_cod_plazo
     FROM ge_plz_contables
    WHERE can_dias = (SELECT MIN(can_dias) FROM ge_plz_contables WHERE can_dias >= (p_can_dias));

   RETURN(v_cod_plazo || ' ' || v_plazo);
EXCEPTION
   WHEN no_data_found THEN
      RETURN(NULL);
END;
/

