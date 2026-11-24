create or replace function it.fug_obt_sue_net_deducido(p_nro_cuenta in varchar2, p_fecha in date default null) return number is

  --Variables--
  v_cod_mon_local ba_monedas.cod_moneda%type;
  v_fec_actual    date;
  v_fec_calculo   date;
  v_fec_hor_insercion ge_movimientos.fec_insercion%type;
  v_cod_usuario ba_usuarios.cod_usuario%type;
  v_mto_sue_net_loc  ge_movimientos.monto%type;
  v_cod_modalidad ge_modalidades.cod_modalidad%type;
  v_can_minutos   number(2);

  --Cursores--
  cursor c_pag_sueldos_dia is
    select x.fecha, x.hora, x.cod_usuario, x.cod_moneda, x.cod_modalidad, x.fec_insercion, x.monto,
           fub_con_mon_a_moneda(x.cod_moneda, v_cod_mon_local, x.monto, null, p_fecha) mto_mon_loc_cre
      from ge_movimientos x, ge_transacciones y
     where x.fecha = v_fec_calculo
       and x.cod_tra_padre = 303 --Pago de Sueldo--
       and x.cod_transaccion = 602 --Creditos recibidos--
       and x.reversado = 'N'
       and y.cod_transaccion = x.cod_transaccion
       and y.cod_modulo = x.cod_modulo
       and y.cod_modalidad = x.cod_modalidad
       and y.tipo = 'C' --Credito--
       and x.cod_modalidad in (31,41)
       and x.cod_mad_padre not in (455) --Excluido Transferencia SIPAP--
       and x.nro_cuenta = p_nro_cuenta;

  cursor c_pag_sueldos_cte is
    select x.fecha, x.hora, x.cod_usuario, x.cod_moneda, x.cod_modalidad, x.fec_insercion, x.monto,
           fub_con_mon_a_moneda(x.cod_moneda, v_cod_mon_local, x.monto, null, p_fecha) mto_mon_loc_cre
      from cc_movimientos_his x, ge_transacciones y
     where x.fecha = v_fec_calculo
       and x.cod_tra_padre = 303 --Pago de Sueldo--
       and x.cod_transaccion = 602 --Creditos recibidos--
       and x.reversado = 'N'
       and y.cod_transaccion = x.cod_transaccion
       and y.cod_modulo = x.cod_modulo
       and y.cod_modalidad = x.cod_modalidad
       and y.tipo = 'C' --Credito--
       and x.cod_modalidad = 41
       and x.cod_mad_padre not in (455) --Excluido Transferencia SIPAP--
       and x.nro_cuenta = p_nro_cuenta;

   cursor c_pag_sueldos_vis is
    select x.fecha, x.hora, x.cod_usuario, x.cod_moneda, x.cod_modalidad, x.fec_insercion, x.monto,
           fub_con_mon_a_moneda(x.cod_moneda, v_cod_mon_local, x.monto, null, p_fecha) mto_mon_loc_cre
      from ah_movimientos_his x, ge_transacciones y
     where x.fecha = v_fec_calculo
       and x.cod_tra_padre = 303 --Pago de Sueldo--
       and x.cod_transaccion = 602 --Creditos recibidos--
       and x.reversado = 'N'
       and y.cod_transaccion = x.cod_transaccion
       and y.cod_modulo = x.cod_modulo
       and y.cod_modalidad = x.cod_modalidad
       and y.tipo = 'C' --Credito--
       and x.cod_modalidad = 31
       and x.cod_mad_padre not in (455) --Excluido Transferencia SIPAP--
       and x.nro_cuenta = p_nro_cuenta;


  cursor c_mov_sueldos_dia is
    select x.fecha, x.hora, x.cod_usuario, x.cod_moneda, x.fec_insercion, x.monto,
           fub_con_mon_a_moneda(x.cod_moneda, v_cod_mon_local, x.monto, null, p_fecha) mto_mon_loc_deb
      from ge_movimientos x, ge_transacciones y
     where x.fecha = v_fec_calculo
       and x.reversado = 'N'
       and y.cod_transaccion = x.cod_transaccion
       and y.cod_modulo = x.cod_modulo
       and y.cod_modalidad = x.cod_modalidad
       and y.tipo = 'D' --Debito--
       and x.fec_insercion between v_fec_hor_insercion and (v_fec_hor_insercion + (v_can_minutos/24*60)) --2 min adelante--
       and x.cod_usuario = v_cod_usuario
       and x.cod_mad_padre not in (455) --Excluido Transferencia SIPAP--
       and x.nro_cuenta = p_nro_cuenta
       --Filtros relacionados a Procesos Aut. de Debitos--
       --Debito Aut. de TC--
       and ((x.cod_tra_padre = 186 and x.cod_transaccion = 503) or
       --Debito Aut. de Prestamos--
            (x.cod_tra_padre = 364 and x.cod_transaccion = 503) or
       --Debito Aut. de Deb. Pendientes--
            (x.cod_tra_padre = x.cod_transaccion));

  cursor c_mov_sueldos_cte is
    select x.fecha, x.hora, x.cod_usuario, x.cod_moneda, x.fec_insercion, x.monto,
           fub_con_mon_a_moneda(x.cod_moneda, v_cod_mon_local, x.monto, null, p_fecha) mto_mon_loc_deb
      from cc_movimientos_his x, ge_transacciones y
     where x.fecha = v_fec_calculo
       and x.reversado = 'N'
       and y.cod_transaccion = x.cod_transaccion
       and y.cod_modulo = x.cod_modulo
       and y.cod_modalidad = x.cod_modalidad
       and y.tipo = 'D' --Debito--
       and x.fec_insercion between v_fec_hor_insercion and (v_fec_hor_insercion + (v_can_minutos/24*60)) --2 min adelante--
       and x.cod_usuario = v_cod_usuario
       and x.cod_mad_padre not in (455) --Excluido Transferencia SIPAP--
       and x.nro_cuenta = p_nro_cuenta
       --Filtros relacionados a Procesos Aut. de Debitos--
       --Debito Aut. de TC--
       and ((x.cod_tra_padre = 186 and x.cod_transaccion = 503) or
       --Debito Aut. de Prestamos--
            (x.cod_tra_padre = 364 and x.cod_transaccion = 503) or
       --Debito Aut. de Deb. Pendientes--
            (x.cod_tra_padre = x.cod_transaccion));

  cursor c_mov_sueldos_vis is
    select x.fecha, x.hora, x.cod_usuario, x.cod_moneda, x.fec_insercion, x.monto,
           fub_con_mon_a_moneda(x.cod_moneda, v_cod_mon_local, x.monto, null, p_fecha) mto_mon_loc_deb
      from ah_movimientos_his x, ge_transacciones y
     where x.fecha = v_fec_calculo
       and x.reversado = 'N'
       and y.cod_transaccion = x.cod_transaccion
       and y.cod_modulo = x.cod_modulo
       and y.cod_modalidad = x.cod_modalidad
       and y.tipo = 'D' --Debito--
       and x.fec_insercion between v_fec_hor_insercion and (v_fec_hor_insercion + (v_can_minutos/24*60)) --2 min adelante--
       and x.cod_usuario = v_cod_usuario
       and x.cod_mad_padre not in (455) --Excluido Transferencia SIPAP--
       and x.nro_cuenta = p_nro_cuenta
       --Filtros relacionados a Procesos Aut. de Debitos--
       --Debito Aut. de TC--
       and ((x.cod_tra_padre = 186 and x.cod_transaccion = 503) or
       --Debito Aut. de Prestamos--
            (x.cod_tra_padre = 364 and x.cod_transaccion = 503) or
       --Debito Aut. de Deb. Pendientes--
            (x.cod_tra_padre = x.cod_transaccion));

begin
  --Carga de Variables--
  v_cod_mon_local := pag_gen.fu_obt_mon_local;
  v_fec_actual    := pag_cal.fu_obt_fec_actual(1);
  v_can_minutos   := 2;
  if p_fecha is null then
     v_fec_calculo := v_fec_actual;
  else
     v_fec_calculo := p_fecha;
  end if;

  if v_fec_calculo = v_fec_actual then --Movimientos del Dia--
     v_mto_sue_net_loc := 0;
     for sue in c_pag_sueldos_dia loop
         v_fec_hor_insercion := sue.fec_insercion;
         v_cod_usuario := sue.cod_usuario;
         v_mto_sue_net_loc := nvl(v_mto_sue_net_loc,0) + nvl(sue.mto_mon_loc_cre,0);
         for mov in c_mov_sueldos_dia loop
             v_mto_sue_net_loc := nvl(v_mto_sue_net_loc,0) - nvl(mov.mto_mon_loc_deb,0);
         end loop;
     end loop;
  else
     --Obtener modalidad de la cuenta--
     select a.cod_modalidad
       into v_cod_modalidad
       from ge_cuentas a
      where a.nro_cuenta = p_nro_cuenta;
     v_mto_sue_net_loc := 0;
     if v_cod_modalidad = 41 then
        for sue in c_pag_sueldos_cte loop
            v_fec_hor_insercion := sue.fec_insercion;
            v_cod_usuario := sue.cod_usuario;
            v_mto_sue_net_loc := nvl(v_mto_sue_net_loc,0) + nvl(sue.mto_mon_loc_cre,0);
            for mov in c_mov_sueldos_cte loop
                v_mto_sue_net_loc := nvl(v_mto_sue_net_loc,0) - nvl(mov.mto_mon_loc_deb,0);
            end loop;
        end loop;
     else
        for sue in c_pag_sueldos_vis loop
            v_fec_hor_insercion := sue.fec_insercion;
            v_cod_usuario := sue.cod_usuario;
            v_mto_sue_net_loc := nvl(v_mto_sue_net_loc,0) + nvl(sue.mto_mon_loc_cre,0);
            for mov in c_mov_sueldos_vis loop
                v_mto_sue_net_loc := nvl(v_mto_sue_net_loc,0) - nvl(mov.mto_mon_loc_deb,0);
            end loop;
        end loop;
     end if;
  end if;
  return v_mto_sue_net_loc;
end;
/

