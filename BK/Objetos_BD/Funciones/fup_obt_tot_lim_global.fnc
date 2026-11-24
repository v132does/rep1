CREATE OR REPLACE FUNCTION IT.FUP_OBT_TOT_LIM_GLOBAL
 (P_COD_GRU_ECONOMICO IN GE_GRU_ECONOMICOS.COD_GRU_ECONOMICO%TYPE,
  P_COD_MONEDA IN VARCHAR2 DEFAULT 'GS',
  P_TIPO IN VARCHAR2 DEFAULT 'A') RETURN NUMBER
 IS
 v_tot_mto_aplicado   number(18,2);
 v_tot_mto_limite     number(18,2);
 v_tot_ope_especifica number(18,2);
 v_can_lim_clientes   number;

begin
  SELECT
  --A-Monto Aplicado--
  sum(fub_con_mon_a_moneda(a.cod_moneda,p_cod_moneda, nvl(a.mto_aplicado,0), a.cotizacion)),
  --T-Total de Limites--
  sum(fub_con_mon_a_moneda(a.cod_moneda,p_cod_moneda, nvl(a.monto,0), a.cotizacion)),
  --E-Operaciones Especificas--
  SUM(NVL(CASE WHEN A.estado = 'P' then fug_obt_tot_ope_esp_sol(A.cod_persona, p_cod_moneda, A.nro_linea)
  Else fug_obt_tot_ope_especifica(A.cod_persona, p_cod_moneda) END,0)),
  --C-Cantidad--
  sum(decode(a.nro_linea,null,0,1))
  INTO v_tot_mto_aplicado, v_tot_mto_limite, v_tot_ope_especifica, v_can_lim_clientes
  FROM PR_LINEAS A, GE_CLIENTES B
 WHERE B.COD_PERSONA = A.COD_PERSONA
   AND B.COD_GRU_ECONOMICO IS NOT NULL
   AND A.ESTADO IN ('A','P')
   AND B.COD_GRU_ECONOMICO = P_COD_GRU_ECONOMICO;
 if p_tipo = 'A' then
    --Monto Aplicado--
    return v_tot_mto_aplicado;
 elsif p_tipo = 'T' then
    --Monto Total de Limites-
    return v_tot_mto_limite;
 elsif p_tipo = 'E' then
    --Operaciones Especificas--
    return v_tot_ope_especifica;
 elsif p_tipo = 'C' then
    --Cantidad de Lineas--
    return v_can_lim_clientes;
 else
    return 0;
 end if;
exception
  when others then
       raise_application_error(-20000,'Error en FUP_OBT_TOT_LIM_GLOBAL: '||sqlerrm);
end;
/

