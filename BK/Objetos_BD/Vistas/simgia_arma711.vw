create or replace force view it.simgia_arma711 as
select '0' M711SUC,
       '0' M711CTA,
       '0' M711SUB,
       '' M711NOMBRE,
       '' M711DIREC,
       0 M711TELEF,
       0 M711RIESGO,
       '' cod_persona,
       0 M711SLMMAN,
       0 M711SLDACT,
       '' M711NRO700,
       0 M711SLNODS,
       '0' M711NUMERO,
       0 M711TIPINT,
       0 M711TIPCAP,
       0 M711SDOMED,
       0 M711ACDIAS,
       to_number(nvl(to_char(pae_cnf.fu_obt_fec_actual(1),'ddmmyy'),0)) M711ULTMOV,
       0 M711INTERS,
       0 M711BANDLQ,
       0 M711SDMDSA,
       0 M711BADALT,
       0 M711APCTEM,
       0 M711APCTBL,
       0 M711APDBCR,
       0 M711APAUX,
       '' M711IND1,
       '' M711IND2,
       0 M711GRPCTA,
       '' M711FILLR1,
       0 M711AUXMAE,
       '' M711FILLR2
       --,'' nro_cuenta
from dual

union all

select to_char(nvl(acvi.cod_oficina, 0)) M711SUC,
       '711' M711CTA,
       to_char(nvl(substr(acvi.nro_cuenta, 5, 6),0)) M711SUB,
       nvl(PAI_INT.FU_SIM_NORM_CADENA(acvi.denominacion,40),'') M711NOMBRE,
       nvl(PAI_INT.FU_SIM_NORM_CADENA((select a.direccion
         from ba_direcciones a
         where a.cod_persona = gccli.cod_persona
         and a.principal = 'S' and rownum = 1),40),'') M711DIREC,
       0 M711TELEF,
       to_number(nvl(gccli.cod_persona,0)) M711RIESGO,
       gccli.cod_persona,
       0 M711SLMMAN,
       nvl(acvi.sal_tot_batch - nvl(acvi.sal_ret_batch,0),0) M711SLDACT,
       '' M711NRO700,
       0 M711SLNODS,
       -- 0 M711NUMERO,
       nvl(PAI_INT.fu_obt_cta_contable(fub_obt_rub_transaccion(acvi.cod_modulo,
                               acvi.cod_modalidad,
                               decode(nvl(acvi.cta_combinada,'N'),'S',682,602), --codigo transaccion
                               acvi.cod_moneda,
                               gccli.cod_persona,
                               1,
                               'C')),0) M711NUMERO,
       nvl((select f.val_tasa
         from ge_tas_fechas f
         where f.nro_cuenta = acvi.nro_cuenta
         and f.cod_tasa = acvi.cod_tasa),0) M711TIPINT,
       nvl(acvi.tip_capitalizacion,0) M711TIPCAP,
       0 M711SDOMED,
       0 M711ACDIAS,
       to_number(nvl(to_char(acvi.fec_ult_movimiento,'ddmmyy'),0)) M711ULTMOV,
       --nvl(pai_int.devengado_acumulado(acvi.nro_cuenta),0) M711INTERS,
       --acvi.nro_cuenta M711INTERS,
       nvl(de.mto_dev_acumulado,0) M711INTERS,
       0 M711BANDLQ,
       0 M711SDMDSA,
       0 M711BADALT,
       0 M711APCTEM,
       0 M711APCTBL,
       0 M711APDBCR,
       0 M711APAUX,
       --'' M711IND1,
       to_char(decode(nvl(acvi.cod_cau_cancelacion,-1), -1,'',236,2,1)) M711IND1, --a pedido de Roberto gimenez 2010-02-04
       '' M711IND2,
       --nvl(eg.grubcp,0) M711GRPCTA,
       decode(acvi.cta_combinada, 'S', decode(eg.grubcp, 10, 50, 16, 56, 0), nvl(eg.grubcp,0) ) M711GRPCTA, -- a pedido de V.P.

       '' M711FILLR1,
       0 M711AUXMAE,
       '' M711FILLR2
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
and   acvi.cod_moneda in ('GS')
;

