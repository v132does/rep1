create or replace procedure it.prp_gen_car_esp_res4(p_nro_cuenta in varchar2) is

  --Proyecto SDRES4COVI---29.04.20-----
  --Procedimiento p/ generar cargos especiales de Resolucion 4--

  --Variables--
  v_tra_car_mora  ge_transacciones.cod_transaccion%type;
  v_tra_car_puni  ge_transacciones.cod_transaccion%type;
  v_nro_cuenta       ge_cuentas.nro_cuenta%type;
  v_tot_descuento    ge_movimientos.monto%type;
  v_tot_des_mora    ge_movimientos.monto%type;
  v_tot_des_puni    ge_movimientos.monto%type;
  v_tot_des_aux      ge_movimientos.monto%type;
  v_can_cuotas       pr_cta_prestamos.can_cuotas%type;
  v_mto_cuo_mora    pr_cta_gastos.monto%type;
  v_mto_cuo_puni    pr_cta_gastos.monto%type;
  v_mto_acu_cargo    pr_cta_gastos.monto%type;
  v_mto_acu_mora    pr_cta_gastos.monto%type;
  v_mto_acu_puni    pr_cta_gastos.monto%type;
  v_redondeo         number(5);
  v_fec_ini_vigencia date;
  v_con_cuotas       number(5);
  v_mto_min_car      pr_cta_gastos.monto%type;
  v_mto_car_mora     pr_cta_gastos.monto%type;
  v_mto_car_puni     pr_cta_gastos.monto%type;
  v_mensaje          varchar2(2000);
  v_fec_actual       date := pag_cal.fu_obt_fec_actual(6);
  v_dia_dif          number(5);

  --Cursores--
  cursor c_dat_cta_nueva is
     select des.nro_cuenta, des.cod_moneda, des.cod_modalidad, des.can_cuotas, des.cod_modulo,
            des.cod_sub_modalidad, k.cot_mon_fuerte, --ori.nro_cuenta nro_cta_ori,
            sum(case when des.cod_moneda = ori.cod_moneda then k.mto_tot_descuento else
                pag_gen.fu_con_mon_a_moneda(ori.cod_moneda, des.cod_moneda, k.mto_tot_descuento,
                k.cot_mon_fuerte, null, k.cot_mon_fuerte) end) mto_tot_descuento,
            sum(case when des.cod_moneda = ori.cod_moneda then k.mto_mora else
                pag_gen.fu_con_mon_a_moneda(ori.cod_moneda, des.cod_moneda, k.mto_mora,
                k.cot_mon_fuerte, null, k.cot_mon_fuerte) end) mto_mor_cap,
            sum(case when des.cod_moneda = ori.cod_moneda then k.mto_mor_int else
                pag_gen.fu_con_mon_a_moneda(ori.cod_moneda, des.cod_moneda, k.mto_mor_int,
                k.cot_mon_fuerte, null, k.cot_mon_fuerte) end) mto_mor_int,
            sum(case when des.cod_moneda = ori.cod_moneda then k.mto_punitorio else
                pag_gen.fu_con_mon_a_moneda(ori.cod_moneda, des.cod_moneda, k.mto_punitorio,
                k.cot_mon_fuerte, null, k.cot_mon_fuerte) end) mto_punitorio,
            sum(case when des.cod_moneda = ori.cod_moneda then k.mto_impuesto else
                pag_gen.fu_con_mon_a_moneda(ori.cod_moneda, des.cod_moneda, k.mto_impuesto,
                k.cot_mon_fuerte, null, k.cot_mon_fuerte) end) mto_impuesto,
            sum(nvl(k.mto_tot_descuento,0) - nvl(k.mto_impuesto,0)) mto_des_neto,
            k.nro_sol_nueva nro_sol_nva, k.fec_proceso fec_ini_sol, des.fec_inicio fec_ini_cta
       from pr_cta_prestamos des,
            pr_cta_prestamos ori,
            pr_cta_pre_ref_res4 k
      where des.nro_cuenta = p_nro_cuenta
        and k.nro_cuenta = ori.nro_cuenta
        and k.nro_sol_nueva = des.nro_solicitud
     group by des.nro_cuenta, des.cod_moneda, des.cod_modalidad, des.can_cuotas, des.cod_modulo,
            des.cod_sub_modalidad, k.cot_mon_fuerte, k.nro_sol_nueva, k.fec_proceso, des.fec_inicio
     union
     select des.nro_cuenta, des.cod_moneda, des.cod_modalidad, des.can_cuotas, des.cod_modulo,
            des.cod_sub_modalidad, k.cot_mon_fuerte, --ori.nro_cuenta nro_cta_ori,
            sum(case when des.cod_moneda = ori.cod_moneda then k.mto_tot_descuento else
                pag_gen.fu_con_mon_a_moneda(ori.cod_moneda, des.cod_moneda, k.mto_tot_descuento,
                k.cot_mon_fuerte, null, k.cot_mon_fuerte) end) mto_tot_descuento,
            sum(case when des.cod_moneda = ori.cod_moneda then k.mto_mora else
                pag_gen.fu_con_mon_a_moneda(ori.cod_moneda, des.cod_moneda, k.mto_mora,
                k.cot_mon_fuerte, null, k.cot_mon_fuerte) end ) mto_mor_cap,
            sum(case when des.cod_moneda = ori.cod_moneda then k.mto_mor_int else
                pag_gen.fu_con_mon_a_moneda(ori.cod_moneda, des.cod_moneda, k.mto_mor_int,
                k.cot_mon_fuerte, null, k.cot_mon_fuerte) end ) mto_mor_int,
            sum(case when des.cod_moneda = ori.cod_moneda then k.mto_punitorio else
                pag_gen.fu_con_mon_a_moneda(ori.cod_moneda, des.cod_moneda, k.mto_punitorio,
                k.cot_mon_fuerte, null, k.cot_mon_fuerte) end ) mto_punitorio,
            sum(case when des.cod_moneda = ori.cod_moneda then k.mto_impuesto else
                pag_gen.fu_con_mon_a_moneda(ori.cod_moneda, des.cod_moneda, k.mto_impuesto,
                k.cot_mon_fuerte, null, k.cot_mon_fuerte) end ) mto_impuesto,
            sum(nvl(k.mto_tot_descuento,0) - nvl(k.mto_impuesto,0)) mto_des_neto,
            k.nro_sol_nueva nro_sol_nva, k.fec_proceso fec_ini_nva, des.fec_inicio fec_ini_cta
    from pr_cta_prestamos des,
         ov_cta_vencidas ori,
         pr_cta_pre_ref_res4 k
      where des.nro_cuenta = p_nro_cuenta
        and k.nro_cuenta = ori.nro_cuenta
        and k.nro_sol_nueva = des.nro_solicitud
      group by des.nro_cuenta, des.cod_moneda, des.cod_modalidad, des.can_cuotas, des.cod_modulo,
            des.cod_sub_modalidad, k.cot_mon_fuerte, ori.nro_cuenta, ori.cod_moneda, k.nro_sol_nueva, k.fec_proceso, des.fec_inicio;

  cursor c_cuo_cta_nueva is
    select y.* from pr_cuotas y
    where y.nro_cuenta = p_nro_cuenta
      and y.nro_cuota > 0
     order by y.nro_cuota;
begin
  --Carga de Variables--
  v_mensaje := 'carga de variables';
  v_tra_car_mora := fug_obt_pardinamico('TRA_CAR_MOR_RESOL4');
  v_tra_car_puni := fug_obt_pardinamico('TRA_CAR_PUN_RESOL4');

  --Se debe repartir los cargos en las cuotas--
  v_mensaje := 'cursor datos cta';
  for dat in c_dat_cta_nueva loop
      v_nro_cuenta    := dat.nro_cuenta;
      v_mto_min_car   := nvl(fug_obt_pardinamico('MTO_MIN_CAR_RESOL4',null,null,dat.cod_moneda),0);

      --Generar solo si igual o mayor a mto minimo--
      if nvl(dat.mto_des_neto,0) >= nvl(v_mto_min_car,0) then
         v_tot_des_aux   := dat.mto_des_neto;
         v_tot_descuento := 0;
         v_mensaje := 'valida total de descuento';

         --Verifica los datos descontador en tabla espejo 1 x 1--
         if nvl(v_tot_des_aux,0) > 0 then
             v_mensaje := 'valida moneda igual';
             v_tot_descuento := v_tot_des_aux;
             v_tot_des_mora := nvl(dat.mto_mor_cap,0) + nvl(dat.mto_mor_int,0);
             v_tot_des_puni := nvl(dat.mto_punitorio,0);

             v_mensaje := 'calcula descuentos';
             v_redondeo   := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', 6,dat.cod_modalidad, dat.cod_moneda);
             v_can_cuotas := dat.can_cuotas;
             v_con_cuotas := 0;
             v_mto_acu_cargo := 0;
             v_mto_acu_mora := 0;
             v_mto_acu_puni := 0;
             v_mto_car_mora  := trunc((nvl(dat.mto_mor_cap,0) + nvl(dat.mto_mor_int,0)) / v_can_cuotas,v_redondeo);
             v_mto_car_puni  := trunc(nvl(dat.mto_punitorio,0) / v_can_cuotas,v_redondeo);
             for cuo in c_cuo_cta_nueva loop
                 v_mensaje := 'ciclo de cuotas';
                 v_con_cuotas := nvl(v_con_cuotas,0) + 1;
                 v_fec_ini_vigencia := cuo.fec_vencimiento;
                 if v_con_cuotas = v_can_cuotas then
                    v_mto_cuo_mora := nvl(v_tot_des_mora,0) - nvl(v_mto_acu_mora,0);
                    v_mto_cuo_puni := nvl(v_tot_des_puni,0) - nvl(v_mto_acu_puni,0);
                 else
                    v_mto_cuo_mora := v_mto_car_mora;
                    v_mto_cuo_puni := v_mto_car_puni;
                 end if;
                 v_mto_acu_mora := v_mto_acu_mora + v_mto_cuo_mora;
                 v_mto_acu_puni := v_mto_acu_puni + v_mto_cuo_puni;

                 --Insertar el cargo adicional por mora--
                 if nvl(v_mto_cuo_mora,0) > 0 then
                    v_mensaje := 'inserta pr_cta_gastos 1';
                    insert into pr_cta_gastos
                    (NRO_CUENTA, COD_TRANSACCION, COD_MONEDA, MONTO,
                     FEC_INGRESO, FEC_VENCIMIENTO, FEC_ULT_PAGO,
                     COD_MODALIDAD, HOR_ULT_PAGO, COD_MODULO,
                     FEC_INI_VIGENCIA, NRO_SOLICITUD, COD_TAS_REF1,
                     VAL_TAS_REF1, COD_TAS_REF2, VAL_TAS_REF2,
                     REFERENCIA, COD_REF_GASTO)
                    values
                    (v_nro_cuenta, v_tra_car_mora, dat.cod_moneda, v_mto_car_mora,
                     v_fec_ini_vigencia, null, null,
                     dat.cod_modalidad, null, dat.cod_modulo,
                     v_fec_ini_vigencia, dat.nro_sol_nva, null,
                     null, null, null, 'GAMORESOL4', null);
                 end if;

                  --Insertar el cargo adicional por punitorio--
                 if nvl(v_mto_cuo_puni,0) > 0 then
                   v_mensaje := 'inserta pr_cta_gastos 2';
                   insert into pr_cta_gastos
                   (NRO_CUENTA, COD_TRANSACCION, COD_MONEDA, MONTO,
                    FEC_INGRESO, FEC_VENCIMIENTO, FEC_ULT_PAGO,
                    COD_MODALIDAD, HOR_ULT_PAGO, COD_MODULO,
                    FEC_INI_VIGENCIA, NRO_SOLICITUD, COD_TAS_REF1,
                    VAL_TAS_REF1, COD_TAS_REF2, VAL_TAS_REF2,
                    REFERENCIA, COD_REF_GASTO)
                   values
                   (v_nro_cuenta, v_tra_car_puni, dat.cod_moneda, v_mto_car_puni,
                    v_fec_ini_vigencia, null, null,
                    dat.cod_modalidad, null, dat.cod_modulo,
                    v_fec_ini_vigencia, dat.nro_sol_nva, null,
                    null, null, null, 'GAPURESOL4', null);
                 end if;
            end loop;
         end if;
      end if;

      --Actualizar datos de tabla espejo Resol4--
      v_mensaje := 'actualiza pr_cta_pre_ref_res4';
      IF dat.cod_sub_modalidad <> 97 THEN
        update pr_cta_pre_ref_res4 z
           set z.nro_cta_nueva = v_nro_cuenta,
               z.cod_mon_sol_nueva = dat.cod_moneda/*,
               z.cod_moneda = dat.cod_mon_ori*/
         where z.nro_sol_nueva = dat.nro_sol_nva;--z.nro_cuenta = dat.nro_cta_ori;
      ELSE -- actualiza fecha Ini RRR cuando es diferente a la fecha de sistema
         v_dia_dif := v_fec_actual - dat.fec_ini_sol;
         IF v_dia_dif > 0 THEN
            UPDATE pr_solicitudes
               SET fec_ini_rrr = fec_ini_rrr + v_dia_dif
             WHERE nro_solicitud = dat.nro_sol_nva;
            -- cuando la fecha de inicio es menor a la fecha sistema
            v_dia_dif := v_fec_actual - dat.fec_ini_cta;
            IF v_dia_dif > 0 THEN
               UPDATE pr_solicitudes
                  SET fec_inicio = fec_inicio + v_dia_dif,
                      fec_pri_vencimiento = fec_pri_vencimiento + v_dia_dif,
                      fec_vencimiento = fec_vencimiento + v_dia_dif
                WHERE nro_solicitud = dat.nro_sol_nva;
               UPDATE pr_sol_tasas
                  SET fec_vigencia = fec_vigencia + v_dia_dif
                WHERE nro_solicitud = dat.nro_sol_nva;
               UPDATE pr_cuotas
                  SET fec_vencimiento = fec_vencimiento + v_dia_dif
                WHERE nro_cuenta = v_nro_cuenta;
               UPDATE pr_sol_cuotas
                  SET fec_vto_habil = fec_vto_habil + v_dia_dif,
                      fec_vto_exacto = fec_vto_exacto + v_dia_dif
                WHERE nro_solicitud = dat.nro_sol_nva;
               UPDATE pr_cta_prestamos
                  SET fec_inicio = fec_inicio + v_dia_dif,
                      fec_vencimiento = fec_vencimiento + v_dia_dif
                WHERE nro_cuenta = v_nro_cuenta;
            END IF;
         END IF;
      END IF;
  end loop;
exception
  when others then
     raise_application_error(-20000,'ERROR: en prp_gen_car_esp_res4:'||v_mensaje||'-'||sqlerrm);
end;
/

