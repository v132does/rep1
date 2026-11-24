create or replace function it.fug_obt_nom_dia_mes(p_tipo in varchar2,
                                               p_fecha in date default null) return varchar2 is
  v_nombre varchar2(50);
  v_fecha date;
begin
  if p_fecha is null then
     v_fecha := pag_cal.FU_OBT_FEC_ACTUAL(1);
  else
     v_fecha := p_fecha;
  end if;
  if p_tipo = 'D' then --Nombre del Día--
   BEGIN
      select rtrim(upper(to_char(v_fecha,'DAY')))
      into v_nombre
      from dual;
      If v_nombre    = 'SUNDAY'    then v_nombre := 'DOMINGO';
      Elsif v_nombre = 'MONDAY'    then v_nombre := 'LUNES';
      Elsif v_nombre = 'TUESDAY'   then v_nombre := 'MARTES' ;
      Elsif v_nombre = 'WEDNESDAY' then v_nombre := 'MIERCOLES' ;
      Elsif v_nombre = 'THURSDAY'  then v_nombre := 'JUEVES' ;
      Elsif v_nombre = 'FRIDAY'    then v_nombre := 'VIERNES'  ;
      Elsif v_nombre = 'SATURDAY'  then v_nombre := 'SABADO' ;
      End if;
   END;
  elsif p_tipo = 'M' then --Nombre del Mes--
   BEGIN
      select decode(to_number(to_char(v_fecha,'MM')),1,'ENERO',2,'FEBRERO',
             3,'MARZO',4,'ABRIL',5,'MAYO',6,'JUNIO',7,'JULIO',8,'AGOSTO',
             9,'SETIEMBRE',10,'OCTUBRE',11,'NOVIEMBRE',12,'DICIEMBRE')
      into v_nombre
      from dual;
   END;
  end if;
  return(v_nombre);
exception
  when others then
       raise_application_error(-20000,'Error en : fug_obt_nom_dia_mes '||sqlerrm);
end fug_obt_nom_dia_mes;
/

