CREATE OR REPLACE PROCEDURE IT.PRB_INS_DAT_ESP_MOVIM is
  --DESOPIMI-66 PRB_INF_DIA_CIDESA informe diario CIDESA--
  --Realiza copia y mantenimiento diario de datos de movimientos--
  --Instalar proceso al final de cierre de fin de dia ITGF o post cierre--
  vg_fec_actual             date;
  vg_fec_contable           date;
  vg_lugar                  varchar2(200);
  vg_hor_inicio             varchar2(8);
  vg_hor_fin                varchar2(8);
  vg_cod_programa           ge_log_procesos.cod_programa%type;

  PROCEDURE LP_CAR_VAR_PROCESO IS
  BEGIN
    vg_lugar   := 'LP_CAR_VAR_PROCESO';
    vg_hor_inicio := to_char(sysdate,'hh24:mi:ss');
    vg_fec_actual := pag_cal.FU_OBT_FEC_ACTUAL(1);
    vg_fec_contable := pag_cal.FU_OBT_FEC_ACTUAL(2);
    vg_hor_fin := to_char(sysdate,'hh24:mi:ss');
    prg_act_log_procesos(vg_cod_programa,vg_lugar, vg_fec_actual, vg_hor_inicio, vg_hor_fin);
  exception
    when others then
         raise_application_error(-20000,'Error en LP_CAR_VAR_PROCESO-'||sqlerrm);
  END LP_CAR_VAR_PROCESO;

  PROCEDURE LP_ELI_TAB_REG_DIARIO IS
  begin
    vg_lugar   := 'LP_ELI_TAB_UTILIZADAS';
    vg_hor_inicio := TO_CHAR(SYSDATE,'HH24:MI:SS');
    delete from GE_CON_ESP_CIDESA x
     where x.fecha = vg_fec_actual
       and x.ref_origen in ('CTA_BAN_TMP', 'RUBROS_TMP', 'ASIENTOS','SAL_OFICINAS',
                            'ASIENTOS_DET', 'MOV_DIARIOS', 'SNP_TRANSFERENCIAS');
    vg_hor_fin := to_char(sysdate,'hh24:mi:ss');
    prg_act_log_procesos(vg_cod_programa,vg_lugar, vg_fec_actual, vg_hor_inicio, vg_hor_fin);
  exception
    when others then
         raise_application_error(-20000,'Error en LP_ELI_TAB_REG_DIARIO-'||sqlerrm);
  END LP_ELI_TAB_REG_DIARIO;

  PROCEDURE LP_INS_ENT_FINANCIERAS IS
  begin
    vg_lugar   := 'LP_INS_ENT_FINANCIERAS';
    vg_hor_inicio := TO_CHAR(SYSDATE,'HH24:MI:SS');
    insert into GE_CON_ESP_CIDESA
    (nro_cuenta, cod_modulo, cod_modalidad, cod_moneda, cod_banco,
     cod_ente, cod_rubro, cod_bco_central, cod_rub_sobregiro, ref_origen, fecha)
    select a.nro_cuenta, cod_modulo, cod_modalidad, cod_moneda,
           cod_banco, a.cod_ente, cod_rubro, c.val_parametro cod_bco_central,
           d.val_parametro cod_rub_sobregiro, 'CTA_BAN_TMP', vg_fec_actual
      from cc_cta_bancarias a, ge_entes b, ge_par_entes c, ge_cta_dat_adicionales d
     WHERE a.cod_ente = b.cod_ente
       and b.tipo = 'FI'
       and c.cod_ente(+) = b.cod_ente
       and c.parametro(+) = 'COD_ENT_CIDESA'
       and d.nro_cuenta(+) = a.nro_cuenta
       and d.parametro(+)  = 'COD_RUB_SOB_CTA_BAN';
    vg_hor_fin := to_char(sysdate,'hh24:mi:ss');
    prg_act_log_procesos(vg_cod_programa,vg_lugar, vg_fec_actual, vg_hor_inicio, vg_hor_fin);
  exception
    when others then
         raise_application_error(-20000,'Error en LP_INS_ENT_FINANCIERAS-'||sqlerrm);
  end LP_INS_ENT_FINANCIERAS;

  PROCEDURE LP_INS_ENT_BANCARIAS IS
  begin
    vg_lugar   := 'LP_INS_ENT_BANCARIAS';
    vg_hor_inicio := TO_CHAR(SYSDATE,'HH24:MI:SS');
    insert into GE_CON_ESP_CIDESA
    (nro_cuenta, cod_modulo, cod_modalidad, cod_moneda, cod_banco,
     cod_ente, cod_rubro, cod_bco_central, cod_rub_sobregiro, REF_ORIGEN, fecha)
    select a.nro_cuenta, cod_modulo, cod_modalidad,
           cod_moneda, a.cod_banco, a.cod_ente,
           cod_rubro, b.cod_bco_central, d.val_parametro cod_rub_sobregiro, 'CTA_BAN_TMP', vg_fec_actual
      from cc_cta_bancarias a, ge_bancos b, ge_cta_dat_adicionales d
     where a.cod_banco = b.cod_banco
       and b.estado = 'A'
       and b.ubicacion = 'L'
       and d.nro_cuenta(+) = a.nro_cuenta
       and d.parametro(+)  = 'COD_RUB_SOB_CTA_BAN';
    vg_hor_fin := to_char(sysdate,'hh24:mi:ss');
    prg_act_log_procesos(vg_cod_programa,vg_lugar, vg_fec_actual, vg_hor_inicio, vg_hor_fin);
  exception
    when others then
         raise_application_error(-20000,'Error en LP_INS_ENT_BANCARIAS-'||sqlerrm);
  end LP_INS_ENT_BANCARIAS;

  PROCEDURE LP_INS_TAB_RUBROS_TMP IS
  begin
    vg_lugar   := 'LP_INS_RUB_ESPECIALES';
    vg_hor_inicio := TO_CHAR(SYSDATE,'HH24:MI:SS');
    insert into GE_CON_ESP_CIDESA
    (cod_rubro, cod_bco_central, tipo, REF_ORIGEN, fecha)
    select distinct cod_rubro, cod_bco_central, 'N', 'RUBROS_TMP', vg_fec_actual
      from GE_CON_ESP_CIDESA x
     where x.fecha = vg_fec_actual
       and x.ref_origen = 'CTA_BAN_TMP'
       and x.cod_rubro is not null
    union
    select distinct cod_rub_sobregiro, cod_bco_central, 'S', 'RUBROS_TMP', vg_fec_actual
      from GE_CON_ESP_CIDESA x
     where x.fecha = vg_fec_actual
       and x.ref_origen = 'CTA_BAN_TMP'
       and cod_rub_sobregiro is not null;
    vg_hor_fin := to_char(sysdate,'hh24:mi:ss');
    prg_act_log_procesos(vg_cod_programa,vg_lugar, vg_fec_actual, vg_hor_inicio, vg_hor_fin);
  exception
    when others then
         raise_application_error(-20000,'Error en LP_INS_TAB_RUBROS_TMP-'||sqlerrm);
  end LP_INS_TAB_RUBROS_TMP;

  PROCEDURE LP_INS_TAB_ASIENTOS IS
  BEGIN
    vg_lugar   := 'LP_INS_TAB_ASIENTOS';
    vg_hor_inicio := TO_CHAR(SYSDATE,'HH24:MI:SS');
    insert into GE_CON_ESP_CIDESA
    (FECHA,COD_OFICINA,NRO_ASIENTO,COD_USUARIO,COD_MODULO,COD_MODALIDAD,
    TOT_CONTROL,ACTUALIZADO,REVERSADO,OFI_INTEGRADA,CONFIRMADO,COD_OFI_ORIGEN,
    USU_INSERCION,FEC_INSERCION,USU_MODIFICACION,FEC_MODIFICACION,FEC_VALOR, REF_ORIGEN)
    select distinct a.FECHA,a.COD_OFICINA,a.NRO_ASIENTO,a.COD_USUARIO,a.COD_MODULO,a.COD_MODALIDAD,
    a.TOT_CONTROL,a.ACTUALIZADO,a.REVERSADO,a.OFI_INTEGRADA,a.CONFIRMADO,a.COD_OFI_ORIGEN,
    a.USU_INSERCION,a.FEC_INSERCION,a.USU_MODIFICACION,a.FEC_MODIFICACION,a.FEC_VALOR, 'ASIENTOS'
    from cb_asi_automaticos_tmp a, cb_asi_automaticos_det_tmp b
    where a.fecha = b.fecha
      and a.nro_asiento = b.nro_asiento
      and a.cod_oficina = b.cod_oficina
      and b.cod_rubro IN ('111201090400699','111201090450099','211101020400699','211101020414499')
      and a.fecha = vg_fec_actual;
    vg_hor_fin := to_char(sysdate,'hh24:mi:ss');
    prg_act_log_procesos(vg_cod_programa,vg_lugar, vg_fec_actual, vg_hor_inicio, vg_hor_fin);
  exception
    when others then
         raise_application_error(-20000,'Error en LP_INS_TAB_ASIENTOS-'||sqlerrm);
  END LP_INS_TAB_ASIENTOS;

  PROCEDURE LP_INS_TAB_ASIENTOS_DET IS
  BEGIN
    -- desde CB_ASI_AUTOMATICOS_DET_TMP
    vg_lugar   := 'LP_INS_TAB_ASIENTOS 1';
    vg_hor_inicio := TO_CHAR(SYSDATE,'HH24:MI:SS');
    insert into GE_CON_ESP_CIDESA
    (FECHA , COD_OFICINA, NRO_ASIENTO, NRO_LINEA, COD_RUBRO, TIP_MOVIMIENTO,
     MTO_MON_RUBRO, MTO_MON_LOCAL, DESCRIPCION, REFERENCIA,
     PROTEGIDO, ACTUALIZADO, VAL_COTIZACION, DISTRIBUIDO,
     REF_MOVIMIENTO, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION,
     FEC_MODIFICACION, FEC_VALOR, REF_ORIGEN)
    select c.FECHA,c.COD_OFICINA,c.NRO_ASIENTO,c.NRO_LINEA,c.COD_RUBRO,c.TIP_MOVIMIENTO,
    c.MTO_MON_RUBRO,c.MTO_MON_LOCAL,c.DESCRIPCION,c.REFERENCIA,c.PROTEGIDO,c.ACTUALIZADO,c.VAL_COTIZACION,
    c.DISTRIBUIDO,c.REF_MOVIMIENTO,c.USU_INSERCION,c.FEC_INSERCION,c.USU_MODIFICACION,c.FEC_MODIFICACION,
    c.FEC_VALOR, 'ASIENTOS_DET'
    from GE_CON_ESP_CIDESA cc, cb_asi_automaticos_det_tmp c
    where cc.fecha = vg_fec_actual
      and cc.ref_origen = 'RUBROS_TMP'
      and cc.cod_rubro = c.cod_rubro
      and c.fecha = cc.fecha
      and cc.tipo = 'N'
      and c.cod_rubro IN ('111201051001199','111201051801105','111201051801117');
    vg_hor_fin := to_char(sysdate,'hh24:mi:ss');
    prg_act_log_procesos(vg_cod_programa,vg_lugar, vg_fec_actual, vg_hor_inicio, vg_hor_fin);
    -- desde CB_ASI_AUTOMATICOS_DET_TMP
    vg_lugar   := 'LP_INS_TAB_ASIENTOS 2';
    vg_hor_inicio := TO_CHAR(SYSDATE,'HH24:MI:SS');
    insert into GE_CON_ESP_CIDESA
    (FECHA , COD_OFICINA, NRO_ASIENTO, NRO_LINEA, COD_RUBRO, TIP_MOVIMIENTO,
     MTO_MON_RUBRO, MTO_MON_LOCAL, DESCRIPCION, REFERENCIA,
     PROTEGIDO, ACTUALIZADO, VAL_COTIZACION, DISTRIBUIDO,
     REF_MOVIMIENTO, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION,
     FEC_MODIFICACION, FEC_VALOR, REF_ORIGEN)
    select c.FECHA,c.COD_OFICINA,c.NRO_ASIENTO,c.NRO_LINEA,c.COD_RUBRO,c.TIP_MOVIMIENTO,
    c.MTO_MON_RUBRO,c.MTO_MON_LOCAL,c.DESCRIPCION,c.REFERENCIA,c.PROTEGIDO,c.ACTUALIZADO,c.VAL_COTIZACION,
    c.DISTRIBUIDO,c.REF_MOVIMIENTO,c.USU_INSERCION,c.FEC_INSERCION,c.USU_MODIFICACION,c.FEC_MODIFICACION,
    c.FEC_VALOR, 'ASIENTOS_DET'
    from GE_CON_ESP_CIDESA cc, CB_ASIENTOS_DET c
    where c.fecha = vg_fec_actual
    and cc.ref_origen = 'RUBROS_TMP'
    and cc.cod_rubro=c.cod_rubro
    and cc.cod_bco_central not in(1007,1001)
    and cc.tipo IN ('N','S')
    and cc.fecha = c.fecha;
    vg_hor_fin := to_char(sysdate,'hh24:mi:ss');
    prg_act_log_procesos(vg_cod_programa,vg_lugar, vg_fec_actual, vg_hor_inicio, vg_hor_fin);  
  exception
    when others then
         raise_application_error(-20000,'Error en LP_INS_TAB_ASIENTOS_DET-'||sqlerrm);
  END LP_INS_TAB_ASIENTOS_DET;

  PROCEDURE LP_INS_TAB_MOVIMIENTOS IS
  BEGIN
    vg_lugar   := 'LP_INS_MOV_DIARIOS';
    vg_hor_inicio := TO_CHAR(SYSDATE,'HH24:MI:SS');
    insert into GE_CON_ESP_CIDESA
    (fecha, hora, cod_usuario, nro_secuencia,
    fec_valor, monto, nro_cuenta, cod_moneda,
    cod_oficina, cod_error, cod_retencion, fec_fin_retencion,
    est_cuenta, estado, cod_causa, cod_banco,
    cod_ofi_origen, concepto, cod_tasa, val_tasa,
    cod_rubro, cod_ref_cambio, reversado, cod_usu_reversion,
    hor_reversion, emi_aviso, cod_tra_padre, cod_mod_padre,
    cod_mad_padre, cod_transaccion, cod_modulo, cod_modalidad,
    mto_equ_local, nro_caja, cotizacion, cod_bco_central,
    nro_documento, nro_documento2, nro_documento3, nro_documento4,
    protegido, cod_autorizacion, cod_usu_autorizador, usu_insercion,
    fec_insercion, usu_modificacion, fec_modificacion, tip_mov_rubro,
    cod_tip_ope_cambio, referencia, cod_persona, cod_sit_contable,
    nro_conciliacion, ref_origen)
    select distinct m.FECHA,m.HORA,m.COD_USUARIO,m.NRO_SECUENCIA,m.FEC_VALOR,m.MONTO,m.NRO_CUENTA,m.COD_MONEDA,
    m.COD_OFICINA,m.COD_ERROR,m.COD_RETENCION,m.FEC_FIN_RETENCION,m.EST_CUENTA,m.ESTADO,m.COD_CAUSA,m.COD_BANCO,
    m.COD_OFI_ORIGEN,m.CONCEPTO,m.COD_TASA,m.VAL_TASA,m.COD_RUBRO,m.COD_REF_CAMBIO,m.REVERSADO,m.COD_USU_REVERSION,
    m.HOR_REVERSION,m.EMI_AVISO,m.COD_TRA_PADRE,m.COD_MOD_PADRE,m.COD_MAD_PADRE,m.COD_TRANSACCION,m.COD_MODULO,
    m.COD_MODALIDAD,m.MTO_EQU_LOCAL,m.NRO_CAJA,m.COTIZACION,m.COD_BCO_CENTRAL,m.NRO_DOCUMENTO,m.NRO_DOCUMENTO2,
    m.NRO_DOCUMENTO3,m.NRO_DOCUMENTO4,m.PROTEGIDO,m.COD_AUTORIZACION,m.COD_USU_AUTORIZADOR,m.USU_INSERCION,
    m.FEC_INSERCION,m.USU_MODIFICACION,m.FEC_MODIFICACION,m.TIP_MOV_RUBRO,m.COD_TIP_OPE_CAMBIO,m.REFERENCIA,
    m.COD_PERSONA,m.COD_SIT_CONTABLE,m.NRO_CONCILIACION, 'MOV_DIARIOS'
    from GE_MOVIMIENTOS m, GE_CON_ESP_CIDESA c
    where c.fecha = vg_fec_actual
      and c.ref_origen = 'ASIENTOS_DET'
      and c.fecha = m.FECHA
      and c.ref_movimiento = m.NRO_DOCUMENTO4
      and ((m.cod_moneda <> 'GS' and nvl(c.mto_mon_rubro,0) <> 0) or
           (m.cod_moneda = 'GS' and nvl(c.mto_mon_rubro,0) = 0))
      and m.fecha = vg_fec_actual;
    vg_hor_fin := to_char(sysdate,'hh24:mi:ss');
    prg_act_log_procesos(vg_cod_programa,vg_lugar, vg_fec_actual, vg_hor_inicio, vg_hor_fin);
  exception
    when others then
         raise_application_error(-20000,'Error en LP_INS_TAB_MOVIMIENTOS-'||sqlerrm);
  END LP_INS_TAB_MOVIMIENTOS;

  PROCEDURE LP_INS_TAB_SNP_TRANSFERENCIAS IS
  BEGIN
    vg_lugar   := 'LP_INS_TAB_SNP_TRANSFERENCIAS';
    vg_hor_inicio := TO_CHAR(SYSDATE,'HH24:MI:SS');
    insert into GE_CON_ESP_CIDESA
    (nro_referencia, nro_lote, nro_sec_lote, cod_modulo, cod_modalidad,
      cod_oficina, cod_msj_swift, cod_tip_operacion, cod_sub_tip_operacion,
      msj_swift, fec_valor, fec_ingreso, fec_recepcion, fecha, hora, cod_usuario,
      cod_moneda, monto, cod_per_solicitante, nom_solicitante, dir_solicitante,
      cod_tip_doc_solicitante, nro_doc_solicitante, nro_cta_solicitante, cod_swi_pte_solicitante,
      cod_swi_suc_solicitante, nro_cta_pte_solicitante, cod_per_beneficiario, nom_beneficiario,
      dir_beneficiario, cod_tip_doc_beneficiario, nro_doc_beneficiario, nro_cta_beneficiario,
      nro_cta_pte_beneficiario, cod_swi_pte_beneficiario, cod_swi_suc_beneficiario,
      plazo, concepto, observacion, nro_ref_externa, tip_cargo, ind_valor, situacion, estado,
      tip_rechazo, mto_cargo, prioridad, nro_operacion, tip_mensaje, error, cod_usu_transaccion,
      imp_inf_hacienda, origen, plataforma, indemnizado, ref_oid, cod_per_intermediario, 
      nom_intermediario, cod_swi_pte_intermediario, dir_intermediario, nro_cta_pte_intermediario,
      cod_bco_corresponsal, nom_corresponsal, cod_swi_pte_corresponsal, nro_cta_pte_corresponsal, 
      ben_dir_correo, cod_tra_padre, ref_origen)
    select distinct d.nro_referencia, d.nro_lote, d.nro_sec_lote, d.cod_modulo, d.cod_modalidad,
      d.cod_oficina, d.cod_msj_swift, d.cod_tip_operacion, d.cod_sub_tip_operacion,
      d.msj_swift, d.fec_valor, d.fec_ingreso, d.fec_recepcion, vg_fec_actual, d.hora, d.cod_usuario, --se utiliza vg_fec_actual en fecha 
      d.cod_moneda, d.monto, d.cod_per_solicitante, d.nom_solicitante, d.dir_solicitante,
      d.cod_tip_doc_solicitante, d.nro_doc_solicitante, d.nro_cta_solicitante, d.cod_swi_pte_solicitante,
      d.cod_swi_suc_solicitante, d.nro_cta_pte_solicitante, d.cod_per_beneficiario, d.nom_beneficiario,
      d.dir_beneficiario, d.cod_tip_doc_beneficiario, d.nro_doc_beneficiario, d.nro_cta_beneficiario,
      d.nro_cta_pte_beneficiario, d.cod_swi_pte_beneficiario, d.cod_swi_suc_beneficiario,
      d.plazo, d.concepto, d.observacion, d.nro_ref_externa, d.tip_cargo, d.ind_valor, d.situacion, d.estado,
      d.tip_rechazo, d.mto_cargo, d.prioridad, d.nro_operacion, d.tip_mensaje, d.error, d.cod_usu_transaccion,
      d.imp_inf_hacienda, d.origen, d.plataforma, d.indemnizado, d.ref_oid, d.cod_per_intermediario, 
      d.nom_intermediario, d.cod_swi_pte_intermediario, d.dir_intermediario, d.nro_cta_pte_intermediario,
      d.cod_bco_corresponsal,       d.nom_corresponsal, d.cod_swi_pte_corresponsal,
      d.nro_cta_pte_corresponsal, d.ben_dir_correo, d.cod_tra_padre, 'SNP_TRANSFERENCIAS'
      from GE_CON_ESP_CIDESA m, ge_snp_transferencias d
     where m.fecha = vg_fec_actual
       and m.ref_origen = 'MOV_DIARIOS'
       and m.nro_documento = d.nro_referencia;
    vg_hor_fin := to_char(sysdate,'hh24:mi:ss');
    prg_act_log_procesos(vg_cod_programa,vg_lugar, vg_fec_actual, vg_hor_inicio, vg_hor_fin);
  exception
    when others then
         raise_application_error(-20000,'Error en LP_INS_TAB_SNP_TRANSFERENCIAS-'||sqlerrm);
  END LP_INS_TAB_SNP_TRANSFERENCIAS;
BEGIN
  --Carga nombre del Programa--
  VG_COD_PROGRAMA := 'PRB_INS_DAT_ESP_MOVIM';

  --Carga Variables del Proceso--
  LP_CAR_VAR_PROCESO;

  --Eliminar Tablas Temporales--
  LP_ELI_TAB_REG_DIARIO;

  --Inserta entidades Financieras--
  LP_INS_ENT_FINANCIERAS;

  --Inserta bancos en ge_bancos--
  LP_INS_ENT_BANCARIAS;

  --Inserta rubros especiales--
  LP_INS_TAB_RUBROS_TMP;
  
  --Insertar Tabla Especial de Asientos--
  LP_INS_TAB_ASIENTOS;
  
  --Insertar Tabla Especial de Asientos--
  LP_INS_TAB_ASIENTOS_DET;
  
  --Inserta Movimientos del dia--
  LP_INS_TAB_MOVIMIENTOS;
  
  --Insertar ge_snp_transferencias-
  LP_INS_TAB_SNP_TRANSFERENCIAS;

end PRB_INS_DAT_ESP_MOVIM;
/

