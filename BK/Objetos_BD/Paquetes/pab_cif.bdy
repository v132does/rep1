create or replace package body it.PAB_CIF is
  -- Author  : XPY3109 NAF - ABR 2019/CORECOIFA-2 
  -- Created : 20/03/2019 12:15:20
  -- Purpose : Paquete de Conciliacion de Ingresos - Facturaciones
  
  vg_fec_actual       date;
  vg_fec_inicial      date;
  vg_fec_final        date;
  vg_mes_informe      varchar2(8);
  vg_mes_archivo      varchar2(8);
  vg_rub_ingresos     varchar2(300);
  vg_rub_sin_factura  varchar2(300);
  vg_repositorio      varchar2(100);
  vg_email_de         varchar2(100);
  vg_email_para       varchar2(500);
  vg_ip               varchar2(100);
  vg_port             varchar2(100);
  vg_user             varchar2(100);
  vg_pass             varchar2(100);
  vg_compartido       varchar2(100);
  vg_car_contabilidad varchar2(100);
  vg_fin_linea        varchar2(2);
  vg_tabulador        varchar2(1);
  vg_lon_fin_linea    integer;
  vg_max_long         integer;
  vg_arc_extension    varchar2(5);
  vg_csv_separador    varchar2(1);
  vg_proceso          varchar2(30);
  vg_arc_detalle      varchar2(20) := '';
  vg_hor_procesa      varchar2(100);
  vg_hor_control      varchar2(2);
  vg_fec_generacion   date;
  
  -- Inicializa Variables para conciliación
  Procedure pr_ini_variables( p_fec_proceso date default null) is
    v_fec_temporal date;
  begin
     vg_proceso := 'pr_ini_variables';
     -- Fecha
     vg_fec_actual := pag_cal.FU_OBT_FEC_ACTUAL(1);
     if p_fec_proceso is not null then
        vg_fec_inicial := to_date('01'||to_char(p_fec_proceso,'/mm/yyyy'),'dd/mm/yyyy');
        v_fec_temporal := ADD_MONTHS(vg_fec_inicial,1);
        vg_fec_final := pag_cal.FU_OBT_FEC_ANT_HAB(v_fec_temporal,31,1);    
     else
        -- si no recibe fecha, genera al mes anterior cerrado
        v_fec_temporal := to_date('01'||to_char(vg_fec_actual,'/mm/yyyy'),'dd/mm/yyyy');
        vg_fec_final := pag_cal.FU_OBT_FEC_ANT_HAB(v_fec_temporal,31,1);
        vg_fec_inicial := to_date('01'||to_char(vg_fec_final,'/mm/yyyy'),'dd/mm/yyyy');
     end if;
     vg_mes_informe := to_char(vg_fec_inicial,'/mm/yyyy');
     vg_mes_archivo := to_char(vg_fec_inicial,'yyyy-mm');
     -- Rubros
     vg_rub_ingresos       := fug_obt_pardinamico('CIF_RUB_INGRESOS');
     vg_rub_sin_factura    := fug_obt_pardinamico('CIF_RUB_SIN_FACTURA');
     -- Generacion de Archivos
     vg_repositorio        := 'MAIL';
     vg_email_de           := fug_obt_pardinamico('CAM_MAR_DIR_MAI_NET');--'bbvanet@bbva.com.py';
     vg_email_para         := fug_obt_pardinamico('CIF_INF_ENV_EMAIL');
     --vg_email_para         := 'nicolas.andrusky.contractor@bbva.com,dummy@abcd777.com.py'; --pruebas
     vg_ip                 := fug_obt_pardinamico('DIR_SVR_REP_ARCHIVOS');
     --vg_ip                 := '62.12.240.24'; -- pruebas bbvatest
     vg_port               := '21';
     vg_user               := fug_obt_pardinamico('USU_FTP_REP_ARCHIVOS');
     vg_pass               := fug_obt_pardinamico('PAS_FTP_REP_ARCHIVOS');
     vg_compartido         := '\\'||fug_obt_pardinamico('PAS_FTP_REP_ARCHIVOS')||'\';
     vg_car_contabilidad   := 'ramail\contabilidad\';
     --vg_car_contabilidad   := 'ramail\DyD\'; -- pruebas bbvatest
     vg_fin_linea          := chr(13) || chr(10);
     vg_lon_fin_linea      := LENGTH(vg_fin_linea);
     vg_tabulador          := CHR(9);
     vg_max_long           := 32767;
     vg_arc_extension      := 'txt';
     vg_csv_separador      := ';'; 
     -- Control de Procesamiento por rango horario
     vg_hor_control        := nvl(fug_obt_pardinamico('CIF_INF_HOR_CTRL'),'NO');
  end;
  
  -- Trunca tablas temporales
  Procedure pr_tru_temporales is
  begin
     vg_proceso := 'pr_tru_temporales';
     -- truncado de tablas
     execute immediate 'truncate table CB_CIF_ASIENTOS_TMP';
     execute immediate 'truncate table CB_CIF_MOVIMIENTOS_TMP';
     execute immediate 'truncate table CB_CIF_FACTURAS_TMP';
     -- borrado de tablas
     delete from cb_cif_inf_detalle where fecha between vg_fec_inicial and vg_fec_final;
  end;
  
  -- Genera Estadistica de Tabla
  Procedure pr_gen_estadisticas(p_tabla varchar2, p_usuario varchar2 default 'IT') is
  begin
     vg_proceso := 'pr_gen_estadisticas';
     dbms_stats.gather_table_stats(upper(p_usuario), upper(p_tabla), NULL, 100,FALSE, NULL, NULL, 'ALL',TRUE);
  end;
  
  -- Copia datos a tablas tmp
  Procedure pr_gen_temporales is  
  begin
    vg_proceso := 'pr_gen_temporales';
    -- copia detalle de asientos
    insert into cb_cif_asientos_tmp
      select *
      from cb_asientos_det_his x 
      where x.fecha between vg_fec_inicial and vg_fec_final
          and substr(x.cod_rubro, 1, 5) IN (
                select to_char(regexp_substr(vg_rub_ingresos,'[^,]+', 1, level)) from dual
                connect by regexp_substr(vg_rub_ingresos, '[^,]+', 1, level) is not null );

    pr_gen_estadisticas('cb_cif_asientos_tmp');
    
    -- copia detalle de movimientos
    insert into cb_cif_movimientos_tmp
    select m.FECHA, m.HORA, m.COD_USUARIO, m.NRO_SECUENCIA, 
       m.FEC_VALOR, m.MONTO, m.MTO_EQU_LOCAL, m.COTIZACION ,m.NRO_CUENTA, 
       t.COD_PERSONA, m.COD_MONEDA,
       m.ESTADO,m.CONCEPTO,
       m.REVERSADO,COD_USU_REVERSION,HOR_REVERSION, --datos de reversion
       m.COD_TRA_PADRE, m.COD_TRANSACCION,
       m.COD_MODULO, m.COD_MODALIDAD,
       m.NRO_DOCUMENTO,m.NRO_DOCUMENTO4, m.REFERENCIA, t.cod_persona cod_per_referencia,
       DECODE(m.COD_TRANSACCION,515,'C',560,'C',TH.TIPO)  tip_movimiento,
       x.cod_rubro, x.tip_movimiento tip_movimiento_asi, x.mto_mon_rubro, 
       x.mto_mon_local, x.val_cotizacion, x.descripcion,
       decode(m.REVERSADO,'S','D','-') rev_tipo,
       'N' tie_factura --marca como que no tiene factura por defecto
    from AH_MOVIMIENTOS_HIS m
         left join GE_TRANSACCIONES TH on m.COD_MODULO = TH.COD_MODULO and m.COD_MODALIDAD = TH.COD_MODALIDAD
              and m.COD_TRANSACCION = TH.COD_TRANSACCION
          join cb_cif_asientos_tmp x on x.fecha = m.FECHA 
              and x.ref_movimiento = m.NRO_DOCUMENTO4
          left join ge_cta_clientes t on t.nro_cuenta=m.REFERENCIA and t.relacion = 'P';

    insert into cb_cif_movimientos_tmp
    select m.FECHA, m.HORA, m.COD_USUARIO, m.NRO_SECUENCIA, 
       m.FEC_VALOR, m.MONTO, m.MTO_EQU_LOCAL, m.COTIZACION ,m.NRO_CUENTA, 
       t.COD_PERSONA, m.COD_MONEDA,
       m.ESTADO,m.CONCEPTO,
       m.REVERSADO,COD_USU_REVERSION,HOR_REVERSION, --datos de reversion
       m.COD_TRA_PADRE, m.COD_TRANSACCION,
       m.COD_MODULO, m.COD_MODALIDAD,
       m.NRO_DOCUMENTO,m.NRO_DOCUMENTO4, m.REFERENCIA, t.cod_persona cod_per_referencia,
       DECODE(m.COD_TRANSACCION,515,'C',560,'C',TH.TIPO)  tip_movimiento,
       x.cod_rubro, x.tip_movimiento tip_movimiento_asi, x.mto_mon_rubro, 
       x.mto_mon_local, x.val_cotizacion, x.descripcion,
       decode(m.REVERSADO,'S','D','-') rev_tipo,
       'N' tie_factura --marca como que no tiene factura por defecto
    from CC_MOVIMIENTOS_HIS m
         left join GE_TRANSACCIONES TH on m.COD_MODULO = TH.COD_MODULO and m.COD_MODALIDAD = TH.COD_MODALIDAD
              and m.COD_TRANSACCION = TH.COD_TRANSACCION
          join cb_cif_asientos_tmp x on x.fecha = m.FECHA 
              and x.ref_movimiento = m.NRO_DOCUMENTO4
          left join ge_cta_clientes t on t.nro_cuenta=m.REFERENCIA and t.relacion = 'P';

    insert into cb_cif_movimientos_tmp
    select m.FECHA, m.HORA, m.COD_USUARIO, m.NRO_SECUENCIA, 
       m.FEC_VALOR, m.MONTO, m.MTO_EQU_LOCAL, m.COTIZACION ,m.NRO_CUENTA, 
       t.COD_PERSONA, m.COD_MONEDA,
       m.ESTADO,m.CONCEPTO,
       m.REVERSADO,COD_USU_REVERSION,HOR_REVERSION, --datos de reversion
       m.COD_TRA_PADRE, m.COD_TRANSACCION,
       m.COD_MODULO, m.COD_MODALIDAD,
       m.NRO_DOCUMENTO,m.NRO_DOCUMENTO4, m.REFERENCIA, t.cod_persona cod_per_referencia,
       DECODE(m.COD_TRANSACCION,515,'C',560,'C',TH.TIPO)  tip_movimiento,
       x.cod_rubro, x.tip_movimiento tip_movimiento_asi, x.mto_mon_rubro, 
       x.mto_mon_local, x.val_cotizacion, x.descripcion,
       decode(m.REVERSADO,'S','D','-') rev_tipo,
       'N' tie_factura --marca como que no tiene factura por defecto
    from PR_MOVIMIENTOS_HIS m
         left join GE_TRANSACCIONES TH on m.COD_MODULO = TH.COD_MODULO and m.COD_MODALIDAD = TH.COD_MODALIDAD
              and m.COD_TRANSACCION = TH.COD_TRANSACCION
          join cb_cif_asientos_tmp x on x.fecha = m.FECHA 
              and x.ref_movimiento = m.NRO_DOCUMENTO4
          left join ge_cta_clientes t on t.nro_cuenta=m.REFERENCIA and t.relacion = 'P';

    insert into cb_cif_movimientos_tmp
    select m.FECHA, m.HORA, m.COD_USUARIO, m.NRO_SECUENCIA, 
       m.FEC_VALOR, m.MONTO, m.MTO_EQU_LOCAL, m.COTIZACION ,m.NRO_CUENTA, 
       t.COD_PERSONA, m.COD_MONEDA,
       m.ESTADO,m.CONCEPTO,
       m.REVERSADO,COD_USU_REVERSION,HOR_REVERSION, --datos de reversion
       m.COD_TRA_PADRE, m.COD_TRANSACCION,
       m.COD_MODULO, m.COD_MODALIDAD,
       m.NRO_DOCUMENTO,m.NRO_DOCUMENTO4, m.REFERENCIA, t.cod_persona cod_per_referencia,
       DECODE(m.COD_TRANSACCION,515,'C',560,'C',TH.TIPO)  tip_movimiento,
       x.cod_rubro, x.tip_movimiento tip_movimiento_asi, x.mto_mon_rubro, 
       x.mto_mon_local, x.val_cotizacion, x.descripcion,
       decode(m.REVERSADO,'S','D','-') rev_tipo,
       'N' tie_factura --marca como que no tiene factura por defecto
    from TA_MOVIMIENTOS_HIS m
         left join GE_TRANSACCIONES TH on m.COD_MODULO = TH.COD_MODULO and m.COD_MODALIDAD = TH.COD_MODALIDAD
              and m.COD_TRANSACCION = TH.COD_TRANSACCION
          join cb_cif_asientos_tmp x on x.fecha = m.FECHA 
              and x.ref_movimiento = m.NRO_DOCUMENTO4
          left join ge_cta_clientes t on t.nro_cuenta=m.REFERENCIA and t.relacion = 'P';

    insert into cb_cif_movimientos_tmp
    select m.FECHA, m.HORA, m.COD_USUARIO, m.NRO_SECUENCIA, 
       m.FEC_VALOR, m.MONTO, m.MTO_EQU_LOCAL, m.COTIZACION ,m.NRO_CUENTA, 
       t.COD_PERSONA, m.COD_MONEDA,
       m.ESTADO,m.CONCEPTO,
       m.REVERSADO,COD_USU_REVERSION,HOR_REVERSION, --datos de reversion
       m.COD_TRA_PADRE, m.COD_TRANSACCION,
       m.COD_MODULO, m.COD_MODALIDAD,
       m.NRO_DOCUMENTO,m.NRO_DOCUMENTO4, m.REFERENCIA, t.cod_persona cod_per_referencia,
       DECODE(m.COD_TRANSACCION,515,'C',560,'C',TH.TIPO)  tip_movimiento,
       x.cod_rubro, x.tip_movimiento tip_movimiento_asi, x.mto_mon_rubro, 
       x.mto_mon_local, x.val_cotizacion, x.descripcion,
       decode(m.REVERSADO,'S','D','-') rev_tipo,
       'N' tie_factura --marca como que no tiene factura por defecto
    from LC_MOVIMIENTOS_HIS m
         left join GE_TRANSACCIONES TH on m.COD_MODULO = TH.COD_MODULO and m.COD_MODALIDAD = TH.COD_MODALIDAD
              and m.COD_TRANSACCION = TH.COD_TRANSACCION
          join cb_cif_asientos_tmp x on x.fecha = m.FECHA 
              and x.ref_movimiento = m.NRO_DOCUMENTO4
          left join ge_cta_clientes t on t.nro_cuenta=m.REFERENCIA and t.relacion = 'P';

    insert into cb_cif_movimientos_tmp
    select m.FECHA, m.HORA, m.COD_USUARIO, m.NRO_SECUENCIA, 
       m.FEC_VALOR, m.MONTO, m.MTO_EQU_LOCAL, m.COTIZACION ,m.NRO_CUENTA, 
       t.COD_PERSONA, m.COD_MONEDA,
       m.ESTADO,m.CONCEPTO,
       m.REVERSADO,COD_USU_REVERSION,HOR_REVERSION, --datos de reversion
       m.COD_TRA_PADRE, m.COD_TRANSACCION,
       m.COD_MODULO, m.COD_MODALIDAD,
       m.NRO_DOCUMENTO,m.NRO_DOCUMENTO4, m.REFERENCIA, t.cod_persona cod_per_referencia,
       DECODE(m.COD_TRANSACCION,515,'C',560,'C',TH.TIPO)  tip_movimiento,
       x.cod_rubro, x.tip_movimiento tip_movimiento_asi, x.mto_mon_rubro, 
       x.mto_mon_local, x.val_cotizacion, x.descripcion,
       decode(m.REVERSADO,'S','D','-') rev_tipo,
       'N' tie_factura --marca como que no tiene factura por defecto
    from CX_MOVIMIENTOS_HIS m
         left join GE_TRANSACCIONES TH on m.COD_MODULO = TH.COD_MODULO and m.COD_MODALIDAD = TH.COD_MODALIDAD
              and m.COD_TRANSACCION = TH.COD_TRANSACCION
          join cb_cif_asientos_tmp x on x.fecha = m.FECHA 
              and x.ref_movimiento = m.NRO_DOCUMENTO4
          left join ge_cta_clientes t on t.nro_cuenta=m.REFERENCIA and t.relacion = 'P';

    insert into cb_cif_movimientos_tmp
    select m.FECHA, m.HORA, m.COD_USUARIO, m.NRO_SECUENCIA, 
       m.FEC_VALOR, m.MONTO, m.MTO_EQU_LOCAL, m.COTIZACION ,m.NRO_CUENTA, 
       t.COD_PERSONA, m.COD_MONEDA,
       m.ESTADO,m.CONCEPTO,
       m.REVERSADO,COD_USU_REVERSION,HOR_REVERSION, --datos de reversion
       m.COD_TRA_PADRE, m.COD_TRANSACCION,
       m.COD_MODULO, m.COD_MODALIDAD,
       m.NRO_DOCUMENTO,m.NRO_DOCUMENTO4, m.REFERENCIA, t.cod_persona cod_per_referencia,
       DECODE(m.COD_TRANSACCION,515,'C',560,'C',TH.TIPO)  tip_movimiento,
       x.cod_rubro, x.tip_movimiento tip_movimiento_asi, x.mto_mon_rubro, 
       x.mto_mon_local, x.val_cotizacion, x.descripcion,
       decode(m.REVERSADO,'S','D','-') rev_tipo,
       'N' tie_factura --marca como que no tiene factura por defecto
    from MD_MOVIMIENTOS_HIS m
         left join GE_TRANSACCIONES TH on m.COD_MODULO = TH.COD_MODULO and m.COD_MODALIDAD = TH.COD_MODALIDAD
              and m.COD_TRANSACCION = TH.COD_TRANSACCION
          join cb_cif_asientos_tmp x on x.fecha = m.FECHA 
              and x.ref_movimiento = m.NRO_DOCUMENTO4
          left join ge_cta_clientes t on t.nro_cuenta=m.REFERENCIA and t.relacion = 'P';

    insert into cb_cif_movimientos_tmp
    select m.FECHA, m.HORA, m.COD_USUARIO, m.NRO_SECUENCIA, 
       m.FEC_VALOR, m.MONTO, m.MTO_EQU_LOCAL, m.COTIZACION ,m.NRO_CUENTA, 
       t.COD_PERSONA, m.COD_MONEDA,
       m.ESTADO,m.CONCEPTO,
       m.REVERSADO,COD_USU_REVERSION,HOR_REVERSION, --datos de reversion
       m.COD_TRA_PADRE, m.COD_TRANSACCION,
       m.COD_MODULO, m.COD_MODALIDAD,
       m.NRO_DOCUMENTO,m.NRO_DOCUMENTO4, m.REFERENCIA, t.cod_persona cod_per_referencia,
       DECODE(m.COD_TRANSACCION,515,'C',560,'C',TH.TIPO)  tip_movimiento,
       x.cod_rubro, x.tip_movimiento tip_movimiento_asi, x.mto_mon_rubro, 
       x.mto_mon_local, x.val_cotizacion, x.descripcion,
       decode(m.REVERSADO,'S','D','-') rev_tipo,
       'N' tie_factura --marca como que no tiene factura por defecto
    from OV_MOVIMIENTOS_HIS m
         left join GE_TRANSACCIONES TH on m.COD_MODULO = TH.COD_MODULO and m.COD_MODALIDAD = TH.COD_MODALIDAD
              and m.COD_TRANSACCION = TH.COD_TRANSACCION
          join cb_cif_asientos_tmp x on x.fecha = m.FECHA 
              and x.ref_movimiento = m.NRO_DOCUMENTO4
          left join ge_cta_clientes t on t.nro_cuenta=m.REFERENCIA and t.relacion = 'P';

    insert into cb_cif_movimientos_tmp
    select m.FECHA, m.HORA, m.COD_USUARIO, m.NRO_SECUENCIA, 
       m.FEC_VALOR, m.MONTO, m.MTO_EQU_LOCAL, m.COTIZACION ,m.NRO_CUENTA, 
       t.COD_PERSONA, m.COD_MONEDA,
       m.ESTADO,m.CONCEPTO,
       m.REVERSADO,COD_USU_REVERSION,HOR_REVERSION, --datos de reversion
       m.COD_TRA_PADRE, m.COD_TRANSACCION,
       m.COD_MODULO, m.COD_MODALIDAD,
       m.NRO_DOCUMENTO,m.NRO_DOCUMENTO4, m.REFERENCIA, t.cod_persona cod_per_referencia,
       DECODE(m.COD_TRANSACCION,515,'C',560,'C',TH.TIPO)  tip_movimiento,
       x.cod_rubro, x.tip_movimiento tip_movimiento_asi, x.mto_mon_rubro, 
       x.mto_mon_local, x.val_cotizacion, x.descripcion,
       decode(m.REVERSADO,'S','D','-') rev_tipo,
       'N' tie_factura --marca como que no tiene factura por defecto
    from AF_MOVIMIENTOS_HIS m
         left join GE_TRANSACCIONES TH on m.COD_MODULO = TH.COD_MODULO and m.COD_MODALIDAD = TH.COD_MODALIDAD
              and m.COD_TRANSACCION = TH.COD_TRANSACCION
          join cb_cif_asientos_tmp x on x.fecha = m.FECHA 
              and x.ref_movimiento = m.NRO_DOCUMENTO4
          left join ge_cta_clientes t on t.nro_cuenta=m.REFERENCIA and t.relacion = 'P';

    insert into cb_cif_movimientos_tmp
    select m.FECHA, m.HORA, m.COD_USUARIO, m.NRO_SECUENCIA, 
       m.FEC_VALOR, m.MONTO, m.MTO_EQU_LOCAL, m.COTIZACION ,m.NRO_CUENTA, 
       t.COD_PERSONA, m.COD_MONEDA,
       m.ESTADO,m.CONCEPTO,
       m.REVERSADO,COD_USU_REVERSION,HOR_REVERSION, --datos de reversion
       m.COD_TRA_PADRE, m.COD_TRANSACCION,
       m.COD_MODULO, m.COD_MODALIDAD,
       m.NRO_DOCUMENTO,m.NRO_DOCUMENTO4, m.REFERENCIA, t.cod_persona cod_per_referencia,
       DECODE(m.COD_TRANSACCION,515,'C',560,'C',TH.TIPO)  tip_movimiento,
       x.cod_rubro, x.tip_movimiento tip_movimiento_asi, x.mto_mon_rubro, 
       x.mto_mon_local, x.val_cotizacion, x.descripcion,
       decode(m.REVERSADO,'S','D','-') rev_tipo,
       'N' tie_factura --marca como que no tiene factura por defecto
    from BU_MOVIMIENTOS_HIS m
         left join GE_TRANSACCIONES TH on m.COD_MODULO = TH.COD_MODULO and m.COD_MODALIDAD = TH.COD_MODALIDAD
              and m.COD_TRANSACCION = TH.COD_TRANSACCION
          join cb_cif_asientos_tmp x on x.fecha = m.FECHA 
              and x.ref_movimiento = m.NRO_DOCUMENTO4
          left join ge_cta_clientes t on t.nro_cuenta=m.REFERENCIA and t.relacion = 'P';

    insert into cb_cif_movimientos_tmp
    select m.FECHA, m.HORA, m.COD_USUARIO, m.NRO_SECUENCIA, 
       m.FEC_VALOR, m.MONTO, m.MTO_EQU_LOCAL, m.COTIZACION ,m.NRO_CUENTA, 
       t.COD_PERSONA, m.COD_MONEDA,
       m.ESTADO,m.CONCEPTO,
       m.REVERSADO,COD_USU_REVERSION,HOR_REVERSION, --datos de reversion
       m.COD_TRA_PADRE, m.COD_TRANSACCION,
       m.COD_MODULO, m.COD_MODALIDAD,
       m.NRO_DOCUMENTO,m.NRO_DOCUMENTO4, m.REFERENCIA, t.cod_persona cod_per_referencia,
       DECODE(m.COD_TRANSACCION,515,'C',560,'C',TH.TIPO)  tip_movimiento,
       x.cod_rubro, x.tip_movimiento tip_movimiento_asi, x.mto_mon_rubro, 
       x.mto_mon_local, x.val_cotizacion, x.descripcion,
       decode(m.REVERSADO,'S','D','-') rev_tipo,
       'N' tie_factura --marca como que no tiene factura por defecto
    from GE_MOVIMIENTOS_HIS m
         left join GE_TRANSACCIONES TH on m.COD_MODULO = TH.COD_MODULO and m.COD_MODALIDAD = TH.COD_MODALIDAD
              and m.COD_TRANSACCION = TH.COD_TRANSACCION
          join cb_cif_asientos_tmp x on x.fecha = m.FECHA 
              and x.ref_movimiento = m.NRO_DOCUMENTO4
          left join ge_cta_clientes t on t.nro_cuenta=m.REFERENCIA and t.relacion = 'P';  
    
    pr_gen_estadisticas('cb_cif_movimientos_tmp');
    
    -- detalle de facturas CB_CIF_FACTURAS_TMP
    insert into CB_CIF_FACTURAS_TMP
    select 
      --detalle de factura
      b.FECHA,
      b.HORA,
      b.COD_USUARIO,
      b.NRO_SECUENCIA,
      b.NRO_FACTURA,
      b.NRO_TIMBRADO,
      b.COD_OFI_ORIGEN,
      b.COD_TRA_PADRE,
      b.NRO_DOCUMENTO,
      b.DESCRIPCION,
      b.COD_MONEDA,
      b.MTO_EXENTO,
      b.MTO_EXENTO_GS,
      b.MTO_GRAVADO_5,
      b.MTO_GRA_5_GS,
      b.MTO_GRAVADO_10,
      b.MTO_GRA_10_GS,
      b.IMPUESTO_5,
      b.IMPUESTO_5_GS,
      b.IMPUESTO_10,
      b.IMPUESTO_10_GS,
      b.COTIZACION,
      b.USU_INSERCION,
      b.FEC_INSERCION,
      b.USU_MODIFICACION,
      b.FEC_MODIFICACION,
      b.NRO_CUENTA,
      b.AJU_IMPUESTO_5,
      b.AJU_IMPUESTO_10,
      b.COD_MOD_PADRE,
      b.COD_MAD_PADRE,
      b.COD_TRANSACCION,
      b.COD_MODULO,
      b.COD_MODALIDAD,
      --cabecera de factura
      c.TIP_COMPROBANTE,
      c.TIP_VENTA,
      c.COD_PERSONA,
      --desde detalle de movimientos
      a.fecha,
      a.hora,
      a.cod_usuario,
      a.nro_secuencia,
      a.monto,   
      a.mto_equ_local,
      a.nro_cuenta,
      a.cod_persona,
      a.cod_moneda,
      a.cod_tra_padre,
      a.cod_transaccion,
      a.cod_modulo,
      a.cod_modalidad,
      a.nro_documento,
      a.referencia,     
      a.cod_per_referencia,
      a.tip_movimiento,
      a.reversado,
      a.cod_rubro
      , decode(nvl(decode(a.cod_moneda,'GS',a.monto, a.mto_equ_local),0), b.MTO_GRAVADO_10,'SI',
              b.MTO_GRA_10_GS,'SI',b.MTO_EXENTO,'SI',b.Mto_Exento_Gs,'SI',b.MTO_EXENTO,'SI','NO') match_monto
           , abs( a.monto - decode(a.cod_moneda, 'GS', MTO_GRA_10_GS+b.MTO_EXENTO_GS, b.MTO_GRAVADO_10+b.MTO_EXENTO)) match_mto_mon_diff
           , abs( decode( a.cod_moneda, 'GS', a.monto, a.mto_equ_local) - (MTO_GRA_10_GS+b.MTO_EXENTO_GS)) match_mto_gs_diff
           , decode(a.cod_tra_padre, b.cod_tra_padre,'SI','NO') match_tra_pad
           , decode(a.nro_cuenta, b.nro_cuenta,'SI','NO') match_nro_cuenta
           , decode(a.referencia, b.nro_cuenta,'SI','NO') match_cta_referencia
           , decode(a.cod_per_referencia, c.cod_persona,'SI','NO') match_per_referencia
           , decode(a.cod_persona, c.cod_persona,'SI','NO') match_cod_persona
           , decode(a.NRO_DOCUMENTO, b.nro_documento,'SI','NO') match_nro_documento
           
           , decode(a.nro_secuencia,b.nro_secuencia,'SI','NO') Match_nro_secuencia,
             abs(a.nro_secuencia-b.nro_secuencia) Match_sec_dif,
             'NO' duplicado,
             null Utilizar,
             null COD_MATCH,
             'basica' tip_conciliacion
    from cb_cif_movimientos_tmp a
         join cb_lib_ventas_det b on a.fecha=b.fecha and a.hora=b.hora
              and a.cod_usuario=b.cod_usuario 
              and a.NRO_SECUENCIA IN (b.nro_secuencia-2,b.nro_secuencia-1, b.nro_secuencia, b.nro_secuencia+1, b.nro_secuencia+2)
         join cb_lib_ventas c on c.nro_factura=b.nro_factura and c.nro_factura=b.nro_factura;
     
     pr_gen_estadisticas('cb_cif_facturas_tmp');   
  end;
  
  -- Depura tablas tmp
  Procedure pr_dep_facturas is  
  begin
    vg_proceso := 'pr_dep_facturas';
    -- Depuracion de facturas    
    -- se elimina los registros duplicados que tienen registros matchean por nro de secuencia perfectamente
    delete from cb_cif_facturas_tmp a
    where Exists 
       (select b.match_nro_secuencia
           from cb_cif_facturas_tmp b
           where b.match_nro_secuencia = 'SI'
           and b.mov_fecha = a.mov_fecha and b.mov_hora = a.mov_hora 
           and b.mov_cod_usuario=a.mov_cod_usuario and b.mov_nro_secuencia=a.mov_nro_secuencia
        )
        and a.match_nro_secuencia = 'NO';
        
    -- se eliminan registros con facturas-nro secuencia que ya tienen match exacto
    delete from cb_cif_facturas_tmp a
    where Exists 
       (select b.match_nro_secuencia
           from cb_cif_facturas_tmp b
           where b.match_nro_secuencia = 'SI'
           and b.FECHA = a.FECHA and b.HORA = a.HORA 
           and b.COD_USUARIO=a.COD_USUARIO and b.NRO_SECUENCIA=a.NRO_SECUENCIA
           and b.NRO_FACTURA=a.NRO_FACTURA and	b.NRO_TIMBRADO=a.NRO_TIMBRADO
        )
        and a.match_nro_secuencia = 'NO';
        
    -- se marcan registros duplicados
    update cb_cif_facturas_tmp a
        set a.duplicado = 'SI'
    where Exists 
       (select 'SI'
        from (select mov_fecha,mov_hora,mov_cod_usuario,mov_nro_secuencia, count(1) cant
             from cb_cif_facturas_tmp
             group by mov_fecha,mov_hora,mov_cod_usuario,mov_nro_secuencia) b
        where b.cant > 1
              and a.mov_fecha= b.mov_fecha and a.mov_hora=b.mov_hora and a.mov_cod_usuario=b.mov_cod_usuario          
                  and a.mov_nro_secuencia=b.mov_nro_secuencia);
    
    -- Marca Match Facturas
    -- Match perfecto Monto Nro secuencia
    update cb_cif_facturas_tmp set UTILIZAR = 'SI', COD_MATCH = 'MTO_SEC'
    where match_nro_secuencia = 'SI' and match_monto = 'SI';
    -- Match Nro secuencia
    update cb_cif_facturas_tmp set UTILIZAR = 'SI', COD_MATCH = 'NRO_SEC'
    where match_nro_secuencia = 'SI' and match_monto = 'NO'; --OJO este se puedi unir con el de arriba?!
    --MTO_REF_SEC2
    update cb_cif_facturas_tmp set UTILIZAR = 'SI', COD_MATCH = 'MTO_REF_SEC2'
    where match_nro_secuencia = 'NO' and MATCH_SEC_DIF = 2 and MATCH_CTA_REFERENCIA = 'SI'
    and match_monto = 'SI';
    --MTO_REF_SEC1
    update cb_cif_facturas_tmp set UTILIZAR = 'SI', COD_MATCH = 'MTO_REF_SEC1'
    where match_nro_secuencia = 'NO' and DUPLICADO = 'NO' and MATCH_SEC_DIF = 1 
    and MATCH_CTA_REFERENCIA = 'SI' and MATCH_TRA_PAD = 'SI'
    and match_monto = 'SI';
    --Marcar Malos
    update cb_cif_facturas_tmp set UTILIZAR = 'NO', COD_MATCH = 'NO_MATCH'
    where match_nro_secuencia = 'NO' and MATCH_COD_PERSONA = 'NO'
     and MATCH_NRO_CUENTA = 'NO' and MATCH_CTA_REFERENCIA = 'NO' and MATCH_PER_REFERENCIA = 'NO'
     and MATCH_MONTO = 'NO';
    
    -- control duplicados 
    -- se elimina los registros duplicados que tienen registros que matchean
    delete from cb_cif_facturas_tmp a
    where Exists 
       (select b.match_nro_secuencia
           from cb_cif_facturas_tmp b
           where UTILIZAR = 'SI'
           and b.mov_fecha = a.mov_fecha and b.mov_hora = a.mov_hora 
           and b.mov_cod_usuario=a.mov_cod_usuario and b.mov_nro_secuencia=a.mov_nro_secuencia
        )
        and COD_MATCH = 'NO_MATCH' or COD_MATCH is Null
    ;
    -- eliminar registros con facturas-nro secuencia que ya tienen match exacto con mov v07c
    delete from cb_cif_facturas_tmp a
    where Exists 
       (select b.match_nro_secuencia
           from cb_cif_facturas_tmp b
           where UTILIZAR = 'SI'
           and b.FECHA = a.FECHA and b.HORA = a.HORA 
           and b.COD_USUARIO=a.COD_USUARIO and b.NRO_SECUENCIA=a.NRO_SECUENCIA
           and b.NRO_FACTURA=a.NRO_FACTURA and	b.NRO_TIMBRADO=a.NRO_TIMBRADO
        )
        and a.COD_MATCH = 'NO_MATCH' or a.COD_MATCH is Null; 
           
    -- 7 se marcan registros duplicados
    --se reinicializa
    update cb_cif_facturas_tmp a
        set a.duplicado = 'NO' where 1=1;
    --se marca   
    update cb_cif_facturas_tmp a
        set a.duplicado = 'SI'
    where Exists 
       (select 'SI'
        from (select mov_fecha,mov_hora,mov_cod_usuario,mov_nro_secuencia, count(1) cant
             from cb_cif_facturas_tmp
             group by mov_fecha,mov_hora,mov_cod_usuario,mov_nro_secuencia) b
        where b.cant > 1
              and a.mov_fecha= b.mov_fecha and a.mov_hora=b.mov_hora and a.mov_cod_usuario=b.mov_cod_usuario          
                  and a.mov_nro_secuencia=b.mov_nro_secuencia);
                  
     --pr_gen_estadisticas('cb_cif_facturas_tmp');
  end;
  
  -- Actualiza tabla de movimientos
  Procedure pr_act_movimientos is  
  begin
    vg_proceso := 'pr_act_movimientos';
    -- Depuracion de movimientos
    -- se marcan movimientos si es que tiene factura
    update cb_cif_movimientos_tmp a
       set a.tie_factura='S'
    where exists (select 'S'
                 from cb_cif_facturas_tmp b
                 where b.mov_fecha=a.fecha and a.hora=b.mov_hora  
                 and a.cod_usuario=b.mov_cod_usuario and a.nro_secuencia=b.mov_nro_secuencia);
                 
    ------
    -- marcado de movimientos reversados como
    -- D del dia - 
    -- M dentro del mes - 
    -- O Original del Mes
    -- H Historico (fuera del mes)
    -- V verificar, casos especiales

    -- marcar reversados dias diferentes
    --negativo es el mov de reversion
    update cb_cif_movimientos_tmp t
    set t.tip_reversion =  decode(to_char(fecha,'mm'), to_char(fec_valor,'mm'),'M','H')
    where ( t.reversado='S'
            or ( t.hor_reversion is not null and t.cod_usu_reversion is not null) --incluye extornos 
          )
       and t.fec_valor != t.fecha
       and t.monto < 0;

    --  casos a verificar
    -- la mayoria se va a marcar como M si el mov de reversion esta en el mes actual
    update cb_cif_movimientos_tmp t
    set t.tip_reversion =  'V'
    where ( t.reversado='S'
            or ( t.hor_reversion is not null and t.cod_usu_reversion is not null) --incluye extornos 
          )
       and t.fec_valor != t.fecha
       and t.monto >= 0;

    --marcar mov originales reversados - solo los tipo M como O
    update cb_cif_movimientos_tmp a
       set a.tip_reversion='O'
    where exists (select 'S'
                 from cb_cif_movimientos_tmp b
                 where b.tip_reversion='M' 
                 and a.fecha=b.fec_valor and a.hora=b.hor_reversion
                 and a.cod_usuario=b.cod_usu_reversion and a.nro_secuencia=b.nro_secuencia);    
  end;
  
  --CB_CIF_INF_DETALLE
  Procedure pr_gen_det_conciliacion is  
  begin
     vg_proceso := 'pr_gen_det_conciliacion';
     Insert into cb_cif_inf_detalle
     select a.fecha, a.cod_rubro, c.descripcion,
           mto_asientos, 
           nvl(mto_movimientos,0),
           nvl(mto_mov_rev_do,0), nvl(mto_mov_rev_dr,0),
           nvl(mto_mov_rev_mo,0), nvl(mto_mov_rev_mr,0), 
           nvl(mto_mov_rev_h,0), nvl(mto_mov_rev_v,0),
           nvl(mto_asi_sin_mov,0),  
           nvl(e.mto_factura,0), nvl(mto_ncredito,0),
           nvl(mto_fac_eli_reversiones,0), nvl(mto_fac_eli_diferencias,0),
           -- diferencias
           nvl(abs(mto_asientos),0) - nvl(abs(mto_movimientos),0)  dif_mov_asientos, 
           (nvl(abs(mto_asientos),0)) - abs( nvl(abs(e.mto_factura),0) -  
                nvl(abs(e.mto_ncredito),0)) dif_fac_asi_basica, 
           -- aut9 este calculo devuelve 3092 registros sin diff a dic 2019, mejoras en rev_mr
           abs(nvl(mto_asientos,0) - nvl(mto_asi_sin_mov,0)) - 
                nvl(abs(mto_mov_rev_mo),0) - 
                abs( nvl(abs(e.mto_factura),0) + nvl(mto_mov_rev_mr,0) -  
                     nvl(abs(e.mto_ncredito),0)) dif_fac_asi_aut,             
           decode(abs(nvl(mto_asientos,0)), 0,-999, 
                round(abs((nvl(abs(mto_asientos),0) - nvl(abs(mto_asi_sin_mov),0)) - 
                    nvl(abs(mto_mov_rev_mo),0) - 
                    abs( nvl(abs(e.mto_factura),0)+ nvl(mto_mov_rev_mr,0) -  
                         nvl(abs(e.mto_ncredito),0))) * 100/ nvl(abs(mto_asientos),0),3)) dif_por_automatica,
           nvl(abs(mto_asi_sin_mov),0) mto_fac_fal_asi_directos,             
           nvl(abs( abs(nvl(mto_asientos,0) - nvl(mto_asi_sin_mov,0)) - 
                nvl(abs(mto_mov_rev_mo),0) - abs( nvl(abs(e.mto_factura),0) + 
                nvl(mto_mov_rev_mr,0) -  nvl(abs(e.mto_ncredito),0))),0) mto_fac_fal_automatico
     from 
          -- maestro de asientos 
          (select x.fecha, x.cod_rubro, sum(decode(x.tip_movimiento,'D',nvl(x.mto_mon_local,0)*-1,nvl(x.mto_mon_local,0))) mto_asientos
          from cb_cif_asientos_tmp x 
          where substr(x.cod_rubro, 1, 5) IN ( select to_char(regexp_substr(vg_rub_ingresos,'[^,]+', 1, level)) 
                                             from dual
                                             connect by regexp_substr(vg_rub_ingresos, '[^,]+', 1, level) is not null )
          group by x.fecha, x.cod_rubro) a 
            
          join cb_rubros c on c.cod_rubro = a.cod_rubro

          -- asientos generados por movimientos
          left join (select y.fecha, y.cod_rubro, 
                           sum( decode(y.cod_moneda,
                                      'GS', decode(y.tip_movimiento,'D', y.monto*-1,y.monto),
                                      decode(y.tip_movimiento,'D', y.mto_equ_local*-1,y.mto_equ_local)
                           )) mto_movimientos 
               from cb_cif_movimientos_tmp y
               where y.tip_reversion = '-'
               group by y.fecha, y.cod_rubro) b on a.fecha=b.fecha and a.cod_rubro=b.cod_rubro
           -- rev del dia operacion original
           left join (select y.fecha, y.cod_rubro, 
                          sum( decode(y.cod_moneda,'GS', y.monto, y.mto_equ_local)) mto_mov_rev_do
               from cb_cif_movimientos_tmp y
               where y.tip_reversion = 'D'
               and y.monto > 0
               group by y.fecha, y.cod_rubro) j on a.fecha = j.fecha and a.cod_rubro = j.cod_rubro
           -- rev del dia - reversion   
           left join (select y.fecha, y.cod_rubro, 
                         sum( decode(y.cod_moneda,'GS', y.monto, y.mto_equ_local)) mto_mov_rev_dr 
               from cb_cif_movimientos_tmp y
               where y.tip_reversion = 'D'
               and y.monto < 0
               group by y.fecha, y.cod_rubro) j2 on a.fecha=j2.fecha and a.cod_rubro=j2.cod_rubro  
           -- reversion historica        
           left join (select y.fecha, y.cod_rubro,
                         sum( decode(y.cod_moneda,'GS', y.monto, y.mto_equ_local)) mto_mov_rev_h 
               from cb_cif_movimientos_tmp y
               where y.tip_reversion = 'H'
               group by y.fecha, y.cod_rubro) k on a.fecha=k.fecha and a.cod_rubro=k.cod_rubro
           -- movimiento de reversion del mes
           left join (select y.fecha, y.cod_rubro, 
                         sum( decode(y.cod_moneda,'GS', y.monto, y.mto_equ_local)) mto_mov_rev_mr 
               from cb_cif_movimientos_tmp y
               where y.tip_reversion = 'M'
               group by y.fecha, y.cod_rubro) l on a.fecha=l.fecha and a.cod_rubro=l.cod_rubro  
           -- movimiento reversado del mes  
           left join (select y.fecha, y.cod_rubro, 
                         sum(decode(y.cod_moneda, 'GS', y.monto, y.mto_equ_local)) mto_mov_rev_mo 
               from cb_cif_movimientos_tmp y
               where y.tip_reversion = 'O'
               group by y.fecha, y.cod_rubro) n on a.fecha=n.fecha and a.cod_rubro=n.cod_rubro  
           -- movimiento de reversion a verificar  
           left join (select y.fecha, y.cod_rubro, 
                         sum( decode(y.cod_moneda, 'GS', y.monto, y.mto_equ_local)) mto_mov_rev_v
               from cb_cif_movimientos_tmp y
               where y.tip_reversion = 'V'
               group by y.fecha, y.cod_rubro) m on a.fecha=m.fecha and a.cod_rubro=m.cod_rubro 
               
          -- asientos no relacionado a movimientos
          left join (select x.fecha, x.cod_rubro, sum(decode(x.tip_movimiento,'D',nvl(x.mto_mon_local,0)*-1,nvl(x.mto_mon_local,0))) mto_asi_sin_mov
          from cb_asientos_det_his x 
          where x.fecha between vg_fec_inicial and vg_fec_final
               and substr(x.cod_rubro, 1, 5) IN ( select to_char(regexp_substr(vg_rub_ingresos,'[^,]+', 1, level)) 
                                             from dual
                                             connect by regexp_substr(vg_rub_ingresos, '[^,]+', 1, level) is not null )
               and x.ref_movimiento is null
          group by x.fecha, x.cod_rubro) d on a.fecha=d.fecha and a.cod_rubro=d.cod_rubro
            
          -- facturas y notas de credito 
          left join (select f.mov_fecha fecha, f.cod_rubro, 
               sum(decode( f.tip_comprobante,
                           'F', (nvl(f.MTO_EXENTO_GS,0)+nvl(MTO_GRA_5_GS,0)+nvl(f.MTO_GRA_10_GS,0)),
               0)) mto_factura,
               sum(decode( f.tip_comprobante,
               'F', 0,
               (nvl(f.MTO_EXENTO_GS,0)+nvl(MTO_GRA_5_GS,0)+nvl(f.MTO_GRA_10_GS,0)))) mto_ncredito
          from cb_cif_facturas_tmp f 
          where f.mov_fecha between vg_fec_inicial and vg_fec_final
                and f.utilizar='SI'
          group by f.mov_fecha, f.cod_rubro) e on a.fecha = e.fecha and a.cod_rubro = e.cod_rubro        
             
          -- fac borradas
          left join (select y.fecha, y.cod_rubro, 
                        sum( decode(y.cod_moneda, 'GS', y.monto, y.mto_equ_local)) mto_fac_eli_reversiones
           from cb_cif_movimientos_tmp y
                join cb_obs_lib_ventas_det_tmp z on y.fecha=z.fecha and y.hora=z.hora
                     and y.cod_usuario=z.cod_usuario and y.nro_secuencia=z.nro_secuencia
                     and z.error = 'Operación Reversada'
           group by y.fecha, y.cod_rubro) h on a.fecha = h.fecha and a.cod_rubro=h.cod_rubro
             
           left join (select y.fecha, y.cod_rubro, 
                         sum( decode(y.cod_moneda, 'GS', y.monto, y.mto_equ_local)) mto_fac_eli_diferencias
           from cb_cif_movimientos_tmp y
                join cb_obs_lib_ventas_det_tmp z on y.fecha=z.fecha and y.hora=z.hora
                     and y.cod_usuario=z.cod_usuario and y.nro_secuencia=z.nro_secuencia
                     and z.error != 'Operación Reversada'
           group by y.fecha, y.cod_rubro) h on a.fecha = h.fecha and a.cod_rubro=h.cod_rubro 
     order by a.cod_rubro, a.fecha;

  end;
  -- Verificacion de existencia de registros a fecha solicitada
  Procedure pr_ver_datos is
     v_cant number(9);
  Begin
     select count(1)
     into v_cant
     from CB_CIF_INF_DETALLE t
     where t.fecha = vg_fec_final;
     IF v_cant = 0 then
        raise_application_error(-20001,'No hay datos de conciliacion a fecha ' || to_char(vg_fec_final,'dd/mm/yyyy')
           ||'. Verifique la generacion de datos.');
     END IF;
  Exception        
     WHEN OTHERS THEN
        raise_application_error(-20000,sqlerrm);
  End;
  -- Verificacion de Fecha de Parametro CIF_FEC_CONCILIACION
  Procedure pr_ver_fecha(p_valor in varchar2) is
     v_fecha       date;
     v_separador   varchar2(1);
  Begin
     vg_proceso := 'pr_ver_fecha';
     -- Valida longitud  
     If length(p_valor) != 10 Then
        raise_application_error(-20000, 'El formato de la fecha debe ser DD/MM/AAAA.');
     End If;
     -- Obtiene separador 
     IF INSTR(p_valor,'/') > 0 then
       v_separador := '/';
     ELSE
       raise_application_error(-20000, 'El formato de la fecha debe ser dd/mm/AAAA.');
     END IF;
     -- Intenta convertir el string a fecha       
     Begin
        v_fecha := to_date(p_valor,'dd' || v_separador || 'mm' || v_separador || 'yyyy');
     Exception
        When Others Then
           If Sqlcode = -1841 Then
              raise_application_error(-20003, 'Año no válido. ' || Sqlerrm);
           Elsif Sqlcode = -1843 Then
              raise_application_error(-20003, 'Mes no válido. ' || Sqlerrm);
           Else
              raise_application_error(-20002, 'El formato de la fecha debe ser DD/MM/AAAA. ' || Sqlerrm);
           End If;
     End;
  Exception
     When Others Then
        If Sqlcode <= -20000 Then
           Raise;
        Else
           raise_application_error(-20003, vg_proceso || '. ' || Sqlcode);
        End If;
  End;
  -- Verifica de rango de horarios permitidos para el procesamiento
  Procedure pr_ver_horarios  is  
    v_es_permitido     varchar2(2);
    v_hora_disp        varchar2(200);
    v_mensaje          varchar2(250);
    v_sysdate          date;
    v_sys_hora         varchar2(8);
    v_nro_dia          number;
    v_contador         number;
    -- Devuelve SI en caso de sabados domingos y feriados
    Function lp_dia_feriados return varchar2 is
      v_es_feriado     varchar2(2);
    begin
      v_sysdate   := sysdate;
      v_sys_hora  := to_char(sysdate,'HH24:MI:SS');
      v_es_feriado  := 'NO';
      -- Controla si es feriado oficina 31
      if fue_ctr_fec_feriado(v_sysdate, 31) then
         v_es_feriado := 'SI';
      else 
         select to_char(v_sysdate, 'D') 
         into v_nro_dia
         from dual;
         -- si es 6 sabado o 7 domingo
         if v_nro_dia > 5 then
            v_es_feriado := 'SI';
         end if;
      end if;
      return v_es_feriado;
    end;
    -- despliega horarios de prosesamiento en forma de texto
    Function lp_obt_horarios return varchar2 is
      v_retorno              varchar2(200);
      cursor c_horarios is select a.inicio, b.fin  
          from (select rownum id_hora, to_char(regexp_substr( vg_hor_procesa,'[^,]+', 1, level)) inicio 
                from dual
                connect by regexp_substr( vg_hor_procesa, '[^,]+', 1, level) is not null ) a 
                   join (select rownum id_hora, to_char(regexp_substr( vg_hor_procesa,'[^,]+', 1, level)) fin 
                         from dual
                         connect by regexp_substr( vg_hor_procesa, '[^,]+', 1, level) is not null ) b on a.id_hora+1=b.id_hora
                            and mod(b.id_hora,2) = 0 -- b obtiene lineas pares, horas de fin
          where mod(a.id_hora,2) <> 0; 
    begin
       v_retorno := '';
       v_contador := 0;
       for hora in c_horarios loop
           if v_contador > 0 then
              v_retorno := v_retorno || ' y ';
           end if;
           v_contador := v_contador + 1;
           v_retorno := v_retorno || hora.inicio ||' - ' || hora.fin;
       end loop;
       if v_contador = 0 then
          v_retorno := 'No hay horarios configurados actualmente. Verifique parametro dinamico CIF_INF_HOR_PROC.';
       else
          v_retorno := 'Los horarios para procesamiento son ' || v_retorno || '. Fte: Parametro dinamico CIF_INF_HOR_PROC.';
       end if;
       return v_retorno;
    end;
  begin
     vg_proceso  := 'lp_obt_horarios';
     if vg_hor_control = 'SI' then
        -- controla sabado domingo y feriado
        if lp_dia_feriados = 'NO' then
            -- No es feriado ni sabado ni domingo, controla por horario
            -- recupera el parametro dinamico CIF_INF_HOR_PROC
            vg_hor_procesa := fug_obt_pardinamico('CIF_INF_HOR_PROC');
            v_es_permitido := 'NO';
            begin
              select  'SI' respuesta
              into v_es_permitido      
              from (select to_char(sysdate,'HH24:MI:SS') ahora, a.inicio, b.fin  
                    from (select rownum id_hora, to_char(regexp_substr( vg_hor_procesa,'[^,]+', 1, level)) inicio 
                          from dual
                          connect by regexp_substr( vg_hor_procesa, '[^,]+', 1, level) is not null ) a 
                             join (select rownum id_hora, to_char(regexp_substr( vg_hor_procesa,'[^,]+', 1, level)) fin 
                                   from dual
                                   connect by regexp_substr( vg_hor_procesa, '[^,]+', 1, level) is not null ) b on a.id_hora+1=b.id_hora
                                      and mod(b.id_hora,2) = 0 -- b obtiene lineas pares, horas de fin
                    where mod(a.id_hora,2) <> 0 )-- a obtiene lineas impares, horas de inicio
              where to_date(ahora,'HH24:MI:SS') between to_date(inicio,'HH24:MI:SS') and to_date(fin,'HH24:MI:SS');
            exception
               when others then
                  v_es_permitido := 'NO';
             end;
         else
            -- es dia feriado, permite procesar
            v_es_permitido := 'SI';
         end if;
     else 
        v_es_permitido := 'SI';
     end if;
     -- Despliegua mensaje de error y detiene el procesamiento
     if v_es_permitido = 'NO' then
        -- obtiene horarios configurados
        v_hora_disp := lp_obt_horarios;
        if v_contador > 0 then
           v_mensaje := 'No se puede ejecutar el proceso en este horario ('|| v_sys_hora ||'). ' || v_hora_disp;
        else
           v_mensaje := v_hora_disp;
        end if;
        raise_application_error(-20000,v_mensaje);
     end if;
  end;
  
  -- Envia archivo por FTP
  procedure lp_env_arc_ftp(p_nom_archivo IN varchar2, 
                       p_ftp_dir_repositorio IN varchar2, 
                       p_ftp_dir_ip IN varchar2, 
                       p_ftp_dir_puerto IN varchar2, 
                       p_ftp_usuario IN varchar2, 
                       p_ftp_contrasena IN varchar2) is
    v_conexion      UTL_TCP.connection;
    v_det_error     varchar2(1000);
  BEGIN
    vg_proceso := 'lp_env_arc_ftp';
    v_det_error := null;
    v_conexion := utl_ftp.login(p_ftp_dir_ip, p_ftp_dir_puerto, p_ftp_usuario, p_ftp_contrasena); 
    utl_ftp.binary(p_conn => v_conexion);
    utl_ftp.put(p_conn      => v_conexion,
                p_from_dir  => vg_repositorio,
                p_from_file => p_nom_archivo,
                p_to_file   => p_ftp_dir_repositorio || p_nom_archivo 
                );
    utl_ftp.logout(v_conexion);
    UTL_TCP.close_all_connections;
  EXCEPTION
    WHEN OTHERS THEN
      v_det_error := substr(sqlerrm,1,400);
      begin
        UTL_TCP.close_connection(v_conexion);
      exception
        when others then
          v_det_error := v_det_error || substr(sqlerrm,1,400);
      end;
      IF nvl(LENGTH(v_det_error),0) > 0 THEN
         raise_application_error(-20000,vg_proceso ||' '|| v_det_error);
      END IF;
  END;
  
  -- Controla Generacion de Datos 
  -- Evita reproceso a la misma fecha en caso que el procesamiento finalice correctamente
  function lf_gen_control return varchar2 is
  begin
     vg_fec_generacion := to_date(nvl(fug_obt_pardinamico('CIF_INF_GEN_CTRL'),'01/01/1900'),'dd/mm/yyyy');
     if vg_fec_generacion = vg_fec_final then
        return 'NO'; -- no se va a ejecutar
     else
        return 'SI'; -- si se va a ejecutar
     end if;
  end;
  
  -- Actualiza fecha de generacion para control de reproceso
  procedure lp_act_control is
  begin
     update ge_par_dinamicos t
     set t.val_parametro = to_char(vg_fec_final,'dd/mm/yyyy')
     where t.parametro = 'CIF_INF_GEN_CTRL';
  exception
    when others then
       raise_application_error(-20001,'Error al actualizar parametro CIF_INF_GEN_CTRL '|| sqlerrm);
  end;
  -- Genera achivo desde tabla
  procedure pr_gen_arc_tabla (p_tabla in varchar2) is
     --variables para archivo
     v_archivo        UTL_FILE.FILE_TYPE;
     v_linea          VARCHAR2(32767);
     v_arc_nombre     VARCHAR2(128); -- nombre del archivo
     v_buffer         VARCHAR2(32767);

     cursor cur_asientos is
        select *
        from cb_cif_asientos_tmp
        order by fecha,cod_rubro,nro_asiento,nro_linea;
        
     cursor cur_movimientos is
        select *
        from cb_cif_movimientos_tmp
        order by fecha,hora,cod_usuario,nro_secuencia;
 
     cursor cur_facturas is
        select *
        from cb_cif_facturas_tmp
        order by fecha,hora,cod_usuario,nro_secuencia;
     
     cursor cur_det_diario is
        select a.*,
               decode(nvl(b.cod_rub_ini,'-9'),'-9',null,'NO FACTURA') observacion
        from cb_cif_inf_detalle a
             left join ( select to_char(regexp_substr(vg_rub_sin_factura,'[^,]+', 1, level)) cod_rub_ini 
                         from dual
                         connect by regexp_substr(vg_rub_sin_factura, '[^,]+', 1, level) is not null ) b
                         on b.cod_rub_ini = substr(a.cod_rubro,1,5)
        where fecha between vg_fec_inicial and vg_fec_final
        order by cod_rubro, fecha;
     /*      
     function lf_obt_cabecera(p_tabla varchar2) return varchar2 is
        v_cabecera    varchar2(3000);
        cursor cur_columnas  (p_tabla varchar2) is
           SELECT column_name 
           FROM dba_tab_columns 
           WHERE TABLE_NAME = upper(p_tabla) ORDER BY COLUMN_ID;      
     begin
       v_cabecera := '';
       for rec in cur_columnas( p_tabla) loop
          if nvl(length(v_cabecera),0) > 0 then
            v_cabecera := v_cabecera || vg_csv_separador;
          end if;
          v_cabecera := v_cabecera || rec.column_name;
       end loop;          
       return v_cabecera;
     end lf_obt_cabecera;   
     */
  begin
     vg_proceso := 'pr_gen_arc_tabla';
     -- Genera Archivo Detalle de Asientos
     if upper(p_tabla)= upper('cb_cif_asientos_tmp') then
        v_arc_nombre := vg_mes_archivo || '_' || upper(p_tabla)||vg_arc_detalle||'.'|| vg_arc_extension;
        -- abre el archivo
        v_archivo := UTL_FILE.FOPEN(vg_repositorio, v_arc_nombre,'W',32767);
        -- genera cabecera
        --v_linea := lf_obt_cabecera(p_tabla)|| vg_tabulador;
        v_linea := 'FECHA' || vg_csv_separador || 'COD_OFICINA' || vg_csv_separador 
                || 'NRO_ASIENTO' || vg_csv_separador || 'NRO_LINEA' || vg_csv_separador 
                || 'COD_RUBRO' || vg_csv_separador || 'TIP_MOVIMIENTO' || vg_csv_separador 
                || 'MTO_MON_RUBRO' || vg_csv_separador || 'MTO_MON_LOCAL' || vg_csv_separador 
                || 'DESCRIPCION' || vg_csv_separador || 'REFERENCIA' || vg_csv_separador 
                || 'PROTEGIDO' || vg_csv_separador || 'ACTUALIZADO' || vg_csv_separador 
                || 'VAL_COTIZACION' || vg_csv_separador || 'DISTRIBUIDO' || vg_csv_separador 
                || 'REF_MOVIMIENTO' || vg_csv_separador || 'USU_INSERCION' || vg_csv_separador 
                || 'FEC_INSERCION' || vg_csv_separador || 'USU_MODIFICACION' || vg_csv_separador 
                || 'FEC_MODIFICACION' || vg_csv_separador || 'FEC_VALOR' || vg_tabulador;

        utl_file.put_line(v_archivo, v_linea);
        for reg in cur_asientos loop
           v_linea := to_char(reg.FECHA,'DD/MM/YYYY')||  vg_csv_separador || reg.COD_OFICINA||  vg_csv_separador || reg.NRO_ASIENTO||  vg_csv_separador || reg.NRO_LINEA||  vg_csv_separador 
                   || reg.COD_RUBRO||  vg_csv_separador || reg.TIP_MOVIMIENTO||  vg_csv_separador || to_char(reg.MTO_MON_RUBRO)||  vg_csv_separador 
                   || to_char(reg.MTO_MON_LOCAL)||  vg_csv_separador || reg.DESCRIPCION||  vg_csv_separador || reg.REFERENCIA||  vg_csv_separador 
                   || reg.PROTEGIDO||  vg_csv_separador || reg.ACTUALIZADO||  vg_csv_separador || to_char(reg.VAL_COTIZACION)||  vg_csv_separador 
                   || reg.DISTRIBUIDO||  vg_csv_separador || reg.REF_MOVIMIENTO||  vg_csv_separador || reg.USU_INSERCION||  vg_csv_separador 
                   || to_char(reg.FEC_INSERCION, 'DD/MM/YYYY HH24:MI:SS')||  vg_csv_separador || reg.USU_MODIFICACION||  vg_csv_separador 
                   || to_char(reg.FEC_MODIFICACION, 'DD/MM/YYYY HH24:MI:SS')||  vg_csv_separador || to_char(reg.FEC_VALOR);
           if nvl(length(v_buffer),0) + vg_lon_fin_linea + nvl(length(v_linea),0) <= vg_max_long then
              v_buffer := v_buffer || vg_fin_linea || v_linea;                      
           else
              if v_buffer is not null then
                 --escribe linea en el archivo
                 utl_file.put_line(v_archivo, v_buffer);
              end if;
              v_buffer := v_linea;
           end if;
           exit when cur_asientos%notfound;
        end loop;
        -- escribe linea en el archivo
        utl_file.put_line(v_archivo, v_buffer);
        -- cierra el archivo
        utl_file.fclose(v_archivo);
     end if;
     -- Genera Archivo Detalle de Movimientos   
     if upper(p_tabla)= upper('cb_cif_movimientos_tmp') then
        v_arc_nombre := vg_mes_archivo || '_' || upper(p_tabla)||vg_arc_detalle || '.' || vg_arc_extension;
        -- abre el archivo
        v_archivo := UTL_FILE.FOPEN(vg_repositorio, v_arc_nombre,'W',32767);
        -- genera la cabecera
        --v_linea := lf_obt_cabecera(p_tabla) || vg_tabulador;
        v_linea := 'FECHA' || vg_csv_separador || 'HORA' || vg_csv_separador || 
                'COD_USUARIO' || vg_csv_separador || 'NRO_SECUENCIA' || vg_csv_separador || 
                'FEC_VALOR' || vg_csv_separador || 'MONTO' || vg_csv_separador || 
                'MTO_EQU_LOCAL' || vg_csv_separador || 'COTIZACION' || vg_csv_separador || 
                'NRO_CUENTA' || vg_csv_separador || 'COD_PERSONA' || vg_csv_separador || 
                'COD_MONEDA' || vg_csv_separador || 'ESTADO' || vg_csv_separador || 
                'CONCEPTO' || vg_csv_separador || 'REVERSADO' || vg_csv_separador || 
                'COD_USU_REVERSION' || vg_csv_separador || 'HOR_REVERSION' || vg_csv_separador || 
                'COD_TRA_PADRE' || vg_csv_separador || 'COD_TRANSACCION' || vg_csv_separador || 
                'COD_MODULO' || vg_csv_separador || 'COD_MODALIDAD' || vg_csv_separador || 
                'NRO_DOCUMENTO' || vg_csv_separador || 'NRO_DOCUMENTO4' || vg_csv_separador || 
                'REFERENCIA' || vg_csv_separador || 'COD_PER_REFERENCIA' || vg_csv_separador || 
                'TIP_MOVIMIENTO' || vg_csv_separador || 'COD_RUBRO' || vg_csv_separador || 
                'TIP_MOV_ASIENTO' || vg_csv_separador || 'MTO_MON_RUBRO' || vg_csv_separador || 
                'MTO_MON_LOCAL' || vg_csv_separador || 'VAL_COTIZACION' || vg_csv_separador || 
                'DESCRIPCION' || vg_csv_separador || 'TIP_REVERSION' || vg_csv_separador || 
                'TIE_FACTURA' || vg_tabulador;

        utl_file.put_line(v_archivo, v_linea);
        for reg in cur_movimientos loop
           v_linea := to_char(reg.FECHA,'DD/MM/YYYY')||  vg_csv_separador || reg.HORA||  vg_csv_separador || reg.COD_USUARIO||  vg_csv_separador || to_char(reg.NRO_SECUENCIA)||  vg_csv_separador 
              || to_char(reg.FEC_VALOR,'DD/MM/YYYY')||  vg_csv_separador || to_char(reg.MONTO)||  vg_csv_separador || to_char(reg.MTO_EQU_LOCAL)||  vg_csv_separador ||  to_char(reg.COTIZACION)||  vg_csv_separador || reg.NRO_CUENTA||  vg_csv_separador 
              || reg.COD_PERSONA||  vg_csv_separador || reg.COD_MONEDA||  vg_csv_separador || reg.ESTADO||  vg_csv_separador || reg.CONCEPTO||  vg_csv_separador || reg.REVERSADO||  vg_csv_separador 
              || reg.COD_USU_REVERSION||  vg_csv_separador || reg.HOR_REVERSION||  vg_csv_separador || reg.COD_TRA_PADRE||  vg_csv_separador || reg.COD_TRANSACCION||  vg_csv_separador 
              || reg.COD_MODULO||  vg_csv_separador || reg.COD_MODALIDAD||  vg_csv_separador || reg.NRO_DOCUMENTO||  vg_csv_separador || reg.NRO_DOCUMENTO4||  vg_csv_separador 
              || reg.REFERENCIA||  vg_csv_separador || reg.COD_PER_REFERENCIA||  vg_csv_separador || reg.TIP_MOVIMIENTO||  vg_csv_separador || reg.COD_RUBRO||  vg_csv_separador 
              || reg.TIP_MOV_ASIENTO||  vg_csv_separador || to_char(reg.MTO_MON_RUBRO)||  vg_csv_separador || to_char(reg.MTO_MON_LOCAL)||  vg_csv_separador || to_char(reg.VAL_COTIZACION)||  vg_csv_separador 
              || reg.DESCRIPCION||  vg_csv_separador || reg.TIP_REVERSION||  vg_csv_separador || reg.TIE_FACTURA;
           if nvl(length(v_buffer),0) + vg_lon_fin_linea + nvl(length(v_linea),0) <= vg_max_long then
              v_buffer := v_buffer || vg_fin_linea || v_linea;                      
           else
              if v_buffer is not null then
                 -- escribe linea en el archivo
                 utl_file.put_line(v_archivo, v_buffer);
              end if;
              v_buffer := v_linea;
           end if;
           exit when cur_movimientos%notfound;
        end loop;
        -- escribe linea en el archivo
        utl_file.put_line(v_archivo, v_buffer);
        -- cierra el archivo
        utl_file.fclose(v_archivo);
     end if;
     -- Genera Archivo Detalle Facturas
     if upper(p_tabla)= upper('cb_cif_facturas_tmp') then
        v_arc_nombre := vg_mes_archivo || '_' || upper(p_tabla)||vg_arc_detalle||'.'|| vg_arc_extension;
        -- abre el archivo
        v_archivo := UTL_FILE.FOPEN(vg_repositorio, v_arc_nombre,'W',32767);
        -- genera la cabecera
        --v_linea := lf_obt_cabecera(p_tabla) || vg_tabulador;
        v_linea := 'FECHA' || vg_csv_separador || 'HORA' || vg_csv_separador || 'COD_USUARIO' || vg_csv_separador || 
        'NRO_SECUENCIA' || vg_csv_separador || 'NRO_FACTURA' || vg_csv_separador || 'NRO_TIMBRADO' || vg_csv_separador || 
        'COD_OFI_ORIGEN' || vg_csv_separador || 'COD_TRA_PADRE' || vg_csv_separador || 'NRO_DOCUMENTO' || vg_csv_separador || 
        'DESCRIPCION' || vg_csv_separador || 'COD_MONEDA' || vg_csv_separador || 'MTO_EXENTO' || vg_csv_separador || 
        'MTO_EXENTO_GS' || vg_csv_separador || 'MTO_GRAVADO_5' || vg_csv_separador || 'MTO_GRA_5_GS' || vg_csv_separador || 
        'MTO_GRAVADO_10' || vg_csv_separador || 'MTO_GRA_10_GS' || vg_csv_separador || 'IMPUESTO_5' || vg_csv_separador || 
        'IMPUESTO_5_GS' || vg_csv_separador || 'IMPUESTO_10' || vg_csv_separador || 'IMPUESTO_10_GS' || vg_csv_separador || 
        'COTIZACION' || vg_csv_separador || 'USU_INSERCION' || vg_csv_separador || 'FEC_INSERCION' || vg_csv_separador || 
        'USU_MODIFICACION' || vg_csv_separador || 'FEC_MODIFICACION' || vg_csv_separador || 'NRO_CUENTA' || vg_csv_separador || 
        'AJU_IMPUESTO_5' || vg_csv_separador || 'AJU_IMPUESTO_10' || vg_csv_separador || 'COD_MOD_PADRE' || vg_csv_separador || 
        'COD_MAD_PADRE' || vg_csv_separador || 'COD_TRANSACCION' || vg_csv_separador || 'COD_MODULO' || vg_csv_separador || 
        'COD_MODALIDAD' || vg_csv_separador || 'TIP_COMPROBANTE' || vg_csv_separador || 'TIP_VENTA' || vg_csv_separador || 
        'COD_PERSONA' || vg_csv_separador || 'MOV_FECHA' || vg_csv_separador || 'MOV_HORA' || vg_csv_separador || 
        'MOV_COD_USUARIO' || vg_csv_separador || 'MOV_NRO_SECUENCIA' || vg_csv_separador || 'MOV_MONTO' || vg_csv_separador || 
        'MOV_MTO_EQU_LOCAL' || vg_csv_separador || 'MOV_NRO_CUENTA' || vg_csv_separador || 'MOV_COD_PERSONA' || vg_csv_separador || 
        'MOV_COD_MONEDA' || vg_csv_separador || 'MOV_COD_TRA_PADRE' || vg_csv_separador || 'MOV_COD_TRANSACCION' || vg_csv_separador || 
        'MOV_COD_MODULO' || vg_csv_separador || 'MOV_COD_MODALIDAD' || vg_csv_separador || 'MOV_NRO_DOCUMENTO' || vg_csv_separador || 
        'MOV_REFERENCIA' || vg_csv_separador || 'MOV_COD_PER_REFERENCIA' || vg_csv_separador || 'MOV_TIP_MOVIMIENTO' || vg_csv_separador || 
        'MOV_REVERSADO' || vg_csv_separador || 'COD_RUBRO' || vg_csv_separador || 'MATCH_MONTO' || vg_csv_separador || 
        'MATCH_MTO_MON_DIFF' || vg_csv_separador || 'MATCH_MTO_GS_DIFF' || vg_csv_separador || 'MATCH_TRA_PAD' || vg_csv_separador || 
        'MATCH_NRO_CUENTA' || vg_csv_separador || 'MATCH_NRO_DOCUMENTO' || vg_csv_separador || 'MATCH_CTA_REFERENCIA' || vg_csv_separador || 
        'MATCH_PER_REFERENCIA' || vg_csv_separador || 'MATCH_COD_PERSONA' || vg_csv_separador || 'MATCH_NRO_SECUENCIA' || vg_csv_separador || 
        'MATCH_SEC_DIF' || vg_csv_separador || 'DUPLICADO' || vg_csv_separador || 'UTILIZAR' || vg_csv_separador || 'COD_MATCH' || vg_csv_separador || 
        'TIP_CONCILIACION' || vg_tabulador;
        utl_file.put_line(v_archivo, v_linea);
        for reg in cur_facturas loop
           v_linea := to_char(reg.FECHA,'DD/MM/YYYY')||  vg_csv_separador || reg.HORA||  vg_csv_separador || reg.COD_USUARIO||  vg_csv_separador 
                   || reg.NRO_SECUENCIA||  vg_csv_separador || reg.NRO_FACTURA||  vg_csv_separador || reg.NRO_TIMBRADO||  vg_csv_separador 
                   || reg.COD_OFI_ORIGEN||  vg_csv_separador || reg.COD_TRA_PADRE||  vg_csv_separador || reg.NRO_DOCUMENTO||  vg_csv_separador 
                   || reg.DESCRIPCION||  vg_csv_separador || reg.COD_MONEDA||  vg_csv_separador || to_char(reg.MTO_EXENTO)||  vg_csv_separador 
                   || to_char(reg.MTO_EXENTO_GS)||  vg_csv_separador || to_char(reg.MTO_GRAVADO_5)||  vg_csv_separador 
                   || to_char(reg.MTO_GRA_5_GS)||  vg_csv_separador || to_char(reg.MTO_GRAVADO_10)||  vg_csv_separador 
                   || to_char(reg.MTO_GRA_10_GS)||  vg_csv_separador || to_char(reg.IMPUESTO_5)||  vg_csv_separador 
                   || to_char(reg.IMPUESTO_5_GS)||  vg_csv_separador || to_char(reg.IMPUESTO_10)||  vg_csv_separador 
                   || to_char(reg.IMPUESTO_10_GS)||  vg_csv_separador || to_char(reg.COTIZACION)||  vg_csv_separador 
                   || reg.USU_INSERCION||  vg_csv_separador || to_char(reg.FEC_INSERCION, 'DD/MM/YYYY HH24:MI:SS')||  vg_csv_separador 
                   || reg.USU_MODIFICACION||  vg_csv_separador || to_char(reg.FEC_MODIFICACION, 'DD/MM/YYYY HH24:MI:SS')||  vg_csv_separador 
                   || reg.NRO_CUENTA||  vg_csv_separador || to_char(reg.AJU_IMPUESTO_5)||  vg_csv_separador || to_char(reg.AJU_IMPUESTO_10)||  vg_csv_separador 
                   || reg.COD_MOD_PADRE||  vg_csv_separador || reg.COD_MAD_PADRE||  vg_csv_separador || reg.COD_TRANSACCION||  vg_csv_separador 
                   || reg.COD_MODULO||  vg_csv_separador || reg.COD_MODALIDAD||  vg_csv_separador || reg.TIP_COMPROBANTE||  vg_csv_separador 
                   || reg.TIP_VENTA||  vg_csv_separador || reg.COD_PERSONA||  vg_csv_separador || to_char(reg.MOV_FECHA, 'DD/MM/YYYY')||  vg_csv_separador  
                   || reg.MOV_HORA||  vg_csv_separador || reg.MOV_COD_USUARIO||  vg_csv_separador || reg.MOV_NRO_SECUENCIA||  vg_csv_separador 
                   || to_char(reg.MOV_MONTO)||  vg_csv_separador || to_char(reg.MOV_MTO_EQU_LOCAL)||  vg_csv_separador || reg.MOV_NRO_CUENTA||  vg_csv_separador 
                   || reg.MOV_COD_PERSONA||  vg_csv_separador || reg.MOV_COD_MONEDA||  vg_csv_separador || reg.MOV_COD_TRA_PADRE||  vg_csv_separador 
                   || reg.MOV_COD_TRANSACCION||  vg_csv_separador || reg.MOV_COD_MODULO||  vg_csv_separador || reg.MOV_COD_MODALIDAD||  vg_csv_separador 
                   || reg.MOV_NRO_DOCUMENTO||  vg_csv_separador || reg.MOV_REFERENCIA||  vg_csv_separador || reg.MOV_COD_PER_REFERENCIA||  vg_csv_separador 
                   || reg.MOV_TIP_MOVIMIENTO||  vg_csv_separador || reg.MOV_REVERSADO||  vg_csv_separador || reg.COD_RUBRO||  vg_csv_separador 
                   || reg.MATCH_MONTO||  vg_csv_separador || to_char(reg.MATCH_MTO_MON_DIFF)||  vg_csv_separador || to_char(reg.MATCH_MTO_GS_DIFF)||  vg_csv_separador 
                   || reg.MATCH_TRA_PAD||  vg_csv_separador || reg.MATCH_NRO_CUENTA||  vg_csv_separador || reg.MATCH_NRO_DOCUMENTO||  vg_csv_separador 
                   || reg.MATCH_CTA_REFERENCIA||  vg_csv_separador || reg.MATCH_PER_REFERENCIA||  vg_csv_separador || reg.MATCH_COD_PERSONA||  vg_csv_separador 
                   || reg.MATCH_NRO_SECUENCIA||  vg_csv_separador || reg.MATCH_SEC_DIF||  vg_csv_separador || reg.DUPLICADO||  vg_csv_separador 
                   || reg.UTILIZAR||  vg_csv_separador || reg.COD_MATCH||  vg_csv_separador || reg.tip_conciliacion;
           if nvl(length(v_buffer),0) + vg_lon_fin_linea + nvl(length(v_linea),0) <= vg_max_long then
              v_buffer := v_buffer || vg_fin_linea || v_linea;                      
           else
              if v_buffer is not null then
                 -- escribe linea en el archivo
                 utl_file.put_line(v_archivo, v_buffer);
              end if;
              v_buffer := v_linea;
           end if;
           exit when cur_facturas%notfound;
        end loop;
        -- escribe linea en el archivo
        utl_file.put_line(v_archivo, v_buffer);
        -- cierra el archivo
        utl_file.fclose(v_archivo);
     end if;
     -- Genera Archivo Detalle Diario Conciliacion
     if upper(p_tabla)= upper('cb_cif_inf_detalle') then
        v_arc_nombre := vg_mes_archivo || '_' || upper('cb_cif_det_diario')||vg_arc_detalle||'.'|| vg_arc_extension;
        -- abre el archivo
        v_archivo := UTL_FILE.FOPEN(vg_repositorio, v_arc_nombre,'W',32767);
        -- genera la cabecera
        -- v_linea := lf_obt_cabecera(p_tabla) || vg_csv_separador || 'OBSERVACION' || vg_tabulador;
        v_linea := 'FECHA' || vg_csv_separador || 'COD_RUBRO' || vg_csv_separador || 'DESCRIPCION' || vg_csv_separador || 
        'MTO_ASIENTOS' || vg_csv_separador || 'MTO_MOVIMIENTOS' || vg_csv_separador || 'MTO_MOV_REV_DO' || vg_csv_separador || 
        'MTO_MOV_REV_DR' || vg_csv_separador || 'MTO_MOV_REV_MO' || vg_csv_separador || 'MTO_MOV_REV_MR' || vg_csv_separador || 
        'MTO_MOV_REV_HIS' || vg_csv_separador || 'MTO_MOV_REV_VER' || vg_csv_separador || 'MTO_ASI_SIN_MOV' || vg_csv_separador || 
        'MTO_FACTURA' || vg_csv_separador || 'MTO_NCREDITO' || vg_csv_separador || 'MTO_FAC_ELI_REVERSIONES' || vg_csv_separador || 
        'MTO_FAC_ELI_DIFERENCIAS' || vg_csv_separador || 'DIF_MOV_ASIENTOS' || vg_csv_separador || 'DIF_FAC_ASI_BASICA' || vg_csv_separador || 
        'DIF_FAC_ASI_AUTOMATICA' || vg_csv_separador || 'DIF_POR_AUTOMATICA' || vg_csv_separador || 'MTO_FAC_FAL_ASI_DIRECTOS' || vg_csv_separador || 
        'MTO_FAC_FAL_AUTOMATICO' || vg_csv_separador || 'OBSERVACION' || vg_tabulador;
        utl_file.put_line(v_archivo, v_linea);
        for reg in cur_det_diario loop
           v_linea := to_char(reg.FECHA,'DD/MM/YYYY')||  vg_csv_separador || reg.COD_RUBRO||  vg_csv_separador || reg.DESCRIPCION||  vg_csv_separador 
                   || to_char(reg.MTO_ASIENTOS)||  vg_csv_separador || to_char(reg.MTO_MOVIMIENTOS)||  vg_csv_separador || to_char(reg.MTO_MOV_REV_DO)||  vg_csv_separador 
                   || to_char( reg.MTO_MOV_REV_DR)||  vg_csv_separador || to_char(reg.MTO_MOV_REV_MO)||  vg_csv_separador || to_char(reg.MTO_MOV_REV_MR)||  vg_csv_separador 
                   || to_char(reg.MTO_MOV_REV_HIS)||  vg_csv_separador || to_char(reg.MTO_MOV_REV_VER)||  vg_csv_separador || to_char(reg.MTO_ASI_SIN_MOV)||  vg_csv_separador 
                   || to_char(reg.MTO_FACTURA)||  vg_csv_separador || to_char(reg.MTO_NCREDITO)||  vg_csv_separador || to_char(reg.MTO_FAC_ELI_REVERSIONES)||  vg_csv_separador 
                   || to_char(reg.MTO_FAC_ELI_DIFERENCIAS)||  vg_csv_separador || to_char(reg.DIF_MOV_ASIENTOS)||  vg_csv_separador 
                   || to_char(reg.DIF_FAC_ASI_BASICA)||  vg_csv_separador || to_char(reg.DIF_FAC_ASI_AUTOMATICA)||  vg_csv_separador 
                   || to_char(reg.DIF_POR_AUTOMATICA)||  vg_csv_separador || to_char(reg.MTO_FAC_FAL_ASI_DIRECTOS)||  vg_csv_separador 
                   || to_char(reg.MTO_FAC_FAL_AUTOMATICO) ||  vg_csv_separador || reg.observacion;
           if nvl(length(v_buffer),0) + vg_lon_fin_linea + nvl(length(v_linea),0) <= vg_max_long then
              v_buffer := v_buffer || vg_fin_linea || v_linea;                      
           else
              if v_buffer is not null then
                 -- escribe linea en el archivo
                 utl_file.put_line(v_archivo, v_buffer);
              end if;
              v_buffer := v_linea;
           end if;
           exit when cur_det_diario%notfound;
        end loop;
        -- escribe linea en el archivo
        utl_file.put_line(v_archivo, v_buffer);
        -- cierra el archivo
        utl_file.fclose(v_archivo);
     end if;
     -- Si existe el archivo: envia por FTP el archivo generado
     IF nvl(length(v_arc_nombre),0) > 0 THEN
       lp_env_arc_ftp(v_arc_nombre, 
           vg_car_contabilidad, 
           vg_ip, 
           vg_port, 
           vg_user, 
           vg_pass);
      END IF;
  exception
    when utl_file.invalid_operation then
      utl_file.fclose(v_archivo);
      raise_application_error(-20061,'operacion invalida '||sqlerrm);
    when utl_file.invalid_filehandle then
      utl_file.fclose(v_archivo);
      raise_application_error(-20062,'manejador invalido '||sqlerrm);
    when utl_file.write_error then
      utl_file.fclose(v_archivo);
      raise_application_error(-20063,'error de escritura '||sqlerrm);
    when utl_file.invalid_mode then
      utl_file.fclose(v_archivo);
      raise_application_error(-20064,'modo invalido '||sqlerrm);
    when utl_file.internal_error then
      utl_file.fclose(v_archivo);
      raise_application_error(-20065,'internal error '||sqlerrm);
   WHEN OTHERS THEN
     utl_file.fclose(v_archivo);
      raise_application_error(-20099,'Error Inesperado '||sqlerrm);
  end;
  -- Envia Email Aviso de Generacion de Archivos
  procedure lp_env_aviso is
     v_conexion   utl_smtp.connection;
     v_dir_para           varchar2(100);
     v_dir_de             varchar2(100);
     v_asunto             varchar2(100);
     v_contenido          varchar2(100);
     v_det_error          varchar2(500);
  BEGIN  
     vg_proceso  := 'lp_env_email';
     v_det_error := '';
     v_dir_para  := vg_email_para;
     v_dir_de    := vg_email_de;
     v_asunto    := 'Conciliacion de Ingresos - Facturaciones al ' || vg_fec_final || ' ' ||vg_arc_detalle;
     v_contenido := 'Los archivos con los datos del reporte estan disponibles en:' || chr(10) ||
                    '\\' || vg_ip || '\' || vg_car_contabilidad;     
     v_conexion := it_mail.begin_mail(v_dir_de, v_dir_para, v_asunto, IT_MAIL.MULTIPART_MIME_TYPE);
     it_mail.attach_text(v_conexion, v_contenido, 'text/plain');
     it_mail.end_mail(v_conexion);  
  EXCEPTION
   WHEN utl_smtp.transient_error or utl_smtp.permanent_error THEN
      v_det_error := substr(sqlerrm,1,400);
      begin
        utl_smtp.quit(v_conexion);
      exception
        when others then
          v_det_error := v_det_error || substr(sqlerrm,1,400);
      end;
      IF nvl(LENGTH(v_det_error),0) > 0 THEN 
         raise_application_error(-20000,vg_proceso ||' '|| v_det_error);
      END IF;
   WHEN OTHERS THEN
      v_det_error := substr(sqlerrm,1,400);
      begin
        utl_smtp.quit(v_conexion);
      exception
        when others then
          v_det_error := v_det_error || substr(sqlerrm,1,400);
      end;
      IF nvl(LENGTH(v_det_error),0) > 0 THEN
         raise_application_error(-20000,vg_proceso ||' '|| v_det_error);
      END IF;
  END;
  
  -- Genera Conciliacion
  Procedure pr_gen_conciliacion( p_fec_proceso date default null)  is  
  begin
     -- Inicializa variables
     pr_ini_variables(p_fec_proceso); 
     if lf_gen_control = 'SI' then       
       -- Verifica el horario de procesamiento
       pr_ver_horarios;
       -- Trunca tablas temporales
       pr_tru_temporales;
       -- Generación de datos para Conciliacion Basica
       pr_gen_temporales;
       pr_dep_facturas;
       pr_act_movimientos;
       -- Genera Detalle Informe Conciliacion
       pr_gen_det_conciliacion;
       -- Actualiza fecha en parametro dinamico de ctrl 
       lp_act_control;
     else
       raise_application_error(-20000,' Datos ya procesados a fecha '|| to_char(vg_fec_final,'dd/mm/yyyy') || 
          '. Para reproceso modificar fecha del parametro CIF_INF_GEN_CTRL.'||
          ' Para Generar Archivos a esta fecha, Precione SI.');
     end if;
  end;
  
  -- Genera Conciliacion a Fecha Especifica
  -- La fecha se establece en el parametro dinamico CIF_FEC_CONCILIACION
  Procedure pr_gen_con_fecha is
     v_fec_especifica date;
  begin
     vg_proceso := 'pr_gen_con_fecha';
     -- Obtener parametro dinamico con fecha a generar
     v_fec_especifica := to_date(fug_obt_pardinamico('CIF_FEC_CONCILIACION'),'dd/mm/yyyy');
     -- Genera Conciliacion
     pr_gen_conciliacion(v_fec_especifica);
  end;
  
  -- Genera Archivos de Conciliacion
  Procedure pr_gen_archivos( p_fec_proceso date default null) is
  begin
     vg_proceso := 'pr_gen_archivos';
     -- inicializa el paquete
     pr_ini_variables(p_fec_proceso);
     -- verifica existencia de datos a la fecha
     pr_ver_datos;
     -- genera archivos     
     pr_gen_arc_tabla('CB_CIF_ASIENTOS_TMP');
     pr_gen_arc_tabla('CB_CIF_MOVIMIENTOS_TMP');
     pr_gen_arc_tabla('CB_CIF_FACTURAS_TMP');
     pr_gen_arc_tabla('CB_CIF_INF_DETALLE');     
     -- envia email de eviso
     lp_act_control;
  end;
  
  -- Genera Archivos de Conciliacion a Fecha Especifica
  -- La fecha se establece en el parametro dinamico CIF_FEC_CONCILIACION
  Procedure pr_gen_arc_fecha is
     v_fec_especifica date;
  begin
     vg_proceso := 'pr_gen_arc_fecha';
     vg_arc_detalle := '_req_'||to_char(sysdate,'yyyymmddHH24mi');
     -- Obtener parametro dinamico con fecha a generar
     v_fec_especifica := to_date(fug_obt_pardinamico('CIF_FEC_CONCILIACION'),'dd/mm/yyyy');
     -- Genera Archivos de Conciliacion
     pr_gen_archivos(v_fec_especifica);     
  end;
  
end PAB_CIF;
/

