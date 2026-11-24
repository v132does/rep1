create or replace function it.fug_obt_tra_tip_aduana(p_cod_transaccion  in ge_transacciones.cod_transaccion%type,
                                                      p_cod_modulo      in ge_modalidades.cod_modulo%type,
                                                      p_cod_modalidad   in ge_modalidades.cod_modalidad%type)
  return varchar2 is
  v_tipo ge_transacciones.tipo%type;
  v_cod_transaccion ge_transacciones.cod_transaccion%type;
  v_afecta ge_transacciones.afecta%type;
begin
  
  begin
   select a.tipo, a.cod_transaccion, a.afecta
     into v_tipo, v_cod_transaccion, v_afecta
   from ge_transacciones a
   where a.cod_transaccion = p_cod_transaccion
     and a.cod_modulo = p_cod_modulo
     and a.cod_modalidad = p_cod_modalidad;
   exception
     when others then
       v_tipo := null;
       v_cod_transaccion := null;
       v_afecta := null;
   end;
   
   if v_tipo is not null then
      v_tipo := fug_obt_tra_tipo(v_cod_transaccion, v_tipo, v_afecta);
   end if;
     
   return v_tipo;

exception
  when others then
    return null;
    
end fug_obt_tra_tip_aduana;
/
