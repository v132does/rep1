create or replace function it.fug_obt_tip_mov_contable(
      p_cod_modulo in number, p_cod_modalidad in number, p_cod_transaccion in number)
 return varchar2 is
   /* retorna: D-Si la transaccion hace debito contable
               C-Si la transaccion hace credito contable
               A-Ambos
               N=No genera asientos contables*/
v_retorno varchar2(1) := 'N';
v_cod_tip_asiento ge_transacciones.cod_tip_asiento%type;
v_cod_tip_asiento2 ge_transacciones.cod_tip_asiento2%type;
begin
  -- busco el codigo de asiento 1 y 2
   select cod_tip_asiento, cod_tip_asiento2, b.tipo
     into v_cod_tip_asiento, v_cod_tip_asiento2, v_retorno
     from ge_transacciones b
    where b.cod_modulo = p_cod_modulo
      and b.cod_modalidad = p_cod_modalidad
      and b.cod_transaccion = p_cod_transaccion;
  -- ve el tipo del movimiento

  if p_cod_modulo = 4 and p_cod_modalidad != 41 then
    return v_retorno;
  else
    select distinct tip_movimiento
      into v_retorno
      from ge_tip_asientos a
     where cod_tip_asiento in (v_cod_tip_asiento,v_cod_tip_asiento2);
    return v_retorno;
  end if;
exception
  when too_many_rows then
     return 'A'; -- ambos
  when no_data_found then
     return 'N'; -- NO TIENE ASIENTOS
  when  others then
     return null;
end;
/

