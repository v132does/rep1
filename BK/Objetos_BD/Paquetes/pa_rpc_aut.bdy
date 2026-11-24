CREATE OR REPLACE PACKAGE BODY IT.PA_RPC_AUT IS

-------------------------------------------------------------------------------------------------------------------------------------
--
-- Funcion para obtener valores de GE_PAR_RA
FUNCTION fu_obt_valor_par
    (
    v_servicio IN varchar2 DEFAULT 'ALL',
    v_tabla    IN varchar2,
    v_campo    IN varchar2
    )
    RETURN  varchar2 IS

  -- Proposito: Retorna valor de un campo específico de la tabla de GE_PAR_RA
  -- Precondición:  los parámetros no deben ser nulos
  -- Poscondicion: devuelve un valor 'ERROR' en caso de errores
  /* cambios:
          20120711:FJM: cambie el v_valor  de varchar2(500) a varchar2(4000)
          20120829:FJM: pr_gen_mov_riegos: se agrego un chr(39) para que agregue
                        comillas simples a la ultima columna del reporte
  */
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

-------------------------------------------------------------------------------------------------------------------------------------
-- Devengado Diario
PROCEDURE pr_dev_dia
IS
CURSOR cu_dev_dia(p_fecha DATE, p_mes VARCHAR2) IS
    select c.cod_persona, e.nom_completo, p.nro_cuenta, s.cod_moneda, s.cod_oficina, s.val_tasa, s.dev_acumulado, s.dev_no_cobrado,
    s.dev_suspenso, s.val_int_devengar, s.sal_capital, s.sal_interes, s.sal_int_adelantado, s.estado, s.fec_ult_devengado,
    s.tip_interes, p.cod_modalidad, tot_cap_acumulado, tot_int_acumulado, can_dia_acumulado,
    d.capital sal_cap_cuota, d.fec_inicio, d.fecha, d.nro_cuota,
    dev_nco_dia_01, dev_sus_dia_01, dev_nco_dia_02, dev_sus_dia_02, dev_nco_dia_03, dev_sus_dia_03, dev_nco_dia_04,
    dev_sus_dia_04, dev_nco_dia_05, dev_sus_dia_05, dev_nco_dia_06, dev_sus_dia_06, dev_nco_dia_07, dev_sus_dia_07,
    dev_nco_dia_08, dev_sus_dia_08, dev_nco_dia_09, dev_sus_dia_09, dev_nco_dia_10, dev_sus_dia_10, dev_nco_dia_11,
    dev_sus_dia_11, dev_nco_dia_12, dev_sus_dia_12, dev_nco_dia_13, dev_sus_dia_13, dev_nco_dia_14, dev_sus_dia_14,
    dev_nco_dia_15, dev_sus_dia_15, dev_nco_dia_16, dev_sus_dia_16, dev_nco_dia_17, dev_sus_dia_17, dev_nco_dia_18,
    dev_sus_dia_18, dev_nco_dia_19, dev_sus_dia_19, dev_nco_dia_20, dev_sus_dia_20, dev_nco_dia_21, dev_sus_dia_21,
    dev_nco_dia_22, dev_sus_dia_22, dev_nco_dia_23, dev_sus_dia_23, dev_nco_dia_24, dev_sus_dia_24, dev_nco_dia_25,
    dev_sus_dia_25, dev_nco_dia_26, dev_sus_dia_26, dev_nco_dia_27, dev_sus_dia_27, dev_nco_dia_28, dev_sus_dia_28,
    dev_nco_dia_29, dev_sus_dia_29, dev_nco_dia_30, dev_sus_dia_30, dev_nco_dia_31, dev_sus_dia_31
    from pr_sal_mensuales p, ge_cta_clientes c, ba_personas e,pr_cta_prestamos s, ge_clientes t,
       (select nro_cuenta, nro_cuota, fecha, capital, fec_inicio
      from pr_devengados e
      where fec_ult_devengado = p_fecha
      and exists(select 1 from pr_cta_prestamos o
            where e.nro_cuenta = o.nro_cuenta
            and o.tip_interes = 'V')) d
    where mes = p_mes
    and c.nro_cuenta = p.nro_cuenta
    and c.relacion='P'
    and c.cod_persona = e.cod_persona
    and s.nro_cuenta=p.nro_cuenta
    and d.nro_cuenta(+)=p.nro_cuenta
    and c.cod_persona = t.cod_persona;


  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'dev_dia'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_fec_sist         DATE;
  v_fecha            VARCHAR2(8);
  v_mes              VARCHAR2(2);

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
  select pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1)
  into v_fec_sist
  from dual;

  v_fecha := to_char(v_fec_sist,'DDMMYYYY');
  v_mes := to_char(v_fec_sist,'MM');

-- Abrir archivo
v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'.txt','W',32767);

-- Colocar el titulo a los campos
v_linetit := 'COD_PERSONA'||CHR(9)||'NOM_COMPLETO'||CHR(9)||'NRO_CUENTA'||CHR(9)||'COD_MONEDA'||CHR(9)||'COD_OFICINA'||CHR(9)||'VAL_TASA'||CHR(9)||'DEV_ACUMULADO'||CHR(9)||'DEV_NO_COBRADO'||CHR(9)||
    'DEV_SUSPENSO'||CHR(9)||'VAL_INT_DEVENGAR'||CHR(9)||'SAL_CAPITAL'||CHR(9)||'SAL_INTERES'||CHR(9)||'SAL_INT_ADELANTADO'||CHR(9)||'ESTADO'||CHR(9)||'FEC_ULT_DEVENGADO'||CHR(9)||
    'TIP_INTERES'||CHR(9)||'COD_MODALIDAD'||CHR(9)||'TOT_CAP_ACUMULADO'||CHR(9)||'TOT_INT_ACUMULADO'||CHR(9)||'CAN_DIA_ACUMULADO'||CHR(9)||
    'SAL_CAP_CUOTA'||CHR(9)||'FEC_INICIO'||CHR(9)||'FECHA'||CHR(9)||'NRO_CUOTA'||CHR(9)||
    'DEV_NCO_DIA_01'||CHR(9)||'DEV_SUS_DIA_01'||CHR(9)||'DEV_NCO_DIA_02'||CHR(9)||'DEV_SUS_DIA_02'||CHR(9)||'DEV_NCO_DIA_03'||CHR(9)||'DEV_SUS_DIA_03'||CHR(9)||'DEV_NCO_DIA_04'||CHR(9)||
    'DEV_SUS_DIA_04'||CHR(9)||'DEV_NCO_DIA_05'||CHR(9)||'DEV_SUS_DIA_05'||CHR(9)||'DEV_NCO_DIA_06'||CHR(9)||'DEV_SUS_DIA_06'||CHR(9)||'DEV_NCO_DIA_07'||CHR(9)||'DEV_SUS_DIA_07'||CHR(9)||
    'DEV_NCO_DIA_08'||CHR(9)||'DEV_SUS_DIA_08'||CHR(9)||'DEV_NCO_DIA_09'||CHR(9)||'DEV_SUS_DIA_09'||CHR(9)||'DEV_NCO_DIA_10'||CHR(9)||'DEV_SUS_DIA_10'||CHR(9)||'DEV_NCO_DIA_11'||CHR(9)||
    'DEV_SUS_DIA_11'||CHR(9)||'DEV_NCO_DIA_12'||CHR(9)||'DEV_SUS_DIA_12'||CHR(9)||'DEV_NCO_DIA_13'||CHR(9)||'DEV_SUS_DIA_13'||CHR(9)||'DEV_NCO_DIA_14'||CHR(9)||'DEV_SUS_DIA_14'||CHR(9)||
    'DEV_NCO_DIA_15'||CHR(9)||'DEV_SUS_DIA_15'||CHR(9)||'DEV_NCO_DIA_16'||CHR(9)||'DEV_SUS_DIA_16'||CHR(9)||'DEV_NCO_DIA_17'||CHR(9)||'DEV_SUS_DIA_17'||CHR(9)||'DEV_NCO_DIA_18'||CHR(9)||
    'DEV_SUS_DIA_18'||CHR(9)||'DEV_NCO_DIA_19'||CHR(9)||'DEV_SUS_DIA_19'||CHR(9)||'DEV_NCO_DIA_20'||CHR(9)||'DEV_SUS_DIA_20'||CHR(9)||'DEV_NCO_DIA_21'||CHR(9)||'DEV_SUS_DIA_21'||CHR(9)||
    'DEV_NCO_DIA_22'||CHR(9)||'DEV_SUS_DIA_22'||CHR(9)||'DEV_NCO_DIA_23'||CHR(9)||'DEV_SUS_DIA_23'||CHR(9)||'DEV_NCO_DIA_24'||CHR(9)||'DEV_SUS_DIA_24'||CHR(9)||'DEV_NCO_DIA_25'||CHR(9)||
    'DEV_SUS_DIA_25'||CHR(9)||'DEV_NCO_DIA_26'||CHR(9)||'DEV_SUS_DIA_26'||CHR(9)||'DEV_NCO_DIA_27'||CHR(9)||'DEV_SUS_DIA_27'||CHR(9)||'DEV_NCO_DIA_28'||CHR(9)||'DEV_SUS_DIA_28'||CHR(9)||
    'DEV_NCO_DIA_29'||CHR(9)||'DEV_SUS_DIA_29'||CHR(9)||'DEV_NCO_DIA_30'||CHR(9)||'DEV_SUS_DIA_30'||CHR(9)||'DEV_NCO_DIA_31'||CHR(9)||'DEV_SUS_DIA_31';

utl_file.put_line(v_file,v_linetit);

-- Definir una linea en blanco para separar los datos del titulo de los campos
v_linetit := ' ';
utl_file.put_line(v_file,v_linetit);

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN cu_dev_dia(v_fec_sist, v_mes) LOOP

    --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
  v_line := to_char(rec.cod_persona)||chr(9)||to_char(rec.nom_completo)||chr(9)||to_char(rec.nro_cuenta)||chr(9)||to_char(rec.cod_moneda)||chr(9)||to_char(rec.cod_oficina)||chr(9)||to_char(rec.val_tasa)||chr(9)||to_char(rec.dev_acumulado,'999999999999D00')||chr(9)||to_char(rec.dev_no_cobrado,'999999999999D00')||chr(9)||
    to_char(rec.dev_suspenso,'999999999999D00')||chr(9)||to_char(rec.val_int_devengar,'999999999999D00')||chr(9)||to_char(rec.sal_capital,'999999999999D00')||chr(9)||to_char(rec.sal_interes,'999999999999D00')||chr(9)||to_char(rec.sal_int_adelantado,'999999999999D00')||chr(9)||to_char(rec.estado)||chr(9)||to_char(rec.fec_ult_devengado)||chr(9)||
    to_char(rec.tip_interes)||chr(9)||to_char(rec.cod_modalidad)||chr(9)||to_char(rec.tot_cap_acumulado,'999999999999D00')||chr(9)||to_char(rec.tot_int_acumulado,'999999999999D00')||chr(9)||to_char(rec.can_dia_acumulado)||chr(9)||
    to_char(rec.sal_cap_cuota)||chr(9)||to_char(rec.fec_inicio)||chr(9)||to_char(rec.fecha)||chr(9)||to_char(rec.nro_cuota)||chr(9)||
    to_char(rec.dev_nco_dia_01)||chr(9)||to_char(rec.dev_sus_dia_01)||chr(9)||to_char(rec.dev_nco_dia_02)||chr(9)||to_char(rec.dev_sus_dia_02)||chr(9)||to_char(rec.dev_nco_dia_03)||chr(9)||to_char(rec.dev_sus_dia_03)||chr(9)||to_char(rec.dev_nco_dia_04)||chr(9)||
    to_char(rec.dev_sus_dia_04)||chr(9)||to_char(rec.dev_nco_dia_05)||chr(9)||to_char(rec.dev_sus_dia_05)||chr(9)||to_char(rec.dev_nco_dia_06)||chr(9)||to_char(rec.dev_sus_dia_06)||chr(9)||to_char(rec.dev_nco_dia_07)||chr(9)||to_char(rec.dev_sus_dia_07)||chr(9)||
    to_char(rec.dev_nco_dia_08)||chr(9)||to_char(rec.dev_sus_dia_08)||chr(9)||to_char(rec.dev_nco_dia_09)||chr(9)||to_char(rec.dev_sus_dia_09)||chr(9)||to_char(rec.dev_nco_dia_10)||chr(9)||to_char(rec.dev_sus_dia_10)||chr(9)||to_char(rec.dev_nco_dia_11)||chr(9)||
    to_char(rec.dev_sus_dia_11)||chr(9)||to_char(rec.dev_nco_dia_12)||chr(9)||to_char(rec.dev_sus_dia_12)||chr(9)||to_char(rec.dev_nco_dia_13)||chr(9)||to_char(rec.dev_sus_dia_13)||chr(9)||to_char(rec.dev_nco_dia_14)||chr(9)||to_char(rec.dev_sus_dia_14)||chr(9)||
    to_char(rec.dev_nco_dia_15)||chr(9)||to_char(rec.dev_sus_dia_15)||chr(9)||to_char(rec.dev_nco_dia_16)||chr(9)||to_char(rec.dev_sus_dia_16)||chr(9)||to_char(rec.dev_nco_dia_17)||chr(9)||to_char(rec.dev_sus_dia_17)||chr(9)||to_char(rec.dev_nco_dia_18)||chr(9)||
    to_char(rec.dev_sus_dia_18)||chr(9)||to_char(rec.dev_nco_dia_19)||chr(9)||to_char(rec.dev_sus_dia_19)||chr(9)||to_char(rec.dev_nco_dia_20)||chr(9)||to_char(rec.dev_sus_dia_20)||chr(9)||to_char(rec.dev_nco_dia_21)||chr(9)||to_char(rec.dev_sus_dia_21)||chr(9)||
    to_char(rec.dev_nco_dia_22)||chr(9)||to_char(rec.dev_sus_dia_22)||chr(9)||to_char(rec.dev_nco_dia_23)||chr(9)||to_char(rec.dev_sus_dia_23)||chr(9)||to_char(rec.dev_nco_dia_24)||chr(9)||to_char(rec.dev_sus_dia_24)||chr(9)||to_char(rec.dev_nco_dia_25)||chr(9)||
    to_char(rec.dev_sus_dia_25)||chr(9)||to_char(rec.dev_nco_dia_26)||chr(9)||to_char(rec.dev_sus_dia_26)||chr(9)||to_char(rec.dev_nco_dia_27)||chr(9)||to_char(rec.dev_sus_dia_27)||chr(9)||to_char(rec.dev_nco_dia_28)||chr(9)||to_char(rec.dev_sus_dia_28)||chr(9)||
    to_char(rec.dev_nco_dia_29)||chr(9)||to_char(rec.dev_sus_dia_29)||chr(9)||to_char(rec.dev_nco_dia_30)||chr(9)||to_char(rec.dev_sus_dia_30)||chr(9)||to_char(rec.dev_nco_dia_31)||chr(9)||to_char(rec.dev_sus_dia_31);

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

   EXIT WHEN cu_dev_dia%NOTFOUND;
END LOOP;
--Escribes la linea en el fichero
UTL_FILE.PUT_LINE(v_file, v_buffer);

--Cerrar el handler al fichero
UTL_FILE.FCLOSE(v_file);
COMMIT;

  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_respuesta := pa_file_ftp.fu_put_ascii(pa_rpc_aut.g_ip, pa_rpc_aut.g_port,
   pa_rpc_aut.g_user,pa_rpc_aut.g_pass, pa_rpc_aut.g_repository,
   v_name||'.txt', g_contabilidad||v_name||'_'||v_fecha||'.txt');

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el mail
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','DEVENGADO_DIA');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte Devengado Diario a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_contabilidad||'

    Nombre del Archivo: '||v_name||'_'||v_fecha||'.txt';

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error    := null;

    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, v_name||'_'||v_fecha||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;

    --Enviamos el mail a soporte
     -- Obtenemos direccion de correo de soporte
     v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error Reporte Devengado Diario a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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
    RAISE_APPLICATION_ERROR(-20062,'Manejador invalido');
  WHEN UTL_FILE.WRITE_ERROR THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20063,'Error de escritura '||sqlerrm);
  WHEN UTL_FILE.INVALID_MODE THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20064,'Modo invalido');
  WHEN UTL_FILE.INTERNAL_ERROR THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20065,'Internal Error');
END pr_dev_dia;
-------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------
-- Devengado Diario con Rubros
PROCEDURE pr_dev_dia_rub
IS
CURSOR cu_dev_dia_rub(p_fecha DATE, p_mes VARCHAR2) IS
    select c.cod_persona, e.nom_completo, p.nro_cuenta, s.cod_moneda, s.cod_oficina, s.val_tasa, s.dev_acumulado, s.dev_no_cobrado,
    s.dev_suspenso, s.val_int_devengar, s.sal_capital, s.sal_interes, s.sal_int_adelantado, s.estado, s.fec_ult_devengado,
    s.tip_interes, p.cod_modalidad, tot_cap_acumulado, tot_int_acumulado, can_dia_acumulado,
    d.capital sal_cap_cuota, d.fec_inicio, d.fecha, d.nro_cuota,
    dev_nco_dia_01, dev_sus_dia_01, dev_nco_dia_02, dev_sus_dia_02, dev_nco_dia_03, dev_sus_dia_03, dev_nco_dia_04,
    dev_sus_dia_04, dev_nco_dia_05, dev_sus_dia_05, dev_nco_dia_06, dev_sus_dia_06, dev_nco_dia_07, dev_sus_dia_07,
    dev_nco_dia_08, dev_sus_dia_08, dev_nco_dia_09, dev_sus_dia_09, dev_nco_dia_10, dev_sus_dia_10, dev_nco_dia_11,
    dev_sus_dia_11, dev_nco_dia_12, dev_sus_dia_12, dev_nco_dia_13, dev_sus_dia_13, dev_nco_dia_14, dev_sus_dia_14,
    dev_nco_dia_15, dev_sus_dia_15, dev_nco_dia_16, dev_sus_dia_16, dev_nco_dia_17, dev_sus_dia_17, dev_nco_dia_18,
    dev_sus_dia_18, dev_nco_dia_19, dev_sus_dia_19, dev_nco_dia_20, dev_sus_dia_20, dev_nco_dia_21, dev_sus_dia_21,
    dev_nco_dia_22, dev_sus_dia_22, dev_nco_dia_23, dev_sus_dia_23, dev_nco_dia_24, dev_sus_dia_24, dev_nco_dia_25,
    dev_sus_dia_25, dev_nco_dia_26, dev_sus_dia_26, dev_nco_dia_27, dev_sus_dia_27, dev_nco_dia_28, dev_sus_dia_28,
    dev_nco_dia_29, dev_sus_dia_29, dev_nco_dia_30, dev_sus_dia_30, dev_nco_dia_31, dev_sus_dia_31,
    fub_obt_rub_transaccion(s.cod_modulo, s.cod_modalidad, 903, --codigo transaccion
                 s.cod_moneda, c.cod_persona, fug_obt_plz_contable(s.fec_vencimiento - s.fec_inicio), 'D',
                 s.estado, s.tip_renovacion, nvl(t.cat_riesgo,1), s.tip_interes, s.tipo, null, s.cod_sec_credito
                ) rubro_903,
    fub_obt_rub_transaccion(s.cod_modulo, s.cod_modalidad, 947, --codigo transaccion
                 s.cod_moneda, c.cod_persona, fug_obt_plz_contable(s.fec_vencimiento - s.fec_inicio), 'C',
                 s.estado, s.tip_renovacion, t.cat_riesgo, s.tip_interes, s.tipo, null, s.cod_sec_credito
                ) rubro_947,
    fub_obt_rub_transaccion(s.cod_modulo, s.cod_modalidad, 901, --codigo transaccion
                 s.cod_moneda, c.cod_persona, fug_obt_plz_contable(s.fec_vencimiento - s.fec_inicio), 'C',
                 s.estado, s.tip_renovacion, t.cat_riesgo, s.tip_interes, s.tipo, null, s.cod_sec_credito
                ) rubro_901
    from pr_sal_mensuales p, ge_cta_clientes c, ba_personas e,pr_cta_prestamos s, ge_clientes t,
    (select nro_cuenta, nro_cuota, fecha, capital, fec_inicio
      from pr_devengados e
      where fec_ult_devengado = p_fecha
      and exists(select 1 from pr_cta_prestamos o
            where e.nro_cuenta = o.nro_cuenta
            and o.tip_interes = 'V')) d
    where mes = p_mes
    and c.nro_cuenta = p.nro_cuenta
    and c.relacion='P'
    and c.cod_persona = e.cod_persona
    and s.nro_cuenta=p.nro_cuenta
    and d.nro_cuenta(+)=p.nro_cuenta
    and c.cod_persona = t.cod_persona;

  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'dev_dia_rub'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_fec_sist         DATE;
  v_fecha            VARCHAR2(8);
  v_mes              VARCHAR2(2);

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
  select pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1)
  into v_fec_sist
  from dual;

  v_fecha := to_char(v_fec_sist,'DDMMYYYY');
  v_mes := to_char(v_fec_sist,'MM');

-- Abrir archivo
v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'.txt','W',32767);

-- Colocar el titulo a los campos
v_linetit := 'COD_PERSONA'||CHR(9)||'NOM_COMPLETO'||CHR(9)||'NRO_CUENTA'||CHR(9)||'COD_MONEDA'||CHR(9)||'COD_OFICINA'||CHR(9)||'VAL_TASA'||CHR(9)||'DEV_ACUMULADO'||CHR(9)||'DEV_NO_COBRADO'||CHR(9)||
    'DEV_SUSPENSO'||CHR(9)||'VAL_INT_DEVENGAR'||CHR(9)||'SAL_CAPITAL'||CHR(9)||'SAL_INTERES'||CHR(9)||'SAL_INT_ADELANTADO'||CHR(9)||'ESTADO'||CHR(9)||'FEC_ULT_DEVENGADO'||CHR(9)||
    'TIP_INTERES'||CHR(9)||'COD_MODALIDAD'||CHR(9)||'TOT_CAP_ACUMULADO'||CHR(9)||'TOT_INT_ACUMULADO'||CHR(9)||'CAN_DIA_ACUMULADO'||CHR(9)||
    'SAL_CAP_CUOTA'||CHR(9)||'FEC_INICIO'||CHR(9)||'FECHA'||CHR(9)||'NRO_CUOTA'||CHR(9)||
    'DEV_NCO_DIA_01'||CHR(9)||'DEV_SUS_DIA_01'||CHR(9)||'DEV_NCO_DIA_02'||CHR(9)||'DEV_SUS_DIA_02'||CHR(9)||'DEV_NCO_DIA_03'||CHR(9)||'DEV_SUS_DIA_03'||CHR(9)||'DEV_NCO_DIA_04'||CHR(9)||
    'DEV_SUS_DIA_04'||CHR(9)||'DEV_NCO_DIA_05'||CHR(9)||'DEV_SUS_DIA_05'||CHR(9)||'DEV_NCO_DIA_06'||CHR(9)||'DEV_SUS_DIA_06'||CHR(9)||'DEV_NCO_DIA_07'||CHR(9)||'DEV_SUS_DIA_07'||CHR(9)||
    'DEV_NCO_DIA_08'||CHR(9)||'DEV_SUS_DIA_08'||CHR(9)||'DEV_NCO_DIA_09'||CHR(9)||'DEV_SUS_DIA_09'||CHR(9)||'DEV_NCO_DIA_10'||CHR(9)||'DEV_SUS_DIA_10'||CHR(9)||'DEV_NCO_DIA_11'||CHR(9)||
    'DEV_SUS_DIA_11'||CHR(9)||'DEV_NCO_DIA_12'||CHR(9)||'DEV_SUS_DIA_12'||CHR(9)||'DEV_NCO_DIA_13'||CHR(9)||'DEV_SUS_DIA_13'||CHR(9)||'DEV_NCO_DIA_14'||CHR(9)||'DEV_SUS_DIA_14'||CHR(9)||
    'DEV_NCO_DIA_15'||CHR(9)||'DEV_SUS_DIA_15'||CHR(9)||'DEV_NCO_DIA_16'||CHR(9)||'DEV_SUS_DIA_16'||CHR(9)||'DEV_NCO_DIA_17'||CHR(9)||'DEV_SUS_DIA_17'||CHR(9)||'DEV_NCO_DIA_18'||CHR(9)||
    'DEV_SUS_DIA_18'||CHR(9)||'DEV_NCO_DIA_19'||CHR(9)||'DEV_SUS_DIA_19'||CHR(9)||'DEV_NCO_DIA_20'||CHR(9)||'DEV_SUS_DIA_20'||CHR(9)||'DEV_NCO_DIA_21'||CHR(9)||'DEV_SUS_DIA_21'||CHR(9)||
    'DEV_NCO_DIA_22'||CHR(9)||'DEV_SUS_DIA_22'||CHR(9)||'DEV_NCO_DIA_23'||CHR(9)||'DEV_SUS_DIA_23'||CHR(9)||'DEV_NCO_DIA_24'||CHR(9)||'DEV_SUS_DIA_24'||CHR(9)||'DEV_NCO_DIA_25'||CHR(9)||
    'DEV_SUS_DIA_25'||CHR(9)||'DEV_NCO_DIA_26'||CHR(9)||'DEV_SUS_DIA_26'||CHR(9)||'DEV_NCO_DIA_27'||CHR(9)||'DEV_SUS_DIA_27'||CHR(9)||'DEV_NCO_DIA_28'||CHR(9)||'DEV_SUS_DIA_28'||CHR(9)||
    'DEV_NCO_DIA_29'||CHR(9)||'DEV_SUS_DIA_29'||CHR(9)||'DEV_NCO_DIA_30'||CHR(9)||'DEV_SUS_DIA_30'||CHR(9)||'DEV_NCO_DIA_31'||CHR(9)||'DEV_SUS_DIA_31'||CHR(9)||
    'RUBRO_903'||CHR(9)||'RUBRO_947'||CHR(9)||'RUBRO_901';

utl_file.put_line(v_file,v_linetit);

-- Definir una linea en blanco para separar los datos del titulo de los campos
v_linetit := ' ';
utl_file.put_line(v_file,v_linetit);

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN cu_dev_dia_rub(v_fec_sist, v_mes) LOOP

    --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
  v_line := to_char(rec.cod_persona)||chr(9)||to_char(rec.nom_completo)||chr(9)||to_char(rec.nro_cuenta)||chr(9)||to_char(rec.cod_moneda)||chr(9)||to_char(rec.cod_oficina)||chr(9)||to_char(rec.val_tasa)||chr(9)||to_char(rec.dev_acumulado,'999999999999D00')||chr(9)||to_char(rec.dev_no_cobrado,'999999999999D00')||chr(9)||
    to_char(rec.dev_suspenso,'999999999999D00')||chr(9)||to_char(rec.val_int_devengar,'999999999999D00')||chr(9)||to_char(rec.sal_capital,'999999999999D00')||chr(9)||to_char(rec.sal_interes,'999999999999D00')||chr(9)||to_char(rec.sal_int_adelantado,'999999999999D00')||chr(9)||to_char(rec.estado)||chr(9)||to_char(rec.fec_ult_devengado)||chr(9)||
    to_char(rec.tip_interes)||chr(9)||to_char(rec.cod_modalidad)||chr(9)||to_char(rec.tot_cap_acumulado,'999999999999D00')||chr(9)||to_char(rec.tot_int_acumulado,'999999999999D00')||chr(9)||to_char(rec.can_dia_acumulado)||chr(9)||
    to_char(rec.sal_cap_cuota)||chr(9)||to_char(rec.fec_inicio)||chr(9)||to_char(rec.fecha)||chr(9)||to_char(rec.nro_cuota)||chr(9)||
    to_char(rec.dev_nco_dia_01)||chr(9)||to_char(rec.dev_sus_dia_01)||chr(9)||to_char(rec.dev_nco_dia_02)||chr(9)||to_char(rec.dev_sus_dia_02)||chr(9)||to_char(rec.dev_nco_dia_03)||chr(9)||to_char(rec.dev_sus_dia_03)||chr(9)||to_char(rec.dev_nco_dia_04)||chr(9)||
    to_char(rec.dev_sus_dia_04)||chr(9)||to_char(rec.dev_nco_dia_05)||chr(9)||to_char(rec.dev_sus_dia_05)||chr(9)||to_char(rec.dev_nco_dia_06)||chr(9)||to_char(rec.dev_sus_dia_06)||chr(9)||to_char(rec.dev_nco_dia_07)||chr(9)||to_char(rec.dev_sus_dia_07)||chr(9)||
    to_char(rec.dev_nco_dia_08)||chr(9)||to_char(rec.dev_sus_dia_08)||chr(9)||to_char(rec.dev_nco_dia_09)||chr(9)||to_char(rec.dev_sus_dia_09)||chr(9)||to_char(rec.dev_nco_dia_10)||chr(9)||to_char(rec.dev_sus_dia_10)||chr(9)||to_char(rec.dev_nco_dia_11)||chr(9)||
    to_char(rec.dev_sus_dia_11)||chr(9)||to_char(rec.dev_nco_dia_12)||chr(9)||to_char(rec.dev_sus_dia_12)||chr(9)||to_char(rec.dev_nco_dia_13)||chr(9)||to_char(rec.dev_sus_dia_13)||chr(9)||to_char(rec.dev_nco_dia_14)||chr(9)||to_char(rec.dev_sus_dia_14)||chr(9)||
    to_char(rec.dev_nco_dia_15)||chr(9)||to_char(rec.dev_sus_dia_15)||chr(9)||to_char(rec.dev_nco_dia_16)||chr(9)||to_char(rec.dev_sus_dia_16)||chr(9)||to_char(rec.dev_nco_dia_17)||chr(9)||to_char(rec.dev_sus_dia_17)||chr(9)||to_char(rec.dev_nco_dia_18)||chr(9)||
    to_char(rec.dev_sus_dia_18)||chr(9)||to_char(rec.dev_nco_dia_19)||chr(9)||to_char(rec.dev_sus_dia_19)||chr(9)||to_char(rec.dev_nco_dia_20)||chr(9)||to_char(rec.dev_sus_dia_20)||chr(9)||to_char(rec.dev_nco_dia_21)||chr(9)||to_char(rec.dev_sus_dia_21)||chr(9)||
    to_char(rec.dev_nco_dia_22)||chr(9)||to_char(rec.dev_sus_dia_22)||chr(9)||to_char(rec.dev_nco_dia_23)||chr(9)||to_char(rec.dev_sus_dia_23)||chr(9)||to_char(rec.dev_nco_dia_24)||chr(9)||to_char(rec.dev_sus_dia_24)||chr(9)||to_char(rec.dev_nco_dia_25)||chr(9)||
    to_char(rec.dev_sus_dia_25)||chr(9)||to_char(rec.dev_nco_dia_26)||chr(9)||to_char(rec.dev_sus_dia_26)||chr(9)||to_char(rec.dev_nco_dia_27)||chr(9)||to_char(rec.dev_sus_dia_27)||chr(9)||to_char(rec.dev_nco_dia_28)||chr(9)||to_char(rec.dev_sus_dia_28)||chr(9)||
    to_char(rec.dev_nco_dia_29)||chr(9)||to_char(rec.dev_sus_dia_29)||chr(9)||to_char(rec.dev_nco_dia_30)||chr(9)||to_char(rec.dev_sus_dia_30)||chr(9)||to_char(rec.dev_nco_dia_31)||chr(9)||to_char(rec.dev_sus_dia_31)||chr(9)||
    to_char(rec.rubro_903)||chr(9)||to_char(rec.rubro_947)||chr(9)||to_char(rec.rubro_901);

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

   EXIT WHEN cu_dev_dia_rub%NOTFOUND;
END LOOP;
--Escribes la linea en el fichero
UTL_FILE.PUT_LINE(v_file, v_buffer);

--Cerrar el handler al fichero
UTL_FILE.FCLOSE(v_file);
COMMIT;

  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_respuesta := pa_file_ftp.fu_put_ascii(pa_rpc_aut.g_ip, pa_rpc_aut.g_port, pa_rpc_aut.g_user,
                                          pa_rpc_aut.g_pass, pa_rpc_aut.g_repository,
                                          v_name||'.txt', g_contabilidad||v_name||'_'||v_fecha||'.txt');

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','DEVENGADO_DIA_RUBRO');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte Devengado Diario con Rubros a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_contabilidad||'

    Nombre del Archivo: '||v_name||'_'||v_fecha||'.txt';

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error    := null;

    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, v_name||'_'||v_fecha||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;

    --Enviamos el mail a soporte
     -- Obtenemos direccion de correo de soporte
     v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error Reporte Devengado Diario con Rubros a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  END IF;

 COMMIT;
EXCEPTION
  WHEN UTL_FILE.INVALID_OPERATION THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20061,'Operacion invalida');
  WHEN UTL_FILE.INVALID_FILEHANDLE THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20062,'Manejador invalido');
  WHEN UTL_FILE.WRITE_ERROR THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20063,'Error de escritura '||sqlerrm);
  WHEN UTL_FILE.INVALID_MODE THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20064,'Modo invalido');
  WHEN UTL_FILE.INTERNAL_ERROR THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20065,'Internal Error');
END pr_dev_dia_rub;
-------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------
-- Pre Cierre Diario
PROCEDURE pr_pre_cierre
IS
CURSOR cu_precierre_dia(p_fecha DATE) IS
    select ' '||b.hora hora,
      b.cod_usuario usuario,
      b.cod_ofi_origen ofi,
      b.nro_secuencia sec,
      b.nro_cuenta cuenta,
      b.cod_moneda mon,
      b.monto,
      b.mto_equ_local mto_en_gs,
      b.cod_tra_padre cod_p,
      c.descripcion transaccion_padre,
      b.cod_modalidad cod_m,
      b.cod_transaccion cod_t,
      d.descripcion transaccion_hijo,
      b.tip_mov_rubro tip,
      substr(b.cod_rubro,1,2)||'.'||
      substr(b.cod_rubro,3,1)||'.'||
      substr(b.cod_rubro,4,2)||'.'||
      substr(b.cod_rubro,6,3)||'.'||
      substr(b.cod_rubro,3,1)||'.'||
      substr(b.cod_rubro,9,2)||'.'||
      substr(b.cod_rubro,11,3)||'.'||
      substr(b.cod_rubro,14,2) rubro_contable,
      x.descripcion des_rubro,
      b.monto mto_asiento,
      decode(b.tip_mov_rubro, 'D', b.mto_equ_local, 0) Debito,
      decode(b.tip_mov_rubro, 'C', b.mto_equ_local, 0) Crédito,
      observacion,
      x.cod_rub_externo
    from cb_rubros x, ge_transacciones d, ge_transacciones c, ge_asientos_tmp b
    where b.cod_mod_padre = c.cod_modulo(+)
    and b.cod_mad_padre= c.cod_modalidad(+)
    and b.cod_tra_padre = c.cod_transaccion(+)
    and b.cod_modulo = d.cod_modulo(+)
    and b.cod_modalidad = d.cod_modalidad(+)
    and b.cod_transaccion = d.cod_transaccion(+)
    and x.cod_rubro(+)  = b.cod_rubro
    and b.fecha = p_fecha
    order by hora;

  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'pre_cierre_dia'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_fec_sist         DATE;
  v_fecha            VARCHAR2(8);

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
  select pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1)
  into v_fec_sist
  from dual;

  v_fecha := to_char(v_fec_sist,'DDMMYYYY');

-- Abrir archivo
v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'.txt','W',32767);

-- Colocar el titulo a los campos
v_linetit := 'HORA'||CHR(9)||'USUARIO'||CHR(9)||'OFI'||CHR(9)||'SEC'||CHR(9)||'CUENTA'||CHR(9)||'MON'||CHR(9)||'MONTO'||CHR(9)||'MTO_EN_GS'||CHR(9)||
    'COD_P'||CHR(9)||'TRANSACCION_PADRE'||CHR(9)||'COD_M'||CHR(9)||'COD_T'||CHR(9)||'TRANSACCION_HIJO'||CHR(9)||'TIP'||CHR(9)||'RUBRO_CONTABLE'||CHR(9)||
    'DES_RUBRO'||CHR(9)||'MTO_ASIENTO'||CHR(9)||'DEBITO'||CHR(9)||'CRÉDITO'||CHR(9)||'OBSERVACION'||CHR(9)||'COD_RUB_EXTERNO';

utl_file.put_line(v_file,v_linetit);

-- Definir una linea en blanco para separar los datos del titulo de los campos
v_linetit := ' ';
utl_file.put_line(v_file,v_linetit);

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN cu_precierre_dia(v_fec_sist) LOOP

    --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
  v_line := to_char(rec.hora)||chr(9)||to_char(rec.usuario)||chr(9)||to_char(rec.ofi)||chr(9)||to_char(rec.sec)||chr(9)||to_char(rec.cuenta)||chr(9)||
    to_char(rec.mon)||chr(9)||to_char(rec.monto,'999999999999D00')||chr(9)||to_char(rec.mto_en_gs,'999999999999D00')||chr(9)||
    to_char(rec.cod_p)||chr(9)||to_char(rec.transaccion_padre)||chr(9)||to_char(rec.cod_m)||chr(9)||to_char(rec.cod_t)||chr(9)||
    to_char(rec.transaccion_hijo)||chr(9)||to_char(rec.tip)||chr(9)||to_char(rec.rubro_contable)||chr(9)||to_char(rec.des_rubro)||chr(9)||
    to_char(rec.mto_asiento,'999999999999D00')||chr(9)||to_char(rec.Debito,'999999999999D00')||chr(9)||to_char(rec.Crédito,'999999999999D00')||chr(9)||
    to_char(rec.observacion)||chr(9)||to_char(rec.cod_rub_externo);


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

  EXIT WHEN cu_precierre_dia%NOTFOUND;
END LOOP;
--Escribes la linea en el fichero
UTL_FILE.PUT_LINE(v_file, v_buffer);

--Cerrar el handler al fichero
UTL_FILE.FCLOSE(v_file);
COMMIT;

  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_respuesta := pa_file_ftp.fu_put_ascii(pa_rpc_aut.g_ip, pa_rpc_aut.g_port, pa_rpc_aut.g_user,
                                          pa_rpc_aut.g_pass, pa_rpc_aut.g_repository,
                                          v_name||'.txt', g_contabilidad||v_name||'_'||v_fecha||'.txt');

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','PRE_CIERRE_DIA');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte Pre Cierre Diario a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_contabilidad||'

    Nombre del Archivo: '||v_name||'_'||v_fecha||'.txt';

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error    := null;

    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, v_name||'_'||v_fecha||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;

    --Enviamos el mail a soporte
     -- Obtenemos direccion de correo de soporte
     v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error Reporte Pre Cierre Diario a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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
END pr_pre_cierre;
-------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------
-- Inventario de Sobregiros
PROCEDURE pr_sobregiros
IS
CURSOR cu_sob_inventario(p_fecha DATE) IS
    select i.COD_PERSONA,
      i.NOM_COMPLETO,
      i.CTA_CONTABLE,
      i.NRO_CUENTA,
      i.COD_OFICINA,
      i.PRODUCTO,
      i.SUBCTA,
      i.COD_MONEDA,
      i.SAL_TOTAL,
      i.SAL_RETENIDO,
      i.SAL_BLOQUEADO,
      i.MTO_EMBARGO,
      i.SAL_DISPONIBLE,
      i.MONTO_LINEA,
      i.EXCESOS,
      i.FEC_ENTRADA,
      i.FEC_VENCIMIENTO,
      i.GESTOR,
      i.FEC_INSERCION,
      i.FECHA
    from cc_sob_inventario i
    where i.fecha = p_fecha;

  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'sobregiros'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_fec_sist         DATE;
  v_fecha            VARCHAR2(8);

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
  select pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1)
  into v_fec_sist
  from dual;

  v_fecha := to_char(v_fec_sist,'DDMMYYYY');

-- Abrir archivo
v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'.txt','W',32767);

-- Colocar el titulo a los campos
v_linetit := 'COD_PERSONA'||CHR(9)||'NOM_COMPLETO'||CHR(9)||'CTA_CONTABLE'||CHR(9)||'NRO_CUENTA'||CHR(9)||'COD_OFICINA'||CHR(9)||'PRODUCTO'||CHR(9)||'SUBCTA'||CHR(9)||'COD_MONEDA'||CHR(9)||
    'SAL_TOTAL'||CHR(9)||'SAL_RETENIDO'||CHR(9)||'SAL_BLOQUEADO'||CHR(9)||'MTO_EMBARGO'||CHR(9)||'SAL_DISPONIBLE'||CHR(9)||'MONTO_LINEA'||CHR(9)||'EXCESOS'||CHR(9)||
    'FEC_ENTRADA'||CHR(9)||'FEC_VENCIMIENTO'||CHR(9)||'GESTOR'||CHR(9)||'FEC_INSERCION'||CHR(9)||'FECHA';

utl_file.put_line(v_file,v_linetit);

-- Definir una linea en blanco para separar los datos del titulo de los campos
v_linetit := ' ';
utl_file.put_line(v_file,v_linetit);

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN cu_sob_inventario(v_fec_sist) LOOP

    --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
  v_line := to_char(rec.COD_PERSONA)||chr(9)||to_char(rec.NOM_COMPLETO)||chr(9)||to_char(rec.CTA_CONTABLE)||chr(9)||to_char(rec.NRO_CUENTA)||chr(9)||to_char(rec.COD_OFICINA)||chr(9)||
    to_char(rec.PRODUCTO)||chr(9)||to_char(rec.SUBCTA)||chr(9)||to_char(rec.COD_MONEDA)||chr(9)||to_char(rec.SAL_TOTAL,'999999999999D00')||chr(9)||
    to_char(rec.SAL_RETENIDO,'999999999999D00')||chr(9)||to_char(rec.SAL_BLOQUEADO,'999999999999D00')||chr(9)||to_char(rec.MTO_EMBARGO,'999999999999D00')||chr(9)||
    to_char(rec.SAL_DISPONIBLE,'999999999999D00')||chr(9)||to_char(rec.MONTO_LINEA,'999999999999D00')||chr(9)||to_char(rec.EXCESOS,'999999999999D00')||chr(9)||
    to_char(rec.FEC_ENTRADA)||chr(9)||to_char(rec.FEC_VENCIMIENTO)||chr(9)||to_char(rec.GESTOR)||chr(9)||to_char(rec.FEC_INSERCION)||chr(9)||to_char(rec.FECHA);


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

  EXIT WHEN cu_sob_inventario%NOTFOUND;
END LOOP;
--Escribes la linea en el fichero
UTL_FILE.PUT_LINE(v_file, v_buffer);

--Cerrar el handler al fichero
UTL_FILE.FCLOSE(v_file);
COMMIT;

  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_respuesta := pa_file_ftp.fu_put_ascii(pa_rpc_aut.g_ip, pa_rpc_aut.g_port, pa_rpc_aut.g_user,
                                          pa_rpc_aut.g_pass, pa_rpc_aut.g_repository,
                                          v_name||'.txt', g_riesgos||v_name||'_'||v_fecha||'.txt');

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOBREGIROS');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte Inventario de Sobregiros a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_riesgos||'

    Nombre del Archivo: '||v_name||'_'||v_fecha||'.txt';

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
     v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
    it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error    := null;

    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, v_name||'_'||v_fecha||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;

    --Enviamos el mail a soporte
     -- Obtenemos direccion de correo de soporte
     v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error Reporte Inventario de Sobregiros a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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
END pr_sobregiros;
-------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------
-- Depósitos con Cheque - Detalle Movimiento
PROCEDURE pr_cheq_det_mov
IS
CURSOR cu_che_det_mov(p_fecha DATE) IS
    select a.fecha, a.hora, a.cod_usuario, a.cod_tra_padre,
        fug_obt_des_transaccion(a.cod_mod_padre,a.cod_mad_padre,a.cod_tra_padre) des_tra_padre,
        decode(a.tip_monto,'O',case when a.nro_caja in (select c.nro_caja from cj_cajas c where c.tipo = 'S') then 9 else 1 end, 'T',2,'S',3,'-') retencion,
        '['||a.cod_oficina||'] '||fue_obt_des_oficina(a.cod_oficina) oficina,
        a.cod_moneda, a.nro_caja, a.nro_cuenta, a.monto, a.nro_documento
        from cj_movimientos_his a
        where fecha = p_fecha
          and tip_monto in ('O','S','T')
          and estado != 'R'
          and cod_moneda = pag_gen.fu_obt_mon_local
        order by 1,3,2;

  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'cheque_det_mov'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_fec_sist         DATE;
  v_fecha            VARCHAR2(8);

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
  select pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1)
  into v_fec_sist
  from dual;

  v_fecha := to_char(v_fec_sist,'DDMMYYYY');

-- Abrir archivo
v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'.txt','W',32767);

-- Colocar el titulo a los campos
v_linetit := 'FECHA'||CHR(9)||'HORA'||CHR(9)||'COD_USUARIO'||CHR(9)||'COD_TRA_PADRE'||CHR(9)||'DES_TRA_PADRE'||CHR(9)||'RETENCION'||CHR(9)||'OFICINA'||CHR(9)||
           'COD_MONEDA'||CHR(9)||'NRO_CAJA'||CHR(9)||'NRO_CUENTA'||CHR(9)||'MONTO'||CHR(9)||'NRO_DOCUMENTO';

utl_file.put_line(v_file,v_linetit);

-- Definir una linea en blanco para separar los datos del titulo de los campos
v_linetit := ' ';
utl_file.put_line(v_file,v_linetit);

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN cu_che_det_mov(v_fec_sist) LOOP

    --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
  v_line := to_char(rec.fecha)||chr(9)||to_char(rec.hora)||chr(9)||to_char(rec.cod_usuario)||chr(9)||to_char(rec.cod_tra_padre)||chr(9)||
    to_char(rec.des_tra_padre)||chr(9)||to_char(rec.retencion)||chr(9)||to_char(rec.oficina)||chr(9)||to_char(rec.cod_moneda)||chr(9)||
    to_char(rec.nro_caja)||chr(9)||to_char(rec.nro_cuenta)||chr(9)||to_char(rec.monto,'999999999999D00')||chr(9)||to_char(rec.nro_documento);


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

  EXIT WHEN cu_che_det_mov%NOTFOUND;
END LOOP;
--Escribes la linea en el fichero
UTL_FILE.PUT_LINE(v_file, v_buffer);

--Cerrar el handler al fichero
UTL_FILE.FCLOSE(v_file);
COMMIT;

  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_respuesta := pa_file_ftp.fu_put_ascii(pa_rpc_aut.g_ip, pa_rpc_aut.g_port, pa_rpc_aut.g_user,
                                          pa_rpc_aut.g_pass, pa_rpc_aut.g_repository,
                                          v_name||'.txt', g_contabilidad||v_name||'_'||v_fecha||'.txt');

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','CHEQUE_DET_MOV');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte Depósitos con Cheque - Detalle Movimiento a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_contabilidad||'

    Nombre del Archivo: '||v_name||'_'||v_fecha||'.txt';

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error    := null;

    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, v_name||'_'||v_fecha||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;

    --Enviamos el mail a soporte
     -- Obtenemos direccion de correo de soporte
     v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error Reporte Depósitos con Cheque - Detalle Movimiento a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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
END pr_cheq_det_mov;
-------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------
-- Depósitos con Cheque - Cheques Remitidos Detalle
PROCEDURE pr_cheq_rem_det
IS
CURSOR cu_che_rem_det(p_fecha DATE) IS
        select x.fecha,
           x.cod_oficina,
           x.nro_lote,
           x.cod_banco,
           x.nro_cuenta cta_libradora,
           x.nro_cheque,
           x.monto,
           x.cod_cau_devolucion,
           x.dev_com_directa
        from cc_che_remitidos x
        where x.fecha >= p_fecha
        and x.fecha   <= p_fecha
        order by x.fecha, x.cod_oficina, x.nro_lote;

  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'cheque_rem_det'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_fec_sist         DATE;
  v_fecha            VARCHAR2(8);

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
  select pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1)
  into v_fec_sist
  from dual;

  v_fecha := to_char(v_fec_sist,'DDMMYYYY');

-- Abrir archivo
v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'.txt','W',32767);

-- Colocar el titulo a los campos
v_linetit := 'FECHA'||CHR(9)||'COD_OFICINA'||CHR(9)||'NRO_LOTE'||CHR(9)||'COD_BANCO'||CHR(9)||'CTA_LIBRADORA'||CHR(9)||
             'NRO_CHEQUE'||CHR(9)||'MONTO'||CHR(9)||'COD_CAU_DEVOLUCION'||CHR(9)||'DEV_COM_DIRECTA';

utl_file.put_line(v_file,v_linetit);

-- Definir una linea en blanco para separar los datos del titulo de los campos
v_linetit := ' ';
utl_file.put_line(v_file,v_linetit);

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN cu_che_rem_det(v_fec_sist) LOOP

    --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
  v_line := to_char(rec.fecha)||chr(9)||to_char(rec.cod_oficina)||chr(9)||to_char(rec.nro_lote)||chr(9)||
         to_char(rec.cod_banco)||chr(9)||to_char(rec.cta_libradora)||chr(9)||to_char(rec.nro_cheque)||chr(9)||
         to_char(rec.monto,'999999999999D00')||chr(9)||to_char(rec.cod_cau_devolucion)||chr(9)||to_char(rec.dev_com_directa);


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

  EXIT WHEN cu_che_rem_det%NOTFOUND;
END LOOP;
--Escribes la linea en el fichero
UTL_FILE.PUT_LINE(v_file, v_buffer);

--Cerrar el handler al fichero
UTL_FILE.FCLOSE(v_file);
COMMIT;

  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_respuesta := pa_file_ftp.fu_put_ascii(pa_rpc_aut.g_ip, pa_rpc_aut.g_port, pa_rpc_aut.g_user,
                                          pa_rpc_aut.g_pass, pa_rpc_aut.g_repository,
                                          v_name||'.txt', g_contabilidad||v_name||'_'||v_fecha||'.txt');

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','CHEQUE_REM_DET');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte Depósitos con Cheque - Cheques Remitidos Detalle a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_contabilidad||'

    Nombre del Archivo: '||v_name||'_'||v_fecha||'.txt';

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error    := null;

    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, v_name||'_'||v_fecha||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;

    --Enviamos el mail a soporte
     -- Obtenemos direccion de correo de soporte
     v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error Reporte Depósitos con Cheque - Cheques Remitidos Detalle a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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
END pr_cheq_rem_det;
-------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------
-- Depósitos con Cheque - Cheques Remitidos Cabecera
PROCEDURE pr_cheq_rem_cab
IS
CURSOR cu_che_rem_cab(p_fecha DATE) IS
        select r.fecha,
           r.cod_oficina,
           r.nro_caja,
           r.nro_lote,
           r.nro_referencia cta_dep,
           r.monto
        from cc_che_remitidos_res r
        where r.fecha >= p_fecha
        and r.fecha   <= p_fecha
        order by r.fecha, r.cod_oficina, r.nro_lote;

  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'cheque_rem_cab'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_fec_sist         DATE;
  v_fecha            VARCHAR2(8);

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
  select pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1)
  into v_fec_sist
  from dual;

  v_fecha := to_char(v_fec_sist,'DDMMYYYY');

-- Abrir archivo
v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'.txt','W',32767);

-- Colocar el titulo a los campos
v_linetit := 'FECHA'||CHR(9)||'COD_OFICINA'||CHR(9)||'NRO_CAJA'||CHR(9)||'NRO_LOTE'||CHR(9)||'CTA_DEP'||CHR(9)||'MONTO';

utl_file.put_line(v_file,v_linetit);

-- Definir una linea en blanco para separar los datos del titulo de los campos
v_linetit := ' ';
utl_file.put_line(v_file,v_linetit);

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN cu_che_rem_cab(v_fec_sist) LOOP

    --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
  v_line := to_char(rec.fecha)||chr(9)||to_char(rec.cod_oficina)||chr(9)||to_char(rec.nro_caja)||chr(9)||
             to_char(rec.nro_lote)||chr(9)||to_char(rec.cta_dep)||chr(9)||to_char(rec.monto,'999999999999D00');


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

  EXIT WHEN cu_che_rem_cab%NOTFOUND;
END LOOP;
--Escribes la linea en el fichero
UTL_FILE.PUT_LINE(v_file, v_buffer);

--Cerrar el handler al fichero
UTL_FILE.FCLOSE(v_file);
COMMIT;

  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_respuesta := pa_file_ftp.fu_put_ascii(pa_rpc_aut.g_ip, pa_rpc_aut.g_port, pa_rpc_aut.g_user,
                                          pa_rpc_aut.g_pass, pa_rpc_aut.g_repository,
                                          v_name||'.txt', g_contabilidad||v_name||'_'||v_fecha||'.txt');

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','CHEQUE_REM_CAB');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte Depósitos con Cheque - Cheques Remitidos Cabecera a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_contabilidad||'

    Nombre del Archivo: '||v_name||'_'||v_fecha||'.txt';

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error    := null;

    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, v_name||'_'||v_fecha||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;

    --Enviamos el mail a soporte
     -- Obtenemos direccion de correo de soporte
     v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error Reporte Depósitos con Cheque - Cheques Remitidos Cabecera a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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
END pr_cheq_rem_cab;
-------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------
-- Previsiones Específicas Detallado
--PROCEDURE pr_previ_det
  /*
       Borrado por Rolando Enciso por inconsistencia en el paquete pa_rpc_aut,
       el mismo procedimiento se encuentra en el paquete pag_evo.
  */

-------------------------------------------------------------------------------------------------------------------------------------
-- Previsiones Específicas Resumen
PROCEDURE pr_previ_res
IS
CURSOR cu_prevision_res IS
    select o.cod_persona riesgo, p.nom_completo nombre_per, d.abreviatura doc, p.nro_documento nro_doc,
       e.cat_riesgo, fup_obt_categoria(e.cat_automatica,e.cat_subjetiva) cat_crc,
       e.cod_oficina ofi, n.descripcion oficina, e.cod_usu_oficial, u.nombre nombre_usu,
       g.descripcion banca, e.cat_subjetiva, e.cod_gru_economico gru_eco,
       e.cat_gru_economico, e.cat_sistema,
       e.tipo, substr(r1.significado,1,40) tip_cliente,
       e.tot_deu_sistema tot_deu_rsistema, e.tot_deu_con_sistema tot_con_rsistema,
       sum(o.tot_deu_real) tot_deu_real, sum(o.tot_deu_contingente) tot_deu_contingente, sum(o.dev_no_cobrado) dev_no_cobrado,
       sum(o.tot_gar_computables) tot_gar_computables, sum(o.tot_prevision) tot_prevision,
       (case when e.cat_riesgo = 1 and to_char(nvl(MAX(o.cat_automatica),1)) in ('1', '1.1', '1.2') then nvl(MAX(o.cat_automatica),1) when e.cat_riesgo = 1 and to_char(nvl(MAX(o.cat_automatica),1)) not in ('1', '1.1', '1.2') then 1.2 else null end) subcategoria,
       -- Requerimiento: CNFAIRUNO-3.
       -- Fecha: 22/09/2014.
       (SELECT MAX(bc.val_minimo) FROM ba_cod_referencias bc WHERE bc.dominio = 'GRU_ECO_BCP' AND bc.val_maximo = nvl(e.cod_gru_economico,0)) gru_eco_bcp
    from ge_cla_operaciones o, ge_clientes e, ba_personas p,
         ba_tip_documentos d, ba_oficinas n, ba_cod_referencias r1, ge_est_cuentas t,
         ba_usuarios u,  ba_oficinas f, ba_gru_oficinas g
    where o.cod_persona=e.cod_persona
    and e.cod_persona=p.cod_persona
    and p.cod_tip_documento=d.cod_tip_documento
    and e.cod_oficina=n.cod_oficina
    and r1.dominio='TIP_CLIENTE'
    and r1.val_minimo=nvl(e.tipo,'T')
    and e.cod_usu_oficial=u.cod_usuario
    and u.cod_oficina=f.cod_oficina
    and f.cod_gru_oficina=g.cod_gru_oficina(+)
    and t.cod_modulo=o.cod_modulo
    and t.cod_modalidad=o.cod_modalidad
    and t.estado=o.cod_estado
    group by o.cod_persona, p.nom_completo, d.abreviatura, p.nro_documento,
           e.cat_riesgo, fup_obt_categoria(e.cat_automatica,e.cat_subjetiva),e.cod_oficina,
           n.descripcion, e.cod_usu_oficial, u.nombre,g.descripcion,
           e.cat_subjetiva, e.cod_gru_economico,
           e.cat_gru_economico, e.cat_sistema, e.tot_deu_sistema, e.tot_deu_con_sistema,
           e.tipo, substr(r1.significado,1,40)
    order by o.cod_persona;


  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'prevision_res'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_fec_sist         DATE;
  v_fecha            VARCHAR2(8);

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
  ---
  v_gru_eco_bcp_1    sb_gru_eco_bcp_det.grupo%TYPE;
  v_gru_eco_bcp_2    sb_gru_eco_bcp_det.grupo%TYPE;
  v_gru_eco_bcp_3    sb_gru_eco_bcp_det.grupo%TYPE;
  v_gru_eco_bcp_4    sb_gru_eco_bcp_det.grupo%TYPE;
  v_gru_eco_bcp_5    sb_gru_eco_bcp_det.grupo%TYPE;
  v_grupo_eco_bcp    VARCHAR2(4000);

BEGIN
  -- Obtenemos la fecha del sistema
  select pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1)
  into v_fec_sist
  from dual;

  v_fecha := to_char(v_fec_sist,'DDMMYYYY');

-- Abrir archivo
v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'.txt','W',32767);

-- Colocar el titulo a los campos
v_linetit := 'RIESGO'||CHR(9)||'NOMBRE_PER'||CHR(9)||'DOC'||CHR(9)||'NRO_DOC'||CHR(9)||'CAT_RIESGO'||CHR(9)||
             'CAT_CRC'||CHR(9)||'OFI'||CHR(9)||'OFICINA'||CHR(9)||'COD_USU_OFICIAL'||CHR(9)||'NOMBRE_USU'||CHR(9)||
             'BANCA'||CHR(9)||'CAT_SUBJETIVA'||CHR(9)||'GRU_ECO'||CHR(9)||'GRU_ECO_BCP'||CHR(9)||'CAT_GRU_ECONOMICO'||CHR(9)||
             'GRU_ECO_BCP_1'||CHR(9)||'GRU_ECO_BCP_2'||CHR(9)||'GRU_ECO_BCP_3'||CHR(9)||
             'GRU_ECO_BCP_4'||CHR(9)||'GRU_ECO_BCP_5'||CHR(9)||'GRUPO_ECO_BCP'||CHR(9)||--CNF-GRU_ECO_BCP
             'CAT_SISTEMA'||CHR(9)||'TIPO'||CHR(9)||'TIP_CLIENTE'||CHR(9)||'TOT_DEU_RSISTEMA'||CHR(9)||
             'TOT_CON_RSISTEMA'||CHR(9)||'TOT_DEU_REAL'||CHR(9)||'TOT_DEU_CONTINGENTE'||CHR(9)||
             'DEV_NO_COBRADO'||CHR(9)||'TOT_GAR_COMPUTABLES'||CHR(9)||'TOT_PREVISION'||CHR(9)||'SUBCATEGORIA';

utl_file.put_line(v_file,v_linetit);

-- Definir una linea en blanco para separar los datos del titulo de los campos
v_linetit := ' ';
utl_file.put_line(v_file,v_linetit);

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN cu_prevision_res LOOP
  prs_obt_gru_eco_bcp(rec.doc, rec.nro_doc, v_gru_eco_bcp_1, v_gru_eco_bcp_2, v_gru_eco_bcp_3, v_gru_eco_bcp_4, v_gru_eco_bcp_5, v_grupo_eco_bcp);--CNF-GRU_ECO_BCP
  --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
  v_line := to_char(rec.RIESGO)||chr(9)||to_char(rec.NOMBRE_PER)||chr(9)||to_char(rec.DOC)||chr(9)||to_char(rec.NRO_DOC)||chr(9)||
            to_char(rec.CAT_RIESGO)||chr(9)||to_char(rec.CAT_CRC)||chr(9)||to_char(rec.OFI)||chr(9)||to_char(rec.OFICINA)||chr(9)||
            to_char(rec.COD_USU_OFICIAL)||chr(9)||to_char(rec.NOMBRE_USU)||chr(9)||to_char(rec.BANCA)||chr(9)||to_char(rec.CAT_SUBJETIVA)||chr(9)||
            to_char(rec.GRU_ECO)||chr(9)||to_char(rec.GRU_ECO_BCP)||chr(9)||to_char(rec.CAT_GRU_ECONOMICO)||chr(9)||
            to_char(nvl(v_gru_eco_bcp_1,' '))||chr(9)||to_char(nvl(v_gru_eco_bcp_2,' '))||chr(9)||to_char(nvl(v_gru_eco_bcp_3,' '))||chr(9)||
            to_char(nvl(v_gru_eco_bcp_4,' '))||chr(9)||to_char(nvl(v_gru_eco_bcp_5,' '))||chr(9)||to_char(nvl(v_grupo_eco_bcp,' '))||chr(9)||
            to_char(rec.CAT_SISTEMA)||chr(9)||
            to_char(rec.TIPO)||chr(9)||to_char(rec.TIP_CLIENTE)||chr(9)||to_char(rec.TOT_DEU_RSISTEMA,'999999999999D00')||chr(9)||
            to_char(rec.TOT_CON_RSISTEMA,'999999999999D00')||chr(9)||to_char(rec.TOT_DEU_REAL,'999999999999D00')||chr(9)||
            to_char(rec.TOT_DEU_CONTINGENTE,'999999999999D00')||chr(9)||to_char(rec.DEV_NO_COBRADO,'999999999999D00')||chr(9)||
            to_char(rec.TOT_GAR_COMPUTABLES,'999999999999D00')||chr(9)||to_char(rec.TOT_PREVISION,'999999999999D00')||chr(9)||
            to_char(rec.SUBCATEGORIA);

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

   EXIT WHEN cu_prevision_res%NOTFOUND;
END LOOP;
--Escribes la linea en el fichero
UTL_FILE.PUT_LINE(v_file, v_buffer);

--Cerrar el handler al fichero
UTL_FILE.FCLOSE(v_file);
COMMIT;

  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_respuesta := pa_file_ftp.fu_put_ascii(pa_rpc_aut.g_ip, pa_rpc_aut.g_port, pa_rpc_aut.g_user,
                                          pa_rpc_aut.g_pass, pa_rpc_aut.g_repository,
                                          v_name||'.txt', g_riesgos||v_name||'_'||v_fecha||'.txt');

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','PREVISION_RESUMEN');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte Previsiones Específicas Resumen a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_riesgos||'

    Nombre del Archivo: '||v_name||'_'||v_fecha||'.txt';

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error    := null;

    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, v_name||'_'||v_fecha||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;

    --Enviamos el mail a soporte
     -- Obtenemos direccion de correo de soporte
     v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error Reporte Previsiones Específicas Resumen a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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
    RAISE_APPLICATION_ERROR(-20062,'Manejador invalido');
  WHEN UTL_FILE.WRITE_ERROR THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20063,'Error de escritura '||sqlerrm);
  WHEN UTL_FILE.INVALID_MODE THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20064,'Modo invalido');
  WHEN UTL_FILE.INTERNAL_ERROR THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20065,'Internal Error');
END pr_previ_res;
-------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------
-- Diferencias Bacht del cierre
PROCEDURE pr_bacht_cierre
IS
CURSOR cu_bacht_cierre(p_fecha DATE) IS
    select fecha,
       tip_control,
       clave,
       cod_modalidad,
       observacion,
       usu_insercion,
       fec_insercion
      from tm_log_controles t
    where t.tip_control like '%DIF%BAT%LIN%'
          and t.fecha = p_fecha
    order by 3;

  v_name             VARCHAR2(128) := 'dif_bacht_cierre'; -- nombre del archivo
  v_flag             BOOLEAN;

  -- Variables de fechas
  v_fec_sist         DATE;
  v_fecha            VARCHAR2(8);

  -- Variables para mail
  v_conn             utl_smtp.connection;
  v_para             VARCHAR2(500);
  v_asunto           VARCHAR2(2000);
  v_mje_mail         VARCHAR2(4000);
  v_cabecera         VARCHAR2(32767);
  v_detalle          VARCHAR2(32767);
  v_hini_mail        ge_ra_log_mail.hor_inicio%type;
  v_hfin_mail        ge_ra_log_mail.hor_fin%type;
  v_det_error        ge_ra_log_mail.det_error%type;

BEGIN
  -- Obtenemos la fecha del sistema
  select pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1)
  into v_fec_sist
  from dual;

  v_fecha := to_char(v_fec_sist,'DDMMYYYY');

  -- obtenemos los mail que van a recibir el reporte
  v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','DIF_BACHT_CIERRE');

  --

  v_det_error   := null;
  v_hini_mail   := null;
  v_hfin_mail   := null;
  v_asunto      := null;
  v_flag        := FALSE;

  -- Empezamos a cargar los datos del mail a enviar
  v_hini_mail := to_char(sysdate,'hh24:mi:ss');
  --
  v_asunto := 'Reporte Diferencias Bacht del cierre a la fecha '||v_fec_sist||'.';
  v_mje_mail := 'El archivo '||v_name||'_'||v_fecha||'.txt con los datos del reporte se encuentra adjunto en el mail.';

  begin
    --**
    v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
    it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
    it_mail.begin_attachment(v_conn,'text/plain',false,v_name||'_'||v_fecha||'.txt');
    --**
      -- Titulo del reporte
      -- Colocar el titulo a los campos
      v_cabecera := 'FECHA'||CHR(9)||'TIP_CONTROL'||CHR(9)||'CLAVE'||CHR(9)||'COD_MODALIDAD'||CHR(9)||
                    'OBSERVACION'||CHR(9)||'USU_INSERCION'||CHR(9)||'FEC_INSERCION'||CHR(13)||CHR(10);

      --** Arma el Archivo Anexo.
      it_mail.write_text(v_conn,v_cabecera);
      --**

      v_detalle := '';

      -- detalle del reporte
      FOR REC IN cu_bacht_cierre(v_fec_sist) LOOP
        v_flag := TRUE;
        --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
        v_detalle := to_char(rec.FECHA)||chr(9)||to_char(rec.TIP_CONTROL)||chr(9)||to_char(rec.CLAVE)||chr(9)||
                     to_char(rec.COD_MODALIDAD)||chr(9)||to_char(rec.OBSERVACION)||chr(9)||
                     to_char(rec.USU_INSERCION)||chr(9)||to_char(rec.FEC_INSERCION)||chr(13)||chr(10);

        --Escribir la linea en el archivo
        --**
        it_mail.write_text(v_conn,v_detalle);
        v_detalle := '';
        --**

        EXIT WHEN cu_bacht_cierre%NOTFOUND;
      END LOOP;
    --**
    -- Verificamos si el cursor trajo por lo menos un registro, de ser asi enviamos el mail
    IF v_flag THEN
       it_mail.end_mail(v_conn);
    ELSE
      ROLLBACK;
    END IF;
    --**
  exception
    when utl_smtp.transient_error or utl_smtp.permanent_error then
    begin
      utl_smtp.quit(v_conn);
    exception
    when utl_smtp.transient_error or utl_smtp.permanent_error then
      null;
    end;
    v_det_error := substr(sqlerrm,1,4000);
  end;

  --
  v_hfin_mail := to_char(sysdate,'hh24:mi:ss');

  -- Insertamos en la tabla de log  si ocurrio algun error al enviar el mail
      IF v_det_error is not null THEN
          INSERT INTO ge_ra_log_mail
           (fec_envio, nom_archivo, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
          VALUES
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;
COMMIT;
EXCEPTION
  WHEN OTHERS THEN
    raise_application_error(-20000,'Error al Generar Diferencias Bacht del cierre. '||sqlerrm);
END pr_bacht_cierre;
-------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------
-- Validación Diferencia de Posición
PROCEDURE pr_val_dif_posi
IS
CURSOR cu_val_dif_posi IS
    SELECT COD_MOD_PADRE,
       COD_MAD_PADRE, /* COD_OFI_ORIGEN,*/
       FECHA,
       COD_USUARIO,
       HORA,
       COD_MONEDA,
       SUM(DECODE(TIP_MOV_RUBRO, 'D', MONTO, 0)) "W_TOTDEBE",
       SUM(DECODE(TIP_MOV_RUBRO, 'C', MONTO, 0)) "W_TOTHABE"
    FROM GE_ASIENTOS_TMP A
    WHERE TIP_MOV_RUBRO IS NOT NULL
       AND SUBSTR(COD_RUBRO, 1, 1) IN ('1', '2')
       AND COD_MOD_PADRE <> 7
       AND NOT EXISTS (SELECT 0
              FROM LV_DET_BOL_CAMBIOS X
             WHERE X.COD_USUARIO = A.COD_USUARIO
               AND X.FECHA = A.FECHA
               AND X.HORA = A.HORA)
    GROUP BY COD_MOD_PADRE,
              COD_MAD_PADRE, /*COD_OFI_ORIGEN, */
              FECHA,
              COD_USUARIO,
              HORA,
              COD_MONEDA
    HAVING NVL(SUM(DECODE(TIP_MOV_RUBRO, 'D', MONTO, 0)), 0) <> NVL(SUM(DECODE(TIP_MOV_RUBRO, 'C', MONTO, 0)), 0);

  v_name             VARCHAR2(128) := 'valida_dif_posi'; -- nombre del archivo
  v_flag             BOOLEAN;

  -- Variables de fechas
  v_fec_sist         DATE;
  v_fecha            VARCHAR2(8);

  -- Variables para mail
  v_conn             utl_smtp.connection;
  v_para             VARCHAR2(500);
  v_asunto           VARCHAR2(2000);
  v_mje_mail         VARCHAR2(4000);
  v_cabecera         VARCHAR2(32767);
  v_detalle          VARCHAR2(32767);
  v_hini_mail        ge_ra_log_mail.hor_inicio%type;
  v_hfin_mail        ge_ra_log_mail.hor_fin%type;
  v_det_error        ge_ra_log_mail.det_error%type;

BEGIN
  -- Obtenemos la fecha del sistema
  select pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1)
  into v_fec_sist
  from dual;

  v_fecha := to_char(v_fec_sist,'DDMMYYYY');

  -- obtenemos los mail que van a recibir el reporte
  v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','VALIDA_DIF_POSICION');

  --

  v_det_error   := null;
  v_hini_mail   := null;
  v_hfin_mail   := null;
  v_asunto      := null;
  v_flag        := FALSE;

  -- Empezamos a cargar los datos del mail a enviar
  v_hini_mail := to_char(sysdate,'hh24:mi:ss');
  --
  v_asunto := 'Reporte Validación Diferencia de Posición a la fecha '||v_fec_sist||'.';
  v_mje_mail := 'El archivo '||v_name||'_'||v_fecha||'.txt con los datos del reporte se encuentra adjunto en el mail.';

  begin
    --**
    v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
    it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
    it_mail.begin_attachment(v_conn,'text/plain',false,v_name||'_'||v_fecha||'.txt');
    --**
      -- Titulo del reporte
      -- Colocar el titulo a los campos
      v_cabecera := 'COD_MOD_PADRE'||CHR(9)||'COD_MAD_PADRE'||CHR(9)||'FECHA'||CHR(9)||'COD_USUARIO'||CHR(9)||
                    'HORA'||CHR(9)||'COD_MONEDA'||CHR(9)||'W_TOTDEBE'||CHR(9)||'W_TOTHABE'||CHR(13)||CHR(10);

      --** Arma el Archivo Anexo.
      it_mail.write_text(v_conn,v_cabecera);
      --**

      v_detalle := '';

      -- detalle del reporte
      FOR REC IN cu_val_dif_posi LOOP
        v_flag := TRUE;
        --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
        v_detalle := to_char(rec.COD_MOD_PADRE)||chr(9)||to_char(rec.COD_MAD_PADRE)||chr(9)||to_char(rec.FECHA)||chr(9)||
                     to_char(rec.COD_USUARIO)||chr(9)||to_char(rec.HORA)||chr(9)||
                     to_char(rec.COD_MONEDA)||chr(9)||to_char(rec.W_TOTDEBE,'999999999999D00')||chr(9)||
                     to_char(rec.W_TOTHABE,'999999999999D00')||chr(13)||chr(10);

        --Escribir la linea en el archivo
        --**
        it_mail.write_text(v_conn,v_detalle);
        v_detalle := '';
        --**

        EXIT WHEN cu_val_dif_posi%NOTFOUND;
      END LOOP;
    --**
    -- Verificamos si el cursor trajo por lo menos un registro, de ser asi enviamos el mail
    IF v_flag THEN
       it_mail.end_mail(v_conn);
    ELSE
      ROLLBACK;
    END IF;
    --**
  exception
    when utl_smtp.transient_error or utl_smtp.permanent_error then
    begin
      utl_smtp.quit(v_conn);
    exception
    when utl_smtp.transient_error or utl_smtp.permanent_error then
      null;
    end;
    v_det_error := substr(sqlerrm,1,4000);
  end;

  --
  v_hfin_mail := to_char(sysdate,'hh24:mi:ss');

  -- Insertamos en la tabla de log  si ocurrio algun error al enviar el mail
      IF v_det_error is not null THEN
          INSERT INTO ge_ra_log_mail
           (fec_envio, nom_archivo, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
          VALUES
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;
COMMIT;
EXCEPTION
  WHEN OTHERS THEN
    raise_application_error(-20000,'Error al Generar Reporte Validación Diferencia de Posición. '||sqlerrm);
END pr_val_dif_posi;
-------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------
-- Saldos Contables Abierto HISTORICO - AS400
PROCEDURE pr_saldo_imp
IS
CURSOR cu_sal_abierto IS
    select '0'||substr(k.cod_rub_padre,1,5) bcp1, null col1,
       substr(k.cod_rub_externo,1,6)||'.'||substr(k.cod_rub_externo,7,5)||'.'||substr(k.cod_rub_externo,12,1) rub_as,
       null col2, k.Descripcion Descripcion,
       (nvl(s.sal_mon_rub_ant,0)+nvl(s.deb_mon_rubro,0)-nvl(s.cre_mon_rubro,0)) * -1 saldo_me,
       null col3,
       case when (nvl(s.sal_mon_loc_ant,0)+nvl(s.deb_mon_local,0)-nvl(s.cre_mon_local,0)) > 0 then
          abs(nvl(s.sal_mon_loc_ant,0)+nvl(s.deb_mon_local,0)-nvl(s.cre_mon_local,0)) else 0 end acum_deb_ml,
       case when (nvl(s.sal_mon_loc_ant,0)+nvl(s.deb_mon_local,0)-nvl(s.cre_mon_local,0)) < 0 then
          abs(nvl(s.sal_mon_loc_ant,0)+nvl(s.deb_mon_local,0)-nvl(s.cre_mon_local,0)) else 0 end acum_cre_ml,
       k.cod_rubro, k.cod_rub_externo, s.fecha, 'Balance Abierto' Tip_Balance
    from cb_sal_consolidados_dia s, cb_rubros k
    where s.cod_rubro = k.cod_rubro
    and k.imputable   = 'S'
    and s.fecha       = pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1)
    and abs(nvl(s.sal_mon_loc_ant,0)+nvl(s.deb_mon_local,0)-nvl(s.cre_mon_local,0)) <> 0
    order by 3;

  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'bal_abierto_his'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_fecha            VARCHAR2(8);
  v_hora             VARCHAR2(8);

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
  -- Obtenemos la fecha del sistema de cierre
  v_fecha := to_char(pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1),'YYYYMMDD');

  -- Obtenemos la hora de la base de datos
  v_hora := to_char(sysdate,'hh24miss');

-- Abrir archivo
v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'.txt','W',32767);

-- Colocar el titulo a los campos
v_linetit := 'BCP1'||CHR(9)||'COL1'||CHR(9)||'RUB_AS'||CHR(9)||'COL2'||CHR(9)||'DESCRIPCION'||CHR(9)||'SALDO_ME'||CHR(9)||
             'COL3'||CHR(9)||'ACUM_DEB_ML'||CHR(9)||'ACUM_CRE_ML'||CHR(9)||'COD_RUBRO'||CHR(9)||'COD_RUB_EXTERNO'||CHR(9)||
             'FECHA'||CHR(9)||'TIP_BALANCE';

utl_file.put_line(v_file,v_linetit);

-- Definir una linea en blanco para separar los datos del titulo de los campos
v_linetit := ' ';
utl_file.put_line(v_file,v_linetit);

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN cu_sal_abierto LOOP

    --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
  v_line := to_char(rec.BCP1)||chr(9)||to_char(rec.COL1)||chr(9)||to_char(rec.RUB_AS)||chr(9)||
             to_char(rec.COL2)||chr(9)||to_char(rec.DESCRIPCION)||chr(9)||to_char(rec.SALDO_ME,'999999999999999999999D00')||chr(9)||
            to_char(rec.COL3)||chr(9)||to_char(rec.ACUM_DEB_ML,'999999999999999999999D00')||chr(9)||
            to_char(rec.ACUM_CRE_ML,'999999999999999999999D00')||chr(9)||to_char(rec.COD_RUBRO)||chr(9)||
            to_char(rec.COD_RUB_EXTERNO)||chr(9)||to_char(rec.FECHA)||chr(9)||to_char(rec.TIP_BALANCE);


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

  EXIT WHEN cu_sal_abierto%NOTFOUND;
END LOOP;
--Escribes la linea en el fichero
UTL_FILE.PUT_LINE(v_file, v_buffer);

--Cerrar el handler al fichero
UTL_FILE.FCLOSE(v_file);
COMMIT;

  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_respuesta := pa_file_ftp.fu_put_ascii(pa_rpc_aut.g_ip, pa_rpc_aut.g_port, pa_rpc_aut.g_user,
                                          pa_rpc_aut.g_pass, pa_rpc_aut.g_repository,
                                          v_name||'.txt', g_balances||v_name||'_'||v_fecha||'_'||v_hora||'.txt');

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SALDO_IMPUTABLE');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte Balance Abierto Historico a la fecha '||v_fecha||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_balances||'

    Nombre del Archivo: '||v_name||'_'||v_fecha||'_'||v_hora||'.txt';

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'_'||v_hora||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error    := null;

    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, v_name||'_'||v_fecha||'_'||v_hora||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;

    --Enviamos el mail a soporte
     -- Obtenemos direccion de correo de soporte
     v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error Reporte Balance Abierto Historico a la fecha '||v_fecha||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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
END pr_saldo_imp;
-------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------
-- Saldos Contables Abierto por Sucursal HISTORICO - AS400
PROCEDURE pr_sal_cont_suc
IS
CURSOR cu_sal_abierto_suc IS
    select s.cod_oficina, '0'||substr(k.cod_rub_padre,1,5) bcp1, null col1,
       substr(k.cod_rub_externo,1,6)||'.'||substr(k.cod_rub_externo,7,5)||'.'||substr(k.cod_rub_externo,12,1) rub_as,
       null col2, k.Descripcion Descripcion,
       (nvl(s.sal_mon_rub_ant,0)+nvl(s.deb_mon_rubro,0)-nvl(s.cre_mon_rubro,0)) * -1 saldo_me,
       null col3,

       case when (nvl(s.sal_mon_loc_ant,0)+nvl(s.deb_mon_local,0)-nvl(s.cre_mon_local,0)) > 0 then
          abs(nvl(s.sal_mon_loc_ant,0)+nvl(s.deb_mon_local,0)-nvl(s.cre_mon_local,0)) else 0 end acum_deb_ml,

       case when (nvl(s.sal_mon_loc_ant,0)+nvl(s.deb_mon_local,0)-nvl(s.cre_mon_local,0)) < 0 then
          abs(nvl(s.sal_mon_loc_ant,0)+nvl(s.deb_mon_local,0)-nvl(s.cre_mon_local,0)) else 0 end acum_cre_ml,

       k.cod_rubro, k.cod_rub_externo, s.fecha, 'Balance Abierto x Sucursal' Tip_Balance

    from cb_sal_oficinas_dia s, cb_rubros k
    where s.cod_rubro   = k.cod_rubro
    and k.imputable     = 'S'
    and s.fecha         = pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1)
    and abs(nvl(s.sal_mon_loc_ant,0)+nvl(s.deb_mon_local,0)-nvl(s.cre_mon_local,0)) <> 0
    order by 1,4;

  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'bal_abierto_suc_his'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_fecha            VARCHAR2(8);
  v_hora             VARCHAR2(8);

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
  -- Obtenemos la fecha del sistema de cierre
  v_fecha := to_char(pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1),'YYYYMMDD');
--v_fecha := to_char(add_months(pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1),-1),'YYYYMMDD');

  -- Obtenemos la hora de la base de datos
  v_hora := to_char(sysdate,'hh24miss');

-- Abrir archivo
v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'.txt','W',32767);

-- Colocar el titulo a los campos
v_linetit := 'COD_OFICINA'||CHR(9)||'BCP1'||CHR(9)||'COL1'||CHR(9)||'RUB_AS'||CHR(9)||'COL2'||CHR(9)||
             'DESCRIPCION'||CHR(9)||'SALDO_ME'||CHR(9)||'COL3'||CHR(9)||'ACUM_DEB_ML'||CHR(9)||'ACUM_CRE_ML'||CHR(9)||
             'COD_RUBRO'||CHR(9)||'COD_RUB_EXTERNO'||CHR(9)||'FECHA'||CHR(9)||'TIP_BALANCE';

utl_file.put_line(v_file,v_linetit);

-- Definir una linea en blanco para separar los datos del titulo de los campos
v_linetit := ' ';
utl_file.put_line(v_file,v_linetit);

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN cu_sal_abierto_suc LOOP

    --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
  v_line := to_char(rec.COD_OFICINA)||chr(9)||to_char(rec.BCP1)||chr(9)||to_char(rec.COL1)||chr(9)||to_char(rec.RUB_AS)||chr(9)||
             to_char(rec.COL2)||chr(9)||to_char(rec.DESCRIPCION)||chr(9)||to_char(rec.SALDO_ME,'999999999999999999999D00')||chr(9)||
            to_char(rec.COL3)||chr(9)||to_char(rec.ACUM_DEB_ML,'999999999999999999999D00')||chr(9)||
            to_char(rec.ACUM_CRE_ML,'999999999999999999999D00')||chr(9)||to_char(rec.COD_RUBRO)||chr(9)||
            to_char(rec.COD_RUB_EXTERNO)||chr(9)||to_char(rec.FECHA)||chr(9)||to_char(rec.TIP_BALANCE);


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

  EXIT WHEN cu_sal_abierto_suc%NOTFOUND;
END LOOP;
--Escribes la linea en el fichero
UTL_FILE.PUT_LINE(v_file, v_buffer);

--Cerrar el handler al fichero
UTL_FILE.FCLOSE(v_file);
COMMIT;

  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_respuesta := pa_file_ftp.fu_put_ascii(pa_rpc_aut.g_ip, pa_rpc_aut.g_port, pa_rpc_aut.g_user,
                                          pa_rpc_aut.g_pass, pa_rpc_aut.g_repository,
                                          v_name||'.txt', g_balances||v_name||'_'||v_fecha||'_'||v_hora||'.txt');

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SALDO_IMPUTABLE_SUC');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte Balance Abierto Historico por Sucursal a la fecha '||v_fecha||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_balances||'

    Nombre del Archivo: '||v_name||'_'||v_fecha||'_'||v_hora||'.txt';

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'_'||v_hora||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error    := null;

    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, v_name||'_'||v_fecha||'_'||v_hora||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;

    --Enviamos el mail a soporte
     -- Obtenemos direccion de correo de soporte
     v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error Reporte Balance Abierto Historico por Sucursal a la fecha '||v_fecha||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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
END pr_sal_cont_suc;
-------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------
-- Saldos Contables Sin Signo HISTORICO - AS400
PROCEDURE pr_saldo_cont
IS
CURSOR cu_saldo_cont IS
   select '0'||substr(r.cod_rub_bcp,1,5) bcp1,
       case when substr(r.cod_rub_bcp,6,6) = '000000' then null
       else substr(r.cod_rub_bcp,6,6) end bcp2,
       '0'||substr(r.cod_rub_bcp,1,5)||substr(r.cod_rub_bcp,6,6) rubro_BCP,
       null col,
       k.Descripcion Descripcion,

       abs((nvl(s.sal_mon_loc_ant,0)+nvl(s.deb_mon_local,0)-nvl(s.cre_mon_local,0)) -
           (nvl(s.sal_equ_loc_ant,0)+nvl(s.deb_equ_local,0)-nvl(s.cre_equ_local,0))) Saldo_Guaranies,

       case when ((nvl(s.sal_mon_loc_ant,0)+nvl(s.deb_mon_local,0)-nvl(s.cre_mon_local,0)) -
                  (nvl(s.sal_equ_loc_ant,0)+nvl(s.deb_equ_local,0)-nvl(s.cre_equ_local,0))) < 0 then '+'
       when ((nvl(s.sal_mon_loc_ant,0)+nvl(s.deb_mon_local,0)-nvl(s.cre_mon_local,0)) -
             (nvl(s.sal_equ_loc_ant,0)+nvl(s.deb_equ_local,0)-nvl(s.cre_equ_local,0))) > 0 then '-'
       else null end signo_gs,

       abs(nvl(s.sal_mon_rub_ant,0)+nvl(s.deb_mon_rubro,0)-nvl(s.cre_mon_rubro,0)) Saldo_Rubro,

       case when (nvl(s.sal_mon_rub_ant,0)+nvl(s.deb_mon_rubro,0)-nvl(s.cre_mon_rubro,0)) < 0 then '+'
       when (nvl(s.sal_mon_rub_ant,0)+nvl(s.deb_mon_rubro,0)-nvl(s.cre_mon_rubro,0)) > 0 then '-'
       else null end signo_me,

       abs(nvl(s.sal_equ_loc_ant,0)+nvl(s.deb_equ_local,0)-nvl(s.cre_equ_local,0)) Saldo_Equivalente,

       case when (nvl(s.sal_equ_loc_ant,0)+nvl(s.deb_equ_local,0)-nvl(s.cre_equ_local,0)) < 0 then '+'
       when (nvl(s.sal_equ_loc_ant,0)+nvl(s.deb_equ_local,0)-nvl(s.cre_equ_local,0)) > 0 then '-'
       else null end signo_equiv,

       abs(nvl(s.sal_mon_loc_ant,0)+nvl(s.deb_mon_local,0)-nvl(s.cre_mon_local,0)) Saldo_Total,

       case when nvl(s.sal_mon_loc_ant,0)+nvl(s.deb_mon_local,0)-nvl(s.cre_mon_local,0) < 0 then '+'
       when nvl(s.sal_mon_loc_ant,0)+nvl(s.deb_mon_local,0)-nvl(s.cre_mon_local,0) > 0 then '-'
       else null end signo_Total, k.cod_rubro rubro_it, s.fecha, 'Balance Cerrado' Tip_Balance

    from cb_sal_consolidados_dia s, cb_rub_bcp r, cb_rubros k
    where r.cod_rub_bcp(+) = substr(s.cod_rubro,1,8)||substr(s.cod_rubro,3,1)||substr(s.cod_rubro,9,2)
    and s.cod_rubro        = k.cod_rubro
    and k.imputable        = 'N'
    and k.nivel            <= 5
    and s.fecha            = pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1)
    and abs(nvl(s.sal_mon_loc_ant,0)+nvl(s.deb_mon_local,0)-nvl(s.cre_mon_local,0)) <> 0
    and not exists(select 1 from cb_rubros t where substr(t.cod_rubro,9,2) = '01' and nivel = 5 and k.cod_rubro=t.cod_rub_padre)
    order by 1, r.cod_rub_bcp;

  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'bal_cerrado_his'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_fecha            VARCHAR2(8);
  v_hora             VARCHAR2(8);

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
  -- Obtenemos la fecha del sistema de cierre
  v_fecha := to_char(pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1),'YYYYMMDD');
--v_fecha := to_char(add_months(pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1),-1),'YYYYMMDD');

  -- Obtenemos la hora de la base de datos
  v_hora := to_char(sysdate,'hh24miss');

-- Abrir archivo
v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'.txt','W',32767);

-- Colocar el titulo a los campos
v_linetit := 'BCP1'||CHR(9)||'BCP2'||CHR(9)||'RUBRO_BCP'||CHR(9)||'COL'||CHR(9)||'DESCRIPCION'||CHR(9)||
             'SALDO_GUARANIES'||CHR(9)||'SIGNO_GS'||CHR(9)||
             'SALDO_RUBRO'||CHR(9)||'SIGNO_ME'||CHR(9)||'SALDO_EQUIVALENTE'||CHR(9)||'SIGNO_EQUIV'||CHR(9)||
             'SALDO_TOTAL'||CHR(9)||'SIGNO_TOTAL'||CHR(9)||'RUBRO_IT'||CHR(9)||'FECHA'||CHR(9)||'TIP_BALANCE';

utl_file.put_line(v_file,v_linetit);

-- Definir una linea en blanco para separar los datos del titulo de los campos
v_linetit := ' ';
utl_file.put_line(v_file,v_linetit);

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN cu_saldo_cont LOOP

    --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
  v_line := to_char(rec.BCP1)||chr(9)||to_char(rec.BCP2)||chr(9)||to_char(rec.RUBRO_BCP)||chr(9)||
             to_char(rec.COL)||chr(9)||to_char(rec.DESCRIPCION)||chr(9)||
            to_char(rec.SALDO_GUARANIES,'999999999999999999999D00')||chr(9)||to_char(rec.SIGNO_GS)||chr(9)||
            to_char(rec.SALDO_RUBRO,'999999999999999999999D00')||chr(9)||to_char(rec.SIGNO_ME)||chr(9)||
            to_char(rec.SALDO_EQUIVALENTE,'999999999999999999999D00')||chr(9)||to_char(rec.SIGNO_EQUIV)||chr(9)||
            to_char(rec.SALDO_TOTAL,'999999999999999999999D00')||chr(9)||to_char(rec.SIGNO_TOTAL)||chr(9)||
            to_char(rec.RUBRO_IT)||chr(9)||to_char(rec.FECHA)||chr(9)||to_char(rec.TIP_BALANCE);


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

  EXIT WHEN cu_saldo_cont%NOTFOUND;
END LOOP;
--Escribes la linea en el fichero
UTL_FILE.PUT_LINE(v_file, v_buffer);

--Cerrar el handler al fichero
UTL_FILE.FCLOSE(v_file);
COMMIT;

  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_respuesta := pa_file_ftp.fu_put_ascii(pa_rpc_aut.g_ip, pa_rpc_aut.g_port, pa_rpc_aut.g_user,
                                          pa_rpc_aut.g_pass, pa_rpc_aut.g_repository,
                                          v_name||'.txt', g_balances||v_name||'_'||v_fecha||'_'||v_hora||'.txt');

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SALDO_CONTABLE');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte Balance Cerrado Historico a la fecha '||v_fecha||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_balances||'

    Nombre del Archivo: '||v_name||'_'||v_fecha||'_'||v_hora||'.txt';

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'_'||v_hora||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error    := null;

    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, v_name||'_'||v_fecha||'_'||v_hora||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;

    --Enviamos el mail a soporte
     -- Obtenemos direccion de correo de soporte
     v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error Reporte Balance Cerrado Historico a la fecha '||v_fecha||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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
END pr_saldo_cont;
-------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------
-- Saldos Contables Con Signos HISTORICO - AS400
PROCEDURE pr_sal_no_signo
IS
CURSOR cu_sal_no_signo IS
    select '0'||substr(r.cod_rub_bcp,1,5) bcp1,
       case when substr(r.cod_rub_bcp,6,6) = '000000' then null
       else substr(r.cod_rub_bcp,6,6) end bcp2,
       k.Descripcion Descripcion,
       ((nvl(s.sal_mon_loc_ant,0)+nvl(s.deb_mon_local,0)-nvl(s.cre_mon_local,0)) -
        (nvl(s.sal_equ_loc_ant,0)+nvl(s.deb_equ_local,0)-nvl(s.cre_equ_local,0))) * -1 Saldo_Guaranies,
       (nvl(s.sal_mon_rub_ant,0)+nvl(s.deb_mon_rubro,0)-nvl(s.cre_mon_rubro,0)) * -1 Saldo_Rubro,
       (nvl(s.sal_equ_loc_ant,0)+nvl(s.deb_equ_local,0)-nvl(s.cre_equ_local,0)) * -1 Saldo_Equivalente,
       (nvl(s.sal_mon_loc_ant,0)+nvl(s.deb_mon_local,0)-nvl(s.cre_mon_local,0)) * -1 Saldo_Total,
       k.cod_rubro rubro_it,  s.fecha, 'Balance Cerrado Con Signo' Tip_Balance
    from cb_sal_consolidados_dia s, cb_rub_bcp r, cb_rubros k
    where r.cod_rub_bcp(+) = substr(s.cod_rubro,1,8)||substr(s.cod_rubro,3,1)||substr(s.cod_rubro,9,2)
    and s.cod_rubro        = k.cod_rubro
    and k.imputable        = 'N'
    and k.nivel            <= 5
    and s.fecha            = pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1)
    and abs(nvl(s.sal_mon_loc_ant,0)+nvl(s.deb_mon_local,0)-nvl(s.cre_mon_local,0)) <> 0
    and not exists(select 1 from cb_rubros t where substr(t.cod_rubro,9,2) = '01' and nivel = 5 and k.cod_rubro=t.cod_rub_padre)
    order by 1, r.cod_rub_bcp;

  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'bal_cerrado_consig_his'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_fecha            VARCHAR2(8);
  v_hora             VARCHAR2(8);

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
  -- Obtenemos la fecha del sistema de cierre
  v_fecha := to_char(pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1),'YYYYMMDD');
--v_fecha := to_char(add_months(pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1),-1),'YYYYMMDD');

  -- Obtenemos la hora de la base de datos
  v_hora := to_char(sysdate,'hh24miss');

-- Abrir archivo
v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'.txt','W',32767);

-- Colocar el titulo a los campos
v_linetit := 'BCP1'||CHR(9)||'BCP2'||CHR(9)||'DESCRIPCION'||CHR(9)||'SALDO_GUARANIES'||CHR(9)||'SALDO_RUBRO'||CHR(9)||
             'SALDO_EQUIVALENTE'||CHR(9)||'SALDO_TOTAL'||CHR(9)||'RUBRO_IT'||CHR(9)||'FECHA'||CHR(9)||'TIP_BALANCE';

utl_file.put_line(v_file,v_linetit);

-- Definir una linea en blanco para separar los datos del titulo de los campos
v_linetit := ' ';
utl_file.put_line(v_file,v_linetit);

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN cu_sal_no_signo LOOP

    --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
  v_line := to_char(rec.BCP1)||chr(9)||to_char(rec.BCP2)||chr(9)||to_char(rec.DESCRIPCION)||chr(9)||
             to_char(rec.SALDO_GUARANIES,'999999999999999999999D00')||chr(9)||to_char(rec.SALDO_RUBRO,'999999999999999999999D00')||chr(9)||
            to_char(rec.SALDO_EQUIVALENTE,'999999999999999999999D00')||chr(9)||to_char(rec.SALDO_TOTAL,'999999999999999999999D00')||chr(9)||
            to_char(rec.RUBRO_IT)||chr(9)||to_char(rec.FECHA)||chr(9)||to_char(rec.TIP_BALANCE);


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

  EXIT WHEN cu_sal_no_signo%NOTFOUND;
END LOOP;
--Escribes la linea en el fichero
UTL_FILE.PUT_LINE(v_file, v_buffer);

--Cerrar el handler al fichero
UTL_FILE.FCLOSE(v_file);
COMMIT;

  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_respuesta := pa_file_ftp.fu_put_ascii(pa_rpc_aut.g_ip, pa_rpc_aut.g_port, pa_rpc_aut.g_user,
                                          pa_rpc_aut.g_pass, pa_rpc_aut.g_repository,
                                          v_name||'.txt', g_balances||v_name||'_'||v_fecha||'_'||v_hora||'.txt');

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SALDO_SIN_SIGNO');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte Balance Cerrado Historico Con Signo a la fecha '||v_fecha||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_balances||'

    Nombre del Archivo: '||v_name||'_'||v_fecha||'_'||v_hora||'.txt';

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'_'||v_hora||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error    := null;

    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, v_name||'_'||v_fecha||'_'||v_hora||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;

    --Enviamos el mail a soporte
     -- Obtenemos direccion de correo de soporte
     v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error Reporte Balance Cerrado Historico Con Signo a la fecha '||v_fecha||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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
END pr_sal_no_signo;
-------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------
-- Saldos Contables Con Signos por Sucursal HISTORICO - AS400
PROCEDURE pr_sal_nosig_suc
IS
CURSOR cu_sal_no_signo IS
    select s.cod_oficina, '0'||substr(r.cod_rub_bcp,1,5) bcp1,
       case when substr(r.cod_rub_bcp,6,6) = '000000' then null
       else substr(r.cod_rub_bcp,6,6) end bcp2,
       k.Descripcion Descripcion,
       ((nvl(s.sal_mon_loc_ant,0)+nvl(s.deb_mon_local,0)-nvl(s.cre_mon_local,0)) -
        (nvl(s.sal_equ_loc_ant,0)+nvl(s.deb_equ_local,0)-nvl(s.cre_equ_local,0))) * -1 Saldo_Guaranies,
       (nvl(s.sal_mon_rub_ant,0)+nvl(s.deb_mon_rubro,0)-nvl(s.cre_mon_rubro,0)) * -1 Saldo_Rubro,
       (nvl(s.sal_equ_loc_ant,0)+nvl(s.deb_equ_local,0)-nvl(s.cre_equ_local,0)) * -1 Saldo_Equivalente,
       (nvl(s.sal_mon_loc_ant,0)+nvl(s.deb_mon_local,0)-nvl(s.cre_mon_local,0)) * -1 Saldo_Total,
       k.cod_rubro rubro_it,  s.fecha, 'Balance Cerrado Con Signo x Sucursal' Tip_Balance
    from cb_sal_oficinas_dia s, cb_rub_bcp r, cb_rubros k
    where r.cod_rub_bcp(+) = substr(s.cod_rubro,1,8)||substr(s.cod_rubro,3,1)||substr(s.cod_rubro,9,2)
    and s.cod_rubro        = k.cod_rubro
    and k.imputable        = 'N'
    and k.nivel            <= 5
    and s.fecha            = pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1)
    and abs(nvl(s.sal_mon_loc_ant,0)+nvl(s.deb_mon_local,0)-nvl(s.cre_mon_local,0)) <> 0
    and not exists(select 1 from cb_rubros t where substr(t.cod_rubro,9,2) = '01' and nivel = 5 and k.cod_rubro=t.cod_rub_padre)
    order by 1,2, r.cod_rub_bcp;

  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'bal_cerrado_consig_suc_his'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_fecha            VARCHAR2(8);
  v_hora             VARCHAR2(8);

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
  -- Obtenemos la fecha del sistema de cierre
  v_fecha := to_char(pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1),'YYYYMMDD');
--v_fecha := to_char(add_months(pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1),-1),'YYYYMMDD');

  -- Obtenemos la hora de la base de datos
  v_hora := to_char(sysdate,'hh24miss');

-- Abrir archivo
v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'.txt','W',32767);

-- Colocar el titulo a los campos
v_linetit := 'COD_OFICINA'||CHR(9)||'BCP1'||CHR(9)||'BCP2'||CHR(9)||'DESCRIPCION'||CHR(9)||'SALDO_GUARANIES'||CHR(9)||
             'SALDO_RUBRO'||CHR(9)||'SALDO_EQUIVALENTE'||CHR(9)||'SALDO_TOTAL'||CHR(9)||'RUBRO_IT'||CHR(9)||
             'FECHA'||CHR(9)||'TIP_BALANCE';

utl_file.put_line(v_file,v_linetit);

-- Definir una linea en blanco para separar los datos del titulo de los campos
v_linetit := ' ';
utl_file.put_line(v_file,v_linetit);

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN cu_sal_no_signo LOOP

    --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
  v_line := to_char(rec.COD_OFICINA)||chr(9)||to_char(rec.BCP1)||chr(9)||to_char(rec.BCP2)||chr(9)||to_char(rec.DESCRIPCION)||chr(9)||
             to_char(rec.SALDO_GUARANIES,'999999999999999999999D00')||chr(9)||to_char(rec.SALDO_RUBRO,'999999999999999999999D00')||chr(9)||
            to_char(rec.SALDO_EQUIVALENTE,'999999999999999999999D00')||chr(9)||to_char(rec.SALDO_TOTAL,'999999999999999999999D00')||chr(9)||
            to_char(rec.RUBRO_IT)||chr(9)||to_char(rec.FECHA)||chr(9)||to_char(rec.TIP_BALANCE);


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

  EXIT WHEN cu_sal_no_signo%NOTFOUND;
END LOOP;
--Escribes la linea en el fichero
UTL_FILE.PUT_LINE(v_file, v_buffer);

--Cerrar el handler al fichero
UTL_FILE.FCLOSE(v_file);
COMMIT;

  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_respuesta := pa_file_ftp.fu_put_ascii(pa_rpc_aut.g_ip, pa_rpc_aut.g_port, pa_rpc_aut.g_user,
                                          pa_rpc_aut.g_pass, pa_rpc_aut.g_repository,
                                          v_name||'.txt', g_balances||v_name||'_'||v_fecha||'_'||v_hora||'.txt');

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SALDO_SIN_SIGNO_SUC');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte Balance Cerrado Con Signo Historico por Sucursal a la fecha '||v_fecha||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_balances||'

    Nombre del Archivo: '||v_name||'_'||v_fecha||'_'||v_hora||'.txt';

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'_'||v_hora||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error    := null;

    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, v_name||'_'||v_fecha||'_'||v_hora||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;

    --Enviamos el mail a soporte
     -- Obtenemos direccion de correo de soporte
     v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error Reporte Balance Cerrado Con Signo Historico por Sucursal a la fecha '||v_fecha||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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
END pr_sal_nosig_suc;
-------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------
-- Procedimiento para obtener reportes de saldos contables de la AS400
PROCEDURE pr_bal_cerrado
IS
BEGIN
    BEGIN

      -- Saldos Contables Abierto HISTORICO - AS400
      pa_rpc_aut.pr_saldo_imp;
      commit;

      -- Saldos Contables Abierto por Sucursal HISTORICO - AS400
      pa_rpc_aut.pr_sal_cont_suc;
      commit;

      -- Saldos Contables Sin Signo HISTORICO - AS400
      pa_rpc_aut.pr_saldo_cont;
      commit;

      -- Saldos Contables Con Signos HISTORICO - AS400
      pa_rpc_aut.pr_sal_no_signo;
      commit;

      -- Saldos Contables Con Signos por Sucursal HISTORICO - AS400
      pa_rpc_aut.pr_sal_nosig_suc;
      commit;

    END;
END pr_bal_cerrado;
-------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------
-- Saldos Promedio Abierto - AS400
   PROCEDURE pr_prom_abi
IS
CURSOR cu_sal_proabi(p_anho VARCHAR2, p_mes VARCHAR2) IS
     select '0'||substr(k.cod_rub_padre,1,5) bcp1, null col1,
       substr(k.cod_rub_externo,1,6)||'.'||substr(k.cod_rub_externo,7,5)||'.'||substr(k.cod_rub_externo,12,1) rub_as,
       null col2, k.Descripcion Descripcion,
       sum(round((nvl(s.tot_acumulado,0)/s.can_dia_acumulado),0) * -1) saldo_me,
       null col3,

       case when sum(nvl(s.tot_acu_mon_local,0)/s.can_dia_acumulado) > 0 then
        abs(sum(round(((nvl(s.tot_acu_mon_local,0)/s.can_dia_acumulado)),0)))
         else 0 end acum_deb_ml,

       case when sum(nvl(s.tot_acu_mon_local,0)/s.can_dia_acumulado) < 0 then
           abs(sum(round(((nvl(s.tot_acu_mon_local,0)/s.can_dia_acumulado)),0))) else 0 end acum_cre_ml,

       k.cod_rubro, k.cod_rub_externo, s.mes, s.ano, 'Promedio Abierto' Tip_Balance,
       sum(round((nvl(s.tot_acumulado,0)/s.can_dia_acumulado),0)) saldo_me_IT,
       sum(round((nvl(s.tot_acu_mon_local,0)/s.can_dia_acumulado),0)) saldo_me_local
    from cb_sal_promedios s, cb_rubros k
    where s.cod_rubro   = k.cod_rubro
    and k.imputable     = 'S'
    and s.ano           = p_anho
    and s.mes           = p_mes
    and abs(nvl(s.tot_acu_mon_local,0)) <> 0
    group by '0'||substr(k.cod_rub_padre,1,5),
       substr(k.cod_rub_externo,1,6)||'.'||substr(k.cod_rub_externo,7,5)||'.'||substr(k.cod_rub_externo,12,1),
       null,k.Descripcion,k.cod_rubro, k.cod_rub_externo, s.mes, s.ano, 'Promedio Abierto'
    order by 3;

  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'promedio_abierto'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_anho             VARCHAR2(4);
  v_mes              VARCHAR2(2);
  v_hora             VARCHAR2(8);

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
  -- Obtenemos la fecha anterior
  -- anho
  v_anho  := to_char(add_months(pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1),-1),'YYYY');
  -- mes
  v_mes   := to_char(add_months(pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1),-1),'MM');

  -- Obtenemos la hora de la base de datos
  v_hora := to_char(sysdate,'hh24miss');

-- Abrir archivo
v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'.txt','W',32767);

-- Colocar el titulo a los campos
v_linetit := 'BCP1'||CHR(9)||'COL1'||CHR(9)||'RUB_AS'||CHR(9)||'COL2'||CHR(9)||'DESCRIPCION'||CHR(9)||'SALDO_ME'||CHR(9)||
             'COL3'||CHR(9)||'ACUM_DEB_ML'||CHR(9)||'ACUM_CRE_ML'||CHR(9)||'COD_RUBRO'||CHR(9)||'COD_RUB_EXTERNO'||CHR(9)||
             'MES'||CHR(9)||'ANO'||CHR(9)||'TIP_BALANCE';

utl_file.put_line(v_file,v_linetit);

-- Definir una linea en blanco para separar los datos del titulo de los campos
v_linetit := ' ';
utl_file.put_line(v_file,v_linetit);

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN cu_sal_proabi(v_anho, v_mes) LOOP

    --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
  v_line := to_char(rec.BCP1)||chr(9)||to_char(rec.COL1)||chr(9)||to_char(rec.RUB_AS)||chr(9)||
             to_char(rec.COL2)||chr(9)||to_char(rec.DESCRIPCION)||chr(9)||to_char(rec.SALDO_ME,'999999999999999999999D00')||chr(9)||
            to_char(rec.COL3)||chr(9)||to_char(rec.ACUM_DEB_ML,'999999999999999999999D00')||chr(9)||
            to_char(rec.ACUM_CRE_ML,'999999999999999999999D00')||chr(9)||to_char(rec.COD_RUBRO)||chr(9)||
            to_char(rec.COD_RUB_EXTERNO)||chr(9)||to_char(rec.MES)||chr(9)||to_char(rec.ANO)||chr(9)||
            to_char(rec.TIP_BALANCE);


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

  EXIT WHEN cu_sal_proabi%NOTFOUND;
END LOOP;
--Escribes la linea en el fichero
UTL_FILE.PUT_LINE(v_file, v_buffer);

--Cerrar el handler al fichero
UTL_FILE.FCLOSE(v_file);
COMMIT;

  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_respuesta := pa_file_ftp.fu_put_ascii(pa_rpc_aut.g_ip, pa_rpc_aut.g_port, pa_rpc_aut.g_user,
                                          pa_rpc_aut.g_pass, pa_rpc_aut.g_repository,
                                          v_name||'.txt', g_balances||v_name||'_'||v_anho||v_mes||'_'||v_hora||'.txt');

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','PROMEDIO_ABIERTO');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte Balance Saldos Promedio Abierto a la fecha '||v_anho||v_mes||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_balances||'

    Nombre del Archivo: '||v_name||'_'||v_anho||v_mes||'_'||v_hora||'.txt';

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_anho||v_mes||'_'||v_hora||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error    := null;

    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, v_name||'_'||v_anho||v_mes||'_'||v_hora||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;

    --Enviamos el mail a soporte
     -- Obtenemos direccion de correo de soporte
     v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error Reporte Balance Saldos Promedio Abierto a la fecha '||v_anho||v_mes||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_anho||v_mes||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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
END pr_prom_abi;
-------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------
-- Saldos Promedio Abierto por Sucursal - AS400
PROCEDURE pr_proabi_suc
IS
CURSOR cu_proabi_suc(p_anho VARCHAR2, p_mes VARCHAR2) IS
    select s.cod_oficina, '0'||substr(k.cod_rub_padre,1,5) bcp1, null col1,
       substr(k.cod_rub_externo,1,6)||'.'||substr(k.cod_rub_externo,7,5)||'.'||substr(k.cod_rub_externo,12,1) rub_as,
       null col2, k.Descripcion Descripcion,
       (round(((nvl(s.tot_acumulado,0))/s.can_dia_acumulado),0) * -1) saldo_me,
       null col3,

       case when ((nvl(s.tot_acu_mon_local,0))/s.can_dia_acumulado) > 0 then
          (round((abs((nvl(s.tot_acu_mon_local,0))/s.can_dia_acumulado)),0))
           else 0 end acum_deb_ml,

       case when ((nvl(s.tot_acu_mon_local,0))/s.can_dia_acumulado) < 0 then
          (round((abs((nvl(s.tot_acu_mon_local,0))/s.can_dia_acumulado)),0)) else 0 end acum_cre_ml,

       k.cod_rubro, k.cod_rub_externo, s.mes, s.ano, 'Promedio Abierto x Sucursal' Tip_Balance
    from cb_sal_promedios s, cb_rubros k
    where s.cod_rubro   = k.cod_rubro
    and k.imputable     = 'S'
    and s.ano           = p_anho
    and s.mes           = p_mes
    and abs(nvl(s.tot_acu_mon_local,0)) <> 0
    order by 1,3;

  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'prom_abierto_suc'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_anho             VARCHAR2(4);
  v_mes              VARCHAR2(2);
  v_hora             VARCHAR2(8);

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
  -- Obtenemos la fecha anterior
  -- anho
  v_anho  := to_char(add_months(pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1),-1),'YYYY');
  -- mes
  v_mes   := to_char(add_months(pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1),-1),'MM');

  -- Obtenemos la hora de la base de datos
  v_hora := to_char(sysdate,'hh24miss');

-- Abrir archivo
v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'.txt','W',32767);

-- Colocar el titulo a los campos
v_linetit := 'COD_OFICINA'||CHR(9)||'BCP1'||CHR(9)||'COL1'||CHR(9)||'RUB_AS'||CHR(9)||'COL2'||CHR(9)||'DESCRIPCION'||CHR(9)||
             'SALDO_ME'||CHR(9)||'COL3'||CHR(9)||'ACUM_DEB_ML'||CHR(9)||'ACUM_CRE_ML'||CHR(9)||
             'COD_RUBRO'||CHR(9)||'COD_RUB_EXTERNO'||CHR(9)||'MES'||CHR(9)||'ANO'||CHR(9)||'TIP_BALANCE';

utl_file.put_line(v_file,v_linetit);

-- Definir una linea en blanco para separar los datos del titulo de los campos
v_linetit := ' ';
utl_file.put_line(v_file,v_linetit);

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN cu_proabi_suc(v_anho, v_mes) LOOP

    --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
  v_line := to_char(rec.COD_OFICINA)||chr(9)||to_char(rec.BCP1)||chr(9)||to_char(rec.COL1)||chr(9)||to_char(rec.RUB_AS)||chr(9)||
             to_char(rec.COL2)||chr(9)||to_char(rec.DESCRIPCION)||chr(9)||to_char(rec.SALDO_ME,'999999999999999999999D00')||chr(9)||
            to_char(rec.COL3)||chr(9)||to_char(rec.ACUM_DEB_ML,'999999999999999999999D00')||chr(9)||
            to_char(rec.ACUM_CRE_ML,'999999999999999999999D00')||chr(9)||to_char(rec.COD_RUBRO)||chr(9)||
            to_char(rec.COD_RUB_EXTERNO)||chr(9)||to_char(rec.MES)||chr(9)||to_char(rec.ANO)||chr(9)||
            to_char(rec.TIP_BALANCE);


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

  EXIT WHEN cu_proabi_suc%NOTFOUND;
END LOOP;
--Escribes la linea en el fichero
UTL_FILE.PUT_LINE(v_file, v_buffer);

--Cerrar el handler al fichero
UTL_FILE.FCLOSE(v_file);
COMMIT;

  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_respuesta := pa_file_ftp.fu_put_ascii(pa_rpc_aut.g_ip, pa_rpc_aut.g_port, pa_rpc_aut.g_user,
                                          pa_rpc_aut.g_pass, pa_rpc_aut.g_repository,
                                          v_name||'.txt', g_balances||v_name||'_'||v_anho||v_mes||'_'||v_hora||'.txt');

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','PROMEDIO_ABIERTO_SUC');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte Balance Saldos Promedio Abierto por Sucursal a la fecha '||v_anho||v_mes||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_balances||'

    Nombre del Archivo: '||v_name||'_'||v_anho||v_mes||'_'||v_hora||'.txt';

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_anho||v_mes||'_'||v_hora||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error    := null;

    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, v_name||'_'||v_anho||v_mes||'_'||v_hora||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;

    --Enviamos el mail a soporte
     -- Obtenemos direccion de correo de soporte
     v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error Reporte Balance Saldos Promedio Abierto por Sucursal a la fecha '||v_anho||v_mes||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_anho||v_mes||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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
END pr_proabi_suc;
-------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------
-- Saldos Promedio Cerrado - AS400
PROCEDURE pr_prom_cerra
IS
CURSOR cu_prom_cer(p_anho VARCHAR2, p_mes VARCHAR2) IS
    select '0'||substr(r.cod_rub_bcp,1,5) bcp1,
       case when substr(r.cod_rub_bcp,6,6) = '000000' then null
       else substr(r.cod_rub_bcp,6,6) end bcp2,
       k.Descripcion Descripcion,

       sum(round((((nvl(s.tot_acu_mon_local,0)) -
        (nvl(s.tot_acu_equ_local,0)))/s.can_dia_acumulado),0)) * -1 Saldo_Guaranies,
       sum(round(((nvl(s.tot_acumulado,0))/s.can_dia_acumulado),0)) * -1 Saldo_Rubro,
       sum(round(((nvl(s.tot_acu_equ_local,0))/s.can_dia_acumulado),0)) * -1 Saldo_Equivalente,
       sum(round(((nvl(s.tot_acu_mon_local,0))/s.can_dia_acumulado),0)) * -1 Saldo_Total,
       k.cod_rubro rubro_it,  s.mes, s.ano, 'Promedio Cerrado Con Signo' Tip_Balance
    from cb_sal_promedios s, cb_rub_bcp r, cb_rubros k
    where r.cod_rub_bcp(+) = substr(s.cod_rubro,1,8)||substr(s.cod_rubro,3,1)||substr(s.cod_rubro,9,2)
    and s.cod_rubro        = k.cod_rubro
    and k.imputable        = 'N'
    and k.nivel            <= 5
    and s.ano              = p_anho
    and s.mes              = p_mes
    and abs(nvl(s.tot_acu_mon_local,0)) <> 0
    and not exists(select 1 from cb_rubros t where substr(t.cod_rubro,9,2) = '01' and nivel = 5 and k.cod_rubro=t.cod_rub_padre)
    group by '0'||substr(r.cod_rub_bcp,1,5),
       case when substr(r.cod_rub_bcp,6,6) = '000000' then null
       else substr(r.cod_rub_bcp,6,6) end,
       k.Descripcion,
       k.cod_rubro,  s.mes, s.ano, 'Promedio Cerrado Con Signo'
    order by 1, 2;

  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'promedio_cerrado'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_anho             VARCHAR2(4);
  v_mes              VARCHAR2(2);
  v_hora             VARCHAR2(8);

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
  -- Obtenemos la fecha anterior
  -- anho
  v_anho  := to_char(add_months(pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1),-1),'YYYY');
  -- mes
  v_mes   := to_char(add_months(pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1),-1),'MM');

  -- Obtenemos la hora de la base de datos
  v_hora := to_char(sysdate,'hh24miss');

-- Abrir archivo
v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'.txt','W',32767);

-- Colocar el titulo a los campos
v_linetit := 'BCP1'||CHR(9)||'BCP2'||CHR(9)||'DESCRIPCION'||CHR(9)||'SALDO_GUARANIES'||CHR(9)||
             'SALDO_RUBRO'||CHR(9)||'SALDO_EQUIVALENTE'||CHR(9)||'SALDO_TOTAL'||CHR(9)||'RUBRO_IT'||CHR(9)||
             'MES'||CHR(9)||'ANO'||CHR(9)||'TIP_BALANCE';

utl_file.put_line(v_file,v_linetit);

-- Definir una linea en blanco para separar los datos del titulo de los campos
v_linetit := ' ';
utl_file.put_line(v_file,v_linetit);

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN cu_prom_cer(v_anho, v_mes) LOOP

    --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
  v_line := to_char(rec.BCP1)||chr(9)||to_char(rec.BCP2)||chr(9)||to_char(rec.DESCRIPCION)||chr(9)||
             to_char(rec.SALDO_GUARANIES,'999999999999999999999D00')||chr(9)||to_char(rec.SALDO_RUBRO,'999999999999999999999D00')||chr(9)||
            to_char(rec.SALDO_EQUIVALENTE,'999999999999999999999D00')||chr(9)||to_char(rec.SALDO_TOTAL,'999999999999999999999D00')||chr(9)||
            to_char(rec.RUBRO_IT)||chr(9)||to_char(rec.MES)||chr(9)||to_char(rec.ANO)||chr(9)||
            to_char(rec.TIP_BALANCE);


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

  EXIT WHEN cu_prom_cer%NOTFOUND;
END LOOP;
--Escribes la linea en el fichero
UTL_FILE.PUT_LINE(v_file, v_buffer);

--Cerrar el handler al fichero
UTL_FILE.FCLOSE(v_file);
COMMIT;

  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_respuesta := pa_file_ftp.fu_put_ascii(pa_rpc_aut.g_ip, pa_rpc_aut.g_port, pa_rpc_aut.g_user,
                                          pa_rpc_aut.g_pass, pa_rpc_aut.g_repository,
                                          v_name||'.txt', g_balances||v_name||'_'||v_anho||v_mes||'_'||v_hora||'.txt');

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','PROMEDIO_CERRADO');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte Balance Saldos Promedio Cerrado a la fecha '||v_anho||v_mes||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_balances||'

    Nombre del Archivo: '||v_name||'_'||v_anho||v_mes||'_'||v_hora||'.txt';

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_anho||v_mes||'_'||v_hora||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error    := null;

    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, v_name||'_'||v_anho||v_mes||'_'||v_hora||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;

    --Enviamos el mail a soporte
     -- Obtenemos direccion de correo de soporte
     v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error Reporte Balance Saldos Promedio Cerrado a la fecha '||v_anho||v_mes||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_anho||v_mes||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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
END pr_prom_cerra;
-------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------
-- Saldos Promedio Cerrado por Sucursal - AS400
PROCEDURE pr_procer_suc
IS
CURSOR cu_procer_suc(p_anho VARCHAR2, p_mes VARCHAR2) IS
    select s.cod_oficina, '0'||substr(r.cod_rub_bcp,1,5) bcp1,
       case when substr(r.cod_rub_bcp,6,6) = '000000' then null
       else substr(r.cod_rub_bcp,6,6) end bcp2,
       k.Descripcion Descripcion,

       sum(round((((nvl(s.tot_acu_mon_local,0)) -
        (nvl(s.tot_acu_equ_local,0)))/s.can_dia_acumulado),0)) * -1 Saldo_Guaranies,
       sum(round(((nvl(s.tot_acumulado,0))/s.can_dia_acumulado),0)) * -1 Saldo_Rubro,
       sum(round(((nvl(s.tot_acu_equ_local,0))/s.can_dia_acumulado),0)) * -1 Saldo_Equivalente,
       sum(round(((nvl(s.tot_acu_mon_local,0))/s.can_dia_acumulado),0)) * -1 Saldo_Total,
       k.cod_rubro rubro_it,  s.mes, s.ano, 'Promedio Cerrado Con Signo x Sucursal' Tip_Balance

    from cb_sal_promedios s, cb_rub_bcp r, cb_rubros k
    where r.cod_rub_bcp(+) = substr(s.cod_rubro,1,8)||substr(s.cod_rubro,3,1)||substr(s.cod_rubro,9,2)
    and s.cod_rubro   = k.cod_rubro
    and k.imputable   = 'N'
    and k.nivel       <= 5
    and s.ano         = p_anho
    and s.mes         = p_mes
    and abs(nvl(s.tot_acu_mon_local,0)) <> 0
    and not exists(select 1 from cb_rubros t where substr(t.cod_rubro,9,2) = '01' and nivel = 5 and k.cod_rubro=t.cod_rub_padre)
    group by s.cod_oficina, '0'||substr(r.cod_rub_bcp,1,5),
       case when substr(r.cod_rub_bcp,6,6) = '000000' then null
       else substr(r.cod_rub_bcp,6,6) end,
       k.Descripcion,
       k.cod_rubro,  s.mes, s.ano, 'Promedio Cerrado Con Signo x Sucursal'
    order by 1, 2, 3;

  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'prom_cerrado_suc'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_anho             VARCHAR2(4);
  v_mes              VARCHAR2(2);
  v_hora             VARCHAR2(8);

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
  -- Obtenemos la fecha anterior
  -- anho
  v_anho  := to_char(add_months(pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1),-1),'YYYY');
  -- mes
  v_mes   := to_char(add_months(pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1),-1),'MM');

  -- Obtenemos la hora de la base de datos
  v_hora := to_char(sysdate,'hh24miss');

-- Abrir archivo
v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'.txt','W',32767);

-- Colocar el titulo a los campos
v_linetit := 'COD_OFICINA'||CHR(9)||'BCP1'||CHR(9)||'BCP2'||CHR(9)||'DESCRIPCION'||CHR(9)||'SALDO_GUARANIES'||CHR(9)||
             'SALDO_RUBRO'||CHR(9)||'SALDO_EQUIVALENTE'||CHR(9)||'SALDO_TOTAL'||CHR(9)||'RUBRO_IT'||CHR(9)||
             'MES'||CHR(9)||'ANO'||CHR(9)||'TIP_BALANCE';

utl_file.put_line(v_file,v_linetit);

-- Definir una linea en blanco para separar los datos del titulo de los campos
v_linetit := ' ';
utl_file.put_line(v_file,v_linetit);

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN cu_procer_suc(v_anho, v_mes) LOOP

    --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
  v_line := to_char(rec.COD_OFICINA)||chr(9)||to_char(rec.BCP1)||chr(9)||to_char(rec.BCP2)||chr(9)||to_char(rec.DESCRIPCION)||chr(9)||
             to_char(rec.SALDO_GUARANIES,'999999999999999999999D00')||chr(9)||to_char(rec.SALDO_RUBRO,'999999999999999999999D00')||chr(9)||
            to_char(rec.SALDO_EQUIVALENTE,'999999999999999999999D00')||chr(9)||to_char(rec.SALDO_TOTAL,'999999999999999999999D00')||chr(9)||
            to_char(rec.RUBRO_IT)||chr(9)||to_char(rec.MES)||chr(9)||to_char(rec.ANO)||chr(9)||
            to_char(rec.TIP_BALANCE);


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

  EXIT WHEN cu_procer_suc%NOTFOUND;
END LOOP;
--Escribes la linea en el fichero
UTL_FILE.PUT_LINE(v_file, v_buffer);

--Cerrar el handler al fichero
UTL_FILE.FCLOSE(v_file);
COMMIT;

  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_respuesta := pa_file_ftp.fu_put_ascii(pa_rpc_aut.g_ip, pa_rpc_aut.g_port, pa_rpc_aut.g_user,
                                          pa_rpc_aut.g_pass, pa_rpc_aut.g_repository,
                                          v_name||'.txt', g_balances||v_name||'_'||v_anho||v_mes||'_'||v_hora||'.txt');

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','PROMEDIO_CERRADO_SUC');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte Balance Saldos Promedio Cerrado por Sucursal a la fecha '||v_anho||v_mes||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_balances||'

    Nombre del Archivo: '||v_name||'_'||v_anho||v_mes||'_'||v_hora||'.txt';

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_anho||v_mes||'_'||v_hora||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error    := null;

    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, v_name||'_'||v_anho||v_mes||'_'||v_hora||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;

    --Enviamos el mail a soporte
     -- Obtenemos direccion de correo de soporte
     v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error Reporte Balance Saldos Promedio Cerrado por Sucursal a la fecha '||v_anho||v_mes||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_anho||v_mes||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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
END pr_procer_suc;
-------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------
-- Procedimiento para obtener reportes de saldos de promedio de la AS400
PROCEDURE pr_bal_promedio
IS
BEGIN
    BEGIN

      -- Saldos Promedio Abierto - AS400
      pa_rpc_aut.pr_prom_abi;
      commit;

      -- Saldos Promedio Abierto por Sucursal - AS400
      pa_rpc_aut.pr_proabi_suc;
      commit;

      -- Saldos Promedio Cerrado - AS400
      pa_rpc_aut.pr_prom_cerra;
      commit;

      -- Saldos Promedio Cerrado por Sucursal - AS400
      pa_rpc_aut.pr_procer_suc;
      commit;

    END;
END pr_bal_promedio;
-------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------
-- Saldos Contables Abierto - AS400
PROCEDURE pr_bal_abierto
IS
CURSOR cu_sal_abi IS
    select '0'||substr(k.cod_rub_padre,1,5) bcp1, null col1,
       substr(k.cod_rub_externo,1,6)||'.'||substr(k.cod_rub_externo,7,5)||'.'||substr(k.cod_rub_externo,12,1) rub_as,
       null col2, k.Descripcion Descripcion,
       (nvl(s.sal_mon_rub_ant,0)+nvl(s.deb_mon_rubro,0)-nvl(s.cre_mon_rubro,0)) * -1 saldo_me,
       null col3,

       case when (nvl(s.sal_mon_loc_ant,0)+nvl(s.deb_mon_local,0)-nvl(s.cre_mon_local,0)) > 0 then
          abs(nvl(s.sal_mon_loc_ant,0)+nvl(s.deb_mon_local,0)-nvl(s.cre_mon_local,0)) else 0 end acum_deb_ml,

       case when (nvl(s.sal_mon_loc_ant,0)+nvl(s.deb_mon_local,0)-nvl(s.cre_mon_local,0)) < 0 then
          abs(nvl(s.sal_mon_loc_ant,0)+nvl(s.deb_mon_local,0)-nvl(s.cre_mon_local,0)) else 0 end acum_cre_ml,

       k.cod_rubro, k.cod_rub_externo, 'Balance Abierto' Tip_Balance
    from cb_sal_consolidados s, cb_rubros k
    where s.cod_rubro   = k.cod_rubro
    and k.imputable     = 'S'
    and abs(nvl(s.sal_mon_loc_ant,0)+nvl(s.deb_mon_local,0)-nvl(s.cre_mon_local,0)) <> 0
    order by 3;

  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'bal_abierto'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_fecha            VARCHAR2(8);
  v_hora             VARCHAR2(8);

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
  -- Obtenemos la fecha del sistema de contabilidad
  v_fecha := to_char(pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1),'YYYYMMDD');

  -- Obtenemos la hora de la base de datos
  v_hora := to_char(sysdate,'hh24miss');

-- Abrir archivo
v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'.txt','W',32767);

-- Colocar el titulo a los campos
v_linetit := 'BCP1'||CHR(9)||'COL1'||CHR(9)||'RUB_AS'||CHR(9)||'COL2'||CHR(9)||'DESCRIPCION'||CHR(9)||'SALDO_ME'||CHR(9)||
             'COL3'||CHR(9)||'ACUM_DEB_ML'||CHR(9)||'ACUM_CRE_ML'||CHR(9)||'COD_RUBRO'||CHR(9)||'COD_RUB_EXTERNO'||CHR(9)||
             'TIP_BALANCE';

utl_file.put_line(v_file,v_linetit);

-- Definir una linea en blanco para separar los datos del titulo de los campos
v_linetit := ' ';
utl_file.put_line(v_file,v_linetit);

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN cu_sal_abi LOOP

    --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
  v_line := to_char(rec.BCP1)||chr(9)||to_char(rec.COL1)||chr(9)||to_char(rec.RUB_AS)||chr(9)||
             to_char(rec.COL2)||chr(9)||to_char(rec.DESCRIPCION)||chr(9)||to_char(rec.SALDO_ME,'999999999999999999999D00')||chr(9)||
            to_char(rec.COL3)||chr(9)||to_char(rec.ACUM_DEB_ML,'999999999999999999999D00')||chr(9)||
            to_char(rec.ACUM_CRE_ML,'999999999999999999999D00')||chr(9)||to_char(rec.COD_RUBRO)||chr(9)||
            to_char(rec.COD_RUB_EXTERNO)||chr(9)||to_char(rec.TIP_BALANCE);


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

  EXIT WHEN cu_sal_abi%NOTFOUND;
END LOOP;
--Escribes la linea en el fichero
UTL_FILE.PUT_LINE(v_file, v_buffer);

--Cerrar el handler al fichero
UTL_FILE.FCLOSE(v_file);
COMMIT;

  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_respuesta := pa_file_ftp.fu_put_ascii(pa_rpc_aut.g_ip, pa_rpc_aut.g_port, pa_rpc_aut.g_user,
                                          pa_rpc_aut.g_pass, pa_rpc_aut.g_repository,
                                          v_name||'.txt', g_balances||v_name||'_'||v_fecha||'_'||v_hora||'.txt');

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','BALANCE_ABIERTO');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte Balance Abierto a la fecha '||v_fecha||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_balances||'

    Nombre del Archivo: '||v_name||'_'||v_fecha||'_'||v_hora||'.txt';

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'_'||v_hora||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error    := null;

    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, v_name||'_'||v_fecha||'_'||v_hora||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;

    --Enviamos el mail a soporte
     -- Obtenemos direccion de correo de soporte
     v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error Reporte Balance Abierto a la fecha '||v_fecha||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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
END pr_bal_abierto;
-------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------
-- Saldos Contables Abierto por Sucursal - AS400
PROCEDURE pr_bal_abi_suc
IS
CURSOR cu_bal_abierto_suc IS
    select s.cod_oficina, '0'||substr(k.cod_rub_padre,1,5) bcp1, null col1,
       substr(k.cod_rub_externo,1,6)||'.'||substr(k.cod_rub_externo,7,5)||'.'||substr(k.cod_rub_externo,12,1) rub_as,
       null col2, k.Descripcion Descripcion,
       (nvl(s.sal_mon_rub_ant,0)+nvl(s.deb_mon_rubro,0)-nvl(s.cre_mon_rubro,0)) * -1 saldo_me,
       null col3,

       case when (nvl(s.sal_mon_loc_ant,0)+nvl(s.deb_mon_local,0)-nvl(s.cre_mon_local,0)) > 0 then
          abs(nvl(s.sal_mon_loc_ant,0)+nvl(s.deb_mon_local,0)-nvl(s.cre_mon_local,0)) else 0 end acum_deb_ml,

       case when (nvl(s.sal_mon_loc_ant,0)+nvl(s.deb_mon_local,0)-nvl(s.cre_mon_local,0)) < 0 then
          abs(nvl(s.sal_mon_loc_ant,0)+nvl(s.deb_mon_local,0)-nvl(s.cre_mon_local,0)) else 0 end acum_cre_ml,

       k.cod_rubro, k.cod_rub_externo, 'Balance Abierto x Sucursal' Tip_Balance
    from cb_sal_oficinas s, cb_rubros k
    where s.cod_rubro = k.cod_rubro
    and k.imputable   = 'S'
    and abs(nvl(s.sal_mon_loc_ant,0)+nvl(s.deb_mon_local,0)-nvl(s.cre_mon_local,0)) <> 0
    order by 1,4;

  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'bal_abierto_suc'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_fecha            VARCHAR2(8);
  v_hora             VARCHAR2(8);

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
  -- Obtenemos la fecha del sistema de contabilidad
  v_fecha := to_char(pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1),'YYYYMMDD');

  -- Obtenemos la hora de la base de datos
  v_hora := to_char(sysdate,'hh24miss');

-- Abrir archivo
v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'.txt','W',32767);

-- Colocar el titulo a los campos
v_linetit := 'COD_OFICINA'||CHR(9)||'BCP1'||CHR(9)||'COL1'||CHR(9)||'RUB_AS'||CHR(9)||'COL2'||CHR(9)||
             'DESCRIPCION'||CHR(9)||'SALDO_ME'||CHR(9)||'COL3'||CHR(9)||'ACUM_DEB_ML'||CHR(9)||'ACUM_CRE_ML'||CHR(9)||
             'COD_RUBRO'||CHR(9)||'COD_RUB_EXTERNO'||CHR(9)||'TIP_BALANCE';

utl_file.put_line(v_file,v_linetit);

-- Definir una linea en blanco para separar los datos del titulo de los campos
v_linetit := ' ';
utl_file.put_line(v_file,v_linetit);

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN cu_bal_abierto_suc LOOP

    --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
  v_line := to_char(rec.COD_OFICINA)||chr(9)||to_char(rec.BCP1)||chr(9)||to_char(rec.COL1)||chr(9)||to_char(rec.RUB_AS)||chr(9)||
             to_char(rec.COL2)||chr(9)||to_char(rec.DESCRIPCION)||chr(9)||to_char(rec.SALDO_ME,'999999999999999999999D00')||chr(9)||
            to_char(rec.COL3)||chr(9)||to_char(rec.ACUM_DEB_ML,'999999999999999999999D00')||chr(9)||
            to_char(rec.ACUM_CRE_ML,'999999999999999999999D00')||chr(9)||to_char(rec.COD_RUBRO)||chr(9)||
            to_char(rec.COD_RUB_EXTERNO)||chr(9)||to_char(rec.TIP_BALANCE);


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

  EXIT WHEN cu_bal_abierto_suc%NOTFOUND;
END LOOP;
--Escribes la linea en el fichero
UTL_FILE.PUT_LINE(v_file, v_buffer);

--Cerrar el handler al fichero
UTL_FILE.FCLOSE(v_file);
COMMIT;

  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_respuesta := pa_file_ftp.fu_put_ascii(pa_rpc_aut.g_ip, pa_rpc_aut.g_port, pa_rpc_aut.g_user,
                                          pa_rpc_aut.g_pass, pa_rpc_aut.g_repository,
                                          v_name||'.txt', g_balances||v_name||'_'||v_fecha||'_'||v_hora||'.txt');

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','BALANCE_ABIERTO_SUC');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte Balance Abierto por Sucursal a la fecha '||v_fecha||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_balances||'

    Nombre del Archivo: '||v_name||'_'||v_fecha||'_'||v_hora||'.txt';

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'_'||v_hora||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error    := null;

    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, v_name||'_'||v_fecha||'_'||v_hora||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;

    --Enviamos el mail a soporte
     -- Obtenemos direccion de correo de soporte
     v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error Reporte Balance Abierto por Sucursal a la fecha '||v_fecha||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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
END pr_bal_abi_suc;
-------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------
-- Saldos Contables Con Signos - AS400
PROCEDURE pr_balcerra_sig
IS
CURSOR cu_balcerra_signo IS
    select '0'||substr(r.cod_rub_bcp,1,5) bcp1,
       case when substr(r.cod_rub_bcp,6,6) = '000000' then null
       else substr(r.cod_rub_bcp,6,6) end bcp2,
       k.Descripcion Descripcion,
       ((nvl(s.sal_mon_loc_ant,0)+nvl(s.deb_mon_local,0)-nvl(s.cre_mon_local,0)) -
        (nvl(s.sal_equ_loc_ant,0)+nvl(s.deb_equ_local,0)-nvl(s.cre_equ_local,0))) * -1 Saldo_Guaranies,
       (nvl(s.sal_mon_rub_ant,0)+nvl(s.deb_mon_rubro,0)-nvl(s.cre_mon_rubro,0)) * -1 Saldo_Rubro,
       (nvl(s.sal_equ_loc_ant,0)+nvl(s.deb_equ_local,0)-nvl(s.cre_equ_local,0)) * -1 Saldo_Equivalente,
       (nvl(s.sal_mon_loc_ant,0)+nvl(s.deb_mon_local,0)-nvl(s.cre_mon_local,0)) * -1 Saldo_Total,
       k.cod_rubro rubro_it, 'Balance Cerrado Con Signo' Tip_Balance
    from cb_sal_consolidados s, cb_rub_bcp r, cb_rubros k
    where r.cod_rub_bcp(+) = substr(s.cod_rubro,1,8)||substr(s.cod_rubro,3,1)||substr(s.cod_rubro,9,2)
    and s.cod_rubro        = k.cod_rubro
    and k.imputable        = 'N'
    and k.nivel            <= 5
    and abs(nvl(s.sal_mon_loc_ant,0)+nvl(s.deb_mon_local,0)-nvl(s.cre_mon_local,0)) <> 0
    and not exists(select 1 from cb_rubros t where substr(t.cod_rubro,9,2) = '01' and nivel = 5 and k.cod_rubro=t.cod_rub_padre)
    order by 1, r.cod_rub_bcp, k.nivel;

  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'bal_cerrado_consig'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_fecha            VARCHAR2(8);
  v_hora             VARCHAR2(8);

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
  -- Obtenemos la fecha del sistema de contabilidad
  v_fecha := to_char(pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1),'YYYYMMDD');

  -- Obtenemos la hora de la base de datos
  v_hora := to_char(sysdate,'hh24miss');

-- Abrir archivo
v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'.txt','W',32767);

-- Colocar el titulo a los campos
v_linetit := 'BCP1'||CHR(9)||'BCP2'||CHR(9)||'DESCRIPCION'||CHR(9)||'SALDO_GUARANIES'||CHR(9)||'SALDO_RUBRO'||CHR(9)||
             'SALDO_EQUIVALENTE'||CHR(9)||'SALDO_TOTAL'||CHR(9)||'RUBRO_IT'||CHR(9)||'TIP_BALANCE';

utl_file.put_line(v_file,v_linetit);

-- Definir una linea en blanco para separar los datos del titulo de los campos
v_linetit := ' ';
utl_file.put_line(v_file,v_linetit);

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN cu_balcerra_signo LOOP

    --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
  v_line := to_char(rec.BCP1)||chr(9)||to_char(rec.BCP2)||chr(9)||to_char(rec.DESCRIPCION)||chr(9)||
             to_char(rec.SALDO_GUARANIES,'999999999999999999999D00')||chr(9)||to_char(rec.SALDO_RUBRO,'999999999999999999999D00')||chr(9)||
            to_char(rec.SALDO_EQUIVALENTE,'999999999999999999999D00')||chr(9)||to_char(rec.SALDO_TOTAL,'999999999999999999999D00')||chr(9)||
            to_char(rec.RUBRO_IT)||chr(9)||to_char(rec.TIP_BALANCE);


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

  EXIT WHEN cu_balcerra_signo%NOTFOUND;
END LOOP;
--Escribes la linea en el fichero
UTL_FILE.PUT_LINE(v_file, v_buffer);

--Cerrar el handler al fichero
UTL_FILE.FCLOSE(v_file);
COMMIT;

  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_respuesta := pa_file_ftp.fu_put_ascii(pa_rpc_aut.g_ip, pa_rpc_aut.g_port, pa_rpc_aut.g_user,
                                          pa_rpc_aut.g_pass, pa_rpc_aut.g_repository,
                                          v_name||'.txt', g_balances||v_name||'_'||v_fecha||'_'||v_hora||'.txt');

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','BALANCE_CERRADO_SIG');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte Balance Cerrado con Signo a la fecha '||v_fecha||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_balances||'

    Nombre del Archivo: '||v_name||'_'||v_fecha||'_'||v_hora||'.txt';

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'_'||v_hora||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error    := null;

    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, v_name||'_'||v_fecha||'_'||v_hora||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;

    --Enviamos el mail a soporte
     -- Obtenemos direccion de correo de soporte
     v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error Reporte Balance Cerrado Con Signo a la fecha '||v_fecha||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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
END pr_balcerra_sig;
-------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------
-- Saldos Contables Con Signos por Sucursal - AS400
PROCEDURE pr_balce_sig_suc
IS
CURSOR cu_balce_sig_suc IS
      select s.cod_oficina, '0'||substr(r.cod_rub_bcp,1,5) bcp1,
         case when substr(r.cod_rub_bcp,6,6) = '000000' then null
         else substr(r.cod_rub_bcp,6,6) end bcp2,
         k.Descripcion Descripcion,
         ((nvl(s.sal_mon_loc_ant,0)+nvl(s.deb_mon_local,0)-nvl(s.cre_mon_local,0)) -
          (nvl(s.sal_equ_loc_ant,0)+nvl(s.deb_equ_local,0)-nvl(s.cre_equ_local,0))) * -1 Saldo_Guaranies,
         (nvl(s.sal_mon_rub_ant,0)+nvl(s.deb_mon_rubro,0)-nvl(s.cre_mon_rubro,0)) * -1 Saldo_Rubro,
         (nvl(s.sal_equ_loc_ant,0)+nvl(s.deb_equ_local,0)-nvl(s.cre_equ_local,0)) * -1 Saldo_Equivalente,
         (nvl(s.sal_mon_loc_ant,0)+nvl(s.deb_mon_local,0)-nvl(s.cre_mon_local,0)) * -1 Saldo_Total,
         k.cod_rubro rubro_it, 'Balance Cerrado Con Signo x Sucursal' Tip_Balance
      from cb_sal_oficinas s, cb_rub_bcp r, cb_rubros k
      where r.cod_rub_bcp(+) = substr(s.cod_rubro,1,8)||substr(s.cod_rubro,3,1)||substr(s.cod_rubro,9,2)
      and s.cod_rubro        = k.cod_rubro
      and k.imputable        = 'N'
      and k.nivel            <= 5
      and abs(nvl(s.sal_mon_loc_ant,0)+nvl(s.deb_mon_local,0)-nvl(s.cre_mon_local,0)) <> 0
      and not exists(select 1 from cb_rubros t where substr(t.cod_rubro,9,2) = '01' and nivel = 5 and k.cod_rubro=t.cod_rub_padre)
      order by 1,2, r.cod_rub_bcp;

  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'bal_cerrado_consig_suc'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_fecha            VARCHAR2(8);
  v_hora             VARCHAR2(8);

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
  -- Obtenemos la fecha del sistema de contabilidad
  v_fecha := to_char(pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1),'YYYYMMDD');

  -- Obtenemos la hora de la base de datos
  v_hora := to_char(sysdate,'hh24miss');

-- Abrir archivo
v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'.txt','W',32767);

-- Colocar el titulo a los campos
v_linetit := 'COD_OFICINA'||CHR(9)||'BCP1'||CHR(9)||'BCP2'||CHR(9)||'DESCRIPCION'||CHR(9)||
             'SALDO_GUARANIES'||CHR(9)||'SALDO_RUBRO'||CHR(9)||'SALDO_EQUIVALENTE'||CHR(9)||
             'SALDO_TOTAL'||CHR(9)||'RUBRO_IT'||CHR(9)||'TIP_BALANCE';

utl_file.put_line(v_file,v_linetit);

-- Definir una linea en blanco para separar los datos del titulo de los campos
v_linetit := ' ';
utl_file.put_line(v_file,v_linetit);

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN cu_balce_sig_suc LOOP

    --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
  v_line := to_char(rec.COD_OFICINA)||chr(9)||to_char(rec.BCP1)||chr(9)||to_char(rec.BCP2)||chr(9)||to_char(rec.DESCRIPCION)||chr(9)||
             to_char(rec.SALDO_GUARANIES,'999999999999999999999D00')||chr(9)||to_char(rec.SALDO_RUBRO,'999999999999999999999D00')||chr(9)||
            to_char(rec.SALDO_EQUIVALENTE,'999999999999999999999D00')||chr(9)||to_char(rec.SALDO_TOTAL,'999999999999999999999D00')||chr(9)||
            to_char(rec.RUBRO_IT)||chr(9)||to_char(rec.TIP_BALANCE);


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

  EXIT WHEN cu_balce_sig_suc%NOTFOUND;
END LOOP;
--Escribes la linea en el fichero
UTL_FILE.PUT_LINE(v_file, v_buffer);

--Cerrar el handler al fichero
UTL_FILE.FCLOSE(v_file);
COMMIT;

  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_respuesta := pa_file_ftp.fu_put_ascii(pa_rpc_aut.g_ip, pa_rpc_aut.g_port, pa_rpc_aut.g_user,
                                          pa_rpc_aut.g_pass, pa_rpc_aut.g_repository,
                                          v_name||'.txt', g_balances||v_name||'_'||v_fecha||'_'||v_hora||'.txt');

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','BALANCE_CERRADO_SIG_SUC');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte Balance Cerrado con Signo por Sucursal a la fecha '||v_fecha||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_balances||'

    Nombre del Archivo: '||v_name||'_'||v_fecha||'_'||v_hora||'.txt';

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'_'||v_hora||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error    := null;

    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, v_name||'_'||v_fecha||'_'||v_hora||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;

    --Enviamos el mail a soporte
     -- Obtenemos direccion de correo de soporte
     v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error Reporte Balance Cerrado Con Signo por Sucursal a la fecha '||v_fecha||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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
END pr_balce_sig_suc;
-------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------
-- Saldos Contables Sin Signo - AS400
PROCEDURE pr_balan_cerrado
IS
CURSOR cu_balcerrado IS
      select '0'||substr(r.cod_rub_bcp,1,5) bcp1,
         case when substr(r.cod_rub_bcp,6,6) = '000000' then null
         else substr(r.cod_rub_bcp,6,6) end bcp2,
         '0'||substr(r.cod_rub_bcp,1,5)||substr(r.cod_rub_bcp,6,6) rubro_BCP,
         null col, k.Descripcion Descripcion,

         abs((nvl(s.sal_mon_loc_ant,0)+nvl(s.deb_mon_local,0)-nvl(s.cre_mon_local,0)) -
             (nvl(s.sal_equ_loc_ant,0)+nvl(s.deb_equ_local,0)-nvl(s.cre_equ_local,0))) Saldo_Guaranies,

         case when ((nvl(s.sal_mon_loc_ant,0)+nvl(s.deb_mon_local,0)-nvl(s.cre_mon_local,0)) -
                    (nvl(s.sal_equ_loc_ant,0)+nvl(s.deb_equ_local,0)-nvl(s.cre_equ_local,0))) < 0 then '+'
         when ((nvl(s.sal_mon_loc_ant,0)+nvl(s.deb_mon_local,0)-nvl(s.cre_mon_local,0)) -
               (nvl(s.sal_equ_loc_ant,0)+nvl(s.deb_equ_local,0)-nvl(s.cre_equ_local,0))) > 0 then '-'
         else null end signo_gs,

         abs(nvl(s.sal_mon_rub_ant,0)+nvl(s.deb_mon_rubro,0)-nvl(s.cre_mon_rubro,0)) Saldo_Rubro,

         case when (nvl(s.sal_mon_rub_ant,0)+nvl(s.deb_mon_rubro,0)-nvl(s.cre_mon_rubro,0)) < 0 then '+'
         when (nvl(s.sal_mon_rub_ant,0)+nvl(s.deb_mon_rubro,0)-nvl(s.cre_mon_rubro,0)) > 0 then '-'
         else null end signo_me,

         abs(nvl(s.sal_equ_loc_ant,0)+nvl(s.deb_equ_local,0)-nvl(s.cre_equ_local,0)) Saldo_Equivalente,

         case when (nvl(s.sal_equ_loc_ant,0)+nvl(s.deb_equ_local,0)-nvl(s.cre_equ_local,0)) < 0 then '+'
         when (nvl(s.sal_equ_loc_ant,0)+nvl(s.deb_equ_local,0)-nvl(s.cre_equ_local,0)) > 0 then '-'
         else null end signo_equiv,

         abs(nvl(s.sal_mon_loc_ant,0)+nvl(s.deb_mon_local,0)-nvl(s.cre_mon_local,0)) Saldo_Total,

         case when nvl(s.sal_mon_loc_ant,0)+nvl(s.deb_mon_local,0)-nvl(s.cre_mon_local,0) < 0 then '+'
         when nvl(s.sal_mon_loc_ant,0)+nvl(s.deb_mon_local,0)-nvl(s.cre_mon_local,0) > 0 then '-'
         else null end signo_Total,
         k.cod_rubro rubro_it, 'Balance Cerrado' Tip_Balance
      from cb_sal_consolidados s, cb_rub_bcp r, cb_rubros k
      where r.cod_rub_bcp(+) = substr(s.cod_rubro,1,8)||substr(s.cod_rubro,3,1)||substr(s.cod_rubro,9,2)
      and s.cod_rubro        = k.cod_rubro
      and k.imputable        = 'N'
      and k.nivel            <= 5
      and abs(nvl(s.sal_mon_loc_ant,0)+nvl(s.deb_mon_local,0)-nvl(s.cre_mon_local,0)) <> 0
      and not exists(select 1 from cb_rubros t where substr(t.cod_rubro,9,2) = '01' and nivel = 5 and k.cod_rubro=t.cod_rub_padre)
      order by 1, r.cod_rub_bcp;

  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'bal_cerrado'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_fecha            VARCHAR2(8);
  v_hora             VARCHAR2(8);

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
  -- Obtenemos la fecha del sistema de contabilidad
  v_fecha := to_char(pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1),'YYYYMMDD');

  -- Obtenemos la hora de la base de datos
  v_hora := to_char(sysdate,'hh24miss');

-- Abrir archivo
v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'.txt','W',32767);

-- Colocar el titulo a los campos
v_linetit := 'BCP1'||CHR(9)||'BCP2'||CHR(9)||'RUBRO_BCP'||CHR(9)||'COL'||CHR(9)||'DESCRIPCION'||CHR(9)||
             'SALDO_GUARANIES'||CHR(9)||'SIGNO_GS'||CHR(9)||
             'SALDO_RUBRO'||CHR(9)||'SIGNO_ME'||CHR(9)||'SALDO_EQUIVALENTE'||CHR(9)||'SIGNO_EQUIV'||CHR(9)||
             'SALDO_TOTAL'||CHR(9)||'SIGNO_TOTAL'||CHR(9)||'RUBRO_IT'||CHR(9)||'TIP_BALANCE';

utl_file.put_line(v_file,v_linetit);

-- Definir una linea en blanco para separar los datos del titulo de los campos
v_linetit := ' ';
utl_file.put_line(v_file,v_linetit);

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN cu_balcerrado LOOP

    --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
  v_line := to_char(rec.BCP1)||chr(9)||to_char(rec.BCP2)||chr(9)||to_char(rec.RUBRO_BCP)||chr(9)||
             to_char(rec.COL)||chr(9)||to_char(rec.DESCRIPCION)||chr(9)||
            to_char(rec.SALDO_GUARANIES,'999999999999999999999999D00')||chr(9)||to_char(rec.SIGNO_GS)||chr(9)||
            to_char(rec.SALDO_RUBRO,'999999999999999999999D00')||chr(9)||to_char(rec.SIGNO_ME)||chr(9)||
            to_char(rec.SALDO_EQUIVALENTE,'999999999999999999999D00')||chr(9)||to_char(rec.SIGNO_EQUIV)||chr(9)||
            to_char(rec.SALDO_TOTAL,'999999999999999999999D00')||chr(9)||to_char(rec.SIGNO_TOTAL)||chr(9)||
            to_char(rec.RUBRO_IT)||chr(9)||to_char(rec.TIP_BALANCE);


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

  EXIT WHEN cu_balcerrado%NOTFOUND;
END LOOP;
--Escribes la linea en el fichero
UTL_FILE.PUT_LINE(v_file, v_buffer);

--Cerrar el handler al fichero
UTL_FILE.FCLOSE(v_file);
COMMIT;

  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_respuesta := pa_file_ftp.fu_put_ascii(pa_rpc_aut.g_ip, pa_rpc_aut.g_port, pa_rpc_aut.g_user,
                                          pa_rpc_aut.g_pass, pa_rpc_aut.g_repository,
                                          v_name||'.txt', g_balances||v_name||'_'||v_fecha||'_'||v_hora||'.txt');

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','BALANCE_CERRADO');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte Balance Cerrado a la fecha '||v_fecha||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_balances||'

    Nombre del Archivo: '||v_name||'_'||v_fecha||'_'||v_hora||'.txt';

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'_'||v_hora||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error    := null;

    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, v_name||'_'||v_fecha||'_'||v_hora||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;

    --Enviamos el mail a soporte
     -- Obtenemos direccion de correo de soporte
     v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error Reporte Balance Historico a la fecha '||v_fecha||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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
END pr_balan_cerrado;
-------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------
-- Procedimiento para obtener reportes de saldos contables Diarios de la AS400
PROCEDURE pr_balcerra_dia
IS
BEGIN
    BEGIN

      -- Saldos Contables Abierto - AS400
      pa_rpc_aut.pr_bal_abierto;
      commit;

      -- Saldos Contables Abierto por Sucursal - AS400
      pa_rpc_aut.pr_bal_abi_suc;
      commit;

      -- Saldos Contables Con Signos - AS400
      pa_rpc_aut.pr_balcerra_sig;
      commit;

      -- Saldos Contables Con Signos por Sucursal - AS400
      pa_rpc_aut.pr_balce_sig_suc;
      commit;

      -- Saldos Contables Sin Signo - AS400
      pa_rpc_aut.pr_balan_cerrado;
      commit;

    END;
END pr_balcerra_dia;
-------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------
-- Control de Posición de Cambios formato AS400
PROCEDURE pr_pos_cambio
IS
CURSOR cu_pos_cambio IS
      select t.texto texto
      from TMP_POS_CAMBIO t
      order by t.NRO_BLOQUE asc, t.NRO_LINEA asc;

  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'ctrl_pos_cambio'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_fecha            VARCHAR2(8);
  v_hora             VARCHAR2(8);

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
  -- Obtenemos la fecha del sistema de contabilidad
  v_fecha := to_char(pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1),'YYYYMMDD');

  -- Obtenemos la hora de la base de datos
  v_hora := to_char(sysdate,'hh24miss');

-- Abrir archivo
v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'.txt','W',32767);

-- Colocar el titulo a los campos
v_linetit := 'TEXTO';

utl_file.put_line(v_file,v_linetit);

-- Definir una linea en blanco para separar los datos del titulo de los campos
v_linetit := ' ';
utl_file.put_line(v_file,v_linetit);

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN cu_pos_cambio LOOP

    --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
  v_line := to_char(rec.TEXTO);

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

  EXIT WHEN cu_pos_cambio%NOTFOUND;
END LOOP;
--Escribes la linea en el fichero
UTL_FILE.PUT_LINE(v_file, v_buffer);

--Cerrar el handler al fichero
UTL_FILE.FCLOSE(v_file);
COMMIT;

  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_respuesta := pa_file_ftp.fu_put_binary(pa_rpc_aut.g_ip, pa_rpc_aut.g_port, pa_rpc_aut.g_user,
                                          pa_rpc_aut.g_pass, pa_rpc_aut.g_repository,
                                          v_name||'.txt', g_contabilidad||v_name||'_'||v_fecha||'_'||v_hora||'.txt');

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','CTRL_POS_CAMBIO');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte Control de Posición de Cambios formato AS400 a la fecha '||v_fecha||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_contabilidad||'

    Nombre del Archivo: '||v_name||'_'||v_fecha||'_'||v_hora||'.txt';

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'_'||v_hora||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error    := null;

    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, v_name||'_'||v_fecha||'_'||v_hora||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;

    --Enviamos el mail a soporte
     -- Obtenemos direccion de correo de soporte
     v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error Reporte Control de Posición de Cambios formato AS400 a la fecha '||v_fecha||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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
END pr_pos_cambio;
-------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------
-- Procedimiento para obtener reportes de Control de Posición de Cambios formato AS400
PROCEDURE pr_ctrl_pos_cam
IS
BEGIN
    BEGIN

      -- Procedimiento para Generación de Posición de Cambios - formato AS400
      prb_gen_pos_cambio;
      commit;

      -- Control de Posición de Cambios formato AS400
      pa_rpc_aut.pr_pos_cambio;
      commit;

    END;
END pr_ctrl_pos_cam;
-------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------
-- Diferencia ARMAMAY - Balance ITGF
PROCEDURE pr_dif_armamay
IS
CURSOR cu_dif_amamay IS
    select msuc, cta_as, cta_it, cod_moneda, saldo_gs_as, saldo_me_as,
           saldo_gs_it, saldo_me_it, diff_gs, diff_me
    from smg_cua_armamay_sal_oficina2
    order by 1,3;

  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'dif_amamay_bal_itgf'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_fecha            VARCHAR2(8);
  v_hora             VARCHAR2(8);

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
  -- Obtenemos la fecha del sistema de contabilidad
  v_fecha := to_char(pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1),'YYYYMMDD');

  -- Obtenemos la hora de la base de datos
  v_hora := to_char(sysdate,'hh24miss');

-- Abrir archivo
v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'.txt','W',32767);

-- Colocar el titulo a los campos
v_linetit := 'MSUC'||CHR(9)||'CTA_AS'||CHR(9)||'CTA_IT'||CHR(9)||'COD_MONEDA'||CHR(9)||
             'SALDO_GS_AS'||CHR(9)||'SALDO_ME_AS'||CHR(9)||'SALDO_GS_IT'||CHR(9)||
             'SALDO_ME_IT'||CHR(9)||'DIFF_GS'||CHR(9)||'DIFF_ME';

utl_file.put_line(v_file,v_linetit);

-- Definir una linea en blanco para separar los datos del titulo de los campos
v_linetit := ' ';
utl_file.put_line(v_file,v_linetit);

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN cu_dif_amamay LOOP

    --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
  v_line := to_char(rec.MSUC)||chr(9)||to_char(rec.CTA_AS)||chr(9)||to_char(rec.CTA_IT)||chr(9)||to_char(rec.COD_MONEDA)||chr(9)||
             to_char(rec.SALDO_GS_AS,'999999999999999999999D00')||chr(9)||to_char(rec.SALDO_ME_AS,'999999999999999999999D00')||chr(9)||
            to_char(rec.SALDO_GS_IT,'999999999999999999999D00')||chr(9)||to_char(rec.SALDO_ME_IT,'999999999999999999999D00')||chr(9)||
            to_char(rec.DIFF_GS,'999999999999999999999D00')||chr(9)||to_char(rec.DIFF_ME,'999999999999999999999D00');


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

  EXIT WHEN cu_dif_amamay%NOTFOUND;
END LOOP;
--Escribes la linea en el fichero
UTL_FILE.PUT_LINE(v_file, v_buffer);

--Cerrar el handler al fichero
UTL_FILE.FCLOSE(v_file);
COMMIT;

  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_respuesta := pa_file_ftp.fu_put_ascii(pa_rpc_aut.g_ip, pa_rpc_aut.g_port, pa_rpc_aut.g_user,
                                          pa_rpc_aut.g_pass, pa_rpc_aut.g_repository,
                                          v_name||'.txt', g_contabilidad||v_name||'_'||v_fecha||'_'||v_hora||'.txt');

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','DIF_ARMAMAY');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte Diferencia ARMAMAY - Balance ITGF a la fecha '||v_fecha||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_contabilidad||'

    Nombre del Archivo: '||v_name||'_'||v_fecha||'_'||v_hora||'.txt';

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'_'||v_hora||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error    := null;

    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, v_name||'_'||v_fecha||'_'||v_hora||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;

    --Enviamos el mail a soporte
     -- Obtenemos direccion de correo de soporte
     v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error Reporte Diferencia ARMAMAY - Balance ITGF a la fecha '||v_fecha||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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
END pr_dif_armamay;
-------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------
-- Informes para Casa Matriz en España - ACTPAS
PROCEDURE pr_info_actpas
IS
CURSOR cu_info_actpas IS
       select d.actpas
       from cb_act_pas_esp_tmp d;

  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'ACTPAS'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_fecha            VARCHAR2(8);

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
  -- Obtenemos la fecha del sistema de contabilidad
  v_fecha := to_char(pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1),'DDMMYYYY');

-- Abrir archivo
v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'.txt','W',32767);

-- Colocar el titulo a los campos
v_linetit := 'ACTPAS';

utl_file.put_line(v_file,v_linetit);

-- Definir una linea en blanco para separar los datos del titulo de los campos
v_linetit := ' ';
utl_file.put_line(v_file,v_linetit);

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN cu_info_actpas LOOP

    --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
  v_line := to_char(rec.ACTPAS);

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

  EXIT WHEN cu_info_actpas%NOTFOUND;
END LOOP;
--Escribes la linea en el fichero
UTL_FILE.PUT_LINE(v_file, v_buffer);

--Cerrar el handler al fichero
UTL_FILE.FCLOSE(v_file);
COMMIT;

  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_respuesta := pa_file_ftp.fu_put_ascii(pa_rpc_aut.g_ip, pa_rpc_aut.g_port, pa_rpc_aut.g_user,
                                          pa_rpc_aut.g_pass, pa_rpc_aut.g_repository,
                                          v_name||'.txt', g_infoespana||v_name||'_'||v_fecha||'.txt');

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','INFO_ESPANA');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte ACTPAS para Casa Matriz en España a la fecha '||v_fecha||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_infoespana||'

    Nombre del Archivo: '||v_name||'_'||v_fecha||'.txt';

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error    := null;

    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, v_name||'_'||v_fecha||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;

    --Enviamos el mail a soporte
     -- Obtenemos direccion de correo de soporte
     v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error Reporte ACTPAS para Casa Matriz en España a la fecha '||v_fecha||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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
END pr_info_actpas;
-------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------
-- Informes para Casa Matriz en España - BALBBVA
PROCEDURE pr_info_balbbva
IS
CURSOR cu_info_balbbva IS
       select d.balbbva
       from cb_bal_bbv_esp_tmp d
       order by balbbva;

  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'BALBBVA'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_fecha            VARCHAR2(8);

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
  -- Obtenemos la fecha del sistema de contabilidad
  v_fecha := to_char(pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1),'DDMMYYYY');

-- Abrir archivo
v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name,'W',32767);

-- Colocar el titulo a los campos
v_linetit := 'BALBBVA';

utl_file.put_line(v_file,v_linetit);

-- Definir una linea en blanco para separar los datos del titulo de los campos
v_linetit := ' ';
utl_file.put_line(v_file,v_linetit);

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN cu_info_balbbva LOOP

    --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
  v_line := to_char(rec.BALBBVA);

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

  EXIT WHEN cu_info_balbbva%NOTFOUND;
END LOOP;
--Escribes la linea en el fichero
UTL_FILE.PUT_LINE(v_file, v_buffer);

--Cerrar el handler al fichero
UTL_FILE.FCLOSE(v_file);
COMMIT;

  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_respuesta := pa_file_ftp.fu_put_ascii(pa_rpc_aut.g_ip, pa_rpc_aut.g_port, pa_rpc_aut.g_user,
                                          pa_rpc_aut.g_pass, pa_rpc_aut.g_repository,
                                          v_name, g_infoespana||v_name||'_'||v_fecha);

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','INFO_ESPANA');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte BALBBVA para Casa Matriz en España a la fecha '||v_fecha||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_infoespana||'

    Nombre del Archivo: '||v_name||'_'||v_fecha;

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha, v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error    := null;

    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, v_name||'_'||v_fecha, v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;

    --Enviamos el mail a soporte
     -- Obtenemos direccion de correo de soporte
     v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error Reporte BALBBVA para Casa Matriz en España a la fecha '||v_fecha||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha, v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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
END pr_info_balbbva;
-------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------
-- Informes para Casa Matriz en España - RA13407
PROCEDURE pr_info_ra13407
IS
CURSOR cu_info_ra13407 IS
       select d.line
       from cb_ra1_3407_esp_tmp d;

  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'RA13407'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_fecha            VARCHAR2(8);

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
  -- Obtenemos la fecha del sistema de contabilidad
  v_fecha := to_char(pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1),'DDMMYYYY');

-- Abrir archivo
v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'.txt','W',32767);

-- Colocar el titulo a los campos
v_linetit := 'LINE';

utl_file.put_line(v_file,v_linetit);

-- Definir una linea en blanco para separar los datos del titulo de los campos
v_linetit := ' ';
utl_file.put_line(v_file,v_linetit);

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN cu_info_ra13407 LOOP

    --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
  v_line := to_char(rec.LINE);

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

  EXIT WHEN cu_info_ra13407%NOTFOUND;
END LOOP;
--Escribes la linea en el fichero
UTL_FILE.PUT_LINE(v_file, v_buffer);

--Cerrar el handler al fichero
UTL_FILE.FCLOSE(v_file);
COMMIT;

  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_respuesta := pa_file_ftp.fu_put_ascii(pa_rpc_aut.g_ip, pa_rpc_aut.g_port, pa_rpc_aut.g_user,
                                          pa_rpc_aut.g_pass, pa_rpc_aut.g_repository,
                                          v_name||'.txt', g_infoespana||v_name||'_'||v_fecha||'.txt');

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','INFO_ESPANA');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte RA13407 para Casa Matriz en España a la fecha '||v_fecha||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_infoespana||'

    Nombre del Archivo: '||v_name||'_'||v_fecha||'.txt';

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error    := null;

    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, v_name||'_'||v_fecha||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;

    --Enviamos el mail a soporte
     -- Obtenemos direccion de correo de soporte
     v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error Reporte RA13407 para Casa Matriz en España a la fecha '||v_fecha||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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
END pr_info_ra13407;
-------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------
-- Informes para Casa Matriz en España - RESBBVA
PROCEDURE pr_info_resbbva
IS
CURSOR cu_info_resbbva IS
       select resbbva
       from cb_res_bbv_esp_tmp
       order by nro_linea asc;

  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'RESBBVA'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_fecha            VARCHAR2(8);

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
  -- Obtenemos la fecha del sistema de contabilidad
  v_fecha := to_char(pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1),'DDMMYYYY');

-- Abrir archivo
v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'.prn','W',32767);

-- Colocar el titulo a los campos
v_linetit := 'RESBBVA';

utl_file.put_line(v_file,v_linetit);

-- Definir una linea en blanco para separar los datos del titulo de los campos
v_linetit := ' ';
utl_file.put_line(v_file,v_linetit);

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN cu_info_resbbva LOOP

    --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
  v_line := to_char(rec.RESBBVA);

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

  EXIT WHEN cu_info_resbbva%NOTFOUND;
END LOOP;
--Escribes la linea en el fichero
UTL_FILE.PUT_LINE(v_file, v_buffer);

--Cerrar el handler al fichero
UTL_FILE.FCLOSE(v_file);
COMMIT;

  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_respuesta := pa_file_ftp.fu_put_ascii(pa_rpc_aut.g_ip, pa_rpc_aut.g_port, pa_rpc_aut.g_user,
                                          pa_rpc_aut.g_pass, pa_rpc_aut.g_repository,
                                          v_name||'.prn', g_infoespana||v_name||'_'||v_fecha||'.prn');

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','INFO_ESPANA');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte RESBBVA para Casa Matriz en España a la fecha '||v_fecha||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_infoespana||'

    Nombre del Archivo: '||v_name||'_'||v_fecha||'.prn';

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.prn', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error    := null;

    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, v_name||'_'||v_fecha||'.prn', v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;

    --Enviamos el mail a soporte
     -- Obtenemos direccion de correo de soporte
     v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error Reporte RESBBVA para Casa Matriz en España a la fecha '||v_fecha||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.prn', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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
END pr_info_resbbva;
-------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------
-- Procedimiento para obtener reportes de Informes para Casa Matriz en Espana
PROCEDURE pr_info_espana
IS
BEGIN
    BEGIN

      -- Informes para Casa Matriz en España - ACTPAS
      pa_rpc_aut.pr_info_actpas;
      commit;

      -- Informes para Casa Matriz en España - BALBBVA
      pa_rpc_aut.pr_info_balbbva;
      commit;

      -- Informes para Casa Matriz en España - RA13407
      pa_rpc_aut.pr_info_ra13407;
      commit;

      -- Informes para Casa Matriz en España - RESBBVA
      pa_rpc_aut.pr_info_resbbva;
      commit;

    END;
END pr_info_espana;
-------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------
-- Libro IVA de Ventas Diarios
PROCEDURE pr_iva_venta_di
IS
CURSOR cu_iva_venta_di IS
          select  c.fecha,c.hora,c.cod_usuario,a.nro_secuencia,c.nro_factura,c.nro_timbrado,
                  c.descripcion,c.nro_cuenta, c.cod_moneda,c.mto_exento,c.mto_exento_gs,
                  c.mto_gravado_5,c.mto_gra_5_gs,c.mto_gravado_10,c.mto_gra_10_gs,
                  c.impuesto_5,
                  (case when a.MTO_EQU_LOCAL is null then c.impuesto_5_gs
                              when abs(a.MTO_EQU_LOCAL) > c.impuesto_5_gs then (c.impuesto_5_gs + c.aju_impuesto_5)
                              when abs(a.MTO_EQU_LOCAL) < c.impuesto_5_gs then (c.impuesto_5_gs - c.aju_impuesto_5)
                              else c.impuesto_5_gs end) impuesto_5_gs,
                  c.impuesto_10,
                  (case when a.MTO_EQU_LOCAL is null then c.impuesto_10_gs
                              when abs(a.MTO_EQU_LOCAL) > c.impuesto_10_gs then (c.impuesto_10_gs + c.aju_impuesto_10)
                              when abs(a.MTO_EQU_LOCAL) < c.impuesto_10_gs then (c.impuesto_10_gs - c.aju_impuesto_10)
                              else c.impuesto_10_gs end) impuesto_10_gs,
                  c.cotizacion, b.nro_asiento,b.nro_linea
           from ge_movimientos a, cb_asi_automaticos_det b, cb_lib_ventas_det_tmp c
            where a.NRO_DOCUMENTO4        = b.ref_movimiento
              and a.FECHA                 = b.fecha
              and a.FECHA                 = c.fecha
              and a.HORA                  = c.hora
              and (a.NRO_CUENTA           = c.nro_cuenta or a.NRO_CUENTA is null)
              and (abs(a.monto)           = c.impuesto_5 or abs(a.monto) = c.impuesto_10)
              and a.COD_TASA in (323,343,420)
              and (b.tip_movimiento       = 'C' or (b.tip_movimiento = 'D' and a.MONTO < 0))
              and substr(b.cod_rubro,1,2) = '24'
          union
          select  c.fecha,c.hora,c.cod_usuario,a.nro_secuencia,c.nro_factura,c.nro_timbrado,
                  c.descripcion,c.nro_cuenta, c.cod_moneda,c.mto_exento,c.mto_exento_gs,
                  c.mto_gravado_5,c.mto_gra_5_gs,c.mto_gravado_10,c.mto_gra_10_gs,
                  c.impuesto_5,
                  (case when a.MTO_EQU_LOCAL is null then c.impuesto_5_gs
                              when abs(a.MTO_EQU_LOCAL) > c.impuesto_5_gs then (c.impuesto_5_gs + c.aju_impuesto_5)
                              when abs(a.MTO_EQU_LOCAL) < c.impuesto_5_gs then (c.impuesto_5_gs - c.aju_impuesto_5)
                              else c.impuesto_5_gs end) impuesto_5_gs,
                  c.impuesto_10,
                  (case when a.MTO_EQU_LOCAL is null then c.impuesto_10_gs
                              when abs(a.MTO_EQU_LOCAL) > c.impuesto_10_gs then (c.impuesto_10_gs + c.aju_impuesto_10)
                              when abs(a.MTO_EQU_LOCAL) < c.impuesto_10_gs then (c.impuesto_10_gs - c.aju_impuesto_10)
                              else c.impuesto_10_gs end) impuesto_10_gs,
                  c.cotizacion, b.nro_asiento,b.nro_linea
           from ge_movimientos a, cb_asi_automaticos_det b, cb_lib_ventas_det_tmp c
            where a.NRO_DOCUMENTO4        = b.ref_movimiento
              and a.FECHA                 = b.fecha
              and a.FECHA                 = c.fecha
              and a.HORA                  = c.hora
              and (a.NRO_CUENTA           = c.nro_cuenta or a.NRO_CUENTA is null)
              and (abs(a.monto)           = c.impuesto_5 or abs(a.monto) = c.impuesto_10)
              and (b.tip_movimiento       = 'C' or (b.tip_movimiento = 'D' and a.MONTO < 0))
              and a.cod_tasa is null
              and substr(b.cod_rubro,1,2) = '24'
              AND EXISTS (select 1
                                    from ge_transacciones_det gd
                                   where gd.cod_transaccion =a.cod_transaccion
                                     and pab_iva.fu_mov_con_iva(gd.cod_mod_hijo, gd.cod_mad_hijo, gd.cod_tra_hijo,null, null) = 'S');

  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'libro_IVA_venta_diario'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_fec_sist         VARCHAR2(10);
  v_fecha            VARCHAR2(8);

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
  v_fec_sist := to_char(sysdate,'DD/MM/YYYY');

  v_fecha := to_char(sysdate,'DDMMYYYY');

-- Abrir archivo
v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'.txt','W',32767);

-- Colocar el titulo a los campos
v_linetit := 'FECHA'||CHR(9)||'HORA'||CHR(9)||'COD_USUARIO'||CHR(9)||'NRO_SECUENCIA'||CHR(9)||'NRO_FACTURA'||CHR(9)||
             'NRO_TIMBRADO'||CHR(9)||'DESCRIPCION'||CHR(9)||'NRO_CUENTA'||CHR(9)||'COD_MONEDA'||CHR(9)||'MTO_EXENTO'||CHR(9)||
             'MTO_EXENTO_GS'||CHR(9)||'MTO_GRAVADO_5'||CHR(9)||'MTO_GRA_5_GS'||CHR(9)||'MTO_GRAVADO_10'||CHR(9)||
             'MTO_GRA_10_GS'||CHR(9)||'IMPUESTO_5'||CHR(9)||'IMPUESTO_5_GS'||CHR(9)||'IMPUESTO_10'||CHR(9)||
             'IMPUESTO_10_GS'||CHR(9)||'COTIZACION'||CHR(9)||'NRO_ASIENTO'||CHR(9)||'NRO_LINEA';

utl_file.put_line(v_file,v_linetit);

-- Definir una linea en blanco para separar los datos del titulo de los campos
v_linetit := ' ';
utl_file.put_line(v_file,v_linetit);

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN cu_iva_venta_di LOOP

    --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
  v_line := to_char(rec.FECHA)||chr(9)||to_char(rec.HORA)||chr(9)||to_char(rec.COD_USUARIO)||chr(9)||to_char(rec.NRO_SECUENCIA)||chr(9)||
            to_char(rec.NRO_FACTURA)||chr(9)||to_char(rec.NRO_TIMBRADO)||chr(9)||to_char(rec.DESCRIPCION)||chr(9)||
            to_char(rec.NRO_CUENTA)||chr(9)||to_char(rec.COD_MONEDA)||chr(9)||
            to_char(rec.MTO_EXENTO,'999999999999999999D00')||chr(9)||to_char(rec.MTO_EXENTO_GS,'999999999999999999D00')||chr(9)||
            to_char(rec.MTO_GRAVADO_5,'999999999999D00')||chr(9)||to_char(rec.MTO_GRA_5_GS,'999999999999999999D00')||chr(9)||
            to_char(rec.MTO_GRAVADO_10,'999999999999999999D00')||chr(9)||to_char(rec.MTO_GRA_10_GS,'999999999999999999D00')||chr(9)||
            to_char(rec.IMPUESTO_5,'999999999999999999D00')||chr(9)||to_char(rec.IMPUESTO_5_GS,'999999999999999999D00')||chr(9)||
            to_char(rec.IMPUESTO_10,'999999999999999999D00')||chr(9)||to_char(rec.IMPUESTO_10_GS,'999999999999999999D00')||chr(9)||
            to_char(rec.COTIZACION,'999999999999999999D00')||chr(9)||to_char(rec.NRO_ASIENTO)||chr(9)||to_char(rec.NRO_LINEA);

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

  EXIT WHEN cu_iva_venta_di%NOTFOUND;
END LOOP;
--Escribes la linea en el fichero
UTL_FILE.PUT_LINE(v_file, v_buffer);

--Cerrar el handler al fichero
UTL_FILE.FCLOSE(v_file);
COMMIT;

  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_respuesta := pa_file_ftp.fu_put_ascii(pa_rpc_aut.g_ip, pa_rpc_aut.g_port, pa_rpc_aut.g_user,
                                          pa_rpc_aut.g_pass, pa_rpc_aut.g_repository,
                                          v_name||'.txt', g_contabilidad||v_name||'_'||v_fecha||'.txt');

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','LIBRO_IVA_VENTA_DIA');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte Libro IVA Venta Diario a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_contabilidad||'

    Nombre del Archivo: '||v_name||'_'||v_fecha||'.txt';

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error    := null;

    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, v_name||'_'||v_fecha||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;

    --Enviamos el mail a soporte
     -- Obtenemos direccion de correo de soporte
     v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error Libro IVA Venta Diario a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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
END pr_iva_venta_di;
-------------------------------------------------------------------------------------------------------------------------------------

/******* REPORTES MENSUALES *******/

-------------------------------------------------------------------------------------------------------------------------------------
-- Previsiones Específicas Detallado Mensual
PROCEDURE pr_prev_det_mes
IS
CURSOR cu_prevision_mes IS
    select distinct (ti.descripcion) tip_gar,ss.riesgo, ss.nombre,ss.doc,ss.nro_doc,ss.cat_riesgo,ss.cat_crc,ss.ofi,ss.oficina,ss.cod_usu_oficial,ss.nom_usu,
    ss.banca,ss.cat_subjetiva,ss.gru_eco,ss.cat_sistema,ss.tot_deu_rsistema,ss.tot_con_rsistema,ss.tipo,ss.tip_cliente,ss.rubro,ss.cod_modalidad,
    ss.nro_cuenta,ss.cod_moneda,ss.cod_estado,ss.estado,ss.tot_deu_real,ss.tot_deu_contingente,ss.dev_no_cobrado,ss.tot_gar_computables,
    ss.tot_prevision, ss.cat_automatica,ss.cat_renovaciones,ss.dia_atraso,ss.tip_destino, ss.destino,ss.cod_sec_credito,ss.desc_sec_crd,
    ss.tip_renovacion,ss.mto_mora,ss.sect_prestamo,ss.desc_sect_prestamo,ss.fec_desembolso fec_contratacion, FUG_OBT_ES_PER_INHI(ss.riesgo) as inhibido
      from vg_previsiones_detalladas ss, pr_cta_garantias ga, pr_gar_tipos ti
     where ss.nro_cuenta = ga.nro_cuenta
       and ss.riesgo = ga.cod_persona
       and ga.cod_garantia = ti.cod_garantia
    union
    select ' ' tip_gar, ss.riesgo, ss.nombre,ss.doc,ss.nro_doc,ss.cat_riesgo,ss.cat_crc,ss.ofi,ss.oficina,ss.cod_usu_oficial,ss.nom_usu,
    ss.banca,ss.cat_subjetiva,ss.gru_eco,ss.cat_sistema,ss.tot_deu_rsistema,ss.tot_con_rsistema,ss.tipo,ss.tip_cliente,ss.rubro,ss.cod_modalidad,
    ss.nro_cuenta,ss.cod_moneda,ss.cod_estado,ss.estado,ss.tot_deu_real,ss.tot_deu_contingente,ss.dev_no_cobrado,ss.tot_gar_computables,
    ss.tot_prevision, ss.cat_automatica,ss.cat_renovaciones,ss.dia_atraso,ss.tip_destino, ss.destino,ss.cod_sec_credito,ss.desc_sec_crd,
    ss.tip_renovacion,ss.mto_mora,ss.sect_prestamo,ss.desc_sect_prestamo,ta.fec_activacion fec_contratacion, FUG_OBT_ES_PER_INHI(ss.riesgo) as inhibido
      from vg_previsiones_detalladas ss, ta_tarjetas ta
     where ss.sect_prestamo is null
       and ss.nro_cuenta = ta.nro_cuenta(+);

  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'prevision_det_mes'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_fec_sist         DATE;
  v_fecha            VARCHAR2(8);

  -- Variables para mail
  v_conn             utl_smtp.connection;
  v_para             VARCHAR2(4000);
  v_asunto           VARCHAR2(2000);
  v_mje_mail         VARCHAR2(4000);
  v_hini_mail        ge_ra_log_mail.hor_inicio%type;
  v_hfin_mail        ge_ra_log_mail.hor_fin%type;
  v_det_error        ge_ra_log_mail.det_error%type;

  -- Variables para FTP
  v_respuesta        VARCHAR2(4000);
  v_hini_ftp         ge_ra_log_ftp.hor_inicio%type;
  v_hfin_ftp         ge_ra_log_ftp.hor_fin%type;
  ---
  v_gru_eco_bcp_1    sb_gru_eco_bcp_det.grupo%TYPE;
  v_gru_eco_bcp_2    sb_gru_eco_bcp_det.grupo%TYPE;
  v_gru_eco_bcp_3    sb_gru_eco_bcp_det.grupo%TYPE;
  v_gru_eco_bcp_4    sb_gru_eco_bcp_det.grupo%TYPE;
  v_gru_eco_bcp_5    sb_gru_eco_bcp_det.grupo%TYPE;
  v_grupo_eco_bcp    VARCHAR2(4000);

BEGIN
  -- Obtenemos la fecha del sistema
  select pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1)
  into v_fec_sist
  from dual;

  v_fecha := to_char(v_fec_sist,'DDMMYYYY');

-- Abrir archivo
v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'.txt','W',32767);

-- Colocar el titulo a los campos
v_linetit := 'TIP_GAR'||CHR(9)||'RIESGO'||CHR(9)||'NOMBRE'||CHR(9)||'DOC'||CHR(9)||'NRO_DOC'||CHR(9)||'CAT_RIESGO'||CHR(9)||'CAT_CRC'||CHR(9)||
             'OFI'||CHR(9)||'OFICINA'||CHR(9)||'COD_USU_OFICIAL'||CHR(9)||'NOM_USU'||CHR(9)||'BANCA'||CHR(9)||'CAT_SUBJETIVA'||CHR(9)||
             'GRU_ECO'||CHR(9)||'GRU_ECO_BCP_1'||CHR(9)||'GRU_ECO_BCP_2'||CHR(9)||'GRU_ECO_BCP_3'||CHR(9)||
             'GRU_ECO_BCP_4'||CHR(9)||'GRU_ECO_BCP_5'||CHR(9)||'GRUPO_ECO_BCP'||CHR(9)||--CNF-GRU_ECO_BCP
             'CAT_SISTEMA'||CHR(9)||'TOT_DEU_RSISTEMA'||CHR(9)||'TOT_CON_RSISTEMA'||CHR(9)||
             'TIPO'||CHR(9)||'TIP_CLIENTE'||CHR(9)||'RUBRO'||CHR(9)||'COD_MODALIDAD'||CHR(9)||'NRO_CUENTA'||CHR(9)||'COD_MONEDA'||CHR(9)||
             'COD_ESTADO'||CHR(9)||'ESTADO'||CHR(9)||'TOT_DEU_REAL'||CHR(9)||'TOT_DEU_CONTINGENTE'||CHR(9)||'DEV_NO_COBRADO'||CHR(9)||
             'TOT_GAR_COMPUTABLES'||CHR(9)||'TOT_PREVISION'||CHR(9)||'CAT_AUTOMATICA'||CHR(9)||'CAT_RENOVACIONES'||CHR(9)||'DIA_ATRASO'||CHR(9)||
             'TIP_DESTINO'||CHR(9)||'DESTINO'||CHR(9)||'COD_SEC_CREDITO'||CHR(9)||'DESC_SEC_CRD'||CHR(9)||'TIP_RENOVACION'||CHR(9)||'MTO_MORA'||CHR(9)||
             'SECT_PRESTAMO'||CHR(9)||'DESC_SECT_PRESTAMO'||CHR(9)||'FEC_CONTRATACION'||CHR(9)||'INHIBIDO';

utl_file.put_line(v_file,v_linetit);

-- Definir una linea en blanco para separar los datos del titulo de los campos
v_linetit := ' ';
utl_file.put_line(v_file,v_linetit);

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN cu_prevision_mes LOOP
  prs_obt_gru_eco_bcp(rec.doc, rec.nro_doc, v_gru_eco_bcp_1, v_gru_eco_bcp_2, v_gru_eco_bcp_3, v_gru_eco_bcp_4, v_gru_eco_bcp_5, v_grupo_eco_bcp);--CNF-GRU_ECO_BCP
  --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
  v_line := to_char(rec.TIP_GAR)||chr(9)||to_char(rec.RIESGO)||chr(9)||to_char(rec.NOMBRE)||chr(9)||to_char(rec.DOC)||chr(9)||to_char(rec.NRO_DOC)||chr(9)||
            to_char(rec.CAT_RIESGO)||chr(9)||to_char(rec.CAT_CRC)||chr(9)||to_char(rec.OFI)||chr(9)||to_char(rec.OFICINA)||chr(9)||
            to_char(rec.COD_USU_OFICIAL)||chr(9)||to_char(rec.NOM_USU)||chr(9)||to_char(rec.BANCA)||chr(9)||to_char(rec.CAT_SUBJETIVA)||chr(9)||
            to_char(rec.GRU_ECO)||chr(9)||
            to_char(nvl(v_gru_eco_bcp_1,' '))||chr(9)||to_char(nvl(v_gru_eco_bcp_2,' '))||chr(9)||to_char(nvl(v_gru_eco_bcp_3,' '))||chr(9)||
            to_char(nvl(v_gru_eco_bcp_4,' '))||chr(9)||to_char(nvl(v_gru_eco_bcp_5,' '))||chr(9)||to_char(nvl(v_grupo_eco_bcp,' '))||chr(9)||
            to_char(rec.CAT_SISTEMA)||chr(9)||
            to_char(rec.TOT_DEU_RSISTEMA,'999999999999D00')||chr(9)||to_char(rec.TOT_CON_RSISTEMA,'999999999999D00')||chr(9)||
            to_char(rec.TIPO)||chr(9)||to_char(rec.TIP_CLIENTE)||chr(9)||to_char(rec.RUBRO)||chr(9)||to_char(rec.COD_MODALIDAD)||chr(9)||
            to_char(rec.NRO_CUENTA)||chr(9)||to_char(rec.COD_MONEDA)||chr(9)||to_char(rec.COD_ESTADO)||chr(9)||to_char(rec.ESTADO)||chr(9)||
            to_char(rec.TOT_DEU_REAL,'999999999999D00')||chr(9)||to_char(rec.TOT_DEU_CONTINGENTE,'999999999999D00')||chr(9)||
            to_char(rec.DEV_NO_COBRADO,'999999999999D00')||chr(9)||to_char(rec.TOT_GAR_COMPUTABLES,'999999999999D00')||chr(9)||
            to_char(rec.TOT_PREVISION,'999999999999D00')||chr(9)||to_char(rec.CAT_AUTOMATICA)||chr(9)||to_char(rec.CAT_RENOVACIONES)||chr(9)||
            to_char(rec.DIA_ATRASO)||chr(9)||to_char(rec.TIP_DESTINO)||chr(9)||to_char(rec.DESTINO)||chr(9)||to_char(rec.COD_SEC_CREDITO)||chr(9)||
            to_char(rec.DESC_SEC_CRD)||chr(9)||to_char(rec.TIP_RENOVACION)||chr(9)||to_char(rec.MTO_MORA,'999999999999D00')||chr(9)||
            to_char(rec.SECT_PRESTAMO)||chr(9)||to_char(rec.DESC_SECT_PRESTAMO)||chr(9)||to_char(rec.FEC_CONTRATACION)||chr(9)||to_char(rec.INHIBIDO);

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

   EXIT WHEN cu_prevision_mes%NOTFOUND;
END LOOP;
--Escribes la linea en el fichero
UTL_FILE.PUT_LINE(v_file, v_buffer);

--Cerrar el handler al fichero
UTL_FILE.FCLOSE(v_file);
COMMIT;

  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_respuesta := pa_file_ftp.fu_put_ascii(pa_rpc_aut.g_ip, pa_rpc_aut.g_port, pa_rpc_aut.g_user,
                                          pa_rpc_aut.g_pass, pa_rpc_aut.g_repository,
                                          v_name||'.txt', g_riesgos||v_name||'_'||v_fecha||'.txt');

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','PREVISION_DETALLE_MES');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte Mensual de Previsiones Específicas Detallada a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_riesgos||'

    Nombre del Archivo: '||v_name||'_'||v_fecha||'.txt';

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error    := null;

    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, v_name||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;

    --Enviamos el mail a soporte
     -- Obtenemos direccion de correo de soporte
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error Reporte Mensual Previsiones Especificas Detallada a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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
    RAISE_APPLICATION_ERROR(-20062,'Manejador invalido');
  WHEN UTL_FILE.WRITE_ERROR THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20063,'Error de escritura '||sqlerrm);
  WHEN UTL_FILE.INVALID_MODE THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20064,'Modo invalido');
  WHEN UTL_FILE.INTERNAL_ERROR THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20065,'Internal Error');
END pr_prev_det_mes;
-------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------
-- Impuestos al Valor Agregado 1
PROCEDURE pr_imp_va_uno
IS
CURSOR cu_agregado_uno(p_fecha_des DATE, p_fecha_has DATE) IS
        select d.fecha, d.cod_oficina, d.nro_asiento, d.nro_linea, d.cod_rubro, d.descripcion,
               d.tip_movimiento, decode(d.tip_movimiento,'D',d.mto_mon_rubro*-1,d.mto_mon_rubro) mto_rubro,
               decode(d.tip_movimiento,'D',d.mto_mon_local*-1,d.mto_mon_local) mto_local, d.ref_movimiento
        from cb_asi_automaticos_det d
        where d.fecha between p_fecha_des and p_fecha_has
        and d.cod_rubro in ('150102470200199' /*IMPUESTO AL VALOR AGREGADO - 10%*/, '150102470200299' /*IMPUESTO AL VALOR AGREGADO - 5%*/)
        order by 1;

  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'impuesto_va_uno'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_fec_sist         DATE;
  v_fecha            VARCHAR2(8);
  v_dia_ini          DATE;
  v_dia_fin          DATE;

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
  select pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1)
  into v_fec_sist
  from dual;

  v_fecha := to_char(v_fec_sist,'DDMMYYYY');

  --Obtenemos el primer dia y el ultimo dia del mes
  v_dia_ini := trunc(v_fec_sist,'month');
  v_dia_fin := trunc(last_day(v_fec_sist));

-- Abrir archivo
v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'.txt','W',32767);

-- Colocar el titulo a los campos
v_linetit := 'FECHA'||CHR(9)||'COD_OFICINA'||CHR(9)||'NRO_ASIENTO'||CHR(9)||'NRO_LINEA'||CHR(9)||'COD_RUBRO'||CHR(9)||
              'DESCRIPCION'||CHR(9)||'TIP_MOVIMIENTO'||CHR(9)||'MTO_RUBRO'||CHR(9)||'MTO_LOCAL'||CHR(9)||
             'REF_MOVIMIENTO';

utl_file.put_line(v_file,v_linetit);

-- Definir una linea en blanco para separar los datos del titulo de los campos
v_linetit := ' ';
utl_file.put_line(v_file,v_linetit);

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN cu_agregado_uno(v_dia_ini, v_dia_fin) LOOP

    --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
  v_line := to_char(rec.fecha)||chr(9)||to_char(rec.cod_oficina)||chr(9)||to_char(rec.nro_asiento)||chr(9)||to_char(rec.nro_linea)||chr(9)||
            to_char(rec.cod_rubro)||chr(9)||to_char(rec.descripcion)||chr(9)||to_char(rec.tip_movimiento)||chr(9)||
            to_char(rec.mto_rubro,'999999999999D00')||chr(9)||to_char(rec.mto_local,'999999999999D00')||chr(9)||
            to_char(rec.ref_movimiento);


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

  EXIT WHEN cu_agregado_uno%NOTFOUND;
END LOOP;
--Escribes la linea en el fichero
UTL_FILE.PUT_LINE(v_file, v_buffer);

--Cerrar el handler al fichero
UTL_FILE.FCLOSE(v_file);
COMMIT;

  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_respuesta := pa_file_ftp.fu_put_ascii(pa_rpc_aut.g_ip, pa_rpc_aut.g_port, pa_rpc_aut.g_user,
                                          pa_rpc_aut.g_pass, pa_rpc_aut.g_repository,
                                          v_name||'.txt', g_amaral||v_name||'_'||v_fecha||'.txt');

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','IMPUESTO_VA_UNO');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte Impuestos al Valor Agregado 1 a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_amaral||'

    Nombre del Archivo: '||v_name||'_'||v_fecha||'.txt';

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error    := null;

    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, v_name||'_'||v_fecha||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;

    --Enviamos el mail a soporte
     -- Obtenemos direccion de correo de soporte
     v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error Reporte Impuestos al Valor Agregado 1 a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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
END pr_imp_va_uno;
-------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------
-- Impuestos al Valor Agregado 2
PROCEDURE pr_imp_va_dos
IS
CURSOR cu_agregado_dos(p_fecha_des DATE, p_fecha_has DATE) IS
        select d.fecha, d.cod_oficina, d.nro_asiento, d.nro_linea, d.cod_rubro, d.descripcion,
               d.tip_movimiento, decode(d.tip_movimiento,'D',d.mto_mon_rubro*-1,d.mto_mon_rubro) mto_rubro,
               decode(d.tip_movimiento,'D',d.mto_mon_local*-1,d.mto_mon_local) mto_local, d.ref_movimiento
        from cb_asientos_det_his d
        where d.fecha between p_fecha_des and p_fecha_has
        and d.cod_rubro in ('240102440100199' /*IMPUESTO AL VALOR AGREGADO - 10%*/, '240102440100299' /*IMPUESTO AL VALOR AGREGADO - 5%*/)
        order by 1;

  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'impuesto_va_dos'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_fec_sist         DATE;
  v_fecha            VARCHAR2(8);
  v_dia_ini          DATE;
  v_dia_fin          DATE;

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
  select pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1)
  into v_fec_sist
  from dual;

  v_fecha := to_char(v_fec_sist,'DDMMYYYY');

  --Obtenemos el primer dia y el ultimo dia del mes
  v_dia_ini := trunc(v_fec_sist,'month');
  v_dia_fin := trunc(last_day(v_fec_sist));

-- Abrir archivo
v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'.txt','W',32767);

-- Colocar el titulo a los campos
v_linetit := 'FECHA'||CHR(9)||'COD_OFICINA'||CHR(9)||'NRO_ASIENTO'||CHR(9)||'NRO_LINEA'||CHR(9)||'COD_RUBRO'||CHR(9)||
             'DESCRIPCION'||CHR(9)||'TIP_MOVIMIENTO'||CHR(9)||'MTO_RUBRO'||CHR(9)||'MTO_LOCAL'||CHR(9)||
             'REF_MOVIMIENTO';

utl_file.put_line(v_file,v_linetit);

-- Definir una linea en blanco para separar los datos del titulo de los campos
v_linetit := ' ';
utl_file.put_line(v_file,v_linetit);

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN cu_agregado_dos(v_dia_ini, v_dia_fin) LOOP

    --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
  v_line := to_char(rec.fecha)||chr(9)||to_char(rec.cod_oficina)||chr(9)||to_char(rec.nro_asiento)||chr(9)||to_char(rec.nro_linea)||chr(9)||
            to_char(rec.cod_rubro)||chr(9)||to_char(rec.descripcion)||chr(9)||to_char(rec.tip_movimiento)||chr(9)||
            to_char(rec.mto_rubro,'999999999999D00')||chr(9)||to_char(rec.mto_local,'999999999999D00')||chr(9)||
            to_char(rec.ref_movimiento);

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

  EXIT WHEN cu_agregado_dos%NOTFOUND;
END LOOP;
--Escribes la linea en el fichero
UTL_FILE.PUT_LINE(v_file, v_buffer);

--Cerrar el handler al fichero
UTL_FILE.FCLOSE(v_file);
COMMIT;

  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_respuesta := pa_file_ftp.fu_put_ascii(pa_rpc_aut.g_ip, pa_rpc_aut.g_port, pa_rpc_aut.g_user,
                                          pa_rpc_aut.g_pass, pa_rpc_aut.g_repository,
                                          v_name||'.txt', g_amaral||v_name||'_'||v_fecha||'.txt');

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','IMPUESTO_VA_DOS');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte Impuestos al Valor Agregado 2 a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_amaral||'

    Nombre del Archivo: '||v_name||'_'||v_fecha||'.txt';

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error    := null;

    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, v_name||'_'||v_fecha||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;

    --Enviamos el mail a soporte
     -- Obtenemos direccion de correo de soporte
     v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error Reporte Impuestos al Valor Agregado 2 a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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
END pr_imp_va_dos;
-------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------
-- Libro de Compras
PROCEDURE pr_lib_compra
IS
CURSOR cu_lib_compra(p_fecha_des DATE, p_fecha_has DATE) IS
        select b.nro_factura, b.nro_timbrado, b.fecha, b.cod_persona, b.raz_social,
               b.nro_documento, b.mto_gravado_5, b.mto_gravado_10, b.impuesto_5, b.impuesto_10
          from cb_lib_compras b
          where b.fecha between p_fecha_des and p_fecha_has;

  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'libro_compra'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_fec_sist         DATE;
  v_fecha            VARCHAR2(8);
  v_dia_ini          DATE;
  v_dia_fin          DATE;

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
  select pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1)
  into v_fec_sist
  from dual;

  v_fecha := to_char(v_fec_sist,'DDMMYYYY');

  --Obtenemos el primer dia y el ultimo dia del mes
  v_dia_ini := trunc(v_fec_sist,'month');
  v_dia_fin := trunc(last_day(v_fec_sist));

-- Abrir archivo
v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'.txt','W',32767);

-- Colocar el titulo a los campos
v_linetit := 'NRO_FACTURA'||CHR(9)||'NRO_TIMBRADO'||CHR(9)||'FECHA'||CHR(9)||'COD_PERSONA'||CHR(9)||'RAZ_SOCIAL'||CHR(9)||
             'NRO_DOCUMENTO'||CHR(9)||'MTO_GRAVADO_5'||CHR(9)||'MTO_GRAVADO_10'||CHR(9)||'IMPUESTO_5'||CHR(9)||'IMPUESTO_10';

utl_file.put_line(v_file,v_linetit);

-- Definir una linea en blanco para separar los datos del titulo de los campos
v_linetit := ' ';
utl_file.put_line(v_file,v_linetit);

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN cu_lib_compra(v_dia_ini, v_dia_fin) LOOP

    --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
  v_line := to_char(rec.nro_factura)||chr(9)||to_char(rec.nro_timbrado)||chr(9)||to_char(rec.fecha)||chr(9)||to_char(rec.cod_persona)||chr(9)||
            to_char(rec.raz_social)||chr(9)||to_char(rec.nro_documento)||chr(9)||to_char(rec.mto_gravado_5,'999999999999D00')||chr(9)||
            to_char(rec.mto_gravado_10,'999999999999D00')||chr(9)||to_char(rec.impuesto_5,'999999999999D00')||chr(9)||to_char(rec.impuesto_10,'999999999999D00');

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

  EXIT WHEN cu_lib_compra%NOTFOUND;
END LOOP;
--Escribes la linea en el fichero
UTL_FILE.PUT_LINE(v_file, v_buffer);

--Cerrar el handler al fichero
UTL_FILE.FCLOSE(v_file);
COMMIT;

  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_respuesta := pa_file_ftp.fu_put_ascii(pa_rpc_aut.g_ip, pa_rpc_aut.g_port, pa_rpc_aut.g_user,
                                          pa_rpc_aut.g_pass, pa_rpc_aut.g_repository,
                                          v_name||'.txt', g_amaral||v_name||'_'||v_fecha||'.txt');

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','LIBRO_COMPRA');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte Libro de Compras a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_amaral||'

    Nombre del Archivo: '||v_name||'_'||v_fecha||'.txt';

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error    := null;

    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, v_name||'_'||v_fecha||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;

    --Enviamos el mail a soporte
     -- Obtenemos direccion de correo de soporte
     v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error Libro de Compras a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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
END pr_lib_compra;
-------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------
-- Libro de Compras Detallado
PROCEDURE pr_lib_comp_det
IS
CURSOR cu_lib_comp_det(p_fecha_des DATE, p_fecha_has DATE) IS
        select b.nro_factura, b.nro_timbrado, b.fecha, b.cod_persona, b.raz_social, b.nro_documento,
               b.mto_gravado_5, b.mto_gravado_10, b.impuesto_5, b.impuesto_10, p.fec_pago, b.fec_pago fec_pago_libro_iva,
               p.cod_ofi_origen, pd.nro_linea, pd.cod_oficina, fue_obt_des_oficina(pd.cod_oficina) des_oficina, pd.cod_area,
               pd.val_unitario, pd.cantidad, pd.val_compra, pd.tip_impuesto, pd.val_impuesto, pd.mto_neto, pd.val_total
        from cb_lib_compras b, pv_compras p, pv_compras_det pd
        where b.nro_factura = p.nro_factura
        and p.cod_compra = pd.cod_compra
        and b.cod_ent_proveedor = p.cod_ent_proveedor
        and b.fecha between p_fecha_des and p_fecha_has
        order by p.fec_pago, p.nro_factura, pd.nro_linea;

  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'libro_compra_det'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_fec_sist         DATE;
  v_fecha            VARCHAR2(8);
  v_dia_ini          DATE;
  v_dia_fin          DATE;

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
  select pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1)
  into v_fec_sist
  from dual;

  v_fecha := to_char(v_fec_sist,'DDMMYYYY');

  --Obtenemos el primer dia y el ultimo dia del mes
  v_dia_ini := trunc(v_fec_sist,'month');
  v_dia_fin := trunc(last_day(v_fec_sist));

-- Abrir archivo
v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'.txt','W',32767);

-- Colocar el titulo a los campos
v_linetit := 'NRO_FACTURA'||CHR(9)||'NRO_TIMBRADO'||CHR(9)||'FECHA'||CHR(9)||'COD_PERSONA'||CHR(9)||'RAZ_SOCIAL'||CHR(9)||
             'NRO_DOCUMENTO'||CHR(9)||'MTO_GRAVADO_5'||CHR(9)||'MTO_GRAVADO_10'||CHR(9)||'IMPUESTO_5'||CHR(9)||'IMPUESTO_10'||CHR(9)||
             'FEC_PAGO'||CHR(9)||'FEC_PAGO_LIBRO_IVA'||CHR(9)||'COD_OFI_ORIGEN'||CHR(9)||'NRO_LINEA'||CHR(9)||'COD_OFICINA'||CHR(9)||
             'DES_OFICINA'||CHR(9)||'COD_AREA'||CHR(9)||'VAL_UNITARIO'||CHR(9)||'CANTIDAD'||CHR(9)||'VAL_COMPRA'||CHR(9)||
             'TIP_IMPUESTO'||CHR(9)||'VAL_IMPUESTO'||CHR(9)||'MTO_NETO'||CHR(9)||'VAL_TOTAL';

utl_file.put_line(v_file,v_linetit);

-- Definir una linea en blanco para separar los datos del titulo de los campos
v_linetit := ' ';
utl_file.put_line(v_file,v_linetit);

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN cu_lib_comp_det(v_dia_ini, v_dia_fin) LOOP

    --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
  v_line := to_char(rec.nro_factura)||chr(9)||to_char(rec.nro_timbrado)||chr(9)||to_char(rec.fecha)||chr(9)||to_char(rec.cod_persona)||chr(9)||
            to_char(rec.raz_social)||chr(9)||to_char(rec.nro_documento)||chr(9)||to_char(rec.mto_gravado_5,'999999999999D00')||chr(9)||
            to_char(rec.mto_gravado_10,'999999999999D00')||chr(9)||to_char(rec.impuesto_5,'999999999999D00')||chr(9)||to_char(rec.impuesto_10,'999999999999D00')||chr(9)||
            to_char(rec.fec_pago)||chr(9)||to_char(rec.fec_pago_libro_iva)||chr(9)||to_char(rec.cod_ofi_origen)||chr(9)||
            to_char(rec.nro_linea)||chr(9)||to_char(rec.cod_oficina)||chr(9)||to_char(rec.des_oficina)||chr(9)||
            to_char(rec.cod_area)||chr(9)||to_char(rec.val_unitario,'999999999999D00')||chr(9)||to_char(rec.cantidad)||chr(9)||
            to_char(rec.val_compra,'999999999999D00')||chr(9)||to_char(rec.tip_impuesto)||chr(9)||
            to_char(rec.val_impuesto,'999999999999D00')||chr(9)||to_char(rec.mto_neto,'999999999999D00')||chr(9)||to_char(rec.val_total,'999999999999D00');

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

  EXIT WHEN cu_lib_comp_det%NOTFOUND;
END LOOP;
--Escribes la linea en el fichero
UTL_FILE.PUT_LINE(v_file, v_buffer);

--Cerrar el handler al fichero
UTL_FILE.FCLOSE(v_file);
COMMIT;

  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_respuesta := pa_file_ftp.fu_put_ascii(pa_rpc_aut.g_ip, pa_rpc_aut.g_port, pa_rpc_aut.g_user,
                                          pa_rpc_aut.g_pass, pa_rpc_aut.g_repository,
                                          v_name||'.txt', g_amaral||v_name||'_'||v_fecha||'.txt');

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','LIBRO_COMPRA_DET');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte Libro de Compras Detallado a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_amaral||'

    Nombre del Archivo: '||v_name||'_'||v_fecha||'.txt';

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error    := null;

    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, v_name||'_'||v_fecha||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;

    --Enviamos el mail a soporte
     -- Obtenemos direccion de correo de soporte
     v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error Libro de Compras Detallado a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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
END pr_lib_comp_det;
-------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------
-- Retencion Iva
PROCEDURE pr_reten_iva
IS
CURSOR cu_ret_iva(p_fecha_des DATE, p_fecha_has DATE) IS
        select d.fecha, d.cod_oficina, d.nro_asiento, d.nro_linea, d.cod_rubro, d.descripcion,
               d.tip_movimiento, decode(d.tip_movimiento,'D',d.mto_mon_rubro*-1,d.mto_mon_rubro) mto_rubro,
               decode(d.tip_movimiento,'D',d.mto_mon_local*-1,d.mto_mon_local) mto_local, d.ref_movimiento
        from cb_asi_automaticos_det d
        where d.fecha between p_fecha_des and p_fecha_has
        and d.cod_rubro = '240102420101299' /*RETENCION IVA - AGENTE DE RETENCION*/
        order by 1;

  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'retencion_iva'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_fec_sist         DATE;
  v_fecha            VARCHAR2(8);
  v_dia_ini          DATE;
  v_dia_fin          DATE;

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
  select pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1)
  into v_fec_sist
  from dual;

  v_fecha := to_char(v_fec_sist,'DDMMYYYY');

  --Obtenemos el primer dia y el ultimo dia del mes
  v_dia_ini := trunc(v_fec_sist,'month');
  v_dia_fin := trunc(last_day(v_fec_sist));

-- Abrir archivo
v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'.txt','W',32767);

-- Colocar el titulo a los campos
v_linetit := 'FECHA'||CHR(9)||'COD_OFICINA'||CHR(9)||'NRO_ASIENTO'||CHR(9)||'NRO_LINEA'||CHR(9)||'COD_RUBRO'||CHR(9)||
             'DESCRIPCION'||CHR(9)||'TIP_MOVIMIENTO'||CHR(9)||'MTO_RUBRO'||CHR(9)||'MTO_LOCAL'||CHR(9)||'REF_MOVIMIENTO';

utl_file.put_line(v_file,v_linetit);

-- Definir una linea en blanco para separar los datos del titulo de los campos
v_linetit := ' ';
utl_file.put_line(v_file,v_linetit);

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN cu_ret_iva(v_dia_ini, v_dia_fin) LOOP

    --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
  v_line := to_char(rec.fecha)||chr(9)||to_char(rec.cod_oficina)||chr(9)||to_char(rec.nro_asiento)||chr(9)||to_char(rec.nro_linea)||chr(9)||
            to_char(rec.cod_rubro)||chr(9)||to_char(rec.descripcion)||chr(9)||to_char(rec.tip_movimiento)||chr(9)||
            to_char(rec.mto_rubro,'999999999999D00')||chr(9)||to_char(rec.mto_local,'999999999999D00')||chr(9)||to_char(rec.ref_movimiento);

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

  EXIT WHEN cu_ret_iva%NOTFOUND;
END LOOP;
--Escribes la linea en el fichero
UTL_FILE.PUT_LINE(v_file, v_buffer);

--Cerrar el handler al fichero
UTL_FILE.FCLOSE(v_file);
COMMIT;

  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_respuesta := pa_file_ftp.fu_put_ascii(pa_rpc_aut.g_ip, pa_rpc_aut.g_port, pa_rpc_aut.g_user,
                                          pa_rpc_aut.g_pass, pa_rpc_aut.g_repository,
                                          v_name||'.txt', g_amaral||v_name||'_'||v_fecha||'.txt');

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','RETENCION_IVA');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte Retencion Iva a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_amaral||'

    Nombre del Archivo: '||v_name||'_'||v_fecha||'.txt';

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error    := null;

    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, v_name||'_'||v_fecha||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;

    --Enviamos el mail a soporte
     -- Obtenemos direccion de correo de soporte
     v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error Reporte Retencion Iva a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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
END pr_reten_iva;
-------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------
-- Libro de Ventas
PROCEDURE pr_lib_vta
IS
CURSOR cu_lib_venta(p_fecha_des DATE, p_fecha_has DATE) IS
select b.nro_factura,
       b.nro_timbrado,
       b.fecha,
       b.cod_persona,
       b.nom_completo,
       b.nro_documento,
       b.mto_gravado_5,
       b.mto_gravado_10,
       b.mto_gravado_5_gs,
       b.mto_gravado_10_gs,
       b.impuesto_5,
       b.impuesto_10,
       case
         when substr(b.nro_factura, 5, 3) = '011' then
          (nvl(b.impuesto_5_gs, 0) * -1)
         when substr(b.nro_factura, 5, 3) <> '011' then
          nvl(b.impuesto_5_gs, 0)
       end impuesto_5_gs,
       case
         when substr(b.nro_factura, 5, 3) = '011' then
          (nvl(b.impuesto_10_gs, 0) * -1)
         when substr(b.nro_factura, 5, 3) <> '011' then
          nvl(b.impuesto_10_gs, 0)
       end impuesto_10_gs
  from cb_lib_ventas b
 where b.fecha between p_fecha_des and p_fecha_has;

  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'libro_venta'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_fec_sist         DATE;
  v_fecha            VARCHAR2(8);
  v_dia_ini          DATE;
  v_dia_fin          DATE;

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
  select pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1)
  into v_fec_sist
  from dual;

  v_fecha := to_char(v_fec_sist,'DDMMYYYY');

  --Obtenemos el primer dia y el ultimo dia del mes
  v_dia_ini := trunc(v_fec_sist,'month');
  v_dia_fin := trunc(last_day(v_fec_sist));

-- Abrir archivo
v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'.txt','W',32767);

-- Colocar el titulo a los campos
v_linetit := 'NRO_FACTURA'||CHR(9)||'NRO_TIMBRADO'||CHR(9)||'FECHA'||CHR(9)||'COD_PERSONA'||CHR(9)||'NOM_COMPLETO'||CHR(9)||
             'NRO_DOCUMENTO'||CHR(9)||'MTO_GRAVADO_5'||CHR(9)||'MTO_GRAVADO_10'||CHR(9)||'MTO_GRAVADO_5_GS'||CHR(9)||
             'MTO_GRAVADO_10_GS'||CHR(9)||'IMPUESTO_5'||CHR(9)||'IMPUESTO_10'||CHR(9)||'IMPUESTO_5_GS'||CHR(9)||'IMPUESTO_10_GS';

utl_file.put_line(v_file,v_linetit);

-- Definir una linea en blanco para separar los datos del titulo de los campos
v_linetit := ' ';
utl_file.put_line(v_file,v_linetit);

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN cu_lib_venta(v_dia_ini, v_dia_fin) LOOP

    --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
  v_line := to_char(rec.nro_factura)||chr(9)||to_char(rec.nro_timbrado)||chr(9)||to_char(rec.fecha)||chr(9)||to_char(rec.cod_persona)||chr(9)||
            to_char(rec.nom_completo)||chr(9)||to_char(rec.nro_documento)||chr(9)||to_char(rec.mto_gravado_5,'999999999999D00')||chr(9)||
            to_char(rec.mto_gravado_10,'999999999999D00')||chr(9)||to_char(rec.mto_gravado_5_gs,'999999999999D00')||chr(9)||
            to_char(rec.mto_gravado_10_gs,'999999999999D00')||chr(9)||to_char(rec.impuesto_5,'999999999999D00')||chr(9)||
            to_char(rec.impuesto_10,'999999999999D00')||chr(9)||to_char(rec.impuesto_5_gs,'999999999999D00')||chr(9)||to_char(rec.impuesto_10_gs,'999999999999D00');

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

  EXIT WHEN cu_lib_venta%NOTFOUND;
END LOOP;
--Escribes la linea en el fichero
UTL_FILE.PUT_LINE(v_file, v_buffer);

--Cerrar el handler al fichero
UTL_FILE.FCLOSE(v_file);
COMMIT;

  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_respuesta := pa_file_ftp.fu_put_ascii(pa_rpc_aut.g_ip, pa_rpc_aut.g_port, pa_rpc_aut.g_user,
                                          pa_rpc_aut.g_pass, pa_rpc_aut.g_repository,
                                          v_name||'.txt', g_amaral||v_name||'_'||v_fecha||'.txt');

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','LIBRO_VENTA');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte Libro de Ventas a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_amaral||'

    Nombre del Archivo: '||v_name||'_'||v_fecha||'.txt';

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error    := null;

    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, v_name||'_'||v_fecha||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;

    --Enviamos el mail a soporte
     -- Obtenemos direccion de correo de soporte
     v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error Reporte Libro de Ventas a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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
END pr_lib_vta;
-------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------
-- Libro de Ventas Detallado
PROCEDURE pr_lib_vta_det
IS
CURSOR cu_lib_vent_det(p_fecha_des DATE, p_fecha_has DATE) IS
select d.nro_factura,
       d.nro_timbrado,
       d.cod_ofi_origen,
       d.fecha fec_movimiento,
       d.hora,
       d.cod_usuario,
       d.descripcion,
       d.cod_moneda,
       case
         when substr(d.nro_factura, 5, 3) = '011' then
          (nvl(d.impuesto_5_gs, 0) * -1)
         when substr(d.nro_factura, 5, 3) <> '011' then
          nvl(d.impuesto_5_gs, 0)
       end impuesto_5_gs,
       case
         when substr(d.nro_factura, 5, 3) = '011' then
          (nvl(d.impuesto_10_gs, 0) * -1)
         when substr(d.nro_factura, 5, 3) <> '011' then
          nvl(d.impuesto_10_gs, 0)
       end impuesto_10_gs,
       decode(substr(d.nro_factura, 5, 3),
              '011',
              (nvl(d.impuesto_5_gs, 0) + nvl(d.impuesto_10_gs, 0)) * -1,
              (nvl(d.impuesto_5_gs, 0) + nvl(d.impuesto_10_gs, 0))) iva
  from cb_lib_ventas_det d
 where d.fecha between p_fecha_des and p_fecha_has;

  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'libro_venta_det'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_fec_sist         DATE;
  v_fecha            VARCHAR2(8);
  v_dia_ini          DATE;
  v_dia_fin          DATE;

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
  select pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1)
  into v_fec_sist
  from dual;

  v_fecha := to_char(v_fec_sist,'DDMMYYYY');

  --Obtenemos el primer dia y el ultimo dia del mes
  v_dia_ini := trunc(v_fec_sist,'month');
  v_dia_fin := trunc(last_day(v_fec_sist));

-- Abrir archivo
v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'.txt','W',32767);
-- Colocar el titulo a los campos
v_linetit := 'NRO_FACTURA'||CHR(9)||'NRO_TIMBRADO'||CHR(9)
||'COD_OFI_ORIGEN'||CHR(9)||'FEC_MOVIMIENTO'||CHR(9)
||'HORA'||CHR(9)||'COD_USUARIO'||CHR(9)||'DESCRIPCION'||CHR(9)
||'COD_MONEDA'||CHR(9)||'IMPUESTO_5_GS'||CHR(9)||'IMPUESTO_10_GS'
||CHR(9)||'IVA';

utl_file.put_line(v_file,v_linetit);

-- Definir una linea en blanco para separar los datos del titulo de los campos
v_linetit := ' ';
utl_file.put_line(v_file,v_linetit);

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN cu_lib_vent_det(v_dia_ini, v_dia_fin) LOOP
--Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
  v_line := to_char(rec.nro_factura)||chr(9)||
            to_char(rec.nro_timbrado)||chr(9)||
            to_char(rec.cod_ofi_origen)||chr(9)||
            to_char(rec.fec_movimiento)||chr(9)||
            to_char(rec.hora)||chr(9)||
            to_char(rec.cod_usuario)||chr(9)||
            to_char(rec.descripcion)||chr(9)||
            to_char(rec.cod_moneda)||chr(9)||
            to_char(rec.impuesto_5_gs)||chr(9)||
            to_char(rec.impuesto_10_gs)||chr(9)||
            to_char(rec.iva);

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

  EXIT WHEN cu_lib_vent_det%NOTFOUND;
END LOOP;
--Escribes la linea en el fichero
UTL_FILE.PUT_LINE(v_file, v_buffer);

--Cerrar el handler al fichero
UTL_FILE.FCLOSE(v_file);
COMMIT;

  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_respuesta := pa_file_ftp.fu_put_ascii(pa_rpc_aut.g_ip,
  pa_rpc_aut.g_port, pa_rpc_aut.g_user,pa_rpc_aut.g_pass,
  pa_rpc_aut.g_repository,v_name||'.txt',
  g_amaral||v_name||'_'||v_fecha||'.txt');

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','LIBRO_VENTA_DET');

      -- Damos valor a los demas datos
v_asunto := 'Reporte Libro de Ventas Detallado a la fecha '
||v_fec_sist||'.';
v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_amaral||'

    Nombre del Archivo: '||v_name||'_'||v_fecha||'.txt';

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error    := null;

    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, v_name||'_'||v_fecha||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;

    --Enviamos el mail a soporte
     -- Obtenemos direccion de correo de soporte
     v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error Reporte Libro de Ventas Detallado a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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
END pr_lib_vta_det;
-------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------
-- Pagos a Proveedores (Compras Mensuales)
PROCEDURE pr_pag_prov_cm
IS
CURSOR cu_pag_prov(p_fecha_des DATE, p_fecha_has DATE) IS
select p.fecha, p.cod_ent_proveedor, p.nom_proveedor, p.tip_comprobante,p.nro_factura,
       p.timbrado,p.ruc, upper(p.concepto) concepto, p.cod_moneda,p.cotizacion,
       p.estado, p.cod_mon_pago,pd.nro_linea, pd.cod_transaccion,
       fug_obt_des_transaccion(pd.cod_modulo, pd.cod_modalidad, pd.cod_transaccion)
       des_transaccion,pd.cod_articulo, pd.cod_oficina, fue_obt_des_oficina
       (pd.cod_oficina)des_oficina,pd.cod_area, a.descripcion des_area,
       pd.cantidad,pd.val_unitario,pd.tip_impuesto,pd.descripcion,
       pd.mto_neto, pd.val_impuesto,pd.val_total,
       decode(p.for_pago,'C','Credito en cuenta','G','Cheque Gerencia',
       'E','Efectivo','R','Rubro contable')forma_pago
 from pv_compras p, pv_compras_det pd, ba_areas a
where p.cod_compra = pd.cod_compra
  and p.fecha between p_fecha_des and p_fecha_has
  and p.cod_cau_anulacion is null
  and pd.cod_oficina = a.cod_oficina
  and pd.cod_area = a.cod_area
order by 1, 2, 5;

  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'pago_prov_cm'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_fec_sist         DATE;
  v_fecha            VARCHAR2(8);
  v_dia_ini          DATE;
  v_dia_fin          DATE;

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
  select pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1)
  into v_fec_sist
  from dual;

  v_fecha := to_char(v_fec_sist,'DDMMYYYY');

  --Obtenemos el primer dia y el ultimo dia del mes
  v_dia_ini := trunc(v_fec_sist,'month');
  v_dia_fin := trunc(last_day(v_fec_sist));

-- Abrir archivo
v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'.txt','W',32767);

-- Colocar el titulo a los campos
v_linetit := 'FECHA'||CHR(9)||'COD_ENT_PROVEEDOR'||CHR(9)||'NOM_PROVEEDOR'||CHR(9)||
             'TIP_COMPROBANTE'||CHR(9)||'NRO_FACTURA'||CHR(9)||'TIMBRADO'||CHR(9)||
             'RUC'||CHR(9)||'CONCEPTO'||CHR(9)||'COD_MONEDA'||CHR(9)||'COTIZACION'||CHR(9)||
             'ESTADO'||CHR(9)||'COD_MON_PAGO'||CHR(9)||'NRO_LINEA'||CHR(9)||
             'COD_TRANSACCION'||CHR(9)||'DES_TRANSACCION'||CHR(9)||'COD_ARTICULO'||CHR(9)||
             'COD_OFICINA'||CHR(9)||'DES_OFICINA'||CHR(9)||'COD_AREA'||CHR(9)||
             'DES_AREA'||CHR(9)||'CANTIDAD'||CHR(9)||'VAL_UNITARIO'||CHR(9)||
             'TIP_IMPUESTO'||CHR(9)||'DESCRIPCION'||CHR(9)||'MTO_NETO'||CHR(9)||
             'VAL_IMPUESTO'||CHR(9)||'VAL_TOTAL'||CHR(9)||'FORMA_PAGO';

utl_file.put_line(v_file,v_linetit);

-- Definir una linea en blanco para separar los datos del titulo de los campos
v_linetit := ' ';
utl_file.put_line(v_file,v_linetit);

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN cu_pag_prov(v_dia_ini, v_dia_fin) LOOP

    --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
  v_line := to_char(rec.FECHA)||chr(9)||to_char(rec.COD_ENT_PROVEEDOR)||chr(9)||
            to_char(rec.NOM_PROVEEDOR)||chr(9)||to_char(rec.TIP_COMPROBANTE)||chr(9)||
            to_char(rec.NRO_FACTURA)||chr(9)||to_char(rec.TIMBRADO)||chr(9)||
            to_char(rec.RUC)||chr(9)||to_char(rec.CONCEPTO)||chr(9)||
            to_char(rec.COD_MONEDA)||chr(9)||to_char(rec.COTIZACION)||chr(9)||
            to_char(rec.ESTADO)||chr(9)||to_char(rec.COD_MON_PAGO)||chr(9)||
            to_char(rec.NRO_LINEA)||chr(9)||to_char(rec.COD_TRANSACCION)||chr(9)||
            to_char(rec.DES_TRANSACCION)||chr(9)||to_char(rec.COD_ARTICULO)||chr(9)||
            to_char(rec.COD_OFICINA)||chr(9)||to_char(rec.DES_OFICINA)||chr(9)||
            to_char(rec.COD_AREA)||chr(9)||to_char(rec.DES_AREA)||chr(9)||
            to_char(rec.CANTIDAD)||chr(9)||
            to_char(rec.VAL_UNITARIO,'999999999999D00')||chr(9)||
            to_char(rec.TIP_IMPUESTO)||chr(9)||to_char(rec.DESCRIPCION)||chr(9)||
            to_char(rec.MTO_NETO,'999999999999D00')||chr(9)||
            to_char(rec.VAL_IMPUESTO,'999999999999D00')||chr(9)||
            to_char(rec.VAL_TOTAL,'999999999999D00')||chr(9)||
            to_char(rec.FORMA_PAGO);

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

  EXIT WHEN cu_pag_prov%NOTFOUND;
END LOOP;
--Escribes la linea en el fichero
UTL_FILE.PUT_LINE(v_file, v_buffer);

--Cerrar el handler al fichero
UTL_FILE.FCLOSE(v_file);
COMMIT;

  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_respuesta := pa_file_ftp.fu_put_ascii(pa_rpc_aut.g_ip, pa_rpc_aut.g_port, pa_rpc_aut.g_user,
                                          pa_rpc_aut.g_pass, pa_rpc_aut.g_repository,
                                          v_name||'.txt', g_compras||v_name||'_'||v_fecha||'.txt');

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      -- v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','PAGO_PROVEEDOR_CM');
      --DYDMR-1810 / mayo-2015 / se cambia la tabla donde se guardan los valores de 
      --correos para poder realizar el mantenimiento por por pantalla
      V_PARA := fug_obt_pardinamico('REP_PAG_PROVEEDOR_CM');
      
      -- Damos valor a los demas datos
      v_asunto := 'Reporte Pagos a Proveedores (Compras Mensuales) a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_compras||'

      Nombre del Archivo: '||v_name||'_'||v_fecha||'.txt';

      -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error    := null;

    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, v_name||'_'||v_fecha||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;

    --Enviamos el mail a soporte
     -- Obtenemos direccion de correo de soporte
     v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error Reporte Pagos a Proveedores (Compras Mensuales) a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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
END pr_pag_prov_cm;
-------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------
-- Inventario de Devengados Mensual al Cierre del Mes
PROCEDURE pr_inv_dev_mes
IS
CURSOR cu_inv_dev_mes IS
      select c.cod_persona, fue_obt_nom_persona(c.cod_persona) nombre,
             h.nro_cuenta, h.cod_moneda, h.cod_oficina, h.cod_modalidad, h.tip_interes, h.fec_ult_devengado,
             h.fec_inicio, h.fec_vencimiento,
             nvl(h.val_int_devengar,0) adev_fin_mes,
             nvl(h.dev_suspenso,0) sus_fin_mes,
             nvl(h.dev_acumulado,0) dev_acu_fin_mes,
             fub_obt_rub_transaccion(h.cod_modulo, h.cod_modalidad, 903, --codigo transaccion
                                     h.cod_moneda, c.cod_persona, fug_obt_plz_contable(h.fec_vencimiento - h.fec_inicio), 'D',
                                     h.estado, h.tip_renovacion, nvl(t.cat_riesgo,1), h.tip_interes, h.tipo, null, h.cod_sec_credito
                                    ) rubro_adevengar,

             fub_obt_rub_transaccion(h.cod_modulo, h.cod_modalidad, 947, --codigo transaccion
                                     h.cod_moneda, c.cod_persona, fug_obt_plz_contable(h.fec_vencimiento - h.fec_inicio), 'C',
                                     h.estado, h.tip_renovacion, t.cat_riesgo, h.tip_interes, h.tipo, null, h.cod_sec_credito
                                    ) rubro_suspenso
      from pr_cta_prestamos h, ge_cta_clientes c, ge_clientes t
      where  h.nro_cuenta=c.nro_cuenta
        and c.relacion='P'
        and c.cod_persona=t.cod_persona;

  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'inv_devengado_mes'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_fec_sist         DATE;
  v_fecha            VARCHAR2(8);

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
  select pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1)
  into v_fec_sist
  from dual;

  v_fecha := to_char(v_fec_sist,'DDMMYYYY');

-- Abrir archivo
v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'.txt','W',32767);

-- Colocar el titulo a los campos
v_linetit := 'COD_PERSONA'||CHR(9)||'NOMBRE'||CHR(9)||'NRO_CUENTA'||CHR(9)||'COD_MONEDA'||CHR(9)||'COD_OFICINA'||CHR(9)||
             'COD_MODALIDAD'||CHR(9)||'TIP_INTERES'||CHR(9)||'FEC_ULT_DEVENGADO'||CHR(9)||'FEC_INICIO'||CHR(9)||
             'FEC_VENCIMIENTO'||CHR(9)||'ADEV_FIN_MES'||CHR(9)||'SUS_FIN_MES'||CHR(9)||'DEV_ACU_FIN_MES'||CHR(9)||
             'RUBRO_ADEVENGAR'||CHR(9)||'RUBRO_SUSPENSO';

utl_file.put_line(v_file,v_linetit);

-- Definir una linea en blanco para separar los datos del titulo de los campos
v_linetit := ' ';
utl_file.put_line(v_file,v_linetit);

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN cu_inv_dev_mes LOOP

    --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
  v_line := to_char(rec.COD_PERSONA)||chr(9)||to_char(rec.NOMBRE)||chr(9)||to_char(rec.NRO_CUENTA)||chr(9)||to_char(rec.COD_MONEDA)||chr(9)||
            to_char(rec.COD_OFICINA)||chr(9)||to_char(rec.COD_MODALIDAD)||chr(9)||to_char(rec.TIP_INTERES)||chr(9)||to_char(rec.FEC_ULT_DEVENGADO)||chr(9)||
            to_char(rec.FEC_INICIO)||chr(9)||to_char(rec.FEC_VENCIMIENTO)||chr(9)||to_char(rec.ADEV_FIN_MES)||chr(9)||
            to_char(rec.SUS_FIN_MES)||chr(9)||to_char(rec.DEV_ACU_FIN_MES)||chr(9)||to_char(rec.RUBRO_ADEVENGAR)||chr(9)||to_char(rec.RUBRO_SUSPENSO);


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

  EXIT WHEN cu_inv_dev_mes%NOTFOUND;
END LOOP;
--Escribes la linea en el fichero
UTL_FILE.PUT_LINE(v_file, v_buffer);

--Cerrar el handler al fichero
UTL_FILE.FCLOSE(v_file);
COMMIT;

  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_respuesta := pa_file_ftp.fu_put_ascii(pa_rpc_aut.g_ip, pa_rpc_aut.g_port, pa_rpc_aut.g_user,
                                          pa_rpc_aut.g_pass, pa_rpc_aut.g_repository,
                                          v_name||'.txt', g_sistemas||v_name||'_'||v_fecha||'.txt');

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','INV_DEVENGADO_MENSUAL');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte Inventario de Devengados Mensual al Cierre del Mes a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_sistemas||'

    Nombre del Archivo: '||v_name||'_'||v_fecha||'.txt';

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
     v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
    it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error    := null;

    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, v_name||'_'||v_fecha||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;

    --Enviamos el mail a soporte
     -- Obtenemos direccion de correo de soporte
     v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error Reporte Inventario de Devengados Mensual al Cierre del Mes a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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
END pr_inv_dev_mes;
-------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------
-- Inventario de Bonos Subordinados al cierre del Mes
PROCEDURE pr_bonos_sub
IS
CURSOR cu_bonos_sub IS
      select bsserie, bsnumero, bscupon, bstitur, bssuc, bsnumclien, bsagente, bsmoneda, bsmonto,
             bsfemisi, bsvencim, bstipot, bstasa1, bstasa2, bstasa3, bstasa4, bslrm_lib, bsfeini,
             bsdeveng, bsusuario, bsfereg, bspigno
      from simgia_arbosubor ;

  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'bonos_sub_mes'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_fec_sist         DATE;
  v_fecha            VARCHAR2(8);

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
  -- CRO-JM-11/2014: Cambiamos la máscara de formato numérico por esta session:
     pre_cam_for_numerico('.,');

  -- Obtenemos la fecha del sistema
  select pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1)
  into v_fec_sist
  from dual;

  v_fecha := to_char(v_fec_sist,'DDMMYYYY');

-- Abrir archivo
v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'.txt','W',32767);

-- Colocar el titulo a los campos
v_linetit := 'BSSERIE'||CHR(9)||'BSNUMERO'||CHR(9)||'BSCUPON'||CHR(9)||'BSTITUR'||CHR(9)||'BSSUC'||CHR(9)||
             'BSNUMCLIEN'||CHR(9)||'BSAGENTE'||CHR(9)||'BSMONEDA'||CHR(9)||'BSMONTO'||CHR(9)||
             'BSFEMISI'||CHR(9)||'BSVENCIM'||CHR(9)||'BSTIPOT'||CHR(9)||'BSTASA1'||CHR(9)||'BSTASA2'||CHR(9)||
             'BSTASA3'||CHR(9)||'BSTASA4'||CHR(9)||'BSLRM_LIB'||CHR(9)||'BSFEINI'||CHR(9)||
             'BSDEVENG'||CHR(9)||'BSUSUARIO'||CHR(9)||'BSFEREG'||CHR(9)||'BSPIGNO'||CHR(9)||'FECHA_HIS';

utl_file.put_line(v_file,v_linetit);

-- Definir una linea en blanco para separar los datos del titulo de los campos
v_linetit := ' ';
utl_file.put_line(v_file,v_linetit);

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN cu_bonos_sub LOOP

    --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
    -- CRO-JM-10/2014: Se agrega máscara para los valores numericos ('NLS_NUMERIC_CHARACTERS = ''.,''')
    -- debido a: "error de conversión de carácter a número numérico o de valor" al realizar su ejecucion
 v_line := to_char(rec.BSSERIE)||chr(9)||to_char(rec.BSNUMERO)||chr(9)||to_char(rec.BSCUPON)||chr(9)||to_char(rec.BSTITUR)||chr(9)||
            to_char(rec.BSSUC)||chr(9)||to_char(rec.BSNUMCLIEN)||chr(9)||to_char(rec.BSAGENTE)||chr(9)||to_char(rec.BSMONEDA)||chr(9)||
            to_char(rec.BSMONTO,'999999999999D00', 'NLS_NUMERIC_CHARACTERS = ''.,''')||chr(9)||to_char(rec.BSFEMISI)||chr(9)||to_char(rec.BSVENCIM)||chr(9)||
            to_char(rec.BSTIPOT)||chr(9)||to_char(rec.BSTASA1,'999999999999D00', 'NLS_NUMERIC_CHARACTERS = ''.,''')||chr(9)||to_char(rec.BSTASA2,'999999999999D00', 'NLS_NUMERIC_CHARACTERS = ''.,''')||chr(9)||to_char(rec.BSTASA3,'999999999999D00', 'NLS_NUMERIC_CHARACTERS = ''.,''')||chr(9)||
            to_char(rec.BSTASA4,'999999999999D00', 'NLS_NUMERIC_CHARACTERS = ''.,''')||chr(9)||to_char(rec.BSLRM_LIB,'999999999999D00', 'NLS_NUMERIC_CHARACTERS = ''.,''')||chr(9)||to_char(rec.BSFEINI)||chr(9)||to_char(rec.BSDEVENG)||chr(9)||
            to_char(rec.BSUSUARIO)||chr(9)||to_char(rec.BSFEREG)||chr(9)||to_char(rec.BSPIGNO)||chr(9);


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

  EXIT WHEN cu_bonos_sub%NOTFOUND;
END LOOP;
--Escribes la linea en el fichero
UTL_FILE.PUT_LINE(v_file, v_buffer);

--Cerrar el handler al fichero
UTL_FILE.FCLOSE(v_file);
COMMIT;

  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_respuesta := pa_file_ftp.fu_put_ascii(pa_rpc_aut.g_ip, pa_rpc_aut.g_port, pa_rpc_aut.g_user,
                                          pa_rpc_aut.g_pass, pa_rpc_aut.g_repository,
                                          v_name||'.txt', g_finanzas||v_name||'_'||v_fecha||'.txt');

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','BONO_SUB_MES');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte Inventario de Bonos Subordinados al cierre del Mes a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_finanzas||'

    Nombre del Archivo: '||v_name||'_'||v_fecha||'.txt';

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
     v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
    it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error    := null;

    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, v_name||'_'||v_fecha||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;

    --Enviamos el mail a soporte
     -- Obtenemos direccion de correo de soporte
     v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error Reporte Inventario de Bonos Subordinados al cierre del Mes a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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
END pr_bonos_sub;
-------------------------------------------------------------------------------------------------------------------------------------

-- Inventarios de cartera activa y pasiva al cierre del Mes
PROCEDURE pr_cartera_mes
IS
CURSOR cu_cartera_mes IS

      select bf.cod_rubro, bf.cod_rub_externo, bf.descripcion, bf.cod_moneda, bf.cod_modalidad, bf.cod_oficina, bf.tip_saldo,
             bf.cod_persona, bf.nombre, bf.nro_cuenta, bf.sal_actual, bf.sal_mon_local, bf.val_tasa, bf.fec_inicio,
             bf.fec_vencimiento, bf.sal_promedio, pc.mto_capital monto_inicial,
             m.fec_inicio md_cta_documentos_fec_inicio, m.fec_insercion fecha_padre
      from bv_finanzas bf, pr_cta_prestamos pc, md_cta_documentos m
      where bf.nro_cuenta = pc.nro_cuenta(+)
        and bf.nro_cuenta = m.nro_cuenta(+)
      order by cod_rubro;

  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'cartera_mes'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_fec_sist         DATE;
  v_fecha            VARCHAR2(8);

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
  select pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1)
  into v_fec_sist
  from dual;

  v_fecha := to_char(v_fec_sist,'DDMMYYYY');

-- Abrir archivo
v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'.txt','W',32767);

-- Colocar el titulo a los campos
  v_linetit := 'COD_RUBRO'||CHR(9)||'COD_RUB_EXTERNO'||CHR(9)||'DESCRIPCION'||CHR(9)||'COD_MONEDA'||CHR(9)||'COD_MODALIDAD'||CHR(9)||
             'COD_OFICINA'||CHR(9)||'TIP_SALDO'||CHR(9)||'COD_PERSONA'||CHR(9)||'NOMBRE'||CHR(9)||
             'NRO_CUENTA'||CHR(9)||'SAL_ACTUAL'||CHR(9)||'SAL_MON_LOCAL'||CHR(9)||'VAL_TASA'||CHR(9)||'FEC_INICIO'||CHR(9)||
             'FEC_VENCIMIENTO'||CHR(9)||'SAL_PROMEDIO'||CHR(9)||'MONTO_INICIAL'||CHR(9)||
             'MD_CTA_DOCUMENTOS_FEC_INICIO'||CHR(9)||'FECHA_PADRE';

utl_file.put_line(v_file,v_linetit);

-- Definir una linea en blanco para separar los datos del titulo de los campos
v_linetit := ' ';
utl_file.put_line(v_file,v_linetit);

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN cu_cartera_mes LOOP

    --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
  v_line := to_char(rec.COD_RUBRO)||chr(9)||to_char(rec.COD_RUB_EXTERNO)||chr(9)||to_char(rec.DESCRIPCION)||chr(9)||
            to_char(rec.COD_MONEDA)||chr(9)||to_char(rec.COD_MODALIDAD)||chr(9)||to_char(rec.COD_OFICINA)||chr(9)||
            to_char(rec.TIP_SALDO)||chr(9)||to_char(rec.COD_PERSONA)||chr(9)||to_char(rec.NOMBRE)||chr(9)||to_char(rec.NRO_CUENTA)||chr(9)||
            to_char(rec.SAL_ACTUAL,'999999999999D00')||chr(9)||to_char(rec.SAL_MON_LOCAL,'999999999999D00')||chr(9)||
            to_char(rec.VAL_TASA,'999999999999D00')||chr(9)||to_char(rec.FEC_INICIO)||chr(9)||to_char(rec.FEC_VENCIMIENTO)||chr(9)||
            to_char(rec.SAL_PROMEDIO,'999999999999D00')||chr(9)||to_char(rec.MONTO_INICIAL,'999999999999D00')||chr(9)||
            to_char(rec.MD_CTA_DOCUMENTOS_FEC_INICIO)||chr(9)||to_char(rec.FECHA_PADRE);

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

  EXIT WHEN cu_cartera_mes%NOTFOUND;
END LOOP;
--Escribes la linea en el fichero
UTL_FILE.PUT_LINE(v_file, v_buffer);

--Cerrar el handler al fichero
UTL_FILE.FCLOSE(v_file);
COMMIT;

  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_respuesta := pa_file_ftp.fu_put_ascii(pa_rpc_aut.g_ip, pa_rpc_aut.g_port, pa_rpc_aut.g_user,
                                          pa_rpc_aut.g_pass, pa_rpc_aut.g_repository,
                                          v_name||'.txt', g_finanzas||v_name||'_'||v_fecha||'.txt');

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','INV_CARTERA_MES');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte Inventarios de cartera activa y pasiva al cierre del Mes a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_finanzas||'

    Nombre del Archivo: '||v_name||'_'||v_fecha||'.txt';

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
     v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
    it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error    := null;

    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, v_name||'_'||v_fecha||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;

    --Enviamos el mail a soporte
     -- Obtenemos direccion de correo de soporte
     v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error Reporte Inventarios de cartera activa y pasiva al cierre del Mes a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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
END pr_cartera_mes;
-------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------
-- Inventario de Cuotas de Préstamos de los Clientes
PROCEDURE pr_cuo_pres_cli
IS
CURSOR cu_pres_cli IS
    select cod_rubro, cod_rub_externo, descripcion, cod_moneda, cod_modalidad, cod_oficina, cod_persona,
           nombre, nro_cuenta, sal_capital, sal_mon_local, val_tasa, nro_cuota, fec_inicio, fec_vencimiento,
           sal_interes, cod_rubro_int
    from bv_cuo_prest_clientes;


  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'cuo_prest_clientes'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_fec_sist         DATE;
  v_fecha            VARCHAR2(8);

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
  select pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1)
  into v_fec_sist
  from dual;

  v_fecha := to_char(v_fec_sist,'DDMMYYYY');

-- Abrir archivo
v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'.txt','W',32767);

-- Colocar el titulo a los campos
v_linetit := 'COD_RUBRO'||CHR(9)||'COD_RUB_EXTERNO'||CHR(9)||'DESCRIPCION'||CHR(9)||'COD_MONEDA'||CHR(9)||'COD_MODALIDAD'||CHR(9)||
             'COD_OFICINA'||CHR(9)||'COD_PERSONA'||CHR(9)||'NOMBRE'||CHR(9)||'NRO_CUENTA'||CHR(9)||'SAL_CAPITAL'||CHR(9)||
             'SAL_MON_LOCAL'||CHR(9)||'VAL_TASA'||CHR(9)||'NRO_CUOTA'||CHR(9)||'FEC_INICIO'||CHR(9)||
             'FEC_VENCIMIENTO'||CHR(9)||'SAL_INTERES'||CHR(9)||'COD_RUBRO_INT';

utl_file.put_line(v_file,v_linetit);

-- Definir una linea en blanco para separar los datos del titulo de los campos
v_linetit := ' ';
utl_file.put_line(v_file,v_linetit);

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN cu_pres_cli LOOP

  --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
  v_line := to_char(rec.COD_RUBRO)||chr(9)||to_char(rec.COD_RUB_EXTERNO)||chr(9)||to_char(rec.DESCRIPCION)||chr(9)||to_char(rec.COD_MONEDA)||chr(9)||
            to_char(rec.COD_MODALIDAD)||chr(9)||to_char(rec.COD_OFICINA)||chr(9)||to_char(rec.COD_PERSONA)||chr(9)||to_char(rec.NOMBRE)||chr(9)||
            to_char(rec.NRO_CUENTA)||chr(9)||to_char(rec.SAL_CAPITAL,'999999999999D00')||chr(9)||to_char(rec.SAL_MON_LOCAL,'999999999999D00')||chr(9)||
            to_char(rec.VAL_TASA,'999999999999D0000')||chr(9)||to_char(rec.NRO_CUOTA)||chr(9)||to_char(rec.FEC_INICIO)||chr(9)||
            to_char(rec.FEC_VENCIMIENTO)||chr(9)||to_char(rec.SAL_INTERES,'999999999999D00')||chr(9)||to_char(rec.COD_RUBRO_INT);

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

   EXIT WHEN cu_pres_cli%NOTFOUND;
END LOOP;
--Escribes la linea en el fichero
UTL_FILE.PUT_LINE(v_file, v_buffer);

--Cerrar el handler al fichero
UTL_FILE.FCLOSE(v_file);
COMMIT;

  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_respuesta := pa_file_ftp.fu_put_ascii(pa_rpc_aut.g_ip, pa_rpc_aut.g_port, pa_rpc_aut.g_user,
                                          pa_rpc_aut.g_pass, pa_rpc_aut.g_repository,
                                          v_name||'.txt', g_finanzas||v_name||'_'||v_fecha||'.txt');

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','CUOTA_PREST_CLIENTES');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte Inventario de Cuotas de Préstamos de los Clientes a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_finanzas||'

    Nombre del Archivo: '||v_name||'_'||v_fecha||'.txt';

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error    := null;

    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, v_name||'_'||v_fecha||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;

    --Enviamos el mail a soporte
     -- Obtenemos direccion de correo de soporte
     v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error Reporte Inventario de Cuotas de Préstamos de los Clientes a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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
    RAISE_APPLICATION_ERROR(-20062,'Manejador invalido');
  WHEN UTL_FILE.WRITE_ERROR THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20063,'Error de escritura '||sqlerrm);
  WHEN UTL_FILE.INVALID_MODE THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20064,'Modo invalido');
  WHEN UTL_FILE.INTERNAL_ERROR THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20065,'Internal Error');
END pr_cuo_pres_cli;
-------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------
-- Inventario de Cuotas de Préstamos Recibidos
PROCEDURE pr_cuo_pres_rec
IS
CURSOR cu_pres_crec IS
      select cod_rubro, cod_rub_externo, descripcion, cod_moneda, cod_modalidad, cod_oficina, cod_persona, nombre,
             nro_cuenta, sal_capital, sal_mon_local, val_tasa, nro_cuota, fec_inicio, fec_vencimiento, sal_interes,
             cod_rubro_int
      from bv_cuo_prest_recibidos;


  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'cuo_prest_recibido'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_fec_sist         DATE;
  v_fecha            VARCHAR2(8);

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
  select pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1)
  into v_fec_sist
  from dual;

  v_fecha := to_char(v_fec_sist,'DDMMYYYY');

-- Abrir archivo
v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'.txt','W',32767);

-- Colocar el titulo a los campos
v_linetit := 'COD_RUBRO'||CHR(9)||'COD_RUB_EXTERNO'||CHR(9)||'DESCRIPCION'||CHR(9)||'COD_MONEDA'||CHR(9)||'COD_MODALIDAD'||CHR(9)||
             'COD_OFICINA'||CHR(9)||'COD_PERSONA'||CHR(9)||'NOMBRE'||CHR(9)||'NRO_CUENTA'||CHR(9)||'SAL_CAPITAL'||CHR(9)||
             'SAL_MON_LOCAL'||CHR(9)||'VAL_TASA'||CHR(9)||'NRO_CUOTA'||CHR(9)||'FEC_INICIO'||CHR(9)||
             'FEC_VENCIMIENTO'||CHR(9)||'SAL_INTERES'||CHR(9)||'COD_RUBRO_INT';

utl_file.put_line(v_file,v_linetit);

-- Definir una linea en blanco para separar los datos del titulo de los campos
v_linetit := ' ';
utl_file.put_line(v_file,v_linetit);

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN cu_pres_crec LOOP

  --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
  v_line := to_char(rec.COD_RUBRO)||chr(9)||to_char(rec.COD_RUB_EXTERNO)||chr(9)||to_char(rec.DESCRIPCION)||chr(9)||to_char(rec.COD_MONEDA)||chr(9)||
            to_char(rec.COD_MODALIDAD)||chr(9)||to_char(rec.COD_OFICINA)||chr(9)||to_char(rec.COD_PERSONA)||chr(9)||to_char(rec.NOMBRE)||chr(9)||
            to_char(rec.NRO_CUENTA)||chr(9)||to_char(rec.SAL_CAPITAL,'999999999999D00')||chr(9)||to_char(rec.SAL_MON_LOCAL,'999999999999D00')||chr(9)||
            to_char(rec.VAL_TASA,'999999999999D0000')||chr(9)||to_char(rec.NRO_CUOTA)||chr(9)||to_char(rec.FEC_INICIO)||chr(9)||
            to_char(rec.FEC_VENCIMIENTO)||chr(9)||to_char(rec.SAL_INTERES,'999999999999D00')||chr(9)||to_char(rec.COD_RUBRO_INT);

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

   EXIT WHEN cu_pres_crec%NOTFOUND;
END LOOP;
--Escribes la linea en el fichero
UTL_FILE.PUT_LINE(v_file, v_buffer);

--Cerrar el handler al fichero
UTL_FILE.FCLOSE(v_file);
COMMIT;

  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_respuesta := pa_file_ftp.fu_put_ascii(pa_rpc_aut.g_ip, pa_rpc_aut.g_port, pa_rpc_aut.g_user,
                                          pa_rpc_aut.g_pass, pa_rpc_aut.g_repository,
                                          v_name||'.txt', g_finanzas||v_name||'_'||v_fecha||'.txt');

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','CUOTA_PREST_RECIBIDOS');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte Inventario de Cuotas de Préstamos Recibidos a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_finanzas||'

    Nombre del Archivo: '||v_name||'_'||v_fecha||'.txt';

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error    := null;

    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, v_name||'_'||v_fecha||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;

    --Enviamos el mail a soporte
     -- Obtenemos direccion de correo de soporte
     v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error Reporte Inventario de Cuotas de Préstamos Recibidos a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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
    RAISE_APPLICATION_ERROR(-20062,'Manejador invalido');
  WHEN UTL_FILE.WRITE_ERROR THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20063,'Error de escritura '||sqlerrm);
  WHEN UTL_FILE.INVALID_MODE THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20064,'Modo invalido');
  WHEN UTL_FILE.INTERNAL_ERROR THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20065,'Internal Error');
END pr_cuo_pres_rec;
-------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------
-- Informe de pago de sueldos
PROCEDURE pr_pago_sueldo
IS
CURSOR cu_pago_sueldo(p_fecha_des DATE, p_fecha_has DATE) IS
        select cliente, nom_cliente, nro_cuenta, cod_cli_pagadora, nom_emp_pagadora, monto, fec_proceso, cod_moneda
        from gv_pago_sueldo p
        where p.fec_proceso between p_fecha_des and p_fecha_has;

  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'inf_pago_sueldo'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_fec_sist         DATE;
  v_fecha            VARCHAR2(8);
  v_dia_ini          DATE;
  v_dia_fin          DATE;

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
  select pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1)
  into v_fec_sist
  from dual;

  v_fecha := to_char(v_fec_sist,'DDMMYYYY');

  --Obtenemos el primer dia y el ultimo dia del mes
  v_dia_ini := trunc(v_fec_sist,'month');
  v_dia_fin := trunc(last_day(v_fec_sist));

-- Abrir archivo
v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'.txt','W',32767);

-- Colocar el titulo a los campos
v_linetit := 'CLIENTE'||CHR(9)||'NOM_CLIENTE'||CHR(9)||'NRO_CUENTA'||CHR(9)||'COD_CLI_PAGADORA'||CHR(9)||
             'NOM_EMP_PAGADORA'||CHR(9)||'MONTO'||CHR(9)||'FEC_PROCESO'||CHR(9)||'COD_MONEDA';

utl_file.put_line(v_file,v_linetit);

-- Definir una linea en blanco para separar los datos del titulo de los campos
v_linetit := ' ';
utl_file.put_line(v_file,v_linetit);

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN cu_pago_sueldo(v_dia_ini, v_dia_fin) LOOP

    --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
  v_line := to_char(rec.CLIENTE)||chr(9)||to_char(rec.NOM_CLIENTE)||chr(9)||to_char(rec.NRO_CUENTA)||chr(9)||
            to_char(rec.COD_CLI_PAGADORA)||chr(9)||to_char(rec.NOM_EMP_PAGADORA)||chr(9)||
            to_char(rec.MONTO,'999999999999D00')||chr(9)||to_char(rec.FEC_PROCESO)||chr(9)||to_char(rec.COD_MONEDA);


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

  EXIT WHEN cu_pago_sueldo%NOTFOUND;
END LOOP;
--Escribes la linea en el fichero
UTL_FILE.PUT_LINE(v_file, v_buffer);

--Cerrar el handler al fichero
UTL_FILE.FCLOSE(v_file);
COMMIT;

  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_respuesta := pa_file_ftp.fu_put_ascii(pa_rpc_aut.g_ip, pa_rpc_aut.g_port, pa_rpc_aut.g_user,
                                          pa_rpc_aut.g_pass, pa_rpc_aut.g_repository,
                                          v_name||'.txt', g_sistemas||v_name||'_'||v_fecha||'.txt');

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','INF_PAGO_SUELDO');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte Informe de Pago de Sueldos a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_sistemas||'

    Nombre del Archivo: '||v_name||'_'||v_fecha||'.txt';

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error    := null;

    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, v_name||'_'||v_fecha||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;

    --Enviamos el mail a soporte
     -- Obtenemos direccion de correo de soporte
     v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error Reporte Informe de Pago de Sueldos a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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
END pr_pago_sueldo;
-------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------
-- Extracto de Funcionarios
PROCEDURE pr_ext_func
IS
CURSOR cu_ext_func(p_fecha DATE) IS
      select cta.cod_persona cliente, cta.nro_cuenta, nombre,
      cta.direccion,
      cta.piso,
      cta.departamento,
      cta.edificio,
      prefijo, telefono,
             sucursal, tipo_cuenta, sub_cuenta, cliente empresa, retener, cta.tip_impresion, p.nro_documento, cta.Cuenta cuenta_c,--fue_per_dat_adicional(CTA.COD_PERSONA,'TIP_GEN_EXTRACTOS') TIP_GENERACION
             bpd.val_parametro TIP_GENERACION,
      cta.ciudad
      from gv_extracto cta, ge_clientes ge, ba_personas p, ba_per_dat_adicionales bpd
      where  cta.funcionario = 'S'
      and cta.fec_extracto = p_fecha
      and cta.tip_impresion not in ('N','Z')
      and cta.cli_confidencial = 'S'
      and cta.fre_extracto = 'M'
      and cta.cod_persona = ge.cod_persona
      and nvl(ge.cli_especial,'N') = 'N'
     -- and ge.cod_persona = d.cod_persona
     -- and nvl(d.principal,'X') = 'S'
      and cta.cod_persona = p.cod_persona
      and bpd.cod_persona = cta.cod_persona
      and parametro  = 'TIP_GEN_EXTRACTOS'
      /*and exists (Select 's' from ge_ext_cli_movimientos a
                     where a.cod_persona = cta.cod_persona
                     and   a.nro_cuenta = cta.nro_cuenta )*/
     and exists  (Select 's' from ge_ext_cli_movimientos t
                  where t.cod_Extracto = cta.cod_extracto
                  and t.cod_persona = cta.cod_persona
                  and t.fec_extracto = p_fecha)
                


      order by cta.cod_oficina, to_number(cta.cod_persona);

  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'funcionarios'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_fec_sist         DATE;
  v_fecha            VARCHAR2(8);

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
  select pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1)
  into v_fec_sist
  from dual;

  v_fecha := to_char(v_fec_sist,'DDMMYYYY');

-- Abrir archivo
v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'.txt','W',32767);

-- Colocar el titulo a los campos
v_linetit := 'CLIENTE'||CHR(9)||'CUENTA'||CHR(9)||'NOMBRE'||CHR(9)||'DIRECCION'||CHR(9)||'CIUDAD'||CHR(9)||'PISO'||CHR(9)||'DPTO'||CHR(9)||'EDIFICIO'||CHR(9)||/*'PREFIJO'||CHR(9)||*/'TELEFONO'||CHR(9)||'SUCURSAL'||CHR(9)||/*'TIPO_CUENTA'||CHR(9)||*//*'SUB_CUENTA'||CHR(9)||*/'EMPRESA'||CHR(9)||'RETENER'||CHR(9)||'TIP_IMPRESION'||CHR(9)||'NRO_DOCUMENTO'||CHR(9)||'CUENTAS_CONSOLIDADAS'||CHR(9)||'TIP_GEN_EXTRACTO';

utl_file.put_line(v_file,v_linetit);

-- Definir una linea en blanco para separar los datos del titulo de los campos
v_linetit := ' ';
utl_file.put_line(v_file,v_linetit);

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN cu_ext_func(v_fec_sist) LOOP

    --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
  v_line := to_char(rec.cliente)||chr(9)||to_char(rec.nro_cuenta)||chr(9)||to_char(rec.nombre)||chr(9)||
            to_char(rec.direccion)||chr(9)||to_char(rec.ciudad)||chr(9)||to_char(rec.piso)||chr(9)||to_char(rec.departamento)||chr(9)||to_char(rec.edificio)||chr(9)||/*to_char(rec.prefijo)||chr(9)||*/to_char(rec.telefono)||chr(9)||
            to_char(rec.sucursal)||chr(9)||/*to_char(rec.tipo_cuenta)||chr(9)||*//*to_char(rec.sub_cuenta)||chr(9)||*/
             to_char(rec.empresa)||chr(9)||to_char(rec.retener)||chr(9)||to_char(rec.tip_impresion)||chr(9)||to_char(rec.nro_documento)||chr(9)||to_char(rec.cuenta_c)||chr(9)||to_char(rec.TIP_GENERACION);

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

  EXIT WHEN cu_ext_func%NOTFOUND;
END LOOP;
--Escribes la linea en el fichero
UTL_FILE.PUT_LINE(v_file, v_buffer);

--Cerrar el handler al fichero
UTL_FILE.FCLOSE(v_file);
COMMIT;

  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_respuesta := pa_file_ftp.fu_put_ascii(pa_rpc_aut.g_ip, pa_rpc_aut.g_port, pa_rpc_aut.g_user,
                                          pa_rpc_aut.g_pass, pa_rpc_aut.g_repository,
                                          v_name||'.txt', g_extractos||v_name||'_'||v_fecha||'.txt');

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','EXTRAC_FUNCIONARIO');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte de Funcionarios a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_extractos||'

    Nombre del Archivo: '||v_name||'_'||v_fecha||'.txt';

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error    := null;

    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, v_name||'_'||v_fecha||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;

    --Enviamos el mail a soporte
     -- Obtenemos direccion de correo de soporte
     v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error Reporte de Funcionarios a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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
END pr_ext_func;
-------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------
-- Extracto Normales Retener
PROCEDURE pr_nor_retener
IS
CURSOR cu_nor_retener(p_fecha DATE) IS
  select CTA.cod_persona cliente,
         nro_cuenta,
         nombre,
         cta.Direccion_retener,
         cta.piso,
         cta.departamento,
         cta.edificio,
         p.nro_documento,
         prefijo,
         telefono,
         sucursal,
         tipo_cuenta,
         sub_cuenta,
         cliente Empresa,
         retener,
         cta.tip_impresion,
         cta.Cuenta cuenta_c,
         --fue_per_dat_adicional(CTA.COD_PERSONA,'TIP_GEN_EXTRACTOS') TIP_GENERACION
         bpd.val_parametro TIP_GENERACION,cta.ciudad
    from gv_extracto cta,GE_CLIENTES GE, ba_personas p, ba_per_dat_adicionales bpd
   where cta.Cliente is null
     and cta.funcionario = 'N'
     and cta.fec_extracto = p_fecha
     and nvl(cta.Retener,'x') = 'Retener'
     and cta.tip_impresion not in ('N','Z')
     and cta.cod_oficina in(11,21)
     and cta.cli_confidencial = 'N'
     AND CTA.FRE_EXTRACTO = 'M'
     AND CTA.cod_persona = GE.COD_PERSONA
     AND NVL(GE.CLI_ESPECIAL,'N')='N'
     --and ge.cod_persona = d.cod_persona
     --and nvl(d.principal,'X') = 'S'
     and cta.cod_persona = p.cod_persona
     and bpd.cod_persona = cta.cod_persona
     and bpd.parametro  = 'TIP_GEN_EXTRACTOS'
     --and ciu.cod_ciudad = d.cod_ciudad
     --and ciu.cod_pais = d.cod_pais
    /* and exists (Select 's' from ge_ext_cli_movimientos a
                     where a.cod_persona = cta.cod_persona
                     and   a.nro_cuenta = cta.nro_cuenta )*/
     and exists  (Select 's' from ge_ext_cli_movimientos t
                  where t.cod_Extracto = cta.cod_extracto
                  and t.cod_persona = cta.cod_persona
                  and t.fec_extracto = p_fecha)
     
   order by cta.cod_oficina, to_number(cta.cod_persona);

  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'normal_retener'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_fec_sist         DATE;
  v_fecha            VARCHAR2(8);

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
  select pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1)
  into v_fec_sist
  from dual;

  v_fecha := to_char(v_fec_sist,'DDMMYYYY');

-- Abrir archivo
v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'.txt','W',32767);

-- Colocar el titulo a los campos
v_linetit := 'CLIENTE'||CHR(9)||'CUENTA'||CHR(9)||'NOMBRE'||CHR(9)||'DIRECCION'||CHR(9)||/*'PREFIJO'||CHR(9)||*/'TELEFONO'||CHR(9)||'SUCURSAL'||CHR(9)||/*'TIPO_CUENTA'||CHR(9)||*//*'SUB_CUENTA'||CHR(9)||*/'EMPRESA'||CHR(9)||'RETENER'||CHR(9)||'TIP_IMPRESION'||CHR(9)||'NRO_DOCUMENTO'||CHR(9)||'CUENTAS_CONSOLIDADAS'||CHR(9)||'TIP_GEN_EXTRACTO';

utl_file.put_line(v_file,v_linetit);

-- Definir una linea en blanco para separar los datos del titulo de los campos
v_linetit := ' ';
utl_file.put_line(v_file,v_linetit);

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN cu_nor_retener(v_fec_sist) LOOP

    --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
  v_line := to_char(rec.cliente)||chr(9)||to_char(rec.nro_cuenta)||chr(9)||to_char(rec.nombre)||chr(9)||
            to_char(rec.Direccion_retener)||chr(9)||/*to_char(rec.prefijo)||chr(9)||*/to_char(rec.telefono)||chr(9)||
            to_char(rec.sucursal)||chr(9)||/*to_char(rec.tipo_cuenta)||chr(9)||*//*to_char(rec.sub_cuenta)||chr(9)||*/
             to_char(rec.empresa)||chr(9)||to_char(rec.retener)||chr(9)||to_char(rec.tip_impresion)||chr(9)||to_char(rec.nro_documento)||chr(9)||to_char(rec.cuenta_c)||chr(9)||to_char(rec.TIP_GENERACION);

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

  EXIT WHEN cu_nor_retener%NOTFOUND;
END LOOP;
--Escribes la linea en el fichero
UTL_FILE.PUT_LINE(v_file, v_buffer);

--Cerrar el handler al fichero
UTL_FILE.FCLOSE(v_file);
COMMIT;

  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_respuesta := pa_file_ftp.fu_put_ascii(pa_rpc_aut.g_ip, pa_rpc_aut.g_port, pa_rpc_aut.g_user,
                                          pa_rpc_aut.g_pass, pa_rpc_aut.g_repository,
                                          v_name||'.txt', g_extractos||v_name||'_'||v_fecha||'.txt');

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','NORMAL_RETENER');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte Nomales Retener a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_extractos||'

    Nombre del Archivo: '||v_name||'_'||v_fecha||'.txt';

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error    := null;

    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, v_name||'_'||v_fecha||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;

    --Enviamos el mail a soporte
     -- Obtenemos direccion de correo de soporte
     v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error Reporte Normales Retener a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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
END pr_nor_retener;
-------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------
-- Extracto Normales NO Retener
PROCEDURE pr_nor_no_reten
IS
CURSOR cu_no_retener(p_fecha DATE) IS
      select CTA.cod_persona cliente,
           nro_cuenta,
           nombre,
           cta.direccion,
           cta.piso,
           cta.departamento,
           cta.edificio,
           p.nro_documento,
           prefijo,
           telefono,
           sucursal,
           tipo_cuenta,
           sub_cuenta,
           cliente Empresa,
           retener,
           cta.tip_impresion,
           cta.Cuenta cuenta_c,
           --fue_per_dat_adicional(CTA.COD_PERSONA,'TIP_GEN_EXTRACTOS') TIP_GENERACION
           bpd.val_parametro TIP_GENERACION,cta.ciudad
      from gv_extracto cta,GE_CLIENTES GE,ba_personas p, ba_per_dat_adicionales bpd
     where cta.Cliente is null
       and cta.funcionario = 'N'
       and cta.fec_extracto = p_fecha
       and nvl(cta.Retener,'x') <> 'Retener'
       and cta.tip_impresion not in ('N','Z')
       and cta.cli_confidencial = 'N'
       AND CTA.FRE_EXTRACTO = 'M'
       AND CTA.cod_persona = GE.COD_PERSONA
       AND NVL(GE.CLI_ESPECIAL,'N')='N'

       and cta.cod_persona = p.cod_persona
       and bpd.cod_persona = cta.cod_persona
       and bpd.parametro  = 'TIP_GEN_EXTRACTOS'
       /*and exists (Select 's' from ge_ext_cli_movimientos a
                     where a.cod_persona = cta.cod_persona
                     and   a.nro_cuenta = cta.nro_cuenta )*/
      and exists  (Select 's' from ge_ext_cli_movimientos t
                  where t.cod_Extracto = cta.cod_extracto
                  and t.cod_persona = cta.cod_persona
                  and t.fec_extracto = p_fecha)
    

     order by cta.cod_oficina, to_number(cta.cod_persona);

  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'normal_no_retener'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_fec_sist         DATE;
  v_fecha            VARCHAR2(8);

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
  select pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1)
  into v_fec_sist
  from dual;

  v_fecha := to_char(v_fec_sist,'DDMMYYYY');

-- Abrir archivo
v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'.txt','W',32767);

-- Colocar el titulo a los campos
v_linetit := 'CLIENTE'||CHR(9)||'CUENTA'||CHR(9)||'NOMBRE'||CHR(9)||'DIRECCION'||CHR(9)||'CIUDAD'||CHR(9)||'PISO'||CHR(9)||'DPTO'||CHR(9)||'EDIFICIO'||CHR(9)||/*'PREFIJO'||CHR(9)||*/'TELEFONO'||CHR(9)||'SUCURSAL'||CHR(9)||/*'TIPO_CUENTA'||CHR(9)||*//*'SUB_CUENTA'||CHR(9)||*/'EMPRESA'||CHR(9)||'RETENER'||CHR(9)||'TIP_IMPRESION'||CHR(9)||'NRO_DOCUMENTO'||CHR(9)||'CUENTAS_CONSOLIDADAS'||CHR(9)||'TIP_GEN_EXTRACTO';

utl_file.put_line(v_file,v_linetit);

-- Definir una linea en blanco para separar los datos del titulo de los campos
v_linetit := ' ';
utl_file.put_line(v_file,v_linetit);

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN cu_no_retener(v_fec_sist) LOOP

    --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
  v_line := to_char(rec.cliente)||chr(9)||to_char(rec.nro_cuenta)||chr(9)||to_char(rec.nombre)||chr(9)||
            to_char(rec.direccion)||chr(9)||to_char(rec.ciudad)||chr(9)||to_char(rec.piso)||chr(9)||to_char(rec.departamento)||chr(9)||to_char(rec.edificio)||chr(9)||/*to_char(rec.prefijo)||chr(9)||*/to_char(rec.telefono)||chr(9)||
            to_char(rec.sucursal)||chr(9)||/*to_char(rec.tipo_cuenta)||chr(9)||*//*to_char(rec.sub_cuenta)||chr(9)||*/
             to_char(rec.empresa)||chr(9)||to_char(rec.retener)||chr(9)||to_char(rec.tip_impresion)||chr(9)||to_char(rec.nro_documento)||chr(9)||to_char(rec.cuenta_c)||chr(9)||to_char(rec.TIP_GENERACION);

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

  EXIT WHEN cu_no_retener%NOTFOUND;
END LOOP;
--Escribes la linea en el fichero
UTL_FILE.PUT_LINE(v_file, v_buffer);

--Cerrar el handler al fichero
UTL_FILE.FCLOSE(v_file);
COMMIT;

  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_respuesta := pa_file_ftp.fu_put_ascii(pa_rpc_aut.g_ip, pa_rpc_aut.g_port, pa_rpc_aut.g_user,
                                          pa_rpc_aut.g_pass, pa_rpc_aut.g_repository,
                                          v_name||'.txt', g_extractos||v_name||'_'||v_fecha||'.txt');

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','NORMAL_NO_RETENER');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte Nomales No Retener a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_extractos||'

    Nombre del Archivo: '||v_name||'_'||v_fecha||'.txt';

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error    := null;

    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, v_name||'_'||v_fecha||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;

    --Enviamos el mail a soporte
     -- Obtenemos direccion de correo de soporte
     v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error Reporte Normales No Retener a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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
END pr_nor_no_reten;
-------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------
-- Nomina Otras Sucursales
PROCEDURE pr_nomina_suc
IS
CURSOR cu_nomina_suc(p_fecha DATE) IS
      select cta.cod_persona cliente,
             nro_cuenta,
             nombre,
             cta.direccion_ente direccion,
             cta.piso_ente piso,
             cta.departamento_ente departamento,
             cta.edificio_ente edificio,
             p.nro_documento,
             prefijo,
             telefono,
             sucursal,
             tipo_cuenta,
             sub_cuenta,
             cliente Empresa,
             retener,
             cta.tip_impresion,
             cta.Cuenta cuenta_c,
             --fue_per_dat_adicional(CTA.COD_PERSONA,'TIP_GEN_EXTRACTOS') TIP_GENERACION,
             bpd.val_parametro TIP_GENERACION,cta.ciudad,
             cta.direccion_ente direc_ente,--dirección ente
             cta.piso_ente piso_ente, --piso ente
             cta.departamento_ente dpto_ente, --dpto ente
             cta.edificio_ente  --edificio ente
        from gv_extracto cta,ge_clientes ge, ba_personas p, ba_per_dat_adicionales bpd
       where cta.Cliente is not null
         and cta.funcionario = 'N'
         and cta.fec_extracto = p_fecha
         and cta.tip_impresion not in ('N','Z')
         and cta.cod_oficina > 1
         and cta.cli_confidencial = 'N'
         and cta.fre_extracto = 'M'
         and cta.cod_persona = ge.cod_persona
         and nvl(ge.cli_especial,'N') = 'N'
         and cta.cod_persona = p.cod_persona
         and bpd.cod_persona = cta.cod_persona
         and bpd.parametro  = 'TIP_GEN_EXTRACTOS'
         /*and exists (Select 's' from ge_ext_cli_movimientos a
                     where a.cod_persona = cta.cod_persona
                     and   a.nro_cuenta = cta.nro_cuenta )*/
        and exists  (Select 's' from ge_ext_cli_movimientos t
                  where t.cod_Extracto = cta.cod_extracto
                  and t.cod_persona = cta.cod_persona
                  and t.fec_extracto = p_fecha)
     
      order by cta.Sucursal, cta.Cliente, to_number(cta.cod_persona);

  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'nomina_sucursal'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_fec_sist         DATE;
  v_fecha            VARCHAR2(8);

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
  select pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1)
  into v_fec_sist
  from dual;

  v_fecha := to_char(v_fec_sist,'DDMMYYYY');

-- Abrir archivo
v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'.txt','W',32767);

-- Colocar el titulo a los campos
v_linetit := 'CLIENTE'||CHR(9)||'CUENTA'||CHR(9)||'NOMBRE'||CHR(9)||'DIRECCION'||CHR(9)||'CIUDAD'||CHR(9)||'PISO'||CHR(9)||'DPTO'||CHR(9)||'EDIFICIO'||CHR(9)||/*'PREFIJO'||CHR(9)||*/'TELEFONO'||CHR(9)||'SUCURSAL'||CHR(9)||/*'TIPO_CUENTA'||CHR(9)||*//*'SUB_CUENTA'||CHR(9)||*/'EMPRESA'||CHR(9)||'RETENER'||CHR(9)||'TIP_IMPRESION'||CHR(9)||'NRO_DOCUMENTO'||CHR(9)||'CUENTAS_CONSOLIDADAS'||CHR(9)||'TIP_GEN_EXTRACTO'||CHR(9)||'DIRECCION_EMPRESA'||CHR(9)||'CIUDAD_EMPRESA'||CHR(9)||'PISO_EMPRESA'||CHR(9)||'DPTO_EMPRESA'||CHR(9)||'EDIFICIO_EMPRESA';

utl_file.put_line(v_file,v_linetit);

-- Definir una linea en blanco para separar los datos del titulo de los campos
v_linetit := ' ';
utl_file.put_line(v_file,v_linetit);

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN cu_nomina_suc(v_fec_sist) LOOP

    --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
  v_line := to_char(rec.cliente)||chr(9)||to_char(rec.nro_cuenta)||chr(9)||to_char(rec.nombre)||chr(9)||
            to_char(rec.direccion)||chr(9)||to_char(rec.ciudad)||chr(9)||to_char(rec.piso)||chr(9)||to_char(rec.departamento)||chr(9)||to_char(rec.edificio)||chr(9)||/*to_char(rec.prefijo)||chr(9)||*/to_char(rec.telefono)||chr(9)||
            to_char(rec.sucursal)||chr(9)||/*to_char(rec.tipo_cuenta)||chr(9)||*//*to_char(rec.sub_cuenta)||chr(9)||*/
             to_char(rec.empresa)||chr(9)||to_char(rec.retener)||chr(9)||to_char(rec.tip_impresion)||chr(9)||to_char(rec.nro_documento)||chr(9)||to_char(rec.cuenta_c)||chr(9)||to_char(rec.TIP_GENERACION)||chr(9)||to_char(rec.direc_ente)||chr(9)||to_char(rec.ciudad)||chr(9)||to_char(rec.piso_ente)||chr(9)||to_char(rec.dpto_ente)||chr(9)||to_char(rec.edificio_ente);

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

  EXIT WHEN cu_nomina_suc%NOTFOUND;
END LOOP;
--Escribes la linea en el fichero
UTL_FILE.PUT_LINE(v_file, v_buffer);

--Cerrar el handler al fichero
UTL_FILE.FCLOSE(v_file);
COMMIT;

  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_respuesta := pa_file_ftp.fu_put_ascii(pa_rpc_aut.g_ip, pa_rpc_aut.g_port, pa_rpc_aut.g_user,
                                          pa_rpc_aut.g_pass, pa_rpc_aut.g_repository,
                                          v_name||'.txt', g_extractos||v_name||'_'||v_fecha||'.txt');

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','NOMIMA_SUCURSAL');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte Nomina Otras Sucursales a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_extractos||'

    Nombre del Archivo: '||v_name||'_'||v_fecha||'.txt';

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error    := null;

    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, v_name||'_'||v_fecha||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;

    --Enviamos el mail a soporte
     -- Obtenemos direccion de correo de soporte
     v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error Reporte Nomina Otras Sucursales a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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
END pr_nomina_suc;
-------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------
-- Nomina Sucursal 1 segun parametro recibido
PROCEDURE pr_nomina_suno
  (
    v_par1    VARCHAR2,
    v_par2    VARCHAR2
  )
IS
CURSOR cu_nomina_suno(p_fecha DATE) IS
      select cta.cod_persona cliente,
             nro_cuenta,
             nombre,
             cta.direccion_ente direccion,
             cta.piso_ente piso,
             cta.departamento_ente departamento,
             cta.edificio_ente edificio,
             p.nro_documento,
             prefijo,
             telefono,
             sucursal,
             tipo_cuenta,
             sub_cuenta,
             cliente Empresa,
             retener,
             cta.tip_impresion,
             cta.Cuenta cuenta_c,
             --fue_per_dat_adicional(CTA.COD_PERSONA,'TIP_GEN_EXTRACTOS') TIP_GENERACION,
             bpd.val_parametro TIP_GENERACION,cta.ciudad,
             cta.direccion_ente direc_ente,--dirección ente
             cta.piso_ente , --piso ente
             cta.departamento_ente dpto_ente, --dpto ente
             cta.edificio_ente  --edificio ente
      from gv_extracto cta, ge_clientes ge , ba_personas p, ba_per_dat_adicionales bpd
      where cta.Cliente is not null
         and cta.funcionario = 'N'
         and cta.fec_extracto = p_fecha
         and cta.tip_impresion not in ('N','Z')
         and cta.cod_oficina = 1
         and cta.cli_confidencial = 'N'
         and cta.fre_extracto = 'M'
         and cta.cod_persona = ge.cod_persona
         and nvl(ge.cli_especial,'N')='N'
         and cta.cod_persona = p.cod_persona
         and bpd.cod_persona = cta.cod_persona
         and bpd.parametro  = 'TIP_GEN_EXTRACTOS'
         and to_number(cta.cod_persona) between v_par1 and v_par2
        /* and exists (Select 's' from ge_ext_cli_movimientos a
                     where a.cod_persona = cta.cod_persona
                     and   a.nro_cuenta = cta.nro_cuenta )*/
       and exists  (Select 's' from ge_ext_cli_movimientos t
                  where t.cod_Extracto = cta.cod_extracto
                  and t.cod_persona = cta.cod_persona
                  and t.fec_extracto = p_fecha)
     
      order by cta.Sucursal, cta.Cliente, to_number(cta.cod_persona);

  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'nomina1'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_fec_sist         DATE;
  v_fecha            VARCHAR2(8);

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
  select pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1)
  into v_fec_sist
  from dual;

  v_fecha := to_char(v_fec_sist,'DDMMYYYY');

-- Abrir archivo
--if v_par1 = pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','NOMINA_PAR_1') then
   v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'.txt','W',32767);
/*else
   v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'.txt','a',32767);
end if;*/

-- Colocar el titulo a los campos
v_linetit := 'CLIENTE'||CHR(9)||'CUENTA'||CHR(9)||'NOMBRE'||CHR(9)||'DIRECCION'||CHR(9)||'CIUDAD'||CHR(9)||'PISO'||CHR(9)||'DPTO'||CHR(9)||'EDIFICIO'||CHR(9)||/*'PREFIJO'||CHR(9)||*/'TELEFONO'||CHR(9)||'SUCURSAL'||CHR(9)||/*'TIPO_CUENTA'||CHR(9)||*//*'SUB_CUENTA'||CHR(9)||*/'EMPRESA'||CHR(9)||'RETENER'||CHR(9)||'TIP_IMPRESION'||CHR(9)||'NRO_DOCUMENTO'||CHR(9)||'CUENTAS_CONSOLIDADAS'||CHR(9)||'TIP_GEN_EXTRACTO'||CHR(9)||'DIRECCION_EMPRESA'||CHR(9)||'CIUDAD_EMPRESA'||CHR(9)||'PISO_EMPRESA'||CHR(9)||'DPTO_EMPRESA'||CHR(9)||'EDIFICIO_EMPRESA';

utl_file.put_line(v_file,v_linetit);

-- Definir una linea en blanco para separar los datos del titulo de los campos
v_linetit := ' ';
utl_file.put_line(v_file,v_linetit);

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN cu_nomina_suno(v_fec_sist) LOOP

    --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
  v_line := to_char(rec.cliente)||chr(9)||to_char(rec.nro_cuenta)||chr(9)||to_char(rec.nombre)||chr(9)||
            to_char(rec.direccion)||chr(9)||to_char(rec.ciudad)||chr(9)||to_char(rec.piso)||chr(9)||to_char(rec.departamento)||chr(9)||to_char(rec.edificio)||chr(9)||/*to_char(rec.prefijo)||chr(9)||*/to_char(rec.telefono)||chr(9)||
            to_char(rec.sucursal)||chr(9)||/*to_char(rec.tipo_cuenta)||chr(9)||*//*to_char(rec.sub_cuenta)||chr(9)||*/
             to_char(rec.empresa)||chr(9)||to_char(rec.retener)||chr(9)||to_char(rec.tip_impresion)||chr(9)||to_char(rec.nro_documento)||chr(9)||to_char(rec.cuenta_c)||chr(9)||to_char(rec.TIP_GENERACION)||chr(9)||to_char(rec.direc_ente)||chr(9)||to_char(rec.ciudad)||chr(9)||to_char(rec.piso_ente)||chr(9)||to_char(rec.dpto_ente)||chr(9)||to_char(rec.edificio_ente);

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

  EXIT WHEN cu_nomina_suno%NOTFOUND;
END LOOP;
--Escribes la linea en el fichero
UTL_FILE.PUT_LINE(v_file, v_buffer);

--Cerrar el handler al fichero
UTL_FILE.FCLOSE(v_file);
COMMIT;

  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_respuesta := pa_file_ftp.fu_put_ascii(pa_rpc_aut.g_ip, pa_rpc_aut.g_port, pa_rpc_aut.g_user,
                                          pa_rpc_aut.g_pass, pa_rpc_aut.g_repository,
                                          v_name||'.txt', g_extractos||v_name||'_'||v_par1||'al'||v_par2||'_'||v_fecha||'.txt');

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','NOMIMA_SUC_UNO');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte Nomina Sucursal 1 a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_extractos||'

    Nombre del Archivo: '||v_name||'_'||v_par1||'al'||v_par2||'_'||v_fecha||'.txt';

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_par1||'al'||v_par2||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error    := null;

    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, v_name||'_'||v_par1||'al'||v_par2||'_'||v_fecha||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;

    --Enviamos el mail a soporte
     -- Obtenemos direccion de correo de soporte
     v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error Reporte Nomina Sucursal 1 a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_par1||'al'||v_par2||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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
END pr_nomina_suno;
-------------------------------------------------------------------------------------------------------------------------------------

PROCEDURE pr_cli_confidencial
IS
CURSOR cu_no_retener(p_fecha DATE) IS
      select CTA.cod_persona cliente,
           nro_cuenta,
           nombre,
           --cta.direccion,
           replace(replace(NVL(cta.direccion,fue_obt_dir_principa(cta.cod_persona)),'.',''),',','')direccion,
           d.piso,
           d.departamento,
           d.edificio,
           p.nro_documento,
           prefijo,
           telefono,
           sucursal,
           tipo_cuenta,
           sub_cuenta,
           cliente Empresa,
           retener,
           cta.tip_impresion,
           cta.Cuenta cuenta_c,
           --fue_per_dat_adicional(CTA.COD_PERSONA,'TIP_GEN_EXTRACTOS') TIP_GENERACION
           bpd.val_parametro TIP_GENERACION,ciu.descripcion ciudad
      from gv_extracto cta,GE_CLIENTES GE,ba_direcciones d, ba_personas p, ba_per_dat_adicionales bpd, ba_ciudades ciu
     where cta.Cliente is null
       and cta.funcionario = 'N'
       and cta.fec_extracto = p_fecha
       and nvl(cta.Retener,'x') <> 'Retener'
       and cta.tip_impresion not in ('N','Z')
       and cta.cli_confidencial = 'S'--solo clientes confidenciales
       AND CTA.FRE_EXTRACTO = 'M'
       AND CTA.cod_persona = GE.COD_PERSONA
       AND NVL(GE.CLI_ESPECIAL,'N')='N'
       and ge.cod_persona = d.cod_persona
       and nvl(d.principal,'X') = 'S'
       and cta.cod_persona = p.cod_persona
       and bpd.cod_persona = cta.cod_persona
       and parametro  = 'TIP_GEN_EXTRACTOS'
       and ciu.cod_ciudad(+) = d.cod_ciudad
       and ciu.cod_pais(+) = d.cod_pais
       /*and exists (Select 's' from ge_ext_cli_movimientos a
                     where a.cod_persona = cta.cod_persona
                     and   a.nro_cuenta = cta.nro_cuenta )*/
       and exists  (Select 's' from ge_ext_cli_movimientos t
                  where t.cod_Extracto = cta.cod_extracto
                  and t.cod_persona = cta.cod_persona
                  and t.fec_extracto = p_fecha)
     
     order by cta.cod_oficina, to_number(cta.cod_persona);

  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'clientes_confidenciales'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_fec_sist         DATE;
  v_fecha            VARCHAR2(8);

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
  select pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1)
  into v_fec_sist
  from dual;

  v_fecha := to_char(v_fec_sist,'DDMMYYYY');

-- Abrir archivo
v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'.txt','W',32767);

-- Colocar el titulo a los campos
v_linetit := 'CLIENTE'||CHR(9)||'CUENTA'||CHR(9)||'NOMBRE'||CHR(9)||'DIRECCION'||CHR(9)||'CIUDAD'||CHR(9)||'PISO'||CHR(9)||'DPTO'||CHR(9)||'EDIFICIO'||CHR(9)||/*'PREFIJO'||CHR(9)||*/'TELEFONO'||CHR(9)||'SUCURSAL'||CHR(9)||/*'TIPO_CUENTA'||CHR(9)||*//*'SUB_CUENTA'||CHR(9)||*/'EMPRESA'||CHR(9)||'RETENER'||CHR(9)||'TIP_IMPRESION'||CHR(9)||'NRO_DOCUMENTO'||CHR(9)||'CUENTAS_CONSOLIDADAS'||CHR(9)||'TIP_GEN_EXTRACTO';
utl_file.put_line(v_file,v_linetit);

-- Definir una linea en blanco para separar los datos del titulo de los campos
v_linetit := ' ';
utl_file.put_line(v_file,v_linetit);

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN cu_no_retener(v_fec_sist) LOOP

    --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
  v_line := to_char(rec.cliente)||chr(9)||to_char(rec.nro_cuenta)||chr(9)||to_char(rec.nombre)||chr(9)||
            to_char(rec.direccion)||chr(9)||to_char(rec.ciudad)||chr(9)||to_char(rec.piso)||chr(9)||to_char(rec.departamento)||chr(9)||to_char(rec.edificio)||chr(9)||/*to_char(rec.prefijo)||chr(9)||*/to_char(rec.telefono)||chr(9)||
            to_char(rec.sucursal)||chr(9)||/*to_char(rec.tipo_cuenta)||chr(9)||*//*to_char(rec.sub_cuenta)||chr(9)||*/
             to_char(rec.empresa)||chr(9)||to_char(rec.retener)||chr(9)||to_char(rec.tip_impresion)||chr(9)||to_char(rec.nro_documento)||chr(9)||to_char(rec.cuenta_c)||chr(9)||to_char(rec.TIP_GENERACION);

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

  EXIT WHEN cu_no_retener%NOTFOUND;
END LOOP;
--Escribes la linea en el fichero
UTL_FILE.PUT_LINE(v_file, v_buffer);

--Cerrar el handler al fichero
UTL_FILE.FCLOSE(v_file);
COMMIT;

  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_respuesta := pa_file_ftp.fu_put_ascii(pa_rpc_aut.g_ip, pa_rpc_aut.g_port, pa_rpc_aut.g_user,
                                          pa_rpc_aut.g_pass, pa_rpc_aut.g_repository,
                                          v_name||'.txt', g_extractos||v_name||'_'||v_fecha||'.txt');

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','NORMAL_NO_RETENER');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte Nomales No Retener a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_extractos||'

    Nombre del Archivo: '||v_name||'_'||v_fecha||'.txt';

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error    := null;

    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, v_name||'_'||v_fecha||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;

    --Enviamos el mail a soporte
     -- Obtenemos direccion de correo de soporte
     v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error Reporte Normales No Retener a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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
END pr_cli_confidencial;
-------------------------------------------------------------------------------------------------------------------------------------
-- Procedimiento para obtener Nomina Sucursal 1 enviando parametros
PROCEDURE pr_obt_nomina
IS
    v_par1   VARCHAR2(50) := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','NOMINA_PAR_1');
    v_par2   VARCHAR2(50) := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','NOMINA_PAR_2');
    v_par3   VARCHAR2(50) := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','NOMINA_PAR_2')+1;
    v_par4   VARCHAR2(50) := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','NOMINA_PAR_3');
    v_par5   VARCHAR2(50) := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','NOMINA_PAR_3')+1;
    v_par6   VARCHAR2(50) := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','NOMINA_PAR_4');

  BEGIN
    BEGIN
      -- Archivo 1
      pa_rpc_aut.PR_NOMINA_SUNO(v_par1, v_par2);
      commit;

      -- Archivo 2
      pa_rpc_aut.PR_NOMINA_SUNO(v_par3, v_par4);
      commit;

      -- Archivo 3
      pa_rpc_aut.PR_NOMINA_SUNO(v_par5, v_par6);
      commit;
    END;
END pr_obt_nomina;
-------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------
-- Extracto Vip Retener
PROCEDURE pr_vip_retener
IS
CURSOR cu_vip_retener(p_fecha DATE) IS
      select CTA.cod_persona cliente,
           nro_cuenta,
           nombre,
           cta.direccion_retener,
           cta.piso,
           cta.departamento,
           cta.edificio,
           p.nro_documento,
           prefijo,
           telefono,
           sucursal,
           tipo_cuenta,
           sub_cuenta,
           cliente Empresa,
           retener,
           cta.tip_impresion,
           cta.Cuenta cuenta_c,
           --fue_per_dat_adicional(CTA.COD_PERSONA,'TIP_GEN_EXTRACTOS') TIP_GENERACION
           bpd.val_parametro TIP_GENERACION,cta.ciudad
        from gv_extracto cta, ge_clientes g, ba_personas p, ba_per_dat_adicionales bpd
       where cta.Cliente is null --Para sacar clientes vip que no son nomina y IS Not NULL para clientes VIP que son nomina
         and cta.funcionario = 'N'
         and cta.fec_extracto = p_fecha
         and nvl(cta.Retener,'x') ='Retener'
         and cta.tip_impresion not in ('N','Z')
         and cta.cli_confidencial = 'N'
         AND CTA.FRE_EXTRACTO = 'M'
         and cta.cod_persona = g.cod_persona
         and nvl(g.cli_especial,'N') = 'S'
         and g.cod_seg_preferente = 1
         and cta.cod_persona = p.cod_persona
         and bpd.cod_persona = cta.cod_persona
         and bpd.parametro  = 'TIP_GEN_EXTRACTOS'
         /*and exists (Select 's' from ge_ext_cli_movimientos a
                     where a.cod_persona = cta.cod_persona
                     and   a.nro_cuenta = cta.nro_cuenta )*/
         and exists  (Select 's' from ge_ext_cli_movimientos t
                  where t.cod_Extracto = cta.cod_extracto
                  and t.cod_persona = cta.cod_persona
                  and t.fec_extracto = p_fecha)
     
       order by cta.cod_oficina, to_number(cta.cod_persona);

  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'vip_retener'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_fec_sist         DATE;
  v_fecha            VARCHAR2(8);

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
  select pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1)
  into v_fec_sist
  from dual;

  v_fecha := to_char(v_fec_sist,'DDMMYYYY');

-- Abrir archivo
v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'.txt','W',32767);

-- Colocar el titulo a los campos
v_linetit := 'CLIENTE'||CHR(9)||'CUENTA'||CHR(9)||'NOMBRE'||CHR(9)||'DIRECCION'||CHR(9)||'CIUDAD'||CHR(9)||'PISO'||CHR(9)||'DPTO'||CHR(9)||'EDIFICIO'||CHR(9)||/*'PREFIJO'||CHR(9)||*/'TELEFONO'||CHR(9)||'SUCURSAL'||CHR(9)||/*'TIPO_CUENTA'||CHR(9)||*//*'SUB_CUENTA'||CHR(9)||*/'EMPRESA'||CHR(9)||'RETENER'||CHR(9)||'TIP_IMPRESION'||CHR(9)||'NRO_DOCUMENTO'||CHR(9)||'CUENTAS_CONSOLIDADAS'||CHR(9)||'TIP_GEN_EXTRACTO';

utl_file.put_line(v_file,v_linetit);

-- Definir una linea en blanco para separar los datos del titulo de los campos
v_linetit := ' ';
utl_file.put_line(v_file,v_linetit);

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN cu_vip_retener(v_fec_sist) LOOP

    --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
  v_line := to_char(rec.cliente)||chr(9)||to_char(rec.nro_cuenta)||chr(9)||to_char(rec.nombre)||chr(9)||
            to_char(rec.direccion_retener)||chr(9)||to_char(rec.ciudad)||chr(9)||to_char(rec.piso)||chr(9)||to_char(rec.departamento)||chr(9)||to_char(rec.edificio)||chr(9)||/*to_char(rec.prefijo)||chr(9)||*/to_char(rec.telefono)||chr(9)||
            to_char(rec.sucursal)||chr(9)||/*to_char(rec.tipo_cuenta)||chr(9)||*//*to_char(rec.sub_cuenta)||chr(9)||*/
             to_char(rec.empresa)||chr(9)||to_char(rec.retener)||chr(9)||to_char(rec.tip_impresion)||chr(9)||to_char(rec.nro_documento)||chr(9)||to_char(rec.cuenta_c)||chr(9)||to_char(rec.TIP_GENERACION);

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

  EXIT WHEN cu_vip_retener%NOTFOUND;
END LOOP;
--Escribes la linea en el fichero
UTL_FILE.PUT_LINE(v_file, v_buffer);

--Cerrar el handler al fichero
UTL_FILE.FCLOSE(v_file);
COMMIT;

  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_respuesta := pa_file_ftp.fu_put_ascii(pa_rpc_aut.g_ip, pa_rpc_aut.g_port, pa_rpc_aut.g_user,
                                          pa_rpc_aut.g_pass, pa_rpc_aut.g_repository,
                                          v_name||'.txt', g_extractos||v_name||'_'||v_fecha||'.txt');

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','VIP_RETENER');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte Vip Retener a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_extractos||'

    Nombre del Archivo: '||v_name||'_'||v_fecha||'.txt';

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error    := null;

    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, v_name||'_'||v_fecha||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;

    --Enviamos el mail a soporte
     -- Obtenemos direccion de correo de soporte
     v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error Reporte Vip Retener a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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
END pr_vip_retener;
-------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------
-- Extracto Vip No Retener
PROCEDURE pr_vip_no_reten
IS
CURSOR cu_vip_no_reten(p_fecha DATE) IS
      select CTA.cod_persona cliente,
           nro_cuenta,
           nombre,
           cta.direccion,
           cta.piso,
           cta.departamento,
           cta.edificio,
           p.nro_documento,
           prefijo,
           telefono,
           sucursal,
           tipo_cuenta,
           sub_cuenta,
           cliente Empresa,
           retener,
           cta.tip_impresion,
           cta.Cuenta cuenta_c,
           --fue_per_dat_adicional(CTA.COD_PERSONA,'TIP_GEN_EXTRACTOS') TIP_GENERACION
           bpd.val_parametro TIP_GENERACION,cta.ciudad
        from gv_extracto cta, ge_clientes g, ba_personas p, ba_per_dat_adicionales bpd
       where cta.Cliente is null     --Para sacar clientes vip que no son nomina y IS Not NULL para clientes VIP que son nomina
         and cta.funcionario = 'N'
         and cta.fec_extracto = p_fecha
         and nvl(cta.Retener,'x') <> 'Retener'
         and cta.tip_impresion not in ('N','Z')
         and cta.cli_confidencial = 'N'
         AND CTA.FRE_EXTRACTO = 'M'
         and cta.cod_persona = g.cod_persona
         and nvl(g.cli_especial,'N') = 'S'
         and g.cod_seg_preferente = 1
         and cta.cod_persona = p.cod_persona
         and bpd.cod_persona = cta.cod_persona
         and bpd.parametro  = 'TIP_GEN_EXTRACTOS'
         /*and exists (Select 's' from ge_ext_cli_movimientos a
                     where a.cod_persona = cta.cod_persona
                     and   a.nro_cuenta = cta.nro_cuenta )*/
         and exists  (Select 's' from ge_ext_cli_movimientos t
                  where t.cod_Extracto = cta.cod_extracto
                  and t.cod_persona = cta.cod_persona
                  and t.fec_extracto = p_fecha)
     
       order by cta.cod_oficina, to_number(cta.cod_persona);

  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'vip_no_retener'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_fec_sist         DATE;
  v_fecha            VARCHAR2(8);

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
  select pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1)
  into v_fec_sist
  from dual;

  v_fecha := to_char(v_fec_sist,'DDMMYYYY');

-- Abrir archivo
v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'.txt','W',32767);

-- Colocar el titulo a los campos
v_linetit := 'CLIENTE'||CHR(9)||'CUENTA'||CHR(9)||'NOMBRE'||CHR(9)||'DIRECCION'||CHR(9)||'CIUDAD'||CHR(9)||'PISO'||CHR(9)||'DPTO'||CHR(9)||'EDIFICIO'||CHR(9)||/*'PREFIJO'||CHR(9)||*/'TELEFONO'||CHR(9)||'SUCURSAL'||CHR(9)||/*'TIPO_CUENTA'||CHR(9)||*//*'SUB_CUENTA'||CHR(9)||*/'EMPRESA'||CHR(9)||'RETENER'||CHR(9)||'TIP_IMPRESION'||CHR(9)||'NRO_DOCUMENTO'||CHR(9)||'CUENTAS_CONSOLIDADAS'||CHR(9)||'TIP_GEN_EXTRACTO';
utl_file.put_line(v_file,v_linetit);

-- Definir una linea en blanco para separar los datos del titulo de los campos
v_linetit := ' ';
utl_file.put_line(v_file,v_linetit);

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN cu_vip_no_reten(v_fec_sist) LOOP

    --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
  v_line := to_char(rec.cliente)||chr(9)||to_char(rec.nro_cuenta)||chr(9)||to_char(rec.nombre)||chr(9)||
            to_char(rec.direccion)||chr(9)||to_char(rec.ciudad)||chr(9)||to_char(rec.piso)||chr(9)||to_char(rec.departamento)||chr(9)||to_char(rec.edificio)||chr(9)||/*to_char(rec.prefijo)||chr(9)||*/to_char(rec.telefono)||chr(9)||
            to_char(rec.sucursal)||chr(9)||/*to_char(rec.tipo_cuenta)||chr(9)||*//*to_char(rec.sub_cuenta)||chr(9)||*/
             to_char(rec.empresa)||chr(9)||to_char(rec.retener)||chr(9)||to_char(rec.tip_impresion)||chr(9)||to_char(rec.nro_documento)||chr(9)||to_char(rec.cuenta_c)||chr(9)||to_char(rec.TIP_GENERACION);

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

  EXIT WHEN cu_vip_no_reten%NOTFOUND;
END LOOP;
--Escribes la linea en el fichero
UTL_FILE.PUT_LINE(v_file, v_buffer);

--Cerrar el handler al fichero
UTL_FILE.FCLOSE(v_file);
COMMIT;

  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_respuesta := pa_file_ftp.fu_put_ascii(pa_rpc_aut.g_ip, pa_rpc_aut.g_port, pa_rpc_aut.g_user,
                                          pa_rpc_aut.g_pass, pa_rpc_aut.g_repository,
                                          v_name||'.txt', g_extractos||v_name||'_'||v_fecha||'.txt');

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','VIP_NO_RETENER');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte Vip No Retener a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_extractos||'

    Nombre del Archivo: '||v_name||'_'||v_fecha||'.txt';

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error    := null;

    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, v_name||'_'||v_fecha||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;

    --Enviamos el mail a soporte
     -- Obtenemos direccion de correo de soporte
     v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error Reporte Vip No Retener a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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
END pr_vip_no_reten;
-------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------
-- Extracto Vip Nomina
PROCEDURE pr_vip_nomina
IS
CURSOR cu_vip_nomina(p_fecha DATE) IS
      select cta.cod_persona cliente,
             nro_cuenta,
             nombre,
             cta.direccion_ente direccion,
             cta.piso_ente piso,
             cta.departamento_ente departamento,
             cta.edificio_ente edificio,
             p.nro_documento,
             prefijo,
             telefono,
             sucursal,
             tipo_cuenta,
             sub_cuenta,
             cliente Empresa,
             retener,
             cta.tip_impresion,
             cta.Cuenta cuenta_c,
             --fue_per_dat_adicional(CTA.COD_PERSONA,'TIP_GEN_EXTRACTOS') TIP_GENERACION,
             bpd.val_parametro TIP_GENERACION,cta.ciudad,
             cta.direccion_ente direc_ente,--dirección ente
             cta.piso_ente piso_ente, --piso ente
             cta.departamento_ente dpto_ente, --dpto ente
             cta.edificio_ente  --edificio ente
        from gv_extracto cta, ge_clientes g, ba_personas p, ba_per_dat_adicionales bpd
       where cta.Cliente is not null
         and cta.funcionario = 'N'
         and cta.fec_extracto = p_fecha
         and cta.tip_impresion not in ('N','Z')
         and cta.cli_confidencial = 'N'
         AND CTA.FRE_EXTRACTO = 'M'
         and cta.cod_persona = g.cod_persona
         and cta.cod_persona = p.cod_persona
         and bpd.cod_persona = cta.cod_persona
         and bpd.parametro  = 'TIP_GEN_EXTRACTOS'
         and nvl(g.cli_especial,'N') = 'S'
         and g.cod_seg_preferente = 1
         /*and exists (Select 's' from ge_ext_cli_movimientos a
                     where a.cod_persona = cta.cod_persona
                     and   a.nro_cuenta = cta.nro_cuenta )*/
         and exists  (Select 's' from ge_ext_cli_movimientos t
                  where t.cod_Extracto = cta.cod_extracto
                  and t.cod_persona = cta.cod_persona
                  and t.fec_extracto = p_fecha)
     
       order by cta.Sucursal, cta.Cliente, to_number(cta.cod_persona);

  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'vip_nomina'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_fec_sist         DATE;
  v_fecha            VARCHAR2(8);

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
  select pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1)
  into v_fec_sist
  from dual;

  v_fecha := to_char(v_fec_sist,'DDMMYYYY');

-- Abrir archivo
v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'.txt','W',32767);

-- Colocar el titulo a los campos
v_linetit := 'CLIENTE'||CHR(9)||'CUENTA'||CHR(9)||'NOMBRE'||CHR(9)||'DIRECCION'||CHR(9)||'CIUDAD'||CHR(9)||'PISO'||CHR(9)||'DPTO'||CHR(9)||'EDIFICIO'||CHR(9)||/*'PREFIJO'||CHR(9)||*/'TELEFONO'||CHR(9)||'SUCURSAL'||CHR(9)||/*'TIPO_CUENTA'||CHR(9)||*//*'SUB_CUENTA'||CHR(9)||*/'EMPRESA'||CHR(9)||'RETENER'||CHR(9)||'TIP_IMPRESION'||CHR(9)||'NRO_DOCUMENTO'||CHR(9)||'CUENTAS_CONSOLIDADAS'||CHR(9)||'TIP_GEN_EXTRACTO'||CHR(9)||'DIRECCION_EMPRESA'||CHR(9)||'CIUDAD_EMPRESA'||CHR(9)||'PISO_EMPRESA'||CHR(9)||'DPTO_EMPRESA'||CHR(9)||'EDIFICIO_EMPRESA';
utl_file.put_line(v_file,v_linetit);

-- Definir una linea en blanco para separar los datos del titulo de los campos
v_linetit := ' ';
utl_file.put_line(v_file,v_linetit);

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN cu_vip_nomina(v_fec_sist) LOOP

    --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
  v_line := to_char(rec.cliente)||chr(9)||to_char(rec.nro_cuenta)||chr(9)||to_char(rec.nombre)||chr(9)||
            to_char(rec.direccion)||chr(9)||to_char(rec.ciudad)||chr(9)||to_char(rec.piso)||chr(9)||to_char(rec.departamento)||chr(9)||to_char(rec.edificio)||chr(9)||/*to_char(rec.prefijo)||chr(9)||*/to_char(rec.telefono)||chr(9)||
            to_char(rec.sucursal)||chr(9)||/*to_char(rec.tipo_cuenta)||chr(9)||*//*to_char(rec.sub_cuenta)||chr(9)||*/
             to_char(rec.empresa)||chr(9)||to_char(rec.retener)||chr(9)||to_char(rec.tip_impresion)||chr(9)||to_char(rec.nro_documento)||chr(9)||to_char(rec.cuenta_c)||chr(9)||to_char(rec.TIP_GENERACION)||chr(9)||to_char(rec.direc_ente)||chr(9)||to_char(rec.ciudad)||chr(9)||to_char(rec.piso_ente)||chr(9)||to_char(rec.dpto_ente)||chr(9)||to_char(rec.edificio_ente);

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

  EXIT WHEN cu_vip_nomina%NOTFOUND;
END LOOP;
--Escribes la linea en el fichero
UTL_FILE.PUT_LINE(v_file, v_buffer);

--Cerrar el handler al fichero
UTL_FILE.FCLOSE(v_file);
COMMIT;

  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_respuesta := pa_file_ftp.fu_put_ascii(pa_rpc_aut.g_ip, pa_rpc_aut.g_port, pa_rpc_aut.g_user,
                                          pa_rpc_aut.g_pass, pa_rpc_aut.g_repository,
                                          v_name||'.txt', g_extractos||v_name||'_'||v_fecha||'.txt');

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','VIP_NOMINA');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte Vip Nomina a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_extractos||'

    Nombre del Archivo: '||v_name||'_'||v_fecha||'.txt';

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error    := null;

    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, v_name||'_'||v_fecha||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;

    --Enviamos el mail a soporte
     -- Obtenemos direccion de correo de soporte
     v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error Reporte Vip Nomina a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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
END pr_vip_nomina;
-------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------
-- Extracto Premiun Retener
PROCEDURE pr_prem_retener
IS
CURSOR cu_premiun_ret(p_fecha DATE) IS
      select CTA.cod_persona cliente,
           nro_cuenta,
           nombre,
           cta.direccion_retener,
           cta.piso,
           cta.departamento,
           cta.edificio,
           p.nro_documento,
           prefijo,
           telefono,
           sucursal,
           tipo_cuenta,
           sub_cuenta,
           cliente Empresa,
           retener,
           cta.tip_impresion,
           cta.Cuenta cuenta_c,
           --fue_per_dat_adicional(CTA.COD_PERSONA,'TIP_GEN_EXTRACTOS') TIP_GENERACION
           bpd.val_parametro TIP_GENERACION,cta.ciudad
        from gv_extracto cta, ge_clientes g, ba_personas p, ba_per_dat_adicionales bpd
       where cta.Cliente is null
         and cta.funcionario = 'N'
         and cta.fec_extracto = p_fecha
         and nvl(cta.Retener,'x') ='Retener'
         and cta.tip_impresion not in ('N','Z')
         and cta.cli_confidencial = 'N'
         AND CTA.FRE_EXTRACTO = 'M'
         and cta.cod_persona = g.cod_persona
         and nvl(g.cli_especial,'N') = 'S'
         and g.cod_seg_preferente = 2
         and cta.cod_persona = p.cod_persona
         and bpd.cod_persona = cta.cod_persona
         and bpd.parametro  = 'TIP_GEN_EXTRACTOS'
         /*and exists (Select 's' from ge_ext_cli_movimientos a
                     where a.cod_persona = cta.cod_persona
                     and   a.nro_cuenta = cta.nro_cuenta )*/
         and exists  (Select 's' from ge_ext_cli_movimientos t
                  where t.cod_Extracto = cta.cod_extracto
                  and t.cod_persona = cta.cod_persona
                  and t.fec_extracto = p_fecha)
     
       order by cta.cod_oficina, to_number(cta.cod_persona);

  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'premiun_retener'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_fec_sist         DATE;
  v_fecha            VARCHAR2(8);

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
  select pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1)
  into v_fec_sist
  from dual;

  v_fecha := to_char(v_fec_sist,'DDMMYYYY');

-- Abrir archivo
v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'.txt','W',32767);

-- Colocar el titulo a los campos
v_linetit := 'CLIENTE'||CHR(9)||'CUENTA'||CHR(9)||'NOMBRE'||CHR(9)||'DIRECCION'||CHR(9)||'CIUDAD'||CHR(9)||'PISO'||CHR(9)||'DPTO'||CHR(9)||'EDIFICIO'||CHR(9)||/*'PREFIJO'||CHR(9)||*/'TELEFONO'||CHR(9)||'SUCURSAL'||CHR(9)||/*'TIPO_CUENTA'||CHR(9)||*//*'SUB_CUENTA'||CHR(9)||*/'EMPRESA'||CHR(9)||'RETENER'||CHR(9)||'TIP_IMPRESION'||CHR(9)||'NRO_DOCUMENTO'||CHR(9)||'CUENTAS_CONSOLIDADAS'||CHR(9)||'TIP_GEN_EXTRACTO';
utl_file.put_line(v_file,v_linetit);

-- Definir una linea en blanco para separar los datos del titulo de los campos
v_linetit := ' ';
utl_file.put_line(v_file,v_linetit);

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN cu_premiun_ret(v_fec_sist) LOOP

    --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
  v_line := to_char(rec.cliente)||chr(9)||to_char(rec.nro_cuenta)||chr(9)||to_char(rec.nombre)||chr(9)||
            to_char(rec.direccion_retener)||chr(9)||to_char(rec.ciudad)||chr(9)||to_char(rec.piso)||chr(9)||to_char(rec.departamento)||chr(9)||to_char(rec.edificio)||chr(9)||/*to_char(rec.prefijo)||chr(9)||*/to_char(rec.telefono)||chr(9)||
            to_char(rec.sucursal)||chr(9)||/*to_char(rec.tipo_cuenta)||chr(9)||*//*to_char(rec.sub_cuenta)||chr(9)||*/
             to_char(rec.empresa)||chr(9)||to_char(rec.retener)||chr(9)||to_char(rec.tip_impresion)||chr(9)||to_char(rec.nro_documento)||chr(9)||to_char(rec.cuenta_c)||chr(9)||to_char(rec.TIP_GENERACION);

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

  EXIT WHEN cu_premiun_ret%NOTFOUND;
END LOOP;
--Escribes la linea en el fichero
UTL_FILE.PUT_LINE(v_file, v_buffer);

--Cerrar el handler al fichero
UTL_FILE.FCLOSE(v_file);
COMMIT;

  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_respuesta := pa_file_ftp.fu_put_ascii(pa_rpc_aut.g_ip, pa_rpc_aut.g_port, pa_rpc_aut.g_user,
                                          pa_rpc_aut.g_pass, pa_rpc_aut.g_repository,
                                          v_name||'.txt', g_extractos||v_name||'_'||v_fecha||'.txt');

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','PREMIUN_RETENER');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte Premiun Retener a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_extractos||'

    Nombre del Archivo: '||v_name||'_'||v_fecha||'.txt';

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error    := null;

    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, v_name||'_'||v_fecha||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;

    --Enviamos el mail a soporte
     -- Obtenemos direccion de correo de soporte
     v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error Reporte Premiun Retener a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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
END pr_prem_retener;
-------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------
-- Extracto Premiun No Retener
PROCEDURE pr_pre_no_reten
IS
CURSOR cu_prem_no_reten(p_fecha DATE) IS
     select CTA.cod_persona cliente,
           nro_cuenta,
           nombre,
           cta.direccion,
           cta.piso,
           cta.departamento,
           cta.edificio,
           p.nro_documento,
           prefijo,
           telefono,
           sucursal,
           tipo_cuenta,
           sub_cuenta,
           cliente Empresa,
           retener,
           cta.tip_impresion,
           cta.Cuenta cuenta_c,
           --fue_per_dat_adicional(CTA.COD_PERSONA,'TIP_GEN_EXTRACTOS') TIP_GENERACION
           bpd.val_parametro TIP_GENERACION,cta.ciudad
        from gv_extracto cta, ge_clientes g, ba_personas p, ba_per_dat_adicionales bpd
       where cta.Cliente is null
         and cta.funcionario = 'N'
         and cta.fec_extracto = p_fecha
         and nvl(cta.Retener,'x') <> 'Retener'
         and cta.tip_impresion not in ('N','Z')
         and cta.cli_confidencial = 'N'
         AND CTA.FRE_EXTRACTO = 'M'
         and cta.cod_persona = g.cod_persona
         and nvl(g.cli_especial,'N') = 'S'
         and g.cod_seg_preferente = 2
         and cta.cod_persona = p.cod_persona
         and bpd.cod_persona = cta.cod_persona
         and bpd.parametro  = 'TIP_GEN_EXTRACTOS'
         /*and exists (Select 's' from ge_ext_cli_movimientos a
                     where a.cod_persona = cta.cod_persona
                     and   a.nro_cuenta = cta.nro_cuenta )*/
         and exists  (Select 's' from ge_ext_cli_movimientos t
                  where t.cod_Extracto = cta.cod_extracto
                  and t.cod_persona = cta.cod_persona
                  and t.fec_extracto = p_fecha)
     
       order by cta.cod_oficina, to_number(cta.cod_persona);

  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'premiun_no_reten'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_fec_sist         DATE;
  v_fecha            VARCHAR2(8);

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
  select pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1)
  into v_fec_sist
  from dual;

  v_fecha := to_char(v_fec_sist,'DDMMYYYY');

-- Abrir archivo
v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'.txt','W',32767);

-- Colocar el titulo a los campos
v_linetit := 'CLIENTE'||CHR(9)||'CUENTA'||CHR(9)||'NOMBRE'||CHR(9)||'DIRECCION'||CHR(9)||'CIUDAD'||CHR(9)||'PISO'||CHR(9)||'DPTO'||CHR(9)||'EDIFICIO'||CHR(9)||/*'PREFIJO'||CHR(9)||*/'TELEFONO'||CHR(9)||'SUCURSAL'||CHR(9)||/*'TIPO_CUENTA'||CHR(9)||*//*'SUB_CUENTA'||CHR(9)||*/'EMPRESA'||CHR(9)||'RETENER'||CHR(9)||'TIP_IMPRESION'||CHR(9)||'NRO_DOCUMENTO'||CHR(9)||'CUENTAS_CONSOLIDADAS'||CHR(9)||'TIP_GEN_EXTRACTO';
utl_file.put_line(v_file,v_linetit);

-- Definir una linea en blanco para separar los datos del titulo de los campos
v_linetit := ' ';
utl_file.put_line(v_file,v_linetit);

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN cu_prem_no_reten(v_fec_sist) LOOP

    --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
  v_line := to_char(rec.cliente)||chr(9)||to_char(rec.nro_cuenta)||chr(9)||to_char(rec.nombre)||chr(9)||
            to_char(rec.direccion)||chr(9)||to_char(rec.ciudad)||chr(9)||to_char(rec.piso)||chr(9)||to_char(rec.departamento)||chr(9)||to_char(rec.edificio)||chr(9)||/*to_char(rec.prefijo)||chr(9)||*/to_char(rec.telefono)||chr(9)||
            to_char(rec.sucursal)||chr(9)||/*to_char(rec.tipo_cuenta)||chr(9)||*//*to_char(rec.sub_cuenta)||chr(9)||*/
             to_char(rec.empresa)||chr(9)||to_char(rec.retener)||chr(9)||to_char(rec.tip_impresion)||chr(9)||to_char(rec.nro_documento)||chr(9)||to_char(rec.cuenta_c)||chr(9)||to_char(rec.TIP_GENERACION);

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

  EXIT WHEN cu_prem_no_reten%NOTFOUND;
END LOOP;
--Escribes la linea en el fichero
UTL_FILE.PUT_LINE(v_file, v_buffer);

--Cerrar el handler al fichero
UTL_FILE.FCLOSE(v_file);
COMMIT;

  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_respuesta := pa_file_ftp.fu_put_ascii(pa_rpc_aut.g_ip, pa_rpc_aut.g_port, pa_rpc_aut.g_user,
                                          pa_rpc_aut.g_pass, pa_rpc_aut.g_repository,
                                          v_name||'.txt', g_extractos||v_name||'_'||v_fecha||'.txt');

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','PREMIUN_NO_RETEN');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte Premiun No Retener a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_extractos||'

    Nombre del Archivo: '||v_name||'_'||v_fecha||'.txt';

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error    := null;

    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, v_name||'_'||v_fecha||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;

    --Enviamos el mail a soporte
     -- Obtenemos direccion de correo de soporte
     v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error Reporte Premiun No Retener a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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
END pr_pre_no_reten;
-------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------
-- Extracto Premiun Nomina
PROCEDURE pr_prem_nomina
IS
CURSOR cu_prem_nomina(p_fecha DATE) IS
      select cta.cod_persona cliente,
             nro_cuenta,
             nombre,
             cta.direccion_ente direccion,
             cta.piso_ente piso,
             cta.departamento_ente departamento,
             cta.edificio_ente edificio,
             p.nro_documento,
             prefijo,
             telefono,
             sucursal,
             tipo_cuenta,
             sub_cuenta,
             cliente Empresa,
             retener,
             cta.tip_impresion,
             cta.Cuenta cuenta_c,
             --fue_per_dat_adicional(CTA.COD_PERSONA,'TIP_GEN_EXTRACTOS') TIP_GENERACION,
             bpd.val_parametro TIP_GENERACION,cta.ciudad,
             cta.direccion_ente direc_ente,--dirección ente
             cta.piso_ente piso_ente, --piso ente
             cta.departamento_ente dpto_ente, --dpto ente
             cta.edificio_ente  --edificio ente
        from gv_extracto cta, ge_clientes g, ba_personas p, ba_per_dat_adicionales bpd
       where cta.Cliente is not null
         and cta.funcionario = 'N'
         and cta.fec_extracto = p_fecha
         and cta.tip_impresion not in ('N','Z')
         and cta.cli_confidencial = 'N'
         AND CTA.FRE_EXTRACTO = 'M'
         and cta.cod_persona = g.cod_persona
         and cta.cod_persona = p.cod_persona
         and bpd.cod_persona = cta.cod_persona
         and bpd.parametro  = 'TIP_GEN_EXTRACTOS'
         and nvl(g.cli_especial,'N') = 'S'
         and g.cod_seg_preferente = 2
         /*and exists (Select 's' from ge_ext_cli_movimientos a
                     where a.cod_persona = cta.cod_persona
                     and   a.nro_cuenta = cta.nro_cuenta )*/
         and exists  (Select 's' from ge_ext_cli_movimientos t
                  where t.cod_Extracto = cta.cod_extracto
                  and t.cod_persona = cta.cod_persona
                  and t.fec_extracto = p_fecha)
     
       order by cta.Sucursal, cta.Cliente, to_number(cta.cod_persona);

  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'premiun_nomina'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_fec_sist         DATE;
  v_fecha            VARCHAR2(8);

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
  select pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1) --DYDMR-4616
  into v_fec_sist
  from dual;

  v_fecha := to_char(v_fec_sist,'DDMMYYYY');

-- Abrir archivo
v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'.txt','W',32767);

-- Colocar el titulo a los campos
v_linetit := 'CLIENTE'||CHR(9)||'CUENTA'||CHR(9)||'NOMBRE'||CHR(9)||'DIRECCION'||CHR(9)||'CIUDAD'||CHR(9)||'PISO'||CHR(9)||'DPTO'||CHR(9)||'EDIFICIO'||CHR(9)||/*'PREFIJO'||CHR(9)||*/'TELEFONO'||CHR(9)||'SUCURSAL'||CHR(9)||/*'TIPO_CUENTA'||CHR(9)||*//*'SUB_CUENTA'||CHR(9)||*/'EMPRESA'||CHR(9)||'RETENER'||CHR(9)||'TIP_IMPRESION'||CHR(9)||'NRO_DOCUMENTO'||CHR(9)||'CUENTAS_CONSOLIDADAS'||CHR(9)||'TIP_GEN_EXTRACTO'||CHR(9)||'DIRECCION_EMPRESA'||CHR(9)||'CIUDAD_EMPRESA'||CHR(9)||'PISO_EMPRESA'||CHR(9)||'DPTO_EMPRESA'||CHR(9)||'EDIFICIO_EMPRESA';
utl_file.put_line(v_file,v_linetit);

-- Definir una linea en blanco para separar los datos del titulo de los campos
v_linetit := ' ';
utl_file.put_line(v_file,v_linetit);

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN cu_prem_nomina(v_fec_sist) LOOP

    --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
  v_line := to_char(rec.cliente)||chr(9)||to_char(rec.nro_cuenta)||chr(9)||to_char(rec.nombre)||chr(9)||
            to_char(rec.direccion)||chr(9)||to_char(rec.ciudad)||chr(9)||to_char(rec.piso)||chr(9)||to_char(rec.departamento)||chr(9)||to_char(rec.edificio)||chr(9)||/*to_char(rec.prefijo)||chr(9)||*/to_char(rec.telefono)||chr(9)||
            to_char(rec.sucursal)||chr(9)||/*to_char(rec.tipo_cuenta)||chr(9)||*//*to_char(rec.sub_cuenta)||chr(9)||*/
             to_char(rec.empresa)||chr(9)||to_char(rec.retener)||chr(9)||to_char(rec.tip_impresion)||chr(9)||to_char(rec.nro_documento)||chr(9)||to_char(rec.cuenta_c)||chr(9)||to_char(rec.TIP_GENERACION)||chr(9)||to_char(rec.direc_ente)||chr(9)||to_char(rec.ciudad)||chr(9)||to_char(rec.piso_ente)||chr(9)||to_char(rec.dpto_ente)||chr(9)||to_char(rec.edificio_ente);

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

  EXIT WHEN cu_prem_nomina%NOTFOUND;
END LOOP;
--Escribes la linea en el fichero
UTL_FILE.PUT_LINE(v_file, v_buffer);

--Cerrar el handler al fichero
UTL_FILE.FCLOSE(v_file);
COMMIT;

  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_respuesta := pa_file_ftp.fu_put_ascii(pa_rpc_aut.g_ip, pa_rpc_aut.g_port, pa_rpc_aut.g_user,
                                          pa_rpc_aut.g_pass, pa_rpc_aut.g_repository,
                                          v_name||'.txt', g_extractos||v_name||'_'||v_fecha||'.txt');

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','PREMIUN_NOMINA');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte Premiun Nomina a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_extractos||'

    Nombre del Archivo: '||v_name||'_'||v_fecha||'.txt';

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error    := null;

    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, v_name||'_'||v_fecha||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;

    --Enviamos el mail a soporte
     -- Obtenemos direccion de correo de soporte
     v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error Reporte Premiun Nomina a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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
END pr_prem_nomina;
-------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------
-- Procedimiento para obtener los extractos
PROCEDURE pr_ob_extractos
IS

  -- Variable de fecha
  v_fec_sist         DATE;

  -- Variables para mail
  v_conn             utl_smtp.connection;
  v_para             VARCHAR2(500);
  v_asunto           VARCHAR2(2000);
  v_mje_mail         VARCHAR2(4000);
  v_hini_mail        ge_ra_log_mail.hor_inicio%type;
  v_hfin_mail        ge_ra_log_mail.hor_fin%type;
  v_det_error        ge_ra_log_mail.det_error%type;

  BEGIN

  -- Obtenemos la fecha del sistema
  select pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1) --DYDMR-4616
  into v_fec_sist
  from dual;

    BEGIN
      -- Extracto Funcionarios
      pa_rpc_aut.pr_ext_func;
      commit;

      -- Extracto Normales Retener
      pa_rpc_aut.pr_nor_retener;
      commit;

      -- Extracto Normales No Retener
      pa_rpc_aut.pr_nor_no_reten;
      commit;

      -- Extracto Nomina Otras Sucursales
      pa_rpc_aut.pr_nomina_suc;
      commit;

      -- Extracto Nomina Sucursal 1
      pa_rpc_aut.pr_obt_nomina;
      commit;

      -- Extracto Vip Retener
      pa_rpc_aut.pr_vip_retener;
      commit;
      -- Extracto Vip No Retener
      pa_rpc_aut.pr_vip_no_reten;
      commit;

      -- Extracto Vip Nomina
      pa_rpc_aut.pr_vip_nomina;
      commit;

      -- Extracto Premiun Retener
      pa_rpc_aut.pr_prem_retener;
      commit;

      -- Extracto Premiun No Retener
      pa_rpc_aut.pr_pre_no_reten;
      commit;

      -- Extracto Premiun Nomina
      pa_rpc_aut.pr_prem_nomina;
      commit;
      --Extracto cliente confidencial
      pa_rpc_aut.pr_cli_confidencial;
      commit;

      /************** Enviamos el mail a soporte *********************/
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

      -- Damos valor a los demas datos
      v_asunto := 'Reportes de Extractos a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'Los archivos correspondiente a Extractos fueron creados.

      Dichos archivos se encuentran en la siguiente dirección: '||g_compartido||g_extractos||'';

       -- Enviamos el mail
        v_det_error    := null;
        v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

        BEGIN
          v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
          it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
          it_mail.end_mail(v_conn);
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
             (SYSDATE, 'procedure de extractos', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
            COMMIT;
        END IF;
    EXCEPTION
      WHEN OTHERS THEN
       --Enviamos el mail de error a soporte
       -- Obtenemos direccion de correo de soporte
       v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

      -- Damos valor a los demas datos
        v_asunto := 'Error al ejecutar procedimiento de extractos a la fecha '||v_fec_sist||'.';
        v_mje_mail := 'Error al ejecutar los procedimientos.

        Error: '||substr(sqlerrm,1,4000)||'.';

        v_hini_mail := to_char(sysdate,'hh24:mi:ss');

        BEGIN
          v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
          it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
          it_mail.end_mail(v_conn);
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
             (SYSDATE, 'Error envio mail extractos', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
            COMMIT;
        END IF;
    END;
END pr_ob_extractos;
-------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------
-- Libro IVA de Compras Mensual
PROCEDURE pr_liva_compra
IS
CURSOR cu_liva_compra(p_fecha_des VARCHAR2, p_fecha_has VARCHAR2) IS
          select m.FECHA,to_char(c.fecha,('hh:mm:ss')) hora,c.usu_insercion,l.nro_factura,l.nro_timbrado,
           c.concepto,l.nro_documento,'GS' cod_moneda, l.mto_exento mto_exento, l.mto_exento mto_exento_gs,
           l.mto_gravado_5 mto_gravado_5,l.mto_gravado_5 mto_gra_5_gs,l.mto_gravado_10 mto_gravado_10,l.mto_gravado_10 mto_gra_10_gs,
           l.impuesto_5 impuesto_5,l.impuesto_5 impuesto_5_gs,l.impuesto_10 impuesto_10,l.impuesto_10 impuesto_10_gs,1 cotizacion,
           a.nro_asiento,a.nro_linea
          from gv_movimientos m,pv_compras c, cb_lib_compras l,cb_asi_automaticos_det a
         where m.NRO_DOCUMENTO4         = a.ref_movimiento
           and   m.FECHA between p_fecha_des and  p_fecha_has
           and   m.FECHA                = a.fecha
           and   m.FECHA                = l.fec_pago
           and   substr(m.concepto,7,15)= l.nro_factura
           and   l.nro_factura          = c.nro_factura
           and   l.nro_timbrado         = c.timbrado
           and   l.cod_ent_proveedor    = c.cod_ent_proveedor
           and   a.tip_movimiento       = 'D'
        union
        select m.FECHA,to_char(c.fecha,('hh:mm:ss')) hora,c.usu_insercion,l.nro_factura,l.nro_timbrado,
               c.concepto,l.nro_documento,'GS' cod_moneda, l.mto_exento mto_exento, l.mto_exento mto_exento_gs,
               l.mto_gravado_5 mto_gravado_5,l.mto_gravado_5 mto_gra_5_gs,l.mto_gravado_10 mto_gravado_10,l.mto_gravado_10 mto_gra_10_gs,
               l.impuesto_5 impuesto_5,l.impuesto_5 impuesto_5_gs,l.impuesto_10 impuesto_10,l.impuesto_10 impuesto_10_gs,1 cotizacion,
               a.nro_asiento,a.nro_linea
          from gv_movimientos m,pv_compras c, cb_lib_compras l,cb_asi_automaticos_det a
         where m.NRO_DOCUMENTO4             = a.ref_movimiento
           and   m.FECHA                   between p_fecha_des and  p_fecha_has
           and   m.FECHA                    = a.fecha
           and   m.FECHA                    = l.fec_pago
           and   substr(m.concepto,7,15)    = l.nro_factura
           and   l.nro_factura              = c.nro_factura
           and   l.nro_timbrado             = c.timbrado
           and   l.cod_ent_proveedor        = c.cod_ent_proveedor
           and   l.mto_gravado_10           = 0
           and   l.mto_gravado_5            = 0
           and   a.tip_movimiento           = 'C';

  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'libro_IVA_compra'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_fec_sist         VARCHAR2(10);
  v_fecha            VARCHAR2(8);
  v_dia_ini          VARCHAR2(10);
  v_dia_fin          VARCHAR2(10);

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
  v_fec_sist := to_char(sysdate,'DD/MM/YYYY');

  v_fecha := to_char(sysdate,'DDMMYYYY');

  --Obtenemos el primer dia y el ultimo dia del mes
  v_dia_ini := to_char(trunc(sysdate,'month'),'DD/MM/YYYY');
  v_dia_fin := to_char(last_day(sysdate),'DD/MM/YYYY');

-- Abrir archivo
v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'.txt','W',32767);

-- Colocar el titulo a los campos
v_linetit := 'FECHA'||CHR(9)||'HORA'||CHR(9)||'USU_INSERCION'||CHR(9)||'NRO_FACTURA'||CHR(9)||'NRO_TIMBRADO'||CHR(9)||
             'CONCEPTO'||CHR(9)||'NRO_DOCUMENTO'||CHR(9)||'COD_MONEDA'||CHR(9)||'MTO_EXENTO'||CHR(9)||'MTO_EXENTO_GS'||CHR(9)||
             'MTO_GRAVADO_5'||CHR(9)||'MTO_GRA_5_GS'||CHR(9)||'MTO_GRAVADO_10'||CHR(9)||'MTO_GRA_10_GS'||CHR(9)||'IMPUESTO_5'||CHR(9)||
             'IMPUESTO_5_GS'||CHR(9)||'IMPUESTO_10'||CHR(9)||'IMPUESTO_10_GS'||CHR(9)||'COTIZACION'||CHR(9)||
             'NRO_ASIENTO'||CHR(9)||'NRO_LINEA';

utl_file.put_line(v_file,v_linetit);

-- Definir una linea en blanco para separar los datos del titulo de los campos
v_linetit := ' ';
utl_file.put_line(v_file,v_linetit);

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN cu_liva_compra(v_dia_ini, v_dia_fin) LOOP

    --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
  v_line := to_char(rec.FECHA)||chr(9)||to_char(rec.HORA)||chr(9)||to_char(rec.USU_INSERCION)||chr(9)||to_char(rec.NRO_FACTURA)||chr(9)||
            to_char(rec.NRO_TIMBRADO)||chr(9)||to_char(rec.CONCEPTO)||chr(9)||to_char(rec.NRO_DOCUMENTO)||chr(9)||
            to_char(rec.COD_MONEDA)||chr(9)||to_char(rec.MTO_EXENTO,'999999999999999999D00')||chr(9)||to_char(rec.MTO_EXENTO_GS,'999999999999999999D00')||chr(9)||
            to_char(rec.MTO_GRAVADO_5,'999999999999D00')||chr(9)||to_char(rec.MTO_GRA_5_GS,'999999999999999999D00')||chr(9)||
            to_char(rec.MTO_GRAVADO_10,'999999999999999999D00')||chr(9)||to_char(rec.MTO_GRA_10_GS,'999999999999999999D00')||chr(9)||
            to_char(rec.IMPUESTO_5,'999999999999999999D00')||chr(9)||to_char(rec.IMPUESTO_5_GS,'999999999999999999D00')||chr(9)||
            to_char(rec.IMPUESTO_10,'999999999999999999D00')||chr(9)||to_char(rec.IMPUESTO_10_GS,'999999999999999999D00')||chr(9)||
            to_char(rec.COTIZACION,'999999999999999999D00')||chr(9)||to_char(rec.NRO_ASIENTO)||chr(9)||to_char(rec.NRO_LINEA);

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

  EXIT WHEN cu_liva_compra%NOTFOUND;
END LOOP;
--Escribes la linea en el fichero
UTL_FILE.PUT_LINE(v_file, v_buffer);

--Cerrar el handler al fichero
UTL_FILE.FCLOSE(v_file);
COMMIT;

  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_respuesta := pa_file_ftp.fu_put_ascii(pa_rpc_aut.g_ip, pa_rpc_aut.g_port, pa_rpc_aut.g_user,
                                          pa_rpc_aut.g_pass, pa_rpc_aut.g_repository,
                                          v_name||'.txt', g_contabilidad||v_name||'_'||v_fecha||'.txt');

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','LIBRO_IVA_COMPRA');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte Libro IVA Compras a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_contabilidad||'

    Nombre del Archivo: '||v_name||'_'||v_fecha||'.txt';

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error    := null;

    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, v_name||'_'||v_fecha||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;

    --Enviamos el mail a soporte
     -- Obtenemos direccion de correo de soporte
     v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error Libro IVA Compras a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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
END pr_liva_compra;
-------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------
-- Libro IVA de Ventas Mensual
PROCEDURE pr_liva_venta
IS
CURSOR cu_liva_venta(p_fecha_des VARCHAR2, p_fecha_has VARCHAR2) IS
          select  c.fecha,c.hora,c.cod_usuario,a.nro_secuencia,c.nro_factura,c.nro_timbrado,
                  c.descripcion,c.nro_cuenta, c.cod_moneda,c.mto_exento,c.mto_exento_gs,
                  c.mto_gravado_5,c.mto_gra_5_gs,c.mto_gravado_10,c.mto_gra_10_gs,
                  c.impuesto_5,
                  (case when a.MTO_EQU_LOCAL is null then c.impuesto_5_gs
                              when abs(a.MTO_EQU_LOCAL) > c.impuesto_5_gs then (c.impuesto_5_gs + c.aju_impuesto_5)
                              when abs(a.MTO_EQU_LOCAL) < c.impuesto_5_gs then (c.impuesto_5_gs - c.aju_impuesto_5)
                              else c.impuesto_5_gs end) impuesto_5_gs,
                  c.impuesto_10,
                  (case when a.MTO_EQU_LOCAL is null then c.impuesto_10_gs
                              when abs(a.MTO_EQU_LOCAL) > c.impuesto_10_gs then (c.impuesto_10_gs + c.aju_impuesto_10)
                              when abs(a.MTO_EQU_LOCAL) < c.impuesto_10_gs then (c.impuesto_10_gs - c.aju_impuesto_10)
                              else c.impuesto_10_gs end) impuesto_10_gs,
                  c.cotizacion, b.nro_asiento,b.nro_linea
           from gv_movimientos a, cb_asi_automaticos_det b, cb_lib_ventas_det c
            where a.NRO_DOCUMENTO4 = b.ref_movimiento
              and a.FECHA between to_date(p_fecha_des,'dd/mm/yyyy') and to_date(p_fecha_has,'dd/mm/yyyy')
              and a.FECHA = b.fecha
              and a.FECHA = c.fecha
              and a.HORA = c.hora
              and (a.NRO_CUENTA = c.nro_cuenta or a.NRO_CUENTA is null)
              and (abs(a.monto) = c.impuesto_5 or abs(a.monto) = c.impuesto_10)
              and a.COD_TASA in (323,343,420)
              and (b.tip_movimiento = 'C' or (b.tip_movimiento = 'D' and a.MONTO < 0))
              and substr(b.cod_rubro,1,2) = '24'
          union
          select  c.fecha,c.hora,c.cod_usuario,a.nro_secuencia,c.nro_factura,c.nro_timbrado,
                  c.descripcion,c.nro_cuenta, c.cod_moneda,c.mto_exento,c.mto_exento_gs,
                  c.mto_gravado_5,c.mto_gra_5_gs,c.mto_gravado_10,c.mto_gra_10_gs,
                  c.impuesto_5,
                  (case when a.MTO_EQU_LOCAL is null then c.impuesto_5_gs
                              when abs(a.MTO_EQU_LOCAL) > c.impuesto_5_gs then (c.impuesto_5_gs + c.aju_impuesto_5)
                              when abs(a.MTO_EQU_LOCAL) < c.impuesto_5_gs then (c.impuesto_5_gs - c.aju_impuesto_5)
                              else c.impuesto_5_gs end) impuesto_5_gs,
                  c.impuesto_10,
                  (case when a.MTO_EQU_LOCAL is null then c.impuesto_10_gs
                              when abs(a.MTO_EQU_LOCAL) > c.impuesto_10_gs then (c.impuesto_10_gs + c.aju_impuesto_10)
                              when abs(a.MTO_EQU_LOCAL) < c.impuesto_10_gs then (c.impuesto_10_gs - c.aju_impuesto_10)
                              else c.impuesto_10_gs end) impuesto_10_gs,
                  c.cotizacion, b.nro_asiento,b.nro_linea
           from gv_movimientos a, cb_asi_automaticos_det b, cb_lib_ventas_det c
            where a.NRO_DOCUMENTO4 = b.ref_movimiento
              and a.FECHA between to_date(p_fecha_des,'dd/mm/yyyy') and to_date(p_fecha_has,'dd/mm/yyyy')
              and a.FECHA = b.fecha
              and a.FECHA = c.fecha
              and a.HORA = c.hora
              and (a.NRO_CUENTA = c.nro_cuenta or a.NRO_CUENTA is null)
              and (abs(a.monto) = c.impuesto_5 or abs(a.monto) = c.impuesto_10)
              and (b.tip_movimiento = 'C' or (b.tip_movimiento = 'D' and a.MONTO < 0))
              and a.cod_tasa is null
              and substr(b.cod_rubro,1,2) = '24'
              AND EXISTS (select 1
                                    from ge_transacciones_det gd
                                   where gd.cod_transaccion =a.cod_transaccion
                                     and pab_iva.fu_mov_con_iva(gd.cod_mod_hijo, gd.cod_mad_hijo, gd.cod_tra_hijo,null, null) = 'S');

  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'libro_IVA_venta_mensual'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_fec_sist         VARCHAR2(10);
  v_fecha            VARCHAR2(8);
  v_dia_ini          VARCHAR2(10);
  v_dia_fin          VARCHAR2(10);

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
  v_fec_sist := to_char(sysdate,'DD/MM/YYYY');

  v_fecha := to_char(sysdate,'DDMMYYYY');

  --Obtenemos el primer dia y el ultimo dia del mes
  v_dia_ini := to_char(trunc(sysdate,'month'),'DD/MM/YYYY');
  v_dia_fin := to_char(last_day(sysdate),'DD/MM/YYYY');

-- Abrir archivo
v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'.txt','W',32767);

-- Colocar el titulo a los campos
v_linetit := 'FECHA'||CHR(9)||'HORA'||CHR(9)||'COD_USUARIO'||CHR(9)||'NRO_SECUENCIA'||CHR(9)||'NRO_FACTURA'||CHR(9)||
             'NRO_TIMBRADO'||CHR(9)||'DESCRIPCION'||CHR(9)||'NRO_CUENTA'||CHR(9)||'COD_MONEDA'||CHR(9)||'MTO_EXENTO'||CHR(9)||
             'MTO_EXENTO_GS'||CHR(9)||'MTO_GRAVADO_5'||CHR(9)||'MTO_GRA_5_GS'||CHR(9)||'MTO_GRAVADO_10'||CHR(9)||
             'MTO_GRA_10_GS'||CHR(9)||'IMPUESTO_5'||CHR(9)||'IMPUESTO_5_GS'||CHR(9)||'IMPUESTO_10'||CHR(9)||
             'IMPUESTO_10_GS'||CHR(9)||'COTIZACION'||CHR(9)||'NRO_ASIENTO'||CHR(9)||'NRO_LINEA';

utl_file.put_line(v_file,v_linetit);

-- Definir una linea en blanco para separar los datos del titulo de los campos
v_linetit := ' ';
utl_file.put_line(v_file,v_linetit);

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN cu_liva_venta(v_dia_ini, v_dia_fin) LOOP

    --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
  v_line := to_char(rec.FECHA)||chr(9)||to_char(rec.HORA)||chr(9)||to_char(rec.COD_USUARIO)||chr(9)||to_char(rec.NRO_SECUENCIA)||chr(9)||
            to_char(rec.NRO_FACTURA)||chr(9)||to_char(rec.NRO_TIMBRADO)||chr(9)||to_char(rec.DESCRIPCION)||chr(9)||
            to_char(rec.NRO_CUENTA)||chr(9)||to_char(rec.COD_MONEDA)||chr(9)||
            to_char(rec.MTO_EXENTO,'999999999999999999D00')||chr(9)||to_char(rec.MTO_EXENTO_GS,'999999999999999999D00')||chr(9)||
            to_char(rec.MTO_GRAVADO_5,'999999999999D00')||chr(9)||to_char(rec.MTO_GRA_5_GS,'999999999999999999D00')||chr(9)||
            to_char(rec.MTO_GRAVADO_10,'999999999999999999D00')||chr(9)||to_char(rec.MTO_GRA_10_GS,'999999999999999999D00')||chr(9)||
            to_char(rec.IMPUESTO_5,'999999999999999999D00')||chr(9)||to_char(rec.IMPUESTO_5_GS,'999999999999999999D00')||chr(9)||
            to_char(rec.IMPUESTO_10,'999999999999999999D00')||chr(9)||to_char(rec.IMPUESTO_10_GS,'999999999999999999D00')||chr(9)||
            to_char(rec.COTIZACION,'999999999999999999D00')||chr(9)||to_char(rec.NRO_ASIENTO)||chr(9)||to_char(rec.NRO_LINEA);

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

  EXIT WHEN cu_liva_venta%NOTFOUND;
END LOOP;
--Escribes la linea en el fichero
UTL_FILE.PUT_LINE(v_file, v_buffer);

--Cerrar el handler al fichero
UTL_FILE.FCLOSE(v_file);
COMMIT;

  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_respuesta := pa_file_ftp.fu_put_ascii(pa_rpc_aut.g_ip, pa_rpc_aut.g_port, pa_rpc_aut.g_user,
                                          pa_rpc_aut.g_pass, pa_rpc_aut.g_repository,
                                          v_name||'.txt', g_contabilidad||v_name||'_'||v_fecha||'.txt');

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','LIBRO_IVA_VENTA');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte Libro IVA Venta Mensual a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_contabilidad||'

    Nombre del Archivo: '||v_name||'_'||v_fecha||'.txt';

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error    := null;

    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, v_name||'_'||v_fecha||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;

    --Enviamos el mail a soporte
     -- Obtenemos direccion de correo de soporte
     v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error Libro IVA Venta Mensual a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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
END pr_liva_venta;
-------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------
-- Archivos para Cidesa
PROCEDURE pr_arch_cidesa
IS
-- cursor principal de archivos a generar
CURSOR cu_arc_cidesa IS
      select  distinct t.cod_bco_central, t.cod_moneda, t.cod_modalidad,
      decode(t.cod_modalidad,'442','C',decode(t.cod_moneda,'GS','G','USD','D','EUR','E','PYG','G')) prefijo,
      decode(t.cod_modalidad,'442','C',decode(t.cod_moneda,'GS','G','USD','D','EUR','E','PYG','G'))  || '1007'|| t.cod_bco_central
      || decode(t.cod_bco_central,1006,decode(t.cod_modalidad,'47','PRONET',''),'')
      ||'_'||t.frecuencia nom_arch
      from cb_inf_cid_tmp t
      order by t.cod_bco_central,t.cod_moneda, t.cod_modalidad;

  -- Variables de generacion del archivo
  v_cod_moneda               cb_rubros.cod_moneda%TYPE;
  v_cod_bco_central          ge_bancos.cod_bco_central%TYPE;
  v_cod_modalidad            ge_modalidades.cod_modalidad%TYPE;
-- cursor del contenido del archivo a generar
CURSOR cu_arc_contenido IS
    select b.texto from (
    select i.cidesa||','||lpad(nvl(x.cant,0),5,0) TEXTO,i.fecha,i.tipo
    from cb_inf_cid_tmp i
    left join(
          select t.cod_bco_central ,t.cod_moneda, t.cod_modalidad, count(1)cant
                 from cb_inf_cid_tmp t
                 where t.tipo<>'I'
                 group by t.cod_bco_central ,t.cod_moneda, t.cod_modalidad)x on x.cod_bco_central = i.cod_bco_central
                 and x.cod_moneda = i.cod_moneda
                 and x.cod_modalidad=i.cod_modalidad
        where i.tipo='I'
        and i.cod_bco_central=v_cod_bco_central
        and i.cod_moneda=v_cod_moneda
        and i.cod_modalidad=v_cod_modalidad
    union all
        select t.cidesa TEXTO,t.fecha,t.tipo
        from cb_inf_cid_tmp t
        where t.cod_bco_central=v_cod_bco_central
        and t.cod_moneda=v_cod_moneda
        and t.cod_modalidad=v_cod_modalidad
        and t.tipo<>'I')b
        order by b.fecha asc,b.tipo desc;

  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := ''; -- nombre del archivo, se crea dinamicamente en cursor
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_fecha            VARCHAR2(8);
  v_hora             VARCHAR2(8);

  -- Variables para mail
  v_conn             utl_smtp.connection;
  v_para             VARCHAR2(500);
  v_asunto           VARCHAR2(2000);
  v_mje_mail         VARCHAR2(4000);
  --v_mje_mail_det     VARCHAR2(2000) := '';
  v_mje_mail_det     VARCHAR2(4000) := ''; -- PN 15/09/2014 SC 7476: Se agranda el tamaño del campo por error de desbordamiento
  v_hini_mail        ge_ra_log_mail.hor_inicio%type;
  v_hfin_mail        ge_ra_log_mail.hor_fin%type;
  v_det_error        ge_ra_log_mail.det_error%type;

  -- Variables para FTP
  v_respuesta        VARCHAR2(4000);
  v_hini_ftp         ge_ra_log_ftp.hor_inicio%type;
  v_hfin_ftp         ge_ra_log_ftp.hor_fin%type;



BEGIN
  -- Obtenemos la fecha del sistema de contabilidad
  v_fecha := to_char(pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1),'YYYYMMDD');

  -- Obtenemos la hora de la base de datos
  v_hora := to_char(sysdate,'hh24miss');

--Se recorre el cursor principal, cada registro es un archivo diferente
FOR ARC IN cu_arc_cidesa LOOP

    v_name := arc.nom_arch;
    -- Abrir archivo
    v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'.txt','W',32767);
    --v_file := UTL_FILE.FOPEN('/oradata/utl',v_name||'.txt','W',32767);

    -- carga las variables de filtro del archivo actual
    v_cod_bco_central := arc.cod_bco_central;
    v_cod_moneda := arc.cod_moneda;
    v_cod_modalidad := arc.cod_modalidad;
    v_buffer := '';
    --Consulta y recorre el contenido del archivo actual
    FOR REC IN cu_arc_contenido LOOP

        --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
      v_line := to_char(rec.TEXTO);

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

      EXIT WHEN cu_arc_contenido%NOTFOUND;
    END LOOP;
    --Escribes la linea en el fichero
    UTL_FILE.PUT_LINE(v_file, v_buffer);

    --Cerrar el handler al fichero
    UTL_FILE.FCLOSE(v_file);
    COMMIT;

      v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

      -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
      v_respuesta := pa_file_ftp.fu_put_binary(pa_rpc_aut.g_ip, pa_rpc_aut.g_port, pa_rpc_aut.g_user,
                                              pa_rpc_aut.g_pass, pa_rpc_aut.g_repository,
                                              v_name||'.txt', g_infocidesa ||v_name||'_'||v_fecha||'_'||v_hora||'.txt');

      v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

      IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP

          v_mje_mail_det := v_mje_mail_det || v_name||'_'||v_fecha||'_'||v_hora||'.txt
';

      ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP

        v_det_error    := null;

        -- Insertamos el error del envio al directorio compartido
        INSERT INTO ge_ra_log_ftp
         (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
        VALUES
         (SYSDATE, v_name||'_'||v_fecha||'_'||v_hora||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
        COMMIT;

        --Enviamos el mail a soporte
         -- Obtenemos direccion de correo de soporte
         v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

        -- Damos valor a los demas datos
          v_asunto := 'Error informes para Cidesa a la fecha '||v_fecha||'.';
          v_mje_mail := 'Error al enviar archivo por FTP.

        Error: '||v_respuesta||'.

        Para mas información verificar la tabla GE_RA_LOG_FTP';

          v_mje_mail_det := v_mje_mail_det || v_name||'_'||v_fecha||'_'||v_hora||'.txt ERROR al generar este archivo
';
          v_hini_mail := to_char(sysdate,'hh24:mi:ss');

          BEGIN
            v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
            it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
            it_mail.end_mail(v_conn);
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
               (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
              COMMIT;
          END IF;

      END IF;
    COMMIT;
    EXIT WHEN cu_arc_cidesa%NOTFOUND;
END LOOP;

-- Enviamos el mail al usuario
-- Obtenemos los direcciones de correo para quien o quienes va el correo
v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','ARCHIVOS_CIDESA');
-- Damos valor a los demas datos
v_asunto := 'Informes para Cidesa a la fecha '||v_fecha||'.';
v_mje_mail := 'Los archivos con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_infocidesa||'

Archivos: '||v_mje_mail_det;

v_det_error    := null;
v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

BEGIN
  v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
  it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
  it_mail.end_mail(v_conn);
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
     (SYSDATE, v_name||'_'||v_fecha||'_'||v_hora||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
    COMMIT;
END IF;
-- fin envio de email al usuario

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
END pr_arch_cidesa;
-------------------------------------------------------------------------------------------------------------------------------------
-- Archivos para Cidesa
PROCEDURE pr_arch_940_cidesa
IS
-- cursor principal de archivos a generar
CURSOR cu_arc_cidesa IS
select  distinct t.cod_bco_central, t.cod_moneda, t.cod_modalidad,
      decode(t.cod_modalidad,'442','C',decode(t.cod_moneda,'GS','G','USD','D','EUR','E','PYG','G')) prefijo,
      decode(t.cod_modalidad,'442','C',decode(t.cod_moneda,'GS','G','USD','D','EUR','E','PYG','G'))  || '1005100'|| t.cod_bco_central
      || decode(t.cod_bco_central,1006,decode(t.cod_modalidad,'47','PRONET',''),'')
      ||'_'||t.frecuencia nom_arch
      from cb_inf_cid_940_tmp t
      order by t.cod_bco_central,t.cod_moneda, t.cod_modalidad;
  -- Variables de generacion del archivo
  v_cod_moneda               cb_rubros.cod_moneda%TYPE;
  v_cod_bco_central          ge_bancos.cod_bco_central%TYPE;
  v_cod_modalidad            ge_modalidades.cod_modalidad%TYPE;
-- cursor del contenido del archivo a generar
CURSOR cu_arc_contenido IS
    select b.texto from (
    select i.cidesa||','||lpad(nvl(x.cant,0),5,0) TEXTO,i.fecha,i.tipo
    from cb_inf_cid_940_tmp i
    left join(
          select t.cod_bco_central ,t.cod_moneda, t.cod_modalidad, count(1)cant
                 from cb_inf_cid_940_tmp t
                 where t.tipo<>'I'
                 group by t.cod_bco_central ,t.cod_moneda, t.cod_modalidad)x on x.cod_bco_central = i.cod_bco_central
                 and x.cod_moneda = i.cod_moneda
                 and x.cod_modalidad=i.cod_modalidad
        where i.tipo='I'
        and i.cod_bco_central=v_cod_bco_central
        and i.cod_moneda=v_cod_moneda
        and i.cod_modalidad=v_cod_modalidad
    union all
        select t.cidesa TEXTO,t.fecha,t.tipo
        from cb_inf_cid_940_tmp t
        where t.cod_bco_central=v_cod_bco_central
        and t.cod_moneda=v_cod_moneda
        and t.cod_modalidad=v_cod_modalidad
        and t.tipo<>'I')b
        order by b.fecha asc,b.tipo desc;

  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := ''; -- nombre del archivo, se crea dinamicamente en cursor
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_fecha            VARCHAR2(8);
  v_hora             VARCHAR2(8);

  -- Variables para mail
  v_conn             utl_smtp.connection;
  v_para             VARCHAR2(500);
  v_asunto           VARCHAR2(2000);
  v_mje_mail         VARCHAR2(4000);
  --v_mje_mail_det     VARCHAR2(2000) := '';
  V_MJE_MAIL_DET Varchar2(4000) := ''; -- PN 15/09/2014 SC 7476: Se agranda el tamaño del campo por error de desbordamiento
  v_hini_mail        ge_ra_log_mail.hor_inicio%type;
  v_hfin_mail        ge_ra_log_mail.hor_fin%type;
  v_det_error        ge_ra_log_mail.det_error%type;
  -- Variables para FTP
  v_respuesta        VARCHAR2(4000);
  v_hini_ftp         ge_ra_log_ftp.hor_inicio%type;
  v_hfin_ftp         ge_ra_log_ftp.hor_fin%type;
BEGIN
  -- Obtenemos la fecha del sistema de contabilidad
  v_fecha := to_char(pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1),'YYYYMMDD');

  -- Obtenemos la hora de la base de datos
  v_hora := to_char(sysdate,'hh24miss');

--Se recorre el cursor principal, cada registro es un archivo diferente
FOR ARC IN cu_arc_cidesa LOOP

    v_name := arc.nom_arch;
    v_name:=v_name||'_'||v_fecha||'_'||v_hora||'.txt';
    -- Abrir archivo
    v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'.txt','W',32767);
    --v_file := UTL_FILE.FOPEN('/oradata/utl',v_name||'.txt','W',32767);

    -- carga las variables de filtro del archivo actual
    v_cod_bco_central := arc.cod_bco_central;
    v_cod_moneda := arc.cod_moneda;
    v_cod_modalidad := arc.cod_modalidad;
    v_buffer := '';

     --Consulta y recorre el contenido del archivo actual
    FOR REC IN cu_arc_contenido LOOP

        --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
      v_line := to_char(rec.TEXTO);

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

      EXIT WHEN cu_arc_contenido%NOTFOUND;
    END LOOP;
    --Escribes la linea en el fichero
    UTL_FILE.PUT_LINE(v_file, v_buffer);

    --Cerrar el handler al fichero
    UTL_FILE.FCLOSE(v_file);
    COMMIT;

      v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

      -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP

      v_respuesta := pa_file_ftp.fu_put_binary(pa_rpc_aut.g_ip, pa_rpc_aut.g_port, pa_rpc_aut.g_user,
                                              pa_rpc_aut.g_pass, pa_rpc_aut.g_repository,
                                              v_name||'.txt', g_infocidesa ||v_name||'_'||v_fecha||'_'||v_hora||'.txt');

      v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');
      v_respuesta := 'OK';
      IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP

          v_mje_mail_det := v_mje_mail_det || v_name||'_'||v_fecha||'_'||v_hora||'.txt
';

      ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP

        v_det_error    := null;

        -- Insertamos el error del envio al directorio compartido
        INSERT INTO ge_ra_log_ftp
         (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
        VALUES
         (SYSDATE, v_name||'_'||v_fecha||'_'||v_hora||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
        COMMIT;

        --Enviamos el mail a soporte
         -- Obtenemos direccion de correo de soporte
         v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

        -- Damos valor a los demas datos
          v_asunto := 'Error informes para Cidesa 940 a la fecha '||v_fecha||'.';
          v_mje_mail := 'Error al enviar archivo por FTP.

        Error: '||v_respuesta||'.

        Para mas información verificar la tabla GE_RA_LOG_FTP';

          v_mje_mail_det := v_mje_mail_det || v_name||'_'||v_fecha||'_'||v_hora||'.txt ERROR al generar este archivo
';
          v_hini_mail := to_char(sysdate,'hh24:mi:ss');

          BEGIN
            v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
            it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
            it_mail.end_mail(v_conn);
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
               (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
              COMMIT;
          END IF;

      END IF;
    COMMIT;
    EXIT WHEN cu_arc_cidesa%NOTFOUND;
END LOOP;


-- Enviamos el mail al usuario
-- Obtenemos los direcciones de correo para quien o quienes va el correo
v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','ARCHIVOS_CIDESA');
-- Damos valor a los demas datos
v_asunto := 'Informes para Cidesa 940 a la fecha '||v_fecha||'.';
v_mje_mail := 'Los archivos con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_infocidesa||'

Archivos: '||v_mje_mail_det;

v_det_error    := null;
v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

BEGIN
  v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
  it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
  it_mail.end_mail(v_conn);

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
     (SYSDATE, v_name||'_'||v_fecha||'_'||v_hora||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
    COMMIT;
END IF;
-- fin envio de email al usuario

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
END pr_arch_940_cidesa;
-------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------
-- Cuentas asociadas a Entes de Pago Salario
PROCEDURE pr_cta_aso_pag_sal
IS
CURSOR cu_cta_aso IS
    select pp.cod_ente,
       pp.empresa,
       pp.cod_modulo,
       pp.cod_modalidad,
       pp.tipo_cta,
       pp.sub_mod,
       pp.sub_mod_cta,
       pp.gestor,
       pp.nro_cuenta,
       pp.cod_moneda,
       pp.fec_apertura,
       pp.estado_cta,
       pp.cod_persona,
       pp.cliente,
       pp.nro_documento,
       pp.debito_tarjeta,
       pp.debito_prestamo,
       pp.fec_ult_acrd,
       pp.sal_disponible,
       pp.mon_sobregiro
  from vg_cta_nomina pp;


  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'cta_aso_pag_sal'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_fec_sist         DATE;
  v_fecha            VARCHAR2(8);

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
  select pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1)
  into v_fec_sist
  from dual;

  v_fecha := to_char(v_fec_sist,'DDMMYYYY');

-- Abrir archivo
v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'.txt','W',32767);

-- Colocar el titulo a los campos
v_linetit := 'COD_ENTE'||CHR(9)||'EMPRESA'||CHR(9)||'COD_MODULO'||CHR(9)||'COD_MODALIDAD'||CHR(9)||'TIPO_CTA'||CHR(9)||
             'SUB_MOD'||CHR(9)||'SUB_MOD_CTA'||CHR(9)||'GESTOR'||CHR(9)||'NRO_CUENTA'||CHR(9)||'COD_MONEDA'||CHR(9)||
             'FEC_APERTURA'||CHR(9)||'ESTADO_CTA'||CHR(9)||'COD_PERSONA'||CHR(9)||'CLIENTE'||CHR(9)||
             'NRO_DOCUMENTO'||CHR(9)||'DEBITO_TARJETA'||CHR(9)||'DEBITO_PRESTAMO'||CHR(9)||'FEC_ULT_ACRD'||CHR(9)||
             'SAL_DISPONIBLE'||CHR(9)||'MON_SOBREGIRO';

utl_file.put_line(v_file,v_linetit);

-- Definir una linea en blanco para separar los datos del titulo de los campos
v_linetit := ' ';
utl_file.put_line(v_file,v_linetit);

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN cu_cta_aso LOOP

    --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
  v_line := to_char(rec.cod_ente)||chr(9)||to_char(rec.empresa)||chr(9)||to_char(rec.cod_modulo)||chr(9)||to_char(rec.cod_modalidad)||chr(9)||
            to_char(rec.tipo_cta)||chr(9)||to_char(rec.sub_mod)||chr(9)||to_char(rec.sub_mod_cta)||chr(9)||to_char(rec.gestor)||chr(9)||
            to_char(rec.nro_cuenta)||chr(9)||to_char(rec.cod_moneda)||chr(9)||to_char(rec.fec_apertura)||chr(9)||to_char(rec.estado_cta)||chr(9)||
            to_char(rec.cod_persona)||chr(9)||to_char(rec.cliente)||chr(9)||to_char(rec.nro_documento)||chr(9)||
            to_char(rec.debito_tarjeta)||chr(9)||to_char(rec.debito_prestamo)||chr(9)||to_char(rec.fec_ult_acrd)||chr(9)||
            to_char(rec.sal_disponible,'999999999999D00')||chr(9)||to_char(rec.mon_sobregiro,'999999999999D00');

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

   EXIT WHEN cu_cta_aso%NOTFOUND;
END LOOP;
--Escribes la linea en el fichero
UTL_FILE.PUT_LINE(v_file, v_buffer);

--Cerrar el handler al fichero
UTL_FILE.FCLOSE(v_file);
COMMIT;

  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_respuesta := pa_file_ftp.fu_put_ascii(pa_rpc_aut.g_ip, pa_rpc_aut.g_port, pa_rpc_aut.g_user,
                                          pa_rpc_aut.g_pass, pa_rpc_aut.g_repository,
                                          v_name||'.txt', g_operaciones||v_name||'_'||v_fecha||'.txt');

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','ARCHIVOS_OPERACIONES');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte Cuentas asociadas a Entes de Pago Salario '||v_fec_sist||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_operaciones||'

    Nombre del Archivo: '||v_name||'_'||v_fecha||'.txt';

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error    := null;

    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, v_name||'_'||v_fecha||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;

    --Enviamos el mail a soporte
     -- Obtenemos direccion de correo de soporte
     v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error Reporte Cuentas asociadas a Entes de Pago Salario '||v_fec_sist||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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
    RAISE_APPLICATION_ERROR(-20062,'Manejador invalido');
  WHEN UTL_FILE.WRITE_ERROR THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20063,'Error de escritura '||sqlerrm);
  WHEN UTL_FILE.INVALID_MODE THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20064,'Modo invalido');
  WHEN UTL_FILE.INTERNAL_ERROR THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20065,'Internal Error');
END pr_cta_aso_pag_sal;
--------------------------------------------------------------------------
-- Cuentas Nomina asociadas a Entes de Pago Salario
PROCEDURE pr_nom_pag_sal
IS
CURSOR cu_nom_aso IS
    select aa.cod_ente,
         aa.empresa,
         aa.cod_modulo,
         aa.cod_modalidad,
         aa.tipo_cta,
         aa.sub_mod,
         aa.sub_mod_cta,
         aa.nro_cuenta,
         aa.cod_moneda,
         aa.cod_persona,
         aa.cliente,
         aa.fec_apertura,
         aa.cheq_activas,
         aa.fec_ult_extraccion,
         aa.fec_ult_deposito
    from ge_cta_ope_tmp aa;


  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'nom_pag_sal'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_fec_sist         DATE;
  v_fecha            VARCHAR2(8);

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
  select pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1)
  into v_fec_sist
  from dual;

  v_fecha := to_char(v_fec_sist,'DDMMYYYY');

-- Abrir archivo
v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'.txt','W',32767);

-- Colocar el titulo a los campos
v_linetit := 'COD_ENTE'||CHR(9)||'EMPRESA'||CHR(9)||'COD_MODULO'||CHR(9)||'COD_MODALIDAD'||CHR(9)||'TIPO_CTA'||CHR(9)||
             'SUB_MOD'||CHR(9)||'SUB_MOD_CTA'||'NRO_CUENTA'||CHR(9)||'COD_MONEDA'||CHR(9)||
             'COD_PERSONA'||CHR(9)||'CLIENTE'||CHR(9)||
             'FEC_APERTURA'||CHR(9)||'CHEQ_ACTIVAS'||CHR(9)||'FEC_ULT_EXTRACCION'||CHR(9)||'FEC_ULT_DEPOSITO';

utl_file.put_line(v_file,v_linetit);

-- Definir una linea en blanco para separar los datos del titulo de los campos
v_linetit := ' ';
utl_file.put_line(v_file,v_linetit);

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN cu_nom_aso LOOP

    --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
  v_line := to_char(rec.cod_ente)||chr(9)||to_char(rec.empresa)||chr(9)||to_char(rec.cod_modulo)||chr(9)||to_char(rec.cod_modalidad)||chr(9)||
            to_char(rec.tipo_cta)||chr(9)||to_char(rec.sub_mod)||chr(9)||to_char(rec.sub_mod_cta)||chr(9)||to_char(rec.nro_cuenta)||chr(9)||
            to_char(rec.cod_moneda)||chr(9)||to_char(rec.cod_persona)||
            to_char(rec.cliente)||chr(9)||to_char(rec.fec_apertura)||chr(9)||
            to_char(rec.cheq_activas)||chr(9)||to_char(rec.fec_ult_extraccion)||chr(9)||to_char(rec.fec_ult_extraccion)||chr(9)||
            to_char(rec.fec_ult_deposito);

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

   EXIT WHEN cu_nom_aso%NOTFOUND;
END LOOP;
--Escribes la linea en el fichero
UTL_FILE.PUT_LINE(v_file, v_buffer);

--Cerrar el handler al fichero
UTL_FILE.FCLOSE(v_file);
COMMIT;

  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_respuesta := pa_file_ftp.fu_put_ascii(pa_rpc_aut.g_ip, pa_rpc_aut.g_port, pa_rpc_aut.g_user,
                                          pa_rpc_aut.g_pass, pa_rpc_aut.g_repository,
                                          v_name||'.txt', g_operaciones||v_name||'_'||v_fecha||'.txt');

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','ARCHIVOS_OPERACIONES');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte Cuentas Nomina asociadas a Entes de Pago Salario'||v_fec_sist||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_operaciones||'

    Nombre del Archivo: '||v_name||'_'||v_fecha||'.txt';

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error    := null;

    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, v_name||'_'||v_fecha||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;

    --Enviamos el mail a soporte
     -- Obtenemos direccion de correo de soporte
     v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error Reporte Cuentas Nomina asociadas a Entes de Pago Salario'||v_fec_sist||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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
    RAISE_APPLICATION_ERROR(-20062,'Manejador invalido');
  WHEN UTL_FILE.WRITE_ERROR THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20063,'Error de escritura '||sqlerrm);
  WHEN UTL_FILE.INVALID_MODE THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20064,'Modo invalido');
  WHEN UTL_FILE.INTERNAL_ERROR THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20065,'Internal Error');
END pr_nom_pag_sal;
---------------------------------------
-- Generación del plan de cuentas
PROCEDURE pr_gen_plan_cuentas
IS
CURSOR cu_pla_cta IS
    select r.cod_rubro,r.descripcion,r.cod_moneda,r.cod_rub_padre,
      r.abreviatura,r.tipo,r.nivel,r.naturaleza,r.deducible,r.imputable,r.ajustable,
      r.ult_nro_mayor,r.usu_insercion,r.fec_insercion,r.usu_modificacion,r.fec_modificacion,
      r.fec_inicio,r.fec_fin,r.cod_rub_externo,r.cod_consolidacion,r.cod_gestion,r.nro_gru_rubro,
      r.transitorio,r.plz_maximo,r.automatico,r.afe_naturaleza
    from cb_rubros r;


  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'Plan_de_Cuentas'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_fec_sist         DATE;
  v_fecha            VARCHAR2(8);

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
  select pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1)
  into v_fec_sist
  from dual;

  v_fecha := to_char(v_fec_sist,'DDMMYYYY');

-- Abrir archivo
v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'.txt','W',32767);

-- Colocar el titulo a los campos
v_linetit := 'COD_RUBRO'||CHR(9)||'DESCRIPCION'||CHR(9)||'COD_MONEDA'||CHR(9)||'COD_RUB_PADRE'||CHR(9)||'ABREVIATURA'||CHR(9)||
             'TIPO'||CHR(9)||'NIVEL'||'NATURALEZA'||CHR(9)||'DEDUCIBLE'||CHR(9)||
             'IMPUTABLE'||CHR(9)||'AJUSTABLE'||CHR(9)||
             'ULT_NRO_MAYOR'||CHR(9)||'USU_INSERCION'||CHR(9)||'FEC_INSERCION'||CHR(9)||'USU_MODIFICACION'||CHR(9)||
             'FEC_MODIFICACION'||CHR(9)||'FEC_INICIO'||CHR(9)||'FEC_FIN'||CHR(9)||
             'COD_RUB_EXTERNO'||CHR(9)||'COD_CONSOLIDACION'||CHR(9)||'COD_GESTION'||CHR(9)||
             'NRO_GRU_RUBRO'||CHR(9)||'TRANSITORIO'||CHR(9)||'PLZ_MAXIMO'||CHR(9)||
             'AUTOMATICO'||CHR(9)||'AFE_NATURALEZA';


utl_file.put_line(v_file,v_linetit);

-- Definir una linea en blanco para separar los datos del titulo de los campos
v_linetit := ' ';
utl_file.put_line(v_file,v_linetit);

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN cu_pla_cta LOOP

    --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
  v_line := to_char(rec.cod_rubro)||chr(9)||to_char(rec.descripcion)||chr(9)||to_char(rec.cod_moneda)||chr(9)||
            to_char(rec.cod_rub_padre)||chr(9)||to_char(rec.abreviatura)||chr(9)||
            to_char(rec.tipo)||chr(9)||to_char(rec.nivel)||chr(9)||to_char(rec.naturaleza)||chr(9)||
            to_char(rec.deducible)||chr(9)||to_char(rec.imputable)||
            to_char(rec.ajustable)||chr(9)||to_char(rec.ult_nro_mayor)||chr(9)||
            to_char(rec.usu_insercion)||chr(9)||to_char(rec.fec_insercion)||chr(9)||to_char(rec.usu_modificacion)||chr(9)||
            to_char(rec.fec_modificacion)||chr(9)||to_char(rec.fec_inicio)||chr(9)||to_char(rec.fec_fin)||chr(9)||
            to_char(rec.cod_rub_externo)||chr(9)||to_char(rec.cod_consolidacion)||chr(9)||to_char(rec.cod_gestion)||chr(9)||
            to_char(rec.nro_gru_rubro)||chr(9)||to_char(rec.transitorio)||chr(9)||
            to_char(rec.plz_maximo)||chr(9)||to_char(rec.automatico)||chr(9)||to_char(rec.afe_naturaleza);

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

   EXIT WHEN cu_pla_cta%NOTFOUND;
END LOOP;
--Escribes la linea en el fichero
UTL_FILE.PUT_LINE(v_file, v_buffer);

--Cerrar el handler al fichero
UTL_FILE.FCLOSE(v_file);
COMMIT;

  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_respuesta := pa_file_ftp.fu_put_ascii(pa_rpc_aut.g_ip, pa_rpc_aut.g_port, pa_rpc_aut.g_user,
                                          pa_rpc_aut.g_pass, pa_rpc_aut.g_repository,
                                          v_name||'.txt', g_contabilidad||v_name||'_'||v_fecha||'.txt');

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','PLAN_CUENTAS');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte de Plan de Cuentas'||v_fec_sist||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_contabilidad||'

    Nombre del Archivo: '||v_name||'_'||v_fecha||'.txt';

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error    := null;

    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, v_name||'_'||v_fecha||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;

    --Enviamos el mail a soporte
     -- Obtenemos direccion de correo de soporte
     v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error Reporte de Plan de Cuentas'||v_fec_sist||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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
    RAISE_APPLICATION_ERROR(-20062,'Manejador invalido');
  WHEN UTL_FILE.WRITE_ERROR THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20063,'Error de escritura '||sqlerrm);
  WHEN UTL_FILE.INVALID_MODE THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20064,'Modo invalido');
  WHEN UTL_FILE.INTERNAL_ERROR THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20065,'Internal Error');
END pr_gen_plan_cuentas;
-------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------
-- Saldos Promedio Abierto - Diario
PROCEDURE pr_prom_abi_diario
IS
CURSOR cu_sal_proabi(p_anho VARCHAR2, p_mes VARCHAR2) IS
     select '0'||substr(k.cod_rub_padre,1,5) bcp1, null col1,
       substr(k.cod_rub_externo,1,6)||'.'||substr(k.cod_rub_externo,7,5)||'.'||substr(k.cod_rub_externo,12,1) rub_as,
       null col2, k.Descripcion Descripcion,
       sum(round((nvl(s.tot_acumulado,0)/s.can_dia_acumulado),0) * -1) saldo_me,
       null col3,

       case when sum(nvl(s.tot_acu_mon_local,0)/s.can_dia_acumulado) > 0 then
        abs(sum(round(((nvl(s.tot_acu_mon_local,0)/s.can_dia_acumulado)),0)))
         else 0 end acum_deb_ml,

       case when sum(nvl(s.tot_acu_mon_local,0)/s.can_dia_acumulado) < 0 then
           abs(sum(round(((nvl(s.tot_acu_mon_local,0)/s.can_dia_acumulado)),0))) else 0 end acum_cre_ml,

       k.cod_rubro, k.cod_rub_externo, s.mes, s.ano, 'Promedio Abierto' Tip_Balance,
       sum(round((nvl(s.tot_acumulado,0)/s.can_dia_acumulado),0)) saldo_me_IT,
       sum(round((nvl(s.tot_acu_mon_local,0)/s.can_dia_acumulado),0)) saldo_me_local
    from cb_sal_promedios s, cb_rubros k
    where s.cod_rubro   = k.cod_rubro
    and k.imputable     = 'S'
    and s.ano           = p_anho
    and s.mes           = p_mes
    and abs(nvl(s.tot_acu_mon_local,0)) <> 0
    group by '0'||substr(k.cod_rub_padre,1,5),
       substr(k.cod_rub_externo,1,6)||'.'||substr(k.cod_rub_externo,7,5)||'.'||substr(k.cod_rub_externo,12,1),
       null,k.Descripcion,k.cod_rubro, k.cod_rub_externo, s.mes, s.ano, 'Promedio Abierto'
    order by 3;

  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'prom_abierto_diario'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_anho             VARCHAR2(4);
  v_mes              VARCHAR2(2);
  --v_hora             VARCHAR2(8);


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
  -- Obtenemos la fecha anterior
  -- anho
  v_anho  := to_char(pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1),'YYYY');
  -- mes
  v_mes   := to_char(pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1),'MM');

  /*select to_char(max(fecha),'dd') into v_can_dia--se obtiene la máxima fecha de la contabilidad cerrada para sacar saldo promedio
   from cb_asientos_his;*/

  -- Obtenemos la hora de la base de datos
  --v_hora := to_char(sysdate,'hh24miss');

-- Abrir archivo
v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'.txt','W',32767);

-- Colocar el titulo a los campos
v_linetit := 'BCP1'||CHR(9)||'COL1'||CHR(9)||'RUB_AS'||CHR(9)||'COL2'||CHR(9)||'DESCRIPCION'||CHR(9)||'SALDO_ME'||CHR(9)||
             'COL3'||CHR(9)||'ACUM_DEB_ML'||CHR(9)||'ACUM_CRE_ML'||CHR(9)||'COD_RUBRO'||CHR(9)||'COD_RUB_EXTERNO'||CHR(9)||
             'MES'||CHR(9)||'ANO'||CHR(9)||'TIP_BALANCE';

utl_file.put_line(v_file,v_linetit);

-- Definir una linea en blanco para separar los datos del titulo de los campos
v_linetit := ' ';
utl_file.put_line(v_file,v_linetit);

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN cu_sal_proabi(v_anho, v_mes) LOOP

    --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
  v_line := to_char(rec.BCP1)||chr(9)||to_char(rec.COL1)||chr(9)||to_char(rec.RUB_AS)||chr(9)||
             to_char(rec.COL2)||chr(9)||to_char(rec.DESCRIPCION)||chr(9)||to_char(rec.SALDO_ME,'999999999999999999999D00')||chr(9)||
            to_char(rec.COL3)||chr(9)||to_char(rec.ACUM_DEB_ML,'999999999999999999999D00')||chr(9)||
            to_char(rec.ACUM_CRE_ML,'999999999999999999999D00')||chr(9)||to_char(rec.COD_RUBRO)||chr(9)||
            to_char(rec.COD_RUB_EXTERNO)||chr(9)||to_char(rec.MES)||chr(9)||to_char(rec.ANO)||chr(9)||
            to_char(rec.TIP_BALANCE);


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

  EXIT WHEN cu_sal_proabi%NOTFOUND;
END LOOP;
--Escribes la linea en el fichero
UTL_FILE.PUT_LINE(v_file, v_buffer);

--Cerrar el handler al fichero
UTL_FILE.FCLOSE(v_file);
COMMIT;

  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_respuesta := pa_file_ftp.fu_put_ascii(pa_rpc_aut.g_ip, pa_rpc_aut.g_port, pa_rpc_aut.g_user,
                                          pa_rpc_aut.g_pass, pa_rpc_aut.g_repository,
                                          v_name||'.txt', g_balances||v_name||'_'||v_anho||v_mes||'.txt');

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','PROMEDIO_ABIERTO');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte Balance Saldos Promedio Abierto Diario a la fecha '||v_anho||v_mes||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_balances||'

    Nombre del Archivo: '||v_name||'_'||v_anho||v_mes||'.txt';

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_anho||v_mes||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error    := null;

    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, v_name||'_'||v_anho||v_mes||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;

    --Enviamos el mail a soporte
     -- Obtenemos direccion de correo de soporte
     v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error Reporte Balance Saldos Promedio Abierto Diario a la fecha '||v_anho||v_mes||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_anho||v_mes||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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
END pr_prom_abi_diario;

-------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------
-- Saldos Promedio Abierto por Sucursal - Diario
PROCEDURE pr_pro_abi_suc_diario
IS
CURSOR cu_proabi_suc(p_anho VARCHAR2, p_mes VARCHAR2, p_can_dia NUMBER) IS
    select s.cod_oficina, '0'||substr(k.cod_rub_padre,1,5) bcp1, null col1,
       substr(k.cod_rub_externo,1,6)||'.'||substr(k.cod_rub_externo,7,5)||'.'||substr(k.cod_rub_externo,12,1) rub_as,
       null col2, k.Descripcion Descripcion,
       (round(((nvl(s.tot_acumulado,0))/p_can_dia),0) * -1) saldo_me,
       null col3,

       case when ((nvl(s.tot_acu_mon_local,0))/p_can_dia) > 0 then
          (round((abs((nvl(s.tot_acu_mon_local,0))/p_can_dia)),0))
           else 0 end acum_deb_ml,

       case when ((nvl(s.tot_acu_mon_local,0))/p_can_dia) < 0 then
          (round((abs((nvl(s.tot_acu_mon_local,0))/p_can_dia)),0)) else 0 end acum_cre_ml,

       k.cod_rubro, k.cod_rub_externo, s.mes, s.ano, 'Promedio Abierto x Sucursal' Tip_Balance
    from cb_sal_promedios s, cb_rubros k
    where s.cod_rubro   = k.cod_rubro
    and k.imputable     = 'S'
    and s.ano           = p_anho
    and s.mes           = p_mes
    and abs(nvl(s.tot_acu_mon_local,0)) <> 0
    order by 1,3;

  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'prom_abi_suc_diario'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_anho             VARCHAR2(4);
  v_mes              VARCHAR2(2);
  --v_hora             VARCHAR2(8);
  v_can_dia          NUMBER;

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
  -- Obtenemos la fecha anterior
  -- anho
  v_anho  := to_char(pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1),'YYYY');
  -- mes
  v_mes   := to_char(pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1),'MM');

  select to_char(max(fecha),'mm') into v_can_dia--se obtiene la máxima fecha de la contabilidad cerrada para sacar saldo promedio
   from cb_asientos_his;

  -- Obtenemos la hora de la base de datos
  --v_hora := to_char(sysdate,'hh24miss');

-- Abrir archivo
v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'.txt','W',32767);

-- Colocar el titulo a los campos
v_linetit := 'COD_OFICINA'||CHR(9)||'BCP1'||CHR(9)||'COL1'||CHR(9)||'RUB_AS'||CHR(9)||'COL2'||CHR(9)||'DESCRIPCION'||CHR(9)||
             'SALDO_ME'||CHR(9)||'COL3'||CHR(9)||'ACUM_DEB_ML'||CHR(9)||'ACUM_CRE_ML'||CHR(9)||
             'COD_RUBRO'||CHR(9)||'COD_RUB_EXTERNO'||CHR(9)||'MES'||CHR(9)||'ANO'||CHR(9)||'TIP_BALANCE';

utl_file.put_line(v_file,v_linetit);

-- Definir una linea en blanco para separar los datos del titulo de los campos
v_linetit := ' ';
utl_file.put_line(v_file,v_linetit);

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN cu_proabi_suc(v_anho, v_mes, v_can_dia) LOOP

    --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
  v_line := to_char(rec.COD_OFICINA)||chr(9)||to_char(rec.BCP1)||chr(9)||to_char(rec.COL1)||chr(9)||to_char(rec.RUB_AS)||chr(9)||
             to_char(rec.COL2)||chr(9)||to_char(rec.DESCRIPCION)||chr(9)||to_char(rec.SALDO_ME,'999999999999999999999D00')||chr(9)||
            to_char(rec.COL3)||chr(9)||to_char(rec.ACUM_DEB_ML,'999999999999999999999D00')||chr(9)||
            to_char(rec.ACUM_CRE_ML,'999999999999999999999D00')||chr(9)||to_char(rec.COD_RUBRO)||chr(9)||
            to_char(rec.COD_RUB_EXTERNO)||chr(9)||to_char(rec.MES)||chr(9)||to_char(rec.ANO)||chr(9)||
            to_char(rec.TIP_BALANCE);


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

  EXIT WHEN cu_proabi_suc%NOTFOUND;
END LOOP;
--Escribes la linea en el fichero
UTL_FILE.PUT_LINE(v_file, v_buffer);

--Cerrar el handler al fichero
UTL_FILE.FCLOSE(v_file);
COMMIT;

  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_respuesta := pa_file_ftp.fu_put_ascii(pa_rpc_aut.g_ip, pa_rpc_aut.g_port, pa_rpc_aut.g_user,
                                          pa_rpc_aut.g_pass, pa_rpc_aut.g_repository,
                                          v_name||'.txt', g_balances||v_name||'_'||v_anho||v_mes||v_can_dia||'.txt');

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','PROMEDIO_ABIERTO_SUC');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte Balance Saldos Promedio Abierto por Sucursal Diario a la fecha '||v_anho||v_mes||v_can_dia||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_balances||'

    Nombre del Archivo: '||v_name||'_'||v_anho||v_mes||v_can_dia||'.txt';

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_anho||v_mes||v_can_dia||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error    := null;

    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, v_name||'_'||v_anho||v_mes||v_can_dia||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;

    --Enviamos el mail a soporte
     -- Obtenemos direccion de correo de soporte
     v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error Reporte Balance Saldos Promedio Abierto por Sucursal Diario a la fecha '||v_anho||v_mes||v_can_dia||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_anho||v_mes||v_can_dia||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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
END pr_pro_abi_suc_diario;

-------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------
-- Saldos Promedio Cerrado - Diario
PROCEDURE pr_prom_cer_diario
IS
CURSOR cu_prom_cer(p_anho VARCHAR2, p_mes VARCHAR2) IS
    select '0'||substr(r.cod_rub_bcp,1,5) bcp1,
       case when substr(r.cod_rub_bcp,6,6) = '000000' then null
       else substr(r.cod_rub_bcp,6,6) end bcp2,
       k.Descripcion Descripcion,

       sum(round((((nvl(s.tot_acu_mon_local,0)) -
        (nvl(s.tot_acu_equ_local,0)))/s.can_dia_acumulado),0)) * -1 Saldo_Guaranies,
       sum(round(((nvl(s.tot_acumulado,0))/s.can_dia_acumulado),0)) * -1 Saldo_Rubro,
       sum(round(((nvl(s.tot_acu_equ_local,0))/s.can_dia_acumulado),0)) * -1 Saldo_Equivalente,
       sum(round(((nvl(s.tot_acu_mon_local,0))/s.can_dia_acumulado),0)) * -1 Saldo_Total,
       k.cod_rubro rubro_it,  s.mes, s.ano, 'Promedio Cerrado Con Signo' Tip_Balance
    from cb_sal_promedios s, cb_rub_bcp r, cb_rubros k
    where r.cod_rub_bcp(+) = substr(s.cod_rubro,1,8)||substr(s.cod_rubro,3,1)||substr(s.cod_rubro,9,2)
    and s.cod_rubro        = k.cod_rubro
    and k.imputable        = 'N'
    and k.nivel            <= 5
    and s.ano              = p_anho
    and s.mes              = p_mes
    and abs(nvl(s.tot_acu_mon_local,0)) <> 0
    and not exists(select 1 from cb_rubros t where substr(t.cod_rubro,9,2) = '01' and nivel = 5 and k.cod_rubro=t.cod_rub_padre)
    group by '0'||substr(r.cod_rub_bcp,1,5),
       case when substr(r.cod_rub_bcp,6,6) = '000000' then null
       else substr(r.cod_rub_bcp,6,6) end,
       k.Descripcion,
       k.cod_rubro,  s.mes, s.ano, 'Promedio Cerrado Con Signo'
    order by 1, 2;

  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'prom_cerrado_diario'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_anho             VARCHAR2(4);
  v_mes              VARCHAR2(2);
  --v_hora             VARCHAR2(8);


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
  -- Obtenemos la fecha anterior
  -- anho
  v_anho  := to_char(pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1),'YYYY');
  -- mes
  v_mes   := to_char(pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1),'MM');

  /*select to_char(max(fecha),'mm') into v_can_dia--se obtiene la máxima fecha de la contabilidad cerrada para sacar saldo promedio
   from cb_asientos_his;*/

  -- Obtenemos la hora de la base de datos
  --v_hora := to_char(sysdate,'hh24miss');

-- Abrir archivo
v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'.txt','W',32767);

-- Colocar el titulo a los campos
v_linetit := 'BCP1'||CHR(9)||'BCP2'||CHR(9)||'DESCRIPCION'||CHR(9)||'SALDO_GUARANIES'||CHR(9)||
             'SALDO_RUBRO'||CHR(9)||'SALDO_EQUIVALENTE'||CHR(9)||'SALDO_TOTAL'||CHR(9)||'RUBRO_IT'||CHR(9)||
             'MES'||CHR(9)||'ANO'||CHR(9)||'TIP_BALANCE';

utl_file.put_line(v_file,v_linetit);

-- Definir una linea en blanco para separar los datos del titulo de los campos
v_linetit := ' ';
utl_file.put_line(v_file,v_linetit);

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN cu_prom_cer(v_anho, v_mes) LOOP

    --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
  v_line := to_char(rec.BCP1)||chr(9)||to_char(rec.BCP2)||chr(9)||to_char(rec.DESCRIPCION)||chr(9)||
             to_char(rec.SALDO_GUARANIES,'999999999999999999999D00')||chr(9)||to_char(rec.SALDO_RUBRO,'999999999999999999999D00')||chr(9)||
            to_char(rec.SALDO_EQUIVALENTE,'999999999999999999999D00')||chr(9)||to_char(rec.SALDO_TOTAL,'999999999999999999999D00')||chr(9)||
            to_char(rec.RUBRO_IT)||chr(9)||to_char(rec.MES)||chr(9)||to_char(rec.ANO)||chr(9)||
            to_char(rec.TIP_BALANCE);


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

  EXIT WHEN cu_prom_cer%NOTFOUND;
END LOOP;
--Escribes la linea en el fichero
UTL_FILE.PUT_LINE(v_file, v_buffer);

--Cerrar el handler al fichero
UTL_FILE.FCLOSE(v_file);
COMMIT;

  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_respuesta := pa_file_ftp.fu_put_ascii(pa_rpc_aut.g_ip, pa_rpc_aut.g_port, pa_rpc_aut.g_user,
                                          pa_rpc_aut.g_pass, pa_rpc_aut.g_repository,
                                          v_name||'.txt', g_balances||v_name||'_'||v_anho||v_mes||'.txt');

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','PROMEDIO_CERRADO');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte Balance Saldos Promedio Cerrado a la fecha Diario '||v_anho||v_mes||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_balances||'

    Nombre del Archivo: '||v_name||'_'||v_anho||v_mes||'.txt';

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_anho||v_mes||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error    := null;

    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, v_name||'_'||v_anho||v_mes||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;

    --Enviamos el mail a soporte
     -- Obtenemos direccion de correo de soporte
     v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error Reporte Balance Saldos Promedio Cerrado a la fecha Diario '||v_anho||v_mes||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_anho||v_mes||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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
END pr_prom_cer_diario;

-------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------
-- Saldos Promedio Cerrado por Sucursal - Diario
PROCEDURE pr_pro_cer_suc_diario
IS
CURSOR cu_procer_suc(p_anho VARCHAR2, p_mes VARCHAR2, p_can_dia NUMBER) IS
    select s.cod_oficina, '0'||substr(r.cod_rub_bcp,1,5) bcp1,
       case when substr(r.cod_rub_bcp,6,6) = '000000' then null
       else substr(r.cod_rub_bcp,6,6) end bcp2,
       k.Descripcion Descripcion,

       sum(round((((nvl(s.tot_acu_mon_local,0)) -
        (nvl(s.tot_acu_equ_local,0)))/s.can_dia_acumulado),0)) * -1 Saldo_Guaranies,
       sum(round(((nvl(s.tot_acumulado,0))/s.can_dia_acumulado),0)) * -1 Saldo_Rubro,
       sum(round(((nvl(s.tot_acu_equ_local,0))/s.can_dia_acumulado),0)) * -1 Saldo_Equivalente,
       sum(round(((nvl(s.tot_acu_mon_local,0))/s.can_dia_acumulado),0)) * -1 Saldo_Total,
       k.cod_rubro rubro_it,  s.mes, s.ano, 'Promedio Cerrado Con Signo x Sucursal' Tip_Balance

    from cb_sal_promedios s, cb_rub_bcp r, cb_rubros k
    where r.cod_rub_bcp(+) = substr(s.cod_rubro,1,8)||substr(s.cod_rubro,3,1)||substr(s.cod_rubro,9,2)
    and s.cod_rubro   = k.cod_rubro
    and k.imputable   = 'N'
    and k.nivel       <= 5
    and s.ano         = p_anho
    and s.mes         = p_mes
    and abs(nvl(s.tot_acu_mon_local,0)) <> 0
    and not exists(select 1 from cb_rubros t where substr(t.cod_rubro,9,2) = '01' and nivel = 5 and k.cod_rubro=t.cod_rub_padre)
    group by s.cod_oficina, '0'||substr(r.cod_rub_bcp,1,5),
       case when substr(r.cod_rub_bcp,6,6) = '000000' then null
       else substr(r.cod_rub_bcp,6,6) end,
       k.Descripcion,
       k.cod_rubro,  s.mes, s.ano, 'Promedio Cerrado Con Signo x Sucursal'
    order by 1, 2, 3;

  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'prom_cerrado_suc'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_anho             VARCHAR2(4);
  v_mes              VARCHAR2(2);
  --v_hora             VARCHAR2(8);
  v_can_dia          NUMBER;

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
  -- Obtenemos la fecha anterior
  -- anho
   v_anho  := to_char(pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1),'YYYY');
  -- mes
  v_mes   := to_char(pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1),'MM');

  select to_char(max(fecha),'mm') into v_can_dia--se obtiene la máxima fecha de la contabilidad cerrada para sacar saldo promedio
   from cb_asientos_his;

-- Abrir archivo
v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'.txt','W',32767);

-- Colocar el titulo a los campos
v_linetit := 'COD_OFICINA'||CHR(9)||'BCP1'||CHR(9)||'BCP2'||CHR(9)||'DESCRIPCION'||CHR(9)||'SALDO_GUARANIES'||CHR(9)||
             'SALDO_RUBRO'||CHR(9)||'SALDO_EQUIVALENTE'||CHR(9)||'SALDO_TOTAL'||CHR(9)||'RUBRO_IT'||CHR(9)||
             'MES'||CHR(9)||'ANO'||CHR(9)||'TIP_BALANCE';

utl_file.put_line(v_file,v_linetit);

-- Definir una linea en blanco para separar los datos del titulo de los campos
v_linetit := ' ';
utl_file.put_line(v_file,v_linetit);

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN cu_procer_suc(v_anho, v_mes, v_can_dia) LOOP

    --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
  v_line := to_char(rec.COD_OFICINA)||chr(9)||to_char(rec.BCP1)||chr(9)||to_char(rec.BCP2)||chr(9)||to_char(rec.DESCRIPCION)||chr(9)||
             to_char(rec.SALDO_GUARANIES,'999999999999999999999D00')||chr(9)||to_char(rec.SALDO_RUBRO,'999999999999999999999D00')||chr(9)||
            to_char(rec.SALDO_EQUIVALENTE,'999999999999999999999D00')||chr(9)||to_char(rec.SALDO_TOTAL,'999999999999999999999D00')||chr(9)||
            to_char(rec.RUBRO_IT)||chr(9)||to_char(rec.MES)||chr(9)||to_char(rec.ANO)||chr(9)||
            to_char(rec.TIP_BALANCE);


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

  EXIT WHEN cu_procer_suc%NOTFOUND;
END LOOP;
--Escribes la linea en el fichero
UTL_FILE.PUT_LINE(v_file, v_buffer);

--Cerrar el handler al fichero
UTL_FILE.FCLOSE(v_file);
COMMIT;

  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_respuesta := pa_file_ftp.fu_put_ascii(pa_rpc_aut.g_ip, pa_rpc_aut.g_port, pa_rpc_aut.g_user,
                                          pa_rpc_aut.g_pass, pa_rpc_aut.g_repository,
                                          v_name||'.txt', g_balances||v_name||'_'||v_anho||v_mes||v_can_dia||'.txt');

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos las direcciones de correo para quien o quienes va el correo
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','PROMEDIO_CERRADO_SUC');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte Balance Saldos Promedio Cerrado por Sucursal Diario a la fecha  '||v_anho||v_mes||v_can_dia||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_balances||'

    Nombre del Archivo: '||v_name||'_'||v_anho||v_mes||v_can_dia||'.txt';

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_anho||v_mes||v_can_dia||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error    := null;

    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, v_name||'_'||v_anho||v_mes||v_can_dia||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;

    --Enviamos el mail a soporte
     -- Obtenemos direccion de correo de soporte
     v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error Reporte Balance Saldos Promedio Cerrado por Sucursal Diario a la fecha '||v_anho||v_mes||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_anho||v_mes||v_can_dia||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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
END pr_pro_cer_suc_diario;

-------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------
-- Procedimiento para obtener reportes de saldos de promedio diarios
PROCEDURE pr_bal_prom_diario
IS
BEGIN
    BEGIN

      -- Saldos Promedio Abierto Diario
      pa_rpc_aut.pr_prom_abi_diario;
      commit;

      -- Saldos Promedio Abierto por Sucursal Diario
      pa_rpc_aut.pr_pro_abi_suc_diario;
      commit;

      -- Saldos Promedio Cerrado Diario
      pa_rpc_aut.pr_prom_cer_diario;
      commit;

      -- Saldos Promedio Cerrado por Sucursal Diario
      pa_rpc_aut.pr_pro_cer_suc_diario;
      commit;

    END;
END pr_bal_prom_diario;

-------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------
-- Informes para Casa Matriz en España - Renta Fija
PROCEDURE pr_info_renta_fija
IS
CURSOR cu_renta IS
       select d.LINEA linea
       from CB_INF_REN_TMP d;

  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'RENTA_FIJA'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_fecha            VARCHAR2(8);

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
  -- Obtenemos la fecha del último fin de mes
  select to_char(pag_cal.FU_OBT_FEC_ANT_HAB ((select f.pri_dia_mes from ge_calendarios f
   where f.cod_modulo=1),31,1),'DDMMYYYY') into v_fecha
   from dual;

-- Abrir archivo
v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name,'W',32767);

-- Colocar el titulo a los campos
v_linetit := 'RENTA_FIJA';

utl_file.put_line(v_file,v_linetit);

-- Definir una linea en blanco para separar los datos del titulo de los campos
v_linetit := ' ';
utl_file.put_line(v_file,v_linetit);

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN cu_renta LOOP

    --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
  v_line := to_char(rec.LINEA);

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

  EXIT WHEN cu_renta%NOTFOUND;
END LOOP;
--Escribes la linea en el fichero
UTL_FILE.PUT_LINE(v_file, v_buffer);

--Cerrar el handler al fichero
UTL_FILE.FCLOSE(v_file);
COMMIT;

  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_respuesta := pa_file_ftp.fu_put_ascii(pa_rpc_aut.g_ip, pa_rpc_aut.g_port, pa_rpc_aut.g_user,
                                          pa_rpc_aut.g_pass, pa_rpc_aut.g_repository,
                                          v_name, g_infoespana||v_name||'_'||v_fecha);

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','INFO_RENTA');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte RENTA_FIJA para Casa Matriz en España a la fecha '||v_fecha||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_infoespana||'

    Nombre del Archivo: '||v_name||'_'||v_fecha;

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha, v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error    := null;

    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, v_name||'_'||v_fecha, v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;

    --Enviamos el mail a soporte
     -- Obtenemos direccion de correo de soporte
     v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error Reporte RENTA_FIJA para Casa Matriz en España a la fecha '||v_fecha||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha, v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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
END pr_info_renta_fija;

-------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------
-- Generación de informe para cuadrar R1 del bcp diario
PROCEDURE pr_gen_inf_r1
IS
CURSOR cu_datos_d(p_fec_proceso date) IS
    select i.cod_rubro, i.cod_moneda,i.cod_modulo, i.cod_modalidad, i.cod_oficina, i.tip_saldo,
        e.cod_persona, d.nro_cuenta, d.sal_actual,t.estado, 0 lin_credito_tarjeta,
        decode(i.cod_moneda,'GS',d.sal_actual,(nvl(d.sal_actual,0)
        * fug_obt_cotizacion(i.cod_moneda,p_fec_proceso))) monto_gs
      from cb_sal_inventarios i, cb_sal_inventarios_det d, ge_cta_clientes e, ge_cuentas t
      where i.nro_referencia=d.nro_referencia
      and d.nro_cuenta=e.nro_cuenta
      and e.relacion='P'
      and i.cod_modulo in (4,8)
      and t.nro_cuenta=d.nro_cuenta
      and i.cod_modulo=t.cod_modulo
      and i.cod_modalidad=t.cod_modalidad
      and substr(i.cod_rubro,1,10) in ('4101060702','4101060904','4101061104','4101061502','4101061702')
      and nvl(d.sal_actual,0) <> 0
union all
select i.cod_rubro, i.cod_moneda,i.cod_modulo, i.cod_modalidad, i.cod_oficina, i.tip_saldo,
        e.cod_persona, d.nro_cuenta, d.sal_actual,tt.estado,(nvl(tt.lin_credito,0)+nvl(tt.lin_cuotas,0)) lin_credito_tarjeta,
        decode(i.cod_moneda,'GS',d.sal_actual,(nvl(d.sal_actual,0) * fug_obt_cotizacion(i.cod_moneda,p_fec_proceso)))monto_gs
      from cb_sal_inventarios i, cb_sal_inventarios_det d, ge_cta_clientes e, ta_cta_tarjetas tt
      where i.nro_referencia=d.nro_referencia
      and d.nro_cuenta=e.nro_cuenta
      and e.relacion='P'
      and i.cod_modulo in (5)
      and tt.nro_cuenta=d.nro_cuenta
      and i.cod_modulo=tt.cod_modulo
      and i.cod_modalidad=tt.cod_modalidad
      and substr(i.cod_rubro,1,10) in ('4101060702','4101060904','4101061104','4101061502','4101061702')
      and nvl(d.sal_actual,0) <> 0;


  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'INFORME_R1'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_fec_sist         DATE;
  v_fecha            VARCHAR2(8);
  v_fec_proceso      DATE;

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
   select to_char(pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1),'DDMMYYYY') into v_fecha
   from dual;

   v_fec_proceso:=pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1);
-- Abrir archivo
v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'.txt','W',32767);

-- Colocar el titulo a los campos
v_linetit := 'COD_RUBRO'||CHR(9)||'COD_MONEDA'||CHR(9)||'COD_MODULO'||CHR(9)||'COD_MODALIDAD'||CHR(9)||
             'COD_OFICINA'||CHR(9)||'TIP_SALDO'||CHR(9)||'COD_PERSONA'||CHR(9)||'NRO_CUENTA'||CHR(9)||
             'SAL_ACTUAL'||CHR(9)||'ESTADO'||CHR(9)||'LINEA_CRE_TARJETA'||CHR(9)||'MTO_GS';


utl_file.put_line(v_file,v_linetit);

-- Definir una linea en blanco para separar los datos del titulo de los campos
v_linetit := ' ';
utl_file.put_line(v_file,v_linetit);

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN cu_datos_d(v_fec_proceso) LOOP

    --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
  v_line := to_char(rec.cod_rubro)||chr(9)||to_char(rec.cod_moneda)||chr(9)||
            to_char(rec.cod_modulo)||chr(9)||to_char(rec.cod_modalidad)||chr(9)||
            to_char(rec.cod_oficina)||chr(9)||to_char(rec.tip_saldo)||chr(9)||to_char(rec.cod_persona)||chr(9)||
            to_char(rec.nro_cuenta)||chr(9)||to_char(rec.sal_actual,'999999999999999999D00')||chr(9)||
            to_char(rec.estado)||chr(9)||to_char(rec.lin_credito_tarjeta)||chr(9)||to_char(rec.monto_gs);

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

   EXIT WHEN cu_datos_d%NOTFOUND;
END LOOP;
--Escribes la linea en el fichero
UTL_FILE.PUT_LINE(v_file, v_buffer);

--Cerrar el handler al fichero
UTL_FILE.FCLOSE(v_file);
COMMIT;

  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_respuesta := pa_file_ftp.fu_put_ascii(pa_rpc_aut.g_ip, pa_rpc_aut.g_port, pa_rpc_aut.g_user,
                                          pa_rpc_aut.g_pass, pa_rpc_aut.g_repository,
                                          v_name||'.txt', g_contabilidad||v_name||'_'||v_fecha||'.txt');

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','INFORME_R1');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte de Cuadre R1 BCP'||v_fec_sist||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_contabilidad||'

    Nombre del Archivo: '||v_name||'_'||v_fecha||'.txt';

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error    := null;

    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, v_name||'_'||v_fecha||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;

    --Enviamos el mail a soporte
     -- Obtenemos direccion de correo de soporte
     v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error Reporte de Cuadre R1 BCP'||v_fec_sist||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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
    RAISE_APPLICATION_ERROR(-20062,'Manejador invalido');
  WHEN UTL_FILE.WRITE_ERROR THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20063,'Error de escritura '||sqlerrm);
  WHEN UTL_FILE.INVALID_MODE THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20064,'Modo invalido');
  WHEN UTL_FILE.INTERNAL_ERROR THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20065,'Internal Error');
END pr_gen_inf_r1;
-------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------
-- Generación de informe para cuadrar R1 del bcp mensual
PROCEDURE pr_gen_inf_r1_mens
IS
CURSOR cu_datos(p_fec_proceso date) IS
    select i.cod_rubro, i.cod_moneda,i.cod_modulo, i.cod_modalidad, i.cod_oficina, i.tip_saldo,
        e.cod_persona, d.nro_cuenta, d.sal_actual,t.estado, 0 lin_credito_tarjeta,
        decode(i.cod_moneda,'GS',d.sal_actual,(nvl(d.sal_actual,0)
        * fug_obt_cotizacion(i.cod_moneda,p_fec_proceso))) monto_gs
      from cb_sal_inventarios i, cb_sal_inventarios_det d, ge_cta_clientes e, ge_cuentas t
      where i.nro_referencia=d.nro_referencia
      and d.nro_cuenta=e.nro_cuenta
      and e.relacion='P'
      and i.cod_modulo in (4,8)
      and t.nro_cuenta=d.nro_cuenta
      and i.cod_modulo=t.cod_modulo
      and i.cod_modalidad=t.cod_modalidad
      and substr(i.cod_rubro,1,10) in ('4101060702','4101060904','4101061104','4101061502','4101061702')
      and nvl(d.sal_actual,0) <> 0
union all
select i.cod_rubro, i.cod_moneda,i.cod_modulo, i.cod_modalidad, i.cod_oficina, i.tip_saldo,
        e.cod_persona, d.nro_cuenta, d.sal_actual,tt.estado,(nvl(tt.lin_credito,0)+nvl(tt.lin_cuotas,0)) lin_credito_tarjeta,
        decode(i.cod_moneda,'GS',d.sal_actual,(nvl(d.sal_actual,0) * fug_obt_cotizacion(i.cod_moneda,p_fec_proceso)))monto_gs
      from cb_sal_inventarios i, cb_sal_inventarios_det d, ge_cta_clientes e, ta_cta_tarjetas tt
      where i.nro_referencia=d.nro_referencia
      and d.nro_cuenta=e.nro_cuenta
      and e.relacion='P'
      and i.cod_modulo in (5)
      and tt.nro_cuenta=d.nro_cuenta
      and i.cod_modulo=tt.cod_modulo
      and i.cod_modalidad=tt.cod_modalidad
      and substr(i.cod_rubro,1,10) in ('4101060702','4101060904','4101061104','4101061502','4101061702')
      and nvl(d.sal_actual,0) <> 0;


  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'INFORME_R1'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_fec_sist         DATE;
  v_fecha            VARCHAR2(8);
  v_fec_proceso      DATE;

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
   select to_char(pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1),'DDMMYYYY') into v_fecha
   from dual;
   --Fecha para la cotizacion
   v_fec_proceso:=pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1);

-- Abrir archivo
v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'.txt','W',32767);

-- Colocar el titulo a los campos
v_linetit := 'COD_RUBRO'||CHR(9)||'COD_MONEDA'||CHR(9)||'COD_MODULO'||CHR(9)||'COD_MODALIDAD'||CHR(9)||
             'COD_OFICINA'||CHR(9)||'TIP_SALDO'||CHR(9)||'COD_PERSONA'||CHR(9)||'NRO_CUENTA'||CHR(9)||
             'SAL_ACTUAL'||CHR(9)||'ESTADO'||CHR(9)||'LINEA_CRE_TARJETA'||CHR(9)||'MTO_GS';


utl_file.put_line(v_file,v_linetit);

-- Definir una linea en blanco para separar los datos del titulo de los campos
v_linetit := ' ';
utl_file.put_line(v_file,v_linetit);

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN cu_datos(v_fec_proceso) LOOP

    --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
  v_line := to_char(rec.cod_rubro)||chr(9)||to_char(rec.cod_moneda)||chr(9)||
            to_char(rec.cod_modulo)||chr(9)||to_char(rec.cod_modalidad)||chr(9)||
            to_char(rec.cod_oficina)||chr(9)||to_char(rec.tip_saldo)||chr(9)||to_char(rec.cod_persona)||chr(9)||
            to_char(rec.nro_cuenta)||chr(9)||to_char(rec.sal_actual,'999999999999999999D00')||chr(9)||
            to_char(rec.estado)||chr(9)||to_char(rec.lin_credito_tarjeta)||chr(9)||to_char(rec.monto_gs);

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

   EXIT WHEN cu_datos%NOTFOUND;
END LOOP;
--Escribes la linea en el fichero
UTL_FILE.PUT_LINE(v_file, v_buffer);

--Cerrar el handler al fichero
UTL_FILE.FCLOSE(v_file);
COMMIT;

  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_respuesta := pa_file_ftp.fu_put_ascii(pa_rpc_aut.g_ip, pa_rpc_aut.g_port, pa_rpc_aut.g_user,
                                          pa_rpc_aut.g_pass, pa_rpc_aut.g_repository,
                                          v_name||'.txt', g_contabilidad||v_name||'_'||v_fecha||'.txt');

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','INFORME_R1');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte de Cuadre R1 BCP'||v_fec_sist||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_contabilidad||'

    Nombre del Archivo: '||v_name||'_'||v_fecha||'.txt';

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error    := null;

    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, v_name||'_'||v_fecha||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;

    --Enviamos el mail a soporte
     -- Obtenemos direccion de correo de soporte
     v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error Reporte de Cuadre R1 BCP'||v_fec_sist||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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
    RAISE_APPLICATION_ERROR(-20062,'Manejador invalido');
  WHEN UTL_FILE.WRITE_ERROR THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20063,'Error de escritura '||sqlerrm);
  WHEN UTL_FILE.INVALID_MODE THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20064,'Modo invalido');
  WHEN UTL_FILE.INTERNAL_ERROR THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20065,'Internal Error');
END pr_gen_inf_r1_mens;
-------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------
-- Generacion de Mayor Contable en txt
PROCEDURE pr_gen_mayor(p_fec_desde in date,p_fec_hasta in date,p_rubro in varchar2,p_oficina in number)
IS
CURSOR cu_prom_cer(pc_fec_desde date, pc_fec_hasta date, pc_rubro varchar2,pc_oficina number) IS
  select e.cod_rubro, cod_rub_externo, e.fecha,e.cod_oficina,nro_asiento,
         nro_linea, ref, descripcion,deb_rubro,cre_rubro,deb_local,cre_local,
         pab_may.FU_CAL_SAL_MAY(e.cod_rubro,e.cod_oficina,
         (nvl(deb_local,0)-nvl(cre_local,0)),(nvl(deb_rubro,0)-nvl(cre_rubro,0)))saldo_ml,
         e.cod_usuario,FUB_OBT_SAL_CONSOLIDADO(e.cod_rubro,e.fecha)saldo_consolidado
  from bv_may_oficinas e
  where e.cod_rubro=pc_rubro
  and e.fecha between pc_fec_desde and pc_fec_hasta
  and (e.cod_oficina=pc_oficina or pc_oficina is null);

  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'Mayor_Contable'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;


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

  -- Variables de fecha
  v_fecha            date;

BEGIN

 select to_char(pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1),'DDMMYYYY') into v_fecha
   from dual;
 if p_fec_desde > p_fec_hasta then
   RAISE_APPLICATION_ERROR(-20000,'La fecha desde no puede ser mayor a la fecha hasta');
 end if;
-- Abrir archivo
v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'_'||p_rubro||'.txt','W',32767);

-- Colocar el titulo a los campos
v_linetit := 'COD_RUBRO'||CHR(9)||'COD_RUB_EXT'||CHR(9)||'FECHA'||CHR(9)||
             'COD_OFICINA'||CHR(9)||'NRO_ASIENTO'||CHR(9)||'NRO_LINEA'||CHR(9)||
             'REF'||CHR(9)||'DESCRIPCION'||CHR(9)||
             'DEB_RUBRO'||CHR(9)||'CRE_RUBRO'||CHR(9)||'DEB_LOCAL'||CHR(9)||
             'CRE_LOCAL'||CHR(9)||'SALDO_ML' ||CHR(9)||'COD_USUARIO'||CHR(9)||'SALDO_CONSOLIDADO'  ;

utl_file.put_line(v_file,v_linetit);

-- Definir una linea en blanco para separar los datos del titulo de los campos
v_linetit := ' ';
utl_file.put_line(v_file,v_linetit);

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN cu_prom_cer(p_fec_desde, p_fec_hasta, p_rubro,p_oficina) LOOP

    --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
  v_line := to_char(rec.cod_rubro)||chr(9)||
            to_char(rec.cod_rub_externo)||chr(9)||
            to_char(rec.fecha)||chr(9)||
            to_char(rec.cod_oficina)||chr(9)||
            to_char(rec.nro_asiento)||chr(9)||
            to_char(rec.nro_linea)||chr(9)||
            to_char(rec.ref)||chr(9)||
            to_char(rec.descripcion)||chr(9)||
            to_char(rec.deb_rubro)||chr(9)||
            to_char(rec.cre_rubro)||chr(9)||
            to_char(rec.deb_local)||chr(9)||
            to_char(rec.cre_local)||chr(9)||
            to_char(rec.saldo_ml)||chr(9)||
            to_char(rec.cod_usuario)||chr(9)||
            to_char(rec.saldo_consolidado);


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

  EXIT WHEN cu_prom_cer%NOTFOUND;
END LOOP;
--Escribes la linea en el fichero
UTL_FILE.PUT_LINE(v_file, v_buffer);

--Cerrar el handler al fichero
UTL_FILE.FCLOSE(v_file);
COMMIT;

  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_respuesta := pa_file_ftp.fu_put_ascii(pa_rpc_aut.g_ip, pa_rpc_aut.g_port, pa_rpc_aut.g_user,
                                          pa_rpc_aut.g_pass, pa_rpc_aut.g_repository,
                                          v_name||'_'||p_rubro||'.txt', g_contabilidad||v_name||'_'||p_rubro||'.txt');

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','MAYOR_CONTABLE');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte Mayor contable del rubro '||p_rubro||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_contabilidad||'

    Nombre del Archivo: '||v_name||'_'||p_rubro||'.txt';

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||p_rubro||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error    := null;

    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, v_name||'_'||p_rubro||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;

    --Enviamos el mail a soporte
     -- Obtenemos direccion de correo de soporte
     v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error Mayor contable del rubro '||p_rubro||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||p_rubro||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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
END pr_gen_mayor;

------------------------------------------------------------------------------------------
-----------------------------Inventario de Garantias 1------------------------------------
procedure pr_inv_gar
is cursor inv_garantias is
select i.cod_rubro,
       r.cod_rub_externo,
       r.descripcion,
       i.cod_moneda,
       i.cod_modalidad,
       i.cod_oficina,
       decode(i.tip_saldo,'E','COMPUTABLE','EXCESO') tip_saldo,
       p.cod_persona,
       fue_obt_nom_persona(p.cod_persona) nombre,
       d.nro_cuenta nro_garantia,
       d.sal_actual,
       p.fec_inicio,
       p.fec_vencimiento,
       p.estado,
       p.fec_ult_tasacion,
       p.cod_mon_tasacion,
       P.VAL_TASACION
 from cb_sal_inventarios i, cb_sal_inventarios_det d, cb_rubros r,
      pr_garantias p, pr_gar_tipos t
where i.nro_referencia=d.nro_referencia
  and to_number(trim(d.nro_cuenta))=p.nro_garantia
  and i.cod_rubro=r.cod_rubro(+)
  and i.tip_saldo in ('E','J') -- Garantías
  and t.cod_garantia=p.cod_garantia
  and t.computable='S'
  and substr(i.cod_rubro,1,2)='51' ;

  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'inv_garantias'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_fec_sist         DATE;
  v_fecha            VARCHAR2(8);

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
  --var_char
  v_char             varchar2(1);

BEGIN
  -- Obtenemos la fecha del sistema
  v_char :=chr(9);
  select pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1)
  into v_fec_sist
  from dual;

  v_fecha := to_char(v_fec_sist,'DDMMYYYY');

-- Abrir archivo
v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'.txt','W',32767);

-- Colocar el titulo a los campos
v_linetit :='cod_rubro'||v_char||'cod_rub_externo'||v_char||'descripcion '||v_char||
            'cod_moneda'||v_char||'cod_modalidad'||v_char||'cod_oficina'||v_char||
            'tip_saldo'||v_char||'cod_persona'||v_char||'nombre'||v_char||
            'nro_garantia '||v_char||'sal_actual '||v_char||'fec_inicio'||v_char||
            'fec_vencimiento'||v_char||'estado'||v_char||'fec_ult_tasacion '||v_char||
            'cod_mon_tasacion'||v_char||'val_tasacion';

utl_file.put_line(v_file,v_linetit);

-- Definir una linea en blanco para separar los datos del titulo de los campos
v_linetit := ' ';utl_file.put_line(v_file,v_linetit);

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN inv_garantias LOOP
    --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
v_line :=
        to_char(rec.cod_rubro||v_char)||
        to_char(rec.cod_rub_externo||v_char)||
        to_char(rec.descripcion ||v_char)||
        to_char(rec.cod_moneda||v_char)||
        to_char(rec.cod_modalidad||v_char)||
        to_char(rec.cod_oficina||v_char)||
        to_char(rec.tip_saldo||v_char)||
        to_char(rec.cod_persona||v_char)||
        to_char(rec.nombre||v_char)||
        to_char(rec.nro_garantia ||v_char)||
        to_char(rec.sal_actual ,'999999999999D00')||v_char||
        to_char(rec.fec_inicio||v_char)||
        to_char(rec.fec_vencimiento||v_char)||
        to_char(rec.estado||v_char)||
        to_char(rec.fec_ult_tasacion||v_char)||
        to_char(rec.cod_mon_tasacion||v_char)||
        to_char(rec.val_tasacion);

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

   EXIT WHEN inv_garantias%NOTFOUND;
END LOOP;
--Escribes la linea en el fichero
UTL_FILE.PUT_LINE(v_file, v_buffer);

--Cerrar el handler al fichero
UTL_FILE.FCLOSE(v_file);
COMMIT;
  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');
  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_respuesta := pa_file_ftp.fu_put_ascii
  (pa_rpc_aut.g_ip, pa_rpc_aut.g_port, pa_rpc_aut.g_user,pa_rpc_aut.g_pass,
   pa_rpc_aut.g_repository,v_name||'.txt', g_riesgos||v_name||'_'||v_fecha||'.txt');

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','INV_GARANTIAS');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte de garantias, Inventario 1 '||v_fec_sist||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_riesgos||'

    Nombre del Archivo: '||v_name||'_'||v_fecha||'.txt';

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,
                   v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error    := null;

    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, v_name||'_'||v_fecha||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;

    --Enviamos el mail a soporte
     -- Obtenemos direccion de correo de soporte
     v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error Reporte de Garantias a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail
         (pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
          it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
          it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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
    RAISE_APPLICATION_ERROR(-20062,'Manejador invalido');
  WHEN UTL_FILE.WRITE_ERROR THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20063,'Error de escritura '||sqlerrm);
  WHEN UTL_FILE.INVALID_MODE THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20064,'Modo invalido');
  WHEN UTL_FILE.INTERNAL_ERROR THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20065,'Internal Error');
END pr_inv_gar;
------------------------------------------------------------------------------------------
---------------------Inventario de Garantias(asientos contables)--------------------------
procedure pr_inv_asi_gar
is cursor inv_asi_garantias is
select ta.cod_rubro rubro,
       ta.descripcion des_asiento,
       g.cod_oficina oficina,
       sc.descripcion sec_contable,
       ta.ind_residente residente,
       g.cod_persona cod_persona,
       g.cod_garantia cod_garantia,
       tg.descripcion des_garantia,
       g.nro_garantia nro_garantia,
       fue_obt_des_refcodes('EST_GARANTIA',g.estado) Estado_Garantia,
       g.fec_inicio fec_inicio,
       g.fec_vencimiento fec_vencimiento,
       g.cod_moneda moneda,
       g.valor valor,
       g.val_tasacion val_tasacion,
       g.fec_ult_tasacion fec_ult_tasacion,
       g.nro_escritura nro_escritura,
       e.descripcion des_escribano
  from ge_entes e,
       pr_gar_tipos tg,
       ge_clientes c,
       pr_garantias g,
       ge_transacciones t,
       ge_tip_asientos ta,
       ge_sec_contables sc
 where g.cod_persona = c.cod_persona
   and g.cod_garantia = tg.cod_garantia
   and g.cod_ent_escribania = e.cod_ente(+)
   and ta.cod_sec_contable = sc.cod_sec_contable(+)
   and t.cod_transaccion = tg.cod_transaccion1
   and t.cod_modalidad = 61
   and t.cod_tip_asiento = ta.cod_tip_asiento
   and ta.cod_moneda = g.cod_moneda
   and ta.tip_movimiento ='D'
   and g.estado <> 'N'
union
select ta.cod_rubro rubro,
       ta.descripcion des_asiento,
       g.cod_oficina oficina,
       sc.descripcion sec_contable,
       ta.ind_residente residente,
       g.cod_persona cod_persona,
       g.cod_garantia cod_garantia,
       tg.descripcion des_garantia,
       g.nro_garantia nro_garantia,
      fue_obt_des_refcodes('EST_GARANTIA',g.estado) Estado_Garantia,
       g.fec_inicio fec_inicio,
       g.fec_vencimiento fec_vencimiento,
       g.cod_moneda moneda,
       g.valor valor,
       g.val_tasacion val_tasacion,
       g.fec_ult_tasacion fec_ult_tasacion,
       g.nro_escritura nro_escritura,
       e.descripcion des_escribano
  from ge_entes e,
       pr_gar_tipos tg,
       ge_clientes c,
       pr_garantias g,
       ge_transacciones t,
       ge_tip_asientos ta,
       ge_sec_contables sc
 where g.cod_persona = c.cod_persona
   and g.cod_garantia = tg.cod_garantia
   and g.cod_ent_escribania = e.cod_ente(+)
   and ta.cod_sec_contable = sc.cod_sec_contable(+)
   and t.cod_transaccion = tg.cod_transaccion2
   and t.cod_modalidad = 61
   and t.cod_tip_asiento = ta.cod_tip_asiento
   and ta.cod_moneda = g.cod_moneda
   and ta.tip_movimiento ='D'
   and tg.cod_transaccion1 is null
   and g.estado <> 'N';

  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'inv_asi_garantias'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_fec_sist         DATE;
  v_fecha            VARCHAR2(8);

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
  --var_char
  v_char             varchar2(1);

BEGIN
  -- Obtenemos la fecha del sistema
  v_char :=chr(9);
  select pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1)
  into v_fec_sist
  from dual;

  v_fecha := to_char(v_fec_sist,'DDMMYYYY');

-- Abrir archivo
v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'.txt','W',32767);

-- Colocar el titulo a los campos
v_linetit :='rubro'||v_char||'des_asiento'||v_char||
            'oficina'||v_char||'sec_contable'||v_char||
            'residente'||v_char||'cod_persona'||v_char||
            'cod_garantia'||v_char||'des_garantia'||v_char||
            'nro_garantia'||v_char||'Estado_Garantia'||v_char||
            'fec_inicio'||v_char||'fec_vencimiento'||v_char||
            'moneda'||v_char||'valor'||v_char||
            'val_tasacion'||v_char||'fec_ult_tasacion'||v_char||
            'nro_escritura'||v_char||'des_escribano';

utl_file.put_line(v_file,v_linetit);

-- Definir una linea en blanco para separar los datos del titulo de los campos
v_linetit := ' ';utl_file.put_line(v_file,v_linetit);

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN inv_asi_garantias LOOP
    --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
v_line :=
        to_char(rec.rubro||v_char)||
        to_char(rec.des_asiento||v_char)||
        to_char(rec.oficina||v_char)||
        to_char(rec.sec_contable||v_char)||
        to_char(rec.residente||v_char)||
        to_char(rec.cod_persona||v_char)||
        to_char(rec.cod_garantia||v_char)||
        to_char(rec.des_garantia||v_char)||
        to_char(rec.nro_garantia||v_char)||
        to_char(rec.Estado_Garantia||v_char)||
        to_char(rec.fec_inicio||v_char)||
        to_char(rec.fec_vencimiento||v_char)||
        to_char(rec.moneda||v_char)||
        to_char(rec.valor,'999999999999D00')||v_char||
        to_char(rec.val_tasacion||v_char)||
        to_char(rec.fec_ult_tasacion||v_char)||
        to_char(rec.nro_escritura||v_char)||
        to_char(rec.des_escribano);

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

   EXIT WHEN inv_asi_garantias%NOTFOUND;
END LOOP;
--Escribes la linea en el fichero
UTL_FILE.PUT_LINE(v_file, v_buffer);

--Cerrar el handler al fichero
UTL_FILE.FCLOSE(v_file);
COMMIT;
  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');
  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_respuesta := pa_file_ftp.fu_put_ascii
  (pa_rpc_aut.g_ip, pa_rpc_aut.g_port, pa_rpc_aut.g_user,pa_rpc_aut.g_pass,
   pa_rpc_aut.g_repository,v_name||'.txt', g_riesgos||v_name||'_'||v_fecha||'.txt');

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','INV_GARANTIAS');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte de garantias, Inventario 2 '||v_fec_sist||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_riesgos||'

    Nombre del Archivo: '||v_name||'_'||v_fecha||'.txt';

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,
                   v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error    := null;

    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, v_name||'_'||v_fecha||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;

    --Enviamos el mail a soporte
     -- Obtenemos direccion de correo de soporte
     v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error Reporte de Garantias a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail
         (pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
          it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
          it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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
    RAISE_APPLICATION_ERROR(-20062,'Manejador invalido');
  WHEN UTL_FILE.WRITE_ERROR THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20063,'Error de escritura '||sqlerrm);
  WHEN UTL_FILE.INVALID_MODE THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20064,'Modo invalido');
  WHEN UTL_FILE.INTERNAL_ERROR THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20065,'Internal Error');
END pr_inv_asi_gar;
-------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------
-- Informe de Prestamos del Exterior Mensual
PROCEDURE pr_gen_pres_ext
IS
CURSOR cu_pres_ext IS
    select nvl(gcli.cod_persona,0) PREFNUMCLI,
      decode(mdoc.cod_modalidad,118,'P',109,'C','') PREFTIPOPR,
      nvl(PAI_INT.FU_SIM_NORM_CADENA(mdoc.nro_documento,20),'SEQ'|| rownum) PREFNRO,
      'C' PREFTIPOR,
      '3' PREFTIPOCL,
      decode(mdoc.cod_moneda,'GS','0','USD','5','EUR','17') PREFMONEDA,
      nvl(to_char(mdet.fec_vencimiento,'YYYYMMDD'),0) PREFVTO,
      nvl(mdet.sal_capital,0) PREFMONTO,
      nvl(mdoc.cod_oficina,0) PREFSUC,
      nvl(pai_int.fu_obt_cta_contable(fub_obt_rub_transaccion(mdoc.cod_modulo,mdoc.cod_modalidad,711, /*codigo transaccion*/
                                                           mdoc.cod_moneda,gcli.cod_persona,fug_obt_plz_contable(mdoc.fec_vencimiento - mdoc.fec_inicio),
                                                           'D',mdoc.estado, null, null, null, null,mdoc.cod_sit_contable)),0) PREFCUENTA,
      nvl(to_char(PAI_INT.FU_SIM_OBT_FECHAINI(mdet.nro_cuenta,mdet.nro_cuota),'yyyymmdd'),0) PREFFEINI,
      0 PREFDEVENG,
      nvl(to_char(trunc(sysdate),'yyyymmdd'),0) PREFCHCONT,
      nvl(mdoc.val_tasa,0) PREFTASA,
      --check 1
      mdoc.fec_ult_pago doc_ult_pago, mdet.fec_ult_pago det_ult_pago, mdet.mto_capital,
      mdoc.estado doc_estado, mdet.estado det_estado,
      --check 2
      (select min(mdet3.fec_vencimiento)
        from md_cta_documentos mdoc3, md_doc_detalles mdet3
        where mdoc3.cod_modalidad in (109,118)
        and mdet3.nro_cuenta= mdet.nro_cuenta
        and mdet3.mto_capital <> 0
        and mdet3.estado not in ('N','S') ) venc_gral,
      mdet.fec_vencimiento venc_registro,
      --check 3
      (select max(mv3.fec_ult_devengado)
                                           from md_devengados mv3
                                           where mv3.nro_cuenta = mdet.nro_cuenta) fec_ult_dev2,
      fug_obt_plz_contable(mdoc.fec_vencimiento - mdoc.fec_inicio) plazo,
      mdoc.fec_vencimiento fec_vencimiento,
      mdoc.fec_inicio fec_inicio

      from ge_cta_clientes gcli, md_cta_documentos mdoc, md_doc_detalles mdet
      where gcli.relacion = 'P'
      and mdoc.nro_cuenta= gcli.nro_cuenta
      and mdoc.cod_modalidad in (109,118)
      and mdoc.nro_cuenta= mdet.nro_cuenta
      and mdet.mto_capital <> 0
      and mdet.estado not in ('N','S')

UNION

select nvl(gcli.cod_persona,0) PREFNUMCLI,
      decode(mdoc.cod_modalidad,118,'P',109,'C','') PREFTIPOPR,
      nvl(PAI_INT.FU_SIM_NORM_CADENA(mdoc.nro_documento,15), 'SEQ'|| rownum) PREFNRO,
      'I' PREFTIPOR,
      '3' PREFTIPOCL,
      decode(mdoc.cod_moneda,'GS','0','USD','5','EUR','17') PREFMONEDA,
      nvl(to_char(mdet.fec_vencimiento,'YYYYMMDD'),0) PREFVTO,
      nvl(mdet.mto_interes,0) PREFMONTO,
      nvl(mdoc.cod_oficina,0) PREFSUC,
      nvl(pai_int.fu_obt_cta_contable(fub_obt_rub_transaccion(mdoc.cod_modulo,mdoc.cod_modalidad,719, /*codigo transaccion*/
                                                                 mdoc.cod_moneda,gcli.cod_persona,fug_obt_plz_contable(mdoc.fec_vencimiento - mdoc.fec_inicio),
                                                                 'D',mdoc.estado, null, null, null, null,mdoc.cod_sit_contable)),0) PREFCUENTA,
      nvl(to_char(PAI_INT.FU_SIM_OBT_FECHAINI(mdet.nro_cuenta,mdet.nro_cuota),'yyyymmdd'),0) PREFFEINI,
      Case
      when (select min(mdet2.fec_vencimiento)
            from md_cta_documentos mdoc2, md_doc_detalles mdet2
            where mdoc2.cod_modalidad in (109,118)
            and mdet2.nro_cuenta = mdet.nro_cuenta
            and mdoc2.nro_cuenta = mdet2.nro_cuenta
            and mdet2.mto_interes <> 0
            and mdet2.estado not in ('N','S')) = mdet.fec_vencimiento then

                nvl((mdoc.sal_interes - mdoc.val_int_devengar),0)

      else
            0
      end PREFDEVENG,
      nvl(to_char(trunc(sysdate),'yyyymmdd'),0) PREFCHCONT,
      nvl(mdoc.val_tasa,0) PREFTASA,
      --check 1
      mdoc.fec_ult_pago doc_ult_pago, mdet.fec_ult_pago det_ult_pago, mdet.mto_capital,
      mdoc.estado doc_estado, mdet.estado det_estado,
      --check 2
      (select min(mdet3.fec_vencimiento)
            from md_cta_documentos mdoc3, md_doc_detalles mdet3
            where mdoc3.cod_modalidad in (109,118)
            and mdet3.nro_cuenta= mdet.nro_cuenta
            and mdet3.mto_interes <> 0
            and mdet3.estado not in ('N','S')) venc_gral,
      mdet.fec_vencimiento venc_registro,
      --check 3
      (select max(mv3.fec_ult_devengado)
                                           from md_devengados mv3
                                           where mv3.nro_cuenta = mdet.nro_cuenta) fec_ult_dev2,
      fug_obt_plz_contable(mdoc.fec_vencimiento - mdoc.fec_inicio) plazo,
      mdoc.fec_vencimiento fec_vencimiento,
      mdoc.fec_inicio fec_inicio
      from ge_cta_clientes gcli, md_cta_documentos mdoc, md_doc_detalles mdet
      where gcli.relacion = 'P'
      and mdoc.nro_cuenta= gcli.nro_cuenta
      and mdoc.cod_modalidad in (109,118)
      and mdoc.nro_cuenta= mdet.nro_cuenta
      and mdet.mto_interes <> 0
      and mdet.estado not in ('N','S');

  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'Prestamo_Exterior'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;


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

  -- Variables de fecha
  v_fecha            varchar2(8);

BEGIN

 select to_char(pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1),'DDMMYYYY') into v_fecha
   from dual;

-- Abrir archivo
v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'_'||v_fecha||'.txt','W',32767);

-- Colocar el titulo a los campos
v_linetit := 'PREFNUMCLI'||CHR(9)||'PREFTIPOPR'||CHR(9)||'PREFNRO'||CHR(9)||'PREFTIPOR'||CHR(9)||
             'PREFTIPOCL'||CHR(9)||'PREFMONEDA'||CHR(9)||'PREFVTO'||CHR(9)||'PREFMONTO'||CHR(9)||
             'PREFSUC'||CHR(9)||'PREFCUENTA'||CHR(9)||'PREFFEINI'||CHR(9)||
             'PREFDEVENG'||CHR(9)||'PREFCHCONT'||CHR(9)||'PREFTASA'||CHR(9)||
             'DOC_ULT_PAGO'||CHR(9)||'DET_ULT_PAGO'||CHR(9)||'MTO_CAPITAL'||CHR(9)||
             'DOC_ESTADO'||CHR(9)||'DET_ESTADO'||CHR(9)||'VENC_GRAL'||CHR(9)||
             'VENC_REGISTRO'||CHR(9)||'FEC_ULT_DEV2'||CHR(9)||'PLAZO'||CHR(9)||
             'FEC_VTO'||CHR(9)||'FEC_INICIO';

utl_file.put_line(v_file,v_linetit);

-- Definir una linea en blanco para separar los datos del titulo de los campos
v_linetit := ' ';
utl_file.put_line(v_file,v_linetit);

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN cu_pres_ext LOOP

    --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
  v_line := to_char(rec.prefnumcli)||chr(9)||to_char(rec.preftipopr)||chr(9)||to_char(rec.prefnro)||chr(9)||
             to_char(rec.preftipor)||chr(9)||to_char(rec.preftipocl)||chr(9)||
            to_char(rec.prefmoneda)||chr(9)||to_char(rec.prefvto)||chr(9)||
            to_char(rec.prefmonto)||chr(9)||to_char(rec.prefsuc)||chr(9)||
            to_char(rec.prefcuenta)||chr(9)||to_char(rec.preffeini)||chr(9)||to_char(rec.prefdeveng)||chr(9)||
            to_char(rec.prefchcont)||chr(9)||to_char(rec.preftasa)||chr(9)||to_char(rec.doc_ult_pago)||chr(9)||
            to_char(rec.det_ult_pago)||chr(9)||to_char(rec.mto_capital)||chr(9)||
            to_char(rec.doc_estado)||chr(9)||to_char(rec.det_estado)||chr(9)||to_char(rec.venc_gral)||chr(9)||
            to_char(rec.venc_registro)||chr(9)||to_char(rec.fec_ult_dev2)||chr(9)||
            to_char(rec.plazo)||chr(9)||to_char(rec.fec_vencimiento)||chr(9)||to_char(rec.fec_inicio);


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

  EXIT WHEN cu_pres_ext%NOTFOUND;
END LOOP;
--Escribes la linea en el fichero
UTL_FILE.PUT_LINE(v_file, v_buffer);

--Cerrar el handler al fichero
UTL_FILE.FCLOSE(v_file);
COMMIT;

  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_respuesta := pa_file_ftp.fu_put_ascii(pa_rpc_aut.g_ip, pa_rpc_aut.g_port, pa_rpc_aut.g_user,
                                          pa_rpc_aut.g_pass, pa_rpc_aut.g_repository,
                                          v_name||'_'||v_fecha||'.txt', g_contabilidad||v_name||'_'||v_fecha||'.txt');

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','INV_PRES_EXT');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte de Préstamos del Exterior de fecha '||v_fecha||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_contabilidad||'

    Nombre del Archivo: '||v_name||'_'||v_fecha||'.txt';

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error    := null;

    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, v_name||'_'||v_fecha||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;

    --Enviamos el mail a soporte
     -- Obtenemos direccion de correo de soporte
     v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error de Préstamos del Exterior de fecha '||v_fecha||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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

END pr_gen_pres_ext;


--------------------------
----------------------------------------------------------------------------------------------------------------------------------------
-- REPORTE DE CUADRE BALANCE GENERAL
--------------------------
PROCEDURE pr_cua_invcon
IS
CURSOR CU_CUA_INVCON IS
    select cod_rubro, cod_rub_externo,t.rubro,cuenta,sub_cuenta,producto,
           nombre_rubro, cod_oficina,des_oficina,mon,moneda,tot_inventario,
           sal_contable, diferencia,t.clasificacion, t.tipo
        from bv_cua_contable t
       order by 7, 1;


  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'cua_invcon'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_fec_sist         DATE;
  v_fecha            VARCHAR2(8);
  v_mes              VARCHAR2(2);

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
  select pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1)
  into v_fec_sist
  from dual;

  v_fecha := to_char(v_fec_sist,'DDMMYYYY');
  v_mes := to_char(v_fec_sist,'MM');

-- Abrir archivo
v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'.txt','W',32767);

-- Colocar el titulo a los campos
v_linetit := 'COD_RUBRO'||CHR(9)||'COD_RUB_EXTERNO'||CHR(9)||'RUBRO'||CHR(9)||'CUENTA'||CHR(9)||'SUB_CUENTA'||CHR(9)||'PRODUCTO'||CHR(9)||'NOMBRE_RUBRO'||CHR(9)||'COD_OFICINA'||CHR(9)||
    'DES_OFICINA'||CHR(9)||'MON'||CHR(9)||'MONEDA'||CHR(9)||'TOT_INVENTARIO'||CHR(9)||'SAL_CONTABLE'||CHR(9)||'DIFERENCIA'||CHR(9)||'CLASIFICACION'||CHR(9)||
    'TIPO';

utl_file.put_line(v_file,v_linetit);

-- Definir una linea en blanco para separar los datos del titulo de los campos
v_linetit := ' ';
utl_file.put_line(v_file,v_linetit);

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN CU_CUA_INVCON LOOP

    --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
  v_line := to_char(rec.cod_rubro)||chr(9)||to_char(rec.cod_rub_externo)||chr(9)||to_char(rec.rubro)||chr(9)||to_char(rec.cuenta)||chr(9)||to_char(rec.sub_cuenta)||chr(9)||to_char(rec.producto)||chr(9)||to_char(rec.nombre_rubro)||chr(9)||to_char(rec.cod_oficina)||chr(9)||
    to_char(rec.des_oficina)||chr(9)||to_char(rec.mon)||chr(9)||to_char(rec.moneda)||chr(9)||to_char(rec.tot_inventario,'99999999999999999D00')||chr(9)||to_char(rec.sal_contable,'99999999999999999D00')||chr(9)||to_char(rec.diferencia,'99999999999999999D00')||chr(9)||to_char(rec.clasificacion)||chr(9)||
    to_char(rec.tipo);

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

   EXIT WHEN CU_CUA_INVCON%NOTFOUND;
END LOOP;
--Escribes la linea en el fichero
UTL_FILE.PUT_LINE(v_file, v_buffer);

--Cerrar el handler al fichero
UTL_FILE.FCLOSE(v_file);
COMMIT;

  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_respuesta := pa_file_ftp.fu_put_ascii(pa_rpc_aut.g_ip, pa_rpc_aut.g_port,
   pa_rpc_aut.g_user,pa_rpc_aut.g_pass, pa_rpc_aut.g_repository,
   v_name||'.txt', g_contabilidad||v_name||'_'||v_fecha||'.txt');

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el mail
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','CUADRE_BALANCE_GENERAL');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte reporte de CUADRE BALANCE GENERAL a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_contabilidad||'

    Nombre del Archivo: '||v_name||'_'||v_fecha||'.txt';

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error    := null;

    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, v_name||'_'||v_fecha||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;

    --Enviamos el mail a soporte
     -- Obtenemos direccion de correo de soporte
     v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error Reporte de CUADRE BALANCE GENERAL '||v_fec_sist||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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
    RAISE_APPLICATION_ERROR(-20062,'Manejador invalido');
  WHEN UTL_FILE.WRITE_ERROR THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20063,'Error de escritura '||sqlerrm);
  WHEN UTL_FILE.INVALID_MODE THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20064,'Modo invalido');
  WHEN UTL_FILE.INTERNAL_ERROR THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20065,'Internal Error');
END pr_cua_invcon;
--------------------------
----------------------------------------------------------------------------------------------------------------------------------------
-- REPORTE DE ENC_ASCII
--------------------------
PROCEDURE pr_enc_ascii
IS
CURSOR CU_ENC_CIRCULAR IS
    select archivo from sv_enc_circular254;


  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'enc_ascii'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_fec_sist         DATE;
  v_fecha            VARCHAR2(8);
  v_mes              VARCHAR2(2);

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
  select pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1)
  into v_fec_sist
  from dual;

  v_fecha := to_char(v_fec_sist,'DDMMYYYY');
  v_mes := to_char(v_fec_sist,'MM');

-- Abrir archivo
v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'.txt','W',32767);

-- Colocar el titulo a los campos
v_linetit := 'ARCHIVO';

utl_file.put_line(v_file,v_linetit);

-- Definir una linea en blanco para separar los datos del titulo de los campos
v_linetit := ' ';
utl_file.put_line(v_file,v_linetit);

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN CU_ENC_CIRCULAR LOOP

    --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
  v_line := to_char(rec.archivo);

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

   EXIT WHEN CU_ENC_CIRCULAR%NOTFOUND;
END LOOP;
--Escribes la linea en el fichero
UTL_FILE.PUT_LINE(v_file, v_buffer);

--Cerrar el handler al fichero
UTL_FILE.FCLOSE(v_file);
COMMIT;

  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_respuesta := pa_file_ftp.fu_put_ascii(pa_rpc_aut.g_ip, pa_rpc_aut.g_port,
   pa_rpc_aut.g_user,pa_rpc_aut.g_pass, pa_rpc_aut.g_repository,
   v_name||'.txt', g_contabilidad||v_name||'_'||v_fecha||'.txt');

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el mail
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','ENC_ASCII');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte de enc_ascii a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_contabilidad||'

    Nombre del Archivo: '||v_name||'_'||v_fecha||'.txt';

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error    := null;

    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, v_name||'_'||v_fecha||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;

    --Enviamos el mail a soporte
     -- Obtenemos direccion de correo de soporte
     v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error Reporte de enc_ascii '||v_fec_sist||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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
    RAISE_APPLICATION_ERROR(-20062,'Manejador invalido');
  WHEN UTL_FILE.WRITE_ERROR THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20063,'Error de escritura '||sqlerrm);
  WHEN UTL_FILE.INVALID_MODE THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20064,'Modo invalido');
  WHEN UTL_FILE.INTERNAL_ERROR THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20065,'Internal Error');
END pr_enc_ascii;

---------------------------Conciliación Automática
PROCEDURE pr_con_automatica
IS
CURSOR CU_CON_AUTOMATICA IS
select fecha,hora,cod_usuario,nro_secuencia,nro_cuenta,
       monto,cod_moneda,mto_equ_local,cotizacion,cod_oficina,cod_ofi_origen,
       concepto,nro_documento,cod_transaccion,cod_modulo,cod_modalidad,
       nro_documento4,nro_asiento,nro_linea,descripcion,reversado,
       cod_rubro,tip_mov,fec_conciliacion, mov_cuadre,conciliado
FROM (
select d.fecha,d.hora,d.cod_usuario,d.nro_secuencia,d.nro_cuenta,d.monto,d.cod_moneda,
       d.mto_equ_local,d.cotizacion,d.cod_oficina,d.cod_ofi_origen,d.concepto,
       d.nro_documento,d.cod_transaccion,d.cod_modulo,d.cod_modalidad,
       d.nro_documento4,d.nro_asiento,d.nro_linea,d.descripcion,
       d.reversado,d.cod_rubro,d.tip_mov,null fec_conciliacion,
       d.mov_cuadre,'N'conciliado
  from cb_con_rub_det d
 where cod_rubro IN ('240402600206099','150102570206099')
 union all

select d.fecha,d.hora,d.cod_usuario,d.nro_secuencia,m.nro_cuenta,m.monto,m.cod_moneda,
       m.mto_equ_local,m.cotizacion,m.cod_oficina,m.cod_ofi_origen,m.concepto,
       m.nro_documento,m.cod_transaccion,m.cod_modulo,m.cod_modalidad,
       m.nro_documento4,c.nro_asiento,c.nro_linea,c.descripcion,
       m.reversado,d.cod_rubro,c.tip_movimiento,
       d.fec_conciliacion,d.mov_cuadre,
       'S'conciliado
  from cb_con_rub_det_his d,
  (select mo.fecha,mo.hora,mo.cod_usuario,mo.nro_secuencia,mo.fec_valor,mo.monto,
          mo.nro_cuenta, mo.cod_moneda, mo.cod_oficina, mo.cod_error,mo.cod_retencion,
          mo.fec_fin_retencion, mo.est_cuenta, mo.estado,
          mo.cod_causa, mo.cod_banco, mo.cod_ofi_origen, mo.concepto, mo.cod_tasa,
          mo.val_tasa, mo.cod_rubro, mo.cod_ref_cambio, mo.reversado, mo.cod_usu_reversion,
          mo.hor_reversion, mo.emi_aviso, mo.cod_tra_padre, mo.cod_mod_padre, mo.cod_mad_padre,
          mo.cod_transaccion, mo.cod_modulo, mo.cod_modalidad, mo.mto_equ_local, mo.nro_caja,
          mo.cotizacion, mo.cod_bco_central, mo.nro_documento, mo.nro_documento2,
          mo.nro_documento3,mo.nro_documento4, mo.protegido, mo.tip_mov_rubro,
          mo.cod_autorizacion, mo.cod_usu_autorizador,
          mo.usu_insercion, mo.fec_insercion, mo.usu_modificacion,
          mo.fec_modificacion, mo.cod_tip_ope_cambio,
          to_number(null) nro_folio, mo.referencia,
          'h' tipo, -- historico
          'historico' des_tipo,
          mo.cod_persona cod_persona,
          mo.cod_sit_contable cod_sit_contable,
          null nro_conciliacion
    from TA_MOVIMIENTOS_HIS MO ) m , cb_asi_automaticos_det c
   where d.fecha=m.FECHA
     and d.hora=m.HORA
     and d.cod_usuario=m.COD_USUARIO
     and d.nro_secuencia=m.NRO_SECUENCIA
     and m.FECHA=c.fecha
     and m.NRO_DOCUMENTO4=c.ref_movimiento
     and d.cod_rubro=c.cod_rubro
     and D.cod_rubro IN ('240402600206099','150102570206099')) vc
   where nvl(conciliado,' ') IN ('N','S')
     and cod_moneda = 'GS'
     and fecha = pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1)-1 ;

  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'INV_CON_TARJETAS'; --nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_fec_sist         DATE;
  v_fecha            VARCHAR2(8);
  v_mes              VARCHAR2(2);

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
  select pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1)
  into v_fec_sist
  from dual;

  v_fecha := to_char(v_fec_sist,'DDMMYYYY');
  v_mes := to_char(v_fec_sist,'MM');

-- Abrir archivo
v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'.txt','W',32767);

-- Colocar el titulo a los campos
v_linetit := 'FECHA'||CHR(9)||'HORA'||CHR(9)||
'COD_USUARIO'||CHR(9)||   'NRO_SECUENCIA'||CHR(9)||
'NRO_CUENTA' ||CHR(9)||   'MONTO'||CHR(9)||
'COD_MONEDA' ||CHR(9)||   'MTO_EQU_LOCAL'||CHR(9)||
'COTIZACION' ||CHR(9)||   'COD_OFICINA'||CHR(9)||
'COD_OFI_ORIGEN'||CHR(9)||'CONCEPTO'||CHR(9)||
'NRO_DOCUMENTO'||CHR(9)|| 'COD_TRANSACCION'||CHR(9)||
'COD_MODULO'||CHR(9)||    'COD_MODALIDAD'||CHR(9)||
'NRO_DOCUMENTO4'||CHR(9)||'NRO_ASIENTO'||CHR(9)||
'NRO_LINEA' ||CHR(9)||    'DESCRIPCION'||CHR(9)||
'REVERSADO' ||CHR(9)||    'COD_RUBRO'||CHR(9)||
'TIP_MOV'   ||CHR(9)||    'FEC_CONCILIACION'||CHR(9)||
'MOV_CUADRE'||CHR(9)||    'CONCILIADO';

utl_file.put_line(v_file,v_linetit);

-- Definir una linea en blanco para separar los datos del titulo de los campos
v_linetit := ' ';
utl_file.put_line(v_file,v_linetit);

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN CU_CON_AUTOMATICA LOOP

    --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
v_line := to_char(rec.FECHA)||chr(9)||
          to_char(rec.HORA)||chr(9)||
          to_char(rec.COD_USUARIO)||chr(9)||
          to_char(rec.NRO_SECUENCIA)||chr(9)||
          to_char(rec.NRO_CUENTA)||chr(9)||
          to_char(rec.MONTO)||chr(9)||
          to_char(rec.COD_MONEDA)||chr(9)||
          to_char(rec.MTO_EQU_LOCAL)||chr(9)||
          to_char(rec.COTIZACION)||chr(9)||
          to_char(rec.COD_OFICINA)||chr(9)||
          to_char(rec.COD_OFI_ORIGEN)||chr(9)||
          to_char(rec.CONCEPTO)||chr(9)||
          to_char(rec.NRO_DOCUMENTO)||chr(9)||
          to_char(rec.COD_TRANSACCION)||chr(9)||
          to_char(rec.COD_MODULO)||chr(9)||
          to_char(rec.COD_MODALIDAD)||chr(9)||
          to_char(rec.NRO_DOCUMENTO4)||chr(9)||
          to_char(rec.NRO_ASIENTO)||chr(9)||
          to_char(rec.NRO_LINEA)||chr(9)||
          to_char(rec.DESCRIPCION)||chr(9)||
          to_char(rec.REVERSADO)||chr(9)||
          to_char(rec.COD_RUBRO)||chr(9)||
          to_char(rec.TIP_MOV)||chr(9)||
          to_char(rec.FEC_CONCILIACION)||chr(9)||
          to_char(rec.MOV_CUADRE)||chr(9)||
          to_char(rec.CONCILIADO);

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

   EXIT WHEN CU_CON_AUTOMATICA%NOTFOUND;
END LOOP;
--Escribes la linea en el fichero
UTL_FILE.PUT_LINE(v_file, v_buffer);

--Cerrar el handler al fichero
UTL_FILE.FCLOSE(v_file);
COMMIT;

  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_respuesta := pa_file_ftp.fu_put_ascii(pa_rpc_aut.g_ip, pa_rpc_aut.g_port,
   pa_rpc_aut.g_user,pa_rpc_aut.g_pass, pa_rpc_aut.g_repository,
   v_name||'.txt',g_conciliaciones||v_name||'_'||v_fecha||'.txt');

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el mail
  v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','INV_CON_TARJETAS');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte de CUADRE BALANCE GENERAL a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_conciliaciones||'

    Nombre del Archivo: '||v_name||'_'||v_fecha||'.txt';

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error    := null;

    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, v_name||'_'||v_fecha||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;

    --Enviamos el mail a soporte
     -- Obtenemos direccion de correo de soporte
     v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','INV_CON_TARJETAS');

    -- Damos valor a los demas datos
      v_asunto := 'Error Reporte de CUADRE BALANCE GENERAL '||v_fec_sist||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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
    RAISE_APPLICATION_ERROR(-20062,'Manejador invalido');
  WHEN UTL_FILE.WRITE_ERROR THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20063,'Error de escritura '||sqlerrm);
  WHEN UTL_FILE.INVALID_MODE THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20064,'Modo invalido');
  WHEN UTL_FILE.INTERNAL_ERROR THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20065,'Internal Error');
END pr_con_automatica;
---------------------------Conciliación Automática

--------------------------------
-- CTAS TRANSITORIAS
--------------------------------
procedure pr_ctas_trnsitorias
IS
CURSOR cu_datos(p_fec_proceso date) IS
 select x.fecha,
       x.hora,
       x.cod_usuario,
       x.nro_secuencia,
       x.nro_cuenta,
       x.monto,
       x.cod_moneda,
       x.mto_mon_local,
       x.COTIZACION,
       x.cod_oficina,
       x.COD_OFI_ORIGEN,
       ltrim(rtrim(x.concepto,'"'),'"') concepto,
       x.nro_documento,
       x.cod_transaccion,
       x.cod_modulo,
       x.cod_modalidad,
       x.NRO_DOCUMENTO4,
       x.nro_asiento,
       x.nro_linea,
       ltrim(rtrim(x.descripcion,'"'),'"') descripcion,
       x.reversado,
       x.cod_rubro,
       x.TIP_MOV,

       0 mov_cuadre
  from (select h.fecha,
               g.hora,
               g.cod_usuario,
               g.nro_secuencia,
               g.nro_cuenta,
               abs(g.monto) monto,
               g.cod_moneda,
               h.mto_mon_local,
               g.COTIZACION,
               h.cod_oficina,
               g.COD_OFI_ORIGEN,
               g.concepto,
               g.nro_documento,
               g.cod_transaccion,
               g.cod_modulo,
               g.cod_modalidad,
               g.NRO_DOCUMENTO4,
               h.nro_asiento,
               h.nro_linea,
               h.descripcion,
               g.reversado,
               h.cod_rubro,
               h.tip_movimiento TIP_MOV,
               0 mov_cuadre
          from gv_movimientos g, cb_asientos_det h, cb_asientos c
         where h.nro_asiento = c.nro_asiento
           and h.fecha = c.fecha
           and h.cod_oficina = c.cod_oficina
           and g.FECHA = h.FECHA
           and g.NRO_DOCUMENTO4 = h.ref_movimiento
           and g.fecha=p_fec_proceso

        union
        select d.fecha,
               null,
               s.cod_usuario,
               null,
               null,
               case
                 when r.cod_moneda = 'GS' then
                  d.mto_mon_local
                 else
                  d.mto_mon_rubro
               end monto,
               r.cod_moneda,
               d.mto_mon_local,
               null,
               d.cod_oficina,
               null,
               d.descripcion,
               null,
               null,
               s.cod_modulo,
               s.cod_modalidad,
               d.ref_movimiento,
               d.nro_asiento,
               d.nro_linea,
               d.descripcion,
               s.reversado,
               d.cod_rubro,
               d.tip_movimiento,
               0 mov_cuadre
          from cb_rubros r, cb_asientos s, cb_asientos_det d
         where d.nro_asiento = s.nro_asiento
           and d.fecha = s.fecha
           and d.cod_oficina = s.cod_oficina
           and r.cod_rubro = d.cod_rubro
           and ((r.cod_moneda <> 'GS' and nvl(d.mto_mon_rubro,0) <> 0) or
               (r.cod_moneda = 'GS' and nvl(d.mto_mon_rubro,0) = 0))
           and s.nro_asi_automatico is null) x
where x.cod_rubro in(select r.cod_rubro from cb_cor_rubros r);


  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'CTAS_TRANSITORIAS'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_fec_sist         DATE;
  v_fecha            VARCHAR2(8);
  v_fec_proceso      DATE;

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
   select to_char(pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1),'DDMMYYYY') into v_fecha
   from dual;
   --Fecha para la cotizacion
   v_fec_proceso:=pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1);

-- Abrir archivo
v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'.txt','W',32767);

-- Colocar el titulo a los campos
v_linetit := 'FECHA'||CHR(9)||'HORA'||CHR(9)||'COD_USUARIO'||CHR(9)||'NRO_SECUENCIA'||CHR(9)||
             'NRO_CUENTA'||CHR(9)||'MONTO'||CHR(9)||'COD_MONEDA'||CHR(9)||'MTO_MON_LOCAL'||CHR(9)||
             'COTIZACION'||CHR(9)||'COD_OFICINA'||CHR(9)||'COD_OFI_ORIGEN'||CHR(9)||'CONCEPTO'||CHR(9)||'NRO_DOCUMENTO'
             ||CHR(9)||'COD_TRANSACCION'||CHR(9)||'COD_MODULO'||CHR(9)||'COD_MODALIDAD'||CHR(9)||'NRO_DOCUMENTO4'
             ||CHR(9)||'NRO_ASIENTO'||CHR(9)||'NRO_LINEA'||CHR(9)||'DESCRIPCION'||CHR(9)||'REVERSADO'||CHR(9)||'COD_RUBRO'
             ||CHR(9)||'TIP_MOV'||CHR(9)||'MOV_CUADRE';


utl_file.put_line(v_file,v_linetit);

-- Definir una linea en blanco para separar los datos del titulo de los campos
v_linetit := ' ';
utl_file.put_line(v_file,v_linetit);

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN cu_datos(v_fec_proceso) LOOP

    --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
  v_line := to_char(rec.FECHA)          ||chr(9)||to_char(rec.HORA)           ||chr(9)||
            to_char(rec.COD_USUARIO)    ||chr(9)||to_char(rec.NRO_SECUENCIA)  ||chr(9)||
            to_char(rec.NRO_CUENTA)     ||chr(9)||to_char(rec.MONTO,'999999999999999999D00')||chr(9)||
            to_char(rec.COD_MONEDA)     ||chr(9)||to_char(rec.MTO_MON_LOCAL,'999999999999999999D00')||chr(9)||

            to_char(rec.COTIZACION,'999999999999999999D00')||chr(9)||to_char(rec.COD_OFICINA)||chr(9)||

            to_char(rec.COD_OFI_ORIGEN) ||chr(9)||to_char(rec.CONCEPTO)       ||chr(9)||
            to_char(rec.NRO_DOCUMENTO)  ||chr(9)||to_char(rec.COD_TRANSACCION)||chr(9)||
            to_char(rec.COD_MODULO)     ||chr(9)||to_char(rec.COD_MODALIDAD)  ||chr(9)||
            to_char(rec.NRO_DOCUMENTO4) ||chr(9)||to_char(rec.NRO_ASIENTO)    ||chr(9)||
            to_char(rec.NRO_LINEA)      ||chr(9)||to_char(rec.DESCRIPCION)    ||chr(9)||
            to_char(rec.REVERSADO)      ||chr(9)||to_char(rec.COD_RUBRO)      ||chr(9)||
            to_char(rec.TIP_MOV)        ||chr(9)||to_char(rec.MOV_CUADRE);

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

   EXIT WHEN cu_datos%NOTFOUND;
END LOOP;
--Escribes la linea en el fichero
UTL_FILE.PUT_LINE(v_file, v_buffer);

--Cerrar el handler al fichero
UTL_FILE.FCLOSE(v_file);
COMMIT;

  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_respuesta := pa_file_ftp.fu_put_ascii(pa_rpc_aut.g_ip, pa_rpc_aut.g_port, pa_rpc_aut.g_user,
                                          pa_rpc_aut.g_pass, pa_rpc_aut.g_repository,
                                          v_name||'.txt', g_contabilidad||v_name||'_'||v_fecha||'.txt');

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','CTAS_TRANSITORIAS');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte de CTAS_TRANSITORIAS'||v_fec_sist||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_contabilidad||'

    Nombre del Archivo: '||v_name||'_'||v_fecha||'.txt';

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error    := null;

    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, v_name||'_'||v_fecha||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;

    --Enviamos el mail a soporte
     -- Obtenemos direccion de correo de soporte
     v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error Reporte de CTAS_TRANSITORIAS'||v_fec_sist||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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
    RAISE_APPLICATION_ERROR(-20062,'Manejador invalido');
  WHEN UTL_FILE.WRITE_ERROR THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20063,'Error de escritura '||sqlerrm);
  WHEN UTL_FILE.INVALID_MODE THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20064,'Modo invalido');
  WHEN UTL_FILE.INTERNAL_ERROR THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20065,'Internal Error');
END pr_ctas_trnsitorias;-------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------
-- Informe diario de apuntes y asientos manuales
PROCEDURE pr_apu_masivos
IS
CURSOR cu_renta IS
select h.fecha,h.hora,h.cod_oficina,h.cod_usuario,h.cod_modulo,h.cod_modalidad,
             h.monto mto_origen,h.mto_equ_local,h.cod_moneda, h.nro_cuenta,
             h.cod_tra_padre,
             h.concepto,h.nro_documento4,d.tip_movimiento,d.cod_rubro
      from ge_movimientos h, cb_asientos_det d
      where h.fecha=d.fecha
      and h.nro_documento4=d.ref_movimiento
      and h.cod_tra_padre=100
      --cuentas corrientes apuntes masivos
      union
      select h.fecha,h.hora,h.cod_oficina,h.cod_usuario,h.cod_modulo,h.cod_modalidad,
             h.monto mto_origen,h.mto_equ_local,h.cod_moneda, h.nro_cuenta,h.cod_tra_padre,
             h.concepto,h.nro_documento4,d.tip_movimiento,d.cod_rubro
      from cc_movimientos_his h, cb_asientos_det d
      where h.fecha=d.fecha
      and h.nro_documento4=d.ref_movimiento
      and h.cod_tra_padre=100
      and h.cod_mod_padre=2
      and h.cod_mad_padre=21
      union
      --ctas ahorros apuntes masivos
      select h.fecha,h.hora,h.cod_oficina,h.cod_usuario,h.cod_modulo,h.cod_modalidad,
             h.monto mto_origen,h.mto_equ_local,h.cod_moneda, h.nro_cuenta,h.cod_tra_padre,
             h.concepto,h.nro_documento4,d.tip_movimiento,d.cod_rubro
      from ah_movimientos_his h, cb_asientos_det d
      where h.fecha=d.fecha
      and h.nro_documento4=d.ref_movimiento
      and h.cod_tra_padre=100
      and h.cod_mod_padre=2
      and h.cod_mad_padre=21
      --asientos masivos
      union
      select d.fecha,null,d.cod_oficina,h.cod_usuario,h.cod_modulo,h.cod_modalidad,
             d.mto_mon_rubro monto_origen,
             d.mto_mon_local, r.cod_moneda,null,null,
             d.descripcion,d.ref_movimiento, d.tip_movimiento,d.cod_rubro
      from cb_asientos_det d, cb_rubros r, cb_asientos h
      where r.cod_rubro=d.cod_rubro
      and d.fecha=h.fecha
      and d.cod_oficina=h.cod_oficina
      and d.nro_asiento=h.nro_asiento
      and (h.nro_asi_automatico is null and h.nro_asi_futuro is null);

  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'APU_MASIVOS'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_fecha            VARCHAR2(8);

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
  -- Obtenemos la fecha del último fin de mes
  select to_char(pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1),'DDMMYYYY') into v_fecha
   from dual;

-- Abrir archivo
v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name,'W',32767);
-- Colocar el titulo a los campos
v_linetit := 'FECHA'||CHR(9)||'HORA'||CHR(9)||'COD_OFICINA'||CHR(9)||'COD_USUARIO'||CHR(9)||
             'COD_MODULO'||CHR(9)||'COD_MODALIDAD'||CHR(9)||'MTO_ORIGEN'||CHR(9)||'MTO_EQ_LOCAL'||CHR(9)||
             'MONEDA'||CHR(9)||'NRO_CUENTA'||CHR(9)||'COD_TRA_PADRE'||CHR(9)||'CONCEPTO'||CHR(9)||
             'NRO_DOCUMENTO4'||CHR(9)||'TIP_MOV'||CHR(9)||'COD_RUBRO';

utl_file.put_line(v_file,v_linetit);

-- Definir una linea en blanco para separar los datos del titulo de los campos
v_linetit := ' ';
utl_file.put_line(v_file,v_linetit);

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN cu_renta LOOP

    --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
   v_line := to_char(rec.Fecha)||chr(9)||to_char(rec.hora)||chr(9)||
            to_char(rec.cod_oficina)||chr(9)||to_char(rec.cod_usuario)||chr(9)||
            to_char(rec.cod_modulo)||chr(9)||to_char(rec.cod_modalidad)||chr(9)||to_char(rec.mto_origen,'999999999999999999D00')||chr(9)||
            to_char(rec.mto_equ_local,'999999999999999999D00')||chr(9)||to_char(rec.cod_moneda)||chr(9)||
            to_char(rec.nro_cuenta)||chr(9)||to_char(rec.cod_tra_padre)||chr(9)||to_char(rec.concepto)||chr(9)||
            to_char(rec.nro_documento4)||chr(9)||to_char(rec.tip_movimiento)||to_char(rec.cod_rubro);


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

  EXIT WHEN cu_renta%NOTFOUND;
END LOOP;
--Escribes la linea en el fichero
UTL_FILE.PUT_LINE(v_file, v_buffer);

--Cerrar el handler al fichero
UTL_FILE.FCLOSE(v_file);
COMMIT;

  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_respuesta := pa_file_ftp.fu_put_ascii(pa_rpc_aut.g_ip, pa_rpc_aut.g_port, pa_rpc_aut.g_user,
                                          pa_rpc_aut.g_pass, pa_rpc_aut.g_repository,
                                          v_name, g_contabilidad||v_name||'_'||v_fecha);

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','APU_MASIVOS');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte APU_MASIVOS a la fecha '||v_fecha||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_contabilidad||'

    Nombre del Archivo: '||v_name||'_'||v_fecha;

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha, v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error    := null;

    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, v_name||'_'||v_fecha, v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;

    --Enviamos el mail a soporte
     -- Obtenemos direccion de correo de soporte
     v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error Reporte APU_MASIVOS a la fecha '||v_fecha||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha, v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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
END pr_apu_masivos;


------------------------pr_lib_ventas1_det----------------------------
PROCEDURE pr_lib_ventas1_det
IS
CURSOR cu_lib_venta(p_fecha_des DATE, p_fecha_has DATE) IS

select d.nro_factura, d.nro_timbrado,d.cod_oficina,
       d.fecha FEC_FACT,cd.fecha fec_movimiento,cd.hora,cd.cod_usuario,cd.descripcion,
       cd.cod_moneda,decode(substr(cd.nro_factura,5,3),'011',
       (nvl(cd.impuesto_5_gs,0)+ nvl(cd.impuesto_10_gs,0))*-1,
       (nvl(cd.impuesto_5_gs,0)+nvl(cd.impuesto_10_gs,0))) IVA,
       a.nro_asiento,a.nro_linea
  from gv_movimientos m
   ,cb_lib_ventas d
   ,cb_lib_ventas_det cd
   ,cb_asientos_det_his a
   ,cb_asientos_his c
   where cd.fecha between p_fecha_des and p_fecha_has
   and d.nro_factura= cd.nro_factura
   and d.nro_timbrado= cd.nro_timbrado
   and m.NRO_DOCUMENTO4=a.ref_movimiento--movimientos con asientos
   and m.fecha=a.fecha--movimientos con asientos
   and m.fecha = cd.fecha
   and m.hora = cd.hora
   and m.cod_usuario = cd.cod_usuario
   and m.nro_secuencia = cd.nro_secuencia
   and m.fecha=a.fecha
   and a.fecha=c.fecha
   and a.cod_oficina=c.cod_oficina
   and a.nro_asiento=c.nro_asiento
   and a.cod_rubro not in ('142102050200199'/*DEUDORES POR UTILIZACION DE TC-RESIDENTE*/,
                           '221101360200105'/*CUENTAS CORRIENTES M/E - DOLARES*/,
                           '142102050200199'/*DEUDORES POR UTILIZACION DE TC-RESIDENTE*/);

  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'LIBRO_VENTA1_ASI'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_fec_sist         DATE;
  v_fecha            VARCHAR2(8);
  v_dia_ini          DATE;
  v_dia_fin          DATE;

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
  select pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1)
  into v_fec_sist
  from dual;

  v_fecha := to_char(v_fec_sist,'DDMMYYYY');

  --Obtenemos el primer dia y el ultimo dia del mes
  v_dia_ini := trunc(v_fec_sist,'month');
  v_dia_fin := trunc(last_day(v_fec_sist));

-- Abrir archivo
v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'.txt','W',32767);



-- Colocar el titulo a los campos
  v_linetit := 'NRO_FACTURA'||CHR(9)||
               'NRO_TIMBRADO'||CHR(9)||
               'COD_OFICINA'||CHR(9)||
               'FEC_FACT'||CHR(9)||
               'FEC_MOVIMIENTO'||CHR(9)||
               'HORA'||CHR(9)||
               'COD_USUARIO'||CHR(9)||
               'DESCRIPCION'||CHR(9)||
               'COD_MONEDA'||CHR(9)||
               'IVA'||CHR(9)||
               'NRO_ASIENTO'||CHR(9)||
               'NRO_LINEA';

utl_file.put_line(v_file,v_linetit);

-- Definir una linea en blanco para separar los datos del titulo de los campos
v_linetit := ' ';
utl_file.put_line(v_file,v_linetit);

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN cu_lib_venta(v_dia_ini, v_dia_fin) LOOP

--Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))

  v_line := to_char(rec.nro_factura)||chr(9)||
            to_char(rec.nro_timbrado)||chr(9)||
            to_char(rec.cod_oficina)||chr(9)||
            to_char(rec.fec_fact)||chr(9)||
            to_char(rec.fec_movimiento)||chr(9)||
            to_char(rec.hora)||chr(9)||
            to_char(rec.cod_usuario)||chr(9)||
            to_char(rec.descripcion)||chr(9)||
            to_char(rec.cod_moneda)||chr(9)||
            to_char(rec.iva)||chr(9)||
            to_char(rec.nro_asiento)||chr(9)||
            to_char(rec.nro_linea);

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

  EXIT WHEN cu_lib_venta%NOTFOUND;
END LOOP;
--Escribes la linea en el fichero
UTL_FILE.PUT_LINE(v_file, v_buffer);

--Cerrar el handler al fichero
UTL_FILE.FCLOSE(v_file);
COMMIT;

  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_respuesta := pa_file_ftp.fu_put_ascii(pa_rpc_aut.g_ip, pa_rpc_aut.g_port,
  pa_rpc_aut.g_user,pa_rpc_aut.g_pass, pa_rpc_aut.g_repository,v_name||'.txt', g_amaral||v_name||'_'||v_fecha||'.txt');

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','LIBRO_VENTA1_ASI');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte Libro de Ventas1 con asiento/linea a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_amaral||'

    Nombre del Archivo: '||v_name||'_'||v_fecha||'.txt';

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error    := null;

    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, v_name||'_'||v_fecha||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;

    --Enviamos el mail a soporte
     -- Obtenemos direccion de correo de soporte
     v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error Reporte Libro de Ventas a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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
END pr_lib_ventas1_det;
------------------------pr_lib_ventas1_det----------------------------


------------------------pr_lib_ventas3_det----------------------------

PROCEDURE pr_lib_ventas3_det
IS
CURSOR cu_lib_venta(p_fecha_des DATE, p_fecha_has DATE) IS

select d.nro_factura, d.nro_timbrado, d.fecha, d.cod_persona, d.nom_completo,
       d.nro_documento, d.mto_gravado_5, d.mto_gravado_10, d.mto_gravado_5_gs,
       d.mto_gravado_10_gs, d.impuesto_5,d.impuesto_10, d.impuesto_5_gs,
       d.impuesto_10_gs,a.NRO_ASIENTO,a.NRO_LINEA
   from gv_movimientos m
   ,cb_lib_ventas d
   ,cb_lib_ventas_det cd
   ,cb_asientos_det_his a
   ,cb_asientos_his c
   where cd.fecha between p_fecha_des and p_fecha_has
   and d.nro_factura= cd.nro_factura
   and d.nro_timbrado= cd.nro_timbrado
   and m.NRO_DOCUMENTO4=a.ref_movimiento--movimientos con asientos
   and m.fecha=a.fecha--movimientos con asientos
   and m.fecha = cd.fecha
   and m.hora = cd.hora
   and m.cod_usuario = cd.cod_usuario
   and m.nro_secuencia = cd.nro_secuencia
   and m.fecha=a.fecha
   and a.fecha=c.fecha
   and a.cod_oficina=c.cod_oficina
   and a.nro_asiento=c.nro_asiento
   and a.cod_rubro not in ('142102050200199'/*DEUDORES POR UTILIZACION DE TC-RESIDENTE*/,
                           '221101360200105'/*CUENTAS CORRIENTES M/E - DOLARES*/,
                           '142102050200199'/*DEUDORES POR UTILIZACION DE TC-RESIDENTE*/);


  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'LIBRO_VENTA3_ASI'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_fec_sist         DATE;
  v_fecha            VARCHAR2(8);
  v_dia_ini          DATE;
  v_dia_fin          DATE;

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
  select pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1)
  into v_fec_sist
  from dual;

  v_fecha := to_char(v_fec_sist,'DDMMYYYY');

  --Obtenemos el primer dia y el ultimo dia del mes
  v_dia_ini := trunc(v_fec_sist,'month');
  v_dia_fin := trunc(last_day(v_fec_sist));

-- Abrir archivo
v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'.txt','W',32767);

-- Colocar el titulo a los campos
v_linetit := 'NRO_FACTURA'||CHR(9)||
             'NRO_TIMBRADO'||CHR(9)||
             'FECHA'||CHR(9)||
             'COD_PERSONA'||CHR(9)||
             'NOM_COMPLETO'||CHR(9)||
             'NRO_DOCUMENTO'||CHR(9)||
             'MTO_GRAVADO_5'||CHR(9)||
             'MTO_GRAVADO_10'||CHR(9)||
             'MTO_GRAVADO_5_GS'||CHR(9)||
             'MTO_GRAVADO_10_GS'||CHR(9)||
             'IMPUESTO_5'||CHR(9)||
             'IMPUESTO_10'||CHR(9)||
             'IMPUESTO_5_GS'||CHR(9)||
             'IMPUESTO_10_GS'||CHR(9)||
             'NRO_ASIENTO'||CHR(9)||
             'NRO_LINEA';

utl_file.put_line(v_file,v_linetit);

-- Definir una linea en blanco para separar los datos del titulo de los campos
v_linetit := ' ';
utl_file.put_line(v_file,v_linetit);

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN cu_lib_venta(v_dia_ini, v_dia_fin) LOOP

--Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))

  v_line := to_char(rec.nro_factura)||chr(9)||
            to_char(rec.nro_timbrado)||chr(9)||
            to_char(rec.fecha)||chr(9)||
            to_char(rec.cod_persona)||chr(9)||
            to_char(rec.nom_completo)||chr(9)||
            to_char(rec.nro_documento)||chr(9)||
            to_char(rec.mto_gravado_5,'999999999999D00')||chr(9)||
            to_char(rec.mto_gravado_10,'999999999999D00')||chr(9)||
            to_char(rec.mto_gravado_5_gs,'999999999999D00')||chr(9)||
            to_char(rec.mto_gravado_10_gs,'999999999999D00')||chr(9)||
            to_char(rec.impuesto_5,'999999999999D00')||chr(9)||
            to_char(rec.impuesto_10,'999999999999D00')||chr(9)||
            to_char(rec.impuesto_5_gs,'999999999999D00')||chr(9)||
            to_char(rec.impuesto_10_gs,'999999999999D00')||chr(9)||
            to_char(rec.nro_asiento)||chr(9)||
            to_char(rec.nro_linea);

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

  EXIT WHEN cu_lib_venta%NOTFOUND;
END LOOP;
--Escribes la linea en el fichero
UTL_FILE.PUT_LINE(v_file, v_buffer);

--Cerrar el handler al fichero
UTL_FILE.FCLOSE(v_file);
COMMIT;

  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_respuesta := pa_file_ftp.fu_put_ascii(pa_rpc_aut.g_ip, pa_rpc_aut.g_port,
  pa_rpc_aut.g_user,pa_rpc_aut.g_pass, pa_rpc_aut.g_repository,v_name||'.txt', g_amaral||v_name||'_'||v_fecha||'.txt');

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','LIBRO_VENTA3_ASI');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte Libro de Ventas3 con asiento/linea a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_amaral||'

    Nombre del Archivo: '||v_name||'_'||v_fecha||'.txt';

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error    := null;

    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, v_name||'_'||v_fecha||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;

    --Enviamos el mail a soporte
     -- Obtenemos direccion de correo de soporte
     v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error Reporte Libro de Ventas a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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
END pr_lib_ventas3_det;
------------------------pr_lib_ventas3_det----------------------------

------------------------pr_lib_compras4_det----------------------------
PROCEDURE pr_lib_compras4_det
IS
 CURSOR cu_lib_venta(p_fecha_des DATE, p_fecha_has DATE) IS
 select h.fecha, h.cod_oficina, h.nro_asiento, h.nro_linea,
        h.cod_rubro, h.descripcion, h.tip_movimiento,
        decode(h.tip_movimiento,'D',h.mto_mon_rubro*-1,h.mto_mon_rubro) mto_rubro,
        decode(h.tip_movimiento,'D',h.mto_mon_local*-1,h.mto_mon_local) mto_local,
        h.ref_movimiento,d.nro_factura,e.cod_persona riesgo
   from cc_movimientos_his g,
        cb_asientos_det_his h,
        cb_asientos_his c,
        cb_lib_ventas_det d,
        cb_lib_ventas e
  where h.nro_asiento = c.nro_asiento
    and h.fecha = c.fecha
    and h.cod_oficina = c.cod_oficina
    and e.nro_factura=d.nro_factura
    and e.nro_timbrado = d.nro_timbrado
    and g.NRO_DOCUMENTO4 = h.ref_movimiento
    and d.fecha = g.fecha(+)
    and d.hora = g.hora(+)
    and d.cod_usuario = g.cod_usuario
    and d.nro_cuenta = g.nro_cuenta
    and h.cod_rubro = '240102420101299' /*RETENCION IVA - AGENTE DE RETENCION*/
    and h.fecha between p_fecha_des and p_fecha_has
 union all
select h.fecha, h.cod_oficina, h.nro_asiento, h.nro_linea,
       h.cod_rubro, h.descripcion, h.tip_movimiento,
       decode(h.tip_movimiento,'D',h.mto_mon_rubro*-1,h.mto_mon_rubro) mto_rubro,
       decode(h.tip_movimiento,'D',h.mto_mon_local*-1,h.mto_mon_local) mto_local,
       h.ref_movimiento,d.nro_factura,e.cod_persona riesgo
  from ov_movimientos_his g,
       cb_asientos_det_his h,
       cb_asientos_his c,
       cb_lib_ventas_det d,
       cb_lib_ventas e
 where h.nro_asiento = c.nro_asiento
   and h.fecha = c.fecha
   and h.cod_oficina = c.cod_oficina
   and e.nro_factura=d.nro_factura
   and e.nro_timbrado = d.nro_timbrado
   and g.NRO_DOCUMENTO4 = h.ref_movimiento
   and d.fecha = g.fecha(+)
   and d.hora = g.hora(+)
   and d.cod_usuario = g.cod_usuario
   and d.nro_cuenta = g.nro_cuenta
   and h.cod_rubro = '240102420101299' /*RETENCION IVA - AGENTE DE RETENCION*/
   and h.fecha between p_fecha_des and p_fecha_has
   order by 1;

  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'LIBRO_VENTA4_ASI'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_fec_sist         DATE;
  v_fecha            VARCHAR2(8);
  v_dia_ini          DATE;
  v_dia_fin          DATE;

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
  select pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1)
  into v_fec_sist
  from dual;

  v_fecha := to_char(v_fec_sist,'DDMMYYYY');

  --Obtenemos el primer dia y el ultimo dia del mes
  v_dia_ini := trunc(v_fec_sist,'month');
  v_dia_fin := trunc(last_day(v_fec_sist));

-- Abrir archivo
v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'.txt','W',32767);

-- Colocar el titulo a los campos
v_linetit := 'FECHA'||CHR(9)||
             'COD_OFICINA'||CHR(9)||
             'NRO_ASIENTO'||CHR(9)||
             'NRO_LINEA'||CHR(9)||
             'COD_RUBRO'||CHR(9)||
             'DESCRIPCION'||CHR(9)||
             'TIP_MOVIMIENTO'||CHR(9)||
             'MTO_RUBRO'||CHR(9)||
             'MTO_LOCAL'||CHR(9)||
             'REF_MOVIMIENTO'||CHR(9)||
             'NRO_FACTURA'||CHR(9)||
             'RIESGO';

utl_file.put_line(v_file,v_linetit);

-- Definir una linea en blanco para separar los datos del titulo de los campos
v_linetit := ' ';
utl_file.put_line(v_file,v_linetit);

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN cu_lib_venta(v_dia_ini, v_dia_fin) LOOP

--Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))

  v_line := to_char(rec.fecha)||chr(9)||
            to_char(rec.cod_oficina)||chr(9)||
            to_char(rec.nro_asiento)||chr(9)||
            to_char(rec.nro_linea)||chr(9)||
            to_char(rec.cod_rubro)||chr(9)||
            to_char(rec.descripcion)||chr(9)||
            to_char(rec.tip_movimiento)||chr(9)||
            to_char(rec.mto_rubro)||chr(9)||
            to_char(rec.mto_local)||chr(9)||
            to_char(rec.ref_movimiento)||chr(9)||
            to_char(rec.nro_factura)||chr(9)||
            to_char(rec.riesgo);

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

  EXIT WHEN cu_lib_venta%NOTFOUND;
END LOOP;
--Escribes la linea en el fichero
UTL_FILE.PUT_LINE(v_file, v_buffer);

--Cerrar el handler al fichero
UTL_FILE.FCLOSE(v_file);
COMMIT;

  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_respuesta := pa_file_ftp.fu_put_ascii(pa_rpc_aut.g_ip, pa_rpc_aut.g_port,
  pa_rpc_aut.g_user,pa_rpc_aut.g_pass, pa_rpc_aut.g_repository,v_name||'.txt', g_amaral||v_name||'_'||v_fecha||'.txt');

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','LIBRO_VENTA4_ASI');
      -- Damos valor a los demas datos
      v_asunto := 'Reporte Libro de Ventas3 con asiento/linea a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_amaral||'

    Nombre del Archivo: '||v_name||'_'||v_fecha||'.txt';

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error    := null;

    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, v_name||'_'||v_fecha||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;

    --Enviamos el mail a soporte
     -- Obtenemos direccion de correo de soporte
     v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');
    -- Damos valor a los demas datos
      v_asunto := 'Error Reporte Libro de Ventas a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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
END pr_lib_compras4_det;

------------------------pr_lib_compras4_det----------------------------

------------------------pr_tas_reales----------------------------------
--PROCEDURE pr_tas_reales
/*
      Borrado por Rolando Enciso por inconsistencia en el paquete pa_rpc_aut,
      el mismo procedimiento se encuentra en el paquete pag_evo
*/

------------------------pr_gen_mov_riegos----------------------------------
PROCEDURE pr_gen_mov_riegos is
   v_sql varchar2(4000);     --query a ser ejecutado
   v_name VARCHAR2(128); -- nombre del archivo
   v_fechita varchar2(8); --fecha yyyymmdd
   v_ext varchar2(8); --fecha yyyymmdd

   v_directorio_creacion varchar2(100); --dir de destino local
   v_ctas_in varchar2(4000);            --cuentas para filtrar el query

  v_resultado varchar2(5000) := '';
  v_result           boolean;
  v_cursor           number;
  v_rows             number(10) := 1;
  v_filas            number(9) := 0;
  v_val_campo        varchar2(500);    -- contendra el valor del campo
  v_columnas         number(2) := 2;   -- cantidad de columnas a leer
  v_col_varchar2     varchar2(500);
  v_file UTL_FILE.FILE_TYPE;

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
  begin
    /*  creacion: 2010711:fjm
        proposito: Genera Archivo TXT de Movimientos de Riesgos para Proyecto SICEROF
        cambios:

    */


     v_ctas_in := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','MOV_RIESGOS_PARAM_CTAS_IN');


     v_name := 'MOVIMIENTOS_RIEGOS';
     v_fechita := to_char(sysdate,'yyyyMMdd');
     v_ext := '.txt';
     v_sql := 'select to_char(ad.fecha,''ddMMyyyy'')fecha_contable,
                      lpad(ad.cod_oficina,4,''0'')centro_de_costo,
                      ad.mto_mon_local importe_contable,
                      lpad(ad.nro_asiento,6,''0'') folio,
                      trim(ad.cod_rubro) cuenta_contable,
                      CHR(39)||trim(ad.descripcion)||CHR(39) descripcion
                from cb_asientos_det ad
                inner join cb_rubros r
                      on r.cod_rubro=ad.cod_rubro
                where ad.cod_rubro in ( '||v_ctas_in ||' ) ';

     v_directorio_creacion := pa_rpc_aut.g_repository;--'/oradata/utl';--
     begin
      v_columnas := 6;
      if v_columnas <= 0 then -- retorno sin datos
        raise_application_error(-20001,'No existen columnas en el Select');
      end if;
      if v_sql is not null and v_columnas > 0 then
        v_result := dbms_sql.is_open(v_cursor);
        if not v_result then
          v_cursor     := dbms_sql.open_cursor;
          v_result := dbms_sql.is_open(v_cursor);
          if v_result then
           dbms_sql.parse(v_cursor,v_sql,dbms_sql.native); --1 = NATIVE, 2 = V7 Y 0 = V6
           --Variables en el cursors
           for i in 1..v_columnas loop
             dbms_sql.define_column(v_cursor,i,v_col_varchar2,500);
           end loop;
           v_rows := dbms_sql.execute(v_cursor);
          end if;
        end if;
        -- abre el archivo
        IF UTL_FILE.IS_OPEN(v_file) = FALSE THEN
--        v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_filename, 'w');
          v_file := UTL_FILE.FOPEN(v_directorio_creacion,v_name||v_ext,'W',32767);
        END IF;
        -- ciclo de lectura de registros
        v_rows :=  dbms_sql.fetch_rows(v_cursor);
        loop exit when v_rows = 0;
            v_filas := v_filas + 1;
            v_resultado := null;
            for i in 1..v_columnas loop
             dbms_sql.column_value(v_cursor,i,v_val_campo);
             if i = v_columnas then
                v_resultado := v_resultado  || nvl(v_val_campo,' ');
             else
                v_resultado := v_resultado  || nvl(v_val_campo,' ')|| ',';
             end if;
            end loop;
            UTL_FILE.PUT_LINE(v_file, v_resultado); -- graba una linea
            -- leo el sigte registro
            v_rows :=  dbms_sql.fetch_rows(v_cursor);
         end loop;
         dbms_sql.close_cursor(v_cursor);
         -- cierra el archivo
         UTL_FILE.FCLOSE(v_file);
      end if;
     end;

     v_respuesta := pa_file_ftp.fu_put_ascii(pa_rpc_aut.g_ip,
                              pa_rpc_aut.g_port,
                              pa_rpc_aut.g_user,
                              pa_rpc_aut.g_pass,
                              v_directorio_creacion,
                              v_name||v_ext,
                              pa_rpc_aut.g_riesgos||v_name||'_'||v_fechita||v_ext);

   IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','MOV_RIESGOS_EMAIL_TO');

      -- Damos valor a los demas datos
      v_asunto := 'Movimientos de Riesgos Generados para la fecha '||to_char(sysdate,'dd/MM/yyyy')||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_riesgos||'

    Nombre del Archivo: '||v_name||'_'||v_fechita||v_ext;

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,
                                      v_para,
                                      v_asunto,
                                      IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fechita||v_ext, v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error    := null;

    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, v_name||'_'||v_fechita||v_ext, v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;

    --Enviamos el mail a soporte
     -- Obtenemos direccion de correo de soporte
     v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error generando Movimientos de Riesgos a la fecha '||to_char(sysdate,'dd/MM/yyyy')||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,
                                      v_para,
                                      v_asunto,
                                      IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fechita||v_ext, v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  END IF;

  end pr_gen_mov_riegos;
------------------------pr_gen_mov_riegos----------------------------------


-- REPORTE DE CUADRE BALANCE GENERAL - CUENTAS DE RESULTADO OPERATIVOS
PROCEDURE pr_inv_resultado
IS
CURSOR c_cua_inv_resultado IS
    select cod_rubro, cod_rub_externo,t.rubro,cuenta,sub_cuenta,producto,
           nombre_rubro, cod_oficina,des_oficina,mon,moneda,tot_inventario,
           sal_contable, diferencia,t.clasificacion, t.tipo
        from bv_cua_rub_resultados t
       order by 7, 1;


  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'cua_inv_rub_resultados'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_fec_sist         DATE;
  v_fecha            VARCHAR2(8);

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
  select pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1)
  into v_fec_sist
  from dual;

  v_fecha := to_char(v_fec_sist,'DDMMYYYY');

-- Abrir archivo
v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'.txt','W',32767);

-- Colocar el titulo a los campos
v_linetit := 'COD_RUBRO'||CHR(9)||'COD_RUB_EXTERNO'||CHR(9)||'RUBRO'||CHR(9)||'CUENTA'||CHR(9)||'SUB_CUENTA'||CHR(9)||'PRODUCTO'||CHR(9)||'NOMBRE_RUBRO'||CHR(9)||'COD_OFICINA'||CHR(9)||
    'DES_OFICINA'||CHR(9)||'MON'||CHR(9)||'MONEDA'||CHR(9)||'TOT_INVENTARIO'||CHR(9)||'SAL_CONTABLE'||CHR(9)||'DIFERENCIA'||CHR(9)||'CLASIFICACION'||CHR(9)||
    'TIPO';

utl_file.put_line(v_file,v_linetit);

-- Definir una linea en blanco para separar los datos del titulo de los campos
v_linetit := ' ';
utl_file.put_line(v_file,v_linetit);

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN c_cua_inv_resultado LOOP

    --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
  v_line := to_char(rec.cod_rubro)||chr(9)||to_char(rec.cod_rub_externo)||chr(9)||to_char(rec.rubro)||chr(9)||to_char(rec.cuenta)||chr(9)||to_char(rec.sub_cuenta)||chr(9)||to_char(rec.producto)||chr(9)||to_char(rec.nombre_rubro)||chr(9)||to_char(rec.cod_oficina)||chr(9)||
    to_char(rec.des_oficina)||chr(9)||to_char(rec.mon)||chr(9)||to_char(rec.moneda)||chr(9)||to_char(rec.tot_inventario,'99999999999999999D00')||chr(9)||to_char(rec.sal_contable,'99999999999999999D00')||chr(9)||to_char(rec.diferencia,'99999999999999999D00')||chr(9)||to_char(rec.clasificacion)||chr(9)||
    to_char(rec.tipo);

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

   EXIT WHEN c_cua_inv_resultado%NOTFOUND;
END LOOP;
--Escribes la linea en el fichero
UTL_FILE.PUT_LINE(v_file, v_buffer);

--Cerrar el handler al fichero
UTL_FILE.FCLOSE(v_file);
COMMIT;

  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_respuesta := pa_file_ftp.fu_put_ascii(pa_rpc_aut.g_ip, pa_rpc_aut.g_port,
   pa_rpc_aut.g_user,pa_rpc_aut.g_pass, pa_rpc_aut.g_repository,
   v_name||'.txt', g_contabilidad||v_name||'_'||v_fecha||'.txt');

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el mail
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','CUADRE_BALANCE_RESULTADO');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte reporte de Cuadre Balance Cuentas de Resultados Operativo a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_contabilidad||'

    Nombre del Archivo: '||v_name||'_'||v_fecha||'.txt';

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error    := null;

    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, v_name||'_'||v_fecha||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;

    --Enviamos el mail a soporte
     -- Obtenemos direccion de correo de soporte
     v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error Reporte de Cuadre Balance Cuentas de Resultados Operativo a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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
    RAISE_APPLICATION_ERROR(-20062,'Manejador invalido');
  WHEN UTL_FILE.WRITE_ERROR THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20063,'Error de escritura '||sqlerrm);
  WHEN UTL_FILE.INVALID_MODE THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20064,'Modo invalido');
  WHEN UTL_FILE.INTERNAL_ERROR THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20065,'Internal Error');
END pr_inv_resultado;
--------------------------------------------------------------------------------------------------------------------

-- REPORTE DE CUADRE BALANCE GENERAL - CUENTAS DE RESULTADO CONTABLE
PROCEDURE pr_inv_contable
IS
CURSOR c_inv_contable IS

      select bf.cod_rubro, bf.cod_rub_externo, bf.descripcion, bf.cod_moneda, bf.cod_modalidad, bf.cod_oficina, bf.tip_saldo,
             bf.cod_persona, bf.nombre, bf.nro_cuenta, bf.sal_actual, bf.sal_mon_local, bf.val_tasa, bf.fec_inicio,
             bf.fec_vencimiento, bf.sal_promedio
      from bv_inv_contable bf
      order by bf.cod_rubro;

  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'inv_contable_mes'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_fec_sist         DATE;
  v_fecha            VARCHAR2(8);

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
  select pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1)
  into v_fec_sist
  from dual;

  v_fecha := to_char(v_fec_sist,'DDMMYYYY');

-- Abrir archivo
v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'.txt','W',32767);

-- Colocar el titulo a los campos
  v_linetit := 'COD_RUBRO'||CHR(9)||'COD_RUB_EXTERNO'||CHR(9)||'DESCRIPCION'||CHR(9)||'COD_MONEDA'||CHR(9)||'COD_MODALIDAD'||CHR(9)||
             'COD_OFICINA'||CHR(9)||'TIP_SALDO'||CHR(9)||'COD_PERSONA'||CHR(9)||'NOMBRE'||CHR(9)||
             'NRO_CUENTA'||CHR(9)||'SAL_ACTUAL'||CHR(9)||'SAL_MON_LOCAL'||CHR(9)||'VAL_TASA'||CHR(9)||'FEC_INICIO'||CHR(9)||
             'FEC_VENCIMIENTO'||CHR(9)||'SAL_PROMEDIO';

utl_file.put_line(v_file,v_linetit);

-- Definir una linea en blanco para separar los datos del titulo de los campos
v_linetit := ' ';
utl_file.put_line(v_file,v_linetit);

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN c_inv_contable LOOP

    --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
  v_line := to_char(rec.COD_RUBRO)||chr(9)||to_char(rec.COD_RUB_EXTERNO)||chr(9)||to_char(rec.DESCRIPCION)||chr(9)||
            to_char(rec.COD_MONEDA)||chr(9)||to_char(rec.COD_MODALIDAD)||chr(9)||to_char(rec.COD_OFICINA)||chr(9)||
            to_char(rec.TIP_SALDO)||chr(9)||to_char(rec.COD_PERSONA)||chr(9)||to_char(rec.NOMBRE)||chr(9)||to_char(rec.NRO_CUENTA)||chr(9)||
            to_char(rec.SAL_ACTUAL,'999999999999D00')||chr(9)||to_char(rec.SAL_MON_LOCAL,'999999999999D00')||chr(9)||
            to_char(rec.VAL_TASA,'999999999999D00')||chr(9)||to_char(rec.FEC_INICIO)||chr(9)||to_char(rec.FEC_VENCIMIENTO)||chr(9)||
            to_char(rec.SAL_PROMEDIO,'999999999999D00');

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

  EXIT WHEN c_inv_contable%NOTFOUND;
END LOOP;
--Escribes la linea en el fichero
UTL_FILE.PUT_LINE(v_file, v_buffer);

--Cerrar el handler al fichero
UTL_FILE.FCLOSE(v_file);
COMMIT;

  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_respuesta := pa_file_ftp.fu_put_ascii(pa_rpc_aut.g_ip, pa_rpc_aut.g_port, pa_rpc_aut.g_user,
                                          pa_rpc_aut.g_pass, pa_rpc_aut.g_repository,
                                          v_name||'.txt', g_contabilidad||v_name||'_'||v_fecha||'.txt');

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','INV_CONTABLE');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte Cuadre Balance Cuentas de Resultados Contable a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_contabilidad||'

    Nombre del Archivo: '||v_name||'_'||v_fecha||'.txt';

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
     v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
    it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error    := null;

    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, v_name||'_'||v_fecha||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;

    --Enviamos el mail a soporte
     -- Obtenemos direccion de correo de soporte
     v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error Reporte Cuadre Balance Cuentas de Resultados Contable a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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
END pr_inv_contable;
--------------------------------------------------------------------------------------------------------------------
-- REPORTE DE TIEMPOS DEL CIERRE
PROCEDURE pr_tie_proc(p_cod_proceso ge_procesos_det.cod_proceso%type)
IS
CURSOR cu_procesos_cierre  IS
select a.cod_proceso,
       a.nro_orden,
       a.descripcion,
       a.cod_programa,
       a.hor_inicio,
       a.hor_fin,
       a.obligatorio,
       a.activo,
       a.frecuencia,
       a.error
  from ge_procesos_det a
 where a.activo = 'S'
   and a.cod_proceso = p_cod_proceso
 order by a.nro_orden, a.hor_inicio;

 CURSOR cu_procesos  IS
select a.cod_proceso,
       a.descripcion,
       a.hor_inicio,
       a.hor_fin
  from ge_procesos  a
 where  a.cod_proceso = p_cod_proceso;

  v_name             VARCHAR2(128) := 'PROCESOS_CIERRE'; -- nombre del archivo
  v_flag             BOOLEAN;
  v_descripcion      ge_procesos.descripcion%type;

  -- Variables de fechas
  v_fec_sist         DATE;
  v_fecha            VARCHAR2(8);
  v_hora             VARCHAR2(8);

  -- Variables para mail
  v_conn             utl_smtp.connection;
  v_para             VARCHAR2(500);
  v_asunto           VARCHAR2(2000);
  v_mje_mail         LONG;

  v_cabecera_mail    LONG;

  v_fin_mail         LONG := ' </table>
                             </i> <br><br> Atentamente,
                              </p>
                              <p><img src="http://www.bbva.com.py/images/logo-bbva.png" alt="Site Logo" />
                            </body>
                          </html>';

  V_DETALLE_mail     LONG := '';

  v_cabecera         VARCHAR2(32767);
  v_detalle          VARCHAR2(32767);
  v_hini_mail        ge_ra_log_mail.hor_inicio%type;
  v_hfin_mail        ge_ra_log_mail.hor_fin%type;
  v_det_error        ge_ra_log_mail.det_error%type;

BEGIN
  -- Obtenemos la fecha del sistema
  select pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1)
  into v_fec_sist
  from dual;

  select a.descripcion
    into v_descripcion
    from ge_procesos a
   where a.cod_proceso = p_cod_proceso;

  v_fecha := to_char(v_fec_sist,'DDMMYYYY');

  if p_cod_proceso = 11 then
     v_name := 'CIERRE_DIARIO';
  end if;

  if p_cod_proceso = 12 then
     v_name := 'POST_CIERRE';
  end if;
  -- obtenemos los mail que van a recibir el reporte
  v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','PROCESOS_CIERRE');

  --
  v_det_error   := null;
  v_hini_mail   := null;
  v_hfin_mail   := null;
  v_asunto      := null;
  v_flag        := FALSE;

   SELECT TO_CHAR(sysdate,'hh:mi:ss')
  into v_hora
   FROM DUAL;

  -- Empezamos a cargar los datos del mail a enviar
  v_hini_mail := to_char(sysdate,'hh24:mi:ss');
  --
  v_asunto := 'Reporte de tiempos del proceso : ' || v_descripcion || ', a la fecha: '||v_fec_sist||'.';

  v_cabecera_mail := '<html>
                  <body>
                         Remitimos el archivo  '||v_name||'_'||v_fecha||'.xls con los tiempos de los procesos, adjuntos en el mail.
                  <br><br>
                  </p>
                  <table cellspacing="0"
                          cellpadding="5"
                          border="4">
                  <tr>
                    <td width="80%" bgcolor="B0C4DE"> <b>DESCRIPCION</b></td>
                    <td width="80%" bgcolor="B0C4DE"> <b>COD_PROCESO</b></td>
                    <td width="80%" bgcolor="B0C4DE"> <b>HOR_INICIO</b></td>
                    <td width="80%" bgcolor="B0C4DE"> <b>HOR_FIN</b></td>
                    <td width="80%" bgcolor="B0C4DE"> <b></b></td>
                  </tr>';


  begin

       FOR REC IN cu_procesos LOOP
          V_DETALLE_mail := V_DETALLE_mail || '<tr>
                         <td width="180%" bgcolor="FFFFFF">'||REC.DESCRIPCION||'</td>
                         <td width="180%" bgcolor="FFFFFF">'||REC.COD_PROCESO||'</td>
                         <td width="180%" bgcolor="FFFFFF">'||REC.HOR_INICIO||'</td>
                         <td width="180%" bgcolor="FFFFFF">'||v_hora||'</td>
                          <td width="180%" bgcolor="E0FFFF"></td>
                        </tr> ';
          EXIT WHEN cu_procesos%NOTFOUND;
        END LOOP;

        v_mje_mail := v_cabecera_mail||V_DETALLE_mail||v_fin_mail;

  end;

  begin
    --**

    v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
    it_mail.attach_text(v_conn,  v_mje_mail,'text/html');

    it_mail.begin_attachment(v_conn,'text/plain',false,v_name||'_'||v_fecha||'.xls');
    --**
      -- Titulo del reporte
      -- Colocar el titulo a los campos
      v_cabecera :=
      'COD_PROCESO'||CHR(9)||
      'NRO_ORDEN'||CHR(9)||
      'DESCRIPCION'||CHR(9)||
      'COD_PROGRAMA'||CHR(9)||
      'HOR_INICIO'||CHR(9)||
      'HOR_FIN'||CHR(9)||
      'OBLIGATORIO'||CHR(9)||
      'ACTIVO'||CHR(9)||
      'FRECUENCIA'||CHR(9)||
      'ERROR'||CHR(13)||CHR(10) ;

      --** Arma el Archivo Anexo.
      it_mail.write_text(v_conn,v_cabecera);
      --**

      v_detalle := '';

      -- detalle del reporte
      FOR REC IN cu_procesos_cierre LOOP
        v_flag := TRUE;
        --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
        v_detalle :=
        to_char(rec.COD_PROCESO)||chr(9)||
        to_char(rec.NRO_ORDEN)||chr(9)||
        to_char(rec.DESCRIPCION)||chr(9)||
        to_char(rec.COD_PROGRAMA)||chr(9)||
        to_char(rec.HOR_INICIO)||chr(9)||
        to_char(rec.HOR_FIN)||chr(9)||
        to_char(rec.OBLIGATORIO)||chr(9)||
        to_char(rec.ACTIVO)||chr(9)||
        to_char(rec.FRECUENCIA)||chr(9)||
        to_char(rec.ERROR)||CHR(13)||CHR(10);
        --Escribir la linea en el archivo
        --**
        it_mail.write_text(v_conn,v_detalle);
        v_detalle := '';
        --**

        EXIT WHEN cu_procesos_cierre%NOTFOUND;
      END LOOP;
    --**
    -- Verificamos si el cursor trajo por lo menos un registro, de ser asi enviamos el mail
    IF v_flag THEN
       it_mail.end_mail(v_conn);
    ELSE
      ROLLBACK;
    END IF;
    --**
  exception
    when utl_smtp.transient_error or utl_smtp.permanent_error then
    begin
      utl_smtp.quit(v_conn);
    exception
    when utl_smtp.transient_error or utl_smtp.permanent_error then
      null;
    end;
    v_det_error := substr(sqlerrm,1,4000);
  end;

  --
  v_hfin_mail := to_char(sysdate,'hh24:mi:ss');

  -- Insertamos en la tabla de log  si ocurrio algun error al enviar el mail
      IF v_det_error is not null THEN
          INSERT INTO ge_ra_log_mail
           (fec_envio, nom_archivo, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
          VALUES
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;
COMMIT;
EXCEPTION
  WHEN OTHERS THEN
    raise_application_error(-20000,'Error al enviar los tiempos del Cierre'||sqlerrm);
END pr_tie_proc;
-----------------------------------------------------------------------------------------------------

-- REPORTE ANALISIS DE LIQUIDEZ 1
PROCEDURE pr_analiq1
IS
CURSOR CU_ANALIQ1 IS
     select moneda,
            cuentas,
            plz_vista,
            men_30_dias,
            men_90_dias,
            men_180_dias,
            men_1_ano,
            men_3_anos,
            may_3_anos,
            monto,
            informe
       from sb_ana_liq_inf12 t
      where t.informe='ANALIQ1'
   order by t.cuentas, t.moneda;

  v_name             VARCHAR2(128) := 'ANALIQ1'; -- nombre del archivo
  v_flag             BOOLEAN;
  v_descripcion      sb_ana_liq_inf12.informe%type;

  -- Variables de fechas
  v_fec_sist         DATE;
  v_fecha            VARCHAR2(8);

  -- Variables para mail
  v_conn             utl_smtp.connection;
  v_para             VARCHAR2(500);
  v_asunto           VARCHAR2(2000);
  v_mje_mail         LONG;

  v_cabecera_mail    LONG;

  v_fin_mail         LONG := ' </table>
                             </i> <br><br> Atentamente,
                              </p>
                              <p><img src="http://www.bbva.com.py/images/logo-bbva.png" alt="Site Logo" />
                            </body>
                          </html>';

  V_DETALLE_mail     LONG := '';

  v_cabecera         VARCHAR2(32767);
  v_detalle          VARCHAR2(32767);
  v_hini_mail        ge_ra_log_mail.hor_inicio%type;
  v_hfin_mail        ge_ra_log_mail.hor_fin%type;
  v_det_error        ge_ra_log_mail.det_error%type;

BEGIN
  -- Obtenemos la fecha del sistema
  select pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1)
  into v_fec_sist
  from dual;

  v_fecha := to_char(v_fec_sist,'DDMMYYYY');
  v_name := 'ANALIQ1';

  -- obtenemos los mail que van a recibir el reporte
  v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','PROCESOS_ANALIQ');

  --
  v_det_error   := null;
  v_hini_mail   := null;
  v_hfin_mail   := null;
  v_asunto      := null;
  v_flag        := FALSE;

  -- Empezamos a cargar los datos del mail a enviar
  v_hini_mail := to_char(sysdate,'hh24:mi:ss');
  --
  v_asunto := 'Reporte de análisis de liquidez 1' || ', a la fecha: '||v_fec_sist||'.';
  v_mje_mail := 'El archivo con los datos del reporte Analisis de liquidez 1 se encuentra adjunto al mail:'||v_name||'_'||v_fecha||'.txt';
  begin
    --**
    v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
    it_mail.attach_text(v_conn,  v_mje_mail,'text/html');

    it_mail.begin_attachment(v_conn,'text/plain',false,v_name||'_'||v_fecha||'.txt');
    --**
      -- Titulo del reporte
      -- Colocar el titulo a los campos
      v_cabecera :=
      'MONEDA'||CHR(9)||
      'CUENTAS'||CHR(9)||
      'PLZ_VISTA'||CHR(9)||
      'MEN_30_DIAS'||CHR(9)||
      'MEN_90_DIAS'||CHR(9)||
      'MEN_180_DIAS'||CHR(9)||
      'MEN_1_ANO'||CHR(9)||
      'MEN_3_ANOS'||CHR(9)||
      'MAY_3_ANOS'||CHR(9)||
      'MONTO'||CHR(9)||
      'INFORME'||CHR(13)||CHR(10) ;

      --** Arma el Archivo Anexo.
      it_mail.write_text(v_conn,v_cabecera);
      --**

      v_detalle := '';
      -- detalle del reporte
      FOR REC IN CU_ANALIQ1 LOOP
        v_flag := TRUE;
        --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
        v_detalle :=
        to_char(rec.MONEDA)||chr(9)||
        to_char(rec.CUENTAS)||chr(9)||
        to_char(rec.PLZ_VISTA)||chr(9)||
        to_char(rec.MEN_30_DIAS)||chr(9)||
        to_char(rec.MEN_90_DIAS)||chr(9)||
        to_char(rec.MEN_180_DIAS)||chr(9)||
        to_char(rec.MEN_1_ANO)||chr(9)||
        to_char(rec.MEN_3_ANOS)||chr(9)||
        to_char(rec.MAY_3_ANOS)||chr(9)||
        to_char(rec.MONTO)||chr(9)||
        to_char(rec.INFORME)||CHR(13)||CHR(10);
        --Escribir la linea en el archivo
        --**
        it_mail.write_text(v_conn,v_detalle);
        v_detalle := '';
        --**

        EXIT WHEN CU_ANALIQ1%NOTFOUND;
      END LOOP;
    --**
    -- Verificamos si el cursor trajo por lo menos un registro, de ser asi enviamos el mail
    IF v_flag THEN
       it_mail.end_mail(v_conn);
    ELSE
      ROLLBACK;
    END IF;
    --**
  exception
    when utl_smtp.transient_error or utl_smtp.permanent_error then
    begin
      utl_smtp.quit(v_conn);
    exception
    when utl_smtp.transient_error or utl_smtp.permanent_error then
      null;
    end;
    v_det_error := substr(sqlerrm,1,4000);
  end;

  --
  v_hfin_mail := to_char(sysdate,'hh24:mi:ss');

  -- Insertamos en la tabla de log  si ocurrio algun error al enviar el mail
      IF v_det_error is not null THEN
          INSERT INTO ge_ra_log_mail
           (fec_envio, nom_archivo, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
          VALUES
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;
COMMIT;
EXCEPTION
  WHEN OTHERS THEN
    raise_application_error(-20000,'Error al enviar el archivo:'||v_name||sqlerrm);
END pr_analiq1;
-----------------------------------------------------------------------------------------------------

-- REPORTE ANALISIS DE LIQUIDEZ 2
PROCEDURE pr_analiq2
IS
CURSOR CU_ANALIQ2 IS
     select moneda,
            cuentas,
            plz_vista,
            men_30_dias,
            men_90_dias,
            men_180_dias,
            men_1_ano,
            men_3_anos,
            may_3_anos,
            monto,
            informe
       from sb_ana_liq_inf12 t
      where t.informe='ANALIQ2'
   order by t.cuentas, t.moneda;

  v_name             VARCHAR2(128) := 'ANALIQ2'; -- nombre del archivo
  v_flag             BOOLEAN;
  v_descripcion      sb_ana_liq_inf12.informe%type;

  -- Variables de fechas
  v_fec_sist         DATE;
  v_fecha            VARCHAR2(8);

  -- Variables para mail
  v_conn             utl_smtp.connection;
  v_para             VARCHAR2(500);
  v_asunto           VARCHAR2(2000);
  v_mje_mail         LONG;

  v_cabecera_mail    LONG;

  v_fin_mail         LONG := ' </table>
                             </i> <br><br> Atentamente,
                              </p>
                              <p><img src="http://www.bbva.com.py/images/logo-bbva.png" alt="Site Logo" />
                            </body>
                          </html>';

  V_DETALLE_mail     LONG := '';

  v_cabecera         VARCHAR2(32767);
  v_detalle          VARCHAR2(32767);
  v_hini_mail        ge_ra_log_mail.hor_inicio%type;
  v_hfin_mail        ge_ra_log_mail.hor_fin%type;
  v_det_error        ge_ra_log_mail.det_error%type;

BEGIN
  -- Obtenemos la fecha del sistema
  select pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1)
  into v_fec_sist
  from dual;

  v_fecha := to_char(v_fec_sist,'DDMMYYYY');
  v_name := 'ANALIQ2';

  -- obtenemos los mail que van a recibir el reporte
  v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','PROCESOS_ANALIQ');

  --
  v_det_error   := null;
  v_hini_mail   := null;
  v_hfin_mail   := null;
  v_asunto      := null;
  v_flag        := FALSE;

  -- Empezamos a cargar los datos del mail a enviar
  v_hini_mail := to_char(sysdate,'hh24:mi:ss');
  --
  v_asunto := 'Reporte de análisis de liquidez 2' || ', a la fecha: '||v_fec_sist||'.';
  v_mje_mail := 'El archivo con los datos del reporte Análisis de liquidez 2 se encuentra adjunto al mail:'||v_name||'_'||v_fecha||'.txt';
  begin
    --**
    v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
    it_mail.attach_text(v_conn,  v_mje_mail,'text/html');

    it_mail.begin_attachment(v_conn,'text/plain',false,v_name||'_'||v_fecha||'.txt');
    --**
      -- Titulo del reporte
      -- Colocar el titulo a los campos
      v_cabecera :=
      'MONEDA'||CHR(9)||
      'CUENTAS'||CHR(9)||
      'PLZ_VISTA'||CHR(9)||
      'MEN_30_DIAS'||CHR(9)||
      'MEN_90_DIAS'||CHR(9)||
      'MEN_180_DIAS'||CHR(9)||
      'MEN_1_ANO'||CHR(9)||
      'MEN_3_ANOS'||CHR(9)||
      'MAY_3_ANOS'||CHR(9)||
      'MONTO'||CHR(9)||
      'INFORME'||CHR(13)||CHR(10) ;

      --** Arma el Archivo Anexo.
      it_mail.write_text(v_conn,v_cabecera);
      --**

      v_detalle := '';
      -- detalle del reporte
      FOR REC IN CU_ANALIQ2 LOOP
        v_flag := TRUE;
        --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
        v_detalle :=
        to_char(rec.MONEDA)||chr(9)||
        to_char(rec.CUENTAS)||chr(9)||
        to_char(rec.PLZ_VISTA)||chr(9)||
        to_char(rec.MEN_30_DIAS)||chr(9)||
        to_char(rec.MEN_90_DIAS)||chr(9)||
        to_char(rec.MEN_180_DIAS)||chr(9)||
        to_char(rec.MEN_1_ANO)||chr(9)||
        to_char(rec.MEN_3_ANOS)||chr(9)||
        to_char(rec.MAY_3_ANOS)||chr(9)||
        to_char(rec.MONTO)||chr(9)||
        to_char(rec.INFORME)||CHR(13)||CHR(10);
        --Escribir la linea en el archivo
        --**
        it_mail.write_text(v_conn,v_detalle);
        v_detalle := '';
        --**

        EXIT WHEN CU_ANALIQ2%NOTFOUND;
      END LOOP;
    --**
    -- Verificamos si el cursor trajo por lo menos un registro, de ser asi enviamos el mail
    IF v_flag THEN
       it_mail.end_mail(v_conn);
    ELSE
      ROLLBACK;
    END IF;
    --**
  exception
    when utl_smtp.transient_error or utl_smtp.permanent_error then
    begin
      utl_smtp.quit(v_conn);
    exception
    when utl_smtp.transient_error or utl_smtp.permanent_error then
      null;
    end;
    v_det_error := substr(sqlerrm,1,4000);
  end;

  --
  v_hfin_mail := to_char(sysdate,'hh24:mi:ss');

  -- Insertamos en la tabla de log  si ocurrio algun error al enviar el mail
      IF v_det_error is not null THEN
          INSERT INTO ge_ra_log_mail
           (fec_envio, nom_archivo, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
          VALUES
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;
COMMIT;
EXCEPTION
  WHEN OTHERS THEN
    raise_application_error(-20000,'Error al enviar el archivo:'||v_name||sqlerrm);
END pr_analiq2;
-----------------------------------------------------------------------------------------------------

-- REPORTE ANALISIS DE LIQUIDEZ 3
PROCEDURE pr_analiq3
IS
CURSOR CU_ANALIQ3 IS
   select moneda,
          cuentas,
          plz_vista,
          men_180_dias,
          men_365_dias,
          men_3_anos,
          men_5_anos,
          men_10_anos,
          may_10_anos,
          monto,
          informe
     from sb_ana_liq_inf34 t
    where t.informe = 'ANALIQ3'
    order by t.cuentas, t.moneda;

  v_name             VARCHAR2(128) := 'ANALIQ3'; -- nombre del archivo
  v_flag             BOOLEAN;
  v_descripcion      sb_ana_liq_inf34.informe%type;

  -- Variables de fechas
  v_fec_sist         DATE;
  v_fecha            VARCHAR2(8);

  -- Variables para mail
  v_conn             utl_smtp.connection;
  v_para             VARCHAR2(500);
  v_asunto           VARCHAR2(2000);
  v_mje_mail         LONG;

  v_cabecera_mail    LONG;

  v_fin_mail         LONG := ' </table>
                             </i> <br><br> Atentamente,
                              </p>
                              <p><img src="http://www.bbva.com.py/images/logo-bbva.png" alt="Site Logo" />
                            </body>
                          </html>';

  V_DETALLE_mail     LONG := '';

  v_cabecera         VARCHAR2(32767);
  v_detalle          VARCHAR2(32767);
  v_hini_mail        ge_ra_log_mail.hor_inicio%type;
  v_hfin_mail        ge_ra_log_mail.hor_fin%type;
  v_det_error        ge_ra_log_mail.det_error%type;

BEGIN
  -- Obtenemos la fecha del sistema
  select pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1)
  into v_fec_sist
  from dual;

  v_fecha := to_char(v_fec_sist,'DDMMYYYY');
  v_name := 'ANALIQ3';

  -- obtenemos los mail que van a recibir el reporte
  v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','PROCESOS_ANALIQ');

  --
  v_det_error   := null;
  v_hini_mail   := null;
  v_hfin_mail   := null;
  v_asunto      := null;
  v_flag        := FALSE;

  -- Empezamos a cargar los datos del mail a enviar
  v_hini_mail := to_char(sysdate,'hh24:mi:ss');
  --
  v_asunto := 'Reporte de análisis de liquidez 3' || ', a la fecha: '||v_fec_sist||'.';
  v_mje_mail := 'El archivo con los datos del reporte Analisis de liquidez 3 se encuentra adjunto al mail:'||v_name||'_'||v_fecha||'.txt';
  begin
    --**
    v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
    it_mail.attach_text(v_conn,  v_mje_mail,'text/html');

    it_mail.begin_attachment(v_conn,'text/plain',false,v_name||'_'||v_fecha||'.txt');
    --**
      -- Titulo del reporte
      -- Colocar el titulo a los campos
      v_cabecera :=
      'MONEDA'||CHR(9)||
      'CUENTAS'||CHR(9)||
      'PLZ_VISTA'||CHR(9)||
      'MEN_180_DIAS'||CHR(9)||
      'MEN_365_DIAS'||CHR(9)||
      'MEN_3_ANOS'||CHR(9)||
      'MEN_5_ANOS'||CHR(9)||
      'MEN_10_ANOS'||CHR(9)||
      'MAY_10_ANOS'||CHR(9)||
      'MONTO'||CHR(9)||
      'INFORME'||CHR(13)||CHR(10) ;

      --** Arma el Archivo Anexo.
      it_mail.write_text(v_conn,v_cabecera);
      --**

      v_detalle := '';
      -- detalle del reporte
      FOR REC IN CU_ANALIQ3 LOOP
        v_flag := TRUE;
        --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
        v_detalle :=
        to_char(rec.MONEDA)||chr(9)||
        to_char(rec.CUENTAS)||chr(9)||
        to_char(rec.PLZ_VISTA)||chr(9)||
        to_char(rec.MEN_180_DIAS)||chr(9)||
        to_char(rec.MEN_365_DIAS)||chr(9)||
        to_char(rec.MEN_3_ANOS)||chr(9)||
        to_char(rec.MEN_5_ANOS)||chr(9)||
        to_char(rec.MEN_10_ANOS)||chr(9)||
        to_char(rec.MAY_10_ANOS)||chr(9)||
        to_char(rec.MONTO)||chr(9)||
        to_char(rec.INFORME)||CHR(13)||CHR(10);
        --Escribir la linea en el archivo
        --**
        it_mail.write_text(v_conn,v_detalle);
        v_detalle := '';
        --**

        EXIT WHEN CU_ANALIQ3%NOTFOUND;
      END LOOP;
    --**
    -- Verificamos si el cursor trajo por lo menos un registro, de ser asi enviamos el mail
    IF v_flag THEN
       it_mail.end_mail(v_conn);
    ELSE
      ROLLBACK;
    END IF;
    --**
  exception
    when utl_smtp.transient_error or utl_smtp.permanent_error then
    begin
      utl_smtp.quit(v_conn);
    exception
    when utl_smtp.transient_error or utl_smtp.permanent_error then
      null;
    end;
    v_det_error := substr(sqlerrm,1,4000);
  end;

  --
  v_hfin_mail := to_char(sysdate,'hh24:mi:ss');

  -- Insertamos en la tabla de log  si ocurrio algun error al enviar el mail
      IF v_det_error is not null THEN
          INSERT INTO ge_ra_log_mail
           (fec_envio, nom_archivo, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
          VALUES
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;
COMMIT;
EXCEPTION
  WHEN OTHERS THEN
    raise_application_error(-20000,'Error al enviar el archivo:'||v_name||sqlerrm);
END pr_analiq3;
-----------------------------------------------------------------------------------------------------

-- REPORTE ANALISIS DE LIQUIDEZ 4
PROCEDURE pr_analiq4
IS
CURSOR CU_ANALIQ4 IS
   select moneda,
          cuentas,
          plz_vista,
          men_180_dias,
          men_365_dias,
          men_3_anos,
          men_5_anos,
          men_10_anos,
          may_10_anos,
          monto,
          informe
     from sb_ana_liq_inf34 t
    where t.informe = 'ANALIQ4'
    order by t.cuentas, t.moneda;

  v_name             VARCHAR2(128) := 'ANALIQ4'; -- nombre del archivo
  v_flag             BOOLEAN;
  v_descripcion      sb_ana_liq_inf34.informe%type;

  -- Variables de fechas
  v_fec_sist         DATE;
  v_fecha            VARCHAR2(8);

  -- Variables para mail
  v_conn             utl_smtp.connection;
  v_para             VARCHAR2(500);
  v_asunto           VARCHAR2(2000);
  v_mje_mail         LONG;

  v_cabecera_mail    LONG;

  v_fin_mail         LONG := ' </table>
                             </i> <br><br> Atentamente,
                              </p>
                              <p><img src="http://www.bbva.com.py/images/logo-bbva.png" alt="Site Logo" />
                            </body>
                          </html>';

  V_DETALLE_mail     LONG := '';

  v_cabecera         VARCHAR2(32767);
  v_detalle          VARCHAR2(32767);
  v_hini_mail        ge_ra_log_mail.hor_inicio%type;
  v_hfin_mail        ge_ra_log_mail.hor_fin%type;
  v_det_error        ge_ra_log_mail.det_error%type;

BEGIN
  -- Obtenemos la fecha del sistema
  select pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1)
  into v_fec_sist
  from dual;

  v_fecha := to_char(v_fec_sist,'DDMMYYYY');
  v_name := 'ANALIQ4';

  -- obtenemos los mail que van a recibir el reporte
  v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','PROCESOS_ANALIQ');

  --
  v_det_error   := null;
  v_hini_mail   := null;
  v_hfin_mail   := null;
  v_asunto      := null;
  v_flag        := FALSE;

  -- Empezamos a cargar los datos del mail a enviar
  v_hini_mail := to_char(sysdate,'hh24:mi:ss');
  --
  v_asunto := 'Reporte de análisis de liquidez 4' || ', a la fecha: '||v_fec_sist||'.';
  v_mje_mail := 'El archivo con los datos del reporte Analisis de liquidez 4 se encuentra adjunto al mail:'||v_name||'_'||v_fecha||'.txt';
  begin
    --**
    v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
    it_mail.attach_text(v_conn,  v_mje_mail,'text/html');

    it_mail.begin_attachment(v_conn,'text/plain',false,v_name||'_'||v_fecha||'.txt');
    --**
      -- Titulo del reporte
      -- Colocar el titulo a los campos
      v_cabecera :=
      'MONEDA'||CHR(9)||
      'CUENTAS'||CHR(9)||
      'PLZ_VISTA'||CHR(9)||
      'MEN_180_DIAS'||CHR(9)||
      'MEN_365_DIAS'||CHR(9)||
      'MEN_3_ANOS'||CHR(9)||
      'MEN_5_ANOS'||CHR(9)||
      'MEN_10_ANOS'||CHR(9)||
      'MAY_10_ANOS'||CHR(9)||
      'MONTO'||CHR(9)||
      'INFORME'||CHR(13)||CHR(10) ;

      --** Arma el Archivo Anexo.
      it_mail.write_text(v_conn,v_cabecera);
      --**

      v_detalle := '';
      -- detalle del reporte
      FOR REC IN CU_ANALIQ4 LOOP
        v_flag := TRUE;
        --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
        v_detalle :=
        to_char(rec.MONEDA)||chr(9)||
        to_char(rec.CUENTAS)||chr(9)||
        to_char(rec.PLZ_VISTA)||chr(9)||
        to_char(rec.MEN_180_DIAS)||chr(9)||
        to_char(rec.MEN_365_DIAS)||chr(9)||
        to_char(rec.MEN_3_ANOS)||chr(9)||
        to_char(rec.MEN_5_ANOS)||chr(9)||
        to_char(rec.MEN_10_ANOS)||chr(9)||
        to_char(rec.MAY_10_ANOS)||chr(9)||
        to_char(rec.MONTO)||chr(9)||
        to_char(rec.INFORME)||CHR(13)||CHR(10);
        --Escribir la linea en el archivo
        --**
        it_mail.write_text(v_conn,v_detalle);
        v_detalle := '';
        --**

        EXIT WHEN CU_ANALIQ4%NOTFOUND;
      END LOOP;
    --**
    -- Verificamos si el cursor trajo por lo menos un registro, de ser asi enviamos el mail
    IF v_flag THEN
       it_mail.end_mail(v_conn);
    ELSE
      ROLLBACK;
    END IF;
    --**
  exception
    when utl_smtp.transient_error or utl_smtp.permanent_error then
    begin
      utl_smtp.quit(v_conn);
    exception
    when utl_smtp.transient_error or utl_smtp.permanent_error then
      null;
    end;
    v_det_error := substr(sqlerrm,1,4000);
  end;

  --
  v_hfin_mail := to_char(sysdate,'hh24:mi:ss');

  -- Insertamos en la tabla de log  si ocurrio algun error al enviar el mail
      IF v_det_error is not null THEN
          INSERT INTO ge_ra_log_mail
           (fec_envio, nom_archivo, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
          VALUES
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;
COMMIT;
EXCEPTION
  WHEN OTHERS THEN
    raise_application_error(-20000,'Error al enviar el archivo:'||v_name||sqlerrm);
END pr_analiq4;
-----------------------------------------------------------------------------------------------------

-- REPORTE ANALISIS DE LIQUIDEZ 5
PROCEDURE pr_analiq5
IS
CURSOR CU_ANALIQ5 IS
   select moneda,
          cuentas,
          men_7_dias,
          men_30_dias,
          men_60_dias,
          men_90_dias,
          may_90_dias,
          monto,
          informe
     from sb_ana_liq_inf56 t
    where t.informe = 'ANALIQ5'
    order by t.cuentas, t.moneda;

  v_name             VARCHAR2(128) := 'ANALIQ5'; -- nombre del archivo
  v_flag             BOOLEAN;
  v_descripcion      sb_ana_liq_inf56.informe%type;

  -- Variables de fechas
  v_fec_sist         DATE;
  v_fecha            VARCHAR2(8);

  -- Variables para mail
  v_conn             utl_smtp.connection;
  v_para             VARCHAR2(500);
  v_asunto           VARCHAR2(2000);
  v_mje_mail         LONG;

  v_cabecera_mail    LONG;

  v_fin_mail         LONG := ' </table>
                             </i> <br><br> Atentamente,
                              </p>
                              <p><img src="http://www.bbva.com.py/images/logo-bbva.png" alt="Site Logo" />
                            </body>
                          </html>';

  V_DETALLE_mail     LONG := '';

  v_cabecera         VARCHAR2(32767);
  v_detalle          VARCHAR2(32767);
  v_hini_mail        ge_ra_log_mail.hor_inicio%type;
  v_hfin_mail        ge_ra_log_mail.hor_fin%type;
  v_det_error        ge_ra_log_mail.det_error%type;

BEGIN
  -- Obtenemos la fecha del sistema
  select pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1)
  into v_fec_sist
  from dual;

  v_fecha := to_char(v_fec_sist,'DDMMYYYY');
  v_name := 'ANALIQ5';

  -- obtenemos los mail que van a recibir el reporte
  v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','PROCESOS_ANALIQ');

  --
  v_det_error   := null;
  v_hini_mail   := null;
  v_hfin_mail   := null;
  v_asunto      := null;
  v_flag        := FALSE;

  -- Empezamos a cargar los datos del mail a enviar
  v_hini_mail := to_char(sysdate,'hh24:mi:ss');
  --
  v_asunto := 'Reporte de análisis de liquidez 5' || ', a la fecha: '||v_fec_sist||'.';
  v_mje_mail := 'El archivo con los datos del reporte Analisis de liquidez 4 se encuentra adjunto al mail:'||v_name||'_'||v_fecha||'.txt';
  begin
    --**
    v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
    it_mail.attach_text(v_conn,  v_mje_mail,'text/html');

    it_mail.begin_attachment(v_conn,'text/plain',false,v_name||'_'||v_fecha||'.txt');
    --**

      -- Titulo del reporte
      -- Colocar el titulo a los campos
      v_cabecera :=
      'MONEDA'||CHR(9)||
      'CUENTAS'||CHR(9)||
      'MEN_7_DIAS'||CHR(9)||
      'MEN_30_DIAS'||CHR(9)||
      'MEN_60_DIAS'||CHR(9)||
      'MEN_90_DIAS'||CHR(9)||
      'MAY_90_DIAS'||CHR(9)||
      'MONTO'||CHR(9)||
      'INFORME'||CHR(13)||CHR(10);

      --** Arma el Archivo Anexo.
      it_mail.write_text(v_conn,v_cabecera);
      --**

      v_detalle := '';
      -- detalle del reporte
      FOR REC IN CU_ANALIQ5 LOOP
        v_flag := TRUE;
        --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))

        v_detalle := to_char(rec.MONEDA)||chr(9)||
      to_char(rec.CUENTAS)||chr(9)||
      to_char(rec.MEN_7_DIAS)||chr(9)||
      to_char(rec.MEN_30_DIAS)||chr(9)||
      to_char(rec.MEN_60_DIAS)||chr(9)||
      to_char(rec.MEN_90_DIAS)||chr(9)||
      to_char(rec.MAY_90_DIAS)||chr(9)||
      to_char(rec.MONTO)||chr(9)||
      to_char(rec.INFORME)||CHR(13)||CHR(10);
        --Escribir la linea en el archivo
        --**
        it_mail.write_text(v_conn,v_detalle);
        v_detalle := '';
        --**

        EXIT WHEN CU_ANALIQ5%NOTFOUND;
      END LOOP;
    --**
    -- Verificamos si el cursor trajo por lo menos un registro, de ser asi enviamos el mail
    IF v_flag THEN
       it_mail.end_mail(v_conn);
    ELSE
      ROLLBACK;
    END IF;
    --**
  exception
    when utl_smtp.transient_error or utl_smtp.permanent_error then
    begin
      utl_smtp.quit(v_conn);
    exception
    when utl_smtp.transient_error or utl_smtp.permanent_error then
      null;
    end;
    v_det_error := substr(sqlerrm,1,4000);
  end;

  --
  v_hfin_mail := to_char(sysdate,'hh24:mi:ss');

  -- Insertamos en la tabla de log  si ocurrio algun error al enviar el mail
      IF v_det_error is not null THEN
          INSERT INTO ge_ra_log_mail
           (fec_envio, nom_archivo, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
          VALUES
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;
COMMIT;
EXCEPTION
  WHEN OTHERS THEN
    raise_application_error(-20000,'Error al enviar el archivo:'||v_name||sqlerrm);
END pr_analiq5;
-----------------------------------------------------------------------------------------------------

-- REPORTE ANALISIS DE LIQUIDEZ 6
PROCEDURE pr_analiq6
IS
CURSOR CU_ANALIQ6 IS
   select moneda,
          cuentas,
          men_7_dias,
          men_30_dias,
          men_60_dias,
          men_90_dias,
          may_90_dias,
          monto,
          informe
     from sb_ana_liq_inf56 t
    where t.informe = 'ANALIQ6'
    order by t.cuentas, t.moneda;

  v_name             VARCHAR2(128) := 'ANALIQ6'; -- nombre del archivo
  v_flag             BOOLEAN;
  v_descripcion      sb_ana_liq_inf56.informe%type;

  -- Variables de fechas
  v_fec_sist         DATE;
  v_fecha            VARCHAR2(8);

  -- Variables para mail
  v_conn             utl_smtp.connection;
  v_para             VARCHAR2(500);
  v_asunto           VARCHAR2(2000);
  v_mje_mail         LONG;

  v_cabecera_mail    LONG;

  v_fin_mail         LONG := ' </table>
                             </i> <br><br> Atentamente,
                              </p>
                              <p><img src="http://www.bbva.com.py/images/logo-bbva.png" alt="Site Logo" />
                            </body>
                          </html>';

  V_DETALLE_mail     LONG := '';

  v_cabecera         VARCHAR2(32767);
  v_detalle          VARCHAR2(32767);
  v_hini_mail        ge_ra_log_mail.hor_inicio%type;
  v_hfin_mail        ge_ra_log_mail.hor_fin%type;
  v_det_error        ge_ra_log_mail.det_error%type;

BEGIN
  -- Obtenemos la fecha del sistema
  select pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1)
  into v_fec_sist
  from dual;

  v_fecha := to_char(v_fec_sist,'DDMMYYYY');
  v_name := 'ANALIQ6';

  -- obtenemos los mail que van a recibir el reporte
  v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','PROCESOS_ANALIQ');

  --
  v_det_error   := null;
  v_hini_mail   := null;
  v_hfin_mail   := null;
  v_asunto      := null;
  v_flag        := FALSE;

  -- Empezamos a cargar los datos del mail a enviar
  v_hini_mail := to_char(sysdate,'hh24:mi:ss');
  --
  v_asunto := 'Reporte de análisis de liquidez 6' || ', a la fecha: '||v_fec_sist||'.';
  v_mje_mail := 'El archivo con los datos del reporte Analisis de liquidez 4 se encuentra adjunto al mail:'||v_name||'_'||v_fecha||'.txt';
  begin
    --**
    v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
    it_mail.attach_text(v_conn,  v_mje_mail,'text/html');

    it_mail.begin_attachment(v_conn,'text/plain',false,v_name||'_'||v_fecha||'.txt');
    --**

      -- Titulo del reporte
      -- Colocar el titulo a los campos
      v_cabecera :=
      'MONEDA'||CHR(9)||
      'CUENTAS'||CHR(9)||
      'MEN_7_DIAS'||CHR(9)||
      'MEN_30_DIAS'||CHR(9)||
      'MEN_60_DIAS'||CHR(9)||
      'MEN_90_DIAS'||CHR(9)||
      'MAY_90_DIAS'||CHR(9)||
      'MONTO'||CHR(9)||
      'INFORME'||CHR(13)||CHR(10);

      --** Arma el Archivo Anexo.
      it_mail.write_text(v_conn,v_cabecera);
      --**

      v_detalle := '';
      -- detalle del reporte
      FOR REC IN CU_ANALIQ6 LOOP
        v_flag := TRUE;
        --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))

        v_detalle := to_char(rec.MONEDA)||chr(9)||
      to_char(rec.CUENTAS)||chr(9)||
      to_char(rec.MEN_7_DIAS)||chr(9)||
      to_char(rec.MEN_30_DIAS)||chr(9)||
      to_char(rec.MEN_60_DIAS)||chr(9)||
      to_char(rec.MEN_90_DIAS)||chr(9)||
      to_char(rec.MAY_90_DIAS)||chr(9)||
      to_char(rec.MONTO)||chr(9)||
      to_char(rec.INFORME)||CHR(13)||CHR(10);
        --Escribir la linea en el archivo
        --**
        it_mail.write_text(v_conn,v_detalle);
        v_detalle := '';
        --**

        EXIT WHEN CU_ANALIQ6%NOTFOUND;
      END LOOP;
    --**
    -- Verificamos si el cursor trajo por lo menos un registro, de ser asi enviamos el mail
    IF v_flag THEN
       it_mail.end_mail(v_conn);
    ELSE
      ROLLBACK;
    END IF;
    --**
  exception
    when utl_smtp.transient_error or utl_smtp.permanent_error then
    begin
      utl_smtp.quit(v_conn);
    exception
    when utl_smtp.transient_error or utl_smtp.permanent_error then
      null;
    end;
    v_det_error := substr(sqlerrm,1,4000);
  end;

  --
  v_hfin_mail := to_char(sysdate,'hh24:mi:ss');

  -- Insertamos en la tabla de log  si ocurrio algun error al enviar el mail
      IF v_det_error is not null THEN
          INSERT INTO ge_ra_log_mail
           (fec_envio, nom_archivo, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
          VALUES
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;
COMMIT;
EXCEPTION
  WHEN OTHERS THEN
    raise_application_error(-20000,'Error al enviar el archivo:'||v_name||sqlerrm);
END pr_analiq6;
-----------------------------------------------------------------------------------------------------
-- REPORTE CALCULO DE DEPOSITOS INTERNOS.
PROCEDURE pr_inv_dep_internos
IS

--Variables.
  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'inv_dep_internos'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_fec_sist         DATE;
  v_fecha            VARCHAR2(8);

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

-- Cursores.
CURSOR c_inv_dep_internos IS
   SELECT a.ano,a.mes,a.tip_saldo,a.nro_cuenta,a.fec_ult_proceso, a.estado, a.cod_moneda,
          a.cod_oficina, a.cod_transaccion, a.can_dia_acumulados, a.sal_acumulado, a.sal_promedio,
          a.val_tasa, a.mto_dep_interno, b.cod_modulo, b.cod_modalidad, c.fec_inicio, c.fec_vencimiento
     FROM ge_cta_dep_internos_det a, ge_cuentas b, pr_cta_prestamos c
    WHERE a.ano = to_char(v_fec_sist,'yyyy')
      AND a.mes = to_char(v_fec_sist,'mm')
      AND a.nro_cuenta = b.nro_cuenta
      AND a.nro_cuenta = c.nro_cuenta
      AND b.cod_modulo = 6
   UNION ALL
   SELECT a.ano,a.mes,a.tip_saldo,a.nro_cuenta,a.fec_ult_proceso, a.estado, a.cod_moneda,
          a.cod_oficina, a.cod_transaccion, a.can_dia_acumulados, a.sal_acumulado, a.sal_promedio,
          a.val_tasa, a.mto_dep_interno, b.cod_modulo, b.cod_modalidad, c.fec_apertura, c.fec_vencimiento
     FROM ge_cta_dep_internos_det a, ge_cuentas b, ah_cta_certificados c
    WHERE a.ano = to_char(v_fec_sist,'yyyy')
      AND a.mes = to_char(v_fec_sist,'mm')
      AND a.nro_cuenta = b.nro_cuenta
      AND a.nro_cuenta = c.nro_cuenta
      AND b.cod_modalidad = 33
   UNION ALL
   SELECT a.ano,a.mes,a.tip_saldo,a.nro_cuenta,a.fec_ult_proceso, a.estado, a.cod_moneda,
          a.cod_oficina, a.cod_transaccion, a.can_dia_acumulados, a.sal_acumulado, a.sal_promedio,
          a.val_tasa, a.mto_dep_interno, b.cod_modulo, b.cod_modalidad, v_fec_sist, v_fec_sist
     FROM ge_cta_dep_internos_det a, ge_cuentas b
    WHERE a.ano = to_char(v_fec_sist,'yyyy')
      AND a.mes = to_char(v_fec_sist,'mm')
      AND a.nro_cuenta = b.nro_cuenta
      AND b.cod_modulo <> 6
      AND b.cod_modalidad <> 33;

BEGIN

  -- Obtenemos la fecha del sistema
  SELECT pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1)
    INTO v_fec_sist
    FROM dual;

  v_fecha := to_char(v_fec_sist,'DDMMYYYY');

  -- Abrir archivo
  v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'.txt','W',32767);

  -- Colocar el titulo a los campos
  v_linetit := 'ANHO'||CHR(9)||'MES'||CHR(9)||'TIP_SALDO'||CHR(9)||'COD_MODULO'||CHR(9)||'COD_MODALIDAD'||CHR(9)||
               'NRO_CUENTA'||CHR(9)||'FEC_INICIO'||CHR(9)||'FEC_VENCIMIENTO'||CHR(9)||'FEC_ULT_PROCESO'||CHR(9)||
               'ESTADO'||CHR(9)||'COD_MONEDA'||CHR(9)||'COD_OFICINA'||CHR(9)||'COD_TRANSACCION'||CHR(9)||
               'CAN_DIA_ACUMULADOS'||CHR(9)||'SAL_ACUMULADO'||CHR(9)||'SAL_PROMEDIO'||CHR(9)||'VAL_TASA'||CHR(9)||
               'MTO_DEP_INTERNO';

  utl_file.put_line(v_file,v_linetit);

  -- Definir una linea en blanco para separar los datos del titulo de los campos
  v_linetit := ' ';
  utl_file.put_line(v_file,v_linetit);

  --Definir un cursor for loop que recorre los datos obtenidos
  FOR reg IN c_inv_dep_internos LOOP

    --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
  v_line := to_char(reg.ano)||chr(9)||to_char(reg.mes)||chr(9)||to_char(reg.tip_saldo)||chr(9)||
            to_char(reg.cod_modulo)||chr(9)||to_char(reg.cod_modalidad)||chr(9)||to_char(reg.nro_cuenta)||chr(9)||
            to_char(reg.fec_inicio)||chr(9)||to_char(reg.fec_vencimiento)||chr(9)||to_char(reg.fec_ult_proceso)||chr(9)||
            to_char(reg.estado)||chr(9)||to_char(reg.cod_moneda)||chr(9)||to_char(reg.cod_oficina)||chr(9)||
            to_char(reg.cod_transaccion)||chr(9)||to_char(reg.can_dia_acumulados)||chr(9)||to_char(reg.sal_acumulado,'9999999999999999D00')||chr(9)||
            to_char(reg.sal_promedio,'9999999999999999D00')||chr(9)||to_char(reg.val_tasa,'999999999999D00')||chr(9)||
            to_char(reg.mto_dep_interno,'9999999999999999D00');

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

  EXIT WHEN c_inv_dep_internos%NOTFOUND;
  END LOOP;

  --Escribes la linea en el fichero
  UTL_FILE.PUT_LINE(v_file, v_buffer);

  --Cerrar el handler al fichero
  UTL_FILE.FCLOSE(v_file);
  COMMIT;

  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_respuesta := pa_file_ftp.fu_put_ascii(pa_rpc_aut.g_ip, pa_rpc_aut.g_port, pa_rpc_aut.g_user,
                                          pa_rpc_aut.g_pass, pa_rpc_aut.g_repository,
                                          v_name||'.txt', g_contabilidad||v_name||'_'||v_fecha||'.txt');

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP

      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pa_rpc_aut.fu_obt_valor_par('RA','REPORTES','INV_DEP_INTERNOS');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte Cálculo Depositos Internos a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_contabilidad||'

      Nombre del Archivo: '||v_name||'_'||v_fecha||'.txt';

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
         it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
         it_mail.end_mail(v_conn);
      EXCEPTION
         WHEN utl_smtp.transient_error OR utl_smtp.permanent_error THEN
            BEGIN
               utl_smtp.quit(v_conn);
            EXCEPTION
               WHEN utl_smtp.transient_error or utl_smtp.permanent_error then
                  NULL;
            END;
            v_det_error := substr(sqlerrm,1,4000);
      END;

      v_hfin_mail := to_char(sysdate,'hh24:mi:ss');

      -- Insertamos en la tabla de log  si ocurrio algun error al enviar el mail
      IF v_det_error IS NOT NULL THEN
         INSERT INTO ge_ra_log_mail
            (fec_envio, nom_archivo, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
         VALUES
            (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
         COMMIT;
      END IF;

  ELSE

    -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error    := null;

    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
       (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
       (SYSDATE, v_name||'_'||v_fecha||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;

    --Enviamos el mail a soporte
    -- Obtenemos direccion de correo de soporte
    v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
    v_asunto := 'Error Reporte Cálculo Depositos Internos a la fecha '||v_fec_sist||'.';
    v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

    v_hini_mail := to_char(sysdate,'hh24:mi:ss');

    BEGIN
       v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
       it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
       it_mail.end_mail(v_conn);
    EXCEPTION
       WHEN utl_smtp.transient_error or utl_smtp.permanent_error then
          BEGIN
             utl_smtp.quit(v_conn);
          EXCEPTION
             WHEN utl_smtp.transient_error OR utl_smtp.permanent_error THEN
                NULL;
          END;
          v_det_error := substr(sqlerrm,1,4000);
    END;

    v_hfin_mail := to_char(sysdate,'hh24:mi:ss');

    -- Insertamos en la tabla de log  si ocurrio algun error al enviar el mail
    IF v_det_error IS NOT NULL THEN
       INSERT INTO ge_ra_log_mail
          (fec_envio, nom_archivo, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
       VALUES
          (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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
END pr_inv_dep_internos;
--------------------------------------------------------------------------------------------------------------------
-- REPORTE SALDO PROMEDIOS DE BALANCE ANTES DE LA EJECUCION DEL PROCESOS DEPOSITOS INTERNOS.
PROCEDURE pr_sal_pro_di
IS

--Cursores.
CURSOR c_sal_promedios IS
   SELECT s.ano, s.mes, s.cod_oficina, k.cod_rubro, k.Descripcion Descripcion, k.cod_moneda,
          s.tot_acu_mon_local sal_acumulado,
          s.can_dia_acumulado,
          (round((((nvl(s.tot_acu_mon_local,0))/s.can_dia_acumulado)),0)) sal_promedio
     FROM cb_sal_promedios_tmp s, cb_rubros k
    WHERE s.cod_rubro = k.cod_rubro
      AND k.imputable = 'S'
      AND abs(nvl(s.tot_acu_mon_local,0)) <> 0
      AND s.cod_rubro LIKE '%25704%'
    ORDER BY 1,3;

-- Variables.
  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'sal_prom_dep_interno'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

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

  -- Variables de fechas
  v_fec_sist         DATE;
  v_fecha            VARCHAR2(8);

BEGIN

   -- Obtenemos la fecha del sistema
   SELECT pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1)
     INTO v_fec_sist
     FROM dual;

   v_fecha := to_char(v_fec_sist,'DDMMYYYY');

   -- Abrir archivo
   v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'.txt','W',32767);

   -- Colocar el titulo a los campos
   v_linetit := 'ANHO'||CHR(9)||'MES'||CHR(9)||'COD_OFICINA'||CHR(9)||'COD_RUBRO'||CHR(9)||'DESCRIPCION'||CHR(9)||
                'MONEDA'||CHR(9)||'SALDO_ACUMULADO'||CHR(9)||'CAN_DIA_ACUMULADO'||CHR(9)||'SAL_PROMEDIO';

   utl_file.put_line(v_file,v_linetit);

   -- Definir una linea en blanco para separar los datos del titulo de los campos
   v_linetit := ' ';
   utl_file.put_line(v_file,v_linetit);

   --Definir un cursor for loop que recorre los datos obtenidos
   FOR reg IN c_sal_promedios LOOP

      --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
      v_line := to_char(reg.ano)||chr(9)||to_char(reg.mes)||chr(9)||to_char(reg.cod_oficina)||chr(9)||to_char(reg.cod_rubro)||chr(9)||
                to_char(reg.descripcion)||chr(9)||to_char(reg.cod_moneda)||chr(9)||to_char(reg.sal_acumulado,'999999999999999999999D00')||chr(9)||
                to_char(reg.can_dia_acumulado)||chr(9)||to_char(reg.sal_promedio,'999999999999999999999D00');

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

      EXIT WHEN c_sal_promedios%NOTFOUND;
   END LOOP;

   --Escribes la linea en el fichero
   UTL_FILE.PUT_LINE(v_file, v_buffer);

   --Cerrar el handler al fichero
   UTL_FILE.FCLOSE(v_file);
   COMMIT;

   v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

   -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
   v_respuesta := pa_file_ftp.fu_put_ascii(pa_rpc_aut.g_ip, pa_rpc_aut.g_port, pa_rpc_aut.g_user,
                                           pa_rpc_aut.g_pass, pa_rpc_aut.g_repository,
                                           v_name||'.txt', g_balances||v_name||'_'||v_fecha||'.txt');

   v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

   IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SAL_PRO_DEP_INTERNOS');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte Balance Saldos Promedio antes del proceso de DI, a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_balances||'

      Nombre del Archivo: '||v_name||'_'||v_fecha||'.txt';

      -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
         it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
         it_mail.end_mail(v_conn);
      EXCEPTION
        WHEN utl_smtp.transient_error or utl_smtp.permanent_error then
           BEGIN
              utl_smtp.quit(v_conn);
           EXCEPTION
              WHEN utl_smtp.transient_error or utl_smtp.permanent_error then
                 NULL;
           END;
           v_det_error := substr(sqlerrm,1,4000);
      END;

      v_hfin_mail := to_char(sysdate,'hh24:mi:ss');

      -- Insertamos en la tabla de log  si ocurrio algun error al enviar el mail
      IF v_det_error is not null THEN
         INSERT INTO ge_ra_log_mail
            (fec_envio, nom_archivo, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
         VALUES
            (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
         COMMIT;
      END IF;

   ELSE
      -- ERROR AL ENVIAR ARCHIVO POR FTP
      v_det_error    := null;

      -- Insertamos el error del envio al directorio compartido
      INSERT INTO ge_ra_log_ftp
         (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
      VALUES
         (SYSDATE, v_name||'_'||v_fecha||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
      COMMIT;

      --Enviamos el mail a soporte
      -- Obtenemos direccion de correo de soporte
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

      -- Damos valor a los demas datos
      v_asunto := 'Error Reporte Balance Saldos Promedio antes del proceso de DI, a la fecha '||v_fecha||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

      Error: '||v_respuesta||'.

      Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
         it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
         it_mail.end_mail(v_conn);
      EXCEPTION
         WHEN utl_smtp.transient_error or utl_smtp.permanent_error then
            BEGIN
               utl_smtp.quit(v_conn);
            EXCEPTION
               WHEN utl_smtp.transient_error or utl_smtp.permanent_error then
                  NULL;
            END;
            v_det_error := substr(sqlerrm,1,4000);
      END;

      v_hfin_mail := to_char(sysdate,'hh24:mi:ss');

      -- Insertamos en la tabla de log  si ocurrio algun error al enviar el mail
      IF v_det_error is not null THEN
         INSERT INTO ge_ra_log_mail
            (fec_envio, nom_archivo, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
         VALUES
            (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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
END pr_sal_pro_di;
--------------------------------------------------------------------------------------------------------------------
-- REPORTE DE VARIACION DE CARTERA (INVERSIÓN RENTABLE, ACTIVOS DUDOSOS Y RECURSOS).
-- Fecha: 03/09/2013 Requerimiento:REG-BBVA-CNF_2279_FATD.01-NVO_ATR_PLA_CUENTAS.doc Realizo por: JF - Nuevos Atributos del Plan de Cuentas
PROCEDURE pr_inv_var_car
IS
   -- Cursor.
   CURSOR c_inv_cuentas IS
   SELECT a.cod_rubro, a.descripcion, a.cod_moneda, a.cod_modalidad, a.cod_oficina, a.tip_saldo,
          a.cod_persona, a.nombre, a.nro_cuenta, a.sal_actual, a.sal_mon_local, a.val_tasa, a.fec_inicio,
          a.fec_vencimiento,
          fue_obt_sig_refcodes('COD_ETI_CAP_RUBROS',b.cod_cap_mis) des_cap_mis,
          fue_obt_sig_refcodes('COD_ETI_GRU_RUBROS',b.cod_gru_mis) des_gru_mis,
          fue_obt_sig_refcodes('COD_ETI_ACT_RUBROS',b.cod_act_mis) des_act_mis,
          fue_obt_sig_refcodes('COD_ETI_SUB_ACT_RUBROS',b.cod_sub_act_mis) des_sub_act_mis,
          'INVENTARIO' tip_cuenta
     FROM bv_finanzas a, cb_cla_rub_mis b
    WHERE a.cod_rubro = b.cod_rubro
      AND b.cod_cap_mis IN (100,110,200)
   UNION
   -- Fecha modificación: 13/02/2014
   -- REG-BBVA-CNF_2380_FAFU.01-AJU_INF_VAR_CARTERA.doc
   SELECT a.cod_rubro, a.descripcion, a.cod_moneda, a.cod_modalidad, a.cod_oficina, a.tip_saldo,
          a.cod_persona, a.nombre, a.nro_cuenta, a.sal_actual, a.sal_mon_local, a.val_tasa, a.fec_inicio,
          a.fec_vencimiento,
          fue_obt_sig_refcodes('COD_ETI_CAP_RUBROS',b.cod_cap_mis) des_cap_mis,
          fue_obt_sig_refcodes('COD_ETI_GRU_RUBROS',b.cod_gru_mis) des_gru_mis,
          fue_obt_sig_refcodes('COD_ETI_ACT_RUBROS',b.cod_act_mis) des_act_mis,
          fue_obt_sig_refcodes('COD_ETI_SUB_ACT_RUBROS',b.cod_sub_act_mis) des_sub_act_mis,
          ' ' tip_cuenta
     FROM bv_cta_can_finanzas a, cb_cla_rub_mis b
    WHERE a.cod_rubro = b.cod_rubro
      AND b.cod_cap_mis IN (100,110,200);

   -- Variables
   v_fec_actual    cb_sal_inventarios_his.fecha%type;
   v_fec_anterior  cb_sal_inventarios_his.fecha%type;
   v_sal_anterior  cb_sal_inventarios.sal_total%type := 0;
   v_mto_variacion cb_sal_inventarios.sal_total%type := 0;

   -- FTP
   v_file             UTL_FILE.FILE_TYPE;
   v_line             VARCHAR2(32767);
   v_linetit          VARCHAR2(2000);
   v_buffer           VARCHAR2(32767);
   v_name             VARCHAR2(128) := 'var_cartera';
   v_lines            PLS_INTEGER := 0;
   v_eol              CONSTANT VARCHAR2(1) := CHR(10);
   v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
   v_maxline          CONSTANT PLS_INTEGER := 32767;

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

   -- Variables de fechas
   v_fecha            VARCHAR2(8);

BEGIN

   -- Obtengo la fecha de los informes
   v_fec_actual   := pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1);
   v_fec_anterior := pag_cal.fu_obt_fec_ant_hab(v_fec_actual,null);

   -- Formato de fecha para el informe.
   v_fecha := to_char(v_fec_actual,'DDMMYYYY');

   -- Abrir archivo
   v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'.txt','W',32767);

   -- Colocar el titulo a los campos
   v_linetit := 'COD_RUBRO'||CHR(9)||'DESCRIPCION'||CHR(9)||'COD_MONEDA'||CHR(9)||'COD_MODALIDAD'||CHR(9)||
                'COD_OFICINA'||CHR(9)||'TIP_SALDO'||CHR(9)||'COD_PERSONA'||CHR(9)||'NOM_PERSONA'||CHR(9)||
                'NRO_CUENTA'||CHR(9)||'SAL_ACTUAL'||CHR(9)||'SAL_MON_LOCAL'||CHR(9)||'SAL_MON_LOC_ANTERIOR'||CHR(9)||
                'MTO_VARIACION'||CHR(9)||'VAL_TASA'||CHR(9)||'FEC_INICIO'||CHR(9)||'FEC_VENCIMIENTO'||CHR(9)||
                'CAP_MIS'||CHR(9)||'GRU_MIS'||CHR(9)||'ACT_MIS'||CHR(9)||'SUB_ACT_MIS';

   utl_file.put_line(v_file,v_linetit);

   -- Definir una linea en blanco para separar los datos del titulo de los campos
   v_linetit := ' ';
   utl_file.put_line(v_file,v_linetit);

   --Definir un cursor for loop que recorre los datos obtenidos
   FOR reg IN c_inv_cuentas LOOP
      -- Obtengo el saldo de la cuenta del día anterior.
      -- Fecha modificación: 13/02/2014
      -- REG-BBVA-CNF_2380_FAFU.01-AJU_INF_VAR_CARTERA.doc
      IF reg.tip_cuenta = 'INVENTARIO' THEN
         SELECT nvl(sum(b.sal_actual),0)
           INTO v_sal_anterior
           FROM cb_sal_inventarios_his a, cb_sal_inventarios_det_his b
          WHERE a.fecha = b.fecha
            AND a.nro_referencia = b.nro_referencia
            AND a.fecha = v_fec_anterior
            AND a.cod_rubro = reg.cod_rubro
            AND b.nro_cuenta = reg.nro_cuenta;

         -- Cálculo la variación.
         v_mto_variacion := reg.sal_actual - v_sal_anterior;

         --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
         v_line := to_char(REG.COD_RUBRO)||chr(9)||to_char(REG.DESCRIPCION)||chr(9)||to_char(REG.COD_MONEDA)||chr(9)||
                to_char(REG.COD_MODALIDAD)||chr(9)||to_char(REG.COD_OFICINA)||chr(9)||to_char(REG.TIP_SALDO)||chr(9)||
                to_char(REG.COD_PERSONA)||chr(9)||to_char(REG.NOMBRE)||chr(9)||to_char(REG.NRO_CUENTA)||chr(9)||
                to_char(REG.SAL_ACTUAL,'999999999999D00')||chr(9)||to_char(REG.SAL_MON_LOCAL,'999999999999D00')||chr(9)||
                to_char(V_SAL_ANTERIOR,'999999999999D00')||chr(9)||to_char(V_MTO_VARIACION,'999999999999D00')||chr(9)||
                to_char(REG.VAL_TASA,'999999999999D00')||chr(9)||to_char(REG.FEC_INICIO)||chr(9)||to_char(REG.FEC_VENCIMIENTO)||chr(9)||
                to_char(REG.DES_CAP_MIS)||chr(9)||to_char(REG.DES_GRU_MIS)||chr(9)||to_char(REG.DES_ACT_MIS)||chr(9)||
                to_char(REG.DES_SUB_ACT_MIS);
      ELSE
         -- Fecha modificación: 13/02/2014
         -- REG-BBVA-CNF_2380_FAFU.01-AJU_INF_VAR_CARTERA.doc
         -- Cálculo la variación.
         v_sal_anterior := NVL(reg.sal_actual,0);
         v_mto_variacion := 0 - v_sal_anterior;

         --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
         v_line := to_char(REG.COD_RUBRO)||chr(9)||to_char(REG.DESCRIPCION)||chr(9)||to_char(REG.COD_MONEDA)||chr(9)||
                to_char(REG.COD_MODALIDAD)||chr(9)||to_char(REG.COD_OFICINA)||chr(9)||to_char(REG.TIP_SALDO)||chr(9)||
                to_char(REG.COD_PERSONA)||chr(9)||to_char(REG.NOMBRE)||chr(9)||to_char(REG.NRO_CUENTA)||chr(9)||
                to_char('0','999999999999D00')||chr(9)||to_char('0','999999999999D00')||chr(9)||
                to_char(V_SAL_ANTERIOR,'999999999999D00')||chr(9)||to_char(V_MTO_VARIACION,'999999999999D00')||chr(9)||
                to_char(REG.VAL_TASA,'999999999999D00')||chr(9)||to_char(REG.FEC_INICIO)||chr(9)||to_char(REG.FEC_VENCIMIENTO)||chr(9)||
                to_char(REG.DES_CAP_MIS)||chr(9)||to_char(REG.DES_GRU_MIS)||chr(9)||to_char(REG.DES_ACT_MIS)||chr(9)||
                to_char(REG.DES_SUB_ACT_MIS);
      END IF;

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

      EXIT WHEN c_inv_cuentas%NOTFOUND;
   END LOOP;

   --Escribes la linea en el fichero
   UTL_FILE.PUT_LINE(v_file, v_buffer);

   --Cerrar el handler al fichero
   UTL_FILE.FCLOSE(v_file);
   COMMIT;

   v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

   -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
   v_respuesta := pa_file_ftp.fu_put_ascii(pa_rpc_aut.g_ip, pa_rpc_aut.g_port, pa_rpc_aut.g_user,
                                           pa_rpc_aut.g_pass, pa_rpc_aut.g_repository,
                                           v_name||'.txt', g_finanzas||v_name||'_'||v_fecha||'.txt');

   v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

   IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','VAR_CARTERA');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte de Variación de Cartera, a la fecha '||v_fec_actual||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_finanzas||'

      Nombre del Archivo: '||v_name||'_'||v_fecha||'.txt';

      -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
         it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
         it_mail.end_mail(v_conn);
      EXCEPTION
        WHEN utl_smtp.transient_error or utl_smtp.permanent_error then
           BEGIN
              utl_smtp.quit(v_conn);
           EXCEPTION
              WHEN utl_smtp.transient_error or utl_smtp.permanent_error then
                 NULL;
           END;
           v_det_error := substr(sqlerrm,1,4000);
      END;

      v_hfin_mail := to_char(sysdate,'hh24:mi:ss');

      -- Insertamos en la tabla de log  si ocurrio algun error al enviar el mail
      IF v_det_error is not null THEN
         INSERT INTO ge_ra_log_mail
            (fec_envio, nom_archivo, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
         VALUES
            (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
         COMMIT;
      END IF;

   ELSE
      -- ERROR AL ENVIAR ARCHIVO POR FTP
      v_det_error    := null;

      -- Insertamos el error del envio al directorio compartido
      INSERT INTO ge_ra_log_ftp
         (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
      VALUES
         (SYSDATE, v_name||'_'||v_fecha||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
      COMMIT;

      --Enviamos el mail a soporte
      -- Obtenemos direccion de correo de soporte
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

      -- Damos valor a los demas datos
      v_asunto := 'Error Reporte de Variación de Cartera, a la fecha '||v_fecha||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

      Error: '||v_respuesta||'.

      Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
         it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
         it_mail.end_mail(v_conn);
      EXCEPTION
         WHEN utl_smtp.transient_error or utl_smtp.permanent_error then
            BEGIN
               utl_smtp.quit(v_conn);
            EXCEPTION
               WHEN utl_smtp.transient_error or utl_smtp.permanent_error then
                  NULL;
            END;
            v_det_error := substr(sqlerrm,1,4000);
      END;

      v_hfin_mail := to_char(sysdate,'hh24:mi:ss');

      -- Insertamos en la tabla de log  si ocurrio algun error al enviar el mail
      IF v_det_error is not null THEN
         INSERT INTO ge_ra_log_mail
            (fec_envio, nom_archivo, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
         VALUES
            (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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
END;
-----------------------------------------------------------------------------------------------------
-- REPORTE DE INVENTARIO DE VENTA DE CARTERA.
PROCEDURE pr_vta_cartera
IS
-- Cursor.
   CURSOR c_inv_vta_cartera IS
   SELECT gs.fecha, gs.cod_persona, gs.nom_completo, gs.nro_documento, gs.cli_nomina, gs.fec_ult_acreditacion,
       gs.cod_oficina, gs.nro_cuenta, gs.tip_producto, gs.gar_cliente, gs.gar_ven_cliente, gs.nro_tarjeta,
       gs.afinidad, gs.cod_per_codeudor, gs.gar_codeudor, gs.gar_ven_codeudor, gs.gestor, gs.mto_deuda, gs.mto_previsiones,
       gs.dia_atrasos, gs.cat_cliente, gs.tot_riesgo, gs.fec_ult_cat_sistema, gs.cat_sistema, gs.tot_deu_sistema,
       gs.tot_deu_con_sistema, gs.tot_deu_cod_sistema, gs.tot_cuotas, gs.tot_cuo_vencidas, gs.tip_bloqueo, gs.tip_inhibicion,
       gs.tel_particular, gs.dir_particular, gs.tel_laboral, gs.dir_laboral
     FROM ge_sal_inv_vta_cartera_tmp gs;

   -- Variables
   v_fec_actual    cb_sal_inventarios_his.fecha%type;

   -- FTP
   v_file             UTL_FILE.FILE_TYPE;
   v_line             VARCHAR2(32767);
   v_linetit          VARCHAR2(2000);
   v_buffer           VARCHAR2(32767);
   v_name             VARCHAR2(128) := 'inv_vta_cartera';
   v_lines            PLS_INTEGER := 0;
   v_eol              CONSTANT VARCHAR2(1) := CHR(10);
   v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
   v_maxline          CONSTANT PLS_INTEGER := 32767;

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

   -- Variables de fechas
   v_fecha            VARCHAR2(8);

BEGIN

   -- Obtengo la fecha de los informes
   v_fec_actual := pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1);

   -- Formato de fecha para el informe.
   v_fecha := to_char(v_fec_actual,'DDMMYYYY');

   -- Abrir archivo
   v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'.txt','W',32767);

   -- Colocar el titulo a los campos
   v_linetit := 'FECHA'||CHR(9)||'COD_PERSONA'||CHR(9)||'NOM_COMPLETO'||CHR(9)||'NRO_DOCUMENTO'||CHR(9)||
                'CLI_NOMINA'||CHR(9)||'FEC_ULT_ACREDITACION'||CHR(9)||'COD_OFICINA'||CHR(9)||'NRO_CUENTA'||CHR(9)||
                'TIP_PRODUCTO'||CHR(9)||'GAR_CLIENTE'||CHR(9)||'GAR_VEN_CLIENTE'||CHR(9)||'NRO_TARJETA'||CHR(9)||
                'AFINIDAD'||CHR(9)||'COD_PER_CODEUDOR'||CHR(9)||'GAR_CODEUDOR'||CHR(9)||'GAR_VEN_CODEUDOR'||CHR(9)||
                'GESTOR'||CHR(9)||'MTO_DEUDA'||CHR(9)||'MTO_PREVISIONES'||CHR(9)||'DIA_ATRASOS'||CHR(9)||
                'CAT_CLIENTE'||CHR(9)||'TOT_RIESGO'||CHR(9)||'FEC_ULT_CAT_SISTEMA'||CHR(9)||'CAT_SISTEMA'||CHR(9)||
                'TOT_DEU_SISTEMA'||CHR(9)||'TOT_DEU_CON_SISTEMA'||CHR(9)||'TOT_DEU_COD_SISTEMA'||CHR(9)||
                'TOT_CUOTAS'||CHR(9)||'TOT_CUO_VENCIDAS'||CHR(9)||'TIP_BLOQUEO'||CHR(9)||'TIP_INHIBICION'||CHR(9)||
                'TEL_PARTICULAR'||CHR(9)||'DIR_PARTICULAR'||CHR(9)||'TEL_LABORAL'||CHR(9)||'DIR_LABORAL';

   utl_file.put_line(v_file,v_linetit);

   -- Definir una linea en blanco para separar los datos del titulo de los campos
   v_linetit := ' ';
   utl_file.put_line(v_file,v_linetit);

   --Definir un cursor for loop que recorre los datos obtenidos
   FOR reg IN c_inv_vta_cartera LOOP

      --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
      v_line := to_char(REG.FECHA)||chr(9)||to_char(REG.COD_PERSONA)||chr(9)||to_char(REG.NOM_COMPLETO)||chr(9)||
                to_char(REG.NRO_DOCUMENTO)||chr(9)||to_char(REG.CLI_NOMINA)||chr(9)||to_char(REG.FEC_ULT_ACREDITACION)||chr(9)||
                to_char(REG.COD_OFICINA)||chr(9)||to_char(REG.NRO_CUENTA)||chr(9)||to_char(REG.TIP_PRODUCTO)||chr(9)||
                to_char(REG.GAR_CLIENTE)||chr(9)||to_char(REG.GAR_VEN_CLIENTE)||chr(9)||to_char(REG.NRO_TARJETA)||chr(9)||
                to_char(REG.AFINIDAD)||chr(9)||to_char(REG.COD_PER_CODEUDOR)||chr(9)||to_char(REG.GAR_CODEUDOR)||chr(9)||
                to_char(REG.GAR_VEN_CODEUDOR)||chr(9)||to_char(REG.GESTOR)||chr(9)||to_char(REG.MTO_DEUDA,'999999999999999D00')||chr(9)||
                to_char(REG.MTO_PREVISIONES,'999999999999999D00')||chr(9)||to_char(REG.DIA_ATRASOS)||chr(9)||
                to_char(REG.CAT_CLIENTE)||chr(9)||to_char(REG.TOT_RIESGO,'999999999999999D00')||chr(9)||to_char(REG.FEC_ULT_CAT_SISTEMA)||chr(9)||
                to_char(REG.CAT_SISTEMA)||chr(9)||to_char(REG.TOT_DEU_SISTEMA,'999999999999999D00')||chr(9)||
                to_char(REG.TOT_DEU_CON_SISTEMA,'999999999999999D00')||chr(9)||to_char(REG.TOT_DEU_COD_SISTEMA,'999999999999999D00')||chr(9)||
                to_char(REG.TOT_CUOTAS)||chr(9)||to_char(REG.TOT_CUO_VENCIDAS)||chr(9)||to_char(REG.TIP_BLOQUEO)||chr(9)||
                to_char(REG.TIP_INHIBICION)||chr(9)||to_char(REG.TEL_PARTICULAR)||chr(9)||
                to_char(REG.DIR_PARTICULAR)||chr(9)||to_char(REG.TEL_LABORAL)||chr(9)||to_char(REG.DIR_LABORAL);

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

      EXIT WHEN c_inv_vta_cartera%NOTFOUND;
   END LOOP;

   --Escribes la linea en el fichero
   UTL_FILE.PUT_LINE(v_file, v_buffer);

   --Cerrar el handler al fichero
   UTL_FILE.FCLOSE(v_file);
   COMMIT;

   v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

   -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
   v_respuesta := pa_file_ftp.fu_put_ascii(pa_rpc_aut.g_ip, pa_rpc_aut.g_port, pa_rpc_aut.g_user,
                                           pa_rpc_aut.g_pass, pa_rpc_aut.g_repository,
                                           v_name||'.txt', g_riesgos||v_name||'_'||v_fecha||'.txt');

   v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

   IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','INV_VTA_CARTERA');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte - Inventario de Venta de Cartera, a la fecha '||v_fec_actual||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_riesgos||'

      Nombre del Archivo: '||v_name||'_'||v_fecha||'.txt';

      -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
         it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
         it_mail.end_mail(v_conn);
      EXCEPTION
        WHEN utl_smtp.transient_error or utl_smtp.permanent_error then
           BEGIN
              utl_smtp.quit(v_conn);
           EXCEPTION
              WHEN utl_smtp.transient_error or utl_smtp.permanent_error then
                 NULL;
           END;
           v_det_error := substr(sqlerrm,1,4000);
      END;

      v_hfin_mail := to_char(sysdate,'hh24:mi:ss');

      -- Insertamos en la tabla de log  si ocurrio algun error al enviar el mail
      IF v_det_error is not null THEN
         INSERT INTO ge_ra_log_mail
            (fec_envio, nom_archivo, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
         VALUES
            (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
         COMMIT;
      END IF;

   ELSE
      -- ERROR AL ENVIAR ARCHIVO POR FTP
      v_det_error    := null;

      -- Insertamos el error del envio al directorio compartido
      INSERT INTO ge_ra_log_ftp
         (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
      VALUES
         (SYSDATE, v_name||'_'||v_fecha||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
      COMMIT;

      --Enviamos el mail a soporte
      -- Obtenemos direccion de correo de soporte
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

      -- Damos valor a los demas datos
      v_asunto := 'Error Reporte - Inventario de Venta de Cartera, a la fecha '||v_fecha||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

      Error: '||v_respuesta||'.

      Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
         it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
         it_mail.end_mail(v_conn);
      EXCEPTION
         WHEN utl_smtp.transient_error or utl_smtp.permanent_error then
            BEGIN
               utl_smtp.quit(v_conn);
            EXCEPTION
               WHEN utl_smtp.transient_error or utl_smtp.permanent_error then
                  NULL;
            END;
            v_det_error := substr(sqlerrm,1,4000);
      END;

      v_hfin_mail := to_char(sysdate,'hh24:mi:ss');

      -- Insertamos en la tabla de log  si ocurrio algun error al enviar el mail
      IF v_det_error is not null THEN
         INSERT INTO ge_ra_log_mail
            (fec_envio, nom_archivo, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
         VALUES
            (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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
END;
-----------------------------------------------------------------------------------------------------
 -- Información de Extractos
PROCEDURE pr_inf_ext
IS
CURSOR cu_ext(p_fecha DATE) IS
     select cta.cod_persona cliente,
            pe.nro_documento,
             replace(replace(cta.nom_cliente,'.',''),',','') Nombre,
             replace(replace(NVL(cta.direccion,fue_obt_dir_principa(cta.cod_persona)),'.',''),',','') Direccion,
             ci.descripcion ciudad,
             substr(cta.telefono,1,instr(cta.telefono,' ')) Prefijo, telefono,
             cta.cod_oficina sucursal, cta.cod_per_empresa empresa,
             cta.tip_impresion, cta.cod_extracto,
             decode(cta.tip_direccion, 'R', 'Retener') retener,
             decode(cta.cli_confidencial,'S','SI','NO') Confidencial,
             decode(ge.cli_especial,'S','SI','NO') Especial,
             sg.descripcion seg_preferente
        from ge_ext_clientes cta, ge_clientes ge, ba_personas pe, ba_ciudades ci, ge_seg_preferentes sg
       where cta.funcionario = 'N' --- No traer funcionarios
         and cta.fec_extracto = p_fecha
         and cta.tip_impresion not in ('N','Z')
         and cta.fre_extracto = 'M'
         and cta.cod_persona = ge.cod_persona
         and ge.cod_persona = pe.cod_persona
         and cta.cod_ciudad = ci.cod_ciudad(+)
         and cta.cod_pais = ci.cod_pais(+)
         and ge.cod_seg_preferente = sg.cod_seg_preferente(+)
         /*and exists (Select 's' from ge_ext_cli_movimientos a
                     where a.cod_persona = cta.cod_persona
                     and   a.cod_extracto = cta.cod_extracto )*/
         and exists  (Select 's' from ge_ext_cli_movimientos t
                  where t.cod_Extracto = cta.cod_extracto
                  and t.cod_persona = cta.cod_persona
                  and t.fec_extracto = p_fecha)
     
     
     


       order by cta.cod_oficina, NVL(cta.cod_per_empresa,'0'), to_number(cta.cod_persona);


  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'inf_extractos'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_fec_sist         DATE;
  v_fecha            VARCHAR2(8);

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
  select pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1)
  into v_fec_sist
  from dual;

  v_fecha := to_char(v_fec_sist,'DDMMYYYY');

-- Abrir archivo
v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'.txt','W',32767);

-- Colocar el titulo a los campos
v_linetit := 'CLIENTE'||CHR(9)||'NRO_DOCUMENTO'||CHR(9)||'NOMBRE'||CHR(9)||'DIRECCION'||CHR(9)||'CIUDAD'||CHR(9)||/*'PREFIJO'||CHR(9)||*/
              'TELEFONO'||CHR(9)||'SUCURSAL'||CHR(9)||'EMPRESA'||CHR(9)||'TIP_IMPRESION'||CHR(9)||'COD_EXTRACTO'||CHR(9)||
              'RETENER'||CHR(9)||'CONFIDENCIAL'||CHR(9)||'ESPECIAL'||CHR(9)||'SEG_PREFERENTE';
utl_file.put_line(v_file,v_linetit);

-- Definir una linea en blanco para separar los datos del titulo de los campos
v_linetit := ' ';
utl_file.put_line(v_file,v_linetit);

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN cu_ext(v_fec_sist) LOOP

    --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
  v_line := to_char(rec.CLIENTE)||chr(9)||to_char(rec.NRO_DOCUMENTO)||chr(9)||to_char(rec.NOMBRE)||chr(9)||to_char(rec.DIRECCION)||chr(9)||
            to_char(rec.CIUDAD)||chr(9)||/*to_char(rec.prefijo)||chr(9)||*/to_char(rec.TELEFONO)||chr(9)||to_char(rec.SUCURSAL)||chr(9)||
            to_char(rec.EMPRESA)||chr(9)||to_char(rec.TIP_IMPRESION)||chr(9)||to_char(rec.COD_EXTRACTO)||chr(9)||to_char(rec.RETENER)||chr(9)||
            to_char(rec.CONFIDENCIAL)||chr(9)||to_char(rec.ESPECIAL)||chr(9)||to_char(rec.SEG_PREFERENTE);

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

  EXIT WHEN cu_ext%NOTFOUND;
END LOOP;
--Escribes la linea en el fichero
UTL_FILE.PUT_LINE(v_file, v_buffer);

--Cerrar el handler al fichero
UTL_FILE.FCLOSE(v_file);
COMMIT;

  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_respuesta := pa_file_ftp.fu_put_ascii(pa_rpc_aut.g_ip, pa_rpc_aut.g_port, pa_rpc_aut.g_user,
                                          pa_rpc_aut.g_pass, pa_rpc_aut.g_repository,
                                          v_name||'.txt', g_extractos||v_name||'_'||v_fecha||'.txt');

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','NORMAL_RETENER');

      -- Damos valor a los demas datos
      v_asunto := 'Informe de extractos a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_extractos||'

    Nombre del Archivo: '||v_name||'_'||v_fecha||'.txt';

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error    := null;

    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, v_name||'_'||v_fecha||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;

    --Enviamos el mail a soporte
     -- Obtenemos direccion de correo de soporte
     v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error Reporte de extractos a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
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
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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
END pr_inf_ext;
-------------------------------------------------------------------------------------------------------------------------------------
-- Resumen de Cuentas de la Venta de Cartera.
PROCEDURE pr_inf_vta_cartera
IS
-- Cursor.
   CURSOR c_vta_cartera IS
   SELECT bm.cod_modulo, bm.descripcion des_modulo, gm.cod_modalidad, gm.descripcion des_modalidad, a.nro_cuenta, a.cod_moneda,
          SUM((CASE WHEN a.cod_transaccion NOT IN (957,8843) THEN
                (CASE WHEN gt.tipo = 'C' THEN
                    NVL(a.monto,0)
                 ELSE
                    NVL(a.monto,0) * (-1)
                 END)
               ELSE
                  0
               END)) deuda,
          SUM((CASE WHEN a.cod_transaccion = 957 THEN nvl(a.monto,0) ELSE 0 END)) prevision,
          SUM((CASE WHEN a.cod_transaccion = 8843 THEN nvl(a.monto,0) ELSE 0 END)) perdida
     FROM ge_movimientos a, ge_transacciones gt, ba_modulos bm, ge_modalidades gm
    WHERE a.hora IN (SELECT gv.hora
                       FROM ge_movimientos gv
                      WHERE gv.fecha = a.fecha
                        AND gv.cod_usuario = a.cod_usuario
                        AND gv.referencia = '8843')
      AND a.cod_transaccion = gt.cod_transaccion
      AND a.cod_modalidad = gt.cod_modalidad
      AND a.cod_modulo = bm.cod_modulo
      AND a.cod_modulo = gm.cod_modulo
      AND a.cod_modalidad = gm.cod_modalidad
    GROUP BY bm.cod_modulo, bm.descripcion, gm.cod_modalidad, gm.descripcion, a.nro_cuenta, a.cod_moneda;

   -- Variables
   v_fec_actual    cb_sal_inventarios_his.fecha%type;

   -- FTP
   v_file             UTL_FILE.FILE_TYPE;
   v_line             VARCHAR2(32767);
   v_linetit          VARCHAR2(2000);
   v_buffer           VARCHAR2(32767);
   v_name             VARCHAR2(128) := 'res_vta_cartera';
   v_lines            PLS_INTEGER := 0;
   v_eol              CONSTANT VARCHAR2(1) := CHR(10);
   v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
   v_maxline          CONSTANT PLS_INTEGER := 32767;

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

   -- Variables de fechas
   v_fecha            VARCHAR2(8);

BEGIN

   -- Obtengo la fecha de los informes
   v_fec_actual   := pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1);

   -- Formato de fecha para el informe.
   v_fecha := to_char(v_fec_actual,'DDMMYYYY');

   -- Abrir archivo
   v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'.txt','W',32767);

   -- Colocar el titulo a los campos
   v_linetit := 'COD_MODULO'||CHR(9)||'DES_MODULO'||CHR(9)||'COD_MODALIDAD'||CHR(9)||'DES_MODALIDAD'||CHR(9)||
                'NRO_CUENTA'||CHR(9)||'COD_MONEDA'||CHR(9)||'DEUDA'||CHR(9)||'PREVISION'||CHR(9)||'PERDIDA';

   utl_file.put_line(v_file,v_linetit);

   -- Definir una linea en blanco para separar los datos del titulo de los campos
   v_linetit := ' ';
   utl_file.put_line(v_file,v_linetit);

   --Definir un cursor for loop que recorre los datos obtenidos
   FOR reg IN c_vta_cartera LOOP

      --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
      v_line := to_char(REG.COD_MODULO)||chr(9)||to_char(REG.DES_MODULO)||chr(9)||to_char(REG.COD_MODALIDAD)||chr(9)||
                to_char(REG.DES_MODALIDAD)||chr(9)||to_char(REG.NRO_CUENTA)||chr(9)||to_char(REG.COD_MONEDA)||chr(9)||
                to_char(REG.DEUDA,'999999999999D00')||chr(9)||to_char(REG.PREVISION,'999999999999D00')||chr(9)||
                to_char(REG.PERDIDA,'999999999999D00');

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

      EXIT WHEN c_vta_cartera%NOTFOUND;
   END LOOP;

   --Escribes la linea en el fichero
   UTL_FILE.PUT_LINE(v_file, v_buffer);

   --Cerrar el handler al fichero
   UTL_FILE.FCLOSE(v_file);
   COMMIT;

   v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

   -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
   v_respuesta := pa_file_ftp.fu_put_ascii(pa_rpc_aut.g_ip, pa_rpc_aut.g_port, pa_rpc_aut.g_user,
                                           pa_rpc_aut.g_pass, pa_rpc_aut.g_repository,
                                           v_name||'.txt', g_finanzas||v_name||'_'||v_fecha||'.txt');

   v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

   IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','RES_VTA_CARTERA');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte de Venta de Cartera, a la fecha '||v_fec_actual||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_finanzas||'

      Nombre del Archivo: '||v_name||'_'||v_fecha||'.txt';

      -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
         it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
         it_mail.end_mail(v_conn);
      EXCEPTION
        WHEN utl_smtp.transient_error or utl_smtp.permanent_error then
           BEGIN
              utl_smtp.quit(v_conn);
           EXCEPTION
              WHEN utl_smtp.transient_error or utl_smtp.permanent_error then
                 NULL;
           END;
           v_det_error := substr(sqlerrm,1,4000);
      END;

      v_hfin_mail := to_char(sysdate,'hh24:mi:ss');

      -- Insertamos en la tabla de log  si ocurrio algun error al enviar el mail
      IF v_det_error is not null THEN
         INSERT INTO ge_ra_log_mail
            (fec_envio, nom_archivo, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
         VALUES
            (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
         COMMIT;
      END IF;

   ELSE
      -- ERROR AL ENVIAR ARCHIVO POR FTP
      v_det_error    := null;

      -- Insertamos el error del envio al directorio compartido
      INSERT INTO ge_ra_log_ftp
         (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
      VALUES
         (SYSDATE, v_name||'_'||v_fecha||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
      COMMIT;

      --Enviamos el mail a soporte
      -- Obtenemos direccion de correo de soporte
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

      -- Damos valor a los demas datos
      v_asunto := 'Error Reporte de Venta de Cartera, a la fecha '||v_fecha||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

      Error: '||v_respuesta||'.

      Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
         it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
         it_mail.end_mail(v_conn);
      EXCEPTION
         WHEN utl_smtp.transient_error or utl_smtp.permanent_error then
            BEGIN
               utl_smtp.quit(v_conn);
            EXCEPTION
               WHEN utl_smtp.transient_error or utl_smtp.permanent_error then
                  NULL;
            END;
            v_det_error := substr(sqlerrm,1,4000);
      END;

      v_hfin_mail := to_char(sysdate,'hh24:mi:ss');

      -- Insertamos en la tabla de log  si ocurrio algun error al enviar el mail
      IF v_det_error is not null THEN
         INSERT INTO ge_ra_log_mail
            (fec_envio, nom_archivo, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
         VALUES
            (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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
END;
-------------------------------------------------------------------------------------------------------------------------------------
-- Informe del Proceso de Derrama de Gastos.
PROCEDURE pr_inf_der_gastos
IS
   -- Variables
   v_fec_actual    cb_sal_inventarios_his.fecha%type;

   -- Cursor.
   CURSOR c_vta_cartera IS
   SELECT v.fecha, v.cod_oficina, v.cod_rubro, v.cod_area, v.cod_modulo, v.des_modulo,
          v.cod_modalidad, v.des_modalidad, v.cod_transaccion, v.cod_moneda, SUM(v.importe) importe,
          v.cod_tip_distribucion, v.referencia, v.cod_direccion, v.des_direccion, v.cod_gerencia,
          v.des_gerencia, v.cod_ger_zonal, v.des_ger_zonal, v.cod_departamento, v.des_departamento,
          ba.descripcion des_area
     FROM (
          SELECT ci.fecha, ci.cod_oficina, ci.cod_rubro,
                 NVL(pab_gto.fu_obt_rel_cen_costos(ci.cod_area),ci.cod_area) cod_area,
                 ci.cod_modulo, bm.descripcion des_modulo, ci.cod_modalidad, gm.descripcion des_modalidad,
                 ci.cod_transaccion, ci.cod_moneda, NVL(ci.importe,0) importe, ci.cod_tip_distribucion, ci.referencia,
                 cj.cod_direccion, cj.des_direccion, cj.cod_gerencia, cj.des_gerencia, cj.cod_ger_zonal, cj.des_ger_zonal,
                 cj.cod_departamento, cj.des_departamento
            FROM cb_inf_der_gastos ci, cb_jer_der_gastos cj, ba_modulos bm, ge_modalidades gm
           WHERE ci.fecha = v_fec_actual
             AND ci.cod_area = cj.cod_area(+)
             AND ci.cod_oficina = cj.cod_oficina(+)
             AND ci.cod_modulo = bm.cod_modulo
             AND ci.cod_modulo = gm.cod_modulo
             AND ci.cod_modalidad = gm.cod_modalidad) v, ba_areas ba
    WHERE v.cod_area = ba.cod_area(+)
      AND v.cod_oficina = ba.cod_oficina(+)
    GROUP BY v.fecha, v.cod_oficina, v.cod_rubro, v.cod_area, v.cod_modulo, v.des_modulo,
             v.cod_modalidad, v.des_modalidad, v.cod_transaccion, v.cod_moneda,
             v.cod_tip_distribucion, v.referencia, v.cod_direccion, v.des_direccion, v.cod_gerencia,
             v.des_gerencia, v.cod_ger_zonal, v.des_ger_zonal, v.cod_departamento, v.des_departamento,
             ba.descripcion;

   -- FTP
   v_file             UTL_FILE.FILE_TYPE;
   v_line             VARCHAR2(32767);
   v_linetit          VARCHAR2(2000);
   v_buffer           VARCHAR2(32767);
   v_name             VARCHAR2(128) := 'inv_der_gastos';
   v_lines            PLS_INTEGER := 0;
   v_eol              CONSTANT VARCHAR2(1) := CHR(10);
   v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
   v_maxline          CONSTANT PLS_INTEGER := 32767;

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

   -- Variables de fechas
   v_fecha            VARCHAR2(8);

BEGIN

   -- Obtengo la fecha de los informes
   v_fec_actual   := pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),7,1);

   -- Formato de fecha para el informe.
   v_fecha := to_char(v_fec_actual,'DDMMYYYY');

   -- Abrir archivo
   v_file := UTL_FILE.FOPEN(pa_rpc_aut.g_repository,v_name||'.txt','W',32767);

   -- Colocar el titulo a los campos
   v_linetit := 'FECHA'||CHR(9)||'COD_OFICINA'||CHR(9)||'COD_RUBRO'||CHR(9)||'COD_AREA'||CHR(9)||
                'DES_AREA'||CHR(9)||'COD_MODULO'||CHR(9)||'DES_MODULO'||CHR(9)||'COD_MODALIDAD'||CHR(9)||
                'DES_MODALIDAD'||CHR(9)||'COD_TRANSACCION'||CHR(9)||'COD_MONEDA'||CHR(9)||'IMPORTE'||CHR(9)||
                'COD_TIP_DISTRIBUCION'||CHR(9)||'REFERENCIA'||CHR(9)||'COD_DIRECCION'||CHR(9)||'DES_DIRECCION'||CHR(9)||
                'COD_GERENCIA'||CHR(9)||'DES_GERENCIA'||CHR(9)||'COD_GER_ZONAL'||CHR(9)||'DES_GER_ZONAL'||CHR(9)||
                'COD_DEPARTAMENTO'||CHR(9)||'DES_DEPARTAMENTO';

   utl_file.put_line(v_file,v_linetit);

   -- Definir una linea en blanco para separar los datos del titulo de los campos
   v_linetit := ' ';
   utl_file.put_line(v_file,v_linetit);

   --Definir un cursor for loop que recorre los datos obtenidos
   FOR reg IN c_vta_cartera LOOP

      --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
      v_line := to_char(REG.FECHA)||chr(9)||to_char(REG.COD_OFICINA)||chr(9)||to_char(REG.COD_RUBRO)||chr(9)||
                to_char(REG.COD_AREA)||chr(9)||to_char(REG.DES_AREA)||chr(9)||to_char(REG.COD_MODULO)||chr(9)||
                to_char(REG.DES_MODULO)||chr(9)||to_char(REG.COD_MODALIDAD)||chr(9)||to_char(REG.DES_MODALIDAD)||chr(9)||
                to_char(REG.COD_TRANSACCION)||chr(9)||to_char(REG.COD_MONEDA)||chr(9)||to_char(REG.IMPORTE,'999999999999999D00')||chr(9)||
                to_char(REG.COD_TIP_DISTRIBUCION)||chr(9)||to_char(REG.REFERENCIA)||chr(9)||to_char(REG.COD_DIRECCION)||chr(9)||
                to_char(REG.DES_DIRECCION)||chr(9)||to_char(REG.COD_GERENCIA)||chr(9)||to_char(REG.DES_GERENCIA)||chr(9)||
                to_char(REG.COD_GER_ZONAL)||chr(9)||to_char(REG.DES_GER_ZONAL)||chr(9)||to_char(REG.COD_DEPARTAMENTO)||chr(9)||
                to_char(REG.DES_DEPARTAMENTO);

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

      EXIT WHEN c_vta_cartera%NOTFOUND;
   END LOOP;

   --Escribes la linea en el fichero
   UTL_FILE.PUT_LINE(v_file, v_buffer);

   --Cerrar el handler al fichero
   UTL_FILE.FCLOSE(v_file);
   COMMIT;

   v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

   -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
   v_respuesta := pa_file_ftp.fu_put_ascii(pa_rpc_aut.g_ip, pa_rpc_aut.g_port, pa_rpc_aut.g_user,
                                           pa_rpc_aut.g_pass, pa_rpc_aut.g_repository,
                                           v_name||'.txt', g_finanzas||v_name||'_'||v_fecha||'.txt');

   v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

   IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','INV_DER_GASTOS');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte de Derrama de Gastos, a la fecha '||v_fec_actual||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_finanzas||'

      Nombre del Archivo: '||v_name||'_'||v_fecha||'.txt';

      -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
         it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
         it_mail.end_mail(v_conn);
      EXCEPTION
        WHEN utl_smtp.transient_error or utl_smtp.permanent_error then
           BEGIN
              utl_smtp.quit(v_conn);
           EXCEPTION
              WHEN utl_smtp.transient_error or utl_smtp.permanent_error then
                 NULL;
           END;
           v_det_error := substr(sqlerrm,1,4000);
      END;

      v_hfin_mail := to_char(sysdate,'hh24:mi:ss');

      -- Insertamos en la tabla de log  si ocurrio algun error al enviar el mail
      IF v_det_error is not null THEN
         INSERT INTO ge_ra_log_mail
            (fec_envio, nom_archivo, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
         VALUES
            (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
         COMMIT;
      END IF;

   ELSE
      -- ERROR AL ENVIAR ARCHIVO POR FTP
      v_det_error    := null;

      -- Insertamos el error del envio al directorio compartido
      INSERT INTO ge_ra_log_ftp
         (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
      VALUES
         (SYSDATE, v_name||'_'||v_fecha||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
      COMMIT;

      --Enviamos el mail a soporte
      -- Obtenemos direccion de correo de soporte
      v_para := pa_rpc_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

      -- Damos valor a los demas datos
      v_asunto := 'Error Reporte de Derrama de Gastos, a la fecha '||v_fecha||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

      Error: '||v_respuesta||'.

      Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pa_rpc_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
         it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
         it_mail.end_mail(v_conn);
      EXCEPTION
         WHEN utl_smtp.transient_error or utl_smtp.permanent_error then
            BEGIN
               utl_smtp.quit(v_conn);
            EXCEPTION
               WHEN utl_smtp.transient_error or utl_smtp.permanent_error then
                  NULL;
            END;
            v_det_error := substr(sqlerrm,1,4000);
      END;

      v_hfin_mail := to_char(sysdate,'hh24:mi:ss');

      -- Insertamos en la tabla de log  si ocurrio algun error al enviar el mail
      IF v_det_error is not null THEN
         INSERT INTO ge_ra_log_mail
            (fec_envio, nom_archivo, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
         VALUES
            (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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
END;
-------------------------------------------------------------------------------------------------------------------------------------
END PA_RPC_AUT;
/

