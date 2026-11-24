CREATE OR REPLACE PROCEDURE IT.PRG_CAM_CLAVE AUTHID DEFINER
AS
v_cod_usuario ba_seg_logica_tmp.cod_usuario%type;
v_perfil varchar2(50);
v_per_desbloqueo varchar2(50) := fug_obt_pardinamico('PER_USU_DESBLOQUEO');
v_procesa varchar2(1) := 'N';
Function fu_ver_perfil_user(p_cod_usuario in ba_usuarios.cod_usuario%type)
  return varchar2 is
  Begin
    /*Select upper(d.perfil)
       into v_perfil
      From sys.gv_user_perfil_bd d
     Where upper(d.cod_usuario) = upper(p_cod_usuario); */
     select upper(d.cod_rol)
       into v_perfil
     From ba_usu_roles d
     where upper(d.cod_usuario) = upper(p_cod_usuario);
     return v_perfil;
  Exception
     When no_data_found then 
       v_perfil:= 'Usuario no Existe';   
       return v_perfil;
     When others then
       v_perfil:= 'ERROR';   
       return v_perfil;
  End;
  Function fu_procesa(p_perfil in varchar2)
  return varchar2 is
  Begin
    Select 'S'
       into v_procesa
      From dual
     Where v_per_desbloqueo LIKE '%*'||ltrim(rtrim(p_perfil))||'*%';
     return v_procesa;
  Exception
     When no_data_found then 
       v_procesa := 'N';
       return v_procesa;
     When others then
       v_procesa := 'N';
       return v_procesa;
  End;    
BEGIN
  for x in (select * from ba_seg_logica_tmp) loop
      --if upper(x.cod_usuario) like '%PY%' or upper(x.cod_usuario) like '%XPG%' then
      v_perfil := fu_ver_perfil_user(upper(x.cod_usuario));
     --if v_per_desbloqueo = v_perfil then
      if fu_procesa(upper(v_perfil)) = 'S' then
       begin
             select a.cod_usuario into v_cod_usuario
             from ba_usuarios a
             where a.cod_usuario= upper(x.cod_usuario);
             if NVL(x.bloqueo,'N') ='S' then
                begin
                     EXECUTE IMMEDIATE 'ALTER USER '|| v_cod_usuario ||' ACCOUNT LOCK';
                exception
                when others then
                     raise_application_error(-20000, 'Error al bloquear'||upper(x.cod_usuario)||sqlerrm);
                end;
             else
               if x.new_password='N' then
                 begin
                     EXECUTE IMMEDIATE 'ALTER USER '|| v_cod_usuario ||' ACCOUNT UNLOCK';
                 exception
                 when others then
                     raise_application_error(-20000, 'Error al desbloquear'||upper(x.cod_usuario)||sqlerrm);
                 end;
               else
                 begin
                     EXECUTE IMMEDIATE 'ALTER USER '|| v_cod_usuario ||' ACCOUNT UNLOCK IDENTIFIED BY '||x.new_password || ' password expire';
                 exception
                 when others then
                     raise_application_error(-20000, 'Error al cambiar password y desbloquear usuario'||upper(x.cod_usuario)||sqlerrm);
                 end;
               end if;
             end if;
       exception
               when no_data_found then
                 raise_application_error(-20000, 'Codigo de usuario no registrado en BA_USUARIOS '||upper(x.cod_usuario)||sqlerrm);
               when others then
                 raise_application_error(-20000, 'Error al procesar '||sqlerrm);
        end;

      else
          --raise_application_error(-20000, 'Codigo de usuario no valido '||x.cod_usuario||sqlerrm);
          raise_application_error(-20000, 'El perfil del usuario '||upper(x.cod_usuario)||' es '||v_perfil||' este PERFIL no permite procesar!.'||sqlerrm);
      end if;
  END LOOP;


END PRG_CAM_CLAVE;
/

