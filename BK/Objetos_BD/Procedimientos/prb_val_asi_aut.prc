create or replace procedure IT.PRB_VAL_ASI_AUT IS
 /* Validacion de asientos diarios */
  v_debito        NUMBER;
  v_credito       NUMBER;
  v_deb_mon_rubro NUMBER;
  v_cre_mon_rubro NUMBER;
  v_imputable     VARCHAR2(1);
  v_fec_actual    date   := pag_cal.fu_obt_fec_actual(1);
 ------- para cabecera de asientos ------
  R_CAB   CB_ASI_AUTOMATICOS%rowtype;
  CURSOR CAB is SELECT *
               FROM   CB_ASI_AUTOMATICOS
               WHERE  FECHA = V_FEC_ACTUAL
               FOR    UPDATE OF CONFIRMADO;
 ------ detalle de asientos -------
  R_DET   CB_ASI_AUTOMATICOS_DET%rowtype;
  CURSOR DET is SELECT *
                FROM  CB_ASI_AUTOMATICOS_DET
                WHERE COD_OFICINA = R_CAB.COD_OFICINA
                  AND NRO_ASIENTO = R_CAB.NRO_ASIENTO
                  AND FECHA = R_CAB.FECHA
                  FOR UPDATE OF NRO_ASIENTO;
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
         INSERT INTO CB_VALIDACIONES
            (FECHA, NRO_ASIENTO, NRO_LINEA, ERROR,
             COD_MODULO, COD_MODALIDAD, COD_OFICINA)
         VALUES(v_fec_actual, v_nro_asiento,v_nro_linea, v_msj_error,
             v_cod_modulo,v_cod_modalidad, v_cod_oficina);
  END;

BEGIN
 -- limpia archivo CB_VALIDACIONES
 delete CB_VALIDACIONES where nro_asiento <> -1;
 ----- verifica si hay asientos para validar -----
  OPEN CAB;
  LOOP
     FETCH CAB INTO R_CAB;
     EXIT WHEN CAB%notfound;
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
         IF CTA%NOTFOUND THEN
            v_msj_error :='No existe cuenta ' || r_det.COD_RUBRO || ' en CB_RUB_OFICINAS';
            /* No generar el error, se creó el procedimiento PRB_COR_ASI_AUT que regulariza este tipo de error
              y envía por email los detalles a la gente de Contabilidad */
            --LP_GEN_ERROR;

         END IF;
         IF v_imputable = 'N' and r_det.COD_RUBRO not in ( '140704259200199') THEN   -- temporal hasta solucionar una incidencia. js - 27/06/13
            v_msj_error :='Cuenta '||r_det.COD_RUBRO||' no es '|| 'imputable ';
            LP_GEN_ERROR;
         END IF;
         IF R_DET.TIP_MOVIMIENTO = 'D' THEN
            v_debito   := v_debito   + NVL(R_DET.MTO_MON_LOCAL,0);
            v_deb_mon_rubro := v_deb_mon_rubro + NVL(R_DET.MTO_MON_RUBRO,0);
         ELSIF R_DET.TIP_MOVIMIENTO = 'C' THEN
            v_credito   := v_credito   + NVL(R_DET.MTO_MON_LOCAL,0);
            v_cre_mon_rubro := v_cre_mon_rubro + NVL(R_DET.MTO_MON_RUBRO,0);
         ELSE
           v_msj_error := 'Tipo de Movimiento Inválido ' ;
            LP_GEN_ERROR;
         END IF;
         IF R_DET.MTO_MON_LOCAL = 0 THEN
            v_msj_error := 'Importe ML = 0 ';
            LP_GEN_ERROR;
         END IF;
         IF R_DET.REFERENCIA IS NULL AND
            R_DET.DESCRIPCION IS NULL THEN
            v_msj_error := 'Descripción y Referencia en blanco' ;
            LP_GEN_ERROR;
         END IF;
         IF R_DET.MTO_MON_LOCAL <> TRUNC(R_DET.MTO_MON_LOCAL) THEN
            v_msj_error := 'Moneda local con decimales' ;
            --Actualizar detalle
            update CB_ASI_AUTOMATICOS_DET
              set mto_mon_local = round(mto_mon_local)
                WHERE CURRENT OF DET;
            --Actualizar Cabecera
            update cb_asi_automaticos c
            set c.tot_control = (select sum(mto_mon_local)
                                   from cb_asi_automaticos_det 
                                   where nro_asiento = v_nro_asiento)
            where c.nro_asiento = v_nro_asiento;
         END IF;
      END LOOP;
      v_nro_linea := 0;
      IF DET%rowcount > 0 THEN
         IF v_debito <> v_credito THEN
            v_msj_error := 'Asiento no balancea.' ;
            IF R_CAB.CONFIRMADO = 'S' THEN
               v_msj_error := 'Asiento no balancea y marcado OK.' ;
            END IF;
            /* No generar el error, se creó el procedimiento PRB_COR_ASI_AUT que regulariza este tipo de error
              y envía por email los detalles a la gente de Contabilidad */
            --LP_GEN_ERROR;
         ELSE
            NULL;
            /*
            IF v_debito * 2 <> R_CAB.TOT_CONTROL THEN
               v_msj_error := 'Total de Control no coincide con suma de débitos y créditos ';
               LP_GEN_ERROR;
            END IF;
            */
         END IF;
      ELSE
         v_msj_error  := 'No existen líneas de detalle ';
         LP_GEN_ERROR;
      END IF;
 END LOOP;
 commit;
  IF CAB%rowcount = 0 THEN
     RAISE_APPLICATION_ERROR(-20000,' ERROR. No existen asientos para validar en esta fecha');
  END IF;
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
       RAISE_APPLICATION_ERROR(-20000,'Error en la validación de Asientos '||sqlerrm);
     END IF;
END;
/
