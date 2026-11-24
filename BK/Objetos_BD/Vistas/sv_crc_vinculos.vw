CREATE OR REPLACE FORCE VIEW IT.SV_CRC_VINCULOS AS
SELECT o.linea, o.registro, o.fecha
  FROM (
        SELECT RPAD(s.nom_referencia, 10) ||
               RPAD(TO_CHAR(s.fec_periodo, 'yyyymmdd'), 8, ' ') ||
               LPAD(s.cod_entidad, 4, '0') ||
               LPAD(c.can_reg, 9, '0') AS linea,
               0 AS registro,
               s.fec_periodo AS fecha
          FROM sb_crc_vinculos s,
               (SELECT a.fecha AS fec, COUNT(*) AS can_reg
                  FROM sb_crc_vinculos_det a
                 WHERE a.nom_referencia = 'VINCULOS'
                   AND ((a.cod_modulo <> 15) OR (a.cod_modulo = 15 AND a.tip_vinculo = 9))
                   AND NOT (
                         pas_cri.fu_es_unipersonal(a.nro_documento) = 'S'
                     AND (a.tip_documento = 'RUC'
                       OR INSTR(a.NRO_DOCUMENTO, '-', 1, 1) > 0)
                   )
                 GROUP BY a.fecha) c
         WHERE s.fec_periodo = c.fec
           AND s.nom_referencia = 'VINCULOS'
       ) o
UNION ALL
SELECT SUBSTR(linea, 1, LENGTH(linea) - 9) || LPAD(registro, 9, '0') AS linea,
       registro,
       fecha
FROM (
  SELECT o2.linea,
         ROW_NUMBER() OVER (PARTITION BY o2.fecha ORDER BY o2.registro) AS registro,
         o2.fecha
    FROM (
          SELECT
            LPAD(e.nro_formulario, 3, '0') ||
            DECODE (
              pas_cri.fu_obt_cod_entidad,
              2079, RPAD(LPAD(e.cod_oficina_eqv, 2, '0'), 4, ' '),
              1007, LPAD(e.cod_oficina_eqv, 4, '0'),
              2036, RPAD(LPAD(e.cod_oficina_eqv, 2, '0'), 4, ' '),
              2080, LPAD(e.cod_oficina_eqv, 4, '0'),
              2037, LPAD(
                      NVL(
                        fue_tab_dat_adicional(
                          'GE_CUENTAS',
                          'SIB_OFI_CRC_INACTIVAS',
                          e.nro_operacion_eqv
                        ),
                        e.cod_oficina_eqv
                      ),
                      4,
                      '0'
                    ),
              RPAD(e.cod_oficina_eqv, 4, ' ')
            ) ||
            LPAD(NVL(e.tip_operacion, 0), 3, '0') ||
            RPAD(
              DECODE(
                pas_cri.fu_obt_cod_entidad,
                2037,
                  NVL(
                    fue_tab_dat_adicional(
                      'AH_CTA_CERTIFICADOS',
                      'SIB_CTA_CRC_INFORMADA',
                      e.nro_operacion_eqv
                    ),
                    e.nro_operacion_eqv
                  ),
                e.nro_operacion_eqv
              ),
              60,
              ' '
            ) ||
            RPAD(e.cod_mon_iso, 3, ' ') ||
            RPAD(NVL(e.tip_documento, ' '), 3, ' ') ||
            DECODE(
              e.tip_documento,
              'RUC',
                DECODE(
                  pas_cri.fu_obt_cod_entidad,
                  2079,
                    RPAD(
                      NVL(e.nro_documento, ' ') || '-' ||
                      fue_obt_ruc_dig_verificador(e.nro_documento),
                      30,
                      ' '
                    ),
                  6004,
                    RPAD(
                      NVL(e.nro_documento, ' ') || '-' ||
                      fue_obt_ruc_dig_verificador(e.nro_documento),
                      30,
                      ' '
                    ),
                  RPAD(NVL(e.nro_documento, ' '), 30, ' ')
                ),
              RPAD(NVL(e.nro_documento, ' '), 30, ' ')
            ) ||
            RPAD(NVL(TO_CHAR(e.fec_nacimiento, 'yyyymmdd'), ' '), 8, ' ') ||
            RPAD(NVL(e.nombres,   ' '), 255, ' ') ||
            RPAD(NVL(e.apellidos, ' '), 100, ' ') ||
            LPAD(e.tip_vinculo, 3, '0') ||
            NVL(e.per_vinculada, 'N') ||
            LPAD(e.nro_registro, 9, '0') AS linea,
            e.nro_registro AS registro,
            e.fecha        AS fecha
          FROM IT.SV_CRC_VINCULOS_DET_EQV e
          ORDER BY e.nro_registro
         ) o2
)
ORDER BY fecha, registro;
