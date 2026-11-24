CREATE OR REPLACE TRIGGER IT.AA_AH_DEV_BON_SUBORDINADOS
  AFTER DELETE OR UPDATE
     ON AH_DEV_BON_SUBORDINADOS
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 12/01/2012 a las 19:02:48 Hs.
  */
  r_baudi AH_AUDITORIAS%ROWTYPE; -- Registro de la tabla AH_AUDITORIAS
BEGIN
  r_baudi.tabla := 'AH_DEV_BON_SUBORDINADOS';
  r_baudi.clave := :old.nro_cuenta;
  r_baudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    r_baudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_baudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  r_baudi.detalle := pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'COD_MODULO', :old.cod_modulo, :new.cod_modulo, 'N' );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'COD_MODALIDAD', :old.cod_modalidad, :new.cod_modalidad, 'N' );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'FECHA', :old.fecha, :new.fecha, 'F' );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'HORA', :old.hora, :new.hora );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'COD_USUARIO', :old.cod_usuario, :new.cod_usuario );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'NRO_SECUENCIA', :old.nro_secuencia, :new.nro_secuencia, 'N' );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'MONTO', :old.monto, :new.monto, 'M' );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'MTO_EQU_LOCAL', :old.mto_equ_local, :new.mto_equ_local, 'M' );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'MTO_INT_ACUMULADO', :old.mto_int_acumulado, :new.mto_int_acumulado, 'M' );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'COD_MONEDA', :old.cod_moneda, :new.cod_moneda );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'COD_TRANSACCION', :old.cod_transaccion, :new.cod_transaccion, 'N' );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'COD_TRA_ALTA', :old.cod_tra_alta, :new.cod_tra_alta, 'N' );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'COD_TRA_GANANCIA', :old.cod_tra_ganancia, :new.cod_tra_ganancia, 'N' );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'CONCEPTO', :old.concepto, :new.concepto );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'FEC_INICIO', :old.fec_inicio, :new.fec_inicio, 'F' );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'FEC_VENCIMIENTO', :old.fec_vencimiento, :new.fec_vencimiento, 'F' );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'ESTADO', :old.estado, :new.estado );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'MTO_DEV_ANTERIOR', :old.mto_dev_anterior, :new.mto_dev_anterior, 'M' );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'MTO_DEV_ACTUAL', :old.mto_dev_actual, :new.mto_dev_actual, 'M' );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'MTO_DEV_ACUMULADO', :old.mto_dev_acumulado, :new.mto_dev_acumulado, 'M' );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'CAN_DIA_ACTUAL', :old.can_dia_actual, :new.can_dia_actual, 'N' );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'CAN_DIA_ANTERIOR', :old.can_dia_anterior, :new.can_dia_anterior, 'N' );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'COD_OFICINA', :old.cod_oficina, :new.cod_oficina, 'N' );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'FEC_ULT_PROCESO', :old.fec_ult_proceso, :new.fec_ult_proceso, 'F' );

  -- Insertar tabla de auditoria
  pra_ins_ah_auditoria( r_baudi );
EXCEPTION
  when others then
    pra_ins_ah_auditoria( r_baudi );
END;
/

