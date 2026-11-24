create or replace function it.fug_rel_asi_transaccion
(p_cod_tip_asiento in number,
 p_cod_modulo      in number default null,
 p_cod_modalidad   in number default null,
 p_cod_transaccion in number default null)
return varchar2 is
v_sino varchar2(1) := 'N';
begin
   select 'S'
     into v_sino
     from ge_transacciones 
    where cod_modulo = nvl(p_cod_modulo,cod_modulo)
      and cod_modalidad = nvl(p_cod_modalidad, cod_modalidad)
      and cod_transaccion = nvl(p_cod_transaccion,cod_transaccion)
      and (cod_tip_asiento = p_cod_tip_asiento or cod_tip_asiento2 = p_cod_tip_asiento)
      and rownum = 1;
    return v_sino;  
exception           
   when no_data_found then
      return v_sino;
   when others then
      raise_application_error(-20000, 'Error buscando el tipo de asiento '||sqlerrm);
end;
/

