create or replace procedure it.prp_act_ofe_che_roga is

  v_fec_actual ge_calendarios.fec_actual%type := pag_cal.fu_obt_fec_actual(6);

  --cursor principal
  cursor c_che_roga is
    select a.nro_oferta,
           a.nro_doc_solicitante,
           a.cod_per_solicitante,
           a.nro_doc_invitado,
           a.cod_per_invitado,
           a.estado
      from pr_pre_che_roga a
     where a.estado not in ('N')
       and v_fec_actual between a.fec_oferta and a.fec_vencimiento;

  -- variables
  v_cod_per_soli ba_personas.cod_persona%type;
  v_cod_per_invi ba_personas.cod_persona%type;
  v_cod_error    varchar2(5);
  v_cod_inh_err  number := 0;
  v_det_error varchar2(4000);
  v_doc_persona     varchar2(1); --tiene doc
  v_pro_activo      varchar2(1); --tiene cta activa
  v_onboarding      varchar2(1); --hizo onboarding
  v_doc_inv_persona varchar2(1);
  v_pro_inv_activo  varchar2(1);
  v_inv_onboarding  varchar2(1);
  v_nom_completo    ba_personas.nom_completo%type;
  v_pri_nombre      ba_per_fisicas.pri_nombre%type;
  v_seg_nombre      ba_per_fisicas.seg_nombre%type;
  v_pri_apellido    ba_per_fisicas.pri_apellido%type;
  v_seg_apellido    ba_per_fisicas.seg_apellido%type;
  v_per_inh_soli    varchar2(1);
  v_per_inh_invi    varchar2(1);
  v_est_oferta      pr_pre_che_roga.estado%type;
  v_nro_doc_soli    pr_pre_che_roga.nro_doc_solicitante%type;
  v_nro_doc_invi    pr_pre_che_roga.nro_doc_invitado%type;
  v_sol_enc_cto     varchar2(1); -- solicitante se encuentra correcto
  v_inv_enc_cto     varchar2(1); -- invitado se encuentra correcto
begin
  --
  begin
    pre_ini_aplicacion;
    pae_cnf.g_cod_modulo := 1;
  end;
  --
  for reg in c_che_roga loop
    v_sol_enc_cto     := 'N';
    v_inv_enc_cto     := 'N';
    v_per_inh_soli    := 'N';
    v_per_inh_invi    := 'N';
    v_doc_persona     := 'N';
    v_pro_activo      := 'N';
    v_onboarding      := 'N';
    v_doc_inv_persona := 'N';
    v_pro_inv_activo  := 'N';
    v_inv_onboarding  := 'N';
    v_est_oferta      := reg.estado;
    v_nro_doc_soli    := reg.nro_doc_solicitante;
    v_nro_doc_invi    := reg.nro_doc_invitado;
    v_cod_per_soli    := reg.cod_per_solicitante;
    v_cod_per_invi    := reg.cod_per_invitado;
    v_cod_error       := 0;
  
    if nvl(v_cod_error, 0) = 0 then
      -- Tiene Documento, Hizo Onb y tiene cta activa, solicitante
      it.prg_cli_onboarding(v_nro_doc_soli,
                            v_doc_persona,
                            v_pro_activo,
                            v_onboarding);
      -- Tiene Documento, Hizo Onb y tiene cta activa, invitado
      it.prg_cli_onboarding(v_nro_doc_invi,
                            v_doc_inv_persona,
                            v_pro_inv_activo,
                            v_inv_onboarding);
      -- Recupera datos solicitante 
      if v_cod_per_soli is null then
        if (v_doc_persona = 'S' and v_pro_activo = 'S' and
           v_onboarding = 'S') then
          v_sol_enc_cto  := 'S';
          v_cod_per_soli := it.fue_obt_cod_persona(v_nro_doc_soli);
          begin
            select f.pri_nombre,
                   f.seg_nombre,
                   f.pri_apellido,
                   f.seg_apellido,
                   p.nom_completo
              into v_pri_nombre,
                   v_seg_nombre,
                   v_pri_apellido,
                   v_seg_apellido,
                   v_nom_completo
              from ba_per_fisicas f, ba_personas p
             where f.cod_persona = v_cod_per_soli
               and f.cod_persona = p.cod_persona;
          exception
            when no_data_found then
              v_pri_nombre   := null;
              v_pri_apellido := null;
          end;
          -- Verifica inhibicion del solicitante
          if nvl(v_cod_error, 0) = 0 and
             (v_pri_nombre is not null and v_pri_apellido is not null) then
            v_cod_inh_err := null;
          
            if nvl(fug_cau_inh_por_nombre(v_nom_completo, null), 'X') = 'X' then
              -- Si la persona no tiene coincidencia el campo EST_VERIFICACION debe ser Sin Coincidencias.
              it.prg_per_par_listas(v_pri_nombre,
                                    v_seg_nombre,
                                    v_pri_apellido,
                                    v_seg_apellido,
                                    v_cod_inh_err,
                                    v_det_error);
            
              if nvl(v_cod_inh_err, 0) != 0 then
                v_per_inh_soli := 'S';
              else
                v_per_inh_soli := 'N';
              end if;
            end if;
          end if;
          -- Update codigo persona solicitante
          if v_cod_per_soli is not null and v_per_inh_soli = 'N' then
            begin
              update pr_pre_che_roga ss
                 set ss.cod_per_solicitante = v_cod_per_soli
               where ss.nro_oferta = reg.nro_oferta;
              commit;
            exception
              when others then
                raise_application_error(-20000, v_det_error || SQLERRM);
            end;
          end if;
        end if;
      end if;
      -- Recupera datos Invitado
      if v_cod_per_invi is null then
        if (v_doc_inv_persona = 'S' and v_pro_inv_activo = 'S' and
           v_inv_onboarding = 'S') then
          v_inv_enc_cto  := 'S';
          v_cod_per_invi := it.fue_obt_cod_persona(v_nro_doc_invi);
          begin
            select f.pri_nombre,
                   f.seg_nombre,
                   f.pri_apellido,
                   f.seg_apellido,
                   p.nom_completo
              into v_pri_nombre,
                   v_seg_nombre,
                   v_pri_apellido,
                   v_seg_apellido,
                   v_nom_completo
              from ba_per_fisicas f, ba_personas p
             where f.cod_persona = v_cod_per_invi
               and f.cod_persona = p.cod_persona;
          exception
            when no_data_found then
              v_pri_nombre   := null;
              v_pri_apellido := null;
          end;
          -- Verifica inhibicion invitado
          if nvl(v_cod_error, 0) = 0 and
             (v_pri_nombre is not null and v_pri_apellido is not null) then
            v_cod_inh_err := null;
          
            if nvl(fug_cau_inh_por_nombre(v_nom_completo, null), 'X') = 'X' then
              -- Si la persona no tiene coincidencia el campo EST_VERIFICACION debe ser Sin Coincidencias.
              it.prg_per_par_listas(v_pri_nombre,
                                    v_seg_nombre,
                                    v_pri_apellido,
                                    v_seg_apellido,
                                    v_cod_inh_err,
                                    v_det_error);
            
              if nvl(v_cod_inh_err, 0) != 0 then
                v_per_inh_invi := 'S';
              else
                v_per_inh_invi := 'N';
              end if;
            end if;
          end if;
          -- Update codigo persona invitada 
          if v_cod_per_invi is not null and v_per_inh_invi = 'N' then
            begin
              update pr_pre_che_roga ss
                 set ss.cod_per_invitado = v_cod_per_invi
               where ss.nro_oferta = reg.nro_oferta;
              commit;
            exception
              when others then
                raise_application_error(-20000, v_det_error || SQLERRM);
            end;
          end if;
        end if;
      end if;
      -- Update Estado de Oferta
      -- Siempre en Pendiente porque los estados cambian por el importador
     /* if (v_cod_per_soli is not null and v_cod_per_invi is not null and
         v_per_inh_soli = 'N' and v_per_inh_invi = 'N') then
        begin
          update pr_pre_che_roga ss
             set ss.estado = 'P'
           where ss.nro_oferta = reg.nro_oferta;
        exception
          when others then
            raise_application_error(-20000, v_det_error || SQLERRM);
        end;
        v_cod_error := 0;
      elsif v_cod_per_soli is not null and v_nro_doc_invi is null and
            v_per_inh_soli = 'N' then
        -- Update tabla maestra si no tiene invitado y no esta inhibido
        begin
          update pr_pre_che_roga ss
             set ss.estado = 'F'
           where ss.nro_oferta = reg.nro_oferta;
        exception
          when others then
            v_cod_error := 99;
            raise_application_error(-20000, v_det_error || SQLERRM);
        end;
        v_cod_error := 0;
      else
        prg_ins_log_programas('PRP_ACT_OFE_CHE_ROGA',
                              substr('2-Error: ' || sqlerrm, 1, 4000),
                              v_cod_per_soli,
                              null);
        v_cod_error := 99;
      end if;*/
    end if;
  
    if v_cod_error = 0 then
      commit;
    end if;
  
  end loop;
exception
  when others then
    prg_ins_log_programas('PRP_ACT_OFE_CHE_ROGA',
                          substr('5-Error: ' || sqlerrm, 1, 4000),
                          v_cod_per_soli,
                          null);
end;
/

