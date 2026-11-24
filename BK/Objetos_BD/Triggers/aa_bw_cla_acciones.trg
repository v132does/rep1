CREATE OR REPLACE TRIGGER IT.AA_BW_CLA_ACCIONES
  AFTER DELETE OR UPDATE
     ON BW_CLA_ACCIONES
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 02/10/2007 a las 08:13:12 Hs.
  */
  v_registro BW_AUDITORIAS%ROWTYPE; -- Registro de la tabla BW_AUDITORIAS
BEGIN
  v_registro.tabla := 'BW_CLA_ACCIONES';
  v_registro.clave := :old.cod_persona||'#'||:old.cod_per_vinculada;
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'ACCION', :old.ACCION, :new.ACCION);
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_HOJ_SEGURIDAD', :old.NRO_HOJ_SEGURIDAD, :new.NRO_HOJ_SEGURIDAD,'N');
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TIP_CLAVE', :old.TIP_CLAVE, :new.TIP_CLAVE);

  -- Insertar tabla de auditoria
  prw_ins_bw_auditoria( v_registro );
EXCEPTION
  when others then
    prw_ins_bw_auditoria( v_registro );
END;
/

