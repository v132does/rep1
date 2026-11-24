CREATE OR REPLACE PACKAGE BODY IT.PAG_REP IS
--------------------------------------------------------------------------------------------------------------------------------------
-- Funcion para obtener valores de GE_PAR_RA
FUNCTION fu_obt_valor_par
    (
    v_servicio IN varchar2 DEFAULT 'ALL',
    v_tabla    IN varchar2,
    v_campo    IN varchar2
    )
    RETURN  varchar2 IS

  -- Proposito: Retorna valor de un campo espec¿fico de la tabla de GE_PAR_RA
  -- Precondici¿n:  los par¿metros no deben ser nulos
  -- Poscondicion: devuelve un valor 'ERROR' en caso de errores

     v_valor     varchar2(4000);
  BEGIN
    begin
    select valor into v_valor
      from ge_par_ra
      where cod_servicio = v_servicio
      and nombre_servicio = v_tabla
      and nombre_campo = v_campo;
    exception
      when others then
      v_valor := 'ERROR';
    end;

     RETURN v_valor ;
  END;
------------------------prb_con_iva_cua_modalidad----------------------------------
PROCEDURE prb_con_iva_cua_modalidad
IS

CURSOR dat_cua_modalidad IS
  select tip_movimiento, IVA, COD_MOD_PADRE, COD_MAD_PADRE,descripcion,tipo,
         sum(mto_asiento) mto_asiento, sum(mto_factura) mto_factura, 
         sum(mto_asiento) - sum(mto_factura) diferencia
   from cb_inf_ctr_iva_tmp t
  group by tip_movimiento,IVA,COD_MOD_PADRE, COD_MAD_PADRE,tipo,descripcion
  order by IVA desc,tipo,COD_MOD_PADRE,COD_MAD_PADRE;


  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'con_iva_cua_modalidad'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_fec_sist         DATE;
  v_fecha            VARCHAR2(8);
  v_fec_enc_legal    DATE;

  -- Variables para mail
  v_conn             utl_smtp.connection;
  v_para             VARCHAR2(500);
  v_asunto           VARCHAR2(2000);
  v_mje_mail         VARCHAR2(4000);
  v_hini_mail        ge_ra_log_mail.hor_inicio%type;
  v_hfin_mail        ge_ra_log_mail.hor_fin%type;
  v_det_error        ge_ra_log_mail.det_error%type;

  -- Variables para FTP
  v_respuesta        VARCHAR2(4000);
  v_hini_ftp         ge_ra_log_ftp.hor_inicio%type;
  v_hfin_ftp         ge_ra_log_ftp.hor_fin%type;

BEGIN

  -- Obtenemos la fecha del sistema
  select pag_cal.FU_OBT_FEC_ANTERIOR(2)
    into v_fec_sist
    from dual;

  v_fecha := to_char(v_fec_sist,'DDMMYYYY');

  -- Abrir archivo
  v_file := UTL_FILE.FOPEN(pa_rep_aut.g_repository,v_name||'.csv','W',32767);

  -- Colocar el titulo a los campos
  v_linetit := 'TIP_MOVIMIENTO'||chr(59)||
               'IVA'||chr(59)||
               'COD_MOD_PADRE'||chr(59)||
               'COD_MAD_PADRE'||chr(59)||
               'DESCRIPCION' ||chr(59)||
               'TIPO' ||chr(59)||
               'MONTO_ASIENTO' ||chr(59)||
               'MONTO_FACTURA' ||chr(59)||
               'DIFERENCIA' || v_eol;

  utl_file.put_line(v_file,v_linetit);

  --Definir un cursor for loop que recorre los datos obtenidos
  FOR REC IN dat_cua_modalidad LOOP

  --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(59))

    v_line := to_char(rec.TIP_MOVIMIENTO)||chr(59)||
              to_char(rec.IVA)||chr(59)||                    
              to_char(rec.COD_MOD_PADRE)||chr(59)||
              to_char(rec.COD_MAD_PADRE)||chr(59)||                            
              to_char(rec.DESCRIPCION)||chr(59)||
              to_char(rec.TIPO)||chr(59)||
              to_char(rec.MTO_ASIENTO)||chr(59)||                            
              to_char(rec.MTO_FACTURA)||chr(59)||              
              to_char(rec.DIFERENCIA);

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

    EXIT WHEN dat_cua_modalidad%NOTFOUND;
  END LOOP;
  --Escribes la linea en el fichero
  UTL_FILE.PUT_LINE(v_file, v_buffer);

  --Cerrar el handler al fichero
  UTL_FILE.FCLOSE(v_file);
  COMMIT;

    v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

    -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
    v_respuesta := pa_file_ftp.fu_put_ascii(pa_rep_aut.g_ip, 
                                            pa_rep_aut.g_port,
                                            pa_rep_aut.g_user,
                                            pa_rep_aut.g_pass, 
                                            pa_rep_aut.g_repository,
                                            v_name||'.csv', g_contabilidad||v_name||'_'||v_fecha||'.csv');

    v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

    IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
        -- Obtenemos los direcciones de correo para quien o quienes va el correo
        v_para := pa_rep_aut.FU_OBT_VALOR_PAR('RA','REPORTES','IVA');

        -- Damos valor a los demas datos
        v_asunto := 'Informes Complementarios de IVA - Cuadre por Modalidad de fecha '|| to_char(v_fec_sist,'dd/mm/yyy') ||'.';
        v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente direcci¿n: '||g_compartido||g_contabilidad||'

      Nombre del Archivo: '||v_name||'_'||v_fecha||'.csv';

       -- Enviamos el mail
        v_det_error    := null;
        v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

        BEGIN
          it_mail.mail(pa_rep_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        EXCEPTION
          when utl_smtp.transient_error or utl_smtp.permanent_error then
              begin
                utl_smtp.quit(v_conn);
              exception
              when utl_smtp.transient_error or utl_smtp.permanent_error then
                null;
              end;
              v_det_error := substr(sqlerrm,1,4000);
        END;

        v_hfin_mail := to_char(sysdate,'hh24:mi:ss');

        -- Insertamos en la tabla de log  si ocurrio algun error al enviar el mail
        IF v_det_error is not null THEN
            INSERT INTO ge_ra_log_mail
             (fec_envio, nom_archivo, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
            VALUES
             (SYSDATE, v_name||'_'||v_fecha||'.csv', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
            COMMIT;
        END IF;

    ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
      v_det_error    := null;

      -- Insertamos el error del envio al directorio compartido
      INSERT INTO ge_ra_log_ftp
       (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
      VALUES
       (SYSDATE, v_name||'_'||v_fecha||'.csv', v_respuesta, v_hini_ftp, v_hfin_ftp);
      COMMIT;

      --Enviamos el mail a soporte
       -- Obtenemos direccion de correo de soporte
       v_para := pa_rep_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

      -- Damos valor a los demas datos
        v_asunto := 'Error Informes Complementarios de IVA - Cuadre por Modalidad de fecha '||v_fec_enc_legal||'.';
        v_mje_mail := 'Error al enviar archivo por FTP.

      Error: '||v_respuesta||'.

      Para mas informaci¿n verificar la tabla GE_RA_LOG_FTP';

        v_hini_mail := to_char(sysdate,'hh24:mi:ss');

        BEGIN
          it_mail.mail(pa_rep_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        EXCEPTION
          when utl_smtp.transient_error or utl_smtp.permanent_error then
              begin
                utl_smtp.quit(v_conn);
              exception
              when utl_smtp.transient_error or utl_smtp.permanent_error then
                null;
              end;
              v_det_error := substr(sqlerrm,1,4000);
        END;

        v_hfin_mail := to_char(sysdate,'hh24:mi:ss');

        -- Insertamos en la tabla de log  si ocurrio algun error al enviar el mail
        IF v_det_error is not null THEN
            INSERT INTO ge_ra_log_mail
             (fec_envio, nom_archivo, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
            VALUES
             (SYSDATE, v_name||'_'||v_fecha||'.csv', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
            COMMIT;
        END IF;

    END IF;
    COMMIT;
EXCEPTION
  WHEN UTL_FILE.INVALID_OPERATION THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20061,'Operacion invalida '||sqlerrm);
  WHEN UTL_FILE.INVALID_FILEHANDLE THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20062,'Manejador invalido '||sqlerrm);
  WHEN UTL_FILE.WRITE_ERROR THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20063,'Error de escritura '||sqlerrm);
  WHEN UTL_FILE.INVALID_MODE THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20064,'Modo invalido '||sqlerrm);
  WHEN UTL_FILE.INTERNAL_ERROR THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20065,'Internal Error '||sqlerrm);
END prb_con_iva_cua_modalidad;
------------------------prb_con_iva_cua_modalidad----------------------------------

------------------------prb_con_iva_cua_movimientos----------------------------------
PROCEDURE prb_con_iva_cua_movimientos
IS


CURSOR dat_cua_movimientos IS
    select TIP_MOVIMIENTO,IVA,COD_MOD_PADRE,COD_MAD_PADRE,DESCRIPCION, 
    FECHA,HORA,COD_USUARIO,REVERSADO,TIPO,mto_asiento,mto_factura ,DIFERENCIA
   from cb_inf_ctr_iva_tmp t
  order by IVA desc,tipo,COD_MOD_PADRE,COD_MAD_PADRE, FECHA,HORA,COD_USUARIO,REVERSADO;


  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'con_iva_cua_movimientos'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_fec_sist         DATE;
  v_fecha            VARCHAR2(8);
  v_fec_enc_legal    DATE;

  -- Variables para mail
  v_conn             utl_smtp.connection;
  v_para             VARCHAR2(500);
  v_asunto           VARCHAR2(2000);
  v_mje_mail         VARCHAR2(4000);
  v_hini_mail        ge_ra_log_mail.hor_inicio%type;
  v_hfin_mail        ge_ra_log_mail.hor_fin%type;
  v_det_error        ge_ra_log_mail.det_error%type;

  -- Variables para FTP
  v_respuesta        VARCHAR2(4000);
  v_hini_ftp         ge_ra_log_ftp.hor_inicio%type;
  v_hfin_ftp         ge_ra_log_ftp.hor_fin%type;

BEGIN

  -- Obtenemos la fecha del sistema
  select pag_cal.FU_OBT_FEC_ANTERIOR(2)
    into v_fec_sist
    from dual;

  v_fecha := to_char(v_fec_sist,'DDMMYYYY');

  -- Abrir archivo
  v_file := UTL_FILE.FOPEN(pa_rep_aut.g_repository,v_name||'.csv','W',32767);

  -- Colocar el titulo a los campos
  v_linetit := 'TIP_MOVIMIENTO'||chr(59)||
               'IVA'||chr(59)||
               'COD_MOD_PADRE'||chr(59)||
               'COD_MAD_PADRE'||chr(59)||
               'DESCRIPCION' ||chr(59)||
               'FECHA' ||chr(59)||
               'HORA' ||chr(59)||
               'COD_USUARIO' ||chr(59)||
               'REVERSADO' ||chr(59)||
               'TIPO' ||chr(59)||
               'MONTO_ASIENTO' ||chr(59)||
               'MONTO_FACTURA' ||chr(59)||
               'DIFERENCIA' || v_eol;

  utl_file.put_line(v_file,v_linetit);

  --Definir un cursor for loop que recorre los datos obtenidos
  FOR REC IN dat_cua_movimientos LOOP

  --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(59))

    v_line := to_char(rec.TIP_MOVIMIENTO)||chr(59)||
              to_char(rec.IVA)||chr(59)||                    
              to_char(rec.COD_MOD_PADRE)||chr(59)||
              to_char(rec.COD_MAD_PADRE)||chr(59)||                            
              to_char(rec.DESCRIPCION)||chr(59)||
              to_char(rec.FECHA)||chr(59)||
              to_char(rec.HORA)||chr(59)||
              to_char(rec.COD_USUARIO)||chr(59)||
              to_char(rec.reversado)||chr(59)||
              to_char(rec.TIPO)||chr(59)||
              to_char(rec.MTO_ASIENTO)||chr(59)||                            
              to_char(rec.MTO_FACTURA)||chr(59)||              
              to_char(rec.DIFERENCIA);

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

    EXIT WHEN dat_cua_movimientos%NOTFOUND;
  END LOOP;
  --Escribes la linea en el fichero
  UTL_FILE.PUT_LINE(v_file, v_buffer);

  --Cerrar el handler al fichero
  UTL_FILE.FCLOSE(v_file);
  COMMIT;

    v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

    -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
    v_respuesta := pa_file_ftp.fu_put_ascii(pa_rep_aut.g_ip, 
                                            pa_rep_aut.g_port,
                                            pa_rep_aut.g_user,
                                            pa_rep_aut.g_pass, 
                                            pa_rep_aut.g_repository,
                                            v_name||'.csv', g_contabilidad||v_name||'_'||v_fecha||'.csv');

    v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

    IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
        -- Obtenemos los direcciones de correo para quien o quienes va el correo
        v_para := pa_rep_aut.FU_OBT_VALOR_PAR('RA','REPORTES','IVA');

        -- Damos valor a los demas datos
        v_asunto := 'Informes Complementarios de IVA - Cuadre por Movimientos de fecha '|| to_char(v_fec_sist,'dd/mm/yyy') ||'.';
        v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente direcci¿n: '||g_compartido||g_contabilidad||'

      Nombre del Archivo: '||v_name||'_'||v_fecha||'.csv';

       -- Enviamos el mail
        v_det_error    := null;
        v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

        BEGIN
          it_mail.mail(pa_rep_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        EXCEPTION
          when utl_smtp.transient_error or utl_smtp.permanent_error then
              begin
                utl_smtp.quit(v_conn);
              exception
              when utl_smtp.transient_error or utl_smtp.permanent_error then
                null;
              end;
              v_det_error := substr(sqlerrm,1,4000);
        END;

        v_hfin_mail := to_char(sysdate,'hh24:mi:ss');

        -- Insertamos en la tabla de log  si ocurrio algun error al enviar el mail
        IF v_det_error is not null THEN
            INSERT INTO ge_ra_log_mail
             (fec_envio, nom_archivo, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
            VALUES
             (SYSDATE, v_name||'_'||v_fecha||'.csv', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
            COMMIT;
        END IF;

    ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
      v_det_error    := null;

      -- Insertamos el error del envio al directorio compartido
      INSERT INTO ge_ra_log_ftp
       (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
      VALUES
       (SYSDATE, v_name||'_'||v_fecha||'.csv', v_respuesta, v_hini_ftp, v_hfin_ftp);
      COMMIT;

      --Enviamos el mail a soporte
       -- Obtenemos direccion de correo de soporte
       v_para := pa_rep_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

      -- Damos valor a los demas datos
        v_asunto := 'Error Informes Complementarios de IVA - Cuadre por Movimientos de fecha '||v_fec_enc_legal||'.';
        v_mje_mail := 'Error al enviar archivo por FTP.

      Error: '||v_respuesta||'.

      Para mas informaci¿n verificar la tabla GE_RA_LOG_FTP';

        v_hini_mail := to_char(sysdate,'hh24:mi:ss');

        BEGIN
          it_mail.mail(pa_rep_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        EXCEPTION
          when utl_smtp.transient_error or utl_smtp.permanent_error then
              begin
                utl_smtp.quit(v_conn);
              exception
              when utl_smtp.transient_error or utl_smtp.permanent_error then
                null;
              end;
              v_det_error := substr(sqlerrm,1,4000);
        END;

        v_hfin_mail := to_char(sysdate,'hh24:mi:ss');

        -- Insertamos en la tabla de log  si ocurrio algun error al enviar el mail
        IF v_det_error is not null THEN
            INSERT INTO ge_ra_log_mail
             (fec_envio, nom_archivo, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
            VALUES
             (SYSDATE, v_name||'_'||v_fecha||'.csv', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
            COMMIT;
        END IF;

    END IF;
    COMMIT;
EXCEPTION
  WHEN UTL_FILE.INVALID_OPERATION THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20061,'Operacion invalida '||sqlerrm);
  WHEN UTL_FILE.INVALID_FILEHANDLE THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20062,'Manejador invalido '||sqlerrm);
  WHEN UTL_FILE.WRITE_ERROR THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20063,'Error de escritura '||sqlerrm);
  WHEN UTL_FILE.INVALID_MODE THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20064,'Modo invalido '||sqlerrm);
  WHEN UTL_FILE.INTERNAL_ERROR THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20065,'Internal Error '||sqlerrm);
END prb_con_iva_cua_movimientos;
------------------------prb_con_iva_cua_movimientos----------------------------------

------------------------prb_con_iva_det_movimientos----------------------------------
PROCEDURE prb_con_iva_det_movimientos
IS

CURSOR dat_det_movimientos(p_fecha IN DATE) IS
  -- detalle de movimientos con descuadre superiores a 10 Gs
select a.FECHA,a.HORA,a.COD_USUARIO,d.nombre usuario_mov,a.NRO_SECUENCIA, -- pk mov
       a.FEC_VALOR,a.MONTO,a.MTO_EQU_LOCAL,a.COD_MONEDA,a.COTIZACION, --monto y moneda
       a.NRO_CUENTA,a.COD_PERSONA,a.DENOMINACION,
       a.VAL_TASA,a.NRO_DOCUMENTO4,a.COD_OFICINA,a.CONCEPTO,
       a.COD_MOD_PADRE,a.COD_MAD_PADRE,a.COD_MODULO,a.COD_MODALIDAD,
       a.COD_TRA_PADRE,a.DES_TRA_PADRE,a.COD_TRANSACCION,a.DES_TRANSACCION,
       a.REVERSADO,a.COD_USU_REVERSION,a.HOR_REVERSION, -- datos reversion
       a.FEC_INSERCION, e.nombre usuario_ins,
      --datos de la factura o NC
      c.TIPO_FACTURA,c.COD_TRA_PADRE_FACTURA,c.DES_FACTURA,c.NOM_COMPLETO,c.NRO_DOCUMENTO_FACTURA,
      c.COD_MONEDA_FACTURA,c.MTO_EXENTO,c.MTO_EXENTO_GS,c.MTO_GRAVADO_5,c.MTO_GRA_5_GS,c.MTO_GRAVADO_10,
      c.MTO_GRA_10_GS,c.IMPUESTO_5,c.IMPUESTO_5_GS,c.IMPUESTO_10,c.IMPUESTO_10_GS,c.COTIZACION_FACTURA,
      c.NRO_FACTURA,c.NRO_CUENTA_FACTURA,c.COD_PERSONA_FACTURA,c.fec_insercion_factura,c.USU_INSERCION_FACTURA,c.TIP_COMPROBANTE,c.TIP_VENTA
from gv_movimientos a
join (select distinct fecha,hora,cod_usuario
      from cb_inf_ctr_iva_tmp t
      where abs(t.diferencia) > 10) b on a.FECHA=b.fecha and a.HORA=b.hora and a.COD_USUARIO=b.cod_usuario
left join ba_usuarios d on d.cod_usuario=a.COD_USUARIO
left join ba_usuarios e on e.cod_usuario=a.USU_INSERCION
left join (select 'Definitiva' tipo_factura, x.fecha,x.hora,x.cod_usuario,x.nro_secuencia, --fk movimiento
      x.cod_tra_padre cod_tra_padre_factura, x.descripcion des_factura, w.nom_completo,x.nro_documento nro_documento_factura,
      x.COD_MONEDA COD_MONEDA_FACTURA,x.MTO_EXENTO,x.MTO_EXENTO_GS,x.MTO_GRAVADO_5,x.MTO_GRA_5_GS,      
      x.MTO_GRAVADO_10,x.MTO_GRA_10_GS,x.IMPUESTO_5,x.IMPUESTO_5_GS,x.IMPUESTO_10,x.IMPUESTO_10_GS,x.COTIZACION COTIZACION_FACTURA, --montos y moneda
      x.nro_factura,x.nro_cuenta NRO_CUENTA_FACTURA, null COD_PERSONA_FACTURA, -- nro factura y datos del cliente
      x.fec_insercion fec_insercion_factura,x.usu_insercion usu_insercion_factura,w.tip_comprobante,w.tip_venta
      from cb_lib_ventas_det x
           join cb_lib_ventas w on w.nro_factura=x.nro_factura and w.nro_timbrado=x.nro_timbrado
      where x.fecha=p_fecha
      union all
      select 'Temporal' tipo_factura,y.fecha,y.hora,y.cod_usuario,y.nro_secuencia, --fk movimiento
      y.cod_tra_padre cod_tra_padre_factura, y.descripcion des_factura, y.nom_completo,y.nro_documento nro_documento_factura,
      y.COD_MONEDA COD_MONEDA_FACTURA,y.MTO_EXENTO,y.MTO_EXENTO_GS,y.MTO_GRAVADO_5,y.MTO_GRA_5_GS,
      y.MTO_GRAVADO_10,y.MTO_GRA_10_GS,y.IMPUESTO_5,y.IMPUESTO_5_GS,y.IMPUESTO_10,y.IMPUESTO_10_GS,y.COTIZACION COTIZACION_FACTURA, --montos y moneda
      y.nro_factura,y.nro_cuenta NRO_CUENTA_FACTURA, y.cod_persona COD_PERSONA_FACTURA, -- nro factura y datos del cliente
      y.fec_insercion fec_insercion_factura,y.usu_insercion usu_insercion_factura,decode(y.reversado,'N','F','NC') tip_comprobante,y.tip_venta
      from cb_lib_ventas_det_tmp y
      where y.fecha=p_fecha
      union all
      select 'Eliminada' tipo_factura,z.fecha,z.hora,z.cod_usuario,z.nro_secuencia, --fk movimiento
      z.cod_tra_padre cod_tra_padre_factura, z.descripcion des_factura, z.nom_completo,z.nro_documento nro_documento_factura,
      z.COD_MONEDA COD_MONEDA_FACTURA,z.MTO_EXENTO,z.MTO_EXENTO_GS,z.MTO_GRAVADO_5,z.MTO_GRA_5_GS,
      z.MTO_GRAVADO_10,z.MTO_GRA_10_GS,z.IMPUESTO_5,z.IMPUESTO_5_GS,z.IMPUESTO_10,z.IMPUESTO_10_GS,z.COTIZACION COTIZACION_FACTURA,  --montos y moneda
      z.nro_factura,z.nro_cuenta NRO_CUENTA_FACTURA, z.cod_persona COD_PERSONA_FACTURA, -- nro factura y datos del cliente
      z.fec_insercion fec_insercion_factura,z.usu_insercion usu_insercion_factura, decode(z.reversado,'N','F','NC') tip_comprobante,z.tip_venta
      from cb_obs_lib_ventas_det_tmp z
      where z.fecha=p_fecha) c on a.FECHA=c.fecha and a.hora=c.hora and a.COD_USUARIO=c.cod_usuario and a.NRO_SECUENCIA=c.nro_secuencia
where a.TIPO='H'
order by a.fecha,a.hora,a.cod_usuario,a.nro_secuencia; 


  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'con_iva_det_movimientos'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_fec_sist         DATE;
  v_fecha            VARCHAR2(8);
  v_fec_enc_legal    DATE;

  -- Variables para mail
  v_conn             utl_smtp.connection;
  v_para             VARCHAR2(500);
  v_asunto           VARCHAR2(2000);
  v_mje_mail         VARCHAR2(4000);
  v_hini_mail        ge_ra_log_mail.hor_inicio%type;
  v_hfin_mail        ge_ra_log_mail.hor_fin%type;
  v_det_error        ge_ra_log_mail.det_error%type;

  -- Variables para FTP
  v_respuesta        VARCHAR2(4000);
  v_hini_ftp         ge_ra_log_ftp.hor_inicio%type;
  v_hfin_ftp         ge_ra_log_ftp.hor_fin%type;

BEGIN

  -- Obtenemos la fecha del sistema
  select pag_cal.FU_OBT_FEC_ANTERIOR(2)
    into v_fec_sist
    from dual;

  v_fecha := to_char(v_fec_sist,'DDMMYYYY');

  -- Abrir archivo
  v_file := UTL_FILE.FOPEN(pa_rep_aut.g_repository,v_name||'.csv','W',32767);

  -- Colocar el titulo a los campos
  v_linetit := 'FECHA'||chr(59)||
               'HORA'||chr(59)||
               'COD_USUARIO'||chr(59)||
               'USUARIO_MOV'||chr(59)||
               'NRO_SECUENCIA'||chr(59)||
               'FEC_VALOR'||chr(59)||
               'MONTO'||chr(59)||
               'MTO_EQU_LOCAL'||chr(59)||
               'COD_MONEDA'||chr(59)||
               'COTIZACION'||chr(59)||
               'NRO_CUENTA'||chr(59)||
               'COD_PERSONA'||chr(59)||
               'DENOMINACION'||chr(59)||
               'VAL_TASA'||chr(59)||
               'NRO_DOCUMENTO4'||chr(59)||
               'COD_OFICINA'||chr(59)||
               'CONCEPTO'||chr(59)||
               'COD_MOD_PADRE'||chr(59)||
               'COD_MAD_PADRE'||chr(59)||
               'COD_MODULO'||chr(59)||
               'COD_MODALIDAD'||chr(59)||
               'COD_TRA_PADRE'||chr(59)||
               'DES_TRA_PADRE'||chr(59)||
               'COD_TRANSACCION'||chr(59)||
               'DES_TRANSACCION'||chr(59)||
               'REVERSADO'||chr(59)||
               'COD_USU_REVERSION'||chr(59)||
               'HOR_REVERSION'||chr(59)||
               'FEC_INSERCION'||chr(59)||
               'USUARIO_INS'||chr(59)||
               'TIPO_FACTURA'||chr(59)||
               'COD_TRA_PADRE_FACTURA'||chr(59)||
               'DES_FACTURA'||chr(59)||
               'NOM_COMPLETO'||chr(59)||
               'NRO_DOCUMENTO_FACTURA'||chr(59)||
               'COD_MONEDA_FACTURA'||chr(59)||
               'MTO_EXENTO'||chr(59)||
               'MTO_EXENTO_GS'||chr(59)||
               'MTO_GRAVADO_5'||chr(59)||
               'MTO_GRA_5_GS'||chr(59)||
               'MTO_GRAVADO_10'||chr(59)||
               'MTO_GRA_10_GS'||chr(59)||
               'IMPUESTO_5'||chr(59)||
               'IMPUESTO_5_GS'||chr(59)||
               'IMPUESTO_10'||chr(59)||
               'IMPUESTO_10_GS'||chr(59)||
               'COTIZACION_FACTURA'||chr(59)||
               'NRO_FACTURA'||chr(59)||
               'NRO_CUENTA_FACTURA'||chr(59)||
               'COD_PERSONA_FACTURA'||chr(59)||
               'FEC_INSERCION_FACTURA'||chr(59)||
               'USU_INSERCION_FACTURA'||chr(59)||
               'TIP_COMPROBANTE'||chr(59)||
               'TIP_VENTA'|| v_eol;

  utl_file.put_line(v_file,v_linetit);

  --Definir un cursor for loop que recorre los datos obtenidos
  FOR REC IN dat_det_movimientos(v_fec_sist) LOOP

  --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(59))

    v_line := to_char(rec.FECHA)||chr(59)||   
              to_char(rec.HORA)||chr(59)||   
              to_char(rec.COD_USUARIO)||chr(59)||   
              to_char(rec.USUARIO_MOV)||chr(59)||   
              to_char(rec.NRO_SECUENCIA)||chr(59)||   
              to_char(rec.FEC_VALOR)||chr(59)||   
              to_char(rec.MONTO)||chr(59)||   
              to_char(rec.MTO_EQU_LOCAL)||chr(59)||   
              to_char(rec.COD_MONEDA)||chr(59)||   
              to_char(rec.COTIZACION)||chr(59)||   
              to_char(rec.NRO_CUENTA)||chr(59)||   
              to_char(rec.COD_PERSONA)||chr(59)||   
              to_char(rec.DENOMINACION)||chr(59)||   
              to_char(rec.VAL_TASA)||chr(59)||   
              to_char(rec.NRO_DOCUMENTO4)||chr(59)||   
              to_char(rec.COD_OFICINA)||chr(59)||   
              to_char(rec.CONCEPTO)||chr(59)||   
              to_char(rec.COD_MOD_PADRE)||chr(59)||   
              to_char(rec.COD_MAD_PADRE)||chr(59)||   
              to_char(rec.COD_MODULO)||chr(59)||   
              to_char(rec.COD_MODALIDAD)||chr(59)||   
              to_char(rec.COD_TRA_PADRE)||chr(59)||   
              to_char(rec.DES_TRA_PADRE)||chr(59)||   
              to_char(rec.COD_TRANSACCION)||chr(59)||   
              to_char(rec.DES_TRANSACCION)||chr(59)||   
              to_char(rec.REVERSADO)||chr(59)||   
              to_char(rec.COD_USU_REVERSION)||chr(59)||   
              to_char(rec.HOR_REVERSION)||chr(59)||   
              to_char(rec.FEC_INSERCION)||chr(59)||   
              to_char(rec.USUARIO_INS)||chr(59)||   
              to_char(rec.TIPO_FACTURA)||chr(59)||   
              to_char(rec.COD_TRA_PADRE_FACTURA)||chr(59)||   
              to_char(rec.DES_FACTURA)||chr(59)||   
              to_char(rec.NOM_COMPLETO)||chr(59)||   
              to_char(rec.NRO_DOCUMENTO_FACTURA)||chr(59)||   
              to_char(rec.COD_MONEDA_FACTURA)||chr(59)||   
              to_char(rec.MTO_EXENTO)||chr(59)||   
              to_char(rec.MTO_EXENTO_GS)||chr(59)||   
              to_char(rec.MTO_GRAVADO_5)||chr(59)||   
              to_char(rec.MTO_GRA_5_GS)||chr(59)||   
              to_char(rec.MTO_GRAVADO_10)||chr(59)||   
              to_char(rec.MTO_GRA_10_GS)||chr(59)||   
              to_char(rec.IMPUESTO_5)||chr(59)||   
              to_char(rec.IMPUESTO_5_GS)||chr(59)||   
              to_char(rec.IMPUESTO_10)||chr(59)||   
              to_char(rec.IMPUESTO_10_GS)||chr(59)||   
              to_char(rec.COTIZACION_FACTURA)||chr(59)||   
              to_char(rec.NRO_FACTURA)||chr(59)||   
              to_char(rec.NRO_CUENTA_FACTURA)||chr(59)||   
              to_char(rec.COD_PERSONA_FACTURA)||chr(59)||   
              to_char(rec.FEC_INSERCION_FACTURA)||chr(59)||   
              to_char(rec.USU_INSERCION_FACTURA)||chr(59)||   
              to_char(rec.TIP_COMPROBANTE)||chr(59)||   
              to_char(rec.TIP_VENTA);

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

    EXIT WHEN dat_det_movimientos%NOTFOUND;
  END LOOP;
  --Escribes la linea en el fichero
  UTL_FILE.PUT_LINE(v_file, v_buffer);

  --Cerrar el handler al fichero
  UTL_FILE.FCLOSE(v_file);
  COMMIT;

    v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

    -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
    v_respuesta := pa_file_ftp.fu_put_ascii(pa_rep_aut.g_ip, 
                                            pa_rep_aut.g_port,
                                            pa_rep_aut.g_user,
                                            pa_rep_aut.g_pass, 
                                            pa_rep_aut.g_repository,
                                            v_name||'.csv', g_contabilidad||v_name||'_'||v_fecha||'.csv');

    v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

    IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
        -- Obtenemos los direcciones de correo para quien o quienes va el correo
        v_para := pa_rep_aut.FU_OBT_VALOR_PAR('RA','REPORTES','IVA');

        -- Damos valor a los demas datos
        v_asunto := 'Informes Complementarios de IVA - Detalle de movimientos de fecha '|| to_char(v_fec_sist,'dd/mm/yyy') ||'.';
        v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente direcci¿n: '||g_compartido||g_contabilidad||'

      Nombre del Archivo: '||v_name||'_'||v_fecha||'.csv';

       -- Enviamos el mail
        v_det_error    := null;
        v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

        BEGIN
          it_mail.mail(pa_rep_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        EXCEPTION
          when utl_smtp.transient_error or utl_smtp.permanent_error then
              begin
                utl_smtp.quit(v_conn);
              exception
              when utl_smtp.transient_error or utl_smtp.permanent_error then
                null;
              end;
              v_det_error := substr(sqlerrm,1,4000);
        END;

        v_hfin_mail := to_char(sysdate,'hh24:mi:ss');

        -- Insertamos en la tabla de log  si ocurrio algun error al enviar el mail
        IF v_det_error is not null THEN
            INSERT INTO ge_ra_log_mail
             (fec_envio, nom_archivo, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
            VALUES
             (SYSDATE, v_name||'_'||v_fecha||'.csv', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
            COMMIT;
        END IF;

    ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
      v_det_error    := null;

      -- Insertamos el error del envio al directorio compartido
      INSERT INTO ge_ra_log_ftp
       (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
      VALUES
       (SYSDATE, v_name||'_'||v_fecha||'.csv', v_respuesta, v_hini_ftp, v_hfin_ftp);
      COMMIT;

      --Enviamos el mail a soporte
       -- Obtenemos direccion de correo de soporte
       v_para := pa_rep_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

      -- Damos valor a los demas datos
        v_asunto := 'Error Informes Complementarios de IVA - Detalle de movimientos de fecha '||v_fec_enc_legal||'.';
        v_mje_mail := 'Error al enviar archivo por FTP.

      Error: '||v_respuesta||'.

      Para mas informaci¿n verificar la tabla GE_RA_LOG_FTP';

        v_hini_mail := to_char(sysdate,'hh24:mi:ss');

        BEGIN
          it_mail.mail(pa_rep_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        EXCEPTION
          when utl_smtp.transient_error or utl_smtp.permanent_error then
              begin
                utl_smtp.quit(v_conn);
              exception
              when utl_smtp.transient_error or utl_smtp.permanent_error then
                null;
              end;
              v_det_error := substr(sqlerrm,1,4000);
        END;

        v_hfin_mail := to_char(sysdate,'hh24:mi:ss');

        -- Insertamos en la tabla de log  si ocurrio algun error al enviar el mail
        IF v_det_error is not null THEN
            INSERT INTO ge_ra_log_mail
             (fec_envio, nom_archivo, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
            VALUES
             (SYSDATE, v_name||'_'||v_fecha||'.csv', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
            COMMIT;
        END IF;

    END IF;
    COMMIT;
EXCEPTION
  WHEN UTL_FILE.INVALID_OPERATION THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20061,'Operacion invalida '||sqlerrm);
  WHEN UTL_FILE.INVALID_FILEHANDLE THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20062,'Manejador invalido '||sqlerrm);
  WHEN UTL_FILE.WRITE_ERROR THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20063,'Error de escritura '||sqlerrm);
  WHEN UTL_FILE.INVALID_MODE THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20064,'Modo invalido '||sqlerrm);
  WHEN UTL_FILE.INTERNAL_ERROR THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20065,'Internal Error '||sqlerrm);
END prb_con_iva_det_movimientos;
------------------------prb_con_iva_det_movimientos----------------------------------
--Informes Complementarios de IVA - Insercion y Generacion de informes complementarios de control de IVA
PROCEDURE prb_con_iva_complement IS
  -- Variables
  v_fec_sist         DATE;
  
  BEGIN
    -- Informes Adicionales - SC 15528 - ITGF - Reestructuracion de Informe de control IVA - Facturacion
    -- se trunca tabla del informe
    execute immediate 'truncate table cb_inf_ctr_iva_tmp';
    
    --Obtenemos la fecha anterior del sistema modulo 2 (Contabilidad)
    v_fec_sist := pag_cal.FU_OBT_FEC_ANTERIOR(2);
    
    -- Cuadre asientos - movimientos - facturas
    -- Inserta Creditos
   insert into cb_inf_ctr_iva_tmp (tip_movimiento,iva,cod_mod_padre,cod_mad_padre,descripcion,fecha,hora,
                                  cod_usuario,reversado,tipo,mto_asiento,mto_factura,diferencia) 
    select 'Credito' TIP_MOVIMIENTO, IVA, COD_MOD_PADRE, COD_MAD_PADRE, 
           decode(nvl(c.descripcion,''),'','',decode(V_AUX,0,c.descripcion,c.descripcion || ' - ')) || 
           decode(V_AUX,'99','Informe Financiero','98','Reversiones del d¿a','97','Facturas eliminadas por Rev.del mes',95,'Facturas Temporales',96,'Facturas Definitivas',100,'Asientos Masivos','') descripcion, 
           FECHA,HORA,COD_USUARIO,reversado,
           decode(x.tipo,'A','Automatico','I','Ajuste Informe','M','Manuales',x.tipo) tipo,
           sum(mto_asiento) monto_asiento, sum(mto_factura) monto_factura, sum(mto_asiento) - sum(mto_factura) diferencia
    from
    (
      -- asientos 
      select decode(a.cod_rubro,'240102440100199','10%','240102440100299','5%','') IVA, 'A' tipo,
               b.COD_MOD_PADRE,b.COD_MAD_PADRE,0 V_AUX,b.FECHA,b.HORA,b.COD_USUARIO,b.reversado, SUM(abs(decode(b.COD_MONEDA,'GS',b.MONTO,decode(b.MTO_EQU_LOCAL,0,round(b.MONTO*b.COTIZACION),b.MTO_EQU_LOCAL)))) mto_asiento, 0 mto_factura
            from cb_asi_automaticos_det a
      join ge_movimientos_ant b on a.fecha=b.FECHA and a.ref_movimiento=b.NRO_DOCUMENTO4 
       where a.fecha = v_fec_sist
             and a.cod_rubro in ('240102440100199','240102440100299')
             and a.tip_movimiento = 'C'
             and a.referencia is null
      group by decode(a.cod_rubro,'240102440100199','10%','240102440100299','5%',''),b.COD_MOD_PADRE,b.COD_MAD_PADRE,b.FECHA,b.HORA,b.COD_USUARIO,b.reversado
    union all
          -- informe financiero
          select decode(d.cod_rubro,'240102440100199','10%','240102440100299','5%','') IVA, 'M' tipo,
                 b.COD_MOD_PADRE,b.COD_MAD_PADRE,99 V_AUX,b.FECHA,b.HORA,b.COD_USUARIO,b.reversado,(SUM(abs(decode(b.COD_MONEDA,'GS',b.MONTO,decode(b.MTO_EQU_LOCAL,0,round(b.MONTO*b.COTIZACION),b.MTO_EQU_LOCAL))))) mto_asiento, 0 mto_factura
         from cb_asi_automaticos_det d
              join ge_movimientos_ant b on d.fecha=b.FECHA and d.ref_movimiento=b.NRO_DOCUMENTO4 
        where d.cod_rubro in ('240102440100199','240102440100299')
          and d.referencia     is not null
          --and d.mto_mon_local <> 0
          and d.fecha          = v_fec_sist--p_fecha 
          and d.tip_movimiento = 'C'
          group by decode(d.cod_rubro,'240102440100199','10%','240102440100299','5%',''),b.COD_MOD_PADRE,b.COD_MAD_PADRE,b.FECHA,b.HORA,b.COD_USUARIO,b.reversado
    union all
          -- se resta reversados del d¿a
             select decode(a.cod_rubro,'240102440100199','10%','240102440100299','5%','') IVA, 'I' tipo,
             g.COD_MOD_PADRE, g.COD_MAD_PADRE, 98 V_AUX,g.FECHA,g.HORA,g.COD_USUARIO,g.reversado, sum(decode(g.cod_moneda, 'GS', nvl(g.monto, 0),decode(g.MTO_EQU_LOCAL,0,round(g.MONTO*g.COTIZACION),g.MTO_EQU_LOCAL))) mto_asiento, 0 mto_factura
         from ge_movimientos_ant g, cb_asi_automaticos_det a
        where g.nro_documento4 = a.ref_movimiento
          and g.fecha = a.fecha
          and a.cod_rubro in ('240102440100199','240102440100299')
          and g.val_tasa    = 10
          and g.monto       < 0
          and g.fec_valor   = g.fecha
          and g.fecha       = v_fec_sist
          group by decode(a.cod_rubro,'240102440100199','10%','240102440100299','5%',''), g.COD_MOD_PADRE, g.COD_MAD_PADRE,g.FECHA,g.HORA,g.COD_USUARIO,g.reversado
    union all
         (-- asientos masivos
        select decode(a.cod_rubro,'240102440100199','10%','240102440100299','5%','') IVA, 'M' tipo,
        b.COD_MODULO COD_MOD_PADRE, b.COD_MODALIDAD COD_MAD_PADRE,100 V_AUX, a.FECHA,'',a.usu_insercion,'N' Reversado, SUM(a.mto_mon_local) mto_asiento, 0 mto_factura
        from CB_ASIENTOS_DET a 
             join CB_ASIENTOS b on a.fecha=b.FECHA and a.cod_oficina=b.COD_OFICINA and a.nro_asiento=b.nro_asiento
        where a.fecha= v_fec_sist
        and a.cod_rubro IN ('240102440100199','240102440100299')
        and a.ref_movimiento is null
        and a.tip_movimiento='C'
        group by decode(a.cod_rubro,'240102440100199','10%','240102440100299','5%',''), a.FECHA,b.COD_MODULO, b.COD_MODALIDAD, a.usu_insercion
      union
        select decode(a.cod_rubro,'240102440100199','10%','240102440100299','5%','') IVA, 'M' tipo,
        b.COD_MODULO COD_MOD_PADRE, b.COD_MODALIDAD COD_MAD_PADRE,100 V_AUX, a.FECHA,'',a.usu_insercion,'N' Reversado, SUM(a.mto_mon_local) mto_asiento, 0 mto_factura
        from CB_ASIENTOS_DET_his a 
             join CB_ASIENTOS_his b on a.fecha=b.FECHA and a.cod_oficina=b.COD_OFICINA and a.nro_asiento=b.nro_asiento
        where a.fecha= v_fec_sist
        and a.cod_rubro IN ('240102440100199','240102440100299')
        and a.ref_movimiento is null
        and a.tip_movimiento='C'
        group by decode(a.cod_rubro,'240102440100199','10%','240102440100299','5%',''), a.FECHA,b.COD_MODULO, b.COD_MODALIDAD, a.usu_insercion
      )
    union all
      -- facturas definitivas
      select decode(a.IMPUESTO_10_GS,0,'5%','10%') IVA, 'A' tipo,
      b.COD_MOD_PADRE,b.COD_MAD_PADRE,0 V_AUX,b.FECHA,b.HORA,b.COD_USUARIO,b.reversado, 0 mto_asiento, SUM(decode(nvl(a.IMPUESTO_10_GS,0),0,nvl(a.IMPUESTO_5_GS,0),nvl(a.IMPUESTO_10_GS,0))) mto_factura
            from cb_lib_ventas_det a
      join cb_lib_ventas c on c.nro_factura = a.nro_factura and c.nro_timbrado = a.nro_timbrado
      join ge_movimientos_ant b on a.fecha=b.FECHA and a.hora=b.HORA and a.cod_usuario=b.COD_USUARIO and a.nro_secuencia=b.NRO_SECUENCIA 
           and b.MONTO > 0
       where a.fecha = v_fec_sist --p_fecha
       and c.tip_comprobante = 'F'
       group by decode(a.IMPUESTO_10_GS,0,'5%','10%'),b.COD_MOD_PADRE,b.COD_MAD_PADRE,b.FECHA,b.HORA,b.COD_USUARIO,b.reversado

    union all
          -- facturas definitivas manuales
      select decode(a.IMPUESTO_10_GS,0,'5%','10%') IVA, 'M' tipo,
      nvl(b.COD_MOD_PADRE,a.COD_MOD_PADRE),nvl(b.COD_MAD_PADRE,a.COD_MAD_PADRE), 96 V_AUX,b.FECHA,b.HORA,b.COD_USUARIO,b.reversado, 0 mto_asiento, SUM(decode(nvl(a.IMPUESTO_10_GS,0),0,nvl(a.IMPUESTO_5_GS,0),nvl(a.IMPUESTO_10_GS,0))) mto_factura
            from cb_lib_ventas_det a
      join cb_lib_ventas c on c.nro_factura = a.nro_factura and c.nro_timbrado = a.nro_timbrado
      left join ge_movimientos_ant b on a.fecha=b.FECHA and a.hora=b.HORA and a.cod_usuario=b.COD_USUARIO and a.nro_secuencia=b.NRO_SECUENCIA 
           and b.MONTO > 0
       where a.fecha = v_fec_sist --p_fecha
       and c.tip_comprobante = 'F'
       and b.FECHA is null
       group by decode(a.IMPUESTO_10_GS,0,'5%','10%'),nvl(b.COD_MOD_PADRE,a.COD_MOD_PADRE),nvl(b.COD_MAD_PADRE,a.COD_MAD_PADRE),b.FECHA,b.HORA,b.COD_USUARIO,b.reversado

    union all
      -- facturas temporales
      select decode(a.IMPUESTO_10_GS,0,'5%','10%') IVA, 'A' tipo,
             b.COD_MOD_PADRE,b.COD_MAD_PADRE, 0 V_AUX,b.FECHA,b.HORA,b.COD_USUARIO,b.reversado, 0 mto_asiento, SUM(decode(nvl(a.IMPUESTO_10_GS,0),0,nvl(a.IMPUESTO_5_GS,0),nvl(a.IMPUESTO_10_GS,0))) mto_factura
            from cb_lib_ventas_det_tmp a
      join ge_movimientos_ant b on a.fecha=b.FECHA and a.hora=b.HORA and a.cod_usuario=b.COD_USUARIO and a.nro_secuencia=b.NRO_SECUENCIA
           and b.MONTO > 0
       where a.fecha = v_fec_sist --p_fecha
       and a.reversado='N'
       group by decode(a.IMPUESTO_10_GS,0,'5%','10%'), b.COD_MOD_PADRE,b.COD_MAD_PADRE,b.FECHA,b.HORA,b.COD_USUARIO ,b.reversado
    union all
      --- facturas temporales manuales
      select decode(a.IMPUESTO_10_GS,0,'5%','10%') IVA, 'M' tipo,
             nvl(b.COD_MOD_PADRE,a.cod_mod_padre),nvl(b.COD_MAD_PADRE,a.cod_mad_padre), 95 V_AUX,b.FECHA,b.HORA,b.COD_USUARIO,b.reversado, 0 mto_asiento, SUM(decode(nvl(a.IMPUESTO_10_GS,0),0,nvl(a.IMPUESTO_5_GS,0),nvl(a.IMPUESTO_10_GS,0))) mto_factura
            from cb_lib_ventas_det_tmp a
      left join ge_movimientos_ant b on a.fecha=b.FECHA and a.hora=b.HORA and a.cod_usuario=b.COD_USUARIO and a.nro_secuencia=b.NRO_SECUENCIA
       where a.fecha = v_fec_sist --p_fecha
       and a.reversado='N'
       and b.FECHA is null
        group by decode(a.IMPUESTO_10_GS,0,'5%','10%'),nvl(b.COD_MOD_PADRE,a.cod_mod_padre),nvl(b.COD_MAD_PADRE,a.cod_mad_padre),b.FECHA,b.HORA,b.COD_USUARIO,b.reversado
    ) x
    left join ge_modalidades c on c.cod_modalidad=x.COD_MAD_PADRE
    group by IVA,COD_MOD_PADRE, COD_MAD_PADRE,x.tipo, V_AUX,c.descripcion,FECHA,HORA,COD_USUARIO,reversado
    order by IVA desc,tipo,COD_MOD_PADRE,COD_MAD_PADRE;
    

    -- Inserta Debitos
    insert into cb_inf_ctr_iva_tmp  (tip_movimiento,iva,cod_mod_padre,cod_mad_padre,descripcion,fecha,hora,
                cod_usuario,reversado,tipo,mto_asiento,mto_factura,diferencia)
    select 'Debito' TIP_MOVIMIENTO,IVA, COD_MOD_PADRE, COD_MAD_PADRE,
           decode(nvl(c.descripcion,''),'','',decode(V_AUX,0,c.descripcion,c.descripcion || ' - ')) || 
           decode(V_AUX,'99','Informe Financiero','98','Reversiones del d¿a','97','Facturas eliminadas por Rev.del mes',95,'Facturas Temporales',96,'Facturas Definitivas','') descripcion, 
           FECHA,HORA,COD_USUARIO,reversado,
           decode(x.tipo,'A','Automatico','I','Ajuste Informe','M','Manuales',x.tipo) tipo,
           sum(mto_asiento) mto_asiento, sum(mto_factura) mto_factura, sum(mto_asiento) - sum(mto_factura) diferencia
    from
    (
      -- asientos 
      select decode(a.cod_rubro,'240102440100199','10%','240102440100299','5%','') IVA, 'A' tipo, 
               b.COD_MOD_PADRE,b.COD_MAD_PADRE, 0 V_AUX,b.FECHA,b.HORA,b.COD_USUARIO,b.reversado, SUM(abs(decode(b.COD_MONEDA,'GS',abs(b.MONTO),abs(decode(b.MTO_EQU_LOCAL,0,round(b.MONTO*b.COTIZACION),b.MTO_EQU_LOCAL))))) mto_asiento, 0 mto_factura
            from cb_asi_automaticos_det a
      join ge_movimientos_ant b on a.fecha=b.FECHA and a.ref_movimiento=b.NRO_DOCUMENTO4
       where a.fecha = v_fec_sist --p_fecha
             and a.cod_rubro in ('240102440100199','240102440100299')
             and a.tip_movimiento = 'D'
             and a.referencia is null
      group by decode(a.cod_rubro,'240102440100199','10%','240102440100299','5%',''),b.COD_MOD_PADRE,b.COD_MAD_PADRE,b.FECHA,b.HORA,b.COD_USUARIO,b.reversado
    union all
          -- informe financiero
          select decode(d.cod_rubro,'240102440100199','10%','240102440100299','5%','') IVA, 'M' tipo,
                 b.COD_MOD_PADRE,b.COD_MAD_PADRE, 99 V_AUX,b.FECHA,b.HORA,b.COD_USUARIO,b.reversado,(SUM(abs(decode(b.COD_MONEDA,'GS',b.MONTO,decode(b.MTO_EQU_LOCAL,0,round(b.MONTO*b.COTIZACION),b.MTO_EQU_LOCAL))))) mto_asiento, 0 mto_factura
         from cb_asi_automaticos_det d
              join ge_movimientos_ant b on d.fecha=b.FECHA and d.ref_movimiento=b.NRO_DOCUMENTO4
        where d.cod_rubro in ('240102440100199','240102440100299')
          and d.referencia is not null
          --and d.mto_mon_local <> 0
          and d.fecha          = v_fec_sist--p_fecha 
          and d.tip_movimiento = 'D'
          group by decode(d.cod_rubro,'240102440100199','10%','240102440100299','5%',''),b.COD_MOD_PADRE,b.COD_MAD_PADRE,b.FECHA,b.HORA,b.COD_USUARIO,b.reversado
    union all
      -- se resta reversados del d¿a
             select decode(a.cod_rubro,'240102440100199','10%','240102440100299','5%','') IVA, 'I' tipo,
             g.COD_MOD_PADRE, g.COD_MAD_PADRE, 98 V_AUX,g.FECHA,g.HORA,g.COD_USUARIO,g.reversado, sum(decode(g.cod_moneda, 'GS', nvl(g.monto, 0), decode(g.MTO_EQU_LOCAL,0,round(g.MONTO*g.COTIZACION),g.MTO_EQU_LOCAL))) mto_asiento, 0 mto_factura
         from ge_movimientos_ant g, cb_asi_automaticos_det a
        where g.nro_documento4 = a.ref_movimiento
          and g.fecha = a.fecha
          and a.cod_rubro in ('240102440100199','240102440100299')
          and g.val_tasa    = 10
          and g.monto       < 0
          and g.fec_valor   = g.fecha
          and g.fecha       = v_fec_sist
          group by decode(a.cod_rubro,'240102440100199','10%','240102440100299','5%',''), g.COD_MOD_PADRE, g.COD_MAD_PADRE,g.FECHA,g.HORA,g.COD_USUARIO,g.reversado
    union all
       (-- asientos masivos
      select decode(a.cod_rubro,'240102440100199','10%','240102440100299','5%','') IVA, 'M' tipo,
      b.COD_MODULO COD_MOD_PADRE, b.COD_MODALIDAD COD_MAD_PADRE,100 V_AUX, a.FECHA,'',a.usu_insercion,'N' reversado, SUM(a.mto_mon_local) mto_asiento, 0 mto_factura
      from CB_ASIENTOS_DET a 
           join CB_ASIENTOS b on a.fecha=b.FECHA and a.cod_oficina=b.COD_OFICINA and a.nro_asiento=b.nro_asiento
      where a.fecha= v_fec_sist
      and a.cod_rubro IN ('240102440100199','240102440100299')
      and a.ref_movimiento is null
      and a.tip_movimiento='D'
      group by decode(a.cod_rubro,'240102440100199','10%','240102440100299','5%',''), a.FECHA,b.COD_MODULO, b.COD_MODALIDAD, a.usu_insercion
    union
      select decode(a.cod_rubro,'240102440100199','10%','240102440100299','5%','') IVA, 'M' tipo,
      b.COD_MODULO COD_MOD_PADRE, b.COD_MODALIDAD COD_MAD_PADRE,100 V_AUX, a.FECHA,'',a.usu_insercion,'N' reversado, SUM(a.mto_mon_local) mto_asiento, 0 mto_factura
      from CB_ASIENTOS_DET_his a 
           join CB_ASIENTOS_his b on a.fecha=b.FECHA and a.cod_oficina=b.COD_OFICINA and a.nro_asiento=b.nro_asiento
      where a.fecha= v_fec_sist
      and a.cod_rubro IN ('240102440100199','240102440100299')
      and a.ref_movimiento is null
      and a.tip_movimiento='D'
      group by decode(a.cod_rubro,'240102440100199','10%','240102440100299','5%',''), a.FECHA,b.COD_MODULO, b.COD_MODALIDAD, a.usu_insercion
      )
    union all
      -- facturas definitivas
      select decode(a.IMPUESTO_10_GS,0,'5%','10%') IVA, 'A' tipo, 
      b.COD_MOD_PADRE,b.COD_MAD_PADRE,0 V_AUX,b.FECHA,b.HORA,b.COD_USUARIO,b.reversado, 0 mto_asiento, SUM(decode(nvl(a.IMPUESTO_10_GS,0),0,nvl(a.IMPUESTO_5_GS,0),nvl(a.IMPUESTO_10_GS,0))) mto_factura
            from cb_lib_ventas_det a
                 join CB_LIB_VENTAS c on a.nro_factura=c.nro_factura and a.nro_timbrado=c.nro_timbrado
      join ge_movimientos_ant b on a.fecha=b.FECHA and a.hora=b.HORA and a.cod_usuario=b.COD_USUARIO and a.nro_secuencia=b.NRO_SECUENCIA 
           
       where a.fecha = v_fec_sist --p_fecha
             and c.tip_comprobante='N'
       group by decode(a.IMPUESTO_10_GS,0,'5%','10%'),b.COD_MOD_PADRE,b.COD_MAD_PADRE,b.FECHA,b.HORA,b.COD_USUARIO,b.reversado
    union all
      -- facturas definitivas manuales
      select decode(a.IMPUESTO_10_GS,0,'5%','10%') IVA, 'M' tipo,
      nvl(b.COD_MOD_PADRE,a.COD_MOD_PADRE),nvl(b.COD_MAD_PADRE,a.COD_MAD_PADRE),95 V_AUX,b.FECHA,b.HORA,b.COD_USUARIO,b.reversado, 0 mto_asiento, SUM(decode(nvl(a.IMPUESTO_10_GS,0),0,nvl(a.IMPUESTO_5_GS,0),nvl(a.IMPUESTO_10_GS,0))) mto_factura
            from cb_lib_ventas_det a
      join cb_lib_ventas c on c.nro_factura = a.nro_factura and c.nro_timbrado = a.nro_timbrado
      left join ge_movimientos_ant b on a.fecha=b.FECHA and a.hora=b.HORA and a.cod_usuario=b.COD_USUARIO and a.nro_secuencia=b.NRO_SECUENCIA       
       where a.fecha = v_fec_sist --p_fecha
       and c.tip_comprobante = 'N'
       and b.FECHA is null
       group by decode(a.IMPUESTO_10_GS,0,'5%','10%'),nvl(b.COD_MOD_PADRE,a.COD_MOD_PADRE),nvl(b.COD_MAD_PADRE,a.COD_MAD_PADRE),b.FECHA,b.HORA,b.COD_USUARIO,b.reversado
    union all
      -- facturas temporales
      select decode(a.IMPUESTO_10_GS,0,'5%','10%') IVA, 'A' tipo,
             nvl(b.COD_MOD_PADRE,a.COD_MOD_PADRE),nvl(b.COD_MAD_PADRE,a.COD_MAD_PADRE),0 V_AUX,b.FECHA,b.HORA,b.COD_USUARIO,b.reversado, 0 mto_asiento, SUM(decode(nvl(a.IMPUESTO_10_GS,0),0,nvl(a.IMPUESTO_5_GS,0),nvl(a.IMPUESTO_10_GS,0))) mto_factura
            from cb_lib_ventas_det_tmp a
      join ge_movimientos_ant b on a.fecha=b.FECHA and a.hora=b.HORA and a.cod_usuario=b.COD_USUARIO and a.nro_secuencia=b.NRO_SECUENCIA
       where a.fecha = v_fec_sist --p_fecha
             and a.reversado='S'
       group by decode(a.IMPUESTO_10_GS,0,'5%','10%'),nvl(b.COD_MOD_PADRE,a.COD_MOD_PADRE),nvl(b.COD_MAD_PADRE,a.COD_MAD_PADRE),b.FECHA,b.HORA,b.COD_USUARIO,b.reversado
    union all
       --- facturas temporales manuales
      select decode(a.IMPUESTO_10_GS,0,'5%','10%') IVA, 'M' tipo, 
             nvl(b.COD_MOD_PADRE,a.cod_mod_padre),nvl(b.COD_MAD_PADRE,a.cod_mod_padre), 95 V_AUX,b.FECHA,b.HORA,b.COD_USUARIO,b.reversado, 0 mto_asiento, SUM(decode(nvl(a.IMPUESTO_10_GS,0),0,nvl(a.IMPUESTO_5_GS,0),nvl(a.IMPUESTO_10_GS,0))) mto_factura
            from cb_lib_ventas_det_tmp a
      left join ge_movimientos_ant b on a.fecha=b.FECHA and a.hora=b.HORA and a.cod_usuario=b.COD_USUARIO and a.nro_secuencia=b.NRO_SECUENCIA
       where a.fecha = v_fec_sist --p_fecha
       and a.reversado='S'
       and b.FECHA is null
        group by decode(a.IMPUESTO_10_GS,0,'5%','10%'),nvl(b.COD_MOD_PADRE,a.cod_mod_padre),nvl(b.COD_MAD_PADRE,a.cod_mod_padre),b.FECHA,b.HORA,b.COD_USUARIO,b.reversado
       
    union all
        -- facturas borradas en lugar de hacer NC
          select decode(c.IMPUESTO_10_GS,0,'5%','10%') IVA, 'A' tipo, 
                 a.COD_MOD_PADRE,a.COD_MAD_PADRE,97 V_AUX,b.FECHA,b.HORA,b.COD_USUARIO,b.reversado, 0 mto_asiento, SUM(decode(nvl(c.IMPUESTO_10_GS,0),0,nvl(c.IMPUESTO_5_GS,0),nvl(c.IMPUESTO_10_GS,0))) mto_factura 
                 from ge_movimientos_ant a
             join gv_movimientos b on a.FEC_VALOR=b.FECHA and a.HOR_REVERSION=b.HORA and a.COD_USU_REVERSION=b.COD_USUARIO 
                  and a.NRO_SECUENCIA=b.NRO_SECUENCIA 
             join cb_obs_lib_ventas_det_tmp c on c.fecha=b.FECHA and c.hora=b.HORA and c.COD_USUARIO=b.COD_USUARIO and c.nro_secuencia=b.NRO_SECUENCIA
        where a.FECHA = v_fec_sist
        and b.FECHA between '01'||to_char(v_fec_sist,'/mm/yyyy') and v_fec_sist-1
        and b.tipo='H' 
        group by decode(c.IMPUESTO_10_GS,0,'5%','10%'), a.COD_MOD_PADRE,a.COD_MAD_PADRE ,b.FECHA,b.HORA,b.COD_USUARIO,b.reversado
    ) x
    left join ge_modalidades c on c.cod_modalidad=x.COD_MAD_PADRE
    group by IVA,COD_MOD_PADRE, COD_MAD_PADRE,x.tipo, V_AUX, descripcion,FECHA,HORA,COD_USUARIO,reversado
    order by IVA desc,x.tipo,COD_MOD_PADRE,COD_MAD_PADRE;
    
    -- se generan y envian los informes adicionales
    prb_con_iva_cua_modalidad;
    prb_con_iva_cua_movimientos;
    prb_con_iva_det_movimientos;

END prb_con_iva_complement;
------------------------prb_con_iva_complementarios----------------------------------   
END PAG_REP;
/

