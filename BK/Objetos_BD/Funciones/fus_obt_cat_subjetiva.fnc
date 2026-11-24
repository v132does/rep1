CREATE OR REPLACE FUNCTION IT.fus_obt_cat_subjetiva(p_cod_persona IN ge_clientes.cod_persona%TYPE)
   RETURN NUMBER IS
    v_cat_subjetiva ge_clientes.cat_subjetiva%TYPE;
BEGIN
   SELECT cat_subjetiva
     INTO v_cat_subjetiva
     FROM ge_clientes
    WHERE cod_persona = p_cod_persona;

   RETURN v_cat_subjetiva;
EXCEPTION
   WHEN OTHERS THEN
      RETURN NULL;
END;
/

