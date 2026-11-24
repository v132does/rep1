CREATE OR REPLACE PROCEDURE IT.PRB_ASI_CIE_EJERCICIO IS
  v_fec_actual     date        := pag_cal.fu_obt_fec_actual(2);
  v_ano_actual     number(4)   := to_char(v_fec_actual,'yyyy');
  v_mes_actual     number(2)   := to_char(v_fec_actual,'mm');
  v_tip_inicial    cb_rubros.tipo%type;
  v_tip_final      cb_rubros.tipo%type;
  CURSOR OFIC is
     SELECT DISTINCT COD_OFICINA
       FROM CB_SAL_OFICINAS
      WHERE ANO = v_ano_actual
        AND MES = v_mes_actual;
  --- Saldos por oficina
  CURSOR CUR_CIE(p_cod_oficina in number) IS
     SELECT CB_SAL_OFICINAS.COD_OFICINA, CB_RUBROS.COD_RUBRO,
     NVL(SAL_MON_LOC_ANT,0)+NVL(DEB_MON_LOCAL,0)-NVL(CRE_MON_LOCAL,0),
     NVL(SAL_MON_RUB_ANT,0)+NVL(DEB_MON_RUBRO,0)-NVL(CRE_MON_RUBRO,0), cb_rubros.tipo
     FROM   CB_SAL_OFICINAS, CB_RUBROS, CB_RUB_OFICINAS
     WHERE  CB_SAL_OFICINAS.COD_OFICINA = p_cod_oficina
       AND  CB_SAL_OFICINAS.COD_OFICINA = CB_RUB_OFICINAS.COD_OFICINA
       AND  CB_SAL_OFICINAS.COD_RUBRO = CB_RUB_OFICINAS.COD_RUBRO
       AND  CB_SAL_OFICINAS.ANO = v_ano_actual
       AND  CB_SAL_OFICINAS.MES = v_mes_actual
       AND  CB_RUB_OFICINAS.COD_RUBRO = CB_RUBROS.COD_RUBRO
       AND  CB_RUBROS.TIPO >= v_tip_inicial
       AND  CB_RUBROS.TIPO <= v_tip_final
       AND  CB_RUBROS.IMPUTABLE = 'S';
-------
v_cod_oficina         ba_oficinas.cod_oficina%type;
v_cod_rubro           cb_rubros.cod_rubro%type;
v_tot_mon_local       cb_asientos.tot_control%type;
v_tot_mon_rubro       cb_asientos.tot_control%type;
-------
v_nro_asiento         cb_asientos.nro_asiento%type;
v_tip_movimiento      cb_asientos_det.tip_movimiento%type;
v_tip_mov_contra      cb_asientos_det.tip_movimiento%type;
v_cod_rub_contra      cb_asientos_det.cod_rubro%type;

v_nro_linea           cb_asientos_det.nro_linea%type;
v_tot_control         cb_asientos.tot_control%type;
v_tot_oficina         cb_asientos_det.mto_mon_local%type;
v_referencia          cb_asientos_det_his.referencia%type;
v_cer_cta_patrimonial varchar2(1) := nvl(fug_obt_pardinamico('CON_CER_CTA_PATRIMONIAL'),'N');
v_con_tip_inicial     cb_rubros.tipo%type;
v_con_tip_final       cb_rubros.tipo%type;
v_tipo                cb_rubros.tipo%type;
BEGIN
  If nvl(v_cer_cta_patrimonial,'N') = 'S' then
    v_con_tip_inicial := 1;
    v_con_tip_final   := 4;
  else
    v_con_tip_inicial := 2;
    v_con_tip_final   := 2;
  End if;
  for i in v_con_tip_inicial..v_con_tip_final loop
      if i = 1 then
         v_tip_inicial := 1;
         v_tip_final   := 3;
         v_referencia  := 'CIE.CT.PAT';
      elsif i = 2 then
         v_tip_inicial := 6;
         v_tip_final   := 7;
         v_referencia  := 'CIE.CT.RES';
      elsif i = 3 then
         v_tip_inicial := 4;
         v_tip_final   := 4;
         v_referencia  := 'CIE.CT.CON';
      elsif i = 4 then
         v_tip_inicial := 5;
         v_tip_final   := 5;
         v_referencia  := 'CIE.CT.ORD';
      end if;
      ------- ve nro asiento -----------
      v_nro_asiento := fug_obt_pardinamico('SIG_NRO_ASIENTO');
      FOR ofi IN OFIC LOOP
          IF CUR_CIE%isopen THEN
             CLOSE CUR_CIE;
          END IF;
          OPEN CUR_CIE(ofi.cod_oficina);
          v_nro_linea   := 0;
          v_tot_control := 0;
          v_tot_oficina := 0;
           LOOP
            FETCH CUR_CIE INTO v_cod_oficina, v_cod_rubro, v_tot_mon_local, v_tot_mon_rubro, v_tipo;
            EXIT WHEN CUR_CIE%notfound;
            ----
            -- ve numero de asiento y cuenta ganancia --
            --------------------------------------------
            IF NVL(v_tot_mon_local,0) <> 0 THEN
               IF NVL(v_tot_mon_local,0) < 0 THEN
                  v_tip_movimiento := 'D';
               ELSE
                  v_tip_movimiento := 'C';
               END IF;
            END IF;
            IF NVL(v_tot_mon_local,0) <> 0 THEN
               --
               v_tot_control := nvl(v_tot_control,0) + ABS(v_tot_mon_local);
               --
               v_tot_oficina := nvl(v_tot_oficina,0) + nvl(v_tot_mon_local,0);
               --
               v_nro_linea := v_nro_linea + 1;
               --
               INSERT INTO CB_ASIENTOS_DET
                   (COD_OFICINA, FECHA, NRO_ASIENTO, NRO_LINEA,
                    COD_RUBRO, MTO_MON_LOCAL, MTO_MON_RUBRO,
                    TIP_MOVIMIENTO, DESCRIPCION, ACTUALIZADO,
                    REFERENCIA)
               VALUES
                    (v_cod_oficina, v_fec_actual, v_nro_asiento, v_nro_linea,
                     v_cod_rubro,  ABS(v_tot_mon_local), abs(v_tot_mon_rubro),
                     v_tip_movimiento, 'Cierre de Ejercicio','N',
                     v_referencia);
               --

            END IF;
          END LOOP;
          IF v_tot_control > 0 THEN
            if v_tot_oficina < 0 then
               v_cod_rub_contra := fug_obt_pardinamico('COD_RUB_GANANCIAS',2, 21, pag_gen.FU_OBT_MON_LOCAL, ofi.cod_oficina);
               v_tip_mov_contra := 'C';
            elsif v_tot_oficina > 0 then
               v_cod_rub_contra := fug_obt_pardinamico('COD_RUB_PERDIDAS',2, 21, pag_gen.FU_OBT_MON_LOCAL, ofi.cod_oficina);
               v_tip_mov_contra := 'D';
            end if;
            v_tot_control := nvl(v_tot_control,0) + ABS(v_tot_oficina);
            if abs(v_tot_oficina) <> 0 and nvl(v_cer_cta_patrimonial,'N') = 'N' then --- No todos los asientos necesitan utilidad
            -- linea de asiento a la cuenta de ganancia --
               v_nro_linea := v_nro_linea + 1;
               INSERT INTO CB_ASIENTOS_DET
                   (COD_OFICINA, FECHA, NRO_ASIENTO, NRO_LINEA,
                    COD_RUBRO, MTO_MON_LOCAL, MTO_MON_RUBRO,
                    TIP_MOVIMIENTO, DESCRIPCION, ACTUALIZADO,
                    REFERENCIA, fec_valor)
               VALUES
                   (v_cod_oficina, v_fec_actual,  v_nro_asiento, v_nro_linea,
                    v_cod_rub_contra, ABS(v_tot_oficina), 0,
                    v_tip_mov_contra, 'Cierre de Ejercicio','N',
                    'CIE.CT.PAT',v_fec_actual);
            else
              If v_tipo in (6,7) then
                 v_nro_linea := v_nro_linea + 1;
                 SELECT sum(NVL(SAL_MON_LOC_ANT,0)+NVL(DEB_MON_LOCAL,0)-NVL(CRE_MON_LOCAL,0))
                   INTO v_tot_oficina
                   FROM   CB_SAL_OFICINAS, CB_RUBROS, CB_RUB_OFICINAS
                   WHERE  CB_SAL_OFICINAS.COD_OFICINA = v_cod_oficina
                     AND  CB_SAL_OFICINAS.COD_OFICINA = CB_RUB_OFICINAS.COD_OFICINA
                     AND  CB_SAL_OFICINAS.COD_RUBRO = CB_RUB_OFICINAS.COD_RUBRO
                     AND  CB_SAL_OFICINAS.ANO = v_ano_actual
                     AND  CB_SAL_OFICINAS.MES = v_mes_actual
                     AND  CB_RUB_OFICINAS.COD_RUBRO = CB_RUBROS.COD_RUBRO
                     AND  CB_RUBROS.TIPO >= 6
                     AND  CB_RUBROS.TIPO <= 7
                     AND  CB_RUBROS.IMPUTABLE = 'S';
                 if v_tot_oficina < 0 then
                   v_cod_rub_contra := fug_obt_pardinamico('COD_RUB_GANANCIAS',2, 21, pag_gen.FU_OBT_MON_LOCAL, ofi.cod_oficina);
                   v_tip_mov_contra := 'C';
                 elsif v_tot_oficina > 0 then
                   v_cod_rub_contra := fug_obt_pardinamico('COD_RUB_PERDIDAS',2, 21, pag_gen.FU_OBT_MON_LOCAL, ofi.cod_oficina);
                   v_tip_mov_contra := 'D';
                 end if;
                 INSERT INTO CB_ASIENTOS_DET
                     (COD_OFICINA, FECHA, NRO_ASIENTO, NRO_LINEA,
                      COD_RUBRO, MTO_MON_LOCAL, MTO_MON_RUBRO,
                      TIP_MOVIMIENTO, DESCRIPCION, ACTUALIZADO,
                      REFERENCIA, fec_valor)
                 VALUES
                     (v_cod_oficina, v_fec_actual,  v_nro_asiento, v_nro_linea,
                      v_cod_rub_contra, ABS(v_tot_oficina), 0,
                      v_tip_mov_contra, 'Cierre de Ejercicio','N',
                      'CIE.CT.RES',v_fec_actual);
              end if;
            end if;
            INSERT INTO CB_ASIENTOS
                    (COD_OFICINA, NRO_ASIENTO, COD_USUARIO,
                     FECHA, COD_MODULO, COD_MODALIDAD, TOT_CONTROL,
                     ACTUALIZADO, REVERSADO, COD_OFI_ORIGEN, CONFIRMADO,
                     OFI_INTEGRADA,fec_valor)
            VALUES (v_cod_oficina, v_nro_asiento, user,
                    v_fec_actual, 2, 21, v_tot_control,
                    'N', 'N', v_cod_oficina, 'S', 'N',v_fec_actual);
          END IF;
          v_nro_asiento := v_nro_asiento + 1;
          IF CUR_CIE%isopen THEN
             CLOSE CUR_CIE;
          END IF;
       END LOOP;
       -- actualizo el sgte. nro de asiento
       prg_act_par_dinamico('SIG_NRO_ASIENTO',null, null, null, null, v_nro_asiento);
       ---------------------------------
   end loop;
   -- habilitar inicio de ejercicio
    PRB_INI_PRO_CONTAB(350);
EXCEPTION
   when others then
      raise_application_error(-20000, 'Error en Cierre del Ejercicio '||sqlerrm);
END;
/

