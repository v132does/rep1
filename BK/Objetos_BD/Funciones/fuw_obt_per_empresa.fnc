CREATE OR REPLACE FUNCTION IT.fuw_obt_per_empresa(p_cod_empresa IN ba_personas.cod_persona%TYPE,
                                               p_cod_persona IN ba_personas.cod_persona%TYPE) 
                                               RETURN VARCHAR2 IS
  v_retorno ba_vinculos.cod_perfil%TYPE;
BEGIN
  SELECT v.cod_perfil
    INTO v_retorno
    FROM ba_vinculos v
   WHERE v.cod_persona = p_cod_empresa
     AND v.cod_per_vinculo = p_cod_persona
     AND v.cod_perfil IS NOT NULL;

  RETURN v_retorno;
EXCEPTION
   WHEN OTHERS THEN
      RETURN NULL;
END;
/

