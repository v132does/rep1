create or replace package body it.pag_swe is

  procedure pr_gen_pag_ser_cnb(p_cod_ente                in varchar2,
                               p_cod_servicio            in number,
                               p_descripcion             in varchar2,
                               p_monto                   in number,
                               p_cod_moneda              in varchar2,
                               p_cod_transaccion_wepa    in varchar2,
                               p_cod_transaccion_bancard in varchar2,
                               p_error                   out number,
                               p_respuesta               out varchar2) is
  
    v_cod_transaccion_deb NUMBER(4);
    v_cod_transaccion_cre NUMBER(4);
    v_cod_tra_padre       NUMBER(4);
    v_codigo_modulo       NUMBER(3) := 4;
    v_codigo_modalidad    NUMBER(3) := 43;
    v_numero_secuencia    NUMBER(3) := 1;
    v_fecha_actual        DATE := it.pag_cal.fu_obt_fec_actual(v_codigo_modulo);
    v_det_error           ge_log_errores.det_error%type;
    v_cod_ofi_origen      ba_oficinas.cod_oficina%type;
    v_cta_wepa            ge_movimientos.nro_cuenta%type;
    v_cta_bancard         ge_movimientos.nro_cuenta%type;
    v_existe_e            varchar2(1);
    v_usuario             varchar2(15);
    v_hora_c              ge_movimientos.hora%TYPE;
    v_cod_ente            number := 9733;
    v_cod_usu_ser         ba_usuarios.cod_usuario%type := fug_obt_parentes(v_cod_ente,
                                                                        'USU_PAG_SER');
    v_cod_ofi_usu         ba_oficinas.cod_oficina%type := fug_obt_ofi_usuario(v_cod_usu_ser);
    v_existe_l            varchar2(1);
  begin
    begin
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 1;
    end;
  
    if nvl(p_cod_ente, 0) = 0 then
      p_error     := 1;
      p_respuesta := 'Ingresar codigo de Ente ';
      return;
    end if;
  
    begin
      Select 'S'
        into v_existe_e
        from ge_entes t
       where t.tipo = 'CN'
         and t.cod_ente = p_cod_ente;
    exception
      when no_data_found then
        v_existe_e := 'N';
      when others then
        v_existe_e := 'N';
    end;
  
    if nvl(v_existe_e, 'N') = 'N' then
      p_error     := 2;
      p_respuesta := 'Ente no registrado en Ge_entes ';
      return;
    end if;
  
    if p_monto is null or p_monto <= 0 then
      p_error     := 3;
      p_respuesta := 'Ingresar monto correcto ';
      return;
    end if;
  
    if p_cod_moneda is null then
      p_error     := 4;
      p_respuesta := 'Ingresar moneda ';
      return;
    elsif p_cod_moneda != it.pag_gen.fu_obt_mon_local then
      p_error     := 5;
      p_respuesta := 'Ingresar moneda correcta ';
      return;
    end if;
    --- UPS-457 control de liquidaciones----
    begin
        select 'S' 
          into v_existe_l
          from ge_cnb_liquidaciones s
         where s.nro_operacion = p_cod_transaccion_wepa
           and s.nro_transaccion = p_cod_transaccion_bancard;
    exception
         when no_data_found then
          v_existe_l:= 'N';
         when others then
          v_existe_l:= 'N';
    end;
    if nvl(v_existe_l, 'N') = 'S' then
      p_error     := 12;
      p_respuesta := 'Error al procesar transaccion - Operación Existente!';
      return;
    end if;
    --- UPS-457 control de liquidaciones----
    savepoint pago_servicio;
  
    if pae_cnf.fu_obt_est_modulo(1) != 2 then
      p_error     := 6;
      p_respuesta := 'Modulo Cerrado. No se puede operar';
    else
      if nvl(p_error, 0) != '0' then
        p_error     := 7;
        p_respuesta := 'Ocurrió un error en el proceso de pago';
        v_det_error := p_respuesta;
      else
        v_cod_tra_padre       := it.fug_obt_pardinamico(p_parametro  => 'COD_TRAN_PAD_CNB_BAN',
                                                        p_cod_moneda => p_cod_moneda);
        v_cod_transaccion_deb := it.fug_obt_pardinamico(p_parametro  => 'COD_TRAN_DEB_CNB_BAN',
                                                        p_cod_moneda => p_cod_moneda);
        v_cod_transaccion_cre := it.fug_obt_pardinamico(p_parametro  => 'COD_TRAN_CRED_CNB_BAN',
                                                        p_cod_moneda => p_cod_moneda);
      
        /* v_cta_wepa    := it.fug_obt_pardinamico(p_parametro  => 'CTA_OP_WEPA_CNB',
        p_cod_moneda => p_cod_moneda);*/
        v_cta_wepa    := it.fug_obt_parentes(p_cod_ente, 'CTA_OP_WEPA_CNB');
        v_cta_bancard := it.fug_obt_pardinamico(p_parametro  => 'CTA_OP_BANCARD',
                                                p_cod_moneda => p_cod_moneda);
      
        v_cod_ofi_origen := fug_obt_ofi_usuario(user);
        
        
        v_usuario   := it.fug_obt_mov_user(v_cod_usu_ser,'S_SER_USER_WEPAPAGSER'); 


        v_hora_c    := it.fug_obt_hora(v_usuario,'s_hor_movimi');
        
        pag_cta.pr_set_variables(p_cod_usuario => v_usuario,
                                 p_fec_valor => trunc(sysdate),
                                 p_cod_tra_padre => v_cod_tra_padre,
                                 p_estado => 'N',
                                 p_reversado => 'N',
                                 p_nro_secuencia => v_numero_secuencia,
                                 p_est_cuenta => null,
                                 p_cod_ofi_origen => v_cod_ofi_usu);
      
        --verificacion datos cuenta a Debitar
        pag_cta.pr_obt_cuenta(v_cta_wepa);
        pag_cta.pr_set_nro_documento2(p_nro_documento2 => p_cod_servicio);
        pag_cta.pr_set_nro_documento3(p_cod_ente);
        pag_cta.pr_set_referencia(p_cod_transaccion_bancard);
        pag_cta.pr_act_operacion(p_nro_cuenta      => v_cta_wepa,
                                 p_hora            => v_hora_c,
                                 p_tip_movimiento  => 'D',
                                 p_cod_moneda      => p_cod_moneda,
                                 p_monto           => p_monto,
                                 p_cod_tra_padre   => v_cod_tra_padre,
                                 p_cod_transaccion => v_cod_transaccion_deb,
                                 p_nro_documento   => p_cod_transaccion_wepa,
                                 p_cotizacion      => null,
                                 p_cod_ofi_origen  => v_cod_ofi_origen,
                                 p_cod_mod_padre   => v_codigo_modulo,
                                 p_cod_mad_padre   => v_codigo_modalidad,
                                 p_cod_tasa        => null,
                                 p_val_tasa        => null,
                                 p_concepto        => 'Debito pago servicio Wepa',
                                 p_emi_aviso       => 'N',
                                 p_nro_secuencia   => v_numero_secuencia,
                                 p_fec_valor       => trunc(sysdate),
                                 p_cod_banco       => null,
                                 p_cod_causa       => null,
                                 p_mto_equ_local   => null);
      
        if pag_cta.g_cod_error <> 0 then
          -- actualizacion con problemas
          p_error     := 8;
          p_respuesta := pag_cta.g_msj_error;
          v_det_error := substr('Ocurrió el sgte. error en el proceso de debito: ' ||
                                ltrim(to_char(pag_cta.g_cod_error, '000')) || ' ' ||
                                pag_cta.g_msj_error,
                                1,
                                4000);
        
        else
          -- Credito pago servicio
          pag_cta.pr_obt_cuenta(v_cta_bancard);
          pag_cta.pr_set_nro_documento2(p_nro_documento2 => p_cod_servicio);
          pag_cta.pr_set_nro_documento3(p_cod_ente);
          pag_cta.pr_set_referencia(p_cod_transaccion_bancard);
          pag_cta.pr_set_variables(p_cod_usuario => v_usuario,
                                 p_fec_valor => trunc(sysdate),
                                 p_cod_tra_padre => v_cod_tra_padre,
                                 p_estado => 'N',
                                 p_reversado => 'N',
                                 p_nro_secuencia => v_numero_secuencia,
                                 p_est_cuenta => null,
                                 p_cod_ofi_origen => v_cod_ofi_usu);
                                 
          pag_cta.pr_act_operacion(p_nro_cuenta      => v_cta_bancard,
                                   p_hora            => v_hora_c,
                                   p_tip_movimiento  => 'C',
                                   p_cod_moneda      => p_cod_moneda,
                                   p_monto           => p_monto,
                                   p_cod_tra_padre   => v_cod_tra_padre,
                                   p_cod_transaccion => v_cod_transaccion_cre,
                                   p_nro_documento   => p_cod_transaccion_wepa,
                                   p_cotizacion      => null,
                                   p_cod_ofi_origen  => v_cod_ofi_origen,
                                   p_cod_mod_padre   => v_codigo_modulo,
                                   p_cod_mad_padre   => v_codigo_modalidad,
                                   p_cod_tasa        => null,
                                   p_val_tasa        => null,
                                   p_concepto        => 'Credito pago servicio Wepa',
                                   p_emi_aviso       => 'N',
                                   p_nro_secuencia   => v_numero_secuencia,
                                   p_fec_valor       => trunc(sysdate),
                                   p_cod_banco       => null,
                                   p_cod_causa       => null,
                                   p_mto_equ_local   => null);
          if pag_cta.g_cod_error <> 0 then
            -- actualizacion con problemas
            p_error     := 9;
            p_respuesta := 'Ocurrió un error en el proceso de pago';
            v_det_error := substr('Ocurrió el sgte. error en el proceso de debito ' ||
                                  ltrim(to_char(pag_cta.g_cod_error, '000')) ||
                                  pag_cta.g_msj_error,
                                  1,
                                  4000);
          
          else
            begin
              insert into bw_pag_servicios
                (nro_cuenta,
                 cod_servicio,
                 fecha,
                 hora,
                 nro_transaccion,
                 nro_lote,
                 ip_usuario,
                 terminal,
                 cod_moneda,
                 mto_transaccion,
                 mto_comision,
                 mto_mora,
                 mto_interes,
                 reversado,
                 mto_debito,
                 cod_mon_servicio,
                 red_pago,
                 des_servicio,
                 par_enviados,
                 nro_documento)
              VALUES
                (v_cta_wepa,
                 p_cod_servicio,
                 v_fecha_actual,
                 v_hora_c,
                 p_cod_transaccion_bancard,
                 0,
                 null,
                 null,
                 p_cod_moneda,
                 p_monto,
                 null,
                 null,
                 null,
                 'N',
                 p_monto,
                 null,
                 6, -- Wepa
                 substr(p_descripcion, 1, 250),
                 null,
                 p_cod_transaccion_wepa);
            exception
              when others then
                p_error     := 10;
                p_respuesta := 'Error al procesar transaccion';
                v_det_error := 'Error al procesar transaccion ' ||
                               DBMS_UTILITY.format_error_backtrace || ' ' ||
                               DBMS_UTILITY.format_error_stack;
            end;
          
            begin
              insert into ge_cnb_liquidaciones
                (COD_ENTE,
                 NRO_OPERACION,
                 NRO_TRANSACCION,
                 FECHA,
                 COD_MONEDA,
                 MTO_LIQUIDAR,
                 MTO_TOTAL,
                 ESTADO,
                 MOT_ERROR,
                 TIP_OPE,
                 FEC_PROCESO)
              values
                (p_cod_ente,
                 p_cod_transaccion_wepa,
                 p_cod_transaccion_bancard,
                 trunc(sysdate),
                 p_cod_moneda,
                 p_monto,
                 p_monto,
                 'P',
                 null,
                 'D',
                 null);
            exception
              when others then
                p_error     := 11;
                p_respuesta := 'Error al procesar transaccion';
                v_det_error := 'Error al procesar transaccion ' ||
                               DBMS_UTILITY.format_error_backtrace || ' ' ||
                               DBMS_UTILITY.format_error_stack;
            end;
          end if;
        end if;
      end if;
    end if;
  
    --Verificacion para Retorno
    if p_error <> 0 then
      --hay que corregir
      v_det_error := substr(v_det_error ||'Cod.Wepa: '||p_cod_transaccion_wepa||' Cod.Bancard: '
      ||p_cod_transaccion_bancard,1,4000);
      prg_ins_log_programas('PAG_SWE.PR_GEN_PAG_SER_CNB',
                            v_det_error,
                            null,
                            null);
      rollback to pago_servicio;
    else
      --Retorno Operacion exitosa
      p_error     := 0;
      p_respuesta := 'Operacion Confirmada';
    end if;
  
  exception
    when others then
      p_error := 99;
      p_respuesta := 'Error en proceso de pago de servicio';
      v_det_error := substr('Error en proceso ' || 'Cod.Wepa: '||p_cod_transaccion_wepa||
                     ' Cod.Bancard: '||p_cod_transaccion_bancard||' '||
                     DBMS_UTILITY.format_error_backtrace || ' ' ||
                     DBMS_UTILITY.format_error_stack,1,4000);
      prg_ins_log_programas('PAG_SWE.PR_GEN_PAG_SER_CNB',
                            v_det_error,
                            null,
                            null);
  end pr_gen_pag_ser_cnb;

  procedure pr_pro_liq_cnb is
  
    v_cta_ente         ah_cta_vistas.nro_cuenta%type;
    v_cod_mon_local    ba_monedas.cod_moneda%type := pag_gen.fu_obt_mon_local;
    v_cod_modulo       ba_modulos.cod_modulo%type;
    v_cod_modalidad    ge_modalidades.cod_modalidad%type;
    v_est_cuenta       ge_cuentas.estado%type;
    v_cta_operativa    ge_cuentas.nro_cuenta%type;
    v_cod_modulo_pri   ba_modulos.cod_modulo%type;
    v_cod_moda_pri     ge_modalidades.cod_modalidad%type;
    v_hora_actual      ge_movimientos.hora%type := to_char(sysdate,'hh24:mi:ss');
    v_cod_tra_padre    varchar2(4);
    v_cod_ente         number := 9733;
    v_cod_usu_ser      ba_usuarios.cod_usuario%type := fug_obt_parentes(v_cod_ente,
                                                                        'USU_PAG_SER');
    v_cod_ofi_origen   ba_oficinas.cod_oficina%type := fug_obt_ofi_usuario(v_cod_usu_ser);
    v_det_error        ge_log_errores.det_error%type;
    v_saldo_cta        ah_cta_vistas.sal_total%type;
    v_monto_a_liquidar ge_movimientos.monto%type;
    v_sal_liq          ge_movimientos.monto%type;
    v_mon              varchar2(1);
    v_cod_error        number;
    v_msj_error        varchar2(300);
    v_cod_moneda       ba_monedas.cod_moneda%type := 'GS';
    v_fecha            date := trunc(sysdate - 1);
    v_fec_actual       date := pag_cal.fu_obt_fec_actual(1);
    v_can_dias         number := fug_obt_pardinamico('CAN_DIA_MOV_LIQCNB');
    v_usuario          varchar2(15);
    v_hora_c           ge_movimientos.hora%TYPE;
    v_numero_secuencia NUMBER(3) := 0;
  
    cursor c_cuentas is
      Select t.cod_ente,
             t.nro_operacion,
             t.cod_moneda,
             t.mto_liquidar,
             t.mto_total,
             t.nro_transaccion,
             rowid
        from ge_cnb_liquidaciones t
       where t.estado = 'P'
         and t.mto_liquidar > 0
         and t.fecha <= v_fecha
         and t.cod_ente = v_cod_ente
         and t.cod_moneda = v_cod_moneda
         and exists (select 1 from cc_movimientos_his a
                      where a.fecha >= (v_fec_actual - v_can_dias)
                        and a.nro_documento = t.nro_operacion
                        and a.referencia = to_char(t.nro_transaccion)
                        and a.cod_moneda = t.cod_moneda);
  
  begin
    begin
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 1;
    end;
  
    if v_cod_moneda is null then
      v_cod_error := 1;
      v_msj_error := 'Moneda no puede ser null';
    end if;
  
    if v_fecha is null then
      v_cod_error := 2;
      v_msj_error := 'Fecha no puede ser null';
    end if;
  
    if v_cod_ente is null then
      v_cod_error := 3;
      v_msj_error := 'Ente no puede ser nulo. Verificar';
    end if;
    --recupera la cuenta del ente y la cuenta operativa para los movimientos
    if v_cod_moneda = v_cod_mon_local then
      v_cta_ente      := fug_obt_parentes(v_cod_ente, 'CTA_AH_WEP_GS');
      v_cta_operativa := fug_obt_parentes(v_cod_ente, 'CTA_OP_WEPA_CNB');
      /*else
      v_cta_ente      := fug_obt_parentes(v_cod_ente, 'CTA_AH_CNB_USD');
      v_cta_operativa := fug_obt_parentes(v_cod_ente, 'CTA_OP_CNB_USD');*/
    end if;
  
    --recupera datos de la cuenta parametrizada para el ente CNB
    if v_cta_ente is not null then
      begin
        select cod_modulo, cod_modalidad, estado
          into v_cod_modulo, v_cod_modalidad, v_est_cuenta
          from ge_cuentas
         where nro_cuenta = v_cta_ente;
      exception
        when no_data_found then
          v_cod_error := 4;
          v_msj_error := 'Error al recuperar datos de la cuenta: ' ||
                         v_cta_ente;
      end;
    end if;
  
    begin
      pag_cta.pr_obt_cuenta(v_cta_ente);
      v_saldo_cta := pag_cta.g_ctas.sal_disponible;
    exception
      when no_data_found then
        v_cod_error := 5;
        v_msj_error := 'Error al recuperar datos de la Cta. de Ahorro: ' ||
                       v_cta_ente;
      when others then
        v_cod_error := 6;
        v_msj_error := 'Error al recuperar datos de la Cta. de Ahorro: ' ||
                       v_cta_ente;
    end;
  
    if v_cta_operativa is not null then
      begin
        select cod_modulo, cod_modalidad
          into v_cod_modulo_pri, v_cod_moda_pri
          from ge_cuentas
         where nro_cuenta = v_cta_operativa;
      exception
        when no_data_found then
          v_cod_error := 7;
          v_msj_error := 'Error al recuperar datos de la Cta. Operativa: ' ||
                         v_cta_operativa;
      end;
    end if;
    v_cod_tra_padre := it.fug_obt_pardinamico(p_parametro  => 'COD_TRAN_PAD_CNB_BAN',
                                              p_cod_moneda => v_cod_moneda);
    -------------------------------------------------
    --si no hubo error continua el proceso
    if nvl(v_cod_error, 0) = 0 and nvl(v_saldo_cta, 0) > 0 then
      -------------------------------------------------------------------------------------
      for i in c_cuentas loop
        savepoint liquidacion;
          v_cod_error := null; --inicializo variable
        
          if v_saldo_cta >= i.mto_liquidar then
            v_monto_a_liquidar := i.mto_liquidar;
            v_mon              := 'L';
          else
            v_monto_a_liquidar := v_saldo_cta;
            v_mon              := 'P';
          end if;
        
          --obtiene el cod_tra_padre dependiendo del servicio
          if v_cod_tra_padre is null then
            v_cod_error := 8;
            v_msj_error := 'Error al buscar transaccion Padre.';
          end if;
          if nvl(v_cod_error, 0) = 0 then
            v_hora_actual := fug_obt_hor_disponible(v_fec_actual,v_hora_actual,v_cod_usu_ser,'N');
            if v_numero_secuencia >= 998 then
              v_numero_secuencia := 0;
            end if;
            begin
            
            v_usuario   := it.fug_obt_mov_user(v_cod_usu_ser,'S_SER_USER_WEPAPAGSER'); 
            v_hora_c    := it.fug_obt_hora(v_usuario,'s_hor_movimi');
           
            pag_cta.pr_set_variables(p_cod_usuario => v_usuario,
                                     p_fec_valor => trunc(sysdate),
                                     p_cod_tra_padre => v_cod_tra_padre,
                                     p_estado => 'N',
                                     p_reversado => 'N',
                                     p_nro_secuencia => v_numero_secuencia,
                                     p_est_cuenta => null,
                                     p_cod_ofi_origen => v_cod_ofi_origen,
                                     p_cod_mod_padre => v_cod_modulo_pri,
                                     p_cod_mad_padre => v_cod_moda_pri);
            
              pag_cta.pr_nro_caja(p_nro_caja => null);
              pag_cta.pr_act_operacion(p_nro_cuenta      => v_cta_ente,
                                       p_hora            => v_hora_c,
                                       p_tip_movimiento  => 'D',
                                       p_cod_moneda      => v_cod_moneda,
                                       p_monto           => v_monto_a_liquidar,
                                       p_cod_tra_padre   => v_cod_tra_padre,
                                       p_cod_transaccion => 503,
                                       p_nro_documento   => i.nro_operacion,
                                       p_cotizacion      => null,
                                       p_cod_ofi_origen  => v_cod_ofi_origen,
                                       p_cod_mod_padre   => v_cod_modulo_pri,
                                       p_cod_mad_padre   => v_cod_moda_pri,
                                       p_cod_tasa        => null,
                                       p_val_tasa        => null,
                                       p_concepto        => 'Debito Liquidacion Wepa',
                                       p_emi_aviso       => 'N',
                                       p_nro_secuencia   => v_numero_secuencia,
                                       p_fec_valor       => trunc(sysdate),
                                       p_cod_banco       => null,
                                       p_cod_causa       => null,
                                       p_mto_equ_local   => null);
              if pag_cta.g_cod_error <> 0 then
                v_cod_error := pag_cta.g_cod_error;
                v_msj_error := pag_cta.g_msj_error;
                rollback to liquidacion;
                v_det_error := 'Nro_operacion : ' || i.nro_operacion ||
                               ' - ' || v_cod_error || ' - ' || v_msj_error;
                prg_ins_log_programas('PAG_SWE.PR_PRO_LIQ_CNB',
                                      v_det_error,
                                      null,
                                      v_cta_ente);
                begin
                  update ge_cnb_liquidaciones t
                     set t.mot_error = substr(v_msj_error, 1, 250)
                   where rowid = i.rowid;
                exception
                  when others then
                    v_cod_error := 9;
                    v_det_error := substr('Error al actualizar registro liquidado. Movimiento: ' ||
                                          i.nro_operacion || ' - Ente: ' ||
                                          v_cod_ente ||
                                          DBMS_UTILITY.format_error_backtrace || ' ' ||
                                          DBMS_UTILITY.format_error_stack,
                                          1,
                                          4000);
                    prg_ins_log_programas('PAG_SWE.PR_PRO_LIQ_CNB',
                                          v_det_error,
                                          null,
                                          v_cta_ente);
                end;
              end if;
              if nvl(v_cod_error, 0) = 0 then
                pag_cta.pr_set_variables(p_cod_usuario => v_usuario,
                                     p_fec_valor => trunc(sysdate),
                                     p_cod_tra_padre => v_cod_tra_padre,
                                     p_estado => 'N',
                                     p_reversado => 'N',
                                     p_nro_secuencia => v_numero_secuencia,
                                     p_est_cuenta => null,
                                     p_cod_ofi_origen => v_cod_ofi_origen,
                                     p_cod_mod_padre => v_cod_modulo_pri,
                                     p_cod_mad_padre => v_cod_moda_pri);
                                     
                pag_cta.pr_nro_caja(p_nro_caja => null);
                pag_cta.pr_act_operacion(p_nro_cuenta      => v_cta_operativa,
                                         p_hora            => v_hora_c,
                                         p_tip_movimiento  => 'C',
                                         p_cod_moneda      => v_cod_moneda,
                                         p_monto           => v_monto_a_liquidar,
                                         p_cod_tra_padre   => v_cod_tra_padre,
                                         p_cod_transaccion => 602,
                                         p_nro_documento   => i.nro_operacion,
                                         p_cotizacion      => null,
                                         p_cod_ofi_origen  => v_cod_ofi_origen,
                                         p_cod_mod_padre   => v_cod_modulo_pri,
                                         p_cod_mad_padre   => v_cod_moda_pri,
                                         p_cod_tasa        => null,
                                         p_val_tasa        => null,
                                         p_concepto        => 'Credito Liquidacion Wepa',
                                         p_emi_aviso       => 'N',
                                         p_nro_secuencia   => v_numero_secuencia,
                                         p_fec_valor       => trunc(sysdate),
                                         p_cod_banco       => null,
                                         p_cod_causa       => null,
                                         p_mto_equ_local   => null);
                if pag_cta.g_cod_error <> 0 then
                  v_cod_error := pag_cta.g_cod_error;
                  v_msj_error := pag_cta.g_msj_error;
                  rollback to liquidacion;
                  v_det_error := 'Nro_operacion : ' || i.nro_operacion ||
                                 ' - ' || v_cod_error || ' - ' ||
                                 v_msj_error;
                  prg_ins_log_programas('PAG_SWE.PR_PRO_LIQ_CNB',
                                        v_det_error,
                                        null,
                                        v_cta_operativa);
                  begin
                    update ge_cnb_liquidaciones t
                       set t.mot_error = substr(v_msj_error, 1, 250)
                     where rowid = i.rowid;
                  exception
                    when others then
                      v_cod_error := 10;
                      v_det_error := substr('Error al actualizar registro liquidado. Movimiento: ' ||
                                            i.nro_operacion || ' - Ente: ' ||
                                            v_cod_ente ||
                                            DBMS_UTILITY.format_error_backtrace || ' ' ||
                                            DBMS_UTILITY.format_error_stack,
                                            1,
                                            4000);
                      prg_ins_log_programas('PAG_SWE.PR_PRO_LIQ_CNB',
                                            v_det_error,
                                            null,
                                            v_cta_operativa);
                  end;
                else
                  --no hubo errores se puede actualizar la tabla de liquidacion
                  v_sal_liq := i.mto_liquidar - v_monto_a_liquidar;
                
                  begin
                    update ge_cnb_liquidaciones t
                       set t.estado       = v_mon,
                           t.fec_proceso  = trunc(sysdate),
                           t.mto_liquidar = decode(v_mon, 'L', 0, v_sal_liq)
                     where rowid = i.rowid;
                  exception
                    when others then
                      v_cod_error := 11;
                      v_msj_error := 'Error al actualizar registro.';
                      v_det_error := substr('Error al actualizar registro. Nro_operacion: ' || i.nro_operacion ||
                                            DBMS_UTILITY.format_error_backtrace || ' ' ||
                                            DBMS_UTILITY.format_error_stack,
                                            1,
                                            4000);
                      rollback to liquidacion;
                  end;
                end if;
              end if;
            exception
              when others then
                v_cod_error := 12;
                v_msj_error := 'Error al procesar Liquidacion.';
                v_det_error := substr('Error al procesar Liquidacion. Nro_operacion: ' || i.nro_operacion ||
                                      DBMS_UTILITY.format_error_backtrace || ' ' ||
                                      DBMS_UTILITY.format_error_stack,
                                      1,
                                      4000);
            end;
          end if;
        
          if nvl(v_cod_error, 0) != 0 then
            v_det_error := substr('Error : ' || v_cod_error || ' - Nro_operacion: ' || i.nro_operacion ||
                                  v_msj_error || ' - ' || v_det_error,
                                  1,
                                  4000);
            PRG_INS_LOG_PROGRAMAS('PAG_SWE.PR_PRO_LIQ_CNB',
                                  v_det_error,
                                  null,
                                  null);
          end if;
        commit;
      end loop;
      begin
       update ge_cnb_liquidaciones t
          set t.mot_error = 'No se encuentra movimiento para la liquidacion'
        where t.estado = 'P'
          and t.mto_liquidar > 0
          and t.fecha <= v_fecha
          and t.cod_ente = v_cod_ente
          and t.cod_moneda = v_cod_moneda
          and not exists (select 1 from cc_movimientos_his a
                           where a.fecha >= (v_fec_actual - v_can_dias)
                             and a.nro_documento = t.nro_operacion
                             and a.referencia = to_char(t.nro_transaccion)
                             and a.cod_moneda = t.cod_moneda);
      end;
      -------------------------------------------------------------------------------------
      if nvl(v_cod_error, 0) = 0 then
        v_cod_error := 0;
      else
        v_cod_error := nvl(v_cod_error, 99);
        v_msj_error := 'Lote de Liquidacion No Procesado - ' || v_cod_ente || '-' ||
                       v_cod_moneda || '-' || pag_cta.g_msj_error;
      end if;
    end if;
    if nvl(v_cod_error, 0) != 0 then
      v_det_error := 'Ente : ' || v_cod_ente || '-' || v_msj_error;
      PRG_INS_LOG_PROGRAMAS('PAG_SWE.PR_PRO_LIQ_CNB',
                            v_det_error,
                            null,
                            null);
    end if;
    if nvl(v_saldo_cta, 0) <= 0 then
      v_det_error := 'Cuenta: ' || v_cta_ente || ' con Saldo ' || v_saldo_cta||'.';
      PRG_INS_LOG_PROGRAMAS('PAG_SWE.PR_PRO_LIQ_CNB',
                            v_det_error,
                            null,
                            null);
    end if;
  exception
    when others then
      v_cod_error := 14;
      v_det_error := substr('Error al ejecutar el proceso de liquidacion ' ||
                            DBMS_UTILITY.format_error_backtrace || ' ' ||
                            DBMS_UTILITY.format_error_stack,
                            1,
                            4000);
      PRG_INS_LOG_PROGRAMAS('PAG_SWE.PR_PRO_LIQ_CNB',
                            v_cod_error || ' - ' || v_det_error,
                            null,
                            null);
      rollback;
  end pr_pro_liq_cnb;
end pag_swe;
/

