CREATE OR REPLACE FORCE VIEW IT.PV_INV_PR_CTA_PRESTAMOS AS
SELECT b.cod_moneda,
       (CASE
          WHEN b.estado = 'C' AND a.estado = 'C' THEN
           '1-Vigente'
          WHEN b.estado = 'V' AND a.estado = 'V' THEN
           '2-Vencida'
          WHEN b.estado = 'G' AND a.estado = 'G' THEN
           '3-En gestión'
          WHEN b.estado = 'M' AND a.estado = 'M' THEN
           '4-Moroso'
          WHEN b.estado = 'I' AND a.estado = 'I' THEN
           '5-Incobrable'
          ELSE
           '99-incongruencia estado prestamo'
       END) estado,
       b.cod_oficina,
       COUNT(DISTINCT(b.nro_cuenta)) cant_cuentas,
       SUM(round(nvl(a.sal_capital, 0) + nvl(a.sal_interes, 0) + nvl(a.sal_int_documentado,0),
                                    decode(b.cod_moneda, 'GS',
                                    fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',null,null,b.cod_moneda,null),
                                    fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',null,null,b.cod_moneda,null)))) saldo_documento,
       SUM(decode(b.cod_moneda, 'GS',
                  0,
                  round(round(nvl(a.sal_capital, 0) + nvl(a.sal_interes, 0) +
                               nvl(a.sal_int_documentado, 0)) *
                         it.fug_obt_cotizacion('USD', g.fec_actual)))) saldo_documento_gs,
       SUM(nvl(a.sal_capital, 0)) saldo_capital,
       SUM(decode(b.cod_moneda, 'GS', 0,
                  round(round(nvl(a.sal_capital, 0)) * it.fug_obt_cotizacion('USD', g.fec_actual)))) saldo_capital_gs,
       SUM(nvl(a.sal_interes, 0) + nvl(a.sal_int_documentado, 0)) saldo_interes,
       SUM(decode(b.cod_moneda, 'GS', 0,
                  round(round(nvl(a.sal_interes, 0) + nvl(a.sal_int_documentado, 0)) *
                         it.fug_obt_cotizacion('USD', g.fec_actual)))) saldo_interes_gs,
       SUM(nvl(a.dev_no_cobrado, 0)) devengado_no_cobrado,
       SUM(decode(b.cod_moneda, 'GS', 0,
                  round(round(nvl(a.dev_no_cobrado, 0)) * it.fug_obt_cotizacion('USD', g.fec_actual)))) devengado_no_cobrado_gs,
       SUM(nvl(a.dev_suspenso, 0)) devengado_en_suspenso,
       SUM(decode(b.cod_moneda, 'GS', 0,
                  round(round(nvl(a.dev_suspenso, 0)) * it.fug_obt_cotizacion('USD', g.fec_actual)))) devengado_en_suspenso_gs,
       SUM(decode(b.cod_moneda, 'GS',
                  0,
                         round(nvl(a.sal_interes, 0) + nvl(a.sal_int_documentado, 0) -
                                nvl(a.dev_no_cobrado, 0) - nvl(a.dev_suspenso, 0)) *
                          it.fug_obt_cotizacion('USD', g.fec_actual))) saldo_interes_adevengar_gs,
       SUM(nvl(a.sal_capital, 0) + nvl(a.dev_no_cobrado, 0)) capitalmasintdevengado,
       SUM(decode(b.cod_moneda, 'GS', 0,
                  round(round(nvl(a.sal_capital, 0) + nvl(a.dev_no_cobrado, 0)) *
                         it.fug_obt_cotizacion('USD', g.fec_actual)))) capitalmasintdevengado_gs
  FROM it.pr_cuotas        a,
       it.pr_cta_prestamos b,
       it.ba_oficinas      c,
       it.ge_calendarios   g,
       it.ge_clientes      ge_cli,
       it.ge_cta_clientes  cta_cli
 WHERE cta_cli.cod_persona = ge_cli.cod_persona
   AND cta_cli.relacion = 'P'
   AND cta_cli.nro_cuenta = b.nro_cuenta
   AND a.estado NOT IN ('N', 'I')
   AND b.estado NOT IN ('N', 'I')
   AND b.cod_oficina = c.cod_oficina
   AND a.nro_cuenta = b.nro_cuenta
   AND a.nro_cuota > 0
   AND b.cod_modulo = g.cod_modulo
   --AND B.COD_MODALIDAD NOT IN (63,68,69)
 GROUP BY b.cod_moneda,
          (CASE
             WHEN b.estado = 'C' AND a.estado = 'C' THEN
              '1-Vigente'
             WHEN b.estado = 'V' AND a.estado = 'V' THEN
              '2-Vencida'
             WHEN b.estado = 'G' AND a.estado = 'G' THEN
              '3-En gestión'
             WHEN b.estado = 'M' AND a.estado = 'M' THEN
              '4-Moroso'
             WHEN b.estado = 'I' AND a.estado = 'I' THEN
              '5-Incobrable'
             ELSE
              '99-incongruencia estado prestamo'
          END),
          b.cod_oficina
;

