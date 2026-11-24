CREATE OR REPLACE TRIGGER IT.aa_ta_ext_cli_log_gp
 AFTER DELETE OR UPDATE
 ON ta_ext_cli_log_gp
 FOR EACH ROW

DECLARE
r_taudi ta_auditorias%rowtype; -- Registro de la tabla TA_AUDITORIAS
BEGIN
  r_taudi.tabla := 'TA_EXT_CLI_LOG_GP'; 
  r_taudi.clave := :old.nro_cuenta||'#'||:old.fec_cierre;
  r_taudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

  IF updating THEN
    r_taudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_taudi.tip_novedad := 'E';
  END IF;
   --- Registrar Detalle
  r_taudi.detalle := pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'FEC_CIERRE', :old.fec_cierre, :new.fec_cierre);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'NRO_CUENTA', :old.nro_cuenta, :new.nro_cuenta);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'NRO_TARJETA', :old.nro_tarjeta, :new.nro_tarjeta);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'NOM_ARCHIVO', :old.nom_archivo, :new.nom_archivo);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'CON_MOVIMIENTO', :old.con_movimiento, :new.con_movimiento);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'ERR_LOG', :old.err_log, :new.err_log);

  --- Insertar tabla de auditoria
  PRT_INS_TA_AUDITORIA(r_taudi);
END;
/
