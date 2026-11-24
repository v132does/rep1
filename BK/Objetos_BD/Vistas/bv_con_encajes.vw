CREATE OR REPLACE FORCE VIEW IT.BV_CON_ENCAJES AS
SELECT '04_Control_x_Modalidad' tip_control, s.fecha,
       r.cod_moneda moneda,
       CASE
         WHEN r.cod_moneda = 'GS' AND substr(s.cod_rubro, 3, 1) BETWEEN '1' AND '6' THEN
          15
         WHEN r.cod_moneda = 'GS' AND substr(s.cod_rubro, 3, 1) = '8' THEN
          0
         WHEN r.cod_moneda = 'USD' AND substr(s.cod_rubro, 3, 1) BETWEEN '1' AND '6' THEN
          26.5
         WHEN r.cod_moneda = 'USD' AND substr(s.cod_rubro, 3, 1) = '8' THEN
          1.5
       END sujeto_a,
       CASE
         WHEN r.cod_rubro LIKE '21_1010202%' OR
              r.cod_rubro LIKE '21_1010204%' THEN
          'Bancos del Pais'
         WHEN r.cod_rubro LIKE '22110136%' OR r.cod_rubro like '21110284%' OR
              r.cod_rubro LIKE '22140290%' THEN
          'Cuentas Corrientes'
         WHEN r.cod_rubro like '22110148%' THEN
          'Cheque Certificado'
         WHEN ((r.cod_rubro like '21110196%' OR r.cod_rubro like '22110138%' OR
              r.cod_rubro like '22140238%' OR r.cod_rubro like '22140292%' OR
              r.cod_rubro like '22110236%' OR r.cod_rubro like '21110102%') AND
              r.cod_rubro NOT LIKE '2111010202%' AND
              r.cod_rubro NOT LIKE '2111010204%') THEN
          'Ahorro a la Vista'
         WHEN (r.cod_rubro LIKE '22_10156%' OR r.cod_rubro LIKE '21_10104%' OR
              r.cod_rubro LIKE '22_40298%') AND
              substr(r.cod_rubro, 3, 1) BETWEEN '1' AND '6' THEN
          'CDA Vista'
         WHEN r.cod_rubro LIKE '22810156%' THEN
          'CDA Plazo'
       END tipo,
       'Contable' tip_saldo,
       SUM(decode(r.cod_moneda,
                  'GS',
                  nvl(s.sal_mon_loc_ant, 0) + nvl(s.deb_mon_local, 0) -
                  nvl(s.cre_mon_local, 0),
                  nvl(s.sal_mon_rub_ant, 0) + nvl(s.deb_mon_rubro, 0) -
                  nvl(s.cre_mon_rubro, 0))) saldo,
       0 int_vencido,
       0 total
  FROM cb_sal_consolidados_dia s, cb_rubros r
 WHERE r.imputable = 'S'
   AND r.cod_rubro = s.cod_rubro
   AND (r.cod_rubro LIKE '21_1010202%' OR r.cod_rubro LIKE '21_1010204%' OR -- Bancos del pais
       r.cod_rubro LIKE '22110136%' OR r.cod_rubro like '21110284%' OR
       r.cod_rubro LIKE '22140290%' OR -- Cuentas Corrientes
       r.cod_rubro like '22110148%' OR
       ((r.cod_rubro LIKE '21110196%' OR r.cod_rubro LIKE '22110138%' OR
       r.cod_rubro LIKE '22140238%' OR r.cod_rubro LIKE '22140292%' OR
       r.cod_rubro LIKE '22110236%' OR r.cod_rubro LIKE '21110102%') AND
       r.cod_rubro NOT LIKE '2111010202%' AND
       r.cod_rubro NOT LIKE '2111010204%') OR -- Ahorro a la Vista
       ((r.cod_rubro LIKE '22_10156%' OR r.cod_rubro LIKE '21_10104%' OR
       r.cod_rubro LIKE '22_40298%') AND
       substr(r.cod_rubro, 3, 1) BETWEEN '1' AND '6') OR -- CDA Vista
       r.cod_rubro LIKE '22810156%' -- CDA
       )
 GROUP BY s.fecha,
          r.cod_moneda,
          CASE
            WHEN r.cod_moneda = 'GS' AND
                 substr(s.cod_rubro, 3, 1) BETWEEN '1' AND '6' THEN
             15
            WHEN r.cod_moneda = 'GS' AND substr(s.cod_rubro, 3, 1) = '8' THEN
             0
            WHEN r.cod_moneda = 'USD' AND
                 substr(s.cod_rubro, 3, 1) BETWEEN '1' AND '6' THEN
             26.5
            WHEN r.cod_moneda = 'USD' AND substr(s.cod_rubro, 3, 1) = '8' THEN
             1.5
          END,
          CASE
            WHEN r.cod_rubro LIKE '21_1010202%' OR
                 r.cod_rubro LIKE '21_1010204%' THEN
             'Bancos del Pais'
            WHEN r.cod_rubro LIKE '22110136%' OR
                 r.cod_rubro like '21110284%' OR
                 r.cod_rubro LIKE '22140290%' THEN
             'Cuentas Corrientes'
            WHEN r.cod_rubro like '22110148%' THEN
             'Cheque Certificado'
            WHEN ((r.cod_rubro like '21110196%' OR
                 r.cod_rubro like '22110138%' OR
                 r.cod_rubro like '22140238%' OR
                 r.cod_rubro like '22140292%' OR
                 r.cod_rubro like '22110236%' OR
                 r.cod_rubro like '21110102%') AND
                 r.cod_rubro NOT LIKE '2111010202%' AND
                 r.cod_rubro NOT LIKE '2111010204%') THEN
             'Ahorro a la Vista'
            WHEN (r.cod_rubro LIKE '22_10156%' OR
                 r.cod_rubro LIKE '21_10104%' OR
                 r.cod_rubro LIKE '22_40298%') AND
                 substr(r.cod_rubro, 3, 1) BETWEEN '1' AND '6' THEN
             'CDA Vista'
            WHEN r.cod_rubro LIKE '22810156%' THEN
             'CDA Plazo'
          END
UNION ALL
SELECT '04_Control_x_Modalidad' tip_control, x.fec_anterior fecha,
       ah.cod_moneda moneda,
       CASE
         WHEN ah.cod_moneda = 'GS' AND plazo BETWEEN 361 AND 540 THEN
          7
         WHEN ah.cod_moneda = 'GS' AND plazo >= 541 THEN
          0
         WHEN ah.cod_moneda = 'USD' AND plazo BETWEEN 361 AND 540 THEN
          16.5
         WHEN ah.cod_moneda = 'USD' AND plazo BETWEEN 541 AND 1080 THEN
          6.5
         WHEN ah.cod_moneda = 'USD' AND plazo >= 1080 THEN
          1.5
       END sujeto_a,
       'CDA Plazo' tipo,
       'Fisico' tip_saldo,
       nvl(SUM(capital), 0) capital,
       nvl(SUM(xx_mto_interes), 0) mto_interes,
       nvl(SUM(capital), 0) + nvl(SUM(xx_mto_interes), 0) cap_interes
  FROM (SELECT nro_cuenta,
               cod_moneda,
               fec_vencimiento - fec_apertura plazo,
               capital
          FROM ah_cta_certificados ah
         WHERE fec_vencimiento - fec_apertura >= 361
           AND est_cer_batch NOT IN ('V', 'P')
           AND est_batch NOT IN ('T', 'A', 'C', 'X')
           AND 'N' =
               nvl(fug_obt_paradicional(ah.nro_cuenta, 'EXO_ENCAJES'), 'N')) ah,
       ge_calendarios x,
       (SELECT g.nro_cuenta xx_nro_cuenta,
               SUM(nvl(g.mto_interes, 0)) xx_mto_interes
          FROM ah_cupones g
         WHERE g.est_batch = 'V'
         GROUP BY g.nro_cuenta)
 WHERE x.cod_modulo = 3
   AND xx_nro_cuenta(+) = ah.nro_cuenta
 GROUP BY x.fec_anterior,
          ah.cod_moneda,
          CASE
            WHEN ah.cod_moneda = 'GS' AND plazo BETWEEN 361 AND 540 THEN
             7
            WHEN ah.cod_moneda = 'GS' AND plazo >= 541 THEN
             0
            WHEN ah.cod_moneda = 'USD' AND plazo BETWEEN 361 AND 540 THEN
             16.5
            WHEN ah.cod_moneda = 'USD' AND plazo BETWEEN 541 AND 1080 THEN
             6.5
            WHEN ah.cod_moneda = 'USD' AND plazo >= 1080 THEN
             1.5
          END
 ---ORDER BY 2, 3, 4 DESC, 5, 6
------
union all
select '01_Control_Diferencia', a.fecha, a.cod_moneda, 9999,
       'CAL_DIFERENCIA',
       'RUBROS' TIPO,
       nvl(a.saldo,0) sal_inventario,
       decode(a.cod_moneda,'GS',ROUND(nvl(b.saldo,0)/1000,0),b.saldo) sal_contable,
       nvl(a.saldo,0)+decode(a.cod_moneda,'GS',ROUND(nvl(b.saldo,0)/1000,0),b.saldo) diferencia
from
(
select a.fecha fecha,
       'GS' cod_moneda,
       nvl(a.sujeto_d,0)+nvl(a.sujeto_e,0)+nvl(a.sujeto_f,0)+nvl(a.sujeto_g,0) saldo
from sb_encajes_ml a
union all
select a.fecha fecha,
       a.cod_moneda cod_moneda,
       nvl(a.sujeto_a,0)+nvl(a.sujeto_b,0)+nvl(a.sujeto_c,0)+nvl(a.sujeto_d,0) saldo
from sb_encajes_me a)
 a,
(
select a.fecha fecha,
       c.cod_moneda cod_moneda,
       sum(decode(c.cod_moneda,'GS',
       nvl(a.sal_mon_loc_ant,0)+nvl(a.deb_mon_local,0)-nvl(a.cre_mon_local,0),
       nvl(a.sal_mon_rub_ant,0)+nvl(a.deb_mon_rubro,0)-nvl(a.cre_mon_rubro,0))) saldo
from cb_sal_consolidados_dia a, cb_gru_rubros_det b, cb_rubros c
where b.cod_gru_rubro = 16 --Grupo de Rubros de Encaje--
  and substr(b.cod_rubro,1,2)||substr(b.cod_rubro,4,5) = substr(a.cod_rubro,1,2)||substr(a.cod_rubro,4,5)
  and c.cod_rubro = a.cod_rubro
  and c.imputable = 'S'
  and decode(c.cod_moneda,'GS',nvl(a.sal_mon_loc_ant,0)+nvl(a.deb_mon_local,0)-nvl(a.cre_mon_local,0),
             nvl(a.sal_mon_rub_ant,0)+nvl(a.deb_mon_rubro,0)-nvl(a.cre_mon_rubro,0)) <> 0
group by a.fecha, c.cod_moneda
) b
where a.cod_moneda = b.cod_moneda
  and a.fecha = b.fecha
union all
select '02_Saldos_Contables', a.fecha, c.cod_moneda, to_number(c.cod_rubro),
       c.descripcion,
       'RUBROS' TIPO,
       decode(c.cod_moneda,'GS',
       nvl(a.sal_mon_loc_ant,0)+nvl(a.deb_mon_local,0)-nvl(a.cre_mon_local,0),
       nvl(a.sal_mon_rub_ant,0)+nvl(a.deb_mon_rubro,0)-nvl(a.cre_mon_rubro,0)) saldo, 0,0
from cb_sal_consolidados_dia a, cb_gru_rubros_det b, cb_rubros c
where b.cod_gru_rubro = 16 --Grupo de Rubros de Encaje--
  and substr(b.cod_rubro,1,2)||substr(b.cod_rubro,4,5) = substr(a.cod_rubro,1,2)||substr(a.cod_rubro,4,5)
  and c.cod_rubro = a.cod_rubro
  and c.imputable = 'S'
  and decode(c.cod_moneda,'GS',nvl(a.sal_mon_loc_ant,0)+nvl(a.deb_mon_local,0)-nvl(a.cre_mon_local,0),
             nvl(a.sal_mon_rub_ant,0)+nvl(a.deb_mon_rubro,0)-nvl(a.cre_mon_rubro,0)) <> 0
union all
select '03_Saldos_Inventarios', a.fecha, 'GS', 9999,
       'ENCAJES',
       'SUJETO_15' TIPO,
       nvl(a.sujeto_d,0)+nvl(a.sujeto_e,0) saldo, 0,0
from sb_encajes_ml a
UNION ALL
select '03_Saldos_Inventarios', a.fecha, 'GS', 9999,
       'ENCAJES',
       'SUJETO_7' TIPO,
       nvl(a.sujeto_f,0) saldo, 0,0
from sb_encajes_ml a
union all
select '03_Saldos_Inventarios', a.fecha, 'GS', 9999,
       'ENCAJES',
       'SUJETO_0' TIPO,
       nvl(a.sujeto_g,0) saldo, 0,0
from sb_encajes_ml a
union all
select '03_Saldos_Inventarios', a.fecha, a.cod_moneda, 9999,
       'ENCAJES',
       'SUJETO_26,5' TIPO,
       nvl(a.sujeto_a,0) saldo, 0,0
from sb_encajes_me a
union all
select '03_Saldos_Inventarios', a.fecha, a.cod_moneda, 9999,
       'ENCAJES',
       'SUJETO_16,5' TIPO,
       nvl(a.sujeto_b,0) saldo, 0,0
from sb_encajes_me a
union all
select '03_Saldos_Inventarios', a.fecha, a.cod_moneda, 9999,
       'ENCAJES',
       'SUJETO_6,5' TIPO,
       nvl(a.sujeto_c,0) saldo, 0,0
from sb_encajes_me a
union all
select '03_Saldos_Inventarios', a.fecha, a.cod_moneda, 9999,
       'ENCAJES',
       'SUJETO_1,5' TIPO,
       nvl(a.sujeto_d,0) saldo, 0,0
from sb_encajes_me a
order by 1
;

