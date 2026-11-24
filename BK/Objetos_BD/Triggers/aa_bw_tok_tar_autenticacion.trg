CREATE OR REPLACE TRIGGER IT.AA_BW_TOK_TAR_AUTENTICACION
  AFTER DELETE OR UPDATE
     ON BW_TOK_TAR_AUTENTICACION
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 10/03/2021 a las 17:00:44 Hs.
  */
  v_registro BW_AUDITORIAS%ROWTYPE; -- Registro de la tabla BW_AUDITORIAS
BEGIN
  v_registro.tabla := 'BW_TOK_TAR_AUTENTICACION';
  v_registro.clave := :old.cod_autenticacion;
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_RESPUESTA', :old.cod_respuesta, :new.cod_respuesta );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_TOKENIZACION', :old.cod_tokenizacion, :new.cod_tokenizacion );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TIP_AUTENTICACION', :old.tip_autenticacion, :new.tip_autenticacion );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'INF_ENMASCARADA', :old.inf_enmascarada, :new.inf_enmascarada );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'DIR_CLIENTE', :old.dir_cliente, :new.dir_cliente );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'DIR_ORIGEN', :old.dir_origen, :new.dir_origen );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'PLATAFORMA', :old.plataforma, :new.plataforma );

  -- Insertar tabla de auditoria
  prw_ins_bw_auditoria( v_registro );
EXCEPTION
  when others then
    prw_ins_bw_auditoria( v_registro );
END;
/

