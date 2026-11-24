create or replace function it.FUA_VER_NRO_CERTIFICADO
 (p_cod_moneda in varchar2,
  p_serie in varchar2,
  p_nro_certificado in number)
 return varchar2 is
  Result varchar2(01);
begin
/*  select estado
    into Result
    from in_oso_ocarton
   where serie = p_serie
     and moneda = decode(p_cod_moneda,pag_gen.fu_obt_mon_local,'PYG',p_cod_moneda)
     and numero = p_nro_certificado;
  return(Result);*/
  return 'E';
exception
   when others then
      return ('N');
end FUA_VER_NRO_CERTIFICADO;
/

