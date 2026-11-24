CREATE OR REPLACE TRIGGER IT.AA_GE_ONB_VERIFICADOS
  AFTER DELETE OR UPDATE
     ON IT.GE_ONB_VERIFICADOS
    FOR EACH ROW
DECLARE
  v_registro  ge_auditorias%rowtype; -- Registro de la tabla GE_AUDITORIAS
BEGIN
  v_registro.tabla := 'GE_ONB_VERIFICADOS';
  v_registro.clave := :old.id;
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'ID', :old.id, :new.id );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_DOCUMENTO', :old.nro_documento, :new.nro_documento );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_INTENTO', :old.nro_intento, :new.nro_intento );
  --- Insertar tabla de auditoria
  prg_ins_ge_auditoria( v_registro );
EXCEPTION
  when others then
       prg_ins_ge_auditoria( v_registro );
END;
/
