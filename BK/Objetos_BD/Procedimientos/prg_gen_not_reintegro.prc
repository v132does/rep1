create or replace procedure it.prg_gen_not_reintegro is
  v_actual ge_calendarios.fec_actual%type;
  -- Reintegro de compra.
  -- Informar reintegro de compra en comercios.
  -- En el momento de recibir el reintegro en cuenta.

  cursor c_not is
    select fecha,
           hora,
           cod_usuario,
           mto_reintegro,
           nro_cuenta,
           mto_compra,
           cod_cli_comercio,
           nom_comercio,
           cod_promocion,
           nro_documento3
      from ge_mov_reintegros c
     where c.fecha = v_actual
       and not exists -- verificar que no existe en bw_not_mensajes en la misma fecha para la misma cuenta y nro_documento3
     (select 1
              from bw_not_mensajes s
             where s.nro_cuenta = c.nro_cuenta
               and trunc(s.fec_insercion) = trunc(c.fecha)
               and s.nro_documento3 = c.nro_documento3);

  --  variables parametrizadas
  v_tip_eve_tarjetas ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('TIP_EVE_REINTEGRO');
  v_cod_tip_evento   bw_not_tip_eventos.cod_tip_evento%type := 60;
  -- variables
  v_cod_persona    ge_cta_clientes.cod_persona%type;
  v_nro_cuenta     ge_cta_clientes.nro_cuenta%type;
  v_cod_evento     bw_not_eventos.cod_evento%type;
  v_suscripto      varchar2(1);
  v_sus_evento     varchar2(1);
  v_template       bw_not_tip_eventos.template%type;
  v_mensaje        varchar2(140);
  v_titulo         bw_not_tip_eventos.titulo%type;
  v_result         number(3);
  v_result1        number(3);
  v_telefono       ba_telefonos.telefono%type;
  v_det_error      varchar2(4000);
  v_mto_reintegro  ge_mov_reintegros.mto_reintegro%type;
  v_men_titulo     varchar2(45);
  v_nro_documento3 bw_not_mensajes.nro_documento3%type;
begin
  --
  begin
    pre_ini_aplicacion;
    pae_cnf.g_cod_modulo := 1;
  end;
  -- obtiene template
  v_result1 := paw_not.fu_obt_not_template(v_tip_eve_tarjetas, v_template);

  if v_result1 <> 0 then
    v_det_error := 'Error al obtener template del evento Reintegro de compras: ' ||
                   v_tip_eve_tarjetas || ', codigo tipo evento: ' ||
                   v_cod_tip_evento;
    raise_application_error(-20000, v_det_error);
  end if;

  -- obtiene titulo
  begin
    select titulo
      into v_titulo
      from bw_not_tip_eventos
     where cod_tip_evento = v_tip_eve_tarjetas;
  exception
    when others then
      v_titulo := null;
  end;

  if v_titulo is null then
    v_det_error := 'Error al obtener Titulo del evento  Reintegro de compras: ' ||
                   v_tip_eve_tarjetas || ', codigo tipo evento: ' ||
                   v_cod_tip_evento;
    raise_application_error(-20000, v_det_error);
  end if;

  v_actual        := pag_cal.fu_obt_fec_actual(5);
  v_mto_reintegro := 0;

  for reg in c_not loop
  
    v_nro_cuenta     := reg.nro_cuenta;
    v_suscripto      := 'N';
    v_sus_evento     := 'N';
    v_mto_reintegro  := reg.mto_reintegro;
    v_nro_documento3 := reg.nro_documento3;
    -- obtiene cod_persona
    begin
      select a.cod_persona
        into v_cod_persona
        from ge_cta_clientes a
       where a.nro_cuenta = v_nro_cuenta
         and a.relacion = 'P'
         and rownum = 1;
    exception
      when others then
        v_cod_persona := null;
    end;
    if v_cod_persona is not null then
      --verifica si esta suscripto al servicio de notificaciones
      begin
        select 'S'
          into v_suscripto
          from bw_not_cli_suscriptos s
         where s.cod_persona = v_cod_persona
           and s.activo = 'S';
      exception
        when others then
          v_suscripto := 'N';
      end;
    
      if v_suscripto = 'S' then
        --verifica si esta suscripto al evento
        begin
          select 'S'
            into v_sus_evento
            from bw_not_suscripciones ss
           where ss.cod_persona = v_cod_persona
             and ss.nro_cuenta = v_nro_cuenta
             and ss.cod_evento = v_cod_tip_evento
             and ss.activo = 'S';
        exception
          when others then
            v_sus_evento := 'N';
        end;
      
        if v_sus_evento = 'S' then
          -- insert en bw_not_mensajes
          v_men_titulo := utl_lms.format_message(v_titulo,
                                                 trim(to_char(v_mto_reintegro,
                                                              '999G999G999G999')),
                                                 0,
                                                 5);
        
          v_mensaje := v_template;
        
          v_result := paw_not.fu_ins_mensaje(v_cod_tip_evento,
                                             'ITGF',
                                             v_mensaje,
                                             v_men_titulo,
                                             '3',
                                             v_cod_persona,
                                             v_nro_cuenta,
                                             sysdate,
                                             'S',
                                             v_nro_documento3);
          if v_result = 0 then
            commit;
          end if;
        
        else
          -- obtiene telefono que hizo Onboarding
          begin
            select substr(val_parametro, -10)
              into v_telefono
              from ba_tab_dat_adicionales c
             where referencia = v_cod_persona
               and parametro = 'CELULAR_ONBOARDING';
          exception
            when others then
              -- obtiene telefono de ba_telefonos
              v_telefono := fue_obt_tel_principa(v_cod_persona);
          end;
        
          -- alta al evento
          begin
            insert into bw_not_suscripciones
              (cod_persona, nro_cuenta, cod_evento, activo)
            values
              (v_cod_persona, v_nro_cuenta, v_cod_tip_evento, 'S');
          exception
            when dup_val_on_index then
              update bw_not_suscripciones
                 set activo = 'S'
               where cod_persona = v_cod_persona
                 and nro_cuenta = v_nro_cuenta
                 and cod_evento = v_cod_evento;
          end;
          -- insert en bw_not_mensajes
          v_men_titulo := utl_lms.format_message(v_titulo,
                                                 trim(to_char(v_mto_reintegro,
                                                              '999G999G999G999')),
                                                 0,
                                                 5);
        
          v_mensaje := v_template;
        
          v_result := paw_not.fu_ins_mensaje(v_cod_tip_evento,
                                             'ITGF',
                                             v_mensaje,
                                             v_men_titulo,
                                             '3',
                                             v_cod_persona,
                                             v_nro_cuenta,
                                             sysdate,
                                             'S',
                                             v_nro_documento3);
          if v_result = 0 then
            commit;
          end if;
        
        end if;
      
      else
        -- obtiene telefono que hizo Onboarding
        begin
          select substr(val_parametro, -10)
            into v_telefono
            from ba_tab_dat_adicionales c
           where referencia = v_cod_persona
             and parametro = 'CELULAR_ONBOARDING';
        exception
          when others then
            -- obtiene telefono de ba_telefonos
            v_telefono := fue_obt_tel_principa(v_cod_persona);
        end;
      
        -- alta al servicio de notificaciones 
        begin
          v_result := paw_not.fu_alt_cliente(v_cod_persona,
                                             3, --PUSH
                                             v_telefono,
                                             'ITGF');
        exception
          when others then
            v_det_error := sqlerrm;
            raise_application_error(-20000, v_det_error);
        end;
        -- alta al evento
        begin
          insert into bw_not_suscripciones
            (cod_persona, nro_cuenta, cod_evento, activo)
          values
            (v_cod_persona, v_nro_cuenta, v_cod_tip_evento, 'S');
        exception
          when dup_val_on_index then
            update bw_not_suscripciones
               set activo = 'S'
             where cod_persona = v_cod_persona
               and nro_cuenta = v_nro_cuenta
               and cod_evento = v_cod_evento;
        end;
        -- insert en bw_not_mensajes
        v_men_titulo := utl_lms.format_message(v_titulo,
                                               trim(to_char(v_mto_reintegro,
                                                            '999G999G999G999')),
                                               0,
                                               5);
      
        v_mensaje := v_template;
      
        v_result := paw_not.fu_ins_mensaje(v_cod_tip_evento,
                                           'ITGF',
                                           v_mensaje,
                                           v_men_titulo,
                                           '3',
                                           v_cod_persona,
                                           v_nro_cuenta,
                                           sysdate,
                                           'S',
                                           v_nro_documento3);
        if v_result = 0 then
          commit;
        end if;
      
      end if;
    end if;
  end loop;
exception
  when others then
    prg_ins_log_programas('prg_gen_not_reintegro',
                          substr('5-Error: ' || sqlerrm, 1, 4000),
                          v_cod_persona,
                          v_nro_cuenta);
    raise_application_error(-20000, v_det_error);
end;
/

