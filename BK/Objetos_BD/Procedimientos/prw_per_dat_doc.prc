CREATE OR REPLACE PROCEDURE IT.prw_per_dat_doc(p_cod_circuito      IN wf_circuitos.cod_circuito%TYPE,
                                               p_tip_accion        IN VARCHAR2,
                                               p_cod_tip_documento IN ba_per_ima_documentos.cod_tip_documento%TYPE,
                                               p_observacion       IN ba_per_ima_documentos.observacion%TYPE) IS
  v_persona          varchar2(15);
  v_wf_error         varchar2(2000);
  v_can_cir_pen      number;
  v_cod_usuario      wf_circuitos.usu_insercion%TYPE; 
  v_retorno          varchar(4000);
  v_vto_documento    ba_personas.fec_vto_documento%type;
  v_cod_error        number;
  v_men_error        varchar2(4000);
  v_cta_ahorro       ge_cuentas.nro_cuenta%type;
  v_cta_alcancia     ge_cuentas.nro_cuenta%type;
  v_nro_tarjeta      ah_tar_debitos.nro_tarjeta%type;
  v_cod_tip_circuito wf_circuitos.cod_tip_circuito%type;
  v_cod_causal ge_per_inhibidas.cod_causa%TYPE := fug_obt_pardinamico('COD_CAU_EXC') ; 
  v_per_correo ba_tab_dat_adicionales.val_parametro%type;

  v_cod_cau_alt_riesgo ge_per_inhibidas.cod_causa%type := fug_obt_pardinamico('COD_CAU_ALT_RIESGO',
                                                                              null,
                                                                              null,
                                                                              null,
                                                                              null);
  v_cod_cau_med_riesgo ge_per_inhibidas.cod_causa%type := fug_obt_pardinamico('COD_CAU_MED_RIESGO',
                                                                              null,
                                                                              null,
                                                                              null,
                                                                              null);

  v_cod_cau_pep          ge_per_inhibidas.cod_causa%type := fug_obt_pardinamico('COD_CAU_PEP',
                                                                                null,
                                                                                null,
                                                                                null,
                                                                                null);
  v_cod_cau_blo_alt_per  ge_per_inhibidas.cod_causa%type := fug_obt_pardinamico('COD_CAU_BLO_ALT_PER',
                                                                                null,
                                                                                null,
                                                                                null,
                                                                                null);                                                                                 
  v_cod_pai_nacionalidad ba_per_fisicas.cod_pai_nacionalidad%type;
  v_est_civil            ba_per_fisicas.est_civil%type;
  /*circuitos pendientes correspondiente a la persona*/
  cursor c_cir_ped_persona(p_persona in wf_circuitos.cod_persona%type) is
    select w.cod_circuito, w.cod_tip_circuito, w.estado
      from wf_circuitos w
     where estado not in ('C', 'F')
       and cod_persona = p_persona
       and cod_circuito <> p_cod_circuito;
  /*Circuitos dependientes pendientes relacionados a la persona*/
  cursor c_cir_per_pen_dependientes(p_persona in wf_circuitos.cod_persona%type) is
    select w.cod_circuito, w.cod_tip_circuito, w.estado
      from wf_circuitos w
     where estado not in ('C', 'F')
       and cod_persona = p_persona
       and cod_tip_circuito in (38, 39, 37, 40, 41, 43, 54)
       and cod_circuito <> p_cod_circuito;

  cursor c_cta_onboarding(p_persona in wf_circuitos.cod_persona%type) is
    select v.nro_cuenta, v.cod_modulo, v.cod_modalidad
      from ge_cta_clientes cc, ah_cta_vistas v
     where cc.nro_cuenta = v.nro_cuenta
       and cc.relacion = 'P'
       and v.estado not in ('T', 'C')
       and v.cod_canal = 26
       and cc.cod_persona = p_persona;
BEGIN
  begin
    pre_ini_aplicacion;
    pae_cnf.g_cod_modulo := 1;
  end;
  select cod_persona, usu_insercion, cod_tip_circuito
    into v_persona, v_cod_usuario, v_cod_tip_circuito
    from wf_circuitos w
   where cod_circuito = p_cod_circuito;

  begin
    select count(*)
      into v_can_cir_pen
      from wf_circuitos
     where estado not in ('C', 'F')
       and cod_tip_circuito in (38, 39, 37, 40, 41, 43, 54)
       and cod_persona = v_persona
       and cod_circuito <> p_cod_circuito;
  exception
    when others then
      v_can_cir_pen := 0;
  end;

  begin
    select p.fec_vto_documento, f.cod_pai_nacionalidad, f.est_civil
      into v_vto_documento, v_cod_pai_nacionalidad, v_est_civil
      from ba_personas p, ba_per_fisicas f
     where P.cod_persona = v_persona
       and p.cod_persona = f.cod_persona;
  exception
    when no_data_found then
      raise_application_error(-20000,
                              'Persona ' || v_persona || ' no existe');
  end;

  if p_tip_accion = 'A' then
    if v_cod_tip_circuito = 37 then
      --cedula frente
      if to_char(v_vto_documento, 'dd/mm/yyyy') = '01/01/2050' then
        raise_application_error(-20000,
                                'Se debe actualizar la fecha de vencimiento de la cédula del cliente cód.:' ||
                                v_persona);
      end if;
      if nvl(v_cod_pai_nacionalidad, 999) = 999 then
        raise_application_error(-20000,
                                'Se debe actualizar la nacionalidad el cliente cód.:' ||
                                v_persona);
      end if;
      if nvl(v_est_civil, 'X') = 'X' then
        raise_application_error(-20000,
                                'Se debe actualizar el estado civil del cliente cód.:' ||
                                v_persona);
      end if;
      v_retorno := pag_pla.fu_ins_ba_per_ima_documentos(v_persona,
                                                        null,
                                                        125,
                                                        v_vto_documento,
                                                        null,
                                                        p_observacion);
      if nvl(v_retorno, 'N') = 'S' then
        --cedula reverso
        v_retorno := pag_pla.fu_ins_ba_per_ima_documentos(v_persona,
                                                          null,
                                                          126,
                                                          v_vto_documento,
                                                          null,
                                                          p_observacion);
      end if;
    elsif v_cod_tip_circuito = 39 then
      --fotografia
      v_retorno := pag_pla.fu_ins_ba_per_ima_documentos(v_persona,
                                                        null,
                                                        127,
                                                        v_vto_documento,
                                                        null,
                                                        p_observacion);
    elsif v_cod_tip_circuito = 43 then
      if v_cod_cau_alt_riesgo = '0' or v_cod_cau_med_riesgo = '0' then
        raise_application_error(-20000,
                                'Verificar configuracion de los parametros dinamicos COD_CAU_ALT_RIESGO y/o COD_CAU_MED_RIESGO');
      else
        update ge_per_inhibidas i
           set i.estado = 'D'
         where i.estado = 'I'
           and i.cod_causa in (v_cod_cau_alt_riesgo, v_cod_cau_med_riesgo)
           and i.cod_persona = v_persona;

        if sql%rowcount = 0 then
          raise_application_error(-20000,
                                  'No se encontró persona inhibida');
        end if;
      end if;
    elsif v_cod_tip_circuito = 44 then
      if nvl(v_cod_cau_pep, '0') = '0' then
        raise_application_error(-20000,
                                'Verificar configuracion del parametro dinamico COD_CAU_PEP');
      else
        update ge_per_inhibidas i
           set i.estado = 'D'
         where i.estado = 'I'
           and i.cod_causa in (v_cod_cau_pep)
           and i.cod_persona = v_persona;

        if sql%rowcount = 0 then
          raise_application_error(-20000,
                                  'No se encontró persona inhibida');
        end if;
      end if;
    elsif v_cod_tip_circuito = 38 then
      if nvl(v_cod_cau_blo_alt_per, '0') = '0' then
        raise_application_error(-20000,
                                'Verificar configuracion del parametro dinamico COD_CAU_BLO_ALT_PER');
      else
        update ge_per_inhibidas i
           set i.estado = 'D'
         where i.estado = 'I'
           and i.cod_causa = v_cod_cau_blo_alt_per
           and i.cod_persona = v_persona;

        if sql%rowcount = 0 then
          raise_application_error(-20000,
                                  'No se encontró persona inhibida');
        end if;
      end if;
    end if;

    if nvl(v_retorno, 'N') != 'S' and v_cod_tip_circuito in (37, 39) then
      raise_application_error(-20000,
                              'Error al insertar datos de la imagen');
    end if;

    if nvl(v_can_cir_pen, 0) = 0 then
      update ba_personas
         set est_verificacion    = 'V',
             cod_usu_verificador = user,
             fec_verificacion    = pag_cal.fu_obt_fec_actual(1),
             obs_verificacion    = p_observacion
       where cod_persona = v_persona;
      v_cod_error := null;
      v_men_error := null;
      it.paa_alc.PR_CRE_CTA_AHORRO(v_persona,
                                   'GS',
                                   'V',
                                   v_cod_error,
                                   v_men_error,
                                   v_cta_ahorro,
                                   v_cta_alcancia,
                                   v_nro_tarjeta);
      if nvl(v_cod_error, 0) <> 0 then
        raise_application_error(-20000,
                                'Error al Crear cuenta de ahorro ' ||
                                v_men_error);
      end if;
    end if;

  elsif p_tip_accion in ('R', 'C') then
     PRG_GEN_INH_PER(v_persona,
                         v_cod_causal,
                         'PERSONA INHIBIDA LISTA ONBOARDING',
                         'I');  
    begin
      update ba_personas
         set est_verificacion    = 'R',
             cod_usu_verificador = user,
             fec_verificacion    = pag_cal.fu_obt_fec_actual(1),
             obs_verificacion    = p_observacion
       where cod_persona = v_persona;
    exception
      when others then
        raise_application_error(-20000,
                                'No se puedo rechazar Persona: ' ||
                                v_persona || ' - '||sqlerrm);
    end;
    if v_cod_tip_circuito = 37 then
      begin
        /*Se elimina parametros onboarding*/
        delete from ba_tab_dat_adicionales
         where tab_relacion = 'BA_PERSONAS'
           and parametro in ('CELULAR_ONBOARDING', 'EMAIL_ONBOARDING')
           and referencia = v_persona;

        delete from ba_tab_dat_adicionales
         where tab_relacion = 'GE_CLIENTES'
           and parametro = 'GEN_COD_USU_PLATAFORMA'
           and referencia = v_persona;
      exception
        when others then
          raise_application_error(-20000,
                                  'Error al finalizar eliminar parámetros onboarding');
      end;

      for rec in c_cir_ped_persona(v_persona) loop
        /*Se finalizan las tareas pendientes*/
        v_wf_error := paw_cir.FU_CAN_CIR_PENDIENTES(rec.cod_tip_circuito,
                                                    v_persona);
        if v_wf_error <> 0 then
          raise_application_error(-20000,
                                  'Error al finalizar Tarea de Workflow');
        end if;
      end loop;
      v_cod_error := null;
      v_men_error := null;
      /*Bloquea cuentas creadas en el onbarding*/
      for c in c_cta_onboarding(v_persona) loop
        IT.PRG_BLO_CTA_ONBOARDING(c.nro_cuenta,
                                 122,
                                 p_observacion,
                                 'N',
                                 v_cod_error,
                                 v_men_error);
        if nvl(v_cod_error, 0) != 0 then
          raise_application_error(-20000,
                                  'No se pudo bloquear la cuenta ' ||
                                  c.nro_cuenta || ' ' || v_men_error);
        end if;
      end loop;

      v_wf_error := it.paw_cir.FU_FIN_CIR_PEN_COD(37,
                                                  p_cod_circuito,
                                                  p_tip_accion);
      if v_wf_error <> 0 then
        raise_application_error(-20000,
                                'Error al finalizar Tarea de Workflow');
      end if;

    end if;

    if v_cod_tip_circuito != 37 then
      for reg in c_cir_per_pen_dependientes(v_persona) loop
        v_wf_error := paw_cir.FU_CAN_CIR_PENDIENTES(reg.cod_tip_circuito,
                                                    v_persona);
        if v_wf_error <> 0 then
          raise_application_error(-20000,
                                  'Error al finalizar Tarea de Workflow tipo ' ||
                                  reg.cod_tip_circuito || ' circuito: ' ||
                                  reg.cod_circuito);
        end if;
      end loop;
    end if;

    v_wf_error := it.paw_cir.FU_FIN_CIR_PEN_COD(v_cod_tip_circuito,
                                                p_cod_circuito,
                                                p_tip_accion);
    if v_wf_error <> 0 then
      raise_application_error(-20000,
                              'Error al finalizar Tarea de Workflow');
    end if;

    if nvl(v_wf_error, 0) = 0 then
      begin
        v_per_correo := fue_tab_dat_adicional('BA_PERSONAS',
                                              'EMAIL_ONBOARDING',
                                              v_persona);
      exception
        when others then
          v_per_correo := null;
      end;
      if v_per_correo is not null then
        v_cod_error := null;
        v_men_error := null;
        pag_pla.pr_env_not_onboarding(v_persona,
                                      null,
                                      v_per_correo,
                                      3,
                                      v_cod_error,
                                      v_men_error);
      end if;
    end if;
  end if;
END;
/

