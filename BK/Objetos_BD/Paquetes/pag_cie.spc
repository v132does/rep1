CREATE OR REPLACE PACKAGE IT.PAG_CIE
IS
   -- Constantes de peso para los niveles de log
   c_log_OFF   PLS_INTEGER := 0; --Apagado      : deshabilitar logs
   c_log_TRACE PLS_INTEGER := 1; --Detalle fino : depuración profunda
   c_log_DEBUG PLS_INTEGER := 2; --Detalle      : información técnica para desarrolladores y pruebas
   c_log_INFO  PLS_INTEGER := 3; --Información  : resúmen de la ejecución normal del sistema
   c_log_WARN  PLS_INTEGER := 4; --Advertencia  : eventos inesperados no críticos y/o controlados
   c_log_ERROR PLS_INTEGER := 5; --Error        : interrupción que afecta determinada funcionalidad, sin comprometer la operatividad del sistema
   c_log_FATAL PLS_INTEGER := 6; --Crítico      : interrupción violenta del sistema que requiere intervención inmediata

   -- Constantes de contexto para la ejecución de un Programa de un Proceso
   c_ctx_SECUENCIAL   CONSTANT VARCHAR2(12) := 'SECUENCIAL';   -- Mantener sesión principal
   c_ctx_JOB_PARALELO CONSTANT VARCHAR2(12) := 'JOB_PARALELO'; -- Crear nueva sesión en job concurrente
   c_ctx_OCO          CONSTANT VARCHAR2(12) := 'OCO';          -- Sesión que ejecuta Programas desde una orquestación externa a Oracle
   c_ctx_OCO_ASYNC    CONSTANT VARCHAR2(12) := 'OCO_ASYNC';    -- Sesión que ejecuta Programas ASYNC desde una orquestación externa a Oracle

   -- Constantes de mensajes temporales relacionados a la ejecución en Paralelo de un Programa
   c_msj_DEP_F_NO_RESUELTA  CONSTANT VARCHAR2(55) := 'Dependencia de Fin de Programa Previo no resuelta.';
   c_msj_PRO_P_EN_EJECUCION CONSTANT VARCHAR2(55) := 'El programa se encuentra en ejecución en paralelo...';
   c_msj_ERR_PRO_PARALELO   CONSTANT VARCHAR2(75) := 'Se detectó de manera temprana el fin de un Programa Paralelo en Error.';
   c_msj_OCO_EN_EJECUCION   CONSTANT VARCHAR2(90) := 'La tarea se encuentra en ejecución desde una orquestación externa a Oracle (OCO).';

   /*
      30-06-2025  v1.0  LReyes
      OBJETIVO: Obtener, en texto resumen, información del entorno de ejecución del usuario.
   */
   FUNCTION FU_OBT_ENTORNO
   RETURN VARCHAR2;

   /*
      22-01-2025  v1.0  LReyes
      OBJETIVO: Encapsular el acceso a las constantes del package para el Forms GPPROFIN.
   */
   FUNCTION FN_GET_CONSTANTE (
      p_key IN VARCHAR2
   )
   RETURN VARCHAR2;

   /*
      22-01-2025  v1.0  LReyes
      OBJETIVO: Generar el nombre de un JOB a partir de los parámetros COD_PROCESO y NRO_ORDEN.
   */ 
   FUNCTION FN_JOB_NOMBRAR (
      p_cod_proceso IN NUMBER,
      p_nro_orden   IN NUMBER
   )
   RETURN VARCHAR2;

   /*
      23-12-2024  v1.0  LReyes
      OBJETIVO: Evaluar las dependencias configuradas para el Programa parametrizado según tipo.
   */
   FUNCTION FN_VER_DEPENDENCIA (
      p_cod_proceso  IN  NUMBER,
      p_cod_programa IN  VARCHAR2,
      p_tipo         IN  VARCHAR2
   )
   RETURN VARCHAR2;

   /*
      23-12-2024  v1.0  LReyes
      OBJETIVO: Ejecutar las dependencias de Control para el Programa parametrizado.
   */
   FUNCTION FN_CTR_PROGRAMA (
      p_cod_programa IN  VARCHAR2
   )
   RETURN NUMBER;

   /*
      23-12-2024  v1.0  LReyes
      OBJETIVO: Verificar si el Programa parametrizado aún continúa en ejecución como JOB concurrente.
   */ 
   FUNCTION FN_JOB_EN_EJECUCION (
      p_job_name  IN  VARCHAR2
   )
   RETURN VARCHAR2;

   /*
      25-02-2025  v1.0  LReyes
      OBJETIVO: Evaluar si algún Programa Paralelo del Proceso parametrizado está en ejecución.
   */
   FUNCTION FU_OBT_PRO_EJE_PARALELO (
      p_cod_proceso IN ge_procesos_dep.cod_proceso%TYPE
   )
   RETURN VARCHAR2;

   /*
      13-02-2025  v1.0  LReyes
      OBJETIVO: Evaluar si algún Programa Paralelo del Proceso parametrizado ha finalizado en error.
   */
   FUNCTION FU_OBT_PRO_ERR_PARALELO (
      p_cod_proceso IN ge_procesos_dep.cod_proceso%TYPE
   )
   RETURN VARCHAR2;

   /*
      29-01-2025  v1.0  LReyes
      OBJETIVO: Evaluar si el error parametrizado desactiva la posibilidad de paralelismo del Programa parametrizado.
   */ 
   FUNCTION FU_JOB_SIN_PARALELISMO (
      p_cod_proceso  IN ge_err_pro_paralelos.cod_proceso%TYPE,
      p_cod_programa IN ge_err_pro_paralelos.cod_programa%TYPE,
      p_error        IN VARCHAR2
   )
   RETURN VARCHAR2;
   
   /*
      30-03-2026  v1.0  fdavalos
      OBJETIVO: Obtener hora para el usuario del cierre.
   */
   FUNCTION FU_OBT_HORA(
     p_cod_usuario IN VARCHAR2,
     p_seq_hora    IN VARCHAR2,
     p_caracter    IN VARCHAR2
     )
   RETURN VARCHAR2;
   
   /*
      30-03-2026  v1.0  fdavalos
      OBJETIVO: Obtener movimiento para el usuario del cierre.
   */
   FUNCTION FU_OBT_MOV_USER(
     p_tip_user     IN ba_cod_referencias.abreviatura%type,
     p_dominio      IN ba_cod_referencias.dominio%type,
     p_can_user     IN NUMBER,
     p_seq_usuario  IN VARCHAR2    
     )
   RETURN VARCHAR2;

   /*.
      23-12-2024  v1.0  LReyes
      OBJETIVO: Encapsular la lógica de ejecución dinámica de cada Programa de un Proceso.
   */
   PROCEDURE PR_EJE_PRO_PROGRAMA (
      p_cod_proceso  IN  NUMBER,
      p_nro_orden    IN  NUMBER,
      p_cod_programa IN  VARCHAR2,
      p_contexto     IN  VARCHAR2,
      p_log_level    IN  VARCHAR2,
      p_error        OUT VARCHAR2
   );

   /*
      23-12-2024  v1.0  LReyes
      OBJETIVO: Detener la ejecución del JOB concurrente de un Programa según COD_PROCESO y NRO_ORDEN.
   */ 
   PROCEDURE PR_JOB_STOP (
      p_cod_proceso IN NUMBER,
      p_nro_orden   IN NUMBER
   );

   /*
      23-12-2024  v1.0  LReyes
      OBJETIVO: Registrar mensajes de log en una transacción autónoma. 
   */
   PROCEDURE PR_AT_INS_LOG (
      p_cod_proceso  IN NUMBER,
      p_nro_orden    IN NUMBER,
      p_cod_programa IN VARCHAR2,
      p_mensaje      IN VARCHAR2,
      p_log_level    IN PLS_INTEGER,
      p_contexto     IN VARCHAR2,
      p_fecha        IN DATE
   );

   /*
      23-12-2024  v1.0  LReyes
      OBJETIVO: Registrar mensajes de log.
   */
   PROCEDURE PR_INS_LOG (
      p_mensaje      IN VARCHAR2,
      p_log_level    IN PLS_INTEGER DEFAULT c_log_INFO,
      p_transaction  IN VARCHAR2 DEFAULT NULL
   );

   /*
      23-12-2024  v1.0  LReyes
      OBJETIVO: Setear los valores configurados en la base de datos para el uso del package.
   */
   PROCEDURE PR_SET_PARAMETROS (
      p_cod_proceso  IN NUMBER   DEFAULT NULL,
      p_nro_orden    IN NUMBER   DEFAULT NULL,
      p_cod_programa IN VARCHAR2 DEFAULT NULL,
      p_contexto     IN VARCHAR2 DEFAULT NULL,
      p_log_level    IN VARCHAR2 DEFAULT 'INFO'
   );

   /*
      27-01-2026  v1.0  LReyes
      OBJETIVO: Encapsular la lógica de ejecución dinámica de cada Programa de un Proceso. Versión OCO -Operational Closure Orchestrator-
   */
   PROCEDURE PR_EJE_TAREA_OCO (
      p_cod_proceso  IN  NUMBER,
      p_nro_orden    IN  NUMBER,
      p_cod_programa IN  VARCHAR2,
      p_contexto     IN  VARCHAR2 DEFAULT 'OCO',
      p_log_level    IN  VARCHAR2 DEFAULT 'INFO',
      p_error        OUT VARCHAR2
   );

   /*
      05-02-2026  v1.0  LReyes
      OBJETIVO: Verificar si el Proceso parametrizado se encuentra en orquestación externa a Oracle.
   */ 
   FUNCTION FN_OCO_EN_EJECUCION (
      p_cod_proceso  IN  NUMBER
   )
   RETURN VARCHAR2;

   /*
      12-02-2026  v1.0  LReyes
      OBJETIVO: Actualizar la tabla cabecera GE_PROCESOS desde la orquestación externa a Oracle.
   */ 
   PROCEDURE PR_UPD_PRO_OCO (
      p_cod_proceso IN  NUMBER,
      p_tipo        IN  VARCHAR2,
      p_error_in    IN  VARCHAR2 DEFAULT NULL,
      p_error_out   OUT VARCHAR2
   );

   /*
      02-03-2026  v1.0  LReyes
      OBJETIVO: Actualizar la tabla detalle GE_PROCESOS_DET desde la orquestación externa a Oracle.
   */
   PROCEDURE PR_UPD_PRO_DET_OCO (
      p_cod_proceso IN  NUMBER,
      p_nro_orden   IN  NUMBER,
      p_accion      IN  VARCHAR2,
      p_error_in    IN  VARCHAR2 DEFAULT NULL,
      p_error_out   OUT VARCHAR2
   );

   /*
      15-05-2026  v1.0  LReyes
      OBJETIVO: Encapsular la lógica de ejecución dinámica ASYNC de cada Programa de un Proceso. Versión OCO -Operational Closure Orchestrator-
   */
   PROCEDURE PR_EJE_TAREA_OCO_ASYNC (
      p_cod_proceso  IN  NUMBER,
      p_nro_orden    IN  NUMBER,
      p_cod_programa IN  VARCHAR2,
      p_token        IN  VARCHAR2,
      p_contexto     IN  VARCHAR2 DEFAULT 'OCO_ASYNC',
      p_log_level    IN  VARCHAR2 DEFAULT 'INFO',
      p_error        OUT VARCHAR2
   );

END PAG_CIE;
