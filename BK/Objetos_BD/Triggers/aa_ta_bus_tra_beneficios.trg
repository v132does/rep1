CREATE OR REPLACE TRIGGER IT.AA_TA_BUS_TRA_BENEFICIOS
  AFTER DELETE OR UPDATE
     ON TA_BUS_TRA_BENEFICIOS
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 22/08/2007 a las 09:33:44 Hs.
  */
  v_registro AF_AUDITORIAS%ROWTYPE; -- Registro de la tabla AF_AUDITORIAS
BEGIN
  v_registro.tabla := 'TA_BUS_TRA_BENEFICIOS';
  v_registro.clave := to_char( :old.identificador);
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'IDENTIFICADOR', :old.identificador, :new.identificador );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FECHA_TRANSACCION', :old.fecha_transaccion, :new.fecha_transaccion, 'F' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'CONFIRMACION_REINTEGRO', :old.confirmacion_reintegro, :new.confirmacion_reintegro );

  -- Insertar tabla de auditoria
  prt_ins_ta_auditoria( v_registro );
EXCEPTION
  when others then
    prt_ins_ta_auditoria( v_registro );
END;
/
