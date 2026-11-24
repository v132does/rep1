create or replace function it.FUG_OBT_OFI_USUARIO
  ( P_COD_USUARIO IN VARCHAR2 )
  return varchar2 is
  v_oficina ba_usuarios.cod_oficina%type;
begin
  -- Recupera la oficina en la que se encuentra el usuario
  select cod_oficina
    into v_oficina
    from ba_usuarios c
   where c.cod_usuario = p_cod_usuario;
  return(v_oficina);
exception
  when no_data_found then
    v_oficina := null;
    return v_oficina;
  when others then
     raise_application_error(-20000,'FUG_OBT_OFI_USUARIO'||sqlerrm);
end FUG_OBT_OFI_USUARIO;
/

