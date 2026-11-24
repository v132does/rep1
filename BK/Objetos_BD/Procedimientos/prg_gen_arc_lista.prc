CREATE OR REPLACE PROCEDURE IT.prg_gen_arc_lista IS
 -- Requerimiento: CNFNORMA-65
 -- Fecha: 07/10/2016
  v_eol     CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen  CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_fec_sist DATE := pag_cal.FU_OBT_FEC_ACTUAL(1);
  v_fecha    VARCHAR2(8):= to_char(v_fec_sist, 'DDMMYYYY');

  -- Variables para mail
  v_conn      utl_smtp.connection;
  v_para      VARCHAR2(4000) := fug_obt_pardinamico('DIR_MAIL_CUMPLIMIENTO');
  v_asunto    VARCHAR2(2000);
  v_mje_mail  VARCHAR2(4000);
  v_hini_mail ge_ra_log_mail.hor_inicio%type;
  v_hfin_mail ge_ra_log_mail.hor_fin%type;
  v_det_error ge_ra_log_mail.det_error%type;
  v_mensaje   VARCHAR2(4000);
  v_nom_arc1  varchar2(128);
  v_nom_arc2  varchar2(128);

  -- Variables conexion
  v_repository         VARCHAR2(100) := 'MAIL';
  v_env_mail           VARCHAR2(100) := fug_obt_dir_correo;
  v_ip                 VARCHAR2(100) := fug_obt_pardinamico('DIR_SVR_REP_ARCHIVOS');
  v_port               VARCHAR2(100) := '21';
  v_user               VARCHAR2(100) := fug_obt_pardinamico('USU_FTP_REP_ARCHIVOS');
  v_pass               VARCHAR2(100) := fug_obt_pardinamico('PAS_FTP_REP_ARCHIVOS');
  v_compartido         VARCHAR2(100) := '\\'||v_ip||'\';
  v_cumplimiento       VARCHAR2(100) := 'ramail\Cumplimiento\';
  -- Cursores
  CURSOR cu_lista IS
    SELECT distinct(upper(fug_eli_acentos(t.nombre)))nombre,
           t.nom_lista,
           t.cod_persona
     FROM ge_per_listas_tmp t
       WHERE t.exi_bbva = 'S'
         and t.nombre is not null
      order by 1 asc;
  --
    CURSOR cu_nacionalidad IS
      SELECT distinct(upper(t.nacionalidad))nacionalidad,
             f.cod_persona,
             t.nom_lista
       FROM ge_per_listas_tmp t,
            ba_paises p,
            ba_personas f
         WHERE upper(t.nacionalidad) = p.descripcion
           and p.cod_pais = f.cod_pais
           and t.nacionalidad is not null
       order by upper(t.nacionalidad);
  --
  CURSOR ba_paises(p_nacionalidad varchar2) IS
    SELECT p.nacionalidad
      FROM ba_paises p
     WHERE instr(p_nacionalidad, p.nacionalidad) > 0;
  --
  procedure lp_gen_arc_nombre is
    v_file    UTL_FILE.FILE_TYPE;
    v_line    VARCHAR2(32767);
    v_linetit VARCHAR2(2000);
    v_buffer  VARCHAR2(32767);
    v_name    VARCHAR2(128) := 'COMPARACION_LISTAS'; -- nombre del archivo
    v_lines   PLS_INTEGER := 0;
    v_cont    PLS_INTEGER := 0;
    -- Variables para FTP
    v_respuesta VARCHAR2(4000);
    v_hini_ftp  ge_ra_log_ftp.hor_inicio%type;
    v_hfin_ftp  ge_ra_log_ftp.hor_fin%type;
    begin
      -- Obtenemos la fecha del sistema
      -- Abrir archivo
      v_file := UTL_FILE.FOPEN(v_repository,
                               v_name || '.xls',
                               'W',
                               32767);

      -- Colocar el titulo a los campos
      v_linetit := 'ORDEN' || CHR(9) ||
                   'NOM_LISTA' || CHR(9) ||
                   'NOMBRE' ||CHR(9) ||
                   'COD_PERSONA';

      utl_file.put_line(v_file, v_linetit);

      --Definir un cursor for loop que recorre los datos obtenidos
      FOR REC IN cu_lista LOOP
          v_cont := v_cont+1;

        --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
        v_line := to_char(v_cont) || chr(9) ||
                  to_char(rec.nom_lista) || chr(9) ||
                  to_char(rec.nombre) || chr(9) ||
                  to_char(rec.cod_persona);

        IF LENGTH(v_buffer) + v_eollen + LENGTH(v_line) <= v_maxline THEN
          v_buffer := v_buffer || v_eol || v_line;
        ELSE
          IF v_buffer IS NOT NULL THEN
            --Escribes la linea en el fichero
            UTL_FILE.PUT_LINE(v_file, v_buffer);
          END IF;
          v_buffer := v_line;
        END IF;

        v_lines := v_lines + 1;

      END LOOP;
      --Escribes la linea en el fichero
      UTL_FILE.PUT_LINE(v_file, v_buffer);

      --Cerrar el handler al fichero
      UTL_FILE.FCLOSE(v_file);

      v_hini_ftp := to_char(sysdate, 'hh24:mi:ss');
      v_nom_arc1 := v_name || '_' ||v_fecha || '.xls';
      -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
      v_respuesta := pa_file_ftp.fu_put_ascii(v_ip,
                                              v_port,
                                              v_user,
                                              v_pass,
                                              v_repository,
                                              v_name||'.xls',
                                              v_cumplimiento || v_nom_arc1);
      v_mensaje := v_respuesta;
      v_hfin_ftp := to_char(sysdate, 'hh24:mi:ss');
  EXCEPTION
    WHEN UTL_FILE.INVALID_OPERATION THEN
      UTL_FILE.FCLOSE(v_file);

     INSERT INTO ge_ra_log_mail
        (fec_envio, nom_archivo, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
      VALUES
        (SYSDATE, v_nom_arc1, v_para, v_asunto, 'Operacion invalida ', v_hini_mail, v_hfin_mail);
    WHEN UTL_FILE.INVALID_FILEHANDLE THEN
      UTL_FILE.FCLOSE(v_file);
    INSERT INTO ge_ra_log_mail
        (fec_envio, nom_archivo, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
      VALUES
        (SYSDATE, v_nom_arc1, v_para, v_asunto, 'Manejador invalido ', v_hini_mail, v_hfin_mail);
    WHEN UTL_FILE.WRITE_ERROR THEN
      UTL_FILE.FCLOSE(v_file);
     INSERT INTO ge_ra_log_mail
        (fec_envio, nom_archivo, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
      VALUES
        (SYSDATE, v_nom_arc1, v_para, v_asunto, 'Error de escritura ' , v_hini_mail, v_hfin_mail);
    WHEN UTL_FILE.INVALID_MODE THEN
      UTL_FILE.FCLOSE(v_file);
     INSERT INTO ge_ra_log_mail
        (fec_envio, nom_archivo, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
      VALUES
        (SYSDATE, v_nom_arc1, v_para, v_asunto, 'Modo invalido ' , v_hini_mail, v_hfin_mail);
    WHEN UTL_FILE.INTERNAL_ERROR THEN
      UTL_FILE.FCLOSE(v_file);
     INSERT INTO ge_ra_log_mail
        (fec_envio, nom_archivo, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
      VALUES
        (SYSDATE, v_nom_arc1, v_para, v_asunto, 'Internal Error ', v_hini_mail, v_hfin_mail);
    WHEN OTHERS THEN
      UTL_FILE.FCLOSE(v_file);
      INSERT INTO ge_ra_log_mail
        (fec_envio, nom_archivo, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
      VALUES
        (SYSDATE, v_nom_arc1, v_para, v_asunto, 'Error Desconocido ', v_hini_mail, v_hfin_mail);
      IF v_respuesta <> 'OK' then
             -- ERROR AL ENVIAR ARCHIVO POR FTP
        v_det_error := null;

        -- Insertamos el error del envio al directorio compartido
        INSERT INTO ge_ra_log_ftp
          (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
        VALUES
          (SYSDATE,
           v_nom_arc1,
           v_respuesta,
           v_hini_ftp,
           v_hfin_ftp);

        --Enviamos el mail
        -- Damos valor a los demas datos
        v_asunto   := 'Error Comparación de Listas con Clientes ' ||
                      v_fec_sist || '.';
        v_mje_mail := 'Error al enviar archivo por FTP.

        Error: ' || v_respuesta || '.

        Para mas información verificar la tabla GE_RA_LOG_FTP';

        v_hini_mail := to_char(sysdate, 'hh24:mi:ss');

        BEGIN
          v_conn := it_mail.begin_mail(v_env_mail,
                                       v_para,
                                       v_asunto,
                                       IT_MAIL.MULTIPART_MIME_TYPE);
          it_mail.attach_text(v_conn, v_mje_mail, 'text/plain');
          it_mail.end_mail(v_conn);
        EXCEPTION
          when utl_smtp.transient_error or utl_smtp.permanent_error then
            begin
              utl_smtp.quit(v_conn);
            exception
              when utl_smtp.transient_error or utl_smtp.permanent_error then
                null;
            end;
            v_det_error := substr(sqlerrm, 1, 4000);
        END;

        v_hfin_mail := to_char(sysdate, 'hh24:mi:ss');

        -- Insertamos en la tabla de log  si ocurrio algun error al enviar el mail
        IF v_det_error is not null THEN
          INSERT INTO ge_ra_log_mail
            (fec_envio,
             nom_archivo,
             dir_correo,
             mensaje,
             det_error,
             hor_inicio,
             hor_fin)
          VALUES
            (SYSDATE,
             v_nom_arc1,
             v_para,
             v_asunto,
             v_det_error,
             v_hini_mail,
             v_hfin_mail);
        end if;
     end if;
    end lp_gen_arc_nombre;
  --
  procedure lp_gen_arc_nacionalidad is
    v_file    UTL_FILE.FILE_TYPE;
    v_line    VARCHAR2(32767);
    v_linetit VARCHAR2(2000);
    v_buffer  VARCHAR2(32767);
    v_name    VARCHAR2(128) := 'COMP_NAC_LISTAS'; -- nombre del archivo
    v_lines   PLS_INTEGER := 0;
    v_cont    PLS_INTEGER := 0;
    -- Variables para FTP
    v_respuesta VARCHAR2(4000);
    v_hini_ftp  ge_ra_log_ftp.hor_inicio%type;
    v_hfin_ftp  ge_ra_log_ftp.hor_fin%type;
    begin
      -- Obtenemos la fecha del sistema
      -- Abrir archivo
      v_file := UTL_FILE.FOPEN(v_repository,
                               v_name || '.xls',
                               'W',
                               32767);

      -- Colocar el titulo a los campos
      v_linetit := 'ORDEN' || CHR(9) ||
                   'NOM_LISTA' ||CHR(9) ||
                   'NACIONALIDAD' ||CHR(9) ||
                   'COD_PERSONA';
      utl_file.put_line(v_file, v_linetit);

      --Definir un cursor for loop que recorre los datos obtenidos
      FOR REC IN cu_nacionalidad LOOP
         v_cont := v_cont+1;

        --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
        v_line := to_char(v_cont) || chr(9)||
                  to_char(rec.Nom_Lista) || chr(9)||
                  to_char(rec.nacionalidad) || chr(9) ||
                  to_char(rec.cod_persona);

        IF LENGTH(v_buffer) + v_eollen + LENGTH(v_line) <= v_maxline THEN
          v_buffer := v_buffer || v_eol || v_line;
        ELSE
          IF v_buffer IS NOT NULL THEN
            --Escribes la linea en el fichero
            UTL_FILE.PUT_LINE(v_file, v_buffer);
          END IF;
          v_buffer := v_line;
        END IF;

        v_lines := v_lines + 1;

      END LOOP;
      --Escribes la linea en el fichero
      UTL_FILE.PUT_LINE(v_file, v_buffer);

      --Cerrar el handler al fichero
      UTL_FILE.FCLOSE(v_file);

      v_hini_ftp := to_char(sysdate, 'hh24:mi:ss');
      v_nom_arc2 := v_name || '_' ||v_fecha || '.xls';
      -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
      v_respuesta := pa_file_ftp.fu_put_ascii(v_ip,
                                              v_port,
                                              v_user,
                                              v_pass,
                                              v_repository,
                                              v_name||'.xls',
                                              v_cumplimiento || v_nom_arc2);
      v_mensaje := v_respuesta;
      v_hfin_ftp := to_char(sysdate, 'hh24:mi:ss');
  EXCEPTION
    WHEN UTL_FILE.INVALID_OPERATION THEN
      UTL_FILE.FCLOSE(v_file);

     INSERT INTO ge_ra_log_mail
        (fec_envio, nom_archivo, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
      VALUES
        (SYSDATE, v_nom_arc2, v_para, v_asunto, 'Operacion invalida ', v_hini_mail, v_hfin_mail);
    WHEN UTL_FILE.INVALID_FILEHANDLE THEN
      UTL_FILE.FCLOSE(v_file);
    INSERT INTO ge_ra_log_mail
        (fec_envio, nom_archivo, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
      VALUES
        (SYSDATE, v_nom_arc2, v_para, v_asunto, 'Manejador invalido ', v_hini_mail, v_hfin_mail);
    WHEN UTL_FILE.WRITE_ERROR THEN
      UTL_FILE.FCLOSE(v_file);
     INSERT INTO ge_ra_log_mail
        (fec_envio, nom_archivo, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
      VALUES
        (SYSDATE, v_nom_arc2, v_para, v_asunto, 'Error de escritura ' , v_hini_mail, v_hfin_mail);
    WHEN UTL_FILE.INVALID_MODE THEN
      UTL_FILE.FCLOSE(v_file);
     INSERT INTO ge_ra_log_mail
        (fec_envio, nom_archivo, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
      VALUES
        (SYSDATE, v_nom_arc2, v_para, v_asunto, 'Modo invalido ' , v_hini_mail, v_hfin_mail);
    WHEN UTL_FILE.INTERNAL_ERROR THEN
      UTL_FILE.FCLOSE(v_file);
     INSERT INTO ge_ra_log_mail
        (fec_envio, nom_archivo, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
      VALUES
        (SYSDATE, v_nom_arc2, v_para, v_asunto, 'Internal Error ', v_hini_mail, v_hfin_mail);
    WHEN OTHERS THEN
      UTL_FILE.FCLOSE(v_file);
      INSERT INTO ge_ra_log_mail
        (fec_envio, nom_archivo, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
      VALUES
        (SYSDATE, v_nom_arc2, v_para, v_asunto, 'Error Desconocido ', v_hini_mail, v_hfin_mail);
      IF v_respuesta <> 'OK' then
             -- ERROR AL ENVIAR ARCHIVO POR FTP
        v_det_error := null;

        -- Insertamos el error del envio al directorio compartido
        INSERT INTO ge_ra_log_ftp
          (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
        VALUES
          (SYSDATE,
           v_nom_arc2,
           v_respuesta,
           v_hini_ftp,
           v_hfin_ftp);

        --Enviamos el mail
        -- Damos valor a los demas datos
        v_asunto   := 'Error Comparación de Listas con Clientes ' ||
                      v_fec_sist || '.';
        v_mje_mail := 'Error al enviar archivo por FTP.

        Error: ' || v_respuesta || '.

        Para mas información verificar la tabla GE_RA_LOG_FTP';

        v_hini_mail := to_char(sysdate, 'hh24:mi:ss');

        BEGIN
          v_conn := it_mail.begin_mail(v_env_mail,
                                       v_para,
                                       v_asunto,
                                       IT_MAIL.MULTIPART_MIME_TYPE);
          it_mail.attach_text(v_conn, v_mje_mail, 'text/plain');
          it_mail.end_mail(v_conn);
        EXCEPTION
          when utl_smtp.transient_error or utl_smtp.permanent_error then
            begin
              utl_smtp.quit(v_conn);
            exception
              when utl_smtp.transient_error or utl_smtp.permanent_error then
                null;
            end;
            v_det_error := substr(sqlerrm, 1, 4000);
        END;

        v_hfin_mail := to_char(sysdate, 'hh24:mi:ss');

        -- Insertamos en la tabla de log  si ocurrio algun error al enviar el mail
        IF v_det_error is not null THEN
          INSERT INTO ge_ra_log_mail
            (fec_envio,
             nom_archivo,
             dir_correo,
             mensaje,
             det_error,
             hor_inicio,
             hor_fin)
          VALUES
            (SYSDATE,
             v_nom_arc2,
             v_para,
             v_asunto,
             v_det_error,
             v_hini_mail,
             v_hfin_mail);
        end if;
     end if;
   end lp_gen_arc_nacionalidad;

BEGIN
  lp_gen_arc_nombre;
  lp_gen_arc_nacionalidad;
  IF v_mensaje = 'OK' THEN
    --ARCHIVO ENVIADO POR FTP
    -- Damos valor a los demas datos
    v_asunto   := 'Reporte Comparación de Listas con Clientes ' ||
                  v_fec_sist || '.';
    v_mje_mail := 'Archivo con los datos del reporte lo tiene disponible en la siguiente dirección: ' ||
                  v_compartido || v_cumplimiento || '

    Nombre Archivo: ' ||v_nom_arc1||', '|| v_nom_arc2;

    -- Enviamos el mail
    v_det_error := null;
    v_hini_mail := to_char(sysdate, 'hh24:mi:ss');

    BEGIN
      v_conn := it_mail.begin_mail(v_env_mail,
                                   v_para,
                                   v_asunto,
                                   IT_MAIL.MULTIPART_MIME_TYPE);
      it_mail.attach_text(v_conn, v_mje_mail, 'text/plain');
      it_mail.end_mail(v_conn);
    EXCEPTION
      when utl_smtp.transient_error or utl_smtp.permanent_error then
        begin
          utl_smtp.quit(v_conn);
        exception
          when utl_smtp.transient_error or utl_smtp.permanent_error then
            null;
        end;
        v_det_error := substr(sqlerrm, 1, 4000);
    END;

    v_hfin_mail := to_char(sysdate, 'hh24:mi:ss');

    -- Insertamos en la tabla de log  si ocurrio algun error al enviar el mail
    IF v_det_error is not null THEN
      INSERT INTO ge_ra_log_mail
        (fec_envio,
         nom_archivo,
         dir_correo,
         mensaje,
         det_error,
         hor_inicio,
         hor_fin)
      VALUES
        (SYSDATE,
         v_nom_arc1||', '||v_nom_arc2,
         v_para,
         v_asunto,
         v_det_error,
         v_hini_mail,
         v_hfin_mail);
    END IF;
  END IF;
END prg_gen_arc_lista;
/

