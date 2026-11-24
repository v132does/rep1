CREATE OR REPLACE FUNCTION IT.FUG_OBT_CAN_EXTRACCIONES
  (P_NRO_CUENTA IN VARCHAR2)
  return Number IS
  v_fcdehoy date;
  v_cod_modulo     ge_cuentas.cod_modulo%type;
  v_cod_modalidad  ge_cuentas.cod_modalidad%type;
  v_cod_moneda     ge_cuentas.cod_moneda%type;
  v_cod_oficina    ge_cuentas.cod_oficina%type;
  v_val_tasa       ge_movimientos.val_tasa%type;
  v_cod_tasa       ge_movimientos.cod_tasa%type := 901;
  v_can_extracciones number(3);
  v_cod_ente       ah_cta_vistas.cod_ente%type;
  --Variables para saldo promedio
  v_fec_ini           date; --fechsa inicial del mes anterior
  v_fec_fin           date; --fecha final del mes anterior
  v_sal_promedio      ah_capitalizaciones.sal_promedio%type;
  v_sal_acumulado     ah_capitalizaciones.sal_promedio%type;
  v_can_dia_acumulado ah_sal_mensuales.can_dia_acumulado%type;
  v_cod_sub_modalidad number(5) := null;
  v_cod_ent_tas       ge_tas_fechas.cod_ente%type;

begin
  v_fcdehoy := pag_cal.fu_obt_fec_actual(3);
  if P_NRO_CUENTA is not null then
    v_cod_ent_tas := fug_obt_ent_pag_sue(p_nro_cuenta);
  else
    v_cod_ent_tas := null;
  end if;
  begin
    select a.cod_modulo, a.cod_modalidad, a.cod_moneda, a.cod_oficina, b.cod_ente, a.cod_sub_modalidad
      into v_cod_modulo, v_cod_modalidad, v_cod_moneda,v_cod_oficina, v_cod_ente, v_cod_sub_modalidad
      from ah_cta_vistas b, ge_cuentas a
     where a.nro_cuenta = p_nro_cuenta
       and b.nro_cuenta(+) = a.nro_cuenta;
  exception
    when others then
      raise_application_error(-20000,'En obtener datos de la cuenta '||sqlerrm);
  end;
  --Buscar si esta personalizado la cantidad de extracciones
  begin
    select nvl(val_tasa,0)
      into v_val_tasa
      from ge_tas_fechas
     where nvl(cod_modulo,nvl(v_cod_modulo,-1))       = nvl(v_cod_modulo,-1)
       AND nvl(cod_modalidad,nvl(v_cod_modalidad,-1)) = nvl(v_cod_modalidad,-1)
       AND nvl(cod_sub_modalidad,nvl(v_cod_sub_modalidad,-1)) = nvl(v_cod_sub_modalidad,-1)
       AND nvl(cod_oficina,nvl(v_cod_oficina,-1))     = nvl(v_cod_oficina,-1)
       AND nvl(cod_ente,nvl(v_cod_ent_tas,-1))        = nvl(v_cod_ent_tas,-1)
       AND nvl(cod_moneda,nvl(v_cod_moneda,'x'))      = nvl(v_cod_moneda,'x')
       AND nro_cuenta  = p_nro_cuenta
       AND cod_tasa = v_cod_tasa
       AND fec_vigencia =(SELECT MAX(fec_vigencia)
                            FROM  ge_tas_fechas
                           WHERE nvl(cod_modulo,nvl(v_cod_modulo,-1))       = nvl(v_cod_modulo,-1)
                             AND nvl(cod_modalidad,nvl(v_cod_modalidad,-1)) = nvl(v_cod_modalidad,-1)
                             AND nvl(cod_sub_modalidad,nvl(v_cod_sub_modalidad,-1)) = nvl(v_cod_sub_modalidad,-1)
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
      v_can_extracciones := fug_obt_parentes(v_cod_ente,'CAN_MAX_TRANSACCION');
      if v_can_extracciones is null then
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
            v_val_tasa := fug_obt_valtas_rango(900,
                                               v_cod_modulo,
                                               v_cod_modalidad,
                                               v_cod_moneda,
                                               v_cod_oficina,
                                               v_sal_promedio,
                                               v_fcdehoy);
            return v_val_tasa;
          exception
            when others then
              IF sqlcode <= -20000 THEN
                raise;
              else
                raise_application_error(-20000,'Al buscar por saldo promedio'||' - '||sqlerrm);
              End if;
          end;
      else
          return v_can_extracciones;
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
    /*IF sqlcode <= -20000 THEN
      raise;
    else
      raise_application_error(-20000,'Cuenta Nro.:'||p_nro_cuenta||' - '||sqlerrm);
    End if;*/
    return 0;
end FUG_OBT_CAN_EXTRACCIONES;
/

