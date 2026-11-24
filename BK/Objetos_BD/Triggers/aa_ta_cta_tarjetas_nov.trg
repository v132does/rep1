CREATE OR REPLACE TRIGGER IT.AA_TA_CTA_TARJETAS_NOV
  AFTER DELETE OR UPDATE
     ON TA_CTA_TARJETAS_NOV
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 09/05/2013 a las 20:02:37 Hs.
  */
  r_taudi TA_AUDITORIAS%ROWTYPE; -- Registro de la tabla TA_AUDITORIAS
BEGIN
  r_taudi.tabla := 'TA_CTA_TARJETAS_NOV';
  r_taudi.clave := :old.nro_cuenta || '#' || to_char( :old.fecha, 'DD/MM/YYYY HH24:MI:SS');
  r_taudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    r_taudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_taudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  r_taudi.detalle := pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'LIN_CUOTAS', :old.lin_cuotas, :new.lin_cuotas, 'M' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'LIN_CREDITO', :old.lin_credito, :new.lin_credito, 'M' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'TIP_COBRO', :old.tip_cobro, :new.tip_cobro );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'DEB_AUTOMATICO', :old.deb_automatico, :new.deb_automatico );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'NRO_CTA_DEBITO', :old.nro_cta_debito, :new.nro_cta_debito );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'DIR_ENVIO', :old.dir_envio, :new.dir_envio );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'TEL_PRINCIPAL', :old.tel_principal, :new.tel_principal );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'ENVIADO', :old.enviado, :new.enviado );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'LOCALIDAD', :old.localidad, :new.localidad );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'NIV_APROBACION', :old.niv_aprobacion, :new.niv_aprobacion );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'NRO_ACTA', :old.nro_acta, :new.nro_acta, 'N' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'FEC_APROBACION', :old.fec_aprobacion, :new.fec_aprobacion, 'F' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'OBSERVACION', :old.observacion, :new.observacion );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'APROBADO', :old.aprobado, :new.aprobado );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_ESTADO', :old.cod_estado, :new.cod_estado, 'N' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'NOM_EMBOZAR', :old.nom_embozar, :new.nom_embozar );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_USU_OFICIAL', :old.cod_usu_oficial, :new.cod_usu_oficial );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_SEXO', :old.cod_sexo, :new.cod_sexo );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'NOM_COMPLETO', :old.nom_completo, :new.nom_completo );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'NRO_DOCUMENTO', :old.nro_documento, :new.nro_documento );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_PAI_NACIONALIDAD', :old.cod_pai_nacionalidad, :new.cod_pai_nacionalidad, 'N' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_PROFESION', :old.cod_profesion, :new.cod_profesion, 'N' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'EST_CIVIL', :old.est_civil, :new.est_civil );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'FEC_NACIMIENTO', :old.fec_nacimiento, :new.fec_nacimiento, 'F' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'NRO_TARJETA', :old.nro_tarjeta, :new.nro_tarjeta );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_TIP_CIERRE', :old.cod_tip_cierre, :new.cod_tip_cierre, 'N' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'CAT_RIESGO', :old.cat_riesgo, :new.cat_riesgo );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'GAS_NO_APLICAR', :old.gas_no_aplicar, :new.gas_no_aplicar );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'RET_EXTRACTO', :old.ret_extracto, :new.ret_extracto );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'MOT_RET_EXTRACTO', :old.mot_ret_extracto, :new.mot_ret_extracto, 'N' );

  -- Insertar tabla de auditoria
  prt_ins_ta_auditoria( r_taudi );
EXCEPTION
  when others then
    prt_ins_ta_auditoria( r_taudi );
END;
/

