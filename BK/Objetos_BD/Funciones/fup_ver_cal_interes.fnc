create or replace function it.fup_ver_cal_interes(P_NRO_SOLICITUD  IN NUMBER)
  return varchar2 is
  Cursor c1 is Select s.tot_prestamo, s.monto, s.tip_interes, s.fec_inicio,
                      s.fec_pri_vencimiento, 
                      s.cod_modulo, s.cod_modalidad, s.cod_oficina, s.cod_moneda, 
                      c.nro_cuota,
                      c.sal_cap_anterior, c.mto_capital, 
                      c.val_interes, c.val_int_adelantado,
                      c.fec_vto_exacto, c.fec_vto_habil, s.tip_amortizacion,
                      s.tip_aju_fecha,
                      s.per_gracia,
                      s.tip_monto,
                      s.mto_cargo,
                      s.exo_impuesto
                 from pr_sol_cuotas c, pr_solicitudes s
                where c.nro_solicitud = s.nro_solicitud                 
                  and c.nro_solicitud = p_nro_solicitud
                  and c.nro_cuota > 0
                  and s.nro_solicitud = p_nro_solicitud
                  and s.usu_insercion<>'HBANKF'
                Order by nro_cuota;
  
  v_mto_interes pr_sol_cuotas.val_interes%type;
  v_val_tasa    pr_sol_tasas.val_tasa%type;
  v_sal_cap_anterior pr_sol_cuotas.sal_cap_anterior%type := 0;
  v_dias             pr_sol_cuotas.dia_periodo%type := 0;
  v_fec_ven_anterior pr_sol_cuotas.fec_vto_exacto%type;
  v_redondeo     number(2) := 0;
  v_ven_fijo     varchar(1);      
  v_resultado    varchar2(3000) := null;
  v_dif_aceptada number(5) := 10; -- diferencia aceptada en gs
  v_tot_cuota        number(5); --Cantidad total de cuotas de la solicitud
  v_per_interes      pr_sol_tasas.per_vencimiento%type;
  v_int_per_gracia   number;
  v_imp_interes      number;
  v_val_tas_imp      ge_tas_fechas.val_tasa%type;
  v_fec_vigencia     date;
  v_tip_valor        ge_tasas.tip_valor%type;
  v_tipo             ge_tasas.tipo%type;
  v_cod_tasa         ge_tasas.cod_tasa%type;
  v_cod_persona      ba_personas.cod_persona%type;
  v_existe           varchar2(20) := 'SIN';
  v_exi_che_roga     varchar2(20) := 'SIN';
  v_cod_per_soli      ba_personas.cod_persona%type;
  v_cod_mad_prestamos ge_modalidades.cod_modalidad%type := 0;
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
  --Obtener cantidad de cuotas de la solicitud
  begin
    select max(nro_cuota)
      into v_tot_cuota
      from pr_sol_cuotas
     where nro_solicitud = p_nro_solicitud;
  exception
    when no_data_found then
      v_tot_cuota := 0;
  end;

  --Obtener periodo de interes
  begin
    select per_vencimiento
      into v_per_interes
      from pr_sol_tasas
     where pr_sol_tasas.nro_solicitud = p_nro_solicitud;
  exception
    when no_data_found then
      v_per_interes := 0;
  end;
  
  --obtenemos el codigo de persona de la solicitud
  /*begin
     Select distinct(cod_persona)
      into v_cod_persona
      from pr_solicitudes es
      where es.nro_solicitud = p_nro_solicitud;
      -- verificamos que la solicitud este en esta tabla de preaprobados
      begin  
         Select 'PREAPROBADO'
           into v_existe
         from pr_pre_aprobados a
         where a.cod_persona = v_cod_persona
           and a.nro_solicitud = p_nro_solicitud 
           and rownum = 1;
      exception
        when no_data_found then
          v_existe := 'SIN';
      end;
      -- obtenemos el codigo de persona de la solicitud che roga
      begin
        Select distinct (cod_persona)
          into v_cod_per_soli
          from pr_solicitudes es
         where es.nro_solicitud = p_nro_solicitud;
      -- verificamos que la solicitud este en esta tabla de pr_pre_che_roga
        begin
          Select 'CHEROGA'
            into v_exi_che_roga
            from pr_pre_che_roga a
           where a.cod_per_solicitante = v_cod_per_soli
             and a.nro_solicitud = p_nro_solicitud
             and rownum = 1;
        exception
          when no_data_found then
            v_exi_che_roga := 'SIN';
        end;
      
      exception
        when too_many_rows then
          v_resultado := 'Hay mas de un codigo de persona con el mismo nro. de Solicitud';
        when others then
          v_resultado := null;
      end;
  EXCEPTION
    when too_many_rows THEN
      v_resultado := 'Hay mas de un codigo de persona con el mismo nro. de Solicitud';
    when others then
      v_resultado := null;
  end;  */

  For r1 in c1 Loop
    v_cod_mad_prestamos := r1.cod_modalidad;
    If r1.nro_cuota = 1 then
       v_sal_cap_anterior := r1.tot_prestamo;
       v_fec_ven_anterior := r1.fec_inicio;
       v_val_tasa         := fl_obt_tasa;
       v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', r1.cod_modulo, r1.cod_modalidad, r1.cod_moneda, r1.cod_oficina);
       If r1.cod_moneda != pag_gen.FU_OBT_MON_LOCAL then
          v_dif_aceptada := 1; -- diferencia aceptada en moneda extranjera
       End If;
/*       if r1.tip_amortizacion = 'P' then
          declare
             v_val_int_2 number(18,2);
          begin
             select val_interes
               into v_val_int_2
               from pr_sol_cuotas
              where nro_solicitud = p_nro_solicitud
                and nro_cuota = 2;
              v_ven_fijo := v_val_int_2 * 36500 / (v_val_tasa * (r1.tot_prestamo - r1.mto_capital));
             if v_ven_fijo between 30.4155 and 30.417 then
                v_ven_fijo := 30.416666666666666666666666666667;
             else   
                v_ven_fijo := round(v_ven_fijo,0);
             end if;  
          exception
             when others then
                v_ven_fijo := null;
          end; 
       end if;*/
    End If;
    
    if r1.tip_aju_fecha = 'E' THEN
      v_ven_fijo := 'S';
    else
      v_ven_fijo := 'N';
    end if;
    
    IF r1.nro_cuota = 1 AND
       abs(30 - (r1.fec_pri_vencimiento - r1.fec_inicio)) > 2 THEN
      v_dias := r1.fec_pri_vencimiento - r1.fec_inicio;
      v_int_per_gracia := ROUND((r1.tot_prestamo * (v_val_tasa/36500) * (v_dias - to_char(last_day(r1.fec_pri_vencimiento),'dd'))),v_redondeo);
      IF NVL(r1.tip_amortizacion,'X') = 'I' THEN
         v_int_per_gracia := ROUND((v_int_per_gracia / v_tot_cuota),v_redondeo);
      END IF;
    ELSIF v_per_interes = 30 AND r1.tip_amortizacion in ('B') THEN
      IF v_ven_fijo = 'S' THEN
        v_dias := 30.416666666666666666666666666667;
      ELSE
        v_dias := v_per_interes;
      END IF;
    ELSE
      v_dias := r1.fec_vto_habil - v_fec_ven_anterior;
    END IF;
    
    --if r1.cod_modalidad in (62,608,620,622,630) then
    If FUP_OBT_TIP_DESCUENTO(r1.cod_modalidad) in ('F','D','C') then
       v_mto_interes := ceil(r1.mto_capital * (r1.fec_vto_habil-r1.fec_inicio) * v_val_tasa / 36500);
/*    elsif r1.tip_amortizacion = 'P' then
       If r1.nro_cuota = 1 and  abs(30-v_dias) > 2 then -- cuota 1, particular
          v_mto_interes := round(nvl(v_sal_cap_anterior,0) * v_dias * v_val_tasa / 36500, v_redondeo);
       else    
          v_mto_interes := round(nvl(v_sal_cap_anterior,0) * nvl(v_ven_fijo,v_dias) * v_val_tasa / 36500, v_redondeo);
       end if; */  
    else    
       --if nvl(v_existe,'SIN') =  'SIN'  and  nvl(v_exi_che_roga,'SIN') =  'SIN' then
       if instr(fug_obt_pardinamico('COD_MAD_PRESTAMOS'),','||v_cod_mad_prestamos||',') = 0 then
           v_mto_interes := round(nvl(v_sal_cap_anterior,0) * v_dias * v_val_tasa / 36500, v_redondeo);
           if r1.exo_impuesto = 'S' and NVL(fug_obt_pardinamico('MAD_REF_CUO_IGUALES',r1.cod_modulo,r1.cod_modalidad),'N') = 'S' then
             pag_gen.pr_obt_val_tasa (r1.cod_modulo, r1.cod_modalidad, null,
                                      null, r1.cod_moneda, null, 'N',
                                      v_cod_tasa, 709,
                                      r1.fec_inicio, v_val_tas_imp, v_fec_vigencia, 
                                      v_tip_valor, v_tipo);
             v_imp_interes := round((v_mto_interes * v_val_tas_imp/100),v_redondeo);
           else
             v_imp_interes := 0;
           end if;
       
      -- elsif nvl(v_existe,'SIN') = 'PREAPROBADO' or nvl(v_exi_che_roga,'SIN') = 'CHEROGA' THEN
       elsif instr(fug_obt_pardinamico('COD_MAD_PRESTAMOS'),','||v_cod_mad_prestamos||',') > 0 then
         if r1.nro_cuota = 1  THEN
           v_dias := to_char(last_day(r1.fec_pri_vencimiento),'dd');
         else
           v_dias := r1.fec_vto_habil - v_fec_ven_anterior ;
         end if;

         v_mto_interes := ROUND(nvl(v_sal_cap_anterior  * (v_val_tasa / 36500) * v_dias ,v_redondeo))
                          + ROUND((v_int_per_gracia / v_tot_cuota),v_redondeo);
       end if;        
    end if;
    
    If r1.tip_interes = 'V' then
       If abs(v_mto_interes - r1.val_interes) > v_dif_aceptada Then
          -- Son diferentes...
          v_resultado := 'Diferencia cuota: '||to_char(r1.nro_cuota)||' Calculado '||to_char(v_mto_interes)||' Generado '||to_char(r1.val_interes)||' diferencia '||to_char(v_mto_interes - r1.val_interes||' Dias '||v_dias);
       --Else
       --   dbms_output.put_line('Sin Diferencia cuota: '||to_char(r1.nro_cuota)||' Calculado '||to_char(v_mto_interes)||' Generado '||to_char(r1.val_interes));
       End If;
    Else
       If abs(v_mto_interes - r1.val_int_adelantado) > v_dif_aceptada Then
          -- Son diferentes...
          v_resultado := 'Diferencia cuota: '||to_char(r1.nro_cuota)||' Calculado '||to_char(v_mto_interes)||' Generado '||to_char(r1.val_int_adelantado)||' diferencia '||to_char(v_mto_interes - r1.val_int_adelantado);
       --Else
       -- dbms_output.put_line('Sin Diferencia cuota: '||to_char(r1.nro_cuota)||' Calculado '||to_char(v_mto_interes)||' Generado '||to_char(r1.val_int_adelantado));       
       End If;
    End If;    
    v_sal_cap_anterior := v_sal_cap_anterior - r1.mto_capital + nvl(v_imp_interes,0);
    v_fec_ven_anterior := r1.fec_vto_habil;
    if v_resultado is not null then
       exit;
    end if;
  End Loop;
  return v_resultado;
 -- return null;  
end FUP_VER_CAL_INTERES;
/
