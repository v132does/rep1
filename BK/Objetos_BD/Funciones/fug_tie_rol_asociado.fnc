create or replace function it.fug_tie_rol_asociado(p_cod_usuario IN VARCHAR2, p_cod_rol in varchar2) return varchar2 is
  Result varchar2(1) := 'N';
begin
  select 'S'
    into result
    from ba_usu_roles d
   where d.cod_rol = p_cod_rol
     and d.cod_usuario = p_cod_usuario;
  return result;
exception
  when no_data_found then
       return 'N';
  when others then
     raise_application_error(-20000,'fug_tie_rol_asociado '||sqlerrm);
end fug_tie_rol_asociado;
/

