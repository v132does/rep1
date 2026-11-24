CREATE OR REPLACE TRIGGER IT.AA_PR_TAS_VARIABLES_DET
  AFTER DELETE OR UPDATE
     ON PR_TAS_VARIABLES_DET
    FOR EACH ROW
DECLARE
  v_registro PR_AUDITORIAS%ROWTYPE; 
BEGIN
  v_registro.tabla := 'PR_TAS_VARIABLES_DET';
  v_registro.clave := to_char( :old.nro_solicitud) || '#' || to_char( :old.nro_cuota);
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  --- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_PERIODO', :old.cod_periodo, :new.cod_periodo );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MTO_CAPITAL', :old.mto_capital, :new.mto_capital, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_VENCIMIENTO', :old.fec_vencimiento, :new.fec_vencimiento, 'F' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MTO_INTERES', :old.mto_interes, :new.mto_interes, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'SAL_CAPITAL', :old.sal_capital, :new.sal_capital, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'SAL_INTERES', :old.sal_interes, :new.sal_interes, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'VAL_RECARGO', :old.val_recargo, :new.val_recargo, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MTO_INT_DOCUMENTADO', :old.mto_int_documentado, :new.mto_int_documentado, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'VALOR_CUOTA', :old.valor_cuota, :new.valor_cuota, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'RENEGOCIACION', :old.renegociacion, :new.renegociacion );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TAS_REFERENCIA', :old.tas_referencia, :new.tas_referencia, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TAS_UTILIZADA', :old.tas_utilizada, :new.tas_utilizada, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'DIA', :old.dia, :new.dia );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'VAL_INT_ADELANTADO', :old.val_int_adelantado, :new.val_int_adelantado, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'VAL_INTERES', :old.val_interes, :new.val_interes, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'VAL_INT_ORIGINAL', :old.val_int_original, :new.val_int_original, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MTO_CARGO', :old.mto_cargo, :new.mto_cargo, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TOT_CUOTA', :old.tot_cuota, :new.tot_cuota, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_RENEGOCIACION', :old.fec_renegociacion, :new.fec_renegociacion, 'F' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'SPREAD', :old.spread, :new.spread, 'M' );

  -- Insertar tabla de auditoria
  prp_ins_pr_auditoria( v_registro );
EXCEPTION
  when others then
    prp_ins_pr_auditoria( v_registro );
END;
/

