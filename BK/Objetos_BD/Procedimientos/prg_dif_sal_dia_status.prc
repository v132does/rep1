CREATE OR REPLACE PROCEDURE  IT.PRG_DIF_SAL_DIA_STATUS IS

/* MJ 07-01-2025 Procedimiento que indica las diferencias de saldo disponible diarias,
                 tanto en monto como en cantidades.
   MJ 16-06-2026 Se unifican las consultas de insercion y se separa el resumen
                 (GE_DIF_CTA_DIARIAS) por producto/modalidad.
                 Se agregan tipos de saldos BLOQUEADO y RETENIDO 
*/
 

    P_FECHA DATE := pag_cal.FU_OBT_FEC_ACTUAL(6);

BEGIN

    EXECUTE IMMEDIATE 'DELETE IT.ge_cta_dif_sal_diario';

    INSERT INTO IT.ge_cta_dif_sal_diario (
        fecha,
        nro_cuenta,
        cod_modalidad,
        modalidad,
        cod_moneda,
        denominacion,
        tip_saldo,
        sal_online,
        sal_batch,
        dif_saldo,
        var_dif_saldo,
        nueva,
        estado,
        fec_estado,
        usu_insercion,
        fec_insercion
    )
    SELECT
        TRUNC(P_FECHA),
        A.NRO_CUENTA,
        A.COD_MODALIDAD,
        'AHORROS A LA VISTA',
        A.COD_MONEDA,
        A.DENOMINACION,
        T.TIP_SALDO,
        CASE T.TIP_SALDO
            WHEN 'DISPONIBLE' THEN A.SAL_TOTAL
            WHEN 'BLOQUEADO'  THEN A.SAL_BLOQUEADO
            WHEN 'RETENIDO'   THEN A.SAL_RETENIDO
        END AS SAL_ONLINE,
        CASE T.TIP_SALDO
            WHEN 'DISPONIBLE' THEN A.SAL_TOT_BATCH
            WHEN 'BLOQUEADO'  THEN A.SAL_BLO_BATCH
            WHEN 'RETENIDO'   THEN A.SAL_RET_BATCH
        END AS SAL_BATCH,
        CASE T.TIP_SALDO
            WHEN 'DISPONIBLE' THEN (A.SAL_TOTAL     - A.SAL_TOT_BATCH)
            WHEN 'BLOQUEADO'  THEN (A.SAL_BLOQUEADO - A.SAL_BLO_BATCH)
            WHEN 'RETENIDO'   THEN (A.SAL_RETENIDO  - A.SAL_RET_BATCH)
        END AS DIF_SALDO,
        ABS(CASE T.TIP_SALDO
            WHEN 'DISPONIBLE' THEN (A.SAL_TOTAL     - A.SAL_TOT_BATCH)
            WHEN 'BLOQUEADO'  THEN (A.SAL_BLOQUEADO - A.SAL_BLO_BATCH)
            WHEN 'RETENIDO'   THEN (A.SAL_RETENIDO  - A.SAL_RET_BATCH)
        END) AS VAR_DIF_SALDO,
        'S',
        'PENDIENTE',
        SYSDATE,
        'PRG_DIF_SAL',
        SYSDATE
    FROM AH_CTA_VISTAS A
    CROSS JOIN (
        SELECT 'DISPONIBLE' AS TIP_SALDO FROM DUAL UNION ALL
        SELECT 'BLOQUEADO'                FROM DUAL UNION ALL
        SELECT 'RETENIDO'                 FROM DUAL
    ) T
    WHERE A.COD_MODALIDAD IN ('31', '334')
      AND CASE T.TIP_SALDO
              WHEN 'DISPONIBLE' THEN (A.SAL_TOTAL     - A.SAL_TOT_BATCH)
              WHEN 'BLOQUEADO'  THEN (A.SAL_BLOQUEADO - A.SAL_BLO_BATCH)
              WHEN 'RETENIDO'   THEN (A.SAL_RETENIDO  - A.SAL_RET_BATCH)
          END <> 0

    UNION ALL

   SELECT
        TRUNC(P_FECHA),
        A.NRO_CUENTA,
        A.COD_MODALIDAD,
        'CUENTA CORRIENTE',
        A.COD_MONEDA,
        A.DENOMINACION,
        T.TIP_SALDO,
        CASE T.TIP_SALDO
            WHEN 'DISPONIBLE' THEN A.SAL_TOTAL
            WHEN 'BLOQUEADO'  THEN A.SAL_BLOQUEADO
            WHEN 'RETENIDO'   THEN A.SAL_RETENIDO
        END AS SAL_ONLINE,
        CASE T.TIP_SALDO
            WHEN 'DISPONIBLE' THEN A.SAL_TOT_BATCH
            WHEN 'BLOQUEADO'  THEN A.SAL_BLO_BATCH
            WHEN 'RETENIDO'   THEN A.SAL_RET_BATCH
        END AS SAL_BATCH,
        CASE T.TIP_SALDO
            WHEN 'DISPONIBLE' THEN (A.SAL_TOTAL     - A.SAL_TOT_BATCH)
            WHEN 'BLOQUEADO'  THEN (A.SAL_BLOQUEADO - A.SAL_BLO_BATCH)
            WHEN 'RETENIDO'   THEN (A.SAL_RETENIDO  - A.SAL_RET_BATCH)
        END AS DIF_SALDO,
        ABS(CASE T.TIP_SALDO
            WHEN 'DISPONIBLE' THEN (A.SAL_TOTAL     - A.SAL_TOT_BATCH)
            WHEN 'BLOQUEADO'  THEN (A.SAL_BLOQUEADO - A.SAL_BLO_BATCH)
            WHEN 'RETENIDO'   THEN (A.SAL_RETENIDO  - A.SAL_RET_BATCH)
        END) AS VAR_DIF_SALDO,
        'S',
        'PENDIENTE',
        SYSDATE,
        'PRG_DIF_SAL',
        SYSDATE
    FROM CC_CTA_CORRIENTES A
    CROSS JOIN (
        SELECT 'DISPONIBLE' AS TIP_SALDO FROM DUAL UNION ALL
        SELECT 'BLOQUEADO'                FROM DUAL UNION ALL
        SELECT 'RETENIDO'                 FROM DUAL
    ) T
    WHERE A.COD_MODALIDAD IN ('41')
      AND CASE T.TIP_SALDO
              WHEN 'DISPONIBLE' THEN (A.SAL_TOTAL     - A.SAL_TOT_BATCH)
              WHEN 'BLOQUEADO'  THEN (A.SAL_BLOQUEADO - A.SAL_BLO_BATCH)
              WHEN 'RETENIDO'   THEN (A.SAL_RETENIDO  - A.SAL_RET_BATCH)
          END <> 0;

    INSERT INTO IT.GE_DIF_CTA_DIARIAS (
        fecha,
        cod_moneda,
        dif_cuadran,
        dif_sin_cuadrar,
        dif_sentido_contrario,
        dif_sin_identificar,
        tot_cuentas_dif,
        cant_cuadran,
        cant_sin_cuadrar,
        cant_sentido_contrario,
        cant_sin_identificar,
        pct_cuadran,
        pct_sin_cuadrar,
        pct_sentido_contrario,
        pct_sin_identificar,
        pct_cant_cuadran,
        pct_cant_sin_cuadrar,
        pct_cant_sentido_contrario,
        pct_cant_sin_identificar,
        modalidad,
        tip_saldo
    )
    WITH segmentadas_sum AS (
        SELECT
            NRO_CUENTA,
            TIP_SALDO,
            SUM(MONTO) AS TOTAL_MONTO
        FROM it.ge_cta_dif_segmentadas
        GROUP BY NRO_CUENTA, TIP_SALDO
    ),
    base AS (
        SELECT
            A.NRO_CUENTA,
            A.COD_MONEDA,
            A.MODALIDAD,
            A.TIP_SALDO,
            A.DIF_SALDO,
            CASE
                WHEN B.NRO_CUENTA IS NULL                 THEN 'SIN IDENTIFICAR'
                WHEN NVL(B.TOTAL_MONTO, 0) =  A.DIF_SALDO THEN 'CUADRAN DIRECTAMENTE'
                WHEN NVL(B.TOTAL_MONTO, 0) = -A.DIF_SALDO THEN 'SENTIDO CONTRARIO'
                ELSE                                           'NO CUADRAN DIRECTAMENTE'
            END AS RESULTADO
        FROM IT.ge_cta_dif_sal_diario A
        LEFT JOIN segmentadas_sum B
               ON A.NRO_CUENTA = B.NRO_CUENTA
              AND A.TIP_SALDO  = B.TIP_SALDO 
        WHERE A.COD_MONEDA IN ('GS', 'USD')
    ),
    resumen_abierto AS (
        SELECT
            TRUNC(P_FECHA)  AS FECHA,
            COD_MONEDA,
            MODALIDAD,
            TIP_SALDO,

            /* MONTOS */
            SUM(CASE WHEN RESULTADO = 'CUADRAN DIRECTAMENTE'    THEN ABS(DIF_SALDO) ELSE 0 END) AS DIF_CUADRAN,
            SUM(CASE WHEN RESULTADO = 'NO CUADRAN DIRECTAMENTE' THEN ABS(DIF_SALDO) ELSE 0 END) AS DIF_SIN_CUADRAR,
            SUM(CASE WHEN RESULTADO = 'SENTIDO CONTRARIO'       THEN ABS(DIF_SALDO) ELSE 0 END) AS DIF_SENTIDO_CONTRARIO,
            SUM(CASE WHEN RESULTADO = 'SIN IDENTIFICAR'         THEN ABS(DIF_SALDO) ELSE 0 END) AS DIF_SIN_IDENTIFICAR,

            /* CANTIDADES */
            COUNT(CASE WHEN RESULTADO = 'CUADRAN DIRECTAMENTE'    THEN 1 END) AS CANT_CUADRAN,
            COUNT(CASE WHEN RESULTADO = 'NO CUADRAN DIRECTAMENTE' THEN 1 END) AS CANT_SIN_CUADRAR,
            COUNT(CASE WHEN RESULTADO = 'SENTIDO CONTRARIO'       THEN 1 END) AS CANT_SENTIDO_CONTRARIO,
            COUNT(CASE WHEN RESULTADO = 'SIN IDENTIFICAR'         THEN 1 END) AS CANT_SIN_IDENTIFICAR,
            COUNT(*) AS TOT_CUENTAS_DIF

        FROM base
        GROUP BY COD_MONEDA, MODALIDAD, TIP_SALDO
    ),
    totales_por_producto AS (
        SELECT
            COD_MONEDA,
            MODALIDAD,
            TIP_SALDO,
            SUM(CANT_CUADRAN)           AS TOT_CUADRAN,
            SUM(CANT_SIN_CUADRAR)       AS TOT_SIN_CUADRAR,
            SUM(CANT_SENTIDO_CONTRARIO) AS TOT_SENTIDO_CONTRARIO,
            SUM(CANT_SIN_IDENTIFICAR)   AS TOT_SIN_IDENTIFICAR,
            SUM(TOT_CUENTAS_DIF)        AS TOT_GENERAL
        FROM resumen_abierto
        GROUP BY COD_MONEDA, MODALIDAD, TIP_SALDO
    )
    SELECT
        r.FECHA,
        r.COD_MONEDA,

        r.DIF_CUADRAN,
        r.DIF_SIN_CUADRAR,
        r.DIF_SENTIDO_CONTRARIO,
        r.DIF_SIN_IDENTIFICAR,
        r.TOT_CUENTAS_DIF,

        r.CANT_CUADRAN,
        r.CANT_SIN_CUADRAR,
        r.CANT_SENTIDO_CONTRARIO,
        r.CANT_SIN_IDENTIFICAR,

        /*%POR MONTO*/
        ROUND(r.DIF_CUADRAN            / NULLIF(r.DIF_CUADRAN + r.DIF_SIN_CUADRAR + r.DIF_SENTIDO_CONTRARIO + r.DIF_SIN_IDENTIFICAR, 0) * 100, 2) AS PCT_CUADRAN,
        ROUND(r.DIF_SIN_CUADRAR        / NULLIF(r.DIF_CUADRAN + r.DIF_SIN_CUADRAR + r.DIF_SENTIDO_CONTRARIO + r.DIF_SIN_IDENTIFICAR, 0) * 100, 2) AS PCT_SIN_CUADRAR,
        ROUND(r.DIF_SENTIDO_CONTRARIO  / NULLIF(r.DIF_CUADRAN + r.DIF_SIN_CUADRAR + r.DIF_SENTIDO_CONTRARIO + r.DIF_SIN_IDENTIFICAR, 0) * 100, 2) AS PCT_SENTIDO_CONTRARIO,
        ROUND(r.DIF_SIN_IDENTIFICAR    / NULLIF(r.DIF_CUADRAN + r.DIF_SIN_CUADRAR + r.DIF_SENTIDO_CONTRARIO + r.DIF_SIN_IDENTIFICAR, 0) * 100, 2) AS PCT_SIN_IDENTIFICAR,

        /*%POR CANTIDAD*/
        ROUND(g.TOT_CUADRAN            / NULLIF(g.TOT_GENERAL, 0) * 100, 2) AS PCT_CANT_CUADRAN,
        ROUND(g.TOT_SIN_CUADRAR        / NULLIF(g.TOT_GENERAL, 0) * 100, 2) AS PCT_CANT_SIN_CUADRAR,
        ROUND(g.TOT_SENTIDO_CONTRARIO  / NULLIF(g.TOT_GENERAL, 0) * 100, 2) AS PCT_CANT_SENTIDO_CONTRARIO,
        ROUND(g.TOT_SIN_IDENTIFICAR    / NULLIF(g.TOT_GENERAL, 0) * 100, 2) AS PCT_CANT_SIN_IDENTIFICAR,
        r.MODALIDAD,
        r.TIP_SALDO

    FROM resumen_abierto r
    INNER JOIN totales_por_producto g
            ON r.COD_MONEDA = g.COD_MONEDA
           AND r.MODALIDAD  = g.MODALIDAD
           AND r.TIP_SALDO  = g.TIP_SALDO;


    COMMIT;

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        IT.PRG_INS_LOG_PROGRAMAS (
            p_cod_programa => 'PRG_DIF_SAL_DIA_STATUS',
            p_det_error    => SQLERRM,
            p_cod_persona  => 'MJ',
            p_nro_cuenta   => NULL
        );
        RAISE;
		
END prg_dif_sal_dia_status;
