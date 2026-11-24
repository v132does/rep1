CREATE OR REPLACE TRIGGER IT.AA_GE_DEU_COM_CLIENTES
  AFTER DELETE OR UPDATE
     ON IT.GE_DEU_COM_CLIENTES
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditorka
  || (c) 2005 - IT Consultores
  || Generado el 29/12/2014 a las 10:06:19 Hs.
  */
  rg_raudi GE_AUDITORIAS%ROWTYPE; -- Registro de la tabla GE_AUDITORIAS
BEGIN
  rg_raudi.tabla := 'GE_DEU_COM_CLIENTES';
  rg_raudi.clave := nvl(:old.NRO_CTA_DEBITO,:new.NRO_CTA_DEBITO);
  rg_raudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    rg_raudi.tip_novedad := 'M';
  ELSIF deleting THEN
    rg_raudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  rg_raudi.detalle := pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'FEC_OPERACION', :old.FEC_OPERACION, :new.FEC_OPERACION,'F' );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'NRO_CTA_DEBITO', :old.NRO_CTA_DEBITO, :new.NRO_CTA_DEBITO );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'BENEFICIARIO', :old.BENEFICIARIO, :new.BENEFICIARIO );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'COD_MODALIDAD', :old.NRO_LOTE, :new.NRO_LOTE, 'N' );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'TIP_DOCUMENTO', :old.TIP_DOCUMENTO, :new.TIP_DOCUMENTO);
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'NRO_DOCUMENTO', :old.NRO_DOCUMENTO, :new.NRO_DOCUMENTO);
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'COD_MONEDA', :old.COD_MONEDA, :new.COD_MONEDA );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'MTO_TOT_PEND', :old.MTO_TOT_PEND, :new.MTO_TOT_PEND,'N' );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'ESTADO', :old.ESTADO, :new.ESTADO );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'COD_ENTE', :old.COD_ENTE, :new.COD_ENTE, 'N' );

    -- Insertar tabla de auditoria
  prg_ins_ge_auditoria( rg_raudi );
EXCEPTION
  when others then
    prg_ins_ge_auditoria( rg_raudi );
END;
/

