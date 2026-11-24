CREATE OR REPLACE TRIGGER IT.aa_ta_ext_cli_cab_gp
 AFTER DELETE OR UPDATE
 ON TA_EXT_CLI_CAB_GP
 FOR EACH ROW

DECLARE
r_taudi ta_auditorias%rowtype; -- Registro de la tabla TA_AUDITORIAS
BEGIN
  r_taudi.tabla := 'TA_EXT_CLI_CAB_GP'; 
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
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'NRO_FACTURA', :old.nro_factura, :new.nro_factura);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'VAL_DESDE', :old.val_desde, :new.val_desde);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'VAL_HASTA', :old.val_hasta, :new.val_hasta);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'NRO_TARJETA', :old.nro_tarjeta, :new.nro_tarjeta);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'FEC_VENCIMIENTO', :old.fec_vencimiento, :new.fec_vencimiento);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'FEC_CIE_SIG', :old.fec_cie_sig, :new.fec_cie_sig);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'FEC_VEN_SIG', :old.fec_ven_sig, :new.fec_ven_sig);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'FEC_CIE_ANT', :old.fec_cie_ant, :new.fec_cie_ant);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'FEC_VEN_ANT', :old.fec_ven_ant, :new.fec_ven_ant);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'DEU_ANT', :old.deu_ant, :new.deu_ant);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'MTO_PAGO', :old.mto_pago, :new.mto_pago);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'SAL_FINANCIADO', :old.sal_financiado, :new.sal_financiado);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'MTO_CAR_MES', :old.mto_car_mes, :new.mto_car_mes);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'VAL_DEU_TOT_MES', :old.val_deu_tot_mes, :new.val_deu_tot_mes);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'VAL_DEU_CUO_FACTURAR', :old.val_deu_cuo_facturar, :new.val_deu_cuo_facturar);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'INT_CAR_DEV_SUSPENSO', :old.int_car_dev_suspenso, :new.int_car_dev_suspenso);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'VAL_DEU_TOTAL', :old.val_deu_total, :new.val_deu_total);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'LIN_CREDITO', :old.lin_credito, :new.lin_credito);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'LIN_DISPONIBLE', :old.lin_disponible, :new.lin_disponible);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'TAS_ANU_NOMINAL', :old.tas_anu_nominal, :new.tas_anu_nominal);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'TAS_ANU_EFECTIVA', :old.tas_anu_efectiva, :new.tas_anu_efectiva);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'OBS_RESUMEN', :old.obs_resumen, :new.obs_resumen);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'CON_MOVIMIENTO', :old.con_movimiento, :new.con_movimiento);

  --- Insertar tabla de auditoria
  PRT_INS_TA_AUDITORIA(r_taudi);
END;
/
