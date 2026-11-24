create or replace function it.fut_obt_nro_cuenta
 (p_cod_modalidad in number,
  p_cod_tip_tarjeta in varchar2,
  p_afinidad        in varchar2)
return varchar2 is
v_sig_nro_cuenta number(15);
v_fila varchar2(300);
begin
   select nvl(sig_nro_cuenta,0), rowid
     into v_sig_nro_cuenta, v_fila
     from ta_tipos a
    where a.cod_modalidad = p_cod_modalidad
      and a.cod_tip_tarjeta = p_cod_tip_tarjeta
      and a.afinidad = p_afinidad;
   -- actualizo
   update ta_tipos
      set sig_nro_cuenta = sig_nro_cuenta + 1
    where rowid = v_fila;
   return v_sig_nro_cuenta;
exception
  when others then
     return 0;
end;
/

