CREATE OR REPLACE FUNCTION IT.FUP_OBT_TRANSACCION
 (P_CONCEPTO IN PR_COB_PRIORIDADES.CONCEPTO%TYPE
 ,P_ESTADO IN PR_CTA_PRESTAMOS.ESTADO%TYPE
 ,P_TIPO IN PR_CTA_PRESTAMOS.TIPO%TYPE
 ,P_TIP_INTERES IN PR_CTA_PRESTAMOS.TIP_INTERES%TYPE
 ,P_NRO_CUENTA IN PR_CTA_PRESTAMOS.NRO_CUENTA%TYPE
 ,P_COD_ORI_FONDO IN PR_CTA_PRESTAMOS.COD_ORI_FONDO%TYPE
 ,P_EST_NUEVO IN PR_CTA_PRESTAMOS.ESTADO%TYPE
 ,P_OPERACION IN VARCHAR2 DEFAULT 'C')

 RETURN NUMBER
 IS
v_cod_transaccion ge_transacciones.cod_transaccion%type := NULL;
v_descripcion ge_movimientos.concepto%type;
/* función que retorna la transacción que se debe usar por cobro o cambio de situación, teniendo 
   en cuenta las condiciones del préstamo */

BEGIN
   --llama al procedimiento que realiza las evaluaciones correspondientes y retorna la transacción
   prp_obt_transaccion(P_CONCEPTO, P_ESTADO, P_TIPO, P_TIP_INTERES, P_NRO_CUENTA, P_COD_ORI_FONDO, P_EST_NUEVO, P_OPERACION,
                       v_cod_transaccion, v_descripcion);
   
   return NVL(v_cod_transaccion,-1); --- Para que de error de transaccion si no recupera nada

exception
  when others then
    if sqlcode >= -20000 then
      raise;
    else
      raise_application_error(-20000,'Recup.Transacc. Cta.'||P_NRO_CUENTA||' Est.'||P_ESTADO||' Tipo '||P_TIPO||' Int.'||P_TIP_INTERES
                                    ||' Ori.Fondo '||P_COD_ORI_FONDO||'-'||sqlerrm);
    end if;
END;
/

