CREATE OR REPLACE TRIGGER IT.AA_WF_CIR_TAREAS
  AFTER DELETE OR UPDATE
     ON IT.WF_CIR_TAREAS
    FOR EACH ROW
DECLARE
  r_gaudi WF_AUDITORIAS%ROWTYPE; -- Registro de la tabla BA_AUDITORIAS
BEGIN
  r_gaudi.tabla := 'WF_CIR_TAREAS';
  r_gaudi.clave := to_char( :old.cod_circuito) || '#' || :old.cod_tarea;
  r_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    r_gaudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_gaudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  r_gaudi.detalle := pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'COD_TIP_CIRCUITO', :old.cod_tip_circuito, :new.cod_tip_circuito );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'COD_TIP_TAREA', :old.cod_tip_tarea, :new.cod_tip_tarea );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'DESCRIPCION', :old.descripcion, :new.descripcion );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'COMENTARIO', :old.comentario, :new.comentario );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'IND_ANEXO', :old.ind_anexo, :new.ind_anexo );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'ESTADO', :old.estado, :new.estado );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'FEC_ASIGNACION', :old.fec_asignacion, :new.fec_asignacion );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'FEC_FINALIZACION', :old.fec_finalizacion, :new.fec_finalizacion );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'COD_GRU_RESPONSABLE', :old.cod_gru_responsable, :new.cod_gru_responsable );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'COD_CAUSA', :old.cod_causa, :new.cod_causa );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'COD_USU_RESPONSABLE', :old.cod_usu_responsable, :new.cod_usu_responsable );      
  -- Insertar tabla de auditoria
  prw_ins_wf_auditoria( r_gaudi );
EXCEPTION
  when others then
   prw_ins_wf_auditoria( r_gaudi );
END;
/
