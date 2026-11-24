create or replace function it.fui_obt_des_periodo
(p_fec_hasta date,
 p_tip_periodo varchar2,
 p_fec_inicio date default null
) RETURN varchar2 is
v_retorno varchar2(100);
v_nom_mes varchar2(15);
v_nom_mes_desde varchar2(15);
v_nro_trimestre number(6);

begin
  --- Nombre del mes
  BEGIN
    select decode(to_number(to_char(p_fec_hasta,'MM')),1,'ENERO',2,'FEBRERO',
           3,'MARZO',4,'ABRIL',5,'MAYO',6,'JUNIO',7,'JULIO',8,'AGOSTO',
           9,'SETIEMBRE',10,'OCTUBRE',11,'NOVIEMBRE',12,'DICIEMBRE')
    into v_nom_mes
    from dual;
  END;
  if p_tip_periodo = 'T' then
     v_nro_trimestre := to_char(p_fec_hasta,'Q');
     --- Obtener mes inicial y final del trimestre
     BEGIN
        select decode(to_number(to_char(add_months(p_fec_hasta,-2),'MM')),1,'ENERO',2,'FEBRERO',
               3,'MARZO',4,'ABRIL',5,'MAYO',6,'JUNIO',7,'JULIO',8,'AGOSTO',
               9,'SETIEMBRE',10,'OCTUBRE',11,'NOVIEMBRE',12,'DICIEMBRE')
          into v_nom_mes_desde
          from dual;
     END;   
     v_retorno := 'TRIMESTRE '||v_nro_trimestre||': '||v_nom_mes_desde||' - '||v_nom_mes||' / '||to_char(p_fec_hasta,'YYYY');
  elsif p_tip_periodo = 'M' then
     v_retorno := 'MES '||v_nom_mes||' / '||to_char(p_fec_hasta,'YYYY');
  elsif p_tip_periodo = 'D' then
     v_retorno := 'DIA '||to_char(p_fec_hasta,'DD')||' DE '||v_nom_mes||' DE '||to_char(p_fec_hasta,'YYYY');
  elsif p_tip_periodo = 'A' then
     v_retorno := 'AÑO '||to_char(p_fec_hasta,'YYYY');
  elsif p_tip_periodo = 'S' then
     v_retorno := 'SEMANA DEL '||to_char(p_fec_inicio,'DD/MM/YYYY')||' AL '||to_char(p_fec_hasta,'DD/MM/YYYY');
  elsif p_tip_periodo = 'Q' then
     if to_char(p_fec_hasta,'DD') <= '15' then
        v_retorno := '1RA. QUINCENA DEL MES '||v_nom_mes||' / '||to_char(p_fec_hasta,'YYYY');
     else
        v_retorno := '2DA. QUINCENA DEL MES '||v_nom_mes||' / '||to_char(p_fec_hasta,'YYYY');
     end if;      
  end if;
  return v_retorno;
end;
/

