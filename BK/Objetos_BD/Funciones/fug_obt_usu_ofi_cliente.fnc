create or replace function it.FUG_OBT_USU_OFI_CLIENTE
  ( P_COD_PERSONA IN VARCHAR2 )
  return varchar2 is
  v_cod_usu_oficial ge_clientes.cod_usu_oficial%type;
begin
  ---Recupera el oficial del cliente
  select cod_usu_oficial
    into v_cod_usu_oficial
    from ge_clientes c
   where c.cod_persona = p_cod_persona ;
  return v_cod_usu_oficial;
exception
  when no_data_found then
     return null;
  when others then
     raise_application_error(-20000,'FUG_OBT_USU_OFI_CLIENTE'||sqlerrm);
end FUG_OBT_USU_OFI_CLIENTE;
/

