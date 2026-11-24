CREATE OR REPLACE PACKAGE IT.PAS_BCP IS
v_tip_implementacion ge_par_generales.tip_implementacion%type := fug_obt_tip_implementacion;
v_rango1                   ge_movimientos.monto%type;
v_rango2                  ge_movimientos.monto%type;
v_rango3                  ge_movimientos.monto%type;
v_rango4                  ge_movimientos.monto%type;
v_rango5                  ge_movimientos.monto%type;
v_rango6                  ge_movimientos.monto%type;
v_sal_min_vigente          pr_parametros.sal_min_vigente%type;

/* Permite generar las tablas de encajes legales. */
PROCEDURE PR_GEN_ENCAJES;
/* Recuperar TAN - Res. 012022 */
FUNCTION FU_OBT_VAL_TIR
(
   p_inicial   IN NUMBER,
   p_can_items IN NUMBER,
   p_numeros   IN VARCHAR2,
   p_plazos    IN VARCHAR2
) RETURN NUMBER ;
/* Recuperar TIR */
FUNCTION FU_OBT_TIR_ADE
 (P_INICIAL IN NUMBER
 ,P_CAN_ITEMS IN NUMBER
 ,P_NUMEROS IN VARCHAR2
 ,P_DIAS IN NUMBER
 )
  RETURN NUMBER;
/* Recuperar TIR */
FUNCTION FU_OBT_TIR
 (P_INICIAL IN NUMBER
 ,P_CAN_ITEMS IN NUMBER
 ,P_NUMEROS IN VARCHAR2
 )
 RETURN NUMBER;
/* Obtener tasa efectiva. */
FUNCTION FU_OBT_TAE
 (P_TASA IN NUMBER
 ,P_PERIODO_CAPIT IN NUMBER
 )
 RETURN NUMBER;
/* Obtener tasa anual. */
FUNCTION FU_OBT_TAS_ANUAL
 (P_TIR IN NUMBER
 ,P_PERIODO_CAPIT IN NUMBER
 )
 RETURN NUMBER;
FUNCTION FU_OBT_CUP_VENCIDO
 (P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 )
 RETURN NUMBER;
/* Obtener tasa efectiva de CDA. */
FUNCTION FU_OBT_TAE_CDA
 (P_TIP_CAPITALIZACION IN AH_CTA_CERTIFICADOS.TIP_CAPITALIZACION%TYPE
 ,P_VAL_TASA IN NUMBER
 ,P_PLAZO IN NUMBER
 ,P_CAPITAL IN NUMBER
 )
 RETURN NUMBER;
/* Obtener tasa anual nominal de CDA */
FUNCTION FU_OBT_TAS_ANU_CDA
 (P_TIP_CAPITALIZACION IN NUMBER
 ,P_VAL_TASA IN NUMBER
 ,P_PLAZO IN NUMBER
 ,P_CAPITAL IN NUMBER
 )
 RETURN NUMBER;
/* Obtener el TIR para CDA */
FUNCTION FU_OBT_TIR_CDA
 (P_TIP_CAPITALIZACION IN NUMBER
 ,P_VAL_TASA IN NUMBER
 ,P_PLAZO IN NUMBER
 ,P_CAPITAL IN NUMBER
 )
 RETURN NUMBER;
/* Obtener tasa efectiva y nominal de prestamo */
PROCEDURE PR_OBT_TAS_PRESTAMO
 (P_NRO_SOLICITUD IN PR_CTA_PRESTAMOS.NRO_SOLICITUD%TYPE
 ,P_NRO_CUENTA IN PR_CTA_PRESTAMOS.NRO_CUENTA%TYPE
 ,P_VAL_TAE IN OUT NUMBER
 ,P_VAL_TAN IN OUT NUMBER
 );
/* Generar los registros de la tabla sb_estratifacion_dep el ultimo día. */
PROCEDURE PR_GEN_ESTRATIFICACI;
/* Buscar moneda fuerte */
FUNCTION FU_OBT_MON_FUERTE
 RETURN VARCHAR2;
/* Permite generar las tablas de liquidez */
PROCEDURE PR_GEN_ANA_LIQ;
/* Genera los depositoos en casa matriz y dependencias. */
PROCEDURE PR_GEN_DEP_OFICINAS;
/* Obtener fecha de vencimiento anterior del prestamos. */
FUNCTION FU_OBT_VTO_ANT_CUO
 (P_NRO_CUENTA IN PR_CTA_PRESTAMOS.NRO_CUENTA%TYPE
 ,P_NRO_CUOTA IN PR_CUOTAS.NRO_CUOTA%TYPE
 )
 RETURN DATE;
/* Genera las aperturas y calcula las tasas correspondientes. */
PROCEDURE PR_GEN_APE_TAS_SEM;
/* Obtener devengado total de CDA. */
FUNCTION FU_OBT_DEV_CDA
 (P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 ,P_CAPITAL IN AH_CTA_CERTIFICADOS.CAPITAL%TYPE
 ,P_FEC_APERTURA IN AH_CTA_CERTIFICADOS.FEC_APERTURA%TYPE
 ,P_FEC_CALCULO IN DATE
 )
 RETURN NUMBER;
/* Obtener devengado de Ahorro a la Vista. */
FUNCTION FU_OBT_DEV_AV
 (P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 ,P_FEC_ULT_CAPITALIZACION IN AH_CTA_VISTAS.FEC_ULT_CAPITALIZACION%TYPE
 )
 RETURN NUMBER;
PROCEDURE PR_GEN_DEP_INS_CAPTA;
/* Generar archivos ASCII del fonde de garantías. */
PROCEDURE PR_GEN_FDG_ASCII
 (P_FECHA IN DATE default null
 );
PROCEDURE PR_FON_GARANTIA;
/* Obtener devengado_his total de CDA. */
FUNCTION FU_OBT_DEV_CDA_HIS
 (P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 ,P_ANO IN AH_SAL_MENSUALES.ANO%TYPE
 ,P_MES IN AH_SAL_MENSUALES.MES%TYPE
 )
 RETURN NUMBER;

/* Genera detalle del Encaje para BCP */
PROCEDURE PR_GEN_ENCAJES_DET(P_FEC_ACTUAL IN date);

/* Genera Informe del Encaje Legal para BCP - Historico */
PROCEDURE PR_GEN_ENC_ASCII_HIS
  (P_FECHA IN DATE default null);

/* Genera Informe del Encaje Legal para BCP - Diario */
PROCEDURE PR_GEN_ENC_ASCII;

/* Circular 263/2011 - Inserta registros de Liquidez Diario - Inventario.*/
PROCEDURE PR_INS_LIQ_DIA_INV
  (P_FECHA IN DATE default null);
/* Circular 263/2011 - Inserta registros de Liquidez Diario - Contabilidad.*/
PROCEDURE PR_INS_LIQ_DIA_CON
  (P_FECHA IN DATE default null);
/* Generar Archivo Ascii Circular 263/2011 - Liquidez Diario.*/
PROCEDURE PR_GEN_LIQ_DIA_ASCII
  (P_FECHA IN DATE default null);

/* Permite generar el informe de encaje legal mensual en base a la informacion contenida en el informe
de encaje legal diario (ASCII) . */
PROCEDURE PR_GEN_ENC_MENSUAL(P_FECHA IN SB_ENCAJES_ML.FECHA%TYPE DEFAULT NULL);

/* Permite generar REPROCESO del informe de encaje legal mensual en base a la informacion contenida en el informe
de encaje legal diario (ASCII) . */
PROCEDURE PR_GEN_REP_ENC_MENSUAL;


/* Genera Informe Personas Inhibidas para BCP - Diario */
PROCEDURE PR_GEN_INHIBIDAS
          (P_FECHA IN DATE default null);

/* Genera Informe Personas Rehabilitadas de Inhibicion para BCP - Diario */
PROCEDURE PR_GEN_REHABILITADAS
          (P_FECHA IN DATE default null);

PROCEDURE PR_GEN_FDG_VALIDACION;

END PAS_BCP;
/

