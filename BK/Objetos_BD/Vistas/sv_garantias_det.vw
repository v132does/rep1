CREATE OR REPLACE FORCE VIEW IT.SV_GARANTIAS_DET AS
SELECT b.nro_garantia nro_garantia,
       nvl(SUM(nvl(a.val_edilicio, 0)), 0) mto_tas_asegurable,
       nvl(SUM(nvl(a.val_terreno, 0)), 0) mto_tas_no_asegurable,
       nvl(SUM(nvl(a.val_seguro, 0)), 0) mto_asegurado,
       MAX(nvl(b.cod_mon_tasacion,b.cod_moneda)) cod_mon_tasacion
  FROM pr_gar_hipotecarias a, pr_garantias b
 WHERE a.nro_garantia = b.nro_garantia
   AND a.fec_vencimiento > pag_cal.fu_obt_fec_actual(1)
  GROUP BY b.nro_garantia, b.cod_mon_tasacion

UNION
SELECT d.nro_garantia,
       nvl(SUM(nvl(c.val_tasacion, 0)), 0),
       0,
       nvl(SUM(nvl(c.val_seguro, 0)), 0),
       MAX(nvl(d.cod_mon_tasacion,d.cod_moneda)) cod_mon_tasacion
  FROM pr_gar_vehiculos c, pr_garantias d
 WHERE c.nro_garantia = d.nro_garantia
   AND c.fec_vencimiento > pag_cal.fu_obt_fec_actual(1)
 GROUP BY d.nro_garantia, d.cod_mon_tasacion
UNION
SELECT b.nro_garantia,
       nvl(SUM(nvl(b.valor, 0)), 0) mto_tas_asegurable,
       0 mto_tas_no_asegurable,
       0 mto_seguro,
       MAX(nvl(b.cod_mon_tasacion,b.cod_moneda)) cod_mon_tasacion
  FROM pr_gar_cash a, pr_garantias b
 WHERE a.nro_garantia = b.nro_garantia
 GROUP BY b.nro_garantia, b.cod_mon_tasacion
UNION
SELECT b.nro_garantia,
       nvl(SUM(nvl(b.valor, 0)), 0) mto_tas_asegurable,
       0 mto_tas_no_asegurable,
       0 mto_seguro,
       MAX(nvl(b.cod_mon_tasacion,b.cod_moneda)) cod_mon_tasacion
  FROM pr_gar_standbys a, pr_garantias b
 WHERE a.nro_garantia = b.nro_garantia
 GROUP BY b.nro_garantia, b.cod_mon_tasacion
UNION
SELECT b.nro_garantia,
       nvl(SUM(nvl(b.valor, 0)), 0)  mto_tas_asegurable,
       0 mto_tas_no_asegurable,
       nvl(SUM(decode(a.cod_ent_seguro, NULL, 0, (b.valor))),
           0) mto_seguro, --- si tiene monto seguro
       MAX(nvl(b.cod_mon_tasacion,b.cod_moneda)) cod_mon_tasacion
  FROM pr_gar_warrants a, pr_garantias b
 WHERE a.nro_garantia = b.nro_garantia
   AND a.fec_vencimiento > pag_cal.fu_obt_fec_actual(1)
 GROUP BY b.nro_garantia, b.cod_moneda
;

