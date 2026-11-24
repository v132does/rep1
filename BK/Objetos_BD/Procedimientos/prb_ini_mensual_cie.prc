create or replace procedure it.prb_ini_mensual_cie is
  /* inicializacion mensual */
v_fec_actual     date      := pag_cal.fu_obt_fec_actual(2);
v_ano            number(4) := to_char(v_fec_actual,'yyyy');
v_mes_actual     number(2) := to_char(v_fec_actual,'mm');
v_mes_anterior   number(2) := to_number(to_char(pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_ACTUAL(2),1),'MM'));
begin
 -- Cargar fechas calendario -----------------------------------
 pag_cal.PR_OBT_DAT_CALENDAR(2);
/* if (v_fec_actual = pag_cal.G_PRI_DIA_MES_HABIL and to_char(v_fec_actual,'mm') <> '01') or
     to_char(v_fec_actual,'ddmm') = '0101' then*/
    -- es inicio mensual
    if v_mes_anterior <> v_mes_actual then
       prg_act_par_dinamico('MES_FISCAL',null, null, null, null,(fug_obt_pardinamico('MES_FISCAL') + 1));
    end if;
    -- Actualiza parámetro del Informe mensual de Saldos Contables BBVADES-3263
    --prg_act_par_dinamico('FEC_SAL_CONTABLES',null, null, null, null,to_char(pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_ACTUAL(2),1),'YYYYMM'));
    -- RABP-CNF(17-07-2015)CNFACCON-1: Se inserta para que se reinicie en forma mensual
    prg_act_par_dinamico('SIG_NRO_ASIENTO',null, null, null, null,'1');
    --
    prb_tra_sal_historico_cie;
    --
    prb_gen_sal_mensuales_cie;
    --
    prb_sum_sal_consolidados_ape;
    --
    prb_ini_anual;  -- solo se ejecuta si es inicio de año fiscal
    --
    --pas_pla.pr_pro_planinfo; --Genera datos para Planinfo--
-- end if;
end;
/

