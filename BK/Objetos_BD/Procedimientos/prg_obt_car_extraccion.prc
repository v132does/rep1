create or replace procedure it.prg_obt_car_extraccion
 ( P_NRO_CUENTA       in GE_CUENTAS.NRO_CUENTA%TYPE
  ,P_TIP_CUENTA       in VARCHAR2
  ,P_COD_GRU_TRANSACCION  IN NUMBER  
  ,P_COD_TRA_CARGO    IN  GE_MOVIMIENTOS.COD_TRANSACCION%TYPE
  ,P_PAR_DINAMICO         IN VARCHAR2  
  ,P_COD_TAS_CARGO    OUT GE_MOVIMIENTOS.COD_TASA%TYPE
  ,P_VAL_TAS_CARGO    OUT GE_MOVIMIENTOS.VAL_TASA%TYPE
  ,P_VAL_CARGO        OUT GE_MOVIMIENTOS.VAL_TASA%TYPE
  ,P_COD_TRA_IMPUESTO OUT GE_MOVIMIENTOS.COD_TRANSACCION%TYPE
  ,P_COD_TAS_IMPUESTO OUT GE_MOVIMIENTOS.COD_TASA%TYPE
  ,P_VAL_TAS_IMPUESTO OUT GE_MOVIMIENTOS.VAL_TASA%TYPE
  ,P_VAL_IMPUESTO     OUT GE_MOVIMIENTOS.VAL_TASA%TYPE)
   is
   v_can_oper             number;
   v_can_ope_dia          number;
   v_can_ext_permitidas   number;
   v_fec_inicial          date;
   v_fcdehoy              date;
   v_anio_actual          number;
   v_mes_actual           number;
   v_can_pag_permitidos   number;
   v_sal_promedio         number;
   --Datos de la cuenta
   v_cod_modulo     ge_cuentas.cod_modulo%type;
   v_cod_modalidad  ge_cuentas.cod_modalidad%type;
   v_cod_moneda     ge_cuentas.cod_moneda%type;
   v_cod_oficina    ge_cuentas.cod_oficina%type;
   v_monloc         ba_monedas.cod_moneda%type;
   v_fec_apertura   date;
   v_redondeo       number;

begin
  v_fcdehoy     := pag_cal.fu_obt_fec_actual(3);
  v_fec_inicial := to_date('01/'||to_char(v_fcdehoy,'MM/YYYY'),'DD/MM/YYYY');
  v_monloc      := pag_gen.fu_obt_mon_local;
  v_anio_actual := to_number(to_char(v_fcdehoy,'YYYY'));
  v_mes_actual  := to_number(to_char(v_fcdehoy,'MM'));  
  --
  begin
    select cod_modulo, cod_modalidad, cod_moneda,cod_oficina, fec_apertura
      into v_cod_modulo, v_cod_modalidad, v_cod_moneda,v_cod_oficina, v_fec_apertura
      from ge_cuentas
     where nro_cuenta = p_nro_cuenta;
  exception
    when others then
      raise_application_error(-20000,'En obtener datos de la cuenta '||sqlerrm);
  end;
  v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',v_cod_modulo,v_cod_modalidad,v_cod_moneda);  
  if v_fec_apertura < v_fec_inicial then
      -- Obtener cantidad de operaciones realizadas en el mes
      If v_cod_modulo = 4 then
        select count(1)
          into v_can_oper
          from ge_transacciones, cc_movimientos_his
         where ge_transacciones.COD_MODULO(+) = cc_movimientos_his.COD_MODULO
           and ge_transacciones.COD_MODALIDAD(+) = cc_movimientos_his.COD_MODALIDAD
           and ge_transacciones.COD_TRANSACCION(+) = cc_movimientos_his.COD_TRANSACCION
           and nro_cuenta = p_nro_cuenta
           and fecha between v_fec_inicial and v_fcdehoy
           --and DECODE(cc_movimientos_his.COD_TRANSACCION,515,'C',565,'C',ge_transacciones.TIPO) = 'D'
           and estado = 'N'
           and reversado = 'N'
           --and cod_tra_padre in (382,354,355) 
           --and cc_movimientos_his.cod_transaccion in (503,590)
           and (cod_mod_padre, cod_mad_padre, cod_tra_padre) in (select cod_modulo, cod_modalidad, cod_transaccion
                                                                   from ge_gru_transacciones_det x
                                                                  where x.cod_gru_transaccion = p_cod_gru_transaccion)
           and monto > 0;
      elsif v_cod_modulo = 3 then
        select count(1)
          into v_can_oper
          from ge_transacciones, ah_movimientos_his
         where ge_transacciones.COD_MODULO(+) = ah_movimientos_his.COD_MODULO
           and ge_transacciones.COD_MODALIDAD(+) = ah_movimientos_his.COD_MODALIDAD
           and ge_transacciones.COD_TRANSACCION(+) = ah_movimientos_his.COD_TRANSACCION
           and nro_cuenta = p_nro_cuenta
           and fecha between v_fec_inicial and v_fcdehoy
           --and DECODE(ah_movimientos_his.COD_TRANSACCION,515,'C',565,'C',ge_transacciones.TIPO) = 'D'
           and estado = 'N'
           and reversado = 'N'
           and (cod_mod_padre, cod_mad_padre, cod_tra_padre) in (select cod_modulo, cod_modalidad, cod_transaccion
                                                                   from ge_gru_transacciones_det x
                                                                  where x.cod_gru_transaccion = p_cod_gru_transaccion)
           --and cod_tra_padre in (382,353) 
           --and ah_movimientos_his.cod_transaccion in (503,590)       
           and monto > 0;
      else
        select count(1)
          into v_can_oper
          from gv_movimientos
         where nro_cuenta = p_nro_cuenta
           and fecha between v_fec_inicial and v_fcdehoy
           and cod_tip_movimiento = 'D'
           and estado = 'N'
           and reversado = 'N'
           and (cod_mod_padre, cod_mad_padre, cod_tra_padre) in (select cod_modulo, cod_modalidad, cod_transaccion
                                                                   from ge_gru_transacciones_det x
                                                                  where x.cod_gru_transaccion = p_cod_gru_transaccion)
           and monto > 0;
      End if;

      if v_cod_modulo in (3,4) then
          select count(1)
            into v_can_ope_dia
            from ge_transacciones, ge_movimientos
           where ge_transacciones.COD_MODULO(+) = ge_movimientos.COD_MODULO
             and ge_transacciones.COD_MODALIDAD(+) = ge_movimientos.COD_MODALIDAD
             and ge_transacciones.COD_TRANSACCION(+) = ge_movimientos.COD_TRANSACCION
             and nro_cuenta = p_nro_cuenta
             --and DECODE(ge_movimientos.COD_TRANSACCION,515,'C',565,'C',ge_transacciones.TIPO) = 'D'
             and estado = 'N'
             and reversado = 'N'
             --and cod_tra_padre in (382,353,354,355) 
             --and ge_movimientos.cod_transaccion in (503,590)       
             and (cod_mod_padre, cod_mad_padre, cod_tra_padre) in (select cod_modulo, cod_modalidad, cod_transaccion
                                                                     from ge_gru_transacciones_det x
                                                                    where x.cod_gru_transaccion = p_cod_gru_transaccion)
             and monto > 0;
      end if;
      --Obtener la cantidad de extracciones permitidas
      -- RI : 02/12/09 : Se comenta la obtencion de la cantidad de extracciones permitidas
      -- ya que la cantidad permitida esta parametrizada en la tasa como "valor hasta"
      --
      --v_can_ext_permitidas := fug_obt_can_extracciones(p_nro_cuenta);
      -- sumo 
      
      v_can_oper := nvl(v_can_oper,0) + nvl(v_can_ope_dia,0); -- 1 por la transaccion actual
  
      --- RI : 02/12/09 : Se comenta la obtencion del cargo, ya que el mismo debe ser del tipo matricial,
      --- de acuerdo al saldo promedio se obtiene una tasa con esa tasa y de acuerdo a la cantidad
      --- de extracciones se obtiene el valor de la tasa
      --
      --Si las operaciones realizadas superan a las permitidas, si cobra el cargo
      /*If nvl(v_can_oper,0) > v_can_ext_permitidas  then
        prg_obt_cargos(v_cod_oficina,
                       p_nro_cuenta,
                       v_cod_moneda,
                       NULL,
                       v_cod_modulo,
                       v_cod_modalidad,
                       p_cod_tra_cargo,--Transaccion para el cobro de cargos por extraccion 
                       p_cod_tas_cargo,
                       p_val_tas_cargo,
                       p_val_cargo,
                       p_cod_tra_impuesto,
                       p_cod_tas_impuesto,
                       p_val_tas_impuesto,
                       p_val_impuesto);
    
      end if;*/
      
      -- RI : 02/12/09 : Desde aqui la obtencion del cargo en forma matricial
      ---
      -- Obtener el saldo promedio de la cuenta
      -- DYDMR-7653 Nov/2017 OMM se cambia para tener en cuenta la cantidad de operaciones completa.
       If nvl(v_can_oper,0) > 0 then    
          If  p_tip_cuenta = 'C' then  -- Cta. Cte.
            Begin 
             SELECT round(NVL(SAL_ACU_DIARIO,0)/CAN_DIA_ACUMULADO,v_redondeo)
               INTO v_sal_promedio
               FROM CC_SAL_MENSUALES
              WHERE NRO_CUENTA = p_nro_cuenta
                AND ANO = v_anio_actual
                AND MES = v_mes_actual
                AND NVL(CAN_DIA_ACUMULADO,0) <> 0;
            EXCEPTION
              WHEN NO_DATA_FOUND THEN
                v_sal_promedio := 0;
            END;      
          Elsif p_tip_cuenta = 'A' then  -- Ahorro
            Begin 
             SELECT round(NVL(SAL_ACU_DIARIO,0)/CAN_DIA_ACUMULADO,v_redondeo)
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
          END IF;  
          -- Proceso que obtiene el valor de la tasa a partir del saldo y la cantidad de extracciones
          prc_obt_cargos(v_cod_oficina,
                         p_nro_cuenta,
                         v_cod_moneda,
                         v_sal_promedio,
                         v_can_oper,   -- cantidad de extracciones
                         v_cod_modulo,
                         v_cod_modalidad,
                         p_cod_tra_cargo, --Transaccion para el cobro de cargos por extraccion
                         p_cod_tas_cargo,
                         p_val_tas_cargo,
                         p_val_cargo,
                         p_cod_tra_impuesto,
                         p_cod_tas_impuesto,
                         p_val_tas_impuesto,
                         p_val_impuesto,
                         v_can_pag_permitidos);
    End if;          
  end if;
exception
  when others then
    IF sqlcode <= -20000 THEN
      raise;
    else
      raise_application_error(-20000,'En obtener cargos'||' - '||sqlerrm);
    End if;
end prg_obt_car_extraccion;
/

