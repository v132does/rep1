create or replace force view it.simgia_invengen as
select i.cod_rubro, r.cod_rub_externo, r.descripcion, i.cod_modalidad, i.tip_saldo, i.cod_moneda,
       d.nro_cuenta, sum(d.sal_actual) sal_actual, p.val_tasa, p.fec_inicio, p.fec_vencimiento, e.cod_persona, fue_obt_nom_persona(e.cod_persona) nombre
from cb_sal_inventarios i, cb_sal_inventarios_det d, pr_cta_prestamos p, cb_rubros r, ge_cta_clientes e
where i.nro_referencia=d.nro_referencia
and d.nro_cuenta=p.nro_cuenta
and p.nro_cuenta=e.nro_cuenta
and e.relacion='P'
and i.cod_rubro=r.cod_rubro(+)
group by i.cod_rubro, r.cod_rub_externo, r.descripcion, i.cod_modalidad, i.tip_saldo,i.cod_moneda,
       d.nro_cuenta, p.val_tasa, p.fec_inicio, p.fec_vencimiento, e.cod_persona, fue_obt_nom_persona(e.cod_persona)
       order by r.cod_rub_externo desc;

