CREATE OR REPLACE PROCEDURE IT.prg_eje_pro_multiple
(
   p_fecha        IN ge_calendarios.fec_actual%TYPE,
   p_tip_proceso  IN VARCHAR2 := 'I',
   p_cod_proceso  IN NUMBER := NULL,
   p_cod_programa IN ge_procesos_det.cod_programa%TYPE,
   p_err_proceso  OUT VARCHAR2,
   p_nro_orden    IN ge_procesos_det.nro_orden%TYPE,
   p_err_ind      OUT BOOLEAN
) IS
   bv_error     BOOLEAN;
   v_sentencia  VARCHAR2(500);
   v_hor_inicio ge_procesos.hor_inicio%TYPE;
   PROCEDURE lp_ins_log
   (
      p_cod_proceso ge_procesos.cod_proceso%TYPE,
      p_nro_orden   ge_procesos.nro_orden%TYPE
   ) IS
   BEGIN
      INSERT INTO ge_procesos_log
         (fecha, cod_proceso, nro_orden, hor_inicio, hor_error, error, cod_usuario)
      VALUES
         (p_fecha, p_cod_proceso, p_nro_orden, v_hor_inicio, to_char(SYSDATE, 'HH24:MI:SS'),
          p_err_proceso, USER);
   END lp_ins_log;
BEGIN
   BEGIN
      --- Para poder tomar el raise
      bv_error  := FALSE;
      p_err_ind := FALSE;
      --- Ejecutar el proceso, Obs: No se ejecuta un proceso si el anterior
      --- no se ha finalizado con exito a excepcion de los no obligatorios   
      BEGIN
         v_hor_inicio := to_char(SYSDATE, 'hh24:mi:ss');
         --- Actualizar hora inicio y usuario del proceso detalle
         UPDATE ge_procesos_det
            SET hor_inicio = v_hor_inicio, cod_usuario = USER, error = NULL
          WHERE cod_proceso = p_cod_proceso
            AND nro_orden = p_nro_orden
            AND cod_programa = p_cod_programa;
         COMMIT;
         -- inicializo punto de rollback
         SAVEPOINT pro_ejecutado;
         ---
         pae_cnf.g_programa := 'GPPROFIN'; -- se reasigna el valor para asegurar este dato
         --- Ejecutar el proceso en forma dinamica
         v_sentencia := 'BEGIN ' || p_cod_programa || '; END;';
         sql_util.ejecute_dml(v_sentencia, p_err_proceso);
         p_err_proceso := REPLACE(p_err_proceso, 'SQL_UTIL.EJECUTE_DML', '*');
         IF p_err_proceso IS NOT NULL THEN
            -- hago rollback de lo que hizo el proceso
            ROLLBACK TO SAVEPOINT pro_ejecutado;
            lp_ins_log(p_cod_proceso, p_nro_orden);
            UPDATE ge_procesos_det
               SET error = p_err_proceso
             WHERE cod_proceso = p_cod_proceso
               AND nro_orden = p_nro_orden
               AND cod_programa = p_cod_programa;
            COMMIT;
            --if r_det.obligatorio = 'S' then
            -- Cortar proceso si es obligatorio. cortar siempre para que el operador diga si continua o no
            bv_error := TRUE;
            --exit;
            p_err_ind := TRUE;
            --end if;
         END IF;
      EXCEPTION
         WHEN OTHERS THEN
            lp_ins_log(p_cod_proceso, p_nro_orden);
            UPDATE ge_procesos_det
               SET error = p_err_proceso
             WHERE cod_proceso = p_cod_proceso
               AND nro_orden = p_nro_orden
               AND cod_programa = p_cod_programa;
            COMMIT;
            --if r_det.obligatorio = 'S' then
            -- Cortar proceso si es obligatorio
            bv_error := TRUE;
            --exit;
            p_err_ind := TRUE;
            --end if;
      END;
      --- Si hubo error en el proceso obligatorio salir del loop
      IF bv_error THEN
         --exit;
         p_err_ind := TRUE;
      END IF;
      --- Actualizar hora fin si termino con exito;
      IF p_err_proceso IS NULL THEN
         -- Solo si termino con exito le pone la fecha fin.
         UPDATE ge_procesos_det
            SET hor_fin = to_char(SYSDATE, 'hh24:mi:ss'), error = p_err_proceso
          WHERE cod_proceso = p_cod_proceso
            AND nro_orden = p_nro_orden
            AND cod_programa = p_cod_programa;
         COMMIT;
      END IF;
   END;
   --- Si hubo error en el proceso obligatorio terminar la ejecución.
   IF bv_error THEN
      p_err_ind := TRUE;
   END IF;
EXCEPTION
   WHEN OTHERS THEN
      IF SQLCODE <= -20000 THEN
         RAISE;
      ELSE
         raise_application_error(-20000, 'en prg_eje_pro_multiple ' || SQLERRM);
      END IF;
END;
/

