CREATE OR REPLACE PROCEDURE IT.PRG_VER_CONSISTENCIA IS
  v_cod_mon_local VARCHAR2(4) := pag_gen.FU_OBT_MON_LOCAL;
  v_fecha         DATE        := pag_cal.FU_OBT_FEC_ACTUAL(1);

--Variables a Utilizar--
  v_fec_actual ge_calendarios.fec_actual%type := pag_cal.FU_OBT_FEC_ACTUAL(1);
  v_est_modulo  ba_modulos.estado%type;
  v_hor_ini     VARCHAR2(8);
  v_hor_fin     VARCHAR2(8);

  PROCEDURE lp_logeo(p_cod_proceso VARCHAR2, p_hor_ini VARCHAR2, p_hor_fin VARCHAR2) 
  IS PRAGMA AUTONOMOUS_TRANSACTION;
  BEGIN
    INSERT INTO ge_log_procesos (fecha, cod_programa, cod_proceso, hor_inicio, hor_fin)
    VALUES (pag_cal.FU_OBT_FEC_ACTUAL(1), 'PRG_VER_CONSISTENCIA', p_cod_proceso, p_hor_ini, p_hor_fin);
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN NULL;
  END lp_logeo;

/*** SALDOS DE CUENTAS EN GS CON DECIMALES ***/
PROCEDURE lp_cta_gs_con_decimales IS
  CURSOR c_cuentas IS
  -- Ahorros a la Vista
  SELECT nro_cuenta, cod_modalidad, 'Saldo Total: ' || sal_total observacion 
   FROM ah_cta_vistas 
  WHERE cod_moneda = v_cod_mon_local 
    AND sal_total <> TRUNC(sal_total)
  UNION ALL
  SELECT nro_cuenta, cod_modalidad, 'Saldo Retenido: ' || sal_retenido observacion 
   FROM ah_cta_vistas 
  WHERE cod_moneda = v_cod_mon_local 
    AND sal_retenido <> TRUNC(sal_retenido)
  UNION ALL
  SELECT nro_cuenta, cod_modalidad, 'Saldo Bloqueado: ' || sal_bloqueado observacion 
   FROM ah_cta_vistas 
  WHERE cod_moneda = v_cod_mon_local 
    AND sal_bloqueado <> TRUNC(sal_bloqueado)
  UNION ALL
  -- Certificado de Ahorros
  SELECT nro_cuenta, cod_modalidad, 'Saldo Total: ' || sal_total observacion 
   FROM ah_cta_certificados 
  WHERE cod_moneda = v_cod_mon_local 
    AND sal_total <> TRUNC(sal_total)
  UNION ALL
  SELECT nro_cuenta, cod_modalidad, 'Saldo Retenido: ' || sal_retenido observacion 
   FROM ah_cta_certificados 
  WHERE cod_moneda = v_cod_mon_local 
      AND sal_retenido <> TRUNC(sal_retenido)
  UNION ALL
  SELECT nro_cuenta, cod_modalidad, 'Saldo Bloqueado: ' || sal_bloqueado observacion 
   FROM ah_cta_certificados 
  WHERE cod_moneda = v_cod_mon_local 
      AND sal_bloqueado <> TRUNC(sal_bloqueado)
  UNION ALL
  -- Cuentas Corrientes
  SELECT nro_cuenta, cod_modalidad, 'Saldo Total: ' || sal_total observacion 
   FROM cc_cta_corrientes 
  WHERE cod_moneda = v_cod_mon_local 
  AND sal_total <> TRUNC(sal_total)
  UNION ALL
  SELECT nro_cuenta, cod_modalidad, 'Saldo Retenido: ' || sal_retenido observacion 
   FROM cc_cta_corrientes 
  WHERE cod_moneda = v_cod_mon_local 
    AND sal_retenido <> TRUNC(sal_retenido)
  UNION ALL
  SELECT nro_cuenta, cod_modalidad, 'Saldo Bloqueado: ' || sal_bloqueado observacion 
   FROM cc_cta_corrientes 
  WHERE cod_moneda = v_cod_mon_local 
  AND sal_bloqueado <> TRUNC(sal_bloqueado)
  UNION ALL
  -- Cuentas Bancarias
  SELECT nro_cuenta, cod_modalidad, 'Saldo Total: ' || sal_total observacion 
   FROM cc_cta_bancarias 
  WHERE cod_moneda = v_cod_mon_local 
    AND sal_total <> TRUNC(sal_total)
  UNION ALL
  SELECT nro_cuenta, cod_modalidad, 'Saldo Retenido: ' || sal_retenido observacion 
   FROM cc_cta_bancarias 
  WHERE cod_moneda = v_cod_mon_local 
    AND sal_retenido <> TRUNC(sal_retenido)
  UNION ALL
  SELECT nro_cuenta, cod_modalidad, 'Saldo Bloqueado: ' || sal_bloqueado observacion 
   FROM cc_cta_bancarias 
  WHERE cod_moneda = v_cod_mon_local 
    AND sal_bloqueado <> TRUNC(sal_bloqueado)
  UNION ALL
  -- Prestamos
  SELECT nro_cuenta, cod_modalidad, 'Saldo Capital: ' || sal_capital observacion 
   FROM pr_cta_prestamos 
  WHERE cod_moneda = v_cod_mon_local 
    AND sal_capital <> TRUNC(sal_capital)
  UNION ALL
  SELECT nro_cuenta, cod_modalidad, 'Saldo Interes: ' || sal_interes observacion 
   FROM pr_cta_prestamos 
  WHERE cod_moneda = v_cod_mon_local 
    AND sal_interes <> TRUNC(sal_interes)
  UNION ALL
  SELECT nro_cuenta, cod_modalidad, 'Saldo Int. Adelantado: ' || sal_int_adelantado observacion 
    FROM pr_cta_prestamos 
    WHERE cod_moneda = v_cod_mon_local 
      AND sal_int_adelantado <> TRUNC(sal_int_adelantado)
  -- Comex
  UNION ALL
  SELECT nro_cuenta, cod_modalidad, 'Saldo C.Importacion: ' || saldo observacion 
   FROM cx_cta_importaciones 
  WHERE cod_moneda = v_cod_mon_local 
    AND saldo <> TRUNC(saldo)
  UNION ALL
  SELECT nro_cuenta, cod_modalidad, 'Saldo C.Exportacion: ' || saldo observacion 
   FROM cx_cta_exportaciones 
  WHERE cod_moneda = v_cod_mon_local 
    AND saldo <> TRUNC(saldo)
  UNION ALL
  SELECT nro_cuenta, cod_modalidad, 'Saldo Cobranza: ' || saldo observacion 
   FROM cx_cta_cobranzas 
  WHERE cod_moneda = v_cod_mon_local 
    AND saldo <> TRUNC(saldo)
  UNION ALL
  SELECT nro_cuenta, cod_modalidad, 'Monto de Fianza: ' || monto observacion 
   FROM cx_fianzas 
  WHERE cod_moneda = v_cod_mon_local 
    AND monto <> TRUNC(monto)
  UNION ALL
  -- Cuentas de Ahorros Plazos
  SELECT nro_cuenta, cod_modalidad, 'Saldo Total: ' || sal_total observacion 
   FROM ah_cta_plazos 
  WHERE cod_moneda = v_cod_mon_local 
    AND sal_total <> TRUNC(sal_total)
  UNION ALL
  SELECT nro_cuenta, cod_modalidad, 'Saldo Retenido: ' || sal_retenido observacion 
   FROM ah_cta_plazos 
  WHERE cod_moneda = v_cod_mon_local 
    AND sal_retenido <> TRUNC(sal_retenido)
  UNION ALL
  SELECT nro_cuenta, cod_modalidad, 'Saldo Bloqueado: ' || sal_bloqueado observacion 
   FROM ah_cta_plazos 
  WHERE cod_moneda = v_cod_mon_local 
    AND sal_bloqueado <> TRUNC(sal_bloqueado);

  TYPE t_regs IS TABLE OF c_cuentas%ROWTYPE;
  v_regs t_regs;
BEGIN
  OPEN c_cuentas;
  LOOP
    FETCH c_cuentas BULK COLLECT INTO v_regs LIMIT 1000;
    EXIT WHEN v_regs.COUNT = 0;
    FORALL i IN 1..v_regs.COUNT
      INSERT INTO tm_log_controles (fecha, tip_control, clave, cod_modalidad, observacion)
      VALUES (v_fecha, SUBSTR('SALDOS DE CUENTAS EN GS CON DECIMALES', 1, 50), 
            v_regs(i).nro_cuenta, v_regs(i).cod_modalidad, SUBSTR('Cta: ' || v_regs(i).nro_cuenta || ' ' || v_regs(i).observacion, 1, 150));
  END LOOP;
  CLOSE c_cuentas;
END lp_cta_gs_con_decimales;

/*** MONTO DE MOVIMIENTOS EN GS CON DECIMALES ***/
PROCEDURE lp_mov_gs_con_decimales IS
  CURSOR c_movimientos IS
  SELECT nro_cuenta, cod_modalidad, fecha, hora, cod_usuario, nro_secuencia, monto
    FROM ge_movimientos
   WHERE cod_moneda = v_cod_mon_local
     AND monto <> TRUNC(monto);

  TYPE t_regs IS TABLE OF c_movimientos%ROWTYPE;
  v_regs t_regs;
BEGIN
  OPEN c_movimientos;
  LOOP
    FETCH c_movimientos BULK COLLECT INTO v_regs LIMIT 1000;
    EXIT WHEN v_regs.COUNT = 0;
    FORALL i IN 1..v_regs.COUNT
      INSERT INTO tm_log_controles (fecha, tip_control, clave, cod_modalidad, observacion)
      VALUES (v_fecha, 'MONTO DE MOVIMIENTOS EN GS CON DECIMALES',
              SUBSTR(TO_CHAR(v_regs(i).fecha, 'yyyymmdd') || '#' || v_regs(i).hora || '#' || v_regs(i).cod_usuario || '#' || v_regs(i).nro_secuencia, 1, 40),
              v_regs(i).cod_modalidad, SUBSTR('Cta: ' || v_regs(i).nro_cuenta || ' Monto: ' || v_regs(i).monto, 1, 150));
  END LOOP;
  CLOSE c_movimientos;
END lp_mov_gs_con_decimales;

/*** SALDOS DE CUENTAS EN NEGATIVO ***/
PROCEDURE lp_sal_cta_en_negativo IS
  CURSOR c_cuentas IS
  -- Ahorros a la Vista
  SELECT nro_cuenta, cod_modalidad, 'Saldo Total: ' || sal_total observacion 
   FROM ah_cta_vistas 
  WHERE sal_total < 0
  UNION ALL
  SELECT nro_cuenta, cod_modalidad, 'Saldo Retenido: ' || sal_retenido observacion 
   FROM ah_cta_vistas 
  WHERE sal_retenido < 0
  UNION ALL
  SELECT nro_cuenta, cod_modalidad, 'Saldo Bloqueado: ' || sal_bloqueado observacion 
   FROM ah_cta_vistas 
  WHERE sal_bloqueado < 0
  UNION ALL
  -- Certificado de Ahorros
  SELECT nro_cuenta, cod_modalidad, 'Saldo Total: ' || sal_total observacion 
   FROM ah_cta_certificados 
  WHERE sal_total < 0
  UNION ALL
  SELECT nro_cuenta, cod_modalidad, 'Saldo Retenido: ' || sal_retenido observacion 
   FROM ah_cta_certificados 
  WHERE sal_retenido < 0
  UNION ALL
  SELECT nro_cuenta, cod_modalidad, 'Saldo Bloqueado: ' || sal_bloqueado observacion 
   FROM ah_cta_certificados 
  WHERE sal_bloqueado < 0
  UNION ALL
  -- Cuentas Corrientes
  SELECT nro_cuenta, cod_modalidad, 'Saldo Retenido: ' || sal_retenido observacion 
   FROM cc_cta_corrientes 
  WHERE sal_retenido < 0
  UNION ALL
  SELECT nro_cuenta, cod_modalidad, 'Saldo Bloqueado: ' || sal_bloqueado observacion 
   FROM cc_cta_corrientes 
  WHERE sal_bloqueado < 0
  UNION ALL
  -- Cuentas Bancarias
  SELECT nro_cuenta, cod_modalidad, 'Saldo Retenido: ' || sal_retenido observacion 
   FROM cc_cta_bancarias 
  WHERE sal_retenido < 0
  UNION ALL
  SELECT nro_cuenta, cod_modalidad, 'Saldo Bloqueado: ' || sal_bloqueado observacion 
   FROM cc_cta_bancarias 
  WHERE sal_bloqueado < 0
  UNION ALL
  -- Prestamos
  SELECT nro_cuenta, cod_modalidad, 'Saldo Capital: ' || sal_capital observacion 
   FROM pr_cta_prestamos 
  WHERE sal_capital < 0
  UNION ALL
  SELECT nro_cuenta, cod_modalidad, 'Saldo Interes: ' || sal_interes observacion 
   FROM pr_cta_prestamos 
  WHERE sal_interes < 0
  UNION ALL
  SELECT nro_cuenta, cod_modalidad, 'Saldo Int. Adelantado: ' || sal_int_adelantado observacion 
   FROM pr_cta_prestamos 
  WHERE sal_int_adelantado < 0
  -- Comex
  UNION ALL
  SELECT nro_cuenta, cod_modalidad, 'Saldo C.Importacion: ' || saldo observacion 
   FROM cx_cta_importaciones 
  WHERE cod_moneda = v_cod_mon_local 
    AND saldo < 0
  UNION ALL
  SELECT nro_cuenta, cod_modalidad, 'Saldo C.Exportacion: ' || saldo observacion 
   FROM cx_cta_exportaciones 
  WHERE cod_moneda = v_cod_mon_local 
    AND saldo < 0
  UNION ALL
  SELECT nro_cuenta, cod_modalidad, 'Saldo Cobranza: ' || saldo observacion 
   FROM cx_cta_cobranzas 
  WHERE cod_moneda = v_cod_mon_local 
    AND saldo < 0
  UNION ALL
  SELECT nro_cuenta, cod_modalidad, 'Monto de Fianza: ' || monto observacion 
   FROM cx_fianzas 
  WHERE cod_moneda = v_cod_mon_local 
    AND monto < 0
  UNION ALL
  -- Cuentas de Ahorros Plazo
  SELECT nro_cuenta, cod_modalidad, 'Saldo Total: ' || sal_total observacion 
   FROM ah_cta_plazos 
  WHERE sal_total < 0
  UNION ALL
  SELECT nro_cuenta, cod_modalidad, 'Saldo Retenido: ' || sal_retenido observacion 
   FROM ah_cta_plazos 
  WHERE sal_retenido < 0
  UNION ALL
  SELECT nro_cuenta, cod_modalidad, 'Saldo Bloqueado: ' || sal_bloqueado observacion 
   FROM ah_cta_plazos 
  WHERE sal_bloqueado < 0;

  TYPE t_regs IS TABLE OF c_cuentas%ROWTYPE;
  v_regs t_regs;
BEGIN
  OPEN c_cuentas;
  LOOP
    FETCH c_cuentas BULK COLLECT INTO v_regs LIMIT 1000;
    EXIT WHEN v_regs.COUNT = 0;
    FORALL i IN 1..v_regs.COUNT
      INSERT INTO tm_log_controles (fecha, tip_control, clave, cod_modalidad, observacion)
      VALUES (v_fecha, 'SALDOS DE CUENTAS EN NEGATIVO', 
           v_regs(i).nro_cuenta, v_regs(i).cod_modalidad, 
       SUBSTR('Cta: ' || v_regs(i).nro_cuenta || ' ' || v_regs(i).observacion, 1, 150));
  END LOOP;
  CLOSE c_cuentas;
END lp_sal_cta_en_negativo;

/*** DIFERENCIA EN SALDOS RETENIDOS ***/
PROCEDURE lp_dif_sal_retenido IS
  CURSOR c_cuentas IS
  -- Ahorros a la Vista
  SELECT c.nro_cuenta, c.cod_modalidad, c.sal_retenido, NVL(r.tot_retenido, 0) tot_retenido
    FROM ah_cta_vistas c,
         (SELECT nro_cuenta, SUM(sal_retenido) tot_retenido
            FROM ah_retenciones r
           WHERE r.liberado = 'N'
           GROUP BY nro_cuenta) r
   WHERE c.nro_cuenta = r.nro_cuenta(+)
     AND c.sal_retenido <> NVL(r.tot_retenido, 0)
  UNION ALL
  -- Cuentas Corrientes
  SELECT c.nro_cuenta, c.cod_modalidad, c.sal_retenido, NVL(r.tot_retenido, 0) tot_retenido
    FROM cc_cta_corrientes c,
         (SELECT nro_cuenta, SUM(sal_retenido) tot_retenido
            FROM ah_retenciones r
           WHERE r.liberado = 'N'
           GROUP BY nro_cuenta) r
   WHERE c.nro_cuenta = r.nro_cuenta(+)
     AND c.sal_retenido <> NVL(r.tot_retenido, 0);

  TYPE t_regs IS TABLE OF c_cuentas%ROWTYPE;
  v_regs t_regs;
BEGIN
  OPEN c_cuentas;
  LOOP
    FETCH c_cuentas BULK COLLECT INTO v_regs LIMIT 1000;
    EXIT WHEN v_regs.COUNT = 0;
    FORALL i IN 1..v_regs.COUNT
      INSERT INTO tm_log_controles (fecha, tip_control, clave, cod_modalidad, observacion)
      VALUES (v_fecha, 'DIFERENCIA EN SALDOS RETENIDOS', 
              v_regs(i).nro_cuenta, v_regs(i).cod_modalidad,
              SUBSTR('Cta: ' || v_regs(i).nro_cuenta || 
                     ' Saldo Retenido: ' || v_regs(i).sal_retenido || 
                     ' Total Retenido: ' || v_regs(i).tot_retenido || 
                     ' Dif: ' || (v_regs(i).sal_retenido - v_regs(i).tot_retenido), 1, 150));
  END LOOP;
  CLOSE c_cuentas;
END lp_dif_sal_retenido;

/*** DIFERENCIA EN SALDOS BLOQUEADOS ***/
PROCEDURE lp_dif_sal_bloqueado IS
  CURSOR c_cuentas IS
  -- Ahorros a la Vista
  SELECT c.nro_cuenta, c.cod_modalidad, c.sal_bloqueado, NVL(b.tot_bloqueado, 0) tot_bloqueado
    FROM ah_cta_vistas c,
         (SELECT nro_cuenta, SUM(monto) tot_bloqueado 
       FROM ge_bloqueos 
     GROUP BY nro_cuenta) b
   WHERE c.nro_cuenta = b.nro_cuenta(+)
     AND c.sal_bloqueado <> NVL(b.tot_bloqueado, 0)
  UNION ALL
  -- Certificado de Ahorros
  SELECT c.nro_cuenta, c.cod_modalidad, c.sal_bloqueado, NVL(b.tot_bloqueado, 0) tot_bloqueado
    FROM ah_cta_certificados c,
         (SELECT nro_cuenta, SUM(monto) tot_bloqueado 
      FROM ge_bloqueos 
     GROUP BY nro_cuenta) b
   WHERE c.nro_cuenta = b.nro_cuenta(+)
     AND c.sal_bloqueado <> NVL(b.tot_bloqueado, 0)
  UNION ALL
  -- Cuentas Corrientes
  SELECT c.nro_cuenta, c.cod_modalidad, c.sal_bloqueado, NVL(b.tot_bloqueado, 0) tot_bloqueado
    FROM cc_cta_corrientes c,
         (SELECT nro_cuenta, SUM(monto) tot_bloqueado 
      FROM ge_bloqueos 
     GROUP BY nro_cuenta) b
   WHERE c.nro_cuenta = b.nro_cuenta(+)
     AND c.sal_bloqueado <> NVL(b.tot_bloqueado, 0)
  UNION ALL
  -- Cuentas Bancarias
  SELECT c.nro_cuenta, c.cod_modalidad, c.sal_bloqueado, NVL(b.tot_bloqueado, 0) tot_bloqueado
    FROM cc_cta_bancarias c,
         (SELECT nro_cuenta, SUM(monto) tot_bloqueado 
      FROM ge_bloqueos 
     GROUP BY nro_cuenta) b
   WHERE c.nro_cuenta = b.nro_cuenta(+)
     AND c.sal_bloqueado <> NVL(b.tot_bloqueado, 0);

  TYPE t_regs IS TABLE OF c_cuentas%ROWTYPE;
  v_regs t_regs;
BEGIN
  OPEN c_cuentas;
  LOOP
    FETCH c_cuentas BULK COLLECT INTO v_regs LIMIT 1000;
    EXIT WHEN v_regs.COUNT = 0;
    FORALL i IN 1..v_regs.COUNT
      INSERT INTO tm_log_controles (fecha, tip_control, clave, cod_modalidad, observacion)
      VALUES (v_fecha, 'DIFERENCIA EN SALDOS BLOQUEADOS', 
              v_regs(i).nro_cuenta, v_regs(i).cod_modalidad,
              SUBSTR('Cta: ' || v_regs(i).nro_cuenta || 
                     ' Saldo Bloqueado: ' || v_regs(i).sal_bloqueado || 
                     ' Total Bloqueado: ' || v_regs(i).tot_bloqueado || 
                     ' Dif: ' || (v_regs(i).sal_bloqueado - v_regs(i).tot_bloqueado), 1, 150));
  END LOOP;
  CLOSE c_cuentas;
END lp_dif_sal_bloqueado;

/*** DIFERENCIA EN ESTADO BATCH ONLINE ***/
PROCEDURE lp_dif_est_batch_online IS
  CURSOR c_cuentas IS
  -- Ahorros a la Vista
  SELECT nro_cuenta, cod_modalidad, estado, est_batch
    FROM ah_cta_vistas
   WHERE estado <> nvl(est_batch,' ')
   UNION ALL
  -- Certificado de Ahorros
  SELECT nro_cuenta, cod_modalidad, estado, est_batch
    FROM ah_cta_certificados
   WHERE estado <> nvl(est_batch,' ')
   UNION ALL
  -- Cuentas Corrientes
  SELECT nro_cuenta, cod_modalidad, estado, est_batch
    FROM cc_cta_corrientes
   WHERE estado <> nvl(est_batch,' ')
   UNION ALL
  -- Cuentas Bancarias
  SELECT nro_cuenta, cod_modalidad, estado, est_batch
    FROM cc_cta_bancarias
   WHERE estado <> nvl(est_batch,' ')
   UNION ALL
  -- Préstamos
  SELECT nro_cuenta, cod_modalidad, estado, est_batch
    FROM pr_cta_prestamos
   WHERE estado <> nvl(est_batch,' ')
  UNION ALL
  -- Cuentas de Ahorros Plazo
  SELECT nro_cuenta, cod_modalidad, estado, est_batch
    FROM ah_cta_plazos
   WHERE estado <> nvl(est_batch,' ');

  TYPE t_regs IS TABLE OF c_cuentas%ROWTYPE;
  v_regs t_regs;
BEGIN
  OPEN c_cuentas;
  LOOP
    FETCH c_cuentas BULK COLLECT INTO v_regs LIMIT 1000;
    EXIT WHEN v_regs.COUNT = 0;
    FORALL i IN 1..v_regs.COUNT
      INSERT INTO tm_log_controles (fecha, tip_control, clave, cod_modalidad, observacion)     
      VALUES (v_fecha, 'DIFERENCIA EN ESTADO BATCH ONLINE', 
            v_regs(i).nro_cuenta, v_regs(i).cod_modalidad,
              SUBSTR('Cta: ' || v_regs(i).nro_cuenta ||' Estado: ' || v_regs(i).estado ||' Estado Batch: ' || v_regs(i).est_batch, 1, 150));
  END LOOP;
  CLOSE c_cuentas;
END lp_dif_est_batch_online;

/*** DIFERENCIA EN SALDOS BATCH ONLINE ***/
PROCEDURE lp_dif_sal_batch_online IS
  CURSOR c_cuentas IS
  -- Ahorros a la Vista
  SELECT nro_cuenta, cod_modalidad, NVL(sal_total, 0) - NVL(sal_tot_batch, 0) dif, 
  'Saldo Total: ' || sal_total || ' Saldo Total Batch: ' || sal_tot_batch observacion 
  FROM ah_cta_vistas 
  WHERE NVL(sal_total, 0) <> NVL(sal_tot_batch, 0)
  UNION ALL
  SELECT nro_cuenta, cod_modalidad, NVL(sal_retenido, 0) - NVL(sal_ret_batch, 0) dif, 
  'Saldo Retenido: ' || sal_retenido || ' Saldo Retenido Batch: ' || sal_ret_batch observacion 
  FROM ah_cta_vistas 
  WHERE NVL(sal_retenido, 0) <> NVL(sal_ret_batch, 0)
  UNION ALL
  SELECT nro_cuenta, cod_modalidad, NVL(sal_bloqueado, 0) - NVL(sal_blo_batch, 0) dif, 
  'Saldo Bloqueado: ' || sal_bloqueado || ' Saldo Bloqueado Batch: ' || sal_blo_batch observacion 
  FROM ah_cta_vistas 
  WHERE NVL(sal_bloqueado, 0) <> NVL(sal_blo_batch, 0)
  UNION ALL
  -- Certificado de Ahorros
  SELECT nro_cuenta, cod_modalidad, NVL(sal_total, 0) - NVL(sal_tot_batch, 0) dif, 
  'Saldo Total: ' || sal_total || ' Saldo Total Batch: ' || sal_tot_batch observacion 
  FROM ah_cta_certificados 
  WHERE NVL(sal_total, 0) <> NVL(sal_tot_batch, 0)
  UNION ALL
  SELECT nro_cuenta, cod_modalidad, NVL(sal_retenido, 0) - NVL(sal_ret_batch, 0) dif, 
  'Saldo Retenido: ' || sal_retenido || ' Saldo Retenido Batch: ' || sal_ret_batch observacion 
  FROM ah_cta_certificados 
  WHERE NVL(sal_retenido, 0) <> NVL(sal_ret_batch, 0)
  UNION ALL
  SELECT nro_cuenta, cod_modalidad, NVL(sal_bloqueado, 0) - NVL(sal_blo_batch, 0) dif, 
  'Saldo Bloqueado: ' || sal_bloqueado || ' Saldo Bloqueado Batch: ' || sal_blo_batch observacion 
  FROM ah_cta_certificados 
  WHERE NVL(sal_bloqueado, 0) <> NVL(sal_blo_batch, 0)
  UNION ALL
  -- Cuentas Corrientes
  SELECT nro_cuenta, cod_modalidad, NVL(sal_total, 0) - NVL(sal_tot_batch, 0) dif, 
  'Saldo Total: ' || sal_total || ' Saldo Total Batch: ' || sal_tot_batch observacion 
  FROM cc_cta_corrientes 
  WHERE NVL(sal_total, 0) <> NVL(sal_tot_batch, 0)
  UNION ALL
  SELECT nro_cuenta, cod_modalidad, NVL(sal_retenido, 0) - NVL(sal_ret_batch, 0) dif, 
  'Saldo Retenido: ' || sal_retenido || ' Saldo Retenido Batch: ' || sal_ret_batch observacion 
  FROM cc_cta_corrientes 
  WHERE NVL(sal_retenido, 0) <> NVL(sal_ret_batch, 0)
  UNION ALL
  SELECT nro_cuenta, cod_modalidad, NVL(sal_bloqueado, 0) - NVL(sal_blo_batch, 0) dif, 
  'Saldo Bloqueado: ' || sal_bloqueado || ' Saldo Bloqueado Batch: ' || sal_blo_batch observacion 
  FROM cc_cta_corrientes 
  WHERE NVL(sal_bloqueado, 0) <> NVL(sal_blo_batch, 0)
  UNION ALL
  -- Cuentas Bancarias
  SELECT nro_cuenta, cod_modalidad, NVL(sal_total, 0) - NVL(sal_tot_batch, 0) dif, 
  'Saldo Total: ' || sal_total || ' Saldo Total Batch: ' || sal_tot_batch observacion 
  FROM cc_cta_bancarias 
  WHERE NVL(sal_total, 0) <> NVL(sal_tot_batch, 0)
  UNION ALL
  SELECT nro_cuenta, cod_modalidad, NVL(sal_retenido, 0) - NVL(sal_ret_batch, 0) dif, 
  'Saldo Retenido: ' || sal_retenido || ' Saldo Retenido Batch: ' || sal_ret_batch observacion 
  FROM cc_cta_bancarias 
  WHERE NVL(sal_retenido, 0) <> NVL(sal_ret_batch, 0)
  UNION ALL
  SELECT nro_cuenta, cod_modalidad, NVL(sal_bloqueado, 0) - NVL(sal_blo_batch, 0) dif, 
  'Saldo Bloqueado: ' || sal_bloqueado || ' Saldo Bloqueado Batch: ' || sal_blo_batch observacion 
  FROM cc_cta_bancarias 
  WHERE NVL(sal_bloqueado, 0) <> NVL(sal_blo_batch, 0)
  UNION ALL
  -- Prestamos
  SELECT nro_cuenta, cod_modalidad, NVL(sal_capital, 0) - NVL(sal_cap_batch, 0) dif, 
  'Saldo Capital: ' || sal_capital || ' Saldo Capital Batch: ' || sal_cap_batch observacion 
  FROM pr_cta_prestamos 
  WHERE sal_capital <> NVL(sal_cap_batch, 0)
  UNION ALL
  SELECT nro_cuenta, cod_modalidad, NVL(sal_interes, 0) - NVL(sal_int_batch, 0) dif, 
  'Saldo Interes: ' || sal_interes || ' Saldo Interes Batch: ' || sal_int_batch observacion 
  FROM pr_cta_prestamos 
  WHERE sal_interes <> NVL(sal_int_batch, 0)
  UNION ALL
  SELECT nro_cuenta, cod_modalidad, NVL(sal_int_adelantado, 0) - NVL(sal_int_ade_batch, 0) dif, 
  'Saldo Int. Adelantado: ' || sal_int_adelantado || ' Saldo Int. Ade. Batch: ' || sal_int_ade_batch observacion 
  FROM pr_cta_prestamos 
  WHERE NVL(sal_int_adelantado, 0) <> NVL(sal_int_ade_batch, 0)
  UNION ALL
  -- Cuentas de Ahorros Plazo
  SELECT nro_cuenta, cod_modalidad, NVL(sal_total, 0) - NVL(sal_tot_batch, 0) dif, 
  'Saldo Total: ' || sal_total || ' Saldo Total Batch: ' || sal_tot_batch observacion 
  FROM ah_cta_plazos 
  WHERE NVL(sal_total, 0) <> NVL(sal_tot_batch, 0)
  UNION ALL
  SELECT nro_cuenta, cod_modalidad, NVL(sal_retenido, 0) - NVL(sal_ret_batch, 0) dif, 
  'Saldo Retenido: ' || sal_retenido || ' Saldo Retenido Batch: ' || sal_ret_batch observacion 
  FROM ah_cta_plazos 
  WHERE NVL(sal_retenido, 0) <> NVL(sal_ret_batch, 0)
  UNION ALL
  SELECT nro_cuenta, cod_modalidad, NVL(sal_bloqueado, 0) - NVL(sal_blo_batch, 0) dif, 
  'Saldo Bloqueado: ' || sal_bloqueado || ' Saldo Bloqueado Batch: ' || sal_blo_batch observacion 
  FROM ah_cta_plazos 
  WHERE NVL(sal_bloqueado, 0) <> NVL(sal_blo_batch, 0);

  TYPE t_regs IS TABLE OF c_cuentas%ROWTYPE;
  v_regs t_regs;
BEGIN
  OPEN c_cuentas;
  LOOP
    FETCH c_cuentas BULK COLLECT INTO v_regs LIMIT 1000;
    EXIT WHEN v_regs.COUNT = 0;
    FORALL i IN 1..v_regs.COUNT
      INSERT INTO tm_log_controles (fecha, tip_control, clave, cod_modalidad, observacion)
      VALUES (v_fecha, 'DIFERENCIA EN SALDOS BATCH ONLINE', 
            v_regs(i).nro_cuenta, v_regs(i).cod_modalidad,
              SUBSTR('Cta: ' || v_regs(i).nro_cuenta || ' ' || v_regs(i).observacion || ' Dif. : ' || v_regs(i).dif, 1, 150));
  END LOOP;
  CLOSE c_cuentas;
END lp_dif_sal_batch_online;

/*** MOVIMIENTOS EN CUENTAS NO ACTIVAS ***/
PROCEDURE lp_mov_cta_no_activas IS
  CURSOR c_movimientos IS
  -- Ahorros a la Vista
  SELECT m.nro_cuenta, m.cod_modalidad, m.fecha, m.hora, m.cod_usuario, m.nro_secuencia, m.monto, c.estado
    FROM ge_movimientos m, ah_cta_vistas c, ge_transacciones t
   WHERE m.nro_cuenta = c.nro_cuenta
     AND c.estado IN ('A','X')
     AND m.cod_modulo = t.cod_modulo
     AND m.cod_modalidad = t.cod_modalidad
     AND m.cod_transaccion = t.cod_transaccion
     AND (t.afecta = 'S' OR (t.afecta = 'R' AND t.tipo = 'C'))
     AND m.estado = 'N'
     AND m.reversado = 'N'
  UNION ALL
  -- Certificado de Ahorros
  SELECT m.nro_cuenta, m.cod_modalidad, m.fecha, m.hora, m.cod_usuario, m.nro_secuencia, m.monto, c.estado
    FROM ge_movimientos m, ah_cta_certificados c, ge_transacciones t
   WHERE m.nro_cuenta = c.nro_cuenta
     AND c.estado IN ('A','X')
     AND m.cod_modulo = t.cod_modulo
     AND m.cod_modalidad = t.cod_modalidad
     AND m.cod_transaccion = t.cod_transaccion
     AND (t.afecta = 'S' OR (t.afecta = 'R' AND t.tipo = 'C'))
     AND m.estado = 'N'
     AND m.reversado = 'N'
  UNION ALL
  -- Cuentas Corrientes
  SELECT m.nro_cuenta, m.cod_modalidad, m.fecha, m.hora, m.cod_usuario, m.nro_secuencia, m.monto, c.estado
    FROM ge_movimientos m, cc_cta_corrientes c, ge_transacciones t
   WHERE m.nro_cuenta = c.nro_cuenta
     AND c.estado IN ('A','X')
     AND m.cod_modulo = t.cod_modulo
     AND m.cod_modalidad = t.cod_modalidad
     AND m.cod_transaccion = t.cod_transaccion
     AND (t.afecta = 'S' OR (t.afecta = 'R' AND t.tipo = 'C'))
     AND m.estado = 'N'
     AND m.reversado = 'N'
  UNION ALL
  -- Cuentas Bancarias
  SELECT m.nro_cuenta, m.cod_modalidad, m.fecha, m.hora, m.cod_usuario, m.nro_secuencia, m.monto, c.estado
    FROM ge_movimientos m, cc_cta_bancarias c, ge_transacciones t
   WHERE m.nro_cuenta = c.nro_cuenta
     AND c.estado IN ('A','X')
     AND m.cod_modulo = t.cod_modulo
     AND m.cod_modalidad = t.cod_modalidad
     AND m.cod_transaccion = t.cod_transaccion
     AND (t.afecta = 'S' OR (t.afecta = 'R' AND t.tipo = 'C'))
     AND m.estado = 'N'
     AND m.reversado = 'N'
  UNION ALL
  -- Cuentas de Ahorros Plazos
  SELECT m.nro_cuenta, m.cod_modalidad, m.fecha, m.hora, m.cod_usuario, m.nro_secuencia, m.monto, c.estado
    FROM ge_movimientos m, ah_cta_plazos c, ge_transacciones t
   WHERE m.nro_cuenta = c.nro_cuenta
     AND c.estado IN ('A','X')
     AND m.cod_modulo = t.cod_modulo
     AND m.cod_modalidad = t.cod_modalidad
     AND m.cod_transaccion = t.cod_transaccion
     AND (t.afecta = 'S' OR (t.afecta = 'R' AND t.tipo = 'C'))
     AND m.estado = 'N'
     AND m.reversado = 'N';

  TYPE t_regs IS TABLE OF c_movimientos%ROWTYPE;
  v_regs t_regs;
BEGIN
  OPEN c_movimientos;
  LOOP
    FETCH c_movimientos BULK COLLECT INTO v_regs LIMIT 1000;
    EXIT WHEN v_regs.COUNT = 0;
    FORALL i IN 1..v_regs.COUNT
      INSERT INTO tm_log_controles (fecha, tip_control, clave, cod_modalidad, observacion)   
     VALUES(v_fecha, 'MOVIMIENTOS EN CUENTAS NO ACTIVAS',
            SUBSTR(TO_CHAR(v_regs(i).fecha, 'yyyymmdd') || '#' || v_regs(i).hora || '#' || v_regs(i).cod_usuario || '#' || v_regs(i).nro_secuencia, 1, 40),
            v_regs(i).cod_modalidad,
            SUBSTR('Cta: ' || v_regs(i).nro_cuenta ||' Monto: ' || v_regs(i).monto ||' Estado: ' || v_regs(i).estado, 1, 150));
  END LOOP;
  CLOSE c_movimientos;
END lp_mov_cta_no_activas;

/* -- CDA con estado Normal pero sin cupones impresos -- */
PROCEDURE lp_cda_sin_cup_emitidos IS
  CURSOR c_registros IS
  SELECT 'CDA EN ESTADO NORMAL Y SIN CUPONES EMITIDOS' tip_control,
         a.nro_cuenta nro_cuenta, c.cod_modalidad cod_modalidad,
         'Cuenta: ' || a.nro_cuenta || ' Cantidad de Cupones: ' observacion, COUNT(DISTINCT(a.nro_cupon)) cantidad
    FROM ah_cupones a, ge_cuentas c
   WHERE a.nro_cuenta = c.nro_cuenta
     AND a.estado = 'C'
     AND EXISTS (SELECT 0
                   FROM ah_cta_certificados b
                  WHERE b.nro_cuenta = a.nro_cuenta
                    AND b.estado = 'N')
   GROUP BY 'CDA EN ESTADO NORMAL Y SIN CUPONES EMITIDOS', a.nro_cuenta, c.cod_modalidad,
            'Cuenta: ' || a.nro_cuenta || ' Cantidad de Cupones: ';

  TYPE t_regs IS TABLE OF c_registros%ROWTYPE;
  v_regs t_regs;
BEGIN
  OPEN c_registros;
  LOOP
    FETCH c_registros BULK COLLECT INTO v_regs LIMIT 1000;
    EXIT WHEN v_regs.COUNT = 0;
    FORALL i IN 1..v_regs.COUNT
      INSERT INTO tm_log_controles (fecha, tip_control, clave, cod_modalidad, observacion)
     VALUES (v_fecha, SUBSTR(v_regs(i).tip_control, 1, 50), 
           v_regs(i).nro_cuenta, v_regs(i).cod_modalidad, 
             SUBSTR(v_regs(i).observacion || v_regs(i).cantidad, 1, 150));
  END LOOP;
  CLOSE c_registros;
END lp_cda_sin_cup_emitidos;

/* PRESTAMOS CANCELADOS CON SALDO DE DEVENGADO EN SUSPENSO */
PROCEDURE lp_pres_can_con_dev_suspenso IS
  CURSOR c_registros IS
  SELECT 'PRESTAMO CANCELADO CON SALDO DEV. EN SUSPENSO' tip_control,
         nro_cuenta, cod_modalidad,
         'Cuenta: ' || nro_cuenta || ' Devengado en Suspenso: ' || dev_suspenso observacion
    FROM pr_cta_prestamos
   WHERE estado = 'N'
     AND dev_suspenso <> 0;

  TYPE t_regs IS TABLE OF c_registros%ROWTYPE;
  v_regs t_regs;
BEGIN
  OPEN c_registros;
  LOOP
    FETCH c_registros BULK COLLECT INTO v_regs LIMIT 1000;
    EXIT WHEN v_regs.COUNT = 0;
    FORALL i IN 1..v_regs.COUNT
      INSERT INTO tm_log_controles (fecha, tip_control, clave, cod_modalidad, observacion)      
    VALUES(v_fecha, SUBSTR(v_regs(i).tip_control, 1, 50), 
         v_regs(i).nro_cuenta, v_regs(i).cod_modalidad, 
           SUBSTR(v_regs(i).observacion, 1, 150));
  END LOOP;
  CLOSE c_registros;
END lp_pres_can_con_dev_suspenso;

/* DIFERENCIA DE DEVENGADOS ENTRE PRESTAMOS Y CUOTAS */
PROCEDURE lp_dif_dev_prest_cuotas IS
  CURSOR c_registros IS
  SELECT 'DIFERENCIA DE DEVENGADOS ENTRE PRESTAMOS Y CUOTAS' tip_control,
         p.nro_cuenta, p.cod_modalidad,
         'Cuenta: ' || p.nro_cuenta || ' Dev.Acum.Prest.: ' || p.dev_acumulado ||
         ' Dev.Acum.Cuotas: ' || cu.dev_acu_cuota || ' Dif.: ' || (p.dev_acumulado - cu.dev_acu_cuota) observacion
    FROM pr_cta_prestamos p,
         (SELECT nro_cuenta, SUM(dev_acumulado) dev_acu_cuota
            FROM pr_cuotas
           WHERE nro_cuota > 0
           GROUP BY nro_cuenta) cu
   WHERE p.nro_cuenta = cu.nro_cuenta
     AND (p.estado NOT IN ('N','I') OR p.estado = 'N' AND p.fec_cancelacion >= TO_DATE('01/01/2007', 'dd/mm/yyyy'))
     AND p.dev_acumulado <> cu.dev_acu_cuota
  UNION ALL
  SELECT 'DIFERENCIA DE DEVENGADOS ENTRE PRESTAMOS Y CUOTAS' tip_control,
         p.nro_cuenta, p.cod_modalidad,
         'Cuenta: ' || p.nro_cuenta || ' Dev.Susp.Prest.: ' || p.dev_suspenso ||
         ' Dev.Susp.Cuotas: ' || cu.dev_sus_cuota || ' Dif.: ' || (p.dev_suspenso - cu.dev_sus_cuota) observacion
    FROM pr_cta_prestamos p,
         (SELECT nro_cuenta, SUM(dev_suspenso) dev_sus_cuota
            FROM pr_cuotas
           WHERE nro_cuota > 0
           GROUP BY nro_cuenta) cu
   WHERE p.nro_cuenta = cu.nro_cuenta
     AND (p.estado NOT IN ('N','I') OR p.estado = 'N' AND p.fec_cancelacion >= TO_DATE('01/01/2007', 'dd/mm/yyyy'))
     AND p.dev_suspenso <> cu.dev_sus_cuota;

  TYPE t_regs IS TABLE OF c_registros%ROWTYPE;
  v_regs t_regs;
BEGIN
  OPEN c_registros;
  LOOP
    FETCH c_registros BULK COLLECT INTO v_regs LIMIT 1000;
    EXIT WHEN v_regs.COUNT = 0;
    FORALL i IN 1..v_regs.COUNT
      INSERT INTO tm_log_controles (fecha, tip_control, clave, cod_modalidad, observacion)
      VALUES (v_fecha, SUBSTR(v_regs(i).tip_control, 1, 50), 
            v_regs(i).nro_cuenta, v_regs(i).cod_modalidad,
              SUBSTR(v_regs(i).observacion, 1, 150));
  END LOOP;
  CLOSE c_registros;
END lp_dif_dev_prest_cuotas;

/* PRESTAMOS CON DIFERENCIA EN INTERES A DEVENGAR */
PROCEDURE lp_pres_dif_val_int_devengar IS
  CURSOR c_registros IS
  SELECT 'PRESTAMOS CON DIFERENCIA EN INTERES A DEVENGAR' tip_control,
         p.nro_cuenta, p.cod_modalidad,
         'Cuenta: ' || p.nro_cuenta || ' Int.a Devengar: ' || ROUND(p.val_int_devengar, 2) ||
         ' Int.a Dev.Calc.: ' || (x.mto_interes - p.dev_acumulado - x.mto_int_descontado) ||
         ' Dif: ' || (p.val_int_devengar - (x.mto_interes - p.dev_acumulado - x.mto_int_descontado)) observacion
    FROM pr_cta_prestamos p,
         (SELECT nro_cuenta,
                 SUM(c.mto_interes + NVL(c.mto_int_documentado, 0)) mto_interes,
                 SUM(c.mto_int_descontado) mto_int_descontado
            FROM pr_cuotas c
           WHERE c.nro_cuota > 0
           GROUP BY c.nro_cuenta) x
   WHERE p.nro_cuenta = x.nro_cuenta
     AND p.cod_modalidad NOT IN (670, 671)
     AND p.val_int_devengar - (x.mto_interes - p.dev_acumulado - x.mto_int_descontado) <> 0
     AND (p.estado NOT IN ('N','I') OR p.estado = 'N' AND p.fec_cancelacion >= TO_DATE('01/01/2007', 'dd/mm/yyyy'));

  TYPE t_regs IS TABLE OF c_registros%ROWTYPE;
  v_regs t_regs;
BEGIN
  OPEN c_registros;
  LOOP
    FETCH c_registros BULK COLLECT INTO v_regs LIMIT 1000;
    EXIT WHEN v_regs.COUNT = 0;
    FORALL i IN 1..v_regs.COUNT
      INSERT INTO tm_log_controles (fecha, tip_control, clave, cod_modalidad, observacion)
      VALUES (v_fecha, SUBSTR(v_regs(i).tip_control, 1, 50), 
            v_regs(i).nro_cuenta, v_regs(i).cod_modalidad,
              SUBSTR(v_regs(i).observacion, 1, 150));
  END LOOP;
  CLOSE c_registros;
END lp_pres_dif_val_int_devengar;

/* CUENTAS CON CLIENTE PRINCIPAL CON PROBLEMA */
PROCEDURE lp_ver_clte_princ_de_ctas IS
  CURSOR c_registros IS
  SELECT cta.nro_cuenta, cta.cod_modalidad, COUNT(*) cant
    FROM ge_cuentas cta,
         ge_est_cuentas est,
         ge_cta_clientes cli
   WHERE est.cod_modulo = cta.cod_modulo
     AND est.cod_modalidad = cta.cod_modalidad
     AND est.estado = cta.estado
     AND est.activo = 'S'
     AND cli.nro_cuenta = cta.nro_cuenta
     AND cli.relacion = 'P'
   GROUP BY cta.nro_cuenta, cta.cod_modalidad
  HAVING COUNT(*) <> 1;

  TYPE t_regs IS TABLE OF c_registros%ROWTYPE;
  v_regs t_regs;
BEGIN
  OPEN c_registros;
  LOOP
    FETCH c_registros BULK COLLECT INTO v_regs LIMIT 1000;
    EXIT WHEN v_regs.COUNT = 0;
    FORALL i IN 1..v_regs.COUNT
      INSERT INTO tm_log_controles (fecha, tip_control, clave, cod_modalidad, observacion)
      VALUES (v_fecha, 'CUENTAS CON CLIENTE PRINCIPAL CON PROBLEMA', 
            v_regs(i).nro_cuenta, v_regs(i).cod_modalidad,
              SUBSTR('Cuenta ' || v_regs(i).nro_cuenta || ' tiene la cantidad de ' || TO_CHAR(v_regs(i).cant) || ' como cliente principal', 1, 150));
  END LOOP;
  CLOSE c_registros;
END lp_ver_clte_princ_de_ctas;

/* TASAS PERSONALIZADAS Y/O GENERALES INCONSISTENTES */
PROCEDURE lp_ver_tasas IS
  CURSOR c_registros IS
    select 'la Tasa Fija ' tipo_tabla, 'Se debe ingresar Valor Tarifa y/o Mínimo y/o Máximo o bien Spread. ' tipo_error,
           tf.cod_tasa, t.tip_valor, t.tipo, t.aplicar,  
           to_char(tf.fec_vigencia,'DD/MM/YYYY') fec_vigencia, tf.cod_oficina, tf.cod_moneda,
           tf.cod_modulo, tf.cod_modalidad, tf.cod_sub_modalidad, t.descripcion ,
           tf.nro_cuenta, tf.cod_persona, 
           tf.val_maximo, tf.val_minimo, tf.val_base, tf.val_tasa, NULL val_hasta, 
           tf.val_extension
      from ge_tasas t, ge_tas_fechas tf
     where t.cod_tasa = tf.cod_tasa
       and val_tasa is null and val_extension is null and val_minimo is null and val_maximo is null
    union all
    select 'la Tasa Fija ' tipo_tabla, 'Se debe ingresar Valor Tarifa o Spread. ' tipo_error,
           tf.cod_tasa, t.tip_valor, t.tipo, t.aplicar,  
           to_char(tf.fec_vigencia,'DD/MM/YYYY') fec_vigencia, tf.cod_oficina, tf.cod_moneda,
           tf.cod_modulo, tf.cod_modalidad, tf.cod_sub_modalidad, t.descripcion ,
           tf.nro_cuenta, tf.cod_persona, 
           tf.val_maximo, tf.val_minimo, tf.val_base, tf.val_tasa, NULL val_hasta, 
           tf.val_extension
      from ge_tasas t, ge_tas_fechas tf
     where t.cod_tasa = tf.cod_tasa
       and val_tasa is not null and val_extension is not null
   union all
    select 'la Tasa Fija ' tipo_tabla, 'Se debe ingresar por lo menos Valor Tarifa a nivel GENERAL. ' tipo_error,
           tf.cod_tasa, t.tip_valor, t.tipo, t.aplicar,  
           to_char(tf.fec_vigencia,'DD/MM/YYYY') fec_vigencia, tf.cod_oficina, tf.cod_moneda,
           tf.cod_modulo, tf.cod_modalidad, tf.cod_sub_modalidad, t.descripcion ,
           tf.nro_cuenta, tf.cod_persona, 
           tf.val_maximo, tf.val_minimo, tf.val_base, tf.val_tasa, NULL val_hasta, 
           tf.val_extension
      from ge_tasas t, ge_tas_fechas tf
     where t.cod_tasa = tf.cod_tasa
       and val_tasa is null and nro_cuenta is null and cod_persona is null
   union all
          select 'la Tasa Fija ' tipo_tabla, 'Si tiene Spread no puede tener o Valor Máximo o Valor Mínimo. ' tipo_error,
           tf.cod_tasa, t.tip_valor, t.tipo, t.aplicar,  
           to_char(tf.fec_vigencia,'DD/MM/YYYY') fec_vigencia, tf.cod_oficina, tf.cod_moneda,
           tf.cod_modulo, tf.cod_modalidad, tf.cod_sub_modalidad, t.descripcion ,
           tf.nro_cuenta, tf.cod_persona, 
           tf.val_maximo, tf.val_minimo, tf.val_base, tf.val_tasa, NULL val_hasta, 
           tf.val_extension
      from ge_tasas t, ge_tas_fechas tf
     where t.cod_tasa = tf.cod_tasa
       and val_extension is not null and ( val_minimo is not null or val_maximo is not null )    
   union all
    select 'la Tasa Variable ' tipo_tabla, 'Se debe ingresar Valor Tarifa y/o Hasta o bien Spread. ' tipo_error,
           tr.cod_tasa, tt.tip_valor, tt.tipo, tt.aplicar,  
           to_char(tr.fec_vigencia,'DD/MM/YYYY') fec_vigencia, tr.cod_oficina, tr.cod_moneda,
           tr.cod_modulo, tr.cod_modalidad, tr.cod_sub_modalidad, tt.descripcion ,
           tr.nro_cuenta, tr.cod_persona, 
           NULL val_maximo, NULL val_minimo, NULL val_base, tr.val_tasa, tr.val_hasta, 
           tr.val_extension
      from ge_tasas tt, ge_tas_rangos tr
     where tt.cod_tasa = tr.cod_tasa
       and val_tasa is null and val_extension is null and val_hasta is null           
   union all
    select 'la Tasa Variable ' tipo_tabla, 'Se debe ingresar Valor Tarifa o Spread. ' tipo_error,
           tr.cod_tasa, tt.tip_valor, tt.tipo, tt.aplicar,  
           to_char(tr.fec_vigencia,'DD/MM/YYYY') fec_vigencia, tr.cod_oficina, tr.cod_moneda,
           tr.cod_modulo, tr.cod_modalidad, tr.cod_sub_modalidad, tt.descripcion ,
           tr.nro_cuenta, tr.cod_persona, 
           NULL val_maximo, NULL val_minimo, NULL val_base, tr.val_tasa, tr.val_hasta, 
           tr.val_extension
      from ge_tasas tt, ge_tas_rangos tr
     where tt.cod_tasa = tr.cod_tasa
       and val_tasa is not null and val_extension is not null
   union all
    select 'la Tasa Variable ' tipo_tabla, 'Se debe ingresar por lo menos Valor Tarifa a nivel GENERAL. ' tipo_error,
           tr.cod_tasa, tt.tip_valor, tt.tipo, tt.aplicar,  
      to_char(tr.fec_vigencia,'DD/MM/YYYY') fec_vigencia, tr.cod_oficina, tr.cod_moneda,     
      tr.cod_modulo, tr.cod_modalidad, tr.cod_sub_modalidad, tt.descripcion ,
            tr.nro_cuenta, tr.cod_persona,     
           NULL val_maximo, NULL val_minimo, NULL val_base, tr.val_tasa, tr.val_hasta, 
           tr.val_extension
      from ge_tasas tt, ge_tas_rangos tr
     where tt.cod_tasa = tr.cod_tasa
       and val_tasa is null and nro_cuenta is null and cod_persona is null
     order by 2,1;
     
     TYPE t_regs IS TABLE OF c_registros%ROWTYPE;
     v_regs t_regs;
 
BEGIN
  OPEN c_registros;
  LOOP
    FETCH c_registros BULK COLLECT INTO v_regs LIMIT 1000;
    EXIT WHEN v_regs.COUNT = 0;
    FORALL i IN 1..v_regs.COUNT
      INSERT INTO tm_log_controles (fecha, tip_control, clave, cod_modalidad, observacion)
    VALUES(v_fecha,'TASAS PERSONALIZADAS Y/O GENERALES INCONSISTENTES',
           SUBSTR(TO_CHAR(v_regs(i).cod_tasa) || '#' || v_regs(i).fec_vigencia, 1, 40), v_regs(i).cod_modalidad,
           SUBSTR(v_regs(i).tipo_error || 'Verifique ' || v_regs(i).tipo_tabla || v_regs(i).cod_tasa || ' con vigencia ' || v_regs(i).fec_vigencia ||
                     DECODE(v_regs(i).cod_oficina,       NULL, ' ' , ' Ofic. '    || v_regs(i).cod_oficina       || ' ') ||
                     DECODE(v_regs(i).cod_moneda,        NULL, ' ' , ' Mon. '     || v_regs(i).cod_moneda        || ' ') ||
                     DECODE(v_regs(i).cod_modulo,        NULL, ' ' , ' Mod. '     || v_regs(i).cod_modulo        || ' ') ||
                     DECODE(v_regs(i).cod_modalidad,     NULL, ' ' , ' Mad. '     || v_regs(i).cod_modalidad     || ' ') ||
                     DECODE(v_regs(i).cod_sub_modalidad, NULL, ' ' , ' Sub-Mad. ' || v_regs(i).cod_sub_modalidad || ' ') ||
                     DECODE(v_regs(i).nro_cuenta,        NULL, ' ' , ' Cta. '     || v_regs(i).nro_cuenta        || ' ') ||
                     DECODE(v_regs(i).cod_persona,       NULL, ' ' , ' Pers. '    || v_regs(i).cod_persona), 1, 500));
  END LOOP;
  CLOSE c_registros;
END lp_ver_tasas;

/* INCONSISTENCIA DE EXTRACTOS O EXTRACTOS DESCUADRADOS */
PROCEDURE lp_descu_extractos IS
  v_fec_desde DATE;
BEGIN
  pag_cal.pr_obt_dat_calendar(pae_cnf.g_cod_modulo);
  IF v_fec_actual <> pag_cal.G_ULT_DIA_MES_HABIL THEN
      v_fec_desde := TRUNC(ADD_MONTHS(pag_cal.fu_obt_fec_actual(1), -1), 'mm');
      v_hor_ini := TO_CHAR(SYSDATE, 'hh24:mi:ss');
      -- Inserta Extractos inconsistentes de CTA.AHORROS VISTA.
      INSERT INTO tm_log_controles (fecha, tip_control, clave, cod_modalidad, observacion)
      SELECT v_fecha, 'EXTRACTOS DESCUADRADOS O INCONSISTENTES' tip_control,
             a.nro_cuenta,
             a.cod_modalidad,
             SUBSTR('Cuenta:' || a.nro_cuenta || ' Est:' || a.estado || ' Mon:' || cod_moneda ||
             ' Sal Extr:' || TO_CHAR(NVL(sal_ult_extracto, 0) + NVL(creditos, 0) - NVL(debitos, 0)) ||
             ' Dife:' || TO_CHAR(NVL(sal_ult_extracto, 0) + NVL(creditos, 0) - NVL(debitos, 0) - (NVL(sal_tot_batch, 0) - NVL(sal_ret_batch, 0))) ||
             ' Sal Ante:' || TO_CHAR(NVL(sal_ult_extracto, 0)) ||
             ' Sal Actu:' || TO_CHAR((NVL(sal_tot_batch, 0) - NVL(sal_ret_batch, 0))) ||
             ' Cred:' || TO_CHAR(NVL(creditos, 0)) ||
             ' Deb :' || TO_CHAR(NVL(debitos, 0)), 1, 150) observacion
        FROM ah_cta_vistas a,
             (SELECT AV.NRO_CUENTA NRO_CUENTA,
                     SUM(DECODE(TR.COD_TRANSACCION,
                                515, 0,
                                560, 0,
                                DECODE(TR.TIPO,
                                       'D', NVL(MV.MONTO, 0),
                                       0))) DEBITOS,
                     SUM(DECODE(TR.COD_TRANSACCION,
                                515, NVL(MV.MONTO, 0),
                                560, NVL(MV.MONTO, 0),
                                DECODE(TR.TIPO,
                                       'C', NVL(MV.MONTO, 0),
                                       0))) CREDITOS
                FROM GE_TRANSACCIONES TR, AH_MOVIMIENTOS_HIS MV, AH_CTA_VISTAS AV,
                     GE_ARQ_CLIENTES GC, GE_ARQ_CLI_CUENTAS CC
               WHERE mv.NRO_CUENTA = AV.NRO_CUENTA
                 AND GC.COD_PERSONA = CC.COD_PERSONA
                 AND GC.COD_EXTRACTO = CC.COD_EXTRACTO
                 AND GC.FEC_EXTRACTO = CC.FEC_EXTRACTO
                 AND UPPER(GC.FRE_EXTRACTO) = CC.FRE_EXTRACTO
                 AND CC.NRO_CUENTA = AV.NRO_CUENTA
                 AND GC.FRE_EXTRACTO = LOWER(GC.FRE_EXTRACTO)
                 AND AV.ESTADO NOT IN ('C','X','A','P')
                 AND mv.FECHA >= v_fec_desde
                 AND mv.FECHA <= v_fec_actual
                 AND MV.REVERSADO = 'N'
                 AND MV.ESTADO = 'N'
                 AND MV.COD_MODULO = TR.COD_MODULO
                 AND MV.COD_MODALIDAD = TR.COD_MODALIDAD
                 AND MV.COD_TRANSACCION = TR.COD_TRANSACCION
                 AND TR.VE_CLIENTE = 'S'
                 AND TR.TIPO IN ('C', 'D')
               GROUP BY AV.NRO_CUENTA) b
       WHERE b.nro_cuenta = a.nro_cuenta
         AND a.estado NOT IN ('C','X','A','P')
         AND NVL(a.sal_ult_extracto, 0) + NVL(b.creditos, 0) - NVL(b.debitos, 0) <>
             (NVL(a.sal_tot_batch, 0) - NVL(a.sal_ret_batch, 0));
        
      v_hor_fin := TO_CHAR(SYSDATE, 'hh24:mi:ss');
      lp_logeo('lp_descu_extractos_ah', v_hor_ini, v_hor_fin);

      -- Inserta Extractos inconsistentes de CTA.CTE.
      v_hor_ini := TO_CHAR(SYSDATE, 'hh24:mi:ss');
      INSERT INTO tm_log_controles (fecha, tip_control, clave, cod_modalidad, observacion)
      SELECT v_fecha, 'EXTRACTOS DESCUADRADOS O INCONSISTENTES' tip_control,
             a.nro_cuenta,
             a.cod_modalidad,
             SUBSTR('Cuenta:' || a.nro_cuenta || ' Est:' || a.estado || ' Mon:' || cod_moneda ||
             ' Sal Extr:' || TO_CHAR(NVL(sal_ult_extracto, 0) + NVL(creditos, 0) - NVL(debitos, 0)) ||
             ' Dife:' || TO_CHAR(NVL(sal_ult_extracto, 0) + NVL(creditos, 0) - NVL(debitos, 0) - (NVL(sal_tot_batch, 0) - NVL(sal_ret_batch, 0))) ||
             ' Sal Ante:' || TO_CHAR(NVL(sal_ult_extracto, 0)) ||
             ' Sal Actu:' || TO_CHAR((NVL(sal_tot_batch, 0) - NVL(sal_ret_batch, 0))) ||
             ' Cred:' || TO_CHAR(NVL(creditos, 0)) ||
             ' Deb :' || TO_CHAR(NVL(debitos, 0)), 1, 150) observacion
        FROM CC_CTA_CORRIENTES a,
             (SELECT av.nro_cuenta nro_cuenta,
                     SUM(DECODE(tr.cod_transaccion,
                                515, 0,
                                560, 0,
                                DECODE(tr.TIPO,
                                       'D', NVL(mv.MONTO, 0),
                                       0))) debitos,
                     SUM(DECODE(tr.cod_transaccion,
                                515, NVL(mv.MONTO, 0),
                                560, NVL(mv.MONTO, 0),
                                DECODE(tr.TIPO,
                                       'C', NVL(mv.MONTO, 0),
                                       0))) creditos
                FROM GE_TRANSACCIONES tr, CC_MOVIMIENTOS_HIS mv, CC_CTA_CORRIENTES AV, 
                     GE_ARQ_CLIENTES GC, GE_ARQ_CLI_CUENTAS CC
               WHERE mv.NRO_CUENTA = AV.NRO_CUENTA
                 AND GC.COD_PERSONA = CC.COD_PERSONA
                 AND GC.COD_EXTRACTO = CC.COD_EXTRACTO
                 AND GC.FEC_EXTRACTO = CC.FEC_EXTRACTO
                 AND UPPER(GC.FRE_EXTRACTO) = CC.FRE_EXTRACTO
                 AND CC.NRO_CUENTA = AV.NRO_CUENTA
                 AND GC.FRE_EXTRACTO = LOWER(GC.FRE_EXTRACTO)
                 AND AV.ESTADO NOT IN ('C','X','A','P')
                 AND mv.FECHA >= v_fec_desde
                 AND mv.FECHA <= v_fec_actual
                 AND mv.REVERSADO = 'N'
                 AND mv.ESTADO = 'N'
                 AND mv.COD_MODULO = tr.COD_MODULO
                 AND mv.COD_MODALIDAD = tr.COD_MODALIDAD
                 AND mv.COD_TRANSACCION = tr.COD_TRANSACCION
                 AND tr.VE_CLIENTE = 'S'
                 AND tr.TIPO IN ('C', 'D')
               GROUP BY av.nro_cuenta) b
       WHERE b.nro_cuenta = a.nro_cuenta
         AND a.estado NOT IN ('C','X','A','P')
         AND NVL(a.sal_ult_extracto, 0) + NVL(b.creditos, 0) - NVL(b.debitos, 0) <>
             (NVL(a.sal_tot_batch, 0) - NVL(a.sal_ret_batch, 0));
             
      v_hor_fin := TO_CHAR(SYSDATE, 'hh24:mi:ss');
      lp_logeo('lp_descu_extractos_cc', v_hor_ini, v_hor_fin);
  END IF;
END lp_descu_extractos;

/* --- BLOQUE PRINCIPAL --- */
BEGIN
  pre_ini_aplicacion;
  pae_cnf.g_cod_modulo := 1;
  pag_cal.PR_OBT_DAT_CALENDAR(1);

  v_est_modulo := PAE_CNF.FU_OBT_EST_MODULO(1);

  v_hor_ini := TO_CHAR(SYSDATE, 'hh24:mi:ss');
  DELETE FROM tm_log_controles WHERE fecha = v_fecha;
  v_hor_fin := TO_CHAR(SYSDATE, 'hh24:mi:ss');
  lp_logeo('BORRADO TM_LOG_CONTROLES', v_hor_ini, v_hor_fin);

  -- Procesos de Controles
  v_hor_ini := TO_CHAR(SYSDATE, 'hh24:mi:ss');
  lp_cta_gs_con_decimales;
  v_hor_fin := TO_CHAR(SYSDATE, 'hh24:mi:ss');
  lp_logeo('lp_cta_gs_con_decimales', v_hor_ini, v_hor_fin);

  v_hor_ini := TO_CHAR(SYSDATE, 'hh24:mi:ss');
  lp_mov_gs_con_decimales;
  v_hor_fin := TO_CHAR(SYSDATE, 'hh24:mi:ss');
  lp_logeo('lp_mov_gs_con_decimales', v_hor_ini, v_hor_fin);

  v_hor_ini := TO_CHAR(SYSDATE, 'hh24:mi:ss');
  lp_sal_cta_en_negativo;
  v_hor_fin := TO_CHAR(SYSDATE, 'hh24:mi:ss');
  lp_logeo('lp_sal_cta_en_negativo', v_hor_ini, v_hor_fin);

  v_hor_ini := TO_CHAR(SYSDATE, 'hh24:mi:ss');
  lp_dif_sal_retenido;
  v_hor_fin := TO_CHAR(SYSDATE, 'hh24:mi:ss');
  lp_logeo('lp_dif_sal_retenido', v_hor_ini, v_hor_fin);

  v_hor_ini := TO_CHAR(SYSDATE, 'hh24:mi:ss');
  lp_dif_sal_bloqueado;
  v_hor_fin := TO_CHAR(SYSDATE, 'hh24:mi:ss');
  lp_logeo('lp_dif_sal_bloqueado', v_hor_ini, v_hor_fin);

  v_hor_ini := TO_CHAR(SYSDATE, 'hh24:mi:ss');
  lp_cda_sin_cup_emitidos;
  v_hor_fin := TO_CHAR(SYSDATE, 'hh24:mi:ss');
  lp_logeo('lp_cda_sin_cup_emitidos', v_hor_ini, v_hor_fin);

  IF v_est_modulo = 4 THEN
     v_hor_ini := TO_CHAR(SYSDATE, 'hh24:mi:ss');
     lp_dif_est_batch_online;
     v_hor_fin := TO_CHAR(SYSDATE, 'hh24:mi:ss');
     lp_logeo('lp_dif_est_batch_online', v_hor_ini, v_hor_fin);

     v_hor_ini := TO_CHAR(SYSDATE, 'hh24:mi:ss');
     lp_dif_sal_batch_online;
     v_hor_fin := TO_CHAR(SYSDATE, 'hh24:mi:ss');
     lp_logeo('lp_dif_sal_batch_online', v_hor_ini, v_hor_fin);
  END IF;

  v_hor_ini := TO_CHAR(SYSDATE, 'hh24:mi:ss');
  lp_mov_cta_no_activas;
  v_hor_fin := TO_CHAR(SYSDATE, 'hh24:mi:ss');
  lp_logeo('lp_mov_cta_no_activas', v_hor_ini, v_hor_fin);

  v_hor_ini := TO_CHAR(SYSDATE, 'hh24:mi:ss');
  lp_pres_can_con_dev_suspenso;
  v_hor_fin := TO_CHAR(SYSDATE, 'hh24:mi:ss');
  lp_logeo('lp_pres_can_con_dev_suspenso', v_hor_ini, v_hor_fin);

  v_hor_ini := TO_CHAR(SYSDATE, 'hh24:mi:ss');
  lp_dif_dev_prest_cuotas;
  v_hor_fin := TO_CHAR(SYSDATE, 'hh24:mi:ss');
  lp_logeo('lp_dif_dev_prest_cuotas', v_hor_ini, v_hor_fin);

  v_hor_ini := TO_CHAR(SYSDATE, 'hh24:mi:ss');
  lp_pres_dif_val_int_devengar;
  v_hor_fin := TO_CHAR(SYSDATE, 'hh24:mi:ss');
  lp_logeo('lp_pres_dif_val_int_devengar', v_hor_ini, v_hor_fin);

  v_hor_ini := TO_CHAR(SYSDATE, 'hh24:mi:ss');
  lp_ver_tasas;
  v_hor_fin := TO_CHAR(SYSDATE, 'hh24:mi:ss');
  lp_logeo('lp_ver_tasas', v_hor_ini, v_hor_fin);

  lp_descu_extractos;

  v_hor_ini := TO_CHAR(SYSDATE, 'hh24:mi:ss');
  lp_ver_clte_princ_de_ctas;
  v_hor_fin := TO_CHAR(SYSDATE, 'hh24:mi:ss');
  lp_logeo('lp_ver_clte_princ_de_ctas', v_hor_ini, v_hor_fin);

  COMMIT;

END PRG_VER_CONSISTENCIA;
/
