create or replace function it.fuv_obt_dia_envio(p_fec_hoy in date,
                                             p_fec_envio in date)
                                   return number
is


v_cant_dias_completo number := 0;
v_cant_dias_habiles number := 0;
v_cant_dias_feriados number := 0;
v_cant_domysab number := 0;
v_fec_inicio date;
v_fec_fin date;

v_char_pru varchar2(20);

begin

  /*
    Calculamos todos los dias que hay entre la fecha de de hoy
    y la fecha de envio a vencida
  */
  select p_fec_hoy - p_fec_envio
    into v_cant_dias_completo
    from dual;
  /*
     Cantidad de dias que son feriados entre la fecha
     de hoy y la fecha de envio del telegrama
   */
   select count(*) Dias
     into v_cant_dias_feriados
     from ba_feriados f
    where f.fecha between p_fec_hoy and p_fec_envio;

     v_fec_inicio := p_fec_envio;
     v_fec_fin := p_fec_hoy;

  while v_fec_inicio < v_fec_fin loop
     v_char_pru := to_char(v_fec_inicio,'DAY');
     if replace(upper(v_char_pru),' ','') = 'SATURDAY' OR
        replace(upper(v_char_pru),' ','') = 'SUNDAY'
        --('SUNDAY','DOMINGO','SATURDAY', 'SÁBADO', 'SABADO')
         THEN
       v_cant_domysab := v_cant_domysab + 1;
     end if;
     v_fec_inicio := v_fec_inicio + 1;
  end loop;

  v_cant_dias_habiles := nvl(v_cant_dias_completo,0) - nvl(v_cant_dias_feriados,0) - nvl(v_cant_domysab,0);

  return v_cant_dias_habiles;
end;
/

