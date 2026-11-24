create or replace function it.fug_obt_ing_pos_cta_com
 (p_nro_cuenta in varchar2, p_can_dia_mov_his number)
 return number
 is
   v_mto_ingreso ge_movimientos.monto%type;
   v_cod_mon_local ba_monedas.cod_moneda%type := pag_gen.fu_obt_mon_local;
   v_mto_ing_dia  ge_movimientos.monto%type;
   v_fec_actual ge_calendarios.fec_actual%type := pag_cal.FU_OBT_FEC_ACTUAL(1);
begin
  begin
   select sum(decode( a.cod_moneda, v_cod_mon_local, a.monto, a.mto_equ_local))
     into v_mto_ingreso
     from cc_movimientos_his a, cc_cta_corrientes cc, ge_transacciones t, ge_gru_transacciones_det d
    where cc.nro_cuenta = p_nro_cuenta
      and a.fecha >= trunc(v_fec_actual-p_can_dia_mov_his)
      and cc.nro_cuenta = a.nro_cuenta
      and d.cod_gru_transaccion = 90
      and a.cod_mod_padre = d.cod_modulo
      and a.cod_mad_padre = d.cod_modalidad
      and a.cod_tra_padre = d.cod_transaccion
      and a.cod_modulo = t.cod_modulo
      and a.cod_modalidad = t.cod_modalidad
      and a.cod_transaccion = t.cod_transaccion
      and t.tipo = 'C'
      and a.reversado = 'N'
      and cc.estado = 'N';
  exception
    when others then
       v_mto_ingreso := 0;
  end;

  begin
   select sum(decode( a.cod_moneda, v_cod_mon_local, a.monto, a.mto_equ_local))
     into v_mto_ing_dia
     from ge_movimientos a, cc_cta_corrientes cc, ge_transacciones t, ge_gru_transacciones_det d
    where a.fecha = v_fec_actual
      and cc.nro_cuenta = p_nro_cuenta
      and cc.nro_cuenta = a.nro_cuenta
      and d.cod_gru_transaccion = 90
      and a.cod_mod_padre = d.cod_modulo
      and a.cod_mad_padre = d.cod_modalidad
      and a.cod_tra_padre = d.cod_transaccion
      and a.cod_modulo = t.cod_modulo
      and a.cod_modalidad = t.cod_modalidad
      and a.cod_transaccion = t.cod_transaccion
      and t.tipo = 'C'
      and a.reversado = 'N'
      and cc.estado = 'N';
  exception
    when others then
       v_mto_ing_dia := 0;
  end;

  return nvl(v_mto_ingreso, 0) + nvl(v_mto_ing_dia,0);

exception
   when others then
     return 0;
end fug_obt_ing_pos_cta_com;
/

