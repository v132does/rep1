CREATE OR REPLACE TRIGGER IT.AA_LC_INF_DATATEC
  AFTER DELETE OR UPDATE
     ON LC_INF_DATATEC
    FOR EACH ROW
DECLARE
  r_gaudi AF_AUDITORIAS%ROWTYPE; -- Registro de la tabla AF_AUDITORIAS
BEGIN
  r_gaudi.tabla := 'LC_INF_DATATEC';
  r_gaudi.clave := :old.id_datatec;
  r_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    r_gaudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_gaudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  r_gaudi.detalle := pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'TIP_OPERACION', :old.tip_operacion, :new.tip_operacion );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'MERCADO', :old.mercado, :new.mercado );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'ORIGEN', :old.origen, :new.origen );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'OPERACION', :old.operacion, :new.operacion );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'USU_DATATEC', :old.usu_datatec, :new.usu_datatec );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'FEC_TRANSACCION', :old.fec_transaccion, :new.fec_transaccion);
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'HOR_TRANSACCION', :old.hor_transaccion, :new.hor_transaccion );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'FEC_INI_CONTRATO', :old.fec_ini_contrato, :new.fec_ini_contrato );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'FEC_FIN_CONTRATO', :old.fec_fin_contrato, :new.fec_fin_contrato );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'TIP_REGISTRO', :old.tip_registro, :new.tip_registro );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'TIP_TASA', :old.tip_tasa, :new.tip_tasa );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'TAS_INTERES', :old.tas_interes, :new.tas_interes );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'VAL_AMORTIZACION', :old.val_amortizacion, :new.val_amortizacion );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'PRECIO', :old.precio, :new.precio );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'MONTO', :old.monto, :new.monto );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'COD_MONEDA', :old.cod_moneda, :new.cod_moneda );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'COD_MON_CONTRAPARTE', :old.cod_mon_contraparte, :new.cod_mon_contraparte );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'TIP_INDENTIFICACION', :old.tip_indentificacion, :new.tip_indentificacion );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'ID_CONTRAPARTE', :old.id_contraparte, :new.id_contraparte );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'OBSERVACION', :old.observacion, :new.observacion );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'CUMPLIMIENTO', :old.cumplimiento, :new.cumplimiento );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'SIS_ORIGEN', :old.sis_origen, :new.sis_origen );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'CIUDAD', :old.ciudad, :new.ciudad );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'ESTADO', :old.estado, :new.estado );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'USU_INSERCION', :old.usu_insercion, :new.usu_insercion );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'FEC_INSERCION', :old.fec_insercion, :new.fec_insercion );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'USU_MODIFICACION', :old.usu_modificacion, :new.usu_modificacion );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'FEC_MODIFICACION', :old.fec_modificacion, :new.fec_modificacion );

  -- Insertar tabla de auditoria
  prf_ins_af_auditoria( r_gaudi );
EXCEPTION
  when others then
    prf_ins_af_auditoria( r_gaudi );
END;
/

