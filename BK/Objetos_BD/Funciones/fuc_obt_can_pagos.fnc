create or replace function it.FUC_OBT_CAN_PAGOS
  (P_NRO_CUENTA IN VARCHAR2)
  return Number IS
  v_fcdehoy date;
  v_cod_modulo     ge_cuentas.cod_modulo%type;
  v_cod_modalidad  ge_cuentas.cod_modalidad%type;
  v_nro_cta_ahorro ge_cuentas.nro_cuenta%type;
  v_cod_moneda     ge_cuentas.cod_moneda%type;
  v_cod_oficina    ge_cuentas.cod_oficina%type;
  v_cod_ofi_ahorro ge_cuentas.cod_oficina%type;
  v_val_tasa       ge_movimientos.val_tasa%type;
  v_cod_tasa       ge_movimientos.cod_tasa%type := 901;
  v_can_pagos number(3);
  --Variables para saldo promedio
  v_fec_ini           date; --fecha inicial del mes anterior
  v_fec_fin           date; --fecha final del mes anterior
  v_sal_promedio      ah_capitalizaciones.sal_promedio%type;
  v_sal_pro_ahorro    ah_capitalizaciones.sal_promedio%type;
  v_sal_acumulado     ah_capitalizaciones.sal_promedio%type;
  v_can_dia_acumulado ah_sal_mensuales.can_dia_acumulado%type;
  v_sal_min_exigido           number(18,2);
  v_cod_persona       ba_personas.cod_persona%type;
  v_cod_sub_modalidad number(5) := null;
  v_cod_ente          ge_entes.cod_ente%type;

begin
  v_fcdehoy := pag_cal.fu_obt_fec_actual(4);
  begin
    select cod_modulo, cod_modalidad, cod_moneda,cod_oficina, sal_minimo, cod_sub_modalidad
      into v_cod_modulo, v_cod_modalidad, v_cod_moneda,v_cod_oficina, v_sal_min_exigido, v_cod_sub_modalidad
      from cc_cta_corrientes
     where nro_cuenta = p_nro_cuenta;
  exception
    when others then
      raise_application_error(-20000,'En obtener datos de la cuenta '||sqlerrm);
  end;
  --
  if P_NRO_CUENTA is not null then
    v_cod_ente := fug_obt_ent_pag_sue(p_nro_cuenta);
  else
    v_cod_ente := null;
  end if;
  --Buscar si esta personalizado la cantidad de extracciones
  begin
    select nvl(val_tasa,0)
      into v_val_tasa
      from ge_tas_fechas
     where nvl(cod_modulo,nvl(v_cod_modulo,-1))       = nvl(v_cod_modulo,-1)
       AND nvl(cod_modalidad,nvl(v_cod_modalidad,-1)) = nvl(v_cod_modalidad,-1)
       AND nvl(cod_sub_modalidad,nvl(v_cod_sub_modalidad,-1)) = nvl(v_cod_sub_modalidad,-1)
       AND nvl(cod_oficina,nvl(v_cod_oficina,-1))     = nvl(v_cod_oficina,-1)
       AND nvl(cod_ente,nvl(v_cod_ente,-1))           = nvl(v_cod_ente,-1)
       AND nvl(cod_moneda,nvl(v_cod_moneda,'x'))      = nvl(v_cod_moneda,'x')
       AND nro_cuenta  = p_nro_cuenta
       AND cod_tasa = v_cod_tasa
       AND fec_vigencia =(SELECT MAX(fec_vigencia)
                            FROM  ge_tas_fechas
                           WHERE nvl(cod_modulo,nvl(v_cod_modulo,-1))       = nvl(v_cod_modulo,-1)
                             AND nvl(cod_modalidad,nvl(v_cod_modalidad,-1)) = nvl(v_cod_modalidad,-1)
                             AND nvl(cod_sub_modalidad,nvl(v_cod_sub_modalidad,-1)) = nvl(v_cod_sub_modalidad,-1)
                             AND nvl(cod_oficina,nvl(v_cod_oficina,-1))     = nvl(v_cod_oficina,-1)
                             AND nvl(cod_ente,nvl(v_cod_ente,-1))           = nvl(v_cod_ente,-1)
                             AND nvl(cod_moneda,nvl(v_cod_moneda,'x'))      = nvl(v_cod_moneda,'x')
                             AND nro_cuenta  = p_nro_cuenta
                             AND cod_tasa = v_cod_tasa
                             AND fec_vigencia <= v_fcdehoy);
    return v_val_tasa;
  exception
    when no_data_found then
      --Si no esta personalizado debe buscar deacuerdo al saldo promedio de la cuenta
      --Obtener el saldo promedio del mes anterior
      begin
        v_fec_ini := to_date('01/'||to_char(add_months(v_fcdehoy,-1),'mm/yyyy'),'DD/MM/YYYY');
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
        -- busco su cuenta de ahorro si esta combinada para sumar su saldo promedio
        begin
          select cod_oficina, nro_cta_ahorro
            into v_cod_ofi_ahorro, v_nro_cta_ahorro
            from ge_cuentas b, cc_cta_combinadas
           where nro_cta_cte = p_nro_cuenta
             and nro_cta_cte = nro_cuenta;
          pag_cta.pr_obt_sal_promedio(3,
                                      31,
                                      v_cod_ofi_ahorro,
                                      v_nro_cta_ahorro,
                                      v_fec_ini,
                                      v_fec_fin,
                                      v_sal_acumulado,
                                      v_sal_pro_ahorro,
                                      v_can_dia_acumulado);
          v_sal_promedio := nvl(v_sal_promedio,0) + nvl(v_sal_pro_ahorro,0);

        exception
           when others then
               v_nro_cta_ahorro := null;
        end;
        -- veo el minimo exigido para la cuenta
        IF v_sal_min_exigido IS NULL THEN --no tiene saldo mínimo
          --principal de cuenta
          v_cod_persona := fug_obt_cli_principal(p_nro_cuenta);
          --recuperar el saldo mínimo del parámetro
          v_sal_min_exigido := FUG_OBT_SAL_MIN_PACTADO(v_cod_moneda, v_cod_persona, v_cod_modulo,
                             v_cod_modalidad, v_cod_oficina,v_cod_sub_modalidad);
        END IF;
        if nvl(v_sal_promedio,0) < nvl(v_sal_min_exigido,0) and nvl(pag_cta.FU_OBT_LIN_SOBREGIRO(p_nro_cuenta, v_fcdehoy),0) > 0  then
           -- no tiene promedio minimo, y si tiene linea de sobregiro
           -- busco el monto SIGUIENTE AL minimo del rango de tasas para esta tasa 900
           begin
             SELECT min(val_hasta)
               INTO v_sal_promedio
               FROM ge_tas_rangos
              WHERE nvl(cod_modulo,nvl(v_cod_modulo,-1))       = nvl(v_cod_modulo,-1)
                AND nvl(cod_modalidad,nvl(v_cod_modalidad,-1)) = nvl(v_cod_modalidad,-1)
                AND nvl(cod_sub_modalidad,nvl(v_cod_sub_modalidad,-1)) = nvl(v_cod_sub_modalidad,-1)
                AND nvl(cod_oficina,nvl(v_cod_oficina,-1))     = nvl(v_cod_oficina,-1)
                AND nvl(cod_ente,nvl(v_cod_ente,-1))           = nvl(v_cod_ente,-1)
                AND nvl(cod_moneda,nvl(v_cod_moneda,'x'))      = nvl(v_cod_moneda,'x')
                AND nvl(nro_cuenta,nvl(p_nro_cuenta,'x'))      = nvl(p_nro_cuenta,'x')
                AND cod_tasa = 900
                and val_tasa > 0
                AND fec_vigencia =(SELECT MAX(fec_vigencia)
                                     FROM ge_tas_rangos
                                    WHERE nvl(cod_modulo,nvl(v_cod_modulo,-1))       = nvl(v_cod_modulo,-1)
                                      AND nvl(cod_modalidad,nvl(v_cod_modalidad,-1)) = nvl(v_cod_modalidad,-1)
                                      AND nvl(cod_sub_modalidad,nvl(v_cod_sub_modalidad,-1)) = nvl(v_cod_sub_modalidad,-1)
                                      AND nvl(cod_oficina,nvl(v_cod_oficina,-1))     = nvl(v_cod_oficina,-1)
                                      AND nvl(cod_ente,nvl(v_cod_ente,-1))           = nvl(v_cod_ente,-1)
                                      AND nvl(cod_moneda,nvl(v_cod_moneda,'x'))      = nvl(v_cod_moneda,'x')
                                      AND nvl(nro_cuenta,nvl(p_nro_cuenta,'x'))      = nvl(p_nro_cuenta,'x')
                                      AND cod_tasa = 900
                                      AND fec_vigencia <= v_fcdehoy);
           exception
              when others then
                 v_sal_promedio := 0;
           end;
        end if;
        --Obtener la cantidad de pagos de cheques deacuerdo al saldo promedio
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
    when others then
      IF sqlcode <= -20000 THEN
        raise;
      else
        raise_application_error(-20000,'Al buscar por personalización'||' - '||sqlerrm);
      End if;
  end;
exception
  when others then
    return 0;
/*    IF sqlcode <= -20000 THEN
      raise;
    else
      raise_application_error(-20000,'Cuenta Nro.:'||p_nro_cuenta||' - '||sqlerrm);
    End if;*/
end FUC_OBT_CAN_PAGOS;
/

