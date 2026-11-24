CREATE OR REPLACE TRIGGER IT.AA_GE_SNP_IMP_HACIENDA
  AFTER DELETE OR UPDATE
     ON GE_SNP_IMP_HACIENDA
    FOR EACH ROW
DECLARE



  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 04/07/2013 a las 14:23:24 Hs.
  
  
  */
  r_gaudi GE_AUDITORIAS%ROWTYPE; -- Registro de la tabla GE_AUDITORIAS
BEGIN
  r_gaudi.tabla := 'GE_SNP_IMP_HACIENDA';
  r_gaudi.clave := :old.cod_impuesto || '#' || to_char( :old.cod_msj_swift) || '#' || :old.cod_tip_operacion || '#' || :old.cod_sub_tip_operacion;
  r_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    r_gaudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_gaudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle

  
  -- Insertar tabla de auditoria
  prg_ins_ge_auditoria( r_gaudi );
EXCEPTION
  when others then
    prg_ins_ge_auditoria( r_gaudi );
END;
/

