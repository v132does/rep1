create or replace function it.fug_obt_ent_pag_sue(p_nro_cuenta in varchar2)
return number is
  Result number;
begin

  select ge.cod_ente 
    into Result
    from ge_entes ge, cc_cta_corrientes ccc
   where ge.cod_ente = ccc.cod_ente 
     and ccc.nro_cuenta = p_nro_cuenta;
  return(Result);
exception 
when no_data_found then
  begin
     select ge.cod_ente 
       into Result
       from ge_entes ge, ah_cta_vistas acv
      where ge.cod_ente = acv.cod_ente 
        and acv.nro_cuenta = p_nro_cuenta;
    return(Result);
  exception
    when no_data_found then
      return null;
    when others then
      return null;
  end;
end fug_obt_ent_pag_sue;
/

