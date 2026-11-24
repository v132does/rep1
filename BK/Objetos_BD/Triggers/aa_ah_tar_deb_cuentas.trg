CREATE OR REPLACE TRIGGER IT.AA_AH_TAR_DEB_CUENTAS
  AFTER DELETE OR UPDATE
     ON AH_TAR_DEB_CUENTAS
    FOR EACH ROW

DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 08/08/2005 a las 12:07:29 Hs.
  */
  v_registro AH_AUDITORIAS%ROWTYPE; -- Registro de la tabla AH_AUDITORIAS
BEGIN
  v_registro.tabla := 'AH_TAR_DEB_CUENTAS';
  v_registro.clave := :old.nro_cuenta || '#' || :old.cod_persona || '#' || :old.nro_cta_relacionada || '#' || to_char(:old.cod_ent_procesadora);
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle

  -- Insertar tabla de auditoria
  pra_ins_ah_auditoria( v_registro );
EXCEPTION
  when others then
    pra_ins_ah_auditoria( v_registro );
END;
/

