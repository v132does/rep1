CREATE OR REPLACE TRIGGER IT.AA_WF_CIRCUITOS
  AFTER DELETE OR UPDATE
     ON IT.WF_CIRCUITOS
    FOR EACH ROW
DECLARE
  r_gaudi WF_AUDITORIAS%ROWTYPE; -- Registro de la tabla BA_AUDITORIAS
BEGIN
  r_gaudi.tabla := 'WF_CIRCUITOS';
  r_gaudi.clave := to_char( :old.cod_circuito) || '#' || :old.cod_tip_circuito;
  r_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    r_gaudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_gaudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  r_gaudi.detalle := pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'FEC_INICIO', :old.fec_inicio, :new.fec_inicio );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'REFERENCIA', :old.referencia, :new.referencia );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'COD_TAR_ACTUAL', :old.cod_tar_actual, :new.cod_tar_actual );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'DESCRIPCION', :old.descripcion, :new.descripcion );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'ESTADO', :old.estado, :new.estado);
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'IND_ANEXO', :old.ind_anexo, :new.ind_anexo );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'FEC_FIN', :old.fec_fin, :new.fec_fin );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'COD_PERSONA', :old.cod_persona, :new.cod_persona );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'COD_GRU_RES_ACTUAL', :old.cod_gru_res_actual, :new.cod_gru_res_actual );

  -- Insertar tabla de auditoria
  prw_ins_wf_auditoria( r_gaudi );
EXCEPTION
  when others then
   prw_ins_wf_auditoria( r_gaudi );
END;
/
