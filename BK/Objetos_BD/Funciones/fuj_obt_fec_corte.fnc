create or replace function it.fuj_obt_fec_corte(p_nro_caja in varchar2)
return date
is
 v_fec_ult_corte date;
begin
  begin
    select max(to_date(to_char(a.fecha,'dd/mm/yyyy')||' '||a.hora,'dd/mm/yyyy hh24:mi:ss'))
      into v_fec_ult_corte
      from cj_movimientos a
     where a.nro_caja = p_nro_caja
       and a.cod_tra_padre = 300
       and a.estado != 'R'
       and a.cod_usuario = (select c.cod_usu_responsable
                              from cj_cajas c
                             where c.nro_caja = p_nro_caja);
  exception
    when no_data_found then
    v_fec_ult_corte := null;
    when others then
    v_fec_ult_corte := null;
  end;
  if v_fec_ult_corte is null then
    begin
      select max(to_date(to_char(a.fecha,'dd/mm/yyyy')||' '||a.hora,'dd/mm/yyyy hh24:mi:ss'))
        into v_fec_ult_corte
        from cj_movimientos_his a
       where a.nro_caja = p_nro_caja
         and a.cod_tra_padre = 300
         and a.estado != 'R'
         and a.cod_usuario = (select c.cod_usu_responsable
                                from cj_cajas c
                               where c.nro_caja = p_nro_caja);
    exception
      when no_data_found then
      v_fec_ult_corte := null;
      when others then
      v_fec_ult_corte := null;
    end;
  end if;
  if v_fec_ult_corte is null then
    v_fec_ult_corte := to_date('01/01/1900 00:00:01','dd/mm/yyyy hh24:mi:ss');
  end if;
  return v_fec_ult_corte;
end;
/

