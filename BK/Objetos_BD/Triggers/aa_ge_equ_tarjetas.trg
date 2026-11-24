CREATE OR REPLACE TRIGGER IT.AA_GE_EQU_TARJETAS
  AFTER DELETE OR UPDATE
     ON GE_EQU_TARJETAS
    FOR EACH ROW
DECLARE
  v_registro GE_AUDITORIAS%ROWTYPE; -- Registro de la tabla GE_AUDITORIAS
BEGIN
  v_registro.tabla := 'GE_EQU_TARJETAS';
  v_registro.clave := to_char( :old.fecha, 'DD/MM/YYYY HH24:MI:SS') || '#' || to_char( :old.nro_secuencia) || '#' || :old.nro_cuenta;
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_MODULO', :old.cod_modulo, :new.cod_modulo );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_MODALIDAD', :old.cod_modalidad, :new.cod_modalidad );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TIP_TARJETA', :old.tip_tarjeta, :new.tip_tarjeta );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_MONEDA', :old.cod_moneda, :new.cod_moneda );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'LIM_CRE_CABECERA', :old.lim_cre_cabecera, :new.lim_cre_cabecera );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'LIM_FINANCIACION', :old.lim_financiacion, :new.lim_financiacion );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'LIM_RET_EFECTIVO', :old.lim_ret_efectivo, :new.lim_ret_efectivo );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_EMISION', :old.fec_emision, :new.fec_emision );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'IND_TARJETA', :old.ind_tarjeta, :new.ind_tarjeta );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MTO_PAG_MINIMO', :old.mto_pag_minimo, :new.mto_pag_minimo );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'LIM_CRE_DETALLE', :old.lim_cre_detalle, :new.lim_cre_detalle );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TOT_COM_MES', :old.tot_com_mes, :new.tot_com_mes );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'SAL_TOTAL', :old.sal_total, :new.sal_total );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'SAL_CUOTAS', :old.sal_cuotas, :new.sal_cuotas );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'SAL_VENCIDO', :old.sal_vencido, :new.sal_vencido );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'IMP_CUO_MES_1', :old.imp_cuo_mes_1, :new.imp_cuo_mes_1 );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'IMP_CUO_MES_2', :old.imp_cuo_mes_2, :new.imp_cuo_mes_2 );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'IMP_CUO_MES_3', :old.imp_cuo_mes_3, :new.imp_cuo_mes_3 );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'IMP_CUO_MES_4', :old.imp_cuo_mes_4, :new.imp_cuo_mes_4 );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'IMP_CUO_MES_5', :old.imp_cuo_mes_5, :new.imp_cuo_mes_5 );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'IMP_CUO_MES_6', :old.imp_cuo_mes_6, :new.imp_cuo_mes_6 );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'IMP_CUO_MES_7', :old.imp_cuo_mes_7, :new.imp_cuo_mes_7 );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'IMP_CUO_MES_8', :old.imp_cuo_mes_8, :new.imp_cuo_mes_8 );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'IMP_CUO_MES_9', :old.imp_cuo_mes_9, :new.imp_cuo_mes_9 );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'IMP_CUO_MES_10', :old.imp_cuo_mes_10, :new.imp_cuo_mes_10 );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'IMP_CUO_MES_11', :old.imp_cuo_mes_11, :new.imp_cuo_mes_11 );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'IMP_CUO_MES_12', :old.imp_cuo_mes_12, :new.imp_cuo_mes_12 );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_CANCELACION', :old.fec_cancelacion, :new.fec_cancelacion, 'F' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_INICIO', :old.fec_inicio, :new.fec_inicio, 'F' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TIP_PROCESO', :old.tip_proceso, :new.tip_proceso );

  -- Insertar tabla de auditoria
  prg_ins_ge_auditoria( v_registro );
EXCEPTION
  when others then
    prg_ins_ge_auditoria( v_registro );
END;
/

