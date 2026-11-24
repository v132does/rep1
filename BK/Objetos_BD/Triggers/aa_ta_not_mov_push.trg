CREATE OR REPLACE TRIGGER IT.AA_TA_NOT_MOV_PUSH
  AFTER DELETE OR UPDATE
     ON IT.TA_NOT_MOV_PUSH
    FOR EACH ROW
DECLARE
  r_taudi TA_AUDITORIAS%ROWTYPE; -- Registro de la tabla TA_AUDITORIAS
BEGIN
  r_taudi.tabla := 'TA_NOT_MOV_PUSH';
  r_taudi.clave := :old.nro_cuenta;
  r_taudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    r_taudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_taudi.tip_novedad := 'E';
  END IF;
  -- Registrar Detalle
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'ID_NOVEDAD', :old.id_novedad, :new.id_novedad);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'TIP_ACCION', :old.tip_accion, :new.tip_accion);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'ID_TRANSACCION', :old.id_transaccion, :new.id_transaccion);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'FEC_HOR_TRANSACCION', :old.fec_hor_transaccion, :new.fec_hor_transaccion);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'REASON', :old.reason, :new.reason);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'MARCA', :old.marca, :new.marca);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'ENTIDAD', :old.entidad, :new.entidad);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'NRO_CUENTA', :old.nro_cuenta, :new.nro_cuenta);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_PRODUCTO', :old.cod_producto, :new.cod_producto);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'AFINIDAD', :old.afinidad, :new.afinidad);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'ADICIONAL', :old.adicional, :new.adicional);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'NRO_TARJETA', :old.nro_tarjeta, :new.nro_tarjeta);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'PROVINCIA', :old.provincia, :new.provincia);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_PROVINCIA', :old.cod_provincia, :new.cod_provincia);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'VIA_ORIGEN', :old.via_origen, :new.via_origen);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'RED_ORIGEN', :old.red_origen, :new.red_origen);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'POS_ORIGEN', :old.pos_origen, :new.pos_origen);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'ING_ORIGEN', :old.ing_origen, :new.ing_origen);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'DEB_AUTOMATICO', :old.deb_automatico, :new.deb_automatico);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'ORI_INTERNACIONAL', :old.ori_internacional, :new.ori_internacional);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_CONCEPTO', :old.cod_concepto, :new.cod_concepto);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'PLAN', :old.plan, :new.plan);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'NRO_CUOTAS', :old.nro_cuotas, :new.nro_cuotas);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'TAS_INTERES', :old.tas_interes, :new.tas_interes);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_DIFERIMIENTO', :old.cod_diferimiento, :new.cod_diferimiento);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'FEC_DIFERIMIENTO', :old.fec_diferimiento, :new.fec_diferimiento);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'ID_INT_COMERCIO', :old.id_int_comercio, :new.id_int_comercio);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'EST_INT_COMERCIO', :old.est_int_comercio, :new.est_int_comercio);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_ISO', :old.cod_iso, :new.cod_iso);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'DES_ISO', :old.des_iso, :new.des_iso);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'ICA', :old.ica, :new.ica);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'MCC', :old.mcc, :new.mcc);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'TCC', :old.tcc, :new.tcc);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'TIP_ESTADO', :old.tip_estado, :new.tip_estado);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_ESTADO', :old.cod_estado, :new.cod_estado);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'FEC_ESTADO', :old.fec_estado, :new.fec_estado);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'ES_FORZADA', :old.es_forzada, :new.es_forzada);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'MONEDA', :old.moneda, :new.moneda);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'IMP_AUTORIZACION', :old.imp_autorizacion, :new.imp_autorizacion);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'IMP_TOT_TRANSACCION', :old.imp_tot_transaccion, :new.imp_tot_transaccion);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'IMP_CONVERTIDO', :old.imp_convertido, :new.imp_convertido);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'IMP_INTERES', :old.imp_interes, :new.imp_interes);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'IMP_INT_IVA', :old.imp_int_iva, :new.imp_int_iva);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'IMP_CARGOS', :old.imp_cargos, :new.imp_cargos);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'IMP_CAR_IVA', :old.imp_car_iva, :new.imp_car_iva);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'IMP_CAR_RG4240', :old.imp_car_rg4240, :new.imp_car_rg4240);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_MON_ORI_ISO', :old.cod_mon_ori_iso, :new.cod_mon_ori_iso);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'IMP_TOT_ORI_ISO', :old.imp_tot_ori_iso, :new.imp_tot_ori_iso);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_AUTORIZACION', :old.cod_autorizacion, :new.cod_autorizacion);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'CUP_AUTORIZACION', :old.cup_autorizacion, :new.cup_autorizacion);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'LOT_AUTORIZACION', :old.lot_autorizacion, :new.lot_autorizacion);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'NRO_AUTORIZACION', :old.nro_autorizacion, :new.nro_autorizacion);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'MOT_RECHAZO', :old.mot_rechazo, :new.mot_rechazo);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'DES_RECHAZO', :old.des_rechazo, :new.des_rechazo);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'NOR_FRA_RECHAZO', :old.nor_fra_rechazo, :new.nor_fra_rechazo);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'REG_FRA_RECHAZO', :old.reg_fra_rechazo, :new.reg_fra_rechazo);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_BILLETERA', :old.cod_billetera, :new.cod_billetera);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'ETIQUETAS', :old.etiquetas, :new.etiquetas);
  -- Insertar tabla de auditoria
  prt_ins_ta_auditoria( r_taudi );
EXCEPTION
  WHEN OTHERS THEN
    prt_ins_ta_auditoria( r_taudi );
END;
/
