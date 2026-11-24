create or replace function it.fue_obt_are_usuario(p_cod_usuario in ba_usuarios.cod_usuario%type)
   return varchar2 is
   v_cod_area ba_usuarios.cod_area%type;
begin
   select cod_area
     into v_cod_area
     from ba_usuarios
    where cod_usuario = p_cod_usuario;

   return v_cod_area;
exception
   when no_data_found then
      return null;
   when others then
      if sqlcode <= -20000 then
         raise;
      else
         raise_application_error(-20000, 'Error al buscar área en BA_USUARIOS :  ' || sqlerrm);
      end if;
end;
/

