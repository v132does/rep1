CREATE OR REPLACE FUNCTION IT.FUC_OBT_SAL_SIN_SOBREGIRO(P_NRO_CUENTA  IN CC_CTA_CORRIENTES.NRO_CUENTA%TYPE) RETURN NUMBER IS
   v_saldo CC_CTA_CORRIENTES.SAL_TOTAL%TYPE;
BEGIN
   If nvl(P_NRO_CUENTA,'XX') <> 'XX' Then
        pag_cta.PR_OBT_CUENTA(P_NRO_CUENTA);
        if pag_cta.G_CTAS.cod_modalidad = 41 then
           v_saldo := pag_cta.FU_SAL_DIS_COMBINADA;
        ElsIf pag_cta.G_CTAS.cod_modalidad = 31 then
           v_saldo := pag_cta.FU_SAL_TOTAL;
        End if;
  End If;
   Return v_saldo;
END FUC_OBT_SAL_SIN_SOBREGIRO;
/

