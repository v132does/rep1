CREATE OR REPLACE PROCEDURE it.prp_gen_des_prestamos(p_nro_solicitud     in pr_solicitudes.nro_solicitud%TYPE,
                                                  p_mto_desembolsar   in pr_solicitudes.monto%TYPE,
                                                  p_nro_cta_acreditar in ge_movimientos.nro_cuenta%TYPE,
                                                  p_clave             in number,
                                                  p_cod_persona       in ba_personas.cod_persona%TYPE,
                                                  p_nro_cuenta        out pr_cta_prestamos.nro_cuenta%TYPE,
                                                  p_cod_error         out NUMBER,
                                                  p_msj_error         out VARCHAR2,
                                                  p_destino           in ge_cta_dat_adicionales.val_parametro%TYPE,
                                                  p_ind_blo_cta       in VARCHAR2 default 'F',
                                                  p_mov_descripcion   in ge_movimientos.concepto%type default null) IS
  ---------------------------------------------------------------------------
  g_lugar     VARCHAR2(250);
  g_msj_error VARCHAR2(4000);
  g_cod_error NUMBER(3) DEFAULT 0;
  --------------------------------------------------------------------------
  v_fec_actual    DATE := pag_cal.FU_OBT_FEC_ACTUAL(6);
  v_tip_documento pr_solicitudes.tip_documento%TYPE := 1;
  v_nro_doc_desde number := 1;
  v_nro_doc_hasta number := 1;
  v_cod_oficina   ba_oficinas.cod_oficina%TYPE;
  v_cod_ori_fondo pr_solicitudes.cod_ori_fondo%TYPE;
  v_hora          ge_movimientos.hora%type := to_char(sysdate, 'hh24:mi:ss');
  v_cod_modulo    pr_solicitudes.cod_modulo%TYPE := 6;
  v_cod_modalidad pr_solicitudes.cod_modalidad%TYPE := 65;
  v_cod_moneda    pr_solicitudes.cod_moneda%type :=  nvl(pag_cta.g_ctas.COD_MONEDA, 'GS');
  ---------------------------------------------------------------------------
  v_mov_descripcion    ge_par_dinamicos.val_parametro%type := NVL(p_mov_descripcion, fug_obt_pardinamico('DES_CRE_PRESTAMO'));
  v_mto_cargo          number;
  v_mto_int_adelantado number;
  ---------------------------------------------------------------------------
  v_nro_secuencia ge_movimientos.nro_secuencia%TYPE := 0;
  v_nro_cuenta    ge_movimientos.nro_cuenta%TYPE;
  v_cotizacion    ge_movimientos.cotizacion%TYPE;
  v_impuesto      ge_movimientos.monto%type;
  ----------------------------------------------------------------------------
  v_nro_doc_blo ge_movimientos.nro_documento%TYPE;
  v_cod_causa   ge_movimientos.cod_causa%TYPE;
  ----------------------------------------------------------------------------
  v_dir_mail  ge_par_dinamicos.parametro%type := fug_obt_pardinamico('MAI_BLO_DESEMBOLSO');
  v_texto     varchar2(4000);
  v_remitente ge_par_generales.dir_correo%type := fug_obt_dir_correo;
  v_asunto    varchar2(4000);
  ----------------------------------------------------------------------------
  v_mto_sue_minimo     pr_parametros.sal_min_vigente%type;
  v_can_sue_minimo     ge_par_dinamicos.val_parametro%type;
  v_mto_lim_cta_basica ge_movimientos.monto%type;
  v_sal_acu_mes        ah_sal_mensuales.tot_creditos%type;
  ----------------------------------------------------------------------------
  v_msj_error VARCHAR2(4000);
  v_cod_error NUMBER(3) DEFAULT 0;
  ----------------------------------------------------------------------------
  v_cod_mon_solicitud pr_solicitudes.cod_moneda%type;
  ----------------------------------------------------------------------------
  v_exite     varchar2(1);
  v_existe_tc varchar2(1);
  v_est_doc   number := 0;
  v_est_wf48  number := 0;

  PROCEDURE pr_obt_dat_solicitud IS
    r_psoli pr_solicitudes%rowtype;
  BEGIN
    pap_pre.PR_OBT_DAT_SOLICITUD(p_nro_solicitud,
                                 r_psoli,
                                 v_mto_cargo,
                                 v_mto_int_adelantado);
    IF r_psoli.estado = 'L' THEN
      v_tip_documento := r_psoli.tip_documento;
      v_cod_ori_fondo := r_psoli.cod_ori_fondo;
      v_cod_oficina   := r_psoli.cod_oficina;
    END IF;
    v_cod_modalidad     := r_psoli.cod_modalidad;
    v_cod_mon_solicitud := r_psoli.cod_moneda;
  EXCEPTION
    WHEN OTHERS THEN
      g_cod_error := '001';
      g_lugar     := 'Obtener Solicitud ' || p_nro_solicitud;
      g_msj_error := 'Error al obtener solicitudes ' || SQLERRM;
  END;
  --------- Insertamos movimientos de Bloqueo de Saldos--------------------------
  PROCEDURE pr_ins_mov_bloqueo(p_cod_tra_padre   ge_movimientos.cod_tra_padre%TYPE,
                               p_cod_transaccion ge_movimientos.cod_transaccion%TYPE,
                               p_imp_transaccion ge_movimientos.monto%TYPE,
                               p_nro_documento   ge_movimientos.nro_documento%TYPE,
                               p_cod_causa       ge_movimientos.cod_causa%TYPE,
                               p_emi_aviso       ge_movimientos.emi_aviso%TYPE) IS
    r_gmovi ge_movimientos%rowtype;
    -------------------------------------------------------
    -- Obj. Graba GE_MOVIMIENTOS de acuerdo a los parametros --
    -------------------------------------------------------
  BEGIN
    g_lugar         := 'Genera_ge_movimientos';
    v_nro_secuencia := v_nro_secuencia + 1;
    --- Cargar registro de movimientos
    r_gmovi.cod_usuario     := user;
    r_gmovi.hora            := v_hora;
    r_gmovi.nro_secuencia   := nvl(v_nro_secuencia, 1);
    r_gmovi.cod_modulo      := pag_Cta.G_CTAS.COD_MODULO;
    r_gmovi.cod_modalidad   := pag_cta.G_CTAS.COD_MODALIDAD;
    r_gmovi.cod_oficina     := pag_cta.G_CTAS.COD_OFICINA;
    r_gmovi.nro_cuenta      := p_nro_cta_acreditar;
    r_gmovi.cod_moneda      := v_cod_moneda;
    r_gmovi.fec_valor       := v_fec_actual;
    r_gmovi.fecha           := v_fec_actual;
    r_gmovi.cod_tra_padre   := p_cod_tra_padre;
    r_gmovi.cod_transaccion := p_cod_transaccion;
    r_gmovi.est_cuenta      := pag_cta.g_ctas.ESTADO;
    r_gmovi.estado          := 'N';
    r_gmovi.cod_ofi_origen  := TO_NUMBER(nvl(v_cod_oficina,
                                             it.fug_obt_ofi_matriz));
    r_gmovi.reversado       := 'N';
    r_gmovi.emi_aviso       := p_emi_aviso;
    r_gmovi.protegido       := 'N';
    r_gmovi.cod_mod_padre   := nvl(pag_Cta.g_ctas.COD_MODULO, 3);
    r_gmovi.cod_mad_padre   := nvl(pag_cta.g_ctas.COD_MODALIDAD, 31);
    r_gmovi.monto           := p_imp_transaccion;
    r_gmovi.nro_documento   := p_nro_documento;
    r_gmovi.cod_causa       := p_cod_causa;
    pag_gen.pr_ins_ge_movimiento(r_gmovi);
    v_nro_secuencia := nvl(v_nro_secuencia, 1) + 1;
  EXCEPTION
    WHEN OTHERS THEN
      g_cod_error := '010';
      g_lugar     := 'Genera Movimiento de Bloqueo de Saldo';
      g_msj_error := 'Error al generar movimiento de bloqueo ' || SQLERRM;
  END;
BEGIN
  g_msj_error := ' ';
  g_cod_error := 0;
  BEGIN
    pre_ini_aplicacion;
  END;
  PAE_CNF.G_PROGRAMA := 'PRP_GEN_DES_PRESTAMOS';
  -- Inicialmente controlamos que la ---------------------------------------------
  -- clave introducida sea correcta  ---------------------------------------------
  IF nvl(g_cod_error, '000') = '000' THEN
    IF fue_tab_dat_adicional('PR_SOLICITUDES',
                             'CLA_PRE_APROBADO',
                             p_nro_solicitud) <> p_clave THEN
      g_cod_error := '003';
      g_msj_error := 'Clave invalida.';
    END IF;
    -- Obtenemos la solicitud del cliente -------------------------------------------
    IF nvl(g_cod_error, '000') = '000' THEN
      pr_obt_dat_solicitud;
    END IF;   
  
    -------- VERIFICACION DEL MONTO CREDITO EN COMPARACION DEL MONTO TOPE -----------
  
    IF nvl(g_cod_error, '000') = '000' THEN
      pag_cta.PR_OBT_CUENTA(p_nro_cta_acreditar);
      --DA-6962- control de moneda para desembolso
      if nvl(pag_cta.G_COD_ERROR, 0) = 0 then
        if pag_cta.G_CTAS.COD_MONEDA <> v_cod_mon_solicitud then
          G_COD_ERROR := 39;
          G_MSJ_ERROR := 'Moneda de la solicitud ' || v_cod_mon_solicitud ||
                         ' es distinta a la moneda de la cuenta credito ' ||
                         pag_cta.G_CTAS.COD_MONEDA;
        
        end if;
      else
        G_COD_ERROR := 40;
        G_MSJ_ERROR := 'Ocurrió un error al obtener la cuenta ' ||
                       p_nro_cta_acreditar || 'Error: ' ||
                       pag_cta.G_COD_ERROR;
      
      end if;
      /*Cuenta bajo riesgo*/
      if /*:new.cod_modalidad = 334*/
       fug_obt_paradicional(p_nro_cta_acreditar, 'LIM_CRE_TRANSACCIONES') is not null and
       user not in ('APICAJERO', 'JNICORA') and nvl(G_COD_ERROR, 0) = 0 then
      
        --control solo si es credito
        it.prg_val_cta_baj_riesgo(p_nro_cta_acreditar,
                                  v_cod_moneda,
                                  pag_Cta.G_CTAS.COD_MODULO,
                                  pag_cta.G_CTAS.COD_MODALIDAD,
                                  p_mto_desembolsar,
                                  g_cod_error,
                                  g_msj_error);
      
        if nvl(g_cod_error, 0) != 0 then
          G_COD_ERROR := 41;
          G_MSJ_ERROR := 'Monto acreditado supera el limite de cuenta de Bajo Riesgo ' ||
                         pag_cta.G_COD_ERROR || ' ..';
        
        end if;
      end if;
    end if;
  
    -- Generamos la cuenta y el desembolso -------------------------------------------
    IF nvl(g_cod_error, '000') = '000' THEN
    begin
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
     exception
      when others then
         g_cod_error := '5';--sqlcode;
         g_msj_error := sqlerrm;
     end;
      -----------------------------------------------------------------------------------
    IF nvl(g_cod_error, '000') = '000' THEN
      IF p_nro_cta_acreditar is not null THEN
        --
        pag_cta.PR_OBT_CUENTA(p_nro_cta_acreditar);
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
        IF p_mto_desembolsar <> 0 THEN
          IF p_mto_desembolsar > 0 THEN
            begin
              pag_cta.PR_ACT_OPERACION(p_nro_cta_acreditar,
                                       v_hora,
                                       'C',
                                       v_cod_moneda,
                                       p_mto_desembolsar - nvl(v_impuesto, 0),
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
          --actualiza cod_seg_cliente de ge_clientes 
                BEGIN
                  update ge_clientes a
                     set a.cod_seg_cliente = nvl(a.cod_seg_cliente,fug_obt_pardinamico('PRE_PLUS_SEGMENTO'))
                   where a.cod_persona = p_cod_persona;
                EXCEPTION
                  WHEN OTHERS THEN
                    g_cod_error := '009';
                    g_lugar     := 'Actualiza tabla ge_clientes';
                    g_msj_error := 'Error al actualizar segmento de cliente ' ||
                                   SQLERRM;
                END;
            exception
              when others then
                g_cod_error := '004';
                g_lugar     := 'Credito cuenta de Ahorro';
                g_msj_error := 'Error al realizar credito de pre-aprobados ' ||
                               SQLERRM;
            end;
          END IF;
        END IF;
   
        BEGIN
          UPDATE pr_cta_prestamos pp
             SET pp.nro_cta_debito = p_nro_cta_acreditar,
                 pp.cob_automatico = 'S'
           WHERE pp.nro_solicitud = p_nro_solicitud
             AND pp.nro_cuenta = v_nro_cuenta;
        EXCEPTION
          WHEN OTHERS THEN
            g_cod_error := '008';
            g_lugar     := 'Actualiza tabla pr_cta_prestamos';
            g_msj_error := 'Error al actualizar debito automatico de pr_cta_prestamos ' ||
                           SQLERRM;
        END;
 
      END IF;
      --  DA-9874 -- esto ya valida en la funcion fug_val_con_uni_per
      /*begin
        select count(1)
          into v_est_doc
          from ba_per_ima_documentos
         where cod_persona = p_cod_persona
           and cod_tip_documento = 64
           and est_doc = 'A';
      exception
        when no_data_found then
          v_est_doc := 0;
        when others then
          v_est_doc := 0;
      end;
      begin -- se saca validacion de circuitos PCON-504 PCON-429
        select count(1)
          into v_est_wf48
          from wf_circuitos
         where estado <> 'F'
           and referencia = p_cod_persona
           and cod_tip_circuito = 48;
      exception
        when no_data_found then
          v_est_wf48 := 0;
        when others then
          v_est_wf48 := 0;
      end;*/
      -- UENP-1115 controlar solo CU 
      --IF (fug_val_con_uni_per(p_cod_persona) = 'N' or (v_est_doc > 0 and v_est_wf48 > 0 )) OR
     IF nvl(g_cod_error, '000') = '000' THEN
      IF fug_val_con_uni_per(p_cod_persona) = 'N' OR nvl(p_ind_blo_cta, 'F') = 'T' THEN
         
         pra_dbl_blq_cuentas(p_nro_cuenta        => p_nro_cta_acreditar,
                             p_monto             => p_mto_desembolsar,
                             p_tip_operacion     => 'B',
                             p_sub_tip_operacion => 'S',
                             p_cod_causa         => fug_obt_pardinamico('PRE_COD_CAU_BLO_CTA', 6, v_cod_modalidad),
                             p_cod_error         => v_cod_error,
                             p_msj_error         => v_msj_error); 
               
        --notificacion de bloqueo de saldo--
        if nvl(v_dir_mail, 'X') <> 'X' then
          begin
            v_asunto := 'Saldo Bloqueado por Desembolso para persona  ' ||
                        FUE_OBT_NOM_PERSONA(p_cod_persona);
            v_texto  := 'El saldo se encuentra bloqueado y la firma del CU debe ser regularizada.' ||
                        chr(10) || 'Cliente: ' || p_cod_persona || ' - ' ||
                        FUE_OBT_NOM_PERSONA(p_cod_persona) || chr(10) ||
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
        ------------------------------------
      END IF;
     END IF; 
    END IF;
   END IF;
  END IF;
  --
  IF nvl(g_cod_error, '000') <> '000' THEN
    p_cod_error := g_cod_error;
    p_msj_error := g_msj_error;
    rollback;
  ELSE
    g_cod_error  := '000';
    g_msj_error  := 'PROCESO CONCLUIDO CON EXITO.';
    p_nro_cuenta := v_nro_cuenta;
    p_cod_error  := g_cod_error;
    p_msj_error  := g_msj_error;
    --DA-6457
    IF p_destino IS NOT NULL THEN 
     it.prg_act_alias_cta(p_nro_cuenta,p_destino,'C',g_cod_error,g_msj_error);
    END IF;
    commit;
  END IF;
END;
/
