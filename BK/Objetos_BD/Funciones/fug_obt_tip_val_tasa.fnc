create or replace function it.fug_obt_tip_val_tasa (p_cod_tasa in number)
return varchar2 is
v_retorno varchar2(1);
begin
  select tip_valor
    into v_retorno
    from ge_tasas
   where cod_tasa = p_cod_tasa;
  return v_retorno;
exception
  when others then
     return null;
end;
/

