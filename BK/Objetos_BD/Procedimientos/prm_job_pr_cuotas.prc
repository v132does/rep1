CREATE OR REPLACE PROCEDURE IT.prm_job_pr_cuotas IS

  CURSOR dev IS
    SELECT c.*, p.est_batch est_prestamo, c.estado est_cuota
      FROM it.pr_cuotas@uenodesg c, it.pr_cta_prestamos p
     WHERE c.nro_cuenta = p.nro_cuenta
       AND not exists (select 1
              from pr_cuotas t
             where c.nro_cuenta = t.nro_cuenta
               and c.nro_cuota = t.nro_cuota);
  --- cursor de cuotas canceladas totalmente con prestamos no cancelados (script: IV_VAL.fu_val_cuo_pag_anticipadamente)
  CURSOR c_cuo_can IS
    SELECT nro_cuenta
      FROM pr_cuotas@uenodesg t
     WHERE t.estado = 'N'
       AND EXISTS
     (SELECT 1
              FROM pr_cta_prestamos x
             WHERE x.nro_cuenta = t.nro_cuenta
               AND x.estado <> 'N')
       AND t.nro_cuota = (SELECT MAX(y.nro_cuota)
                            FROM pr_cuotas y
                           WHERE y.nro_cuenta = t.nro_cuenta)
       AND not exists (select 1
              from pr_cuotas c
             where c.nro_cuenta = t.nro_cuenta
               and c.nro_cuota = t.nro_cuota);

  v_error     VARCHAR2(500);
  v_err       VARCHAR2(500);
  v_ermsj     VARCHAR2(500);
  v_fecha     DATE := SYSDATE;
  v_est_cuota pr_cuotas.estado%TYPE;
  v_cantidad  NUMBER := 0;
  v_fec       date := pag_cal.fu_obt_fec_actual(1);

BEGIN

  BEGIN
    pre_ini_aplicacion;
    pae_cnf.g_cod_modulo := '1';
  END;

  --Desabilitar los triggers
  sql_util.ejecute_dml('alter table pr_cuotas disable all triggers', v_err);
  --sql_util.ejecute_dml('alter table pr_cuotas disable constraint FK_PCUOT_NRO_CUENTA', v_err);
  IF v_err IS NOT NULL THEN
    raise_application_error(-20000, 'Al desabilitar triggers ' || v_err);
  END IF;
  delete mi_logs where proceso = 'PR_CUOTAS';
  /*
  sql_util.ejecute_dml('truncate table PR_CUOTAS', v_err);
  if v_err is not null then
     raise_application_error(-20000,'Al truncar PR_CUOTAS '||v_err);
  end if;*/

  FOR a IN dev LOOP
    v_cantidad := v_cantidad + 1;
    -- Los préstamos incobrables cuyas cuotas estén pendientes deben actualizarse con estado Incobrable
    IF a.est_prestamo = 'I' AND a.est_cuota NOT IN ('N', 'X') THEN
      v_est_cuota := 'I';
    ELSE
      v_est_cuota := a.est_cuota;
    END IF;
    BEGIN
      INSERT INTO pr_cuotas
        (nro_cuenta,
         nro_cuota,
         mto_capital,
         fec_vencimiento,
         mto_interes,
         estado,
         sal_capital,
         sal_interes,
         prioridad,
         fec_ult_pago,
         val_recargo,
         mto_int_documentado,
         nro_documento,
         sal_int_documentado,
         dev_no_cobrado,
         dev_suspenso,
         dev_acumulado,
         mto_int_descontado,
         mto_cap_adelantado,
         usu_insercion,
         usu_modificacion,
         fec_insercion,
         fec_modificacion)
      VALUES
        (a.nro_cuenta,
         a.nro_cuota,
         a.mto_capital,
         a.fec_vencimiento,
         a.mto_interes,
         v_est_cuota,
         nvl(a.sal_capital, 0),
         nvl(a.sal_interes, 0),
         a.prioridad,
         a.fec_ult_pago,
         a.val_recargo,
         a.mto_int_documentado,
         a.nro_documento,
         a.sal_int_documentado,
         a.dev_no_cobrado,
         decode(v_est_cuota, 'N', 0, a.dev_suspenso),
         a.dev_acumulado,
         a.mto_int_descontado,
         a.mto_cap_adelantado,
         a.usu_insercion,
         a.usu_modificacion,
         a.fec_insercion,
         a.fec_modificacion);
    EXCEPTION
      WHEN OTHERS THEN
        v_error := SQLCODE;
        v_ermsj := SQLERRM;
        INSERT INTO mi_logs
          (nro_reg, nro_error, men_error, comentario, proceso, fec_proceso)
        VALUES
          (1, v_error, v_ermsj, a.nro_cuenta, 'PR_CUOTAS', v_fecha);
    END;
  
  END LOOP;

  /*FOR c IN c_cuo_can LOOP
        UPDATE pr_cta_prestamos SET estado = 'N', EST_BATCH = 'N' WHERE nro_cuenta = c.nro_cuenta;
     END LOOP;
  */ /*
   --- Insertar las solicitudes de prestamos
   BEGIN
    INSERT INTO pr_solicitudes
      (nro_solicitud, descripcion, monto, tip_interes, tip_amortizacion, dia_plazo, fec_vencimiento,
       aju_ult_cuota, mto_interes, tip_aju_fecha, per_vto_capital, per_gracia, cod_persona,
       fec_inicio, tip_monto, aju_gracia, tot_prestamo, estado, cod_modulo, cod_modalidad,
       cod_moneda, cod_oficina, cod_sec_credito, cod_departamento, cod_rub_economico, usu_insercion,
       usu_modificacion,fec_insercion, fec_modificacion,tip_documento)
      (SELECT fue_obt_sig_secuencia('s_nro_sol_prestamos'),
              'SOLICITUD MIGRADA',
              a.mto_capital,
              a.tip_interes,
              'P',
              to_number(a.fec_vencimiento - a.fec_inicio),
              a.fec_vencimiento,
              'N',
              SUM(b.mto_interes),
              'E',
              decode(a.per_vto_capital,0,30,a.per_vto_capital),
              0,
              c.cod_persona,
              a.fec_inicio,
              'N',
              'N',
              a.mto_capital,
              'A',
              a.cod_modulo,
              a.cod_modalidad,
              a.cod_moneda,
              a.cod_oficina,
              a.cod_sec_credito,
              d.cod_departamento,
              a.cod_rub_economico,
              'MIGRA',
              'MIGRA',
              v_fec,
              v_fec,
              1
         FROM pr_cta_prestamos a,
              pr_cuotas        b,
              ge_cta_clientes  c,
              ba_oficinas      o,
              ba_ciudades      e,
              ba_departamentos d
        WHERE a.nro_cuenta = b.nro_cuenta
          AND b.nro_cuota = 1
          AND a.nro_cuenta = c.nro_cuenta
          AND a.estado <> 'N'
          AND a.nro_solicitud IS NULL
          AND c.relacion = 'P'
          AND a.usu_insercion = 'MIGRA'
          AND a.cod_oficina = o.cod_oficina
          AND c.cod_oficina = o.cod_oficina
          AND o.cod_ciudad = e.cod_ciudad
          AND o.cod_pais = e.cod_pais
          AND e.cod_departamento = d.cod_departamento
        GROUP BY a.mto_capital,
                 a.tip_interes,
                 a.fec_vencimiento,
                 a.fec_inicio,
                 c.cod_persona,
                 a.estado,
                 a.cod_modulo,
                 a.cod_modalidad,
                 a.cod_moneda,
                 a.cod_oficina,
                 a.cod_sec_credito,
                 a.cod_rub_economico,
                 a.per_vto_capital,
                 d.cod_departamento);
    EXCEPTION
         WHEN OTHERS THEN
            v_error := SQLCODE;
            v_ermsj := SQLERRM;
            INSERT INTO mi_logs
               (nro_reg, nro_error, men_error, comentario, proceso, fec_proceso)
            VALUES
               (1, v_error, v_ermsj, 'verif_pr_solicitudes', 'INSERT_PR_SOLICITUDES', v_fecha);
   END;*/
  /*
     BEGIN
     --- Actualizar nro_solicitud de prestamos
     UPDATE pr_cta_prestamos a
        SET a.nro_solicitud =
            (SELECT MAX(b.nro_solicitud)
               FROM pr_solicitudes b, ge_cta_clientes c
              WHERE a.cod_modulo = b.cod_modulo
                AND a.cod_modalidad = b.cod_modalidad
                AND a.cod_moneda = b.cod_moneda
                AND b.descripcion LIKE 'SOLICITUD MIGRADA'
                AND a.fec_inicio = b.fec_inicio
                AND a.fec_vencimiento = b.fec_vencimiento
                AND a.mto_capital = b.monto
                AND b.cod_persona = c.cod_persona
                AND c.relacion = 'P'
                AND c.nro_cuenta = a.nro_cuenta
                AND a.estado <> 'N')
      WHERE a.nro_solicitud IS NULL
        AND EXISTS (SELECT 's'
               FROM pr_solicitudes d, ge_cta_clientes e
              WHERE a.cod_modulo = d.cod_modulo
                AND a.cod_modalidad = d.cod_modalidad
                AND a.cod_moneda = d.cod_moneda
                AND d.descripcion LIKE 'SOLICITUD MIGRADA'
                AND a.fec_inicio = d.fec_inicio
                AND a.fec_vencimiento = d.fec_vencimiento
                AND a.mto_capital = d.monto
                AND d.cod_persona = e.cod_persona
                AND e.relacion = 'P'
                AND e.nro_cuenta = a.nro_cuenta);
      EXCEPTION
           WHEN OTHERS THEN
              v_error := SQLCODE;
              v_ermsj := SQLERRM;
              INSERT INTO mi_logs
                 (nro_reg, nro_error, men_error, comentario, proceso, fec_proceso)
              VALUES
                 (1, v_error, v_ermsj, 'verif_pr_cta_prestamos', 'UPDATE_SOLICITUDES EN PRESTAMOS', v_fecha);
      END;
  */ /*
   BEGIN
   --- Insertar en pr_sol_cargos
   INSERT INTO pr_sol_cargos
      (nro_solicitud, cod_transaccion, fec_tasa, val_tasa, monto, cod_tasa, cod_ent_seguro,
       cod_moneda, mto_mon_prestamo, usu_insercion, usu_modificacion,fec_insercion, fec_modificacion)
      (SELECT DISTINCT a.nro_solicitud,
                       709,
                       NULL,
                       a.val_tasa,
                       c.mto_interes,
                       NULL,
                       NULL,
                       a.cod_moneda,
                       c.mto_interes,
                       'MIGRA',
                       'MIGRA',
                        v_fec,
                        v_fec
         FROM pr_solicitudes c, pr_cta_prestamos a
        WHERE a.estado <> 'N'
          AND a.nro_solicitud = c.nro_solicitud
          AND NOT EXISTS (SELECT 1
                 FROM pr_sol_cargos b
                WHERE b.nro_solicitud = a.nro_solicitud
                  AND cod_transaccion = 709)
          AND c.descripcion = 'SOLICITUD MIGRADA'
        GROUP BY a.nro_solicitud, a.val_tasa, c.mto_interes, a.cod_moneda, c.tot_prestamo
       HAVING COUNT(*) = 1);
   EXCEPTION
         WHEN OTHERS THEN
            v_error := SQLCODE;
            v_ermsj := SQLERRM;
            INSERT INTO mi_logs
               (nro_reg, nro_error, men_error, comentario, proceso, fec_proceso)
            VALUES
               (1, v_error, v_ermsj,'verif_pr_sol_cargos', 'insert_pr_sol_cargos', v_fecha);
    END;
   begin
   --- Insertar en pr_sol_tasas
   INSERT INTO pr_sol_tasas
      (nro_solicitud, fec_vigencia, val_tasa, tip_cobro, per_vencimiento, usu_insercion,
       usu_modificacion,fec_insercion, fec_modificacion )
      SELECT DISTINCT p.nro_solicitud,
                      s.fec_inicio,
                      p.val_tasa,
                      s.tip_interes,
                      s.per_vto_capital,
                      'MIGRA',
                      'MIGRA',
                      v_fec,
                      v_fec
        FROM pr_solicitudes s, pr_cta_prestamos p
       WHERE s.nro_solicitud = p.nro_solicitud
         AND p.usu_insercion = 'MIGRA'
       GROUP BY p.nro_solicitud, s.fec_inicio, p.val_tasa, s.tip_interes, s.per_vto_capital
      HAVING COUNT(*) = 1;
  EXCEPTION
         WHEN OTHERS THEN
            v_error := SQLCODE;
            v_ermsj := SQLERRM;
            INSERT INTO mi_logs
               (nro_reg, nro_error, men_error, comentario, proceso, fec_proceso)
            VALUES
               (1, v_error, v_ermsj, 'verif_pr_sol_tasas', 'insert_pr_sol_tasas', v_fecha);
    END;

   begin
   --- Insertar en pr_sol_cuotas
   INSERT INTO pr_sol_cuotas
      (nro_solicitud, nro_cuota, mto_capital, fec_vto_habil, fec_vto_exacto, val_interes,
       sal_capital, val_int_original, val_int_adelantado, dia_periodo, dia_interes, usu_insercion,
       usu_modificacion,fec_insercion, fec_modificacion )
      SELECT DISTINCT s.nro_solicitud,
                MAX(c.nro_cuota),
                c.mto_capital,
                c.fec_vencimiento,
                c.fec_vencimiento,
                CASE
                   WHEN p.cod_modalidad IN ('608', '62') THEN
                    0
                   ELSE
                    c.mto_interes
                END mto_interes,
                c.sal_capital,
                0,
                CASE
                   WHEN p.cod_modalidad IN ('608', '62') THEN
                    c.mto_int_documentado
                   ELSE
                    0
                END val_int_adelantado,
                p.per_vto_capital,
                p.per_vto_interes,
                'MIGRA',
                'MIGRA',
                v_fec,
                v_fec
  FROM pr_cta_prestamos p, pr_solicitudes s, pr_cuotas c
 WHERE p.nro_solicitud = s.nro_solicitud
   AND p.nro_cuenta = c.nro_cuenta
   AND p.estado <> 'N'
   AND p.usu_insercion = 'MIGRA'
   AND c.usu_insercion = 'MIGRA'
   AND s.descripcion LIKE 'SOLICITUD MIGRADA'
   AND s.nro_solicitud NOT IN (SELECT nro_solicitud FROM pr_sol_cuotas)
 GROUP BY s.nro_solicitud,
          c.nro_cuota,
          c.mto_capital,
          c.fec_vencimiento,
          c.fec_vencimiento,
          c.mto_interes,
          c.mto_int_documentado,
          c.sal_capital,
          p.cod_modalidad,
          p.per_vto_capital,
          p.per_vto_interes
HAVING COUNT(*) = 1;

  EXCEPTION
         WHEN OTHERS THEN
            v_error := SQLCODE;
            v_ermsj := SQLERRM;
            INSERT INTO mi_logs
               (nro_reg, nro_error, men_error, comentario, proceso, fec_proceso)
            VALUES
               (1, v_error, v_ermsj,  'verif_pr_sol_cuotas', 'insert_pr_sol_cuotas', v_fecha);
    END;*/
  --- Actualiza cuotas canceladas no devengadas totalmente (script IV_VAL.fu_val_cancelado_no_devengado)
  UPDATE pr_cuotas a
     SET dev_acumulado = mto_interes + mto_int_documentado
   WHERE a.dev_acumulado !=
         nvl(a.mto_interes, 0) + nvl(a.mto_int_documentado, 0)
     AND nvl(a.sal_interes, 0) + nvl(a.sal_int_documentado, 0) = 0
     AND a.nro_cuenta IN
         (SELECT nro_cuenta FROM pr_cta_prestamos WHERE estado <> 'N');
  /*
   --- Actualiza cantidad de cuotas de prestamos differente a la cantidad de cuotas de pr_cuotas (script:IT_VAL.fu_val_dif_cant_cuotas_pres)
   UPDATE pr_cta_prestamos b
      SET can_cuotas =
          (SELECT COUNT(*) FROM pr_cuotas c WHERE c.nro_cuenta = b.nro_cuenta)
    WHERE b.can_cuotas <> (SELECT COUNT(*) FROM pr_cuotas c WHERE b.nro_cuenta = c.nro_cuenta);
  -- actualiza cantidad de cuotas en cabecera
  update pr_cta_prestamos a
                   set a.can_cuotas = (select count(*)
                                      from pr_cuotas c
                                       where a.nro_cuenta = c.nro_cuenta)
                 where  a.can_cuotas <> (select count(*)
                                      from pr_cuotas c
                                       where a.nro_cuenta = c.nro_cuenta)
                   and a.estado <> 'N';*/
  --Habilitar los triggers
  sql_util.ejecute_dml('alter table pr_cuotas enable all triggers', v_err);
  sql_util.ejecute_dml('alter table pr_solicitudes enable all triggers',
                       v_err);
  sql_util.ejecute_dml('alter table pr_sol_cargos enable all triggers',
                       v_err);
  sql_util.ejecute_dml('alter table pr_sol_tasas enable all triggers',
                       v_err);
  sql_util.ejecute_dml('alter table pr_sol_cuotas enable all triggers',
                       v_err);
  --sql_util.ejecute_dml('alter table pr_cuotas enable constraint FK_PCUOT_NRO_CUENTA', v_err);
  IF v_err IS NOT NULL THEN
    raise_application_error(-20000, 'Al habilitar triggers ' || v_err);
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    v_error := SQLCODE;
    v_ermsj := nvl(v_err, SQLERRM);
    v_fecha := SYSDATE;
    INSERT INTO mi_logs
      (nro_reg, nro_error, men_error, comentario, proceso, fec_proceso)
    VALUES
      (1, v_error, v_ermsj, 'verif_job_pr_cuotas', 'PR_CUOTAS', v_fecha);
    COMMIT;
END;
/

