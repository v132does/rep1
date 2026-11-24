CREATE OR REPLACE TRIGGER IT.AA_MD_DEP_CTA_DOCUMENTOS AFTER DELETE OR UPDATE
     ON MD_DEP_CTA_DOCUMENTOS
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 19/06/2018 a las 16:25:00 Hs.
  */
  v_registro MD_AUDITORIAS%ROWTYPE; -- Registro de la tabla MD_AUDITORIAS
BEGIN
  v_registro.tabla := 'MD_DEP_CTA_DOCUMENTOS';
  v_registro.clave := :old.nro_referencia;
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_MODULO', :old.cod_modulo, :new.cod_modulo, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_CUENTA', :old.nro_cuenta, :new.nro_cuenta );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_MODALIDAD', :old.cod_modalidad, :new.cod_modalidad, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_OFICINA', :old.cod_oficina, :new.cod_oficina, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_MONEDA', :old.cod_moneda, :new.cod_moneda );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_PERSONA', :old.cod_persona, :new.cod_persona );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_DOCUMENTO', :old.nro_documento, :new.nro_documento );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'DENOMINACION', :old.denominacion, :new.denominacion );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_INICIO', :old.fec_inicio, :new.fec_inicio, 'F' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_VENCIMIENTO', :old.fec_vencimiento, :new.fec_vencimiento, 'F' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MONTO', :old.monto, :new.monto, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'VAL_TASA', :old.val_tasa, :new.val_tasa, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'CANTIDAD', :old.cantidad, :new.cantidad, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'ESTADO', :old.estado, :new.estado );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_CAM_ESTADO', :old.fec_cam_estado, :new.fec_cam_estado, 'F' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_CANCELACION', :old.fec_cancelacion, :new.fec_cancelacion );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MTO_INTERES', :old.mto_interes, :new.mto_interes, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'VAL_PRESENTE', :old.val_presente, :new.val_presente, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'SAL_INTERES', :old.sal_interes, :new.sal_interes, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'EST_BATCH', :old.est_batch, :new.est_batch );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'SAL_VAL_PRE_BATCH', :old.sal_val_pre_batch, :new.sal_val_pre_batch, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'SAL_INT_BATCH', :old.sal_int_batch, :new.sal_int_batch, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_ULT_DEVENGADO', :old.fec_ult_devengado, :new.fec_ult_devengado, 'F' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'BENEFICIARIO', :old.beneficiario, :new.beneficiario );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'DEV_ACUMULADO', :old.dev_acumulado, :new.dev_acumulado, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TIP_CALCULO', :old.tip_calculo, :new.tip_calculo );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_CAUSA', :old.cod_causa, :new.cod_causa, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_CTA_PADRE', :old.nro_cta_padre, :new.nro_cta_padre );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COM_DOC_RELACIONADOS', :old.com_doc_relacionados, :new.com_doc_relacionados );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'SAL_VAL_PRESENTE', :old.sal_val_presente, :new.sal_val_presente, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'VAL_INT_DEVENGAR', :old.val_int_devengar, :new.val_int_devengar, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_INSTRUCCION', :old.cod_instruccion, :new.cod_instruccion );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'OBSERVACION', :old.observacion, :new.observacion );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_PER_ADQUIRIDO', :old.cod_per_adquirido, :new.cod_per_adquirido );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FOR_PAGO', :old.for_pago, :new.for_pago );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_REF_CREDITO', :old.nro_ref_credito, :new.nro_ref_credito );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_PER_VENDIDO', :old.cod_per_vendido, :new.cod_per_vendido );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MTO_VENTA', :old.mto_venta, :new.mto_venta, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MTO_INT_VENTA', :old.mto_int_venta, :new.mto_int_venta, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'DIA_ANO', :old.dia_ano, :new.dia_ano, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COMISION', :old.comision, :new.comision, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'SAL_BATCH', :old.sal_batch, :new.sal_batch, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MTO_DEV_DIA', :old.mto_dev_dia, :new.mto_dev_dia, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'DIA_DEVENGADO', :old.dia_devengado, :new.dia_devengado, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MTO_IMPUESTO', :old.mto_impuesto, :new.mto_impuesto, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'SAL_CAPITAL', :old.sal_capital, :new.sal_capital, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TOT_INT_DESCONTADO', :old.tot_int_descontado, :new.tot_int_descontado, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_OFI_CREDITO', :old.cod_ofi_credito, :new.cod_ofi_credito, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_OFI_INTERES', :old.cod_ofi_interes, :new.cod_ofi_interes, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MTO_OFI_INTERES', :old.mto_ofi_interes, :new.mto_ofi_interes, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_SEC_CREDITO', :old.cod_sec_credito, :new.cod_sec_credito, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_BCO_CENTRAL', :old.cod_bco_central, :new.cod_bco_central );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TIP_COB_INTERES', :old.tip_cob_interes, :new.tip_cob_interes );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TIP_AMORTIZACION', :old.tip_amortizacion, :new.tip_amortizacion );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_ULT_PAGO', :old.fec_ult_pago, :new.fec_ult_pago, 'F' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'PER_ADQUIRIDO', :old.per_adquirido, :new.per_adquirido );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_INI_REPO', :old.fec_ini_repo, :new.fec_ini_repo, 'F' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_VEN_REPO', :old.fec_ven_repo, :new.fec_ven_repo, 'F' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'VAL_TAS_REPO', :old.val_tas_repo, :new.val_tas_repo, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'VAL_BAS_REPO', :old.val_bas_repo, :new.val_bas_repo, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_SIT_CONTABLE', :old.cod_sit_contable, :new.cod_sit_contable );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MER_SECUNDARIO', :old.mer_secundario, :new.mer_secundario );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_CTA_REPO', :old.nro_cta_repo, :new.nro_cta_repo );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_LINEA', :old.nro_linea, :new.nro_linea, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_RUB_ECONOMICO', :old.cod_rub_economico, :new.cod_rub_economico );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TIP_DOCUMENTO', :old.tip_documento, :new.tip_documento );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_TIP_OPERACION', :old.cod_tip_operacion, :new.cod_tip_operacion, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'SAL_DISPONIBLE', :old.sal_disponible, :new.sal_disponible, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'DES_OPERACION', :old.des_operacion, :new.des_operacion );

  -- Insertar tabla de auditoria
  prm_ins_md_auditoria( v_registro );
EXCEPTION
  when others then
    prm_ins_md_auditoria( v_registro );
END;
/

