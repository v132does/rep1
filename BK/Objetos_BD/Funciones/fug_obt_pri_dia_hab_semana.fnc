create or replace function it.fug_obt_pri_dia_hab_semana(p_fecha in date) return date is
 --Funcion que devueve el primer dia habil de la semana en la cual esta--
 --contenida una fecha recibida como parametro--
 v_nro_dia_semana number(1);
 v_fec_pri_hab_semana date;
 v_fec_auxliar date;
begin
  select to_number(to_char(p_fecha,'D')) nro_dia_semana
    into v_nro_dia_semana
    from dual;
  if v_nro_dia_semana = 1 then --Es domingo--
     v_fec_pri_hab_semana := pag_cal.fu_obt_fec_habil(p_fecha,1,null);
  else
     v_fec_auxliar := p_fecha - (v_nro_dia_semana - 2);
     v_fec_pri_hab_semana := pag_cal.fu_obt_fec_habil(v_fec_auxliar,1,null);
  end if;
  return v_fec_pri_hab_semana;
Exception
  when others then 
     raise_application_error(-20000,'Error en fug_obt_pri_dia_hab_semana: '||sqlerrm);  
end;
/

