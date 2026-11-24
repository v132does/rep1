create or replace procedure it.prc_obt_car_pagos
 ( P_NRO_CUENTA       in GE_CUENTAS.NRO_CUENTA%TYPE
  ,P_COD_TAS_CARGO    OUT GE_MOVIMIENTOS.COD_TASA%TYPE
  ,P_VAL_TAS_CARGO    OUT GE_MOVIMIENTOS.VAL_TASA%TYPE
  ,P_VAL_CARGO        OUT GE_MOVIMIENTOS.VAL_TASA%TYPE
  ,P_COD_TRA_IMPUESTO OUT GE_MOVIMIENTOS.COD_TRANSACCION%TYPE
  ,P_COD_TAS_IMPUESTO OUT GE_MOVIMIENTOS.COD_TASA%TYPE
  ,P_VAL_TAS_IMPUESTO OUT GE_MOVIMIENTOS.VAL_TASA%TYPE
  ,P_VAL_IMPUESTO     OUT GE_MOVIMIENTOS.VAL_TASA%TYPE
  ,P_COD_TRANSACCION  OUT GE_MOVIMIENTOS.COD_TRANSACCION%TYPE
  ,P_HOR_ACTUAL       IN OUT GE_MOVIMIENTOS.HORA%TYPE
  ,P_NRO_sECUENCIA    IN OUT GE_MOVIMIENTOS.NRO_SECUENCIA%TYPE)
   is
   v_can_oper       number;
   v_can_ope_dia    number;
   v_can_pag_permitidos        number;
   v_fec_inicial    date;
   v_fcdehoy        date;
   v_anio_actual    number;
   v_mes_Actual     number;
   --Datos de la cuenta
   v_cod_modulo     ge_cuentas.cod_modulo%type;
   v_cod_modalidad  ge_cuentas.cod_modalidad%type;
   v_cod_moneda     ge_cuentas.cod_moneda%type;
   v_cod_oficina    ge_cuentas.cod_oficina%type;
   v_monloc         ba_monedas.cod_moneda%type;
   v_fec_apertura   date;
   v_sal_promedio   number;
   v_can_max_cheque number;
   v_can_operacion  number;
   v_nro_Secuencia  ge_movimientos.nro_Secuencia%type := p_nro_Secuencia;
   v_hor_actual     ge_movimientos.hora%type          := p_hor_actual;
begin
  v_fcdehoy     := pag_cal.fu_obt_fec_actual(4);
  v_fec_inicial := to_date('01/'||to_char(v_fcdehoy,'MM/YYYY'),'DD/MM/YYYY');
  v_monloc      := pag_gen.fu_obt_mon_local;
  v_anio_actual := to_number(to_char(v_fcdehoy,'YYYY'));
  v_mes_actual  := to_number(to_char(v_fcdehoy,'MM'));
  v_can_max_cheque := fug_obt_pardinamico('CAN_MAX_CHEQUE',NULL,NULL,NULL,NULL,NULL);

  begin
    select cod_modulo, cod_modalidad, cod_moneda,cod_oficina,fec_apertura
      into v_cod_modulo, v_cod_modalidad, v_cod_moneda,v_cod_oficina,v_fec_apertura
      from ge_cuentas
     where nro_cuenta = p_nro_cuenta;
  exception
    when others then
      raise_application_error(-20000,'En obtener datos de la cuenta '||sqlerrm);
  end;

  if v_fec_apertura < v_fec_inicial then
    --Obtener cantidad de operaciones realizadas en el mes
    select count(1)
      into v_can_oper
      from ge_transacciones, cc_movimientos_his
     where ge_transacciones.COD_MODULO(+) = cc_movimientos_his.COD_MODULO
       and ge_transacciones.COD_MODALIDAD(+) = cc_movimientos_his.COD_MODALIDAD
       and ge_transacciones.COD_TRANSACCION(+) = cc_movimientos_his.COD_TRANSACCION
       and nro_cuenta = p_nro_cuenta
       and fecha between v_fec_inicial and v_fcdehoy
       and DECODE(cc_movimientos_his.COD_TRANSACCION,515,'C',565,'C',ge_transacciones.TIPO) = 'D'
       and estado = 'N'
       and reversado = 'N'
       and cod_tra_padre in (354,355,320)
       and cc_movimientos_his.cod_transaccion in (590,521,591)
       and monto > 0;
    select count(1)
      into v_can_ope_dia
      from ge_transacciones, ge_movimientos
     where ge_transacciones.COD_MODULO(+) = ge_movimientos.COD_MODULO
       and ge_transacciones.COD_MODALIDAD(+) = ge_movimientos.COD_MODALIDAD
       and ge_transacciones.COD_TRANSACCION(+) = ge_movimientos.COD_TRANSACCION
       and nro_cuenta = p_nro_cuenta
       and DECODE(ge_movimientos.COD_TRANSACCION,515,'C',565,'C',ge_transacciones.TIPO) = 'D'
       and estado = 'N'
       and reversado = 'N'
       and cod_tra_padre in (354,355,320)
       and ge_movimientos.cod_transaccion in (590,521,591)
       and monto > 0;
    -- sumo con lo del dia los datos del historico
    v_can_oper := nvl(v_can_oper,0) + nvl(v_can_ope_dia,0);

    /* RI : 30/11/09 : Se comenta porque en el nuevo esquema de tasa matricial ya
      se se tiene la cantidad permitida de cheques   */
    --Obtener la cantidad de pagos de cheques permitidas
    --v_can_pag_permitidos := fuc_obt_can_pagos(p_nro_cuenta);

    --Si las operaciones realizadas superan a las permitidas, si cobra el cargo
  --If nvl(v_can_oper,0) > nvl(v_can_pag_permitidos,0)  then
      -- Obtener el saldo promedio de la cuenta
      Begin
       SELECT round(NVL(SAL_ACU_DIARIO,0)/CAN_DIA_ACUMULADO,0)
         INTO v_sal_promedio
         FROM AH_SAL_MENSUALES
        WHERE NRO_CUENTA = p_nro_cuenta
          AND ANO = v_anio_actual
          AND MES = v_mes_actual
          AND NVL(CAN_DIA_ACUMULADO,0) <> 0;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          v_sal_promedio := 0;
      END;
      --- Obtener cargo
--      v_can_oper := nvl(v_can_oper,0) - nvl(v_can_pag_permitidos,0);
      if v_can_oper > v_can_max_cheque then
       /* RI : 01/12/09 : Si la cantidad de operaciones es mayor a lo parametrizado entonces primero debe
         cobrar el cargo que le corresponde segun la tasa matricial segun transaccion 140
         y luego por la diferencia encima de la cantidad maxima le cobra la tasa segun transaccion 4111 */
        --
        --- Obtengo el cargo Segun Tasa Matricial
        prc_obt_cargos(v_cod_oficina,
                       p_nro_cuenta,
                       v_cod_moneda,
                       v_sal_promedio,
                       v_can_max_cheque, --se envia la maxima
                       v_cod_modulo,
                       v_cod_modalidad,
                       140,--Transaccion para el cobro de cargos por pago de cheques
                       p_cod_tas_cargo,
                       p_val_tas_cargo,
                       p_val_cargo,
                       p_cod_tra_impuesto,
                       p_cod_tas_impuesto,
                       p_val_tas_impuesto,
                       p_val_impuesto,
                       v_can_pag_permitidos);
         p_cod_transaccion := 140;
         v_can_operacion := v_Can_max_cheque - nvl(v_can_pag_permitidos,0);
         -- se calcula el valor por la cantidad
         p_val_cargo := p_val_cargo * v_can_operacion;
         p_val_impuesto := p_val_impuesto * v_can_operacion;

         --Realizar el cobro
         if v_nro_secuencia > 990 then
           v_hor_actual := pag_gen.fu_obt_sig_segundo(v_hor_actual);
           v_nro_secuencia := 0;
         end if;
         prc_cob_car_pagos(p_nro_cuenta,
                           p_COD_TAS_CARGO,
                           p_VAL_TAS_CARGO,
                           p_VAL_CARGO,
                           p_COD_TRA_IMPUESTO,
                           p_COD_TAS_IMPUESTO,
                           p_VAL_TAS_IMPUESTO,
                           p_VAL_IMPUESTO,
                           p_cod_Transaccion,
                           v_fcdehoy,
                           v_hor_actual,
                           v_nro_secuencia);

          --- Segun Tasa x Cantidad superior al maximo
          -- Limpio los parametros recibidos del anterior
          p_cod_tas_cargo := null;
          p_val_Tas_cargo := null;
          p_val_cargo     := null;
          p_cod_tra_impuesto := null;
          p_cod_tas_impuesto := null;
          p_Val_impuesto     := null;
          --Obtengo el cargo de la transaccion 4111
          prg_obt_cargos(v_cod_oficina,
                       p_nro_cuenta,
                       v_cod_moneda,
                       null,
                       v_cod_modulo,
                       v_cod_modalidad,
                       4111,--Transaccion para el cobro de cargos por pago de cheques a partir del maximo
                       p_cod_tas_cargo,
                       p_val_tas_cargo,
                       p_val_cargo,
                       p_cod_tra_impuesto,
                       p_cod_tas_impuesto,
                       p_val_tas_impuesto,
                       p_val_impuesto);
          p_cod_transaccion := 4111;
          v_can_operacion := nvl(v_can_oper,0) - nvl(v_can_max_cheque,0);
          -- se calcula el valor por la cantidad
          p_val_cargo := p_val_cargo * v_can_operacion;
          p_val_impuesto := p_val_impuesto * v_can_operacion;

         --Realizar el cobro
         if v_nro_secuencia > 990 then
           v_hor_actual := pag_gen.fu_obt_sig_segundo(v_hor_actual);
           v_nro_secuencia := 0;
         end if;
         prc_cob_car_pagos(p_nro_cuenta,
                           p_COD_TAS_CARGO,
                           p_VAL_TAS_CARGO,
                           p_VAL_CARGO,
                           p_COD_TRA_IMPUESTO,
                           p_COD_TAS_IMPUESTO,
                           p_VAL_TAS_IMPUESTO,
                           p_VAL_IMPUESTO,
                           p_cod_Transaccion,
                           v_fcdehoy,
                           v_hor_actual,
                           v_nro_Secuencia);

      else  --segun tasa matricial 140
        prc_obt_cargos(v_cod_oficina,
                       p_nro_cuenta,
                       v_cod_moneda,
                       v_sal_promedio,
                       v_can_oper,
                       v_cod_modulo,
                       v_cod_modalidad,
                       140,--Transaccion para el cobro de cargos por pago de cheques
                       p_cod_tas_cargo,
                       p_val_tas_cargo,
                       p_val_cargo,
                       p_cod_tra_impuesto,
                       p_cod_tas_impuesto,
                       p_val_tas_impuesto,
                       p_val_impuesto,
                       v_can_pag_permitidos);
         p_cod_transaccion := 140;
         v_can_oper := nvl(v_can_oper,0) - nvl(v_can_pag_permitidos,0);
         -- se calcula el valor por la cantidad
         p_val_cargo := p_val_cargo * v_can_oper;
         p_val_impuesto := p_val_impuesto * v_can_oper;

         --Realizar el cobro
         if v_nro_secuencia > 990 then
           v_hor_actual := pag_gen.fu_obt_sig_segundo(v_hor_actual);
           v_nro_secuencia := 0;
         end if;
         prc_cob_car_pagos(p_nro_cuenta,
                           p_COD_TAS_CARGO,
                           p_VAL_TAS_CARGO,
                           p_VAL_CARGO,
                           p_COD_TRA_IMPUESTO,
                           p_COD_TAS_IMPUESTO,
                           p_VAL_TAS_IMPUESTO,
                           p_VAL_IMPUESTO,
                           p_cod_Transaccion,
                           v_fcdehoy,
                           v_hor_actual,
                           v_nro_Secuencia);
     end if;
 End if;
 p_hor_actual    := v_hor_Actual;
 p_nro_Secuencia := v_nro_Secuencia;
exception
  when others then
    IF sqlcode <= -20000 THEN
      raise;
    else
      raise_application_error(-20000,'En obtener cargos por pago de cheques'||' - '||sqlerrm);
    End if;
end prc_obt_car_pagos;
/

