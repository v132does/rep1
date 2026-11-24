CREATE OR REPLACE TRIGGER IT.AA_GE_SPI_CAT_COMERCIOS
  AFTER DELETE OR UPDATE
     ON it.GE_SPI_CAT_COMERCIOS
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2022 - ITTI DIGITAL
  ||
  */
  rg_raudi GE_AUDITORIAS%ROWTYPE; -- Registro de la tabla GE_AUDITORIAS

BEGIN
  rg_raudi.tabla := 'GE_SPI_CAT_COMERCIOS';
  rg_raudi.clave := to_char( :old.COD_CATASTRO);
  rg_raudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    rg_raudi.tip_novedad := 'M';
  ELSIF deleting THEN
    rg_raudi.tip_novedad := 'E';
  END IF;

rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad,'COD_PERSONA', :old.COD_PERSONA, :new.COD_PERSONA);
rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad,'NRO_CUENTA', :old.NRO_CUENTA, :new.NRO_CUENTA);
rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad,'FEC_INICIO', :old.FEC_INICIO, :new.FEC_INICIO);
rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad,'FEC_VENCIMIENTO', :old.FEC_VENCIMIENTO, :new.FEC_VENCIMIENTO);
rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad,'ESTADO', :old.ESTADO, :new.ESTADO);
rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad,'OBSERVACION', :old.OBSERVACION, :new.OBSERVACION);
-- Insertar tabla de auditoria
prg_ins_ge_auditoria( rg_raudi );
EXCEPTION
  when others then
    prg_ins_ge_auditoria( rg_raudi );
END;
/

