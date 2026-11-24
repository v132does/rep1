CREATE OR REPLACE PROCEDURE IT.PRP_GEN_PAG_SEG_ANUAL IS

  -----------------------------------------------------------
  --Proyecto SDSEGVID-3 Seguro de Vida Distribuido (1521)----
  --Generacion cargo de Seguro de Vida en desembolso---------
  -----------------------------------------------------------

  -- Todos los préstamos vigentes, con saldo de capital y seguro de vida
  -- PPCARCSV-1 - Automatización de Registros Contables de Comisiones de Seguro MAPFRE -- CN: 04/2016 --
  --1-) Buscar todos los los préstamos que se desembolsaron en la fecha y que tenga asociado el cobro de cargo 736- Comisión por Seguro de Vida.
  --2-) Se deberán excluir las modalidades que se encuentren parametrizadas en el parámetro dinámico MOD_EXC_COM_SEG_VIDA
  --
  v_val_parametro   ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('NRO_CTA_EXC_SEG_VIDA');
  --
  -- Prestamos desembolsados en la fecha --
  cursor c_desembolsos is
    select a.*
      from ge_movimientos a
     where a.cod_transaccion = 736
       and a.cod_tra_padre = 358
       and a.cod_modulo = 6 -- Modulo Préstamos
       and a.reversado = 'N'
       and instr(nvl(v_val_parametro, '0'), a.nro_cuenta) = 0 --Cuentas Excluidas por error detectado--
       --Proyecto SDSEGVID-144--Seguro Anual de Consumo--------
       --Valida si es una cuenta de consumo con seguro anual --
       and exists (select 1
                     from ba_tab_dat_adicionales x, pr_solicitudes y, pr_cta_prestamos z
                    where z.nro_cuenta = a.nro_cuenta
                      and y.nro_solicitud = z.nro_solicitud
                      and x.tab_relacion = 'PR_SOLICITUDES'
                      and x.parametro = 'PRE_PRO_CTA_SEG_ANUAL'
                      and x.referencia = y.nro_solicitud
                      and x.val_parametro = 'S')
       and not exists (select 1
                         from pr_cta_gas_seguros c
                        where c.nro_cuenta = a.nro_cuenta)
     order by a.fec_insercion desc;
  v_mto_capital       pr_cta_prestamos.mto_capital%type;
  v_fec_inicio        date;
  v_fec_vencimiento   date;
  v_sal_capital       pr_cta_prestamos.sal_capital%type := 0;
  v_cap_asegurado     pr_cta_prestamos.sal_capital%type := 0;
  v_nro_cuota         pr_cuotas.nro_cuota%type;
  v_cargo             number;
  --Que no haya sido generado antes----
  v_importe            ge_movimientos.monto%type;
  v_imp_cuota          number;
  v_tot_cargo          number;
  v_imp_restante       number;
  v_fec_vto            date;
  v_redondeo           number;
  v_fec_actual         date := PAG_CAL.FU_OBT_FEC_ACTUAL(6);
  v_cod_mon_local      ge_movimientos.cod_moneda%type := pag_gen.fu_obt_mon_local;
  v_cta_cre            ge_movimientos.nro_cuenta%type;
  v_tas_prima          ge_movimientos.cod_tasa%type;
  v_cod_tasa           ge_tasas.cod_tasa%type;
  v_cod_tas_prima      ge_tasas.cod_tasa%type := 345;  
  v_cod_tas_seguro     ge_tasas.cod_tasa%type := 339;    
  v_val_Tasa           ge_movimientos.val_tasa%type;
  v_val_Tas_iva        ge_movimientos.val_tasa%type;
  v_val_tas_prima      ge_movimientos.val_tasa%type;
  v_val_tas_dia        ge_movimientos.val_tasa%type;
  v_ent_seguro         ge_entes.cod_ente%type;
  v_cod_persona        ba_personas.cod_persona%type;
  v_cod_ofi_origen     ba_usuarios.cod_oficina%type;
  v_cod_tas_seg_vida   ge_movimientos.cod_tasa%type;
  v_tip_tas_seg_vida   ge_tasas.tipo%type;
  v_mto_car_bco_base   ge_movimientos.monto%type;
  v_lugar              varchar2(100);
  -- Variables de registro
  r_pcpre         pr_cta_prestamos%rowtype;
  r_gmovi         ge_movimientos%rowtype;
  v_fec_ini       date;
  v_cod_rubro     cb_rubros.cod_rubro%type;
  v_cod_mon_rubro cb_rubros.cod_moneda%type;
  v_fec_sug_pago  date;
  v_fec_vigencia  date;
  v_tip_valor     ge_tasas.tip_valor%type;
  v_tipo          ge_tasas.tipo%type;

  ---
  v_mto_car_dis_seguro     number(18, 2);
  v_mto_car_cli_base     number(18, 2);
  v_mto_car_pri_base     number(18, 2);
  v_mto_car_dis_banco      number(18, 2);
  v_mto_car_dis_iva_banco  number(18, 2);
  v_mto_car_dis_iva_seguro number(18, 2);
  v_dia_calculo   number := 365/12;

  v_cargo_iva number(18, 2);

  rg_calend       ge_calendarios%rowtype := pag_cal.fu_obt_reg_cal(6); ---DYDMR-7487 - 19/10/2017
  v_fec_control   ge_calendarios.fec_actual%type;
  v_cod_ref_gasto pr_cta_gastos.cod_ref_gasto%type;

  --------------------------------------------------------------------------------------------
  --  EMPIEZA EL PROCEDIMIENTO
  --------------------------------------------------------------------------------------------

BEGIN
  begin
    pre_ini_aplicacion;
    pae_cnf.g_cod_modulo := 6;
  end;
  v_fec_control  := v_fec_actual;
  if v_fec_actual = rg_calend.ult_dia_mes_habil then
    v_fec_control := RG_CALEND.ULT_DIA_MES;
  END IF;

  For i in c_desembolsos loop
    r_gmovi                  := null; --Inicializar registro movimiento
    v_mto_car_dis_seguro     := 0;
    v_mto_car_dis_banco      := 0;
    v_mto_car_dis_iva_banco  := 0;
    v_mto_car_dis_iva_seguro := 0;
    v_cod_ref_gasto          := null;
    v_lugar                  := 'Cta.: ' || i.nro_cuenta;
    --Traer los datos del prestamo
    pap_pre.pr_obt_dat_prestamo(i.nro_cuenta, r_pcpre);
    -- Trae el codigo del ente que corresponde a la propuesta
    /*
    especs.
    excluir las MODALIDADES DE consumo del gen_com_seg_vida (o sea las modalidades que
    se procesaran en este proceso ya no debe tocar el otro)

    1 iter
    si es la primera cuota calcular pago full saldo completo a 12 meses,
    guardar fecha inicio de la primera,
    2 iter
    selecccionar la primera cuota cuya fecha de vencimiento sea mayor a la fecha de vencimienbto de
    la primera + 365, calcular el pago con el saldo capital de la cuota a doce meses si la fecha de
    inicio de la cuota + doce meses no es mayor a la fecha de vencimiento del prestamo,
    si lo es calcular el pago hasta la fecha de vencimienbto del prestamo, si no es guardar fecha de
    vencimiento de la cuota que abarco el pago y guardar como fecha inicio siguiente iter.
    3 iter y mas
    repetir prceso hasta que se alcance la fecha de vencimiento del prestamo
    */
    --v_conmes := 360/r_pcpre.per_vto_capital
--Agregado para recuperar tasas para la cuota 0
      begin
        select t.cod_ent_seguro
          into v_ent_seguro
          from pr_sol_cargos t
         where t.nro_solicitud = r_pcpre.nro_solicitud
           and t.cod_transaccion = 736;
      exception
        when no_data_found then
          v_ent_seguro := FUG_OBT_ENT_SEGURO(6, i.cod_modalidad, 'V');
        when others then
          raise_application_error(-20000,
                                  'No encuentra código de Aseguradora. Verifique Solicitud ' ||
                                  r_pcpre.nro_solicitud);
      end;
      v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                                        r_pcpre.cod_modulo,
                                        r_pcpre.cod_modalidad,
                                        r_pcpre.cod_moneda,
                                        r_pcpre.cod_oficina);





    v_val_tasa := fug_obt_val_tasa(i.cod_modulo,
                                   i.cod_modalidad,
                                   null,
                                   null,
                                   i.cod_moneda,
                                   r_pcpre.fec_vencimiento - r_pcpre.fec_inicio,
                                   null,
                                   v_cod_tas_seguro,
                                   null,
                                   v_fec_inicio);

      --Traer valor de la tasa de prima seguro vida.
    v_val_tas_prima := fug_obt_val_tasa(i.cod_modulo,
                                   i.cod_modalidad,
                                   null,
                                   null,
                                   i.cod_moneda,
                                   r_pcpre.fec_vencimiento - r_pcpre.fec_inicio,
                                   null,
                                   v_cod_tas_prima,
                                   null,
                                   v_fec_inicio);


      --Traer el codigo de persona
      Begin
        v_cod_persona := fug_obt_cli_principal(i.nro_cuenta);
      Exception
        when others then
          v_cod_persona := null;
      end;

--      v_mto_car_cli_base := round(((r_pcpre.sal_capital * v_val_tasa) / 100), v_redondeo);
--      v_mto_car_pri_base := round((v_mto_car_cli_base / (v_val_tasa / v_val_tas_prima)), v_redondeo);
--      v_mto_car_bco_base := v_mto_car_cli_base - v_mto_car_pri_base;
      --carculos de nuevos campos--
      v_mto_car_cli_base := i.monto;
      v_mto_car_pri_base := round(((r_pcpre.sal_capital * (v_val_tas_prima / (365/12)) * (r_pcpre.fec_vencimiento - r_pcpre.fec_inicio)) / 100),v_redondeo);

        insert into pr_cta_gas_seguros
          (NRO_SOLICITUD,
           COD_TRANSACCION,
           COD_MONEDA,
           MONTO,
           SAL_CAPITAL,
           FEC_INGRESO,
           FEC_VENCIMIENTO,
           FEC_ULT_PAGO,
           COD_MODALIDAD,
           COD_MODULO,
           FEC_INI_VIGENCIA,
           NRO_CUENTA,
           COD_TAS_REF1,
           VAL_TAS_REF1,
           mto_car_ref1,
           COD_TAS_REF2,
           VAL_TAS_REF2,
           mto_car_ref2,
           nro_cuota,
           estado,
           FEC_ANU_SUG_PAG_ASE,
           ano,
           ano_pag_prima,
           mes_pag_prima,
           fec_pag_prima,
           cod_persona)
        values
          (r_pcpre.nro_solicitud,
           i.cod_transaccion,
           i.cod_moneda,
           i.monto,
           r_pcpre.sal_capital,
           i.fecha - 1,
           i.fecha,
           i.fecha,
           i.cod_modalidad,
           i.cod_modulo,
           i.fecha,
           r_pcpre.nro_cuenta,
           v_cod_tas_seguro,
           v_val_tasa,
           v_cargo, --esta es la parte de la comision a cobrar al cliente
           v_cod_tas_prima, --este es la parte del pago a la aseguradora, cod_tasa, val_tasa, y monto
           v_val_tas_prima,
           v_importe,
           0,
           'G',
           null,
           0,
           null,
           null,
           to_char(r_pcpre.fec_inicio),
           v_cod_persona);

            update pr_cta_gas_seguros x
               set x.estado = decode(nvl(x.monto,0),0,'G',x.estado),
                   val_tas_ref1 = v_val_tasa,
                   val_tas_ref2 = v_val_tas_prima,
                   --Calculo de Distribucion nueva--
--                   mto_car_dis_seguro = (round(((round((x.monto / (v_val_tasa / v_val_tas_prima)),v_redondeo)) / 1.1),v_redondeo)) + ((round((x.monto / (v_val_tasa / v_val_tas_prima)),v_redondeo)) - (round(((round((x.monto / (v_val_tasa / v_val_tas_prima)),v_redondeo)) / 1.1),v_redondeo))),
--                   mto_car_dis_com_seguro = (round(((round((x.monto / (v_val_tasa / v_val_tas_prima)),v_redondeo)) / 1.1),v_redondeo)) + ((round((x.monto / (v_val_tasa / v_val_tas_prima)),v_redondeo)) - (round(((round((x.monto / (v_val_tasa / v_val_tas_prima)),v_redondeo)) / 1.1),v_redondeo))),
--                   mto_car_dis_banco = (round(((x.monto - round((x.monto / (v_val_tasa / v_val_tas_prima)),v_redondeo)) / 1.1),v_redondeo)) + ((x.monto - round((x.monto / (v_val_tasa / v_val_tas_prima)),v_redondeo)) - round(((x.monto - round((x.monto / (v_val_tasa / v_val_tas_prima)),v_redondeo)) / 1.1),v_redondeo)),
--                   mto_car_dis_com_banco = (round(((x.monto - round((x.monto / (v_val_tasa / v_val_tas_prima)),v_redondeo)) / 1.1),v_redondeo)) + ((x.monto - round((x.monto / (v_val_tasa / v_val_tas_prima)),v_redondeo)) - round(((x.monto - round((x.monto / (v_val_tasa / v_val_tas_prima)),v_redondeo)) / 1.1),v_redondeo)),
                   --Calculo de Distribucion base--
--                   mto_car_cli_base = i.monto,
--                   mto_car_pri_base = v_mto_car_pri_base,
--                   mto_car_bco_base = v_mto_car_bco_base,
--                   mto_car_pri_com_base  = round((mto_car_pri_base / 1.1),v_redondeo),
--                   mto_car_bco_com_base  = round((mto_car_bco_base / 1.1),v_redondeo),
                   --Otros campos--
                   dia_cuota = x.fec_vencimiento - x.fec_ini_vigencia,
                   cod_ent_seguro = v_ent_seguro,
                   cod_persona = v_cod_persona
             where x.nro_solicitud = r_pcpre.nro_solicitud
               and x.nro_cuota = 0;

            update pr_cta_gas_seguros x
               set mto_car_pri_com_base  = round((mto_car_pri_base / 1.1),v_redondeo),
                   mto_car_pri_iva_base = mto_car_pri_base - round((mto_car_pri_base / 1.1),v_redondeo),
                   mto_car_bco_com_base  = round((mto_car_bco_base / 1.1),v_redondeo),
                   mto_car_bco_iva_base = mto_car_bco_base - round((mto_car_bco_base / 1.1),v_redondeo)
             where x.nro_solicitud = r_pcpre.nro_solicitud
               and x.nro_cuota = 0;

    for j in 1 .. r_pcpre.can_cuotas loop
        begin
          select min(b.fec_inicio),
                 max(a.fec_vencimiento),
                 sum(a.sal_capital),
                 max(a.nro_cuota)
            into v_fec_inicio,
                 v_fec_vencimiento,
                 v_sal_capital,
                 v_nro_cuota
            from pr_cuotas a, pr_cta_prestamos b
           where a.nro_cuenta = b.nro_cuenta
             and a.fec_vencimiento between
                 nvl(v_fec_ini + 1, r_pcpre.fec_inicio) and
                 add_months(nvl(v_fec_vencimiento, b.fec_inicio), 12)
             and b.nro_cuenta = i.nro_cuenta;
        end;
        v_fec_sug_pago := v_fec_inicio + 365;
      
      -- cuando es una sola cuota y el plazo supera 365 dia el select anterior retorna
      -- misma fecha de inicio y vencimiento, por lo que la diferencia es 0 y da error de division
      -- DYDMR-12834
      if r_pcpre.can_cuotas = 1 and (v_fec_inicio = v_fec_vencimiento) and
         (r_pcpre.fec_inicio <> r_pcpre.fec_vencimiento) then
        v_fec_vencimiento := r_pcpre.fec_vencimiento;
        v_nro_cuota := r_pcpre.can_cuotas;
        v_sal_capital := r_pcpre.sal_capital;
      end if;
      -- 
      if v_fec_ini is null then
        v_fec_ini       := v_fec_inicio;
        v_cap_asegurado := r_pcpre.mto_capital;
      end if;
/*      begin
        select t.cod_ent_seguro
          into v_ent_seguro
          from pr_sol_cargos t
         where t.nro_solicitud = r_pcpre.nro_solicitud
           and t.cod_transaccion = 736;
      exception
        when no_data_found then
          v_ent_seguro := FUG_OBT_ENT_SEGURO(6, i.cod_modalidad, 'V');
        when others then
          raise_application_error(-20000,
                                  'No encuentra código de Aseguradora. Verifique Solicitud ' ||
                                  r_pcpre.nro_solicitud);
      end;*/
      --Traer el monto del seguro de vida

      v_imp_cuota := v_sal_capital;

      --Verificacion de la Tasas de la transaccion 1521--
      begin
        select b.tipo
          into v_tip_tas_seg_vida
          from ge_transacciones a, ge_tasas b
         where a.cod_transaccion = i.cod_transaccion --1521--
           and a.cod_modulo = i.cod_modulo
           and a.cod_modalidad = i.cod_modalidad
           and b.cod_tasa = a.cod_tasa;
      exception
        when no_data_found then
          raise_application_error(-20000,
                                  'Error. No existe tasa definida para tran 1521.' ||
                                  sqlerrm);
        when others then
          raise_application_error(-20000,
                                  'Error. En traer tipo de tasa tran 1521.' ||
                                  sqlerrm);
      end;
      if v_tip_tas_seg_vida = 'F' then
        v_cod_tas_seg_vida := fug_obt_parentes(v_ent_seguro,
                                               'COD_TAS_SEG_VID_ANUAL');
      else
        v_cod_tas_seg_vida := fug_obt_parentes(v_ent_seguro,
                                               'COD_TAS_SEG_ANUAL');
      end if;
      if v_cod_tas_seg_vida is not null then
        if v_tip_tas_seg_vida = 'F' then
          v_val_tasa := fug_obt_valtas_rango(v_cod_tas_seg_vida,
                                             i.COD_MODULO,
                                             i.COD_MODALIDAD,
                                             i.cod_moneda,
                                             i.cod_oficina,
                                             NULL,
                                             r_pcpre.fec_inicio);
        else
          v_val_tasa := fug_obt_valtas_rango(v_cod_tas_seg_vida,
                                             i.COD_MODULO,
                                             i.COD_MODALIDAD,
                                             i.cod_moneda,
                                             i.cod_oficina,
                                             v_mto_capital,
                                             v_fec_inicio);
          v_val_tasa := fug_obt_valtas_rango(v_val_tasa,
                                             i.COD_MODULO,
                                             i.COD_MODALIDAD,
                                             i.cod_moneda,
                                             i.cod_oficina,
                                             v_fec_vencimiento - v_fec_ini,
                                             v_fec_inicio);
        end if;
        if v_val_tasa is null then
          raise_application_error(-20000,
                                  'No encuentra valor de la tasa del seguro de vida. Verifique');
        end if;
      else
        raise_application_error(-20000,
                                'No encuentra código de la tasa del seguro de vida. Verifique');
      end if;
      v_cod_ofi_origen := FUG_OBT_OFI_USUARIO(r_pcpre.usu_insercion);
      -- Redondeo
/*      v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                                        r_pcpre.cod_modulo,
                                        r_pcpre.cod_modalidad,
                                        r_pcpre.cod_moneda,
                                        r_pcpre.cod_oficina);*/
      -- Traer la fecha de vencimiento de la cuota mas vencida pendiente de pago
      Begin

        Select min(fec_vencimiento)
          into v_fec_vto
          from pr_cuotas
         where nro_cuenta = i.nro_cuenta
           and fec_vencimiento > v_fec_control
           and estado <> 'N'
           and nro_cuota > 0; -- DYDMR-7487 - 19/10/2017
        --RI: 01/09/2010: Si la minima cuota esta vencida, asignar esa fecha de vto.
        If v_fec_vto is null then
          Select min(fec_vencimiento)
            into v_fec_vto
            from pr_cuotas
           where nro_cuenta = i.nro_cuenta
             and estado <> 'N'
             and nro_cuota > 0; -- DYDMR-7487 - 19/10/2017
        End if;
      Exception
        when others then
          raise_application_error(-20000,
                                  'Error en Generar Mov. Seguro al traer fecha de vencimiento de cuota. ' ||
                                  pag_cta.fu_obt_cod_error() || ' - ' ||
                                  pag_cta.fu_obt_msj_error());
      End;
      --Traer valor de la tasa de prima seguro vida.
      v_tas_prima := fug_obt_parentes(v_ent_seguro, 'COD_TAS_PRI_VID_ANUAL');
      if v_tas_prima is not null then
        PAG_GEN.PR_OBT_VAL_TASA(r_pcpre.cod_modulo,
                                r_pcpre.cod_modalidad,
                                r_pcpre.cod_oficina,
                                r_pcpre.nro_cuenta,
                                r_pcpre.cod_moneda,
                                (v_fec_vencimiento - v_fec_inicio),
                                'N',
                                v_tas_prima,
                                NULL,
                                r_pcpre.fec_inicio,
                                v_val_tas_prima,
                                v_fec_vigencia,
                                v_tip_valor,
                                v_tipo);
        if v_val_tas_prima is null then
          raise_application_error(-20000,
                                  'No encuentra valor de la tasa del seguro de vida. Verifique');
        end if;
      else
        raise_application_error(-20000,
                                'No encuentra código de la tasa del seguro de vida. Verifique');
      end if;
      begin
        v_cta_cre := null;
        if fug_obt_tip_ente(v_ent_seguro) = 'SE' then
          if r_pcpre.cod_moneda = v_cod_mon_local then
            v_cta_cre   := fug_obt_parentes(v_ent_seguro,
                                            'NRO_CTA_SEG_MON_LOCAL');
            v_cod_rubro := fug_obt_parentes(v_ent_seguro,
                                            'COD_RUB_MON_LOCAL');
          else
            v_cta_cre   := fug_obt_parentes(v_ent_seguro,
                                            'NRO_CTA_SEG_MON_FUERTE');
            v_cod_rubro := fug_obt_parentes(v_ent_seguro,
                                            'COD_RUB_MON_FUERTE');
          end if;
        else
          v_cta_cre := fug_obt_parentes(v_ent_seguro, 'NRO_CTA_ESCRIBANIA');
        end if;
      exception
        when others then
          v_cta_cre := null;
      end;

      v_cod_mon_rubro := 'GS';
      v_tot_cargo     := v_imp_cuota;

      --Hacer el calculo por la porcion que le corresponde a la aseguradora

      -- Generar el movimiento de credito por el IVA del total del cargo
      -- Se calcula el I.V.A.   s/ el Cargo
      v_cod_tasa := null;
      pag_gen.pr_obt_val_tasa(r_pcpre.cod_modulo,
                              r_pcpre.cod_modalidad,
                              r_pcpre.cod_oficina,
                              r_pcpre.nro_cuenta,
                              r_pcpre.cod_moneda,
                              0,
                              'N',
                              v_cod_tasa,
                              517, --Transaccion
                              pap_cob.g_fec_calculo,
                              v_val_tas_iva,
                              v_fec_vigencia,
                              v_tip_valor,
                              v_tipo);
      -- RI : 03/06/2010 : El cargo de seguro es iva incluido, se debe desglosar

      v_cargo_iva := nvl(v_mto_car_dis_iva_seguro, 0) +
                     nvl(v_mto_car_dis_iva_banco, 0);
      --Modificar nro de dodumento2 de la 1521 para la feactura--
      update ge_movimientos z
         set z.nro_documento3 = i.cod_persona
       where z.fecha = i.fecha
         and z.hora = i.hora
         and z.cod_usuario = i.cod_usuario
         and z.nro_secuencia = i.nro_secuencia;

--      v_cargo   := round(((v_cap_asegurado * v_val_tasa) / 100), v_redondeo);
      v_cargo := round(((v_cap_asegurado * (v_val_tasa / (365/12)) * (v_fec_vencimiento - v_fec_ini)) / 100),v_redondeo);
      v_importe := round((v_cargo / (((v_val_tasa / (365/12)) * (v_fec_vencimiento - v_fec_ini))/ v_val_tas_prima)), v_redondeo);
      --carculos de nuevos campos--
      v_mto_car_dis_seguro     := round((v_importe / 1.1), v_redondeo);
      v_mto_car_dis_iva_seguro := v_importe - v_mto_car_dis_seguro;
      v_mto_car_dis_banco      := round((v_cargo - v_importe), v_redondeo);
      v_imp_restante           := v_cargo - v_importe;
      v_importe                := nvl(v_mto_car_dis_seguro, 0) +  nvl(v_mto_car_dis_banco, 0);

--      v_mto_car_cli_base := i.monto;
--      v_mto_car_pri_base := round(((r_pcpre.sal_capital * (v_val_tas_prima / (365/12)) * (r_pcpre.fec_vencimiento - r_pcpre.fec_inicio)) / 100),v_redondeo);


      insert into pr_cta_gas_seguros a
        (NRO_CUENTA,
         COD_TRANSACCION,
         COD_MONEDA,
         MONTO,
         a.mto_car_cli_base,
         a.sal_capital,
         FEC_INGRESO,
         FEC_VENCIMIENTO,
         FEC_ULT_PAGO,
         COD_MODALIDAD,
         HOR_ULT_PAGO,
         COD_MODULO,
         FEC_INI_VIGENCIA,
         NRO_SOLICITUD,
         COD_TAS_REF1,
         VAL_TAS_REF1,
         MTO_CAR_REF1,
         COD_TAS_REF2,
         VAL_TAS_REF2,
         MTO_CAR_REF2,
         MTO_DIF_REFERENCIAS,
         NRO_CUOTA,
         ESTADO,
         DIA_CUOTA,
         COD_ENT_SEGURO,
         COD_PERSONA,
         COD_REF_GASTO,
         fec_anu_sug_pag_ase,
         A.ANO,
         a.ano_pag_prima,
         a.mes_pag_prima,
         a.fec_pag_prima) --tasas
      values
        (r_pcpre.nro_cuenta,
         i.cod_transaccion,
         i.cod_moneda,
         null,
         v_cargo,
         v_cap_asegurado,
         v_fec_ini,
         v_fec_vencimiento,
         null,
         r_pcpre.cod_modalidad,
         null,
         6,
         v_fec_ini,
         r_pcpre.nro_solicitud,
         v_cod_tas_seg_vida,
         v_val_tasa,
         v_mto_car_dis_banco,
         v_tas_prima,
         v_val_tas_prima,
         v_mto_car_dis_seguro,
         null,
         v_nro_cuota,
         'G',
         null,
         v_ent_seguro,
         null,
         null,
         v_fec_ini,
         j,
         to_char(v_fec_ini, 'YYYY'),
         to_char(v_fec_ini, 'MM'),
         v_fec_ini);
         --actualizar / insertar fechas de pago de prima
         v_fec_ini       := v_fec_vencimiento;
         v_cap_asegurado := v_cap_asegurado - v_sal_capital;
         if not sql%found then
           raise_application_error(-20000, 'Error del update');
         end if;
         if v_nro_cuota > 0 then
            update pr_cta_gas_seguros x
               set x.estado = decode(nvl(x.monto,0),0,'G',x.estado),
                   cod_tas_ref1 = v_cod_tas_seg_vida,
                   val_tas_ref1 = v_val_tasa,
                   cod_tas_ref2 = v_tas_prima,
                   val_tas_ref2 = v_val_tas_prima,
                   --Calculo de Distribucion nueva--
                   mto_car_dis_com_seguro = null,
                   mto_car_dis_com_banco = null,
                   --Calculo de Distribucion base-- prima monto completo. comision: mto completo
                   mto_car_pri_base = (round(((round((x.mto_car_cli_base / (v_val_tasa / v_val_tas_prima)),v_redondeo)) / 1.1),v_redondeo)) + ((round((x.mto_car_cli_base / (v_val_tasa / v_val_tas_prima)),v_redondeo)) - (round(((round((x.mto_car_cli_base / (v_val_tasa / v_val_tas_prima)),v_redondeo)) / 1.1),v_redondeo))),
                   mto_car_pri_com_base  =  round((x.mto_car_cli_base / (v_val_tasa / v_val_tas_prima)),v_redondeo) - (round((x.mto_car_cli_base / (v_val_tasa / v_val_tas_prima)),v_redondeo) - (round(((x.mto_car_cli_base / (v_val_tasa / v_val_tas_prima)) / 1.1),v_redondeo))),                   
                   mto_car_pri_iva_base = round((x.mto_car_cli_base / (v_val_tasa / v_val_tas_prima)),v_redondeo) - (round(((x.mto_car_cli_base / (v_val_tasa / v_val_tas_prima)) / 1.1),v_redondeo)), 
                   mto_car_bco_base = (round(((x.mto_car_cli_base - round((x.mto_car_cli_base / (v_val_tasa / v_val_tas_prima)),v_redondeo)) / 1.1),v_redondeo)) + ((x.mto_car_cli_base - round((x.mto_car_cli_base / (v_val_tasa / v_val_tas_prima)),v_redondeo)) - round(((x.mto_car_cli_base - round((x.mto_car_cli_base / (v_val_tasa / v_val_tas_prima)),v_redondeo)) / 1.1),v_redondeo)),
                   mto_car_bco_com_base  = (round((x.mto_car_cli_base - round((x.mto_car_cli_base / (v_val_tasa / v_val_tas_prima)),v_redondeo)))) - ((round((x.mto_car_cli_base - round((x.mto_car_cli_base / (v_val_tasa / v_val_tas_prima)),v_redondeo))))  - (round(((x.mto_car_cli_base - round((x.mto_car_cli_base / (v_val_tasa / v_val_tas_prima)),v_redondeo)) / 1.1)))),
                   mto_car_bco_iva_base = (round((x.mto_car_cli_base - round((x.mto_car_cli_base / (v_val_tasa / v_val_tas_prima)),v_redondeo))))  - (round(((x.mto_car_cli_base - round((x.mto_car_cli_base / (v_val_tasa / v_val_tas_prima)),v_redondeo)) / 1.1))), 
                   --Otros campos--
                   dia_cuota = x.fec_vencimiento - x.fec_ini_vigencia,
                   cod_ent_seguro = v_ent_seguro,
                   cod_persona = v_cod_persona
             where x.nro_solicitud = r_pcpre.nro_solicitud
               and x.nro_cuota > 0;
         end if;
             if not sql%found then
               raise_application_error(-20000, 'Error del update');
             end if;
       if v_nro_cuota = r_pcpre.can_cuotas then
          exit;
       end if;
    end loop;
    <<siguiente_registro>>
    v_fec_ini := null;
    v_fec_vencimiento := null;
  End loop;
Exception
  WHEN OTHERS THEN
    raise_application_error(-20000,
                            'Error al generar cargos por Seg de Vida.' ||
                            ' - ' || v_lugar || 'Excluir Cta en parametro NRO_CTA_EXC_SEG_VIDA.'||
                            ' Error : ' || sqlerrm);
END;
/

