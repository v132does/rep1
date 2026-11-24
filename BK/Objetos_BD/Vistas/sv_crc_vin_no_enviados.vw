CREATE OR REPLACE FORCE VIEW IT.SV_CRC_VIN_NO_ENVIADOS AS
SELECT a.cod_persona,
       a.relacion,
       a.cod_modulo,
       fecha,
       d.cod_oficina,
       g.cod_moneda,
       d.tip_operacion,
       NULL AS evento,
       d.nro_operacion
  FROM ge_cta_clientes a, sb_crc_operaciones_det d, ge_cuentas g
 WHERE a.nro_cuenta = d.nro_operacion
   AND a.nro_cuenta = g.nro_cuenta
   AND relacion = 'P'
   AND NOT EXISTS (SELECT 1
          FROM sb_crc_vinculos_det t
         WHERE t.nro_operacion = d.nro_operacion
           AND a.cod_persona = t.cod_persona)
UNION
-- Vinculos.
SELECT a.cod_persona,
       a.relacion,
       a.cod_modulo,
       fecha,
       d.cod_oficina,
       g.cod_moneda,
       d.tip_operacion,
       NULL,
       d.nro_operacion
  FROM ge_cta_clientes a, ge_cta_clientes b, ba_personas c, sb_crc_operaciones_det d, ge_cuentas g --A = vinculos, B = Principal
 WHERE a.nro_cuenta = d.nro_operacion
   AND a.nro_cuenta = b.nro_cuenta
   AND b.cod_persona = c.cod_persona
   AND g.nro_cuenta = d.nro_operacion
   AND b.relacion = 'P'
   AND a.relacion NOT IN ('P', 'A')
   AND NOT EXISTS (SELECT 1
          FROM ba_vinculos v, ge_cta_clientes g
         WHERE v.cod_per_vinculo = a.cod_persona
           AND g.cod_persona = v.cod_persona
           AND g.nro_cuenta = d.nro_operacion
           AND g.relacion = 'P'
           AND tipo = 'E')
   AND ((a.relacion NOT IN ('Y', 'O') AND c.tipo = 'J') OR c.tipo = 'F')
   AND NOT EXISTS (SELECT 1
          FROM sb_crc_vinculos_det t
         WHERE t.nro_operacion = d.nro_operacion
           AND a.cod_persona = t.cod_persona)
UNION
-- Conyuges
SELECT v.cod_per_vinculo,
       v.tipo relacion,
       c.cod_modulo,
       d.fecha,
       d.cod_oficina,
       g.cod_moneda,
       d.tip_operacion,
       NULL,
       d.nro_operacion
  FROM ba_vinculos v, ge_cta_clientes c, sb_crc_operaciones_det d, ge_cuentas g
 WHERE v.cod_persona = c.cod_persona
   AND c.nro_cuenta = d.nro_operacion
   AND g.nro_cuenta = c.nro_cuenta
   AND v.cod_per_vinculo <> c.cod_persona
   AND v.tipo = 'E'
   AND c.relacion = 'P'
   AND fug_obt_pardinamico('CRC_DAT_CONYUGES') = 'S'
   AND EXISTS (SELECT 1
          FROM ge_cta_clientes s
         WHERE s.nro_cuenta = c.nro_cuenta
           AND s.relacion <> 'P'
           AND s.cod_persona = v.cod_per_vinculo)
   AND NOT EXISTS (SELECT 1
          FROM sb_crc_vinculos_det t
         WHERE t.nro_operacion = d.nro_operacion
           AND c.cod_persona = t.cod_persona)
UNION
--Emisores Descuento de cheques
SELECT DISTINCT z.cod_persona,
                'L' relacion,
                p.cod_modulo,
                d.fecha,
                d.cod_oficina,
                p.cod_moneda,
                d.tip_operacion,
                NULL,
                d.nro_operacion
  FROM ge_che_custodias       t,
       pr_rel_chq_lib         x,
       pr_chq_libradores      y,
       ba_personas            z,
       pr_cta_prestamos       p,
       sb_crc_operaciones_det d
 WHERE x.cod_banco = t.cod_banco
   AND x.nro_cheque = t.nro_cheque
   AND x.cta_libradora = t.cta_libradora
   AND t.estado = 'C'
   AND y.nro_documento = x.nro_documento
   AND y.cod_tip_documento = x.cod_tip_documento
   AND z.nro_documento = x.nro_documento
   AND z.cod_tip_documento = x.cod_tip_documento
   AND t.nro_referencia = d.nro_operacion
   AND z.cod_persona NOT IN
       (SELECT cod_persona FROM ge_cta_clientes s WHERE s.nro_cuenta = d.nro_operacion)
   AND p.nro_cuenta = t.nro_referencia
   AND nvl(fup_obt_tip_descuento(p.cod_modalidad), 'X') IN ('D', 'C')
   AND p.estado <> 'N'
   AND fug_obt_pardinamico('SIB_CRC_INC_CLA_EMISORES') = 'S'
   AND NOT EXISTS (SELECT 1
          FROM sb_crc_vinculos_det t
         WHERE t.nro_operacion = d.nro_operacion
           AND z.cod_persona = t.cod_persona)
UNION
-- Emisores Descuento de documentos
SELECT DISTINCT p.cod_persona,
                'L' relacion,
                pr.cod_modulo,
                t.fecha,
                t.cod_oficina,
                pr.cod_moneda,
                t.tip_operacion,
                NULL,
                t.nro_operacion
  FROM pr_documentos d, ba_personas p, pr_cta_prestamos pr, sb_crc_operaciones_det t
 WHERE d.estado = 'C'
   AND p.cod_tip_documento = d.cod_tip_documento
   AND p.nro_documento = d.nro_documento
   AND d.nro_referencia = t.nro_operacion
   AND p.cod_persona NOT IN
       (SELECT cod_persona FROM ge_cta_clientes s WHERE s.nro_cuenta = t.nro_operacion)
   AND pr.nro_cuenta = d.nro_referencia
   AND pr.estado <> 'N'
   AND nvl(fup_obt_tip_descuento(pr.cod_modalidad), 'X') IN ('D', 'C')
   AND fug_obt_pardinamico('SIB_CRC_INC_CLA_EMISORES') = 'S'
   AND NOT EXISTS (SELECT 1
          FROM sb_crc_vinculos_det e
         WHERE e.nro_operacion = t.nro_operacion
           AND p.cod_persona = e.cod_persona)
;

