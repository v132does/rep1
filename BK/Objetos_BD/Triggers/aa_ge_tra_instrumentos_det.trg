CREATE OR REPLACE TRIGGER IT.AA_ge_tra_instrumentos_det
  AFTER DELETE OR UPDATE
     ON GE_TRA_INSTRUMENTOS_DET
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 07/09/2011 a las 16:52:37 Hs.
  */
  v_registro GE_AUDITORIAS%ROWTYPE; -- Registro de la tabla GE_AUDITORIAS
BEGIN
  v_registro.tabla := 'GE_TRA_INSTRUMENTOS_DET';
  v_registro.clave := :old.cod_tra_instrumento || '#' || to_char( :old.cod_tra_padre) || '#' || to_char( :old.cod_mod_padre) || '#' || to_char( :old.cod_mad_padre);
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle

  -- Insertar tabla de auditoria
  prg_ins_ge_auditoria( v_registro );
EXCEPTION
  when others then
    prg_ins_ge_auditoria( v_registro );
END;
/

