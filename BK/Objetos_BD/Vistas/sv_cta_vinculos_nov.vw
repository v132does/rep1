CREATE OR REPLACE FORCE VIEW IT.SV_CTA_VINCULOS_NOV AS
SELECT DISTINCT trunc(c.fecha) fecha,
                b.nro_operacion nro_cuenta,
                b.cod_oficina,
                s.cod_moneda,
                c.cod_persona,
                b.tip_operacion,
                b.cod_modulo,
                c.evento,
                c.relacion,
                s.estado,
                s.cod_modalidad,
                c.Nro_Cheque
  FROM sb_crc_vinculos_det b
       -- NOR-764 CDA-D: b.nro_operacion es ISIN, la novedad trae la cuenta interna
       LEFT JOIN (SELECT x.cod_isin, x.nro_cuenta
                    FROM (SELECT h.cod_isin, h.nro_cuenta,
                                 ROW_NUMBER() OVER (PARTITION BY h.cod_isin
                                                    ORDER BY CASE WHEN h.estado IN ('A', 'X') THEN 1 ELSE 0 END,
                                                             h.fec_apertura DESC, h.nro_cuenta DESC) rn
                            FROM ah_cta_certificados h
                           WHERE h.cod_modalidad = 34
                             AND h.cod_isin IS NOT NULL) x
                   WHERE x.rn = 1) hc ON hc.cod_isin = b.nro_operacion,
       sb_cta_vinculos_nov c, ge_cuentas s
 WHERE NVL(hc.nro_cuenta, pae_uti.fu_obt_valor(b.nro_operacion,1)) = c.nro_cuenta--pae_uti.fu_obt_valor( fus_obt_cta_operacion(b.nro_operacion,b.cod_modulo) , 1) = c.nro_cuenta
   AND s.nro_cuenta =  c.nro_cuenta--pae_uti.fu_obt_valor(b.nro_operacion, 1)
   and s.cod_modulo <> 5
   and c.relacion <> 'L'
   AND c.fecha = (SELECT DISTINCT (MAX(fecha))
                    FROM sb_cta_vinculos_nov e
                   WHERE e.nro_cuenta = c.nro_cuenta--pae_uti.fu_obt_valor(fus_obt_cta_operacion(b.nro_operacion,b.cod_modulo), 1) = e.nro_cuenta
                     and e.cod_modulo <> 5
                     AND e.cod_persona = c.cod_persona)
 union              
SELECT DISTINCT trunc(c.fecha) fecha,
                b.nro_operacion nro_cuenta,
                b.cod_oficina,
                s.cod_moneda,
                c.cod_persona,
                b.tip_operacion,
                b.cod_modulo,
                c.evento,
                c.relacion,
                s.estado,
                s.cod_modalidad,
                c.Nro_Cheque
  FROM sb_crc_vinculos_det b, ge_cuentas s,sb_cta_vinculos_nov c,ta_tarjetas t
 WHERE t.nro_cuenta = b.nro_operacion
   and b.nro_operacion  = c.nro_cuenta--pae_uti.fu_obt_valor( fus_obt_cta_operacion(b.nro_operacion,b.cod_modulo) , 1) = c.nro_cuenta
   AND s.nro_cuenta =  c.nro_cuenta--pae_uti.fu_obt_valor(b.nro_operacion, 1)
   and s.cod_modulo = 5
   and c.relacion <> 'L'
   AND c.fecha = (SELECT DISTINCT (MAX(fecha))
                    FROM sb_cta_vinculos_nov e
                   WHERE e.nro_cuenta = b.nro_operacion--pae_uti.fu_obt_valor(fus_obt_cta_operacion(b.nro_operacion,b.cod_modulo), 1) = e.nro_cuenta
                     AND e.cod_persona = c.cod_persona)
union
SELECT DISTINCT trunc(c.fecha) fecha,
                b.nro_operacion nro_cuenta,
                b.cod_oficina,
                s.cod_moneda,
                c.cod_persona,
                b.tip_operacion,
                b.cod_modulo,
                c.evento,
                c.relacion,
                s.estado,
                s.cod_modalidad,
                c.Nro_Cheque
  FROM sb_crc_vinculos_det b, ge_cuentas s,sb_cta_vinculos_nov c,ta_tarjetas t
 WHERE t.nro_tarjeta = b.nro_operacion
   and b.nro_operacion  = c.nro_cuenta--pae_uti.fu_obt_valor( fus_obt_cta_operacion(b.nro_operacion,b.cod_modulo) , 1) = c.nro_cuenta
   AND s.nro_cuenta =  c.nro_cuenta--pae_uti.fu_obt_valor(b.nro_operacion, 1)
   and s.cod_modulo = 5
   and c.relacion <> 'L'
   AND c.fecha = (SELECT DISTINCT (MAX(fecha))
                    FROM sb_cta_vinculos_nov e
                   WHERE e.nro_cuenta = b.nro_operacion--pae_uti.fu_obt_valor(fus_obt_cta_operacion(b.nro_operacion,b.cod_modulo), 1) = e.nro_cuenta
                     AND e.cod_persona = c.cod_persona)
UNION
--LIBRADORES
SELECT trunc(c.fecha) fecha,
       b.nro_operacion,
       b.cod_oficina,
       s.cod_moneda,
       b.cod_persona, --codeudor  tambien,
       b.tip_operacion,
       b.cod_modulo,
       c.evento,
       c.relacion,
       s.estado,
       s.cod_modalidad,
       c.nro_cheque
  FROM sb_crc_vinculos_det b, sb_cta_vinculos_nov c, ge_cuentas s, sv_libradores li
 WHERE pae_uti.fu_obt_valor(b.nro_operacion, 1) = c.nro_cuenta
   AND s.nro_cuenta = pae_uti.fu_obt_valor(b.nro_operacion, 1)
   AND c.relacion = 'L'
   AND b.tip_vinculo IN (2, 6) --codeudor y librador
   AND to_char(c.nro_cheque) = li.nro_cheque
   and li.nro_cuota = pae_uti.fu_obt_valor(b.nro_operacion, 2)
   and (li.documento = pae_uti.fu_obt_valor(b.nro_operacion, 3) or
        li.nro_cheque= pae_uti.fu_obt_valor(b.nro_operacion, 3))
   AND c.nro_cheque IS NOT NULL
UNION
--Esposos
SELECT DISTINCT trunc(c.fecha),
                b.nro_operacion,
                b.cod_oficina,
                g.cod_moneda,
                c.cod_persona,
                b.tip_operacion,
                b.cod_modulo,
                c.evento,
                c.relacion,
                g.estado,
                g.cod_modalidad,
                c.nro_cheque
  FROM sb_crc_vinculos_det b, sb_cta_vinculos_nov c, ge_cuentas g
 WHERE c.cod_persona = b.cod_persona
   AND pae_uti.fu_obt_valor(b.nro_operacion, 1) = g.nro_cuenta
   AND trunc(c.fecha) =
       (SELECT MAX(trunc(fecha)) FROM sb_cta_vinculos_nov e WHERE e.cod_persona = b.cod_persona)
   AND EXISTS (SELECT 1 FROM sb_crc_operaciones_det t WHERE t.nro_operacion = b.nro_operacion)
   AND c.evento = 'D'
   AND c.relacion = 'E'
   AND b.tip_vinculo = 7
   AND fug_obt_pardinamico('CRC_DAT_CONYUGES') = 'S'
UNION
-- VINCULACIONES <> de modulo 5
SELECT DISTINCT trunc(c.fecha),
                b.nro_operacion,
                b.cod_oficina,
                g.cod_moneda,
                v.cod_per_vinculo,
                b.tip_operacion,
                b.cod_modulo,
                c.evento,
                c.relacion,
                g.estado,
                g.cod_modalidad,
                c.nro_cheque
  FROM sb_crc_vinculos_det b, sb_cta_vinculos_nov c, ge_cuentas g, ba_vinculos v, ge_est_cuentas e
 WHERE c.cod_persona = c.cod_persona
   AND trunc(c.fecha) =
       (SELECT MAX(trunc(fecha)) FROM sb_cta_vinculos_nov e WHERE e.cod_persona = b.cod_persona)
   AND EXISTS (SELECT 1 FROM sb_crc_operaciones_det t WHERE t.nro_operacion = b.nro_operacion)
   AND g.nro_cuenta = pae_uti.fu_obt_valor(b.nro_operacion,1)--pae_uti.fu_obt_valor(fus_obt_cta_operacion(b.nro_operacion,b.cod_modulo), 1)
   AND c.evento = 'V'
   and g.cod_modulo <>5
   AND c.relacion = 'E'
   AND b.tip_vinculo = 1
   AND b.cod_persona = c.cod_persona
   AND v.cod_persona = b.cod_persona
   AND e.cod_modulo = g.cod_modulo
   AND e.cod_modalidad = g.cod_modalidad
   AND e.estado = g.estado
   AND e.activo = 'S' -- vincular solo a operaciones vigentes.
   AND v.tipo = 'E'
   AND fug_obt_pardinamico('CRC_DAT_CONYUGES') = 'S'
union
   -- VINCULACIONES modulo 5 modalidad <> 53
SELECT DISTINCT trunc(c.fecha),
                b.nro_operacion,
                b.cod_oficina,
                g.cod_moneda,
                v.cod_per_vinculo,
                b.tip_operacion,
                b.cod_modulo,
                c.evento,
                c.relacion,
                g.estado,
                g.cod_modalidad,
                c.nro_cheque
  FROM sb_crc_vinculos_det b, sb_cta_vinculos_nov c, ge_cuentas g, ba_vinculos v, ge_est_cuentas e,ta_tarjetas t
 WHERE c.cod_persona = c.cod_persona
   AND trunc(c.fecha) =
       (SELECT MAX(trunc(fecha)) FROM sb_cta_vinculos_nov e WHERE e.cod_persona = b.cod_persona)
   AND EXISTS (SELECT 1 FROM sb_crc_operaciones_det t WHERE t.nro_operacion = b.nro_operacion)
   and b.nro_operacion = t.nro_tarjeta
   AND g.nro_cuenta = t.nro_cuenta--pae_uti.fu_obt_valor(fus_obt_cta_operacion(b.nro_operacion,b.cod_modulo), 1)
   AND c.evento = 'V'
   and g.cod_modulo =5
   AND c.relacion = 'E'
   AND b.tip_vinculo = 1
   AND b.cod_persona = c.cod_persona
   AND v.cod_persona = b.cod_persona
   AND e.cod_modulo = g.cod_modulo
   AND e.cod_modalidad = g.cod_modalidad
   AND e.estado = g.estado
   AND e.activo = 'S' -- vincular solo a operaciones vigentes.
   AND v.tipo = 'E'
   AND fug_obt_pardinamico('CRC_DAT_CONYUGES') = 'S'
union
 -- VINCULACIONES modulo 5 modalidad 53
SELECT DISTINCT trunc(c.fecha),
                b.nro_operacion,
                b.cod_oficina,
                g.cod_moneda,
                v.cod_per_vinculo,
                b.tip_operacion,
                b.cod_modulo,
                c.evento,
                c.relacion,
                g.estado,
                g.cod_modalidad,
                c.nro_cheque
  FROM sb_crc_vinculos_det b, sb_cta_vinculos_nov c, ge_cuentas g, ba_vinculos v, ge_est_cuentas e
 WHERE c.cod_persona = c.cod_persona
   AND trunc(c.fecha) =
       (SELECT MAX(trunc(fecha)) FROM sb_cta_vinculos_nov e WHERE e.cod_persona = b.cod_persona)
   AND EXISTS (SELECT 1 FROM sb_crc_operaciones_det t WHERE t.nro_operacion = b.nro_operacion)
   AND g.nro_cuenta = b.nro_operacion--pae_uti.fu_obt_valor(fus_obt_cta_operacion(b.nro_operacion,b.cod_modulo), 1)
   AND c.evento = 'V'
   and g.cod_modulo =5
   AND c.relacion = 'E'
   AND b.tip_vinculo = 1
   AND b.cod_persona = c.cod_persona
   AND v.cod_persona = b.cod_persona
   AND e.cod_modulo = g.cod_modulo
   AND e.cod_modalidad = g.cod_modalidad
   AND e.estado = g.estado
   AND e.activo = 'S' -- vincular solo a operaciones vigentes.
   AND v.tipo = 'E'
   AND fug_obt_pardinamico('CRC_DAT_CONYUGES') = 'S'
;

