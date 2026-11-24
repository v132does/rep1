create or replace function it.FUP_OBT_POR_WARRANTS(p_cod_deposito in number) return number is
  v_por_control number(10,2);
  v_fec_actual  date;
  v_mto_almacen number(18,2);
  v_mto_cartera number(18,2);
  v_cod_mon_local varchar2(3);
  v_por_almacen number(10,2);
begin
  -- Obtiene los valores de Fecha Actual y Moneda Local.
  v_fec_actual  := pag_cal.FU_OBT_FEC_ACTUAL(6);
  v_cod_mon_local := pag_gen.FU_OBT_MON_LOCAL;
  -- Suma el monto que se tiene guardado en un almacén de warrant.
  Select sum(pag_gen.FU_CON_MON_A_MONEDA(g.cod_moneda, v_cod_mon_local, nvl(g.valor,0)))
    into v_mto_almacen
    from pr_garantias g, pr_gar_warrants w
   where g.nro_garantia = w.nro_garantia
     and w.cod_ent_deposito = p_cod_deposito
     and g.estado not in ('T','N', 'V')
     and w.fec_vencimiento > v_fec_actual -- Aún no está vencido
     and w.fec_inicio <= v_fec_actual;
  If v_mto_almacen > 0 then
     -- Obtiene el monto de la cartera en la moneda local tambien.
     Select sum(pag_gen.FU_CON_MON_A_MONEDA(p.cod_moneda, v_cod_mon_local, nvl(sal_capital,0)+nvl(sal_int_adelantado,0)))
       into v_mto_cartera
       from pr_cta_prestamos p
      where estado not in ('N', 'I');
  End if;
  -- Obtiene el porcentaje del warrant con respecto a la cartera.
  v_por_almacen := round((v_mto_almacen * 100)/v_mto_cartera,2);

  Return v_por_almacen;
  ---
end FUP_OBT_POR_WARRANTS;
/

