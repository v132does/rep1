create or replace PACKAGE  IT.PAS_SOL AS

    -- ===================================================================
    -- FU_GENERAR_UUID: Genera identificador Ãºnico para ejecuciones
    -- ===================================================================
    FUNCTION FU_GENERAR_UUID RETURN VARCHAR2;

    -- ===================================================================
    -- PR_REGISTRAR_LOG: Registra eventos en la tabla de logs
    -- ===================================================================
    PROCEDURE PR_REGISTRAR_LOG (
        p_id_ejecucion      IN VARCHAR2,
        p_tipo_log          IN VARCHAR2,
        p_mensaje           IN VARCHAR2,
        p_detalle_error     IN CLOB DEFAULT NULL,
        p_cantidad_registros IN NUMBER DEFAULT NULL,
        p_tiempo_ms         IN NUMBER DEFAULT NULL
    );

    -- ===================================================================
    -- PR_ACTUALIZAR_EJECUCION: Actualiza estado de ejecuciÃ³n
    -- ===================================================================
    PROCEDURE PR_ACTUALIZAR_EJECUCION (
        p_id_ejecucion      IN VARCHAR2,
        p_estado            IN VARCHAR2,
        p_registros_procesados IN NUMBER DEFAULT NULL,
        p_registros_error   IN NUMBER DEFAULT NULL,
        p_tiempo_ms         IN NUMBER DEFAULT NULL
    );

    -- ===================================================================
    -- FU_VALIDAR_PARAMETROS: Valida parÃ¡metros de entrada
    -- ===================================================================
    FUNCTION FU_VALIDAR_PARAMETROS (
        p_ano               IN NUMBER,
        p_mes               IN NUMBER,
        p_fuente_datos      IN VARCHAR2
    ) RETURN BOOLEAN;

    -- ===================================================================
    -- PR_LIMPIAR_DATOS_ANTIGUOS: Elimina registros antiguos
    -- ===================================================================
    PROCEDURE PR_LIMPIAR_DATOS_ANTIGUOS (
        p_meses_atras       IN NUMBER DEFAULT 12,
        p_registros_eliminados OUT NUMBER
    );

    -- ===================================================================
    -- FU_OBTENER_RESUMEN_EJECUCIONES: Genera reporte de ejecuciones
    -- ===================================================================
    FUNCTION FU_OBTENER_RESUMEN_EJECUCIONES (
        p_dias              IN NUMBER DEFAULT 7
    ) RETURN VARCHAR2;
    -- ===================================================================
    --
    --====================================================================
    function FU_GET_TOT_GARANTIAS (p_anexo in varchar2)return number;
    -- ===================================================================
    --
    --====================================================================
    PROCEDURE PR_ANEXOS_GENERAR_EXCEL(
        p_id_ejecucion IN VARCHAR2,
        p_anexo        IN VARCHAR2,
        p_resultado         OUT NUMBER);

    PROCEDURE PR_GENERAR_ANEXOS (
        p_fecha             IN DATE,
        p_fuente_datos      IN VARCHAR2 DEFAULT NULL,
        p_id_ejecucion      OUT VARCHAR2,
        p_resultado         OUT NUMBER,
        p_anexo             IN VARCHAR2 DEFAULT NULL,
        p_aud               IN VARCHAR2 DEFAULT 'N',
        p_fecha_aud         IN DATE DEFAULT NULL
    );

END;
