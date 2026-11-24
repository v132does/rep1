create or replace function it.ardepign_repetido(vsuc in number, vmon in number, vcta in number  ) return number
is
vresult number;
begin
  -- verifica si existe con fecha actual del sistema
  --select count(*) into vresult from SIMGIA_PROCESOS where nom_proceso = proceso and fec_proceso = pag_cal.fu_obt_fec_actual(1);
  select /*t.APSUCUR, t.APMONTO, t.APMAYOR*/ count(*) into vresult
  from simgia_ardepign_gar t
  where t.apsucur= vsuc and t.apmonto= vmon and t.apmayor= vcta;

  if vresult > 0 then
    RETURN 1;
  else
     RETURN 0;
  end if;

exception
  when no_data_found then
     RETURN 0;
end;
/

