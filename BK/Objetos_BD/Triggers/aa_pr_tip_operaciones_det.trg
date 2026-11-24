CREATE OR REPLACE TRIGGER IT.AA_PR_TIP_OPERACIONES_DET
  AFTER DELETE OR UPDATE
     ON PR_TIP_OPERACIONES_DET
    FOR EACH ROW
DECLARE
  v_registro PR_AUDITORIAS%ROWTYPE; 
BEGIN
  v_registro.tabla := 'PR_TIP_OPERACIONES_DET';
  v_registro.clave := :old.cod_tip_operacion || '#' || :old.cod_periodo;
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  --- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'DESCRIPCION', :old.descripcion, :new.descripcion );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_MONEDA', :old.cod_moneda, :new.cod_moneda );

  -- Insertar tabla de auditoria
  prp_ins_pr_auditoria( v_registro );
EXCEPTION
  when others then
    prp_ins_pr_auditoria( v_registro );
END;
/

