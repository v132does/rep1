CREATE OR REPLACE TRIGGER IT.AA_TA_CTA_TARJETAS
  AFTER DELETE OR UPDATE
  OF NRO_CUENTA,
    DENOMINACION,
    COD_MODULO,
    COD_MODALIDAD,
    COD_OFICINA,
    COD_MONEDA,
    LIN_CREDITO,
    LIN_CUOTAS,
    MTO_PAG_MINIMO,
    MTO_MORA,
    DIA_MORA,
    MTO_AUTORIZACIONES,
    MTO_INT_COMPRAS,
    MTO_PAG_MES,
    MTO_GAS_MORA,
    ESTADO,
    EST_ADMINISTRADORA,
    FEC_SOLICITUD,
    FEC_APERTURA,
    FEC_ULT_PAGO,
    FEC_ULT_COMPRA,
    FEC_ULT_OPERACION,
    FEC_ULT_EXTRACTO,
    FEC_ULT_CIERRE,
    FEC_VCT_ULT_CIERRE,
    COD_TIP_CIERRE,
    COB_GAS_FINANCIERO,
    TIP_TAS_FINANCIACION,
    TIP_COM_EMISION,
    TAS_FINANCIACION,
    TAS_ADELANTO,
    TAS_MORA,
    TAS_CUOTAS,
    DEB_AUTOMATICO,
    TIP_COBRO,
    NRO_CTA_DEBITO,
    MTO_MIN_PAGO,
    POR_PAG_MINIMO,
    COD_USU_PROMOTOR,
    MAR_MORA,
    MAR_EXCEDIDO,
    MAR_RECUPERADO,
    MAR_BLOQUEO,
    CON_COSTO,
    NRO_SOLICITUD,
    COD_CAUSA,
    COD_CANAL,
    COD_CAMPANA,
    USU_INSERCION,
    FEC_INSERCION,
    USU_MODIFICACION,
    FEC_MODIFICACION,
    CAT_AUTOMATICA,
    EN_JUICIO,
    FEC_JUICIO,
    COD_ENT_JUICIO,
    MAX_ATRASO,
    PRO_ATRASO,
    NRO_LINEA,
    COD_RUB_ECONOMICO
     ON TA_CTA_TARJETAS
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 03/05/2013 a las 11:30:35 Hs.
  */
  r_taudi TA_AUDITORIAS%ROWTYPE; -- Registro de la tabla TA_AUDITORIAS
  v_usu_excluido ge_par_dinamicos.val_parametro%TYPE:=fug_obt_pardinamico('TAR_COD_USU_EXCLUIDO');
BEGIN
  IF instr(v_usu_excluido,USER) = 0 THEN
  r_taudi.tabla := 'TA_CTA_TARJETAS';
  r_taudi.clave := :old.nro_cuenta;
  r_taudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    r_taudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_taudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  r_taudi.detalle := pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'DENOMINACION', :old.denominacion, :new.denominacion );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_MODULO', :old.cod_modulo, :new.cod_modulo, 'N' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_MODALIDAD', :old.cod_modalidad, :new.cod_modalidad, 'N' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_OFICINA', :old.cod_oficina, :new.cod_oficina, 'N' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_MONEDA', :old.cod_moneda, :new.cod_moneda );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'LIN_CREDITO', :old.lin_credito, :new.lin_credito, 'M' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'LIN_CUOTAS', :old.lin_cuotas, :new.lin_cuotas, 'M' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'SAL_FACTURAR', :old.sal_facturar, :new.sal_facturar, 'M' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'SAL_FACTURADO', :old.sal_facturado, :new.sal_facturado, 'M' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'SAL_FINANCIADO', :old.sal_financiado, :new.sal_financiado, 'M' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'SAL_ULT_EXTRACTO', :old.sal_ult_extracto, :new.sal_ult_extracto, 'M' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'SAL_CUO_PENDIENTES', :old.sal_cuo_pendientes, :new.sal_cuo_pendientes, 'M' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'MTO_PAG_MINIMO', :old.mto_pag_minimo, :new.mto_pag_minimo, 'M' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'SAL_PAG_MINIMO', :old.sal_pag_minimo, :new.sal_pag_minimo, 'M' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'MTO_MORA', :old.mto_mora, :new.mto_mora, 'M' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'DIA_MORA', :old.dia_mora, :new.dia_mora, 'M' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'MTO_AUTORIZACIONES', :old.mto_autorizaciones, :new.mto_autorizaciones, 'M' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'MTO_INT_COMPRAS', :old.mto_int_compras, :new.mto_int_compras, 'M' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'MTO_PAG_MES', :old.mto_pag_mes, :new.mto_pag_mes, 'M' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'MTO_GAS_MORA', :old.mto_gas_mora, :new.mto_gas_mora, 'M' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'ESTADO', :old.estado, :new.estado );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'EST_ADMINISTRADORA', :old.est_administradora, :new.est_administradora );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'FEC_SOLICITUD', :old.fec_solicitud, :new.fec_solicitud, 'F' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'FEC_APERTURA', :old.fec_apertura, :new.fec_apertura, 'F' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'FEC_ULT_PAGO', :old.fec_ult_pago, :new.fec_ult_pago, 'F' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'FEC_ULT_COMPRA', :old.fec_ult_compra, :new.fec_ult_compra, 'F' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'FEC_ULT_OPERACION', :old.fec_ult_operacion, :new.fec_ult_operacion, 'F' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'FEC_ULT_EXTRACTO', :old.fec_ult_extracto, :new.fec_ult_extracto, 'F' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'FEC_ULT_CIERRE', :old.fec_ult_cierre, :new.fec_ult_cierre, 'F' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'FEC_VCT_ULT_CIERRE', :old.fec_vct_ult_cierre, :new.fec_vct_ult_cierre, 'F' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_TIP_CIERRE', :old.cod_tip_cierre, :new.cod_tip_cierre, 'N' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COB_GAS_FINANCIERO', :old.cob_gas_financiero, :new.cob_gas_financiero );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'TIP_TAS_FINANCIACION', :old.tip_tas_financiacion, :new.tip_tas_financiacion );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'TIP_COM_EMISION', :old.tip_com_emision, :new.tip_com_emision );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'TAS_FINANCIACION', :old.tas_financiacion, :new.tas_financiacion, 'M' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'TAS_ADELANTO', :old.tas_adelanto, :new.tas_adelanto, 'M' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'TAS_MORA', :old.tas_mora, :new.tas_mora, 'M' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'TAS_CUOTAS', :old.tas_cuotas, :new.tas_cuotas, 'M' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'DEB_AUTOMATICO', :old.deb_automatico, :new.deb_automatico );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'TIP_COBRO', :old.tip_cobro, :new.tip_cobro );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'NRO_CTA_DEBITO', :old.nro_cta_debito, :new.nro_cta_debito );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'MTO_MIN_PAGO', :old.mto_min_pago, :new.mto_min_pago, 'M' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'POR_PAG_MINIMO', :old.por_pag_minimo, :new.por_pag_minimo, 'N' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_USU_PROMOTOR', :old.cod_usu_promotor, :new.cod_usu_promotor );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'MAR_MORA', :old.mar_mora, :new.mar_mora );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'MAR_EXCEDIDO', :old.mar_excedido, :new.mar_excedido );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'MAR_RECUPERADO', :old.mar_recuperado, :new.mar_recuperado );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'MAR_BLOQUEO', :old.mar_bloqueo, :new.mar_bloqueo );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'CON_COSTO', :old.con_costo, :new.con_costo );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'NRO_SOLICITUD', :old.nro_solicitud, :new.nro_solicitud, 'M' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_CAUSA', :old.cod_causa, :new.cod_causa, 'N' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_CANAL', :old.cod_canal, :new.cod_canal, 'N' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_CAMPANA', :old.cod_campana, :new.cod_campana, 'N' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'CAT_AUTOMATICA', :old.cat_automatica, :new.cat_automatica, 'N' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'EN_JUICIO', :old.en_juicio, :new.en_juicio );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'FEC_JUICIO', :old.fec_juicio, :new.fec_juicio, 'F' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_ENT_JUICIO', :old.cod_ent_juicio, :new.cod_ent_juicio, 'N' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'MAX_ATRASO', :old.max_atraso, :new.max_atraso, 'N' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'PRO_ATRASO', :old.pro_atraso, :new.pro_atraso, 'N' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'NRO_LINEA', :old.nro_linea, :new.nro_linea, 'N' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_RUB_ECONOMICO', :old.cod_rub_economico, :new.cod_rub_economico );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'CAT_AUT_ANTERIOR', :old.cat_aut_anterior, :new.cat_aut_anterior, 'N' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'FEC_ACTIVACION', :old.fec_activacion, :new.fec_activacion, 'F' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'FEC_CANCELACION', :old.fec_cancelacion, :new.fec_cancelacion, 'F' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'TAS_EFECTIVA', :old.tas_efectiva, :new.tas_efectiva, 'M' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'MTO_AUT_CUOTAS', :old.mto_aut_cuotas, :new.mto_aut_cuotas, 'M' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'AFINIDAD', :old.afinidad, :new.afinidad );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'SUB_AFINIDAD', :old.sub_afinidad, :new.sub_afinidad );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'SAL_PROCESADORA', :old.sal_procesadora, :new.sal_procesadora, 'M' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'MTO_FIJ_PAG_MINIMO', :old.mto_fij_pag_minimo, :new.mto_fij_pag_minimo, 'M' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'MTO_MIN_PAG_MINIMO', :old.mto_min_pag_minimo, :new.mto_min_pag_minimo, 'M' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'TAS_INT_CORRIENTE', :old.tas_int_corriente, :new.tas_int_corriente, 'M' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'TAS_INT_COMPRA', :old.tas_int_compra, :new.tas_int_compra, 'M' );

  -- Insertar tabla de auditoria
  prt_ins_ta_auditoria( r_taudi );
  END IF;
EXCEPTION
  when others then
    IF instr(v_usu_excluido,USER) = 0 THEN
    prt_ins_ta_auditoria( r_taudi );
    END IF;
END;
/
