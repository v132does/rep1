CREATE OR REPLACE PACKAGE IT.pao_mor IS
 v_directorio varchar2(20) := fug_obt_pardinamico('DIR_INFORMCONF');--DIR.SETEADA PARA PRODUCCION
 --v_directorio varchar2(20) := '/u02/oradata/it/utl';-- DIR.SETEADA PARA BBVA_DESA
  v_afiliado   varchar2(10) := fug_obt_pardinamico( 'COD_AFI_INFORMCONF');
/*Variables */
  g_servidor   VARCHAR2(200) := FUG_OBT_PARENTES( fug_obt_pardinamico('GEN_COD_ENTE_INFORMCONF'),'WS_DIR_IP_INFORMCONF');
  g_puerto     NUMBER(4) := FUG_OBT_PARENTES( fug_obt_pardinamico('GEN_COD_ENTE_INFORMCONF'),'WS_PTO_INFORMCONF');
  g_tie_espera NUMBER(4) := NULL;
  g_reproceso  varchar2(1) := 'N'; 
  g_reauto     varchar2(1) := 'N';
/* Guarda los sucesos de los procesos de Informconf */
PROCEDURE PR_INS_INFORME
  (P_PROCESO IN CO_INF_PROCESOS.NOM_PROCESO%TYPE
  ,P_FEC_INI IN DATE
  ,P_COMENTARIO IN CO_INF_PROCESOS.COMENTARIO%TYPE
  ,P_ERROR IN BOOLEAN := TRUE);
/* Obtiene el código de operación Informconf a partir de la cuenta */
FUNCTION FU_OBT_INF_OPERACION
  (P_COD_MODULO IN NUMBER
  ,P_RELACION IN VARCHAR2
  ,P_COD_MODALIDAD IN NUMBER DEFAULT NULL)
RETURN NUMBER;
/* Obtiene la moneda Informconf para la moneda del sistema */
FUNCTION FU_OBT_INF_MONEDA
  (P_COD_MONEDA IN VARCHAR2)
  RETURN VARCHAR2; 
/* Proceso de generación de datos para Informconf */
PROCEDURE PR_PRO_INF_DIARIO
  (P_FEC_PROCESO IN DATE DEFAULT trunc(pag_cal.fu_obt_fec_actual(6)));
/* Inserta registro de la tabla CO_INF_OPE_DIARIAS */
PROCEDURE PR_INS_INF_OPE_DIARIA( p_registro  IN  CO_INF_OPE_DIARIAS%ROWTYPE,
                                 p_men_error OUT CO_INF_PROCESOS.COMENTARIO%TYPE );
/* Genera archivo para Informconf */
PROCEDURE PR_GEN_INF_ARCHIVO
  (P_FEC_PROCESO IN DATE DEFAULT trunc(pag_cal.fu_obt_fec_actual(6)));
/* Procesa los registros diarios confirmados por Informconf */
PROCEDURE PR_PRO_INF_CONFIRMAR
  (P_FEC_PROCESO IN DATE DEFAULT trunc(pag_cal.fu_obt_fec_actual(6)));
/* Indica que no existen registros sin procesar que impidan la ejecución de nuevos procesos */
FUNCTION FU_PUE_PROCESAR( P_FEC_PROCESO IN DATE ) RETURN BOOLEAN;
/* Envío total de clientes a Control de Cartera en Informconf */
PROCEDURE PR_PRO_INF_CTL_CARTERA
  (P_FEC_PROCESO IN DATE DEFAULT trunc(pag_cal.fu_obt_fec_actual(6)));
/* Verifica que no se hayan producido errores en los procesos de Informconf */
PROCEDURE PR_CTL_INF_PROCESO (P_FEC_PROCESO IN DATE DEFAULT trunc(sysdate));
/* Obtiene el apellido de casada */
FUNCTION FU_OBT_APE_CASADA( P_COD_PERSONA IN VARCHAR2 ) RETURN VARCHAR2;
---proceso que  validará los datos e invocará al proceso de envio de datos a INFORMCONF
PROCEDURE PR_ENV_MOROSIDAD (p_reproceso   varchar2 default 'N',
                            p_fec_proceso date default null);
--Proceso que realizará inserción de informe histórico                                
PROCEDURE PR_INS_INF_HISTORICO (p_cod_persona    co_inf_personas.cod_persona%type,
                                p_ide_operacion  co_inf_personas.ide_operacion%type,
                                p_relacion       co_inf_personas.relacion%type,
                                p_fec_proceso    date);
--Notificación al usuario de procesamiento
PROCEDURE PR_NOT_PROCESAMIENTO (P_FEC_PROCESO IN DATE DEFAULT null);
--Proceso ejecutado en Tarea Programada
PROCEDURE PR_PRO_AUTOMATICO;
END PAO_MOR;
/

