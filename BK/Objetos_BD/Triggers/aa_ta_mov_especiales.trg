CREATE OR REPLACE TRIGGER IT.AA_TA_MOV_ESPECIALES
  AFTER DELETE OR UPDATE
     ON TA_MOV_ESPECIALES
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 23/09/2013 a las 16:58:55 Hs.
  */
  r_taudi TA_AUDITORIAS%ROWTYPE; -- Registro de la tabla TA_AUDITORIAS
BEGIN
  r_taudi.tabla := 'TA_MOV_ESPECIALES';
  r_taudi.clave := :old.ref_archivo || '#' || to_char( :old.fec_proceso, 'DD/MM/YYYY HH24:MI:SS');
  r_taudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    r_taudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_taudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  r_taudi.detalle := pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'NRO_CUENTA', :old.nro_cuenta, :new.nro_cuenta );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'NRO_TARJETA', :old.nro_tarjeta, :new.nro_tarjeta );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'DIG_VERIFICADOR', :old.dig_verificador, :new.dig_verificador, 'N' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'FEC_MOVIMIENTO', :old.fec_movimiento, :new.fec_movimiento, 'F' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'DES_MOVIMIENTO', :old.des_movimiento, :new.des_movimiento );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'MTO_OPERACION', :old.mto_operacion, :new.mto_operacion, 'M' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'TIP_AFECTACION', :old.tip_afectacion, :new.tip_afectacion );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'TIP_MOVIMIENTO', :old.tip_movimiento, :new.tip_movimiento );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'FINANCIA', :old.financia, :new.financia );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_USUARIO', :old.cod_usuario, :new.cod_usuario );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_ORIGEN', :old.cod_origen, :new.cod_origen, 'N' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'REF_PROCESO', :old.ref_proceso, :new.ref_proceso );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'FECHA', :old.fecha, :new.fecha, 'F' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'PROCESADO', :old.procesado, :new.procesado );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_USU_PROCESO', :old.cod_usu_proceso, :new.cod_usu_proceso );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'ERROR', :old.error, :new.error );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'MTO_IMPUESTO', :old.mto_impuesto, :new.mto_impuesto, 'M' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'MTO_INT_CORRIENTE', :old.mto_int_corriente, :new.mto_int_corriente, 'M' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'MTO_INT_MORA', :old.mto_int_mora, :new.mto_int_mora, 'M' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'MTO_INT_PUNITORIO', :old.mto_int_punitorio, :new.mto_int_punitorio, 'M' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'MTO_INT_CUOTA', :old.mto_int_cuota, :new.mto_int_cuota, 'M' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'MTO_IVA_CUO_5', :old.mto_iva_cuo_5, :new.mto_iva_cuo_5, 'M' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'MTO_IVA_AFE_PER_10', :old.mto_iva_afe_per_10, :new.mto_iva_afe_per_10, 'M' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'MTO_IVA_AFE_PER_5', :old.mto_iva_afe_per_5, :new.mto_iva_afe_per_5, 'M' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'MTO_IVA_AFE_CIE_10', :old.mto_iva_afe_cie_10, :new.mto_iva_afe_cie_10, 'M' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'MTO_IVA_AFE_CIE_5', :old.mto_iva_afe_cie_5, :new.mto_iva_afe_cie_5, 'M' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'CLASE', :old.clase, :new.clase );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_RUBRO', :old.cod_rubro, :new.cod_rubro );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'IND_REPROCESO', :old.ind_reproceso, :new.ind_reproceso );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'NRO_CTA_DEBITO', :old.nro_cta_debito, :new.nro_cta_debito );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'MTO_AMORTIZACION', :old.mto_amortizacion, :new.mto_amortizacion, 'M' );

  -- Insertar tabla de auditoria
  prt_ins_ta_auditoria( r_taudi );
EXCEPTION
  when others then
    prt_ins_ta_auditoria( r_taudi );
END;
/

