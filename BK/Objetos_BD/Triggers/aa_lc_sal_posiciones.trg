CREATE OR REPLACE TRIGGER IT.AA_LC_SAL_POSICIONES
  AFTER DELETE OR UPDATE
     ON LC_SAL_POSICIONES
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 18/10/2006 a las 17:37:26 Hs.
  */
  v_registro LC_AUDITORIAS%ROWTYPE; -- Registro de la tabla LC_AUDITORIAS
BEGIN
  v_registro.tabla := 'LC_SAL_POSICIONES';
  v_registro.clave := to_char( :old.cod_ofi_cambio) || '#' || :old.cod_moneda || '#' || :old.tip_posicion;
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MTO_EFE_COMPRA', :old.mto_efe_compra, :new.mto_efe_compra, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MTO_EFE_VENTA', :old.mto_efe_venta, :new.mto_efe_venta, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MTO_NEF_COMPRA', :old.mto_nef_compra, :new.mto_nef_compra, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MTO_NEF_VENTA', :old.mto_nef_venta, :new.mto_nef_venta, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COT_EFECTIVO', :old.cot_efectivo, :new.cot_efectivo, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COT_NO_EFECTIVO', :old.cot_no_efectivo, :new.cot_no_efectivo, 'N' );

  -- Insertar tabla de auditoria
  prl_ins_lc_auditoria( v_registro );
EXCEPTION
  when others then
    prl_ins_lc_auditoria( v_registro );
END;
/

