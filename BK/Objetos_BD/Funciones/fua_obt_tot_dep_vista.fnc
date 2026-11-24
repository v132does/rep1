create or replace function it.fua_obt_tot_dep_vista(p_cod_persona number,p_cod_moneda varchar2) return number is
  saldo_caja_ah number;
  saldo_cta_cte number;
begin

  begin
    select nvl(sum(v.sal_total),0) into saldo_caja_ah
    from ah_cta_vistas v
    left outer join ge_cta_clientes cl on (cl.cod_persona=p_cod_persona and cl.relacion='P')
    where cl.nro_cuenta=v.nro_cuenta and v.cod_moneda like p_cod_moneda and v.sal_total>=0;
  exception
    when others then
      return null;
  end;

  begin
    select nvl(sum(c.sal_total),0) into saldo_cta_cte
    from cc_cta_corrientes c
    left outer join ge_cta_clientes cl on (cl.cod_persona=p_cod_persona and cl.relacion='P')
    where cl.nro_cuenta=c.nro_cuenta and c.cod_moneda like p_cod_moneda and c.sal_total>=0;
  exception
    when others then
      return null;
  end;

  return(saldo_caja_ah+saldo_cta_cte);

end fua_obt_tot_dep_vista;
/

