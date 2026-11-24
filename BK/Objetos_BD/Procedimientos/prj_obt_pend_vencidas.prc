CREATE OR REPLACE PROCEDURE IT.PRJ_OBT_PEND_VENCIDAS
 (P_NRO_CUENTA IN VARCHAR2
 ,P_FECHA IN DATE
 ,P_HORA IN VARCHAR2
 ,P_TOT_CAPITAL OUT NUMBER
 ,P_TOT_MORA OUT NUMBER
 ,P_TOT_IMPUESTO OUT NUMBER
 ,P_TOT_CARGO OUT NUMBER
 ,P_TOT_CARGO_IVA OUT NUMBER
 ,P_TOT_PUNITORIO OUT NUMBER
 ,P_TOT_CTA_AHO OUT NUMBER
 ,P_TOT_CTA_CON OUT NUMBER
 ,P_COD_RESPUESTA OUT VARCHAR2
 ,P_MSJ_RESPUESTA OUT VARCHAR2
 )
 IS
-- Datos del COBRO
 v_tot_capital           number(18,2);      -- Capital (MTO_CAPITAL)
 v_tot_mora              number(18,2);      -- Mora s/capital (MTO_INT_MORATORIO)
 v_tot_impuesto          number(18,2);      -- Total impuesto (MTO_IMPUESTO)
 v_tot_cargo             number(18,2);      -- Total cargo (MTO_CARGO)
 v_tot_cargo_iva         number(18,2);      -- Total cargo IVA (MTO_CARGO_IVA)
 v_tot_punitorio         number(18,2);      -- Total monto punitorio (MTO_INT_PUNITORIO)
 v_cod_usuario           varchar2(10);
BEGIN
  Begin
     Select sum(nvl(mto_total,0)),
     sum(nvl(mto_int_moratorio,0)),
     sum(nvl(mto_int_punitorio,0)),
     sum(nvl(mto_cargo,0)),
     sum(nvl(mto_cargo_iva,0)),
     sum(nvl(mto_impuesto,0))
     into v_tot_capital, v_tot_mora,
          v_tot_punitorio , v_tot_cargo,
          v_tot_cargo_iva, v_tot_impuesto
      from ov_cobros where
          nro_cuenta = p_nro_cuenta
      and fecha      = p_fecha
      and hora       = p_hora;

      p_tot_capital        := nvl(v_tot_capital,0);
      p_tot_mora           := nvl(v_tot_mora,0);
      p_tot_punitorio      := nvl(v_tot_punitorio,0);
      p_tot_cargo          := nvl(v_tot_cargo,0);
      p_tot_cargo_iva      := nvl(v_tot_cargo_iva,0);
      p_tot_impuesto       := nvl(v_tot_impuesto,0);
      p_cod_respuesta := '000';
      p_msj_respuesta := null;
  Exception
     when no_data_found then
        p_cod_respuesta := '007';
        p_msj_respuesta := 'No encontro COBRO '||sqlerrm;
     when others then
        p_cod_respuesta := '999';
        p_msj_respuesta := 'Error al buscar en OV_COBROS:'||sqlerrm;
  End;
  if p_cod_respuesta = '000' THEN
     --- Recuperar formas de cobro
     BEGIN
        ---Filtrar el usuario
        select usu_insercion
        into   v_cod_usuario
        from   ov_cobros
        where  nro_cuenta = p_nro_cuenta
        and    fecha      = p_fecha
        and    hora       = p_hora;
        ---
        select nvl(sum(decode(cod_transaccion,503,nvl(monto,0),0)),0),
               nvl(sum(decode(cod_transaccion,842,nvl(monto,0),0)),0)
        into   p_tot_cta_aho, p_tot_cta_con
        from   ge_movimientos
        where  fecha       = p_fecha
        and    hora        = p_hora
        and    cod_usuario = v_cod_usuario
        and    cod_transaccion in (503,842);
     END;
  end if;
END;
/

