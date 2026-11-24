CREATE OR REPLACE PROCEDURE IT.PRT_DEB_PLA_SUELDOS
 (P_NRO_CTA_DEBITO IN TA_CTA_TARJETAS.NRO_CTA_DEBITO%TYPE
 )
 IS
  v_estado        ge_movimientos.estado%type;
  v_obser         ta_cobros.observacion%type;
  v_hora          ge_movimientos.hora%type;
  v_fcdehoy       date;
  v_nro_secuencia ge_movimientos.nro_secuencia%type;
  v_cod_tra_padre ge_movimientos.cod_transaccion%type := 186;
  r_gmovi         ge_movimientos%rowtype;

  --- Datos para utilizar la cuenta de débito
  v_mto_deu_deb    ge_cuentas.sal_contable%type;
  v_mto_deu        ge_cuentas.sal_contable%type;
  v_cot_mon_tar    ge_cotizaciones.val_conversion%type;
  v_cot_mon_deb    ge_cotizaciones.val_conversion%type;
  v_nvo_estado     ge_cuentas.estado%type;
  v_sal_disponible ge_cuentas.sal_contable%type;
  v_procesa        varchar2(01);

  --Carga los debitos automaticos a realizar
  procedure lp_car_deb_automaticos;
  --Marca cobrados anteriormente
  procedure lp_mar_cobrados;
  --Proceso de debitos automaticos
  procedure lp_pro_debitos;
  --Carga los debitos automaticos a realizar
  procedure lp_car_deb_automaticos is
  begin
       --por el vencimiento de pago
       insert into ta_cobros (nro_cta_debito,nro_tarjeta,monto,nro_cuenta,fec_proceso,estado,fec_valor,
                              hora)
       select nro_cta_debito, nro_tarjeta,nvl(sal_pag_minimo,0),tar.nro_cuenta,v_fcdehoy,'E',v_fcdehoy,
              v_hora --DYDMR-728 Reversion cobro tarjeta de credito SC - 4685
         from ta_tarjetas  tar,
              ge_cta_clientes cli,
              ta_cta_tarjetas cta
        where cta.nro_cta_debito = nvl(p_nro_cta_debito,cta.nro_cta_debito)
          and nro_cta_debito is not null
          and tar.nro_cuenta = cli.nro_cuenta
          and cli.cod_persona = tar.cod_persona
          and vigente = 'S'
          and cta.nro_cuenta = tar.nro_cuenta
          and relacion = 'P'
          and fec_vct_ult_cierre >= v_fcdehoy
          and fec_ult_cierre < v_fcdehoy
          and nvl(deb_automatico, 'N') = 'S'
          and nvl(sal_pag_minimo, 0) > 0;
  end;
  --marcando cobrados anteriormente
  procedure lp_mar_cobrados is
    begin
      update ta_cobros a
      set    estado = 'X',
             observacion = 'No realizado. Pagado anteriormente',
             fec_proceso = v_fcdehoy
      where exists (select '1'
                     from  ge_calendarios, ta_cobros b
                     where cod_modulo = 5
                     and   b.nro_tarjeta = a.nro_tarjeta
                     and   nvl(b.estado,'X') in ('C', 'P')
                     and   b.fec_proceso between fec_anterior and fec_proxima)
        and nvl(estado,'E') = 'E'
        and nvl(fec_proceso,v_fcdehoy) = v_fcdehoy;
      --------------
      -- marco los que fueron pagados en el dia con cargo otros
      --------------
      update ta_cobros a
      set    estado = 'X',
             observacion = 'No realizado. Pagado chq.c/otros',
             fec_proceso = v_fcdehoy
      where exists (select '1'
                     from  ge_movimientos mov, ta_tarjetas tar
                     where mov.nro_cuenta = tar.nro_cuenta
                       and cod_tra_padre in (250, 450)
                       and cod_transaccion = 607
                       and reversado = 'N'
                       and tar.nro_tarjeta = a.nro_tarjeta)
        and nvl(estado,'E') = 'E'
        and nvl(fec_proceso,v_fcdehoy) = v_fcdehoy;
    end;
  --procesando debitos automaticos
  procedure lp_pro_debitos is
    cursor op_cursor is
      select nro_cta_debito, tar.nro_tarjeta, monto,cli.cod_modulo,cta.cod_moneda,
             cli.cod_modalidad,tar.nro_cuenta, cta.cod_oficina,cob.rowid fila
        from ge_cta_clientes cli,
             ta_tarjetas tar,
             ta_cobros cob,
             ge_cuentas cta
       where cli.nro_cuenta      = tar.nro_cuenta
         and cli.cod_persona     = tar.cod_persona
         and nvl(cob.estado,'E') = 'E'
         and nvl(cob.fec_proceso,v_fcdehoy) = v_fcdehoy
         and tar.nro_tarjeta   = cob.nro_tarjeta
         and cli.cod_modulo    = cta.cod_modulo
         and cli.cod_modalidad = cta.cod_modalidad
         and cli.nro_cuenta    = cta.nro_cuenta
         and cli.nro_cuenta    = nvl(p_nro_cta_debito, cli.nro_cuenta);
    rg op_cursor%rowtype;

  begin
      if op_cursor%isopen then
         close op_cursor;
      end if;
      open op_cursor;
      loop
        fetch op_cursor into rg;
        exit when op_cursor%notfound;
        v_estado := 'P';
        v_obser := 'Registro procesado';
        v_hora  := pag_gen.fu_obt_sig_segundo(v_hora);
        ----- Recuperar datos de la cuenta, de la que va a debitar
        pag_cta.pr_obt_cuenta(rg.nro_cta_debito);
        if pag_cta.g_cod_error <> 0 then
          v_estado    := 'E';
          v_obser := fug_obt_err_sueldos(pag_cta.g_cod_error);
        end if;
        -- Validar si es que tiene transacción prohibida.
        if v_estado = 'P' then
           If pag_cta.FU_VER_TRA_PROHIBIDA(rg.nro_cuenta, v_cod_tra_padre) = 'S' then
              v_estado := 'E';
              v_obser  := 'Cuenta de Tarjeta con Transaccion Prohibida';
           End if;
        end if;
        -- Calculo el total a debitar en la moneda de la cuenta de debito
        v_cot_mon_tar := null;
        v_cot_mon_deb := null;
        v_mto_deu_deb := 0;
        v_mto_deu     := rg.monto;
        --
        v_mto_deu_deb := v_mto_deu;
        If rg.cod_moneda != pag_cta.g_ctas.cod_moneda then
          If fug_obt_tip_implementacion in (1,7) then
              v_estado    := 'E';
              v_obser := 'Cobro en diferentes monedas no permitido';
          Else
              pag_gen.pr_con_mon_a_moneda(rg.cod_moneda, pag_cta.g_ctas.cod_moneda,
                                          v_mto_deu, v_mto_deu_deb,
                                          v_cot_mon_tar, v_cot_mon_deb);
          End if;
        End if;
        if nvl(pag_cta.g_ctas.sal_disponible,0) < nvl(v_mto_deu_deb,0) and
           nvl(pag_cta.g_ctas.sal_disponible,0) > 0 then
           v_mto_deu_deb := nvl(pag_cta.g_ctas.sal_disponible,0);
           If rg.cod_moneda != pag_cta.g_ctas.cod_moneda then
             --
             v_cot_mon_tar := null;
             v_cot_mon_deb := null;
             pag_gen.pr_con_mon_a_moneda(pag_cta.g_ctas.cod_moneda, rg.cod_moneda,
                                      v_mto_deu_deb, v_mto_deu,
                                      v_cot_mon_deb, v_cot_mon_tar);
           else
              v_mto_deu := v_mto_deu_deb;
           End if;
        end if;

        if v_estado = 'P' then
          --- Verificar si puede realizarse la operación sobre la cuenta de débito
          pag_cta.pr_ver_operacion(rg.nro_cta_debito, v_cod_tra_padre, rg.cod_modulo, rg.cod_modalidad,
                                 'D', pag_cta.g_ctas.cod_moneda, v_mto_deu_deb, rg.cod_oficina,
                                 -- out
                                 pag_cta.g_ctas.cod_modulo, pag_cta.g_ctas.cod_modalidad,
                                 v_nvo_estado, v_sal_disponible, v_procesa);
          if pag_cta.g_cod_error <> 0 or v_procesa = 'N' then
            v_estado:= 'E';
            v_obser := fug_obt_err_sueldos(pag_cta.g_cod_error);
          end if;
          if v_estado = 'P' then
            --- DEBITAR de la cuenta
            v_nro_secuencia := v_nro_secuencia + 1;
            pag_cta.pr_act_operacion(rg.nro_cta_debito, v_hora, 'D', pag_cta.g_ctas.cod_moneda,
                                     v_mto_deu_deb, v_cod_tra_padre, 503, rg.nro_cuenta, null,
                                     rg.cod_oficina, rg.cod_modulo, rg.cod_modalidad,
                                     null, null, 'Debito automatico de tarjetas ',
                                     'S', v_nro_secuencia , v_fcdehoy);
            if pag_cta.g_cod_error <> 0 then
              v_estado:= 'E';
              v_obser := fug_obt_err_sueldos(pag_cta.g_cod_error);
            end if;
          End if;
        End if;
        if v_estado = 'P' then
          --Genera el movimiento por el credito
      	  r_gmovi.cod_usuario     := user;
      	  r_gmovi.hora            := v_hora;
      	  r_gmovi.fecha           := v_fcdehoy;
      	  -- Aumento la secuencia
      	  v_nro_secuencia := v_nro_secuencia + 1;
      	  r_gmovi.nro_secuencia   := v_nro_secuencia;
      	  r_gmovi.cod_modulo      := rg.cod_modulo;
      	  r_gmovi.cod_modalidad   := rg.cod_modalidad;
      	  r_gmovi.cod_oficina     := rg.cod_oficina;
      	  r_gmovi.cod_moneda      := rg.cod_moneda;
      	  r_gmovi.fec_valor       := v_fcdehoy;
      	  r_gmovi.cod_tra_padre   := v_cod_tra_padre;
      	  r_gmovi.cod_mod_padre   := 5;
      	  r_gmovi.cod_mad_padre   := 51;
      	  r_gmovi.cod_transaccion := 978;
      	  r_gmovi.monto           := v_mto_deu;
      	  r_gmovi.nro_documento   := rg.nro_cuenta;
      	  r_gmovi.nro_cuenta      := rg.nro_cuenta;
      	  r_gmovi.cod_ofi_origen  := rg.cod_oficina;
      	  r_gmovi.emi_aviso       := 'N';
      	  r_gmovi.concepto        := 'Crédito de tarjetas';
      	  r_gmovi.estado          := 'N';
      	  r_gmovi.reversado       := 'N';
      	  PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi);
        end if;
        -- actualizo el registro --
        update ta_cobros
           set estado      = v_estado,
               monto       = v_mto_deu,
               observacion = v_obser,
               fec_proceso = v_fcdehoy,
               fec_valor = nvl(fec_valor, v_fcdehoy)
        where rowid = rg.fila;
      end loop;
      -- actualiza el estado de las tarjetas inexistentes en el sistema
      --No se deberia dar x que todas las tarjetas son validas
      update ta_cobros
         set estado = 'E',
             observacion = 'Tarjeta inexistente',
             fec_proceso = v_fcdehoy,
             fec_valor = nvl(fec_valor, v_fcdehoy)
       where fec_proceso is null
         and estado is null;
      /*if op_cursor%rowcount = 0 then
         raise_application_error(-20000,'No existen datos a procesar.');
      end if;*/
      close op_cursor;
  end;
Begin
  v_fcdehoy       := pag_cal.fu_obt_fec_actual(5);
  v_hora          := to_char(sysdate,'HH24:MI:SS');
  v_nro_secuencia := 0;

  --Carga los debitos automaticos a realizar
  lp_car_deb_automaticos;
  --Marca cobrados anteriormente
  lp_mar_cobrados;
  --Proceso de debitos automaticos
  lp_pro_debitos;
End;
/

