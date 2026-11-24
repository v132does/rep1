CREATE OR REPLACE TRIGGER IT.AA_CC_CHE_RECHAZADOS_DET
  AFTER DELETE OR UPDATE
     ON CC_CHE_RECHAZADOS_DET
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 09/08/2017 a las 09:13:06 Hs.
  */
  v_registro CC_AUDITORIAS%ROWTYPE; -- Registro de la tabla CC_AUDITORIAS
BEGIN
  v_registro.tabla := 'CC_CHE_RECHAZADOS_DET';
  v_registro.clave := to_char( :old.fec_proceso, 'DD/MM/YYYY HH24:MI:SS') || '#' || to_char( :old.cod_bco_emisor) || '#' || to_char( :old.cod_cau_devolucion) || '#' || to_char( :old.nro_cheque);
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'CTA_LIBRADORA', :old.cta_libradora, :new.cta_libradora );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_CAU_DEV_BCP', :old.cod_cau_dev_bcp, :new.cod_cau_dev_bcp, 'N' );

  -- Insertar tabla de auditoria
  prc_ins_cc_auditoria( v_registro );
EXCEPTION
  when others then
    prc_ins_cc_auditoria( v_registro );
END;
/

