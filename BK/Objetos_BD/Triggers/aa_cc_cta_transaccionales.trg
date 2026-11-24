CREATE OR REPLACE TRIGGER IT.AA_CC_CTA_TRANSACCIONALES
  AFTER DELETE OR UPDATE
     ON CC_CTA_TRANSACCIONALES
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 27/06/2018 a las 09:26:54 Hs.
  */
  r_caudi CC_AUDITORIAS%ROWTYPE; -- Registro de la tabla CC_AUDITORIAS
BEGIN
  r_caudi.tabla := 'CC_CTA_TRANSACCIONALES';
  r_caudi.clave := :old.nro_cuenta;
  r_caudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    r_caudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_caudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  r_caudi.detalle := pae_cnf.fu_reg_auditoria( r_caudi.tip_novedad, 'COD_MODULO', :old.cod_modulo, :new.cod_modulo, 'N' );
  r_caudi.detalle := r_caudi.detalle || pae_cnf.fu_reg_auditoria( r_caudi.tip_novedad, 'COD_MODALIDAD', :old.cod_modalidad, :new.cod_modalidad, 'N' );
  r_caudi.detalle := r_caudi.detalle || pae_cnf.fu_reg_auditoria( r_caudi.tip_novedad, 'TIP_CTA_TRANSACCIONAL', :old.tip_cta_transaccional, :new.tip_cta_transaccional );
  r_caudi.detalle := r_caudi.detalle || pae_cnf.fu_reg_auditoria( r_caudi.tip_novedad, 'ACTIVO', :old.activo, :new.activo );
  r_caudi.detalle := r_caudi.detalle || pae_cnf.fu_reg_auditoria( r_caudi.tip_novedad, 'FEC_ACTIVACION', :old.fec_activacion, :new.fec_activacion, 'F' );
  r_caudi.detalle := r_caudi.detalle || pae_cnf.fu_reg_auditoria( r_caudi.tip_novedad, 'FEC_INACTIVACION', :old.fec_inactivacion, :new.fec_inactivacion, 'F' );

  -- Insertar tabla de auditoria
  prc_ins_cc_auditoria( r_caudi );
EXCEPTION
  when others then
    prc_ins_cc_auditoria( r_caudi );
END;
/

