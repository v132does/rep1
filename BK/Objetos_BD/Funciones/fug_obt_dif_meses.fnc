create or replace function it.fug_obt_dif_meses(p_fec_final in date, p_fec_inicial in date)
 return number is
	v_result number;
  v_fec_inicial date;
begin
	if p_fec_final < p_fec_inicial then
    raise_application_error(-20000,'Las fecha de inicio es menor la fecha final.');
	end if;
  v_fec_inicial := to_date('01'||to_char(p_fec_inicial,'/mm/yyyy'),'dd/mm/yyyy');
  v_result := 1;
  LOOP
      v_fec_inicial := add_months(v_fec_inicial,1);
      EXIT WHEN v_fec_inicial > p_fec_final;
      v_result := nvl(v_result,0) + 1;
  END LOOP;

	if v_result < 0 then
    raise_application_error(-20000,'Las fecha de inicio es menor la fecha final.');
	end if;
  return v_result;
Exception
  when others then
		raise_application_error(-20000,'Error al realizar cálculo entre fechas.');
end fug_obt_dif_meses;
/

