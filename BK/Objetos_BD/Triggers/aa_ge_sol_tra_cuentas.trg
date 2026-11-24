CREATE OR REPLACE TRIGGER IT.AA_GE_SOL_TRA_CUENTAS
  AFTER DELETE OR UPDATE
     ON "IT"."GE_SOL_TRA_CUENTAS"
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditorka
  || (c) 2005 - IT Consultores
  || Generado el 29/12/2014 a las 10:06:19 Hs.
  */
  rg_raudi GE_AUDITORIAS%ROWTYPE; -- Registro de la tabla GE_AUDITORIAS
BEGIN
  rg_raudi.tabla := 'GE_SOL_TRA_CUENTAS';
  rg_raudi.clave := to_char( :old.Nro_Transferencia);
  rg_raudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    rg_raudi.tip_novedad := 'M';
  ELSIF deleting THEN
    rg_raudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  rg_raudi.detalle := pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'FEC_INGRESO', :old.FEC_INGRESO, :new.FEC_INGRESO,'F' );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'MONTO', :old.MONTO, :new.MONTO, 'M' );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'COD_MONEDA', :old.COD_MONEDA, :new.COD_MONEDA );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'NRO_CTA_DEBITO', :old.NRO_CTA_DEBITO, :new.NRO_CTA_DEBITO );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'COD_PERSONA', :old.COD_PERSONA, :new.COD_PERSONA );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'NOM_BENEFICIARIO', :old.NOM_BENEFICIARIO, :new.NOM_BENEFICIARIO);
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'NRO_TELEFONO', :old.NRO_TELEFONO, :new.NRO_TELEFONO );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'NRO_CTA_CREDITO', :old.NRO_CTA_CREDITO, :new.NRO_CTA_CREDITO );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'FEC_CREDITO', :old.FEC_CREDITO, :new.FEC_CREDITO, 'F' );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'HORA_CREDITO', :old.HORA_CREDITO, :new.HORA_CREDITO);
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'FEC_INGRESO', :old.fec_ingreso, :new.fec_ingreso, 'F' );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'ESTADO', :old.ESTADO, :new.ESTADO );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'TIPO_DOC_BENEF', :old.TIPO_DOC_BENEF, :new.TIPO_DOC_BENEF);
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'NRO_DOC_BENEF', :old.NRO_DOC_BENEF, :new.NRO_DOC_BENEF );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'CONCEPTO', :old.CONCEPTO, :new.CONCEPTO );
 
  -- Insertar tabla de auditoria
  prg_ins_ge_auditoria( rg_raudi );
EXCEPTION
  when others then
    prg_ins_ge_auditoria( rg_raudi );
END;
/

