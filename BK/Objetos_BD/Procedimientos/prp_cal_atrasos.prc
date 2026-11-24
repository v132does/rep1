CREATE OR REPLACE PROCEDURE IT.PRP_CAL_ATRASOS(p_nro_cuenta IN VARCHAR2 DEFAULT NULL) IS
  v_fec_actual ge_calendarios.fec_actual%TYPE;
BEGIN
  BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO := 1; END;

  pag_cal.PR_OBT_DAT_CALENDAR(6);
  v_fec_actual := pag_cal.FU_OBT_FEC_ACTUAL(6);
  IF v_fec_actual = pag_cal.g_ult_dia_mes_habil AND FUG_OBT_PRO_CIE_ENCURSO = 11 THEN
     v_fec_actual := pag_cal.g_ult_dia_mes;
  END IF;

  MERGE INTO pr_cta_prestamos p
  USING (
    WITH
    prcuotas AS (
      SELECT
        x.nro_cuenta,
        ROUND( MAX( NVL(x.fec_ult_pago, v_fec_actual) - x.fec_vencimiento ) ) AS max_atraso,
        ROUND( AVG(
          CASE
            WHEN ROUND( NVL(x.fec_ult_pago, v_fec_actual) - x.fec_vencimiento ) < 0 THEN 0
            ELSE ROUND( NVL(x.fec_ult_pago, v_fec_actual) - x.fec_vencimiento )
          END
        ) ) AS pro_atraso,
        ROUND( v_fec_actual - NVL( MIN( CASE WHEN x.estado = 'N' THEN NULL ELSE x.fec_vencimiento END ), v_fec_actual ) ) AS dia_atraso,
        SUM(
          CASE WHEN x.estado = 'N' THEN 0
               ELSE NVL(x.sal_capital,0) + NVL(x.sal_interes,0) + NVL(x.sal_int_documentado,0)
          END
        ) AS mto_mora
      FROM pr_cuotas x
      WHERE x.nro_cuota > 0
        AND x.fec_vencimiento < v_fec_actual
        AND x.nro_cuenta = NVL(p_nro_cuenta, x.nro_cuenta)
      GROUP BY x.nro_cuenta
    ),
    prcuo_pag AS (
      SELECT x.nro_cuenta, COUNT(*) AS can_cuo_pagadas
      FROM pr_cuotas x
      WHERE x.nro_cuota > 0
        AND x.estado = 'N'
        AND x.nro_cuenta = NVL(p_nro_cuenta, x.nro_cuenta)
      GROUP BY x.nro_cuenta
    ),
    resumen AS (
      SELECT
        d.nro_cuenta,
        GREATEST(d.max_atraso, 0) AS max_atraso,
        GREATEST(d.pro_atraso,  0) AS pro_atraso,
        GREATEST(d.dia_atraso,  0) AS dia_atraso,
        NVL(d.mto_mora, 0)         AS mto_mora,
        NVL(p.can_cuo_pagadas, 0)      AS can_cuo_pagadas
      FROM prcuotas d
      LEFT JOIN prcuo_pag p ON p.nro_cuenta = d.nro_cuenta
    )
    SELECT a.*
    FROM resumen a
  ) s
  ON (p.nro_cuenta = s.nro_cuenta)
  WHEN MATCHED THEN UPDATE SET
    p.dia_atraso       = s.dia_atraso,
    p.pro_atraso       = s.pro_atraso,
    p.max_atraso       = s.max_atraso,
    p.can_cuo_pagadas  = s.can_cuo_pagadas,
    p.mto_mora         = s.mto_mora
  WHERE (p.estado NOT IN ('N','I') OR p.fec_cancelacion = pag_cal.G_FEC_ACTUAL)
    AND (
      NVL(p.dia_atraso,0)      <> s.dia_atraso
      OR NVL(p.mto_mora,0)     <> s.mto_mora
    );
EXCEPTION
  WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20055, 'PRP_CAL_ATRASOS-(MERGE): '||SQLERRM);
END;
/
