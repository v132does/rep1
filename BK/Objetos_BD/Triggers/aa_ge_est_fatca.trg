CREATE OR REPLACE TRIGGER IT."AA_GE_EST_FATCA"
  AFTER DELETE OR UPDATE
     ON GE_EST_FATCA
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 22/10/2014 a las 14:30:08 Hs.
  */
  r_gaudi BA_AUDITORIAS%ROWTYPE; -- Registro de la tabla BA_AUDITORIAS
BEGIN
  r_gaudi.tabla := 'GE_EST_FATCA';
  r_gaudi.clave :=  :old.est_fatca;

  r_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    r_gaudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_gaudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  r_gaudi.detalle := pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'EST_FATCA', :old.est_fatca, :new.est_fatca );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'TIP_DOC_FATCA', :old.tip_doc_fatca, :new.tip_doc_fatca );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'PLZ_VENCIMIENTO', :old.plz_vencimiento, :new.plz_vencimiento , 'F');
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'PLZ_CADUCIDAD', :old.plz_caducidad, :new.plz_caducidad, 'F');
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'MSJ_NUE_ESTADO', :old.msj_nue_estado, :new.msj_nue_estado );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'IND_BLOQUEO', :old.ind_bloqueo, :new.ind_bloqueo );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'TIP_PERSONA', :old.tip_persona, :new.tip_persona );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'IND_EMI_MSJ_USUARIO', :old.ind_emi_msj_usuario, :new.ind_emi_msj_usuario );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'IND_ENV_MAIL', :old.ind_env_mail, :new.ind_env_mail );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'EST_EXP_VENCIMIENTO', :old.est_exp_vencimiento, :new.est_exp_vencimiento );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'EST_EXP_CADUCIDAD', :old.est_exp_caducidad, :new.est_exp_caducidad );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'COD_REPORTE', :old.cod_reporte, :new.cod_reporte );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'TIP_ESTADO', :old.tip_estado, :new.tip_estado );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'DESCRIPCION', :old.descripcion, :new.descripcion );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'TIP_TIT_CUENTA', :old.tip_tit_cuenta, :new.tip_tit_cuenta );


  -- Insertar tabla de auditoria
  pae_cnf.pr_ins_ba_auditoria( r_gaudi );
EXCEPTION
  when others then
    pae_cnf.pr_ins_ba_auditoria( r_gaudi );
END;
/

