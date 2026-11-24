CREATE OR REPLACE FORCE VIEW IT.SV_CRC_OPE_GARANTIAS AS
SELECT o.linea, o.registro, o.fecha
FROM (
  SELECT RPAD(s.nom_referencia, 10) ||
         RPAD(TO_CHAR(s.fec_periodo, 'yyyymmdd'), 8, ' ') ||
         LPAD(s.cod_entidad, 4, '0') ||
         LPAD(c.can_reg, 9, '0') AS linea,
         0 AS registro,
         s.fec_periodo AS fecha
    FROM sb_crc_ope_garantias s,
         (SELECT a.fecha AS fec, COUNT(*) AS can_reg
            FROM sb_crc_ope_garantias_det a
           WHERE a.nom_referencia = 'OPEGARAN'
           GROUP BY a.fecha) c
   WHERE s.fec_periodo = c.fec
     AND s.nom_referencia = 'OPEGARAN'
) o
UNION ALL
SELECT o2.linea, o2.registro, o2.fecha
FROM (
  SELECT
    LPAD(e.NRO_FORMULARIO, 3, '0') ||
    DECODE (pas_cri.fu_obt_cod_entidad,
            2079, RPAD(LPAD(e.COD_OFI_OPERACION_EQV, 2, '0'), 4, ' '),
            1007, LPAD(e.COD_OFI_OPERACION_EQV, 4, '0'),
            2036, RPAD(LPAD(e.COD_OFI_OPERACION_EQV, 2, '0'), 4, ' '),
            2080, LPAD(e.COD_OFI_OPERACION_EQV, 4, '0'),
            2037, LPAD(e.COD_OFI_OPERACION_EQV, 4, '0'),
                  RPAD(e.COD_OFI_OPERACION_EQV, 4, ' ')
    ) ||
    LPAD(NVL(e.TIP_OPERACION, 0), 3, '0') ||
    RPAD(NVL(e.NRO_OPERACION_EQV, ' '), 60, ' ') ||
    RPAD(NVL(e.COD_MON_ISO_OPERACION, ' '), 3, ' ') ||
    DECODE (pas_cri.fu_obt_cod_entidad,
            2079, RPAD(LPAD(e.COD_OFI_GARANTIA, 2, '0'), 4, ' '),
            1007, LPAD(e.COD_OFI_GARANTIA, 4, '0'),
            2036, RPAD(LPAD(e.COD_OFI_GARANTIA, 2, '0'), 4, ' '),
            2080, LPAD(e.COD_OFI_GARANTIA, 4, '0'),
            2037, LPAD(e.COD_OFI_GARANTIA, 4, '0'),
                  RPAD(e.COD_OFI_GARANTIA, 4, ' ')
    ) ||
    RPAD(NVL(e.COD_MON_ISO_GARANTIA, ' '), 3, ' ') ||
    RPAD(NVL(TO_CHAR(e.NRO_GARANTIA), ' '), 60, ' ') ||
    RPAD(NVL(REPLACE(fub_obt_rub_formateado(e.RUB_CON_GARANTIA), '.', NULL), ' '), 18) ||
    LPAD(TO_CHAR(NVL((e.MTO_EQU_UTILIZADO * 100), 0)), 20, '0') ||
    LPAD(e.NRO_REGISTRO, 9, '0') AS linea,
    e.NRO_REGISTRO AS registro,
    e.FECHA AS fecha
  FROM IT.SV_CRC_OPE_GARANTIAS_DET_EQV e
  WHERE e.NOM_REFERENCIA = 'OPEGARAN'
  ORDER BY e.NRO_REGISTRO
) o2
ORDER BY fecha, registro;
