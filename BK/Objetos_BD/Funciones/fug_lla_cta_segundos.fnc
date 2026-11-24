create or replace function it.FUG_LLA_CTA_SEGUNDOS(P_COD_MODALIDAD IN GE_MODALIDADES.COD_MODALIDAD%TYPE
 ,P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 ,P_NOCTURNO IN CHAR default 'N'
 ,P_CAN_SEGUNDOS NUMBER default 0
 )
 RETURN VARCHAR2
 IS
/*
DYDMR-3395 funcion que realiza control de uso de la cuenta P_NRO_CUENTA (llaveo) 
 espera P_CAN_SEGUNDOS antes de devolver N 
 basada en PAG_CTA.FU_LLAVEAR_CUENTA
*/
V_RESPUESTA varchar2(1);
BEGIN

  IF p_cod_modalidad = 31 THEN
     IF p_nocturno = 'N' THEN

         EXECUTE IMMEDIATE 'SELECT ''S''
         FROM AH_CTA_VISTAS
         WHERE nro_cuenta = '||P_NRO_CUENTA||
          ' FOR UPDATE OF nro_cuenta WAIT '|| P_CAN_SEGUNDOS
        INTO V_RESPUESTA;
      RETURN(V_RESPUESTA);
     ELSE

         EXECUTE IMMEDIATE 'SELECT ''S''
         FROM AH_CTA_VISTAS_NOC
         WHERE nro_cuenta = '||P_NRO_CUENTA||
          ' FOR UPDATE OF nro_cuenta WAIT '|| P_CAN_SEGUNDOS
        INTO V_RESPUESTA;
      RETURN(V_RESPUESTA);
    END IF;

   ELSIF p_cod_modalidad = 41 THEN
     IF p_nocturno = 'N' THEN
       EXECUTE IMMEDIATE 'SELECT ''S''
         FROM CC_CTA_CORRIENTES
         WHERE nro_cuenta = '||P_NRO_CUENTA||
          ' FOR UPDATE OF nro_cuenta WAIT '|| P_CAN_SEGUNDOS
        INTO V_RESPUESTA;
      RETURN(V_RESPUESTA);
     ELSE
      EXECUTE IMMEDIATE 'SELECT ''S''
         FROM CC_CTA_CORRIENTES_NOC
         WHERE nro_cuenta = '||P_NRO_CUENTA||
          ' FOR UPDATE OF nro_cuenta WAIT '|| P_CAN_SEGUNDOS
        INTO V_RESPUESTA;
      RETURN(V_RESPUESTA);
     END IF;
   --30/07/2014: BBVANOR-1259 - Operaciones con Financieras del País sin Banco Sponsor
   ELSIF p_cod_modalidad in (42, 43, 44, 45, 46, 47, 48, 49, 442, 455) THEN
      EXECUTE IMMEDIATE 'SELECT ''S''
         FROM CC_CTA_BANCARIAS
         WHERE nro_cuenta = '||P_NRO_CUENTA||
          ' FOR UPDATE OF nro_cuenta WAIT '|| P_CAN_SEGUNDOS
        INTO V_RESPUESTA;
      RETURN(V_RESPUESTA);
   ELSIF p_cod_modalidad IN (33,34,35,36) THEN
      EXECUTE IMMEDIATE 'SELECT ''S''
         FROM AH_CTA_CERTIFICADOS
         WHERE nro_cuenta = '||P_NRO_CUENTA||
          ' FOR UPDATE OF nro_cuenta WAIT '|| P_CAN_SEGUNDOS
        INTO V_RESPUESTA;
      RETURN(V_RESPUESTA);
   ELSIF p_cod_modalidad IN (32) THEN
      EXECUTE IMMEDIATE 'SELECT ''S''
         FROM AH_CTA_PLAZOS
         WHERE nro_cuenta = '||P_NRO_CUENTA||
          ' FOR UPDATE OF nro_cuenta WAIT '|| P_CAN_SEGUNDOS
        INTO V_RESPUESTA;
      RETURN(V_RESPUESTA);
   ELSE
       RAISE_APPLICATION_ERROR(-20000,'ERROR. Llaveo de Cuenta '||p_nro_cuenta||' Incorrecta');
   END IF;

   RETURN('N');

EXCEPTION
 WHEN OTHERS THEN
     RETURN('N');
end;
/

