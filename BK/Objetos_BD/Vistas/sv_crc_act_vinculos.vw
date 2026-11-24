CREATE OR REPLACE FORCE VIEW IT.SV_CRC_ACT_VINCULOS AS
SELECT o.linea, o.registro, o.fecha
FROM (
  SELECT
    RPAD(s.nom_referencia, 10) ||
    RPAD(TO_CHAR(s.fec_periodo, 'yyyymmdd'), 8, ' ') ||
    LPAD(s.cod_entidad, 4, '0') ||
    LPAD(c.can_reg, 9, '0') AS linea,
    0 AS registro,
    s.fec_periodo AS fecha
  FROM sb_crc_act_vinculos s,
       (SELECT a.fecha AS fec, COUNT(*) AS can_reg
          FROM sb_crc_act_vinculos_det a
         WHERE a.nom_referencia = 'VINCULOSD'
         GROUP BY a.fecha) c
  WHERE s.fec_periodo = c.fec
    AND s.nom_referencia = 'VINCULOSD'
) o
UNION ALL
SELECT o2.linea, o2.registro, o2.fecha
FROM (
  SELECT
    LPAD(e.nro_formulario, 3, '0') ||
    DECODE (pas_cri.fu_obt_cod_entidad,
            1007, LPAD(e.cod_oficina_eqv, 4, '0'),
            2080, LPAD(e.cod_oficina_eqv, 4, '0'),
            2036, RPAD(LPAD(e.cod_oficina_eqv, 2, '0'), 4, ' '),
            2037, LPAD(NVL(fue_tab_dat_adicional('GE_CUENTAS','SIB_OFI_CRC_INACTIVAS', e.nro_operacion_eqv), e.cod_oficina_eqv), 4, '0'),
                  RPAD(e.cod_oficina_eqv, 4, ' ')
    ) ||
    LPAD(NVL(e.tip_operacion, 0), 3, '0') ||
    RPAD(DECODE(pas_cri.fu_obt_cod_entidad,
                2037, NVL(fue_tab_dat_adicional('AH_CTA_CERTIFICADOS','SIB_CTA_CRC_INFORMADA', e.nro_operacion_eqv),
                          e.nro_operacion_eqv),
                e.nro_operacion_eqv), 60, ' ') ||
    RPAD(e.cod_mon_iso, 3, ' ') ||
    RPAD(NVL(e.tip_documento, ' '), 3, ' ') ||
    RPAD(NVL(e.nro_documento, ' '), 30, ' ') ||
    RPAD(NVL(e.evento, ' '), 1, ' ') ||
    LPAD(e.nro_registro, 9, '0') AS linea,
    e.nro_registro AS registro,
    e.fecha        AS fecha
  FROM IT.SV_CRC_ACT_VINCULOS_DET_EQV e
  ORDER BY e.nro_registro
) o2
ORDER BY fecha, registro;
