CREATE OR REPLACE PACKAGE IT."PAR_CAM" IS
c_tip_imp CONSTANT NUMBER(3) := fug_obt_tip_implementacion;
/* Genera las personas asociadas a las campañas */
PROCEDURE PR_GEN_CAM_PERSONAS
 (P_COD_CAMPANA CR_CAMPANAS.COD_CAMPANA%TYPE
 );
/* Genera el historial de las personas asociadas a las campañas */
PROCEDURE PR_GEN_HIS_CAMPANAS
 (P_COD_CAMPANA CR_CAMPANAS.COD_CAMPANA%TYPE
 );
/* Actualiza las campañas a "Vencidas" cuando llegue la fecha de fin */
PROCEDURE PR_CAM_VENCIDA;
/* Obtiene la lista de cuentas morosas de la persona */
FUNCTION FU_OBT_CTA_MOROSAS
 (P_COD_PERSONA BA_PERSONAS.COD_PERSONA%TYPE,
  P_FECHA       DATE
 )
 RETURN VARCHAR2;
/* Obtiene la lista de cuentas morosas de la persona para notas */
FUNCTION FU_OBT_CTA_MOR_NOT
 (P_COD_PERSONA BA_PERSONAS.COD_PERSONA%TYPE,
  P_FECHA       DATE
 )
 RETURN VARCHAR2;/* Inserta el registro de agenda y actualiza la tabla CR_CAM_PERSONAS indicando que la actividad fue generada. */
PROCEDURE PR_INS_AGENDA( P_COD_CAMPANA IN  CR_CAMPANAS.COD_CAMPANA%TYPE,
                         P_REG         IN  CR_AGENDAS%ROWTYPE,
                         P_MENSAJE     OUT VARCHAR2
                         );

/* Cuenta la cantidad de usuarios asignados para la ejecución de la campaña */
FUNCTION FU_TOT_USUARIOS( P_TIP_RESPONSABLE IN VARCHAR2,
                          P_RESPONSABLES    IN VARCHAR2
                          ) RETURN NUMBER;

/* Cuenta la cantidad de personas asignadas a la campaña. */
--FUNCTION LF_TOT_PERSONAS( P_CAMPANA IN NUMBER ) RETURN NUMBER;

/* Obtiene la oficina del usuario. */
FUNCTION FU_OBT_OFI_USUARIO( P_COD_USUARIO IN VARCHAR2 ) RETURN NUMBER;

/* Obtiene la la cantidad máxima de días de atraso y la suma de mora en guaraníes. */
PROCEDURE PR_OBT_ATRASO( P_COD_PERSONA IN  VARCHAR2,
                         P_MAX_DIA     OUT NUMBER,
                         P_MTO_MORA    OUT NUMBER
                         );

/* Verifica que no hayan actividades pendientes para el cliente. */
PROCEDURE PR_VER_ACT_PENDIENTES( P_COD_CAMPANA     IN CR_CAMPANAS.COD_CAMPANA%TYPE,
                                 P_COD_PERSONA     IN  BA_PERSONAS.COD_PERSONA%TYPE,
                                 P_DET_ACTIVIDAD   IN  VARCHAR2,
                                 P_CAN_ACTIVIDADES OUT NUMBER
                                 );

/* Habilita/Deshabilita los trigger utilizados en los procesos de agenda. */
FUNCTION FU_SET_TRIGGER( P_ESTADO VARCHAR2 ) RETURN VARCHAR2;
/* Genera la agenda de las campañas para los usuarios */
PROCEDURE PR_GEN_AGENDA
 (P_COD_CAMPANA CR_CAMPANAS.COD_CAMPANA%TYPE
 );
/* Genera notas de las campañas para los usuarios */
PROCEDURE PR_GEN_NOTA
 (P_COD_CAMPANA CR_CAMPANAS.COD_CAMPANA%TYPE
 );
/* Genera los emails para los clientes de las campañas */
PROCEDURE PR_GEN_EMAIL
 (P_COD_CAMPANA IN CR_CAMPANAS.COD_CAMPANA%TYPE
 );
/* Genera las inibiciones y reabilitaciones de clientes */
PROCEDURE PR_GEN_INHIBICION
 (P_COD_CAMPANA CR_CAMPANAS.COD_CAMPANA%TYPE
 );
/* Proceso autom. qu realizas las operaciones relacionadas con la campaña */
PROCEDURE PR_PRO_AUTOMATICO(p_cod_campana in number default null);
/* Proceso de actualización de actividades efectivizadas */
PROCEDURE PR_PRO_ACT_EFECTIVAS;
/* Proceso de control de actividades de cobranzas */
PROCEDURE PR_GEN_ACT_COBRANZA
 (P_COD_CAMPANA CR_CAMPANAS.COD_CAMPANA%TYPE
 );
/* Proceso de control y corrección de datos del cobro */
PROCEDURE PR_CTL_PAG_COBRANZA
 (P_COD_CAMPANA CR_CAMPANAS.COD_CAMPANA%TYPE DEFAULT NULL
 );
/* Proceso de actualización de pagos para actividades de cobranzas */
PROCEDURE PR_ACT_PAG_COBRANZA
 (P_NRO_CUENTA  GE_CUENTAS.NRO_CUENTA%TYPE,
  P_NRO_CUOTA   PR_CUOTAS.NRO_CUOTA%TYPE,
  P_FEC_COBRO   DATE,
  P_DIA_ATRASO  GE_CUENTAS.DIA_ATRASO%TYPE,
  P_MTO_COBRADO TA_COBROS.MONTO%TYPE
 );
END PAR_CAM;
/

