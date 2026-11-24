create or replace procedure it.PRP_VER_CAL_INTERES(P_NRO_SOLICITUD  IN NUMBER) is
  Cursor c1 is Select s.tot_prestamo, s.monto, s.tip_interes, s.fec_inicio,
                      s.fec_pri_vencimiento,
                      s.cod_modulo, s.cod_modalidad, s.cod_oficina, s.cod_moneda,
                      c.nro_cuota,
                      c.sal_cap_anterior, c.mto_capital,
                      c.val_interes, c.val_int_adelantado,
                      c.fec_vto_exacto, c.fec_vto_habil, s.tip_amortizacion
                 from pr_sol_cuotas c, pr_solicitudes s
                where c.nro_solicitud = s.nro_solicitud
                  and c.nro_solicitud = p_nro_solicitud
                  and c.nro_cuota > 0
                  and s.nro_solicitud = p_nro_solicitud
                Order by nro_cuota;

  v_mto_interes pr_sol_cuotas.val_interes%type;
  v_val_tasa    pr_sol_tasas.val_tasa%type;
  v_sal_cap_anterior pr_sol_cuotas.sal_cap_anterior%type := 0;
  v_dias             pr_sol_cuotas.dia_periodo%type := 0;
  v_fec_ven_anterior pr_sol_cuotas.fec_vto_exacto%type;
  v_redondeo     number(2) := 0;
  v_ven_fijo     number(5) := null;
  ---
  function fl_obt_tasa return number is
    v_val_tasa pr_sol_tasas.val_tasa%type;
  Begin
    Select val_tasa
      into v_val_tasa
      from pr_sol_tasas
     where nro_solicitud = p_nro_solicitud;
    Return v_val_tasa;
  End;
begin
  For r1 in c1 Loop
    If r1.nro_cuota = 1 then
       v_sal_cap_anterior := r1.tot_prestamo;
       v_fec_ven_anterior := r1.fec_inicio;
       v_val_tasa         := fl_obt_tasa;
       v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', r1.cod_modulo, r1.cod_modalidad, r1.cod_moneda, r1.cod_oficina);
       if r1.tip_amortizacion = 'P' then
          declare
             v_val_int_2 number(18,2);
          begin
             select val_interes
               into v_val_int_2
               from pr_sol_cuotas
              where nro_solicitud = p_nro_solicitud
                and nro_cuota = 2;
              v_ven_fijo := v_val_int_2 * 36500 / (v_val_tasa * (r1.tot_prestamo - r1.mto_capital));
             if round(v_ven_fijo,2) not in (30,42) then
                v_ven_fijo := round(v_ven_fijo,0);
             end if;
          exception
             when others then
                v_ven_fijo := null;
          end;
       end if;
    End If;
    v_dias := r1.fec_vto_exacto - v_fec_ven_anterior;
    if r1.cod_modalidad in (62,608,620,622,630) then
       v_mto_interes := round(r1.mto_capital * (r1.fec_vto_habil-r1.fec_inicio) * v_val_tasa / 36500, v_redondeo);
    elsif r1.tip_amortizacion = 'P' then
       v_mto_interes := round(nvl(v_sal_cap_anterior,0) * nvl(v_ven_fijo,v_dias) * v_val_tasa / 36500, v_redondeo);
    else
       v_mto_interes := round(nvl(v_sal_cap_anterior,0) * v_dias * v_val_tasa / 36500, v_redondeo);
    end if;
    If r1.tip_interes = 'V' then
       If v_mto_interes != r1.val_interes Then
          -- Son diferentes...
          dbms_output.put_line('Diferencia cuota: '||to_char(r1.nro_cuota)||' Calculado '||to_char(v_mto_interes)||' Generado '||to_char(r1.val_interes)||' diferencia '||to_char(v_mto_interes - r1.val_interes));
       Else
          dbms_output.put_line('Sin Diferencia cuota: '||to_char(r1.nro_cuota)||' Calculado '||to_char(v_mto_interes)||' Generado '||to_char(r1.val_interes));
       End If;
    Else
       If v_mto_interes != r1.val_int_adelantado Then
          -- Son diferentes...
          dbms_output.put_line('Diferencia cuota: '||to_char(r1.nro_cuota)||' Calculado '||to_char(v_mto_interes)||' Generado '||to_char(r1.val_int_adelantado)||' diferencia '||to_char(v_mto_interes - r1.val_int_adelantado));
       Else
          dbms_output.put_line('Sin Diferencia cuota: '||to_char(r1.nro_cuota)||' Calculado '||to_char(v_mto_interes)||' Generado '||to_char(r1.val_int_adelantado));
       End If;
    End If;
    v_sal_cap_anterior := v_sal_cap_anterior - r1.mto_capital;
    v_fec_ven_anterior := r1.fec_vto_exacto;
  End Loop;
end PRP_VER_CAL_INTERES;
/

