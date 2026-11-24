CREATE OR REPLACE PROCEDURE IT.PRB_COR_ASI_AUT IS
 /* Correcion de asientos diarios */
  v_debito        NUMBER;
  v_credito       NUMBER;
  v_deb_mon_rubro NUMBER;
  v_cre_mon_rubro NUMBER;
  v_imputable     VARCHAR2(1);
  v_fec_actual    date   := pag_cal.fu_obt_fec_actual(1);
  v_cod_rub_aux   VARCHAR2(15);
  v_lugar         varchar2(100);
  v_cod_numerico  varchar2(2);
  v_cod_num_moneda varchar2(2);
  v_cod_rub_moneda cb_asi_automaticos_det.cod_rubro%type;

 ------- para cabecera de asientos ------
  R_CAB   CB_ASI_AUTOMATICOS%rowtype;
  CURSOR CAB is SELECT *
               FROM   CB_ASI_AUTOMATICOS
               WHERE  FECHA = V_FEC_ACTUAL
               FOR    UPDATE OF CONFIRMADO;
 ------ detalle de asientos -------
  R_DET   CB_ASI_AUTOMATICOS_DET%rowtype;
  CURSOR DET is SELECT *
                 FROM CB_ASI_AUTOMATICOS_DET
                WHERE COD_OFICINA = R_CAB.COD_OFICINA
                  AND NRO_ASIENTO = R_CAB.NRO_ASIENTO
                  AND FECHA = R_CAB.FECHA;
  ----------------------------------
  CURSOR CTA is SELECT IMPUTABLE
                FROM CB_RUB_OFICINAS B,CB_RUBROS A
               WHERE B.COD_OFICINA = R_CAB.COD_OFICINA
                 AND A.COD_RUBRO = R_DET.COD_RUBRO
                 AND B.COD_RUBRO = A.COD_RUBRO;
  --
  v_nro_asiento   CB_VALIDACIONES.nro_asiento%type;
  v_nro_linea     CB_VALIDACIONES.nro_linea%type;
  v_msj_error     CB_VALIDACIONES.error%type;
  v_cod_modulo    CB_VALIDACIONES.cod_modulo%type;
  v_cod_modalidad CB_VALIDACIONES.cod_modalidad%type;
  v_cod_oficina   CB_VALIDACIONES.cod_oficina%type;
  --
  PROCEDURE LP_GEN_ERROR IS
      BEGIN
         INSERT INTO CB_AUX_VALIDACIONES
            (FECHA, NRO_ASIENTO, NRO_LINEA, ERROR,
             COD_MODULO, COD_MODALIDAD, COD_OFICINA)
         VALUES(v_fec_actual, v_nro_asiento,v_nro_linea, v_msj_error,
             v_cod_modulo,v_cod_modalidad, v_cod_oficina);
      END;


  --Modifica el rubro cuando la cuenta no existe en el balance
  PROCEDURE MOD_RUB_ASI_AUT_DET(P_DET CB_ASI_AUTOMATICOS_DET%rowtype) IS
     BEGIN
     IF P_DET.MTO_MON_RUBRO<>0 THEN --moneda extranjera
        CASE SUBSTR(P_DET.COD_RUBRO,14,2)
           WHEN '01' THEN    --USD
              v_cod_rub_aux := fug_obt_pardinamico('RUB_CON_TRANSITORIO', NULL, NULL, 'USD');
           WHEN '09' THEN    --RS
              v_cod_rub_aux := fug_obt_pardinamico('RUB_CON_TRANSITORIO', NULL, NULL, 'RS');
           WHEN '10' THEN    --ARP
              v_cod_rub_aux := fug_obt_pardinamico('RUB_CON_TRANSITORIO', NULL, NULL, 'ARP');
           WHEN '59' THEN    --EUR
              v_cod_rub_aux := fug_obt_pardinamico('RUB_CON_TRANSITORIO', NULL, NULL, 'EUR');
           WHEN '98' THEN    --GS
              v_cod_rub_aux := fug_obt_pardinamico('RUB_CON_TRANSITORIO', NULL, NULL, 'GS');
           ELSE
              v_cod_rub_aux := NULL;
           END CASE;
     ELSIF P_DET.MTO_MON_RUBRO=0 THEN --moneda local
       v_cod_rub_aux :=fug_obt_pardinamico('RUB_CON_TRANSITORIO', NULL, NULL, 'GS');
     END IF;

     BEGIN
       UPDATE CB_ASI_AUTOMATICOS_DET D
       SET D.COD_RUBRO=v_cod_rub_aux
       WHERE D.FECHA=P_DET.FECHA
       AND D.COD_OFICINA=P_DET.COD_OFICINA
       AND D.NRO_ASIENTO=P_DET.NRO_ASIENTO
       AND D.NRO_LINEA=P_DET.NRO_LINEA;
     EXCEPTION
        WHEN OTHERS THEN
           RAISE_APPLICATION_ERROR(-20000,' ERROR al modificar RUBRO del asiento '||P_DET.NRO_ASIENTO||', nro de linea '||P_DET.NRO_LINEA||'. '||sqlerrm);
     END;
  END;

  --Inserta un asiento para corregir la diferencia cuando no está balanceado
  PROCEDURE MOD_BAL_ASI_AUT(P_CAB CB_ASI_AUTOMATICOS%rowtype,p_debitos number,p_creditos number,p_rubro cb_asi_automaticos_det.cod_rubro%type,p_fecha cb_asi_automaticos_det.fecha%type) IS
     v_tipo varchar2(1);
     v_cta varchar2(15);
     v_max_lin number;
     v_dif number;
     v_mto_mon_rubro number;
     v_mon ba_monedas.cod_moneda%type;

     BEGIN
        BEGIN
          select max(d.nro_linea) into v_max_lin
          from cb_asi_automaticos_det d
          where d.fecha=p_cab.fecha
          and d.cod_oficina=p_cab.cod_oficina
          and d.nro_asiento=p_cab.nro_asiento;
        EXCEPTION
           WHEN OTHERS THEN
              RAISE_APPLICATION_ERROR(-20000,' ERROR al obtener el max nro de linea para el asiento '||p_cab.NRO_ASIENTO||', oficina '||p_cab.cod_oficina||'. '||sqlerrm);
        END;

        --Si hay más debitos, acreditar la cuenta 240402600255599, en mto_mon_local el monto de la diferencia
        IF(p_debitos > p_creditos) THEN
           v_tipo:='C';
               CASE SUBSTR(p_rubro,14,2)
                 WHEN '01' THEN     --USD
                     v_cta := fug_obt_pardinamico('RUB_CON_TRANSITORIO', NULL, NULL, 'USD');
                     v_mon := 'USD';
                 WHEN '09' THEN    --RS
                     v_cta := fug_obt_pardinamico('RUB_CON_TRANSITORIO', NULL, NULL, 'RS');
                     v_mon := 'RS';
                 WHEN '10' THEN    --ARP
                     v_cta := fug_obt_pardinamico('RUB_CON_TRANSITORIO', NULL, NULL, 'ARP');
                     v_mon := 'ARP';
                 WHEN '59' THEN     --EUR
                     v_cta := fug_obt_pardinamico('RUB_CON_TRANSITORIO', NULL, NULL, 'EUR');
                     v_mon := 'EUR';
                ELSE
                     v_cta := fug_obt_pardinamico('RUB_CON_TRANSITORIO', NULL, NULL, 'GS');
                     v_mon := pag_gen.FU_OBT_MON_LOCAL;
                END CASE;
           v_dif:=p_debitos-p_creditos;
        --Si hay más créditos, debitar la cuenta 240402600255599, en mto_mon_local el monto de la diferencia
        ELSIF(p_creditos > p_debitos) THEN
           v_tipo:='D';
            CASE SUBSTR(p_rubro,14,2)
                 WHEN '01' THEN     --USD
                     v_cta := fug_obt_pardinamico('RUB_CON_TRANSITORIO', NULL, NULL, 'USD');
                     v_mon := 'USD';
                 WHEN '09' THEN    --RS
                     v_cta := fug_obt_pardinamico('RUB_CON_TRANSITORIO', NULL, NULL, 'RS');
                     v_mon := 'RS';
                 WHEN '10' THEN    --ARP
                     v_cta := fug_obt_pardinamico('RUB_CON_TRANSITORIO', NULL, NULL, 'ARP');
                     v_mon := 'ARP';
                 WHEN '59' THEN     --EUR
                     v_cta := fug_obt_pardinamico('RUB_CON_TRANSITORIO', NULL, NULL, 'EUR');
                     v_mon := 'EUR';
                 ELSE
                     v_cta := fug_obt_pardinamico('RUB_CON_TRANSITORIO', NULL, NULL, 'GS');
                     v_mon := pag_gen.FU_OBT_MON_LOCAL;
              END CASE;
           v_dif:=p_creditos-p_debitos;
        END IF;

        --Calcular el Monto en moneda extranjera
        if v_mon <> pag_gen.FU_OBT_MON_LOCAL then
           v_mto_mon_rubro:= pal_cam.FU_CON_MON_A_MONEDA(pag_gen.FU_OBT_MON_LOCAL,v_mon,v_dif,pag_gen.fu_obt_cotizacion(v_mon, p_Fecha));
        else
           v_mto_mon_rubro:= 0;
        end if;

        --Adicionar una línea nueva al asiento para regularizar la diferencia de los débitos y créditos
        BEGIN
           insert into cb_asi_automaticos_det
           (FECHA,COD_OFICINA,NRO_ASIENTO,NRO_LINEA,COD_RUBRO,TIP_MOVIMIENTO,MTO_MON_RUBRO,MTO_MON_LOCAL,DESCRIPCION,FEC_VALOR)
           values
           (p_cab.fecha,p_cab.cod_oficina,p_cab.nro_asiento,v_max_lin+1,v_cta,v_tipo,v_mto_mon_rubro,v_dif,
           'REGUL. DIF. CIERRE '||to_char(p_cab.fecha,'dd/mm/yyyy'),p_cab.fecha);
        EXCEPTION
           WHEN OTHERS THEN
              RAISE_APPLICATION_ERROR(-20000,' ERROR al insertar detalle para el asiento '||p_cab.NRO_ASIENTO||', oficina '||p_cab.cod_oficina||'. '||sqlerrm);
        END;

        --Ajustar la diferencia en la cabecera del asiento (cb_asi_automaticos) en el campo tot_control.
        BEGIN
           update cb_asi_automaticos a
           set a.tot_control = a.tot_control + v_dif
           where a.fecha=p_cab.fecha
           and a.cod_oficina=p_cab.cod_oficina
           and a.nro_asiento=p_cab.nro_asiento;
        EXCEPTION
           WHEN OTHERS THEN
              RAISE_APPLICATION_ERROR(-20000,' ERROR al insertar detalle para el asiento '||p_cab.NRO_ASIENTO||', oficina '||p_cab.cod_oficina||'. '||sqlerrm);
        END;
  END;

BEGIN
  ----- verifica si hay asientos para validar -----
  OPEN CAB;
  LOOP
     FETCH CAB INTO R_CAB;
     EXIT WHEN CAB%notfound;
     v_lugar := 'cursor cab';
     ------- INICIO VALIDA CABECERA -------
     v_cod_modulo    := R_CAB.COD_MODULO;
     v_cod_modalidad := R_CAB.COD_MODALIDAD;
     v_nro_asiento   := R_CAB.NRO_ASIENTO;
     v_cod_oficina   := R_CAB.COD_OFICINA;
     v_nro_linea     := 0;
     v_msj_error     := NULL;

--     IF R_CAB.CONFIRMADO = 'N' THEN
--        v_msj_error := 'Asiento esta marcado ok="N".';
--        LP_GEN_ERROR;
--     END IF;
     --------- FIN VALIDA CABECERA --------
     -- ve los detalles de los asientos que corresponden --
     ------------------------------------------------------
      IF DET%isopen THEN
         CLOSE DET;
      END IF;

      OPEN DET;
      v_debito   := 0;
      v_credito   := 0;
      v_deb_mon_rubro := 0;
      v_cre_mon_rubro := 0;

      LOOP
         FETCH DET INTO R_DET;
         EXIT WHEN DET%notfound;
         v_nro_linea := R_DET.NRO_LINEA;

         IF CTA%ISOPEN THEN
            CLOSE CTA;
         END IF;

         OPEN CTA;
         FETCH CTA INTO v_imputable;
         v_lugar := 'cursor CTA ';
         IF CTA%NOTFOUND THEN
            v_msj_error :='No existe cuenta ' || r_det.COD_RUBRO || ' en CB_RUB_OFICINAS';
            LP_GEN_ERROR;
            MOD_RUB_ASI_AUT_DET(R_DET); --modifica el rubro que figura en el asiento
         END IF;
         v_lugar := 'cursor CTA 1';
         IF v_nro_linea = 1 then
            v_cod_num_moneda:= SUBSTR(R_DET.COD_RUBRO,14,2);
            v_cod_rub_moneda:= R_DET.COD_RUBRO;
         END IF;
         v_cod_numerico:= SUBSTR(R_DET.COD_RUBRO,14,2);
         IF R_DET.TIP_MOVIMIENTO = 'D' THEN
            v_debito   := v_debito   + NVL(R_DET.MTO_MON_LOCAL,0);
            v_deb_mon_rubro := v_deb_mon_rubro + NVL(R_DET.MTO_MON_RUBRO,0);
         ELSIF R_DET.TIP_MOVIMIENTO = 'C' THEN
            v_credito   := v_credito   + NVL(R_DET.MTO_MON_LOCAL,0);
            v_cre_mon_rubro := v_cre_mon_rubro + NVL(R_DET.MTO_MON_RUBRO,0);
         END IF;
         if v_cod_numerico <> v_cod_num_moneda then
            v_cod_rub_moneda:= null;
         end if;
      END LOOP;


      v_nro_linea := 0;

      IF DET%rowcount > 0 THEN

         IF v_debito <> v_credito THEN
            v_msj_error := 'Asiento no balancea.' ;

            IF R_CAB.CONFIRMADO = 'S' THEN
               v_msj_error := 'Asiento no balancea y marcado OK.' ;
            END IF;
            v_lugar := 'cursor DET ';
            LP_GEN_ERROR;
            MOD_BAL_ASI_AUT(R_CAB,v_debito,v_credito,v_cod_rub_moneda,R_DET.FECHA); --insertar asiento para que balancee

         END IF;
      END IF;

  END LOOP;

  commit;

  CLOSE CAB;
  CLOSE DET;
---------------------------------
EXCEPTION
   WHEN OTHERS THEN
     IF CAB%isopen THEN
        CLOSE CAB;
     END IF;
     IF DET%isopen THEN
        CLOSE DET;
     END IF;
     IF sqlcode <= -20000 THEN
       raise;
     ELSE
       RAISE_APPLICATION_ERROR(-20000,'Error en la correción de Asientos '||v_lugar || sqlerrm);
     END IF;

END;
/

