CREATE OR REPLACE PROCEDURE IT.PRL_GEN_ARC_MSJ_SWIFT
( p_fecha IN ge_movimientos.fecha%TYPE,
  p_hora  IN ge_movimientos.hora%TYPE,
  p_rut_archivo IN varchar2) IS
--- Definicion de Variables --
  v_nom_archivo varchar2(100);
  v_err_dir     EXCEPTION;
  --
  v_file      utl_file.file_type;
  v_directorio    varchar2(100) := fug_obt_pardinamico('DIR_REP_FTP');
    -- Variables para FTP
  g_ip            VARCHAR2(100) := fug_obt_pardinamico('DIR_SVR_REP_ARCHIVOS');
  g_port          VARCHAR2(100) := fug_obt_pardinamico('PUERTO_FTP');
  g_user          VARCHAR2(100) := fug_obt_pardinamico('USU_FTP_REP_ARCHIVOS');
  g_pass          VARCHAR2(100) := fug_obt_pardinamico('PAS_FTP_REP_ARCHIVOS');
  v_respuesta varchar2(4000);
  v_hini_ftp varchar2(8);
  v_hfin_ftp varchar2(8);
  --
--- Cursor de transferencias a enviar --
--se agrega escape de caracter especial (tab) para evitar problemas en firma LAU DYDMR-16347  
  CURSOR transferencias IS
     select 'PYCOR'||nro_operacion||'.ICR'||'~'||TRANSLATE(msj_swift, CHR(9), ' ') mensaje,msj_swift,rowid fila
       from lc_transferencias a
      where estado = 'E'        --lo q se acaba de marcar como enviado
        and fec_envio = p_fecha
        and hor_envio = p_hora
      order by 1;

  BEGIN
  For reg in transferencias LOOP
  BEGIN
      If nvl(v_nom_archivo,'a') <> substr(reg.mensaje,1,instr(reg.mensaje,'~')-1) then
        IF UTL_FILE.IS_OPEN (v_file) THEN
               UTL_FILE.FCLOSE (v_file);
        End IF;
        v_nom_archivo := substr(reg.mensaje,1,instr(reg.mensaje,'~')-1);
        v_file := UTL_FILE.FOPEN(v_directorio, v_nom_archivo,'W',32767) ;
     End If;
   EXCEPTION
      when others then
        raise_application_error(-20000,'No se pudo abrir el archivo. Es posible que no tenga permisos sobre la 
                                        carpeta o que el archivo esté siendo utilizado por otro programa.'||chr(13)||
                                        p_rut_archivo||nvl(substr(reg.mensaje,1,instr(reg.mensaje,'~')-1),0)||sqlerrm);
    END;
      utl_file.put_line(v_file,substr(reg.mensaje,instr(reg.mensaje,'~')+1));

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
  End loop;
EXCEPTION
  when others then
     raise_application_error(-20000,'Error en PRL_GEN_ARC_MSJ_SWIFT '||sqlerrm);
END;
/

