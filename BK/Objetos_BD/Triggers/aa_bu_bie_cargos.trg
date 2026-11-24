CREATE OR REPLACE TRIGGER IT.AA_BU_BIE_CARGOS
  AFTER DELETE OR UPDATE
     ON BU_BIE_CARGOS
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 05/11/2010 a las 09:55:31 Hs.
  */
  v_registro BU_AUDITORIAS%ROWTYPE; -- Registro de la tabla BU_AUDITORIAS
BEGIN
  v_registro.tabla := 'BU_BIE_CARGOS';
  v_registro.clave := to_char( :old.fecha, 'DD/MM/YYYY HH24:MI:SS') || '#' || to_char( :old.cod_bien) || '#' || to_char( :old.cod_transaccion) || '#' || to_char( :old.cod_modulo) || '#' || to_char( :old.cod_modalidad);
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_MONEDA', :old.cod_moneda, :new.cod_moneda );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MONTO', :old.monto, :new.monto, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'ESTADO', :old.estado, :new.estado );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_PAGO', :old.fec_pago, :new.fec_pago, 'F' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MTO_PREVISION', :old.mto_prevision, :new.mto_prevision, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_PREVISION', :old.fec_prevision, :new.fec_prevision, 'F' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'OBSERVACION', :old.observacion, :new.observacion );

  -- Insertar tabla de auditoria
  pru_ins_bu_auditoria( v_registro );
EXCEPTION
  when others then
    pru_ins_bu_auditoria( v_registro );
END;
/

