create or replace function it.fuh_obt_serie(p_nro_cuenta in ah_cta_certificados.nro_cuenta%type)
  return varchar2 is

  v_calc  number := 0;
  v_serie ah_cta_certificados.serie%type;

begin

  select count(*)
    into v_calc
    from ah_cta_certificados a
   where a.nro_cuenta = p_nro_cuenta;

  if v_calc > 0 then
  
    select a.serie
      into v_serie
      from ah_cta_certificados a
     where a.nro_cuenta = p_nro_cuenta;
  
  else
  
    v_serie := '';
  
  end if;

  return(v_serie);
end fuh_obt_serie;
/

