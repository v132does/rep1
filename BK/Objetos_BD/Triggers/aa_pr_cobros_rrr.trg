CREATE OR REPLACE TRIGGER IT.AA_PR_COBROS_RRR
  AFTER DELETE OR UPDATE
     ON "IT"."PR_COBROS_RRR"
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2015 - IT Consultores
  || Generado el 12/11/2015 a las 10:50:24 Hs.
  */
  r_paudi PR_AUDITORIAS%ROWTYPE; -- Registro de la tabla PR_AUDITORIAS
BEGIN
  r_paudi.tabla := 'PR_COBROS_RRR';
  r_paudi.clave := :old.cod_persona || '#' || :old.nro_cuenta;
  r_paudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    r_paudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_paudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  r_paudi.detalle := pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'FEC_VALOR', :old.fec_valor, :new.fec_valor, 'F' );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'SAL_CAPITAL', :old.sal_capital, :new.sal_capital, 'M' );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'SAL_INTERES', :old.sal_interes, :new.sal_interes, 'M' );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'MTO_CAPITAL', :old.mto_capital, :new.mto_capital, 'M' );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'MTO_INTERES', :old.mto_interes, :new.mto_interes, 'M' );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'MTO_INT_DOCUMENTADO', :old.mto_int_documentado, :new.mto_int_documentado, 'M' );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'MTO_INT_MORATORIO', :old.mto_int_moratorio, :new.mto_int_moratorio, 'M' );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'MTO_INT_MOR_INTERES', :old.mto_int_mor_interes, :new.mto_int_mor_interes, 'M' );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'MTO_INT_MOR_ADELANTADO', :old.mto_int_mor_adelantado, :new.mto_int_mor_adelantado, 'M' );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'MTO_INT_PUNITORIO', :old.mto_int_punitorio, :new.mto_int_punitorio, 'M' );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'MTO_CARGO', :old.mto_cargo, :new.mto_cargo, 'M' );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'MTO_IMPUESTO', :old.mto_impuesto, :new.mto_impuesto, 'M' );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'COD_MONEDA', :old.cod_moneda, :new.cod_moneda );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'DIA_ATRASO', :old.dia_atraso, :new.dia_atraso, 'N' );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'NRO_CUO_DESDE', :old.nro_cuo_desde, :new.nro_cuo_desde, 'N' );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'NRO_CUO_HASTA', :old.nro_cuo_hasta, :new.nro_cuo_hasta, 'N' );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'MTO_PAGADO', :old.mto_pagado, :new.mto_pagado, 'M' );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'MTO_IVA_DEVUELTO', :old.mto_iva_devuelto, :new.mto_iva_devuelto, 'M' );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'NRO_SOL_RENOVADA', :old.nro_sol_renovada, :new.nro_sol_renovada, 'M' );

  -- Insertar tabla de auditoria
  prp_ins_pr_auditoria( r_paudi );
EXCEPTION
  when others then
    prp_ins_pr_auditoria( r_paudi );
END;
/

