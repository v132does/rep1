CREATE OR REPLACE TRIGGER IT.TA_CC_CHE_VENTANILLAS
 AFTER INSERT
 ON CC_CHE_VENTANILLAS
 FOR EACH ROW




DECLARE
-- Envio de mail al verificador
PROCEDURE LP_ENV_MAIL
  IS
  v_cod_usu_verificador ba_usuarios.cod_usuario%type;
  v_dir_correo          ba_usuarios.dir_correo%type;
  cursor ver_chequeras is
   select usa.cod_usuario, usa.dir_correo
     from ba_rol_programas rpr, ba_usu_roles url, ba_usuarios usa
    where rpr.cod_programa = 'CMSOLCHB'
      and rpr.cod_rol = url.cod_rol
      and url.cod_usuario = usa.cod_usuario
      and usa.ver_cta_empleados = 'S'
      and usa.cod_usuario <> 'IT' -- no tomar IT
      and rpr.actualiza = 'S' -- que pueda actualizar en el programa
    order by fue_ver_sesion(usa.cod_usuario),
             decode(usa.cod_usuario,'NOV','A',usa.cod_usuario);
BEGIN
    -- si es interna la cuenta
    open ver_chequeras;
    fetch ver_chequeras into v_cod_usu_verificador, v_dir_correo;
    close ver_chequeras;
    if v_cod_usu_verificador is not null then
      --- Enviar mail al verificador
      if v_dir_correo is not null then
        it_mail.mail(fug_obt_dir_correo,
                     v_dir_correo,
                     'Solicitud de Verificacion',
                     'El usuario '||USER||' solicita la Verificación de las Chequeras  Ventanilla.');
      end if;
    end if;

END;
---
BEGIN
   if inserting then
      -- envia mail al verificador solo
      lp_env_mail;
   end if;
END;
/

