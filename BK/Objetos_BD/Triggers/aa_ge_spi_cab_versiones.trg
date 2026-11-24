CREATE OR REPLACE TRIGGER IT.AA_GE_SPI_CAB_VERSIONES
  AFTER DELETE OR UPDATE
     ON it.GE_SPI_CAB_VERSIONES
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2021 - ITTI DIGITAL
  || Generado el 12/01/2022 a las 18:19:10 Hs.
  */
  rg_raudi GE_AUDITORIAS%ROWTYPE; -- Registro de la tabla GE_AUDITORIAS
BEGIN
  rg_raudi.tabla := 'GE_SPI_CAB_VERSIONES';
  rg_raudi.clave := to_char( :old.tipo_msj);
  rg_raudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    rg_raudi.tip_novedad := 'M';
  ELSIF deleting THEN
    rg_raudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  rg_raudi.detalle := pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'TIPO_MSJ', :old.tipo_msj, :new.tipo_msj );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'VERSION', :old.version, :new.version );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'ESTADO', :old.estado, :new.estado );



  -- Insertar tabla de auditoria
  prg_ins_ge_auditoria( rg_raudi );
EXCEPTION
  when others then
    prg_ins_ge_auditoria( rg_raudi );
END;
/

