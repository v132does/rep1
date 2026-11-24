create or replace procedure it.PRG_OBT_USU_VERIFICADOR(
   p_cod_programa in ba_programas.cod_programa%type
  ,p_cod_usuario in ba_usuarios.cod_usuario%type
  ,p_cod_usu_verificador out ba_usuarios.cod_usuario%type
  ,p_dir_correo out ba_usuarios.dir_correo%type
  ,p_cod_persona in ba_personas.cod_persona%type default null)
is
-- clientes empleados
cursor ver_empleados is
   select usa.cod_usuario, usa.dir_correo
     from ba_rol_programas rpr, ba_usu_roles url, ba_usuarios usa
    where rpr.cod_programa = p_cod_programa
      and rpr.cod_rol = url.cod_rol
      and url.cod_usuario = usa.cod_usuario
      and usa.ver_cta_empleados = 'S'
      and usa.cod_usuario <> 'IT' -- no tomar IT
      and rpr.actualiza = 'S' -- que pueda actualizar en el programa
    order by fue_ver_sesion(usa.cod_usuario); --primero los activos "A";
-- clientes normales
cursor ver_clientes is
   select usa.cod_usuario, usa.dir_correo
     from ba_usuarios usu, ba_rol_programas rpr, ba_usu_roles url, ba_usuarios usa
    where rpr.cod_programa = p_cod_programa
      and rpr.cod_rol = url.cod_rol
      and url.cod_usuario = usa.cod_usuario
      and usa.cod_oficina = usu.cod_oficina
      and usu.cod_usuario = p_cod_usuario
      and fue_ver_sesion(usa.cod_usuario) = 'A'  -- solo el que esta activo
      and usa.ver_cta_empleados = 'N'
      and usa.cod_usuario <> 'IT' -- no tomar IT
      and rpr.actualiza = 'S' -- que pueda actualizar en el programa
    order by fue_ver_sesion(usa.cod_usuario); --primero los activos "A";

begin
   if p_cod_persona is not null and fug_es_empleado(p_cod_persona) = 'S' then
      -- si es empleado
      open ver_empleados;
      fetch ver_empleados into p_cod_usu_verificador, p_dir_correo;
      close ver_empleados;
   else
       -- cualquier persona que no sea empleado
      open ver_clientes;
      fetch ver_clientes into p_cod_usu_verificador, p_dir_correo;
      close ver_clientes;
   end if;
exception
  when others then
     p_cod_usu_verificador := null;
     p_dir_correo := null;
end;
/

