create or replace force view it.bv_cua_rub_resultados as
select a.cod_rubro, b.cod_rub_externo, substr(a.cod_rubro,6,8) rubro, nvl(l.descripcion,'SIN DEFINICION') clasificacion, l.tipo,
       substr(a.cod_rubro,6,3) cuenta, substr(a.cod_rubro,9,2) sub_cuenta, substr(a.cod_rubro,11,3) producto,
       b.descripcion nombre_rubro,
       a.cod_oficina,o.descripcion des_oficina,
       a.cod_moneda mon,
       m.descripcion moneda,
       sum(a.sal_total) tot_inventario,
       sum (decode(substr(a.cod_rubro,1,1),'2',decode(substr(a.cod_rubro,9,1),'9',nvl(c.sal_contable,0),nvl(c.sal_contable,0) * -1),
                                     decode(substr(a.cod_rubro,9,1),'9',nvl(c.sal_contable,0)*-1,nvl(c.sal_contable,0)))) sal_contable,
       sum(nvl(a.sal_total,0)) -
       sum((decode(substr(a.cod_rubro,1,1),'2',decode(substr(a.cod_rubro,9,1),'9',c.sal_contable,nvl(c.sal_contable,0) * -1),
                                     decode(substr(a.cod_rubro,9,1),'9',nvl(c.sal_contable,0)*-1,nvl(c.sal_contable,0)))))
       diferencia
 from ba_monedas m,
      cb_rubros b,ba_oficinas o, cb_cla_rubros l,
      (select cod_rubro, cod_moneda, cod_oficina, sum(sal_contable) sal_contable
          from bv_sal_rub_resultados
         group by cod_rubro, cod_moneda, cod_oficina) c,
      (select v.cod_rubro, v.cod_moneda, v.cod_oficina,
          sum( nvl(v.sal_total,0) ) sal_total
         from
              (select cb.cod_rubro, cr.cod_moneda, cb.cod_oficina,
                  sum( nvl(cb.sal_total,0) ) sal_total
                 from cb_sal_inventarios_his cb, cb_rubros cr
                where cb.fecha = pag_cal.FU_OBT_FEC_ACTUAL(2)
                  and cb.cod_rubro = cr.cod_rubro
                  and cb.tip_saldo = 'K'
                group by cb.cod_rubro, cr.cod_moneda, cb.cod_oficina
               union all
               select cb.cod_rubro, cr.cod_moneda, cb.cod_oficina,
                  sum( nvl(cb.sal_total,0) ) sal_total
                 from cb_sal_inv_contables cb, cb_rubros cr
                where cb.cod_rubro = cr.cod_rubro
                  and cb.tip_saldo = 'K'
                group by cb.cod_rubro, cr.cod_moneda, cb.cod_oficina) v
        group by v.cod_rubro, v.cod_moneda, v.cod_oficina) a
where a.cod_rubro = b.cod_rubro (+)
  and a.cod_rubro = c.cod_rubro (+)
  and a.cod_moneda = c.cod_moneda (+)
  and a.cod_moneda = m.cod_moneda
  and a.cod_oficina = c.cod_oficina (+)
  and substr(b.cod_rubro,1,1) in ('6','7')
  and substr(a.cod_rubro,6,8)=l.cod_clasificacion (+)
  and a.cod_oficina=o.cod_oficina
group by a.cod_rubro, b.cod_rub_externo,substr(a.cod_rubro,6,8), nvl(l.descripcion,'SIN DEFINICION'), l.tipo,
       substr(a.cod_rubro,6,3),substr(a.cod_rubro,9,2),substr(a.cod_rubro,11,3),
       b.descripcion ,
       a.cod_moneda,
       m.descripcion,
       a.cod_oficina,o.descripcion
union all
select a.cod_rubro, a.cod_rub_externo,substr(a.cod_rubro,6,8) rubro, nvl(l.descripcion,'SIN DEFINICION') clasificacion, l.tipo,
       substr(a.cod_rubro,6,3) cuenta,substr(a.cod_rubro,9,2) sub_cuenta,substr(a.cod_rubro,11,3) producto,
       a.descripcion nombre_rubro,
       c.cod_oficina,o.descripcion des_oficina,
       a.cod_moneda mon,
       m.descripcion moneda,
       0 tot_inventario,
       sum (decode(substr(a.cod_rubro,1,1),'2',decode(substr(a.cod_rubro,9,1),'9',nvl(c.sal_contable,0),nvl(c.sal_contable,0) * -1),
                                     decode(substr(a.cod_rubro,9,1),'9',nvl(c.sal_contable,0)*-1,nvl(c.sal_contable,0)))) sal_contable,
       0 - sum((decode(substr(a.cod_rubro,1,1),'2',decode(substr(a.cod_rubro,9,1),'9',c.sal_contable,nvl(c.sal_contable,0) * -1),
                                     decode(substr(a.cod_rubro,9,1),'9',nvl(c.sal_contable,0)*-1,nvl(c.sal_contable,0)))))
       diferencia
 from ba_monedas m,
      cb_rubros a,
      ba_oficinas o,cb_cla_rubros l,
      (select cod_rubro, cod_moneda, cod_oficina, sum(sal_contable) sal_contable
          from bv_sal_rub_resultados
         group by cod_rubro, cod_moneda, cod_oficina) c
where a.cod_moneda = m.cod_moneda
  and a.cod_moneda = c.cod_moneda
  and a.cod_rubro = c.cod_rubro
  and o.cod_oficina=c.cod_oficina
  and substr(a.cod_rubro,1,1) in ('6','7')
  and a.imputable = 'S'
  and substr(a.cod_rubro,6,8)=l.cod_clasificacion (+)
  and not exists (select 1
                  from cb_sal_inventarios_his d, cb_rubros cr
                  where d.fecha = pag_cal.FU_OBT_FEC_ACTUAL(2)
                    and d.cod_rubro = cr.cod_rubro
                    and d.cod_rubro = c.cod_rubro
                    and cr.cod_moneda = m.cod_moneda
                    and d.cod_oficina= c.cod_oficina
                    and d.tip_saldo = 'K')
  and not exists (select 1
                  from cb_sal_inv_contables d, cb_rubros cr
                  where d.cod_rubro = cr.cod_rubro
                    and d.cod_rubro = c.cod_rubro
                    and cr.cod_moneda = m.cod_moneda
                    and d.cod_oficina= c.cod_oficina
                    and d.tip_saldo = 'K')
group by a.cod_rubro, a.cod_rub_externo,substr(a.cod_rubro,6,8), nvl(l.descripcion,'SIN DEFINICION'), l.tipo,
       substr(a.cod_rubro,6,3), substr(a.cod_rubro,9,2),substr(a.cod_rubro,11,3),
       a.descripcion ,
       a.cod_moneda,
       m.descripcion,
       c.cod_oficina,o.descripcion;

