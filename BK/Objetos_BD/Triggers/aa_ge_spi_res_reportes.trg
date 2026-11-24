CREATE OR REPLACE TRIGGER IT.aa_ge_spi_res_reportes
  AFTER DELETE OR UPDATE
     ON it.GE_SPI_RES_REPORTES
    FOR EACH ROW
DECLARE
  rg_raudi GE_AUDITORIAS%ROWTYPE; -- Registro de la tabla GE_AUDITORIAS
BEGIN
  rg_raudi.tabla := 'GE_SPI_RES_REPORTES';
  rg_raudi.clave := to_char( :old.nro_referencia);
  rg_raudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    rg_raudi.tip_novedad := 'M';
  ELSIF deleting THEN
    rg_raudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  rg_raudi.detalle := pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'NRO_REFERENCIA',:old.nro_referencia,:new.nro_referencia);
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'ID_PETICION',:old.id_peticion,:new.id_peticion);
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'ESTADO',:old.estado,:new.estado);
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'FEC_ULT_CONSULTA',:old.fec_ult_consulta,:new.fec_ult_consulta);
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'ERROR',:old.error,:new.error);
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'FEC_INSERCION',:old.fec_insercion,:new.fec_insercion);
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'USU_INSERCION',:old.usu_insercion,:new.usu_insercion);
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'FEC_MODIFICACION',:old.fec_modificacion,:new.fec_modificacion);
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'USU_MODIFICACION',:old.usu_modificacion,:new.usu_modificacion);

  -- Insertar tabla de auditoria
  prg_ins_ge_auditoria( rg_raudi );
EXCEPTION
  when others then
    prg_ins_ge_auditoria( rg_raudi );
END;
/

