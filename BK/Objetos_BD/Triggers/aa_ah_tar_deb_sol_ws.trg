CREATE OR REPLACE TRIGGER IT.AA_AH_TAR_DEB_SOL_WS
  AFTER DELETE OR UPDATE
     ON AH_TAR_DEB_SOL_WS
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 13/08/2015 a las 09:13:14 Hs.
  */
  v_registro AH_AUDITORIAS%ROWTYPE; -- Registro de la tabla AH_AUDITORIAS
BEGIN
  v_registro.tabla := 'AH_TAR_DEB_SOL_WS';
  v_registro.clave := :old.registro;
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_CUENTA', :old.nro_cuenta, :new.nro_cuenta );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_FILA', :old.nro_fila, :new.nro_fila );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_PERSONA', :old.cod_persona, :new.cod_persona );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'RELACION', :old.relacion, :new.relacion );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_EMISION', :old.nro_emision, :new.nro_emision, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'DET_ERROR', :old.det_error, :new.det_error );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_ENVIO', :old.fec_envio, :new.fec_envio );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'HOR_ENVIO', :old.hor_envio, :new.hor_envio );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_HOR_CIERRE', :old.fec_hor_cierre, :new.fec_hor_cierre );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_PROCESADORA', :old.cod_procesadora, :new.cod_procesadora );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NOM_ARCHIVO', :old.nom_archivo, :new.nom_archivo );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'USU_INSERCION', :old.usu_insercion, :new.usu_insercion );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_INSERCION', :old.fec_insercion, :new.fec_insercion, 'F' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'USU_MODIFICACION', :old.usu_modificacion, :new.usu_modificacion );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_MODIFICACION', :old.fec_modificacion, :new.fec_modificacion, 'F' );

  -- Insertar tabla de auditoria
  pra_ins_ah_auditoria( v_registro );
EXCEPTION
  when others then
    pra_ins_ah_auditoria( v_registro );
END;
/

