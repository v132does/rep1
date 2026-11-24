create or replace function it.fuw_obt_nro_movimiento(p_nro_doc_pendiente  bw_movimientos.nro_doc_pendiente%type)
  return bw_movimientos.nro_movimiento%type is
  v_nro_movimiento bw_movimientos.nro_movimiento%type;
begin
  select to_number(c.nro_movimiento || c.cod_tip_mensaje)
  into v_nro_movimiento
  from bw_movimientos c
  where c.nro_doc_pendiente = p_nro_doc_pendiente;
  return v_nro_movimiento;
  exception
    when others then
      return null;
end;
/

