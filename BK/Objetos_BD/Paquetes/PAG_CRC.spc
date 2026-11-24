CREATE OR REPLACE PACKAGE IT.PAG_CRC AS
    ----------------------------------------------------------------------------
    -- Orquestador CRC desacoplado (NOR-508)
    --
    -- Funcionalidad:
    -- - Evita concurrencia por FECHA_PROCESO mediante lock (DBMS_LOCK).
    -- - Controla re-ejecución por fecha (si I_FORZAR <> 'S', bloquea si ya
    --   existe DISP_EXTRACTOR en OK para la misma FECHA_PROCESO).
    -- - Valida entorno por DB_UNIQUE_NAME (fug_obt_pardinamico) y bloquea PROD.
    -- - Valida calendario FinDía (PAG_CAL.FU_OBT_FEC_ACTUAL(1)).
    -- - Valida cierre/postcierre (GE_PROCESOS 11 y 12 con HOR_FIN) y módulos
    --   cerrados en BA_MODULOS (excepto Contabilidad).
    -- - Ejecuta pasos configurados en IT.GE_CRC_PASOS_ORQ.
    -- - Ejecuta procesos CRC configurados en IT.GE_CRC_PROCESOS_CFG, con
    --   reintentos ante errores transitorios (según configuración).
    -- - Ejecuta controles configurados en IT.GE_CRC_CTRL_RESULTADOS_CFG y registra
    --   detalle en IT.GE_CRC_CTRL_RESULTADOS_LOG.
    -- - Registra ejecución en IT.GE_LOG_CRC_EJEC (1 fila por paso y subpaso).
    -- - Genera marca de disponibilidad para extractor en IT.GE_CRC_MARCA_EXTRACTOR.
    ----------------------------------------------------------------------------

    PROCEDURE PRC_EJECUTAR_CRC (
        I_FECHA_PROCESO    IN  DATE     DEFAULT NULL,
        I_MODO_EJECUCION   IN  VARCHAR2 DEFAULT 'AUTO', -- AUTO | MANUAL
        I_USUARIO          IN  VARCHAR2 DEFAULT NULL,
        I_FORZAR           IN  CHAR     DEFAULT 'N',    -- S | N
        O_ID_EJECUCION     OUT NUMBER,
        O_ESTADO_FINAL     OUT VARCHAR2,                -- OK | WARNING | ERROR
        O_RETCODE          OUT NUMBER,                  -- 0 | 1
        O_RETDESC          OUT VARCHAR2
    );

END PAG_CRC;
/