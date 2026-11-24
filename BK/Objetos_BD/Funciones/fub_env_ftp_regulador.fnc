CREATE OR REPLACE FUNCTION IT.fub_env_ftp_regulador
(
   p_proceso IN NUMBER,
   p_archivo IN VARCHAR2
) RETURN VARCHAR2 IS
   --p_proceso: Código de Ente
   v_respuesta VARCHAR2(1000);

BEGIN
   v_respuesta := pa_file_ftp.fu_put_ascii(fug_obt_parentes(p_proceso, 'FTP_IP'),
                                           fug_obt_parentes(p_proceso, 'FTP_PUERTO'),
                                           fug_obt_parentes(p_proceso, 'FTP_USUARIO'),
                                           fug_obt_parentes(p_proceso, 'FTP_PASS'),
                                           fug_obt_parentes(p_proceso, 'DIR_ORACLE'),
                                           p_archivo,
                                           fug_obt_parentes(p_proceso, 'CAR_COMPARTIDA')||'/'/*TO-'*/||p_archivo);
   RETURN v_respuesta;
EXCEPTION
   WHEN OTHERS THEN
      raise_application_error(-20000, 'en fub_env_ftp_regulador. ' || SQLERRM);
END;
/

