CREATE OR REPLACE TRIGGER IT.AA_IG_OPERACIONES
  AFTER DELETE OR UPDATE
     ON IG_OPERACIONES
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 14/06/2007 a las 08:41:54 Hs.
  */
  v_registro IG_AUDITORIAS%ROWTYPE; -- Registro de la tabla IG_AUDITORIAS
BEGIN
  v_registro.tabla := 'IG_OPERACIONES';
  v_registro.clave := :old.nro_cuenta || '#' || to_char( :old.fecha, 'DD/MM/YYYY HH24:MI:SS');
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  IF updating THEN --sólo por modificación
    -- Registrar Detalle
    v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_CONCEPTO', :old.cod_concepto, :new.cod_concepto, 'N' );
    v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_SUB_CONCEPTO', :old.cod_sub_concepto, :new.cod_sub_concepto, 'N' );
    v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_PERIODO', :old.cod_periodo, :new.cod_periodo, 'N' );
    v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_PERSONA', :old.cod_persona, :new.cod_persona );
    v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_MODULO', :old.cod_modulo, :new.cod_modulo, 'N' );
    v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_MODALIDAD', :old.cod_modalidad, :new.cod_modalidad, 'N' );
    v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_OFICINA', :old.cod_oficina, :new.cod_oficina, 'N' );
    v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'ESTADO', :old.estado, :new.estado );
    v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_APERTURA', :old.fec_apertura, :new.fec_apertura, 'F' );
    v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_VENCIMIENTO', :old.fec_vencimiento, :new.fec_vencimiento, 'F' );
    v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_CANCELACION', :old.fec_cancelacion, :new.fec_cancelacion, 'F' );
    v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_MONEDA', :old.cod_moneda, :new.cod_moneda );
    v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MTO_APERTURA', :old.mto_apertura, :new.mto_apertura, 'M' );
    v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'SALDO', :old.saldo, :new.saldo, 'M' );
    v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'INTERES', :old.interes, :new.interes, 'M' );
    v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'INT_DEVENGADO', :old.int_devengado, :new.int_devengado, 'M' );
    v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'INT_DEVENGAR', :old.int_devengar, :new.int_devengar, 'M' );
    v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'INT_DEV_SUSPENSO', :old.int_dev_suspenso, :new.int_dev_suspenso, 'M' );
    v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'INT_RECUPERADO', :old.int_recuperado, :new.int_recuperado, 'M' );
    v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MTO_MORA', :old.mto_mora, :new.mto_mora, 'M' );
    v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'SAL_PROMEDIO', :old.sal_promedio, :new.sal_promedio, 'M' );
    v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'CON_MTO_APERTURA', :old.con_mto_apertura, :new.con_mto_apertura, 'M' );
    v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'CON_SALDO', :old.con_saldo, :new.con_saldo, 'M' );
    v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'CON_INTERES', :old.con_interes, :new.con_interes, 'M' );
    v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'CON_INT_DEVENGADO', :old.con_int_devengado, :new.con_int_devengado, 'M' );
    v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'CON_INT_DEVENGAR', :old.con_int_devengar, :new.con_int_devengar, 'M' );
    v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'CON_INT_DEV_SUSPENSO', :old.con_int_dev_suspenso, :new.con_int_dev_suspenso, 'M' );
    v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'CON_INT_RECUPERADO', :old.con_int_recuperado, :new.con_int_recuperado, 'M' );
    v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'CON_MTO_MORA', :old.con_mto_mora, :new.con_mto_mora, 'M' );
    v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'CON_SAL_PROMEDIO', :old.con_sal_promedio, :new.con_sal_promedio, 'M' );
    v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'POR_MORA', :old.por_mora, :new.por_mora, 'N' );
    v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'LOGRO', :old.logro, :new.logro, 'M' );
    v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'CON_LOGRO', :old.con_logro, :new.con_logro, 'M' );
    v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'DIA_MORA', :old.dia_mora, :new.dia_mora, 'N' );
    v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'PRO_MORA', :old.pro_mora, :new.pro_mora, 'N' );
    v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MAX_MORA', :old.max_mora, :new.max_mora, 'N' );
    v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'VAL_TASA', :old.val_tasa, :new.val_tasa, 'M' );
    v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_USU_OFICIAL', :old.cod_usu_oficial, :new.cod_usu_oficial );
    v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_UNIDAD', :old.cod_unidad, :new.cod_unidad, 'N' );
    v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'DIAS', :old.dias, :new.dias, 'N' );
    v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_PLAZO', :old.cod_plazo, :new.cod_plazo, 'N' );
  
    -- Insertar tabla de auditoria
    pri_ins_ig_auditoria( v_registro );
  end if;
EXCEPTION
  when others then
    pri_ins_ig_auditoria( v_registro );
END;
/

