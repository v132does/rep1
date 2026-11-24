CREATE OR REPLACE PROCEDURE IT.PRC_PRO_COB_CAR_PAGOS (p_nro_cuenta IN VARCHAR2 DEFAULT NULL) IS
   v_cod_tas_cargo    ge_movimientos.cod_tasa%TYPE;
   v_val_tas_cargo    ge_movimientos.val_tasa%TYPE;
   v_val_cargo        ge_movimientos.val_tasa%TYPE;
   v_cod_tra_impuesto ge_movimientos.cod_transaccion%TYPE;
   v_cod_tas_impuesto ge_movimientos.cod_tasa%TYPE;
   v_val_tas_impuesto ge_movimientos.val_tasa%TYPE;
   v_val_impuesto     ge_movimientos.val_tasa%TYPE;
   v_cod_transaccion  ge_movimientos.cod_transaccion%TYPE;
   v_fec_actual       ge_movimientos.fecha%TYPE;
   v_hor_actual       ge_movimientos.hora%TYPE;   
   v_nro_secuencia    ge_movimientos.nro_secuencia%type:=0;

   v_can_oper           NUMBER:=0;
   v_can_ope_dia        NUMBER:=0;
   v_can_pag_permitidos NUMBER:=0;
   v_can_max_cheque     NUMBER:=0;
   v_can_operacion      NUMBER:=0;
   v_can_exonerar       NUMBER:=0;  
   v_anio_actual        NUMBER;
   v_mes_actual         NUMBER;    
   v_fec_inicial        DATE;   

   --Datos de la cuenta
   v_sal_promedio   NUMBER;
   v_sal_pro_ahorro NUMBER;
   v_nro_cta_ahorro VARCHAR2(20);
   v_redondeo       NUMBER;

   --Cursor de cuentas
   CURSOR ctas IS
      SELECT c.nro_cuenta, g.cod_modulo, g.cod_modalidad, g.cod_moneda, g.cod_oficina, g.cod_sub_modalidad
        FROM cc_cta_corrientes c, ge_cuentas g
       WHERE c.nro_cuenta = g.nro_cuenta
         AND c.nro_cuenta = nvl(p_nro_cuenta, c.nro_cuenta)
         AND c.cod_modulo = 4
         AND c.cod_modalidad = 41
         and c.fec_apertura < v_fec_inicial
         AND c.estado NOT IN ('T', 'C', 'A', 'X')
    order by g.cod_modulo, g.cod_modalidad, g.cod_moneda, g.cod_oficina, g.cod_sub_modalidad, c.nro_cuenta;
   --- Variables para corte de control
   v_cod_modulo        ba_modulos.cod_modulo%type := 4; 
   v_cod_modalidad     ge_modalidades.cod_modalidad%type := 41;
   v_cod_moneda        ba_monedas.cod_moneda%type := pag_gen.FU_OBT_MON_LOCAL;
   v_cod_oficina       ba_oficinas.cod_oficina%type := fun_obt_ofi_matriz;
   v_cod_sub_modalidad ge_sub_modalidades.cod_sub_modalidad%type := 1;
   ---
   v_fre_proceso VARCHAR2(1) := fug_obt_fre_proceso('PRC_PRO_COB_CAR_PAGOS');
   v_db_prod     VARCHAR2(1) := fug_ind_produccion;
   v_val_exo_cargo    ge_movimientos.val_tasa%type;
   v_val_exo_impuesto ge_movimientos.val_tasa%type;
   v_tip_valor        ge_tasas.tip_valor%type;
   v_cod_tas_exo      ge_tasas.cod_tasa%TYPE;
   v_can_oper_exo     NUMBER:=0;
   v_nro_cuenta       ge_cuentas.nro_cuenta%TYPE;
   ---
   function lf_obt_cod_tasa (
      p_cod_transaccion ge_transacciones.cod_transaccion%TYPE,
      p_cod_modulo      ge_transacciones.cod_modulo%TYPE,
      p_cod_modalidad   ge_transacciones.cod_modalidad%TYPE)
      return number
   is
      v_cod_tasa ge_tasas.cod_tasa%TYPE;
   begin
      select a.cod_tasa
        into v_cod_tasa
        from ge_transacciones a
       where a.cod_transaccion = p_cod_transaccion
         and a.cod_modulo      = p_cod_modulo
         and a.cod_modalidad   = p_cod_modalidad;
       return v_cod_tasa;
   exception
      when others then 
         return null;
   end;
   ---
   function lf_obt_tra_hijo (
      p_cod_tra_cargo ge_transacciones.cod_transaccion%TYPE,
      p_cod_modulo      ge_transacciones.cod_modulo%TYPE,
      p_cod_modalidad   ge_transacciones.cod_modalidad%TYPE)
      return number
   is
      v_cod_tra_hijo ge_tasas.cod_tasa%TYPE;
   begin
      select cod_tra_hijo
        into v_cod_tra_hijo
        from ge_transacciones_det
       where cod_modulo = p_cod_modulo
         and cod_modalidad = p_cod_modalidad
         and cod_transaccion = p_cod_tra_cargo
         and cod_mod_hijo = p_cod_modulo
         and cod_mad_hijo = p_cod_modalidad
         and cod_tra_hijo <> p_cod_tra_cargo -- Que la transacci¿n hijo sea diferente de la padre PV 02/11/09
         and rownum = 1;
       return v_cod_tra_hijo;
   exception
      when others then 
         return null;
   end;

BEGIN
   BEGIN
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 1;
   END;
   v_fec_actual     := pag_cal.fu_obt_fec_actual(4);
   --v_hor_actual     := fug_ini_hora(SYSDATE, 'HH24:MI:SS');
   --FQ Para evitar error de PK
   v_hor_actual := to_char(sysdate,'HH24:MI:SS');
   v_hor_actual := fug_obt_hor_disponible(v_fec_actual,v_hor_actual,user,'N');
   v_fec_inicial    := to_date('01/' || to_char(v_fec_actual, 'MM/YYYY'), 'DD/MM/YYYY');
   v_anio_actual    := to_number(to_char(v_fec_actual, 'YYYY'));
   v_mes_actual     := to_number(to_char(v_fec_actual, 'MM'));
   FOR reg IN ctas LOOP
      -- obtengo datos de la cuenta
      pag_cta.PR_OBT_CUENTA(reg.nro_cuenta);
      v_nro_cuenta := reg.nro_cuenta;
      if pag_cta.fu_obt_cod_error() <> 0 then
         raise_application_error(-20000,pag_cta.fu_obt_cod_error()||' - '||pag_cta.fu_obt_msj_error());
      end if;
      --- Corte de Control para llamar a parámetro dinámico
      --- rabf 01/mar/2013
      if reg.cod_modulo <> nvl(v_cod_modulo,reg.cod_modulo) or
         reg.cod_modalidad <> nvl(v_cod_modalidad,reg.cod_modalidad) or
         reg.cod_moneda <> nvl(v_cod_moneda,reg.cod_moneda) or
         reg.cod_oficina <> nvl(v_cod_oficina,reg.cod_oficina) or
         reg.cod_sub_modalidad <> nvl(v_cod_sub_modalidad,reg.cod_sub_modalidad) then
         v_can_max_cheque := fug_obt_pardinamico('CAN_MAX_CHEQUE', reg.cod_modulo, reg.cod_modalidad,
                             reg.cod_moneda, reg.cod_oficina, reg.cod_sub_modalidad);
         v_cod_modulo        := reg.cod_modulo;
         v_cod_modalidad     := reg.cod_modalidad;
         v_cod_moneda        := reg.cod_moneda;
         v_cod_oficina       := reg.cod_oficina;
         v_cod_sub_modalidad := reg.cod_sub_modalidad;
      end if;
      --- Limpia variables
      v_cod_tas_cargo := 0;
      v_val_tas_cargo := 0;
      v_val_cargo := 0;

      v_can_oper:= 0;
      v_can_ope_dia:= 0;
      v_can_pag_permitidos:= 0;
      v_can_operacion:= 0;
      v_can_exonerar:= 0; 
     
      v_sal_promedio:= 0;
      v_sal_pro_ahorro:= 0;
      v_nro_cta_ahorro:= 0;
      ---
      v_can_oper_exo := 0;
      ---
  
      v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', pag_cta.g_ctas.cod_modulo, pag_cta.g_ctas.cod_modalidad, pag_cta.g_ctas.cod_moneda);
      IF  pag_cta.g_ctas.fec_apertura < v_fec_inicial THEN
         --Obtener cantidad de operaciones realizadas en el mes
         SELECT COUNT(1)
           INTO v_can_oper
           FROM ge_transacciones, cc_movimientos_his
          WHERE ge_transacciones.cod_modulo(+) = cc_movimientos_his.cod_modulo
            AND ge_transacciones.cod_modalidad(+) = cc_movimientos_his.cod_modalidad
            AND ge_transacciones.cod_transaccion(+) = cc_movimientos_his.cod_transaccion
            AND nro_cuenta = reg.nro_cuenta
            AND fecha BETWEEN v_fec_inicial AND v_fec_actual
            AND decode(cc_movimientos_his.cod_transaccion, 515, 'C', 565, 'C', ge_transacciones.tipo) = 'D'
            AND estado = 'N'
            AND reversado = 'N'
            AND cod_tra_padre IN (354, 355, 320)
            AND cc_movimientos_his.cod_transaccion IN (590, 521, 591)
            AND monto > 0;
         SELECT COUNT(1)
           INTO v_can_ope_dia
           FROM ge_transacciones, ge_movimientos
          WHERE ge_transacciones.cod_modulo(+) = ge_movimientos.cod_modulo
            AND ge_transacciones.cod_modalidad(+) = ge_movimientos.cod_modalidad
            AND ge_transacciones.cod_transaccion(+) = ge_movimientos.cod_transaccion
            AND nro_cuenta = reg.nro_cuenta
            AND decode(ge_movimientos.cod_transaccion, 515, 'C', 565, 'C', ge_transacciones.tipo) = 'D'
            AND estado = 'N'
            AND reversado = 'N'
            AND cod_tra_padre IN (354, 355, 320)
            AND ge_movimientos.cod_transaccion IN (590, 521, 591)
            AND monto > 0;
         -- sumo con lo del dia los datos del historico
         v_can_oper := nvl(v_can_oper, 0) + nvl(v_can_ope_dia, 0);

         IF nvl(v_can_oper, 0) > 0 THEN
            BEGIN
               SELECT nvl(round(nvl(sal_acu_diario, 0) / can_dia_acumulado, 0), 0)
                 INTO v_sal_promedio
                 FROM cc_sal_mensuales
                WHERE nro_cuenta = reg.nro_cuenta
                  AND ano = v_anio_actual
                  AND mes = v_mes_actual
                  AND nvl(can_dia_acumulado, 0) <> 0;
            EXCEPTION
               --AP 2626   20/12/2011
               WHEN no_data_found THEN
                  v_sal_promedio := 0;
            END;
            IF pag_cta.g_ctas.cta_combinada = 'S' THEN
               v_nro_cta_ahorro := pag_cta.g_ctas.NRO_CTA_COMBINADA;
               IF v_nro_cta_ahorro IS NOT NULL THEN
                  -- es combinada
                  BEGIN
                     SELECT round(nvl(sal_acu_diario, 0) / can_dia_acumulado, 0) +
                            nvl(v_sal_promedio, 0)
                       INTO v_sal_pro_ahorro --AP 2626   si no recupera ningún registro
                       FROM ah_sal_mensuales
                      WHERE nro_cuenta = v_nro_cta_ahorro
                        AND ano = v_anio_actual
                        AND mes = v_mes_actual
                        AND nvl(can_dia_acumulado, 0) <> 0;
                  EXCEPTION
                     WHEN no_data_found THEN
                        --AP 2626
                        v_sal_pro_ahorro := 0;
                  END;
               END IF;
            END IF;
         
            v_sal_promedio := nvl(v_sal_promedio, 0) + nvl(v_sal_pro_ahorro, 0); --AP 2626 para no perder ningún saldo promedio
         
            --- Obtener cargo
            v_can_exonerar := 0;
            IF v_can_oper > v_can_max_cheque THEN
               /* RI : 01/12/09 : Si la cantidad de operaciones es mayor a lo parametrizado entonces primero debe
               cobrar el cargo que le corresponde segun la tasa matricial segun transaccion 140
               y luego por la diferencia encima de la cantidad maxima le cobra la tasa segun transaccion 4111 */
               --
               --- Obtengo el cargo Segun Tasa Matricial
               prc_obt_cargos( pag_cta.g_ctas.cod_oficina, reg.nro_cuenta, pag_cta.g_ctas.cod_moneda, v_sal_promedio ,
                              nvl(v_can_max_cheque, 0),
                               --se envia la maxima
                               4, 41, 140,
                               --Transaccion para el cobro de cargos por pago de cheques
                              v_cod_tas_cargo, v_val_tas_cargo, v_val_cargo, v_cod_tra_impuesto,
                              v_cod_tas_impuesto, v_val_tas_impuesto, v_val_impuesto,
                              v_can_pag_permitidos);
                         
               v_cod_transaccion := 140;
               v_can_operacion   := nvl(v_can_max_cheque, 0) - nvl(v_can_pag_permitidos, 0);
               --IF v_can_operacion > 0 THEN 
                  --IF v_val_cargo > 0 THEN
               -- RI : 30/01/10 : Volver a sumar el cargo y el iva para multiplicar por la cantidad y despues volver a calcular el iva
               v_val_cargo    := (v_val_cargo + v_val_impuesto) * nvl(v_can_operacion,0);
               v_val_impuesto := round(nvl(v_val_cargo, 0) * nvl(v_val_tas_impuesto, 0) /
                                       (100 + v_val_tas_impuesto), v_redondeo);
               v_val_cargo    := round(nvl(v_val_cargo, 0) - nvl(v_val_impuesto, 0), v_redondeo);
               /*
               || PCC-Exoneración y Extorno de Comisiones y Tasas
               || Se ejecuta si el proceso no es mensual
               || o la base de datos no es producción
               */
               IF v_fre_proceso <> 'M' OR v_db_prod = 'N' THEN
                  v_cod_tas_exo := lf_obt_cod_tasa(140,4,41);
                  -- busco el valor de la tasa
                  begin
                     v_val_exo_cargo := fug_obt_val_tasa(4,
                                                         41,
                                                         pag_cta.G_CTAS.cod_oficina,
                                                         null,
                                                         pag_cta.G_CTAS.cod_moneda,
                                                         nvl(v_sal_promedio,0),
                                                         'N', NULL, 140,
                                                         v_fec_actual);
                  exception
                     when others then
                        raise_application_error(-20000,'Al Obt.Val.Tasa:'||sqlerrm);
                  end;
                  v_tip_valor := fug_obt_tip_val_tasa(v_cod_tas_exo);
                  IF v_tip_valor = 'V' THEN
                     -- si es un valor, se toma directamente
                     v_val_exo_cargo := nvl(v_val_exo_cargo, 0);
                  elsif v_tip_Valor = 'T' then  -- es un codigo de tasa
                     --si es un codigo de tasa hay que ir a buscar el valor con la tasa devuelta y
                     --con el el p_monto2
                     If nvl(v_val_exo_cargo,0) > 0 then
                        v_tip_valor := fug_obt_tip_val_tasa(v_val_exo_cargo);
                        -- busco el valor de la tasa
                        begin
                           v_val_exo_cargo := fug_obt_val_tasa(4,
                                                               41,
                                                               pag_cta.G_CTAS.cod_oficina,
                                                               null,
                                                               pag_cta.G_CTAS.cod_moneda,
                                                               nvl(v_can_max_cheque, 0), 'N',
                                                               v_val_exo_cargo,null,
                                                               v_fec_actual);
                        exception
                           when others then
                              raise_application_error(-20000,'Al Obt.Val.Tasa:'||sqlerrm);
                        end;
                        if v_tip_Valor = 'V' then
                           v_val_exo_cargo := nvl(v_val_exo_cargo, 0);
                        elsif v_tip_valor = 'C' then
                           v_val_exo_cargo := round(nvl(v_can_operacion, 0) *
                                                    nvl(v_val_exo_cargo, 0), v_redondeo);
                        else
                           -- es un porcentaje
                           v_val_exo_cargo := round(nvl(v_sal_promedio, 0) *
                                                    nvl(v_val_exo_cargo, 0) / 100, v_redondeo);
                           --verificar si el monto a cobrar est¿ limitado x el m¿nimo y m¿ximo de la tasa
                           v_val_exo_cargo := round(pag_gen.FU_OBT_VAL_FINAL(v_val_exo_cargo), v_redondeo);
                        end if;
                     else
                        v_val_exo_cargo := 0;
                     end if;
                  ELSE
                     -- es un porcentaje, se considera incluido en el cargo
                     v_val_exo_cargo := round(nvl(v_sal_promedio, 0) * nvl(v_val_exo_cargo, 0) /
                                           (100 + v_val_exo_cargo), v_redondeo);
                     --verificar si el monto a cobrar está limitado x el mínimo y máximo de la tasa
                     v_val_exo_cargo := pag_gen.fu_obt_val_final(v_val_exo_cargo);
                  END IF;
                  ---
                  if v_cod_tra_impuesto is null then
                     v_cod_tra_impuesto := lf_obt_tra_hijo(140,4,41);
                  end if;
                  begin
                     v_val_exo_impuesto := fug_obt_val_tasa(4,
                                                            41,
                                                            pag_cta.G_CTAS.cod_oficina,
                                                            null,
                                                            pag_cta.G_CTAS.cod_moneda,
                                                            0, 'N', NULL,
                                                            v_cod_tra_impuesto,
                                                            v_fec_actual);
                  exception
                     when others then
                        raise_application_error(-20000,'Al Obt.Val.Tasa:'||sqlerrm);
                  end;
                  v_tip_valor := fug_obt_tip_val_tasa(v_cod_tas_impuesto);
                  IF v_tip_valor = 'V' THEN
                     -- si es un valor, se toma directamente
                     v_val_exo_impuesto := nvl(v_val_exo_impuesto, 0);
                  ELSE
                     -- es un porcentaje, se considera incluido en el cargo
                     v_val_exo_impuesto := round(nvl(v_val_exo_cargo, 0) * nvl(v_val_exo_impuesto, 0) /
                                           (100 + v_val_exo_impuesto), v_redondeo);
                     --verificar si el monto a cobrar está limitado x el mínimo y máximo de la tasa
                     v_val_exo_impuesto := pag_gen.fu_obt_val_final(v_val_exo_impuesto);
                  END IF;
                  -- resto el monto del impuesto al cargo, porque va incluido
                  v_val_exo_cargo := nvl(v_val_exo_cargo,0) - nvl(v_val_exo_impuesto,0);
                  ---
                  v_val_exo_cargo    := (v_val_exo_cargo + v_val_exo_impuesto) * nvl(v_can_operacion,0);
                  v_val_exo_impuesto := round(nvl(v_val_exo_cargo, 0) * nvl(v_val_tas_impuesto, 0) /
                                          (100 + v_val_tas_impuesto), v_redondeo);
                  v_val_exo_cargo    := round(nvl(v_val_exo_cargo, 0) - nvl(v_val_exo_impuesto, 0), v_redondeo);
                  ---
                  if pag_cta.fu_ver_tra_prohibida(reg.nro_cuenta,
                                                  140,
                                                  4,
                                                  41) = 'S' then
                     prg_ins_exoneracion(140,4,
                                         41, pag_cta.G_CTAS.cod_moneda,
                                         reg.nro_cuenta, null, v_cod_tas_cargo,
                                         nvl(v_val_exo_cargo, 0),
                                         nvl(v_val_exo_cargo, 0), null,
                                         nvl(v_val_exo_cargo, 0));
                  elsif
                     (nvl(v_val_cargo, 0) <> nvl(v_val_exo_cargo, 0)) or
                     (nvl(v_val_cargo, 0) = 0 and nvl(v_val_exo_cargo, 0) <> 0) then
                     prg_ins_exoneracion(140,4,
                                         41, pag_cta.G_CTAS.cod_moneda,
                                         reg.nro_cuenta, null, v_cod_tas_cargo,
                                         (nvl(v_val_exo_cargo, 0) - nvl(v_val_cargo, 0)),
                                          v_val_exo_cargo, null,
                                         (nvl(v_val_exo_cargo, 0) - nvl(v_val_cargo, 0)));
                  end if;
                  if pag_cta.fu_ver_tra_prohibida(reg.nro_cuenta,
                                                  v_cod_tra_impuesto,
                                                  4,
                                                  41) = 'S' then
                     prg_ins_exoneracion(v_cod_tra_impuesto, 4,
                                         41, pag_cta.G_CTAS.cod_moneda,
                                         reg.nro_cuenta, null, v_cod_tas_impuesto,
                                         nvl(v_val_impuesto, 0),
                                         nvl(v_val_impuesto, 0), null,
                                         nvl(v_val_impuesto, 0));
                  elsif nvl(v_val_cargo, 0) = 0 or
                        pag_cta.fu_ver_tra_prohibida(reg.nro_cuenta,
                                                     140,
                                                     4,
                                                     41) = 'S' then
                     null;
                  elsif (nvl(v_val_impuesto, 0) <> nvl(v_val_exo_impuesto, 0)) or
                        (nvl(v_val_impuesto, 0) = 0 and nvl(v_val_exo_impuesto, 0) <> 0) then
                     prg_ins_exoneracion(v_cod_tra_impuesto, 4,
                                         41, pag_cta.G_CTAS.cod_moneda,
                                         reg.nro_cuenta, null, v_cod_tas_impuesto,
                                         (nvl(v_val_impuesto, 0) - nvl(v_val_exo_impuesto, 0)),
                                          v_val_exo_impuesto, null,
                                         (nvl(v_val_impuesto, 0) - nvl(v_val_exo_impuesto, 0)));
                  end if;
               end if;
               ---
               IF v_can_operacion > 0 THEN 
                  IF v_val_cargo > 0 THEN
                                 
                     --Realizar el cobro
                     IF v_nro_secuencia > 990 THEN
                        --v_hor_actual    := pag_gen.fu_obt_sig_segundo(v_hor_actual);
                        --FQ Para evitar error de PK
                        v_hor_actual            := fug_obt_hor_disponible(v_fec_actual,v_hor_actual,user,'N');
                        v_nro_secuencia := 0;
                     END IF;
            
                     prc_cob_car_pagos(reg.nro_cuenta, v_cod_tas_cargo, v_val_tas_cargo, v_val_cargo,
                                       v_cod_tra_impuesto, v_cod_tas_impuesto, v_val_tas_impuesto,
                                       v_val_impuesto, v_cod_transaccion, v_fec_actual, v_hor_actual,
                                       v_nro_secuencia);
                  END IF;                                  
                                
               ELSE
                  --si el resultado es negativo significa que la cantidad exonerada
                  --es mayor al tope, guardamos el valor absoluto porque esa
                  --cantidad se debe exonerar en la 4111
                  v_can_exonerar := abs(v_can_operacion);
               END IF;
               --- Segun Tasa x Cantidad superior al maximo
               --- Limpio los parametros recibidos del anterior
               v_cod_tas_cargo    := NULL;
               v_val_tas_cargo    := NULL;
               v_val_cargo        := NULL;
               v_cod_tra_impuesto := NULL;
               v_cod_tas_impuesto := NULL;
               v_val_impuesto     := NULL;

               --Obtengo el cargo de la transaccion 4111
               prg_obt_cargos( pag_cta.g_ctas.cod_oficina, reg.nro_cuenta, pag_cta.g_ctas.cod_moneda, NULL, 4,
                               41, 4111,
                               --Transaccion para el cobro de cargos por pago de cheques a partir del maximo
                              v_cod_tas_cargo, v_val_tas_cargo, v_val_cargo, v_cod_tra_impuesto,
                              v_cod_tas_impuesto, v_val_tas_impuesto, v_val_impuesto);
               v_cod_transaccion := 4111;
               v_can_operacion   := nvl(v_can_oper, 0) - nvl(v_can_max_cheque, 0) -
                                    nvl(v_can_exonerar, 0);
               --IF v_can_operacion > 0 THEN
                  --IF v_val_cargo > 0 THEN
               -- RI : 30/01/10 : Volver a sumar el cargo y el iva para multiplicar por la cantidad y despues volver a calcular el iva
               v_val_cargo    := (nvl(v_val_cargo, 0) + nvl(v_val_impuesto, 0)) * nvl(v_can_operacion,0);
               v_val_impuesto := round(nvl(v_val_cargo, 0) * nvl(v_val_tas_impuesto, 0) /
                                       (100 + v_val_tas_impuesto), v_redondeo);
               v_val_cargo    := round(nvl(v_val_cargo, 0) - nvl(v_val_impuesto, 0), v_redondeo);
               /*
               || PCC-Exoneración y Extorno de Comisiones y Tasas
               || Se ejecuta si el proceso no es mensual
               || o la base de datos no es producción
               */
               IF v_fre_proceso <> 'M' OR v_db_prod = 'N' THEN
                  -- busco el valor de la tasa
                  v_cod_tas_exo := lf_obt_cod_tasa(4111,4,41);
                  begin
                     v_val_exo_cargo := fug_obt_val_tasa(4,
                                                         41,
                                                         pag_cta.G_CTAS.cod_oficina,
                                                         null,
                                                         pag_cta.G_CTAS.cod_moneda,
                                                         0, 'N', NULL,
                                                         4111,
                                                         v_fec_actual);
                  exception
                     when others then
                        raise_application_error(-20000,'Al Obt.Val.Tasa:'||sqlerrm);
                  end;
                  v_tip_valor := fug_obt_tip_val_tasa(v_cod_tas_exo);
                  IF v_tip_valor = 'V' THEN
                     -- si es un valor, se toma directamente
                     v_val_exo_cargo := nvl(v_val_exo_cargo, 0);
                  elsif v_tip_Valor = 'T' then  -- es un codigo de tasa
                     --si es un codigo de tasa hay que ir a buscar el valor con la tasa devuelta y
                     --con el el p_monto2
                     If nvl(v_val_exo_cargo,0) > 0 then
                        v_tip_valor := fug_obt_tip_val_tasa(v_val_exo_cargo);
                        -- busco el valor de la tasa
                        begin
                           v_val_exo_cargo := fug_obt_val_tasa(4,
                                                               41,
                                                               pag_cta.G_CTAS.cod_oficina,
                                                               null,
                                                               pag_cta.G_CTAS.cod_moneda,
                                                               nvl(v_can_max_cheque, 0), 'N',
                                                               v_val_exo_cargo,null,
                                                               v_fec_actual);
                        exception
                           when others then
                              raise_application_error(-20000,'Al Obt.Val.Tasa:'||sqlerrm);
                        end;
                        if v_tip_Valor = 'V' then
                           v_val_exo_cargo := nvl(v_val_exo_cargo, 0);
                        elsif v_tip_valor = 'C' then
                           v_val_exo_cargo := round(nvl(v_can_operacion, 0) *
                                                    nvl(v_val_exo_cargo, 0), v_redondeo);
                        else
                           -- es un porcentaje
                           v_val_exo_cargo := round(nvl(v_sal_promedio, 0) *
                                                    nvl(v_val_exo_cargo, 0) / 100, v_redondeo);
                           --verificar si el monto a cobrar est¿ limitado x el m¿nimo y m¿ximo de la tasa
                           v_val_exo_cargo := round(pag_gen.FU_OBT_VAL_FINAL(v_val_exo_cargo), v_redondeo);
                        end if;
                     else
                        v_val_exo_cargo := 0;
                     end if;
                  ELSE
                     -- es un porcentaje, se considera incluido en el cargo
                     v_val_exo_cargo := round(nvl(NULL, 0) * nvl(v_val_exo_cargo, 0) /
                                           (100 + v_val_exo_cargo), v_redondeo);
                     --verificar si el monto a cobrar está limitado x el mínimo y máximo de la tasa
                     v_val_exo_cargo := pag_gen.fu_obt_val_final(v_val_exo_cargo);
                  END IF;
                  if v_cod_tra_impuesto is null then
                     v_cod_tra_impuesto := lf_obt_tra_hijo(4111,4,41);
                  end if;
                  begin
                     v_val_exo_impuesto := fug_obt_val_tasa(4,
                                                            41,
                                                            pag_cta.G_CTAS.cod_oficina,
                                                            null,
                                                            pag_cta.G_CTAS.cod_moneda,
                                                            0, 'N', NULL,
                                                            v_cod_tra_impuesto,
                                                            v_fec_actual);
                  exception
                     when others then
                        raise_application_error(-20000,'Al Obt.Val.Tasa:'||sqlerrm);
                  end;
                  v_tip_valor := fug_obt_tip_val_tasa(v_cod_tas_impuesto);
                  IF v_tip_valor = 'V' THEN
                     -- si es un valor, se toma directamente
                     v_val_exo_impuesto := nvl(v_val_exo_impuesto, 0);
                  ELSE
                     -- es un porcentaje, se considera incluido en el cargo
                     v_val_exo_impuesto := round(nvl(v_val_exo_cargo, 0) * nvl(v_val_exo_impuesto, 0) /
                                           (100 + v_val_exo_impuesto), v_redondeo);
                     --verificar si el monto a cobrar está limitado x el mínimo y máximo de la tasa
                     v_val_exo_impuesto := pag_gen.fu_obt_val_final(v_val_exo_impuesto);
                  END IF;
                  -- resto el monto del impuesto al cargo, porque va incluido
                  v_val_exo_cargo := nvl(v_val_exo_cargo,0) - nvl(v_val_exo_impuesto,0);
                  ---
                  v_val_exo_cargo    := (v_val_exo_cargo + v_val_exo_impuesto) * nvl(v_can_operacion,0);
                  v_val_exo_impuesto := round(nvl(v_val_exo_cargo, 0) * nvl(v_val_tas_impuesto, 0) /
                                          (100 + v_val_tas_impuesto), v_redondeo);
                  v_val_exo_cargo    := round(nvl(v_val_exo_cargo, 0) - nvl(v_val_exo_impuesto, 0), v_redondeo);
                  ---
                  if pag_cta.fu_ver_tra_prohibida(reg.nro_cuenta,
                                                  4111,
                                                  4,
                                                  41) = 'S' then
                     prg_ins_exoneracion(4111,4,
                                         41, pag_cta.G_CTAS.cod_moneda,
                                         reg.nro_cuenta, null, v_cod_tas_cargo,
                                         nvl(v_val_exo_cargo, 0),
                                         nvl(v_val_exo_cargo, 0), null,
                                         nvl(v_val_exo_cargo, 0));
                  elsif (nvl(v_val_cargo, 0) <> nvl(v_val_exo_cargo, 0)) or
                        (nvl(v_val_cargo, 0) = 0 and nvl(v_val_exo_cargo, 0) <> 0) then
                     prg_ins_exoneracion(4111,4,
                                         41, pag_cta.G_CTAS.cod_moneda,
                                         reg.nro_cuenta, null, v_cod_tas_cargo,
                                         (nvl(v_val_exo_cargo, 0) - nvl(v_val_cargo, 0)),
                                          v_val_exo_cargo, null,
                                         (nvl(v_val_exo_cargo, 0) - nvl(v_val_cargo, 0)));
                  end if;
                  if pag_cta.fu_ver_tra_prohibida(reg.nro_cuenta,
                                                  v_cod_tra_impuesto,
                                                  4,
                                                  41) = 'S' then
                     prg_ins_exoneracion(v_cod_tra_impuesto, 4,
                                         41, pag_cta.G_CTAS.cod_moneda,
                                         reg.nro_cuenta, null, v_cod_tas_impuesto,
                                         nvl(v_val_exo_impuesto, 0),
                                         nvl(v_val_exo_impuesto, 0), null,
                                         nvl(v_val_exo_impuesto, 0));
                  elsif nvl(v_val_cargo, 0) = 0 or
                        pag_cta.fu_ver_tra_prohibida(reg.nro_cuenta,
                                                  4111,
                                                  4,
                                                  41) = 'S' then
                     null;
                  elsif (nvl(v_val_impuesto, 0) <> nvl(v_val_exo_impuesto, 0)) or
                        (nvl(v_val_impuesto, 0) = 0 and nvl(v_val_exo_impuesto, 0) <> 0) then
                     prg_ins_exoneracion(v_cod_tra_impuesto, 4,
                                         41, pag_cta.G_CTAS.cod_moneda,
                                         reg.nro_cuenta, null, v_cod_tas_impuesto,
                                         (nvl(v_val_exo_impuesto, 0) - nvl(v_val_impuesto, 0)),
                                          v_val_exo_impuesto, null,
                                         (nvl(v_val_exo_impuesto, 0) - nvl(v_val_impuesto, 0)));
                  end if;
               end if;
               ---
               IF v_can_operacion > 0 THEN
                  IF v_val_cargo > 0 THEN
                     --Realizar el cobro
                     IF v_nro_secuencia > 990 THEN
                        --v_hor_actual    := pag_gen.fu_obt_sig_segundo(v_hor_actual);
                        --FQ Para evitar error de PK
                        v_hor_actual            := fug_obt_hor_disponible(v_fec_actual,v_hor_actual,user,'N');
                        v_nro_secuencia := 0;
                     END IF;
                     prc_cob_car_pagos(reg.nro_cuenta, v_cod_tas_cargo, v_val_tas_cargo, v_val_cargo,
                                       v_cod_tra_impuesto, v_cod_tas_impuesto, v_val_tas_impuesto,
                                       v_val_impuesto, v_cod_transaccion, v_fec_actual, v_hor_actual,
                                       v_nro_secuencia);  
                  END IF;                                                  
               END IF;
            
            ELSE
               --segun tasa matricial 140
               v_cod_tas_cargo:=0;
               v_val_tas_cargo:=0;
               v_val_cargo:=0;
               v_cod_tra_impuesto:=0;
               v_cod_tas_impuesto:=0; 
               v_val_tas_impuesto:=0;
               v_val_impuesto:=0;
               v_can_pag_permitidos:=0;
               ---
               v_can_oper_exo := nvl(v_can_oper,0);
               ---
               prc_obt_cargos( pag_cta.g_ctas.cod_oficina,  reg.nro_cuenta,  pag_cta.g_ctas.cod_moneda, nvl(v_sal_promedio,0),
                              nvl(v_can_oper,0),  4,  41, 140,
                              --Transaccion para el cobro de cargos por pago de cheques
                              v_cod_tas_cargo, v_val_tas_cargo, v_val_cargo, v_cod_tra_impuesto,
                              v_cod_tas_impuesto, v_val_tas_impuesto, v_val_impuesto,
                              v_can_pag_permitidos);
               v_cod_transaccion := 140;
               v_can_oper        := nvl(v_can_oper, 0) - nvl(v_can_pag_permitidos, 0);
               --IF v_can_oper > 0 and v_val_cargo > 0 THEN
               -- RI : 30/01/10 : Volver a sumar el cargo y el iva para multiplicar por la cantidad y despues volver a calcular el iva
               v_val_cargo    := (v_val_cargo + v_val_impuesto) * nvl(v_can_oper,0);
               v_val_impuesto := round(nvl(v_val_cargo, 0) * nvl(v_val_tas_impuesto, 0) /
                                       (100 + v_val_tas_impuesto), v_redondeo);
               v_val_cargo    := round(nvl(v_val_cargo, 0) - nvl(v_val_impuesto, 0), v_redondeo);
               /*
               || PCC-Exoneración y Extorno de Comisiones y Tasas
               || Se ejecuta si el proceso no es mensual
               || o la base de datos no es producción
               */
               IF v_fre_proceso <> 'M' OR v_db_prod = 'N' THEN
                  v_cod_tas_exo := lf_obt_cod_tasa(140,4,41);
                  -- busco el valor de la tasa
                  begin
                     v_val_exo_cargo := fug_obt_val_tasa(4,
                                                         41,
                                                         pag_cta.G_CTAS.cod_oficina,
                                                         null,
                                                         pag_cta.G_CTAS.cod_moneda,
                                                         nvl(v_sal_promedio, 0),
                                                         'N', NULL, 140,
                                                         v_fec_actual);
                  exception
                     when others then
                        raise_application_error(-20000,'Al Obt.Val.Tasa:'||sqlerrm);
                  end;
                  v_tip_valor := fug_obt_tip_val_tasa(v_cod_tas_exo);
                  IF v_tip_valor = 'V' THEN
                     -- si es un valor, se toma directamente
                     v_val_exo_cargo := nvl(v_val_exo_cargo, 0);
                  elsif v_tip_Valor = 'T' then  -- es un codigo de tasa
                     --si es un codigo de tasa hay que ir a buscar el valor con la tasa devuelta y
                     --con el el p_monto2
                     If nvl(v_val_exo_cargo,0) > 0 then
                        v_tip_valor := fug_obt_tip_val_tasa(v_val_exo_cargo);
                        -- busco el valor de la tasa
                        begin
                           v_val_exo_cargo := fug_obt_val_tasa(4,
                                                               41,
                                                               pag_cta.G_CTAS.cod_oficina,
                                                               null,
                                                               pag_cta.G_CTAS.cod_moneda,
                                                               nvl(v_can_oper_exo, 0), 'N',
                                                               v_val_exo_cargo,null,
                                                               v_fec_actual);
                        exception
                           when others then
                              raise_application_error(-20000,'Al Obt.Val.Tasa:'||sqlerrm);
                        end;
                        if v_tip_Valor = 'V' then
                           v_val_exo_cargo := nvl(v_val_exo_cargo, 0);
                        elsif v_tip_valor = 'C' then
                           v_val_exo_cargo := round(nvl(v_can_operacion, 0) *
                                                    nvl(v_val_exo_cargo, 0), v_redondeo);
                        else
                           -- es un porcentaje
                           v_val_exo_cargo := round(nvl(v_sal_promedio, 0) *
                                                    nvl(v_val_exo_cargo, 0) / 100, v_redondeo);
                           --verificar si el monto a cobrar est¿ limitado x el m¿nimo y m¿ximo de la tasa
                           v_val_exo_cargo := round(pag_gen.FU_OBT_VAL_FINAL(v_val_exo_cargo), v_redondeo);
                        end if;
                     else
                        v_val_exo_cargo := 0;
                     end if;
                  ELSE
                     -- es un porcentaje, se considera incluido en el cargo
                     v_val_exo_cargo := round(nvl(v_sal_promedio, 0) * nvl(v_val_exo_cargo, 0) /
                                           (100 + v_val_exo_cargo), v_redondeo);
                     --verificar si el monto a cobrar está limitado x el mínimo y máximo de la tasa
                     v_val_exo_cargo := pag_gen.fu_obt_val_final(v_val_exo_cargo);
                  END IF;
                  ---
                  if v_cod_tra_impuesto is null then
                     v_cod_tra_impuesto := lf_obt_tra_hijo(140,4,41);
                  end if;
                  begin
                     v_val_exo_impuesto := fug_obt_val_tasa(4,
                                                            41,
                                                            pag_cta.G_CTAS.cod_oficina,
                                                            null,
                                                            pag_cta.G_CTAS.cod_moneda,
                                                            0, 'N', NULL,
                                                            v_cod_tra_impuesto,
                                                            v_fec_actual);
                  exception
                     when others then
                        raise_application_error(-20000,'Al Obt.Val.Tasa:'||sqlerrm);
                  end;
                  v_tip_valor := fug_obt_tip_val_tasa(v_cod_tas_impuesto);
                  IF v_tip_valor = 'V' THEN
                     -- si es un valor, se toma directamente
                     v_val_exo_impuesto := nvl(v_val_exo_impuesto, 0);
                  ELSE
                     -- es un porcentaje, se considera incluido en el cargo
                     v_val_exo_impuesto := round(nvl(v_val_exo_cargo, 0) * nvl(v_val_exo_impuesto, 0) /
                                           (100 + v_val_exo_impuesto), v_redondeo);
                     --verificar si el monto a cobrar está limitado x el mínimo y máximo de la tasa
                     v_val_exo_impuesto := pag_gen.fu_obt_val_final(v_val_exo_impuesto);
                  END IF;
                  -- resto el monto del impuesto al cargo, porque va incluido
                  v_val_exo_cargo := nvl(v_val_exo_cargo,0) - nvl(v_val_exo_impuesto,0);
                  ---
                  v_val_exo_cargo    := (v_val_exo_cargo + v_val_exo_impuesto) * nvl(v_can_oper_exo, 0);
                  v_val_exo_impuesto := round(nvl(v_val_exo_cargo, 0) * nvl(v_val_tas_impuesto, 0) /
                                          (100 + v_val_tas_impuesto), v_redondeo);
                  v_val_exo_cargo    := round(nvl(v_val_exo_cargo, 0) - nvl(v_val_exo_impuesto, 0), v_redondeo);
                  ---
                  if pag_cta.fu_ver_tra_prohibida(reg.nro_cuenta,
                                                  140,
                                                  4,
                                                  41) = 'S' then
                     prg_ins_exoneracion(140,4,
                                         41, pag_cta.G_CTAS.cod_moneda,
                                         reg.nro_cuenta, null, v_cod_tas_cargo,
                                         nvl(v_val_exo_cargo, 0),
                                         nvl(v_val_exo_cargo, 0), null,
                                         nvl(v_val_exo_cargo, 0));
                  elsif (nvl(v_val_cargo, 0) <> nvl(v_val_exo_cargo, 0)) or
                        (nvl(v_val_cargo, 0) = 0 and nvl(v_val_exo_cargo, 0) <> 0) then
                     prg_ins_exoneracion(140,4,
                                         41, pag_cta.G_CTAS.cod_moneda,
                                         reg.nro_cuenta, null, v_cod_tas_cargo,
                                         (nvl(v_val_exo_cargo, 0) - nvl(v_val_cargo, 0)),
                                          v_val_exo_cargo, null,
                                         (nvl(v_val_exo_cargo, 0) - nvl(v_val_cargo, 0)));
                  end if;
                  if pag_cta.fu_ver_tra_prohibida(reg.nro_cuenta,
                                                  v_cod_tra_impuesto,
                                                  4,
                                                  41) = 'S' then
                     prg_ins_exoneracion(v_cod_tra_impuesto, 4,
                                         41, pag_cta.G_CTAS.cod_moneda,
                                         reg.nro_cuenta, null, v_cod_tas_impuesto,
                                         nvl(v_val_exo_impuesto, 0),
                                         nvl(v_val_exo_impuesto, 0), null,
                                         nvl(v_val_exo_impuesto, 0));
                  elsif nvl(v_val_cargo, 0) = 0 or
                        pag_cta.fu_ver_tra_prohibida(reg.nro_cuenta,
                                                  140,
                                                  4,
                                                  41) = 'S' then
                     null;
                  elsif (nvl(v_val_impuesto, 0) <> nvl(v_val_exo_impuesto, 0)) or
                        (nvl(v_val_impuesto, 0) = 0 and nvl(v_val_exo_impuesto, 0) <> 0) then
                     prg_ins_exoneracion(v_cod_tra_impuesto, 4,
                                         41, pag_cta.G_CTAS.cod_moneda,
                                         reg.nro_cuenta, null, v_cod_tas_impuesto,
                                         (nvl(v_val_exo_impuesto, 0) - nvl(v_val_impuesto, 0)),
                                          v_val_exo_impuesto, null,
                                         (nvl(v_val_exo_impuesto, 0) - nvl(v_val_impuesto, 0)));
                  end if;
               end if;
               ---
               IF v_can_oper > 0 and v_val_cargo > 0 THEN
                  --Realizar el cobro
                  IF v_nro_secuencia > 990 THEN
                     --v_hor_actual    := pag_gen.fu_obt_sig_segundo(v_hor_actual);
                     --FQ Para evitar error de PK
                     v_hor_actual            := fug_obt_hor_disponible(v_fec_actual,v_hor_actual,user,'N');
                     v_nro_secuencia := 0;
                  END IF;
                  prc_cob_car_pagos(reg.nro_cuenta, v_cod_tas_cargo, v_val_tas_cargo, v_val_cargo,
                                    v_cod_tra_impuesto, v_cod_tas_impuesto, v_val_tas_impuesto,
                                    v_val_impuesto, v_cod_transaccion, v_fec_actual, v_hor_actual,
                                    v_nro_secuencia);
               END IF;
            END IF;
         END IF;
      END IF;
   END LOOP;
EXCEPTION
   WHEN OTHERS THEN
      raise_application_error(-20000,'Cta:'||v_nro_cuenta||'-'||sqlerrm);
END prc_pro_cob_car_pagos;
/

