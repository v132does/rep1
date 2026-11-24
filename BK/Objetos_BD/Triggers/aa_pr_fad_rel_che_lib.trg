CREATE OR REPLACE TRIGGER IT.AA_PR_FAD_REL_CHE_LIB
  AFTER DELETE OR UPDATE
     ON PR_FAD_REL_CHE_LIB
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 26/11/2018 a las 17:29:20 Hs.
  */
  r_paudi PR_AUDITORIAS%ROWTYPE; -- Registro de la tabla PR_AUDITORIAS
BEGIN
  r_paudi.tabla := 'PR_FAD_REL_CHE_LIB';
  r_paudi.clave := to_char( :old.nro_solicitud) || '#' || to_char( :old.nro_cuota) || '#' || to_char( :old.cod_banco) || '#' || to_char( :old.nro_cheque) || '#' || :old.cta_libradora || '#' || to_char( :old.cod_tip_documento) || '#' || :old.nro_documento;
  r_paudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    r_paudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_paudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  r_paudi.detalle := pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'RELACION', :old.relacion, :new.relacion );

  -- Insertar tabla de auditoria
  prp_ins_pr_auditoria( r_paudi );
EXCEPTION
  when others then
    prp_ins_pr_auditoria( r_paudi );
END;
/

