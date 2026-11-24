create or replace procedure it.prt_gen_not_vto_tarjetas is
  v_tar_dias_not ge_par_dinamicos.val_parametro%type;
  v_actual       ge_calendarios.fec_actual%type;
  -- Vencimiento de TC
  -- Informar que se está por vencer el pago de la TC
  -- Tres días antes del vencimiento de pago
  cursor c_not is
    select fec_vto_pago,
           fec_cierre,
           tc.nro_cuenta,
           cod_persona,
           nvl(tc.sal_facturar, 0) + nvl(tc.sal_financiado, 0) +
           nvl(tc.sal_facturado, 0) + nvl(tc.sal_cuo_pendientes, 0) mto_deu_total
      from ta_sal_cierres tc, ge_cta_clientes cc
     where tc.nro_cuenta = cc.nro_cuenta(+)
       and (fec_vto_pago - v_tar_dias_not) = v_actual
       and fec_cierre =
           (select max(fec_cierre)
              from ta_sal_cierres tc2
             where tc2.nro_cuenta = tc.nro_cuenta)
       and relacion = 'P'
       and cc.cod_persona not in (1)
       and (nvl(tc.sal_facturar, 0) + nvl(tc.sal_financiado, 0) +
           nvl(tc.sal_facturado, 0) + nvl(tc.sal_cuo_pendientes, 0)) > 0;

  --  variables parametrizadas
  v_tip_eve_tarjetas ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('TIP_EVE_TARJETAS');
  v_cod_tip_evento   bw_not_tip_eventos.cod_tip_evento%type := 56;
  -- variables
  v_cod_persona ge_cta_clientes.cod_persona%type;
  v_nro_cuenta  ge_cta_clientes.nro_cuenta%type;
  v_cod_evento  bw_not_eventos.cod_evento%type;
  v_suscripto   varchar2(1);
  v_sus_evento  varchar2(1);
  v_template    bw_not_tip_eventos.template%type;
  v_mensaje     varchar2(140);
  v_titulo      bw_not_tip_eventos.titulo%type;
  v_result      number(3);
  v_result1     number(3);
  v_telefono    ba_telefonos.telefono%type;
  v_det_error   varchar2(4000);
  v_genero      ba_per_fisicas.cod_sexo%type;
begin

  begin
    pre_ini_aplicacion;
    pae_cnf.g_cod_modulo := 1;
  end;
  -- obtiene template
  v_result1 := paw_not.fu_obt_not_template(v_tip_eve_tarjetas, v_template);

  if v_result1 <> 0 then
    v_det_error := 'Error al obtener template del evento Vencimiento de pago minimo de TC: ' ||
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
    v_det_error := 'Error al obtener Titulo del evento Vencimiento de pago minimo de TC: ' ||
                   v_tip_eve_tarjetas || ', codigo tipo evento: ' ||
                   v_cod_tip_evento;
    raise_application_error(-20000, v_det_error);
  end if;

  v_tar_dias_not := fug_obt_pardinamico('TAR_DIAS_NOT');
  v_actual       := pag_cal.fu_obt_fec_actual(5);

  for reg in c_not loop
  
    v_cod_persona := reg.cod_persona;
    v_nro_cuenta  := reg.nro_cuenta;
    v_suscripto   := 'N';
    v_sus_evento  := 'N';
    v_genero      := null;
    -- obtiene genero
    begin
      select cod_sexo
        into v_genero
        from ba_per_fisicas
       where cod_persona = v_cod_persona;
    exception
      when others then
        v_genero := 'M';
    end;
    -- utiliza en el template para diferenciar por genero al cliente, Ej Para estar tranquilo/a
    if v_genero = 'M' then
      v_genero := 'o';
    else
      v_genero := 'a';
    end if;
  
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
        v_titulo := utl_lms.format_message(v_titulo, v_tar_dias_not, 0, 5);
      
        v_mensaje := utl_lms.format_message(v_template,
                                            trim(to_char(reg.mto_deu_total,
                                                         '999G999G999G999')),
                                            v_genero,
                                            0,
                                            5);
        v_result  := paw_not.fu_ins_mensaje(v_cod_tip_evento,
                                            'ITGF',
                                            v_mensaje,
                                            v_titulo,
                                            '3',
                                            v_cod_persona,
                                            v_nro_cuenta,
                                            sysdate,
                                            'S');
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
        v_titulo := utl_lms.format_message(v_titulo, v_tar_dias_not, 0, 5);
      
        v_mensaje := utl_lms.format_message(v_template,
                                            trim(to_char(reg.mto_deu_total,
                                                         '999G999G999G999')),
                                            v_genero,
                                            0,
                                            5);
      
        v_result := paw_not.fu_ins_mensaje(v_cod_tip_evento,
                                           'ITGF',
                                           v_mensaje,
                                           v_titulo,
                                           '3',
                                           v_cod_persona,
                                           v_nro_cuenta,
                                           sysdate,
                                           'S');
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
      v_titulo := utl_lms.format_message(v_titulo, v_tar_dias_not, 0, 5);
    
      v_mensaje := utl_lms.format_message(v_template,
                                          trim(to_char(reg.mto_deu_total,
                                                       '999G999G999G999')),
                                          v_genero,
                                          0,
                                          5);
    
      v_result := paw_not.fu_ins_mensaje(v_cod_tip_evento,
                                         'ITGF',
                                         v_mensaje,
                                         v_titulo,
                                         '3',
                                         v_cod_persona,
                                         v_nro_cuenta,
                                         sysdate,
                                         'S');
      if v_result = 0 then
        commit;
      end if;
    
    end if;
  
  end loop;
exception
  when others then
    prg_ins_log_programas('PRT_GEN_NOT_VTO_TARJETAS',
                          substr('5-Error: ' || sqlerrm, 1, 4000),
                          v_cod_persona,
                          v_nro_cuenta);
    raise_application_error(-20000, v_det_error);
end;
/

