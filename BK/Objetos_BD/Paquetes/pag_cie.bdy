CREATE OR REPLACE PACKAGE BODY IT.PAG_CIE
IS
   vg_cod_programa VARCHAR2(30); -- Programa que está siendo ejecutado dinámicamente
   vg_cod_proceso  NUMBER(3,0);  -- Proceso al que pertenece el Programa
   vg_nro_orden    NUMBER(3,0);  -- Orden que identifica al Programa en la secuencia de pasos del Proceso
   vg_contexto     VARCHAR2(15); -- Identifica la sesión en la que se ejecuta el Programa
   vg_log_level    PLS_INTEGER;  -- Nivel de log configurado para registrar mensajes

   /*
      30-06-2025  v1.0  LReyes
      OBJETIVO: Obtener, en texto resumen, información del entorno de ejecución del usuario.
   */
   FUNCTION FU_OBT_ENTORNO
   RETURN VARCHAR2
   IS
      v_txt VARCHAR2(300) := NULL;
   BEGIN
      SELECT '{n:'||inst_id
             ||' sid:'|| sid
             ||' serial:'|| serial#
             ||'}{'||
             SUBSTR(
                 NVL(SYS_CONTEXT('USERENV', 'BG_JOB_ID'),0)
                 ||';'|| NVL(action, 'null')
                 ||','|| NVL(client_info, 'null'),
             1, 250)
             ||'}' context_env
      INTO v_txt
      FROM gv$session
      WHERE inst_id = SYS_CONTEXT('USERENV', 'INSTANCE')  --Instancia específica de la base
        AND sid     = SYS_CONTEXT('USERENV', 'SID')       --Sesión dentro de la instancia
        AND audsid  = SYS_CONTEXT('USERENV', 'SESSIONID') --Auditoría en correlación con logs de seguridad
        AND serial# = ( SELECT serial#                    --Número de serie asociado a la sesión
                        FROM v$session
                        WHERE sid = SYS_CONTEXT('USERENV', 'SID')
                          AND ROWNUM = 1 );

      RETURN v_txt;
   EXCEPTION
      WHEN OTHERS THEN
         RETURN ' (!) '||
                SUBSTR(
                   'Excepción en FU_OBT_ENTORNO '
                   ||'{n:'   || SYS_CONTEXT('USERENV', 'INSTANCE')
                   ||' sid:' || SYS_CONTEXT('USERENV', 'SID')
                   ||' asid:'|| SYS_CONTEXT('USERENV', 'SESSIONID')
                   ||' err:' || SQLERRM,
                1, 250)||'}';
   END FU_OBT_ENTORNO;

   /*
      22-01-2025  v1.0  LReyes
      Encapsula el acceso a las constantes del package para el Forms GPPROFIN.
   */
   FUNCTION FN_GET_CONSTANTE (
      p_key IN VARCHAR2
   )
   RETURN VARCHAR2
   IS
      v_resultado VARCHAR2(55) := NULL;
   BEGIN
      v_resultado := CASE
                        WHEN p_key = 'c_msj_DEP_F_NO_RESUELTA' THEN c_msj_DEP_F_NO_RESUELTA
                        WHEN p_key = 'c_msj_PRO_P_EN_EJECUCION' THEN c_msj_PRO_P_EN_EJECUCION
                        ELSE NULL
                     END;

      RETURN v_resultado;
   END FN_GET_CONSTANTE;

   /*
      22-01-2025  v1.0  LReyes
      Genera el nombre de un JOB a partir de los parámetros COD_PROCESO y NRO_ORDEN.
   */ 
   FUNCTION FN_JOB_NOMBRAR (
      p_cod_proceso IN NUMBER,
      p_nro_orden   IN NUMBER
   )
   RETURN VARCHAR2
   IS
      v_resultado VARCHAR2(25) := NULL;
   BEGIN
      IF p_cod_proceso IS NOT NULL AND p_nro_orden IS NOT NULL THEN
         v_resultado := 'JOB_EJE_PROG_'||p_cod_proceso||'_'||p_nro_orden;
      END IF;

      RETURN v_resultado;
   END FN_JOB_NOMBRAR;

   /*
      23-12-2024  v1.0  LReyes
      Evalúa las dependencias configuradas para el Programa parametrizado según tipo.
      'F'=Fin de Programa Previo, 'P'=Paralelismo según Programas Predecesores, 'C'=Control, 'D'=Debug
      Se usa también en el Forms GPPROFIN.
   */ 
   FUNCTION FN_VER_DEPENDENCIA (
      p_cod_proceso  IN  NUMBER,
      p_cod_programa IN  VARCHAR2,
      p_tipo         IN  VARCHAR2
   )
   RETURN VARCHAR2
   IS
      v_resultado VARCHAR2(2) := 'NO';
   BEGIN
      SELECT 'SI'
      INTO v_resultado
      FROM ge_procesos_dep
      WHERE cod_proceso = p_cod_proceso
        AND cod_programa = p_cod_programa
        AND tipo = p_tipo
        AND ROWNUM = 1;

      RETURN v_resultado;
   EXCEPTION
      WHEN OTHERS THEN
         RETURN v_resultado;
   END FN_VER_DEPENDENCIA;

   /*
      23-09-2024  v1.0  LReyes
      Ejecuta las dependencias de Control para el Programa parametrizado.
   */
   FUNCTION FN_CTR_PROGRAMA (
      p_cod_programa IN  VARCHAR2
   )
   RETURN NUMBER
   IS
      v_resultado NUMBER := -1;
   BEGIN
      /*
      CASE UPPER(p_cod_programa)
         WHEN 'PRG_TRA_HISTORICO' THEN
            BEGIN
               v_resultado := 0;
               NULL;
            EXCEPTION
               WHEN OTHERS THEN
                  v_resultado := -1;
            END;
         ELSE
            v_resultado := -2; --Lógica de Control INEXISTENTE para el Programa
      END CASE;
      */
      v_resultado := 0;
      RETURN v_resultado;
   EXCEPTION
      WHEN OTHERS THEN
         RETURN v_resultado;
   END FN_CTR_PROGRAMA;

   /*
      23-12-2024  v1.0  LReyes
      Verifica si el Programa parametrizado aún continúa en ejecución como JOB concurrente.
   */ 
   FUNCTION FN_JOB_EN_EJECUCION (
      p_job_name  IN  VARCHAR2
   )
   RETURN VARCHAR2
   IS
      v_resultado VARCHAR2(2) := 'NO';
   BEGIN
      SELECT 'SI'
      INTO v_resultado
      FROM dba_scheduler_running_jobs
      WHERE job_name = p_job_name
        AND ROWNUM = 1;

      RETURN v_resultado;
   EXCEPTION
      WHEN OTHERS THEN
         RETURN v_resultado;
   END FN_JOB_EN_EJECUCION;

   /*
      25-02-2025  v1.0  LReyes
      Evalúa si algún Programa Paralelo del Proceso parametrizado está en ejecución.
      Se usa también en el Forms GPPROFIN.
   */
   FUNCTION FU_OBT_PRO_EJE_PARALELO (
      p_cod_proceso IN ge_procesos_dep.cod_proceso%TYPE
   )
   RETURN VARCHAR2
   IS
      v_resultado VARCHAR2(50) := NULL;
   BEGIN
      SELECT '[' || det.nro_orden || '] ' || det.cod_programa
      INTO v_resultado
      FROM ge_procesos_det det,
           ge_procesos_dep dep
      WHERE det.cod_proceso = dep.cod_proceso
        AND det.cod_programa = dep.cod_programa
        AND dep.cod_proceso = p_cod_proceso
        AND dep.tipo = 'P'
        AND det.activo = 'S'
        AND det.hor_fin IS NULL
        AND det.error IS NOT NULL
        AND det.error = c_msj_PRO_P_EN_EJECUCION
      ORDER BY nro_orden ASC
      FETCH FIRST 1 ROW ONLY;

      RETURN v_resultado;
   EXCEPTION
      WHEN OTHERS THEN
         RETURN v_resultado;
   END FU_OBT_PRO_EJE_PARALELO;

   /*
      13-02-2025  v1.0  LReyes
      Evalúa si algún Programa Paralelo del Proceso parametrizado ha finalizado en error.
      Se usa también en el Forms GPPROFIN.
   */
   FUNCTION FU_OBT_PRO_ERR_PARALELO (
      p_cod_proceso IN ge_procesos_dep.cod_proceso%TYPE
   )
   RETURN VARCHAR2
   IS
      v_resultado VARCHAR2(50) := NULL;
   BEGIN
      SELECT '[' || det.nro_orden || '] ' || det.cod_programa
      INTO v_resultado
      FROM ge_procesos_det det,
           ge_procesos_dep dep
      WHERE det.cod_proceso = dep.cod_proceso
        AND det.cod_programa = dep.cod_programa
        AND dep.cod_proceso = p_cod_proceso
        AND dep.tipo = 'P'
        AND det.activo = 'S'
        AND det.hor_fin IS NULL
        AND det.error IS NOT NULL
        AND det.error != c_msj_PRO_P_EN_EJECUCION
      ORDER BY nro_orden ASC
      FETCH FIRST 1 ROW ONLY;

      RETURN v_resultado;
   EXCEPTION
      WHEN OTHERS THEN
         RETURN v_resultado;
   END FU_OBT_PRO_ERR_PARALELO;

   /*
      29-01-2025  v1.0  LReyes
      Evalúa si el error parametrizado desactiva la posibilidad de paralelismo del Programa parametrizado.
   */ 
   FUNCTION FU_JOB_SIN_PARALELISMO (
      p_cod_proceso  IN ge_err_pro_paralelos.cod_proceso%TYPE,
      p_cod_programa IN ge_err_pro_paralelos.cod_programa%TYPE,
      p_error        IN VARCHAR2
   )
   RETURN VARCHAR2
   IS
      v_resultado VARCHAR2(2) := 'SI';
   BEGIN
      IF p_error IS NULL THEN
         RETURN 'NO';
      END IF;

      SELECT 'NO'
      INTO v_resultado
      FROM ge_err_pro_paralelos
      WHERE cod_proceso = p_cod_proceso
        AND ( cod_programa = p_cod_programa
              OR cod_programa = 'TODOS' )
        AND ( p_error LIKE '%'||error||'%'
              OR error = 'TODOS' )
        AND activo = 'S'
        AND ROWNUM = 1;

      RETURN v_resultado;
   EXCEPTION
      WHEN OTHERS THEN
         RETURN v_resultado;
   END FU_JOB_SIN_PARALELISMO;
   
   /*
      30-03-2026  v1.0  fdavalos
      OBJETIVO: Obtener hora para el usuario del cierre.
   */
   FUNCTION FU_OBT_HORA (
      p_cod_usuario IN VARCHAR2,
      p_seq_hora    IN VARCHAR2,
      p_caracter    IN VARCHAR2
     )
   RETURN VARCHAR2
   IS
    v_hora        ge_movimientos.hora%type;
    v_nro_sec     number;
    v_nro_hor     number;
    v_ind_usuario number;

  BEGIN
    IF upper(substr(p_cod_usuario, -1)) = p_caracter THEN
      v_ind_usuario := 0;
    ELSE
      v_ind_usuario := substr(p_cod_usuario, -1);
    END IF;

    IF v_ind_usuario > 0 THEN
      v_nro_sec := fue_obt_sig_secuencia(p_seq_hora || v_ind_usuario);
    ELSIF v_ind_usuario = 0 THEN
      v_nro_sec := fue_obt_sig_secuencia(p_seq_hora);
    END IF;

    v_nro_hor := MOD(v_nro_sec, 86400);

    v_hora := TO_CHAR(trunc(v_nro_hor / 3600), 'FM9900') || ':' ||
              TO_CHAR(TRUNC(MOD(v_nro_hor, 3600) / 60), 'FM00') || ':' ||
              TO_CHAR(MOD(v_nro_hor, 60), 'FM00');

    RETURN v_hora;
  END FU_OBT_HORA;
   
   /*
      30-03-2026  v1.0  fdavalos
      OBJETIVO: Obtener movimiento para el usuario del cierre.
   */
   FUNCTION FU_OBT_MOV_USER(
     p_tip_user    IN ba_cod_referencias.abreviatura%type,
     p_dominio     IN ba_cod_referencias.dominio%type,
     p_can_user    IN NUMBER,
     p_seq_usuario IN VARCHAR2
     )
   RETURN VARCHAR2
   IS
    v_nro_sec  number;
    v_can_user number;
    v_nro_user number;
    v_user     ba_usuarios.cod_usuario%type;

  BEGIN
 

    v_nro_sec  := FUE_OBT_SIG_SECUENCIA(p_seq_usuario);    
    v_nro_user := mod(v_nro_sec, p_can_user);
    v_user     := IT.FUE_OBT_VAL_USER_DOMINIO(p_dominio,
                                              v_nro_user,
                                              p_tip_user);
    RETURN v_user;
  END FU_OBT_MOV_USER;

   /*
      23-12-2024  v1.0  LReyes
      Ejecuta queries de observación de datos y registra sus resultados en la tabla de log GE_PRO_PROGRAMAS_LOG.
      A fines de DEBUG y Pruebas Comparativas, se ejecuta este sp ANTES de la ejecución del Programa.
      (!) NOTA: NO SE EXPONE ESTE PROCEDIMIENTO EN EL PKG SPEC A FIN DE MANTENERLO PRIVADO AL BODY (!)
   */
   PROCEDURE PR_DBG_ANTES
   IS
   BEGIN
      --- Solo registrar al configurar nivel de log DEBUG o TRACE
      IF vg_log_level IN (c_log_DEBUG, c_log_TRACE)
         AND 'SI' = pag_cie.FN_VER_DEPENDENCIA(vg_cod_proceso, vg_cod_programa, 'D') THEN
         --- PRODUCCIÓN
         NULL;
         --- DESARROLLO
         ----PRG_DESA_DEBUG_ANTES; -- (!) NOTA: ESTE SP SÓLO DEBE EXISTIR EN DESARROLLO (!)
      END IF;
   END PR_DBG_ANTES;

   /*
      23-12-2024  v1.0  LReyes
      Ejecuta queries de observación de datos y registra sus resultados en la tabla de log GE_PRO_PROGRAMAS_LOG.
      A fines de DEBUG y Pruebas Comparativas, se ejecuta este sp DESPUES de la ejecución del Programa.
      (!) NOTA: NO SE EXPONE ESTE PROCEDIMIENTO EN EL PKG SPEC A FIN DE MANTENERLO PRIVADO AL BODY (!)
   */
   PROCEDURE PR_DBG_DESPUES
   IS
   BEGIN
      --- Solo registrar al configurar nivel de log DEBUG o TRACE
      IF vg_log_level IN (c_log_DEBUG, c_log_TRACE)
         AND 'SI' = pag_cie.FN_VER_DEPENDENCIA(vg_cod_proceso, vg_cod_programa, 'D') THEN
         --- PRODUCCIÓN
         NULL;
         --- DESARROLLO
         ----PRG_DESA_DEBUG_DESPUES; -- (!) NOTA: ESTE SP SÓLO DEBE EXISTIR EN DESARROLLO (!)
      END IF;
   END PR_DBG_DESPUES;

   /*
      20-05-2026  v1.1  LReyes
      Encapsula la lógica de ejecución dinámica de cada Programa de un Proceso.
      Se controla la transacción y se registra: inicio, fin y mensajes de trazabilidad.
      Se generan los mensajes asociados a la ejecución dinámica ASYNC de programas.
   */
   PROCEDURE PR_EJE_PRO_PROGRAMA (
      p_cod_proceso  IN  NUMBER,
      p_nro_orden    IN  NUMBER,
      p_cod_programa IN  VARCHAR2,
      p_contexto     IN  VARCHAR2,
      p_log_level    IN  VARCHAR2,
      p_error        OUT VARCHAR2
   )
   IS
      v_sentencia   VARCHAR2(500);
      v_error       VARCHAR2(1000);
      v_hor_inicio  ge_procesos.hor_inicio%TYPE := TO_CHAR(SYSDATE, 'hh24:mi:ss');
      v_token       VARCHAR2(3000);
   BEGIN
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 1;

      PR_SET_PARAMETROS(p_cod_proceso, p_nro_orden, p_cod_programa, p_contexto, p_log_level);

      p_error := 'Call '||p_cod_programa;

      --- Se loguean mensajes de Debug ANTES de la ejecución del Programa
      ----PR_DBG_ANTES; --El DEBUG es sólo un apoyo con propósitos de Pruebas Comparativas en DESARROLLO

      --- Se marca el inicio real de la ejecución
      IF p_contexto = c_ctx_OCO_ASYNC THEN
         SELECT token
         INTO v_token
         FROM ge_pro_programas_async
         WHERE cod_proceso = p_cod_proceso
           AND nro_orden = p_nro_orden;

         UPDATE ge_pro_programas_async
         SET estado = 'RUNNING',
             fec_inicio = SYSTIMESTAMP,
             fec_modificacion = SYSTIMESTAMP
         WHERE cod_proceso = p_cod_proceso
           AND nro_orden = p_nro_orden;
      END IF;

      --- Actualizar hora inicio y usuario del proceso detalle
      UPDATE ge_procesos_det
      SET hor_inicio = v_hor_inicio,
          cod_usuario = USER,
          error = DECODE(p_contexto,
                         c_ctx_JOB_PARALELO, c_msj_PRO_P_EN_EJECUCION,
                         c_ctx_OCO, c_msj_OCO_EN_EJECUCION,
                         c_ctx_OCO_ASYNC, c_msj_OCO_EN_EJECUCION,
                         NULL)
      WHERE cod_proceso = p_cod_proceso
        AND nro_orden = p_nro_orden;
      COMMIT;

      PR_INS_LOG('(INICIO) '||p_cod_programa||' '||FU_OBT_ENTORNO, c_log_INFO, 'COMMIT');

      --- Los Programas Paralelos se demoran 2 segundos para garantizar que la sesión Secuencial detecte su inicio antes de continuar
      IF p_contexto = c_ctx_JOB_PARALELO THEN
         DBMS_SESSION.SLEEP(2);
      END IF;

      pae_cnf.g_programa := 'GPPROFIN'; -- se reasigna el valor para asegurar este dato

      --- Ejecutar el proceso en forma dinamica
      --- inicializo punto de rollback
      SAVEPOINT pro_ejecutado;
      --- Ejecutar el proceso en forma dinamica
      v_sentencia := 'BEGIN '||p_cod_programa|| '; END;';
      sql_util.ejecute_dml(v_sentencia, v_error);
      v_error := REPLACE(v_error, 'SQL_UTIL.EJECUTE_DML', '*');
      IF v_error IS NOT NULL THEN
         -- hago rollback de lo que hizo el proceso
         ROLLBACK TO SAVEPOINT pro_ejecutado;
         raise_application_error(-20022, 'Error durante la ejecución de '||p_cod_programa);
      END IF;

      PR_INS_LOG('(FIN) '||p_cod_programa, c_log_INFO, 'COMMIT');

      --- Se libera el recurso lógico cuando corresponde
      IF p_contexto = c_ctx_OCO_ASYNC THEN
         UPDATE ge_pro_programas_async
         SET estado = 'IDLE',
             cod_programa = NULL,
             token = NULL,
             job_nombre = NULL,
             fec_solicitud = NULL,
             fec_inicio = NULL,
             fec_fin = SYSTIMESTAMP,
             usu_solicitud = NULL,
             fec_modificacion = SYSTIMESTAMP,
             err_mensaje = NULL
         WHERE cod_proceso = p_cod_proceso
           AND nro_orden = p_nro_orden;

         INSERT INTO ge_pro_programas_outbox (
            id_evento, estado, cod_proceso, nro_orden,
            token, eje_estado, eje_mensaje, fec_insercion
         )
         VALUES (
            s_cep_outbox_id_evento.NEXTVAL, 'NEW', p_cod_proceso, p_nro_orden,
            v_token, 'FINISHED', 'Tarea finalizada Ok', SYSTIMESTAMP
         );

         PR_INS_LOG('UNLOCK exclusivo '||p_cod_proceso||' '||p_nro_orden||' '||FU_OBT_ENTORNO, c_log_INFO, 'AUTONOMOUS_TRANSACTION');
      END IF;

      --- Actualizar hora fin si termino con exito;
      UPDATE ge_procesos_det
      SET hor_fin = TO_CHAR(SYSDATE, 'hh24:mi:ss'),
          error = NULL
      WHERE cod_proceso = p_cod_proceso
        AND nro_orden = p_nro_orden;
      COMMIT;

      --- Se loguean mensajes de Debug DESPUES de la ejecución del Programa
      ----PR_DBG_DESPUES; --El DEBUG es sólo un apoyo con propósitos de Pruebas Comparativas en DESARROLLO

      p_error := NULL;
   EXCEPTION
      WHEN OTHERS THEN
         ROLLBACK;

         IF v_error IS NULL THEN
            v_error := SUBSTR(SQLERRM, 1, 500);
         END IF;

         p_error := v_error;
         PR_INS_LOG(p_error, c_log_ERROR, 'COMMIT');

         --- Se libera el recurso lógico cuando corresponde
         IF p_contexto = c_ctx_OCO_ASYNC THEN
            UPDATE ge_pro_programas_async
            SET estado = 'ERROR',
                cod_programa = NULL,
                token = NULL,
                job_nombre = NULL,
                fec_solicitud = NULL,
                fec_inicio = NULL,
                fec_fin = SYSTIMESTAMP,
                usu_solicitud = NULL,
                fec_modificacion = SYSTIMESTAMP,
                err_mensaje = v_error
            WHERE cod_proceso = p_cod_proceso
              AND nro_orden = p_nro_orden;

            INSERT INTO ge_pro_programas_outbox (
               id_evento, estado, cod_proceso, nro_orden,
               token, eje_estado, eje_mensaje, fec_insercion
            )
            VALUES (
               s_cep_outbox_id_evento.NEXTVAL, 'NEW', p_cod_proceso, p_nro_orden,
               v_token, 'ERROR', v_error, SYSTIMESTAMP
            );

            PR_INS_LOG('UNLOCK exclusivo EXCEPTION '||p_cod_proceso||' '||p_nro_orden||' '||FU_OBT_ENTORNO, c_log_INFO, 'AUTONOMOUS_TRANSACTION');
         END IF;

         UPDATE ge_procesos_det
         SET error = v_error
         WHERE cod_proceso = p_cod_proceso
           AND nro_orden = p_nro_orden;

         COMMIT;
   END PR_EJE_PRO_PROGRAMA;

   /*
      23-12-2024  v1.0  LReyes
      Detiene la ejecución del JOB concurrente de un Programa según COD_PROCESO y NRO_ORDEN.
   */ 
   PROCEDURE PR_JOB_STOP (
      p_cod_proceso IN NUMBER,
      p_nro_orden   IN NUMBER
   )
   IS
      v_job_name VARCHAR2(25) := FN_JOB_NOMBRAR(p_cod_proceso, p_nro_orden);
   BEGIN
      IF v_job_name IS NULL THEN
         RETURN;
      END IF;

      FOR rec IN ( SELECT job_name
                   FROM dba_scheduler_running_jobs
                   WHERE job_name = v_job_name )
      LOOP
         BEGIN
            DBMS_SCHEDULER.stop_job(job_name => rec.job_name);
            PR_AT_INS_LOG(p_cod_proceso, p_nro_orden, NULL, 'stop_job '||rec.job_name, c_log_INFO, 'PR_JOB_STOP', pag_cal.FU_OBT_FEC_ACTUAL(1));
         EXCEPTION
            WHEN OTHERS THEN
               PR_AT_INS_LOG(p_cod_proceso, p_nro_orden, NULL, 'stop_job '||rec.job_name||' EXCEPTION '||SQLERRM, c_log_ERROR, 'PR_JOB_STOP', pag_cal.FU_OBT_FEC_ACTUAL(1));
         END;
      END LOOP;
   END PR_JOB_STOP;

   /*
      23-12-2024  v1.0  LReyes
      Registra el mensaje de log en una transacción autónoma. 
   */
   PROCEDURE PR_AT_INS_LOG (
      p_cod_proceso  IN NUMBER,
      p_nro_orden    IN NUMBER,
      p_cod_programa IN VARCHAR2,
      p_mensaje      IN VARCHAR2,
      p_log_level    IN PLS_INTEGER,
      p_contexto     IN VARCHAR2,
      p_fecha        IN DATE
   )
   IS
      PRAGMA AUTONOMOUS_TRANSACTION;
   BEGIN
      -- Se registra el mensaje
      INSERT INTO ge_pro_programas_log (cod_proceso, nro_orden, cod_programa, mensaje, contexto, fecha, nivel)
      VALUES (p_cod_proceso, p_nro_orden, p_cod_programa, p_mensaje, p_contexto, pag_cal.FU_OBT_FEC_ACTUAL(1),
              DECODE(p_log_level,
                     c_log_TRACE, 'TRACE',
                     c_log_DEBUG, 'DEBUG',
                     c_log_INFO, 'INFO',
                     c_log_WARN, 'WARN',
                     c_log_ERROR, 'ERROR',
                     c_log_FATAL, 'FATAL',
                     'OFF'));
      COMMIT;
   END PR_AT_INS_LOG;

   /*
      23-12-2024  v1.0  LReyes
      Registra mensajes de log según nivel configurado.
   */
   PROCEDURE PR_INS_LOG (
      p_mensaje      IN VARCHAR2,
      p_log_level    IN PLS_INTEGER DEFAULT c_log_INFO,
      p_transaction  IN VARCHAR2 DEFAULT NULL
   )
   IS
   BEGIN
      -- Se ignora el mensaje si el log se encuentra Apagado o se intenta registrar un nivel menor al configurado
      IF vg_log_level = c_log_OFF OR p_log_level < vg_log_level THEN
         RETURN;
      END IF;

      -- Si el mensaje se desea registrar como transacción autónoma se pasa y se termina
      IF p_transaction = 'AUTONOMOUS_TRANSACTION' THEN
         PR_AT_INS_LOG(vg_cod_proceso, vg_nro_orden, vg_cod_programa, p_mensaje, p_log_level, vg_contexto, pag_cal.FU_OBT_FEC_ACTUAL(1));
         RETURN;
      END IF;

      -- Se registra el mensaje
      INSERT INTO ge_pro_programas_log (cod_proceso, nro_orden, cod_programa, mensaje, contexto, fecha, nivel)
      VALUES (vg_cod_proceso, vg_nro_orden, vg_cod_programa, p_mensaje, vg_contexto, pag_cal.FU_OBT_FEC_ACTUAL(1),
              DECODE(p_log_level,
                             c_log_TRACE, 'TRACE',
                             c_log_DEBUG, 'DEBUG',
                             c_log_INFO, 'INFO',
                             c_log_WARN, 'WARN',
                             c_log_ERROR, 'ERROR',
                             c_log_FATAL, 'FATAL',
                             'OFF'));

      -- Se ejecuta el COMMIT sólo si se indica que el mensaje puede confirmar la transacción actual
      IF p_transaction = 'COMMIT' THEN
         COMMIT;
      END IF;
   END PR_INS_LOG;

   /*
      23-12-2024  v1.0  LReyes
      Setea los valores configurados en la base de datos para el uso del package.
   */ 
   PROCEDURE PR_SET_PARAMETROS (
      p_cod_proceso  IN NUMBER   DEFAULT NULL,
      p_nro_orden    IN NUMBER   DEFAULT NULL,
      p_cod_programa IN VARCHAR2 DEFAULT NULL,
      p_contexto     IN VARCHAR2 DEFAULT NULL,
      p_log_level    IN VARCHAR2 DEFAULT 'INFO'
   )
   IS
   BEGIN
      vg_cod_proceso  := p_cod_proceso;   
      vg_nro_orden    := p_nro_orden;
      vg_cod_programa := p_cod_programa;
      vg_contexto     := p_contexto;

      vg_log_level := CASE
                         WHEN p_log_level IN ('0', 'OFF')   THEN c_log_OFF
                         WHEN p_log_level IN ('1', 'TRACE') THEN c_log_TRACE
                         WHEN p_log_level IN ('2', 'DEBUG') THEN c_log_DEBUG
                         WHEN p_log_level IN ('3', 'INFO')  THEN c_log_INFO
                         WHEN p_log_level IN ('4', 'WARN')  THEN c_log_WARN
                         WHEN p_log_level IN ('5', 'ERROR') THEN c_log_ERROR
                         WHEN p_log_level IN ('6', 'FATAL') THEN c_log_FATAL
                         ELSE -1
                      END;
      IF vg_log_level = -1 THEN
         vg_log_level := c_log_INFO;
         PR_INS_LOG('Nivel de log default ''INFO'' seteado. El valor configurado en ''PAG_CIE_LOG_LEVEL'' no es válido', c_log_INFO, 'AUTONOMOUS_TRANSACTION');
      END IF;
   END PR_SET_PARAMETROS;

   /*
      27-01-2026  v1.0  LReyes
      Encapsula la lógica de ejecución dinámica de cada Programa de un Proceso. Versión OCO -Operational Closure Orchestrator-
      Para la orquestación desacoplada del servicio OCO se agregaron candados lógicos de mutua exclusión.
   */
   PROCEDURE PR_EJE_TAREA_OCO (
      p_cod_proceso  IN  NUMBER,                  -- desde OCO, process legacyId
      p_nro_orden    IN  NUMBER,                  -- desde OCO, task legacyId
      p_cod_programa IN  VARCHAR2,                -- desde OCO, source
      p_contexto     IN  VARCHAR2 DEFAULT 'OCO',  -- (para identificar y separar las ejecuciones de las de Bankitti)
      p_log_level    IN  VARCHAR2 DEFAULT 'INFO', -- (controlar desde el Backend la verbosidad de trazas en Oracle)
      p_error        OUT VARCHAR2                 -- (Excepciones controladas durante la ejecución. Si no hay error, devuelve NULL)
   )
   IS
      v_whitelist  PLS_INTEGER := 0;
      v_stop       PLS_INTEGER := 0;
      v_lock_desc  VARCHAR2(128);
      v_lock_id    VARCHAR2(128);
      v_candado    INTEGER := -1;
   BEGIN
      IF p_contexto != 'OCO' THEN
         RAISE_APPLICATION_ERROR(-20401, 'Contexto inválido! '||p_contexto);
      END IF;

      PR_SET_PARAMETROS(p_cod_proceso, p_nro_orden, p_cod_programa, p_contexto, p_log_level);

      --Whitelist para prevenir la Inyección de código dinámico
      SELECT COUNT(1)
      INTO v_whitelist
      FROM ge_procesos_det
      WHERE cod_proceso = p_cod_proceso
        AND nro_orden = p_nro_orden
        AND cod_programa = p_cod_programa;

      IF v_whitelist = 0 THEN
         PR_INS_LOG('Tarea desconocida! Se bloquea su ejecución.', c_log_DEBUG, 'AUTONOMOUS_TRANSACTION');
         RAISE_APPLICATION_ERROR(-20047, 'Tarea desconocida! Se bloquea su ejecución.');
      END IF;

      --Si algún Programa es ejecutado desde Bankitti, se bloquea la ejecución desde OCO
      SELECT COUNT(1)
      INTO v_stop
      FROM ge_procesos_det
      WHERE cod_proceso = p_cod_proceso
        AND activo = 'S'
        AND cod_usuario IS NOT NULL
        AND cod_usuario != USER
        AND ROWNUM = 1;

      IF v_stop != 0 THEN
         PR_INS_LOG('Orquestación externa a Oracle BLOQUEADA. El Proceso fue modificado por otro osuario', c_log_DEBUG, 'AUTONOMOUS_TRANSACTION');
         RAISE_APPLICATION_ERROR(-20094, 'Orquestación externa a Oracle BLOQUEADA. El Proceso fue modificado por otro osuario');
      END IF;

      -- Mecanismo de exclusión mutua, para el control global de concurrencia
      v_lock_desc := 'CIE$'||'PR_EJE_TAREA_OCO_'||p_cod_proceso||'_'||p_nro_orden;
      -- Se crea un identificador de bloqueo único
      DBMS_LOCK.ALLOCATE_UNIQUE_AUTONOMOUS(
         lockname        => v_lock_desc, 
         lockhandle      => v_lock_id,
         expiration_secs => (2*60*60)  -- 2 horas (desde la última operación de bloqueo) antes de ser depurado de SYS.DBMS_LOCK_ALLOCATED
      );
      -- Se intenta adquirir el bloqueo (modo exclusivo, timeout 0 segundos)
      v_candado := DBMS_LOCK.REQUEST(
         lockhandle        => v_lock_id,
         lockmode          => DBMS_LOCK.X_MODE,
         timeout           => 0,
         release_on_commit => FALSE
      );
      IF v_candado = 0 THEN
         PR_INS_LOG('LOCK exclusivo '||v_lock_desc||' '||FU_OBT_ENTORNO, c_log_INFO, 'AUTONOMOUS_TRANSACTION');
      ELSE
         PR_INS_LOG('RECHAZO LOCK exclusivo '||v_lock_desc||' '||FU_OBT_ENTORNO, c_log_DEBUG, 'AUTONOMOUS_TRANSACTION');
         RAISE_APPLICATION_ERROR(-20047, 'Existe otra sesión ejecutando la tarea '||p_nro_orden||' del proceso '||p_cod_proceso||'. No se permite su ejecución concurrente.');
      END IF;

      -- Se delega la ejecución dinámica del Programa al procedure existente
      PR_EJE_PRO_PROGRAMA (
         p_cod_proceso,
         p_nro_orden,
         p_cod_programa,
         p_contexto,
         p_log_level,
         p_error
      );
      IF p_error IS NOT NULL THEN
         RAISE_APPLICATION_ERROR(-20048, 'Ocurrió un error durante la ejecución dinámica de la Tarea: '|| p_cod_programa ||'. '|| p_error );
      END IF;

      -- Si obtuve el candado, libero el bloqueo
      IF v_candado = 0 THEN
         v_candado := DBMS_LOCK.RELEASE(v_lock_id);
         PR_INS_LOG('UNLOCK exclusivo '||v_lock_desc||' '||v_candado, c_log_INFO, 'AUTONOMOUS_TRANSACTION');
      END IF;
   EXCEPTION
      WHEN OTHERS THEN
         IF p_error IS NULL THEN
            p_error := SUBSTR(SQLERRM, 1, 500);
         END IF;

         -- Si obtuve el candado, libero el bloqueo
         IF v_candado = 0 THEN
            v_candado := DBMS_LOCK.RELEASE(v_lock_id);
            PR_INS_LOG('UNLOCK exclusivo en EXCEPTION '||v_lock_desc||' '||v_candado, c_log_DEBUG, 'AUTONOMOUS_TRANSACTION');
         END IF;

         PR_INS_LOG(p_error, c_log_ERROR, 'AUTONOMOUS_TRANSACTION');
   END PR_EJE_TAREA_OCO;

   /*
      15-09-2026  v1.0  LReyes
      PRIVATE (privada, solo PACKAGE BODY)
      Verificar si el Proceso parametrizado se encuentra habilitado para su orquestación externa a Oracle.
      Fallback seguro: si el parámetro no está configurado o hay error de parseo, se bloquea (retorna 'NO').
   */
   FUNCTION FN_OCO_PRO_HABILITADO (
      p_cod_proceso  IN  NUMBER
   )
   RETURN VARCHAR2
   IS
      v_lista     VARCHAR2(500);
      v_resultado VARCHAR2(2) := 'NO';
   BEGIN
      v_lista := fug_obt_pardinamico('OCO_CADENAS_HABILITADAS');

      IF v_lista IS NULL THEN
         RETURN 'NO';
      END IF;

      FOR reg IN (
         SELECT TO_NUMBER(TRIM(REGEXP_SUBSTR(v_lista, '[^,]+', 1, LEVEL))) AS cod_proceso
         FROM DUAL
         CONNECT BY REGEXP_SUBSTR(v_lista, '[^,]+', 1, LEVEL) IS NOT NULL
      )
      LOOP
         IF p_cod_proceso = reg.cod_proceso THEN
            v_resultado := 'SI';
            EXIT;
         END IF;
      END LOOP;

      RETURN v_resultado;
   EXCEPTION
      WHEN OTHERS THEN
         RETURN 'NO';
   END FN_OCO_PRO_HABILITADO;

   /*
      05-02-2026  v1.0  LReyes
      Verifica si el Proceso parametrizado se encuentra en orquestación externa a Oracle.
   */ 
   FUNCTION FN_OCO_EN_EJECUCION (
      p_cod_proceso  IN  NUMBER
   )
   RETURN VARCHAR2
   IS
      v_resultado VARCHAR2(2) := 'NO';
   BEGIN
      -- Solo procesos habilitados vía whitelist deben ser evaluados
      IF FN_OCO_PRO_HABILITADO(p_cod_proceso) != 'SI' THEN
         RETURN v_resultado;
      END IF;

      SELECT 'SI'
      INTO v_resultado
      FROM ge_procesos_det det
      WHERE det.cod_proceso = p_cod_proceso
        AND det.activo = 'S'
        AND det.hor_fin IS NULL
        AND det.error IS NOT NULL
        AND det.error = c_msj_OCO_EN_EJECUCION
        AND ROWNUM = 1;

      RETURN v_resultado;
   EXCEPTION
      WHEN OTHERS THEN
         RETURN v_resultado;
   END FN_OCO_EN_EJECUCION;

   /*
      12-02-2026  v1.0  LReyes
      Actualiza la tabla cabecera GE_PROCESOS desde la orquestación externa a Oracle.
   */
   PROCEDURE PR_UPD_PRO_OCO (
      p_cod_proceso IN  NUMBER,                -- desde OCO, process legacyId
      p_tipo        IN  VARCHAR2,              -- desde OCO, tipo de actualización INICIO ó ERROR ó FIN
      p_error_in    IN  VARCHAR2 DEFAULT NULL, -- desde OCO, error a registrar en caso de ERROR ó FIN
      p_error_out   OUT VARCHAR2               -- (Excepciones controladas durante la ejecución. Si no hay error, devuelve NULL)
   )
   IS
   BEGIN
      -- Solo permitir Procesos habilitados vía whitelist dinámica
      IF FN_OCO_PRO_HABILITADO(p_cod_proceso) != 'SI' THEN
         PR_AT_INS_LOG(
            p_cod_proceso, 0, 'PR_UPD_PRO_OCO',
            'El proceso no está habilitado para orquestación externa (OCO)',
            c_log_DEBUG, c_ctx_OCO, pag_cal.FU_OBT_FEC_ACTUAL(1)
         );
         RAISE_APPLICATION_ERROR(-20099, 'El proceso no está habilitado para orquestación externa (OCO)');
      END IF;

      -- Validar tipo de actualización
      IF p_tipo NOT IN ('INICIO', 'ERROR', 'FIN') THEN
         PR_AT_INS_LOG(
            p_cod_proceso, 0, 'PR_UPD_PRO_OCO',
            'Tipo de actualización no permitido para tabla cabecera',
            c_log_DEBUG, c_ctx_OCO, pag_cal.FU_OBT_FEC_ACTUAL(1)
         );
         RAISE_APPLICATION_ERROR(-20098, 'Tipo de actualización no permitido para tabla cabecera');
      END IF;

      -- Validar mensaje de error
      IF p_tipo = 'ERROR' AND p_error_in IS NULL THEN
         PR_AT_INS_LOG(
            p_cod_proceso, 0, 'PR_UPD_PRO_OCO',
            'La descripción de error no puede ser nula',
            c_log_DEBUG, c_ctx_OCO, pag_cal.FU_OBT_FEC_ACTUAL(1)
         );
         RAISE_APPLICATION_ERROR(-20097, 'La descripción de error no puede ser nula');
      END IF;

      p_error_out := NULL;

      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 1;

      -- INICIO
      IF p_tipo = 'INICIO' THEN
         UPDATE ge_procesos
         SET hor_inicio = TO_CHAR(SYSDATE,'HH24:MI:SS'),
             cod_usuario = USER,
             error = NULL
         WHERE cod_proceso = p_cod_proceso
           AND hor_inicio IS NULL;
      -- ERROR
      ELSIF p_tipo = 'ERROR' THEN
         UPDATE ge_procesos
         SET error = p_error_in
         WHERE cod_proceso = p_cod_proceso;
      -- FIN
      ELSIF p_tipo = 'FIN' THEN
         UPDATE ge_procesos
         SET hor_fin = TO_CHAR(SYSDATE,'HH24:MI:SS'),
             error = p_error_in
         WHERE cod_proceso = p_cod_proceso;
      END IF;

      IF SQL%ROWCOUNT = 0 THEN
         PR_AT_INS_LOG(
            p_cod_proceso, 0, 'PR_UPD_PRO_OCO',
            'No se actualizaron registros en tabla cabecera',
            c_log_DEBUG, c_ctx_OCO, pag_cal.FU_OBT_FEC_ACTUAL(1)
         );
         RAISE_APPLICATION_ERROR(-20096, 'No se actualizaron registros en tabla cabecera');
      END IF;
      
      PR_AT_INS_LOG(
         p_cod_proceso, 0, 'PR_UPD_PRO_OCO',
         'Tabla cabecera actualizada '||p_tipo||' Proceso '||p_cod_proceso,
         c_log_DEBUG, c_ctx_OCO, pag_cal.FU_OBT_FEC_ACTUAL(1)
      );

      COMMIT;
   EXCEPTION
      WHEN OTHERS THEN
         p_error_out := 'SQLCODE=' || SQLCODE || ' MSG=' || SQLERRM;
         PR_AT_INS_LOG(
            p_cod_proceso, 0, 'PR_UPD_PRO_OCO',
            'Error al actualizar tabla cabecera '||p_tipo||' Proceso '||p_cod_proceso||' EXCEPTION '||SQLCODE,
            c_log_ERROR, c_ctx_OCO, pag_cal.FU_OBT_FEC_ACTUAL(1)
         );
         ROLLBACK;
   END PR_UPD_PRO_OCO;

   /*
      02-03-2026  v1.0  LReyes
      Actualiza la tabla detalle GE_PROCESOS_DET desde la orquestación externa a Oracle.
   */
   PROCEDURE PR_UPD_PRO_DET_OCO (
      p_cod_proceso IN  NUMBER,                -- desde OCO, process legacyId
      p_nro_orden   IN  NUMBER,                -- desde OCO, task legacyId
      p_accion      IN  VARCHAR2,              -- desde OCO, acción SKIP ó ERRKILL
      p_error_in    IN  VARCHAR2 DEFAULT NULL, -- desde OCO, error a registrar en caso de ERRKILL
      p_error_out   OUT VARCHAR2               -- (Excepciones controladas durante la ejecución. Si no hay error, devuelve NULL)
   )
   IS
      v_stop  PLS_INTEGER := 0;
      v_token VARCHAR2(3000);
   BEGIN
      -- Solo permitir Procesos habilitados vía whitelist dinámica
      IF FN_OCO_PRO_HABILITADO(p_cod_proceso) != 'SI' THEN
         PR_AT_INS_LOG(
            p_cod_proceso, p_nro_orden, 'PR_UPD_PRO_DET_OCO',
            'El proceso no está habilitado para orquestación externa (OCO)',
            c_log_DEBUG, c_ctx_OCO, pag_cal.FU_OBT_FEC_ACTUAL(1)
         );
         RAISE_APPLICATION_ERROR(-20099, 'El proceso no está habilitado para orquestación externa (OCO)');
      END IF;

      -- Validar acción
      IF p_accion NOT IN ('SKIP', 'ERRKILL') THEN
         PR_AT_INS_LOG(
            p_cod_proceso, p_nro_orden, 'PR_UPD_PRO_DET_OCO',
            'Acción no permitida para tabla detalle',
            c_log_DEBUG, c_ctx_OCO, pag_cal.FU_OBT_FEC_ACTUAL(1)
         );
         RAISE_APPLICATION_ERROR(-20095, 'Acción no permitida para tabla detalle');
      END IF;

      -- Validar mensaje de error
      IF p_accion = 'ERRKILL' AND p_error_in IS NULL THEN
         PR_AT_INS_LOG(
            p_cod_proceso, p_nro_orden, 'PR_UPD_PRO_DET_OCO',
            'La descripción de error no puede ser nula',
            c_log_DEBUG, c_ctx_OCO, pag_cal.FU_OBT_FEC_ACTUAL(1)
         );
         RAISE_APPLICATION_ERROR(-20097, 'La descripción de error no puede ser nula');
      END IF;

      p_error_out := NULL;

      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 1;

      -- SKIP
      IF p_accion = 'SKIP' THEN
         --Si algún Programa es ejecutado desde Bankitti, se bloquea la ejecución desde OCO
         SELECT COUNT(1)
         INTO v_stop
         FROM ge_procesos_det
         WHERE cod_proceso = p_cod_proceso
           AND activo = 'S'
           AND cod_usuario IS NOT NULL
           AND cod_usuario != USER
           AND ROWNUM = 1;

         IF v_stop != 0 THEN
            PR_AT_INS_LOG(
               p_cod_proceso, p_nro_orden, 'PR_UPD_PRO_DET_OCO',
               'Orquestación externa a Oracle BLOQUEADA. El Proceso fue modificado por otro osuario',
               c_log_DEBUG, c_ctx_OCO, pag_cal.FU_OBT_FEC_ACTUAL(1)
            );
            RAISE_APPLICATION_ERROR(-20094, 'Orquestación externa a Oracle BLOQUEADA. El Proceso fue modificado por otro osuario');
         END IF;

         UPDATE ge_procesos_det
         SET hor_inicio = TO_CHAR(SYSDATE,'HH24:MI:SS'),
             hor_fin = TO_CHAR(SYSDATE,'HH24:MI:SS'),
             cod_usuario = USER,
             error = NVL(p_error_in, error)
         WHERE cod_proceso = p_cod_proceso
           AND nro_orden = p_nro_orden
           AND activo = 'S'
           AND obligatorio = 'N';
      -- ERROR
      ELSIF p_accion = 'ERRKILL' THEN
         --- Se recupera el token de la última ejecución antes de liberar el recurso lógico
         BEGIN
            SELECT token
            INTO v_token
            FROM ge_pro_programas_async
            WHERE cod_proceso = p_cod_proceso
              AND nro_orden = p_nro_orden;
         EXCEPTION
            WHEN OTHERS THEN
               v_token := NULL;
         END;

         --- Solo se libera el recurso lógico y se genera el mensaje si existe token registrado
         IF v_token IS NOT NULL THEN
            UPDATE ge_pro_programas_async
            SET estado = 'ERROR',
                cod_programa = NULL,
                token = NULL,
                job_nombre = NULL,
                fec_solicitud = NULL,
                fec_inicio = NULL,
                fec_fin = SYSTIMESTAMP,
                usu_solicitud = NULL,
                fec_modificacion = SYSTIMESTAMP,
                err_mensaje = p_error_in
            WHERE cod_proceso = p_cod_proceso
              AND nro_orden = p_nro_orden;

            INSERT INTO ge_pro_programas_outbox (
               id_evento, estado, cod_proceso, nro_orden,
               token, eje_estado, eje_mensaje, fec_insercion
            )
            VALUES (
               s_cep_outbox_id_evento.NEXTVAL, 'NEW', p_cod_proceso, p_nro_orden,
               v_token, 'ERROR', p_error_in, SYSTIMESTAMP
            );

            PR_INS_LOG('UNLOCK exclusivo KILL SESSION '||p_cod_proceso||' '||p_nro_orden||' '||FU_OBT_ENTORNO, c_log_INFO, 'AUTONOMOUS_TRANSACTION');
         END IF;

         UPDATE ge_procesos_det
         SET error = p_error_in
         WHERE cod_proceso = p_cod_proceso
           AND nro_orden = p_nro_orden
           AND activo = 'S';
      END IF;

      IF SQL%ROWCOUNT = 0 THEN
         PR_AT_INS_LOG(
            p_cod_proceso, p_nro_orden, 'PR_UPD_PRO_DET_OCO',
            'No se actualizaron registros',
            c_log_DEBUG, c_ctx_OCO, pag_cal.FU_OBT_FEC_ACTUAL(1)
         );
         RAISE_APPLICATION_ERROR(-20096, 'No se actualizaron registros');
      END IF;

      PR_AT_INS_LOG(
         p_cod_proceso, p_nro_orden, 'PR_UPD_PRO_DET_OCO',
         'Tabla detalle actualizada '||p_accion||' Proceso '||p_cod_proceso||' Tarea '||p_nro_orden||' '||FU_OBT_ENTORNO,
         c_log_DEBUG, c_ctx_OCO, pag_cal.FU_OBT_FEC_ACTUAL(1)
      );

      COMMIT;
   EXCEPTION
      WHEN OTHERS THEN
         p_error_out := 'SQLCODE=' || SQLCODE || ' MSG=' || SQLERRM;
         PR_AT_INS_LOG(
            p_cod_proceso, p_nro_orden, 'PR_UPD_PRO_DET_OCO',
            'Error al actualizar tabla detalle '||p_accion||' Proceso '||p_cod_proceso||' Tarea '||p_nro_orden||' '||FU_OBT_ENTORNO||' EXCEPTION '||SQLCODE,
            c_log_ERROR, c_ctx_OCO, pag_cal.FU_OBT_FEC_ACTUAL(1)
         );
         ROLLBACK;
   END PR_UPD_PRO_DET_OCO;

   /*
      15-05-2026  v1.0  LReyes
      Encapsula la lógica de ejecución dinámica ASYNC de cada Programa de un Proceso. Versión OCO -Operational Closure Orchestrator-
      Para la orquestación desacoplada del servicio OCO se implementa la Tabla de Control GE_PRO_PROGRAMAS_ASYNC como soporte en la gestión de Jobs.
      El row-level lock de fila única elimina race conditions y garantiza exclusión mutua, manteniendo la concurrencia entre programas distintos.
   */
   PROCEDURE PR_EJE_TAREA_OCO_ASYNC (
      p_cod_proceso  IN  NUMBER,                        -- desde OCO, process legacyId
      p_nro_orden    IN  NUMBER,                        -- desde OCO, task legacyId
      p_cod_programa IN  VARCHAR2,                      -- desde OCO, source
      p_token        IN  VARCHAR2,                      -- desde OCO, información codifica para trazar la ejecución hasta el evento de finalización
      p_contexto     IN  VARCHAR2 DEFAULT 'OCO_ASYNC',  -- (para identificar y separar las ejecuciones de las de Bankitti)
      p_log_level    IN  VARCHAR2 DEFAULT 'INFO',       -- (controlar desde el Backend la verbosidad de trazas en Oracle)
      p_error        OUT VARCHAR2                       -- (Excepciones controladas durante la ejecución. Si no hay error, devuelve NULL)
   )
   IS
      v_whitelist         PLS_INTEGER := 0;
      v_stop              PLS_INTEGER := 0;
      v_estado            VARCHAR2(20 BYTE);
      v_current_job_name  VARCHAR2(30);
      v_job_name          VARCHAR2(30);
      v_fec_solicitud     TIMESTAMP;
      v_running_count     PLS_INTEGER := 0;
   BEGIN
      IF p_contexto != 'OCO_ASYNC' THEN
         RAISE_APPLICATION_ERROR(-20401, 'Contexto inválido! '||p_contexto);
      END IF;

      PR_SET_PARAMETROS(p_cod_proceso, p_nro_orden, p_cod_programa, p_contexto, p_log_level);

      --Whitelist para prevenir la Inyección de código dinámico
      SELECT COUNT(1)
      INTO v_whitelist
      FROM ge_procesos_det
      WHERE cod_proceso = p_cod_proceso
        AND nro_orden = p_nro_orden
        AND cod_programa = p_cod_programa
        AND activo = 'S';

      IF v_whitelist = 0 THEN
         PR_INS_LOG('Tarea desconocida! Se bloquea su ejecución.', c_log_DEBUG, 'AUTONOMOUS_TRANSACTION');
         RAISE_APPLICATION_ERROR(-20047, 'Tarea desconocida! Se bloquea su ejecución.');
      END IF;

      --Si algún Programa es ejecutado desde Bankitti, se bloquea la ejecución desde OCO
      SELECT COUNT(1)
      INTO v_stop
      FROM ge_procesos_det
      WHERE cod_proceso = p_cod_proceso
        AND activo = 'S'
        AND cod_usuario IS NOT NULL
        AND cod_usuario != USER
        AND ROWNUM = 1;

      IF v_stop != 0 THEN
         PR_INS_LOG('Orquestación externa a Oracle BLOQUEADA. El Proceso fue modificado por otro osuario', c_log_DEBUG, 'AUTONOMOUS_TRANSACTION');
         RAISE_APPLICATION_ERROR(-20094, 'Orquestación externa a Oracle BLOQUEADA. El Proceso fue modificado por otro osuario');
      END IF;

      --Se asegura la existencia de la fila de control. El registro representa "el recurso lógico protegido" (NO representa su ejecución)
      --Estrategia de descubrimiento dinámico (la fila se crea la primera vez que aparece una tarea y persiste para futuras ejecuciones)
      BEGIN
         INSERT INTO ge_pro_programas_async (cod_proceso, nro_orden, estado, fec_modificacion)
         VALUES (p_cod_proceso, p_nro_orden, 'IDLE', SYSTIMESTAMP);
      EXCEPTION
         WHEN DUP_VAL_ON_INDEX THEN
            NULL;
      END;

      --LOCK TRANSACCIONAL con FOR UPDATE NOWAIT para garantizar: exclusión mutua sin race conditions
      BEGIN
         SELECT estado, job_nombre, fec_solicitud
         INTO v_estado, v_current_job_name, v_fec_solicitud
         FROM ge_pro_programas_async
         WHERE cod_proceso = p_cod_proceso
           AND nro_orden = p_nro_orden
         FOR UPDATE NOWAIT;
      EXCEPTION
         WHEN OTHERS THEN
            IF SQLCODE = -54 THEN
               PR_INS_LOG('Existe otra sesión ejecutando la tarea '||p_nro_orden||' del proceso '||p_cod_proceso||'. No se permite su ejecución concurrente. '||FU_OBT_ENTORNO, c_log_DEBUG, 'AUTONOMOUS_TRANSACTION');
               RAISE_APPLICATION_ERROR(-20147, 'Existe otra sesión ejecutando la tarea '||p_nro_orden||' del proceso '||p_cod_proceso||'. No se permite su ejecución concurrente.');
            ELSE
               RAISE;
            END IF;
      END;

      --Detección de estado huérfano para la recuperación automática del recurso
      --Caso: RUNNING    Pero: el JOB ya no existe por kill session o stop_job
      --Caso: REQUESTED  Pero: el planificador no inició la ejecución del worker por scheduler desactivado o saturación extrema
      IF v_estado = 'RUNNING' OR (v_estado = 'REQUESTED' AND NVL(v_fec_solicitud, SYSTIMESTAMP) < SYSTIMESTAMP - INTERVAL '1' MINUTE) THEN
         SELECT COUNT(1)
         INTO v_running_count
         FROM dba_scheduler_running_jobs
         WHERE job_name = v_current_job_name
           AND ROWNUM = 1;

         IF v_running_count = 0 THEN
            UPDATE ge_pro_programas_async
            SET estado = 'IDLE',
                cod_programa = NULL,
                token = NULL,
                job_nombre = NULL,
                fec_solicitud = NULL,
                fec_inicio = NULL,
                fec_fin = NULL,
                usu_solicitud = NULL,
                fec_modificacion = SYSTIMESTAMP,
                err_mensaje = 'Estado recuperado automáticamente'
            WHERE cod_proceso = p_cod_proceso
              AND nro_orden = p_nro_orden;

            v_estado := 'IDLE';
            PR_INS_LOG('UNLOCK exclusivo RECOVERY '||p_cod_proceso||' '||p_nro_orden||' '||FU_OBT_ENTORNO, c_log_INFO, 'AUTONOMOUS_TRANSACTION');
         END IF;
      END IF;

      --Validación final de concurrencia
      IF v_estado IN ('RUNNING', 'REQUESTED') THEN
         PR_INS_LOG('Existe otra sesión ejecutando la tarea '||p_nro_orden||' del proceso '||p_cod_proceso||'. No se permite su ejecución concurrente. '||FU_OBT_ENTORNO, c_log_DEBUG, 'AUTONOMOUS_TRANSACTION');
         RAISE_APPLICATION_ERROR(-20147, 'Existe otra sesión ejecutando la tarea '||p_nro_orden||' del proceso '||p_cod_proceso||'. No se permite su ejecución concurrente.');
      END IF;

      --Se nombra el Job
      v_job_name := FN_JOB_NOMBRAR(p_cod_proceso, p_nro_orden);

      --Se reserva la ejecución con REQUESTED para rechazar intentos de ejecución concurrentes
      UPDATE ge_pro_programas_async
      SET estado = 'REQUESTED',
          cod_programa = p_cod_programa,
          token = p_token,
          job_nombre = v_job_name,
          fec_solicitud  = SYSTIMESTAMP,
          fec_inicio = NULL,
          fec_fin = NULL,
          usu_solicitud = USER,
          fec_modificacion = SYSTIMESTAMP,
          err_mensaje = NULL
      WHERE cod_proceso = p_cod_proceso
        AND nro_orden = p_nro_orden;

      PR_INS_LOG('LOCK exclusivo '||p_cod_proceso||' '||p_nro_orden||' '||FU_OBT_ENTORNO, c_log_INFO, 'AUTONOMOUS_TRANSACTION');

      --Se crea el Job programando su inicio inmediato
      DBMS_SCHEDULER.CREATE_JOB (
         job_name        => v_job_name,
         start_date      => SYSTIMESTAMP,
         repeat_interval => NULL,
         auto_drop       => TRUE,
         job_type        => 'PLSQL_BLOCK',
         enabled         => TRUE,
         job_action      => 'DECLARE v_error VARCHAR2(1000); BEGIN it.pag_cie.PR_EJE_PRO_PROGRAMA('||p_cod_proceso||', '||p_nro_orden||', '''||REPLACE(p_cod_programa, CHR(39), CHR(39)||CHR(39))||''', '''||p_contexto||''', '''||p_log_level||''', v_error); END;',
         comments        => 'Ejecución dinámica asíncrona desde orquestación externa a Oracle'
      );

      --Se realiza la confirmación al final para evitar ventanas de race condition
      COMMIT;

   EXCEPTION
      WHEN OTHERS THEN
         IF p_error IS NULL THEN
            p_error := SUBSTR(SQLERRM, 1, 500);
         END IF;

         ROLLBACK;

         PR_INS_LOG(p_error, c_log_ERROR, 'AUTONOMOUS_TRANSACTION');
   END PR_EJE_TAREA_OCO_ASYNC;

BEGIN
   PR_SET_PARAMETROS;
END PAG_CIE;

