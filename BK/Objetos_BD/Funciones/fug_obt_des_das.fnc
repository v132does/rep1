create or replace function it.fug_obt_des_das(p_mto_debito     in ge_ext_cli_movimientos.mto_debito%type,
                                              p_nro_cuenta     in varchar2,
                                              p_hor_movimiento in varchar2,
                                              p_nro_documento  in number,
                                              p_cod_tra_padre  in number,
                                              p_nro_secuencia  in number)
  return varchar2 is
  result varchar2(100);
begin
  begin
    select m.concepto
      into result
      from gv_movimientos m
     where m.cod_tra_padre = p_cod_tra_padre
       and m.nro_cuenta = p_nro_cuenta
       and m.nro_documento = p_nro_documento
       and m.nro_secuencia = p_nro_secuencia
       and m.hora = p_hor_movimiento
       and m.monto = p_mto_debito
       and m.FEC_INSERCION >= FUG_OBT_PARDINAMICO('FEC_VIG_DAS');
  exception
    when no_data_found then
      select t.descripcion
        into result
        from ge_transacciones t
       where t.cod_transaccion = p_cod_tra_padre
         and rownum = 1;
  end;
  return(result);
exception
  when others then
    result := 'DEBITO AUTOMATICO (DAS)';
    return(result);
end fug_obt_des_das;
/
