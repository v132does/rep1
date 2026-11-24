CREATE OR REPLACE TRIGGER IT.AA_BA_PERSONAS
  AFTER DELETE OR UPDATE
     ON BA_PERSONAS
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 30/05/2008 a las 15:52:01 Hs.
  */
  v_registro BA_AUDITORIAS%ROWTYPE; -- Registro de la tabla BA_AUDITORIAS
BEGIN
  v_registro.tabla := 'BA_PERSONAS';
  v_registro.clave := :old.cod_persona;
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NOM_COMPLETO', :old.nom_completo, :new.nom_completo );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TIPO', :old.tipo, :new.tipo );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_USU_PROMOTOR', :old.cod_usu_promotor, :new.cod_usu_promotor );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_TIP_DOCUMENTO', :old.cod_tip_documento, :new.cod_tip_documento, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_DOCUMENTO', :old.nro_documento, :new.nro_documento );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_PAIS', :old.cod_pais, :new.cod_pais, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'DIR_CORREO', :old.dir_correo, :new.dir_correo );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_ACTIVIDAD', :old.cod_actividad, :new.cod_actividad, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'REF_BANCARIA', :old.ref_bancaria, :new.ref_bancaria, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'REF_COMERCIAL', :old.ref_comercial, :new.ref_comercial, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'REF_LABORAL', :old.ref_laboral, :new.ref_laboral, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'REF_TARJETA', :old.ref_tarjeta, :new.ref_tarjeta, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TOT_INGRESOS', :old.tot_ingresos, :new.tot_ingresos, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'ING_PRESUNTOS', :old.ing_presuntos, :new.ing_presuntos, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'EGR_PRESUNTOS', :old.egr_presuntos, :new.egr_presuntos, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'EST_VERIFICACION', :old.est_verificacion, :new.est_verificacion );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_USU_VERIFICADOR', :old.cod_usu_verificador, :new.cod_usu_verificador );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NOM_PER_INFORMO', :old.nom_per_informo, :new.nom_per_informo );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'OBS_VERIFICACION', :old.obs_verificacion, :new.obs_verificacion );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_VERIFICACION', :old.fec_verificacion, :new.fec_verificacion, 'F' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TIP_RELACION', :old.tip_relacion, :new.tip_relacion );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_VTO_DOCUMENTO', :old.fec_vto_documento, :new.fec_vto_documento, 'F' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'RECIBE_SMS', :old.recibe_sms, :new.recibe_sms );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TIP_IVA', :old.tip_iva, :new.tip_iva );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TAS_PERSONALIZADA', :old.tas_personalizada, :new.tas_personalizada );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_PAI_DOCUMENTO', :old.cod_pai_documento, :new.cod_pai_documento );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_RUB_PRIMARIO', :old.cod_rub_primario, :new.cod_rub_primario );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_RUB_SECUNDARIO', :old.cod_rub_secundario, :new.cod_rub_secundario );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_RUB_TERCIARIO', :old.cod_rub_terciario, :new.cod_rub_terciario );
  
  -- Insertar tabla de auditoria
  pae_cnf.pr_ins_ba_auditoria( v_registro );
EXCEPTION
  when others then
    pae_cnf.pr_ins_ba_auditoria( v_registro );
END;
/

