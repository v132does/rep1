create or replace function it.FUG_OBT_OFI_CAMARA
 (p_cod_oficina in ba_oficinas.cod_oficina%type) 
  return number is
  v_ofi_camara number;
begin
  select cod_ofi_camara
    into v_ofi_camara
   from ba_oficinas a 
   where cod_oficina = p_cod_oficina;
  if v_ofi_camara is not null then
    return v_ofi_camara;
  else 
    raise_application_error(-20001,'Oficina de Cámara no definida para la oficina '||p_cod_oficina);
  end if;
exception
  when others then
     if sqlcode <= -20000 then
       raise;
     else
       raise_application_error(-20000,'FUG_VER_OFI_CAMARA '||sqlerrm);
     end if;
end;
/

