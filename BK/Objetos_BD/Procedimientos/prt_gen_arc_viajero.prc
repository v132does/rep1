create or replace procedure it.prt_gen_arc_viajero IS
  v_file    UTL_FILE.FILE_TYPE;
  v_line    VARCHAR2(32767);
  v_linetit VARCHAR2(2000);
  v_buffer  VARCHAR2(32767);
  v_name    VARCHAR2(128) := 'ASISTENCIA_BBVA_VIAJERO'; -- nombre del archivo
  v_lines   PLS_INTEGER := 0;
  v_eol     CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen  CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline CONSTANT PLS_INTEGER := 32767;

  --- Variables de fechas
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
  g_envia_mail         VARCHAR2(100) := fug_obt_pardinamico('CAM_MAR_DIR_MAI_NET');--'info@bancognbcaminamosjuntos.com.py';
  --CRO-MB-05/2015: CROMIGDS-3 => Migración de Directorios de un Servidor a Otro
  --g_ip                 VARCHAR2(100) := '192.168.254.136';
  g_ip                 VARCHAR2(100) := fug_obt_pardinamico('DIR_SVR_REP_ARCHIVOS');
  g_port               VARCHAR2(100) := '21';
  --CRO-MB-05/2015: CROMIGDS-3 => Migración de Directorios de un Servidor a Otro
  --g_user               VARCHAR2(100) := 'ftpramail';
  g_user               VARCHAR2(100) := fug_obt_pardinamico('USU_FTP_REP_ARCHIVOS');
  --CRO-MB-05/2015: CROMIGDS-3 => Migración de Directorios de un Servidor a Otro
  --g_pass               VARCHAR2(100) := 'kacha.ma1';
  g_pass               VARCHAR2(100) := fug_obt_pardinamico('PAS_FTP_REP_ARCHIVOS');
  --CRO-MB-05/2015: CROMIGDS-3 => Migración de Directorios de un Servidor a Otro
  --g_compartido         VARCHAR2(100) := '\\192.168.254.136\';
  g_compartido         VARCHAR2(100) := '\\'||fug_obt_pardinamico('PAS_FTP_REP_ARCHIVOS')||'\';
  g_conciliaciones     VARCHAR2(100) := 'ramail\tarjetas\';
   v_err_code NUMBER(5);
   v_err_msj  VARCHAR2(4000);


  CURSOR cu_asiviajero IS
    select lpad(substr(x.nro_tarjeta,13,4),16,'*') as TARJETA,
           x.nom_persona nombre,
           to_char(x.fec_vencimiento, 'mm/yy') vencimiento,
           fug_obt_pardinamico('TIP_TARJETA', 5, x.cod_modalidad) tipo_tarjeta,
           x.relacion tipo_cliente,
           x.cod_tip_tarjeta codigo_tarjeta,
           x.nro_documento ci
      from (select gc.cod_persona cod_persona,
                   fue_obt_nro_doc_persona(gc.cod_persona) nro_documento,
                   cc.nro_cuenta nro_cuenta,
                   t.nro_tarjeta nro_tarjeta,
                   decode(cc.relacion, 'P', 'T', 'A', 'A') as relacion,
                   TRIM(trim(bpf.pri_apellido) || ' ' ||
                        trim(bpf.seg_apellido)) || CHR(44) || CHR(9) ||
                   TRIM(trim(bpf.pri_nombre) || ' ' || trim(bpf.seg_nombre)) nom_persona,
                   cc.cod_modalidad,
                   fut_obt_tip_tarjeta(ct.cod_modalidad, ct.cod_modulo,substr(t.nro_tarjeta, 0, 10),ct.afinidad, ct.sub_afinidad)  as cod_tip_tarjeta,
                   t.fec_vencimiento
              from ge_clientes        gc,
                   ge_cta_clientes    cc,
                   ta_tarjetas        t,
                   ta_cta_tarjetas    ct,
                   ba_personas        ba,
                   ba_per_fisicas     bpf,
                   ba_cod_referencias bcr 
             where gc.cod_persona = cc.cod_persona
               and gc.cod_persona = bpf.cod_persona
               and ba.cod_persona = bpf.cod_persona
               and cc.nro_cuenta = t.nro_cuenta
               and t.nro_cuenta = ct.nro_cuenta
               and t.cod_persona = cc.cod_persona
               and ct.cod_modalidad not in (55,501)
               and t.cod_estado = 6
               and cc.relacion in ('P','A')
               and ct.afinidad not in ('050517',
                                       '050518',
                                       '050519',
                                       '050520',
                                       '050521',
                                       '050522')
               and bcr.dominio(+) = 'SUB_AFINIDAD'
               and bcr.val_minimo(+) = ct.sub_afinidad
               and t.nro_tarjeta =
                   ( -- Es seleccionada una sola tarjeta, la de mayor categoría, en caso que
                    -- el cliente posea más de una.
                    select f.nro_tarjeta --, f.cod_persona
                      from ge_clientes     gf,
                            ge_cta_clientes ge,
                            ta_tarjetas     f,
                            ta_cta_tarjetas cf
                     where gf.cod_persona = ge.cod_persona
                       and ge.nro_cuenta = f.nro_cuenta
                       and f.nro_cuenta = cf.nro_cuenta
                       and f.cod_persona = ge.cod_persona
                       and f.cod_estado = 6
                       and fug_obt_pardinamico('CAT_TARJETA',
                                               cf.cod_modulo,
                                               cf.cod_modalidad) =
                           (select categoria_m
                              from ( -- Mayor categoria por cliente.
                                    select M.cod_persona,
                                            max(M.categoria) categoria_m
                                      from ( -- Todas las categorías por cliente.
                                             select q.cod_persona,
                                                     fug_obt_pardinamico('CAT_TARJETA',
                                                                         r.cod_modulo,
                                                                         r.cod_modalidad) categoria
                                               from ta_tarjetas q, ta_cta_tarjetas r
                                              where q.nro_cuenta = r.nro_cuenta
                                                and q.cod_estado = 6) M
                                     group by M.cod_persona) N
                             where f.cod_persona = N.cod_persona)
                       and f.cod_persona = t.cod_persona
                       and rownum = 1)) x
     order by x.fec_vencimiento;

 
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
               CHR(59) || 'CODIGO_TARJETA' || CHR(59) || 'CI';
  utl_file.put_line(v_file, v_linetit);

  -- Definir una linea en blanco para separar los datos del titulo de los campos
  v_linetit := ' ';
  utl_file.put_line(v_file, v_linetit);

  --Definir un cursor for loop que recorre los datos obtenidos
  FOR REC IN cu_asiviajero LOOP

    --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
    v_line := to_char(rec.tarjeta) || chr(59) || to_char(rec.nombre) ||
              chr(59) || to_char(rec.vencimiento) || chr(59) ||
              to_char(rec.tipo_tarjeta) || chr(59) ||
              to_char(rec.tipo_cliente) || chr(59) ||
              to_char(rec.codigo_tarjeta) || chr(59) || to_char(rec.ci);

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

    EXIT WHEN cu_asiviajero%NOTFOUND;
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
                  (720, 'PRT_GEN_ARC_VIAJERO', v_hini_mail, v_hfin_mail, v_det_error);
      COMMIT;
    END IF;

  ELSE
    -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error := null;

    -- Insertamos el error del envio al directorio compartido
      INSERT INTO ge_pro_aut_logs
                  (cod_proceso, nom_proceso, fec_hor_ini, fec_hor_fin, men_error)
          VALUES
                  (720, 'PRT_GEN_ARC_VIAJERO', v_hini_mail, v_hfin_mail, v_det_error);
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
                  (720, 'PRT_GEN_ARC_VIAJERO', v_hini_mail, v_hfin_mail, v_det_error);
    END IF;

  END IF;
  COMMIT;
EXCEPTION
  WHEN OTHERS THEN 
    v_err_code := SQLCODE;
    v_err_msj  := substr(sqlerrm, 1, 4000);
    UTL_FILE.FCLOSE(v_file);
     INSERT INTO ge_pro_aut_logs (cod_proceso, nom_proceso, fec_hor_ini, fec_hor_fin, nro_error, men_error)
          VALUES (720, 'PRT_GEN_ARC_VIAJERO', v_hini_mail, v_hfin_mail, v_err_code, v_err_msj);

END prt_gen_arc_viajero;
/

