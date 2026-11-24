CREATE OR REPLACE TRIGGER IT.AA_TA_CON_TRA_DIA_DET_GP
  AFTER DELETE OR UPDATE
     ON it.TA_CON_TRA_DIA_DET_GP
    FOR EACH ROW
DECLARE
  r_taudi ta_auditorias%ROWTYPE; -- Registro de la tabla TA_AUDITORIAS
BEGIN
  r_taudi.tabla := 'TA_CON_TRA_DIA_DET_GP';
  r_taudi.clave := :old.nro_cuenta || '#' || :old.nro_tarjeta || '#' || :old.importe|| '#' ||:old.nro_comercio;
  r_taudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    r_taudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_taudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
r_taudi.detalle := pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'NRO_CAR_DIA', :old.nro_car_dia, :new.nro_car_dia);
r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'TIP_REGISTRO', :old.tip_registro, :new.tip_registro);
r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'NRO_CUENTA', :old.nro_cuenta, :new.nro_cuenta);
r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'ADICIONAL', :old.adicional, :new.adicional);
r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'NRO_TARJETA', :old.nro_tarjeta, :new.nro_tarjeta);
r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'FEC_HORA', :old.fec_hora, :new.fec_hora);
r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'IMPORTE', :old.importe, :new.importe);
r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'TIP_MONEDA', :old.tip_moneda, :new.tip_moneda);
r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'AUT_MONEDA', :old.aut_moneda, :new.aut_moneda);
r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'PLAN', :old.plan, :new.plan);
r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'CUOTAS', :old.cuotas, :new.cuotas);
r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_AUTORIZACION', :old.cod_autorizacion, :new.cod_autorizacion);
r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'AUT_FORZADA', :old.aut_forzada, :new.aut_forzada);
r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'AUT_REV_FLAG', :old.aut_rev_flag, :new.aut_rev_flag);
r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'AUT_AUT_DEBI', :old.aut_aut_debi, :new.aut_aut_debi);
r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'NRO_COMERCIO', :old.nro_comercio, :new.nro_comercio);
r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'NOM_COMERCIO', :old.nom_comercio, :new.nom_comercio);
r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'ESTADO', :old.estado, :new.estado);
r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'RELACIONADA', :old.relacionada, :new.relacionada);
r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'ORIGEN', :old.origen, :new.origen);
r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'RECHAZO', :old.rechazo, :new.rechazo);
r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'ICA', :old.ica, :new.ica);
r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'MCC', :old.mcc, :new.mcc);
r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'TCC', :old.tcc, :new.tcc);
r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_REG_FRAUDE', :old.cod_reg_fraude, :new.cod_reg_fraude);
r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'DES_REG_FRAUDE', :old.des_reg_fraude, :new.des_reg_fraude);
r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'MOD_ENTRADA', :old.mod_entrada, :new.mod_entrada);
r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'TERMINAL', :old.terminal, :new.terminal);
r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'USUARIO', :old.usuario, :new.usuario);
r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'STANDIN', :old.standin, :new.standin);
r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'AUT_MON_ORI_SO', :old.aut_mon_ori_so, :new.aut_mon_ori_so);
r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'IMP_ORI_AUTORIZACION', :old.imp_ori_autorizacion, :new.imp_ori_autorizacion);
r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'IMP_AUT_CONVERTIDO', :old.imp_aut_convertido, :new.imp_aut_convertido);
r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'SIG_IMP_AUT_CON', :old.sig_imp_aut_con, :new.sig_imp_aut_con);
r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'TOT_IMP_CARGOS', :old.tot_imp_cargos, :new.tot_imp_cargos);
r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'SIG_IMP_CARGOS', :old.sig_imp_cargos, :new.sig_imp_cargos);
r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'TOT_IMP_IVA', :old.tot_imp_iva, :new.tot_imp_iva);
r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'SIG_IMP_IVA', :old.sig_imp_iva, :new.sig_imp_iva);
r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'TOT_IMP_CAR_CON', :old.tot_imp_car_con, :new.tot_imp_car_con);
r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'SIG_CAR_CONVERTIDO', :old.sig_car_convertido, :new.sig_car_convertido);
r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'TOT_IMP_IVA_CON', :old.tot_imp_iva_con, :new.tot_imp_iva_con);
r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'SIG_IVA_CAR_CON', :old.sig_iva_car_con, :new.sig_iva_car_con);
r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'CON_CARGO', :old.con_cargo, :new.con_cargo);
r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'IMP_CAR_1', :old.imp_car_1, :new.imp_car_1);
r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'SIG_IMP_CAR_1', :old.sig_imp_car_1, :new.sig_imp_car_1);
r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'IMP_CAR_IVA_1', :old.imp_car_iva_1, :new.imp_car_iva_1);
r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'CON_CAR_2', :old.con_car_2, :new.con_car_2);
r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'IMP_CAR_2', :old.imp_car_2, :new.imp_car_2);
r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'SIG_IMP_2', :old.sig_imp_2, :new.sig_imp_2);
r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'IMP_IVA_CAR_2', :old.imp_iva_car_2, :new.imp_iva_car_2);
r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'CON_CAR_3', :old.con_car_3, :new.con_car_3);
r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'IMP_CAR_3', :old.imp_car_3, :new.imp_car_3);
r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'SIG_IMP_3', :old.sig_imp_3, :new.sig_imp_3);
r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'IMP_IVA_CAR_3', :old.imp_iva_car_3, :new.imp_iva_car_3);
r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'IMP_RG4240', :old.imp_rg4240, :new.imp_rg4240);
r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'SIG_IMP_RG4240', :old.sig_imp_rg4240, :new.sig_imp_rg4240);
r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'IMP_IIBB_RG4240', :old.imp_iibb_rg4240, :new.imp_iibb_rg4240);
r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'SIG_IMP_IIBB_RG4240', :old.sig_imp_iibb_rg4240, :new.sig_imp_iibb_rg4240);
r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'PRO_IIBB_RG4240', :old.pro_iibb_rg4240, :new.pro_iibb_rg4240);
r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'MTO_IMP_LEY_PAIS', :old.mto_imp_ley_pais, :new.mto_imp_ley_pais);
r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'SIG_IMP_LEY_PAIS', :old.sig_imp_ley_pais, :new.sig_imp_ley_pais);
r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'FILTRO', :old.filtro, :new.filtro);
r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'CTA_EXTERNA', :old.cta_externa, :new.cta_externa);
r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'REQUEST_ID', :old.request_id, :new.request_id);
r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'USU_INSERCION', :old.usu_insercion, :new.usu_insercion);
r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'FEC_INSERCION', :old.fec_insercion, :new.fec_insercion);
r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'USU_MODIFICACION', :old.usu_modificacion, :new.usu_modificacion);
r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'FEC_MODIFICACION', :old.fec_modificacion, :new.fec_modificacion);
r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'PROCESADO', :old.procesado, :new.procesado);
r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'ERROR', :old.error, :new.error);
r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'FEC_PROCESO', :old.fec_proceso, :new.fec_proceso);
  -- Insertar tabla de auditoria
  prt_ins_ta_auditoria( r_taudi );
EXCEPTION
  when others then
    prt_ins_ta_auditoria( r_taudi );
END;
