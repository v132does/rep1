create or replace function it.fuh_cal_dia_asistencia (
  p_fec_asistencia date,
  p_cod_persona    ba_personas.cod_persona%type)
  return varchar
  is
  v_dia  number;
  v_trabajo varchar2(1);
begin
  begin
    select to_char(a.fecha,'D')
    into   v_dia
    from   rh_asistencias a
    where  a.cod_persona = p_cod_persona
    and    p_fec_asistencia = a.fecha;
  exception
    when no_data_found then
       select to_char(p_fec_asistencia,'D')
       into   v_dia
       from   dual;
       ---
       if v_dia not in (6,7) then
          begin
            select 'F'
            into   v_trabajo
            from   ba_feriados f
            where  f.fecha = p_fec_asistencia;
          exception
            when no_data_found then
               v_dia := 0;
          end;
       end if;
    when others then
       v_dia := 0;
  end;
  ---
  if v_dia = 6 then
     v_trabajo := 'S';
  elsif v_dia = 7 then
     v_trabajo := 'D';
  elsif v_dia = 0 then
     v_trabajo := '0';
  else
     v_trabajo := '7';
  end if;
  ---
  return v_trabajo;
end;
/

