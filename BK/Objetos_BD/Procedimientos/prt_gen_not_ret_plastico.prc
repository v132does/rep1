create or replace procedure it.prt_gen_not_ret_plastico is
  v_actual ge_calendarios.fec_actual%type;
  -- Retiro de plástico
  -- Informar que tiene una tarjeta para retirar y utilizar.
  -- Cuando puede retirarlo, al tener una oferta disponible.
  cursor c_not is
    select a.cod_persona, cta.nro_cuenta nro_cta
      from ba_personas            p,
           ge_cta_clientes        a,
           ba_tab_dat_adicionales t,
           ah_cta_vistas          cta
     where p.cod_persona = a.cod_persona
       and p.cod_persona = t.referencia
       and a.nro_cuenta = cta.nro_cuenta
       and cta.estado not in ('B', 'C', 'P','I') -- se ecluye  (b)bloqueo cuenta, (c)cancelada, (p)pend.cancelacion, i(inactivo)
       and a.relacion = 'P'
       and t.tab_relacion = 'BA_PERSONAS'
       and t.parametro = 'CELULAR_ONBOARDING' -- valida que haya hecho onb
       and exists (select 1
              from ba_per_ima_documentos b
             where p.cod_persona = b.cod_persona
               and b.cod_tip_documento = 64) -- valida que tenga tip doc 64 
       and exists
     (select 1
              from it.ta_lin_pre_aprobado t -- valida que tenga oferta vigente de TC
             where p.cod_persona = t.cod_persona
               and v_actual between t.fec_ini_oferta and t.fec_fin_oferta
               and estado in ('C', 'G'));

  --  variables parametrizadas
  v_tip_eve_tarjetas ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('TIP_EVE_RP');
  v_cod_tip_evento   bw_not_tip_eventos.cod_tip_evento%type := 58;
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
  v_pla_gratis  varchar2(1);
  v_motivo      varchar2(4000);
begin
  --
  begin
    pre_ini_aplicacion;
    pae_cnf.g_cod_modulo := 1;
  end;
  v_actual := pag_cal.fu_obt_fec_actual(5);
  -- obtiene template
  v_result1 := paw_not.fu_obt_not_template(v_tip_eve_tarjetas, v_template);

  if v_result1 <> 0 then
    v_det_error := 'Error al obtener template del evento Retiro de Plastico: ' ||
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
    v_det_error := 'Error al obtener Titulo del evento Retiro de Plastico: ' ||
                   v_tip_eve_tarjetas || ', codigo tipo evento: ' ||
                   v_cod_tip_evento;
    raise_application_error(-20000, v_det_error);
  end if;

  for reg in c_not loop
  
    v_cod_persona := reg.cod_persona;
    v_nro_cuenta  := reg.nro_cta;
    v_suscripto   := 'N';
    v_sus_evento  := 'N';
    v_pla_gratis  := 'N';
    -- valida si tiene tarjeta gratis
    it.prg_val_emi_duo_car_plasticos(v_cod_persona, v_pla_gratis, v_motivo);
  
    if nvl(v_pla_gratis, 'N') = 'S' then
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
          v_titulo := v_titulo;
        
          v_mensaje := v_template;
        
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
          v_titulo := v_titulo;
        
          v_mensaje := v_template;
        
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
        v_titulo := v_titulo;
      
        v_mensaje := v_template;
      
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
    end if;
  end loop;

exception
  when others then
    prg_ins_log_programas('prt_gen_not_ret_plastico',
                          substr('5-Error: ' || sqlerrm, 1, 4000),
                          v_cod_persona,
                          v_nro_cuenta);
    raise_application_error(-20000, v_det_error);
end;
/

