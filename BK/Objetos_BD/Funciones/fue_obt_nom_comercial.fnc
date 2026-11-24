CREATE OR REPLACE FUNCTION IT.FUE_OBT_NOM_COMERCIAL(p_cod_empresa IN ba_per_juridicas.cod_persona%TYPE) RETURN VARCHAR2 IS
  v_retorno ba_per_juridicas.nom_comercial%TYPE;
BEGIN
   SELECT p.nom_comercial
     INTO v_retorno
     FROM ba_per_juridicas p
    WHERE p.cod_persona = p_cod_empresa;  
   RETURN v_retorno;  
EXCEPTION
  WHEN OTHERS THEN
     RETURN NULL;
END;
/

