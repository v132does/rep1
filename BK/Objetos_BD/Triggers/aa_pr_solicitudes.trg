CREATE OR REPLACE TRIGGER IT.AA_PR_SOLICITUDES
  AFTER DELETE OR UPDATE
     ON PR_SOLICITUDES
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 01/08/2012 a las 15:09:59 Hs.
  */
  r_paudi PR_AUDITORIAS%ROWTYPE; -- Registro de la tabla PR_AUDITORIAS
BEGIN
  r_paudi.tabla := 'PR_SOLICITUDES';
  r_paudi.clave := to_char( :old.nro_solicitud);
  r_paudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    r_paudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_paudi.tip_novedad := 'E';
  END IF;

  --- Registrar Detalle
  IF deleting THEN
	  -- r_paudi.detalle := pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'DESCRIPCION',:old.descripcion,:new.descripcion);
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad, 'MONTO', :old.monto, :new.monto, 'M');
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad, 'TIP_INTERES', :old.tip_interes, :new.tip_interes);
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad, 'TIP_AMORTIZACION', :old.tip_amortizacion, :new.tip_amortizacion);
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad, 'DIA_PLAZO', :old.dia_plazo, :new.dia_plazo, 'N');
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad, 'FEC_VENCIMIENTO', :old.fec_vencimiento, :new.fec_vencimiento, 'F');
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad, 'AJU_ULT_CUOTA', :old.aju_ult_cuota, :new.aju_ult_cuota);
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad, 'MTO_INTERES', :old.mto_interes, :new.mto_interes, 'M');
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad, 'TIP_AJU_FECHA', :old.tip_aju_fecha, :new.tip_aju_fecha);
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad, 'PER_VTO_CAPITAL', :old.per_vto_capital, :new.per_vto_capital, 'N');
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad, 'PER_GRACIA', :old.per_gracia, :new.per_gracia, 'N');
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad, 'COD_PERSONA', :old.cod_persona, :new.cod_persona);
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad, 'FEC_INICIO', :old.fec_inicio, :new.fec_inicio, 'F');
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad, 'TIP_MONTO', :old.tip_monto, :new.tip_monto);
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad, 'AJU_GRACIA', :old.aju_gracia, :new.aju_gracia);
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad, 'TOT_PRESTAMO', :old.tot_prestamo, :new.tot_prestamo, 'M');
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad, 'ESTADO', :old.estado, :new.estado);
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad, 'COD_MODULO', :old.cod_modulo, :new.cod_modulo, 'N');
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad, 'COD_MODALIDAD', :old.cod_modalidad, :new.cod_modalidad, 'N');
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad, 'COD_MONEDA', :old.cod_moneda, :new.cod_moneda);
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad, 'MTO_CARGO', :old.mto_cargo, :new.mto_cargo, 'M');
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad, 'COD_OFICINA', :old.cod_oficina, :new.cod_oficina, 'N');
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad, 'FEC_PRI_VENCIMIENTO', :old.fec_pri_vencimiento, :new.fec_pri_vencimiento, 'F');
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad, 'COD_ENT_SEGURO', :old.cod_ent_seguro, :new.cod_ent_seguro, 'N');
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad, 'COD_SEC_CREDITO', :old.cod_sec_credito, :new.cod_sec_credito, 'N');
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad, 'COD_DEPARTAMENTO', :old.cod_departamento, :new.cod_departamento, 'N');
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad, 'NRO_SOL_RENOVADA', :old.nro_sol_renovada, :new.nro_sol_renovada, 'N');
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad, 'TIPO', :old.tipo, :new.tipo);
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad, 'EXO_IMPUESTO', :old.exo_impuesto, :new.exo_impuesto);
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad, 'TOT_DESEMBOLSAR', :old.tot_desembolsar, :new.tot_desembolsar, 'M');
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad, 'CAN_DESEMBOLSOS', :old.can_desembolsos, :new.can_desembolsos, 'N');
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad, 'NRO_SOL_ORIGINAL', :old.nro_sol_original, :new.nro_sol_original, 'N');
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad, 'SAL_PRESTAMO', :old.sal_prestamo, :new.sal_prestamo, 'M');
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad, 'COD_ENT_CONCESIONARIA', :old.cod_ent_concesionaria, :new.cod_ent_concesionaria, 'N');
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad, 'NRO_CTA_DEBITO', :old.nro_cta_debito, :new.nro_cta_debito);
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad, 'DEB_AUTOMATICO', :old.deb_automatico, :new.deb_automatico);
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad, 'FEC_APROBACION', :old.fec_aprobacion, :new.fec_aprobacion, 'F');
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad, 'COD_USU_APROBACION', :old.cod_usu_aprobacion, :new.cod_usu_aprobacion);
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad, 'NRO_LINEA', :old.nro_linea, :new.nro_linea, 'N');
	  -- r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'OBSERVACIONES',:old.observaciones,:new.observaciones);
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad, 'MTO_LIN_APLICADO', :old.mto_lin_aplicado, :new.mto_lin_aplicado, 'M');
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad, 'TIP_RENOVACION', :old.tip_renovacion, :new.tip_renovacion);
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad, 'POR_ORI_FONDO', :old.por_ori_fondo, :new.por_ori_fondo, 'N');
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad, 'COD_DESTINO', :old.cod_destino, :new.cod_destino);
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad, 'VAL_PRESUPUESTO', :old.val_presupuesto, :new.val_presupuesto, 'M');
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad, 'COD_CAUSA', :old.cod_causa, :new.cod_causa, 'N');
	  IF :old.obs_reconsideracion <> :new.obs_reconsideracion THEN
		  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad, 'OBS_RECONSIDERACION', :old.obs_reconsideracion, :new.obs_reconsideracion);
	  END IF;
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad, 'REFERENCIA', :old.referencia, :new.referencia);
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad, 'IND_EVALUACION', :old.ind_evaluacion, :new.ind_evaluacion);
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'COD_SUB_MODALIDAD', :old.cod_sub_modalidad, :new.cod_sub_modalidad, 'N' );
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'TAS_REFERENCIA', :old.tas_referencia, :new.tas_referencia );
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'SPREAD', :old.spread, :new.spread, 'M' );	  
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad, 'COD_RUB_ECONOMICO', :old.cod_rub_economico, :new.cod_rub_economico);
  ELSE
	  --r_paudi.detalle := pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'DESCRIPCION',:old.descripcion,:new.descripcion);
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'MONTO', :old.monto, :new.monto, 'M' );
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'TIP_INTERES', :old.tip_interes, :new.tip_interes );
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'TIP_AMORTIZACION', :old.tip_amortizacion, :new.tip_amortizacion );
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'DIA_PLAZO', :old.dia_plazo, :new.dia_plazo, 'N' );
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'FEC_VENCIMIENTO', :old.fec_vencimiento, :new.fec_vencimiento, 'F' );
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'AJU_ULT_CUOTA', :old.aju_ult_cuota, :new.aju_ult_cuota );
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'MTO_INTERES', :old.mto_interes, :new.mto_interes, 'M' );
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'TIP_AJU_FECHA', :old.tip_aju_fecha, :new.tip_aju_fecha );
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'PER_VTO_CAPITAL', :old.per_vto_capital, :new.per_vto_capital, 'N' );
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'PER_GRACIA', :old.per_gracia, :new.per_gracia, 'N' );
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'COD_PERSONA', :old.cod_persona, :new.cod_persona );
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'FEC_INICIO', :old.fec_inicio, :new.fec_inicio, 'F' );
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'TIP_MONTO', :old.tip_monto, :new.tip_monto );
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'AJU_GRACIA', :old.aju_gracia, :new.aju_gracia );
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'TOT_PRESTAMO', :old.tot_prestamo, :new.tot_prestamo, 'M' );
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'ESTADO', :old.estado, :new.estado );
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'COD_ORI_FONDO', :old.cod_ori_fondo, :new.cod_ori_fondo, 'N' );
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'COD_MODULO', :old.cod_modulo, :new.cod_modulo, 'N' );
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'COD_MODALIDAD', :old.cod_modalidad, :new.cod_modalidad, 'N' );
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'COD_MONEDA', :old.cod_moneda, :new.cod_moneda );
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'MTO_CARGO', :old.mto_cargo, :new.mto_cargo, 'M' );
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'COD_OFICINA', :old.cod_oficina, :new.cod_oficina, 'N' );
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'FEC_PRI_VENCIMIENTO', :old.fec_pri_vencimiento, :new.fec_pri_vencimiento, 'F' );
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'COD_ENT_SEGURO', :old.cod_ent_seguro, :new.cod_ent_seguro, 'N' );
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'COD_SEC_CREDITO', :old.cod_sec_credito, :new.cod_sec_credito, 'N' );
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'COD_DEPARTAMENTO', :old.cod_departamento, :new.cod_departamento, 'N' );
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'NRO_SOL_RENOVADA', :old.nro_sol_renovada, :new.nro_sol_renovada, 'N' );
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'TIP_DOCUMENTO', :old.tip_documento, :new.tip_documento );
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'TIPO', :old.tipo, :new.tipo );
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'EXO_IMPUESTO', :old.exo_impuesto, :new.exo_impuesto );
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'TOT_DESEMBOLSAR', :old.tot_desembolsar, :new.tot_desembolsar, 'M' );
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'CAN_DESEMBOLSOS', :old.can_desembolsos, :new.can_desembolsos, 'N' );
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'NRO_SOL_ORIGINAL', :old.nro_sol_original, :new.nro_sol_original, 'N' );
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'SAL_PRESTAMO', :old.sal_prestamo, :new.sal_prestamo, 'M' );
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'CAN_DES_FALTANTES', :old.can_des_faltantes, :new.can_des_faltantes, 'N' );
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'COD_ENT_CONCESIONARIA', :old.cod_ent_concesionaria, :new.cod_ent_concesionaria, 'N' );
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'NRO_CTA_DEBITO', :old.nro_cta_debito, :new.nro_cta_debito );
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'DEB_AUTOMATICO', :old.deb_automatico, :new.deb_automatico );
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'FEC_APROBACION', :old.fec_aprobacion, :new.fec_aprobacion, 'F' );
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'COD_USU_APROBACION', :old.cod_usu_aprobacion, :new.cod_usu_aprobacion );
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'COD_USU_PROMOTOR', :old.cod_usu_promotor, :new.cod_usu_promotor );
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'NRO_LINEA', :old.nro_linea, :new.nro_linea, 'N' );
	  -- r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'OBSERVACIONES',:old.observaciones,:new.observaciones);
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'COD_CANAL', :old.cod_canal, :new.cod_canal, 'N' );
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'COD_CAMPANA', :old.cod_campana, :new.cod_campana, 'N' );
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'MTO_LIN_APLICADO', :old.mto_lin_aplicado, :new.mto_lin_aplicado, 'M' );
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'TIP_RENOVACION', :old.tip_renovacion, :new.tip_renovacion );
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'AUT_PENDIENTE', :old.aut_pendiente, :new.aut_pendiente );
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'POR_ORI_FONDO', :old.por_ori_fondo, :new.por_ori_fondo, 'N' );
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'COD_DESTINO', :old.cod_destino, :new.cod_destino );
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'VAL_PRESUPUESTO', :old.val_presupuesto, :new.val_presupuesto, 'M' );
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'COD_CAUSA', :old.cod_causa, :new.cod_causa, 'N' );
	  IF :old.obs_reconsideracion <> :new.obs_reconsideracion THEN
		  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad, 'OBS_RECONSIDERACION', :old.obs_reconsideracion, :new.obs_reconsideracion);
	  END IF;
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'REFERENCIA', :old.referencia, :new.referencia );
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'IND_EVALUACION', :old.ind_evaluacion, :new.ind_evaluacion );
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'COD_SUB_MODALIDAD', :old.cod_sub_modalidad, :new.cod_sub_modalidad, 'N' );
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'TAS_REFERENCIA', :old.tas_referencia, :new.tas_referencia );
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'SPREAD', :old.spread, :new.spread, 'M' );
	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad, 'COD_RUB_ECONOMICO', :old.cod_rub_economico, :new.cod_rub_economico);
    	  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'TIP_CAL_RENOVACION', :old.tip_cal_renovacion, :new.tip_cal_renovacion);
   END IF;
	  --- Insertar tabla de auditoria
	  prp_ins_pr_auditoria(r_paudi);
EXCEPTION
   WHEN OTHERS THEN
	   prp_ins_pr_auditoria(r_paudi); -- para insertar hasta donde puede
END;
/

