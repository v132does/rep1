CREATE OR REPLACE PACKAGE BODY IT.PAG_EVO IS
--------------------------------------------------------------------------------------------------------------------------------------
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

PROCEDURE pr_com_bancard
IS
CURSOR cu_ext IS
   Select sit_cuenta,
       ''  oficina,
       '' cod_rubro,
       ''  nombre_rubro,
       a.nro_cuenta,
       '' cod_persona,
       '' as  nombre_titular,
       0 as tot_inventario_itgf,
       nvl(a.sal_facturar,0) as sal_facturar,
       nvl(a.sal_facturado,0) as sal_facturado ,
       nvl(a.sal_financiado,0) as sal_financiado,
       nvl(a.sal_cuo_pendientes,0) as sal_cuo_pendientes,
       (nvl(a.sal_facturar,0) + nvl(a.sal_facturado,0)+ nvl(a.sal_financiado,0) + nvl(a.sal_cuo_pendientes,0)) tot_inventario_bancard,
       (0 - (nvl(a.sal_facturar,0) + nvl(a.sal_facturado,0)+ nvl(a.sal_financiado,0) + nvl(a.sal_cuo_pendientes,0))) diferencia,
       '' as tip_saldo, nvl(a.sal_actual,0) as sal_actual
  from (select t.nro_cuenta,
       t.denominacion,
       '' cod_modulo,
       '' cod_modalidad,
       t.cod_oficina,
       t.cod_moneda,
       lin_credito,
       lin_cuotas,
       sal_facturar,
       sal_facturado,
       sal_financiado,
       sal_ult_extracto,
       sal_cuo_pendientes,
       mto_pag_minimo,
       sal_pag_minimo,
       t.mto_mora,
       dia_mora,
       mto_autorizaciones,
       mto_int_compras,
       mto_pag_mes,
       mto_gas_mora,
       t.estado,
       est_administradora,
       fec_solicitud,
       t.fec_apertura,
       fec_ult_pago,
       fec_ult_compra,
       fec_ult_operacion,
       fec_ult_extracto,
       fec_ult_cierre,
       fec_vct_ult_cierre,
       tip_cierre,
       cob_gas_financiero,
       tip_tas_financiacion,
       tip_com_emision,
       tas_financiacion,
       tas_adelanto,
       tas_mora,
       tas_cuotas,
       deb_automatico,
       tip_cobro,
       nro_cta_debito,
       mto_min_pago,
       por_pag_minimo,
       cod_usu_promotor,
       mar_mora,
       mar_excedido,
       mar_recuperado,
       mar_bloqueo,
       con_costo,
       nro_solicitud,
       cod_causa,
       cat_automatica,
       cod_canal,
       cod_campana,
       t.en_juicio,
       t.fec_juicio,
       t.cod_ent_juicio,
       t.max_atraso,
       t.pro_atraso,
       nro_linea,
       sit_cuenta,
       cod_sucursal,
       nro_reg,
       cod_usu_ente,
       t.usu_insercion,
       t.fec_insercion,
       t.usu_modificacion,
       t.fec_modificacion,
       cod_ent_procesadora,
       cod_afinidad, 0 as sal_actual
  from ta_cta_tarjetas_tmp t
   where t.sit_cuenta = 1
    and not exists (Select 1 from ta_cta_tarjetas a where decode(substr(trim(a.nro_cuenta),1,1),0, substr(trim(a.nro_cuenta),2),a.nro_cuenta) not like '796%'
                    and a.nro_cuenta = decode(substr(trim(t.nro_cuenta),1,1),0, substr(trim(t.nro_cuenta),2),t.nro_cuenta)) ) a
union

Select a.sit_cuenta,
       (aa.cod_oficina || ' ' || fue_obt_des_oficina(aa.cod_oficina)) oficina,
       aa.cod_rubro,
       fub_obt_des_cta_contable(aa.cod_rubro) nombre_rubro,
       a.nro_cuenta,
       g.cod_persona,
       fue_obt_nom_persona(g.cod_persona) nombre_titular,
       aa.sal_actual tot_inventario_itgf,
       nvl(a.sal_facturar,0) as sal_facturar,
       nvl(a.sal_facturado,0) as sal_facturado ,
       nvl(a.sal_financiado,0) as sal_financiado,
       nvl(a.sal_cuo_pendientes,0) as sal_cuo_pendientes,
       (nvl(a.sal_facturar,0) + nvl(a.sal_facturado,0)+ nvl(a.sal_financiado,0) + nvl(a.sal_cuo_pendientes,0)) tot_inventario_bancard,
       (aa.sal_actual - (nvl(a.sal_facturar,0) + nvl(a.sal_facturado,0)+ nvl(a.sal_financiado,0) + nvl(a.sal_cuo_pendientes,0))) diferencia,
       aa.tip_saldo, aa.sal_actual
  from (select ( decode(substr(trim(t.nro_cuenta),1,1),0, substr(trim(t.nro_cuenta),2),t.nro_cuenta) )as nro_cuenta,
       t.denominacion,
       g.cod_modulo,
       g.cod_modalidad,
       t.cod_oficina,
       t.cod_moneda,
       lin_credito,
       lin_cuotas,
       sal_facturar,
       sal_facturado,
       sal_financiado,
       sal_ult_extracto,
       sal_cuo_pendientes,
       mto_pag_minimo,
       sal_pag_minimo,
       t.mto_mora,
       dia_mora,
       mto_autorizaciones,
       mto_int_compras,
       mto_pag_mes,
       mto_gas_mora,
       t.estado,
       est_administradora,
       fec_solicitud,
       t.fec_apertura,
       fec_ult_pago,
       fec_ult_compra,
       fec_ult_operacion,
       fec_ult_extracto,
       fec_ult_cierre,
       fec_vct_ult_cierre,
       tip_cierre,
       cob_gas_financiero,
       tip_tas_financiacion,
       tip_com_emision,
       tas_financiacion,
       tas_adelanto,
       tas_mora,
       tas_cuotas,
       deb_automatico,
       tip_cobro,
       nro_cta_debito,
       mto_min_pago,
       por_pag_minimo,
       cod_usu_promotor,
       mar_mora,
       mar_excedido,
       mar_recuperado,
       mar_bloqueo,
       con_costo,
       nro_solicitud,
       cod_causa,
       cat_automatica,
       cod_canal,
       cod_campana,
       t.en_juicio,
       t.fec_juicio,
       t.cod_ent_juicio,
       t.max_atraso,
       t.pro_atraso,
       nro_linea,
       sit_cuenta,
       cod_sucursal,
       nro_reg,
       cod_usu_ente,
       t.usu_insercion,
       t.fec_insercion,
       t.usu_modificacion,
       t.fec_modificacion,
       cod_ent_procesadora,
       cod_afinidad
  from ta_cta_tarjetas_tmp t, ge_cuentas g
  --DYDMR-2071 ITGF - Informe de Bancard. Proceso de Cierre diario SC 18078
 where decode(substr(trim(t.nro_cuenta),1,1),0, substr(trim(t.nro_cuenta),2),t.nro_cuenta) = g.nro_cuenta )    a,
     ( select c.cod_oficina,
              c.cod_rubro,
              d.sal_actual,
              c.tip_saldo,
              d.nro_cuenta,
              c.cod_modulo,
              c.cod_modalidad
         from cb_sal_inventarios     c,cb_sal_inventarios_det d
        where c.nro_referencia = d.nro_referencia
          and c.cod_rubro in ('142102050200199','160102650209099','160102690209099','160302750209099','240402600215599','250102720100499','240402600201099')) aa,
 ge_cta_clientes g
 where a.cod_modulo = aa.cod_modulo (+)
   and a.cod_modalidad = aa.cod_modalidad (+)
   and g.nro_cuenta = a.nro_cuenta
   and g.relacion   = 'P'
   and a.nro_cuenta = aa.nro_cuenta
 order by 1;
/* where decode(substr(trim(t.nro_cuenta),1,1),0, substr(trim(t.nro_cuenta),2),t.nro_cuenta) = g.nro_cuenta )    a,
       cb_sal_inventarios     c,
       cb_sal_inventarios_det d,
       ge_cta_clientes        g
 where a.cod_modulo = c.cod_modulo (+)
   and a.cod_modalidad = c.cod_modalidad (+)
   and c.nro_referencia = d.nro_referencia
   and g.nro_cuenta = a.nro_cuenta
   and g.relacion   = 'P'
   and c.cod_rubro in (142102050200199,160102650209099,160102690209099,160302750209099,240402600215599,250102720100499)
   and a.nro_cuenta = d.nro_cuenta
 order by 1;*/

  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'sal_itgfbancard'; -- nombre del archivo
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

  -- CL DE-1669-VARIABLES
  v_tot_bancard NUMBER(18,2);
  v_dif_bancard  NUMBER(18,2);
BEGIN
  -- Obtenemos la fecha del sistema
  select pag_cal.FU_OBT_FEC_ACTUAL(1)
  into v_fec_sist
  from dual;

  v_fecha := to_char(v_fec_sist,'DDMMYYYY');

-- Abrir archivo
v_file := UTL_FILE.FOPEN(pag_evo.g_repository,v_name||'.txt','W',32767);

-- Colocar el titulo a los campos
v_linetit := 'SIT_CUENTA'||CHR(9)||'OFICINA'||CHR(9)||'COD_RUBRO'||CHR(9)||'NOMBRE_RUBRO'||CHR(9)||'NRO_CUENTA'||CHR(9)||'COD_PERSONA'||CHR(9)||
              'NOMBRE_TITULAR'||CHR(9)||'TOT_INVENTARIO_ITGF'||CHR(9)||'TOT_INVENTARIO_BANCARD'||CHR(9)||'DIFERENCIA'||CHR(9)||'TIP_SALDO';
utl_file.put_line(v_file,v_linetit);

-- Definir una linea en blanco para separar los datos del titulo de los campos
v_linetit := ' ';
utl_file.put_line(v_file,v_linetit);

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN cu_ext LOOP
     -- CL DE-1669 Agregar rubro 240402600201099 al informe de cuadre. DYD-SDSL-2975
    if  to_char(rec.COD_RUBRO) = '240402600201099' then
           v_tot_bancard := rec.TOT_INVENTARIO_BANCARD *-1 ;
           v_dif_bancard := rec.sal_actual -  v_tot_bancard ;
    else
          v_tot_bancard := rec.TOT_INVENTARIO_BANCARD ;
          v_dif_bancard := rec.DIFERENCIA ;
    end if;
    --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
  v_line := to_char(rec.SIT_CUENTA)||chr(9)||to_char(rec.OFICINA)||chr(9)||to_char(rec.COD_RUBRO)||chr(9)||to_char(rec.NOMBRE_RUBRO)||chr(9)||
            to_char(rec.NRO_CUENTA)||chr(9)||to_char(rec.COD_PERSONA)||chr(9)||to_char(rec.NOMBRE_TITULAR)||chr(9)||to_char(rec.TOT_INVENTARIO_ITGF )||chr(9)||
            to_char(v_tot_bancard)||chr(9)||to_char(v_dif_bancard)||chr(9)||to_char(rec.TIP_SALDO);

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
  v_respuesta := pa_file_ftp.fu_put_ascii(pag_evo.g_ip, pag_evo.g_port, pag_evo.g_user,
                                          pag_evo.g_pass, pag_evo.g_repository,
                                          v_name||'.txt', g_extractos||v_name||'_'||v_fecha||'.txt');


  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pag_evo.FU_OBT_VALOR_PAR('RA','REPORTES','CTAS_TRANSITORIAS');

      -- Damos valor a los demas datos
      v_asunto := 'Cuadre inventario TARJETAS ITGF VS BANCARD '||v_fec_sist||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_extractos||'

    Nombre del Archivo: '||v_name||'_'||v_fecha||'.txt';

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
        it_mail.mail(pag_evo.g_envia_mail,v_para,v_asunto,v_mje_mail);
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
     v_para := pag_evo.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error Reporte de cuadre de Bancard a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
        it_mail.mail(pag_evo.g_envia_mail,v_para,v_asunto,v_mje_mail);  
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
END pr_com_bancard;

PROCEDURE pr_apu_manuales
IS
CURSOR cu_ext(p_fec_desde DATE,p_fec_hasta DATE) IS

select h.fecha,
       h.hora,
       nro_secuencia,
       d.nro_asiento,
       h.cod_oficina,
       h.cod_usuario,
       h.cod_modulo,
       h.cod_modalidad,
       h.monto mto_origen,
       h.mto_equ_local,
       h.cod_moneda,
       h.nro_cuenta,
       h.cod_tra_padre,
       replace(h.concepto, '"', '''') concepto,
       h.nro_documento4,
       d.tip_movimiento,
       d.cod_rubro,
       b1.significado cod_cnc_movimientos,
       b2.significado cod_ori_movimientos,
       b3.significado cod_are_solicitante,
       'General' ind
  from ge_movimientos_his h, cb_asientos_det_his d, cb_dat_asientos_det_his c,
       ba_cod_referencias b1, ba_cod_referencias b2, ba_cod_referencias b3
 where h.fecha          = d.fecha
   and h.nro_documento4 = d.ref_movimiento
   and h.cod_tra_padre  = 100
   and d.fecha          = c.fecha       (+)
   and d.cod_oficina    = c.cod_oficina (+)
   and d.nro_asiento    = c.nro_asiento (+)
   and d.nro_linea      = c.nro_linea   (+)
   and 'ASI_CNC_MOVIMIENTOS' = b1.dominio    (+)
   and c.cod_cnc_movimientos = b1.val_minimo (+)
   and 'ASI_ORI_MOVIMIENTOS' = b2.dominio    (+)
   and c.cod_ori_movimientos = b2.val_minimo (+)
   and 'ASI_ARE_SOLICITANTE' = b3.dominio    (+)
   and c.cod_are_solicitante = b3.val_minimo (+)
   and d.fecha          between p_fec_desde and p_fec_hasta

union

select h.fecha,
       h.hora,
       nro_secuencia,
       d.nro_asiento,
       h.cod_oficina,
       h.cod_usuario,
       h.cod_modulo,
       h.cod_modalidad,
       h.monto mto_origen,
       h.mto_equ_local,
       h.cod_moneda,
       h.nro_cuenta,
       h.cod_tra_padre,
       replace(h.concepto, '"', '''') concepto,
       h.nro_documento4,
       d.tip_movimiento,
       d.cod_rubro,
       b1.significado cod_cnc_movimientos,
       b2.significado cod_ori_movimientos,
       b3.significado cod_are_solicitante,
       'Cuentas Corrientes'
  from cc_movimientos_his h, cb_asientos_det_his d, cb_dat_asientos_det_his c,
       ba_cod_referencias b1, ba_cod_referencias b2, ba_cod_referencias b3
 where h.fecha          = d.fecha
   and h.nro_documento4 = d.ref_movimiento
   and h.cod_tra_padre  = 100
  /*fmolinas DYDMR-759 and h.cod_mod_padre  = 2
   and h.cod_mad_padre  = 21*/
   and d.fecha          = c.fecha       (+)
   and d.cod_oficina    = c.cod_oficina (+)
   and d.nro_asiento    = c.nro_asiento (+)
   and d.nro_linea      = c.nro_linea   (+)
   and 'ASI_CNC_MOVIMIENTOS' = b1.dominio    (+)
   and c.cod_cnc_movimientos = b1.val_minimo (+)
   and 'ASI_ORI_MOVIMIENTOS' = b2.dominio    (+)
   and c.cod_ori_movimientos = b2.val_minimo (+)
   and 'ASI_ARE_SOLICITANTE' = b3.dominio    (+)
   and c.cod_are_solicitante = b3.val_minimo (+)
   and d.fecha          between p_fec_desde and p_fec_hasta

union

--Ctas Ahorros - Apuntes masivos
select h.fecha,
       h.hora,
       nro_secuencia,
       d.nro_asiento,
       h.cod_oficina,
       h.cod_usuario,
       h.cod_modulo,
       h.cod_modalidad,
       h.monto mto_origen,
       h.mto_equ_local,
       h.cod_moneda,
       h.nro_cuenta,
       h.cod_tra_padre,
       replace(h.concepto, '"', '''') concepto,
       h.nro_documento4,
       d.tip_movimiento,
       d.cod_rubro,
       b1.significado cod_cnc_movimientos,
       b2.significado cod_ori_movimientos,
       b3.significado cod_are_solicitante,
       'Ahorros'
  from ah_movimientos_his h, cb_asientos_det_his d, cb_dat_asientos_det_his c,
       ba_cod_referencias b1, ba_cod_referencias b2, ba_cod_referencias b3
 where h.fecha          = d.fecha
   and h.nro_documento4 = d.ref_movimiento
   and h.cod_tra_padre  = 100
  /*fmolinas DYDMR-759 and h.cod_mod_padre  = 2
   and h.cod_mad_padre  = 21*/
   and d.fecha          = c.fecha       (+)
   and d.cod_oficina    = c.cod_oficina (+)
   and d.nro_asiento    = c.nro_asiento (+)
   and d.nro_linea      = c.nro_linea   (+)
   and 'ASI_CNC_MOVIMIENTOS' = b1.dominio    (+)
   and c.cod_cnc_movimientos = b1.val_minimo (+)
   and 'ASI_ORI_MOVIMIENTOS' = b2.dominio    (+)
   and c.cod_ori_movimientos = b2.val_minimo (+)
   and 'ASI_ARE_SOLICITANTE' = b3.dominio    (+)
   and c.cod_are_solicitante = b3.val_minimo (+)
   and d.fecha          between p_fec_desde and p_fec_hasta

union

--Asientos Masivos
select d.fecha,
       null,
       null,
       d.nro_asiento,
       d.cod_oficina,
       h.cod_usuario,
       h.cod_modulo,
       h.cod_modalidad,
       d.mto_mon_rubro monto_origen,
       d.mto_mon_local,
       r.cod_moneda,
       null,
       null,
       replace(d.descripcion, '"', '''') concepto,
       d.ref_movimiento,
       d.tip_movimiento,
       d.cod_rubro,
       b1.significado cod_cnc_movimientos,
       b2.significado cod_ori_movimientos,
       b3.significado cod_are_solicitante,
       'Asientos Masivos'
  from cb_asientos_det_his d, cb_dat_asientos_det_his c, cb_asientos_his h, cb_rubros r,
       ba_cod_referencias b1, ba_cod_referencias b2, ba_cod_referencias b3
 where d.fecha              = h.fecha
   and d.cod_oficina        = h.cod_oficina
   and d.nro_asiento        = h.nro_asiento
   and d.cod_rubro          = r.cod_rubro
   and h.nro_asi_automatico is null
   and h.nro_asi_futuro     is null
   and d.fecha              = c.fecha       (+)
   and d.cod_oficina        = c.cod_oficina (+)
   and d.nro_asiento        = c.nro_asiento (+)
   and d.nro_linea          = c.nro_linea   (+)
   and 'ASI_CNC_MOVIMIENTOS' = b1.dominio    (+)
   and c.cod_cnc_movimientos = b1.val_minimo (+)
   and 'ASI_ORI_MOVIMIENTOS' = b2.dominio    (+)
   and c.cod_ori_movimientos = b2.val_minimo (+)
   and 'ASI_ARE_SOLICITANTE' = b3.dominio    (+)
   and c.cod_are_solicitante = b3.val_minimo (+)
   and d.fecha          between p_fec_desde and p_fec_hasta;


  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'apuntes_manuales'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_fec_sist          DATE;
  v_fecha             VARCHAR2(8);
  v_pri_dia_mes_habil DATE;
  v_ult_dia_mes_habil DATE;

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
  pag_cal.PR_OBT_DAT_CALENDAR(1);
  v_pri_dia_mes_habil := to_date('01'||'/'||to_char(add_months(sysdate, -1), 'MM')||'/'||to_char(add_months(sysdate, -1), 'YYYY'),'dd/mm/yyyy');
  v_ult_dia_mes_habil := to_date(to_char(last_day(add_months(sysdate, -1)), 'dd/mm/yyyy'),'dd/mm/yyyy');
  -- Obtenemos la fecha del sistema
  select pag_cal.FU_OBT_FEC_ACTUAL(1)
  into v_fec_sist
  from dual;

  v_fecha := to_char(v_fec_sist,'DDMMYYYY');

-- Abrir archivo
v_file := UTL_FILE.FOPEN(pag_evo.g_repository,v_name||'.txt','W',32767);
--FECHA, HORA, NRO_SECUENCIA, NRO_ASIENTO, COD_OFICINA, COD_USUARIO, COD_MODULO, COD_MODALIDAD, MTO_ORIGEN, MTO_EQU_LOCAL, COD_MONEDA, NRO_CUENTA, COD_TRA_PADRE, CONCEPTO, NRO_DOCUMENTO4, TIP_MOVIMIENTO, COD_RUBRO
-- Colocar el titulo a los campos
v_linetit := 'FECHA, '||CHR(9)||'HORA'||CHR(9)||'NRO_SECUENCIA'||CHR(9)||'NRO_ASIENTO'||CHR(9)||'COD_OFICINA'||CHR(9)||'COD_USUARIO'||CHR(9)||
             'COD_MODULO'||CHR(9)||'COD_MODALIDAD'||CHR(9)||'MTO_ORIGEN'||CHR(9)||'MTO_EQU_LOCAL'||CHR(9)||'COD_MONEDA'||CHR(9)||'NRO_CUENTA'||CHR(9)||'COD_TRA_PADRE'||CHR(9)||'CONCEPTO'||CHR(9)||'NRO_DOCUMENTO4'
             ||CHR(9)||'TIP_MOVIMIENTO'||CHR(9)||'COD_RUBRO'||CHR(9)||'COD_CNC_MOVIMIENTOS'||CHR(9)||'COD_ORI_MOVIMIENTOS'||CHR(9)||'COD_ARE_SOLICITANTE';
utl_file.put_line(v_file,v_linetit);

-- Definir una linea en blanco para separar los datos del titulo de los campos
v_linetit := ' ';
utl_file.put_line(v_file,v_linetit);

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN cu_ext(v_pri_dia_mes_habil,v_ult_dia_mes_habil) LOOP

    --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
  v_line := to_char(rec.FECHA)||chr(9)||to_char(rec.HORA)||chr(9)||to_char(rec.NRO_SECUENCIA)||chr(9)||to_char(rec.NRO_ASIENTO)||chr(9)||
            to_char(rec.COD_OFICINA)||chr(9)||to_char(rec.COD_USUARIO)||chr(9)||to_char(rec.COD_MODULO)||chr(9)||to_char(rec.COD_MODALIDAD)||chr(9)||
            to_char(rec.MTO_ORIGEN)||chr(9)||to_char(rec.MTO_EQU_LOCAL)||chr(9)||to_char(rec.COD_MONEDA)||chr(9)||to_char(rec.NRO_CUENTA)||chr(9)||
            to_char(rec.COD_TRA_PADRE)||chr(9)||to_char(rec.CONCEPTO)||chr(9)||to_char(rec.NRO_DOCUMENTO4)||chr(9)||to_char(rec.TIP_MOVIMIENTO)||chr(9)||
            to_char(rec.COD_RUBRO)||chr(9)||to_char(rec.cod_cnc_movimientos)||chr(9)||to_char(rec.cod_ori_movimientos)||chr(9)||to_char(rec.cod_are_solicitante);

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
  v_respuesta := pa_file_ftp.fu_put_ascii(pag_evo.g_ip, pag_evo.g_port, pag_evo.g_user,
                                          pag_evo.g_pass, pag_evo.g_repository,
                                          v_name||'.txt', g_extractos||v_name||'_'||v_fecha||'.txt');

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pag_evo.FU_OBT_VALOR_PAR('RA','REPORTES','CTAS_TRANSITORIAS');

      -- Damos valor a los demas datos
      v_asunto := 'Apuntes Manuales '||v_fec_sist||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_extractos||'

    Nombre del Archivo: '||v_name||'_'||v_fecha||'.txt';

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
        it_mail.mail(pag_evo.g_envia_mail,v_para,v_asunto,v_mje_mail);
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
     v_para := pag_evo.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error Reporte de Apuntes Manuales a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
        it_mail.mail(pag_evo.g_envia_mail,v_para,v_asunto,v_mje_mail);
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
END pr_apu_manuales;
-------------------------------------------------------------------------------------------------------------------------------------
procedure pr_cta_excluidas
  (p_max_fec_saldos date)
is
   v_men_error  varchar2(500);
   v_fec_inicio date := p_max_fec_saldos - 1460; --(365 días x 4 años)
begin
   sql_util.ejecute_dml('truncate table it.sb_cta_excluir', v_men_error);
   IF v_men_error IS NOT NULL THEN
      raise_application_error(-20000, v_men_error);
   END IF;
   
   insert into sb_cta_excluir (nro_operacion)
   --CUENTAS INCOBRABLES A EXCLUIR DE SALDOS.
   --671
    SELECT DISTINCT (a.nro_cuenta)
      FROM pr_cta_prestamos a, ge_cuentas_nov g
     WHERE a.estado = 'I'
       AND a.nro_cuenta = g.nro_cuenta
       AND a.estado = g.est_actual
       AND g.fecha <= v_fec_inicio
   UNION
   --1227
   SELECT DISTINCT (b.nro_cta_origen)
     FROM ov_cta_vencidas b
    WHERE b.estado = 'I'
      AND b.fec_cam_estado <= v_fec_inicio
   --
   UNION
   --162
   SELECT DISTINCT (b.nro_cuenta) --validar si debe ser CTA_ORIGEN Y/O CUENTA (##USAR 1RO CTA Y DESPUÉS CTA_ORIGEN##).-
     FROM ov_cta_vencidas b
    WHERE b.estado = 'I'
      AND b.fec_cam_estado <= v_fec_inicio
   ---
   UNION
   --3
   SELECT val_minimo
     FROM ba_cod_referencias
    WHERE dominio = 'CTA_INCOBRABLE_EXCLUIDAS'; -- cuentas incobrables excluidas mayor a 3 años

end;

---
procedure pr_ins_prev_det (p_fecha date default null) is
   v_men_error          varchar2(500);
   v_fec_actual         DATE := pag_cal.FU_OBT_FEC_ACTUAL(1);
   v_max_fec_saldos     date;
   v_cod_mon_local      ba_monedas.cod_moneda%type := pag_gen.FU_OBT_MON_LOCAL;
   v_fec_prev_det       date := to_date(fug_obt_pardinamico('FEC_PREV_DET'),'YYYYMMDD');
   v_base_prod          ge_par_dinamicos.val_parametro%type;
   v_base_datos         varchar2(50);
begin
   if p_fecha is not null then
      v_fec_actual := p_fecha;
   end if;
   --- Parte 1, cargar el temporal del Prev det
   if v_fec_actual <> v_fec_prev_det then
      sql_util.ejecute_dml('truncate table it.GE_PREVISION_DET_TMP', v_men_error);
      IF v_men_error IS NOT NULL THEN
         raise_application_error(-20000, v_men_error);
      END IF;
      
      select max(d.fecha)
        into v_max_fec_saldos
        from sb_crc_saldos_det d
       where last_day(d.fecha) = d.fecha;
      
      insert into GE_PREVISION_DET_TMP(
             cod_modulo, riesgo, nombre_per, nro_doc, cat_riesgo, cat_crc, ofi, cod_usu_oficial,
             cat_subjetiva, gru_eco, cat_gru_economico, cat_sistema, tot_deu_rsistema, tot_con_rsistema,
             tipo, cod_modalidad, nro_cuenta, cod_moneda, cod_estado, estado,
             tot_deu_real, tot_deu_contingente, dev_no_cobrado, tot_gar_computables, tot_prevision, cat_automatica, 
             cat_renovaciones, dia_atraso, tip_destino, cod_sec_credito, mto_mora, prim_prevision, seg_prevision, 
             capital, tot_deuda, rie_des_prv_ant_garantia, rie_gar_nocubierto,
             act_primaria, cod_seg_cliente, cod_pais, cod_tip_documento, cat_de_persona,
             tot_cap_prev, tot_int_prev, query_10)
      select o.cod_modulo, o.cod_persona riesgo, trim(p.nom_completo) nombre_per, trim(p.nro_documento) nro_doc,
             e.cat_riesgo, fup_obt_categoria(e.cat_automatica,e.cat_subjetiva) cat_crc, e.cod_oficina ofi, e.cod_usu_oficial,
             e.cat_subjetiva, e.cod_gru_economico gru_eco, e.cat_gru_economico, e.cat_sistema,
             e.tot_deu_sistema, e.tot_deu_con_sistema tot_con_rsistema, e.tipo, o.cod_modalidad, o.nro_cuenta,
             o.cod_moneda, o.cod_estado, t.descripcion estado, o.tot_deu_real, o.tot_deu_contingente, o.dev_no_cobrado,
             o.tot_gar_computables, o.tot_prevision, o.cat_automatica, o.cat_renovaciones, o.dia_atraso,
             nvl(o.tip_destino,4) tip_destino,
             o.cod_sec_credito,
             case
                when o.cod_modulo = 6 and o.dia_atraso > 60 then
                   o.tot_deu_real
                when o.cod_modulo = 5 and o.dia_atraso > 30 then
                   o.tot_deu_real
                else
                   0
                end mto_mora,
              nvl(o.tot_pri_prevision,0) prim_prevision,
              nvl(o.tot_prevision,0) - nvl(o.tot_pri_prevision,0) seg_prevision,
             (NVL(o.tot_deu_real,0) - NVL(o.dev_no_cobrado,0)) CAPITAL,
             (NVL(o.tot_deu_real,0) + NVL(o.tot_deu_contingente,0)) TOT_DEUDA,
             (NVL(o.tot_deu_real,0) + NVL(o.tot_deu_contingente,0) - NVL(o.tot_pri_prevision,0)) RIE_DES_PRV_ANT_GARANTIA,
             (NVL(o.tot_deu_real,0) + NVL(o.tot_deu_contingente,0) - NVL(o.tot_pri_prevision,0) - NVL(o.tot_gar_computables,0)) RIE_GAR_NOCUBIERTO,
             -- DE-2044
             p.cod_rub_primario ACT_PRIMARIA,
             e.cod_seg_cliente,
             -- PIPROINTE-285 Riesgos - Anexo 1 - Reportes de Gestión requeridos por GNB Sudameris Colombia
             p.cod_pais, p.cod_tip_documento, e.cat_automatica cat_de_persona
             -- para previsiones de tarjetas y sobregiros
             ,(nvl(o.tot_cap_pri_prevision,0) + nvl(o.tot_cap_seg_prevision,0)) tot_cap_prev
             ,(nvl(o.tot_int_pri_prevision,0) + nvl(o.tot_int_seg_prevision,0)) tot_int_prev
             ,'N' query_10
        from ge_cla_operaciones o, ge_clientes e, ba_personas p, ge_est_cuentas t
       where o.cod_persona=e.cod_persona
         and e.cod_persona=p.cod_persona
         and t.cod_modulo=o.cod_modulo
         and t.cod_modalidad=o.cod_modalidad
         and t.estado=o.cod_estado;
         
         --------------------------
         --- Updates que tardan ---
         --------------------------                          
         update GE_PREVISION_DET_TMP o
            set rubro = fub_obt_rub_contable(o.cod_modulo,o.nro_cuenta)
          where o.query_10 = 'N'; -- 01:05
          
         -- fug_obt_dat_operaciones(o.nro_cuenta,'F')
         -- Préstamos --
         update GE_PREVISION_DET_TMP o
            set fecha_inicio_oper = (Select to_char(p.fec_inicio,'dd/mm/yyyy')
                                       from pr_cta_prestamos p
                                      where p.nro_cuenta = o.nro_cuenta)
          where o.query_10 = 'N'
            and o.cod_modulo = 6; -- 00:33        
         -- Caja de Ahorro --
         update GE_PREVISION_DET_TMP o
            set fecha_inicio_oper = (Select to_char(a.fec_apertura,'dd/mm/yyyy')
                                       from ah_cta_vistas a
                                      where a.nro_cuenta = o.nro_cuenta)
          where o.query_10 = 'N'
            and o.cod_modulo = 3;
          -- Cuenta Corriente --
          update GE_PREVISION_DET_TMP o
            set fecha_inicio_oper = (Select to_char(c.fec_apertura,'dd/mm/yyyy')
                                       from cc_cta_corrientes c
                                      where c.nro_cuenta = o.nro_cuenta)
          where o.query_10 = 'N'
            and o.cod_modulo = 4;
          -- Tarjeta --
          update GE_PREVISION_DET_TMP o
            set fecha_inicio_oper = (Select to_char(t.fec_apertura,'dd/mm/yyyy')
                                       from ta_cta_tarjetas t
                                      where t.nro_cuenta = o.nro_cuenta)
          where o.query_10 = 'N'
            and o.cod_modulo = 5;
          -- Importación/Exportación --
          update GE_PREVISION_DET_TMP o
            set fecha_inicio_oper = (Select to_char(max(i.fec_solicitud),'dd/mm/yyyy')
                                       from cx_cta_importaciones i
                                      where i.nro_cuenta = o.nro_cuenta)
          where o.query_10 = 'N'
            and o.cod_modulo = 8
            and o.fecha_inicio_oper is null;
          update GE_PREVISION_DET_TMP o
            set fecha_inicio_oper = (Select to_char(max(i.fec_solicitud),'dd/mm/yyyy')
                                       from cx_cta_exportaciones i
                                      where i.nro_cuenta = o.nro_cuenta)
          where o.query_10 = 'N'
            and o.cod_modulo = 8
            and o.fecha_inicio_oper is null;
          --- P/ QUERY 10 ---
          update GE_PREVISION_DET_TMP o
            set fecha_inicio_oper = (Select to_char(max(i.fec_solicitud),'dd/mm/yyyy')
                                       from cx_fianzas i
                                      where i.nro_cuenta = o.nro_cuenta)
          where o.query_10 = 'N'
            and o.cod_modulo = 8
            and o.fecha_inicio_oper is null;
          -- Fianzas --
          update GE_PREVISION_DET_TMP o
            set fecha_inicio_oper = (Select to_char(f.fec_inicio,'dd/mm/yyyy')
                                       from md_cta_documentos f
                                      where f.nro_cuenta = o.nro_cuenta)
          where o.query_10 = 'N'
            and o.cod_modulo = 10;
          -- Operaciones Vencidas --
          update GE_PREVISION_DET_TMP o
            set fecha_inicio_oper = (Select to_char(x.fec_apertura,'dd/mm/yyyy')
                                       from ov_cta_vencidas x
                                      where x.nro_cuenta = o.nro_cuenta)
          where o.query_10 = 'N'
            and o.cod_modulo = 15;
         
         -- fug_obt_sal_operacion(o.nro_cuenta,o.cod_moneda)
         -- Préstamos --
         update GE_PREVISION_DET_TMP o
            set sdo_mora = pal_cam.fu_con_mon_a_moneda(o.cod_moneda, v_cod_mon_local,
                           (Select sum(nvl(sal_capital, 0) + nvl(sal_interes, 0) + nvl(sal_int_documentado,0))
                              from pr_cuotas
                             where nro_cuenta = o.nro_cuenta
                               and fec_vencimiento < v_fec_actual
                               and (nvl(sal_capital, 0) > 0 or nvl(sal_interes, 0) > 0 or nvl(sal_int_documentado,0) > 0)))
          where o.query_10 = 'N'
            and o.cod_modulo = 6; --01:12
         -- Sobregiro --
         update GE_PREVISION_DET_TMP o
            set sdo_mora = pal_cam.fu_con_mon_a_moneda(o.cod_moneda, v_cod_mon_local,
                           (Select sum(sal_total)
                              from cc_sobregiros c, cc_sobregiros_res r
                             where c.nro_cuenta = o.nro_cuenta
                               and c.nro_cuenta = r.nro_cuenta
                               and c.fecha = (Select max(c.fecha)
                                                from cc_sobregiros c
                                               where c.nro_cuenta = o.nro_cuenta)
                               and nvl(r.can_dia_sobregiro,0) > 0 ))
          where o.query_10 = 'N'
            and o.cod_modulo = 4;
         -- Tarjeta --
         update GE_PREVISION_DET_TMP o
            set sdo_mora = pal_cam.fu_con_mon_a_moneda(o.cod_moneda, v_cod_mon_local,
                           (Select sum(t.mto_mora)
                              from ta_cta_tarjetas t, ge_cta_clientes c
                             where t.nro_cuenta = c.nro_cuenta
                               and t.nro_cuenta = o.nro_cuenta
                               and c.relacion = 'P'))
          where o.query_10 = 'N'
            and o.cod_modulo = 5;    
         -- Operaciones Vencidas --
         update GE_PREVISION_DET_TMP o
            set sdo_mora = pal_cam.fu_con_mon_a_moneda(o.cod_moneda, v_cod_mon_local,
                           (select sum(t.Sal_Total)
                              from ov_cta_vencidas t
                             WHERE T.NRO_CUENTA = o.nro_cuenta))
          where o.query_10 = 'N'
            and o.cod_modulo = 15;
         
         --- fug_obt_des_actividad(O.ACT_PRIMARIA,'N')
         update GE_PREVISION_DET_TMP o
            set DES_ACT_PRIMARIA = (select descripcion
                                      from ge_rub_economicos
                                     where cod_rub_economico = O.ACT_PRIMARIA)
          where o.query_10 = 'N';
        ---
        --- DYDMR-9946 - Fecha de Operación prev_det
        ---
        delete GE_PREVISION_DET_TMP
         where to_date(fecha_inicio_oper,'dd/mm/yyyy') > v_fec_actual;
        ---
        update GE_PREVISION_DET_TMP o
           set o.doc = (select d.abreviatura from ba_tip_documentos d where o.cod_tip_documento=d.cod_tip_documento)
         where o.query_10 = 'N';
         update GE_PREVISION_DET_TMP o
            set o.oficina = (select n.descripcion from ba_oficinas n where o.ofi = n.cod_oficina)
          where o.query_10 = 'N';
         update GE_PREVISION_DET_TMP o
            set o.ofi_usu = (select u.cod_oficina 
                               from ba_usuarios u, ba_oficinas f, ba_gru_oficinas g
                              where o.cod_usu_oficial=u.cod_usuario
                                and u.cod_oficina=f.cod_oficina
                                and f.cod_gru_oficina=g.cod_gru_oficina)
          where o.query_10 = 'N';
         update GE_PREVISION_DET_TMP o
            set o.banca = (select g.descripcion 
                             from ba_usuarios u, ba_oficinas f, ba_gru_oficinas g
                            where o.cod_usu_oficial=u.cod_usuario
                              and u.cod_oficina=f.cod_oficina
                              and f.cod_gru_oficina=g.cod_gru_oficina)
          where o.query_10 = 'N';
         update GE_PREVISION_DET_TMP o
            set o.tip_cliente = (select substr(r1.significado,1,40) 
                                   from ba_cod_referencias r1 
                                  where r1.dominio='TIP_CLIENTE'
                                    and r1.val_minimo=nvl(o.tipo,'T'))
          where o.query_10 = 'N';
         update GE_PREVISION_DET_TMP o
            set o.nombre_usu = (select u.nombre from ba_usuarios u where o.cod_usu_oficial = u.cod_usuario)
          where o.query_10 = 'N';
         -- Requerimiento: CNFAIRUNO-3.
         -- Fecha: 22/09/2014.
         update GE_PREVISION_DET_TMP o
            set GRU_ECO_INFORMADO = (CASE WHEN (SELECT COUNT(DISTINCT g1.cod_persona)
                                                  FROM ge_cla_operaciones g1, ge_clientes g2
                                                 WHERE g1.cod_persona = g2.cod_persona
                                                   AND g2.cod_gru_economico = o.gru_eco) > 1
                                                  THEN o.gru_eco END)
          where o.query_10 = 'N';
         update GE_PREVISION_DET_TMP x
            set x.saldo_interes = (select s.sal_int_batch from pr_cta_prestamos s where x.nro_cuenta = s.nro_cuenta)
          where x.query_10 = 'N';
         update GE_PREVISION_DET_TMP x
            set x.sect_prestamo = (select s.cod_sec_credito from pr_cta_prestamos s where x.nro_cuenta = s.nro_cuenta)
          where x.query_10 = 'N';
         update GE_PREVISION_DET_TMP x
            set x.cod_sub_modalidad = (select s.cod_sub_modalidad from pr_cta_prestamos s where x.nro_cuenta = s.nro_cuenta)
          where x.query_10 = 'N';
         update GE_PREVISION_DET_TMP x
            set x.cod_campana = (select s.cod_campana from pr_cta_prestamos s where x.nro_cuenta = s.nro_cuenta)
          where x.query_10 = 'N';
         update GE_PREVISION_DET_TMP x
            set x.nro_solicitud = (select s.nro_solicitud from pr_cta_prestamos s where x.nro_cuenta = s.nro_cuenta)
          where x.query_10 = 'N';
         --RE DE-1358
         update GE_PREVISION_DET_TMP x
            set x.canal_prestamo = (select s.cod_canal from pr_cta_prestamos s where x.nro_cuenta = s.nro_cuenta)
          where x.query_10 = 'N';          
         ---
         update GE_PREVISION_DET_TMP x
            set x.desc_sect_prestamo = (select se.descripcion 
                                          from pr_sec_creditos se, pr_cta_prestamos s 
                                         where se.cod_sec_credito = s.cod_sec_credito
                                           and s.nro_cuenta = x.nro_cuenta)
          where x.query_10 = 'N';
         ---
         update GE_PREVISION_DET_TMP x
            set x.CAPITAL_INICIAL = (CASE 
                                        WHEN x.cod_modulo = 5 THEN
                                           NVL((select tr.lin_credito
                                                  from ta_cta_tarjetas tr
                                                 where tr.cod_modulo = x.cod_modulo
                                                   and tr.nro_cuenta = x.nro_cuenta),1)
                                        ELSE (select s.mto_capital 
                                                from pr_cta_prestamos s
                                               where x.nro_cuenta = s.nro_cuenta)
                                     END)
          where x.query_10 = 'N';          
         ---
         update GE_PREVISION_DET_TMP x
            set destino = (select substr(r2.significado,1,20)
                             from ba_cod_referencias r2
                            where r2.dominio='TIP_DESTINO'
                              and r2.val_minimo=nvl(x.tip_destino,4))
          where x.query_10 = 'N';
         --- En el proceso: it.pap_cat.PR_PRO_DAT_PRESTAMO se le asigna el COD_BCO_CENTRAL en el cod_sec_credito
         update GE_PREVISION_DET_TMP o
            set o.desc_sec_crd = 
                case
                   when o.cod_sec_credito = 701 then
                      'PRESTAMOS CONSUMO'
                   when o.cod_sec_credito = 750 then
                      'PRESTAMOS PARA LA VIVIENDA H20/H30'
                   when o.cod_sec_credito = 111 then
                      'CONSTRUCCION - OTROS'
                   when o.cod_sec_credito = 135 then
                      'COMERCIO MINORISTA'
                   when o.cod_sec_credito = 172 then
                      'ADELANTO DE IMP'
                   when o.cod_sec_credito = 201 then
                      'EXPLOTACION GANADERIA'
                   when o.Cod_Sec_Credito = 203 then
                      'OTRAS ACT.GANADERAS'
                   when o.Cod_Sec_Credito = 330 then
                      'OTRAS INDUSTRIAS'
                   when o.cod_sec_credito = 400 then
                      'EXPORTACION OTROS PRODUCTOS'
                   when o.cod_sec_credito = 401 then
                      'EXPORTACION PRODUCTOS AGRÍCOLAS'
                   when o.cod_sec_credito = 408 then
                      'IMPOR Y COMER. MAQ.Y  EQUIPOS'
                   when o.cod_sec_credito = 409 then
                      'OTROS COMERCIOS AL POR MAYOR'
                   when o.cod_sec_credito not in (111,135,172,201,203,330,400,401,408,409,701,750) then
                      (select se.descripcion
                         from pr_sec_creditos se, pr_cta_prestamos s
                        where se.cod_bco_central = o.cod_sec_credito
                          and se.cod_sec_credito = s.cod_sec_credito
                          and s.nro_cuenta = o.nro_cuenta)
                      -- HO - DYDMR-6075 - "o.cod_sec_credito" se carga en el PAP_CAT.pr_pro_dat_prestamo desde el pv_cat_prestamos,
                      -- donde apunta al campo cod_bco_central con un alias cod_sec_credito, por lo que se coloca "cod_bco_central = "
                end
          where o.query_10 = 'N';
         update GE_PREVISION_DET_TMP x
            set Tip_renovacion = (select decode(nvl(s.tip_renovacion,'A'),'A','Nuevo',
                                                                          'D','Desembolso Etapas',
                                                                          'V','Vista',
                                                                          'E','Re-estructurado',
                                                                          'N','Renovado',
                                                                          'R','Refinanciado',
                                                                          'Otro')
                                    from pr_cta_prestamos s where x.nro_cuenta = s.nro_cuenta);
        --where x.query_10 = 'N';
        update GE_PREVISION_DET_TMP x
           set Tip_renovacion = 'Nuevo'
         where Tip_renovacion is null;
        --- Requerimiento: CNFAIRUNO-3.
        --- Fecha: 22/09/2014.
        update GE_PREVISION_DET_TMP o
           set GRU_ECO_BCP = (SELECT MAX(bc.val_minimo)
                                FROM ba_cod_referencias bc
                               WHERE bc.dominio = 'GRU_ECO_BCP'
                                 AND bc.val_maximo = nvl(o.gru_eco,0)
                                 AND bc.fec_modificacion = (SELECT MAX(re.fec_modificacion)
                                                              FROM ba_cod_referencias re
                                                             WHERE bc.dominio = re.dominio
                                                               AND bc.val_maximo = re.val_maximo))
          where o.query_10 = 'N';
        ---
        update GE_PREVISION_DET_TMP o
           set SUB_CAT_INDIVIDUAL_NO_R4 = (CASE WHEN o.cat_riesgo = 1 THEN
                                                     NVL((select MAX((CASE WHEN a.cat_automatica >= 2
                                                                      THEN 1.2
                                                                      ELSE a.cat_automatica END))
                                                            from ge_cla_operaciones a
                                                           where a.cod_persona = o.riesgo
                                                             and not exists (select 1
                                                                               from ge_par_dinamicos g
                                                                              where a.cod_modulo = g.cod_modulo
                                                                                and a.cod_modalidad = g.cod_modalidad
                                                                                and g.parametro = 'COD_MAD_RESOLUCION04'
                                                                                and g.val_parametro = 'S')
                                                          ),1) END)
          where o.query_10 = 'N';
        update GE_PREVISION_DET_TMP o
           set SUB_CAT_INDIVIDUAL_R4 = (CASE WHEN o.cat_riesgo = 1 THEN
                                                  NVL((select MAX((CASE WHEN a.cat_automatica >= 2
                                                                        THEN 1.2
                                                                        ELSE a.cat_automatica END))
                                                         from ge_cla_operaciones a
                                                        where a.cod_persona = o.riesgo
                                                          and exists (select 1
                                                                        from ge_par_dinamicos g
                                                                       where a.cod_modulo = g.cod_modulo
                                                                         and a.cod_modalidad = g.cod_modalidad
                                                                         and g.parametro = 'COD_MAD_RESOLUCION04'
                                                                         and g.val_parametro = 'S')
                                                          ),1) END)
          where o.query_10 = 'N';
        update GE_PREVISION_DET_TMP o
           set ES_COVID = nvl(fug_obt_pardinamico('COD_MAD_RESOLUCION04', o.cod_modulo, o.cod_modalidad),'N') 
          where o.query_10 = 'N';
        update GE_PREVISION_DET_TMP o
           set SUB_CAT_GRUPO = (CASE WHEN o.gru_eco IS NOT NULL THEN
                                           (CASE WHEN o.cat_riesgo = 1 THEN
                                                      NVL((select MAX((CASE WHEN a.cat_automatica >= 2
                                                                            THEN 1.2 
                                                                            ELSE a.cat_automatica END))
                                                             from ge_cla_operaciones a
                                                            where a.cod_persona IN (SELECT x.cod_persona 
                                                                                      FROM ge_clientes x
                                                                                     where x.cod_gru_economico = o.gru_eco)),1)
                                            END) END)
          where o.query_10 = 'N';
      commit;
      
      
      --- Mesa de Dinero
      insert into GE_PREVISION_DET_TMP(
             cod_modulo, riesgo, nombre_per, doc, nro_doc, cat_riesgo, cat_crc, ofi, oficina, ofi_usu, 
             cod_usu_oficial, nombre_usu, banca, cat_subjetiva, gru_eco, gru_eco_informado, cat_gru_economico, 
             cat_sistema, tot_deu_rsistema, tot_con_rsistema, tipo, tip_cliente, rubro, cod_modalidad, 
             nro_cuenta, saldo_interes, fecha_inicio_oper, cod_moneda, cod_estado, estado, tot_deu_real, 
             tot_deu_contingente, dev_no_cobrado, tot_gar_computables, tot_prevision, cat_automatica, 
             cat_renovaciones, dia_atraso, sdo_mora, tip_destino, destino, cod_sec_credito, desc_sec_crd, 
             tip_renovacion, mto_mora, sect_prestamo, desc_sect_prestamo, prim_prevision, seg_prevision, 
             cod_sub_modalidad, cod_campana, gru_eco_bcp, sub_cat_individual_no_r4, sub_cat_individual_r4, 
             es_covid, sub_cat_grupo, capital, tot_deuda, rie_des_prv_ant_garantia, rie_gar_nocubierto, 
             capital_inicial, act_primaria, des_act_primaria, cod_seg_cliente, nro_solicitud, canal_prestamo, 
             cod_pais, cod_tip_documento, cat_de_persona, tot_cap_prev, tot_int_prev, query_10)
      select o.cod_modulo, o.cod_persona riesgo, ltrim(rtrim(p.nom_completo)) nombre_per, d.abreviatura doc, ltrim(rtrim(p.nro_documento)) nro_doc,
             e.cat_riesgo, fup_obt_categoria(e.cat_automatica,e.cat_subjetiva) cat_crc, e.cod_oficina ofi, n.descripcion oficina,
             u.cod_oficina ofi_usu, e.cod_usu_oficial, u.nombre nombre_usu, g.descripcion banca, e.cat_subjetiva, e.cod_gru_economico gru_eco,
             (CASE WHEN (SELECT COUNT(DISTINCT g1.cod_persona) FROM ge_cla_operaciones g1, ge_clientes g2 WHERE g1.cod_persona = g2.cod_persona AND g2.cod_gru_economico = e.cod_gru_economico) > 1 THEN e.cod_gru_economico END) GRU_ECO_INFORMADO,
             e.cat_gru_economico, e.cat_sistema, e.tot_deu_sistema tot_deu_rsistema, e.tot_deu_con_sistema tot_con_rsistema,
             e.tipo, substr(r1.significado,1,40) tip_cliente, fub_obt_rub_contable(o.cod_modulo,o.nro_cuenta) rubro,
             o.cod_modalidad, o.nro_cuenta,o.sal_int_batch saldo_interes, fug_obt_dat_operaciones(o.nro_cuenta,'F') fecha_inicio_oper, o.cod_moneda, o.estado cod_estado, t.descripcion estado, (o.sal_capital + o.sal_interes) tot_deu_real,
             0 tot_deu_contingente, pal_cam.FU_CON_MON_A_MONEDA(o.cod_moneda, v_cod_mon_local, (o.mto_interes - o.val_int_devengar)) dev_no_cobrado,
             0 tot_gar_computables, 0 tot_prevision, e.cat_automatica, null cat_renovaciones, 0 dia_atraso,fug_obt_sal_operacion(o.nro_cuenta,o.cod_moneda) sdo_mora,
             null tip_destino, null destino, o.cod_sec_credito, null desc_sec_crd,
             'Nuevo' Tip_renovacion,
             0 mto_mora, o.cod_sec_credito sect_prestamo,
             null desc_sect_prestamo,
             0 prim_prevision,
             0 seg_prevision,
             null cod_sub_modalidad,  null cod_campana,
             (SELECT MAX(bc.val_minimo)
                FROM ba_cod_referencias bc
               WHERE bc.dominio = 'GRU_ECO_BCP'
                 AND bc.val_maximo = nvl(e.cod_gru_economico,0)
                 AND bc.fec_modificacion = (SELECT MAX(re.fec_modificacion)
                                              FROM ba_cod_referencias re
                                             WHERE bc.dominio = re.dominio
                                               AND bc.val_maximo = re.val_maximo)) GRU_ECO_BCP,
             (CASE WHEN e.cat_riesgo = 1 THEN NVL((select MAX((CASE WHEN a.cat_automatica >= 2 THEN 1.2 ELSE a.cat_automatica END)) from ge_cla_operaciones a  where a.cod_persona = o.cod_persona
               and nvl(fug_obt_pardinamico('COD_MAD_RESOLUCION04', a.cod_modulo, a.cod_modalidad),'N') = 'N'
             ),1) END) SUB_CAT_INDIVIDUAL_NO_R4,
             (CASE WHEN e.cat_riesgo = 1 THEN NVL((select MAX((CASE WHEN a.cat_automatica >= 2 THEN 1.2 ELSE a.cat_automatica END)) from ge_cla_operaciones a where a.cod_persona = o.cod_persona
               and nvl(fug_obt_pardinamico('COD_MAD_RESOLUCION04', a.cod_modulo, a.cod_modalidad),'N') = 'S'
             ),1) END) SUB_CAT_INDIVIDUAL_R4,
             nvl(fug_obt_pardinamico('COD_MAD_RESOLUCION04', o.cod_modulo, o.cod_modalidad),'N') ES_COVID,
             (CASE WHEN e.cod_gru_economico IS NOT NULL THEN (CASE WHEN e.cat_riesgo = 1 THEN NVL((select MAX((CASE WHEN a.cat_automatica >= 2 THEN 1.2 ELSE a.cat_automatica END)) from ge_cla_operaciones a where a.cod_persona IN (SELECT x.cod_persona FROM ge_clientes x where x.cod_gru_economico = e.cod_gru_economico)),1) END) END) SUB_CAT_GRUPO,
              o.monto CAPITAL, o.monto TOT_DEUDA, 0 RIE_DES_PRV_ANT_GARANTIA, 0 RIE_GAR_NOCUBIERTO, o.monto CAPITAL_INICIAL
             ,p.cod_rub_primario ACT_PRIMARIA,fug_obt_des_actividad(P.COD_RUB_PRIMARIO,'N') DES_ACT_PRIMARIA
             ,e.cod_seg_cliente, null nro_solicitud, null canal_prestamo
             ,p.cod_pais, p.cod_tip_documento, e.cat_automatica cat_de_persona
             ,0 tot_cap_prev, 0 tot_int_prev
             ,'M' query_10
        from md_cta_documentos o, ge_clientes e, ba_personas p, sb_crc_operaciones_det a,
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
         and t.estado=o.estado
         and o.nro_cuenta = a.nro_operacion
         and o.estado <> 'N'
         and o.cod_modalidad in (134,144);
      commit;
      --- Venta de Bienes Adjudicados
      insert into GE_PREVISION_DET_TMP(
             cod_modulo, riesgo, nombre_per, doc, nro_doc, cat_riesgo, cat_crc, ofi, oficina, ofi_usu, 
             cod_usu_oficial, nombre_usu, banca, cat_subjetiva, gru_eco, gru_eco_informado, cat_gru_economico, 
             cat_sistema, tot_deu_rsistema, tot_con_rsistema, tipo, tip_cliente, rubro, cod_modalidad, 
             nro_cuenta, saldo_interes, fecha_inicio_oper, cod_moneda, cod_estado, estado, tot_deu_real, 
             tot_deu_contingente, dev_no_cobrado, tot_gar_computables, tot_prevision, cat_automatica, 
             cat_renovaciones, dia_atraso, sdo_mora, tip_destino, destino, cod_sec_credito, desc_sec_crd, 
             tip_renovacion, mto_mora, sect_prestamo, desc_sect_prestamo, prim_prevision, seg_prevision, 
             cod_sub_modalidad, cod_campana, gru_eco_bcp, sub_cat_individual_no_r4, sub_cat_individual_r4, 
             es_covid, sub_cat_grupo, capital, tot_deuda, rie_des_prv_ant_garantia, rie_gar_nocubierto, 
             capital_inicial, act_primaria, des_act_primaria, cod_seg_cliente, nro_solicitud, canal_prestamo, 
             cod_pais, cod_tip_documento, cat_de_persona, tot_cap_prev, tot_int_prev, query_10)
      select 2 cod_modulo, o.cod_persona riesgo, ltrim(rtrim(p.nom_completo)) nombre_per, d.abreviatura doc, ltrim(rtrim(p.nro_documento)) nro_doc,
             e.cat_riesgo, fup_obt_categoria(e.cat_automatica,e.cat_subjetiva) cat_crc, e.cod_oficina ofi, n.descripcion oficina,
             u.cod_oficina ofi_usu, e.cod_usu_oficial, u.nombre nombre_usu, g.descripcion banca, e.cat_subjetiva, e.cod_gru_economico gru_eco,
             (CASE WHEN (SELECT COUNT(DISTINCT g1.cod_persona) FROM ge_cla_operaciones g1, ge_clientes g2 WHERE g1.cod_persona = g2.cod_persona AND g2.cod_gru_economico = e.cod_gru_economico) > 1 THEN e.cod_gru_economico END) GRU_ECO_INFORMADO,
             e.cat_gru_economico, e.cat_sistema, e.tot_deu_sistema tot_deu_rsistema, e.tot_deu_con_sistema tot_con_rsistema,
             e.tipo, substr(r1.significado,1,40) tip_cliente, o.rubro_activo rubro,
             null cod_modalidad, o.cod_persona nro_cuenta,o.sal_ganancia saldo_interes, to_char(o.fec_alta,'dd/mm/yyyy') fecha_inicio_oper,o.cod_moneda, null cod_estado, null estado, (o.mto_cuota * o.cuo_pendientes) tot_deu_real,
             0 tot_deu_contingente, 0 dev_no_cobrado,
             0 tot_gar_computables, 0 tot_prevision, e.cat_automatica, null cat_renovaciones, 0 dia_atraso, null sdo_mora,
             null tip_destino, null destino, null cod_sec_credito, null desc_sec_crd,
             'Nuevo' Tip_renovacion,
             0 mto_mora, null sect_prestamo,
             null desc_sect_prestamo,
             0 prim_prevision,
             0 seg_prevision,
             null cod_sub_modalidad,  null cod_campana,
             (SELECT MAX(bc.val_minimo)
                FROM ba_cod_referencias bc
               WHERE bc.dominio = 'GRU_ECO_BCP'
                 AND bc.val_maximo = nvl(e.cod_gru_economico,0)
                 AND bc.fec_modificacion = (SELECT MAX(re.fec_modificacion)
                                              FROM ba_cod_referencias re
                                             WHERE bc.dominio = re.dominio
                                               AND bc.val_maximo = re.val_maximo)) GRU_ECO_BCP,
             (CASE WHEN e.cat_riesgo = 1 THEN NVL((select MAX((CASE WHEN a.cat_automatica >= 2 THEN 1.2 ELSE a.cat_automatica END)) from ge_cla_operaciones a  where a.cod_persona = o.cod_persona
               and nvl(fug_obt_pardinamico('COD_MAD_RESOLUCION04', a.cod_modulo, a.cod_modalidad),'N') = 'N'
              ),1) END) SUB_CAT_INDIVIDUAL_NO_R4,
             (CASE WHEN e.cat_riesgo = 1 THEN NVL((select MAX((CASE WHEN a.cat_automatica >= 2 THEN 1.2 ELSE a.cat_automatica END)) from ge_cla_operaciones a where a.cod_persona = o.cod_persona
               and nvl(fug_obt_pardinamico('COD_MAD_RESOLUCION04', a.cod_modulo, a.cod_modalidad),'N') = 'S'
              ),1) END) SUB_CAT_INDIVIDUAL_R4,
             'N' ES_COVID,
             (CASE WHEN e.cod_gru_economico IS NOT NULL THEN (CASE WHEN e.cat_riesgo = 1 THEN NVL((select MAX((CASE WHEN a.cat_automatica >= 2 THEN 1.2 ELSE a.cat_automatica END)) from ge_cla_operaciones a where a.cod_persona IN (SELECT x.cod_persona FROM ge_clientes x where x.cod_gru_economico = e.cod_gru_economico)),1) END) END) SUB_CAT_GRUPO,
              o.sal_actual CAPITAL, o.sal_actual TOT_DEUDA, 0 RIE_DES_PRV_ANT_GARANTIA, 0 RIE_GAR_NOCUBIERTO, 0 CAPITAL_INICIAL
             ,p.cod_rub_primario ACT_PRIMARIA,fug_obt_des_actividad(P.COD_RUB_PRIMARIO,'N') DES_ACT_PRIMARIA
             ,e.cod_seg_cliente, null nro_solicitud, null canal_prestamo
             ,p.cod_pais, p.cod_tip_documento, e.cat_automatica cat_de_persona
             ,0 tot_cap_prev, 0 tot_int_prev
             ,'B' query_10
        from CB_INV_BIE_VENDIDOS o, ge_clientes e, ba_personas p,
             ba_tip_documentos d, ba_oficinas n, ba_cod_referencias r1,
             ba_usuarios u,  ba_oficinas f, ba_gru_oficinas g
       where o.cod_persona=e.cod_persona
         and e.cod_persona=p.cod_persona
         and p.cod_tip_documento=d.cod_tip_documento
         and e.cod_oficina=n.cod_oficina
         and r1.dominio='TIP_CLIENTE'
         and r1.val_minimo=nvl(e.tipo,'T')
         and e.cod_usu_oficial=u.cod_usuario
         and u.cod_oficina=f.cod_oficina 
         and f.cod_gru_oficina=g.cod_gru_oficina(+);
      commit;
      --- Ventas de Cartera No Financiero (Figura en el Inventario Contable)
      insert into GE_PREVISION_DET_TMP(
             cod_modulo, riesgo, nombre_per, doc, nro_doc, cat_riesgo, cat_crc, ofi, oficina, ofi_usu, 
             cod_usu_oficial, nombre_usu, banca, cat_subjetiva, gru_eco, gru_eco_informado, cat_gru_economico, 
             cat_sistema, tot_deu_rsistema, tot_con_rsistema, tipo, tip_cliente, rubro, cod_modalidad, 
             nro_cuenta, saldo_interes, fecha_inicio_oper, cod_moneda, cod_estado, estado, tot_deu_real, 
             tot_deu_contingente, dev_no_cobrado, tot_gar_computables, tot_prevision, cat_automatica, 
             cat_renovaciones, dia_atraso, sdo_mora, tip_destino, destino, cod_sec_credito, desc_sec_crd, 
             tip_renovacion, mto_mora, sect_prestamo, desc_sect_prestamo, prim_prevision, seg_prevision, 
             cod_sub_modalidad, cod_campana, gru_eco_bcp, sub_cat_individual_no_r4, sub_cat_individual_r4, 
             es_covid, sub_cat_grupo, capital, tot_deuda, rie_des_prv_ant_garantia, rie_gar_nocubierto, 
             capital_inicial, act_primaria, des_act_primaria, cod_seg_cliente, nro_solicitud, canal_prestamo, 
             cod_pais, cod_tip_documento, cat_de_persona, tot_cap_prev, tot_int_prev, query_10)
      select d.cod_modulo, p.cod_persona riesgo, ltrim(rtrim(p.nom_completo)) nombre_per,
             fue_obt_tip_doc_abreviatura(p.cod_tip_documento) doc,
             ltrim(rtrim(p.nro_documento)) nro_doc,
             to_char(d.cat_cliente), fup_obt_categoria(d.cat_cliente,e.cat_subjetiva) cat_crc, e.cod_oficina ofi,
             fue_obt_des_oficina(e.cod_oficina) oficina,
             (select u.cod_oficina
                from ba_usuarios u
               where e.cod_usu_oficial=u.cod_usuario) ofi_usu,
             e.cod_usu_oficial,
             (select u.nombre
                from ba_usuarios u
               where e.cod_usu_oficial=u.cod_usuario) nombre_usu,
             (select g.descripcion
                from ba_usuarios u,  ba_oficinas f, ba_gru_oficinas g
               where e.cod_usu_oficial=u.cod_usuario
                 and u.cod_oficina=f.cod_oficina 
                 and f.cod_gru_oficina=g.cod_gru_oficina(+)) banca,
             e.cat_subjetiva, e.cod_gru_economico gru_eco,
             (CASE WHEN (SELECT COUNT(DISTINCT g1.cod_persona) FROM ge_cla_operaciones g1, ge_clientes g2 WHERE g1.cod_persona = g2.cod_persona AND g2.cod_gru_economico = e.cod_gru_economico) > 1 THEN e.cod_gru_economico END) GRU_ECO_INFORMADO,
             e.cat_gru_economico, d.cat_sistema, e.tot_deu_sistema tot_deu_rsistema, e.tot_deu_con_sistema tot_con_rsistema,
             e.tipo, substr(r1.significado,1,40) tip_cliente, 
             fub_obt_rub_contable(d.cod_modulo,d.nro_cuenta) rubro,
             d.cod_modalidad cod_modalidad, d.nro_cuenta,
             0 saldo_interes, fug_obt_dat_operaciones(d.nro_cuenta,'F') fecha_inicio_oper, 
             g.cod_moneda cod_moneda,
             d.estado cod_estado, decode(d.estado,'V','Vendida','C','Confirmada','E','Excluida','N','Cancelada',null) estado,
                           
             nvl(nvl(d.sal_deu_cta_actual,d.mto_deu_mon_cuenta),0) tot_deu_real,
                 
             0 tot_deu_contingente, 0 dev_no_cobrado,
             0 tot_gar_computables, 0 tot_prevision,
                
             d.cat_ope_actual cat_automatica,
                
             null cat_renovaciones, 0 dia_atraso, null sdo_mora,
             null tip_destino, null destino, null cod_sec_credito, null desc_sec_crd,
             'Nuevo' Tip_renovacion,
             0 mto_mora, null sect_prestamo,
             null desc_sect_prestamo,
             0 prim_prevision,
             0 seg_prevision,
             null cod_sub_modalidad,  null cod_campana,
             (SELECT MAX(bc.val_minimo)
                FROM ba_cod_referencias bc
               WHERE bc.dominio = 'GRU_ECO_BCP'
                 AND bc.val_maximo = nvl(e.cod_gru_economico,0)
                 AND bc.fec_modificacion = (SELECT MAX(re.fec_modificacion)
                                              FROM ba_cod_referencias re
                                             WHERE bc.dominio = re.dominio
                                               AND bc.val_maximo = re.val_maximo)) GRU_ECO_BCP,
             (CASE WHEN d.cat_cliente  = 1 THEN NVL((select MAX((CASE WHEN a.cat_automatica >= 2 THEN 1.2 ELSE a.cat_automatica END)) from ge_cla_operaciones a  where a.cod_persona = p.cod_persona
               and nvl(fug_obt_pardinamico('COD_MAD_RESOLUCION04', a.cod_modulo, a.cod_modalidad),'N') = 'N'
              ),1) END) SUB_CAT_INDIVIDUAL_NO_R4,
             (CASE WHEN d.cat_cliente = 1 THEN NVL((select MAX((CASE WHEN a.cat_automatica >= 2 THEN 1.2 ELSE a.cat_automatica END)) from ge_cla_operaciones a where a.cod_persona = p.cod_persona
               and nvl(fug_obt_pardinamico('COD_MAD_RESOLUCION04', a.cod_modulo, a.cod_modalidad),'N') = 'S'
              ),1) END) SUB_CAT_INDIVIDUAL_R4,
             'N' ES_COVID,
             (CASE WHEN e.cod_gru_economico IS NOT NULL THEN (CASE WHEN d.cat_cliente = 1 THEN NVL((select MAX((CASE WHEN a.cat_automatica >= 2 THEN 1.2 ELSE a.cat_automatica END)) from ge_cla_operaciones a where a.cod_persona IN (SELECT x.cod_persona FROM ge_clientes x where x.cod_gru_economico = e.cod_gru_economico)),1) END) END) SUB_CAT_GRUPO,
                  
             nvl(nvl(d.sal_deu_cta_actual,d.mto_deu_mon_cuenta),0) CAPITAL, 
             nvl(nvl(d.sal_deu_cta_actual,d.mto_deu_mon_cuenta),0) TOT_DEUDA, 
                  
             0 RIE_DES_PRV_ANT_GARANTIA, 0 RIE_GAR_NOCUBIERTO, 0 CAPITAL_INICIAL
             ,p.cod_rub_primario ACT_PRIMARIA,fug_obt_des_actividad(P.COD_RUB_PRIMARIO,'N') DES_ACT_PRIMARIA
             ,e.cod_seg_cliente, null nro_solicitud, null canal_prestamo
             ,p.cod_pais, p.cod_tip_documento, d.cat_cliente cat_de_persona
             ,0 tot_cap_prev, 0 tot_int_prev
             ,'C' query_10
        from ge_sal_inv_vta_cartera_his d, ge_clientes e, ba_personas p, ba_cod_referencias r1, ge_cuentas g
       where d.cod_persona=e.cod_persona
         and e.cod_persona=p.cod_persona
         and d.nro_cuenta=g.nro_cuenta 
         and r1.val_minimo=nvl(e.tipo,'T')
         and r1.dominio='TIP_CLIENTE'
         and d.estado in ('V','C')--DYDMR-9157 - También deben ser consideradas las 'Confirmadas'.-
         and d.ope_recaptados = 'N';
      commit;
      --- Ventas de Cartera Particulares Prestamos (NO Figura en el Inventario Contable)
      insert into GE_PREVISION_DET_TMP(
             cod_modulo, riesgo, nombre_per, doc, nro_doc, cat_riesgo, cat_crc, ofi, oficina, ofi_usu, 
             cod_usu_oficial, nombre_usu, banca, cat_subjetiva, gru_eco, gru_eco_informado, cat_gru_economico, 
             cat_sistema, tot_deu_rsistema, tot_con_rsistema, tipo, tip_cliente, rubro, cod_modalidad, 
             nro_cuenta, saldo_interes, fecha_inicio_oper, cod_moneda, cod_estado, estado, tot_deu_real, 
             tot_deu_contingente, dev_no_cobrado, tot_gar_computables, tot_prevision, cat_automatica, 
             cat_renovaciones, dia_atraso, sdo_mora, tip_destino, destino, cod_sec_credito, desc_sec_crd, 
             tip_renovacion, mto_mora, sect_prestamo, desc_sect_prestamo, prim_prevision, seg_prevision, 
             cod_sub_modalidad, cod_campana, gru_eco_bcp, sub_cat_individual_no_r4, sub_cat_individual_r4, 
             es_covid, sub_cat_grupo, capital, tot_deuda, rie_des_prv_ant_garantia, rie_gar_nocubierto, 
             capital_inicial, act_primaria, des_act_primaria, cod_seg_cliente, nro_solicitud, canal_prestamo, 
             cod_pais, cod_tip_documento, cat_de_persona, tot_cap_prev, tot_int_prev, query_10)
      select o.cod_modulo, p.cod_persona riesgo, ltrim(rtrim(p.nom_completo)) nombre_per,
             fue_obt_tip_doc_abreviatura(p.cod_tip_documento) doc,
             ltrim(rtrim(p.nro_documento)) nro_doc,
             e.cat_riesgo, fup_obt_categoria(e.cat_automatica,e.cat_subjetiva) cat_crc, e.cod_oficina ofi,
             fue_obt_des_oficina(e.cod_oficina) oficina,
             (select u.cod_oficina
                from ba_usuarios u
               where e.cod_usu_oficial=u.cod_usuario) ofi_usu,
             e.cod_usu_oficial,
             (select u.nombre
                from ba_usuarios u
               where e.cod_usu_oficial=u.cod_usuario) nombre_usu,
             (select g.descripcion
                from ba_usuarios u,  ba_oficinas f, ba_gru_oficinas g
               where e.cod_usu_oficial=u.cod_usuario
                 and u.cod_oficina=f.cod_oficina 
                 and f.cod_gru_oficina=g.cod_gru_oficina(+)) banca,
             e.cat_subjetiva, e.cod_gru_economico gru_eco,
             (CASE WHEN (SELECT COUNT(DISTINCT g1.cod_persona) FROM ge_cla_operaciones g1, ge_clientes g2 WHERE g1.cod_persona = g2.cod_persona AND g2.cod_gru_economico = e.cod_gru_economico) > 1 THEN e.cod_gru_economico END) GRU_ECO_INFORMADO,
             e.cat_gru_economico, e.cat_sistema, e.tot_deu_sistema tot_deu_rsistema, e.tot_deu_con_sistema tot_con_rsistema,
             e.tipo, substr(r1.significado,1,40) tip_cliente, o.rub_con_capital rubro,
             o.cod_modalidad cod_modalidad,
             nvl(substr(o.nro_operacion,1,INSTR(o.nro_operacion,'#')-1),o.nro_operacion) nro_cuenta,
             nvl(o.sal_int_dev_no_cobrado,0) saldo_interes, fug_obt_dat_operaciones(o.nro_operacion,'F') fecha_inicio_oper, 
             (select b.cod_moneda
                from ba_monedas b
               where c.cod_mon_iso=b.cod_mon_iso) cod_moneda,
             null cod_estado, null estado,
                           
             (nvl(o.sal_capital,0)+nvl(o.sal_int_dev_no_cobrado,0)) tot_deu_real,
                 
             0 tot_deu_contingente, nvl(o.sal_int_dev_no_cobrado,0) dev_no_cobrado,
             0 tot_gar_computables, 0 tot_prevision,
                
             to_number(decode(cla_riesgo,'1a','1.1','1b','1.2',cla_riesgo)) cat_automatica,
                
             null cat_renovaciones, 0 dia_atraso, null sdo_mora,
             null tip_destino, null destino, null cod_sec_credito, null desc_sec_crd,
             'Nuevo' Tip_renovacion,
             0 mto_mora, null sect_prestamo,
             null desc_sect_prestamo,
             0 prim_prevision,
             0 seg_prevision,
             null cod_sub_modalidad,  null cod_campana,
             (SELECT MAX(bc.val_minimo)
                FROM ba_cod_referencias bc
               WHERE bc.dominio = 'GRU_ECO_BCP'
                 AND bc.val_maximo = nvl(e.cod_gru_economico,0)
                 AND bc.fec_modificacion = (SELECT MAX(re.fec_modificacion)
                                              FROM ba_cod_referencias re
                                             WHERE bc.dominio = re.dominio
                                               AND bc.val_maximo = re.val_maximo)) GRU_ECO_BCP,
             (CASE WHEN e.cat_riesgo = 1 THEN NVL((select MAX((CASE WHEN a.cat_automatica >= 2 THEN 1.2 ELSE a.cat_automatica END)) from ge_cla_operaciones a  where a.cod_persona = c.cod_persona
               and nvl(fug_obt_pardinamico('COD_MAD_RESOLUCION04', a.cod_modulo, a.cod_modalidad),'N') = 'N'
              ),1) END) SUB_CAT_INDIVIDUAL_NO_R4,
             (CASE WHEN e.cat_riesgo = 1 THEN NVL((select MAX((CASE WHEN a.cat_automatica >= 2 THEN 1.2 ELSE a.cat_automatica END)) from ge_cla_operaciones a where a.cod_persona = c.cod_persona
               and nvl(fug_obt_pardinamico('COD_MAD_RESOLUCION04', a.cod_modulo, a.cod_modalidad),'N') = 'S'
              ),1) END) SUB_CAT_INDIVIDUAL_R4,
             'N' ES_COVID,
             (CASE WHEN e.cod_gru_economico IS NOT NULL THEN (CASE WHEN e.cat_riesgo = 1 THEN NVL((select MAX((CASE WHEN a.cat_automatica >= 2 THEN 1.2 ELSE a.cat_automatica END)) from ge_cla_operaciones a where a.cod_persona IN (SELECT x.cod_persona FROM ge_clientes x where x.cod_gru_economico = e.cod_gru_economico)),1) END) END) SUB_CAT_GRUPO,
                  
             nvl(o.sal_capital,0) CAPITAL, 
             (nvl(o.sal_capital,0)+nvl(o.sal_int_dev_no_cobrado,0)) TOT_DEUDA, 
                
             0 RIE_DES_PRV_ANT_GARANTIA, 0 RIE_GAR_NOCUBIERTO, 0 CAPITAL_INICIAL
             ,p.cod_rub_primario ACT_PRIMARIA,fug_obt_des_actividad(P.COD_RUB_PRIMARIO,'N') DES_ACT_PRIMARIA
             ,e.cod_seg_cliente, null nro_solicitud, null canal_prestamo
             ,p.cod_pais, p.cod_tip_documento, e.cat_automatica cat_de_persona
             ,0 tot_cap_prev, 0 tot_int_prev
             ,'V' query_10
        from sb_crc_vinculos_det c, sb_crc_saldos_det o, 
             ge_cta_clientes d, pr_cta_prestamos pr,
             ge_clientes e, ba_personas p, ba_cod_referencias r1
       where c.nro_operacion = o.nro_operacion
         and c.tip_operacion = o.tip_operacion
         and d.nro_cuenta = pr.nro_cuenta
         and nvl(substr(o.nro_operacion,1,INSTR(o.nro_operacion,'#')-1),o.nro_operacion) = d.nro_cuenta
         and o.fecha = v_max_fec_saldos
         and substr(o.rub_con_capital,6,3) = '697'
         and c.tip_vinculo = 9
         and d.relacion = 'P'
         and d.cod_persona = e.cod_persona
         and p.cod_persona=e.cod_persona
         and r1.dominio='TIP_CLIENTE'
         and r1.val_minimo=nvl(e.tipo,'T')
         and not exists (select 1 from ge_cla_operaciones a
                          where d.nro_cuenta = a.nro_cuenta)
         and not exists (select 1 from ge_sal_inv_vta_cartera_his h
                          where d.nro_cuenta = h.nro_cuenta
                            and h.estado in ('V','C')--DYDMR-9157 - También deben ser consideradas las 'Confirmadas'.-
                            and h.ope_recaptados = 'N')
         and not exists (select 1 from ge_cla_operaciones a
                          where nvl(substr(o.nro_operacion,INSTR(o.nro_operacion,'##')+2),o.nro_operacion) = a.nro_cuenta)
         and not exists (select 1 from ge_sal_inv_vta_cartera_his h
                          where nvl(substr(o.nro_operacion,INSTR(o.nro_operacion,'##')+2),o.nro_operacion) = h.nro_cuenta
                            and h.estado in ('V','C')--DYDMR-9157 - También deben ser consideradas las 'Confirmadas'.-
                            and h.ope_recaptados = 'N');
      commit;
      --- Venta de Cartera Particulares Operaciones Vencidas (NO Figura en el Inventario Contable)
      insert into GE_PREVISION_DET_TMP(
             cod_modulo, riesgo, nombre_per, doc, nro_doc, cat_riesgo, cat_crc, ofi, oficina, ofi_usu, 
             cod_usu_oficial, nombre_usu, banca, cat_subjetiva, gru_eco, gru_eco_informado, cat_gru_economico, 
             cat_sistema, tot_deu_rsistema, tot_con_rsistema, tipo, tip_cliente, rubro, cod_modalidad, 
             nro_cuenta, saldo_interes, fecha_inicio_oper, cod_moneda, cod_estado, estado, tot_deu_real, 
             tot_deu_contingente, dev_no_cobrado, tot_gar_computables, tot_prevision, cat_automatica, 
             cat_renovaciones, dia_atraso, sdo_mora, tip_destino, destino, cod_sec_credito, desc_sec_crd, 
             tip_renovacion, mto_mora, sect_prestamo, desc_sect_prestamo, prim_prevision, seg_prevision, 
             cod_sub_modalidad, cod_campana, gru_eco_bcp, sub_cat_individual_no_r4, sub_cat_individual_r4, 
             es_covid, sub_cat_grupo, capital, tot_deuda, rie_des_prv_ant_garantia, rie_gar_nocubierto, 
             capital_inicial, act_primaria, des_act_primaria, cod_seg_cliente, nro_solicitud, canal_prestamo, 
             cod_pais, cod_tip_documento, cat_de_persona, tot_cap_prev, tot_int_prev, query_10)
      select o.cod_modulo, p.cod_persona riesgo, ltrim(rtrim(p.nom_completo)) nombre_per,
             fue_obt_tip_doc_abreviatura(p.cod_tip_documento) doc,
             ltrim(rtrim(p.nro_documento)) nro_doc,
             e.cat_riesgo, fup_obt_categoria(e.cat_automatica,e.cat_subjetiva) cat_crc, e.cod_oficina ofi,
             fue_obt_des_oficina(e.cod_oficina) oficina,
             (select u.cod_oficina
                from ba_usuarios u
               where e.cod_usu_oficial=u.cod_usuario) ofi_usu,
             e.cod_usu_oficial,
             (select u.nombre
                from ba_usuarios u
               where e.cod_usu_oficial=u.cod_usuario) nombre_usu,
             (select g.descripcion
                from ba_usuarios u,  ba_oficinas f, ba_gru_oficinas g
               where e.cod_usu_oficial=u.cod_usuario
                 and u.cod_oficina=f.cod_oficina 
                 and f.cod_gru_oficina=g.cod_gru_oficina(+)) banca,
             e.cat_subjetiva, e.cod_gru_economico gru_eco,
             (CASE WHEN (SELECT COUNT(DISTINCT g1.cod_persona) FROM ge_cla_operaciones g1, ge_clientes g2 WHERE g1.cod_persona = g2.cod_persona AND g2.cod_gru_economico = e.cod_gru_economico) > 1 THEN e.cod_gru_economico END) GRU_ECO_INFORMADO,
             e.cat_gru_economico, e.cat_sistema, e.tot_deu_sistema tot_deu_rsistema, e.tot_deu_con_sistema tot_con_rsistema,
             e.tipo, substr(r1.significado,1,40) tip_cliente, o.rub_con_capital rubro,
             o.cod_modalidad cod_modalidad,
             nvl(substr(o.nro_operacion,1,INSTR(o.nro_operacion,'#')-1),o.nro_operacion) nro_cuenta,
             nvl(o.sal_int_dev_no_cobrado,0) saldo_interes, fug_obt_dat_operaciones(o.nro_operacion,'F') fecha_inicio_oper, 
             (select b.cod_moneda
                from ba_monedas b
               where c.cod_mon_iso=b.cod_mon_iso) cod_moneda,
             null cod_estado, null estado,
                            
             (nvl(o.sal_capital,0)+nvl(o.sal_int_dev_no_cobrado,0)) tot_deu_real,
                  
             0 tot_deu_contingente, nvl(o.sal_int_dev_no_cobrado,0) dev_no_cobrado,
             0 tot_gar_computables, 0 tot_prevision,
                
             to_number(decode(cla_riesgo,'1a','1.1','1b','1.2',cla_riesgo)) cat_automatica,
                 
             null cat_renovaciones, 0 dia_atraso, null sdo_mora,
             null tip_destino, null destino, null cod_sec_credito, null desc_sec_crd,
             'Nuevo' Tip_renovacion,
             0 mto_mora, null sect_prestamo,
             null desc_sect_prestamo,
             0 prim_prevision,
             0 seg_prevision,
             null cod_sub_modalidad,  null cod_campana,
             (SELECT MAX(bc.val_minimo)
                FROM ba_cod_referencias bc
               WHERE bc.dominio = 'GRU_ECO_BCP'
                 AND bc.val_maximo = nvl(e.cod_gru_economico,0)
                 AND bc.fec_modificacion = (SELECT MAX(re.fec_modificacion)
                                              FROM ba_cod_referencias re
                                             WHERE bc.dominio = re.dominio
                                               AND bc.val_maximo = re.val_maximo)) GRU_ECO_BCP,
             (CASE WHEN e.cat_riesgo = 1 THEN NVL((select MAX((CASE WHEN a.cat_automatica >= 2 THEN 1.2 ELSE a.cat_automatica END)) from ge_cla_operaciones a  where a.cod_persona = c.cod_persona
               and nvl(fug_obt_pardinamico('COD_MAD_RESOLUCION04', a.cod_modulo, a.cod_modalidad),'N') = 'N'
               ),1) END) SUB_CAT_INDIVIDUAL_NO_R4,
             (CASE WHEN e.cat_riesgo = 1 THEN NVL((select MAX((CASE WHEN a.cat_automatica >= 2 THEN 1.2 ELSE a.cat_automatica END)) from ge_cla_operaciones a where a.cod_persona = c.cod_persona
               and nvl(fug_obt_pardinamico('COD_MAD_RESOLUCION04', a.cod_modulo, a.cod_modalidad),'N') = 'S'
              ),1) END) SUB_CAT_INDIVIDUAL_R4,
             'N' ES_COVID,
             (CASE WHEN e.cod_gru_economico IS NOT NULL THEN (CASE WHEN e.cat_riesgo = 1 THEN NVL((select MAX((CASE WHEN a.cat_automatica >= 2 THEN 1.2 ELSE a.cat_automatica END)) from ge_cla_operaciones a where a.cod_persona IN (SELECT x.cod_persona FROM ge_clientes x where x.cod_gru_economico = e.cod_gru_economico)),1) END) END) SUB_CAT_GRUPO,
                  
             nvl(o.sal_capital,0) CAPITAL, 
             (nvl(o.sal_capital,0)+nvl(o.sal_int_dev_no_cobrado,0)) TOT_DEUDA, 
                  
             0 RIE_DES_PRV_ANT_GARANTIA, 0 RIE_GAR_NOCUBIERTO, 0 CAPITAL_INICIAL
             ,p.cod_rub_primario ACT_PRIMARIA,fug_obt_des_actividad(P.COD_RUB_PRIMARIO,'N') DES_ACT_PRIMARIA
             ,e.cod_seg_cliente, null nro_solicitud, null canal_prestamo
             ,p.cod_pais, p.cod_tip_documento, e.cat_automatica cat_de_persona
             ,0 tot_cap_prev, 0 tot_int_prev
             ,'V' query_10
        from sb_crc_vinculos_det c, sb_crc_saldos_det o, 
             ge_cta_clientes d, ov_cta_vencidas ov,
             ge_clientes e, ba_personas p, ba_cod_referencias r1
       where c.nro_operacion = o.nro_operacion
         and c.tip_operacion = o.tip_operacion
         and d.nro_cuenta = ov.nro_cta_origen
         and nvl(substr(o.nro_operacion,1,INSTR(o.nro_operacion,'#')-1),o.nro_operacion) = d.nro_cuenta
         and o.fecha = v_max_fec_saldos
         and substr(o.rub_con_capital,6,3) = '697'
         and c.tip_vinculo = 9
         and d.relacion = 'P'
         and d.cod_persona = e.cod_persona
         and p.cod_persona=e.cod_persona
         and r1.dominio='TIP_CLIENTE'
         and r1.val_minimo=nvl(e.tipo,'T')
         and not exists (select 1 from ge_cla_operaciones a
                          where d.nro_cuenta = a.nro_cuenta)
         and not exists (select 1 from ge_sal_inv_vta_cartera_his h
                          where d.nro_cuenta = h.nro_cuenta
                            and h.estado in ('V','C')--DYDMR-9157 - También deben ser consideradas las 'Confirmadas'.-
                            and h.ope_recaptados = 'N')
         and not exists (select 1 from ge_cla_operaciones a
                          where ov.nro_cuenta = a.nro_cuenta)
         and not exists (select 1 from ge_sal_inv_vta_cartera_his h
                          where ov.nro_cuenta = h.nro_cuenta
                            and h.estado in ('V','C')--DYDMR-9157 - También deben ser consideradas las 'Confirmadas'.-
                            and h.ope_recaptados = 'N');
      commit;
      --- Venta a particulares que a pesar de estar registrado
      --- en la tabla GE_SAL_INV_VTA_CARTERA_HIS (sin saldo),
      --- se incluye manualmente en el reporte normativo 
      insert into GE_PREVISION_DET_TMP(
             cod_modulo, riesgo, nombre_per, doc, nro_doc, cat_riesgo, cat_crc, ofi, oficina, ofi_usu, 
             cod_usu_oficial, nombre_usu, banca, cat_subjetiva, gru_eco, gru_eco_informado, cat_gru_economico, 
             cat_sistema, tot_deu_rsistema, tot_con_rsistema, tipo, tip_cliente, rubro, cod_modalidad, 
             nro_cuenta, saldo_interes, fecha_inicio_oper, cod_moneda, cod_estado, estado, tot_deu_real, 
             tot_deu_contingente, dev_no_cobrado, tot_gar_computables, tot_prevision, cat_automatica, 
             cat_renovaciones, dia_atraso, sdo_mora, tip_destino, destino, cod_sec_credito, desc_sec_crd, 
             tip_renovacion, mto_mora, sect_prestamo, desc_sect_prestamo, prim_prevision, seg_prevision, 
             cod_sub_modalidad, cod_campana, gru_eco_bcp, sub_cat_individual_no_r4, sub_cat_individual_r4, 
             es_covid, sub_cat_grupo, capital, tot_deuda, rie_des_prv_ant_garantia, rie_gar_nocubierto, 
             capital_inicial, act_primaria, des_act_primaria, cod_seg_cliente, nro_solicitud, canal_prestamo, 
             cod_pais, cod_tip_documento, cat_de_persona, tot_cap_prev, tot_int_prev, query_10)
      select o.cod_modulo, p.cod_persona riesgo, ltrim(rtrim(p.nom_completo)) nombre_per,
             fue_obt_tip_doc_abreviatura(p.cod_tip_documento) doc,
             ltrim(rtrim(p.nro_documento)) nro_doc,
             e.cat_riesgo, fup_obt_categoria(e.cat_automatica,e.cat_subjetiva) cat_crc, e.cod_oficina ofi,
             fue_obt_des_oficina(e.cod_oficina) oficina,
             (select u.cod_oficina
                from ba_usuarios u
               where e.cod_usu_oficial=u.cod_usuario) ofi_usu,
             e.cod_usu_oficial,
             (select u.nombre
                from ba_usuarios u
               where e.cod_usu_oficial=u.cod_usuario) nombre_usu,
             (select g.descripcion
                from ba_usuarios u,  ba_oficinas f, ba_gru_oficinas g
               where e.cod_usu_oficial=u.cod_usuario
                 and u.cod_oficina=f.cod_oficina 
                 and f.cod_gru_oficina=g.cod_gru_oficina(+)) banca,
             e.cat_subjetiva, e.cod_gru_economico gru_eco,
             (CASE WHEN (SELECT COUNT(DISTINCT g1.cod_persona) FROM ge_cla_operaciones g1, ge_clientes g2 WHERE g1.cod_persona = g2.cod_persona AND g2.cod_gru_economico = e.cod_gru_economico) > 1 THEN e.cod_gru_economico END) GRU_ECO_INFORMADO,
             e.cat_gru_economico, e.cat_sistema, e.tot_deu_sistema tot_deu_rsistema, e.tot_deu_con_sistema tot_con_rsistema,
             e.tipo, substr(r1.significado,1,40) tip_cliente, o.rub_con_capital rubro,
             o.cod_modalidad cod_modalidad,
             nvl(substr(o.nro_operacion,1,INSTR(o.nro_operacion,'#')-1),o.nro_operacion) nro_cuenta,
             nvl(o.sal_int_dev_no_cobrado,0) saldo_interes, fug_obt_dat_operaciones(o.nro_operacion,'F') fecha_inicio_oper, 
             (select b.cod_moneda
                from ba_monedas b
               where o.con_mon_iso=b.cod_mon_iso) cod_moneda,
             null cod_estado, null estado,
                            
             (nvl(o.sal_capital,0)+nvl(o.sal_int_dev_no_cobrado,0)) tot_deu_real,
                  
             0 tot_deu_contingente, nvl(o.sal_int_dev_no_cobrado,0) dev_no_cobrado,
             0 tot_gar_computables, 0 tot_prevision,
                 
             to_number(decode(cla_riesgo,'1a','1.1','1b','1.2',cla_riesgo)) cat_automatica,
                 
             null cat_renovaciones, 0 dia_atraso, null sdo_mora,
             null tip_destino, null destino, null cod_sec_credito, null desc_sec_crd,
             'Nuevo' Tip_renovacion,
             0 mto_mora, null sect_prestamo,
             null desc_sect_prestamo,
             0 prim_prevision,
             0 seg_prevision,
             null cod_sub_modalidad,  null cod_campana,
             (SELECT MAX(bc.val_minimo)
                FROM ba_cod_referencias bc
               WHERE bc.dominio = 'GRU_ECO_BCP'
                 AND bc.val_maximo = nvl(e.cod_gru_economico,0)
                 AND bc.fec_modificacion = (SELECT MAX(re.fec_modificacion)
                                              FROM ba_cod_referencias re
                                             WHERE bc.dominio = re.dominio
                                               AND bc.val_maximo = re.val_maximo)) GRU_ECO_BCP,
             (CASE WHEN e.cat_riesgo = 1 THEN NVL((select MAX((CASE WHEN a.cat_automatica >= 2 THEN 1.2 ELSE a.cat_automatica END)) from ge_cla_operaciones a  where a.cod_persona = p.cod_persona
               and nvl(fug_obt_pardinamico('COD_MAD_RESOLUCION04', a.cod_modulo, a.cod_modalidad),'N') = 'N'
              ),1) END) SUB_CAT_INDIVIDUAL_NO_R4,
             (CASE WHEN e.cat_riesgo = 1 THEN NVL((select MAX((CASE WHEN a.cat_automatica >= 2 THEN 1.2 ELSE a.cat_automatica END)) from ge_cla_operaciones a where a.cod_persona = p.cod_persona
               and nvl(fug_obt_pardinamico('COD_MAD_RESOLUCION04', a.cod_modulo, a.cod_modalidad),'N') = 'S'
              ),1) END) SUB_CAT_INDIVIDUAL_R4,
             'N' ES_COVID,
             (CASE WHEN e.cod_gru_economico IS NOT NULL THEN (CASE WHEN e.cat_riesgo = 1 THEN NVL((select MAX((CASE WHEN a.cat_automatica >= 2 THEN 1.2 ELSE a.cat_automatica END)) from ge_cla_operaciones a where a.cod_persona IN (SELECT x.cod_persona FROM ge_clientes x where x.cod_gru_economico = e.cod_gru_economico)),1) END) END) SUB_CAT_GRUPO,
                  
             nvl(o.sal_capital,0) CAPITAL, 
             (nvl(o.sal_capital,0)+nvl(o.sal_int_dev_no_cobrado,0)) TOT_DEUDA, 
                  
             0 RIE_DES_PRV_ANT_GARANTIA, 0 RIE_GAR_NOCUBIERTO, 0 CAPITAL_INICIAL
             ,p.cod_rub_primario ACT_PRIMARIA,fug_obt_des_actividad(P.COD_RUB_PRIMARIO,'N') DES_ACT_PRIMARIA
             ,e.cod_seg_cliente, null nro_solicitud, null canal_prestamo
             ,p.cod_pais, p.cod_tip_documento, e.cat_automatica cat_de_persona
             ,0 tot_cap_prev, 0 tot_int_prev
             ,'V' query_10
        from sb_crc_saldos_det o, ge_cta_clientes d, ba_cod_referencias h,
             ge_clientes e, ba_personas p, ba_cod_referencias r1
       where nvl(substr(o.nro_operacion,1,INSTR(o.nro_operacion,'#')-1),o.nro_operacion) = d.nro_cuenta
         and o.fecha = v_max_fec_saldos
         and substr(o.rub_con_capital,6,3) = '697'
         and d.relacion = 'P'
         and d.cod_persona = e.cod_persona
         and p.cod_persona=e.cod_persona
         and r1.dominio='TIP_CLIENTE'
         and r1.val_minimo=nvl(e.tipo,'T')
         and h.dominio = 'VENTA_CARTERA_PARTICULARES'
         and h.val_minimo = d.nro_cuenta;                     
      commit;
      --- Préstamos Incobrables
      insert into GE_PREVISION_DET_TMP(
             cod_modulo, riesgo, nombre_per, doc, nro_doc, cat_riesgo, cat_crc, ofi, oficina, ofi_usu, 
             cod_usu_oficial, nombre_usu, banca, cat_subjetiva, gru_eco, gru_eco_informado, cat_gru_economico, 
             cat_sistema, tot_deu_rsistema, tot_con_rsistema, tipo, tip_cliente, rubro, cod_modalidad, 
             nro_cuenta, saldo_interes, fecha_inicio_oper, cod_moneda, cod_estado, estado, tot_deu_real, 
             tot_deu_contingente, dev_no_cobrado, tot_gar_computables, tot_prevision, cat_automatica, 
             cat_renovaciones, dia_atraso, sdo_mora, tip_destino, destino, cod_sec_credito, desc_sec_crd, 
             tip_renovacion, mto_mora, sect_prestamo, desc_sect_prestamo, prim_prevision, seg_prevision, 
             cod_sub_modalidad, cod_campana, gru_eco_bcp, sub_cat_individual_no_r4, sub_cat_individual_r4, 
             es_covid, sub_cat_grupo, capital, tot_deuda, rie_des_prv_ant_garantia, rie_gar_nocubierto, 
             capital_inicial, act_primaria, des_act_primaria, cod_seg_cliente, nro_solicitud, canal_prestamo, 
             cod_pais, cod_tip_documento, cat_de_persona, tot_cap_prev, tot_int_prev, query_10)
      select o.cod_modulo, e.cod_persona riesgo, ltrim(rtrim(p.nom_completo)) nombre_per, d.abreviatura doc, ltrim(rtrim(p.nro_documento)) nro_doc,
             e.cat_riesgo, fup_obt_categoria(e.cat_automatica,e.cat_subjetiva) cat_crc, e.cod_oficina ofi, n.descripcion oficina,
             u.cod_oficina ofi_usu, e.cod_usu_oficial, u.nombre nombre_usu, g.descripcion banca, e.cat_subjetiva, e.cod_gru_economico gru_eco,
             -- Requerimiento: CNFAIRUNO-3.
             -- Fecha: 22/09/2014.
             (CASE WHEN (SELECT COUNT(DISTINCT g1.cod_persona) FROM ge_cla_operaciones g1, ge_clientes g2 WHERE g1.cod_persona = g2.cod_persona AND g2.cod_gru_economico = e.cod_gru_economico) > 1 THEN e.cod_gru_economico END) GRU_ECO_INFORMADO,
             e.cat_gru_economico, e.cat_sistema, e.tot_deu_sistema tot_deu_rsistema, e.tot_deu_con_sistema tot_con_rsistema,
             e.tipo, substr(r1.significado,1,40) tip_cliente, fub_obt_rub_contable(o.cod_modulo,o.nro_cuenta) rubro,
             o.cod_modalidad, o.nro_cuenta,
             0 saldo_interes,fug_obt_dat_operaciones(o.nro_cuenta,'F') fecha_inicio_oper,o.cod_moneda,
             o.estado, t.descripcion estado,
             (nvl(o.sal_cap_batch,0) + nvl(o.sal_int_batch,0) + nvl(o.sal_int_ade_batch,0)) tot_deu_real,
             0 tot_deu_contingente, o.dev_no_cobrado,
             0 tot_gar_computables, 
             0 tot_prevision, e.cat_automatica, o.cat_renovaciones, o.dia_atraso,fug_obt_sal_operacion(o.nro_cuenta,o.cod_moneda) sdo_mora,
             nvl(o.tip_destino,4) tip_destino, substr(r2.significado,1,20) destino, o.cod_sec_credito,
             case
                when o.cod_sec_credito = 701 then --En el proceso: it.pap_cat.PR_PRO_DAT_PRESTAMO se le asigna el COD_BCO_CENTRAL en el cod_sec_credito
                   'PRESTAMOS CONSUMO'
                when o.cod_sec_credito = 750 then
                   'PRESTAMOS PARA LA VIVIENDA H20/H30'
                when o.cod_sec_credito = 111 then
                   'CONSTRUCCION - OTROS'
                when o.cod_sec_credito = 135 then
                   'COMERCIO MINORISTA'
                when o.cod_sec_credito = 172 then
                   'ADELANTO DE IMP'
                when o.cod_sec_credito = 201 then
                   'EXPLOTACION GANADERIA'
                when o.Cod_Sec_Credito = 203 then
                   'OTRAS ACT.GANADERAS'
                when o.Cod_Sec_Credito = 330 then
                   'OTRAS INDUSTRIAS'
                when o.cod_sec_credito = 400 then
                   'EXPORTACION OTROS PRODUCTOS'
                when o.cod_sec_credito = 401 then
                   'EXPORTACION PRODUCTOS AGRÍCOLAS'
                when o.cod_sec_credito = 408 then
                   'IMPOR Y COMER. MAQ.Y  EQUIPOS'
                when o.cod_sec_credito = 409 then
                   'OTROS COMERCIOS AL POR MAYOR'
                when o.cod_sec_credito not in (111,135,172,201,203,330,400,401,408,409,701,750) then
                   (select se.descripcion from pr_sec_creditos se where se.cod_bco_central = o.cod_sec_credito and se.cod_sec_credito = o.cod_sec_credito)-- HO - DYDMR-6075 - "o.cod_sec_credito" se carga en el PAP_CAT.pr_pro_dat_prestamo desde el pv_cat_prestamos, donde apunta al campo cod_bco_central con un alias cod_sec_credito, por lo que se coloca "cod_bco_central = "
             end desc_sec_crd,
             decode(nvl(o.tip_renovacion,'A'),'A','Nuevo','D','Desembolso Etapas','V','Vista','E','Re-estructurado',
             'N','Renovado','R','Refinanciado','Otro') Tip_renovacion,
             0 mto_mora, o.cod_sec_credito sect_prestamo,
             (select se.descripcion from pr_sec_creditos se where se.cod_sec_credito = o.cod_sec_credito)desc_sect_prestamo,
             0 prim_prevision,
             0 seg_prevision,
             o.cod_sub_modalidad,  o.cod_campana,
             -- Requerimiento: CNFAIRUNO-3.
             -- Fecha: 22/09/2014.
             (SELECT MAX(bc.val_minimo)
                FROM ba_cod_referencias bc
               WHERE bc.dominio = 'GRU_ECO_BCP'
                 AND bc.val_maximo = nvl(e.cod_gru_economico,0)
                 AND bc.fec_modificacion = (SELECT MAX(re.fec_modificacion)
                                              FROM ba_cod_referencias re
                                             WHERE bc.dominio = re.dominio
                                               AND bc.val_maximo = re.val_maximo)) GRU_ECO_BCP,
             (CASE WHEN e.cat_riesgo = 1 THEN NVL((select MAX((CASE WHEN a.cat_automatica >= 2 THEN 1.2 ELSE a.cat_automatica END)) from ge_cla_operaciones a  where a.cod_persona = e.cod_persona
               and nvl(fug_obt_pardinamico('COD_MAD_RESOLUCION04', a.cod_modulo, a.cod_modalidad),'N') = 'N'
              ),1) END) SUB_CAT_INDIVIDUAL_NO_R4,
             (CASE WHEN e.cat_riesgo = 1 THEN NVL((select MAX((CASE WHEN a.cat_automatica >= 2 THEN 1.2 ELSE a.cat_automatica END)) from ge_cla_operaciones a where a.cod_persona = e.cod_persona
               and nvl(fug_obt_pardinamico('COD_MAD_RESOLUCION04', a.cod_modulo, a.cod_modalidad),'N') = 'S'
              ),1) END) SUB_CAT_INDIVIDUAL_R4,
             nvl(fug_obt_pardinamico('COD_MAD_RESOLUCION04', o.cod_modulo, o.cod_modalidad),'N') ES_COVID,
             (CASE WHEN e.cod_gru_economico IS NOT NULL THEN (CASE WHEN e.cat_riesgo = 1 THEN NVL((select MAX((CASE WHEN a.cat_automatica >= 2 THEN 1.2 ELSE a.cat_automatica END)) from ge_cla_operaciones a where a.cod_persona IN (SELECT x.cod_persona FROM ge_clientes x where x.cod_gru_economico = e.cod_gru_economico)),1) END) END) SUB_CAT_GRUPO,
             (nvl(o.sal_cap_batch,0) + nvl(o.sal_int_batch,0) + nvl(o.sal_int_ade_batch,0)) CAPITAL,
             (nvl(o.sal_cap_batch,0) + nvl(o.sal_int_batch,0) + nvl(o.sal_int_ade_batch,0)) TOT_DEUDA,
             0 RIE_DES_PRV_ANT_GARANTIA,
             0 RIE_GAR_NOCUBIERTO,
             -- DE-2044
             (CASE WHEN o.cod_modulo = 5 THEN NVL((select tr.lin_credito from ta_cta_tarjetas tr where tr.cod_modulo = o.cod_modulo and tr.nro_cuenta = o.nro_cuenta),1) 
                   ELSE (nvl(o.sal_cap_batch,0) + nvl(o.sal_int_batch,0) + nvl(o.sal_int_ade_batch,0)) END) CAPITAL_INICIAL

             ,p.cod_rub_primario ACT_PRIMARIA,fug_obt_des_actividad(P.COD_RUB_PRIMARIO,'N') DES_ACT_PRIMARIA
             ,e.cod_seg_cliente, o.nro_solicitud
             ,o.cod_canal canal_prestamo --RE DE-1358
             -- PIPROINTE-285 Riesgos - Anexo 1 - Reportes de Gestión requeridos por GNB Sudameris Colombia
             ,p.cod_pais, p.cod_tip_documento, e.cat_automatica cat_de_persona
             -- para previsiones de tarjetas y sobregiros
             ,0 tot_cap_prev
             ,0 tot_int_prev
             , 'P' query_10
        from pr_cta_prestamos o, ge_cta_clientes cl, ge_clientes e, ba_personas p,
             ba_tip_documentos d, ba_oficinas n, ba_cod_referencias r1, ge_est_cuentas t,
             ba_cod_referencias r2, ba_usuarios u,  ba_oficinas f, ba_gru_oficinas g
       where o.nro_cuenta=cl.nro_cuenta
         and cl.cod_persona=e.cod_persona
         and cl.relacion = 'P'
         and e.cod_persona=p.cod_persona
         and p.cod_tip_documento=d.cod_tip_documento
         and e.cod_oficina=n.cod_oficina
         and r1.dominio='TIP_CLIENTE'
         and r1.val_minimo=nvl(e.tipo,'T')
         and r2.dominio='TIP_DESTINO'
         and r2.val_minimo=nvl(o.tip_destino,4)
         and e.cod_usu_oficial=u.cod_usuario
         and u.cod_oficina=f.cod_oficina
         and f.cod_gru_oficina=g.cod_gru_oficina(+)
         and t.cod_modulo=o.cod_modulo
         and t.cod_modalidad=o.cod_modalidad
         and t.estado=o.estado
         and o.est_batch = 'I'
         and nvl(o.fec_inicio,v_fec_actual) <= v_fec_actual --DYDMR-9946 - Fecha de Operación prev_det
         and not exists (select 1 from ge_cla_operaciones a
                          where o.nro_cuenta = a.nro_cuenta);
      commit;
      --- Operaciones Vencidas Incobrables  
      insert into GE_PREVISION_DET_TMP(
             cod_modulo, riesgo, nombre_per, doc, nro_doc, cat_riesgo, cat_crc, ofi, oficina, ofi_usu, 
             cod_usu_oficial, nombre_usu, banca, cat_subjetiva, gru_eco, gru_eco_informado, cat_gru_economico, 
             cat_sistema, tot_deu_rsistema, tot_con_rsistema, tipo, tip_cliente, rubro, cod_modalidad, 
             nro_cuenta, saldo_interes, fecha_inicio_oper, cod_moneda, cod_estado, estado, tot_deu_real, 
             tot_deu_contingente, dev_no_cobrado, tot_gar_computables, tot_prevision, cat_automatica, 
             cat_renovaciones, dia_atraso, sdo_mora, tip_destino, destino, cod_sec_credito, desc_sec_crd, 
             tip_renovacion, mto_mora, sect_prestamo, desc_sect_prestamo, prim_prevision, seg_prevision, 
             cod_sub_modalidad, cod_campana, gru_eco_bcp, sub_cat_individual_no_r4, sub_cat_individual_r4, 
             es_covid, sub_cat_grupo, capital, tot_deuda, rie_des_prv_ant_garantia, rie_gar_nocubierto, 
             capital_inicial, act_primaria, des_act_primaria, cod_seg_cliente, nro_solicitud, canal_prestamo, 
             cod_pais, cod_tip_documento, cat_de_persona, tot_cap_prev, tot_int_prev, query_10)
      select o.cod_modulo, e.cod_persona riesgo, ltrim(rtrim(p.nom_completo)) nombre_per, d.abreviatura doc, ltrim(rtrim(p.nro_documento)) nro_doc,
             e.cat_riesgo, fup_obt_categoria(e.cat_automatica,e.cat_subjetiva) cat_crc, e.cod_oficina ofi, n.descripcion oficina,
             u.cod_oficina ofi_usu, e.cod_usu_oficial, u.nombre nombre_usu, g.descripcion banca, e.cat_subjetiva, e.cod_gru_economico gru_eco,
             -- Requerimiento: CNFAIRUNO-3.
             -- Fecha: 22/09/2014.
             (CASE WHEN (SELECT COUNT(DISTINCT g1.cod_persona) FROM ge_cla_operaciones g1, ge_clientes g2 WHERE g1.cod_persona = g2.cod_persona AND g2.cod_gru_economico = e.cod_gru_economico) > 1 THEN e.cod_gru_economico END) GRU_ECO_INFORMADO,
             e.cat_gru_economico, e.cat_sistema, e.tot_deu_sistema tot_deu_rsistema, e.tot_deu_con_sistema tot_con_rsistema,
             e.tipo, substr(r1.significado,1,40) tip_cliente, fub_obt_rub_contable(o.cod_modulo,o.nro_cuenta) rubro,
             o.cod_modalidad, o.nro_cuenta,
             0 saldo_interes,fug_obt_dat_operaciones(o.nro_cuenta,'F') fecha_inicio_oper,o.cod_moneda,
             o.estado, t.descripcion estado,
             nvl(o.sal_tot_batch,0) tot_deu_real,
             0 tot_deu_contingente, 0 dev_no_cobrado,
             0 tot_gar_computables, 
             0 tot_prevision, e.cat_automatica, e.cat_renovaciones, o.dia_atraso,fug_obt_sal_operacion(o.nro_cuenta,o.cod_moneda) sdo_mora,
             4 tip_destino, substr(r2.significado,1,20) destino, null cod_sec_credito,
             null desc_sec_crd,
             'Nuevo' Tip_renovacion,
             0 mto_mora, null sect_prestamo,
             null desc_sect_prestamo,
             0 prim_prevision,
             0 seg_prevision,
             null cod_sub_modalidad,  null cod_campana,
             -- Requerimiento: CNFAIRUNO-3.
             -- Fecha: 22/09/2014.
             (SELECT MAX(bc.val_minimo)
                FROM ba_cod_referencias bc
               WHERE bc.dominio = 'GRU_ECO_BCP'
                 AND bc.val_maximo = nvl(e.cod_gru_economico,0)
                 AND bc.fec_modificacion = (SELECT MAX(re.fec_modificacion)
                                              FROM ba_cod_referencias re
                                             WHERE bc.dominio = re.dominio
                                               AND bc.val_maximo = re.val_maximo)) GRU_ECO_BCP,
             (CASE WHEN e.cat_riesgo = 1 THEN NVL((select MAX((CASE WHEN a.cat_automatica >= 2 THEN 1.2 ELSE a.cat_automatica END)) from ge_cla_operaciones a  where a.cod_persona = e.cod_persona
               and nvl(fug_obt_pardinamico('COD_MAD_RESOLUCION04', a.cod_modulo, a.cod_modalidad),'N') = 'N'
              ),1) END) SUB_CAT_INDIVIDUAL_NO_R4,
             (CASE WHEN e.cat_riesgo = 1 THEN NVL((select MAX((CASE WHEN a.cat_automatica >= 2 THEN 1.2 ELSE a.cat_automatica END)) from ge_cla_operaciones a where a.cod_persona = e.cod_persona
               and nvl(fug_obt_pardinamico('COD_MAD_RESOLUCION04', a.cod_modulo, a.cod_modalidad),'N') = 'S'
              ),1) END) SUB_CAT_INDIVIDUAL_R4,
             nvl(fug_obt_pardinamico('COD_MAD_RESOLUCION04', o.cod_modulo, o.cod_modalidad),'N') ES_COVID,
             (CASE WHEN e.cod_gru_economico IS NOT NULL THEN (CASE WHEN e.cat_riesgo = 1 THEN NVL((select MAX((CASE WHEN a.cat_automatica >= 2 THEN 1.2 ELSE a.cat_automatica END)) from ge_cla_operaciones a where a.cod_persona IN (SELECT x.cod_persona FROM ge_clientes x where x.cod_gru_economico = e.cod_gru_economico)),1) END) END) SUB_CAT_GRUPO,
             nvl(o.sal_tot_batch,0) CAPITAL,
             nvl(o.sal_tot_batch,0) TOT_DEUDA,
             0 RIE_DES_PRV_ANT_GARANTIA,
             0 RIE_GAR_NOCUBIERTO,
             -- DE-2044
             (CASE WHEN o.cod_modulo = 5 THEN NVL((select tr.lin_credito from ta_cta_tarjetas tr where tr.cod_modulo = o.cod_modulo and tr.nro_cuenta = o.nro_cuenta),1) 
                   ELSE (o.sal_tot_batch) END) CAPITAL_INICIAL

             ,p.cod_rub_primario ACT_PRIMARIA,fug_obt_des_actividad(P.COD_RUB_PRIMARIO,'N') DES_ACT_PRIMARIA
             ,e.cod_seg_cliente, null nro_solicitud
             ,null canal_prestamo --RE DE-1358
             -- PIPROINTE-285 Riesgos - Anexo 1 - Reportes de Gestión requeridos por GNB Sudameris Colombia
             ,p.cod_pais, p.cod_tip_documento, e.cat_automatica cat_de_persona
             -- para previsiones de tarjetas y sobregiros
             ,0 tot_cap_prev
             ,0 tot_int_prev
             ,'O' query_10
        from ov_cta_vencidas o, ge_cta_clientes cl, ge_clientes e, ba_personas p,
             ba_tip_documentos d, ba_oficinas n, ba_cod_referencias r1, ge_est_cuentas t,
             ba_cod_referencias r2, ba_usuarios u,  ba_oficinas f, ba_gru_oficinas g
       where o.nro_cuenta=cl.nro_cuenta
         and cl.cod_persona=e.cod_persona
         and cl.relacion = 'P'
         and e.cod_persona=p.cod_persona
         and p.cod_tip_documento=d.cod_tip_documento
         and e.cod_oficina=n.cod_oficina
         and r1.dominio='TIP_CLIENTE'
         and r1.val_minimo=nvl(e.tipo,'T')
         and r2.dominio='TIP_DESTINO'
         and r2.val_minimo=4
         and e.cod_usu_oficial=u.cod_usuario
         and u.cod_oficina=f.cod_oficina
         and f.cod_gru_oficina=g.cod_gru_oficina(+)
         and t.cod_modulo=o.cod_modulo
         and t.cod_modalidad=o.cod_modalidad
         and t.estado=o.estado
         and o.est_batch = 'I'
         and nvl(o.fec_apertura,v_fec_actual) <= v_fec_actual --DYDMR-9946 - Fecha de Operación prev_det
         and not exists (select 1 from ge_cla_operaciones a
                          where o.nro_cuenta = a.nro_cuenta);
      commit;
      --- Cuentas con intereses en negativo y no están en ge_cla_operaciones
      insert into GE_PREVISION_DET_TMP(
             cod_modulo, riesgo, nombre_per, doc, nro_doc, cat_riesgo, cat_crc, ofi, oficina, ofi_usu, 
             cod_usu_oficial, nombre_usu, banca, cat_subjetiva, gru_eco, gru_eco_informado, cat_gru_economico, 
             cat_sistema, tot_deu_rsistema, tot_con_rsistema, tipo, tip_cliente, rubro, cod_modalidad, 
             nro_cuenta, saldo_interes, fecha_inicio_oper, cod_moneda, cod_estado, estado, tot_deu_real, 
             tot_deu_contingente, dev_no_cobrado, tot_gar_computables, tot_prevision, cat_automatica, 
             cat_renovaciones, dia_atraso, sdo_mora, tip_destino, destino, cod_sec_credito, desc_sec_crd, 
             tip_renovacion, mto_mora, sect_prestamo, desc_sect_prestamo, prim_prevision, seg_prevision, 
             cod_sub_modalidad, cod_campana, gru_eco_bcp, sub_cat_individual_no_r4, sub_cat_individual_r4, 
             es_covid, sub_cat_grupo, capital, tot_deuda, rie_des_prv_ant_garantia, rie_gar_nocubierto, 
             capital_inicial, act_primaria, des_act_primaria, cod_seg_cliente, nro_solicitud, canal_prestamo, 
             cod_pais, cod_tip_documento, cat_de_persona, tot_cap_prev, tot_int_prev, query_10)
      select o.cod_modulo, p.cod_persona riesgo, ltrim(rtrim(p.nom_completo)) nombre_per,
             fue_obt_tip_doc_abreviatura(p.cod_tip_documento) doc,
             ltrim(rtrim(p.nro_documento)) nro_doc,
             e.cat_riesgo, fup_obt_categoria(e.cat_automatica,e.cat_subjetiva) cat_crc, e.cod_oficina ofi,
             fue_obt_des_oficina(e.cod_oficina) oficina,
             (select u.cod_oficina
                from ba_usuarios u
               where e.cod_usu_oficial=u.cod_usuario) ofi_usu,
             e.cod_usu_oficial,
             (select u.nombre
                from ba_usuarios u
               where e.cod_usu_oficial=u.cod_usuario) nombre_usu,
             (select g.descripcion
                from ba_usuarios u,  ba_oficinas f, ba_gru_oficinas g
               where e.cod_usu_oficial=u.cod_usuario
                 and u.cod_oficina=f.cod_oficina 
                 and f.cod_gru_oficina=g.cod_gru_oficina(+)) banca,
             e.cat_subjetiva, e.cod_gru_economico gru_eco,
             (CASE WHEN (SELECT COUNT(DISTINCT g1.cod_persona) FROM ge_cla_operaciones g1, ge_clientes g2 WHERE g1.cod_persona = g2.cod_persona AND g2.cod_gru_economico = e.cod_gru_economico) > 1 THEN e.cod_gru_economico END) GRU_ECO_INFORMADO,
             e.cat_gru_economico, e.cat_sistema, e.tot_deu_sistema tot_deu_rsistema, e.tot_deu_con_sistema tot_con_rsistema,
             e.tipo, substr(r1.significado,1,40) tip_cliente, o.rub_con_capital rubro,
             o.cod_modalidad cod_modalidad,
             nvl(substr(o.nro_operacion,1,INSTR(o.nro_operacion,'#')-1),o.nro_operacion) nro_cuenta,
             nvl(o.sal_int_dev_no_cobrado,0) saldo_interes, fug_obt_dat_operaciones(o.nro_operacion,'F') fecha_inicio_oper, 
             (select b.cod_moneda
                from ba_monedas b
               where o.con_mon_iso=b.cod_mon_iso) cod_moneda,
             null cod_estado, null estado,
                            
             (nvl(o.sal_capital,0)+nvl(o.sal_int_dev_no_cobrado,0)) tot_deu_real,
                 
             0 tot_deu_contingente, nvl(o.sal_int_dev_no_cobrado,0) dev_no_cobrado,
             0 tot_gar_computables, 0 tot_prevision,
                 
             to_number(decode(cla_riesgo,'1a','1.1','1b','1.2',cla_riesgo)) cat_automatica,
                 
             null cat_renovaciones, 0 dia_atraso, null sdo_mora,
             null tip_destino, null destino, null cod_sec_credito, null desc_sec_crd,
             'Nuevo' Tip_renovacion,
             0 mto_mora, null sect_prestamo,
             null desc_sect_prestamo,
             0 prim_prevision,
             0 seg_prevision,
             null cod_sub_modalidad,  null cod_campana,
             (SELECT MAX(bc.val_minimo)
                FROM ba_cod_referencias bc
               WHERE bc.dominio = 'GRU_ECO_BCP'
                 AND bc.val_maximo = nvl(e.cod_gru_economico,0)
                 AND bc.fec_modificacion = (SELECT MAX(re.fec_modificacion)
                                              FROM ba_cod_referencias re
                                             WHERE bc.dominio = re.dominio
                                               AND bc.val_maximo = re.val_maximo)) GRU_ECO_BCP,
             (CASE WHEN e.cat_riesgo = 1 THEN NVL((select MAX((CASE WHEN a.cat_automatica >= 2 THEN 1.2 ELSE a.cat_automatica END)) from ge_cla_operaciones a  where a.cod_persona = p.cod_persona
               and nvl(fug_obt_pardinamico('COD_MAD_RESOLUCION04', a.cod_modulo, a.cod_modalidad),'N') = 'N'
              ),1) END) SUB_CAT_INDIVIDUAL_NO_R4,
             (CASE WHEN e.cat_riesgo = 1 THEN NVL((select MAX((CASE WHEN a.cat_automatica >= 2 THEN 1.2 ELSE a.cat_automatica END)) from ge_cla_operaciones a where a.cod_persona = p.cod_persona
               and nvl(fug_obt_pardinamico('COD_MAD_RESOLUCION04', a.cod_modulo, a.cod_modalidad),'N') = 'S'
              ),1) END) SUB_CAT_INDIVIDUAL_R4,
             'N' ES_COVID,
             (CASE WHEN e.cod_gru_economico IS NOT NULL THEN (CASE WHEN e.cat_riesgo = 1 THEN NVL((select MAX((CASE WHEN a.cat_automatica >= 2 THEN 1.2 ELSE a.cat_automatica END)) from ge_cla_operaciones a where a.cod_persona IN (SELECT x.cod_persona FROM ge_clientes x where x.cod_gru_economico = e.cod_gru_economico)),1) END) END) SUB_CAT_GRUPO,
                 
             nvl(o.sal_capital,0) CAPITAL, 
             (nvl(o.sal_capital,0)+nvl(o.sal_int_dev_no_cobrado,0)) TOT_DEUDA, 
                  
             0 RIE_DES_PRV_ANT_GARANTIA, 0 RIE_GAR_NOCUBIERTO, 0 CAPITAL_INICIAL
             ,p.cod_rub_primario ACT_PRIMARIA,fug_obt_des_actividad(P.COD_RUB_PRIMARIO,'N') DES_ACT_PRIMARIA
             ,e.cod_seg_cliente, null nro_solicitud, null canal_prestamo
             ,p.cod_pais, p.cod_tip_documento, e.cat_automatica cat_de_persona
             ,0 tot_cap_prev, 0 tot_int_prev
             ,'V' query_10
        from sb_crc_saldos_det o, ge_cta_clientes d, ba_cod_referencias h,
             ge_clientes e, ba_personas p, ba_cod_referencias r1
       where nvl(substr(o.nro_operacion,1,INSTR(o.nro_operacion,'#')-1),o.nro_operacion) = d.nro_cuenta
         and o.fecha = v_max_fec_saldos
         and d.relacion = 'P'
         and d.cod_persona = e.cod_persona
         and p.cod_persona=e.cod_persona
         and r1.dominio='TIP_CLIENTE'
         and r1.val_minimo=nvl(e.tipo,'T')
         and h.dominio = 'CTA_INT_NEGATIVOS'
         and h.val_minimo = d.nro_cuenta;
      commit;
      
      begin dbms_stats.gather_table_stats('IT','GE_PREVISION_DET_TMP'); end;
            
      if nvl(fug_obt_pardinamico('CUENTAS_EXCLIDAS_CRC'),'N') = 'S' then
         pag_evo.pr_cta_excluidas(v_max_fec_saldos);
         commit;
      end if;
      
      -----------------------------------------------
      --- Parte 2, cargar la tabla de previsiones ---
      -----------------------------------------------
      v_base_prod := fug_obt_pardinamico('BD_PROD');      
      SELECT upper(sys_context('USERENV', 'DB_NAME'))
        INTO v_base_datos
        FROM dual;
      IF v_base_datos = v_base_prod then
         --- Solo si es en produccion se debe restaurar
         sql_util.ejecute_dml('truncate table it.MI_PREVISIONES_RES', v_men_error);
         IF v_men_error IS NOT NULL THEN
            raise_application_error(-20000, v_men_error);
         END IF;
         
         insert into mi_previsiones_res(
                nro_cuenta, fecha, porcentaje, por_calculado, tot_prv_contingencia, monto)
         select e.nro_cuenta, e.fecha, e.porcentaje, e.por_calculado,0,e.monto
           from pr_previsiones e, ge_prevision_det_tmp d
          where e.nro_cuenta = d.nro_cuenta
            and e.fecha = (select max(p.fecha)
                             from pr_previsiones p
                            where p.nro_cuenta = d.nro_cuenta);   
         commit;
         
         insert into mi_previsiones_res(
                nro_cuenta, fecha, porcentaje, por_calculado,tot_prv_contingencia,monto)
         select e.nro_cuenta, e.fecha, e.porcentaje, e.por_calculado,tot_prv_contingencia,e.monto
           from ta_previsiones e, ge_prevision_det_tmp d
          where e.nro_cuenta = d.nro_cuenta
            and e.fecha = (select max(p.fecha)
                             from ta_previsiones p
                            where p.nro_cuenta = d.nro_cuenta);   
         commit;
         
         insert into mi_previsiones_res(
                nro_cuenta, fecha, porcentaje, por_calculado,tot_prv_contingencia,monto)
         select e.nro_cuenta, e.fecha, e.porcentaje, e.por_calculado,tot_prv_contingencia,e.monto
           from cc_previsiones e, ge_prevision_det_tmp d
          where e.nro_cuenta = d.nro_cuenta
            and e.fecha = (select max(p.fecha)
                             from cc_previsiones p
                            where p.nro_cuenta = d.nro_cuenta);   
         commit;
         
         insert into mi_previsiones_res(
                nro_cuenta, fecha, porcentaje, por_calculado,tot_prv_contingencia,monto)
         select e.nro_cuenta, e.fecha, e.porcentaje, e.por_calculado,0,e.monto
           from ov_previsiones e, ge_prevision_det_tmp d
          where e.nro_cuenta = d.nro_cuenta
            and e.fecha = (select max(p.fecha)
                             from ov_previsiones p
                            where p.nro_cuenta = d.nro_cuenta);   
            
         insert into mi_previsiones_res(
                nro_cuenta, fecha, porcentaje, por_calculado,tot_prv_contingencia,monto)
         select e.nro_cuenta, e.fecha, e.porcentaje, e.por_calculado,0,e.monto
           from cx_previsiones e, ge_prevision_det_tmp d
          where e.nro_cuenta = d.nro_cuenta
            and e.fecha = (select max(p.fecha)
                             from cx_previsiones p
                            where p.nro_cuenta = d.nro_cuenta);   
         commit;
      
      END IF;

      --- Actualizar parámetro para la siguiente ejecución
      update ge_par_dinamicos
         set VAL_PARAMETRO = to_char(v_fec_actual,'YYYYMMDD')
       where PARAMETRO =  'FEC_PREV_DET';
      commit;
   end if;
   

exception
   when others then
      raise_application_error(-20000,'Al generar PREV.DET.TMP: '||sqlerrm);
end;
	

-- Previsiones Específicas Detallado
PROCEDURE pr_previ_det(
  p_cod_proceso ge_procesos_det.cod_proceso%type default null,
  p_nro_cuenta  ge_cuentas.nro_cuenta%type default null)
IS

v_fec_actual       DATE := pag_cal.FU_OBT_FEC_ACTUAL(1);
v_sub_cat_individual    ge_cla_operaciones.cat_automatica%type;
v_es_covid              ge_par_dinamicos.val_parametro%type;
v_cod_mon_local         ba_monedas.cod_moneda%type := pag_gen.FU_OBT_MON_LOCAL;
v_max_fec_saldos        date;
v_nro_cuenta            ge_cuentas.nro_cuenta%type := p_nro_cuenta; -- usar solo para debug

  CURSOR cu_prevision_det IS
  --- Cursor Original del PREV_DET
  select cod_modulo, riesgo, nombre_per, doc, nro_doc, cat_riesgo, cat_crc, ofi, oficina, ofi_usu, 
         cod_usu_oficial, nombre_usu, banca, cat_subjetiva, gru_eco, gru_eco_informado, cat_gru_economico, 
         cat_sistema, tot_deu_rsistema, tot_con_rsistema, tipo, tip_cliente, rubro, cod_modalidad, 
         nro_cuenta, saldo_interes, fecha_inicio_oper, cod_moneda, cod_estado, estado, tot_deu_real, 
         tot_deu_contingente, dev_no_cobrado, tot_gar_computables, tot_prevision, cat_automatica, 
         cat_renovaciones, dia_atraso, sdo_mora, tip_destino, destino, cod_sec_credito, desc_sec_crd, 
         tip_renovacion, mto_mora, sect_prestamo, desc_sect_prestamo, prim_prevision, seg_prevision, 
         cod_sub_modalidad, cod_campana, gru_eco_bcp, sub_cat_individual_no_r4, sub_cat_individual_r4, 
         es_covid, sub_cat_grupo, capital, tot_deuda, rie_des_prv_ant_garantia, rie_gar_nocubierto, 
         capital_inicial, act_primaria, des_act_primaria, cod_seg_cliente, nro_solicitud, canal_prestamo, 
         cod_pais, cod_tip_documento, cat_de_persona, tot_cap_prev, tot_int_prev, query_10
    from GE_PREVISION_DET_TMP
   where nro_cuenta = nvl(v_nro_cuenta, nro_cuenta)
   order by riesgo, cod_modulo, cod_modalidad, cod_moneda, nro_cuenta;

  TYPE cur_prev_type IS TABLE of cu_prevision_det%rowtype;
  rec  cur_prev_type;

  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'prevision_det'; -- nombre del archivo
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

  -- Variables dyd-sdsl-2505
  v_sub_afinidad             ta_cta_tarjetas.sub_afinidad%type;
  v_fec_inicio               ta_cta_tarjetas.fec_apertura%type;
  v_campana                  pr_solicitudes.cod_campana%type;
  v_campana_origen           pr_solicitudes.cod_campana%type;
  v_sub_modalidad            ta_cta_tarjetas.sub_afinidad%type;
  v_desc_sub_modalidad       ge_sub_modalidades.descripcion%type;
  v_cta_origen               ta_cta_tarjetas.nro_cuenta%type;
  v_fec_ini_origen           ta_cta_tarjetas.fec_apertura%type;
  v_sub_afinidad_origen      ta_cta_tarjetas.sub_afinidad%type;
  v_desc_sub_afinidad_origen ba_cod_referencias.abreviatura%type;
  v_null                     varchar2(1);
  --
  v_cat_bcp          ge_cla_operaciones.cat_automatica%TYPE := NULL;

  -- RE DE-1172 INFORME PARA RED DE SUCURSALES - MICAHELA ESCOBAR
  v_linetit2          VARCHAR2(2000);
  v_line2             VARCHAR2(32767);
  v_name2             VARCHAR2(128) := 'inf_cartera_total'; -- nombre del archivo
  v_file2             UTL_FILE.FILE_TYPE;
  v_buffer2           VARCHAR2(32767);
  v_usu_liq           ba_usuarios.cod_usuario%type;
  v_canal             pr_solicitudes.cod_canal%type;
  v_des_canal         ge_canales.descripcion%type;
  v_usu_promotor      pr_solicitudes.cod_usu_promotor%type;
  v_des_promotor      ba_usuarios.nombre%type;
  v_concesionaria     pr_solicitudes.cod_ent_concesionaria%type;
  v_des_concesionaria ge_entes.descripcion%type;

  -- RE DE-1358 - VARIABLES
  --v_can_pt             ge_canales.descripcion%type; -- variable que guarda el codigo de canal (prestamo ó tdc)
  v_mes_facturacion    cr_per_dat_segmentacion.mes_facturacion%type;
  v_ano_facturacion    cr_per_dat_segmentacion.ano_facturacion%type;
  v_mto_facturacion    cr_per_dat_segmentacion.mto_facturacion%type;
  v_mes_rating         cr_per_dat_segmentacion.mes_rating%type;
  v_ano_rating         cr_per_dat_segmentacion.ano_rating%type;
  v_rating             cr_per_dat_segmentacion.rating%type;
  v_mes_hatos          cr_per_dat_segmentacion.mes_hatos%type;
  v_ano_hatos          cr_per_dat_segmentacion.ano_hatos%type;
  v_can_hatos          cr_per_dat_segmentacion.can_hatos%type;
  v_tip_hec_cultivadas cr_per_tip_hectareas.tip_hec_cultivadas%type;
  v_nro_hec_cultivadas cr_per_tip_hectareas.nro_hec_cultivadas%type;
  v_mes                cr_per_tip_hectareas.mes%type;
  v_anho               cr_per_tip_hectareas.anho%type;
  v_des_tip_cultivo   ba_cod_referencias.abreviatura%type;
  --RE DE-1622 - VARIABLES
  v_py_autorizador     ba_usuarios.cod_usuario%type;        -- Código Usuario Autorizador
  v_py_nombre          ba_usuarios.nombre%type;             -- Nombre Usuario Autorizador
  v_fec_autorizacion   date;                                -- Fecha Autorizacion
  v_nro_linea          pr_cta_prestamos.nro_linea%type;     -- Nro Linea
  v_nro_sol_linea      ta_solicitudes.nro_solicitud%type;   -- Nro Solicitud
  v_est_cuenta         ge_est_cuentas.estado%type;          -- estado de cuenta
  v_cta_inicial        pr_cta_prestamos.nro_cuenta%type;    -- Nro de cuenta prestamo ó tarjeta
  v_fec_ini_pt         date;                                -- Fecha inicio del prestamo ó tarjeta
  v_fec_vencimiento    date;                                -- Fecha vencimiento del prestamo
  v_fec_ini_linea      date;                                -- Fecha inicio de la linea
  v_tiene_sobregiro    VARCHAR2(1);                         -- Indicador si la cuenta tiene habilitado sobregiro
  v_cta_ori_cta_cte    ov_cta_vencidas.nro_cta_origen%type; -- Variable para almacenar la cta origen de operaciones vencidas
  v_fec_pos_linea      VARCHAR2(1);                         -- Variable para verificar las fechas entre fecha de aprobacion del prestamo y fecha de aprobacion de linea. Valores posible 'S','N'
  -- DE-2594 PyR NAF MAY/2017
  v_cod_usu_apr_cuenta ba_usuarios.cod_usuario%type;
  v_nom_usu_apr_cuenta ba_usuarios.nombre%type;
  v_fec_apr_cuenta     pr_solicitudes.fec_aprobacion%type;
  v_men_error          varchar2(500);
  -- COREADRRR-1
  v_tip_rrr_holding    varchar2(1);
  v_ref_rrr_holding    ba_cod_referencias.abreviatura%type;
  -- PIPROINTE-285 Riesgos - Anexo 1 - Reportes de Gestión requeridos por GNB Sudameris Colombia (Query 9)
  g_query_10            VARCHAR2(100) := 'ramail\ReportesRegulatorios\'; /*QUERY 10*/

  v_linetit3           VARCHAR2(2000);
  v_line3              VARCHAR2(32767);
  v_name3              VARCHAR2(128) := 'Query_10'; -- nombre del archivo
  v_file3              UTL_FILE.FILE_TYPE;
  v_buffer3            VARCHAR2(32767);
  
  --v_linetit4           VARCHAR2(2000);
  --v_line4              VARCHAR2(32767);
  --v_name4              VARCHAR2(128) := 'Query_9'; -- nombre del archivo
  --v_file4              UTL_FILE.FILE_TYPE;
  --v_buffer4            VARCHAR2(32767);
  
  v_nro_secuencia      number := 0;
  v_fec_archivo        varchar2(8);
  v_pais_bt            mi_query_10.Pais%type;
  v_tipo_doc_bt        mi_query_10.tipo_doc%type;
  v_relacion           mi_query_10.vinculo%type;
  v_fec_cat_sub        date;
  v_cod_rubro          cb_rubros.cod_rubro%type;
  v_tae                mi_query_10.tae%type;
  v_tan                mi_query_10.tan%type;
  v_rub_bcp            cb_rubros.cod_rubro%type;
  v_tip_operacion      varchar2(3);
  v_titulo             varchar2(3);
  v_capitulo           varchar2(3);
  v_grupo              varchar2(3);
  v_subgrupo           varchar2(3);
  v_moneda_bt          mi_query_10.moneda%type;
  v_mto_desembolsado   pr_solicitudes.tot_desembolsar%type;
  v_fec_vto            pr_cta_prestamos.fec_vencimiento%type;
  v_cotizacion         ge_cotizaciones.val_conversion%type;
  v_sal_capital_mo     pr_cta_prestamos.sal_capital%type;
  v_sal_capital_ml     pr_cta_prestamos.sal_capital%type;
  v_sal_exceso_mo      pr_cta_prestamos.sal_capital%type;
  v_sal_exceso_ml      pr_cta_prestamos.sal_capital%type;
  v_sal_interes_mo     pr_cta_prestamos.sal_interes%type;
  v_sal_interes_ml     pr_cta_prestamos.sal_interes%type;
  v_int_suspenso_mo    pr_cta_prestamos.dev_suspenso%type;
  v_int_suspenso_ml    pr_cta_prestamos.dev_suspenso%type;

  v_tot_deu_cont_mo    ge_dat_pre_det_tmp.tot_deu_contingente%type;
  v_tot_gar_comp_mo    ge_dat_pre_det_tmp.tot_gar_computables%type;
  v_por_prevision      number;--pr_previsiones.porcentaje%type;
  v_por_prev_calc      number;--pr_previsiones.porcentaje%type;
  
  v_prev_cap_mo        pr_previsiones.tot_cap_pri_prevision%type;
  v_prev_cap_ml        pr_previsiones.tot_cap_pri_prevision%type;
  v_prev_int_mo        pr_previsiones.tot_int_pri_prevision%type;
  v_prev_int_ml        pr_previsiones.tot_int_pri_prevision%type;
  v_prev_cont_mo       ta_previsiones.tot_prv_contingencia%type;
  v_prev_cont_ml       ta_previsiones.tot_prv_contingencia%type;
  v_tot_prev_mo        cc_previsiones.monto%type;
  
  v_prim_prevision_mo  ge_dat_pre_det_tmp.prim_prevision%type;
  v_seg_prevision_mo   ge_dat_pre_det_tmp.seg_prevision%type;
  v_estado_bt          varchar2(240);
  
  v_mto_cta_mora_mo    pr_cuotas.mto_capital%type;
  v_mto_cta_mora_ml    pr_cuotas.mto_capital%type;
  
  v_can_cuo_canceladas number;
  v_fec_pri_vto        date;
  v_fec_vto_antiguo    date;
  v_sal_deu_activo_mo  pr_cta_prestamos.sal_capital%type;
  v_sal_deu_activo_ml  pr_cta_prestamos.sal_capital%type;
  v_can_registros      number;
  v_fec_cat_char       varchar2(240);
  v_fec_vto_char       varchar2(240);
  v_fec_ini_char       varchar2(240);
  v_gar_bca_mo         number;
  v_gar_bca_ml         number;
  v_gar_no_bca_mo      number;
  v_gar_no_bca_ml      number;
  v_des_modalidad      ge_modalidades.descripcion%type;
  v_ges_judicial       varchar2(60);
  v_tip_deudor         mi_query_10.tipo_deudor%type;
  v_cat_resultante     mi_query_10.cat_resultante%type;
  v_categoria          number(3,2);
  v_cat_subjetiva      mi_query_10.cat_subjetiva%type;
  v_tip_prestamo       pr_cta_prestamos.tipo%type;
  v_segmento           mi_query_10.segmento%type;
  v_seg_interno        mi_query_10.clasif_interna%type;
  v_des_cat_crc        varchar2(60);
  v_des_cat_ind        varchar2(60);
  v_des_cat_ren        varchar2(60);

  v_prev_gen_mo        mi_query_10.prevision_generica_mo%type;
  v_prev_gen_ml        mi_query_10.prevision_generica_ml%type;
  v_modulo             mi_query_10.modulo%type;
  v_es_r4              mi_query_10.es_r4%type;
  rp_mquery            mi_query_10%rowtype;
  
  v_mto_cont_mo        cc_sobregiros.mto_linea%type;
  v_mto_cont_ml        cc_sobregiros.mto_linea%type;
  v_sal_cap_cont       varchar2(1) := 'N';
  
  v_sal_cap_ant_ml     pr_cta_prestamos.sal_capital%type;
  v_sal_cap_ant_mo     pr_cta_prestamos.sal_capital%type;
  v_tot_deuda_mo       ge_cla_operaciones.tot_deu_real%type;
  v_tot_deuda_ml       ge_cla_operaciones.tot_deu_real%type;
  v_cod_ente           ge_entes.cod_ente%type;
  v_tot_riesgo         ge_cla_operaciones.tot_deu_real%type;
  v_cod_ori_fondo      pr_cta_prestamos.cod_ori_fondo%type;
  v_por_ori_fondo      pr_cta_prestamos.por_ori_fondo%type;
  v_ori_fondo_afd      varchar2(1) := 'N';
  v_cod_rub_economico  pr_rub_economicos.cod_rub_economico%type;
  --- Para enviar correo solo si BD es Produccion
  v_bas_prod    ge_par_dinamicos.val_parametro%type;
  vg_bas_datos  varchar2(50);
  v_env_mail    boolean := false;
  --- validacion del cierre
  v_ult_dia_mes_habil ge_calendarios.ult_dia_mes_habil%type;
  ---
  v_act_bco_central pr_rub_economicos.cod_bco_central%type;
  ---
   function lf_obt_rubro_inv (p_nro_cuenta ge_cuentas.nro_cuenta%type)
      return varchar2 is
      v_rub_crc cb_rubros.cod_rubro%type;
   begin
      select max(b.cod_rubro)
        into v_rub_crc
        from cb_sal_inventarios_det a, cb_sal_inventarios b
       where a.nro_cuenta = p_nro_cuenta
         and b.nro_referencia = a.nro_referencia
         and b.tip_saldo = 'C'
         and substr(b.cod_rubro,1,1) = '1';
      return v_rub_crc;
   exception
      when others then
         return null;
   end;
   
   function lf_obt_rub_contable (p_nro_cuenta IN VARCHAR2,
                                 p_tip_saldo  IN VARCHAR2,
                                 p_sit_deuda  IN VARCHAR2 DEFAULT NULL)
   RETURN VARCHAR2 IS
      v_rub_contable cb_rubros.cod_rubro%TYPE;
   BEGIN
      SELECT a.cod_rubro
        INTO v_rub_contable
        FROM cb_sal_inventarios a, cb_sal_inventarios_det d
       WHERE a.nro_referencia = d.nro_referencia
         AND d.nro_cuenta = p_nro_cuenta
         AND a.tip_saldo = p_tip_saldo
         AND d.sal_actual > 0
         AND (p_sit_deuda IS NULL OR a.situacion = p_sit_deuda);
      RETURN v_rub_contable;
   EXCEPTION
      WHEN OTHERS THEN
         return null;
   END;   
   
   procedure lp_ins_query_10 (rg_mquery mi_query_10%rowtype) is
   begin
      Begin
          insert into mi_query_10 values(
                 rg_mquery.empresa, rg_mquery.fecha_informe, rg_mquery.secuencia, rg_mquery.pais, rg_mquery.tipo_doc, 
                 rg_mquery.nro_documento, rg_mquery.nombre_deudor, rg_mquery.tipo_deudor, rg_mquery.vinculo, rg_mquery.grupo_econ, 
                 rg_mquery.actividad, rg_mquery.sucursal, rg_mquery.cuenta, rg_mquery.cat_resultante, rg_mquery.cat_subjetiva,
                 rg_mquery.fecha_desde_cat_sub, rg_mquery.titulo, rg_mquery.capitulo, rg_mquery.rubro, rg_mquery.modulo,
                 rg_mquery.moneda, rg_mquery.operacion, rg_mquery.sub_operacion, rg_mquery.tipo_operacion, rg_mquery.papel,
                 rg_mquery.fecha_de_alta, rg_mquery.fecha_de_vto, rg_mquery.dias_mora, rg_mquery.monto_desembolsado, rg_mquery.saldo_capital_mo, 
                 rg_mquery.saldo_capital_ml, rg_mquery.interes_mo, rg_mquery.interes_ml, rg_mquery.interes_suspendido_mo, rg_mquery.interes_suspendido_ml, 
                 rg_mquery.saldo_contingente_mo, rg_mquery.saldo_contingente_ml, rg_mquery.garantia_computable_mo, rg_mquery.garantia_computable_ml, rg_mquery.porcentaje_prevision, 
                 rg_mquery.prevision_s_capital_mo, rg_mquery.prevision_s_capital_ml, rg_mquery.prevision_s_interes_mo, rg_mquery.prevision_s_interes_ml, rg_mquery.prevision_s_contingente_mo, 
                 rg_mquery.prevision_s_contingente_ml, rg_mquery.primera_prevision_mo, rg_mquery.primera_prevision_ml, rg_mquery.segunda_prevision_mo, rg_mquery.segunda_prevision_ml, 
                 rg_mquery.prevision_generica_mo, rg_mquery.prevision_generica_ml, rg_mquery.estado, rg_mquery.ejecutivo, rg_mquery.nombre_ejecutivo, 
                 rg_mquery.segmento, rg_mquery.clasif_interna, rg_mquery.tipo_prestamo, rg_mquery.tae, rg_mquery.tan, 
                 rg_mquery.monto_operacion_mo, rg_mquery.monto_operacion_ml, rg_mquery.monto_cuota_atrasada_mo, rg_mquery.monto_cuota_atrasada_ml, rg_mquery.cuotas_canceladas, 
                 rg_mquery.fecha_1er_vto, rg_mquery.fecha_vto_mas_antiguo, rg_mquery.saldo_deuda_en_activo_mo, rg_mquery.saldo_deuda_en_activo_ml, rg_mquery.total_de_riesgo, 
                 rg_mquery.recuperaciones, rg_mquery.categoria_de_persona, rg_mquery.categoria_de_operacion, rg_mquery.garantia_bancaria_mo, rg_mquery.garantia_bancaria_ml, 
                 rg_mquery.garantia_no_bancaria_mo, rg_mquery.garantia_no_bancaria_ml, rg_mquery.categoria_rrr, rg_mquery.es_r4, rg_mquery.tipo_doc_crc, rg_mquery.nro_doc_crc
                 );
          commit;
      exception
          when others then
            raise_application_error(-20000,'pr_previ_det - Error al insertar en mi_query_10: '||sqlerrm);
      end;
      
      v_line3 := 
      rg_mquery.empresa ||CHR(124)|| to_char(rg_mquery.fecha_informe,'yyyymmdd') ||CHR(124)|| to_char(rg_mquery.secuencia) ||CHR(124)|| rg_mquery.pais ||CHR(124)|| rg_mquery.tipo_doc ||CHR(124)||
      rg_mquery.nro_documento ||CHR(124)|| rg_mquery.nombre_deudor ||CHR(124)|| rg_mquery.tipo_deudor ||CHR(124)|| rg_mquery.vinculo ||CHR(124)|| rg_mquery.grupo_econ ||CHR(124)|| 
      rg_mquery.actividad ||CHR(124)|| rg_mquery.sucursal ||CHR(124)|| rg_mquery.cuenta ||CHR(124)|| rg_mquery.cat_resultante ||CHR(124)|| rg_mquery.cat_subjetiva ||CHR(124)||
      v_fec_cat_char ||CHR(124)|| rg_mquery.titulo ||CHR(124)|| rg_mquery.capitulo ||CHR(124)|| rg_mquery.rubro ||CHR(124)|| rg_mquery.modulo ||CHR(124)||
      rg_mquery.moneda ||CHR(124)|| rg_mquery.operacion ||CHR(124)|| rg_mquery.sub_operacion ||CHR(124)|| rg_mquery.tipo_operacion ||CHR(124)|| rg_mquery.papel ||CHR(124)||
      v_fec_ini_char ||CHR(124)|| v_fec_vto_char ||CHR(124)|| to_char(rg_mquery.dias_mora) ||CHR(124)|| to_char(rg_mquery.monto_desembolsado, '999999999999999999D00') ||CHR(124)|| to_char(rg_mquery.saldo_capital_mo, '999999999999999999D00') ||CHR(124)|| 
      to_char(rg_mquery.saldo_capital_ml, '999999999999999999D00') ||CHR(124)|| to_char(rg_mquery.interes_mo, '999999999999999999D00') ||CHR(124)|| to_char(rg_mquery.interes_ml, '999999999999999999D00') ||CHR(124)|| to_char(rg_mquery.interes_suspendido_mo, '999999999999999999D00') ||CHR(124)|| to_char(rg_mquery.interes_suspendido_ml, '999999999999999999D00') ||CHR(124)|| 
      to_char(rg_mquery.saldo_contingente_mo, '999999999999999999D00') ||CHR(124)|| to_char(rg_mquery.saldo_contingente_ml,'999999999999999999D00') ||CHR(124)|| to_char(rg_mquery.garantia_computable_mo, '999999999999999999D00') ||CHR(124)|| to_char(rg_mquery.garantia_computable_ml,'999999999999999999D00') ||CHR(124)|| to_char(rg_mquery.porcentaje_prevision) ||CHR(124)|| 
      to_char(rg_mquery.prevision_s_capital_mo, '999999999999999999D00')||CHR(124)|| to_char(rg_mquery.prevision_s_capital_ml, '999999999999999999D00') ||CHR(124)|| to_char(rg_mquery.prevision_s_interes_mo, '999999999999999999D00')||CHR(124)|| to_char(rg_mquery.prevision_s_interes_ml, '999999999999999999D00') ||CHR(124)|| to_char(rg_mquery.prevision_s_contingente_mo,'999999999999999999D00') ||CHR(124)|| 
      to_char(rg_mquery.prevision_s_contingente_ml, '999999999999999999D00') ||CHR(124)|| to_char(rg_mquery.primera_prevision_mo, '999999999999999999D00') ||CHR(124)|| to_char(rg_mquery.primera_prevision_ml, '999999999999999999D00') ||CHR(124)|| to_char(rg_mquery.segunda_prevision_mo, '999999999999999999D00') ||CHR(124)|| to_char(rg_mquery.segunda_prevision_ml, '999999999999999999D00') ||CHR(124)|| 
      to_char(rg_mquery.prevision_generica_mo, '999999999999999999D00') ||CHR(124)|| to_char(rg_mquery.prevision_generica_ml, '999999999999999999D00') ||CHR(124)|| rg_mquery.estado ||CHR(124)|| rg_mquery.ejecutivo ||CHR(124)|| rg_mquery.nombre_ejecutivo ||CHR(124)|| 
      rg_mquery.segmento ||CHR(124)|| rg_mquery.clasif_interna ||CHR(124)|| rg_mquery.tipo_prestamo ||CHR(124)|| to_char(rg_mquery.tae, '999D0000') ||CHR(124)|| to_char(rg_mquery.tan, '999D0000') ||CHR(124)|| 
      to_char(rg_mquery.monto_operacion_mo, '999999999999999999D00') ||CHR(124)|| to_char(rg_mquery.monto_operacion_ml, '999999999999999999D00') ||CHR(124)|| to_char(rg_mquery.monto_cuota_atrasada_mo, '999999999999999999D00') ||CHR(124)|| to_char(rg_mquery.monto_cuota_atrasada_ml, '999999999999999999D00') ||CHR(124)|| to_char(rg_mquery.cuotas_canceladas) ||CHR(124)|| 
      nvl(to_char(rg_mquery.fecha_1er_vto, 'yyyymmdd'),' ') ||CHR(124)|| nvl(to_char(rg_mquery.fecha_vto_mas_antiguo, 'yyyymmdd'), ' ') ||CHR(124)|| to_char(rg_mquery.saldo_deuda_en_activo_mo, '999999999999999999D00') ||CHR(124)|| to_char(rg_mquery.saldo_deuda_en_activo_ml, '999999999999999999D00') ||CHR(124)|| to_char(rg_mquery.total_de_riesgo, '999999999999999999D00') ||CHR(124)|| 
      rg_mquery.recuperaciones ||CHR(124)|| rg_mquery.categoria_de_persona ||CHR(124)|| rg_mquery.categoria_rrr ||CHR(124)|| to_char(rg_mquery.garantia_bancaria_mo, '999999999999999999D00') ||CHR(124)|| to_char(rg_mquery.garantia_bancaria_ml, '999999999999999999D00') ||CHR(124)|| 
      to_char(rg_mquery.garantia_no_bancaria_mo, '999999999999999999D00') ||CHR(124)|| to_char(rg_mquery.garantia_no_bancaria_ml, '999999999999999999D00') ||CHR(124)|| rg_mquery.categoria_de_operacion ||CHR(124)|| rg_mquery.es_r4 ||CHR(124)|| rg_mquery.tipo_doc_crc ||CHR(124)|| rg_mquery.nro_doc_crc;
   
      IF LENGTH(v_buffer3) + v_eollen + LENGTH(v_line3) <= v_maxline THEN
        v_buffer3 := v_buffer3 || v_eol || v_line3;
      ELSE
        IF v_buffer3 IS NOT NULL THEN
          --Escribes la linea en el fichero
          UTL_FILE.PUT_LINE(v_file3, v_buffer3);
        END IF;
        v_buffer3 := v_line3;
      END IF;

   end;
      
   /* Obtener la categor?a de previsi?n de clientes para categor?a 1(Uno)*/
   FUNCTION lf_obt_cat_prevision(p_cod_persona IN ge_cla_operaciones.cod_persona%TYPE) RETURN NUMBER AS
      v_cat_riesgo ge_cla_operaciones.cat_automatica%TYPE;
   BEGIN
      --Verifico las operaciones que posee el cliente.
      SELECT nvl(MAX(nvl(a.cat_automatica,1)), 1)
        INTO v_cat_riesgo
        FROM ge_cla_operaciones a
       WHERE a.cod_persona = p_cod_persona
         /*AND nvl(a.cat_automatica,1) < 2*/;
      RETURN v_cat_riesgo;
   EXCEPTION
      WHEN OTHERS THEN
         v_cat_riesgo := 1;
         RETURN v_cat_riesgo;
   END;
   /* Obtener la categor?a de previsi?n de clientes para categor?a 1(Uno)*/
   FUNCTION lf_obt_cta_excluida(p_nro_cuenta ge_cuentas.nro_cuenta%type)
      RETURN varchar2 AS
      v_existe varchar2(1) := 'N';
   BEGIN
      --Verifico las operaciones que posee el cliente.
      SELECT decode(count(*),0,'N','S')
        INTO v_existe
        FROM sb_cta_excluir a
       WHERE a.nro_operacion = p_nro_cuenta;
      RETURN v_existe;
   EXCEPTION
      WHEN OTHERS THEN
         RETURN 'N';
   END;
  ---
 FUNCTION fl_obt_cta_inicial (p_nro_cta VARCHAR2) RETURN VARCHAR2 IS
   CURSOR cur_cuentas IS
     SELECT a.nro_cuenta, LEVEL nivel
       FROM pr_cta_prestamos a
     START WITH a.nro_cuenta = p_nro_cta -- cta vigente
     CONNECT BY PRIOR a.nro_cuenta = a.nro_cta_renovada
     ORDER BY nivel ASC;
   v_nivel NUMBER(2);
   v_cta_ini pr_cta_prestamos.nro_cuenta%TYPE;
  BEGIN
    v_nivel := 0;
    FOR reg_cta IN cur_cuentas LOOP
     IF reg_cta.nivel >= v_nivel THEN
        v_cta_ini := reg_cta.nro_cuenta;
        v_nivel := reg_cta.nivel;
     END IF;
    END LOOP;
    RETURN v_cta_ini;
  EXCEPTION
     WHEN OTHERS THEN
      v_cta_ini := p_nro_cta;
      v_nivel := NULL;
      RETURN v_cta_ini;
  END;
BEGIN
  -- DE-2594 PyR NAF MAY/2017 - Se almacena el informe en la tabla temporal GE_DAT_PRE_DET_TMP
  -- Se trunca la tabla temporal
  if v_nro_cuenta is null then
     sql_util.ejecute_dml('truncate table GE_DAT_PRE_DET_TMP', v_men_error);
  end if;
  IF v_men_error IS NOT NULL THEN
     raise_application_error(-20000, v_men_error);
  END IF;
  pre_cam_for_numerico('.,'); -- dydmr-5893

  --PIPROINTE-285 Riesgos - Anexo 1 - Reportes de Gestión requeridos por GNB Sudameris Colombia (Query 9)
  select max(d.fecha)
    into v_max_fec_saldos
    from sb_crc_saldos_det d
   where last_day(d.fecha) = d.fecha;
  
  v_bas_prod := fug_obt_pardinamico('BD_PROD');
  SELECT upper(sys_context('USERENV', 'DB_NAME'))
    INTO vg_bas_datos
    FROM dual;
  IF vg_bas_datos = V_BAS_PROD then
     begin
        select a.ult_dia_mes_habil
          into v_ult_dia_mes_habil
          from ge_calendarios a
         where a.cod_modulo = 1;
     exception
        when others then
           raise_application_error(-20000,'Al Obt.ULT_DIA_MES_HABIL '||sqlerrm);
     end;
     --- si es producción y la ultima fecha habil del mes, retornar8
     if v_fec_actual = v_ult_dia_mes_habil then
        return;
     else
        v_env_mail := true;
     end if;
  END IF;
  
  if nvl(p_cod_proceso,0) > 0 and vg_bas_datos = V_BAS_PROD then
     --- proceso independiente
     --- debe tomar la fecha anterior
     v_fec_sist := pag_cal.FU_OBT_FEC_ANT_HAB(v_fec_actual,fun_obt_ofi_matriz);
  else
     --- Obtenemos la fecha del sistema
     select pag_cal.FU_OBT_FEC_ACTUAL(1)
     into v_fec_sist
     from dual;
  end if;
  
  if v_nro_cuenta is null then
     select count(*)
       into v_can_registros
       from mi_query_10
      where fecha_informe = v_fec_sist;
     if nvl(v_can_registros,0) > 0 then
        if nvl(p_cod_proceso,0) > 0 then
           --- proceso independiente
           --- retornar porque ya se procesó en en cierre
           return;
        else
           --- cierre diario
           --- es un reproceso
           delete mi_query_10
            where fecha_informe = v_fec_sist;
        end if;
     end if;
  end if;
  
  v_fecha := to_char(v_fec_sist,'DDMMYYYY');
  v_fec_archivo := to_char(v_fec_sist,'YYYYMMDD');

-- Abrir archivo
v_file := UTL_FILE.FOPEN(pag_evo.g_repository,v_name||'.txt','W',32767);
v_file2 := UTL_FILE.FOPEN(pag_evo.g_repository,v_name2||'.txt','W',32767); -- RE DE-1172
v_file3 := UTL_FILE.FOPEN(pag_evo.g_repository,v_name3||'.csv','W',32767);
--v_file4 := UTL_FILE.FOPEN(pag_evo.g_repository,v_name3||'.txt','W',32767);

-- Colocar el titulo a los campos
-- ARCHIVO PREVISION_DET
v_linetit := 'RIESGO'||CHR(9)||'NOMBRE_PER'||CHR(9)||'DOC'||CHR(9)||'NRO_DOC'||CHR(9)||'CAT_RIESGO'||CHR(9)||'CAT_CRC'||CHR(9)||
             'OFI'||CHR(9)||'OFICINA'||CHR(9)||'OFI_USU' ||CHR(9)||'COD_USU_OFICIAL'||CHR(9)||'NOMBRE_USU'||CHR(9)||'BANCA'||CHR(9)||'CAT_SUBJETIVA'||CHR(9)||
             'GRU_ECO'||CHR(9)||'GRU_ECO_INFORMADO'||CHR(9)||'GRU_ECO_BCP'||CHR(9)||'CAT_GRU_ECONOMICO'||CHR(9)||'SUB_CAT_INDIVIDUAL'||CHR(9)||'SUB_CAT_GRUPO'||CHR(9)||'CAT_BCP'||CHR(9)||
             'GRU_ECO_BCP_1'||CHR(9)||'GRU_ECO_BCP_2'||CHR(9)||'GRU_ECO_BCP_3'||CHR(9)||
             'GRU_ECO_BCP_4'||CHR(9)||'GRU_ECO_BCP_5'||CHR(9)||'GRUPO_ECO_BCP'||CHR(9)||--CNF-GRU_ECO_BCP
             'CAT_SISTEMA'||CHR(9)||'TOT_DEU_RSISTEMA'||CHR(9)||'TOT_CON_RSISTEMA'||CHR(9)||
             'TIPO'||CHR(9)||'TIP_CLIENTE'||CHR(9)||'RUBRO'||CHR(9)||'COD_MODALIDAD'||CHR(9)||'NRO_CUENTA'||CHR(9)||'SUB_MODALIDAD'||CHR(9)||'DESC_SUB_MODALIDAD'||CHR(9)||'CAMPANHA'||CHR(9)||'FEC_TARJETA'||CHR(9)||'SALDO_INTERES'||CHR(9)||'FECHA_INICIO_OPER'||CHR(9)||'COD_MONEDA'||CHR(9)||
             'COD_ESTADO'||CHR(9)||'ESTADO'||CHR(9)||'TOT_DEU_REAL'||CHR(9)||'TOT_DEU_CONTINGENTE'||CHR(9)||'DEV_NO_COBRADO'||CHR(9)||
             'CAPITAL'||CHR(9)||'TOT_DEUDA'||CHR(9)||'RIE_DES_PRV_ANT_GARANTIA'||CHR(9)||'RIE_GAR_NOCUBIERTO'||CHR(9)||
             'TOT_GAR_COMPUTABLES'||CHR(9)||'TOT_PREVISION'||CHR(9)||'CAT_AUTOMATICA'||CHR(9)||'CAT_RENOVACIONES'||CHR(9)||'DIA_ATRASO'||CHR(9)||'SDO_MORA'||CHR(9)||
             'TIP_DESTINO'||CHR(9)||'DESTINO'||CHR(9)||'COD_SEC_CREDITO'||CHR(9)||'DESC_SEC_CRD'||CHR(9)||'TIP_RENOVACION'||CHR(9)||'MTO_MORA'||CHR(9)||
             'SECT_PRESTAMO'||CHR(9)||'DESC_SECT_PRESTAMO'||CHR(9)||'PRIM_PREVISION'||CHR(9)||'SEG_PREVISION'||CHR(9)||
             'CTA_ORIGEN'||CHR(9)||'FEC_INI_ORIGEN'||CHR(9)||'CAMPANA_ORIGEN'||CHR(9)||'SUB_AFINIDAD_ORIGEN'||CHR(9)||'DESC_SUB_AFINIDAD_ORIGEN'||CHR(9)||
             'CAPITAL_INICIAL'||CHR(9)||'ACT_PRIMARIA'||CHR(9)||'DES_ACT_PRIMARIA'||CHR(9)||
             /* RE DE-1358 */
             'CANAL_PRODUCTO'||CHR(9)||'DES_CANAL_PRODUCTO'||CHR(9)||'MES_FACTURACION'||CHR(9)||'ANO_FACTURACION'||CHR(9)||'MTO_FACTURACION'||CHR(9)||
             'MES_RATING'||CHR(9)||'ANO_RATING'||CHR(9)||'RATING'||CHR(9)||
             'MES_HATOS'||CHR(9)||'ANHO_HATOS'||CHR(9)||'CANT_HATOS'||CHR(9)||
             'TIP_HEC_CULTIVADAS'||CHR(9)||'NRO_HEC_CULTIVADAS'||CHR(9)||'MES'||CHR(9)||'ANHO'||CHR(9)||
             /* RE DE-1622*/
             'PY_AUTORIZADOR'||CHR(9)||'PY_NOMBRE'||CHR(9)||'FEC_AUTORIZACION'||CHR(9)||'NRO_LÍNEA'||CHR(9)||
             'COD_PROMOTOR'||CHR(9)||'NOM_PROMOTOR'||CHR(9)|| -- DE-2044
             'PY_AUTORIZADOR_CTA_VIGENTE'||CHR(9)||'PY_NOMBRE_CTA_VIGENTE'||CHR(9)||'FECHA_AUTORIZA_CTA_VIGENTE'||CHR(9)|| -- DE-2594 PyR MAY/2017 NAF
             'REFI_HOLDING'; -- COREADRRR-1           
utl_file.put_line(v_file,v_linetit);

-- RE DE-1172 *********************************************************
-- ARCHIVO INF_CARTERA_TOTAL
v_linetit2 := 'RIESGO'              ||CHR(9)|| 'NOMBRE_PER'        ||CHR(9)|| 'DOC'                ||CHR(9)|| 'NRO_DOC'            ||CHR(9)|| 'CAT_RIESGO'          ||CHR(9)||
              'CAT_CRC'             ||CHR(9)|| 'OFI'               ||CHR(9)|| 'OFICINA'            ||CHR(9)|| 'OFI_USU'            ||CHR(9)|| 'NOMBRE_USU'          ||CHR(9)||
              'BANCA'               ||CHR(9)|| 'CAT_SUBJETIVA'     ||CHR(9)|| 'GRU_ECO'            ||CHR(9)|| 'CAT_SISTEMA'        ||CHR(9)|| 'TOT_DEU_RSISTEMA'    ||CHR(9)||
              'TOT_CON_RSISTEMA'    ||CHR(9)|| 'TIP_CLIENTE'       ||CHR(9)|| 'AREA_DE_NEGOCIO'    ||chr(9)|| 'RUBRO'              ||CHR(9)|| 'COD_MODALIDAD'       ||CHR(9)||
              'NRO_CUENTA'          ||CHR(9)|| 'SUB_MODALIDAD'     ||CHR(9)|| 'DESC_SUB_MODALIDAD' ||CHR(9)|| 'PRODUCTO'           ||CHR(9)|| 'CANAL'               ||CHR(9)||
              'PROMOTOR'            ||CHR(9)|| 'NOMBRE_PROMOTOR'   ||CHR(9)|| 'CONCESIONARIA'      ||CHR(9)|| 'CAMPANHA'           ||CHR(9)|| 'FEC_TARJETA'         ||CHR(9)||
              'SALDO_INTERES'       ||CHR(9)|| 'FECHA_INICIO_OPER' ||CHR(9)|| 'COD_MONEDA'         ||CHR(9)|| 'ESTADO'             ||CHR(9)|| 'TOT_DEU_REAL'        ||CHR(9)||
              'TOT_DEU_CONTINGENTE' ||CHR(9)|| 'DEV_NO_COBRADO'    ||CHR(9)|| 'CAPITAL'            ||CHR(9)|| 'TOT_DEUDA'          ||CHR(9)|| 'TOT_PREVISION'       ||CHR(9)||
              'CAT_RENOVACIONES'    ||CHR(9)|| 'DIA_ATRASO'        ||CHR(9)|| 'SDO_MORA'           ||CHR(9)|| 'DESTINO'            ||CHR(9)|| 'COD_SEC_CREDITO'     ||CHR(9)||
              'DESC_SEC_CRD'        ||CHR(9)|| 'TIP_RENOVACION'    ||CHR(9)|| 'MTO_MORA'           ||CHR(9)|| 'SECT_PRESTAMO'      ||CHR(9)|| 'DESC_SECT_PRESTAMO'  ||CHR(9)||
              'USUARIO_LIQ.'        ||CHR(9)|| 'NOMBRE_USU_LIQ.';
utl_file.put_line(v_file2,v_linetit2);
--**********************************************************************
--PIPROINTE-285 Riesgos - Anexo 1 - Reportes de Gestión requeridos por GNB Sudameris Colombia (Query 9)
v_linetit3 := 'EMPRESA'                    ||CHR(124)|| 'FECHA_INFORME'              ||CHR(124)|| 'SECUENCIA'                ||CHR(124)|| 'PAIS'                     ||CHR(124)|| 'TIPO_DOC'                   ||CHR(124)||
              'NRO_DOCUMENTO'              ||CHR(124)|| 'NOMBRE_DEUDOR'              ||CHR(124)|| 'TIPO_DEUDOR'              ||CHR(124)|| 'VINCULO'                  ||CHR(124)|| 'GRUPO_ECON'                 ||CHR(124)||
              'ACTIVIDAD'                  ||CHR(124)|| 'SUCURSAL'                   ||CHR(124)|| 'CUENTA'                   ||CHR(124)|| 'CAT_RESULTANTE'           ||CHR(124)|| 'CAT_SUBJETIVA'              ||CHR(124)||
              'FECHA_DESDE_CAT_SUB'        ||CHR(124)|| 'TITULO'                     ||CHR(124)|| 'CAPITULO'                 ||CHR(124)|| 'RUBRO'                    ||CHR(124)|| 'MODULO'                     ||CHR(124)||
              'MONEDA'                     ||CHR(124)|| 'OPERACION'                  ||CHR(124)|| 'SUB_OPERACION'            ||CHR(124)|| 'TIPO_OPERACION'           ||CHR(124)|| 'PAPEL'                      ||CHR(124)||
              'FECHA_DE_ALTA'              ||CHR(124)|| 'FECHA_DE_VTO'               ||CHR(124)|| 'DIAS_MORA'                ||CHR(124)|| 'MONTO_DESEMBOLSADO'       ||CHR(124)|| 'SALDO_CAPITAL_MO'           ||CHR(124)||
              'SALDO_CAPITAL_ML'           ||CHR(124)|| 'INTERES_MO'                 ||CHR(124)|| 'INTERES_ML'               ||CHR(124)|| 'INTERES_SUSPENDIDO_MO'    ||CHR(124)|| 'INTERES_SUSPENDIDO_ML'      ||CHR(124)||
              'SALDO_CONTINGENTE_MO'       ||CHR(124)|| 'SALDO_CONTINGENTE_ML'       ||CHR(124)|| 'GARANTIA_COMPUTABLE_MO'   ||CHR(124)|| 'GARANTIA_COMPUTABLE_ML'   ||CHR(124)|| 'PORCENTAJE_PREVISION'       ||CHR(124)||
              'PREVISION_S_CAPITAL_MO'     ||CHR(124)|| 'PREVISION_S_CAPITAL_ML'     ||CHR(124)|| 'PREVISION_S_INTERES_MO'   ||CHR(124)|| 'PREVISION_S_INTERES_ML'   ||CHR(124)|| 'PREVISION_S_CONTINGENTE_MO' ||CHR(124)||
              'PREVISION_S_CONTINGENTE_ML' ||CHR(124)|| 'PRIMERA_PREVISION_MO'       ||CHR(124)|| 'PRIMERA_PREVISION_ML'     ||CHR(124)|| 'SEGUNDA_PREVISION_MO'     ||CHR(124)|| 'SEGUNDA_PREVISION_ML'       ||CHR(124)||
              'PREVISION_GENERICA_MO'      ||CHR(124)|| 'PREVISION_GENERICA_ML'      ||CHR(124)|| 'ESTADO'                   ||CHR(124)|| 'EJECUTIVO'                ||CHR(124)|| 'NOMBRE_EJECUTIVO'           ||CHR(124)||
              'SEGMENTO'                   ||CHR(124)|| 'CLASIF_INTERNA'             ||CHR(124)|| 'TIPO_PRESTAMO'            ||CHR(124)|| 'TAE'                      ||CHR(124)|| 'TAN'                        ||CHR(124)||
              'MONTO_OPERACION_MO'         ||CHR(124)|| 'MONTO_OPERACION_ML'         ||CHR(124)|| 'MONTO_CUOTA_ATRASADA_MO'  ||CHR(124)|| 'MONTO_CUOTA_ATRASADA_ML'  ||CHR(124)|| 'CUOTAS_CANCELADAS'          ||CHR(124)||
              'FECHA_1ER_VTO'              ||CHR(124)|| 'FECHA_VTO_MAS_ANTIGUO'      ||CHR(124)|| 'SALDO_DEUDA_EN_ACTIVO_MO' ||CHR(124)|| 'SALDO_DEUDA_EN_ACTIVO_ML' ||CHR(124)|| 'TOTAL_DE_RIESGO'            ||CHR(124)||
              'RECUPERACIONES'             ||CHR(124)|| 'CATEGORIA_DE_PERSONA'       ||CHR(124)|| 'CATEGORIA_RRR'            ||CHR(124)|| 'GARANTIA_BANCARIA_MO'     ||CHR(124)|| 'GARANTIA_BANCARIA_ML'       ||CHR(124)||
              'GARANTIA_NO_BANCARIA_MO'    ||CHR(124)|| 'GARANTIA_NO_BANCARIA_ML'    ||CHR(124)|| 'CATEGORIA_DE_OPERACION'   ||CHR(124)|| 'ES_R4'                    ||CHR(124)|| 'TIPO_DOCUMENTO_CRC'         ||CHR(124)||
              'NRO_DOCUMENTO_CRC';

utl_file.put_line(v_file3,v_linetit3);

--**********************************************************************

-- Definir una linea en blanco para separar los datos del titulo de los campos
v_linetit := ' ';
utl_file.put_line(v_file,v_linetit);
--- RE DE-1172
v_linetit2 := ' ';
utl_file.put_line(v_file2,v_linetit2);
--- PIPROINTE-285 Riesgos - Anexo 1 - Reportes de Gestión requeridos por GNB Sudameris Colombia (Query 9)
/*
v_linetit3 := ' ';
utl_file.put_line(v_file3,v_linetit3);
*/
rp_mquery.empresa := fug_obt_cod_entidad;
rp_mquery.fecha_informe := v_fec_sist;
rp_mquery.sub_operacion := ' ';
rp_mquery.papel := 0;

---********
pr_ins_prev_det(v_fec_sist);
--Definir un cursor for loop que recorre los datos obtenidos
If cu_prevision_det%isopen THEN
   CLOSE cu_prevision_det;
End If;
Open cu_prevision_det;
Loop
FETCH cu_prevision_det BULK COLLECT INTO rec LIMIT 3000;
FOR i in 1.. rec.count LOOP
--FOR REC IN cu_prevision_det LOOP

  prs_obt_gru_eco_bcp(rec(i).doc, rec(i).nro_doc, v_gru_eco_bcp_1, v_gru_eco_bcp_2, v_gru_eco_bcp_3, v_gru_eco_bcp_4, v_gru_eco_bcp_5, v_grupo_eco_bcp);--CNF-GRU_ECO_BCP
  ---seteamos las variables
     v_cta_origen               := null;
     v_fec_ini_origen           := null;
     v_sub_afinidad_origen      := null;
     v_desc_sub_afinidad_origen := null;
     v_campana_origen           := null;
  ---
  -- RE DE-1172 ***********
   v_usu_liq := NULL;
   v_canal := NULL;
   v_des_canal := NULL;
   v_usu_promotor := NULL;
   v_des_promotor := NULL;
   v_concesionaria := NULL;
   v_des_concesionaria := NULL;
  --************************
  --RE DE-1358
  --v_can_pt             := null;
  v_mes_facturacion    := null;
  v_ano_facturacion    := null;
  v_mto_facturacion    := null;
  v_mes_rating         := null;
  v_ano_rating         := null;
  v_rating             := null;
  v_mes_hatos          := null;
  v_ano_hatos          := null;
  v_can_hatos          := null;
  v_tip_hec_cultivadas := null;
  v_nro_hec_cultivadas := null;
  v_mes                := null;
  v_anho               := null;
  v_des_tip_cultivo   := null;

  --RE DE-1622
  /*
    Inicializo todas las variables
  */
  v_nro_sol_linea     := NULL;
  v_est_cuenta        := NULL;
  v_nro_linea         := NULL;
  v_py_autorizador    := NULL;
  v_py_nombre         := NULL;
  v_fec_autorizacion  := NULL;
  v_fec_ini_pt        := NULL;
  v_fec_vencimiento   := NULL;
  v_fec_ini_linea     := NULL;
  v_tiene_sobregiro   := NULL;
  v_cta_ori_cta_cte   := NULL;
  v_cta_inicial       := NULL;
  v_fec_pos_linea     := NULL;
  -- DE-2594
  v_cod_usu_apr_cuenta := NULL;
  v_nom_usu_apr_cuenta := NULL;
  v_fec_apr_cuenta     := NULL;
  -- COREADRRR-1
  v_tip_rrr_holding   := NULL;
  v_ref_rrr_holding   := NULL;
  v_sub_cat_individual := null;
  -- PIPROINTE-285 Riesgos - Anexo 1 - Reportes de Gestión requeridos por GNB Sudameris Colombia (Query 9)
  v_mto_desembolsado   := 0;
  v_fec_vto            := null;
  v_cotizacion         := 0;
  v_sal_capital_mo     := 0;
  v_sal_capital_ml     := 0;
  v_sal_interes_mo     := 0;
  v_sal_interes_ml     := nvl(rec(i).dev_no_cobrado,0);
  v_int_suspenso_mo    := 0;
  v_int_suspenso_ml    := 0;
  v_mto_cta_mora_mo    := 0;
  v_mto_cta_mora_ml    := 0;
  v_can_cuo_canceladas := 0;
  v_fec_pri_vto        := null;
  v_fec_vto_antiguo    := null;
  v_sal_deu_activo_mo  := 0;
  v_sal_deu_activo_ml  := 0;
  v_por_prevision      := 0;
  v_por_prev_calc      := 0;
  v_prev_cap_mo        := 0;
  v_prev_cap_ml        := rec(i).tot_cap_prev;
  v_prev_int_mo        := 0;
  v_prev_int_ml        := rec(i).tot_int_prev;
  v_prev_cont_mo       := 0;
  v_prev_cont_ml       := 0;
  v_mto_cont_mo        := 0;
  v_mto_cont_ml        := 0;
  v_tot_deuda_mo       := 0;
  v_tot_deuda_ml       := 0;
  v_cod_ori_fondo      := 0;
  v_por_ori_fondo      := 0;
  v_ori_fondo_afd      := 'N';
  v_tot_prev_mo        := 0;
  
    if rec(i).cod_modulo = '5' Then
        --TARJETAS
        v_null := 'N';
        -- DE-2594 PyR MAY/2017 NAF: Unificacion de consultas
        -- Obtenemos de la tarjeta la sub_afinidad o en caso que sea null obtenemos la afinidad
        -- Obtenemos la fecha de ingreso y campaña de la tarjeta
        -- RE DE-1358 SE OBTIENE EL CODIGO Y DESCRIPCION DEL CANAL DE UNA TARJETA DE CREDITO
        begin
           select t.sub_afinidad,
                  t.fec_apertura,
                  nvl(t.cod_campana,s.cod_campana),
                  nvl(t.cod_usu_promotor, s.cod_usu_promotor),
                  nvl(t.cod_canal,s.cod_canal), nvl(c.descripcion,'s/d') -- DE-2044 canal de ta_cta_tarjeta sino de solicitudes
             into v_sub_afinidad,
                  v_fec_inicio,
                  v_campana,
                  v_usu_promotor,
                  v_canal, v_des_canal
             from ta_cta_tarjetas t, ta_solicitudes s, ge_canales c
            where t.cod_modulo = rec(i).cod_modulo
              and t.nro_cuenta = rec(i).nro_cuenta
              and t.nro_solicitud = s.nro_solicitud(+)
              And s.cod_canal = c.cod_canal(+);
        exception
             when others then
                  v_null         := 'S';
                  v_sub_afinidad := null;
                  v_fec_inicio   := null;
                  v_canal        := null;
                  v_des_canal    := 's/d';                  
        end;           
       -- DE-2044
       if v_usu_promotor is not null then
         v_des_promotor := fue_obt_nom_usuario(v_usu_promotor);
       end if;
        v_sub_modalidad := v_sub_afinidad;
        --Obtenemos la descripcion de sub_afinidad o en su  defecto la descripcion de afinidad
        if v_null = 'N' then
           v_sub_modalidad      := v_sub_afinidad;
           v_desc_sub_modalidad := fue_obt_des_refcodes('SUB_AFINIDAD',  v_sub_afinidad);
        else
           v_sub_modalidad      := null;
           v_desc_sub_modalidad := null;
        end if;
        
        --- PIPROINTE-285 Riesgos - Anexo 1 - Reportes de Gestión requeridos por GNB Sudameris Colombia (Query 9)
        begin
           select nvl(e.porcentaje,0), nvl(e.tot_prv_contingencia,0), nvl(e.por_calculado,0)
             into v_por_prevision, v_prev_cont_mo, v_por_prev_calc
             from mi_previsiones_res e
            where e.nro_cuenta = rec(i).nro_cuenta;
         exception
            when others then
               v_por_prevision := 0;
               v_prev_cont_mo  := 0;
               v_por_prev_calc := 0;
        end;
        --- TC siemprees en moneda local
        v_prev_cap_mo := nvl(rec(i).tot_prevision,0) - nvl(v_prev_cont_mo,0);
        begin
          select b.mto_aprobado, a.fec_vct_ult_cierre,
                 -- (nvl(a.sal_facturar,0)+nvl(a.sal_facturado,0)+nvl(a.sal_financiado,0)+nvl(a.sal_cuo_pendientes,0))
                 -- Comentado por ICL 24/08/2011 a pedido de Hector Bengoa se cambia por el saldo seg?n movimientos
                 nvl(a.sal_procesadora,0),
                 decode(a.estado, 'B', 0, (nvl(a.lin_credito,0) + nvl(a.lin_cuotas,0)))
            into v_mto_desembolsado, v_fec_vto,
                 v_sal_capital_mo, v_mto_cont_mo
            from ta_cta_tarjetas a,
                 ta_solicitudes b
           where a.cod_modulo = rec(i).cod_modulo
             and a.nro_cuenta = rec(i).nro_cuenta
             and a.nro_solicitud = b.nro_solicitud(+);
        exception
          when others then
             v_mto_desembolsado := 0;
             v_fec_vto := null;
             v_sal_capital_mo := 0;
             v_mto_cont_mo := nvl(rec(i).capital_inicial,0);
        end;
        v_int_suspenso_mo := 0;
        v_sal_deu_activo_mo := nvl(v_sal_capital_mo,0);
        v_tip_prestamo := null;
     elsif rec(i).cod_modulo = '6' and nvl(rec(i).query_10,'N') not in ('P','V') then
        --PRESTAMOS
        --Se obtiene cod_sub_modalidad, descripcion sub_modalidad, fecha_inicio = null, campaña
        v_sub_modalidad := rec(i).cod_sub_modalidad;
        begin
           select descripcion
             into v_desc_sub_modalidad
             from ge_sub_modalidades
            where cod_modulo = rec(i).cod_modulo
              and cod_modalidad = rec(i).cod_modalidad
              and cod_sub_modalidad = rec(i).cod_sub_modalidad;
        exception
             when others then
                v_desc_sub_modalidad := null;
              end;
        --obtiene la campaña de la cuenta
        begin
          select nvl(a.cod_campana, b.cod_campana)
             --- PIPROINTE-285 Riesgos - Anexo 1 - Reportes de Gestión requeridos por GNB Sudameris Colombia (Query 9)
               , b.tot_desembolsar, a.fec_vencimiento,
                 a.sal_cap_batch, a.dev_suspenso,
                 a.sal_cap_batch, a.tipo,
                 a.cod_ori_fondo, a.por_ori_fondo
            into v_campana
               , v_mto_desembolsado, v_fec_vto,
                 v_sal_capital_mo, v_int_suspenso_mo,
                 v_sal_deu_activo_mo, v_tip_prestamo,
                 v_cod_ori_fondo, v_por_ori_fondo
            from pr_cta_prestamos a,
                 pr_solicitudes b
           where a.cod_modulo = rec(i).cod_modulo
             and a.nro_cuenta = rec(i).nro_cuenta
             and a.nro_solicitud = b.nro_solicitud(+);
        exception
          when others then
           v_campana := null;
           v_mto_desembolsado := 0;
           v_fec_vto := null;
           v_sal_capital_mo := 0;
           v_int_suspenso_mo := 0;
           v_sal_deu_activo_mo := 0;
           v_tip_prestamo := null;
        end;
        v_fec_inicio := Null;
     -- RE DE-1172 *************************
     BEGIN -- obtenemos usuario que liquidó el prestamo
      Select G.COD_USUARIO
         INTO v_usu_liq
        From PR_SOL_GESTIONES   G,
             PR_SOLICITUDES     P
       Where P.NRO_SOLICITUD = G.NRO_SOLICITUD
         and g.nro_solicitud = rec(i).nro_solicitud
         and G.ESTADO = 'L'
         AND G.FECHA = (Select Max(G1.FECHA)
                            From PR_SOL_GESTIONES G1,
                                 PR_SOLICITUDES   P1
                           Where P1.NRO_SOLICITUD = G1.NRO_SOLICITUD
                             And G1.NRO_SOLICITUD = G.NRO_SOLICITUD
                             And G1.ESTADO = 'L');
     EXCEPTION
       WHEN OTHERS THEN
         v_usu_liq := NULL;
     END;
     BEGIN -- obtiene canal, promotor, concesionaria/inmobiliaria
       SELECT P.COD_CANAL, P.COD_USU_PROMOTOR, P.COD_ENT_CONCESIONARIA
       INTO   v_canal, v_usu_promotor, v_concesionaria
       FROM PR_SOLICITUDES P
       WHERE p.nro_solicitud = rec(i).nro_solicitud;
       EXCEPTION
         WHEN OTHERS THEN
          v_canal := NULL;
          v_usu_promotor := NULL;
          v_concesionaria := NULL;
     END;
     -- DE-2044
     if v_usu_promotor is not null then
       v_des_promotor := fue_obt_nom_usuario(v_usu_promotor);
     end if;
     -- obtiene el nombre de la concesionaria
     IF v_concesionaria IS NOT NULL THEN
       BEGIN
         Select DESCRIPCION
           into v_des_concesionaria
           From GE_ENTES
          Where COD_ENTE = v_concesionaria;
       EXCEPTION
         WHEN OTHERS THEN
           v_des_concesionaria := NULL;
       END;
      END IF;
      --************************************
      -- RE DE-1358   -- DE-2044 -- separar el código de la descripción --
     -- v_can_pt := to_char(rec.canal_prestamo)||' - '||FUG_OBT_DES_CANAL(rec.canal_prestamo);

        if rec(i).canal_prestamo is not null then --- DE-2044 canal de pr_cta_prestamos sino de pr_solicitudes
          v_canal     := rec(i).canal_prestamo;
          v_des_canal := FUG_OBT_DES_CANAL(rec(i).canal_prestamo);
        end if;
        -- COREADRRR-1
        BEGIN
          SELECT d.val_parametro
            INTO v_tip_rrr_holding
            FROM ge_cta_dat_adicionales d
           WHERE d.nro_cuenta = rec(i).nro_cuenta
             AND d.parametro = 'TIP_REF_HOLDING';
        EXCEPTION
          WHEN OTHERS THEN
            v_tip_rrr_holding := NULL;
        END;
        IF v_tip_rrr_holding IS NULL AND rec(i).tip_renovacion IN ('Re-estructurado','Renovado','Refinanciado') THEN
           v_tip_rrr_holding := 'R';
        END IF;
        IF v_tip_rrr_holding IS NOT NULL THEN
           v_ref_rrr_holding := fue_obt_des_refcodes('TIP_REF_HOLDING', v_tip_rrr_holding);
        END IF;                    
        --- PIPROINTE-285 Riesgos - Anexo 1 - Reportes de Gestión requeridos por GNB Sudameris Colombia (Query 9)
        begin
           select nvl(e.porcentaje,0), nvl(e.por_calculado,0)
             into v_por_prevision, v_por_prev_calc
             from mi_previsiones_res e
            where e.nro_cuenta = rec(i).nro_cuenta;
         exception
            when others then
               v_por_prevision := 0;
               v_por_prev_calc := 0;
        end;
        select sum(nvl(r.sal_capital,0)+nvl(r.sal_interes,0)+nvl(r.sal_int_documentado,0))
          into v_mto_cta_mora_mo
          from pr_cuotas r
         where r.nro_cuenta = rec(i).nro_cuenta
           and r.nro_cuota > 0
           and r.estado <> 'N'
           and r.fec_vencimiento < v_fec_actual;
        select count(*)
          into v_can_cuo_canceladas
          from pr_cuotas r
         where r.nro_cuenta = rec(i).nro_cuenta
           and r.nro_cuota > 0
           and r.estado = 'N';
        select min(r.fec_vencimiento)
          into v_fec_pri_vto
          from pr_cuotas r
         where r.nro_cuenta = rec(i).nro_cuenta
           and r.nro_cuota > 0;
        v_fec_vto_antiguo := v_fec_pri_vto;
          
     elsif rec(i).cod_modulo = '15' And rec(i).cod_modalidad = '151' Then
        --OPERACIONES VENCIDAS
          v_sub_modalidad := to_char(rec(i).cod_sub_modalidad);
          begin
           select descripcion
             into v_desc_sub_modalidad
             from ge_sub_modalidades
            where cod_modulo = rec(i).cod_modulo
              and cod_modalidad = rec(i).cod_modalidad
              and cod_sub_modalidad = rec(i).cod_sub_modalidad;
        exception
             when others then
                v_desc_sub_modalidad := null;
              end;
                v_campana    := null;
                v_fec_inicio := null;
        --obtiene la cta origen
        begin
           select v.nro_cta_origen
             into v_cta_origen
             from ov_cta_vencidas v
            where v.nro_cuenta = rec(i).nro_cuenta
              and v.cod_modulo = rec(i).cod_modulo
              and v.cod_modalidad = '151';
        exception
             when others then
                  v_cta_origen := Null;
        end;
          If nvl(v_cta_origen, 'N') != 'N' Then
            --verifica que exista una cta origen de tarjetas vencidas
               v_null := 'N';
            --Otenemos de la tarjeta la sub_afinidad
               begin
                select t.sub_afinidad
                  into v_sub_afinidad_origen
                  from ta_cta_tarjetas t
                 where t.cod_modulo = '5'
                   and t.nro_cuenta = v_cta_origen;
             exception
                  when others then
                   v_null                := 'S';
                   v_sub_afinidad_origen := null;
                   end;
            --obtenemos la fecha de ingreso y campaña de la tarjeta
      -- DE-2044
      -- se agrega para que también obtenga el canal --- dydmr-4177 DM
               begin
                select t.fec_apertura,
                       nvl(t.cod_campana,s.cod_campana),
                       nvl(t.cod_usu_promotor, s.cod_usu_promotor),
                       nvl(t.cod_canal,s.cod_canal), ca.descripcion
                  into v_fec_ini_origen,
                       v_campana_origen,
                       v_usu_promotor,
                       v_canal, v_des_canal
                  from ta_cta_tarjetas t, ta_solicitudes s, ge_canales ca
                 where t.cod_modulo = '5'
                   and t.nro_cuenta = v_cta_origen
                   AND t.nro_solicitud = s.nro_solicitud(+)
                   and s.cod_canal     = ca.cod_canal(+);
             exception
                  when others then
                     v_fec_ini_origen := null;
                     v_canal          := null;
                     v_des_canal      := 's/d';
                   end;
            --Obtenemos la descripcion de sub_afinidad o en su  defecto la descripcion de afinidad
               if v_null = 'N' then
                  v_desc_sub_afinidad_origen := fue_obt_des_refcodes('SUB_AFINIDAD', v_sub_afinidad_origen);
               else
                  v_desc_sub_afinidad_origen := null;
               end if;
               -- DE-2044
               if v_usu_promotor is not null then
                 v_des_promotor := fue_obt_nom_usuario(v_usu_promotor);
               end if;
          end if;
           --- PIPROINTE-285 Riesgos - Anexo 1 - Reportes de Gestión requeridos por GNB Sudameris Colombia (Query 9)
           begin
              select nvl(e.porcentaje,0), nvl(e.por_calculado,0)
                into v_por_prevision, v_por_prev_calc
                from mi_previsiones_res e
               where e.nro_cuenta = rec(i).nro_cuenta;
            exception
               when others then
                  v_por_prevision := 0;
                  v_por_prev_calc := 0;
           end;
      else
         if rec(i).cod_modulo = 15 Then
           --- PIPROINTE-285 Riesgos - Anexo 1 - Reportes de Gestión requeridos por GNB Sudameris Colombia (Query 9)
           begin
              select nvl(e.porcentaje,0), nvl(e.por_calculado,0)
                into v_por_prevision, v_por_prev_calc
                from mi_previsiones_res e
               where e.nro_cuenta = rec(i).nro_cuenta;
            exception
               when others then
                  v_por_prevision := 0;
                  v_por_prev_calc := 0;
           end;
        elsif rec(i).cod_modulo = 4 Then
           begin
              select nvl(e.porcentaje,0),
                     nvl(e.monto,0),
                     nvl(e.tot_prv_contingencia,0),
                     nvl(e.por_calculado,0)
                into v_por_prevision, v_tot_prev_mo, v_prev_cont_mo, v_por_prev_calc
                from mi_previsiones_res e
               where e.nro_cuenta = rec(i).nro_cuenta;
            exception
               when others then
                  v_por_prevision := 0;
                  v_tot_prev_mo   := 0;
                  v_prev_cont_mo  := 0;
                  v_por_prev_calc := 0;
           end;
           v_prev_cap_mo := nvl(v_tot_prev_mo,0) - nvl(v_prev_cont_mo,0);
           ---
           v_mto_desembolsado := 0;
           v_cod_ente         := null;
           begin
             select (nvl(a.sal_tot_batch,0) - nvl(sal_blo_batch,0) - nvl(sal_ret_batch,0)),
                    a.cod_ente
               into v_sal_capital_mo, v_cod_ente
               from cc_cta_corrientes a
              where a.nro_cuenta = rec(i).nro_cuenta;
           exception
             when others then
              v_sal_capital_mo := 0;
              v_cod_ente := null;
           end;
           -- ICL 22/03/2012 Mail HB: Contingencia solo considerar Nómina
           begin
           /*select a.mto_linea
               into v_mto_cont_mo
               from cc_sobregiros a
              where a.nro_cuenta = rec.nro_cuenta
                and a.fecha = v_fec_actual;*/
             select a.monto
               into v_mto_cont_mo
               from cc_lin_sobregiros a
              where a.nro_cuenta = rec(i).nro_cuenta
                and a.estado = 'A';           
           exception
             when others then
              v_mto_cont_mo := 0;
           end;
           --v_sal_interes_mo := 0;
           v_int_suspenso_mo := 0;
           v_sal_deu_activo_mo := 0;
           v_tip_prestamo := null;
           ---
           v_fec_vto := null;
           begin
             select max(a.fec_vencimiento)
               into v_fec_vto
               from cc_lin_sobregiros a
              where (a.nro_cuenta = rec(i).nro_cuenta or
                     a.cod_persona = rec(i).riesgo)
                and a.estado = 'A';
           exception
             when others then
                v_fec_vto := null;
           end;
        end if;
        ---<
        v_sub_modalidad := rec(i).cod_sub_modalidad;
        begin
         select descripcion
           into v_desc_sub_modalidad
           from ge_sub_modalidades
          where cod_modulo = rec(i).cod_modulo
            and cod_modalidad = rec(i).cod_modalidad
            and cod_sub_modalidad = rec(i).cod_sub_modalidad;
      exception
           when others then
            v_desc_sub_modalidad := null;
            end;
        v_campana    := rec(i).cod_campana;
        v_fec_inicio := null;
      end if;
      -- Asigno valor a las variables de grupo.
      -- Requerimiento: CNFAIRUNO-3.
      -- Fecha: 22/09/2014.
      /*
      || I.	Vinculo: Se debe colocar si están vinculados a algún grupo económico.
      || 1 para aquellos que estén vinculados al Banco GNB,
      || 2 para aquellos que estén vinculados a algún grupo económico y
      || 9 para aquellos que no están relacionados a ningún grupo económico.
      */
      rp_mquery.grupo_econ := nvl(rec(i).gru_eco_bcp,0); -- para que no pierda su valor
      if rp_mquery.grupo_econ is null then
         v_relacion := '9';
      elsif rec(i).tipo = 'R' then
         v_relacion := '1';
      else
         v_relacion := '2';
      end if;
      rp_mquery.vinculo := v_relacion;
      ---      
      IF rec(i).GRU_ECO_INFORMADO IS NULL THEN
         rec(i).cat_gru_economico := NULL;
         rec(i).gru_eco_bcp       := NULL;
         rec(i).sub_cat_grupo     := NULL;
      END IF;
      -- Obtiene la categoria calculada en base a las sub categorías.
      IF rec(i).cat_riesgo <> 1 THEN
         v_cat_bcp := rec(i).cat_riesgo;
      ELSE
         v_es_covid:= nvl(fug_obt_pardinamico('COD_MAD_RESOLUCION04', rec(i).cod_modulo, rec(i).cod_modalidad),'N') ;
         if v_es_covid = 'S' then
            v_sub_cat_individual := rec(i).sub_cat_individual_r4;
         else 
            v_sub_cat_individual := rec(i).sub_cat_individual_no_r4;
         end if;
         IF (nvl(fug_obt_pardinamico('MAD_HIPOTECARIOS', rec(i).cod_modulo, rec(i).cod_modalidad), 'N') = 'S' OR
             nvl(fug_obt_pardinamico('PRE_MAD_CONSTRUCCIONES', rec(i).cod_modulo, rec(i).cod_modalidad), 'N') = 'S') AND
            (v_sub_cat_individual > 1 AND v_sub_cat_individual < 2) THEN
             v_sub_cat_individual := 1;          
         END IF;   
         v_cat_bcp := fup_obt_categoria(NVL(v_sub_cat_individual,1),NVL(rec(i).sub_cat_grupo,1));
      END IF;
       BEGIN    --DE-1358 - SEGMENTACION(MES,AÑO,FACTURACION)-RATING(AÑO,MES,RATING)-GANADERIA(MES,AÑO,HATOS)
          --DYDMR-DYDMR-4977 / rpavon 20.09.2016--
          --Se ajusta el criterio a la pantalla ercapers--
          --Se trae el registro maximo de mes-año facturacion--
          --por persona y por cod_rub_primario de ba_personas--
          SELECT t.mes_facturacion, t.ano_facturacion, t.mto_facturacion, t.mes_rating, t.ano_rating, t.rating, t.mes_hatos, t.ano_hatos, t.can_hatos
            INTO v_mes_facturacion, v_ano_facturacion, v_mto_facturacion, v_mes_rating, v_ano_rating, v_rating, v_mes_hatos, v_ano_hatos, v_can_hatos
            FROM CR_PER_DAT_SEGMENTACION T
           WHERE T.COD_PERSONA = rec(i).riesgo
             AND T.COD_RUB_PRIMARIO =  rec(i).act_primaria
             AND TO_DATE(T.ANO_FACTURACION||T.MES_FACTURACION,'YYYYMM') =
                   (SELECT MAX(TO_DATE(CP1.ANO_FACTURACION||CP1.MES_FACTURACION,'YYYYMM'))
                      FROM CR_PER_DAT_SEGMENTACION CP1
                     WHERE CP1.COD_PERSONA = T.COD_PERSONA
                       AND CP1.COD_RUB_PRIMARIO = T.COD_RUB_PRIMARIO);
        EXCEPTION
          WHEN OTHERS THEN
            v_mes_facturacion := null;
            v_ano_facturacion := null;
            v_mto_facturacion := null;
            v_mes_rating      := null;
            v_ano_rating      := null;
            v_rating          := null;
            v_mes_hatos       := null;
            v_ano_hatos       := null;
            v_can_hatos       := null;
        END;
        --DE-1358 - AGRICULTURA(TIPO HECTAREAS CULTIVADA, NRO HECTAREAS CULTIVADA, MES, AÑO)
        DECLARE
           v_cant NUMBER(3); --cantidad de tipos de hectareas
        BEGIN
          --- CONTAMOS CANTIDAD DE TIPOS DE CULTIVOS
         SELECT COUNT(1)
              INTO v_cant
              FROM cr_per_tip_hectareas t1
             WHERE t1.cod_persona = rec(i).riesgo
               AND t1.nro_hec_cultivadas = (SELECT max(t2.nro_hec_cultivadas)
                                              FROM cr_per_tip_hectareas t2
                                             WHERE t2.cod_persona = t1.cod_persona);
          ----
         IF v_cant = 1 THEN --si existe un solo cultivo
           BEGIN
             SELECT t.tip_hec_cultivadas, t.nro_hec_cultivadas, t.mes, t.anho
               INTO v_tip_hec_cultivadas, v_nro_hec_cultivadas, v_mes, v_anho
               FROM cr_per_tip_hectareas t
              WHERE t.cod_persona = rec(i).riesgo
                AND t.nro_hec_cultivadas = (SELECT max(t3.nro_hec_cultivadas)
                                              FROM cr_per_tip_hectareas t3
                                              WHERE t3.cod_persona = t.cod_persona);
           EXCEPTION
            WHEN OTHERS THEN
             v_tip_hec_cultivadas := null;
             v_nro_hec_cultivadas := null;
             v_mes                := null;
             v_anho               := null;
             v_des_tip_cultivo    := null;
           END;
         ELSIF v_cant > 1 THEN
            BEGIN
              SELECT tt.tip_hec_cultivadas, tt.nro_hec_cultivadas, tt.mes, tt.anho
                INTO v_tip_hec_cultivadas, v_nro_hec_cultivadas, v_mes, v_anho
                FROM cr_per_tip_hectareas tt
               WHERE tt.cod_persona = rec(i).riesgo
                 AND tt.tip_hec_cultivadas = 9 ; --SI ES SOJA
            EXCEPTION
              WHEN no_data_found THEN -- SI NO ES SOJA TRAEMOS EL PRIMERO EN LA LISTA
                 SELECT tt.tip_hec_cultivadas, tt.nro_hec_cultivadas, tt.mes, tt.anho
                   INTO v_tip_hec_cultivadas, v_nro_hec_cultivadas, v_mes, v_anho
                   FROM cr_per_tip_hectareas tt
                  WHERE tt.cod_persona = rec(i).riesgo
                  AND tt.nro_hec_cultivadas = (SELECT MAX(t4.nro_hec_cultivadas)
                                                     FROM cr_per_tip_hectareas t4
                                                    WHERE t4.cod_persona = tt.cod_persona)
                  AND rownum = 1;
              WHEN OTHERS THEN
               v_tip_hec_cultivadas := null;
               v_nro_hec_cultivadas := null;
               v_mes                := null;
               v_anho               := null;
               v_des_tip_cultivo    := null;
            END;

         ELSE
            v_tip_hec_cultivadas := null;
            v_nro_hec_cultivadas := null;
            v_mes                := null;
            v_anho               := null;
            v_des_tip_cultivo    := null;
         END IF;
        EXCEPTION
          WHEN OTHERS THEN
            v_tip_hec_cultivadas := null;
            v_nro_hec_cultivadas := null;
            v_mes                := null;
            v_anho               := null;
            v_des_tip_cultivo   := null;
        END;
        IF v_tip_hec_cultivadas IS NOT NULL THEN
           v_des_tip_cultivo := fue_obt_des_refcodes('COD_TIP_HEC_CULTIVADAS',v_tip_hec_cultivadas);
        END IF;
     -- ***************** DE-1622 - GUSTAVO FERNANDEZ ********************
     -- PY_AUTORIZADOR, NOMBRE AUTORIZADOR, NRO_LINEA , FECHA AUTORIZACION
     --1ro verificar si existe en la tabla ge_cta_aut_usuarios
     --si existe en la tabla, entonces asignar los datos a mostrar en el prev_det
     IF rec(i).COD_MODULO IN (5,6,15) OR (rec(i).COD_MODULO = 4 AND rec(i).COD_MODALIDAD = 41) THEN
       -- ver si tiene cuenta madre(inicial)
       IF rec(i).COD_MODULO = 6 THEN
          v_cta_inicial := fl_obt_cta_inicial(rec(i).nro_cuenta);
          --- DE-2449 08/2016
          if v_cta_inicial <> rec(i).nro_cuenta then ---es RRR
            v_cta_origen := v_cta_inicial;
            begin
               select e.fec_inicio, e.cod_campana into v_fec_ini_origen, v_campana_origen
                from pr_cta_prestamos e where
                e.nro_cuenta = v_cta_inicial;
            exception
              when others then
               v_cta_origen     := null;
               v_fec_ini_origen := null;
               v_campana_origen := null;
            end;
          end if;
          ---
       ELSIF rec(i).COD_MODULO = 5 OR (rec(i).COD_MODULO = '15' AND rec(i).cod_modalidad = '151' )THEN --operaciones vencidas mod=15 and mad=151
          IF rec(i).cod_modulo = 5 THEN
             v_cta_inicial := rec(i).nro_cuenta;
          ELSE
             v_cta_inicial := v_cta_origen;
          END IF;
       END IF;
       BEGIN
         SELECT u.usu_autorizador, u.fec_autorizacion, u.nro_linea, u.nro_solicitud
           INTO v_py_autorizador, v_fec_autorizacion, v_nro_linea, v_nro_sol_linea
           FROM ge_cta_aut_usuarios u
          WHERE u.nro_cuenta = v_cta_inicial
            AND u.cod_modulo = nvl(rec(i).cod_modulo, u.cod_modulo)
            AND u.cod_modalidad = nvl(rec(i).cod_modalidad, u.cod_modalidad);
       EXCEPTION
           WHEN NO_DATA_FOUND THEN
             BEGIN
               SELECT u.usu_autorizador, u.fec_autorizacion, u.nro_linea, u.nro_solicitud
                   INTO v_py_autorizador, v_fec_autorizacion, v_nro_linea,  v_nro_sol_linea
                   FROM ge_cta_aut_usuarios u
                WHERE u.nro_cuenta = rec(i).nro_cuenta
                  AND u.cod_modulo = nvl(rec(i).cod_modulo, u.cod_modulo)
                  AND u.cod_modalidad = nvl(rec(i).cod_modalidad, u.cod_modalidad);
             EXCEPTION
                 WHEN OTHERS THEN
                  NULL;
             END;
           WHEN OTHERS THEN
            NULL;
       END;
       -- DE-2594 PyR NAF MAY/2017
       -- los campos nuevos deben ser siempre de la cta actual
       BEGIN
         SELECT u.cod_usu_apr_cuenta, u.nom_usu_apr_cuenta, u.fec_apr_cuenta
           INTO v_cod_usu_apr_cuenta, v_nom_usu_apr_cuenta, v_fec_apr_cuenta
           FROM ge_cta_aut_usuarios u
          WHERE u.nro_cuenta = rec(i).nro_cuenta
            AND u.cod_modulo = nvl(rec(i).cod_modulo, u.cod_modulo)
            AND u.cod_modalidad = nvl(rec(i).cod_modalidad, u.cod_modalidad);
       EXCEPTION
           WHEN NO_DATA_FOUND THEN
             v_cod_usu_apr_cuenta := null;
             v_nom_usu_apr_cuenta := null;
             v_fec_apr_cuenta := null;
       END;
       IF v_py_autorizador IS NULL THEN
         IF rec(i).COD_MODULO = 6 THEN --PRESTAMOS
           BEGIN--obtiene el nro de solicitud  y fecha inicio de prestamo
             SELECT nvl(v_nro_sol_linea,s.nro_solicitud), s.fec_inicio
               INTO v_nro_sol_linea, v_fec_ini_pt
               FROM pr_cta_prestamos s
              WHERE s.nro_cuenta = nvl(v_cta_inicial,rec(i).nro_cuenta)
                AND s.nro_solicitud IS NOT NULL;
           EXCEPTION
             WHEN OTHERS THEN
               NULL;
           END;
         ELSIF rec(i).COD_MODULO = 5 OR (rec(i).COD_MODULO = '15' AND rec(i).cod_modalidad = '151' )THEN -- tarjetas mod=5 / --operaciones vencidas mod=15 and mad=151
           -- obtenemos nro de solicitud y fecha_activación de la tarjeta
           BEGIN
             SELECT nvl(v_nro_sol_linea,c.nro_solicitud), c.fec_apertura
               INTO v_nro_sol_linea, v_fec_ini_pt
               FROM ta_cta_tarjetas c
              WHERE c.nro_cuenta = v_cta_inicial
                AND c.nro_solicitud IS NOT NULL;
           EXCEPTION
             WHEN OTHERS THEN
               NULL;
           END;
         END IF;
         --SI NO EXISTE EN LA TABLA GE_CTA_AUT_USUARIOS
         IF v_nro_linea IS NULL THEN
           --2do buscar de la tabla pr_lin_vin_productos_his donde se
           --registran las que no estan activas
           BEGIN
             SELECT a.cod_usuario, a.nro_linea
               INTO v_py_autorizador, v_nro_linea
               FROM pr_lin_vin_productos_his a
              WHERE a.nro_cuenta = nvl(v_cta_inicial,rec(i).nro_cuenta)
                AND a.fecha || a.hora = (SELECT MIN(a1.fecha || a1.hora)
                                             FROM pr_lin_vin_productos_his a1
                                            WHERE a1.nro_cuenta = a.nro_cuenta);
           EXCEPTION
             WHEN no_data_found THEN
               --3ro buscar de la tabla pr_lin_aplicaciones_his donde se encuentran los registros
               --historticos de las lineas aplicadas a una cuenta
               BEGIN
                  SELECT DISTINCT h.nro_linea
                       INTO v_nro_linea
                       FROM pr_lin_aplicaciones_his h
                      WHERE h.nro_cuenta = nvl(v_cta_inicial,rec(i).nro_cuenta)
                        AND h.fec_insercion =(SELECT MIN (h1.fec_insercion)
                                                FROM pr_lin_aplicaciones_his h1
                                               WHERE h1.nro_cuenta = h.nro_cuenta);
               EXCEPTION
                 WHEN no_data_found THEN
                   --4to buscar de la tabla pr_lin_aplicaciones donde se encuentran los registros
                   --de las lineas aplicadas a una cuenta
                   BEGIN
                      Select H.NRO_LINEA
                       INTO v_nro_linea
                       FROM pr_lin_aplicaciones h
                       Where H.NRO_CUENTA = NVL(V_CTA_INICIAL, rec(i).NRO_CUENTA)
                         And H.NRO_LINEA =(SELECT Min(H1.NRO_LINEA)
                                              FROM PR_LIN_APLICACIONES H1
                                             WHERE H1.NRO_CUENTA = H.NRO_CUENTA);
                   EXCEPTION
                     WHEN no_data_found THEN
                       --5to buscar en la tabla pr_cta_prestamos y ta_cta_tarjetas si tiene una linea asignada
                       BEGIN
                         IF rec(i).COD_MODULO = 6 THEN
                           --prestamos
                           SELECT p.nro_linea
                             INTO v_nro_linea
                             FROM pr_cta_prestamos p
                            WHERE p.nro_cuenta = nvl(v_cta_inicial,rec(i).nro_cuenta);
                         ELSIF rec(i).COD_MODULO = 5 OR (rec(i).COD_MODULO = '15' AND rec(i).cod_modalidad = '151' ) THEN
                           --tarjetas
                           SELECT t.nro_linea
                             INTO v_nro_linea
                             FROM ta_cta_tarjetas t
                            WHERE t.nro_cuenta = nvl(v_cta_inicial,rec(i).nro_cuenta);
                         END IF;
                       EXCEPTION
                         WHEN OTHERS THEN
                           NULL;
                       END;
                      WHEN OTHERS THEN
                       NULL;
                   END;
                WHEN OTHERS THEN
                 NULL;
               END;
              WHEN OTHERS THEN
                NULL;
           END;
         END IF;
         ---si hay linea
         IF v_nro_linea IS NOT NULL THEN
           BEGIN-- usu_insercion es el que aprobó
             SELECT nvl(l.usu_insercion, v_py_autorizador), nvl(l.fec_aprobacion,v_fec_autorizacion), nvl(l.fec_vencimiento,v_fec_vencimiento)
               INTO v_py_autorizador, v_fec_autorizacion, v_fec_vencimiento
               FROM pr_lineas_his l
              WHERE l.nro_linea = v_nro_linea
                AND l.estado = 'A' -- estado aprobado
                AND l.fec_insercion = (SELECT MIN(h.fec_insercion)
                                         FROM pr_lineas_his h
                                        WHERE h.nro_linea = l.nro_linea
                                          AND h.estado = 'A');
           EXCEPTION
             WHEN no_data_found THEN
               BEGIN-- usu_insercion es el que aprobó
                 SELECT nvl(l.usu_insercion, v_py_autorizador), nvl(l.fec_aprobacion,v_fec_autorizacion), nvl(l.fec_vencimiento,v_fec_vencimiento)
                   INTO v_py_autorizador, v_fec_autorizacion, v_fec_vencimiento
                   FROM pr_lineas l
                  WHERE l.nro_linea = v_nro_linea
                    AND l.estado = 'A'-- estado aprobado
                    AND l.fec_insercion = (SELECT MIN(h.fec_insercion)
                                             FROM pr_lineas h
                                            WHERE h.nro_linea = l.nro_linea
                                              AND h.estado = 'A');
               EXCEPTION
                 WHEN OTHERS THEN
                   NULL;
               END;
             WHEN OTHERS THEN
               NULL;
           END;
         END IF;
         -- si no tiene linea aplicada o el prestamo fue aprobado antes que la linea
         -- tambien verificar que la linea no haya vencido antes del otorgamiento del prestamo
        IF v_fec_ini_pt IS NOT NULL THEN
         IF  v_nro_linea IS NOT NULL THEN
             IF v_fec_ini_pt >= v_fec_autorizacion AND v_fec_ini_pt <= v_fec_vencimiento THEN
             v_fec_pos_linea := 'N';
             ELSIF v_fec_ini_pt > v_fec_autorizacion AND v_fec_ini_pt > v_fec_vencimiento THEN
               v_fec_pos_linea := 'S';
             ELSIF v_fec_ini_pt <  v_fec_autorizacion THEN
             v_fec_pos_linea := 'S';
             END IF;
           ELSE
             v_fec_pos_linea := 'S';
           END IF;
         ELSE
          v_fec_pos_linea := 'N';
          V_PY_AUTORIZADOR   := NULL;
          V_FEC_AUTORIZACION := NULL;
          V_NRO_LINEA        := NULL;
         END IF;
         IF  v_fec_pos_linea = 'S' THEN
           --en caso que entre por diferencia de fecha
            v_nro_linea        := NULL;
            v_py_autorizador   := NULL;
             IF rec(i).cod_modulo = 6 THEN
               v_fec_autorizacion := v_fec_ini_pt;
                 BEGIN -- obtenemos usuario autorizador que liquidó el prestamo
                   SELECT g.cod_usuario
                     INTO v_py_autorizador
                     FROM pr_sol_gestiones   g,
                          pr_solicitudes     p
                    WHERE p.nro_solicitud = g.nro_solicitud
                      AND g.nro_solicitud = v_nro_sol_linea
                      AND g.estado = 'L'
                      AND g.fecha = (SELECT MAX(g1.fecha)
                                       FROM pr_sol_gestiones g1,
                                            pr_solicitudes   p1
                                      WHERE p1.nro_solicitud = g1.nro_solicitud
                                        AND g1.nro_solicitud = g.nro_solicitud
                                        AND g1.estado = 'L');
                 EXCEPTION
                   WHEN OTHERS THEN
                     NULL;
                 END;
             ELSIF rec(i).cod_modulo = 5 OR (rec(i).COD_MODULO = '15' AND rec(i).cod_modalidad = '151' ) THEN
               v_fec_autorizacion := v_fec_ini_pt;
                 Begin
                   SELECT g.cod_usuario
                     INTO v_py_autorizador
                     FROM ta_sol_gestiones g,
                          ta_solicitudes   p
                    WHERE p.nro_solicitud = g.nro_solicitud
                      AND g.nro_solicitud = v_nro_sol_linea
                      AND g.cod_estado In ('APR')
                      AND g.fecha = (SELECT MAX(g1.fecha)
                                       FROM ta_sol_gestiones g1,
                                            ta_solicitudes   p1
                                      WHERE p1.nro_solicitud = g1.nro_solicitud
                                        AND g1.nro_solicitud = g.nro_solicitud
                                        AND g1.cod_estado In ('APR'));
                 Exception
                   When Others Then
                     NULL;
                 End;
             ELSIF rec(i).cod_modulo = '15' AND rec(i).cod_modalidad = 152 THEN
               --busca cta origen
                 BEGIN
                   SELECT v.nro_cta_origen
                     INTO v_cta_ori_cta_cte
                     FROM ov_cta_vencidas v
                    WHERE v.nro_cuenta = rec(i).nro_cuenta;
                 EXCEPTION
                   WHEN OTHERS THEN
                     v_cta_ori_cta_cte := NULL;
                 END;
                 IF v_cta_ori_cta_cte IS NOT NULL THEN
                   --verifica la si la cta tiene sobregiro y luego busca la linea
                   BEGIN
                     SELECT 'S'
                       INTO v_tiene_sobregiro
                       FROM cc_cta_corrientes T
                      WHERE T.NRO_CUENTA = v_cta_ori_cta_cte
                        AND T.ACU_SOBREGIRO = 'S';
                   EXCEPTION
                    WHEN OTHERS THEN
                      v_tiene_sobregiro := 'N';
                   END;
                   IF v_tiene_sobregiro = 'S' THEN
                     --busco la linea
                     BEGIN
                       SELECT h.nro_linea, nvl(h.cod_usu_autoriza, h.usu_insercion), nvl(h.fec_inicio, h.fec_insercion)
                         INTO v_nro_linea, v_py_autorizador, v_fec_autorizacion
                         FROM cc_lin_sobregiros_his h
                        WHERE h.nro_cuenta = v_cta_ori_cta_cte
                          AND h.nro_linea IS NOT NULL;
                     EXCEPTION
                       WHEN no_data_found THEN
                         BEGIN
                           SELECT h1.nro_linea, nvl(h1.cod_usu_autoriza, h1.usu_insercion), nvl(h1.fec_inicio, h1.fec_insercion)
                             INTO v_nro_linea, v_py_autorizador, v_fec_autorizacion
                             FROM cc_lin_sobregiros h1
                            WHERE h1.nro_cuenta = v_cta_ori_cta_cte
                             AND h1.nro_linea IS NOT NULL;
                         EXCEPTION
                           WHEN OTHERS THEN
                            NULL;
                         END;
                       WHEN OTHERS THEN
                         NULL;
                     END;
                   END IF;
                 END IF;
             END IF;
         END IF;
       END IF;
       IF v_py_autorizador IS NOT NULL THEN
          v_py_nombre :=fue_obt_nom_usuario(v_py_autorizador);
       END IF;
     END IF;
     --**********************************************************************************
      --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
      -- Requerimiento: CNFAIRUNO-3.
      -- Fecha: 22/09/2014.
  -- ARCHIVO PREVISON_DET
if nvl(rec(i).query_10,'N') = 'N' and v_nro_cuenta is null then
  v_line := to_char(rec(i).RIESGO)||chr(9)||replace(to_char(rec(i).NOMBRE_PER),chr(10),'')||chr(9)||to_char(rec(i).DOC)||chr(9)||replace(to_char(rec(i).NRO_DOC),chr(10),'')||chr(9)||
            to_char(rec(i).CAT_RIESGO)||chr(9)||to_char(rec(i).CAT_CRC)||chr(9)||to_char(rec(i).OFI)||chr(9)||to_char(rec(i).OFICINA)||chr(9)||rec(i).ofi_usu ||chr(9)||
            to_char(rec(i).COD_USU_OFICIAL)||chr(9)||to_char(rec(i).NOMBRE_USU)||chr(9)||to_char(rec(i).BANCA)||chr(9)||to_char(rec(i).CAT_SUBJETIVA)||chr(9)||
            to_char(rec(i).GRU_ECO)||chr(9)||to_char(rec(i).GRU_ECO_INFORMADO)||chr(9)||to_char(rec(i).GRU_ECO_BCP)||chr(9)||to_char(rec(i).CAT_GRU_ECONOMICO)||chr(9)||
            to_char(v_sub_cat_individual)||chr(9)||to_char(rec(i).SUB_CAT_GRUPO)||chr(9)||to_char(v_cat_bcp)||chr(9)||
            to_char(nvl(v_gru_eco_bcp_1,' '))||chr(9)||to_char(nvl(v_gru_eco_bcp_2,' '))||chr(9)||to_char(nvl(v_gru_eco_bcp_3,' '))||chr(9)||
            to_char(nvl(v_gru_eco_bcp_4,' '))||chr(9)||to_char(nvl(v_gru_eco_bcp_5,' '))||chr(9)||to_char(nvl(v_grupo_eco_bcp,' '))||chr(9)||
            to_char(rec(i).CAT_SISTEMA)||chr(9)||
            to_char(rec(i).TOT_DEU_RSISTEMA,'999999999999D00')||chr(9)||to_char(rec(i).TOT_CON_RSISTEMA,'999999999999D00')||chr(9)||
            to_char(rec(i).TIPO)||chr(9)||to_char(rec(i).TIP_CLIENTE)||chr(9)||to_char(rec(i).RUBRO)||chr(9)||to_char(rec(i).COD_MODALIDAD)||chr(9)||
            to_char(rec(i).NRO_CUENTA)||chr(9)||v_sub_modalidad||chr(9)||v_desc_sub_modalidad||chr(9)||to_char(v_campana)||chr(9)||v_fec_inicio||chr(9)||to_char(rec(i).SALDO_INTERES)||chr(9)||to_char(rec(i).FECHA_INICIO_OPER)||chr(9)||to_char(rec(i).COD_MONEDA)||chr(9)||to_char(rec(i).COD_ESTADO)||chr(9)||to_char(rec(i).ESTADO)||chr(9)||
            to_char(rec(i).TOT_DEU_REAL,'999999999999D00')||chr(9)||to_char(rec(i).TOT_DEU_CONTINGENTE,'999999999999D00')||chr(9)||
            to_char(rec(i).DEV_NO_COBRADO,'999999999999D00')||chr(9)||
            to_char(rec(i).CAPITAL,'999999999999D00')||chr(9)||to_char(rec(i).TOT_DEUDA,'999999999999D00')||chr(9)||to_char(rec(i).RIE_DES_PRV_ANT_GARANTIA,'999999999999D00')||chr(9)||to_char(rec(i).RIE_GAR_NOCUBIERTO,'999999999999D00')||chr(9)||
            to_char(rec(i).TOT_GAR_COMPUTABLES,'999999999999D00')||chr(9)||
            to_char(rec(i).TOT_PREVISION,'999999999999D00')||chr(9)||to_char(rec(i).CAT_AUTOMATICA)||chr(9)||to_char(rec(i).CAT_RENOVACIONES)||chr(9)||
            to_char(rec(i).DIA_ATRASO)||chr(9)||to_char(rec(i).SDO_MORA)||chr(9)||to_char(rec(i).TIP_DESTINO)||chr(9)||to_char(rec(i).DESTINO)||chr(9)||to_char(rec(i).COD_SEC_CREDITO)||chr(9)||
            to_char(rec(i).DESC_SEC_CRD)||chr(9)||to_char(rec(i).TIP_RENOVACION)||chr(9)||to_char(rec(i).MTO_MORA,'999999999999D00')||chr(9)||
            to_char(rec(i).SECT_PRESTAMO)||chr(9)||to_char(rec(i).DESC_SECT_PRESTAMO)||chr(9)||to_char(rec(i).prim_prevision,'999999999999D00')||chr(9)||
            to_char(rec(i).seg_prevision,'999999999999D00')||chr(9)||v_cta_origen||chr(9)||v_fec_ini_origen||chr(9)||to_char(v_campana_origen)||chr(9)||v_sub_afinidad_origen||chr(9)||v_desc_sub_afinidad_origen||chr(9)||
            to_char(rec(i).capital_inicial,'999999999999D00')||chr(9)||rec(i).act_primaria||chr(9)||rec(i).des_act_primaria||chr(9)||
            /*V_CAN_PT*/ v_canal||CHR(9)||v_des_canal||CHR(9)||V_MES_FACTURACION||CHR(9)||V_ANO_FACTURACION||CHR(9)|| V_MTO_FACTURACION||CHR(9)||
            V_MES_RATING||CHR(9)||V_ANO_RATING||CHR(9)||V_RATING||CHR(9)||
            V_MES_HATOS||CHR(9)||V_ANO_HATOS||CHR(9)||V_CAN_HATOS||CHR(9)||
            V_DES_TIP_CULTIVO||CHR(9)||V_NRO_HEC_CULTIVADAS||CHR(9)||V_MES||CHR(9)||V_ANHO||CHR(9)||
            /*RE DE-1622*/
            V_PY_AUTORIZADOR||CHR(9)||V_PY_NOMBRE||CHR(9)||V_FEC_AUTORIZACION||CHR(9)||V_NRO_LINEA||CHR(9)||
            v_usu_promotor||CHR(9)||v_des_promotor||CHR(9)|| -- DE-2044
            v_cod_usu_apr_cuenta ||CHR(9)|| v_nom_usu_apr_cuenta||CHR(9)|| v_fec_apr_cuenta||CHR(9)|| -- DE-2594 PyR MAY/2017 NAF
            v_ref_rrr_holding; -- COREADRRR-1
            
            -- DE-2594 PyR MAY/2017 NAF - Inserta PREVISON_DET en tabla temporal GE_DAT_PRE_DET_TMP
            Begin
                insert into GE_DAT_PRE_DET_TMP values(rec(i).RIESGO,replace(to_char(rec(i).NOMBRE_PER),chr(10),''),rec(i).DOC,
                       replace(to_char(rec(i).NRO_DOC),chr(10),''),rec(i).CAT_RIESGO,rec(i).CAT_CRC,rec(i).OFI,rec(i).OFICINA,
                       rec(i).ofi_usu,rec(i).COD_USU_OFICIAL,rec(i).NOMBRE_USU,rec(i).BANCA,rec(i).CAT_SUBJETIVA,rec(i).GRU_ECO,
                       rec(i).GRU_ECO_INFORMADO,rec(i).GRU_ECO_BCP,rec(i).CAT_GRU_ECONOMICO,v_sub_cat_individual,
                       rec(i).SUB_CAT_GRUPO,v_cat_bcp,v_gru_eco_bcp_1,v_gru_eco_bcp_2,v_gru_eco_bcp_3,v_gru_eco_bcp_4,
                       v_gru_eco_bcp_5,v_grupo_eco_bcp,rec(i).CAT_SISTEMA,rec(i).TOT_DEU_RSISTEMA,rec(i).TOT_CON_RSISTEMA,
                       rec(i).TIPO,rec(i).TIP_CLIENTE,rec(i).RUBRO,rec(i).COD_MODALIDAD,rec(i).NRO_CUENTA,v_sub_modalidad,
                       v_desc_sub_modalidad,v_campana,v_fec_inicio,rec(i).SALDO_INTERES,rec(i).FECHA_INICIO_OPER,
                       rec(i).COD_MONEDA,rec(i).COD_ESTADO,rec(i).ESTADO,rec(i).TOT_DEU_REAL,rec(i).TOT_DEU_CONTINGENTE,
                       rec(i).DEV_NO_COBRADO,rec(i).CAPITAL,rec(i).TOT_DEUDA,rec(i).RIE_DES_PRV_ANT_GARANTIA,rec(i).RIE_GAR_NOCUBIERTO,
                       rec(i).TOT_GAR_COMPUTABLES,rec(i).TOT_PREVISION,rec(i).CAT_AUTOMATICA,rec(i).CAT_RENOVACIONES,
                       rec(i).DIA_ATRASO,rec(i).SDO_MORA,rec(i).TIP_DESTINO,rec(i).DESTINO,rec(i).COD_SEC_CREDITO,rec(i).DESC_SEC_CRD,
                       rec(i).TIP_RENOVACION,rec(i).MTO_MORA,rec(i).SECT_PRESTAMO,rec(i).DESC_SECT_PRESTAMO,rec(i).prim_prevision,
                       rec(i).seg_prevision,v_cta_origen,v_fec_ini_origen,v_campana_origen,v_sub_afinidad_origen,
                       v_desc_sub_afinidad_origen,rec(i).capital_inicial,rec(i).act_primaria,rec(i).des_act_primaria,
                       v_canal,v_des_canal,V_MES_FACTURACION,V_ANO_FACTURACION, V_MTO_FACTURACION,V_MES_RATING,
                       V_ANO_RATING,V_RATING,V_MES_HATOS,V_ANO_HATOS,V_CAN_HATOS,V_DES_TIP_CULTIVO,V_NRO_HEC_CULTIVADAS,
                       V_MES,V_ANHO,V_PY_AUTORIZADOR,V_PY_NOMBRE,V_FEC_AUTORIZACION,V_NRO_LINEA,v_usu_promotor,
                       v_des_promotor,v_cod_usu_apr_cuenta,v_nom_usu_apr_cuenta,v_fec_apr_cuenta, v_ref_rrr_holding);
                commit;
            exception
                when others then
                  raise_application_error(-20000,'pr_previ_det - al insertar cta: ' || rec(i).nro_cuenta ||
                                                 ' en GE_DAT_PRE_DET_TMP: '||sqlerrm);
            end;
            
   IF LENGTH(v_buffer) + v_eollen + LENGTH(v_line) <= v_maxline THEN
      v_buffer := v_buffer || v_eol || v_line;
   ELSE
     IF v_buffer IS NOT NULL THEN
       --Escribes la linea en el fichero
       UTL_FILE.PUT_LINE(v_file, v_buffer);
     END IF;
      v_buffer := v_line;
   END IF;
            
-- RE DE-1172 *******************************************************
-- ARCHIVO INF_CARTERA_TOTAL
  v_line2 := to_char(rec(i).RIESGO)                                ||chr(9)|| replace(to_char(rec(i).NOMBRE_PER),chr(10),'')   ||chr(9)|| to_char(rec(i).DOC)                          ||chr(9)|| replace(to_char(rec(i).NRO_DOC),chr(10),'') ||chr(9)|| to_char(rec(i).CAT_RIESGO)                            ||chr(9)||
             to_char(rec(i).CAT_CRC)                               ||chr(9)|| to_char(rec(i).OFI)                              ||chr(9)|| to_char(rec(i).OFICINA)                      ||chr(9)|| rec(i).ofi_usu                              ||chr(9)|| to_char(rec(i).NOMBRE_USU)                            ||chr(9)||
             to_char(rec(i).BANCA)                                 ||chr(9)|| to_char(rec(i).CAT_SUBJETIVA)                    ||chr(9)|| to_char(rec(i).GRU_ECO)                      ||chr(9)|| to_char(rec(i).CAT_SISTEMA)                 ||chr(9)|| to_char(rec(i).TOT_DEU_RSISTEMA,'999999999999D00')    ||chr(9)||
             to_char(rec(i).TOT_CON_RSISTEMA,'999999999999D00')    ||chr(9)|| to_char(rec(i).TIP_CLIENTE)                      ||chr(9)|| fug_obt_des_segmento(rec(i).cod_seg_cliente) ||chr(9)|| to_char(rec(i).RUBRO)                       ||chr(9)|| to_char(rec(i).COD_MODALIDAD)                         ||chr(9)||
             to_char(rec(i).NRO_CUENTA)                            ||chr(9)|| v_sub_modalidad                               ||chr(9)|| v_desc_sub_modalidad                      ||chr(9)|| fug_obt_des_modalidad(rec(i).cod_modalidad) ||chr(9)|| FUG_OBT_DES_CANAL(v_canal)                         ||chr(9)||
             v_usu_promotor                                     ||chr(9)|| fue_obt_nom_usuario(v_usu_promotor)           ||chr(9)|| v_des_concesionaria                       ||chr(9)|| to_char(v_campana)                       ||chr(9)|| v_fec_inicio                                       ||chr(9)||
             to_char(rec(i).SALDO_INTERES)                         ||chr(9)|| to_char(rec(i).FECHA_INICIO_OPER)                ||chr(9)|| to_char(rec(i).COD_MONEDA)                   ||chr(9)|| to_char(rec(i).ESTADO)                      ||chr(9)|| to_char(rec(i).TOT_DEU_REAL,'999999999999D00')        ||chr(9)||
             to_char(rec(i).TOT_DEU_CONTINGENTE,'999999999999D00') ||chr(9)|| to_char(rec(i).DEV_NO_COBRADO,'999999999999D00') ||chr(9)|| to_char(rec(i).CAPITAL,'999999999999D00')    ||chr(9)|| to_char(rec(i).TOT_DEUDA,'999999999999D00') ||chr(9)|| to_char(rec(i).TOT_PREVISION,'999999999999D00')       ||chr(9)||
             to_char(rec(i).CAT_RENOVACIONES)                      ||chr(9)|| to_char(rec(i).DIA_ATRASO)                       ||chr(9)|| to_char(rec(i).SDO_MORA)                     ||chr(9)|| to_char(rec(i).DESTINO)                     ||chr(9)|| to_char(rec(i).COD_SEC_CREDITO)                       ||chr(9)||
             to_char(rec(i).DESC_SEC_CRD)                          ||chr(9)|| to_char(rec(i).TIP_RENOVACION)                   ||chr(9)|| to_char(rec(i).MTO_MORA,'999999999999D00')   ||chr(9)|| to_char(rec(i).SECT_PRESTAMO)               ||chr(9)|| to_char(rec(i).DESC_SECT_PRESTAMO)                    ||chr(9)||
             v_usu_liq                                          ||chr(9)|| fue_obt_nom_usuario(v_usu_liq);
   IF LENGTH(v_buffer2) + v_eollen + LENGTH(v_line2) <= v_maxline THEN
     v_buffer2 := v_buffer2 || v_eol || v_line2;
   ELSE
     IF v_buffer2 IS NOT NULL THEN
       --Escribes la linea en el fichero
       UTL_FILE.PUT_LINE(v_file2, v_buffer2);
     END IF;
     v_buffer2 := v_line2;
   END IF;
end if;
   --- PIPROINTE-285 Riesgos
   --- Anexo 1 
   --- Reportes de Gestión requeridos por GNB Sudameris Colombia
   --- (Query 9)
   if nvl(rec(i).cod_modulo,1) = 5 and
      nvl(fug_obt_pardinamico('GEN_TAR_PREVISION',5,rec(i).cod_modalidad),'S') = 'N' then
      goto siguiente;
   elsif nvl(rec(i).cod_modulo,1) = 15 then
      v_cta_origen := null;
      begin
         select v.nro_cta_origen
           into v_cta_origen
           from ov_cta_vencidas v
          where v.nro_cuenta = rec(i).nro_cuenta;
      exception
         when others then
            v_cta_origen := Null;
      end;
      if nvl(lf_obt_cta_excluida(v_cta_origen),'N') = 'S' then
         goto siguiente;
      end if;
   end if;
   if nvl(lf_obt_cta_excluida(rec(i).nro_cuenta),'N') = 'S' then
      goto siguiente;
   end if;
   ---
   v_pais_bt := pag_mig.fu_obt_cod_bantotal(rec(i).cod_pais,'BA_PAISES');
   v_tipo_doc_bt := pag_mig.fu_obt_cod_bantotal(rec(i).cod_tip_documento,'BA_TIP_DOCUMENTOS');
   if nvl(v_tipo_doc_bt,'#N/A') = '#N/A' then
      v_tipo_doc_bt := '2';
   end if;
   /*
   || H. Tipo Deudor: Se debe colocar el tipo de deudor según Resolución 1.
   || 01 para grandes deudores
   || 02 para pequeños y medianos deudores
   || 03 para consumo
   || 04 para microcréditos.
   ||
   || En ITGF: Tipo de cliente
   || R = Grandes deudores relacionados a la Entidad,
   || M = Grandes Deudores Comerciales,
   || N = Pequeños deudores relacionados a la Entidad,
   || C = Pequeños deudores comerciales,
   || P = Deudores Personales,
   || T = Micro creditos
   */
   /*
   -- slresfo1
   -- Resolucion Nro 37
   -- Formato 1 (Resumen)
    (CASE
       WHEN sb_clientes.tipo IN ('G', 'M', 'R') THEN
        1
       WHEN sb_clientes.tipo IN ('N', 'C') THEN
        4
       WHEN sb_clientes.tipo IN ('T') THEN
        5
       WHEN sb_clientes.tipo IN ('P') THEN
        2
       WHEN sb_clientes.tipo IN ('V') THEN
        3
       ELSE
        4
    END) tip_destino,
   */
   v_modulo := ' ';
   begin
      select t.val_cod_bantotal
        into v_modulo
        from mi_tab_parametricas t 
       where t.nom_tab_itgf = 'MODULOS_PRODUCTOS'
         and t.nom_col_codigo = 'COD_MODULO'
         and t.val_cod_itgf = rec(i).cod_modulo
         and t.nom_col_codigo2 = 'COD_MODALIDAD'
         and t.val_cod_itgf2 = rec(i).cod_modalidad;
   exception
      when others then
         v_modulo := ' ';
   end;
   if rec(i).tipo in ('G','R','M') then
      v_tip_deudor := '01';
   elsif rec(i).tipo in ('N','C') then
      v_tip_deudor := '02';--'04';
   elsif rec(i).tipo = 'T' then
      v_tip_deudor := '04';--'05';
   elsif rec(i).tipo = 'P' then
      v_tip_deudor := '03';--'02';
   elsif rec(i).tipo = 'V' then
      v_tip_deudor := '03';
      v_modulo := '129';
   else
      v_tip_deudor := '04';
   end if;
   if v_tip_deudor is null then
      v_tip_deudor := '04';
   end if;
   if rec(i).tip_destino = 3 then
      v_modulo := '129';
   end if;
   /*
   || K. Actividad: Se debe colocar el código de actividad del cliente en referencia
   || (no se debe colocar el destino de la operación, sino que la actividad principal del cliente).
   || CIIU. ge_clientes.cod_rub_primario ==> rec(i).act_primaria
   */
   v_cod_rub_economico := null;
   v_act_bco_central   := null;
   --- para el caso que no sea igual al codigo del Banco Central
   if rec(i).cod_modulo = 5 or rec(i).cod_modalidad = 151 then
      v_cod_rub_economico := '970107';
   /*else
      if rec(i).cod_modulo = 15 then
         select max(d.cod_rub_economico)
           into v_cod_rub_economico
           from sb_crc_operaciones_det d
          where nvl(substr(d.nro_operacion,1,INSTR(d.nro_operacion,'#')-1),d.nro_operacion) = v_cta_origen;
      else
         select max(d.cod_rub_economico)
           into v_cod_rub_economico
           from sb_crc_operaciones_det d
          where nvl(substr(d.nro_operacion,1,INSTR(d.nro_operacion,'#')-1),d.nro_operacion) = rec(i).nro_cuenta;
      end if;
   end if;
   --- Casos de Actividad Primaria del Cliente nulo
   if v_cod_rub_economico is null then*/
      elsif rec(i).cod_modulo = 4 then
         begin
            select max(a.cod_rub_economico)
              into v_cod_rub_economico
              from cc_lin_sobregiros a
             where (a.nro_cuenta = rec(i).nro_cuenta or a.cod_persona = rec(i).riesgo)
               and a.estado = 'A';
         exception
            when others then
               v_cod_rub_economico := null;
         end;
         if v_cod_rub_economico is null then
            v_cod_rub_economico := '970108';         
         end if;
      /*elsif rec(i).cod_modulo = 5 then
         begin
            select a.cod_rub_economico
              into v_cod_rub_economico
              from ta_cta_tarjetas a
             where a.nro_cuenta = rec(i).nro_cuenta;
         exception
            when others then
               v_cod_rub_economico := null;
         end;*/
      elsif rec(i).cod_modulo = 6 then
         begin
            select a.cod_rub_economico
              into v_cod_rub_economico
              from pr_cta_prestamos a
             where a.nro_cuenta = rec(i).nro_cuenta;
         exception
            when others then
               v_cod_rub_economico := null;
         end;
      elsif rec(i).cod_modulo = 8 then
         begin
            select a.cod_rub_economico
              into v_cod_rub_economico
              from cx_cta_exportaciones a
             where a.nro_cuenta = rec(i).nro_cuenta;
         exception
            when no_data_found then
               begin
                  select a.cod_rub_economico
                    into v_cod_rub_economico
                    from cx_cta_importaciones a
                   where a.nro_cuenta = rec(i).nro_cuenta;
               exception
                  when no_data_found then
                     begin
                        select a.cod_rub_economico
                          into v_cod_rub_economico
                          from cx_fianzas a
                         where a.nro_cuenta = rec(i).nro_cuenta;
                     exception
                        when others then
                           v_cod_rub_economico := null;
                     end;
                  when others then
                     v_cod_rub_economico := null;
               end;
            when others then
               v_cod_rub_economico := null;
         end;
      elsif rec(i).cod_modulo = 10 then
         begin
            select a.cod_rub_economico
              into v_cod_rub_economico
              from md_cta_documentos a
             where a.nro_cuenta = rec(i).nro_cuenta;
         exception
            when others then
               v_cod_rub_economico := null;
         end;
      --elsif rec(i).cod_modulo = 15 then
      elsif rec(i).cod_modalidad = 152 then
         begin
            select a.cod_rub_economico
              into v_cod_rub_economico
              from ov_cta_vencidas a
             where a.nro_cuenta = rec(i).nro_cuenta;
         exception
            when others then
               v_cod_rub_economico := null;
         end;
      end if;
   --else
   --   rec(i).act_primaria := v_cod_rub_economico;
   --end if;
   if v_cod_rub_economico is null then
      if rec(i).cod_modulo = 15 then
         select max(d.cod_rub_economico)
           into v_cod_rub_economico
           from sb_crc_operaciones_det d
          where nvl(substr(d.nro_operacion,1,INSTR(d.nro_operacion,'#')-1),d.nro_operacion) = v_cta_origen;
      else
         select max(d.cod_rub_economico)
           into v_cod_rub_economico
           from sb_crc_operaciones_det d
          where nvl(substr(d.nro_operacion,1,INSTR(d.nro_operacion,'#')-1),d.nro_operacion) = rec(i).nro_cuenta;
      end if;
   end if;
   /*if rec.act_primaria is null then
      if rec.cod_modulo = 4 or rec.cod_modalidad = 152 then
         rec.act_primaria := '970108';
      elsif rec.cod_modulo = 5 or rec.cod_modalidad = 151 then
         rec.act_primaria := '970107';
      end if;
   end if;*/
   if v_cod_rub_economico is null then
      v_cod_rub_economico := rec(i).act_primaria;
   end if;
   --- para el caso que no sea igual al codigo del Banco Central
   if v_cod_rub_economico is not null then
      begin
         select a.cod_bco_central
           into v_act_bco_central
           from pr_rub_economicos a
          where a.cod_rub_economico = v_cod_rub_economico;
      exception
         when others then
            v_act_bco_central := null;
      end;
   else
      v_act_bco_central := null;
   end if;
   
   /*
   || N. Cat. Resultante: Se debe colocar la categoría final resultante del cliente en referencia.
   ||
   || Se debe traer la categoria del grupo (siguiente fila),
   || en caso que no tenga Cat Grupo traer la categoria automática de la operación
   || y en caso que no tenga se debe traer la de riesgos.
   || Incluir en la definición "Categoria" conforme mail de GNB
   ||
   || CAT_RESULTANTE: Debe ir en formato:
   || "Categoria 1", "Categoria 1a", "Categoria 1b",
   || "Categoria 2", "Categoria 3", "Categoria 4", "Categoria 5", "Categoria 6".
   */
   v_categoria := nvl(rec(i).cat_riesgo,1);
   if v_categoria is null then
      v_categoria := 1;
   end if;
   if v_categoria = 1 then
      if nvl(lf_obt_cat_prevision(rec(i).riesgo),1) = 1.1 then
         v_cat_resultante := 'Categoria 1a';
      elsif nvl(lf_obt_cat_prevision(rec(i).riesgo),1) = 1.2 then
         v_cat_resultante := 'Categoria 1b';
      else
         v_cat_resultante := 'Categoria 1';
      end if;
   elsif v_categoria = 1.1 then
      v_cat_resultante := 'Categoria 1a';
   elsif v_categoria = 1.2 then
      v_cat_resultante := 'Categoria 1b';
   elsif v_categoria = 2 then
      v_cat_resultante := 'Categoria 2';
   elsif v_categoria = 3 then
      v_cat_resultante := 'Categoria 3';
   elsif v_categoria = 4 then
      v_cat_resultante := 'Categoria 4';
   elsif v_categoria = 5 then
      v_cat_resultante := 'Categoria 5';
   elsif v_categoria = 6 then
      v_cat_resultante := 'Categoria 6';
   else
      v_cat_resultante := 'Categoria 1';
   end if;
   if v_cat_resultante is null then
      v_cat_resultante := 'Categoria 1';
   end if;
   /*
   || O. Cat. Subjetiva: Se debe colocar la categoría subjetiva del cliente si lo tuviera.
   || CAT_SUBJETIVA: Debe ir en el mismo formato que la CAT_RESULTANTE.
   || Para los casos que no tienen categoría subjetiva, se deja vacío.
   */
   if rec(i).cat_subjetiva is null then
      v_cat_subjetiva := null;
   elsif rec(i).cat_subjetiva = 1 then
      v_cat_subjetiva := null;
   elsif rec(i).cat_subjetiva = 2 then
      v_cat_subjetiva := 'Categoria 2';
   elsif rec(i).cat_subjetiva = 3 then
      v_cat_subjetiva := 'Categoria 3';
   elsif rec(i).cat_subjetiva = 4 then
      v_cat_subjetiva := 'Categoria 4';
   elsif rec(i).cat_subjetiva = 5 then
      v_cat_subjetiva := 'Categoria 5';
   elsif rec(i).cat_subjetiva = 6 then
      v_cat_subjetiva := 'Categoria 6';
   else
      v_cat_subjetiva := null;
   end if;
   if v_cat_subjetiva is null then
      v_cat_subjetiva := ' ';
   end if;
   ---
   if rec(i).cat_automatica is null then
      rec(i).cat_automatica := 1;
   end if;
   if rec(i).cat_automatica = 1 then
      v_des_cat_crc := 'Categoria 1';
   elsif rec(i).cat_automatica = 1.1 then
      v_des_cat_crc := 'Categoria 1a';
   elsif rec(i).cat_automatica = 1.2 then
      v_des_cat_crc := 'Categoria 1b';
   elsif rec(i).cat_automatica = 2 then
      v_des_cat_crc := 'Categoria 2';
   elsif rec(i).cat_automatica = 3 then
      v_des_cat_crc := 'Categoria 3';
   elsif rec(i).cat_automatica = 4 then
      v_des_cat_crc := 'Categoria 4';
   elsif rec(i).cat_automatica = 5 then
      v_des_cat_crc := 'Categoria 5';
   elsif rec(i).cat_automatica = 6 then
      v_des_cat_crc := 'Categoria 6';
   else
      v_des_cat_crc := 'Categoria 1';
   end if;
   if v_des_cat_crc is null then
      v_des_cat_crc := 'Categoria 1';
   end if;
   ---
   if rec(i).cat_de_persona is null then
      rec(i).cat_de_persona := 1;
   end if;
   if rec(i).cat_de_persona = 1 then
      if nvl(lf_obt_cat_prevision(rec(i).riesgo),1) = 1.1 then
         v_des_cat_ind := 'Categoria 1a';
      elsif nvl(lf_obt_cat_prevision(rec(i).riesgo),1) = 1.2 then
         v_des_cat_ind := 'Categoria 1b';
      else
         v_des_cat_ind := 'Categoria 1';
      end if;         
   elsif rec(i).cat_de_persona = 1.1 then
      v_des_cat_ind := 'Categoria 1a';
   elsif rec(i).cat_de_persona = 1.2 then
      v_des_cat_ind := 'Categoria 1b';
   elsif rec(i).cat_de_persona = 2 then
      v_des_cat_ind := 'Categoria 2';
   elsif rec(i).cat_de_persona = 3 then
      v_des_cat_ind := 'Categoria 3';
   elsif rec(i).cat_de_persona = 4 then
      v_des_cat_ind := 'Categoria 4';
   elsif rec(i).cat_de_persona = 5 then
      v_des_cat_ind := 'Categoria 5';
   elsif rec(i).cat_de_persona = 6 then
      v_des_cat_ind := 'Categoria 6';
   else
      v_des_cat_ind := 'Categoria 1';
   end if;   
   if v_des_cat_ind is null then
      v_des_cat_ind := 'Categoria 1';
   end if;
   ---
   if rec(i).CAT_RENOVACIONES = 1 then
      v_des_cat_ren := 'Categoria 1';
   elsif rec(i).CAT_RENOVACIONES = 1.1 then
      v_des_cat_ren := 'Categoria 1a';
   elsif rec(i).CAT_RENOVACIONES = 1.2 then
      v_des_cat_ren := 'Categoria 1b';
   elsif rec(i).CAT_RENOVACIONES = 2 then
      v_des_cat_ren := 'Categoria 2';
   elsif rec(i).CAT_RENOVACIONES = 3 then
      v_des_cat_ren := 'Categoria 3';
   elsif rec(i).CAT_RENOVACIONES = 4 then
      v_des_cat_ren := 'Categoria 4';
   elsif rec(i).CAT_RENOVACIONES = 5 then
      v_des_cat_ren := 'Categoria 5';
   elsif rec(i).CAT_RENOVACIONES = 6 then
      v_des_cat_ren := 'Categoria 6';
   else
      v_des_cat_ren := 'Categoria 1';
   end if;
   ---
   select max(x.fec_mod_informacion)
     into v_fec_cat_sub
     from GE_CLI_INFORMACIONES x
    where x.cod_persona = rec(i).riesgo
      and x.informacion = 'CATEGORIA'
      and x.dat_informacion > 1;
   --- Atender
   v_sal_cap_cont  := 'N';
   v_sal_exceso_mo := 0;
   v_cotizacion := fug_obt_cotizacion(rec(i).cod_moneda);
   ---
   if nvl(rec(i).query_10,'N') in ('M','B','C','P','O') then
      v_sal_capital_mo := rec(i).capital;
      v_mto_cont_mo    := 0;
   elsif rec(i).cod_modulo = 8 then
      begin
        select e.porcentaje, e.por_calculado
          into v_por_prevision, v_por_prev_calc
          from cx_previsiones e
         where e.nro_cuenta = rec(i).nro_cuenta;
      exception
         when others then
            v_por_prevision := 0;
            v_por_prev_calc := 0;
      end;         
      ---
      begin
         select a.mto_utilizado, a.monto
           into v_sal_capital_mo, v_mto_cont_mo
           from cx_cta_exportaciones a
          where a.nro_cuenta = rec(i).nro_cuenta;
      exception
         when no_data_found then
            begin
               select nvl(x.sal_utilizado,0), nvl(a.saldo,0)
                 into v_sal_capital_mo, v_mto_cont_mo
                 from cx_cta_importaciones a,
                    ( SELECT nro_cuenta cuenta, /*fec_vencimiento,*/ -- DYDMR-2455 -- CN:09/2015 - No se utiliza y ocasiona duplicacion de registros
                        SUM(saldo) sal_utilizado
                       FROM cx_embarques
                      WHERE nro_cuenta = rec(i).nro_cuenta
                      GROUP BY nro_cuenta /*, fec_vencimiento*/ ) x
                where a.nro_cuenta = x.cuenta (+)
                  and a.nro_cuenta = rec(i).nro_cuenta;
            exception
               when no_data_found then
                  begin
                     select 0, a.monto
                       into v_sal_capital_mo, v_mto_cont_mo
                       from cx_fianzas a
                      where a.nro_cuenta = rec(i).nro_cuenta;
                  exception
                     when others then
                        v_sal_cap_cont := 'E';
                  end;
               when others then
                  v_sal_cap_cont := 'E';
            end;
         when others then
            v_sal_cap_cont := 'E';
      end;
      if v_sal_cap_cont = 'E' then
         v_sal_capital_mo := rec(i).capital;
         v_mto_cont_mo    := rec(i).tot_deu_contingente;
         if rec(i).cod_moneda = v_cod_mon_local then
            v_mto_cont_mo := v_mto_cont_ml;
         else
            v_mto_cont_mo := v_mto_cont_ml / v_cotizacion;
         end if;      
      end if;
      if v_sal_capital_mo > 0 then
         v_sal_exceso_mo  := nvl(v_mto_cont_mo,0) - nvl(v_sal_capital_mo,0);
         v_mto_cont_mo    := nvl(v_sal_capital_mo,0);
         v_sal_capital_mo := 0;
      end if;
      v_sal_cap_cont := 'X';
   elsif rec(i).cod_modulo in (10,15) then
      v_sal_capital_ml := rec(i).capital;
      if rec(i).cod_moneda = v_cod_mon_local then
         v_sal_capital_mo := v_sal_capital_ml;
         v_mto_cont_mo    := v_mto_cont_ml;
      else
         v_sal_capital_mo := v_sal_capital_ml / v_cotizacion;
         v_mto_cont_mo    := v_mto_cont_ml / v_cotizacion;
      end if;      
   elsif nvl(rec(i).query_10,'N') = 'L' then
      v_sal_capital_mo := rec(i).capital;
      if rec(i).cod_moneda = v_cod_mon_local then
         v_sal_capital_ml := v_sal_capital_mo;
         v_mto_cont_ml    := v_mto_cont_mo;
      else
         v_sal_capital_ml := v_sal_capital_mo * v_cotizacion;
         v_mto_cont_ml    := v_mto_cont_mo * v_cotizacion;
      end if;      
   elsif nvl(rec(i).query_10,'N') = 'V' then
      v_sal_capital_ml := rec(i).capital;
      v_mto_cont_mo    := 0;
      if rec(i).cod_moneda = v_cod_mon_local then
         v_sal_capital_mo := v_sal_capital_ml;
      else
         v_sal_capital_mo := v_sal_capital_ml / v_cotizacion;
      end if;
   end if;
   --- si es TC o Sobregiro tiene monto contingente
   if nvl(v_sal_capital_mo,0) <= 0 and nvl(v_mto_cont_mo,0) <= 0 and rec(i).cod_modulo <> 4 then
      goto siguiente;
   elsif nvl(v_sal_capital_mo,0) = 0 and nvl(v_mto_cont_mo,0) = 0 and rec(i).cod_modulo = 4 then
      goto siguiente;
   elsif rec(i).cod_modulo = 5 then
      if nvl(v_sal_capital_mo,0) <= 0 and nvl(v_mto_cont_mo,0) > 0 then 
         if nvl(v_sal_capital_mo,0) < 0 then
            v_sal_capital_mo := 0;
         end if;
         v_sal_cap_cont   := 'O';
      else
         v_mto_cont_mo := nvl(v_mto_cont_mo,0) - nvl(v_sal_capital_mo,0);
         if nvl(v_mto_cont_mo,0) < 0 then
            v_mto_cont_mo := 0;
         end if;
      end if;
   elsif rec(i).cod_modulo = 4 then
      if nvl(v_sal_capital_mo,0) >= 0 and nvl(v_mto_cont_mo,0) > 0 and
         v_cod_ente is not null then
         if nvl(v_sal_capital_mo,0) > 0 then
            v_sal_capital_mo := 0;
         end if;
         v_sal_cap_cont := 'O';
      elsif nvl(v_sal_capital_mo,0) < 0 then
         v_sal_capital_mo := nvl(v_sal_capital_mo,0) * -1;
         if nvl(v_sal_capital_mo,0) > 0 and nvl(v_mto_cont_mo,0) > 0 then
            if nvl(v_sal_capital_mo,0) > nvl(v_mto_cont_mo,0) then
               v_sal_exceso_mo  := nvl(v_sal_capital_mo,0) - nvl(v_mto_cont_mo,0);
               v_sal_capital_mo := nvl(v_mto_cont_mo,0);
               v_mto_cont_mo    :=  0;
               v_sal_cap_cont   := 'S';
            else
               if v_cod_ente is not null then
                  v_mto_cont_mo := nvl(v_mto_cont_mo,0) - nvl(v_sal_capital_mo,0);
               else
                  v_mto_cont_mo := 0;
               end if;
            end if;
         end if;
      end if;
   end if;
   ---
   if nvl(v_sal_cap_cont,'N') = 'S' then
      v_cod_rubro := pab_asi.fu_obt_rub_contable(rec(i).nro_cuenta,'C','A');
   elsif nvl(v_sal_cap_cont,'N') = 'X' then
      v_cod_rubro := pab_asi.fu_obt_rub_contable(rec(i).nro_cuenta,'S','U');
      if v_cod_rubro is null then
         v_cod_rubro := lf_obt_rub_contable(rec(i).nro_cuenta,'S','U');
      end if;
      if v_cod_rubro is null then
         v_cod_rubro := lf_obt_rub_contable(rec(i).nro_cuenta,'S','A');
      end if;
   elsif nvl(rec(i).query_10,'N') in ('B','L','V') then
      v_cod_rubro := rec(i).rubro;
   elsif nvl(v_sal_cap_cont,'N') = 'O' then
      v_cod_rubro := pab_asi.fu_obt_rub_contable(rec(i).nro_cuenta, 'O');
      IF v_cod_rubro IS NULL THEN
         v_cod_rubro := fus_obt_cod_rubro(rec(i).nro_cuenta,'O');
      END IF;
   elsif nvl(rec(i).query_10,'N') = 'C' then
      v_cod_rubro := fus_obt_cod_rubro(rec(i).nro_cuenta,'X');
   elsif nvl(rec(i).query_10,'N') = 'I' then
      v_cod_rubro := lf_obt_rub_contable(rec(i).nro_cuenta,'C','I');
   elsif nvl(rec(i).query_10,'N') in ('P','O') then
      if rec(i).cod_moneda = v_cod_mon_local then
         v_cod_rubro := '510406890200299';
      else
         v_cod_rubro := '510406890200205';
      end if;
   else
      --- rubro de capital
      v_cod_rubro := lf_obt_rubro_inv(rec(i).nro_cuenta);
      if v_cod_rubro is null then
         v_ori_fondo_afd := 'N';
         if nvl(rec(i).query_10,'N') = 'N' and rec(i).cod_modulo = 6 then
            IF v_cod_ori_fondo <>
                fug_obt_pardinamico('COD_ORI_FON_DESEMB', NULL, NULL, rec(i).cod_moneda, NULL, NULL) and
                v_cod_ori_fondo <> fug_obt_pardinamico('COD_ORI_FON_DESEMB', 6, rec(i).cod_modalidad, rec(i).cod_moneda, NULL, NULL)THEN--DYDMR-9438
                --es fondos propios tomar el 100%
                IF v_por_ori_fondo > 0 AND v_por_ori_fondo <= 100 THEN
                   v_ori_fondo_afd := 'S';
                END IF;
            END IF;
         end if;
         ---
         if v_ori_fondo_afd = 'S' then
            v_cod_rubro := lf_obt_rub_contable(rec(i).nro_cuenta,'F');
         else
            v_cod_rubro := fus_obt_cod_rubro(rec(i).nro_cuenta,'C');
         end if;
      end if;
   end if;
   if v_cod_rubro is null then
      if rec(i).cod_modulo = 4 then
         --- rubro de capital
         v_cod_rubro := lf_obt_rubro_inv(rec(i).nro_cuenta);
         if v_cod_rubro is null then
            goto siguiente;
         end if;
         --- El rubro corresponde, 265 vencido, 269 gestion y 275 moroso
         v_sal_cap_cont   := 'N';
         v_sal_capital_mo := nvl(v_sal_capital_mo,0) + nvl(v_sal_exceso_mo,0);
         v_sal_exceso_mo  := 0;
         v_mto_cont_mo    := 0;
      else
         if rec(i).cod_modulo in (5,8) then
            goto siguiente;
         else
            v_cod_rubro := to_char(rec(i).RUBRO);
         end if;
      end if;
   end if;
   
   /*
   || las operaciones relacionadas al rubro ANTICIPOS AL PERSONAL
   || ya no forman parte de Cartera de Créditos,
   || no son informadas en los apartados de CRC ni de Resolución 1
   */
   if rec(i).cod_modalidad = 672 and substr(v_cod_rubro,1,2) = '15' then
      goto siguiente;
   end if;
   ---
   v_rub_bcp       := substr(v_cod_rubro, 1, 8) || substr(v_cod_rubro, 3, 1) || substr(v_cod_rubro, 9, 2);
   v_tip_operacion := substr(v_cod_rubro, 6, 3);
   v_titulo        := substr(v_cod_rubro, 1, 1);
   v_capitulo      := substr(v_cod_rubro, 2, 1);
   v_grupo         := substr(v_cod_rubro, 4, 2);
   v_subgrupo      := substr(v_cod_rubro, 9, 2);
   --- tipo de Operación pasiva 136 cuenta corriente no debe estar incluida dentro del query 10
   if rec(i).cod_modulo = 4 and nvl(v_tip_operacion,'0') = '136' then
      goto siguiente;
   end if;
   /*
   || BD. Segmento: Se debe colocar el segmento interno al que pertenece el cliente.
   || BE. Clasif. Interna: Se debe colocar la clasificación interna del cliente.
   ||
   || SEGMENTO: Debe ir si el cliente pertenece al segmento de personas, corporativo, pymes, etc.
   || (Si hubieren otros segmentos en el GNB PF, colocarlos).
   ||
   || El segmento se saca de la tabla dw_cli_segmentos
   || El segmento se genera mensualmente en el dw y luego se copia a esa tabla en itgf
   */
   begin  
      select case
             when sgto_acido_estructural = 20100 then 'INST_PRIVADAS'
				 WHEN sgto_acido_estructural = 20200 then 'INST_PUBLICAS'
				 WHEN sgto_acido_estructural = 20300 then 'INST_FINANCIERAS'
		       when sgto_acido_estructural = 30100 then 'EMPR_TOP'
		       when sgto_acido_estructural = 30200 then 'EMPR_SUPERIOR'
		       when sgto_acido_estructural = 30300 then 'EMPR_CLASICA'
		       when sgto_acido_estructural = 30400 then 'EMPR_MICRO'
		       when sgto_acido_estructural = 40100 then 'PYMES_TOP'
		       when sgto_acido_estructural = 40200 then 'PYMES_SUPERIOR'
		       when sgto_acido_estructural = 40300 then 'PYMES_CLASICO'
		       when sgto_acido_estructural = 60300 then 'MICRO_PYMES'
		       when sgto_acido_estructural = 80100 then 'HNWI'
		       when sgto_acido_estructural in (81000, 82000) then 'VIP'
		       when sgto_acido_estructural = 83000 then 'CLASICO RENTA ALTA'
		       when sgto_acido_estructural = 83100 then 'CLASICO RENTA BAJA'
   	       when sgto_acido_estructural = 84000 then	'TRANSACCIONAL RENTA ALTA'
		       when sgto_acido_estructural = 84100 then 'TRANSACCIONAL RENTA BAJA'
		       when sgto_acido_estructural IN (86000, 87000, 88000) then 'VALOR_CERO'
		       else 'SIN IDENTIFICAR'
             end des_acido, a.sgto_valor
        into v_seg_interno, v_segmento
        from dw_cli_segmentos a
       where a.nu_cte = lpad(rec(i).riesgo,8,'0')
         and a.fh_informacion = (select max(d.fh_informacion)
                                   from dw_cli_segmentos d
                                  where a.nu_cte = d.nu_cte);
   exception
      when others then
         v_segmento    := ' ';
         v_seg_interno := ' ';
   end;
   /*
   || BF: Tipo Préstamo: Se debe colocar los tipos de productos
   || (Prestamos, Compra de Cartera, CDA COMPRADOS PLAN PAGOS-USD, L/C a la Vista,
   || Carta de Crédito, Sobregiro, Cheq. Pend. Cobro,  Documentos Descontados, Tarjetas, etc.)
   ||     
   || TIPO_PRESTAMO: Debe ir si es un Préstamo, Tarjeta, Sobregiro, etc.
   || Así como se coloca en el anexo 1 en el campo de “Tipo de Producto de Crédito”.
   || Adjunto el ejemplo, ya que debe ir en este mismo formato.
   */
   if rec(i).query_10 = 'C' then
      v_des_modalidad := 'Venta Cartera NoFin';
   elsif rec(i).query_10 = 'V' then
      v_des_modalidad := 'Venta Cartera Particulares';
   elsif rec(i).query_10 = 'B' then
      v_des_modalidad := 'Venta Bienes Plazo';
   elsif rec(i).query_10 = 'P' then
      v_des_modalidad := 'Prestamos Incobrables';
   elsif rec(i).query_10 = 'O' then
      v_des_modalidad := 'OpeVenc Incobrables';
   elsif rec(i).cod_modulo = 6 and
      rec(i).cod_modalidad not in (
        62 --DESCUENTO DE DOCUMENTOS
      ,608 --DESCUENTO DE CHEQUES
     --613 --PCP INTERES ADELANTADO
      ,622 --CARTERA COMPRADA
     --676  --PRESTAMOS PERSONALES INT.ADELANTADO
     ) then --nvl(v_tip_prestamo,'X') <> 'D'
      v_des_modalidad := 'Prestamos';
   elsif (rec(i).cod_modulo = 5 or rec(i).cod_modalidad = 151) then
      v_des_modalidad := 'Tarjetas de Credito';
   elsif (rec(i).cod_modulo = 4 or rec(i).cod_modalidad = 152) then
      v_des_modalidad := 'Sobregiros';
   else
      v_des_modalidad := fug_obt_des_modalidad(rec(i).cod_modalidad);
   end if;
   --- FUS_OBT_TAS_EFECTIVA
   v_tae := null;
   if rec(i).cod_modulo = 5 then
      begin
         select t.tas_financiacion
           into v_tae
           from ta_cta_tarjetas t
          where t.nro_cuenta = rec(i).nro_cuenta;               
      exception
         when others then
            v_tae := null;
      end;
   end if;
   if v_tae is not null then
      v_tan := v_tae;
   else
      begin
         select t.val_tas_efectiva, t.val_tas_nominal
           into v_tae, v_tan
           from IT.MI_SB_TAS_APE_SEMANALES t
          where t.nro_cuenta = rec(i).nro_cuenta
            and t.fec_apertura = (select max(a.fec_apertura)
                                   from MI_SB_TAS_APE_SEMANALES a
                                  where a.nro_cuenta = t.nro_cuenta);
      exception
         when others then
            v_tae := null;
            v_tan := null;
      end;
   end if;
   ---
   v_moneda_bt     := pag_mig.fu_obt_cod_bantotal(rec(i).cod_moneda, 'BA_MONEDAS');
   v_estado_bt     := rec(i).tip_renovacion;
   /*
   || traer la garantia computable que tenia que usar el scr
   || en caso de categoria 6, dependiendo del semestre
   || se va disminuyendo la garantia computable
   || hasta que llega un punto que se previsiona en un 100%
   ||
   || select t.tot_gar_computables - (t.tot_gar_computables * t.por_calculado/100)
   ||   from pr_previsiones t
   ||  where t.por_calculado > 0;   
   */
   if nvl(v_por_prev_calc,0) > 0 and nvl(rec(i).cat_riesgo,1) = 6 then
      rec(i).tot_gar_computables := rec(i).tot_gar_computables - (rec(i).tot_gar_computables * v_por_prev_calc/100);
   end if;
   --- Ajusta Prevision sobre capital e interes para los casos de prestamos vencidos
   if rec(i).query_10 = 'N'     and -- solo los de ge_cla_operaciones
      rec(i).cat_automatica = 6 and -- solo los vencidos
      nvl(v_prev_cap_ml,0) + nvl(v_prev_int_ml,0) = 0 and -- no tienen prevision de capital ni interes
      nvl(rec(i).prim_prevision,0) + nvl(rec(i).seg_prevision,0) - nvl(v_prev_cont_ml,0) > 0 then 
      v_prev_cap_ml := round(nvl(rec(i).prim_prevision,0) + nvl(rec(i).seg_prevision,0) - nvl(v_prev_cont_ml,0),0);
   end if;
   ---
   select nvl(sum(a.mto_apl_computable),0), nvl(sum(a.mto_apl_com_ml),0)
     into v_gar_bca_mo, v_gar_bca_ml
     from pr_cta_garantias_det a, pr_garantias g
    where a.cod_garantia in (5, 19, 21)
      and a.nro_garantia = g.nro_garantia
      and a.nro_cuenta = rec(i).nro_cuenta
      and a.fecha = v_fec_actual;
   
   if rec(i).cod_moneda = v_cod_mon_local then
      v_int_suspenso_ml   := round(v_int_suspenso_mo,0);
      
      v_tot_deu_cont_mo   := round(rec(i).tot_deu_contingente,2);
      v_tot_gar_comp_mo   := round(rec(i).tot_gar_computables,2);
      v_prim_prevision_mo := round(rec(i).prim_prevision,2);
      v_seg_prevision_mo  := round(rec(i).seg_prevision,2);
      v_sal_interes_mo    := round(rec(i).dev_no_cobrado,2);
      
      if rec(i).cod_modulo in (4,5) then 
         -- tiene prevision de contingencia en prevision de capital en ge_cla_operaciones
         v_prev_cap_ml    := round(v_prev_cap_mo,0);
      else
         v_prev_cap_mo    := round(v_prev_cap_ml,2);
      end if;
      v_prev_int_mo       := round(v_prev_int_ml,2);
      
      v_prev_cont_ml      := round(v_prev_cont_mo,0);
      v_mto_cta_mora_ml   := round(v_mto_cta_mora_mo,0);
      v_sal_deu_activo_ml := round(v_sal_deu_activo_mo,0);
      v_mto_cont_ml       := round(v_mto_cont_mo,0);
      v_sal_cap_ant_ml    := round(v_sal_cap_ant_mo,0);
      v_sal_capital_ml    := round(v_sal_capital_mo,0);
      v_sal_exceso_ml     := round(v_sal_exceso_mo,0);
   else
      v_int_suspenso_ml   := round(v_int_suspenso_mo  * v_cotizacion,0);
      
      v_tot_deu_cont_mo   := round(rec(i).tot_deu_contingente / v_cotizacion,2);
      v_tot_gar_comp_mo   := round(rec(i).tot_gar_computables / v_cotizacion,2);
      v_prim_prevision_mo := round(rec(i).prim_prevision / v_cotizacion,2);
      v_seg_prevision_mo  := round(rec(i).seg_prevision / v_cotizacion,2);
      v_sal_interes_mo    := round(rec(i).dev_no_cobrado / v_cotizacion,2);
      
      if rec(i).cod_modulo in (4,5) then 
         -- tiene prevision de contingencia en prevision de capital en ge_cla_operaciones
         v_prev_cap_ml    := round((v_prev_cap_mo * v_cotizacion),0);
      else
         v_prev_cap_mo    := round(v_prev_cap_ml / v_cotizacion,2);
      end if;
      v_prev_int_mo       := round(v_prev_int_ml / v_cotizacion,2);
      
      v_prev_cont_ml      := round(v_prev_cont_mo * v_cotizacion,0);
      v_mto_cta_mora_ml   := round(v_mto_cta_mora_mo * v_cotizacion,0);
      v_sal_deu_activo_ml := round(v_sal_deu_activo_mo * v_cotizacion,0);
      v_mto_cont_ml       := round(v_mto_cont_mo * v_cotizacion,0);
      
      v_sal_cap_ant_ml    := round(v_sal_cap_ant_mo * v_cotizacion,0);
      v_sal_capital_ml    := round(v_sal_capital_mo * v_cotizacion,0);
      v_sal_exceso_ml     := round(v_sal_exceso_mo * v_cotizacion,0);
   end if;
   --- SALDO_DEUDA_EN_ACTIVO_ML
   --- v_tot_deuda_mo := rec(i).tot_deu_real;
   v_tot_deuda_mo := nvl(v_sal_capital_mo,0) + nvl(v_sal_interes_mo,0);
   if rec(i).cod_moneda = v_cod_mon_local then
      v_tot_deuda_ml := round(v_tot_deuda_mo,0);
   else
      v_tot_deuda_ml := round(v_tot_deuda_mo * v_cotizacion,0);
   end if;
   --- Calculo de Prevision Generica
   --- =(SALDO_CAPITAL_ML-(PRIMERA_PREVISION_ML+SEGUNDA_PREVISION_ML))*0,5%
   v_prev_gen_mo := 0;
   v_prev_gen_ml := 0;
   if (substr(v_cod_rubro,1,2) = '14' and substr(v_cod_rubro,4,2) in ('10','40','80','90')) or
      (substr(v_cod_rubro,1,2) = '16' and substr(v_cod_rubro,4,2) in ('10','20','30','40','80','90')) then  
      v_prev_gen_ml := round( 
                              (
                                 (nvl(v_sal_capital_ml,0)+nvl(rec(i).dev_no_cobrado,0)) - 
                                 (nvl(rec(i).prim_prevision,0)+nvl(rec(i).seg_prevision,0))
                              ) * 0.005, 0);
      v_prev_gen_mo := round(
                              (
                                 (nvl(v_sal_capital_mo,0)+nvl(v_sal_interes_mo,0)) -
                                 (nvl(v_prim_prevision_mo,0)+nvl(v_seg_prevision_mo,0))
                               )* 0.005, 2);
   end if;
   ---
   --- rec(i)alcula la prevision igual de 1004
   ----
   if replace(v_cat_resultante,'Categoria ') = '1a' then
      v_por_prevision := 0.5;
   elsif replace(v_cat_resultante,'Categoria ') = '1b' then
      v_por_prevision := 1.5;
   elsif replace(v_cat_resultante,'Categoria ') = '2' then
      v_por_prevision := 5;
   elsif replace(v_cat_resultante,'Categoria ') = '3' then
      v_por_prevision := 25;
   elsif replace(v_cat_resultante,'Categoria ') = '4' then
      v_por_prevision := 50;
   elsif replace(v_cat_resultante,'Categoria ') = '5' then
      v_por_prevision := 75;
   elsif replace(v_cat_resultante,'Categoria ') = '6' then
      v_por_prevision := 100;
   else
      v_por_prevision := 0;
   end if;

   if v_por_prevision is not null then
      v_por_prevision := v_por_prevision/100;
   end if;
   
   v_gar_no_bca_ml := nvl(rec(i).tot_gar_computables,0) - nvl(v_gar_bca_ml,0);
   if nvl(v_gar_no_bca_ml,0) < 0 then
      v_gar_no_bca_ml := 0;
   end if;
   v_gar_no_bca_mo := nvl(v_tot_gar_comp_mo,0) - nvl(v_gar_bca_mo,0);
   if nvl(v_gar_no_bca_mo,0) < 0 then
      v_gar_no_bca_mo := 0;
   end if;
   
   SELECT decode(count(*),0,'NO','GESTION JUDICIAL')
     into v_ges_judicial
     FROM ge_per_inhibidas b, ge_causales a
    WHERE a.cod_causa = b.cod_causa
      AND a.descripcion LIKE '%JUDI%'
      AND a.tipo = 'I'
      AND b.estado = 'I'
      AND b.cod_persona = rec(i).riesgo;
   if nvl(v_ges_judicial,'NO') = 'NO' then
      if nvl(rec(i).dia_atraso,0) > 0 then
         v_ges_judicial := 'SI';
      end if;
   end if;
   if v_ges_judicial is null then
      v_ges_judicial := 'NO';
   end if;
   ---
   v_tot_riesgo := nvl(v_tot_deuda_ml,0) + nvl(v_mto_cont_ml,0);
   ---
   v_es_r4 := nvl(fug_obt_pardinamico('COD_MAD_RESOLUCION04',rec(i).cod_modulo, rec(i).cod_modalidad),'N');
   
   rec(i).nombre_per := replace(rec(i).nombre_per,chr(10));--elimina enter
   rec(i).nombre_per := replace(rec(i).nombre_per,chr(124));--elimina pipe
   ---
   v_nro_secuencia := nvl(v_nro_secuencia,0) + 1;
   rp_mquery.secuencia := v_nro_secuencia;
   rp_mquery.pais := v_pais_bt;
   rp_mquery.tipo_doc := v_tipo_doc_bt;
   
   rp_mquery.nro_documento := rec(i).nro_doc;
   rp_mquery.nombre_deudor := rec(i).nombre_per;
   rp_mquery.tipo_deudor := v_tip_deudor;
 --rp_mquery.vinculo := v_relacion;
 --rp_mquery.grupo_econ := nvl(rec.gru_eco_bcp,0);
   
   rp_mquery.actividad := v_act_bco_central;
   rp_mquery.sucursal := rec(i).oficina;
   rp_mquery.cuenta := rec(i).riesgo;
   rp_mquery.cat_resultante := v_cat_resultante;
   rp_mquery.cat_subjetiva := v_cat_subjetiva;
   
   rp_mquery.fecha_desde_cat_sub := v_fec_cat_sub;
   rp_mquery.titulo := v_titulo;
   rp_mquery.capitulo := v_capitulo;
   rp_mquery.rubro := v_rub_bcp;
   rp_mquery.modulo := v_modulo;
   
   rp_mquery.moneda := v_moneda_bt;
   rp_mquery.operacion := rec(i).nro_cuenta;
   rp_mquery.tipo_operacion := v_tip_operacion;
   
   rp_mquery.fecha_de_alta := rec(i).fecha_inicio_oper;
   rp_mquery.fecha_de_vto := v_fec_vto;
   rp_mquery.dias_mora := rec(i).dia_atraso;
   rp_mquery.monto_desembolsado := nvl(v_mto_desembolsado,0);
   ---
   rp_mquery.saldo_capital_mo := nvl(v_sal_capital_mo,0);
   rp_mquery.saldo_capital_ml := nvl(v_sal_capital_ml,0);
   ---
   if nvl(rec(i).query_10,'N') = 'C' then
      rp_mquery.interes_mo := 0;
      rp_mquery.interes_ml := 0;
      rp_mquery.interes_suspendido_mo := 0;
      rp_mquery.interes_suspendido_ml := 0;
      ---
      rp_mquery.saldo_contingente_mo := 0;
      rp_mquery.saldo_contingente_ml := 0;
   else
      rp_mquery.interes_mo := nvl(v_sal_interes_mo,0);
      rp_mquery.interes_ml := nvl(v_sal_interes_ml,0);
      rp_mquery.interes_suspendido_mo := nvl(v_int_suspenso_mo,0);
      rp_mquery.interes_suspendido_ml := nvl(v_int_suspenso_ml,0);
      ---
      rp_mquery.saldo_contingente_mo := nvl(v_mto_cont_mo,0);
      rp_mquery.saldo_contingente_ml := nvl(v_mto_cont_ml,0);
   end if;      
   ---
   rp_mquery.porcentaje_prevision := nvl(v_por_prevision,0);
   ---
   rp_mquery.garantia_computable_mo := nvl(v_tot_gar_comp_mo,0);
   rp_mquery.garantia_computable_ml := nvl(rec(i).tot_gar_computables,0);
   rp_mquery.prevision_s_capital_mo := nvl(v_prev_cap_mo,0);
   rp_mquery.prevision_s_capital_ml := nvl(v_prev_cap_ml,0);
   rp_mquery.prevision_s_interes_mo := nvl(v_prev_int_mo,0);
   rp_mquery.prevision_s_interes_ml := nvl(v_prev_int_ml,0);
   rp_mquery.prevision_s_contingente_mo := nvl(v_prev_cont_mo,0);
   rp_mquery.prevision_s_contingente_ml := nvl(v_prev_cont_ml,0);
   rp_mquery.primera_prevision_mo := nvl(v_prim_prevision_mo,0);
   rp_mquery.primera_prevision_ml := nvl(rec(i).prim_prevision,0);
   rp_mquery.segunda_prevision_mo := nvl(v_seg_prevision_mo,0);
   rp_mquery.segunda_prevision_ml := nvl(rec(i).seg_prevision,0);
   rp_mquery.prevision_generica_mo := nvl(v_prev_gen_mo,0);
   rp_mquery.prevision_generica_ml := nvl(v_prev_gen_ml,0);

   rp_mquery.estado := v_estado_bt;
   rp_mquery.ejecutivo := rec(i).cod_usu_oficial;
   rp_mquery.nombre_ejecutivo := rec(i).nombre_usu;
   
 --rp_mquery.segmento := v_segmento;
   rp_mquery.segmento := rec(i).banca;
   rp_mquery.clasif_interna := v_seg_interno;
   rp_mquery.tipo_prestamo := v_des_modalidad;
   rp_mquery.tae := nvl(v_tae,0);
   rp_mquery.tan := nvl(v_tan,0);
   
   rp_mquery.monto_operacion_mo := nvl(v_sal_capital_mo,0);
   rp_mquery.monto_operacion_ml := nvl(v_sal_capital_ml,0);
   rp_mquery.monto_cuota_atrasada_mo := nvl(v_mto_cta_mora_mo,0);
   rp_mquery.monto_cuota_atrasada_ml := nvl(v_mto_cta_mora_ml,0);
   rp_mquery.cuotas_canceladas := nvl(v_can_cuo_canceladas,0);
   
   rp_mquery.fecha_1er_vto := v_fec_pri_vto;
   rp_mquery.fecha_vto_mas_antiguo := v_fec_vto_antiguo;
   rp_mquery.saldo_deuda_en_activo_mo := nvl(v_tot_deuda_mo,0);--nvl(v_sal_deu_activo_mo,0);
   rp_mquery.saldo_deuda_en_activo_ml := nvl(v_tot_deuda_ml,0);--nvl(v_sal_deu_activo_ml,0);
   rp_mquery.total_de_riesgo := nvl(v_tot_riesgo,0); --nvl(rec(i).tot_deuda,0);
   
   rp_mquery.recuperaciones := v_ges_judicial;
   rp_mquery.categoria_de_persona := v_des_cat_ind;
   rp_mquery.categoria_de_operacion := v_des_cat_crc;
   rp_mquery.garantia_bancaria_mo := nvl(v_gar_bca_mo,0);
   rp_mquery.garantia_bancaria_ml := nvl(v_gar_bca_ml,0);
   
   rp_mquery.garantia_no_bancaria_mo := nvl(v_gar_no_bca_mo,0);
   rp_mquery.garantia_no_bancaria_ml := nvl(v_gar_no_bca_ml,0);
   rp_mquery.categoria_rrr := v_des_cat_ren;
   rp_mquery.es_r4 := v_es_r4;
   --- fecha_desde_cat_sub
   if rp_mquery.fecha_desde_cat_sub is not null then
      v_fec_cat_char:= to_char(rp_mquery.fecha_desde_cat_sub,'yyyymmdd');
   else
      v_fec_cat_char := ' ';
   end if;
   --- fecha_de_vto
   if rp_mquery.fecha_de_vto is not null then
      v_fec_vto_char:= to_char(rp_mquery.fecha_de_vto,'yyyymmdd');
   else
      v_fec_vto_char := ' ';
   end if;
   --- fecha_de_alta
   if rp_mquery.fecha_de_alta is not null then
      v_fec_ini_char:= to_char(to_date(rp_mquery.fecha_de_alta,'dd/mm/yyyy'),'yyyymmdd');
   else
      v_fec_ini_char := ' ';
   end if;
   --- Campos de tipo y nro de documento de CRC
   rp_mquery.nro_doc_crc := null;
   rp_mquery.tipo_doc_crc := null;
   begin
      select a.nro_documento, a.tip_documento
        into rp_mquery.nro_doc_crc, rp_mquery.tipo_doc_crc
        from sb_crc_clasificaciones_det a
       where a.cod_persona = rec(i).riesgo
         and a.fecha = v_max_fec_saldos;
   exception
      when others then
         rp_mquery.nro_doc_crc := null;
   end;
   ---
   if rp_mquery.nro_doc_crc is null then
      begin
         select a.nro_documento
           into rp_mquery.nro_doc_crc
           from sb_crc_clasificaciones_det a
          where a.cod_persona = rec(i).riesgo
            and a.fecha = (select max(b.fecha)
                             from sb_crc_clasificaciones_det b
                            where b.cod_persona = a.cod_persona);
      exception
         when others then
            rp_mquery.nro_doc_crc := null;
      end;
   end if;
   if rp_mquery.nro_doc_crc is null then
      rp_mquery.nro_doc_crc := rec(i).nro_doc;
   end if;
   ---
   if rp_mquery.tipo_doc_crc is null then
      begin
         select a.tip_documento
           into rp_mquery.tipo_doc_crc
           from sb_crc_clasificaciones_det a
          where a.cod_persona = rec(i).riesgo
            and a.fecha = (select max(b.fecha)
                             from sb_crc_clasificaciones_det b
                            where b.cod_persona = a.cod_persona);
      exception
         when others then
            rp_mquery.tipo_doc_crc := null;
      end;
   end if;
   if rp_mquery.tipo_doc_crc is null then
      if v_tipo_doc_bt = 1 then
         rp_mquery.tipo_doc_crc := 'CI';
      elsif v_tipo_doc_bt = 3 then
         rp_mquery.tipo_doc_crc := 'RUC';
      elsif v_tipo_doc_bt = 8 then
         rp_mquery.tipo_doc_crc := 'CRP';
      else
         rp_mquery.tipo_doc_crc := 'CRC';
      end if;
   end if;
   ---------------------------
   if v_nro_cuenta is null then
      lp_ins_query_10(rp_mquery);
   end if;
   ---------------------------
   if v_sal_cap_cont in ('S','X') and nvl(v_sal_exceso_mo,0) > 0 then
      if v_sal_cap_cont = 'S' then --rec.cod_modulo = 4
         v_cod_rubro := pab_asi.fu_obt_rub_contable(rec(i).nro_cuenta,'C','T');
      elsif v_sal_cap_cont = 'X' then --rec.cod_modulo = 8
         v_cod_rubro := pab_asi.fu_obt_rub_contable(rec(i).nro_cuenta,'S','A');
         if v_cod_rubro is null then
            v_cod_rubro := lf_obt_rub_contable(rec(i).nro_cuenta,'S','A');
         end if;
      end if;
      v_rub_bcp       := substr(v_cod_rubro, 1, 8) || substr(v_cod_rubro, 3, 1) || substr(v_cod_rubro, 9, 2);
      v_tip_operacion := substr(v_cod_rubro, 6, 3);
      v_titulo        := substr(v_cod_rubro, 1, 1);
      v_capitulo      := substr(v_cod_rubro, 2, 1);
      v_grupo         := substr(v_cod_rubro, 4, 2);
      v_subgrupo      := substr(v_cod_rubro, 9, 2);
      
      rp_mquery.rubro := v_rub_bcp;
      rp_mquery.tipo_operacion := v_tip_operacion;
      rp_mquery.titulo := v_titulo;
      rp_mquery.capitulo := v_capitulo;
         
      v_nro_secuencia := nvl(v_nro_secuencia,0) + 1;
      rp_mquery.secuencia := v_nro_secuencia;
      
      if v_sal_cap_cont = 'S' then
         rp_mquery.saldo_capital_mo     := nvl(v_sal_exceso_mo,0);
         rp_mquery.saldo_capital_ml     := nvl(v_sal_exceso_ml,0);
         rp_mquery.saldo_contingente_mo := 0;
         rp_mquery.saldo_contingente_ml := 0;
      elsif v_sal_cap_cont = 'X' then
         rp_mquery.saldo_capital_mo     := 0;
         rp_mquery.saldo_capital_ml     := 0;
         rp_mquery.saldo_contingente_mo := nvl(v_sal_exceso_mo,0);
         rp_mquery.saldo_contingente_ml := nvl(v_sal_exceso_ml,0);
      end if;
      --- SALDO_DEUDA_EN_ACTIVO_ML
      rp_mquery.saldo_deuda_en_activo_mo := nvl(rp_mquery.saldo_capital_mo,0);
      rp_mquery.saldo_deuda_en_activo_ml := nvl(rp_mquery.saldo_capital_ml,0);
      rp_mquery.total_de_riesgo := nvl(v_sal_exceso_ml,0);
       
      rp_mquery.interes_mo := 0;--nvl(v_sal_interes_mo,0);
      rp_mquery.interes_ml := 0;--nvl(rec.dev_no_cobrado,0);
      rp_mquery.interes_suspendido_mo := 0;--nvl(v_int_suspenso_mo,0);
      rp_mquery.interes_suspendido_ml := 0;--nvl(v_int_suspenso_ml,0);
      
      rp_mquery.garantia_computable_mo := 0;--nvl(v_tot_gar_comp_mo,0);
      rp_mquery.garantia_computable_ml := 0;--nvl(rec.tot_gar_computables,0);
      rp_mquery.porcentaje_prevision := 0;--nvl(v_por_prevision,0);
      
      rp_mquery.prevision_s_capital_mo := 0;--nvl(v_prev_cap_mo,0);
      rp_mquery.prevision_s_capital_ml := 0;--nvl(v_prev_cap_ml,0);
      rp_mquery.prevision_s_interes_mo := 0;--nvl(v_prev_int_mo,0);
      rp_mquery.prevision_s_interes_ml := 0;--nvl(v_prev_int_ml,0);
      rp_mquery.prevision_s_contingente_mo := 0;--nvl(v_prev_cont_mo,0);
      
      rp_mquery.prevision_s_contingente_ml := 0;--nvl(v_prev_cont_ml,0);
      rp_mquery.primera_prevision_mo := 0;--nvl(v_prim_prevision_mo,0);
      rp_mquery.primera_prevision_ml := 0;--nvl(rec.prim_prevision,0);
      rp_mquery.segunda_prevision_mo := 0;--nvl(v_seg_prevision_mo,0);
      rp_mquery.segunda_prevision_ml := 0;--nvl(rec.seg_prevision,0);
      
      rp_mquery.prevision_generica_mo := 0;--nvl(v_prev_gen_mo,0);
      rp_mquery.prevision_generica_ml := 0;--nvl(v_prev_gen_ml,0);
      rp_mquery.garantia_bancaria_mo := 0;--nvl(v_gar_bca_mo,0);
      rp_mquery.garantia_bancaria_ml := 0;--nvl(v_gar_bca_ml,0);
      
      rp_mquery.garantia_no_bancaria_mo := 0;--nvl(v_gar_no_bca_mo,0);
      rp_mquery.garantia_no_bancaria_ml := 0;--nvl(v_gar_no_bca_ml,0);
      
      if v_nro_cuenta is null then
         lp_ins_query_10(rp_mquery);
      end if;

   end if;
   
--**********************************************************************
    v_lines := v_lines + 1;
   <<siguiente>>
   null;
   --EXIT WHEN cu_prevision_det%NOTFOUND;
END LOOP;
--------------------------------
EXIT WHEN cu_prevision_det%NOTFOUND;
END LOOP;
--Escribes la linea en el fichero
UTL_FILE.PUT_LINE(v_file, v_buffer);
-- RE DE-1172**************************
UTL_FILE.PUT_LINE(v_file2, v_buffer2);
-- PIPROINTE-285 Riesgos - Anexo 1 - Reportes de Gestión requeridos por GNB Sudameris Colombia (Query 9)
UTL_FILE.PUT_LINE(v_file3, v_buffer3);
--UTL_FILE.PUT_LINE(v_file4, v_buffer4);
--*************************************

--Cerrar el handler al fichero
UTL_FILE.FCLOSE(v_file);
-- RE DE-1172**************************
UTL_FILE.FCLOSE(v_file2);
-- PIPROINTE-285 Riesgos - Anexo 1 - Reportes de Gestión requeridos por GNB Sudameris Colombia (Query 9)
UTL_FILE.FCLOSE(v_file3);
--UTL_FILE.FCLOSE(v_file4);
--*************************************
COMMIT;

  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_respuesta := pa_file_ftp.fu_put_ascii(pag_evo.g_ip, pag_evo.g_port, pag_evo.g_user,
                                          pag_evo.g_pass, pag_evo.g_repository,
                                          v_name||'.txt', g_riesgos||v_name||'_'||v_fecha||'.txt');
  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');
  
  -- ARCHIVO PREVISION_DET
  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
    -- Obtenemos las direcciones de correo para quien o quienes va el correo
    v_para := pag_evo.FU_OBT_VALOR_PAR('RA','REPORTES','PREVISION_DETALLE');
    
    -- Damos valor a los demas datos
    v_asunto := 'Reporte Previsiones Específicas Detallado a la fecha '||v_fec_sist||'.';
    v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_riesgos||'
    
    Nombre del Archivo: '||v_name||'_'||v_fecha||'.txt';
    
    -- Enviamos el mail
    v_det_error    := null;
    v_hini_mail    := to_char(sysdate,'hh24:mi:ss');
    
    if v_env_mail then
      BEGIN
        it_mail.mail(pag_evo.g_envia_mail,v_para,v_asunto,v_mje_mail);
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
    end if;
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
    v_para := pag_evo.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
    v_asunto := 'Error Reporte Previsiones Específicas Detallado a la fecha '||v_fec_sist||'.';
    v_mje_mail := 'Error al enviar archivo por FTP.
    
    Error: '||v_respuesta||'.
    
    Para mas información verificar la tabla GE_RA_LOG_FTP';
    
    v_hini_mail := to_char(sysdate,'hh24:mi:ss');

    if v_env_mail then
      BEGIN
        it_mail.mail(pag_evo.g_envia_mail,v_para,v_asunto,v_mje_mail);
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
    end if;
    
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

  -- ENVIO POR FTP -- ARCHIVO INF_CARTERA_TOTAL
  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');
  v_respuesta := pa_file_ftp.fu_put_ascii(pag_evo.g_ip, pag_evo.g_port, pag_evo.g_user,
                                          pag_evo.g_pass, pag_evo.g_repository,
                                          v_name2||'.txt', pag_evo.g_red_sucursales||v_name2||'_'||v_fecha||'.txt');
  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');
  IF v_respuesta != 'OK' THEN
    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
       (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
       (SYSDATE, v_name2||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;
    -- Obtenemos las direcciones de correo para quien o quienes va el correo
    v_para := fug_obt_pardinamico('MAIL_CARTERA_TOT_RED_SUCURSAL');
    -- Damos valor a los demas datos
    v_asunto := 'No se generó INFORME CANALES COMPLEMENTARIOS a la fecha '||v_fec_sist||'.';
    v_mje_mail := 'El archivo con los datos del informe NO SE HA GENERADO en la siguiente dirección: '||'\\'||g_ip||'\'
               ||g_red_sucursales||'Nombre del Archivo: '||v_name2||'_'||v_fecha||'.txt.
               Ver ERROR en la tabla ge_ra_log_ftp.';
    -- Enviamos el mail
    v_det_error    := null;
    v_hini_mail    := to_char(sysdate,'hh24:mi:ss');
    
    if v_env_mail then
      BEGIN
        it_mail.mail(pag_evo.g_envia_mail,v_para,v_asunto,v_mje_mail);
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
    end if;
    v_hfin_mail := to_char(sysdate,'hh24:mi:ss');
    -- Insertamos en la tabla de log si ocurrio algún error al enviar el mail
    IF v_det_error is not null THEN
       INSERT INTO ge_ra_log_mail
          (fec_envio, nom_archivo, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
       VALUES
          (SYSDATE, v_name2||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
       COMMIT;
    END IF;
  END IF;
    
  -- PIPROINTE-285 Riesgos - Anexo 1 - Reportes de Gestión requeridos por GNB Sudameris Colombia (Query 9)
  -- ARCHIVO QUERY10
  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');
  v_respuesta := pa_file_ftp.fu_put_ascii(pag_evo.g_ip, pag_evo.g_port, pag_evo.g_user,
                                          pag_evo.g_pass, pag_evo.g_repository,
                                          v_name3||'.csv', g_query_10||v_name3||'_'||v_fec_archivo||'.csv');
  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');
  
  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
     -- Obtenemos las direcciones de correo para quien o quienes va el correo
     v_para := pag_evo.FU_OBT_VALOR_PAR('RA','REPORTES','PREVISION_DETALLE');
     
     -- Damos valor a los demas datos
     v_asunto := 'Reporte Query 10 a la fecha '||v_fec_sist||'.';
     v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_query_10||'
     
     Nombre del Archivo: '||v_name3||'_'||v_fec_archivo||'.csv';
     
     -- Enviamos el mail
     v_det_error    := null;
     v_hini_mail    := to_char(sysdate,'hh24:mi:ss');
     if v_env_mail then
        BEGIN
           it_mail.mail(pag_evo.g_envia_mail,v_para,v_asunto,v_mje_mail);
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
      end if;
      v_hfin_mail := to_char(sysdate,'hh24:mi:ss');
      -- Insertamos en la tabla de log si ocurrio algún error al enviar el mail
      IF v_det_error is not null THEN
          INSERT INTO ge_ra_log_mail
           (fec_envio, nom_archivo, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
          VALUES
           (SYSDATE, v_name3||'.csv', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
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
     
     -- Enviamos el mail a soporte
     -- Obtenemos direccion de correo de soporte
     v_para := pag_evo.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');
     
     -- Damos valor a los demas datos
     v_asunto := 'Error Reporte Query 10 a la fecha '||v_fec_sist||'.';
     v_mje_mail := 'Error al enviar archivo por FTP.
     
     Error: '||v_respuesta||'.
     
     Para mas información verificar la tabla GE_RA_LOG_FTP';
     
     v_hini_mail := to_char(sysdate,'hh24:mi:ss');
     if v_env_mail then
        BEGIN
           it_mail.mail(pag_evo.g_envia_mail,v_para,v_asunto,v_mje_mail);
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
     end if;     
     v_hfin_mail := to_char(sysdate,'hh24:mi:ss');
     
     -- Insertamos en la tabla de log  si ocurrio algun error al enviar el mail
     IF v_det_error is not null THEN
        INSERT INTO ge_ra_log_mail
           (fec_envio, nom_archivo, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
        VALUES
           (SYSDATE, v_name3||'.csv', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
        COMMIT;
     END IF;

  END IF;
   --*************************************

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
END pr_previ_det;

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
                              <p><img src="'||fug_obt_pardinamico('URL_BCO_LOGO')||'" alt="Site Logo" />
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
  select pag_cal.FU_OBT_FEC_ACTUAL(1)
  into v_fec_sist
  from dual;

  select a.descripcion
    into v_descripcion
    from ge_procesos a
   where a.cod_proceso = p_cod_proceso;

  v_fecha := to_char(v_fec_sist,'DDMMYYYY');

  if p_cod_proceso = 10 then
     v_name := 'INICIO_DIA';
  end if;

  if p_cod_proceso = 11 then
     v_name := 'CIERRE_DIARIO';
  end if;

  if p_cod_proceso = 12 then
     v_name := 'POST_CIERRE';
  end if;
  -- obtenemos los mail que van a recibir el reporte
  v_para := pa_rep_aut.FU_OBT_VALOR_PAR('RA','REPORTES','PROCESOS_CIERRE');

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
  v_asunto := 'Reporte de tiempos del proceso: ' || v_descripcion || ', a la fecha: '||v_fec_sist||'.';

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
    /*v_conn := it_mail.begin_mail(pa_rep_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
    it_mail.attach_text(v_conn,  v_mje_mail,'text/html');
    it_mail.begin_attachment(v_conn,'text/plain',false,v_name||'_'||v_fecha||'.xls');*/
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
      --it_mail.write_text(v_conn,v_cabecera);
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
        --it_mail.write_text(v_conn,v_detalle);
        v_detalle := '';
        --**
        EXIT WHEN cu_procesos_cierre%NOTFOUND;
      END LOOP;
    --**
    -- Verificamos si el cursor trajo por lo menos un registro, de ser asi enviamos el mail
    IF v_flag THEN
       --envio de correo con archivo excel
       it_mail.mail_attach_xls(pa_rep_aut.g_envia_mail,--sender
                               v_para, --destinatario/s
                               v_asunto, --asunto correo
                               v_mje_mail, --mensaje correo
                               v_cabecera||v_detalle, --data (excel)
                               v_name||'_'||v_fecha||'.xls' --nombre del archivo excel
                               );     
       --it_mail.end_mail(v_conn);
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
  v_pri_dia_mes_ant   DATE;
  v_ult_dia_mes_ant   DATE;

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
  select pag_cal.FU_OBT_FEC_ACTUAL(1)
  into v_fec_sist
  from dual;
--Obtenemos el primer dia y el ultimo dia del mes anterior
  v_pri_dia_mes_ant := to_date('01'||'/'||to_char(add_months(sysdate, -1), 'MM')||'/'||to_char(add_months(sysdate, -1), 'YYYY'),'dd/mm/yyyy');
  v_ult_dia_mes_ant := to_date(to_char(last_day(add_months(sysdate, -1)), 'dd/mm/yyyy'),'dd/mm/yyyy');

  v_fecha := to_char(v_fec_sist,'DDMMYYYY');

  --Obtenemos el primer dia y el ultimo dia del mes
  v_dia_ini := trunc(v_fec_sist,'month');
  v_dia_fin := trunc(last_day(v_fec_sist));

-- Abrir archivo
v_file := UTL_FILE.FOPEN(pa_rep_aut.g_repository,v_name||'.txt','W',32767);

-- Colocar el titulo a los campos
v_linetit := 'FECHA'||CHR(9)||'COD_OFICINA'||CHR(9)||'NRO_ASIENTO'||CHR(9)||'NRO_LINEA'||CHR(9)||'COD_RUBRO'||CHR(9)||
             'DESCRIPCION'||CHR(9)||'TIP_MOVIMIENTO'||CHR(9)||'MTO_RUBRO'||CHR(9)||'MTO_LOCAL'||CHR(9)||
             'REF_MOVIMIENTO';

utl_file.put_line(v_file,v_linetit);

-- Definir una linea en blanco para separar los datos del titulo de los campos
v_linetit := ' ';
utl_file.put_line(v_file,v_linetit);

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN cu_agregado_dos(v_pri_dia_mes_ant, v_ult_dia_mes_ant) LOOP

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
  v_respuesta := pa_file_ftp.fu_put_ascii(pa_rep_aut.g_ip, pa_rep_aut.g_port, pa_rep_aut.g_user,
                                          pa_rep_aut.g_pass, pa_rep_aut.g_repository,
                                          v_name||'.txt', g_amaral||v_name||'_'||v_fecha||'.txt');

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pa_rep_aut.FU_OBT_VALOR_PAR('RA','REPORTES','IMPUESTO_VA_DOS');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte Impuestos al Valor Agregado 2 a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_amaral||'

    Nombre del Archivo: '||v_name||'_'||v_fecha||'.txt';

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
        it_mail.mail(pa_rep_aut.g_envia_mail,v_para,v_asunto,v_mje_mail);
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
     v_para := pa_rep_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error Reporte Impuestos al Valor Agregado 2 a la fecha '||v_fec_sist||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
        it_mail.mail(pa_rep_aut.g_envia_mail,v_para,v_asunto,v_mje_mail);
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
       pp.mon_sobregiro,
       pp.dir_correo,
       pp.dir_kit
  from vg_cta_nomina pp ;

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

    -- Variables de la Consulta
    v_nro_cliente varchar2(100);
    v_tip_doc varchar2(100);
    v_pri_nombre varchar2(100);
    v_seg_nombre varchar2(100);
    v_pri_apellido varchar2(100);
    v_seg_apellido varchar2(100);
    v_dir_principal varchar2(100);
    v_tel_principal varchar2(100);
    v_dir_secundaria varchar2(100);
    v_tel_secundario varchar2(100);
    v_fec_nac varchar2(100);
    v_sexo varchar2(100);
    v_nac varchar2(100);
    v_est_civil varchar2(100);
    v_oficina varchar2(100);
    v_oficial varchar2(100);
    v_usu_alta varchar2(100);
    v_fec_apert varchar2(100);
    v_cor_info  varchar2(100);
    v_fec_contrato varchar2(100);

BEGIN
  -- Obtenemos la fecha del sistema
  select pag_cal.FU_OBT_FEC_ACTUAL(1)
  into v_fec_sist
  from dual;

v_fecha := to_char(v_fec_sist,'DDMMYYYY');

-- Abrir archivo
v_file := UTL_FILE.FOPEN(pag_evo.g_repository,v_name||'.txt','W',32767);

-- Colocar el titulo a los campos
v_linetit := 'COD_ENTE'||CHR(9)||'EMPRESA'||CHR(9)||'COD_MODULO'||CHR(9)||'COD_MODALIDAD'||CHR(9)||'TIPO_CTA'||CHR(9)||
             'SUB_MOD'||CHR(9)||'SUB_MOD_CTA'||CHR(9)||'GESTOR'||CHR(9)||'NRO_CUENTA'||CHR(9)||'COD_MONEDA'||CHR(9)||
             'FEC_APERTURA'||CHR(9)||'ESTADO_CTA'||CHR(9)||'COD_PERSONA'||CHR(9)||'CLIENTE'||CHR(9)||
             'NRO_DOCUMENTO'||CHR(9)||'DEBITO_TARJETA'||CHR(9)||'DEBITO_PRESTAMO'||CHR(9)||'FEC_ULT_ACRD'||CHR(9)||
             'SAL_DISPONIBLE'||CHR(9)||'MON_SOBREGIRO'||CHR(9)||'V_NRO_CLIENTE'||CHR(9)||'V_TIP_DOC'||CHR(9)||'V_PRI_NOMBRE'||CHR(9)||'V_SEG_NOMBRE'||CHR(9)||'V_PRI_APELLIDO'||CHR(9)||
             'V_SEG_APELLIDO'||CHR(9)||'V_DIR_PRINCIPAL'||CHR(9)||'V_DIR_SECUNDARIA'||CHR(9)||'V_TEL_PRINCIPAL'||CHR(9)||'V_TEL_SECUNDARIO'||CHR(9)||
             'V_FEC_NAC'||CHR(9)||'V_SEXO'||CHR(9)||'V_NAC'||CHR(9)||'V_EST_CIVIL'||CHR(9)||'V_OFICINA'||CHR(9)||'V_OFICIAL'||CHR(9)||'V_USU_ALTA'||CHR(9)||
             'V_FEC_APERT'||CHR(9)||'V_COR_INFO'||CHR(9)||'V_FEC_CONTRATO'||CHR(9)||'V_DIR_CORREO'||CHR(9)||'V_DIR_KIT';

utl_file.put_line(v_file,v_linetit);

-- Definir una linea en blanco para separar los datos del titulo de los campos
v_linetit := ' ';
utl_file.put_line(v_file,v_linetit);

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN cu_cta_aso LOOP

      v_nro_cliente       := fu_cta_aso_pag_sal(rec.nro_cuenta,1) ;
      v_tip_doc            := fu_cta_aso_pag_sal(rec.nro_cuenta,2) ;
      v_pri_nombre       := fu_cta_aso_pag_sal(rec.nro_cuenta,3) ;
      v_seg_nombre     := fu_cta_aso_pag_sal(rec.nro_cuenta,4) ;
      v_pri_apellido       := fu_cta_aso_pag_sal(rec.nro_cuenta,5) ;
      v_seg_apellido     := fu_cta_aso_pag_sal(rec.nro_cuenta,6) ;
      v_dir_principal      := fu_cta_aso_pag_sal(rec.nro_cuenta,7) ;
      v_tel_principal      := fu_cta_aso_pag_sal(rec.nro_cuenta,8) ;
      v_dir_secundaria  := fu_cta_aso_pag_sal(rec.nro_cuenta,9) ;
      v_tel_secundario  := fu_cta_aso_pag_sal(rec.nro_cuenta,10) ;
      v_fec_nac            := fu_cta_aso_pag_sal(rec.nro_cuenta,11) ;
      v_sexo                := fu_cta_aso_pag_sal(rec.nro_cuenta,12) ;
      v_nac                  := fu_cta_aso_pag_sal(rec.nro_cuenta,13) ;
      v_est_civil            := fu_cta_aso_pag_sal(rec.nro_cuenta,14) ;
      v_oficina              := fu_cta_aso_pag_sal(rec.nro_cuenta,15) ;
      v_oficial               := fu_cta_aso_pag_sal(rec.nro_cuenta,16) ;
      v_usu_alta           := fu_cta_aso_pag_sal(rec.nro_cuenta,17) ;
      v_fec_apert          := fu_cta_aso_pag_sal(rec.nro_cuenta,18) ;
      v_cor_info            := fu_cta_aso_pag_sal(rec.nro_cuenta,19) ;
      v_fec_contrato     := fu_cta_aso_pag_sal(rec.nro_cuenta,20) ;

    --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
  v_line := to_char(rec.cod_ente)||chr(9)||to_char(rec.empresa)||chr(9)||to_char(rec.cod_modulo)||chr(9)||to_char(rec.cod_modalidad)||chr(9)||
            to_char(rec.tipo_cta)||chr(9)||to_char(rec.sub_mod)||chr(9)||to_char(rec.sub_mod_cta)||chr(9)||to_char(rec.gestor)||chr(9)||
            to_char(rec.nro_cuenta)||chr(9)||to_char(rec.cod_moneda)||chr(9)||to_char(rec.fec_apertura)||chr(9)||to_char(rec.estado_cta)||chr(9)||
            to_char(rec.cod_persona)||chr(9)||to_char(rec.cliente)||chr(9)||to_char(rec.nro_documento)||chr(9)||
            to_char(rec.debito_tarjeta)||chr(9)||to_char(rec.debito_prestamo)||chr(9)||to_char(rec.fec_ult_acrd)||chr(9)||
            to_char(rec.sal_disponible,'999999999999D00')||chr(9)||to_char(rec.mon_sobregiro,'999999999999D00')||chr(9)||to_char(v_nro_cliente)||chr(9)||to_char(v_tip_doc)||chr(9)||to_char(v_pri_nombre)||chr(9)||to_char(v_seg_nombre)||chr(9)||to_char(v_pri_apellido)||chr(9)||
            to_char(v_seg_apellido)||chr(9)||to_char(v_dir_principal)||chr(9)||to_char(v_dir_secundaria)||chr(9)||to_char(v_tel_principal)||chr(9)||to_char(v_tel_secundario)||chr(9)||
            to_char(v_fec_nac)||chr(9)||to_char(v_sexo)||chr(9)||to_char(v_nac)||chr(9)||to_char(v_est_civil)||chr(9)||to_char(v_oficina)||chr(9)||to_char(v_oficial)||chr(9)||to_char(v_usu_alta)||chr(9)||
            to_char(v_fec_apert)||chr(9)||to_char(v_cor_info)||chr(9)||to_char(v_fec_contrato)||chr(9)||replace(to_char(rec.dir_correo),chr(10),'')||chr(9)||replace(to_char(rec.dir_kit),chr(10),'');

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
  v_respuesta := pa_file_ftp.fu_put_ascii(pag_evo.g_ip, pag_evo.g_port, pag_evo.g_user,
                                          pag_evo.g_pass, pag_evo.g_repository,
                                          v_name||'.txt', g_operaciones||v_name||'_'||v_fecha||'.txt');

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pag_evo.FU_OBT_VALOR_PAR('RA','REPORTES','ARCHIVOS_OPERACIONES');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte Cuentas asociadas a Entes de Pago Salario '||v_fec_sist||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_operaciones||'

    Nombre del Archivo: '||v_name||'_'||v_fecha||'.txt';

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
        it_mail.mail(pag_evo.g_envia_mail,v_para,v_asunto,v_mje_mail);
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
     v_para := pag_evo.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error Reporte Cuentas asociadas a Entes de Pago Salario '||v_fec_sist||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
        it_mail.mail(pag_evo.g_envia_mail,v_para,v_asunto,v_mje_mail);
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

FUNCTION fu_cta_aso_pag_sal(p_nro_cuenta in varchar2, p_tipo in number)
  return varchar2 is
  -- Proposito: Retorna valores de cuentas de pago de salarios
  -- Precondición:  los parámetros no deben ser nulos
  -- Poscondicion: devuelve un valor nulo en caso de errores
  v_cod_persona ge_cta_clientes.cod_persona%type;
  v_cod_modulo ge_cuentas.cod_modulo%type;
  v_return  varchar2(100);
begin
  begin
    Select g.cod_persona
      into v_cod_persona
      from ge_cta_clientes g
     where g.nro_cuenta = p_nro_cuenta
       and g.relacion = 'P';
    if p_tipo = 1 then
      -- Código de Persona --
      v_return := v_cod_persona;
    elsif p_tipo = 2 then
      -- Tipo de Documento --
      select t.abreviatura
        into v_return
        from ba_personas p, ba_tip_documentos t
       where p.cod_tip_documento = t.cod_tip_documento
         and p.cod_persona = v_cod_persona;
    elsif p_tipo = 3 then
      -- Primer Nombre --
      Select f.pri_nombre
        into v_return
        from ba_per_fisicas f
       where f.cod_persona = v_cod_persona;
    elsif p_tipo = 4 then
      -- Segundo Nombre --
      Select f.seg_nombre
        into v_return
        from ba_per_fisicas f
       where f.cod_persona = v_cod_persona;
    elsif p_tipo = 5 then
      -- Primer apellido --
      Select f.pri_apellido
        into v_return
        from ba_per_fisicas f
       where f.cod_persona = v_cod_persona;
    elsif p_tipo = 6 then
      -- Segundo apellido --
      Select f.seg_apellido
        into v_return
        from ba_per_fisicas f
       where f.cod_persona = v_cod_persona;
    elsif p_tipo = 7 then
      -- Dirección Principal --
      Select t.direccion
        into v_return
        from ba_direcciones t
       where t.cod_persona = v_cod_persona
         and t.principal = 'S';
    elsif p_tipo = 8 then
          -- Teléfono Principal --
         select t.area || ' ' || t.telefono
           into v_return
           from ba_telefonos t
          where t.cod_persona = v_cod_persona
            and t.principal = 'S';
    elsif p_tipo = 9 then
      -- Segunda dirección --
      select t.direccion
        into v_return
        from ba_direcciones t
       where t.cod_persona = v_cod_persona
         and t.cod_direccion =
             (select min(x.cod_direccion)
                from ba_direcciones x
               where x.cod_persona = t.cod_persona
                 and x.principal <> 'S');
    elsif p_tipo = 10 then
          -- Segundo Teléfono --
         select t.area || ' ' || t.telefono
           into v_return
             from ba_telefonos t
            where t.cod_persona = v_cod_persona
              and t.cod_telefono = (select min(x.cod_telefono)
                                      from ba_telefonos x
                                     where x.cod_persona = t.cod_persona
                                       and x.principal <> 'S');
    elsif p_tipo = 11 then
      -- Fecha de Nacimiento  --
      Select f.fec_nacimiento
        into v_return
        from ba_per_fisicas f
       where f.cod_persona = v_cod_persona;
    elsif p_tipo = 12 then
      -- Sexo  --
      Select decode(f.cod_sexo, 'M', 'MASCULINO', 'FEMENINO')
        into v_return
        from ba_per_fisicas f
       where f.cod_persona = v_cod_persona;
    elsif p_tipo = 13 then
      -- Nacionalidad  --
      Select p.descripcion
        into v_return
        from ba_per_fisicas f, ba_paises p
       where f.cod_pai_nacionalidad = p.cod_pais
         and f.cod_persona = v_cod_persona;
    elsif p_tipo = 14 then
      -- Estado Civil   --
      Select upper(r.significado)
        into v_return
        from ba_cod_referencias r, ba_per_fisicas f
       where r.val_minimo = f.est_civil
         and f.cod_persona = v_cod_persona
         and r.dominio = 'COD_EST_CIVIL';
    elsif p_tipo = 15 then
      -- Oficina --
      Select fue_obt_des_oficina(c.cod_oficina)
        into v_return
        from ge_clientes c
       where c.cod_persona = v_cod_persona;
    elsif p_tipo = 16 then
      -- Oficial --
      Select c.cod_usu_oficial
        into v_return
        from ge_clientes c
       where c.cod_persona = v_cod_persona;
    elsif p_tipo = 17 then
      -- Usuario de Alta --
      -- DYDMR-1729 Estaba trayendo el usuario que insertó la persona de GE_CLIENTES,
      -- se ajusta para que traiga el usuario que insertó la cuenta de ge_cta_clientes
      select fue_obt_nom_usuario(c.usu_insercion)
        into v_return
        from ge_cta_clientes c
       where c.nro_cuenta =p_nro_cuenta
           and c.relacion='P';
    elsif p_tipo = 18 then
      -- Fecha de Apertura --
         Select cod_modulo
           into v_cod_modulo
           from ge_cuentas
          where nro_cuenta = p_nro_cuenta;
          if v_cod_modulo = 3 then -- Cajas de Ahorro
               Select trunc(fec_insercion)
                 into v_return
                 from ah_cta_vistas
                where nro_cuenta =p_nro_cuenta ;
          elsif   v_cod_modulo = 4 then -- Cuentas Corrientes
               Select trunc(fec_insercion)
                 into v_return
                 from cc_cta_corrientes
                where nro_cuenta = p_nro_cuenta;
          else -- Otras Cuentas
                v_return := fug_obt_dat_operaciones(p_nro_cuenta, 'F');
          end if;
    elsif p_tipo = 19 then
      -- Corte Infonet --
      select max(to_char(t.fec_grabacion,'hh24:mi:ss'))
        into v_return
        from ah_tar_debitos t
       where t.nro_cuenta = p_nro_cuenta;
     elsif p_tipo = 20 then
        -- Fecha de Contrato --
         select p.val_parametro
           into v_return
           from ba_cod_referencias t, ge_par_entes p
          where t.abreviatura = p.parametro
            and t.dominio = 'CON_ENT_PAG_SUELDOS'
            and t.val_minimo = '07'
            and p.cod_ente = fue_obt_cod_ent_per(v_cod_persona);
    end if;
 exception
    when others then
        v_return := '' ;
    end;
    return v_return;
 end;
------------------------pr_tas_reales----------------------------------
PROCEDURE pr_tas_reales
IS

--variales de fecha--
v_ano_mes_anterior varchar2(6) :=  to_char(pag_cal.FU_OBT_FEC_ACTUAL(1),'yyyymm');

CURSOR cu_tas_reales IS
select NRO_CUENTA,
       COD_MODULO,
       COD_MODALIDAD,
       CANT_DIAS,
       SEMANA
  from TAS_REAL_MENSUAL
 where substr(semana,0,6)= v_ano_mes_anterior
 order by 1;

  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'CTA_PLAZOS'; -- nombre del archivo
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
  select pag_cal.FU_OBT_FEC_ACTUAL(1)
  into v_fec_sist
  from dual;

  v_fecha := to_char(v_fec_sist,'DDMMYYYY');

  -- Abrir archivo
  v_file := UTL_FILE.FOPEN(pa_rep_aut.g_repository,v_name||'.txt','W',32767);

  -- Colocar el titulo a los campos
  v_linetit := 'NRO_CUENTA'||CHR(9)||
               'COD_MODULO'||CHR(9)||
               'COD_MODALIDAD'||CHR(9)||
               'CANT_DIAS'||CHR(9)||
               'SEMANA';

  utl_file.put_line(v_file,v_linetit);

  -- Definir una linea en blanco para separar los datos del titulo de los campos
  v_linetit := ' ';
  utl_file.put_line(v_file,v_linetit);

  --Definir un cursor for loop que recorre los datos obtenidos
  FOR REC IN cu_tas_reales LOOP

  --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))

    v_line := to_char(rec.NRO_CUENTA)||chr(9)||
              to_char(rec.COD_MODULO)||chr(9)||
              to_char(rec.COD_MODALIDAD)||chr(9)||
              to_char(rec.CANT_DIAS) ;

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

    EXIT WHEN cu_tas_reales%NOTFOUND;
  END LOOP;
  --Escribes la linea en el fichero
  UTL_FILE.PUT_LINE(v_file, v_buffer);

  --Cerrar el handler al fichero
  UTL_FILE.FCLOSE(v_file);
  COMMIT;

    v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

    -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
    v_respuesta := pa_file_ftp.fu_put_ascii(pa_rep_aut.g_ip, pa_rep_aut.g_port,
    pa_rep_aut.g_user,pa_rep_aut.g_pass, pa_rep_aut.g_repository,v_name||'.txt', g_amaral||v_name||'_'||v_fecha||'.txt');

    v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

    IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
        -- Obtenemos los direcciones de correo para quien o quienes va el correo
        v_para := pa_rep_aut.FU_OBT_VALOR_PAR('RA','REPORTES','CTA_PLAZOS');

        -- Damos valor a los demas datos
        v_asunto := 'Tasas reales mensuales a la fecha '||v_fec_sist||'.';
        v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_contabilidad||'

      Nombre del Archivo: '||v_name||'_'||v_fecha||'.txt';

       -- Enviamos el mail
        v_det_error    := null;
        v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

        BEGIN
          it_mail.mail(pa_rep_aut.g_envia_mail,v_para,v_asunto,v_mje_mail);
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
       v_para := pa_rep_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

      -- Damos valor a los demas datos
        v_asunto := 'Error Tasas Reales a la fecha '||v_fec_sist||'.';
        v_mje_mail := 'Error al enviar archivo por FTP.

      Error: '||v_respuesta||'.

      Para mas información verificar la tabla GE_RA_LOG_FTP';

        v_hini_mail := to_char(sysdate,'hh24:mi:ss');

        BEGIN
          it_mail.mail(pa_rep_aut.g_envia_mail,v_para,v_asunto,v_mje_mail);
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
END pr_tas_reales;
------------------------pr_tas_reales----------------------------------

-- Informe Detallado de envío de Encaje Legal al BCP (MT998)
PROCEDURE prs_snp_inf_enc_legal
IS

CURSOR dat_mje_swift(p_fecha IN DATE) IS
  select a.plazo_de,
         a.plazo_a,
         a.moneda,
         a.fecha,
         DECODE(a.moneda, 'PYG', replace(a.monto, ',', ''), a.monto) monto
    from table(fug_obt_msj_swift(p_fecha))a;

  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'inf_det_enc_legal'; -- nombre del archivo
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
  -- Se halla la ultima fecha disponible de la Planilla de Encaje Legal Diaria.
  select nvl(max(fecha),sysdate)
    into v_fec_enc_legal
    from sb_enc_circular254;

  -- Obtenemos la fecha del sistema
  select pag_cal.FU_OBT_FEC_ACTUAL(1)
    into v_fec_sist
    from dual;

  v_fecha := to_char(v_fec_sist,'DDMMYYYY');

  -- Abrir archivo
  v_file := UTL_FILE.FOPEN(pa_rep_aut.g_repository,v_name||'.txt','W',32767);

  -- Colocar el titulo a los campos
  v_linetit := 'PLAZO_DE'||CHR(9)||
               'PLAZO_A'||CHR(9)||
               'MONEDA'||CHR(9)||
               'FECHA'||CHR(9)||
               'MONTO';

  utl_file.put_line(v_file,v_linetit);

  -- Definir una linea en blanco para separar los datos del titulo de los campos
  v_linetit := ' ';
  utl_file.put_line(v_file,v_linetit);

  --Definir un cursor for loop que recorre los datos obtenidos
  FOR REC IN dat_mje_swift(v_fec_enc_legal) LOOP

  --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))

    v_line := to_char(rec.PLAZO_DE)||chr(9)||
              to_char(rec.PLAZO_A)||chr(9)||
              to_char(rec.MONEDA)||chr(9)||
              to_char(rec.FECHA)||chr(9)||
              to_char(rec.MONTO) ;

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

    EXIT WHEN dat_mje_swift%NOTFOUND;
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
                                            v_name||'.txt', g_contabilidad||v_name||'_'||v_fecha||'.txt');

    v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

    IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
        -- Obtenemos los direcciones de correo para quien o quienes va el correo
        v_para := pa_rep_aut.FU_OBT_VALOR_PAR('RA','REPORTES','ENCAJE_LEGAL');

        -- Damos valor a los demas datos
        v_asunto := 'Informe Detallado de Envío de Encaje Legal a BCP(MT998) de fecha '||v_fec_enc_legal||'.';
        v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_contabilidad||'

      Nombre del Archivo: '||v_name||'_'||v_fecha||'.txt';

       -- Enviamos el mail
        v_det_error    := null;
        v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

        BEGIN
          it_mail.mail(pa_rep_aut.g_envia_mail,v_para,v_asunto,v_mje_mail);
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
       v_para := pa_rep_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

      -- Damos valor a los demas datos
        v_asunto := 'Error Informe Detallado de Envío de Encaje Legal a BCP(MT998) de fecha '||v_fec_enc_legal||'.';
        v_mje_mail := 'Error al enviar archivo por FTP.

      Error: '||v_respuesta||'.

      Para mas información verificar la tabla GE_RA_LOG_FTP';

        v_hini_mail := to_char(sysdate,'hh24:mi:ss');

        BEGIN
          it_mail.mail(pa_rep_aut.g_envia_mail,v_para,v_asunto,v_mje_mail);
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
END prs_snp_inf_enc_legal;
-----------------------------------------------------------------------
------------ Movimiento de Depositos Mayores a 10.000 USD por oficina y General ---------------------------
PROCEDURE pr_mov_dep_oficina IS
  --LARCE 12/02/2015
  v_fec_actual    DATE DEFAULT pag_cal.fu_obt_fec_actual(1);
  v_dir_mail_cre  ge_par_dinamicos.val_parametro%type;
  v_adjunto       CLOB;
  v_adjunto2      CLOB;
  v_cabecera      CLOB;
  v_nom_adj       VARCHAR2(500);

  -- Variables para mail
  v_asunto      VARCHAR2(2000);
  v_ofi         ba_oficinas.cod_oficina%TYPE;
  v_ofi_ant     ba_oficinas.cod_oficina%TYPE;
  v_ctrol       NUMBER(9)DEFAULT 0;
  v_dir_mail    ba_personas.dir_correo%type DEFAULT fug_obt_dir_correo;
  v_message     VARCHAR2(300);
  v_cab_message CLOB;
  v_error       VARCHAR2(4000);
  v_sucursal    ba_oficinas.descripcion%TYPE;
  v_mto         ge_par_dinamicos.val_parametro%TYPE DEFAULT fug_obt_pardinamico('OPE_SUP_MON_FUERTE');

--Cursor detalle de depósitos por oficina
 CURSOR c_depo_suc is
 select (select a.cod_oficina
          from ge_clientes a
         where a.cod_persona = cc.cod_persona ) cod_oficina,
       fue_obt_des_oficina((select a.cod_oficina
                             from ge_clientes a
                            where a.cod_persona = cc.cod_persona )) Sucursal,
       cc.cod_persona Numero_cliente,
       fug_obt_nom_cuenta(t.nro_cuenta) Nombre_cliente,
       fug_obt_gestor(cc.cod_persona) Gestor,
       t.nro_cuenta,
       decode(t.cod_moneda,'USD',to_char(t.Monto,'9g999g999g999g999d09'),to_char(t.Monto,'99g999g999g999g999')) Monto_depositado,
       t.cod_moneda Moneda
  from GE_MOVIMIENTOS t, ba_oficinas ba, ge_cta_clientes cc
 where t.nro_cuenta = cc.nro_cuenta
   and ba.cod_oficina = cc.cod_oficina
   and cc.relacion = 'P'
   and t.cod_tra_padre in (350, 371, 393, 452) -- A solicitud de Antonella Merlo se sacó la 351
   and t.estado = 'N'
   and t.reversado = 'N'
   AND NOT exists
                  (select 1
                     from Cj_Cajas a
                    where a.tipo = 'S'
                      and a.nro_caja = t.nro_caja)
    and fub_con_mon_a_moneda(t.cod_moneda,'USD',t.monto,null,v_fec_actual) > v_mto
  order by cod_oficina;

  PROCEDURE lp_env_mail_xls(p_dir_mail VARCHAR2, p_dir_mail_cre VARCHAR2, p_asunto VARCHAR2, p_message VARCHAR2, p_adjunto CLOB, p_nom_arc VARCHAR2) IS
  v_det_error ge_ra_log_mail.det_error%type;
  v_hini_mail ge_ra_log_mail.hor_inicio%type;
  v_hfin_mail ge_ra_log_mail.hor_fin%type;

     BEGIN
       v_det_error := NULL;
       v_hini_mail    := to_char(sysdate,'hh24:mi:ss');
       it_mail.mail_attach_xls(p_dir_mail, p_dir_mail_cre, p_asunto,p_message,p_adjunto,p_nom_arc);
     EXCEPTION
       WHEN OTHERS THEN
        v_det_error := substr(sqlerrm,1,4000);
        v_hfin_mail := to_char(sysdate,'hh24:mi:ss');
        -- Insertamos en la tabla de log  si ocurrio algun error al enviar el mail
        INSERT INTO ge_ra_log_mail
                   (fec_envio, nom_archivo, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
              VALUES
                   (SYSDATE, v_nom_adj || '.xls', p_dir_mail_cre, p_asunto, v_det_error, v_hini_mail, v_hfin_mail);
              COMMIT;
     END;

  -----------------------------
  --Inicio Programa Principal--
  -----------------------------
  BEGIN
     -- Titulos de las columnas.
     v_cabecera := chr(10)||'Sucursal' || chr(9) || 'Nro_Cliente' || chr(9) || 'Nombre_Cliente' ||
                chr(9) || 'Gestor' || chr(9) ||'Nro_Cuenta' || chr(9) ||
                'Monto_Depósito' || chr(9) || 'Moneda' ||chr(10);
     --
     v_message := 'Depósitos de la Sucursal';
     v_cab_message :='Fecha Informe:'||CHR(9) ||to_char(SYSDATE,'dd/mm/yyyy hh24:mi:ss')||chr(10) || CHR(9) || CHR(9) ||
                     'DEPOSITOS MAYORES A 10.000 USD' || CHR(10) ||
                     v_cabecera;
     v_asunto:= 'Depósitos mayores a 10.000 USD - Sucursal ';
     for k in c_depo_suc loop --por depósito.
         v_ctrol := v_ctrol +1;
         if v_ctrol = 1 then
           v_ofi_ant := k.cod_oficina;
           v_ofi:= k.cod_oficina;
         else
           v_ofi_ant := v_ofi;
           v_ofi := k.cod_oficina;
         end if;
          v_adjunto2 := v_adjunto2 || k.sucursal || chr(9) ||k.numero_cliente || chr(9) ||k.nombre_cliente || chr(9) ||
                       k.gestor || chr(9) ||k.nro_cuenta || chr(9)||  k.Monto_depositado ||chr(9)|| k.moneda|| chr(10);

         if v_ofi_ant = v_ofi then
             v_adjunto := v_adjunto || k.sucursal || chr(9) ||k.numero_cliente || chr(9) ||k.nombre_cliente || chr(9) ||
                          k.gestor || chr(9) || k.nro_cuenta || chr(9)|| k.Monto_depositado ||chr(9)|| k.moneda|| chr(10);

          else
           v_dir_mail_cre:= fug_obt_pardinamico('LDI_DIR_SUC',null,null,null,v_ofi_ant) ;
           v_nom_adj := 'DEP_' || fue_obt_des_oficina(v_ofi_ant) || '_' ||to_char(v_fec_actual, 'DDMMYY');
           v_sucursal := fue_obt_des_oficina(v_ofi_ant);
           -- -- Envío de mail a la sucursal que corresponde.
              lp_env_mail_xls(v_dir_mail,v_dir_mail_cre,v_asunto||v_sucursal,v_message||' '||v_sucursal,v_cab_message||v_adjunto,v_nom_adj||'.xls');

           v_adjunto := k.sucursal || chr(9) || k.numero_cliente || chr(9) ||k.nombre_cliente || chr(9) ||
                       k.gestor || chr(9) || k.nro_cuenta || chr(9)|| k.Monto_depositado ||chr(9)||  k.moneda|| chr(10);
          end if;
     end loop;

     -- Ultimo mail
        v_dir_mail_cre:= fug_obt_pardinamico('LDI_DIR_SUC',null,null,null,v_ofi) ;
        v_nom_adj := 'DEP_' || fue_obt_des_oficina(v_ofi) || '_' ||to_char(v_fec_actual, 'DDMMYY');
        v_sucursal := fue_obt_des_oficina(v_ofi);
         -- -- Envío de mail a la sucursal que corresponde.
            lp_env_mail_xls(v_dir_mail,v_dir_mail_cre,v_asunto||v_sucursal,v_message||' '||v_sucursal,v_cab_message||v_adjunto,v_nom_adj||'.xls');

     -- Envía el mail a Cumplimiento Normativo.
     v_dir_mail_cre:= fug_obt_pardinamico('LDI_DIR_CORREO') ;
     v_nom_adj := 'DEP_SUCURSALES'||'_' || to_char(v_fec_actual, 'DDMMYY');
     v_asunto   := 'Depósitos mayores a 10.000 USD de todas las sucursales';
     v_message := 'Depósitos de todas las Sucursales.';
     -- Envia el mail a Cumplimiento Normativo con listado de Deposito de Todas las Sucursales.
        lp_env_mail_xls(v_dir_mail,v_dir_mail_cre,v_asunto,v_message,v_cab_message||v_adjunto2,v_nom_adj||'.xls');

EXCEPTION
 WHEN OTHERS THEN
   v_error := substr(sqlerrm,1,4000);
    INSERT INTO ge_ra_log_mail
               (fec_envio, nom_archivo, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
         VALUES
               (SYSDATE, 'DEP_SUCURSAL_X.xls', 'ERROR', 'Error en el procedimiento PR_MOV_DEP_OFICINA',  v_error, to_char(sysdate,'hh24:mi:ss'), to_char(sysdate,'hh24:mi:ss'));
         COMMIT;
  END;

PROCEDURE pr_ope_renegociacion IS
  --variable de fecha del parámetro dinámico
   v_fec_ini          ge_par_dinamicos.val_parametro%TYPE := FUG_OBT_PARDINAMICO('FEC_INI_OPE');
   v_fec_fin          ge_par_dinamicos.val_parametro%TYPE := FUG_OBT_PARDINAMICO('FEC_FIN_OPE');
   v_cod_persona      ge_par_dinamicos.val_parametro%TYPE := TRIM(FUG_OBT_PARDINAMICO('COD_PERSONA_OPE'));
   
CURSOR cur_cta_principal IS
   Select P.NRO_CUENTA,
          P.COD_MODALIDAD,
          FUG_OBT_DES_MODALIDAD(P.COD_MODALIDAD) DES_OPE_MAD,
          P.FEC_INICIO,
          P.FEC_VENCIMIENTO,
          P.COD_MONEDA,
          P.MTO_CAPITAL,
          P.FEC_VENCIMIENTO - P.FEC_INICIO PLAZO,
          P.VAL_TASA,
          P.TIPO,
          FUE_OBT_DES_REFCODES('TIP_PRESTAMO', P.TIPO) DES_PRESTAMO,
          P.TIP_RENOVACION,
          FUE_OBT_DES_REFCODES('TIP_RENOVACION', P.TIP_RENOVACION) DES_RENEGOCIACION,
          P.COD_OFICINA COD_OFICINA,
          FUE_OBT_DES_OFICINA(P.COD_OFICINA) DES_OFICINA,
          P.ESTADO COD_ESTADO,
          FUE_OBT_DES_REFCODES('ESTADO', P.ESTADO) DES_ESTADO,
          P.COD_PERSONA,
          FUE_OBT_NOM_PERSONA(P.COD_PERSONA) NOM_PERSONA ,
          P.DIA_ATRASO DIA_ATRASO,
          P.COD_USUARIO
     From (Select PR.NRO_CUENTA,
                  PR.COD_MODALIDAD,
                  PR.FEC_INICIO,
                  PR.FEC_VENCIMIENTO,
                  PR.COD_MONEDA,
                  PR.MTO_CAPITAL,
                  PR.VAL_TASA,
                  PR.TIPO,
                  PR.TIP_RENOVACION,
                  PR.COD_OFICINA,
                  PR.ESTADO,
                  C.COD_PERSONA,
                  NVL(PR.DIA_ATRASO, 0) DIA_ATRASO,
                  PG.COD_USUARIO
             From PR_CTA_PRESTAMOS PR,
                  GE_CTA_CLIENTES  C,
                  (Select * From PR_SOL_GESTIONES D Where D.ESTADO = 'L') PG
            Where PR.NRO_CUENTA = C.NRO_CUENTA
              AND PR.NRO_SOLICITUD = PG.NRO_SOLICITUD
              And NVL(C.RELACION, 'X') = 'P'
              And PR.ESTADO != 'N'
              And PG.FECHA = (Select Max(Q.FECHA)
                                From PR_SOL_GESTIONES Q
                               Where Q.NRO_SOLICITUD = PR.NRO_SOLICITUD
                                 And Q.ESTADO = 'L')) P
    Where P.FEC_INICIO BETWEEN to_date(v_fec_ini,'dd/mm/yyyy') AND to_date(v_fec_fin,'dd/mm/yyyy')
     And P.COD_PERSONA = nvl(v_cod_persona, P.COD_PERSONA);
      

-- DYDMR-5263 - Incidencia SAU - ITGF - Informe que Contenga Operaciones
-- Prestamos Vigentes con sus Respectivas Cuentas Renovadas hasta la Cuenta Madre o Inicial     
Cursor  cur_cta_cancelada (p_cta_renovada pr_cta_prestamos.nro_cuenta%type)is 
 Select A.NRO_CUENTA      CTA_PRINCIPAL,
        LEVEL             nivel,
        a.nro_cta_renovada nro_cta_renovada ,
        A.FEC_CANCELACION FEC_CANCEL,
        A.MTO_CAPITAL     MTO_CAP_CTA_RENOVADA,
        FUE_OBT_DES_REFCODES('TIP_RENOVACION', A.TIP_RENOVACION) TIP_REN_CTA_RENOVADA,
        G.COD_USUARIO     USU_CTA_RENOVADA,
        A.FEC_INICIO      FEC_INI_RENOVADA,
        A.FEC_VENCIMIENTO FEC_VEN_RENOVADA
   From PR_CTA_PRESTAMOS A,
        (Select * From PR_SOL_GESTIONES D Where D.ESTADO = 'L') G
  Where A.NRO_SOLICITUD = G.NRO_SOLICITUD
    And G.FECHA = (Select Max(Q.FECHA)
                     From PR_SOL_GESTIONES Q
                    Where Q.NRO_SOLICITUD = A.NRO_SOLICITUD
                      And Q.ESTADO = 'L')
     and a.estado != 'C'
     START WITH a.nro_cuenta =  p_cta_renovada  
     CONNECT BY PRIOR a.nro_cuenta = a.nro_cta_renovada
     ORDER BY nivel ASC;
         
  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'OPE_RENEGOCIACION'; -- nombre del archivo
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

  -- Variables para archivo
  v_existe                    boolean;
  v_cta_principal             pr_cta_prestamos.nro_cuenta%type;
  v_cta_renovada              pr_cta_prestamos.nro_cta_renovada%type;
  v_cta_actual                pr_cta_prestamos.nro_cuenta%type;
  v_cta_anterior              pr_cta_prestamos.nro_cuenta%type;
  v_cont_cursor               number(9):= 0;
  v_fec_cancel                date;
  v_mto_cap_cta_renovada      pr_cta_prestamos.mto_capital%type;
  v_tip_ren_cta_renovada      cg_ref_codes.rv_abbreviation%type;
  v_usu_cta_renovada          ge_clientes.cod_usu_oficial%type;
  v_fec_ini_renovada          pr_cta_prestamos.fec_inicio%type;
  v_fec_ven_renovada          pr_cta_prestamos.fec_vencimiento%type;
  v_error_fecha               EXCEPTION;

BEGIN
  IF v_fec_ini IS NOT NULL AND v_fec_fin IS NOT NULL THEN
        -- Obtenemos la fecha del sistema
        v_fec_sist := to_char(pag_cal.FU_OBT_FEC_ACTUAL(1),'DDMMYYYY') ;
        v_fecha := to_char(v_fec_sist,'DDMMYYYY');

      -- Abrir archivo
      v_file := UTL_FILE.FOPEN(pag_evo.g_repository,v_name||'.XLS','W',32767);

      --Coloca titulo del informe
      v_linetit :=CHR(9)||CHR(9)||CHR(9)||CHR(9)||'INFORME DE OPERACIONES DE RENEGOCIACION DE PRESTAMO';
      utl_file.put_line(v_file,v_linetit);

      -- Colocar el titulo a los campos
      v_linetit := 'NRO.CUENTA'               ||CHR(9)||'TIPO OPERACION/MODALIDAD'  ||CHR(9)||'DESC.TIPO OPERACION/MODALIDAD'  ||CHR(9)||
                   'FECHA INICIO'             ||CHR(9)||'FECHA VENCIMIENTO'         ||CHR(9)||'MONEDA'                         ||CHR(9)||
                   'MONTO CAPITAL'            ||CHR(9)||'PLAZO'                     ||CHR(9)||'TASA'                           ||CHR(9)||
                   'TIPO PRESTAMO'            ||CHR(9)||'DESC.PRESTAMO'             ||CHR(9)||'TIPO RENEGOCIACION'             ||CHR(9)||
                   'DESC.RENEGOCIACION'       ||CHR(9)||'COD.USUARIO'               ||CHR(9)||'CTA.RENOVADA'                   ||CHR(9)||
                   'FEC.CANCELACION'          ||CHR(9)||'MONTO CAPITAL CTA.RENOVADA'||CHR(9)||'TIPO RENEGOCIACIÓN CTA.RENOVADA'||CHR(9)||
                   'COD.USUARIO CTA.RENOVADA' ||CHR(9)||'FEC.INICIO CTA.RENOVADA'   ||CHR(9)||'FEC. VENC. CTA.RENOVADA'        ||CHR(9)||
                   'COD.OFICINA'              ||CHR(9)||'DESC.OFICINA'              ||CHR(9)||'COD.ESTADO'                     ||CHR(9)||
                   'DESC.ESTADO'              ||CHR(9)||'COD.PERSONA'               ||CHR(9)||'NOMBRE PERSONA'                 ||CHR(9)||
                   'DIAS ATRASO';
      
      utl_file.put_line(v_file,v_linetit);
 
      --Definir un cursor for loop que recorre las cuentas principales
      FOR REC IN cur_cta_principal LOOP
         V_EXISTE := TRUE;
         v_cont_cursor := v_cont_cursor + 1;
         IF v_cont_cursor = 1 THEN
           v_cta_actual := rec.nro_cuenta;
           v_cta_anterior := rec.nro_cuenta;
         ELSE
          v_cta_anterior := v_cta_actual;
          v_cta_actual := rec.nro_cuenta;
         END IF;
        v_line := rec.NRO_CUENTA        ||chr(9)||rec.COD_MODALIDAD  ||chr(9)||rec.DES_OPE_MAD   ||chr(9)||
                  rec.FEC_INICIO        ||chr(9)||rec.FEC_VENCIMIENTO||chr(9)||rec.COD_MONEDA    ||chr(9)||
                  rec.MTO_CAPITAL       ||chr(9)||rec.PLAZO          ||chr(9)||rec.VAL_TASA      ||chr(9)||
                  rec.TIPO              ||chr(9)||rec.DES_PRESTAMO   ||chr(9)||rec.TIP_RENOVACION||chr(9)||
                  rec.DES_RENEGOCIACION ||chr(9)||rec.COD_USUARIO    ||chr(9)||NULL              ||chr(9)||
                  NULL                  ||chr(9)||NULL               ||chr(9)||NULL              ||chr(9)||
                  NULL                  ||chr(9)||NULL               ||chr(9)||NULL              ||chr(9)||
                  rec.COD_OFICINA       ||chr(9)||rec.DES_OFICINA    ||chr(9)||rec.COD_ESTADO    ||chr(9)||
                  rec.DES_ESTADO        ||chr(9)||rec.COD_PERSONA    ||chr(9)||rec.NOM_PERSONA   ||chr(9)||
                  rec.DIA_ATRASO;

 
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
      
    
    FOR c_can IN cur_cta_cancelada(REC.NRO_CUENTA) LOOP  
          v_lines := v_lines + 1;

-- DYDMR-5263 - Incidencia SAU - ITGF - Informe que Contenga Operaciones
-- Prestamos Vigentes con sus Respectivas Cuentas Renovadas hasta la Cuenta Madre o Inicial                     
             /* IF v_existe THEN*/
                v_line := rec.NRO_CUENTA        ||chr(9)||NULL                  ||chr(9)||NULL                  ||chr(9)||
                          NULL                  ||chr(9)||NULL                  ||chr(9)||NULL                  ||chr(9)||
                          NULL                  ||chr(9)||NULL                  ||chr(9)||NULL                  ||chr(9)||
                          NULL                  ||chr(9)||NULL                  ||chr(9)||NULL                  ||chr(9)||
                          NULL                  ||chr(9)||NULL                  ||chr(9)||c_can.cta_principal   ||chr(9)||
                          c_can.FEC_CANCEL          ||chr(9)||c_can.MTO_CAP_CTA_RENOVADA||chr(9)||c_can.TIP_REN_CTA_RENOVADA||CHR(9)||
                          c_can.USU_CTA_RENOVADA    ||chr(9)||c_can.FEC_INI_RENOVADA    ||chr(9)||c_can.FEC_VEN_RENOVADA    ||chr(9)||
                          NULL                  ||chr(9)||NULL                  ||chr(9)||NULL                  ||chr(9)||
                          NULL                  ||chr(9)||rec.COD_PERSONA       ||chr(9)||rec.NOM_PERSONA       ||chr(9)||
                          NULL;


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
          -- DYDMR-5263 - Incidencia SAU - ITGF - Informe que Contenga Operaciones
          -- Prestamos Vigentes con sus Respectivas Cuentas Renovadas hasta la Cuenta Madre o Inicial   
              /*END IF;*/
          /* END LOOP;*/
          
          EXIT WHEN cur_cta_cancelada%NOTFOUND;
          END LOOP;

         EXIT WHEN cur_cta_principal%NOTFOUND;
      END LOOP;
      --Escribes la linea en el fichero
      UTL_FILE.PUT_LINE(v_file, v_buffer);

      --Cerrar el handler al fichero
      UTL_FILE.FCLOSE(v_file);

        v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

        -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
        v_respuesta := pa_file_ftp.fu_put_ascii(pag_evo.g_ip,
                                                pag_evo.g_port,
                                                pag_evo.g_user,
                                                pag_evo.g_pass,
                                                pag_evo.g_repository,
                                                v_name||'.XLS',
                                                g_riesgos||v_name||'_'||v_fecha||'.XLS');

        v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

        IF v_respuesta != 'OK' THEN  --ARCHIVO ENVIADO POR FTP ; ERROR AL ENVIAR ARCHIVO POR FTP
          v_det_error    := null;

          -- Insertamos el error del envio al directorio compartido
          INSERT INTO ge_ra_log_ftp
           (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
          VALUES
           (SYSDATE, v_name||'.XLS', v_respuesta, v_hini_ftp, v_hfin_ftp);

          --Enviamos el mail a soporte
           -- Obtenemos direccion de correo de soporte
           v_para := pag_evo.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

          -- Damos valor a los demas datos
            v_asunto := 'Error Reporte Operaciones de Renegociación Detallado a la fecha '||v_fec_sist||'.';
            v_mje_mail := 'Error al enviar archivo por FTP.Error: '||v_respuesta||'.Para mas información verificar la tabla GE_RA_LOG_FTP';
            v_hini_mail := to_char(sysdate,'hh24:mi:ss');

            BEGIN
              it_mail.mail(pag_evo.g_envia_mail,v_para,v_asunto,v_mje_mail);
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
                 (SYSDATE, v_name||'.XLS', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
           END IF;

        END IF;

     COMMIT;
ELSE
  RAISE v_error_fecha;
END IF;

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
  WHEN v_error_fecha THEN
    RAISE_APPLICATION_ERROR(-20066,'Error de Fechas : Ingrese fechas validas');
   WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20067,'Error Inesperado :'||sqlerrm);
END pr_ope_renegociacion;

PROCEDURE pr_cua_pre_cierre IS
  -- Variables de fechas
  v_fec_sist         DATE;
  v_fecha            VARCHAR2(8);

---GENERA EL ARCHIVO CUADRE_PRE_CIERRE_USU_DIA
PROCEDURE LP_GEN_ARC_RES_GENERAL(P_FECHA DATE) IS

 --VARIABLES PARA ARCHIVO
  v_file      UTL_FILE.FILE_TYPE;
  v_line      VARCHAR2(32767);
  v_linetit   VARCHAR2(2000);
  v_buffer    VARCHAR2(32767);
  v_lines     PLS_INTEGER := 0;
  v_eol       CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen    CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline   CONSTANT PLS_INTEGER := 32767;
  v_formato   VARCHAR2(25):= '999g999g999g999g999d00';
  v_name      VARCHAR2(128) := 'CUADRE_PRE_CIERRE_USU_DIA';-- nombre del archivo

 -- Variables para FTP
  v_respuesta VARCHAR2(4000);
  v_hini_ftp  ge_ra_log_ftp.hor_inicio%type;
  v_hfin_ftp  ge_ra_log_ftp.hor_fin%type;

 CURSOR CUR_CUADRE_GRAL IS --resumen general
     SELECT COD_USUARIO USUARIO,
            SUM(DECODE(TIP_MOV_RUBRO, 'D', MTO_EQU_LOCAL, 0)) "TOT_DEBITO",
            SUM(DECODE(TIP_MOV_RUBRO, 'C', MTO_EQU_LOCAL, 0)) "TOT_CREDITO",
            SUM(DECODE(TIP_MOV_RUBRO, 'D', MTO_EQU_LOCAL, 0)) -
            SUM(DECODE(TIP_MOV_RUBRO, 'C', MTO_EQU_LOCAL, 0)) "TOT_DIFERENCIA"
       FROM GE_ASIENTOS_TMP T
      WHERE TIP_MOV_RUBRO IS NOT NULL
        AND T.FECHA = P_FECHA
   GROUP BY COD_USUARIO
     HAVING NVL(SUM(DECODE(TIP_MOV_RUBRO, 'D', MTO_EQU_LOCAL, 0)), 0) != NVL(SUM(DECODE(TIP_MOV_RUBRO, 'C', MTO_EQU_LOCAL, 0)), 0)
   ORDER BY 1,2,3;
BEGIN
  -- Abrir archivo
  v_file := UTL_FILE.FOPEN(pag_evo.g_repository,v_name||'.txt','W',32767);

  -- Colocar el titulo a los campos
  v_linetit :='USUARIO'||CHR(9)||'DEBITO'||CHR(9)||'CREDITO'||CHR(9)||'TOTAL_DIFERENCIA' ;
  utl_file.put_line(v_file,v_linetit);

  -- Definir una linea en blanco para separar los datos del titulo de los campos
  v_linetit := ' ';
  utl_file.put_line(v_file,v_linetit);

 --Definir un cursor for loop que recorre los datos obtenidos
  FOR REC IN CUR_CUADRE_GRAL LOOP
    --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
    v_line := to_char(rec.usuario)||chr(9)||to_char(rec.Tot_Debito,v_formato)||chr(9)||to_char(rec.Tot_Credito,v_formato)||chr(9)||to_char(rec.Tot_Diferencia,v_formato);
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
    EXIT WHEN CUR_CUADRE_GRAL%NOTFOUND;
  END LOOP;

  --Escribes la linea en el fichero
  UTL_FILE.PUT_LINE(v_file, v_buffer);
  --Cerrar el handler al fichero
  UTL_FILE.FCLOSE(v_file);

  /*
   Se envia mediante FTP el archivo generado a Servidor de archivos
  */
   v_hini_ftp := to_char(sysdate,'hh24:mi:ss');
    -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
    v_respuesta := pa_file_ftp.fu_put_ascii(pag_evo.g_ip, pag_evo.g_port, pag_evo.g_user,
                                            pag_evo.g_pass, pag_evo.g_repository,
                                            v_name||'.txt', pag_evo.g_contabilidad||v_name||'_'||v_fecha||'.txt');


    v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');
   IF v_respuesta != 'OK' THEN  -- ERROR AL ENVIAR ARCHIVO POR FTP
      -- Insertamos el error del envio al directorio compartido
      INSERT INTO ge_ra_log_ftp
       (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
      VALUES
       (SYSDATE, v_name||'_'||v_fecha||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
     COMMIT;
    END IF;

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

---GENERA EL ARCHIVO CUADRE_PRE_CIERRE_HORA_DIA
PROCEDURE LP_GEN_ARC_RES_DET1(P_FECHA DATE) IS

  --VARIABLES PARA ARCHIVO
  v_file      UTL_FILE.FILE_TYPE;
  v_line      VARCHAR2(32767);
  v_linetit   VARCHAR2(2000);
  v_buffer    VARCHAR2(32767);
  v_lines     PLS_INTEGER := 0;
  v_eol       CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen    CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline   CONSTANT PLS_INTEGER := 32767;
  v_formato   VARCHAR2(25):= '999g999g999g999g999d00';
  v_name      VARCHAR2(128) := 'CUADRE_PRE_CIERRE_HORA_DIA'; -- nombre del archivo

 -- Variables para FTP
  v_respuesta VARCHAR2(4000);
  v_hini_ftp  ge_ra_log_ftp.hor_inicio%type;
  v_hfin_ftp  ge_ra_log_ftp.hor_fin%type;

 CURSOR CUR_CUADRE_DET1 IS --RESUMEN DETALLE 1
     SELECT HORA,COD_USUARIO USUARIO,
            SUM(DECODE(TIP_MOV_RUBRO, 'D', MTO_EQU_LOCAL, 0)) "TOT_DEBITO",
            SUM(DECODE(TIP_MOV_RUBRO, 'C', MTO_EQU_LOCAL, 0)) "TOT_CREDITO",
            SUM(DECODE(TIP_MOV_RUBRO, 'D', MTO_EQU_LOCAL, 0)) -
            SUM(DECODE(TIP_MOV_RUBRO, 'C', MTO_EQU_LOCAL, 0)) "TOT_DIFERENCIA"
       FROM GE_ASIENTOS_TMP T
      WHERE TIP_MOV_RUBRO IS NOT NULL
       AND T.FECHA = P_FECHA
   GROUP BY COD_USUARIO,HORA
     HAVING NVL(SUM(DECODE(TIP_MOV_RUBRO, 'D', MTO_EQU_LOCAL, 0)), 0) != NVL(SUM(DECODE(TIP_MOV_RUBRO, 'C', MTO_EQU_LOCAL, 0)), 0)
   ORDER BY 1,2,3;
BEGIN

  -- Abrir archivo
  v_file := UTL_FILE.FOPEN(pag_evo.g_repository,v_name||'.txt','W',32767);

  -- Colocar el titulo a los campos
  v_linetit := 'HORA'||CHR(9)||'USUARIO'||CHR(9)||'DEBITO'||CHR(9)||'CREDITO'||CHR(9)||'TOTAL_DIFERENCIA' ;
  utl_file.put_line(v_file,v_linetit);

  -- Definir una linea en blanco para separar los datos del titulo de los campos
  v_linetit := ' ';
  utl_file.put_line(v_file,v_linetit);

  --Definir un cursor for loop que recorre los datos obtenidos
  FOR REC1 IN CUR_CUADRE_DET1 LOOP
    --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
    v_line := to_char(rec1.hora)||chr(9)||to_char(rec1.usuario)||chr(9)||to_char(rec1.Tot_Debito,v_formato)||chr(9)||to_char(rec1.Tot_Credito,v_formato)||chr(9)||to_char(rec1.Tot_Diferencia,v_formato);
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
    EXIT WHEN CUR_CUADRE_DET1%NOTFOUND;
  END LOOP;

  --Escribes la linea en el fichero
  UTL_FILE.PUT_LINE(v_file, v_buffer);
  --Cerrar el handler al fichero
  UTL_FILE.FCLOSE(v_file);

  /*
   Se envia mediante FTP el archivo generado a Servidor de archivos
  */
   v_hini_ftp := to_char(sysdate,'hh24:mi:ss');
    -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
    v_respuesta := pa_file_ftp.fu_put_ascii(pag_evo.g_ip, pag_evo.g_port, pag_evo.g_user,
                                            pag_evo.g_pass, pag_evo.g_repository,
                                            v_name||'.txt', pag_evo.g_contabilidad||v_name||'_'||v_fecha||'.txt');
    v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');
    IF v_respuesta != 'OK' THEN  -- ERROR AL ENVIAR ARCHIVO POR FTP
      -- Insertamos el error del envio al directorio compartido
      INSERT INTO ge_ra_log_ftp
       (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
      VALUES
       (SYSDATE, v_name||'_'||v_fecha||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
     COMMIT;
    END IF;

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

---GENERA EL ARCHIVO CUADRE_PRE_CIERRE_DET_DIA
PROCEDURE LP_GEN_ARC_RES_DET2(P_FECHA DATE) IS

 --VARIABLES PARA ARCHIVO
  v_file      UTL_FILE.FILE_TYPE;
  v_line      VARCHAR2(32767);
  v_linetit   VARCHAR2(2000);
  v_buffer    VARCHAR2(32767);
  v_lines     PLS_INTEGER := 0;
  v_eol       CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen    CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline   CONSTANT PLS_INTEGER := 32767;
  v_formato   VARCHAR2(25):= '999g999g999g999g999d00';
  v_name      VARCHAR2(128) := 'CUADRE_PRE_CIERRE_DET_DIA'; --'CUADRE_PRE_CIERRE_DET2_DIA'; -- nombre del archivo

 -- Variables para FTP
  v_respuesta VARCHAR2(4000);
  v_hini_ftp  ge_ra_log_ftp.hor_inicio%type;
  v_hfin_ftp  ge_ra_log_ftp.hor_fin%type;

 CURSOR CUADRE_DET1 IS --RESUMEN DETALLE 1
     SELECT HORA,COD_USUARIO,
            SUM(DECODE(TIP_MOV_RUBRO, 'D', MTO_EQU_LOCAL, 0)) "W_TOTDEBE",
            SUM(DECODE(TIP_MOV_RUBRO, 'C', MTO_EQU_LOCAL, 0)) "W_TOTHABE",
            SUM(DECODE(TIP_MOV_RUBRO, 'D', MTO_EQU_LOCAL, 0)) -
            SUM(DECODE(TIP_MOV_RUBRO, 'C', MTO_EQU_LOCAL, 0)) "TOTAL"
       FROM GE_ASIENTOS_TMP T
      WHERE TIP_MOV_RUBRO IS NOT NULL
       AND T.FECHA = P_FECHA
   GROUP BY COD_USUARIO,HORA
     HAVING NVL(SUM(DECODE(TIP_MOV_RUBRO, 'D', MTO_EQU_LOCAL, 0)), 0) != NVL(SUM(DECODE(TIP_MOV_RUBRO, 'C', MTO_EQU_LOCAL, 0)), 0)
   ORDER BY 1,2,3;

 CURSOR CUR_CUADRE_DET2(P_HORA VARCHAR2,P_FEC DATE, P_USUARIO VARCHAR2) IS --RESUMEN DETALLE 2
     Select ' ' || B.HORA HORA,
            B.COD_USUARIO USUARIO,
            B.COD_OFI_ORIGEN OFI,
            B.NRO_SECUENCIA SEC,
            B.NRO_CUENTA CUENTA,
            B.COD_MONEDA MON,
            B.MONTO,
            B.MTO_EQU_LOCAL MTO_EN_GS,
            B.COD_TRA_PADRE COD_P,
            C.DESCRIPCION TRANSACCION_PADRE,
            B.COD_MODALIDAD COD_M,
            B.COD_TRANSACCION COD_T,
            D.DESCRIPCION TRANSACCION_HIJO,
            B.TIP_MOV_RUBRO TIP,
            SUBSTR(B.COD_RUBRO, 1, 2) || '.' || SUBSTR(B.COD_RUBRO, 3, 1) || '.' ||
            SUBSTR(B.COD_RUBRO, 4, 2) || '.' || SUBSTR(B.COD_RUBRO, 6, 3) || '.' ||
            SUBSTR(B.COD_RUBRO, 3, 1) || '.' || SUBSTR(B.COD_RUBRO, 9, 2) || '.' ||
            SUBSTR(B.COD_RUBRO, 11, 3) || '.' || SUBSTR(B.COD_RUBRO, 14, 2) RUBRO_CONTABLE,
            X.DESCRIPCION DES_RUBRO,
            B.MONTO MTO_ASIENTO,
            DECODE(B.TIP_MOV_RUBRO, 'D', B.MTO_EQU_LOCAL, 0) DEBITO,
            DECODE(B.TIP_MOV_RUBRO, 'C', B.MTO_EQU_LOCAL, 0) CRÉDITO,
            B.OBSERVACION,
            X.COD_RUB_EXTERNO
       FROM CB_RUBROS        X,
            GE_TRANSACCIONES D,
            GE_TRANSACCIONES C,
            GE_ASIENTOS_TMP  B
      WHERE B.COD_MOD_PADRE = C.COD_MODULO(+)
        AND B.COD_MAD_PADRE = C.COD_MODALIDAD(+)
        AND B.COD_TRA_PADRE = C.COD_TRANSACCION(+)
        AND B.COD_MODULO = D.COD_MODULO(+)
        AND B.COD_MODALIDAD = D.COD_MODALIDAD(+)
        AND B.COD_TRANSACCION = D.COD_TRANSACCION(+)
        AND X.COD_RUBRO(+) = B.COD_RUBRO
        AND B.HORA = P_HORA
        AND B.FECHA = P_FEC
        AND B.COD_USUARIO = P_USUARIO
    ORDER BY 1,2,3;
BEGIN

  -- Abrir archivo
  v_file := UTL_FILE.FOPEN(pag_evo.g_repository,v_name||'.txt','W',32767);

  -- Colocar el titulo a los campos
  v_linetit := 'HORA'            ||CHR(9)||'USUARIO'          ||CHR(9)||'OFI'           ||CHR(9)||'SEC'        ||CHR(9)||
               'CUENTA'          ||CHR(9)||'MON'              ||CHR(9)||'MONTO'         ||CHR(9)||'MTO_EN_GS'  ||CHR(9)||
               'COD_P'           ||CHR(9)||'TRANSACCION_PADRE'||CHR(9)||'COD_M'         ||CHR(9)||'COD_T'      ||CHR(9)||
               'TRANSACCION_HIJO'||CHR(9)||'TIP'              ||CHR(9)||'RUBRO_CONTABLE'||CHR(9)||'DES_RUBRO'  ||CHR(9)||
               'MTO_ASIENTO'     ||CHR(9)||'DEBITO'           ||CHR(9)||'CREDITO'       ||CHR(9)||'OBSERVACION'||CHR(9)||
               'COD_RUB_EXTERNO';
  utl_file.put_line(v_file,v_linetit);

  -- Definir una linea en blanco para separar los datos del titulo de los campos
  v_linetit := ' ';
  utl_file.put_line(v_file,v_linetit);

  --Definir un cursor for loop que recorre los datos obtenidos
  FOR REG IN CUADRE_DET1 LOOP
     FOR REC2 IN CUR_CUADRE_DET2(REG.HORA,P_FECHA,REG.COD_USUARIO) LOOP
        --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
        v_line := to_char(rec2.hora)                 ||chr(9)||to_char(rec2.usuario)          ||chr(9)||to_char(rec2.ofi)              ||chr(9)||to_char(rec2.sec)                ||chr(9)||
                  to_char(rec2.cuenta)               ||chr(9)||to_char(rec2.mon)              ||chr(9)||to_char(rec2.monto,v_formato)  ||chr(9)||to_char(rec2.mto_en_gs,v_formato)||chr(9)||
                  to_char(rec2.cod_p)                ||chr(9)||to_char(rec2.transaccion_padre)||chr(9)||to_char(rec2.cod_m)            ||chr(9)||to_char(rec2.cod_t)              ||chr(9)||
                  to_char(rec2.transaccion_hijo)     ||chr(9)||to_char(rec2.tip)              ||chr(9)||to_char(rec2.rubro_contable)   ||chr(9)||to_char(rec2.des_rubro)          ||chr(9)||
                  to_char(rec2.mto_asiento,v_formato)||chr(9)||to_char(rec2.Debito,v_formato) ||chr(9)||to_char(rec2.Crédito,v_formato)||chr(9)||to_char(rec2.observacion)        ||chr(9)||
                  to_char(rec2.cod_rub_externo);
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
       EXIT WHEN CUR_CUADRE_DET2%NOTFOUND;
     END LOOP;
    EXIT WHEN CUADRE_DET1%NOTFOUND;
  END LOOP;

  --Escribes la linea en el fichero
  UTL_FILE.PUT_LINE(v_file, v_buffer);
  --Cerrar el handler al fichero
  UTL_FILE.FCLOSE(v_file);

  /*
   Se envia mediante FTP el archivo generado a Servidor de archivos
  */
   v_hini_ftp := to_char(sysdate,'hh24:mi:ss');
    -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
    v_respuesta := pa_file_ftp.fu_put_ascii(pag_evo.g_ip, pag_evo.g_port, pag_evo.g_user,
                                            pag_evo.g_pass, pag_evo.g_repository,
                                            v_name||'.txt', pag_evo.g_contabilidad||v_name||'_'||v_fecha||'.txt');
    v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

    IF v_respuesta != 'OK' THEN  -- ERROR AL ENVIAR ARCHIVO POR FTP
      -- Insertamos el error del envio al directorio compartido
      INSERT INTO ge_ra_log_ftp
       (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
      VALUES
       (SYSDATE, v_name||'_'||v_fecha||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
     COMMIT;
    END IF;

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
BEGIN
 -- Obtenemos la fecha del sistema
  select pag_cal.FU_OBT_FEC_ACTUAL(1)
  into v_fec_sist
  from dual;
  v_fecha := to_char(v_fec_sist,'DDMMYYYY');

-- GENERAMOS EL ARCHIVO RESUMEN CUADRE GRAL
   LP_GEN_ARC_RES_GENERAL(TRUNC(v_fec_sist));

-- GENERAMOS EL ARCHIVO RESUMEN CUADRE DETALLE 1
   LP_GEN_ARC_RES_DET1(TRUNC(v_fec_sist));

-- GENERAMOS EL ARCHIVO RESUMEN CUADRE DETALLE 2
   LP_GEN_ARC_RES_DET2(TRUNC(v_fec_sist));

EXCEPTION
  WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20066,'Error Inesperado '||sqlerrm);
END pr_cua_pre_cierre;

-- Requerimiento: CNFDEEVO-30.
-- Fecha: 04/03/2016.
PROCEDURE pr_mov_uni_oficinas
IS
   -- Variables
   v_fec_actual    cb_sal_inventarios_his.fecha%type;
   -- Fecha: 30/06/2016.
   -- Requerimiento: CNFDEEVO-47.
   v_cod_ofi_tesoreria    ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('COD_OFI_TESORERIA');

   -- Cursor.
   -- Fecha: 30/06/2016.
   -- Requerimiento: CNFDEEVO-47.
   CURSOR c_cuentas IS
   select v.cod_persona, v.nvo_oficina, v.cod_oficina, v.nro_cuenta
        from (select b.cod_persona, fug_obt_ofi_usuario(fug_obt_cod_usu_oficial(b.cod_persona)) nvo_oficina, a.cod_oficina, a.nro_cuenta
                from ah_cta_certificados a, ge_cta_clientes b
               where a.nro_cuenta = b.nro_cuenta
                 and b.relacion   = 'P'
                 and a.estado     not in ('C','X')
                 and NVL(fug_obt_paradicional(a.nro_cuenta,'CTA_PUNTAS_TESORERIA'),'N') = 'N'
               order by b.cod_persona) v
      where v.nvo_oficina != v.cod_oficina
      UNION ALL
      select v.cod_persona, v.nvo_oficina, v.cod_oficina, v.nro_cuenta
        from (select b.cod_persona, v_cod_ofi_tesoreria nvo_oficina, a.cod_oficina, a.nro_cuenta
                from ah_cta_certificados a, ge_cta_clientes b
               where a.nro_cuenta = b.nro_cuenta
                 and b.relacion   = 'P'
                 and a.estado     not in ('C','X')
                 and NVL(fug_obt_paradicional(a.nro_cuenta,'CTA_PUNTAS_TESORERIA'),'N') = 'S'
               order by b.cod_persona) v
      where v.nvo_oficina != v.cod_oficina
      UNION ALL
      select v.cod_persona, v.nvo_oficina, v.cod_oficina, v.nro_cuenta
        from (select b.cod_persona, fug_obt_ofi_usuario(fug_obt_cod_usu_oficial(b.cod_persona)) nvo_oficina, a.cod_oficina, a.nro_cuenta
                from ah_cta_vistas a, ge_cta_clientes b
               where a.nro_cuenta = b.nro_cuenta
                 and b.relacion   = 'P'
                 and a.estado     not in ('C','X','P')
                 and NVL(fug_obt_paradicional(a.nro_cuenta,'CTA_PUNTAS_TESORERIA'),'N') = 'N'
                order by b.cod_persona) v
              where v.nvo_oficina != v.cod_oficina
      UNION ALL
      select v.cod_persona, v.nvo_oficina, v.cod_oficina, v.nro_cuenta
        from (select b.cod_persona, v_cod_ofi_tesoreria nvo_oficina, a.cod_oficina, a.nro_cuenta
                from ah_cta_vistas a, ge_cta_clientes b
               where a.nro_cuenta = b.nro_cuenta
                 and b.relacion   = 'P'
                 and a.estado     not in ('C','X','P')
                 and NVL(fug_obt_paradicional(a.nro_cuenta,'CTA_PUNTAS_TESORERIA'),'N') = 'S'
                order by b.cod_persona) v
              where v.nvo_oficina != v.cod_oficina
      UNION ALL
      select v.cod_persona, v.nvo_oficina, v.cod_oficina, v.nro_cuenta
        from (
      select b.cod_persona, fug_obt_ofi_usuario(fug_obt_cod_usu_oficial(b.cod_persona)) nvo_oficina, a.cod_oficina, a.nro_cuenta
        from cc_cta_corrientes a, ge_cta_clientes b
       where a.nro_cuenta = b.nro_cuenta
         and b.relacion = 'P'
         and a.estado not in ('C','X','P')
        order by b.cod_persona) v
      where v.nvo_oficina != v.cod_oficina
      UNION ALL
      select v.cod_persona, v.nvo_oficina, v.cod_oficina, v.nro_cuenta
        from (
      select b.cod_persona, fug_obt_ofi_usuario(fug_obt_cod_usu_oficial(b.cod_persona)) nvo_oficina, a.cod_oficina, a.nro_cuenta
        from ta_cta_tarjetas a, ge_cta_clientes b
       where a.nro_cuenta = b.nro_cuenta
         and b.relacion = 'P'
         and a.estado not in ('A','C')
        order by b.cod_persona) v
      where v.nvo_oficina != v.cod_oficina
      UNION ALL
      select v.cod_persona, v.nvo_oficina, v.cod_oficina, v.nro_cuenta
        from (
      select b.cod_persona, fug_obt_ofi_usuario(fug_obt_cod_usu_oficial(b.cod_persona)) nvo_oficina, a.cod_oficina, a.nro_cuenta
        from pr_cta_prestamos a, ge_cta_clientes b
       where a.nro_cuenta = b.nro_cuenta
         and b.relacion = 'P'
         and a.estado not in ('N','I')
        order by b.cod_persona) v
      where v.nvo_oficina != v.cod_oficina
      UNION ALL
      select v.cod_persona, v.nvo_oficina, v.cod_oficina, v.nro_cuenta
        from (
      select b.cod_persona, fug_obt_ofi_usuario(fug_obt_cod_usu_oficial(b.cod_persona)) nvo_oficina, a.cod_oficina, a.nro_cuenta
        from ov_cta_vencidas a, ge_cta_clientes b
       where a.nro_cuenta = b.nro_cuenta
         and b.relacion = 'P'
         and a.estado not in ('C','I')
        order by b.cod_persona) v
      where v.nvo_oficina != v.cod_oficina
      UNION ALL
      select v.cod_persona, v.nvo_oficina, v.cod_oficina, v.nro_cuenta
        from (
      select b.cod_persona, fug_obt_ofi_usuario(fug_obt_cod_usu_oficial(b.cod_persona)) nvo_oficina, a.cod_oficina, a.nro_cuenta
        from cx_cta_cobranzas a, ge_cta_clientes b
       where a.nro_cuenta = b.nro_cuenta
         and b.relacion = 'P'
         and a.cod_modalidad IN ('83','84')
         and a.estado NOT IN ('C','R','G')
        order by b.cod_persona) v
      where v.nvo_oficina != v.cod_oficina
      UNION ALL
      select v.cod_persona, v.nvo_oficina, v.cod_oficina, v.nro_cuenta
        from (
      select b.cod_persona, fug_obt_ofi_usuario(fug_obt_cod_usu_oficial(b.cod_persona)) nvo_oficina, a.cod_oficina, a.nro_cuenta
        from cx_cta_exportaciones a, ge_cta_clientes b
       where a.nro_cuenta = b.nro_cuenta
         and b.relacion = 'P'
         and a.cod_modalidad IN ('82')
         and a.estado NOT IN ('C','R','G','U')
        order by b.cod_persona) v
      where v.nvo_oficina != v.cod_oficina
      UNION ALL
      select v.cod_persona, v.nvo_oficina, v.cod_oficina, v.nro_cuenta
        from (
      select b.cod_persona, fug_obt_ofi_usuario(fug_obt_cod_usu_oficial(b.cod_persona)) nvo_oficina, a.cod_oficina, a.nro_cuenta
        from cx_cta_importaciones a, ge_cta_clientes b
       where a.nro_cuenta = b.nro_cuenta
         and b.relacion = 'P'
         and a.cod_modalidad IN ('81')
         and a.estado NOT IN ('C','R','G','U')
        order by b.cod_persona) v
      where v.nvo_oficina != v.cod_oficina
      UNION ALL
      select v.cod_persona, v.nvo_oficina, v.cod_oficina, v.nro_cuenta
        from (
      select b.cod_persona, fug_obt_ofi_usuario(fug_obt_cod_usu_oficial(b.cod_persona)) nvo_oficina, a.cod_oficina, a.nro_cuenta
        from cx_fianzas a, ge_cta_clientes b
       where a.nro_cuenta = b.nro_cuenta
         and b.relacion = 'P'
         and a.cod_modalidad IN ('88')
         and a.estado NOT IN ('C')
        order by b.cod_persona) v
      where v.nvo_oficina != v.cod_oficina;

   -- FTP
   v_file             UTL_FILE.FILE_TYPE;
   v_line             VARCHAR2(32767);
   v_linetit          VARCHAR2(2000);
   v_buffer           VARCHAR2(32767);
   v_name             VARCHAR2(128) := 'inv_cam_gestores';
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
   v_fec_actual   := pag_cal.FU_OBT_FEC_ACTUAL(1);

   -- Formato de fecha para el informe.
   v_fecha := to_char(v_fec_actual,'DDMMYYYY');

   -- Abrir archivo
   v_file := UTL_FILE.FOPEN(pa_rep_aut.g_repository,v_name||'.txt','W',32767);

   -- Colocar el titulo a los campos
   v_linetit := 'COD_PERSONA'||CHR(9)||'NRO_CUENTA'||CHR(9)||'COD_OFI_ANTERIOR'||CHR(9)||'COD_OFI_ACTUAL';

   utl_file.put_line(v_file,v_linetit);

   -- Definir una linea en blanco para separar los datos del titulo de los campos
   v_linetit := ' ';
   utl_file.put_line(v_file,v_linetit);

   --Definir un cursor for loop que recorre los datos obtenidos
   FOR reg IN c_cuentas LOOP

      --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
      v_line := to_char(REG.COD_PERSONA)||chr(9)||to_char(REG.NRO_CUENTA)||chr(9)||to_char(REG.COD_OFICINA)||chr(9)||
                to_char(REG.NVO_OFICINA);

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

      EXIT WHEN c_cuentas%NOTFOUND;
   END LOOP;

   --Escribes la linea en el fichero
   UTL_FILE.PUT_LINE(v_file, v_buffer);

   --Cerrar el handler al fichero
   UTL_FILE.FCLOSE(v_file);
   COMMIT;

   v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

   -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
   v_respuesta := pa_file_ftp.fu_put_ascii(pa_rep_aut.g_ip, pa_rep_aut.g_port, pa_rep_aut.g_user,
                                           pa_rep_aut.g_pass, pa_rep_aut.g_repository,
                                           v_name||'.txt', g_finanzas||v_name||'_'||v_fecha||'.txt');

   v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

   IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pa_rep_aut.FU_OBT_VALOR_PAR('RA','REPORTES','VAR_CARTERA');

      -- Damos valor a los demas datos
      v_asunto := 'Inventario de Cuentas - Cambio de Gestor, a la fecha '||v_fec_actual||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_finanzas||'

      Nombre del Archivo: '||v_name||'_'||v_fecha||'.txt';

      -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         it_mail.mail(pa_rep_aut.g_envia_mail,v_para,v_asunto,v_mje_mail);
      EXCEPTION
        WHEN utl_smtp.transient_error or utl_smtp.permanent_error then
           BEGIN
              utl_smtp.quit(v_conn);
           EXCEPTION
              WHEN utl_smtp.transient_error or utl_smtp.permanent_error then
                 NULL;
           END;
           v_det_error := substr(sqlerrm,1,4000);
         WHEN OTHERS THEN
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
      v_para := pa_rep_aut.FU_OBT_VALOR_PAR('RA','REPORTES','VAR_CARTERA');

      -- Damos valor a los demas datos
      v_asunto := 'Error Inventario de Cuentas - Cambio de Gestor, a la fecha '||v_fecha||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

      Error: '||v_respuesta||'.

      Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');
      
      BEGIN 
         it_mail.mail(pa_rep_aut.g_envia_mail,v_para,v_asunto,v_mje_mail);        
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
procedure pr_com_prevision (p_tipo in char) is
  -- Variables de fechas
  v_fecha           date := pag_cal.fu_obt_fec_actual(1);
 --variables para archivo
  v_file        UTL_FILE.FILE_TYPE;
  v_line       VARCHAR2(32767);
  v_linetit    VARCHAR2(2000);
  v_buffer    VARCHAR2(32767);
  v_lines      PLS_INTEGER := 0;
  v_eol         CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen    CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline  CONSTANT PLS_INTEGER := 32767;
  v_name      VARCHAR2(128) := 'PREVISION_MEN';-- nombre del archivo
 -- Variables para FTP
  v_respuesta VARCHAR2(4000);
  v_hini_ftp  ge_ra_log_ftp.hor_inicio%type;
  v_hfin_ftp  ge_ra_log_ftp.hor_fin%type;
-- Variables para el procedimiento
  v_fec_actual      date := pag_cal.fu_obt_fec_ant_hab(pag_cal.fu_obt_fec_actual(2),31);
  v_fec_anterior    date;
  v_cod_persona     ba_personas.cod_persona%type;
  v_nombre          ba_personas.nom_completo%type;
  v_sal_anterior    number(18,2);
  v_sal_actual      number(18,2);
  v_variacion       number(18,2);

  --DYDMR-3601 - ITGF - Procesos Independientes 630 y 631 SC 27675
  cursor cur_prevision  (p_fec_actual   in  date,
                         p_fec_anterior in  date) is

        select a.cod_persona
          from cb_sal_inventarios_det_his d,
               cb_sal_inventarios_his     c,
               ge_cta_clientes            a,
               cb_gru_rubros_det          x
         where d.nro_referencia = c.nro_referencia
           and d.nro_cuenta = a.nro_cuenta
           and a.relacion = 'P'
           and d.fecha = p_fec_actual
           and x.cod_gru_rubro = 300
           and x.cod_rubro = c.cod_rubro
        union
        select a.cod_persona
          from cb_sal_inventarios_det_his d,
               cb_sal_inventarios_his     c,
               ge_cta_clientes            a,
               cb_gru_rubros_det          x
         where d.nro_referencia = c.nro_referencia
           and d.nro_cuenta = a.nro_cuenta
           and a.relacion = 'P'
           and d.fecha = p_fec_anterior
           and x.cod_gru_rubro = 300
           and x.cod_rubro = c.cod_rubro;

function lf_obt_saldos(p_cod_persona ge_cta_clientes.cod_persona%type,
                         p_fecha date) return number is
--DYDMR-3601 - ITGF - Procesos Independientes 630 y 631 SC 27675
v_cod_cliente ge_cta_clientes.cod_persona%type;
v_saldo       cb_sal_inventarios_his.sal_total%type;

begin
  begin
    select a.cod_persona, sum(nvl(d.sal_actual, 0)) saldo
      into v_cod_persona, v_saldo
      from cb_sal_inventarios_det_his d,
           cb_sal_inventarios_his     c,
           ge_cta_clientes            a,
           cb_gru_rubros_det          x
     where d.nro_referencia = c.nro_referencia
       and d.nro_cuenta = a.nro_cuenta
       and a.relacion = 'P'
       and a.cod_modulo = c.cod_modulo
       and a.cod_modalidad = c.cod_modalidad
       and x.cod_gru_rubro = 300
       and x.cod_rubro = c.cod_rubro
       and d.fecha = p_fecha
       and a.cod_persona = p_cod_persona
     group by a.cod_persona;
      return v_saldo;
    exception

    when others then
      v_saldo := 0;
      return v_saldo;
  end;


  end lf_obt_saldos;




begin
v_fec_anterior  :=pag_cal.fu_obt_fec_ant_hab( last_day((add_months(v_fec_actual, -1 ))),null,0) ;
if p_tipo = 'M' then
         v_fec_actual   := v_fec_anterior ;
         v_fec_anterior := pag_cal.fu_obt_fec_ant_hab( last_day((add_months(v_fec_anterior , -1 ))),null,0) ;
else
         v_name := 'PREVISION_DIA';
end if;



  -- Abrir archivo
  v_file := UTL_FILE.FOPEN(g_repository,v_name||'.csv','W',32767);
  -- Colocar el titulo a los campos
  v_linetit :='COD_PERSONA'||','||'NOMBRE'||','||'SALDO_ANT'||','||'SALDO_ACT'||','||'VARIACION'||','||'FEC_ANTERIOR'||','||'FEC_ACTUAL'||CHR(9) ;
  utl_file.put_line(v_file,v_linetit);
  -- Definir una linea en blanco para separar los datos del titulo de los campos
  v_linetit := ' ';
  utl_file.put_line(v_file,v_linetit);
 --Definir un cursor for loop que recorre los datos obtenidos
  for rec in cur_prevision(v_fec_actual,v_fec_anterior) loop
      --DYDMR-3601 - ITGF - Procesos Independientes 630 y 631 SC 27675
      v_sal_actual   := lf_obt_saldos(rec.cod_persona,v_fec_actual);
      v_sal_anterior := lf_obt_saldos(rec.cod_persona,v_fec_anterior);

       if v_sal_actual <> 0 or v_sal_anterior <> 0 then
                     v_cod_persona := rec.cod_persona;
                     --DYDMR-3601 - ITGF - Procesos Independientes 630 y 631 SC 27675
                     v_nombre         := fue_obt_nom_persona(rec.cod_persona);--rec.nombre ;
                     v_fec_actual    := v_fec_actual  ;
                     v_fec_anterior := v_fec_anterior ;
                     v_variacion      := abs(v_sal_actual) - abs(v_sal_anterior) ;
                     --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
                      v_line := to_char(v_cod_persona)||','||to_char(v_nombre)||','||to_char(v_sal_anterior)||','||to_char(v_sal_actual)||','||to_char(v_variacion)||','||to_char(v_fec_anterior,'dd/mm/yyyy')||','||to_char(v_fec_actual,'dd/mm/yyyy');
                      if length(v_buffer) + v_eollen + length(v_line) <= v_maxline then
                        v_buffer := v_buffer || v_eol || v_line;
                      else
                         if v_buffer is not null then
                           --escribes la linea en el fichero
                            utl_file.put_line(v_file, v_buffer);
                         end if;
                         v_buffer := v_line;
                      end if;
                      v_lines := v_lines + 1;
                      exit when cur_prevision%notfound;
           end if;
            end loop;
            --Escribes la linea en el fichero
            utl_file.put_line(v_file, v_buffer);
            --cerrar el handler al fichero
            utl_file.fclose(v_file);
            -- Se envia mediante FTP el archivo generado a Servidor de archivos
             v_hini_ftp := to_char(sysdate,'hh24:mi:ss');
             -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
            v_respuesta := pa_file_ftp.fu_put_ascii(pag_evo.g_ip, pag_evo.g_port, pag_evo.g_user,
                                                      pag_evo.g_pass, pag_evo.g_repository,
                                                      v_name||'.csv', pag_evo.g_contabilidad||v_name||'_'||v_fecha||'.csv');

              v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');
              IF v_respuesta != 'OK' THEN  -- ERROR AL ENVIAR ARCHIVO POR FTP
                    -- Insertamos el error del envio al directorio compartido
                    insert into ge_ra_log_ftp
                     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
                    values
                     (sysdate, v_name||'_'||v_fecha||'.csv', v_respuesta, v_hini_ftp, v_hfin_ftp);
                   commit;
             end if;
  exception
    when utl_file.invalid_operation then
      utl_file.fclose(v_file);
      raise_application_error(-20061,'operacion invalida '||sqlerrm);
    when utl_file.invalid_filehandle then
      utl_file.fclose(v_file);
      raise_application_error(-20062,'manejador invalido '||sqlerrm);
    when utl_file.write_error then
      utl_file.fclose(v_file);
      raise_application_error(-20063,'error de escritura '||sqlerrm);
    when utl_file.invalid_mode then
      utl_file.fclose(v_file);
      raise_application_error(-20064,'modo invalido '||sqlerrm);
    when utl_file.internal_error then
      utl_file.fclose(v_file);
      raise_application_error(-20065,'internal error '||sqlerrm);
   WHEN OTHERS THEN
     utl_file.fclose(v_file);
      raise_application_error(-20099,'Error Inesperado '||sqlerrm);
end pr_com_prevision ;

procedure pr_snp_pre_enc_legal ( p_fecha in sb_encajes_ml.fecha%type default null )
-- Procedimiento de generación previa de archivo de encaje legal (MT998) antes de enviar a SIPAP
is
   v_sql                     varchar2(4000);
   v_cur                     sys_refcursor;
   v_monto                number;
   v_fecha                 date;
   v_fec_proceso      date;
   v_relacion        float;
   v_redondeo        number(2);
   v_cod_mon_iso     ba_monedas.cod_mon_iso%type;
   v_cod_cuenta        sb_enc_circular254.cod_cuenta%type;
   v_monto2               number;
   v_monto3               number;
   v_fec_arch             varchar2(8);
   v_swi_row sb_men_swift_tmp%rowtype;
 --variables para archivo
  v_file        UTL_FILE.FILE_TYPE;
  v_line       VARCHAR2(32767);
  v_linetit    VARCHAR2(2000);
  v_buffer    VARCHAR2(32767);
  v_lines      PLS_INTEGER := 0;
  v_eol         CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen    CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline  CONSTANT PLS_INTEGER := 32767;
  v_name      VARCHAR2(128) := 'PRE_ENVIO_ENCAJE';-- nombre del archivo
 -- Variables para FTP
  v_respuesta VARCHAR2(4000);
  v_hini_ftp  ge_ra_log_ftp.hor_inicio%type;
  v_hfin_ftp  ge_ra_log_ftp.hor_fin%type;
  --
  v_sal_cap_cov_pyg number;
  v_sal_cap_cov_usd number;
  v_cod_moneda      ba_monedas.cod_moneda%type;

 cursor c_encaje (p_fecha in date) is
    Select * from sb_men_swift_tmp order by 3,1,5;

   -- Cursor con los Plazos parametrizados a informar --
   cursor c_plazos is
      SELECT val_minimo dia_fin, val_maximo plazo, cod_moneda
        FROM (SELECT a.val_minimo,
                     a.val_maximo,
                     'GS' cod_moneda,
                     1 orden
                FROM ba_cod_referencias a
               WHERE a.dominio = 'SNP_PLZ_ENC_LEG_ML'
               UNION
              SELECT a.val_minimo,
                     a.val_maximo,
                     'USD' cod_moneda,
                     2 orden
                FROM ba_cod_referencias a
               WHERE a.dominio = 'SNP_PLZ_ENC_LEG_ME'
               UNION
              SELECT a.val_minimo,
                     a.val_maximo,
                     'EUR' cod_moneda,
                     3 orden
                FROM ba_cod_referencias a
               WHERE a.dominio = 'SNP_PLZ_ENC_LEG_ME')
       ORDER BY orden, to_number(val_minimo);

   cursor c_desencajes is
   Select distinct fecha
     from sb_men_swift_tmp
     order by fecha;   

   --- Saldos Capital Covit
   procedure lp_ins_sal_cap_cov(
             v_tip_saldo varchar2,
             v_sal_cap_cov number) is
     v_redondeo number := fug_obt_pardinamico(p_parametro => 'VAL_RED_MON_EXTRANJERA',
                                              p_cod_moneda => v_cod_moneda);
   begin
      -- Moneda
      begin
         select m.cod_mon_iso
           into v_cod_mon_iso
           from ba_monedas m
          where m.cod_moneda = v_cod_moneda;
      exception
          when others then
             raise_application_error(-20004,'Error al Obtener Moneda ISO para '||v_cod_moneda||': '||sqlerrm);
      end;
      v_line := '1,'||
                '3650,'||
                v_cod_mon_iso||','||
                to_char(v_fecha,'DDMMYYYY')||','||
                trim(to_char(round(nvl(v_sal_cap_cov, 0),v_redondeo)));
       
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
   end;
-------------------------
--- PROCESO PRINCIPAL ---
-------------------------
begin
   begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
   execute immediate ('TRUNCATE TABLE IT.SB_MEN_SWIFT_TMP');
   -- Se halla la última fecha de proceso --
   select max(fecha)
     into v_fec_proceso
     from sb_enc_circular254
    where fecha <= nvl(p_fecha, fecha);
   -- Si es nulo se informa la utlima fecha procesada
   if p_fecha is null then
      v_fecha := v_fec_proceso;
   else
      v_fecha := p_fecha;
   end if;
   -- Proceso por plazos --
   for plz in c_plazos loop
      ---inicio de ajuste BSEVOCORE-648 VAE 06/2021
      v_relacion := 1; --Inicializa la relacion entre monedas
      v_redondeo := 0;
      if plz.cod_moneda<> PAG_GEN.FU_OBT_MON_LOCAL then 
        --si es moneda extranjera se informar el valor equivalente en dolares  
        v_relacion := (PAG_GEN.FU_OBT_COTIZACION(plz.cod_moneda,v_fec_proceso))
                        /(PAG_GEN.FU_OBT_COTIZACION(PAG_GEN.FU_OBT_MON_FUERTE,v_fec_proceso));
        v_redondeo := FUG_OBT_PARDINAMICO('VAL_RED_MON_EXTRANJERA',7,71,PAG_GEN.FU_OBT_MON_FUERTE,null);
      end if;
     --Se modifica el cursor para multiplicar el importe por el valor de la relacion entre monedas.
      v_sql := 'select sum(a.importe) monto, a.cod_cuenta
                  from sb_enc_circular254 a, ba_monedas m
                 where a.cod_moneda = m.cod_mon_bco_central
                   and a.plazo in ('||plz.plazo||')
                   and m.cod_moneda = '''||plz.cod_moneda||'''
                   and a.fecha = '''||v_fec_proceso||'''
                 group by m.cod_mon_iso, a.cod_cuenta';
      ---fin de ajuste BSEVOCORE-648 VAE 06/2021
      open v_cur for v_sql;
      v_monto := null;
      v_cod_cuenta := null;
      v_monto2     := null;
      v_monto3     := null;
      --Se halla la moneda ISO.
      begin
         select m.cod_mon_iso
           into v_cod_mon_iso
           from ba_monedas m
          where m.cod_moneda = plz.cod_moneda;
      exception
          when others then
             raise_application_error(-20004,'Error al Obtener Moneda '||plz.cod_moneda||': '||sqlerrm);
      end;
     -- Se halla el Monto total del Select dinámico --
      loop
         fetch v_cur into v_monto3, v_cod_cuenta;
         v_monto3 := round(v_monto3 * v_relacion,v_redondeo);---dolarizar moneda extranjera en caso de ser necesario VAE07/2021 BSEVOCORE-648
         if v_cur%found and v_cod_cuenta = 218 then
            v_monto2 := nvl(v_monto2,0) + v_monto3;
         elsif v_cur%found and v_cod_cuenta <> 218 then
            v_monto := nvl(v_monto,0) + v_monto3;
         end if;
         exit when v_cur%notfound;
      end loop;
      -- Fecha
      v_swi_row.fecha :=  v_fecha ;
      -- Plazo Desde
      case when plz.dia_fin = '1' then
         v_swi_row.plazo_de :=  1;
       when plz.dia_fin = '360' then
         v_swi_row.plazo_de := 2 ;
       when plz.dia_fin = '540' then
          v_swi_row.plazo_de := 361 ;
       when plz.dia_fin = '1080' then
           v_swi_row.plazo_de := 541;
      when plz.dia_fin = '3650' and plz.cod_moneda = pas_snp.g_cod_mon_local then
           v_swi_row.plazo_de := 541;
       when plz.dia_fin = '3650' and plz.cod_moneda != pas_snp.g_cod_mon_local then
           v_swi_row.plazo_de := 1081 ;
        else
           v_swi_row.plazo_de := 0 ;
        end case ;
      -- Plazo Hasta
       v_swi_row.plazo_a := plz.dia_fin ;
      -- Moneda
      v_swi_row.moneda := v_cod_mon_iso ;
      -- Monto
      v_swi_row.monto := nvl(v_monto,0) ;
      insert into sb_men_swift_tmp values v_swi_row ;
      If plz.dia_fin = 3650 Then
          -- Fecha
          v_swi_row.fecha :=  v_fecha ;
          -- Plazo Desde
        case when plz.dia_fin = '540' then
            v_swi_row.plazo_de := 1 ;
        else
            v_swi_row.plazo_de :=  541 ;
        end case ;
          -- Plazo Hasta
        case when plz.dia_fin =540 then
             v_swi_row.plazo_a := 540 ;
        else
             v_swi_row.plazo_a := 3650 ;
        end case;
          -- Moneda
          v_swi_row.moneda := v_cod_mon_iso ;
          -- Monto
          v_swi_row.monto := nvl(v_monto2,0) ;
         insert into sb_men_swift_tmp values v_swi_row ;
      End If;
   end loop;
   ---------------------------------------------------------------------------------------
   -- Generación en Servidor de archivos --
   ----------------------------------------------------------------------------------------
    -- Abrir archivo
  v_file := utl_file.fopen(g_repository,v_name||'.csv','W',32767);
  -- Colocar el titulo a los campos
  v_linetit :='PLAZO_DE'||','||'PLAZO_A'||','||'MONEDA'||','||'FECHA'||','||'MONTO'||CHR(9) ;
  utl_file.put_line(v_file,v_linetit);
  -- Definir una linea en blanco para separar los datos del titulo de los campos
  v_linetit := ' ';
  utl_file.put_line(v_file,v_linetit);
 --Definir un cursor for loop que recorre los datos obtenidos
   for rec in c_encaje(v_fec_proceso) loop
        v_fec_arch := to_char(trunc(rec.fecha),'dd')||to_char(trunc(rec.fecha),'mm')||to_char(trunc(rec.fecha),'yyyy');
      --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
            v_line := to_char(rec.plazo_de)||','||to_char(rec.plazo_a)||','||to_char(rec.moneda)||','||v_fec_arch||','||to_char(rec.monto);
            if length(v_buffer) + v_eollen + length(v_line) <= v_maxline then
              v_buffer := v_buffer || v_eol || v_line;
            else
               if v_buffer is not null then
                 --escribes la linea en el fichero
                  utl_file.put_line(v_file, v_buffer);
               end if;
               v_buffer := v_line;
            end if;
            v_lines := v_lines + 1;
            exit when c_encaje%notfound;
   end loop;
   /*
   || SDOPENLE07-1 Informe Operativa del Encaje legal
   */
   for des in c_desencajes loop
      v_cod_moneda      := pag_gen.FU_OBT_MON_LOCAL;
      v_sal_cap_cov_pyg := fus_obt_desencajes(des.fecha, v_cod_moneda);
      if nvl(v_sal_cap_cov_pyg,0) <> 0 then
         lp_ins_sal_cap_cov('SALCAPCOVPYG',v_sal_cap_cov_pyg);
      end if;
      ---
      v_cod_moneda      := pag_gen.FU_OBT_MON_FUERTE;
      v_sal_cap_cov_usd := fus_obt_desencajes(des.fecha, v_cod_moneda);
      if nvl(v_sal_cap_cov_usd,0) <> 0 then
         lp_ins_sal_cap_cov('SALCAPCOVUSD',v_sal_cap_cov_usd);
      end if;
   end loop;
   --Escribes la linea en el fichero
    utl_file.put_line(v_file, v_buffer);
    --cerrar el handler al fichero
    utl_file.fclose(v_file);
    -- Se envia mediante FTP el archivo generado a Servidor de archivos
     v_hini_ftp := to_char(sysdate,'hh24:mi:ss');
     -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
    v_respuesta := pa_file_ftp.fu_put_ascii(pag_evo.g_ip, pag_evo.g_port, pag_evo.g_user,
                                              pag_evo.g_pass, pag_evo.g_repository,
                                              v_name||'.csv', pag_evo.g_contabilidad||v_name||'_'||v_fec_arch||'.csv');
    ---
      v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');
      IF v_respuesta != 'OK' THEN  -- error al enviar archivo por ftp
            -- Insertamos el error del envio al directorio compartido
            insert into ge_ra_log_ftp
             (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
            values
             (sysdate, v_name||'_'||v_fec_arch||'.csv', v_respuesta, v_hini_ftp, v_hfin_ftp);
           commit;
     end if;
  exception
    when utl_file.invalid_operation then
      utl_file.fclose(v_file);
      raise_application_error(-20061,'operacion invalida '||sqlerrm);
    when utl_file.invalid_filehandle then
      utl_file.fclose(v_file);
      raise_application_error(-20062,'manejador invalido '||sqlerrm);
    when utl_file.write_error then
      utl_file.fclose(v_file);
      raise_application_error(-20063,'error de escritura '||sqlerrm);
    when utl_file.invalid_mode then
      utl_file.fclose(v_file);
      raise_application_error(-20064,'modo invalido '||sqlerrm);
    when utl_file.internal_error then
      utl_file.fclose(v_file);
      raise_application_error(-20065,'internal error '||sqlerrm);
   when others then
     utl_file.fclose(v_file);
      raise_application_error(-20099,'Error Inesperado '||sqlerrm);
     if sqlcode <= -20000 then
        raise;
     else
        raise_application_error(-20999, 'Error al Procesar Encaje legal: '||sqlerrm);
     end if ;
   ----------------------------------------------------------------------------------------
end pr_snp_pre_enc_legal;

-- Requerimiento: CNFBPAFM-3.
/* Genera el Balance Proyectado. */
PROCEDURE pr_bal_sim_abi_suc(p_fecha in ge_calendarios.fec_actual%type)
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
    from cb_sim_sal_oficinas s, cb_rubros k
    where s.cod_rubro = k.cod_rubro
    and k.imputable   = 'S'
    and abs(nvl(s.sal_mon_loc_ant,0)+nvl(s.deb_mon_local,0)-nvl(s.cre_mon_local,0)) <> 0
    order by 1,4;

  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'sim_bal_abierto_suc'; -- nombre del archivo
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
  v_fecha := to_char(p_fecha,'YYYYMMDD');

  -- Obtenemos la hora de la base de datos
  v_hora := to_char(sysdate,'hh24miss');

-- Abrir archivo
v_file := UTL_FILE.FOPEN(pa_rep_aut.g_repository,v_name||'.txt','W',32767);

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
  v_respuesta := pa_file_ftp.fu_put_ascii(pa_rep_aut.g_ip, pa_rep_aut.g_port, pa_rep_aut.g_user,
                                          pa_rep_aut.g_pass, pa_rep_aut.g_repository,
                                          v_name||'.txt', g_finanzas||v_name||'_'||v_fecha||'_'||v_hora||'.txt');

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pa_rep_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SIM_BALANCE_ABIERTO_SUC');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte Balance Proyectado Abierto por Sucursal a la fecha '||v_fecha||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente dirección: '||g_compartido||g_finanzas||'

    Nombre del Archivo: '||v_name||'_'||v_fecha||'_'||v_hora||'.txt';

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
        it_mail.mail(pa_rep_aut.g_envia_mail,v_para,v_asunto,v_mje_mail);
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
     v_para := pa_rep_aut.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error Reporte Balance Proyectado Abierto por Sucursal a la fecha '||v_fecha||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas información verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
        it_mail.mail(pa_rep_aut.g_envia_mail,v_para,v_asunto,v_mje_mail);
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
END pr_bal_sim_abi_suc;

END pag_evo;
/

