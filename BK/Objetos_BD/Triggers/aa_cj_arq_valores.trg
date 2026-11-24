CREATE OR REPLACE TRIGGER IT.AA_CJ_ARQ_VALORES
  AFTER DELETE OR UPDATE
     ON CJ_ARQ_VALORES
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 30/11/2022 a las 11:24:19 Hs.
  */
  v_registro CJ_AUDITORIAS%ROWTYPE; -- Registro de la tabla CJ_AUDITORIAS
BEGIN
  v_registro.tabla := 'CJ_ARQ_VALORES';
  v_registro.clave := to_char( :old.nro_caja) || '#' || :old.cod_moneda || '#' || to_char( :old.fecha, 'DD/MM/YYYY HH24:MI:SS') || '#' || to_char( :old.cod_tip_valor);
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'CANTIDAD', :old.cantidad, :new.cantidad, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MONTO', :old.monto, :new.monto, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_ORDEN', :old.nro_orden, :new.nro_orden, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_USUARIO', :old.cod_usuario, :new.cod_usuario );

  -- Insertar tabla de auditoria
  prj_ins_cj_auditoria( v_registro );
EXCEPTION
  when others then
    prj_ins_cj_auditoria( v_registro );
END;
/

