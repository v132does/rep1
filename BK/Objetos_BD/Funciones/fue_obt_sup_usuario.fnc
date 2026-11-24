create or replace function it.fue_obt_sup_usuario(p_cod_usuario in ba_usuarios.cod_usuario%type)
   return varchar2 is
   v_cod_usu_supervisor ba_usuarios.cod_usu_supervisor%type;
begin
   select cod_usu_supervisor
     into v_cod_usu_supervisor
     from ba_usuarios
    where cod_usuario = p_cod_usuario;

   return v_cod_usu_supervisor;
exception
   when no_data_found then
      return null;
   when others then
      if sqlcode <= -20000 then
         raise;
      else
         raise_application_error(-20000, 'Error al buscar supervisor en BA_USUARIOS :  ' || sqlerrm);
      end if;
end;
/

