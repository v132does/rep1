CREATE OR REPLACE TRIGGER IT.aa_ta_ext_cli_det_mov_gp
 AFTER DELETE OR UPDATE
 ON TA_EXT_CLI_DET_MOV_GP
 FOR EACH ROW

DECLARE
r_taudi ta_auditorias%ROWTYPE;
BEGIN
  r_taudi.tabla := 'TA_EXT_CLI_DET_MOV_GP'; 
  r_taudi.clave := :old.nro_cuenta||'#'||:old.fec_cierre||'#'||:old.nro_cupon;
  r_taudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

  IF updating THEN
    r_taudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_taudi.tip_novedad := 'E';
  END IF;
   --- Registrar Detalle
  r_taudi.detalle := pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'NRO_CUENTA', :old.nro_cuenta, :new.nro_cuenta);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'FEC_CIERRE', :old.fec_cierre, :new.fec_cierre);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'FEC_OPERACION', :old.fec_operacion, :new.fec_operacion);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'FEC_PROCESO', :old.fec_proceso, :new.fec_proceso);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'NRO_CUPON', :old.nro_cupon, :new.nro_cupon);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'DETALLE', :old.detalle, :new.detalle);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'NRO_CUOTA', :old.nro_cuota, :new.nro_cuota);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'FINANCIABLE', :old.financiable, :new.financiable);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'MTO_IVA', :old.mto_iva, :new.mto_iva);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COT_DOLAR', :old.cot_dolar, :new.cot_dolar);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'MONTO', :old.monto, :new.monto);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'LOCALIDAD', :old.localidad, :new.localidad);

  --- Insertar tabla de auditoria
  PRT_INS_TA_AUDITORIA(r_taudi);
END;
/
