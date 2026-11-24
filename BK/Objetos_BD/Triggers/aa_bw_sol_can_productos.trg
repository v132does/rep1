CREATE OR REPLACE TRIGGER IT.AA_BW_SOL_CAN_PRODUCTOS
  AFTER DELETE OR UPDATE
     ON BW_SOL_CAN_PRODUCTOS
    FOR EACH ROW
DECLARE

  v_registro BW_AUDITORIAS%ROWTYPE; -- Registro de la tabla BW_AUDITORIAS
BEGIN
  v_registro.tabla := 'BW_SOL_CAN_PRODUCTOS';
  v_registro.clave := :old.cod_persona || '#' || :old.tip_producto || '#' || to_char( :old.nro_producto) || '#' || to_char( :old.fec_solicitud);
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_PERSONA', :old.cod_persona, :new.cod_persona );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TIP_PRODUCTO', :old.tip_producto, :new.tip_producto);
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_PRODUCTO', :old.nro_producto, :new.nro_producto);
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_SOLICITUD', :old.fec_solicitud, :new.fec_solicitud);
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MOT_CANCELACION', :old.mot_cancelacion, :new.mot_cancelacion);
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COMENTARIOS', :old.comentarios, :new.comentarios);
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TEL_CONTACTO', :old.tel_contacto, :new.tel_contacto);
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MAIL_CONTACTO', :old.mail_contacto, :new.mail_contacto);
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'ENVIADO', :old.enviado, :new.enviado);
  -- Insertar tabla de auditoria
  prw_ins_bw_auditoria( v_registro );
EXCEPTION
  when others then
    prw_ins_bw_auditoria( v_registro );
END;
/

