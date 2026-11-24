CREATE OR REPLACE TRIGGER IT."TB_GE_AUT_REVERSIONES"
  before update on GE_AUT_REVERSIONES 
  referencing new as new old as old
  for each row
DECLARE
  -- CROGEFIT-3: JUANMA-20/04/2015: Este trigger es solamente para los casos de impresion de formularios FIT.
  procedure pr_rev_formularios(p_fecha           in cj_acu_imp_transacciones.fecha%type,
                               p_cod_persona     in cj_acu_imp_transacciones.cod_persona%type,
                               p_nro_cuenta      in cj_acu_imp_transacciones.nro_cuenta%type,
                               p_cod_transaccion in cj_acu_imp_transacciones.cod_transaccion%type,
                               p_nro_documento   in ge_movimientos.nro_documento%type) is
    v_cod_tra_formularios varchar2(2000) := fug_obt_pardinamico('COD_TRA_FORMULARIOS'); --242,243,NNN
    v_cod_tra_personas    varchar2(2000) := fug_obt_pardinamico('COD_TRA_FOR_PERSONAS'); --245, NNN
    v_fec_actual          ge_movimientos.fecha%type := pag_cal.fu_obt_fec_actual(1); --fecha actual del sistema
    v_pri_dia_habil       ge_movimientos.fecha%type := pag_cal.fu_obt_fec_pri_dia_mes_habil(1); --primer día hábil del mes actual
    v_cod_persona         ba_personas.cod_persona%type;
    v_nro_cuenta          cj_acu_imp_transacciones.nro_cuenta%type := p_nro_cuenta;
    r_acu                 cj_acu_imp_transacciones%rowtype;
    g_fecha               cj_acu_imp_transacciones.fecha%type;
    g_hora                cj_acu_imp_transacciones.hora%type;
  
    -- para los casos en que fueron parametrizadas por persona:
    procedure pr_act_personas(p_fecha in cj_acu_imp_transacciones.fecha%type,
                              p_hora  in cj_acu_imp_transacciones.hora%type) is
    begin
      if fug_obt_pardinamico('CLI_CUE_DIA_MENSUAL') = 'D' then
        --buscamos diariamente:
        begin
          select a.*
            into r_acu
            from cj_acu_imp_transacciones a
           where a.cod_persona = v_cod_persona
             and a.fecha = p_fecha
             and a.hora = p_hora
             and a.cod_transaccion = p_cod_transaccion
             and a.fecha = v_fec_actual;
          --and nvl(a.impreso, 'N') = 'S';
        exception
          when others then
            r_acu := null;
        end;
        if r_acu.cod_persona is not null then
          update cj_acu_imp_transacciones a --actualizamos solo el primer registro
             set a.impreso = 'R'
           where a.cod_persona = r_acu.cod_persona
             and a.hora = r_acu.hora
             and a.fecha = r_acu.fecha;
          --and nvl(a.impreso, 'N') = 'S';
          update cj_acu_imp_transacciones a --actualizamos todos los registros involucrados
             set a.impreso = 'N'
           where a.cod_persona = r_acu.cod_persona
             and a.fec_modificacion = r_acu.fec_modificacion;
          --and nvl(a.impreso, 'N') = 'S';
        end if;
      elsif fug_obt_pardinamico('CLI_CUE_DIA_MENSUAL') = 'M' then
        begin
          select * -- recuperamos datos de la tabla maestra
            into r_acu
            from cj_acu_imp_transacciones a
           where a.cod_persona = v_cod_persona
             and a.fecha = p_fecha
             and a.hora = p_hora
             and a.cod_transaccion = p_cod_transaccion
             and a.fecha = v_fec_actual;
          --and nvl(a.impreso, 'N') = 'S';
        exception
          when others then
            r_acu := null;
        end;
      
        if r_acu.cod_persona is not null then
          update cj_acu_imp_transacciones a --actualizamos solo el primer registro
             set a.impreso = 'R'
           where a.cod_persona = r_acu.cod_persona
             and a.hora = r_acu.hora
             and a.fecha = r_acu.fecha;
          --and nvl(a.impreso, 'N') = 'S';
          update cj_acu_imp_transacciones a --actualizamos todos los registros involucrados
             set a.impreso = 'N'
           where a.cod_persona = r_acu.cod_persona
             and a.fec_modificacion = r_acu.fec_modificacion;
          --and nvl(a.impreso, 'N') = 'S';
          update cj_acu_imp_transacciones_his b --actualizamos todos los registros de la tabla histórico
             set b.impreso = 'N'
           where b.cod_persona = r_acu.cod_persona
             and b.fec_modificacion = r_acu.fec_modificacion
             and b.fecha >= v_pri_dia_habil;
          --and nvl(b.impreso, 'N') = 'S';
        end if;
      end if;
    end pr_act_personas;
  
    -- en este procedimiento actualizamos las transacciones de caja que fueron parametrizadas por cliente y persona:
    procedure pr_act_cli_persona(p_fecha in cj_acu_imp_transacciones.fecha%type,
                                 p_hora  in cj_acu_imp_transacciones.hora%type) is
    begin
      if fug_obt_pardinamico('CLI_CUE_DIA_MENSUAL') = 'D' then
        --buscamos diariamente:
        begin
          select a.*
            into r_acu
            from cj_acu_imp_transacciones a
           where (a.nro_cuenta = v_nro_cuenta or v_nro_cuenta is null)
             and a.cod_persona = v_cod_persona
             and a.fecha = p_fecha
             and a.hora = p_hora
             and a.cod_transaccion = p_cod_transaccion
             and a.fecha = v_fec_actual;
          --and nvl(a.impreso, 'N') = 'S';
        exception
          when others then
            r_acu := null;
        end;
        if r_acu.nro_cuenta is not null and r_acu.cod_persona is not null then
          update cj_acu_imp_transacciones a --actualizamos solo el primer registro
             set a.impreso = 'R'
           where (a.nro_cuenta = v_nro_cuenta or v_nro_cuenta is null)
             and a.cod_persona = r_acu.cod_persona
             and a.hora = r_acu.hora
             and a.fecha = r_acu.fecha;
          update cj_acu_imp_transacciones a --actualizamos todos los registros involucrados
             set a.impreso = 'N'
           where a.nro_cuenta = r_acu.nro_cuenta
             and a.cod_persona = r_acu.cod_persona
             and a.fec_modificacion = r_acu.fec_modificacion;
          --and nvl(a.impreso, 'N') = 'S';
        end if;
      elsif fug_obt_pardinamico('CLI_CUE_DIA_MENSUAL') = 'M' then
        begin
          select * -- recuperamos datos de la tabla maestra
            into r_acu
            from cj_acu_imp_transacciones a
           where (a.nro_cuenta = v_nro_cuenta or v_nro_cuenta is null)
             and a.cod_persona = v_cod_persona
             and a.fecha = p_fecha
             and a.hora = p_hora
             and a.cod_transaccion = p_cod_transaccion
             and a.fecha = v_fec_actual;
          --and nvl(a.impreso, 'N') = 'S';
        exception
          when others then
            r_acu := null;
        end;
      
        if r_acu.cod_persona is not null and r_acu.nro_cuenta is not null then
          update cj_acu_imp_transacciones a --actualizamos solo el primer registro
             set a.impreso = 'R'
           where a.nro_cuenta = r_acu.nro_cuenta
             and a.cod_persona = r_acu.cod_persona
             and a.hora = r_acu.hora
             and a.fecha = r_acu.fecha;
          --and nvl(a.impreso, 'N') = 'S';
          update cj_acu_imp_transacciones a --actualizamos todos los registros involucrados
             set a.impreso = 'N'
           where a.nro_cuenta = r_acu.nro_cuenta
             and a.cod_persona = r_acu.cod_persona
             and a.fec_modificacion = r_acu.fec_modificacion;
          --and nvl(a.impreso, 'N') = 'S';
          update cj_acu_imp_transacciones_his b --actualizamos todos los registros de la tabla histórico
             set b.impreso = 'N'
           where b.nro_cuenta = r_acu.nro_cuenta
             and b.cod_persona = r_acu.cod_persona
             and b.fec_modificacion = r_acu.fec_modificacion
             and b.fecha >= v_pri_dia_habil;
          --and nvl(b.impreso, 'N') = 'S';
        end if;
      end if;
    end pr_act_cli_persona;
  
    -- programa principal
  begin
    begin
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 1;
    end;
    if (instr(',' || v_cod_tra_formularios || ',', -- verificamos si la transaccion está parametrizada:
              ',' || p_cod_transaccion || ',') > 0) or
       (instr(',' || v_cod_tra_personas || ',',
              ',' || p_cod_transaccion || ',') > 0) then
      if p_cod_persona is not null then
        begin
          select a.cod_persona
            into v_cod_persona
            from ba_personas a
           where a.cod_persona = p_cod_persona;
        exception
          when others then
            Raise_application_error(-20001,
                                    'No se ha encontrado registros para esta Persona: ' ||
                                    p_cod_persona);
        end;
      end if;
    else
      v_cod_persona := fug_obt_cli_principal(v_nro_cuenta);
    end if;
  
    if p_cod_transaccion in ('243', '245', '246') then
      begin
        select g.fecha, g.hora
          into g_fecha, g_hora
          from ge_movimientos g
         where g.fecha = p_fecha
           and g.nro_documento = p_nro_documento
           and g.nro_cuenta is not null
           and g.reversado <> 'S'
           and g.hora = (select max(f.hora)
                           from ge_movimientos f
                          where g.cod_usuario = f.cod_usuario
                            and g.fecha = f.fecha
                            and g.nro_secuencia = f.nro_secuencia
                            and g.nro_documento = f.nro_documento)
           and g.nro_cuenta = (case -- aquí elegimos si existe una cuenta distinta a la cuenta de cambios del banco, sino elegimos esa cuenta de cambios:
                 when ((select count(a.nro_cuenta)
                          from ge_movimientos a
                         where a.nro_documento = g.nro_documento
                           and a.fecha = g.fecha
                           and a.cod_usuario = g.cod_usuario
                           and a.hora = g.hora
                           and a.nro_cuenta is not null
                           and not exists (select b.nro_cuenta
                                  from LC_CTA_CAMBIOS b
                                 where a.nro_cuenta = b.nro_cuenta)) > 0) then
                  (select a.nro_cuenta
                     from ge_movimientos a
                    where a.nro_documento = g.nro_documento
                      and a.fecha = g.fecha
                      and a.cod_usuario = g.cod_usuario
                      and a.hora = g.hora
                      and a.nro_cuenta is not null
                      and not exists (select b.nro_cuenta
                             from LC_CTA_CAMBIOS b
                            where a.nro_cuenta = b.nro_cuenta)
                    group by a.nro_cuenta)
                 else
                  (select a.nro_cuenta
                     from ge_movimientos a
                    where a.nro_documento = g.nro_documento
                      and a.fecha = g.fecha
                      and a.cod_usuario = g.cod_usuario
                      and a.hora = g.hora
                      and a.nro_cuenta is not null
                      and exists (select b.nro_cuenta
                             from LC_CTA_CAMBIOS b
                            where a.nro_cuenta = b.nro_cuenta)
                    group by a.nro_cuenta)
               end)
         group by g.fecha, g.hora;
      exception
        when no_data_found then
          begin
            select a.fecha, a.hora
              into g_fecha, g_hora
              from cj_acu_imp_transacciones a
             where a.fecha = p_fecha
               and a.cod_transaccion = p_cod_transaccion
               and a.hora = :new.hora
               and a.cod_usuario = :new.cod_usuario
               and (a.cod_persona = :new.cod_persona or
                   :new.cod_persona is null)
               and (a.nro_cuenta = :new.nro_cuenta or
                   :new.nro_cuenta is null);
          exception
            when others then
              g_fecha := null;
              g_hora  := null;
          end;
        when others then
          g_fecha := null;
          g_hora  := null;
      end;
    else
      --recuperamos los datos de ge_movimientos y cj_movimientos porque puede haber diferencia de hora:
      begin
        select a.fecha, a.hora
          into g_fecha, g_hora
          from ge_movimientos g, cj_movimientos a
         where g.fecha = p_fecha
           and g.nro_documento = a.nro_documento
           and g.cod_moneda = a.cod_moneda
           and g.nro_documento = p_nro_documento
           and g.fecha = a.fecha
           and g.nro_cuenta is not null
           and g.reversado <> 'S'
           and a.estado <> 'R'
           and g.hora = (select max(f.hora)
                           from ge_movimientos f
                          where g.cod_usuario = f.cod_usuario
                            and g.fecha = f.fecha
                            and g.nro_secuencia = f.nro_secuencia
                            and g.nro_documento = f.nro_documento)
           and g.nro_cuenta = (case -- aquí elegimos si existe una cuenta distinta a la cuenta de cambios del banco, sino elegimos esa cuenta de cambios:
                 when ((select count(a.nro_cuenta)
                          from ge_movimientos a
                         where a.nro_documento = g.nro_documento
                           and a.fecha = g.fecha
                           and a.cod_usuario = g.cod_usuario
                           and a.hora = g.hora
                           and a.nro_cuenta is not null
                           and not exists
                         (select b.nro_cuenta
                                  from LC_CTA_CAMBIOS b
                                 where a.nro_cuenta = b.nro_cuenta)) > 0) then
                  (select a.nro_cuenta
                     from ge_movimientos a
                    where a.nro_documento = g.nro_documento
                      and a.fecha = g.fecha
                      and a.cod_usuario = g.cod_usuario
                      and a.hora = g.hora
                      and a.nro_cuenta is not null
                      and not exists
                    (select b.nro_cuenta
                             from LC_CTA_CAMBIOS b
                            where a.nro_cuenta = b.nro_cuenta)
                    group by a.nro_cuenta)
                 else
                  (select a.nro_cuenta
                     from ge_movimientos a
                    where a.nro_documento = g.nro_documento
                      and a.fecha = g.fecha
                      and a.cod_usuario = g.cod_usuario
                      and a.hora = g.hora
                      and a.nro_cuenta is not null
                      and exists
                    (select b.nro_cuenta
                             from LC_CTA_CAMBIOS b
                            where a.nro_cuenta = b.nro_cuenta)
                    group by a.nro_cuenta)
               end)
         group by a.fecha, a.hora;
      exception
        when others then
          g_fecha := null;
          g_hora  := null;
      end;
    end if;
    if v_cod_persona is null then
      v_cod_persona := p_cod_persona;
    end if;
  
    if v_nro_cuenta is not null or v_cod_persona is not null then
      if fug_obt_pardinamico('CUE_CLI_FORMULARIO') = 'CUE' then
        -- por cuenta y por persona
        if (instr(',' || v_cod_tra_formularios || ',',
                  ',' || p_cod_transaccion || ',') > 0) then
          pr_act_cli_persona(g_fecha, g_hora);
        elsif (instr(',' || v_cod_tra_personas || ',', -- la búsqueda se hará solo por el código de personas:
                     ',' || p_cod_transaccion || ',') > 0) then
          pr_act_personas(g_fecha, g_hora);
        else
          -- procesar normalmente
          if fug_obt_pardinamico('CLI_CUE_DIA_MENSUAL') = 'D' then
            begin
              select a.*
                into r_acu
                from cj_acu_imp_transacciones a
               where (a.nro_cuenta = v_nro_cuenta or v_nro_cuenta is null)
                 and a.fecha = g_fecha
                 and a.hora = g_hora
                 and a.cod_transaccion = p_cod_transaccion
                 and a.fecha = v_fec_actual
                 and (instr(',' || v_cod_tra_formularios || ',',
                            ',' || a.cod_transaccion || ',') = 0); -- se utiliza este filtro para que estire cuentas distintas a las cuentas del banco.-;
            exception
              when others then
                r_acu := null;
            end;
            if r_acu.nro_cuenta is not null then
              update cj_acu_imp_transacciones a --actualizamos solo el primer registro
                 set a.impreso = 'R'
               where a.nro_cuenta = r_acu.nro_cuenta
                 and a.hora = r_acu.hora
                 and a.fecha = r_acu.fecha;
              update cj_acu_imp_transacciones a --actualizamos todos los registros involucrados
                 set a.impreso = 'N'
               where a.nro_cuenta = r_acu.nro_cuenta
                 and a.fec_modificacion = r_acu.fec_modificacion;
            end if;
          
          elsif fug_obt_pardinamico('CLI_CUE_DIA_MENSUAL') = 'M' then
            begin
              select *
                into r_acu
                from cj_acu_imp_transacciones a
               where (a.nro_cuenta = v_nro_cuenta or v_nro_cuenta is null)
                 and a.fecha = g_fecha
                 and a.hora = g_hora
                 and a.cod_transaccion = p_cod_transaccion
                 and a.fecha = v_fec_actual
                 and (instr(',' || v_cod_tra_formularios || ',',
                            ',' || a.cod_transaccion || ',') = 0); -- se utiliza este filtro para que estire cuentas distintas a las cuentas del banco.-;
            exception
              when others then
                r_acu := null;
            end;
          
            if r_acu.nro_cuenta is not null then
              update cj_acu_imp_transacciones a --actualizamos solo el primer registro
                 set a.impreso = 'R'
               where a.nro_cuenta = r_acu.nro_cuenta
                 and a.hora = r_acu.hora
                 and a.fecha = r_acu.fecha;
              update cj_acu_imp_transacciones a --actualizamos todos los registros involucrados
                 set a.impreso = 'N'
               where a.nro_cuenta = r_acu.nro_cuenta
                 and a.fec_modificacion = r_acu.fec_modificacion;
              update cj_acu_imp_transacciones_his b --actualizamos todos los registros de la tabla histórico
                 set b.impreso = 'N'
               where b.nro_cuenta = r_acu.nro_cuenta
                 and b.fec_modificacion = r_acu.fec_modificacion
                 and b.fecha >= v_pri_dia_habil;
            end if;
          end if;
        end if;
      
        -- Se  verifica si hay que imprimir el formulario, pero por cliente:
      elsif fug_obt_pardinamico('CUE_CLI_FORMULARIO') = 'CLI' then
        if (instr(',' || v_cod_tra_formularios || ',',
                  ',' || p_cod_transaccion || ',') > 0) then
          pr_act_cli_persona(g_fecha, g_hora);
        elsif (instr(',' || v_cod_tra_personas || ',', -- si la búsqueda se hará solo por el código de personas:
                     ',' || p_cod_transaccion || ',') > 0) then
          pr_act_personas(g_fecha, g_hora);
        else
          -- procesar normalmente
          if fug_obt_pardinamico('CLI_CUE_DIA_MENSUAL') = 'D' then
            --buscamos diariamente:
            begin
              select a.*
                into r_acu
                from cj_acu_imp_transacciones a
               where a.cod_persona = v_cod_persona
                 and a.fecha = g_fecha
                 and a.hora = g_hora
                 and a.cod_transaccion = p_cod_transaccion
                 and a.fecha = v_fec_actual
                 and (instr(',' || v_cod_tra_formularios || ',',
                            ',' || a.cod_transaccion || ',') = 0); -- se utiliza este filtro para que estire cuentas distintas a las cuentas del banco.-;
            exception
              when others then
                r_acu := null;
            end;
            if r_acu.cod_persona is not null then
              update cj_acu_imp_transacciones a --actualizamos solo el primer registro
                 set a.impreso = 'R'
               where a.cod_persona = v_cod_persona
                 and a.hora = r_acu.hora
                 and a.fecha = r_acu.fecha;
              update cj_acu_imp_transacciones a --actualizamos todos los registros involucrados
                 set a.impreso = 'N'
               where a.cod_persona = v_cod_persona
                 and a.fec_modificacion = r_acu.fec_modificacion;
            end if;
          
          elsif fug_obt_pardinamico('CLI_CUE_DIA_MENSUAL') = 'M' then
            begin
              select *
                into r_acu
                from cj_acu_imp_transacciones a
               where a.cod_persona = v_cod_persona
                 and a.fecha = g_fecha
                 and a.hora = g_hora
                 and a.cod_transaccion = p_cod_transaccion
                 and a.fecha = v_fec_actual
                 and (instr(',' || v_cod_tra_formularios || ',',
                            ',' || a.cod_transaccion || ',') = 0); -- se utiliza este filtro para que estire cuentas distintas a las cuentas del banco.-;
            exception
              when others then
                r_acu := null;
            end;
            if r_acu.nro_cuenta is not null then
              update cj_acu_imp_transacciones a --actualizamos solo el primer registro
                 set a.impreso = 'R'
               where a.cod_persona = v_cod_persona
                 and a.hora = r_acu.hora
                 and a.fecha = r_acu.fecha;
              update cj_acu_imp_transacciones a --actualizamos todos los registros involucrados
                 set a.impreso = 'N'
               where a.cod_persona = v_cod_persona
                 and a.fec_modificacion = r_acu.fec_modificacion;
              update cj_acu_imp_transacciones_his b --actualizamos todos los registros de la tabla histórico
                 set b.impreso = 'N'
               where b.cod_persona = v_cod_persona
                 and b.fec_modificacion = r_acu.fec_modificacion
                 and b.fecha >= v_pri_dia_habil;
            end if;
          end if;
        end if;
      end if;
    end if;
  end pr_rev_formularios;

  /* Proceso Principal */
BEGIN
  IF updating THEN
    IF :new.estado = 'A' THEN
      -- CROGEFIT-3: JUANMA-20/04/2015:
      pr_rev_formularios(:new.fecha,
                         :new.cod_persona,
                         :new.nro_cuenta,
                         :new.cod_tra_padre,
                         :new.nro_documento);
    END IF;
  END IF;
END;
/

