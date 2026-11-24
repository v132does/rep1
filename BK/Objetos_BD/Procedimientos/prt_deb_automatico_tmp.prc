CREATE OR REPLACE PROCEDURE IT.PRT_DEB_AUTOMATICO_TMP
 (P_NRO_CTA_DEBITO IN TA_CTA_TARJETAS.NRO_CTA_DEBITO%TYPE DEFAULT NULL
 )
 IS
  v_pago_sueldo   varchar2(1) := 'N';
  v_estado        ge_movimientos.estado%type;
  v_obser         ta_cobros.observacion%type;
  v_hora          ge_movimientos.hora%type;
  v_fcdehoy       date;
 
  v_nro_secuencia ge_movimientos.nro_secuencia%type;

  v_cod_tra_padre ge_movimientos.cod_transaccion%type := 986;
  r_gmovi         ge_movimientos%rowtype;
  v_lugar         varchar2(1000);

  --- Datos para utilizar la cuenta de débito
  v_mto_deu_deb    ge_cuentas.sal_contable%type;
  v_mto_deu        ge_cuentas.sal_contable%type;
  v_cot_mon_tar    ge_cotizaciones.val_conversion%type;
  v_cot_mon_deb    ge_cotizaciones.val_conversion%type;
  v_nvo_estado     ge_cuentas.estado%type;
  v_sal_disponible ge_cuentas.sal_contable%type;
  v_cod_usuario    ba_usuarios.cod_usuario%type;
  v_lin_sobregiro  number;
  v_procesa        varchar2(01);
  --RI: 15/12/2010: Parametro creado para determinar si se procesa cuenta de nomina
  v_pro_cta_nomina varchar2(1) := nvl(fug_obt_pardinamico('PRO_CTA_NOMINA'),'S');

  --Carga los debitos automaticos a realizar
  procedure lp_car_deb_automaticos;
  --Marca cobrados anteriormente
  procedure lp_mar_cobrados;
  --Proceso de debitos automaticos
  procedure lp_pro_debitos;
  --Proceso de verificación de ejecución del proceso a nivel de ge_proceso
  procedure lp_ver_proceso;
  --Proceso de verificación de ejecución del proceso a nivel de sessiones
  procedure lp_ver_sesion;
  --Carga los debitos automaticos a realizar
  procedure lp_car_deb_automaticos is
  begin
       --por el vencimiento de pago
       insert into ta_cobros (nro_cta_debito,nro_tarjeta,monto,nro_cuenta,fec_proceso,estado,fec_valor)
       select nro_cta_debito, nro_tarjeta,nvl(sal_pag_minimo,0),tar.nro_cuenta,v_fcdehoy,'E',v_fcdehoy
         from ta_tarjetas  tar,
              ge_cta_clientes cli,
              ta_cta_tarjetas cta
        where cta.nro_cta_debito = nvl(p_nro_cta_debito,cta.nro_cta_debito)
          and tar.nro_cuenta = cli.nro_cuenta
          and cli.cod_persona = tar.cod_persona
          and vigente = 'N'
          and not exists (select 1 from ta_tarjetas t3 where t3.nro_cuenta = tar.nro_cuenta
                       and t3.cod_persona = tar.cod_persona
                       and t3.vigente ='S')
          and cta.nro_cuenta = tar.nro_cuenta
          and relacion = 'P'
          /* -- RI: 22/02/2010 : A pedido de A.Britez se saca esta condicion
             and ((v_pago_sueldo = 'N' and fec_vct_ult_cierre = v_fcdehoy) OR
               (v_pago_sueldo = 'S' and fec_vct_ult_cierre >= v_fcdehoy and fec_ult_cierre < v_fcdehoy)
               )*/
          and v_fcdehoy >= fec_vct_ult_cierre
          and deb_automatico = 'S'
          and nvl(sal_pag_minimo, 0) > 0
          /*RI: 15/12/2010: para que evalue si procesar o no cuentas de nomina */
          and (not exists (Select 1 from cc_cta_corrientes c
                           where c.nro_cuenta = cta.nro_cta_debito and c.cod_ente is not null
                             and v_pro_cta_nomina = 'N')
           or v_pro_cta_nomina = 'S')
          and (not exists(Select 1 from ah_cta_vistas c
                           where c.nro_cuenta = cta.nro_cta_debito and c.cod_ente is not null
                             and v_pro_cta_nomina = 'N')
           or v_pro_cta_nomina = 'S')
           and tar.nro_tarjeta = (select max(ta.nro_tarjeta) from ta_tarjetas ta 
                                   where ta.nro_cuenta=tar.nro_cuenta
                                     and ta.cod_persona=tar.cod_persona);

       -- morosos
       insert into ta_cobros (nro_cta_debito, nro_tarjeta, monto,nro_cuenta,fec_proceso,estado,fec_valor)
       select nro_cta_debito, nro_tarjeta,nvl(mto_mora,0),tar.nro_cuenta,v_fcdehoy,'E',v_fcdehoy
         from ta_tarjetas  tar,
              ge_cta_clientes cli,
              ta_cta_tarjetas cta
        where cta.nro_cta_debito = nvl(p_nro_cta_debito,cta.nro_cta_debito)
          and tar.nro_cuenta = cli.nro_cuenta
          and cli.cod_persona = tar.cod_persona
          and vigente = 'N'
          and not exists (select 1 from ta_tarjetas t3 where t3.nro_cuenta = tar.nro_cuenta
                       and t3.cod_persona = tar.cod_persona
                       and t3.vigente ='S')
          and cta.nro_cuenta = tar.nro_cuenta
          and relacion = 'P'
          and deb_automatico = 'S'
          and fec_vct_ult_cierre != v_fcdehoy
          and nvl(dia_mora,0) > 0
          and nvl(mto_mora, 0) > 0
          and not exists (select 0 from ta_cobros x
                           where x.nro_tarjeta = tar.nro_tarjeta
                             and x.fec_proceso = v_fcdehoy
                             and x.nro_cta_debito = cta.nro_cta_debito
                             and x.estado = 'E'
                             and x.observacion is null) -- JIRA 1557
          /*RI: 15/12/2010: para que evalue si procesar o no cuentas de nomina */
          and (not exists (Select 1 from cc_cta_corrientes c
                           where c.nro_cuenta = cta.nro_cta_debito and c.cod_ente is not null
                             and v_pro_cta_nomina = 'N')
           or v_pro_cta_nomina = 'S')
          and (not exists(Select 1 from ah_cta_vistas c
                           where c.nro_cuenta = cta.nro_cta_debito and c.cod_ente is not null
                             and v_pro_cta_nomina = 'N')
           or v_pro_cta_nomina = 'S')
           and tar.nro_tarjeta = (select max(ta.nro_tarjeta) from ta_tarjetas ta 
                                   where ta.nro_cuenta=tar.nro_cuenta
                                     and ta.cod_persona=tar.cod_persona);
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
        and nvl(fec_proceso,v_fcdehoy) = v_fcdehoy
        and a.nro_cta_debito = nvl(p_nro_cta_debito, a.nro_cta_debito); -- SDC - AP 641.
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
        and nvl(fec_proceso,v_fcdehoy) = v_fcdehoy
        and a.nro_cta_debito = nvl(p_nro_cta_debito, a.nro_cta_debito);  -- SDC - AP 641.
    end;
  --procesando debitos automaticos
  procedure lp_pro_debitos is
    cursor op_cursor is
    select cob.nro_cta_debito, cob.nro_tarjeta, cob.monto, cta.cod_modulo, cta.cod_moneda,
       cta.cod_modalidad, cta.nro_cuenta, cta.cod_oficina, cob.rowid fila
        from ta_cta_tarjetas cta,
             ta_tarjetas tar,
             ta_cobros cob
       where cob.nro_cta_debito = nvl(p_nro_cta_debito, cob.nro_cta_debito)
         and cob.fec_proceso    = v_fcdehoy
         and cob.estado         = 'E' 
         and cob.nro_tarjeta    = tar.nro_tarjeta
         and cob.nro_cuenta     = cta.nro_cuenta
         and cob.observacion    is null; -- JIRA 1557
    rg op_cursor%rowtype;

  begin
     IF nvl(pae_cnf.g_programa, 'X') = 'GPPROFIN' or nvl(pae_cnf.g_programa, 'X') = 'GPPAGSUE' THEN
      --cierre
        v_hora := fug_ini_hora(SYSDATE, 'HH24:MI:SS');
     ELSE
        v_hora := to_char(SYSDATE, 'HH24:MI:SS');
     END IF;
     if op_cursor%isopen then
        close op_cursor;
     end if;
      open op_cursor;
      loop
        fetch op_cursor into rg;
        exit when op_cursor%notfound;
        v_lugar := 'Tarjeta  : '||rg.nro_tarjeta;
        v_estado := 'P';
        v_obser := 'Registro procesado';
        v_hora  := pag_gen.fu_obt_sig_segundo(v_hora);
        if v_nro_secuencia > 990 then
           v_hora  := pag_gen.fu_obt_sig_segundo(v_hora);
           v_nro_Secuencia := 0;
        end if;
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

        --- Calculo el total a debitar en la moneda de la cuenta de debito
        v_cot_mon_tar := null;
        v_cot_mon_deb := null;
        v_mto_deu_deb := 0;
        v_mto_deu     := rg.monto;
        --
        v_mto_deu_deb := v_mto_deu;
        If rg.cod_moneda != pag_cta.g_ctas.cod_moneda then
          /* por ahora se anula esto para que no debite en moneda diferente */
          If fug_obt_tip_implementacion = 7 then
              v_estado    := 'E';
              v_obser := 'Cobro en diferentes monedas no permitido';
          Else
          /* Obtiene el monto en moneda Extranjera a Debitar */
              pag_gen.pr_con_mon_a_moneda(rg.cod_moneda, pag_cta.g_ctas.cod_moneda,
                                          v_mto_deu, v_mto_deu_deb,
                                          v_cot_mon_tar, v_cot_mon_deb);
          end if;
        End if;

        /* se comenta esto porque no fue pedido por el usuario, y no fue probado aún
        -- RI: 10/08/2010: se tiene en cuenta la linea de sobregiro
        v_lin_sobregiro := 0;
        if pag_cta.g_ctas.cod_modalidad = 41 then
           v_lin_sobregiro := nvl(pag_cta.FU_OBT_LIN_SOBREGIRO(rg.nro_cta_debito, v_fcdehoy),0);
        end if;
        -- RI: 10/08/2010: tener en cuenta tambien el saldo de la cuenta combinada
        if nvl(pag_cta.g_ctas.sal_disponible,0)+nvl(pag_cta.g_ctas.sal_dis_combinada,0)+v_lin_sobregiro
          < nvl(v_mto_deu_deb,0) and
           nvl(pag_cta.g_ctas.sal_disponible,0)+nvl(pag_cta.g_ctas.sal_dis_combinada,0)+v_lin_sobregiro > 0 then
           v_mto_deu_deb := nvl(pag_cta.g_ctas.sal_disponible,0)+nvl(pag_cta.g_ctas.sal_dis_combinada,0)+v_lin_sobregiro;
        */ -- hasta aquí se comenta

        if nvl(pag_cta.g_ctas.sal_disponible,0) < nvl(v_mto_deu_deb,0) and
           nvl(pag_cta.g_ctas.sal_disponible,0) > 0 then
           v_mto_deu_deb := nvl(pag_cta.g_ctas.sal_disponible,0);

          If rg.cod_moneda != pag_cta.g_ctas.cod_moneda then
             --
             v_cot_mon_tar := null;
             v_cot_mon_deb := null;
          /* Obtiene el monto en moneda local a Debitar por el Saldo Disponible de la Cuenta en moneda Extranjera */
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
            v_obser := substr(fug_obt_err_sueldos(pag_cta.g_cod_error),1,50);
          end if;
          if v_estado = 'P' then
            --- DEBITAR de la cuenta
            --v_nro_secuencia := v_nro_secuencia + 1;
            pag_cta.pr_act_operacion(rg.nro_cta_debito, v_hora, 'D', pag_cta.g_ctas.cod_moneda,
                                     v_mto_deu_deb, v_cod_tra_padre, 503, rg.nro_cuenta, v_cot_mon_deb,
                                     rg.cod_oficina, rg.cod_modulo, rg.cod_modalidad,
                                     null, null, 'Debito automatico de tarjetas ',
                                     'S', v_nro_secuencia , v_fcdehoy, null,null,v_mto_deu);
            if pag_cta.g_cod_error <> 0 then
              v_estado:= 'E';
              v_obser := substr(fug_obt_err_sueldos(pag_cta.g_cod_error),1,50);
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
          if v_nro_secuencia > 990 then
             v_hora  := pag_gen.fu_obt_sig_segundo(v_hora);
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
  --Proceso de verificación de ejecución del proceso a nivel de ge_proceso
  procedure lp_ver_proceso is
  begin
     select p.cod_usuario
       into v_cod_usuario
       from ge_procesos p, ge_procesos_det det
      where p.cod_proceso = det.cod_proceso
        and det.cod_programa = 'PRT_DEB_AUTOMATICO'
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
       and u.object_name = 'PRT_DEB_AUTOMATICO'
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
  v_fcdehoy       := pag_cal.fu_obt_fec_actual(5);
  v_hora          := to_char(sysdate,'HH24:MI:SS');
  v_nro_secuencia := 0;

  If nvl(pae_cnf.G_PROGRAMA,'X')  = 'GPPAGSUE' then
     -- Viene desde pago de Sueldos...
     v_pago_sueldo   := 'S';
     v_cod_tra_padre := 186;
     if pae_cnf.G_HORA is null then
       v_hora          := to_char(sysdate,'HH24:MI:SS');
       v_nro_secuencia := 0;
     else
       v_hora          := pae_cnf.G_HORA;
       v_nro_secuencia := nvl(pae_cnf.G_NRO_SECUENCIA,0) + 1;
        if v_nro_secuencia > 990 then
           v_hora  := pag_gen.fu_obt_sig_segundo(v_hora);
           v_nro_Secuencia := 0;
        end if;
     end if;
     --AP 2331 - Verifico que no se ejecute en simultáneo el Proceso Indep. con otro Usuario.
     lp_ver_proceso;
  else
     --AP 2331 - Verifico para que no se ejecute el procedimiento en simultáneo con el GPPAGSUE.
     lp_ver_sesion;
  end if;
  --Carga los debitos automaticos a realizar
  v_lugar := 'lp_car_deb_automaticos';
  lp_car_deb_automaticos;
  --Marca cobrados anteriormente
  v_lugar := 'lp_mar_cobrados';
  lp_mar_cobrados;
  --Proceso de debitos automaticos
  v_lugar := 'lp_pro_debitos';
  lp_pro_debitos;
  --- Asigno la secuencia a la Global...
  pae_cnf.G_NRO_SECUENCIA := v_nro_secuencia;
  pae_cnf.g_hora := v_hora;

EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE < -20000 THEN
        raise;
    ELSE
        raise_application_error(-20002,'Error : '||v_lugar||' '||sqlerrm);
    END IF;
END;
/

