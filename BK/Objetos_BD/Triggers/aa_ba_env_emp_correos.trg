CREATE OR REPLACE TRIGGER IT.AA_BA_ENV_EMP_CORREOS
  AFTER DELETE OR UPDATE
     ON IT.BA_ENV_EMP_CORREOS
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoria
  || (c) 2022 - IT Digital
  */
  v_registro BA_AUDITORIAS%ROWTYPE; -- Registro de la tabla BA_AUDITORIAS
BEGIN
  v_registro.tabla := 'BA_ENV_EMP_CORREOS';
  v_registro.clave := :old.nro_correo;
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;
  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_CORREO', :old.nro_correo, :new.nro_correo );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_PERSONA', :old.cod_persona, :new.cod_persona);
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'ESTADO', :old.estado, :new.estado);
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TIP_PRODUCTO', :old.tip_producto, :new.tip_producto);
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_REGISTRO', :old.fec_registro, :new.fec_registro);
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_ENVIO', :old.fec_envio, :new.fec_envio);
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MSJ_ERROR', :old.msj_error, :new.msj_error);
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'DESTINATARIOS', :old.destinatarios, :new.destinatarios);

   -- Insertar tabla de auditoria
  pae_cnf.pr_ins_ba_auditoria(v_registro);
EXCEPTION
  when others then
    pae_cnf.pr_ins_ba_auditoria(v_registro);
END;
/

