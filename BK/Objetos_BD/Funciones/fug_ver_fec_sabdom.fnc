create or replace function it.fug_ver_fec_sabdom(p_fecha in date) return varchar2 is
 --Verifica si una fecha dada es Sabado o Domingo--
 --Variables--
 v_nom_dia varchar2(100);
 v_es_feriado varchar2(1);
begin
  --Verificar Sabadi y Domingio--
  select ltrim(rtrim(upper(to_char(trunc(p_fecha),'DAY'))))
    into v_nom_dia
    from dual;
  
  v_es_feriado := 'N';
  if fue_ctr_fec_feriado(p_fecha,null) THEN
     v_es_feriado := 'S';
  end if;
  
  if ((v_nom_dia in ('SATURDAY','SABADO','SÁBADO','SUNDAY','DOMINGO')) or 
      (nvl(v_es_feriado,'N') = 'S')) then
     return 'S';
  else
     return 'N';
  end if;
 
exception
  when others then
    raise_application_error(-20000,'Error en fug_ver_fec_sabdom - '||sqlerrm);
end;
/

