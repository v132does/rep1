create or replace function it.fug_ope_referencia(p_operacion     in lc_transferencias.nro_operacion%type default null,
                                              p_fec_operacion in lc_transferencias.fec_operacion%type default null)
  return varchar2 is
  v_val_convertido varchar2(60);
begin
  select (n.cod_tip_referencia || '/' || n.nro_referencia)
    into v_val_convertido
    from lc_transferencias n
   where n.nro_operacion = p_operacion
     and n.fec_operacion = p_fec_operacion ;
  return v_val_convertido;
exception
  when others then
    return nvl(p_operacion,'0');
end;
/

