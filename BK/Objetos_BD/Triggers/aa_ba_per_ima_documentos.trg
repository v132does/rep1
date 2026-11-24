CREATE OR REPLACE TRIGGER IT.AA_BA_PER_IMA_DOCUMENTOS
  AFTER DELETE OR UPDATE
     ON BA_PER_IMA_DOCUMENTOS
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2015 - IT Consultores
  || Generado el 22/07/2015 a las 10:18:28 Hs.
  */
  r_eaudi BA_AUDITORIAS%ROWTYPE; -- Registro de la tabla BA_AUDITORIAS
BEGIN
  r_eaudi.tabla := 'BA_PER_IMA_DOCUMENTOS';
  r_eaudi.clave := :old.cod_persona || '#' || :old.cod_tip_documento || '#' || to_char( :old.nro_referencia);
  r_eaudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    r_eaudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_eaudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  r_eaudi.detalle := r_eaudi.detalle || pae_cnf.fu_reg_auditoria( r_eaudi.tip_novedad, 'FEC_ESCANEO', :old.fec_escaneo, :new.fec_escaneo, 'F' );
  r_eaudi.detalle := r_eaudi.detalle || pae_cnf.fu_reg_auditoria( r_eaudi.tip_novedad, 'EST_DOC', :old.est_doc, :new.est_doc );
  r_eaudi.detalle := r_eaudi.detalle || pae_cnf.fu_reg_auditoria( r_eaudi.tip_novedad, 'OBSERVACION', :old.observacion, :new.observacion );
  r_eaudi.detalle := r_eaudi.detalle || pae_cnf.fu_reg_auditoria( r_eaudi.tip_novedad, 'FEC_APROBACION', :old.fec_aprobacion, :new.fec_aprobacion, 'F' );
  r_eaudi.detalle := r_eaudi.detalle || pae_cnf.fu_reg_auditoria( r_eaudi.tip_novedad, 'COD_USU_APROBACION', :old.cod_usu_aprobacion, :new.cod_usu_aprobacion );
  r_eaudi.detalle := r_eaudi.detalle || pae_cnf.fu_reg_auditoria( r_eaudi.tip_novedad, 'FEC_VENCIMIENTO', :old.fec_vencimiento, :new.fec_vencimiento, 'F' );

  -- Insertar tabla de auditoria
  pae_cnf.pr_ins_ba_auditoria( r_eaudi );
EXCEPTION
  when others then
    pae_cnf.pr_ins_ba_auditoria( r_eaudi );
END;
/

