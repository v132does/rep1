CREATE OR REPLACE TRIGGER IT.AA_GE_EQF_CONVOCATORIAS_RES
  AFTER DELETE OR UPDATE
     ON GE_EQF_CONVOCATORIAS_RES
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 18/03/2019 a las 11:37:51 Hs.
  */
  v_registro GE_AUDITORIAS%ROWTYPE; -- Registro de la tabla GE_AUDITORIAS
BEGIN
  v_registro.tabla := 'GE_EQF_CONVOCATORIAS_RES';
  v_registro.clave := to_char( :old.nro_solicitud);
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_PERSONA', :old.cod_persona, :new.cod_persona );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_SECUENCIA', :old.nro_secuencia, :new.nro_secuencia, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_CONSULTA', :old.fec_consulta, :new.fec_consulta, 'F' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'HOR_CONSULTA', :old.hor_consulta, :new.hor_consulta );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NOM_SER_WEBSERVICE', :old.nom_ser_webservice, :new.nom_ser_webservice );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TIP_PERSONA', :old.tip_persona, :new.tip_persona );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'CAN_TOTAL', :old.can_total, :new.can_total, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'CAN_FINIQUITADAS', :old.can_finiquitadas, :new.can_finiquitadas, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'CAN_NO_FINIQUITADAS', :old.can_no_finiquitadas, :new.can_no_finiquitadas, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MAY_FEC_ADMISION', :old.may_fec_admision, :new.may_fec_admision );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MEN_FEC_ADMISION', :old.men_fec_admision, :new.men_fec_admision );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MSG_ERROR', :old.msg_error, :new.msg_error );

  -- Insertar tabla de auditoria
  prg_ins_ge_auditoria( v_registro );
EXCEPTION
  when others then
    prg_ins_ge_auditoria( v_registro );
END;
/

