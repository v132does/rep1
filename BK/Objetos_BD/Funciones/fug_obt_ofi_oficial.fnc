CREATE OR REPLACE FUNCTION IT.FUG_OBT_OFI_OFICIAL(p_cod_persona IN GE_CLIENTES.COD_PERSONA%TYPE)
RETURN NUMBER IS 
 v_oficina  ba_oficinas.cod_oficina%type;
BEGIN
      Select c.cod_oficina
        into v_oficina
        from ge_clientes b, ba_usuarios c
       Where b.cod_persona     = p_cod_persona
         and b.cod_usu_oficial = c.cod_usuario;
      return v_oficina;
EXCEPTION
  when no_data_found then
     v_oficina := null;
     return v_oficina;
  When others then
     raise_application_error(-20000,'Error al consultar oficina del gestor, persona '||p_cod_persona||'. '||SQLERRM);
End FUG_OBT_OFI_OFICIAL;
/

