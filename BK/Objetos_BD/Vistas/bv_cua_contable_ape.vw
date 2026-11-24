create or replace force view it.bv_cua_contable_ape as
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
          from bv_sal_contables_ape
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
  and substr(b.cod_rubro,1,1) in ('1','2','4','5') -- RB 02/07/2012. Se visualiza solamente las cuentas patrimoniales.
  and substr(a.cod_rubro,6,8)=l.cod_clasificacion (+)
  and a.cod_oficina=o.cod_oficina
  and a.cod_rubro not in(select distinct g.cod_rubro
                              from ge_tip_asientos g, ge_transacciones c
                              where g.cod_tip_asiento=c.cod_tip_asiento
                              and c.cod_transaccion=8846
                              and g.tip_movimiento='D')
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
          from bv_sal_contables_ape
         group by cod_rubro, cod_moneda, cod_oficina) c
where a.cod_moneda = m.cod_moneda
  and a.cod_moneda = c.cod_moneda
  and a.cod_rubro = c.cod_rubro
  and o.cod_oficina=c.cod_oficina
  and substr(a.cod_rubro,1,1) in ('1','2','4','5') -- RB 02/07/2012. Se visualiza solamente las cuentas patrimoniales.
  and a.imputable = 'S'
  and substr(a.cod_rubro,6,8)=l.cod_clasificacion (+)
  and not exists (select 1
                  from cb_sal_inventarios d
                  where d.cod_rubro = c.cod_rubro
                    and d.cod_moneda = m.cod_moneda
                    and c.cod_oficina=d.cod_oficina)
  and a.cod_rubro not in(select distinct g.cod_rubro
                              from ge_tip_asientos g, ge_transacciones c
                              where g.cod_tip_asiento=c.cod_tip_asiento
                              and c.cod_transaccion=8846
                              and g.tip_movimiento='D')
group by a.cod_rubro, a.cod_rub_externo,substr(a.cod_rubro,6,8), nvl(l.descripcion,'SIN DEFINICION'), l.tipo,
       substr(a.cod_rubro,6,3), substr(a.cod_rubro,9,2),substr(a.cod_rubro,11,3),
       a.descripcion ,
       a.cod_moneda,
       m.descripcion,
       c.cod_oficina,o.descripcion
---venta de cartera
union all
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
          from bv_sal_contables_ape
         group by cod_rubro, cod_moneda, cod_oficina) c,
      (select pas_cri.fu_obt_cod_rubro(cb.nro_cuenta, cb.cod_modulo, cb.cod_modalidad, 8846,
                                                                    g.cod_moneda, NULL, null,
                                                                    NULL, NULL, 'D', NULL, null) cod_rubro, g.cod_moneda, cb.cod_oficina,
              sum( nvl(cb.sal_deu_cta_actual,cb.mto_deu_mon_cuenta) ) sal_total
       from ge_sal_inv_vta_cartera_his cb, ge_cuentas g
       where cb.nro_cuenta=g.nro_cuenta
       and cb.estado IN ( 'V', 'C' )
       AND cb.ope_recaptados = 'N'
       group by pas_cri.fu_obt_cod_rubro(cb.nro_cuenta, cb.cod_modulo, cb.cod_modalidad, 8846,
                                                                    g.cod_moneda, NULL, null,
                                                                    NULL, NULL, 'D', NULL, null), g.cod_moneda, cb.cod_oficina) a
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
;

