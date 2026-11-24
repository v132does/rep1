CREATE OR REPLACE TRIGGER IT.AA_BW_OPE_CLAVES
  AFTER DELETE OR UPDATE
     ON BW_OPE_CLAVES
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 09/05/2014 a las 15:45:54 Hs.
  */
  r_eaudi BW_AUDITORIAS%ROWTYPE; -- Registro de la tabla BW_AUDITORIAS
BEGIN
  r_eaudi.tabla := 'BW_OPE_CLAVES';
  r_eaudi.clave := :old.cod_persona || '#' || :old.cod_per_vinculada || '#' || :old.tip_clave;
  r_eaudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    r_eaudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_eaudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  r_eaudi.detalle := pae_cnf.fu_reg_auditoria( r_eaudi.tip_novedad, 'CLA_VERIFICADOR', :old.cla_verificador, :new.cla_verificador, 'N' );
  r_eaudi.detalle := r_eaudi.detalle || pae_cnf.fu_reg_auditoria( r_eaudi.tip_novedad, 'CLAVE', :old.clave, :new.clave );
  r_eaudi.detalle := r_eaudi.detalle || pae_cnf.fu_reg_auditoria( r_eaudi.tip_novedad, 'CLA_IMPRESA', :old.cla_impresa, :new.cla_impresa );
  r_eaudi.detalle := r_eaudi.detalle || pae_cnf.fu_reg_auditoria( r_eaudi.tip_novedad, 'CAN_ACCESO', :old.can_acceso, :new.can_acceso, 'N' );
  r_eaudi.detalle := r_eaudi.detalle || pae_cnf.fu_reg_auditoria( r_eaudi.tip_novedad, 'EST_CLAVE', :old.est_clave, :new.est_clave );
  r_eaudi.detalle := r_eaudi.detalle || pae_cnf.fu_reg_auditoria( r_eaudi.tip_novedad, 'FEC_EST_CLAVE', :old.fec_est_clave, :new.fec_est_clave, 'F' );
  r_eaudi.detalle := r_eaudi.detalle || pae_cnf.fu_reg_auditoria( r_eaudi.tip_novedad, 'CAN_INTENTOS', :old.can_intentos, :new.can_intentos, 'N' );
  r_eaudi.detalle := r_eaudi.detalle || pae_cnf.fu_reg_auditoria( r_eaudi.tip_novedad, 'FEC_ULT_ERROR', :old.fec_ult_error, :new.fec_ult_error, 'F' );
  r_eaudi.detalle := r_eaudi.detalle || pae_cnf.fu_reg_auditoria( r_eaudi.tip_novedad, 'FEC_ULT_ACCESO', :old.fec_ult_acceso, :new.fec_ult_acceso, 'F' );
  r_eaudi.detalle := r_eaudi.detalle || pae_cnf.fu_reg_auditoria( r_eaudi.tip_novedad, 'USU_IMPRESION', :old.usu_impresion, :new.usu_impresion );
  r_eaudi.detalle := r_eaudi.detalle || pae_cnf.fu_reg_auditoria( r_eaudi.tip_novedad, 'FEC_IMPRESION', :old.fec_impresion, :new.fec_impresion, 'F' );
  r_eaudi.detalle := r_eaudi.detalle || pae_cnf.fu_reg_auditoria( r_eaudi.tip_novedad, 'COD_OFI_IMPRESION', :old.cod_ofi_impresion, :new.cod_ofi_impresion, 'N' );
  r_eaudi.detalle := r_eaudi.detalle || pae_cnf.fu_reg_auditoria( r_eaudi.tip_novedad, 'FEC_CAM_CLAVE', :old.fec_cam_clave, :new.fec_cam_clave, 'F' );
  r_eaudi.detalle := r_eaudi.detalle || pae_cnf.fu_reg_auditoria( r_eaudi.tip_novedad, 'NRO_LOTE', :old.nro_lote, :new.nro_lote, 'N' );
  r_eaudi.detalle := r_eaudi.detalle || pae_cnf.fu_reg_auditoria( r_eaudi.tip_novedad, 'CAN_IMPRESION', :old.can_impresion, :new.can_impresion, 'N' );

  -- Insertar tabla de auditoria
  prw_ins_bw_auditoria( r_eaudi );
EXCEPTION
  when others then
    prw_ins_bw_auditoria( r_eaudi );
END;
/

