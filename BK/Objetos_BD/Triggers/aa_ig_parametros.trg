CREATE OR REPLACE TRIGGER IT.AA_IG_PARAMETROS
  AFTER DELETE OR UPDATE
     ON IG_PARAMETROS
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 07/06/2007 a las 10:50:33 Hs.
  */
  v_registro IG_AUDITORIAS%ROWTYPE; -- Registro de la tabla IG_AUDITORIAS
BEGIN
  v_registro.tabla := 'IG_PARAMETROS';
  v_registro.clave := to_char( :old.cod_periodo);
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'DESCRIPCION', :old.descripcion, :new.descripcion );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_HASTA', :old.fec_hasta, :new.fec_hasta, 'F' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TIP_PERIODO', :old.tip_periodo, :new.tip_periodo );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_DESDE', :old.fec_desde, :new.fec_desde, 'F' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'LIQUIDADO', :old.liquidado, :new.liquidado );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MAR_OPERATIVO', :old.mar_operativo, :new.mar_operativo );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COEFICIENTE', :old.coeficiente, :new.coeficiente, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_ULT_PROCESO', :old.fec_ult_proceso, :new.fec_ult_proceso, 'F' );

  -- Insertar tabla de auditoria
  pri_ins_ig_auditoria( v_registro );
EXCEPTION
  when others then
    pri_ins_ig_auditoria( v_registro );
END;
/

