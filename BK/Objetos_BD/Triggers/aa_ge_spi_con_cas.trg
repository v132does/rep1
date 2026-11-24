CREATE OR REPLACE TRIGGER IT.AA_GE_SPI_CON_CAS
  AFTER DELETE OR UPDATE
     ON it.GE_SPI_CON_CAS
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2021 - ITTI DIGITAL
  || Generado el 15/12/2021 a las 12:03:19 Hs.
  */
  rg_raudi GE_AUDITORIAS%ROWTYPE; -- Registro de la tabla GE_AUDITORIAS
BEGIN
  rg_raudi.tabla := 'GE_SPI_CON_CAS';
  rg_raudi.clave := to_char( :old.nro_referencia);
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
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'TIP_CONSULTA ', :OLD.TIP_CONSULTA, :NEW.TIP_CONSULTA );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'FECHA ', :OLD.FECHA, :NEW.FECHA, 'F'  );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'HORA ', :OLD.HORA, :NEW.HORA );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'EST_SOLICITUD ', :OLD.EST_SOLICITUD, :NEW.EST_SOLICITUD );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'COD_SWI_PTE_SOLICITANTE ', :OLD.COD_SWI_PTE_SOLICITANTE, :NEW.COD_SWI_PTE_SOLICITANTE );
  -- Insertar tabla de auditoria
  prg_ins_ge_auditoria( rg_raudi );
EXCEPTION
  when others then
    prg_ins_ge_auditoria( rg_raudi );
END;
/

