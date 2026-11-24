CREATE OR REPLACE PROCEDURE IT.PRT_ACT_MOV_INFONET IS
   
BEGIN
   DBMS_MVIEW.REFRESH('GV_MOV_INFONET');
   
   PRG_ENV_MAIL( fug_obt_dir_correo,
                 fug_obt_pardinamico('EMAIL_MOV_INFONET'),
                 'Aviso de Finalización de Procedimiento. ',
                 'El procedimiento para el refresh de la vista ' || chr(10) ||
                 'materializada de movimientos de infonet terminó correctamente ' || chr(10) || chr(10) ||
                 'DYD - Desarrollo de Negocios. ' );
    
EXCEPTION
   WHEN OTHERS THEN
      raise_application_error(-20000,
                              'Error de actualización de vista GV_MOV_INFONET '||' '||
                               SQLERRM);
END;
/

