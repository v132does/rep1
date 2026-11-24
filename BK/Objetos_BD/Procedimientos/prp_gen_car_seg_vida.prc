CREATE OR REPLACE PROCEDURE IT.PRP_GEN_CAR_SEG_VIDA IS
v_fec_actual      date := PAG_CAL.FU_OBT_FEC_ACTUAL(6);
-- Todos los préstamos vigente, con saldo de capital y seguro de vida--
Cursor c_prestamos is
 select distinct p.cod_modalidad, p.nro_cuenta , c.cod_transaccion, p.nro_solicitud
   from pr_sol_cargos c, pr_cta_prestamos p
  where p.estado not in('N', 'I') -- Prestamos vigentes, que no esten ni cancelados ni incobrables
    and nvl(p.sal_capital,0) > 0
    and c.nro_solicitud = p.nro_solicitud
    and c.cod_transaccion = 1521  -- Cargo x seg de vida en cuotas
    ------------------------------------------------------------
    --Proyecto SDSEGVID-3 Seguro de Vida Distribuido (1521)-----
    --Exclusion ctas c/seg. distr. son generadas de otra forma--
    ------------------------------------------------------------
    and not exists (select 1
                      from ba_tab_dat_adicionales x
                     where x.tab_relacion = 'PR_SOLICITUDES'
                       and x.parametro = 'PRE_IND_CUO_CAL_SEGURO'
                       and x.referencia = c.nro_solicitud
                       and x.val_parametro = 'S')
    and not exists (select 1
                      from pr_cta_gastos
                     where nro_cuenta = p.nro_cuenta
                       and cod_transaccion = c.cod_transaccion
                       and fec_ingreso = v_fec_actual)
    ------------------------------------------------------------
 union
 select distinct p.cod_modalidad, p.nro_cuenta, c.cod_Transaccion, p.nro_solicitud
   from pr_cta_gastos c, pr_cta_prestamos p
  where p.estado not in('N', 'I') -- Prestamos vigentes, que no esten ni cancelados ni incobrables
    and nvl(p.sal_capital,0) > 0
    and c.nro_cuenta = p.nro_cuenta
    and c.cod_Transaccion = 1521  -- Cargo x seg de vida en cuotas
    and not exists (select 1
                      from ba_tab_dat_adicionales x
                     where x.tab_relacion = 'PR_SOLICITUDES'
                       and x.parametro = 'PRE_IND_CUO_CAL_SEGURO'
                       and x.referencia = p.nro_solicitud
                       and x.val_parametro = 'S')
    and not exists (select 1 
                      from pr_sol_cargos y
                     where y.nro_solicitud = p.nro_solicitud
                       and y.cod_transaccion = 736)
    and not exists (select 1
                      from pr_cta_gastos
                     where nro_cuenta = p.nro_cuenta
                       and cod_transaccion = c.cod_transaccion
                       and fec_ingreso = v_fec_actual); --Ya cobro en desembolso--

--
v_importe         ge_movimientos.monto%type;
v_nro_comprobante ge_movimientos.nro_documento3%type;
v_imp_cuota       number;
v_tot_cargo       number;
v_imp_restante    number;
v_fec_vto         date;
v_redondeo_ml     number(2) := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', 6, null, pag_gen.fu_obt_mon_local);
v_redondeo        number;

v_nro_secuencia   ge_movimientos.nro_secuencia%type := 0;
v_hora            ge_movimientos.hora%type := to_char(sysdate,'hh24:mi:ss');
v_cod_usuario     ge_movimientos.cod_usuario%type := user;
v_cod_mon_local   ge_movimientos.cod_moneda%type  := pag_gen.fu_obt_mon_local;
v_cotizacion      ge_movimientos.cotizacion%type;
v_cta_cre         ge_movimientos.nro_cuenta%type;
v_tas_prima       ge_movimientos.cod_tasa%type;
v_val_Tasa        ge_movimientos.val_tasa%type;
v_val_tas_prima   ge_movimientos.val_tasa%type;
v_ent_seguro      ge_entes.cod_ente%type;
v_cod_persona     ba_personas.cod_persona%type;
v_cod_ofi_origen  ba_usuarios.cod_oficina%type := FUG_OBT_OFI_USUARIO(USER);
v_cod_tas_seg_vida ge_movimientos.cod_tasa%type;
v_lugar           varchar2(100);
v_cod_tra_movimiento ge_transacciones.cod_transaccion%type;
-- Variables de registro
r_pcpre           pr_cta_prestamos%rowtype;
r_gmovi           ge_movimientos%rowtype;

v_cod_rubro       cb_rubros.cod_rubro%type;
v_cod_mon_rubro   cb_rubros.cod_moneda%type;

v_fec_vigencia date;
v_tip_valor ge_tasas.tip_valor%type;
v_tipo ge_tasas.tipo%type;

rg_calend        ge_calendarios%rowtype := pag_cal.fu_obt_reg_cal(6); ---DYDMR-7487 - 19/10/2017
 ---
 v_fre_proceso VARCHAR2(1) := fug_obt_fre_proceso('PRP_GEN_CAR_SEG_VIDA');
 v_db_prod     VARCHAR2(1) := fug_ind_produccion;
 v_val_exo_cargo ge_movimientos.val_tasa%type;
 v_val_tas_exo   ge_movimientos.val_tasa%type;
 --- DYDMR-7487 - 19/10/2017
 v_fec_control      ge_calendarios.fec_actual%type;
 ---
 v_error            ge_pro_programas_log.mensaje%type;
 v_cant_err_maximo  number := nvl(to_number(fug_obt_pardinamico('CAN_ERR_MAX_SEG_VIDA')),5);
 v_cont_errores     number := 0;
--------------------------------------------------------------------------------------------
function Fu_redondear_centena(p_importe in number)  return number is
v_imp number;
v_imp_cen number;

begin
  if  p_importe/100 = trunc(p_importe/100) then  -- esta bien
    v_imp_cen := p_importe;
  else
    v_imp := round(p_importe / 100);
    v_imp_cen := v_imp * 100;
    loop
      if v_imp_cen >= p_importe then
        exit;
      end if;
      v_imp_cen := v_imp_Cen + 100;
    end loop;
  End if;
  return v_imp_Cen;
END;

--------------------------------------------------------------------------------------------
--  EMPIEZA EL PROCEDIMIENTO
--------------------------------------------------------------------------------------------

BEGIN
  ----- DYDMR-7487 - 19/10/2017 ---
  v_fec_control := v_fec_actual;
  if v_fec_actual = rg_calend.ult_dia_mes_habil then
     v_fec_control := RG_CALEND.ULT_DIA_MES;
  END IF;
 ---------------------------------
    begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 6; end;
    v_hora := fug_obt_hor_disponible(v_fec_actual,v_hora,user,'N');
    For reg in c_prestamos loop
      BEGIN
        r_gmovi := null;  --Inicializar registro movimiento
        v_lugar := 'Cta.: '||reg.nro_cuenta;
        
        --Traer los datos del prestamo
        pap_pre.pr_obt_dat_prestamo(reg.nro_cuenta, r_pcpre);
        -- Trae el codigo del ente que corresponde a la propuesta
        begin
           select t.cod_ent_seguro
           into v_ent_seguro
           from pr_sol_cargos t
           where t.nro_solicitud = reg.nro_solicitud
            and t.cod_transaccion = 1521;
         exception
        when no_data_found then
           v_ent_seguro := FUG_OBT_ENT_SEGURO(6, reg.cod_modalidad, 'V');
            when others then
                 raise_application_error(-20000,
                      'No encuentra código de Aseguradora. Verifique Solicitud '||reg.nro_solicitud);
          end;
        --Traer el monto del seguro de vida
        v_imp_cuota := pap_pre.fu_obt_mto_seg_vida(reg.nro_solicitud, reg.cod_modalidad, r_pcpre.sal_capital, null, r_pcpre.fec_inicio, r_pcpre.fec_vencimiento,v_val_tasa);
        v_cod_tas_seg_vida := fug_obt_parentes(v_ent_seguro,'COD_TAS_SEG_VIDA');

        -- Redondeo
        v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', r_pcpre.cod_modulo, r_pcpre.cod_modalidad, r_pcpre.cod_moneda, r_pcpre.cod_oficina);
        --Traer el codigo de persona
        Begin
          v_cod_persona := fug_obt_cli_principal(reg.nro_cuenta);
        Exception
          when others then
             v_cod_persona := null;
        end;
        -- Traer la fecha de vencimiento de la cuota mas vencida pendiente de pago
        Begin
          Select min(fec_vencimiento) into v_fec_vto
            from pr_cuotas
           where nro_cuenta = reg.nro_cuenta
             and fec_vencimiento > v_fec_control
             and estado <> 'N'
             and nro_cuota > 0;-- DYDMR-7487 - 19/10/2017
          --RI: 01/09/2010: Si la minima cuota esta vencida, asignar esa fecha de vto.
          If v_fec_vto is null then
            Select min(fec_vencimiento) into v_fec_vto
              from pr_cuotas
             where nro_cuenta = reg.nro_cuenta
               and estado <> 'N'
               and nro_cuota > 0;-- DYDMR-7487 - 19/10/2017
          End if;
        Exception
           when others then
             raise_application_error(-20000, 'Error en Generar Mov. Seguro al traer fecha de vencimiento de cuota. '||pag_cta.fu_obt_cod_error()||  ' - '|| pag_cta.fu_obt_msj_error());
        End;
        --
        --Traer valor de la tasa de prima seguro vida.
        v_tas_prima := fug_obt_parentes(v_ent_seguro, 'COD_TAS_PRI_ASE_VIDA');
        if v_tas_prima is not null then
         PAG_GEN.PR_OBT_VAL_TASA(r_pcpre.cod_modulo,r_pcpre.cod_modalidad,r_pcpre.cod_oficina,
                     r_pcpre.nro_cuenta,  r_pcpre.cod_moneda, (r_pcpre.fec_vencimiento-r_pcpre.fec_inicio),
                     'N', v_tas_prima,  NULL, r_pcpre.fec_inicio, v_val_tas_prima,v_fec_vigencia,
                     v_tip_valor, v_tipo);
          if v_val_tas_prima is null then
            raise_application_error(-20000,'No encuentra valor de la tasa del seguro de vida. Verifique');
          end if;
        else
          raise_application_error(-20000,'No encuentra código de la tasa del seguro de vida. Verifique');
        end if;
         /*
         || PCC-Exoneración y Extorno de Comisiones y Tasas
         || Se ejecuta si el proceso no es mensual
         || o la base de datos no es producción
         */
         IF v_fre_proceso <> 'M' OR v_db_prod = 'N' THEN
            -- busco el valor de la tasa
            begin
              v_val_exo_cargo := pap_pre.fu_obt_mto_seg_vida(reg.nro_solicitud,
                                                             reg.cod_modalidad,
                                                             r_pcpre.sal_capital, null,
                                                             r_pcpre.fec_inicio,
                                                             r_pcpre.fec_vencimiento,
                                                             v_val_tas_exo);

            exception
               when others then
                  raise_application_error(-20000,'Al Obt.Val.Tasa:'||sqlerrm);
            end;
            if pag_cta.fu_ver_tra_prohibida(r_pcpre.nro_cuenta,
                                            reg.cod_transaccion,
                                            r_pcpre.cod_modulo,
                                            r_pcpre.cod_modalidad) = 'S' then
               prg_ins_exoneracion(reg.cod_transaccion, r_pcpre.cod_modulo,
                                   r_pcpre.cod_modalidad, r_pcpre.cod_moneda,
                                   r_pcpre.nro_cuenta, null, v_tas_prima,
                                   nvl(v_val_exo_cargo, 0),
                                   nvl(v_val_exo_cargo, 0), null,
                                   nvl(v_val_exo_cargo, 0));
            elsif (nvl(v_imp_cuota, 0) <> nvl(v_val_exo_cargo, 0)) or
                  (nvl(v_imp_cuota, 0) = 0 and nvl(v_val_exo_cargo, 0) <> 0)then
               prg_ins_exoneracion(reg.cod_transaccion, r_pcpre.cod_modulo,
                                   r_pcpre.cod_modalidad, r_pcpre.cod_moneda,
                                   r_pcpre.nro_cuenta, null, v_tas_prima,
                                   (nvl(v_val_exo_cargo, 0) - nvl(v_imp_cuota, 0)),
                                    v_val_exo_cargo, null,
                                   (nvl(v_val_exo_cargo, 0) - nvl(v_imp_cuota, 0)));
            end if;
         end if;
         ---
        Insert into Pr_cta_gastos
          (Nro_cuenta, Cod_transaccion, cod_moneda, Monto, Fec_ingreso,
           Fec_ini_vigencia, Fec_vencimiento, Cod_modalidad, cod_modulo, nro_solicitud,
           cod_tas_ref1, val_tas_ref1, cod_tas_ref2, val_tas_ref2)
        Values
          (r_pcpre.nro_cuenta, reg.cod_transaccion, r_pcpre.cod_moneda, v_imp_cuota, v_Fec_actual,
           v_fec_vto, null, r_pcpre.cod_modalidad, r_pcpre.cod_modulo,r_pcpre.nro_solicitud,
           v_cod_tas_seg_vida, v_val_tasa, v_tas_prima, v_val_tas_prima);

        -------------------------------------------------------------------------------------------------
        --2  ESTA PARTE ES PARA GENERAR LOS MOVIMIENTOS QUE CORRESPONDEN POR LOS CARGOS Y EL CREDITO EN LA
        --   CUENTA DE LA PROCESADORA
        -------------------------------------------------------------------------------------------------
        /*
        -- Generar el movimiento por el total del cargo por seguro
        */
        v_nro_secuencia := v_nro_secuencia + 1;

        --sig segundo x si hay mas de 999 reg.
        if v_nro_secuencia >= 990/*995*/ then --se baja la secuencia DYDMR-12209
           --v_hora := PAG_GEN.FU_OBT_SIG_SEGUNDO(v_hora);
           v_hora := fug_obt_hor_disponible(v_fec_actual,v_hora,user,'N');
           v_nro_secuencia := 1;
        end if;

        r_gmovi.nro_secuencia      := v_nro_secuencia;
        r_gmovi.cod_usuario        := v_cod_usuario;
        r_gmovi.hora               := v_hora;
        r_gmovi.fecha              := v_fec_actual;
        r_gmovi.cod_modulo         := r_pcpre.cod_modulo;
        r_gmovi.cod_modalidad      := r_pcpre.cod_modalidad;
        r_gmovi.cod_oficina        := r_pcpre.cod_oficina;
        r_gmovi.nro_cuenta         := null;
        r_gmovi.cod_moneda         := r_pcpre.cod_moneda;
        r_gmovi.est_cuenta         := null;
        r_gmovi.cod_tra_padre      := 371;  -- Cargos por seguro en cuotas
        r_gmovi.cod_transaccion    := 1526;  -- Debito por cargo de seguros a cuenta en suspenso
        r_gmovi.concepto           := 'Cargos por Seguro de Vida';
        r_gmovi.monto              := v_imp_cuota;
        if r_pcpre.cod_moneda <> v_cod_mon_local then
           v_cotizacion               := pag_gen.fu_obt_cotizacion(r_pcpre.cod_moneda, v_fec_actual);
           r_gmovi.cotizacion         := v_cotizacion;
           r_gmovi.mto_equ_local      := round(trunc(v_imp_cuota,2)*v_cotizacion,v_redondeo_ml);
        else
           v_cotizacion               := null;
           r_gmovi.cotizacion         := null;
           r_gmovi.mto_equ_local      := null;
        end if;
        r_gmovi.fec_valor          := v_fec_actual;
        r_gmovi.emi_aviso          := 'N';
        r_gmovi.reversado          := 'N';
        r_gmovi.protegido          := 'N';
        r_gmovi.estado             := 'N';
        r_gmovi.cod_ofi_origen     := v_cod_ofi_origen;
        r_gmovi.cod_mod_padre      := r_pcpre.cod_modulo;
        r_gmovi.cod_mad_padre      := r_pcpre.cod_modalidad;
        r_gmovi.referencia         := r_pcpre.nro_cuenta; --RI: 01/09/10
        r_gmovi.val_tasa           := v_val_Tasa;
        r_gmovi.cod_persona        := v_cod_persona;
        pag_gen.pr_ins_ge_movimiento(r_gmovi);
        /*
        -- Esta parte corresponde al credito del monto a pagar a la Aseguradora en su cuenta
        --*/
        begin
            v_cta_cre := null;
            if fug_obt_tip_ente(v_ent_seguro) = 'SE' then
              if r_pcpre.cod_moneda = v_cod_mon_local then
                 v_cta_cre := fug_obt_parentes(v_ent_seguro, 'NRO_CTA_SEG_MON_LOCAL');
                 v_cod_rubro := fug_obt_parentes(v_ent_seguro, 'COD_RUB_MON_LOCAL');
              else
                 v_cta_cre := fug_obt_parentes(v_ent_seguro, 'NRO_CTA_SEG_MON_FUERTE');
                 v_cod_rubro := fug_obt_parentes(v_ent_seguro, 'COD_RUB_MON_FUERTE');
              end if;
            else
               v_cta_cre := fug_obt_parentes(v_ent_seguro, 'NRO_CTA_ESCRIBANIA');
            end if;
        exception
            when others then v_cta_cre := null;
        end;

        --Si en los Parámetros del Ente esta configurado un Rubro Contable se realiza el Crédito a este Rubro
        if v_cod_rubro is not null then
          v_cod_mon_rubro := pag_sue.fu_obt_mon_rubro(v_cod_rubro);

           v_tot_cargo := v_imp_cuota;

           --Hacer el calculo por la porcion que le corresponde a la aseguradora
           v_importe := round(r_pcpre.sal_capital * v_val_tas_prima / 100,v_redondeo);

           if r_pcpre.cod_moneda <> v_cod_mon_rubro then
              v_importe := pag_gen.FU_CON_MON_A_MONEDA(r_pcpre.cod_moneda,v_cod_mon_rubro,v_importe, v_cotizacion);
           else
              v_importe := round(v_importe,v_redondeo);
           end if;

        --ITGF - Diferencias en Saldos de Inventario y Saldos Contables en el Rubro Seguro de Vida por Cobrar -SC 13187
        /* if r_pcpre.cod_moneda = v_cod_mon_local
           and v_importe > 100 then
             v_importe := Fu_redondear_centena(v_importe);
         end if;*/
           v_imp_restante := v_tot_cargo - v_importe;


           --Hacer el Crédito a la Cuenta Contable
           v_nro_secuencia            := v_nro_secuencia + 1;
           r_gmovi.nro_secuencia      := v_nro_secuencia;
           r_gmovi.cod_usuario        := v_cod_usuario;
           r_gmovi.hora               := v_hora;
           r_gmovi.fecha              := v_fec_actual;
           r_gmovi.cod_modulo         := r_pcpre.cod_modulo;
           r_gmovi.cod_modalidad      := r_pcpre.cod_modalidad;
           r_gmovi.cod_oficina        := r_pcpre.cod_oficina;
           r_gmovi.nro_cuenta         := null;
           r_gmovi.cod_moneda         := r_pcpre.cod_moneda;
           r_gmovi.est_cuenta         := null;
           r_gmovi.cod_tra_padre      := 371;
           r_gmovi.cod_transaccion    := null;
           r_gmovi.concepto           := 'Credito por Cargos de Seguro '||r_pcpre.nro_cuenta;
           r_gmovi.monto              := v_importe;
           if r_pcpre.cod_moneda <> v_cod_mon_local then
              v_cotizacion               := pag_gen.fu_obt_cotizacion(r_pcpre.cod_moneda, v_fec_actual);
              r_gmovi.cotizacion         := v_cotizacion;
              r_gmovi.mto_equ_local      := round(trunc(v_importe,2)*v_cotizacion,v_redondeo_ml);
           else
              v_cotizacion               := null;
              r_gmovi.cotizacion         := null;
              r_gmovi.mto_equ_local      := null;
           end if;
           r_gmovi.fec_valor          := v_fec_actual;
           r_gmovi.emi_aviso          := 'N';
           r_gmovi.reversado          := 'N';
           r_gmovi.protegido          := 'N';
           r_gmovi.estado             := 'N';
           r_gmovi.cod_ofi_origen     := v_cod_ofi_origen;
           r_gmovi.cod_mod_padre      := r_pcpre.cod_modulo;
           r_gmovi.cod_mad_padre      := r_pcpre.cod_modalidad;
           --r_gmovi.nro_documento      := r_pcpre.nro_cuenta;
           r_gmovi.referencia         := r_pcpre.nro_cuenta;  --RI: 01/09/10
           r_gmovi.cod_rubro          := v_cod_rubro;
           r_gmovi.tip_mov_rubro      := 'C';  --Tipo de Movimiento Crédito
           r_gmovi.val_tasa           := v_val_tas_prima;
           pag_gen.pr_ins_ge_movimiento(r_gmovi);

        elsif v_cta_cre is not null then
           -- Traigo datos de la cuenta de la aseuguradora
           pag_cta.PR_OBT_CUENTA(v_cta_cre);

           v_tot_cargo := v_imp_cuota;

           -- Hacer el calculo por la porcion que le corresponde a la aseguradora
           v_importe := round(r_pcpre.sal_capital * v_val_tas_prima / 100,v_redondeo);

           if r_pcpre.cod_moneda <> pag_cta.G_CTAS.cod_moneda then
              v_importe := pag_gen.FU_CON_MON_A_MONEDA(r_pcpre.cod_moneda,pag_cta.G_CTAS.cod_moneda,v_importe, v_cotizacion);
           else
              v_importe := round(v_importe,v_redondeo);
           end if;

         --ITGF - Diferencias en Saldos de Inventario y Saldos Contables en el Rubro Seguro de Vida por Cobrar -SC 13187
         /*If r_pcpre.cod_moneda = v_cod_mon_local
           and v_importe > 100 then
              v_importe := Fu_redondear_centena(v_importe);
         end if;*/
           v_imp_restante := v_tot_cargo - v_importe;

           -- ENE/2017 OMM DYDMR-4907 Solo genera movimiento si el importe es mayor a cero
           IF nvl(v_importe,0) > 0 then
               --- Acreditar a cuenta de ahorro
               pag_cta.pr_act_operacion(v_cta_cre,
                            v_hora,--HORA
                            'C',
                            pag_cta.g_ctas.cod_moneda,      --Moneda de la Operacion
                            v_importe,
                           371,  -- COD_TRA_PADRE (Cargos por Seguros)
                            602,  -- COD_TRA_HIJO (602)
                           null,
                            v_cotizacion,  --COTIZACION
                            v_cod_ofi_origen,      --cod_ofi_origen
                            r_pcpre.cod_modulo,     --cod_mod_padre
                           r_pcpre.cod_modalidad,  --cod_mad_padre
                           null,                       --cod_tasa
                           v_val_tas_prima,            --val_tasa
                              'Credito por Cargos de Seguro '||r_pcpre.nro_cuenta,
                           'S',                        --emi_aviso
                           v_nro_secuencia,
                           v_Fec_actual);

               if pag_cta.fu_obt_cod_error() <> 0 then
                   raise_application_error(-20000, 'Acr.Seguro '||pag_cta.fu_obt_cod_error()||  ' - '|| pag_cta.fu_obt_msj_error());
               Else
                   --- Graba el numero de comprobante para que pueda imprimir...
                   If fug_obt_tip_implementacion in (1,7) then
                     select s_nro_debito.nextval into v_nro_comprobante from dual;
                     ---
                     update ge_movimientos
                       set nro_documento3 = v_nro_comprobante,
                           referencia     = r_pcpre.nro_cuenta --RI: 01/09/10
                     where hora = v_hora
                       and cod_usuario = user
                       and cod_tra_padre = 371
                       and concepto = 'Credito por Cargos de Seguro '||r_pcpre.nro_cuenta;
                  End If;
               end if;
           end if ;
        else
           -- no existe cuenta de seguro
           raise_application_error(-20000,'Cuenta de Credito del Seguro o Escribania no definida. Verifique');
        end if;
         if v_imp_restante < 0 then
           v_cod_tra_movimiento := fug_obt_parentes(v_ent_seguro, 'COD_TRA_MOV_DEB_VIDA');
         elsif v_imp_restante > 0 then
           v_cod_tra_movimiento := fug_obt_parentes(v_ent_seguro, 'COD_TRA_MOV_CRE_VIDA');
         end if;
        if nvl(abs(v_imp_restante),0) > 0 then
          /*
          -- Grabar el movimiento por la porcion restante
          */
          v_nro_secuencia := v_nro_secuencia + 1;
          r_gmovi.nro_secuencia      := v_nro_secuencia;
          r_gmovi.cod_usuario        := v_cod_usuario;
          r_gmovi.hora               := v_hora;
          r_gmovi.fecha              := v_fec_actual;
          r_gmovi.cod_modulo         := r_pcpre.cod_modulo;
          r_gmovi.cod_modalidad      := r_pcpre.cod_modalidad;
          r_gmovi.cod_oficina        := r_pcpre.cod_oficina;
          r_gmovi.nro_cuenta         := null;
          r_gmovi.cod_moneda         := r_pcpre.cod_moneda;
          r_gmovi.est_cuenta         := null;
          r_gmovi.cod_tra_padre      := 371;
          r_gmovi.cod_transaccion    := v_cod_tra_movimiento; --1634;
          r_gmovi.concepto           := 'Cargos por Diferencia Comisión - Prima Seguro de Vida';
          r_gmovi.monto              := abs(v_imp_restante);
          if r_pcpre.cod_moneda <> v_cod_mon_local then
             v_cotizacion               := pag_gen.fu_obt_cotizacion(r_pcpre.cod_moneda, v_fec_actual);
             r_gmovi.cotizacion         := v_cotizacion;
             r_gmovi.mto_equ_local      := round(trunc(abs(v_imp_restante),2)*v_cotizacion,v_redondeo_ml);
          else
             v_cotizacion               := null;
             r_gmovi.cotizacion         := null;
             r_gmovi.mto_equ_local      := null;
          end if;
          r_gmovi.fec_valor          := v_fec_actual;
          r_gmovi.emi_aviso          := 'N';
          r_gmovi.reversado          := 'N';
          r_gmovi.protegido          := 'N';
          r_gmovi.estado             := 'N';
          r_gmovi.cod_ofi_origen     := v_cod_ofi_origen;
          r_gmovi.cod_mod_padre      := r_pcpre.cod_modulo;
          r_gmovi.cod_mad_padre      := r_pcpre.cod_modalidad;
          --r_gmovi.nro_documento      := r_pcpre.nro_cuenta;
          r_gmovi.referencia         := r_pcpre.nro_cuenta; --RI: 01-09/10
          r_gmovi.val_tasa           := null;
          r_gmovi.cod_rubro          := null;
          r_gmovi.tip_mov_rubro      := null;
          r_gmovi.cod_persona        := v_cod_persona;
          pag_gen.pr_ins_ge_movimiento(r_gmovi);
        end if;
         
        commit;
       EXCEPTION
         WHEN OTHERS THEN
           v_cont_errores := v_cont_errores +1;
           --Control de cantidad de errores: si es mayor al parametrizado debe lanzar error
           IF v_cont_errores < v_cant_err_maximo THEN
             ROLLBACK;
             v_error := 'Error en Cta ' || reg.nro_cuenta ||' fecha '|| v_fec_actual ||' hora '|| TO_CHAR(SYSDATE, 'hh24:mi:ss') ||' error '||SUBSTR(SQLERRM, 1, 250);
             pag_cie.PR_INS_LOG(v_error, pag_cie.c_log_ERROR, 'AUTONOMOUS_TRANSACTION');
           ELSE
             ROLLBACK;
             v_error := 'Error en Cta ' || reg.nro_cuenta ||' fecha '|| v_fec_actual ||' hora '|| TO_CHAR(SYSDATE, 'hh24:mi:ss') ||' error '||SUBSTR(SQLERRM, 1, 250);
             pag_cie.PR_INS_LOG(v_error, pag_cie.c_log_ERROR, 'AUTONOMOUS_TRANSACTION');
             raise_application_error(-20000, 'El proceso superó el límite de errores. '||' Error en Cta ' || reg.nro_cuenta ||' fecha '|| v_fec_actual ||' hora '|| TO_CHAR(SYSDATE, 'hh24:mi:ss') ||' error '||SUBSTR(SQLERRM, 1, 250));
           END IF;
       END;
       --- Siguiente registro
       <<siguiente_registro>>
       null;
    End loop;
  --END IF;
Exception
  WHEN OTHERS THEN
     raise_application_error(-20000, 'Error al generar cargos por seguro de Vidas.'||' - '||v_lugar||' Error : '||sqlerrm);
END;
/
