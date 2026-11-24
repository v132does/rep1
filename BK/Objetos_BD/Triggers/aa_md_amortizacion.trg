CREATE OR REPLACE TRIGGER IT.AA_MD_AMORTIZACION
  AFTER DELETE OR UPDATE
     ON MD_AMORTIZACION
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 18/07/2008 a las 15:14:12 Hs.
  */
  v_registro MD_AUDITORIAS%ROWTYPE; -- Registro de la tabla MD_AUDITORIAS
BEGIN
  v_registro.tabla := 'MD_AMORTIZACION';
  v_registro.clave := :old.hora || '#' || to_char( :old.fecha, 'DD/MM/YYYY HH24:MI:SS') || '#' || :old.nro_cuenta || '#' || to_char( :old.nro_cuota);
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_VENCIMIENTO', :old.fec_vencimiento, :new.fec_vencimiento, 'F' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'ESTADO', :old.estado, :new.estado );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'SAL_CAP_PRESTAMO', :old.sal_cap_prestamo, :new.sal_cap_prestamo, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'SAL_INT_PRESTAMO', :old.sal_int_prestamo, :new.sal_int_prestamo, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'SAL_CAP_CUOTA', :old.sal_cap_cuota, :new.sal_cap_cuota, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'SAL_INT_CUOTA', :old.sal_int_cuota, :new.sal_int_cuota, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_ULT_PAGO', :old.fec_ult_pago, :new.fec_ult_pago, 'F' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'DIA_MORA', :old.dia_mora, :new.dia_mora, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MTO_CAPITAL', :old.mto_capital, :new.mto_capital, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MTO_INTERES', :old.mto_interes, :new.mto_interes, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MTO_INT_IVA', :old.mto_int_iva, :new.mto_int_iva, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MTO_INT_DESCONTADO', :old.mto_int_descontado, :new.mto_int_descontado, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_DOCUMENTO', :old.nro_documento, :new.nro_documento, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_ULT_DEVENGADO', :old.fec_ult_devengado, :new.fec_ult_devengado, 'F' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'DEV_NO_COBRADO', :old.dev_no_cobrado, :new.dev_no_cobrado, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'DEV_ACUMULADO', :old.dev_acumulado, :new.dev_acumulado, 'M' );

  -- Insertar tabla de auditoria
  prm_ins_md_auditoria( v_registro );
EXCEPTION
  when others then
    prm_ins_md_auditoria( v_registro );
END;
/

