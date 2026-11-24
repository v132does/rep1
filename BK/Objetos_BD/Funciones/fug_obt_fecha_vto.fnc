create or replace function it.fug_obt_fecha_vto(p_opcion in number)
  return date is
  v_fecha_vto  date;
  v_fec_actual date;
  v_aux        varchar2(10);
  v_dia        varchar2(2);
  v_mes        varchar(2);
  v_ano        varchar(4);
  v_can_dia    number;

begin
  v_fec_actual := pag_cal.fu_obt_fec_actual(1);
  v_can_dia    := to_number(nvl(fug_obt_pardinamico('CAN_DIA_VTO_ADICIONAL'),
                                0));
  v_fec_actual := v_fec_actual + nvl(v_can_dia, 0);
  v_dia        := to_number(to_char(v_fec_actual, 'DD'));
  v_mes        := to_number(to_char(v_fec_actual, 'MM'));
  v_ano        := to_number(to_char(v_fec_actual, 'YYYY'));
  if nvl(v_dia, 0) > nvl(p_opcion, 0) then
    v_aux       := p_opcion || '/' || v_mes || '/' || v_ano;
    v_fecha_vto := add_months(to_date(v_aux, 'dd/mm/yyyy'), 2);
  else
    if v_mes = '2' then
      IF p_opcion <= 15 THEN
        v_aux       := p_opcion || '/' || v_mes || '/' || v_ano;
        v_fecha_vto := add_months(to_date(v_aux, 'dd/mm/yyyy'), 1);
      ELSE
        v_aux       := last_day(v_fec_actual);
        v_fecha_vto := add_months(to_date(v_aux, 'dd/mm/yyyy'), 1);
        v_dia       := to_number(to_char(v_fecha_vto, 'DD'));
        v_mes       := to_number(to_char(v_fecha_vto, 'MM'));
        v_ano       := to_number(to_char(v_fecha_vto, 'YYYY'));
        v_fecha_vto := to_date(p_opcion || '/' || v_mes || '/' || v_ano,'dd/mm/RRRR');
      END IF;
    else
      v_aux       := p_opcion || '/' || v_mes || '/' || v_ano;
      v_fecha_vto := add_months(to_date(v_aux, 'dd/mm/yyyy'), 1);
    end if;
  end if;
  return(v_fecha_vto);

end fug_obt_fecha_vto;
/

