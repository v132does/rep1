create or replace procedure it.prp_gen_not_vto_prestamos is
  v_pre_dias_not ge_par_dinamicos.val_parametro%type;

  --cursor de prestamos con vencimientos a X dias
  cursor c_not is
    select c.cod_persona,
           p.nro_cuenta,
           p.fec_vencimiento,
           p.nro_cuota,
           pc.can_cuotas
      from pr_cuotas p
     inner join ge_cta_clientes c
        on p.nro_cuenta = c.nro_cuenta
     inner join pr_cta_prestamos pc
        on p.nro_cuenta = pc.nro_cuenta
     where trunc(p.fec_vencimiento) = trunc(sysdate + v_pre_dias_not)
       and p.estado = 'C'
       and c.relacion = 'P'
       and c.cod_persona in
           (select referencia
              from ba_tab_dat_adicionales c
             where parametro = 'CELULAR_ONBOARDING');

  --  variables parametrizadas
  v_tip_eve_prestamos ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('TIP_EVE_PRESTAMOS'); --PRECUOVEN
  v_cod_tip_evento    bw_not_tip_eventos.cod_tip_evento%type := fug_obt_pardinamico('COD_TIP_EVENTO'); --55
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
  --
  begin
    pre_ini_aplicacion;
    pae_cnf.g_cod_modulo := 1;
  end;
  -- obtiene template
  v_result1 := paw_not.fu_obt_not_template(v_tip_eve_prestamos, v_template);

  if v_result1 <> 0 then
    v_det_error := 'Error al obtener template del evento Vencimiento de prestamos : ' ||
                   v_tip_eve_prestamos || ', codigo tipo evento: ' ||
                   v_cod_tip_evento;
    raise_application_error(-20000, v_det_error);
  end if;
  -- obtiene titulo
  begin
    select titulo
      into v_titulo
      from bw_not_tip_eventos
     where cod_tip_evento = v_tip_eve_prestamos;
  exception
    when others then
      v_titulo := null;
  end;
  v_pre_dias_not := fug_obt_pardinamico('PRE_DIAS_NOT');

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
        v_mensaje := utl_lms.format_message(v_template,
                                            v_genero,
                                            trim(to_char(reg.nro_cuota,
                                                         '999')),
                                            trim(to_char(reg.can_cuotas,
                                                         '999')),
                                            substr(v_nro_cuenta,
                                                   length(v_nro_cuenta) - 3),
                                            0,
                                            5);
      
        v_titulo := utl_lms.format_message(v_titulo,
                                           lower(rtrim(TO_char(sysdate +
                                                               v_pre_dias_not,
                                                               'DD "de" MONTH'))),
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
        v_mensaje := utl_lms.format_message(v_template,
                                            v_genero,
                                            trim(to_char(reg.nro_cuota,
                                                         '999')),
                                            trim(to_char(reg.can_cuotas,
                                                         '999')),
                                            substr(v_nro_cuenta,
                                                   length(v_nro_cuenta) - 3),
                                            0,
                                            5);
      
        v_titulo := utl_lms.format_message(v_titulo,
                                           lower(rtrim(TO_char(sysdate +
                                                               v_pre_dias_not,
                                                               'DD "de" MONTH'))),
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
      v_mensaje := utl_lms.format_message(v_template,
                                          v_genero,
                                          trim(to_char(reg.nro_cuota, '999')),
                                          trim(to_char(reg.can_cuotas, '999')),
                                          substr(v_nro_cuenta,
                                                 length(v_nro_cuenta) - 3),
                                          0,
                                          5);
    
      v_titulo := utl_lms.format_message(v_titulo,
                                         lower(rtrim(TO_char(sysdate +
                                                             v_pre_dias_not,
                                                             'DD "de" MONTH'))),
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
    prg_ins_log_programas('PRP_GEN_NOT_VTO_PRESTAMOS',
                          substr('5-Error: ' || sqlerrm, 1, 4000),
                          v_cod_persona,
                          v_nro_cuenta);
    raise_application_error(-20000, v_det_error);
end;
/

