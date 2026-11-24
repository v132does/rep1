CREATE OR REPLACE TRIGGER IT.AA_CJ_VAL_TRANSITO
  AFTER DELETE OR UPDATE
     ON CJ_VAL_TRANSITO
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 17/11/2009 a las 15:27:35 Hs.
  */
  v_registro CJ_AUDITORIAS%ROWTYPE; -- Registro de la tabla CJ_AUDITORIAS
BEGIN
  v_registro.tabla := 'CJ_VAL_TRANSITO';
  v_registro.clave := to_char( :old.nro_documento);
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_CAJA', :old.nro_caja, :new.nro_caja, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_OFICINA', :old.cod_oficina, :new.cod_oficina, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_MONEDA', :old.cod_moneda, :new.cod_moneda );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FECHA', :old.fecha, :new.fecha, 'F' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MONTO', :old.monto, :new.monto, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_OFI_DESTINO', :old.cod_ofi_destino, :new.cod_ofi_destino, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'ESTADO', :old.estado, :new.estado );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_CAJ_PROCESO', :old.nro_caj_proceso, :new.nro_caj_proceso, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_USU_PROCESO', :old.cod_usu_proceso, :new.cod_usu_proceso );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_PROCESO', :old.fec_proceso, :new.fec_proceso, 'F' );

  -- Insertar tabla de auditoria
  prj_ins_cj_auditoria( v_registro );
EXCEPTION
  when others then
    prj_ins_cj_auditoria( v_registro );
END;
/

