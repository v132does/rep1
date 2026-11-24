CREATE OR REPLACE FUNCTION IT.fus_obt_cat_riesgo(p_cod_persona IN ge_clientes.cod_persona%TYPE)
   RETURN NUMBER IS
   v_cat_riesgo ge_clientes.cat_riesgo%TYPE;
BEGIN
   SELECT cat_automatica INTO v_cat_riesgo FROM ge_clientes WHERE cod_persona = p_cod_persona;

   RETURN v_cat_riesgo; ---- retorna la categoria de riego 
EXCEPTION
  WHEN OTHERS THEN
    RETURN NULL;   
END;
/

