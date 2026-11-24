CREATE OR REPLACE TRIGGER IT.AA_CX_CTA_GARANTIAS
 AFTER DELETE OR UPDATE
 ON CX_CTA_GARANTIAS
 REFERENCING OLD AS OLD NEW AS NEW
 FOR EACH ROW
DECLARE

  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 19/08/2005 a las 11:39:43 Hs.
  */
  v_registro CX_AUDITORIAS%ROWTYPE; -- Registro de la tabla CE_AUDITORIAS
BEGIN
  v_registro.tabla := 'CX_CTA_GARANTIAS';
  v_registro.clave := :old.nro_cuenta||'#'||:old.nro_garantia||'#'||:old.cod_garantia;
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_CUENTA', :old.nro_cuenta, :new.nro_cuenta );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_GARANTIA', :old.nro_garantia, :new.nro_garantia );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_GARANTIA', :old.cod_garantia, :new.cod_garantia, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MTO_APLICADO', :old.mto_aplicado, :new.mto_aplicado, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MTO_APL_COMPUTABLE', :old.mto_apl_computable, :new.mto_apl_computable, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MTO_CON_COMPUTABLE', :old.mto_con_computable, :new.mto_con_computable, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MTO_CON_NOCOMPUTABLE', :old.mto_con_nocomputable, :new.mto_con_nocomputable, 'M' );

  -- Insertar tabla de auditoria
  prx_ins_cX_auditoria( v_registro );
EXCEPTION
  when others then
    prx_ins_cX_auditoria( v_registro );
END;
/

