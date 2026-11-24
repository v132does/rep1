create or replace trigger it.tb_wf_circuitos
  before insert on wf_circuitos
  for each row
declare
  v_nro_documento    ba_personas.nro_documento%type;
  v_nom_completo     ba_personas.nom_completo%type;
  v_nro_telefono     ba_tab_dat_adicionales.val_parametro%type;
  v_dir_correo       ba_tab_dat_adicionales.val_parametro%type;
  v_cod_circuito     wf_circuitos.cod_tip_circuito%type;
  v_dir_cor_destino  ge_par_dinamicos.val_parametro%type;
  v_act_notificacion varchar2(1) := 'N';
  v_cir_notificacion varchar2(100) := fug_obt_pardinamico('COD_CIR_NOT_ONB');
  v_can_existe number;  
begin
  v_act_notificacion := nvl(fug_obt_pardinamico('HAB_NOT_CIR_ONB'), 'N');
  v_cod_circuito     := nvl(:new.cod_tip_circuito, -1);
  v_dir_cor_destino  := fug_obt_pardinamico('DIR_COR_TAR_ONB');
  if v_act_notificacion = 'S' then
    --if instr(v_cir_notificacion, v_cod_circuito) > 0 then
    if (instr(v_cir_notificacion,','||v_cod_circuito||',')) > 0 then
      begin
        select a.nro_documento, a.nom_completo
          into v_nro_documento, v_nom_completo
          from ba_personas a
         where a.cod_persona = :new.cod_persona;
      exception
        when no_data_found then
          v_nro_documento := null;
        when others then
          v_nro_documento := null;
      end;
      if v_nro_documento is not null then
        v_nro_telefono := fue_tab_dat_adicional('BA_PERSONAS',
                                                'CELULAR_ONBOARDING',
                                                :new.cod_persona);
        v_dir_correo   := fue_tab_dat_adicional('BA_PERSONAS',
                                                'EMAIL_ONBOARDING',
                                                :new.cod_persona);        
        
        -- Control para envio de ticket zendesk
        begin
          select count(*)
            into v_can_existe
            from wf_circuitos a
           where a.cod_persona = :new.cod_persona
             and (instr(v_cir_notificacion,','||a.cod_tip_circuito||',')) > 0
             and rownum = 1;
        exception
          when no_data_found then
            v_can_existe := 0;
          when others then
            v_can_existe := 0;
        end;
        if nvl(v_can_existe,0)=0 then
              begin
                it_mail.mail(fug_obt_dir_correo,
                             v_dir_cor_destino,
                             --'Tarea de WF Circuito ' || :new.cod_tip_circuito ||
                             'Tarea de WF Circuito ' ||
                             ' Onboarding Cliente CI: ' || v_nro_documento,
                             'Código/Nombre de Persona: ' || :new.cod_persona ||
                             ' - ' || v_nom_completo || chr(10) ||
                             'Número de CI: ' || v_nro_documento || chr(10) ||
                             'Teléfono: ' || v_nro_telefono || chr(10) ||
                             'Correo: ' || v_dir_correo || chr(10) );
                             --'Tipo de Tarea: ' || :new.cod_tip_circuito || ' - ' ||
                             --:new.descripcion);
              exception
                when others then
                  null;
              end;
      end if ;      
            
      end if;
    end if;
  end if;
end;
/
