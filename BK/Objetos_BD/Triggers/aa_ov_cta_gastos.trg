CREATE OR REPLACE TRIGGER IT."AA_OV_CTA_GASTOS"
  AFTER DELETE OR UPDATE
     ON OV_CTA_GASTOS
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 20/11/2007 a las 17:31:48 Hs.
  */
  v_registro OV_AUDITORIAS%ROWTYPE; -- Registro de la tabla OV_AUDITORIAS
BEGIN
  v_registro.tabla := 'OV_CTA_GASTOS';
  v_registro.clave := :old.nro_cuenta || '#' || to_char( :old.cod_transaccion) || '#' || to_char( :old.fec_ingreso, 'DD/MM/YYYY HH24:MI:SS');
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_MONEDA', :old.cod_moneda, :new.cod_moneda );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MONTO', :old.monto, :new.monto, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_VENCIMIENTO', :old.fec_vencimiento, :new.fec_vencimiento, 'F' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_ULT_PAGO', :old.fec_ult_pago, :new.fec_ult_pago, 'F' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_MODALIDAD', :old.cod_modalidad, :new.cod_modalidad, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'HOR_ULT_PAGO', :old.hor_ult_pago, :new.hor_ult_pago );

  -- Insertar tabla de auditoria
  prv_ins_ov_auditoria( v_registro );
EXCEPTION
  when others then
    prv_ins_ov_auditoria( v_registro );
END;
/

