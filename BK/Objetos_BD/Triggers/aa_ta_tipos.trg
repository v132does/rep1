CREATE OR REPLACE TRIGGER IT.AA_TA_TIPOS
  AFTER DELETE OR UPDATE
     ON TA_TIPOS
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 06/05/2013 a las 12:52:42 Hs.
  */
  r_taudi TA_AUDITORIAS%ROWTYPE; -- Registro de la tabla TA_AUDITORIAS
BEGIN
  r_taudi.tabla := 'TA_TIPOS';
  r_taudi.clave := to_char( :old.cod_modulo) || '#' || to_char( :old.cod_modalidad) || '#' || :old.afinidad || '#' || :old.sub_afinidad || '#' || to_char( :old.nro_bin);
  r_taudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    r_taudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_taudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  r_taudi.detalle := pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_TIP_TARJETA', :old.cod_tip_tarjeta, :new.cod_tip_tarjeta );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'DESCRIPCION', :old.descripcion, :new.descripcion );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_ENT_PROCESADORA', :old.cod_ent_procesadora, :new.cod_ent_procesadora, 'N' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_TIP_CIERRE', :old.cod_tip_cierre, :new.cod_tip_cierre, 'N' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'TIP_COBRO', :old.tip_cobro, :new.tip_cobro );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'TIP_TAS_FINANCIACION', :old.tip_tas_financiacion, :new.tip_tas_financiacion );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'TIP_COM_EMISION', :old.tip_com_emision, :new.tip_com_emision );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'TIP_GAS_FINANCIERO', :old.tip_gas_financiero, :new.tip_gas_financiero );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'TIP_GENERACION', :old.tip_generacion, :new.tip_generacion );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'TIP_CUENTA', :old.tip_cuenta, :new.tip_cuenta );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'CTA_VIP', :old.cta_vip, :new.cta_vip );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'CTA_PERSONALIZADA', :old.cta_personalizada, :new.cta_personalizada );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'PLZ_DUR_TARJETA', :old.plz_dur_tarjeta, :new.plz_dur_tarjeta, 'N' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'FRANQUEO', :old.franqueo, :new.franqueo );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_CAMPANA', :old.cod_campana, :new.cod_campana, 'N' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_OFICINA', :old.cod_oficina, :new.cod_oficina, 'N' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'SIG_NRO_CUENTA', :old.sig_nro_cuenta, :new.sig_nro_cuenta, 'N' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'TIP_ALCANCE', :old.tip_alcance, :new.tip_alcance );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'REF_EXTERNA', :old.ref_externa, :new.ref_externa, 'N' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'MIN_LINEA', :old.min_linea, :new.min_linea, 'M' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'MAX_LINEA', :old.max_linea, :new.max_linea, 'M' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'EXO_PAQUETE', :old.exo_paquete, :new.exo_paquete );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'AFE_EMPLEADO', :old.afe_empleado, :new.afe_empleado );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'MTO_CUO_ANUAL', :old.mto_cuo_anual, :new.mto_cuo_anual );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'CAN_CUO_ANUAL', :old.can_cuo_anual, :new.can_cuo_anual );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'POR_EXO_CUO_ANUAL', :old.por_exo_cuo_anual, :new.por_exo_cuo_anual );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'TAS_PERSONALIZADA', :old.tas_personalizada, :new.tas_personalizada );
  -- Insertar tabla de auditoria
  prt_ins_ta_auditoria( r_taudi );
EXCEPTION
  when others then
    prt_ins_ta_auditoria( r_taudi );
END;
/

