CREATE OR REPLACE TRIGGER IT.AA_SB_ENC_CIRCULAR254
  AFTER DELETE OR UPDATE
     ON "IT"."SB_ENC_CIRCULAR254"
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 29/11/2022 a las 14:50:19 Hs.
  */
  v_registro SB_AUDITORIAS%ROWTYPE; -- Registro de la tabla SB_AUDITORIAS
BEGIN
  v_registro.tabla := 'SB_ENC_CIRCULAR254';
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  v_registro.clave := to_char(:old.fecha) || '#' || to_char(:old.nro_registro);
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FECHA', :old.fecha, :new.fecha, 'F' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_REGISTRO', :old.nro_registro, :new.nro_registro, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_MONEDA', :old.cod_moneda, :new.cod_moneda, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_CUENTA', :old.cod_cuenta, :new.cod_cuenta, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_SUBCUENTA', :old.cod_subcuenta, :new.cod_subcuenta, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'PLAZO', :old.plazo, :new.plazo, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'RANGO', :old.rango, :new.rango, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'CAN_CUENTA', :old.can_cuenta, :new.can_cuenta, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'IMPORTE', :old.importe, :new.importe, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'CTA_DEPARTAMENTO', :old.cta_departamento, :new.cta_departamento, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'ENC_EXONERADO', :old.enc_exonerado, :new.enc_exonerado, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_REFERENCIA', :old.nro_referencia, :new.nro_referencia, 'N' );

  -- Insertar tabla de auditoria
  prs_ins_sb_auditoria( v_registro );
EXCEPTION
  when others then
    prs_ins_sb_auditoria( v_registro );
END;
/

