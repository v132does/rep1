create or replace force view it.bv_cua_conciliaciones as
select a.cod_rubro, b.cod_rub_externo, substr(a.cod_rubro,6,8) rubro, nvl(l.descripcion,'SIN DEFINICION') clasificacion, l.tipo,
       substr(a.cod_rubro,6,3) cuenta, substr(a.cod_rubro,9,2) sub_cuenta, substr(a.cod_rubro,11,3) producto,
       b.descripcion nombre_rubro,
       a.cod_oficina,o.descripcion des_oficina,
       a.cod_moneda mon,
       m.descripcion moneda,
       --sum(a.sal_total) tot_inventario,
       sum (decode(substr(a.cod_rubro,1,1),'2',decode(substr(a.cod_rubro,9,1),'9',nvl(a.sal_total,0)* -1,nvl(a.sal_total,0)),
                                     decode(substr(a.cod_rubro,9,1),'9',nvl(a.sal_total,0),nvl(a.sal_total,0)*-1))) tot_inventario,
       sum (decode(substr(a.cod_rubro,1,1),'2',decode(substr(a.cod_rubro,9,1),'9',nvl(c.sal_contable,0),nvl(c.sal_contable,0) * -1),
                                     decode(substr(a.cod_rubro,9,1),'9',nvl(c.sal_contable,0)*-1,nvl(c.sal_contable,0)))) sal_contable,
       --sum(nvl(sal_total,0)) -
       sum (decode(substr(a.cod_rubro,1,1),'2',decode(substr(a.cod_rubro,9,1),'9',nvl(a.sal_total,0)* -1,nvl(a.sal_total,0)),
                                     decode(substr(a.cod_rubro,9,1),'9',nvl(a.sal_total,0),nvl(a.sal_total,0)*-1)))-
       sum((decode(substr(a.cod_rubro,1,1),'2',decode(substr(a.cod_rubro,9,1),'9',c.sal_contable,nvl(c.sal_contable,0) * -1),
                                     decode(substr(a.cod_rubro,9,1),'9',nvl(c.sal_contable,0)*-1,nvl(c.sal_contable,0)))))
       diferencia
 from ba_monedas m,
      cb_rubros b,ba_oficinas o, cb_cla_rubros l,
      (select cod_rubro, cod_moneda, cod_oficina, sum(sal_contable) sal_contable
          from (select
                a.cod_rubro,
                b.descripcion,
                a.cod_oficina,
                cod_moneda,
                decode(b.cod_moneda,'GS',(nvl(a.sal_mon_loc_ant,0)+nvl(a.deb_mon_local,0)-nvl(a.cre_mon_local,0)),
                (nvl(a.sal_mon_rub_ant,0)+nvl(a.deb_mon_rubro,0)-nvl(a.cre_mon_rubro,0))) sal_contable
                from cb_rubros b, cb_sal_oficinas_dia a
                where a.cod_rubro = b.cod_rubro
                and substr(a.cod_rubro,1,1) in ('1','2','4','5')
                and a.fecha=(select max(x.fecha) from cb_cor_rub_det x)
                and decode(b.cod_moneda,'GS',(nvl(a.sal_mon_loc_ant,0)+nvl(a.deb_mon_local,0)-nvl(a.cre_mon_local,0)),
                (nvl(a.sal_mon_rub_ant,0)+nvl(a.deb_mon_rubro,0)-nvl(a.cre_mon_rubro,0))) <> 0
                )

         group by cod_rubro, cod_moneda, cod_oficina) c,
      (select cb.cod_rubro, cb.cod_moneda, cb.cod_oficina,
              sum( nvl(decode(cb.tip_mov,'C',cb.monto,cb.monto*-1),0) ) sal_total
       from cb_cor_rub_det cb
       group by cod_rubro, cod_moneda, cb.cod_oficina) a
where a.cod_rubro = b.cod_rubro (+)
  and a.cod_rubro = c.cod_rubro (+)
  and a.cod_moneda = c.cod_moneda (+)
  and a.cod_moneda = m.cod_moneda
  and a.cod_oficina = c.cod_oficina (+)
  and substr(a.cod_rubro,6,8)=l.cod_clasificacion (+)
  and a.cod_oficina=o.cod_oficina
  --and a.cod_rubro not in ('240402600200999')
group by a.cod_rubro, b.cod_rub_externo,substr(a.cod_rubro,6,8), nvl(l.descripcion,'SIN DEFINICION'), l.tipo,
       substr(a.cod_rubro,6,3),substr(a.cod_rubro,9,2),substr(a.cod_rubro,11,3),
       b.descripcion ,
       a.cod_moneda,
       m.descripcion,
       a.cod_oficina,o.descripcion

union

select c.cod_rubro, b.cod_rub_externo, substr(a.cod_rubro,6,8) rubro, nvl(l.descripcion,'SIN DEFINICION') clasificacion, l.tipo,
       substr(a.cod_rubro,6,3) cuenta, substr(a.cod_rubro,9,2) sub_cuenta, substr(a.cod_rubro,11,3) producto,
       b.descripcion nombre_rubro,
       a.cod_oficina,o.descripcion des_oficina,
       a.cod_moneda mon,
       m.descripcion moneda,
       --sum(a.sal_total) tot_inventario,
       sum (decode(substr(a.cod_rubro,1,1),'2',decode(substr(a.cod_rubro,9,1),'9',nvl(a.sal_total,0)* -1,nvl(a.sal_total,0)),
                                     decode(substr(a.cod_rubro,9,1),'9',nvl(a.sal_total,0),nvl(a.sal_total,0)*-1))) tot_inventario,
       sum (decode(substr(a.cod_rubro,1,1),'2',decode(substr(a.cod_rubro,9,1),'9',nvl(c.sal_contable,0),nvl(c.sal_contable,0) * -1),
                                     decode(substr(a.cod_rubro,9,1),'9',nvl(c.sal_contable,0)*-1,nvl(c.sal_contable,0)))) sal_contable,
       --sum(nvl(sal_total,0)) -
       sum (decode(substr(a.cod_rubro,1,1),'2',decode(substr(a.cod_rubro,9,1),'9',nvl(a.sal_total,0)* -1,nvl(a.sal_total,0)),
                                     decode(substr(a.cod_rubro,9,1),'9',nvl(a.sal_total,0),nvl(a.sal_total,0)*-1)))-
       sum((decode(substr(a.cod_rubro,1,1),'2',decode(substr(a.cod_rubro,9,1),'9',c.sal_contable,nvl(c.sal_contable,0) * -1),
                                     decode(substr(a.cod_rubro,9,1),'9',nvl(c.sal_contable,0)*-1,nvl(c.sal_contable,0)))))
       diferencia
 from ba_monedas m,
      cb_rubros b,ba_oficinas o, cb_cla_rubros l,
      (select cod_rubro, cod_moneda, cod_oficina, sum(sal_contable) sal_contable
          from (select
                a.cod_rubro,
                b.descripcion,
                a.cod_oficina,
                cod_moneda,
                decode(b.cod_moneda,'GS',(nvl(a.sal_mon_loc_ant,0)+nvl(a.deb_mon_local,0)-nvl(a.cre_mon_local,0)),
                (nvl(a.sal_mon_rub_ant,0)+nvl(a.deb_mon_rubro,0)-nvl(a.cre_mon_rubro,0))) sal_contable
                from cb_rubros b, cb_sal_oficinas_dia a
                where a.cod_rubro = b.cod_rubro
                and substr(a.cod_rubro,1,1) in ('1','2','4','5')
                and a.fecha=(select max(x.fecha) from cb_cor_rub_det x)
                and decode(b.cod_moneda,'GS',(nvl(a.sal_mon_loc_ant,0)+nvl(a.deb_mon_local,0)-nvl(a.cre_mon_local,0)),
                (nvl(a.sal_mon_rub_ant,0)+nvl(a.deb_mon_rubro,0)-nvl(a.cre_mon_rubro,0))) <> 0
                )

         group by cod_rubro, cod_moneda, cod_oficina) c,
      (select cb.cod_rubro, cb.cod_moneda, cb.cod_oficina,
              sum( nvl(decode(cb.tip_mov,'C',cb.monto,cb.monto*-1),0) ) sal_total
       from cb_cor_rub_det cb
       group by cod_rubro, cod_moneda, cb.cod_oficina) a, cb_cor_rubros ccr
where c.cod_rubro = b.cod_rubro (+)
  and c.cod_rubro = a.cod_rubro (+)
  and c.cod_moneda = a.cod_moneda (+)
  and c.cod_moneda = m.cod_moneda
  and c.cod_oficina = a.cod_oficina (+)
  and substr(c.cod_rubro,6,8)=l.cod_clasificacion (+)
  and c.cod_oficina=o.cod_oficina
  and c.cod_rubro = ccr.cod_rubro
  and ccr.estado = 'A' -- SOLO INCLUIR RUBROS ACTIVOS DE CONCILIACION PARA EL CONTROL - 19/jul/2013 PFRDR
  --and a.cod_rubro not in ('240402600200999')
group by c.cod_rubro, b.cod_rub_externo,substr(a.cod_rubro,6,8), nvl(l.descripcion,'SIN DEFINICION'), l.tipo,
       substr(a.cod_rubro,6,3),substr(a.cod_rubro,9,2),substr(a.cod_rubro,11,3),
       b.descripcion ,
       a.cod_moneda,
       m.descripcion,
       a.cod_oficina,o.descripcion
;

