create or replace function it.fug_tip_operacion(p_cod_transaccion in ge_transacciones.cod_transaccion%type,
                                                p_cod_modulo      in ge_transacciones.cod_modulo%type,
                                                p_cod_modalidad   in ge_transacciones.cod_modalidad%type,
                                                p_cod_tra_padre   in ge_transacciones.cod_transaccion%type,
                                                p_cod_mod_padre   in ge_transacciones.cod_modulo%type,
                                                p_cod_mad_padre   in ge_transacciones.cod_modalidad%type)
  return varchar2 is
  v_tipo varchar2(100);
begin
  if p_cod_tra_padre in (352, 393) then
    v_tipo := 'Depósito';
    return(v_tipo);
  elsif p_cod_tra_padre in (353, 382) then
    v_tipo := 'Extracción en efectivo';
    return(v_tipo);
  elsif p_cod_tra_padre in (380, 389) then
    v_tipo := 'Transacción tarjetas';
    return(v_tipo);
  elsif p_cod_tra_padre in (8526, 8592) then
    v_tipo := 'Pago de servicios';
    return(v_tipo);
  elsif p_cod_tra_padre = 325 and p_cod_mod_padre = 3 and
        p_cod_transaccion in (560, 609) then
    v_tipo := 'Capitalización de interés Cuentas';
    return(v_tipo);
  elsif p_cod_tra_padre = 250 and p_cod_mod_padre = 5 then
    v_tipo := 'Pago de tarjeta de crédito';
    return(v_tipo);
   elsif p_cod_tra_padre = 384 and p_cod_mod_padre in (9,4) then
      v_tipo := 'Transferencia por contacto';
    return(v_tipo);
   elsif p_cod_tra_padre = 702 then
     v_tipo := 'Reintegro';
    return(v_tipo);
  end if;

  if nvl(v_tipo, 'x') = 'x' then
    begin
      --Busca si es transferencia
      select decode(d.cod_transaccion,
                    303,
                    'Transferencia a otro banco',
                    'Transferencia entre cuentas')
        into v_tipo
        from ge_gru_transacciones_det d
       where d.cod_gru_transaccion = '108'
         and d.cod_transaccion = p_cod_tra_padre
         and d.cod_modulo = p_cod_modulo
         and d.cod_modalidad = p_cod_modalidad;
      return(v_tipo);
    exception
      --Busca si es creditos varios
      when no_data_found then
        begin
          select 'Créditos varios'
            into v_tipo
            from ge_gru_transacciones_det d
           where d.cod_gru_transaccion = '101'
             and d.cod_transaccion = p_cod_transaccion
             and d.cod_modulo = p_cod_modulo
             and d.cod_modalidad = p_cod_modalidad;
          return(v_tipo);
        exception
          --
          when no_data_found then
            begin
              select 'Débitos, Cobros, Comisiones, Cargos, etc.'
                into v_tipo
                from ge_gru_transacciones_det d
               where d.cod_gru_transaccion = '100'
                 and d.cod_transaccion = p_cod_transaccion
                 and d.cod_modulo = p_cod_modulo
                 and d.cod_modalidad = p_cod_modalidad;
              return(v_tipo);
            exception
              --Busca si es deposito
              when no_data_found then
                begin
                  select 'Depósito'
                    into v_tipo
                    from ge_gru_transacciones_det d
                   where d.cod_gru_transaccion = '109'
                     and d.cod_transaccion = p_cod_transaccion
                     and d.cod_modulo = p_cod_modulo
                     and d.cod_modalidad = p_cod_modalidad;
                  return(v_tipo);
                exception
                  when no_data_found then
                    begin
                      select 'Pago de tarjeta de crédito'
                        into v_tipo
                        from ge_gru_transacciones_det d
                       where d.cod_gru_transaccion = '105'
                         and d.cod_transaccion = p_cod_transaccion
                         and d.cod_modulo = p_cod_modulo
                         and d.cod_modalidad = p_cod_modalidad;
                         return(v_tipo);
                    exception
                      when no_data_found then
                        begin
                          select 'Transacción de Tarjeta de crédito'
                            into v_tipo
                            from ge_gru_transacciones_det d
                           where d.cod_gru_transaccion = '106'
                             and d.cod_transaccion = p_cod_transaccion
                             and d.cod_modulo = p_cod_modulo
                             and d.cod_modalidad = p_cod_modalidad;
                             return(v_tipo);
                        exception
                          when no_data_found then
                            begin
                              select 'Cargos de tarjetas'
                                into v_tipo
                                from ge_gru_transacciones_det d
                               where d.cod_gru_transaccion = '107'
                                 and d.cod_transaccion = p_cod_transaccion
                                 and d.cod_modulo = p_cod_modulo
                                 and d.cod_modalidad = p_cod_modalidad;
                                 return(v_tipo);
                            exception
                              when no_data_found then
                                v_tipo := 'Otras transacciones';
                                return(v_tipo);
                            end;
                        end;
                    end;
                end;
            end;
        end;
    end;
  end if;
  if nvl(v_tipo,'x')='x' then
    v_tipo := 'Otras transacciones';
    return(v_tipo);
  end if;
exception
  when others then
    prg_ins_log_programas('FUG_TIP_OPERACION',sqlerrm||' : '||p_cod_tra_padre||' '||p_cod_mod_padre||' '||p_cod_mad_padre||' '||p_cod_modalidad||' '||p_cod_modulo||' '||p_cod_modalidad,null,null);
    v_tipo := 'Otras transacciones';
    return(v_tipo);
end fug_tip_operacion;
/

