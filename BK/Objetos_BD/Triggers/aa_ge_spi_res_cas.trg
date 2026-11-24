CREATE OR REPLACE TRIGGER IT.AA_GE_SPI_RES_CAS
  AFTER DELETE OR UPDATE
     ON it.GE_SPI_RES_CAS
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2021 - ITTI DIGITAL
  || Generado el 15/12/2021 a las 12:03:19 Hs.
  */
  rg_raudi GE_AUDITORIAS%ROWTYPE; -- Registro de la tabla GE_AUDITORIAS
BEGIN
  rg_raudi.tabla := 'GE_SPI_RES_CAS';
  rg_raudi.clave := to_char( :old.nro_referencia);
  rg_raudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );

  IF updating THEN
    rg_raudi.tip_novedad := 'M';
  ELSIF deleting THEN
    rg_raudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  rg_raudi.detalle := pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad,'NRO_REFERENCIA',              :OLD.NRO_REFERENCIA , :NEW.NRO_REFERENCIA );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad,'TIP_IDENTIFICADOR',   :OLD.TIP_IDENTIFICADOR, :NEW.TIP_IDENTIFICADOR );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad,'VAL_IDENTIFICADOR',   :OLD.VAL_IDENTIFICADOR, :NEW.VAL_IDENTIFICADOR );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad,'COD_PERSONA',       :OLD.COD_PERSONA, :NEW.COD_PERSONA);
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad,'TIP_CONSULTA',      :OLD.TIP_CONSULTA, :NEW.TIP_CONSULTA );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad,'FECHA',         :OLD.FECHA, :NEW.FECHA,'F'  );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad,'HORA',        :OLD.HORA, :NEW.HORA );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad,'VAL_CLI_RECORDID',  :OLD.VAL_CLI_RECORDID, :NEW.VAL_CLI_RECORDID );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad,'VAL_CTA_RECORDID',  :OLD.VAL_CTA_RECORDID, :NEW.VAL_CTA_RECORDID );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad,'VAL_ALIAS_RECORDID',  :OLD.VAL_ALIAS_RECORDID, :NEW.VAL_ALIAS_RECORDID );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad,'FEC_VTO_DOCUMENTO',   :OLD.FEC_VTO_DOCUMENTO, :NEW.FEC_VTO_DOCUMENTO,'F' );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad,'NOMBRE',        :OLD.NOMBRE, :NEW.NOMBRE );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad,'APELLIDO',      :OLD.APELLIDO, :NEW.APELLIDO );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad,'NRO_CUENTA',      :OLD.NRO_CUENTA, :NEW.NRO_CUENTA );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad,'TIP_CUENTA',      :OLD.TIP_CUENTA, :NEW.TIP_CUENTA );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad,'COD_MON_CTA',     :OLD.COD_MON_CTA, :NEW.COD_MON_CTA );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad,'FEC_APERTURA',    :OLD.FEC_APERTURA, :NEW.FEC_APERTURA,'F' );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad,'FEC_CANCELACION',   :OLD.FEC_CANCELACION, :NEW.FEC_CANCELACION,'F' );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad,'CTA_DEFECTO',     :OLD.CTA_DEFECTO, :NEW.CTA_DEFECTO );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad,'ERROR',         :OLD.ERROR, :NEW.ERROR );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad,'COD_SWI_PARTICIPANTE ',         :OLD.COD_SWI_PARTICIPANTE, :NEW.COD_SWI_PARTICIPANTE );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad,'TIP_DOC_CLIENTE ',         :OLD.TIP_DOC_CLIENTE, :NEW.TIP_DOC_CLIENTE );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad,'NRO_DOC_CLIENTE ',         :OLD.NRO_DOC_CLIENTE, :NEW.NRO_DOC_CLIENTE );
  

  -- Insertar tabla de auditoria
  prg_ins_ge_auditoria( rg_raudi );
EXCEPTION
  when others then
    prg_ins_ge_auditoria( rg_raudi );
END;
/

