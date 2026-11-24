CREATE OR REPLACE TRIGGER IT.AA_LC_RES_OPERACIONES
  AFTER DELETE OR UPDATE
     ON LC_RES_OPERACIONES
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoria
  || (c) 2005 - IT Consultores
  || Generado el 18/10/2006 a las 17:36:54 Hs.
  */
  v_registro LC_AUDITORIAS%ROWTYPE; -- Registro de la tabla LC_AUDITORIAS
BEGIN
  v_registro.tabla := 'LC_RES_OPERACIONES';
  v_registro.clave := to_char( :old.cod_ofi_cambio) || '#' || :old.cod_moneda || '#' || :old.tip_moneda;
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_MON_NUMERICO', :old.cod_mon_numerico, :new.cod_mon_numerico, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_MODULO', :old.cod_modulo, :new.cod_modulo, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COT_ANTERIOR', :old.cot_anterior, :new.cot_anterior, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COT_ACTUAL', :old.cot_actual, :new.cot_actual, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_ACTIVIDAD', :old.cod_actividad, :new.cod_actividad, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MTO_POS_ANTERIOR', :old.mto_pos_anterior, :new.mto_pos_anterior, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MTO_SOB_COM_ANT', :old.mto_sob_com_ant, :new.mto_sob_com_ant, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MTO_SOB_VTA_ANT', :old.mto_sob_vta_ant, :new.mto_sob_vta_ant, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MTO_SOB_COM_LOC_ANT', :old.mto_sob_com_loc_ant, :new.mto_sob_com_loc_ant, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MTO_SOB_VTA_LOC_ANT', :old.mto_sob_vta_loc_ant, :new.mto_sob_vta_loc_ant, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MTO_COMPRA', :old.mto_compra, :new.mto_compra, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COT_COMPRA', :old.cot_compra, :new.cot_compra, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MTO_COM_LOCAL', :old.mto_com_local, :new.mto_com_local, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MTO_VENTA', :old.mto_venta, :new.mto_venta, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COT_VENTA', :old.cot_venta, :new.cot_venta, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MTO_VTA_LOCAL', :old.mto_vta_local, :new.mto_vta_local, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MTO_POS_ACTUAL', :old.mto_pos_actual, :new.mto_pos_actual, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MTO_POS_COMPRA', :old.mto_pos_compra, :new.mto_pos_compra, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MTO_POS_VENTA', :old.mto_pos_venta, :new.mto_pos_venta, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MTO_POS_DIA_REAL', :old.mto_pos_dia_real, :new.mto_pos_dia_real, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MTO_POS_COM_NETO', :old.mto_pos_com_neto, :new.mto_pos_com_neto, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MTO_POS_VTA_NETO', :old.mto_pos_vta_neto, :new.mto_pos_vta_neto, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_RUB_ECONOMICO', :old.cod_rub_economico, :new.cod_rub_economico );
  
  -- Insertar tabla de auditoria
  prl_ins_lc_auditoria( v_registro );
EXCEPTION
  when others then
    prl_ins_lc_auditoria( v_registro );
END;
/

