CREATE OR REPLACE TRIGGER IT.AA_CC_CHE_DEV_FIRMANTES
  AFTER DELETE OR UPDATE
     ON CC_CHE_DEV_FIRMANTES
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 21/07/2006 a las 17:49:54 Hs.
  */
  v_registro CC_AUDITORIAS%ROWTYPE; -- Registro de la tabla CC_AUDITORIAS
BEGIN
  v_registro.tabla := 'CC_CHE_DEV_FIRMANTES';
  v_registro.clave := :old.nro_cuenta || '#' || to_char( :old.nro_cheque) || '#' || :old.cod_persona;
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle

  -- Insertar tabla de auditoria
  prc_ins_cc_auditoria( v_registro );
EXCEPTION
  when others then
    prc_ins_cc_auditoria( v_registro );
END;
/

