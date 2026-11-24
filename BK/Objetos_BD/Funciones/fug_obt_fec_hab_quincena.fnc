create or replace function it.fug_obt_fec_hab_quincena(p_fecha in date)
 return date
 is
   v_result date;
begin
   if (to_char(to_date(15||to_char(p_fecha,'mmyyyy'),'dd/mm/yyyy'),'D') = 1)
     then
     v_result := to_date(16||to_char(p_fecha,'mmyyyy'),'dd/mm/yyyy');
   elsif (to_char(to_date(15||to_char(p_fecha,'mmyyyy'),'dd/mm/yyyy'),'D') = 7)
     then
     v_result := to_date(17||to_char(p_fecha,'mmyyyy'),'dd/mm/yyyy');
   else
     v_result := to_date(15||to_char(p_fecha,'mmyyyy'),'dd/mm/yyyy');
   end if;
   return pag_cal.FU_OBT_FEC_SIG_HAB(v_result-1, null); -- null para p_cod_oficina.
end fug_obt_fec_hab_quincena;
/

