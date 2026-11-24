create or replace procedure it.prb_asi_ape_ejercicio is
    ---------
  v_fec_actual            cb_asientos.fecha%type := pag_cal.fu_obt_fec_actual(2);
  v_ano_actual            number(4)   := to_char(v_fec_actual,'yyyy');
  v_cod_rub_ganancia      cb_asientos_det.cod_rubro%type;
  v_cod_rub_perdida       cb_asientos_det.cod_rubro%type;
  v_cod_rub_uti_acu       cb_asientos_det.cod_rubro%type;
  v_cod_rub_per_acu       cb_asientos_det.cod_rubro%type;
  v_nro_asiento           cb_asientos_det.nro_asiento%type;
  v_cod_rubro             cb_asientos_det.cod_rubro%type;
  v_mon_local             ba_monedas.cod_moneda%type := pag_gen.fu_obt_mon_local;
  v_cer_cta_patrimonial   varchar2(1) := nvl(fug_obt_pardinamico('CON_CER_CTA_PATRIMONIAL'),'N');

  PROCEDURE LP_GEN_ASI_APERTURA IS
     v_cod_oficina    cb_asientos.cod_oficina%type;
     v_fec_his        cb_asientos.fecha%type;
     v_nro_asi_his    cb_asientos.nro_asiento%type;
     v_nro_asiento    cb_asientos.nro_asiento%type;
     v_tip_movimiento cb_asientos_det.tip_movimiento%type;
     v_tot_control    cb_asientos.tot_control%type := 0;
     v_tot_mto_debito cb_asientos.tot_control%type := 0;
     v_tot_mto_credito cb_asientos.tot_control%type := 0;
     v_nro_linea       cb_asientos_det.nro_linea%type := 0;
     --- Cursor de ultimo asiento del historico
     cursor c_asientos_cierre is
     select * from cb_asientos_his cab
     where exists (select 1 from cb_asientos_det_his det
                   where cab.fecha = det.fecha
                     and cab.cod_oficina = det.cod_oficina
                     and cab.nro_asiento = det.nro_asiento
                     and (det.referencia = 'CIE.CT.PAT' or
                          det.referencia = 'CIE.CT.CON' or
                          det.referencia = 'CIE.CT.ORD'))

      and fecha >= to_date('01/01/'||(v_ano_actual-1),'DD/MM/YYYY');
     --- Cursor de detalles
     cursor c_detalle_asientos is
     select * from cb_asientos_det_his
     where cod_oficina = v_cod_oficina
     and fecha = v_fec_his
     and nro_asiento = v_nro_asi_his
     and (referencia = 'CIE.CT.PAT' or
          referencia = 'CIE.CT.CON' or
          referencia = 'CIE.CT.ORD');

  BEGIN
     v_nro_asiento := fug_obt_pardinamico('SIG_NRO_ASIENTO');
     v_nro_asiento := v_nro_asiento - 1;
     FOR reg in c_asientos_cierre loop
        v_cod_oficina := reg.cod_oficina;
        v_fec_his     := reg.fecha;
        v_nro_asi_his := reg.nro_asiento;
        v_nro_asiento := v_nro_asiento + 1;
        v_tot_control := 0;
        v_tot_mto_debito  := 0;
        v_tot_mto_credito := 0;
        for det in c_detalle_asientos loop
           v_tot_control := v_tot_control + nvl(det.mto_mon_local,0);
           if det.tip_movimiento = 'C' then
              v_tot_mto_debito := v_tot_mto_debito + nvl(det.mto_mon_local,0);
              v_tip_movimiento := 'D';
           else
              v_tot_mto_credito := v_tot_mto_credito + nvl(det.mto_mon_local,0);
              v_tip_movimiento := 'C';
           end if;
           --Evaluar Rubro de Ganancia o Perdidas--
           v_cod_rubro := det.cod_rubro;
           if v_cod_rubro = v_cod_rub_ganancia then
              v_cod_rubro := v_cod_rub_uti_acu;--Utilidades Acumuladas
           elsif v_cod_rubro = v_cod_rub_perdida then
              v_cod_rubro := v_cod_rub_per_acu; --Perdidas Acumuladas
           end if;
           --- Insertar asiento
           v_nro_linea := v_nro_linea + 1;
           --
           If nvl(v_cer_cta_patrimonial,'N') = 'S' then
             INSERT INTO CB_ASIENTOS_DET
                 (COD_OFICINA, FECHA, NRO_ASIENTO, NRO_LINEA,
                  COD_RUBRO, MTO_MON_LOCAL, MTO_MON_RUBRO,
                  TIP_MOVIMIENTO, DESCRIPCION, ACTUALIZADO,
                  REFERENCIA,fec_valor)
             VALUES
                  (v_cod_oficina, v_fec_actual, v_nro_asiento, v_nro_linea,
                   v_cod_rubro, det.mto_mon_local, det.mto_mon_rubro,
                   v_tip_movimiento, 'Apertura de Ejercicio','N',
                   'Apertura',v_fec_actual);
           else
             INSERT INTO CB_ASIENTOS_DET
                 (COD_OFICINA, FECHA, NRO_ASIENTO, NRO_LINEA,
                  COD_RUBRO, MTO_MON_LOCAL, MTO_MON_RUBRO,
                  TIP_MOVIMIENTO, DESCRIPCION, ACTUALIZADO,
                  REFERENCIA,fec_valor)
             VALUES
                  (v_cod_oficina, v_fec_actual, v_nro_asiento, v_nro_linea,
                   det.cod_rubro, det.mto_mon_local, det.mto_mon_rubro,
                   v_tip_movimiento, 'Apertura de Ejercicio','N',
                   'Apertura',v_fec_actual);
             -- contrapartida
             v_nro_linea := v_nro_linea + 1;

             INSERT INTO CB_ASIENTOS_DET
                 (COD_OFICINA, FECHA, NRO_ASIENTO, NRO_LINEA,
                  COD_RUBRO, MTO_MON_LOCAL, MTO_MON_RUBRO,
                  TIP_MOVIMIENTO, DESCRIPCION, ACTUALIZADO,
                  REFERENCIA,fec_valor)
             VALUES
                  (v_cod_oficina, v_fec_actual, v_nro_asiento, v_nro_linea,
                   v_cod_rubro, det.mto_mon_local, det.mto_mon_rubro,
                   det.tip_movimiento, 'Apertura de Ejercicio','N',
                   'Apertura',v_fec_actual);
          End if;
        end loop;

        IF v_tot_control > 0 THEN
           INSERT INTO CB_ASIENTOS
                  (COD_OFICINA, NRO_ASIENTO, COD_USUARIO,
                   FECHA, COD_MODULO, COD_MODALIDAD, TOT_CONTROL,
                   ACTUALIZADO, REVERSADO, COD_OFI_ORIGEN, CONFIRMADO,
                   OFI_INTEGRADA)
           VALUES (v_cod_oficina, v_nro_asiento, user,
                   v_fec_actual, 2, 21, v_tot_control,
                   'N', 'N', v_cod_oficina, 'S', 'N');
        END IF;

     END LOOP;
     ---------------------------------------
     ---Actualizo el sgte. nro de asiento---
     ---------------------------------------
     prg_act_par_dinamico('SIG_NRO_ASIENTO',null, null, null, null, v_nro_asiento + 1);
  END;
BEGIN
    v_cod_rub_ganancia := fug_obt_pardinamico('COD_RUB_GANANCIAS',2, 21, v_mon_local);
    v_cod_rub_perdida  := fug_obt_pardinamico('COD_RUB_PERDIDAS',2, 21, v_mon_local);
    v_cod_rub_uti_acu  := fug_obt_pardinamico('CON_RUB_UTI_ACUMULADAS',2, 21, v_mon_local);
    v_cod_rub_per_acu  := fug_obt_pardinamico('CON_RUB_PER_ACUMULADAS',2, 21, v_mon_local);

    LP_GEN_ASI_APERTURA;
    prb_act_saldos;
    prb_sum_sal_oficinas;
    prb_sum_sal_consolidados;
END;
/
