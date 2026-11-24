CREATE OR REPLACE TRIGGER IT.AA_OV_PREVISIONES
  AFTER DELETE OR UPDATE
     ON OV_PREVISIONES
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 19/10/2007 a las 09:09:53 Hs.
  */
  v_registro OV_AUDITORIAS%ROWTYPE; -- Registro de la tabla OV_AUDITORIAS
BEGIN
  v_registro.tabla := 'OV_PREVISIONES';
  v_registro.clave := to_char( :old.fecha, 'DD/MM/YYYY HH24:MI:SS');
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_CUENTA', :old.nro_cuenta, :new.nro_cuenta );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MONTO', :old.monto, :new.monto, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'SALDO', :old.saldo, :new.saldo, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'PORCENTAJE', :old.porcentaje, :new.porcentaje, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TOT_GAR_COMPUTABLES', :old.tot_gar_computables, :new.tot_gar_computables, 'M' );

  -- Insertar tabla de auditoria
  prv_ins_ov_auditoria( v_registro );
EXCEPTION
  when others then
    prv_ins_ov_auditoria( v_registro );
END;
/

