CREATE OR REPLACE TRIGGER IT.AA_OV_CTA_VENCIDAS
  AFTER DELETE OR UPDATE
     ON OV_CTA_VENCIDAS
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 07/06/2013 a las 11:37:38 Hs.
  */
  r_vaudi OV_AUDITORIAS%ROWTYPE; -- Registro de la tabla OV_AUDITORIAS
BEGIN
  r_vaudi.tabla := 'OV_CTA_VENCIDAS';
  r_vaudi.clave := :old.nro_cuenta;
  r_vaudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    r_vaudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_vaudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  r_vaudi.detalle := pae_cnf.fu_reg_auditoria( r_vaudi.tip_novedad, 'COD_MODULO', :old.cod_modulo, :new.cod_modulo, 'N' );
  r_vaudi.detalle := r_vaudi.detalle || pae_cnf.fu_reg_auditoria( r_vaudi.tip_novedad, 'COD_MODALIDAD', :old.cod_modalidad, :new.cod_modalidad, 'N' );
  r_vaudi.detalle := r_vaudi.detalle || pae_cnf.fu_reg_auditoria( r_vaudi.tip_novedad, 'COD_OFICINA', :old.cod_oficina, :new.cod_oficina, 'N' );
  r_vaudi.detalle := r_vaudi.detalle || pae_cnf.fu_reg_auditoria( r_vaudi.tip_novedad, 'NRO_CTA_ORIGEN', :old.nro_cta_origen, :new.nro_cta_origen );
  r_vaudi.detalle := r_vaudi.detalle || pae_cnf.fu_reg_auditoria( r_vaudi.tip_novedad, 'COD_MONEDA', :old.cod_moneda, :new.cod_moneda );
  r_vaudi.detalle := r_vaudi.detalle || pae_cnf.fu_reg_auditoria( r_vaudi.tip_novedad, 'DENOMINACION', :old.denominacion, :new.denominacion );
  r_vaudi.detalle := r_vaudi.detalle || pae_cnf.fu_reg_auditoria( r_vaudi.tip_novedad, 'FEC_APERTURA', :old.fec_apertura, :new.fec_apertura, 'F' );
  r_vaudi.detalle := r_vaudi.detalle || pae_cnf.fu_reg_auditoria( r_vaudi.tip_novedad, 'ESTADO', :old.estado, :new.estado );
  r_vaudi.detalle := r_vaudi.detalle || pae_cnf.fu_reg_auditoria( r_vaudi.tip_novedad, 'FEC_CAM_ESTADO', :old.fec_cam_estado, :new.fec_cam_estado, 'F' );
  r_vaudi.detalle := r_vaudi.detalle || pae_cnf.fu_reg_auditoria( r_vaudi.tip_novedad, 'FEC_ULT_MOVIMIENTO', :old.fec_ult_movimiento, :new.fec_ult_movimiento, 'F' );
  r_vaudi.detalle := r_vaudi.detalle || pae_cnf.fu_reg_auditoria( r_vaudi.tip_novedad, 'HOR_ULT_MOVIMIENTO', :old.hor_ult_movimiento, :new.hor_ult_movimiento );
  r_vaudi.detalle := r_vaudi.detalle || pae_cnf.fu_reg_auditoria( r_vaudi.tip_novedad, 'MTO_ORIGEN', :old.mto_origen, :new.mto_origen, 'M' );
  r_vaudi.detalle := r_vaudi.detalle || pae_cnf.fu_reg_auditoria( r_vaudi.tip_novedad, 'SAL_TOT_BATCH', :old.sal_tot_batch, :new.sal_tot_batch, 'M' );
  r_vaudi.detalle := r_vaudi.detalle || pae_cnf.fu_reg_auditoria( r_vaudi.tip_novedad, 'DIA_ATRASO', :old.dia_atraso, :new.dia_atraso, 'N' );
  r_vaudi.detalle := r_vaudi.detalle || pae_cnf.fu_reg_auditoria( r_vaudi.tip_novedad, 'DIA_ATR_INICIAL', :old.dia_atr_inicial, :new.dia_atr_inicial, 'N' );
  r_vaudi.detalle := r_vaudi.detalle || pae_cnf.fu_reg_auditoria( r_vaudi.tip_novedad, 'DIG_VERIFICADOR', :old.dig_verificador, :new.dig_verificador, 'N' );
  r_vaudi.detalle := r_vaudi.detalle || pae_cnf.fu_reg_auditoria( r_vaudi.tip_novedad, 'FEC_INI_MORA', :old.fec_ini_mora, :new.fec_ini_mora, 'F' );
  r_vaudi.detalle := r_vaudi.detalle || pae_cnf.fu_reg_auditoria( r_vaudi.tip_novedad, 'VAL_TASA', :old.val_tasa, :new.val_tasa, 'M' );
  r_vaudi.detalle := r_vaudi.detalle || pae_cnf.fu_reg_auditoria( r_vaudi.tip_novedad, 'EST_BATCH', :old.est_batch, :new.est_batch );
  r_vaudi.detalle := r_vaudi.detalle || pae_cnf.fu_reg_auditoria( r_vaudi.tip_novedad, 'EN_JUICIO', :old.en_juicio, :new.en_juicio );
  r_vaudi.detalle := r_vaudi.detalle || pae_cnf.fu_reg_auditoria( r_vaudi.tip_novedad, 'FEC_JUICIO', :old.fec_juicio, :new.fec_juicio, 'F' );
  r_vaudi.detalle := r_vaudi.detalle || pae_cnf.fu_reg_auditoria( r_vaudi.tip_novedad, 'COD_ENT_JUICIO', :old.cod_ent_juicio, :new.cod_ent_juicio, 'N' );
  r_vaudi.detalle := r_vaudi.detalle || pae_cnf.fu_reg_auditoria( r_vaudi.tip_novedad, 'EST_ANTERIOR', :old.est_anterior, :new.est_anterior );
  r_vaudi.detalle := r_vaudi.detalle || pae_cnf.fu_reg_auditoria( r_vaudi.tip_novedad, 'SAL_TOTAL', :old.sal_total, :new.sal_total, 'M' );
  r_vaudi.detalle := r_vaudi.detalle || pae_cnf.fu_reg_auditoria( r_vaudi.tip_novedad, 'SAL_ANTERIOR', :old.sal_anterior, :new.sal_anterior, 'M' );
  r_vaudi.detalle := r_vaudi.detalle || pae_cnf.fu_reg_auditoria( r_vaudi.tip_novedad, 'COD_RUB_ECONOMICO', :old.cod_rub_economico, :new.cod_rub_economico );
  r_vaudi.detalle := r_vaudi.detalle || pae_cnf.fu_reg_auditoria( r_vaudi.tip_novedad, 'NRO_SOL_RENOVADA', :old.nro_sol_renovada, :new.nro_sol_renovada, 'N' );
  r_vaudi.detalle := r_vaudi.detalle || pae_cnf.fu_reg_auditoria( r_vaudi.tip_novedad, 'NRO_CTA_RENOVADA', :old.nro_cta_renovada, :new.nro_cta_renovada );

  -- Insertar tabla de auditoria
  prv_ins_ov_auditoria( r_vaudi );
EXCEPTION
  when others then
    prv_ins_ov_auditoria( r_vaudi );
END;
/

