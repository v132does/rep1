CREATE OR REPLACE FUNCTION IT.FUG_OBT_CAN_PERMITIDAS
  (P_NRO_CUENTA IN VARCHAR2,
   P_COD_TASA   IN NUMBER,   -- codigo de la tasa para el control de las cantidades permitidas
   P_PAR_ENTE   IN VARCHAR)  -- nombre del campo en el ente que controla este dato
  return Number IS
  v_fcdehoy date;
  v_cod_modulo     ge_cuentas.cod_modulo%type;
  v_cod_modalidad  ge_cuentas.cod_modalidad%type;
  v_cod_moneda     ge_cuentas.cod_moneda%type;
  v_cod_oficina    ge_cuentas.cod_oficina%type;
  v_val_tasa       ge_movimientos.val_tasa%type;
  v_cod_tasa       ge_movimientos.cod_tasa%type := p_cod_tasa;
  v_can_permitidas number;
  v_cod_ente       ah_cta_vistas.cod_ente%type;
  --Variables para saldo promedio
  v_fec_ini           date; --fechsa inicial del mes anterior
  v_fec_fin           date; --fecha final del mes anterior
  v_sal_promedio      ah_capitalizaciones.sal_promedio%type;
  v_sal_acumulado     ah_capitalizaciones.sal_promedio%type;
  v_can_dia_acumulado ah_sal_mensuales.can_dia_acumulado%type;
  v_tip_valor ge_tasas.tip_valor%type;
  v_tipo ge_tasas.tipo%type;
  v_cod_ent_tas       ge_tas_fechas.cod_ente%type;
  v_can_paq_exnomina      number;
  v_cod_paq_exnomina  ge_paquetes.cod_paquete%type := fug_obt_pardinamico('COD_PAQ_EXNOMINA');
  v_can_ext_per_exnomina number := fug_obt_pardinamico('CAN_EXT_PER_EXNOMINA');
  v_can_con_atm_exnomina number := fug_obt_pardinamico('CAN_CON_ATM_EXNOMINA');

begin
  begin
    select count(*)
      into v_can_paq_exnomina
      from ge_paq_cuentas c
     where c.cod_paquete = v_cod_paq_exnomina
       and c.nro_cuenta = p_nro_cuenta;
  exception
    when others then
      v_can_paq_exnomina := 0;
  end;


  if P_NRO_CUENTA is not null then
    v_cod_ent_tas := fug_obt_ent_pag_sue(p_nro_cuenta);
  else
    v_cod_ent_tas := null;
  end if;
  v_fcdehoy := pag_cal.fu_obt_fec_actual(3);
  begin
    select a.cod_modulo, a.cod_modalidad, a.cod_moneda, a.cod_oficina, a.cod_ente
      into v_cod_modulo, v_cod_modalidad, v_cod_moneda,v_cod_oficina, v_cod_ente
      from ah_cta_vistas a
     where a.nro_cuenta = p_nro_cuenta
     union all
    select a.cod_modulo, a.cod_modalidad, a.cod_moneda, a.cod_oficina, a.cod_ente
      from cc_cta_corrientes a
     where a.nro_cuenta = p_nro_cuenta;
  exception
    when others then
      raise_application_error(-20000,'En obtener datos de la cuenta '||sqlerrm);
  end;
  --Buscar si esta personalizado la cantidad de transacciones permitidas
  begin
    select nvl(val_tasa,0)
      into v_val_tasa
      from ge_tas_fechas
     where nvl(cod_modulo,nvl(v_cod_modulo,-1))       = nvl(v_cod_modulo,-1)
       AND nvl(cod_modalidad,nvl(v_cod_modalidad,-1)) = nvl(v_cod_modalidad,-1)
       AND nvl(cod_oficina,nvl(v_cod_oficina,-1))     = nvl(v_cod_oficina,-1)
       AND nvl(cod_ente,nvl(v_cod_ent_tas,-1))        = nvl(v_cod_ent_tas,-1)
       AND nvl(cod_moneda,nvl(v_cod_moneda,'x'))      = nvl(v_cod_moneda,'x')
       AND nro_cuenta  = p_nro_cuenta
       AND cod_tasa = v_cod_tasa
       AND fec_vigencia =(SELECT MAX(fec_vigencia)
                            FROM  ge_tas_fechas
                           WHERE nvl(cod_modulo,nvl(v_cod_modulo,-1))       = nvl(v_cod_modulo,-1)
                             AND nvl(cod_modalidad,nvl(v_cod_modalidad,-1)) = nvl(v_cod_modalidad,-1)
                             AND nvl(cod_oficina,nvl(v_cod_oficina,-1))     = nvl(v_cod_oficina,-1)
                             AND nvl(cod_ente,nvl(v_cod_ent_tas,-1))        = nvl(v_cod_ent_tas,-1)
                             AND nvl(cod_moneda,nvl(v_cod_moneda,'x'))      = nvl(v_cod_moneda,'x')
                             AND nro_cuenta  = p_nro_cuenta
                             AND cod_tasa = v_cod_tasa
                             AND fec_vigencia <= v_fcdehoy);
    return v_val_tasa;
  exception
    when no_data_found then
      --Si no esta personalizado debe buscar deacuerdo al saldo promedio de la cuenta
      --Obtener el saldo promedio del mes anterior
      v_can_permitidas := fug_obt_parentes(v_cod_ente,p_par_ente);
      if v_can_permitidas is null and nvl(v_can_paq_exnomina,0) = 0  then
          begin
            v_fec_ini := to_date('01'||to_char(add_months(v_fcdehoy,-1),'mmyyyy'),'DDMMYYYY');
            v_fec_fin := last_day(v_fec_ini);
            pag_cta.pr_obt_sal_promedio(v_cod_modulo,
                                        v_cod_modalidad,
                                        v_cod_oficina,
                                        p_nro_cuenta,
                                        v_fec_ini,
                                        v_fec_fin,
                                        v_sal_acumulado,
                                        v_sal_promedio,
                                        v_can_dia_acumulado);
            --Obtener la cantidad de extracciones deacuerdo al saldo promedio
            begin
                PAG_GEN.PR_OBT_VAL_TASA(v_cod_modulo,v_cod_modalidad,v_cod_oficina,
                                   P_NRO_CUENTA,  v_cod_moneda, v_sal_promedio, 'N',
                                   v_cod_tasa, NULL, v_fcdehoy, V_VAL_TASA,v_fcdehoy,
                                   v_tip_valor, v_tipo);
            exception
                when no_data_found then
                  raise_application_error(-20000,
                  'Tasa '||to_char(v_cod_tasa)||' no registrada por rango');
            end;

            return v_val_tasa;
          exception
            when others then
              IF sqlcode <= -20000 THEN
                raise;
              else
                raise_application_error(-20000,'Al buscar por saldo promedio'||' - '||sqlerrm);
              End if;
          end;
      elsif nvl(v_can_paq_exnomina, 0) > 0 and P_PAR_ENTE = 'CAN_MAX_EXT_PRO_ATM' then
          return v_can_ext_per_exnomina;
      elsif nvl(v_can_paq_exnomina, 0) > 0 and P_PAR_ENTE = 'CAN_MAX_CON_PRO_ATM' then
          return v_can_con_atm_exnomina;
      else
        return v_can_permitidas;
      end if;
    when others then
      IF sqlcode <= -20000 THEN
        raise;
      else
        raise_application_error(-20000,'Al buscar por personalización'||' - '||sqlerrm);
      End if;
  end;
  return null;
exception
  when others then
    IF sqlcode <= -20000 THEN
      raise;
    else
      raise_application_error(-20000,'Cuenta Nro.:'||p_nro_cuenta||' - '||sqlerrm);
    End if;
end FUG_OBT_CAN_PERMITIDAS;
/

