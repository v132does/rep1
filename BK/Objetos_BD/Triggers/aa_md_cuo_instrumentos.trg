CREATE OR REPLACE TRIGGER IT.AA_MD_CUO_INSTRUMENTOS
  AFTER DELETE OR UPDATE
     ON MD_CUO_INSTRUMENTOS
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 21/07/2015 a las 16:20:11 Hs. 
  */
  v_registro MD_AUDITORIAS%ROWTYPE; -- Registro de la tabla MD_AUDITORIAS
  
BEGIN
  v_registro.tabla := 'MD_CUO_INSTRUMENTOS';
  v_registro.clave := :old.nro_cuenta || '#' || to_char( :old.nro_cuota);
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MTO_CUOTA', :old.mto_cuota, :new.mto_cuota, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'ESTADO', :old.estado, :new.estado );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_CTA_REPO', :old.nro_cta_repo, :new.nro_cta_repo );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'VAL_TAS_RENDIMIENTO', :old.val_tas_rendimiento, :new.val_tas_rendimiento, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MTO_PRESENTE', :old.mto_presente, :new.mto_presente, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'VAL_TAS_PORCENTAJE', :old.val_tas_porcentaje, :new.val_tas_porcentaje, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MTO_INTERES', :old.mto_interes, :new.mto_interes, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MTO_CON_DESCUENTO', :old.mto_con_descuento, :new.mto_con_descuento, 'M' );
  
  -- Insertar tabla de auditoria
  prm_ins_md_auditoria( v_registro );
EXCEPTION
  when others then
    prm_ins_md_auditoria( v_registro );
END;
/

