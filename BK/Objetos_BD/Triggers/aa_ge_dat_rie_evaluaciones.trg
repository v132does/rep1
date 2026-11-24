CREATE OR REPLACE TRIGGER IT.AA_GE_DAT_RIE_EVALUACIONES
  AFTER DELETE OR UPDATE
     ON GE_DAT_RIE_EVALUACIONES
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 13/04/2012 a las 09:41:43 Hs.
  */
  r_baudi GE_AUDITORIAS%ROWTYPE; -- Registro de la tabla GE_AUDITORIAS
BEGIN
  r_baudi.tabla := 'GE_DAT_RIE_EVALUACIONES';
  r_baudi.clave := to_char( :old.nro_solicitud) || '#' || to_char( :old.nro_intento);
  r_baudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    r_baudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_baudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  r_baudi.detalle := pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'COD_FLUJO', :old.cod_flujo, :new.cod_flujo );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'RESERVADO', :old.reservado, :new.reservado );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'NIVEL', :old.nivel, :new.nivel );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'DIC_PER_FINAL', :old.dic_per_final, :new.dic_per_final );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'DIC_FINAL', :old.dic_final, :new.dic_final );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'DIC_BUR_FINAL', :old.dic_bur_final, :new.dic_bur_final );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'MTO_RECONDUCIDO', :old.mto_reconducido, :new.mto_reconducido, 'M' );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'COD_MONEDA', :old.cod_moneda, :new.cod_moneda );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'LIM_MAX_OPERACION', :old.lim_max_operacion, :new.lim_max_operacion, 'M' );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'PLAZO', :old.plazo, :new.plazo, 'N' );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'TAS_MTO_RECONDUCIDO', :old.tas_mto_reconducido, :new.tas_mto_reconducido, 'N' );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'COD_PERSONA', :old.cod_persona, :new.cod_persona );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'COD_MODULO', :old.cod_modulo, :new.cod_modulo, 'N' );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'VER_FLUJO', :old.ver_flujo, :new.ver_flujo );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'ESTADO', :old.estado, :new.estado );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'COD_MODALIDAD', :old.cod_modalidad, :new.cod_modalidad, 'N' );

  -- Insertar tabla de auditoria
  prg_ins_ge_auditoria( r_baudi );
EXCEPTION
  when others then
    prg_ins_ge_auditoria( r_baudi );
END;
/

