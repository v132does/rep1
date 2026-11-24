CREATE OR REPLACE FORCE VIEW IT.SIMGIA_PREVICAR AS
select
tct.cod_oficina as PCSUC,
gcc.cod_persona as PCRIESGO,
--tp.nro_cuenta as PCCUENTA,
nvl(PAI_INT.fu_obt_cta_contable(fub_obt_rub_transaccion(tct.cod_modulo,
                               tct.cod_modalidad,
                               730, --codigo transaccion
                               tct.cod_moneda,
                               gc.cod_persona,
                               1,
                               'C',
                               decode(tct.cat_automatica,'1','C','2','V','3','G','4','M','M') ,
                               null, gc.cat_riesgo, null, gc.tipo,null,null)),0) PCCUENTA,
to_number(substr('000000' || tp.nro_cuenta,-6)) as PCPROPUE,
--tp.monto PCMONTO,
(nvl(tp.monto,0) - nvl(tp.tot_prv_contingencia,0)) PCMONTO,
0 PCIND,
nvl(gc.cat_riesgo,1) as PCCLASE
, 1 consulta
from ta_previsiones tp, ge_cta_clientes gcc, ta_cta_tarjetas tct, ge_clientes gc
where tp.nro_cuenta = gcc.nro_cuenta
and tp.nro_cuenta = tct.nro_cuenta
and gcc.cod_persona = gc.cod_persona
and gcc.relacion = 'P'
and tp.fecha = (select max(b.fecha) from ta_previsiones  b where b.nro_cuenta = tp.nro_cuenta)
and (nvl(tp.monto,0) - nvl(tp.tot_prv_contingencia,0)) > 0
and tct.estado <> 'C'

union all

--tarj mto conting
select
tct.cod_oficina as PCSUC,
gcc.cod_persona as PCRIESGO,
--tp.nro_cuenta as PCCUENTA,
nvl(PAI_INT.fu_obt_cta_contable(fub_obt_rub_transaccion(tct.cod_modulo,
                               tct.cod_modalidad,
                               756, --codigo transaccion
                               tct.cod_moneda,
                               gc.cod_persona,
                               1,
                               'C',
                               tct.estado,
                               null, gc.cat_riesgo, null, gc.tipo,null,null)),0) PCCUENTA,
to_number(substr('000000' || tp.nro_cuenta,-6)) as PCPROPUE,
--tp.monto PCMONTO,
nvl(tp.tot_prv_contingencia,0) PCMONTO,
0 PCIND,
nvl(gc.cat_riesgo,1) as PCCLASE
, 2 consulta
from ta_previsiones tp, ge_cta_clientes gcc, ta_cta_tarjetas tct, ge_clientes gc
where tp.nro_cuenta = gcc.nro_cuenta
and tp.nro_cuenta = tct.nro_cuenta
and gcc.cod_persona = gc.cod_persona
and gcc.relacion = 'P'
and tp.fecha = (select max(b.fecha) from ta_previsiones  b where b.nro_cuenta = tp.nro_cuenta)
and tp.tot_prv_contingencia > 0
and tct.estado <> 'C'

union all

select
pcp.cod_oficina as PCSUC,
gcc.cod_persona as PCRIESGO,
--pp.nro_cuenta as PCCUENTA,
nvl(PAI_INT.fu_obt_cta_contable(fub_obt_rub_transaccion(pcp.cod_modulo,
                               pcp.cod_modalidad,
                               730, --codigo transaccion
                               pcp.cod_moneda,
                               gc.cod_persona,
                               d.cod_plazo,
                               'C',
                               pcp.estado,
                               null, gc.cat_riesgo, null, gc.tipo,null,null)),0) PCCUENTA,
to_number(substr('000000' || pp.nro_cuenta,-6)) as PCPROPUE,
pp.monto as PCMONTO,
0 PCIND,
nvl(gc.cat_riesgo,1) as PCCLASE
, 3 consulta
from pr_previsiones pp, ge_cta_clientes gcc, pr_cta_prestamos pcp, ge_clientes gc, ge_plz_contables d
where pp.nro_cuenta = gcc.nro_cuenta
and pp.nro_cuenta = pcp.nro_cuenta
and gc.cod_persona = gcc.cod_persona
and gcc.relacion = 'P'
and pp.fecha = (select max(b.fecha) from pr_previsiones  b where b.nro_cuenta = pp.nro_cuenta)
and pp.monto > 0
and pcp.estado not in ('N','I')
AND can_dias = (SELECT MIN(can_dias)
                                        FROM ge_plz_contables
                                       WHERE can_dias >=
                                           pcp.fec_vencimiento - pcp.fec_inicio)

union all

select
ccc.cod_oficina as PCSUC,
gcc.cod_persona as PCRIESGO,
--cp.nro_cuenta as PCCUENTA,
nvl(PAI_INT.fu_obt_cta_contable(fub_obt_rub_transaccion(ccc.cod_modulo,
                               ccc.cod_modalidad,
                               730, --codigo transaccion
                               ccc.cod_moneda,
                               gc.cod_persona,
                               1,
                               'C',
                               nvl(r.sit_deuda,'M'),--ccc.estado,
                               null, gc.cat_riesgo, null, gc.tipo,null,null)),0) PCCUENTA,
to_number(substr('000000' || cp.nro_cuenta,-6)) as PCPROPUE,
cp.monto as PCMONTO,
0 PCIND,
nvl(gc.cat_riesgo,1) as PCCLASE
, 4 consulta
from cc_previsiones cp, ge_cta_clientes gcc, cc_cta_corrientes ccc, ge_clientes gc, cc_sobregiros_res r
where cp.nro_cuenta = gcc.nro_cuenta
and cp.nro_cuenta = ccc.nro_cuenta
and gc.cod_persona = gcc.cod_persona
and gcc.relacion = 'P'
and cp.fecha = (select max(b.fecha) from cc_previsiones  b where b.nro_cuenta = cp.nro_cuenta)
and r.nro_cuenta(+)=ccc.nro_cuenta
and cp.monto > 0
and ccc.estado <> 'C'

union all

SELECT /*c.cod_modulo, c.cod_modalidad, c.cod_oficina, c.nro_cuenta,ge.cod_sec_contable, ge.cod_tip_deudor, ge.residente,
          fup_obt_categoria(ge.cat_automatica,ge.cat_subjetiva) cat_riesgo,v.fecha,
          c.cod_moneda, nvl(v.saldo,0) SALDO, 0 LINEA_DE_CREDITO,
          c.dia_atraso, c.est_batch, nvl(v.monto,0) mto_prevision,
          nvl(v.tot_pri_prevision,0) tot_pri_prevision*/
c.cod_oficina as PCSUC,
gc.cod_persona as PCRIESGO,
--cp.nro_cuenta as PCCUENTA,
nvl(PAI_INT.fu_obt_cta_contable(fub_obt_rub_transaccion(c.cod_modulo,
                               c.cod_modalidad,
                               730, --codigo transaccion
                               c.cod_moneda,
                               gc.cod_persona,
                               1,
                               'C',
                               c.est_batch,--ccc.estado,
                               null, ge.cat_riesgo, null, ge.tipo,null,null)),0) PCCUENTA,
to_number(substr('000000' || v.nro_cuenta,-6)) as PCPROPUE,
v.monto as PCMONTO,
0 PCIND,
nvl(ge.cat_riesgo,1) as PCCLASE
, 4 consulta
from ov_previsiones v, ov_cta_vencidas c, ge_clientes ge, ge_cta_clientes gc
where c.nro_cuenta= v.nro_cuenta
and ge.cod_persona = gc.cod_persona
and gc.nro_cuenta = c.nro_cuenta
and gc.relacion = 'P'
and v.fecha = (select max(b.fecha) from ov_previsiones  b where c.nro_cuenta = b.nro_cuenta)
and v.monto > 0
and c.estado not in ('C','I')
;

