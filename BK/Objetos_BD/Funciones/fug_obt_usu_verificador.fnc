create or replace function it.FUG_OBT_USU_VERIFICADOR(
   p_cod_programa in ba_programas.cod_programa%type
  ,p_cod_usuario in ba_usuarios.cod_usuario%type)
   return varchar2 is
   v_cod_usu_verificador ba_usuarios.cod_usuario%type;
begin
   select distinct usa.cod_usuario
     into v_cod_usu_verificador
     from ba_usuarios usu, ba_rol_programas rpr, ba_usu_roles url, ba_usuarios usa
    where rpr.cod_programa = p_cod_programa
      and rpr.cod_rol = url.cod_rol
      and url.cod_usuario = usa.cod_usuario
      and usa.cod_oficina = usu.cod_oficina
      and usu.cod_usuario = p_cod_usuario
      and fue_ver_sesion(usa.cod_usuario) = 'A'  -- solo el que esta activo
      and rownum = 1;
   return v_cod_usu_verificador;
exception
   when no_data_found then
      return NULL;
   when too_many_rows then
        return NULL;
end;
/

