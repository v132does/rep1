create or replace procedure    it.prp_gen_des_che_roga(p_nro_solicitud     in pr_solicitudes.nro_solicitud%type,
                                                    p_mto_desembolsar   in pr_solicitudes.monto%type,
                                                    p_nro_cta_acreditar in ge_movimientos.nro_cuenta%type,
                                                    p_clave             in number,
                                                    p_cod_persona       in ba_personas.cod_persona%type,
                                                    p_nro_cuenta        out pr_cta_prestamos.nro_cuenta%type,
                                                    p_cod_error         out number,
                                                    p_msj_error         out varchar2,
                                                    p_destino           in ge_cta_dat_adicionales.val_parametro%type,
                                                    p_mov_descripcion   in ge_movimientos.concepto%type default null) is
  ---------------------------------------------------------------------------
  g_lugar       varchar2(250);
  g_msj_error   varchar2(4000);
  g_cod_error   number(3) default 0;
  v_log_mensaje varchar2(4000);
  --------------------------------------------------------------------------
  v_fec_actual    date := pag_cal.fu_obt_fec_actual(6);
  v_tip_documento pr_solicitudes.tip_documento%type := 1;
  v_nro_doc_desde number := 1;
  v_nro_doc_hasta number := 1;
  v_cod_oficina   ba_oficinas.cod_oficina%type;
  v_cod_ori_fondo pr_solicitudes.cod_ori_fondo%type;
  v_hora          ge_movimientos.hora%type := to_char(sysdate, 'hh24:mi:ss');
  v_cod_modulo    pr_solicitudes.cod_modulo%type := 6;
  v_cod_modalidad pr_solicitudes.cod_modalidad%type := 65;
  v_cod_moneda    pr_solicitudes.cod_moneda%type := nvl(pag_cta.g_ctas.cod_moneda,
                                                        'GS');
  ---------------------------------------------------------------------------
  v_mov_descripcion    ge_par_dinamicos.val_parametro%type := NVL(p_mov_descripcion, fug_obt_pardinamico('DES_CRE_PRESTAMO'));
  v_mto_cargo          number;
  v_mto_int_adelantado number;
  ---------------------------------------------------------------------------
  v_nro_secuencia ge_movimientos.nro_secuencia%type := 0;
  v_nro_cuenta    ge_movimientos.nro_cuenta%type;
  v_cotizacion    ge_movimientos.cotizacion%type;
  v_impuesto      ge_movimientos.monto%type;
  ----------------------------------------------------------------------------
  v_nro_doc_blo ge_movimientos.nro_documento%type;
  v_cod_causa   ge_movimientos.cod_causa%type;
  ----------------------------------------------------------------------------
  v_dir_mail  ge_par_dinamicos.parametro%type := fug_obt_pardinamico('DIR_MAIL_OPERATIVO');
  v_correo    ba_personas.dir_correo%type;
  v_texto     varchar2(4000);
  v_remitente ge_par_generales.dir_correo%type := fug_obt_dir_correo;
  v_asunto    varchar2(4000);
  ----------------------------------------------------------------------------
  v_mto_sue_minimo     pr_parametros.sal_min_vigente%type;
  v_can_sue_minimo     ge_par_dinamicos.val_parametro%type;
  v_mto_lim_cta_basica ge_movimientos.monto%type;
  v_sal_acu_mes        ah_sal_mensuales.tot_creditos%type;
  ----------------------------------------------------------------------------
  v_msj_error varchar2(4000);
  v_cod_error number(3) default 0;
  ----------------------------------------------------------------------------
  v_cod_mon_solicitud pr_solicitudes.cod_moneda%type;
  ----------------------------------------------------------------------------
  v_exite        varchar2(1);
  v_existe_tc    varchar2(1);
  v_existe_pr    varchar2(1);
  v_cod_per_invi ba_personas.cod_persona%type;
  v_exi_tc_invi  varchar2(1);
  v_exi_pr_invi  varchar2(1);
  ------------------------------------------------------------------------------
  v_des_mail  ge_par_dinamicos.parametro%type := fug_obt_pardinamico('EMAIL_DESEM_CHE_ROGA');
  v_constructora    VARCHAR2(100);--pr_pre_che_roga.constructora%type;
  r_psoli pr_solicitudes%rowtype;
  ----------------------------------------------------------------------------
  procedure pr_obt_dat_solicitud is
  begin
    pap_pre.pr_obt_dat_solicitud(p_nro_solicitud,
                                 r_psoli,
                                 v_mto_cargo,
                                 v_mto_int_adelantado);
    if r_psoli.estado = 'L' then
      v_tip_documento := r_psoli.tip_documento;
      v_cod_ori_fondo := r_psoli.cod_ori_fondo;
      v_cod_oficina   := r_psoli.cod_oficina;
    end if;
    v_cod_modalidad     := r_psoli.cod_modalidad;
    v_cod_mon_solicitud := r_psoli.cod_moneda;
  exception
    when others then
      g_cod_error := '001';
      g_lugar     := 'Obtener Solicitud ' || p_nro_solicitud;
      g_msj_error := 'Error al obtener solicitudes ' || sqlerrm;
  end;
  --------- insertamos movimientos de bloqueo de saldos--------------------------
  procedure pr_ins_mov_bloqueo(p_cod_tra_padre   ge_movimientos.cod_tra_padre%type,
                               p_cod_transaccion ge_movimientos.cod_transaccion%type,
                               p_imp_transaccion ge_movimientos.monto%type,
                               p_nro_documento   ge_movimientos.nro_documento%type,
                               p_cod_causa       ge_movimientos.cod_causa%type,
                               p_emi_aviso       ge_movimientos.emi_aviso%type) is
    r_gmovi ge_movimientos%rowtype;
    -------------------------------------------------------
    -- obj. graba ge_movimientos de acuerdo a los parametros --
    -------------------------------------------------------
  begin
    g_lugar         := 'Genera_ge_movimientos';
    v_nro_secuencia := v_nro_secuencia + 1;
    --- cargar registro de movimientos
    r_gmovi.cod_usuario     := user;
    r_gmovi.hora            := v_hora;
    r_gmovi.nro_secuencia   := nvl(v_nro_secuencia, 1);
    r_gmovi.cod_modulo      := pag_cta.g_ctas.cod_modulo;
    r_gmovi.cod_modalidad   := pag_cta.g_ctas.cod_modalidad;
    r_gmovi.cod_oficina     := pag_cta.g_ctas.cod_oficina;
    r_gmovi.nro_cuenta      := p_nro_cta_acreditar;
    r_gmovi.cod_moneda      := v_cod_moneda;
    r_gmovi.fec_valor       := v_fec_actual;
    r_gmovi.fecha           := v_fec_actual;
    r_gmovi.cod_tra_padre   := p_cod_tra_padre;
    r_gmovi.cod_transaccion := p_cod_transaccion;
    r_gmovi.est_cuenta      := pag_cta.g_ctas.estado;
    r_gmovi.estado          := 'N';
    r_gmovi.cod_ofi_origen  := to_number(nvl(v_cod_oficina,
                                             it.fug_obt_ofi_matriz));
    r_gmovi.reversado       := 'N';
    r_gmovi.emi_aviso       := p_emi_aviso;
    r_gmovi.protegido       := 'N';
    r_gmovi.cod_mod_padre   := nvl(pag_cta.g_ctas.cod_modulo, 3);
    r_gmovi.cod_mad_padre   := nvl(pag_cta.g_ctas.cod_modalidad, 31);
    r_gmovi.monto           := p_imp_transaccion;
    r_gmovi.nro_documento   := p_nro_documento;
    r_gmovi.cod_causa       := p_cod_causa;
    pag_gen.pr_ins_ge_movimiento(r_gmovi);
    v_nro_secuencia := nvl(v_nro_secuencia, 1) + 1;
  exception
    when others then
      g_cod_error := '010';
      g_lugar     := 'Genera Movimiento de Bloqueo de Saldo';
      g_msj_error := 'Error al generar movimiento de bloqueo ' || sqlerrm;
  end;
begin
  g_msj_error := ' ';
  g_cod_error := 0;
  begin
    pre_ini_aplicacion;
  end;
  pae_cnf.g_programa := 'PRP_GEN_DES_CHE_ROGA';
  -- inicialmente controlamos que la ---------------------------------------------
  -- clave introducida sea correcta  ---------------------------------------------
  if nvl(g_cod_error, '000') = '000' then
    if fue_tab_dat_adicional('PR_SOLICITUDES',
                             'CLA_PRE_APROBADO',
                             p_nro_solicitud) <> p_clave then
      g_cod_error := '003';
      g_msj_error := 'Clave invalida.';
    end if;
    -- obtenemos la solicitud del cliente -------------------------------------------
    if nvl(g_cod_error, '000') = '000' then
      pr_obt_dat_solicitud;
    end if;
  
    --------------------control cuenta con oferta de tarjeta vigente---------------------
    /*if nvl(g_cod_error, '000') = '000' then
      begin
        select 'S'
          into v_existe_tc
          from ta_lin_pre_aprobado t
         where t.estado = 'A'
           and t.cod_persona = p_cod_persona;
      exception
        when no_data_found then
          v_existe_tc := 'N';
        when others then
          g_cod_error := '011';
          g_lugar     := 'Consulta estado Tarjeta';
          g_msj_error := 'Error al consultar estado tarjeta ' || sqlerrm;
      end;
    
      if nvl(v_existe_tc, 'N') = 'S' then
        g_cod_error := '013';
        g_lugar     := 'Persona posee una Linea de credito activa';
        g_msj_error := 'Persona posee una Linea de credito activa ';
      
        update pr_pre_aprobados pp
           set pp.estado = 'V', pp.fec_fin_oferta = trunc(sysdate)
         where pp.nro_solicitud = p_nro_solicitud
           and pp.cod_persona = p_cod_persona;
      
        update pr_solicitudes t
           set t.estado        = 'N',
               t.observaciones = 'Baja de solicitud de préstamo por aceptación de oferta de línea de crédito.'
         where t.nro_solicitud = p_nro_solicitud;
      end if;
    end if;*/
    --------------------control cuenta con oferta de tarjeta vigente---------------------
  
    -------- verificacion del monto credito en comparacion del monto tope -----------
  
    if nvl(g_cod_error, '000') = '000' then
      pag_cta.pr_obt_cuenta(p_nro_cta_acreditar);
      --da-6962- control de moneda para desembolso
      if nvl(pag_cta.g_cod_error, 0) = 0 then
        if pag_cta.g_ctas.cod_moneda <> v_cod_mon_solicitud then
          g_cod_error := 39;
          g_msj_error := 'Moneda de la solicitud ' || v_cod_mon_solicitud ||
                         ' es distinta a la moneda de la cuenta credito ' ||
                         pag_cta.g_ctas.cod_moneda;
        
        end if;
      else
        g_cod_error := 40;
        g_msj_error := 'Ocurrió un error al obtener la cuenta ' ||
                       p_nro_cta_acreditar || 'Error: ' ||
                       pag_cta.g_cod_error;
      
      end if;
      -- Control para Cambio de modalidad
      if fug_obt_paradicional(p_nro_cta_acreditar, 'LIM_CRE_TRANSACCIONES') is not null and
         user not in ('APICAJERO', 'JNICORA') and nvl(g_cod_error, 0) = 0 then
      
        If fug_obt_paradicional(p_nro_cta_acreditar, 'CTA_CAM_MODALIDAD') is null Then
          -- Insercion de parametro para cambio de modalidad
          Begin
            insert into ge_cta_dat_adicionales
              (nro_cuenta, parametro, val_parametro)
            values
              (p_nro_cta_acreditar, 'CTA_CAM_MODALIDAD', '31');
          Exception
            when others then
              null;
          End;
        
        End if;
      
        -- cambio de modalidad
        pra_act_modalidad(p_cod_persona,
                          p_nro_cta_acreditar,
                          334, --origen
                          31 --destino
                          );
      
        -- borramos el limite de credito
        begin
          delete from ge_cta_dat_adicionales
           where nro_cuenta = p_nro_cta_acreditar
             and parametro = 'LIM_CRE_TRANSACCIONES';
          commit;
        Exception
          when others then
            null;
        End;
      end if;
      /*cuenta bajo riesgo*/ /*:new.cod_modalidad = 334*/
      if fug_obt_paradicional(p_nro_cta_acreditar, 'LIM_CRE_TRANSACCIONES') is not null and
         user not in ('APICAJERO', 'JNICORA') and nvl(g_cod_error, 0) = 0 then
      
        --control solo si es credito
        it.prg_val_cta_baj_riesgo(p_nro_cta_acreditar,
                                  v_cod_moneda,
                                  pag_cta.g_ctas.cod_modulo,
                                  pag_cta.g_ctas.cod_modalidad,
                                  p_mto_desembolsar,
                                  g_cod_error,
                                  g_msj_error);
      
        if nvl(g_cod_error, 0) != 0 then
          g_cod_error := 41;
          g_msj_error := 'Monto acreditado supera el limite de cuenta de Bajo Riesgo ' ||
                         pag_cta.g_cod_error || ' ..';
        
        end if;
      end if;
    end if;
  
    -- generamos la cuenta y el desembolso -------------------------------------------
    if nvl(g_cod_error, '000') = '000' then
    
      pap_pre.pr_des_prestamos(p_nro_solicitud,
                               p_mto_desembolsar,
                               v_fec_actual,
                               v_tip_documento,
                               v_nro_doc_desde,
                               v_nro_doc_hasta,
                               v_cod_oficina,
                               v_cod_ori_fondo,
                               v_hora,
                               v_nro_secuencia,
                               v_nro_cuenta);
      -----------------------------------------------------------------------------------
      if p_nro_cta_acreditar is not null then
        --
        pag_cta.pr_obt_cuenta(p_nro_cta_acreditar);
        --
        v_cotizacion := null;
        prg_ver_cob_cargos(p_nro_cta_acreditar,
                           v_nro_cuenta,
                           v_cod_modulo,
                           v_cod_modalidad,
                           v_cod_oficina,
                           v_cod_moneda,
                           abs(p_mto_desembolsar),
                           'Desembolso de Préstamo ' || v_nro_cuenta,
                           null,
                           v_fec_actual,
                           v_hora,
                           v_impuesto,
                           v_nro_secuencia,
                           'S',
                           v_cotizacion);
        --
        if p_mto_desembolsar <> 0 then
          if p_mto_desembolsar > 0 then
            begin
              pag_cta.pr_act_operacion(p_nro_cta_acreditar,
                                       v_hora,
                                       'C',
                                       v_cod_moneda,
                                       p_mto_desembolsar -
                                       nvl(v_impuesto, 0),
                                       358,
                                       602,
                                       p_nro_solicitud,
                                       v_cotizacion,
                                       v_cod_oficina,
                                       v_cod_modulo,
                                       v_cod_modalidad,
                                       null,
                                       null,
                                       nvl(v_mov_descripcion,'Desembolso de Sol. ' ||
                                       p_nro_solicitud),
                                       'S',
                                       v_nro_secuencia,
                                       v_fec_actual);
            exception
              when others then
                g_cod_error := '004';
                g_lugar     := 'Credito cuenta de Ahorro';
                g_msj_error := 'Error al realizar credito de pre-aprobados ' ||
                               sqlerrm;
            end;
          end if;
        end if;
    /*    begin
          update pr_pre_che_roga pp --pr_pre_aprobados pp
             set pp.estado = 'N' --'N' Desembolsado ADF
           where pp.nro_solicitud = p_nro_solicitud
             and pp.cod_per_solicitante = p_cod_persona
             and pp.estado in ('V', 'I');
        exception
          when others then
            g_cod_error := '008';
            g_lugar     := 'Actualiza tabla pre-aprobados';
            g_msj_error := 'Error al actualizar estado de pre-aprobados ' ||
                           sqlerrm;
        end;
        */
        begin
          update pr_cta_prestamos pp
             set pp.nro_cta_debito = p_nro_cta_acreditar,
                 pp.cob_automatico = 'S'
           where pp.nro_solicitud = p_nro_solicitud
             and pp.nro_cuenta = v_nro_cuenta;
        exception
          when others then
            g_cod_error := '008';
            g_lugar     := 'Actualiza tabla pr_cta_prestamos';
            g_msj_error := 'Error al actualizar debito automatico de pr_cta_prestamos ' ||
                           sqlerrm;
        end;
        -- oferta tarjeta titular
        begin
          select 'S'
            into v_exite
            from ta_lin_pre_aprobado t
           where t.estado in ('C', 'G')
             and t.cod_persona = p_cod_persona;
        exception
          when no_data_found then
            v_exite := 'N';
          when others then
            --  g_cod_error := '011';
            g_lugar     := 'Consulta estado Tarjeta';
            g_msj_error := 'Error al Consulta estado Tarjeta ' || sqlerrm;
        end;
      
        if nvl(v_exite, 'N') = 'S' then
          update ta_lin_pre_aprobado t
             set t.estado = 'N', t.fec_fin_oferta = trunc(sysdate)
           where t.estado in ('C', 'G')
             and t.cod_persona = p_cod_persona;
        end if;
        -- oferta Pre aprobado titular
        begin
          select 'S'
            into v_existe_pr
            from pr_pre_aprobados t
           where t.estado in ('C', 'G')
             and t.cod_persona = p_cod_persona;
        exception
          when no_data_found then
            v_existe_pr := 'N';
          when others then
            --   g_cod_error := '011';
            g_lugar     := 'Consulta estado Pre Aprobado';
            g_msj_error := 'Error al Consulta estado Pre aprobado ' ||
                           sqlerrm;
        end;
      
        if nvl(v_existe_pr, 'N') = 'S' then
          update pr_pre_aprobados t
             set t.estado = 'N', t.fec_fin_oferta = trunc(sysdate)
           where t.estado in ('C', 'G')
             and t.cod_persona = p_cod_persona;
        end if;
        -- Obtenemos invitado
        begin
 --         select tt.cod_per_invitado
 --          into v_cod_per_invi
 --           from pr_pre_che_roga tt
 --          where tt.estado in ('V', 'I')
 --            and tt.cod_per_solicitante = p_cod_persona;
     SELECT NRO_GARANTIA 
       INTO v_cod_per_invi
       FROM pr_sol_garantias
      WHERE nro_solicitud = p_nro_solicitud;
        exception
          when no_data_found then
            v_cod_per_invi := null;
          when others then
            --  g_cod_error := '011';
            g_lugar     := 'Consulta persona Invitada';
            g_msj_error := 'Error al Consulta Persona invitada ' || sqlerrm;
        end;
        if v_cod_per_invi is not null then
          -- oferta tarjeta invitado
          begin
            select 'S'
              into v_exi_tc_invi
              from ta_lin_pre_aprobado t
             where t.estado in ('C', 'G')
               and t.cod_persona = v_cod_per_invi;
          exception
            when no_data_found then
              v_exi_tc_invi := 'N';
            when others then
              --  g_cod_error := '011';
              g_lugar     := 'Consulta estado Tarjeta';
              g_msj_error := 'Error al Consulta estado Tarjeta ' || sqlerrm;
          end;
        
          if nvl(v_exi_tc_invi, 'N') = 'S' then
            update ta_lin_pre_aprobado t
               set t.estado = 'N', t.fec_fin_oferta = trunc(sysdate)
             where t.estado in ('C', 'G')
               and t.cod_persona = v_cod_per_invi;
          end if;
          -- oferta Pre aprobado invitado
          begin
            select 'S'
              into v_exi_pr_invi
              from pr_pre_aprobados t
             where t.estado in ('C', 'G')
               and t.cod_persona = v_cod_per_invi;
          exception
            when no_data_found then
              v_exi_pr_invi := 'N';
            when others then
              --   g_cod_error := '011';
              g_lugar     := 'Consulta estado Pre Aprobado';
              g_msj_error := 'Error al Consulta estado Pre aprobado ' ||
                             sqlerrm;
          end;
        
          if nvl(v_exi_pr_invi, 'N') = 'S' then
            update pr_pre_aprobados t
               set t.estado = 'N', t.fec_fin_oferta = trunc(sysdate)
             where t.estado in ('C', 'G')
               and t.cod_persona = v_cod_per_invi;
          end if;
        
        end if;
      end if;
      --
      -- if fug_val_con_uni_per(p_cod_persona) = 'N' then
      v_cod_causa := fug_obt_pardinamico('PRE_COD_CAU_CHE_ROGA');
      if v_nro_doc_blo is null then
        begin
          select s_nro_bloqueo.nextval into v_nro_doc_blo from dual;
        exception
          when others then
            g_cod_error := '005';
            g_lugar     := 'Obtiene la secuencia del bloqueo';
            g_msj_error := 'Error al generar secuencia de bloqueo ' ||
                           sqlerrm;
        end;
      end if;
      --
      --604
    
      begin
        update ah_cta_vistas a
           set a.fec_ult_movimiento = v_fec_actual,
               a.hor_ult_movimiento = v_hora,
               a.sal_bloqueado      = a.sal_bloqueado + p_mto_desembolsar,
               a.estado             = 'S'
         where a.nro_cuenta = p_nro_cta_acreditar;
      
        --seteamos el estado de la cuenta por que desde este punto debe figurar como bloqueado
        --para todos los movimientos
        pag_cta.g_ctas.estado := 'S';
      
      exception
        when others then
          g_cod_error := '007';
          g_lugar     := 'Actualiza Cuenta Ahorro';
          g_msj_error := 'Error al actualizar datos de la cuenta de ahorro ' ||
                         sqlerrm;
      end;
      --
      v_hora := pag_gen.fu_obt_sig_segundo(v_hora);
      pr_ins_mov_bloqueo(307, 409, null, v_nro_doc_blo, v_cod_causa, 'N');
      --
    
      begin
        insert into ge_bloqueos
          (nro_cuenta,
           fec_inicio,
           nro_documento,
           cod_causa,
           monto,
           hor_inicio,
           fec_fin,
           tipo,
           observacion)
        values
          (p_nro_cta_acreditar,
           v_fec_actual,
           v_nro_doc_blo,
           v_cod_causa,
           p_mto_desembolsar,
           v_hora,
           null,
           'S',
           'BLOQUEO DE SALDOS DESEM. CHE ROGA');
      exception
        when others then
          g_cod_error := '006';
          g_lugar     := 'Inserta Bloqueos';
          g_msj_error := 'Error al insertar bloqueos ' || sqlerrm;
      end;
    
      -- insert ba_tab_dat_adicionales
      begin
        insert into ba_tab_dat_adicionales
          (tab_relacion, referencia, parametro, val_parametro)
        values
          ('GE_BLOQUEOS',
           v_nro_doc_blo,
           'BLO_CHE_ROGA',
           p_nro_cta_acreditar);
      exception
        when others then
          g_cod_error := '008';
          g_lugar     := 'Inserta Dat Adicionales';
          g_msj_error := 'Error al insertar Dat_Adicionales ' || sqlerrm;
      end;
    
      pr_ins_mov_bloqueo(307,
                         604,
                         p_mto_desembolsar,
                         v_nro_doc_blo,
                         v_cod_causa,
                         'N');
      --notificacion de bloqueo de saldo--
      if p_cod_persona is not null then
        begin
          select t.dir_correo
            into v_correo
            from ba_personas t
           where t.cod_persona = p_cod_persona;
        exception
          when no_data_found then
            prg_ins_log_programas('PRP_GEN_DES_CHE_ROGA',
                                  substr('Error: ' || sqlerrm, 1, 4000),
                                  null,
                                  p_cod_persona);
        end;
      
      end if;
    
      if nvl(v_correo, v_dir_mail) <> 'X' then
        begin
          v_asunto := 'Saldo Bloqueado por Desembolso para persona  ' ||
                      fue_obt_nom_persona(p_cod_persona);
          v_texto  := 'El saldo se encuentra bloqueado por Tramites Legales.' ||
                      chr(10) || 'Cliente: ' || p_cod_persona || ' - ' ||
                      fue_obt_nom_persona(p_cod_persona) || chr(10) ||
                      'Cuenta Prestamo Desembolsado: ' || v_nro_cuenta ||
                      chr(10) || 'Cuenta Acreditada: ' ||
                      p_nro_cta_acreditar || chr(10) ||
                      'Monto Desembolsado: ' || p_mto_desembolsar ||
                      chr(10);
          it_mail.mail(v_remitente, -- quien envia
                       v_dir_mail, -- a quien
                       v_asunto, -- asunto
                       v_texto); -- detalle
                       
        exception
          when others then
            null;
        end;
        
      end if;
      -- fin envio correo
      -- inicio correo crp desembolso
      /* begin
       --obtengo el interes
        select constructora
          into v_constructora 
          from pr_pre_che_roga pp
         where pp.nro_solicitud = p_nro_solicitud
           and pp.cod_per_solicitante = p_cod_persona;
       
          v_asunto := 'Che Roga  ' ||fue_obt_nom_persona(p_cod_persona) || ' ' || FUE_OBT_NRO_DOC_PERSONA(p_cod_persona);
          v_texto  := 'Tipo de garantía: ' ||  fug_obt_pardinamico('PRE_TIP_GARANTIA', r_psoli.COD_MODULO, r_psoli.COD_MODALIDAD, NULL, NULL, NULL) || chr(10) || 
                      'Fiador de la operación: ' || v_constructora || chr(10) ||   
                      'Comprador del inmueble'|| chr(10) ||       
                      fue_obt_nom_persona(p_cod_persona) || chr(10) ||
                      FUE_OBT_NRO_DOC_PERSONA(p_cod_persona) || chr(10) ||
                      'Producto: ' || FUG_OBT_DES_MODAL(r_psoli.COD_MODULO,r_psoli.COD_MODALIDAD)|| chr(10) ||
                      'Monto de la línea de crédito:  ' || chr(10) ||
                      'Monto bruto del prestamo '|| p_mto_desembolsar || chr(10) ||
                      'Intereses ' || r_psoli.mto_interes|| chr(10) ||
                      'Gastos administrativos '||r_psoli.mto_cargo || chr(10) ||
                      chr(10);
          it_mail.mail(v_remitente, -- quien envia
                       v_des_mail, -- a quien
                       v_asunto, -- asunto
                       v_texto); -- detalle
                       
        exception
          when others then
            null;
        end;*/
      -- fin envio crp desembolso
      ------------------------------------
      --
      -- end if;
    end if;
  end if;
  --
  --
  if nvl(g_cod_error, '000') <> '000' then
    p_cod_error := g_cod_error;
    p_msj_error := g_msj_error;
  else
    g_cod_error  := '000';
    g_msj_error  := 'PROCESO CONCLUIDO CON EXITO.';
    p_nro_cuenta := v_nro_cuenta;
    p_cod_error  := g_cod_error;
    p_msj_error  := g_msj_error;
  
    --Inicia WF 925
    if paw_cir.fu_ini_circuito(925, p_cod_persona, p_cod_persona) <> 0 then
      v_log_mensaje := substr('Error al iniciar el Circuito de Documentos Pendientes Empresas ' ||
                              paw_cir.G_MSJ_ERROR,
                              1,
                              4000);
      prg_ins_log_programas('PAG_PLA.PR_ALT_PER_JUR_ONB',
                            substr('Error: ' || v_log_mensaje, 1, 4000),
                            p_cod_persona,
                            null);
    end if;
  
    --da-6457
    if p_destino is not null then
      it.prg_act_alias_cta(p_nro_cuenta,
                           p_destino,
                           'C',
                           v_cod_error,
                           v_msj_error);
    end if;
  end if;
end;
/