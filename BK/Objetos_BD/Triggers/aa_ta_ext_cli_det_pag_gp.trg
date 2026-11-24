CREATE OR REPLACE TRIGGER IT.aa_ta_ext_cli_det_pag_gp
 AFTER DELETE OR UPDATE
 ON TA_EXT_CLI_DET_PAG_GP
 FOR EACH ROW

DECLARE
r_taudi ta_auditorias%ROWTYPE;
BEGIN
  r_taudi.tabla := 'TA_EXT_CLI_DET_PAG_GP'; 
  r_taudi.clave := :old.nro_cuenta||'#'||:old.fec_cierre;
  r_taudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

  IF updating THEN
    r_taudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_taudi.tip_novedad := 'E';
  END IF;
   --- Registrar Detalle
  r_taudi.detalle := pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'NRO_CUENTA', :old.nro_cuenta, :new.nro_cuenta);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'FEC_CIERRE', :old.fec_cierre, :new.fec_cierre);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'DIA_MORA', :old.dia_mora, :new.dia_mora);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'CAR_POR_COMISION', :old.car_por_comision, :new.car_por_comision);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'MON_INTERES', :old.mon_interes, :new.mon_interes);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'MTO_IVA_CAR_COMISION', :old.mto_iva_car_comision, :new.mto_iva_car_comision);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'MTO_IVA_INTERES', :old.mto_iva_interes, :new.mto_iva_interes);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'TOT_FACTURA', :old.tot_factura, :new.tot_factura);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COM_NO_FINANCIABLES', :old.com_no_financiables, :new.com_no_financiables);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'GAS_FINANCIEROS', :old.gas_financieros, :new.gas_financieros);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COM_FINANCIABLES', :old.com_financiables, :new.com_financiables);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'SAL_MORA', :old.sal_mora, :new.sal_mora);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'MTO_PAG_MINIMO', :old.mto_pag_minimo, :new.mto_pag_minimo);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'INF_REL_SOCIO', :old.inf_rel_socio, :new.inf_rel_socio);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'NRO_COD_BARRA', :old.nro_cod_barra, :new.nro_cod_barra);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'INT_PUN_MORATORIO', :old.int_pun_moratorio, :new.int_pun_moratorio);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'CAT_BCP', :old.cat_bcp, :new.cat_bcp);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'FEC_CAT', :old.fec_cat, :new.fec_cat);

  --- Insertar tabla de auditoria
  PRT_INS_TA_AUDITORIA(r_taudi);
END;
/
