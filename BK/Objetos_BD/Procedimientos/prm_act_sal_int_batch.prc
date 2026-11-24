CREATE OR REPLACE PROCEDURE IT.PRM_ACT_SAL_INT_BATCH
 (P_FECHA IN GE_MOVIMIENTOS.FECHA%TYPE
 ,P_COD_OFICINA IN GE_MOVIMIENTOS.COD_OFICINA%TYPE
 ,P_NRO_CUENTA IN GE_MOVIMIENTOS.NRO_CUENTA%TYPE
 ,P_COD_MODALIDAD IN GE_MOVIMIENTOS.COD_MODALIDAD%TYPE
 ,P_MONTO IN GE_MOVIMIENTOS.MONTO%TYPE
 ,P_EST_CUENTA IN GE_MOVIMIENTOS.EST_CUENTA%TYPE
 ,P_REVERSADO IN GE_MOVIMIENTOS.REVERSADO%TYPE
 ,P_TIP_MOV_RUBRO IN GE_MOVIMIENTOS.TIP_MOV_RUBRO%TYPE
 ,P_AFECTA IN GE_TRANSACCIONES.AFECTA%TYPE
 )
 IS

V_MES NUMBER(2, 0);
V_ANIO NUMBER(4, 0);
v_monto ge_movimientos.monto%type;
Begin
   v_monto := nvl(p_monto,0);

   --- En prestamo el Credito corresponde a los cobros
   if p_tip_mov_rubro = 'C' then
      v_monto := v_monto * -1;
   end if;
   -- Actualiza de acuerdo al tipo de interes si es vencido el sal_int_batch, de lo contrario sal_int_ade_batch.
   update MD_CTA_DOCUMENTOS
      set SAL_INT_BATCH = nvl(SAL_INT_BATCH,0) + decode(nvl(tip_calculo,'V'), 'V', v_monto, 0)
    where NRO_CUENTA    = P_NRO_CUENTA;
   if sql%notfound then
      raise_application_error(-20000, 'No existe dato en Cta., # '||
                              P_NRO_CUENTA || ' Modal: ' || P_COD_MODALIDAD||
                              'Oficina: ' || P_COD_OFICINA);
   end if;
Exception
   When OTHERS Then
      raise_application_error(-20001,'Cuenta: '||P_NRO_CUENTA||
                   ' Importe: '||v_monto||' PRM_ACT_SAL_INT_BATCH. '||sqlerrm);
END;

 
/
