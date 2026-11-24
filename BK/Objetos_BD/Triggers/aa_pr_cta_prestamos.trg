CREATE OR REPLACE TRIGGER IT.AA_PR_CTA_PRESTAMOS
 AFTER DELETE OR UPDATE OF NRO_CTA_DEBITO
, NRO_CTA_RENOVADA
, NRO_DOCUMENTO
, COD_ORI_FONDO
, NRO_SOL_RENOVADA
, FEC_INICIO
, PER_VTO_INTERES
, DIG_VERIFICADOR
, DESCRIPCION
, NRO_SOLICITUD
, FEC_VENCIMIENTO
, TIPO
, COD_CANAL
, COD_MODALIDAD
, COD_CAMPANA
, COD_OFICINA
, COD_CAUSA
, EN_JUICIO
, VAL_TASA
, TIP_DOCUMENTO
, TIP_RENOVACION
, COD_SEC_CREDITO
, NRO_CUENTA
, ESTADO
, TIP_DESTINO
, COD_MONEDA
, TIP_INTERES
, FEC_CANCELACION
, COD_MODULO
, COB_AUTOMATICO
, NRO_LINEA
, EXO_IMPUESTOS
, PER_VTO_CAPITAL
, COD_RUB_ECONOMICO
, NRO_CTA_NOVADA
, FEC_ULT_CATEGORIZACION
 ON PR_CTA_PRESTAMOS
 FOR EACH ROW

DECLARE
r_paudi pr_auditorias%rowtype; -- Registro de la tabla PR_AUDITORIAS
BEGIN
   r_paudi.tabla := 'PR_CTA_PRESTAMOS';
   r_paudi.clave := :old.nro_cuenta;
   r_paudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_paudi.tip_novedad := 'M';
   elsif deleting then
      r_paudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
    r_paudi.detalle := pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'DIG_VERIFICADOR',:old.dig_verificador,:new.dig_verificador,'N');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'COD_MODULO',:old.cod_modulo,:new.cod_modulo,'N');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'COD_MODALIDAD',:old.cod_modalidad,:new.cod_modalidad,'N');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'COD_OFICINA',:old.cod_oficina,:new.cod_oficina,'N');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'NRO_CTA_DEBITO',:old.nro_cta_debito,:new.nro_cta_debito);
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'NRO_CTA_RENOVADA',:old.nro_cta_renovada,:new.nro_cta_renovada);
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'FEC_CANCELACION',:old.fec_cancelacion,:new.fec_cancelacion,'F');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'ESTADO',:old.estado,:new.estado);
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'MTO_CAPITAL',:old.mto_capital,:new.mto_capital,'M');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'SAL_CAPITAL',:old.sal_capital,:new.sal_capital,'M');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'SAL_INTERES',:old.sal_interes,:new.sal_interes,'M');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'VAL_INT_DEVENGAR',:old.val_int_devengar,:new.val_int_devengar,'M');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'NRO_SOLICITUD',:old.nro_solicitud,:new.nro_solicitud,'N');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'EST_BATCH',:old.est_batch,:new.est_batch);
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'SAL_CAP_BATCH',:old.sal_cap_batch,:new.sal_cap_batch,'M');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'SAL_INT_BATCH',:old.sal_int_batch,:new.sal_int_batch,'M');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'NRO_DOCUMENTO',:old.nro_documento,:new.nro_documento,'N');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'EST_ANTERIOR',:old.est_anterior,:new.est_anterior);
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'DEV_ACUMULADO',:old.dev_acumulado,:new.dev_acumulado,'M');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'TIP_DOCUMENTO',:old.tip_documento,:new.tip_documento);
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'NRO_SOL_RENOVADA',:old.nro_sol_renovada,:new.nro_sol_renovada,'N');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'COB_AUTOMATICO',:old.cob_automatico,:new.cob_automatico);
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'SAL_INT_ADELANTADO',:old.sal_int_adelantado,:new.sal_int_adelantado,'M');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'FEC_ULT_DEVENGADO',:old.fec_ult_devengado,:new.fec_ult_devengado,'F');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'DEV_NO_COBRADO',:old.dev_no_cobrado,:new.dev_no_cobrado,'M');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'NRO_LINEA',:old.nro_linea,:new.nro_linea,'N');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'COD_MONEDA',:old.cod_moneda,:new.cod_moneda);
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'MONTO',:old.monto,:new.monto,'M');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'FEC_INICIO',:old.fec_inicio,:new.fec_inicio,'F');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'FEC_VENCIMIENTO',:old.fec_vencimiento,:new.fec_vencimiento,'F');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'TIPO',:old.tipo,:new.tipo);
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'VAL_TASA',:old.val_tasa,:new.val_tasa,'N');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'CAN_CUOTAS',:old.can_cuotas,:new.can_cuotas,'N');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'CAN_CUO_PAGADAS',:old.can_cuo_pagadas,:new.can_cuo_pagadas,'N');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'DIA_ATRASO',:old.dia_atraso,:new.dia_atraso,'N');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'MAX_ATRASO',:old.max_atraso,:new.max_atraso,'N');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'PRO_ATRASO',:old.pro_atraso,:new.pro_atraso,'N');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'EXO_IMPUESTOS',:old.exo_impuestos,:new.exo_impuestos);
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'COD_CAUSA',:old.cod_causa,:new.cod_causa,'N');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'COD_CANAL',:old.cod_canal,:new.cod_canal,'N');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'COD_CAMPANA',:old.cod_campana,:new.cod_campana,'N');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'COD_SEC_CREDITO',:old.cod_sec_credito,:new.cod_sec_credito,'N');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'DESCRIPCION',:old.descripcion,:new.descripcion);
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'TIP_DESTINO',:old.tip_destino,:new.tip_destino,'N');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'TIP_INTERES',:old.tip_interes,:new.tip_interes);
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'MTO_LIN_APLICADO',:old.mto_lin_aplicado,:new.mto_lin_aplicado,'M');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'TIP_RENOVACION',:old.tip_renovacion,:new.tip_renovacion);
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'SAL_INT_ADE_BATCH',:old.sal_int_ade_batch,:new.sal_int_ade_batch,'M');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'COD_ORI_FONDO',:old.cod_ori_fondo,:new.cod_ori_fondo,'N');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'PER_VTO_CAPITAL',:old.per_vto_capital,:new.per_vto_capital,'N');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'PER_VTO_INTERES',:old.per_vto_interes,:new.per_vto_interes,'N');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'DEV_SUSPENSO',:old.dev_suspenso,:new.dev_suspenso,'M');
    r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'EN_JUICIO', :old.en_juicio, :new.en_juicio );
    r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'FEC_JUICIO', :old.fec_juicio, :new.fec_juicio, 'F' );
    r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'COD_ENT_JUICIO', :old.cod_ent_juicio, :new.cod_ent_juicio, 'N' );
    r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'CAT_RENOVACIONES', :old.cat_renovaciones, :new.cat_renovaciones, 'N' );
    r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'MTO_MORA', :old.mto_mora, :new.mto_mora, 'M' );
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'POR_ORI_FONDO',:old.por_ori_fondo,:new.por_ori_fondo,'N');
  	r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'COD_RUB_ECONOMICO',:old.cod_rub_economico,:new.cod_rub_economico);
  	r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'COD_BANCA',:old.cod_banca,:new.cod_banca);
  	r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'FEC_REN_TAS_ORIG',:old.fec_ren_tas_orig,:new.fec_ren_tas_orig);
  	r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'FEC_REN_TAS',:old.fec_ren_tas,:new.fec_ren_tas);
  	r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'COD_SUB_MODALIDAD',:old.cod_sub_modalidad,:new.cod_sub_modalidad);                
	  r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'NRO_CTA_NOVADA',:old.nro_cta_novada,:new.nro_cta_novada);
	  r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'FEC_ULT_CATEGORIZACION',:old.fec_ult_categorizacion,:new.fec_ult_categorizacion);
   --- Insertar tabla de auditoria
   PRP_INS_PR_AUDITORIA(r_paudi);
EXCEPTION
   WHEN OTHERS THEN
      PRP_INS_PR_AUDITORIA(r_paudi);
END;
/

