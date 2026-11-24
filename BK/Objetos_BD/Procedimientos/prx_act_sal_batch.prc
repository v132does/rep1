CREATE OR REPLACE PROCEDURE IT.PRX_ACT_SAL_BATCH
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
   --- En CCI el Crédito corresponde a los cobros
   if p_tip_mov_rubro = 'C' then
      v_monto := v_monto * -1;
   end if;

   if p_cod_modalidad = 81 then
     update CX_CTA_IMPORTACIONES
        set SAL_BATCH = nvl(SAL_BATCH,0) + v_monto
      where NRO_CUENTA    = P_NRO_CUENTA;
     if sql%notfound then
        raise_application_error(-20000, 'No existe dato en CCI, # '|| P_NRO_CUENTA || ' Modal: ' || P_COD_MODALIDAD||
                                'Oficina: ' || P_COD_OFICINA);
     end if;
   elsif p_cod_modalidad = 82 then
     update CX_CTA_EXPORTACIONES
        set SAL_BATCH = nvl(SAL_BATCH,0) + v_monto
      where NRO_CUENTA    = P_NRO_CUENTA;
     if sql%notfound then
        raise_application_error(-20000, 'No existe dato en CCE, # '|| P_NRO_CUENTA || ' Modal: ' || P_COD_MODALIDAD||
                                'Oficina: ' || P_COD_OFICINA);
     end if;
   elsif p_cod_modalidad in (83,84) then
     update CX_CTA_COBRANZAS
        set SAL_BATCH = SAL_BATCH + v_monto
      where NRO_CUENTA    = P_NRO_CUENTA;
     if sql%notfound then
        raise_application_error(-20000, 'No existe dato en Cobranzas, # '|| P_NRO_CUENTA || ' Modal: ' || P_COD_MODALIDAD||
                                'Oficina: ' || P_COD_OFICINA);
     end if;
   end if;
Exception
   When OTHERS Then
      raise_application_error(-20001,'Cuenta: '||P_NRO_CUENTA||' Importe: '||v_monto||' PRX_ACT_SAL_BATCH. '||sqlerrm);
END;

 
/
