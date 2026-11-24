CREATE OR REPLACE TRIGGER IT.AA_CR_CAM_PERSONAS_HIS
 AFTER DELETE OR UPDATE
 ON CR_CAM_PERSONAS_HIS
 FOR EACH ROW

DECLARE
  r_raudi cr_auditorias%rowtype; -- Registro de la tabla CR_AUDITORIAS
BEGIN
  r_raudi.tabla := 'CR_CAM_PERSONAS_HIS';
  r_raudi.clave := to_char( :old.cod_campana ) || '#' || :old.cod_persona;
  r_raudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    r_raudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_raudi.tip_novedad := 'E';
  END IF;
  --- Registrar Detalle
  r_raudi.detalle := pae_cnf.fu_reg_auditoria( r_raudi.tip_novedad, 'FEC_HISTORIAL', :old.fec_historial, :new.fec_historial, 'F' );
  r_raudi.detalle := r_raudi.detalle || pae_cnf.fu_reg_auditoria( r_raudi.tip_novedad, 'COD_CAMPANA', :old.cod_campana, :new.cod_campana );
  r_raudi.detalle := r_raudi.detalle || pae_cnf.fu_reg_auditoria( r_raudi.tip_novedad, 'COD_PERSONA', :old.cod_persona, :new.cod_persona );
  r_raudi.detalle := r_raudi.detalle || pae_cnf.fu_reg_auditoria( r_raudi.tip_novedad, 'ESTADO', :old.estado, :new.estado );
  r_raudi.detalle := r_raudi.detalle || pae_cnf.fu_reg_auditoria( r_raudi.tip_novedad, 'COD_ESTADO_ACT', :old.cod_estado_act, :new.cod_estado_act );
  r_raudi.detalle := r_raudi.detalle || pae_cnf.fu_reg_auditoria( r_raudi.tip_novedad, 'DET_ACTIVIDAD', :old.det_actividad, :new.det_actividad );
  r_raudi.detalle := r_raudi.detalle || pae_cnf.fu_reg_auditoria( r_raudi.tip_novedad, 'FEC_ACTIVIDAD', :old.fec_actividad, :new.fec_actividad, 'F' );

  --- Insertar tabla de auditoria
  PRR_INS_CR_AUDITORIA(r_raudi);
END;
/

