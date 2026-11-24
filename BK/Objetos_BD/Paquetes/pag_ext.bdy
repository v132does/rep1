create or replace PACKAGE BODY    it.PAG_EXT
IS
   /*
      23-09-2024  v1.0  LReyes
      Monitor. Ejecuta y supervisa, en paralelo, el procedimiento parametrizado.
      Se encapsula el procedimiento objetivo como job y se controla si su tiempo de ejecución alcanza el timeout parametrizado.
      También se controla el tiempo de ejecución del pool de instancias.
   */
   vg_orden_log_perf  PLS_INTEGER := 0;
   
   PROCEDURE pr_log_perf_event (
      p_cod_programa                  IN VARCHAR2,
      p_cod_subproceso                IN VARCHAR2,
      p_fec_inicio                    IN TIMESTAMP,
      p_fec_fin                       IN TIMESTAMP DEFAULT NULL,
      p_val_duracion_seg              IN NUMBER DEFAULT NULL,
      p_est_resultado                 IN VARCHAR2,
      p_des_error                     IN VARCHAR2 DEFAULT NULL,
      p_val_timeout_pool_mi           IN NUMBER DEFAULT NULL,
      p_val_timeout_job_mi            IN NUMBER DEFAULT NULL,
      p_val_cant_job_lanzados         IN NUMBER DEFAULT NULL,
      p_val_cant_job_stop_timeout     IN NUMBER DEFAULT NULL,
      p_val_cant_intervalos_liberados IN NUMBER DEFAULT NULL,
      p_val_cant_clientes_procesados  IN NUMBER DEFAULT NULL,
      p_val_cant_cuentas_procesadas   IN NUMBER DEFAULT NULL,
      p_val_cant_movimientos_gen      IN NUMBER DEFAULT NULL,
      p_est_resultado_maestras        IN VARCHAR2 DEFAULT NULL
   )
   IS
      v_det_error        VARCHAR2(4000);
      v_orden            PLS_INTEGER;
      v_des_mes_proceso  VARCHAR2(30);

      FUNCTION lf_json_text (p_value IN VARCHAR2) RETURN VARCHAR2
      IS
      BEGIN
         IF p_value IS NULL THEN
            RETURN 'null';
         END IF;

         RETURN '"' || REPLACE(REPLACE(p_value, CHR(34), '\"'), CHR(10), ' ') || '"';
      END lf_json_text;
   BEGIN

      v_des_mes_proceso := UPPER(TRIM(TO_CHAR(vg_fec_ult_cierre_mes, 'fmMonth', 'NLS_DATE_LANGUAGE=SPANISH')));     
      v_orden := NVL(vg_orden_log_perf, 0) + 1;
      vg_orden_log_perf := v_orden;

      v_det_error :=
         '{"DES_MES_PROCESO":' || lf_json_text(v_des_mes_proceso) ||
         ',"ORDEN":' || TO_CHAR(v_orden) ||
         ',"COD_SUBPROCESO":' || lf_json_text(p_cod_subproceso) ||
         ',"FEC_INICIO":' || lf_json_text(TO_CHAR(p_fec_inicio, 'YYYY-MM-DD HH24:MI:SS.FF3')) ||
         ',"FEC_FIN":' || CASE WHEN p_fec_fin IS NULL THEN 'null' ELSE lf_json_text(TO_CHAR(p_fec_fin, 'YYYY-MM-DD HH24:MI:SS.FF3')) END ||
         ',"VAL_DURACION_SEG":' || CASE WHEN p_val_duracion_seg IS NULL THEN 'null' ELSE TO_CHAR(p_val_duracion_seg, 'FM9999999990D00', 'NLS_NUMERIC_CHARACTERS=.,') END ||
         ',"EST_RESULTADO":' || lf_json_text(p_est_resultado);

      IF p_est_resultado = 'ERROR' THEN
         v_det_error := v_det_error || ',"DES_ERROR":' || lf_json_text(p_des_error);
      END IF;

      IF p_cod_subproceso = 'GEN_EXT_MONITOR' THEN
         v_det_error := v_det_error ||
            ',"VAL_TIMEOUT_POOL_MI":' || NVL(TO_CHAR(p_val_timeout_pool_mi), 'null') ||
            ',"VAL_TIMEOUT_JOB_MI":' || NVL(TO_CHAR(p_val_timeout_job_mi), 'null') ||
            ',"VAL_CANT_JOB_LANZADOS":' || NVL(TO_CHAR(p_val_cant_job_lanzados), 'null') ||
            ',"VAL_CANT_JOB_STOP_TIMEOUT":' || NVL(TO_CHAR(p_val_cant_job_stop_timeout), 'null') ||
            ',"VAL_CANT_INTERVALOS_LIBERADOS":' || NVL(TO_CHAR(p_val_cant_intervalos_liberados), 'null');
      ELSIF p_cod_subproceso = 'PR_GEN_EXTRACTO' THEN
         v_det_error := v_det_error ||
            ',"VAL_CANT_CLIENTES_PROCESADOS":' || NVL(TO_CHAR(p_val_cant_clientes_procesados), 'null') ||
            ',"VAL_CANT_CUENTAS_PROCESADAS":' || NVL(TO_CHAR(p_val_cant_cuentas_procesadas), 'null') ||
            ',"VAL_CANT_MOVIMIENTOS_GEN":' || NVL(TO_CHAR(p_val_cant_movimientos_gen), 'null') ||
            ',"EST_RESULTADO_MAESTRAS":' || lf_json_text(p_est_resultado_maestras);
      END IF;

      v_det_error := v_det_error || '}';

      PRG_INS_LOG_PROGRAMAS(p_cod_programa, v_det_error);
   END pr_log_perf_event;
   
   PROCEDURE GEN_EXT_MONITOR (
      p_procedure_name IN VARCHAR2
   )
   IS
      v_init_time      TIMESTAMP WITH TIME ZONE;
      v_stop_time      TIMESTAMP WITH TIME ZONE;
      v_flag_timeout   PLS_INTEGER := 0;
      v_hay_intervalo  PLS_INTEGER := 0;
      v_cant_proc      PLS_INTEGER := 0;
      v_session_count  PLS_INTEGER := 0;
      v_initial_time               PLS_INTEGER := DBMS_UTILITY.get_time;
      v_elapsed_time               PLS_INTEGER;
      v_elapsed_seg                NUMBER;
      v_fec_inicio                 TIMESTAMP := SYSTIMESTAMP;
      v_fec_fin                    TIMESTAMP;
      v_det_error                  VARCHAR2(4000);
      v_cant_job_lanzados          PLS_INTEGER := 0;
      v_cant_job_stop_timeout      PLS_INTEGER := 0;
      v_cant_intervalos_liberados  PLS_INTEGER := 0;
   BEGIN
      PR_SET_PARAMETROS;
    
      pr_log_perf_event(
            p_cod_programa                  => 'PERF_GEN_EXT_MONITOR',
            p_cod_subproceso                => 'GEN_EXT_MONITOR',
            p_fec_inicio                    => v_fec_inicio,
            p_fec_fin                       => NULL,
            p_val_duracion_seg              => NULL,
            p_est_resultado                 => 'FEC_INICIO',
            p_des_error                     => NULL,
            p_val_timeout_pool_mi           => NULL,
            p_val_timeout_job_mi            => NULL,
            p_val_cant_job_lanzados         => NULL,
            p_val_cant_job_stop_timeout     => NULL,
            p_val_cant_intervalos_liberados => NULL
         );
      
      
      PRG_INS_LOG_PROGRAMAS(vg_pkg||'.GEN_EXT_MONITOR', 'Inicio... ult_pri_dia_mes_habil('||TO_CHAR(vg_ult_pri_dia_mes_habil, 'DD/MM/YYYY')||') '||
                            'fec_ult_cierre_mes('||TO_CHAR(vg_fec_ult_cierre_mes, 'DD/MM/YYYY')||') intervalo_size('||vg_intervalo_size||') bulk_size('||vg_bulk_size||') '||
                            'job_cant_instancias('||vg_job_cant_instancias||') max_loop_intervalos('||vg_max_loop_intervalos||') '||
                            'timeout_pool_MI('||vg_timeout_pool_MI||') timeout_job_MI('||vg_timeout_job_MI||')');

      --Calculamos el tiempo de ejecución máximo para el pool de tareas
      v_init_time := SYSTIMESTAMP;
      v_stop_time := v_init_time + INTERVAL '1' MINUTE * vg_timeout_pool_MI;

      LOOP
         --Comprobamos si el tiempo transcurrido alcanza el timeout del pool de instancias
         IF SYSTIMESTAMP > v_stop_time THEN
            v_flag_timeout := 1;
         END IF;

         --Comprobamos que aún quede al menos un intervalo a ser procesado
         SELECT COUNT(1)
         INTO v_hay_intervalo
         FROM ge_ext_intervalos
         WHERE pri_dia_mes_habil = vg_ult_pri_dia_mes_habil
           AND estado = 'I'
           AND rownum = 1;

         --Condición de fin:
         -- + No queda ningún intervalo para procesar
         -- + Se agotó el tiempo de ejecución máximo del pool
         -- + Se alcanzó la cantidad máxima de iteraciones de Intervalos a ser procesados en cada intento de Generación de Extractos
         EXIT WHEN v_hay_intervalo = 0 OR v_flag_timeout = 1 OR v_cant_proc >= vg_max_loop_intervalos;

         --Contamos la cantidad de sesiones ejecutando el job
         SELECT COUNT(1)
         INTO v_session_count --@LReyes --alternativa a DBA_SCHEDULER_JOB_RUN_DETAILS
         FROM v$session
         WHERE schemaname = 'IT'
           AND module = 'DBMS_SCHEDULER'
           AND action LIKE 'JOB_GEN_EXT_%';

         --Evaluamos lanzar nuevas instancias
         IF v_session_count < vg_job_cant_instancias THEN
            FOR i IN 1 .. (vg_job_cant_instancias-v_session_count) LOOP
               IF v_cant_proc < vg_max_loop_intervalos THEN
                  DBMS_SESSION.SLEEP(1);
                  v_cant_proc := v_cant_proc + 1;
                  DBMS_SCHEDULER.create_job (
                     job_name        => 'JOB_GEN_EXT_'||TO_CHAR(SYSDATE, 'HH24MISS'),
                     start_date      => SYSTIMESTAMP,
                     end_date        => SYSTIMESTAMP + INTERVAL '1' MINUTE * vg_timeout_job_MI,
                     repeat_interval => NULL,
                     auto_drop       => TRUE,
                     job_type        => 'PLSQL_BLOCK',
                     enabled         => TRUE,
                     job_action      => 'BEGIN '||p_procedure_name||'(TO_DATE('''||TO_CHAR(vg_ult_pri_dia_mes_habil,'DD/MM/YYYY')||''', ''DD/MM/YYYY'')); END;'
                  );
                  v_cant_job_lanzados := v_cant_job_lanzados + 1;
               ELSE
                  PRG_INS_LOG_PROGRAMAS(vg_pkg||'.GEN_EXT_MONITOR', 'Se alcanzó la cantidad máxima de iteraciones de Intervalos a ser procesados');
                  EXIT;
               END IF;
            END LOOP;
         ELSE
            PRG_INS_LOG_PROGRAMAS(vg_pkg||'.GEN_EXT_MONITOR', 'Se alcanzó la cantidad máxima de jobs concurrentes para el pool de instancias');
         END IF;

         --Monitoreamos el tiempo de ejecución transcurrido de las instancias
         FOR rec IN ( SELECT job_name,
                             start_time,
                             end_time,
                             actual_time
                      FROM ( SELECT ACTION job_name,
                                    logon_time start_time,
                                    logon_time + INTERVAL '1' MINUTE * vg_timeout_job_MI end_time,
                                    CAST(SYSTIMESTAMP AS DATE) actual_time
                             FROM v$session
                             WHERE schemaname = 'IT'
                               AND module = 'DBMS_SCHEDULER'
                               AND action LIKE 'JOB_GEN_EXT_%' )
                      WHERE actual_time >= end_time )
         LOOP
            BEGIN
               DBMS_SCHEDULER.stop_job(job_name => rec.job_name);
               v_cant_job_stop_timeout := v_cant_job_stop_timeout + 1;
               PRG_INS_LOG_PROGRAMAS(vg_pkg||'.GEN_EXT_MONITOR', 'stop_job '||rec.job_name||'. La instancia agotó el tiempo máximo de ejecución permitido.');
            EXCEPTION
               WHEN OTHERS THEN
                  PRG_INS_LOG_PROGRAMAS(vg_pkg||'.GEN_EXT_MONITOR', 'stop_job '||rec.job_name||'. EXCEPTION | '||SQLERRM);
            END;
         END LOOP;

         --Esperamos 10 segundos antes de iterar
         DBMS_SESSION.SLEEP(10);
      END LOOP;

      IF v_flag_timeout = 1 THEN
         PRG_INS_LOG_PROGRAMAS(vg_pkg||'.GEN_EXT_MONITOR', 'TIMEOUT del pool de instancias');
      END IF;

      IF v_cant_proc >= vg_max_loop_intervalos THEN
         PRG_INS_LOG_PROGRAMAS(vg_pkg||'.GEN_EXT_MONITOR', 'Se alcanzó CANTIDAD MÁXIMA de iteraciones de Intervalos a ser procesados');
      END IF;

      --Contamos una última vez la cantidad de sesiones ejecutando el job
      SELECT COUNT(1)
      INTO v_session_count
      FROM v$session
      WHERE schemaname = 'IT'
        AND module = 'DBMS_SCHEDULER'
        AND action LIKE 'JOB_GEN_EXT_%';

      --Última oportunidad de que terminen los jobs en ejecución
      IF v_session_count > 0 THEN
         PRG_INS_LOG_PROGRAMAS(vg_pkg||'.GEN_EXT_MONITOR', 'Final time slice '||vg_timeout_job_MI||' min');

         --Esperamos el tiempo máximo que puede tardar un job
         DBMS_SESSION.SLEEP(60 * vg_timeout_job_MI);

         --Detenemos todos los jobs en ejecución
         FOR rec IN ( SELECT job_name,
                             start_time,
                             end_time,
                             actual_time
                      FROM ( SELECT ACTION job_name,
                                    logon_time start_time,
                                    logon_time + INTERVAL '1' MINUTE * vg_timeout_job_MI end_time,
                                    CAST(SYSTIMESTAMP AS DATE) actual_time
                             FROM v$session
                             WHERE schemaname = 'IT'
                               AND module = 'DBMS_SCHEDULER'
                               AND action LIKE 'JOB_GEN_EXT_%' ) )
         LOOP
            BEGIN
               DBMS_SCHEDULER.stop_job(job_name => rec.job_name);
               v_cant_job_stop_timeout := v_cant_job_stop_timeout + 1;
               PRG_INS_LOG_PROGRAMAS(vg_pkg||'.GEN_EXT_MONITOR', 'stop_job final '||rec.job_name||'. La instancia agotó el tiempo máximo de ejecución permitido.');
            EXCEPTION
               WHEN OTHERS THEN
                  PRG_INS_LOG_PROGRAMAS(vg_pkg||'.GEN_EXT_MONITOR', 'stop_job final '||rec.job_name||'. EXCEPTION | '||SQLERRM);
            END;
         END LOOP;
      END IF;

      --Comprobamos si quedó al menos un intervalo bloqueado
      SELECT COUNT(1)
      INTO v_hay_intervalo
      FROM ge_ext_intervalos
      WHERE pri_dia_mes_habil = vg_ult_pri_dia_mes_habil
        AND estado = 'B'
        AND rownum = 1;

      IF v_hay_intervalo > 0 THEN
         UPDATE GE_EXT_INTERVALOS
         SET estado = 'L',
             observacion = 'Consultar trazas en Tabla de Log. Timeout alcanzado o Excepción capturada',
             usu_modificacion = USER,
             fec_modificacion = SYSDATE
         WHERE pri_dia_mes_habil = vg_ult_pri_dia_mes_habil
           AND estado = 'B';
         v_cant_intervalos_liberados := SQL%ROWCOUNT;
         COMMIT;
      END IF;
      v_fec_fin := SYSTIMESTAMP;
      v_elapsed_time := DBMS_UTILITY.get_time - v_initial_time;
      v_elapsed_seg := TRUNC(v_elapsed_time / 100, 2);
           
      pr_log_perf_event(
            p_cod_programa                  => 'PERF_GEN_EXT_MONITOR',
            p_cod_subproceso                => 'GEN_EXT_MONITOR',
            p_fec_inicio                    => v_fec_inicio,
            p_fec_fin                       => v_fec_fin,
            p_val_duracion_seg              => v_elapsed_seg,
            p_est_resultado                 => 'SUCCESS',
            p_des_error                     => NULL,
            p_val_timeout_pool_mi           => vg_timeout_pool_MI,
            p_val_timeout_job_mi            => vg_timeout_job_MI,
            p_val_cant_job_lanzados         => v_cant_job_lanzados,
            p_val_cant_job_stop_timeout     => v_cant_job_stop_timeout,
            p_val_cant_intervalos_liberados => v_cant_intervalos_liberados
         );
      
      PRG_INS_LOG_PROGRAMAS(vg_pkg||'.GEN_EXT_MONITOR', 'Fin Ok');
   EXCEPTION
      WHEN OTHERS THEN
         v_fec_fin := SYSTIMESTAMP;
         v_elapsed_time := DBMS_UTILITY.get_time - v_initial_time;
         v_elapsed_seg := TRUNC(v_elapsed_time / 100, 2);
         pr_log_perf_event(
            p_cod_programa                  => 'PERF_GEN_EXT_MONITOR',
            p_cod_subproceso                => 'GEN_EXT_MONITOR',
            p_fec_inicio                    => v_fec_inicio,
            p_fec_fin                       => v_fec_fin,
            p_val_duracion_seg              => v_elapsed_seg,
            p_est_resultado                 => 'ERROR',
            p_des_error                     => SQLERRM,
            p_val_timeout_pool_mi           => vg_timeout_pool_MI,
            p_val_timeout_job_mi            => vg_timeout_job_MI,
            p_val_cant_job_lanzados         => v_cant_job_lanzados,
            p_val_cant_job_stop_timeout     => v_cant_job_stop_timeout,
            p_val_cant_intervalos_liberados => v_cant_intervalos_liberados
         );
         PRG_INS_LOG_PROGRAMAS(vg_pkg||'.GEN_EXT_MONITOR', 'EXCEPTION | '||SQLERRM);
         RAISE;
   END GEN_EXT_MONITOR;

   /*
      23-09-2024  v1.0  LReyes
      Genera intervalos para poblar la Tabla GE_EXT_INTERVALOS. Aquí se define la Prioridad de los mismos.
      El universo de Clientes se prioriza según tipo: Persona Jurídica o Persona Física (a su vez, según segmento).
   */
   PROCEDURE PR_INT_GENERAR (
      p_pri_dia_mes_habil IN DATE
   )
   IS
      v_fetch_count        PLS_INTEGER := 0;
      v_prioridad          PLS_INTEGER := 0;
      v_cod_cota_inferior  ge_ext_intervalos.cod_cota_inferior%TYPE;
      v_cod_cota_superior  ge_ext_intervalos.cod_cota_superior%TYPE;
      t_int_clientes       t_cod_persona_table := t_cod_persona_table();
   BEGIN
      PR_SET_PARAMETROS;

      v_fetch_count := 0;
      v_prioridad := 1;
      PRG_INS_LOG_PROGRAMAS(vg_pkg||'.PR_INT_GENERAR', '['||v_prioridad||'] Recolección de Clientes Tipo Persona Jurídica');
      OPEN cur_per_juridicas(p_pri_dia_mes_habil);
      LOOP
         FETCH cur_per_juridicas
         BULK COLLECT INTO t_int_clientes LIMIT vg_intervalo_size;
         EXIT WHEN t_int_clientes.COUNT = 0;

         v_fetch_count := v_fetch_count + 1;
         v_cod_cota_inferior := t_int_clientes(t_int_clientes.FIRST);
         v_cod_cota_superior := t_int_clientes(t_int_clientes.LAST);

         INSERT INTO GE_EXT_INTERVALOS ( pri_dia_mes_habil, cod_cota_inferior, cod_cota_superior, prioridad )
         VALUES ( p_pri_dia_mes_habil, v_cod_cota_inferior, v_cod_cota_superior, v_prioridad );
      END LOOP;
      CLOSE cur_per_juridicas;
      PRG_INS_LOG_PROGRAMAS(vg_pkg||'.PR_INT_GENERAR', '['||v_prioridad||'] '||v_fetch_count||' intervalos generados');

      FOR segmento IN 1 .. 2
      LOOP
         v_fetch_count := 0;
         v_prioridad := segmento + 1;
         PRG_INS_LOG_PROGRAMAS(vg_pkg||'.PR_INT_GENERAR', '['||v_prioridad||'] Recolección de Clientes Tipo Persona Física - Segmento '||segmento);
         OPEN cur_per_fisicas(p_pri_dia_mes_habil, segmento);
         LOOP
            FETCH cur_per_fisicas
            BULK COLLECT INTO t_int_clientes LIMIT vg_intervalo_size;
            EXIT WHEN t_int_clientes.COUNT = 0;

            v_fetch_count := v_fetch_count + 1;
            v_cod_cota_inferior := t_int_clientes(t_int_clientes.FIRST);
            v_cod_cota_superior := t_int_clientes(t_int_clientes.LAST);

            INSERT INTO GE_EXT_INTERVALOS ( pri_dia_mes_habil, cod_cota_inferior, cod_cota_superior, prioridad )
            VALUES ( p_pri_dia_mes_habil, v_cod_cota_inferior, v_cod_cota_superior, v_prioridad );
         END LOOP;
         CLOSE cur_per_fisicas;
         PRG_INS_LOG_PROGRAMAS(vg_pkg||'.PR_INT_GENERAR', '['||v_prioridad||'] '||v_fetch_count||' intervalos generados');
      END LOOP;

      COMMIT;
   EXCEPTION
      WHEN OTHERS THEN
         PRG_INS_LOG_PROGRAMAS(vg_pkg||'.PR_INT_GENERAR', 'EXCEPTION | '||SQLERRM);
         ROLLBACK;
         IF cur_per_juridicas%ISOPEN THEN
            CLOSE cur_per_juridicas;
         END IF;
         IF cur_per_fisicas%ISOPEN THEN
            CLOSE cur_per_fisicas;
         END IF;
         RAISE;
   END PR_INT_GENERAR;

   /*
      23-09-2024  v1.0  LReyes
      Recupera 1 a 1, la cantidad parametrizada de intervalos ponderados.
      Cada intervalo, es bloqueado 'B' al ser recuperado y actualizado post procesamiento según corresponda 'L', 'E', etc..
      A partir de las cotas del intervalo se listan los Clientes y luego se depuran aquellos que deben ser excluidos.
   */
   PROCEDURE PR_INT_PROCESAR (
      p_pri_dia_mes_habil IN DATE,
      p_cant_intervalos   IN PLS_INTEGER DEFAULT 1
   )
   IS
      v_traza             ge_log_errores.det_error%TYPE;
      v_initial_time      PLS_INTEGER := DBMS_UTILITY.get_time;
      v_elapsed_time      PLS_INTEGER := DBMS_UTILITY.get_time;
      
      v_fec_inicio        TIMESTAMP := SYSTIMESTAMP;
      v_fec_fin           TIMESTAMP;
      v_inicio            PLS_INTEGER;
      v_duracion_seg      NUMBER;
      
      v_aux_time          PLS_INTEGER;
      v_aux_cant          PLS_INTEGER;
      v_hay_error         PLS_INTEGER;
      v_intervalo         ge_ext_intervalos%ROWTYPE;
      v_cod_persona_list  t_cod_persona_table := t_cod_persona_table();
   BEGIN
      FOR i IN 1 .. p_cant_intervalos
      LOOP
         --Se recupera el intervalo de mayor prioridad
         BEGIN
            SELECT *
            INTO v_intervalo
            FROM ge_ext_intervalos
            WHERE rowid = ( SELECT rowid
                            FROM ge_ext_intervalos
                            WHERE pri_dia_mes_habil = p_pri_dia_mes_habil
                              AND estado = 'I'
                            ORDER BY prioridad ASC,
                                     cod_cota_inferior ASC
                            FETCH FIRST 1 ROW ONLY )
            FOR UPDATE SKIP LOCKED;
         EXCEPTION
            WHEN NO_DATA_FOUND THEN
               PRG_INS_LOG_PROGRAMAS(vg_pkg||'.PR_INT_PROCESAR', 'No se encontró ningún intervalo para procesar');
               EXIT;
            WHEN OTHERS THEN
               RAISE;
         END;

         --Se cambia el estado del intervalo para evitar su reproceso, más allá de su resultado
         UPDATE GE_EXT_INTERVALOS
         SET estado = 'B',
             usu_modificacion = USER,
             fec_modificacion = SYSDATE
         WHERE pri_dia_mes_habil = p_pri_dia_mes_habil
           AND cod_cota_inferior = v_intervalo.cod_cota_inferior
           AND cod_cota_superior = v_intervalo.cod_cota_superior;

         COMMIT;

         --Se listan los Clientes que pertenecen al intervalo
         PR_INT_CLI_LISTAR(p_pri_dia_mes_habil, v_intervalo.cod_cota_inferior, v_intervalo.cod_cota_superior, v_cod_persona_list);
         v_aux_cant := v_cod_persona_list.COUNT;

         --Se depura la lista de Clientes
         PR_INT_CLI_DEPURAR(vg_fec_ult_cierre_mes, v_cod_persona_list);

         --Si después de la depuración la lista resulta vacía, se cambia su estado y se continua con la iteración de intervalos
         IF v_cod_persona_list.COUNT = 0 THEN
            UPDATE GE_EXT_INTERVALOS
            SET estado = 'P',
                observacion = 'Lista de Clientes vacía luego de su depuración',
                usu_modificacion = USER,
                fec_modificacion = SYSDATE
            WHERE pri_dia_mes_habil = p_pri_dia_mes_habil
              AND cod_cota_inferior = v_intervalo.cod_cota_inferior
              AND cod_cota_superior = v_intervalo.cod_cota_superior;

            COMMIT;
            CONTINUE;
         END IF;

         BEGIN
            PRG_INS_LOG_PROGRAMAS(vg_pkg||'.PR_INT_PROCESAR',
                                  'Intervalo [ '||v_intervalo.cod_cota_inferior||' ~ '||v_intervalo.cod_cota_superior||' ] '||
                                  'con '||v_cod_persona_list.COUNT||' Clientes '||
                                  CASE WHEN v_cod_persona_list.COUNT < v_aux_cant THEN '(lista depurada de '||v_aux_cant||')' ELSE '' END);

            v_hay_error := 0;
            
            v_fec_inicio := SYSTIMESTAMP;
            v_inicio := DBMS_UTILITY.get_time;
            
            PR_GEN_EXTRACTO('M', v_cod_persona_list);
           
            v_fec_fin := SYSTIMESTAMP;
            v_duracion_seg := TRUNC((DBMS_UTILITY.get_time - v_inicio) / 100, 2);
                  
            pr_log_perf_event(
                p_cod_programa                 => 'PERF_PR_INT_PROCESAR',
                p_cod_subproceso               => '~CURSOR Intervalo [ '||v_intervalo.cod_cota_inferior||' ~ '||v_intervalo.cod_cota_superior||' ] '||
                                  'con '||v_cod_persona_list.COUNT||' Clientes ',
                p_fec_inicio                   => v_fec_inicio,
                p_fec_fin                      => v_fec_fin,
                p_val_duracion_seg             => v_duracion_seg,
                p_est_resultado                => 'SUCCESS');

            COMMIT;
         EXCEPTION
            WHEN OTHERS THEN
               PRG_INS_LOG_PROGRAMAS(vg_pkg||'.PR_INT_PROCESAR',
                                     'Intervalo [ '||v_intervalo.cod_cota_inferior||' ~ '||v_intervalo.cod_cota_superior||' ] '||
                                     'EXCEPTION | '||SQLERRM);
               ROLLBACK;
               v_hay_error := 1;
         END;

         v_aux_time := DBMS_UTILITY.get_time;
         PRG_INS_LOG_PROGRAMAS(vg_pkg||'.PR_INT_PROCESAR',
                               'Intervalo [ '||v_intervalo.cod_cota_inferior||' ~ '||v_intervalo.cod_cota_superior||' ] '||
                               'Tiempo de ejecución: '||TRUNC((v_aux_time - v_elapsed_time)/100/60, 2)||' minutes');
         v_elapsed_time := v_aux_time;

         UPDATE GE_EXT_INTERVALOS
         SET estado = DECODE(v_hay_error,
                             0, 'P',
                             'L'),
             observacion = DECODE(v_hay_error,
                                  0, NULL,
                                  'Consultar trazas en Tabla de Log. Excepción capturada'),
             usu_modificacion = USER,
             fec_modificacion = SYSDATE
         WHERE pri_dia_mes_habil = p_pri_dia_mes_habil
           AND cod_cota_inferior = v_intervalo.cod_cota_inferior
           AND cod_cota_superior = v_intervalo.cod_cota_superior;

         COMMIT;
      END LOOP;

   EXCEPTION
      WHEN OTHERS THEN
         v_traza := SQLERRM;
         PRG_INS_LOG_PROGRAMAS(vg_pkg||'.PR_INT_PROCESAR', 'EXCEPTION | '||v_traza);
         ROLLBACK;

         IF v_intervalo.cod_cota_inferior IS NOT NULL AND v_intervalo.cod_cota_superior IS NOT NULL THEN
            UPDATE GE_EXT_INTERVALOS
            SET estado = 'E',
                observacion = SUBSTR(v_traza, 500),
                usu_modificacion = USER,
                fec_modificacion = SYSDATE
            WHERE pri_dia_mes_habil = p_pri_dia_mes_habil
              AND cod_cota_inferior = v_intervalo.cod_cota_inferior
              AND cod_cota_superior = v_intervalo.cod_cota_superior;

            COMMIT;
         END IF;
   END PR_INT_PROCESAR;

   /*
      17-10-2024  v1.0  LReyes
      Revierte un intervalo determinado, eliminando todos los extractos generados para el mismo.
   */
   PROCEDURE PR_INT_REVERTIR (
      p_pri_dia_mes_habil IN DATE,
      p_fec_ult_extracto  IN DATE,
      p_cod_cota_inferior IN VARCHAR2,
      p_cod_cota_superior IN VARCHAR2,
      p_depura_selector   IN VARCHAR2 DEFAULT 'TODO'
   )
   IS
      v_cod_persona_list  t_cod_persona_table := t_cod_persona_table();
   BEGIN
      --Se listan los Clientes que pertenecen al intervalo
      PR_INT_CLI_LISTAR(p_pri_dia_mes_habil, p_cod_cota_inferior, p_cod_cota_superior, v_cod_persona_list);

      --Se depura la lista de Clientes
      PR_INT_CLI_DEPURAR(p_fec_ult_extracto, v_cod_persona_list, p_depura_selector);

      --Se eliminan los extractos generados para los Clientes listados
      PR_ELI_EXTRACTO(p_fec_ult_extracto, v_cod_persona_list);

      --Se cambia el estado del intervalo para evitar su reproceso, más allá de su resultado
      UPDATE GE_EXT_INTERVALOS
      SET estado = 'I',
          observacion = NULL,
          usu_modificacion = USER,
          fec_modificacion = SYSDATE
      WHERE pri_dia_mes_habil = p_pri_dia_mes_habil
        AND cod_cota_inferior = p_cod_cota_inferior
        AND cod_cota_superior = p_cod_cota_superior;

      COMMIT;
   EXCEPTION
      WHEN OTHERS THEN
         PRG_INS_LOG_PROGRAMAS(vg_pkg||'.PR_INT_REVERTIR', 'EXCEPTION | '||SQLERRM);
         ROLLBACK;
         RAISE;
   END PR_INT_REVERTIR;

   /*
      23-09-2024  v1.0  LReyes
      Revierte todos los intervalos de un determinado mes, eliminando todos los extractos generados para el mismo.
   */
   PROCEDURE PR_INT_REVERTIR (
      p_pri_dia_mes_habil IN DATE,
      p_fec_ult_extracto  IN DATE
   )
   IS
      v_row_count  PLS_INTEGER := 0;
   BEGIN
      --Se iteran los intervalos procesados
      FOR rec IN ( SELECT *
                   FROM ge_ext_intervalos
                   WHERE pri_dia_mes_habil = p_pri_dia_mes_habil
                     AND estado != 'I'
                   ORDER BY prioridad ASC,
                            cod_cota_inferior ASC )
      LOOP
         PR_INT_REVERTIR(
            p_pri_dia_mes_habil,
            p_fec_ult_extracto,
            rec.cod_cota_inferior,
            rec.cod_cota_superior
         );

         v_row_count := v_row_count + 1;
      END LOOP;

      PRG_INS_LOG_PROGRAMAS(vg_pkg||'.PR_INT_REVERTIR', 'Intervalos Revertidos: '||v_row_count);
      COMMIT;
   EXCEPTION
      WHEN OTHERS THEN
         PRG_INS_LOG_PROGRAMAS(vg_pkg||'.PR_INT_REVERTIR', 'EXCEPTION | '||SQLERRM);
         ROLLBACK;
   END PR_INT_REVERTIR;

   /*
      23-09-2024  v1.0  LReyes
      Elimina todos los intervalos ponderados generados para un determinado mes.
   */
   PROCEDURE PR_INT_ELIMINAR (
      p_pri_dia_mes_habil IN DATE
   )
   IS
      v_row_count  PLS_INTEGER := 0;
   BEGIN
      DELETE GE_EXT_INTERVALOS
      WHERE pri_dia_mes_habil = p_pri_dia_mes_habil;

      v_row_count := SQL%ROWCOUNT;
      IF v_row_count > 0 THEN
         PRG_INS_LOG_PROGRAMAS(vg_pkg||'.PR_INT_ELIMINAR', 'Intervalos Eliminados: '||v_row_count);
      END IF;

      COMMIT;
   EXCEPTION
      WHEN OTHERS THEN
         PRG_INS_LOG_PROGRAMAS(vg_pkg||'.PR_INT_ELIMINAR', 'EXCEPTION | '||SQLERRM);
         ROLLBACK;
         RAISE;
   END PR_INT_ELIMINAR;

   /*
      23-09-2024  v1.0  LReyes
      Recuperar la Lista de Clientes que pertenecen a un determinado intervalo ponderado.
   */
   PROCEDURE PR_INT_CLI_LISTAR (
      p_pri_dia_mes_habil IN DATE,
      p_cod_cota_inferior IN VARCHAR2,
      p_cod_cota_superior IN VARCHAR2,
      p_cod_persona_list  OUT t_cod_persona_table
   )
   IS
      v_prioridad  ge_ext_intervalos.prioridad%TYPE;
   BEGIN
      p_cod_persona_list := t_cod_persona_table();

      SELECT prioridad
      INTO v_prioridad
      FROM ge_ext_intervalos
      WHERE pri_dia_mes_habil = p_pri_dia_mes_habil
        AND cod_cota_inferior = p_cod_cota_inferior
        AND cod_cota_superior = p_cod_cota_superior;

      CASE
         WHEN v_prioridad = 1 THEN
            OPEN cur_per_juridicas(p_pri_dia_mes_habil, p_cod_cota_inferior, p_cod_cota_superior);
            FETCH cur_per_juridicas BULK COLLECT INTO p_cod_persona_list;
            CLOSE cur_per_juridicas;
         WHEN v_prioridad IN ( 2, 3 ) THEN
            OPEN cur_per_fisicas(p_pri_dia_mes_habil, v_prioridad-1, p_cod_cota_inferior, p_cod_cota_superior);
            FETCH cur_per_fisicas BULK COLLECT INTO p_cod_persona_list;
            CLOSE cur_per_fisicas;
         ELSE
            raise_application_error(-20001, 'PRIORIDAD DESCONOCIDA ['||v_prioridad||']');
      END CASE;

   EXCEPTION
      WHEN OTHERS THEN
         PRG_INS_LOG_PROGRAMAS(vg_pkg||'.PR_INT_CLI_LISTAR',
                               'Intervalo [ '||p_cod_cota_inferior||' ~ '||p_cod_cota_superior||' ] '||
                               'EXCEPTION | '||SQLERRM);
         IF cur_per_juridicas%ISOPEN THEN
            CLOSE cur_per_juridicas;
         END IF;
         IF cur_per_fisicas%ISOPEN THEN
            CLOSE cur_per_fisicas;
         END IF;
         RAISE;
   END PR_INT_CLI_LISTAR;

   /*
      23-09-2024  v1.0  EMilanese
      Elimina de la lista de Clientes aquellos que deben ser excluidos por distintos motivos.
      Blacklist, tabla que contiene Clientes a ser excluidos por alguna particularidad.
      Extracto ya generado, lógica que evita el reproceso de aquellos Clientes previamente procesados Ok.
   */
   PROCEDURE PR_INT_CLI_DEPURAR (
      p_fec_ult_extracto  IN DATE,
      p_cod_persona_list  IN OUT t_cod_persona_table,
      p_selector          IN VARCHAR2 DEFAULT 'TODO'
   )
   IS
      v_aux_del  t_cod_persona_table := t_cod_persona_table();
      v_aux_out  t_cod_persona_table := t_cod_persona_table();
   BEGIN
      v_aux_out := p_cod_persona_list;

      IF p_selector IN ( 'TODO', 'BLACKLIST' ) THEN
         --Blacklist
         SELECT cli.COLUMN_VALUE cod_persona
         BULK COLLECT INTO v_aux_del
         FROM ge_ext_blacklist blk,
              TABLE(p_cod_persona_list) cli
         WHERE blk.cod_persona = cli.COLUMN_VALUE;

         --Clientes depurados por Blacklist
         v_aux_out := v_aux_out MULTISET EXCEPT v_aux_del;
      END IF;

      IF p_selector IN ( 'TODO', 'MAESTROS_OK' ) THEN
         --Extracto completamente generado y validado Ok
         SELECT cli.COLUMN_VALUE cod_persona
         BULK COLLECT INTO v_aux_del
         FROM TABLE(p_cod_persona_list) cli
         WHERE EXISTS (
                        SELECT 1
                        FROM ge_ext_upd_tbl_maestras
                        WHERE cod_persona = cli.COLUMN_VALUE
                          AND fec_ult_extracto = p_fec_ult_extracto
         );
         
         --Clientes depurados por Extracto ya generado
         v_aux_out := v_aux_out MULTISET EXCEPT v_aux_del;
      END IF;

      p_cod_persona_list.DELETE;
      p_cod_persona_list := v_aux_out;

   EXCEPTION
      WHEN OTHERS THEN
         PRG_INS_LOG_PROGRAMAS(vg_pkg||'.PR_INT_CLI_DEPURAR',
                               'Lista [ '||p_cod_persona_list(p_cod_persona_list.FIRST)||' ~ '||p_cod_persona_list(p_cod_persona_list.LAST)||' ] '||
                               'EXCEPTION | '||SQLERRM);
         RAISE;
   END PR_INT_CLI_DEPURAR;

   /*
      23-09-2024  v1.0  LReyes
      Genera Extractos a partir de la Lista de Clientes parametrizada.
   */ 
   PROCEDURE PR_GEN_EXTRACTO (
      p_frecuencia       IN VARCHAR2 DEFAULT 'M',
      p_cod_persona_list IN t_cod_persona_table
   )
   IS
      -- Definicion de Variables Globales
      v_lugar             VARCHAR2(2000) := 'Iniciando';
      v_cod_persona       ba_personas.cod_persona%TYPE;
      v_nro_cuenta        ge_cta_clientes.nro_cuenta%TYPE;
      v_cod_extracto      ge_ext_clientes.cod_extracto%TYPE;
      v_cod_ext_separado  ge_ext_clientes.cod_extracto%TYPE;
      v_cod_modalidad     ge_modalidades.cod_modalidad%TYPE;
      ---
      v_fec_actual        ge_calendarios.fec_actual%TYPE;
      v_pri_dia_mes_habil ge_calendarios.pri_dia_mes_habil%TYPE;
      v_inserta           VARCHAR2(1);
      v_frecuencia        VARCHAR2(1);
      --- Variables de Datos de Direccion
      v_dir_cliente       ge_ext_clientes.direccion%TYPE;
      v_pri_obs_dir       ge_ext_clientes.det_direccion%TYPE;
      v_seg_obs_dir       ge_ext_clientes.observacion%TYPE;
      v_cod_pais          ge_ext_clientes.cod_pais%TYPE;
      v_cod_ciudad        ge_ext_clientes.cod_ciudad%TYPE;
      v_des_barrio        ge_ext_clientes.barrio%TYPE;
      v_tel_cliente       ge_ext_clientes.telefono%TYPE;
      v_tip_envio         ge_dir_envios.tip_envio%TYPE;
      --sergio CROGENEXT
      v_piso              VARCHAR2(2000);
      v_departamento      VARCHAR2(2000);
      v_edificio          VARCHAR2(2000);
      v_direccion         VARCHAR2(2000);
      --Sergio CROGENEXT-14 11-03-2015: control de dirección extractos
      v_tip_gen_extracto  VARCHAR2(1);--I = Individual / C = Consolidado
      v_es_nomina         VARCHAR2(1);-- S =  es nómina / N = no es nómina
      --- Variables de Datos del Oficial
      v_es_empleado       VARCHAR2(1);
      v_cli_confidencial  VARCHAR2(1);
      v_cat_riesgo        ge_clientes.cat_riesgo%TYPE;
      v_fec_ult_clasif    ge_clientes.fec_ult_clasif%TYPE;
      v_cod_ofi_cliente   NUMBER(4);
      v_cod_usu_oficial   ge_clientes.cod_usu_oficial%TYPE;
      v_tel_oficial       ba_oficinas.telefono%TYPE;
      v_int_oficial       ba_usuarios.nro_interno%TYPE;
      v_tip_extracto      ge_clientes.tip_extracto%TYPE;
      ---
      v_fec_movimiento    ge_calendarios.fec_actual%TYPE;
      v_sal_actual        ge_ext_cli_cuentas.sal_actual%TYPE;
      v_nom_cliente       ba_personas.nom_completo%TYPE;
      v_mto_bloqueo       NUMBER;
      v_sal_blo_anterior  NUMBER;
      v_cod_per_ente      ge_entes.cod_persona%TYPE;
      v_msj               VARCHAR2(500) := NULL;
      v_initial_time      PLS_INTEGER := DBMS_UTILITY.get_time;
      v_inicio            PLS_INTEGER := DBMS_UTILITY.get_time;
      v_fec_inicio        TIMESTAMP := SYSTIMESTAMP;
      v_fec_fin           TIMESTAMP;
      v_duracion_seg      NUMBER;
      v_det_error         VARCHAR2(4000);
      v_des_mes_proceso   VARCHAR2(30) := UPPER(TRIM(TO_CHAR(vg_fec_ult_cierre_mes, 'fmMonth', 'NLS_DATE_LANGUAGE=SPANISH')));
      v_cant_clientes_procesados  PLS_INTEGER := 0;
      v_cant_cuentas_procesadas   PLS_INTEGER := 0;
      v_cant_movimientos_gen      PLS_INTEGER := 0;
      v_estado_maestras           VARCHAR2(20) := 'OK';
      --@LReyes --Nuevo cursor unificado
      CURSOR cur_principal IS
         with mae_cli as (
            SELECT DISTINCT
               ge_cta_clientes.cod_persona
            FROM
               ge_cuentas,
               ge_cta_clientes,
               TABLE(p_cod_persona_list) cli
            WHERE
                  ge_cuentas.cod_modulo = ge_cta_clientes.cod_modulo
               AND ge_cuentas.cod_modalidad = ge_cta_clientes.cod_modalidad
               AND ge_cuentas.cod_oficina = ge_cta_clientes.cod_oficina
               AND ge_cuentas.nro_cuenta = ge_cta_clientes.nro_cuenta
               AND ge_cuentas.fre_extracto = 'M'
               AND ge_cta_clientes.relacion = 'P'
               AND ge_cta_clientes.cod_persona = cli.COLUMN_VALUE
               AND ge_cuentas.cod_modulo != 5
               AND ( ( ge_cuentas.estado NOT IN ( 'X', 'A', 'C', 'P' ) )
                     OR ( ge_cuentas.estado IN ( 'C', 'P' )
                          AND ge_cuentas.fec_modificacion >= v_pri_dia_mes_habil ) )
         ),
         ctas as (
            SELECT DISTINCT
               mae_cli.cod_persona,
               ge_cta_clientes.cod_modulo,
               decode(ge_cta_clientes.cod_modulo,
                      3, ge_cta_clientes.cod_modalidad,
                      4, decode(ge_cta_clientes.cod_modalidad,
                                41, 41,
                                43),
                      ge_cta_clientes.cod_modulo) cod_modalidad
            FROM
               ge_cta_clientes,
               mae_cli
            WHERE
                  ge_cta_clientes.cod_persona = mae_cli.cod_persona
               AND ge_cta_clientes.relacion = 'P'
               AND ge_cta_clientes.cod_modulo BETWEEN 3 AND 6
            ORDER BY
               mae_cli.cod_persona,
               decode(ge_cta_clientes.cod_modulo,
                      4, 1,
                      3, decode(ge_cta_clientes.cod_modulo,
                                3, ge_cta_clientes.cod_modalidad,
                                4, decode(ge_cta_clientes.cod_modalidad,
                                          41, 41,
                                          43),
                                ge_cta_clientes.cod_modulo))
         )
         SELECT
               cod_persona,
               cod_modulo,
               cod_modalidad
         FROM
            ctas;

      -- @LReyes - CREATE TYPE a nivel Package Spec
      mae_cli_ctas_list t_cta_table;

      -- @LReyes - Declaramos una colección asociativa
      TYPE t_assoc_array IS TABLE OF PLS_INTEGER INDEX BY VARCHAR2(10);
      ge_ext_cli_cuentas_collection t_assoc_array;

      ---
      --Generar movimientos retenidos por cuenta
      PROCEDURE lp_generar_mov_retenciones (
         p_nro_cuenta IN VARCHAR2
      )
      IS
      BEGIN
         BEGIN
            pre_ini_aplicacion;
            pae_cnf.g_cod_modulo := 1;
         END;
         v_lugar := 'lp_generar_mov_retenciones. Cta ' || p_nro_cuenta;

         INSERT INTO ge_ext_cli_mov_retenidos (
            fec_extracto,
            cod_retencion,
            nro_documento,
            cod_persona,
            monto,
            fec_movimiento,
            fec_liberacion,
            nro_cuenta,
            cod_modulo,
            cod_modalidad,
            fre_extracto,
            cod_extracto
         ) 
         SELECT
            v_fec_actual,
            ah_retenciones.cod_retencion,
            ah_retenciones.nro_documento,
            v_cod_persona,
            ah_retenciones.sal_retenido,--Se modifico el campo MONTO x SAL_RETENIDO <<EF,09/09/2009>>
            ah_retenciones.fec_inicio,
            ah_retenciones.fec_final,
            ah_retenciones.nro_cuenta,
            ah_retenciones.cod_modulo,
            ah_retenciones.cod_modalidad,
            v_frecuencia,
            v_cod_extracto
         FROM
            ah_retenciones
         WHERE
               ah_retenciones.nro_cuenta = p_nro_cuenta
            AND ah_retenciones.cod_modalidad IN ( 31, 41 )
            AND ah_retenciones.liberado = 'N'
            AND ah_retenciones.fec_final > v_fec_actual;
      END lp_generar_mov_retenciones;
      ---
      --Generar movimientos pendientes de pago por cuenta
      PROCEDURE lp_generar_mov_pendientes (
         p_nro_cuenta IN VARCHAR2
      )
      IS
      BEGIN
         v_lugar := 'lp_generar_mov_pendientes. Cta ' || p_nro_cuenta;
         INSERT INTO ge_ext_cli_mov_pendientes (
            fec_extracto,
            tip_comision,
            cod_persona,
            monto,
            fec_movimiento,
            nro_cuenta,
            cod_modulo,
            cod_modalidad,
            fre_extracto,
            cod_extracto,
            descripcion
         )
         SELECT
            v_fec_actual,
            ge_mov_pendientes.cod_transaccion,
            v_cod_persona,
            ge_mov_pendientes.monto,
            ge_mov_pendientes.fecha,
            ge_mov_pendientes.nro_cuenta,
            ge_mov_pendientes.cod_modulo,
            ge_mov_pendientes.cod_modalidad,
            v_frecuencia,
            v_cod_extracto,
            fug_obt_des_transaccion(cod_mod_padre, cod_mad_padre, cod_tra_padre) descripcion
         FROM
            ge_mov_pendientes
         WHERE
               ge_mov_pendientes.nro_cuenta = p_nro_cuenta
            AND ge_mov_pendientes.cod_modalidad IN ( 31, 41 )
            AND ge_mov_pendientes.estado = 'I'
            AND ge_mov_pendientes.fecha <= v_fec_actual;
      END lp_generar_mov_pendientes;

      FUNCTION lf_obt_per_ente (
         p_cod_ente ge_entes.cod_ente%TYPE
      ) RETURN VARCHAR2 IS
         vcod_per_ente ge_entes.cod_persona%TYPE;
      BEGIN
         SELECT
            cod_persona
         INTO vcod_per_ente
         FROM
            ge_entes
         WHERE
            cod_ente = p_cod_ente;

         IF vcod_per_ente IS NOT NULL THEN
            RETURN vcod_per_ente;
         ELSE
            RETURN NULL;
         END IF;
      EXCEPTION
         WHEN no_data_found THEN
            RETURN NULL;
         WHEN OTHERS THEN
            RETURN NULL;
      END;
      --
      FUNCTION lf_obt_mto_bloqueado (
         p_nro_cuenta IN VARCHAR2
      ) RETURN NUMBER IS
         vmto_bloqueo NUMBER DEFAULT 0;
      BEGIN
         SELECT
            nvl(SUM(monto),
                0)
         INTO vmto_bloqueo
         FROM
            ge_bloqueos
         WHERE
            cod_causa IN (
               SELECT
                  cod_causa
               FROM
                  ge_par_causales
               WHERE
                     parametro = 'COD_CAU_BLO_EXT'
                  AND val_parametro = 'S'
            )
            AND nro_cuenta = p_nro_cuenta;

         RETURN vmto_bloqueo;
      EXCEPTION
         WHEN no_data_found THEN
            RETURN 0;
         WHEN OTHERS THEN
            RETURN 0;
      END;

      FUNCTION lf_obt_sal_blo_anterior (
         p_nro_cuenta   IN VARCHAR2,
         p_fec_extracto IN DATE
      ) RETURN NUMBER IS
         vmto_bloqueo NUMBER DEFAULT 0;
      BEGIN
         SELECT
            sal_bloqueado
         INTO vmto_bloqueo
         FROM
            ge_ext_cli_cuentas
         WHERE
               nro_cuenta = p_nro_cuenta
            AND fec_extracto = p_fec_extracto;

         RETURN vmto_bloqueo;
      EXCEPTION
         WHEN no_data_found THEN
            RETURN 0;
         WHEN OTHERS THEN
            RETURN 0;
      END;

      PROCEDURE lp_eli_ext_generado IS
      BEGIN
         DELETE ge_ext_cli_movimientos
         WHERE
               fec_extracto = v_fec_actual
            AND upper(fre_extracto) = v_frecuencia;

         DELETE ge_ext_resumenes a
         WHERE
               fec_extracto = v_fec_actual
            AND upper(fre_extracto) = v_frecuencia;

         DELETE ge_ext_cli_cuentas a
         WHERE
               fec_extracto = v_fec_actual
            AND upper(fre_extracto) = v_frecuencia;

         DELETE ge_ext_clientes
         WHERE
               fec_extracto = v_fec_actual
            AND upper(fre_extracto) = v_frecuencia;

         DELETE ge_ext_cli_mov_retenidos
         WHERE
            fec_extracto = v_fec_actual;

      END;

      PROCEDURE lp_obtener_datos_del_cliente IS
      BEGIN
         v_lugar := 'lp_obtener_datos_del_cliente';
         SELECT
            ge_clientes.cod_usu_oficial,
            ba_usuarios.telefono,
            ba_usuarios.nro_interno,
            ge_clientes.tip_extracto,
            ge_clientes.cod_oficina,
            ge_clientes.cli_confidencial,
            nom_completo,
            pap_cat.fu_obt_cat_crc(v_cod_persona, v_fec_actual, 'N'),
            ge_clientes.fec_ult_clasif
         INTO
            v_cod_usu_oficial,
            v_tel_oficial,
            v_int_oficial,
            v_tip_extracto,
            v_cod_ofi_cliente,
            v_cli_confidencial,
            v_nom_cliente,
            v_cat_riesgo,
            v_fec_ult_clasif
         FROM
            ba_personas,
            ba_oficinas,
            ba_usuarios,
            ge_clientes
         WHERE
               ge_clientes.cod_persona = v_cod_persona
            AND ba_usuarios.cod_usuario = ge_clientes.cod_usu_oficial
            AND ba_oficinas.cod_oficina = ba_usuarios.cod_oficina
            AND ge_clientes.cod_persona = ba_personas.cod_persona;

         v_es_empleado := fug_es_empleado(v_cod_persona);
      EXCEPTION
         WHEN OTHERS THEN
            v_es_empleado := 'N';
            v_tel_oficial := NULL;
            v_int_oficial := NULL;
            v_tip_extracto := NULL;
            v_cod_ofi_cliente := NULL;
            v_cli_confidencial := NULL;
            v_cat_riesgo := NULL;
            v_fec_ult_clasif := NULL;
            v_cod_usu_oficial := NULL;
            v_nom_cliente := NULL;
      END lp_obtener_datos_del_cliente;

      PROCEDURE lp_dir_envio IS
      BEGIN
         v_lugar := 'lp_dir_envio';
          ---0. limpio los valores a leer ------------------------------------
         v_dir_cliente := NULL;
         v_pri_obs_dir := NULL;
         v_seg_obs_dir := NULL;
         v_cod_pais := NULL;
         v_cod_ciudad := NULL;
         v_des_barrio := NULL;
         v_tel_cliente := NULL;
         v_tip_envio := NULL;
         v_direccion := NULL;
          ---1. Leo la vista de acuerdo a los datos que me pasa --------------
         SELECT
            substr(gv.dir_envio, 1, 89),
            gv.prim_observacion,
            gv.seg_observacion,
            gv.cod_pais,
            gv.cod_ciudad,
            gv.des_barrio,
            gv.tel_principal,
            gv.tip_envio,
            gv.piso,
            gv.departamento,
            gv.edificio
         INTO
            v_dir_cliente,
            v_pri_obs_dir,
            v_seg_obs_dir,
            v_cod_pais,
            v_cod_ciudad,
            v_des_barrio,
            v_tel_cliente,
            v_tip_envio,
            v_piso,
            v_departamento,
            v_edificio
         FROM
            gv_dir_envios gv
         WHERE
             --Cliente gen. Individual (dirección personalizada por cuenta)
            ( ( gv.nro_cuenta = v_nro_cuenta
                AND nvl(v_tip_gen_extracto, 'C') = 'I'
                AND gv.cod_persona = v_cod_persona
                AND nvl(v_es_nomina, 'N') = 'N' )
              OR
             --Cliente gen. Consolidada (dirección personalizada por dirección de envío)
               ( gv.nro_cuenta IS NULL
                   AND nvl(v_tip_gen_extracto, 'C') = 'C'
                   AND gv.cod_persona = v_cod_persona
                   AND nvl(v_es_nomina, 'N') = 'N' )
              OR
             --Cliente NÓMINA gen. Consolidada/individual (se tiene que traer la dirección principal del ente.)
               ( gv.nro_cuenta IS NULL
                   AND nvl(v_es_nomina, 'N') = 'S'
                   AND gv.cod_persona = v_cod_per_ente
                   AND gv.nro_cuenta IS NULL ) );

                  --se obtiene el piso-edificio-dpto si es que no se retiene el extracto
         IF instr(v_dir_cliente, 'RETENER EN ') = 0 THEN
            IF v_piso IS NOT NULL THEN
               v_direccion := ' Piso: ' || v_piso;
            END IF;
            IF v_departamento IS NOT NULL THEN
               v_direccion := v_direccion
                              || ' Dpto.: '
                              || v_departamento;
            END IF;

            IF v_edificio IS NOT NULL THEN
               v_direccion := v_direccion
                              || ' Edificio: '
                              || v_edificio;
            END IF;

            v_dir_cliente := substr(v_dir_cliente || v_direccion, 1, 89);
         END IF;
      EXCEPTION
         WHEN no_data_found THEN
            NULL;
         WHEN too_many_rows THEN
            NULL;
         WHEN OTHERS THEN
            v_lugar := substr(v_cod_persona
                              || '-'
                              || v_dir_cliente, 1, 2000);
      END lp_dir_envio;

      PROCEDURE lp_generar_ctacte
      IS
         v_sal_ult_extracto  NUMBER(18, 2) DEFAULT 0;
         v_mto_debito        NUMBER(18, 2);
         v_mto_credito       NUMBER(18, 2);
         v_mto_deb           NUMBER(18, 2);
         v_mto_cre           NUMBER(18, 2);
         v_can               NUMBER(06) := 0;
         v_existe            VARCHAR2(01) := 'N';
         v_tiene_mov         VARCHAR2(01) := 'N';
         v_cantidad          NUMBER := 0;-- TN-1003 EFMILANES: se paso de NUMBER(6) a NUMBER porque quedo chica
         v_imprime_extracto  VARCHAR2(1);
         v_sal_acumulado     cc_sal_mensuales.sal_acu_deudor%TYPE;
         v_can_dia_acumulado cc_sal_mensuales.can_dia_acumulado%TYPE;
         v_sal_promedio      cc_sal_mensuales.sal_acu_deudor%TYPE;
         v_nro_cta_combinada cc_cta_combinadas.nro_cta_ahorro%TYPE;
         v_val_tasa          ge_tas_fechas.val_tasa%TYPE;
         v_val_tae           ge_tas_fechas.val_tasa%TYPE;
         v_mto_linea         cc_lin_sobregiros.monto%TYPE;
         v_fec_vto_linea     cc_lin_sobregiros.fec_vencimiento%TYPE;
         v_tipo              ge_ext_cli_cuentas.tip_cuenta%TYPE;
         v_tip_resumen       ge_ext_resumenes.tipo%TYPE;
         v_sal_disponible    ge_ext_resumenes.sal_disponible%TYPE;
         ts_inicio          TIMESTAMP;
         ts_fin             TIMESTAMP;
         v_cant_mov         NUMBER;

         ----------------------------------
         -- CURSOR DEL ARCHIVO PRINCIPAL --
         ----------------------------------
         CURSOR mae_cue IS
         with cuentas AS (
            SELECT
               cli.cod_persona,
               ge_cta_clientes.cod_modulo,
               ge_cta_clientes.cod_modalidad,
               ge_cta_clientes.cod_oficina,
               ge_cta_clientes.nro_cuenta,
               cc_cta_corrientes.cod_moneda,
               cc_cta_corrientes.sal_ult_extracto,
               nvl(cc_cta_corrientes.nro_folio, 0) + 1                                     nro_folio,
               cc_cta_corrientes.denominacion,
               cc_cta_corrientes.sal_ret_batch,
               nvl(cc_cta_corrientes.fec_ult_extracto, cc_cta_corrientes.fec_apertura - 1) fec_ult_extracto,
               nvl(bpd.val_parametro, 'C')                                                 separado,
               cc_cta_corrientes.fec_apertura,
               cc_cta_corrientes.rowid                                                     registro,
               cc_cta_corrientes.cta_combinada,
               cc_cta_corrientes.tas_personalizada,
               cc_cta_corrientes.sal_total - cc_cta_corrientes.sal_retenido                saldo,
               cc_cta_corrientes.sal_bloqueado,
               cc_cta_corrientes.cod_ente,
               decode(cc_cta_corrientes.cod_ente, NULL, 'N', 'S')                          es_nomina,--se obtiene si es nómina
               nvl(ge_paq_cuentas.cod_paquete, 0)                                          cod_paquete
            FROM
               ge_dir_envios,
               cc_cta_corrientes,
               ge_cta_clientes,
               ge_paq_cuentas,
               ba_per_dat_adicionales bpd,
               TABLE(mae_cli_ctas_list) cli
            WHERE
                  ge_dir_envios.cod_persona (+) = ge_cta_clientes.cod_persona--CROGENEXT-13 Sergio Servín 06/08/2014,
               AND ge_dir_envios.nro_cuenta (+) = ge_cta_clientes.nro_cuenta--CROGENEXT-13 Sergio Servín 06/08/2014,
               AND ge_cta_clientes.cod_persona = cli.cod_persona
               AND cli.cod_modulo = 4
               AND cli.cod_modalidad = 41
               AND ge_cta_clientes.relacion = 'P'
               AND cc_cta_corrientes.cod_modulo = ge_cta_clientes.cod_modulo
               AND cc_cta_corrientes.cod_modalidad = ge_cta_clientes.cod_modalidad
               AND cc_cta_corrientes.cod_oficina = ge_cta_clientes.cod_oficina
               AND cc_cta_corrientes.nro_cuenta = ge_cta_clientes.nro_cuenta
               AND cc_cta_corrientes.fre_extracto = v_frecuencia--CROGENEXT-13 Sergio Servín 06/08/2014
               AND bpd.cod_persona (+) = ge_cta_clientes.cod_persona
               AND bpd.parametro (+) = 'TIP_GEN_EXTRACTOS'
               AND ( ( cc_cta_corrientes.estado NOT IN ( 'C', 'P' ) )
                     OR ( cc_cta_corrientes.estado IN ( 'C', 'P' )
                          AND cc_cta_corrientes.fec_ult_movimiento >= v_pri_dia_mes_habil
                          AND cc_cta_corrientes.fec_ult_movimiento > nvl(cc_cta_corrientes.fec_ult_extracto, cc_cta_corrientes.fec_apertura - 1
                          ) ) )
               AND ge_paq_cuentas.nro_cuenta (+) = ge_cta_clientes.nro_cuenta
               AND ge_paq_cuentas.cod_persona (+) = ge_cta_clientes.cod_persona
         ),
         movimientos AS (
            SELECT
               cuentas.cod_persona,
               cuentas.nro_cuenta,
               cuentas.cod_modulo,
               cuentas.cod_modalidad,
               cuentas.cod_oficina,
               SUM(decode(fug_obt_tra_tipo(ge_transacciones.cod_transaccion, ge_transacciones.tipo, ge_transacciones.afecta),
                        'D',
                        nvl(cc_movimientos_his.monto, 0),
                        0)) mto_debito,
               SUM(decode(fug_obt_tra_tipo(ge_transacciones.cod_transaccion, ge_transacciones.tipo, ge_transacciones.afecta),
                        'C',
                        nvl(cc_movimientos_his.monto, 0),
                        0)) mto_credito,
               COUNT('X')   cantidad
            FROM
               ge_transacciones,
               cc_movimientos_his,
               cuentas
            WHERE
                  cc_movimientos_his.cod_modulo = cuentas.cod_modulo
               AND cc_movimientos_his.cod_modalidad = cuentas.cod_modalidad
               AND cc_movimientos_his.cod_oficina = cuentas.cod_oficina
               AND cc_movimientos_his.nro_cuenta = cuentas.nro_cuenta
               AND cc_movimientos_his.fecha > nvl(cuentas.fec_ult_extracto, cuentas.fec_apertura - 1) --:v_fec_movimiento
               AND cc_movimientos_his.fecha <= v_fec_actual
               AND ( cc_movimientos_his.reversado = 'N'
                     OR ( cc_movimientos_his.reversado = 'S'
                        AND fec_valor <= nvl(cuentas.fec_ult_extracto, cuentas.fec_apertura - 1) --:v_fec_movimiento
                        AND EXISTS (
                  SELECT
                     1
                  FROM
                     cc_movimientos_his rev  -- CB. 25/09/2013.
                  WHERE
                        cc_movimientos_his.fec_valor = rev.fecha
                     AND cc_movimientos_his.hor_reversion = rev.hora
                     AND cc_movimientos_his.cod_usu_reversion = rev.cod_usuario
                     AND cc_movimientos_his.nro_secuencia = rev.nro_secuencia
                              -- DYDMR-5672 NAF 01/2017
                     AND cc_movimientos_his.nro_cuenta = rev.nro_cuenta
                     AND abs(cc_movimientos_his.monto) = abs(rev.monto)
               ) )
                     OR ( cc_movimientos_his.reversado = 'S'
                        AND cc_movimientos_his.cod_tra_padre IN ( 303, 302 )
                        AND cc_movimientos_his.cod_mad_padre = 455 ) )
               AND cc_movimientos_his.estado = 'N'
               AND cc_movimientos_his.cod_modulo = ge_transacciones.cod_modulo
               AND cc_movimientos_his.cod_modalidad = ge_transacciones.cod_modalidad
               AND cc_movimientos_his.cod_transaccion = ge_transacciones.cod_transaccion
               AND ge_transacciones.ve_cliente = 'S'
               AND ge_transacciones.tipo IN ( 'C', 'D' )
               AND nvl(ge_transacciones.afecta, 'XX') != 'B'
            GROUP BY
               cuentas.cod_persona,
               cuentas.nro_cuenta,
               cuentas.cod_modulo,
               cuentas.cod_modalidad,
               cuentas.cod_oficina
         )
         SELECT cuentas.*,
                NVL(movimientos.mto_debito, 0)  mto_debito,
                NVL(movimientos.mto_credito, 0) mto_credito,
                NVL(movimientos.cantidad, 0)    cantidad
         FROM cuentas
         LEFT JOIN movimientos
         ON cuentas.cod_persona = movimientos.cod_persona
            AND cuentas.nro_cuenta = movimientos.nro_cuenta
            AND cuentas.cod_modulo = movimientos.cod_modulo
            AND cuentas.cod_modalidad = movimientos.cod_modalidad
            AND cuentas.cod_oficina = movimientos.cod_oficina
         ORDER BY
            cuentas.cod_persona;

         mov_masivos_list t_mov_mas_table := t_mov_mas_table();
         
         CURSOR cur_mov_ctacte IS
         SELECT
            mov.cod_persona,
            v_fec_actual fec_actual,
            cc_movimientos_his.fecha,
            cc_movimientos_his.fec_valor,
            cc_movimientos_his.hora,
            cc_movimientos_his.nro_cuenta,
            cc_movimientos_his.nro_documento,
            cc_movimientos_his.cod_mod_padre,
            cc_movimientos_his.cod_mad_padre,
            cc_movimientos_his.cod_tra_padre,
            ( decode(fug_obt_tra_tipo(ge_transacciones.cod_transaccion, ge_transacciones.tipo, ge_transacciones.afecta),
                     'D',
                     nvl(cc_movimientos_his.monto, 0),
                     0) ) monto_D,
            ( decode(fug_obt_tra_tipo(ge_transacciones.cod_transaccion, ge_transacciones.tipo, ge_transacciones.afecta),
                     'C',
                     nvl(cc_movimientos_his.monto, 0),
                     0) ) monto_C,
            1 cod_extracto, 
            v_frecuencia frecuencia,
            cc_movimientos_his.nro_secuencia,
            cc_movimientos_his.cod_ofi_origen,
            cc_movimientos_his.fec_insercion,
            decode(ge_transacciones.afecta, 'B', 'S', 'N') ind_bloqueo
         FROM
            ge_transacciones,
            cc_movimientos_his,
            TABLE(mov_masivos_list) mov
         WHERE
               cc_movimientos_his.cod_modulo = mov.cod_modulo
            AND cc_movimientos_his.cod_modalidad = mov.cod_modalidad
            AND cc_movimientos_his.cod_oficina = mov.cod_oficina
            AND cc_movimientos_his.nro_cuenta = mov.nro_cuenta
            AND cc_movimientos_his.fecha > mov.fec_movimiento
            AND cc_movimientos_his.fecha <= v_fec_actual
            AND ( cc_movimientos_his.reversado = 'N'
                  OR ( cc_movimientos_his.reversado = 'S'
                       AND fec_valor <= mov.fec_movimiento 
                       AND EXISTS (
               SELECT
                  1
               FROM
                  cc_movimientos_his rev  -- CB. 25/09/2013.
               WHERE
                     cc_movimientos_his.fec_valor = rev.fecha
                  AND cc_movimientos_his.hor_reversion = rev.hora
                  AND cc_movimientos_his.cod_usu_reversion = rev.cod_usuario
                  AND cc_movimientos_his.nro_secuencia = rev.nro_secuencia
                          -- DYDMR-5672 NAF 01/2017
                  AND cc_movimientos_his.nro_cuenta = rev.nro_cuenta
                  AND abs(cc_movimientos_his.monto) = abs(rev.monto)
            ) )
                  OR ( cc_movimientos_his.reversado = 'S'
                       AND cc_movimientos_his.cod_tra_padre IN ( 303, 302 )
                       AND cc_movimientos_his.cod_mad_padre = 455 ) )
            AND cc_movimientos_his.estado = 'N'
            AND cc_movimientos_his.cod_modulo = ge_transacciones.cod_modulo
            AND cc_movimientos_his.cod_modalidad = ge_transacciones.cod_modalidad
            AND cc_movimientos_his.cod_transaccion = ge_transacciones.cod_transaccion
            AND ge_transacciones.ve_cliente = 'S'
            AND ge_transacciones.tipo IN ( 'C', 'D' )
            AND nvl(ge_transacciones.afecta, 'XX') != 'B';
                             
         TYPE t_cur_mov_ctacte_type IS TABLE OF cur_mov_ctacte%rowtype;
         t_cur_mov_ctacte  t_cur_mov_ctacte_type;

         v_count_loop PLS_INTEGER := 0;
      BEGIN
         v_lugar := 'lp_generar_ctacte';
         v_cod_persona := -1;
         v_initial_time := DBMS_UTILITY.get_time;
         
         v_inicio := DBMS_UTILITY.get_time;
         v_fec_inicio := SYSTIMESTAMP;
         
         FOR av IN mae_cue LOOP
            BEGIN
                v_count_loop := v_count_loop + 1;
    
                IF v_cod_persona != av.cod_persona THEN
                   --Inicializo la variable que separa los extractos especificos
                   v_cod_persona := av.cod_persona;
                   v_cod_extracto := 1;
                   v_inserta := 'N';
                   IF NOT ge_ext_cli_cuentas_collection.EXISTS(av.cod_persona) THEN
                      ge_ext_cli_cuentas_collection(av.cod_persona) := -1;
                   END IF;
                END IF;
    
                --limpio variables
                v_sal_promedio := NULL;
                v_nro_cta_combinada := NULL;
                v_val_tasa := NULL;
                v_val_tae := NULL;
                v_cod_per_ente := lf_obt_per_ente(av.cod_ente);
                --- asigno el codigo de extracto unico -----------------
                v_nro_cuenta := av.nro_cuenta;
                v_sal_ult_extracto := nvl(av.sal_ult_extracto, 0);
                v_tiene_mov := 'N';
                v_cantidad := 0;
                v_mto_bloqueo := lf_obt_mto_bloqueado(av.nro_cuenta);
                v_fec_movimiento := nvl(av.fec_ult_extracto, av.fec_apertura - 1);
    
                --SE CAPTURA LOS DATOS PARA OBTENER LA DIRECCION CORRECTA DEL EXTRACTO :SServin 13-03-2015 CROGENEXT-14
                v_tip_gen_extracto := av.separado;--se obtiene si es individual o consolidado
                --se obtiene si es nómina o no--
                v_es_nomina := av.es_nomina;
                -----
    
                --@LReyes --la suma de todos los movimientos del historico ahora disponible en el Cursor
                v_mto_debito := av.mto_debito;
                v_mto_credito := av.mto_credito;
                v_cantidad := av.cantidad;
    
                -- SDC - AP 897/8 - Ingresa solo si no hay movimientos entonces busca si existe movimiento por bloqueo
                -- Aqui no se incluyen los Bloqueos para Act. el Sal Anterior.
    
                IF nvl(v_cantidad, 0) > 0 OR nvl(v_can, 0) > 0 THEN
                   v_tiene_mov := 'S';
                END IF;
    
                v_existe := 'N';
    
                --IF AV.SEPARADO = 'S' OR AV.COD_PAQUETE > 0  THEN --CROGENEXT-13 Sergio Servín 06/08/2014
                IF av.separado = 'I' OR av.cod_paquete > 0 THEN
                   --@LReyes --Array asociativo. Clave(cod_persona) Valor(cuenta para cod_extracto)
                   IF ge_ext_cli_cuentas_collection(av.cod_persona) < 0 THEN
                      ge_ext_cli_cuentas_collection(av.cod_persona) := 1;
                   ELSE
                      ge_ext_cli_cuentas_collection(av.cod_persona) := ge_ext_cli_cuentas_collection(av.cod_persona) + 1;
                   END IF;
                   v_cod_extracto := ge_ext_cli_cuentas_collection(av.cod_persona);
                   ---------------------------------------------------------
                ELSE
                   --@LReyes --Dado que se itera por cod_cliente ordenado, buscamos pre-existencia en el Array asociativo
                   IF ge_ext_cli_cuentas_collection(av.cod_persona) < 0 THEN
                      ge_ext_cli_cuentas_collection(av.cod_persona) := 1;
                      v_existe := 'N';
                   ELSE
                      v_existe := 'S';
                   END IF;
                   v_cod_extracto := ge_ext_cli_cuentas_collection(av.cod_persona);
                END IF;
    
                IF v_existe = 'N' THEN
                   -- busco los datos del cliente ---------------------------
                   lp_obtener_datos_del_cliente;
                   lp_dir_envio;
                   v_imprime_extracto := v_tip_extracto;
                   v_lugar := 'lp_generar_ctacte: 1-insert GE_EXT_CLIENTES '
                              || v_cod_persona
                              || '-'
                              || v_dir_cliente;
                   INSERT INTO ge_ext_clientes (
                      cod_persona,
                      fec_extracto,
                      fre_extracto,
                      funcionario,
                      nom_cliente,
                      direccion,
                      telefono,
                      cod_usu_oficial,
                      cod_pais,
                      cod_ciudad,
                      tel_oficial,
                      nro_interno,
                      cod_extracto,
                      det_direccion,
                      observacion,
                      barrio,
                      cod_mensaje,
                      tip_impresion,
                      cli_confidencial,
                      cod_oficina,
                      cat_riesgo,
                      fec_ult_clasif,
                      cod_per_empresa,
                      tip_direccion
                   ) VALUES (
                      v_cod_persona,
                      v_fec_actual,
                      v_frecuencia,
                      v_es_empleado,
                      v_nom_cliente,
                      v_dir_cliente,
                      v_tel_cliente,
                      v_cod_usu_oficial,
                      v_cod_pais,
                      v_cod_ciudad,
                      v_tel_oficial,
                      v_int_oficial,
                      v_cod_extracto,
                      v_pri_obs_dir,
                      v_seg_obs_dir,
                      v_des_barrio,
                      '1',
                      v_imprime_extracto,
                      v_cli_confidencial,
                      decode(av.separado, 'I', av.cod_oficina, v_cod_ofi_cliente),
                      v_cat_riesgo,
                      v_fec_ult_clasif,
                      v_cod_per_ente,
                      v_tip_envio
                   );
    
                   v_inserta := 'S';
                END IF;
    
                v_lugar := 'lp_generar_ctacte: Cta.combinada';
                --busca la cuenta combinada si corresponde
                IF av.cta_combinada = 'S' THEN
                   BEGIN
                      SELECT
                         nro_cta_ahorro
                      INTO v_nro_cta_combinada
                      FROM
                         cc_cta_combinadas
                      WHERE
                         nro_cta_cte = av.nro_cuenta;
    
                   EXCEPTION
                      WHEN no_data_found THEN
                         NULL;
                      WHEN OTHERS THEN
                         NULL;
                   END;
                END IF;
                
                
                --obtiene saldo promedio
                v_lugar := 'lp_generar_ctacte: Saldo Promedio';
                pag_cta.pr_obt_sal_promedio(av.cod_modulo, av.cod_modalidad, av.cod_oficina, av.nro_cuenta, v_fec_actual,
                                           v_fec_actual, v_sal_acumulado, v_sal_promedio, v_can_dia_acumulado);
                
                --- cargo los valores para el calculo de la tasa --                
                v_lugar := 'lp_generar_ctacte: Tasa de la Cuenta';
                v_val_tasa := fug_obt_val_tasa(av.cod_modulo, av.cod_modalidad, av.cod_oficina, av.nro_cuenta, av.cod_moneda,
                                              v_sal_promedio, av.tas_personalizada, NULL, 550, v_fec_actual);--busca x la transaccion de sobregiro
                
                --obtiene tae
                v_lugar := 'lp_generar_ctacte: Tae';    
                v_val_tae := pas_bcp.fu_obt_tae(v_val_tasa, 30);
    
                ----------------------------------------------------
                -- INSERTA REGISTRO EN EL ARCHIVO CABECERA ACTIVO --
                ----------------------------------------------------
                --si saldo negativo -> tipo Prestamo
    
                IF nvl(v_sal_ult_extracto, 0) + nvl(v_mto_credito, 0) - nvl(v_mto_debito, 0) < 0 THEN
                   v_tipo := 'P';
                ELSE --si saldo positivo -> tipo Ahorro
                   v_tipo := 'A';
                END IF;
    
                v_sal_blo_anterior := lf_obt_sal_blo_anterior(av.nro_cuenta, av.fec_ult_extracto);
                
                v_lugar := 'lp_generar_ctacte: Insert en GE_EXT_CLI_CUENTAS: ' || '-' || av.nro_cuenta;
                
                INSERT INTO ge_ext_cli_cuentas (
                   ge_ext_cli_cuentas.cod_persona,
                   ge_ext_cli_cuentas.fec_extracto,
                   ge_ext_cli_cuentas.tip_cuenta,
                   ge_ext_cli_cuentas.cod_oficina,
                   ge_ext_cli_cuentas.cod_modalidad,
                   ge_ext_cli_cuentas.nro_cuenta,
                   ge_ext_cli_cuentas.cod_moneda,
                   ge_ext_cli_cuentas.sal_anterior,
                   ge_ext_cli_cuentas.sal_actual,
                   ge_ext_cli_cuentas.nro_folio,
                   ge_ext_cli_cuentas.sal_a_confirmar,
                   ge_ext_cli_cuentas.cod_extracto,
                   ge_ext_cli_cuentas.fre_extracto,
                   sal_promedio,
                   nro_cta_combinada,
                   tas_nominal,
                   tas_efectiva,
                   ge_ext_cli_cuentas.sal_bloqueado,
                   ge_ext_cli_cuentas.cod_per_empresa,
                   sal_blo_anterior
                ) VALUES (
                   v_cod_persona,
    		   v_fec_actual,
                   v_tipo, --'A',
                   av.cod_oficina,
                   av.cod_modalidad,
                   av.nro_cuenta,
                   av.cod_moneda,
                   v_sal_ult_extracto,
                   nvl(v_sal_ult_extracto, 0) + nvl(v_mto_credito, 0) - nvl(v_mto_debito, 0),
                   av.nro_folio,
                   av.sal_ret_batch,
                   v_cod_extracto,
                   v_frecuencia,
                   v_sal_promedio,
                   v_nro_cta_combinada,
                   v_val_tasa,
                   v_val_tae,
                   v_mto_bloqueo,
                   v_cod_per_ente,
                   v_sal_blo_anterior
                );
    
                --@LReyes --Se modificaron por INSERT SELECT
                lp_generar_mov_retenciones(av.nro_cuenta);
                lp_generar_mov_pendientes(av.nro_cuenta);
    
                IF v_frecuencia = 'M' THEN
                    -- Actualizar el Saldo Mensual Actual.
                   BEGIN
                      UPDATE cc_sal_mensuales
                      SET
                         sal_ult_extracto = nvl(v_sal_ult_extracto, 0) + nvl(v_mto_credito, 0) - nvl(v_mto_debito, 0)
                      WHERE
                            nro_cuenta = av.nro_cuenta
                         AND ano = TO_NUMBER(to_char(v_fec_actual, 'YYYY'))
                         AND mes = TO_NUMBER(to_char(v_fec_actual, 'MM'));
    
                   EXCEPTION
                      WHEN OTHERS THEN
                         pr_ins_log_error('Error al Actualizar el Saldo Mensual en CTA.CTES. ' || av.nro_cuenta || '. ' || sqlerrm, av.nro_cuenta);
                   END;
                END IF;
    
                IF v_tiene_mov = 'S' THEN
                   v_lugar := 'lp_generar_ctacte: INSERT en GE_EXT_CUENTAS_TTG';
                   INSERT INTO GE_EXT_CUENTAS_TTG ( --@LReyes Tabla para la concurrencia
                      nro_cuenta,
                      cod_modulo,
                      cod_modalidad,
                      nro_folio,
                      fec_ult_extracto,
                      sal_ult_extracto,
                      nom_tabla,
                      cod_persona
                   ) VALUES (
                      av.nro_cuenta,
                      av.cod_modulo,
                      av.cod_modalidad,
                      av.nro_folio,
                      v_fec_actual,
                      nvl(v_sal_ult_extracto, 0) + nvl(v_mto_credito, 0) - nvl(v_mto_debito, 0),
                      'CC_CTA_CORRIENTES',
                      v_cod_persona
                   );
                   IF v_cod_extracto = 1 and v_cantidad < vg_max_movimientos THEN
                      -----------------------------------------------------
                      -- [MASIVO] INSERTA REGISTRO EN EL ARCHIVO DETALLE --
                      -----------------------------------------------------
                      --@LReyes --Guardo datos para recuperar luego, masivamente, los movimientos de la cuenta.
                      mov_masivos_list.EXTEND;
                      mov_masivos_list(mov_masivos_list.COUNT) := mov_mas_record(
                         v_cod_persona,
                         av.nro_cuenta,
                         av.cod_modulo,
                         av.cod_modalidad,
                         av.cod_oficina,
                         v_fec_movimiento
                      );
                        
                   ELSE
                      --------------------------------------------
                      -- INSERTA REGISTRO EN EL ARCHIVO DETALLE --
                      --------------------------------------------
                      v_lugar := 'lp_generar_ctacte: INSERT en GE_EXT_CLI_MOVIMIENTOS';
                      INSERT INTO ge_ext_cli_movimientos (
                         cod_persona,
                         fec_extracto,
                         fec_movimiento,
                         fec_valor,
                         hor_movimiento,
                         nro_cuenta,
                         nro_documento,
                         cod_modulo,
                         cod_modalidad,
                         cod_tra_padre,
                         mto_debito,
                         mto_credito,
                         cod_extracto,
                         fre_extracto,
                         nro_secuencia,
                         cod_ofi_origen,
                         fec_insercion,
                         ind_bloqueo
                      )
                      SELECT
                         v_cod_persona,
                     	 v_fec_actual,
                         cc_movimientos_his.fecha,
                         cc_movimientos_his.fec_valor,
                         cc_movimientos_his.hora,
                         cc_movimientos_his.nro_cuenta,
                         cc_movimientos_his.nro_documento,
                         cc_movimientos_his.cod_mod_padre,
                         cc_movimientos_his.cod_mad_padre,
                         cc_movimientos_his.cod_tra_padre,
                         ( decode(fug_obt_tra_tipo(ge_transacciones.cod_transaccion, ge_transacciones.tipo, ge_transacciones.afecta),
                                  'D',
                                  nvl(cc_movimientos_his.monto, 0),
                                  0) ),
                         ( decode(fug_obt_tra_tipo(ge_transacciones.cod_transaccion, ge_transacciones.tipo, ge_transacciones.afecta),
                                  'C',
                                  nvl(cc_movimientos_his.monto, 0),
                                  0) ),
                         v_cod_extracto,
                         v_frecuencia,
                         cc_movimientos_his.nro_secuencia,
                         cc_movimientos_his.cod_ofi_origen,
                         cc_movimientos_his.fec_insercion,
                         decode(ge_transacciones.afecta, 'B', 'S', 'N')
                      FROM
                         ge_transacciones,
                         cc_movimientos_his
                      WHERE
                            cc_movimientos_his.cod_modulo = av.cod_modulo
                         AND cc_movimientos_his.cod_modalidad = av.cod_modalidad
                         AND cc_movimientos_his.cod_oficina = av.cod_oficina
                         AND cc_movimientos_his.nro_cuenta = av.nro_cuenta
                         AND cc_movimientos_his.fecha > v_fec_movimiento -- 17/07/2009 V.O.
                         AND cc_movimientos_his.fecha <= v_fec_actual
                         AND ( cc_movimientos_his.reversado = 'N'
                               OR ( cc_movimientos_his.reversado = 'S'
                                    AND fec_valor <= v_fec_movimiento
                                    AND EXISTS (
                            SELECT
                               1
                            FROM
                               cc_movimientos_his rev  -- CB. 25/09/2013.
                            WHERE
                                  cc_movimientos_his.fec_valor = rev.fecha
                               AND cc_movimientos_his.hor_reversion = rev.hora
                               AND cc_movimientos_his.cod_usu_reversion = rev.cod_usuario
                               AND cc_movimientos_his.nro_secuencia = rev.nro_secuencia
                                       -- DYDMR-5672 NAF 01/2017
                               AND cc_movimientos_his.nro_cuenta = rev.nro_cuenta
                               AND abs(cc_movimientos_his.monto) = abs(rev.monto)
                         ) )
                               OR ( cc_movimientos_his.reversado = 'S'
                                    AND cc_movimientos_his.cod_tra_padre IN ( 303, 302 )
                                    AND cc_movimientos_his.cod_mad_padre = 455 ) )
                         AND cc_movimientos_his.estado = 'N'
                         AND cc_movimientos_his.cod_modulo = ge_transacciones.cod_modulo
                         AND cc_movimientos_his.cod_modalidad = ge_transacciones.cod_modalidad
                         AND cc_movimientos_his.cod_transaccion = ge_transacciones.cod_transaccion
                         AND ge_transacciones.ve_cliente = 'S'
                         AND ge_transacciones.tipo IN ( 'C', 'D' )
                         AND nvl(ge_transacciones.afecta, 'XX') != 'B';
    
                   END IF;
                END IF;
                
                v_fec_vto_linea := NULL;
                BEGIN
                    --busca sobregiro vencido                
                    SELECT 
                        sal_tot_batch,
                        fec_cam_estado,
                        '7',
                        0
                    INTO 
                        v_mto_linea,
                        v_fec_vto_linea,
                        v_tip_resumen,
                        v_sal_disponible
                    FROM
                        ov_cta_vencidas
                    WHERE
                        nro_cta_origen = av.nro_cuenta
                    AND cod_modalidad = 153
                    AND estado = 'V'
                    AND av.saldo < 0;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        --buscar linea de sobregiro
                        BEGIN
                            SELECT
                              nvl(SUM(monto),
                                  0),
                              MIN(fec_vencimiento),
                              '5'
                           INTO
                              v_mto_linea,
                              v_fec_vto_linea,
                              v_tip_resumen
                           FROM
                              cc_lin_sobregiros
                           WHERE
                                 nro_cuenta = av.nro_cuenta
                              AND v_fec_actual BETWEEN fec_inicio AND fec_vencimiento
                              AND estado = 'A';
                              
                              v_sal_disponible := ( av.saldo - av.sal_bloqueado ) + v_mto_linea;
                        EXCEPTION
                            WHEN OTHERS THEN
                                NULL;
                        END;
                    WHEN OTHERS THEN
                        NULL;
                END;
                BEGIN
                   
                   ---------------------------------------------------------
                   -- INSERTA REGISTRO EN EL ARCHIVO RESUMEN DE CTA CTE --SOLO SI TIENE SOBREGIRO
                   ---------------------------------------------------------
                   IF v_fec_vto_linea IS NOT NULL THEN
                        v_lugar := 'lp_generar_ctacte: INSERT en GE_EXT_RESUMENES';
                      INSERT INTO ge_ext_resumenes (
                         ge_ext_resumenes.cod_persona,
                         ge_ext_resumenes.fec_extracto,
                         ge_ext_resumenes.tipo,
                         ge_ext_resumenes.nro_cuenta,
                         ge_ext_resumenes.mto_capital,
                         ge_ext_resumenes.mto_interes,
                         ge_ext_resumenes.fec_vencimiento,
                         ge_ext_resumenes.cod_extracto,
                         ge_ext_resumenes.fre_extracto,
                         ge_ext_resumenes.sal_disponible,
                         cod_modalidad,
                         cod_moneda
                      ) VALUES (
                         v_cod_persona,
                     	 v_fec_actual,
                         v_tip_resumen,
                         av.nro_cuenta,
                         v_mto_linea,
                         av.saldo,
                         v_fec_vto_linea,
                         v_cod_extracto,
                         v_frecuencia,
                         v_sal_disponible,
                         av.cod_modalidad,
                         av.cod_moneda
                      );
    
                   END IF;
    
                EXCEPTION
                   WHEN OTHERS THEN
                      NULL;
                END;
    
                IF v_count_loop >= 50 THEN
                   COMMIT;
                   v_count_loop := 0;
                END IF;
            EXCEPTION
                WHEN OTHERS THEN
                    pr_ins_log_error(v_lugar || ' | ' || SQLERRM, av.nro_cuenta);
                    UPDATE ge_ext_clientes
                    SET fre_Extracto = lower(v_frecuencia)
                    WHERE cod_persona = v_cod_persona
                    AND fec_extracto = v_fec_actual;
            END;
         END LOOP;
         v_fec_fin := SYSTIMESTAMP;
         v_duracion_seg := TRUNC((DBMS_UTILITY.get_time - v_inicio) / 100, 2);
                  
         pr_log_perf_event(
                p_cod_programa                 => 'PERF_PR_GEN_EXTRACTO',
                p_cod_subproceso               => 'lp_generar_ctacte~CURSOR mae_cue',
                p_fec_inicio                   => v_fec_inicio,
                p_fec_fin                      => v_fec_fin,
                p_val_duracion_seg             => v_duracion_seg,
                p_est_resultado                => 'SUCCESS');
         
         COMMIT;

         -----------------------------------------------------
         -- [MASIVO] INSERTA REGISTRO EN EL ARCHIVO DETALLE --
         -----------------------------------------------------
         --@LReyes --Datos antes guardados para recuperar masivamente los movimientos de las cuentas.         
         IF mov_masivos_list.COUNT > 0 THEN
            v_lugar := 'lp_generar_ctacte: [MASIVO] INSERT en GE_EXT_CLI_MOVIMIENTOS';
            ts_inicio := SYSTIMESTAMP;
            v_cant_mov := 0;
            v_initial_time := DBMS_UTILITY.get_time;
            
            v_inicio := DBMS_UTILITY.get_time;
            v_fec_inicio := SYSTIMESTAMP;
            
            OPEN cur_mov_ctacte;

            LOOP
               FETCH cur_mov_ctacte
               BULK COLLECT INTO t_cur_mov_ctacte LIMIT vg_bulk_size;
               EXIT WHEN t_cur_mov_ctacte.COUNT() = 0;
               
               v_cant_mov := v_cant_mov + t_cur_mov_ctacte.COUNT();

               FORALL i IN t_cur_mov_ctacte.FIRST() .. t_cur_mov_ctacte.LAST()
                  INSERT INTO ge_ext_cli_movimientos (
                        cod_persona,
                        fec_extracto,
                        fec_movimiento,
                        fec_valor,
                        hor_movimiento,
                        nro_cuenta,
                        nro_documento,
                        cod_modulo,
                        cod_modalidad,
                        cod_tra_padre,
                        mto_debito,
                        mto_credito,
                        cod_extracto,
                        fre_extracto,
                        nro_secuencia,
                        cod_ofi_origen,
                        fec_insercion,
                        ind_bloqueo
                  )
                  VALUES (
                     t_cur_mov_ctacte(i).cod_persona,
                     t_cur_mov_ctacte(i).fec_actual,
                     t_cur_mov_ctacte(i).fecha,
                     t_cur_mov_ctacte(i).fec_valor,
                     t_cur_mov_ctacte(i).hora,
                     t_cur_mov_ctacte(i).nro_cuenta,
                     t_cur_mov_ctacte(i).nro_documento,
                     t_cur_mov_ctacte(i).cod_mod_padre,
                     t_cur_mov_ctacte(i).cod_mad_padre,
                     t_cur_mov_ctacte(i).cod_tra_padre,
                     t_cur_mov_ctacte(i).monto_D,
                     t_cur_mov_ctacte(i).monto_C,
                     t_cur_mov_ctacte(i).cod_extracto,
                     t_cur_mov_ctacte(i).frecuencia,
                     t_cur_mov_ctacte(i).nro_secuencia,
                     t_cur_mov_ctacte(i).cod_ofi_origen,
                     t_cur_mov_ctacte(i).fec_insercion,
                     t_cur_mov_ctacte(i).ind_bloqueo
                  );
               COMMIT;
            END LOOP;

            CLOSE cur_mov_ctacte;
            
            v_fec_fin := SYSTIMESTAMP;
            v_duracion_seg := TRUNC((DBMS_UTILITY.get_time - v_inicio) / 100, 2);
                  
            pr_log_perf_event(
                p_cod_programa                 => 'PERF_PR_GEN_EXTRACTO',
                p_cod_subproceso               => 'lp_generar_ctacte~CURSOR cur_mov_ctacte',
                p_fec_inicio                   => v_fec_inicio,
                p_fec_fin                      => v_fec_fin,
                p_val_duracion_seg             => v_duracion_seg,
                p_est_resultado                => 'SUCCESS');
            
            ts_fin := SYSTIMESTAMP;
            pr_ins_log_error('lp_generar_ctate: [insert mov masivo] cantidad->' || v_cant_mov || ', duracion->' || substr(ts_fin-ts_inicio, -18, 11), null);
         END IF;

      END lp_generar_ctacte;

      PROCEDURE lp_generar_ctaban
      IS
         v_sal_ult_extracto NUMBER(18, 2) DEFAULT 0;
         v_mto_debito       NUMBER(18, 2);
         v_mto_credito      NUMBER(18, 2);
         v_mto_deb          NUMBER(18, 2);
         v_can              NUMBER(6) := 0;
         v_mto_cre          NUMBER(18, 2);
         v_existe           VARCHAR2(1) := 'N';
         v_tiene_mov        VARCHAR2(1) := 'N';
         v_cantidad         NUMBER := 0;-- TN-1003 EFMILANES: se paso de NUMBER(6) a NUMBER porque quedo chica
         v_imprime_extracto VARCHAR2(1);
         ts_inicio          TIMESTAMP;
         ts_fin             TIMESTAMP;
         v_cant_mov         NUMBER;

         ----------------------------------
         -- CURSOR DEL ARCHIVO PRINCIPAL --
         ----------------------------------
         CURSOR mae_cue IS
         with cuentas AS (
            SELECT
               cli.cod_persona,
               t.cod_modulo,
               t.cod_modalidad,
               t.cod_oficina,
               t.nro_cuenta,
               c.cod_moneda,
               c.sal_ult_extracto,
               nvl(c.nro_folio, 0) + 1                     nro_folio,
               c.denominacion,
               c.sal_ret_batch,
               nvl(c.fec_ult_extracto, c.fec_apertura - 1) fec_ult_extracto,
               nvl(bpd.val_parametro, 'C')                 separado,
               c.rowid                                     registro,
               c.sal_bloqueado
            FROM
               ge_dir_envios          d,
               cc_cta_bancarias       c,
               ge_cta_clientes        t,
               ba_per_dat_adicionales bpd,
               TABLE(mae_cli_ctas_list) cli
            WHERE
                  d.cod_persona (+) = t.cod_persona--CROGENEXT-13 Sergio Servín 06/08/2014
               AND d.nro_cuenta (+) = t.nro_cuenta--CROGENEXT-13 Sergio Servín 06/08/2014
               AND t.cod_persona = cli.cod_persona
               AND cli.cod_modulo = 4
               AND cli.cod_modalidad != 41
               AND t.relacion = 'P'
               AND c.cod_modulo = t.cod_modulo
               AND c.cod_modalidad = t.cod_modalidad
               AND c.cod_oficina = t.cod_oficina
               AND c.nro_cuenta = t.nro_cuenta
               AND c.fre_extracto = v_frecuencia --CROGENEXT-13 Sergio Servín 06/08/2014
               AND bpd.cod_persona (+) = t.cod_persona
               AND bpd.parametro (+) = 'TIP_GEN_EXTRACTOS'
               AND ( ( c.estado NOT IN ( 'C', 'P' ) )
                     OR ( c.estado IN ( 'C', 'P' )
                          AND c.fec_ult_movimiento >= v_pri_dia_mes_habil
                          AND c.fec_ult_movimiento > nvl(c.fec_ult_extracto, c.fec_apertura - 1) ) )
         ),
         movimientos AS (
            SELECT
               cuentas.cod_persona,
               cuentas.nro_cuenta,
               cuentas.cod_modulo,
               cuentas.cod_modalidad,
               cuentas.cod_oficina,
               SUM(decode(fug_obt_tra_tipo(t.cod_transaccion, t.tipo, t.afecta),
                          'D',
                          nvl(m.monto, 0),
                          0)) mto_debito,
               SUM(decode(fug_obt_tra_tipo(t.cod_transaccion, t.tipo, t.afecta),
                          'C',
                          nvl(m.monto, 0),
                          0)) mto_credito,
               COUNT('X')     cantidad
         FROM
            ge_transacciones   t,
            cc_movimientos_his m,
            cuentas
         WHERE
               m.cod_modulo = cuentas.cod_modulo
            AND m.cod_modalidad = cuentas.cod_modalidad
            AND m.cod_oficina = cuentas.cod_oficina
            AND m.nro_cuenta = cuentas.nro_cuenta
            AND m.fecha > cuentas.fec_ult_extracto
            AND m.fecha <= v_fec_actual
            AND ( m.reversado = 'N'
                  OR
                  --DYDMR-6072 - Incidencia SAU - ITGF - Incidencia Generación de Datos de Cuentas Bancarias
                   ( m.reversado = 'S'
                       AND fec_valor <= cuentas.fec_ult_extracto
                       AND EXISTS (
               SELECT
                  1
               FROM
                  cc_movimientos_his rev  -- CB. 25/09/2013.
               WHERE
                     m.fec_valor = rev.fecha
                  AND m.hor_reversion = rev.hora
                  AND m.cod_usu_reversion = rev.cod_usuario
                  AND m.nro_secuencia = rev.nro_secuencia
                          -- DYDMR-5672 NAF 01/2017
                  AND m.nro_cuenta = rev.nro_cuenta
                  AND abs(m.monto) = abs(rev.monto)
            ) )
                  OR ( m.reversado = 'S'
                       AND m.cod_tra_padre IN ( 303, 302 )
                       AND m.cod_mad_padre = 455 ) )
            AND m.estado = 'N'
            AND m.cod_modulo = t.cod_modulo
            AND m.cod_modalidad = t.cod_modalidad
            AND m.cod_transaccion = t.cod_transaccion
            AND nvl(t.afecta, 'X') != 'B'
            AND t.ve_cliente = 'S'
            AND t.tipo IN ( 'C', 'D' )
         GROUP BY
            cuentas.cod_persona,
            cuentas.nro_cuenta,
            cuentas.cod_modulo,
            cuentas.cod_modalidad,
            cuentas.cod_oficina
         )
         SELECT cuentas.*,
                NVL(movimientos.mto_debito, 0)  mto_debito,
                NVL(movimientos.mto_credito, 0) mto_credito,
                NVL(movimientos.cantidad, 0)    cantidad
         FROM cuentas
         LEFT JOIN movimientos
         ON cuentas.cod_persona = movimientos.cod_persona
            AND cuentas.nro_cuenta = movimientos.nro_cuenta
            AND cuentas.cod_modulo = movimientos.cod_modulo
            AND cuentas.cod_modalidad = movimientos.cod_modalidad
            AND cuentas.cod_oficina = movimientos.cod_oficina
         ORDER BY
            cuentas.cod_persona
         ;

         mov_masivos_list t_mov_mas_table := t_mov_mas_table();

         CURSOR cur_mov_ctaban IS
         SELECT
            mov.cod_persona,
            v_fec_actual fec_actual,
            h.fecha,
            h.fec_valor,
            h.hora,
            h.nro_cuenta,
            h.nro_documento,
            h.cod_mod_padre,
            h.cod_mad_padre,
            h.cod_tra_padre,
            ( decode(fug_obt_tra_tipo(t.cod_transaccion, t.tipo, t.afecta),
                     'D',
                     nvl(h.monto, 0),
                     0) ) monto_D,
            ( decode(fug_obt_tra_tipo(t.cod_transaccion, t.tipo, afecta),
                     'C',
                     nvl(h.monto, 0),
                     0) ) monto_C,
            1 cod_extracto, --v_cod_extracto,
            v_frecuencia frecuencia,
            h.nro_secuencia,
            h.cod_ofi_origen,
            h.fec_insercion,
            decode(t.afecta, 'B', 'S', 'N') ind_bloqueo
         FROM
            ge_transacciones   t,
            cc_movimientos_his h,
            TABLE(mov_masivos_list) mov
         WHERE
               h.cod_modulo = mov.cod_modulo
            AND h.cod_modalidad = mov.cod_modalidad
            AND h.cod_oficina = mov.cod_oficina
            AND h.nro_cuenta = mov.nro_cuenta
            AND h.fecha > mov.fec_movimiento
            AND h.fecha <= v_fec_actual
            -- DYDMR-6072 - Incidencia SAU - ITGF - Incidencia Generación de Datos de Cuentas Bancarias
            AND ( h.reversado = 'N'
                  OR ( h.reversado = 'S'
                       AND fec_valor <= mov.fec_movimiento
                       AND EXISTS (
               SELECT
                  1
               FROM
                  cc_movimientos_his rev  -- CB. 25/09/2013.
               WHERE
                     h.fec_valor = rev.fecha
                  AND h.hor_reversion = rev.hora
                  AND h.cod_usu_reversion = rev.cod_usuario
                  AND h.nro_secuencia = rev.nro_secuencia
                  -- DYDMR-5672 NAF 01/2017
                  AND h.nro_cuenta = rev.nro_cuenta
                  AND abs(h.monto) = abs(rev.monto)
            ) )
                  OR ( h.reversado = 'S'
                       AND h.cod_tra_padre IN ( 303, 302 )
                       AND h.cod_mad_padre = 455 ) )
            AND h.estado = 'N'
            AND h.cod_modulo = t.cod_modulo
            AND h.cod_modalidad = t.cod_modalidad
            AND h.cod_transaccion = t.cod_transaccion
            AND ( nvl(t.afecta, 'XX') = 'B'
                  AND h.cod_causa IN (
               SELECT
                  cod_causa
               FROM
                  ge_par_causales
               WHERE
                     parametro = 'COD_CAU_BLO_EXT'
                  AND val_parametro = 'S'
            )
                  OR nvl(t.afecta, 'XX') != 'B' )
            AND t.ve_cliente = 'S'
            AND t.tipo IN ( 'C', 'D' );

         TYPE t_cur_mov_ctaban_type IS TABLE OF cur_mov_ctaban%rowtype;
         t_cur_mov_ctaban  t_cur_mov_ctaban_type;

         v_count_loop PLS_INTEGER := 0;
      BEGIN
         v_lugar := 'lp_generar_ctaban';
         v_cod_persona := -1;
         v_initial_time := DBMS_UTILITY.get_time;
         
         v_inicio := DBMS_UTILITY.get_time;
         v_fec_inicio := SYSTIMESTAMP;
         
         FOR b IN mae_cue LOOP
            BEGIN
                v_count_loop := v_count_loop + 1;
    
                IF v_cod_persona != b.cod_persona THEN
                   --Inicializo la variable que separa los extractos especificos
                   v_cod_persona := b.cod_persona;
                   v_cod_extracto := 1;
                   --v_cod_ext_separado := 1;
                   IF NOT ge_ext_cli_cuentas_collection.EXISTS(b.cod_persona) THEN
                      ge_ext_cli_cuentas_collection(b.cod_persona) := -1;
                   END IF;
                END IF;
                
                --- asigno el codigo de extracto unico -----------------
                v_nro_cuenta := b.nro_cuenta;
                --WA:08/08/2014 Se agrega 49 para financiera Pais
                IF b.cod_modalidad IN ( 42, 48, 49 ) THEN -- BANCOS DEL PAIS
                   v_sal_ult_extracto := nvl(b.sal_ult_extracto, 0) * -1;
                ELSE
                   v_sal_ult_extracto := nvl(b.sal_ult_extracto, 0);
                END IF;
    
                v_tiene_mov := 'N';
                v_cantidad := 0;
                v_mto_bloqueo := lf_obt_mto_bloqueado(b.nro_cuenta);
    
                --@LReyes --la suma de todos los movimientos del historico ahora disponible en el Cursor
                v_mto_debito := b.mto_debito;
                v_mto_credito := b.mto_credito;
                v_cantidad := b.cantidad;
    
                ----------------------------------------------------------
                -- SDC - AP 897/8 - Si no tiene movimientos verifica si tiene bloqueos
                IF nvl(v_cantidad, 0) = 0 THEN
                BEGIN
                -- Aqui no se incluyen los Bloqueos para Act. el Sal Anterior.
                      SELECT
                         SUM(decode(t.cod_transaccion,
                                    515,
                                    0,
                                    560,
                                    0,
                                    decode(t.tipo,
                                           'D',
                                           nvl(m.monto, 0),
                                           0))),
                         SUM(decode(t.cod_transaccion,
                                    515,
                                    nvl(m.monto, 0),
                                    560,
                                    nvl(m.monto, 0),
                                    decode(t.tipo,
                                           'C',
                                           nvl(m.monto, 0),
                                           0))),
                         COUNT('X')
                      INTO
                         v_mto_deb,
                         v_mto_cre,
                         v_can
                      FROM
                         ge_transacciones   t,
                         cc_movimientos_his m
                      WHERE
                            m.cod_modulo = b.cod_modulo
                         AND m.cod_modalidad = b.cod_modalidad
                         AND m.cod_oficina = b.cod_oficina
                         AND m.nro_cuenta = b.nro_cuenta
                         AND m.fecha > b.fec_ult_extracto
                         AND m.fecha <= v_fec_actual
                         AND ( m.reversado = 'N'
                               OR
                               --DYDMR-6072 - Incidencia SAU - ITGF - Incidencia Generación de Datos de Cuentas Bancarias
                                ( m.reversado = 'S'
                                    AND fec_valor <= b.fec_ult_extracto
                                    AND EXISTS (
                            SELECT
                               1
                            FROM
                               cc_movimientos_his rev  -- CB. 25/09/2013.
                            WHERE
                                  m.fec_valor = rev.fecha
                               AND m.hor_reversion = rev.hora
                               AND m.cod_usu_reversion = rev.cod_usuario
                               AND m.nro_secuencia = rev.nro_secuencia
                                    -- DYDMR-5672 NAF 01/2017
                               AND m.nro_cuenta = rev.nro_cuenta
                               AND abs(m.monto) = abs(rev.monto)
                         ) )
                               OR ( m.reversado = 'S'
                                    AND m.cod_tra_padre IN ( 303, 302 )
                                    AND m.cod_mad_padre = 455 ) )
                         AND m.estado = 'N'
                         AND m.cod_modulo = t.cod_modulo
                         AND m.cod_modalidad = t.cod_modalidad
                         AND m.cod_transaccion = t.cod_transaccion
                         AND t.ve_cliente = 'S'
                         AND t.tipo IN ( 'C', 'D' )
                         AND ( nvl(t.afecta, 'XX') = 'B'
                               AND m.cod_causa IN (
                            SELECT
                               cod_causa
                            FROM
                               ge_par_causales
                            WHERE
                                  parametro = 'COD_CAU_BLO_EXT'
                               AND val_parametro = 'S'
                         )
                               OR nvl(t.afecta, 'XX') != 'B' );
    
                   EXCEPTION
                      WHEN OTHERS THEN
                         v_mto_deb := 0;
                         v_mto_cre := 0;
                         v_can := 0;
                   END;
                END IF;
                ----------------------------------------------------------
    
                IF nvl(v_cantidad, 0) > 0 OR nvl(v_can, 0) > 0 THEN
                   v_tiene_mov := 'S';
                END IF;
    
                v_existe := 'N';
                --IF b.separado = 'S' THEN--CROGENEXT-13 Sergio Servín 06/08/2014
                IF b.separado = 'I' THEN
                   --@LReyes --Array asociativo. Clave(cod_persona) Valor(cuenta para cod_extracto)
                   IF ge_ext_cli_cuentas_collection(b.cod_persona) < 0 THEN
                      ge_ext_cli_cuentas_collection(b.cod_persona) := 1;
                   ELSE
                      ge_ext_cli_cuentas_collection(b.cod_persona) := ge_ext_cli_cuentas_collection(b.cod_persona) + 1;
                   END IF;
                   v_cod_extracto := ge_ext_cli_cuentas_collection(b.cod_persona);
                   ---------------------------------------------------------
                ELSE
                   --@LReyes --Dado que se itera por cod_cliente ordenado, buscamos pre-existencia en el Array asociativo
                   IF ge_ext_cli_cuentas_collection(b.cod_persona) < 0 THEN
                      ge_ext_cli_cuentas_collection(b.cod_persona) := 1;
                      v_existe := 'N';
                   ELSE
                      v_existe := 'S';
                   END IF;
                   v_cod_extracto := ge_ext_cli_cuentas_collection(b.cod_persona);
                END IF;
    
                IF v_existe = 'N' THEN
                
                   -- busco los datos del cliente ---------------------------
                   v_lugar := 'lp_generar_ctaban: lp_obtener_datos_del_cliente';
                   lp_obtener_datos_del_cliente;
                   lp_dir_envio;
                   v_imprime_extracto := v_tip_extracto;
                   v_lugar := 'lp_generar_ctaban: 1-insert GE_EXT_CLIENTES '
                              || v_cod_persona
                              || '-'
                              || v_dir_cliente;
                   BEGIN
                      INSERT INTO ge_ext_clientes (
                         cod_persona,
                         fec_extracto,
                         fre_extracto,
                         funcionario,
                         nom_cliente,
                         direccion,
                         telefono,
                         cod_usu_oficial,
                         cod_pais,
                         cod_ciudad,
                         tel_oficial,
                         nro_interno,
                         cod_extracto,
                         det_direccion,
                         observacion,
                         barrio,
                         cod_mensaje,
                         tip_impresion,
                         cli_confidencial,
                         cod_oficina,
                         cat_riesgo,
                         fec_ult_clasif,
                         tip_direccion
                      ) VALUES (
                         v_cod_persona,
                     	 v_fec_actual,
                         v_frecuencia,
                         v_es_empleado,
                         v_nom_cliente,--b.denominacion,
                         v_dir_cliente,
                         v_tel_cliente,
                         v_cod_usu_oficial,
                         v_cod_pais,
                         v_cod_ciudad,
                         v_tel_oficial,
                         v_int_oficial,
                         v_cod_extracto,
                         v_pri_obs_dir,
                         v_seg_obs_dir,
                         v_des_barrio,
                         '1',
                         v_imprime_extracto,
                         v_cli_confidencial,
                         decode(b.separado, 'I', b.cod_oficina, v_cod_ofi_cliente),
                         v_cat_riesgo,
                         v_fec_ult_clasif,
                         v_tip_envio
                      );
    
                   EXCEPTION
                      WHEN OTHERS THEN
                         NULL;
                   END;
    
                   v_inserta := 'S';
                END IF;
    
                ----------------------------------------------------
                -- INSERTA REGISTRO EN EL ARCHIVO CABECERA ACTIVO --
                ----------------------------------------------------
                BEGIN
                   --WA:08/08/2014 Se agrega 49 para financiera Pais
                   IF b.cod_modalidad IN ( 42, 48, 49 ) THEN -- bancos del pais
                      v_sal_actual := nvl(v_sal_ult_extracto, 0) - nvl(v_mto_credito, 0) + nvl(v_mto_debito, 0);
                   ELSE
                      v_sal_actual := nvl(v_sal_ult_extracto, 0) - nvl(v_mto_debito, 0) + nvl(v_mto_credito, 0);
                   END IF;
                    v_lugar := 'lp_generar_ctaban: INSERT en GE_EXT_CLI_CUENTAS: ' || '-' || b.nro_cuenta;
                   INSERT INTO ge_ext_cli_cuentas (
                      cod_persona,
                      fec_extracto,
                      tip_cuenta,
                      cod_oficina,
                      cod_modalidad,
                      nro_cuenta,
                      cod_moneda,
                      sal_anterior,
                      sal_actual,
                      nro_folio,
                      sal_a_confirmar,
                      cod_extracto,
                      fre_extracto,
                      sal_bloqueado
                   ) VALUES (
                      v_cod_persona,
                      v_fec_actual,
                      'A',
                      b.cod_oficina,
                      b.cod_modalidad,
                      b.nro_cuenta,
                      b.cod_moneda,
                      v_sal_ult_extracto,
                      v_sal_actual,
                      b.nro_folio,
                      b.sal_ret_batch,
                      v_cod_extracto,
                      v_frecuencia,
                      v_mto_bloqueo
                   );
                EXCEPTION
                   WHEN OTHERS THEN
                      NULL;
                END;
    
                IF v_tiene_mov = 'S' THEN
                   v_lugar := 'lp_generar_ctaban: INSERT en GE_EXT_CUENTAS_TTG';
                   INSERT INTO GE_EXT_CUENTAS_TTG ( --@LReyes Tabla para la concurrencia
                      nro_cuenta,
                      cod_modulo,
                      cod_modalidad,
                      nro_folio,
                      fec_ult_extracto,
                      sal_ult_extracto,
                      nom_tabla,
                      cod_persona
                   ) VALUES (
                      b.nro_cuenta,
                      b.cod_modulo,
                      b.cod_modalidad,
                      b.nro_folio,
                      v_fec_actual,
                      v_sal_actual,
                      'CC_CTA_BANCARIAS',
                      v_cod_persona
                   );
                   IF v_cod_extracto = 1 and v_cantidad < vg_max_movimientos THEN
                      -----------------------------------------------------
                      -- [MASIVO] INSERTA REGISTRO EN EL ARCHIVO DETALLE --
                      -----------------------------------------------------
                      
                      --@LReyes --Guardo datos para recuperar luego, masivamente, los movimientos de la cuenta.
                      mov_masivos_list.EXTEND;
                      mov_masivos_list(mov_masivos_list.COUNT) := mov_mas_record(
                         b.cod_persona,
                         b.nro_cuenta,
                         b.cod_modulo,
                         b.cod_modalidad,
                         b.cod_oficina,
                         b.fec_ult_extracto
                      );
    
                   ELSE
                      --------------------------------------------
                      -- INSERTA REGISTRO EN EL ARCHIVO DETALLE --
                      --------------------------------------------
                      v_lugar := 'lp_generar_ctaban: [MASIVO] INSERT en ge_ext_cli_movimientos';
                      BEGIN
                         INSERT INTO ge_ext_cli_movimientos (
                            cod_persona,
                            fec_extracto,
                            fec_movimiento,
                            fec_valor,
                            hor_movimiento,
                            nro_cuenta,
                            nro_documento,
                            cod_modulo,
                            cod_modalidad,
                            cod_tra_padre,
                            mto_debito,
                            mto_credito,
                            cod_extracto,
                            fre_extracto,
                            nro_secuencia,
                            cod_ofi_origen,
                            fec_insercion,
                            ind_bloqueo
                         )
                            SELECT
                               v_cod_persona,
                               v_fec_actual,
                               h.fecha,
                               h.fec_valor,
                               h.hora,
                               h.nro_cuenta,
                               h.nro_documento,
                               h.cod_mod_padre,
                               h.cod_mad_padre,
                               h.cod_tra_padre,
                               ( decode(fug_obt_tra_tipo(t.cod_transaccion, t.tipo, t.afecta),
                                        'D',
                                        nvl(h.monto, 0),
                                        0) ),
                               ( decode(fug_obt_tra_tipo(t.cod_transaccion, t.tipo, afecta),
                                        'C',
                                        nvl(h.monto, 0),
                                        0) ),
                               v_cod_extracto,
                               v_frecuencia,
                               h.nro_secuencia,
                               h.cod_ofi_origen,
                               h.fec_insercion,
                               decode(t.afecta, 'B', 'S', 'N')
                            FROM
                               ge_transacciones   t,
                               cc_movimientos_his h
                            WHERE
                                  h.cod_modulo = b.cod_modulo
                               AND h.cod_modalidad = b.cod_modalidad
                               AND h.cod_oficina = b.cod_oficina
                               AND h.nro_cuenta = b.nro_cuenta
                               AND h.fecha > b.fec_ult_extracto
                               AND h.fecha <= v_fec_actual
                           -- DYDMR-6072 - Incidencia SAU - ITGF - Incidencia Generación de Datos de Cuentas Bancarias
                               AND ( h.reversado = 'N'
                                     OR ( h.reversado = 'S'
                                          AND fec_valor <= b.fec_ult_extracto
                                          AND EXISTS (
                                  SELECT
                                     1
                                  FROM
                                     cc_movimientos_his rev  -- CB. 25/09/2013.
                                  WHERE
                                        h.fec_valor = rev.fecha
                                     AND h.hor_reversion = rev.hora
                                     AND h.cod_usu_reversion = rev.cod_usuario
                                     AND h.nro_secuencia = rev.nro_secuencia
                                                                       -- DYDMR-5672 NAF 01/2017
                                     AND h.nro_cuenta = rev.nro_cuenta
                                     AND abs(h.monto) = abs(rev.monto)
                               ) )
                                     OR ( h.reversado = 'S'
                                          AND h.cod_tra_padre IN ( 303, 302 )
                                          AND h.cod_mad_padre = 455 ) )
                               AND h.estado = 'N'
                               AND h.cod_modulo = t.cod_modulo
                               AND h.cod_modalidad = t.cod_modalidad
                               AND h.cod_transaccion = t.cod_transaccion
                               AND ( nvl(t.afecta, 'XX') = 'B'
                                     AND h.cod_causa IN (
                                  SELECT
                                     cod_causa
                                  FROM
                                     ge_par_causales
                                  WHERE
                                        parametro = 'COD_CAU_BLO_EXT'
                                     AND val_parametro = 'S'
                               )
                                     OR nvl(t.afecta, 'XX') != 'B' )
                               AND t.ve_cliente = 'S'
                               AND t.tipo IN ( 'C', 'D' );
    
                      EXCEPTION
                         WHEN OTHERS THEN
                            NULL;
                      END;
                   END IF;
                END IF;
    
                IF v_count_loop >= 50 THEN
                   COMMIT;
                   v_count_loop := 0;
                END IF;
            EXCEPTION
                WHEN OTHERS THEN
                    pr_ins_log_error(v_lugar || ' | ' || SQLERRM, b.nro_cuenta);
                    UPDATE ge_ext_clientes
                    SET fre_Extracto = lower(v_frecuencia)
                    WHERE cod_persona = v_cod_persona
                    AND	fec_extracto = v_fec_actual;
            END;
         END LOOP;
         
         v_fec_fin := SYSTIMESTAMP;
         v_duracion_seg := TRUNC((DBMS_UTILITY.get_time - v_inicio) / 100, 2);
                  
         pr_log_perf_event(
                p_cod_programa                 => 'PERF_PR_GEN_EXTRACTO',
                p_cod_subproceso               => 'lp_generar_ctaban~CURSOR mae_cue',
                p_fec_inicio                   => v_fec_inicio,
                p_fec_fin                      => v_fec_fin,
                p_val_duracion_seg             => v_duracion_seg,
                p_est_resultado                => 'SUCCESS');
                
         COMMIT;

         -----------------------------------------------------
         -- [MASIVO] INSERTA REGISTRO EN EL ARCHIVO DETALLE --
         -----------------------------------------------------
         --@LReyes --Datos antes guardados para recuperar masivamente los movimientos de las cuentas.
         IF mov_masivos_list.COUNT > 0 THEN
            ts_inicio := SYSTIMESTAMP;
            v_cant_mov := 0;
            
            v_inicio := DBMS_UTILITY.get_time;
            v_fec_inicio := SYSTIMESTAMP;
            
            OPEN cur_mov_ctaban;
            v_initial_time := DBMS_UTILITY.get_time;
            LOOP
               FETCH cur_mov_ctaban
               BULK COLLECT INTO t_cur_mov_ctaban LIMIT vg_bulk_size;
               EXIT WHEN t_cur_mov_ctaban.COUNT() = 0;
                
               v_cant_mov := v_cant_mov + t_cur_mov_ctaban.COUNT();
               
               FORALL i IN t_cur_mov_ctaban.FIRST() .. t_cur_mov_ctaban.LAST()
                  INSERT INTO ge_ext_cli_movimientos (
                        cod_persona,
                        fec_extracto,
                        fec_movimiento,
                        fec_valor,
                        hor_movimiento,
                        nro_cuenta,
                        nro_documento,
                        cod_modulo,
                        cod_modalidad,
                        cod_tra_padre,
                        mto_debito,
                        mto_credito,
                        cod_extracto,
                        fre_extracto,
                        nro_secuencia,
                        cod_ofi_origen,
                        fec_insercion,
                        ind_bloqueo
                  )
                  VALUES (
                     t_cur_mov_ctaban(i).cod_persona,
                     t_cur_mov_ctaban(i).fec_actual,
                     t_cur_mov_ctaban(i).fecha,
                     t_cur_mov_ctaban(i).fec_valor,
                     t_cur_mov_ctaban(i).hora,
                     t_cur_mov_ctaban(i).nro_cuenta,
                     t_cur_mov_ctaban(i).nro_documento,
                     t_cur_mov_ctaban(i).cod_mod_padre,
                     t_cur_mov_ctaban(i).cod_mad_padre,
                     t_cur_mov_ctaban(i).cod_tra_padre,
                     t_cur_mov_ctaban(i).monto_D,
                     t_cur_mov_ctaban(i).monto_C,
                     t_cur_mov_ctaban(i).cod_extracto,
                     t_cur_mov_ctaban(i).frecuencia,
                     t_cur_mov_ctaban(i).nro_secuencia,
                     t_cur_mov_ctaban(i).cod_ofi_origen,
                     t_cur_mov_ctaban(i).fec_insercion,
                     t_cur_mov_ctaban(i).ind_bloqueo
                  );
               COMMIT;
            END LOOP;

            CLOSE cur_mov_ctaban;
                        
            v_fec_fin := SYSTIMESTAMP;
            v_duracion_seg := TRUNC((DBMS_UTILITY.get_time - v_inicio) / 100, 2);
                  
            pr_log_perf_event(
                p_cod_programa                 => 'PERF_PR_GEN_EXTRACTO',
                p_cod_subproceso               => 'lp_generar_ctaban~CURSOR cur_mov_ctaban',
                p_fec_inicio                   => v_fec_inicio,
                p_fec_fin                      => v_fec_fin,
                p_val_duracion_seg             => v_duracion_seg,
                p_est_resultado                => 'SUCCESS');
            
            ts_fin := SYSTIMESTAMP;
            pr_ins_log_error('lp_generar_ctaban: [insert mov masivo] cantidad->' || v_cant_mov || ', duracion->' || substr(ts_fin-ts_inicio, -18, 11), null);
         END IF;

      END lp_generar_ctaban;

      PROCEDURE lp_generar_vistas
      IS
         v_sal_ult_extracto  NUMBER(18, 2) DEFAULT 0;
         v_mto_debito        NUMBER(18, 2);
         v_mto_credito       NUMBER(18, 2);
         v_mto_deb           NUMBER(18, 2);
         v_mto_cre           NUMBER(18, 2);
         v_can               NUMBER(06) := 0;
         v_existe            VARCHAR2(01) := 'N';
         v_tiene_mov         VARCHAR2(01) := 'N';
         v_cantidad          NUMBER := 0;-- TN-1003 EFMILANES: se paso de NUMBER(6) a NUMBER porque quedo chica
         v_imprime_extracto  VARCHAR2(1);
         v_sal_acumulado     cc_sal_mensuales.sal_acu_deudor%TYPE;
         v_sal_promedio      cc_sal_mensuales.sal_acu_deudor%TYPE;
         v_can_dia_acumulado cc_sal_mensuales.can_dia_acumulado%TYPE;
         v_nro_cta_combinada cc_cta_combinadas.nro_cta_ahorro%TYPE;
         v_val_tasa          ge_tas_fechas.val_tasa%TYPE;
         v_val_tae           ge_tas_fechas.val_tasa%TYPE;
         ts_inicio          TIMESTAMP;
         ts_fin             TIMESTAMP;
         v_cant_mov         NUMBER;

         ----------------------------------
         -- CURSOR DEL ARCHIVO PRINCIPAL --
         ----------------------------------
         CURSOR mae_cue IS
         with cuentas AS (
            SELECT
               cli.cod_persona,
               ge_cta_clientes.cod_modulo,
               ge_cta_clientes.cod_modalidad,
               ge_cta_clientes.cod_oficina,
               ge_cta_clientes.nro_cuenta,
               ah_cta_vistas.cod_moneda,
               ah_cta_vistas.sal_ult_extracto,
               nvl(ah_cta_vistas.nro_folio, 0) + 1                                 nro_folio,
               ah_cta_vistas.denominacion,
               ah_cta_vistas.sal_ret_batch,
               nvl(ah_cta_vistas.fec_ult_extracto, ah_cta_vistas.fec_apertura - 1) fec_ult_extracto,
               nvl(bpd.val_parametro, 'C')                                         separado,
               ah_cta_vistas.fec_apertura,
               ah_cta_vistas.rowid                                                 registro,
               ah_cta_vistas.cta_combinada,
               ah_cta_vistas.tas_personalizada,
               ah_cta_vistas.cod_tasa,
               ah_cta_vistas.sal_bloqueado,
               ah_cta_vistas.cod_ente,
               decode(ah_cta_vistas.cod_ente, NULL, 'N', 'S')                      es_nomina,--se obtiene si es nómina
               nvl(ge_paq_cuentas.cod_paquete, 0)                                  cod_paquete
            FROM
               ge_dir_envios,
               ah_cta_vistas,
               ge_cta_clientes,
               ge_paq_cuentas,
               ba_per_dat_adicionales bpd,
               TABLE(mae_cli_ctas_list) cli
            WHERE
                  ge_dir_envios.cod_persona (+) = ge_cta_clientes.cod_persona--CROGENEXT-13 Sergio Servín 06/08/2014
               AND ge_dir_envios.nro_cuenta (+) = ge_cta_clientes.nro_cuenta--CROGENEXT-13 Sergio Servín 06/08/2014
               AND ge_cta_clientes.cod_persona = cli.cod_persona
               AND cli.cod_modulo = 3
               AND cli.cod_modalidad IN ( 31, 334 )
               AND ge_cta_clientes.cod_modalidad = cli.cod_modalidad
               AND ge_cta_clientes.relacion = 'P'
               AND ah_cta_vistas.cod_modulo = ge_cta_clientes.cod_modulo
               AND ah_cta_vistas.cod_modalidad = ge_cta_clientes.cod_modalidad
               AND ah_cta_vistas.cod_oficina = ge_cta_clientes.cod_oficina
               AND ah_cta_vistas.nro_cuenta = ge_cta_clientes.nro_cuenta
               AND ah_cta_vistas.fre_extracto = v_frecuencia--CROGENEXT-13 Sergio Servín 06/08/2014
               AND bpd.cod_persona (+) = ge_cta_clientes.cod_persona
               AND bpd.parametro (+) = 'TIP_GEN_EXTRACTOS'
               AND ( ( ah_cta_vistas.estado NOT IN ( 'C', 'P' ) )
                     OR ( ah_cta_vistas.estado IN ( 'C', 'P' )
                          AND ah_cta_vistas.fec_ult_movimiento >= v_pri_dia_mes_habil
                          AND ah_cta_vistas.fec_ult_movimiento > nvl(ah_cta_vistas.fec_ult_extracto, ah_cta_vistas.fec_apertura - 1) ) )
               AND ge_paq_cuentas.nro_cuenta (+) = ge_cta_clientes.nro_cuenta
               AND ge_paq_cuentas.cod_persona (+) = ge_cta_clientes.cod_persona
         ),
         movimientos AS (
            SELECT
               cuentas.cod_persona,
               cuentas.nro_cuenta,
               cuentas.cod_modulo,
               cuentas.cod_modalidad,
               cuentas.cod_oficina,
               SUM(decode(fug_obt_tra_tipo(ge_transacciones.cod_transaccion, ge_transacciones.tipo, ge_transacciones.afecta),
                          'D',
                          nvl(ah_movimientos_his.monto, 0),
                          0)) mto_debito,
               SUM(decode(fug_obt_tra_tipo(ge_transacciones.cod_transaccion, ge_transacciones.tipo, ge_transacciones.afecta),
                          'C',
                          nvl(ah_movimientos_his.monto, 0),
                          0)) mto_credito,
               COUNT('X')     cantidad
            FROM
               ge_transacciones,
               ah_movimientos_his,
               cuentas
            WHERE
                  ah_movimientos_his.cod_modulo = cuentas.cod_modulo
               AND ah_movimientos_his.cod_modalidad = cuentas.cod_modalidad
               AND ah_movimientos_his.cod_oficina = cuentas.cod_oficina
               AND ah_movimientos_his.nro_cuenta = cuentas.nro_cuenta
               AND ah_movimientos_his.fecha > nvl(cuentas.fec_ult_extracto, cuentas.fec_apertura - 1)
               AND ah_movimientos_his.fecha <= v_fec_actual
               AND ( ah_movimientos_his.reversado = 'N'
                     OR ( ah_movimientos_his.reversado = 'S'
                          AND fec_valor <= nvl(cuentas.fec_ult_extracto, cuentas.fec_apertura - 1)
                          AND EXISTS (
                  SELECT
                     1
                  FROM
                     ah_movimientos_his rev  -- CB. 25/09/2013.
                  WHERE
                        ah_movimientos_his.fec_valor = rev.fecha
                     AND ah_movimientos_his.hor_reversion = rev.hora
                     AND ah_movimientos_his.cod_usu_reversion = rev.cod_usuario
                     AND ah_movimientos_his.nro_secuencia = rev.nro_secuencia
                                -- DYDMR-5672 NAF 01/2017
                     AND ah_movimientos_his.nro_cuenta = rev.nro_cuenta
                     AND abs(ah_movimientos_his.monto) = abs(rev.monto)
               ) )
                     OR ( ah_movimientos_his.reversado = 'S'
                          AND ah_movimientos_his.cod_tra_padre IN ( 303, 302 )
                          AND ah_movimientos_his.cod_mad_padre = 455 ) )
               AND ah_movimientos_his.estado = 'N'
               AND ah_movimientos_his.cod_modulo = ge_transacciones.cod_modulo
               AND ah_movimientos_his.cod_modalidad = ge_transacciones.cod_modalidad
               AND ah_movimientos_his.cod_transaccion = ge_transacciones.cod_transaccion
               AND ge_transacciones.ve_cliente = 'S'
               AND ge_transacciones.tipo IN ( 'C', 'D' )
               AND nvl(ge_transacciones.afecta, 'XX') != 'B'
            GROUP BY
               cuentas.cod_persona,
               cuentas.nro_cuenta,
               cuentas.cod_modulo,
               cuentas.cod_modalidad,
               cuentas.cod_oficina
         )
         SELECT cuentas.*,
                NVL(movimientos.mto_debito, 0)  mto_debito,
                NVL(movimientos.mto_credito, 0) mto_credito,
                NVL(movimientos.cantidad, 0)    cantidad
         FROM cuentas
         LEFT JOIN movimientos
         ON cuentas.cod_persona = movimientos.cod_persona
            AND cuentas.nro_cuenta = movimientos.nro_cuenta
            AND cuentas.cod_modulo = movimientos.cod_modulo
            AND cuentas.cod_modalidad = movimientos.cod_modalidad
            AND cuentas.cod_oficina = movimientos.cod_oficina
         ORDER BY
            cuentas.cod_persona
         ;

         mov_masivos_list t_mov_mas_table := t_mov_mas_table();

         CURSOR cur_mov_vistas IS
         SELECT
            mov.cod_persona,
            v_fec_actual fec_actual,
            ah_movimientos_his.fecha,
            ah_movimientos_his.fec_valor,
            ah_movimientos_his.hora,
            ah_movimientos_his.nro_cuenta,
            ah_movimientos_his.nro_documento,
            ah_movimientos_his.cod_mod_padre,
            ah_movimientos_his.cod_mad_padre,
            ah_movimientos_his.cod_tra_padre,
            ( decode(fug_obt_tra_tipo(ge_transacciones.cod_transaccion, ge_transacciones.tipo, ge_transacciones.afecta),
                     'D',
                     nvl(ah_movimientos_his.monto, 0),
                     0) ) monto_D,
            ( decode(fug_obt_tra_tipo(ge_transacciones.cod_transaccion, ge_transacciones.tipo, ge_transacciones.afecta),
                     'C',
                     nvl(ah_movimientos_his.monto, 0),
                     0) ) monto_C,
            1 cod_extracto,
            v_frecuencia frecuencia,
            ah_movimientos_his.nro_secuencia,
            ah_movimientos_his.cod_ofi_origen,
            ah_movimientos_his.fec_insercion,
            decode(ge_transacciones.afecta, 'B', 'S', 'N') ind_bloqueo
         FROM
            ge_transacciones,
            ah_movimientos_his,
            TABLE(mov_masivos_list) mov
         WHERE
               ah_movimientos_his.cod_modulo = mov.cod_modulo
            AND ah_movimientos_his.cod_modalidad = mov.cod_modalidad
            AND ah_movimientos_his.cod_oficina = mov.cod_oficina
            AND ah_movimientos_his.nro_cuenta = mov.nro_cuenta
            AND ah_movimientos_his.fecha > mov.fec_movimiento
            AND ah_movimientos_his.fecha <= v_fec_actual
            AND ( ah_movimientos_his.reversado = 'N'
                  OR ( ah_movimientos_his.reversado = 'S'
                       AND fec_valor <= mov.fec_movimiento
                       AND EXISTS (
               SELECT
                  1
               FROM
                  ah_movimientos_his rev  -- CB. 25/09/2013.
               WHERE
                     ah_movimientos_his.fec_valor = rev.fecha
                  AND ah_movimientos_his.hor_reversion = rev.hora
                  AND ah_movimientos_his.cod_usu_reversion = rev.cod_usuario
                  AND ah_movimientos_his.nro_secuencia = rev.nro_secuencia
                          -- DYDMR-5672 NAF 01/2017
                  AND ah_movimientos_his.nro_cuenta = rev.nro_cuenta
                  AND abs(ah_movimientos_his.monto) = abs(rev.monto)
            ) )
                  OR ( ah_movimientos_his.reversado = 'S'
                       AND ah_movimientos_his.cod_tra_padre IN ( 303, 302 )
                       AND ah_movimientos_his.cod_mad_padre = 455 ) )
            AND ah_movimientos_his.estado = 'N'
            AND ah_movimientos_his.cod_modulo = ge_transacciones.cod_modulo
            AND ah_movimientos_his.cod_modalidad = ge_transacciones.cod_modalidad
            AND ah_movimientos_his.cod_transaccion = ge_transacciones.cod_transaccion
            AND ge_transacciones.ve_cliente = 'S'
            AND ge_transacciones.tipo IN ( 'C', 'D' )
            AND nvl(ge_transacciones.afecta, 'XX') != 'B';

         TYPE t_cur_mov_vistas_type IS TABLE OF cur_mov_vistas%rowtype;
         t_cur_mov_vistas  t_cur_mov_vistas_type;

         v_count_loop PLS_INTEGER := 0;
      BEGIN
         v_lugar := 'lp_generar_vistas';
         v_cod_persona := -1;
         v_initial_time := DBMS_UTILITY.get_time;
         
         v_inicio := DBMS_UTILITY.get_time;
         v_fec_inicio := SYSTIMESTAMP;
                  
         FOR av IN mae_cue LOOP
            BEGIN
                v_count_loop := v_count_loop + 1;
    
                IF v_cod_persona != av.cod_persona THEN
                   --Inicializo la variable que separa los extractos especificos
                   v_cod_persona := av.cod_persona;
                   v_cod_extracto := 1;
                   v_inserta := 'N';
                   IF NOT ge_ext_cli_cuentas_collection.EXISTS(av.cod_persona) THEN
                      ge_ext_cli_cuentas_collection(av.cod_persona) := -1;
                   END IF;
                END IF;
    
                --limpio variables
                v_sal_promedio := NULL;
                v_nro_cta_combinada := NULL;
                v_val_tasa := NULL;
                v_val_tae := NULL;
                --- asigno el codigo de extracto unico -----------------
                v_nro_cuenta := av.nro_cuenta;
                v_sal_ult_extracto := nvl(av.sal_ult_extracto, 0);
                v_tiene_mov := 'N';
                v_cantidad := 0;
                v_mto_bloqueo := lf_obt_mto_bloqueado(av.nro_cuenta);
                v_cod_per_ente := lf_obt_per_ente(av.cod_ente);
                v_fec_movimiento := nvl(av.fec_ult_extracto, av.fec_apertura - 1);
    
                --SE CAPTURA LOS DATOS PARA OBTENER LA DIRECCION CORRECTA DEL EXTRACTO :SServin 13-03-2015 CROGENEXT-14
                v_tip_gen_extracto := av.separado;--se obtiene si es individual o consolidado
                --se obtiene si es nómina o no--
                v_es_nomina := av.es_nomina;
                -----
    
                --@LReyes --la suma de todos los movimientos del historico ahora disponible en el Cursor
                v_mto_debito := av.mto_debito;
                v_mto_credito := av.mto_credito;
                v_cantidad := av.cantidad;
    
                IF nvl(v_cantidad, 0) > 0 OR nvl(v_can, 0) > 0 THEN
                   v_tiene_mov := 'S';
                END IF;
    
                v_existe := 'N';
                IF av.separado = 'I' OR av.cod_paquete > 0 THEN
                   --@LReyes --Array asociativo. Clave(cod_persona) Valor(cuenta para cod_extracto)
                   IF ge_ext_cli_cuentas_collection(av.cod_persona) < 0 THEN
                      ge_ext_cli_cuentas_collection(av.cod_persona) := 1;
                   ELSE
                      ge_ext_cli_cuentas_collection(av.cod_persona) := ge_ext_cli_cuentas_collection(av.cod_persona) + 1;
                   END IF;
                   v_cod_extracto := ge_ext_cli_cuentas_collection(av.cod_persona);
                   ---------------------------------------------------------
                ELSE
                   --@LReyes --Dado que se itera por cod_cliente ordenado, buscamos pre-existencia en el Array asociativo
                   IF ge_ext_cli_cuentas_collection(av.cod_persona) < 0 THEN
                      ge_ext_cli_cuentas_collection(av.cod_persona) := 1;
                      v_existe := 'N';
                   ELSE
                      v_existe := 'S';
                   END IF;
                   v_cod_extracto := ge_ext_cli_cuentas_collection(av.cod_persona);
                END IF;
    
                IF v_existe = 'N' THEN
                   -- busco los datos del cliente ---------------------------
                   lp_obtener_datos_del_cliente;
                   lp_dir_envio;
                   v_imprime_extracto := v_tip_extracto;
                   v_lugar := 'lp_generar_vistas: 1-insert GE_EXT_CLIENTES '
                              || v_cod_persona
                              || '-'
                              || v_dir_cliente;
                   INSERT INTO ge_ext_clientes (
                      cod_persona,
                      fec_extracto,
                      fre_extracto,
                      funcionario,
                      nom_cliente,
                      direccion,
                      telefono,
                      cod_usu_oficial,
                      cod_pais,
                      cod_ciudad,
                      tel_oficial,
                      nro_interno,
                      cod_extracto,
                      det_direccion,
                      observacion,
                      barrio,
                      cod_mensaje,
                      tip_impresion,
                      cli_confidencial,
                      cod_oficina,
                      cat_riesgo,
                      fec_ult_clasif,
                      cod_per_empresa,
                      tip_direccion
                   ) VALUES (
                      v_cod_persona,
                      v_fec_actual,
                      v_frecuencia,
                      v_es_empleado,
                      v_nom_cliente,
                      v_dir_cliente,
                      v_tel_cliente,
                      v_cod_usu_oficial,
                      v_cod_pais,
                      v_cod_ciudad,
                      v_tel_oficial,
                      v_int_oficial,
                      v_cod_extracto,
                      v_pri_obs_dir,
                      v_seg_obs_dir,
                      v_des_barrio,
                      '1',
                      v_imprime_extracto,
                      v_cli_confidencial,
                      decode(av.separado, 'I', av.cod_oficina, v_cod_ofi_cliente),
                      v_cat_riesgo,
                      v_fec_ult_clasif,
                      v_cod_per_ente,
                      v_tip_envio
                   );
    
                   v_inserta := 'S';
                END IF;
    
                v_lugar := 'lp_generar_vistas: Cta.combinada';
                --busca la cuenta combinada si corresponde
                IF av.cta_combinada = 'S' THEN
                   BEGIN
                      SELECT
                         nro_cta_cte
                      INTO v_nro_cta_combinada
                      FROM
                         cc_cta_combinadas
                      WHERE
                         nro_cta_ahorro = av.nro_cuenta;
    
                   EXCEPTION
                      WHEN no_data_found THEN
                         NULL;
                      WHEN OTHERS THEN
                         NULL;
                   END;
                END IF;
    
                
                --obtiene saldo promedio
                v_lugar := 'lp_generar_vistas: Saldo promedio';
                pag_cta.pr_obt_sal_promedio(av.cod_modulo, av.cod_modalidad, av.cod_oficina, av.nro_cuenta, v_fec_actual,
                                           v_fec_actual, v_sal_acumulado, v_sal_promedio, v_can_dia_acumulado);
                
                --- cargo los valores para el calculo de la tasa --
                v_lugar := 'lp_generar_vistas: Obtener Tasa';                
                v_val_tasa := fug_obt_val_tasa(av.cod_modulo, av.cod_modalidad, av.cod_oficina, av.nro_cuenta, av.cod_moneda,
                                              v_sal_promedio, av.tas_personalizada, av.cod_tasa, NULL, v_fec_actual);
                
                --obtiene tae
                v_lugar := 'lp_generar_vistas: Tae';    
                v_val_tae := pas_bcp.fu_obt_tae(v_val_tasa, 30);
                ----------------------------------------------------
                -- INSERTA REGISTRO EN EL ARCHIVO CABECERA ACTIVO --
                ----------------------------------------------------
                v_lugar := 'lp_generar_vistas: lf_obt_sal_blo_anterior';
                v_sal_blo_anterior := lf_obt_sal_blo_anterior(av.nro_cuenta, av.fec_ult_extracto);

                v_lugar := 'lp_generar_vistas: INSERT en GE_EXT_CLI_CUENTAS: ' || '-' || av.nro_cuenta;
                
                INSERT INTO ge_ext_cli_cuentas (
                   ge_ext_cli_cuentas.cod_persona,
                   ge_ext_cli_cuentas.fec_extracto,
                   ge_ext_cli_cuentas.tip_cuenta,
                   ge_ext_cli_cuentas.cod_oficina,
                   ge_ext_cli_cuentas.cod_modalidad,
                   ge_ext_cli_cuentas.nro_cuenta,
                   ge_ext_cli_cuentas.cod_moneda,
                   ge_ext_cli_cuentas.sal_anterior,
                   ge_ext_cli_cuentas.sal_actual,
                   ge_ext_cli_cuentas.nro_folio,
                   ge_ext_cli_cuentas.sal_a_confirmar,
                   ge_ext_cli_cuentas.cod_extracto,
                   ge_ext_cli_cuentas.fre_extracto,
                   sal_promedio,
                   nro_cta_combinada,
                   tas_nominal,
                   tas_efectiva,
                   ge_ext_cli_cuentas.sal_bloqueado,
                   ge_ext_cli_cuentas.cod_per_empresa,
                   sal_blo_anterior
                ) VALUES (
                   v_cod_persona,
		   v_fec_actual,
                   'A',
                   av.cod_oficina,
                   av.cod_modalidad,
                   av.nro_cuenta,
                   av.cod_moneda,
                   v_sal_ult_extracto,
                   nvl(v_sal_ult_extracto, 0) + nvl(v_mto_credito, 0) - nvl(v_mto_debito, 0),
                   av.nro_folio,
                   av.sal_ret_batch,
                   v_cod_extracto,
                   v_frecuencia,
                   v_sal_promedio,
                   v_nro_cta_combinada,
                   v_val_tasa,
                   v_val_tae,
                   v_mto_bloqueo,
                   v_cod_per_ente,
                   v_sal_blo_anterior
                );
    
                --@LReyes --Se modificaron por INSERT SELECT
                lp_generar_mov_retenciones(av.nro_cuenta);
                lp_generar_mov_pendientes(av.nro_cuenta);
    
                -- Si es Fin de Mes Actualizar el Saldo Mensual Actual.
                IF v_frecuencia = 'M' THEN
                   BEGIN
                      UPDATE ah_sal_mensuales
                      SET
                         sal_ult_extracto = nvl(v_sal_ult_extracto, 0) + nvl(v_mto_credito, 0) - nvl(v_mto_debito, 0)
                      WHERE
                            nro_cuenta = av.nro_cuenta
                         AND ano = TO_NUMBER(to_char(v_fec_actual, 'YYYY'))
                         AND mes = TO_NUMBER(to_char(v_fec_actual, 'MM'));
    
                   EXCEPTION
                      WHEN OTHERS THEN
                         pr_ins_log_error('Error al Actualizar el Saldo Mensual en CTA.VISTAS. ' || av.nro_cuenta || '. ' || sqlerrm, av.nro_cuenta);
                   END;
                END IF;
    
                IF v_tiene_mov = 'S' THEN
                   v_lugar := 'lp_generar_vistas: INSERT en GE_EXT_CUENTAS_TTG';
                   INSERT INTO GE_EXT_CUENTAS_TTG ( --@LReyes Tabla para la concurrencia
                      nro_cuenta,
                      cod_modulo,
                      cod_modalidad,
                      nro_folio,
                      fec_ult_extracto,
                      sal_ult_extracto,
                      nom_tabla,
                      cod_persona
                   ) VALUES (
                      av.nro_cuenta,
                      av.cod_modulo,
                      av.cod_modalidad,
                      av.nro_folio,
                      v_fec_actual,
                      nvl(v_sal_ult_extracto, 0) + nvl(v_mto_credito, 0) - nvl(v_mto_debito, 0),
                      'AH_CTA_VISTAS',
                      v_cod_persona
                   );
                   IF v_cod_extracto = 1 and v_cantidad < vg_max_movimientos THEN
                      -----------------------------------------------------
                      -- [MASIVO] INSERTA REGISTRO EN EL ARCHIVO DETALLE --
                      -----------------------------------------------------
                      --@LReyes --Guardo datos para recuperar luego, masivamente, los movimientos de la cuenta.
                      mov_masivos_list.EXTEND;
                      mov_masivos_list(mov_masivos_list.COUNT) := mov_mas_record(
                         v_cod_persona,
                         av.nro_cuenta,
                         av.cod_modulo,
                         av.cod_modalidad,
                         av.cod_oficina,
                         v_fec_movimiento
                      );
                      
                   ELSE
                      --------------------------------------------
                      -- INSERTA REGISTRO EN EL ARCHIVO DETALLE --
                      --------------------------------------------
                      v_lugar := 'lp_generar_vistas: INSERT en GE_EXT_CLI_MOVIMIENTOS';
                      INSERT INTO ge_ext_cli_movimientos (
                         cod_persona,
                         fec_extracto,
                         fec_movimiento,
                         fec_valor,
                         hor_movimiento,
                         nro_cuenta,
                         nro_documento,
                         cod_modulo,
                         cod_modalidad,
                         cod_tra_padre,
                         mto_debito,
                         mto_credito,
                         cod_extracto,
                         fre_extracto,
                         nro_secuencia,
                         cod_ofi_origen,
                         fec_insercion,
                         ind_bloqueo
                      )
                      SELECT
                         v_cod_persona,
                     	 v_fec_actual,
                         ah_movimientos_his.fecha,
                         ah_movimientos_his.fec_valor,
                         ah_movimientos_his.hora,
                         ah_movimientos_his.nro_cuenta,
                         ah_movimientos_his.nro_documento,
                         ah_movimientos_his.cod_mod_padre,
                         ah_movimientos_his.cod_mad_padre,
                         ah_movimientos_his.cod_tra_padre,
                         ( decode(fug_obt_tra_tipo(ge_transacciones.cod_transaccion, ge_transacciones.tipo, ge_transacciones.afecta),
                                  'D',
                                  nvl(ah_movimientos_his.monto, 0),
                                  0) ),
                         ( decode(fug_obt_tra_tipo(ge_transacciones.cod_transaccion, ge_transacciones.tipo, ge_transacciones.afecta),
                                  'C',
                                  nvl(ah_movimientos_his.monto, 0),
                                  0) ),
                         v_cod_extracto,
                         v_frecuencia,
                         ah_movimientos_his.nro_secuencia,
                         ah_movimientos_his.cod_ofi_origen,
                         ah_movimientos_his.fec_insercion,
                         decode(ge_transacciones.afecta, 'B', 'S', 'N')
                      FROM
                         ge_transacciones,
                         ah_movimientos_his
                      WHERE
                            ah_movimientos_his.cod_modulo = av.cod_modulo
                         AND ah_movimientos_his.cod_modalidad = av.cod_modalidad
                         AND ah_movimientos_his.cod_oficina = av.cod_oficina
                         AND ah_movimientos_his.nro_cuenta = av.nro_cuenta
                         AND ah_movimientos_his.fecha > v_fec_movimiento
                         AND ah_movimientos_his.fecha <= v_fec_actual
                         AND ( ah_movimientos_his.reversado = 'N'
                               OR ( ah_movimientos_his.reversado = 'S'
                                    AND fec_valor <= v_fec_movimiento
                                    AND EXISTS (
                            SELECT
                               1
                            FROM
                               ah_movimientos_his rev  -- CB. 25/09/2013.
                            WHERE
                                  ah_movimientos_his.fec_valor = rev.fecha
                               AND ah_movimientos_his.hor_reversion = rev.hora
                               AND ah_movimientos_his.cod_usu_reversion = rev.cod_usuario
                               AND ah_movimientos_his.nro_secuencia = rev.nro_secuencia
                                       -- DYDMR-5672 NAF 01/2017
                               AND ah_movimientos_his.nro_cuenta = rev.nro_cuenta
                               AND abs(ah_movimientos_his.monto) = abs(rev.monto)
                         ) )
                               OR ( ah_movimientos_his.reversado = 'S'
                                    AND ah_movimientos_his.cod_tra_padre IN ( 303, 302 )
                                    AND ah_movimientos_his.cod_mad_padre = 455 ) )
                         AND ah_movimientos_his.estado = 'N'
                         AND ah_movimientos_his.cod_modulo = ge_transacciones.cod_modulo
                         AND ah_movimientos_his.cod_modalidad = ge_transacciones.cod_modalidad
                         AND ah_movimientos_his.cod_transaccion = ge_transacciones.cod_transaccion
                         AND ge_transacciones.ve_cliente = 'S'
                         AND ge_transacciones.tipo IN ( 'C', 'D' )
                         AND nvl(ge_transacciones.afecta, 'XX') != 'B';
    
                   END IF;
                END IF;
                
                v_lugar := 'lp_generar_vistas: Busca cambio de modalidad';
                DECLARE
                    v_cod_modalidad     NUMBER;
                    v_mto_movimientos   NUMBER;
                    v_cant_movimientos  NUMBER;
                BEGIN
                    SELECT MIN(cod_modalidad)
                    INTO v_cod_modalidad
                    FROM ah_movimientos_his
                    WHERE cod_modulo = av.cod_modulo
                     AND cod_modalidad != av.cod_modalidad
                     AND cod_oficina = av.cod_oficina
                     AND nro_cuenta = av.nro_cuenta
                     AND fecha > v_fec_movimiento
                     AND fecha <= v_fec_actual;
                     
                     IF v_cod_modalidad IS NOT NULL THEN
                         v_lugar := 'lp_generar_vistas: INSERT en GE_EXT_CLI_MOVIMIENTOS(CAMBIO DE MODALIDAD)';
    
                          INSERT INTO ge_ext_cli_movimientos (
                             cod_persona,
                             fec_extracto,
                             fec_movimiento,
                             fec_valor,
                             hor_movimiento,
                             nro_cuenta,
                             nro_documento,
                             cod_modulo,
                             cod_modalidad,
                             cod_tra_padre,
                             mto_debito,
                             mto_credito,
                             cod_extracto,
                             fre_extracto,
                             nro_secuencia,
                             cod_ofi_origen,
                             fec_insercion,
                             concepto,
                             ind_bloqueo
                          )
                          SELECT
                             v_cod_persona,
                             v_fec_actual,
                             ah_movimientos_his.fecha,
                             ah_movimientos_his.fec_valor,
                             ah_movimientos_his.hora,
                             ah_movimientos_his.nro_cuenta,
                             ah_movimientos_his.nro_documento,
                             ah_movimientos_his.cod_mod_padre,
                             ah_movimientos_his.cod_mad_padre,
                             ah_movimientos_his.cod_tra_padre,
                             ( decode(fug_obt_tra_tipo(ge_transacciones.cod_transaccion, ge_transacciones.tipo, ge_transacciones.afecta),
                                      'D',
                                      nvl(ah_movimientos_his.monto, 0),
                                      0) ),
                             ( decode(fug_obt_tra_tipo(ge_transacciones.cod_transaccion, ge_transacciones.tipo, ge_transacciones.afecta),
                                      'C',
                                      nvl(ah_movimientos_his.monto, 0),
                                      0) ),
                             v_cod_extracto,
                             v_frecuencia,
                             ah_movimientos_his.nro_secuencia,
                             ah_movimientos_his.cod_ofi_origen,
                             ah_movimientos_his.fec_insercion,
                             'CAMBIO DE MODALIDAD',
                             decode(ge_transacciones.afecta, 'B', 'S', 'N')
                          FROM
                             ge_transacciones,
                             ah_movimientos_his
                          WHERE
                                ah_movimientos_his.cod_modulo = av.cod_modulo
                             AND ah_movimientos_his.cod_modalidad = v_cod_modalidad
                             AND ah_movimientos_his.cod_oficina = av.cod_oficina
                             AND ah_movimientos_his.nro_cuenta = av.nro_cuenta
                             AND ah_movimientos_his.fecha > v_fec_movimiento
                             AND ah_movimientos_his.fecha <= v_fec_actual
                             AND ( ah_movimientos_his.reversado = 'N'
                                   OR ( ah_movimientos_his.reversado = 'S'
                                        AND fec_valor <= v_fec_movimiento
                                        AND EXISTS (
                                SELECT
                                   1
                                FROM
                                   ah_movimientos_his rev  -- CB. 25/09/2013.
                                WHERE
                                      ah_movimientos_his.fec_valor = rev.fecha
                                   AND ah_movimientos_his.hor_reversion = rev.hora
                                   AND ah_movimientos_his.cod_usu_reversion = rev.cod_usuario
                                   AND ah_movimientos_his.nro_secuencia = rev.nro_secuencia
                                           -- DYDMR-5672 NAF 01/2017
                                   AND ah_movimientos_his.nro_cuenta = rev.nro_cuenta
                                   AND abs(ah_movimientos_his.monto) = abs(rev.monto)
                             ) )
                                   OR ( ah_movimientos_his.reversado = 'S'
                                        AND ah_movimientos_his.cod_tra_padre IN ( 303, 302 )
                                        AND ah_movimientos_his.cod_mad_padre = 455 ) )
                             AND ah_movimientos_his.estado = 'N'
                             AND ah_movimientos_his.cod_modulo = ge_transacciones.cod_modulo
                             AND ah_movimientos_his.cod_modalidad = ge_transacciones.cod_modalidad
                             AND ah_movimientos_his.cod_transaccion = ge_transacciones.cod_transaccion
                             AND ge_transacciones.ve_cliente = 'S'
                             AND ge_transacciones.tipo IN ( 'C', 'D' )
                             AND nvl(ge_transacciones.afecta, 'XX') != 'B';
                             
                             v_lugar := 'lp_generar_vistas: SELECT en GE_EXT_CLI_MOVIMIENTOS(CAMBIO DE MODALIDAD)';
                             
                             SELECT count(1), sum(mto_credito-mto_debito)
                             INTO v_cant_movimientos, v_mto_movimientos
                             FROM ge_ext_cli_movimientos
                             WHERE nro_cuenta = av.nro_cuenta
                             AND fec_extracto = v_fec_actual
                             AND concepto = 'CAMBIO DE MODALIDAD';
                             
                             v_lugar := 'lp_generar_vistas: UPDATE sal_total en GE_EXT_CLI_CUENTAS(CAMBIO DE MODALIDAD)';
                             
                             UPDATE ge_ext_cli_cuentas
                             SET sal_actual = sal_actual + v_mto_movimientos
                             WHERE nro_cuenta = av.nro_cuenta
                             AND fec_extracto = v_fec_actual;
                             
                             v_lugar := 'lp_generar_vistas: UPDATE sal_ult_extracto en GE_EXT_CUENTAS_TTG(CAMBIO DE MODALIDAD)';
                             
                             UPDATE ge_ext_cuentas_ttg
                             SET sal_ult_extracto = sal_ult_extracto + v_mto_movimientos
                             WHERE nro_cuenta = av.nro_cuenta;
                             
                             pr_ins_log_error('CAMBIO DE MODALIDAD: modalidad: ' || v_cod_modalidad || ', cantidad: ' || v_cant_movimientos || ', monto: ' || v_mto_movimientos, av.nro_cuenta);
                        END IF;
                EXCEPTION
                    WHEN OTHERS THEN
                        pr_ins_log_error(v_lugar || ' | ' || SQLERRM, av.nro_cuenta);
                END; 
                -- fin insert movimientos CAMBIO DE MODALIDAD
    
                IF v_count_loop >= 50 THEN
                   COMMIT;
                   v_count_loop := 0;
                END IF;
            EXCEPTION
                WHEN OTHERS THEN
                    pr_ins_log_error(v_lugar || ' | ' || SQLERRM, av.nro_cuenta);
                    UPDATE ge_ext_clientes
                    SET fre_Extracto = lower(v_frecuencia)
                    WHERE cod_persona = v_cod_persona
                    AND fec_extracto = v_fec_actual;
            END;
         END LOOP;
                  
         v_fec_fin := SYSTIMESTAMP;
         v_duracion_seg := TRUNC((DBMS_UTILITY.get_time - v_inicio) / 100, 2);
                  
         pr_log_perf_event(
                p_cod_programa                 => 'PERF_PR_GEN_EXTRACTO',
                p_cod_subproceso               => 'lp_generar_vistas~CURSOR mae_cue',
                p_fec_inicio                   => v_fec_inicio,
                p_fec_fin                      => v_fec_fin,
                p_val_duracion_seg             => v_duracion_seg,
                p_est_resultado                => 'SUCCESS');
         
         COMMIT;

         -----------------------------------------------------
         -- [MASIVO] INSERTA REGISTRO EN EL ARCHIVO DETALLE --
         -----------------------------------------------------
         --@LReyes --Datos antes guardados para recuperar masivamente los movimientos de las cuentas.
         IF mov_masivos_list.COUNT > 0 THEN
            v_lugar := 'lp_generar_vistas: [MASIVO] INSERT en GE_EXT_CLI_MOVIMIENTOS';
            ts_inicio := SYSTIMESTAMP;
            v_cant_mov := 0;
            
            v_inicio := DBMS_UTILITY.get_time;
            v_fec_inicio := SYSTIMESTAMP;
            
            OPEN cur_mov_vistas;
            v_initial_time := DBMS_UTILITY.get_time;
            LOOP                
               FETCH cur_mov_vistas
               BULK COLLECT INTO t_cur_mov_vistas LIMIT vg_bulk_size;
               EXIT WHEN t_cur_mov_vistas.COUNT() = 0;
                
                v_cant_mov := v_cant_mov + t_cur_mov_vistas.COUNT();

               FORALL i IN t_cur_mov_vistas.FIRST() .. t_cur_mov_vistas.LAST()
                  INSERT INTO ge_ext_cli_movimientos (
                        cod_persona,
                        fec_extracto,
                        fec_movimiento,
                        fec_valor,
                        hor_movimiento,
                        nro_cuenta,
                        nro_documento,
                        cod_modulo,
                        cod_modalidad,
                        cod_tra_padre,
                        mto_debito,
                        mto_credito,
                        cod_extracto,
                        fre_extracto,
                        nro_secuencia,
                        cod_ofi_origen,
                        fec_insercion,
                        ind_bloqueo
                  )
                  VALUES (
                     t_cur_mov_vistas(i).cod_persona,
                     t_cur_mov_vistas(i).fec_actual,
                     t_cur_mov_vistas(i).fecha,
                     t_cur_mov_vistas(i).fec_valor,
                     t_cur_mov_vistas(i).hora,
                     t_cur_mov_vistas(i).nro_cuenta,
                     t_cur_mov_vistas(i).nro_documento,
                     t_cur_mov_vistas(i).cod_mod_padre,
                     t_cur_mov_vistas(i).cod_mad_padre,
                     t_cur_mov_vistas(i).cod_tra_padre,
                     t_cur_mov_vistas(i).monto_D,
                     t_cur_mov_vistas(i).monto_C,
                     t_cur_mov_vistas(i).cod_extracto,
                     t_cur_mov_vistas(i).frecuencia,
                     t_cur_mov_vistas(i).nro_secuencia,
                     t_cur_mov_vistas(i).cod_ofi_origen,
                     t_cur_mov_vistas(i).fec_insercion,
                     t_cur_mov_vistas(i).ind_bloqueo
                  );
               COMMIT;
            END LOOP;

            CLOSE cur_mov_vistas;
                        
            v_fec_fin := SYSTIMESTAMP;
            v_duracion_seg := TRUNC((DBMS_UTILITY.get_time - v_inicio) / 100, 2);
                  
            pr_log_perf_event(
                p_cod_programa                 => 'PERF_PR_GEN_EXTRACTO',
                p_cod_subproceso               => 'lp_generar_vistas~CURSOR cur_mov_vistas',
                p_fec_inicio                   => v_fec_inicio,
                p_fec_fin                      => v_fec_fin,
                p_val_duracion_seg             => v_duracion_seg,
                p_est_resultado                => 'SUCCESS');
            
            ts_fin := SYSTIMESTAMP;
            pr_ins_log_error('lp_generar_vistas: [insert mov masivo] cantidad->' || v_cant_mov || ', duracion->' || substr(ts_fin-ts_inicio, -18, 11), null);
         END IF;

      END lp_generar_vistas;
      
      PROCEDURE lp_generar_programados
      IS
         v_sal_ult_extracto  NUMBER(18, 2) DEFAULT 0;
         v_mto_debito        NUMBER(18, 2);
         v_mto_credito       NUMBER(18, 2);
         v_existe            VARCHAR2(01) := 'N';
         v_tiene_mov         VARCHAR2(01) := 'N';
         v_cantidad          NUMBER := 0;-- TN-1003 EFMILANES: se paso de NUMBER(6) a NUMBER porque quedo chica
         v_imprime_extracto  VARCHAR2(1);
         v_sal_acumulado     cc_sal_mensuales.sal_acu_deudor%TYPE;
         v_sal_promedio      cc_sal_mensuales.sal_acu_deudor%TYPE;
         v_can_dia_acumulado cc_sal_mensuales.can_dia_acumulado%TYPE;
         v_nro_cta_combinada cc_cta_combinadas.nro_cta_ahorro%TYPE;
         v_val_tasa          ge_tas_fechas.val_tasa%TYPE;
         v_val_tae           ge_tas_fechas.val_tasa%TYPE;
         ts_inicio          TIMESTAMP;
         ts_fin             TIMESTAMP;
         v_cant_mov         NUMBER;

         ----------------------------------
         -- CURSOR DEL ARCHIVO PRINCIPAL --
         ----------------------------------
         CURSOR mae_cue IS
         with cuentas AS (
            SELECT
               cli.cod_persona,
               ge_cta_clientes.cod_modulo,
               ge_cta_clientes.cod_modalidad,
               ge_cta_clientes.cod_oficina,
               ge_cta_clientes.nro_cuenta,
               ah_cta_plazos.cod_moneda,
               nvl(ah_cta_plazos.sal_ult_extracto, ah_cta_plazos.sal_tot_batch)    sal_ult_extracto,
               nvl(ah_cta_plazos.nro_folio, 0) + 1                                 nro_folio,
               ah_cta_plazos.denominacion,
               ah_cta_plazos.sal_ret_batch,
               nvl(ah_cta_plazos.fec_ult_extracto, ah_cta_plazos.fec_apertura - 1) fec_ult_extracto,
               nvl(bpd.val_parametro, 'C')                                         separado,
               ah_cta_plazos.fec_apertura,
               ah_cta_plazos.rowid                                                 registro,
               'N' cta_combinada,
               ah_cta_plazos.tas_personalizada,
               ah_cta_plazos.val_tasa,
               ah_cta_plazos.sal_bloqueado,
               null cod_ente,
               'N'                                                                 es_nomina,
               nvl(ge_paq_cuentas.cod_paquete, 0)                                  cod_paquete
            FROM
               ge_dir_envios,
               ah_cta_plazos,
               ge_cta_clientes,
               ge_paq_cuentas,
               ba_per_dat_adicionales bpd,
               TABLE(mae_cli_ctas_list) cli
            WHERE  ge_dir_envios.cod_persona (+) = ge_cta_clientes.cod_persona
               AND ge_dir_envios.nro_cuenta (+) = ge_cta_clientes.nro_cuenta
               AND ge_cta_clientes.cod_persona = cli.cod_persona
               AND cli.cod_modulo = 3
               AND cli.cod_modalidad = 38
               AND ge_cta_clientes.cod_modalidad = cli.cod_modalidad
               AND ge_cta_clientes.relacion = 'P'
               AND ah_cta_plazos.cod_modulo = ge_cta_clientes.cod_modulo
               AND ah_cta_plazos.cod_modalidad = ge_cta_clientes.cod_modalidad
               AND ah_cta_plazos.cod_oficina = ge_cta_clientes.cod_oficina
               AND ah_cta_plazos.nro_cuenta = ge_cta_clientes.nro_cuenta
               AND ah_cta_plazos.fre_extracto = v_frecuencia
               AND bpd.cod_persona (+) = ge_cta_clientes.cod_persona
               AND bpd.parametro (+) = 'TIP_GEN_EXTRACTOS'
               AND ( ( ah_cta_plazos.estado NOT IN ( 'C', 'P', 'T' ) )
                     OR ( ah_cta_plazos.estado IN ( 'C', 'P', 'T' )
                          AND ah_cta_plazos.fec_ult_movimiento >= v_pri_dia_mes_habil
                          AND ah_cta_plazos.fec_ult_movimiento > nvl(ah_cta_plazos.fec_ult_extracto, ah_cta_plazos.fec_apertura - 1) ) )
               AND ge_paq_cuentas.nro_cuenta (+) = ge_cta_clientes.nro_cuenta
               AND ge_paq_cuentas.cod_persona (+) = ge_cta_clientes.cod_persona
         ),
         movimientos AS (
            SELECT
               cuentas.cod_persona,
               cuentas.nro_cuenta,
               cuentas.cod_modulo,
               cuentas.cod_modalidad,
               cuentas.cod_oficina,
               SUM(decode(fug_obt_tra_tipo(ge_transacciones.cod_transaccion, ge_transacciones.tipo, ge_transacciones.afecta),
                          'D',
                          nvl(ah_movimientos_his.monto, 0),
                          0)) mto_debito,
               SUM(decode(fug_obt_tra_tipo(ge_transacciones.cod_transaccion, ge_transacciones.tipo, ge_transacciones.afecta),
                          'C',
                          nvl(ah_movimientos_his.monto, 0),
                          0)) mto_credito,
               COUNT('X')     cantidad
            FROM
               ge_transacciones,
               ah_movimientos_his,
               cuentas
            WHERE
                  ah_movimientos_his.cod_modulo = cuentas.cod_modulo
               AND ah_movimientos_his.cod_modalidad = cuentas.cod_modalidad
               AND ah_movimientos_his.cod_oficina = cuentas.cod_oficina
               AND ah_movimientos_his.nro_cuenta = cuentas.nro_cuenta
               AND ah_movimientos_his.fecha > nvl(cuentas.fec_ult_extracto, cuentas.fec_apertura - 1)
               AND ah_movimientos_his.fecha <= v_fec_actual
               AND ( ah_movimientos_his.reversado = 'N'
                     OR ( ah_movimientos_his.reversado = 'S'
                          AND fec_valor <= nvl(cuentas.fec_ult_extracto, cuentas.fec_apertura - 1)
                          AND EXISTS (SELECT 1
                                        FROM ah_movimientos_his rev
                                       WHERE ah_movimientos_his.fec_valor = rev.fecha
                                         AND ah_movimientos_his.hor_reversion = rev.hora
                                         AND ah_movimientos_his.cod_usu_reversion = rev.cod_usuario
                                         AND ah_movimientos_his.nro_secuencia = rev.nro_secuencia
                                             AND ah_movimientos_his.nro_cuenta = rev.nro_cuenta
                                             AND abs(ah_movimientos_his.monto) = abs(rev.monto)
                                        ) 
                          )
                                             OR ( ah_movimientos_his.reversado = 'S'
                                                  AND ah_movimientos_his.cod_tra_padre IN ( 303, 302 )
                                                  AND ah_movimientos_his.cod_mad_padre = 455 ) 
                     )
               AND ah_movimientos_his.estado = 'N'
               AND ah_movimientos_his.cod_modulo = ge_transacciones.cod_modulo
               AND ah_movimientos_his.cod_modalidad = ge_transacciones.cod_modalidad
               AND ah_movimientos_his.cod_transaccion = ge_transacciones.cod_transaccion
               AND ge_transacciones.ve_cliente = 'S'
               AND ge_transacciones.tipo IN ( 'C', 'D' )
               AND nvl(ge_transacciones.afecta, 'XX') != 'B'
            GROUP BY
               cuentas.cod_persona,
               cuentas.nro_cuenta,
               cuentas.cod_modulo,
               cuentas.cod_modalidad,
               cuentas.cod_oficina
         )
         SELECT cuentas.*,
                NVL(movimientos.mto_debito, 0)  mto_debito,
                NVL(movimientos.mto_credito, 0) mto_credito,
                NVL(movimientos.cantidad, 0)    cantidad
         FROM cuentas
         LEFT JOIN movimientos
         ON cuentas.cod_persona = movimientos.cod_persona
            AND cuentas.nro_cuenta = movimientos.nro_cuenta
            AND cuentas.cod_modulo = movimientos.cod_modulo
            AND cuentas.cod_modalidad = movimientos.cod_modalidad
            AND cuentas.cod_oficina = movimientos.cod_oficina
         ORDER BY
            cuentas.cod_persona;

         mov_masivos_list t_mov_mas_table := t_mov_mas_table();

         CURSOR cur_mov_programados IS
         SELECT
            mov.cod_persona,
            v_fec_actual fec_actual,
            ah_movimientos_his.fecha,
            ah_movimientos_his.fec_valor,
            ah_movimientos_his.hora,
            ah_movimientos_his.nro_cuenta,
            ah_movimientos_his.nro_documento,
            ah_movimientos_his.cod_mod_padre,
            ah_movimientos_his.cod_mad_padre,
            ah_movimientos_his.cod_tra_padre,
            ( decode(fug_obt_tra_tipo(ge_transacciones.cod_transaccion, ge_transacciones.tipo, ge_transacciones.afecta),
                     'D',
                     nvl(ah_movimientos_his.monto, 0),
                     0) ) monto_D,
            ( decode(fug_obt_tra_tipo(ge_transacciones.cod_transaccion, ge_transacciones.tipo, ge_transacciones.afecta),
                     'C',
                     nvl(ah_movimientos_his.monto, 0),
                     0) ) monto_C,
            1 cod_extracto,
            v_frecuencia frecuencia,
            ah_movimientos_his.nro_secuencia,
            ah_movimientos_his.cod_ofi_origen,
            ah_movimientos_his.fec_insercion,
            decode(ge_transacciones.afecta, 'B', 'S', 'N') ind_bloqueo
         FROM
            ge_transacciones,
            ah_movimientos_his,
            TABLE(mov_masivos_list) mov
         WHERE
               ah_movimientos_his.cod_modulo = mov.cod_modulo
            AND ah_movimientos_his.cod_modalidad = mov.cod_modalidad
            AND ah_movimientos_his.cod_oficina = mov.cod_oficina
            AND ah_movimientos_his.nro_cuenta = mov.nro_cuenta
            AND ah_movimientos_his.fecha > mov.fec_movimiento
            AND ah_movimientos_his.fecha <= v_fec_actual
            AND ( ah_movimientos_his.reversado = 'N'
                  OR ( ah_movimientos_his.reversado = 'S'
                       AND fec_valor <= mov.fec_movimiento
                       AND EXISTS (
               SELECT
                  1
               FROM
                  ah_movimientos_his rev
               WHERE
                     ah_movimientos_his.fec_valor = rev.fecha
                  AND ah_movimientos_his.hor_reversion = rev.hora
                  AND ah_movimientos_his.cod_usu_reversion = rev.cod_usuario
                  AND ah_movimientos_his.nro_secuencia = rev.nro_secuencia
                  AND ah_movimientos_his.nro_cuenta = rev.nro_cuenta
                  AND abs(ah_movimientos_his.monto) = abs(rev.monto)
            ) )
                  OR ( ah_movimientos_his.reversado = 'S'
                       AND ah_movimientos_his.cod_tra_padre IN ( 303, 302 )
                       AND ah_movimientos_his.cod_mad_padre = 455 ) )
            AND ah_movimientos_his.estado = 'N'
            AND ah_movimientos_his.cod_modulo = ge_transacciones.cod_modulo
            AND ah_movimientos_his.cod_modalidad = ge_transacciones.cod_modalidad
            AND ah_movimientos_his.cod_transaccion = ge_transacciones.cod_transaccion
            AND ge_transacciones.ve_cliente = 'S'
            AND ge_transacciones.tipo IN ( 'C', 'D' )
            AND nvl(ge_transacciones.afecta, 'XX') != 'B';

         TYPE t_cur_mov_programados_type IS TABLE OF cur_mov_programados%rowtype;
         t_cur_mov_programados  t_cur_mov_programados_type;

         v_count_loop PLS_INTEGER := 0;
      BEGIN
         v_lugar := 'lp_generar_programados';
         v_cod_persona := -1;
         v_initial_time := DBMS_UTILITY.get_time;
         
         v_inicio := DBMS_UTILITY.get_time;
         v_fec_inicio := SYSTIMESTAMP;
         
         FOR ap IN mae_cue LOOP
            BEGIN
                v_count_loop := v_count_loop + 1;
    
                IF v_cod_persona != ap.cod_persona THEN
                   --Inicializo la variable que separa los extractos especificos
                   v_cod_persona := ap.cod_persona;
                   v_cod_extracto := 1;
                   v_inserta := 'N';
                   IF NOT ge_ext_cli_cuentas_collection.EXISTS(ap.cod_persona) THEN
                      ge_ext_cli_cuentas_collection(ap.cod_persona) := -1;
                   END IF;
                END IF;
    
                --limpio variables
                v_sal_promedio := NULL;
                v_nro_cta_combinada := NULL;
                v_val_tasa := NULL;
                v_val_tae := NULL;
                --- asigno el codigo de extracto unico -----------------
                v_nro_cuenta := ap.nro_cuenta;
                v_sal_ult_extracto := nvl(ap.sal_ult_extracto, 0);
                v_tiene_mov := 'N';
                v_cantidad := 0;
                v_mto_bloqueo := lf_obt_mto_bloqueado(ap.nro_cuenta);
                v_cod_per_ente := lf_obt_per_ente(ap.cod_ente);
                v_fec_movimiento := nvl(ap.fec_ult_extracto, ap.fec_apertura - 1);
    
                --SE CAPTURA LOS DATOS PARA OBTENER LA DIRECCION CORRECTA DEL EXTRACTO :SServin 13-03-2015 CROGENEXT-14
                v_tip_gen_extracto := ap.separado;--se obtiene si es individual o consolidado
                --se obtiene si es nómina o no--
                v_es_nomina := ap.es_nomina;
    
                --la suma de todos los movimientos del historico ahora disponible en el Cursor
                v_mto_debito := ap.mto_debito;
                v_mto_credito := ap.mto_credito;
                v_cantidad := ap.cantidad;
    
                IF nvl(v_cantidad, 0) > 0 THEN
                   v_tiene_mov := 'S';
                END IF;
    
                v_existe := 'N';
                IF ap.separado = 'I' OR ap.cod_paquete > 0 THEN
                   --Array asociativo. Clave(cod_persona) Valor(cuenta para cod_extracto)
                   IF ge_ext_cli_cuentas_collection(ap.cod_persona) < 0 THEN
                      ge_ext_cli_cuentas_collection(ap.cod_persona) := 1;
                   ELSE
                      ge_ext_cli_cuentas_collection(ap.cod_persona) := ge_ext_cli_cuentas_collection(ap.cod_persona) + 1;
                   END IF;
                   v_cod_extracto := ge_ext_cli_cuentas_collection(ap.cod_persona);
                   ---------------------------------------------------------
                ELSE
                   --Dado que se itera por cod_cliente ordenado, buscamos pre-existencia en el Array asociativo
                   IF ge_ext_cli_cuentas_collection(ap.cod_persona) < 0 THEN
                      ge_ext_cli_cuentas_collection(ap.cod_persona) := 1;
                      v_existe := 'N';
                   ELSE
                      v_existe := 'S';
                   END IF;
                   v_cod_extracto := ge_ext_cli_cuentas_collection(ap.cod_persona);
                END IF;
    
                IF v_existe = 'N' THEN
                   -- busco los datos del cliente ---------------------------
                   lp_obtener_datos_del_cliente;
                   lp_dir_envio;
                   v_imprime_extracto := v_tip_extracto;
                   v_lugar := 'lp_generar_programados: 1-insert GE_EXT_CLIENTES '
                              || v_cod_persona
                              || '-'
                              || v_dir_cliente;
                   INSERT INTO ge_ext_clientes (
                      cod_persona,
                      fec_extracto,
                      fre_extracto,
                      funcionario,
                      nom_cliente,
                      direccion,
                      telefono,
                      cod_usu_oficial,
                      cod_pais,
                      cod_ciudad,
                      tel_oficial,
                      nro_interno,
                      cod_extracto,
                      det_direccion,
                      observacion,
                      barrio,
                      cod_mensaje,
                      tip_impresion,
                      cli_confidencial,
                      cod_oficina,
                      cat_riesgo,
                      fec_ult_clasif,
                      cod_per_empresa,
                      tip_direccion
                   ) VALUES (
                      v_cod_persona,
                      v_fec_actual,
                      v_frecuencia,
                      v_es_empleado,
                      v_nom_cliente,
                      v_dir_cliente,
                      v_tel_cliente,
                      v_cod_usu_oficial,
                      v_cod_pais,
                      v_cod_ciudad,
                      v_tel_oficial,
                      v_int_oficial,
                      v_cod_extracto,
                      v_pri_obs_dir,
                      v_seg_obs_dir,
                      v_des_barrio,
                      '1',
                      v_imprime_extracto,
                      v_cli_confidencial,
                      decode(ap.separado, 'I', ap.cod_oficina, v_cod_ofi_cliente),
                      v_cat_riesgo,
                      v_fec_ult_clasif,
                      v_cod_per_ente,
                      v_tip_envio
                   );
    
                   v_inserta := 'S';
                END IF;
    
                v_lugar := 'lp_generar_programados: Cta.combinada';
                --busca la cuenta combinada si corresponde
                IF ap.cta_combinada = 'S' THEN
                   BEGIN
                      SELECT
                         nro_cta_cte
                      INTO v_nro_cta_combinada
                      FROM
                         cc_cta_combinadas
                      WHERE
                         nro_cta_ahorro = ap.nro_cuenta;
    
                   EXCEPTION
                      WHEN no_data_found THEN
                         NULL;
                      WHEN OTHERS THEN
                         NULL;
                   END;
                END IF;
    
                --obtiene saldo promedio
                v_lugar := 'lp_generar_programados: Saldo promedio';
                pag_cta.pr_obt_sal_promedio(ap.cod_modulo, ap.cod_modalidad, ap.cod_oficina, ap.nro_cuenta, v_fec_actual,
                                           v_fec_actual, v_sal_acumulado, v_sal_promedio, v_can_dia_acumulado);

                --- cargo los valores para el calculo de la tasa --
                v_lugar := 'lp_generar_programados: Obtener Tasa';
                v_val_tasa := ap.val_tasa; 

                --obtiene tae
                v_lugar := 'lp_generar_programados: Tae';    
                v_val_tae := pas_bcp.fu_obt_tae(v_val_tasa, 30);

                ----------------------------------------------------
                -- INSERTA REGISTRO EN EL ARCHIVO CABECERA ACTIVO --
                ----------------------------------------------------
                v_lugar := 'lp_generar_programados: lf_obt_sal_blo_anterior';
                v_sal_blo_anterior := lf_obt_sal_blo_anterior(ap.nro_cuenta, ap.fec_ult_extracto);
                
                v_lugar := 'lp_generar_programados: INSERT en GE_EXT_CLI_CUENTAS: ' || '-' || ap.nro_cuenta;
                INSERT INTO ge_ext_cli_cuentas (
                   ge_ext_cli_cuentas.cod_persona,
                   ge_ext_cli_cuentas.fec_extracto,
                   ge_ext_cli_cuentas.tip_cuenta,
                   ge_ext_cli_cuentas.cod_oficina,
                   ge_ext_cli_cuentas.cod_modalidad,
                   ge_ext_cli_cuentas.nro_cuenta,
                   ge_ext_cli_cuentas.cod_moneda,
                   ge_ext_cli_cuentas.sal_anterior,
                   ge_ext_cli_cuentas.sal_actual,
                   ge_ext_cli_cuentas.nro_folio,
                   ge_ext_cli_cuentas.sal_a_confirmar,
                   ge_ext_cli_cuentas.cod_extracto,
                   ge_ext_cli_cuentas.fre_extracto,
                   sal_promedio,
                   nro_cta_combinada,
                   tas_nominal,
                   tas_efectiva,
                   ge_ext_cli_cuentas.sal_bloqueado,
                   ge_ext_cli_cuentas.cod_per_empresa,
                   sal_blo_anterior
                ) VALUES (
                   v_cod_persona,
               	   v_fec_actual,
                   'A',
                   ap.cod_oficina,
                   ap.cod_modalidad,
                   ap.nro_cuenta,
                   ap.cod_moneda,
                   v_sal_ult_extracto,
                   nvl(v_sal_ult_extracto, 0) + nvl(v_mto_credito, 0) - nvl(v_mto_debito, 0),
                   ap.nro_folio,
                   ap.sal_ret_batch,
                   v_cod_extracto,
                   v_frecuencia,
                   v_sal_promedio,
                   v_nro_cta_combinada,
                   v_val_tasa,
                   v_val_tae,
                   v_mto_bloqueo,
                   v_cod_per_ente,
                   v_sal_blo_anterior
                );
    
                --Se modificaron por INSERT SELECT
                lp_generar_mov_retenciones(ap.nro_cuenta);
                lp_generar_mov_pendientes(ap.nro_cuenta);
    
                -- Si es Fin de Mes Actualizar el Saldo Mensual Actual.
                IF v_frecuencia = 'M' THEN
                   BEGIN
                      UPDATE ah_sal_mensuales
                      SET
                         sal_ult_extracto = nvl(v_sal_ult_extracto, 0) + nvl(v_mto_credito, 0) - nvl(v_mto_debito, 0)
                      WHERE
                            nro_cuenta = ap.nro_cuenta
                         AND ano = TO_NUMBER(to_char(v_fec_actual, 'YYYY'))
                         AND mes = TO_NUMBER(to_char(v_fec_actual, 'MM'));
    
                   EXCEPTION
                      WHEN OTHERS THEN
                         pr_ins_log_error('Error al Actualizar el Saldo Mensual en CTA.PLAZOS. ' || ap.nro_cuenta || '. ' || sqlerrm, ap.nro_cuenta);
                   END;
                END IF;
    
                IF v_tiene_mov = 'S' THEN
                   v_lugar := 'lp_generar_programados: INSERT en GE_EXT_CUENTAS_TTG';
                   INSERT INTO GE_EXT_CUENTAS_TTG ( --@LReyes Tabla para la concurrencia
                      nro_cuenta,
                      cod_modulo,
                      cod_modalidad,
                      nro_folio,
                      fec_ult_extracto,
                      sal_ult_extracto,
                      nom_tabla,
                      cod_persona
                   ) VALUES (
                      ap.nro_cuenta,
                      ap.cod_modulo,
                      ap.cod_modalidad,
                      ap.nro_folio,
                      v_fec_actual,
                      nvl(v_sal_ult_extracto, 0) + nvl(v_mto_credito, 0) - nvl(v_mto_debito, 0),
                      'AH_CTA_PLAZOS',
                      v_cod_persona
                   );
                   IF v_cod_extracto = 1 THEN
                      -----------------------------------------------------
                      -- [MASIVO] INSERTA REGISTRO EN EL ARCHIVO DETALLE --
                      -----------------------------------------------------
                      --Guardo datos para recuperar luego, masivamente, los movimientos de la cuenta.
                      mov_masivos_list.EXTEND;
                      mov_masivos_list(mov_masivos_list.COUNT) := mov_mas_record(
                         v_cod_persona,
                         ap.nro_cuenta,
                         ap.cod_modulo,
                         ap.cod_modalidad,
                         ap.cod_oficina,
                         v_fec_movimiento
                      );
                   ELSE
                      --------------------------------------------
                      -- INSERTA REGISTRO EN EL ARCHIVO DETALLE --
                      --------------------------------------------
                      v_lugar := 'lp_generar_programados: INSERT en GE_EXT_CLI_MOVIMIENTOS';
                      INSERT INTO ge_ext_cli_movimientos (
                         cod_persona,
                         fec_extracto,
                         fec_movimiento,
                         fec_valor,
                         hor_movimiento,
                         nro_cuenta,
                         nro_documento,
                         cod_modulo,
                         cod_modalidad,
                         cod_tra_padre,
                         mto_debito,
                         mto_credito,
                         cod_extracto,
                         fre_extracto,
                         nro_secuencia,
                         cod_ofi_origen,
                         fec_insercion,
                         ind_bloqueo
                      )
                      SELECT
                         v_cod_persona,
                     	 v_fec_actual,
                         ah_movimientos_his.fecha,
                         ah_movimientos_his.fec_valor,
                         ah_movimientos_his.hora,
                         ah_movimientos_his.nro_cuenta,
                         ah_movimientos_his.nro_documento,
                         ah_movimientos_his.cod_mod_padre,
                         ah_movimientos_his.cod_mad_padre,
                         ah_movimientos_his.cod_tra_padre,
                         ( decode(fug_obt_tra_tipo(ge_transacciones.cod_transaccion, ge_transacciones.tipo, ge_transacciones.afecta),
                                  'D',
                                  nvl(ah_movimientos_his.monto, 0),
                                  0) ),
                         ( decode(fug_obt_tra_tipo(ge_transacciones.cod_transaccion, ge_transacciones.tipo, ge_transacciones.afecta),
                                  'C',
                                  nvl(ah_movimientos_his.monto, 0),
                                  0) ),
                         v_cod_extracto,
                         v_frecuencia,
                         ah_movimientos_his.nro_secuencia,
                         ah_movimientos_his.cod_ofi_origen,
                         ah_movimientos_his.fec_insercion,
                         decode(ge_transacciones.afecta, 'B', 'S', 'N')
                      FROM
                         ge_transacciones,
                         ah_movimientos_his
                      WHERE
                            ah_movimientos_his.cod_modulo = ap.cod_modulo
                         AND ah_movimientos_his.cod_modalidad = ap.cod_modalidad
                         AND ah_movimientos_his.cod_oficina = ap.cod_oficina
                         AND ah_movimientos_his.nro_cuenta = ap.nro_cuenta
                         AND ah_movimientos_his.fecha > v_fec_movimiento
                         AND ah_movimientos_his.fecha <= v_fec_actual
                         AND ( ah_movimientos_his.reversado = 'N'
                               OR ( ah_movimientos_his.reversado = 'S'
                                    AND fec_valor <= v_fec_movimiento
                                    AND EXISTS (
                            SELECT
                               1
                            FROM
                               ah_movimientos_his rev  -- CB. 25/09/2013.
                            WHERE
                                  ah_movimientos_his.fec_valor = rev.fecha
                               AND ah_movimientos_his.hor_reversion = rev.hora
                               AND ah_movimientos_his.cod_usu_reversion = rev.cod_usuario
                               AND ah_movimientos_his.nro_secuencia = rev.nro_secuencia
                                       -- DYDMR-5672 NAF 01/2017
                               AND ah_movimientos_his.nro_cuenta = rev.nro_cuenta
                               AND abs(ah_movimientos_his.monto) = abs(rev.monto)
                         ) )
                               OR ( ah_movimientos_his.reversado = 'S'
                                    AND ah_movimientos_his.cod_tra_padre IN ( 303, 302 )
                                    AND ah_movimientos_his.cod_mad_padre = 455 ) )
                         AND ah_movimientos_his.estado = 'N'
                         AND ah_movimientos_his.cod_modulo = ge_transacciones.cod_modulo
                         AND ah_movimientos_his.cod_modalidad = ge_transacciones.cod_modalidad
                         AND ah_movimientos_his.cod_transaccion = ge_transacciones.cod_transaccion
                         AND ge_transacciones.ve_cliente = 'S'
                         AND ge_transacciones.tipo IN ( 'C', 'D' )
                         AND nvl(ge_transacciones.afecta, 'XX') != 'B';
    
                   END IF;
                END IF;
    
                IF v_count_loop >= 50 THEN
                   COMMIT;
                   v_count_loop := 0;
                END IF;
            EXCEPTION
                WHEN OTHERS THEN
                    pr_ins_log_error(v_lugar || ' | ' || SQLERRM, ap.nro_cuenta);
                    UPDATE ge_ext_clientes
                    SET fre_Extracto = lower(v_frecuencia)
                    WHERE cod_persona = v_cod_persona
                    AND fec_extracto = v_fec_actual;
            END;
         END LOOP;
         
         v_fec_fin := SYSTIMESTAMP;
         v_duracion_seg := TRUNC((DBMS_UTILITY.get_time - v_inicio) / 100, 2);
         
         pr_log_perf_event(
                p_cod_programa                 => 'PERF_PR_GEN_EXTRACTO',
                p_cod_subproceso               => 'lp_generar_programados~CURSOR mae_cue',
                p_fec_inicio                   => v_fec_inicio,
                p_fec_fin                      => v_fec_fin,
                p_val_duracion_seg             => v_duracion_seg,
                p_est_resultado                => 'SUCCESS');
         
         COMMIT;

         -----------------------------------------------------
         -- [MASIVO] INSERTA REGISTRO EN EL ARCHIVO DETALLE --
         -----------------------------------------------------
         --Datos antes guardados para recuperar masivamente los movimientos de las cuentas.
         IF mov_masivos_list.COUNT > 0 THEN
            v_lugar := 'lp_generar_programados: [MASIVO] INSERT en GE_EXT_CLI_MOVIMIENTOS';
            ts_inicio := SYSTIMESTAMP;
            OPEN cur_mov_programados;
            v_initial_time := DBMS_UTILITY.get_time;
            
            v_inicio := DBMS_UTILITY.get_time;
            v_fec_inicio := SYSTIMESTAMP;
            
            LOOP
               FETCH cur_mov_programados
               BULK COLLECT INTO t_cur_mov_programados LIMIT vg_bulk_size;
               EXIT WHEN t_cur_mov_programados.COUNT() = 0;
            
                v_cant_mov := v_cant_mov + t_cur_mov_programados.COUNT();
                
               FORALL i IN t_cur_mov_programados.FIRST() .. t_cur_mov_programados.LAST()
                  INSERT INTO ge_ext_cli_movimientos (
                        cod_persona,
                        fec_extracto,
                        fec_movimiento,
                        fec_valor,
                        hor_movimiento,
                        nro_cuenta,
                        nro_documento,
                        cod_modulo,
                        cod_modalidad,
                        cod_tra_padre,
                        mto_debito,
                        mto_credito,
                        cod_extracto,
                        fre_extracto,
                        nro_secuencia,
                        cod_ofi_origen,
                        fec_insercion,
                        ind_bloqueo
                  )
                  VALUES (
                     t_cur_mov_programados(i).cod_persona,
                     t_cur_mov_programados(i).fec_actual,
                     t_cur_mov_programados(i).fecha,
                     t_cur_mov_programados(i).fec_valor,
                     t_cur_mov_programados(i).hora,
                     t_cur_mov_programados(i).nro_cuenta,
                     t_cur_mov_programados(i).nro_documento,
                     t_cur_mov_programados(i).cod_mod_padre,
                     t_cur_mov_programados(i).cod_mad_padre,
                     t_cur_mov_programados(i).cod_tra_padre,
                     t_cur_mov_programados(i).monto_D,
                     t_cur_mov_programados(i).monto_C,
                     t_cur_mov_programados(i).cod_extracto,
                     t_cur_mov_programados(i).frecuencia,
                     t_cur_mov_programados(i).nro_secuencia,
                     t_cur_mov_programados(i).cod_ofi_origen,
                     t_cur_mov_programados(i).fec_insercion,
                     t_cur_mov_programados(i).ind_bloqueo
                  );
               COMMIT;
            END LOOP;

            CLOSE cur_mov_programados;
            
            v_fec_fin := SYSTIMESTAMP;
            v_duracion_seg := TRUNC((DBMS_UTILITY.get_time - v_inicio) / 100, 2);
                  
            pr_log_perf_event(
                p_cod_programa                 => 'PERF_PR_GEN_EXTRACTO',
                p_cod_subproceso               => 'lp_generar_programados~CURSOR cur_mov_programados',
                p_fec_inicio                   => v_fec_inicio,
                p_fec_fin                      => v_fec_fin,
                p_val_duracion_seg             => v_duracion_seg,
                p_est_resultado                => 'SUCCESS');
            
            ts_fin := SYSTIMESTAMP;
            pr_ins_log_error('lp_generar_programados: [insert mov masivo] cantidad->' || v_cant_mov || ', duracion->' || substr(ts_fin-ts_inicio, -18, 11), null);
         END IF;

      END lp_generar_programados;

      PROCEDURE lp_generar_certificados
      IS
         v_val_tasa        ge_tas_fechas.val_tasa%TYPE;
         v_val_tae         ge_tas_fechas.val_tasa%TYPE;
         v_fec_vencimiento ah_cupones.fec_vencimiento%TYPE;
         v_mto_interes     ah_cupones.mto_interes%TYPE;

         ----------------------------------
         -- CURSOR DEL ARCHIVO PRINCIPAL --
         ----------------------------------
         CURSOR mae_cue IS
         SELECT
            cli.cod_persona,
            ge_cta_clientes.cod_modulo,
            ge_cta_clientes.cod_modalidad,
            ge_cta_clientes.cod_oficina,
            ge_cta_clientes.nro_cuenta,
            ah_cta_certificados.cod_moneda,
            ah_cta_certificados.tas_personalizada,
            ah_cta_certificados.cod_tasa,
            ah_cta_certificados.capital,
            ah_cta_certificados.fec_vencimiento,
            ah_cta_certificados.sal_ret_batch,
            ah_cta_certificados.sal_tot_batch,
            ah_cta_certificados.fec_apertura,
            fue_obt_titulo(ah_cta_certificados.beneficiario) denominacion,
            ah_cta_certificados.tip_capitalizacion,
            ah_cta_certificados.est_cer_batch,
            ah_cta_certificados.sal_bloqueado
         FROM
            ah_cta_certificados,
            ge_cta_clientes,
            TABLE(mae_cli_ctas_list) cli
         WHERE
               ge_cta_clientes.cod_persona = cli.cod_persona
            AND cli.cod_modulo = 3
            AND cli.cod_modalidad IN ( 33, 34, 35 )
            AND ge_cta_clientes.cod_modalidad = cli.cod_modalidad
            AND ge_cta_clientes.relacion = 'P'
            AND ah_cta_certificados.cod_modulo = ge_cta_clientes.cod_modulo
            AND ah_cta_certificados.cod_modalidad = ge_cta_clientes.cod_modalidad
            AND ah_cta_certificados.cod_oficina = ge_cta_clientes.cod_oficina
            AND ah_cta_certificados.nro_cuenta = ge_cta_clientes.nro_cuenta
            AND ah_cta_certificados.est_batch NOT IN ( 'C', 'T' )
            AND nvl(ah_cta_certificados.sal_tot_batch, 0) > 0;

         v_count_loop PLS_INTEGER := 0;
      BEGIN
         v_lugar := 'lp_generar_certificados';

         v_cod_persona := -1;
         v_initial_time := DBMS_UTILITY.get_time;
         
         v_inicio := DBMS_UTILITY.get_time;
         v_fec_inicio := SYSTIMESTAMP;
         
         FOR cd IN mae_cue LOOP
            BEGIN
                v_count_loop := v_count_loop + 1;
    
                IF v_cod_persona != cd.cod_persona THEN
                   --Inicializo la variable que separa los extractos especificos
                   v_cod_persona := cd.cod_persona;
                END IF;
    
                --limpio variables
                v_mto_interes := NULL;
                v_fec_vencimiento := NULL;
                   --- cargo los valores para el calculo de la tasa --
                v_val_tasa := fug_obt_val_tasa(cd.cod_modulo, cd.cod_modalidad, cd.cod_oficina, cd.nro_cuenta, cd.cod_moneda,
                                               cd.capital, cd.tas_personalizada, cd.cod_tasa, NULL, v_fec_actual);
                --obtiene tae
                v_val_tae := pas_bcp.fu_obt_tae_cda(cd.tip_capitalizacion, v_val_tasa, cd.fec_vencimiento - cd.fec_apertura, cd.capital);
    
                v_mto_bloqueo := lf_obt_mto_bloqueado(cd.nro_cuenta);
    
                ----------------------------------------------------
                -- INSERTA REGISTRO EN EL ARCHIVO CABECERA ACTIVO --
                ----------------------------------------------------
                v_lugar := 'lp_generar_certificados: INSERT en GE_EXT_CLI_CUENTAS: ' || '-' || cd.nro_cuenta;
                INSERT INTO ge_ext_cli_cuentas (
                   ge_ext_cli_cuentas.cod_persona,
                   ge_ext_cli_cuentas.fec_extracto,
                   ge_ext_cli_cuentas.tip_cuenta,
                   ge_ext_cli_cuentas.cod_oficina,
                   ge_ext_cli_cuentas.cod_modalidad,
                   ge_ext_cli_cuentas.nro_cuenta,
                   ge_ext_cli_cuentas.cod_moneda,
                   ge_ext_cli_cuentas.sal_actual,
                   ge_ext_cli_cuentas.sal_a_confirmar,
                   ge_ext_cli_cuentas.cod_extracto,
                   ge_ext_cli_cuentas.fre_extracto,
                   tas_nominal,
                   tas_efectiva,
                   ge_ext_cli_cuentas.sal_bloqueado
                ) VALUES (
                   v_cod_persona,
               	   v_fec_actual,
                   'A',
                   cd.cod_oficina,
                   cd.cod_modalidad,
                   cd.nro_cuenta,
                   cd.cod_moneda,
                   cd.sal_tot_batch,
                   cd.sal_ret_batch,
                   1,
                   v_frecuencia,
                   v_val_tasa,
                   v_val_tae,
                   v_mto_bloqueo
                );
    
                -------------------------------------------------------
                -- CALCULA interes del sgte cupon --
                -------------------------------------------------------
                BEGIN
                   SELECT
                      a.fec_vencimiento,
                      nvl(a.mto_interes, 0)
                   INTO
                      v_fec_vencimiento,
                      v_mto_interes
                   FROM
                      ah_cupones a
                   WHERE
                         a.nro_cuenta = cd.nro_cuenta
                      AND a.nro_cupon = (
                         SELECT
                            MIN(nro_cupon)
                         FROM
                            ah_cupones b
                         WHERE
                               b.nro_cuenta = a.nro_cuenta
                            AND b.nro_cupon > 0
                            AND b.estado NOT IN ( 'P' )
                      )
                      AND a.estado NOT IN ( 'P' );
    
                EXCEPTION
                   WHEN no_data_found THEN
                      NULL;
                END;
    
                ------------------------------------------------------------------
                -- INSERTA REGISTRO EN EL ARCHIVO RESUMEN DE AHORRO CERTIFICADO --
                ------------------------------------------------------------------
                v_lugar := 'lp_generar_certificados: INSERT en GE_EXT_RESUMENES';
                INSERT INTO ge_ext_resumenes (
                   ge_ext_resumenes.cod_persona,
                   ge_ext_resumenes.fec_extracto,
                   ge_ext_resumenes.tipo,
                   ge_ext_resumenes.nro_cuenta,
                   ge_ext_resumenes.mto_capital,
                   ge_ext_resumenes.mto_interes,
                   ge_ext_resumenes.fec_vencimiento,
                   ge_ext_resumenes.cod_extracto,
                   ge_ext_resumenes.fre_extracto,
                   ge_ext_resumenes.fec_inicio,
                   ge_ext_resumenes.beneficiario,
                   cod_modalidad,
                   cod_moneda
                ) VALUES (
                   v_cod_persona,
               	   v_fec_actual,
                   decode(cd.cod_modalidad, 33, '2', '6'),
                   cd.nro_cuenta,
                   decode(cd.est_cer_batch, 'P', 0, cd.capital),
                   v_mto_interes,
                   v_fec_vencimiento,
                   1,
                   v_frecuencia,
                   cd.fec_apertura,
                   cd.denominacion,
                   cd.cod_modalidad,
                   cd.cod_moneda
                );
    
                IF v_count_loop >= 50 THEN
                   COMMIT;
                   v_count_loop := 0;
                END IF;
            EXCEPTION
                WHEN OTHERS THEN
                    pr_ins_log_error(v_lugar || ' | ' || SQLERRM, cd.nro_cuenta);
                    UPDATE ge_ext_clientes
                    SET fre_Extracto = lower(v_frecuencia)
                    WHERE cod_persona = v_cod_persona
                    AND fec_extracto = v_fec_actual;
            END;
         END LOOP;
                  
         v_fec_fin := SYSTIMESTAMP;
         v_duracion_seg := TRUNC((DBMS_UTILITY.get_time - v_inicio) / 100, 2);
                  
         pr_log_perf_event(
                p_cod_programa                 => 'PERF_PR_GEN_EXTRACTO',
                p_cod_subproceso               => 'lp_generar_certificados~CURSOR mae_cue',
                p_fec_inicio                   => v_fec_inicio,
                p_fec_fin                      => v_fec_fin,
                p_val_duracion_seg             => v_duracion_seg,
                p_est_resultado                => 'SUCCESS');
         
         COMMIT;

      END lp_generar_certificados;

      PROCEDURE lp_generar_prestamos
      IS
         v_fec_vencimiento DATE;
         v_sal_capital     NUMBER(16, 2);

         ----------------------------------
         -- CURSOR DEL ARCHIVO PRINCIPAL --
         ----------------------------------
         CURSOR mae_cue IS
         SELECT
            cli.cod_persona,
            ge_cta_clientes.cod_modulo,
            ge_cta_clientes.cod_modalidad,
            ge_cta_clientes.cod_oficina,
            ge_cta_clientes.nro_cuenta,
            pr_cta_prestamos.mto_capital                                                                             tot_prestamo,
            pr_cta_prestamos.cod_moneda,
            nvl(pr_cta_prestamos.sal_capital, 0) + nvl(pr_cta_prestamos.sal_int_adelantado, 0) + nvl(sal_interes, 0) saldo_capital
         FROM
            pr_cta_prestamos,
            ge_cta_clientes,
            TABLE(mae_cli_ctas_list) cli
         WHERE
               ge_cta_clientes.cod_persona = cli.cod_persona
            AND cli.cod_modulo = 6
            AND ge_cta_clientes.relacion = 'P'
            AND pr_cta_prestamos.cod_modulo = ge_cta_clientes.cod_modulo
            AND pr_cta_prestamos.cod_modalidad = ge_cta_clientes.cod_modalidad
            AND pr_cta_prestamos.cod_oficina = ge_cta_clientes.cod_oficina
            AND pr_cta_prestamos.nro_cuenta = ge_cta_clientes.nro_cuenta
            AND pr_cta_prestamos.estado <> 'N'
            AND pr_cta_prestamos.cod_modalidad <> 699

         ORDER BY
            cli.cod_persona;

         v_insertar        VARCHAR2(01);
         v_val_tasa        ge_tas_fechas.val_tasa%TYPE;
         v_val_tae         ge_tas_fechas.val_tasa%TYPE;

         v_count_loop PLS_INTEGER := 0;
      BEGIN
         v_lugar := 'lp_generar_prestamos';

         v_cod_persona := -1;
         v_initial_time := DBMS_UTILITY.get_time;
         
         v_inicio := DBMS_UTILITY.get_time;
         v_fec_inicio := SYSTIMESTAMP;
         
         FOR pr IN mae_cue LOOP
            BEGIN
                v_count_loop := v_count_loop + 1;
    
                IF v_cod_persona != pr.cod_persona THEN
                   -- Inicializo la variable que separa los extractos especificos
                   v_cod_persona := pr.cod_persona;
                END IF;
    
                --limpio variables
                v_val_tasa := NULL;
                v_val_tae := NULL;
    
                -------------------------------------------------------
                -- CALCULA IMPORTE Y VENCIMIENTO DE LA CUOTA A PAGAR --
                -------------------------------------------------------
                v_insertar := 'S';
                BEGIN
                   SELECT
                      a.fec_vencimiento,
                      nvl(a.sal_capital, 0) + nvl(a.sal_int_documentado, 0) + nvl(a.sal_interes, 0)
                   INTO
                      v_fec_vencimiento,
                      v_sal_capital
                   FROM
                      pr_cuotas a
                   WHERE
                         a.nro_cuenta = pr.nro_cuenta
                      AND a.nro_cuota = (
                         SELECT
                            MIN(nro_cuota)
                         FROM
                            pr_cuotas b
                         WHERE
                               b.nro_cuenta = a.nro_cuenta
                            AND b.nro_cuota > 0
                            AND b.estado NOT IN ( 'N' )
                      )
                      AND a.estado NOT IN ( 'N' );
    
                EXCEPTION
                   WHEN no_data_found THEN
                      v_insertar := 'N';
                END;
    
                IF v_insertar = 'S' THEN
    
                   --obtener tasas
                   BEGIN
                      pas_bcp.pr_obt_tas_prestamo(NULL, pr.nro_cuenta, v_val_tae, v_val_tasa);
                   EXCEPTION
                      WHEN OTHERS THEN
                         pr_ins_log_error('Error al obtener tasa del prestamo. ' || pr.nro_cuenta || '. ' || sqlerrm, pr.nro_cuenta);
                   END;
    
                   ----------------------------------------------------
                   -- INSERTA REGISTRO EN EL ARCHIVO CABECERA PASIVO --
                   ----------------------------------------------------
                   v_lugar := 'lp_generar_prestamos: INSERT en GE_EXT_CLI_CUENTAS: ' || '-' || pr.nro_cuenta;
                   INSERT INTO ge_ext_cli_cuentas (
                      ge_ext_cli_cuentas.cod_persona,
                      ge_ext_cli_cuentas.fec_extracto,
                      ge_ext_cli_cuentas.tip_cuenta,
                      ge_ext_cli_cuentas.cod_oficina,
                      ge_ext_cli_cuentas.cod_modalidad,
                      ge_ext_cli_cuentas.nro_cuenta,
                      ge_ext_cli_cuentas.cod_moneda,
                      ge_ext_cli_cuentas.sal_actual,
                      ge_ext_cli_cuentas.cod_extracto,
                      ge_ext_cli_cuentas.fre_extracto,
                      tas_nominal,
                      tas_efectiva,
                      ge_ext_cli_cuentas.sal_bloqueado
                   ) VALUES (
                      v_cod_persona,
                  v_fec_actual,
                      'P',
                      pr.cod_oficina,
                      pr.cod_modalidad,
                      pr.nro_cuenta,
                      pr.cod_moneda,
                      pr.saldo_capital,
                      1,
                      v_frecuencia,
                      v_val_tasa,
                      v_val_tae,
                      0
                   );
    
                   ---------------------------------------------------------
                   -- INSERTA REGISTRO EN EL ARCHIVO RESUMEN DE PRESTAMOS --
                   ---------------------------------------------------------
                   v_lugar := 'lp_generar_prestamos: INSERT en GE_EXT_RESUMENES';
                   INSERT INTO ge_ext_resumenes (
                      ge_ext_resumenes.cod_persona,
                      ge_ext_resumenes.fec_extracto,
                      ge_ext_resumenes.tipo,
                      ge_ext_resumenes.nro_cuenta,
                      ge_ext_resumenes.mto_capital,
                      ge_ext_resumenes.mto_interes,
                      ge_ext_resumenes.fec_vencimiento,
                      ge_ext_resumenes.cod_extracto,
                      ge_ext_resumenes.fre_extracto,
                      ge_ext_resumenes.sal_disponible,
                      cod_modalidad,
                      cod_moneda
                   ) VALUES (
                      v_cod_persona,
                  v_fec_actual,
                      '3',
                      pr.nro_cuenta,
                      pr.tot_prestamo,
                      v_sal_capital,
                      v_fec_vencimiento,
                      1,
                      v_frecuencia,
                      pr.saldo_capital,
                      pr.cod_modalidad,
                      pr.cod_moneda
                   );
                END IF;
    
                IF v_count_loop >= 50 THEN
                   COMMIT;
                   v_count_loop := 0;
                END IF;
            EXCEPTION
                WHEN OTHERS THEN
                    pr_ins_log_error(v_lugar || ' | ' || SQLERRM, pr.nro_cuenta);
                    UPDATE ge_ext_clientes
                    SET fre_Extracto = lower(v_frecuencia)
                    WHERE cod_persona = v_cod_persona
                    AND fec_extracto = v_fec_actual;
            END;
         END LOOP;
                  
         v_fec_fin := SYSTIMESTAMP;
         v_duracion_seg := TRUNC((DBMS_UTILITY.get_time - v_inicio) / 100, 2);
                  
         pr_log_perf_event(
                p_cod_programa                 => 'PERF_PR_GEN_EXTRACTO',
                p_cod_subproceso               => 'lp_generar_prestamos~CURSOR mae_cue',
                p_fec_inicio                   => v_fec_inicio,
                p_fec_fin                      => v_fec_fin,
                p_val_duracion_seg             => v_duracion_seg,
                p_est_resultado                => 'SUCCESS');
         
         COMMIT;

      END lp_generar_prestamos;

      PROCEDURE lp_generar_tarjetas
      IS
         v_val_tasa ge_tas_fechas.val_tasa%TYPE;
         v_val_tae  ge_tas_fechas.val_tasa%TYPE;

         CURSOR mae_cue IS
         SELECT
            ge_cta_clientes.cod_modulo,
            ge_cta_clientes.cod_modalidad,
            ge_cta_clientes.cod_oficina,
            cod_moneda,
            nvl(ta_tarjetas.nro_tarjeta, ta_tarjetas.nro_cuenta)                                                                                      nro_tarjeta
            ,
            nvl(ta_cta_tarjetas.sal_ult_extracto, 0)                                                                                                  sal_ult_extracto
            ,
            nvl(ta_cta_tarjetas.mto_pag_minimo, 0)                                                                                                    mto_pag_minimo
            ,
            nvl(ta_cta_tarjetas.lin_credito, 0) - ( nvl(ta_cta_tarjetas.sal_facturar, 0) + nvl(ta_cta_tarjetas.sal_facturado, 0) + nvl(ta_cta_tarjetas.sal_financiado
            , 0) + nvl(ta_cta_tarjetas.sal_cuo_pendientes, 0) ) sal_disponible,
            nvl(ta_cta_tarjetas.sal_facturar, 0) + nvl(ta_cta_tarjetas.sal_facturado, 0) + nvl(ta_cta_tarjetas.sal_financiado, 0) + nvl(
            ta_cta_tarjetas.sal_cuo_pendientes, 0) saldo,
            ta_cta_tarjetas.fec_vct_ult_cierre,
            ta_cta_tarjetas.nro_cuenta
         FROM
            ta_cta_tarjetas,
            ta_tarjetas,
            ge_cta_clientes
         WHERE
               ge_cta_clientes.cod_persona = v_cod_persona
            AND ge_cta_clientes.relacion = 'P'
            AND ta_tarjetas.nro_cuenta = ge_cta_clientes.nro_cuenta
            AND ta_tarjetas.cod_persona = ge_cta_clientes.cod_persona
            AND ta_tarjetas.vigente = 'S'
            AND ta_cta_tarjetas.nro_cuenta = ge_cta_clientes.nro_cuenta
            AND ta_tarjetas.cod_estado NOT IN ( '10' )
            AND ta_cta_tarjetas.estado <> 'C';

      BEGIN
            v_lugar := 'lp_generar_tarjetas';
         FOR ta IN mae_cue LOOP
            --limpio variables
            v_val_tasa := NULL;
            v_val_tae := NULL;

            ----------------------------------------------------
            -- INSERTA REGISTRO EN EL ARCHIVO CABECERA PASIVO --
            ----------------------------------------------------
            v_lugar := 'lp_generar_tarjetas: INSERT en GE_EXT_CLI_CUENTAS: ' || ta.nro_tarjeta;
            INSERT INTO ge_ext_cli_cuentas (
               ge_ext_cli_cuentas.cod_persona,
               ge_ext_cli_cuentas.fec_extracto,
               ge_ext_cli_cuentas.tip_cuenta,
               ge_ext_cli_cuentas.cod_oficina,
               ge_ext_cli_cuentas.cod_modalidad,
               ge_ext_cli_cuentas.nro_cuenta,
               ge_ext_cli_cuentas.cod_moneda,
               ge_ext_cli_cuentas.sal_actual,
               ge_ext_cli_cuentas.cod_extracto,
               ge_ext_cli_cuentas.fre_extracto,
               tas_nominal,
               tas_efectiva
            ) VALUES (
               v_cod_persona,
               v_fec_actual,
               'P',
               ta.cod_oficina,
               ta.cod_modalidad,
               ta.nro_tarjeta,
               ta.cod_moneda,
               ta.sal_ult_extracto,
               1,
               v_frecuencia,
               v_val_tasa,
               v_val_tae
            );

            ---------------------------------------------------------
            -- INSERTA REGISTRO EN EL ARCHIVO RESUMEN DE TARJETAS --
            ---------------------------------------------------------
            v_lugar := 'lp_generar_tarjetas: INSERT en GE_EXT_RESUMENES';
            INSERT INTO ge_ext_resumenes (
               ge_ext_resumenes.cod_persona,
               ge_ext_resumenes.fec_extracto,
               ge_ext_resumenes.tipo,
               ge_ext_resumenes.nro_cuenta,
               ge_ext_resumenes.mto_capital,
               ge_ext_resumenes.mto_interes,
               ge_ext_resumenes.fec_vencimiento,
               ge_ext_resumenes.cod_extracto,
               ge_ext_resumenes.fre_extracto,
               ge_ext_resumenes.sal_disponible,
               cod_modalidad,
               cod_moneda
            ) VALUES (
               v_cod_persona,
               v_fec_actual,
               '4',
               ta.nro_tarjeta,
               ta.mto_pag_minimo,
               ta.sal_disponible,
               ta.fec_vct_ult_cierre,
               1,
               v_frecuencia,
               ta.saldo,
               ta.cod_modalidad,
               ta.cod_moneda
            );
         END LOOP;
      END lp_generar_tarjetas;

      PROCEDURE lp_act_nro_control
      IS
         v_oficial  ba_usuarios.cod_usuario%TYPE;
         v_cantidad NUMBER(10) := 0;

         CURSOR c1 IS
         SELECT
            ge_ext_clientes.cod_usu_oficial  oficial,
            ge_ext_clientes.ROWID            registro
         FROM
            ge_ext_clientes,
            TABLE(p_cod_persona_list) cli
         WHERE
               ge_ext_clientes.fec_extracto = v_fec_actual
            AND ge_ext_clientes.fre_extracto = v_frecuencia
            AND ge_ext_clientes.cod_persona = cli.COLUMN_VALUE
            AND ge_ext_clientes.tip_impresion IN ( 'C', 'S', 'X' )
         ORDER BY
            ge_ext_clientes.cod_usu_oficial,
            ge_ext_clientes.cod_pais,
            ge_ext_clientes.cod_ciudad,
            upper(ge_ext_clientes.barrio),
            ltrim(upper(ge_ext_clientes.direccion));

         r1 c1%rowtype;
      BEGIN
         v_lugar := 'lp_act_nro_control';

         IF c1%isopen THEN
            CLOSE c1;
         END IF;
         OPEN c1;
         LOOP
            FETCH c1 INTO r1;
            EXIT WHEN c1%notfound;
            IF r1.oficial != v_oficial OR v_oficial IS NULL THEN
               v_cantidad := 0;
               v_oficial := r1.oficial;
            END IF;

            v_cantidad := v_cantidad + 1;
            UPDATE ge_ext_clientes
            SET
               nro_control = v_cantidad
            WHERE
               ROWID = r1.registro;

         END LOOP;

      END lp_act_nro_control;

      PROCEDURE lp_mar_ext_con_diferencia
      IS
      BEGIN
         v_lugar := 'lp_mar_ext_con_diferencia';
          --- actualiza con lower (minuscula las cuentas que tuvieron dif. ---
          --- para que no imprima con los demas extractos --------------------

         FORALL i IN p_cod_persona_list.FIRST() .. p_cod_persona_list.LAST()
            UPDATE ge_ext_clientes
            SET
               ge_ext_clientes.fre_extracto = lower(ge_ext_clientes.fre_extracto)
            WHERE
                  ge_ext_clientes.fec_extracto = v_fec_actual
               AND ge_ext_clientes.fre_extracto = v_frecuencia
               AND ge_ext_clientes.cod_persona = p_cod_persona_list(i)
               AND EXISTS (
                  SELECT
                     0
                  FROM
                     ge_ext_cli_cuentas,
                     ah_cta_vistas
                  WHERE
                        ge_ext_cli_cuentas.cod_persona = ge_ext_clientes.cod_persona
                     AND ge_ext_cli_cuentas.cod_extracto = ge_ext_clientes.cod_extracto
                     AND ge_ext_cli_cuentas.fec_extracto = ge_ext_clientes.fec_extracto
                     AND ge_ext_cli_cuentas.fre_extracto = ge_ext_clientes.fre_extracto
                     AND ah_cta_vistas.cod_modulo = 3
                     AND ah_cta_vistas.cod_modalidad = ge_ext_cli_cuentas.cod_modalidad
                     AND ah_cta_vistas.cod_oficina = ge_ext_cli_cuentas.cod_oficina
                     AND ah_cta_vistas.nro_cuenta = ge_ext_cli_cuentas.nro_cuenta
                     AND ah_cta_vistas.fec_ult_extracto = v_fec_actual
                     AND ( nvl(ah_cta_vistas.sal_ult_extracto, 0) <> nvl(ah_cta_vistas.sal_total, 0) - nvl(ah_cta_vistas.sal_retenido, 0)
                           OR nvl(ah_cta_vistas.sal_ult_extracto, 0) <> nvl(ah_cta_vistas.sal_tot_batch, 0) - nvl(ah_cta_vistas.sal_ret_batch
                           , 0) )
               );
      EXCEPTION
         WHEN OTHERS THEN
            raise_application_error(-20003, 'Error al marcar diferencias ' || sqlerrm);
      END lp_mar_ext_con_diferencia;

      PROCEDURE lp_mar_ext_con_dif_detalle
      IS
         CURSOR diferen IS
         SELECT
            ge_ext_cli_cuentas.cod_persona,
            ge_ext_cli_cuentas.cod_extracto
         FROM
            ge_transacciones,
            ge_ext_cli_movimientos,
            ge_ext_cli_cuentas,
            TABLE(p_cod_persona_list) cli
         WHERE
               ge_transacciones.cod_modulo = ge_ext_cli_movimientos.cod_modulo
            AND ge_transacciones.cod_modalidad = ge_ext_cli_movimientos.cod_modalidad
            AND ge_transacciones.cod_transaccion = ge_ext_cli_movimientos.cod_tra_padre
            AND ge_ext_cli_movimientos.cod_persona = ge_ext_cli_cuentas.cod_persona
            AND ge_ext_cli_movimientos.cod_extracto = ge_ext_cli_cuentas.cod_extracto
            AND ge_ext_cli_movimientos.fec_extracto = ge_ext_cli_cuentas.fec_extracto
            AND ge_ext_cli_movimientos.nro_cuenta = ge_ext_cli_cuentas.nro_cuenta
            AND ge_ext_cli_cuentas.fec_extracto = v_fec_actual
            AND ge_ext_cli_cuentas.fre_extracto = v_frecuencia
            AND ge_ext_cli_cuentas.tip_cuenta = 'A'
            AND ge_ext_cli_cuentas.cod_persona = cli.COLUMN_VALUE
              --WA:08/08/2014 Se agrega 49 para financiera Pais
            AND ge_ext_cli_cuentas.cod_modalidad IN ( 31, 41, 42, 48, 49,
                                                      334 )
            AND nvl(ge_ext_cli_movimientos.ind_bloqueo, 'N') = 'N'
              --WA:08/08/2014 Se agrega 49 para financiera Pais
         GROUP BY
            ge_ext_cli_cuentas.cod_persona,
            ge_ext_cli_cuentas.cod_extracto,
            ge_ext_cli_cuentas.fec_extracto,
            ge_ext_cli_cuentas.nro_cuenta,
            ge_ext_cli_cuentas.cod_modalidad,
            ge_ext_cli_cuentas.sal_anterior,
            ge_ext_cli_cuentas.sal_actual
         HAVING
            decode(ge_ext_cli_cuentas.cod_modalidad, 42, ge_ext_cli_cuentas.sal_anterior * - 1, 48, ge_ext_cli_cuentas.sal_anterior * - 1
            ,
                   49, ge_ext_cli_cuentas.sal_anterior * - 1, ge_ext_cli_cuentas.sal_anterior) + ( SUM(ge_ext_cli_movimientos.mto_credito
                   ) - SUM(ge_ext_cli_movimientos.mto_debito) ) != decode(ge_ext_cli_cuentas.cod_modalidad, 42, ge_ext_cli_cuentas.sal_actual * - 1
                   , 48, ge_ext_cli_cuentas.sal_actual * - 1,
                                                                                                                                         49
                                                                                                                                         ,
                                                                                                                                         ge_ext_cli_cuentas.sal_actual * - 1
                                                                                                                                         ,
                                                                                                                                         ge_ext_cli_cuentas.sal_actual
                                                                                                                                         )
                                                                                                                                         ;

      BEGIN
         v_lugar := 'lp_mar_ext_con_dif_detalle';
         FOR ca IN diferen LOOP
            UPDATE ge_ext_clientes
            SET
               ge_ext_clientes.fre_extracto = lower(ge_ext_clientes.fre_extracto)
            WHERE
                  ge_ext_clientes.cod_persona = ca.cod_persona
               AND ge_ext_clientes.cod_extracto = ca.cod_extracto
               AND ge_ext_clientes.fec_extracto = v_fec_actual
               AND ge_ext_clientes.fre_extracto = v_frecuencia;

         END LOOP;

      EXCEPTION
         WHEN OTHERS THEN
            raise_application_error(-20004, 'Error al marcar dif. detalle ' || sqlerrm);
      END lp_mar_ext_con_dif_detalle;

      PROCEDURE lp_act_folio_ahorros
      IS
         CURSOR cabecera IS
         SELECT
            ge_ext_cli_cuentas.cod_modalidad,
            ge_ext_cli_cuentas.cod_oficina,
            ge_ext_cli_cuentas.nro_cuenta,
            ge_ext_cli_cuentas.cod_persona,
            ge_ext_cli_cuentas.cod_extracto,
            ge_ext_cli_cuentas.nro_folio,
            ge_ext_cli_cuentas.sal_actual
         FROM
            ge_ext_cli_cuentas,
            TABLE(p_cod_persona_list) cli
         WHERE
               ge_ext_cli_cuentas.fec_extracto = v_fec_actual
            AND ge_ext_cli_cuentas.fre_extracto = v_frecuencia
            AND ge_ext_cli_cuentas.tip_cuenta = 'A'
            AND ge_ext_cli_cuentas.cod_persona = cli.COLUMN_VALUE
            AND ge_ext_cli_cuentas.cod_modalidad IN ( 31, 334 );

      BEGIN
         v_lugar := 'lp_act_folio_ahorros';
         FOR ca IN cabecera LOOP
           -- actualizo los datos de la cuenta ---------------------------
            UPDATE ah_movimientos_his
            SET
               nro_folio = nvl(ca.nro_folio, 0)
            WHERE
                  ah_movimientos_his.cod_modulo = 3
               AND ah_movimientos_his.cod_modalidad = ca.cod_modalidad
               AND ah_movimientos_his.cod_oficina = ca.cod_oficina
               AND ah_movimientos_his.nro_cuenta = ca.nro_cuenta
               AND ah_movimientos_his.fecha >= v_pri_dia_mes_habil
               AND ah_movimientos_his.fecha <= v_fec_actual
               AND ( ah_movimientos_his.reversado = 'N'
                     OR ( ah_movimientos_his.reversado = 'S'
                          AND fec_valor < v_pri_dia_mes_habil
                          AND EXISTS (
                  SELECT
                     1
                  FROM
                     ah_movimientos_his rev  -- CB. 25/09/2013.
                  WHERE
                        ah_movimientos_his.fec_valor = rev.fecha
                     AND ah_movimientos_his.hor_reversion = rev.hora
                     AND ah_movimientos_his.cod_usu_reversion = rev.cod_usuario
                     AND ah_movimientos_his.nro_secuencia = rev.nro_secuencia
                            -- DYDMR-5672 NAF 01/2017
                     AND ah_movimientos_his.nro_cuenta = rev.nro_cuenta
                     AND abs(ah_movimientos_his.monto) = abs(rev.monto)
               ) )
                     OR ( ah_movimientos_his.reversado = 'S'
                          AND ah_movimientos_his.cod_tra_padre IN ( 303, 302 )
                          AND ah_movimientos_his.cod_mad_padre = 455 ) )
               AND ah_movimientos_his.estado = 'N'
               AND ah_movimientos_his.nro_folio IS NULL;

         END LOOP;

      END lp_act_folio_ahorros;
      ---
      PROCEDURE lp_act_folio_ctactes
      IS
         CURSOR cabecera IS
         SELECT
            ge_ext_cli_cuentas.cod_modalidad,
            ge_ext_cli_cuentas.cod_oficina,
            ge_ext_cli_cuentas.nro_cuenta,
            ge_ext_cli_cuentas.cod_persona,
            ge_ext_cli_cuentas.cod_extracto,
            ge_ext_cli_cuentas.nro_folio,
            ge_ext_cli_cuentas.sal_actual
         FROM
            ge_ext_cli_cuentas,
            TABLE(p_cod_persona_list) cli
         WHERE
               ge_ext_cli_cuentas.fec_extracto = v_fec_actual
            AND ge_ext_cli_cuentas.fre_extracto = v_frecuencia
            AND ge_ext_cli_cuentas.tip_cuenta IN ( 'A', 'P' ) --para q tome sobregiradas
            AND ge_ext_cli_cuentas.cod_persona = cli.COLUMN_VALUE
            AND ge_ext_cli_cuentas.cod_modalidad BETWEEN 41 AND 49;

      BEGIN
         v_lugar := 'lp_act_folio_ctactes';
         FOR ca IN cabecera LOOP
           -- actualizo los datos de la cuenta ---------------------------
            UPDATE cc_movimientos_his
            SET
               nro_folio = nvl(ca.nro_folio, 0)
            WHERE
                  cc_movimientos_his.cod_modulo = 4
               AND cc_movimientos_his.cod_modalidad = ca.cod_modalidad
               AND cc_movimientos_his.cod_oficina = ca.cod_oficina
               AND cc_movimientos_his.nro_cuenta = ca.nro_cuenta
               AND cc_movimientos_his.fecha >= v_pri_dia_mes_habil
               AND cc_movimientos_his.fecha <= v_fec_actual
               AND ( cc_movimientos_his.reversado = 'N'
                     OR ( cc_movimientos_his.reversado = 'S'
                          AND cc_movimientos_his.fec_valor < v_pri_dia_mes_habil
                          AND EXISTS (
                  SELECT
                     1
                  FROM
                     cc_movimientos_his rev  -- CB. 25/09/2013.
                  WHERE
                        cc_movimientos_his.fec_valor = rev.fecha
                     AND cc_movimientos_his.hor_reversion = rev.hora
                     AND cc_movimientos_his.cod_usu_reversion = rev.cod_usuario
                     AND cc_movimientos_his.nro_secuencia = rev.nro_secuencia
                            -- DYDMR-5672 NAF 01/2017
                     AND cc_movimientos_his.nro_cuenta = rev.nro_cuenta
                     AND abs(cc_movimientos_his.monto) = abs(rev.monto)
               ) )
                     OR ( cc_movimientos_his.reversado = 'S'
                          AND cc_movimientos_his.cod_tra_padre IN ( 303, 302 )
                          AND cc_movimientos_his.cod_mad_padre = 455 ) )
               AND cc_movimientos_his.estado = 'N'
               AND cc_movimientos_his.nro_folio IS NULL;

         END LOOP;

      END lp_act_folio_ctactes;
      ---
      PROCEDURE lp_gen_extracto
      IS
         v_ctacte       PLS_INTEGER;
         v_ctaban       PLS_INTEGER;
         v_vistas       PLS_INTEGER;
         v_certificados PLS_INTEGER;
         v_prestamos    PLS_INTEGER;
         v_programados  PLS_INTEGER;
         ts_inicio      TIMESTAMP;
         ts_fin         TIMESTAMP;
         v_log          VARCHAR(4000);
      BEGIN
         v_lugar := 'lp_gen_extracto';

         --@LReyes --ahora se recupera en memoria
         OPEN cur_principal;
         FETCH cur_principal BULK COLLECT INTO mae_cli_ctas_list;
         CLOSE cur_principal;

         IF mae_cli_ctas_list.COUNT = 0 THEN
            raise_application_error(-20001, 'No hay Clientes aptos para la Generación de Extractos');
            RETURN;
         END IF;

         ge_ext_cli_cuentas_collection.DELETE;

         SELECT CASE WHEN EXISTS ( SELECT 1 
                                   FROM TABLE(mae_cli_ctas_list) 
                                   WHERE cod_modulo = 4 
                                     AND cod_modalidad = 41              ) THEN 1 ELSE 0 END,
                CASE WHEN EXISTS ( SELECT 1 
                                   FROM TABLE(mae_cli_ctas_list) 
                                   WHERE cod_modulo = 4 
                                     AND cod_modalidad != 41             ) THEN 1 ELSE 0 END,
                CASE WHEN EXISTS ( SELECT 1 
                                   FROM TABLE(mae_cli_ctas_list) 
                                   WHERE cod_modulo = 3 
                                     AND cod_modalidad IN ( 31, 334 )    ) THEN 1 ELSE 0 END,
                CASE WHEN EXISTS ( SELECT 1 
                                   FROM TABLE(mae_cli_ctas_list) 
                                   WHERE cod_modulo = 3 
                                     AND cod_modalidad = 38              ) THEN 1 ELSE 0 END,
                CASE WHEN EXISTS ( SELECT 1
                                   FROM TABLE(mae_cli_ctas_list)
                                   WHERE cod_modulo = 3
                                     AND cod_modalidad IN ( 33, 34, 35 ) ) THEN 1 ELSE 0 END,
                CASE WHEN EXISTS ( SELECT 1 
                                   FROM TABLE(mae_cli_ctas_list) 
                                   WHERE cod_modulo = 6                  ) THEN 1 ELSE 0 END
         INTO v_ctacte,
              v_ctaban,
              v_vistas,
              v_programados,
              v_certificados,
              v_prestamos
         FROM DUAL;

         --cod_modulo = 4 AND cod_modalidad = 41
         IF v_ctacte = 1 THEN
            v_initial_time := DBMS_UTILITY.get_time;
            ts_inicio := SYSTIMESTAMP;
            lp_generar_ctacte;
            v_duracion_seg := TRUNC((DBMS_UTILITY.get_time - v_initial_time) / 100, 2);
            ts_fin := SYSTIMESTAMP;
            v_log := 'lp_generar_ctate:  duracion->' || substr(ts_fin-ts_inicio, -18, 11);
            
            pr_log_perf_event(
                p_cod_programa                 => 'PERF_PR_GEN_EXTRACTO',
                p_cod_subproceso               => 'PR_GEN_EXTRACTO~lp_generar_ctacte',
                p_fec_inicio                   => ts_inicio,
                p_fec_fin                      => ts_fin,
                p_val_duracion_seg             => v_duracion_seg,
                p_est_resultado                => 'SUCCESS');
                
         END IF;

        --cod_modulo = 4 AND cod_modalidad != 41
         IF v_ctaban = 1 THEN
            v_initial_time := DBMS_UTILITY.get_time;
            ts_inicio := SYSTIMESTAMP;
            lp_generar_ctaban;
            v_duracion_seg := TRUNC((DBMS_UTILITY.get_time - v_initial_time) / 100, 2);
            ts_fin := SYSTIMESTAMP;
            v_log := v_log || chr(10) || 'lp_generar_ctaban:  duracion->' || substr(ts_fin-ts_inicio, -18, 11);
            
            pr_log_perf_event(
                p_cod_programa                 => 'PERF_PR_GEN_EXTRACTO',
                p_cod_subproceso               => 'PR_GEN_EXTRACTO~lp_generar_ctaban',
                p_fec_inicio                   => ts_inicio,
                p_fec_fin                      => ts_fin,
                p_val_duracion_seg             => v_duracion_seg,
                p_est_resultado                => 'SUCCESS');
            
         END IF;

         --cod_modulo = 3 AND cod_modalidad IN ( 31, 334 )
         IF v_vistas = 1 THEN
            v_initial_time := DBMS_UTILITY.get_time;
            ts_inicio := SYSTIMESTAMP;
            lp_generar_vistas;
            v_duracion_seg := TRUNC((DBMS_UTILITY.get_time - v_initial_time) / 100, 2);
            ts_fin := SYSTIMESTAMP;
            v_log := v_log || chr(10) || 'lp_generar_vistas:  duracion->' || substr(ts_fin-ts_inicio, -18, 11);
                        
            pr_log_perf_event(
                p_cod_programa                 => 'PERF_PR_GEN_EXTRACTO',
                p_cod_subproceso               => 'PR_GEN_EXTRACTO~lp_generar_vistas',
                p_fec_inicio                   => ts_inicio,
                p_fec_fin                      => ts_fin,
                p_val_duracion_seg             => v_duracion_seg,
                p_est_resultado                => 'SUCCESS');
            
         END IF;
         
         -- Genera Ahorro programado
         IF v_programados = 1 THEN
            v_initial_time := DBMS_UTILITY.get_time;
            ts_inicio := SYSTIMESTAMP;
            lp_generar_programados;
            v_duracion_seg := TRUNC((DBMS_UTILITY.get_time - v_initial_time) / 100, 2);
            ts_fin := SYSTIMESTAMP;
            v_log := v_log || chr(10) || 'lp_generar_programados:  duracion->' || substr(ts_fin-ts_inicio, -18, 11);
            
            pr_log_perf_event(
                p_cod_programa                 => 'PERF_PR_GEN_EXTRACTO',
                p_cod_subproceso               => 'PR_GEN_EXTRACTO~lp_generar_programados',
                p_fec_inicio                   => ts_inicio,
                p_fec_fin                      => ts_fin,
                p_val_duracion_seg             => v_duracion_seg,
                p_est_resultado                => 'SUCCESS');
            
         END IF;

         ----cod_modulo = 3 AND cod_modalidad IN ( 33, 34, 35 )
         IF v_certificados = 1 THEN
            v_initial_time := DBMS_UTILITY.get_time;
            ts_inicio := SYSTIMESTAMP;
            lp_generar_certificados;
            v_duracion_seg := TRUNC((DBMS_UTILITY.get_time - v_initial_time) / 100, 2);
            ts_fin := SYSTIMESTAMP;
            v_log := v_log || chr(10) || 'lp_generar_certificados:  duracion->' || substr(ts_fin-ts_inicio, -18, 11);
            
            pr_log_perf_event(
                p_cod_programa                 => 'PERF_PR_GEN_EXTRACTO',
                p_cod_subproceso               => 'PR_GEN_EXTRACTO~lp_generar_certificados',
                p_fec_inicio                   => ts_inicio,
                p_fec_fin                      => ts_fin,
                p_val_duracion_seg             => v_duracion_seg,
                p_est_resultado                => 'SUCCESS');
            
         END IF;

         --cod_modulo = 6
         IF v_prestamos = 1 THEN
            v_initial_time := DBMS_UTILITY.get_time;
            ts_inicio := SYSTIMESTAMP;
            lp_generar_prestamos;
            v_duracion_seg := TRUNC((DBMS_UTILITY.get_time - v_initial_time) / 100, 2);
            ts_fin := SYSTIMESTAMP;
            v_log := v_log || chr(10) || 'lp_generar_prestamos:  duracion->' || substr(ts_fin-ts_inicio, -18, 11);
                                    
            pr_log_perf_event(
                p_cod_programa                 => 'PERF_PR_GEN_EXTRACTO',
                p_cod_subproceso               => 'PR_GEN_EXTRACTO~lp_generar_prestamos',
                p_fec_inicio                   => ts_inicio,
                p_fec_fin                      => ts_fin,
                p_val_duracion_seg             => v_duracion_seg,
                p_est_resultado                => 'SUCCESS');
            
         END IF;
         
         pr_ins_log_error(v_log, null);

      END lp_gen_extracto;

      /*
         TN-1080  v1.0  EMilanese  2026-07-02
         Cambio 1: Eliminar WHERE NOT EXISTS en cur_actualizador para que todas
                   las cuentas de GE_EXT_CUENTAS_TTG se inserten en
                   GE_EXT_UPD_TBL_MAESTRAS independientemente del estado del extracto.
         Ref: TN-1099 - Mejora en la generacion de extractos incondicionales
      */
      PROCEDURE lp_val_act_maestro
      IS
        ts_inicio          TIMESTAMP;
         ts_fin             TIMESTAMP;
         v_cant_mov         NUMBER;
         --Clientes a ser excluídos de disponibilizar Extracto, porque al menos una de sus Cuentas no Valida Saldo
         CURSOR cur_cli_exluir IS
         SELECT DISTINCT(cod_persona)
         FROM (
               --Universo total de Cuentas con movimientos para el extracto
               SELECT cod_persona, nro_cuenta
               FROM GE_EXT_CUENTAS_TTG
               WHERE COD_MODALIDAD != 38 --se excluye ahorro pogramado ya que no corresponde cargar en ge_sal_diarios
               MINUS
               --Cuentas que Validan Saldo Ok
               SELECT ttg.cod_persona, ttg.nro_cuenta
               FROM GE_EXT_CUENTAS_TTG ttg,
                    ge_sal_diarios b
               WHERE b.nro_cuenta(+) = ttg.nro_cuenta
                 AND b.fecha(+) = ttg.fec_ult_extracto
                 AND nvl(b.sal_tot_cap, 0) - nvl(b.sal_ret_ade, 0) = ttg.sal_ult_extracto
                 AND NOT ( ttg.nom_tabla = 'AH_CTA_VISTAS' --Cajas de Ahorro a la vista no admite saldo < 0
                           AND ttg.sal_ult_extracto < 0 )
         );

         v_cod_persona_list_excluir  t_cod_persona_table := t_cod_persona_table();

         CURSOR cur_actualizador IS
         SELECT 1 prioridad,
                ttg.cod_persona,
                ttg.nro_cuenta,
                ttg.cod_modulo,
                ttg.cod_modalidad,
                ttg.nom_tabla,
                ttg.fec_ult_extracto,
                ttg.sal_ult_extracto,
                ttg.nro_folio,
                'I' estado
         FROM GE_EXT_CUENTAS_TTG ttg;

         TYPE t_cur_actualizador_type IS TABLE OF cur_actualizador%rowtype;
         t_cur_actualizador  t_cur_actualizador_type;

      BEGIN
         v_lugar := 'lp_val_act_maestro';

         OPEN cur_cli_exluir;
         FETCH cur_cli_exluir BULK COLLECT INTO v_cod_persona_list_excluir;
         CLOSE cur_cli_exluir;

         --Información de LOG con las Cuentas con Diferencia de Saldo
         FOR i IN 1 .. v_cod_persona_list_excluir.COUNT LOOP
            PRG_INS_LOG_PROGRAMAS(
               vg_pkg||'.LP_VAL_ACT_MAESTRO',
               'Se excluye la Generación de Extractos del Cliente porque posee al menos una Cuenta que NO Valida Saldo',
               v_cod_persona_list_excluir(i)
            );
         END LOOP;

         --Se excluye la impresión de Extractos de aquellos Clientes que tienen al menos una Cuenta que NO Valida Saldo
         FORALL i IN v_cod_persona_list_excluir.FIRST .. v_cod_persona_list_excluir.LAST
            UPDATE ge_ext_clientes
            SET fre_extracto = lower(fre_extracto)
            WHERE fec_extracto = v_fec_actual
              AND cod_persona = v_cod_persona_list_excluir(i);

         COMMIT;

         --Se insertan en la Tabla Temporal de Actualización de Maestros sólo aquellas cuentas a ser actualizadas
         ts_inicio := SYSTIMESTAMP;
         v_cant_mov := 0;
         
         v_inicio := DBMS_UTILITY.get_time;
         
         OPEN cur_actualizador;

         LOOP
            FETCH cur_actualizador
            BULK COLLECT INTO t_cur_actualizador LIMIT vg_bulk_size;
            EXIT WHEN t_cur_actualizador.COUNT() = 0;
            
            v_cant_mov := v_cant_mov + t_cur_actualizador.COUNT();

            FORALL i IN t_cur_actualizador.FIRST .. t_cur_actualizador.LAST
               INSERT INTO ge_ext_upd_tbl_maestras (
                  prioridad,
                  cod_persona,
                  nro_cuenta,
                  cod_modulo,
                  cod_modalidad,
                  nom_tabla,
                  fec_ult_extracto,
                  sal_ult_extracto,
                  nro_folio,
                  estado,
                  fec_insercion,
                  usu_insercion
               )
               VALUES (
                  t_cur_actualizador(i).prioridad,
                  t_cur_actualizador(i).cod_persona,
                  t_cur_actualizador(i).nro_cuenta,
                  t_cur_actualizador(i).cod_modulo,
                  t_cur_actualizador(i).cod_modalidad,
                  t_cur_actualizador(i).nom_tabla,
                  t_cur_actualizador(i).fec_ult_extracto,
                  t_cur_actualizador(i).sal_ult_extracto,
                  t_cur_actualizador(i).nro_folio,
                  t_cur_actualizador(i).estado,
                  sysdate,
                  user
               );
            COMMIT;
         END LOOP;

         CLOSE cur_actualizador;
         
         ts_fin := SYSTIMESTAMP;
         
         v_duracion_seg := TRUNC((DBMS_UTILITY.get_time - v_inicio) / 100, 2);
         
         pr_log_perf_event(
                p_cod_programa                 => 'PERF_PR_GEN_EXTRACTO',
                p_cod_subproceso               => 'lp_val_act_maestro~CURSOR cur_actualizador',
                p_fec_inicio                   => ts_inicio,
                p_fec_fin                      => ts_fin,
                p_val_duracion_seg             => v_duracion_seg,
                p_est_resultado                => 'SUCCESS');
         
        pr_ins_log_error('lp_val_act_maestro: [insert maestras masivo] cantidad->' || v_cant_mov || ', duracion->' || substr(ts_fin-ts_inicio, -18, 11), null);

         COMMIT;
      EXCEPTION
         WHEN OTHERS THEN
            PRG_INS_LOG_PROGRAMAS(vg_pkg||'.LP_VAL_ACT_MAESTRO', 'EXCEPTION | '||SQLERRM);
            ROLLBACK;
            RAISE;
      END lp_val_act_maestro;

   BEGIN
      -- Carga los valores de fecha que va a utilizar en el proceso --
      BEGIN
         pre_ini_aplicacion;
         pae_cnf.g_cod_modulo := 1;
      END;
      IF p_cod_persona_list IS NOT NULL THEN
         v_cant_clientes_procesados := p_cod_persona_list.COUNT;
      END IF;
               
      pr_log_perf_event(
         p_cod_programa                 => 'PERF_PR_GEN_EXTRACTO',
         p_cod_subproceso               => 'PR_GEN_EXTRACTO',
         p_fec_inicio                   => v_fec_inicio,
         p_est_resultado                => 'FEC_INICIO',
         p_val_cant_clientes_procesados => v_cant_clientes_procesados,
         p_val_cant_cuentas_procesadas  => NULL,
         p_val_cant_movimientos_gen     => NULL,
         p_est_resultado_maestras       => v_estado_maestras
      );
         
      v_pri_dia_mes_habil := vg_ult_pri_dia_mes_habil;
      v_fec_actual := vg_fec_ult_cierre_mes;

      --@LReyes --Se implementa una Tabla Temporal Global, para lograr concurrencia y poblar por sesión
      sql_util.ejecute_dml('TRUNCATE TABLE GE_EXT_CUENTAS_TTG', v_msj);
      IF v_msj IS NOT NULL THEN
         raise_application_error(-20001, 'TRUNCATE Tabla Temporal Global - '||v_msj);
      END IF;

      v_frecuencia := p_frecuencia;

      --@LReyes --La verificación de "Extracto ya generado" quedó por fuera.
      --La lista de entrada, está depurada.

      lp_gen_extracto;

      lp_act_nro_control;

      --@LReyes --validación de saldo durante la generación de extractos
      lp_val_act_maestro;

      prg_act_cod_mensaje(v_fec_actual, v_frecuencia);
      IF p_cod_persona_list IS NOT NULL AND p_cod_persona_list.COUNT > 0 THEN
         BEGIN
            SELECT COUNT(1)
            INTO v_cant_cuentas_procesadas
            FROM ge_ext_upd_tbl_maestras m,
                 TABLE(p_cod_persona_list) cli
            WHERE m.cod_persona = cli.COLUMN_VALUE
              AND m.fec_ult_extracto = v_fec_actual;
         EXCEPTION
            WHEN OTHERS THEN
               v_cant_cuentas_procesadas := 0;
         END;
         BEGIN
            SELECT COUNT(1)
            INTO v_cant_movimientos_gen
            FROM ge_ext_cli_movimientos m,
                 TABLE(p_cod_persona_list) cli
            WHERE m.cod_persona = cli.COLUMN_VALUE
              AND m.fec_extracto = v_fec_actual;
         EXCEPTION
            WHEN OTHERS THEN
               v_cant_movimientos_gen := 0;
         END;
      END IF;
      v_fec_fin := SYSTIMESTAMP;
      v_duracion_seg := TRUNC((DBMS_UTILITY.get_time - v_initial_time) / 100, 2);
      
      
      pr_log_perf_event(
         p_cod_programa                 => 'PERF_PR_GEN_EXTRACTO',
         p_cod_subproceso               => 'PR_GEN_EXTRACTO',
         p_fec_inicio                   => v_fec_inicio,
         p_fec_fin                      => v_fec_fin,
         p_val_duracion_seg             => v_duracion_seg,
         p_est_resultado                => 'SUCCESS',
         p_val_cant_clientes_procesados => v_cant_clientes_procesados,
         p_val_cant_cuentas_procesadas  => v_cant_cuentas_procesadas,
         p_val_cant_movimientos_gen     => v_cant_movimientos_gen,
         p_est_resultado_maestras       => v_estado_maestras
      );
      
      
   EXCEPTION
      WHEN OTHERS THEN
         v_fec_fin := SYSTIMESTAMP;
         v_duracion_seg := TRUNC((DBMS_UTILITY.get_time - v_initial_time) / 100, 2);
         v_estado_maestras := 'ERROR';
         
         pr_log_perf_event(
            p_cod_programa                 => 'PERF_PR_GEN_EXTRACTO',
            p_cod_subproceso               => 'PR_GEN_EXTRACTO',
            p_fec_inicio                   => v_fec_inicio,
            p_fec_fin                      => v_fec_fin,
            p_val_duracion_seg             => v_duracion_seg,
            p_est_resultado                => 'ERROR',
            p_des_error                    => SQLERRM,
            p_val_cant_clientes_procesados => v_cant_clientes_procesados,
            p_val_cant_cuentas_procesadas  => v_cant_cuentas_procesadas,
            p_val_cant_movimientos_gen     => v_cant_movimientos_gen,
            p_est_resultado_maestras       => v_estado_maestras
         );
         
         PRG_INS_LOG_PROGRAMAS(vg_pkg||'.PR_GEN_EXTRACTO', 'EXCEPTION | '||SQLERRM);
         ROLLBACK;
         IF SQLCODE <= -20000 THEN
            RAISE;
         ELSE
            RAISE_APPLICATION_ERROR(-20000, v_lugar||' - '||SQLERRM);
         END IF;
   END PR_GEN_EXTRACTO;

   /*
      23-09-2024  v1.0  LReyes
      Sobrecarga SP, para Generar Extractos a partir de un único Cliente parametrizado.
   */ 
   PROCEDURE PR_GEN_EXTRACTO (
      p_frecuencia  IN VARCHAR2 DEFAULT 'M',
      p_cod_persona IN ba_personas.cod_persona%TYPE DEFAULT NULL
   )
   IS
      l_cod_persona t_cod_persona_table := t_cod_persona_table();
   BEGIN
      IF p_cod_persona IS NOT NULL THEN
         l_cod_persona.EXTEND;
         l_cod_persona(l_cod_persona.COUNT) := p_cod_persona;
      END IF;

      PR_GEN_EXTRACTO(p_frecuencia, l_cod_persona);
   END PR_GEN_EXTRACTO;

   /*
      23-09-2024  v1.0  EMilanese
      Elimina Extractos a partir de la Lista de Clientes parametrizada.
   */ 
   PROCEDURE pr_eli_extracto (
      p_fec_extracto      IN ge_ext_clientes.fec_extracto%TYPE, 
      p_cod_persona_list  IN t_cod_persona_table
   )
   IS
   BEGIN
      BEGIN
         pre_ini_aplicacion;
         pae_cnf.g_cod_modulo := 1;
      END;

      FORALL i IN p_cod_persona_list.FIRST()..p_cod_persona_list.LAST()
          DELETE FROM ge_ext_upd_tbl_maestras
          WHERE COD_PERSONA = p_cod_persona_list(i)
            AND FEC_ULT_EXTRACTO = p_fec_extracto;
      COMMIT;

      FORALL i IN p_cod_persona_list.FIRST()..p_cod_persona_list.LAST()
          DELETE FROM ge_ext_resumenes
          WHERE COD_PERSONA = p_cod_persona_list(i)
            AND FEC_EXTRACTO = p_fec_extracto;
      COMMIT;

      FORALL i IN p_cod_persona_list.FIRST()..p_cod_persona_list.LAST()
          DELETE FROM ge_ext_cli_mov_pendientes
          WHERE COD_PERSONA = p_cod_persona_list(i)
            AND FEC_EXTRACTO = p_fec_extracto;
      COMMIT;

      FORALL i IN p_cod_persona_list.FIRST()..p_cod_persona_list.LAST()
          DELETE FROM ge_ext_cli_mov_retenidos
          WHERE COD_PERSONA = p_cod_persona_list(i)
            AND FEC_EXTRACTO = p_fec_extracto;
      COMMIT;

      FORALL i IN p_cod_persona_list.FIRST()..p_cod_persona_list.LAST()
          DELETE FROM ge_ext_cli_movimientos
          WHERE COD_PERSONA = p_cod_persona_list(i)
            AND FEC_EXTRACTO = p_fec_extracto;
      COMMIT;

      FORALL i IN p_cod_persona_list.FIRST()..p_cod_persona_list.LAST()
          DELETE FROM ge_ext_cli_cuentas
          WHERE COD_PERSONA = p_cod_persona_list(i)
            AND FEC_EXTRACTO = p_fec_extracto;
      COMMIT;

      FORALL i IN p_cod_persona_list.FIRST()..p_cod_persona_list.LAST()
          DELETE FROM ge_ext_clientes
          WHERE COD_PERSONA = p_cod_persona_list(i)
            AND FEC_EXTRACTO = p_fec_extracto;
      COMMIT;

   EXCEPTION
      WHEN OTHERS THEN
         ROLLBACK;
         RAISE;
   END pr_eli_extracto;

   /*
      19-09-2024  v1.0  Ctimossi
      Loguea inicio del proceso de actualizacion masiva de maestros
   */
   PROCEDURE pl_log_inicio_proceso (
      p_fecha_inicio DATE,
      p_estado       VARCHAR2,
      p_ejecucion_id OUT NUMBER
   ) AS
      PRAGMA autonomous_transaction;
      v_id_proceso ge_pro_act_ext_maestras.id_proceso%TYPE;
   BEGIN
      SELECT
         it.s_id_proceso.nextval
      INTO v_id_proceso
      FROM
         dual;

      INSERT INTO ge_pro_act_ext_maestras (
         id_proceso,
         fec_inicio,
         estado
      ) VALUES (
         v_id_proceso,
         p_fecha_inicio,
         p_estado
      ) RETURNING v_id_proceso INTO p_ejecucion_id;

      COMMIT;
   END pl_log_inicio_proceso;

   /*
      19-09-2024  v1.0  Ctimossi
      Loguea fin del proceso de actualizacion masiva de maestros
   */
   PROCEDURE pl_log_fin_proceso (
      p_ejecucion_id         NUMBER,
      p_fecha_fin            DATE,
      p_cuentas_actualizadas NUMBER,
      p_estado               VARCHAR2,
      p_observacion          ge_pro_act_ext_maestras.observacion%TYPE
   ) AS
      PRAGMA autonomous_transaction;
   BEGIN
      UPDATE ge_pro_act_ext_maestras
      SET
         fec_fin = p_fecha_fin,
         cant_cuen_actualizadas = p_cuentas_actualizadas,
         estado = p_estado,
         observacion = p_observacion
      WHERE
         id_proceso = p_ejecucion_id;

      COMMIT;
   END pl_log_fin_proceso;

   /*
      19-09-2024  v1.0  Ctimossi
      Actualización masiva de los datos de extractos en las tablas maestro: cc_cta_corrientes, cc_cta_bancarias, ah_cta_vistas
      Este proceso se ejecuta dentro del proceso de cierre diario con una restricción de tiempo que es configurable.
   */
   PROCEDURE pr_act_ext_maestras
   IS
      v_fec_inicio            ge_pro_act_ext_maestras.fec_inicio%TYPE;
      v_fec_fin               ge_pro_act_ext_maestras.fec_fin%TYPE;
      v_tiem_transcurrido     NUMBER;
      v_tiem_maximo           CONSTANT ge_par_dinamicos.val_parametro%TYPE := fug_obt_pardinamico('MIN_EXT_TIMEOUT');   -- Ventana de timeout permitida en el cierre diario
      v_tam_lote              CONSTANT ge_pro_act_ext_maestras.cant_cuen_actualizadas%TYPE := fug_obt_pardinamico('VAL_PAG_ACT_EXT'); -- Tamaño del lote
      v_cue_act_cc_corrientes ge_pro_act_ext_maestras.cant_cuen_actualizadas%TYPE := 0;      -- Contador de cuentas cc corriente actualizados
      v_cue_act_cta_bancarias ge_pro_act_ext_maestras.cant_cuen_actualizadas%TYPE := 0;      -- Contador de cuentas cta bancarias actualziados
      v_cue_act_ah_vistas     ge_pro_act_ext_maestras.cant_cuen_actualizadas%TYPE := 0;      -- Contador de cuentas ah vistas actualizados
      v_cue_tot_actualizadas  ge_pro_act_ext_maestras.cant_cuen_actualizadas%TYPE := 0;
      v_ejec_id               ge_pro_act_ext_maestras.id_proceso%TYPE;
      v_user                  ge_ext_upd_tbl_maestras.usu_modificacion%TYPE;
      v_estado                ge_pro_act_ext_maestras.estado%TYPE := 'COMPLETO';
      v_observacion           ge_pro_act_ext_maestras.observacion%TYPE := NULL;
      v_cue_act_ah_plazos     ge_pro_act_ext_maestras.cant_cuen_actualizadas%TYPE := 0;      -- Contador de cuentas ah plazos actualizados

      bulk_errors EXCEPTION;
      PRAGMA exception_init ( bulk_errors, -24381 );

      TYPE rv_ge_ext_maestras IS TABLE OF ge_ext_upd_tbl_maestras%rowtype INDEX BY PLS_INTEGER;
      v_cuentas               rv_ge_ext_maestras;
      TYPE rv_ge_errores IS   TABLE OF ge_log_errores%rowtype;
      v_errores               rv_ge_errores := rv_ge_errores();

      v_cant_errores          NUMBER := 0;

      CURSOR cu_cue_cc_cta_corriente IS
      SELECT prioridad,
             cod_persona,
             nro_cuenta,
             cod_modulo,
             cod_modalidad,
             nom_tabla,
             fec_ult_extracto,
             sal_ult_extracto,
             nro_folio,
             estado,
             traza,
             NULL,
             NULL,
             NULL,
             NULL
      FROM ge_ext_upd_tbl_maestras
      WHERE estado = 'I'
        AND nom_tabla = 'CC_CTA_CORRIENTES'
        AND fec_ult_extracto = vg_fec_ult_cierre_mes;

      CURSOR cu_cue_cc_cta_bancarias IS
      SELECT prioridad,
             cod_persona,
             nro_cuenta,
             cod_modulo,
             cod_modalidad,
             nom_tabla,
             fec_ult_extracto,
             sal_ult_extracto,
             nro_folio,
             estado,
             traza,
             NULL,
             NULL,
             NULL,
             NULL
      FROM ge_ext_upd_tbl_maestras
      WHERE estado = 'I'
        AND nom_tabla = 'CC_CTA_BANCARIAS'
        AND fec_ult_extracto = vg_fec_ult_cierre_mes;

      CURSOR cu_cue_ah_cta_vistas IS
      SELECT prioridad,
             cod_persona,
             nro_cuenta,
             cod_modulo,
             cod_modalidad,
             nom_tabla,
             fec_ult_extracto,
             sal_ult_extracto,
             nro_folio,
             estado,
             traza,
             NULL,
             NULL,
             NULL,
             NULL
      FROM ge_ext_upd_tbl_maestras
      WHERE estado = 'I'
        AND nom_tabla = 'AH_CTA_VISTAS'
        AND fec_ult_extracto = vg_fec_ult_cierre_mes;

      CURSOR cu_cue_ah_cta_plazos IS
      SELECT prioridad,
             cod_persona,
             nro_cuenta,
             cod_modulo,
             cod_modalidad,
             nom_tabla,
             fec_ult_extracto,
             sal_ult_extracto,
             nro_folio,
             estado,
             traza,
             NULL,
             NULL,
             NULL,
             NULL
      FROM ge_ext_upd_tbl_maestras
      WHERE estado = 'I'
        AND nom_tabla = 'AH_CTA_PLAZOS'
        AND fec_ult_extracto = vg_fec_ult_cierre_mes;

   BEGIN
      PR_SET_PARAMETROS;

      BEGIN
         pre_ini_aplicacion;
         pae_cnf.g_cod_modulo := 1;
      END;

      v_fec_inicio := sysdate;
      SELECT substr(user, 1, 10)
      INTO v_user
      FROM dual;

      pl_log_inicio_proceso(
         p_fecha_inicio => v_fec_inicio,
         p_estado => 'INICIADO',
         p_ejecucion_id => v_ejec_id
      );

        ---------------------------------------cc cta corriente ----------------------------------------------
      OPEN cu_cue_cc_cta_corriente;
      LOOP
         FETCH cu_cue_cc_cta_corriente
         BULK COLLECT INTO v_cuentas LIMIT v_tam_lote;
         EXIT WHEN v_cuentas.count = 0 OR v_estado = 'TIMEOUT';

         BEGIN
            FORALL i IN 1..v_cuentas.count SAVE EXCEPTIONS
               UPDATE cc_cta_corrientes e
               SET
                  e.nro_folio = v_cuentas(i).nro_folio,
                  e.fec_ult_extracto = v_cuentas(i).fec_ult_extracto,
                  e.sal_ult_extracto = v_cuentas(i).sal_ult_extracto
               WHERE
                  e.nro_cuenta = v_cuentas(i).nro_cuenta;

            v_cue_act_cc_corrientes := v_cue_act_cc_corrientes + SQL%rowcount;
         EXCEPTION
            WHEN bulk_errors THEN
               v_cant_errores := SQL%bulk_exceptions.count;

               FOR i IN 1..v_cant_errores LOOP
                  v_errores.extend;
                  v_errores(i).det_error := 'Error en update cc_cta_corriente para la cuenta: '
                                            || v_cuentas(i).nro_cuenta
                                            || ' '
                                            || sqlerrm(-SQL%bulk_exceptions(i).error_code);

                  v_errores(i).nro_cuenta := v_cuentas(i).nro_cuenta;
               END LOOP;
         END;

         v_tiem_transcurrido := ( sysdate - v_fec_inicio ) * 24 * 60;
         IF v_tiem_transcurrido >= v_tiem_maximo THEN
            v_fec_fin := sysdate;
            v_estado := 'TIMEOUT';

            EXIT;
         END IF;

         COMMIT;
      END LOOP;
      CLOSE cu_cue_cc_cta_corriente;

      UPDATE ge_ext_upd_tbl_maestras
      SET
         estado = 'P',
         fec_modificacion = sysdate,
         usu_modificacion = v_user
      WHERE
         ROWID IN (
            SELECT
               tmp.rowid
            FROM
                    ge_ext_upd_tbl_maestras tmp
               JOIN cc_cta_corrientes cta ON cta.nro_cuenta = tmp.nro_cuenta
                                             AND cta.nro_folio = tmp.nro_folio
                                             AND cta.fec_ult_extracto = tmp.fec_ult_extracto
                                             AND cta.sal_ult_extracto = tmp.sal_ult_extracto
         )
         AND estado = 'I';

        ---------------------------------------cta bancaria ----------------------------------------------
      IF v_estado != 'TIMEOUT' THEN
         OPEN cu_cue_cc_cta_bancarias;
         LOOP
            FETCH cu_cue_cc_cta_bancarias
            BULK COLLECT INTO v_cuentas LIMIT v_tam_lote;
            EXIT WHEN v_cuentas.count = 0 OR v_estado = 'TIMEOUT';

            BEGIN
               FORALL i IN 1..v_cuentas.count SAVE EXCEPTIONS
                  UPDATE cc_cta_bancarias e
                  SET
                     e.nro_folio = v_cuentas(i).nro_folio,
                     e.fec_ult_extracto = v_cuentas(i).fec_ult_extracto,
                     e.sal_ult_extracto = v_cuentas(i).sal_ult_extracto
                  WHERE
                     e.nro_cuenta = v_cuentas(i).nro_cuenta;

               v_cue_act_cta_bancarias := v_cue_act_cta_bancarias + SQL%rowcount;
            EXCEPTION
               WHEN OTHERS THEN
                  v_cant_errores := SQL%bulk_exceptions.count;

                  FOR i IN 1..v_cant_errores LOOP
                     v_errores.extend;
                     v_errores(i).det_error := 'Error en update cc_cta_bancarias para la cuenta: '
                                               || v_cuentas(i).nro_cuenta
                                               || ' '
                                               || sqlerrm(-SQL%bulk_exceptions(i).error_code);

                     v_errores(i).nro_cuenta := v_cuentas(i).nro_cuenta;
                  END LOOP;
            END;

            v_tiem_transcurrido := ( sysdate - v_fec_inicio ) * 24 * 60;
            IF v_tiem_transcurrido >= v_tiem_maximo THEN
               v_fec_fin := sysdate;
               v_estado := 'TIMEOUT';

               EXIT;
            END IF;

            COMMIT;
         END LOOP;
         CLOSE cu_cue_cc_cta_bancarias;

         UPDATE ge_ext_upd_tbl_maestras
         SET
            estado = 'P',
            fec_modificacion = sysdate,
            usu_modificacion = v_user
         WHERE
            ROWID IN (
               SELECT
                  tmp.rowid
               FROM
                       ge_ext_upd_tbl_maestras tmp
                  JOIN cc_cta_bancarias cta ON cta.nro_cuenta = tmp.nro_cuenta
                                               AND cta.nro_folio = tmp.nro_folio
                                               AND cta.fec_ult_extracto = tmp.fec_ult_extracto
                                               AND cta.sal_ult_extracto = tmp.sal_ult_extracto
            )
            AND estado = 'I';

      END IF;

        ---------------------------------------ah cta vistas ----------------------------------------------       
      IF v_estado != 'TIMEOUT' THEN
         OPEN cu_cue_ah_cta_vistas;
         LOOP
            FETCH cu_cue_ah_cta_vistas
            BULK COLLECT INTO v_cuentas LIMIT v_tam_lote;
            EXIT WHEN v_cuentas.count = 0 OR v_estado = 'TIMEOUT';
            BEGIN
               FORALL i IN 1..v_cuentas.count SAVE EXCEPTIONS
                  UPDATE ah_cta_vistas e
                  SET
                     e.nro_folio = v_cuentas(i).nro_folio,
                     e.fec_ult_extracto = v_cuentas(i).fec_ult_extracto,
                     e.sal_ult_extracto = v_cuentas(i).sal_ult_extracto
                  WHERE
                     e.nro_cuenta = v_cuentas(i).nro_cuenta;

               v_cue_act_ah_vistas := v_cue_act_ah_vistas + SQL%rowcount;
            EXCEPTION
               WHEN OTHERS THEN
                  v_cant_errores := SQL%bulk_exceptions.count;
                  FOR i IN 1..v_cant_errores LOOP
                     v_errores.extend;
                     v_errores(i).det_error := 'Error en update ah_cta_vistas para la cuenta: '
                                               || v_cuentas(i).nro_cuenta
                                               || ' '
                                               || sqlerrm(-SQL%bulk_exceptions(i).error_code);

                     v_errores(i).nro_cuenta := v_cuentas(i).nro_cuenta;
                  END LOOP;
            END;

            v_tiem_transcurrido := ( sysdate - v_fec_inicio ) * 24 * 60;
            IF v_tiem_transcurrido >= v_tiem_maximo THEN
               v_fec_fin := sysdate;
               v_estado := 'TIMEOUT';

               EXIT;
            END IF;

            COMMIT;
         END LOOP;
         CLOSE cu_cue_ah_cta_vistas;

         UPDATE ge_ext_upd_tbl_maestras
         SET
            estado = 'P',
            fec_modificacion = sysdate,
            usu_modificacion = v_user
         WHERE
            ROWID IN (
               SELECT
                  tmp.rowid
               FROM
                       ge_ext_upd_tbl_maestras tmp
                  JOIN ah_cta_vistas cta ON cta.nro_cuenta = tmp.nro_cuenta
                                            AND cta.nro_folio = tmp.nro_folio
                                            AND cta.fec_ult_extracto = tmp.fec_ult_extracto
                                            AND cta.sal_ult_extracto = tmp.sal_ult_extracto
            )
            AND estado = 'I';
      END IF;

   ---------------------------------------ah cta plazos ----------------------------------------------
      IF v_estado != 'TIMEOUT' THEN
         OPEN cu_cue_ah_cta_plazos;
         LOOP
            FETCH cu_cue_ah_cta_plazos
            BULK COLLECT INTO v_cuentas LIMIT v_tam_lote;
            EXIT WHEN v_cuentas.count = 0 OR v_estado = 'TIMEOUT';
            BEGIN
               FORALL i IN 1..v_cuentas.count SAVE EXCEPTIONS
                  UPDATE ah_cta_plazos e
                  SET
                     e.nro_folio = v_cuentas(i).nro_folio,
                     e.fec_ult_extracto = v_cuentas(i).fec_ult_extracto,
                     e.sal_ult_extracto = v_cuentas(i).sal_ult_extracto
                  WHERE
                     e.nro_cuenta = v_cuentas(i).nro_cuenta;

               v_cue_act_ah_plazos := v_cue_act_ah_plazos + SQL%rowcount;
            EXCEPTION
               WHEN OTHERS THEN
                  v_cant_errores := SQL%bulk_exceptions.count;
                  FOR i IN 1..v_cant_errores LOOP
                     v_errores.extend;
                     v_errores(i).det_error := 'Error en update ah_cta_plazos para la cuenta: '
                                               || v_cuentas(i).nro_cuenta
                                               || ' '
                                               || sqlerrm(-SQL%bulk_exceptions(i).error_code);

                     v_errores(i).nro_cuenta := v_cuentas(i).nro_cuenta;
                  END LOOP;
            END;

            v_tiem_transcurrido := ( sysdate - v_fec_inicio ) * 24 * 60;
            IF v_tiem_transcurrido >= v_tiem_maximo THEN
               v_fec_fin := sysdate;
               v_estado := 'TIMEOUT';

               EXIT;
            END IF;

            COMMIT;
         END LOOP;
         CLOSE cu_cue_ah_cta_plazos;

         UPDATE ge_ext_upd_tbl_maestras
         SET
            estado = 'P',
            fec_modificacion = sysdate,
            usu_modificacion = v_user
         WHERE
            ROWID IN (
               SELECT
                  tmp.rowid
               FROM
                       ge_ext_upd_tbl_maestras tmp
                  JOIN ah_cta_plazos cta ON cta.nro_cuenta = tmp.nro_cuenta
                                            AND cta.nro_folio = tmp.nro_folio
                                            AND cta.fec_ult_extracto = tmp.fec_ult_extracto
                                            AND cta.sal_ult_extracto = tmp.sal_ult_extracto
            )
            AND estado = 'I';
      END IF;

        -- Si se procesan todos los cuentas antes del timeout
      v_fec_fin := sysdate;
      v_cue_tot_actualizadas := v_cue_act_cc_corrientes + v_cue_act_cta_bancarias + v_cue_act_ah_vistas + v_cue_act_ah_plazos;

      IF v_cue_tot_actualizadas = 0 THEN
         v_estado := 'APAGADO';
      END IF;

         -- Loguea los errores en la tabla de errores en transacción autónoma
      IF v_errores.count > 0 THEN
         FOR i IN 1..v_errores.count LOOP
            pr_ins_log_error(v_errores(i).det_error, v_errores(i).nro_cuenta);
         END LOOP;

         v_observacion := 'Ver en ge_log_errores las cuentas con errores en la actualizacion de tablas maestras';
      END IF;

      pl_log_fin_proceso(
         p_ejecucion_id => v_ejec_id,
         p_fecha_fin => v_fec_fin,
         p_cuentas_actualizadas => v_cue_tot_actualizadas,
         p_estado => v_estado,
         p_observacion => v_observacion
      );

      COMMIT;
   EXCEPTION
      WHEN OTHERS THEN
         ROLLBACK;
         v_fec_fin := sysdate;
         v_cue_tot_actualizadas := 0;
         v_estado := 'ERROR';
         pl_log_fin_proceso(
            p_ejecucion_id => v_ejec_id,
            p_fecha_fin => v_fec_fin,
            p_cuentas_actualizadas => v_cue_tot_actualizadas,
            p_estado => v_estado,
            p_observacion => dbms_utility.format_error_backtrace||' - '||sqlerrm
         );

         pr_ins_log_error(dbms_utility.format_error_backtrace|| ' - '||sqlerrm, NULL);
         IF cu_cue_ah_cta_vistas%isopen THEN
            CLOSE cu_cue_ah_cta_vistas;
         END IF;
         IF cu_cue_cc_cta_bancarias%isopen THEN
            CLOSE cu_cue_cc_cta_bancarias;
         END IF;
         IF cu_cue_cc_cta_corriente%isopen THEN
            CLOSE cu_cue_cc_cta_corriente;
         END IF;
   END pr_act_ext_maestras;

   /*
      19-09-2024  v1.0  Ctimossi
      Logueo de errores
   */
   PROCEDURE pr_ins_log_error (
      p_det_error  ge_log_errores.det_error%TYPE,
      p_nro_cuenta ge_log_errores.nro_cuenta%TYPE
   ) IS
   BEGIN
      prg_ins_log_programas(vg_cod_programa, p_det_error, NULL, p_nro_cuenta);
   EXCEPTION
      WHEN OTHERS THEN
         NULL;
   END pr_ins_log_error;

   /*
      04-10-2024  v1.0  LReyes
      Procedimiento invocante a ser incluido en la cadena de Inicio de Día para la generación de extractos.
      
      16-01-2025  v1.1  EMilanese
      TN-592: Se cambia la frecuencia de ejecucion a Diaria y se controla que solo se ejecute el primer dia habil del mes.
    */ 
   PROCEDURE PR_GEN_EXT_MENSUAL
   IS
        v_fec_actual     ge_calendarios.fec_actual%type:= pag_cal.fu_obt_fec_actual(1);
        v_pri_dia_habil  ge_calendarios.fec_actual%type:= pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1);
   BEGIN
        IF v_pri_dia_habil = v_fec_actual THEN
            dbms_scheduler.run_job('"IT"."JOB_EXT_MENSUAL"', FALSE);
            PRG_INS_LOG_PROGRAMAS(vg_pkg||'.PR_GEN_EXT_MENSUAL', 'Job iniciado Ok');
        ELSE
            PRG_INS_LOG_PROGRAMAS(vg_pkg||'.PR_GEN_EXT_MENSUAL','Job JOB_EXT_MENSUAL no ejecutado: no es primer dia habil del mes');
        END IF;
   EXCEPTION
      WHEN OTHERS THEN
         PRG_INS_LOG_PROGRAMAS(vg_pkg||'.PR_GEN_EXT_MENSUAL', 'EXCEPTION | '||SQLERRM);
         RAISE;
   END PR_GEN_EXT_MENSUAL;

   /*
      04-10-2024  v1.0  LReyes
      Procedimiento invocante a ser incluido en la cadena de Fin de Día para la actualización de tablas maestro.
   */ 
   PROCEDURE PR_ACT_EXT_MAESTROS
   IS
      v_fec_actual     ge_calendarios.fec_actual%type:= pag_cal.fu_obt_fec_actual(1);
      v_pri_dia_habil  ge_calendarios.fec_actual%type:= pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1);
      v_act_ext_flag   ge_par_dinamicos.val_parametro%type:= fug_obt_pardinamico('ACT_EXT_MAESTROS_FLAG');
   BEGIN
      IF v_pri_dia_habil = v_fec_actual OR v_act_ext_flag = 'S' THEN
         PRG_INS_LOG_PROGRAMAS(vg_pkg||'.PR_ACT_EXT_MAESTROS','Job JOB_EXT_MAESTROS ejecutado. Flag manual: ' ||v_act_ext_flag);
         dbms_scheduler.run_job('"IT"."JOB_EXT_MAESTROS"',FALSE);
      ELSE
         PRG_INS_LOG_PROGRAMAS(vg_pkg||'.PR_ACT_EXT_MAESTROS','Job JOB_EXT_MAESTROS no ejecutado: no es primer dia habil del mes y no esta habilitado el Flag ACT_EXT_MAESTROS_FLAG');
      END IF;
   EXCEPTION
      WHEN OTHERS THEN
         PRG_INS_LOG_PROGRAMAS(vg_pkg||'.PR_ACT_EXT_MAESTROS','Error: '||dbms_utility.format_error_backtrace|| ' - '||sqlerrm);
         RAISE;
   END PR_ACT_EXT_MAESTROS;

   /*
      23-09-2024  v1.0  LReyes
      Setear los valores configurados en la base de datos para el uso del package.
   */ 
   PROCEDURE PR_SET_PARAMETROS
   IS
      v_initial_time  PLS_INTEGER := DBMS_UTILITY.get_time;
      v_elapsed_time  PLS_INTEGER;
      v_elapsed_seg   NUMBER;
      v_fec_inicio    TIMESTAMP := SYSTIMESTAMP;
      v_fec_fin       TIMESTAMP;
      /*
         02-10-2024  v1.0  LReyes
         Setear el Primer y el Último Día Hábil del mes para el cual se desea Generar Extracto.
         Sin importar si el Cierre de Mes se realizó después del último día hábil del mismo.
      */ 
      PROCEDURE PL_OBT_FEC_MES_EXTRACTO (
         v_fec_pri_dia_habil_mes_ext OUT DATE, --Primer Día Hábil del Mes a Generar Extracto
         v_fec_ult_dia_habil_mes_ext OUT DATE  --Último Día Hábil del Mes a Generar Extracto
      )
      IS
         v_fec_actual            DATE; --Si o si, debe ser el Último Día Hábil del Mes a Generar Extracto ó posterior
         v_fec_proximo_dia_habil DATE; --Próximo Día Hábil a partir de v_fec_actual (Nos posiciona si o si en el mes siguiente al del Extracto a generar)
         v_fec_ult_dia_mes_ext   DATE; --Último Día del Mes a Generar Extracto
      BEGIN
         pag_cal.pr_obt_dat_calendar(3);

         --Fechas auxiliares
         v_fec_actual            := pag_cal.g_fec_actual;
         v_fec_proximo_dia_habil := pag_cal.fu_obt_fec_habil(v_fec_actual+1, 1, 1);
         v_fec_ult_dia_mes_ext   := TRUNC(v_fec_proximo_dia_habil, 'MM')-1;

         --Fechas Objetivo
         v_fec_pri_dia_habil_mes_ext := pag_cal.fu_obt_fec_habil(TRUNC(v_fec_ult_dia_mes_ext, 'MM'), 1, 1);
         v_fec_ult_dia_habil_mes_ext := pag_cal.fu_obt_fec_habil(v_fec_ult_dia_mes_ext, -1, 1);
      END;
   BEGIN
      vg_intervalo_size := fug_obt_pardinamico('PAG_EXT_INT_LENGTH');
      vg_max_loop_intervalos := fug_obt_pardinamico('PAG_EXT_INT_MAX_LOOP');
      vg_timeout_pool_MI := fug_obt_pardinamico('PAG_EXT_TIMEOUT_POOL_MI');
      vg_timeout_job_MI := fug_obt_pardinamico('PAG_EXT_TIMEOUT_JOB_MI');
      vg_bulk_size := fug_obt_pardinamico('PAG_EXT_BULK_SIZE');
      vg_job_cant_instancias := fug_obt_pardinamico('PAG_EXT_JOB_CANT_INSTANCIAS');
      vg_max_movimientos := NVL(fug_obt_pardinamico('PAG_EXT_MAX_MOVIMIENTOS'), 10000);
      PL_OBT_FEC_MES_EXTRACTO(vg_ult_pri_dia_mes_habil, vg_fec_ult_cierre_mes);
      v_fec_fin := SYSTIMESTAMP;
      v_elapsed_time := DBMS_UTILITY.get_time - v_initial_time;
      v_elapsed_seg := TRUNC(v_elapsed_time / 100, 2);
      
   EXCEPTION
      WHEN OTHERS THEN
         v_fec_fin := SYSTIMESTAMP;
         v_elapsed_time := DBMS_UTILITY.get_time - v_initial_time;
         v_elapsed_seg := TRUNC(v_elapsed_time / 100, 2);
         RAISE;
   END PR_SET_PARAMETROS;

BEGIN
   PR_SET_PARAMETROS;
END PAG_EXT;
