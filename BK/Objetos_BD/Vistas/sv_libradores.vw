CREATE OR REPLACE FORCE VIEW IT.SV_LIBRADORES AS
SELECT distinct z.cod_persona cod_persona, pr.nro_cuenta nro_cuenta ,
nvl(pag_gen.fu_con_mon_a_moneda(pr.cod_moneda, pag_gen.fu_obt_mon_local,nvl(t.monto, 0), NULL), 0) sal_capital,
t.nro_cheque, y.nro_documento documento, t.nro_cuota
 FROM ge_che_custodias   t,
      pr_rel_chq_lib     x,
      pr_chq_libradores  y,
      ba_personas        z,
      pr_cta_prestamos   pr
WHERE x.cod_banco = t.cod_banco
  AND x.nro_cheque = t.nro_cheque
  AND x.cta_libradora = t.cta_libradora
  AND t.estado in ('C', 'A', 'B', 'D') -- a = en compensacion / b = devuelto / c = custodio -
  AND y.nro_documento = x.nro_documento
  AND y.cod_tip_documento = x.cod_tip_documento
  AND z.nro_documento = x.nro_documento
  AND z.cod_tip_documento = x.cod_tip_documento
  AND t.nro_referencia = pr.nro_cuenta
  AND pr.est_batch <> 'N'
  --no informar descuento de cheques propios.
  AND NOT EXISTS (SELECT 1
                    FROM ge_cta_clientes s
                   WHERE s.nro_cuenta = pr.nro_cuenta
                     AND s.cod_persona = z.cod_persona
                     AND s.relacion = 'P')
UNION ALL
--cheques devueltos
SELECT DISTINCT z.cod_persona,
                pr.nro_cuenta,
                nvl(pag_gen.fu_con_mon_a_moneda(pr.cod_moneda, pag_gen.fu_obt_mon_local,
                                                nvl(t.monto, 0), NULL), 0) sal_capital,
                t.nro_cheque,
                y.nro_documento documento, t.nro_cuota
  FROM ge_che_custodias t,
       pr_rel_chq_lib x,
       pr_chq_libradores y,
       ba_personas z,
       (SELECT c.nro_cuenta,
               substr(c.descripcion, instr(c.descripcion, 'CTA:') + 4, length(c.descripcion)) nro_cta_origen,
               substr(c.descripcion, instr(c.descripcion, 'CHE:') + 4, instr(c.descripcion, 'CTA:')-6) nro_che_origen,
               c.est_batch,
               c.cod_moneda
          FROM pr_cta_prestamos c
         WHERE c.cod_modalidad = 660
           AND c.est_batch <> 'N') pr
 WHERE x.cod_banco = t.cod_banco
   AND x.nro_cheque = t.nro_cheque
   AND x.cta_libradora = t.cta_libradora
   AND t.estado IN ('B') --b = devuelto
   AND y.nro_documento = x.nro_documento
   AND y.cod_tip_documento = x.cod_tip_documento
   AND z.nro_documento = x.nro_documento
   AND z.cod_tip_documento = x.cod_tip_documento
   AND t.nro_referencia = pr.nro_cta_origen
   AND t.nro_cheque = pr.nro_che_origen
   AND pr.est_batch <> 'N'
      --no informar descuento de cheques propios.
   AND NOT EXISTS (SELECT 1
          FROM ge_cta_clientes s
         WHERE s.nro_cuenta = pr.nro_cuenta
           AND s.cod_persona = z.cod_persona
           AND s.relacion = 'P')
UNION ALL
SELECT distinct p.cod_persona, pr.nro_cuenta,
nvl((pag_gen.fu_con_mon_a_moneda(pr.cod_moneda, pag_gen.fu_obt_mon_local,
                                 nvl(d.monto, 0), NULL)), 0) sal_capital,null, d.nro_documento, d.nro_cuota
 FROM pr_documentos d, ba_personas p, pr_cta_prestamos pr
WHERE d.estado = 'C'
  AND p.cod_tip_documento = d.cod_tip_documento
  AND p.nro_documento  = d.nro_documento
  AND d.nro_referencia = pr.nro_cuenta
  AND pr.est_batch <> 'N'
;

