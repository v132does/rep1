CREATE OR REPLACE TRIGGER IT.AA_GE_SOL_ACT_DATOS
  AFTER DELETE OR UPDATE
     ON GE_SOL_ACT_DATOS
    FOR EACH ROW
DECLARE
  r_gaudi GE_AUDITORIAS%ROWTYPE; -- Registro de la tabla GE_AUDITORIAS
BEGIN
  r_gaudi.tabla := 'GE_SOL_ACT_DATOS';
  r_gaudi.clave := to_char( :old.nro_solicitud);
  r_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    r_gaudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_gaudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  r_gaudi.detalle := pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'COD_PERSONA', :old.cod_persona, :new.cod_persona );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'FEC_SOLICITUD', :old.fec_solicitud, :new.fec_solicitud, 'F'  );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'ESTADO', :old.estado, :new.estado );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'COD_USUARIO', :old.cod_usuario, :new.cod_usuario );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'COD_OFICINA', :old.cod_oficina, :new.cod_oficina, 'N' );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'COD_USU_APROBACION', :old.cod_usu_aprobacion, :new.cod_usu_aprobacion );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'COD_OFI_APROBACION', :old.cod_ofi_aprobacion, :new.cod_ofi_aprobacion, 'N' );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'FEC_CAM_ESTADO', :old.fec_cam_estado, :new.fec_cam_estado, 'F' );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'EST_ANTERIOR', :old.est_anterior, :new.est_anterior );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'MOT_RECHAZO', :old.mot_rechazo, :new.mot_rechazo );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'OBSERVACION', :old.observacion, :new.observacion );

  -- Insertar tabla de auditoria
  prg_ins_ge_auditoria( r_gaudi );
EXCEPTION
  when others then
    prg_ins_ge_auditoria( r_gaudi );
END;
/

