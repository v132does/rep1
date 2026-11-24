CREATE OR REPLACE TRIGGER IT.AA_GE_DAT_RIE_EVALUACIONES_DET
  AFTER DELETE OR UPDATE
     ON GE_DAT_RIE_EVALUACIONES_DET
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 13/04/2012 a las 09:42:25 Hs.
  */
  r_baudi GE_AUDITORIAS%ROWTYPE; -- Registro de la tabla GE_AUDITORIAS
BEGIN
  r_baudi.tabla := 'GE_DAT_RIE_EVALUACIONES_DET';
  r_baudi.clave := to_char( :old.nro_solicitud) || '#' || to_char( :old.nro_intento) || '#' || to_char( :old.nro_secuencia);
  r_baudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    r_baudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_baudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  r_baudi.detalle := pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'TIP_REL_PERSONA', :old.tip_rel_persona, :new.tip_rel_persona );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'COD_PERSONA', :old.cod_persona, :new.cod_persona );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'PUN_SCORING', :old.pun_scoring, :new.pun_scoring, 'M' );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'PRO_MORA', :old.pro_mora, :new.pro_mora, 'N' );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'DIC_PERFIL', :old.dic_perfil, :new.dic_perfil );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'BAL_CAJA', :old.bal_caja, :new.bal_caja, 'M' );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'DIC_BAL_CAJA', :old.dic_bal_caja, :new.dic_bal_caja );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'LIM_MAX_PERSONA', :old.lim_max_persona, :new.lim_max_persona, 'M' );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'DIC_BURO', :old.dic_buro, :new.dic_buro );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'DAT_ENTRADA', :old.dat_entrada, :new.dat_entrada );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'COD_MODULO', :old.cod_modulo, :new.cod_modulo, 'N' );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'COD_MODALIDAD', :old.cod_modalidad, :new.cod_modalidad, 'N' );

  -- Insertar tabla de auditoria
  prg_ins_ge_auditoria( r_baudi );
EXCEPTION
  when others then
    prg_ins_ge_auditoria( r_baudi );
END;
/

