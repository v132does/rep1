create or replace function it.fua_obt_tot_dep_cda(p_cod_persona number,p_cod_moneda varchar2) return number is
  capital number;
begin

  select nvl(sum(c.capital),0) into capital
  from ah_cta_certificados c
  left outer join ge_cta_clientes cl on (cl.cod_persona=p_cod_persona and cl.relacion='P')
  where c.nro_cuenta=cl.nro_cuenta
  and c.cod_modalidad=33 and c.est_certificado<>'P' and c.cod_moneda like p_cod_moneda;

  return(capital);

  exception
    when others then
      return null;

end fua_obt_tot_dep_cda;
/

