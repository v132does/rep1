CREATE OR REPLACE TRIGGER IT.AA_TA_SOL_ADICIONALES
  AFTER DELETE OR UPDATE
     ON TA_SOL_ADICIONALES
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 03/05/2013 a las 13:04:27 Hs.
  */
  r_taudi TA_AUDITORIAS%ROWTYPE; -- Registro de la tabla TA_AUDITORIAS
BEGIN
  r_taudi.tabla := 'TA_SOL_ADICIONALES';
  r_taudi.clave := to_char( :old.nro_solicitud) || '#' || :old.cod_persona;
  r_taudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    r_taudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_taudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  r_taudi.detalle := pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'FEC_APROBACION', :old.fec_aprobacion, :new.fec_aprobacion, 'F' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'FEC_INGRESO', :old.fec_ingreso, :new.fec_ingreso, 'F' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_USU_AUTORIZA', :old.cod_usu_autoriza, :new.cod_usu_autoriza );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_USU_PROMOTOR', :old.cod_usu_promotor, :new.cod_usu_promotor );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'NOM_EMBOZADO', :old.nom_embozado, :new.nom_embozado );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_USU_OFICIAL', :old.cod_usu_oficial, :new.cod_usu_oficial );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_CAUSA', :old.cod_causa, :new.cod_causa, 'N' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'OBSERVACION', :old.observacion, :new.observacion );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'NIV_APROBACION', :old.niv_aprobacion, :new.niv_aprobacion );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_ESTADO', :old.cod_estado, :new.cod_estado );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'NRO_ACTA', :old.nro_acta, :new.nro_acta, 'N' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'NRO_CUENTA', :old.nro_cuenta, :new.nro_cuenta );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'PLA_OPE_POR_CONTADO', :old.pla_ope_por_contado, :new.pla_ope_por_contado, 'M' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'PLA_OPE_MTO_CONTADO', :old.pla_ope_mto_contado, :new.pla_ope_mto_contado, 'M' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'PLA_OPE_MTO_ADELANTO', :old.pla_ope_mto_adelanto, :new.pla_ope_mto_adelanto, 'M' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'PLA_OPE_POR_ADELANTO', :old.pla_ope_por_adelanto, :new.pla_ope_por_adelanto, 'M' );

  -- Insertar tabla de auditoria
  prt_ins_ta_auditoria( r_taudi );
EXCEPTION
  when others then
    prt_ins_ta_auditoria( r_taudi );
END;
/

