CREATE OR REPLACE TRIGGER IT.AA_LOGON_TRIGGER
  AFTER DELETE OR UPDATE
     ON logon_trigger_tab
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado DBA PRODUCCION
  || (c) 2018 - BBVA PARAGUAY
  || Generado el 16/03/2018
  */
v_dir_correo varchar2(50) :=fug_obt_pardinamico('CAM_MAR_DIR_SEGLOG');--'seguridad_logica.py@bbva.com';

BEGIN

  IF updating THEN
    INSERT INTO tr_auditoria VALUES(SYS_CONTEXT('USERENV', 'AUTHENTICATED_IDENTITY'), SYS_CONTEXT('USERENV', 'HOST'), SYSDATE, SYS_CONTEXT('USERENV', 'OS_USER'),'MODIFICA');
    if v_dir_correo is not null then
            it_mail.mail(fug_obt_pardinamico('CAM_MAR_DIR_DBA'),
                       v_dir_correo,
                       'Modificacion tabla logon_trigger_tab ITGF',
                       'El usuario '||USER||' realizo una modificación en la tabla');
          end if;

  ELSIF deleting THEN
    INSERT INTO tr_auditoria VALUES(SYS_CONTEXT('USERENV', 'AUTHENTICATED_IDENTITY'), SYS_CONTEXT('USERENV', 'HOST'), SYSDATE, SYS_CONTEXT('USERENV', 'OS_USER'),'ELIMINA');
    if v_dir_correo is not null then
            it_mail.mail(fug_obt_pardinamico('CAM_MAR_DIR_DBA'),
                       v_dir_correo,
                       'Elimino registro de la tabla logon_trigger_tab ITGF',
                       'El usuario '||USER||' realizo una eliminacion en la tabla');
          end if;
  END IF;

END;
/

