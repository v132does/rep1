CREATE OR REPLACE TRIGGER IT.AA_TA_LOG_SEC_FINTRARES
  AFTER DELETE OR UPDATE
     ON TA_LOG_SEC_FINTRARES
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 19/12/2019 a las 12:19:37 Hs.
  */
  v_registro TA_AUDITORIAS%ROWTYPE; -- Registro de la tabla TA_AUDITORIAS
BEGIN
  v_registro.tabla := 'TA_LOG_SEC_FINTRARES';
  v_registro.clave := :old.cod_fintransac;
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'EST_RESPUESTA', :old.est_respuesta, :new.est_respuesta );
  --v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_RESPUESTA', :old.fec_respuesta, :new.fec_respuesta );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_ERROR', :old.cod_error, :new.cod_error, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_PERSONA', :old.cod_persona, :new.cod_persona );

  -- Insertar tabla de auditoria
  prt_ins_ta_auditoria( v_registro );
EXCEPTION
  when others then
    prt_ins_ta_auditoria( v_registro );
END;
/

