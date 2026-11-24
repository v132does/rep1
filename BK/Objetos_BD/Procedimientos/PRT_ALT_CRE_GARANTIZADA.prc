create or replace procedure it.prt_alt_cre_garantizada(p_cod_persona      in ba_personas.cod_persona%type,
                                                       p_nro_lote in number,
                                                       p_nro_cuenta out varchar2,
                                                       p_nro_cuenta_ah  out varchar2,
                                                       p_tip_embozado  out varchar2,
                                                       p_cod_error   out number,
                                                       p_men_error   out varchar2  ) is

  v_cod_exito   number(5):=nvl(fug_obt_pardinamico('COD_MSG_EXITO'),
                                      200);
  v_cod_error number(5):=nvl(fug_obt_pardinamico('COD_MSG_EXITO'),
                                      200);
  v_men_error   varchar2(200):='Transaccion Exitosa';
  v_cod_tip_producto varchar2(2):='39';
  v_cod_producto varchar2(10);
  v_existe_cta varchar2(1);
  v_existe_tarjeta varchar2(1);
  v_nro_documento varchar2(20);
  v_nombre varchar2(50);
  v_dir varchar2(10);
  v_existe_ge_cuenta varchar2(1);
  ----------
  v_nro_cuenta_td       varchar2(20);
  v_tip_embozado varchar2(10);
  v_linea_pre_aprobado number(15):= nvl(fug_obt_pardinamico('LIN_PRE_APR_1'), 1);
  v_cod_estado_td varchar2(10);
  ----------
  v_nro_solicitud ta_solicitudes.nro_solicitud%type;
  ----------
  v_nro_cuenta  varchar2(20);
  v_nro_tarjeta varchar2(20);
  v_cod_estado varchar2(10);
  v_contrato varchar2(1);

  v_nom_programa varchar2(50) := 'PRT_ALT_CRE_GARANTIZADA';
begin
    begin 
        pre_ini_aplicacion; 
        pae_cnf.g_cod_modulo := 1; 
        execute immediate 'ALTER SESSION SET NLS_DATE_FORMAT = ''DD/MM/RRRR HH24:MI:SS''';
    end;

    begin
      select nro_documento,substr(b.pri_nombre||' '||b.pri_apellido,1,25)
      into v_nro_documento,v_nombre
      from  ba_personas a,ba_per_fisicas b
      where a.cod_persona=b.cod_persona
      and a.cod_persona=p_cod_persona;
      exception
        when others then
          v_nro_documento:=null;
          v_men_error:=substr('Error al recuperar nro_documento - '||p_cod_persona||'-'||sqlerrm,1,200);
          v_cod_error:='111';
          prg_ins_log_programas(v_nom_programa,
                                  substr(v_men_error,
                                         1,
                                         200),
                                  p_cod_persona,
                                  null);
    end;
    
    if v_cod_error=v_cod_exito then
      begin
          select distinct 'S'
            into v_contrato
            from ba_per_ima_documentos
           where cod_tip_documento = 64
             and est_doc in ('A', 'N')
             and cod_persona = p_cod_persona;
             v_contrato := 'S';
        exception
          when no_data_found then
            
            v_contrato := 'N';
         when others then
            v_men_error:=substr('Error CU - '||p_cod_persona||'-'||sqlerrm,1,200);
            v_cod_error:='99';
            v_contrato := 'N';
            prg_ins_log_programas(v_nom_programa,
                                  substr(v_men_error,
                                         1,
                                         200),
                                  p_cod_persona,
                                  null);
         end;
         end if;
    
    

   if v_cod_error=v_cod_exito and v_nro_documento is not null then
        begin--validamos que exista la cuenta
          select 'S',nro_cuenta,a.cod_estado
          into v_existe_cta,v_nro_cuenta,v_cod_estado
          from ta_tar_global_tmp a
          where a.cod_persona=p_cod_persona;
          v_existe_cta:='S';
         exception
        when no_data_found then
          v_existe_cta:='N';
        when too_many_rows then
          v_cod_error:='101';
          v_men_error:=substr('Posee varios registros en temporal - '||p_cod_persona||'-'||sqlerrm,1,200);
          v_existe_cta:='S';
        when others then
        v_cod_error:='102';
        v_men_error:=substr('Error al validar cuenta en temporal - '||p_cod_persona||'-'||sqlerrm,1,200);
        v_existe_cta:='N';
        end;

        begin
          select distinct 'S'
          into v_existe_tarjeta
          from ta_tarjetas s
          where tip_embozado is not null
          and vigente='S'
          and s.cod_persona=p_cod_persona
          and s.nro_cuenta in (select nro_cuenta from ta_cta_tarjetas where cod_modalidad='53');
          v_men_error:=substr('Ya posee cuenta en tc activa- '||p_cod_persona||'-'||sqlerrm,1,200);
        exception
          when no_data_found then
             v_existe_tarjeta:='N';
          when others then
              v_existe_tarjeta:='N';
        end;

       if (v_existe_cta='N' and v_existe_tarjeta='N') or (v_cod_estado=1 and v_existe_cta='S') then--si no existe generamos la cuenta en gp
                                                         --si es baja tambien le generamos la cuenta

             if v_cod_estado=1 then--si tiene estado baja se debe borrar del temporal
               begin
                 delete from ta_tar_global_tmp p
                 where p.nro_cuenta=v_nro_cuenta
                 and p.cod_persona=p_cod_persona
                 and p.cod_estado='1';
                 commit;
               exception
                   when others then
                      v_men_error:=substr('Error al eliminar cuenta del temporal - '||p_cod_persona||'-'||sqlerrm,1,200);
                      v_cod_error:='112';
                      prg_ins_log_programas(v_nom_programa,
                                              substr(v_men_error,
                                                     1,
                                                     200),
                                              p_cod_persona,
                                              null);
               end;
             end if;
             begin--damos de alta la cuenta de gp
              it.pat_tgl.pr_cre_tar_vir_global(v_nro_documento,
                                                 v_cod_error,
                                                 v_men_error);
                commit;
              exception
                when others then
                  v_men_error:=substr('Error al crear cuenta credito - '||p_cod_persona||'-'||sqlerrm,1,200);
                  v_cod_error:='222';
                  prg_ins_log_programas(v_nom_programa,
                                          substr(v_men_error,
                                                 1,
                                                 200),
                                          p_cod_persona,
                                          null);
              end;
        end if;

            if v_cod_error=v_cod_exito and v_existe_tarjeta='N' then
              begin--recuperamos el numero de cuenta /tarjeta
                  select nro_cuenta, nro_tarjeta,s.cod_estado,s.cod_producto
                    into v_nro_cuenta, v_nro_tarjeta,v_cod_estado,v_cod_producto
                    from ta_tar_global_tmp s
                   where s.cod_persona = p_cod_persona;
              exception
                  when others then
                    v_nro_tarjeta := null;
                    v_men_error:=substr('Error al recuperar cuenta tc generada - '||p_cod_persona||'-'||sqlerrm,1,200);
                    v_cod_error:='333';
                     prg_ins_log_programas(v_nom_programa,
                                          substr(v_men_error,
                                                 1,
                                                 200),
                                          p_cod_persona,
                                          null);
              end;
              
              
               if v_cod_error=v_cod_exito and v_existe_tarjeta='N'then
                 begin
                  select nro_cuenta,s.cod_est_solicitud,s.tip_tar_debito
                  into v_nro_cuenta_td,v_cod_estado_td,v_tip_embozado
                  from ah_tar_debitos s
                  where cod_persona=p_cod_persona
                  and tar_activa='S'
                  and cod_ent_procesadora='1175';
                exception
                  when others then
                    v_cod_error:='676';
                   v_men_error:=substr('Error al recuperar cuenta td dir - '||p_cod_persona||'-'||sqlerrm,1,200);
                    prg_ins_log_programas(v_nom_programa,
                                        substr(v_men_error,
                                               1,
                                               200),
                                        p_cod_persona,
                                        null);
                end;
               end if;

              if v_cod_error=v_cod_exito and v_existe_tarjeta='N'then
                begin--verificamos si la cuenta ya existe en ge_cuentas
                    select distinct 'S'
                      into v_existe_ge_cuenta
                      from ge_cuentas s
                     where s.nro_cuenta = v_nro_cuenta;
                     if v_existe_ge_cuenta='S' then
                      v_men_error:=substr('Cuenta tc generada ya existe en ge_cuentas - '||p_cod_persona||'-'||sqlerrm,1,200);
                      v_cod_error:='800';
                      prg_ins_log_programas(v_nom_programa,
                                            substr(v_men_error,
                                                   1,
                                                   200),
                                            p_cod_persona,
                                            null);
                     end if;
                exception
                    when others then
                         null;
                end;
              end if;

              if v_cod_error=v_cod_exito then

               if v_cod_error=v_cod_exito and v_nro_tarjeta is not null and v_existe_tarjeta='N' then
                          

                         -- direccion de envio
                          begin
                          select distinct 'S'
                          into v_dir
                          from  ge_dir_envios a
                          where a.cod_persona=p_cod_persona;
                          exception
                            when no_data_found then
                              begin
                                insert into ge_dir_envios a (cod_persona, tip_envio, referencia)
                                values (p_cod_persona,'R','1');
                              exception
                                when others then
                                  v_cod_error:='345';
                                  v_men_error:=substr('Error al insertar dir envio - '||p_cod_persona||'-'||sqlerrm,1,200);
                                  prg_ins_log_programas(v_nom_programa,
                                                            substr(v_men_error,
                                                                   1,
                                                                   200),
                                                            p_cod_persona,
                                                            null);
                              end;
                            when others then
                              v_cod_error:='350';
                              v_men_error:=substr('Error al recuperar dir envio - '||p_cod_persona||'-'||sqlerrm,1,200);
                              prg_ins_log_programas(v_nom_programa,
                                                            substr(v_men_error,
                                                                   1,
                                                                   200),
                                                            p_cod_persona,
                                                            null);
                          end;

                         begin--validamos solicitud
                             select t.nro_solicitud
                             into v_nro_solicitud
                              from  ta_solicitudes t
                              where cod_persona     = p_cod_persona
                                and cod_modalidad   = '53'
                                and afinidad        = '0601'
                                and cod_estado      <> 'RCH'
                                and rownum=1;
                         exception
                            when no_data_found then
                              begin
                                 --insertamos solicitud
                                    select s_nro_solicitud.nextval
                                    into v_nro_solicitud
                                    from sys.dual;
                                    
                                    insert into ta_solicitudes (nro_solicitud, cod_persona, cod_oficina, cod_modulo, cod_modalidad, cod_usu_promotor, fec_solicitud, cod_usu_oficial, fec_aprobacion, cod_causa, deb_automatico, nro_cta_debito, tip_cobro, nom_embozado, lin_sugerida, monto, puntaje, cod_estado, cod_est_sugerido, tas_int_adelanto, tas_financiacion, tas_mora, mto_min_pago, por_pag_minimo, tip_envio, referencia, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion, nro_linea, observacion, cod_moneda, cod_campana, cod_canal, mto_aprobado, niv_aprobacion, nro_acta, nro_cuenta, afinidad, sub_afinidad, pre_embozada, ind_evaluacion, cod_tip_cierre, cod_rub_economico, tip_plastico, tas_int_corriente, tas_int_compra, por_vip, mto_fij_pag_minimo, mto_min_pag_minimo, tas_int_mora, cod_sub_modalidad, nro_bin, est_verificacion, cod_tas_procard, lin_especial, env_email, cod_ent_procesadora, tip_embozado)
                                    values (v_nro_solicitud, p_cod_persona, 61, 5, 53, 'CREDCARDS', trunc(sysdate), null, null, null, 'N', null, 'M', v_nombre, null, v_linea_pre_aprobado, null, 'APR', null, 0.0000, 0.0000, 0.0000, 0.00, 0.00, 'R', '1', user, sysdate, user, sysdate, null, null, 'GS', null, null, null, null, null, null, '0601', '02', null, 'S', 1, '970107', null, null, null, null, null, null, null, 1, 558548, null, null, null, null, 1175, null);
                                 exception
                                   when others then
                                      v_men_error:=substr('Error al insertar solicitud - '||p_cod_persona||'-'||sqlerrm,1,200);
                                      v_cod_error:='400';
                                       prg_ins_log_programas(v_nom_programa,
                                                            substr(v_men_error,
                                                                   1,
                                                                   200),
                                                            p_cod_persona,
                                                            null);
                                   end;
                            when others then
                              v_men_error:=substr('Error al recuperar solicitud - '||p_cod_persona||'-'||sqlerrm,1,200);
                              v_cod_error:='401';
                               prg_ins_log_programas(v_nom_programa,
                                                    substr(v_men_error,
                                                           1,
                                                           200),
                                                    p_cod_persona,
                                                    null);
                          end;

                          --insertamos ta_cta_tarjetas
                         if v_cod_error=v_cod_exito then
                          begin
                            insert
                            into ta_cta_tarjetas(nro_cuenta,
                           denominacion,
                           cod_modulo,
                           cod_modalidad,
                           cod_oficina,
                           cod_moneda,
                           lin_credito,
                           lin_cuotas,
                           sal_facturar,
                           sal_facturado,
                           sal_financiado,
                           sal_ult_extracto,
                           sal_cuo_pendientes,
                           mto_pag_minimo,
                           sal_pag_minimo,
                           mto_mora,
                           dia_mora,
                           mto_autorizaciones,
                           mto_int_compras,
                           mto_pag_mes,
                           mto_gas_mora,
                           estado,
                           est_administradora,
                           fec_solicitud,
                           fec_apertura,
                           fec_ult_pago,
                           fec_ult_compra,
                           fec_ult_operacion,
                           fec_ult_extracto,
                           fec_ult_cierre,
                           fec_vct_ult_cierre,
                           cod_tip_cierre,
                           cob_gas_financiero,
                           tip_tas_financiacion,
                           tip_com_emision,
                           tas_financiacion,
                           tas_adelanto,
                           tas_mora,
                           tas_cuotas,
                           deb_automatico,
                           tip_cobro,
                           nro_cta_debito,
                           mto_min_pago,
                           por_pag_minimo,
                           cod_usu_promotor,
                           mar_mora,
                           mar_excedido,
                           mar_recuperado,
                           mar_bloqueo,
                           con_costo,
                           nro_solicitud,
                           cod_causa,
                           cod_canal,
                           cod_campana,
                           usu_insercion,
                           fec_insercion,
                           usu_modificacion,
                           fec_modificacion,
                           cat_automatica,
                           fec_juicio,
                           cod_ent_juicio,
                           max_atraso,
                           pro_atraso,
                           nro_linea,
                           en_juicio,
                           cat_aut_anterior,
                           fec_activacion,
                           fec_cancelacion,
                           tas_efectiva,
                           mto_aut_cuotas,
                           afinidad,
                           sub_afinidad,
                           sal_procesadora,
                           cod_rub_economico,
                           tip_plastico,
                           mto_fij_pag_minimo,
                           mto_min_pag_minimo,
                           tas_int_corriente,
                           tas_int_compra,
                           tas_int_mora,
                           car_no_aplicar,
                           mto_car_sus_aplicado,
                           mto_car_suspendido,
                           tas_especial,
                           lin_especial,
                           franqueo,
                           ind_seg_vida,
                           cod_exc_cargo,
                           tip_cierre) values(v_nro_cuenta,
                                              v_nombre,
                                              5,
                                              53,
                                              61,
                                              'GS',
                                              v_linea_pre_aprobado,
                                              0.00,
                                              0.00,
                                              0.00,
                                              0.00,
                                              0.00,
                                              0.00,
                                              0.00,
                                              0.00,
                                              0.00,
                                              0.00,
                                              0.00,
                                              0.00,
                                              0.00,
                                              0.00,
                                              'N',
                                              null,
                                              trunc(sysdate),
                                              trunc(sysdate),
                                              null,
                                              null,
                                              null,
                                              null,
                                              sysdate,
                                              sysdate,
                                              3,
                                              null,
                                              null,
                                              '0',
                                              0.0000,
                                              0.0000,
                                              0.0000,
                                              0.0000,
                                              'S',--debito automatico
                                              'M',
                                              v_nro_cuenta_td,
                                              null,
                                              null,
                                              null,
                                              null,
                                              null,
                                              null,
                                              null,
                                              null,
                                              v_nro_solicitud,
                                              null,
                                              null,
                                              null,
                                              user,
                                              sysdate,
                                              user,
                                              sysdate,
                                              1,
                                              null,
                                              null,
                                              null,
                                              null,
                                              null,
                                              null,
                                              null,
                                              sysdate,
                                              null,
                                              null,
                                              null,
                                              '0601',
                                              '02',
                                              null,
                                              '970107',
                                              null,
                                              null,
                                              null,
                                              null,
                                              null,
                                              null,
                                              null,
                                              0.00,
                                              0.00,
                                              0.0000,
                                              0.00,
                                              null,
                                              null,
                                              null,
                                              '3');
                          exception
                            when others then
                              v_men_error:=substr('Error al insertar ta_cta_tarjetas - '||p_cod_persona||'-'||sqlerrm,1,200);
                              v_cod_error:='402';
                               prg_ins_log_programas(v_nom_programa,
                                                    substr(v_men_error,
                                                           1,
                                                           200),
                                                    p_cod_persona,
                                                    null);
                          end;
                          end if;

                         if v_cod_error=v_cod_exito then
                         begin
                            --insertar en dar_adicionales
                            insert into it.ge_cta_dat_adicionales
                            (nro_cuenta,
                             parametro,
                             val_parametro)
                          values
                            (v_nro_cuenta, 'COD_PRO_TDC_GLOBAL', '38');

                          --insertar garantias
                           insert
                           into ta_cta_garantias(nro_cuenta,
                                                nro_garantia,
                                                cod_garantia,
                                                mto_aplicado,
                                                mto_apl_computable)
                                                 values(v_nro_cuenta,
                                                         null,
                                                         1,
                                                         v_linea_pre_aprobado,
                                                         0);
                          exception
                            when others then
                              v_men_error:=substr('Error dat. adicionales/garantias - '||p_cod_persona||'-'||sqlerrm,1,200);
                              v_cod_error:='403';
                               prg_ins_log_programas(v_nom_programa,
                                                    substr(v_men_error,
                                                           1,
                                                           200),
                                                    p_cod_persona,
                                                    null);
                          end;
                          end if;

                          if v_cod_error=v_cod_exito then
                          begin
                            --insertar ge_cta_clientes
                            insert into ge_cta_clientes (cod_persona, nro_cuenta, dig_verificador, cod_oficina, cod_modulo, cod_modalidad, relacion, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion, nro_cta_cli_btw, integracion, nro_sub_cta_cli_btw, est_relacion)
                            values (p_cod_persona, v_nro_cuenta, 0, 61, 5, 53, 'P', user, sysdate, user, sysdate, null, null, null, 'A');
                          exception
                            when others then
                              v_men_error:=substr('Error al insertar cliente - '||p_cod_persona||'-'||sqlerrm,1,200);
                              v_cod_error:='404';
                               prg_ins_log_programas(v_nom_programa,
                                                    substr(v_men_error,
                                                           1,
                                                           200),
                                                    p_cod_persona,
                                                    null);
                          end;
                          end if;

                          --insertar en ta_tarjetas
                         if v_cod_error=v_cod_exito then
                          begin
                             insert into ta_tarjetas (nro_cuenta, nro_tarjeta, cod_persona, cod_estado, fec_vencimiento, cod_causa, nom_embozar, nom_enviar, vigente, fec_emision, fec_solicitud, tip_envio, referencia, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion, nro_planilla, tip_planilla, nro_pla_anterior, fec_entrega, fec_activacion, observacion, pre_embozada, pla_ope_por_contado, pla_ope_mto_contado, pla_ope_mto_adelanto, pla_ope_por_adelanto, tip_embozado, motivo, rel_tarjeta,id_producto)
                              values (v_nro_cuenta, v_nro_tarjeta, p_cod_persona, '6', to_date('31-05-2030', 'dd-mm-yyyy'), null, v_nombre, null, 'S', sysdate, sysdate, 'R', '1', user, sysdate, user, sysdate, null, null, null, null, sysdate, null, null, null, null, null, null, v_tip_embozado, null, 0,'38');
                           exception
                             when others then
                              v_men_error:=substr('Error al insertar tarjeta - '||p_cod_persona||'-'||sqlerrm,1,200);
                              v_cod_error:='405';
                               prg_ins_log_programas(v_nom_programa,
                                                    substr(v_men_error,
                                                           1,
                                                           200),
                                                    p_cod_persona,
                                                    null);

                          end;
                          end if;


                    if v_cod_error=v_cod_exito then
                      
                        begin
                          commit;
                          if v_cod_estado_td='14' then
                            it.pat_tgl.pr_act_tar_cre(v_nro_cuenta,
                                         p_cod_persona,
                                         v_nro_tarjeta,
                                         14,
                                         v_cod_error,
                                         v_men_error);
                           else 
                             if v_cod_estado!='0' then
                               it.pat_tgl.pr_act_tar_cre(v_nro_cuenta,
                                           p_cod_persona,
                                           v_nro_tarjeta,
                                           0,
                                           v_cod_error,
                                           v_men_error);
                             end if;
                          end if;
                        exception
                          when others then
                            v_men_error:=substr('Error al cambiar el estado - '||p_cod_persona||'-'||v_cod_estado_td||'-'||sqlerrm,1,200);
                            v_cod_error:='500';
                                   prg_ins_log_programas(v_nom_programa,
                                                        substr(v_men_error,
                                                               1,
                                                               200),
                                                        p_cod_persona,
                                                        null);
    
                        end;
                        sys.dbms_lock.sleep(0.7);
                        begin                    
                           it.pat_tgl.pr_act_lim_tar(v_nro_cuenta,
                                          p_cod_persona,
                                          v_nro_tarjeta,
                                          v_linea_pre_aprobado,
                                          v_cod_error,v_men_error);
                        exception
                          when others then
                            v_men_error:=substr('Error al asignar limite - '||p_cod_persona||'-'||sqlerrm,1,200);
                            v_cod_error:='500';
                                   prg_ins_log_programas(v_nom_programa,
                                                        substr(v_men_error,
                                                               1,
                                                               200),
                                                        p_cod_persona,
                                                        null);
    
                        end;
                        
                        --insertamos tab tarjetas garantizadas
                         begin
                            insert into it.ge_cta_dat_adicionales
                          (nro_cuenta,
                           parametro,
                           val_parametro)
                        values
                          (v_nro_cuenta, 'EST_CTA_GARANTIZADA', 'A'); 
                                      
                          exception
                           when others then
                             v_men_error:=substr('Error al insertar marca tarjeta garantizada'||sqlerrm,1,200);
                             v_cod_error:='666';
                             prg_ins_log_programas(v_nom_programa,
                                                  substr(v_cod_error||'-'||v_men_error,
                                                         1,
                                                         4000),
                                                  p_cod_persona,
                                                  null);
                         end;
                    end if;

               end if;--validacion de nro_tarjeta recuperada
            end if;--validacion cuenta generada correctamente
       else--si ya tenia cuenta creada

            v_cod_error:='900';
            prg_ins_log_programas(v_nom_programa,
                                    substr(v_men_error,
                                           1,
                                           200),
                                    p_cod_persona,
                                    null);
        end if;

   end if;--validación de nro de cedula
    
   --insertamos log
         begin
           insert into it.ta_cta_mig_log
            (cod_persona, tip_producto, nro_lote, cod_proceso, msj_proceso, fecha,nro_cuenta)
          values
            (p_cod_persona, v_cod_tip_producto, p_nro_lote, v_cod_error, substr(v_men_error||'-'||v_nro_cuenta_td,1,400), sysdate,v_nro_cuenta);
         exception
           when others then
             v_men_error:=substr('Error al insertar log'||sqlerrm,1,200);
             v_cod_error:='666';
             prg_ins_log_programas(v_nom_programa,
                                  substr(v_cod_error||'-'||v_men_error,
                                         1,
                                         4000),
                                  p_cod_persona,
                                  null);
         end;   
         p_cod_error:=v_cod_error;
         p_men_error:=v_men_error;
         p_nro_cuenta:=v_nro_cuenta;
         p_nro_cuenta_ah:=v_nro_cuenta_td;
         p_tip_embozado:=v_tip_embozado;
    commit;
exception
  when others then
     v_men_error:=substr('Error General'||sqlerrm,1,200);
     v_cod_error:='999';
     prg_ins_log_programas(v_nom_programa,
                          substr(v_cod_error||'-'||v_men_error,
                                 1,
                                 4000),
                          p_cod_persona,
                          null);
         p_cod_error:=v_cod_error;
         p_men_error:=v_men_error;
         p_nro_cuenta:=null;
         p_nro_cuenta_ah:=null;
       p_tip_embozado:=null;
END prt_alt_cre_garantizada;
