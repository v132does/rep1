CREATE OR REPLACE TRIGGER IT.AA_GE_SNP_TRANSFERENCIAS
  AFTER DELETE OR UPDATE
     ON GE_SNP_TRANSFERENCIAS
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 29/12/2014 a las 10:06:19 Hs.
  */
  rg_raudi GE_AUDITORIAS%ROWTYPE; -- Registro de la tabla GE_AUDITORIAS
BEGIN
  rg_raudi.tabla := 'GE_SNP_TRANSFERENCIAS';
  rg_raudi.clave := to_char( :old.nro_referencia);
  rg_raudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    rg_raudi.tip_novedad := 'M';
  ELSIF deleting THEN
    rg_raudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  rg_raudi.detalle := pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'NRO_LOTE', :old.nro_lote, :new.nro_lote );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'NRO_SEC_LOTE', :old.nro_sec_lote, :new.nro_sec_lote );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'COD_MODULO', :old.cod_modulo, :new.cod_modulo, 'N' );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'COD_MODALIDAD', :old.cod_modalidad, :new.cod_modalidad, 'N' );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'COD_OFICINA', :old.cod_oficina, :new.cod_oficina, 'N' );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'COD_MSJ_SWIFT', :old.cod_msj_swift, :new.cod_msj_swift, 'N' );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'COD_TIP_OPERACION', :old.cod_tip_operacion, :new.cod_tip_operacion );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'COD_SUB_TIP_OPERACION', :old.cod_sub_tip_operacion, :new.cod_sub_tip_operacion );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'MSJ_SWIFT', :old.msj_swift, :new.msj_swift );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'FEC_VALOR', :old.fec_valor, :new.fec_valor, 'F' );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'FEC_INGRESO', :old.fec_ingreso, :new.fec_ingreso, 'F' );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'FEC_RECEPCION', :old.fec_recepcion, :new.fec_recepcion, 'F' );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'FECHA', :old.fecha, :new.fecha, 'F' );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'HORA', :old.hora, :new.hora );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'COD_USUARIO', :old.cod_usuario, :new.cod_usuario );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'COD_MONEDA', :old.cod_moneda, :new.cod_moneda );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'MONTO', :old.monto, :new.monto, 'M' );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'COD_PER_SOLICITANTE', :old.cod_per_solicitante, :new.cod_per_solicitante );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'NOM_SOLICITANTE', :old.nom_solicitante, :new.nom_solicitante );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'DIR_SOLICITANTE', :old.dir_solicitante, :new.dir_solicitante );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'COD_TIP_DOC_SOLICITANTE', :old.cod_tip_doc_solicitante, :new.cod_tip_doc_solicitante, 'N' );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'NRO_DOC_SOLICITANTE', :old.nro_doc_solicitante, :new.nro_doc_solicitante );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'NRO_CTA_SOLICITANTE', :old.nro_cta_solicitante, :new.nro_cta_solicitante );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'NRO_CTA_PTE_SOLICITANTE', :old.nro_cta_pte_solicitante, :new.nro_cta_pte_solicitante );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'NRO_CTA_SUC_PTE_SOLICITANTE', :old.nro_cta_suc_pte_solicitante, :new.nro_cta_suc_pte_solicitante );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'COD_SWI_PTE_SOLICITANTE', :old.cod_swi_pte_solicitante, :new.cod_swi_pte_solicitante );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'COD_SWI_SUC_SOLICITANTE', :old.cod_swi_suc_solicitante, :new.cod_swi_suc_solicitante );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'COD_PER_BENEFICIARIO', :old.cod_per_beneficiario, :new.cod_per_beneficiario );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'NOM_BENEFICIARIO', :old.nom_beneficiario, :new.nom_beneficiario );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'DIR_BENEFICIARIO', :old.dir_beneficiario, :new.dir_beneficiario );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'COD_TIP_DOC_BENEFICIARIO', :old.cod_tip_doc_beneficiario, :new.cod_tip_doc_beneficiario, 'N' );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'NRO_DOC_BENEFICIARIO', :old.nro_doc_beneficiario, :new.nro_doc_beneficiario );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'NRO_CTA_BENEFICIARIO', :old.nro_cta_beneficiario, :new.nro_cta_beneficiario );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'NRO_CTA_PTE_BENEFICIARIO', :old.nro_cta_pte_beneficiario, :new.nro_cta_pte_beneficiario );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'NRO_CTA_SUC_PTE_BENEFICIARIO', :old.nro_cta_suc_pte_beneficiario, :new.nro_cta_suc_pte_beneficiario );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'COD_SWI_PTE_BENEFICIARIO', :old.cod_swi_pte_beneficiario, :new.cod_swi_pte_beneficiario );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'COD_SWI_SUC_BENEFICIARIO', :old.cod_swi_suc_beneficiario, :new.cod_swi_suc_beneficiario );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'PLAZO', :old.plazo, :new.plazo, 'N' );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'CONCEPTO', :old.concepto, :new.concepto );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'OBSERVACION', :old.observacion, :new.observacion );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'NRO_REF_EXTERNA', :old.nro_ref_externa, :new.nro_ref_externa );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'TIP_CARGO', :old.tip_cargo, :new.tip_cargo );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'IND_VALOR', :old.ind_valor, :new.ind_valor );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'SITUACION', :old.situacion, :new.situacion );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'ESTADO', :old.estado, :new.estado );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'TIP_RECHAZO', :old.tip_rechazo, :new.tip_rechazo );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'MTO_CARGO', :old.mto_cargo, :new.mto_cargo, 'M' );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'PRIORIDAD', :old.prioridad, :new.prioridad, 'N' );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'NRO_OPERACION', :old.nro_operacion, :new.nro_operacion, 'N' );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'TIP_MENSAJE', :old.tip_mensaje, :new.tip_mensaje );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'REF_OID', :old.ref_oid, :new.ref_oid );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'ERROR', :old.error, :new.error );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'IMP_INF_HACIENDA', :old.imp_inf_hacienda, :new.imp_inf_hacienda );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'ORIGEN', :old.origen, :new.origen );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'PLATAFORMA', :old.plataforma, :new.plataforma );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'INDEMNIZADO', :old.indemnizado, :new.indemnizado );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'COD_SERVICIO', :old.cod_servicio, :new.cod_servicio, 'N' );

  -- Insertar tabla de auditoria
  prg_ins_ge_auditoria( rg_raudi );
EXCEPTION
  when others then
    prg_ins_ge_auditoria( rg_raudi );
END;
/

