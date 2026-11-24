CREATE OR REPLACE TRIGGER IT.AA_GE_PROCESOS_DET_HIS
  AFTER DELETE OR UPDATE
     ON GE_PROCESOS_DET_HIS
    FOR EACH ROW
DECLARE
  r_gaudi GE_AUDITORIAS%ROWTYPE; -- Registro de la tabla GE_AUDITORIAS
BEGIN
  r_gaudi.tabla := 'GE_PROCESOS_DET_HIS';
  r_gaudi.clave := to_char( :old.cod_proceso) || '#' || to_char( :old.nro_orden);
  r_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    r_gaudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_gaudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  r_gaudi.detalle := pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'FECHA', :old.fecha, :new.fecha );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'COD_PROCESO', :old.cod_proceso, :new.cod_proceso );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'NRO_ORDEN', :old.nro_orden, :new.nro_orden );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'COD_PROGRAMA', :old.cod_programa, :new.cod_programa );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'FRECUENCIA', :old.frecuencia, :new.frecuencia );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'HOR_INICIO', :old.hor_inicio, :new.hor_inicio );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'HOR_FIN', :old.hor_fin, :new.hor_fin );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'DURACION', :old.duracion, :new.duracion );
  -- Insertar tabla de auditoria
  prg_ins_ge_auditoria( r_gaudi );
EXCEPTION
  when others then
    prg_ins_ge_auditoria( r_gaudi );
END;
/
