CREATE OR REPLACE PROCEDURE IT.PRA_ACT_SAL_CTA_SIPAP
 IS
 /* 08/06- Proceso de Actualizacion de SAL_TOTAL de CC_CTA_BANCARIAS para las operaciones SIPAP
 realizadas el día. Se toma el SAL_TOT_BATCH y se sumarizan las interbancarias del día
 de ge_movimientos en estado normal. Se ejecutará en el cierre con los movimientos del día,
 cuando se empiece a guardar los datos en GE_MOVIMIENTOS_NOC
 */
v_mto_credito number(18,2);
v_mto_debito number(18,2);
v_mto_total number(18,2);
-- Cursor resumen de Movimientos SIPAP del Día.
CURSOR cuentas IS
select a.Nro_Cuenta,A.COD_MONEDA,A.SAL_TOT_BATCH,A.SAL_TOTAL
  from cc_cta_bancarias a
   where a.cod_modalidad=455
   and fug_obt_paradicional(a.nro_cuenta, 'SNP_TIP_CTA_INTERBANCARIA') = 'LIQ'
    order by a.cod_moneda;
BEGIN
   For cta in cuentas Loop
    begin pre_ini_aplicacion; pae_cnf.g_cod_modulo:=1; end;
    
    v_mto_credito:=0;
    v_mto_debito:=0;
    v_mto_total:=0;
       --Sumamos Crédito
       SELECT sum(a.monto)
          into v_mto_credito
         FROM GE_MOVIMIENTOS a
          WHERE a.ESTADO = 'N'
             and a.cod_mad_padre=455
             and a.nro_cuenta= cta.nro_cuenta
             and a.cod_moneda= cta.cod_moneda
             and a.fecha= pag_cal.FU_OBT_FEC_ACTUAL(1)
             and a.tip_mov_rubro='C';
       --Sumamos Débito
        SELECT sum(a.monto)
          into v_mto_debito
         FROM GE_MOVIMIENTOS a
          WHERE a.ESTADO = 'N'
             and a.cod_mad_padre=455
              and a.nro_cuenta= cta.nro_cuenta
             and a.cod_moneda= cta.cod_moneda
              and a.fecha= pag_cal.FU_OBT_FEC_ACTUAL(1)
             and a.tip_mov_rubro='D';
        v_mto_total:= (nvl(cta.sal_tot_batch,0) + nvl(v_mto_credito,0)) - nvl(v_mto_debito,0);
        --Comparamos si es diferente al total
        if  nvl(v_mto_total,0) <> nvl(cta.sal_total,0) then
           --Hacemos update
           update cc_cta_bancarias b
              set b.sal_total= v_mto_total
                where b.nro_cuenta=cta.nro_cuenta;
        end if;
  end loop;

END;
/

