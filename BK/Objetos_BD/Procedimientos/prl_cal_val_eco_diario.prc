CREATE OR REPLACE PROCEDURE IT.PRL_CAL_VAL_ECO_DIARIO(p_nro_operacion in number default null) is

  --//--Creado por rpavon--12/10/2017--//
  --//--Proyecto: CNFNORMA-274-AJUSTES FORWARD--//
  --//--Para Calcular el Valor Economico de Operaciones Forward vigentes--//

  --Variables--
  v_fec_actual date;
  v_fec_pro_diario date;
  v_fec_ult_proceso date;
  v_fec_fin_proceso date;
  v_fec_fin_pro_aux date;
  v_fec_ult_mes date;
  v_fec_ult_mes_habil date;
  v_val_economico ge_movimientos.monto%type;
  v_val_eco_anterior ge_movimientos.monto%type;
  v_cot_cur_forward LC_FOR_CUR_FORWARD.VAL_COTIZACION%TYPE;
  v_val_cur_rendim LC_FOR_CUR_CUPONES.VAL_TASA%TYPE;
  v_can_dia_plz_residual number(6);
  v_val_fac_descuento number(20,9);
  v_monto lc_ope_futuras.monto%type;
  v_fec_auxiliar date;
  v_fec_anterior date;
  v_mto_gan_per_ml LC_FOR_DAT_VAL_ECONOMICO.MTO_GAN_PER_ML%type;
  v_can_dia_plz_total number(6);
  v_cod_mon_cur_rendim ba_monedas.cod_moneda%type;
  v_cod_mon_cur_forward ba_monedas.cod_moneda%type;
  v_dif_dias number(6);
  --Variables para asientos--
  v_mto_deb_perdida   cb_asientos.tot_control%type;
  v_mto_deb_activo    cb_asientos.tot_control%type;
  v_mto_deb_pasivo    cb_asientos.tot_control%type;
  v_mto_cre_ganancia  cb_asientos.tot_control%type;
  v_mto_cre_activo    cb_asientos.tot_control%type;
  v_mto_cre_pasivo    cb_asientos.tot_control%type;
  v_val_eco_ayer_aux    ge_movimientos.monto%type;
  v_val_eco_actual_aux  ge_movimientos.monto%type;
  v_mto_gan_per_ml_aux  ge_movimientos.monto%type;
  v_moc_deb_perdida  cb_asientos.tot_control%type;
  v_moc_cre_activo   cb_asientos.tot_control%type;
  v_moc_cre_ganancia cb_asientos.tot_control%type;
  v_moc_deb_pasivo   cb_asientos.tot_control%type;
  v_ind_dev_val_economico ge_par_dinamicos.val_parametro%type;

  --Cursor de Operaciones Vigentes--
  cursor c_ope_forward is
         select x.*
           from lc_ope_futuras x
          where x.fec_vencimiento >= v_Fec_actual
            and ((x.estado = 'N' and x.fec_liquidacion is null) or
                 (x.estado = 'L' and x.fec_liquidacion = v_fec_actual))
            and ((x.nro_operacion = p_nro_operacion) or (p_nro_operacion is null))
            and ((v_ind_dev_val_economico = 'N') or
                 (v_ind_dev_val_economico = 'S' and
                  not exists (select 1
                                from ba_cod_referencias z
                               where z.dominio = 'OPE_FUT_DEV_ANTERIOR'
                                 and z.val_minimo = x.nro_cuenta||'#'||x.nro_operacion)));

begin
  --Carga de Variables--
  pag_cal.pr_obt_dat_calendar(7);
  v_fec_actual := pag_cal.g_fec_actual;
  v_fec_ult_mes := pag_cal.g_ult_dia_mes;
  v_fec_ult_mes_habil := pag_cal.g_ult_dia_mes_habil;
  v_ind_dev_val_economico := nvl(fug_obt_pardinamico('IND_DEV_VAL_ECONOMICO'),'N');

  --Evaluacion de Fecha--
  if v_fec_actual = v_fec_ult_mes_habil then
     v_dif_dias := (v_fec_ult_mes - v_fec_actual);
     v_fec_fin_proceso := v_fec_actual + v_dif_dias;
  else
     v_fec_fin_proceso := v_fec_actual;
  end if;
  v_fec_fin_pro_aux := v_fec_fin_proceso;
  
  --Cursor por Operacion de Forward--
  FOR OPE IN C_OPE_FORWARD LOOP
      --Eliminar Datos Anteriores--
      delete from LC_FOR_DAT_VAL_ECONOMICO z
       where z.nro_cuenta = ope.nro_cuenta
         and z.nro_operacion = ope.nro_operacion
         and z.fecha = v_fec_actual;
      
      --Validacion de fecha final de proceso--
      v_fec_fin_proceso := v_fec_fin_pro_aux;
      IF v_fec_fin_proceso > ope.fec_vencimiento then
         v_fec_fin_proceso := ope.fec_vencimiento;
      end if;

      --Buscar la ultima fecha de proceso anterior--
      v_fec_ult_proceso := null;
      v_fec_pro_diario := null;
      select max(y.fec_calculo)
        into v_fec_ult_proceso
        from LC_FOR_DAT_VAL_ECONOMICO y
       where y.nro_cuenta = ope.nro_cuenta
         and y.nro_operacion = ope.nro_operacion;

      --Obtener fecha de procesamiento diario--
      if v_fec_ult_proceso is not null then
         v_fec_pro_diario := v_fec_ult_proceso + 1;
      else
         v_fec_pro_diario := v_fec_actual;
      end if;
      v_can_dia_plz_total := ope.fec_vencimiento - ope.fec_operacion;

      --Calcular 1 semana antes / BCP publica 1 sem. atrasado--
      if ope.cod_mad_transaccion = 72 then --Si es es Venta, es negativo--
         v_monto :=  ope.monto * (-1);
      else
         v_monto :=  ope.monto;
      end if;

      --Ciclo Principal--
      WHILE v_fec_pro_diario <= v_fec_fin_proceso
      LOOP
          v_fec_auxiliar := v_fec_pro_diario;
          v_can_dia_plz_residual := (ope.fec_vencimiento - ope.fec_operacion) - (v_fec_pro_diario - ope.fec_operacion);
          if v_fec_pro_diario = ope.fec_operacion then
             v_val_economico  := 0;
          elsif v_fec_pro_diario = ope.fec_vencimiento then
             v_cot_cur_forward := fug_obt_cotizacion(ope.cod_moneda, v_fec_pro_diario);
             v_val_economico   := round(v_monto * (v_cot_cur_forward - ope.cot_vencimiento));
          else
             v_cod_mon_cur_forward:= fug_obt_pardinamico('COD_MON_CUR_FORWARD',null,null,ope.cod_moneda);
             v_cot_cur_forward    := FUL_OBT_CUR_FORWARD(v_cod_mon_cur_forward, v_can_dia_plz_residual ,v_fec_auxiliar);
             v_cod_mon_cur_rendim := fug_obt_pardinamico('COD_MON_CUR_CUPON',null,null,ope.cod_moneda);
             v_val_cur_rendim     := FUL_OBT_CUR_CUPONES(v_cod_mon_cur_rendim,v_can_dia_plz_residual,v_fec_pro_diario);
             v_val_fac_descuento  := 1 /(1+(((v_val_cur_rendim * (v_can_dia_plz_residual / 365))/100)));
             v_val_economico      := round(v_monto * (v_cot_cur_forward - ope.cot_vencimiento) * v_val_fac_descuento);
          end if;

          --Buscar Valor Economico anterior--
          v_fec_anterior := v_fec_pro_diario - 1;
          v_val_eco_anterior := 0;
          select sum(nvl(k.val_economico,0))
            into v_val_eco_anterior
            from LC_FOR_DAT_VAL_ECONOMICO k
           where k.nro_cuenta = OPE.NRO_CUENTA
             and k.nro_operacion = OPE.NRO_OPERACION
             and k.fec_calculo = v_fec_anterior;

          --Calcular si es Ganancia o Perdida--
          v_mto_gan_per_ml := 0;
          v_mto_gan_per_ml := nvl(v_val_economico,0) - nvl(v_val_eco_anterior,0);

          --Inicio Calculo de Montos para Asientos--
          v_mto_deb_perdida  := 0;
          v_mto_deb_activo   := 0;
          v_mto_deb_pasivo   := 0;
          v_mto_cre_ganancia := 0;
          v_mto_cre_activo   := 0;
          v_mto_cre_pasivo   := 0;

          v_val_eco_ayer_aux    := nvl(v_val_eco_anterior,0);
          v_val_eco_actual_aux  := nvl(v_val_economico,0);
          v_mto_gan_per_ml_aux  := nvl(v_mto_gan_per_ml,0);

          /*if ope.cod_mad_transaccion = 72 then --Es una Venta--
             v_val_eco_ayer_aux    := v_val_eco_ayer_aux * -1;
             v_val_eco_actual_aux  := v_val_eco_actual_aux * -1;
             v_mto_gan_per_ml_aux  := v_mto_gan_per_ml_aux * -1;
          end if;*/

          if nvl(v_val_eco_ayer_aux,0) >= 0 then --VE Ayer era Activo--
             if nvl(v_val_eco_actual_aux,0) >= 0 then --VE Actual es Activo--
                if nvl(v_mto_gan_per_ml_aux,0) >= 0 then
                   --Ganancia--
                   v_mto_cre_ganancia := abs(nvl(v_mto_gan_per_ml_aux,0));
                   v_mto_deb_activo   := abs(nvl(v_mto_gan_per_ml_aux,0));
                else
                   --Perdida--
                   v_mto_deb_perdida := abs(nvl(v_mto_gan_per_ml_aux,0));
                   v_mto_cre_activo  := abs(nvl(v_mto_gan_per_ml_aux,0));
                end if;
             else --VE Acual es Pasivo--
                v_mto_deb_perdida := abs(nvl(v_mto_gan_per_ml_aux,0));
                v_mto_cre_activo  := abs(nvl(v_val_eco_ayer_aux,0));
                v_mto_cre_pasivo  := abs(nvl(v_val_eco_actual_aux,0));
             end if;
          else --VE Ayer era Pasivo--
             if nvl(v_val_eco_actual_aux,0) <= 0 then --VE Actual es Pasivo--
                if nvl(v_mto_gan_per_ml_aux,0) <= 0 then
                   --Perdida--
                   v_mto_deb_perdida := abs(nvl(v_mto_gan_per_ml_aux,0));
                   v_mto_cre_pasivo  := abs(nvl(v_mto_gan_per_ml_aux,0));
                else
                   --Ganancia--
                   v_mto_cre_ganancia := abs(nvl(v_mto_gan_per_ml_aux,0));
                   v_mto_deb_pasivo   := abs(nvl(v_mto_gan_per_ml_aux,0));
                end if;
             else --VE Acual es Activo--
                v_mto_cre_ganancia := abs(nvl(v_mto_gan_per_ml_aux,0));
                v_mto_deb_activo   := abs(nvl(v_val_eco_actual_aux,0));
                v_mto_deb_pasivo   := abs(nvl(v_val_eco_ayer_aux,0));
             end if;
          end if;
          --Fin Calculo de Montos para Asientos--

          --Inicio Calculo de Asiento de Cancelacion--
          v_moc_deb_perdida := 0;
          v_moc_cre_activo  := 0;
          v_moc_cre_ganancia := 0;
          v_moc_deb_pasivo  := 0;
          if v_fec_pro_diario = ope.fec_vencimiento then
             if nvl(v_val_eco_actual_aux,0) >= 0 then --VE Actual es Activo--
                --Contra-asiento de Perdida--
                v_moc_deb_perdida := abs(nvl(v_val_eco_actual_aux,0));
                v_moc_cre_activo  := abs(nvl(v_val_eco_actual_aux,0));
             else --VE Actual es Pasivo--
                --Contra-asiento de Ganancia--
                v_moc_cre_ganancia := abs(nvl(v_val_eco_actual_aux,0));
                v_moc_deb_pasivo   := abs(nvl(v_val_eco_actual_aux,0));
             end if;
          end if;
          --Fin Calculo de Asiento de Cancelacion--

          --Insertar los datos del calculo diario--
          insert into LC_FOR_DAT_VAL_ECONOMICO
          (fecha, nro_cuenta, nro_operacion, cod_moneda, monto,
           val_cot_contrato, can_dia_plz_residual, val_cur_forward, val_cur_cupon,
           val_fac_descuento, val_economico, mto_gan_per_ml, val_cot_vencimiento,
           mto_ope_calculo, fec_operacion, fec_vencimiento, can_dia_plz_total,
           fec_calculo, cod_persona, cod_mad_transaccion, cod_tip_ope_bcp,
           tip_liquidacion, mto_deb_perdida, mto_deb_activo, mto_deb_pasivo,
           mto_cre_ganancia, mto_cre_activo, mto_cre_pasivo,
           moc_deb_perdida, moc_cre_activo, moc_cre_ganancia, moc_deb_pasivo)
          values
          (v_fec_actual, ope.nro_cuenta, ope.nro_operacion, ope.cod_moneda, ope.monto,
           ope.cotizacion, v_can_dia_plz_residual, v_cot_cur_forward, v_val_cur_rendim,
           v_val_fac_descuento, v_val_economico, v_mto_gan_per_ml, ope.cot_vencimiento,
           v_monto, ope.fec_operacion, ope.fec_vencimiento, v_can_dia_plz_total,
           v_fec_pro_diario, ope.cod_persona, ope.cod_mad_transaccion, ope.cod_tip_ope_bcp,
           ope.tip_liquidacion, v_mto_deb_perdida, v_mto_deb_activo, v_mto_deb_pasivo,
           v_mto_cre_ganancia, v_mto_cre_activo, v_mto_cre_pasivo,
           v_moc_deb_perdida, v_moc_cre_activo, v_moc_cre_ganancia, v_moc_deb_pasivo);
          v_fec_pro_diario := v_fec_pro_diario + 1;
      END LOOP;
  END LOOP;
EXCEPTION
   WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20000,'Error en PRL_CAL_VAL_ECO_DIARIO - '||SQLERRM);
END;
/

