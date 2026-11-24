CREATE OR REPLACE TRIGGER IT.AA_BA_PER_DOC_CHECKLIST
  AFTER DELETE OR UPDATE
     ON it.BA_PER_DOC_CHECKLIST
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 30/11/2022 a las 11:02:31 Hs.
  */
  v_registro BA_AUDITORIAS%ROWTYPE; -- Registro de la tabla BA_AUDITORIAS
BEGIN
  v_registro.tabla := 'BA_PER_DOC_CHECKLIST';
  v_registro.clave := :old.cod_persona || '#' || :old.cod_tip_documento;
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_EMISION', :old.fec_emision, :new.fec_emision, 'F' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_VENCIMIENTO', :old.fec_vencimiento, :new.fec_vencimiento, 'F' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'ESTADO', :old.estado, :new.estado );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TIENE', :old.tiene, :new.tiene );

  -- Insertar tabla de auditoria
    pae_cnf.pr_ins_ba_auditoria(v_registro);
EXCEPTION
  when others then
    pae_cnf.pr_ins_ba_auditoria(v_registro);
END;
/

