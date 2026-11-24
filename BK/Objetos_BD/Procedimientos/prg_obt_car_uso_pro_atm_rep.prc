CREATE OR REPLACE PROCEDURE IT.PRG_OBT_CAR_USO_PRO_ATM_REP
 /* retorna el cargo e iva a ser cobrado por el uso de nuetros atms */
 ( P_NRO_CUENTA           in GE_CUENTAS.NRO_CUENTA%TYPE
  ,P_COD_GRU_TRANSACCION  IN GE_GRU_TRANSACCIONES.COD_GRU_TRANSACCION%TYPE
  ,P_COD_TRANSACCION      IN GE_MOVIMIENTOS.COD_TRANSACCION%TYPE
  ,P_PAR_DINAMICO         IN VARCHAR2
  ,P_COD_TAS_CARGO        OUT GE_MOVIMIENTOS.COD_TASA%TYPE
  ,P_VAL_TAS_CARGO        OUT GE_MOVIMIENTOS.VAL_TASA%TYPE
  ,P_VAL_CARGO            OUT GE_MOVIMIENTOS.VAL_TASA%TYPE
  ,P_COD_TRA_IMPUESTO     OUT GE_MOVIMIENTOS.COD_TRANSACCION%TYPE
  ,P_COD_TAS_IMPUESTO     OUT GE_MOVIMIENTOS.COD_TASA%TYPE
  ,P_VAL_TAS_IMPUESTO     OUT GE_MOVIMIENTOS.VAL_TASA%TYPE
  ,P_VAL_IMPUESTO         OUT GE_MOVIMIENTOS.VAL_TASA%TYPE
   )
   is
   v_can_ope_his    number;
   v_can_ope_dia    number;
   v_can_ext_permitidas        number;
   v_fec_inicial    ge_calendarios.fec_actual%type;
   v_fcdehoy        ge_calendarios.fec_actual%type;
   --Datos de la cuenta
   v_cod_modulo     ge_cuentas.cod_modulo%type;
   v_cod_modalidad  ge_cuentas.cod_modalidad%type;
   v_cod_moneda     ge_cuentas.cod_moneda%type;
   v_cod_oficina    ge_cuentas.cod_oficina%type;
   --v_monloc         ba_monedas.cod_moneda%type;
   v_fec_apertura   ge_calendarios.fec_actual%type;
   --
   v_cod_bco_entidad number(5) := fug_obt_cod_banco;
   v_cod_bco_fusion  ge_bancos.cod_banco%type := fug_obt_cod_ban_fusion; 
   --
   v_cod_tas_limite ge_mov_sin_costo.cod_tas_limite%type;
   v_redondeo       number;
   ---
   v_cod_tas_cargo  GE_MOVIMIENTOS.COD_TASA%TYPE;
   v_fec_vigencia   ge_tas_rangos.fec_vigencia%type;
   v_tip_valor      ge_tasas.tip_valor%type;
   v_tipo           ge_tasas.tipo%type;
   v_val_base       number(18,2);
   ---
   v_val_cargo    ge_movimientos.val_tasa%type;
   v_val_tas_imp  ge_movimientos.val_tasa%type;
   v_val_impuesto ge_movimientos.val_tasa%type;
begin
  v_fcdehoy     := trunc(last_day((add_months(pag_cal.fu_obt_fec_actual(3),-1)))-1);--pag_cal.fu_obt_fec_actual(3);
  v_fec_inicial := to_date('01/'||to_char(last_day((add_months(pag_cal.fu_obt_fec_actual(3),-1))),'MM/YYYY'),'DD/MM/YYYY');--to_date('01/'||to_char(v_fcdehoy,'MM/YYYY'),'DD/MM/YYYY');
  --v_monloc      := pag_gen.fu_obt_mon_local;

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
          from cc_movimientos_his
         where nro_cuenta = p_nro_cuenta
           and fecha between v_fec_inicial and v_fcdehoy
           and estado = 'N'
           and reversado = 'N'
           and cc_movimientos_his.cod_transaccion = (case WHEN p_cod_gru_transaccion = 53 THEN  389
                                                  WHEN p_cod_gru_transaccion = 54 THEN 389
                                                  ELSE 503 END)
                    and ((p_cod_gru_transaccion in(53,54) and nvl(cc_movimientos_his.monto,0)= 0)
                      or(cc_movimientos_his.monto > 0))
           and (nvl(cod_banco,v_cod_bco_entidad) = v_cod_bco_entidad
             or nro_documento2 /* nro_atm*/ IN (select g.cod_atm
                                              from cj_atm_entidades g
                                             where g.estado = 'A')
             or nvl(cod_banco,v_cod_bco_fusion) = v_cod_bco_fusion)
           and (cod_mod_padre, cod_mad_padre, cod_tra_padre) in (select cod_modulo, cod_modalidad, cod_transaccion
                                                                   from ge_gru_transacciones_det x
                                                                  where x.cod_gru_transaccion = p_cod_gru_transaccion);

      elsif v_cod_modulo = 3 then
        select count(1)
          into v_can_ope_his
          from ah_movimientos_his
         where nro_cuenta = p_nro_cuenta
           and fecha between v_fec_inicial and v_fcdehoy
           and estado = 'N'
           and reversado = 'N'
           and ah_movimientos_his.cod_transaccion = (case WHEN p_cod_gru_transaccion = 53 THEN  389
                                                  WHEN p_cod_gru_transaccion = 54 THEN 389
                                                  ELSE 503 END)
                    and ((p_cod_gru_transaccion in(53,54) and nvl(ah_movimientos_his.monto,0)= 0)
                      or(ah_movimientos_his.monto > 0))
           and (nvl(cod_banco,v_cod_bco_entidad) = v_cod_bco_entidad
             or nro_documento2 /* nro_atm*/ IN (select g.cod_atm
                                              from cj_atm_entidades g
                                             where g.estado = 'A')
             or nvl(cod_banco,v_cod_bco_fusion) = v_cod_bco_fusion)
           and (cod_mod_padre, cod_mad_padre, cod_tra_padre) in (select cod_modulo, cod_modalidad, cod_transaccion
                                                                   from ge_gru_transacciones_det x
                                                                  where x.cod_gru_transaccion = p_cod_gru_transaccion);
      else
        select count(1)
          into v_can_ope_his
          from gv_movimientos
         where nro_cuenta = p_nro_cuenta
           and fecha between v_fec_inicial and v_fcdehoy
           and estado = 'N'
           and reversado = 'N'
           and gv_movimientos.cod_transaccion = (case WHEN p_cod_gru_transaccion = 53 THEN  389
                                                  WHEN p_cod_gru_transaccion = 54 THEN 389
                                                  ELSE 503 END)
                    and ((p_cod_gru_transaccion in(53,54) and nvl(gv_movimientos.monto,0)= 0)
                      or(gv_movimientos.monto > 0))
           and (nvl(cod_banco,v_cod_bco_entidad) = v_cod_bco_entidad
             or nro_documento2 /* nro_atm*/ IN (select g.cod_atm
                                              from cj_atm_entidades g
                                             where g.estado = 'A')
             or nvl(cod_banco,v_cod_bco_fusion) = v_cod_bco_fusion)
           and (cod_mod_padre, cod_mad_padre, cod_tra_padre) in (select cod_modulo, cod_modalidad, cod_transaccion
                                                                   from ge_gru_transacciones_det x
                                                                  where x.cod_gru_transaccion = p_cod_gru_transaccion);

      End if;
      if v_cod_modulo in (3,4) then
          select count(1)
            into v_can_ope_dia
            from ge_movimientos_ant
           where nro_cuenta = p_nro_cuenta
             and estado = 'N'
             and reversado = 'N'
             and ge_movimientos_ant.cod_transaccion = (case WHEN p_cod_gru_transaccion = 53 THEN  389
                                                  WHEN p_cod_gru_transaccion = 54 THEN 389
                                                  ELSE 503 END)
                    and ((p_cod_gru_transaccion in(53,54) and nvl(ge_movimientos_ant.monto,0)= 0)
                      or(ge_movimientos_ant.monto > 0))

             and (nvl(cod_banco,v_cod_bco_entidad) = v_cod_bco_entidad
             or nro_documento2 /* nro_atm*/ IN (select g.cod_atm
                                              from cj_atm_entidades g
                                             where g.estado = 'A')
             or nvl(cod_banco,v_cod_bco_fusion) = v_cod_bco_fusion)
             and (cod_mod_padre, cod_mad_padre, cod_tra_padre) in (select cod_modulo, cod_modalidad, cod_transaccion
                                                                     from ge_gru_transacciones_det x
                                                                    where x.cod_gru_transaccion = p_cod_gru_transaccion);
      end if;

      --Obtener la cantidad de uso de otros atms
      v_can_ext_permitidas := fug_obt_can_permitidas(p_nro_cuenta, v_cod_tas_limite, P_PAR_DINAMICO);
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
                        p_cod_transaccion,--Transaccion para el cobro de cargos
                        p_cod_tas_cargo,
                        p_val_tas_cargo,
                        p_val_cargo,
                        p_cod_tra_impuesto,
                        p_cod_tas_impuesto,
                        p_val_tas_impuesto,
                        p_val_impuesto);
         v_can_ope_dia := nvl(v_can_ope_dia,0) - nvl(v_can_ext_permitidas,0);
         -- se calcula el valor por la cantidad
         -- RI : 06/01/10 : Volver a sumar el cargo y el iva para multiplicar por la cantidad y despues volver a calcular el iva
         p_val_cargo := (p_val_cargo + p_val_impuesto) * v_can_ope_dia;
         p_val_impuesto := round(nvl(p_val_cargo,0)*
                                    nvl(p_val_tas_impuesto,0)/(100+p_val_tas_impuesto),v_redondeo);
         p_val_Cargo    := round(p_val_Cargo - p_val_impuesto,v_redondeo);
         -- PCCEXECT-123
         --p_val_cargo := p_val_cargo * v_can_ope_dia;
         --p_val_impuesto := p_val_impuesto * v_can_ope_dia;
         --if  v_cod_moneda <> v_monloc then
         --   p_val_Cargo := round(p_val_Cargo,v_redondeo);
         --   p_val_impuesto := round(p_val_impuesto,v_redondeo);
         --end if;
         /*
         || PCC-Exoneración y Extorno de Comisiones y Tasas
         */
         -- veo si la cuenta tiene transaccion prohibida
         v_cod_tas_cargo := p_cod_tas_cargo;
         v_val_base      := 0;
         -- busco el valor de la tasa
         begin
             v_val_cargo := fug_obt_val_tasa(v_cod_modulo,
                                             v_cod_modalidad,
                                             v_cod_oficina,
                                             null,
                                             v_cod_moneda,
                                             0, 'N', NULL,
                                             p_cod_transaccion,
                                             v_fcdehoy);
         exception
            when others then
               raise_application_error(-20000,'Al Obt.Val.Tasa:'||sqlerrm);
         end;
         begin
            v_val_tas_imp := fug_obt_val_tasa(v_cod_modulo,
                                              v_cod_modalidad,
                                              v_cod_oficina,
                                              null,
                                              v_cod_moneda,
                                              0, 'N', NULL,
                                              p_cod_tra_impuesto,
                                              v_fcdehoy);
         exception
            when others then
               raise_application_error(-20000,'Al Obt.Val.Tasa:'||sqlerrm);
         end;
         v_val_impuesto := (round(nvl(v_val_cargo, 0) * nvl(v_val_tas_imp, 0)
                           / (100 + v_val_tas_imp), v_redondeo));         
         v_val_cargo    := nvl(v_can_ope_dia, 0) * nvl(v_val_cargo, 0);
         v_val_impuesto := nvl(v_can_ope_dia, 0) * nvl(v_val_impuesto, 0);
         if pag_cta.fu_ver_tra_prohibida(p_nro_cuenta,
                                         p_cod_transaccion,
                                         v_cod_modulo,
                                         v_cod_modalidad) = 'S' or
            nvl(v_val_cargo, 0) <> nvl(p_val_cargo, 0) or
            nvl(v_val_cargo, 0) = 0 then
            prg_ins_exoneracion(p_cod_transaccion, v_cod_modulo, v_cod_modalidad,
                                v_cod_moneda, p_nro_cuenta, null, v_cod_tas_cargo,
                                (nvl(v_val_cargo, 0) - nvl(p_val_cargo, 0)),
                               v_val_cargo, null,
                              (nvl(v_val_cargo, 0) - nvl(p_val_cargo, 0)));
         end if;
         if pag_cta.fu_ver_tra_prohibida(p_nro_cuenta,
                                         p_cod_tra_impuesto,
                                         v_cod_modulo,
                                         v_cod_modalidad) = 'S' or
            nvl(v_val_impuesto, 0) <> nvl(p_val_impuesto, 0) or
            nvl(v_val_impuesto, 0) = 0 then
            prg_ins_exoneracion(p_cod_tra_impuesto, v_cod_modulo, v_cod_modalidad,
                                v_cod_moneda, p_nro_cuenta, null, v_cod_tas_cargo,
                                (nvl(v_val_impuesto, 0) - nvl(p_val_impuesto, 0)),
                                 v_val_impuesto, null,
                                (nvl(v_val_impuesto, 0) - nvl(p_val_impuesto, 0)));
         end if;
         ---
      end if;
   end if;
exception
  when others then
    IF sqlcode <= -20000 THEN
      raise;
    else
      raise_application_error(-20000,'En obtener cargos'||' - '||sqlerrm);
    End if;
end prg_obt_car_uso_pro_atm_rep;
/

