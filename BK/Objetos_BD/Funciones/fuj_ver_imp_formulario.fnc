CREATE OR REPLACE FUNCTION IT.FUJ_VER_IMP_FORMULARIO(p_nro_cuenta      in ge_movimientos.nro_cuenta%type,
                                                  p_cod_persona     in ge_movimientos.cod_persona%type,
                                                  p_monto           in ge_movimientos.monto%type,
                                                  p_cod_transaccion in ge_movimientos.cod_transaccion%type,
                                                  p_mto_calculado   out number,
                                                  p_reimpresion     in varchar2 default 'N',                                     -- este parametro exclusivo para los casos de reimpresion(110-120)  
                                                  p_fecha           in cj_acu_imp_transacciones.fecha%type default null,         -- este parametro exclusivo para los casos de reimpresion(110-120)  
                                                  p_hora            in cj_acu_imp_transacciones.hora%type default null,          -- este parametro exclusivo para los casos de reimpresion(110-120)  
                                                  p_cod_usuario     in cj_acu_imp_transacciones.cod_usuario%type default null)   -- este parametro exclusivo para los casos de reimpresion(110-120)  
                                                  return boolean is
  v_monto       number := 0;
  v_monto_2     number := 0;
  v_cod_persona ge_movimientos.cod_persona%type;
  v_nro_cuenta  ge_movimientos.nro_cuenta%type              := p_nro_cuenta;
  v_cod_tra_formularios varchar2(2000)                      := fug_obt_pardinamico('COD_TRA_FORMULARIOS'); --242,243,NNN
  v_cod_tra_personas    varchar2(2000)                      := fug_obt_pardinamico('COD_TRA_FOR_PERSONAS'); --245, NNN
  v_fec_actual      ge_movimientos.fecha%type               := pag_cal.fu_obt_fec_actual(1); --fecha actual del sistema
  v_pri_dia_habil   ge_movimientos.fecha%type               := pag_cal.fu_obt_fec_pri_dia_mes_habil(1); --primer día hábil del mes actual
  v_existe          varchar2(1);
BEGIN
  begin -- verificamos si es o no cuenta de cambios
    select 'S'
      into v_existe
      from LC_CTA_CAMBIOS b
     where b.nro_cuenta = v_nro_cuenta;
  exception
    when others then
      v_existe := 'N';
  end;
  
if p_reimpresion = 'S' and v_existe = 'S' then   
   if fug_obt_pardinamico('CLI_CUE_DIA_MENSUAL') = 'D' then
        --buscamos diariamente:
        begin
          select nvl(sum(a.monto), 0)
            into v_monto
            from cj_acu_imp_transacciones a
           where a.nro_cuenta = v_nro_cuenta
             and a.fecha = p_fecha
             and a.hora = p_hora
             and a.cod_usuario = p_cod_usuario
             and nvl(a.impreso, 'N') <> 'R';
        exception
          when others then
            v_monto := 0;
        end;
    elsif fug_obt_pardinamico('CLI_CUE_DIA_MENSUAL') = 'M' then
          begin
            select nvl(sum(monto), 0) as monto
              into v_monto
              from (select a.nro_cuenta, nvl(sum(a.monto), 0) as monto
                      from cj_acu_imp_transacciones a
                     where a.nro_cuenta = v_nro_cuenta
                       and a.fecha = p_fecha
                       and a.hora = p_hora
                       and a.cod_usuario = p_cod_usuario
                       and nvl(a.impreso, 'N') <> 'R'
                     group by a.nro_cuenta
                    union
                    select a.nro_cuenta, nvl(sum(a.monto), 0) as monto
                      from cj_acu_imp_transacciones_his a
                     where a.nro_cuenta = v_nro_cuenta
                       and a.fecha = p_fecha
                       and a.hora = p_hora
                       and a.cod_usuario = p_cod_usuario                      
                       and nvl(a.impreso, 'N') <> 'R'
                     group by a.nro_cuenta);
            exception
              when others then
                v_monto := 0;
            end;
      else
           null;
      end if;

  v_monto_2 := nvl(v_monto, 0);
  v_monto   := nvl(v_monto, 0) + nvl(p_monto, 0);
else
  if (instr(',' || v_cod_tra_formularios || ',',   -- verificamos si la transaccion está parametrizada:
             ',' || p_cod_transaccion || ',') > 0) or
     (instr(',' || v_cod_tra_personas || ',',
             ',' || p_cod_transaccion || ',') > 0) then    
        if fug_obt_pardinamico('CUE_CLI_FORMULARIO') = 'CUE' then
           if v_existe = 'S' then
              v_cod_persona := p_cod_persona;  
           else
              v_cod_persona := fug_obt_cli_principal(p_nro_cuenta);
           end if;
        elsif fug_obt_pardinamico('CUE_CLI_FORMULARIO') = 'CLI' then 
             v_cod_persona := p_cod_persona;
        end if;
  end if;

  if v_nro_cuenta is not null and
     v_cod_persona is not null then
    if fug_obt_pardinamico('CUE_CLI_FORMULARIO') = 'CUE' then -- por cuenta o por persona
       /***********************************************************************************************************************************************************
         -En caso que esté incluido en el parámerto dinámico "COD_TRA_FORMULARIOS":
          cuando la busqueda se haga por cuenta finalmente se buscará por "cliente y por cuenta", se utiliza cod_cliente y cod_persona(el principal de la cuenta)
         -Si no está incluido en el parámerto dinámico "COD_TRA_FORMULARIOS":
          cuando la busqueda se haga por cliente finalmente se hará la busqueda por cliente.
       *************************************************************************************************************************************************************/
          if (instr(',' || v_cod_tra_formularios || ',',
                   ',' || p_cod_transaccion || ',') > 0) then
                if fug_obt_pardinamico('CLI_CUE_DIA_MENSUAL') = 'D' then
                    --buscamos diariamente:
                    begin
                      select nvl(sum(a.monto), 0)
                        into v_monto
                        from cj_acu_imp_transacciones a
                       where a.nro_cuenta = v_nro_cuenta
                         and a.cod_persona = v_cod_persona
                         and a.fecha = v_fec_actual
                         and (select b.cod_modulo -- evitamos la cuenta sea de cambios propia del banco
                                          from ge_cuentas b
                                         where b.nro_cuenta = a.nro_cuenta--'0107010003'
                                         group by b.cod_modulo) <> 7
                         and nvl(a.impreso, 'N') = 'N';
                    exception
                      when others then
                        v_monto := 0;
                    end;
                elsif fug_obt_pardinamico('CLI_CUE_DIA_MENSUAL') = 'M' then
                      begin
                        select nvl(sum(monto), 0) as monto
                          into v_monto
                          from (select a.nro_cuenta, nvl(sum(a.monto), 0) as monto
                                  from cj_acu_imp_transacciones a
                                 where a.nro_cuenta = v_nro_cuenta
                                   and a.cod_persona = v_cod_persona
                                   and a.fecha = v_fec_actual
                                   and (select b.cod_modulo -- evitamos la cuenta sea de cambios propia del banco
                                          from ge_cuentas b
                                         where b.nro_cuenta = a.nro_cuenta--'0107010003'
                                         group by b.cod_modulo) <> 7
                                   and nvl(a.impreso, 'N') = 'N'
                                 group by a.nro_cuenta
                                union
                                select a.nro_cuenta, nvl(sum(a.monto), 0) as monto
                                  from cj_acu_imp_transacciones_his a
                                 where a.nro_cuenta = v_nro_cuenta
                                   and a.cod_persona = v_cod_persona
                                   and a.fecha >= v_pri_dia_habil
                                   and (select b.cod_modulo -- evitamos la cuenta sea de cambios propia del banco
                                          from ge_cuentas b
                                         where b.nro_cuenta = a.nro_cuenta--'0107010003'
                                         group by b.cod_modulo) <> 7
                                   and nvl(a.impreso, 'N') = 'N'
                                 group by a.nro_cuenta);
                        exception
                          when others then
                            v_monto := 0;
                        end;
                  else
                       null;
                  end if;
            elsif (instr(',' || v_cod_tra_personas || ',', -- si la búsqueda se hará solo por el código de personas:
                   ',' || p_cod_transaccion || ',') > 0) then
               if fug_obt_pardinamico('CLI_CUE_DIA_MENSUAL') = 'D' then
                    --buscamos diariamente:
                    begin
                      select nvl(sum(a.monto), 0)
                        into v_monto
                        from cj_acu_imp_transacciones a
                       where a.cod_persona = v_cod_persona
                         and a.fecha = v_fec_actual
                         and (select b.cod_modulo -- evitamos la cuenta sea de cambios propia del banco
                                          from ge_cuentas b
                                         where b.nro_cuenta = a.nro_cuenta--'0107010003'
                                         group by b.cod_modulo) <> 7
                         and nvl(a.impreso, 'N') = 'N';
                    exception
                      when others then
                        v_monto := 0;
                    end;
                elsif fug_obt_pardinamico('CLI_CUE_DIA_MENSUAL') = 'M' then
                      begin
                        select nvl(sum(monto), 0) as monto
                          into v_monto
                          from (select a.cod_persona, nvl(sum(a.monto), 0) as monto
                                  from cj_acu_imp_transacciones a
                                 where a.cod_persona = v_cod_persona
                                   and a.fecha = v_fec_actual
                                   and (select b.cod_modulo -- evitamos la cuenta sea de cambios propia del banco
                                          from ge_cuentas b
                                         where b.nro_cuenta = a.nro_cuenta--'0107010003'
                                         group by b.cod_modulo) <> 7
                                   and nvl(a.impreso, 'N') = 'N'
                                 group by a.cod_persona
                                union
                                select a.cod_persona, nvl(sum(a.monto), 0) as monto
                                  from cj_acu_imp_transacciones_his a
                                 where a.cod_persona = v_cod_persona
                                   and a.fecha >= v_pri_dia_habil
                                   and (select b.cod_modulo -- evitamos la cuenta sea de cambios propia del banco
                                          from ge_cuentas b
                                         where b.nro_cuenta = a.nro_cuenta--'0107010003'
                                         group by b.cod_modulo) <> 7
                                   and nvl(a.impreso, 'N') = 'N'
                                 group by a.cod_persona);
                        exception
                          when others then
                            v_monto := 0;
                        end;
                  else
                       null;
                  end if;

            else -- busqueda normal
                if fug_obt_pardinamico('CLI_CUE_DIA_MENSUAL') = 'D' then --buscamos diariamente:
                  begin
                    select nvl(sum(a.monto), 0)
                      into v_monto
                      from cj_acu_imp_transacciones a
                     where a.nro_cuenta = v_nro_cuenta
                       and a.fecha = v_fec_actual
                       and nvl(a.impreso, 'N') = 'N'
                       and (select b.cod_modulo -- evitamos la cuenta sea de cambios propia del banco
                            from ge_cuentas b
                           where b.nro_cuenta = a.nro_cuenta--'0107010003'
                           group by b.cod_modulo) <> 7
                       and (instr(',' || v_cod_tra_formularios || ',',
                           ',' || a.cod_transaccion || ',') = 0);
                  exception
                    when others then
                      v_monto := 0;
                  end;
                elsif fug_obt_pardinamico('CLI_CUE_DIA_MENSUAL') = 'M' then
                      begin
                        select nvl(sum(monto), 0) as monto
                          into v_monto
                          from (select a.nro_cuenta, nvl(sum(a.monto), 0) as monto
                                  from cj_acu_imp_transacciones a
                                 where a.nro_cuenta = v_nro_cuenta
                                   and a.fecha = v_fec_actual
                                   and nvl(a.impreso, 'N') = 'N'
                                   and (select b.cod_modulo -- evitamos la cuenta sea de cambios propia del banco
                                          from ge_cuentas b
                                         where b.nro_cuenta = a.nro_cuenta--'0107010003'
                                         group by b.cod_modulo) <> 7
                                   and (instr(',' || v_cod_tra_formularios || ',',
                                        ',' || a.cod_transaccion || ',') = 0)
                                 group by a.nro_cuenta
                                union
                                select a.nro_cuenta, nvl(sum(a.monto), 0) as monto
                                  from cj_acu_imp_transacciones_his a
                                 where a.nro_cuenta = v_nro_cuenta
                                   and a.fecha >= v_pri_dia_habil
                                   and nvl(a.impreso, 'N') = 'N'
                                   and (select b.cod_modulo -- evitamos la cuenta sea de cambios propia del banco
                                          from ge_cuentas b
                                         where b.nro_cuenta = a.nro_cuenta--'0107010003'
                                         group by b.cod_modulo) <> 7
                                   and (instr(',' || v_cod_tra_formularios || ',',
                                       ',' || a.cod_transaccion || ',') = 0)
                                 group by a.nro_cuenta);
                      exception
                        when others then
                          v_monto := 0;
                      end;
                else
                   null;
                end if;
            end if;

-- Se  verifica si hay que imprimir el formulario, pero por cliente:
    elsif fug_obt_pardinamico('CUE_CLI_FORMULARIO') = 'CLI' then
        /***********************************************************************************************************************************************************
         -En caso que esté incluido en el parámerto dinámico "COD_TRA_FORMULARIOS":
          cuando la busqueda se haga por cuenta finalmente se buscará por "cliente y por cuenta", se utiliza cod_cliente y cod_persona(el principal de la cuenta)
         -Si no está incluido en el parámerto dinámico "COD_TRA_FORMULARIOS":
          cuando la busqueda se haga por cliente finalmente se hará la busqueda por cliente.
       *************************************************************************************************************************************************************/
          if (instr(',' || v_cod_tra_formularios || ',',
                   ',' || p_cod_transaccion || ',') > 0) then
                if fug_obt_pardinamico('CLI_CUE_DIA_MENSUAL') = 'D' then
                    --buscamos diariamente:
                    begin
                      select nvl(sum(a.monto), 0)
                        into v_monto
                        from cj_acu_imp_transacciones a
                       where a.nro_cuenta = v_nro_cuenta
                         and a.cod_persona = v_cod_persona
                         and a.fecha = v_fec_actual
                         and nvl(a.impreso, 'N') = 'N';
                    exception
                      when others then
                        v_monto := 0;
                    end;
                elsif fug_obt_pardinamico('CLI_CUE_DIA_MENSUAL') = 'M' then
                      begin
                        select nvl(sum(monto), 0) as monto
                          into v_monto
                          from (select a.nro_cuenta, nvl(sum(a.monto), 0) as monto
                                  from cj_acu_imp_transacciones a
                                 where a.nro_cuenta = v_nro_cuenta
                                   and a.cod_persona = v_cod_persona
                                   and a.fecha = v_fec_actual
                                   and nvl(a.impreso, 'N') = 'N'
                                 group by a.nro_cuenta
                                union
                                select a.nro_cuenta, nvl(sum(a.monto), 0) as monto
                                  from cj_acu_imp_transacciones_his a
                                 where a.nro_cuenta = v_nro_cuenta
                                   and a.cod_persona = v_cod_persona
                                   and a.fecha >= v_pri_dia_habil
                                   and nvl(a.impreso, 'N') = 'N'
                                 group by a.nro_cuenta);
                        exception
                          when others then
                            v_monto := 0;
                        end;
                  else
                       null;
                  end if;
            elsif (instr(',' || v_cod_tra_personas || ',', -- si la búsqueda se hará solo por el código de personas:
                   ',' || p_cod_transaccion || ',') > 0) then
               if fug_obt_pardinamico('CLI_CUE_DIA_MENSUAL') = 'D' then
                    --buscamos diariamente:
                    begin
                      select nvl(sum(a.monto), 0)
                        into v_monto
                        from cj_acu_imp_transacciones a
                       where a.cod_persona = v_cod_persona
                         and a.fecha = v_fec_actual
                         and nvl(a.impreso, 'N') = 'N';
                    exception
                      when others then
                        v_monto := 0;
                    end;
                elsif fug_obt_pardinamico('CLI_CUE_DIA_MENSUAL') = 'M' then
                      begin
                        select nvl(sum(monto), 0) as monto
                          into v_monto
                          from (select a.cod_persona, nvl(sum(a.monto), 0) as monto
                                  from cj_acu_imp_transacciones a
                                 where a.cod_persona = v_cod_persona
                                   and a.fecha = v_fec_actual
                                   and nvl(a.impreso, 'N') = 'N'
                                 group by a.cod_persona
                                union
                                select a.cod_persona, nvl(sum(a.monto), 0) as monto
                                  from cj_acu_imp_transacciones_his a
                                 where a.cod_persona = v_cod_persona
                                   and a.fecha >= v_pri_dia_habil
                                   and nvl(a.impreso, 'N') = 'N'
                                 group by a.cod_persona);
                        exception
                          when others then
                            v_monto := 0;
                        end;
                  else
                       null;
                  end if;

            else -- busqueda normal
                if fug_obt_pardinamico('CLI_CUE_DIA_MENSUAL') = 'D' then --buscamos diariamente:
                  begin
                    select nvl(sum(a.monto), 0)
                      into v_monto
                      from cj_acu_imp_transacciones a
                     where a.cod_persona = v_cod_persona
                       and a.fecha = v_fec_actual
                       and nvl(a.impreso, 'N') = 'N'
                       and (instr(',' || v_cod_tra_formularios || ',',
                           ',' || a.cod_transaccion || ',') = 0);
                  exception
                    when others then
                      v_monto := 0;
                  end;
                elsif fug_obt_pardinamico('CLI_CUE_DIA_MENSUAL') = 'M' then
                      begin
                        select nvl(sum(monto), 0) as monto
                          into v_monto
                          from (select a.cod_persona, nvl(sum(a.monto), 0) as monto
                                  from cj_acu_imp_transacciones a
                                 where a.cod_persona = v_cod_persona
                                   and a.fecha = v_fec_actual
                                   and nvl(a.impreso, 'N') = 'N'
                                   and (instr(',' || v_cod_tra_formularios || ',',
                                        ',' || a.cod_transaccion || ',') = 0)
                                 group by a.cod_persona
                                union
                                select a.cod_persona, nvl(sum(a.monto), 0) as monto
                                  from cj_acu_imp_transacciones_his a
                                 where a.cod_persona = v_cod_persona
                                   and a.fecha >= v_pri_dia_habil
                                   and nvl(a.impreso, 'N') = 'N'
                                   and (instr(',' || v_cod_tra_formularios || ',',
                                       ',' || a.cod_transaccion || ',') = 0)
                                 group by a.cod_persona);
                      exception
                        when others then
                          v_monto := 0;
                      end;
                else
                   null;
                end if;
            end if;
    else
      null;
    end if;
    v_monto_2 := nvl(v_monto, 0);
    v_monto   := nvl(v_monto, 0) + nvl(p_monto, 0); -- le sumamos el monto de la transaccion en cuestion
  end if;
end if;  
  p_mto_calculado := v_monto_2; --monto que se enviará a FUJ_IMP_DEC_JURADA_40
  if v_monto >= fug_obt_pardinamico('OPE_SUP_MON_FUERTE') then
    return(true);
  else
    return(false);
  end if;

EXCEPTION
  WHEN OTHERS THEN
    Raise_application_error(-20000,
                            'Error al buscar datos Impresion de Formularios F.I.T ' ||
                            sqlerrm);
    return(false);
END FUJ_VER_IMP_FORMULARIO;
/

