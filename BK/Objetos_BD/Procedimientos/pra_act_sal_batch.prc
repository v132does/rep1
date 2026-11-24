CREATE OR REPLACE PROCEDURE IT.PRA_ACT_SAL_BATCH
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

V_MES NUMBER(2);
V_ANIO NUMBER(4);
v_afe_sal_total     number := 0;
v_afe_sal_retenido  number := 0;
v_afe_sal_bloqueado number := 0;
v_monto             ge_movimientos.monto%type;
v_mto_debito        ge_movimientos.monto%type;
v_mto_credito       ge_movimientos.monto%type;
v_can_debito        number(5) := 0;
v_can_credito       number(5) := 0;
Begin
   V_ANIO :=to_number(to_char(P_FECHA,'YYYY'));
   V_MES  :=to_number(to_char(P_FECHA,'MM'));

   v_mto_debito  := 0;
   v_mto_credito := 0;
   v_can_debito  := 0;
   v_can_credito := 0;
   v_monto       := nvl(p_monto,0);

   if p_tip_mov_rubro = 'D' then
      v_mto_debito := v_monto;
      v_can_debito := 1;
      v_monto := v_monto * -1;
   else
      v_mto_credito := v_monto;
      v_can_credito := 1;
   end if;
   if p_afecta = 'R' then -- afecta al saldo retenido
      if p_tip_mov_rubro = 'C' then
         v_afe_sal_total     := v_monto;
         v_afe_sal_retenido  := v_monto;
         v_afe_sal_bloqueado := 0;
      elsif p_tip_mov_rubro = 'D' then
         v_afe_sal_total     := 0;
         v_afe_sal_retenido  := v_monto;
         v_afe_sal_bloqueado := 0;
      end if;
   elsif p_afecta in ('S','C','I') then  -- afecta al saldo total, capital o interes
      v_afe_sal_total     := v_monto;
      v_afe_sal_retenido  := 0;
      v_afe_sal_bloqueado := 0;
   elsif p_afecta = 'B' then -- afecta al saldo bloqueado
      v_afe_sal_total     := 0;
      v_afe_sal_retenido  := 0;
      v_afe_sal_bloqueado := v_monto;
   else
       raise_application_error(-20000,'Esta operacion no afecta al saldo');
   end if;

   IF P_COD_MODALIDAD in (31,334) then
        update AH_CTA_VISTAS
           set SAL_TOT_BATCH = nvl(SAL_TOT_BATCH,0) + v_afe_sal_total,
               SAL_RET_BATCH = nvl(SAL_RET_BATCH,0) + v_afe_sal_retenido,
               SAL_BLO_BATCH = nvl(SAL_BLO_BATCH,0) + v_afe_sal_bloqueado
         where NRO_CUENTA = P_NRO_CUENTA;
        if sql%notfound then
           raise_application_error(-20000,'No existe dato en Ahorro a la Vista, # '||
                           P_NRO_CUENTA || ' Modal: ' || P_COD_MODALIDAD||
                                          'oficina: ' || P_COD_OFICINA);
        end if;
        IF P_REVERSADO = 'S' and NVL(TO_NUMBER(v_monto),0) < 0 THEN
           update AH_SAL_MENSUALES
              set CAN_CREDITOS  = CAN_CREDITOS + v_can_credito,
                  CAN_DEBITOS   = can_debitos + v_can_debito,
                  TOT_CREDITOS  = TOT_CREDITOS + v_mto_credito,
                  TOT_DEBITOS   = TOT_DEBITOS + v_mto_debito
            where NRO_CUENTA    = P_NRO_CUENTA    and
                  ANO           = V_ANIO          and
                  MES           = V_MES;
          ELSE
           update AH_SAL_MENSUALES
              set CAN_CREDITOS  = CAN_CREDITOS + v_can_credito,
                  CAN_DEBITOS   = can_debitos + v_can_debito,
                  TOT_CREDITOS  = TOT_CREDITOS + v_mto_credito,
                  TOT_DEBITOS   = TOT_DEBITOS + v_mto_debito
            where NRO_CUENTA    = P_NRO_CUENTA    and
                  ANO           = V_ANIO          and
                  MES           = V_MES;
          END IF;
          --- No debe dar error si no encuentra registro..
    END IF;
    IF P_COD_MODALIDAD in (32,37,38) then
       update AH_CTA_PLAZOS
          set SAL_TOT_BATCH = nvl(SAL_TOT_BATCH,0) + v_afe_sal_total,
              SAL_RET_BATCH = nvl(SAL_RET_BATCH,0) + v_afe_sal_retenido,
              SAL_BLO_BATCH = nvl(SAL_BLO_BATCH,0) + v_afe_sal_bloqueado
        where  NRO_CUENTA = P_NRO_CUENTA;
              if sql%notfound then
                 raise_application_error(-20000,'No existe dato en Ahorro a Plazo Fijo, # '||
                                P_NRO_CUENTA || ' Modal: ' || P_COD_MODALIDAD||
                                'Oficina: ' || P_COD_OFICINA);
              end if;
    end if;
    if P_COD_MODALIDAD IN (33,34,35,36) then
       update AH_CTA_CERTIFICADOS
          set SAL_TOT_BATCH = nvl(SAL_TOT_BATCH,0) + v_afe_sal_total,
              SAL_RET_BATCH = nvl(SAL_RET_BATCH,0) + v_afe_sal_retenido,
              SAL_BLO_BATCH = nvl(SAL_BLO_BATCH,0) + v_afe_sal_bloqueado
        where NRO_CUENTA = P_NRO_CUENTA;
              if sql%notfound then
                raise_application_error(-20000,'No existe dato en Certificados, # '||
                               P_NRO_CUENTA || ' Modal: ' || P_COD_MODALIDAD||
                               'Oficina: ' || P_COD_OFICINA);
              end if;
    end if;
    if P_COD_MODALIDAD = 41 then
       update CC_CTA_CORRIENTES
          set SAL_TOT_BATCH = nvl(SAL_TOT_BATCH,0) + v_afe_sal_total,
              SAL_RET_BATCH = nvl(SAL_RET_BATCH,0) + v_afe_sal_retenido,
              SAL_BLO_BATCH = nvl(SAL_BLO_BATCH,0) + v_afe_sal_bloqueado
        where NRO_CUENTA = P_NRO_CUENTA;
             if sql%notfound then
                raise_application_error(-20000, 'No existe dato en Cuenta Corriente, # '||
                               P_NRO_CUENTA || ' Modal: ' || P_COD_MODALIDAD||
                               'Oficina: ' || P_COD_OFICINA);
             end if;
             IF P_REVERSADO = 'S' and
                    NVL(TO_NUMBER(v_MONTO),0) < 0 THEN
                    update CC_SAL_MENSUALES
                      set CAN_CREDITOS  = NVL(CAN_CREDITOS,0) + v_can_credito,
                          CAN_DEBITOS   = NVL(can_debitos,0) + v_can_debito,
                          TOT_CREDITOS  = NVL(TOT_CREDITOS,0)+ v_mto_credito,
                          TOT_DEBITOS   = NVL(TOT_DEBITOS,0) + v_mto_debito
                    where NRO_CUENTA = P_NRO_CUENTA and
                          ANO = V_ANIO              and
                          MES = V_MES;
            ELSE
                    update CC_SAL_MENSUALES
                      set CAN_CREDITOS  = NVL(CAN_CREDITOS,0) + v_can_credito,
                          CAN_DEBITOS   = NVL(can_debitos,0) + v_can_debito,
                          TOT_CREDITOS  = NVL(TOT_CREDITOS,0) + v_mto_credito,
                          TOT_DEBITOS   = NVL(TOT_DEBITOS,0) + v_mto_debito
                    where NRO_CUENTA = P_NRO_CUENTA and
                          ANO = V_ANIO              and
                          MES = V_MES;
            END IF;
            --- No debe dar error si no encuentra registro..
    END IF;
     If P_COD_MODALIDAD IN (42,43,44,45,46,47,48,49,442,455) then --WA:21/02/2014 se agrega condici?n 455 para SIPAP
       update CC_CTA_BANCARIAS
          set SAL_TOT_BATCH = nvl(SAL_TOT_BATCH,0) + v_afe_sal_total,
              SAL_RET_BATCH = nvl(SAL_RET_BATCH,0) + v_afe_sal_retenido,
              SAL_BLO_BATCH = nvl(SAL_BLO_BATCH,0) + v_afe_sal_bloqueado
        where NRO_CUENTA = P_NRO_CUENTA;
             if sql%notfound then
                raise_application_error(-20000, 'No existe dato en Cuenta Bancaria, # '||
                               P_NRO_CUENTA || ' Modal: ' || P_COD_MODALIDAD||
                               'Oficina: ' || P_COD_OFICINA);
             end if;
    End if;
    Exception
    When OTHERS Then
         raise_application_error(-20001,'Cuenta: '||P_NRO_CUENTA||
         ' Importe: '||v_monto||' Pra_act_sal_batch. '||sqlerrm);
END;
/
