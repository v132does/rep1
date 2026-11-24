CREATE OR REPLACE TRIGGER IT.AA_CJ_REG_MOV_SERVICIOS
  AFTER DELETE OR UPDATE
     ON "IT"."CJ_REG_MOV_SERVICIOS"
    FOR EACH ROW
DECLARE
  v_registro CJ_AUDITORIAS%ROWTYPE; -- Registro de la tabla CJ_AUDITORIAS
BEGIN
  v_registro.tabla := 'CJ_REG_MOV_SERVICIOS';
  v_registro.clave := to_char( :old.cod_lote) || '#' || to_char( :old.fecha, 'DD/MM/YYYY HH24:MI:SS');
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_LOTE', :old.COD_LOTE, :new.COD_LOTE);
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_DOCUMENTO', :old.COD_DOCUMENTO, :new.COD_DOCUMENTO);
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_TRANSACCION', :old.NRO_TRANSACCION, :new.NRO_TRANSACCION);
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'ATM_ID', :old.ATM_ID, :new.ATM_ID);
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'DES_TRANSACCION', :old.DES_TRANSACCION, :new.DES_TRANSACCION);
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'SERVICIO', :old.SERVICIO, :new.SERVICIO);
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NOM_COMPLETO', :old.NOM_COMPLETO, :new.NOM_COMPLETO);
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_DOCUMENTO', :old.NRO_DOCUMENTO, :new.NRO_DOCUMENTO);
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_TELEFONO', :old.NRO_TELEFONO, :new.NRO_TELEFONO );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_REFERENCIA', :old.COD_REFERENCIA, :new.COD_REFERENCIA);
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_REFERENCIA_2', :old.COD_REFERENCIA_2, :new.COD_REFERENCIA_2);
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_REFERENCIA_3', :old.COD_REFERENCIA_3, :new.COD_REFERENCIA_3);
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MONTO', :old.MONTO, :new.MONTO,'M');
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MONTO_OPERACION', :old.MONTO_OPERACION, :new.MONTO_OPERACION,'N');
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'ESTADO', :old.estado, :new.estado );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FECHA', :old.fecha, :new.fecha, 'F' );

  -- Insertar tabla de auditoria
  prj_ins_cj_auditoria( v_registro );
EXCEPTION
  when others then
    prj_ins_cj_auditoria( v_registro );
END;
/

