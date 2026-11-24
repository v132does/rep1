CREATE OR REPLACE TRIGGER IT.AA_BW_OPE_CLA_TAS
  AFTER DELETE OR UPDATE
     ON BW_OPE_CLA_TAS
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2014 - IT Consultores
  || Generado el 05/08/2014 a las 17:41:23 Hs.
  */
  r_waudi BW_AUDITORIAS%ROWTYPE; -- Registro de la tabla BW_AUDITORIAS
BEGIN
  r_waudi.tabla := 'BW_OPE_CLA_TAS';
  r_waudi.clave := :old.cod_persona || '#' || :old.cod_per_vinculada;
  r_waudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    r_waudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_waudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  r_waudi.detalle := pae_cnf.fu_reg_auditoria( r_waudi.tip_novedad, 'CLA_VERIFICADOR', :old.cla_verificador, :new.cla_verificador, 'N' );
  r_waudi.detalle := r_waudi.detalle || pae_cnf.fu_reg_auditoria( r_waudi.tip_novedad, 'CLAVE', :old.clave, :new.clave );
  r_waudi.detalle := r_waudi.detalle || pae_cnf.fu_reg_auditoria( r_waudi.tip_novedad, 'CLA_IMPRESA', :old.cla_impresa, :new.cla_impresa );
  r_waudi.detalle := r_waudi.detalle || pae_cnf.fu_reg_auditoria( r_waudi.tip_novedad, 'CAN_ACCESO', :old.can_acceso, :new.can_acceso, 'N' );
  r_waudi.detalle := r_waudi.detalle || pae_cnf.fu_reg_auditoria( r_waudi.tip_novedad, 'EST_CLAVE', :old.est_clave, :new.est_clave );
  r_waudi.detalle := r_waudi.detalle || pae_cnf.fu_reg_auditoria( r_waudi.tip_novedad, 'FEC_EST_CLAVE', :old.fec_est_clave, :new.fec_est_clave, 'F' );
  r_waudi.detalle := r_waudi.detalle || pae_cnf.fu_reg_auditoria( r_waudi.tip_novedad, 'CAN_INTENTOS', :old.can_intentos, :new.can_intentos, 'N' );
  r_waudi.detalle := r_waudi.detalle || pae_cnf.fu_reg_auditoria( r_waudi.tip_novedad, 'FEC_ULT_ERROR', :old.fec_ult_error, :new.fec_ult_error, 'F' );
  r_waudi.detalle := r_waudi.detalle || pae_cnf.fu_reg_auditoria( r_waudi.tip_novedad, 'FEC_ULT_ACCESO', :old.fec_ult_acceso, :new.fec_ult_acceso, 'F' );
  r_waudi.detalle := r_waudi.detalle || pae_cnf.fu_reg_auditoria( r_waudi.tip_novedad, 'USU_IMPRESION', :old.usu_impresion, :new.usu_impresion );
  r_waudi.detalle := r_waudi.detalle || pae_cnf.fu_reg_auditoria( r_waudi.tip_novedad, 'FEC_IMPRESION', :old.fec_impresion, :new.fec_impresion, 'F' );
  r_waudi.detalle := r_waudi.detalle || pae_cnf.fu_reg_auditoria( r_waudi.tip_novedad, 'COD_OFI_IMPRESION', :old.cod_ofi_impresion, :new.cod_ofi_impresion, 'N' );
  r_waudi.detalle := r_waudi.detalle || pae_cnf.fu_reg_auditoria( r_waudi.tip_novedad, 'FEC_CAM_CLAVE', :old.fec_cam_clave, :new.fec_cam_clave, 'F' );
  r_waudi.detalle := r_waudi.detalle || pae_cnf.fu_reg_auditoria( r_waudi.tip_novedad, 'TIP_CLAVE', :old.tip_clave, :new.tip_clave );
  r_waudi.detalle := r_waudi.detalle || pae_cnf.fu_reg_auditoria( r_waudi.tip_novedad, 'COD_CANAL', :old.cod_canal, :new.cod_canal );
  -- Insertar tabla de auditoria
  prw_ins_bw_auditoria( r_waudi );
EXCEPTION
  when others then
    prw_ins_bw_auditoria( r_waudi );
END;
/

