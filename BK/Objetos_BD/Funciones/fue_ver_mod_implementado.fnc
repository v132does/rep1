create or replace function it.FUE_VER_MOD_IMPLEMENTADO
 (p_cod_modulo in number,
  p_fecha date default null)
  return varchar2 is

  v_implementado varchar2(1) := 'N'; --no implementado
begin
  select 'S'
    into v_implementado
    from ba_modulos
   where cod_modulo = p_cod_modulo
     and fec_implementacion <= nvl(p_fecha,pag_cal.FU_OBT_FEC_ACTUAL(p_cod_modulo));
  return(v_implementado);
exception
  when too_many_rows then
     return ('S'); -- implementado
  when no_data_found then
     return ('N'); -- no implementado
  when others then
     raise_application_error(-20000,'Ver Mód. Implementado '||sqlerrm);
end;
/

