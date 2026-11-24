CREATE OR REPLACE PROCEDURE IT.PRA_TOT_RET_BATCH
 (P_FECHA IN GE_MOVIMIENTOS.FECHA%TYPE
 ,P_COD_OFICINA IN GE_MOVIMIENTOS.COD_OFICINA%TYPE
 ,P_NRO_CUENTA IN GE_MOVIMIENTOS.NRO_CUENTA%TYPE
 ,P_COD_MODALIDAD IN GE_MOVIMIENTOS.COD_MODALIDAD%TYPE
 ,P_MONTO IN GE_MOVIMIENTOS.MONTO%TYPE
 ,P_EST_CUENTA IN GE_MOVIMIENTOS.EST_CUENTA%TYPE
 ,P_COD_TRA_PADRE IN GE_MOVIMIENTOS.COD_TRA_PADRE%TYPE
 ,P_REVERSADO IN GE_MOVIMIENTOS.REVERSADO%TYPE
 ,P_TIP_MOV_RUBRO IN GE_MOVIMIENTOS.TIP_MOV_RUBRO%TYPE
 )
 IS

V_MES NUMBER(2, 0);
V_ANIO NUMBER(4, 0);
V_MSJ_ERROR VARCHAR2(100);
V_MONTO GE_MOVIMIENTOS.TIP_MOV_RUBRO%TYPE;
Begin
    V_ANIO :=to_number(to_char(to_date(P_FECHA,'DDMMYYYY'),'YYYY'));
    V_MES  :=to_number(to_char(to_date(P_FECHA,'DDMMYYYY'),'MM'));

    IF P_COD_MODALIDAD = 31 then
        update AH_CTA_VISTAS
           set SAL_TOT_BATCH = nvl(SAL_TOT_BATCH,0) + nvl(P_MONTO,0),
               SAL_RET_BATCH = nvl(SAL_RET_BATCH,0) + nvl(P_MONTO,0)
         where COD_MODALIDAD = P_COD_MODALIDAD and
                 COD_OFICINA = P_COD_OFICINA and
                  NRO_CUENTA = P_NRO_CUENTA;
        if sql%notfound then
           V_MSJ_ERROR := 'No existe dato en Ahorro a la Vista, # '||
                           P_NRO_CUENTA || ' Modal: ' || P_COD_MODALIDAD||
                                          'oficina: ' || P_COD_OFICINA;
        end if;
        IF P_REVERSADO = 'S' and NVL(TO_NUMBER(P_MONTO),0) < 0 THEN
           update AH_SAL_MENSUALES
              set CAN_CREDITOS = nvl(CAN_CREDITOS,0) - 1,
                  TOT_CREDITOS = NVL(TOT_CREDITOS,0) + NVL(TO_NUMBER(P_MONTO),0)
            where COD_MODALIDAD = P_COD_MODALIDAD and
                  COD_OFICINA = P_COD_OFICINA and
                  NRO_CUENTA = P_NRO_CUENTA and
                  ANO = V_ANIO              and
                  MES = V_MES;
        ELSE
           update AH_SAL_MENSUALES
              set CAN_CREDITOS = nvl(CAN_CREDITOS,0) + 1,
                  TOT_CREDITOS = NVL(TOT_CREDITOS,0) + NVL(TO_NUMBER(P_MONTO),0)
            where COD_MODALIDAD = P_COD_MODALIDAD and
                  COD_OFICINA = P_COD_OFICINA and
                  NRO_CUENTA = P_NRO_CUENTA and
                  ANO = V_ANIO              and
                  MES = V_MES;
        END IF;
        if sql%notfound then
            V_MSJ_ERROR := 'No existe dato en Saldos Mensuales, # '||
                           P_NRO_CUENTA || ' Modal: ' || P_COD_MODALIDAD||
                           'Oficina: ' || P_COD_OFICINA||
                           ' Anio: '|| TO_CHAR(V_ANIO)||
                           ' Mes: '||TO_CHAR(V_MES);

        end if;
    END IF;
    IF P_COD_MODALIDAD in (32,37,38) then
       update AH_CTA_PLAZOS
          set SAL_TOT_BATCH = nvl(SAL_TOT_BATCH,0) + nvl(P_MONTO,0),
              SAL_RET_BATCH = nvl(SAL_RET_BATCH,0) + nvl(P_MONTO,0)
        where COD_MODALIDAD = P_COD_MODALIDAD and
              COD_OFICINA = P_COD_OFICINA and
              NRO_CUENTA = P_NRO_CUENTA;
              if sql%notfound then
                 V_MSJ_ERROR := 'No existe dato en Ahorro a Plazo Fijo, # '||
                                P_NRO_CUENTA || ' Modal: ' || P_COD_MODALIDAD||
                                'Oficina: ' || P_COD_OFICINA;
              end if;
    end if;
    if P_COD_MODALIDAD IN (33,34,35,36) then
       update AH_CTA_CERTIFICADOS
          set SAL_TOT_BATCH = nvl(SAL_TOT_BATCH,0) + nvl(P_MONTO,0),
              SAL_RET_BATCH = nvl(SAL_RET_BATCH,0) + nvl(P_MONTO,0)
        where COD_MODALIDAD = P_COD_MODALIDAD and
              COD_OFICINA = P_COD_OFICINA and
              NRO_CUENTA = P_NRO_CUENTA;
              if sql%notfound then
                V_MSJ_ERROR := 'No existe dato en Certificados, # '||
                               P_NRO_CUENTA || ' Modal: ' || P_COD_MODALIDAD||
                               'Oficina: ' || P_COD_OFICINA;
              end if;
    end if;
    if P_COD_MODALIDAD = 41 or
       P_COD_MODALIDAD = 42 then
       update CC_CTA_CORRIENTES
          set SAL_TOT_BATCH = nvl(SAL_TOT_BATCH,0) + nvl(P_MONTO,0),
              SAL_RET_BATCH = nvl(SAL_RET_BATCH,0) + nvl(P_MONTO,0)
        where COD_MODALIDAD = P_COD_MODALIDAD and
              COD_OFICINA = P_COD_OFICINA and
              NRO_CUENTA = P_NRO_CUENTA;
             if sql%notfound then
                V_MSJ_ERROR := 'No existe dato en Cuenta Corriente, # '||
                               P_NRO_CUENTA || ' Modal: ' || P_COD_MODALIDAD||
                               'Oficina: ' || P_COD_OFICINA;
             end if;
             IF P_REVERSADO = 'S' and
                    NVL(TO_NUMBER(P_MONTO),0) < 0 THEN
                    update CC_SAL_MENSUALES
                    set CAN_CREDITOS = nvl(CAN_CREDITOS,0) - 1,
                        TOT_CREDITOS = NVL(TOT_CREDITOS,0) +
                                     NVL(TO_NUMBER(P_MONTO),0)
                    where COD_MODALIDAD = P_COD_MODALIDAD and
                          COD_OFICINA = P_COD_OFICINA and
                          NRO_CUENTA = P_NRO_CUENTA and
                          ANO = V_ANIO              and
                          MES = V_MES;
            ELSE
                    update CC_SAL_MENSUALES
                    set CAN_CREDITOS = nvl(CAN_CREDITOS,0) + 1,
                        TOT_CREDITOS = NVL(TOT_CREDITOS,0) + NVL(TO_NUMBER(P_MONTO),0)
                    where COD_MODALIDAD = P_COD_MODALIDAD and
                          COD_OFICINA = P_COD_OFICINA and
                          NRO_CUENTA = P_NRO_CUENTA and
                          ANO = V_ANIO              and
                          MES = V_MES;
            END IF;
            IF sql%notfound then
                V_MSJ_ERROR := 'No existe dato en Saldos Mensuales, # '||
                               P_NRO_CUENTA || ' Modal: ' || P_COD_MODALIDAD||
                               'Oficina: ' || P_COD_OFICINA;
            END IF;
    END IF;
    Exception
    When OTHERS Then
         raise_application_error(-20001,'Cuenta: '||P_NRO_CUENTA||
         ' Importe: '||P_MONTO||' Pra_tot_ret_batch. ');
END;
/

