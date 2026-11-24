CREATE OR REPLACE TRIGGER IT.AA_GE_PRO_PRE_APROBADOS
  AFTER DELETE OR UPDATE
     ON GE_PRO_PRE_APROBADOS
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 11/04/2012 a las 09:11:26 Hs.
  */
  r_gaudi GE_AUDITORIAS%ROWTYPE; -- Registro de la tabla GE_AUDITORIAS
BEGIN
--
  r_gaudi.tabla          := 'GE_PRO_PRE_APROBADOS';
  r_gaudi.clave          := :old.cod_persona || '#' || to_char(:old.lote);
  r_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);
  IF updating THEN
    r_gaudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_gaudi.tip_novedad := 'E';
  END IF;

   --- Registrar Detalle
  r_gaudi.detalle := pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'COD_OFICINA', :old.cod_oficina, :new.cod_oficina, 'N' );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'COD_USU_OFICIAL', :old.cod_usu_oficial, :new.cod_usu_oficial );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'ESTADO', :old.estado, :new.estado );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'LIN_VIGENTE_TC', :old.lin_vigente_tc, :new.lin_vigente_tc, 'M' );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'LIN_NUEVA_TC', :old.lin_nueva_tc, :new.lin_nueva_tc, 'M' );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'MTO_MAX_CUOTA', :old.mto_max_cuota, :new.mto_max_cuota, 'M' );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'PLZ_12_MESES', :old.plz_12_meses, :new.plz_12_meses, 'M' );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'PLZ_18_MESES', :old.plz_18_meses, :new.plz_18_meses, 'M' );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'PLZ_24_MESES', :old.plz_24_meses, :new.plz_24_meses, 'M' );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'PLZ_30_MESES', :old.plz_30_meses, :new.plz_30_meses, 'M' );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'PLZ_36_MESES', :old.plz_36_meses, :new.plz_36_meses, 'M' );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'PLZ_42_MESES', :old.plz_42_meses, :new.plz_42_meses, 'M' );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'PLZ_48_MESES', :old.plz_48_meses, :new.plz_48_meses, 'M' );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'PLZ_54_MESES', :old.plz_54_meses, :new.plz_54_meses, 'M' );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'PLZ_60_MESES', :old.plz_60_meses, :new.plz_60_meses, 'M' );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'COD_SEGMENTO', :old.cod_segmento, :new.cod_segmento );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'VAL_MIN_TASA', :old.val_min_tasa, :new.val_min_tasa, 'M' );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'VAL_MAX_TASA', :old.val_max_tasa, :new.val_max_tasa, 'M' );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'COD_CAMPANA', :old.cod_campana, :new.cod_campana, 'N' );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'COD_MODULO', :old.cod_modulo, :new.cod_modulo, 'N' );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'COD_MODALIDAD', :old.cod_modalidad, :new.cod_modalidad, 'N' );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'MIN_MONTO', :old.min_monto, :new.min_monto, 'M' );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'MAX_MONTO', :old.max_monto, :new.max_monto, 'M' );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'MIN_PLAZO', :old.min_plazo, :new.min_plazo, 'N' );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'MAX_PLAZO', :old.max_plazo, :new.max_plazo, 'N' );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'IND_EVALUACION', :old.ind_evaluacion, :new.ind_evaluacion );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'COD_CAUSA', :old.cod_causa, :new.cod_causa );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'COD_USU_CANCELACION', :old.cod_usu_cancelacion, :new.cod_usu_cancelacion );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'NRO_SOLICITUD', :old.nro_solicitud, :new.nro_solicitud );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'IND_HAB_ATM', :old.ind_hab_atm, :new.ind_hab_atm );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'NRO_CTA_RENOVADA', :old.nro_cta_renovada, :new.nro_cta_renovada );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'COD_SUB_MODALIDAD', :old.cod_sub_modalidad, :new.cod_sub_modalidad, 'N' );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'DENOMINACION', :old.Denominacion, :new.Denominacion );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'FEC_VTO_CAMPANA', :old.fec_vto_campana, :new.fec_vto_campana );

  -- Insertar tabla de auditoria
  prg_ins_ge_auditoria(r_gaudi);
EXCEPTION
  when others then
    prg_ins_ge_auditoria(r_gaudi);
END;
/

