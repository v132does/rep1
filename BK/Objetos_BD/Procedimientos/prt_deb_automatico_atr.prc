CREATE OR REPLACE PROCEDURE IT.PRT_DEB_AUTOMATICO_ATR
 (P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE DEFAULT NULL,
  P_NRO_CTA_DEBITO IN TA_CTA_TARJETAS.NRO_CUENTA%TYPE DEFAULT NULL,
  P_COD_ENTE IN NUMBER DEFAULT NULL,
  P_NRO_SECUENCIA IN NUMBER DEFAULT NULL,
  P_FECHA IN DATE DEFAULT NULL
 )
 IS
  ---v_pago_sueldo   varchar2(1) := 'N';
  v_rol_referencia varchar2(100);
  v_estado        ge_movimientos.estado%type;
  v_est_envio     ta_cobros.est_envio%type; --DYDMR-3085 se agrega variable de actualización GC 24/02/2016
  v_obser         ta_cobros.observacion%type;
  v_hora          ge_movimientos.hora%type;
  v_fcdehoy       date;
  v_fec_anterior  date;
  v_fec_proxima   date;
  v_nro_cta_ant   ta_cobros.nro_cuenta%TYPE;
  v_commitea       varchar2(1) := 'N';
  v_nro_secuencia ge_movimientos.nro_secuencia%type;
  v_cod_tra_padre ge_movimientos.cod_transaccion%type := 986;
  r_gmovi         ge_movimientos%rowtype;
  rg_ot           ta_cobros%rowtype;
  v_lugar         varchar2(1000);

  --- Datos para utilizar la cuenta de débito
  v_cot_mon_tar    ge_cotizaciones.val_conversion%type;
  v_cot_mon_deb    ge_cotizaciones.val_conversion%type;
  v_nvo_estado     ge_cuentas.estado%type;
  v_sal_disponible ge_cuentas.sal_contable%type;
  v_cod_usuario    ba_usuarios.cod_usuario%type;
  v_lin_sobregiro  number;
  v_procesa        varchar2(01);
  v_cod_tra_aguinaldo  ge_transacciones.cod_transaccion%type;
  v_mto_aguinaldo      number := 0;
  v_tot_aguinaldo      number := 0;
  v_fec_ini_mes        date;
  v_cod_ente           ah_cta_vistas.cod_ente%type := null;
  v_dia_aguinaldo      ge_par_dinamicos.val_parametro%type;
  v_fec_aguinaldo      date;
  v_blo_sal_agui       varchar2(1) := nvl(fug_obt_pardinamico('BLO_DEB_SAL_AGUINALDO'),'N');
  --RI: 15/12/2010: Parametro creado para determinar si se procesa cuenta de nomina
  v_cod_usu_hb       varchar2(30):=fug_obt_pardinamico('COD_USU_HOMEBANKING');
  v_est_modulo ba_modulos.estado%type := 2; -- Modulo Abierto DYDMR-5283 NAF. Nov/2016
  v_horario     varchar2(1)  := 'D'; -- Dia normal DYDMR-5283 NAF. Nov/2016
  v_es_nocturno varchar2(1) := 'N'; -- No es Nocturno DYDMR-5283 NAF. Nov/2016
  v_est_cob_aux varchar2(1);
  v_tie_deu_pen varchar2(1);

  --Proceso de debitos automaticos
  procedure lp_pro_debitos;

  --Proceso de debitos automaticos por Ente--
  procedure lp_pro_deb_ente;

  --Proceso de verificación de ejecución del proceso a nivel de ge_proceso
  procedure lp_ver_proceso;
  --Proceso de verificación de ejecución del proceso a nivel de sessiones
  procedure lp_ver_sesion;

  procedure lp_ins_reg_cobro(RG_OT IN ta_cobros%ROWTYPE);

  procedure lp_ins_reg_cobro(RG_OT IN ta_cobros%ROWTYPE) IS
    /*Inserta ta_cobros para los debitos exitosos de cuentas relacionadas*/
    BEGIN
      pat_val.G_PROCESO := 'PRT_DEB_AUTOMATICO_ATR';
      INSERT INTO TA_COBROS
        (nro_cuenta,
         nro_tarjeta,
         nro_cta_debito,
         fec_proceso,
         monto,
         estado,
         fec_valor,
         observacion,
         est_envio,
         hora,
         cod_usuario,
         dia_mora)
      VALUES
        (rg_ot.nro_cuenta,
         rg_ot.nro_tarjeta,
         rg_ot.nro_cta_debito,
         pag_cal.fu_obt_fec_actual(5),
         rg_ot.monto,
         'P',
         pag_cal.fu_obt_fec_actual(5),
         'Registro procesado prt_deb_automatico ATR',
         'P',
         v_hora,
         user,
         rg_ot.dia_mora);
    END;
    
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
  --Procesando Debitos Automaticos--
  procedure lp_pro_debitos is
    v_dia_atr_deb_aut number(6);

    --Cursor Principal de Cuentas--
    cursor op_cursor IS
      select cob.nro_cta_debito, cob.nro_tarjeta, cob.monto, cob.cod_modulo,
             cob.cod_moneda, cob.cod_modalidad, cob.nro_cuenta, cob.cod_oficina,
             cob.dia_mora, cob.rowid reg_cuenta, cob.cod_persona,
             nvl(x.mto_cobrado,0) mto_cobrado, nvl(x.can_pagos,0) can_pagos
        from TA_CTA_DEB_AUT_COBRAR cob,
              ba_personas p,
        (select x.nro_cuenta,
                sum(nvl(x.monto,0)) mto_cobrado,
                count(*) can_pagos
           from ta_cobros x
          where x.fec_proceso between v_fec_anterior and v_fec_proxima
            and x.estado in ('P','C')
          group by x.nro_cuenta) x
       where ((cob.nro_cta_debito = p_nro_cta_debito) or (p_nro_cta_debito is null))
         and cob.cod_persona = nvl(p_cod_persona, cob.cod_persona)
         and cob.fec_proceso = v_fcdehoy
         and cob.cod_persona = p.cod_persona
         and cob.estado in ('I','F')  --I-Insertado, F-Pagado una fraccion--
         and cob.dia_mora >= v_dia_atr_deb_aut
         and x.nro_cuenta(+) = cob.nro_cuenta
         and cob.referencia in ('02_PRO_MOROSO','03_PRO_ATRASADO')
         and p.tipo = 'J' --Solo PJ
         and not exists (select 1                                 --DYDMR-12533
                           from ge_cta_dat_adicionales da
                          where da.nro_cuenta = cob.nro_cuenta
                            and da.parametro = 'EXC_CTA_COB_AUTOMATICO'
                            and nvl(da.val_parametro, 'N') = 'S')
       order by 1;

    --Cursor de Cuentas Relacionadas--
    rg op_cursor%rowtype;
    Cursor cta_relacionadas(p_cod_persona_rel In ge_clientes.cod_persona%Type,
                            p_cta_debito  In ge_cuentas.nro_cuenta%Type) Is
    select z.nro_cta_debito nro_cuenta,
           z.cod_persona,
           z.relacion,
           z.cod_moneda,
           DECODE(z.COD_MODULO, 3, (B.SAL_TOTAL - (B.SAL_BLOQUEADO + B.SAL_RETENIDO)),
                                4, (C.SAL_TOTAL - (C.SAL_RETENIDO + C.SAL_BLOQUEADO))) sal_total,
           z.cod_modulo,
           z.cod_modalidad
      from TA_CTA_DEB_AUT_DETALLE z,  AH_CTA_VISTAS B, CC_CTA_CORRIENTES C
     where z.COD_PERSONA = P_COD_PERSONA_rel
       AND z.nro_cta_debito <> p_cta_debito
       AND z.nro_cta_debito = B.NRO_CUENTA(+)
       AND z.nro_cta_debito = C.NRO_CUENTA(+)
       AND nvl(c.cod_moneda, b.cod_moneda) = z.cod_moneda
       AND DECODE(z.COD_MODULO, 3,(B.SAL_TOTAL - (B.SAL_BLOQUEADO + B.SAL_RETENIDO)),
                                4,(C.SAL_TOTAL - (C.SAL_RETENIDO + C.SAL_BLOQUEADO))) > 0
       and not exists
       (select m.nro_cta_ahorro
          from cc_cta_combinadas m, ah_cta_vistas v
             where v.nro_cuenta = m.nro_cta_ahorro
               and m.nro_cta_cte = z.nro_cta_debito
               and v.SAL_TOTAL - (v.SAL_BLOQUEADO + v.SAL_RETENIDO) >
                   DECODE(z.COD_MODULO, 3, (B.SAL_TOTAL - (B.SAL_BLOQUEADO + B.SAL_RETENIDO)),
                                        4, (C.SAL_TOTAL - (C.SAL_RETENIDO + C.SAL_BLOQUEADO)))
            union all
            select m.nro_cta_cte
              from cc_cta_combinadas m, cc_cta_corrientes v
             where v.nro_cuenta = m.nro_cta_cte
               and m.nro_cta_ahorro = z.nro_cta_debito
               and v.SAL_TOTAL - (v.SAL_BLOQUEADO + v.SAL_RETENIDO) >
                   DECODE(z.COD_MODULO, 3, (B.SAL_TOTAL - (B.SAL_BLOQUEADO + B.SAL_RETENIDO)),
                                        4, (C.SAL_TOTAL - (C.SAL_RETENIDO + C.SAL_BLOQUEADO))))
    ORDER BY 5 DESC;

    --Variables Principales--
    V_COD_PERSONA BA_PERSONAS.COD_PERSONA%TYPE;
    v_mto_deu_deb    ge_cuentas.sal_contable%type;
    v_mto_deu        ge_cuentas.sal_contable%TYPE;
    v_mto_deu_res    ge_cuentas.sal_contable%TYPE := 0;
    v_mto_deu_mov    ge_cuentas.sal_contable%TYPE := 0;

  begin
     v_dia_atr_deb_aut := fug_obt_pardinamico('TAR_ATR_DEB_AUT_CUENTAS_REL');
     v_hora := to_char(SYSDATE, 'HH24:MI:SS');
     v_hora := fug_obt_hor_disponible(v_fcdehoy,v_hora,user,v_es_nocturno); -- DYDMR-5283 NAF. Nov/2016
     v_nro_cta_ant := 'x';
     if op_cursor%isopen then
        close op_cursor;
     end if;
      open op_cursor;
      --Ciclo de Cuentas de Tarjetas de Credito--
      loop
        fetch op_cursor into rg;
        exit when op_cursor%notfound;
          v_lugar := 'cuenta  : '||rg.nro_cuenta||' deb '||rg.nro_cta_debito;
          v_mto_deu     := rg.monto;
          v_mto_deu_res := rg.monto;
          v_mto_deu_deb := v_mto_deu;
          v_mto_deu_mov := 0;
          v_estado := 'E';
          --Validacion para actualizar estado del registro de la cuenta--
          if nvl(rg.mto_cobrado,0) >= nvl(rg.monto,0) then
             v_tie_deu_pen := 'N';
          else
             v_tie_deu_pen := 'S';
          end if;
          if v_tie_deu_pen = 'S' then
              -----------
             v_cod_persona := rg.cod_persona;
             v_mto_deu     := nvl(rg.monto,0) - nvl(rg.mto_cobrado,0);
             v_mto_deu_res := v_mto_deu;
             v_mto_deu_deb := v_mto_deu;
             --Ciblo de Cuentas Relacionadas--
             FOR i IN cta_relacionadas(v_cod_persona, nvl(rg.nro_cta_debito, rg.nro_cuenta)) LOOP
                v_rol_referencia := 'Cta. '||i.nro_cuenta||' Tar. '||rg.nro_tarjeta;
                prg_cre_savepoint(v_rol_referencia);
                v_commitea       := 'N';
                v_lugar := 'Tarjeta  : '||rg.nro_tarjeta;
                v_estado := 'P';
                v_est_envio := 'P';
                v_obser := 'Registro procesado prt_deb_automatico ATR';
                if v_nro_secuencia > 990 OR rg.nro_cuenta <> v_nro_cta_ant then
                   v_hora := fug_obt_hor_disponible(v_fcdehoy,v_hora,user,v_es_nocturno);
                   v_nro_secuencia := 0;
                   v_nro_cta_ant := rg.nro_cuenta;
                end if;
                ----- Recuperar datos de la cuenta, de la que va a debitar
                pag_cta.pr_obt_cuenta(i.nro_cuenta);
                if pag_cta.g_cod_error <> 0 then
                   v_estado    := 'E';
                   v_est_envio := null; --DYDMR-3085 GC 24/02/2016 PAGOS DUPLICADOS SE REGULARIZA EL CAMPO EST_ENVIO
                   v_obser := fug_obt_err_sueldos(pag_cta.g_cod_error);
                end if;
                -- Validar si es que tiene transacción prohibida.
                if v_estado = 'P' then
                   If pag_cta.FU_VER_TRA_PROHIBIDA(rg.nro_cuenta, v_cod_tra_padre) = 'S' then
                      v_estado := 'E';
                      v_est_envio := null; --DYDMR-3085 GC 24/02/2016 PAGOS DUPLICADOS SE REGULARIZA EL CAMPO EST_ENVIO
                      v_obser  := 'Cuenta de Tarjeta con Transaccion Prohibida';
                   End if;
                end if;
                --- Calculo el total a debitar en la moneda de la cuenta de debito
          v_cot_mon_tar := null;
          v_cot_mon_deb := null;
          --v_mto_deu_deb := 0;
          --
          --
          v_cod_ente       := null;
          begin
            select a.cod_ente
              into v_cod_ente
              from ah_cta_vistas a
             where a.nro_cuenta = i.nro_cuenta;
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
            v_tot_aguinaldo := lf_obt_mto_aguinaldo(i.nro_cuenta);
            v_fec_aguinaldo := lf_obt_fec_aguinaldo(i.nro_cuenta);
          end if;
          
          If rg.cod_moneda != pag_cta.g_ctas.cod_moneda then
            /* por ahora se anula esto para que no debite en moneda diferente */
            If fug_obt_tip_implementacion = 7 then
                v_estado    := 'E';
                v_est_envio := null; --DYDMR-3085 GC 24/02/2016 PAGOS DUPLICADOS SE REGULARIZA EL CAMPO EST_ENVIO
                v_obser := 'Cobro en diferentes monedas no permitido';
            Else
            /* Obtiene el monto en moneda Extranjera a Debitar */
                pag_gen.pr_con_mon_a_moneda(rg.cod_moneda, pag_cta.g_ctas.cod_moneda,
                                            v_mto_deu, v_mto_deu_deb,
                                            v_cot_mon_tar, v_cot_mon_deb);
            end if;
          End if;
          -- 16/09/2013 GC - DC 2776 Se descomenta desde la linea 220 a la 231.
          /* se comenta esto porque no fue pedido por el usuario, y no fue probado aún*/
          -- RI: 10/08/2010: se tiene en cuenta la linea de sobregiro
          v_lin_sobregiro := 0;
          if pag_cta.g_ctas.cod_modalidad = 41 then
             v_lin_sobregiro := nvl(pag_cta.FU_OBT_LIN_SOBREGIRO(i.nro_cuenta, v_fcdehoy),0);
          end if;

                if nvl(pag_cta.g_ctas.sal_disponible,0)+nvl(pag_cta.g_ctas.sal_dis_combinada,0)+v_lin_sobregiro
                    < nvl(v_mto_deu_deb,0) and
                     nvl(pag_cta.g_ctas.sal_disponible,0)+nvl(pag_cta.g_ctas.sal_dis_combinada,0)+v_lin_sobregiro > 0 THEN
                     v_mto_deu_deb := nvl(pag_cta.g_ctas.sal_disponible,0)+nvl(pag_cta.g_ctas.sal_dis_combinada,0)+v_lin_sobregiro;
                   --hasta aquí se comenta

                    /*if nvl(pag_cta.g_ctas.sal_disponible,0) < nvl(v_mto_deu_deb,0) and
                       nvl(pag_cta.g_ctas.sal_disponible,0) > 0 then
                       v_mto_deu_deb := nvl(pag_cta.g_ctas.sal_disponible,0);*/

                    If rg.cod_moneda != pag_cta.g_ctas.cod_moneda then
                       --
                       v_cot_mon_tar := null;
                       v_cot_mon_deb := null;
                    /* Obtiene el monto en moneda local a Debitar por el Saldo Disponible de la Cuenta en moneda Extranjera */
                       pag_gen.pr_con_mon_a_moneda(pag_cta.g_ctas.cod_moneda, rg.cod_moneda,
                                                v_mto_deu_deb, v_mto_deu,
                                                v_cot_mon_deb, v_cot_mon_tar);
                                                /*En este punto ya se el monto a debitar y puedo
                                                obtener el monto restante*/
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
                    BEGIN
                        pag_cta.pr_ver_operacion(i.nro_cuenta, v_cod_tra_padre, rg.cod_modulo, rg.cod_modalidad,
                                               'D', pag_cta.g_ctas.cod_moneda, v_mto_deu_deb, rg.cod_oficina,
                                               -- out
                                               pag_cta.g_ctas.cod_modulo, pag_cta.g_ctas.cod_modalidad,
                                               v_nvo_estado, v_sal_disponible, v_procesa);
                        if pag_cta.g_cod_error <> 0 or v_procesa = 'N' then
                          v_estado:= 'E';
                          v_est_envio := null; --DYDMR-3085 GC 24/02/2016 PAGOS DUPLICADOS SE REGULARIZA EL CAMPO EST_ENVIO
                          v_obser := substr(fug_obt_err_sueldos(pag_cta.g_cod_error),1,50);
                        end if;
                     EXCEPTION 
                         WHEN OTHERS THEN
                           v_estado:= 'E';
                           v_est_envio := null; --DYDMR-3085 GC 24/02/2016 PAGOS DUPLICADOS SE REGULARIZA EL CAMPO EST_ENVIO
                           v_obser := substr(sqlerrm,1,50);
                     END;
                       
                    if v_estado = 'P' then
                      --- DEBITAR de la cuenta
                      BEGIN
                          pag_cta.pr_act_operacion(i.nro_cuenta, v_hora, 'D', pag_cta.g_ctas.cod_moneda,
                                                   v_mto_deu_deb, v_cod_tra_padre, 503, rg.nro_cuenta, v_cot_mon_deb,
                                                   rg.cod_oficina, rg.cod_modulo, rg.cod_modalidad,
                                                   null, null, 'Debito automatico de Pagos Atrasados de Tarjetas ',
                                                   'S', v_nro_secuencia , v_fcdehoy, null,null,v_mto_deu);
                          IF pag_cta.g_cod_error <> 0 then
                            v_estado:= 'E';
                            v_est_envio := null; --DYDMR-3085 GC 24/02/2016 PAGOS DUPLICADOS SE REGULARIZA EL CAMPO EST_ENVIO
                            v_obser := substr(fug_obt_err_sueldos(pag_cta.g_cod_error),1,50);
                          ELSE
                            v_commitea := 'S';
                          end if;
                       EXCEPTION 
                         WHEN OTHERS THEN
                           v_estado:= 'E';
                           v_est_envio := null; --DYDMR-3085 GC 24/02/2016 PAGOS DUPLICADOS SE REGULARIZA EL CAMPO EST_ENVIO
                           v_obser := substr(sqlerrm,1,50);
                       END;
              
                      IF v_estado = 'P' THEN
                      /*Inserta ta_cobros para cuentas relacionadas de las que se debito*/
                         rg_ot.nro_cuenta := rg.nro_cuenta;
                         rg_ot.nro_tarjeta := rg.nro_tarjeta;
                         rg_ot.nro_cta_debito := i.nro_cuenta;
                         rg_ot.monto := v_mto_deu;
                         rg_ot.dia_mora := rg.dia_mora;
                         --Inserta el registro del Cobro--
                         lp_ins_reg_cobro(rg_ot);
                         v_mto_deu_res := nvl(v_mto_deu_res,0) - nvl(v_mto_deu,0);
                         v_mto_deu_mov := nvl(v_mto_deu_mov,0) + nvl(v_mto_deu,0);
                         v_mto_deu := v_mto_deu_res;
                         IF v_mto_deu_res = 0 THEN
                            EXIT;
                         ELSE
                            v_mto_deu_deb :=  v_mto_deu_res;
                         END IF;
                         IF v_commitea = 'S' THEN
                            --commit;
                            null;
                         END IF;
                      ELSE
                         prg_rol_savepoint(v_rol_referencia);
                      END IF;
                    End if;
                  End if;
             END LOOP;
             if nvl(v_mto_deu_mov,0) > 0 THEN
                  --Genera el movimiento por el credito
                  r_gmovi.cod_usuario     := user;
                  r_gmovi.hora            := v_hora;
                  if (v_est_modulo = 2  and  nvl(v_horario, 'D') = 'D') or
                  (nvl(PAE_CNF.G_PROGRAMA,'x') in ('GPPAGSUE','GPPROFIN'))  then
                      r_gmovi.fecha           := v_fcdehoy;
                  else
                      r_gmovi.fecha :=  v_fec_proxima;
                  end if;
                  -- Aumento la secuencia
                  v_nro_secuencia := v_nro_secuencia + 1;
                  if v_nro_secuencia > 990 then
                     --v_hora  := pag_gen.fu_obt_sig_segundo(v_hora);
                     v_hora := fug_obt_hor_disponible(v_fcdehoy,v_hora,user,v_es_nocturno); -- DYDMR-5283 NAF. Nov/2016
                     v_nro_Secuencia := 0;
                  end if;
                  r_gmovi.nro_secuencia   := v_nro_secuencia;
                  r_gmovi.cod_modulo      := rg.cod_modulo;
                  r_gmovi.cod_modalidad   := rg.cod_modalidad;
                  r_gmovi.cod_oficina     := rg.cod_oficina;
                  r_gmovi.cod_moneda      := rg.cod_moneda;
                  r_gmovi.fec_valor       := v_fcdehoy;
                  r_gmovi.cod_tra_padre   := v_cod_tra_padre;
                  r_gmovi.cod_mod_padre   := 5;
                  r_gmovi.cod_mad_padre   := rg.cod_modalidad;
                  r_gmovi.cod_transaccion := 978;
                  r_gmovi.monto           := v_mto_deu_mov;
                  r_gmovi.nro_documento   := rg.nro_cuenta;
                  r_gmovi.nro_cuenta      := rg.nro_cuenta;
                  r_gmovi.cod_ofi_origen  := rg.cod_oficina;
                  r_gmovi.emi_aviso       := 'N';
                  r_gmovi.concepto        := 'Crédito de tarjetas con Pago Atrasado';
                  r_gmovi.estado          := 'N';
                  r_gmovi.reversado       := 'N';
                  PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi,v_es_nocturno); -- DYDMR-5283 NAF. Nov/2016

                  --Actualiza Registro de Tabla de Control--
                  v_est_cob_aux := null;
                  if nvl(rg.monto,0) > (nvl(rg.mto_cobrado,0) + nvl(v_mto_deu_mov,0)) then
                     v_est_cob_aux := 'F';
                  else
                     v_est_cob_aux := 'P';
                  end if;
                     update TA_CTA_DEB_AUT_COBRAR x
                        set x.estado      = v_est_cob_aux,
                            x.mto_cobrado = nvl(rg.mto_cobrado,0) + nvl(v_mto_deu_mov,0),
                            x.observacion = v_obser,
                            x.fec_proceso = v_fcdehoy,
                            x.fec_valor   = v_fcdehoy,
                            x.can_pagos   = nvl(rg.can_pagos,0) + 1
                      where rowid = rg.reg_cuenta;
                  ------------------------------------------
                  v_commitea := 'S';
             end if;
          else
             --Registro de control se pasa a P-Pagado, ya tiene abonado--
             update TA_CTA_DEB_AUT_COBRAR x
                set x.estado      = 'P',
                    x.mto_cobrado = nvl(rg.mto_cobrado,0),
                    x.observacion = v_obser,
                    x.fec_proceso = v_fcdehoy,
                    x.fec_valor   = v_fcdehoy,
                    x.can_pagos   = nvl(rg.can_pagos,0)
              where rowid = rg.reg_cuenta;
          end if;
      END LOOP;
      close op_cursor;
  end;

  --Procesando Debitos Automaticos--
  procedure lp_pro_deb_ente is
    v_dia_atr_deb_aut number(6);

    --Cursor Principal de Cuentas--
    cursor op_cursor IS
      select cob.nro_cta_debito, cob.nro_tarjeta, cob.monto, cob.cod_modulo,
             cob.cod_moneda, cob.cod_modalidad, cob.nro_cuenta, cob.cod_oficina,
             cob.dia_mora, cob.rowid reg_cuenta, cob.cod_persona,
             nvl(x.mto_cobrado,0) mto_cobrado, nvl(x.can_pagos,0) can_pagos
        from TA_CTA_DEB_AUT_COBRAR cob,
        (select x.nro_cuenta,
                sum(nvl(x.monto,0)) mto_cobrado,
                count(*) can_pagos
           from ta_cobros x
          where x.fec_proceso between v_fec_anterior and v_fec_proxima
            and x.estado in ('P','C')
          group by x.nro_cuenta) x
       where ((cob.nro_cta_debito = p_nro_cta_debito) or (p_nro_cta_debito is null))
         and cob.cod_persona = nvl(p_cod_persona, cob.cod_persona)
         and cob.fec_proceso = v_fcdehoy
         and cob.estado in ('I','F')  --I-Insertado, F-Pagado una fraccion--
         and cob.dia_mora >= v_dia_atr_deb_aut
         and x.nro_cuenta(+) = cob.nro_cuenta
         and cob.referencia in ('02_PRO_MOROSO','03_PRO_ATRASADO')
         and exists (select 1
                       from GE_CTA_CLIENTES R, GE_PAG_SUELDOS P
                      WHERE r.nro_cuenta = p.nro_cuenta
                        and cod_ente = p_cod_ente
                        and p.nro_secuencia = p_nro_secuencia
                        and relacion = 'P'
                        and p.tipo = 'C'
                        and cod_proceso = 0
                        and r.cod_persona = cob.cod_persona
                        and fec_proceso = p_fecha)
       order by 1;

    --Cursor de Cuentas Relacionadas--
    rg op_cursor%rowtype;
    Cursor cta_relacionadas(p_cod_persona_rel In ge_clientes.cod_persona%Type,
                            p_cta_debito  In ge_cuentas.nro_cuenta%Type) Is
    select z.nro_cta_debito nro_cuenta,
           z.cod_persona,
           z.relacion,
           z.cod_moneda,
           DECODE(z.COD_MODULO, 3, (B.SAL_TOTAL - (B.SAL_BLOQUEADO + B.SAL_RETENIDO)),
                                4, (C.SAL_TOTAL - (C.SAL_RETENIDO + C.SAL_BLOQUEADO))) sal_total,
           z.cod_modulo,
           z.cod_modalidad
      from TA_CTA_DEB_AUT_DETALLE z,  AH_CTA_VISTAS B, CC_CTA_CORRIENTES C
     where z.COD_PERSONA = P_COD_PERSONA_rel
       AND z.nro_cta_debito <> p_cta_debito
       AND z.nro_cta_debito = B.NRO_CUENTA(+)
       AND z.nro_cta_debito = C.NRO_CUENTA(+)
       AND nvl(c.cod_moneda, b.cod_moneda) = z.cod_moneda
       AND DECODE(z.COD_MODULO, 3,(B.SAL_TOTAL - (B.SAL_BLOQUEADO + B.SAL_RETENIDO)),
                                4,(C.SAL_TOTAL - (C.SAL_RETENIDO + C.SAL_BLOQUEADO))) > 0
       and not exists
       (select m.nro_cta_ahorro
          from cc_cta_combinadas m, ah_cta_vistas v
             where v.nro_cuenta = m.nro_cta_ahorro
               and m.nro_cta_cte = z.nro_cta_debito
               and v.SAL_TOTAL - (v.SAL_BLOQUEADO + v.SAL_RETENIDO) >
                   DECODE(z.COD_MODULO, 3, (B.SAL_TOTAL - (B.SAL_BLOQUEADO + B.SAL_RETENIDO)),
                                        4, (C.SAL_TOTAL - (C.SAL_RETENIDO + C.SAL_BLOQUEADO)))
            union all
            select m.nro_cta_cte
              from cc_cta_combinadas m, cc_cta_corrientes v
             where v.nro_cuenta = m.nro_cta_cte
               and m.nro_cta_ahorro = z.nro_cta_debito
               and v.SAL_TOTAL - (v.SAL_BLOQUEADO + v.SAL_RETENIDO) >
                   DECODE(z.COD_MODULO, 3, (B.SAL_TOTAL - (B.SAL_BLOQUEADO + B.SAL_RETENIDO)),
                                        4, (C.SAL_TOTAL - (C.SAL_RETENIDO + C.SAL_BLOQUEADO))))
    ORDER BY 5 DESC;

    --Variables Principales--
    V_COD_PERSONA BA_PERSONAS.COD_PERSONA%TYPE;
    v_mto_deu_deb    ge_cuentas.sal_contable%type;
    v_mto_deu        ge_cuentas.sal_contable%TYPE;
    v_mto_deu_res    ge_cuentas.sal_contable%TYPE := 0;
    v_mto_deu_mov    ge_cuentas.sal_contable%TYPE := 0;

  begin
     v_dia_atr_deb_aut := fug_obt_pardinamico('TAR_ATR_DEB_AUT_CUENTAS_REL');
     v_hora := to_char(SYSDATE, 'HH24:MI:SS');
     v_hora := fug_obt_hor_disponible(v_fcdehoy,v_hora,user,v_es_nocturno); -- DYDMR-5283 NAF. Nov/2016
     v_nro_cta_ant := 'x';
     if op_cursor%isopen then
        close op_cursor;
     end if;
      open op_cursor;
      --Ciclo de Cuentas de Tarjetas de Credito--
      loop
        fetch op_cursor into rg;
        exit when op_cursor%notfound;
          v_lugar := 'cuenta  : '||rg.nro_cuenta||' deb '||rg.nro_cta_debito;
          v_mto_deu     := rg.monto;
          v_mto_deu_res := rg.monto;
          v_mto_deu_deb := v_mto_deu;
          v_mto_deu_mov := 0;
          v_estado := 'E';
          --Validacion para actualizar estado del registro de la cuenta--
          if nvl(rg.mto_cobrado,0) >= nvl(rg.monto,0) then
             v_tie_deu_pen := 'N';
          else
             v_tie_deu_pen := 'S';
          end if;
          if v_tie_deu_pen = 'S' then
              -----------
             v_cod_persona := rg.cod_persona;
             v_mto_deu     := nvl(rg.monto,0) - nvl(rg.mto_cobrado,0);
             v_mto_deu_res := v_mto_deu;
             v_mto_deu_deb := v_mto_deu;
             --Ciblo de Cuentas Relacionadas--
             FOR i IN cta_relacionadas(v_cod_persona, nvl(rg.nro_cta_debito, rg.nro_cuenta)) LOOP
                v_rol_referencia := 'Cta. '||i.nro_cuenta||' Tar. '||rg.nro_tarjeta;
                prg_cre_savepoint(v_rol_referencia);
                v_commitea       := 'N';
                v_lugar := 'Tarjeta  : '||rg.nro_tarjeta;
                v_estado := 'P';
                v_est_envio := 'P';
                v_obser := 'Registro procesado prt_deb_automatico ATR';
                if v_nro_secuencia > 990 OR rg.nro_cuenta <> v_nro_cta_ant then
                   v_hora := fug_obt_hor_disponible(v_fcdehoy,v_hora,user,v_es_nocturno);
                   v_nro_secuencia := 0;
                   v_nro_cta_ant := rg.nro_cuenta;
                end if;
                ----- Recuperar datos de la cuenta, de la que va a debitar
                pag_cta.pr_obt_cuenta(i.nro_cuenta);
                if pag_cta.g_cod_error <> 0 then
                   v_estado    := 'E';
                   v_est_envio := null; --DYDMR-3085 GC 24/02/2016 PAGOS DUPLICADOS SE REGULARIZA EL CAMPO EST_ENVIO
                   v_obser := fug_obt_err_sueldos(pag_cta.g_cod_error);
                end if;
                -- Validar si es que tiene transacción prohibida.
                if v_estado = 'P' then
                   If pag_cta.FU_VER_TRA_PROHIBIDA(rg.nro_cuenta, v_cod_tra_padre) = 'S' then
                      v_estado := 'E';
                      v_est_envio := null; --DYDMR-3085 GC 24/02/2016 PAGOS DUPLICADOS SE REGULARIZA EL CAMPO EST_ENVIO
                      v_obser  := 'Cuenta de Tarjeta con Transaccion Prohibida';
                   End if;
                end if;
                --- Calculo el total a debitar en la moneda de la cuenta de debito
          v_cot_mon_tar := null;
          v_cot_mon_deb := null;
          --v_mto_deu_deb := 0;
          --
          If rg.cod_moneda != pag_cta.g_ctas.cod_moneda then
            /* por ahora se anula esto para que no debite en moneda diferente */
            If fug_obt_tip_implementacion = 7 then
                v_estado    := 'E';
                v_est_envio := null; --DYDMR-3085 GC 24/02/2016 PAGOS DUPLICADOS SE REGULARIZA EL CAMPO EST_ENVIO
                v_obser := 'Cobro en diferentes monedas no permitido';
            Else
            /* Obtiene el monto en moneda Extranjera a Debitar */
                pag_gen.pr_con_mon_a_moneda(rg.cod_moneda, pag_cta.g_ctas.cod_moneda,
                                            v_mto_deu, v_mto_deu_deb,
                                            v_cot_mon_tar, v_cot_mon_deb);
            end if;
          End if;
          -- 16/09/2013 GC - DC 2776 Se descomenta desde la linea 220 a la 231.
          /* se comenta esto porque no fue pedido por el usuario, y no fue probado aún*/
          -- RI: 10/08/2010: se tiene en cuenta la linea de sobregiro
          v_lin_sobregiro := 0;
          if pag_cta.g_ctas.cod_modalidad = 41 then
             v_lin_sobregiro := nvl(pag_cta.FU_OBT_LIN_SOBREGIRO(i.nro_cuenta, v_fcdehoy),0);
          end if;

                if nvl(pag_cta.g_ctas.sal_disponible,0)+nvl(pag_cta.g_ctas.sal_dis_combinada,0)+v_lin_sobregiro
                    < nvl(v_mto_deu_deb,0) and
                     nvl(pag_cta.g_ctas.sal_disponible,0)+nvl(pag_cta.g_ctas.sal_dis_combinada,0)+v_lin_sobregiro > 0 THEN
                     v_mto_deu_deb := nvl(pag_cta.g_ctas.sal_disponible,0)+nvl(pag_cta.g_ctas.sal_dis_combinada,0)+v_lin_sobregiro;
                   --hasta aquí se comenta

                    /*if nvl(pag_cta.g_ctas.sal_disponible,0) < nvl(v_mto_deu_deb,0) and
                       nvl(pag_cta.g_ctas.sal_disponible,0) > 0 then
                       v_mto_deu_deb := nvl(pag_cta.g_ctas.sal_disponible,0);*/

                    If rg.cod_moneda != pag_cta.g_ctas.cod_moneda then
                       --
                       v_cot_mon_tar := null;
                       v_cot_mon_deb := null;
                    /* Obtiene el monto en moneda local a Debitar por el Saldo Disponible de la Cuenta en moneda Extranjera */
                       pag_gen.pr_con_mon_a_moneda(pag_cta.g_ctas.cod_moneda, rg.cod_moneda,
                                                v_mto_deu_deb, v_mto_deu,
                                                v_cot_mon_deb, v_cot_mon_tar);
                                                /*En este punto ya se el monto a debitar y puedo
                                                obtener el monto restante*/
                     else
                        v_mto_deu := v_mto_deu_deb;
                     End if;
                end if;
                  if v_estado = 'P' then
                    --- Verificar si puede realizarse la operación sobre la cuenta de débito
                    pag_cta.pr_ver_operacion(i.nro_cuenta, v_cod_tra_padre, rg.cod_modulo, rg.cod_modalidad,
                                           'D', pag_cta.g_ctas.cod_moneda, v_mto_deu_deb, rg.cod_oficina,
                                           -- out
                                           pag_cta.g_ctas.cod_modulo, pag_cta.g_ctas.cod_modalidad,
                                           v_nvo_estado, v_sal_disponible, v_procesa);
                    if pag_cta.g_cod_error <> 0 or v_procesa = 'N' then
                      v_estado:= 'E';
                      v_est_envio := null; --DYDMR-3085 GC 24/02/2016 PAGOS DUPLICADOS SE REGULARIZA EL CAMPO EST_ENVIO
                      v_obser := substr(fug_obt_err_sueldos(pag_cta.g_cod_error),1,50);
                    end if;
                    if v_estado = 'P' then
                      --- DEBITAR de la cuenta
                      pag_cta.pr_act_operacion(i.nro_cuenta, v_hora, 'D', pag_cta.g_ctas.cod_moneda,
                                               v_mto_deu_deb, v_cod_tra_padre, 503, rg.nro_cuenta, v_cot_mon_deb,
                                               rg.cod_oficina, rg.cod_modulo, rg.cod_modalidad,
                                               null, null, 'Debito automatico de Pagos Atrasados de Tarjetas ',
                                               'S', v_nro_secuencia , v_fcdehoy, null,null,v_mto_deu);
                      IF pag_cta.g_cod_error <> 0 then
                        v_estado:= 'E';
                        v_est_envio := null; --DYDMR-3085 GC 24/02/2016 PAGOS DUPLICADOS SE REGULARIZA EL CAMPO EST_ENVIO
                        v_obser := substr(fug_obt_err_sueldos(pag_cta.g_cod_error),1,50);
                      ELSE
                        v_commitea := 'S';
                      end if;
                      IF v_estado = 'P' THEN
                      /*Inserta ta_cobros para cuentas relacionadas de las que se debito*/
                         rg_ot.nro_cuenta := rg.nro_cuenta;
                         rg_ot.nro_tarjeta := rg.nro_tarjeta;
                         rg_ot.nro_cta_debito := i.nro_cuenta;
                         rg_ot.monto := v_mto_deu;
                         rg_ot.dia_mora := rg.dia_mora;
                         --Inserta el registro del Cobro--
                         lp_ins_reg_cobro(rg_ot);
                         v_mto_deu_res := nvl(v_mto_deu_res,0) - nvl(v_mto_deu,0);
                         v_mto_deu_mov := nvl(v_mto_deu_mov,0) + nvl(v_mto_deu,0);
                         v_mto_deu := v_mto_deu_res;
                         IF v_mto_deu_res = 0 THEN
                            EXIT;
                         ELSE
                            v_mto_deu_deb :=  v_mto_deu_res;
                         END IF;
                         IF v_commitea = 'S' THEN
                            --commit;
                            null;
                         END IF;
                      ELSE
                         prg_rol_savepoint(v_rol_referencia);
                      END IF;
                    End if;
                  End if;
             END LOOP;
             if nvl(v_mto_deu_mov,0) > 0 THEN
                  --Genera el movimiento por el credito
                  r_gmovi.cod_usuario     := user;
                  r_gmovi.hora            := v_hora;
                  if (v_est_modulo = 2  and  nvl(v_horario, 'D') = 'D') or
                  (nvl(PAE_CNF.G_PROGRAMA,'x') in ('GPPAGSUE','GPPROFIN'))  then
                      r_gmovi.fecha           := v_fcdehoy;
                  else
                      r_gmovi.fecha :=  v_fec_proxima;
                  end if;
                  -- Aumento la secuencia
                  v_nro_secuencia := v_nro_secuencia + 1;
                  if v_nro_secuencia > 990 then
                     --v_hora  := pag_gen.fu_obt_sig_segundo(v_hora);
                     v_hora := fug_obt_hor_disponible(v_fcdehoy,v_hora,user,v_es_nocturno); -- DYDMR-5283 NAF. Nov/2016
                     v_nro_Secuencia := 0;
                  end if;
                  r_gmovi.nro_secuencia   := v_nro_secuencia;
                  r_gmovi.cod_modulo      := rg.cod_modulo;
                  r_gmovi.cod_modalidad   := rg.cod_modalidad;
                  r_gmovi.cod_oficina     := rg.cod_oficina;
                  r_gmovi.cod_moneda      := rg.cod_moneda;
                  r_gmovi.fec_valor       := v_fcdehoy;
                  r_gmovi.cod_tra_padre   := v_cod_tra_padre;
                  r_gmovi.cod_mod_padre   := 5;
                  r_gmovi.cod_mad_padre   := rg.cod_modalidad;
                  r_gmovi.cod_transaccion := 978;
                  r_gmovi.monto           := v_mto_deu_mov;
                  r_gmovi.nro_documento   := rg.nro_cuenta;
                  r_gmovi.nro_cuenta      := rg.nro_cuenta;
                  r_gmovi.cod_ofi_origen  := rg.cod_oficina;
                  r_gmovi.emi_aviso       := 'N';
                  r_gmovi.concepto        := 'Crédito de tarjetas con Pago Atrasado';
                  r_gmovi.estado          := 'N';
                  r_gmovi.reversado       := 'N';
                  PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi,v_es_nocturno); -- DYDMR-5283 NAF. Nov/2016

                  --Actualiza Registro de Tabla de Control--
                  v_est_cob_aux := null;
                  if nvl(rg.monto,0) > (nvl(rg.mto_cobrado,0) + nvl(v_mto_deu_mov,0)) then
                     v_est_cob_aux := 'F';
                  else
                     v_est_cob_aux := 'P';
                  end if;
                     update TA_CTA_DEB_AUT_COBRAR x
                        set x.estado      = v_est_cob_aux,
                            x.mto_cobrado = nvl(rg.mto_cobrado,0) + nvl(v_mto_deu_mov,0),
                            x.observacion = v_obser,
                            x.fec_proceso = v_fcdehoy,
                            x.fec_valor   = v_fcdehoy,
                            x.can_pagos   = nvl(rg.can_pagos,0) + 1
                      where rowid = rg.reg_cuenta;
                  ------------------------------------------
                  v_commitea := 'S';
             end if;
          else
             --Registro de control se pasa a P-Pagado, ya tiene abonado--
             update TA_CTA_DEB_AUT_COBRAR x
                set x.estado      = 'P',
                    x.mto_cobrado = nvl(rg.mto_cobrado,0),
                    x.observacion = v_obser,
                    x.fec_proceso = v_fcdehoy,
                    x.fec_valor   = v_fcdehoy,
                    x.can_pagos   = nvl(rg.can_pagos,0)
              where rowid = rg.reg_cuenta;
          end if;
      END LOOP;
      close op_cursor;
  end;

  --Proceso de verificación de ejecución del proceso a nivel de ge_proceso
  procedure lp_ver_proceso is
  begin
     select p.cod_usuario
       into v_cod_usuario
       from ge_procesos p, ge_procesos_det det
      where p.cod_proceso = det.cod_proceso
        and det.cod_programa = 'PRT_DEB_AUTOMATICO_ATR'
        and p.hor_inicio < to_char(sysdate, 'HH24:MI:SS')
        and p.hor_fin is null
        and p.error is null
        and p.cod_usuario <> user;
      if v_cod_usuario is not null then
         raise_application_error(-20001,'Proceso en Ejecución por el usuario '||v_cod_usuario);
      end if;
  exception
    when no_data_found then
      null;
    when others then
      raise_application_error(-20001,'Error al consultar Ejecución del proceso '||sqlerrm);
  end;
  --Proceso de verificación de ejecución del proceso a nivel de sessiones
  procedure lp_ver_sesion is
  begin
    select substr(username,1,10)
      into v_cod_usuario
      from v$session s, user_objects u
     where s.plsql_entry_object_id = u.object_id
       and u.object_name = 'PRT_DEB_AUTOMATICO_ATR'
       and lower(s.username) <> lower(user)
       and s.status <> 'KILLED';
     if v_cod_usuario is not null then
        raise_application_error(-20001,'Proceso en Ejecución por el usuario '||v_cod_usuario);
     end if;
  exception
     when no_data_found then
       --Verifico que no se ejecute en simultáneo el Proceso con otro Usuario.
       lp_ver_proceso;
     when too_many_rows then
       raise_application_error(-20001,'Existen más de un usuario ejecutando el proceso');
     when others then
       raise_application_error(-20001,'Error al consultar Ejecución del proceso '||sqlerrm);
  end;
Begin
  begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1;end;
  -- DYDMR-5283 NAF. Nov/2016 soporte de tablas noc_
  if nvl(PAE_CNF.G_PROGRAMA,'x') not in ('GPPAGSUE','GPPROFIN') then
    v_est_modulo := pae_cnf.FU_OBT_EST_MODULO(4);
    If v_est_modulo = 2 then
       v_horario := 'D' ; -- N=Cerrado, D=Abierto
       v_es_nocturno := 'N'; -- N=Abierto,  S=Cerrado
    else
       v_horario := 'N' ; -- N=Cerrado, D=Abierto
       v_es_nocturno := 'S'; -- N=Abierto,  S=Cerrado
    end if;
  end if ;

  pag_cal.pr_obt_dat_calendar(5);
  v_fcdehoy       := pag_cal.G_FEC_ACTUAL;
  v_fec_anterior  := pag_cal.G_FEC_ANTERIOR;
  v_fec_proxima   := pag_cal.g_fec_proxima;
  v_hora          := to_char(sysdate,'HH24:MI:SS');
  v_hora          := fug_obt_hor_disponible(v_fcdehoy,v_hora,user,v_es_nocturno); -- DYDMR-5283 NAF. Nov/2016
  v_nro_secuencia := 0;
  v_dia_aguinaldo  := nvl(fug_obt_pardinamico('CAN_DIA_DEB_AGUINALDO'),0);
  --If nvl(pae_cnf.G_PROGRAMA,'X')  = 'GPPAGSUE' then
  If (nvl(pae_cnf.G_PROGRAMA,'X')  in ('GPPAGSUE','GPPROSUE')) /*OR (UPPER(user) = v_cod_usu_hb)*/ then
     -- Viene desde pago de Sueldos...
     --v_pago_sueldo   := 'S';
     v_cod_tra_padre := 186;
     if pae_cnf.G_HORA is null then
       --wa:12/10 se comenta ya obtiene al ingresar la hora disponible
       --v_hora          := to_char(sysdate,'HH24:MI:SS');

       v_nro_secuencia := 0;
     else
       v_hora          := pae_cnf.G_HORA;
       v_nro_secuencia := nvl(pae_cnf.G_NRO_SECUENCIA,0) + 1;
        if v_nro_secuencia > 990 then
           --v_hora  := pag_gen.fu_obt_sig_segundo(v_hora);
           v_hora := fug_obt_hor_disponible(v_fcdehoy,v_hora,user,v_es_nocturno); -- DYDMR-5283 NAF. Nov/2016
           v_nro_Secuencia := 0;
        end if;
     end if;
     --AP 2331 - Verifico que no se ejecute en simultáneo el Proceso Indep. con otro Usuario.
     lp_ver_proceso;
  else
     --AP 2331 - Verifico para que no se ejecute el procedimiento en simultáneo con el GPPAGSUE.
     lp_ver_sesion;
  end if;
  -- DYDMR-7327 OMM SEP/2017 Se separa de la condición anterior por que la secuencia debe iniciar en 1.
  if (UPPER(user) = v_cod_usu_hb) then
      v_cod_tra_padre := 186;
      lp_ver_proceso;
  end if ;
  --Proceso de Debitos Automaticos--
 if P_COD_ENTE is not null then
    v_lugar := 'lp_pro_deb_ente';
    lp_pro_deb_ente;
 else
    v_lugar := 'lp_pro_debitos';
    lp_pro_debitos;
 end if;
 --- Asigno la secuencia a la Global...
  if (UPPER(user) <> v_cod_usu_hb) then
      pae_cnf.G_NRO_SECUENCIA := v_nro_secuencia;
      pae_cnf.g_hora := v_hora;
  end if;

EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE < -20000 THEN
        raise;
    ELSE
        raise_application_error(-20002,'Error : '||v_lugar||' '||sqlerrm);
    END IF;
END;
/