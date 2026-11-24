CREATE OR REPLACE FUNCTION IT.FUG_ENV_FTP
    (
      v_origen     IN varchar2,
      v_archivo    IN varchar2,
      v_destino    IN varchar2,
      v_nombre     IN varchar2
    )
    RETURN  varchar2 IS

  -- Proposito: Retorna valor de envio de archivos por FTP
  -- Precondición:  los parámetros no deben ser nulos
  -- Poscondicion: devuelve un valor de error cuando el envio no se produjo y un valor 'OK' en caso de envio satisfactorio por FTP

     v_valor     varchar2(4000);

     --CRO-MB-05/2015: CROMIGDS-3 => Migración de Directorios de un Servidor a Otro
	 --v_ip          pa_rep_aut.g_ip%type   := '192.168.254.136';
     v_ip          pa_rep_aut.g_ip%type   := fug_obt_pardinamico('DIR_SVR_REP_ARCHIVOS');
	 v_port        pa_rep_aut.g_port%type := '21';
     --CRO-MB-05/2015: CROMIGDS-3 => Migración de Directorios de un Servidor a Otro
	 --v_user        pa_rep_aut.g_user%type := 'ftpramail';
	 v_user        pa_rep_aut.g_user%type := fug_obt_pardinamico('USU_FTP_REP_ARCHIVOS');
     --CRO-MB-05/2015: CROMIGDS-3 => Migración de Directorios de un Servidor a Otro
	 --v_pass        pa_rep_aut.g_pass%type := 'kacha.ma1';
	 v_pass        pa_rep_aut.g_pass%type := fug_obt_pardinamico('PAS_FTP_REP_ARCHIVOS');

  BEGIN
    
    begin
      v_valor := pa_file_ftp.fu_put_ascii(v_ip,
                                          v_port,
                                          v_user,
                                          v_pass,
                                          v_origen,
                                          v_archivo,
                                          v_destino||v_nombre);
    exception
      when others then
           v_valor := 'ERROR AL ENVIAR ARCHIVO. '||SQLERRM;
    end;

     RETURN v_valor ;
  END;
/

