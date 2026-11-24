CREATE OR REPLACE TRIGGER IT.AA_BW_AUTORIZACIONES
  AFTER DELETE OR UPDATE
     ON BW_AUTORIZACIONES
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 02/10/2007 a las 08:13:29 Hs.
  */
  v_registro BW_AUDITORIAS%ROWTYPE; -- Registro de la tabla BW_AUDITORIAS
BEGIN
  v_registro.tabla := 'BW_AUTORIZACIONES';
  v_registro.clave := :old.cod_persona || '#' || to_char( :old.nro_documento);
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_HORA', :old.fec_hora, :new.fec_hora, 'H' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'ACCION', :old.accion, :new.accion );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'OBSERVACION', :old.observacion, :new.observacion );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_CANAL', :old.cod_canal, :new.cod_canal );

  -- Insertar tabla de auditoria
  prw_ins_bw_auditoria( v_registro );
EXCEPTION
  when others then
    prw_ins_bw_auditoria( v_registro );
END;
/

