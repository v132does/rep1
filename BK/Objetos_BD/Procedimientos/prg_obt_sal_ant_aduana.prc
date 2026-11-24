create or replace procedure it.prg_obt_sal_ant_aduana(p_nro_cuenta   in varchar2,
                                                      p_fec_proceso  in date,
                                                      p_sal_actual   out number,
                                                      p_sal_anterior out number) is 
 /**** Calculo de saldo anterior para Aduana ****/
 v_fecha           ge_calendarios.fec_actual%type;
 v_sal_actual      cc_cta_corrientes.sal_total%type;
 v_sal_anterior    cc_cta_corrientes.sal_total%type;
 v_tip_transaccion ge_transacciones.tipo%type;
 v_nro_cuenta      ge_cuentas.nro_cuenta%type;
 v_fec_proceso     ge_movimientos.fec_valor%type;
 /** 
  Cursor para obtener el saldo actual a enviar para aduana 
 **/
 cursor cc_mov_sal_actual is
  select a.cod_transaccion, a.cod_modulo, a.cod_modalidad, nvl(a.mto_equ_local, a.monto) monto
    from ge_movimientos a 
   where a.nro_cuenta = v_nro_cuenta
     and a.reversado = 'N'
     and trunc(a.fec_insercion) between v_fec_proceso and v_fecha
  union all
  select a.cod_transaccion, a.cod_modulo, a.cod_modalidad, nvl(a.mto_equ_local, a.monto) monto
    from cc_movimientos_his a 
   where a.nro_cuenta = v_nro_cuenta
     and a.reversado = 'N'
     and trunc(a.fec_insercion) between v_fec_proceso and v_fecha 
   union all
  select a.cod_transaccion, a.cod_modulo, a.cod_modalidad, nvl(a.mto_equ_local, a.monto) monto
    from ah_movimientos_his a 
   where a.nro_cuenta = v_nro_cuenta
     and a.reversado = 'N'
     and trunc(a.fec_insercion) between v_fec_proceso and v_fecha;
 /** 
  Cursor para obtener el saldo anterior a enviar para aduana
 **/
 cursor cc_mov_sal_anterior is
  /** con cc_movimientos_his **/
  select a.cod_transaccion, a.cod_modulo, a.cod_modalidad, nvl(a.mto_equ_local, a.monto) monto
    from cc_movimientos_his a 
   where a.nro_cuenta = v_nro_cuenta
     and a.reversado = 'N'
     and trunc(a.fec_insercion) = v_fec_proceso
   union all
  /** con ah_movimientos_his **/
  select a.cod_transaccion, a.cod_modulo, a.cod_modalidad, nvl(a.mto_equ_local, a.monto) monto
    from ah_movimientos_his a 
   where a.nro_cuenta = v_nro_cuenta
     and a.reversado = 'N'
     and trunc(a.fec_insercion) = v_fec_proceso
   union all
  /** ge_movimientos **/
  select a.cod_transaccion, a.cod_modulo, a.cod_modalidad, nvl(a.mto_equ_local, a.monto) monto
    from ge_movimientos a 
   where a.nro_cuenta = v_nro_cuenta 
     and a.reversado = 'N'
     and trunc(a.fec_insercion) = v_fec_proceso;

begin 
 /** << PROGRAMA PRINCIPAL >> **/
 v_nro_cuenta := p_nro_cuenta;
 v_fec_proceso := nvl(to_date(p_fec_proceso,'dd/mm/yyyy'), trunc(sysdate))+1;
 if v_nro_cuenta is not null then 
  begin /** Obtenemos el saldo actual de la cuenta **/
   select c.sal_total - nvl(c.sal_retenido,0) - nvl(c.sal_bloqueado,0) - nvl(c.mto_deb_pendientes,0) + nvl(c.mto_cre_pendientes,0)--sal_disponible
     into v_sal_actual
     from cc_cta_corrientes c
    where c.nro_cuenta = v_nro_cuenta;
  exception
   when others then
    v_sal_actual := 0;
  end;
  
  /** asigno la fecha inicial de calculo de saldo actual **/
  v_fecha := trunc(sysdate) ;
  
  /****************************************/ 
   -- Ciclo para obtener el Saldo Actual --
  /****************************************/
  for x in cc_mov_sal_actual loop
   /** obtenemos el tipo de trasaccion D/C **/
   v_tip_transaccion := fug_obt_tra_tip_aduana(x.cod_transaccion, x.cod_modulo, x.cod_modalidad);
   if v_tip_transaccion = 'C' then /** si es credito resta **/
    v_sal_actual := v_sal_actual - x.monto;
   elsif v_tip_transaccion = 'D' then /** si es debito suma **/
    v_sal_actual := v_sal_actual + x.monto;
   end if;
  end loop;
  
  /** resto 1 dia a la fecha inicial para el calculo de saldo anterior **/
  v_fec_proceso := nvl(to_date(p_fec_proceso,'dd/mm/yyyy'), trunc(sysdate));
 
  /*****************************************/
  -- Ciclo para obtener el Saldo Anterior --
  /*****************************************/
  v_sal_anterior := v_sal_actual;
  for x in cc_mov_sal_anterior loop
   /** obtenemos el tipo de trasaccion D/C **/
   v_tip_transaccion := fug_obt_tra_tip_aduana(x.cod_transaccion, x.cod_modulo, x.cod_modalidad);
   if v_tip_transaccion = 'C' then /** si es credito resta **/
    v_sal_anterior := v_sal_anterior - x.monto;
   elsif v_tip_transaccion = 'D' then /** si es debito suma **/
    v_sal_anterior := v_sal_anterior + x.monto;
   end if;
  end loop;
 end if;
 /** parametros de retorno **/
 p_sal_actual   := nvl(v_sal_actual,0);
 p_sal_anterior := nvl(v_sal_anterior,0);
 
exception
 when others then
  p_sal_actual := 0;
  p_sal_anterior := 0;
end;
/
