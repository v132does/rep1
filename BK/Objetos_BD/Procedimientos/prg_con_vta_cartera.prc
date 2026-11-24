CREATE OR REPLACE PROCEDURE IT.PRG_CON_VTA_CARTERA (P_RUC_COMPRADOR IN GE_SAL_INV_VTA_CARTERA_TMP.RUC_COMPRADOR%TYPE,
                                                 P_NOM_COMPRADOR IN GE_SAL_INV_VTA_CARTERA_TMP.NOM_COMPRADOR%TYPE,
                                                 P_MON_VENTA IN GE_SAL_INV_VTA_CARTERA_TMP.MON_VENTA%TYPE,
                                                 P_REF_LOTE IN NUMBER,
                                                 P_PROCESADO OUT VARCHAR2,
                                                 P_COD_ENTE IN GE_ENTES.COD_ENTE%TYPE) IS

  v_fec_actual  date := pag_cal.FU_OBT_FEC_ACTUAL(1);
  -- Variables para mail
  v_conn                   utl_smtp.connection;
  v_para                   VARCHAR2(500);
  v_asunto                 VARCHAR2(2000);
  v_mje_mail               VARCHAR2(4000);
  v_hini_mail              ge_ra_log_mail.hor_inicio%type;
  v_hfin_mail              ge_ra_log_mail.hor_fin%type;
  v_det_error              ge_ra_log_mail.det_error%type;
  v_cant_tarjetas          number;
  v_modulo                 ge_fil_vta_cartera.modulo%type;
  v_dir_correo_para_user   VARCHAR2(200);
       
cursor c_vta_cartera is
    select *
      from ge_sal_inv_vta_cartera_tmp a
     where estado = 'N'
       and ref_lote = p_ref_lote;      
      
procedure pro_inhibe_personas is
   cursor c_inh_personas is
     select distinct (cod_persona) cod_persona 
       from ge_sal_inv_vta_cartera_tmp
      where ref_lote = p_ref_lote;
      
   v_codeudor pr_cta_garantias.nro_garantia%type;   
   cursor c_inh_codeudor(p_cod_persona in ge_cta_clientes.cod_persona%type) is
    select b.nro_garantia
      from ge_cta_clientes a, pr_cta_garantias b
     where a.nro_cuenta = b.nro_cuenta
       and b.cod_garantia = 2
       and a.cod_persona = p_cod_persona
    union
    select b.nro_garantia
      from ge_cta_clientes a, ta_cta_garantias b
     where a.nro_cuenta = b.nro_cuenta
       and b.cod_garantia = 2
       and a.cod_persona = p_cod_persona;
 Begin          
     for i In c_inh_personas loop 
          begin  
            it.prg_ins_per_inhibidos(pae_cnf.fu_obt_fec_actual('6'),
                                     user,
                                     i.cod_persona,
                                     354,
                                     'VENTA DE CARTERA',
                                     'Cliente excluido por proceso de venta de cartera',
                                     'I');
          --Proceso para inhibir a codeudores de la cuenta vendida
          for c in c_inh_codeudor(i.cod_persona) loop
            v_codeudor := c.nro_garantia;
            if v_codeudor is not null then
              it.prg_ins_per_inhibidos(pae_cnf.fu_obt_fec_actual('6'),
                                       user,
                                       v_codeudor,
                                       354,
                                       'VENTA DE CARTERA',
                                       'Cliente excluido por proceso de venta de cartera',
                                       'I');
            end if;
          end loop;
          exception 
            when others then
                  raise_application_error(-20000,'Error al inhibir persona: '||sqlerrm);
          end;                                  
      end loop;           
END;            

BEGIN
  P_PROCESADO := 'NO';
  v_cant_tarjetas := 0;
  select modulo into v_modulo from ge_fil_vta_cartera where ref_lote = p_ref_lote;

  begin
    --se guardan los campos de ruc y nombre comprador, monto y usuario de venta en el TMP
    update ge_sal_inv_vta_cartera_tmp a
       set a.ruc_comprador = p_ruc_comprador,
           a.nom_comprador = p_nom_comprador,
           a.mon_venta     = p_mon_venta,
           a.usu_venta     = user,
           a.cod_ente = p_cod_ente
     where a.estado = 'N'
       and a.ref_lote = P_REF_LOTE;
  Exception
     When others Then
          raise_application_error(-20000,'Error al actualizar Ruc y Comprador '||sqlerrm);
  end;
  begin
    --se carga los registros en la tablar pr_vta_cartera para cancelacion
    for reg in c_vta_cartera loop
      If reg.cod_modulo <> 5 and reg.estado = 'N' Then
          insert into pr_vta_cartera (cod_persona    , nro_cuenta    , tipo_deuda)
                              values (reg.cod_persona, reg.nro_cuenta, (case reg.cod_modulo when 6 then 'P'
                                                                                            when 4 then 'S'
                                                                                            when 15 then 'V'
                                                                        end));
      Elsif reg.cod_modulo = 5 and reg.estado = 'N' Then
          v_cant_tarjetas := v_cant_tarjetas+1;
      End IF;
     
         begin
           insert into ge_cta_dat_adicionales
             (nro_cuenta, parametro, val_parametro)
           values
             (reg.nro_cuenta, 'ENT_ADM_CARTERA', p_cod_ente||' - '||p_nom_comprador);
          exception
           when others then
              raise_application_error(-20000,'Error al enviar al insertar datos ENT_ADM_CARTERA '||sqlerrm);    
         end;
    end loop;
  end;
  begin --Envía al Historial lo excluido de la cartera
    insert into ge_sal_inv_vta_cartera_his t (t.fecha,
                                             t.cod_persona,
                                             t.nom_completo,
                                             t.nro_documento,
                                             t.cli_nomina,
                                             t.fec_ult_acreditacion,
                                             t.cod_oficina,
                                             t.nro_cuenta,
                                             t.tip_producto,
                                             t.nro_tarjeta,
                                             t.afinidad,
                                             t.cod_per_codeudor,
                                             t.gestor,
                                             t.mto_deuda,
                                             t.mto_previsiones,
                                             t.dia_atrasos,
                                             t.cat_cliente,
                                             t.tot_riesgo,
                                             t.fec_ult_cat_sistema,
                                             t.cat_sistema,
                                             t.tot_deu_sistema,
                                             t.tot_deu_con_sistema,
                                             t.tot_deu_cod_sistema,
                                             t.tot_cuotas,
                                             t.tot_cuo_vencidas,
                                             t.tel_particular,
                                             t.dir_particular,
                                             t.tel_laboral,
                                             t.dir_laboral,
                                             t.gar_cliente,
                                             t.gar_ven_cliente,
                                             t.gar_codeudor,
                                             t.gar_ven_codeudor,
                                             t.tip_bloqueo,
                                             t.tip_inhibicion,
                                             t.estado,
                                             t.cod_modulo,
                                             t.cod_modalidad,
                                             t.mot_exclucion,
                                             t.usu_exclucion,
                                             t.observacion,
                                             t.ruc_comprador,
                                             t.nom_comprador,
                                             t.ref_lote,
                                             t.hor_cancelacion,
                                             t.mon_venta,
                                             t.usu_venta,
                                             t.fec_venta,
                                             t.ope_recaptados,
                                             t.mot_reingreso,
                                             t.usu_reingreso,
                                             t.obs_reingreso,
                                             t.mto_deu_mon_cuenta,
                                             t.sal_deu_cta_actual,
                                             t.dia_atr_actual,
                                             t.cat_ope_actual,
                                             t.cat_cli_ponderada,
                                             t.cod_ente)
      select a.fecha,
             a.cod_persona,
             a.nom_completo,
             a.nro_documento,
             a.cli_nomina,
             a.fec_ult_acreditacion,
             a.cod_oficina,
             a.nro_cuenta,
             a.tip_producto,
             a.nro_tarjeta,
             a.afinidad,
             a.cod_per_codeudor,
             a.gestor,
             a.mto_deuda,
             a.mto_previsiones,
             a.dia_atrasos,
             a.cat_cliente,
             a.tot_riesgo,
             a.fec_ult_cat_sistema,
             a.cat_sistema,
             a.tot_deu_sistema,
             a.tot_deu_con_sistema,
             a.tot_deu_cod_sistema,
             a.tot_cuotas,
             a.tot_cuo_vencidas,
             a.tel_particular,
             a.dir_particular,
             a.tel_laboral,
             a.dir_laboral,
             a.gar_cliente,
             a.gar_ven_cliente,
             a.gar_codeudor,
             a.gar_ven_codeudor,
             a.tip_bloqueo,
             a.tip_inhibicion,
             a.estado,
             a.cod_modulo,
             a.cod_modalidad,
             a.mot_exclucion,
             a.usu_exclucion,
             a.observacion,
             a.ruc_comprador,
             a.nom_comprador,
             a.ref_lote,
             a.hor_cancelacion,
             a.mon_venta,
             a.usu_venta,
             v_fec_actual,
             'N',
             null,
             null,
             null,
             nvl(
             round(nvl(a.mto_deuda, 0) /
                   fug_obt_cotizacion(fug_obt_mon_cta(a.nro_cuenta),
                                      a.fecha),
                   to_number(fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                                                 NULL,
                                                 NULL,
                                                 fug_obt_mon_cta(a.nro_cuenta)))), a.mto_deuda),
             null,
             null,
             null,
             null,
             a.cod_ente
        from ge_sal_inv_vta_cartera_tmp a
       where a.estado = 'E'
         and a.ref_lote = P_REF_LOTE;
  Exception
     When others Then
          raise_application_error(-20000,'Error al enviar al Historial lo excluído '||sqlerrm);
  end;
  IF INSTR(v_modulo, '#5') <> 0 THEN
      begin --Se cambian de estado las tarjetas
        update ge_sal_inv_vta_cartera_tmp
           set estado = 'C' --Confirmado, para procesar desde la pantalla OPENVARC
         where estado = 'N'
           and cod_modulo = 5
           and ref_lote = P_REF_LOTE;
      Exception
         When others Then
              raise_application_error(-20000,'Error al cambiar de estado el Mod5 '||sqlerrm);
      end;
      begin --Se envian al Historial las tarjetas
        insert into ge_sal_inv_vta_cartera_his  t (t.fecha,
                                             t.cod_persona,
                                             t.nom_completo,
                                             t.nro_documento,
                                             t.cli_nomina,
                                             t.fec_ult_acreditacion,
                                             t.cod_oficina,
                                             t.nro_cuenta,
                                             t.tip_producto,
                                             t.nro_tarjeta,
                                             t.afinidad,
                                             t.cod_per_codeudor,
                                             t.gestor,
                                             t.mto_deuda,
                                             t.mto_previsiones,
                                             t.dia_atrasos,
                                             t.cat_cliente,
                                             t.tot_riesgo,
                                             t.fec_ult_cat_sistema,
                                             t.cat_sistema,
                                             t.tot_deu_sistema,
                                             t.tot_deu_con_sistema,
                                             t.tot_deu_cod_sistema,
                                             t.tot_cuotas,
                                             t.tot_cuo_vencidas,
                                             t.tel_particular,
                                             t.dir_particular,
                                             t.tel_laboral,
                                             t.dir_laboral,
                                             t.gar_cliente,
                                             t.gar_ven_cliente,
                                             t.gar_codeudor,
                                             t.gar_ven_codeudor,
                                             t.tip_bloqueo,
                                             t.tip_inhibicion,
                                             t.estado,
                                             t.cod_modulo,
                                             t.cod_modalidad,
                                             t.mot_exclucion,
                                             t.usu_exclucion,
                                             t.observacion,
                                             t.ruc_comprador,
                                             t.nom_comprador,
                                             t.ref_lote,
                                             t.hor_cancelacion,
                                             t.mon_venta,
                                             t.usu_venta,
                                             t.fec_venta,
                                             t.ope_recaptados,
                                             t.mot_reingreso,
                                             t.usu_reingreso,
                                             t.obs_reingreso,
                                             t.mto_deu_mon_cuenta,
                                             t.sal_deu_cta_actual,
                                             t.dia_atr_actual,
                                             t.cat_ope_actual,
                                             t.cat_cli_ponderada,
                                             t.cod_ente)
          select a.fecha,
             a.cod_persona,
             a.nom_completo,
             a.nro_documento,
             a.cli_nomina,
             a.fec_ult_acreditacion,
             a.cod_oficina,
             a.nro_cuenta,
             a.tip_producto,
             a.nro_tarjeta,
             a.afinidad,
             a.cod_per_codeudor,
             a.gestor,
             a.mto_deuda,
             a.mto_previsiones,
             a.dia_atrasos,
             a.cat_cliente,
             a.tot_riesgo,
             a.fec_ult_cat_sistema,
             a.cat_sistema,
             a.tot_deu_sistema,
             a.tot_deu_con_sistema,
             a.tot_deu_cod_sistema,
             a.tot_cuotas,
             a.tot_cuo_vencidas,
             a.tel_particular,
             a.dir_particular,
             a.tel_laboral,
             a.dir_laboral,
             a.gar_cliente,
             a.gar_ven_cliente,
             a.gar_codeudor,
             a.gar_ven_codeudor,
             a.tip_bloqueo,
             a.tip_inhibicion,
             a.estado,
             a.cod_modulo,
             a.cod_modalidad,
             a.mot_exclucion,
             a.usu_exclucion,
             a.observacion,
             a.ruc_comprador,
             a.nom_comprador,
             a.ref_lote,
             a.hor_cancelacion,
             a.mon_venta,
             a.usu_venta,
                 v_fec_actual,
                 'N',
                 null,
                 null,
                 null,
                 nvl(
                 round(nvl(a.mto_deuda, 0) /
                       fug_obt_cotizacion(fug_obt_mon_cta(a.nro_cuenta),
                                          a.fecha),
                       to_number(fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                                                     NULL,
                                                     NULL,
                                                     fug_obt_mon_cta(a.nro_cuenta)))), a.mto_deuda),
                 null,
                 null,
                 null,
                 null,
                 a.cod_ente                                               
            from ge_sal_inv_vta_cartera_tmp a
           where a.estado = 'C'
             and a.cod_modulo = 5
             and a.ref_lote = P_REF_LOTE;
         
          P_PROCESADO := 'OK';
          -- Inhibimos la persona
          pro_inhibe_personas;    

        --Se limpia de la cartera las tarjetas y excluidos
        --pues a este punto todos estos ya fueron trataron y pasados al historial
        delete ge_sal_inv_vta_cartera_tmp where estado = 'E' or cod_modulo in (5) and ref_lote = P_REF_LOTE;
      Exception
         When others Then
              raise_application_error(-20000,'Error al enviar al Historial el Mod5 '||sqlerrm);
      end;
  END IF;
  IF INSTR(v_modulo, '#6') <> 0 THEN
      --PRG de cancelacion de prestamos
      pag_vta.PR_VTA_CAR_PRESTAMOS(P_REF_LOTE);
      begin
        --Se envian al Historial los prestamos
        insert into ge_sal_inv_vta_cartera_his t (t.fecha,
                                             t.cod_persona,
                                             t.nom_completo,
                                             t.nro_documento,
                                             t.cli_nomina,
                                             t.fec_ult_acreditacion,
                                             t.cod_oficina,
                                             t.nro_cuenta,
                                             t.tip_producto,
                                             t.nro_tarjeta,
                                             t.afinidad,
                                             t.cod_per_codeudor,
                                             t.gestor,
                                             t.mto_deuda,
                                             t.mto_previsiones,
                                             t.dia_atrasos,
                                             t.cat_cliente,
                                             t.tot_riesgo,
                                             t.fec_ult_cat_sistema,
                                             t.cat_sistema,
                                             t.tot_deu_sistema,
                                             t.tot_deu_con_sistema,
                                             t.tot_deu_cod_sistema,
                                             t.tot_cuotas,
                                             t.tot_cuo_vencidas,
                                             t.tel_particular,
                                             t.dir_particular,
                                             t.tel_laboral,
                                             t.dir_laboral,
                                             t.gar_cliente,
                                             t.gar_ven_cliente,
                                             t.gar_codeudor,
                                             t.gar_ven_codeudor,
                                             t.tip_bloqueo,
                                             t.tip_inhibicion,
                                             t.estado,
                                             t.cod_modulo,
                                             t.cod_modalidad,
                                             t.mot_exclucion,
                                             t.usu_exclucion,
                                             t.observacion,
                                             t.ruc_comprador,
                                             t.nom_comprador,
                                             t.ref_lote,
                                             t.hor_cancelacion,
                                             t.mon_venta,
                                             t.usu_venta,
                                             t.fec_venta,
                                             t.ope_recaptados,
                                             t.mot_reingreso,
                                             t.usu_reingreso,
                                             t.obs_reingreso,
                                             t.mto_deu_mon_cuenta,
                                             t.sal_deu_cta_actual,
                                             t.dia_atr_actual,
                                             t.cat_ope_actual,
                                             t.cat_cli_ponderada,
                                             t.cod_ente)
          select a.fecha,
             a.cod_persona,
             a.nom_completo,
             a.nro_documento,
             a.cli_nomina,
             a.fec_ult_acreditacion,
             a.cod_oficina,
             a.nro_cuenta,
             a.tip_producto,
             a.nro_tarjeta,
             a.afinidad,
             a.cod_per_codeudor,
             a.gestor,
             a.mto_deuda,
             a.mto_previsiones,
             a.dia_atrasos,
             a.cat_cliente,
             a.tot_riesgo,
             a.fec_ult_cat_sistema,
             a.cat_sistema,
             a.tot_deu_sistema,
             a.tot_deu_con_sistema,
             a.tot_deu_cod_sistema,
             a.tot_cuotas,
             a.tot_cuo_vencidas,
             a.tel_particular,
             a.dir_particular,
             a.tel_laboral,
             a.dir_laboral,
             a.gar_cliente,
             a.gar_ven_cliente,
             a.gar_codeudor,
             a.gar_ven_codeudor,
             a.tip_bloqueo,
             a.tip_inhibicion,
             a.estado,
             a.cod_modulo,
             a.cod_modalidad,
             a.mot_exclucion,
             a.usu_exclucion,
             a.observacion,
             a.ruc_comprador,
             a.nom_comprador,
             a.ref_lote,
             a.hor_cancelacion,
             a.mon_venta,
             a.usu_venta,
                 v_fec_actual,
                 'N',
                 null,
                 null,
                 null,
                 nvl(
                 round(nvl(a.mto_deuda, 0) /
                       fug_obt_cotizacion(fug_obt_mon_cta(a.nro_cuenta),
                                          a.fecha),
                       to_number(fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                                                     NULL,
                                                     NULL,
                                                     fug_obt_mon_cta(a.nro_cuenta)))), a.mto_deuda),
                 null,
                 null,
                 null,
                 null,
                 a.cod_ente                                                
            from ge_sal_inv_vta_cartera_tmp a
           where a.estado = 'V'
             and a.cod_modulo = 6
             and a.ref_lote = P_REF_LOTE;
             
         P_PROCESADO := 'OK';
         -- Inhibimos la persona
         pro_inhibe_personas;    
          
        --Se limpia de la cartera los prestamos y lo excluido
        --pues a este punto todos estos ya fueron trataron y pasados al historial
        delete ge_sal_inv_vta_cartera_tmp where estado = 'E' or cod_modulo in (6) and ref_lote = P_REF_LOTE;
      Exception
         When others Then
              raise_application_error(-20000,'Error al enviar al Historial el Mod6 '||sqlerrm);
      end;
  END IF;
  IF INSTR(v_modulo, '#4') <> 0 THEN
      --PRG de cancelacion de sobregiros
      pag_vta.PR_VTA_CAR_SOBREGIROS(P_REF_LOTE);
      begin
        --Se envian al Historial los sobregiros
        insert into ge_sal_inv_vta_cartera_his t (t.fecha,
                                             t.cod_persona,
                                             t.nom_completo,
                                             t.nro_documento,
                                             t.cli_nomina,
                                             t.fec_ult_acreditacion,
                                             t.cod_oficina,
                                             t.nro_cuenta,
                                             t.tip_producto,
                                             t.nro_tarjeta,
                                             t.afinidad,
                                             t.cod_per_codeudor,
                                             t.gestor,
                                             t.mto_deuda,
                                             t.mto_previsiones,
                                             t.dia_atrasos,
                                             t.cat_cliente,
                                             t.tot_riesgo,
                                             t.fec_ult_cat_sistema,
                                             t.cat_sistema,
                                             t.tot_deu_sistema,
                                             t.tot_deu_con_sistema,
                                             t.tot_deu_cod_sistema,
                                             t.tot_cuotas,
                                             t.tot_cuo_vencidas,
                                             t.tel_particular,
                                             t.dir_particular,
                                             t.tel_laboral,
                                             t.dir_laboral,
                                             t.gar_cliente,
                                             t.gar_ven_cliente,
                                             t.gar_codeudor,
                                             t.gar_ven_codeudor,
                                             t.tip_bloqueo,
                                             t.tip_inhibicion,
                                             t.estado,
                                             t.cod_modulo,
                                             t.cod_modalidad,
                                             t.mot_exclucion,
                                             t.usu_exclucion,
                                             t.observacion,
                                             t.ruc_comprador,
                                             t.nom_comprador,
                                             t.ref_lote,
                                             t.hor_cancelacion,
                                             t.mon_venta,
                                             t.usu_venta,
                                             t.fec_venta,
                                             t.ope_recaptados,
                                             t.mot_reingreso,
                                             t.usu_reingreso,
                                             t.obs_reingreso,
                                             t.mto_deu_mon_cuenta,
                                             t.sal_deu_cta_actual,
                                             t.dia_atr_actual,
                                             t.cat_ope_actual,
                                             t.cat_cli_ponderada,
                                             t.cod_ente)
          select a.fecha,
             a.cod_persona,
             a.nom_completo,
             a.nro_documento,
             a.cli_nomina,
             a.fec_ult_acreditacion,
             a.cod_oficina,
             a.nro_cuenta,
             a.tip_producto,
             a.nro_tarjeta,
             a.afinidad,
             a.cod_per_codeudor,
             a.gestor,
             a.mto_deuda,
             a.mto_previsiones,
             a.dia_atrasos,
             a.cat_cliente,
             a.tot_riesgo,
             a.fec_ult_cat_sistema,
             a.cat_sistema,
             a.tot_deu_sistema,
             a.tot_deu_con_sistema,
             a.tot_deu_cod_sistema,
             a.tot_cuotas,
             a.tot_cuo_vencidas,
             a.tel_particular,
             a.dir_particular,
             a.tel_laboral,
             a.dir_laboral,
             a.gar_cliente,
             a.gar_ven_cliente,
             a.gar_codeudor,
             a.gar_ven_codeudor,
             a.tip_bloqueo,
             a.tip_inhibicion,
             a.estado,
             a.cod_modulo,
             a.cod_modalidad,
             a.mot_exclucion,
             a.usu_exclucion,
             a.observacion,
             a.ruc_comprador,
             a.nom_comprador,
             a.ref_lote,
             a.hor_cancelacion,
             a.mon_venta,
             a.usu_venta,
                 v_fec_actual,
                 'N',
                 null,
                 null,
                 null,
                 nvl(
                 round(nvl(a.mto_deuda, 0) /
                       fug_obt_cotizacion(fug_obt_mon_cta(a.nro_cuenta),
                                          a.fecha),
                       to_number(fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                                                     NULL,
                                                     NULL,
                                                     fug_obt_mon_cta(a.nro_cuenta)))), a.mto_deuda),
                 null,
                 null,
                 null,
                 null,
                 a.cod_ente
            from ge_sal_inv_vta_cartera_tmp a
           where a.estado = 'V'
             and a.cod_modulo = 4
             and a.ref_lote = P_REF_LOTE;
         
          P_PROCESADO := 'OK';
          -- Inhibimos la persona
          pro_inhibe_personas;    
        --Se limpian de la cartera los sobregiros y lo excluido
        delete ge_sal_inv_vta_cartera_tmp where estado = 'E' or cod_modulo in (4) and ref_lote = P_REF_LOTE;
      Exception
         When others Then
              raise_application_error(-20000,'Error al enviar al Historial el Mod4 '||sqlerrm);
      end;
  END IF;
  IF INSTR(v_modulo, '#15') <> 0 THEN
      --PRG de cancelacion de ope. vencidas
      pag_vta.PR_VTA_CAR_OPE_VENCIDAS(P_REF_LOTE);
      begin
        --Se envian al Historial las ope. vencidas
        insert into ge_sal_inv_vta_cartera_his t (t.fecha,
                                             t.cod_persona,
                                             t.nom_completo,
                                             t.nro_documento,
                                             t.cli_nomina,
                                             t.fec_ult_acreditacion,
                                             t.cod_oficina,
                                             t.nro_cuenta,
                                             t.tip_producto,
                                             t.nro_tarjeta,
                                             t.afinidad,
                                             t.cod_per_codeudor,
                                             t.gestor,
                                             t.mto_deuda,
                                             t.mto_previsiones,
                                             t.dia_atrasos,
                                             t.cat_cliente,
                                             t.tot_riesgo,
                                             t.fec_ult_cat_sistema,
                                             t.cat_sistema,
                                             t.tot_deu_sistema,
                                             t.tot_deu_con_sistema,
                                             t.tot_deu_cod_sistema,
                                             t.tot_cuotas,
                                             t.tot_cuo_vencidas,
                                             t.tel_particular,
                                             t.dir_particular,
                                             t.tel_laboral,
                                             t.dir_laboral,
                                             t.gar_cliente,
                                             t.gar_ven_cliente,
                                             t.gar_codeudor,
                                             t.gar_ven_codeudor,
                                             t.tip_bloqueo,
                                             t.tip_inhibicion,
                                             t.estado,
                                             t.cod_modulo,
                                             t.cod_modalidad,
                                             t.mot_exclucion,
                                             t.usu_exclucion,
                                             t.observacion,
                                             t.ruc_comprador,
                                             t.nom_comprador,
                                             t.ref_lote,
                                             t.hor_cancelacion,
                                             t.mon_venta,
                                             t.usu_venta,
                                             t.fec_venta,
                                             t.ope_recaptados,
                                             t.mot_reingreso,
                                             t.usu_reingreso,
                                             t.obs_reingreso,
                                             t.mto_deu_mon_cuenta,
                                             t.sal_deu_cta_actual,
                                             t.dia_atr_actual,
                                             t.cat_ope_actual,
                                             t.cat_cli_ponderada,
                                             t.cod_ente)
          select a.fecha,
             a.cod_persona,
             a.nom_completo,
             a.nro_documento,
             a.cli_nomina,
             a.fec_ult_acreditacion,
             a.cod_oficina,
             a.nro_cuenta,
             a.tip_producto,
             a.nro_tarjeta,
             a.afinidad,
             a.cod_per_codeudor,
             a.gestor,
             a.mto_deuda,
             a.mto_previsiones,
             a.dia_atrasos,
             a.cat_cliente,
             a.tot_riesgo,
             a.fec_ult_cat_sistema,
             a.cat_sistema,
             a.tot_deu_sistema,
             a.tot_deu_con_sistema,
             a.tot_deu_cod_sistema,
             a.tot_cuotas,
             a.tot_cuo_vencidas,
             a.tel_particular,
             a.dir_particular,
             a.tel_laboral,
             a.dir_laboral,
             a.gar_cliente,
             a.gar_ven_cliente,
             a.gar_codeudor,
             a.gar_ven_codeudor,
             a.tip_bloqueo,
             a.tip_inhibicion,
             a.estado,
             a.cod_modulo,
             a.cod_modalidad,
             a.mot_exclucion,
             a.usu_exclucion,
             a.observacion,
             a.ruc_comprador,
             a.nom_comprador,
             a.ref_lote,
             a.hor_cancelacion,
             a.mon_venta,
             a.usu_venta,
                 v_fec_actual,
                 'N',
                 null,
                 null,
                 null,
                 nvl(
                 round(nvl(a.mto_deuda, 0) /
                       fug_obt_cotizacion(fug_obt_mon_cta(a.nro_cuenta),
                                          a.fecha),
                       to_number(fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                                                     NULL,
                                                     NULL,
                                                     fug_obt_mon_cta(a.nro_cuenta)))), a.mto_deuda),
                 null,
                 null,
                 null,
                 null,
                 a.cod_ente
            from ge_sal_inv_vta_cartera_tmp a
           where a.estado = 'V'
       and a.cod_modulo = 15
             and a.ref_lote = P_REF_LOTE;
             
         --Se carga el mensaje de que se concluyo el proceso de venta de cartera.
         P_PROCESADO := 'OK';
         -- Inhibimos la persona
         pro_inhibe_personas;    

        --Se limpian de la cartera las ope. vencidas y lo excluido
        delete ge_sal_inv_vta_cartera_tmp where estado = 'E' or cod_modulo in (15) and ref_lote = P_REF_LOTE;
      Exception
         When others Then
              raise_application_error(-20000,'Error al enviar al Historial el Mod15 '||sqlerrm);
      end;
  END IF;

-------------------------------SE PROCEDE A ENVIAR MAIL DE AVISO AL DPTO. DE TARJETAS
  if v_cant_tarjetas > 0 then
    -- Obtenemos los direcciones de correo para quien o quienes va el mail
    begin
      select a.dir_correo
        into v_dir_correo_para_user
        from ba_usuarios a
       where a.cod_usuario = user;
    exception
      when others then
        raise_application_error(-20000, 'ERROR: '||user||' no cuenta con direccion de correo electrónico cargado en el sistema, para agregar a destinatarios del correo de confirmación.');
    end;
    v_para := pa_rep_aut.FU_OBT_VALOR_PAR('RA','REPORTES','VTA_CARTERA_DPTO_TAR')||', '||v_dir_correo_para_user;

    -- Damos valor a los demas datos
    v_asunto := 'Venta de Cartera '||v_fec_actual;
    v_mje_mail := 'Buenos días,

    Se informa que se proceso la venta de la cartera con los siguientes datos:

    * Fecha de venta: '||v_fec_actual||'
    * Nro. Ref. Lote: '||P_REF_LOTE||'
    * Ejecutado por: '||user||' - '||fuy_obt_nom_usuario(user)||'
    * Cantidad de Tarjetas vendidas: '||v_cant_tarjetas||'

    Desde el Departamento de Tarjetas se puede proceder a la cancelacion de las mismas, en la pantalla de Envío de TDC, en ITGF.

    Saludos Cordiales.';

    -- Enviamos el mail
    v_det_error    := null;
    v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

    BEGIN
    v_conn := it_mail.begin_mail(pa_rep_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
    it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
    it_mail.end_mail(v_conn);
    EXCEPTION
      when utl_smtp.transient_error or utl_smtp.permanent_error then
        begin
          utl_smtp.quit(v_conn);
        exception
          when utl_smtp.transient_error or utl_smtp.permanent_error then
          null;
          end;
        v_det_error := substr(sqlerrm,1,4000);
    END;

    v_hfin_mail := to_char(sysdate,'hh24:mi:ss');

    -- Insertamos en la tabla de log si ocurrio algun error al enviar el mail
    IF v_det_error is not null THEN
    INSERT INTO ge_ra_log_mail
       (fec_envio, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
    VALUES
       (SYSDATE, v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
    END IF;
  end if;
---------------------Generación del Informe de Venta de Cartera.
 -- PA_REP_AUT.PR_INF_VTA_CARTERA(P_REF_LOTE);
END;
/

