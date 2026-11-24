create or replace PACKAGE BODY          IT.PAG_TSC AS

  ----------------------------------------------------------------------------
  -- Procedimiento interno de log general (un registro por PASO/ID_EJECUCION)
  ----------------------------------------------------------------------------
  PROCEDURE log_proceso (
    i_id_ejecucion        IN NUMBER,
    i_paso                IN VARCHAR2,
    i_descripcion         IN VARCHAR2,
    i_estado              IN VARCHAR2 DEFAULT NULL,
    i_total_detalle       IN NUMBER   DEFAULT NULL,
    i_procesados_detalle  IN NUMBER   DEFAULT NULL,
    i_tipo_mensaje        IN VARCHAR2 DEFAULT 'INFO',
    i_cod_error           IN VARCHAR2 DEFAULT NULL,
    i_detalle_error       IN VARCHAR2 DEFAULT NULL
  ) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
  BEGIN
    -- Primero intenta ACTUALIZAR el registro del paso
    UPDATE IT.GE_LOG_TSC
       SET FECHA_LOG          = SYSDATE,
           DESCRIPCION        = SUBSTR(i_descripcion, 1, 500),
           ESTADO             = i_estado,
           TOTAL_DETALLE      = NVL(i_total_detalle, TOTAL_DETALLE),
           PROCESADOS_DETALLE = NVL(i_procesados_detalle, PROCESADOS_DETALLE),
           TIPO_MENSAJE       = NVL(i_tipo_mensaje, TIPO_MENSAJE),
           COD_ERROR          = i_cod_error,
           DETALLE_ERROR      = SUBSTR(i_detalle_error, 1, 2000)
     WHERE ID_EJECUCION = i_id_ejecucion
       AND PASO         = SUBSTR(i_paso, 1, 50);

    -- Si no encontró registro, inserta uno nuevo
    IF SQL%ROWCOUNT = 0 THEN
      INSERT INTO IT.GE_LOG_TSC (
        ID_LOG,
        ID_EJECUCION,
        FECHA_LOG,
        PASO,
        DESCRIPCION,
        ESTADO,
        TOTAL_DETALLE,
        PROCESADOS_DETALLE,
        TIPO_MENSAJE,
        COD_ERROR,
        DETALLE_ERROR
      ) VALUES (
        IT.S_GE_LOG_TSC.NEXTVAL,
        i_id_ejecucion,
        SYSDATE,
        SUBSTR(i_paso, 1, 50),
        SUBSTR(i_descripcion, 1, 500),
        i_estado,
        i_total_detalle,
        i_procesados_detalle,
        i_tipo_mensaje,
        i_cod_error,
        SUBSTR(i_detalle_error, 1, 2000)
      );
    END IF;

    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      -- el log nunca debe frenar el proceso
      NULL;
  END log_proceso;


  ----------------------------------------------------------------------------
  -- Procedimiento interno de log de errores por cuenta
  ----------------------------------------------------------------------------
  PROCEDURE log_error_det (
    i_id_ejecucion  IN NUMBER,
    i_paso          IN VARCHAR2,
    i_nro_cuenta    IN VARCHAR2,
    i_cod_rubro     IN VARCHAR2,
    i_cod_modulo    IN NUMBER,
    i_cod_modalidad IN NUMBER,
    i_mensaje       IN VARCHAR2,
    i_cod_error     IN VARCHAR2,
    i_detalle_error IN VARCHAR2
  ) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
  BEGIN
    INSERT INTO IT.GE_LOG_TSC_DET (
      ID_LOG_DET,
      ID_EJECUCION,
      FECHA_LOG,
      PASO,
      NRO_CUENTA,
      COD_RUBRO,
      COD_MODULO,
      COD_MODALIDAD,
      MENSAJE,
      COD_ERROR,
      DETALLE_ERROR
    ) VALUES (
      IT.S_GE_LOG_TSC_DET.NEXTVAL,
      i_id_ejecucion,
      SYSDATE,
      SUBSTR(i_paso, 1, 50),
      i_nro_cuenta,
      i_cod_rubro,
      i_cod_modulo,
      i_cod_modalidad,
      SUBSTR(i_mensaje, 1, 500),
      i_cod_error,
      SUBSTR(i_detalle_error, 1, 2000)
    );
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      NULL;
  END log_error_det;


  ----------------------------------------------------------------------------
  -- Función: indica si un CODCTA está permitido según GE_REL_CTA_ACOD_TAS_INT
  ----------------------------------------------------------------------------
  FUNCTION FN_ES_CODCTA_PERMITIDO (
    i_codcta IN VARCHAR2
  ) RETURN NUMBER IS
    v_dummy NUMBER;
  BEGIN
    SELECT 1
      INTO v_dummy
      FROM IT.GE_REL_CTA_ACOD_TAS_INT r
     WHERE SUBSTR(r.COD_CTA, 1, 3) = i_codcta
       AND ROWNUM = 1;

    RETURN 1;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RETURN 0;
    WHEN OTHERS THEN
      -- ante error inesperado, por defecto no permitir
      RETURN 0;
  END FN_ES_CODCTA_PERMITIDO;


  ----------------------------------------------------------------------------
  -- Proceso: genera el reporte agrupado en IT.GE_REP_TAS_SAL
  -- Lógica:
  --   * Toma SOLO los ACOD presentes en GE_REP_TAS_SAL_DET
  --   * Para cada ACOD arma las dos filas de MONCOD (6200 / 6900)
  --   * Si no hay detalle para la combinación ACOD+MONCOD, deja SALDO = 0
  ----------------------------------------------------------------------------
  PROCEDURE PR_GEN_REPORTE (
    i_fecha_corte   IN DATE,
    i_id_ejecucion  IN NUMBER
  ) IS
    v_corcod  NUMBER(6);
    v_entcod  NUMBER(4);
  BEGIN
    --------------------------------------------------------------------------
    -- Obtener CORCOD y ENTCOD desde el detalle (una sola vez)
    --------------------------------------------------------------------------
    SELECT MAX(d.CORCOD),
           MAX(d.ENTCOD)
      INTO v_corcod,
           v_entcod
      FROM IT.GE_REP_TAS_SAL_DET d
     WHERE d.ID_EJECUCION = i_id_ejecucion
       AND TRUNC(d.FECHA) = TRUNC(i_fecha_corte);

    --------------------------------------------------------------------------
    -- Limpieza previa del reporte para la ejecución indicada
    --------------------------------------------------------------------------
    DELETE FROM IT.GE_REP_TAS_SAL s
     WHERE s.ID_EJECUCION = i_id_ejecucion;

    --------------------------------------------------------------------------
    -- Inserta matriz "par" ACOD x MONCOD (6200/6900) SOLO para ACOD del detalle
    -- Si falta una combinación ACOD+MONCOD en el detalle ¿ SALDO = 0
    --------------------------------------------------------------------------
    INSERT INTO IT.GE_REP_TAS_SAL (
      ID_EJECUCION,
      CORCOD,
      ENTCOD,
      ACOD,
      MONCOD,
      SALDO
    )
    SELECT
      i_id_ejecucion                          AS ID_EJECUCION,
      v_corcod                                AS CORCOD,
      v_entcod                                AS ENTCOD,
      a.ACOD                                  AS ACOD,
      m.MONCOD                                AS MONCOD,
      NVL(
        ROUND(
          NVL(d.SAL_EN_GS, 0) / 1000,
          2
        ),
        0
      )                                       AS SALDO
    FROM (
      -- ACOD presentes en el detalle de la ejecución / fecha
      SELECT DISTINCT d.ACOD
        FROM IT.GE_REP_TAS_SAL_DET d
       WHERE d.ID_EJECUCION = i_id_ejecucion
         AND TRUNC(d.FECHA) = TRUNC(i_fecha_corte)
    ) a
    CROSS JOIN (
      -- las dos monedas del reporte
      SELECT 6200 AS MONCOD FROM DUAL
       UNION ALL
      SELECT 6900 AS MONCOD FROM DUAL
    ) m
    LEFT JOIN (
      -- agregación real a partir del detalle
      SELECT
        d.ACOD,
        d.MONCOD,
        SUM(NVL(d.SAL_EN_GS, 0)) AS SAL_EN_GS
      FROM IT.GE_REP_TAS_SAL_DET d
      WHERE d.ID_EJECUCION = i_id_ejecucion
        AND TRUNC(d.FECHA) = TRUNC(i_fecha_corte)
      GROUP BY
        d.ACOD,
        d.MONCOD
    ) d
      ON d.ACOD   = a.ACOD
     AND d.MONCOD = m.MONCOD;

    COMMIT;
  END PR_GEN_REPORTE;


  ----------------------------------------------------------------------------
  -- Proceso principal: carga detalle y genera reporte (versión bulk)
  ----------------------------------------------------------------------------
  PROCEDURE PR_EJE_TSC (
    i_fecha_corte   IN  DATE,
    o_id_ejecucion  OUT NUMBER
  ) IS

    ----------------------------------------------------------------------------
    -- Cursor base sobre CB_SAL_INV_FINMES + GE_CUENTAS / PR_CTA_PRESTAMOS
    ----------------------------------------------------------------------------
    CURSOR c_det IS
      SELECT f.FECHA,
             f.NRO_CUENTA,
             f.COD_MODULO,
             f.COD_MODALIDAD,
             f.COD_RUBRO,
             f.TIP_SALDO,
             f.COD_MONEDA,
             NVL(p.FEC_INI_RRR, a.FEC_APERTURA) AS FEC_APERTURA,
             a.FEC_VENCIMIENTO,
             f.SAL_ACTUAL
        FROM IT.CB_SAL_INV_FINMES f
        JOIN GE_CUENTAS       a ON a.NRO_CUENTA = f.NRO_CUENTA
        LEFT JOIN PR_CTA_PRESTAMOS p ON p.NRO_CUENTA = f.NRO_CUENTA
       WHERE TRUNC(f.FECHA) = TRUNC(i_fecha_corte)
         AND f.TIP_SALDO    IN ('C', 'Q', 'F')
         AND f.COD_MONEDA   IN ('USD', 'GS')
         AND (
               FN_ES_CODCTA_PERMITIDO(SUBSTR(f.COD_RUBRO, 6, 3)) = 1
               OR SUBSTR(f.COD_RUBRO, 6, 3) IN ('453')
             );

    TYPE t_det_tab IS TABLE OF c_det%ROWTYPE INDEX BY PLS_INTEGER;
    TYPE t_ins_tab IS TABLE OF IT.GE_REP_TAS_SAL_DET%ROWTYPE INDEX BY PLS_INTEGER;

    v_det_tab         t_det_tab;
    v_ins_tab         t_ins_tab;
    c_lote            CONSTANT PLS_INTEGER := 1000;

    v_total_detalle   NUMBER;
    v_procesados      NUMBER := 0;

    v_entcod          NUMBER(4);
    v_corcod          NUMBER(6);

    v_subrub          VARCHAR2(3);
    v_codcta_calc     VARCHAR2(20);
    v_plazo_calc      NUMBER(8);
    v_acod_final      NUMBER(4);
    v_obs             VARCHAR2(400);

    v_cot_usd         NUMBER(18,6);
    v_cotizacion      NUMBER(18,6);
    v_moncod          NUMBER(4);
    v_sal_en_gs       NUMBER(18,2);

    v_mae_acod        NUMBER(4);
    v_usa_maestro     CHAR(1); --TSC CAMBIO 2026-02-25 ddbainotti

    v_tip_destino_esp BA_COD_REFERENCIAS.VAL_MINIMO%TYPE;
    v_significado     BA_COD_REFERENCIAS.SIGNIFICADO%TYPE;

    v_idx             PLS_INTEGER;

  BEGIN
    --------------------------------------------------------------------------
    -- ID_EJECUCION, CORCOD, ENTCOD
    --------------------------------------------------------------------------
    o_id_ejecucion := IT.S_TSC_EJECUCION.NEXTVAL;

    v_corcod := TO_NUMBER(TO_CHAR(TRUNC(i_fecha_corte), 'YYYYMM'));
    v_entcod := PAG_GEN.FU_OBT_COD_ENTIDAD;

    --------------------------------------------------------------------------
    -- Cotización: se obtiene UNA sola vez por fecha
    --------------------------------------------------------------------------
    v_cot_usd := PAG_GEN.FU_OBT_COTIZACION('USD', TRUNC(i_fecha_corte));

    --------------------------------------------------------------------------
    -- Total estimado de registros a procesar
    --------------------------------------------------------------------------
    SELECT COUNT(*)
      INTO v_total_detalle
      FROM IT.CB_SAL_INV_FINMES f
     WHERE TRUNC(f.FECHA) = TRUNC(i_fecha_corte)
       AND f.TIP_SALDO    IN ('C', 'Q', 'F')
       AND f.COD_MONEDA   IN ('USD', 'GS')
       AND (
             FN_ES_CODCTA_PERMITIDO(SUBSTR(f.COD_RUBRO, 6, 3)) = 1
             OR SUBSTR(f.COD_RUBRO, 6, 3) IN ('453')
           );

    --------------------------------------------------------------------------
    -- Log de INICIO en estado EN_PROCESO
    --------------------------------------------------------------------------
    log_proceso(
      i_id_ejecucion       => o_id_ejecucion,
      i_paso               => 'INICIO',
      i_descripcion        => 'Inicio proceso TSC',
      i_estado             => 'EN_PROCESO',
      i_total_detalle      => v_total_detalle,
      i_procesados_detalle => 0
    );

    --------------------------------------------------------------------------
    -- Carga de IT.GE_REP_TAS_SAL_DET en bloques (bulk)
    --------------------------------------------------------------------------
    OPEN c_det;
    LOOP
      FETCH c_det BULK COLLECT INTO v_det_tab LIMIT c_lote;
      EXIT WHEN v_det_tab.COUNT = 0;

      v_ins_tab.DELETE;

      FOR i IN 1 .. v_det_tab.COUNT LOOP
        BEGIN
          --------------------------------------------------------------------
          -- Moneda / cotización / SAL_EN_GS (cotización reutilizada por fecha)
          --------------------------------------------------------------------
          IF v_det_tab(i).COD_MONEDA = 'USD' THEN
            v_moncod     := 6200;
            v_cotizacion := v_cot_usd;
            v_sal_en_gs  := v_det_tab(i).SAL_ACTUAL * v_cot_usd;
          ELSIF v_det_tab(i).COD_MONEDA = 'GS' THEN
            v_moncod     := 6900;
            v_cotizacion := 1;
            v_sal_en_gs  := v_det_tab(i).SAL_ACTUAL;
          ELSE
            v_moncod     := NULL;
            v_cotizacion := NULL;
            v_sal_en_gs  := NULL;
          END IF;

          --------------------------------------------------------------------
          -- TIP_DESTINO_ESP (PR_CTA_DESTINOS / PR_CTA_PRESTAMOS + BA_COD_REF)
          --------------------------------------------------------------------
          v_tip_destino_esp := NULL;
          v_significado     := NULL;

          BEGIN
            -- 1er intento: PR_CTA_DESTINOS
            SELECT cd.tip_des_especifico
              INTO v_tip_destino_esp
              FROM PR_CTA_DESTINOS cd
             WHERE cd.nro_cuenta = v_det_tab(i).NRO_CUENTA;
          EXCEPTION
            WHEN NO_DATA_FOUND THEN
              -- 2do intento: PR_CTA_PRESTAMOS + PR_RUB_ECONOMICOS + BA_COD_REFERENCIAS
              BEGIN
                SELECT a.val_minimo
                  INTO v_tip_destino_esp
                  FROM PR_CTA_PRESTAMOS   p
                  JOIN PR_RUB_ECONOMICOS r
                    ON r.cod_rub_economico = p.cod_rub_economico
                  JOIN BA_COD_REFERENCIAS a
                    ON a.val_minimo = p.tip_destino
                 WHERE a.dominio    = 'TIP_DES_ESPECIFICO'
                   AND p.nro_cuenta = v_det_tab(i).NRO_CUENTA;
              EXCEPTION
                WHEN OTHERS THEN
                  v_tip_destino_esp := NULL;
              END;
            WHEN OTHERS THEN
              v_tip_destino_esp := NULL;
          END;

          -- SIGNIFICADO en BA_COD_REFERENCIAS (si hay tip_destino_esp)
          BEGIN
            IF v_tip_destino_esp IS NOT NULL THEN
              SELECT r.significado
                INTO v_significado
                FROM BA_COD_REFERENCIAS r
               WHERE r.dominio   = 'TIP_DES_ESPECIFICO'
                 AND r.val_minimo = v_tip_destino_esp;
            ELSE
              v_significado := NULL;
            END IF;
          EXCEPTION
            WHEN OTHERS THEN
              v_significado := NULL;
          END;

          --------------------------------------------------------------------
          --TSC CAMBIO 2026-02-25 ddbainotti:
          -- Calcular CODCTA SIEMPRE (también cuando el ACOD venga del maestro)
          --------------------------------------------------------------------
          v_subrub := SUBSTR(v_det_tab(i).COD_RUBRO, 6, 3);

          IF v_subrub IN ('209','405') THEN
            v_codcta_calc := v_subrub || '0' || SUBSTR(v_det_tab(i).COD_RUBRO, 9, 2);
          ELSE
            v_codcta_calc := v_subrub || '000';
          END IF;

          --------------------------------------------------------------------
          --TSC CAMBIO 2026-02-25 ddbainotti:
          -- Intento 1: ACOD desde maestro GE_MAE_TSC por marca USA_ACOD_MAESTRO
          --------------------------------------------------------------------
          v_mae_acod    := NULL;
          v_usa_maestro := 'N';

          BEGIN
            SELECT m.ACOD
              INTO v_mae_acod
              FROM IT.GE_MAE_TSC m
             WHERE m.NRO_CUENTA       = v_det_tab(i).NRO_CUENTA
               AND m.COD_RUBRO        = v_det_tab(i).COD_RUBRO
               AND m.USA_ACOD_MAESTRO = 'S'
               AND ROWNUM = 1;

            v_usa_maestro := 'S';
          EXCEPTION
            WHEN NO_DATA_FOUND THEN
              v_mae_acod    := NULL;
              v_usa_maestro := 'N';
          END;

          IF v_usa_maestro = 'S' AND v_mae_acod IS NOT NULL THEN
            v_acod_final := v_mae_acod;
            v_obs        := 'ACOD definido por maestro GE_MAE_TSC';

            --TSC CAMBIO 2026-02-25 ddbainotti: cuando usa maestro, igual carga CODCTA
            -- (ya está calculado en v_codcta_calc)
            v_plazo_calc := NULL;

          ELSE
            ------------------------------------------------------------------
            -- Intento 2: ACOD calculado mediante PAG_TAS
            ------------------------------------------------------------------
            v_plazo_calc := IT.PAG_TAS.FN_CALC_PLAZO(
                              I_ID_EJECUCION    => o_id_ejecucion,
                              I_COD_MODULO      => TO_CHAR(v_det_tab(i).COD_MODULO),
                              I_COD_MODALIDAD   => TO_CHAR(v_det_tab(i).COD_MODALIDAD),
                              I_FEC_APERTURA    => v_det_tab(i).FEC_APERTURA,
                              I_FEC_VENCIMIENTO => v_det_tab(i).FEC_VENCIMIENTO,
                              I_NRO_CUENTA      => v_det_tab(i).NRO_CUENTA
                            );

            v_acod_final := TO_NUMBER(
                              IT.PAG_TAS.FN_CALC_ACOD(
                                I_ID_EJECUCION  => o_id_ejecucion,
                                I_CODCTA        => v_codcta_calc,
                                I_PLAZO         => v_plazo_calc,
                                I_COD_MODULO    => TO_CHAR(v_det_tab(i).COD_MODULO),
                                I_COD_MODALIDAD => TO_CHAR(v_det_tab(i).COD_MODALIDAD),
                                I_NRO_CUENTA    => v_det_tab(i).NRO_CUENTA,
                                I_COD_RUBRO     => v_det_tab(i).COD_RUBRO,
                                I_TIP_SALDO     => v_det_tab(i).TIP_SALDO
                              )
                            );

            v_obs := 'ACOD calculado por PAG_TAS';
          END IF;

          --------------------------------------------------------------------
          -- Armar registro para inserción bulk en GE_REP_TAS_SAL_DET
          --------------------------------------------------------------------
          v_idx := v_ins_tab.COUNT + 1;

          v_ins_tab(v_idx).ID_EJECUCION      := o_id_ejecucion;
          v_ins_tab(v_idx).FECHA             := v_det_tab(i).FECHA;
          v_ins_tab(v_idx).CORCOD            := v_corcod;
          v_ins_tab(v_idx).ENTCOD            := v_entcod;
          v_ins_tab(v_idx).NRO_CUENTA        := v_det_tab(i).NRO_CUENTA;
          v_ins_tab(v_idx).COD_MODULO        := v_det_tab(i).COD_MODULO;
          v_ins_tab(v_idx).COD_MODALIDAD     := v_det_tab(i).COD_MODALIDAD;
          v_ins_tab(v_idx).COD_RUBRO         := v_det_tab(i).COD_RUBRO;
          v_ins_tab(v_idx).TIP_SALDO         := v_det_tab(i).TIP_SALDO;
          v_ins_tab(v_idx).COD_MONEDA        := v_det_tab(i).COD_MONEDA;
          v_ins_tab(v_idx).FEC_APERTURA      := v_det_tab(i).FEC_APERTURA;
          v_ins_tab(v_idx).FEC_VENCIMIENTO   := v_det_tab(i).FEC_VENCIMIENTO;
          v_ins_tab(v_idx).SAL_ACTUAL        := v_det_tab(i).SAL_ACTUAL;
          v_ins_tab(v_idx).MONCOD            := v_moncod;
          v_ins_tab(v_idx).COTIZACION_USADA  := v_cotizacion;
          v_ins_tab(v_idx).SAL_EN_GS         := v_sal_en_gs;
          v_ins_tab(v_idx).ACOD              := v_acod_final;

          --TSC CAMBIO 2026-02-25 ddbainotti: CODCTA siempre informado (maestro o cálculo)
          v_ins_tab(v_idx).CODCTA_CALC       := v_codcta_calc;

          v_ins_tab(v_idx).PLAZO_CALC        := v_plazo_calc;
          v_ins_tab(v_idx).OBSERVACION       := v_obs;
          v_ins_tab(v_idx).TIP_DESTINO_ESP   := v_tip_destino_esp;
          v_ins_tab(v_idx).SIGNIFICADO       := v_significado;

          v_procesados := v_procesados + 1;

          -- Log de avance cada 50.000 registros (actualiza el mismo registro)
          IF MOD(v_procesados, 50000) = 0 THEN
            log_proceso(
              i_id_ejecucion       => o_id_ejecucion,
              i_paso               => 'CARGA_DETALLE',
              i_descripcion        => 'Registros procesados: ' || v_procesados,
              i_estado             => 'EN_PROCESO',
              i_total_detalle      => v_total_detalle,
              i_procesados_detalle => v_procesados
            );
          END IF;

        EXCEPTION
          WHEN OTHERS THEN
            log_error_det(
              i_id_ejecucion  => o_id_ejecucion,
              i_paso          => 'CARGA_DETALLE',
              i_nro_cuenta    => v_det_tab(i).NRO_CUENTA,
              i_cod_rubro     => v_det_tab(i).COD_RUBRO,
              i_cod_modulo    => v_det_tab(i).COD_MODULO,
              i_cod_modalidad => v_det_tab(i).COD_MODALIDAD,
              i_mensaje       => 'Error procesando registro de detalle',
              i_cod_error     => SQLCODE,
              i_detalle_error => SQLERRM
            );
            -- No se agrega el registro al lote, continúa con el siguiente
        END;
      END LOOP;

      ------------------------------------------------------------------------
      -- Inserción bulk del bloque y commit por lote
      ------------------------------------------------------------------------
      IF v_ins_tab.COUNT > 0 THEN
        FORALL idx IN v_ins_tab.FIRST .. v_ins_tab.LAST
          INSERT INTO IT.GE_REP_TAS_SAL_DET VALUES v_ins_tab(idx);

        COMMIT;
      END IF;

    END LOOP;
    CLOSE c_det;

    --------------------------------------------------------------------------
    -- Log de fin de carga de detalle
    --------------------------------------------------------------------------
    log_proceso(
      i_id_ejecucion       => o_id_ejecucion,
      i_paso               => 'CARGA_DETALLE',
      i_descripcion        => 'Fin carga detalle',
      i_estado             => 'OK',
      i_total_detalle      => v_total_detalle,
      i_procesados_detalle => v_procesados
    );

    --------------------------------------------------------------------------
    -- Generación del reporte agrupado
    --------------------------------------------------------------------------
    PR_GEN_REPORTE(i_fecha_corte   => i_fecha_corte,
                   i_id_ejecucion  => o_id_ejecucion);

    --------------------------------------------------------------------------
    -- Marcar INICIO como OK y FIN OK
    --------------------------------------------------------------------------
    log_proceso(
      i_id_ejecucion       => o_id_ejecucion,
      i_paso               => 'INICIO',
      i_descripcion        => 'Inicio proceso TSC - parámetros iniciales OK',
      i_estado             => 'OK',
      i_total_detalle      => v_total_detalle,
      i_procesados_detalle => v_procesados
    );

    log_proceso(
      i_id_ejecucion       => o_id_ejecucion,
      i_paso               => 'FIN',
      i_descripcion        => 'Proceso TSC finalizado correctamente',
      i_estado             => 'OK',
      i_total_detalle      => v_total_detalle,
      i_procesados_detalle => v_procesados
    );

  EXCEPTION
    WHEN OTHERS THEN
      -- En caso de error general, marcar INICIO y FIN en ERROR
      log_proceso(
        i_id_ejecucion       => o_id_ejecucion,
        i_paso               => 'INICIO',
        i_descripcion        => 'Proceso TSC con error (INICIO)',
        i_estado             => 'ERROR',
        i_total_detalle      => v_total_detalle,
        i_procesados_detalle => v_procesados,
        i_tipo_mensaje       => 'ERROR',
        i_cod_error          => SQLCODE,
        i_detalle_error      => SQLERRM
      );

      log_proceso(
        i_id_ejecucion       => o_id_ejecucion,
        i_paso               => 'FIN',
        i_descripcion        => 'Proceso TSC finalizado con error',
        i_estado             => 'ERROR',
        i_total_detalle      => v_total_detalle,
        i_procesados_detalle => v_procesados,
        i_tipo_mensaje       => 'ERROR',
        i_cod_error          => SQLCODE,
        i_detalle_error      => SQLERRM
      );
      RAISE;
  END PR_EJE_TSC;

END PAG_TSC;