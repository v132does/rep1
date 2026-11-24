CREATE OR REPLACE FUNCTION IT.fue_obt_raz_social(p_cod_empresa IN ba_per_juridicas.cod_persona%TYPE) RETURN VARCHAR2 IS
  v_retorno ba_per_juridicas.raz_social%TYPE;
BEGIN
   SELECT p.raz_social
     INTO v_retorno
     FROM ba_per_juridicas p
    WHERE p.cod_persona = p_cod_empresa;  
   RETURN v_retorno;  
EXCEPTION
  WHEN OTHERS THEN
     RETURN NULL;
END;
/

