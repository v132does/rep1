CREATE MATERIALIZED VIEW IT.AV_CTA_INVENTARIOS
REFRESH FORCE ON DEMAND
AS
SELECT
          a.cod_modulo,
          a.cod_modalidad,
          a.cod_sub_modalidad,
          a.cod_oficina,
          nvl(a.cta_combinada, 'N') as situacion,
          c.cod_sec_contable,
          c.cod_tip_deudor,
          c.residente,
          a.cod_moneda,
          1 as cod_plazo,
          nvl(a.sal_tot_batch, 0) - nvl(a.sal_ret_batch, 0) - nvl(emb.monto,0) as sal_tot_batch,/* Modificado CNF-2013-Resoluci?n SB SG 00076 2013- Cuentas con embargo */
          nvl(a.sal_ret_batch, 0), /*Modificado por Ana Azorero Abr-10*/
          a.nro_cuenta,
          nvl(a.fec_ult_capitalizacion, a.fec_apertura) fec_ult_capitalizacion,
          c.cod_persona
           FROM ge_clientes c, ge_cta_clientes b, ah_cta_vistas a, ge_cuentas cue,
                (select e.nro_cuenta, SUM(NVL(e.monto,0)) monto
                    from ge_bloqueos e
                   where e.cod_causa = 245
                   group by e.nro_cuenta) emb
          WHERE c.cod_persona = b.cod_persona
            AND b.nro_cuenta = a.nro_cuenta
            AND b.nro_cuenta = cue.nro_cuenta
            AND a.nro_cuenta = cue.nro_cuenta
            AND b.relacion = 'P'
            AND (a.sal_tot_batch <> 0 OR a.sal_ret_batch <> 0 OR a.sal_blo_batch <> 0) /*Modificado por Ana Azorero Abr-10*/
            AND a.nro_cuenta = emb.nro_cuenta(+)
         UNION ALL
         SELECT
          a.cod_modulo,
          a.cod_modalidad,
          a.cod_sub_modalidad,
          a.cod_oficina,
          nvl(a.cta_combinada, 'N') as situacion,
          c.cod_sec_contable,
          c.cod_tip_deudor,
          c.residente,
          a.cod_moneda,
          1 as cod_plazo,
          nvl(a.sal_tot_batch, 0) - nvl(a.sal_ret_batch, 0) as sal_tot_batch,
          nvl(a.sal_ret_batch, 0),
          a.nro_cuenta,
          nvl(a.fec_ult_capitalizacion, a.fec_apertura) fec_ult_capitalizacion,
          c.cod_persona
           FROM ge_clientes c, ge_cta_clientes b, ah_cta_vistas a , ge_cuentas cue
          WHERE LENGTH(a.nro_cuenta) > 0
            AND LENGTH(a.ESTADO) > 0
            AND c.cod_persona = b.cod_persona
            AND b.nro_cuenta = a.nro_cuenta
            AND b.nro_cuenta = cue.nro_cuenta
            AND a.nro_cuenta = cue.nro_cuenta
            AND b.relacion = 'P'
            --AND (a.sal_tot_batch <> 0 OR a.sal_ret_batch <> 0 OR a.sal_blo_batch <> 0) /*Modificado por Ana Azorero Abr-10*/
            /*DYDMR-4509 - ITGF - Incidencias Ahorros- Intereses del 19.07.2016
            Debe seguir exponiendo el Saldo Inter?s Devengado aunque el Saldo quede "0"*/
            AND a.estado IN ('N', 'I')
            AND a.sal_tot_batch = 0
            AND a.sal_ret_batch = 0
            AND a.sal_blo_batch = 0
            AND (SELECT nvl(SUM(mto_dev_acumulado), 0)
                   FROM ah_devengados
                  WHERE LENGTH(nro_cuenta) > 0
                    and nro_cuenta = a.nro_cuenta
                    AND fec_inicio >= nvl(a.fec_ult_capitalizacion, a.fec_apertura)) > 0;
