CREATE OR REPLACE PROCEDURE IT.PRL_GEN_ARC_MSJ_SWIFT_199
( p_texto IN varchar2,
  p_rut_archivo IN varchar2) IS
--- Definicion de Variables -- 
  v_nom_archivo varchar2(100);
  v_err_dir     EXCEPTION;
  --
  v_file      utl_file.file_type;
  v_directorio    varchar2(100) := 'MAIL';
    -- Variables para FTP
  g_ip            VARCHAR2(100) := fug_obt_pardinamico('DIR_SVR_REP_ARCHIVOS');
  g_port          VARCHAR2(100) := '21';
  g_user          VARCHAR2(100) := fug_obt_pardinamico('USU_FTP_REP_ARCHIVOS');
  g_pass          VARCHAR2(100) := fug_obt_pardinamico('PAS_FTP_REP_ARCHIVOS');
  v_respuesta varchar2(4000);
  v_hini_ftp varchar2(8);
  v_hfin_ftp varchar2(8);
  --
  BEGIN
  BEGIN
      If nvl(v_nom_archivo,'a') <> substr(p_texto,1,instr(p_texto,'~')-1) then
        IF UTL_FILE.IS_OPEN (v_file) THEN
               UTL_FILE.FCLOSE (v_file);
        End IF;
        v_nom_archivo := substr(p_texto,1,instr(p_texto,'~')-1);
        v_file := UTL_FILE.FOPEN(v_directorio, v_nom_archivo,'W',32767) ;
     End If;
   EXCEPTION
      when others then
        raise_application_error(-20000,'No se pudo abrir el archivo. Es posible que no tenga permisos sobre la 
                                        carpeta o que el archivo esté siendo utilizado por otro programa.'||chr(13)||
                                        p_rut_archivo||nvl(substr(p_texto,1,instr(p_texto,'~')-1),0)||sqlerrm);
    END;
      utl_file.put_line(v_file,substr(p_texto,instr(p_texto,'~')+1));

        IF UTL_FILE.IS_OPEN (v_file) THEN
            UTL_FILE.FCLOSE(v_file);
        END IF;
        -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
        v_hini_ftp  := to_char(sysdate, 'hh24:mi:ss');
        v_respuesta := pa_file_ftp.fu_put_binary(g_ip,
                                                g_port,
                                                g_user,
                                                g_pass,
                                                v_directorio,
                                                v_nom_archivo,
                                                p_rut_archivo || v_nom_archivo);
        v_hfin_ftp  := to_char(sysdate, 'hh24:mi:ss');

       IF v_respuesta <> 'OK' THEN   -- ERROR AL ENVIAR ARCHIVO POR FTP
          -- Insertamos el error del envio al directorio compartido
          INSERT INTO ge_ra_log_ftp
          (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
          VALUES
          (SYSDATE, v_nom_archivo, v_respuesta, v_hini_ftp, v_hfin_ftp);
          COMMIT;
      END IF;
EXCEPTION
  when others then
     raise_application_error(-20000,'Error en PRL_GEN_ARC_MSJ_SWIFT_199'||sqlerrm);
END;
/

