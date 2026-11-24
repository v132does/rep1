create or replace function it.fub_obt_ult_dia_consolidado(p_fecha varchar2)
return varchar2
is
  v_fecha varchar2(10);
begin
  select case when to_char(max(c.fecha),'MM') != '12' then
           to_char(max(c.fecha),'YYYYMMDD')
         else
           to_char((pag_cal.fu_obt_fec_habil(max(c.fecha),-1,null)),'YYYYMMDD')
         end fecha
    into v_fecha
    from cb_sal_consolidados_dia c
   where to_char(c.fecha,'YYYYMM') = p_fecha;
  return v_fecha;
exception
  when others then
  return null;
end;
/

