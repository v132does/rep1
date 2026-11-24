CREATE OR REPLACE PACKAGE BODY IT.PAG_DOM is

  PROCEDURE PR_TRA_ENV_EMAIL(p_para in varchar2,p_asunto in varchar2, p_mensaje in varchar2) IS
   -- Variables para mail
   v_hin_mail ge_ra_log_mail.hor_inicio%type;
   v_hfi_mail ge_ra_log_mail.hor_fin%type;
   v_det_error ge_ra_log_mail.det_error%type;
   PRAGMA AUTONOMOUS_TRANSACTION;
 BEGIN
   BEGIN
     v_hin_mail := to_char(sysdate, 'hh24:mi:ss');
     it_mail.mail(fug_obt_dir_correo, p_para, p_asunto, p_mensaje);
     v_hfi_mail := to_char(sysdate, 'hh24:mi:ss');
   EXCEPTION
     when others then
       v_det_error := substr(sqlerrm, 1, 4000);
       INSERT INTO ge_ra_log_mail
       (fec_envio, nom_archivo, dir_correo, mensaje,
        det_error, hor_inicio, hor_fin)
       VALUES
       (SYSDATE, null, p_para, substr(p_asunto||chr(10)|| p_mensaje,1,2000),
        substr(v_det_error,1,4000), v_hin_mail, v_hfi_mail);
     commit;
   END;
  END PR_TRA_ENV_EMAIL;

  /*Genera Datos para Creditos a Clientes Catastrados*/
  PROCEDURE PR_GEN_DAT_CREDITOS is
  --Variables--
  v_fec_actual    date;
  v_fec_anterior  date;
  v_fec_hor_insercion ge_movimientos.fec_insercion%type;
  v_cod_usuario ba_usuarios.cod_usuario%type;
  v_mto_sue_neto  ge_movimientos.monto%type;
  v_can_minutos   number(2);
  v_nro_cuenta ge_cuentas.nro_cuenta%type;
  v_can_sueldos number(6);
  v_cod_mon_cta ba_monedas.cod_moneda%type;
  v_tot_creditos ge_movimientos.monto%type;
  v_tot_debitos  ge_movimientos.monto%type;
  v_can_creditos number(6);
  v_can_debitos  number(6);
  v_ref_creditos varchar2(4000);
  v_ref_debitos  varchar2(4000);

  --Cursor Ctas Domiciliadas--
  cursor c_cta_domiciliadas is
    --Bancos--
    select a.nro_cuenta, a.nro_cta_beneficiario nro_cta_bco_destino,
           a.cod_per_pte_beneficiario,
           a.cod_persona,
           'Domicil. a Per.Ent:'||a.cod_per_pte_beneficiario||' Cta:'||a.nro_cta_beneficiario concepto
      from GE_DOM_BAN_CUENTAS a
     where a.estado = 'N';

  --Cursor de Pagos de Sueldos - Creditos--
  cursor c_pag_sueldos_dia is
    select x.fecha, x.hora, x.cod_usuario, x.cod_moneda, x.cod_modalidad,
           x.fec_insercion, x.monto mto_credito
      from ge_movimientos_ant x, ge_transacciones y
     where x.nro_cuenta = v_nro_cuenta
       and x.fecha = v_fec_anterior
       and x.cod_tra_padre = 303 --Pago de Sueldo--
       and x.cod_transaccion = 602 --Creditos recibidos--
       and x.reversado = 'N'
       and y.cod_transaccion = x.cod_transaccion
       and y.cod_modulo = x.cod_modulo
       and y.cod_modalidad = x.cod_modalidad
       and y.tipo = 'C' --Credito--
       and x.cod_modalidad in (31,41)
       and x.cod_mad_padre not in (455); --Excluido Transferencia SIPAP--

  --Cursor de Movimientos de Descuentos - Debitos--
  cursor c_mov_sueldos_dia is
    select x.fecha, x.hora, x.cod_usuario, x.cod_moneda, x.fec_insercion, x.monto mto_debito
      from ge_movimientos_ant x, ge_transacciones y
     where x.fecha = v_fec_anterior
       and x.nro_cuenta = v_nro_cuenta
       and x.reversado = 'N'
       and y.cod_transaccion = x.cod_transaccion
       and y.cod_modulo = x.cod_modulo
       and y.cod_modalidad = x.cod_modalidad
       and y.tipo = 'D' --Debito--
       and x.fec_insercion between v_fec_hor_insercion and (v_fec_hor_insercion + (v_can_minutos/24*60)) --2 min adelante--
       and x.cod_usuario = v_cod_usuario
       and x.cod_mad_padre not in (455) --Excluido Transferencia SIPAP--
       --Filtros relacionados a Procesos Aut. de Debitos--
       --Debito Aut. de TC--
       and ((x.cod_tra_padre IN (986, 186) and x.cod_transaccion = 503) or
       --Debito Aut. de Prestamos--
            (x.cod_tra_padre = 364 and x.cod_transaccion = 503) or
       --Debito Aut. de Deb. Pendientes--
            (x.cod_tra_padre = x.cod_transaccion));

  begin
    --Carga de Variables--
    v_can_minutos   := fug_obt_pardinamico('CAN_MIN_DOM_MOVIMIENTOS');
    v_fec_actual    := pag_cal.fu_obt_fec_actual(1);
    v_fec_anterior  := fug_obt_fec_anterior(1);

    --Elimina si existen registros ya generados--
    delete from ge_dom_ban_operaciones x where x.fec_proceso = v_fec_actual;

    --Cursor principal de Cuentas y Movimientos--
    for cue in c_cta_domiciliadas loop
        v_nro_cuenta := cue.nro_cuenta;
        v_ref_creditos := null;
        v_ref_debitos  := null;
        v_can_creditos := 0;
        v_can_debitos  := 0;
        v_tot_creditos := 0;
        v_tot_debitos := 0;
        v_mto_sue_neto := 0;
        v_can_sueldos := 0;
        v_cod_mon_cta := null;
        for sue in c_pag_sueldos_dia loop
            v_can_sueldos := v_can_sueldos + 1;
            if v_can_sueldos = 1 then
               v_cod_mon_cta := sue.cod_moneda;
            end if;
            v_fec_hor_insercion := sue.fec_insercion;
            v_cod_usuario := sue.cod_usuario;
            v_tot_creditos := nvl(v_tot_creditos,0) + nvl(sue.mto_credito,0);
            v_can_creditos := nvl(v_can_creditos,0) + 1;
            v_ref_creditos := substr(v_ref_creditos ||v_cod_usuario||'-'||to_char(v_fec_hor_insercion,'dd/mm/yyyy hh24:mi:ss')||'#',1,4000);
            for mov in c_mov_sueldos_dia loop
                v_tot_debitos := nvl(v_tot_debitos,0) + nvl(mov.mto_debito,0);
                v_can_debitos := nvl(v_can_debitos,0) + 1;
                v_ref_debitos := substr(v_ref_debitos ||mov.cod_usuario||'-'||to_char(mov.fec_insercion,'dd/mm/yyyy hh24:mi:ss')||'#',1,4000);
            end loop;
        end loop;
        v_mto_sue_neto := nvl(v_tot_creditos,0) - nvl(v_tot_debitos,0);
        if nvl(v_mto_sue_neto,0) > 0 then
           insert into ge_dom_ban_operaciones
           (nro_cta_debito, monto, estado, fec_proceso, nro_cta_beneficiario, for_Pago, cod_persona,
            cod_per_pte_beneficiario, cod_moneda, ind_valor, concepto,
            tot_creditos, tot_debitos, can_creditos, can_debitos, ref_creditos, ref_debitos)
           values
           (v_nro_cuenta, v_mto_sue_neto, 'G', v_fec_actual, cue.nro_cta_bco_destino, 'I', cue.cod_persona,
            cue.cod_per_pte_beneficiario, v_cod_mon_cta, 'N', cue.concepto, -- SPI-2 - Se modifica a N valor de IND_VALOR en base a MT102
            v_tot_creditos, v_tot_debitos, v_can_creditos, v_can_debitos, v_ref_creditos, v_ref_debitos);
        end if;
    end loop;
  exception
    when others then
         raise_application_error(-20065, 'Error en pag_dom.pr_gen_dat_creditos - ' || SQLERRM);
  end;

  /*Genera Datos de Transferencias SIPAP para Creditos*/
  PROCEDURE PR_GEN_SNP_MENSAJES IS
  --Variables Generales--
  rg_ge_snp_trans       pas_snp.rg_msj;
  v_error               varchar2(4000);
  v_cod_tip_ope_av      ge_snp_transferencias.cod_tip_operacion%type;
  v_cod_sub_tip_ope_av  ge_snp_transferencias.cod_sub_tip_operacion%type;
  v_cod_sub_tip_ope_bcp ge_snp_transferencias.cod_sub_tip_operacion%type;
  v_cod_mon_cta_debito  ge_cuentas.cod_moneda%type;
  v_nro_lote            varchar2(20);
  v_concepto            varchar2(1000);
  v_fec_actual          date;
  v_dir_beneficiario    ge_snp_transferencias.dir_beneficiario%type;
  v_mto_max number      := fug_obt_pardinamico('SPI_MTO_MAX');
  v_cod_mon_hab         varchar2(10) := fug_obt_pardinamico('SPI_COD_MON_HABILITADO');

  --Cursor de Pagos a Transferir generado en el Cierre--
  cursor c_gen_mensajes is
    select a.*, a.rowid registro,
           a.cod_persona cod_per_solicitante,
           c.nom_completo nom_solicitante,
           c.cod_tip_documento cod_tip_doc_solicitante,
           c.nro_documento nro_doc_solicitante
      from ge_dom_ban_operaciones a, ba_personas c
     where a.estado = 'G' --Estado Generado--
       and a.fec_proceso <= v_fec_actual
       and a.for_pago = 'I' --Transferencia Interbancaria--
       and c.cod_persona = a.cod_persona;
  begin
  --Carga de Variables--
   v_fec_actual := pag_cal.FU_OBT_FEC_ACTUAL(1);
   v_cod_tip_ope_av                  := '011';-- SPI-2 - Se modifica valor en base a MT102
   v_cod_sub_tip_ope_av              := '001';-- SPI-2 - Se modifica valor en base a MT102
   rg_ge_snp_trans.tip_cargo         := 'BEN'; --Beneficiario--
   rg_ge_snp_trans.cod_modulo        := pas_snp.fu_obt_cod_mod_padre;
   rg_ge_snp_trans.cod_modalidad     := pas_snp.fu_obt_cod_mad_padre;
   rg_ge_snp_trans.tip_mensaje       := 'CRED';
   rg_ge_snp_trans.origen            := 'I'; --ITGF--
   rg_ge_snp_trans.plataforma        := 'X'; --X-ADAPTER--
   rg_ge_snp_trans.indemnizado       := 'N'; --Pago Indemnizado--
   rg_ge_snp_trans.cod_swi_pte_solicitante := pas_snp.fu_obt_cod_swi_participante(fug_obt_per_entidad);
   v_nro_lote := 0;

   --Inicio del Ciclo para Generacion de Mensajes--
   for reg in c_gen_mensajes loop
      --Limpieza de Variables--
      v_error                                  := null;
      rg_ge_snp_trans.nro_referencia           := null;
      rg_ge_snp_trans.fecha                    := null;
      rg_ge_snp_trans.hora                     := null;
      rg_ge_snp_trans.cod_usuario              := null;
      rg_ge_snp_trans.fec_valor                := null;
      rg_ge_snp_trans.situacion                := null;
      rg_ge_snp_trans.estado                   := null;
      rg_ge_snp_trans.nro_cta_solicitante      := null;
      v_cod_mon_cta_debito                     := null;
      rg_ge_snp_trans.cod_oficina              := null;
      rg_ge_snp_trans.ind_valor                := null;
      rg_ge_snp_trans.cod_msj_swift            := null;
      rg_ge_snp_trans.cod_tip_operacion        := null;
      rg_ge_snp_trans.cod_sub_tip_operacion    := null;
      rg_ge_snp_trans.fec_ingreso              := null;
      rg_ge_snp_trans.cod_moneda               := null;
      rg_ge_snp_trans.monto                    := null;
      rg_ge_snp_trans.nro_cta_pte_solicitante  := null;
      rg_ge_snp_trans.cod_tip_doc_beneficiario := null;
      rg_ge_snp_trans.nro_doc_beneficiario     := null;
      rg_ge_snp_trans.cod_per_beneficiario     := null;
      rg_ge_snp_trans.nom_beneficiario         := null;
      rg_ge_snp_trans.dir_beneficiario         := null;
      rg_ge_snp_trans.nro_cta_beneficiario     := null;
      rg_ge_snp_trans.cod_swi_pte_beneficiario := null;
      rg_ge_snp_trans.nro_cta_pte_beneficiario := null;
      rg_ge_snp_trans.concepto                 := null;
      rg_ge_snp_trans.prioridad                := null;
      rg_ge_snp_trans.msj_swift                := null;
      rg_ge_snp_trans.ben_dir_correo           := null;
      rg_ge_snp_trans.cod_tra_padre            := null;
      pas_snp.g_msj_error                      := null;

      --Carga de Variables--
      v_cod_sub_tip_ope_bcp := nvl(fug_obt_pardinamico('SNP_SUB_TIP_OPE_TRA_BCP'),'005');  -- DDSI-62
      rg_ge_snp_trans.nro_referencia := pas_snp.fu_obt_sig_nro_referencia;
      rg_ge_snp_trans.nro_operacion := rg_ge_snp_trans.nro_referencia;
      rg_ge_snp_trans.situacion := 'P';
      rg_ge_snp_trans.estado := 'A';
      rg_ge_snp_trans.cod_per_solicitante := reg.cod_per_solicitante;
      rg_ge_snp_trans.nom_solicitante  := reg.nom_solicitante;
      rg_ge_snp_trans.cod_tip_doc_solicitante := reg.cod_tip_doc_solicitante;
      rg_ge_snp_trans.nro_doc_solicitante := reg.nro_doc_solicitante;

      --Obtengo datos de la cta de débito una sola vez
      if nvl(rg_ge_snp_trans.nro_cta_solicitante, 'X') != reg.nro_cta_debito then
         rg_ge_snp_trans.nro_cta_solicitante := reg.nro_cta_debito;
         pag_cta.pr_obt_cuenta(rg_ge_snp_trans.nro_cta_solicitante);
         v_cod_mon_cta_debito := pag_cta.g_ctas.cod_moneda;
         rg_ge_snp_trans.cod_oficina := pag_cta.g_ctas.cod_oficina;
         if pag_cta.fu_obt_cod_error <> 0 then
           v_error := substr(pag_cta.fu_obt_msj_error,1,4000);
           goto siguiente_registro;
         end if;
      end if;

      --Hallo el swift de la entidad de destino -- SPI-2
      begin
        select b.cod_swift
          into rg_ge_snp_trans.cod_swi_pte_beneficiario
          from gv_snp_participantes b
         where b.cod_persona = reg.cod_per_pte_beneficiario
           and pas_snp.fu_obt_cta_ban_participante(b.cod_swift, reg.cod_moneda) is not null;
      exception
          when others then
             v_error := substr('ERROR AL HALLAR SWIFT DE ENTIDAD '||reg.cod_per_pte_beneficiario||': '||sqlerrm,1,4000);
             --goto siguiente_registro;
      end;

      --Se toma como A-Alto Valor solo si supera variable de SPI
      rg_ge_snp_trans.ind_valor := reg.ind_valor;
      If reg.monto <= v_mto_max and reg.cod_moneda = v_cod_mon_hab
        -- and pas_spi.fu_val_ente_habilitado(rg_ge_snp_trans.cod_swi_pte_beneficiario) = 'S' then
        and pas_spi.fu_obt_tra_spi(rg_ge_snp_trans.cod_moneda,rg_ge_snp_trans.monto,'N',rg_ge_snp_trans.cod_swi_pte_beneficiario) = 'S' then
       rg_ge_snp_trans.cod_msj_swift := 102;
       v_cod_tip_ope_av              := '011';
       v_cod_sub_tip_ope_av          := '001';
       rg_ge_snp_trans.ind_valor     := 'N';
      Else
       rg_ge_snp_trans.cod_msj_swift := 103;
       v_cod_tip_ope_av              := '001';
       v_cod_sub_tip_ope_av          := '002';
       rg_ge_snp_trans.ind_valor     := 'S';
      End if;
      rg_ge_snp_trans.cod_tip_operacion := v_cod_tip_ope_av;
      rg_ge_snp_trans.cod_sub_tip_operacion := v_cod_sub_tip_ope_av;
      rg_ge_snp_trans.fec_ingreso := v_fec_actual;
      rg_ge_snp_trans.fec_valor := v_fec_actual;
      rg_ge_snp_trans.cod_moneda := reg.cod_moneda;
      rg_ge_snp_trans.monto := reg.monto;
      rg_ge_snp_trans.nro_cta_pte_solicitante := pas_snp.fu_obt_cta_ban_participante(rg_ge_snp_trans.cod_swi_pte_solicitante,
                                                                                     rg_ge_snp_trans.cod_moneda);

      --Obtener Datos del Beneficiario--
      v_dir_beneficiario := fue_obt_dir_principa(reg.cod_persona);

      --Datos del Beneficiario--
      --rg_ge_snp_trans.cod_tip_doc_beneficiario := reg.cod_tip_doc_beneficiario;
      rg_ge_snp_trans.cod_tip_doc_beneficiario := reg.cod_tip_doc_solicitante;

      --rg_ge_snp_trans.nro_doc_beneficiario := reg.nro_doc_beneficiario;
      rg_ge_snp_trans.nro_doc_beneficiario := reg.nro_doc_solicitante;

      --rg_ge_snp_trans.cod_per_beneficiario := fue_obt_cod_persona(reg.nro_doc_beneficiario);
      rg_ge_snp_trans.cod_per_beneficiario := reg.cod_persona;

      --rg_ge_snp_trans.nom_beneficiario := reg.beneficiario;
      rg_ge_snp_trans.nom_beneficiario := reg.nom_solicitante;

      --rg_ge_snp_trans.dir_beneficiario := reg.dir_beneficiario;
      rg_ge_snp_trans.dir_beneficiario := v_dir_beneficiario;

      rg_ge_snp_trans.nro_cta_beneficiario := reg.nro_cta_beneficiario;
      rg_ge_snp_trans.ben_dir_correo := substr(reg.ben_dir_correo, 1, 80);

      --Inicio de Validaciones--
      if rg_ge_snp_trans.cod_tip_doc_beneficiario is null then
        v_error := substr('ERROR. CODIGO DE TIPO DE DOCUMENTO BENEFICIARIO NO PUEDE SER NULO',1,4000);
        goto siguiente_registro;
      end if;
      --
      if rg_ge_snp_trans.nro_doc_beneficiario is null then
        v_error := substr('ERROR. NUMERO DE DOCUMENTO BENEFICIARIO NO PUEDE SER NULO',1,4000);
        goto siguiente_registro;
      end if;
      --
      if rg_ge_snp_trans.nom_beneficiario is null then
        v_error := substr('ERROR. NOMBRE BENEFICIARIO NO PUEDE SER NULO',1,4000);
        goto siguiente_registro;
      end if;
      --
      if rg_ge_snp_trans.nro_cta_beneficiario is null then
        v_error := substr('ERROR. NUMERO DE CUENTA BENEFICIARIO NO PUEDE SER NULO',1,4000);
        goto siguiente_registro;
      end if;

     --Si es 102 y la moneda destino es en USD
     if rg_ge_snp_trans.cod_msj_swift= 102
         and rg_ge_snp_trans.cod_moneda <> pag_gen.FU_OBT_MON_LOCAL then
         v_error := substr('ERROR. para MT 102 - Debe ser moneda local',1,4000);
         goto siguiente_registro;
     end if;
      --Hallo el swift de la entidad de destino -- SPI-2 - Se adelanta este calculo a la linea 265 para validacion de parametros SPI
 /*     begin
        select b.cod_swift
          into rg_ge_snp_trans.cod_swi_pte_beneficiario
          from gv_snp_participantes b
         where b.cod_persona = reg.cod_per_pte_beneficiario
           and pas_snp.fu_obt_cta_ban_participante(b.cod_swift, reg.cod_moneda) is not null;
      exception
          when others then
             v_error := substr('ERROR AL HALLAR SWIFT DE ENTIDAD '||reg.cod_per_pte_beneficiario||': '||sqlerrm,1,4000);
             goto siguiente_registro;
      end;*/

      --  Si es BCP hay que cambiar el sub tipo de operación a 005
      IF rg_ge_snp_trans.cod_swi_pte_beneficiario = nvl(fug_obt_pardinamico('SNP_BIC_BCP'),'X') THEN
         rg_ge_snp_trans.cod_sub_tip_operacion := v_cod_sub_tip_ope_bcp; -- DDSI-62
         -- No se pueden hacer transferencias por lotes al BCP
         IF rg_ge_snp_trans.cod_tip_operacion = '011' THEN
            v_error := substr('La prioridad de envío no está permitida para transferencias al BCP.',1,4000);
            goto siguiente_registro;
         END IF;
      END IF;
      rg_ge_snp_trans.nro_cta_pte_beneficiario := pas_snp.fu_obt_cta_ban_participante(rg_ge_snp_trans.cod_swi_pte_beneficiario,
                                                                                     rg_ge_snp_trans.cod_moneda);

      if rg_ge_snp_trans.nro_cta_pte_beneficiario is null then
        v_error := substr('ERROR. Cta. Pte. Beneficiario nulo para código swift: '
        ||rg_ge_snp_trans.cod_swi_pte_beneficiario||' Moneda: '||rg_ge_snp_trans.cod_moneda,1,4000);
        goto siguiente_registro;
      end if;

      rg_ge_snp_trans.concepto := trim(substr(trim(v_concepto),1,100));
      rg_ge_snp_trans.cod_tra_padre := 303; -- Transaccion Normal--

      begin
        select m.prioridad
          into rg_ge_snp_trans.prioridad
          from ge_snp_par_mensajes m
         where m.cod_msj_swift = rg_ge_snp_trans.cod_msj_swift
           and m.cod_tip_operacion = rg_ge_snp_trans.cod_tip_operacion
           and m.cod_sub_tip_operacion = rg_ge_snp_trans.cod_sub_tip_operacion
           and m.cod_tra_padre = 303 ; -- Transacción Padre de Pago a Proveedores
      exception
          when others then
             v_error := substr('ERROR AL HALLAR PRIORIDAD: '||sqlerrm,1,4000);
             goto siguiente_registro;
      end;

      begin
         pas_snp.pr_ins_transferencias(rg_ge_snp_trans);--
         if pas_snp.fu_obt_cod_error <> 0 then
           v_error := substr(pas_snp.fu_obt_msj_error,1,4000);
           goto siguiente_registro;
         end if;--
      exception
        when others then
           v_error := substr('ERROR AL INSERTAR TRANSFERENCIA: '||sqlerrm,1,4000);
           goto siguiente_registro;
      end;
      --Si es alto valor recupero
      if rg_ge_snp_trans.cod_msj_swift = 103 then
         begin
           rg_ge_snp_trans.msj_swift := pas_snp.fu_obt_msj_mt103(rg_ge_snp_trans.nro_referencia);
           if pas_snp.fu_obt_cod_error <> 0 then
             v_error := substr('OBTENER MENSAJERÍA: '||pas_snp.fu_obt_msj_error,1,4000);
             goto siguiente_registro;
           end if;
         exception
            when others then
               v_error := substr('OBTENER MENSAJERÍA: '||sqlerrm,1,4000);
               goto siguiente_registro;
         end;

         begin
           update ge_snp_transferencias
              set msj_swift = rg_ge_snp_trans.msj_swift
            where nro_referencia = rg_ge_snp_trans.nro_referencia;
         exception
            when others then
               v_error := substr('ACTUALIZAR GE_SNP_TRANSFERENCIAS: '||sqlerrm,1,4000);
               goto siguiente_registro;
         end;
      end if;

      <<siguiente_registro>>
      if v_error is null then
        begin
           update ge_dom_ban_operaciones k
              set k.nro_referencia  = rg_ge_snp_trans.nro_referencia,
                  k.nro_documento   = rg_ge_snp_trans.nro_referencia,
                  k.estado          = 'N',
                  k.fec_tra_snp     = v_fec_actual,
                  k.dir_beneficiario = v_dir_beneficiario,
                  k.cod_tip_doc_beneficiario = reg.cod_tip_doc_solicitante,
                  k.nro_doc_beneficiario = reg.nro_doc_solicitante,
                  k.beneficiario = reg.nom_solicitante
            where k.rowid = reg.registro;
        exception
          when others then
             v_error := substr('ERROR AL ACTUALIZAR PAGO: '||sqlerrm,1,4000);
             update ge_dom_ban_operaciones k
                set k.estado = 'C', --Cancelado por algun error--
                    k.error = substr(v_error,1,4000)
              where k.rowid = reg.registro;
        end;
      else
        update ge_dom_ban_operaciones k
           set k.estado = 'C', --Cancelado por algun error--
               k.error = substr(v_error,1,4000)
         where k.rowid = reg.registro;
      end if;
   end loop;
  EXCEPTION
    WHEN OTHERS THEN
         raise_application_error(-20002,'Error en pag_dom.pr_gen_snp_mensajes - '||sqlerrm);
  end;

  /*Actualiza Datos para Creditos a Clientes Catastrados*/
  PROCEDURE PR_ACT_DAT_CREDITOS is
  --Variables--
  v_fec_actual    date;
  v_mensaje varchar2(4000);

  begin
    --Carga de Variables--
    v_fec_actual    := pag_cal.fu_obt_fec_actual(1);

    --Actualizacion de Trnsferencias Liquidadas--
    v_mensaje := 'Transaferencias Liquidadas ok';
    update ge_dom_ban_operaciones k
       set (k.estado, k.est_tra_snp, k.sit_tra_snp,
            k.fec_mov_pago, k.hor_mov_pago, k.usu_mov_pago) =
           (select 'P', x.estado, x.situacion,
                   x.fecha, x.hora, x.cod_usuario
              from ge_snp_transferencias x
             where x.nro_referencia = k.nro_referencia
               and x.estado = 'A' --Aprobado--
               and x.situacion = 'L')
     where k.estado = 'N'
       and k.nro_referencia is not null
       and k.est_tra_snp is null
       and k.fec_tra_snp <= v_fec_actual
       and exists (select 1
                     from ge_snp_transferencias x
                    where x.nro_referencia = k.nro_referencia
                      and x.estado = 'A' --Aprobado--
                      and x.situacion = 'L'); --Liquidado--

    --Actualizacion de Trnsferencias No Liquidadas--
    v_mensaje := 'Transaferencias Generadas y No Liquidadas';
    update ge_dom_ban_operaciones k
       set (k.estado, k.est_tra_snp, k.sit_tra_snp, k.error) =
           (Select 'C', x.estado, x.situacion, x.error
              from ge_snp_transferencias x
             where x.nro_referencia = k.nro_referencia)
     where k.estado = 'N'
       and k.nro_referencia is not null
       and k.est_tra_snp is null
       and k.fec_tra_snp <= v_fec_actual
       and exists (select 1
                     from ge_snp_transferencias x
                    where x.nro_referencia = k.nro_referencia); --Liquidada--

    --Actualizacion de Trnsferencias Resto de Operaciones--
    v_mensaje := 'Transaferencias Canceladas';
    update ge_dom_ban_operaciones k
       set k.estado = 'C' --Cancelado--
     where k.nro_referencia is null
       and k.est_tra_snp is null
       and k.fec_proceso <= v_fec_actual
       and k.estado not in ('P','C');

  exception
    when others then
         raise_application_error(-20065, 'Error en '||v_mensaje||' - '|| SQLERRM);
  end;

 /*Envio de Emails por Domiciliacion*/
 PROCEDURE PR_ENV_EMA_GENERAL IS
  --Variables--
  v_fec_actual      DATE;
  v_can_domicil    number(6);
  v_can_detalles    number(6);
  v_asunto varchar2(200);
  v_lugar varchar2(200);
  v_mensaje varchar2(4000);
  v_linea varchar2(4000);
  v_lon_texto number(4);
  v_lon_linea number(4);
  v_para       VARCHAR2(4000);
  v_cod_usu_oficial ge_clientes.cod_usu_oficial%type;
  v_nombre ba_usuarios.nombre%type;
  v_dir_correo ba_usuarios.dir_correo%type;
  v_cod_usu_general ba_usuarios.cod_usuario%type;

  cursor c_dir_envios is
    select distinct b.cod_usu_oficial, c.nombre, c.dir_correo
      from ge_dom_ban_operaciones a, ge_clientes b, ba_usuarios c
     where a.fec_proceso = v_fec_actual
       and b.cod_persona = a.cod_persona
       and c.cod_usuario = b.cod_usu_oficial
    union all
    select v_cod_usu_general, v_cod_usu_general, fug_obt_pardinamico('ENV_EMA_AVI_DOMICIL')
      from dual;

   --Cursor Principal--
  cursor c_ope_dom_cab is
    select '**Totales**' linea
      from dual
    union all
    select '============' linea
      from dual
    union all
    select rpad('Tipo',10,' ')||chr(9)||
           rpad('Mon',3,' ')||chr(9)||
           lpad('Cant.',7,' ')||chr(9)||
           lpad('Monto',18,' ') linea
      from dual
    union all
    select rpad(substr('TOTAL',1,6),10,' ')||chr(9)||
           rpad(a.cod_moneda,3,' ')||chr(9)||
           lpad(trim(to_char(nvl(count(*),0),'999,999')),7,' ')||chr(9)||
           lpad(decode(a.cod_moneda,'GS',trim(to_char(sum(nvl(a.monto,0)),'999,999,999,990')),trim(to_char(sum(nvl(a.monto,0)),'999,999,999,990.99'))),18,' ') linea
      from ge_dom_ban_operaciones a, ge_clientes y
     where a.fec_proceso = v_fec_actual
       and y.cod_persona = a.cod_persona
       and ((y.cod_usu_oficial = v_cod_usu_oficial) or (v_cod_usu_oficial = v_cod_usu_general))
    group by '999', 'TOTAL', a.cod_moneda
    union all
    select chr(10)||'**Detalles**' linea
      from dual
    union all
    select '============' linea
      from dual
    union all
    select rpad('Nro.',4,' ')||chr(9)||
           rpad('Cliente',7,' ')||chr(9)||
           rpad('Ref. SIPAP',18,' ')||chr(9)||
           rpad('Cta Debito',15,' ')||chr(9)||
           rpad('Ent.Dest',8,' ')||chr(9)||
           rpad('Cta.Benef.',10,' ')||chr(9)||
           rpad('Mon',3,' ')||chr(9)||
           rpad('Monto',10,' ')||chr(9)||
           rpad('Estado',6,' ')||chr(9)||
           lpad('Est.SIPAP',9,' ')||chr(9)||
           lpad('Sit.SIPAP',9,' ') linea
      from dual;

  cursor c_ope_dom_det is
    select rownum||chr(9)||
           x.cod_persona||chr(9)||
           a.nro_referencia||chr(9)||
           a.nro_cta_debito||chr(9)||
           substr(fue_obt_nom_persona(a.cod_per_pte_beneficiario),1,10)||chr(9)||
           a.nro_cta_beneficiario||chr(9)||
           a.cod_moneda||chr(9)||
           decode(a.cod_moneda,'GS',trim(to_char(a.monto,'999,999,999,990')),trim(to_char(a.monto,'999,999,999,990.99')))||chr(9)||
           substr(a.estado||'-'||initcap(fue_obt_des_refcodes('EST_DOMICILIACION',a.estado)),1,5)||chr(9)||
           substr(a.est_tra_snp||'-'||initcap(fue_obt_des_refcodes('EST_MSJ_SNP',a.est_tra_snp)),1,5)||chr(9)||
           substr(a.sit_tra_snp||'-'||initcap(fue_obt_des_refcodes('SITUACION',a.sit_tra_snp)),1,5) linea
      from ge_dom_ban_operaciones a, ba_personas x, ge_clientes y
     where a.fec_proceso = v_fec_actual
       and x.cod_persona = a.cod_persona
       and y.cod_persona = a.cod_persona
       and ((y.cod_usu_oficial = v_cod_usu_oficial) or (v_cod_usu_oficial = v_cod_usu_general))
     order by rownum, x.cod_persona, a.cod_moneda, a.monto;
 BEGIN

  v_fec_actual := pag_cal.fu_obt_fec_actual(3);
  v_cod_usu_general := 'GENERAL';

   --Verificacion Operaciones a Vencer - Por Oficiales--
  for ges in c_dir_envios loop
      v_cod_usu_oficial := ges.cod_usu_oficial;
      v_nombre := ges.nombre;
      v_dir_correo := ges.dir_correo;
      v_para := null;
      v_asunto := null;
      v_mensaje := null;
      v_can_domicil := 0;

      select nvl(count(*),0)
        into v_can_domicil
        from ge_dom_ban_operaciones a, ge_clientes y
     where a.fec_proceso = v_fec_actual
       and y.cod_persona = a.cod_persona
       and ((y.cod_usu_oficial = v_cod_usu_oficial)
         or (v_cod_usu_oficial = v_cod_usu_general));

      if nvl(v_can_domicil,0) > 0 then
         --Enviar e-mails a los grupo y otros--
         v_lon_texto := 0;
         FOR cab in c_ope_dom_cab LOOP
             v_linea := trim(cab.linea);
             v_lugar := v_linea;
             v_lon_linea := length(v_linea);
             if (v_lon_texto + v_lon_linea) > 3500 then
                exit;
             else
                v_lon_texto := v_lon_texto + v_lon_linea + 1;
                v_mensaje := v_mensaje||v_linea||chr(10);
             end if;
         END LOOP;
         v_can_detalles := 0;
         FOR det in c_ope_dom_det LOOP
             v_can_detalles := nvl(v_can_detalles,0) + 1;
             v_linea := trim(det.linea);
             v_lugar := v_linea;
             v_lon_linea := length(v_linea);
             if (v_lon_texto + v_lon_linea) > 3500 then
                exit;
             else
                v_lon_texto := v_lon_texto + v_lon_linea + 1;
                v_mensaje := v_mensaje||v_linea||chr(10);
             end if;
             if ((v_can_detalles = 10) and (v_can_domicil > 10)) then
                --Concatena texto y sale--
                v_mensaje := v_mensaje||chr(10)||
                'Obs: Existen otras ('||to_char(nvl(v_can_domicil,0)-nvl(v_can_detalles,0))||') Operaciones'||chr(10)||
                'Para ver estos, generar los listados detallados de control.';
                exit;
             end if;
         END LOOP;

         --Envio de Emails--
         v_para := v_dir_correo;
         if ((v_mensaje is not null) and (v_para is not null)) then
            v_asunto := 'DOMICILIACION : '||trim(to_char(v_can_domicil))||' Operaciones - '||
                        replace(v_cod_usu_oficial,'GENERAL','Total')||' '||initcap(v_nombre);
            PAG_DOM.PR_TRA_ENV_EMAIL(V_PARA, V_ASUNTO, V_MENSAJE);
         end if;
       end if;
   end loop;
  END PR_ENV_EMA_GENERAL;

  PROCEDURE PR_GEN_DAT_INICIO IS
  BEGIN
    --Generar Datos para Creditos--
    PAG_DOM.PR_GEN_DAT_CREDITOS;
    --Genear Mens. SIPAP de Transferencias--
    PAG_DOM.PR_GEN_SNP_MENSAJES;
  END PR_GEN_DAT_INICIO;

  PROCEDURE PR_ACT_DAT_CIERRE IS
  BEGIN
    --Actualizar los datos de Creditos del Dia--
    PAG_DOM.PR_ACT_DAT_CREDITOS;
    --Envia Emails de Informe de Operaciones--
    PAG_DOM.PR_ENV_EMA_GENERAL;
  END PR_ACT_DAT_CIERRE;

END PAG_DOM;
/

