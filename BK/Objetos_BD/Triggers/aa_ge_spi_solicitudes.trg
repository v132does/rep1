CREATE OR REPLACE TRIGGER IT.AA_GE_SPI_SOLICITUDES
  AFTER DELETE OR UPDATE
     ON it.GE_SPI_SOLICITUDES
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2022 - ITTI DIGITAL
  ||
  */
  rg_raudi GE_AUDITORIAS%ROWTYPE; -- Registro de la tabla GE_AUDITORIAS

BEGIN
  rg_raudi.tabla := 'GE_SPI_SOLICITUDES';
  rg_raudi.clave := to_char( :old.cod_sol_spi);
  rg_raudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    rg_raudi.tip_novedad := 'M';
  ELSIF deleting THEN
    rg_raudi.tip_novedad := 'E';
  END IF;

rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad,'CTA_BEN_RECIBIDO', :old.cta_ben_recibido, :new.cta_ben_recibido);
rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad,'COD_TIP_OPERACION', :old.cod_tip_operacion, :new.cod_tip_operacion);
rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad,'TIP_RECHAZO', :old.tip_rechazo, :new.tip_rechazo);
rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad,'INFO_ENVIO', :old.info_envio, :new.info_envio);
rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad,'INFO_REMESA', :old.info_remesa, :new.info_remesa);
rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad,'IDENTIFICACION', :old.identificacion, :new.identificacion);

rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad,'SIT_SOLICITUD', :old.sit_solicitud, :new.sit_solicitud);
rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad,'COD_SWI_SUC_BENEFICIARIO', :old.cod_swi_suc_beneficiario, :new.cod_swi_suc_beneficiario );
rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad,'COD_SWI_BENEFICIARIO', :old.cod_swi_beneficiario, :new.cod_swi_beneficiario );
rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad,'COD_SWI_SUC_SOLICITANTE', :old.cod_swi_suc_solicitante, :new.cod_swi_suc_solicitante );
rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad,'COD_SWI_SOLICITANTE', :old.cod_swi_solicitante, :new.cod_swi_solicitante );
rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad,'NRO_REF_MSJ_ORIGINAL', :old.nro_ref_msj_original, :new.nro_ref_msj_original);
rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad,'COD_MOT_SOLICITUD', :old.cod_mot_solicitud, :new.cod_mot_solicitud );
rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad,'COD_MONEDA', :old.cod_moneda, :new.cod_moneda );
rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad,'UETR', :old.uetr, :new.uetr );
rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad,'CTA_BENEFICIARIO', :old.cta_beneficiario, :new.cta_beneficiario );
rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad,'NRO_REF_SOLICITUD', :old.nro_ref_solicitud, :new.nro_ref_solicitud );   
    
rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad,'MONTO', :old.monto, :new.monto );
rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad,'NOM_SOLICITANTE', :old.nom_solicitante, :new.nom_solicitante);
rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad,'DOC_SOLICITANTE', :old.doc_solicitante, :new.doc_solicitante);
rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad,'TIP_DOC_SOLICITANTE', :old.tip_doc_solicitante, :new.tip_doc_solicitante);
rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad,'CTA_SOLICITANTE', :old.cta_solicitante, :new.cta_solicitante);
rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad,'NOM_BENEFICIARIO', :old.nom_beneficiario, :new.nom_beneficiario);
rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad,'DOC_BENEFICIARIO', :old.doc_beneficiario, :new.doc_beneficiario);
rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad,'TIP_DOC_BENEFICIARIO', :old.tip_doc_beneficiario, :new.tip_doc_beneficiario);
   
rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'NRO_REFERENCIA', :old.nro_referencia, :new.nro_referencia );
rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'COD_MSJ_SWIFT', :old.cod_msj_swift, :new.cod_msj_swift );
rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'NRO_REF_EXTERNA', :old.nro_ref_externa, :new.nro_ref_externa );
rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'FEC_RECEPCION', :old.fec_recepcion, :new.fec_recepcion );
  
rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'EST_NOTIFICACION', :old.est_notificacion, :new.est_notificacion );
rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'EST_SOLICITUD', :old.est_solicitud, :new.est_solicitud);
rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'RESPUESTA', :old.respuesta, :new.respuesta);

  -- Insertar tabla de auditoria
  prg_ins_ge_auditoria( rg_raudi );
EXCEPTION
  when others then
    prg_ins_ge_auditoria( rg_raudi );
END;
/

