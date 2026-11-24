CREATE OR REPLACE TRIGGER IT.AA_BW_NOT_SUSCRIPCIONES
  AFTER DELETE OR UPDATE
       ON BW_NOT_SUSCRIPCIONES
    FOR EACH ROW
DECLARE
  /* 
  || Archivo  creado por el Generador de Triggers de Auditoría
  || Generado el 06/04/2015 a las 16:31:46 Hs.
  */
  v_registro BW_AUDITORIAS%ROWTYPE; -- Registro de la tabla BW_AUDITORIAS
BEGIN
  v_registro.tabla := 'BW_NOT_SUSCRIPCIONES';
  v_registro.clave := :old.cod_persona || '#' || :old.nro_cuenta || '#' || to_char( :old.cod_evento);
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'HORARIO', :old.horario, :new.horario );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MTO_MINIMO', :old.mto_minimo, :new.mto_minimo, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'ACTIVO', :old.activo, :new.activo );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FRECUENCIA', :old.frecuencia, :new.frecuencia );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_ULT_ENVIO', :old.fec_ult_envio, :new.fec_ult_envio, 'F' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'DATO1', :old.dato1, :new.dato1, 'M' );

  -- Insertar tabla de auditoria
  prw_ins_bw_auditoria( v_registro );
EXCEPTION
  when others then
    prw_ins_bw_auditoria( v_registro );
END;
/

