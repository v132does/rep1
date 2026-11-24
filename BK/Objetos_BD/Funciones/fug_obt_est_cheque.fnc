create or replace function it.fug_obt_est_cheque(p_fecha date,
                                              p_nro_cheque number,
                                              p_cod_moneda varchar2,
                                              p_estado varchar2,
                                              p_liberado varchar2,
                                              p_monto number)
return varchar2 is
  v_cod_causa ge_causales.cod_causa%type;
  v_fec_actual date := pag_cal.fu_obt_fec_actual(1);
BEGIN
  if p_fecha = v_fec_actual then
    begin
      select b.cod_causa
        into v_cod_causa
        from ge_movimientos a, ge_causales b
       where a.fecha = p_fecha
         and a.monto = p_monto
         and a.nro_documento = p_nro_cheque
         and a.cod_causa = b.cod_causa
         and a.cod_tra_padre = 321
         and rownum = 1;
    exception
      when no_data_found then
        v_cod_causa := null;
      when others then
        v_cod_causa := null;
    end;
  else
    begin
      select b.cod_causa
        into v_cod_causa
        from ge_movimientos_ant a, ge_causales b
       where a.fecha = p_fecha
         and a.monto = p_monto
         and a.nro_documento = p_nro_cheque
         and a.cod_causa = b.cod_causa
         and a.cod_tra_padre = 321
         and rownum = 1;
    exception
      when no_data_found then
        v_cod_causa := null;
      when others then
        v_cod_causa := null;
    end;
  end if;
      
  if v_cod_causa is not null then
    return v_cod_causa||'-Rechazado';
  end if;
  --
  if p_cod_moneda = 'USD' then
    if p_liberado = 'S' and p_estado = 'C' then
      return 'Confirmado';
    elsif p_liberado = 'N' and p_estado = 'C' then
      return 'Pend. de Confirmación';
    elsif p_liberado = 'N' and p_estado in ('E','I') then
      return 'Pend. de Confirmación';
    end if;
  else
    if p_liberado = 'S' and p_estado in ('E','I') then
      return 'Confirmado';
    elsif p_liberado = 'N' and p_estado = 'C' then
      return 'Pend. de Confirmación';
    elsif p_liberado = 'N' and p_estado in ('E','I') then
      return 'Pend. de Confirmación';
    end if;
  end if;
  
  return 'Pend. de Confirmación';
END;
/

