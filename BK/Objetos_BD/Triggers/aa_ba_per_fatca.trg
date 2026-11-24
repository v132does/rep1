CREATE OR REPLACE TRIGGER IT.AA_BA_PER_FATCA
  AFTER DELETE OR UPDATE
     ON BA_PER_FATCA
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 19/09/2013 a las 15:18:17 Hs.
  */
  r_gaudi BA_AUDITORIAS%ROWTYPE; -- Registro de la tabla BA_AUDITORIAS
BEGIN
  r_gaudi.tabla := 'BA_PER_FATCA';
  r_gaudi.clave := :old.cod_persona;
  r_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    r_gaudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_gaudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  r_gaudi.detalle := pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'COD_PAIS', :old.cod_pais, :new.cod_pais, 'N' );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'ESTADO', :old.estado, :new.estado );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'EST_ANTERIOR', :old.est_anterior, :new.est_anterior );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'NRO_IDENTIFICADOR', :old.nro_identificador, :new.nro_identificador );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'TIP_DOCUMENTO', :old.tip_documento, :new.tip_documento );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'FEC_VENCIMIENTO', :old.fec_vencimiento, :new.fec_vencimiento, 'F' );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'FEC_CADUCIDAD', :old.fec_caducidad, :new.fec_caducidad, 'F' );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'OBSERVACION', :old.observacion, :new.observacion );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'IND_BLOQUEO', :old.ind_bloqueo, :new.ind_bloqueo );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'TIP_ACTUALIZACION', :old.tip_actualizacion, :new.tip_actualizacion );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'TIP_INDICIO', :old.tip_indicio, :new.tip_indicio );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'PRO_ACTUALIZACION', :old.pro_actualizacion, :new.pro_actualizacion );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'FEC_ULT_ACT_ESTADO', :old.fec_ult_act_estado, :new.fec_ult_act_estado );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'USU_ULT_ACT_ESTADO', :old.usu_ult_act_estado, :new.usu_ult_act_estado );      
  -- Insertar tabla de auditoria
  pae_cnf.pr_ins_ba_auditoria( r_gaudi );
EXCEPTION
  when others then
    pae_cnf.pr_ins_ba_auditoria( r_gaudi );
END;
/

