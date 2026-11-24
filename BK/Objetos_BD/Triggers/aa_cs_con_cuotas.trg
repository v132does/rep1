CREATE OR REPLACE TRIGGER IT."AA_CS_CON_CUOTAS"
  AFTER DELETE OR UPDATE
     ON CS_CON_CUOTAS
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 09/03/2009 a las 15:50:20 Hs.
  */
  v_registro CS_AUDITORIAS%ROWTYPE; -- Registro de la tabla CS_AUDITORIAS
BEGIN
  v_registro.tabla := 'CS_CON_CUOTAS';
  v_registro.clave := :old.nro_contrato || '#' || to_char( :old.nro_cuota);
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_DESDE', :old.fec_desde, :new.fec_desde, 'F' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_HASTA', :old.fec_hasta, :new.fec_hasta, 'F' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_VENCIMIENTO', :old.fec_vencimiento, :new.fec_vencimiento, 'F' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_PAGO', :old.fec_pago, :new.fec_pago, 'F' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MONTO', :old.monto, :new.monto, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'ESTADO', :old.estado, :new.estado );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_PAG_ANT', :old.fec_pag_ant, :new.fec_pag_ant, 'F' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_TRANSACCION', :old.cod_transaccion, :new.cod_transaccion, 'M' );

  -- Insertar tabla de auditoria
  prq_ins_cs_auditoria( v_registro );
EXCEPTION
  when others then
    prq_ins_cs_auditoria( v_registro );
END;
/

