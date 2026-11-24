CREATE OR REPLACE FUNCTION IT.fuw_obt_perfil(p_cod_persona IN ba_personas.cod_persona%TYPE,
                                          p_cod_empresa IN ba_personas.cod_persona%TYPE) RETURN VARCHAR2 IS
  v_retorno bw_perfiles.cod_perfil%TYPE;
BEGIN
  if p_cod_empresa is not null then
     v_retorno := fuw_obt_per_empresa(p_cod_empresa, p_cod_persona);
  else
     select c.cod_perfil
       into v_retorno
       from ge_clientes c
      where c.cod_persona = p_cod_persona;
  end if;  
  
  return v_retorno;
EXCEPTION
   WHEN OTHERS THEN
      RETURN NULL;
END;
/

