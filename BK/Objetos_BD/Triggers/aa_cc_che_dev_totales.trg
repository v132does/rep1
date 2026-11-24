CREATE OR REPLACE TRIGGER IT.AA_CC_CHE_DEV_TOTALES
  AFTER DELETE OR UPDATE
     ON CC_CHE_DEV_TOTALES
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 21/07/2006 a las 17:50:18 Hs.
  */
  v_registro CC_AUDITORIAS%ROWTYPE; -- Registro de la tabla CC_AUDITORIAS
BEGIN
  v_registro.tabla := 'CC_CHE_DEV_TOTALES';
  v_registro.clave := :old.cod_persona || '#' || :old.tipo;
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'CANTIDAD', :old.cantidad, :new.cantidad, 'N' );

  -- Insertar tabla de auditoria
  prc_ins_cc_auditoria( v_registro );
EXCEPTION
  when others then
    prc_ins_cc_auditoria( v_registro );
END;
/

