CREATE OR REPLACE TRIGGER IT.AA_IG_SUB_CON_TRANSACCIONES
  AFTER DELETE OR UPDATE
     ON IG_SUB_CON_TRANSACCIONES
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 18/06/2007 a las 16:28:00 Hs.
  */
  v_registro IG_AUDITORIAS%ROWTYPE; -- Registro de la tabla IG_AUDITORIAS
BEGIN
  v_registro.tabla := 'IG_SUB_CON_TRANSACCIONES';
  v_registro.clave := to_char( :old.cod_concepto) || '#' || to_char( :old.cod_sub_concepto) || '#' || to_char( :old.cod_mod_padre) || '#' || to_char( :old.cod_mad_padre) || '#' || to_char( :old.cod_tra_padre) || '#' || to_char( :old.cod_modulo) || '#' || to_char( :old.cod_modalidad) || '#' || to_char( :old.cod_transaccion);
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle

  -- Insertar tabla de auditoria
  pri_ins_ig_auditoria( v_registro );
EXCEPTION
  when others then
    pri_ins_ig_auditoria( v_registro );
END;
/

