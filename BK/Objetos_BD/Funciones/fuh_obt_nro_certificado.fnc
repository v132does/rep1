create or replace function it.fuh_obt_nro_certificado(p_nro_cuenta in ah_cta_certificados.nro_cuenta%type)
  return varchar2 is

  v_calc  number := 0;
  v_nro_certificado ah_cta_certificados.nro_certificado%type;

begin

  select count(*)
    into v_calc
    from ah_cta_certificados a
   where a.nro_cuenta = p_nro_cuenta;

  if v_calc > 0 then
  
    select a.nro_certificado
      into v_nro_certificado
      from ah_cta_certificados a
     where a.nro_cuenta = p_nro_cuenta;
  
  else
  
    v_nro_certificado := '';
  
  end if;

  return(v_nro_certificado);
end fuh_obt_nro_certificado;
/

