CREATE OR REPLACE TRIGGER IT.AA_SB_SNP_CATASTROS
  AFTER DELETE OR UPDATE
     ON IT.SB_SNP_CATASTROS
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditorka
  || (c) 2022 - ITTI DIGITAL
  || Generado el 30/08/2022 a las 14:44:17 Hs
  */
  r_saudi SB_AUDITORIAS%ROWTYPE; -- Registro de la tabla SB_AUDITORIAS
BEGIN
  r_saudi.tabla := 'SB_SNP_CATASTROS';
  r_saudi.clave := :old.nro_orden;
  r_saudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    r_saudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_saudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  r_saudi.detalle := r_saudi.detalle || pae_cnf.fu_reg_auditoria( r_saudi.tip_novedad, 'NRO_ORDEN', :old.nro_orden, :new.nro_orden, 'N' );
  r_saudi.detalle := r_saudi.detalle || pae_cnf.fu_reg_auditoria( r_saudi.tip_novedad, 'ESTADO', :old.estado, :new.estado );
  r_saudi.detalle := r_saudi.detalle || pae_cnf.fu_reg_auditoria( r_saudi.tip_novedad, 'ORIGEN', :old.origen, :new.origen );
  r_saudi.detalle := r_saudi.detalle || pae_cnf.fu_reg_auditoria( r_saudi.tip_novedad, 'COD_MENSAJE', :old.cod_mensaje, :new.cod_mensaje );
  r_saudi.detalle := r_saudi.detalle || pae_cnf.fu_reg_auditoria( r_saudi.tip_novedad, 'COD_MONEDA', :old.cod_moneda, :new.cod_moneda );
  r_saudi.detalle := r_saudi.detalle || pae_cnf.fu_reg_auditoria( r_saudi.tip_novedad, 'MONTO', :old.monto, :new.monto );
  r_saudi.detalle := r_saudi.detalle || pae_cnf.fu_reg_auditoria( r_saudi.tip_novedad, 'IND_MTO_FIJO', :old.ind_mto_fijo, :new.ind_mto_fijo );
  r_saudi.detalle := r_saudi.detalle || pae_cnf.fu_reg_auditoria( r_saudi.tip_novedad, 'FEC_VENCIMIENTO', :old.fec_vencimiento, :new.fec_vencimiento );
  r_saudi.detalle := r_saudi.detalle || pae_cnf.fu_reg_auditoria( r_saudi.tip_novedad, 'TIP_RECHAZO', :old.tip_rechazo, :new.tip_rechazo );
  r_saudi.detalle := r_saudi.detalle || pae_cnf.fu_reg_auditoria( r_saudi.tip_novedad, 'DIA_ENVIO', :old.dia_envio, :new.dia_envio );
  r_saudi.detalle := r_saudi.detalle || pae_cnf.fu_reg_auditoria( r_saudi.tip_novedad, 'COD_PER_SOLICITANTE', :old.cod_per_solicitante, :new.cod_per_solicitante );
  r_saudi.detalle := r_saudi.detalle || pae_cnf.fu_reg_auditoria( r_saudi.tip_novedad, 'COD_TIP_DOC_SOLICITANTE', :old.cod_tip_doc_solicitante, :new.cod_tip_doc_solicitante );
  r_saudi.detalle := r_saudi.detalle || pae_cnf.fu_reg_auditoria( r_saudi.tip_novedad, 'NRO_DOC_SOLICITANTE', :old.nro_doc_solicitante, :new.nro_doc_solicitante );
  r_saudi.detalle := r_saudi.detalle || pae_cnf.fu_reg_auditoria( r_saudi.tip_novedad, 'COD_TIP_PER_SOLICITANTE', :old.cod_tip_per_solicitante, :new.cod_tip_per_solicitante );
  r_saudi.detalle := r_saudi.detalle || pae_cnf.fu_reg_auditoria( r_saudi.tip_novedad, 'NOM_SOLICITANTE', :old.nom_solicitante, :new.nom_solicitante );
  r_saudi.detalle := r_saudi.detalle || pae_cnf.fu_reg_auditoria( r_saudi.tip_novedad, 'DIR_SOLICITANTE', :old.dir_solicitante, :new.dir_solicitante );
  r_saudi.detalle := r_saudi.detalle || pae_cnf.fu_reg_auditoria( r_saudi.tip_novedad, 'COD_SWI_PTE_SOLICITANTE', :old.cod_swi_pte_solicitante, :new.cod_swi_pte_solicitante );
  r_saudi.detalle := r_saudi.detalle || pae_cnf.fu_reg_auditoria( r_saudi.tip_novedad, 'NRO_CTA_PTE_SOLICITANTE', :old.nro_cta_pte_solicitante, :new.nro_cta_pte_solicitante );
  r_saudi.detalle := r_saudi.detalle || pae_cnf.fu_reg_auditoria( r_saudi.tip_novedad, 'NRO_CTA_SOLICITANTE', :old.nro_cta_solicitante, :new.nro_cta_solicitante );
  r_saudi.detalle := r_saudi.detalle || pae_cnf.fu_reg_auditoria( r_saudi.tip_novedad, 'COD_PER_RECEPTOR', :old.cod_per_receptor, :new.cod_per_receptor );
  r_saudi.detalle := r_saudi.detalle || pae_cnf.fu_reg_auditoria( r_saudi.tip_novedad, 'COD_TIP_DOC_RECEPTOR', :old.cod_tip_doc_receptor, :new.cod_tip_doc_receptor );
  r_saudi.detalle := r_saudi.detalle || pae_cnf.fu_reg_auditoria( r_saudi.tip_novedad, 'NRO_DOC_RECEPTOR', :old.nro_doc_receptor, :new.nro_doc_receptor );
  r_saudi.detalle := r_saudi.detalle || pae_cnf.fu_reg_auditoria( r_saudi.tip_novedad, 'COD_TIP_PER_RECEPTOR', :old.cod_tip_per_receptor, :new.cod_tip_per_receptor );
  r_saudi.detalle := r_saudi.detalle || pae_cnf.fu_reg_auditoria( r_saudi.tip_novedad, 'NOM_RECEPTOR', :old.nom_receptor, :new.nom_receptor  );
  r_saudi.detalle := r_saudi.detalle || pae_cnf.fu_reg_auditoria( r_saudi.tip_novedad, 'DIR_RECEPTOR', :old.dir_receptor, :new.dir_receptor );
  r_saudi.detalle := r_saudi.detalle || pae_cnf.fu_reg_auditoria( r_saudi.tip_novedad, 'COD_SWI_PTE_RECEPTOR', :old.cod_swi_pte_receptor, :new.cod_swi_pte_receptor );
  r_saudi.detalle := r_saudi.detalle || pae_cnf.fu_reg_auditoria( r_saudi.tip_novedad, 'NRO_CTA_PTE_RECEPTOR', :old.nro_cta_pte_receptor, :new.nro_cta_pte_receptor );
  r_saudi.detalle := r_saudi.detalle || pae_cnf.fu_reg_auditoria( r_saudi.tip_novedad, 'NRO_CTA_RECEPTOR', :old.nro_cta_receptor, :new.nro_cta_receptor );
  r_saudi.detalle := r_saudi.detalle || pae_cnf.fu_reg_auditoria( r_saudi.tip_novedad, 'NRO_REFERENCIA', :old.nro_referencia, :new.nro_referencia );
  r_saudi.detalle := r_saudi.detalle || pae_cnf.fu_reg_auditoria( r_saudi.tip_novedad, 'NRO_REF_EXTERNA', :old.nro_ref_externa, :new.nro_ref_externa );
  r_saudi.detalle := r_saudi.detalle || pae_cnf.fu_reg_auditoria( r_saudi.tip_novedad, 'FEC_REGISTRO', :old.fec_registro, :new.fec_registro );
  r_saudi.detalle := r_saudi.detalle || pae_cnf.fu_reg_auditoria( r_saudi.tip_novedad, 'TITULAR_SERVICIO', :old.titular_servicio, :new.titular_servicio );
  r_saudi.detalle := r_saudi.detalle || pae_cnf.fu_reg_auditoria( r_saudi.tip_novedad, 'COD_SERVICIO', :old.cod_servicio, :new.cod_servicio );
  r_saudi.detalle := r_saudi.detalle || pae_cnf.fu_reg_auditoria( r_saudi.tip_novedad, 'CAN_CUOTAS', :old.can_cuotas, :new.can_cuotas );
  -- Insertar tabla de auditoria
  prs_ins_sb_auditoria( r_saudi );
EXCEPTION
  when others then
    prs_ins_sb_auditoria( r_saudi );
END;
/

