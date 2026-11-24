create or replace function it.fug_obt_deuda_cuenta(p_cod_modalidad in number,
                                                p_nro_cuenta    in number)
  return number is
  v_deu_total number;
begin
  if p_cod_modalidad = 5 then
    begin
      select nvl(ct.sal_facturar, 0) + nvl(ct.sal_facturado, 0) +
             nvl(ct.sal_financiado, 0)
        into v_deu_total
        from ta_cta_tarjetas ct
       where ct.nro_cuenta = p_nro_cuenta;
    exception
      when others then
        v_deu_total := 0;
    end;
  else
    v_deu_total := 0;
  end if;
  return v_deu_total;
end;
/

