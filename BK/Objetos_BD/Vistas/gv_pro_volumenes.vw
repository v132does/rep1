CREATE OR REPLACE VIEW IT.GV_PRO_VOLUMENES AS
select pag_cal.fu_obt_fec_anterior(1) fecha, cod_programa, cantidad
from(
--PAP_CAT.PR_PRO_CAT_RES37
 select 'PAP_CAT.PR_PRO_CAT_RES37' cod_programa, count(1) cantidad
 from (SELECT a.nro_cuenta
 FROM ge_cta_clientes b, pr_cta_prestamos a
WHERE a.nro_cuenta = b.nro_cuenta
  AND b.relacion = 'P'
  AND ((nvl(a.sal_capital, 0) + nvl(a.sal_int_adelantado, 0) + nvl(a.sal_interes, 0) > 0
  AND a.estado NOT IN ('N', 'I')) or (a.estado = 'N' and a.fec_cancelacion = pag_cal.fu_obt_fec_anterior(1)))
  and not exists (select 1 from pr_vta_carteras x where x.nro_cuenta = a.nro_cuenta)
union
SELECT g.nro_cuenta
 FROM pv_cat_sobregiros g,
      (SELECT nvl(pr.monto, 0) mnto_prevision,
              nvl(pr.tot_pri_prevision, 0) mnto_tot_pri_prevision,
              pr.nro_cuenta
         FROM cc_previsiones pr
        WHERE pr.fecha = (SELECT MAX(pv.fecha)
                            FROM cc_previsiones pv
                           WHERE pr.nro_cuenta = pv.nro_cuenta)) f
WHERE f.nro_cuenta(+) = g.nro_cuenta
union
select a.nro_cuenta
from it.ge_cla_operaciones_tmp a
       where fecha = pag_cal.fu_obt_fec_anterior(1)
union
SELECT a.nro_cuenta
 FROM ge_cta_clientes b, ta_cta_tarjetas a
WHERE b.nro_cuenta = a.nro_cuenta
  AND a.estado <> 'C'
  AND b.relacion = 'P' --y principales de cuenta;
  AND (( EXISTS (SELECT t.nro_cuenta
                   FROM ta_tarjetas t
                  WHERE t.nro_cuenta = a.nro_cuenta
                    AND t.vigente = 'S')) OR
       ( nvl(a.sal_facturar, 0) + nvl(a.sal_facturado, 0) +
         nvl(a.sal_financiado, 0) + nvl(a.sal_cuo_pendientes, 0) <> 0))
  AND NOT EXISTS
     (SELECT t.nro_cuenta
              FROM ta_tarjetas t
             WHERE t.nro_cuenta = a.nro_cuenta
               AND t.vigente = 'S'
               AND T.COD_ESTADO = 12
               and exists
             (SELECT t.nro_cuenta
                      FROM ta_cta_tarjetas t
                     WHERE t.nro_cuenta = a.nro_cuenta
                       and nvl(a.sal_facturar, 0) + nvl(a.sal_facturado, 0) +
                           nvl(a.sal_financiado, 0) +
                           nvl(a.sal_cuo_pendientes, 0) = 0))
union
SELECT a.nro_cuenta
   FROM ge_cta_clientes b, ov_cta_vencidas a
  WHERE a.nro_cuenta = b.nro_cuenta
    AND nvl(a.sal_total, 0) > 0
    AND a.estado NOT IN ('C', 'I')
    AND b.relacion = 'P'
union
select nro_cuenta
from (SELECT a.nro_cuenta
         FROM ge_cta_clientes b, cx_cta_importaciones a
        WHERE a.nro_cuenta = b.nro_cuenta
          AND a.estado NOT IN ('C', 'S') -- cancelada y solicitada
          and (case when (a.mto_prepago > a.mto_utilizado) then
                     a.saldo - (a.mto_prepago - a.mto_utilizado)
                   else a.saldo end) > 0
          AND b.relacion = 'P'
       UNION
       SELECT a.nro_cuenta
         FROM ge_cta_clientes b, cx_fianzas a
        WHERE a.nro_cuenta = b.nro_cuenta
          AND b.relacion = 'P'
          AND a.estado NOT IN ('C', 'S') -- cancelada y solicitada
          AND a.monto > 0)
UNION
SELECT a.nro_cuenta
   FROM md_cta_documentos a, ge_cta_clientes ge
  WHERE a.nro_cuenta = ge.nro_cuenta
    AND fug_obt_pardinamico('PRE_CAT_MAD_MESA',a.cod_modulo,a.cod_modalidad) = 'S'
    AND a.estado = 'C'
    AND ge.relacion = 'P'
union
select b.nro_cuenta
   from ge_cla_operaciones a, pr_cta_prestamos b
  where b.nro_cuenta = a.nro_cuenta
    and exists (select 1 from ba_cod_referencias where dominio = 'COD_MAD_FIDEICOMISO' and val_minimo = a.cod_modalidad)
    and exists (select 1
                  from ge_cta_dat_adicionales c
                 where c.parametro in ('PRE_RRR_CTA_MBT','PRE_RRR_CTA_MBT1','PRE_RRR_CTA_MBT2')
                   and ((c.nro_cuenta = b.nro_cuenta)
                    or (c.val_parametro = b.nro_cuenta)))
union
select '1' NRO_CUENTA
  from it.vm_total_operaciones zz
union
select nro_cuenta
from (
SELECT cod_gru_economico,
        SUM(nvl(tot_deu_real, 0)) ww_ttdeuda,
        SUM(nvl(tot_deu_contingente, 0)) ww_ttdeuco,
        SUM(nvl(tot_gar_computables, 0)) ww_ttgarco,
        SUM(nvl(capital, 0)) ww_capital,
        SUM(nvl(tot_deu_sistema, 0)) ww_tot_deu_sistema,
        SUM(nvl(tot_prevision, 0)) ww_ttprevi,
        b.nro_cuenta
   FROM ge_clientes a,
        (SELECT s.cod_persona, SUM(mto_original) capital, s.nro_cuenta
           FROM ge_cla_operaciones s, ge_clientes e
          WHERE s.cod_persona = e.cod_persona
            AND fup_inc_ope_med_gru(e.cod_gru_economico, nro_cuenta) = 'S'
          GROUP BY s.cod_persona, s.nro_cuenta) b
  WHERE cod_gru_economico IS NOT NULL
    AND a.cod_persona = b.cod_persona
    AND EXISTS
  (SELECT 0 FROM ge_gru_economicos b WHERE b.cod_gru_economico = a.cod_gru_economico)
  GROUP BY cod_gru_economico,nro_cuenta
 HAVING SUM(nvl(tot_deu_real, 0) + nvl(tot_deu_contingente, 0)) > 0))
  union all
--PRA_ACT_CUENTAS
SELECT 'PRA_ACT_CUENTAS' cod_programa, cant cantidad
  FROM (SELECT count(1) cant, a.fecha
          FROM GE_MOVIMIENTOS_ANT A
         INNER JOIN GE_TRANSACCIONES T
            ON A.COD_TRANSACCION = T.COD_TRANSACCION
           AND A.COD_MODULO = T.COD_MODULO
           AND A.COD_MODALIDAD = T.COD_MODALIDAD
         WHERE A.COD_TRANSACCION > 0
           AND A.ESTADO = 'N'
           AND A.NRO_CUENTA IS NOT NULL
           AND T.RUTINA1 IS NOT NULL
           and a.fecha = pag_cal.fu_obt_fec_anterior(1)
         GROUP BY A.FECHA)
union all
--PRA_DEV_VIS_DIARIO
SELECT 'PRA_DEV_VIS_DIARIO' cod_programa, count(1) cantidad
  FROM AH_CTA_VISTAS A,
       GE_CTA_CLIENTES B,
       GE_CLIENTES C,
       GE_CALENDARIOS D,
       (SELECT T.COD_PERSONA, NVL(COUNT(*), 0) CAN_USUARIO
          FROM BA_USUARIOS T
         WHERE T.ESTADO = 'A'
           AND T.COD_PERSONA IS NOT NULL
         GROUP BY T.COD_PERSONA) U
 WHERE ESTADO NOT IN ('C', 'A', 'P', 'X')
   AND FEC_APERTURA <= pag_cal.fu_obt_fec_anterior(1)
   AND B.NRO_CUENTA = A.NRO_CUENTA
   AND B.RELACION = 'P'
   AND U.COD_PERSONA(+) = B.COD_PERSONA
   AND C.COD_PERSONA = B.COD_PERSONA
   AND D.COD_MODULO = 3
union all
--PRP_GEN_CTA_GARANTIA
SELECT 'PRP_GEN_CTA_GARANTIA' cod_programa, count(1) cantidad
  FROM (SELECT o.nro_cuenta
          FROM ov_cta_vencidas o,
               ge_est_cuentas e,
               ge_cta_clientes cc,
               (SELECT nvl(SUM(nvl(og.mto_aplicado, 0)), 0) mto_aplicado,
                       og.nro_cuenta
                  FROM ov_cta_garantias og, pr_garantias g
                 WHERE og.nro_garantia = g.nro_garantia
                   AND og.cod_garantia = g.cod_garantia
                   AND nvl(g.estado, 'C') = 'C'
                      -- No es Abierta, Propia o a Sola Firma
                   AND NOT
                        ((nvl(g.tipo, 'x') = 'A') OR og.cod_garantia IN (1, 2))
                 GROUP BY og.nro_cuenta) f
         WHERE o.nro_cuenta = cc.nro_cuenta
           AND o.estado = e.estado
           AND o.cod_modulo = e.cod_modulo
           AND o.cod_modalidad = e.cod_modalidad
           AND e.activo = 'S'
           AND o.estado <> 'I'
           AND cc.relacion = 'P'
           AND o.nro_cuenta = f.nro_cuenta(+)
        UNION ALL
        SELECT cc.nro_cuenta
          FROM pr_cta_prestamos p,
               ge_est_cuentas e,
               ge_cta_clientes cc,
               (SELECT nvl(SUM(nvl(pg.mto_aplicado, 0)), 0) mto_aplicado,
                       pg.nro_cuenta
                  FROM pr_cta_garantias pg, pr_garantias g
                 WHERE pg.nro_garantia = g.nro_garantia
                   AND pg.cod_garantia = g.cod_garantia
                   AND nvl(g.estado, 'C') = 'C' -- Confirmada
                      -- No es Abierta, Propia o a Sola Firma
                   AND NOT
                        ((nvl(g.tipo, 'x') = 'A') OR pg.cod_garantia IN (1, 2))
                 GROUP BY pg.nro_cuenta) f
         WHERE p.nro_cuenta = cc.nro_cuenta
           AND p.estado = e.estado
           AND p.cod_modulo = e.cod_modulo
           AND p.cod_modalidad = e.cod_modalidad
           AND e.activo = 'S'
           AND p.estado <> 'I'
           AND cc.relacion = 'P'
           AND p.nro_cuenta = f.nro_cuenta(+)
           AND not exists
         (select 1
                  from ge_par_dinamicos g
                 where g.parametro in
                       ('PRE_MAD_CONSTRUCCIONES', 'MAD_HIPOTECARIOS')
                   and g.cod_modulo = e.cod_modulo
                   and g.cod_modalidad = e.cod_modalidad
                   and g.val_parametro = 'S')
        UNION ALL
        /*Cuentas Corrientes + funcion que obtiene el monto aplicado */
        SELECT c.nro_cuenta
          FROM cc_cta_corrientes c,
               ge_est_cuentas    e,
               ge_cta_clientes   cc,
               cc_sobregiros_res r
         WHERE c.nro_cuenta = cc.nro_cuenta
           AND c.estado = e.estado
           AND c.cod_modulo = e.cod_modulo
           AND c.cod_modalidad = e.cod_modalidad
           AND c.nro_cuenta = r.nro_cuenta(+)
           AND e.activo = 'S'
           AND cc.relacion = 'P'
           AND c.sal_total < 0
        UNION ALL
        /*Tarjetas + funcion que obtiene el monto aplicado */
        SELECT t.nro_cuenta
          FROM ta_cta_tarjetas t,
               ge_est_cuentas e,
               ge_cta_clientes cc,
               (SELECT nvl(SUM(nvl(tg.mto_aplicado, 0)), 0) mto_aplicado,
                       tg.nro_cuenta
                  FROM ta_cta_garantias tg, pr_garantias g
                 WHERE tg.nro_garantia = g.nro_garantia
                   AND tg.cod_garantia = g.cod_garantia
                   AND nvl(g.estado, 'C') = 'C'
                      -- No es Abierta, Propia o a Sola Firma
                   AND NOT
                        ((nvl(g.tipo, 'x') = 'A') OR tg.cod_garantia IN (1, 2))
                 GROUP BY nro_cuenta) f
         WHERE t.nro_cuenta = cc.nro_cuenta
           AND t.estado = e.estado
           AND t.cod_modulo = e.cod_modulo
           AND t.cod_modalidad = e.cod_modalidad
           AND e.activo = 'S'
           AND cc.relacion = 'P'
           AND t.nro_cuenta = f.nro_cuenta(+)

        /*Comercio Exterior Fianzas+ funcion que obtiene el monto aplicado */
        UNION ALL
        SELECT xf.nro_cuenta
          FROM cx_fianzas xf,
               ge_est_cuentas ec,
               (SELECT nvl(SUM(nvl(xg.mto_aplicado, 0)), 0) mto_aplicado,
                       xg.nro_cuenta
                  FROM cx_cta_garantias xg, pr_garantias g
                 WHERE xg.nro_garantia = g.nro_garantia
                   AND xg.cod_garantia = g.cod_garantia
                   AND nvl(g.estado, 'C') = 'C'
                      -- No es Abierta, Propia o a Sola Firma
                   AND NOT
                        ((nvl(g.tipo, 'x') = 'A') OR xg.cod_garantia IN (1, 2))
                 GROUP BY xg.nro_cuenta) f
         WHERE xf.estado = ec.estado
           AND xf.cod_modulo = ec.cod_modulo
           AND xf.cod_modalidad = ec.cod_modalidad
           AND ec.activo = 'S'
           AND xf.monto > 0
           AND xf.estado = 'A'
        UNION ALL
        /*Comercio Exterior + funcion que obtiene el monto aplicado */
        SELECT xi.nro_cuenta
          FROM cx_cta_importaciones xi,
               ge_est_cuentas ec,
               ge_cta_clientes cc,
               (SELECT nvl(SUM(nvl(xg.mto_aplicado, 0)), 0) mto_aplicado,
                       xg.nro_cuenta
                  FROM cx_cta_garantias xg, pr_garantias g
                 WHERE xg.nro_garantia = g.nro_garantia
                   AND xg.cod_garantia = g.cod_garantia
                   AND nvl(g.estado, 'C') = 'C'
                      -- No es Abierta, Propia o a Sola Firma
                   AND NOT
                        ((nvl(g.tipo, 'x') = 'A') OR xg.cod_garantia IN (1, 2))
                 GROUP BY xg.nro_cuenta) f
         WHERE cc.nro_cuenta = xi.nro_cuenta
           AND xi.estado = ec.estado
           AND xi.cod_modulo = ec.cod_modulo
           AND xi.cod_modalidad = ec.cod_modalidad
           AND ec.activo = 'S'
           AND cc.relacion = 'P'
           AND xi.saldo > 0
           AND xi.nro_cuenta = f.nro_cuenta(+))
union all
--PRG_TRA_HISTORICO
select 'PRG_TRA_HISTORICO' descripcion, count(1) cantidad
  from (SELECT m.nro_cuenta
          FROM ge_movimientos_ant m
          LEFT JOIN ge_movimientos_tmp t
            ON t.fecha = pag_cal.fu_obt_fec_actual(1)
           AND t.hora = m.hora
           AND t.nro_secuencia = m.nro_secuencia
           AND t.cod_usuario = m.cod_usuario
         WHERE (m.cod_transaccion > 0 OR m.cod_rubro IS NOT NULL)
           AND ((m.cod_modulo = 1 AND m.cod_mod_padre = 1) OR
               (m.cod_modulo = 2 AND m.cod_mod_padre in (1, 2, 9)))
           AND t.fecha IS NULL
        union all
        SELECT m.nro_cuenta
          FROM ge_movimientos_ant m
          LEFT JOIN ge_movimientos_tmp t
            ON t.fecha = pag_cal.fu_obt_fec_actual(1)
           AND t.hora = m.hora
           AND t.nro_secuencia = m.nro_secuencia
           AND t.cod_usuario = m.cod_usuario
         WHERE (m.cod_transaccion > 0 OR m.cod_rubro IS NOT NULL)
           AND (m.cod_modulo = 3 OR
               (m.cod_modulo = 9 AND m.cod_mod_padre = 3))
           AND t.fecha IS NULL
        union all
        SELECT m.nro_cuenta
          FROM ge_movimientos_ant m
          LEFT JOIN ge_movimientos_tmp t
            ON t.fecha = pag_cal.fu_obt_fec_actual(1)
           AND t.hora = m.hora
           AND t.nro_secuencia = m.nro_secuencia
           AND t.cod_usuario = m.cod_usuario
         WHERE (m.cod_transaccion > 0 OR m.cod_rubro IS NOT NULL)
           AND (m.cod_modulo = 4 OR
               (m.cod_modulo = 9 AND m.cod_mod_padre = 4))
           AND t.fecha IS NULL
        union all
        SELECT m.nro_cuenta
          FROM ge_movimientos_ant m
          LEFT JOIN ge_movimientos_tmp t
            ON t.fecha = pag_cal.fu_obt_fec_actual(1)
           AND t.hora = m.hora
           AND t.nro_secuencia = m.nro_secuencia
           AND t.cod_usuario = m.cod_usuario
         WHERE (m.cod_transaccion > 0 OR m.cod_rubro IS NOT NULL)
           AND (m.cod_modulo = 5 OR
               (m.cod_modulo = 9 AND m.cod_mod_padre = 5))
           AND t.fecha IS NULL
        union all
        SELECT m.nro_cuenta
          FROM ge_movimientos_ant m
          LEFT JOIN ge_movimientos_tmp t
            ON t.fecha = pag_cal.fu_obt_fec_actual(1)
           AND t.hora = m.hora
           AND t.nro_secuencia = m.nro_secuencia
           AND t.cod_usuario = m.cod_usuario
         WHERE (m.cod_transaccion > 0 OR m.cod_rubro IS NOT NULL)
           AND (m.cod_modulo = 6 OR
               (m.cod_modulo = 9 AND m.cod_mod_padre = 6))
           AND t.fecha IS NULL
        union all
        SELECT m.nro_cuenta
          FROM ge_movimientos_ant m
          LEFT JOIN ge_movimientos_tmp t
            ON t.fecha = pag_cal.fu_obt_fec_actual(1)
           AND t.hora = m.hora
           AND t.nro_secuencia = m.nro_secuencia
           AND t.cod_usuario = m.cod_usuario
         WHERE (m.cod_transaccion > 0 OR m.cod_rubro IS NOT NULL)
           AND (m.cod_modulo = 7 OR
               (m.cod_modulo = 9 AND m.cod_mod_padre = 7))
           AND t.fecha IS NULL
        union all
        SELECT m.nro_cuenta
          FROM ge_movimientos_ant m
          LEFT JOIN ge_movimientos_tmp t
            ON t.fecha = pag_cal.fu_obt_fec_actual(1)
           AND t.hora = m.hora
           AND t.nro_secuencia = m.nro_secuencia
           AND t.cod_usuario = m.cod_usuario
         WHERE (m.cod_transaccion > 0 OR m.cod_rubro IS NOT NULL)
           AND (m.cod_modulo = 8 OR
               (m.cod_modulo = 9 AND m.cod_mod_padre = 8))
           AND t.fecha IS NULL
        union all
        SELECT m.nro_cuenta
          FROM ge_movimientos_ant m
          LEFT JOIN ge_movimientos_tmp t
            ON t.fecha = pag_cal.fu_obt_fec_actual(1)
           AND t.hora = m.hora
           AND t.nro_secuencia = m.nro_secuencia
           AND t.cod_usuario = m.cod_usuario
         WHERE (m.cod_transaccion > 0 OR m.cod_rubro IS NOT NULL)
           AND (m.cod_modulo = 10 OR
               (m.cod_modulo = 9 AND m.cod_mod_padre = 10))
           AND t.fecha IS NULL
        union all
        SELECT m.nro_cuenta
          FROM ge_movimientos_ant m
          LEFT JOIN ge_movimientos_tmp t
            ON t.fecha = pag_cal.fu_obt_fec_actual(1)
           AND t.hora = m.hora
           AND t.nro_secuencia = m.nro_secuencia
           AND t.cod_usuario = m.cod_usuario
         WHERE (m.cod_transaccion > 0 OR m.cod_rubro IS NOT NULL)
           AND (m.cod_modulo = 13 OR
               (m.cod_modulo = 9 AND m.cod_mod_padre = 13))
           AND t.fecha IS NULL
        union all
        SELECT m.nro_cuenta
          FROM ge_movimientos_ant m
          LEFT JOIN ge_movimientos_tmp t
            ON t.fecha = pag_cal.fu_obt_fec_actual(1)
           AND t.hora = m.hora
           AND t.nro_secuencia = m.nro_secuencia
           AND t.cod_usuario = m.cod_usuario
         WHERE (m.cod_transaccion > 0 OR m.cod_rubro IS NOT NULL)
           AND (m.cod_modulo = 14 OR
               (m.cod_modulo = 9 AND m.cod_mod_padre = 14))
           AND t.fecha IS NULL
        union all
        SELECT m.nro_cuenta
          FROM ge_movimientos_ant m
          LEFT JOIN ge_movimientos_tmp t
            ON t.fecha = pag_cal.fu_obt_fec_actual(1)
           AND t.hora = m.hora
           AND t.nro_secuencia = m.nro_secuencia
           AND t.cod_usuario = m.cod_usuario
         WHERE (m.cod_transaccion > 0 OR m.cod_rubro IS NOT NULL)
           AND (nvl(m.cod_modulo, 15) IN (15, 16, 28) OR
               (m.cod_modulo = 9 AND m.cod_mod_padre IN (15, 16, 9, 28)))
           AND t.fecha IS NULL
        union all
        SELECT m.nro_cuenta
          FROM ge_movimientos_ant m
          LEFT JOIN ge_movimientos_tmp t
            ON t.fecha = pag_cal.fu_obt_fec_actual(1)
           AND t.hora = m.hora
           AND t.nro_secuencia = m.nro_secuencia
           AND t.cod_usuario = m.cod_usuario
         WHERE (m.cod_transaccion > 0 OR m.cod_rubro IS NOT NULL)
           AND (m.cod_modulo = 26 OR
               (m.cod_modulo = 9 AND m.cod_mod_padre = 26))
           AND t.fecha IS NULL)

union all
--PRP_DEV_PRE_FIN
SELECT 'PRP_DEV_PRE_FIN' cod_programa, count(1) cantidad
  FROM pr_cuotas cuo, pr_cta_prestamos pre
 WHERE cuo.nro_cuenta = pre.nro_cuenta
   and pre.cod_modalidad not in (670, 671, 699)
   AND pre.estado not in ('N', 'I')
   and (pre.fec_vencimiento > pag_cal.fu_obt_fec_anterior(1) or
       (pre.fec_vencimiento > pre.fec_ult_devengado and
       pre.val_int_devengar <> 0))
   and nvl(pre.fec_ult_devengado, pre.fec_inicio - 1) <
       pag_cal.fu_obt_fec_anterior(1)
   AND pre.fec_inicio <= pag_cal.fu_obt_fec_anterior(1)
   and cuo.nro_cuota > 0
   AND cuo.estado <> 'N'
   and cuo.sal_interes + nvl(cuo.sal_int_documentado, 0) > 0
   AND ((nvl(cuo.dev_acumulado, 0) <>
       (mto_interes + nvl(mto_int_documentado, 0) -
       nvl(mto_int_descontado, 0))) or
       (cuo.fec_vencimiento > nvl(pre.fec_ult_devengado, pre.fec_inicio)) OR
       (nvl(cuo.dev_no_cobrado, 0) + nvl(cuo.dev_suspenso, 0)) <>
       (nvl(cuo.dev_acumulado, 0) -
       ((mto_interes + nvl(mto_int_documentado, 0) -
       nvl(mto_int_descontado, 0)) -
       (cuo.sal_interes + nvl(sal_int_documentado, 0)))))
union all
--PRA_ACT_SAL_MENSUAL
SELECT 'PRA_ACT_SAL_MENSUAL' cod_programa, count(1) cantidad
  FROM AH_CTA_VISTAS
 WHERE ESTADO NOT IN ('C', 'A', 'X')
union all
--PRB_GEN_SAL_INVENTARIOS
select 'PRB_GEN_SAL_INVENTARIOS' cod_programa, count(1) cantidad
  from (SELECT a.nro_cuenta
          FROM ge_clientes     c,
               ge_cta_clientes b,
               ah_cta_vistas   a,
               ge_cuentas      cue
         WHERE c.cod_persona = b.cod_persona
           AND b.nro_cuenta = a.nro_cuenta
           AND b.nro_cuenta = cue.nro_cuenta
           AND a.nro_cuenta = cue.nro_cuenta
           AND b.relacion = 'P'
           AND (a.sal_tot_batch <> 0 OR a.sal_ret_batch <> 0 OR
               a.sal_blo_batch <> 0)
        UNION ALL
        select a.nro_cuenta
          FROM ge_clientes     c,
               ge_cta_clientes b,
               ah_cta_vistas   a,
               ge_cuentas      cue
         WHERE c.cod_persona = b.cod_persona
           AND b.nro_cuenta = a.nro_cuenta
           AND b.nro_cuenta = cue.nro_cuenta
           AND a.nro_cuenta = cue.nro_cuenta
           AND b.relacion = 'P'
           AND a.estado IN ('N', 'I')
           AND a.sal_tot_batch = 0
           AND a.sal_ret_batch = 0
           AND a.sal_blo_batch = 0
           AND (SELECT nvl(SUM(mto_dev_acumulado), 0)
                  FROM ah_devengados
                 WHERE nro_cuenta = a.nro_cuenta
                   AND fec_inicio >=
                       nvl(a.fec_ult_capitalizacion, a.fec_apertura)) > 0
        union all
        SELECT a.nro_cuenta
          FROM ge_plz_contables d,
               ge_clientes      c,
               ge_cta_clientes  b,
               ah_cta_plazos    a
         WHERE b.nro_cuenta = a.nro_cuenta
           AND b.relacion = 'P'
           AND c.cod_persona = b.cod_persona
           AND a.est_batch NOT IN ('C', 'T')
           AND (a.sal_tot_batch <> 0 OR a.sal_ret_batch <> 0 OR
               a.sal_blo_batch <> 0)
           AND can_dias =
               (SELECT MIN(can_dias)
                  FROM ge_plz_contables
                 WHERE can_dias >= a.fec_vencimiento - a.fec_apertura)
        union all
        select a.nro_cuenta
          FROM ge_plz_contables    d,
               ge_clientes         c,
               ge_cta_clientes     b,
               ah_cta_certificados a
         WHERE b.nro_cuenta = a.nro_cuenta
           AND b.relacion = 'P'
           AND c.cod_persona = b.cod_persona
           AND (a.est_batch NOT IN ('C', 'T') or
               (a.est_batch = 'T' and exists
                (select 1
                    from ah_cupones cup
                   where cup.nro_cuenta = a.nro_cuenta
                     and cup.estado = 'V')))
           AND can_dias =
               (SELECT MIN(can_dias)
                  FROM ge_plz_contables
                 WHERE can_dias >= a.fec_vencimiento - a.fec_apertura)
           AND a.cod_modalidad <> 36
        union all
        select a.nro_cuenta
          FROM ge_plz_contables d,
               ge_clientes c,
               ge_cta_clientes b,
               pr_cta_prestamos a,
               ge_cuentas cue,
               (select monto, nro_cuenta, mto_pre_total
                  from pr_previsiones p
                 where p.fecha =
                       (select max(s.fecha)
                          from pr_previsiones s
                         where s.nro_cuenta = p.nro_cuenta)) pr_previsiones
         WHERE b.nro_cuenta = a.nro_cuenta
           AND b.nro_cuenta = cue.nro_cuenta
           AND a.nro_cuenta = cue.nro_cuenta
           AND b.relacion = 'P'
           AND c.cod_persona = b.cod_persona
           AND a.est_batch NOT IN ('N', 'I')
           AND pr_previsiones.nro_cuenta(+) = a.nro_cuenta
           AND can_dias =
               (SELECT MIN(can_dias)
                  FROM ge_plz_contables
                 WHERE can_dias >= a.fec_vencimiento - a.fec_inicio)
        union all
        SELECT a.nro_cuenta
          FROM ge_clientes c, ge_cta_clientes b, cc_cta_corrientes a
         WHERE b.cod_persona = c.cod_persona
           AND b.nro_cuenta = a.nro_cuenta
           AND b.relacion = 'P'
           AND (a.sal_tot_batch <> 0 OR a.sal_ret_batch <> 0 OR
               a.sal_blo_batch <> 0)
        union all
        SELECT a.nro_cuenta
          FROM ge_clientes c, ge_cta_clientes b, cc_cta_corrientes a
         WHERE b.cod_persona = c.cod_persona
           AND b.nro_cuenta = a.nro_cuenta
           AND relacion = 'P'
           AND (nvl(sal_tot_batch, 0) <> 0 OR nvl(sal_ret_batch, 0) <> 0 OR
               nvl(sal_blo_batch, 0) <> 0)
           AND nvl(sal_tot_batch, 0) - nvl(sal_ret_batch, 0) -
               nvl(sal_blo_batch, 0) < 0
        union all
        SELECT a.nro_cuenta
          FROM ge_clientes c, ge_cta_clientes b, cc_cta_bancarias a
         WHERE c.cod_persona = b.cod_persona
           AND a.nro_cuenta = b.nro_cuenta
           AND relacion = 'P'
              --WA:08/08/2014 Se incluye modalidad 49 para Financieras Pais
           AND a.cod_modalidad IN (42, 45, 48, 442, 455, 49) --WA: 19/02/2014 Se incluye Cta SIPAP
           AND nvl(sal_tot_batch, 0) - nvl(sal_ret_batch, 0) < 0
        union all
        select a.nro_cuenta
          FROM ge_clientes c,
               ge_cta_clientes b,
               ta_cta_tarjetas a,
               (SELECT (nvl(monto, 0) /*- nvl(a.tot_prv_contingencia, 0)*/
                       ) monto,
                       a.tot_prv_contingencia,
                       nro_cuenta
                  FROM ta_previsiones a
                 WHERE a.fecha =
                       (SELECT MAX(b.fecha)
                          FROM ta_previsiones b
                         WHERE a.nro_cuenta = b.nro_cuenta)) ta_previsiones
         WHERE c.cod_persona = b.cod_persona
           AND b.nro_cuenta = a.nro_cuenta
           AND ta_previsiones.nro_cuenta(+) = a.nro_cuenta
           AND b.relacion = 'P'
           AND a.estado <> 'C'
           AND not exists (SELECT 1 -- No considerar las TC vinculadas a Op.Vencidas.
                  FROM ov_cta_vencidas v
                 WHERE v.nro_cta_origen = a.nro_cuenta
                   AND v.estado <> 'C')
        union all
        SELECT a.nro_cuenta
          FROM ge_clientes c,
               cx_cta_importaciones a,
               ge_cta_clientes b,
               (SELECT nro_cuenta cuenta,
                       SUM(saldo) sal_utilizado,
                       SUM(mto_utilizado) mto_utilizado
                  FROM cx_embarques
                 GROUP BY nro_cuenta
                ) x
         WHERE a.nro_cuenta = b.nro_cuenta
           AND b.relacion = 'P'
           AND x.cuenta(+) = a.nro_cuenta
           AND b.cod_persona = c.cod_persona
           AND a.estado NOT IN ('C', 'S') -- cancelada y solicitada
           AND fux_obt_sal_mto_utilizado(a.nro_cuenta) > 0 --solo si tiene saldo utilizado pendiente de cobro
           and (case
                 when nvl(a.mto_prepago, 0) > 0 and
                      nvl(x.mto_utilizado, 0) >= nvl(a.mto_prepago, 0) then
                  nvl(x.mto_utilizado, 0) - nvl(a.mto_prepago, 0)
                 when nvl(a.mto_prepago, 0) > 0 and
                      nvl(x.mto_utilizado, 0) < nvl(a.mto_prepago, 0) then
                  0
                 else
                  nvl(x.sal_utilizado, 0)
               end) > 0
        UNION ALL
        SELECT a.nro_cuenta
          FROM ge_clientes c,
               cx_cta_importaciones a,
               ge_cta_clientes b,
               (SELECT nro_cuenta cuenta,
                       SUM(saldo) sal_utilizado,
                       SUM(mto_utilizado) mto_utilizado
                  FROM cx_embarques
                 GROUP BY nro_cuenta
                ) x
         WHERE a.nro_cuenta = b.nro_cuenta
           AND b.relacion = 'P'
           AND x.cuenta(+) = a.nro_cuenta
           AND b.cod_persona = c.cod_persona
           AND a.estado NOT IN ('C', 'S') -- cancelada y solicitada
           AND (saldo - fux_obt_sal_mto_utilizado(a.nro_cuenta)) > 0 --solo si tiene saldo no utilizado
           and (case
                 when nvl(a.mto_prepago, 0) > 0 and
                      nvl(x.mto_utilizado, 0) <= nvl(a.mto_prepago, 0) then
                  nvl(a.monto, 0) - nvl(a.mto_prepago, 0)
                 else
                  (saldo - fux_obt_sal_mto_utilizado(a.nro_cuenta))
               end) > 0
        UNION ALL
        SELECT a.nro_cuenta
          FROM ge_clientes c, cx_cta_exportaciones a, ge_cta_clientes b
         WHERE a.nro_cuenta = b.nro_cuenta
           AND b.relacion = 'P'
           AND (saldo - fux_obt_sal_mto_utilizado(a.nro_cuenta)) > 0 --solo si tiene saldo no utilizado
           AND b.cod_persona = c.cod_persona
        UNION ALL
        SELECT a.nro_cuenta
          FROM ge_clientes c,
               cx_cta_exportaciones a,
               ge_cta_clientes b,
               (SELECT nro_cuenta cuenta,
                       fec_vencimiento,
                       SUM(saldo) sal_utilizado
                  FROM cx_embarques
                 GROUP BY nro_cuenta, fec_vencimiento) x
         WHERE a.nro_cuenta = b.nro_cuenta
           AND b.relacion = 'P'
           AND x.cuenta = a.nro_cuenta
           AND b.cod_persona = c.cod_persona
           AND (fux_obt_sal_mto_utilizado(a.nro_cuenta)) > 0 --solo si tiene saldo no utilizado
        UNION ALL
        SELECT a.nro_cuenta
          FROM ge_clientes c, cx_cta_cobranzas a, ge_cta_clientes b
         WHERE a.nro_cuenta = b.nro_cuenta
           AND b.relacion = 'P'
           AND a.cod_modalidad IN (83, 84)
           AND a.estado = 'A'
           AND b.cod_persona = c.cod_persona
           AND saldo > 0 --solo si tiene saldo
        UNION ALL
        --fianzas emitidas
        SELECT a.nro_cuenta
          FROM ge_clientes c, cx_fianzas a, ge_cta_clientes b
         WHERE a.nro_cuenta = b.nro_cuenta
           AND b.relacion = 'P'
           AND a.cod_modalidad = 88
           AND a.estado = 'A'
           AND b.cod_persona = c.cod_persona

        union all
        select a.nro_cuenta
          FROM ge_plz_contables    d,
               ge_clientes         c,
               ge_cta_clientes     b,
               md_cta_documentos   a,
               md_cuo_instrumentos o
         WHERE b.nro_cuenta = a.nro_cuenta
           AND a.nro_cuenta = o.nro_cuenta
           AND b.relacion = 'P'
           AND c.cod_persona = b.cod_persona
           AND o.estado NOT IN ('N', 'S')
           AND can_dias =
               (SELECT MIN(can_dias)
                  FROM ge_plz_contables
                 WHERE can_dias >= a.fec_vencimiento - a.fec_inicio)
        UNION ALL
        SELECT ch.nro_cuenta
          FROM cc_che_certificados ch,
               ge_cta_clientes     gc,
               ge_clientes         c,
               cc_cta_corrientes   cc,
               cc_cta_bancarias    cb
         WHERE ch.nro_cuenta = gc.nro_cuenta --cheque con cta-cliente
           AND gc.cod_persona = c.cod_persona --cta-cliente con cliente
           AND cc.nro_cuenta = ch.nro_cuenta --cta-corriente con che-certificado
           AND ch.nro_cta_certificado = cb.nro_cuenta
           AND ch.fec_pago IS NULL
           AND gc.relacion = 'P'
        union all
        SELECT a.nro_cuenta
          FROM ge_plz_contables    d,
               ge_clientes         c,
               ge_cta_clientes     b,
               ah_cta_certificados a
         WHERE b.nro_cuenta = a.nro_cuenta
           AND b.relacion = 'P'
           AND c.cod_persona = b.cod_persona
           AND a.est_batch NOT IN ('C', 'T')
           AND a.cod_modalidad = 36
           AND can_dias =
               (SELECT MIN(can_dias)
                  FROM ge_plz_contables
                 WHERE can_dias >= a.fec_vencimiento - a.fec_apertura)
        union all
        SELECT a.nro_cuenta
          FROM ge_clientes c, ge_cta_clientes b, cc_cta_bancarias a
         WHERE b.cod_persona = c.cod_persona
           AND b.nro_cuenta = a.nro_cuenta
           AND b.relacion = 'P'
           AND a.cod_modalidad = 46
           AND (a.sal_tot_batch <> 0 OR a.sal_ret_batch <> 0 OR
               a.sal_blo_batch <> 0)
        union all
        SELECT t.nro_cuenta
          FROM ov_cta_vencidas t,
               ge_clientes ge,
               ge_cta_clientes gcc,
               (SELECT a.monto, a.nro_cuenta
                  FROM ov_previsiones a
                 WHERE a.fecha =
                       (SELECT MAX(b.fecha)
                          FROM ov_previsiones b
                         WHERE a.nro_cuenta = b.nro_cuenta)) ov_previsiones,
               (SELECT nvl(ov.tot_val_saldo, 0) -
                       nvl(ov.tot_val_prevision, 0) mto_valuado,
                       ov.nro_cuenta
                  FROM ov_valuaciones ov) ov_valuaciones
         WHERE t.nro_cuenta = gcc.nro_cuenta
           AND ge.cod_persona = gcc.cod_persona
           AND gcc.relacion = 'P'
           AND t.est_batch NOT IN ('I', 'C')
           AND ov_previsiones.nro_cuenta(+) = t.nro_cuenta
           AND ov_valuaciones.nro_cuenta(+) = t.nro_cuenta
        union all
        SELECT a.nro_cuenta
          FROM ge_clientes        c,
               ge_cta_clientes    b,
               pr_cta_prestamos   a,
               ge_plz_contables   d,
               pr_previsiones_tmp pr_previsiones
         WHERE c.cod_persona = b.cod_persona
           AND b.nro_cuenta = a.nro_cuenta
           AND pr_previsiones.nro_cuenta(+) = a.nro_cuenta
           AND b.relacion = 'P'
           AND a.est_batch NOT IN ('N', 'I')
           AND can_dias =
               (SELECT MIN(can_dias)
                  FROM ge_plz_contables
                 WHERE can_dias >= a.fec_vencimiento - a.fec_inicio)
           AND (nvl(pr_previsiones.monto, 0)) <> 0
           AND (a.cod_modulo, a.cod_modalidad) not in
               (select p.cod_modulo, p.cod_modalidad
                  from ge_par_dinamicos p
                 where p.parametro = 'PRE_MAD_EXCEPCION'
                   and p.val_parametro = 'S')) a
union all
--PAB_RES.PR_GEN_INV_CTA_RES
select 'PAB_RES.PR_GEN_INV_CTA_RES' cod_programa, count(1) cantidad
  from (SELECT h.nro_cuenta
          FROM cb_sal_inv_res_his h,
               ge_cuentas         g,
               ge_clientes        c,
               ge_cta_clientes    cc,
               ge_modalidades     mo
         WHERE h.periodo = '2025'
           AND h.tipo in ('PR',
                          'VL',
                          'OC',
                          'CD',
                          'CO',
                          'DS',
                          'DE',
                          'OI',
                          'GA',
                          'OE',
                          'IM')
           AND h.nro_cuenta = g.nro_cuenta
           AND g.nro_cuenta = cc.nro_cuenta
           AND cc.relacion = 'P'
           AND c.cod_persona = cc.cod_persona
           AND g.cod_modulo = mo.cod_modulo
           AND g.cod_modalidad = mo.cod_modalidad) a
union all
--PRG_GEN_SAL_DIARIOS
select 'PRG_GEN_SAL_DIARIOS' descripcion, count(1) cantidad
  from (SELECT A.NRO_CUENTA
          FROM AH_DEVENGADOS b, AH_CTA_VISTAS a
         WHERE b.FECHA(+) = pag_cal.fu_obt_fec_anterior(1)
           AND a.NRO_CUENTA = b.NRO_CUENTA(+)
           AND (a.est_batch not in ('A', 'X', 'T', 'C') or
                (a.est_batch = 'C' and
                a.fec_cam_estado = pag_cal.fu_obt_fec_anterior(1)
                ))
         GROUP BY a.COD_MONEDA,
                  a.nro_cuenta,
                  a.est_batch,
                  a.sal_tot_batch,
                  a.sal_blo_batch,
                  a.sal_ret_batch
        UNION ALL
        SELECT A.NRO_CUENTA
          FROM AH_DEVENGADOS b, ah_cta_certificados a
         WHERE b.FECHA(+) = pag_cal.fu_obt_fec_anterior(1)
           AND a.NRO_CUENTA = b.NRO_CUENTA(+)
           AND (a.est_batch not in ('A', 'X', 'T', 'C') or
                (a.est_batch = 'C' and
                a.fec_cam_estado = pag_cal.fu_obt_fec_anterior(1)
                ))
         GROUP BY a.COD_MONEDA,
                  a.nro_cuenta,
                  a.est_batch,
                  a.sal_tot_batch,
                  a.sal_blo_batch,
                  a.sal_ret_batch
        UNION ALL
        SELECT B.NRO_CUENTA
          FROM cc_cta_corrientes b, cc_sobregiros_res r
         WHERE (b.est_batch not in ('A', 'X', 'T', 'C') or
               (b.est_batch = 'C' and
               b.fec_cam_estado = pag_cal.fu_obt_fec_anterior(1)
               ))
           AND b.nro_cuenta = r.nro_cuenta(+)
        UNION ALL
        SELECT T.NRO_CUENTA
          FROM ta_cta_tarjetas t
         WHERE t.estado <> 'C'
        UNION ALL
        SELECT E.NRO_CUENTA
          FROM cx_cta_exportaciones e
         WHERE e.est_batch not in ('C', 'R', 'G', 'P')
        UNION ALL
        SELECT I.NRO_CUENTA
          FROM cx_cta_importaciones i
         WHERE i.est_batch not in ('C', 'R', 'G', 'P')
        UNION ALL
        SELECT F.NRO_CUENTA
          FROM cx_fianzas f
         WHERE f.est_batch not in ('C', 'R', 'G', 'P')
        UNION ALL
        SELECT C.NRO_CUENTA
          FROM cx_cta_cobranzas c
         WHERE c.est_batch not in ('C', 'R', 'G', 'P')
        UNION ALL
        SELECT MD.NRO_CUENTA
          FROM it.md_cta_documentos md
         WHERE md.estado not in ('N', 'S')
        UNION ALL
        SELECT CB.NRO_CUENTA
          FROM cc_cta_bancarias cb
         WHERE cb.cod_modalidad = 45
        UNION ALL
        select W.NRO_CUENTA
          from ge_sal_diarios w
         where fecha =
               pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_ACTUAL(1), 1, 2)
           and (NVL(sal_tot_cap, 0) <> 0 or NVL(sal_blo_int, 0) <> 0 or
               NVL(sal_ret_ade, 0) <> 0 or NVL(dev_dia, 0) <> 0 or
               NVL(dia_atraso, 0) <> 0 or NVL(dev_no_cobrado, 0) <> 0 or
               NVL(dev_suspenso, 0) <> 0)
           and not exists (select 1
                  from ge_sal_diarios t
                 where fecha = pag_cal.fu_obt_fec_anterior(1)
                   and t.nro_cuenta = w.nro_cuenta)) a
 union all
--PRA_CON_TRANSACCION
SELECT 'PRA_CON_TRANSACCION' descripcion, count(1) cantidad
  FROM GE_MOVIMIENTOS_ANT g
 WHERE COD_TRANSACCION > 0
 AND ESTADO = 'N');
