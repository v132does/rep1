CREATE OR REPLACE TRIGGER IT."AA_CS_CONTRATOS"
  AFTER DELETE OR UPDATE
     ON CS_CONTRATOS
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 03/03/2009 a las 14:03:15 Hs.
  */
  v_registro CS_AUDITORIAS%ROWTYPE; -- Registro de la tabla CS_AUDITORIAS
BEGIN
  v_registro.tabla := 'CS_CONTRATOS';
  v_registro.clave := :old.nro_contrato;
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo);
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_APERTURA', :old.fec_apertura, :new.fec_apertura, 'F' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'ESTADO', :old.estado, :new.estado );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TIP_PAGO', :old.tip_pago, :new.tip_pago );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_CTA_DEBITO', :old.nro_cta_debito, :new.nro_cta_debito );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_USU_AUTORIZADOR', :old.cod_usu_autorizador, :new.cod_usu_autorizador);
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'PER_PAGO', :old.per_pago, :new.per_pago, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_ULT_PAGO', :old.fec_ult_pago, :new.fec_ult_pago, 'F' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_SIG_PAGO', :old.fec_sig_pago, :new.fec_sig_pago, 'F' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MTO_ADEUDADO', :old.mto_adeudado, :new.mto_adeudado, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_CANCELACION', :old.fec_cancelacion, :new.fec_cancelacion, 'F' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_MONEDA', :old.cod_moneda, :new.cod_moneda );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_REG_ACCESO', :old.cod_reg_acceso, :new.cod_reg_acceso ); 

  -- Insertar tabla de auditoria
  prq_ins_cs_auditoria( v_registro );
EXCEPTION
  when others then
    prq_ins_cs_auditoria( v_registro );
END;
/

