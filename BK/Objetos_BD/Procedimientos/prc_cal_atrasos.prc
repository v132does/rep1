CREATE OR REPLACE PROCEDURE IT.PRC_CAL_ATRASOS IS
  v_fecha      DATE := pag_cal.fu_obt_fec_actual(1);
  v_hor_inicio VARCHAR2(8);
  v_hor_fin    VARCHAR2(8);
BEGIN
  BEGIN 
    pre_ini_aplicacion; 
    pae_cnf.g_cod_modulo := 1; 
  END;
  
  -- =========================================================================
  -- UPDATE 1: Optimización de MERGE principal
  --   1. EXISTS en subconsulta 'y' (Filtro temprano sobre cc_sal_mensuales)
  --   2. Expresión CASE para consolidar UPDATE1 + UPDATE2 en un solo pase DML
  --   3. Eliminación de asignaciones redundantes (r.can_dias, r.can_dia_sobregiro)
  -- =========================================================================
  v_hor_inicio := TO_CHAR(SYSDATE, 'hh24:mi:ss');

  MERGE INTO cc_sobregiros_res r
    USING (
        SELECT 
            r.nro_cuenta,
            (NVL(t.sal_tot_batch, 0) - NVL(t.sal_blo_batch, 0) - NVL(t.sal_ret_batch, 0)) AS sal_total,
            t.max_atraso AS max_atr_actual,
            y.pro_atraso,
            CASE 
                WHEN t.max_atraso > r.can_dias THEN t.max_atraso 
                ELSE r.can_dias 
            END AS max_atraso
        FROM cc_sobregiros_res r
        JOIN cc_cta_corrientes t 
          ON r.nro_cuenta = t.nro_cuenta
        LEFT JOIN (
            SELECT p.nro_cuenta, 
                   AVG(p.can_dia_deudor) AS pro_atraso
            FROM cc_sal_mensuales p
            WHERE p.can_dia_deudor > 0
              -- Filtro EXISTS para procesar solo cuentas activas en sobregiro
              AND EXISTS (
                  SELECT 1 
                  FROM cc_sobregiros_res sub 
                  WHERE sub.nro_cuenta = p.nro_cuenta
              )
            GROUP BY p.nro_cuenta
        ) y ON y.nro_cuenta = r.nro_cuenta
    ) src
    ON (r.nro_cuenta = src.nro_cuenta)
    WHEN MATCHED THEN
        UPDATE SET 
            r.max_atraso = src.max_atraso,
            r.pro_atraso = src.pro_atraso,
            -- Asignación condicional que reemplaza a UPDATE2
            r.mto_mora   = CASE 
                             WHEN r.can_dias = 0 THEN 0 
                             ELSE src.sal_total * -1 
                           END;

  v_hor_fin := TO_CHAR(SYSDATE, 'hh24:mi:ss');
  prg_act_log_procesos('PRC_CAL_ATRASOS', 'UPDATE1', v_fecha, v_hor_inicio, v_hor_fin);
  
  -- =========================================================================
  -- UPDATE 2: Consolidado dentro del UPDATE 1
  -- =========================================================================
  -- =========================================================================
  -- UPDATE 3: Reemplazo de MERGE por UPDATE directo con NOT EXISTS
  -- Permite uso de Anti-Join / Index Range Scan directo sobre ge_cuentas.
  -- =========================================================================
  v_hor_inicio := TO_CHAR(SYSDATE, 'hh24:mi:ss');

  UPDATE ge_cuentas g
  SET g.dia_atraso = 0,
      g.mto_mora   = 0
  WHERE g.mto_mora > 0
    AND EXISTS (
        SELECT 1 
        FROM cc_cta_corrientes c 
        WHERE c.nro_cuenta    = g.nro_cuenta
          AND c.cod_modulo    = 4
          AND c.cod_modalidad = 41
    )
    AND NOT EXISTS (
        SELECT 1 
        FROM cc_sobregiros_res r 
        WHERE r.nro_cuenta = g.nro_cuenta
    );

  v_hor_fin := TO_CHAR(SYSDATE, 'hh24:mi:ss');
  prg_act_log_procesos('PRC_CAL_ATRASOS', 'UPDATE2', v_fecha, v_hor_inicio, v_hor_fin);
  
  -- =========================================================================
  -- UPDATE 4: Reemplazo de MERGE por UPDATE directo con NOT EXISTS
  -- Elimina sobrecarga del MERGE y filtra eficientemente mto_mora > 0.
  -- =========================================================================
  v_hor_inicio := TO_CHAR(SYSDATE, 'hh24:mi:ss');

  UPDATE cc_cta_corrientes c
  SET c.dia_atraso = 0,
      c.mto_mora   = 0
  WHERE c.cod_modulo    = 4
    AND c.cod_modalidad = 41
    AND c.mto_mora      > 0
    AND NOT EXISTS (
        SELECT 1 
        FROM cc_sobregiros_res r 
        WHERE r.nro_cuenta = c.nro_cuenta
    );

  v_hor_fin := TO_CHAR(SYSDATE, 'hh24:mi:ss');
  prg_act_log_procesos('PRC_CAL_ATRASOS', 'UPDATE3', v_fecha, v_hor_inicio, v_hor_fin);  
      
END prc_cal_atrasos;
/
