create or replace function it.fuj_obt_tip_caja (p_nro_caja in varchar2)
return varchar2 is
  v_tipo cj_cajas.tipo%type;
begin
  select tipo
    into v_tipo
    from cj_cajas
   where nro_caja = p_nro_caja;
   --
  return v_tipo;
exception
  when others then return null;
end;
/

