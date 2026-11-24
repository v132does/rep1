create or replace force view it.simgia_arma719 as
select '0' M719SUC,
       '719' M719CTA,
       '0' M719SUB,
       '' M719NOMBRE,
       '' M719DIRECC,
       0 M719TELEF,
       0 M719RIESGO,
       0 M719SDMEAN,
       0 M719SDDMEA,
       0 M719SDACT,
       0 M719SDDIAC,
       '0' M719NUMERO,
       0 M719TIPOIN,
       0 M719BNDCAP,
       /*0 M719CTACTE, no existe este campo en la tabla de as400*/
       0 M719DIVISA,
       0 M719SDOMED,
       to_number(nvl(to_char(pae_cnf.fu_obt_fec_actual(1),'ddmmyy'),0)) M719FCHULT,
       0 M719BNDLIQ,
       0 M719SLMMEA,
       '' M719IND2,
       0 M719SUCORG,
       '' M719IND1,
       0 M719ACUDIE,
       0 M719ACUDI,
       0 M719PRDPEF,
       0 M719APUAUX,
       0 M719GRPCTA,
       '' M719FILLR1
       --,'' nro_cuenta
from DUAL

UNION ALL

select to_char(nvl(acvi.cod_oficina,0)) M719SUC,
       '719' M719CTA,
       to_char(nvl(substr(acvi.nro_cuenta, 5, 6),0)) M719SUB,
       nvl(PAI_INT.FU_SIM_NORM_CADENA(acvi.denominacion,40),'') M719NOMBRE,
       nvl(PAI_INT.FU_SIM_NORM_CADENA((select a.direccion from ba_direcciones a where a.cod_persona = gccli.cod_persona and a.principal like 'S' and rownum = 1),40),' ') M719DIRECC,
       0 M719TELEF,
       to_number(nvl(gccli.cod_persona,0)) M719RIESGO,
       0 M719SDMEAN,
       0 M719SDDMEA,
       0 M719SDACT,
       nvl(acvi.sal_tot_batch - nvl(acvi.sal_ret_batch,0),0) M719SDDIAC,
       nvl(PAI_INT.fu_obt_cta_contable(fub_obt_rub_transaccion(acvi.cod_modulo,
                               acvi.cod_modalidad,
                               decode(nvl(acvi.cta_combinada,'N'),'S',682,602), --codigo transaccion
                               acvi.cod_moneda,
                               gccli.cod_persona,
                               1,
                               'C')),0) M719NUMERO,
       nvl((select f.val_tasa from ge_tas_fechas f where f.nro_cuenta = acvi.nro_cuenta and f.cod_tasa = acvi.cod_tasa),0) M719TIPOIN,
       nvl(acvi.tip_capitalizacion,0) M719BNDCAP,
       /*0 M719CTACTE, no existe este campo en la tabla de as400*/
       to_number(nvl(decode(acvi.cod_moneda,'GS','00','USD','05','EUR','17'),0)) M719DIVISA,
       0 M719SDOMED,
       to_number(nvl(to_char(acvi.fec_ult_movimiento,'ddmmyy'),0)) M719FCHULT,
       0 M719BNDLIQ,
       --nvl(pai_int.devengado_acumulado(acvi.nro_cuenta),0) M719SLMMEA,
       nvl(de.mto_dev_acumulado,0) M719SLMMEA,
       ' ' M719IND2,
       0 M719SUCORG,
       --' ' M719IND1,
       to_char(decode(nvl(acvi.cod_cau_cancelacion,-1), -1,'',236,2,1)) M719IND1, --a pedido de Roberto gimenez 2010-02-04
       0 M719ACUDIE,
       0 M719ACUDI,
       0 M719PRDPEF,
       0 M719APUAUX,
       --nvl(eg.grubcp,0) M719GRPCTA,
       decode(acvi.cta_combinada, 'S', decode(eg.grubcp, 10, 50, 16, 56, 0), nvl(eg.grubcp,0) ) M719GRPCTA, -- a pedido de V.P.
       ' ' M719FILLR1
       --, acvi.nro_cuenta
from ah_cta_vistas acvi, ge_cta_clientes gccli, ge_clientes gcli, equiv_grubcp eg,
(select d.nro_cuenta, sum(d.mto_dev_acumulado) mto_dev_acumulado
from ah_devengados d
left join ah_capitalizaciones z on d.nro_cuenta = z.nro_cuenta and d.fec_inicio = z.fec_inicio
and z.fecha is null
group by d.nro_cuenta) de

where acvi.nro_cuenta = gccli.nro_cuenta (+)
and   gccli.cod_persona = gcli.cod_persona (+)
and   gcli.cod_tip_deudor = eg.cod_tip_deudor(+)
and   gcli.cod_sec_contable = eg.cod_sec_contable(+)
and   gccli.relacion (+) in ('P')
and   de.nro_cuenta (+) = acvi.nro_cuenta
and   acvi.cod_moneda in ('USD','EUR')
;

