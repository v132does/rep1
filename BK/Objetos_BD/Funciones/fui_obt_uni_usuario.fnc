create or replace function it.FUI_OBT_UNI_USUARIO
 (p_cod_usuario in ba_usuarios.cod_usuario%type) 
  return number is
  v_unidad number;
begin
  select cod_unidad
    into v_unidad
   from ba_usuarios a 
   where cod_usuario = p_cod_usuario;
    return v_unidad;
exception
  when no_data_found then
     return null;
  when others then
     raise_application_error(-20000,'FUI_OBT_UNI_USUARIO '||sqlerrm);
end;
/

