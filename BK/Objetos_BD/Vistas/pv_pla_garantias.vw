CREATE OR REPLACE FORCE VIEW IT.PV_PLA_GARANTIAS AS
SELECT tip_gar,
       oficina,
       max(fecha) fecha,
       cod_persona,
       nom_persona,
       SUM(mto_riesgo) mto_riesgo,
       cod_moneda,
       cotizacion,
       SUM(mto_aplicado_eq_dolar) mto_aplicado_eq_dolar,
       SUM(mto_aplicado_gs) mto_aplicado_gs,
       SUM(mto_aplicado) mto_aplicado,
       SUM(mto_computable_eq_dolar) mto_computable_eq_dolar,
       SUM(mto_computable_gs) mto_computable_gs,
       SUM(mto_computable) mto_valor,
      --- (mto_valor) mto_valor,
       least(SUM(mto_riesgo),  ((mto_valor))) mto_informe
  FROM (SELECT res.tip_gar,
               rie.oficina,
               res.fecha,
               res.cod_persona,
               res.nom_persona,
               rie.mto_riesgo,
               res.cod_moneda,
               res.cotizacion,
               res.mto_aplicado_eq_dolar,
               res.mto_aplicado_gs,
               res.mto_aplicado,
               res.mto_computable_eq_dolar,
               res.mto_computable_gs,
               res.mto_computable,
               val.mto_valor
          FROM (SELECT MAX(a.fec_confirmacion) fecha,
                       d.cod_persona,
                       fue_obt_nom_persona(d.cod_persona) nom_persona,
                       e.descripcion tip_gar,
                       decode(a.cod_moneda, 'USD', SUM(b.mto_aplicado), 0) mto_aplicado_eq_dolar,
                       decode(a.cod_moneda, 'USD', SUM(b.mto_con_computable), 0) mto_computable_eq_dolar,
                       nvl(fug_obt_cotizacion(a.cod_moneda, pag_cal.fu_obt_fec_actual(1)), 1) cotizacion,
                       decode(a.cod_moneda, 'GS', SUM(b.mto_aplicado), 0) mto_aplicado_gs,
                       decode(a.cod_moneda, 'GS', SUM(b.mto_con_computable), 0) mto_computable_gs,
                       a.cod_moneda,
                       SUM(pag_gen.fu_con_mon_a_moneda(a.cod_moneda, pag_gen.fu_obt_mon_local,
                                                       (nvl(b.mto_aplicado, 0)),
                                                       nvl(fug_obt_cotizacion(a.cod_moneda,
                                                                               pag_cal.fu_obt_fec_actual(1)),
                                                            1))) mto_aplicado,
                       SUM(pag_gen.fu_con_mon_a_moneda(a.cod_moneda, pag_gen.fu_obt_mon_local,
                                                       (nvl(b.mto_con_computable, 0)),
                                                       nvl(fug_obt_cotizacion(a.cod_moneda,
                                                                               pag_cal.fu_obt_fec_actual(1)),
                                                            1))) mto_computable
                  FROM pr_garantias     a,
                       ta_cta_garantias b,
                       ta_cta_tarjetas  c,
                       ge_cta_clientes  d,
                       pr_gar_tipos     e
                 WHERE a.cod_garantia = b.cod_garantia
                   AND a.nro_garantia = b.nro_garantia
                   AND b.nro_cuenta = c.nro_cuenta
                   AND c.nro_cuenta = d.nro_cuenta
                   AND c.cod_modulo = d.cod_modulo
                   AND c.cod_modalidad = d.cod_modalidad
                   AND d.relacion = 'P'
                   AND c.estado NOT IN ('C', 'I')
                   AND e.cod_garantia = a.cod_garantia
                   AND e.cod_garantia = b.cod_garantia
                   AND e.por_bco_central > 0
                   AND nvl(a.valor, 0) > 0
                   AND a.estado IN ('C', 'I')
                 GROUP BY d.cod_persona, a.cod_garantia, e.descripcion, a.cod_moneda) res,
               (SELECT fue_obt_des_oficina(tot_rie.oficina) oficina,
                       tip_gar.cod_persona,
                       SUM(round((tip_gar.mto_aplicado * tip_gar.porcentaje) / 100)) mto_riesgo,
                       des_garantia tip_gar
                  FROM (SELECT t.nro_cuenta,
                               t.mto_aplicado,
                               d.mto_aplicado detalle,
                               d.cod_garantia,
                               (SELECT descripcion
                                  FROM pr_gar_tipos
                                 WHERE cod_garantia = d.cod_garantia) des_garantia,
                               t.cod_persona,
                               round((d.mto_aplicado * 100) /
                                     decode(t.mto_aplicado, 0, 1, t.mto_aplicado)) porcentaje
                          FROM (SELECT DISTINCT (a.nro_cuenta) nro_cuenta,
                                                c.cod_persona,
                                                SUM(a.mto_aplicado) mto_aplicado
                                  FROM ta_cta_garantias a, pr_garantias g, ge_cta_clientes c
                                 WHERE a.nro_garantia = g.nro_garantia
                                   AND a.cod_garantia = g.cod_garantia
                                    AND c.relacion = 'P'
                                   AND a.nro_cuenta = c.nro_cuenta
                                   AND g.estado IN ('C', 'I')
                                   AND nvl(g.valor, 0) > 0
                                 GROUP BY a.nro_cuenta, c.cod_persona) t,
                               (SELECT DISTINCT (a.nro_cuenta) nro_cuenta,
                                                g.cod_persona,
                                                g.cod_garantia,
                                                SUM(a.mto_aplicado) mto_aplicado
                                  FROM ta_cta_garantias a, pr_garantias g
                                 WHERE a.nro_garantia = g.nro_garantia
                                   AND a.cod_garantia = g.cod_garantia
                                   AND g.estado IN ('C', 'I')
                                   AND nvl(g.valor, 0) > 0
                                 GROUP BY a.nro_cuenta, g.cod_persona, g.cod_garantia) d
                         WHERE t.nro_cuenta = d.nro_cuenta) tip_gar,
                       (SELECT c.cod_oficina oficina,
                               c.cod_persona,
                               c.nro_cuenta,
                               SUM(c.tot_deu_real) mto_riesgo
                          FROM ge_cla_operaciones c, ta_cta_tarjetas p
                         WHERE c.nro_cuenta = p.nro_cuenta
                           AND c.tot_gar_computables > 0
                           AND cod_estado <> 'C'
                           AND c.nro_cuenta IN
                               (SELECT nro_cuenta
                                  FROM ta_cta_garantias cta, pr_garantias gar
                                 WHERE cta.nro_garantia = gar.nro_garantia)
                         GROUP BY c.cod_oficina, c.cod_persona, c.nro_cuenta) tot_rie
                 WHERE tip_gar.cod_persona = tot_rie.cod_persona
                   AND tip_gar.nro_cuenta = tot_rie.nro_cuenta
                 GROUP BY fue_obt_des_oficina(tot_rie.oficina), tip_gar.cod_persona, des_garantia) rie,
               (SELECT MAX(b.fec_confirmacion) fecha,
                       pre.cod_persona,
                       fue_obt_nom_persona(pre.cod_persona) nom_persona,
                       e.descripcion tip_gar,
                       SUM(pag_gen.fu_con_mon_a_moneda(b.cod_moneda, pag_gen.fu_obt_mon_local,
                                                       (nvl(b.valor, 0)),
                                                       nvl(fug_obt_cotizacion(b.cod_moneda,
                                                                               pag_cal.fu_obt_fec_actual(1)),
                                                            1))) mto_valor
                  FROM (SELECT DISTINCT (a.nro_garantia), a.cod_garantia, d.cod_persona
                          FROM ta_cta_garantias a, ta_cta_tarjetas c, ge_cta_clientes d
                         WHERE a.nro_cuenta = c.nro_cuenta
                           AND d.nro_cuenta = a.nro_cuenta
                           AND d.relacion = 'P'
                           AND c.estado NOT IN ('C', 'I')) pre,
                       pr_garantias b,
                       pr_gar_tipos e
                 WHERE b.nro_garantia = pre.nro_garantia
                   AND b.cod_garantia = pre.cod_garantia
                   AND b.cod_garantia = e.cod_garantia
                   AND nvl(e.por_bco_central, 0) > 0
                   AND nvl(b.valor, 0) > 0
                   AND b.estado IN ('C', 'I')
                 GROUP BY pre.cod_persona, e.descripcion) val
         WHERE res.cod_persona = rie.cod_persona
           AND res.tip_gar = rie.tip_gar
           AND res.tip_gar = val.tip_gar
           AND rie.tip_gar = val.tip_gar
           AND res.cod_persona = val.cod_persona
           AND rie.cod_persona = val.cod_persona
        UNION ALL
        SELECT res.tip_gar,
               rie.oficina,
               res.fecha,
               res.cod_persona,
               res.nom_persona,
               rie.mto_riesgo,
               res.cod_moneda,
               res.cotizacion,
               res.mto_aplicado_eq_dolar,
               res.mto_aplicado_gs,
               res.mto_aplicado,
               res.mto_computable_eq_dolar,
               res.mto_computable_gs,
               res.mto_computable,
               val.mto_valor
          FROM (SELECT MAX(a.fec_confirmacion) fecha,
                       d.cod_persona,
                       fue_obt_nom_persona(d.cod_persona) nom_persona,
                       e.descripcion tip_gar, b.nro_cuenta,
                       CASE
                          WHEN a.cod_moneda = 'USD' and c.cod_moneda = 'GS' THEN
                           round(nvl(SUM(b.mto_aplicado), 0)/nvl(fug_obt_cotizacion(a.cod_moneda, pag_cal.fu_obt_fec_actual(1)), 1),2)
                          WHEN c.cod_moneda = 'USD'   THEN
                           nvl(SUM(b.mto_aplicado), 0)
                       END mto_aplicado_eq_dolar,
                       CASE
                          WHEN a.cod_moneda = 'USD' and c.cod_moneda = 'GS' THEN
                           round(nvl(SUM(b.mto_con_computable), 0)/nvl(fug_obt_cotizacion(a.cod_moneda, pag_cal.fu_obt_fec_actual(1)), 1),2)
                          WHEN c.cod_moneda = 'USD'   THEN
                           nvl(SUM(b.mto_con_computable), 0)
                       END mto_computable_eq_dolar,
                       CASE
                          WHEN a.cod_moneda = 'USD' THEN
                           nvl(fug_obt_cotizacion(a.cod_moneda, pag_cal.fu_obt_fec_actual(1)), 1)
                          WHEN c.cod_moneda = 'USD' THEN
                           nvl(fug_obt_cotizacion(c.cod_moneda, pag_cal.fu_obt_fec_actual(1)), 1)
                       END cotizacion,
                       CASE
                          WHEN a.cod_moneda = 'GS' AND c.cod_moneda = 'GS' THEN
                           nvl(SUM(b.mto_aplicado), 0)
                          WHEN a.cod_moneda = 'USD' AND c.cod_moneda = 'GS' THEN
                            nvl(SUM(b.mto_aplicado), 0)
                          ELSE
                           0
                       END mto_aplicado_gs,
                       CASE
                          WHEN a.cod_moneda = 'GS' AND c.cod_moneda = 'GS' THEN
                           nvl(SUM(b.mto_con_computable), 0)
                          WHEN a.cod_moneda = 'USD' AND c.cod_moneda = 'GS' THEN
                            nvl(SUM(b.mto_con_computable), 0)
                          ELSE
                           0
                       END mto_computable_gs
                       , a.cod_moneda,
                       CASE
                          WHEN a.cod_moneda = 'GS' AND c.cod_moneda = 'GS' THEN
                           nvl(SUM(b.mto_aplicado), 0)
                          WHEN a.cod_moneda = 'GS' AND c.cod_moneda = 'USD' THEN
                           SUM(pag_gen.fu_con_mon_a_moneda(c.cod_moneda, pag_gen.fu_obt_mon_local,
                                                           (nvl(b.mto_aplicado, 0)),
                                                           nvl(fug_obt_cotizacion(c.cod_moneda,
                                                                                   pag_cal.fu_obt_fec_actual(1)),
                                                                1)))

                          WHEN a.cod_moneda = 'USD' AND c.cod_moneda = 'GS' THEN
                           SUM(nvl(b.mto_aplicado, 0))
                          WHEN a.cod_moneda = 'USD' AND c.cod_moneda = 'USD' THEN
                           SUM(pag_gen.fu_con_mon_a_moneda(a.cod_moneda, pag_gen.fu_obt_mon_local,
                                                           (nvl(b.mto_aplicado, 0)),
                                                           nvl(fug_obt_cotizacion(a.cod_moneda,
                                                                                   pag_cal.fu_obt_fec_actual(1)),
                                                                1)))
                       END mto_aplicado,
                       CASE
                          WHEN a.cod_moneda = 'GS' AND c.cod_moneda = 'GS' THEN
                           nvl(SUM(b.mto_con_computable), 0)
                          WHEN a.cod_moneda = 'GS' AND c.cod_moneda = 'USD' THEN
                           SUM(pag_gen.fu_con_mon_a_moneda(c.cod_moneda, pag_gen.fu_obt_mon_local,
                                                           (nvl(b.mto_con_computable, 0)),
                                                           nvl(fug_obt_cotizacion(c.cod_moneda,
                                                                                   pag_cal.fu_obt_fec_actual(1)),
                                                                1)))

                          WHEN a.cod_moneda = 'USD' AND c.cod_moneda = 'GS' THEN
                           SUM(nvl(b.mto_con_computable, 0))
                          WHEN a.cod_moneda = 'USD' AND c.cod_moneda = 'USD' THEN
                           SUM(pag_gen.fu_con_mon_a_moneda(a.cod_moneda, pag_gen.fu_obt_mon_local,
                                                           (nvl(b.mto_con_computable, 0)),
                                                           nvl(fug_obt_cotizacion(a.cod_moneda,
                                                                                   pag_cal.fu_obt_fec_actual(1)),
                                                                1)))
                       END mto_computable
                  FROM pr_garantias     a,
                       pr_cta_garantias b,
                       pr_cta_prestamos c,
                       ge_cta_clientes  d,
                       pr_gar_tipos     e
                 WHERE a.cod_garantia = b.cod_garantia
                   AND a.nro_garantia = b.nro_garantia
                   AND b.nro_cuenta = c.nro_cuenta
                   AND c.nro_cuenta = d.nro_cuenta
                   AND c.cod_modulo = d.cod_modulo
                   AND c.cod_modalidad = d.cod_modalidad
                   AND d.relacion = 'P'
                   AND c.estado NOT IN ('N', 'I')
                   AND e.cod_garantia = a.cod_garantia
                   AND e.cod_garantia = b.cod_garantia
                   AND e.por_bco_central > 0
                   AND nvl(a.valor, 0) > 0
                   AND a.estado IN ('C', 'I')
                 GROUP BY d.cod_persona, a.cod_garantia, e.descripcion, a.cod_moneda, c.cod_moneda, b.nro_cuenta) res,
               (SELECT fue_obt_des_oficina(tot_rie.oficina) oficina,
                       tip_gar.cod_persona,
                       SUM(round((tot_rie.mto_riesgo * tip_gar.porcentaje) / 100)) mto_riesgo,
                       des_garantia tip_gar, tip_gar.nro_cuenta
                  FROM (SELECT t.nro_cuenta,
                               t.mto_aplicado,
                               d.mto_aplicado_detalle detalle,
                               d.cod_garantia,
                               t.cod_persona,
                               (SELECT descripcion
                                  FROM pr_gar_tipos
                                 WHERE cod_garantia = d.cod_garantia) des_garantia,
                               round((d.mto_aplicado_detalle * 100) /
                                     decode(t.mto_aplicado, 0, 1, t.mto_aplicado)) porcentaje
                          FROM (SELECT DISTINCT (a.nro_cuenta) nro_cuenta,
                                                SUM(a.mto_aplicado) mto_aplicado,
                                                c.cod_persona
                                  FROM pr_cta_garantias a, pr_garantias g, ge_ctA_clientes c
                                 WHERE a.nro_garantia = g.nro_garantia
                                   AND a.cod_garantia = g.cod_garantia
                                   AND a.nro_cuenta = c.nro_cuenta
                                   AND c.relacion = 'P'
                                   AND g.estado IN ('C', 'I')
                                   AND nvl(g.valor, 0) > 0
                                 GROUP BY a.nro_cuenta, c.cod_persona) t,
                               (SELECT DISTINCT (a.nro_cuenta) nro_cuenta,
                                                g.cod_garantia,
                                                SUM(a.mto_aplicado) mto_aplicado_detalle
                                  FROM pr_cta_garantias a, pr_garantias g, ge_cta_clientes c
                                 WHERE a.nro_garantia = g.nro_garantia
                                   AND a.cod_garantia = g.cod_garantia
                                   AND c.relacion = 'P'
                                   AND a.nro_cuenta = c.nro_cuenta
                                   AND g.estado IN ('C', 'I')
                                   AND nvl(g.valor, 0) > 0
                                 GROUP BY a.nro_cuenta,  g.cod_garantia, c.cod_persona) d
                                WHERE t.nro_cuenta = d.nro_cuenta) tip_gar,
                       (SELECT c.cod_oficina oficina,
                               c.cod_persona,
                               c.nro_cuenta,
                               SUM(c.tot_deu_real) mto_riesgo
                          FROM ge_cla_operaciones c, pr_cta_prestamos p
                         WHERE c.nro_cuenta = p.nro_cuenta
                           AND c.tot_gar_computables > 0
                           AND cod_estado <> 'N'
                           AND c.nro_cuenta IN
                               (SELECT nro_cuenta
                                  FROM pr_cta_garantias cta, pr_garantias gar
                                 WHERE cta.nro_garantia = gar.nro_garantia)
                         GROUP BY c.cod_oficina, c.cod_persona, c.nro_cuenta) tot_rie
                 WHERE tip_gar.cod_persona = tot_rie.cod_persona
                   AND tip_gar.nro_cuenta = tot_rie.nro_cuenta
                 GROUP BY fue_obt_des_oficina(tot_rie.oficina),
                          tip_gar.cod_persona,
                          des_garantia, tip_gar.nro_cuenta
                ) rie,
               (SELECT MAX(b.fec_confirmacion) fecha,
                       pre.cod_persona,
                       fue_obt_nom_persona(pre.cod_persona) nom_persona,
                       e.descripcion tip_gar,
                       SUM(pag_gen.fu_con_mon_a_moneda(b.cod_moneda, pag_gen.fu_obt_mon_local,
                                                       (nvl(b.valor, 0)),
                                                       nvl(fug_obt_cotizacion(b.cod_moneda,
                                                                               pag_cal.fu_obt_fec_actual(1)),
                                                            1))) mto_valor
                  FROM (SELECT DISTINCT (a.nro_garantia), a.cod_garantia, d.cod_persona
                          FROM pr_cta_garantias a, pr_cta_prestamos c, ge_cta_clientes d
                         WHERE a.nro_cuenta = c.nro_cuenta
                           AND d.nro_cuenta = a.nro_cuenta
                           AND d.relacion = 'P'
                           AND c.estado NOT IN ('N', 'I')) pre,
                       pr_garantias b,
                       pr_gar_tipos e
                 WHERE b.nro_garantia = pre.nro_garantia
                   AND b.cod_garantia = pre.cod_garantia
                   AND b.cod_garantia = e.cod_garantia
                   AND nvl(e.por_bco_central, 0) > 0
                   AND nvl(b.valor, 0) > 0
                   AND b.estado IN ('C', 'I')
                 GROUP BY pre.cod_persona, e.descripcion) val
         WHERE res.cod_persona = rie.cod_persona
           AND res.tip_gar = rie.tip_gar
           AND res.tip_gar = val.tip_gar
           AND rie.tip_gar = val.tip_gar
           AND res.cod_persona = val.cod_persona
           AND rie.cod_persona = val.cod_persona
           AND rie.nro_cuenta  = res.nro_cuenta)
 GROUP BY oficina,fecha, cod_persona, nom_persona, tip_gar, cod_moneda, cotizacion, mto_valor
 ORDER BY 1, 5
;

