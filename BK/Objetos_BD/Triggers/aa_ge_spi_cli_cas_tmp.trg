CREATE OR REPLACE TRIGGER IT.AA_GE_SPI_CLI_CAS_TMP
  AFTER DELETE OR UPDATE
     ON it.GE_SPI_CLI_CAS_TMP
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2021 - ITTI DIGITAL
  || Generado el 15/12/2021 a las 12:03:19 Hs.
  */
  rg_raudi GE_AUDITORIAS%ROWTYPE; -- Registro de la tabla GE_AUDITORIAS
BEGIN
  rg_raudi.tabla := 'GE_SPI_CLI_CAS_TMP';
  rg_raudi.clave := to_char( :old.nro_referencia);
  rg_raudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );

  IF updating THEN
    rg_raudi.tip_novedad := 'M';
  ELSIF deleting THEN
    rg_raudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  rg_raudi.detalle := pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'NRO_REFERENCIA', :OLD.NRO_REFERENCIA , :NEW.NRO_REFERENCIA );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'CLI_RECORDID',   :OLD.CLI_RECORDID,     :NEW.CLI_RECORDID );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'TIP_IDENTIFICADOR', :OLD.TIP_IDENTIFICADOR, :NEW.TIP_IDENTIFICADOR );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'VAL_IDENTIFICADOR', :OLD.VAL_IDENTIFICADOR, :NEW.VAL_IDENTIFICADOR );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'FEC_VTO_DOCUMENTO', :OLD.FEC_VTO_DOCUMENTO, :NEW.FEC_VTO_DOCUMENTO );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'RESIDENCIA',        :OLD.RESIDENCIA,      :NEW.RESIDENCIA );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'NOMBRE',            :OLD.NOMBRE,        :NEW.NOMBRE );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'APELLIDO',          :OLD.APELLIDO,      :NEW.APELLIDO );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'APODO',             :OLD.APODO,       :NEW.APODO );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'GENERO',            :OLD.GENERO,        :NEW.GENERO );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'FEC_NACIMIENTO',    :OLD.FEC_NACIMIENTO,    :NEW.FEC_NACIMIENTO );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'LUGAR_NACIMIENTO',  :OLD.LUGAR_NACIMIENTO,  :NEW.LUGAR_NACIMIENTO );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'DIRECCION',         :OLD.DIRECCION,     :NEW.DIRECCION );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'PAIS',              :OLD.PAIS,        :NEW.PAIS );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'CIUDAD',            :OLD.CIUDAD,        :NEW.CIUDAD );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'DEPARTAMENTO',      :OLD.DEPARTAMENTO,    :NEW.DEPARTAMENTO );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'INF_ADICIONAL',     :OLD.INF_ADICIONAL,   :NEW.INF_ADICIONAL );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'DET_ADICIONAL_PV',  :OLD.DET_ADICIONAL_PV,  :NEW.DET_ADICIONAL_PV );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'EST_CLIENTE',       :OLD.EST_CLIENTE,     :NEW.EST_CLIENTE );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'EST_SOLICITUD',     :OLD.EST_SOLICITUD,   :NEW.EST_SOLICITUD );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'ERROR',             :OLD.ERROR,       :NEW.ERROR );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'TIP_ACCION',       :OLD.TIP_ACCION,     :NEW.TIP_ACCION );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'TIP_CANAL',       :OLD.TIP_CANAL,     :NEW.TIP_CANAL);
  -- Insertar tabla de auditoria
  prg_ins_ge_auditoria( rg_raudi );
EXCEPTION
  when others then
    prg_ins_ge_auditoria( rg_raudi );
END;
/

