CREATE OR REPLACE TRIGGER IT.AA_GE_SPI_ALI_CAS_TMP
  AFTER DELETE OR UPDATE
     ON it.GE_SPI_ALI_CAS_TMP
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2021 - ITTI DIGITAL
  || Generado el 15/12/2021 a las 12:03:19 Hs.
  */
  rg_raudi GE_AUDITORIAS%ROWTYPE; -- Registro de la tabla GE_AUDITORIAS
BEGIN
  rg_raudi.tabla := 'GE_SPI_ALI_CAS_TMP';
  rg_raudi.clave := to_char( :old.NRO_REFERENCIA);
  rg_raudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );

  IF updating THEN
    rg_raudi.tip_novedad := 'M';
  ELSIF deleting THEN
    rg_raudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  rg_raudi.detalle := pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'NRO_REFERENCIA', :OLD.NRO_REFERENCIA , :NEW.NRO_REFERENCIA );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'TIP_IDENTIFICADOR ', :OLD.TIP_IDENTIFICADOR, :NEW.TIP_IDENTIFICADOR );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'VAL_IDENTIFICADOR ', :OLD.VAL_IDENTIFICADOR, :NEW.VAL_IDENTIFICADOR );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'COD_PERSONA ', :OLD.COD_PERSONA, :NEW.COD_PERSONA);
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'FEC_REGISTRO ', :OLD.FEC_REGISTRO, :NEW.FEC_REGISTRO,'F' );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'FEC_VEN_REGISTRO ', :OLD.FEC_VEN_REGISTRO, :NEW.FEC_VEN_REGISTRO, 'F'  );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'NRO_CTA_SOLICITANTE ', :OLD.NRO_CTA_SOLICITANTE, :NEW.NRO_CTA_SOLICITANTE );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'EST_ALIAS ', :OLD.EST_ALIAS, :NEW.EST_ALIAS );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'EST_SOLICITUD ', :OLD.EST_SOLICITUD, :NEW.EST_SOLICITUD );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'CLI_RECORDID ', :OLD.CLI_RECORDID, :NEW.CLI_RECORDID );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'ALI_RECORDID ', :OLD.ALI_RECORDID, :NEW.ALI_RECORDID );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'CUE_RECORDID ', :OLD.CUE_RECORDID, :NEW.CUE_RECORDID );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'CTA_POR_DEFECTO ', :OLD.CTA_POR_DEFECTO, :NEW.CTA_POR_DEFECTO );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'ERROR ', :OLD.ERROR, :NEW.ERROR );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'TIP_ACCION ', :OLD.TIP_ACCION, :NEW.TIP_ACCION );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'TIP_CANAL ', :OLD.TIP_CANAL , :NEW.TIP_CANAL );
  

  -- Insertar tabla de auditoria
  prg_ins_ge_auditoria( rg_raudi );
EXCEPTION
  when others then
    prg_ins_ge_auditoria( rg_raudi );
END;
/

