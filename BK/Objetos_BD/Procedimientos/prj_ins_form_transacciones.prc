create or replace procedure it.prj_ins_form_transacciones(p_nro_cuenta      in ge_movimientos.nro_cuenta%type,
                                                       p_cod_persona     in ge_movimientos.cod_persona%type,
                                                       p_cod_modulo      in ge_movimientos.cod_modulo%type,
                                                       p_cod_transaccion in ge_movimientos.cod_transaccion%type,
                                                       p_cod_usuario     in ge_movimientos.cod_usuario%type,
                                                       p_fecha           in ge_movimientos.fecha%type,
                                                       p_hora            in ge_movimientos.hora%type,
                                                       p_cod_moneda      in ge_movimientos.cod_moneda%type,
                                                       p_monto           in ge_movimientos.monto%type,
                                                       p_impreso         in cj_acu_imp_transacciones.impreso%type default 'N', -- si enviamos "N" solo insertará, si enviamos "S" insertará e imprimirá.
                                                       p_insertar        in varchar2 default 'S',                              --en algunos casos no se deberá insertar, solo actualizar
                                                       p_reimpresion     in varchar2 default 'N') is                           --solo para los casos de reimpresion de comprobantes(110-120)
  -- Insertamos las transacciones que son de caja en la tabla cj_acu_imp_transacciones
  v_nro_cuenta      ge_movimientos.nro_cuenta%type          := p_nro_cuenta;
  v_cod_persona     ge_movimientos.cod_persona%type;
  v_cod_modulo      ge_movimientos.cod_modulo%type          := p_cod_modulo;
  v_cod_transaccion ge_movimientos.cod_transaccion%type     := p_cod_transaccion;
  v_cod_usuario     ge_movimientos.cod_usuario%type         := p_cod_usuario;
  v_fecha           ge_movimientos.fecha%type               := p_fecha;
  v_hora            ge_movimientos.hora%type                := p_hora;
  v_cod_moneda      ge_movimientos.cod_moneda%type          := p_cod_moneda;
  v_cod_tra_formularios varchar2(2000)                      := fug_obt_pardinamico('COD_TRA_FORMULARIOS'); --242,243,NNN
  v_cod_tra_personas    varchar2(2000)                      := fug_obt_pardinamico('COD_TRA_FOR_PERSONAS'); --245, NNN
  v_fec_actual      ge_movimientos.fecha%type               := pag_cal.fu_obt_fec_actual(1); --fecha actual del sistema
  v_pri_dia_habil   ge_movimientos.fecha%type               := pag_cal.fu_obt_fec_pri_dia_mes_habil(1); --primer día hábil del mes actual
  v_existe          varchar2(1) := 'N';                                     


  procedure prj_act_est_impresion(p_nro_cuenta in ge_movimientos.nro_cuenta%type,
                                  p_cod_persona in ge_movimientos.cod_persona%type,
                                  p_cod_transaccion in ge_movimientos.cod_transaccion%type) is
    v_cod_persona ge_movimientos.cod_persona%type  := p_cod_persona;
    v_nro_cuenta  ge_movimientos.nro_cuenta%type   := p_nro_cuenta;
    v_existe      varchar2(1);
    -- Con este procedimiento actualizamos los estados de las impresiones
  begin
      begin -- verificamos si es o no cuenta de cambios
        select 'S'
          into v_existe
          from LC_CTA_CAMBIOS b
         where b.nro_cuenta = v_nro_cuenta;
      exception
        when others then
          v_existe := 'N';
      end;
  
  
   if nvl(p_reimpresion,'N') = 'S' and (nvl(v_existe,'N') = 'S') then  
     --cuando es reimpresion y a la vez sea una cuenta de cambios (solo se actualizará un registro)
      if fug_obt_pardinamico('CLI_CUE_DIA_MENSUAL') = 'D' then
         update cj_acu_imp_transacciones a
          set a.impreso = 'S'
          where (a.nro_cuenta = v_nro_cuenta or v_nro_cuenta is null)
          and   (a.cod_persona = p_cod_persona or p_cod_persona is null)
          and   a.hora = p_hora
          and   a.cod_usuario = p_cod_usuario
          and   a.fecha = p_fecha
          and   nvl(a.impreso,'N') <> 'R';
      elsif fug_obt_pardinamico('CLI_CUE_DIA_MENSUAL') = 'M' then
        update cj_acu_imp_transacciones a
          set a.impreso = 'S'
          where (a.nro_cuenta = v_nro_cuenta or v_nro_cuenta is null)
          and   (a.cod_persona = p_cod_persona or p_cod_persona is null)
          and   a.hora = p_hora
          and   a.cod_usuario = p_cod_usuario
          and   a.fecha = p_fecha
          and   nvl(a.impreso,'N') <> 'R';
          if SQL%NOTFOUND then
             update cj_acu_imp_transacciones_his a
              set a.impreso = 'S'
              where (a.nro_cuenta = v_nro_cuenta or v_nro_cuenta is null)
              and   (a.cod_persona = p_cod_persona or p_cod_persona is null)
              and   a.hora = p_hora
              and   a.cod_usuario = p_cod_usuario
              and   a.fecha = p_fecha
              and   nvl(a.impreso,'N') <> 'R';
          end if;
     end if;
   else
    if fug_obt_pardinamico('CUE_CLI_FORMULARIO') = 'CUE' then
       /***********************************************************************************************************************************************************
         -En caso que esté incluido en el parámerto dinámico "COD_TRA_FORMULARIOS":
          cuando la busqueda se haga por cuenta finalmente se buscará por "cliente y por cuenta", se utiliza cod_cliente y cod_persona(el principal de la cuenta)
         -Si no está incluido en el parámerto dinámico "COD_TRA_FORMULARIOS":
          cuando la busqueda se haga por cliente finalmente se hará la busqueda por cliente.
       *************************************************************************************************************************************************************/
             if (instr(',' || v_cod_tra_formularios || ',',
                   ',' || p_cod_transaccion || ',') > 0)  then
                   if fug_obt_pardinamico('CLI_CUE_DIA_MENSUAL') = 'D' then
                          begin
                            update cj_acu_imp_transacciones a
                               set a.impreso = 'S'
                             where a.nro_cuenta = v_nro_cuenta
                               and a.cod_persona = v_cod_persona
                               and a.fecha = v_fec_actual
                               and a.hora = (case when(select b.cod_modulo -- evitamos la cuenta sea de cambios propia del banco
                                                      from ge_cuentas b
                                                     where b.nro_cuenta = a.nro_cuenta--'0107010003'
                                                     group by b.cod_modulo) <> 7 then
                                                        a.hora
                                                     else
                                                        p_hora
                                                     end)
                               and nvl(a.impreso, 'N') = 'N';
                          exception
                            when others then
                              dbms_output.put_line('Error al tratar de actualizar estado de impresion (1)' ||
                                                   sqlerrm);
                          end;
                    elsif fug_obt_pardinamico('CLI_CUE_DIA_MENSUAL') = 'M' then
                          begin
                            update cj_acu_imp_transacciones a
                               set a.impreso = 'S'
                             where a.nro_cuenta = v_nro_cuenta
                               and a.cod_persona = v_cod_persona
                               and a.fecha = v_fec_actual
                               and a.hora = (case when(select b.cod_modulo -- evitamos la cuenta sea de cambios propia del banco
                                                      from ge_cuentas b
                                                     where b.nro_cuenta = a.nro_cuenta--'0107010003'
                                                     group by b.cod_modulo) <> 7 then
                                                        a.hora
                                                     else
                                                        p_hora
                                                     end)
                               and nvl(a.impreso, 'N') = 'N';
                          exception
                            when others then
                              dbms_output.put_line('Error al tratar de actualizar estado de impresion (2)' ||
                                                   sqlerrm);
                          end;
                          begin
                            update cj_acu_imp_transacciones_his a
                               set a.impreso = 'S'
                             where a.nro_cuenta = v_nro_cuenta
                               and a.cod_persona = v_cod_persona
                               and a.fecha >= v_pri_dia_habil
                               and a.hora = (case when(select b.cod_modulo -- evitamos la cuenta sea de cambios propia del banco
                                                      from ge_cuentas b
                                                     where b.nro_cuenta = a.nro_cuenta--'0107010003'
                                                     group by b.cod_modulo) <> 7 then
                                                        a.hora
                                                     else
                                                        p_hora
                                                     end)
                               and nvl(a.impreso, 'N') = 'N';
                          exception
                            when others then
                              dbms_output.put_line('Error al tratar de actualizar estado de impresion (3)' ||
                                                   sqlerrm);
                          end;
                     else
                       null;
                    end if;

             elsif  (instr(',' || v_cod_tra_personas || ',',
                   ',' || p_cod_transaccion || ',') > 0)  then
                   if fug_obt_pardinamico('CLI_CUE_DIA_MENSUAL') = 'D' then
                          begin
                            update cj_acu_imp_transacciones a
                               set a.impreso = 'S'
                             where a.cod_persona = v_cod_persona
                               and a.fecha = v_fec_actual
                               and a.hora = (case when(select b.cod_modulo -- evitamos la cuenta sea de cambios propia del banco
                                                      from ge_cuentas b
                                                     where b.nro_cuenta = a.nro_cuenta--'0107010003'
                                                     group by b.cod_modulo) <> 7 then
                                                        a.hora
                                                     else
                                                        p_hora
                                                     end)
                               and nvl(a.impreso, 'N') = 'N';
                          exception
                            when others then
                              dbms_output.put_line('Error al tratar de actualizar estado de impresion (4)' ||
                                                   sqlerrm);
                          end;
                    elsif fug_obt_pardinamico('CLI_CUE_DIA_MENSUAL') = 'M' then
                          begin
                            update cj_acu_imp_transacciones a
                               set a.impreso = 'S'
                             where a.cod_persona = v_cod_persona
                               and a.fecha = v_fec_actual
                               and a.hora = (case when(select b.cod_modulo -- evitamos la cuenta sea de cambios propia del banco
                                                      from ge_cuentas b
                                                     where b.nro_cuenta = a.nro_cuenta--'0107010003'
                                                     group by b.cod_modulo) <> 7 then
                                                        a.hora
                                                     else
                                                        p_hora
                                                     end)
                               and nvl(a.impreso, 'N') = 'N';
                          exception
                            when others then
                              dbms_output.put_line('Error al tratar de actualizar estado de impresion (5)' ||
                                                   sqlerrm);
                          end;

                          begin
                            update cj_acu_imp_transacciones_his a
                               set a.impreso = 'S'
                             where a.cod_persona = v_cod_persona
                               and a.fecha >= v_pri_dia_habil
                               and a.hora = (case when(select b.cod_modulo -- evitamos la cuenta sea de cambios propia del banco
                                                      from ge_cuentas b
                                                     where b.nro_cuenta = a.nro_cuenta--'0107010003'
                                                     group by b.cod_modulo) <> 7 then
                                                        a.hora
                                                     else
                                                        p_hora
                                                     end)
                               and nvl(a.impreso, 'N') = 'N';
                          exception
                            when others then
                              dbms_output.put_line('Error al tratar de actualizar estado de impresion (6)' ||
                                                   sqlerrm);
                          end;
                     else
                       null;
                    end if;
             else
                   if fug_obt_pardinamico('CLI_CUE_DIA_MENSUAL') = 'D' then
                          --actualizamos diariamente:
                          begin
                            update cj_acu_imp_transacciones a
                               set a.impreso = 'S'
                             where a.nro_cuenta = v_nro_cuenta
                               and a.fecha = v_fec_actual
                               and nvl(a.impreso, 'N') = 'N'
                               and a.hora = (case when(select b.cod_modulo -- evitamos la cuenta sea de cambios propia del banco
                                                      from ge_cuentas b
                                                     where b.nro_cuenta = a.nro_cuenta--'0107010003'
                                                     group by b.cod_modulo) <> 7 then
                                                        a.hora
                                                     else
                                                        p_hora
                                                     end)
                               and (instr(',' || v_cod_tra_formularios || ',',
                                   ',' || a.cod_transaccion || ',') = 0); -- se utiliza este filtro para que estire cuentas distintas a las cuentas del banco.-
                          exception
                            when others then
                              dbms_output.put_line('Error al tratar de actualizar estado de impresion (7)' ||
                                                   sqlerrm);
                          end;
                    elsif fug_obt_pardinamico('CLI_CUE_DIA_MENSUAL') = 'M' then
                           begin
                            update cj_acu_imp_transacciones a
                               set a.impreso = 'S'
                             where a.nro_cuenta = v_nro_cuenta
                               and a.fecha = v_fec_actual
                               and nvl(a.impreso, 'N') = 'N'
                               and a.hora = (case when(select b.cod_modulo -- evitamos la cuenta sea de cambios propia del banco
                                                      from ge_cuentas b
                                                     where b.nro_cuenta = a.nro_cuenta--'0107010003'
                                                     group by b.cod_modulo) <> 7 then
                                                        a.hora
                                                     else
                                                        p_hora
                                                     end)
                               and (instr(',' || v_cod_tra_formularios || ',',
                                   ',' || a.cod_transaccion || ',') = 0); -- se utiliza este filtro para que estire cuentas distintas a las cuentas del banco.-
                          exception
                            when others then
                              dbms_output.put_line('Error al tratar de actualizar estado de impresion (8)' ||
                                                   sqlerrm);
                          end;
                          begin
                            update cj_acu_imp_transacciones_his a
                               set a.impreso = 'S'
                             where a.nro_cuenta = v_nro_cuenta
                               and a.fecha >= v_pri_dia_habil
                               and nvl(a.impreso, 'N') = 'N'
                               and a.hora = (case when(select b.cod_modulo -- evitamos la cuenta sea de cambios propia del banco
                                                      from ge_cuentas b
                                                     where b.nro_cuenta = a.nro_cuenta--'0107010003'
                                                     group by b.cod_modulo) <> 7 then
                                                        a.hora
                                                     else
                                                        p_hora
                                                     end)
                               and (instr(',' || v_cod_tra_formularios || ',',
                                   ',' || a.cod_transaccion || ',') = 0); -- se utiliza este filtro para que estire distintas a las cuentas del banco.-
                          exception
                            when others then
                              dbms_output.put_line('Error al tratar de actualizar estado de impresion (9)' ||
                                                   sqlerrm);
                          end;
                    else
                      null;
                    end if;
              end if;

 -- Si todo está parametrizado por cliente:

    elsif fug_obt_pardinamico('CUE_CLI_FORMULARIO') = 'CLI' then
           /***********************************************************************************************************************************************************
         -En caso que esté incluido en el parámerto dinámico "COD_TRA_FORMULARIOS":
          cuando la busqueda se haga por cuenta finalmente se buscará por "cliente y por cuenta", se utiliza cod_cliente y cod_persona(el principal de la cuenta)
         -Si no está incluido en el parámerto dinámico "COD_TRA_FORMULARIOS":
          cuando la busqueda se haga por cliente finalmente se hará la busqueda por cliente.
       *************************************************************************************************************************************************************/
             if (instr(',' || v_cod_tra_formularios || ',',
                   ',' || p_cod_transaccion || ',') > 0)  then
                   if fug_obt_pardinamico('CLI_CUE_DIA_MENSUAL') = 'D' then
                          begin
                            update cj_acu_imp_transacciones a
                               set a.impreso = 'S'
                             where a.nro_cuenta = v_nro_cuenta
                               and a.cod_persona = v_cod_persona
                               and a.fecha = v_fec_actual
                               and nvl(a.impreso, 'N') = 'N';
                          exception
                            when others then
                              dbms_output.put_line('Error al tratar de actualizar estado de impresion (10)' ||
                                                   sqlerrm);
                          end;
                    elsif fug_obt_pardinamico('CLI_CUE_DIA_MENSUAL') = 'M' then
                          begin
                            update cj_acu_imp_transacciones a
                               set a.impreso = 'S'
                             where a.nro_cuenta = v_nro_cuenta
                               and a.cod_persona = v_cod_persona
                               and a.fecha = v_fec_actual
                               and nvl(a.impreso, 'N') = 'N';
                          exception
                            when others then
                              dbms_output.put_line('Error al tratar de actualizar estado de impresion (11)' ||
                                                   sqlerrm);
                          end;
                          begin
                            update cj_acu_imp_transacciones_his a
                               set a.impreso = 'S'
                             where a.nro_cuenta = v_nro_cuenta
                               and a.cod_persona = v_cod_persona
                               and a.fecha >= v_pri_dia_habil
                               and nvl(a.impreso, 'N') = 'N';
                          exception
                            when others then
                              dbms_output.put_line('Error al tratar de actualizar estado de impresion (12)' ||
                                                   sqlerrm);
                          end;
                     else
                       null;
                    end if;

             elsif  (instr(',' || v_cod_tra_personas || ',',
                   ',' || p_cod_transaccion || ',') > 0)  then
                   if fug_obt_pardinamico('CLI_CUE_DIA_MENSUAL') = 'D' then
                          begin
                            update cj_acu_imp_transacciones a
                               set a.impreso = 'S'
                             where a.cod_persona = v_cod_persona
                               and a.fecha = v_fec_actual
                               and nvl(a.impreso, 'N') = 'N';
                          exception
                            when others then
                              dbms_output.put_line('Error al tratar de actualizar estado de impresion (13)' ||
                                                   sqlerrm);
                          end;
                    elsif fug_obt_pardinamico('CLI_CUE_DIA_MENSUAL') = 'M' then
                          begin
                            update cj_acu_imp_transacciones a
                               set a.impreso = 'S'
                             where a.cod_persona = v_cod_persona
                               and a.fecha = v_fec_actual
                               and nvl(a.impreso, 'N') = 'N';
                          exception
                            when others then
                              dbms_output.put_line('Error al tratar de actualizar estado de impresion (14)' ||
                                                   sqlerrm);
                          end;

                          begin
                            update cj_acu_imp_transacciones_his a
                               set a.impreso = 'S'
                             where a.cod_persona = v_cod_persona
                               and a.fecha >= v_pri_dia_habil
                               and nvl(a.impreso, 'N') = 'N';
                          exception
                            when others then
                              dbms_output.put_line('Error al tratar de actualizar estado de impresion (15)' ||
                                                   sqlerrm);
                          end;
                     else
                       null;
                    end if;
             else
                   if fug_obt_pardinamico('CLI_CUE_DIA_MENSUAL') = 'D' then
                          --actualizamos diariamente:
                          begin
                            update cj_acu_imp_transacciones a
                               set a.impreso = 'S'
                             where a.cod_persona = v_cod_persona
                               and a.fecha = v_fec_actual
                               and nvl(a.impreso, 'N') = 'N'
                               and (instr(',' || v_cod_tra_formularios || ',',
                                   ',' || a.cod_transaccion || ',') = 0); -- se utiliza este filtro para que estire cuentas distintas a las cuentas del banco.-
                          exception
                            when others then
                              dbms_output.put_line('Error al tratar de actualizar estado de impresion (16)' ||
                                                   sqlerrm);
                          end;
                    elsif fug_obt_pardinamico('CLI_CUE_DIA_MENSUAL') = 'M' then
                           begin
                            update cj_acu_imp_transacciones a
                               set a.impreso = 'S'
                             where a.cod_persona = v_cod_persona
                               and a.fecha = v_fec_actual
                               and nvl(a.impreso, 'N') = 'N'
                               and (instr(',' || v_cod_tra_formularios || ',',
                                   ',' || a.cod_transaccion || ',') = 0); -- se utiliza este filtro para que estire cuentas distintas a las cuentas del banco.-
                          exception
                            when others then
                              dbms_output.put_line('Error al tratar de actualizar estado de impresion (17)' ||
                                                   sqlerrm);
                          end;
                          begin
                            update cj_acu_imp_transacciones_his a
                               set a.impreso = 'S'
                             where a.cod_persona = v_cod_persona
                               and a.fecha >= v_pri_dia_habil
                               and nvl(a.impreso, 'N') = 'N'
                               and (instr(',' || v_cod_tra_formularios || ',',
                                   ',' || a.cod_transaccion || ',') = 0); -- se utiliza este filtro para que estire distintas a las cuentas del banco.-
                          exception
                            when others then
                              dbms_output.put_line('Error al tratar de actualizar estado de impresion (18)' ||
                                                   sqlerrm);
                          end;
                    else
                      null;
                    end if;
              end if;
     else
        null;
     end if;
   end if;
  end prj_act_est_impresion;
-- inicio del programa principal
begin
   if (instr(',' || v_cod_tra_formularios || ',',
             ',' || p_cod_transaccion || ',') > 0) or
       (instr(',' || v_cod_tra_personas || ',',
       ',' || p_cod_transaccion || ',') > 0)   then
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
    begin
      begin
        select 'S'
          into v_existe
          from LC_CTA_CAMBIOS b
         where b.nro_cuenta = p_nro_cuenta
         group by b.nro_cuenta;
      exception
        when others then
          v_existe := 'N';
      end;
      if v_existe = 'N' then
        v_cod_persona := fug_obt_cli_principal(p_nro_cuenta);
      else
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
      end if;
    end;
  end if;
  
  -- Insertamos solo las transaccion especificadas de la parametrizacion
  if (instr(',' || v_cod_tra_formularios || ',',
            ',' || p_cod_transaccion     || ',') > 0)  then 
                   
    if (v_cod_persona is not null) and (v_nro_cuenta is not null) then
      if nvl(p_insertar, 'S') = 'S' then
          begin
            insert into cj_acu_imp_transacciones
              (nro_cuenta,
               cod_persona,
               cod_modulo,
               cod_transaccion,
               cod_usuario,
               fecha,
               hora,
               cod_moneda,
               monto,
               impreso)
            values
              (v_nro_cuenta,
               v_cod_persona,
               v_cod_modulo,
               v_cod_transaccion,
               v_cod_usuario,
               v_fecha,
               v_hora,
               v_cod_moneda,
               p_monto,
               p_impreso);
          exception
            when others then
              Raise_application_error(-20001,
                                      'Error al insertar transacciones ' ||
                                      'Persona: ' || v_cod_persona || ' Hora: ' ||
                                      v_hora || '  ' || sqlerrm);
          end;
      end if;
      if p_impreso = 'S' then
        prj_act_est_impresion(v_nro_cuenta, v_cod_persona, v_cod_transaccion);
      end if;
    else
      if v_cod_persona is null then
         null;
      else
        Raise_application_error(-20003,
                                'No se ha encontrado Principal de la cuenta: ' ||
                                v_nro_cuenta);
      end if;
    end if;
  end if;
exception
  when others then
    Raise_application_error(-20000,
                            'Error al insertar en tabla cj_acu_imp_transacciones ' ||
                            sqlerrm);
end prj_ins_form_transacciones;
/

