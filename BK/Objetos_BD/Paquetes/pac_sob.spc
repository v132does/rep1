CREATE OR REPLACE PACKAGE IT."PAC_SOB" IS
v_redondeo number(2) := 0;
v_tot_int_ant_sueldo number(18,2);
v_tot_int_ant_aguinaldo number(18,2);
/* Debita la cantidad de dias que estuvo excedido en la linea de su acu. */
FUNCTION FU_PRO_EXE_LINEA
 (P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE default null
 ,P_PROCESA IN VARCHAR2 default 'S'
 )
 RETURN NUMBER;
/* Debita los excesos de plazo, los que superan 30 dias de sobregiro */
FUNCTION FU_PRO_EXE_PLAZO
 (P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE DEFAULT NULL
 ,P_PROCESA IN VARCHAR2 DEFAULT 'S'
 )
 RETURN NUMBER;

/* Proceso de liquidacion de sobregiros */
PROCEDURE PR_PRO_LIQ_SOB
 (P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 ,P_PROCESAR IN VARCHAR2
 ,P_IMPUESTO OUT NUMBER
 ,P_INTERES OUT NUMBER
 ,p_manual in varchar2 default null);
/* Debita por el uso de x dias de linea de sobregiro */
FUNCTION FU_UTI_LINEA
 (P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE DEFAULT NULL
 ,P_PROCESA IN VARCHAR2 DEFAULT 'S'
 )
 RETURN NUMBER;
/* Obtiene la situacion del sobregiro */
FUNCTION FU_SIT_SOBREGIRO
 (P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 )
 RETURN VARCHAR2;
-- procedimiento que devuelve la utilizacion de lineas permanente y transitoria
procedure pr_obt_mto_uti_lineas
    (p_nro_cuenta              in varchar2,
     p_mto_uti_lin_permanente  out number,
     p_mto_uti_lin_transitoria out number,
     p_mto_uti_sin_linea       out number);

-- funcion que devuelve la utilizacion de lineas por tipo
FUNCTION fu_obt_mto_uti_lineas
 (P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 ,P_TIPO IN VARCHAR2 )
  return number;
-- procedimiento para el cobro de cargo particular por el uso de anticipo de sueldo o aguinado
-- solo valido para plan sueldo
FUNCTION FU_UTI_ANTICIPOS
 (P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE DEFAULT NULL
 ,P_PROCESA IN VARCHAR2 DEFAULT 'S'
 ,P_TIPO IN VARCHAR2 DEFAULT 'S'
 )
 RETURN NUMBER;
 --bbvades-3200
PROCEDURE PR_ACT_LIQ_SOB(P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE default null);
/* Motor de liquidacion masiva exclusivo de la cadena de cierre. */
PROCEDURE PR_LIQ_SOB_BATCH;
END PAC_SOB;
/
