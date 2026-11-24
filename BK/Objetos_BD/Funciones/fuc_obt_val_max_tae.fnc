CREATE OR REPLACE FUNCTION IT."FUC_OBT_VAL_MAX_TAE" (p_nro_cuenta      in ge_cuentas.nro_cuenta%type,
                                               p_cod_modulo      in ge_cuentas.cod_modulo%type,
                                               p_cod_modalidad   in ge_cuentas.cod_modalidad%type,
                                               p_cod_transaccion in ge_movimientos.cod_transaccion%type,
                                               p_val_cargo       in ge_movimientos.val_tasa%type)
  return number is
  v_monto              ge_movimientos.monto%type;
  v_tot_monto          ge_movimientos.monto%type;                     --Monto Total Cobrado Anteriormente
  v_tot_sobregiro      ge_movimientos.monto%type;                     --Total Sobregiro (Base p/ el Calculo)
  v_tot_gral           ge_movimientos.monto%type;
  v_val_cargo          ge_movimientos.monto%type;                     --Monto Cargo/Interes a Cobrar
  v_cod_grupo          ge_gru_transacciones.cod_gru_transaccion%type;
  v_tas_efectiva       ge_movimientos.val_tasa%type;                  --TAE
  v_monto_maximo       ge_movimientos.monto%type;
  v_afecta             varchar2(1) := 'N';
  v_redondeo           number;
  v_ultdiam            date;
  v_fecha              date := pag_cal.fu_obt_fec_actual(4);
  rv_cta               ge_cuentas%rowtype;
  ---
  v_can_dia_sobregiro  number;
  v_pro_sobregiro      ge_movimientos.monto%type := 0;
  v_tas_maxima         ge_movimientos.val_tasa%type; 
  
  FUNCTION lf_obt_tir
   (
      p_tasa    IN NUMBER,
      p_periodo IN NUMBER
   ) RETURN NUMBER IS
      v_radicando NUMBER;
      v_indice    NUMBER;
      v_potencia  NUMBER;
      v_tan       NUMBER;
      v_tir       NUMBER;

   BEGIN
      v_radicando := (p_tasa / 100) + 1;
      v_indice    := 365 / nvl(p_periodo, 1);
      v_potencia  := power(v_radicando, (1 / v_indice));
      v_tan       := ((v_potencia - 1) * 36500) / nvl(p_periodo, 1);
      v_tir       := v_tan * nvl(p_periodo, 1) / 365;
      RETURN v_tir;
   END;

begin

  --Verificar si existe la cuenta
  begin
    select *
      into rv_cta
      from ge_cuentas c
     where c.nro_cuenta = p_nro_cuenta;
  exception
    when no_data_found then
       raise_application_error(-20001,'No existe la Cuenta Nro.: '||p_nro_cuenta);
  end;

  v_cod_grupo      := fug_obt_pardinamico('GRU_CAR_TAE_SOBREGIRO',p_cod_modulo,p_cod_modalidad,null);
  v_redondeo       := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',p_cod_modulo,p_cod_modalidad,rv_cta.cod_moneda);
  v_val_cargo      := p_val_cargo;
  v_tot_monto      := 0;

  --Validar el Importe del Cargo
  if v_val_cargo < 0 then
     raise_application_error(-20001,'El Valor del Cargo no puede ser Negativo. Cuenta Nro.: '||p_nro_cuenta);
  end if;

  begin
    --Traer la Tasa Efectiva
    select v.tas_efectiva
      into v_tas_efectiva
      from cr_piz_plazos v
     where v.cod_modulo = p_cod_modulo
       and v.cod_modalidad = p_cod_modalidad
       and v.cod_moneda = rv_cta.cod_moneda;
  exception
    when no_data_found then
      v_tas_efectiva := null;
    when too_many_rows then
      raise_application_error(-20001,'TASA EFECTIVA Duplicada en la Pizarra de Productos. Módulo: '||p_cod_modulo||'; Modalidad: '||p_cod_modalidad);
  end;

  --Verificar si la transacción que se intenta cobrar afecta el calculo del TAE
  begin
    select 'S'
      into v_afecta
      from ge_gru_transacciones_det d
     where d.cod_modulo = p_cod_modulo
       and d.cod_modalidad = p_cod_modalidad
       and d.cod_transaccion = p_cod_transaccion
       and d.cod_gru_transaccion = v_cod_grupo;
  exception
    when no_data_found then
       v_afecta := 'N';
  end;

  if v_afecta = 'S' and v_tas_efectiva is not null then
    select ult_dia_mes
      into v_ultdiam
      from ge_calendarios c
     where c.cod_modulo = 4;

    --Obtener la Sumatoria de Montos Sobregirados
    select sum(saldo), count(can_dias)
      into v_tot_sobregiro, v_can_dia_sobregiro
     from cc_sobregiros
     where nro_cuenta = p_nro_cuenta
       and liquidado = 'N'
       and fecha <= v_ultdiam
     order by nro_cuenta,fecha;

      IF nvl(v_can_dia_sobregiro,0) > 0 THEN
         v_pro_sobregiro := v_tot_sobregiro / v_can_dia_sobregiro;
      END IF;


    --Totalizar las Transacciones Cobradas Anteriormente y que afectan el calculo del TAE
    for k in (select monto
                from ge_movimientos t
               where t.fecha = v_fecha
                 and t.nro_cuenta = p_nro_cuenta
                 and t.reversado = 'N'
                 and t.estado = 'N'
                 and t.monto > 0
                 and t.cod_transaccion in
                     (select d.Cod_Transaccion
                        from ge_gru_transacciones_det d
                       where d.cod_modulo = p_cod_modulo
                         and d.cod_modalidad = p_cod_modalidad
                         and d.cod_gru_transaccion = v_cod_grupo)
              ) loop

        --Monto Cobrado (No incluye Impuesto)
        v_monto := k.monto;

        --Acumular el total Cobrado Anteriormente
        v_tot_monto := v_tot_monto + v_monto;

    end loop;

    v_tot_gral := v_tot_monto + v_val_cargo;

    --Validar Sumatoria de Saldos Sobregirados
    if nvl(v_tot_sobregiro,0) < 0 then
       raise_application_error(-20001,'La Suma de Saldos Sobregirados es Menor a Cero, Verifique. Cuenta Nro.: '||p_nro_cuenta);
    end if;

    --Validar Valor del TAE
    if v_tas_efectiva not between 0 and 100 then
       raise_application_error(-20001,'El valor del TAE debe estar entre 0 y 100');
    end if;

    --Calcular el Monto Máximo s/ TAE
    v_tas_maxima := lf_obt_tir(v_tas_efectiva,v_can_dia_sobregiro);
    v_monto_maximo := round((nvl(v_pro_sobregiro,0) * v_tas_maxima)/100,v_redondeo);

    if v_tot_monto < v_monto_maximo then
      --Verificar si el Total Gral. excede y ajustar al monto máximo
      if v_tot_gral > v_monto_maximo then
         v_val_cargo := v_monto_maximo - v_tot_monto;
      end if;
    else
      v_val_cargo := 0; --Ya se llego al máximo con los Cobros Anteriores, no cobrar el cargo
    end if;

  end if; --Fin IF Afecta

  return v_val_cargo;

end fuc_obt_val_max_tae;
/

