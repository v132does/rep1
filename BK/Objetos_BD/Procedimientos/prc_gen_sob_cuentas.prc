CREATE OR REPLACE PROCEDURE IT.PRC_GEN_SOB_CUENTAS IS
   --DESOPIMI-323 PyR Jul/2017 NAF - Basado en PRC_GEN_SOBREGIROS--
   --DYDMR-7095 PyR Jul/2017 NAF - Ajustes en calculos para fin de semana--
   rg_cal  ge_calendarios%ROWTYPE;
   vg_fec_actual DATE;
   vg_fec_anterior ge_calendarios.fec_anterior%TYPE;
   vg_lugar   varchar2(200);
   vg_can_dia_exceso   cc_sobregiros.can_dias%TYPE;
   vg_can_dia_sobregiro cc_sobregiros.can_dia_sobregiro%TYPE;
   -- EP - N.AN. 2014-10-23 SC 9468 - ITGF - Dias de Mora de Cuenta Corriente--
   vg_tie_sob_fec_anterior  varchar2(1);
   vg_act_sobregiro         varchar2(1);
   vg_can_dia_exc_original  cc_sobregiros.can_dias%TYPE;
   vg_can_dia_sob_original  cc_sobregiros.can_dia_sobregiro%TYPE;
   vg_aux_saldo             cc_sobregiros.saldo%TYPE;
   vg_aux_sal_total         cc_sobregiros.sal_total%TYPE;
   vg_aux_sal_retenido      cc_sobregiros.sal_retenido%TYPE;
   vg_aux_mto_linea         cc_sobregiros.mto_linea%TYPE;
   vg_hor_inicio            varchar2(8);
   vg_hor_fin               varchar2(8);
   vg_cod_programa          ge_log_procesos.cod_programa%type;
   vg_bas_datos             varchar2(200);
   vg_usu_base              varchar2(10);
   vg_dif_dias              number(5);
   vg_tra_sobregiros        varchar2(1);
   vg_nro_cuenta varchar2(20);
   ----
   vg_ult_dia_mes_habil     date;
   vg_ult_dia_mes           date;
   vg_pri_dia_mes           date;
   vg_pri_dia_mes_habil     date;
   vg_fec_min_sob           date;
   --Verificar Base y Usuario--
   procedure lp_ver_usu_bas_datos is
     v_bas_prod ge_par_dinamicos.val_parametro%type;
   begin
     v_bas_prod := fug_obt_pardinamico('BD_PROD');
     SELECT upper(sys_context('USERENV', 'DB_NAME'))
       INTO vg_bas_datos
       FROM dual;
     IF vg_bas_datos = v_bas_prod  then
        vg_usu_base := 'IT';
     else
        vg_usu_base := 'DYDTEST';
     end if;
   end lp_ver_usu_bas_datos;
   --Calcular Estadisticas de la Tabla--
   procedure lp_gen_est_tablas(p_tabla in varchar2) is
   begin
     BEGIN dbms_stats.gather_table_stats(vg_usu_base,p_tabla); END;
   end lp_gen_est_tablas;
   --Verifica consistencia de cc_sobregiros_res_ant--
   PROCEDURE lp_ver_con_sob_res_ant IS
      v_fec_sob_res_ant   ge_calendarios.fec_actual%type;
   BEGIN
      select max(fecha)
        into v_fec_sob_res_ant
        from cc_sobregiros_res_ant;
      --verificar que coincida con fecha anterior--
      if v_fec_sob_res_ant <> vg_fec_anterior then
         RAISE_APPLICATION_ERROR(-20010, 'Error en lp_hab_lin_sobregiros: tabla cc_sobregiros_res_ant no tiene de fecha anterior necesaria para calculo. ');
      end if;
   EXCEPTION
      WHEN OTHERS THEN
         IF SQLCODE <= -20000 THEN
            RAISE;
         ELSE
            RAISE_APPLICATION_ERROR(-20010, 'lp_hab_lin_sobregiros. ' || SQLERRM);
         END IF;
   END;
   --Calcula datos de sobregiro desde cc_sobregiros_res_ant--
   PROCEDURE lp_cal_dat_sobregiro IS
   BEGIN
      INSERT INTO CC_SOB_DAT_CALCULADOS_TMP
      SELECT b.nro_cuenta,a.can_dias,a.can_dia_sobregiro,
          vg_dif_dias dif_dias ,
          case when b.mto_linea>= b.saldo then
             'S'
          else
             'N'
          end tie_linea,
          case when  b.mto_linea>= b.saldo then
             0
          else
             decode(nvl(a.can_dias,0),0,1,nvl(a.can_dias,0)+nvl(vg_dif_dias,0)+1)
          end can_dia_actual,
          decode(nvl(a.can_dia_sobregiro,0),0,1,nvl(a.can_dia_sobregiro,0)+nvl(vg_dif_dias,0)+1) can_dia_sob_actual
      FROM CC_SOBREGIROS_RES_ANT a,
                CC_SOBREGIROS_TMP b
      WHERE b.nro_cuenta=a.nro_cuenta(+)
      and b.fecha = vg_fec_actual;
   EXCEPTION
      WHEN OTHERS THEN
        IF SQLCODE <= -20000 THEN
          RAISE;
        ELSE
          RAISE_APPLICATION_ERROR(-20010, 'lp_cal_dat_sobregiro. ' || SQLERRM);
        END IF;
   END;
   --Transfiere a tablas reales registros de sobregiro generados--
   PROCEDURE lp_ins_sob_generado is 
   BEGIN
     insert into cc_sobregiros
     (select * from cc_sobregiros_tmp);
   END;
   --Transfiere a tablas reales registros de resumen de sobregiros generados--
   PROCEDURE lp_ins_res_generado is 
   BEGIN
     insert into cc_sobregiros_res
     (select * from cc_sobregiros_res_tmp);
   END;
   --Trunca tablas tmp del proceso--
   PROCEDURE lp_tru_tab_temporales is
     v_msj     VARCHAR2(200);
   BEGIN
     --CC_SOBREGIROS_RES_TMP--
     sql_util.ejecute_dml('TRUNCATE TABLE CC_SOBREGIROS_RES_TMP', v_msj);
     IF v_msj IS NOT NULL THEN
        raise_application_error(-20000, v_msj);
     END IF;
     --CC_SOBREGIROS_TMP--
     sql_util.ejecute_dml('TRUNCATE TABLE CC_SOBREGIROS_TMP', v_msj);
     IF v_msj IS NOT NULL THEN
        raise_application_error(-20000, v_msj);
     END IF;
     --CC_SOB_DAT_CALCULADOS_TMP--
     sql_util.ejecute_dml('TRUNCATE TABLE CC_SOB_DAT_CALCULADOS_TMP', v_msj);
     IF v_msj IS NOT NULL THEN
        raise_application_error(-20000, v_msj);
     END IF;
   END;
   --Trunca tabla definitiva CC_SOBREGIROS_RES--
   PROCEDURE lp_tru_tab_sobregiros_res is
     v_msj     VARCHAR2(200);
   BEGIN
     sql_util.ejecute_dml('TRUNCATE TABLE CC_SOBREGIROS_RES', v_msj);
     IF v_msj IS NOT NULL THEN
        raise_application_error(-20000, v_msj);
     END IF;
   END;
   --Elimina datos de fechas generadas en tabla definitiva CC_SOBREGIROS--
   PROCEDURE lp_eli_sobregiros is
   BEGIN  
     delete from cc_sobregiros WHERE fecha >= vg_fec_min_sob;      
   END;   
   --Actualiza las lineas de sobregiro--
   PROCEDURE lp_act_lin_sobregiro(p_nro_cuenta IN VARCHAR2, p_estado IN VARCHAR2) IS
      CURSOR cu_lineas IS
         SELECT b.nro_secuencia, b.nro_sec_padre
           FROM cc_lin_sobregiros b
          WHERE b.nro_cuenta = p_nro_cuenta;
   BEGIN
      FOR ccu_lineas IN cu_lineas LOOP
         UPDATE cc_lin_sobregiros clsob
            SET clsob.estado = p_estado
          WHERE clsob.nro_secuencia IN (ccu_lineas.nro_secuencia, ccu_lineas.nro_sec_padre);
      END LOOP;
   EXCEPTION
      WHEN OTHERS THEN
         IF SQLCODE <= -20000 THEN
            RAISE;
         ELSE
            RAISE_APPLICATION_ERROR(-20010, 'lp_act_lin_sobregiros. ' || SQLERRM);
         END IF;
   END;
   --Calcula Sobregiro Diario--
   PROCEDURE lp_cal_sob_diario IS
      ------------------------------------------------------------------------
      ---- DIAS ININTERRUMPIDOS DE MAYOR FECHA
      ------------------------------------------------------------------------
      ---- VARIABLES CURSOR LOOP MAYOR
      ------------------------------------------------------------------------
      v1_cdmodul ba_modulos.cod_modulo%type;
      v1_cdmodal ge_modalidades.cod_modalidad%TYPE;
      v1_cdofici ba_oficinas.cod_oficina%TYPE;
      v1_nrcuent ge_cuentas.nro_cuenta%TYPE;
      v1_saldoac cc_cta_bancarias.sal_minimo%type;
      ------------------------------------------------------------------------
      ---- VARIABLES CURSOR LOOP MENOR
      ------------------------------------------------------------------------
      v_comfech  ba_oficinas.fec_insercion%type;
      v_candias  NUMBER(06);
      v_ttdiasg  NUMBER(06);
      v_cubrio   VARCHAR2(01);
      v_sitsald  VARCHAR2(01);
      ---------------FECHAS----------------
      v_difdias      NUMBER(6) := 0;
      v_fecinic      date;
      v_fec_aux      DATE := NULL;
      v_dia_cargos   NUMBER(4);
      v_can_dia_tmp  number(6);
      v_can_dia_sobregiro_tmp  number(6);
      v_can_dia_anterior  number(6);
      v_can_dia_sob_anterior  number(6);
      ----------------------  DEFINICION LOOP MAYOR  ------------------------
      --ver si esta ok q tome saldos batch, ya q este proceso deber¿a correrse antes del pra_con_transaccion
      CURSOR cu_cta_corrientes IS
         SELECT a.cod_modulo,
                a.cod_modalidad,
                a.cod_oficina,
                a.nro_cuenta,
                nvl(a.sal_total, 0) - nvl(a.sal_retenido, 0) - nvl(a.sal_bloqueado, 0),
                b.can_dia_actual,
                b.can_dia_sob_actual,
                b.can_dias,
                b.can_dia_sobregiro                
           FROM cc_cta_corrientes a,
                CC_SOB_DAT_CALCULADOS_TMP b
          WHERE a.nro_cuenta = b.nro_cuenta(+)
            AND a.cod_modulo = 4
            AND a.cod_modalidad = 41
            AND nvl(a.sal_total, 0) - nvl(a.sal_retenido, 0) - nvl(a.sal_bloqueado, 0) < 0
            AND a.estado <> 'C';
      -----------------------
      CURSOR cc_lin_sobregiros
      (
         v_fcsaldo DATE,
         v_saldo   NUMBER
      ) IS
         SELECT 'S'
           FROM cc_lin_sobregiros
          WHERE nro_cuenta = v1_nrcuent
            AND v_fcsaldo BETWEEN fec_inicio AND fec_vencimiento
               --Se contabilizan tambien las lineas transitorias and nvl(tipo, 'T') = 'P'
            AND estado = 'A'
          GROUP BY nro_cuenta
         HAVING SUM(monto) >= abs(v_saldo);
      --------------------------------
      CURSOR c_sobregiros IS
               SELECT csobr.nro_cuenta, csobr.fecha, csobr.liquidado, csobr.saldo,
                      csobr.mto_linea
                 FROM cc_sobregiros_tmp csobr
                WHERE csobr.nro_cuenta = v1_nrcuent
                  AND csobr.fecha = v_fec_aux -----------------------mayor o igual
             ORDER BY fecha;
   BEGIN
      v_dia_cargos := nvl(fug_obt_pardinamico('DIA_INA_CAR_SOBREGIROS', 4, 41), 9999);
      ------------------------  LEER LOOP MAYOR  -----------------------------
      IF cu_cta_corrientes%ISOPEN THEN
         CLOSE cu_cta_corrientes;
      END IF;
      OPEN cu_cta_corrientes;
      LOOP
         FETCH cu_cta_corrientes
            INTO v1_cdmodul, v1_cdmodal, v1_cdofici, v1_nrcuent, v1_saldoac, v_can_dia_tmp, v_can_dia_sobregiro_tmp,
            v_can_dia_anterior, v_can_dia_sob_anterior;
         EXIT WHEN cu_cta_corrientes%NOTFOUND;
         vg_nro_cuenta := v1_nrcuent;
         v_candias := 0;
         v_ttdiasg := 0;
         v_sitsald := NULL;
         v_cubrio  := 'N';
         v_comfech := vg_fec_actual; --Ajuste para que realice el conteo de dias hasta la fecha actual, modif. el 13/04/2010
         --Recupera Valores Calculados--
         vg_can_dia_sobregiro := v_can_dia_sobregiro_tmp;
         vg_can_dia_exceso := v_can_dia_tmp;
         v_ttdiasg := v_can_dia_tmp;
         -- EP - N.AN. 2014-10-23 SC 9468 - ITGF - Dias de Mora de Cuenta Corriente
         -- cuando el sobregiro inicia un dia habil despues de fin de semana o feriado
         -- solo se actualiza el registro una vez y por logica se inicia en 0
         vg_can_dia_sob_original := vg_can_dia_sobregiro;
         vg_can_dia_exc_original := vg_can_dia_exceso;
         ------Determinacion de Situacion del sobregiro--------
         --campo cc_lin_sobregiros.sit_deuda
         IF nvl(v_ttdiasg, 0) < 61 THEN
            v_sitsald := 'S';
         ELSIF v_ttdiasg < 91 THEN
            v_sitsald := 'V';
         ELSIF v_ttdiasg < 181 THEN
            v_sitsald := 'G';
         ELSIF v_ttdiasg < 361 THEN
            v_sitsald := 'M';
         ELSE
            v_sitsald := 'I';
         END IF;
         -- Actualiza la cantidad de dias de sobregiro en cc_sobregiros
            -- calcula por cuantos dias tiene que agregar --
            if vg_fec_actual = vg_ult_dia_mes_habil then
               v_difdias := round(vg_ult_dia_mes - vg_fec_anterior , 0) - 1;
               v_fecinic := vg_fec_anterior;
            elsif vg_fec_actual = vg_pri_dia_mes_habil then
               v_difdias := round(vg_pri_dia_mes_habil - vg_pri_dia_mes, 0);
               v_fecinic := vg_pri_dia_mes - 1;
            else
               v_difdias := round(vg_fec_actual - vg_fec_anterior , 0) - 1;
               v_fecinic := vg_fec_anterior;
            end if;
            -- Como la funcion que nos devuelve los dias de sobregiro calcula sobre la fecha de hoy
            -- verificamos que si es mas de un d¿a(fines de semana) lo que tenemos que insertar,
            -- restamos a los sobregiros la cantidad de d¿as para que el cursor vaya de menor a mayor.
            if v_difdias > 0 then
               if vg_can_dia_exceso > 0 and vg_can_dia_exceso >= v_difdias then
                  vg_can_dia_exceso := vg_can_dia_exceso - v_difdias;
               else
                  if v_can_dia_anterior > 0 and v_difdias > 1 then
                     vg_can_dia_exceso := v_can_dia_anterior;
                  else
                     vg_can_dia_exceso := 0; -- para que no quede negativo
                  end if;
               end if;
               ---
               if vg_can_dia_sobregiro > 0 and vg_can_dia_sobregiro >= v_difdias then
                  vg_can_dia_sobregiro := vg_can_dia_sobregiro - v_difdias;
               else
                  vg_can_dia_sobregiro := 0;  -- para que no quede negativo
               end if;
            end if;

            -- Recorremos el loop de fecha menor a mayor.
            FOR i IN 0 .. v_difdias LOOP
               v_fec_aux := (v_fecinic + 1)  + i;
               ---
               FOR sob IN c_sobregiros LOOP
                 -- EP - N.AN. 2014-10-23 SC 9468 - ITGF - Dias de Mora de Cuenta Corriente
                 -- verifica si la cuenta ya tenia sobregiro en fecha anterior a fin de semana o feriados
                  vg_tie_sob_fec_anterior := 'N';
                  if v_difdias > 0 then
                     -- Se verifica si la cuenta tienen sobregiro el dia habil anterior
                     begin
                        -- select a cc_sobregiros para la cuenta al dia habil anterior
                        -- en caso contrario
                        SELECT 'S'
                        INTO vg_tie_sob_fec_anterior
                        FROM cc_sobregiros_res_ant
                        WHERE nro_cuenta = sob.nro_cuenta;
                     exception
                        when no_data_found then
                             -- no tiene sobregiro antes del fin de semana/feriado
                             -- se utiliza la cantidadde dias soregiro y exceso original
                              vg_can_dia_sobregiro := vg_can_dia_sob_original;
                              vg_can_dia_exceso:= vg_can_dia_exc_original ;
                     end;
                  end if;
               -- FIN EP - N.AN. 2014-10-23 SC 9468 - ITGF - Dias de Mora de Cuenta Corriente
               -- menor o igual a el importe de la linea de sobregiro no se considera exceso
               -- por lo cual se cera el contador de d¿as de exceso
               IF sob.saldo <= sob.mto_linea THEN
                  vg_can_dia_exceso := 0;
               END IF;

               UPDATE cc_sobregiros_tmp
                  SET can_dias  = vg_can_dia_exceso,
                      can_dia_sobregiro = vg_can_dia_sobregiro,
                      liquidado =
                        (CASE
                            WHEN vg_can_dia_exceso >= v_dia_cargos THEN
                               'S'
                            ELSE
                               'N'
                            END),
                      mto_linea =
                         (CASE
                            -- si la cantidad de d¿as de sobregiro es mayor a 30
                            -- hay exceso y el monto de la l¿nea de sobregiro debe ser cero
                          WHEN sob.saldo > sob.mto_linea  THEN
                             0
                          ELSE
                             -- si la cantidad de d¿as de sobregiro es menor a 31
                             -- el monto de l¿nea de sobregiro debe obtenerse con la funci¿n                         
                             --Incidente encontrado en desarrollo de DESOPIMI-323:--
                             --sobreescribe valor ingresado en lp_gen_cc_sobregiros/DYDMR-1951--
                             --nvl(pag_cta.fu_obt_lin_sobregiro(sob.nro_cuenta, sob.fecha), 0)
                             mto_linea --DESOPIMI-323 se deja el valor original--
                          END)
                WHERE nro_cuenta = sob.nro_cuenta
                  AND fecha = sob.fecha
                  AND liquidado = sob.liquidado;
                 -- si el monto de la linea de sobregiro es mayor a 0 y el saldo
                 -- de sobregiro es mayor a cero hay sobregiro y hay que sumar 1 d¿a
                 -- o si vg_can_dia_sobregiro es mayor a 0 hay sobregiro y se debe sumar 1 d¿a
                 -- esto se agrego para los dias viernes y visperas de feriados en los cuales se crean
                 -- registros para m¿s de un d¿a y el loop se recorre la cantidad de d¿as a crear, entonces
                 -- si el primer d¿a generado tiene sobregiro a los demas d¿as hay que seguir sumandole 1 d¿a
                  IF (nvl(sob.mto_linea,0) > 0 AND nvl(sob.saldo,0) >= 0 )
                      OR vg_can_dia_sobregiro > 0 THEN
                      vg_can_dia_sobregiro := nvl(vg_can_dia_sobregiro, 0) + 1;
                  END IF;
                  vg_can_dia_exceso:= vg_can_dia_exceso + 1;
               END LOOP;
            END LOOP;
            --  si la cantidad de sobregiro es mayor a cero restar 1 porque al salir del loop
            --anterior suma un d¿a demas
            IF vg_can_dia_sobregiro > 0 THEN
               vg_can_dia_sobregiro := vg_can_dia_sobregiro - 1;
            END IF;
            IF vg_can_dia_exceso > 0 then
               vg_can_dia_exceso := vg_can_dia_exceso - 1;
            END IF;
            -- Recien ahora inserto los datos en el cc_sobregiros_res
            INSERT INTO cc_sobregiros_res_tmp
                   (nro_cuenta, can_dias, sit_deuda, can_dia_sobregiro)
            VALUES
                   (v1_nrcuent, /*nvl(vg_can_dia_exceso, 0) DYDMR-3126 14/03/16*/ v_ttdiasg, v_sitsald, nvl(vg_can_dia_sobregiro, 0));

         ------------------------  FIN LOOP MENOR  ------------------------------
      END LOOP;
      vg_nro_cuenta := null;
      IF cu_cta_corrientes%ISOPEN THEN
         CLOSE cu_cta_corrientes;
      END IF;
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'ERROR. Calcular_dias ' || SQLERRM);
   END;
   --Genera sobregiros diarios--
   PROCEDURE lp_gen_cc_sobregiros IS
      v_fecauxi      DATE;
      v_fecinic      date;
      v_difdias      NUMBER(6);
      v_sal_total    cc_cta_corrientes.sal_total%TYPE;
      v_sal_retenido cc_cta_corrientes.sal_retenido%TYPE;
      v_exi_sobregiro varchar2(1);
      CURSOR cuentas IS
         SELECT a.nro_cuenta,
                v_fecauxi,
                abs(nvl(a.sal_total, 0) - nvl(a.sal_retenido, 0) - nvl(a.sal_bloqueado, 0)) saldo,
                a.sal_total,
                a.sal_retenido,
                a.cod_moneda,
                decode(a.nro_cuenta,b.nro_cuenta,'S','N') sob_dia_anterior,
                b.saldo saldo_ant, b.sal_total sal_tot_ant, b.sal_retenido sal_ret_ant, 
                b.liquidado liq_ant, b.mto_linea mto_lin_ant
           FROM cc_cta_corrientes a, cc_sobregiros_ant b
          WHERE a.cod_modalidad = 41
            AND a.estado <> 'C'
            AND nvl(a.sal_total, 0) - nvl(a.sal_retenido, 0) - nvl(a.sal_bloqueado, 0) < 0
            AND a.nro_cuenta=b.nro_cuenta(+)
            AND vg_fec_anterior=b.fecha(+);
   BEGIN
      vg_fec_min_sob := vg_fec_actual;
      --calcula por cuantos dias tiene que agregar--
      if vg_fec_actual = vg_ult_dia_mes_habil then
         v_difdias := round(vg_ult_dia_mes - vg_fec_anterior , 0) - 1;
         v_fecinic := vg_fec_anterior;
      elsif vg_fec_actual = vg_pri_dia_mes_habil then
         v_difdias := round(vg_pri_dia_mes_habil - vg_pri_dia_mes, 0);
         v_fecinic := vg_pri_dia_mes - 1;
      else
         v_difdias := round(vg_fec_actual - vg_fec_anterior , 0) - 1;
         v_fecinic := vg_fec_anterior;
      end if;
      vg_dif_dias := v_difdias;--DESOPIMI-323 PyR Jul/2017 NAF
      FOR i IN 0 .. v_difdias LOOP
         v_fecauxi := (v_fecinic + 1)  + i;
         FOR j IN cuentas LOOP
            vg_tie_sob_fec_anterior := null;
            vg_aux_saldo := null;
            vg_aux_sal_total := null;
            vg_aux_sal_retenido := null;
            vg_aux_mto_linea := null;
            
            IF j.sal_total < 0 THEN
               v_sal_total := abs(j.sal_total);
            ELSE
               v_sal_total := 0;
            END IF;
            v_sal_retenido := nvl(j.saldo, 0) - nvl(v_sal_total, 0);
            -- EP - N.AN. 2014-10-23 SC 9468 - ITGF - Dias de Mora de Cuenta Corriente
            -- controla si la cuenta ya tenia sobregiro en fecha anterior
            -- si no es asi, no corresponde insertar sabado, domingo o feriado
            if v_difdias > 0 then
              -- Se verifica si la cuenta tienen sobregiro el dia habil anterior
              vg_tie_sob_fec_anterior := nvl(j.sob_dia_anterior,'N');
              vg_act_sobregiro := 'N';
              
              --DYDMR-1951 ITGF - Calculo de Sobregiro Mayo 2015 - EL CORRAL S.A. - SC 17012
              -- se utilizan valores de fecha anterior
              if vg_fec_actual > v_fecauxi then
                 vg_aux_saldo := abs(j.saldo_ant);
                 vg_aux_sal_total := nvl(j.sal_tot_ant,0);
                 vg_aux_sal_retenido := nvl(j.sal_ret_ant,0);
                 vg_aux_mto_linea := nvl(j.mto_lin_ant,0);    
              end if;
              if vg_fec_actual <= v_fecauxi then
                -- si es fecha actual o superior consulta la linea 
                vg_aux_mto_linea := nvl(pag_cta.fu_obt_lin_sobregiro(j.nro_cuenta, vg_fec_actual), 0);
                vg_aux_saldo := j.saldo;
                vg_aux_sal_total := nvl(v_sal_total, 0); 
                vg_aux_sal_retenido := nvl(v_sal_retenido, 0);
              end if;
                 
              -- el sobregiro de la cuenta inicia hoy (no tiene sobregiro dia anterior) insertar solo para hoy
              if vg_tie_sob_fec_anterior = 'N' then
                if v_fecauxi = vg_fec_actual then
                  -- es fecha de hoy, se inserta
                   vg_act_sobregiro := 'S';
                else
                   -- es fecha anterior, no corresponde insertar
                   vg_act_sobregiro := 'N';
                end if;
              else
                -- la cuenta ya tenia sobregiro en fecha habil anterior
                -- se insertan para sabado, domingo y feriados
                vg_act_sobregiro := 'S';
              end if;
         else
           vg_act_sobregiro := 'S';
           vg_aux_mto_linea := nvl(pag_cta.fu_obt_lin_sobregiro(j.nro_cuenta, vg_fec_actual), 0); -- DYDMR-7100
         end if;

         if  vg_act_sobregiro = 'S' then
            ----------------------------------------
            --Validacion si ya existe algun registro
            ----------------------------------------
            v_exi_sobregiro := 'N';
            select decode(nvl(count(*),0),0,'N','S')
              into v_exi_sobregiro
              from cc_sobregiros_tmp x
             where nro_cuenta = j.nro_cuenta
               and fecha = v_fecauxi
               and liquidado = 'N';
            
            vg_nro_cuenta := j.nro_cuenta;
            if v_exi_sobregiro = 'N' then
              -- Almacena Minima Fecha de Sobregiro Insertada--
              if (vg_fec_min_sob > v_fecauxi) then
                vg_fec_min_sob := v_fecauxi;
              end if;
              if v_fecauxi <> vg_fec_actual then
                if vg_tie_sob_fec_anterior = 'S' then
                   INSERT INTO cc_sobregiros_tmp
                       (nro_cuenta, fecha, saldo, sal_total, sal_retenido, liquidado, mto_linea)
                   VALUES
                       (j.nro_cuenta, v_fecauxi, nvl(vg_aux_saldo,0), nvl(vg_aux_sal_total,0), nvl(vg_aux_sal_retenido,0), 'N', nvl(vg_aux_mto_linea,0) );
                 end if;
              else
               INSERT INTO cc_sobregiros_tmp
                   (nro_cuenta, fecha, saldo, sal_total, sal_retenido, liquidado, mto_linea)
               VALUES
                   (j.nro_cuenta, v_fecauxi, nvl(j.saldo, 0), nvl(v_sal_total, 0), nvl(v_sal_retenido, 0), 'N', nvl(vg_aux_mto_linea,0));
              end if;
            else
                update cc_sobregiros_tmp x
                   set saldo = nvl(j.saldo,0),
                       sal_total = nvl(v_sal_total, 0),
                       sal_retenido = nvl(v_sal_retenido, 0),
                       mto_linea = nvl(vg_aux_mto_linea,0)
                 where nro_cuenta = j.nro_cuenta
                   and fecha = v_fecauxi
                   and liquidado = 'N';
            end if;
          end if;
         END LOOP;
      END LOOP;
      vg_nro_cuenta := null;
   END;
   --Habilita de vuelta la linea de sobregiro si se produjo un CLEAN-UP--
   --(si el cliente pago su exceso o pago su sobregiro)--
   PROCEDURE lp_hab_lin_sobregiro IS
      CURSOR cu_cta_corrientes IS
         SELECT a.nro_cuenta,
                nvl(a.sal_total, 0) - nvl(a.sal_retenido, 0) - nvl(a.sal_bloqueado, 0) saldo,
                b.monto
           FROM cc_cta_corrientes a, cc_lin_sobregiros b
          WHERE a.nro_cuenta = b.nro_cuenta
            AND a.estado <> 'C'
            AND b.fec_vencimiento > vg_fec_actual
            AND b.estado = 'V';
      v_cam_estado VARCHAR2(1);
   BEGIN
      FOR a IN cu_cta_corrientes LOOP
         v_cam_estado := 'N';
         IF a.saldo >= 0 THEN
            --cleanup
            v_cam_estado := 'S';
         ELSIF abs(a.saldo) <= a.monto THEN
            --pago exceso dentro de los 30 dias
            v_cam_estado := 'S';
         END IF;
         -- habilito la linea de sobregiro
         IF v_cam_estado = 'S' THEN
            BEGIN
               lp_act_lin_sobregiro(a.nro_cuenta, 'A');
            EXCEPTION
               WHEN OTHERS THEN
                  RAISE_APPLICATION_ERROR(-20000, 'al actualizar. ' || SQLERRM);
            END;
         END IF;
      END LOOP;
   EXCEPTION
      WHEN OTHERS THEN
         IF SQLCODE <= -20000 THEN
            RAISE;
         ELSE
            RAISE_APPLICATION_ERROR(-20010, 'lp_hab_lin_sobregiros. ' || SQLERRM);
         END IF;
   END;
BEGIN
   --Traer valores de variables--
   vg_lugar   := 'Traer Valores';
   vg_hor_inicio := to_char(sysdate,'hh24:mi:ss');
   rg_cal  := pag_cal.fu_obt_reg_cal(4);
   vg_ult_dia_mes_habil := rg_cal.ult_dia_mes_habil;   
   vg_ult_dia_mes       := rg_cal.ult_dia_mes;
   vg_pri_dia_mes       := rg_cal.pri_dia_mes;   
   vg_pri_dia_mes_habil := rg_cal.pri_dia_mes_habil;
   vg_fec_actual        := rg_cal.fec_actual;
   vg_fec_anterior      := rg_cal.fec_anterior;
   vg_tra_sobregiros := fug_obt_pardinamico('IND_ACT_SOB_GENERADOS');
   vg_cod_programa := 'PRC_GEN_SOB_CUENTAS';
   vg_hor_fin := to_char(sysdate,'hh24:mi:ss');
   prg_act_log_procesos(vg_cod_programa,vg_lugar, vg_fec_actual, vg_hor_inicio, vg_hor_fin);
   
   --Verificar Base y Usuario--
   vg_lugar   := 'lp_ver_usu_bas_datos';
   vg_hor_inicio := to_char(sysdate,'hh24:mi:ss');
   lp_ver_usu_bas_datos;
   vg_hor_fin := to_char(sysdate,'hh24:mi:ss');
   prg_act_log_procesos(vg_cod_programa,vg_lugar, vg_fec_actual, vg_hor_inicio, vg_hor_fin);
      
   --Verificar consistencia cc_sobregiros_res_ant--
   vg_lugar   := 'lp_ver_con_sob_res_ant';
   vg_hor_inicio := to_char(sysdate,'hh24:mi:ss');
   lp_gen_est_tablas('CC_SOBREGIROS_RES_ANT');
   lp_gen_est_tablas('CC_SOBREGIROS_ANT');
   lp_ver_con_sob_res_ant;
   vg_hor_fin := to_char(sysdate,'hh24:mi:ss');
   prg_act_log_procesos(vg_cod_programa,vg_lugar, vg_fec_actual, vg_hor_inicio, vg_hor_fin);
   
   --Borrar tablas temporales--
   vg_lugar   := 'lp_tru_tab_temporales';
   vg_hor_inicio := to_char(sysdate,'hh24:mi:ss');
   lp_tru_tab_temporales;
   vg_hor_fin := to_char(sysdate,'hh24:mi:ss');
   prg_act_log_procesos(vg_cod_programa,vg_lugar, vg_fec_actual, vg_hor_inicio, vg_hor_fin);
   
   --Habilitar nuevamente las lineas de sobregiro--
   vg_lugar   := 'lp_hab_lin_sobregiro';
   vg_hor_inicio := to_char(sysdate,'hh24:mi:ss');
   lp_hab_lin_sobregiro;
   vg_hor_fin := to_char(sysdate,'hh24:mi:ss');
   prg_act_log_procesos(vg_cod_programa,vg_lugar, vg_fec_actual, vg_hor_inicio, vg_hor_fin);
   
   --Generar cc_sobregiros--
   vg_lugar   := 'lp_gen_cc_sobregiros';
   vg_hor_inicio := to_char(sysdate,'hh24:mi:ss');
   lp_gen_cc_sobregiros;
   lp_gen_est_tablas('CC_SOBREGIROS_TMP');
   vg_hor_fin := to_char(sysdate,'hh24:mi:ss');
   prg_act_log_procesos(vg_cod_programa,vg_lugar, vg_fec_actual, vg_hor_inicio, vg_hor_fin);
   
   --Calcular cantidad de dias de sobregiro--
   vg_lugar   := 'lp_cal_dat_sobregiro';
   vg_hor_inicio := to_char(sysdate,'hh24:mi:ss');
   lp_cal_dat_sobregiro;
   lp_gen_est_tablas('CC_SOB_DAT_CALCULADOS_TMP');
   vg_hor_fin := to_char(sysdate,'hh24:mi:ss');
   prg_act_log_procesos(vg_cod_programa,vg_lugar, vg_fec_actual, vg_hor_inicio, vg_hor_fin);

   --Calcular dias de sobregiro y situacion e inserta cc_sobregiros_res_tmp--
   vg_lugar   := 'lp_cal_sob_diario';
   vg_hor_inicio := to_char(sysdate,'hh24:mi:ss');
   lp_cal_sob_diario;
   lp_gen_est_tablas('CC_SOBREGIROS_RES_TMP');
   vg_hor_fin := to_char(sysdate,'hh24:mi:ss');
   prg_act_log_procesos(vg_cod_programa,vg_lugar, vg_fec_actual, vg_hor_inicio, vg_hor_fin);
   
   --Copia a tablas definitivas--
   IF vg_tra_sobregiros = 'S' THEN
      --Trunca cc_sobregiros_res--
      vg_lugar   := 'lp_tru_tab_sobregiros_res';
      vg_hor_inicio := to_char(sysdate,'hh24:mi:ss');
      lp_tru_tab_sobregiros_res;
      vg_hor_fin := to_char(sysdate,'hh24:mi:ss');
      prg_act_log_procesos(vg_cod_programa,vg_lugar, vg_fec_actual, vg_hor_inicio, vg_hor_fin);
      
      --Borra cc_sobregiros rango de fechas generados--
      vg_lugar   := 'lp_eli_sobregiros';
      vg_hor_inicio := to_char(sysdate,'hh24:mi:ss');
      lp_eli_sobregiros;
      vg_hor_fin := to_char(sysdate,'hh24:mi:ss');
      prg_act_log_procesos(vg_cod_programa,vg_lugar, vg_fec_actual, vg_hor_inicio, vg_hor_fin);
      
      --Transfiere a cc_sobregiros_res--
      vg_lugar   := 'lp_ins_res_generado';
      vg_hor_inicio := to_char(sysdate,'hh24:mi:ss');
      lp_ins_res_generado;
      vg_hor_fin := to_char(sysdate,'hh24:mi:ss');
      prg_act_log_procesos(vg_cod_programa,vg_lugar, vg_fec_actual, vg_hor_inicio, vg_hor_fin);
      
      --Transfiere a cc_sobregiros--
      vg_lugar   := 'lp_ins_sob_generado';
      vg_hor_inicio := to_char(sysdate,'hh24:mi:ss');
      lp_ins_sob_generado;
      vg_hor_fin := to_char(sysdate,'hh24:mi:ss');
      prg_act_log_procesos(vg_cod_programa,vg_lugar, vg_fec_actual, vg_hor_inicio, vg_hor_fin);      
   END IF;
EXCEPTION
  WHEN OTHERS THEN
      raise_application_error(-20005, vg_lugar ||' - '|| vg_nro_cuenta || ' '|| sqlerrm);
END;
/

