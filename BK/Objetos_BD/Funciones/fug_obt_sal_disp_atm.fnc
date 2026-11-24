create or replace function it.fug_obt_sal_disp_atm(p_nro_cuenta in ge_cuentas.nro_cuenta%type)
  return number is
    v_sal_disponible ah_cta_vistas.sal_total%type;
    v_cod_modulo ge_cuentas.cod_modulo%type;
    v_cod_modalidad ge_cuentas.cod_modalidad%type;
    v_est_proceso number(1);
  BEGIN
    select t.cod_modulo, t.cod_modalidad
     into v_cod_modulo, V_COD_MODALIDAD
     from ge_cuentas t where t.nro_cuenta = p_nro_cuenta;
  /*SAL_TOTAL
    - SAL_RETENIDO
    - SAL_BLOQUEADO
    - MTO_DEB_PENDIENTES
    + MTO_CRE_PENDIENTES
    = Saldo disponible*/  
    
    --Obtener saldo disponible en tiempo real(tablas maestras y nocturnas)
     --- Obtiene el estado del Modulo.
     v_est_proceso := pae_cnf.fu_obt_est_modulo(v_cod_modulo);
     
     ----------------------------------------------------------------
   -- Si es Ahorro a la vista  --
   ----------------------------------------------------------------
  IF V_COD_MODULO = 3 then 
   If V_COD_MODALIDAD in (31,334) then
      if V_EST_PROCESO in( 2,6) Then
         SELECT nvl(SAL_TOTAL,0)-nvl(SAL_RETENIDO,0)-nvl(SAL_BLOQUEADO,0)-nvl(MTO_DEB_PENDIENTES,0)+nvl(MTO_CRE_PENDIENTES,0) SAL_DISPONIBLE
           INTO  v_sal_disponible
           FROM AH_CTA_VISTAS
          WHERE NRO_CUENTA = P_NRO_CUENTA;
         -- agregado para cuenta combinada  ---
         -----
      Else  
          -- modifico los datos si el modulo no esta abierto, leyendo los datos del NOC
          SELECT nvl(SAL_TOTAL,0)-nvl(SAL_RETENIDO,0)-nvl(SAL_BLOQUEADO,0)-nvl(MTO_DEB_PENDIENTES,0)+nvl(MTO_CRE_PENDIENTES,0) SAL_DISPONIBLE
            INTO v_sal_disponible
            FROM AH_CTA_VISTAS_NOC
           WHERE NRO_CUENTA = P_NRO_CUENTA;
       end if;
    END IF;

    ----------------------------------------------------------------
    -- Si es Cuenta Corriente lee el cursor de Cuentas Corrientes --
    ----------------------------------------------------------------
   ELSIF v_cod_modulo = 4 then 
    IF  V_COD_MODALIDAD = 41 then
      if V_EST_PROCESO in( 2,6) Then
         SELECT nvl(SAL_TOTAL,0)-nvl(SAL_RETENIDO,0)-nvl(SAL_BLOQUEADO,0)-nvl(MTO_DEB_PENDIENTES,0)+nvl(MTO_CRE_PENDIENTES,0) SAL_DISPONIBLE
           INTO v_sal_disponible
           FROM CC_CTA_CORRIENTES
          WHERE NRO_CUENTA = P_NRO_CUENTA;
         -----
     Else-- 
         -- modifico los datos si el modulo no esta abierto, leyendo los datos del NOC
         SELECT nvl(SAL_TOTAL,0)-nvl(SAL_RETENIDO,0)-nvl(SAL_BLOQUEADO,0)-nvl(MTO_DEB_PENDIENTES,0)+nvl(MTO_CRE_PENDIENTES,0) SAL_DISPONIBLE
           INTO v_sal_disponible
           FROM CC_CTA_CORRIENTES_NOC
          WHERE NRO_CUENTA = P_NRO_CUENTA;
     end if;
         -----
   --- Operaciones con Financieras del País sin Banco Sponsor
   Elsif  V_COD_MODALIDAD in (42, 43, 44, 45, 46, 47, 48, 49, 442, 455) then
   -----------------------------------------------------------
   -- Si es Cuenta Bancaria  --
   -----------------------------------------------------------
         SELECT nvl(SAL_TOTAL,0)-nvl(SAL_RETENIDO,0)-nvl(SAL_BLOQUEADO,0) SAL_DISPONIBLE
           INTO v_sal_disponible
           FROM CC_CTA_BANCARIAS
          WHERE NRO_CUENTA = P_NRO_CUENTA;
   end if;
  END IF;
    return v_sal_disponible;
exception
  when others then
    return 0; -- saldo 0(cero)
end;
/
