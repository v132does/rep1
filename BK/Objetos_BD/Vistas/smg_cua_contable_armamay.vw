create or replace force view it.smg_cua_contable_armamay as
select a.cod_rubro, b.cod_rub_externo, substr(a.cod_rubro,6,8) rubro, nvl(l.descripcion,'SIN DEFINICION') clasificacion, l.tipo,
       substr(a.cod_rubro,6,3) cuenta, substr(a.cod_rubro,9,2) sub_cuenta, substr(a.cod_rubro,11,3) producto,
       b.descripcion nombre_rubro,
       a.cod_oficina,o.descripcion des_oficina,
       a.cod_moneda mon,
       m.descripcion moneda,
       sum(a.sal_total) tot_inventario,
       sum (decode(substr(a.cod_rubro,1,1),'2',decode(substr(a.cod_rubro,9,1),'9',nvl(c.sal_contable,0),nvl(c.sal_contable,0) * -1),
                                     decode(substr(a.cod_rubro,9,1),'9',nvl(c.sal_contable,0)*-1,nvl(c.sal_contable,0)))) sal_contable,
       sum(nvl(sal_total,0)) -
       sum((decode(substr(a.cod_rubro,1,1),'2',decode(substr(a.cod_rubro,9,1),'9',c.sal_contable,nvl(c.sal_contable,0) * -1),
                                     decode(substr(a.cod_rubro,9,1),'9',nvl(c.sal_contable,0)*-1,nvl(c.sal_contable,0)))))
       diferencia
 from ba_monedas m,
      cb_rubros b,ba_oficinas o, cb_cla_rubros l,
      (select cod_rubro, cod_moneda, cod_oficina, sum(sal_contable) sal_contable
          from smg_cua_armamay
         group by cod_rubro, cod_moneda, cod_oficina) c,
      (select cod_rubro, cod_moneda, cb.cod_oficina,
              sum( nvl(sal_total,0) ) sal_total
       from cb_sal_inventarios cb
       group by cod_rubro, cod_moneda, cb.cod_oficina) a
where a.cod_rubro = b.cod_rubro (+)
  and a.cod_rubro = c.cod_rubro (+)
  and a.cod_moneda = c.cod_moneda (+)
  and a.cod_moneda = m.cod_moneda
  and a.cod_oficina = c.cod_oficina (+)
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
          from smg_cua_armamay
          where substr(cod_rubro,1,1) in ('1','2','4','5')
         group by cod_rubro, cod_moneda, cod_oficina) c
where a.cod_moneda = m.cod_moneda
  and a.cod_moneda = c.cod_moneda
  and a.cod_rubro = c.cod_rubro
  and o.cod_oficina=c.cod_oficina
  and a.imputable = 'S'
  and substr(a.cod_rubro,6,8)=l.cod_clasificacion (+)
  and not exists (select 1
                  from cb_sal_inventarios d
                  where d.cod_rubro = c.cod_rubro
                    and d.cod_moneda = m.cod_moneda
                    and c.cod_oficina=d.cod_oficina)
group by a.cod_rubro, a.cod_rub_externo,substr(a.cod_rubro,6,8), nvl(l.descripcion,'SIN DEFINICION'), l.tipo,
       substr(a.cod_rubro,6,3), substr(a.cod_rubro,9,2),substr(a.cod_rubro,11,3),
       a.descripcion ,
       a.cod_moneda,
       m.descripcion,
       c.cod_oficina,o.descripcion;

