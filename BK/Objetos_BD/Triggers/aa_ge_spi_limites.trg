CREATE OR REPLACE TRIGGER IT.AA_GE_SPI_LIMITES
  AFTER DELETE OR UPDATE
     ON it.GE_SPI_LIMITES
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2022 - ITTI DIGITAL
  ||
  */
  rg_raudi GE_AUDITORIAS%ROWTYPE; -- Registro de la tabla GE_AUDITORIAS

BEGIN
  rg_raudi.tabla := 'GE_SPI_LIMITES';
  rg_raudi.clave := to_char( :old.nro_referencia);
  rg_raudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    rg_raudi.tip_novedad := 'M';
  ELSIF deleting THEN
    rg_raudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  rg_raudi.detalle := pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'NRO_REFERENCIA', :old.nro_referencia, :new.nro_referencia );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'NRO_REF_EXTERNA', :old.nro_ref_externa, :new.nro_ref_externa );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'CAN_LIM_ESTABLECIDO', :old.can_lim_establecido, :new.can_lim_establecido, 'M' );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'CAN_LIM_UTILIZADA', :old.can_lim_utilizada, :new.can_lim_utilizada, 'M' );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'POR_LIM_UTILIZADO', :old.por_lim_utilizado, :new.por_lim_utilizado, 'M' );

  -- Insertar tabla de auditoria
  prg_ins_ge_auditoria( rg_raudi );
EXCEPTION
  when others then
    prg_ins_ge_auditoria( rg_raudi );
END;
/

