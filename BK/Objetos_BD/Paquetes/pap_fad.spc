CREATE OR REPLACE PACKAGE IT.PAP_FAD IS
/* Insertar Validaciones. */
PROCEDURE PR_INS_VALIDACIONES (P_NRO_SOLICITUD  PR_FAD_CHE_VAL_DET.NRO_SOLICITUD%TYPE,
                               P_NRO_SECUENCIA  PR_FAD_CHE_VAL_DET.NRO_SECUENCIA%TYPE,
                               P_COD_PERSONA    PR_FAD_CHE_VAL_DET.COD_PERSONA%TYPE,
                               P_RELACION       PR_FAD_CHE_VAL_DET.RELACION%TYPE,
                               P_NRO_CUOTA      PR_FAD_CHE_VAL_DET.NRO_CUOTA%TYPE,
                               P_COD_BANCO      PR_FAD_CHE_VAL_DET.COD_BANCO%TYPE,
                               P_NRO_CHEQUE     PR_FAD_CHE_VAL_DET.NRO_CHEQUE%TYPE,
                               P_CTA_LIBRADORA  PR_FAD_CHE_VAL_DET.CTA_LIBRADORA%TYPE,
                               P_NRO_VALIDACION PR_FAD_CHE_VAL_DET.NRO_VALIDACION%TYPE,
                               P_TIP_VALIDACION PR_FAD_CHE_VAL_DET.TIP_VALIDACION%TYPE,
                               P_ABR_VALIDACION PR_FAD_CHE_VAL_DET.ABR_VALIDACION%TYPE,
                               P_OBSERVACION    PR_FAD_CHE_VAL_DET.OBSERVACION%TYPE,
                               P_AFE_LIM_CRE    VARCHAR2 DEFAULT NULL) ;

/* Obtener referencia de Validación. */
PROCEDURE PR_OBT_REF_VALIDACION (P_DOMINIO     IN  BA_COD_REFERENCIAS.DOMINIO%TYPE,
                                 P_VALOR       IN  BA_COD_REFERENCIAS.VAL_MINIMO%TYPE,
                                 P_TIP_VAL     OUT BA_COD_REFERENCIAS.VAL_MAXIMO%TYPE,
                                 P_VALIDACION  OUT BA_COD_REFERENCIAS.ABREVIATURA%TYPE,
                                 P_TIE_ERR_BLO IN OUT VARCHAR2);

/* Obtener faja del cliente. */
FUNCTION FU_OBT_FAJ_INFORMCONF (P_COD_PERSONA IN PR_FAD_SOLICITUDES.COD_PERSONA%TYPE ) RETURN VARCHAR2;

/* Obtener Situación Infocheck del Cliente. */
FUNCTION FU_OBT_SIT_INFOCHECK (P_COD_PERSONA IN PR_FAD_SOLICITUDES.COD_PERSONA%TYPE ) RETURN VARCHAR2;

/* Obtener Saldo Línea de Crédito del Cliente. */
FUNCTION FU_OBT_CLI_LIN_CREDITO (P_COD_PERSONA   IN PR_FAD_SOLICITUDES.COD_PERSONA%TYPE,
                                 P_COD_MONEDA    IN PR_FAD_SOLICITUDES.COD_MONEDA%TYPE,
                                 P_COD_MODALIDAD IN GE_MODALIDADES.COD_MODALIDAD%TYPE default null,
                                 P_TIPO          IN VARCHAR2 default null) RETURN VARCHAR2;
/* Obtener Concentración del Librador por Operación. */
FUNCTION FU_OBT_CONCENTRACION (P_NRO_SOLICITUD     IN PR_FAD_REL_CHE_LIB.NRO_SOLICITUD%TYPE,                                   
                               P_COD_TIP_DOCUMENTO IN PR_FAD_REL_CHE_LIB.COD_TIP_DOCUMENTO%TYPE,
                               P_NRO_DOCUMENTO     IN PR_FAD_REL_CHE_LIB.NRO_DOCUMENTO%TYPE) RETURN NUMBER;

/* Verificar cheques cruzados entre Deudor y Librador. */
FUNCTION FU_VER_CHE_CRUZADOS (P_COD_PER_DEUDOR IN PR_FAD_SOLICITUDES.COD_PERSONA%TYPE,
                              P_COD_PER_LIB IN PR_FAD_SOLICITUDES.COD_PERSONA%TYPE,
                              P_TIP_DOC_LIB IN PR_CHQ_LIBRADORES.COD_TIP_DOCUMENTO%TYPE,
                              P_NRO_DOC_LIB IN PR_CHQ_LIBRADORES.NRO_DOCUMENTO%TYPE,
                              P_TIPO        IN VARCHAR2,
                              P_CUENTAS IN OUT VARCHAR2) RETURN NUMBER; 

/* Obtener Información Antecedentes - Informconf  */
FUNCTION FU_OBT_ANT_INFORMCONF (P_COD_PERSONA  IN PR_FAD_SOLICITUDES.COD_PERSONA%TYPE,
                                P_COD_TIP_SERV IN NUMBER ) RETURN NUMBER;

/* Obtener Información Antecedentes - Infocheck  */
FUNCTION FU_OBT_ANT_INFOCHECK (P_COD_PERSONA   IN PR_FAD_SOLICITUDES.COD_PERSONA%TYPE,
                               P_COD_TIP_SERV  IN VARCHAR2,
                               P_NRO_SOLICITUD IN PR_FAD_SOLICITUDES.NRO_SOLICITUD%TYPE DEFAULT NULL  ) RETURN NUMBER;                                                                

/* Procedimiento principal de Validación de la Operación. */
PROCEDURE PR_VAL_OPERACION(P_NRO_SOLICITUD IN PR_FAD_SOLICITUDES.NRO_SOLICITUD%TYPE,
                           P_ERROR         IN OUT NUMBER,
                           P_DES_ERROR     IN OUT VARCHAR2);

/* Obtener tipo de Persona según Tipo y Nro de Documento. */
FUNCTION FU_OBT_TIP_PERSONA (P_COD_TIP_DOC IN PR_FAD_REL_CHE_LIB.COD_TIP_DOCUMENTO%TYPE,
                             P_NRO_DOCUMENTO IN PR_FAD_REL_CHE_LIB.NRO_DOCUMENTO%TYPE) RETURN VARCHAR2;
                             
/* Insertar como persona a Libradores, por Operación. */
PROCEDURE PR_INS_PERSONAS (P_NRO_SOLICITUD IN PR_FAD_SOLICITUDES.NRO_SOLICITUD%TYPE);

/* Aprobar Operacion */
PROCEDURE PR_APR_VALIDACION (P_NRO_SOLICITUD IN PR_FAD_SOLICITUDES.NRO_SOLICITUD%TYPE);

/* Cancelar Operacion */
PROCEDURE PR_CAN_VALIDACION (P_NRO_SOLICITUD IN PR_FAD_SOLICITUDES.NRO_SOLICITUD%TYPE);

/* Vincular/Desvincular Solicitud con Operacion */
PROCEDURE PR_VIN_SOL_VALIDACION (P_NRO_SOL_VAL IN PR_FAD_SOLICITUDES.NRO_SOLICITUD%TYPE,
                                 P_TIPO        IN VARCHAR2,
                                 P_TIP_AFE_LIM IN PR_FAD_CHE_CUSTODIAS.TIP_AFE_LIM_CRE%TYPE,
                                 P_NRO_SOL_PRE IN PR_SOLICITUDES.NRO_SOLICITUD%TYPE default null);
/* Insertar en la tabla pr_dat_cheques_tmp (PMDESDOC) */
PROCEDURE PR_INS_DAT_CHEQUES_TMP (P_NRO_SOLICITUD IN PR_FAD_SOLICITUDES.NRO_SOLICITUD%TYPE,
                                  P_AFE_LIM_CRED  IN PR_FAD_CHE_CUSTODIAS.TIP_AFE_LIM_CRE%TYPE);

/* Cancelación Masiva de Operacion por Vencimiento */
PROCEDURE PR_CAN_MAS_VALIDACION (P_TIPO IN VARCHAR2,
                                 P_CANT OUT NUMBER);

/* Procesar consultas a Informconf */
PROCEDURE PR_PRO_INFORMCONF (P_NRO_SOLICITUD IN PR_FAD_SOLICITUDES.NRO_SOLICITUD%TYPE);

/* Procesar consultas a Infocheck */
PROCEDURE PR_PRO_INFOCHECK (P_NRO_SOLICITUD IN PR_FAD_SOLICITUDES.NRO_SOLICITUD%TYPE);                                 

END PAP_FAD;
/

