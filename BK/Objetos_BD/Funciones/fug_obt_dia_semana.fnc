create or replace function it.fug_obt_dia_semana(p_fecha in date) return number is

v_nom_dia varchar2(30);
v_dia_semana number(2);
begin
  select trim(upper(to_char(p_fecha,'DAY')))
    into v_nom_dia
    from dual;
  if v_nom_dia in ('SUNDAY','DOMINGO') then
     v_dia_semana := 1;
  elsif v_nom_dia in ('MONDAY','LUNES') then
     v_dia_semana := 2;
  elsif v_nom_dia in ('TUESDAY','MARTES') then
     v_dia_semana := 3;
  elsif v_nom_dia in ('WEDNESDAY','MIERCOLES','MIÉRCOLES') then
     v_dia_semana := 4;
  elsif v_nom_dia in ('THURSDAY','JUEVES') then
     v_dia_semana := 5;
  elsif v_nom_dia in ('FRIDAY','VIERNES') then
     v_dia_semana := 6;
  else
     v_dia_semana := 7;
  end if;
  return v_dia_semana;
end;
/

