CREATE OR REPLACE TRIGGER IT.AA_GE_CIE_CALENDARIOS
  AFTER DELETE OR UPDATE
     ON IT.GE_CIE_CALENDARIOS
    FOR EACH ROW
DECLARE
  rg_raudi GE_AUDITORIAS%ROWTYPE; -- Registro de la tabla GE_AUDITORIAS
BEGIN
  rg_raudi.tabla := 'GE_CIE_CALENDARIOS';
  rg_raudi.clave := to_char(:old.fecha, 'YYYYMMDD');
  rg_raudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );

  IF updating THEN
    rg_raudi.tip_novedad := 'M';
  ELSIF deleting THEN
    rg_raudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle de Cambios
  rg_raudi.detalle := pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'FECHA',            :OLD.FECHA,            :NEW.FECHA, 'F' );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'OBSERVACION',      :OLD.OBSERVACION,      :NEW.OBSERVACION );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'USU_INSERCION',    :OLD.USU_INSERCION,    :NEW.USU_INSERCION );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'FEC_INSERCION',    :OLD.FEC_INSERCION,    :NEW.FEC_INSERCION, 'F' );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'USU_MODIFICACION', :OLD.USU_MODIFICACION, :NEW.USU_MODIFICACION );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'FEC_MODIFICACION', :OLD.FEC_MODIFICACION, :NEW.FEC_MODIFICACION, 'F' );

  -- Insertar tabla de auditoria
  prg_ins_ge_auditoria( rg_raudi );
EXCEPTION
  WHEN OTHERS THEN
    prg_ins_ge_auditoria( rg_raudi );
END;
