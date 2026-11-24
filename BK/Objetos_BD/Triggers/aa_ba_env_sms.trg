CREATE OR REPLACE TRIGGER IT.AA_BA_ENV_SMS
  AFTER DELETE OR UPDATE
     ON BA_ENV_SMS
    FOR EACH ROW
DECLARE
  v_registro ba_auditorias%ROWTYPE; -- Registro de la tabla BA_AUDITORIAS

BEGIN
  v_registro.tabla := 'BA_ENV_SMS';
  v_registro.clave := :old.cod_persona;
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'ESTADO', :old.ESTADO, :new.ESTADO );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_ENVIO', :old.FEC_ENVIO, :new.FEC_ENVIO );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MSJ_ERROR', :old.MSJ_ERROR, :new.MSJ_ERROR );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'CEL_DESTINATARIO', :old.CEL_DESTINATARIO, :new.CEL_DESTINATARIO );

  -- Insertar tabla de auditoria
  pae_cnf.pr_ins_ba_auditoria( v_registro );
EXCEPTION
  when others then
    pae_cnf.pr_ins_ba_auditoria( v_registro );
END;
/

