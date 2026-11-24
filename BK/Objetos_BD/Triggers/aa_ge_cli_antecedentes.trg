CREATE OR REPLACE TRIGGER IT.AA_GE_CLI_ANTECEDENTES
  AFTER DELETE OR UPDATE
     ON GE_CLI_ANTECEDENTES
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 16/02/2012 a las 11:08:48 Hs.
  */
  r_baudi GE_AUDITORIAS%ROWTYPE; -- Registro de la tabla GE_AUDITORIAS
BEGIN
  r_baudi.tabla := 'GE_CLI_ANTECEDENTES';
  r_baudi.clave := :old.cod_persona;
  r_baudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    r_baudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_baudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  r_baudi.detalle := pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'FAJ_BURO', :old.faj_buro, :new.faj_buro );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'FEC_ULT_INFORMCONF', :old.fec_ult_informconf, :new.fec_ult_informconf, 'F' );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'SIT_INFOCHECK', :old.sit_infocheck, :new.sit_infocheck );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'FEC_ULT_INFOCHECK', :old.fec_ult_infocheck, :new.fec_ult_infocheck, 'F' );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'MTO_PAG_MINIMO', :old.mto_pag_minimo, :new.mto_pag_minimo, 'M' );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'DIA_ATRASO', :old.dia_atraso, :new.dia_atraso, 'N' );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'SIT_TARJETA', :old.sit_tarjeta, :new.sit_tarjeta );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'FEC_ULT_BANCARD', :old.fec_ult_bancard, :new.fec_ult_bancard, 'F' );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'DISPUESTO', :old.dispuesto, :new.dispuesto, 'M' );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'CONTINGENCIA', :old.contingencia, :new.contingencia, 'M' );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'PRO_CATEGORIA', :old.pro_categoria, :new.pro_categoria, 'N' );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'MED_DISPUESTO', :old.med_dispuesto, :new.med_dispuesto, 'M' );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'FEC_ULT_CRC', :old.fec_ult_crc, :new.fec_ult_crc, 'F' );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'FEC_CRC', :old.fec_crc, :new.fec_crc, 'F' );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'TOT_DEU_SISTEMA', :old.tot_deu_sistema, :new.tot_deu_sistema, 'M' );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'TOT_DEU_REAL', :old.tot_deu_real, :new.tot_deu_real, 'M' );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'CAT_SISTEMA', :old.cat_sistema, :new.cat_sistema, 'N' );
  
  -- Insertar tabla de auditoria
  prg_ins_ge_auditoria( r_baudi );
EXCEPTION
  when others then
    prg_ins_ge_auditoria( r_baudi );
END;
/

