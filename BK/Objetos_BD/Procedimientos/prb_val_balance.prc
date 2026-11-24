create or replace procedure it.PRB_VAL_BALANCE is
   --- Valida los saldos de balances
   --- Cursor de cuentas con naturaleza con problem
   --- Solo valida saldos en ML
   cursor c_consolidado is
     select c.cod_oficina, c.cod_rubro, r.naturaleza,
            nvl(c.sal_mon_loc_ant,0)+nvl(c.deb_mon_local,0)-nvl(c.cre_mon_local,0) saldo
       from cb_rubros r, cb_sal_oficinas c
      where c.cod_rubro = r.cod_rubro
        and ((nvl(c.sal_mon_loc_ant,0)+nvl(c.deb_mon_local,0)-nvl(c.cre_mon_local,0) > 0
            and nvl(r.naturaleza,'+') <> '+')
          or (nvl(c.sal_mon_loc_ant,0)+nvl(c.deb_mon_local,0)-nvl(c.cre_mon_local,0) < 0
            and nvl(r.naturaleza,'+') <> '-'))
      order by c.cod_oficina, c.cod_rubro;

   cursor c_interes is
   select c.cod_oficina, substr(c.cod_rubro,1,8) cod_rubro, r.tipo,
          nvl(sum(nvl(c.sal_mon_loc_ant,0)+nvl(c.deb_mon_local,0)-nvl(c.cre_mon_local,0)),0) saldo
     from cb_sal_oficinas c, cb_rubros r
    where r.tipo in (1,2)
      and c.cod_rubro = r.cod_rubro
      and substr(r.cod_rubro,4,1) = '8'
      and r.imputable = 'S'
    group by c.cod_oficina, substr(c.cod_rubro,1,8), r.tipo;
   --- Validar 51 y 52
   v_sal_ml_51   cb_sal_consolidados.sal_mon_loc_ant%type;
   v_sal_equ_51  cb_sal_consolidados.sal_equ_loc_ant%type;
   v_sal_me_51   cb_sal_consolidados.sal_mon_rub_ant%type;
   v_sal_ml_52   cb_sal_consolidados.sal_mon_loc_ant%type;
   v_sal_equ_52  cb_sal_consolidados.sal_equ_loc_ant%type;
   v_sal_me_52   cb_sal_consolidados.sal_mon_rub_ant%type;
   v_sal_valor1  cb_sal_consolidados.sal_mon_loc_ant%type;
   v_sal_valor2  cb_sal_consolidados.sal_mon_loc_ant%type;
   v_sal_valor3  cb_sal_consolidados.sal_mon_loc_ant%type;
   ---
   v_fec_actual  ge_calendarios.fec_actual%type;
   v_linea       number(10) := 0;
begin
   pag_cal.PR_OBT_DAT_CALENDAR(2);
   v_fec_actual := pag_cal.G_FEC_ACTUAL;
   --- Validar naturaleza de la cuenta
   delete cb_validaciones
   where fecha = v_fec_actual
   and nro_asiento = -1;
   v_linea := 0;
   for reg in c_consolidado loop
      v_linea := v_linea + 1;
      insert into cb_validaciones
         (fecha, cod_oficina, nro_asiento, nro_linea, error)
      values
         (v_fec_actual, reg.cod_oficina, -1, v_linea, 'Cuenta '||reg.cod_rubro||' con signo '||reg.naturaleza||
          ' no corresponde el saldo de '||reg.saldo);
   end loop;
   --- Validar saldos de Contingencias
   -- Recuperar 51
   begin
      select nvl(a.sal_mon_loc_ant,0)+nvl(a.deb_mon_local,0)-nvl(a.cre_mon_local,0) saldo_ml,
             nvl(a.sal_equ_loc_ant,0)+nvl(a.deb_equ_local,0)-nvl(a.cre_equ_local,0) saldo_equ,
             nvl(a.sal_mon_rub_ant,0)+nvl(a.deb_mon_rubro,0)-nvl(a.cre_mon_rubro,0) saldo_me
        into v_sal_ml_51, v_sal_equ_51, v_sal_me_51
        from cb_sal_consolidados a
       where cod_rubro = '51000000000';
      exception
         when others then
            v_sal_ml_51  := 0;
            v_sal_equ_51 := 0;
            v_sal_me_51  := 0;
   end;
   -- Recuperar 52
   begin
      select nvl(a.sal_mon_loc_ant,0)+nvl(a.deb_mon_local,0)-nvl(a.cre_mon_local,0) saldo_ml,
             nvl(a.sal_equ_loc_ant,0)+nvl(a.deb_equ_local,0)-nvl(a.cre_equ_local,0) saldo_equ,
             nvl(a.sal_mon_rub_ant,0)+nvl(a.deb_mon_rubro,0)-nvl(a.cre_mon_rubro,0) saldo_me
        into v_sal_ml_52, v_sal_equ_52, v_sal_me_52
        from cb_sal_consolidados a
       where cod_rubro = '52000000000';
      exception
         when others then
            v_sal_ml_52  := 0;
            v_sal_equ_52 := 0;
            v_sal_me_52  := 0;
   end;
   -- validacion
   if v_sal_ml_51 <> v_sal_ml_52 then
      v_linea := v_linea + 1;
      insert into cb_validaciones
         (fecha, cod_oficina, nro_asiento, nro_linea, error)
      values
         (v_fec_actual, 1, -1, v_linea, 'Saldo ML no coincide 51 y 52');
   end if;
   if v_sal_equ_51 <> v_sal_equ_52 then
      v_linea := v_linea + 1;
      insert into cb_validaciones
         (fecha, cod_oficina, nro_asiento, nro_linea, error)
      values
         (v_fec_actual, 1, -1, v_linea, 'Saldo Equivalente no coincide 51 y 52');
   end if;
   if v_sal_me_51 <> v_sal_me_52 then
      v_linea := v_linea + 1;
      insert into cb_validaciones
         (fecha, cod_oficina, nro_asiento, nro_linea, error)
      values
         (v_fec_actual, 1, -1, v_linea, 'Saldo ME no coincide 51 y 52');
   end if;
   --- Validar promedios
   begin
      select sum(nvl(tot_acu_mon_local,0)/nvl(can_dia_acumulado,1)) saldo_ml,
             sum(nvl(a.tot_acu_equ_local,0)/nvl(can_dia_acumulado,1)) saldo_equ,
             sum(nvl(a.tot_acu_mon_fuerte,0)/nvl(can_dia_acumulado,1)) saldo_me
        into v_sal_ml_51, v_sal_equ_51, v_sal_me_51
        from cb_sal_promedios a
       where cod_rubro = '51000000000';
      exception
         when others then
            v_sal_ml_51  := 0;
            v_sal_equ_51 := 0;
            v_sal_me_51  := 0;
   end;
   -- Recuperar 52
   begin
      select sum(nvl(tot_acu_mon_local,0)/nvl(can_dia_acumulado,1)) saldo_ml,
             sum(nvl(a.tot_acu_equ_local,0)/nvl(can_dia_acumulado,1)) saldo_equ,
             sum(nvl(a.tot_acu_mon_fuerte,0)/nvl(can_dia_acumulado,1)) saldo_me
        into v_sal_ml_52, v_sal_equ_52, v_sal_me_52
        from cb_sal_promedios a
       where cod_rubro = '52000000000';
      exception
         when others then
            v_sal_ml_52  := 0;
            v_sal_equ_52 := 0;
            v_sal_me_52  := 0;
   end;
   -- validacion
   if v_sal_ml_51 <> v_sal_ml_52 then
      v_linea := v_linea + 1;
      insert into cb_validaciones
         (fecha, cod_oficina, nro_asiento, nro_linea, error)
      values
         (v_fec_actual, 1, -1, v_linea, 'Saldo Promedio ML no coincide 51 y 52');
   end if;
   if v_sal_equ_51 <> v_sal_equ_52 then
      v_linea := v_linea + 1;
      insert into cb_validaciones
         (fecha, cod_oficina, nro_asiento, nro_linea, error)
      values
         (v_fec_actual, 1, -1, v_linea, 'Saldo Promedio Equivalente no coincide 51 y 52');
   end if;
   if v_sal_me_51 <> v_sal_me_52 then
      v_linea := v_linea + 1;
      insert into cb_validaciones
         (fecha, cod_oficina, nro_asiento, nro_linea, error)
      values
         (v_fec_actual, 1, -1, v_linea, 'Saldo Promedio ME no coincide 51 y 52');
   end if;
   --- Validar Activo - Pasivo <> Patrimonio
   select nvl(c.sal_mon_loc_ant,0)+nvl(c.deb_mon_local,0)-nvl(c.cre_mon_local,0) saldo
     into v_sal_valor1
     from cb_sal_consolidados c
    where cod_rubro = '100000000000000'; -- Activo
   select nvl(c.sal_mon_loc_ant,0)+nvl(c.deb_mon_local,0)-nvl(c.cre_mon_local,0) saldo
     into v_sal_valor2
     from cb_sal_consolidados c
    where cod_rubro = '200000000000000'; -- Pasivo
   select nvl(c.sal_mon_loc_ant,0)+nvl(c.deb_mon_local,0)-nvl(c.cre_mon_local,0) saldo
     into v_sal_valor2
     from cb_sal_consolidados c
    where cod_rubro = '300000000000000'; -- Patrimonio
   if v_sal_valor1 - v_sal_valor2 <> v_sal_valor3 then
      v_linea := v_linea + 1;
      insert into cb_validaciones
         (fecha, cod_oficina, nro_asiento, nro_linea, error)
      values
         (v_fec_actual, 1, -1, v_linea, 'Activo - Pasivo <> Patrimonio');
   end if;
   --- Validar Ingresos - Egresos <> Ganancia
   select nvl(c.sal_mon_loc_ant,0)+nvl(c.deb_mon_local,0)-nvl(c.cre_mon_local,0) saldo
     into v_sal_valor1
     from cb_sal_consolidados c
    where cod_rubro = '600000000000000'; -- Ganancia
   select nvl(c.sal_mon_loc_ant,0)+nvl(c.deb_mon_local,0)-nvl(c.cre_mon_local,0) saldo
     into v_sal_valor2
     from cb_sal_consolidados c
    where cod_rubro = '700000000000000'; -- Perdida
   select nvl(c.sal_mon_loc_ant,0)+nvl(c.deb_mon_local,0)-nvl(c.cre_mon_local,0) saldo
     into v_sal_valor2
     from cb_sal_consolidados c
    where cod_rubro = '310600000000000'; -- Resultado
   if v_sal_valor1 - v_sal_valor2 <> v_sal_valor3 then
      v_linea := v_linea + 1;
      insert into cb_validaciones
         (fecha, cod_oficina, nro_asiento, nro_linea, error)
      values
         (v_fec_actual, 1, -1, v_linea, 'Ganancias - Perdidas <> Resultado');
   end if;
   --- Validar Sucursales y Agencias
   select nvl(c.sal_mon_loc_ant,0)+nvl(c.deb_mon_local,0)-nvl(c.cre_mon_local,0) saldo
     into v_sal_valor1
     from cb_sal_consolidados c
    where cod_rubro = '150102570400000'; -- Sucursales y Agencias
   if v_sal_valor1 <> 0 then
      v_linea := v_linea + 1;
      insert into cb_validaciones
         (fecha, cod_oficina, nro_asiento, nro_linea, error)
      values
         (v_fec_actual, 1, -1, v_linea, 'Sucursales y Agencias con saldo');
   end if;
   --- Validar Interes
   for reg in c_interes loop
      if (reg.saldo < 0 and reg.tipo = 1)
      or (reg.saldo > 0 and reg.tipo = 2) then
         v_linea := v_linea + 1;
         insert into cb_validaciones
            (fecha, cod_oficina, nro_asiento, nro_linea, error)
         values
            (v_fec_actual, reg.cod_oficina, -1, v_linea, 'Suma Cuenta '||reg.cod_rubro||' no corresponde signo '||reg.saldo);
      end if;
   end loop;
end PRB_VAL_BALANCE;
/

