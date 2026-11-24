CREATE OR REPLACE PACKAGE BODY IT.PAG_CRC
AS
    ----------------------------------------------------------------------------
    -- Orquestador CRC desacoplado (NOR-508)
    ----------------------------------------------------------------------------
    -- Nota de estilo:
    -- - Convención: procedimientos públicos en MAYÚSCULAS (PRC_*), helpers en
    --   minúsculas con prefijo fn_/prc_/log_.
    -- - Estados: en tablas se usa 'INICIO'|'OK'|'WARNING'|'ERROR'.
    --   A nivel consolidado de controles se usa 'OK'|'WARN'|'ERROR' (interno).
    ----------------------------------------------------------------------------

    ----------------------------------------------------------------------------
    -- PR_INI_MODULOS: Inicializa la aplicación y establece el código de módulo.
    ----------------------------------------------------------------------------
    PROCEDURE pr_ini_modulos
    IS
    BEGIN
        PRE_INI_APLICACION;
        PAE_CNF.G_COD_MODULO := 1;
    END pr_ini_modulos;

    ----------------------------------------------------------------------------
    -- PR_ABRIR_MODULOS: Cambia el estado del módulo a abierto.
    ----------------------------------------------------------------------------
    PROCEDURE pr_abrir_modulos
    IS
    BEGIN
        UPDATE BA_MODULOS
           SET ESTADO = 2
		WHERE COD_MODULO <> 2;

        COMMIT;
    END pr_abrir_modulos;

    ----------------------------------------------------------------------------
    -- PR_CERRAR_MODULOS: Cambia el estado del módulo a cerrado.
    ----------------------------------------------------------------------------
    PROCEDURE pr_cerrar_modulos
    IS
    BEGIN
        UPDATE BA_MODULOS
           SET ESTADO = 4
		WHERE COD_MODULO <> 2;

        COMMIT;
    END pr_cerrar_modulos;

    ---------------------------------------------------------------------------
    -- Helpers generales
    ---------------------------------------------------------------------------

    FUNCTION fn_get_db_unique_name
        RETURN VARCHAR2
    IS
    BEGIN
        RETURN SYS_CONTEXT ('USERENV', 'DB_UNIQUE_NAME');
    END fn_get_db_unique_name;

    FUNCTION fn_get_pardinamico (p_param IN VARCHAR2)
        RETURN VARCHAR2
    IS
        v_val   VARCHAR2 (4000);
    BEGIN
        v_val := fug_obt_pardinamico (p_param);
        RETURN v_val;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END fn_get_pardinamico;

    -- OJO: esta función NO se usa dentro de SQL (ver log_step_fin)
    FUNCTION fn_fmt_hms (p_inicio IN TIMESTAMP, p_fin IN TIMESTAMP)
        RETURN VARCHAR2
    IS
        v_secs   NUMBER;
        v_h      NUMBER;
        v_m      NUMBER;
        v_s      NUMBER;
    BEGIN
        v_secs :=
            FLOOR (
                  (CAST (p_fin AS DATE) - CAST (p_inicio AS DATE))
                * 24
                * 60
                * 60);

        IF v_secs < 0
        THEN
            v_secs := 0;
        END IF;

        v_h := FLOOR (v_secs / 3600);
        v_m := FLOOR (MOD (v_secs, 3600) / 60);
        v_s := MOD (v_secs, 60);

        RETURN    LPAD (v_h, 2, '0')
               || ':'
               || LPAD (v_m, 2, '0')
               || ':'
               || LPAD (v_s, 2, '0');
    END fn_fmt_hms;

    FUNCTION fn_is_retryable (p_sqlcode IN NUMBER)
        RETURN BOOLEAN
    IS
    BEGIN
        RETURN p_sqlcode IN (-54,                    -- resource busy / NOWAIT
                             -60,                                  -- deadlock
                             -4021,                     -- lock object timeout
                             -3135,                 -- connection lost contact
                             -3113,    -- end-of-file on communication channel
                             -12541,
                             -12545,
                             -12514);
    END fn_is_retryable;

    ---------------------------------------------------------------------------
    -- Helper: fecha calendario (FinDía)
    ---------------------------------------------------------------------------
    FUNCTION fn_get_fecha_calendario
        RETURN DATE
    IS
    BEGIN
        RETURN TRUNC (PAG_CAL.FU_OBT_FEC_ACTUAL (1));
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END fn_get_fecha_calendario;

    ---------------------------------------------------------------------------
    -- Logging (autonomous)
    ---------------------------------------------------------------------------

    PROCEDURE log_step_ini (
        p_id_ejecucion    IN  NUMBER,
        p_fecha_proceso   IN  DATE,
        p_paso_orden      IN  NUMBER,
        p_subpaso_orden   IN  NUMBER,
        p_paso_cod        IN  VARCHAR2,
        p_paso_desc       IN  VARCHAR2,
        p_modo            IN  VARCHAR2,
        p_usuario         IN  VARCHAR2,
        p_db_unique       IN  VARCHAR2,
        p_db_allow        IN  VARCHAR2,
        p_db_prod         IN  VARCHAR2,
        o_id_log          OUT NUMBER
    )
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
        v_fecha_log DATE;
    BEGIN
        SELECT IT.S_GE_LOG_CRC_EJEC.NEXTVAL
          INTO o_id_log
          FROM DUAL;
    
        v_fecha_log := CASE
                         WHEN p_fecha_proceso IS NULL THEN NULL
                         ELSE TRUNC(p_fecha_proceso)
                       END;
    
        INSERT INTO IT.GE_LOG_CRC_EJEC (
            ID_LOG,
            ID_EJECUCION,
            FECHA_PROCESO,
            NOMBRE_PROCESO,
            PASO_ORDEN,
            SUBPASO_ORDEN,
            PASO_COD,
            PASO_DESC,
            ESTADO,
            FH_INICIO,
            DB_UNIQUE_NAME,
            DB_ALLOW_PARAM,
            DB_PROD_PARAM,
            MODO_EJECUCION,
            USUARIO_EJECUCION,
            USU_INSERCION,
            FEC_INSERCION,
            USU_MODIFICACION,
            FEC_MODIFICACION
        )
        VALUES (
            o_id_log,
            p_id_ejecucion,
            v_fecha_log,
            'CRC_DIARIO_DESACOPLE',
            p_paso_orden,
            p_subpaso_orden,
            p_paso_cod,
            p_paso_desc,
            'INICIO',
            SYSTIMESTAMP,
            p_db_unique,
            p_db_allow,
            p_db_prod,
            p_modo,
            p_usuario,
            SUBSTR(NVL(p_usuario, USER), 1, 10),
            SYSDATE,
            SUBSTR(NVL(p_usuario, USER), 1, 10),
            SYSDATE
        );
    
        COMMIT;
    END log_step_ini;

    PROCEDURE log_step_fin (p_id_log      IN NUMBER,
                            p_estado      IN VARCHAR2,
                            p_retcode     IN NUMBER,
                            p_retdesc     IN VARCHAR2,
                            p_err_code    IN VARCHAR2 DEFAULT NULL,
                            p_err_msg     IN VARCHAR2 DEFAULT NULL,
                            p_err_stack   IN CLOB DEFAULT NULL,
                            p_usuario     IN VARCHAR2 DEFAULT NULL)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;

        v_inicio    TIMESTAMP;
        v_dur_hms   VARCHAR2 (8);
    BEGIN
        SELECT FH_INICIO
          INTO v_inicio
          FROM IT.GE_LOG_CRC_EJEC
         WHERE ID_LOG = p_id_log
        FOR UPDATE;

        v_dur_hms := fn_fmt_hms (v_inicio, SYSTIMESTAMP);

        UPDATE IT.GE_LOG_CRC_EJEC
           SET ESTADO = p_estado,
               RETCODE = p_retcode,
               RETDESC = p_retdesc,
               FH_FIN = SYSTIMESTAMP,
               DURACION = v_dur_hms,
               ERR_CODE = p_err_code,
               ERR_MSG = p_err_msg,
               ERR_STACK = p_err_stack,
               USU_MODIFICACION = SUBSTR (NVL (p_usuario, USER), 1, 10),
               FEC_MODIFICACION = SYSDATE
         WHERE ID_LOG = p_id_log;

        COMMIT;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            NULL;
    END log_step_fin;

    PROCEDURE log_set_fecha_proceso (
        p_id_ejecucion   IN NUMBER,
        p_fecha_proceso  IN DATE,
        p_usuario        IN VARCHAR2 DEFAULT NULL
    )
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        UPDATE IT.GE_LOG_CRC_EJEC
           SET FECHA_PROCESO     = TRUNC(p_fecha_proceso),
               USU_MODIFICACION  = SUBSTR(NVL(p_usuario, USER), 1, 10),
               FEC_MODIFICACION  = SYSDATE
         WHERE ID_EJECUCION = p_id_ejecucion
           AND FECHA_PROCESO IS NULL;
    
        COMMIT;
    END log_set_fecha_proceso;
    
    ---------------------------------------------------------------------------
    -- Helper: resolver fecha de proceso (MANUAL/AUTO) + consistencia calendario
    -- - MANUAL: usa la fecha recibida
    -- - AUTO  : usa "anterior hábil a hoy" según PAG_CAL
    -- - Valida que FU_OBT_FEC_ACTUAL esté disponibilizado para la fecha final
    ---------------------------------------------------------------------------
    PROCEDURE prc_resolver_fecha_proceso (
        p_fecha_in        IN     DATE,
        p_modo            IN     VARCHAR2,
        p_cod_oficina     IN     BA_OFICINAS.COD_OFICINA%TYPE,
        o_fecha_proceso      OUT DATE,
        o_origen_fecha       OUT VARCHAR2,
        o_retcode            OUT NUMBER,
        o_retdesc            OUT VARCHAR2)
    IS
        v_fec_calendario   DATE;
        v_fecha_esperada   DATE;
        v_es_auto          BOOLEAN;
    BEGIN
        o_retcode := 0;
        o_retdesc := 'OK';

        v_es_auto :=
               (p_fecha_in IS NULL)
            OR (UPPER (NVL (p_modo, 'AUTO')) = 'AUTO');

        IF NOT v_es_auto
        THEN
            o_fecha_proceso := TRUNC (p_fecha_in);
            o_origen_fecha := 'MANUAL';
            RETURN;
        END IF;

        o_origen_fecha := 'AUTO';

        v_fecha_esperada :=
            TRUNC (
                PAG_CAL.FU_OBT_FEC_ANT_HAB (P_FECHA        => TRUNC (SYSDATE),
                                            P_COD_OFICINA  => p_cod_oficina,
                                            P_DIAS         => 1));

        v_fec_calendario := fn_get_fecha_calendario;

        IF v_fec_calendario IS NULL
        THEN
            o_retcode := 1;
            o_retdesc :=
                'AUTO: no se pudo obtener la fecha del calendario (PAG_CAL.FU_OBT_FEC_ACTUAL(1)).';
            RETURN;
        END IF;

        -- Regla final: la fecha a ejecutar debe ser exactamente la disponibilizada
        IF TRUNC (v_fec_calendario) <> TRUNC (v_fecha_esperada)
        THEN
            o_retcode := 1;
            o_retdesc :=
                   'Ejecución bloqueada: calendario inválido para CRC. '
                || 'Calendario='
                || TO_CHAR (TRUNC (v_fec_calendario), 'DD/MM/YYYY')
                || ' FechaProceso='
                || TO_CHAR (TRUNC (v_fecha_esperada), 'DD/MM/YYYY')
                || '. (FinDía debe estar disponibilizado para la fecha a ejecutar).';
            RETURN;
        END IF;

        o_fecha_proceso := TRUNC (v_fecha_esperada);
    EXCEPTION
        WHEN OTHERS
        THEN
            o_retcode := 1;
            o_retdesc := 'Error resolviendo fecha de proceso: ' || SQLERRM;
    END prc_resolver_fecha_proceso;

    ---------------------------------------------------------------------------
    -- Validaciones operativas FinDía / módulos
    ---------------------------------------------------------------------------

    PROCEDURE prc_validar_cierre_postcierre (o_retcode   OUT NUMBER,
                                             o_retdesc   OUT VARCHAR2)
    IS
        v_cnt   NUMBER := 0;
    BEGIN
        o_retcode := 0;
        o_retdesc := 'OK';

        SELECT COUNT (*)
          INTO v_cnt
          FROM GE_PROCESOS
         WHERE COD_PROCESO IN (11, 12) AND HOR_FIN IS NOT NULL;

        IF v_cnt <> 2
        THEN
            o_retcode := 1;
            o_retdesc :=
                'Ejecución bloqueada: FinDía no cerrado. Requiere GE_PROCESOS(11 y 12) con HOR_FIN informado.';
            RETURN;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            o_retcode := 1;
            o_retdesc :=
                   'Error validando cierre/post-cierre (GE_PROCESOS 11/12): '
                || SQLERRM;
    END prc_validar_cierre_postcierre;

    PROCEDURE prc_validar_modulos_cerrados (o_retcode   OUT NUMBER,
                                            o_retdesc   OUT VARCHAR2)
    IS
        v_cnt                      NUMBER := 0;
        v_cod_mod_conta   CONSTANT NUMBER := 2; -- CONTABILIDAD
    BEGIN
        o_retcode := 0;
        o_retdesc := 'OK';

        SELECT COUNT (*)
          INTO v_cnt
          FROM BA_MODULOS
         WHERE COD_MODULO <> v_cod_mod_conta AND NVL (ESTADO, 0) <> 4;

        IF v_cnt > 0
        THEN
            o_retcode := 1;
            o_retdesc :=
                'Ejecución bloqueada: existen módulos no cerrados (ESTADO<>4) en BA_MODULOS (excepto Contabilidad).';
            RETURN;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            o_retcode := 1;
            o_retdesc :=
                'Error validando módulos cerrados (BA_MODULOS): ' || SQLERRM;
    END prc_validar_modulos_cerrados;

    ---------------------------------------------------------------------------
    -- Lock: devuelve handle para liberar SIEMPRE
    ---------------------------------------------------------------------------
    PROCEDURE prc_lock_ejecucion (
        p_fecha_proceso IN  DATE,
        p_forzar        IN  CHAR,
        o_lockhandle    OUT VARCHAR2,
        o_retcode       OUT NUMBER,
        o_retdesc       OUT VARCHAR2
    )
    IS
        v_res  NUMBER;
        v_cnt  NUMBER;
    BEGIN
        o_retcode    := 0;
        o_retdesc    := 'OK';
        o_lockhandle := NULL;
    
        IF NVL(p_forzar, 'N') <> 'S' THEN
            SELECT COUNT(*)
              INTO v_cnt
              FROM IT.GE_LOG_CRC_EJEC
             WHERE FECHA_PROCESO = TRUNC(p_fecha_proceso)
               AND PASO_COD      = 'DISP_EXTRACTOR'
               AND ESTADO        = 'OK';
    
            IF v_cnt > 0 THEN
                o_retcode := 1;
                o_retdesc :=
                       'Ya existe una ejecución OK para la fecha '
                    || TO_CHAR(p_fecha_proceso,'DD/MM/YYYY')
                    || '. Use I_FORZAR=''S'' si desea re-ejecutar.';
                RETURN;
            END IF;
        END IF;
    
        DBMS_LOCK.ALLOCATE_UNIQUE(
            lockname   => 'CRC_ORQ_' || TO_CHAR(p_fecha_proceso, 'YYYYMMDD'),
            lockhandle => o_lockhandle
        );
    
        v_res := DBMS_LOCK.REQUEST(
            lockhandle        => o_lockhandle,
            lockmode          => DBMS_LOCK.X_MODE,
            timeout           => 0,
            release_on_commit => FALSE
        );
    
        IF v_res <> 0 THEN
            o_retcode := 1;
            o_retdesc :=
                   'Existe otra ejecución CRC en curso para la fecha '
                || TO_CHAR(p_fecha_proceso, 'DD/MM/YYYY')
                || '.';
            RETURN;
        END IF;
    
    EXCEPTION
        WHEN OTHERS THEN
            o_retcode := 1;
            o_retdesc := 'Error lock ejecución: ' || SQLERRM;
    END prc_lock_ejecucion;

    PROCEDURE prc_release_lock (
        p_lockhandle IN VARCHAR2
    )
    IS
        v_res NUMBER;
    BEGIN
        IF p_lockhandle IS NOT NULL THEN
            v_res := DBMS_LOCK.RELEASE(p_lockhandle);
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            NULL;
    END prc_release_lock;

    ---------------------------------------------------------------------------
    -- Paso: validar configuración
    ---------------------------------------------------------------------------
    PROCEDURE prc_obtener_config (o_retcode   OUT NUMBER,
                                  o_retdesc   OUT VARCHAR2)
    IS
        v_cnt   NUMBER;

        PROCEDURE fail (p_msg VARCHAR2)
        IS
        BEGIN
            o_retcode := 1;
            o_retdesc := p_msg;
        END;
    BEGIN
        o_retcode := 0;
        o_retdesc := 'OK';

        SELECT COUNT (*)
          INTO v_cnt
          FROM IT.GE_CRC_PASOS_ORQ
         WHERE ACTIVO = 'S';

        IF v_cnt = 0
        THEN
            fail ('No hay pasos activos en IT.GE_CRC_PASOS_ORQ.');
            RETURN;
        END IF;

        SELECT COUNT (*)
          INTO v_cnt
          FROM (  SELECT ORDEN
                    FROM IT.GE_CRC_PASOS_ORQ
                   WHERE ACTIVO = 'S'
                GROUP BY ORDEN
                  HAVING COUNT (*) > 1);

        IF v_cnt > 0
        THEN
            fail ('Configuración inválida: ORDEN duplicado en pasos (GE_CRC_PASOS_ORQ).');
            RETURN;
        END IF;

        SELECT COUNT (*)
          INTO v_cnt
          FROM (  SELECT COD_PASO
                    FROM IT.GE_CRC_PASOS_ORQ
                   WHERE ACTIVO = 'S'
                GROUP BY COD_PASO
                  HAVING COUNT (*) > 1);

        IF v_cnt > 0
        THEN
            fail ('Configuración inválida: COD_PASO duplicado en pasos (GE_CRC_PASOS_ORQ).');
            RETURN;
        END IF;

        SELECT COUNT (*)
          INTO v_cnt
          FROM IT.GE_CRC_PASOS_ORQ
         WHERE     ACTIVO = 'S'
               AND COD_PASO IN ('VALIDAR_ENTORNO',
                                'OBTENER_CONFIG',
                                'EJECUTAR_CRC',
                                'EJECUTAR_CONTROLES',
                                'DISP_EXTRACTOR');

        IF v_cnt <> 5
        THEN
            fail ('Faltan pasos obligatorios activos. Requeridos: VALIDAR_ENTORNO, OBTENER_CONFIG, EJECUTAR_CRC, EJECUTAR_CONTROLES, DISP_EXTRACTOR.');
            RETURN;
        END IF;

        SELECT COUNT (*)
          INTO v_cnt
          FROM IT.GE_CRC_PROCESOS_CFG
         WHERE ACTIVO = 'S';

        IF v_cnt = 0
        THEN
            fail ('No hay procesos CRC activos en IT.GE_CRC_PROCESOS_CFG.');
            RETURN;
        END IF;

        SELECT COUNT (*)
          INTO v_cnt
          FROM (  SELECT ORDEN
                    FROM IT.GE_CRC_PROCESOS_CFG
                   WHERE ACTIVO = 'S'
                GROUP BY ORDEN
                  HAVING COUNT (*) > 1);

        IF v_cnt > 0
        THEN
            fail ('Configuración inválida: ORDEN duplicado en procesos (GE_CRC_PROCESOS_CFG).');
            RETURN;
        END IF;

        SELECT COUNT (*)
          INTO v_cnt
          FROM IT.GE_CRC_PROCESOS_CFG
         WHERE     ACTIVO = 'S'
               AND (OBJETO_EJECUCION IS NULL OR TRIM (OBJETO_EJECUCION) IS NULL);

        IF v_cnt > 0
        THEN
            fail ('Configuración inválida: existen procesos activos sin OBJETO_EJECUCION.');
            RETURN;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            o_retcode := 1;
            o_retdesc := 'Error validando config: ' || SQLERRM;
    END prc_obtener_config;

    ---------------------------------------------------------------------------
    -- Paso 1: validar entorno
    ---------------------------------------------------------------------------
    PROCEDURE prc_validar_entorno (p_db_unique       IN     VARCHAR2,
                                   p_fecha_proceso   IN     DATE,
                                   o_retcode            OUT NUMBER,
                                   o_retdesc            OUT VARCHAR2,
                                   o_db_allow           OUT VARCHAR2,
                                   o_db_prod            OUT VARCHAR2)
    IS
        v_fec_calendario   DATE;
    BEGIN
        o_retcode := 0;
        o_retdesc := 'OK';
        o_db_allow := fn_get_pardinamico ('VAL_DBUNIQUE_CRC_ALLOW');
        o_db_prod := fn_get_pardinamico ('VAL_DBUNIQUE_CRC_PROD');

        IF o_db_prod IS NOT NULL AND p_db_unique = o_db_prod
        THEN
            o_retcode := 1;
            o_retdesc := 'Ejecución bloqueada: base productiva prohibida (' || o_db_prod || ')';
            RETURN;
        END IF;

        IF o_db_allow IS NOT NULL AND p_db_unique <> o_db_allow
        THEN
            o_retcode := 1;
            o_retdesc := 'Ejecución bloqueada: base no permitida. Actual=' || p_db_unique || ' Permitida=' || o_db_allow;
            RETURN;
        END IF;

        v_fec_calendario := fn_get_fecha_calendario;

        IF v_fec_calendario IS NULL
        THEN
            o_retcode := 1;
            o_retdesc := 'Ejecución bloqueada: no se pudo obtener la fecha del calendario (PAG_CAL.FU_OBT_FEC_ACTUAL(1)).';
            RETURN;
        END IF;

        IF TRUNC (v_fec_calendario) <> TRUNC (p_fecha_proceso)
        THEN
            o_retcode := 1;
            o_retdesc :=
                   'Ejecución bloqueada: calendario inválido para CRC. '
                || 'Calendario='
                || TO_CHAR (TRUNC (v_fec_calendario), 'DD/MM/YYYY')
                || ' FechaProceso='
                || TO_CHAR (TRUNC (p_fecha_proceso), 'DD/MM/YYYY')
                || '. (FinDía debe estar disponibilizado para la fecha a ejecutar).';
            RETURN;
        END IF;

        DECLARE
            v_rc     NUMBER;
            v_desc   VARCHAR2 (4000);
        BEGIN
            prc_validar_cierre_postcierre (v_rc, v_desc);

            IF v_rc <> 0
            THEN
                o_retcode := 1;
                o_retdesc := v_desc;
                RETURN;
            END IF;
        END;

        DECLARE
            v_rc     NUMBER;
            v_desc   VARCHAR2 (4000);
        BEGIN
            prc_validar_modulos_cerrados (v_rc, v_desc);

            IF v_rc <> 0
            THEN
                o_retcode := 1;
                o_retdesc := v_desc;
                RETURN;
            END IF;
        END;

        IF o_db_allow IS NULL
        THEN
            o_retcode := 0;
            o_retdesc := 'WARNING: parámetro VAL_DBUNIQUE_CRC_ALLOW no informado; ejecución no restringida por allow.';
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            o_retcode := 1;
            o_retdesc := 'Error validando entorno: ' || SQLERRM;
    END prc_validar_entorno;

    ---------------------------------------------------------------------------
    -- Paso: EJECUTAR_CONTROLES
    ---------------------------------------------------------------------------
    PROCEDURE prc_ejecutar_controles_det (p_id_ejecucion    IN     NUMBER,
                                          p_fecha_proceso   IN     DATE,
                                          p_usuario         IN     VARCHAR2,
                                          o_estado             OUT VARCHAR2,
                                          o_det_last           OUT VARCHAR2,
                                          o_errs               OUT NUMBER,
                                          o_warns              OUT NUMBER)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;

        v_cnt           NUMBER;
        v_sql           VARCHAR2 (4000);

        v_estado_ctrl   VARCHAR2 (10);
        v_retcode       NUMBER;
        v_retdesc       VARCHAR2 (1000);

        v_id_log_ctrl   NUMBER;
    BEGIN
        o_estado := 'OK';
        o_det_last := NULL;
        o_errs := 0;
        o_warns := 0;

        DELETE FROM IT.GE_CRC_CTRL_RESULTADOS_LOG
              WHERE     ID_EJECUCION = p_id_ejecucion
                    AND FECHA_PROCESO = TRUNC (p_fecha_proceso);

        FOR c IN (  SELECT ID_CTRL,
                           COD_PROC,
                           DESCRIPCION,
                           TABLA_DESTINO,
                           SQL_CONTROL,
                           NVL (MIN_REGISTROS, 0) AS MIN_REGISTROS,
                           NVL (CRITICO, 'N') AS CRITICO
                      FROM IT.GE_CRC_CTRL_RESULTADOS_CFG
                     WHERE ACTIVO = 'S'
                  ORDER BY ID_CTRL)
        LOOP
            v_cnt := NULL;
            v_estado_ctrl := 'OK';
            v_retcode := 0;
            v_retdesc := 'OK';

            BEGIN
                IF c.SQL_CONTROL IS NULL
                THEN
                    v_estado_ctrl := 'ERROR';
                    v_retcode := 1;
                    v_retdesc := 'Control sin SQL_CONTROL (ID_CTRL=' || c.ID_CTRL || ')';
                ELSE
                    v_sql := c.SQL_CONTROL;

                    EXECUTE IMMEDIATE v_sql
                        INTO v_cnt
                        USING TRUNC (p_fecha_proceso);

                    IF c.MIN_REGISTROS > 0
                    THEN
                        IF NVL (v_cnt, 0) >= c.MIN_REGISTROS
                        THEN
                            v_estado_ctrl := 'OK';
                            v_retcode := 0;
                            v_retdesc := 'OK | RES=' || NVL (TO_CHAR (v_cnt), 'NULL') || ' MIN=' || c.MIN_REGISTROS;
                        ELSE
                            IF c.CRITICO = 'S'
                            THEN
                                v_estado_ctrl := 'ERROR';
                                v_retcode := 1;
                            ELSE
                                v_estado_ctrl := 'WARNING';
                                v_retcode := 0;
                            END IF;

                            v_retdesc := 'FAIL | RES=' || NVL (TO_CHAR (v_cnt), 'NULL') || ' MIN=' || c.MIN_REGISTROS;
                        END IF;
                    ELSE
                        IF NVL (v_cnt, 0) = 0
                        THEN
                            v_estado_ctrl := 'OK';
                            v_retcode := 0;
                            v_retdesc := 'OK | RES=0 (esperado 0)';
                        ELSE
                            IF c.CRITICO = 'S'
                            THEN
                                v_estado_ctrl := 'ERROR';
                                v_retcode := 1;
                            ELSE
                                v_estado_ctrl := 'WARNING';
                                v_retcode := 0;
                            END IF;

                            v_retdesc := 'FAIL | RES=' || NVL (TO_CHAR (v_cnt), 'NULL') || ' (esperado 0)';
                        END IF;
                    END IF;
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    IF c.CRITICO = 'S'
                    THEN
                        v_estado_ctrl := 'ERROR';
                        v_retcode := 1;
                    ELSE
                        v_estado_ctrl := 'WARNING';
                        v_retcode := 0;
                    END IF;

                    v_retdesc := 'Error ejecutando SQL_CONTROL: ' || SUBSTR (SQLERRM, 1, 900);
            END;

            SELECT IT.S_GE_CRC_CTRL_RESULTADOS_LOG.NEXTVAL
              INTO v_id_log_ctrl
              FROM DUAL;

            INSERT INTO IT.GE_CRC_CTRL_RESULTADOS_LOG (ID_LOG_CTRL,
                                                       ID_EJECUCION,
                                                       FECHA_PROCESO,
                                                       ID_CTRL,
                                                       COD_PROC,
                                                       DESCRIPCION,
                                                       TABLA_DESTINO,
                                                       CRITICO,
                                                       MIN_REGISTROS,
                                                       RESULTADO_CNT,
                                                       ESTADO,
                                                       RETCODE,
                                                       RETDESC,
                                                       FH_CONTROL,
                                                       USUARIO)
                 VALUES (v_id_log_ctrl,
                         p_id_ejecucion,
                         TRUNC (p_fecha_proceso),
                         c.ID_CTRL,
                         c.COD_PROC,
                         c.DESCRIPCION,
                         c.TABLA_DESTINO,
                         c.CRITICO,
                         c.MIN_REGISTROS,
                         v_cnt,
                         v_estado_ctrl,
                         v_retcode,
                         SUBSTR (v_retdesc, 1, 1000),
                         SYSTIMESTAMP,
                         NVL (p_usuario, USER));

            COMMIT;

            IF v_estado_ctrl = 'ERROR'
            THEN
                o_errs := o_errs + 1;
                o_estado := 'ERROR';
                o_det_last := c.COD_PROC || ' | ' || v_retdesc;
            ELSIF v_estado_ctrl = 'WARNING'
            THEN
                o_warns := o_warns + 1;

                IF o_estado <> 'ERROR'
                THEN
                    o_estado := 'WARN';
                END IF;

                o_det_last := c.COD_PROC || ' | ' || v_retdesc;
            END IF;

            IF c.CRITICO = 'S' AND v_estado_ctrl = 'ERROR'
            THEN
                EXIT;
            END IF;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            o_estado := 'ERROR';
            o_errs := NVL (o_errs, 0) + 1;
            o_det_last := 'Error inesperado prc_ejecutar_controles_det: ' || SUBSTR (SQLERRM, 1, 900);
    END prc_ejecutar_controles_det;

    ---------------------------------------------------------------------------
    -- DISP_EXTRACTOR
    ---------------------------------------------------------------------------
    PROCEDURE prc_disponibilizar_extractor (
        p_id_ejecucion    IN     NUMBER,
        p_fecha_proceso   IN     DATE,
        p_usuario         IN     VARCHAR2,
        o_retcode            OUT NUMBER,
        o_retdesc            OUT VARCHAR2)
    IS
        v_errs       NUMBER := 0;
        v_warns      NUMBER := 0;

        v_det_last   VARCHAR2 (1000);
        v_estado     VARCHAR2 (10) := 'OK';
    BEGIN
        o_retcode := 0;
        o_retdesc := 'OK';

        SELECT SUM (CASE WHEN ESTADO = 'ERROR' THEN 1 ELSE 0 END) AS errs,
               SUM (CASE WHEN ESTADO = 'WARNING' THEN 1 ELSE 0 END) AS warns
          INTO v_errs, v_warns
          FROM IT.GE_CRC_CTRL_RESULTADOS_LOG
         WHERE     ID_EJECUCION = p_id_ejecucion
               AND FECHA_PROCESO = TRUNC (p_fecha_proceso);

        IF NVL (v_errs, 0) > 0
        THEN
            v_estado := 'ERROR';
        ELSIF NVL (v_warns, 0) > 0
        THEN
            v_estado := 'WARN';
        ELSE
            v_estado := 'OK';
        END IF;

        IF v_estado = 'ERROR'
        THEN
            BEGIN
                SELECT SUBSTR (COD_PROC || ' | ' || RETDESC, 1, 1000)
                  INTO v_det_last
                  FROM (  SELECT COD_PROC, RETDESC, FH_CONTROL
                            FROM IT.GE_CRC_CTRL_RESULTADOS_LOG
                           WHERE     ID_EJECUCION = p_id_ejecucion
                                 AND FECHA_PROCESO = TRUNC (p_fecha_proceso)
                                 AND ESTADO = 'ERROR'
                        ORDER BY FH_CONTROL DESC)
                 WHERE ROWNUM = 1;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    v_det_last := 'ERROR - Controles con error (sin detalle)';
            END;
        ELSIF v_estado = 'WARN'
        THEN
            BEGIN
                SELECT SUBSTR (COD_PROC || ' | ' || RETDESC, 1, 1000)
                  INTO v_det_last
                  FROM (  SELECT COD_PROC, RETDESC, FH_CONTROL
                            FROM IT.GE_CRC_CTRL_RESULTADOS_LOG
                           WHERE     ID_EJECUCION = p_id_ejecucion
                                 AND FECHA_PROCESO = TRUNC (p_fecha_proceso)
                                 AND ESTADO = 'WARNING'
                        ORDER BY FH_CONTROL DESC)
                 WHERE ROWNUM = 1;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    v_det_last := 'WARNING - Controles con warning (sin detalle)';
            END;
        ELSE
            v_det_last := 'OK - Controles validados correctamente';
        END IF;

        INSERT INTO IT.GE_CRC_MARCA_EXTRACTOR (ID_MARCA,
                                              ID_EJECUCION,
                                              FECHA_PROCESO,
                                              ESTADO,
                                              DETALLE,
                                              FH_MARCA,
                                              USUARIO)
             VALUES (IT.S_GE_CRC_MARCA_EXTRACTOR.NEXTVAL,
                     p_id_ejecucion,
                     TRUNC (p_fecha_proceso),
                     v_estado,
                     SUBSTR (NVL (v_det_last, 'OK'), 1, 1000),
                     SYSTIMESTAMP,
                     NVL (p_usuario, USER));

        IF v_estado = 'ERROR'
        THEN
            o_retcode := 1;
            o_retdesc := 'DISP_EXTRACTOR: no se disponibiliza por controles con ERROR. Errores=' || NVL (v_errs, 0) || '. ' || NVL (v_det_last, '');
        ELSIF v_estado = 'WARN'
        THEN
            o_retcode := 0;
            o_retdesc := 'WARNING: DISP_EXTRACTOR con controles WARNING. Warnings=' || NVL (v_warns, 0) || '. ' || NVL (v_det_last, '');
        ELSE
            o_retcode := 0;
            o_retdesc := 'OK';
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            o_retcode := 1;
            o_retdesc := 'Error DISP_EXTRACTOR: ' || SQLERRM;
    END prc_disponibilizar_extractor;

    ---------------------------------------------------------------------------
    -- Ejecutar procesos CRC (PROC) + reintentos
    ---------------------------------------------------------------------------
    PROCEDURE prc_ejecutar_crc (p_id_ejecucion    IN     NUMBER,
                                p_fecha_proceso   IN     DATE,
                                p_modo            IN     VARCHAR2,
                                p_usuario         IN     VARCHAR2,
                                p_db_unique       IN     VARCHAR2,
                                p_db_allow        IN     VARCHAR2,
                                p_db_prod         IN     VARCHAR2,
                                o_retcode            OUT NUMBER,
                                o_retdesc            OUT VARCHAR2)
    IS
        v_id_log   NUMBER;
        v_sql      VARCHAR2 (4000);
        v_msg      VARCHAR2 (4000);
    BEGIN
        o_retcode := 0;
        o_retdesc := 'OK';

        FOR r IN (  SELECT ORDEN,
                           COD_PROC,
                           DESCRIPCION,
                           CRITICO,
                           TIPO_EJECUCION,
                           OBJETO_EJECUCION,
                           PARAMETROS,
                           REINTENTOS
                      FROM IT.GE_CRC_PROCESOS_CFG
                     WHERE ACTIVO = 'S'
                  ORDER BY ORDEN)
        LOOP
            log_step_ini (p_id_ejecucion    => p_id_ejecucion,
                          p_fecha_proceso   => p_fecha_proceso,
                          p_paso_orden      => 3,
                          p_subpaso_orden   => r.ORDEN,
                          p_paso_cod        => r.COD_PROC,
                          p_paso_desc       => r.DESCRIPCION,
                          p_modo            => p_modo,
                          p_usuario         => p_usuario,
                          p_db_unique       => p_db_unique,
                          p_db_allow        => p_db_allow,
                          p_db_prod         => p_db_prod,
                          o_id_log          => v_id_log);

            BEGIN
                IF NVL (r.TIPO_EJECUCION, 'PROC') <> 'PROC'
                THEN
                    v_msg := 'TIPO_EJECUCION no soportado en modo actual (solo PROC): ' || r.TIPO_EJECUCION;

                    log_step_fin (v_id_log, 'ERROR', 1, v_msg, 'CFG', v_msg, NULL, p_usuario);

                    IF r.CRITICO = 'S'
                    THEN
                        o_retcode := 1;
                        o_retdesc := v_msg;
                        RETURN;
                    END IF;
                ELSE
                    DECLARE
                        v_try         NUMBER := 0;
                        v_max_retry   NUMBER := NVL (r.REINTENTOS, 0);
                        v_sleep_s     NUMBER := 2;
                    BEGIN
                        WHILE v_try <= v_max_retry
                        LOOP
                            BEGIN
                                v_try := v_try + 1;

                                IF r.PARAMETROS IS NULL
                                THEN
                                    v_sql := 'BEGIN ' || r.OBJETO_EJECUCION || '; COMMIT; END;';
                                ELSE
                                    v_sql := 'BEGIN ' || r.OBJETO_EJECUCION || '(' || r.PARAMETROS || '); COMMIT; END;';
                                END IF;

                                EXECUTE IMMEDIATE v_sql;

                                log_step_fin (v_id_log, 'OK', 0, 'OK', NULL, NULL, NULL, p_usuario);
                                EXIT;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    IF v_try <= v_max_retry AND fn_is_retryable (SQLCODE)
                                    THEN
                                        log_step_fin (p_id_log     => v_id_log,
                                                      p_estado     => 'WARNING',
                                                      p_retcode    => 0,
                                                      p_retdesc    => 'Reintento ' || v_try || '/' || (v_max_retry + 1) || ' por error transitorio: ' || SUBSTR (SQLERRM, 1, 900),
                                                      p_err_code   => TO_CHAR (SQLCODE),
                                                      p_err_msg    => SUBSTR (SQLERRM, 1, 1000),
                                                      p_err_stack  => DBMS_UTILITY.FORMAT_ERROR_BACKTRACE,
                                                      p_usuario    => p_usuario);

                                        DBMS_LOCK.SLEEP (v_sleep_s);
                                        v_sleep_s := LEAST (v_sleep_s * 2, 20);
                                    ELSE
                                        v_msg := 'Error ejecutando ' || r.OBJETO_EJECUCION || ': ' || SQLERRM;

                                        log_step_fin (p_id_log     => v_id_log,
                                                      p_estado     => 'ERROR',
                                                      p_retcode    => 1,
                                                      p_retdesc    => SUBSTR (v_msg, 1, 1000),
                                                      p_err_code   => TO_CHAR (SQLCODE),
                                                      p_err_msg    => SUBSTR (SQLERRM, 1, 1000),
                                                      p_err_stack  => DBMS_UTILITY.FORMAT_ERROR_BACKTRACE,
                                                      p_usuario    => p_usuario);

                                        IF r.CRITICO = 'S'
                                        THEN
                                            o_retcode := 1;
                                            o_retdesc := SUBSTR (v_msg, 1, 1000);
                                            RETURN;
                                        END IF;

                                        EXIT;
                                    END IF;
                            END;
                        END LOOP;
                    END;
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    v_msg := 'Error inesperado en subpaso ' || r.COD_PROC || ': ' || SQLERRM;

                    log_step_fin (p_id_log      => v_id_log,
                                  p_estado      => 'ERROR',
                                  p_retcode     => 1,
                                  p_retdesc     => SUBSTR (v_msg, 1, 1000),
                                  p_err_code    => TO_CHAR (SQLCODE),
                                  p_err_msg     => SUBSTR (SQLERRM, 1, 1000),
                                  p_err_stack   => DBMS_UTILITY.FORMAT_ERROR_BACKTRACE,
                                  p_usuario     => p_usuario);

                    IF r.CRITICO = 'S'
                    THEN
                        o_retcode := 1;
                        o_retdesc := SUBSTR (v_msg, 1, 1000);
                        RETURN;
                    END IF;
            END;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            o_retcode := 1;
            o_retdesc := 'Error en prc_ejecutar_crc: ' || SQLERRM;
    END prc_ejecutar_crc;

    ---------------------------------------------------------------------------
    -- PRC principal
    -- - Loguea también fallas de "precheck" (resolver fecha / lock)
    -- - Libera lock SIEMPRE
    ---------------------------------------------------------------------------
    PROCEDURE PRC_EJECUTAR_CRC (
        I_FECHA_PROCESO   IN  DATE     DEFAULT NULL,
        I_MODO_EJECUCION  IN  VARCHAR2 DEFAULT 'AUTO',
        I_USUARIO         IN  VARCHAR2 DEFAULT NULL,
        I_FORZAR          IN  CHAR     DEFAULT 'N',
        O_ID_EJECUCION    OUT NUMBER,
        O_ESTADO_FINAL    OUT VARCHAR2,
        O_RETCODE         OUT NUMBER,
        O_RETDESC         OUT VARCHAR2
    )
    IS
        v_id_ejecucion    NUMBER;
        v_fecha_proceso   DATE;
        v_usuario         VARCHAR2(30);
        v_modo            VARCHAR2(10);
    
        v_db_unique       VARCHAR2(30);
        v_db_allow        VARCHAR2(30);
        v_db_prod         VARCHAR2(30);
    
        v_id_log          NUMBER;
        v_retcode         NUMBER;
        v_retdesc         VARCHAR2(4000);
    
        -- Consolidado CONTROLES
        v_ctrl_estado     VARCHAR2(10);
        v_ctrl_det_last   VARCHAR2(1000);
        v_ctrl_errs       NUMBER;
        v_ctrl_warns      NUMBER;
    
        -- Fecha AUTO/MANUAL
        v_origen_fecha    VARCHAR2(10);
        v_cod_oficina     BA_OFICINAS.COD_OFICINA%TYPE := NULL;
    
        -- Lock
        v_lockhandle      VARCHAR2(128);
    BEGIN
        O_RETCODE := 0;
        O_RETDESC := 'OK';
        O_ESTADO_FINAL := 'OK';
    
        v_id_ejecucion := IT.S_CRC_ID_EJECUCION.NEXTVAL;
        O_ID_EJECUCION := v_id_ejecucion;
    
        v_usuario   := NVL(I_USUARIO, USER);
        v_modo      := NVL(I_MODO_EJECUCION, 'AUTO');
        v_db_unique := fn_get_db_unique_name;
    
        ----------------------------------------------------------------------------
        -- Resolver fecha antes de loguear (para evitar logs en ejecuciones SKIP)
        ----------------------------------------------------------------------------
        prc_resolver_fecha_proceso(
            p_fecha_in        => I_FECHA_PROCESO,
            p_modo            => v_modo,
            p_cod_oficina     => v_cod_oficina,
            o_fecha_proceso   => v_fecha_proceso,
            o_origen_fecha    => v_origen_fecha,
            o_retcode         => v_retcode,
            o_retdesc         => v_retdesc
        );

        IF v_retcode <> 0 THEN
            O_RETCODE := 1;
            O_RETDESC := v_retdesc;
            O_ESTADO_FINAL := 'ERROR';
            RETURN;
        END IF;

        ----------------------------------------------------------------------------
        -- Lock + duplicados ANTES de loguear: SKIP silencioso sin generar logs
        -- (NOR-655 / SRER-5770: evitar registros VALIDAR_ENTORNO en GE_LOG_CRC_EJEC para ejecuciones duplicadas)
        ----------------------------------------------------------------------------
        prc_lock_ejecucion(
            p_fecha_proceso => v_fecha_proceso,
            p_forzar        => I_FORZAR,
            o_lockhandle    => v_lockhandle,
            o_retcode       => v_retcode,
            o_retdesc       => v_retdesc
        );

        IF v_retcode <> 0 THEN
            O_RETCODE := 1;
            O_RETDESC := v_retdesc;
            O_ESTADO_FINAL := 'ERROR';
            prc_release_lock(v_lockhandle);
            RETURN;
        END IF;

        ----------------------------------------------------------------------------
        -- PASO 1: VALIDAR_ENTORNO (solo si no es SKIP ni error de fecha)
        ----------------------------------------------------------------------------
        log_step_ini(
            p_id_ejecucion  => v_id_ejecucion,
            p_fecha_proceso => v_fecha_proceso,
            p_paso_orden    => 1,
            p_subpaso_orden => NULL,
            p_paso_cod      => 'VALIDAR_ENTORNO',
            p_paso_desc     => 'Validación de entorno, calendario y FinDía',
            p_modo          => v_modo,
            p_usuario       => v_usuario,
            p_db_unique     => v_db_unique,
            p_db_allow      => NULL,
            p_db_prod       => NULL,
            o_id_log        => v_id_log
        );

        ----------------------------------------------------------------------------
        -- Validar entorno (DB allow/prod) + FinDía 11/12 + módulos cerrados
        ----------------------------------------------------------------------------
        prc_validar_entorno(
            p_db_unique     => v_db_unique,
            p_fecha_proceso => v_fecha_proceso,
            o_retcode       => v_retcode,
            o_retdesc       => v_retdesc,
            o_db_allow      => v_db_allow,
            o_db_prod       => v_db_prod
        );

        IF v_retcode = 0 AND v_retdesc LIKE 'WARNING:%' THEN
            log_step_fin(v_id_log, 'WARNING', 0, v_retdesc, NULL, NULL, NULL, v_usuario);
        ELSIF v_retcode = 0 THEN
            log_step_fin(v_id_log, 'OK', 0, v_retdesc, NULL, NULL, NULL, v_usuario);
        ELSE
            log_step_fin(v_id_log, 'ERROR', 1, v_retdesc, 'ENV', v_retdesc, NULL, v_usuario);

            O_RETCODE := 1;
            O_RETDESC := v_retdesc;
            O_ESTADO_FINAL := 'ERROR';
            RETURN;
        END IF;
    
        ----------------------------------------------------------------------------
        -- A partir de acá: loop de pasos configurados
        ----------------------------------------------------------------------------
        FOR p IN (
            SELECT ORDEN, COD_PASO, DESCRIPCION, CRITICO
              FROM IT.GE_CRC_PASOS_ORQ
             WHERE ACTIVO = 'S'
             ORDER BY ORDEN
        ) LOOP
    
            -- OJO: ya ejecutamos VALIDAR_ENTORNO arriba y lo logueamos.
            -- Si en config viene, lo salteamos para no duplicar.
            IF p.COD_PASO = 'VALIDAR_ENTORNO' THEN
                CONTINUE;
            END IF;
    
            log_step_ini(
                p_id_ejecucion  => v_id_ejecucion,
                p_fecha_proceso => v_fecha_proceso,
                p_paso_orden    => p.ORDEN,
                p_subpaso_orden => NULL,
                p_paso_cod      => p.COD_PASO,
                p_paso_desc     => p.DESCRIPCION,
                p_modo          => v_modo,
                p_usuario       => v_usuario,
                p_db_unique     => v_db_unique,
                p_db_allow      => v_db_allow,
                p_db_prod       => v_db_prod,
                o_id_log        => v_id_log
            );
    
            BEGIN
                IF p.COD_PASO = 'OBTENER_CONFIG' THEN
                    prc_obtener_config(v_retcode, v_retdesc);
    
                    IF v_retcode = 0 AND v_retdesc LIKE 'WARNING:%' THEN
                        log_step_fin(v_id_log, 'WARNING', 0, v_retdesc, NULL, NULL, NULL, v_usuario);
                    ELSIF v_retcode = 0 THEN
                        log_step_fin(v_id_log, 'OK', 0, v_retdesc, NULL, NULL, NULL, v_usuario);
                    ELSE
                        log_step_fin(v_id_log, 'ERROR', 1, v_retdesc, 'CFG', v_retdesc, NULL, v_usuario);
                        O_RETCODE := 1; O_RETDESC := v_retdesc; O_ESTADO_FINAL := 'ERROR';
                        prc_release_lock(v_lockhandle);
                        RETURN;
                    END IF;
    
                ELSIF p.COD_PASO = 'EJECUTAR_CRC' THEN
                    pr_ini_modulos;
                    pr_abrir_modulos;
    
                    prc_ejecutar_crc(
                        p_id_ejecucion  => v_id_ejecucion,
                        p_fecha_proceso => v_fecha_proceso,
                        p_modo          => v_modo,
                        p_usuario       => v_usuario,
                        p_db_unique     => v_db_unique,
                        p_db_allow      => v_db_allow,
                        p_db_prod       => v_db_prod,
                        o_retcode       => v_retcode,
                        o_retdesc       => v_retdesc
                    );
    
                    pr_cerrar_modulos;
    
                    IF v_retcode = 0 AND v_retdesc LIKE 'WARNING:%' THEN
                        log_step_fin(v_id_log, 'WARNING', 0, v_retdesc, NULL, NULL, NULL, v_usuario);
                    ELSIF v_retcode = 0 THEN
                        log_step_fin(v_id_log, 'OK', 0, v_retdesc, NULL, NULL, NULL, v_usuario);
                    ELSE
                        log_step_fin(v_id_log, 'ERROR', 1, v_retdesc, 'CRC', v_retdesc, NULL, v_usuario);
                        O_RETCODE := 1; O_RETDESC := v_retdesc; O_ESTADO_FINAL := 'ERROR';
                        prc_release_lock(v_lockhandle);
                        RETURN;
                    END IF;
    
                ELSIF p.COD_PASO = 'EJECUTAR_CONTROLES' THEN
                    prc_ejecutar_controles_det(
                        p_id_ejecucion  => v_id_ejecucion,
                        p_fecha_proceso => v_fecha_proceso,
                        p_usuario       => v_usuario,
                        o_estado        => v_ctrl_estado,
                        o_det_last      => v_ctrl_det_last,
                        o_errs          => v_ctrl_errs,
                        o_warns         => v_ctrl_warns
                    );
    
                    IF v_ctrl_estado = 'ERROR' THEN
                        v_retdesc :=
                            'CONTROLES: ERROR. Errores='||NVL(v_ctrl_errs,0)||
                            CASE WHEN NVL(v_ctrl_warns,0)>0 THEN ' Warnings='||NVL(v_ctrl_warns,0) ELSE '' END||
                            '. '||NVL(v_ctrl_det_last,'');
    
                        log_step_fin(v_id_log, 'ERROR', 1, SUBSTR(v_retdesc,1,1000), 'CTRL', SUBSTR(v_retdesc,1,1000), NULL, v_usuario);
    
                        O_RETCODE := 1; O_RETDESC := SUBSTR(v_retdesc,1,1000); O_ESTADO_FINAL := 'ERROR';
                        prc_release_lock(v_lockhandle);
                        RETURN;
    
                    ELSIF v_ctrl_estado = 'WARN' THEN
                        v_retdesc :=
                            'WARNING: CONTROLES con fallas no críticas. Warnings='||NVL(v_ctrl_warns,0)||
                            CASE WHEN NVL(v_ctrl_errs,0)>0 THEN ' Errores='||NVL(v_ctrl_errs,0) ELSE '' END||
                            '. '||NVL(v_ctrl_det_last,'');
    
                        log_step_fin(v_id_log, 'WARNING', 0, SUBSTR(v_retdesc,1,1000), NULL, NULL, NULL, v_usuario);
                    ELSE
                        log_step_fin(v_id_log, 'OK', 0, 'OK', NULL, NULL, NULL, v_usuario);
                    END IF;
    
                ELSIF p.COD_PASO = 'DISP_EXTRACTOR' THEN
                    prc_disponibilizar_extractor(
                        p_id_ejecucion  => v_id_ejecucion,
                        p_fecha_proceso => v_fecha_proceso,
                        p_usuario       => v_usuario,
                        o_retcode       => v_retcode,
                        o_retdesc       => v_retdesc
                    );
    
                    IF v_retcode = 0 AND v_retdesc LIKE 'WARNING:%' THEN
                        log_step_fin(v_id_log, 'WARNING', 0, v_retdesc, NULL, NULL, NULL, v_usuario);
                    ELSIF v_retcode = 0 THEN
                        log_step_fin(v_id_log, 'OK', 0, v_retdesc, NULL, NULL, NULL, v_usuario);
                    ELSE
                        log_step_fin(v_id_log, 'ERROR', 1, v_retdesc, 'EXT', v_retdesc, NULL, v_usuario);
                        O_RETCODE := 1; O_RETDESC := v_retdesc; O_ESTADO_FINAL := 'ERROR';
                        prc_release_lock(v_lockhandle);
                        RETURN;
                    END IF;
    
                ELSE
                    v_retdesc := 'Paso no reconocido: ' || p.COD_PASO;
                    log_step_fin(v_id_log, 'ERROR', 1, v_retdesc, 'CFG', v_retdesc, NULL, v_usuario);
                    O_RETCODE := 1; O_RETDESC := v_retdesc; O_ESTADO_FINAL := 'ERROR';
                    prc_release_lock(v_lockhandle);
                    RETURN;
                END IF;
    
            EXCEPTION
                WHEN OTHERS THEN
                    v_retdesc := 'Error en paso '||p.COD_PASO||': '||SQLERRM;
                    log_step_fin(
                        p_id_log    => v_id_log,
                        p_estado    => 'ERROR',
                        p_retcode   => 1,
                        p_retdesc   => SUBSTR(v_retdesc,1,1000),
                        p_err_code  => TO_CHAR(SQLCODE),
                        p_err_msg   => SUBSTR(SQLERRM,1,1000),
                        p_err_stack => DBMS_UTILITY.FORMAT_ERROR_BACKTRACE,
                        p_usuario   => v_usuario
                    );
                    O_RETCODE := 1;
                    O_RETDESC := SUBSTR(v_retdesc,1,1000);
                    O_ESTADO_FINAL := 'ERROR';
                    prc_release_lock(v_lockhandle);
                    RETURN;
            END;
    
        END LOOP;
    
        prc_release_lock(v_lockhandle);
    
    EXCEPTION
        WHEN OTHERS THEN
            prc_release_lock(v_lockhandle);
            O_RETCODE := 1;
            O_RETDESC := 'Error general PRC_EJECUTAR_CRC: ' || SQLERRM;
            O_ESTADO_FINAL := 'ERROR';
    END PRC_EJECUTAR_CRC;

END PAG_CRC;
/