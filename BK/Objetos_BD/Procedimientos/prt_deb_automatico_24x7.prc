CREATE OR REPLACE PROCEDURE IT.PRT_DEB_AUTOMATICO_24x7
(
   p_cod_persona    IN VARCHAR2 DEFAULT NULL,
  -- p_nro_cuenta     IN VARCHAR2 DEFAULT NULL,
   p_cta_debito     IN VARCHAR2 DEFAULT NULL
   --p_cod_usu_origen IN VARCHAR2 DEFAULT NULL
) IS
v_mto_mora ta_cta_tarjetas.mto_mora%type := 0;
v_dia_mora ta_cta_tarjetas.dia_mora%type := 0;
v_cod_moneda ta_cta_tarjetas.cod_moneda%type;
v_cod_modulo ta_cta_tarjetas.cod_modulo%type;
v_cod_modalidad ta_cta_tarjetas.cod_modalidad%type;
v_cod_oficina ta_cta_tarjetas.cod_oficina%type;
v_nro_tarjeta ta_tarjetas.nro_tarjeta%type;
v_hora     ge_movimientos.hora%type;
v_hor_actual ge_movimientos.hora%type := to_char(sysdate,'HH24:MI:SS');
v_estado   ge_movimientos.estado%type := 'P';
v_cod_tra_padre ge_movimientos.cod_transaccion%type := 186;
v_obser         ta_cobros.observacion%type;
v_nro_secuencia ge_movimientos.nro_secuencia%type;
v_fcdehoy       date :=pag_cal.fu_obt_fec_actual(5);
r_gmovi         ge_movimientos%rowtype;
 --- Datos para utilizar la cuenta de débito
v_mto_deu_deb    ge_cuentas.sal_contable%type;
v_mto_deu        ge_cuentas.sal_contable%type;
v_cot_mon_tar    ge_cotizaciones.val_conversion%type;
v_cot_mon_deb    ge_cotizaciones.val_conversion%type;
v_nvo_estado     ge_cuentas.estado%type;
v_sal_disponible ge_cuentas.sal_contable%type;
v_procesa        varchar2(01);
v_nro_cta_atraso ge_cuentas.nro_cuenta%type;
v_cod_usu_origen ge_movimientos.cod_usuario%type;
v_cod_tra_aguinaldo  ge_transacciones.cod_transaccion%type;
v_mto_aguinaldo      number := 0;
v_tot_aguinaldo      number := 0;
v_fec_ini_mes        date;
v_cod_ente           ah_cta_vistas.cod_ente%type := null;
v_dia_aguinaldo      ge_par_dinamicos.val_parametro%type;
v_fec_aguinaldo      date;
v_blo_sal_agui       varchar2(1) := nvl(fug_obt_pardinamico('BLO_DEB_SAL_AGUINALDO'),'N');
v_observacion   ta_cobros.observacion%type;
   CURSOR c_cta_atrasos IS
      select t.cod_persona, t.nro_cuenta, t.nro_cta_credito,t.cod_modulo, c.cod_modalidad, t.cod_usu_origen,tc.tot_cobrado
        from ge_cli_cta_atrasos t,ge_cta_dat_adicionales a,ge_cuentas c,ge_par_dinamicos d,
            (select t.nro_cuenta,nvl(sum(t.monto), 0) tot_cobrado
               from ta_cobros t
              where  t.fec_proceso = v_fcdehoy
                and t.estado <> 'E'
                --and t.est_envio = 'E' --se comenta por los dobles debitos
                group by t.nro_cuenta) tc
       where t.tie_deposito = 'S'
         and t.cod_modulo = 5
         and t.nro_cta_credito = p_cta_debito
         and t.cod_persona = p_cod_persona
         and t.nro_cuenta = a.nro_cuenta(+)
         and a.parametro(+) = 'EXC_COB_24X7'
         and nvl(a.val_parametro,'N') = 'N'
         and t.nro_cta_credito = c.nro_cuenta
         --and nvl(c.cod_sub_modalidad,999) <> 6--Excluye Ctas. Aguinaldo --NVB-2176 se comento la sub_modalidad
         and t.cod_modulo = d.cod_modulo
         and d.parametro = 'MOD_COB_24X7'
         and d.val_parametro = 'S'
         and t.mto_mora > nvl(t.tot_cobrado,0) -- No cobrar doble
         and t.procesado = 'N' --Procesar solo una vez
         and t.nro_cuenta = tc.nro_cuenta(+)
         and t.mto_mora > tc.tot_cobrado(+)
       order by t.dia_atraso desc;

PROCEDURE pr_ins_log_error(p_nro_cuenta   tm_log_nominas.nro_cuenta%type,
                          p_monto        tm_log_nominas.monto%type,
                          p_sal_total    tm_log_nominas.sal_total%type,
                          p_lugar        tm_log_nominas.lugar%type,
                          p_observacion  tm_log_nominas.observacion%type)
is
pragma autonomous_transaction;
begin
  insert into tm_log_nominas
  (nro_cuenta, monto, sal_total, lugar, observacion, fec_insercion)
  values
  (p_nro_cuenta, p_monto, p_sal_total, p_lugar, p_observacion, sysdate);
   Begin 
      update ge_cli_cta_atrasos a
         set a.procesado = 'E'
       where a.cod_persona = p_cod_persona
         and a.nro_cuenta = v_nro_cta_atraso
         and a.nro_cta_credito = p_cta_debito
         and a.procesado <> 'S'
         and a.fec_mov_deb24x7 is null
         and a.hor_mov_deb24x7 is null
         and a.cod_usu_deb24x7 is null
         and a.cod_tra_pad_deb24x7 is null;
   EXCEPTION
      WHEN OTHERS THEN
        null;
   End; 
  commit; -- este commit solo afecta a la transaccion autonoma
end ;

function lf_obt_mto_aguinaldo(p_nro_cta varchar2) return number is
begin
    select sum(a.MONTO)
      into v_mto_aguinaldo
      from gv_movimientos a
     where a.FECHA >= v_fec_ini_mes
       and a.fecha <= v_fcdehoy
       and a.COD_TRA_PADRE = v_cod_tra_aguinaldo
       and a.COD_TRANSACCION = 602
       and a.NRO_CUENTA = p_nro_cta
       and a.REVERSADO = 'N';
    return nvl(v_mto_aguinaldo,0);
  exception
    when no_data_found then
      return 0;
    when others then
      return 0;
end;

function lf_obt_fec_aguinaldo(p_nro_cta varchar2) return date is
    v_fec_aguinaldo date;
begin
    select max(a.fecha)
      into v_fec_aguinaldo
      from gv_movimientos a
     where a.FECHA >= v_fec_ini_mes
       and a.fecha <= v_fcdehoy
       and a.COD_TRA_PADRE = v_cod_tra_aguinaldo
       and a.COD_TRANSACCION = 602
       and a.NRO_CUENTA = p_nro_cta
       and a.REVERSADO = 'N';
    return v_fec_aguinaldo;
  exception
    when no_data_found then
      return null;
    when others then
      return null;
end;
  
Begin
   FOR cta IN c_cta_atrasos LOOP
     if cta.cod_modulo = '5' and cta.cod_modalidad <> '53' then
       v_nro_cta_atraso := cta.nro_cuenta;
       v_cod_usu_origen := cta.cod_usu_origen;
       --v_fcdehoy       := pag_cal.fu_obt_fec_actual(5);
       v_hora          := to_char(sysdate,'HH24:MI:SS');
       v_hora := fug_obt_hor_disponible(v_fcdehoy,v_hora,v_cod_usu_origen/*user*/,'N');
       IF v_hora = v_hor_actual THEN
          v_hora    := pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);
       END IF;
       v_nro_secuencia := 0;
       v_dia_aguinaldo  := nvl(fug_obt_pardinamico('CAN_DIA_DEB_AGUINALDO'),0);
        /*Obtiene datos de la Cta. Tarjeta*/
        begin
          select nvl(ct.mto_mora, 0),nvl(ct.dia_mora,0),ct.cod_moneda,
                 ct.cod_modulo,ct.cod_modalidad,ct.cod_oficina,ta.nro_tarjeta
            into v_mto_mora,v_dia_mora,v_cod_moneda,
                 v_cod_modulo,v_cod_modalidad,v_cod_oficina,v_nro_tarjeta
            from ta_cta_tarjetas ct,ta_tarjetas ta
           where ct.nro_cuenta = v_nro_cta_atraso--p_nro_cuenta
             and ct.nro_cuenta = ta.nro_cuenta
             and ta.cod_persona = p_cod_persona
             and ta.vigente = 'S'
             and ta.fec_vencimiento = (select max(tj.fec_vencimiento)
                                         from ta_tarjetas tj
                                        where tj.nro_cuenta  = v_nro_cta_atraso
                                          and tj.cod_persona = p_cod_persona
                                          and tj.vigente = 'S');
        exception
          when no_data_found then
            /*SI NO TIENE TARJETA VIGENTE BUSCA UNA DE LAS TARJETAS CON VTO. MAS ALTO*/
            select nvl(ct.mto_mora, 0),nvl(ct.dia_mora,0),ct.cod_moneda,
                 ct.cod_modulo,ct.cod_modalidad,ct.cod_oficina,ta.nro_tarjeta
            into v_mto_mora,v_dia_mora,v_cod_moneda,
                 v_cod_modulo,v_cod_modalidad,v_cod_oficina,v_nro_tarjeta
            from ta_cta_tarjetas ct,ta_tarjetas ta
           where ct.nro_cuenta = v_nro_cta_atraso--p_nro_cuenta
             and ct.nro_cuenta = ta.nro_cuenta
             and ta.cod_persona = p_cod_persona
            -- and ta.vigente = 'S'
             and ta.fec_vencimiento = (select max(tj.fec_vencimiento)
                                         from ta_tarjetas tj
                                        where tj.nro_cuenta  = v_nro_cta_atraso
                                          and tj.cod_persona = p_cod_persona
                                          /*and tj.vigente = 'S'*/)                            
            and rownum = 1
            order by ta.fec_vencimiento desc;
          when others then
            v_mto_mora := 0;
            v_dia_mora := 0;
        end;
       -- v_hora  := pag_gen.fu_obt_sig_segundo(v_hora);
            ----- Recuperar datos de la cuenta, de la que va a debitar
            pag_cta.pr_obt_cuenta(p_cta_debito);
            if pag_cta.g_cod_error <> 0 then
              v_estado    := 'E';
              v_obser := fug_obt_err_sueldos(pag_cta.g_cod_error);
            end if;
            -- Validar si es que tiene transacción prohibida.
            if v_estado = 'P' then
               If pag_cta.FU_VER_TRA_PROHIBIDA(v_nro_cta_atraso/*p_nro_cuenta*/, v_cod_tra_padre) = 'S' then
                  v_estado := 'E';
                  v_obser  := 'Cuenta de Tarjeta con Transaccion Prohibida';
               End if;
            end if;
            /**************************************************************************/
            -- Calculo el total a debitar en la moneda de la cuenta de debito
            v_cot_mon_tar := null;
            v_cot_mon_deb := null;
            v_mto_deu_deb := 0;
            v_mto_deu     := v_mto_mora - nvl(cta.tot_cobrado,0);
            --
            v_mto_deu_deb := v_mto_deu;
            --
            v_cod_ente       := null;
            begin
              select a.cod_ente
                into v_cod_ente
                from ah_cta_vistas a
               where a.nro_cuenta = cta.nro_cta_credito;
            exception
              when no_data_found then
                v_cod_ente := null;
              when others then
                v_cod_ente := null;
            end;
            if v_cod_ente is not null and nvl(v_blo_sal_agui,'N') = 'S' then
              v_cod_tra_aguinaldo := fug_obt_parentes(v_cod_ente, 'COD_TRA_PAD_AGUINALDO');
              pag_cal.PR_OBT_DAT_CALENDAR(1);
              v_fec_ini_mes := pag_cal.G_PRI_DIA_MES;
              v_tot_aguinaldo := lf_obt_mto_aguinaldo(cta.nro_cta_credito);
              v_fec_aguinaldo := lf_obt_fec_aguinaldo(cta.nro_cta_credito);
            end if;
            --
            If v_cod_moneda != pag_cta.g_ctas.cod_moneda then
              If fug_obt_tip_implementacion in (1,7) then
                  v_estado    := 'E';
                  v_obser := 'Cobro en diferentes monedas no permitido';
              Else
                  pag_gen.pr_con_mon_a_moneda(v_cod_moneda, pag_cta.g_ctas.cod_moneda,
                                              v_mto_deu, v_mto_deu_deb,
                                              v_cot_mon_tar, v_cot_mon_deb);
              End if;
            End if;
            if nvl(pag_cta.g_ctas.sal_disponible,0) < nvl(v_mto_deu_deb,0) and
               nvl(pag_cta.g_ctas.sal_disponible,0) > 0 then
               v_mto_deu_deb := nvl(pag_cta.g_ctas.sal_disponible,0);
               If v_cod_moneda != pag_cta.g_ctas.cod_moneda then
                 --
                 v_cot_mon_tar := null;
                 v_cot_mon_deb := null;
                 pag_gen.pr_con_mon_a_moneda(pag_cta.g_ctas.cod_moneda, v_cod_moneda,
                                          v_mto_deu_deb, v_mto_deu,
                                          v_cot_mon_deb, v_cot_mon_tar);
               else
                  v_mto_deu := v_mto_deu_deb;
               End if;
            end if;
            if nvl(v_blo_sal_agui,'N') = 'S' then 
              if v_cod_ente is not null and ((v_fcdehoy - v_fec_aguinaldo) <= v_dia_aguinaldo) then
                  if nvl(pag_cta.g_ctas.sal_disponible,0) - nvl(v_tot_aguinaldo,0) > 0 then
                    if nvl(pag_cta.g_ctas.sal_disponible,0) - nvl(v_tot_aguinaldo,0) < (nvl(v_mto_deu_deb,0)) then
                      v_mto_deu_deb := nvl(pag_cta.g_ctas.sal_disponible,0) - nvl(v_tot_aguinaldo,0);
                      v_mto_deu     := v_mto_deu_deb;
                    end if;
                  else
                    v_estado := 'E';
                    v_obser  := 'Saldo no cubre la deuda.';
                  end if;
              end if;
            end if;
            if v_estado = 'P' then
              --- Verificar si puede realizarse la operación sobre la cuenta de débito
              pag_cta.pr_ver_operacion(p_cta_debito, v_cod_tra_padre, v_cod_modulo, v_cod_modalidad,
                                     'D', pag_cta.g_ctas.cod_moneda, v_mto_deu_deb, v_cod_oficina,
                                     -- out
                                     pag_cta.g_ctas.cod_modulo, pag_cta.g_ctas.cod_modalidad,
                                     v_nvo_estado, v_sal_disponible, v_procesa);
              if pag_cta.g_cod_error <> 0 or v_procesa = 'N' then
                v_estado:= 'E';
                v_obser := fug_obt_err_sueldos(pag_cta.g_cod_error);
              end if;
              if v_estado = 'P' then
                 v_nro_secuencia := v_nro_secuencia + 1;
                 pag_cta.pr_set_variables(v_cod_usu_origen, v_fcdehoy,
                                                v_cod_tra_padre,
                                                'N',--estado mvto
                                                'N',--reversado
                                                v_nro_secuencia,
                                                'N', -- estado pasa a N
                                                v_cod_oficina,
                                                v_cod_modulo,
                                                v_cod_modalidad);
                --- DEBITAR de la cuenta
                pag_cta.pr_act_operacion(p_cta_debito, v_hora, 'D', pag_cta.g_ctas.cod_moneda,
                                         v_mto_deu_deb, v_cod_tra_padre, 503,v_nro_cta_atraso /*p_nro_cuenta*/, null,
                                         v_cod_oficina, v_cod_modulo, v_cod_modalidad,
                                         null, null, ('Debito automatico de tarjetas 24X7 '||v_nro_cta_atraso/*p_nro_cuenta*/),
                                         'S', v_nro_secuencia , v_fcdehoy);
                if pag_cta.g_cod_error <> 0 then
                  v_estado:= 'E';
                  v_obser := fug_obt_err_sueldos(pag_cta.g_cod_error);
                end if;
              End if;
            End if;
            if v_estado = 'P' then
              --Genera el movimiento por el credito
              r_gmovi.cod_usuario     := v_cod_usu_origen;--user;
              r_gmovi.hora            := v_hora;
              r_gmovi.fecha           := v_fcdehoy;
              -- Aumento la secuencia
              v_nro_secuencia := v_nro_secuencia + 1;
              r_gmovi.nro_secuencia   := v_nro_secuencia;
              r_gmovi.cod_modulo      := v_cod_modulo;
              r_gmovi.cod_modalidad   := v_cod_modalidad;
              r_gmovi.cod_oficina     := v_cod_oficina;
              r_gmovi.cod_moneda      := v_cod_moneda;
              r_gmovi.fec_valor       := v_fcdehoy;
              r_gmovi.cod_tra_padre   := v_cod_tra_padre;
              r_gmovi.cod_mod_padre   := v_cod_modulo;--5;
              r_gmovi.cod_mad_padre   := v_cod_modalidad;-- 51;
              r_gmovi.cod_transaccion := 978;
              r_gmovi.monto           := v_mto_deu;
              r_gmovi.nro_documento   := v_nro_cta_atraso/*p_nro_cuenta*/;
              r_gmovi.nro_cuenta      := v_nro_cta_atraso/*p_nro_cuenta*/;
              r_gmovi.cod_ofi_origen  := v_cod_oficina;
              r_gmovi.emi_aviso       := 'N';
              r_gmovi.concepto        := 'Crédito de tarjetas Cobrador 24x7';
              r_gmovi.estado          := 'N';
              r_gmovi.reversado       := 'N';
              PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi);
              --Acá debe insertar en ta_cobros
                pat_val.G_PROCESO := 'PRT_DEB_AUTOMATICO_24X7';
                insert into ta_cobros
                    (nro_cuenta, nro_tarjeta, nro_cta_debito, fec_proceso, monto, estado, fec_valor, observacion,
                     hora, cod_usuario, dia_mora, est_envio)
                   values
                    (v_nro_cta_atraso/*p_nro_cuenta*/, v_nro_tarjeta, p_cta_debito, v_fcdehoy, v_mto_deu, v_estado, v_fcdehoy, 'Registro Procesado PRT_DEB_AUTOMATICO_24x7',
                     v_hora,v_cod_usu_origen/* user*/, v_dia_mora,
                     'P');
               --Acá actualiza tabla atrasos
               Begin
                 update ge_cli_cta_atrasos a
                   set a.procesado = 'S',
                       a.tot_cobrado = nvl(a.tot_cobrado,0) + nvl(v_mto_deu,0),
                       a.fec_mov_deb24x7 = v_fcdehoy,
                       a.hor_mov_deb24x7 = v_hora,
                       a.cod_usu_deb24x7 = v_cod_usu_origen,--user,
                       a.cod_tra_pad_deb24x7 = v_cod_tra_padre
                   where a.cod_persona = p_cod_persona
                     and a.nro_cuenta = v_nro_cta_atraso/*p_nro_cuenta*/
                     and a.nro_cta_credito = p_cta_debito;
               EXCEPTION
               WHEN OTHERS THEN
                 null;
               End;
            end if;
           IF pag_cta.g_cod_error <> 0 THEN
               pr_ins_log_error(v_nro_cta_atraso,
                                v_mto_deu,
                                0,
                                'PRT_DEB_AUTOMATICO_24x7 1',
                                substr(pag_cta.FU_OBT_MSJ_ERROR, 1, 299));
               --- Siguiente registro
               GOTO siguiente_registro;
               <<siguiente_registro>> NULL;
           END IF;
      elsif cta.cod_modulo = '5' and cta.cod_modalidad = '53' then-- GP
          v_nro_cta_atraso := cta.nro_cuenta;
          v_cod_usu_origen := cta.cod_usu_origen;
          v_hora          := to_char(sysdate,'HH24:MI:SS');
          v_hora := fug_obt_hor_disponible(v_fcdehoy,v_hora,v_cod_usu_origen/*user*/,'N');
          IF v_hora = v_hor_actual THEN
             v_hora    := pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);
          END IF;
           v_nro_secuencia := 0;
           v_dia_aguinaldo  := nvl(fug_obt_pardinamico('CAN_DIA_DEB_AGUINALDO'),0);
        /*Obtiene datos de la Cta. Tarjeta*/
        begin
          select nvl(ct.mto_mora, 0),nvl(ct.dia_mora,0),ct.cod_moneda,
                 ct.cod_modulo,ct.cod_modalidad,ct.cod_oficina,ta.nro_tarjeta
            into v_mto_mora,v_dia_mora,v_cod_moneda,
                 v_cod_modulo,v_cod_modalidad,v_cod_oficina,v_nro_tarjeta
            from ta_cta_tarjetas ct,ta_tarjetas ta
           where ct.nro_cuenta = v_nro_cta_atraso--p_nro_cuenta
             and ct.nro_cuenta = ta.nro_cuenta
             and ta.cod_persona = p_cod_persona
             and ta.vigente = 'S'
             and ta.fec_vencimiento = (select max(tj.fec_vencimiento)
                                         from ta_tarjetas tj
                                        where tj.nro_cuenta  = v_nro_cta_atraso
                                          and tj.cod_persona = p_cod_persona
                                          and tj.vigente = 'S');
        exception
          when no_data_found then
            /*SI NO TIENE TARJETA VIGENTE BUSCA UNA DE LAS TARJETAS CON VTO. MAS ALTO*/
            select nvl(ct.mto_mora, 0),nvl(ct.dia_mora,0),ct.cod_moneda,
                 ct.cod_modulo,ct.cod_modalidad,ct.cod_oficina,ta.nro_tarjeta
            into v_mto_mora,v_dia_mora,v_cod_moneda,
                 v_cod_modulo,v_cod_modalidad,v_cod_oficina,v_nro_tarjeta
            from ta_cta_tarjetas ct,ta_tarjetas ta
           where ct.nro_cuenta = v_nro_cta_atraso--p_nro_cuenta
             and ct.nro_cuenta = ta.nro_cuenta
             and ta.cod_persona = p_cod_persona
            -- and ta.vigente = 'S'
             and ta.fec_vencimiento = (select max(tj.fec_vencimiento)
                                         from ta_tarjetas tj
                                        where tj.nro_cuenta  = v_nro_cta_atraso
                                          and tj.cod_persona = p_cod_persona
                                          /*and tj.vigente = 'S'*/)                            
            and rownum = 1
            order by ta.fec_vencimiento desc;
          when others then
            v_mto_mora := 0;
            v_dia_mora := 0;
        end;
        pag_cta.pr_obt_cuenta(p_cta_debito);
            if pag_cta.g_cod_error <> 0 then
              v_estado    := 'E';
              v_obser := fug_obt_err_sueldos(pag_cta.g_cod_error);
            end if;
            -- Validar si es que tiene transacción prohibida.
            if v_estado = 'P' then
               If pag_cta.FU_VER_TRA_PROHIBIDA(v_nro_cta_atraso/*p_nro_cuenta*/, v_cod_tra_padre) = 'S' then
                  v_estado := 'E';
                  v_obser  := 'Cuenta de Tarjeta con Transaccion Prohibida';
               End if;
            end if;
            /**************************************************************************/
            -- Calculo el total a debitar en la moneda de la cuenta de debito
            v_cot_mon_tar := null;
            v_cot_mon_deb := null;
            v_mto_deu_deb := 0;
            v_mto_deu     := v_mto_mora - nvl(cta.tot_cobrado,0);
            --
            v_mto_deu_deb := v_mto_deu;
            --
            v_cod_ente       := null;
            begin
              select a.cod_ente
                into v_cod_ente
                from ah_cta_vistas a
               where a.nro_cuenta = cta.nro_cta_credito;
            exception
              when no_data_found then
                v_cod_ente := null;
              when others then
                v_cod_ente := null;
            end;
            if v_cod_ente is not null and nvl(v_blo_sal_agui,'N') = 'S' then
              v_cod_tra_aguinaldo := fug_obt_parentes(v_cod_ente, 'COD_TRA_PAD_AGUINALDO');
              pag_cal.PR_OBT_DAT_CALENDAR(1);
              v_fec_ini_mes := pag_cal.G_PRI_DIA_MES;
              v_tot_aguinaldo := lf_obt_mto_aguinaldo(cta.nro_cta_credito);
              v_fec_aguinaldo := lf_obt_fec_aguinaldo(cta.nro_cta_credito);
            end if;
            --
            If v_cod_moneda != pag_cta.g_ctas.cod_moneda then
              If fug_obt_tip_implementacion in (1,7) then
                  v_estado    := 'E';
                  v_obser := 'Cobro en diferentes monedas no permitido';
              Else
                  pag_gen.pr_con_mon_a_moneda(v_cod_moneda, pag_cta.g_ctas.cod_moneda,
                                              v_mto_deu, v_mto_deu_deb,
                                              v_cot_mon_tar, v_cot_mon_deb);
              End if;
            End if;
            if nvl(pag_cta.g_ctas.sal_disponible,0) < nvl(v_mto_deu_deb,0) and
               nvl(pag_cta.g_ctas.sal_disponible,0) > 0 then
               v_mto_deu_deb := nvl(pag_cta.g_ctas.sal_disponible,0);
               If v_cod_moneda != pag_cta.g_ctas.cod_moneda then
                 --
                 v_cot_mon_tar := null;
                 v_cot_mon_deb := null;
                 pag_gen.pr_con_mon_a_moneda(pag_cta.g_ctas.cod_moneda, v_cod_moneda,
                                          v_mto_deu_deb, v_mto_deu,
                                          v_cot_mon_deb, v_cot_mon_tar);
               else
                  v_mto_deu := v_mto_deu_deb;
               End if;
            end if;
            if nvl(v_blo_sal_agui,'N') = 'S' then 
              if v_cod_ente is not null and ((v_fcdehoy - v_fec_aguinaldo) <= v_dia_aguinaldo) then
                  if nvl(pag_cta.g_ctas.sal_disponible,0) - nvl(v_tot_aguinaldo,0) > 0 then
                    if nvl(pag_cta.g_ctas.sal_disponible,0) - nvl(v_tot_aguinaldo,0) < (nvl(v_mto_deu_deb,0)) then
                      v_mto_deu_deb := nvl(pag_cta.g_ctas.sal_disponible,0) - nvl(v_tot_aguinaldo,0);
                      v_mto_deu     := v_mto_deu_deb;
                    end if;
                  else
                    v_estado := 'E';
                    v_obser  := 'Saldo no cubre la deuda.';
                  end if;
              end if;
            end if;
            if v_estado = 'P' then
              --- Verificar si puede realizarse la operación sobre la cuenta de débito
              pag_cta.pr_ver_operacion(p_cta_debito, v_cod_tra_padre, v_cod_modulo, v_cod_modalidad,
                                     'D', pag_cta.g_ctas.cod_moneda, v_mto_deu_deb, v_cod_oficina,
                                     -- out
                                     pag_cta.g_ctas.cod_modulo, pag_cta.g_ctas.cod_modalidad,
                                     v_nvo_estado, v_sal_disponible, v_procesa);
              if pag_cta.g_cod_error <> 0 or v_procesa = 'N' then
                v_estado:= 'E';
                v_obser := fug_obt_err_sueldos(pag_cta.g_cod_error);
              end if;
              if v_estado = 'P' then
                 v_nro_secuencia := v_nro_secuencia + 1;
                 pag_cta.pr_set_variables(v_cod_usu_origen, v_fcdehoy,
                                                v_cod_tra_padre,
                                                'N',--estado mvto
                                                'N',--reversado
                                                v_nro_secuencia,
                                                'N', -- estado pasa a N
                                                v_cod_oficina,
                                                v_cod_modulo,
                                                v_cod_modalidad);
                --- DEBITAR de la cuenta
                pag_cta.pr_act_operacion(p_cta_debito, v_hora, 'D', pag_cta.g_ctas.cod_moneda,
                                         v_mto_deu_deb, v_cod_tra_padre, 503,v_nro_cta_atraso /*p_nro_cuenta*/, null,
                                         v_cod_oficina, v_cod_modulo, v_cod_modalidad,
                                         null, null, ('Debito automatico de tarjetas 24X7 '||v_nro_cta_atraso/*p_nro_cuenta*/),
                                         'S', v_nro_secuencia , v_fcdehoy);
                if pag_cta.g_cod_error <> 0 then
                  v_estado:= 'E';
                  v_obser := fug_obt_err_sueldos(pag_cta.g_cod_error);
                end if;
              End if;
            End if;
            if v_estado = 'P' then
              --Genera el movimiento por el credito
              r_gmovi.cod_usuario     := v_cod_usu_origen;--user;
              r_gmovi.hora            := v_hora;
              r_gmovi.fecha           := v_fcdehoy;
              -- Aumento la secuencia
              v_nro_secuencia := v_nro_secuencia + 1;
              r_gmovi.nro_secuencia   := v_nro_secuencia;
              r_gmovi.cod_modulo      := v_cod_modulo;
              r_gmovi.cod_modalidad   := v_cod_modalidad;
              r_gmovi.cod_oficina     := v_cod_oficina;
              r_gmovi.cod_moneda      := v_cod_moneda;
              r_gmovi.fec_valor       := v_fcdehoy;
              r_gmovi.cod_tra_padre   := v_cod_tra_padre;
              r_gmovi.cod_mod_padre   := v_cod_modulo;--5;
              r_gmovi.cod_mad_padre   := v_cod_modalidad;-- 51;
              r_gmovi.cod_transaccion := 978;
              r_gmovi.monto           := v_mto_deu;
              r_gmovi.nro_documento   := v_nro_cta_atraso;
              r_gmovi.nro_cuenta      := v_nro_cta_atraso;
              r_gmovi.cod_ofi_origen  := v_cod_oficina;
              r_gmovi.emi_aviso       := 'N';
              r_gmovi.concepto        := 'Crédito de tarjetas Cobrador 24x7';
              r_gmovi.estado          := 'N';
              r_gmovi.reversado       := 'N';
              PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi);
              --Acá debe insertar en ta_cobros
                pat_val.G_PROCESO := 'PRT_DEB_AUTOMATICO_24X7';
                insert into ta_cobros_gp
                    (nro_cuenta, nro_tarjeta, nro_cta_debito, fec_proceso, monto, estado, fec_valor, observacion,
                     hora, cod_usuario, dia_mora, est_envio)
                   values
                    (v_nro_cta_atraso, v_nro_tarjeta, p_cta_debito, v_fcdehoy, v_mto_deu, v_estado, v_fcdehoy, 'Registro Procesado PRT_DEB_AUTOMATICO_24x7',
                     v_hora,v_cod_usu_origen, v_dia_mora,
                     'P');
          
            -- p procesado por debito, c cobrado en caja e no procesado por error                   
            begin
              select estado, observacion
                into v_estado, v_observacion
                from ta_cobros_gp t
               where t.nro_cuenta = cta.nro_cta_credito--reg.nro_cta_mora --nro cuenta tarjeta mora
                 and t.nro_cta_debito = cta.nro_cuenta --nro de cuenta caja ahorrro
                 and t.fec_proceso = pag_cal.fu_obt_fec_actual(5)
                 and trunc(t.fec_insercion) =
                     (select max(trunc(fec_insercion))
                        from ta_cobros_gp tt
                       where t.nro_cuenta = tt.nro_cuenta
                         and t.nro_cta_debito = tt.nro_cta_debito
                         and t.fec_proceso = pag_cal.fu_obt_fec_actual(5));
            exception
              when no_data_found then
                v_estado := 'E';
              when others then
                v_estado := 'E';
            end;
          
            --Acá actualiza tabla atrasos
               Begin
                 update ge_cli_cta_atrasos a
                   set a.procesado = 'S',
                       a.tot_cobrado = nvl(a.tot_cobrado,0) + nvl(v_mto_deu,0),
                       a.fec_mov_deb24x7 = v_fcdehoy,
                       a.hor_mov_deb24x7 = v_hora,
                       a.cod_usu_deb24x7 = v_cod_usu_origen,--user,
                       a.cod_tra_pad_deb24x7 = v_cod_tra_padre
                   where a.cod_persona = p_cod_persona
                     and a.nro_cuenta = v_nro_cta_atraso/*p_nro_cuenta*/
                     and a.nro_cta_credito = p_cta_debito;
               EXCEPTION
               WHEN OTHERS THEN
                 null;
               End;   
            end if;
              IF pag_cta.g_cod_error <> 0 THEN
                 pr_ins_log_error(v_nro_cta_atraso,
                                  v_mto_deu,
                                  0,
                                  'PRT_DEB_AUTOMATICO_24x7 1',
                                  substr(pag_cta.FU_OBT_MSJ_ERROR, 1, 299));
              END IF;
            --commit;
      end if;
   End Loop;
 EXCEPTION
     WHEN OTHERS THEN
       pr_ins_log_error(v_nro_cta_atraso,
                        v_mto_deu,
                        0,
                        'PRT_DEB_AUTOMATICO_24x7 2',
                        substr(SQLERRM, 1, 299));
End;
/

