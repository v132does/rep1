CREATE OR REPLACE PACKAGE IT.PAS_RES IS
V_TOT_DEUDA NUMBER(18);
V_LUGAR VARCHAR2(4000);
V_FEC_PROCESO DATE;
V_TIPO_CLIE GE_CLIENTES.TIPO%TYPE;
V_TIP_DESTINO GE_CLA_OPERACIONES.TIP_DESTINO%TYPE;
FUNCTION FU_CLI_SOLO_CONSUMO
 (P_COD_CLIE IN SB_CLIENTES.COD_PERSONA%TYPE
 )
 RETURN VARCHAR2;
/* Obtener garantía hipotecaria de la cuenta. */
FUNCTION FU_OBT_GAR_HIPOTE_SB
 (P_NRO_CUENTA IN GE_CTA_CLIENTES.NRO_CUENTA%TYPE
 )
 RETURN NUMBER;
/* Proceso principal de categorización según la resolución 8. */
PROCEDURE PR_PRO_CAT_RESOL8_SB
 (P_TIPO_PROCESO IN VARCHAR2 default 'T'
 );
/* Proceso de categorización de deudas de comercio exterior. */
PROCEDURE PR_PRO_DAT_IMPORTA_S;
/* Proceso de categorización de préstamos. */
PROCEDURE PR_PRO_DAT_PRESTA_SB;
/* Procesar categorización de cuentas corrientes sobregiradas. */
PROCEDURE PR_PRO_DAT_SOBREG_SB;
/* Procesar categorización de tarjetas de crédito. */
PROCEDURE PR_PRO_DAT_TARJE_SB;
/* Procesar categorización de clientes. */
PROCEDURE PR_PRO_CAT_CLIENT_SB;
/* Procesar categorización de grupos económicos. */
PROCEDURE PR_PRO_CAT_GRUECO_SB;
/* Proceso de cálculo de previsiones. */
PROCEDURE PR_CAL_PREVISION_SB;
/* Insertar datos en la tabla ge_cla_operaciones. */
PROCEDURE PR_INS_GE_CLA_OPERAC
 (RP_OPER IN GE_CLA_OPERACIONES%ROWTYPE
 );
/* Obtener la categoría que le corresponde x mora. */
FUNCTION FU_OBT_CAT_X_MORA_SB
 (P_CAN_DIAS IN NUMBER,
  P_COD_MODALIDAD IN PR_CTA_PRESTAMOS.COD_MODALIDAD%TYPE
 )
 RETURN NUMBER;
/* Verifica si el grupo económico tiene más de un cliente. */
FUNCTION FU_VER_GRU_MAS_CLIE
 (P_COD_GRU_ECONOMICO IN GE_GRU_ECONOMICOS.COD_GRU_ECONOMICO%TYPE
 )
 RETURN BOOLEAN;
END PAS_RES;
/

