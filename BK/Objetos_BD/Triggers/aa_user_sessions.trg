CREATE OR REPLACE TRIGGER IT.AA_USER_SESSIONS
  AFTER DELETE OR UPDATE or INSERT
     ON USERS_SESSIONS
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado DBA PRODUCCION
  || (c) 2018 - BBVA PARAGUAY
  || Generado el 16/03/2018
  */
v_dir_correo varchar2(50) :=fug_obt_pardinamico('CAM_MAR_DIR_SEGLOG');

BEGIN

  IF updating THEN
    INSERT INTO us_auditoria VALUES(SYS_CONTEXT('USERENV', 'AUTHENTICATED_IDENTITY'), SYS_CONTEXT('USERENV', 'HOST'), SYSDATE, SYS_CONTEXT('USERENV', 'OS_USER'),'MODIFICA');
    if v_dir_correo is not null then
            it_mail.mail(fug_obt_pardinamico('CAM_MAR_DIR_DBA'),  
                       v_dir_correo, 
                       'Modificacion tabla USERS_SESSIONS ITGF',
                       'El usuario '||USER||' realizo una modificación en la tabla');
          end if;             

  ELSIF deleting THEN
    INSERT INTO us_auditoria VALUES(SYS_CONTEXT('USERENV', 'AUTHENTICATED_IDENTITY'), SYS_CONTEXT('USERENV', 'HOST'), SYSDATE, SYS_CONTEXT('USERENV', 'OS_USER'),'ELIMINA');
    if v_dir_correo is not null then
            it_mail.mail(fug_obt_pardinamico('CAM_MAR_DIR_DBA'),  
                       v_dir_correo, 
                       'Elimino registro de la tabla USERS_SESSIONS ITGF',
                       'El usuario '||USER||' realizo una eliminacion en la tabla');
          end if;    
  END IF;

END;
/

