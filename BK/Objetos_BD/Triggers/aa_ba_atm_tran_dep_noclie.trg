CREATE OR REPLACE TRIGGER IT.AA_BA_ATM_TRAN_DEP_NOCLIE
  AFTER DELETE OR UPDATE
     ON "IT"."BA_ATM_TRAN_DEP_NOCLIE"
    FOR EACH ROW
DECLARE
  v_registro ba_auditorias%ROWTYPE; -- Registro de la tabla BA_AUDITORIAS

BEGIN
  v_registro.tabla := 'BA_ATM_TRAN_DEP_NOCLIE';
  v_registro.clave := :old.NRO_DOCUMENTO;
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_DOCUMENTO', :old.NRO_DOCUMENTO, :new.NRO_DOCUMENTO );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_TRANSACCION', :old.NRO_TRANSACCION, :new.NRO_TRANSACCION );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'ATM_NOM', :old.ATM_NOM, :new.ATM_NOM );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_TRANSACCION', :old.FEC_TRANSACCION, :new.FEC_TRANSACCION );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TIP_DEPOSITO', :old.TIP_DEPOSITO, :new.TIP_DEPOSITO );

  -- Insertar tabla de auditoria
  pae_cnf.pr_ins_ba_auditoria( v_registro );
EXCEPTION
  when others then
    pae_cnf.pr_ins_ba_auditoria( v_registro );
END;
/

