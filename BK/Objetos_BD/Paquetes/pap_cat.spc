CREATE OR REPLACE PACKAGE IT.pap_cat IS

V_MON_LOCAL BA_MONEDAS.COD_MONEDA%TYPE;
V_MON_FUERTE BA_MONEDAS.COD_MONEDA%TYPE;
V_COT_MON_FUERTE GE_COTIZACIONES.VAL_CONVERSION%TYPE;
V_TOT_DEUDA NUMBER(18);
V_TIPO_CLIE GE_CLIENTES.TIPO%TYPE;
V_LUGAR VARCHAR2(4000);
V_FEC_PROCESO DATE;

/* Verificar si un cliente es de solo consumo. */
FUNCTION FU_CLI_SOLO_CONSUMO
 (P_COD_CLIE IN GE_CLIENTES.COD_PERSONA%TYPE
 )
 RETURN VARCHAR2;
/* Verificar si un cliente es de solo vivienda. */
FUNCTION FU_CLI_SOLO_VIVIENDA
 (P_COD_CLIE IN GE_CLIENTES.COD_PERSONA%TYPE
 )
 RETURN VARCHAR2;
/* Convertir un monto a guaranies. */
FUNCTION FU_CON_A_GUARANIES
 (P_COD_MONEDA IN BA_MONEDAS.COD_MONEDA%TYPE
 ,P_MONTO IN PR_CTA_PRESTAMOS.MTO_CAPITAL%TYPE
 )
 RETURN NUMBER;
/* Obtener la categoria que le corresponde x mora. */
FUNCTION FU_OBT_CATEG_X_MORA
 (P_CAN_DIAS IN NUMBER
 )
 RETURN NUMBER;
/* Obtiene el valor total de la garantia de un cliente. */
FUNCTION FU_OBT_TOT_GAR_CLIE
 (P_COD_CLIE IN GE_CLIENTES.COD_PERSONA%TYPE
 ,P_TOT_DEUDA IN PR_CTA_PRESTAMOS.MTO_CAPITAL%TYPE
 )
 RETURN NUMBER;
/* Proceso principal de categorizacion segun la resolucion 37. */
PROCEDURE PR_PRO_CAT_RES37
 (P_TIPO_PROCESO IN VARCHAR2 := 'T'
 );
/* Procesar categorizacion de clientes. */
PROCEDURE PR_PRO_CAT_CLIENTES;
/* Procesar categorizacion de grupos economicos. */
PROCEDURE PR_PRO_CAT_GRU_ECON;
/* Proceso de categorización de deudas de comercio exterior. */
PROCEDURE PR_PRO_DAT_IMPORTAC;
/* Proceso de categorización de deudas de bonos privados. */
PROCEDURE PR_PRO_DAT_BONOS;
/* Proceso de categorizacion de prestamos. */
PROCEDURE PR_PRO_DAT_PRESTAMO;
/* Procesar categorización de cuentas corrientes sobregiradas. */
PROCEDURE PR_PRO_DAT_SOBREGIRO;

/* Procesar categorizacion de tarjetas de credito. */
PROCEDURE PR_PRO_DAT_TARJETAS;
/* Procesar categorizacion de Operaciones Vencidas */
PROCEDURE PR_PRO_DAT_OPE_VEN;

/* Insertar datos en la tabla GE_CLA_OPERACIONES. */
PROCEDURE PR_INS_SB_CLA_OPERAC
 (RP_OPER IN GE_CLA_OPERACIONES%ROWTYPE
 );
/* Obtiene el valor total de las garantias x la operacion de prestamo. */
FUNCTION FU_OBT_TOT_GAR_X_OPE
 (P_NRO_CUENTA IN PR_CTA_PRESTAMOS.NRO_CUENTA%TYPE,
  P_TOT_DEUDA IN NUMBER DEFAULT NULL --- para q siga funcionando con la Res. Actual
 )
 RETURN NUMBER;
/* Verifica si el cliente esta relacionado con la entidad. */
FUNCTION FU_VER_CLI_REL_ENTI
 (P_COD_PERSONA IN VARCHAR2
 )
 RETURN BOOLEAN;

/* Solo para RRR, se verifica la forma de pago de la nueva operacion */
PROCEDURE PR_OBT_FOR_PAG_RRR
 (P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE,
  P_CATEGORIA  IN GE_CLA_OPERACIONES.CAT_AUTOMATICA%TYPE,
  P_MTO_ORIGINAL IN GE_CLA_OPERACIONES.MTO_ORIGINAL%TYPE,
  P_SAL_CAPITAL  IN GE_CLA_OPERACIONES.MTO_ORIGINAL%TYPE,
  P_FEC_ULT_CATEGORIZACION IN PR_CTA_PRESTAMOS.FEC_ULT_CATEGORIZACION%TYPE,
  P_PUE_CATEGORIA IN OUT VARCHAR2,  --- Puede mejorar categoria S/N
  P_PUE_PREVISION IN OUT VARCHAR2); --- Puede liberar prevision S/N

/* Verifica si el grupo economico tiene mas de un cliente. */
FUNCTION FU_VER_GRU_MAS_CLIE
 (P_COD_GRU_ECONOMICO IN GE_GRU_ECONOMICOS.COD_GRU_ECONOMICO%TYPE
 )
 RETURN BOOLEAN;
/*Retorna la categoria del cliente segun una fecha dada. Circular 00460/2006 FARASOP-182*/
FUNCTION FU_OBT_CAT_CLIENTE
 (P_COD_PERSONA IN GE_CLIENTES.COD_PERSONA%TYPE
 ,P_FECHA       IN DATE DEFAULT NULL
 )
 RETURN NUMBER;
/*Retorna la ultima categoria del cliente enviada a la CRC.*/
FUNCTION fu_obt_cat_crc
(
   p_cod_persona      IN ge_clientes.cod_persona%TYPE,
   p_fecha            IN DATE DEFAULT NULL,
   p_con_subcategoria IN VARCHAR2 DEFAULT NULL
)
RETURN varchar2;

END PAP_CAT;
/

