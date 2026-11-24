create or replace force view it.simgia_arma709 as
select '0' M709SUC,
       '0' M709CTA,
       '0' M709SUB,
       '' M709NOMBRE,
       '' M709DIRECC,
       0 M709TELEF,
       0 M709RIESGO,
       0 M709SDOANT,
       0 M709SDOACT,
       0 M709SDDVAN,
       0 M709SDDVAC,
       0 M709DIVISA,
       0 M709TRASP,
       0 M709LIMSOB,
       0 M709VCTLIM,
       '0' M709NUMERO,
       0 M709IMPSTO,
       0 M709CNTDEB,
       0 M709CNTCRE,
       0 M709SDMDSE,
       0 M709ACMDIA,
       0 M709SDMDME,
       nvl(to_char(pae_cnf.fu_obt_fec_actual(1),'ddmmyy'),0) M709ULTMOV,
       0 M709NODISP,
       0 M709MAYINT,
       0 M709MAYCOM,
       0 M709INISOB,
       0 M709SMDANT,
       '' M709CTAHME,
       0 M709TOTEMB,
       0 M709TOTBLQ,
       '' M709IND1,
       '' M709IND2,
       '' M709IND3,
       '' M709IND4,
       0 M709BLQINT,
       0 M709INIEXC,
       0 M709AUMSOB,
       '' M709FILLR1,
       0 M709TRASPS,
       0 M709GRPCTA,
       0 M709SUCORG,
       0 M709NRPROP,
       0 M709ANPROP,
       0 M709DEPCNB,
       0 M709TOTCRP,
       0 M709PLZADL,
       '' M709FILLR2

from dual

union all

select to_char(nvl(cccor.cod_oficina, 0)) M709SUC,
       '709' M709CTA,
       to_char(nvl(substr(cccor.nro_cuenta, 5, 6), 0)) M709SUB,
       nvl(PAI_INT.FU_SIM_NORM_CADENA(cccor.denominacion,40), '') M709NOMBRE,
       nvl(PAI_INT.FU_SIM_NORM_CADENA((select a.direccion from ba_direcciones a where a.cod_persona = gccli.cod_persona and a.principal like 'S' and rownum = 1),40), '') M709DIRECC,
       0 M709TELEF,
       to_number(nvl(gccli.cod_persona,0)) M709RIESGO,
       0 M709SDOANT,
       0 M709SDOACT,
       0 M709SDDVAN,
       -- to_number(nvl(cccor.sal_total - (cccor.sal_bloqueado + cccor.sal_retenido),0)) M709SDDVAC,
       -- pai_int.calcula_saldo_arma7xx(cccor.sal_tot_batch,cccor.sal_ret_batch,cccor.sal_blo_batch)  M709SDDVAC, -- cambiado el 30-mar-2011 NAF para igualar con logica de inventario
       pai_int.calcula_saldo_arma7xx(cccor.sal_tot_batch,cccor.sal_ret_batch,cccor.sal_blo_batch) M709SDDVAC, -- 20110614 se unifican las logicas, si es negativo se envia logica anterior, para saldos positivos logica nueva
       to_number(nvl(decode(cccor.cod_moneda,'GS','00','USD','05','EUR','17'),0)) M709DIVISA,
       0 M709TRASP,
       nvl(cclso.monto,0) M709LIMSOB,
       nvl(to_number(to_char(cclso.fec_vencimiento,'yymmdd')),0) M709VCTLIM,
       --0 M709NUMERO,
       nvl(PAI_INT.fu_obt_cta_contable(fub_obt_rub_transaccion(cccor.cod_modulo,
                               cccor.cod_modalidad,
                               602, --codigo transaccion
                               cccor.cod_moneda,
                               gccli.cod_persona,
                               1,
                               'C')),0) M709NUMERO,
       0 M709IMPSTO,
       0 M709CNTDEB,
       0 M709CNTCRE,
       0 M709SDMDSE,
       0 M709ACMDIA,
       0 M709SDMDME,
       nvl(to_char(cccor.fec_ult_movimiento,'ddmmyy'),0) M709ULTMOV,
       0 M709NODISP,
       0 M709MAYINT,
       0 M709MAYCOM,
       case
       when nvl(cccor.dia_atraso,0) = 0 and nvl(cccor.sal_total - (cccor.sal_bloqueado + cccor.sal_retenido),0) < 0 then
            to_number(to_char(pae_cnf.fu_obt_fec_actual(1), 'ddmmyy'))
       else
            decode(nvl(cccor.dia_atraso,0), 0, 0, to_number(to_char((pae_cnf.fu_obt_fec_actual(1) - (nvl(cccor.dia_atraso,0)-1)), 'ddmmyy')) )
       end M709INISOB,
       0 M709SMDANT,
       '' M709CTAHME,
       0 M709TOTEMB,
       0 M709TOTBLQ,
       --'' M709IND1,
       to_char(decode(nvl(cccor.cod_cau_cancelacion,-1), -1,'',236,2,1)) M709IND1, --a pedido de Roberto gimenez 2010-02-04
       '' M709IND2,
       '' M709IND3,
       '' M709IND4,
       0 M709BLQINT,
       0 M709INIEXC,
       0 M709AUMSOB,
       '' M709FILLR1,
       0 M709TRASPS,
       nvl(eg.grubcp,0) M709GRPCTA,
       0 M709SUCORG,
       0 M709NRPROP,
       0 M709ANPROP,
       0 M709DEPCNB,
       0 M709TOTCRP,
       0 M709PLZADL,
       '' M709FILLR2

from cc_cta_corrientes cccor, cc_lin_sobregiros cclso, ge_cta_clientes gccli, ge_clientes gcli, equiv_grubcp eg

where cccor.nro_cuenta  = cclso.nro_cuenta (+)
and   cccor.nro_cuenta  = gccli.nro_cuenta (+)
and   gccli.cod_persona = gcli.cod_persona (+)
and   gcli.cod_tip_deudor = eg.cod_tip_deudor(+)
and   gcli.cod_sec_contable = eg.cod_sec_contable(+)
and   gccli.relacion (+) in ('P')
and   cccor.cod_moneda in ('USD','EUR')
;

