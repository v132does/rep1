CREATE OR REPLACE TRIGGER IT.AA_CR_REC_ESTADOS
  AFTER DELETE OR UPDATE
     ON CR_REC_ESTADOS
    FOR EACH ROW


DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoria
  || (c) 2005 - IT Consultores
  || Generado el 15/07/2005 a las 17:28:09 Hs.
  */
  v_registro CR_AUDITORIAS%ROWTYPE; -- Registro de la tabla CR_AUDITORIAS
BEGIN
  v_registro.tabla := 'CR_REC_ESTADOS';
  v_registro.clave := to_char( :old.cod_reclamo ) || '#' || to_char( :old.cod_rec_estado );
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'DESCRIPCION', :old.descripcion, :new.descripcion );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'GRUPO', :old.grupo, :new.grupo );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_ACTIVIDAD', :old.cod_actividad, :new.cod_actividad, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_ESTADO', :old.cod_estado, :new.cod_estado, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'IND_REPROGRAMACION', :old.ind_reprogramacion, :new.ind_reprogramacion );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'IND_REASIGNACION', :old.ind_reasignacion, :new.ind_reasignacion );

  -- Insertar tabla de auditoria
  prr_ins_cr_auditoria( v_registro );
EXCEPTION
  when others then
    prr_ins_cr_auditoria( v_registro );
END;
/

