CREATE OR REPLACE TRIGGER IT.AA_TA_MOV_LIQ_DET
  AFTER DELETE OR UPDATE
     ON "IT"."TA_MOV_LIQ_DET"
    FOR EACH ROW
DECLARE

  r_taudi TA_AUDITORIAS%ROWTYPE; -- Registro de la tabla TA_AUDITORIAS
BEGIN
  r_taudi.tabla := 'TA_MOV_LIQ_DET';
  r_taudi.clave := :old.nro_cuenta;
  r_taudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    r_taudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_taudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
      r_taudi.detalle := pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'NRO_MOV_LIQ', :old.nro_mov_liq, :new.nro_mov_liq );
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'TIP_REGISTRO', :old.tip_registro, :new.tip_registro);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'NRO_TARJETA', :old.nro_tarjeta, :new.nro_tarjeta);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_MARCA', :old.cod_marca, :new.cod_marca);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_ENT_EMISORA', :old.cod_ent_emisora, :new.cod_ent_emisora);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_SUCURSAL', :old.cod_sucursal, :new.cod_sucursal);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'NRO_CUENTA', :old.nro_cuenta, :new.nro_cuenta);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'TIP_SOCIO', :old.tip_socio, :new.tip_socio);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'GRU_CTA_CORRIENTE', :old.gru_cta_corriente, :new.gru_cta_corriente);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'TIP_TRANSACCION', :old.tip_transaccion, :new.tip_transaccion);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'NRO_COMERCIO', :old.nro_comercio, :new.nro_comercio);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'NOM_FAN_COMERCIO', :old.nom_fan_comercio, :new.nom_fan_comercio);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_POS_COMERCIO', :old.cod_pos_comercio, :new.cod_pos_comercio);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_AUTORIZACION', :old.cod_autorizacion, :new.cod_autorizacion);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'ICA_ADQUIRENTE', :old.ica_adquirente, :new.ica_adquirente);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_MOVIMIENTO', :old.cod_movimiento, :new.cod_movimiento);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'DES_MOVIMIENTO', :old.des_movimiento, :new.des_movimiento);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COMPROBANTE', :old.comprobante, :new.comprobante);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'TIP_PLAN', :old.tip_plan, :new.tip_plan);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'PLA_CUOTAS', :old.pla_cuotas, :new.pla_cuotas);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'NRO_CUO_VIGENTE', :old.nro_cuo_vigente, :new.nro_cuo_vigente);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'FEC_OPERACION', :old.fec_operacion, :new.fec_operacion);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'HOR_OPERACION', :old.hor_operacion, :new.hor_operacion);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'FEC_PRESENTACION', :old.fec_presentacion, :new.fec_presentacion);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'FEC_CIE_CTA_CORRIENTE', :old.fec_cie_cta_corriente, :new.fec_cie_cta_corriente);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'FEC_CLEARING', :old.fec_clearing, :new.fec_clearing);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'FEC_DIFERIMIENTO', :old.fec_diferimiento, :new.fec_diferimiento);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'MCC', :old.mcc, :new.mcc);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_MONEDA', :old.cod_moneda, :new.cod_moneda);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'IMP_MON_MOVIMIENTO', :old.imp_mon_movimiento, :new.imp_mon_movimiento);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_MON_ORIGINAL', :old.cod_mon_original, :new.cod_mon_original);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'IMP_MON_ORIGINAL', :old.imp_mon_original, :new.imp_mon_original);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'IMP_INTERES', :old.imp_interes, :new.imp_interes);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'IMP_IVA', :old.imp_iva, :new.imp_iva);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'IMP_TOT_MOVIMIENTO', :old.imp_tot_movimiento, :new.imp_tot_movimiento);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'IMP_DES_FIN_OTORGADO', :old.imp_des_fin_otorgado, :new.imp_des_fin_otorgado);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'IMP_DES_FIN_OTORGADO_IVA', :old.imp_des_fin_otorgado_iva, :new.imp_des_fin_otorgado_iva);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'IMP_CUOTA', :old.imp_cuota, :new.imp_cuota);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'IMP_INT_CUOTA', :old.imp_int_cuota, :new.imp_int_cuota);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'IMP_IVA_CUOTA', :old.imp_iva_cuota, :new.imp_iva_cuota);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'IMP_TOT_CUOTA', :old.imp_tot_cuota, :new.imp_tot_cuota);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'DEBCRED', :old.debcred, :new.debcred);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'TIP_AMORTIZACION', :old.tip_amortizacion, :new.tip_amortizacion);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'CAN_ANTICIPADA', :old.can_anticipada, :new.can_anticipada);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'TNA', :old.tna, :new.tna);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'TEA', :old.tea, :new.tea);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'TAS_INTERCAMBIO', :old.tas_intercambio, :new.tas_intercambio);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'ARA_EMISOR', :old.ara_emisor, :new.ara_emisor);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'SIG_ARANCEL', :old.sig_arancel, :new.sig_arancel);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'IVA_ARA_EMISOR', :old.iva_ara_emisor, :new.iva_ara_emisor);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'SIG_IVA_ARANCEL', :old.sig_iva_arancel, :new.sig_iva_arancel);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'MOT_MENSAJE', :old.mot_mensaje, :new.mot_mensaje);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'IMP_COMPENSACION', :old.imp_compensacion, :new.imp_compensacion);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'SIG_IMP_COMPENSACION', :old.sig_imp_compensacion, :new.sig_imp_compensacion);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'IMP_PER_RG4240', :old.imp_per_rg4240, :new.imp_per_rg4240);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'SIG_IMP_PER_RG4240', :old.sig_imp_per_rg4240, :new.sig_imp_per_rg4240);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'MON_COMPENSACION', :old.mon_compensacion, :new.mon_compensacion);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'TIP_TARJETA', :old.tip_tarjeta, :new.tip_tarjeta);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'FILLER', :old.filler, :new.filler);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'PROCESADO', :old.procesado, :new.procesado);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'ERROR', :old.error, :new.error);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'FEC_PROCESO', :old.fec_proceso, :new.fec_proceso);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_USUARIO', :old.cod_usuario, :new.cod_usuario);

  -- Insertar tabla de auditoria
  prt_ins_ta_auditoria( r_taudi );
EXCEPTION
  when others then
    prt_ins_ta_auditoria( r_taudi );
END;
/

