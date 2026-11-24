CREATE OR REPLACE TRIGGER IT.AA_BW_CANJES
  AFTER INSERT OR UPDATE OR DELETE
    ON BW_CANJES
  FOR EACH ROW
DECLARE
  r_uaudi BW_AUDITORIAS%ROWTYPE; -- Registro de la tabla BW_AUDITORIAS
BEGIN
  
  r_uaudi.tabla := 'BW_CANJES';
  r_uaudi.clave := to_char( :old.nro_canje );
  r_uaudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  
  IF inserting THEN
    r_uaudi.tip_novedad := 'I';
  ELSIF updating THEN
    r_uaudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_uaudi.tip_novedad := 'E';
  END IF;
  
  -- Registrar Detalle
  r_uaudi.detalle := pae_cnf.fu_reg_auditoria( r_uaudi.tip_novedad, 'NRO_CANJE', :old.nro_canje, :new.nro_canje );
  r_uaudi.detalle := r_uaudi.detalle || pae_cnf.fu_reg_auditoria( r_uaudi.tip_novedad, 'NRO_TARJETA', :old.nro_tarjeta , :new.nro_tarjeta );
  r_uaudi.detalle := r_uaudi.detalle || pae_cnf.fu_reg_auditoria( r_uaudi.tip_novedad, 'COD_PERSONA', :old.cod_persona , :new.cod_persona );
  r_uaudi.detalle := r_uaudi.detalle || pae_cnf.fu_reg_auditoria( r_uaudi.tip_novedad, 'CAT_PRODUCTO', :old.cat_producto , :new.cat_producto );
  r_uaudi.detalle := r_uaudi.detalle || pae_cnf.fu_reg_auditoria( r_uaudi.tip_novedad, 'NOM_PRODUCTO', :old.nom_producto , :new.nom_producto );
  r_uaudi.detalle := r_uaudi.detalle || pae_cnf.fu_reg_auditoria( r_uaudi.tip_novedad, 'DES_PRODUCTO', :old.des_producto , :new.des_producto );
  r_uaudi.detalle := r_uaudi.detalle || pae_cnf.fu_reg_auditoria( r_uaudi.tip_novedad, 'TEL_CONTACTO', :old.tel_contacto , :new.tel_contacto );
  r_uaudi.detalle := r_uaudi.detalle || pae_cnf.fu_reg_auditoria( r_uaudi.tip_novedad, 'EMA_CONTACTO', :old.ema_contacto , :new.ema_contacto );
  r_uaudi.detalle := r_uaudi.detalle || pae_cnf.fu_reg_auditoria( r_uaudi.tip_novedad, 'EMA_DES_NOTIFICACION', :old.ema_des_notificacion , :new.ema_des_notificacion );
  r_uaudi.detalle := r_uaudi.detalle || pae_cnf.fu_reg_auditoria( r_uaudi.tip_novedad, 'USU_INSERCION', :old.usu_insercion , :new.usu_insercion );
  r_uaudi.detalle := r_uaudi.detalle || pae_cnf.fu_reg_auditoria( r_uaudi.tip_novedad, 'FEC_INSERCION', :old.fec_insercion , :new.fec_insercion , 'H' );
  r_uaudi.detalle := r_uaudi.detalle || pae_cnf.fu_reg_auditoria( r_uaudi.tip_novedad, 'USU_MODIFICACION', :old.usu_modificacion , :new.usu_modificacion );
  r_uaudi.detalle := r_uaudi.detalle || pae_cnf.fu_reg_auditoria( r_uaudi.tip_novedad, 'FEC_MODIFICACION', :old.fec_modificacion , :new.fec_modificacion , 'H' );
  r_uaudi.detalle := r_uaudi.detalle || pae_cnf.fu_reg_auditoria( r_uaudi.tip_novedad, 'CANTIDAD', :old.cantidad , :new.cantidad );
  r_uaudi.detalle := r_uaudi.detalle || pae_cnf.fu_reg_auditoria( r_uaudi.tip_novedad, 'PUNTOS', :old.puntos , :new.puntos );
  r_uaudi.detalle := r_uaudi.detalle || pae_cnf.fu_reg_auditoria( r_uaudi.tip_novedad, 'TEL_PROVEEDOR', :old.tel_proveedor , :new.tel_proveedor );
  r_uaudi.detalle := r_uaudi.detalle || pae_cnf.fu_reg_auditoria( r_uaudi.tip_novedad, 'SHOWROOM', :old.showroom , :new.showroom );
  r_uaudi.detalle := r_uaudi.detalle || pae_cnf.fu_reg_auditoria( r_uaudi.tip_novedad, 'DIRECCION', :old.direccion , :new.direccion);
  r_uaudi.detalle := r_uaudi.detalle || pae_cnf.fu_reg_auditoria( r_uaudi.tip_novedad, 'REC_AUTORIZADA', :old.rec_autorizada , :new.rec_autorizada );
  r_uaudi.detalle := r_uaudi.detalle || pae_cnf.fu_reg_auditoria( r_uaudi.tip_novedad, 'PER_AUTORIZADA', :old.per_autorizada , :new.per_autorizada );
  r_uaudi.detalle := r_uaudi.detalle || pae_cnf.fu_reg_auditoria( r_uaudi.tip_novedad, 'COD_TIP_AUTORIZADO', :old.cod_tip_autorizado , :new.cod_tip_autorizado );
  r_uaudi.detalle := r_uaudi.detalle || pae_cnf.fu_reg_auditoria( r_uaudi.tip_novedad, 'NRO_DOC_AUTORIZADO', :old.nro_doc_autorizado , :new.nro_doc_autorizado );
  r_uaudi.detalle := r_uaudi.detalle || pae_cnf.fu_reg_auditoria( r_uaudi.tip_novedad, 'HOR_INICIO', :old.hor_inicio , :new.hor_inicio );
  r_uaudi.detalle := r_uaudi.detalle || pae_cnf.fu_reg_auditoria( r_uaudi.tip_novedad, 'BEN_TITULAR', :old.ben_titular , :new.ben_titular );
  r_uaudi.detalle := r_uaudi.detalle || pae_cnf.fu_reg_auditoria( r_uaudi.tip_novedad, 'BENEFICIARIO', :old.beneficiario , :new.beneficiario );
  r_uaudi.detalle := r_uaudi.detalle || pae_cnf.fu_reg_auditoria( r_uaudi.tip_novedad, 'TURNO', :old.turno , :new.turno );
  r_uaudi.detalle := r_uaudi.detalle || pae_cnf.fu_reg_auditoria( r_uaudi.tip_novedad, 'SOL_IDA', :old.sol_ida , :new.sol_ida );
  r_uaudi.detalle := r_uaudi.detalle || pae_cnf.fu_reg_auditoria( r_uaudi.tip_novedad, 'FEC_SALIDA', :old.fec_salida , :new.fec_salida , 'F' );
  r_uaudi.detalle := r_uaudi.detalle || pae_cnf.fu_reg_auditoria( r_uaudi.tip_novedad, 'FEC_RETORNO', :old.fec_retorno , :new.fec_retorno , 'F' );
  r_uaudi.detalle := r_uaudi.detalle || pae_cnf.fu_reg_auditoria( r_uaudi.tip_novedad, 'FEC_FLEXIBLE', :old.fec_flexible , :new.fec_flexible );
  r_uaudi.detalle := r_uaudi.detalle || pae_cnf.fu_reg_auditoria( r_uaudi.tip_novedad, 'CLA_SERVICIO', :old.cla_servicio , :new.cla_servicio );
  r_uaudi.detalle := r_uaudi.detalle || pae_cnf.fu_reg_auditoria( r_uaudi.tip_novedad, 'CAN_NINOS', :old.can_ninos , :new.can_ninos );
  r_uaudi.detalle := r_uaudi.detalle || pae_cnf.fu_reg_auditoria( r_uaudi.tip_novedad, 'CAN_ADULTOS', :old.can_adultos , :new.can_adultos );
  r_uaudi.detalle := r_uaudi.detalle || pae_cnf.fu_reg_auditoria( r_uaudi.tip_novedad, 'LIN_AEREA', :old.lin_aerea , :new.lin_aerea );
  r_uaudi.detalle := r_uaudi.detalle || pae_cnf.fu_reg_auditoria( r_uaudi.tip_novedad, 'VERIFICADO', :old.verificado , :new.verificado );
  r_uaudi.detalle := r_uaudi.detalle || pae_cnf.fu_reg_auditoria( r_uaudi.tip_novedad, 'FECHA_VERIFICACION', :old.fec_verificacion , :new.fec_verificacion, 'F');
  r_uaudi.detalle := r_uaudi.detalle || pae_cnf.fu_reg_auditoria( r_uaudi.tip_novedad, 'COMERCIO', :old.comercio , :new.comercio );
  r_uaudi.detalle := r_uaudi.detalle || pae_cnf.fu_reg_auditoria( r_uaudi.tip_novedad, 'TIP_CANJE', :old.TIP_CANJE , :new.TIP_CANJE );
  r_uaudi.detalle := r_uaudi.detalle || pae_cnf.fu_reg_auditoria( r_uaudi.tip_novedad, 'OPE_CANJE', :old.OPE_CANJE , :new.OPE_CANJE );
  r_uaudi.detalle := r_uaudi.detalle || pae_cnf.fu_reg_auditoria( r_uaudi.tip_novedad, 'SUC_ENV_VOUCHER', :old.SUC_ENV_VOUCHER , :new.SUC_ENV_VOUCHER );
  r_uaudi.detalle := r_uaudi.detalle || pae_cnf.fu_reg_auditoria( r_uaudi.tip_novedad, 'SUC_CLIENTE', :old.SUC_CLIENTE , :new.SUC_CLIENTE );

  -- Insertar registro e tabla de auditoria
  prw_ins_bw_auditoria( r_uaudi );
  
EXCEPTION
  WHEN OTHERS THEN
    prw_ins_bw_auditoria( r_uaudi );
END;
/

