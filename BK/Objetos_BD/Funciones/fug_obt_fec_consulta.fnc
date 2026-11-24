create or replace function it.fug_obt_fec_consulta
return varchar2
is
  v_fecha varchar2(6);
  v_meses number := -1;
begin
  --
  v_fecha := to_char(add_months(pae_cnf.FU_OBT_FEC_ACTUAL(1),v_meses),'mmyyyy');    
  --
  return v_fecha;
end;
/

