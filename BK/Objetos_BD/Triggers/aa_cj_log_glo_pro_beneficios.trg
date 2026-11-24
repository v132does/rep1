CREATE OR REPLACE TRIGGER IT.AA_CJ_LOG_GLO_PRO_BENEFICIOS
  AFTER DELETE OR UPDATE
     ON CJ_LOG_GLO_PRO_BENEFICIOS
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 22/08/2007 a las 09:33:44 Hs.
  */
  v_registro AF_AUDITORIAS%ROWTYPE; -- Registro de la tabla AF_AUDITORIAS
BEGIN
  v_registro.tabla := 'CJ_LOG_GLO_PRO_BENEFICIOS';
  v_registro.clave := to_char( :old.nro_transaccion);
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_TRANSACCION', :old.nro_transaccion, :new.nro_transaccion);
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_SISTEMA', :old.fec_sistema, :new.fec_sistema, 'F' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'CONFIRMACION_REINTEGRO', :old.confirmacion_reintegro, :new.confirmacion_reintegro);

  -- Insertar tabla de auditoria
  prj_ins_cj_auditoria( v_registro );
EXCEPTION
  when others then
    prj_ins_cj_auditoria( v_registro );
END;
/
