CREATE OR REPLACE PACKAGE BODY IT.PAT_GOL IS

  --Fecha de implementacion del proyecto
  v_fecha_implementacion date := to_date(fug_obt_pardinamico('FEC_IMP_FUTBOL'), 'dd/mm/yyyy');

  FUNCTION fu_obt_mon_consumo(p_cod_persona in ba_personas.cod_persona%type,
                              p_periodo     in number) RETURN number IS
    v_monto ta_movimientos_his.monto%type;
  BEGIN
    select nvl(sum(b.monto), 0)
      into v_monto
      from ta_movimientos_his b
     where b.nro_cuenta in (select a.nro_cuenta
                              from ge_cta_clientes a
                             where a.cod_persona = p_cod_persona
                               and a.cod_modulo = 5)
       and to_char(b.fecha, 'MM/YYYY') between
           to_char(add_months(pag_cal.FU_OBT_FEC_ACTUAL(5), -p_periodo),
                   'MM/YYYY') and
           to_char(pag_cal.FU_OBT_FEC_ACTUAL(5), 'MM/YYYY');

    return v_monto;
  exception
    when no_data_found then
      return('');
  END;

  FUNCTION fu_obt_dat_cliente(p_cod_persona in ba_personas.cod_persona%type)
    RETURN varchar2 IS
    v_dat varchar2(4000);

  BEGIN

    select pag_gen.FU_ENC_PIN(b.cod_persona) || ';' ||
           c.pri_nombre || ';' ||c.seg_nombre || ';' || c.pri_apellido || ';' || c.seg_apellido || ';' ||
           to_char(c.fec_nacimiento, 'dd/mm/yyyy') || ';' ||
           'PRY'
      into v_dat
      from ba_personas b, ba_per_fisicas c
     where b.cod_persona = c.cod_persona
       and b.tipo = 'F'
       and b.cod_persona in
           (select ta.cod_persona
              from ta_cta_tarjetas tc, ta_tarjetas ta, ge_cta_clientes gc
             where tc.nro_cuenta = ta.nro_cuenta
               and gc.nro_cuenta = tc.nro_cuenta
               and gc.cod_persona = ta.cod_persona
                 and ta.nro_tarjeta in
                     (select x.nro_tarjeta
                        from ta_tarjetas x
                       where x.nro_cuenta = ta.nro_cuenta
                         and x.cod_persona = ta.cod_persona
                         and x.vigente = 'S'
                         and rownum = 1)
               and gc.relacion = 'P'
               and tc.estado <> 'C'
               and tc.cod_modalidad not in (55, 58, 501))
       and b.cod_persona = p_cod_persona;

    return v_dat;

  exception
    when no_data_found then
      begin
        select pag_gen.FU_ENC_PIN(b.cod_persona) || ';' || c.pri_nombre || ';' ||
               c.seg_nombre || ';' || c.pri_apellido || ';' || c.seg_apellido || ';' ||
               to_char(c.fec_nacimiento, 'dd/mm/yyyy') || ';' || 'PRY'
               into v_dat
          from ba_personas b, ba_per_fisicas c
         where b.cod_persona = c.cod_persona
           and b.tipo = 'F'
           and b.cod_persona in
               (select a.cod_persona
                  from ah_tar_debitos a
                 where exists (select *
                          from ah_cta_vistas b, ge_cta_clientes c
                         where b.nro_cuenta = c.nro_cuenta
                           and c.relacion = 'P'
                           and b.cod_modulo in (3)
                           and b.cod_modalidad in (31)
                           and b.nro_cuenta = a.nro_cuenta
                           and c.cod_persona = a.cod_persona)
                    or exists (select *
                          from cc_cta_corrientes b, ge_cta_clientes c
                         where b.nro_cuenta = c.nro_cuenta
                           and c.relacion = 'P'
                           and b.cod_modulo in (4)
                           and b.cod_modalidad in (41)
                           and b.nro_cuenta = a.nro_cuenta
                           and c.cod_persona = a.cod_persona))
            and b.cod_persona = p_cod_persona;
        return v_dat;
      exception
        when no_data_found then
          return ('');
     END;
  END;

  procedure pr_arc_cuentas IS
    v_file   UTL_FILE.FILE_TYPE;
    v_line   VARCHAR2(32767);
    --v_buffer VARCHAR2(32767);
    v_name   VARCHAR2(128) := 'PFB01.PRY.CONTRACTS.F'; -- nombre del archivo
    v_lines  PLS_INTEGER := 0;
    --v_eol     CONSTANT VARCHAR2(1) := CHR(10);
    --v_eollen  CONSTANT PLS_INTEGER := LENGTH(v_eol);
    --v_maxline CONSTANT PLS_INTEGER := 32767;

    v_final varchar2(100);

    -- Variables de fechas
    v_fec_sist DATE;
    v_fecha    VARCHAR2(8);

    -- Variables para mail

    v_conn      utl_smtp.connection;
    v_para      VARCHAR2(500);
    v_asunto    VARCHAR2(2000);
    v_mje_mail  VARCHAR2(4000);
    v_hini_mail ge_ra_log_mail.hor_inicio%type;
    v_hfin_mail ge_ra_log_mail.hor_fin%type;
    v_det_error ge_ra_log_mail.det_error%type;

    -- Variables para FTP

    v_respuesta VARCHAR2(4000);
    v_hini_ftp  ge_ra_log_ftp.hor_inicio%type;
    v_hfin_ftp  ge_ra_log_ftp.hor_fin%type;

    -- Variables coneccion

    g_repository     VARCHAR2(100) := 'MAIL';
    g_envia_mail     VARCHAR2(100) := 'bbvanet@bbva.com.py';
    --CRO-MB-05/2015: CROMIGDS-3 => Migración de Directorios de un Servidor a Otro
    --g_ip             VARCHAR2(100) := '192.168.254.136';
    g_ip             VARCHAR2(100) := fug_obt_pardinamico('DIR_SVR_REP_ARCHIVOS');
    g_port           VARCHAR2(100) := '21';
    --CRO-MB-05/2015: CROMIGDS-3 => Migración de Directorios de un Servidor a Otro
    --g_user           VARCHAR2(100) := 'ftpramail';
    g_user           VARCHAR2(100) := fug_obt_pardinamico('USU_FTP_REP_ARCHIVOS');
    --CRO-MB-05/2015: CROMIGDS-3 => Migración de Directorios de un Servidor a Otro
    --g_pass           VARCHAR2(100) := 'kacha.ma1';
    g_pass           VARCHAR2(100) := fug_obt_pardinamico('PAS_FTP_REP_ARCHIVOS');
    --CRO-MB-05/2015: CROMIGDS-3 => Migración de Directorios de un Servidor a Otro
    --g_compartido     VARCHAR2(100) := '\\192.168.254.136\';
    g_compartido     VARCHAR2(100) := '\\'||fug_obt_pardinamico('PAS_FTP_REP_ARCHIVOS')||'\';
    g_conciliaciones VARCHAR2(100) := 'ramail\Everilion\Enviados\';
    p_filtros        date;

    CURSOR cu_cuenta(p_filtros date) IS
       select rpad('PRY', 3, ' ') || ';' ||
             rpad(pag_gen.FU_ENC_PIN(b.nro_cuenta), 40, ' ') || ';' ||
             rpad(pag_gen.FU_ENC_PIN(a.cod_persona), 20, ' ') || ';' ||
             rpad(rpad(substr(a.nro_tarjeta, 0, 4), 12, '*') ||
                  substr(a.nro_tarjeta, 13, 4),
                  16,
                  ' ') || ';' ||

             fut_obt_nro_bin(b.cod_modalidad,
                             b.cod_modulo,
                             b.afinidad,
                             b.sub_afinidad,
                             a.nro_tarjeta) || ';' ||

             rpad(fug_obt_des_modalidad(b.cod_modalidad),100,' ') || ';' || 'C' || ';' || case
               when b.estado = 'C' then
                'B'
               else
                'A'
             end || ';' || to_char(b.fec_apertura, 'YYYY-MM-DD') || ';' ||
             rpad(round(b.dia_mora), 5, ' ') || ';' || case
               when round(b.dia_mora) > 0 then
                'S'
               else
                'N'
             end || ';' || rpad(' ', 10, ' ') || ';' as tar

        from ta_tarjetas a, ta_cta_tarjetas b, ge_cuentas c, ba_personas d, ge_cta_clientes gc

       where a.nro_cuenta = b.nro_cuenta
         and b.nro_cuenta = c.nro_cuenta
         and gc.nro_cuenta  = b.nro_cuenta
         and gc.cod_persona = d.cod_persona
         and gc.relacion = 'P'
         and a.cod_persona = d.cod_persona
         and b.estado <> 'C'
         and d.tipo = 'F'
         and a.nro_tarjeta in
           (select x.nro_tarjeta
              from ta_tarjetas x
             where x.nro_cuenta = a.nro_cuenta
               and x.cod_persona = a.cod_persona
               and x.vigente = 'S'
               and rownum = 1)
         and b.cod_modalidad not in (55, 58, 501)
         and trunc(c.fec_insercion) >= p_filtros
        union all
             select rpad('PRY', 3, ' ') || ';' ||
               rpad(pag_gen.FU_ENC_PIN(c.nro_cuenta), 40, ' ') || ';' ||
               rpad(pag_gen.FU_ENC_PIN(c.cod_persona), 20, ' ') || ';' ||
               rpad(rpad(substr(pat_gol.fu_obt_tar_debito(b.nro_cuenta), 0, 4), 12, '*') ||
                    substr(pat_gol.fu_obt_tar_debito(b.nro_cuenta), 13, 4),
                    16,
                    ' ') || ';' ||  case when substr(pat_gol.fu_obt_tar_debito(b.nro_cuenta), 0, 6) = '421345' then '421345JG' else '412616JH' end|| ';' ||

               rpad('DEBITOS '||fug_obt_des_modalidad(b.cod_modalidad), 100, ' ') || ';' || 'D' || ';' || case
                 when b.estado = 'C' then
                  'B'
                 else
                  'A'
               end || ';' || to_char(b.fec_apertura, 'YYYY-MM-DD') || ';' ||
               rpad(0, 5, ' ') || ';' || 'N' || ';' || rpad(' ', 10, ' ') || ';' as tar
          from ah_cta_vistas b, ge_cta_clientes c, ba_personas d
         where b.nro_cuenta = c.nro_cuenta
           and d.cod_persona = c.cod_persona
           and d.tipo = 'F'
           and c.relacion = 'P'
           and b.cod_modalidad = (31)
           and exists (select * from ah_tar_debitos x where x.nro_cuenta = b.nro_cuenta and x.nro_tarjeta is not null)
           and trunc(c.fec_insercion) >= p_filtros
        union all
                 select rpad('PRY', 3, ' ') || ';' ||
               rpad(pag_gen.FU_ENC_PIN(c.nro_cuenta), 40, ' ') || ';' ||
               rpad(pag_gen.FU_ENC_PIN(c.cod_persona), 20, ' ') || ';' ||
               rpad(rpad(substr(pat_gol.fu_obt_tar_debito(b.nro_cuenta), 0, 4), 12, '*') ||
                    substr(pat_gol.fu_obt_tar_debito(b.nro_cuenta), 13, 4),
                    16,
                    ' ') || ';' ||  case when substr(pat_gol.fu_obt_tar_debito(b.nro_cuenta), 0, 6) = '421345' then '421345JG' else '412616JH' end|| ';' ||

               rpad('DEBITOS '||fug_obt_des_modalidad(b.cod_modalidad), 100, ' ') || ';' || 'D' || ';' || case
                 when b.estado = 'C' then
                  'B'
                 else
                  'A'
               end || ';' || to_char(b.fec_apertura, 'YYYY-MM-DD') || ';' ||
               rpad(0, 5, ' ') || ';' || 'N' || ';' || rpad(' ', 10, ' ') || ';' as tar
          from cc_cta_corrientes b, ge_cta_clientes c, ba_personas d
         where b.nro_cuenta = c.nro_cuenta
           and d.cod_persona = c.cod_persona
           and d.tipo = 'F'
           and c.relacion = 'P'
           and b.cod_modalidad = (41)
           and exists (select * from ah_tar_debitos x where x.nro_cuenta = b.nro_cuenta and x.nro_tarjeta is not null)
           and trunc(c.fec_insercion) >= p_filtros;

  BEGIN
    -- Obtenemos la fecha del sistema
    select pag_cal.FU_OBT_FEC_ANTERIOR(1) into v_fec_sist from dual;

    v_fecha := to_char(v_fec_sist, 'YYYYMMDD');
    v_name := v_name||v_fecha||'.IN';

    if v_fec_sist > v_fecha_implementacion then
      p_filtros := v_fec_sist;
    else
      p_filtros := to_Date('01/01/2000', 'dd/mm/yyyy');
    end if;

    -- Abrir archivo
    v_file := UTL_FILE.FOPEN(g_repository, v_name, 'W', 32767);

/*    --Definir un cursor for loop que recorre los datos obtenidos
    FOR REC IN cu_cuenta(p_filtros) LOOP

      --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))

      v_line := to_char(rec.tar);

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

      EXIT WHEN cu_cuenta%NOTFOUND;
    END LOOP;

    v_final := 'CONTROL;';

    if v_lines = 0 then
       return;
    end if;

    v_final := v_final || v_lines;

    --Escribes la linea en el fichero
    UTL_FILE.PUT_LINE(v_file, v_buffer);
    UTL_FILE.PUT_LINE(v_file, v_final);
    --Cerrar el handler al fichero
    UTL_FILE.FCLOSE(v_file);
    COMMIT;
*/

  --Definir un cursor for loop que recorre los datos obtenidos
   FOR REC IN cu_cuenta(p_filtros) LOOP

      --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))

      v_line := to_char(rec.tar);
      UTL_FILE.PUT_LINE(v_file, v_line);
      v_lines := v_lines + 1;

      EXIT WHEN cu_cuenta%NOTFOUND;
    END LOOP;

    v_final := 'CONTROL;';

    if v_lines = 0 then
       return;
    end if;

    v_final := v_final ||  LPAD(v_lines, 9, '0') || ';';

    UTL_FILE.PUT_LINE(v_file, v_final);
    --Cerrar el handler al fichero
    UTL_FILE.FCLOSE(v_file);
    COMMIT;

    v_hini_ftp := to_char(sysdate, 'hh24:mi:ss');

    -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
    v_respuesta := pa_file_ftp.fu_put_ascii(g_ip,
                                            g_port,
                                            g_user,
                                            g_pass,
                                            g_repository,
                                            v_name,
                                            g_conciliaciones || v_name);

    v_hfin_ftp := to_char(sysdate, 'hh24:mi:ss');

    IF v_respuesta = 'OK' THEN
      --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pag_evo.FU_OBT_VALOR_PAR('RA',
                                         'REPORTES',
                                         'ASISTENCIA_BBVA_VIAJERO');

      -- Damos valor a los demas datos
      v_asunto   := 'Reporte Asistencia al Viajero Uruguay a la fecha ' ||
                    v_fec_sist || '.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: ' ||
                    g_compartido || g_conciliaciones || '

          Nombre del Archivo: ' || v_name;

      -- Enviamos el mail
      v_det_error := null;
      v_hini_mail := to_char(sysdate, 'hh24:mi:ss');

      BEGIN
        v_conn := it_mail.begin_mail(g_envia_mail,
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
           v_name,
           v_para,
           v_asunto,
           v_det_error,
           v_hini_mail,
           v_hfin_mail);
        COMMIT;
      END IF;

    ELSE
      -- ERROR AL ENVIAR ARCHIVO POR FTP
      v_det_error := null;

      -- Insertamos el error del envio al directorio compartido
      INSERT INTO ge_ra_log_ftp
        (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
      VALUES
        (SYSDATE,
         v_name,
         v_respuesta,
         v_hini_ftp,
         v_hfin_ftp);
      COMMIT;

      --Enviamos el mail a soporte
      -- Obtenemos direccion de correo de soporte
      v_para := pag_evo.FU_OBT_VALOR_PAR('RA', 'REPORTES', 'SOPORTE');

      -- Damos valor a los demas datos
      v_asunto   := 'Error Reporte Asistencia al Viajero Uruguay a la fecha ' ||
                    v_fec_sist || '.';
      v_mje_mail := 'Error al enviar archivo por FTP.

          Error: ' || v_respuesta || '.

          Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate, 'hh24:mi:ss');

      BEGIN
        v_conn := it_mail.begin_mail(pag_evo.g_envia_mail,
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
           v_name,
           v_para,
           v_asunto,
           v_det_error,
           v_hini_mail,
           v_hfin_mail);
        COMMIT;
      END IF;

    END IF;
    COMMIT;
  EXCEPTION
    WHEN UTL_FILE.INVALID_OPERATION THEN
      UTL_FILE.FCLOSE(v_file);
      RAISE_APPLICATION_ERROR(-20061, 'Operacion invalida ' || sqlerrm);
    WHEN UTL_FILE.INVALID_FILEHANDLE THEN
      UTL_FILE.FCLOSE(v_file);
      RAISE_APPLICATION_ERROR(-20062, 'Manejador invalido ' || sqlerrm);
    WHEN UTL_FILE.WRITE_ERROR THEN
      UTL_FILE.FCLOSE(v_file);
      RAISE_APPLICATION_ERROR(-20063, 'Error de escritura ' || sqlerrm);
    WHEN UTL_FILE.INVALID_MODE THEN
      UTL_FILE.FCLOSE(v_file);
      RAISE_APPLICATION_ERROR(-20064, 'Modo invalido ' || sqlerrm);
    WHEN UTL_FILE.INTERNAL_ERROR THEN
      UTL_FILE.FCLOSE(v_file);
      RAISE_APPLICATION_ERROR(-20065, 'Internal Error ' || sqlerrm);
  END;

  procedure pr_arc_clientes IS
    v_file   UTL_FILE.FILE_TYPE;
    v_line   VARCHAR2(32767);
    --v_buffer VARCHAR2(32767);
    v_name   VARCHAR2(128) := 'PFB02.PRY.CUSTOMERS.F'; -- nombre del archivo
    v_lines  PLS_INTEGER := 0;
    --v_eol     CONSTANT VARCHAR2(1) := CHR(10);
    --v_eollen  CONSTANT PLS_INTEGER := LENGTH(v_eol);
    --v_maxline CONSTANT PLS_INTEGER := 32767;
    v_con_ult_mes ge_movimientos.monto%type := 0;
    v_final       varchar2(100);
    -- Variables de fechas
    v_fec_sist DATE;
    v_fecha    VARCHAR2(8);

    -- Variables para mail

    v_conn      utl_smtp.connection;
    v_para      VARCHAR2(500);
    v_asunto    VARCHAR2(2000);
    v_mje_mail  VARCHAR2(4000);
    v_hini_mail ge_ra_log_mail.hor_inicio%type;
    v_hfin_mail ge_ra_log_mail.hor_fin%type;
    v_det_error ge_ra_log_mail.det_error%type;

    -- Variables para FTP

    v_respuesta VARCHAR2(4000);
    v_hini_ftp  ge_ra_log_ftp.hor_inicio%type;
    v_hfin_ftp  ge_ra_log_ftp.hor_fin%type;

    -- Variables coneccion

    g_repository     VARCHAR2(100) := 'MAIL';
    g_envia_mail     VARCHAR2(100) := 'bbvanet@bbva.com.py';
    --CRO-MB-05/2015: CROMIGDS-3 => Migración de Directorios de un Servidor a Otro
    --g_ip             VARCHAR2(100) := '192.168.254.136';
    g_ip             VARCHAR2(100) := fug_obt_pardinamico('DIR_SVR_REP_ARCHIVOS');
    g_port           VARCHAR2(100) := '21';
    --CRO-MB-05/2015: CROMIGDS-3 => Migración de Directorios de un Servidor a Otro
    --g_user           VARCHAR2(100) := 'ftpramail';
    g_user           VARCHAR2(100) := fug_obt_pardinamico('USU_FTP_REP_ARCHIVOS');
    --CRO-MB-05/2015: CROMIGDS-3 => Migración de Directorios de un Servidor a Otro
    --g_pass           VARCHAR2(100) := 'kacha.ma1';
    g_pass           VARCHAR2(100) := fug_obt_pardinamico('PAS_FTP_REP_ARCHIVOS');
    --CRO-MB-05/2015: CROMIGDS-3 => Migración de Directorios de un Servidor a Otro
    --g_compartido     VARCHAR2(100) := '\\192.168.254.136\';
    g_compartido     VARCHAR2(100) := '\\'||fug_obt_pardinamico('PAS_FTP_REP_ARCHIVOS')||'\';
    g_conciliaciones VARCHAR2(100) := 'ramail\Everilion\Enviados\';
    p_filtros        date;

    CURSOR cu_cliente(p_filtros date) IS
      select 'PRY' || ';' ||
             rpad(pag_gen.FU_ENC_PIN(a.cod_persona), 20, ' ') || ';' ||
             rpad(' ', 10, ' ') || ';' || b.cod_sexo || ';' ||
             FUE_OBT_VAL_MAX_REFCODES('COD_EST_CIVIL', b.est_civil) || ';' ||
             rpad(' ', 20, ' ') || ';' || rpad(' ', 20, ' ') || ';' ||
             rpad(' ', 20, ' ') || ';' || rpad(' ', 20, ' ') || ';' ||
             rpad(' ', 5, ' ') || ';' || 0 || ';' ||
             rpad(round(PAT_GOL.FU_OBT_MON_CONSUMO(a.cod_persona, 1), 2),
                  10,
                  ' ') || ';' ||
             rpad(round(PAT_GOL.FU_OBT_MON_CONSUMO(a.cod_persona, 1) /
                        pag_gen.FU_OBT_COTIZACION('USD',
                                                  pag_cal.FU_OBT_FEC_ACTUAL(5)),
                        2),
                  10,
                  ' ') || ';' ||
             rpad(round(PAT_GOL.FU_OBT_MON_CONSUMO(a.cod_persona, 3), 2),
                  10,
                  ' ') || ';' ||
             rpad(round(PAT_GOL.FU_OBT_MON_CONSUMO(a.cod_persona, 3) /
                        pag_gen.FU_OBT_COTIZACION('USD',
                                                  pag_cal.FU_OBT_FEC_ACTUAL(5)),
                        2),
                  10,
                  ' ') || ';' as tar,

             rpad(round(PAT_GOL.FU_OBT_MON_CONSUMO(a.cod_persona, 1), 2),
                  10,
                  ' ') as con_ult_mes

        from ba_personas a, ba_per_fisicas b
       where a.cod_persona = b.cod_persona
         and a.tipo = 'F'
         and b.cod_sexo <> '0'
         and trunc(a.fec_insercion) >= p_filtros;
  BEGIN
    -- Obtenemos la fecha del sistema
    select pag_cal.FU_OBT_FEC_ANTERIOR(1) into v_fec_sist from dual;

    v_fecha := to_char(v_fec_sist, 'YYYYMMDD');

    v_name := v_name||v_fecha||'.IN';

    if v_fec_sist > v_fecha_implementacion then
      p_filtros := v_fec_sist;
    else
      p_filtros := to_Date('01/01/2000', 'dd/mm/yyyy');
    end if;

    -- Abrir archivo
    v_file := UTL_FILE.FOPEN(g_repository, v_name, 'W', 32767);
/*
    --Definir un cursor for loop que recorre los datos obtenidos
    FOR REC IN cu_cliente(p_filtros) LOOP

      --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
      v_line := to_char(rec.tar);

      IF LENGTH(v_buffer) + v_eollen + LENGTH(v_line) <= v_maxline THEN
        v_buffer := v_buffer ||  v_line|| v_eol ;
      ELSE
        IF v_buffer IS NOT NULL THEN
          --Escribes la linea en el fichero
          UTL_FILE.PUT_LINE(v_file, v_buffer);
        END IF;
        v_buffer := v_line;
      END IF;

      v_lines       := v_lines + 1;
      v_con_ult_mes := v_con_ult_mes + rec.con_ult_mes;
      EXIT WHEN cu_cliente%NOTFOUND;
    END LOOP;

    v_final := 'CONTROL;';

    if v_lines = 0 then
       return;
    end if;

    v_final := v_final || v_lines || ';' || v_con_ult_mes || ';';

    --Escribes la linea en el fichero
    UTL_FILE.PUT_LINE(v_file, v_buffer);
    UTL_FILE.PUT_LINE(v_file, trim(v_final));
    --Cerrar el handler al fichero
    UTL_FILE.FCLOSE(v_file);
    COMMIT;*/

   --Definir un cursor for loop que recorre los datos obtenidos
   FOR REC IN cu_cliente(p_filtros) LOOP

      --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))

      v_line := to_char(rec.tar);
      UTL_FILE.PUT_LINE(v_file, v_line);
      v_lines := v_lines + 1;
      v_con_ult_mes := v_con_ult_mes + rec.con_ult_mes;

      EXIT WHEN cu_cliente%NOTFOUND;
    END LOOP;

    v_final := 'CONTROL;';

    if v_lines = 0 then
       return;
    end if;

    v_final := v_final || LPAD(v_lines, 9, '0') || ';' || LPAD(v_con_ult_mes, 15, '0')|| ';';

    --Escribes la linea en el fichero
    --UTL_FILE.PUT_LINE(v_file, v_buffer);
    UTL_FILE.PUT_LINE(v_file, v_final);
    --Cerrar el handler al fichero
    UTL_FILE.FCLOSE(v_file);
    COMMIT;

    v_hini_ftp := to_char(sysdate, 'hh24:mi:ss');

    -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
    v_respuesta := pa_file_ftp.fu_put_ascii(g_ip,
                                            g_port,
                                            g_user,
                                            g_pass,
                                            g_repository,
                                            v_name,
                                            g_conciliaciones || v_name);

    v_hfin_ftp := to_char(sysdate, 'hh24:mi:ss');

    IF v_respuesta = 'OK' THEN
      --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pag_evo.FU_OBT_VALOR_PAR('RA',
                                         'REPORTES',
                                         'ASISTENCIA_BBVA_VIAJERO');

      -- Damos valor a los demas datos
      v_asunto   := 'Reporte Asistencia al Viajero Uruguay a la fecha ' ||
                    v_fec_sist || '.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: ' ||
                    g_compartido || g_conciliaciones || '

          Nombre del Archivo: ' || v_name;

      -- Enviamos el mail
      v_det_error := null;
      v_hini_mail := to_char(sysdate, 'hh24:mi:ss');

      BEGIN
        v_conn := it_mail.begin_mail(g_envia_mail,
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
           v_name,
           v_para,
           v_asunto,
           v_det_error,
           v_hini_mail,
           v_hfin_mail);
        COMMIT;
      END IF;

    ELSE
      -- ERROR AL ENVIAR ARCHIVO POR FTP
      v_det_error := null;

      -- Insertamos el error del envio al directorio compartido
      INSERT INTO ge_ra_log_ftp
        (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
      VALUES
        (SYSDATE,
         v_name,
         v_respuesta,
         v_hini_ftp,
         v_hfin_ftp);
      COMMIT;

      --Enviamos el mail a soporte
      -- Obtenemos direccion de correo de soporte
      v_para := pag_evo.FU_OBT_VALOR_PAR('RA', 'REPORTES', 'SOPORTE');

      -- Damos valor a los demas datos
      v_asunto   := 'Error Reporte Asistencia al Viajero Uruguay a la fecha ' ||
                    v_fec_sist || '.';
      v_mje_mail := 'Error al enviar archivo por FTP.

          Error: ' || v_respuesta || '.

          Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate, 'hh24:mi:ss');

      BEGIN
        v_conn := it_mail.begin_mail(pag_evo.g_envia_mail,
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
           v_name,
           v_para,
           v_asunto,
           v_det_error,
           v_hini_mail,
           v_hfin_mail);
        COMMIT;
      END IF;

    END IF;
    COMMIT;
  EXCEPTION
    WHEN UTL_FILE.INVALID_OPERATION THEN
      UTL_FILE.FCLOSE(v_file);
      RAISE_APPLICATION_ERROR(-20061, 'Operacion invalida ' || sqlerrm);
    WHEN UTL_FILE.INVALID_FILEHANDLE THEN
      UTL_FILE.FCLOSE(v_file);
      RAISE_APPLICATION_ERROR(-20062, 'Manejador invalido ' || sqlerrm);
    WHEN UTL_FILE.WRITE_ERROR THEN
      UTL_FILE.FCLOSE(v_file);
      RAISE_APPLICATION_ERROR(-20063, 'Error de escritura ' || sqlerrm);
    WHEN UTL_FILE.INVALID_MODE THEN
      UTL_FILE.FCLOSE(v_file);
      RAISE_APPLICATION_ERROR(-20064, 'Modo invalido ' || sqlerrm);
    WHEN UTL_FILE.INTERNAL_ERROR THEN
      UTL_FILE.FCLOSE(v_file);
      RAISE_APPLICATION_ERROR(-20065, 'Internal Error ' || sqlerrm);
  END;

  procedure pr_arc_transacciones IS
    v_file   UTL_FILE.FILE_TYPE;
    v_line   VARCHAR2(32767);
    --v_buffer VARCHAR2(32767);
    v_name   VARCHAR2(128) := 'PIB01.PRY.TRANSACTIONS.F'; -- nombre del archivo
    v_lines  PLS_INTEGER := 0;
    --v_eol     CONSTANT VARCHAR2(1) := CHR(10);
    --v_eollen  CONSTANT PLS_INTEGER := LENGTH(v_eol);
    --v_maxline CONSTANT PLS_INTEGER := 32767;
    v_mon_local ge_movimientos.monto%type := 0;
    v_mon_usd   ge_movimientos.monto%type := 0;
    v_tex_mon_usd   varchar2(20);
    v_final     varchar2(100);
    -- Variables de fechas
    v_fec_sist DATE;
    v_fecha    VARCHAR2(8);

    -- Variables para mail

    v_conn      utl_smtp.connection;
    v_para      VARCHAR2(500);
    v_asunto    VARCHAR2(2000);
    v_mje_mail  VARCHAR2(4000);
    v_hini_mail ge_ra_log_mail.hor_inicio%type;
    v_hfin_mail ge_ra_log_mail.hor_fin%type;
    v_det_error ge_ra_log_mail.det_error%type;

    -- Variables para FTP

    v_respuesta VARCHAR2(4000);
    v_hini_ftp  ge_ra_log_ftp.hor_inicio%type;
    v_hfin_ftp  ge_ra_log_ftp.hor_fin%type;

    -- Variables coneccion

    g_repository     VARCHAR2(100) := 'MAIL';
    g_envia_mail     VARCHAR2(100) := 'bbvanet@bbva.com.py';
    --CRO-MB-05/2015: CROMIGDS-3 => Migración de Directorios de un Servidor a Otro
    --g_ip             VARCHAR2(100) := '192.168.254.136';
    g_ip             VARCHAR2(100) := fug_obt_pardinamico('DIR_SVR_REP_ARCHIVOS');
    g_port           VARCHAR2(100) := '21';
    --CRO-MB-05/2015: CROMIGDS-3 => Migración de Directorios de un Servidor a Otro
    --g_user           VARCHAR2(100) := 'ftpramail';
    g_user           VARCHAR2(100) := fug_obt_pardinamico('USU_FTP_REP_ARCHIVOS');
    --CRO-MB-05/2015: CROMIGDS-3 => Migración de Directorios de un Servidor a Otro
    --g_pass           VARCHAR2(100) := 'kacha.ma1';
    g_pass           VARCHAR2(100) := fug_obt_pardinamico('PAS_FTP_REP_ARCHIVOS');
    --CRO-MB-05/2015: CROMIGDS-3 => Migración de Directorios de un Servidor a Otro
    --g_compartido     VARCHAR2(100) := '\\192.168.254.136\';
    g_compartido     VARCHAR2(100) := '\\'||fug_obt_pardinamico('PAS_FTP_REP_ARCHIVOS')||'\';
    g_conciliaciones VARCHAR2(100) := 'ramail\Everilion\Enviados\';

    CURSOR cu_tran IS
               select 'PRY' || ';' || rpad(pag_gen.FU_ENC_PIN(a.nro_cuenta), 40, ' ') || ';' ||
             rpad(rpad(substr(d.nro_tarjeta, 0, 4), 12, '*') ||
                  substr(d.nro_tarjeta, 13, 4),
                  16,
                  ' ') || ';' || rpad(' ', 10, ' ') || ';' || rpad(' ', 5, ' ') || ';' ||
             substr(c.cod_gru_transaccion, 2, 1) || ';' || 'PYG' || ';' ||
             rpad(a.monto, 10, ' ') || ';' ||
            rpad(trim(to_char(round(a.monto / pag_gen.FU_OBT_COTIZACION('USD',pag_cal.FU_OBT_FEC_ACTUAL(5)),
                        2),'99999999.99')),11,' ')
                         || ';' || to_char(a.fec_valor, 'YYYY-MM-DD') || '-' ||
             a.hora || ';' || ' ' || ';' || 'PY' || ';' ||
             rpad(a.nro_documento4, 10, ' ') || ';' ||
             lpad(a.nro_documento4, 10, 0) || ';' ||
             rpad(' ', 10, ' ') || ';' || to_char(a.fecha, 'YYYY-MM-DD') || '-' ||
             a.hora || ';' as tar,
             a.monto as mon_local,
             round(a.monto / pag_gen.FU_OBT_COTIZACION('USD',pag_cal.FU_OBT_FEC_ACTUAL(5)),2) as mon_usd
        from ta_movimientos_his       a,
             ge_gru_transacciones_det c,
             ta_cta_tarjetas          ba,
             ta_tarjetas              d,
             ge_cta_clientes          e,
             ba_personas              bp
       where a.cod_transaccion = c.cod_transaccion
         and a.cod_modulo = c.cod_modulo
         and a.cod_modalidad = c.cod_modalidad
         and c.cod_gru_transaccion in (41, 42, 43, 44, 45, 46, 47)
         and a.fecha = pag_cal.FU_OBT_FEC_ANTERIOR(5)
         and exists (select * from ta_cli_adheridos b where b.cod_persona = e.cod_persona)
         and a.nro_cuenta = ba.nro_cuenta
         and ba.nro_cuenta = e.nro_cuenta
         and ba.nro_cuenta = d.nro_cuenta
         and a.monto > 0
         and e.relacion = 'P'
         and ba.estado <> 'C'
         and e.cod_persona = bp.cod_persona
         and e.cod_persona = d.cod_persona
         and bp.tipo = 'F'
         and d.nro_tarjeta in (select x.nro_tarjeta
                                 from ta_tarjetas x
                                where x.nro_cuenta = d.nro_cuenta
                                  and x.cod_persona = d.cod_persona
                                  and x.vigente = 'S'
                                  and rownum = 1)
         and ba.cod_modalidad not in (55, 58, 501)
         and a.reversado <> 'S'
      union all
      select 'PRY' || ';' || rpad(pag_gen.FU_ENC_PIN(a.nro_cuenta), 40, ' ') || ';' ||
             rpad(rpad(substr(pat_gol.fu_obt_tar_debito(a.nro_cuenta), 0, 4), 12, '*') ||
                  substr(pat_gol.fu_obt_tar_debito(a.nro_cuenta), 13, 4),
                  16,
                  ' ') || ';' || rpad(' ', 10, ' ') || ';' || rpad(' ', 5, ' ') || ';' ||
             '1' || ';' || 'PYG' || ';' ||
             rpad(a.monto, 10, ' ') || ';' ||

             rpad(trim(to_char(round(a.monto / pag_gen.FU_OBT_COTIZACION('USD',pag_cal.FU_OBT_FEC_ACTUAL(5)),
                        2),'99999999.99')),11,' ')
                        || ';' || to_char(a.fec_valor, 'YYYY-MM-DD') || '-' ||
             a.hora || ';' || ' ' || ';' || 'PY' || ';' ||
             rpad(a.nro_documento4, 10, ' ') || ';' ||
             lpad(a.nro_documento4, 10, 0) || ';' ||
             rpad(' ', 10, ' ') || ';' || to_char(a.fecha, 'YYYY-MM-DD') || '-' ||
             a.hora || ';' as tar,
             a.monto as mon_local,
             round(a.monto / pag_gen.FU_OBT_COTIZACION('USD',pag_cal.FU_OBT_FEC_ACTUAL(5)),2) as mon_usd
        from ah_movimientos_his a, ge_cta_clientes b, ba_personas c

       where  a.cod_tra_padre = '380'
         and a.cod_transaccion = '503'
         and a.nro_cuenta = b.nro_cuenta
         and b.relacion = 'P'
         and b.cod_persona = c.cod_persona
         and a.monto > 0
         and c.tipo = 'F'
         and a.reversado <> 'S'
         and exists (select * from ah_tar_debitos x where x.nro_cuenta = b.nro_cuenta and x.nro_tarjeta is not null)
         and exists (select * from ta_cli_adheridos z where z.cod_persona = c.cod_persona)
         and a.fecha = pag_cal.FU_OBT_FEC_ANTERIOR(3)
      union all
      select 'PRY' || ';' || rpad(pag_gen.FU_ENC_PIN(a.nro_cuenta), 40, ' ') || ';' ||
             rpad(rpad(substr(pat_gol.fu_obt_tar_debito(a.nro_cuenta), 0, 4), 12, '*') ||
                  substr(pat_gol.fu_obt_tar_debito(a.nro_cuenta), 13, 4),
                  16,
                  ' ') || ';' || rpad(' ', 10, ' ') || ';' || rpad(' ', 5, ' ') || ';' ||
             '1' || ';' || 'PYG' || ';' ||
             rpad(a.monto, 10, ' ') || ';' ||
             rpad(trim(to_char(round(a.monto / pag_gen.FU_OBT_COTIZACION('USD',pag_cal.FU_OBT_FEC_ACTUAL(5)),
                        2),'99999999.99')),11,' ')|| ';' || to_char(a.fec_valor, 'YYYY-MM-DD') || '-' ||
             a.hora || ';' || ' ' || ';' || 'PY' || ';' ||
             rpad(a.nro_documento4, 10, ' ') || ';' ||
             lpad(a.nro_documento4, 10, 0) || ';' ||
             rpad(' ', 10, ' ') || ';' || to_char(a.fecha, 'YYYY-MM-DD') || '-' ||
             a.hora || ';' as tar,
             a.monto as mon_local,
             round(a.monto / pag_gen.FU_OBT_COTIZACION('USD',pag_cal.FU_OBT_FEC_ACTUAL(5)),2) as mon_usd
        from cc_movimientos_his a, ge_cta_clientes b, ba_personas c

       where  a.cod_tra_padre = '380'
         and a.cod_transaccion = '503'
         and a.nro_cuenta = b.nro_cuenta
         and b.relacion = 'P'
         and b.cod_persona = c.cod_persona
         and a.monto > 0
         and c.tipo = 'F'
         and a.reversado <> 'S'
         and exists (select * from ah_tar_debitos x where x.nro_cuenta = b.nro_cuenta and x.nro_tarjeta is not null)
         and exists (select * from ta_cli_adheridos z where z.cod_persona = c.cod_persona)
         and a.fecha = pag_cal.FU_OBT_FEC_ANTERIOR(4);

  BEGIN
    -- Obtenemos la fecha del sistema
    select pag_cal.FU_OBT_FEC_ANTERIOR(1) into v_fec_sist from dual;

    v_fecha := to_char(v_fec_sist, 'YYYYMMDD');
    v_name := v_name||v_fecha||'.IN';
    -- Abrir archivo
    v_file := UTL_FILE.FOPEN(g_repository, v_name, 'W', 32767);

  /*  --Definir un cursor for loop que recorre los datos obtenidos
    FOR REC IN cu_tran LOOP

      --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
      v_line := to_char(rec.tar);

      IF LENGTH(v_buffer) + v_eollen + LENGTH(v_line) <= v_maxline THEN
        v_buffer := v_buffer || v_eol || v_line;
      ELSE
        IF v_buffer IS NOT NULL THEN
          --Escribes la linea en el fichero
          UTL_FILE.PUT_LINE(v_file, v_buffer);
        END IF;
        v_buffer := v_line;
      END IF;

      v_lines     := v_lines + 1;
      v_mon_local := v_mon_local + rec.mon_local;
      v_mon_usd   := v_mon_usd + rec.mon_usd;

      EXIT WHEN cu_tran%NOTFOUND;
    END LOOP;

    v_final := 'CONTROL;';

    if v_lines = 0 then
       return;
    end if;

    v_final := v_final || v_lines || ';' || v_mon_local || ';' || v_mon_usd || ';';

    --Escribes la linea en el fichero
    UTL_FILE.PUT_LINE(v_file, v_buffer);
    UTL_FILE.PUT_LINE(v_file, v_final);
    --Cerrar el handler al fichero
    UTL_FILE.FCLOSE(v_file);
    COMMIT;*/

     --Definir un cursor for loop que recorre los datos obtenidos
    FOR REC IN cu_tran LOOP

      --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))

      v_line := to_char(rec.tar);
      UTL_FILE.PUT_LINE(v_file, v_line);
      v_lines := v_lines + 1;
      v_mon_local := v_mon_local + rec.mon_local;
      v_mon_usd   := v_mon_usd + rec.mon_usd;

      EXIT WHEN cu_tran%NOTFOUND;
    END LOOP;

    v_final := 'CONTROL;';

    if v_lines = 0 then
       return;
    end if;
    
    v_tex_mon_usd   := trim(to_char(v_mon_usd,'99999999.99'));
    
    v_final := v_final || LPAD(v_lines, 9, '0') || ';' || LPAD(v_mon_local,15, '0') || ';' || LPAD(v_tex_mon_usd, 16, '0') || ';';

    --Escribes la linea en el fichero
    --UTL_FILE.PUT_LINE(v_file, v_buffer);
    UTL_FILE.PUT_LINE(v_file, v_final);
    --Cerrar el handler al fichero
    UTL_FILE.FCLOSE(v_file);
    COMMIT;

    v_hini_ftp := to_char(sysdate, 'hh24:mi:ss');

    -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
    v_respuesta := pa_file_ftp.fu_put_ascii(g_ip,
                                            g_port,
                                            g_user,
                                            g_pass,
                                            g_repository,
                                            v_name,
                                            g_conciliaciones || v_name);

    v_hfin_ftp := to_char(sysdate, 'hh24:mi:ss');

    IF v_respuesta = 'OK' THEN
      --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pag_evo.FU_OBT_VALOR_PAR('RA',
                                         'REPORTES',
                                         'ASISTENCIA_BBVA_VIAJERO');

      -- Damos valor a los demas datos
      v_asunto   := 'Reporte Asistencia al Viajero Uruguay a la fecha ' ||
                    v_fec_sist || '.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: ' ||
                    g_compartido || g_conciliaciones || '

          Nombre del Archivo: ' || v_name;

      -- Enviamos el mail
      v_det_error := null;
      v_hini_mail := to_char(sysdate, 'hh24:mi:ss');

      BEGIN
        v_conn := it_mail.begin_mail(g_envia_mail,
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
           v_name,
           v_para,
           v_asunto,
           v_det_error,
           v_hini_mail,
           v_hfin_mail);
        COMMIT;
      END IF;

    ELSE
      -- ERROR AL ENVIAR ARCHIVO POR FTP
      v_det_error := null;

      -- Insertamos el error del envio al directorio compartido
      INSERT INTO ge_ra_log_ftp
        (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
      VALUES
        (SYSDATE,
         v_name,
         v_respuesta,
         v_hini_ftp,
         v_hfin_ftp);
      COMMIT;

      --Enviamos el mail a soporte
      -- Obtenemos direccion de correo de soporte
      v_para := pag_evo.FU_OBT_VALOR_PAR('RA', 'REPORTES', 'SOPORTE');

      -- Damos valor a los demas datos
      v_asunto   := 'Error Reporte Asistencia al Viajero Uruguay a la fecha ' ||
                    v_fec_sist || '.';
      v_mje_mail := 'Error al enviar archivo por FTP.

          Error: ' || v_respuesta || '.

          Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate, 'hh24:mi:ss');

      BEGIN
        v_conn := it_mail.begin_mail(pag_evo.g_envia_mail,
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
           v_name,
           v_para,
           v_asunto,
           v_det_error,
           v_hini_mail,
           v_hfin_mail);
        COMMIT;
      END IF;

    END IF;
    COMMIT;
  EXCEPTION
    WHEN UTL_FILE.INVALID_OPERATION THEN
      UTL_FILE.FCLOSE(v_file);
      RAISE_APPLICATION_ERROR(-20061, 'Operacion invalida ' || sqlerrm);
    WHEN UTL_FILE.INVALID_FILEHANDLE THEN
      UTL_FILE.FCLOSE(v_file);
      RAISE_APPLICATION_ERROR(-20062, 'Manejador invalido ' || sqlerrm);
    WHEN UTL_FILE.WRITE_ERROR THEN
      UTL_FILE.FCLOSE(v_file);
      RAISE_APPLICATION_ERROR(-20063, 'Error de escritura ' || sqlerrm);
    WHEN UTL_FILE.INVALID_MODE THEN
      UTL_FILE.FCLOSE(v_file);
      RAISE_APPLICATION_ERROR(-20064, 'Modo invalido ' || sqlerrm);
    WHEN UTL_FILE.INTERNAL_ERROR THEN
      UTL_FILE.FCLOSE(v_file);
      RAISE_APPLICATION_ERROR(-20065, 'Internal Error ' || sqlerrm);
  END;

  PROCEDURE pr_imp_cli_adheridos IS

    v_referencia  VARCHAR2(30) := 'CLI_ADH_FUTBOL';
    v_dir_destino VARCHAR2(100) := 'MAIL';
    v_fec_actual  date default pag_cal.fu_obt_fec_actual(21);
    v_det_error   varchar2(4000);
    v_hor_inicio  ge_ra_log_ftp.hor_inicio%type;
    v_hor_fin     ge_ra_log_ftp.hor_fin%type;
  BEGIN
    v_hor_inicio := to_char(sysdate, 'hh24:mi:ss');
    pag_arc.pr_arc_pro_archivo(v_referencia,
                               v_dir_destino,
                               trunc(v_fec_actual));
    pr_pos_cli_adheridos;

  EXCEPTION
    WHEN OTHERS THEN
      v_det_error := substr(sqlerrm, 1, 4000);
      v_hor_fin   := to_char(sysdate, 'hh24:mi:ss');
      -- Insertamos el error del envio al directorio compartido
      IF v_det_error is not null THEN
        INSERT INTO ge_ra_log_ftp
          (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
        VALUES
          (SYSDATE, v_referencia, v_det_error, v_hor_inicio, v_hor_fin);
        COMMIT;
      END IF;

  END pr_imp_cli_adheridos;

  PROCEDURE pr_pos_cli_adheridos IS
    v_cod_persona  ba_personas.cod_persona%type;
    v_id_titular   ta_cli_adheridos.id_titular%type;
    v_id_pais      ta_cli_adheridos.id_pais%type;
    v_fec_adhesion ta_cli_adheridos.fec_adhesion%type;
    v_con          number := 0;
    v_can          number := 0;
    v_dat          ta_cli_adheridos_tmp.datos%type;

    cursor c_cli is
      select datos from ta_cli_adheridos_tmp;

  BEGIN

    delete ta_cli_adheridos;

    select count(datos) into v_can from ta_cli_adheridos_tmp;

    for reg in c_cli loop
      v_dat := substr(reg.datos,0,7);
      v_con := v_con + 1;
      if v_dat != 'CONTROL' then
               

          v_id_titular   := trim(substr(reg.datos, 0, 20));
          v_id_pais      := trim(substr(reg.datos, 22, 3));

          begin
            v_fec_adhesion := to_date(trim(substr(reg.datos, 26, 19)),'YYYY-MM-DD HH24:MI:SS');
          EXCEPTION
              WHEN OTHERS THEN
                v_fec_adhesion := pag_cal.FU_OBT_FEC_ANTERIOR(5);
           end;
          v_cod_persona  := pag_gen.FU_DES_PIN(v_id_titular);

          insert into ta_cli_adheridos
            (cod_persona, id_titular, id_pais, fec_adhesion)
          values
            (v_cod_persona, v_id_titular, v_id_pais, v_fec_adhesion);
            
       end if;

    end loop;

  END pr_pos_cli_adheridos;


  FUNCTION fu_obt_tar_debito(p_nro_cuenta in ge_cuentas.nro_cuenta%type) return number is
      v_nro_tarjeta ah_tar_debitos.nro_tarjeta%type;

    BEGIN
      select a.nro_tarjeta
        into v_nro_tarjeta
        from ah_tar_debitos a
       where a.nro_cuenta = p_nro_cuenta
         and a.nro_tarjeta is not null
         and rownum = 1;

      return v_nro_tarjeta;
    exception
      when no_data_found then
        return('');
    END;

END pat_gol;
/

