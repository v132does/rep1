CREATE OR REPLACE TRIGGER IT.AA_BW_TD_CONFIGURACIONES
AFTER DELETE OR UPDATE ON BW_TD_CONFIGURACIONES FOR EACH ROW
DECLARE
   v_registro BW_AUDITORIAS%ROWTYPE; -- Registro de la tabla BW_AUDITORIAS
BEGIN
  v_registro.tabla := 'BW_TD_CONFIGURACIONES';
  v_registro.clave := :old.cod_persona || '#' || :old.cod_per_vinculo || '#' || :old.tipo;
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'AUTORIZADOR', :old.autorizador, :new.autorizador );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TELEFONO', :old.telefono, :new.telefono );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'ENVIADO', :old.enviado, :new.enviado );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'REFERENCIA', :old.referencia, :new.referencia );

  -- Insertar tabla de auditoria
  prw_ins_bw_auditoria( v_registro );
EXCEPTION
  when others then
    prw_ins_bw_auditoria( v_registro );
END;
/

