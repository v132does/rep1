CREATE OR REPLACE TRIGGER IT.AA_TA_LOG_SEC_FINTRA
  AFTER DELETE OR UPDATE
     ON TA_LOG_SEC_FINTRA
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 19/12/2019 a las 12:19:16 Hs.
  */
  v_registro TA_AUDITORIAS%ROWTYPE; -- Registro de la tabla TA_AUDITORIAS
BEGIN
  v_registro.tabla := 'TA_LOG_SEC_FINTRA';
  v_registro.clave := :old.cod_fintransac;
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_PROCESADORA', :old.cod_procesadora, :new.cod_procesadora );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_ORIGEN', :old.cod_origen, :new.cod_origen );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_VERIFICACION', :old.cod_verificacion, :new.cod_verificacion );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_COMPRADOR', :old.cod_comprador, :new.cod_comprador );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_COMERCIO', :old.cod_comercio, :new.cod_comercio );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'DES_COMERCIO', :old.des_comercio, :new.des_comercio );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'DIR_URL', :old.dir_url, :new.dir_url );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TIPO_COMERCIO', :old.tipo_comercio, :new.tipo_comercio );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_PAIS', :old.cod_pais, :new.cod_pais );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_TRANSACCION', :old.fec_transaccion, :new.fec_transaccion );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MTO_TRANSACCION', :old.mto_transaccion, :new.mto_transaccion, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_MON_TRA', :old.cod_mon_tra, :new.cod_mon_tra );
  --v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_FINTRA', :old.fec_fintra, :new.fec_fintra );
  --v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_TRANSACCION', :old.cod_transaccion, :new.cod_transaccion );
  --v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_INITRANSAC', :old.cod_initransac, :new.cod_initransac );

  -- Insertar tabla de auditoria
  prt_ins_ta_auditoria( v_registro );
EXCEPTION
  when others then
    prt_ins_ta_auditoria( v_registro );
END;
/

