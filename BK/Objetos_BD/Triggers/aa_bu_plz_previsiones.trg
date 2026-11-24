CREATE OR REPLACE TRIGGER IT.AA_BU_PLZ_PREVISIONES
  AFTER DELETE OR UPDATE
     ON BU_PLZ_PREVISIONES
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 05/11/2010 a las 09:57:55 Hs.
  */
  v_registro BU_AUDITORIAS%ROWTYPE; -- Registro de la tabla BU_AUDITORIAS
BEGIN
  v_registro.tabla := 'BU_PLZ_PREVISIONES';
  v_registro.clave := to_char( :old.cod_plazo);
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'DESCRIPCION', :old.descripcion, :new.descripcion );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'CAN_DIAS', :old.can_dias, :new.can_dias, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'POR_PREVISION', :old.por_prevision, :new.por_prevision, 'N' );

  -- Insertar tabla de auditoria
  pru_ins_bu_auditoria( v_registro );
EXCEPTION
  when others then
    pru_ins_bu_auditoria( v_registro );
END;
/

