create or replace procedure it.prp_baj_pre_aprobados(p_nro_cuenta ge_bloqueos.nro_cuenta%type default null) is

  v_cod_error   number;
  v_cod_err_sal number;
  v_det_error   varchar2(4000);
  v_lugar       varchar2(4000);

  v_cod_causa        ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('COD_CAU_PRE_APROBADOS');
  v_cod_mad_padre    ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('COD_MAD_PRE_APROBADOS');
  v_cod_tra_padre    ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('COD_TRA_PRE_APROBADOS');
  v_cod_tra_sal      ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('COD_TRA_SAL_BLOQUEADOS');
  v_fec_ult_mes      ge_calendarios.fec_anterior%type;
  v_fec_actual       ge_calendarios.fec_actual%type := pag_cal.fu_obt_fec_actual(3);
  v_cod_persona      ba_personas.cod_persona%type;
  v_nro_solicitud    pr_solicitudes.nro_solicitud%type;
  v_cod_pre_aprobado pr_pre_aprobados.cod_pre_aprobado%type;
  v_cod_moneda       pr_pre_aprobados.cod_moneda%type := pag_gen.fu_obt_mon_local;
  v_nro_cuenta       pr_cta_prestamos.nro_cuenta%type;
  v_nro_documento    ge_bloqueos.nro_documento%type;
  v_monto            ge_bloqueos.monto%type;
  v_cod_mod_cta      ah_cta_vistas.cod_modulo%type;
  v_cod_mad_cta      ah_cta_vistas.cod_modalidad%type;
  v_cod_ofi_cta      ah_cta_vistas.cod_oficina%type;
  v_nro_cta_debito   ah_cta_vistas.nro_cuenta%type;

  v_est_doc  varchar2(1);
  v_est_wf48 number;
  v_est_wf3  number;

  v_fec_mov     ge_movimientos.fecha%type;
  v_hor_mov     ge_movimientos.hora%type;
  v_cod_usu_mov ge_movimientos.cod_usuario%type;
  v_cod_mod_mov ge_movimientos.cod_modulo%type;
  v_cod_mad_mov ge_movimientos.cod_modalidad%type;

  v_fec_pre      ge_movimientos.fecha%type;
  v_hor_pre      ge_movimientos.hora%type;
  v_cod_usu_pre  ge_movimientos.cod_usuario%type;
  v_cod_mod_pre  ge_movimientos.cod_modulo%type;
  v_cod_mad_pre  ge_movimientos.cod_modalidad%type;
  v_esp_segundos number;
  v_contador     number := 0;

  -- Cursor principal
  cursor c_prestamos is
    select a.nro_cuenta,
           a.cod_moneda,
           a.nro_solicitud,
           c.cod_persona,
           a.nro_cta_debito,
           a.monto,
           aa.nro_documento
      from pr_cta_prestamos a, ge_cta_clientes c, ge_bloqueos aa
     where a.cod_modalidad = v_cod_mad_padre
       and a.nro_cuenta = c.nro_cuenta
       and a.cod_modulo = c.cod_modulo
       and a.cod_modalidad = c.cod_modalidad
       and a.nro_cta_debito = aa.nro_cuenta
       and aa.cod_causa = v_cod_causa
       and (a.nro_cuenta = p_nro_cuenta or p_nro_cuenta is null)
       and c.relacion = 'P'
       and a.estado = 'C'
       and not exists
     (select 1 from pr_cobros ce where ce.nro_cuenta = a.nro_cuenta);

begin
  begin
    pre_ini_aplicacion;
    pae_cnf.g_cod_modulo := 1;
  end;
  pag_cal.pr_obt_dat_calendar(3);
  v_fec_ult_mes := pag_cal.G_ULT_DIA_MES_HABIL;
  v_fec_actual  := pag_cal.fu_obt_fec_actual(3);

  -- Valida que sea el ultimo dia habil del mes
  if v_fec_actual = v_fec_ult_mes then
  
    for reg in c_prestamos loop
      -- Seteamos variables
      v_cod_pre_aprobado := null;
      v_cod_persona      := reg.cod_persona;
      v_nro_solicitud    := reg.nro_solicitud;
      v_nro_cuenta       := reg.nro_cuenta; -- cuenta de prestamo
      v_nro_documento    := reg.nro_documento; -- nro_documento de ge_bloqueos
      v_nro_cta_debito   := reg.nro_cta_debito; -- cuenta caja ahorro
      v_monto            := reg.monto;
      v_cod_err_sal      := null;
      v_cod_error        := null;
      v_det_error        := null;
      v_lugar            := null;
      v_est_doc          := null;
      v_est_wf3          := null;
      v_est_wf48         := null;
      v_esp_segundos     := 2;
      v_contador         := v_contador + 1;
      -- Recupera datos del pre_aprobado
      begin
        select b.cod_pre_aprobado
          into v_cod_pre_aprobado
          from pr_pre_aprobados b
          join pr_solicitudes c
            on b.nro_solicitud = c.nro_solicitud
         where b.estado = 'D'
           and b.cod_modalidad = v_cod_mad_padre
           and b.cod_persona = v_cod_persona
           and b.nro_solicitud = v_nro_solicitud;
      exception
        when no_data_found then
          v_cod_pre_aprobado := null;
        when too_many_rows then
          select b.cod_pre_aprobado
            into v_cod_pre_aprobado
            from pr_pre_aprobados b
            join pr_solicitudes c
              on b.nro_solicitud = c.nro_solicitud
           where b.estado = 'D'
             and b.cod_modalidad = v_cod_mad_padre
             and b.cod_persona = v_cod_persona
             and b.nro_solicitud = v_nro_solicitud
             and exists (select 1
                    from pr_cta_prestamos bb
                   where bb.nro_solicitud = c.nro_solicitud
                     and bb.estado = 'C');
        when others then
          v_cod_pre_aprobado := null;
      end;
    
      if v_cod_pre_aprobado is not null then
        -- Recupera datos de CU - WF
        begin
          v_est_doc := fug_val_con_uni_per(v_cod_persona);
        exception
          when others then
            raise_application_error(-20000,
                                    'En FUG_VAL_CON_UNI_PER ' || SQLERRM);
        end;
        begin
          select count(1)
            into v_est_wf48
            from wf_circuitos
           where estado <> 'F'
             and referencia = v_cod_persona
             and cod_tip_circuito = 48;
        exception
          when no_data_found then
            v_est_wf48 := 0;
          when others then
            raise_application_error(-20000,
                                    'En wf_circuitos_48 ' || SQLERRM);
        end;
        begin
          select count(1)
            into v_est_wf3
            from wf_circuitos
           where estado <> 'F'
             and referencia = v_cod_persona
             and cod_tip_circuito = 3;
        exception
          when no_data_found then
            v_est_wf3 := 0;
          when others then
            raise_application_error(-20000,
                                    'En wf_circuitos_3 ' || SQLERRM);
        end;
        -- Valida CU y WF
        if v_est_doc = 'N' or
           (v_est_doc = 'S' and (v_est_wf48 > 0 or v_est_wf3 > 0)) then
        
          -- Valida datos caja ahorro
          if v_nro_cta_debito is not null then
          
            pag_cta.pr_obt_cuenta(v_nro_cta_debito);
            v_cod_mod_cta := pag_cta.g_ctas.cod_modulo;
            v_cod_mad_cta := pag_cta.g_ctas.cod_modalidad;
            v_cod_ofi_cta := pag_cta.g_ctas.cod_oficina;
          
            -- Recupera movimientos para reverso de la caja de ahorro
            begin
              select ab.fecha,
                     ab.hora,
                     ab.cod_usuario,
                     ab.cod_mod_padre,
                     ab.cod_mad_padre
                into v_fec_mov,
                     v_hor_mov,
                     v_cod_usu_mov,
                     v_cod_mod_mov,
                     v_cod_mad_mov
                from (select a.fecha,
                             a.hora,
                             a.cod_usuario,
                             a.cod_mod_padre,
                             a.cod_mad_padre
                        from ge_movimientos a
                       where a.cod_tra_padre = v_cod_tra_sal
                         and a.nro_cuenta = v_nro_cta_debito
                         and a.nro_documento = v_nro_documento
                      union
                      select a.fecha,
                             a.hora,
                             a.cod_usuario,
                             a.cod_mod_padre,
                             a.cod_mad_padre
                        from ah_movimientos_his a
                       where a.cod_tra_padre = v_cod_tra_sal
                         and a.nro_cuenta = v_nro_cta_debito
                         and a.nro_documento = v_nro_documento) ab;
            exception
              when no_data_found then
                v_fec_mov     := null;
                v_hor_mov     := null;
                v_cod_usu_mov := null;
                v_cod_mod_mov := null;
                v_cod_mad_mov := null;
              when others then
                raise_application_error(-20000,
                                        'En ah_cta_vistas para la Persona: ' ||
                                        v_cod_persona ||
                                        ', Cuenta Debito: ' ||
                                        v_nro_cta_debito || ' ' || SQLERRM);
            end;
            -- Se realiza el reverso de la caja de ahorro
            if sql%found then
              begin
                it.prg_rev_operacion(v_fec_mov,
                                     v_hor_mov,
                                     v_cod_usu_mov,
                                     v_cod_mod_mov,
                                     v_cod_mad_mov,
                                     v_cod_tra_sal);
              exception
                when others then
                  v_cod_error := 98;
                  v_lugar     := 'Reverso de la caja de ahorro.';
                  v_det_error := 'No se proceso ningun registro para la Cuenta ' ||
                                 v_nro_cta_debito || '-' || sqlerrm;
                  it.prg_ins_log_programas('PRP_BAJ_PRE_APROBADOS',
                                           v_lugar || ' - ' || v_det_error,
                                           v_cod_persona,
                                           v_nro_cta_debito);
              end;
            else
              v_cod_error := 99;
              v_lugar     := 'Reverso de la caja de ahorro.';
              v_det_error := 'No se proceso ningun registro para la Cuenta ' ||
                             v_nro_cta_debito || '-' || sqlerrm;
              it.prg_ins_log_programas('PRP_BAJ_PRE_APROBADOS',
                                       v_lugar || ' - ' || v_det_error,
                                       v_cod_persona,
                                       v_nro_cta_debito);
            end if;
            -- Recupera movimientos para reverso del prestamo
            begin
              select ab.fecha,
                     ab.hora,
                     ab.cod_usuario,
                     ab.cod_mod_padre,
                     ab.cod_mad_padre
                into v_fec_pre,
                     v_hor_pre,
                     v_cod_usu_pre,
                     v_cod_mod_pre,
                     v_cod_mad_pre
                from (select a.fecha,
                             a.hora,
                             cod_usuario,
                             cod_mod_padre,
                             cod_mad_padre
                        from ge_movimientos a
                       where a.cod_tra_padre = v_cod_tra_padre
                         and a.nro_cuenta = v_nro_cuenta
                      union
                      select a.fecha,
                             a.hora,
                             cod_usuario,
                             cod_mod_padre,
                             cod_mad_padre
                        from pr_movimientos_his a
                       where a.cod_tra_padre = v_cod_tra_padre
                         and a.nro_cuenta = v_nro_cuenta) ab;
            
            exception
              when no_data_found then
                v_fec_pre     := null;
                v_hor_pre     := null;
                v_cod_usu_pre := null;
                v_cod_mod_pre := null;
                v_cod_mad_pre := null;
              when others then
                raise_application_error(-20000,
                                        'En ah_cta_vistas para la Persona: ' ||
                                        v_cod_persona || ', Cuenta: ' ||
                                        v_nro_cuenta || ' ' || SQLERRM);
            end;
            dbms_lock.sleep(1);
            -- Se realiza el reverso del prestamo
            if sql%found then
              begin
                it.prg_rev_operacion(v_fec_pre,
                                     v_hor_pre,
                                     v_cod_usu_pre,
                                     v_cod_mod_pre,
                                     v_cod_mad_pre,
                                     v_cod_tra_padre);
              exception
                when others then
                  v_cod_error := 98;
                  v_lugar     := 'Reverso del Prestamo.';
                  v_det_error := 'No se proceso ningun registro para la cuenta ' ||
                                 v_nro_cuenta || '-' || sqlerrm;
                  it.prg_ins_log_programas('PRP_BAJ_PRE_APROBADOS',
                                           v_lugar || ' - ' || v_det_error,
                                           v_cod_persona,
                                           v_nro_cuenta);
              end;
            else
              v_cod_error := 99;
              v_lugar     := 'Reverso del Prestamo.';
              v_det_error := 'No se proceso ningun registro para la cuenta ' ||
                             v_nro_cuenta || '-' || sqlerrm;
              it.prg_ins_log_programas('PRP_BAJ_PRE_APROBADOS',
                                       v_lugar || ' - ' || v_det_error,
                                       v_cod_persona,
                                       v_nro_cuenta);
            end if;
            savepoint v_rev_cta_cte;
            -- Espera un 2 seg para que no de error de PK
            if mod(v_contador, 1) = 0 then
              dbms_lock.sleep(v_esp_segundos);
            end if;
            -- Se elimina el bloqueo de saldo
            if nvl(v_cod_error, 0) = 0 then
              it.pra_dbl_saldos(v_nro_cuenta, --prestamo
                                v_nro_cta_debito, --ahorro
                                v_fec_mov,
                                v_monto,
                                v_nro_documento,
                                reg.cod_moneda,
                                v_cod_causa,
                                v_cod_ofi_cta,
                                v_cod_mod_cta,
                                v_cod_mad_cta,
                                v_cod_err_sal);
            else
              v_cod_err_sal := 99;
            end if;
            -- Si no hubo error en el desbloqueo de saldo, continua
          
            if nvl(v_cod_err_sal, 0) = 0 then
              -- Se actualiza pr_pre_aprobados
              update pr_pre_aprobados cc
                 set nro_solicitud = null, estado = 'C'
               where estado = 'D'
                 and cod_modalidad = v_cod_mad_padre
                 and cod_persona = v_cod_persona
                 and fec_fin_oferta > v_fec_actual;
            
              if sql%notfound then
                v_lugar     := 'Actualiza pr_pre_aprobados.';
                v_det_error := 'No se proceso ningun registro para la persona (no es bloqueante) ' ||
                               v_cod_persona || '-' || sqlerrm;
                it.prg_ins_log_programas('PRP_BAJ_PRE_APROBADOS',
                                         v_lugar || ' - ' || v_det_error,
                                         v_cod_persona,
                                         v_nro_cuenta);
              end if;
            
              -- Inserta en pr_pre_apr_reversados
              insert into pr_pre_apr_reversados
                (cod_pre_aprobado,
                 nro_solicitud,
                 --  nro_documento,
                 cod_persona,
                 nro_cuenta,
                 monto,
                 cod_moneda,
                 fec_reverso,
                 usu_reverso)
              values
                (v_cod_pre_aprobado,
                 v_nro_solicitud,
                 -- p_nro_documento,
                 v_cod_persona,
                 v_nro_cuenta,
                 v_monto,
                 v_cod_moneda,
                 v_fec_actual,
                 user);
            
              if sql%notfound then
                v_cod_error := 99;
                v_lugar     := 'Inserta pr_pre_apr_reversados.';
                v_det_error := 'No se proceso ningun registro para la persona ' ||
                               v_cod_persona || '-' || sqlerrm;
                it.prg_ins_log_programas('PRP_BAJ_PRE_APROBADOS',
                                         v_lugar || ' - ' || v_det_error,
                                         v_cod_persona,
                                         v_nro_cuenta);
              end if;
            
              -- Si no hubo errores comitea
              commit;
            
            else
              v_cod_error := 99;
              v_lugar     := 'Validacion de bloqueo de saldo.';
              v_det_error := 'Ningun registro procesado para la persona.' ||
                             v_cod_persona;
            
              it.prg_ins_log_programas('PRP_BAJ_PRE_APROBADOS',
                                       v_lugar || ' - ' || v_det_error,
                                       v_cod_persona,
                                       v_nro_cuenta);
              rollback to savepoint v_rev_cta_cte;
              continue;
            end if;
          end if;
          -- Actualiza pr_solicitudes a L (Pendiente de Liquidación)
          if nvl(v_cod_error, 0) = 0 then
            begin
              update pr_solicitudes cc
                 set estado = 'L'
               where nro_solicitud = v_nro_solicitud;
            exception
              when others then
                raise_application_error(-20000,
                                        'En update pr_solicitudes a Pendiente de Liquidación, solicitud ' ||
                                        v_nro_solicitud || ' - cuenta ' ||
                                        reg.nro_cuenta || ' - ' || SQLERRM);
            end;
            if sql%notfound then
              v_lugar     := 'Actualiza solicitud del Prestamo.';
              v_det_error := 'No se proceso ningun registro para la solicitud ' ||
                             v_nro_solicitud || '-' || sqlerrm;
              it.prg_ins_log_programas('PRP_BAJ_PRE_APROBADOS',
                                       v_lugar || ' - ' || v_det_error,
                                       v_cod_persona,
                                       v_nro_cuenta);
            end if;
            commit;
          end if;
          -- Actualiza pr_solicitudes a N (Cancelada)
          if nvl(v_cod_error, 0) = 0 then
            begin
              update pr_solicitudes cc
                 set estado = 'N'
               where nro_solicitud = v_nro_solicitud;
            exception
              when others then
                raise_application_error(-20000,
                                        'En update pr_solicitudes a Cancelada, solicitud ' ||
                                        v_nro_solicitud || ' - cuenta ' ||
                                        reg.nro_cuenta || ' - ' || SQLERRM);
            end;
            if sql%notfound then
              v_lugar     := 'Actualiza solicitud del Prestamo.';
              v_det_error := 'No se proceso ningun registro para la solicitud ' ||
                             v_nro_solicitud || '-' || sqlerrm;
              it.prg_ins_log_programas('PRP_BAJ_PRE_APROBADOS',
                                       v_lugar || ' - ' || v_det_error,
                                       v_cod_persona,
                                       v_nro_cuenta);
            end if;
            commit;
          end if;
        else
          v_lugar     := 'Validacion de Contrato Unico.';
          v_det_error := 'Verificar estado de Contrato Unico y WorkFlow del circuito 3 y 48.' ||
                         sqlerrm;
          it.prg_ins_log_programas('PRP_BAJ_PRE_APROBADOS',
                                   v_lugar || ' - ' || v_det_error,
                                   v_cod_persona,
                                   v_nro_cuenta);
        end if;
      
      else
        v_lugar     := 'Validacion de prestamo Pre-Aprobado.';
        v_det_error := 'No tiene prestamos Pre-Aprobados.' || sqlerrm;
        it.prg_ins_log_programas('PRP_BAJ_PRE_APROBADOS',
                                 v_lugar || ' - ' || v_det_error,
                                 v_cod_persona,
                                 v_nro_cuenta);
      end if;
    
    end loop;
  else
    v_lugar     := 'Validacion del ultimo dia habil.';
    v_det_error := 'No es el ultimo dia habil del mes. ' || sqlerrm;
    it.prg_ins_log_programas('PRP_BAJ_PRE_APROBADOS',
                             v_lugar || ' - ' || v_det_error,
                             null,
                             null);
  end if;

exception
  when others then
    v_lugar     := 'When others del proceso PRP_BAJ_PRE_APROBADOS.';
    v_det_error := sqlerrm;
    it.prg_ins_log_programas('PRP_BAJ_PRE_APROBADOS',
                             v_lugar || ' - ' || v_det_error,
                             v_cod_persona,
                             v_nro_cuenta);
  
end;
/

