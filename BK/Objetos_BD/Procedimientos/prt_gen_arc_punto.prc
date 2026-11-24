CREATE OR REPLACE PROCEDURE IT.PRT_GEN_ARC_PUNTO IS
  v_file    UTL_FILE.FILE_TYPE;
  v_line    VARCHAR2(32767);
  v_linetit VARCHAR2(2000);
  v_buffer  VARCHAR2(32767);
  v_name    VARCHAR2(128) := 'ASISTENCIA_PUNTOS'; -- nombre del archivo
  v_lines   PLS_INTEGER := 0;
  v_eol     CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen  CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline CONSTANT PLS_INTEGER := 32767;

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

  g_repository         VARCHAR2(100) := 'MAIL';

  g_envia_mail         VARCHAR2(100) := fug_obt_pardinamico('CAM_MAR_DIR_MAI_NET');--fug_obt_dir_correo;
  --CRO-MB-05/2015: CROMIGDS-3 => Migraci?n de Directorios de un Servidor a Otro
  --g_ip                 VARCHAR2(100) := '192.168.254.136';
  g_ip                 VARCHAR2(100) := fug_obt_pardinamico('DIR_SVR_REP_ARCHIVOS');
  g_port               VARCHAR2(100) := '21';
  --CRO-MB-05/2015: CROMIGDS-3 => Migraci?n de Directorios de un Servidor a Otro
  --g_user               VARCHAR2(100) := 'ftpramail';
  g_user               VARCHAR2(100) := fug_obt_pardinamico('USU_FTP_REP_ARCHIVOS');
  --CRO-MB-05/2015: CROMIGDS-3 => Migraci?n de Directorios de un Servidor a Otro
  --g_pass               VARCHAR2(100) := 'kacha.ma1';
  g_pass               VARCHAR2(100) := fug_obt_pardinamico('PAS_FTP_REP_ARCHIVOS');
  --CRO-MB-05/2015: CROMIGDS-3 => Migraci?n de Directorios de un Servidor a Otro
  --g_compartido         VARCHAR2(100) := '\\192.168.254.136\';
  --g_compartido         VARCHAR2(100) := '\\'||fug_obt_pardinamico('PAS_FTP_REP_ARCHIVOS')||'\';
  g_compartido         VARCHAR2(100) := '\\'||fug_obt_pardinamico('DIR_SVR_REP_ARCHIVOS')||'\';
  g_conciliaciones     VARCHAR2(100) := 'ramail\tarjetas\';
  v_det_otro_error         varchar2(3000);
  v_err_code NUMBER(5);
   v_err_msj  VARCHAR2(4000);

 CURSOR cu_puntos IS
   select lpad(substr(c.nro_tarjeta,13,4),12,'*') as TARJETA,
          TRIM(trim(d.pri_apellido) || ' ' ||
                    trim(d.seg_apellido)) || CHR(44) || CHR(9) ||
               TRIM(trim(d.pri_nombre) || ' ' || trim(d.seg_nombre))  as NOMBRE,
           c.fec_vencimiento as VENCIMIENTO,
           fut_obt_tip_tarjeta(b.cod_modalidad, b.cod_modulo, substr(c.nro_tarjeta, 0, 10), b.afinidad, b.sub_afinidad) as TIPO_TARJETA,
           'T' as TIPO_CLIENTE,
           round(nvl(x.saldo,0)) as PUNTOS_TARJETA,
           fue_obt_nro_doc_persona(g.cod_persona) as CI,
           fug_obt_des_afinidad(b.afinidad) as Afinidad
           -- DYDMR-2318 ITGF - Incidencia Reporte de Puntos - Interasistencia SC 19468
      from ( SELECT t.nro_cuenta, t.puntos saldo, c.cod_persona
               FROM ta_cta_tarjetas ta, ge_cta_clientes c,
                   -- MDPNVAPC-1 - Nueva versi?n de Archivos de Puntos (Lealtad vs Cobranding) -- 05/2016
                   ( select e.nro_cuenta nro_cuenta,
                            e.puntos puntos
                       from tv_pun_extracto e
                      where e.val_minimo = 'Z' -- Saldo Actual --
                     ) t
              WHERE t.nro_cuenta = ta.nro_cuenta
                AND t.nro_cuenta = c.nro_cuenta
                --AND nvl(instr(fug_obt_pardinamico('AFI_TAR_PUNTOS', ta.cod_modulo, ta.cod_modalidad), ta.afinidad),0) != 0
                AND (nvl(instr(','||fug_obt_pardinamico('AFI_TAR_PUNTOS', ta.cod_modulo, ta.cod_modalidad)||',', ','||ta.afinidad||','),0) != 0  -- se agrega ',' al principio y al final para comparar exactamente con la afinidad definida
                    or  nvl(instr(','||fug_obt_pardinamico('AFI_TAR_PUNTOS_EXP', ta.cod_modulo, ta.cod_modalidad)||',', ','||ta.afinidad||','),0) != 0) --DYDMR-5621 GC 06/12/2016
                and c.relacion = 'P' ) x,
             ta_cta_tarjetas b,
             ta_tarjetas c,
            ge_cta_clientes g,
            ba_per_fisicas d
     where x.nro_cuenta = b.nro_cuenta
       and c.nro_cuenta = b.nro_cuenta
       and g.nro_cuenta = b.nro_cuenta
       and g.cod_persona = c.cod_persona
       and d.cod_persona = g.cod_persona
       and g.relacion = 'P'
       and c.vigente = 'S'
       and c.cod_estado = 6  -- Activa
       and x.cod_persona = g.cod_persona;

BEGIN
  -- Obtenemos la fecha del sistema
  select pag_cal.FU_OBT_FEC_ACTUAL(1) into v_fec_sist from dual;

  v_fecha := to_char(v_fec_sist, 'DDMMYYYY');

  -- Abrir archivo
  v_file := UTL_FILE.FOPEN(g_repository,
                           v_name || '.txt',
                           'W',
                           32767);

  -- Colocar el titulo a los campos
  v_linetit := 'TARJETA' || CHR(59) || 'NOMBRE' || CHR(59) || 'VENCIMIENTO' ||
               CHR(59) || 'TIPO_TARJETA' || CHR(59) || 'TIPO_CLIENTE' ||
               CHR(59) || 'PUNTOS_TARJETA' || CHR(59) || 'CI' || CHR(59) || 'AFINIDAD';
  utl_file.put_line(v_file, v_linetit);

  -- Definir una linea en blanco para separar los datos del titulo de los campos
  v_linetit := ' ';
  utl_file.put_line(v_file, v_linetit);

  --Definir un cursor for loop que recorre los datos obtenidos
  FOR REC IN cu_puntos LOOP

    --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
    v_line := to_char(rec.TARJETA) || chr(59) || to_char(rec.NOMBRE) ||
              chr(59) || to_char(rec.VENCIMIENTO) || chr(59) ||
              to_char(rec.TIPO_TARJETA) || chr(59) ||
              to_char(rec.TIPO_CLIENTE) || chr(59) ||
              to_char(rec.PUNTOS_TARJETA) || chr(59) || to_char(rec.CI) || chr(59) ||to_char(rec.Afinidad) ;

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

    EXIT WHEN cu_puntos%NOTFOUND;
  END LOOP;
  --Escribes la linea en el fichero
  UTL_FILE.PUT_LINE(v_file, v_buffer);

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
                                          v_name || '.txt',
                                          g_conciliaciones || v_name || '_' ||
                                          v_fecha || '.txt');

  IF v_respuesta = 'OK' THEN
    --ARCHIVO ENVIADO POR FTP
    -- Obtenemos los direcciones de correo para quien o quienes va el correo
    v_para := pag_evo.FU_OBT_VALOR_PAR('RA',
                                       'REPORTES',
                                       v_name);

    -- Damos valor a los demas datos
    v_asunto   := 'Reporte Puntos de Tarjetas Experience a la fecha ' ||
                  v_fec_sist || '.';
    v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente direcci?n: ' ||
                  g_compartido || g_conciliaciones || '

    Nombre del Archivo: ' || v_name || '_' || v_fecha ||'.txt';

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
      INSERT INTO ge_pro_aut_logs
                  (cod_proceso, nom_proceso, fec_hor_ini, fec_hor_fin, men_error)
          VALUES
                  (720, 'PRT_GEN_ARC_PUNTO', v_hini_mail, v_hfin_mail, v_det_error);
      COMMIT;
    END IF;

  ELSE
    -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error := null;

    INSERT INTO ge_pro_aut_logs
                  (cod_proceso, nom_proceso, fec_hor_ini, fec_hor_fin, men_error)
          VALUES
                  (720, 'PRT_GEN_ARC_PUNTO', v_hini_mail, v_hfin_mail, v_det_error);
    COMMIT;

    --Enviamos el mail a soporte
    -- Obtenemos direccion de correo de soporte
    v_para := pag_evo.FU_OBT_VALOR_PAR('RA', 'REPORTES', v_name);

    -- Damos valor a los demas datos
    v_asunto   := 'Error Reporte Puntos de Tarjetas Experience a la fecha ' ||
                  v_fec_sist || '.';
    v_mje_mail := 'Error al enviar archivo por FTP.

    Error: ' || v_respuesta || '.

    Para mas informaci?n verificar la tabla GE_RA_LOG_FTP';

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
        INSERT INTO ge_pro_aut_logs
                  (cod_proceso, nom_proceso, fec_hor_ini, fec_hor_fin, men_error)
          VALUES
                  (720, 'PRT_GEN_ARC_PUNTO', v_hini_mail, v_hfin_mail, v_det_error);
    END IF;

  END IF;
/*  COMMIT;
  prt_gen_arc_viajero;
  --DYDMR-9254 llamada a gener.arch.Conc.Bancard
  prg_gen_arc_con_bancard;
  --CORETAIN-3 Llamada a proceso indep. tdc innominadas.
  prt_env_wsi_cta_tar;*/

EXCEPTION
  WHEN OTHERS THEN
    v_err_code := SQLCODE;
    v_err_msj  := SQLERRM;
    UTL_FILE.FCLOSE(v_file);
     INSERT INTO ge_pro_aut_logs (cod_proceso, nom_proceso, fec_hor_ini, fec_hor_fin, nro_error, men_error)
          VALUES (720, 'PRT_GEN_ARC_PUNTO', v_hini_mail, v_hfin_mail, v_err_code, v_err_msj);


END PRT_GEN_ARC_PUNTO;
/

