CREATE OR REPLACE TRIGGER IT.AA_GE_EQF_MOR_ACT_ADEFI
  AFTER DELETE OR UPDATE
     ON GE_EQF_MOR_ACT_ADEFI
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 18/03/2019 a las 11:41:01 Hs.
  */
  v_registro GE_AUDITORIAS%ROWTYPE; -- Registro de la tabla GE_AUDITORIAS
BEGIN
  v_registro.tabla := 'GE_EQF_MOR_ACT_ADEFI';
  v_registro.clave := to_char( :old.nro_solicitud) || '#' || to_char( :old.nro_secuencia);
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_PERSONA', :old.cod_persona, :new.cod_persona );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_CONSULTA', :old.fec_consulta, :new.fec_consulta, 'F' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'HOR_CONSULTA', :old.hor_consulta, :new.hor_consulta );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NOM_SER_WEBSERVICE', :old.nom_ser_webservice, :new.nom_ser_webservice );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TIP_PERSONA', :old.tip_persona, :new.tip_persona );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'ACT_AFILIADO', :old.act_afiliado, :new.act_afiliado );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'CANTIDAD', :old.cantidad, :new.cantidad, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MEN_FEC_VTO_PENDIENTE', :old.men_fec_vto_pendiente, :new.men_fec_vto_pendiente );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MAY_FEC_VTO_PENDIENTE', :old.may_fec_vto_pendiente, :new.may_fec_vto_pendiente );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'SUM_SAL_ACREEDOR', :old.sum_sal_acreedor, :new.sum_sal_acreedor, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MONEDA', :old.moneda, :new.moneda );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MSG_ERROR', :old.msg_error, :new.msg_error );

  -- Insertar tabla de auditoria
  prg_ins_ge_auditoria( v_registro );
EXCEPTION
  when others then
    prg_ins_ge_auditoria( v_registro );
END;
/

