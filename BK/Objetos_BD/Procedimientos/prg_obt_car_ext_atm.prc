create or replace procedure it.prg_obt_car_ext_atm
 /* retorna el cargo e iva a ser cobrado por el uso de otros atms */
 ( P_NRO_CUENTA           in GE_CUENTAS.NRO_CUENTA%TYPE
  ,P_COD_GRU_TRANSACCION  IN NUMBER
  ,P_COD_TAS_CARGO        OUT GE_MOVIMIENTOS.COD_TASA%TYPE
  ,P_VAL_TAS_CARGO        OUT GE_MOVIMIENTOS.VAL_TASA%TYPE
  ,P_VAL_CARGO            OUT GE_MOVIMIENTOS.VAL_TASA%TYPE
  ,P_COD_TRA_IMPUESTO     OUT GE_MOVIMIENTOS.COD_TRANSACCION%TYPE
  ,P_COD_TAS_IMPUESTO     OUT GE_MOVIMIENTOS.COD_TASA%TYPE
  ,P_VAL_TAS_IMPUESTO     OUT GE_MOVIMIENTOS.VAL_TASA%TYPE
  ,P_VAL_IMPUESTO         OUT GE_MOVIMIENTOS.VAL_TASA%TYPE)
   is
   v_can_ope_his    number;
   v_can_ope_dia    number;
   v_can_ext_permitidas        number;
   v_fec_inicial    date;
   v_fcdehoy        date;
   --Datos de la cuenta
   v_cod_modulo     ge_cuentas.cod_modulo%type;
   v_cod_modalidad  ge_cuentas.cod_modalidad%type;
   v_cod_moneda     ge_cuentas.cod_moneda%type;
   v_cod_oficina    ge_cuentas.cod_oficina%type;
   v_monloc         ba_monedas.cod_moneda%type;
   v_fec_apertura   date;
   --
   v_cod_bco_entidad number(5) := fug_obt_cod_banco;
   --
   v_cod_tas_limite number(5);
begin
  v_fcdehoy     := pag_cal.fu_obt_fec_actual(3);
  v_fec_inicial := to_date('01/'||to_char(v_fcdehoy,'MM/YYYY'),'DD/MM/YYYY');
  v_monloc      := pag_gen.fu_obt_mon_local;
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
  begin
     select a.cod_tas_limite
       into v_cod_tas_limite
       from ge_mov_sin_costo a
      where a.cod_gru_transaccion = p_cod_gru_transaccion;
  end;
  if v_fec_apertura < v_fec_inicial then
      -- Obtener cantidad de operaciones realizadas en el mes
      If v_cod_modulo = 4 then
        select count(1)
          into v_can_ope_his
          from ge_transacciones, cc_movimientos_his
         where ge_transacciones.COD_MODULO(+) = cc_movimientos_his.COD_MODULO
           and ge_transacciones.COD_MODALIDAD(+) = cc_movimientos_his.COD_MODALIDAD
           and ge_transacciones.COD_TRANSACCION(+) = cc_movimientos_his.COD_TRANSACCION
           and nro_cuenta = p_nro_cuenta
           and fecha between v_fec_inicial and v_fcdehoy
           and estado = 'N'
           and reversado = 'N'
           and cod_banco <> v_cod_bco_entidad
           and nro_documento2 /* nro_atm*/ not IN (select g.cod_atm
                                              from cj_atm_entidades g
                                             where g.estado = 'A')
           and (cod_mod_padre, cod_mad_padre, cod_tra_padre) in (select cod_modulo, cod_modalidad, cod_transaccion
                                                                   from ge_gru_transacciones_det x
                                                                  where x.cod_gru_transaccion = p_cod_gru_transaccion);

      elsif v_cod_modulo = 3 then
        select count(1)
          into v_can_ope_his
          from ge_transacciones, ah_movimientos_his
         where ge_transacciones.COD_MODULO(+) = ah_movimientos_his.COD_MODULO
           and ge_transacciones.COD_MODALIDAD(+) = ah_movimientos_his.COD_MODALIDAD
           and ge_transacciones.COD_TRANSACCION(+) = ah_movimientos_his.COD_TRANSACCION
           and nro_cuenta = p_nro_cuenta
           and fecha between v_fec_inicial and v_fcdehoy
           and estado = 'N'
           and reversado = 'N'
           and cod_banco <> v_cod_bco_entidad
           and nro_documento2 /* nro_atm*/ not IN (select g.cod_atm
                                              from cj_atm_entidades g
                                             where g.estado = 'A')
           and (cod_mod_padre, cod_mad_padre, cod_tra_padre) in (select cod_modulo, cod_modalidad, cod_transaccion
                                                                   from ge_gru_transacciones_det x
                                                                  where x.cod_gru_transaccion = p_cod_gru_transaccion)
                      ;
      else
        select count(1)
          into v_can_ope_his
          from gv_movimientos
         where nro_cuenta = p_nro_cuenta
           and fecha between v_fec_inicial and v_fcdehoy
           and estado = 'N'
           and reversado = 'N'
           and cod_banco <> v_cod_bco_entidad
           and nro_documento2 /* nro_atm*/ not IN (select g.cod_atm
                                              from cj_atm_entidades g
                                             where g.estado = 'A')
           and (cod_mod_padre, cod_mad_padre, cod_tra_padre) in (select cod_modulo, cod_modalidad, cod_transaccion
                                                                   from ge_gru_transacciones_det x
                                                                  where x.cod_gru_transaccion = p_cod_gru_transaccion);

      End if;
      if v_cod_modulo in (3,4) then
          select count(1)
            into v_can_ope_dia
            from ge_transacciones, ge_movimientos
           where ge_transacciones.COD_MODULO(+) = ge_movimientos.COD_MODULO
             and ge_transacciones.COD_MODALIDAD(+) = ge_movimientos.COD_MODALIDAD
             and ge_transacciones.COD_TRANSACCION(+) = ge_movimientos.COD_TRANSACCION
             and nro_cuenta = p_nro_cuenta
             and estado = 'N'
             and reversado = 'N'
             and cod_banco <> v_cod_bco_entidad
           and nro_documento2 /* nro_atm*/ not IN (select g.cod_atm
                                              from cj_atm_entidades g
                                             where g.estado = 'A')
             and (cod_mod_padre, cod_mad_padre, cod_tra_padre) in (select cod_modulo, cod_modalidad, cod_transaccion
                                                                     from ge_gru_transacciones_det x
                                                                    where x.cod_gru_transaccion = p_cod_gru_transaccion);

      end if;
      --Obtener la cantidad de uso de otros atms
      v_can_ext_permitidas := fug_obt_can_permitidas(p_nro_cuenta, v_cod_tas_limite, 'CAN_MAX_USO_OTR_ATM');
      if nvl(v_can_ext_permitidas,0) > nvl(v_can_ope_his,0) then
        v_can_ext_permitidas :=  nvl(v_can_ext_permitidas,0) - nvl(v_can_ope_his,0); -- le bajo las ya realizadas hasta ayer
      else
        v_can_ext_permitidas := 0; -- ya no tiene permitida ninguna transaccion, porque ya se exedio en la historia
      end if;
      --Si las operaciones realizadas superan a las permitidas, si cobra el cargo
      If nvl(v_can_ope_dia,0) > v_can_ext_permitidas  then
        prg_obt_cargos(v_cod_oficina,
                       p_nro_cuenta,
                       v_cod_moneda,
                       NULL,
                       v_cod_modulo,
                       v_cod_modalidad,
                       145,--Transaccion para el cobro de cargos por uso de otro atm
                       p_cod_tas_cargo,
                       p_val_tas_cargo,
                       p_val_cargo,
                       p_cod_tra_impuesto,
                       p_cod_tas_impuesto,
                       p_val_tas_impuesto,
                       p_val_impuesto);
       v_can_ope_dia := nvl(v_can_ope_dia,0) - nvl(v_can_ext_permitidas,0);
       -- se calcula el valor por la cantidad
       p_val_cargo := p_val_cargo * v_can_ope_dia;
       p_val_impuesto := p_val_impuesto * v_can_ope_dia;

      end if;
  end if;
exception
  when others then
    IF sqlcode <= -20000 THEN
      raise;
    else
      raise_application_error(-20000,'En obtener cargos'||' - '||sqlerrm);
    End if;
end prg_obt_car_ext_atm;
/

