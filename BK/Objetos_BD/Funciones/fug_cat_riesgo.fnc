create or replace function it.fug_cat_riesgo(
  p_cat_riesgo ge_clientes.cat_riesgo%type)
return Char is
  v_riesgo varchar2(4000);
begin
  ---
  v_riesgo := fue_obt_des_refcodes('CAT_RIESGO',to_char(p_cat_riesgo));
  ---
  if p_cat_riesgo is null then
     return 'Sin categoría';
  elsif p_cat_riesgo in (1,2,3,5) then
     return p_cat_riesgo||' '||'Riesgo '||v_riesgo;
  else
     return p_cat_riesgo||' '||v_riesgo;
  end if;
  ---
  exception
     when no_data_found then
        return null;
end;
/

