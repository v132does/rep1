CREATE OR REPLACE VIEW IT.SV_CRC_OPERACIONES AS
SELECT linea || ';' || registro AS linea, registro, fecha
FROM (
  SELECT
    o2.linea,
    ROW_NUMBER() OVER (PARTITION BY o2.fecha ORDER BY o2.registro ASC) AS registro,
    o2.fecha
  FROM (
    SELECT
      TO_NUMBER(e.NRO_FORMULARIO) || ';' ||
      TO_CHAR(e.FECHA, 'yyyymmdd') || ';' ||
      e.COD_OFICINA_EQV || ';' ||
      e.TIP_OPERACION || ';' ||
      e.NRO_OPERACION_EQV || ';' ||
      e.COD_MONEDA || ';' ||
      TO_CHAR(e.FEC_OPERACION, 'yyyymmdd') || ';' ||
      TO_CHAR(e.FEC_PRI_VENCIMIENTO, 'yyyymmdd') || ';' ||
      NVL(e.NRO_CUOTA, 0) || ';' ||
      TRIM(LEADING '0' FROM NVL(REPLACE(fub_obt_rub_formateado(e.CTA_CON_CAP_ORIGINAL),'.',NULL),' ')) || ';' ||
      TO_CHAR(NVL(e.MTO_ORI_CAPITAL, 0), 'FM999999999990.00') || ';' ||
      TO_CHAR(NVL(e.MTO_LIN_CREDITO, 0), 'FM999999999990.00') || ';' ||
      TRIM(LEADING '0' FROM NVL(REPLACE(fub_obt_rub_formateado(e.CTA_CON_INT_ORIGINAL),'.',NULL),' ')) || ';' ||
      TO_CHAR(NVL(e.MTO_ORI_INTERES, 0), 'FM999999999990.00') || ';' ||
      e.COD_RUB_PRIMARIO || ';' ||
      it.fu_obt_ref_bcp_barrio(e.COD_PERSONA) || ';' ||
      NVL(e.COD_RUB_ECONOMICO, DECODE(e.COD_MODULO, 5, 970107, 970108)) || ';' ||
      NVL(e.DIA_PLAZO, 0) || ';' ||
      NVL(REPLACE(e.TAS_NOMINAL, ',', '.'), 0) || ';' ||
      it.fu_obt_ref_cod_cal_saras(NVL(e.COD_RUB_ECONOMICO, DECODE(e.COD_MODULO, 5, 970107, 970108)))
      AS linea,
      e.NRO_REGISTRO AS registro,
      e.FECHA        AS fecha
    FROM IT.SV_CRC_OPERACIONES_DET_EQV e
    WHERE e.COD_MODULO <> 15
    ORDER BY e.NRO_REGISTRO
  ) o2
)
ORDER BY fecha, registro;
