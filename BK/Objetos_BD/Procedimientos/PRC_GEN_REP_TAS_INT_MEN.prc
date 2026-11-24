create or replace PROCEDURE                   IT.PRC_GEN_REP_TAS_INT_MEN IS
  /* ==================== Identificador de ejecución ==================== */
  v_id_ejecucion NUMBER := TO_NUMBER(TO_CHAR(SYSTIMESTAMP,'YYYYMMDDHH24MISSFF3'));

  /* ==================== Fechas por reporte (GE_CALENDARIOS) ==================== */
  v_fecha_cierre_ca  DATE;
  v_fecha_cierre_cc  DATE;
  v_fecha_cierre_tc  DATE;

  v_semana_ca        VARCHAR2(10);
  v_semana_cc        VARCHAR2(10);
  v_semana_tc        VARCHAR2(10);

  v_fecha_char_ca    VARCHAR2(10);
  v_fecha_char_cc    VARCHAR2(10);
  v_fecha_char_tc    VARCHAR2(10);

  /* ==================== Parametrización ==================== */
  v_array_limit       PLS_INTEGER := 50000;  -- default si parámetro nulo/erróneo
  v_commit_each_rows  PLS_INTEGER := 0;      -- 0 = commit único al final
  v_rows_buffer       PLS_INTEGER := 0;

  /* ==================== Totales por rama ==================== */
  v_ca_gs NUMBER := 0; v_ca_usd NUMBER := 0;
  v_cc_gs NUMBER := 0; v_cc_usd NUMBER := 0;
  v_tc    NUMBER := 0;

  /* ==================== Tipos y buffer ==================== */
  TYPE t_row IS RECORD (
    corcod           VARCHAR2(10),
    codcta           VARCHAR2(10),
    entcod           VARCHAR2(10),
    tasreg           VARCHAR2(1),
    acod             VARCHAR2(10),
    fecha_char       VARCHAR2(10),
    tascod           VARCHAR2(50),
    moncod           NUMBER,
    periodo          NUMBER,
    tasnom           NUMBER,
    tasefe           NUMBER,
    tasmont          NUMBER,
    saldo_contable   NUMBER
  );
  TYPE t_tab IS TABLE OF t_row;
  v_batch t_tab := t_tab();  -- inicializada

  /* ==================== Cursores ==================== */
    CURSOR cur_ca (p_mon VARCHAR2) IS
      SELECT
        v_semana_ca                                   AS corcod,
        SUBSTR(de.cod_rubro, 6, 3) || '000'           AS codcta,
        TO_CHAR(pag_gen.fu_obt_cod_entidad)           AS entcod,
        'V'                                           AS tasreg,
        '2021'                                        AS acod,
        v_fecha_char_ca                               AS fecha_char,
        a.nro_cuenta                                  AS tascod,
        DECODE(a.cod_moneda,'GS',6900,'USD',6200)     AS moncod,
        30                                            AS periodo,
        NVL(de.val_tasa,
            FUG_OBT_VAL_TASA( a.cod_modulo, a.cod_modalidad, a.cod_oficina,
                              a.nro_cuenta, a.cod_moneda, NULL,
                              a.tas_personalizada, a.cod_tasa, NULL, a.fec_apertura )
        )                                             AS tasnom,
        ROUND(PAS_BCP.FU_OBT_TAE(
                NVL(de.val_tasa,
                    FUG_OBT_VAL_TASA( a.cod_modulo, a.cod_modalidad, a.cod_oficina,
                                      a.nro_cuenta, a.cod_moneda, NULL,
                                      a.tas_personalizada, a.cod_tasa, NULL, a.fec_apertura )
                ), 30
             ), 2)                                    AS tasefe,
        NVL(xx.promedio, a.sal_promedio/1000)         AS tasmont,
        de.sal_actual                                 AS saldo_contable
      FROM ge_cuentas a
      JOIN ge_est_cuentas b
        ON a.cod_modulo    = b.cod_modulo
       AND a.cod_modalidad = b.cod_modalidad
       AND a.estado        = b.estado
      JOIN it.cb_sal_inv_finmes de
        ON de.nro_cuenta = a.nro_cuenta
      LEFT JOIN (
        SELECT ROUND((NVL(c.sal_acu_diario,0) / NVL(c.can_dia_acumulado,1)),2) / 1000 AS promedio,
               c.nro_cuenta
          FROM ah_sal_mensuales c
         WHERE c.mes = TO_NUMBER(TO_CHAR(v_fecha_cierre_ca,'MM'))
           AND c.ano = TO_NUMBER(TO_CHAR(v_fecha_cierre_ca,'YYYY'))
      ) xx ON xx.nro_cuenta = a.nro_cuenta
     WHERE de.fecha            = v_fecha_cierre_ca
       AND de.tip_saldo        = 'C'
       AND a.cod_moneda        = p_mon
       AND de.cod_moneda       = p_mon
       AND SUBSTR(de.cod_rubro,6,3) IN ('102','138','152','156','196','236','238','292')
       AND a.cod_modulo        = 3
       AND a.cod_modalidad     IN (31,39,334);


    CURSOR cur_cc (p_mon VARCHAR2) IS
      SELECT
        v_semana_cc                                   AS corcod,
        SUBSTR(de.cod_rubro, 6, 3) || '000'           AS codcta,
        TO_CHAR(pag_gen.fu_obt_cod_entidad)           AS entcod,
        'V'                                           AS tasreg,
        '1080'                                        AS acod,
        v_fecha_char_cc                               AS fecha_char,
        a.nro_cuenta                                  AS tascod,
        DECODE(a.cod_moneda,'GS',6900,'USD',6200)     AS moncod,
        30                                            AS periodo,
        CAST(NULL AS NUMBER)                          AS tasnom,
        CAST(NULL AS NUMBER)                          AS tasefe,
        NVL(xx.promedio, a.sal_promedio/1000)         AS tasmont,
        de.sal_actual                                 AS saldo_contable
      FROM ge_cuentas a
      JOIN ge_est_cuentas b
        ON a.cod_modulo    = b.cod_modulo
       AND a.cod_modalidad = b.cod_modalidad
       AND a.estado        = b.estado
      JOIN it.cb_sal_inv_finmes de
        ON de.nro_cuenta = a.nro_cuenta
      LEFT JOIN (
        SELECT ROUND((NVL(c.sal_acu_diario,0) / NVL(c.can_dia_acumulado,1)),2) / 1000 AS promedio,
               c.nro_cuenta
          FROM cc_sal_mensuales c
         WHERE c.mes = TO_NUMBER(TO_CHAR(v_fecha_cierre_cc,'MM'))
           AND c.ano = TO_NUMBER(TO_CHAR(v_fecha_cierre_cc,'YYYY'))
      ) xx ON xx.nro_cuenta = a.nro_cuenta
     WHERE de.fecha            = v_fecha_cierre_cc
       AND de.tip_saldo        = 'C'
       AND a.cod_moneda        = p_mon
       AND de.cod_moneda       = p_mon
       AND SUBSTR(de.cod_rubro,6,3) IN ('136','187','189','284','290','397')
       AND a.cod_modulo        = 4
       AND a.cod_modalidad     = 41;


    CURSOR cur_tc IS
        WITH FF AS (SELECT v_fecha_cierre_tc AS FECHA FROM DUAL)
        SELECT
          v_semana_tc                                   AS corcod,
          '205002'                                      AS codcta,
          TO_CHAR(pag_gen.fu_obt_cod_entidad)           AS entcod,
          'V'                                           AS tasreg,
          '1066'                                        AS acod,
          v_fecha_char_tc                               AS fecha_char,
          A.NRO_CUENTA                                  AS tascod,
          DECODE(A.COD_MONEDA,'GS',6900,'USD',6200)     AS moncod,
          30                                            AS periodo,
          A.VAL_TASA                                    AS tasnom,
          ROUND(PAS_BCP.FU_OBT_TAE(A.VAL_TASA,30),2)    AS tasefe,
          A.SAL_PROMEDIO / 1000                         AS tasmont,
          DE.SAL_ACTUAL                                 AS saldo_contable
        FROM FF
        JOIN CB_SAL_INVENTARIOS_DET_HIS DE
          ON DE.FECHA = FF.FECHA
        JOIN CB_SAL_INVENTARIOS_HIS CA
          ON CA.FECHA = DE.FECHA
         AND DE.NRO_REFERENCIA = CA.NRO_REFERENCIA
        JOIN GE_CUENTAS A
          ON DE.NRO_CUENTA = A.NRO_CUENTA
        JOIN GE_EST_CUENTAS B
          ON A.COD_MODULO    = B.COD_MODULO
         AND A.COD_MODALIDAD = B.COD_MODALIDAD
         AND A.ESTADO        = B.ESTADO
        LEFT JOIN TA_CTA_TARJETAS T
          ON T.NRO_CUENTA = A.NRO_CUENTA
       WHERE CA.TIP_SALDO = 'C'
         AND A.COD_MODULO = 5
         AND B.ACTIVO     = 'S'
         AND SUBSTR(CA.COD_RUBRO,6,5) = '20502';



  /* ==================== Helpers ==================== */

  -- Parámetros dinámicos con defaults
  PROCEDURE p_load_params IS
    v_raw VARCHAR2(4000);
  BEGIN
    BEGIN v_raw := fug_obt_pardinamico('VAL_REP_TAS_ARRAY_LIMIT'); EXCEPTION WHEN OTHERS THEN v_raw := NULL; END;
    IF v_raw IS NULL OR TRIM(v_raw) IS NULL THEN v_array_limit := 50000;
    ELSE BEGIN v_array_limit := TO_NUMBER(TRIM(v_raw)); EXCEPTION WHEN OTHERS THEN v_array_limit := 50000; END; END IF;

    BEGIN v_raw := fug_obt_pardinamico('VAL_REP_TAS_COMMIT_ROWS'); EXCEPTION WHEN OTHERS THEN v_raw := NULL; END;
    IF v_raw IS NULL OR TRIM(v_raw) IS NULL THEN v_commit_each_rows := 0;
    ELSE BEGIN v_commit_each_rows := TO_NUMBER(TRIM(v_raw)); EXCEPTION WHEN OTHERS THEN v_commit_each_rows := 0; END; END IF;
  END p_load_params;

  -- Logger AUTÓNOMO (siempre por rama; para INIT/TRUNCATE/FIN/ERROR dejar totales NULL)
  PROCEDURE log_auton(p_etapa     VARCHAR2,
                      p_reporte   VARCHAR2,
                      p_moneda    VARCHAR2,
                      p_mensaje   VARCHAR2,
                      p_ins_rama  NUMBER,
                      p_tot_rama  NUMBER) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
    v_pct NUMBER;
  BEGIN
    v_pct := CASE WHEN p_tot_rama > 0 THEN ROUND(100 * p_ins_rama / p_tot_rama, 2) END;

    INSERT INTO IT.GE_LOG_TAS_INT_MEN(
      ID_EJECUCION, FECHA_LOG, ETAPA, MENSAJE,
      TOTAL_INSERTS, TOTAL_ESPERADO, PORCENTAJE
    ) VALUES (
      v_id_ejecucion, SYSDATE, NVL(p_etapa,'-'),
      CASE WHEN p_reporte IS NOT NULL OR p_moneda IS NOT NULL
           THEN '['||NVL(p_reporte,'-')||'/'||NVL(p_moneda,'-')||'] '||p_mensaje
           ELSE p_mensaje
      END,
      p_ins_rama, p_tot_rama, v_pct
    );
    COMMIT;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  -- Inserción por rama con progreso a log (solo % de rama)
  PROCEDURE p_insert_lote(p_reporte   VARCHAR2,
                          p_moneda    VARCHAR2,
                          p_etiqueta  VARCHAR2,
                          p_tot_rama  NUMBER) IS
    v_inserted_branch PLS_INTEGER := 0;
    v_ins_this_fetch  PLS_INTEGER;
  BEGIN
    v_batch := t_tab();  -- vaciar buffer
    log_auton('INIT_RAMA', p_reporte, p_moneda, 'Inicio '||p_etiqueta, 0, p_tot_rama);

    IF p_reporte = 'CA' THEN
      OPEN cur_ca(p_moneda);
      LOOP
        FETCH cur_ca BULK COLLECT INTO v_batch LIMIT v_array_limit;
        EXIT WHEN v_batch.COUNT = 0;

        FORALL i IN 1 .. v_batch.COUNT SAVE EXCEPTIONS
          INSERT INTO IT.GE_REP_TAS_INT_MEN(
            REPORTE, MONEDA, CORCOD, CODCTA, ENTCOD, TASREG, ACOD,
            FECHA, MONCOD, TASCOD, PERIODO, TASNOM, TASEFE, TASMONT, SALDO_CONTABLE
          ) VALUES (
            'CA', p_moneda,
            v_batch(i).corcod, v_batch(i).codcta, v_batch(i).entcod, v_batch(i).tasreg, '2021',
            v_fecha_cierre_ca, v_batch(i).moncod, v_batch(i).tascod, v_batch(i).periodo,
            v_batch(i).tasnom, v_batch(i).tasefe, v_batch(i).tasmont, v_batch(i).saldo_contable
          );

        v_ins_this_fetch  := v_batch.COUNT;
        v_inserted_branch := v_inserted_branch + v_ins_this_fetch;
        v_rows_buffer     := v_rows_buffer     + v_ins_this_fetch;

        IF v_commit_each_rows > 0 AND v_rows_buffer >= v_commit_each_rows THEN
          COMMIT; v_rows_buffer := 0;
          log_auton('COMMIT', p_reporte, p_moneda, 'Commit '||p_etiqueta, v_inserted_branch, p_tot_rama);
        END IF;
      END LOOP;
      CLOSE cur_ca;

    ELSIF p_reporte = 'CC' THEN
      OPEN cur_cc(p_moneda);
      LOOP
        FETCH cur_cc BULK COLLECT INTO v_batch LIMIT v_array_limit;
        EXIT WHEN v_batch.COUNT = 0;

        FORALL i IN 1 .. v_batch.COUNT SAVE EXCEPTIONS
          INSERT INTO IT.GE_REP_TAS_INT_MEN(
            REPORTE, MONEDA, CORCOD, CODCTA, ENTCOD, TASREG, ACOD,
            FECHA, MONCOD, TASCOD, PERIODO, TASNOM, TASEFE, TASMONT, SALDO_CONTABLE
          ) VALUES (
            'CC', p_moneda,
            v_batch(i).corcod, v_batch(i).codcta, v_batch(i).entcod, v_batch(i).tasreg, '1080',
            v_fecha_cierre_cc, v_batch(i).moncod, v_batch(i).tascod, v_batch(i).periodo,
            v_batch(i).tasnom, v_batch(i).tasefe, v_batch(i).tasmont, v_batch(i).saldo_contable
          );

        v_ins_this_fetch  := v_batch.COUNT;
        v_inserted_branch := v_inserted_branch + v_ins_this_fetch;
        v_rows_buffer     := v_rows_buffer     + v_ins_this_fetch;

        IF v_commit_each_rows > 0 AND v_rows_buffer >= v_commit_each_rows THEN
          COMMIT; v_rows_buffer := 0;
          log_auton('COMMIT', p_reporte, p_moneda, 'Commit '||p_etiqueta, v_inserted_branch, p_tot_rama);
        END IF;
      END LOOP;
      CLOSE cur_cc;

    ELSIF p_reporte = 'TC' THEN
      OPEN cur_tc;
      LOOP
        FETCH cur_tc BULK COLLECT INTO v_batch LIMIT v_array_limit;
        EXIT WHEN v_batch.COUNT = 0;

        FORALL i IN 1 .. v_batch.COUNT SAVE EXCEPTIONS
          INSERT INTO IT.GE_REP_TAS_INT_MEN(
            REPORTE, MONEDA, CORCOD, CODCTA, ENTCOD, TASREG, ACOD,
            FECHA, MONCOD, TASCOD, PERIODO, TASNOM, TASEFE, TASMONT, SALDO_CONTABLE
          ) VALUES (
            'TC',
            CASE v_batch(i).moncod WHEN 6900 THEN 'GS' WHEN 6200 THEN 'USD' ELSE NULL END,
            v_batch(i).corcod, v_batch(i).codcta, v_batch(i).entcod, v_batch(i).tasreg, '1066',
            v_fecha_cierre_tc, v_batch(i).moncod, v_batch(i).tascod, v_batch(i).periodo,
            v_batch(i).tasnom, v_batch(i).tasefe, v_batch(i).tasmont, v_batch(i).saldo_contable
          );

        v_ins_this_fetch  := v_batch.COUNT;
        v_inserted_branch := v_inserted_branch + v_ins_this_fetch;
        v_rows_buffer     := v_rows_buffer     + v_ins_this_fetch;

        IF v_commit_each_rows > 0 AND v_rows_buffer >= v_commit_each_rows THEN
          COMMIT; v_rows_buffer := 0;
          -- (Para TC, la moneda va por fila; en el log dejamos la etiqueta de rama)
          log_auton('COMMIT', p_reporte, NULL, 'Commit '||p_etiqueta, v_inserted_branch, p_tot_rama);
        END IF;
      END LOOP;
      CLOSE cur_tc;

    ELSE
      RAISE_APPLICATION_ERROR(-20001, 'Reporte no soportado: '||p_reporte);
    END IF;

    -- Fin de rama (debe quedar en 100%)
    log_auton('FIN_RAMA', p_reporte, p_moneda, 'Fin '||p_etiqueta, v_inserted_branch, p_tot_rama);

  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = -24381 THEN
        log_auton('ERROR', p_reporte, p_moneda, 'Errores por fila (SAVE EXCEPTIONS) en '||p_etiqueta, NULL, NULL);
        RAISE_APPLICATION_ERROR(-20002, 'Errores por fila en '||p_etiqueta);
      ELSE
        log_auton('ERROR', p_reporte, p_moneda, SQLERRM, NULL, NULL);
        RAISE;
      END IF;
  END p_insert_lote;

BEGIN
  /* Fechas por módulo (último día de mes por cada COD_MODULO) */
  SELECT ULT_DIA_MES_HABIL INTO v_fecha_cierre_ca FROM GE_CALENDARIOS WHERE COD_MODULO = 3;
  SELECT ULT_DIA_MES_HABIL INTO v_fecha_cierre_cc FROM GE_CALENDARIOS WHERE COD_MODULO = 4;
  SELECT ULT_DIA_MES_HABIL INTO v_fecha_cierre_tc FROM GE_CALENDARIOS WHERE COD_MODULO = 5;

  IF v_fecha_cierre_ca IS NULL OR v_fecha_cierre_cc IS NULL OR v_fecha_cierre_tc IS NULL THEN
    RAISE_APPLICATION_ERROR(-20010, 'ULT_DIA_MES nulo en GE_CALENDARIOS para 3/4/5.');
  END IF;

  v_fecha_char_ca := TO_CHAR(v_fecha_cierre_ca,'DD/MM/YYYY');
  v_fecha_char_cc := TO_CHAR(v_fecha_cierre_cc,'DD/MM/YYYY');
  v_fecha_char_tc := TO_CHAR(v_fecha_cierre_tc,'DD/MM/YYYY');

  -- Semana por fecha
  BEGIN SELECT s.semana INTO v_semana_ca FROM sb_semanas s WHERE v_fecha_cierre_ca BETWEEN s.desde AND s.hasta;
  EXCEPTION WHEN NO_DATA_FOUND THEN RAISE_APPLICATION_ERROR(-20011, 'SB_SEMANAS sin registro para CA '||v_fecha_char_ca);
           WHEN TOO_MANY_ROWS  THEN RAISE_APPLICATION_ERROR(-20012, 'SB_SEMANAS múltiple para CA '||v_fecha_char_ca);
  END;
  BEGIN SELECT s.semana INTO v_semana_cc FROM sb_semanas s WHERE v_fecha_cierre_cc BETWEEN s.desde AND s.hasta;
  EXCEPTION WHEN NO_DATA_FOUND THEN RAISE_APPLICATION_ERROR(-20013, 'SB_SEMANAS sin registro para CC '||v_fecha_char_cc);
           WHEN TOO_MANY_ROWS  THEN RAISE_APPLICATION_ERROR(-20014, 'SB_SEMANAS múltiple para CC '||v_fecha_char_cc);
  END;
  BEGIN SELECT s.semana INTO v_semana_tc FROM sb_semanas s WHERE v_fecha_cierre_tc BETWEEN s.desde AND s.hasta;
  EXCEPTION WHEN NO_DATA_FOUND THEN RAISE_APPLICATION_ERROR(-20015, 'SB_SEMANAS sin registro para TC '||v_fecha_char_tc);
           WHEN TOO_MANY_ROWS  THEN RAISE_APPLICATION_ERROR(-20016, 'SB_SEMANAS múltiple para TC '||v_fecha_char_tc);
  END;

  /* Parámetros */
  p_load_params;

  /* Totales esperados por rama (para % de rama) */
  SELECT COUNT(*) INTO v_ca_gs
    FROM it.cb_sal_inv_finmes de JOIN ge_cuentas a ON a.nro_cuenta = de.nro_cuenta
   WHERE de.fecha = v_fecha_cierre_ca AND de.tip_saldo = 'C' AND a.cod_modulo = 3
     AND a.cod_moneda = 'GS' AND de.cod_moneda = 'GS'
     AND a.cod_modalidad IN (31,39,334)
     AND SUBSTR(de.cod_rubro,6,3) IN ('102','138','152','156','196','236','238','292');

  SELECT COUNT(*) INTO v_ca_usd
    FROM it.cb_sal_inv_finmes de JOIN ge_cuentas a ON a.nro_cuenta = de.nro_cuenta
   WHERE de.fecha = v_fecha_cierre_ca AND de.tip_saldo = 'C' AND a.cod_modulo = 3
     AND a.cod_moneda = 'USD' AND de.cod_moneda = 'USD'
     AND a.cod_modalidad IN (31,39,334)
     AND SUBSTR(de.cod_rubro,6,3) IN ('102','138','152','156','196','236','238','292');

  SELECT COUNT(*) INTO v_cc_gs
    FROM it.cb_sal_inv_finmes de JOIN ge_cuentas a ON a.nro_cuenta = de.nro_cuenta
   WHERE de.fecha = v_fecha_cierre_cc AND de.tip_saldo = 'C' AND a.cod_modulo = 4
     AND a.cod_moneda = 'GS' AND de.cod_moneda = 'GS'
     AND a.cod_modalidad = 41
     AND SUBSTR(de.cod_rubro,6,3) IN ('136','187','189','284','290','397');

  SELECT COUNT(*) INTO v_cc_usd
    FROM it.cb_sal_inv_finmes de JOIN ge_cuentas a ON a.nro_cuenta = de.nro_cuenta
   WHERE de.fecha = v_fecha_cierre_cc AND de.tip_saldo = 'C' AND a.cod_modulo = 4
     AND a.cod_moneda = 'USD' AND de.cod_moneda = 'USD'
     AND a.cod_modalidad = 41
     AND SUBSTR(de.cod_rubro,6,3) IN ('136','187','189','284','290','397');

  SELECT COUNT(*) INTO v_tc
    FROM CB_SAL_INVENTARIOS_DET_HIS de
    JOIN CB_SAL_INVENTARIOS_HIS ca
      ON ca.fecha = de.fecha AND ca.nro_referencia = de.nro_referencia
    JOIN ge_cuentas a
      ON a.nro_cuenta = de.nro_cuenta
    JOIN ge_est_cuentas b
      ON a.cod_modulo=b.cod_modulo AND a.cod_modalidad=b.cod_modalidad AND a.estado=b.estado
   WHERE de.fecha = v_fecha_cierre_tc AND ca.tip_saldo = 'C' AND a.cod_modulo = 5
     AND b.activo = 'S' AND SUBSTR(ca.cod_rubro,6,5) = '20502';

  /* Log inicial (sin totales) */
  log_auton('INIT', NULL, NULL,
            'Fechas CA:'||v_fecha_char_ca||', CC:'||v_fecha_char_cc||', TC:'||v_fecha_char_tc,
            NULL, NULL);

  /* Refrescar destino */
  EXECUTE IMMEDIATE 'TRUNCATE TABLE IT.GE_REP_TAS_INT_MEN';
  log_auton('TRUNCATE', NULL, NULL, 'Tabla IT.GE_REP_TAS_INT_MEN truncada', NULL, NULL);

  /* Carga por ramas (log por rama) */
  p_insert_lote('CA','GS',  'CA-GS',  v_ca_gs);
  p_insert_lote('CA','USD', 'CA-USD', v_ca_usd);
  p_insert_lote('CC','GS',  'CC-GS',  v_cc_gs);
  p_insert_lote('CC','USD', 'CC-USD', v_cc_usd);
  p_insert_lote('TC',NULL,  'TC',     v_tc);


  /* ==================== Paso final: resumen CODCTA + MONCOD ==================== */

  -- Inserto agregados
  INSERT INTO IT.GE_REP_TAS_INT_MEN (
    REPORTE, MONEDA, CORCOD, CODCTA, ENTCOD, TASREG, ACOD,
    FECHA, MONCOD,
    TASCOD,              -- NRO_CUENTA agregado = CODCTA||LPAD(MONCOD,4,'0')
    PERIODO,
    TASNOM,              -- promedio simple
    TASEFE,              -- promedio simple
    TASMONT              -- suma
  )
    SELECT
        'AG' AS REPORTE,
        CASE t.MONCOD WHEN 6900 THEN 'GS' WHEN 6200 THEN 'USD' END AS MONEDA,
        MIN(t.CORCOD)                         AS CORCOD,
        t.CODCTA                              AS CODCTA,
        MIN(t.ENTCOD)                         AS ENTCOD,
        MIN(t.TASREG)                         AS TASREG,
        MIN(t.ACOD)                           AS ACOD,
        MIN(t.FECHA)                          AS FECHA,
        t.MONCOD                              AS MONCOD,
        TO_CHAR(t.CODCTA) || LPAD(TO_CHAR(t.MONCOD),4,'0') AS TASCOD,
        MIN(t.PERIODO)                        AS PERIODO,
        AVG(t.TASNOM)                         AS TASNOM,
        AVG(t.TASEFE)                         AS TASEFE,
        SUM(
          CASE 
            WHEN t.MONCOD = 6200
              THEN t.TASMONT * PAG_GEN.FU_OBT_COTIZACION('USD', TRUNC(t.FECHA))
            ELSE t.TASMONT
          END
        ) AS TASMONT
    FROM IT.GE_REP_TAS_INT_MEN t
    WHERE t.REPORTE IN ('CA','CC','TC') 
      AND t.CODCTA NOT IN (152000,156000)
    GROUP BY t.CODCTA, t.MONCOD;

  -- Log opcional del agregado
  BEGIN
    log_auton('FIN_RAMA', 'AG', NULL, 'Insert resumen CODCTA+MONCOD', NULL, NULL);
  EXCEPTION WHEN OTHERS THEN NULL; END;

  COMMIT;
  log_auton('FIN', NULL, NULL, 'Proceso finalizado OK', NULL, NULL);

EXCEPTION
  WHEN OTHERS THEN
    ROLLBACK;
    log_auton('ERROR', NULL, NULL, SQLERRM, NULL, NULL);
    RAISE;
END;