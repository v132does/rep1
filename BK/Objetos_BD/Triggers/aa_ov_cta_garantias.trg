CREATE OR REPLACE TRIGGER IT.AA_OV_CTA_GARANTIAS
  AFTER DELETE OR UPDATE
     ON OV_CTA_GARANTIAS
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 19/10/2007 a las 08:59:42 Hs.
  */
  v_registro OV_AUDITORIAS%ROWTYPE; -- Registro de la tabla OV_AUDITORIAS
BEGIN
  v_registro.tabla := 'OV_CTA_GARANTIAS';
  v_registro.clave := :old.nro_cuenta || '#' || to_char( :old.nro_garantia) || '#' || to_char( :old.cod_garantia);
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MTO_APLICADO', :old.mto_aplicado, :new.mto_aplicado, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MTO_APL_COMPUTABLE', :old.mto_apl_computable, :new.mto_apl_computable, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MTO_CON_COMPUTABLE', :old.mto_con_computable, :new.mto_con_computable, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MTO_CON_NOCOMPUTABLE', :old.mto_con_nocomputable, :new.mto_con_nocomputable, 'M' );

  -- Insertar tabla de auditoria
  prv_ins_ov_auditoria( v_registro );
EXCEPTION
  when others then
    prv_ins_ov_auditoria( v_registro );
END;
/

