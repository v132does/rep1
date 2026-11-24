CREATE OR REPLACE TRIGGER IT.AA_GE_SET_ORDENES
  AFTER DELETE OR UPDATE
     ON GE_SET_ORDENES
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 17/04/2013 a las 19:53:57 Hs.
  */
  r_gaudi GE_AUDITORIAS%ROWTYPE; -- Registro de la tabla AF_AUDITORIAS
BEGIN
  r_gaudi.tabla := 'GE_SET_ORDENES';
  r_gaudi.clave := to_char( :old.nro_secuencia);
  r_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    r_gaudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_gaudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  r_gaudi.detalle := pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'FEC_ORDEN', :old.fec_orden, :new.fec_orden, 'F' );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'FEC_PAGO', :old.fec_pago, :new.fec_pago, 'F' );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'NRO_CTA_BCP', :old.nro_cta_bcp, :new.nro_cta_bcp );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'MONTO', :old.monto, :new.monto, 'N' );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'TIP_ORDEN', :old.tip_orden, :new.tip_orden );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'COD_ERROR', :old.cod_error, :new.cod_error );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'MSG_ERROR', :old.msg_error, :new.msg_error );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'ESTADO', :old.estado, :new.estado );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'COD_SET', :old.cod_set, :new.cod_set, 'N' );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'FEC_RENVIO', :old.fec_renvio, :new.fec_renvio, 'F' );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'NRO_SEC_RENVIO', :old.nro_sec_renvio, :new.nro_sec_renvio, 'N' );

  -- Insertar tabla de auditoria
  prg_ins_ge_auditoria( r_gaudi );
EXCEPTION
  when others then
    prg_ins_ge_auditoria( r_gaudi );
END;
/

