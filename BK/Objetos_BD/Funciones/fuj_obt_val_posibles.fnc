create or replace function it.FUJ_OBT_VAL_POSIBLES(
      p_cod_transaccion in varchar2, -- Codigo de transaccion
      p_cod_campo in varchar2)       -- nombre del campo
 return varchar2 is
  -- defino por defecto el modulo y modalidad a utilizar
  v_cod_modulo number(3) := 9;    -- Caja
  v_cod_modalidad number(3) := 91; -- Caja 
  v_resultado varchar2(8000) := '';
begin
  select val_posibles 
    into v_resultado
    from ge_tra_campos
   where cod_modulo = v_cod_modulo
     and cod_modalidad = v_cod_modalidad
     and cod_transaccion = to_number(p_cod_transaccion)
     and cod_campo = p_cod_campo;
  return (v_resultado);   
exception
   when others then
      return ('');
end FUJ_OBT_VAL_POSIBLES;
/

