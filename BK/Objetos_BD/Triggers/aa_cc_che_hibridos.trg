CREATE OR REPLACE TRIGGER IT.AA_CC_CHE_HIBRIDOS
  AFTER DELETE OR UPDATE
     ON CC_CHE_HIBRIDOS
    FOR EACH ROW
DECLARE
  r_baudi CC_AUDITORIAS%ROWTYPE; -- Registro de la tabla CC_AUDITORIAS
BEGIN
  r_baudi.tabla := 'CC_CHE_HIBRIDOS';
  r_baudi.clave := :old.nro_cuenta || '#' || to_char( :old.nro_cheque);
  r_baudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    r_baudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_baudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle

  r_baudi.detalle := pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'COD_MONEDA', :old.cod_moneda, :new.cod_moneda  );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'SITUACION', :old.situacion, :new.situacion );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'MONTO', :old.monto, :new.monto, 'M' );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'NRO_CAJA', :old.nro_caja, :new.nro_caja, 'N' );
  -- Insertar tabla de auditoria
  prc_ins_cc_auditoria( r_baudi );
EXCEPTION
  when others then
    prc_ins_cc_auditoria( r_baudi );
END;
/

