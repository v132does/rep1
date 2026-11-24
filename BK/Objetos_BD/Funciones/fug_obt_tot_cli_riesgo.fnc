CREATE OR REPLACE FUNCTION IT.fug_obt_tot_cli_riesgo
(
   p_cod_persona IN ba_personas.cod_persona%TYPE,
   p_cod_moneda  IN ba_monedas.cod_moneda%TYPE
) RETURN NUMBER IS
   v_tot_riesgo NUMBER;
BEGIN
   --Obtiene el Riesgo Total del Cliente. (Límite de Crédito + Operaciones Específicas)
   v_tot_riesgo := nvl(fug_obt_tot_ope_esp_sol(p_cod_persona, p_cod_moneda, NULL) +
                       fup_obt_mto_lin_aprobada(p_cod_persona, p_cod_moneda), 0);

   RETURN v_tot_riesgo;
END;
/

