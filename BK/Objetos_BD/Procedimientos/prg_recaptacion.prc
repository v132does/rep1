CREATE OR REPLACE PROCEDURE IT.PRG_RECAPTACION ( P_REF_LOTE IN NUMBER,
                                              P_PROCESADO OUT VARCHAR2)
IS
  v_dias_atraso    number;
  v_saldo_atraso   number;
  v_hora           varchar2(8);
  v_fec_prev       date;
  v_mon_previ      number;
  v_por_prevision  number;
  v_sal_capital    number;
  v_dev_no_cobrado number;

  cursor c_productos is
  select *
    from ge_sal_inv_vta_cartera_his a
   where a.ope_recaptados = 'P'
     and a.ref_lote  = nvl(p_ref_lote, a.ref_lote);
BEGIN
  P_PROCESADO := 'NO';
  v_hora := to_char(SYSDATE, 'hh24:mi:ss');
  v_fec_prev := pag_cal.FU_OBT_FEC_ANTERIOR(1);
  FOR reg IN c_productos LOOP
    if reg.cod_modulo = 6 then
      v_hora := fug_obt_hor_disponible(pag_cal.FU_OBT_FEC_ACTUAL(1),v_hora,user,'N');
      begin
        PRG_REV_OPERACION(reg.fec_venta,
                          reg.hor_cancelacion,
                          reg.usu_venta,
                          6,
                          reg.cod_modalidad,
                          359,
                          user,
                          v_hora,
                          'N',
                          'REINGRESO EN TIEMPO DE GARANTIA DE VENTA DE CARTERA');
      exception
        when others then
          raise_application_error(-20000,'Error en PRG_REV_OPERACION '||Sqlerrm);
      end;
      begin
        select a.MONTO
          into v_mon_previ
          from gv_movimientos a
         where a.FECHA = reg.fec_venta
           and a.HORA = reg.hor_cancelacion
           and a.COD_TRA_PADRE = 359
           and a.COD_TRANSACCION = 957;
      exception
         WHEN OTHERS THEN
           raise_application_error(-20000,'Error obtener monto prevision de Préstamo '||Sqlerrm);
      end;

      /*Reactivar la Previsión anterior a la venta*/
      begin
        select a.sal_capital, a.dev_no_cobrado, a.porcentaje
          into v_sal_capital, v_dev_no_cobrado, v_por_prevision
          from pr_previsiones a
         where a.fecha = (select max(b.fecha)
                            from pr_previsiones b
                           where b.nro_cuenta = a.nro_cuenta
                             and b.nro_cuenta = reg.nro_cuenta
                             and b.fecha < reg.fec_venta);
      exception
        when no_data_found then
          v_por_prevision := round(((v_mon_previ/reg.mto_deuda) * 100),2);
      end;
      --
      begin
        INSERT INTO pr_previsiones(fecha, nro_cuenta, monto, sal_capital, dev_no_cobrado, porcentaje, tot_gar_computables, tot_pri_prevision)
        VALUES (v_fec_prev, reg.nro_cuenta, v_mon_previ, nvl(v_sal_capital,reg.mto_deu_mon_cuenta), nvl(v_dev_no_cobrado,0), v_por_prevision, 0, 0);
      exception --HO - Se realiza un update en caso de que la fecha anterior conincida con la fecha de venta de la cartera
        when dup_val_on_index then
          update pr_previsiones
             set monto               = v_mon_previ,
                 sal_capital         = nvl(v_sal_capital,reg.mto_deu_mon_cuenta),
                 dev_no_cobrado      = nvl(v_dev_no_cobrado,0),
                 porcentaje          = v_por_prevision,
                 tot_gar_computables = 0,
                 tot_pri_prevision   = 0
           where fecha      = v_fec_prev
             and nro_cuenta = reg.nro_cuenta;
      end;
	  
      -- Actualizar mto. int. descontado.
      begin
        update pr_cuotas a
           set a.mto_int_descontado = 0
         where a.nro_cuenta = reg.nro_cuenta
           and a.fec_vencimiento >= reg.fec_venta;
      exception
        when no_data_found then
          null;
      end;
    elsif reg.cod_modulo = 5 then
      BEGIN
        --se obtienen los dias de atraso y el saldo en deuda
        select nvl(b.dia_atrasos,0), b.mto_deu_mon_cuenta
          into v_dias_atraso, v_saldo_atraso
          from ge_sal_inv_vta_cartera_his b
         where b.ref_lote    = reg.ref_lote
           and b.nro_cuenta  = reg.nro_cuenta
           and b.cod_persona = reg.cod_persona;
      EXCEPTION
        WHEN OTHERS THEN
          v_dias_atraso := 1;
          v_saldo_atraso := 1;
      END;

      insert into TA_MOV_ESPECIALES_TMP (NRO_CUENTA, NRO_TARJETA, DIG_VERIFICADOR, DES_MOVIMIENTO, MTO_OPERACION)
      values (reg.nro_cuenta, reg.nro_tarjeta, 0, 'PASEAVENCIDA', v_saldo_atraso);

      Update ta_cta_tarjetas
         set dia_mora = v_dias_atraso,
             estado = 'P'
       Where nro_cuenta = reg.nro_cuenta;

      --procedimiento principal para tarjetas
      prg_rec_tarjetas(reg.nro_cuenta);

      Update ta_cta_tarjetas
         set estado = 'C'
       Where nro_cuenta = reg.nro_cuenta;

    elsif reg.cod_modulo = 4 then
      BEGIN
        --se obtienen los dias de atraso y el saldo en deuda
        select b.dia_atrasos, b.mto_deu_mon_cuenta
          into v_dias_atraso, v_saldo_atraso
          from ge_sal_inv_vta_cartera_his b
         where b.ref_lote    = reg.ref_lote
           and b.nro_cuenta  = reg.nro_cuenta
           and b.cod_persona = reg.cod_persona;
      EXCEPTION
        WHEN OTHERS THEN
          v_dias_atraso := 1;
          v_saldo_atraso := 1;
      END;
      --
      Update cc_cta_corrientes c
         set c.estado = 'P'
       Where c.nro_cuenta = reg.nro_cuenta;
      --
      begin
        PRG_REV_OPERACION(reg.fec_venta,
                          reg.hor_cancelacion,
                          reg.usu_venta,
                          reg.cod_modulo,
                          reg.cod_modalidad,
                          8843,
                          user,
                          v_hora,
                          'N',
                          'RECAPTACION VENTA DE CARTERA');
      exception
        when others then
          raise_application_error(-20000,'Error en PRG_REV_OPERACION '||Sqlerrm);
      end;
      --
      begin
        PRG_REV_OPERACION(reg.fec_venta,
                          reg.hor_cancelacion,
                          reg.usu_venta,
                          reg.cod_modulo,
                          reg.cod_modalidad,
                          8846,
                          user,
                          v_hora,
                          'N',
                          'RECAPTACION CUENTA DE ORDEN VENTA DE CARTERA');
      exception
        when others then
          raise_application_error(-20000,'Error en PRG_REV_OPERACION '||Sqlerrm);
      end;
      --La reactivacion de la prevision se realiza en el PRG_RECAP_SOBREGIRO
      --procedimiento principal para Sobregiros
      PRG_REC_SOBREGIROS(reg.nro_cuenta, v_dias_atraso, reg.ref_lote);

    elsif reg.cod_modulo = 15 then
      v_hora := fug_obt_hor_disponible(pag_cal.FU_OBT_FEC_ACTUAL(1),v_hora,user,'N');
      begin
        PRG_REV_OPERACION(reg.fec_venta,
                          reg.hor_cancelacion,
                          reg.usu_venta,
                          reg.cod_modulo,
                          reg.cod_modalidad,
                          139,
                          user,
                          v_hora,
                          'N',
                          'REINGRESO EN TIEMPO DE GARANTIA DE VENTA DE CARTERA');
      exception
        when others then
          raise_application_error(-20000,'Error en PRG_REV_OPERACION '||Sqlerrm);
      end;
      begin
        select a.MONTO
          into v_mon_previ
          from gv_movimientos a
         where a.FECHA = reg.fec_venta
           and a.HORA = reg.hor_cancelacion
           and a.COD_TRA_PADRE = 139
           and a.COD_TRANSACCION = 957;
      exception
         WHEN OTHERS THEN
           raise_application_error(-20000,'Error obtener monto prevision de Ope. Vencida '||Sqlerrm);
      end;
      v_por_prevision := round(((v_mon_previ/reg.mto_deuda) * 100),2);

      begin
        INSERT INTO ov_previsiones(fecha, nro_cuenta, monto, saldo, porcentaje, tot_gar_computables, tot_pri_prevision)
        VALUES (v_fec_prev, reg.nro_cuenta, v_mon_previ, reg.mto_deu_mon_cuenta, v_por_prevision, 0, 0);
      exception --HO - Se realiza un update en caso de que la fecha anterior conincida con la fecha de venta de la cartera
        when dup_val_on_index then
          update ov_previsiones
             set monto               = v_mon_previ,
                 saldo               = reg.mto_deu_mon_cuenta,
                 porcentaje          = v_por_prevision,
                 tot_gar_computables = 0,
                 tot_pri_prevision   = 0
           where fecha      = v_fec_prev
             and nro_cuenta = reg.nro_cuenta;
      end;

    end if;

    --Se pasa el campo OPE_RECAPTADOS del estado 'P' al 'S'
    update ge_sal_inv_vta_cartera_his a
       set ope_recaptados = 'S'
     where a.nro_cuenta = reg.nro_cuenta
       and a.ref_lote  = nvl(p_ref_lote, a.ref_lote);
    EXIT WHEN c_productos%NOTFOUND;
  END LOOP;
  --se carga el mensaje de que se concluyó el proceso de recaptacion
    P_PROCESADO := 'OK';
EXCEPTION
      When Others Then
           raise_application_error(-20000,'Error PRG_RECAPTACION '||Sqlerrm);
END;
/

