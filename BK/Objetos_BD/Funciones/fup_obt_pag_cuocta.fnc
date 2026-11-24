create or replace function it.fup_obt_pag_cuocta(p_nro_cuenta in varchar2,
                                              p_nro_cuota  in number)
  return date is
  v_fecha date;
begin
  select d.fec_ult_pago
    into v_fecha
    from pr_cuotas d
   where d.nro_cuenta = p_nro_cuenta
     and d.nro_cuota = p_nro_cuota;
  return v_fecha;
exception
  when others then
    return v_fecha;
end fup_obt_pag_cuocta;
/

