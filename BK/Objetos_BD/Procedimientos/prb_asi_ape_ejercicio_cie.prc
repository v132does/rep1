CREATE OR REPLACE PROCEDURE IT.PRB_ASI_APE_EJERCICIO_CIE is
    ---------
  v_fec_actual            date        := pag_cal.fu_obt_fec_actual(2);
  v_ano_actual            number(4)   := to_char(v_fec_actual,'yyyy');
  v_mes_actual            number(2)   := to_char(v_fec_actual,'mm');
  v_fec_anterior          date;     --:= v_fec_actual - 1;
  v_sal_mon_local         NUMBER;
  v_cod_rub_ganancia      varchar2(15);
  v_cod_rub_perdida       varchar2(15);
  v_cod_ofi_matriz        number(4);
  v_nro_lin_matriz        number(4);
  v_nro_asiento           cb_asientos.nro_asiento%type;
  v_nro_asi_matriz        cb_asientos.nro_asiento%type;
  v_cod_rub_ord           cb_rubros.cod_rubro%type := '510106530100199'; -- rubro de SF
  v_referencia            cb_asientos_det.referencia%type;
  v_es_asi_orden          varchar2(1);

  v_importe               NUMBER;
  v_imp_matriz            number;
  v_cod_rub_debito        varchar2(15);
  v_cod_rub_credito       varchar2(15);
  v_cod_ofi_utilidad      number(3);
  v_cod_rubro             varchar2(15);

  cursor c_uti_acumulada is
  SELECT b.cod_oficina,
         sum(NVL(SAL_MON_LOC_ANT,0)+NVL(DEB_MON_LOCAL,0)-NVL(CRE_MON_LOCAL,0)) sal_mon_local
      --INTO   v_sal_mon_local
    FROM   CB_RUBROS a,  APE_CB_SAL_OFICINAS b
   WHERE  b.COD_RUBRO in ('310504160100199','310504200100199') --Ctas de Utilidad Acumulada--
     AND  IMPUTABLE = 'S'
     AND  a.COD_RUBRO = b.COD_RUBRO
     AND  ANO = v_ano_actual
     AND  MES = v_mes_actual
     AND B.COD_OFICINA <> v_cod_ofi_matriz
   group by b.cod_oficina
   order by b.cod_oficina;

  PROCEDURE LP_GEN_ASI_APERTURA IS
     v_cod_oficina    cb_asientos.cod_oficina%type;
     v_fec_his        cb_asientos.fecha%type;
     v_nro_asi_his    cb_asientos.nro_asiento%type;
     v_nro_asiento    cb_asientos.nro_asiento%type;
     v_tip_movimiento varchar2(1);
     v_tip_mov_contra varchar2(1);
     v_cod_rub_contra varchar2(20);
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
                     and (det.referencia = 'CIE.CT.PAT'
                      or  det.referencia = 'CIE.CT.CON'
                      or  det.referencia = 'CIE.CT.ORD'))
      and fecha = v_fec_anterior;
     --- Cursor de detalles
     cursor c_detalle_asientos is
     select * from cb_asientos_det_his
     where cod_oficina = v_cod_oficina
     and fecha = v_fec_his
     and nro_asiento = v_nro_asi_his
     and (referencia = 'CIE.CT.PAT'
      or  referencia = 'CIE.CT.CON'
      or  referencia = 'CIE.CT.ORD');
  BEGIN
     v_nro_asiento := fug_obt_pardinamico('SIG_NRO_ASIENTO');
     v_nro_asiento := v_nro_asiento - 1;
     ---
     select max(det.fecha) 
       into v_fec_anterior
       from cb_asientos_det_his det
      where (det.referencia = 'CIE.CT.PAT'
         or  det.referencia = 'CIE.CT.CON'
         or  det.referencia = 'CIE.CT.ORD');
     FOR reg in c_asientos_cierre loop
        v_cod_oficina := reg.cod_oficina;
        v_fec_his     := reg.fecha;
        v_nro_asi_his := reg.nro_asiento;
        v_nro_asiento := v_nro_asiento + 1;
        v_tot_control := 0;
        v_tot_mto_debito  := 0;
        v_tot_mto_credito := 0;
        v_es_asi_orden    := null;
        for det in c_detalle_asientos loop
           if v_es_asi_orden is null then
              if det.referencia = 'CIE.CT.ORD' then
                 v_es_asi_orden := 'S';
               else
                 v_es_asi_orden := 'N';
              end if;
           end if;
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
              v_cod_rubro := '310504160100199'; --Cambiar por Utilidades Acumuladas--
           elsif v_cod_rubro = v_cod_rub_perdida then
              v_cod_rubro := '310504200100199'; --Cambiar por Perdidas Acumuladas--
           end if;
           --- Insertar asiento
           v_nro_linea := v_nro_linea + 1;
           --
           INSERT INTO CB_ASIENTOS_DET
               (COD_OFICINA, FECHA, NRO_ASIENTO, NRO_LINEA,
                COD_RUBRO, MTO_MON_LOCAL, MTO_MON_RUBRO,
                TIP_MOVIMIENTO, DESCRIPCION, ACTUALIZADO,
                REFERENCIA, fec_valor)
           VALUES
                (v_cod_oficina, v_fec_actual, v_nro_asiento, v_nro_linea,
                 v_cod_rubro, det.mto_mon_local, det.mto_mon_rubro,
                 v_tip_movimiento, 'Apertura de Ejercicio','N',
                 'Apertura', v_fec_actual);
        end loop;

        IF v_tot_control > 0 THEN
           INSERT INTO CB_ASIENTOS
                  (COD_OFICINA, NRO_ASIENTO, COD_USUARIO,
                   FECHA, COD_MODULO, COD_MODALIDAD, TOT_CONTROL,
                   ACTUALIZADO, REVERSADO, COD_OFI_ORIGEN, CONFIRMADO,
                   OFI_INTEGRADA, fec_valor)
           VALUES (v_cod_oficina, v_nro_asiento, user,
                   v_fec_actual, 2, 21, v_tot_control,
                   'N', 'N', v_cod_oficina, 'S', 'N', v_fec_actual);
        END IF;

     END LOOP;
     ---------------------------------------
     ---Actualizo el sgte. nro de asiento---
     ---------------------------------------
     prg_act_par_dinamico('SIG_NRO_ASIENTO',null, null, null, null, v_nro_asiento + 1);
  END;
BEGIN
    v_cod_rub_ganancia := fug_obt_pardinamico('COD_RUB_GANANCIAS',2, 21, pag_gen.FU_OBT_MON_LOCAL);
    v_cod_rub_perdida  := fug_obt_pardinamico('COD_RUB_PERDIDAS',2, 21, pag_gen.FU_OBT_MON_LOCAL);
    LP_GEN_ASI_APERTURA;
    prb_act_saldos_ape;
    prb_sum_sal_oficinas_ape; -- Solo para BBVA - 04/01/2012
    prb_sum_sal_consolidados_ape;

    ----------------------------------------------------
    --- Generar asiento de Transferencia de Utilidad ---
    ----------------------------------------------------
    if fug_obt_tip_implementacion <> 1 then --- BBVA no aplica - 04/01/2012
        v_nro_asi_matriz := fug_obt_pardinamico('SIG_NRO_ASIENTO');
        v_nro_asiento := v_nro_asi_matriz;
        select cod_ofi_matriz into v_cod_ofi_matriz from ge_par_generales;
        v_imp_matriz := 0;
        v_nro_lin_matriz := 0;
        for uti in c_uti_acumulada loop
            v_nro_asiento := v_nro_asiento + 1;
            v_sal_mon_local := uti.sal_mon_local;
            v_cod_ofi_utilidad := uti.cod_oficina;
            IF v_sal_mon_local < 0 THEN
               --Ganancias--
               --v_cod_rub_debito  := v_cod_rub_ganancia;
               v_cod_rub_debito := '150102570400199';
               v_cod_rub_credito := '310504160100199';   -- utilidad acumulada --
               v_importe         := nvl(v_sal_mon_local,0) *-1;
            ELSE
               --Pérdidas--
               v_cod_rub_debito  := '310504200100199';
               --v_cod_rub_credito := v_cod_rub_perdida;   -- perdida acumulada --
               v_cod_rub_credito := '150102570400199';
               v_importe         := nvl(v_sal_mon_local,0);
            END IF;
            v_imp_matriz := nvl(v_imp_matriz,0) + nvl(v_importe,0);
            ------------------------------------------------------
            ---Asiento para la Oficina a traspasar----------------
            ------------------------------------------------------
            INSERT INTO CB_ASIENTOS_DET
                (COD_OFICINA, NRO_ASIENTO, FECHA, NRO_LINEA,
                 COD_RUBRO, MTO_MON_LOCAL, MTO_MON_RUBRO,
                 TIP_MOVIMIENTO, DESCRIPCION, ACTUALIZADO, fec_valor)
            VALUES
                (v_cod_ofi_utilidad, v_nro_asiento, v_fec_actual, 1,
                 v_cod_rub_debito, v_importe, NULL,
                 'C', 'ASIENTO DE PASE DE SALDO','N', v_fec_actual);
            -- linea dos
            ------------------------------------------------------
            INSERT INTO CB_ASIENTOS_DET
                (COD_OFICINA, NRO_ASIENTO, FECHA, NRO_LINEA,
                 COD_RUBRO, MTO_MON_LOCAL, MTO_MON_RUBRO,
                 TIP_MOVIMIENTO, DESCRIPCION, ACTUALIZADO, fec_valor)
            VALUES
                (v_cod_ofi_utilidad, v_nro_asiento, v_fec_actual, 2,
                 v_cod_rub_credito, v_importe,
                 NULL, 'D','ASIENTO DE PASE DE SALDO','N', v_fec_actual);
            -- inserta cabecera --
            ----------------------
            INSERT INTO CB_ASIENTOS
               (COD_OFICINA, NRO_ASIENTO, COD_USUARIO,
                FECHA, COD_MODULO, COD_MODALIDAD, TOT_CONTROL,
                ACTUALIZADO, REVERSADO, COD_OFI_ORIGEN,
                OFI_INTEGRADA, CONFIRMADO, fec_valor)
            VALUES
               (v_cod_ofi_utilidad, v_nro_asiento,
                user, v_fec_actual, 2, 21,v_importe * 2,
                'N', 'N', v_cod_ofi_utilidad, 'N', 'S', v_fec_actual);

            -----------------------------------------------
            --- Asiento para Casa Matriz-------------------
            -----------------------------------------------
            v_nro_lin_matriz := v_nro_lin_matriz + 1;
            INSERT INTO CB_ASIENTOS_DET
                (COD_OFICINA, NRO_ASIENTO, FECHA, NRO_LINEA,
                 COD_RUBRO, MTO_MON_LOCAL, MTO_MON_RUBRO,
                 TIP_MOVIMIENTO, DESCRIPCION, ACTUALIZADO, fec_valor)
            VALUES
                (v_cod_ofi_matriz, v_nro_asi_matriz, v_fec_actual, v_nro_lin_matriz,
                 v_cod_rub_credito, v_importe, NULL,
                 'C', 'ASIENTO DE PASE DE SALDO','N', v_fec_actual);
            -- linea dos
            ------------------------------------------------------
            v_nro_lin_matriz := v_nro_lin_matriz + 1;
            INSERT INTO CB_ASIENTOS_DET
                (COD_OFICINA, NRO_ASIENTO, FECHA, NRO_LINEA,
                 COD_RUBRO, MTO_MON_LOCAL, MTO_MON_RUBRO,
                 TIP_MOVIMIENTO, DESCRIPCION, ACTUALIZADO, fec_valor)
            VALUES
                (v_cod_ofi_matriz, v_nro_asi_matriz, v_fec_actual, v_nro_lin_matriz,
                 v_cod_rub_debito, v_importe,
                 NULL, 'D','ASIENTO DE PASE DE SALDO','N', v_fec_actual);
       end loop;
       --------------------------------
       --Inserta cabecera casa matriz--
       --------------------------------
       INSERT INTO CB_ASIENTOS
       (COD_OFICINA, NRO_ASIENTO, COD_USUARIO,
        FECHA, COD_MODULO, COD_MODALIDAD, TOT_CONTROL,
        ACTUALIZADO, REVERSADO, COD_OFI_ORIGEN,
        OFI_INTEGRADA, CONFIRMADO, fec_valor)
       VALUES
       (v_cod_ofi_matriz, v_nro_asi_matriz,
        user, v_fec_actual, 2, 21,v_imp_matriz * 2,
        'N', 'N', v_cod_ofi_matriz, 'N', 'S', v_fec_actual);

       -----------------------------------
       --Actualiza parametro de Asientos--
       -----------------------------------
       prg_act_par_dinamico('SIG_NRO_ASIENTO',null, null, null, null, v_nro_asiento + 1 );
   end if;
END;
/

