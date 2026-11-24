CREATE OR REPLACE TRIGGER IT.AA_GE_COB_SERVICIOS_RES
  AFTER DELETE OR UPDATE
     ON GE_COB_SERVICIOS_RES
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 25/10/2006 a las 14:27:45 Hs.
  */
  v_registro GE_AUDITORIAS%ROWTYPE; -- Registro de la tabla GE_AUDITORIAS
BEGIN
  v_registro.tabla := 'GE_COB_SERVICIOS_RES';
  v_registro.clave := to_char( :old.cod_servicio) || '#' || to_char( :old.fec_remision, 'DD/MM/YYYY HH24:MI:SS') || '#' || to_char( :old.nro_remision);
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'CANTIDAD', :old.cantidad, :new.cantidad, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_MONEDA', :old.cod_moneda, :new.cod_moneda );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TOT_MONTO', :old.tot_monto, :new.tot_monto, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TOT_DEBITO', :old.tot_debito, :new.tot_debito, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TOT_EFECTIVO', :old.tot_efectivo, :new.tot_efectivo, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TOT_CHE_NUE_BANCO', :old.tot_che_nue_banco, :new.tot_che_nue_banco, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TOT_CHE_OTR_BANCO', :old.tot_che_otr_banco, :new.tot_che_otr_banco, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TOT_COMISION', :old.tot_comision, :new.tot_comision, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TOT_IMPUESTO', :old.tot_impuesto, :new.tot_impuesto, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'VAL_TAS_COMISION', :old.val_tas_comision, :new.val_tas_comision, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'VAL_TAS_IMPUESTO', :old.val_tas_impuesto, :new.val_tas_impuesto, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_OFI_ORIGEN', :old.cod_ofi_origen, :new.cod_ofi_origen, 'N' );

  -- Insertar tabla de auditoria
  prg_ins_ge_auditoria( v_registro );
EXCEPTION
  when others then
    prg_ins_ge_auditoria( v_registro );
END;
/

