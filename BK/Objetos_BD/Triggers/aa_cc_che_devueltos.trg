CREATE OR REPLACE TRIGGER IT.AA_CC_CHE_DEVUELTOS
  AFTER DELETE OR UPDATE
     ON CC_CHE_DEVUELTOS
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 21/07/2006 a las 17:49:09 Hs.
  */
  v_registro CC_AUDITORIAS%ROWTYPE; -- Registro de la tabla CC_AUDITORIAS
BEGIN
  v_registro.tabla := 'CC_CHE_DEVUELTOS';
  v_registro.clave := :old.nro_cuenta || '#' || to_char( :old.nro_cheque) || '#' || to_char( :old.fecha, 'DD/MM/YYYY') || '#' || :old.hora || '#' || :old.cod_usuario;
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_MONEDA', :old.cod_moneda, :new.cod_moneda );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MONTO', :old.monto, :new.monto, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_OFI_CAMARA', :old.cod_ofi_camara, :new.cod_ofi_camara, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_CAUSA', :old.cod_causa, :new.cod_causa, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TIPO', :old.tipo, :new.tipo );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MULTA', :old.multa, :new.multa, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'SAL_MULTA', :old.sal_multa, :new.sal_multa, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_BCO_RECEPTOR', :old.cod_bco_receptor, :new.cod_bco_receptor, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_CAJA', :old.nro_caja, :new.nro_caja, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'REGULARIZADO', :old.regularizado, :new.regularizado );

  -- Insertar tabla de auditoria
  prc_ins_cc_auditoria( v_registro );
EXCEPTION
  when others then
    prc_ins_cc_auditoria( v_registro );
END;
/

