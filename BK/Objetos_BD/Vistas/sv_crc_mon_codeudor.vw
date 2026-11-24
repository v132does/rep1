CREATE OR REPLACE FORCE VIEW IT.SV_CRC_MON_CODEUDOR AS
SELECT ROUND(sum((nvl(p.sal_capital, 0) + nvl(p.dev_no_cobrado, 0)) * nvl(FUG_OBT_COTIZACION(o.cod_moneda,o.fecha),1))) sal_capital --FIELDESK-13629
           ,d.cod_persona, o.fecha
        FROM sb_crc_operaciones_det o, sb_crc_vinculos_det d , pr_cta_prestamos p
       WHERE o.fecha = d.fecha
         AND p.nro_cuenta =pae_uti.fu_obt_valor(fus_obt_cta_operacion(o.nro_operacion,d.cod_modulo), 1)
         AND d.tip_vinculo IN (002, 004, 005, 007, 010) --FIELDESK-13629
         and o.tip_operacion not in ('405','351')
         /*ajuste operaciones en fecha de cierre que ya esta en saldos*/
         AND NOT EXISTS (SELECT '1' FROM sb_crc_saldos_det e
                         WHERE e.nro_operacion= o.nro_operacion
                         AND e.fecha = o.fecha)
         AND o.nro_operacion = d.nro_operacion
       GROUP BY d.cod_persona, o.fecha
   UNION
   -- Codeudores Descuento de cheques
   SELECT distinct (select ROUND(sum((nvl(p.sal_capital, 0) + nvl(p.dev_no_cobrado, 0)) * nvl(FUG_OBT_COTIZACION(o.cod_moneda,o.fecha),1))) from pr_cta_prestamos p
                       where  p.nro_cuenta =pae_uti.fu_obt_valor(fus_obt_cta_operacion(o.nro_operacion,d.cod_modulo), 1)) sal_capital  --FIELDESK-13629
         , d.cod_persona, o.fecha
        FROM sb_crc_operaciones_det o, sb_crc_vinculos_det d
       WHERE o.fecha = d.fecha
         AND o.tip_operacion in ('405','351')
         AND d.tip_vinculo IN (002, 004, 005, 007, 010) --FIELDESK-13629
         /*ajuste operaciones en fecha de cierre que ya esta en saldos*/
         AND NOT EXISTS (SELECT '1' FROM sb_crc_saldos_det e
                         WHERE e.nro_operacion= o.nro_operacion
                         AND e.fecha = o.fecha)
         AND o.nro_operacion = d.nro_operacion
UNION
-- Emisores Descuento de cheques
SELECT round(sum((nvl(cu.sal_capital, 0) + nvl(cu.dev_no_cobrado, 0)) * nvl(FUG_OBT_COTIZACION(o.cod_moneda,o.fecha),1)))sal_capital,
         e.cod_persona, o.fecha
         FROM ge_che_custodias       a,
              pr_rel_chq_lib         b,
              pr_chq_libradores      c,
              ba_personas            e,
              pr_cta_prestamos       f,
              sb_crc_operaciones_det o,
              pr_cuotas              cu
        WHERE a.nro_referencia = pae_uti.fu_obt_valor(o.nro_operacion, 1) --#03 Debe enviarse el parametro en 1 para que recupere el nro de operacion correcto - Eduardo Nu?ez 22-04-2021
          AND a.nro_cheque = b.nro_cheque
          AND a.cod_banco = b.cod_banco
          AND a.cta_libradora = b.cta_libradora
          AND c.nro_documento = b.nro_documento
          AND a.nro_cuota = pae_uti.fu_obt_valor(o.nro_operacion, 2)
          AND c.cod_tip_documento = b.cod_tip_documento
          AND e.nro_documento = c.nro_documento
          AND e.cod_tip_documento = c.cod_tip_documento
          AND b.nro_documento = e.nro_documento
          AND o.cod_modulo = 6
          AND b.cod_tip_documento = e.cod_tip_documento
          AND f.nro_cuenta = a.nro_referencia
          AND a.estado IN ('A', 'B', 'C')
          AND NOT EXISTS(SELECT 1
                 FROM ge_cta_clientes ct
                WHERE ct.nro_cuenta = f.nro_cuenta
                  AND e.cod_persona = ct.cod_persona
                  AND relacion = 'P')
          AND nvl(fup_obt_tip_descuento(f.cod_modalidad), 'X') IN ('D', 'C')
          AND cu.nro_cuenta = a.nro_referencia
          AND cu.nro_cuota = a.nro_cuota
          AND NOT EXISTS (SELECT '1' FROM sb_crc_saldos_det e
                               WHERE e.nro_operacion= o.nro_operacion
                               AND e.fecha = o.fecha)
        group by e.cod_persona,o.fecha
  UNION
  -- Emisores Descuento de documentos
         SELECT round(sum((nvl(cu.sal_capital, 0) + nvl(cu.dev_no_cobrado, 0)) * nvl(FUG_OBT_COTIZACION(o.cod_moneda,o.fecha),1)))sal_capital,
              p.cod_persona, o.fecha
           FROM pr_documentos d, ba_personas p, pr_cta_prestamos pr, pr_cuotas cu, sb_crc_operaciones_det o
          WHERE d.estado = 'C'
            AND p.cod_tip_documento = d.cod_tip_documento
            AND p.nro_documento = d.nro_documento
            and o.cod_modulo = '6'
            AND d.nro_cuota = pae_uti.fu_obt_valor(o.nro_operacion, 2)
            AND d.nro_referencia = pae_uti.fu_obt_valor(o.nro_operacion, 1)--Se ajusta para que busque nro de cuenta estaba trayendo nro de cuota
            AND d.nro_referencia = pr.nro_cuenta
            AND pr.est_batch <> 'N' -- No canceladas
            AND nvl(fup_obt_tip_descuento(pr.cod_modalidad), 'X') IN ('D', 'C')
            AND NOT EXISTS (SELECT 1
                             FROM ge_cta_clientes ct
                            WHERE ct.nro_cuenta = pr.nro_cuenta
                              AND p.cod_persona = ct.cod_persona
                              AND relacion = 'P')
            AND pr.nro_cuenta = d.nro_referencia
            AND nvl(fup_obt_tip_descuento(pr.cod_modalidad), 'X') IN ('D', 'C')
            AND d.nro_referencia = cu.nro_cuenta
            AND d.nro_cuota = cu.nro_cuota
            AND NOT EXISTS (SELECT '1' FROM sb_crc_saldos_det e
                         WHERE e.nro_operacion= o.nro_operacion
                         AND e.fecha = o.fecha)
            GROUP BY p.cod_persona,o.fecha
;

