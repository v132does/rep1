CREATE OR REPLACE FUNCTION IT.fue_obt_cod_pro_equivalente(p_cod_programa IN VARCHAR2) RETURN VARCHAR IS
   v_cod_pro_equivalente ba_programas.cod_pro_equivalente%TYPE;
BEGIN
   SELECT a.cod_pro_equivalente
     INTO v_cod_pro_equivalente
     FROM ba_programas a
    WHERE a.cod_programa = p_cod_programa;

   RETURN nvl(v_cod_pro_equivalente, p_cod_programa);
EXCEPTION
   WHEN no_data_found THEN
      RETURN nvl(v_cod_pro_equivalente, p_cod_programa);
END;
/

