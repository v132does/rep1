create or replace procedure it.PRG_DEB_AUT_DEU_CLEARING(p_nro_cuenta in ah_cta_vistas.nro_cuenta%type,
                                                        p_fec_operacion in ge_deu_com_clientes.fec_operacion%type,
                                                        p_nro_lote      in ge_deu_com_clientes.nro_lote%type,
                                                        p_cod_ente      in ge_deu_com_clientes.cod_ente%type,
                                                        p_cod_error  out number,
                                                        p_mensaje    out varchar2) is

  v_mon_tot_debito      it.ge_deu_com_clientes.mto_tot_pend%type;
  v_res_bloqueo         varchar2(4000);
  v_res_desbloqueo      varchar2(4000);
  v_men_error           varchar2(4000);
  v_nro_cta_transitoria ge_par_dinamicos.val_parametro%type;
  v_fec_actual          ge_calendarios.fec_actual%type;
  v_hora                ge_movimientos.hora%type;
  v_cod_error           number := 0;
  v_horario             varchar2(1);
  v_es_mov_noc          varchar2(1);
  v_es_cta_noc          varchar2(1);
  v_fec_valor           ge_calendarios.fec_actual%type;
  v_cod_ofi_origen      ah_cta_vistas.cod_oficina%type;
  v_secuencia           ge_movimientos.nro_secuencia%type;
  v_mto_debito          ge_movimientos.monto%type;
  v_nro_transaccion     ge_movimientos.nro_documento%type;
  v_nro_lote            it.ge_deu_com_clientes.nro_lote%type;
  v_pago                varchar2(1);
  v_rollback            varchar2(1) := 'N';
  v_mon_debito          ge_cuentas.cod_moneda%type;
  v_cod_mod_debito      ge_cuentas.cod_modulo%type;
  v_cod_mad_debito      ge_cuentas.cod_modalidad%type;
  v_cod_ofi_debito      ge_cuentas.cod_oficina%type;
  v_mon_transitoria     ge_cuentas.cod_moneda%type;
  v_cod_mod_transitoria ge_cuentas.cod_modulo%type;
  v_cod_mad_transitoria ge_cuentas.cod_modalidad%type;
  v_cod_ofi_transitoria ge_cuentas.cod_oficina%type;
  v_sal_disponible      ah_cta_vistas.sal_total%type;
  v_moneda              ba_monedas.cod_moneda%type;
  v_cta_wepa            varchar2(500);
  v_usu_cle             ba_usuarios.cod_usuario%type := fug_obt_pardinamico('USU_CLE_WEPA');
  v_cod_tra_padre       ge_movimientos.cod_tra_padre%type := 8950;
  v_est_inicial         ba_modulos.estado%type;
  v_est_actual          ba_modulos.estado%type;

  procedure lp_ver_horario(p_cod_ofi_origen in ba_oficinas.cod_oficina%type,
                           p_modulo         in ba_modulos.cod_modulo%type,
                           p_horario        out varchar2,
                           p_es_mov_noc     out varchar2,
                           p_es_cta_noc     out varchar2,
                           p_fec_actual     out date,
                           p_fec_valor      out date,
                           p_cod_error      out number,
                           p_men_error      out varchar2) is
  
    v_est_modulo ba_modulos.estado%type;
  begin
    p_cod_error  := 0;
    p_horario    := 'D'; -- dia normal
    p_es_mov_noc := 'N'; -- para grabar en las tablas nocturnas
    p_es_cta_noc := 'N';
    p_fec_actual := pag_cal.fu_obt_fec_actual(p_modulo);
    v_est_modulo := pae_cnf.fu_obt_est_modulo(p_modulo);
  
    if fug_obt_pardinamico('ACT_NOCTURNO') = 'N' then
      p_cod_error := '1070';
      p_men_error := 'Modulo en proceso de cierre';
    elsif v_est_modulo in (1,6) then/*FSOP-20695*/
        p_cod_error := '1070';
        p_men_error := 'Modulo en proceso de cierre';
    elsif v_est_modulo = 2 then
        p_horario    := 'D'; -- dia normal
        p_es_mov_noc := 'N'; -- para grabar en las tablas nocturnas
        p_es_cta_noc := 'N';
        p_fec_actual := pag_cal.fu_obt_fec_actual(p_modulo);
      else
        p_horario := 'N'; -- noche
        if v_est_modulo <> 1 then
          p_fec_actual := pag_cal.fu_obt_fec_habil(p_fec_actual + 1,
                                                   1,
                                                   p_cod_ofi_origen);
        end if;
        p_es_mov_noc := 'S'; -- para grabar en las tablas nocturnas
        p_es_cta_noc := 'S'; -- solo para que llavee la cuenta nocturna
      end if;
    pag_cta.g_horario := p_horario;
    p_fec_valor       := trunc(sysdate);
    v_est_inicial     := v_est_modulo;    
  EXCEPTION
    WHEN OTHERS THEN
      p_cod_error := 99;
      p_men_error := substr('lp_ver_horario' || ' ' ||
                            DBMS_UTILITY.format_error_backtrace || ' ' ||
                            DBMS_UTILITY.format_error_stack,
                            1,
                            4000);
    
  END lp_ver_horario;
begin
   savepoint cobro;
  v_rollback := 'S';
  begin
    pre_ini_aplicacion;
    pae_cnf.g_cod_modulo := 1;
  end;
  
  v_cod_ofi_origen      := fug_obt_ofi_usuario('FIELCOCNB');

   BEGIN
      select d.mto_tot_pend, d.nro_lote,d.cod_moneda
        into v_mon_tot_debito, v_nro_lote,v_moneda
        from it.ge_deu_com_clientes d
       where d.nro_cta_debito = p_nro_cuenta
         and d.fec_operacion  = p_fec_operacion
         and d.nro_lote       = p_nro_lote
         and d.cod_ente       = p_cod_ente
         and d.estado != 'P';
    EXCEPTION
      when no_data_found then
        v_mon_tot_debito := 0;
      when others then
        p_cod_error := 3;
        p_mensaje   := 'Error al verificar si cuenta tiene deuda pendiente ' ||
                       SQLERRM;
    END;
    
    v_nro_cta_transitoria := fug_obt_pardinamico('NRO_CTA_TRANSITORIA',null,null,v_moneda,null);
    v_cta_wepa :=  fug_obt_pardinamico('NRO_CTA_WEPA',null,null,v_moneda,null); 
    
    if nvl(v_mon_tot_debito, 0) > 0 and nvl(p_cod_error, 0) = 0 then
      --Desbloqueo de cuenta
      v_hora            := fug_ini_hora;
      v_hora            := fug_obt_hor_disponible(v_fec_actual,
                                                  v_hora,
                                                  'CLEARING',
                                                  v_es_mov_noc);
      --if v_cta_wepa != p_nro_cuenta then                                         
      --Si la cuenta es Wepa no se realiza el desbloqueo
      if (instr(v_cta_wepa,','||p_nro_cuenta||',')) = 0 then   
      v_res_desbloqueo  := it.FUG_DES_BLO_CTA_CLEARING(p_nro_cuenta  => p_nro_cuenta,
                                                       p_tip_bloqueo => 'D',
                                                       p_estado      => 'N',
                                                       p_hora        => v_hora);
       if v_res_desbloqueo!='OK' then
         p_cod_error := 8;
         p_mensaje   := v_res_desbloqueo;
       end if;
       
      end if;
      v_nro_transaccion := to_number(to_char(v_nro_lote) ||
                                     to_char(sysdate, 'ss'));
                                     
      v_hora := pag_gen.fu_obt_sig_segundo(v_hora);
    
     if nvl(p_cod_error,0) = 0 then
        --Debito de la cuenta
      
        begin
          select c.cod_moneda, c.cod_modalidad, c.cod_modulo, c.cod_oficina
            into v_mon_debito,
                 v_cod_mad_debito,
                 v_cod_mod_debito,
                 v_cod_ofi_debito
            from ge_cuentas c
           where nro_cuenta = p_nro_cuenta;
        exception
          when no_data_found then
            p_cod_error := 4;
            p_mensaje   := 'Cuenta no existe ' || p_nro_cuenta;
          when others then
            p_cod_error := 4;
            p_mensaje   := 'Error al obtener datos de la cuenta ' ||
                           sqlerrm;
        end;
      
        lp_ver_horario(v_cod_ofi_debito,
                       '3',/*v_cod_mod_debito,*/--FSOP-20695 siempre debe tomar el 3 para validar el horario, por ser el maestro de los módulos
                       v_horario,
                       v_es_mov_noc,
                       v_es_cta_noc,
                       v_fec_actual,
                       v_fec_valor,
                       v_cod_error,
                       v_men_error);
      
        if nvl(v_cod_error, 0) != 0 then
          p_cod_error := 3;
          p_mensaje   := v_men_error;
        
        else
           pag_cta.PR_OBT_CUENTA(p_nro_cuenta);
           v_sal_disponible:=nvl(pag_cta.G_CTAS.SAL_DISPONIBLE,0);
         
          if nvl(v_sal_disponible, 0) > 0 then
            if v_sal_disponible >= v_mon_tot_debito then
              v_mto_debito := v_mon_tot_debito; --se le debita la totalidad de la deuda
              v_pago       := 'P'; --total
            else
              v_mto_debito := v_sal_disponible; -- se le debita la totalidad del saldo
              v_pago       := 'S'; --parcial
            end if;
            v_secuencia := 0;
            pag_cta.PR_SET_NRO_DOCUMENTO2(v_nro_lote);
          
            --Verificamos que el estado del modulo aún se encuentre disponible
            v_est_actual:=pae_cnf.fu_obt_est_modulo(3);/*FSOP-20695*/
            if (v_est_inicial!=v_est_actual or v_est_actual in (1,6)) then
                 p_cod_error := 3;
                 p_mensaje   := 'Entidad en proceso de cierre, vuelva a intentar';
                 raise_application_error(-20000,p_mensaje);
            end if;/*FSOP-20695*/

            pag_cta.pr_act_operacion(p_nro_cuenta      => p_nro_cuenta,
                                     p_hora            => v_hora,
                                     p_tip_movimiento  => 'D',
                                     p_cod_moneda      => v_mon_debito,
                                     p_monto           => v_mto_debito,
                                     p_cod_tra_padre   => v_cod_tra_padre,
                                     p_cod_transaccion => 8916,
                                     p_nro_documento   => v_nro_transaccion,
                                     p_cotizacion      => null,
                                     p_cod_ofi_origen  => v_cod_ofi_origen,
                                     p_cod_mod_padre   => v_cod_mod_debito,
                                     p_cod_mad_padre   => v_cod_mad_debito,
                                     p_cod_tasa        => null,
                                     p_val_tasa        => null,
                                     p_concepto        => 'Débito por deuda clearing Wepa',
                                     p_emi_aviso       => 'N',
                                     p_nro_secuencia   => v_secuencia,
                                     p_fec_valor       => v_fec_valor,
                                     p_cod_banco       => null,
                                     p_cod_causa       => null,
                                     p_mto_equ_local   => null);
          
            if pag_cta.g_cod_error <> 0 then
              -- actualizacion con problemas
              p_cod_error := 4;
              p_mensaje   := p_cod_error || ' ' || pag_cta.G_MSJ_ERROR;
            else
              --Credito en la cuenta transitoria
              if nvl(v_nro_cta_transitoria, 'X') != 'X' then
                if nvl(p_cod_error, 0) = 0 then
                  begin
                    select c.cod_moneda,
                           c.cod_modalidad,
                           c.cod_modulo,
                           c.cod_oficina
                      into v_mon_transitoria,
                           v_cod_mad_transitoria,
                           v_cod_mod_transitoria,
                           v_cod_ofi_transitoria
                      from ge_cuentas c
                     where nro_cuenta = v_nro_cta_transitoria;
                  exception
                    when no_data_found then
                      p_cod_error := 4;
                      p_mensaje   := 'Cuenta no existe ' ||
                                     v_nro_cta_transitoria;
                    when others then
                      p_cod_error := 4;
                      p_mensaje   := 'Error al obtener datos de la cuenta transitoria ' ||
                                     sqlerrm;
                  end;
                  pag_cta.PR_SET_NRO_DOCUMENTO2(v_nro_lote);
                  pag_cta.pr_set_variables(v_usu_cle,
                           v_fec_valor,
                           v_cod_tra_padre,
                           'N',
                           'N',
                           v_secuencia,
                           null,
                           fug_obt_ofi_usuario(v_usu_cle),
                           v_cod_mod_debito,
                           v_cod_mad_debito);

            --Verificamos que el estado del modulo aún se encuentre disponible
            v_est_actual:=pae_cnf.fu_obt_est_modulo(3);/*FSOP-20695*/
            if (v_est_inicial!=v_est_actual or v_est_actual in (1,6)) then
                 p_cod_error := 3;
                 p_mensaje   := 'Entidad en proceso de cierre, vuelva a intentar';
                 raise_application_error(-20001,p_mensaje);
            end if;/*FSOP-20695*/

                  pag_cta.pr_act_operacion(p_nro_cuenta      => v_nro_cta_transitoria,
                                           p_hora            => v_hora,
                                           p_tip_movimiento  => 'C',
                                           p_cod_moneda      => v_mon_transitoria,
                                           p_monto           => v_mto_debito,
                                           p_cod_tra_padre   => v_cod_tra_padre,
                                           p_cod_transaccion => 8917,
                                           p_nro_documento   => v_nro_transaccion,
                                           p_cotizacion      => null,
                                           p_cod_ofi_origen  => v_cod_ofi_origen,
                                           p_cod_mod_padre   => v_cod_mod_debito, --v_cod_mod_transitoria,
                                           p_cod_mad_padre   => v_cod_mad_debito, --v_cod_mad_transitoria,
                                           p_cod_tasa        => null,
                                           p_val_tasa        => null,
                                           p_concepto        => 'Crédito por deuda clearing Wepa',
                                           p_emi_aviso       => 'N',
                                           p_nro_secuencia   => v_secuencia,
                                           p_fec_valor       => v_fec_valor,
                                           p_cod_banco       => null,
                                           p_cod_causa       => null,
                                           p_mto_equ_local   => null);
                
                  if pag_cta.g_cod_error <> 0 then
                    -- actualizacion con problemas
                    p_cod_error := 5;
                    p_mensaje   := p_cod_error || ' ' ||
                                   pag_cta.G_MSJ_ERROR;
                  end if;
                end if;
              else
                p_cod_error := 6;
                p_mensaje   := 'No se encuentra configurado el parametro "NRO_CTA_TRANSITORIA"';
              end if;
            end if;
          else
            p_cod_error := 7;
            p_mensaje   := 'La cuenta no tiene saldo disponible';
          end if;
        end if;
     end if;
       
      if nvl(p_cod_error, 0) = 0 then
        --actualizo la tabla
        begin
          update it.ge_deu_com_clientes c
             set c.mto_tot_pend  = c.mto_tot_pend - v_mto_debito,
                 c.estado        = v_pago
           where nro_cta_debito  = p_nro_cuenta
             and nro_lote        = p_nro_lote
             and c.fec_operacion = p_fec_operacion
             and c.cod_ente      = p_cod_ente
             and c.estado != 'P';
          if sql%rowcount = 0 then
            p_cod_error := 9;
            p_mensaje   := ' No se pudo actualizo registro. Nro lote: ' ||
                           v_nro_lote || ' Monto debitado: ' ||
                           v_mto_debito;
          end if;
        exception
          when others then
            p_cod_error := 10;
            p_mensaje   := substr('Error al actualizar registro ' ||
                                  sqlerrm,
                                  1,
                                  4000);
        end;
        --Bloqueo de cuenta
        if nvl(v_res_desbloqueo,'X') = 'OK' then
          -- si se pudo hacer el desbloqueo
          v_res_bloqueo := it.FUG_DES_BLO_CTA_CLEARING(p_nro_cuenta  => p_nro_cuenta,
                                                       p_tip_bloqueo => 'B',
                                                       p_estado      => 'D',
                                                       p_hora        => v_hora);
          if v_res_bloqueo != 'OK' then
            p_cod_error := 8;
            p_mensaje   := v_res_bloqueo;
          end if;
        end if;
      end if;
    end if;

  if nvl(p_cod_error, 0) != '0' then
       rollback to cobro;
  
    it.prg_ins_log_programas('PRG_DEB_AUT_DEU_CLEARING',
                             p_mensaje,
                             null,
                             p_nro_cuenta);
  else
    p_cod_error := 0;
    if nvl(v_mon_tot_debito, 0) > 0 then
      p_mensaje := 'Proceso de cobro automático finalizado correctamente';
    else
      p_mensaje := 'Cliente no tiene deuda pendiente de pago';
    end if;
  end if;

exception
  when others then
    if nvl(v_rollback, 'N') = 'S' then
      rollback to cobro;
    end if;
    if p_mensaje is null then-- para tomar el error anterior
    p_cod_error := 99;
    p_mensaje   := 'Ocurrio un error inesperado en el proceso de cobro automatico ';
    end if;
    prg_ins_log_programas('PRG_DEB_AUT_DEU_CLEARING',
                          substr(p_mensaje || ' ' ||
                                 DBMS_UTILITY.format_error_stack || ' - ' ||
                                 DBMS_UTILITY.format_error_backtrace,
                                 1,
                                 4000),
                          null,
                          p_nro_cuenta);
end PRG_DEB_AUT_DEU_CLEARING;
/

