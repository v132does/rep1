create or replace procedure it.prc_pro_cob_car_pagos_V2(p_nro_cuenta in varchar2 default null) is
  V_COD_TAS_CARGO     GE_MOVIMIENTOS.COD_TASA%TYPE;
  V_VAL_TAS_CARGO     GE_MOVIMIENTOS.VAL_TASA%TYPE;
  V_VAL_CARGO         GE_MOVIMIENTOS.VAL_TASA%TYPE;
  V_COD_TRA_IMPUESTO  GE_MOVIMIENTOS.COD_TRANSACCION%TYPE;
  V_COD_TAS_IMPUESTO  GE_MOVIMIENTOS.COD_TASA%TYPE;
  V_VAL_TAS_IMPUESTO  GE_MOVIMIENTOS.VAL_TASA%TYPE;
  V_VAL_IMPUESTO      GE_MOVIMIENTOS.VAL_TASA%TYPE;
  V_COD_tRANSACCION   GE_MOVIMIENTOS.COD_TRANSACCION%TYPE;

  v_hor_actual        varchar2(08) ;
  v_fec_actual        date;
  v_nro_secuencia     number(3) := 0;
  v_nvo_estado        varchar2(1);
  v_sal_disponible    number;
  v_procesa           varchar2(1);

  v_can_oper       number;
  v_can_ope_dia    number;
  v_can_pag_permitidos        number;
  v_fec_inicial    date;
  v_anio_actual    number;
  v_mes_Actual     number;
  v_can_max_cheque number;
  v_can_operacion  number;
  --Datos de la cuenta
  v_cod_modulo     ge_cuentas.cod_modulo%type;
  v_cod_modalidad  ge_cuentas.cod_modalidad%type;
  v_cod_moneda     ge_cuentas.cod_moneda%type;
  v_cod_oficina    ge_cuentas.cod_oficina%type;
  v_monloc         ba_monedas.cod_moneda%type;
  v_fec_apertura   date;
  v_sal_promedio   number;
  v_nro_cta_ahorro varchar2(20);
  v_redondeo       number;
  v_can_exonerar   number;
  --Cursor de cuentas
  cursor ctas is
  select nro_cuenta,cod_moneda,cod_oficina,cta_combinada
    from cc_cta_corrientes c
    where 0 <>  (select count(*) from ge_movimientos m WHERE FECHA = TO_dATE('01/02/2010','DD/MM/YYYY') AND CONCEPTO = 'Devolución de Comisión'
                 AND COD_tRANSACCION IN(140,517,4111) and m.nro_cuenta = c.nro_cuenta)
      and cod_modulo    = 4
      and cod_modalidad = 41
      and estado not in ('T','C','A','X');
  /* Obtiene la Cta Cte si es una Cuenta Combinada. */
  FUNCTION LF_OBT_CTA_AHO_COMB
   (P_NRO_CUENTA IN AH_CTA_VISTAS.NRO_CUENTA%TYPE
   )
   RETURN VARCHAR2
   IS

  V_NRO_CTA_AHO CC_CTA_COMBINADAS.NRO_CTA_AHORRO%TYPE;
  BEGIN
       SELECT NRO_CTA_AHORRO
         INTO V_NRO_CTA_AHO
         FROM CC_CTA_COMBINADAS
        WHERE NRO_CTA_CTE = P_NRO_CUENTA;
       RETURN V_NRO_CTA_AHO;
  EXCEPTION
     WHEN NO_DATA_FOUND THEN
        RETURN null;
     WHEN OTHERS THEN
        RETURN null;
  END;
  --
begin
  Begin pre_ini_aplicacion; pae_cnf.G_COD_MODULO:=1;end;
  v_fec_actual := pag_cal.fu_obt_fec_actual('4');
  v_hor_actual := fug_ini_hora(sysdate,'HH24:MI:SS');
  v_fec_inicial := to_date('01/'||to_char(v_fec_Actual,'MM/YYYY'),'DD/MM/YYYY');
  v_monloc      := pag_gen.fu_obt_mon_local;
  v_anio_actual := to_number(to_char(v_fec_actual,'YYYY'));
  v_mes_actual  := to_number(to_char(v_fec_Actual,'MM'));
  v_can_max_cheque := fug_obt_pardinamico('CAN_MAX_CHEQUE',NULL,NULL,NULL,NULL,NULL);
  for reg in ctas loop
    begin
      select cod_modulo, cod_modalidad, cod_moneda,cod_oficina,fec_apertura
        into v_cod_modulo, v_cod_modalidad, v_cod_moneda,v_cod_oficina,v_fec_apertura
        from ge_cuentas
       where nro_cuenta = reg.nro_cuenta;
    exception
      when others then
        raise_application_error(-20000,'En obtener datos de la cuenta '||sqlerrm);
    end;
    v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',v_cod_modulo,v_cod_modalidad,v_cod_moneda);
    if v_fec_apertura < v_fec_inicial then
        --Obtener cantidad de operaciones realizadas en el mes
        select count(1)
          into v_can_oper
          from ge_transacciones, cc_movimientos_his
         where ge_transacciones.COD_MODULO(+) = cc_movimientos_his.COD_MODULO
           and ge_transacciones.COD_MODALIDAD(+) = cc_movimientos_his.COD_MODALIDAD
           and ge_transacciones.COD_TRANSACCION(+) = cc_movimientos_his.COD_TRANSACCION
           and nro_cuenta = reg.nro_cuenta
           --and fecha between v_fec_inicial and v_fec_actual
           and fecha between to_Date('01/01/2010','dd/mm/yyyy') and to_date('31/01/2010','dd/mm/yyyy')
           and DECODE(cc_movimientos_his.COD_TRANSACCION,515,'C',565,'C',ge_transacciones.TIPO) = 'D'
           and estado = 'N'
           and reversado = 'N'
           and cod_tra_padre in (354,355,320)
           and cc_movimientos_his.cod_transaccion in (590,521,591)
           and monto > 0;
           
           v_can_ope_dia := 0;
/*        select count(1)
          into v_can_ope_dia
          from ge_transacciones, ge_movimientos
         where ge_transacciones.COD_MODULO(+) = ge_movimientos.COD_MODULO
           and ge_transacciones.COD_MODALIDAD(+) = ge_movimientos.COD_MODALIDAD
           and ge_transacciones.COD_TRANSACCION(+) = ge_movimientos.COD_TRANSACCION
           and nro_cuenta = reg.nro_cuenta
           and DECODE(ge_movimientos.COD_TRANSACCION,515,'C',565,'C',ge_transacciones.TIPO) = 'D'
           and estado = 'N'
           and reversado = 'N'
           and cod_tra_padre in (354,355,320)
           and ge_movimientos.cod_transaccion in (590,521,591)
           and monto > 0;*/
        -- sumo con lo del dia los datos del historico
        v_can_oper := nvl(v_can_oper,0) + nvl(v_can_ope_dia,0);

        /* RI : 30/11/09 : Se comenta porque en el nuevo esquema de tasa matricial ya
          se se tiene la cantidad permitida de cheques   */
        --Obtener la cantidad de pagos de cheques permitidas
        --v_can_pag_permitidos := fuc_obt_can_pagos(reg.nro_cuenta);

        --Si las operaciones realizadas superan a las permitidas, si cobra el cargo
      --If nvl(v_can_oper,0) > nvl(v_can_pag_permitidos,0)  then
          -- Obtener el saldo promedio de la cuenta
       If nvl(v_can_oper,0) > 0 then
          Begin
           SELECT nvl(round(NVL(SAL_ACU_DIARIO,0)/CAN_DIA_ACUMULADO,0),0)
             INTO v_sal_promedio
             FROM CC_SAL_MENSUALES
            WHERE NRO_CUENTA = reg.nro_cuenta
              AND ANO = 2010
              AND MES = 1
              AND NVL(CAN_DIA_ACUMULADO,0) <> 0;
            if reg.cta_combinada = 'S' then
                v_nro_cta_ahorro := LF_OBT_CTA_AHO_COMB(reg.nro_cuenta);
                if v_nro_cta_ahorro is not null then
                   -- es combinada
                   SELECT round(NVL(SAL_ACU_DIARIO,0)/CAN_DIA_ACUMULADO,0) +
                          NVL(v_sal_promedio,0)
                     INTO v_sal_promedio
                     FROM AH_SAL_MENSUALES
                    WHERE NRO_CUENTA = v_nro_cta_ahorro
                      AND ANO = 2010
                      AND MES = 1
                      AND NVL(CAN_DIA_ACUMULADO,0) <> 0;
                end if;
            end if;
          EXCEPTION
            WHEN NO_DATA_FOUND THEN
              v_sal_promedio := 0;
          END;
          --- Obtener cargo
          v_can_exonerar := 0;
    --      v_can_oper := nvl(v_can_oper,0) - nvl(v_can_pag_permitidos,0);
          if v_can_oper > v_can_max_cheque then
           /* RI : 01/12/09 : Si la cantidad de operaciones es mayor a lo parametrizado entonces primero debe
             cobrar el cargo que le corresponde segun la tasa matricial segun transaccion 140
             y luego por la diferencia encima de la cantidad maxima le cobra la tasa segun transaccion 4111 */
            --
            --- Obtengo el cargo Segun Tasa Matricial
            prc_obt_cargos(v_cod_oficina,
                           reg.nro_cuenta,
                           v_cod_moneda,
                           v_sal_promedio,
                           v_can_max_cheque, --se envia la maxima
                           v_cod_modulo,
                           v_cod_modalidad,
                           140,--Transaccion para el cobro de cargos por pago de cheques
                           v_cod_tas_cargo,
                           v_val_tas_cargo,
                           v_val_cargo,
                           v_cod_tra_impuesto,
                           v_cod_tas_impuesto,
                           v_val_tas_impuesto,
                           v_val_impuesto,
                           v_can_pag_permitidos);
             v_cod_transaccion := 140;
             v_can_operacion := v_Can_max_cheque - nvl(v_can_pag_permitidos,0);
             If v_can_operacion > 0 then
               -- RI : 30/01/10 : Volver a sumar el cargo y el iva para multiplicar por la cantidad y despues volver a calcular el iva
                v_val_cargo := (v_val_cargo + v_val_impuesto) * v_can_operacion;
                v_val_impuesto := round(nvl(v_val_cargo,0)*
                                      nvl(v_val_tas_impuesto,0)/(100+v_val_tas_impuesto),v_redondeo);
                v_val_Cargo    := round(nvl(v_val_Cargo,0) - nvl(v_val_impuesto,0),v_redondeo);

             -- se calcula el valor por la cantidad
             -- v_val_cargo := v_val_cargo * v_can_operacion;
             -- v_val_impuesto := v_val_impuesto * v_can_operacion;

               --Realizar el cobro
               if v_nro_secuencia > 990 then
                v_hor_actual := pag_gen.fu_obt_sig_segundo(v_hor_actual);
                v_nro_secuencia := 0;
               end if;
               prc_cob_car_pagos(reg.nro_cuenta,
                               v_COD_TAS_CARGO,
                               v_VAL_TAS_CARGO,
                               v_VAL_CARGO,
                               v_COD_TRA_IMPUESTO,
                               v_COD_TAS_IMPUESTO,
                               v_VAL_TAS_IMPUESTO,
                               v_VAL_IMPUESTO,
                               v_cod_Transaccion,
                               v_fec_Actual,
                               v_hor_actual,
                               v_nro_secuencia);
             Else
                --si el resultado es negativo significa que la cantidad exonerada
                --es mayor al tope, guardamos el valor absoluto porque esa
                --cantidad se debe exonerar en la 4111
                v_can_exonerar := abs(v_can_operacion);
             end if;
             --- Segun Tasa x Cantidad superior al maximo
             -- Limpio los parametros recibidos del anterior
              v_cod_tas_cargo := null;
              v_val_Tas_cargo := null;
              v_val_cargo     := null;
              v_cod_tra_impuesto := null;
              v_cod_tas_impuesto := null;
              v_Val_impuesto     := null;
              --Obtengo el cargo de la transaccion 4111
              prg_obt_cargos(v_cod_oficina,
                           reg.nro_cuenta,
                           v_cod_moneda,
                           null,
                           v_cod_modulo,
                           v_cod_modalidad,
                           4111,--Transaccion para el cobro de cargos por pago de cheques a partir del maximo
                           v_cod_tas_cargo,
                           v_val_tas_cargo,
                           v_val_cargo,
                           v_cod_tra_impuesto,
                           v_cod_tas_impuesto,
                           v_val_tas_impuesto,
                           v_val_impuesto);
              v_cod_transaccion := 4111;
              v_can_operacion := nvl(v_can_oper,0) - nvl(v_can_max_cheque,0) - nvl(v_can_exonerar,0);

             -- RI : 30/01/10 : Volver a sumar el cargo y el iva para multiplicar por la cantidad y despues volver a calcular el iva
              if  v_can_operacion > 0 then
                v_val_cargo := (v_val_cargo + v_val_impuesto) * v_can_operacion;
                v_val_impuesto := round(nvl(v_val_cargo,0)*
                                      nvl(v_val_tas_impuesto,0)/(100+v_val_tas_impuesto),v_redondeo);
                v_val_Cargo    := round(nvl(v_val_Cargo,0) - nvl(v_val_impuesto,0),v_redondeo);
              --
              -- se calcula el valor por la cantidad
              --v_val_cargo := v_val_cargo * v_can_operacion;
              --v_val_impuesto := v_val_impuesto * v_can_operacion;

             --Realizar el cobro
               if v_nro_secuencia > 990 then
                 v_hor_actual := pag_gen.fu_obt_sig_segundo(v_hor_actual);
                 v_nro_secuencia := 0;
               end if;
               prc_cob_car_pagos(reg.nro_cuenta,
                                 v_COD_TAS_CARGO,
                                 v_VAL_TAS_CARGO,
                                 v_VAL_CARGO,
                                 v_COD_TRA_IMPUESTO,
                                 v_COD_TAS_IMPUESTO,
                                 v_VAL_TAS_IMPUESTO,
                                 v_VAL_IMPUESTO,
                                 v_cod_Transaccion,
                                 v_fec_Actual,
                                 v_hor_actual,
                                 v_nro_secuencia);
              end if;                    
          else  --segun tasa matricial 140
            prc_obt_cargos(v_cod_oficina,
                           reg.nro_cuenta,
                           v_cod_moneda,
                           v_sal_promedio,
                           v_can_oper,
                           v_cod_modulo,
                           v_cod_modalidad,
                           140,--Transaccion para el cobro de cargos por pago de cheques
                           v_cod_tas_cargo,
                           v_val_tas_cargo,
                           v_val_cargo,
                           v_cod_tra_impuesto,
                           v_cod_tas_impuesto,
                           v_val_tas_impuesto,
                           v_val_impuesto,
                           v_can_pag_permitidos);
             v_cod_transaccion := 140;
             v_can_oper := nvl(v_can_oper,0) - nvl(v_can_pag_permitidos,0);
             -- RI : 30/01/10 : Volver a sumar el cargo y el iva para multiplicar por la cantidad y despues volver a calcular el iva
             if v_can_oper > 0 then
                v_val_cargo := (v_val_cargo + v_val_impuesto) * v_can_oper;
                v_val_impuesto := round(nvl(v_val_cargo,0)*
                                      nvl(v_val_tas_impuesto,0)/(100+v_val_tas_impuesto),v_redondeo);
                v_val_Cargo    := round(nvl(v_val_Cargo,0) - nvl(v_val_impuesto,0),v_redondeo);

             -- se calcula el valor por la cantidad
             -- v_val_cargo := v_val_cargo * v_can_oper;
             -- v_val_impuesto := v_val_impuesto * v_can_oper;

               --Realizar el cobro
               if v_nro_secuencia > 990 then
                 v_hor_actual := pag_gen.fu_obt_sig_segundo(v_hor_actual);
                 v_nro_secuencia := 0;
               end if;
               prc_cob_car_pagos(reg.nro_cuenta,
                                 v_COD_TAS_CARGO,
                                 v_VAL_TAS_CARGO,
                                 v_VAL_CARGO,
                                 v_COD_TRA_IMPUESTO,
                                 v_COD_TAS_IMPUESTO,
                                 v_VAL_TAS_IMPUESTO,
                                 v_VAL_IMPUESTO,
                                 v_cod_Transaccion,
                                 v_Fec_actual,
                                 v_hor_actual,
                                 v_nro_Secuencia);
                end if;                                 
         end if;
      End if;
     End if;
  end loop;
end prc_pro_cob_car_pagos_v2;
/

