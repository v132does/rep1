CREATE OR REPLACE TRIGGER IT.AA_AH_CON_DIA_DET
  AFTER DELETE OR UPDATE
     ON "IT"."AH_CON_DIA_DET"
    FOR EACH ROW
DECLARE
  r_taudi TA_AUDITORIAS%ROWTYPE; -- Registro de la tabla TA_AUDITORIAS
BEGIN
  r_taudi.tabla := 'AH_CON_DIA_DET';
  r_taudi.clave := :old.nro_cuenta;
  r_taudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    r_taudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_taudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'NRO_CON_DIA', :old.nro_con_dia, :new.nro_con_dia);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'TIP_REGISTRO', :old.tip_registro, :new.tip_registro);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'NRO_TARJETA', :old.nro_tarjeta, :new.nro_tarjeta);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_MARCA', :old.cod_marca, :new.cod_marca);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_ENT_EMISORA', :old.cod_ent_emisora, :new.cod_ent_emisora);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_OFICINA', :old.cod_oficina, :new.cod_oficina);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'NRO_CUENTA', :old.nro_cuenta, :new.nro_cuenta);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'TIP_SOCIO', :old.tip_socio, :new.tip_socio);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_GRU_CTA_CTE', :old.cod_gru_cta_cte, :new.cod_gru_cta_cte);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_TIP_TRANSACCION', :old.cod_tip_transaccion, :new.cod_tip_transaccion);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_COMERCIO', :old.cod_comercio, :new.cod_comercio);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'NOM_COMERCIO', :old.nom_comercio, :new.nom_comercio);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_POS_COMERCIO', :old.cod_pos_comercio, :new.cod_pos_comercio);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_AUTORIZACION', :old.cod_autorizacion, :new.cod_autorizacion);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_ICA_ADQUIRIENTE', :old.cod_ica_adquiriente, :new.cod_ica_adquiriente);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_MOVIMIENTO', :old.cod_movimiento, :new.cod_movimiento);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'DES_MOVIMIENTO', :old.des_movimiento, :new.des_movimiento);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'NRO_COMPROBANTE', :old.nro_comprobante, :new.nro_comprobante);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_TIP_PLAN', :old.cod_tip_plan, :new.cod_tip_plan);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'CAN_PLA_CUOTAS', :old.can_pla_cuotas, :new.can_pla_cuotas);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'NRO_CUO_VIGENTE', :old.nro_cuo_vigente, :new.nro_cuo_vigente);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'FEC_OPERACION', :old.fec_operacion, :new.fec_operacion);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'HOR_OPERACION', :old.hor_operacion, :new.hor_operacion);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'FEC_PRESENTACION', :old.fec_presentacion, :new.fec_presentacion);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'FEC_CIE_CTA_CTE', :old.fec_cie_cta_cte, :new.fec_cie_cta_cte);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'FEC_CLEARING', :old.fec_clearing, :new.fec_clearing);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'FEC_DIFERIMIENTO', :old.fec_diferimiento, :new.fec_diferimiento);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'MCC', :old.mcc, :new.mcc);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_MON_MOVIMIENTO', :old.cod_mon_movimiento, :new.cod_mon_movimiento);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'IMP_MON_MOVIMIENTO', :old.imp_mon_movimiento, :new.imp_mon_movimiento);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_MON_ORIGINAL', :old.cod_mon_original, :new.cod_mon_original);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'IMP_MON_ORIGINAL', :old.imp_mon_original, :new.imp_mon_original);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'IMP_INTERES', :old.imp_interes, :new.imp_interes);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'IMP_IVA', :old.imp_iva, :new.imp_iva);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'IMP_TOT_MOVIMIENTO', :old.imp_tot_movimiento, :new.imp_tot_movimiento);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'IMP_DESC_FIN_OTORGADO', :old.imp_desc_fin_otorgado, :new.imp_desc_fin_otorgado);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'IMP_DESC_FIN_OTO_IVA', :old.imp_desc_fin_oto_iva, :new.imp_desc_fin_oto_iva);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'IMP_CUOTA', :old.imp_cuota, :new.imp_cuota);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'IMP_INT_CUOTA', :old.imp_int_cuota, :new.imp_int_cuota);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'IMP_IVA_CUOTA', :old.imp_iva_cuota, :new.imp_iva_cuota);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'IMP_TOT_CUOTA', :old.imp_tot_cuota, :new.imp_tot_cuota);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_DEB_CRE', :old.cod_deb_cre, :new.cod_deb_cre);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'TIP_AMORTIZACION', :old.tip_amortizacion, :new.tip_amortizacion);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'TIP_TARJETA', :old.tip_tarjeta, :new.tip_tarjeta);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'TNA', :old.tna, :new.tna);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'TAE', :old.tae, :new.tae);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'TAI', :old.tai, :new.tai);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'IMP_ARA_EMISOR', :old.imp_ara_emisor, :new.imp_ara_emisor);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'SIG_IVA_ARANCEL', :old.sig_iva_arancel, :new.sig_iva_arancel);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'IMP_IVA_ARA_EMISOR', :old.imp_iva_ara_emisor, :new.imp_iva_ara_emisor);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'SIG_IVA_ARANCEL2', :old.sig_iva_arancel2, :new.sig_iva_arancel2);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'MOT_MENSAJE', :old.mot_mensaje, :new.mot_mensaje);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'IMP_COMPENSACION', :old.imp_compensacion, :new.imp_compensacion);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'SIG_IMP_COMPENSACION', :old.sig_imp_compensacion, :new.sig_imp_compensacion);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'IMP_PERCEP', :old.imp_percep, :new.imp_percep);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'SIG_PERCEP', :old.sig_percep, :new.sig_percep);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'TIP_PRODUCTO', :old.tip_producto, :new.tip_producto);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'FEC_CIE_COMERCIOS', :old.fec_cie_comercios, :new.fec_cie_comercios);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'PLAN', :old.plan, :new.plan);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'MON_COMPENSACION', :old.mon_compensacion, :new.mon_compensacion);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'IMP_AUTORIZACION', :old.imp_autorizacion, :new.imp_autorizacion);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'SIG_IMP_AUTORIZACION', :old.sig_imp_autorizacion, :new.sig_imp_autorizacion);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'MON_AUTORIZACION', :old.mon_autorizacion, :new.mon_autorizacion);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'IMP_AUT_CONVENIO', :old.imp_aut_convenio, :new.imp_aut_convenio);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'SIG_IMP_AUT_CONVENIO', :old.sig_imp_aut_convenio, :new.sig_imp_aut_convenio);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'MON_AUT_CONVENIO', :old.mon_aut_convenio, :new.mon_aut_convenio);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'IMP_IPM_DE6', :old.imp_ipm_de6, :new.imp_ipm_de6);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'SIG_IMP_IPM', :old.sig_imp_ipm, :new.sig_imp_ipm);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'MON_IPM', :old.mon_ipm, :new.mon_ipm);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'ID_AUTO', :old.id_auto, :new.id_auto);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'ID_COD_AUTO', :old.id_cod_auto, :new.id_cod_auto);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'CTA_EXTERNA', :old.cta_externa, :new.cta_externa);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'REQUEST_ID', :old.request_id, :new.request_id);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'IMP_PERCEP_27', :old.imp_percep_27, :new.imp_percep_27);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'SIG_PERCEP_27', :old.sig_percep_27, :new.sig_percep_27);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'IMP_IVA_SER_DIGITALES', :old.imp_iva_ser_digitales, :new.imp_iva_ser_digitales);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'SIG_IMP_IVA_SER_DIG', :old.sig_imp_iva_ser_dig, :new.sig_imp_iva_ser_dig);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'IMP_IIBB', :old.imp_iibb, :new.imp_iibb);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'SIG_IMP_IIBB', :old.sig_imp_iibb, :new.sig_imp_iibb);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_PCIA_IIBB', :old.cod_pcia_iibb, :new.cod_pcia_iibb);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'ESTADO', :old.estado, :new.estado);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'FILTER', :old.filter, :new.filter);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'USU_INSERCION', :old.usu_insercion, :new.usu_insercion);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'FEC_INSERCION', :old.fec_insercion, :new.fec_insercion);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'USU_MODIFICACION', :old.usu_modificacion, :new.usu_modificacion);
      r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'FEC_MODIFICACION', :old.fec_modificacion, :new.fec_modificacion);
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

