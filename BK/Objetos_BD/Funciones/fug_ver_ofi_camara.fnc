create or replace function it.FUG_VER_OFI_CAMARA
 (p_cod_oficina in ba_oficinas.cod_oficina%type)
  return boolean is
  v_existe number;
begin
  select count(*)
    into v_existe
   from ba_oficinas a
   where cod_ofi_camara = p_cod_oficina;
  if nvl(v_existe,0) > 0 then
    return true;
  else
    return false;
  end if;
exception
  when others then
     raise_application_error(-20000,'FUG_VER_OFI_CAMARA '||sqlerrm);
end;
/

