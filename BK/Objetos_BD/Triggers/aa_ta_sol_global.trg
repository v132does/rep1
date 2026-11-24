CREATE OR REPLACE TRIGGER IT.AA_TA_SOL_GLOBAL
  AFTER DELETE OR UPDATE
     ON IT.TA_SOL_GLOBAL
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 03/07/2006 a las 12:29:46 Hs.
  */
  v_registro TA_AUDITORIAS%ROWTYPE; -- Registro de la tabla TA_AUDITORIAS
BEGIN
  v_registro.tabla := 'TA_SOL_GLOBAL';
  v_registro.clave := to_char( :old.cod_solicitud);
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TIPO_SOLICITUD', :old.tipo_solicitud, :new.tipo_solicitud );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_TARJETA', :old.nro_tarjeta, :new.nro_tarjeta );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_CUENTA', :old.nro_cuenta, :new.nro_cuenta );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FECHA', :old.fecha, :new.fecha, 'F' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'ESTADO', :old.estado, :new.estado);
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'DETALLE_ENTREGA', :old.detalle_entrega, :new.detalle_entrega);
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MOTIVO', :old.motivo, :new.motivo );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TIPO_ENTREGA', :old.tipo_entrega, :new.tipo_entrega );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'EST_PIN', :old.est_pin, :new.est_pin );
  -- Insertar tabla de auditoria
  prt_ins_ta_auditoria( v_registro );
EXCEPTION
  when others then
    prt_ins_ta_auditoria( v_registro );
END;
/

