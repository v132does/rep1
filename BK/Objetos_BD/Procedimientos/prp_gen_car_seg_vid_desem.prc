CREATE OR REPLACE PROCEDURE IT.PRP_GEN_CAR_SEG_VID_DESEM IS

-----------------------------------------------------------
--Proyecto SDSEGVID-3 Seguro de Vida Distribuido (1521)----
--Generacion cargo de Seguro de Vida en desembolso---------
-----------------------------------------------------------

-- Todos los préstamos vigente, con saldo de capital y seguro de vida
Cursor c_prestamos is
 select distinct c.cod_tra_padre,
                c.cod_modalidad,
                c.nro_cuenta,
                c.cod_Transaccion,
                c.nro_documento nro_solicitud, b.cod_persona,
                a.cod_modulo, a.cod_moneda, a.cod_oficina, a.fec_inicio, a.fec_vencimiento, a.mto_capital,
                c.monto, c.fecha, c.hora, c.cod_usuario, c.nro_secuencia, c.cod_ofi_origen
  from ge_movimientos c, pr_cta_prestamos a, pr_solicitudes b
 where c.estado in ('N') -- Prestamos vigentes, que no esten ni cancelados ni incobrables
   and c.cod_tra_padre = 358
   and c.reversado = 'N'
   and c.cod_Transaccion = 1521 -- Cargo x seg de vida en cuotas
   and a.nro_cuenta = c.nro_cuenta
   and b.nro_solicitud = a.nro_solicitud
   and exists (select 1
                 from ba_tab_dat_adicionales x
                where x.tab_relacion = 'PR_SOLICITUDES'
                  and x.parametro = 'PRE_IND_CUO_CAL_SEGURO'
                  and x.referencia = b.nro_solicitud
                  and x.val_parametro = 'S')
    --Que no haya sido generado antes--
    and not exists (select 1 from pr_cta_gas_seguros z
                     where z.nro_solicitud = b.nro_solicitud
                       and z.nro_cuota = 0
                       and z.estado = 'G');
--
v_importe         ge_movimientos.monto%type;
v_imp_cuota       number;
v_tot_cargo       number;
v_imp_restante    number;
v_fec_vto         date;
v_redondeo_ml     number(2) := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', 6, null, pag_gen.fu_obt_mon_local);
v_redondeo        number;
v_fec_actual      date :=PAG_CAL.FU_OBT_FEC_ACTUAL(6);
v_fec_anterior    date;
v_nro_secuencia   ge_movimientos.nro_secuencia%type := 0;
v_hora            ge_movimientos.hora%type := to_char(sysdate,'hh24:mi:ss');
v_cod_usuario     ge_movimientos.cod_usuario%type;
v_cod_mon_local   ge_movimientos.cod_moneda%type  := pag_gen.fu_obt_mon_local;
v_cotizacion      ge_movimientos.cotizacion%type;
v_cta_cre         ge_movimientos.nro_cuenta%type;
v_tas_prima       ge_movimientos.cod_tasa%type;
v_val_Tasa        ge_movimientos.val_tasa%type;
v_val_Tas_iva     ge_movimientos.val_tasa%type;
v_val_tas_prima   ge_movimientos.val_tasa%type;
v_ent_seguro      ge_entes.cod_ente%type;
v_cod_persona     ba_personas.cod_persona%type;
v_cod_ofi_origen  ba_usuarios.cod_oficina%type;
v_cod_tas_seg_vida ge_movimientos.cod_tasa%type;
v_tip_tas_seg_vida ge_tasas.tipo%type;
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

---
v_mto_car_dis_seguro     number(18,2);
v_mto_car_dis_banco      number(18,2);
v_mto_car_dis_iva_banco  number(18,2);
v_mto_car_dis_iva_seguro number(18,2);

v_cod_tasa ge_tasas.cod_tasa%type;
v_cargo_iva number(18,2);

rg_calend        ge_calendarios%rowtype := pag_cal.fu_obt_reg_cal(6); ---DYDMR-7487 - 19/10/2017
v_fec_control      ge_calendarios.fec_actual%type;
v_cod_ref_gasto  pr_cta_gastos.cod_ref_gasto%type;
v_cod_tra_padre  ge_transacciones.cod_transaccion%type;

--------------------------------------------------------------------------------------------
--  EMPIEZA EL PROCEDIMIENTO
--------------------------------------------------------------------------------------------

BEGIN
   begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 6; end;
   v_fec_anterior := fug_obt_fec_anterior(6);
   v_fec_control := v_fec_actual;
   if v_fec_actual = rg_calend.ult_dia_mes_habil then
      v_fec_control := RG_CALEND.ULT_DIA_MES;
   END IF;

    For reg in c_prestamos loop
      r_gmovi := null;  --Inicializar registro movimiento
      v_mto_car_dis_seguro     := 0;
      v_mto_car_dis_banco      := 0;
      v_mto_car_dis_iva_banco  := 0;
      v_mto_car_dis_iva_seguro := 0;
      v_cod_ref_gasto := null;
      v_lugar := 'Cta.: '||reg.nro_cuenta;
      --Agregado p/ generar misma hora y usuario del desembolso - DYDMR-12001--
      v_cod_tra_padre  := reg.cod_tra_padre; --Transaccion de Desembolso--
      v_cod_usuario    := reg.cod_usuario;
      v_hora           := reg.hora;
      v_cod_ofi_origen := reg.cod_ofi_origen;
      --Traer el maximo nro de secuencia del movimiento--
      select max(x.nro_secuencia)
        into v_nro_secuencia
        from ge_movimientos x
       where x.fecha = reg.fecha
         and x.hora = reg.hora
         and x.cod_usuario = reg.cod_usuario;
      ---------------------------------------------------
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
      v_imp_cuota := reg.monto;

      --Verificacion de la Tasas de la transaccion 1521--
      begin
        select b.tipo
          into v_tip_tas_seg_vida
          from ge_transacciones a, ge_tasas b
         where a.cod_transaccion = reg.cod_transaccion --1521--
           and a.cod_modulo = reg.cod_modulo
           and a.cod_modalidad = reg.cod_modalidad
           and b.cod_tasa = a.cod_tasa;
      exception
        when no_data_found then
             raise_application_error(-20000, 'Error. No existe tasa definida para tran 1521.'||sqlerrm);
        when others then
             raise_application_error(-20000, 'Error. En traer tipo de tasa tran 1521.'||sqlerrm);
      end;
      if v_tip_tas_seg_vida = 'F' then
         v_cod_tas_seg_vida := fug_obt_parentes(v_ent_seguro,'COD_TAS_SEG_VIDA');
      else
         v_cod_tas_seg_vida := fug_obt_parentes(v_ent_seguro,'COD_TAS_SEGURO');
      end if;
      if v_cod_tas_seg_vida is not null then
         if v_tip_tas_seg_vida = 'F' then
            v_val_tasa := fug_obt_valtas_rango(v_cod_tas_seg_vida, reg.COD_MODULO, reg.COD_MODALIDAD,
                           reg.cod_moneda, reg.cod_oficina, NULL,
                           reg.fec_inicio);
         else
            v_val_tasa := fug_obt_valtas_rango(v_cod_tas_seg_vida, reg.COD_MODULO, reg.COD_MODALIDAD,
                           reg.cod_moneda, reg.cod_oficina, reg.mto_capital,
                           reg.fec_inicio);
            v_val_tasa := fug_obt_valtas_rango(v_val_tasa, reg.COD_MODULO, reg.COD_MODALIDAD,
                           reg.cod_moneda, reg.cod_oficina, reg.fec_vencimiento - reg.fec_inicio,
                           reg.fec_inicio);
        end if;
        if v_val_tasa is null then
          raise_application_error(-20000,'No encuentra valor de la tasa del seguro de vida. Verifique');
        end if;
      else
        raise_application_error(-20000,'No encuentra código de la tasa del seguro de vida. Verifique');
      end if;

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
       --Obtener codigo de referencia de gasto--
       Select S_COD_REF_GASTO.NEXTVAL
         into v_cod_ref_gasto
         from dual;

       --Inserta pr_cta_gastos--
       Insert into Pr_cta_gastos
        (Nro_cuenta, Cod_transaccion, cod_moneda, Monto, Fec_ingreso,
         Fec_ini_vigencia, Fec_vencimiento, Cod_modalidad, cod_modulo, nro_solicitud,
         cod_tas_ref1, val_tas_ref1, cod_tas_ref2, val_tas_ref2, fec_ult_pago, hor_ult_pago,
         cod_ref_gasto)
      Values
        (r_pcpre.nro_cuenta, reg.cod_transaccion, r_pcpre.cod_moneda, v_imp_cuota, v_fec_anterior,
         v_fec_vto, v_fec_actual, r_pcpre.cod_modalidad, r_pcpre.cod_modulo,r_pcpre.nro_solicitud,
         v_cod_tas_seg_vida, v_val_tasa, v_tas_prima, v_val_tas_prima, v_fec_actual, v_hora,
         v_cod_ref_gasto);

      -- Generar el movimiento por el total del cargo por seguro
      v_nro_secuencia := v_nro_secuencia + 1;
      if v_nro_secuencia >= 995 then
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
      r_gmovi.cod_tra_padre      := v_cod_tra_padre;  -- Cargos por seguro en cuotas
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

      -- Esta parte corresponde al credito del monto a pagar a la Aseguradora en su cuenta
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
        
       if v_cod_rubro is not null then
         v_cod_mon_rubro := pag_sue.fu_obt_mon_rubro(v_cod_rubro);
       end if;
         v_tot_cargo := v_imp_cuota;

         --Hacer el calculo por la porcion que le corresponde a la aseguradora
         v_importe := round((v_imp_cuota / (v_val_tasa / v_val_tas_prima)),v_redondeo);

         --carculos de nuevos campos--
         v_mto_car_dis_seguro     := round((v_importe / 1.1),v_redondeo);
         v_mto_car_dis_iva_seguro := v_importe - v_mto_car_dis_seguro;
         v_mto_car_dis_banco      := round(((v_imp_cuota - v_importe) / 1.1),v_redondeo);
         v_mto_car_dis_iva_banco  := (v_imp_cuota - v_importe) - v_mto_car_dis_banco;
         v_imp_restante := v_tot_cargo - v_importe;
         v_importe := nvl(v_mto_car_dis_seguro,0) + nvl(v_mto_car_dis_banco,0);

        v_nro_secuencia := v_nro_secuencia + 1;
        r_gmovi.nro_secuencia      := v_nro_secuencia;
        r_gmovi.cod_usuario        := v_cod_usuario;
        r_gmovi.hora               := v_hora;
        r_gmovi.fecha              := v_fec_actual;
        r_gmovi.cod_modulo         := r_pcpre.cod_modulo;
        r_gmovi.cod_modalidad      := r_pcpre.cod_modalidad;
        r_gmovi.cod_oficina        := r_pcpre.cod_oficina;
        r_gmovi.nro_cuenta         := null;
        r_gmovi.cod_moneda         := reg.cod_moneda;
        r_gmovi.est_cuenta         := null;
        r_gmovi.cod_tra_padre      := v_cod_tra_padre;
        r_gmovi.cod_transaccion    := 1633;
        r_gmovi.concepto           := 'Cobro de Cargos de Seguros en cuotas';
        r_gmovi.monto              := v_importe;
        if reg.cod_moneda <> v_cod_mon_local then
           v_cotizacion               := pag_gen.fu_obt_cotizacion(reg.cod_moneda, v_fec_actual);
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
        r_gmovi.referencia         := r_pcpre.nro_cuenta;  --RI: 01/09/10
        r_gmovi.cod_tasa           := null;
        r_gmovi.val_tasa           := null;
        r_gmovi.cod_rubro          := null;
        r_gmovi.tip_mov_rubro      := null;
        r_gmovi.cod_persona        := v_cod_persona;
            ----- ajuste---
        r_gmovi.nro_documento      := reg.nro_solicitud;
        r_gmovi.nro_documento2     := r_pcpre.nro_cuenta;
        r_gmovi.nro_documento3     := reg.cod_persona;
        pag_gen.pr_ins_ge_movimiento(r_gmovi);

       if v_imp_restante < 0 then
         v_cod_tra_movimiento := fug_obt_parentes(v_ent_seguro, 'COD_TRA_MOV_DEB_VIDA');
       elsif v_imp_restante > 0 then
         v_cod_tra_movimiento := fug_obt_parentes(v_ent_seguro, 'COD_TRA_MOV_CRE_VIDA');
       end if;

       -- Generar el movimiento de credito por el IVA del total del cargo
        -- Se calcula el I.V.A.   s/ el Cargo
        v_cod_tasa := null;
        pag_gen.pr_obt_val_tasa(r_pcpre.cod_modulo, r_pcpre.cod_modalidad,
                                r_pcpre.cod_oficina, r_pcpre.nro_cuenta, r_pcpre.cod_moneda,
                                0, 'N', v_cod_tasa, 517, --Transaccion
                                pap_cob.g_fec_calculo, v_val_tas_iva, v_fec_vigencia, v_tip_valor, v_tipo);
        -- RI : 03/06/2010 : El cargo de seguro es iva incluido, se debe desglosar

        v_cargo_iva := nvl(v_mto_car_dis_iva_seguro,0) + nvl(v_mto_car_dis_iva_banco,0);

        v_nro_secuencia            := v_nro_secuencia + 1;
        r_gmovi.nro_secuencia      := v_nro_secuencia;
        r_gmovi.cod_usuario        := v_cod_usuario;
        r_gmovi.hora               := v_hora;
        r_gmovi.fecha              := v_fec_actual;
        r_gmovi.cod_modulo         := r_pcpre.cod_modulo;
        r_gmovi.cod_modalidad      := r_pcpre.cod_modalidad;
        r_gmovi.cod_oficina        := r_pcpre.cod_oficina;
        r_gmovi.nro_cuenta         := null;
        r_gmovi.cod_moneda         := reg.cod_moneda;
        r_gmovi.est_cuenta         := null;
        r_gmovi.cod_tra_padre      := v_cod_tra_padre;  -- Cobro de Cargos por seguro en cuotas
        r_gmovi.cod_transaccion    := 1631;  -- Credito por el IVA del total del cargo
        r_gmovi.concepto           := 'Cobro de Cargos de Seguros en cuotas.3';
        r_gmovi.monto              := v_cargo_iva;
        if reg.cod_moneda <> v_cod_mon_local then
           v_cotizacion               := pag_gen.fu_obt_cotizacion(reg.cod_moneda, v_fec_actual);
           r_gmovi.cotizacion         := v_cotizacion;
           r_gmovi.mto_equ_local      := round(trunc(v_cargo_iva,2)*v_cotizacion,v_redondeo_ml);
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
        r_gmovi.referencia         := r_pcpre.nro_cuenta;  --RI: 01/09/10
        r_gmovi.cod_tasa           := v_cod_tasa;
        r_gmovi.val_tasa           := v_val_tas_iva; --Se agrego el valor de la tasa para generar el libro de ventas JF 31/08/2011.-
        r_gmovi.cod_rubro          := null;
        r_gmovi.tip_mov_rubro      := null;
        r_gmovi.cod_persona        := v_cod_persona;
          ----- ajuste---
        r_gmovi.nro_documento      := r_pcpre.nro_cuenta;
        r_gmovi.nro_documento2     := r_pcpre.nro_cuenta;
        r_gmovi.nro_documento3     := reg.cod_persona;
        pag_gen.pr_ins_ge_movimiento(r_gmovi);
       -------

       --Modificar nro de dodumento2 de la 1521 para la feactura--
       update ge_movimientos z
          set z.nro_documento3 = reg.cod_persona
        where z.fecha = reg.fecha
          and z.hora = reg.hora
          and z.cod_usuario = reg.cod_usuario
          and z.nro_secuencia = reg.nro_secuencia;

       update pr_cta_gas_seguros x
              set x.estado = 'G',
                  x.fec_ingreso = v_fec_anterior,
                  x.fec_ult_pago = v_fec_actual,
                  x.hor_ult_pago = v_hora,
                  cod_tas_ref1 = v_cod_tas_seg_vida,
                  val_tas_ref1 = v_val_tasa,
                  cod_tas_ref2 = v_tas_prima,
                  val_tas_ref2 = v_val_tas_prima,
                  --Calculo de Distribucion nueva--
                  mto_car_dis_com_seguro = round(((round((x.monto / (v_val_tasa / v_val_tas_prima)),v_redondeo)) / 1.1),v_redondeo),
                  mto_car_dis_iva_seguro = (round((x.monto / (v_val_tasa / v_val_tas_prima)),v_redondeo)) - (round(((round((x.monto / (v_val_tasa / v_val_tas_prima)),v_redondeo)) / 1.1),v_redondeo)),
                  mto_car_dis_seguro = (round(((round((x.monto / (v_val_tasa / v_val_tas_prima)),v_redondeo)) / 1.1),v_redondeo)) + ((round((x.monto / (v_val_tasa / v_val_tas_prima)),v_redondeo)) - (round(((round((x.monto / (v_val_tasa / v_val_tas_prima)),v_redondeo)) / 1.1),v_redondeo))),
                  mto_car_dis_com_banco = round(((x.monto - round((x.monto / (v_val_tasa / v_val_tas_prima)),v_redondeo)) / 1.1),v_redondeo),
                  mto_car_dis_iva_banco = (x.monto - round((x.monto / (v_val_tasa / v_val_tas_prima)),v_redondeo)) - round(((x.monto - round((x.monto / (v_val_tasa / v_val_tas_prima)),v_redondeo)) / 1.1),v_redondeo),
                  mto_car_dis_banco = (round(((x.monto - round((x.monto / (v_val_tasa / v_val_tas_prima)),v_redondeo)) / 1.1),v_redondeo)) + ((x.monto - round((x.monto / (v_val_tasa / v_val_tas_prima)),v_redondeo)) - round(((x.monto - round((x.monto / (v_val_tasa / v_val_tas_prima)),v_redondeo)) / 1.1),v_redondeo)),
                  --Otros campos--
                  ano = 0,
                  dia_acu_cuota = (x.fec_vencimiento - reg.fec_inicio),
                  dia_cuota = 0,
                  cod_ent_seguro = v_ent_seguro,
                  cod_persona = v_cod_persona,
                  cod_ref_gasto = v_cod_ref_gasto
            where x.nro_solicitud = r_pcpre.nro_solicitud
              and x.nro_cuota = 0;

            --Actualiza demas cuotas--
            update pr_cta_gas_seguros x
               set x.estado = decode(nvl(x.monto,0),0,'G',x.estado),
                   cod_tas_ref1 = v_cod_tas_seg_vida,
                   val_tas_ref1 = v_val_tasa,
                   cod_tas_ref2 = v_tas_prima,
                   val_tas_ref2 = v_val_tas_prima,
                   --Calculo de Distribucion nueva--
                   mto_car_dis_com_seguro = round(((round((x.monto / (v_val_tasa / v_val_tas_prima)),v_redondeo)) / 1.1),v_redondeo),
                   mto_car_dis_iva_seguro = (round((x.monto / (v_val_tasa / v_val_tas_prima)),v_redondeo)) - (round(((round((x.monto / (v_val_tasa / v_val_tas_prima)),v_redondeo)) / 1.1),v_redondeo)),
                   mto_car_dis_seguro = (round(((round((x.monto / (v_val_tasa / v_val_tas_prima)),v_redondeo)) / 1.1),v_redondeo)) + ((round((x.monto / (v_val_tasa / v_val_tas_prima)),v_redondeo)) - (round(((round((x.monto / (v_val_tasa / v_val_tas_prima)),v_redondeo)) / 1.1),v_redondeo))),
                   mto_car_dis_com_banco = round(((x.monto - round((x.monto / (v_val_tasa / v_val_tas_prima)),v_redondeo)) / 1.1),v_redondeo),
                   mto_car_dis_iva_banco = (x.monto - round((x.monto / (v_val_tasa / v_val_tas_prima)),v_redondeo)) - round(((x.monto - round((x.monto / (v_val_tasa / v_val_tas_prima)),v_redondeo)) / 1.1),v_redondeo),
                   mto_car_dis_banco = (round(((x.monto - round((x.monto / (v_val_tasa / v_val_tas_prima)),v_redondeo)) / 1.1),v_redondeo)) + ((x.monto - round((x.monto / (v_val_tasa / v_val_tas_prima)),v_redondeo)) - round(((x.monto - round((x.monto / (v_val_tasa / v_val_tas_prima)),v_redondeo)) / 1.1),v_redondeo)),
                   --Calculo de Distribucion base--
                   mto_car_pri_com_base  = round((mto_car_pri_base / 1.1),v_redondeo),
                   mto_car_pri_iva_base = mto_car_pri_base - round((mto_car_pri_base / 1.1),v_redondeo),
                   mto_car_bco_com_base  = round((mto_car_bco_base / 1.1),v_redondeo),
                   mto_car_bco_iva_base = mto_car_bco_base - round((mto_car_bco_base / 1.1),v_redondeo),
                   --Otros campos--
                   ano = ceil(TRUNC((x.fec_vencimiento - reg.fec_inicio)/365,2)),
                   dia_acu_cuota = (x.fec_vencimiento - reg.fec_inicio),
                   dia_cuota = x.fec_vencimiento - x.fec_ini_vigencia,
                   cod_ent_seguro = v_ent_seguro,
                   cod_persona = v_cod_persona
             where x.nro_solicitud = r_pcpre.nro_solicitud
               and x.nro_cuota > 0;

            --Actualizar el año y mes de pago de prima de seguro--
            update pr_cta_gas_seguros a
   set (a.ano_pag_prima, a.mes_pag_prima, a.fec_pag_prima) = (select to_number(to_char(min(x.fec_ini_vigencia),'YYYY')),
                                                    to_number(to_char(min(x.fec_ini_vigencia),'MM')),
                                                    min(x.fec_ini_vigencia)
                                               from pr_cta_gas_seguros x
                                              where x.nro_cuenta = a.nro_cuenta
                                                and x.ano = a.ano)
            where a.nro_solicitud = r_pcpre.nro_solicitud
              and exists (select 1
                            from pr_cta_gas_seguros x
                           where x.nro_cuenta = a.nro_cuenta
                             and x.ano = a.ano);

       --- Siguiente registro--
       <<siguiente_registro>>
       null;
    End loop;
Exception
  WHEN OTHERS THEN
     raise_application_error(-20000, 'Error al generar cargos por seguro de Vidas.'||' - '||v_lugar||' Error : '||sqlerrm);
END;
/

