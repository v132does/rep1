create or replace function it.fug_es_date(p_fec bw_mov_pendientes.dato2%type) return varchar2 is
 v_fecha date;
begin
  v_fecha := to_date(p_fec, 'dd/mm/yyyy');
  return 'S';
  exception
    when others then
      return 'N';
end;
/

