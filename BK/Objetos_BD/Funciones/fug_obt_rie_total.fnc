create or replace function it.FUG_OBT_RIE_TOTAL(p_cod_persona in ba_personas.cod_persona%type)
 return number is
--- Variables auxiliares
CURSOR PRESTAMOS IS
   SELECT B.COD_PERSONA, A.NRO_CUENTA, A.COD_MODULO, A.COD_MODALIDAD,
         A.COD_MONEDA, NVL(A.SAL_CAPITAL,0)+NVL(A.SAL_INT_ADELANTADO,0) SALDO,
         NVL(A.DIA_ATRASO,0) DIA_ATRASO, A.ESTADO,
         A.DEV_NO_COBRADO, A.COD_OFICINA, NVL(A.TIP_RENOVACION,'A') TIPO, TIP_INTERES,
         A.MTO_CAPITAL, A.NRO_CTA_RENOVADA, (A.FEC_VENCIMIENTO - A.FEC_INICIO) PLAZO,
         A.TIP_RENOVACION, A.COD_SEC_CREDITO, A.TIP_DESTINO
   FROM GE_CTA_CLIENTES B, PR_CTA_PRESTAMOS A
   WHERE A.NRO_CUENTA = B.NRO_CUENTA
   AND NVL(A.SAL_CAPITAL,0)+NVL(A.SAL_INT_ADELANTADO,0) >0 --(x inconsistencia)
   AND A.ESTADO <> 'N' --solo las no canceladas
   and b.cod_persona = p_cod_persona
   AND B.RELACION ='P';--y principales de cuenta
V_TOT_DEUDA NUMBER(18,2);
V_DEV_NO_COBRADO NUMBER(18,2);
--- Deudas de tarjetas ----------------------------------------------
CURSOR TARJETAS IS
   SELECT B.COD_PERSONA, A.COD_MODULO, A.COD_MODALIDAD, A.COD_OFICINA,
         A.NRO_CUENTA, A.COD_MONEDA,
         NVL(A.SAL_FACTURAR,0)+NVL(A.SAL_FACTURADO,0)+NVL(A.SAL_FINANCIADO,0) SALDO,
         NVL(A.LIN_CREDITO,0) LINEA_DE_CREDITO, NVL(A.DIA_MORA,0) DIA_MORA, A.ESTADO
   FROM GE_CTA_CLIENTES B, TA_CTA_TARJETAS A
   WHERE ESTADO <> 'C'
   AND A.NRO_CUENTA = B.NRO_CUENTA
   AND B.COD_PERSONA = P_COD_PERSONA
   AND NVL(A.SAL_FACTURAR,0)+NVL(A.SAL_FACTURADO,0)+NVL(A.SAL_FINANCIADO,0) >0--(x inconsistencia)
   AND B.RELACION ='P';--y principales de cuenta;
WW_TTDEUCO NUMBER(18);
--------------
   v_tot_riesgo pr_cta_prestamos.sal_capital%type;
begin
   v_tot_riesgo := 0;
   FOR PR IN PRESTAMOS LOOP
		  --VER SI ES DOCUMENTADO
		  -- Inicializo el dev no cobrado
      V_DEV_NO_COBRADO :=  NVL(PR.DEV_NO_COBRADO,0);
      ---1. calculo la deuda en la moneda local ----------------------
      V_TOT_DEUDA      := PAP_CAT.FU_CON_A_GUARANIES(PR.COD_MONEDA, nvl(PR.SALDO,0)+NVL(V_DEV_NO_COBRADO,0));
      v_tot_riesgo := v_tot_riesgo + nvl(v_tot_deuda,0);
   END LOOP;
   FOR TA IN TARJETAS LOOP
      ---1. calculo la deuda en la moneda local ----------------------
      -- Se considera solo la linea
      WW_TTDEUCO := NVL(TA.LINEA_DE_CREDITO,0);
      WW_TTDEUCO := PAP_CAT.FU_CON_A_GUARANIES(TA.COD_MONEDA,WW_TTDEUCO);
      v_tot_riesgo := v_tot_riesgo + nvl(ww_ttdeuco,0);
   END LOOP;
   return(v_tot_riesgo);
end FUG_OBT_RIE_TOTAL;
/

