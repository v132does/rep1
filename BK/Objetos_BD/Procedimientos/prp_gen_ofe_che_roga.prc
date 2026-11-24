create or replace procedure it.prp_gen_ofe_che_roga is
  --cursor del archivo tmp importado.
  cursor c_che_roga is
    select to_number(a.nro_oferta) nro_oferta,
           a.nro_doc_solicitante,
           a.cod_per_solicitante,
           a.nro_doc_invitado,
           a.cod_per_invitado,
           a.fec_oferta,
           a.fec_vencimiento,
           to_number(a.mto_total) mto_total,
           to_number(a.mto_proyecto) mto_proyecto,
           to_number(a.mto_equipamiento) mto_equipamiento,
           to_number(a.mto_cuota) mto_cuota,
           to_number(a.can_cuotas) can_cuotas,
           upper(a.equipamiento) equipamiento,
           a.cod_moneda,
           a.tip_producto,
           initcap(a.ubi_vivienda) ubi_vivienda,
           a.nom_proyecto,
           a.tip_vivienda,
           a.sub_tip_vivienda,
           a.constructora,
           a.detalle_1,
           a.detalle_2,
           a.detalle_3,
           a.detalle_4,
           a.detalle_5,
           upper(a.estado) estado,
           a.inv_acepto,
           a.nro_solicitud,
           a.dimension,
           a.can_dormitorios,
           to_number(a.mto_garantia) mto_garantia,
           to_number(a.mto_tasacion) mto_tasacion,
           to_number(a.mto_notario) mto_notario,
           to_number(a.mto_adm_gastos) mto_adm_gastos,
           to_number(a.mto_cuo_contruccion) mto_cuo_contruccion,
           initcap(a.pto_equilibrio) pto_equilibrio,
           tipo,
           destino,
           ejecutora,
           to_number(a.mto_total_2) mto_total_2
      from pr_pre_che_roga_tmp a;

  --  Variables parametrizadas
  v_fec_actual        ge_calendarios.fec_actual%type := pag_cal.fu_obt_fec_actual(6);
  v_cod_oficina       ge_par_generales.cod_ofi_matriz%type := fug_obt_ofi_matriz;
  v_cod_rub_economico number := fug_obt_pardinamico('COD_RUB_CHE_ROGA');
  v_cod_modalidad     number := fug_obt_pardinamico('COD_MOD_CHE_ROGA');
  v_cod_oficial       ge_clientes.cod_usu_oficial%TYPE := fug_obt_pardinamico('BWE_COD_USU_OFICIAL');
  v_dir_mail_ofi      ba_personas.dir_correo%type := fug_obt_pardinamico('DIR_MAIL_OPERATIVO');
  v_tip_pro_oficial   it.ba_env_correos.tip_producto%type := fue_obt_val_max_referencia('TIP_MAI_PRODUCTO',
                                                                                        'ENVIOROGA');
  -- Variables
  v_json             long;
  v_can_registro     number;
  v_can_lim_oferta   number;
  v_nro_doc_soli     pr_pre_che_roga.nro_doc_solicitante%type;
  v_nro_doc_invi     pr_pre_che_roga.nro_doc_invitado%type;
  v_cod_moneda       ge_par_generales.cod_mon_local%type := pag_gen.fu_obt_mon_local;
  v_cod_per_soli     ba_personas.cod_persona%type;
  v_cod_per_invi     ba_personas.cod_persona%type;
  v_cod_error        varchar2(5) := 'OK';
  v_cod_inh_err      number := 0;
  v_det_error        varchar2(4000);
  v_doc_persona      varchar2(1); --tiene doc
  v_pro_activo       varchar2(1); --tiene cta activa
  v_onboarding       varchar2(1); --hizo onboarding
  v_doc_inv_persona  varchar2(1);
  v_pro_inv_activo   varchar2(1);
  v_inv_onboarding   varchar2(1);
  v_nom_sol_completo ba_personas.nom_completo%type;
  v_nom_inv_completo ba_personas.nom_completo%type;
  v_pri_nombre       ba_per_fisicas.pri_nombre%type;
  v_seg_nombre       ba_per_fisicas.seg_nombre%type;
  v_pri_apellido     ba_per_fisicas.pri_apellido%type;
  v_seg_apellido     ba_per_fisicas.seg_apellido%type;
  v_per_inh_soli     varchar2(1);
  v_per_inh_invi     varchar2(1);
  v_est_oferta       pr_pre_che_roga.estado%type;
  v_est_control      pr_pre_che_roga.estado%type;

  v_tem_vigente varchar2(1) := 'N';
  v_sol_enc_cto varchar2(1); -- solicitante se encuentra correcto
  v_inv_enc_cto varchar2(1); -- invitado se encuentra correcto
  v_mto_total   number(18, 2);
  ------------------------------------------------------
  v_val_Tasa         ge_tas_rangos.val_tasa%TYPE;
  v_cod_tasa         ge_tas_rangos.cod_tasa%TYPE;  
begin
  --
  begin
    pre_ini_aplicacion;
    pae_cnf.g_cod_modulo := 1;
  end;
  --
  for reg in c_che_roga loop
    v_can_registro    := 0;
    v_can_lim_oferta  := 0;
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
    v_cod_per_soli    := null;
    v_cod_per_invi    := null;
    v_est_control     := null;
    
    -- Valida si existe oferta, no controla estado
    begin
      select count(1), initcap(t.estado)
        into v_can_registro, v_est_control
        from pr_pre_che_roga t
       where (t.nro_doc_solicitante = v_nro_doc_soli)
         and t.nro_oferta in
             (select nro_oferta
                from pr_pre_che_roga tt
               where tt.nro_oferta = reg.nro_oferta)
       group by estado;
    exception
      when no_data_found then
        v_can_registro := 0;
      when others then
        v_can_registro := 0;
    end;
    --
       -- Validación campo destino y montos
    if reg.destino is null then
      v_cod_error := '101';
      raise_application_error(-20000, 'Error 101: El campo DESTINO no puede ser nulo. Nro Oferta : '||reg.nro_oferta);
    end if;

    if upper(trim(reg.destino)) = 'PREVENTA' then
      if reg.mto_total is null then
        v_cod_error := '102';
        raise_application_error(-20000, 'Error 102: Para DESTINO PREVENTA el MONTO TOTAL no puede ser nulo. Nro Oferta : '||reg.nro_oferta);
      end if;
    else
      if reg.mto_total_2 is null then
        v_cod_error := '103';
        raise_application_error(-20000, 'Error 103: Para DESTINO distinto de PREVENTA el MONTO TOTAL 2 no puede ser nulo. Nro Oferta : '||reg.nro_oferta);
      end if;
    end if;
    if v_cod_error = 'OK' then
      -- Inicializa estado
      v_est_oferta := case
                        when v_est_oferta = 'PENDIENTE' then
                         'P'
                        when v_est_oferta = 'PENDIENTE ANALIZAR CALIF. CREDITO' then
                         'A'
                        when v_est_oferta = 'APROBADO IFI' then
                         'I'
                        when v_est_oferta = 'PENDIENTE PUNTO DE EQUILIBRIO' then
                         'E'
                        when v_est_oferta = 'PENDIENTE APROBACI�N AFD' then
                         'F'
                        when v_est_oferta = 'APROBADO AFD' then
                         'D'
                        when v_est_oferta = 'PENDIENTE CONTINUIDAD CLIENTE' then
                         'C'
                        when v_est_oferta = 'AVANZAR SOLICITUD' then
                         'V'
                        when v_est_oferta = 'CANCELADO POR EL CLIENTE' then
                         'X'
                        when v_est_oferta = 'CANCELADO 90 DIAS' then
                         'S'
                        when v_est_oferta = 'CANCELADO MUVH' then
                         'H'
                        when v_est_oferta = 'PENDIENTE DESEMBOLSO AFD' then
                         'Y'
                        when v_est_oferta = 'DESEMBOLSADO AFD' then
                         'Z'
                        when v_est_oferta = 'DESEMBOLSADO IFI' then
                         'W'
                        when v_est_oferta = 'CONTINUAR SOLICITUD' then
                         'U'
                        when v_est_oferta = 'PENDIENTE GESTION AFD' then
                         'G'
                        when v_est_oferta = 'PENDIENTE DESEMBOLSO BNF' then
                         'B'
                        when v_est_oferta = 'DESEMBOLSADO BNF' then
                         'N'
                        else
                         'P'
                      end;
      -- 
      if (v_can_registro > 0 and v_est_control <> v_est_oferta) or
         (v_est_control = v_est_oferta) then
        -- Update tabla maestra del estado nuevo del archivo
        begin
          update pr_pre_che_roga ss
             set ss.estado = v_est_oferta
           where ss.nro_oferta = reg.nro_oferta
             and ss.nro_doc_solicitante = v_nro_doc_soli;
        exception
          when others then
            v_cod_error := 99;
            raise_application_error(-20000, v_det_error || SQLERRM);
        end;
      
        -- Obtiene codigo persona si lo tuviere
        begin
          v_cod_per_soli := it.fue_obt_cod_persona(v_nro_doc_soli);
        exception
          when others then
            v_cod_error := 99;
            raise_application_error(-20000, 'No existe persona' || SQLERRM);
        end;
        -- Llama PR que gestiona Banners
        it.prp_env_datos(v_cod_per_soli, v_est_oferta);
      
      else
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
                   v_nom_sol_completo
              from ba_per_fisicas f, ba_personas p
             where f.cod_persona = v_cod_per_soli
               and f.cod_persona = p.cod_persona;
          exception
            when no_data_found then
              v_pri_nombre   := null;
              v_pri_apellido := null;
          end;
          if nvl(v_cod_error, 'ERROR') = 'OK' and
             (v_pri_nombre is not null and v_pri_apellido is not null) then
            v_cod_inh_err := null;
          
            if nvl(fug_cau_inh_por_nombre(v_nom_sol_completo, null), 'X') = 'X' then
              -- Si la persona no tiene coincidencia el campo EST_VERIFICACION debe ser Sin Coincidencias.
              it.prg_per_par_listas(v_pri_nombre,
                                    v_seg_nombre,
                                    v_pri_apellido,
                                    v_seg_apellido,
                                    v_cod_inh_err,
                                    v_det_error);
            
              if nvl(v_cod_inh_err, 0) != 0 then
                v_per_inh_soli := 'S';
                v_cod_per_soli := null; -- si esta inhibido no debe llevar codigo persona            
              else
                v_per_inh_soli := 'N';
              end if;
            end if;
          end if;
        
        end if;
        -- Recupera datos Invitado
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
                   v_nom_inv_completo
              from ba_per_fisicas f, ba_personas p
             where f.cod_persona = v_cod_per_invi
               and f.cod_persona = p.cod_persona;
          exception
            when no_data_found then
              v_pri_nombre   := null;
              v_pri_apellido := null;
          end;
          if nvl(v_cod_error, 'ERROR') = 'OK' and
             (v_pri_nombre is not null and v_pri_apellido is not null) then
            v_cod_inh_err := null;
          
            if nvl(fug_cau_inh_por_nombre(v_nom_inv_completo, null), 'X') = 'X' then
              -- Si la persona no tiene coincidencia el campo EST_VERIFICACION debe ser Sin Coincidencias.
              it.prg_per_par_listas(v_pri_nombre,
                                    v_seg_nombre,
                                    v_pri_apellido,
                                    v_seg_apellido,
                                    v_cod_inh_err,
                                    v_det_error);
            
              if nvl(v_cod_inh_err, 0) != 0 then
                v_per_inh_invi := 'S';
                v_cod_per_invi := null; -- si esta inhibido no debe llevar codigo persona
              else
                v_per_inh_invi := 'N';
              end if;
            end if;
          end if;
        end if;
        -- Inicializa estado oferta
        -- Si el solicitante e invitado hicieron Onboarding y no estan Inhibidos, oferta En Proceso (G)
        if (v_sol_enc_cto = 'S' and v_inv_enc_cto = 'S' and
           v_per_inh_soli = 'N' and v_per_inh_invi = 'N') then
          v_est_oferta := 'P'; --'G';
        elsif (v_sol_enc_cto = 'S' and v_per_inh_soli = 'N' and
              v_nro_doc_invi is null) then
          -- no tiene invitado
          v_est_oferta := 'P'; --'G';
        else
          v_est_oferta := 'P'; --'I';
        end if;
        -- Tasa de Gastos Administrativo para descontar el total los gastos administrativos incluidos en el excel.
   IF upper(trim(reg.destino)) = 'PREVENTA' then    
      BEGIN
          SELECT t.cod_tasa
            INTO v_cod_tasa
            FROM ge_transacciones t
           WHERE t.cod_modulo = 6
             AND t.cod_modalidad = v_cod_modalidad
             AND t.cod_transaccion = 704;
        EXCEPTION
          WHEN no_data_found THEN
            v_cod_error := 999;
            raise_application_error(-20000, 'No se encuentra parametrizada la tasa para el cargo de Gastos Administrativo.' || SQLERRM);
        END;
        --
        v_val_Tasa := fug_obt_valtas_rango(v_cod_tasa,
                                           6,
                                           v_cod_modalidad,
                                           v_cod_moneda,
                                           null,
                                           reg.mto_total,
                                           reg.fec_oferta);
                                           
        v_mto_total       := (to_number(reg.mto_total) - round((to_number(reg.mto_total) * v_val_Tasa / 100),0));   
   ELSE 
        v_mto_total := reg.mto_total_2;
   END IF;
        -- Inserta tabla maestra      
        begin
          insert into pr_pre_che_roga x
            (x.nro_oferta,
             x.nro_doc_solicitante,
             x.cod_per_solicitante,
             x.nro_doc_invitado,
             x.cod_per_invitado,
             x.fec_oferta,
             x.fec_vencimiento,
             x.mto_total,
             x.mto_proyecto,
             x.mto_equipamiento,
             x.mto_cuota,
             x.can_cuotas,
             x.equipamiento,
             x.cod_moneda,
             x.tip_producto,
             x.ubi_vivienda,
             x.nom_proyecto,
             x.tip_vivienda,
             x.sub_tip_vivienda,
             x.constructora,
             x.detalle_1,
             x.detalle_2,
             x.detalle_3,
             x.detalle_4,
             x.detalle_5,
             x.estado,
             x.inv_acepto,
             x.nro_solicitud,
             x.dimension,
             x.can_dormitorios,
             x.cod_oficina,
             x.cod_usu_oficial,
             x.tip_amortizacion,
             x.cod_modalidad,
             x.cod_rub_economico,
             x.mot_estado,
             x.mto_garantia,
             x.mto_notario,
             x.mto_tasacion,
             x.mto_adm_gastos,
             x.mto_cuo_contruccion,
             x.pto_equilibrio,
             x.tipo,
             x.destino,
             x.ejecutora)
          values
            (reg.nro_oferta,
             v_nro_doc_soli,
             v_cod_per_soli,
             v_nro_doc_invi,
             v_cod_per_invi,
             trunc(reg.fec_oferta),
             trunc(reg.fec_vencimiento),
             v_mto_total,
             reg.mto_proyecto,
             reg.mto_equipamiento,
             reg.mto_cuota,
             reg.can_cuotas,
             reg.equipamiento,
             v_cod_moneda,
             reg.tip_producto,
             reg.ubi_vivienda,
             reg.nom_proyecto,
             reg.tip_vivienda,
             reg.sub_tip_vivienda,
             reg.constructora,
             reg.detalle_1,
             reg.detalle_2,
             reg.detalle_3,
             reg.detalle_4,
             reg.detalle_5,
             v_est_oferta,
             'N',
             reg.nro_solicitud,
             reg.dimension,
             reg.can_dormitorios,
             v_cod_oficina,
             v_cod_oficial,
             null,
             v_cod_modalidad,
             v_cod_rub_economico,
             null,
             reg.mto_garantia,
             reg.mto_notario,
             reg.mto_tasacion,
             reg.mto_adm_gastos,
             reg.mto_cuo_contruccion,
             reg.pto_equilibrio,
             reg.tipo,
             reg.destino,
             reg.ejecutora);
        exception
          when others then
            v_det_error := SQLERRM;
            raise_application_error(-20000, v_det_error || SQLERRM);
        end;
      
        -- Inicio envio correo. 
        v_json := '{' || '"Nro.Documento Solicitante":' || '"' ||
                  v_nro_doc_soli || '"' || ',' || --Documento solicitante
                  '"Nombre Solicitante":' || '"' || v_nom_sol_completo || '"' || ',' || -- Nombre solicitante
                  '"Nro.Documento Invitado":' || '"' || v_nro_doc_invi || '"' || ',' || --Documento invitado
                  '"Nombre Invitado":' || '"' || v_nom_inv_completo || '"' || ',' || -- Nombre invitado
                  '"Nro Oferta":' || '"' || reg.nro_oferta || '"' || ',' || --Nro Oferta
                  '"Fecha Oferta":' || '"' || reg.fec_oferta || '"' || ',' || -- Fecha solicitud
                  '"Monto Total":' || '"' || reg.mto_total || '"' || ',' || -- Mto total
                  '"Monto Proyecto":' || '"' || reg.mto_proyecto || '"' || ',' || -- Mto Proyecto
                  '"Monto Equipamiento":' || '"' || reg.mto_equipamiento || '"' || ',' || -- Mto Equipamiento
                  '"Monto Cuota":' || '"' || reg.mto_cuota || '"' || ',' || -- Mto Cuota
                  '"Cantidad de Cuotas":' || '"' || reg.can_cuotas || '"' || ',' || -- Cantidad Cuotas
                  '"Estado Oferta":' || '"' || v_est_oferta || '"' || '}'; -- Estado
        -- Verifica template 
        begin
          select 'S'
            into v_tem_vigente
            from ge_mai_onb_templates
           where v_fec_actual between ini_vigencia and fin_vigencia
             and tip_producto = v_tip_pro_oficial;
        exception
          when no_data_found then
            v_tem_vigente := 'N';
          when too_many_rows then
            v_tem_vigente := 'S';
          when others then
            v_tem_vigente := 'N';
        end;
        -- Validacion para insertar
        if v_dir_mail_ofi is not null then
          if nvl(v_tem_vigente, 'N') = 'S' then
          
            insert into it.ba_env_correos
              (cod_persona,
               tip_producto,
               estado,
               fec_registro,
               parametros,
               mai_destinatario)
            values
              (nvl(v_cod_per_soli, '1'),
               v_tip_pro_oficial,
               'P',
               sysdate,
               v_json,
               v_dir_mail_ofi);
          else
            prg_ins_log_programas('PRP_GEN_OFE_CHE_ROGA',
                                  '3-Error: ' ||
                                  'Template se encuentra inactivo o no existe',
                                  v_cod_per_soli,
                                  null);
          end if;
        else
          prg_ins_log_programas('PRP_GEN_OFE_CHE_ROGA',
                                '4-Error: ' ||
                                'Correo no esta cargado en el cliente',
                                v_cod_per_soli,
                                null);
        end if;
        -- Llama PR que gestiona Banners
        it.prp_env_datos(v_cod_per_soli, v_est_oferta);
      
      end if; -- fin envio correo
    
      -- Elimina datos del temporal.
      delete from pr_pre_che_roga_tmp where nro_oferta = reg.nro_oferta;
    
    end if;
  end loop;
exception
  when others then
    raise_application_error(-20000, sqlerrm || sqlcode || v_det_error);
end;
/

