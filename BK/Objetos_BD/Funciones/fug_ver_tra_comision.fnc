create or replace function it.fug_ver_tra_comision (
       p_cod_modulo        ge_transacciones.cod_modulo%type
      ,p_cod_modalidad     ge_transacciones.cod_modalidad%type
      ,p_cod_transaccion   ge_transacciones.cod_transaccion%type)
return varchar2
is
   v_es_ganancia varchar2(1) := 'N';
begin
   select 'S'
   into   v_es_ganancia
   from   ge_transacciones t
   where  t.cod_modulo = p_cod_modulo
   and    t.cod_modalidad = p_cod_modalidad
   and    t.cod_transaccion = p_cod_transaccion
   and    t.cod_tip_asi_resultado is not null;
   return nvl(v_es_ganancia,'N');
exception
   when no_data_found then
      return 'N';
   when others then
      raise_application_error(-2000,'Error:'||Sqlerrm);
end;
/

