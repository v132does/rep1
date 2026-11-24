CREATE OR REPLACE TRIGGER IT.AA_IG_OPE_RES_CLIENTES
  AFTER DELETE OR UPDATE
     ON IG_OPE_RES_CLIENTES
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 14/06/2007 a las 08:42:14 Hs.
  */
  v_registro IG_AUDITORIAS%ROWTYPE; -- Registro de la tabla IG_AUDITORIAS
BEGIN
  v_registro.tabla := 'IG_OPE_RES_CLIENTES';
  v_registro.clave := :old.cod_persona || '#' || to_char( :old.cod_concepto) || '#' || to_char( :old.cod_sub_concepto) || '#' || to_char( :old.fecha, 'DD/MM/YYYY HH24:MI:SS') || '#' || :old.cod_moneda;
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  IF updating THEN --sólo por modificación
    -- Registrar Detalle
    v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_PERIODO', :old.cod_periodo, :new.cod_periodo, 'N' );
    v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_OFICINA', :old.cod_oficina, :new.cod_oficina, 'N' );
    v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_UNIDAD', :old.cod_unidad, :new.cod_unidad, 'N' );
    v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_GRU_ECONOMICO', :old.cod_gru_economico, :new.cod_gru_economico, 'N' );
    v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_USU_OFICIAL', :old.cod_usu_oficial, :new.cod_usu_oficial );
    v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'CAT_RIESGO', :old.cat_riesgo, :new.cat_riesgo );
    v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'SUM_MTO_APERTURA', :old.sum_mto_apertura, :new.sum_mto_apertura, 'M' );
    v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'SUM_SALDO', :old.sum_saldo, :new.sum_saldo, 'M' );
    v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'SUM_INTERES', :old.sum_interes, :new.sum_interes, 'M' );
    v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'SUM_INT_DEVENGADO', :old.sum_int_devengado, :new.sum_int_devengado, 'M' );
    v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'SUM_INT_DEVENGAR', :old.sum_int_devengar, :new.sum_int_devengar, 'M' );
    v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'SUM_INT_DEV_SUSPENSO', :old.sum_int_dev_suspenso, :new.sum_int_dev_suspenso, 'M' );
    v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'SUM_INT_RECUPERADO', :old.sum_int_recuperado, :new.sum_int_recuperado, 'M' );
    v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'SUM_MTO_MORA', :old.sum_mto_mora, :new.sum_mto_mora, 'M' );
    v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'SUM_SAL_PROMEDIO', :old.sum_sal_promedio, :new.sum_sal_promedio, 'M' );
    v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'SUM_CON_MTO_APERTURA', :old.sum_con_mto_apertura, :new.sum_con_mto_apertura, 'M' );
    v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'SUM_CON_SALDO', :old.sum_con_saldo, :new.sum_con_saldo, 'M' );
    v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'SUM_CON_INTERES', :old.sum_con_interes, :new.sum_con_interes, 'M' );
    v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'SUM_CON_INT_DEVENGADO', :old.sum_con_int_devengado, :new.sum_con_int_devengado, 'M' );
    v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'SUM_CON_INT_DEVENGAR', :old.sum_con_int_devengar, :new.sum_con_int_devengar, 'M' );
    v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'SUM_CON_INT_DEV_SUSPENSO', :old.sum_con_int_dev_suspenso, :new.sum_con_int_dev_suspenso, 'M' );
    v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'SUM_CON_INT_RECUPERADO', :old.sum_con_int_recuperado, :new.sum_con_int_recuperado, 'M' );
    v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'SUM_CON_MTO_MORA', :old.sum_con_mto_mora, :new.sum_con_mto_mora, 'M' );
    v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'SUM_CON_SAL_PROMEDIO', :old.sum_con_sal_promedio, :new.sum_con_sal_promedio, 'M' );
    v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'POR_MORA', :old.por_mora, :new.por_mora, 'N' );
    v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'SUM_LOGRO', :old.sum_logro, :new.sum_logro, 'M' );
    v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'SUM_CON_LOGRO', :old.sum_con_logro, :new.sum_con_logro, 'M' );
    v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MAX_MORA', :old.max_mora, :new.max_mora, 'N' );
    v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'PRO_MORA', :old.pro_mora, :new.pro_mora, 'N' );
    v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'CAN_CUENTAS', :old.can_cuentas, :new.can_cuentas, 'N' );
    v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_PLAZO', :old.cod_plazo, :new.cod_plazo, 'N' );
    -- Insertar tabla de auditoria
    pri_ins_ig_auditoria( v_registro );
  end if;
EXCEPTION
  when others then
    pri_ins_ig_auditoria( v_registro );
END;
/

