create or replace function it.fug_com_prom_vigente(p_cod_comercio in ge_com_promociones.cod_ent_comercio%type,
                                                   p_can_mes      in number)
  return varchar2 is
  v_activo             varchar2(1) := 'N';
  v_fec_inicio         date;
  v_fec_fin            date;
  v_fec_ini_referencia date;
  v_fec_fin_referencia date;
  v_fec_referencia     date;

begin
  begin
    select max(c.fec_inicio), max(c.fec_fin)
      into v_fec_inicio, v_fec_fin
      from ge_com_adheridos c, ge_com_promociones p
     where c.cod_promocion = p.cod_promo
       and p.cod_ent_comercio = p_cod_comercio;
  
    if p_can_mes = 0 then
      -- si es promo actual
      v_fec_referencia := trunc(sysdate);
      if v_fec_referencia >= v_fec_inicio and v_fec_referencia <= v_fec_fin then
        v_activo := 'S';
      end if;
    else
      v_fec_ini_referencia := trunc(ADD_MONTHS(trunc(sysdate),
                                               nvl(p_can_mes, -12)),
                                    'MM');
      if p_can_mes = -1 then
        --si es mes anterior la fecha fin de referencia es el ultimo dia del mes pasado
        v_fec_fin_referencia := LAST_DAY(ADD_MONTHS(trunc(sysdate),
                                                    nvl(p_can_mes, -12)));
      else
        --la fecha fin de referencia es una fecha futura a un anho
        v_fec_fin_referencia := LAST_DAY(ADD_MONTHS(trunc(sysdate), 12));
      end if;
    
      if v_fec_inicio between v_fec_ini_referencia and v_fec_fin_referencia then
        v_activo := 'S';
      end if;
    end if;
  
  exception
    when no_data_found then
      v_activo := 'N';
    when others then
      null;
  end;

  return(v_activo);
exception
  when others then
    v_activo := 'N';
    return(v_activo);
end fug_com_prom_vigente;
/

