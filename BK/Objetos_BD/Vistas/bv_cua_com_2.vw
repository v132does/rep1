CREATE OR REPLACE FORCE VIEW IT.BV_CUA_COM_2 AS
SELECT fub_obt_rub_formateado(b.cod_rubro) rubro,
       b.cod_rubro,
       b.descripcion nombre_rubro,
       pag_cal.fu_obt_fec_actual(2) fecha,
       c.cod_moneda mon,
       m.descripcion moneda,
       nvl(SUM(a.sal_total), 0) tot_inventario,
       SUM(decode(substr(c.cod_rubro, 1, 1), '2',
                  decode(substr(c.cod_rubro, 9, 1), '9', nvl(c.sal_contable, 0),
                          nvl(c.sal_contable, 0) * -1),
                  decode(substr(c.cod_rubro, 9, 1), '9', nvl(c.sal_contable, 0) * -1,
                          nvl(c.sal_contable, 0)))) sal_contable,
       SUM(nvl(a.sal_total, 0)) -
       SUM(decode(substr(c.cod_rubro, 1, 1), '2',
                  decode(substr(c.cod_rubro, 9, 1), '9', nvl(c.sal_contable, 0),
                          nvl(c.sal_contable, 0) * -1),
                  decode(substr(c.cod_rubro, 9, 1), '9', nvl(c.sal_contable, 0) * -1,
                          nvl(c.sal_contable, 0)))) diferencia
  FROM ba_monedas m,
       cb_rubros b,
       (SELECT cod_rubro, cod_moneda, SUM(sal_contable) sal_contable
          FROM bv_sal_contables
         GROUP BY cod_rubro, cod_moneda) c,
       (SELECT cod_rubro, cod_moneda, SUM(nvl(sal_total, 0)) sal_total
          FROM cb_sal_inventarios_his cb
         WHERE cb.fecha = pag_cal.fu_obt_fec_actual(2)
         GROUP BY cod_rubro, cod_moneda) a
 WHERE c.cod_rubro = b.cod_rubro(+)
   AND b.cod_moneda = m.cod_moneda(+)
   AND c.cod_rubro = a.cod_rubro(+)
   AND c.cod_moneda = a.cod_moneda(+)
  -- AND c.cod_oficina = a.cod_oficina(+)
   AND b.imputable = 'S'
 --  AND c.cod_rubro IN (SELECT cod_rubro FROM cb_sal_inventarios_his)
  -- AND (c.sal_contable <> 0 OR a.sal_total <> 0)
 GROUP BY b.descripcion, c.cod_moneda, m.descripcion, b.cod_rubro
union
SELECT fub_obt_rub_formateado(b.cod_rubro) rubro,
       b.cod_rubro,
       b.descripcion nombre_rubro,
       c.fecha,
       c.cod_moneda mon,
       m.descripcion moneda,
       nvl(SUM(a.sal_total), 0) tot_inventario,
       SUM(decode(substr(c.cod_rubro, 1, 1), '2',
                  decode(substr(c.cod_rubro, 9, 1), '9', nvl(c.sal_contable, 0),
                          nvl(c.sal_contable, 0) * -1),
                  decode(substr(c.cod_rubro, 9, 1), '9', nvl(c.sal_contable, 0) * -1,
                          nvl(c.sal_contable, 0)))) sal_contable,
       SUM(nvl(a.sal_total, 0)) -
       SUM(decode(substr(c.cod_rubro, 1, 1), '2',
                  decode(substr(c.cod_rubro, 9, 1), '9', nvl(c.sal_contable, 0),
                          nvl(c.sal_contable, 0) * -1),
                  decode(substr(c.cod_rubro, 9, 1), '9', nvl(c.sal_contable, 0) * -1,
                          nvl(c.sal_contable, 0)))) diferencia
  FROM ba_monedas m,
       cb_rubros b,
       (SELECT a.cod_rubro, s.cod_moneda,  a.fecha, sum(decode(s.cod_moneda, 'GS',
              (nvl(a.sal_mon_loc_ant, 0) + nvl(a.deb_mon_local, 0) - nvl(a.cre_mon_local, 0)),
              (nvl(a.sal_mon_rub_ant, 0) + nvl(a.deb_mon_rubro, 0) - nvl(a.cre_mon_rubro, 0)))) sal_contable
          FROM cb_sal_oficinas_dia a, cb_rubros s
         where s.cod_rubro = a.cod_rubro
         GROUP BY a.cod_rubro, cod_moneda, a.fecha) c,
       (SELECT cod_rubro,  cod_moneda, cb.fecha, SUM(nvl(sal_total, 0)) sal_total
          FROM cb_sal_inventarios_his cb
         GROUP BY cod_rubro, cod_moneda, fecha) a
 WHERE c.cod_rubro = b.cod_rubro(+)
   AND b.cod_moneda = m.cod_moneda(+)
   AND c.cod_rubro = a.cod_rubro(+)
   AND c.cod_moneda = a.cod_moneda(+)
 --  AND c.cod_oficina = a.cod_oficina(+)
   and c.fecha = a.fecha(+)
   AND b.imputable = 'S'
   --AND c.cod_rubro IN (SELECT cod_rubro FROM cb_sal_inventarios_his)
 --  AND (c.sal_contable <> 0 OR a.sal_total <> 0)
 GROUP BY b.descripcion, c.cod_moneda,c.fecha , m.descripcion, b.cod_rubro
;

