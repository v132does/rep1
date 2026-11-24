CREATE OR REPLACE TRIGGER IT.AA_GE_INV_DOC_ANULADOS
  AFTER DELETE OR UPDATE
     ON GE_INV_DOC_ANULADOS
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 20/03/2012 a las 14:52:45 Hs.
  */
  r_baudi GE_AUDITORIAS%ROWTYPE; -- Registro de la tabla GE_AUDITORIAS
BEGIN
  r_baudi.tabla := 'GE_INV_DOC_ANULADOS';
  r_baudi.clave := to_char( :old.nro_secuencia) || '#' || to_char( :old.nro_documento);
  r_baudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    r_baudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_baudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  r_baudi.detalle := pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'COD_CAUSA', :old.cod_causa, :new.cod_causa, 'N' );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'EST_ANTERIOR', :old.est_anterior, :new.est_anterior );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'OBSERVACION', :old.observacion, :new.observacion );

  -- Insertar tabla de auditoria
  prg_ins_ge_auditoria( r_baudi );
EXCEPTION
  when others then
    prg_ins_ge_auditoria( r_baudi );
END;
/

