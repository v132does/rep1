CREATE OR REPLACE TRIGGER IT.aa_ge_snp_plantillas
  AFTER DELETE OR UPDATE
     ON it.GE_SNP_PLANTILLAS
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditorka
  || (c) 2016 - IT Consultores
  || Generado el 07/03/2016 a las 08:47:10 Hs.
  */
  r_gaudi GE_AUDITORIAS%ROWTYPE; -- Registro de la tabla GE_AUDITORIAS
BEGIN
  r_gaudi.tabla := 'GE_SNP_PLANTILLAS';
  r_gaudi.clave := to_char( :old.nro_plantilla);
  r_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    r_gaudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_gaudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  r_gaudi.detalle := pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'COD_PERSONA', :old.cod_persona, :new.cod_persona );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'NRO_CTA_SOLICITANTE', :old.nro_cta_solicitante, :new.nro_cta_solicitante );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'COD_MONEDA', :old.cod_moneda, :new.cod_moneda );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'MONTO', :old.monto, :new.monto, 'M' );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'COD_SWI_PTE_BENEFICIARIO', :old.cod_swi_pte_beneficiario, :new.cod_swi_pte_beneficiario );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'NRO_CTA_BENEFICIARIO', :old.nro_cta_beneficiario, :new.nro_cta_beneficiario );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'NOM_BENEFICIARIO', :old.nom_beneficiario, :new.nom_beneficiario );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'COD_TIP_DOC_BENEFICIARIO', :old.cod_tip_doc_beneficiario, :new.cod_tip_doc_beneficiario, 'N' );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'NRO_DOC_BENEFICIARIO', :old.nro_doc_beneficiario, :new.nro_doc_beneficiario );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'COD_PER_VINCULADA', :old.cod_per_vinculada, :new.cod_per_vinculada );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'DIR_BENEFICIARIO', :old.dir_beneficiario, :new.dir_beneficiario );

  -- Insertar tabla de auditoria
  prg_ins_ge_auditoria( r_gaudi );
EXCEPTION
  when others then
    prg_ins_ge_auditoria( r_gaudi );
END;
/

