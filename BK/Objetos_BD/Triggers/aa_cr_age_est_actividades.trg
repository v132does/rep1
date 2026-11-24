CREATE OR REPLACE TRIGGER IT.AA_CR_AGE_EST_ACTIVIDADES
 AFTER DELETE OR UPDATE
 ON CR_AGE_EST_ACTIVIDADES
 FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 15/07/2005 a las 17:31:38 Hs.
  */
  v_registro CR_AUDITORIAS%ROWTYPE; -- Registro de la tabla CR_AUDITORIAS
BEGIN
  v_registro.tabla := 'CR_AGE_EST_ACTIVIDADES';
  v_registro.clave := to_char( :old.cod_actividad ) || '#' || to_char( :old.cod_estado );
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'DESCRIPCION', :old.descripcion, :new.descripcion );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'GRUPO', :old.grupo, :new.grupo );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'IND_REPROGRAMACION', :old.ind_reprogramacion, :new.ind_reprogramacion );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'IND_REASIGNACION', :old.ind_reasignacion, :new.ind_reasignacion );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'IND_CANCELACION', :old.ind_cancelacion, :new.ind_cancelacion );

  -- Insertar tabla de auditoria
  prr_ins_cr_auditoria( v_registro );
EXCEPTION
  when others then
    prr_ins_cr_auditoria( v_registro );
END;
/

