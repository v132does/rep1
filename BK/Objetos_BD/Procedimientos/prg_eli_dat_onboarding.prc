create or replace procedure it.prg_eli_dat_onboarding(p_cod_persona in ba_personas.cod_persona%type) is
  v_cod_error   number;
  v_det_error   varchar2(4000);
  v_lugar       varchar2(1000);
  v_cod_persona ba_personas.cod_persona%type;
  v_customer_id varchar2(50);

begin
  begin
    pre_ini_aplicacion;
    pae_cnf.g_cod_modulo := 1;
  end;
  -- valida que persona sea valida
  begin
    select referencia
      into v_cod_persona
      from ba_tab_dat_adicionales c
     where referencia = p_cod_persona;
  exception
    when no_data_found then
      v_cod_persona := null;
    when too_many_rows then
      select referencia
        into v_cod_persona
        from ba_tab_dat_adicionales c
       where referencia = p_cod_persona
         and trunc(c.fec_insercion) =
             (select max(trunc(fec_insercion))
                from ba_tab_dat_adicionales tt
               where tt.referencia = c.referencia)
         and rownum = 1;

    when others then
      v_cod_persona := null;
  end;

  if v_cod_persona is not null then

    begin
      -- elimina datos adicionales
      delete from ba_tab_dat_adicionales
       where referencia = p_cod_persona
         and parametro in ('CELULAR_ONBOARDING',
                           'EMAIL_ONBOARDING',
                           'GEN_COD_USU_PLATAFORMA');


      if sql%notfound then
        v_cod_error := 1;
        v_lugar     := 'Elimina datos BA_TAB_DAT_ADICIONALES.';
        v_det_error := sqlerrm ||
                       ' No se proceso ningun registro para la persona ' ||
                       p_cod_persona;
        it.prg_ins_log_programas('BA_TAB_DAT_ADICIONALES',
                                 v_lugar || ' - ' || v_det_error,
                                 p_cod_persona,
                                 null);
      end if;
    exception
      when others then
        v_cod_error := 2;
        v_lugar     := 'When others. Elimina datos BA_TAB_DAT_ADICIONALES.';
        v_det_error := sqlerrm ||
                       ' No se proceso ningun registro para la persona ' ||
                       p_cod_persona;
        it.prg_ins_log_programas('PRG_ELI_DAT_ONBOARDING',
                                 v_lugar || ' - ' || v_det_error,
                                 p_cod_persona,
                                 null);
    end;
    -- elimina Worflow
    /* begin

      delete from wf_cir_tareas c
       where c.cod_circuito in
             (select c.cod_circuito
                from wf_circuitos c
               where c.cod_persona = p_cod_persona);

      if sql%notfound then
        v_cod_error := 1;
        v_lugar     := 'Elimina datos WF_CIR_TAREAS.';
        v_det_error := 'No se proceso ningun registro para la persona ' ||
                       p_cod_persona;
        it.prg_ins_log_programas('PRG_ELI_DAT_ONBOARDING',
                                 v_lugar || ' - ' || v_det_error,
                                 p_cod_persona,
                                 null);
      end if;

      delete from wf_circuitos c where c.cod_persona = p_cod_persona;

      if sql%notfound then
        v_cod_error := 1;
        v_lugar     := 'Elimina datos WF_CIRCUITOS.';
        v_det_error := 'No se proceso ningun registro para la persona ' ||
                       p_cod_persona;
        it.prg_ins_log_programas('PRG_ELI_DAT_ONBOARDING',
                                 v_lugar || ' - ' || v_det_error,
                                 p_cod_persona,
                                 null);
      end if;
    exception
      when others then
        v_cod_error := 2;
        v_lugar     := 'When others. Elimina datos WF_CIRCUITOS - WF_CIR_TAREAS.';
        v_det_error := 'No se proceso ningun registro para la persona ' ||
                       p_cod_persona;
        it.prg_ins_log_programas('PRG_ELI_DAT_ONBOARDING',
                                 v_lugar || ' - ' || v_det_error,
                                 p_cod_persona,
                                 null);
    end;*/

    --- AUTH (esquema de la base intermedia) 
    -- obtenemos ID
    begin
      select id
        into v_customer_id
        from auth.auth_user@uenoprod
       where code_person = p_cod_persona;
    exception
      when no_data_found then
        v_customer_id := null;
      when too_many_rows then
        select id
          into v_customer_id
          from auth.auth_user@uenoprod
         where code_person = p_cod_persona
           and rownum = 1;
      when others then
        v_customer_id := null;
    end;

    if v_customer_id is not null then
      begin

        delete from auth.auth_user_sesion@uenoprod
         where user_id = v_customer_id;

        -- borra detalle
        delete from auth.auth_device_user@uenoprod
         where user_id = v_customer_id;

        delete from auth.auth_unsuccessful_login_user@uenoprod
         where user_id = v_customer_id;

        delete from auth.auth_password_history@uenoprod
         where user_id = v_customer_id;

        delete from auth.auth_user@uenoprod where id = v_customer_id;

        -- borra cabecera
        delete from auth.auth_device_user_app@uenoprod
         where user_app_id = v_customer_id;

        delete from auth.auth_session_app@uenoprod
         where user_app_id = v_customer_id;
         
        delete from auth.auth_user_device_push_token@uenoprod where user_id = v_customer_id;      

        delete from auth.auth_unsuccessful_login_user_app@uenoprod
         where user_app_id = v_customer_id;

        delete from auth.auth_user_app@uenoprod where id = v_customer_id;      
        
        
        if sql%notfound then
          v_cod_error := 3;
          v_lugar     := 'Elimina datos esquema AUTH';
          v_det_error := sqlerrm ||
                         ' No se proceso ningun registro para la persona ' ||
                         p_cod_persona;
          it.prg_ins_log_programas('PRG_ELI_DAT_ONBOARDING',
                                   v_lugar || ' - ' || v_det_error,
                                   p_cod_persona,
                                   null);
        end if;
      exception
        when others then
          v_cod_error := 4;
          v_lugar     := 'When others. Elimina datos esquema AUTH.';
          v_det_error := sqlerrm ||
                         ' No se proceso ningun registro para la persona ' ||
                         p_cod_persona;
          it.prg_ins_log_programas('PRG_ELI_DAT_ONBOARDING',
                                   v_lugar || ' - ' || v_det_error,
                                   p_cod_persona,
                                   null);
      end;
    else
      v_cod_error := 5;
      v_lugar     := 'Valida persona en esquema AUTH.';
      v_det_error := sqlerrm || ' La persona ' || p_cod_persona ||
                     ' no es valida en el esquema AUTH.';
      it.prg_ins_log_programas('PRG_ELI_DAT_ONBOARDING',
                               v_lugar || ' - ' || v_det_error,
                               p_cod_persona,
                               null);
    end if;

  else
    v_cod_error := 6;
    v_lugar     := 'Valida persona.';
    v_det_error := sqlerrm || ' La persona ' || p_cod_persona ||
                   ' no es valida.';
    it.prg_ins_log_programas('PRG_ELI_DAT_ONBOARDING',
                             v_lugar || ' - ' || v_det_error,
                             p_cod_persona,
                             null);
  end if;

  if nvl(v_cod_error, 0) != 0 then
    rollback;
  else
    commit;
  end if;

exception
  when others then
    v_lugar     := 'When others del proceso PRG_ELI_DAT_ONBOARDING.';
    v_det_error := sqlerrm;
    it.prg_ins_log_programas('PRG_ELI_DAT_ONBOARDING',
                             v_lugar || ' - ' || v_det_error,
                             p_cod_persona,
                             null);
    rollback;

end;
/
