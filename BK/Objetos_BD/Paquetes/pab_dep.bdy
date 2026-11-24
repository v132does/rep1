CREATE OR REPLACE PACKAGE BODY IT.PAB_DEP is

/* Realiza el calculo de los Depositos Internos.*/
PROCEDURE PR_GEN_DEP_INTERNOS IS
  --- Variables Generales..
  v_cod_oficina       ba_oficinas.cod_oficina%type;
  v_cod_moneda        ba_monedas.cod_moneda%type;
  v_fec_actual        ge_calendarios.fec_actual%type          := pag_cal.fu_obt_fec_actual(2);
  v_cod_transaccion   ge_transacciones.cod_transaccion%type;
  v_can_dia_acumulado cb_sal_promedios_tmp.can_dia_acumulado%type;
  v_importe           cb_sal_promedios.tot_acu_mon_local%type;
  v_sal_promedio      cb_sal_promedios_tmp.tot_acumulado%type := 0;
  v_sal_operativo     cb_sal_promedios_tmp.tot_acumulado%type := 0;
  v_cod_modulo        ge_modalidades.cod_modulo%type          := 2;
  v_cod_modalidad     ge_modalidades.cod_modalidad%type       :=21;
  v_cod_tasa          ge_tas_rangos.cod_tasa%type;
  v_val_tasa          ge_tas_rangos.val_tasa%type;
  v_fec_vigencia      ge_tas_rangos.fec_vigencia%type;
  v_tip_valor         ge_tasas.tip_valor%type;
  v_tipo              ge_tasas.tip_valor%type;
  v_cod_rubro         cb_sal_promedios_tmp.cod_rubro%type;  
  v_est_proceso       ba_modulos.estado%type;
  v_mto_dep_interno   number;
    
  -- Cursores.
  CURSOR c_sal_rubros IS
     SELECT substr(cb.cod_rubro,1,10)||ltrim(to_char(cb.cod_oficina,'000'))||substr(cb.cod_rubro,14,2) cod_rubro,
            cb.cod_oficina,
            cb.cod_moneda,
            cb.can_dia_acumulado,
            nvl(sum(cb.tot_acu_mon_local),0) monto           
       FROM cb_sal_promedios_tmp cb, cb_rubros cr
      WHERE substr(cb.cod_rubro,6,5) = '25704'
        AND cb.cod_rubro = cr.cod_rubro
        AND cr.imputable = 'S'
      GROUP BY substr(cb.cod_rubro,1,10)||ltrim(to_char(cb.cod_oficina,'000'))||substr(cb.cod_rubro,14,2), 
               cb.cod_oficina, cb.cod_moneda, cb.can_dia_acumulado;
  
BEGIN

   -- Valida que el modulo de contabilidad ese cerrado.
   v_est_proceso := pae_cnf.fu_obt_est_modulo(v_cod_modulo);
   IF nvl(v_est_proceso,2) <> 4 THEN
      raise_application_error(-20000,'El modulo '||to_char(v_cod_modulo)||' debe estar cerrado para ejercutar el proceso');
   END IF;
   
   -- Reapertura el modulo contable.
   prb_reapertura;
     
   -- Calcula los Depositos Internos. 
   IF c_sal_rubros%isopen THEN
      CLOSE c_sal_rubros;
   END IF;
   
   -- Elimino los calculos de la fecha.
   delete cb_sal_dep_internos cb where cb.fecha = v_fec_actual;
   
   -- Calculo el Deposito Interno.
   OPEN c_sal_rubros;
   LOOP
      FETCH c_sal_rubros INTO v_cod_rubro,v_cod_oficina,v_cod_moneda,v_can_dia_acumulado,v_importe;
         EXIT WHEN c_sal_rubros%notfound;
         -- Genero el Movimiento de Dep. Internos.
         v_sal_promedio  := round((nvl(v_importe,0) / v_can_dia_acumulado),0);
         -- Obtengo el importe del saldo promedio de la sucursal neteado.
         BEGIN
            v_sal_operativo := nvl(FU_OBT_MTO_DEP_INTERNOS(to_char(v_fec_actual,'yyyy'),to_char(v_fec_actual,'mm'),v_cod_oficina,v_cod_moneda),0);
            v_sal_operativo := round((nvl(v_sal_operativo,0) / v_can_dia_acumulado),0);
         EXCEPTION
            WHEN OTHERS THEN
               v_sal_operativo := 0;   
         END;
         v_sal_promedio  := v_sal_promedio - v_sal_operativo;
         -- Determino el Codigo de Transaccion.
         IF v_sal_promedio < 0 THEN
            v_cod_transaccion := 999;            
         ELSE
            v_cod_transaccion := 1999;
         END IF;
         v_sal_promedio := abs(v_sal_promedio);
                
         -- Calculo el valor del Dep. Interno.
         v_cod_tasa     := NULL;
         v_val_tasa     := NULL;
         v_fec_vigencia := NULL;
         v_tip_valor    := NULL;
         v_tipo         := NULL;
         BEGIN
            PAG_GEN.PR_OBT_VAL_TASA(P_COD_MODULO => v_cod_modulo,
                                    P_COD_MODALIDAD => v_cod_modalidad, 
                                    P_COD_OFICINA => v_cod_oficina,
                                    P_NRO_CUENTA => NULL,
                                    P_COD_MONEDA => v_cod_moneda,
                                    P_MTO_TRANSACCION => NULL,
                                    P_TAS_PERSONALIZADA => 'N',
                                    P_COD_TASA => v_cod_tasa, 
                                    P_COD_TRANSACCION => v_cod_transaccion,
                                    P_FEC_FINAL => v_fec_actual,
                                    P_VAL_TASA => v_val_tasa,
                                    P_FEC_VIGENCIA => v_fec_vigencia,
                                    P_TIP_VALOR => v_tip_valor,
                                    P_TIPO => v_tipo,
                                    P_COD_PERSONA => NULL,                                
                                    P_COD_SUB_MODALIDAD => NULL);
                                   
            -- Calculo el deposito interno.
            v_mto_dep_interno := ROUND(pag_gen.fu_cal_int_simple(v_sal_promedio,v_can_dia_acumulado,v_val_tasa),0);
           
            -- Registro en la tabla.
            INSERT INTO cb_sal_dep_internos(fecha,cod_rubro,cod_oficina,cod_moneda,sal_promedio,can_dia_acumulados,val_tasa,mto_dep_interno, cod_transaccion)
                 VALUES (v_fec_actual,v_cod_rubro,v_cod_oficina,v_cod_moneda, v_sal_promedio, v_can_dia_acumulado, v_val_tasa,v_mto_dep_interno, v_cod_transaccion);
            
         EXCEPTION
            WHEN OTHERS THEN
               raise_application_error(-20000,' ERROR. Tasa no definida para la moneda: '||v_cod_moneda||sqlerrm);
         END;         
   END LOOP;
   IF C_SAL_RUBROS%ROWCOUNT = 0 THEN
      CLOSE C_SAL_RUBROS;
         raise_application_error(-20000,' ERROR. No se encontraron registros.'||sqlerrm);
   END IF;
   IF C_SAL_RUBROS%ISOPEN THEN
      CLOSE C_SAL_RUBROS;
   END IF;
--     
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    CLOSE c_sal_rubros;
    raise_application_error(-20000,' ERROR. No se encontraron registros.');
  WHEN OTHERS THEN
    CLOSE c_sal_rubros;
    raise_application_error(-20000,'Error en PRB_GEN_DEP_INTERNOS '||sqlerrm);
END;

/* Procedimiento que inserta asientos manuales. */
PROCEDURE PR_INS_ASI_MANUALES(rp_bamde IN cb_asientos_det%ROWTYPE) 
IS
BEGIN
   -- Inserto en la cabecera.
   UPDATE cb_asientos cb
      SET cb.tot_control = cb.tot_control + rp_bamde.mto_mon_local
    WHERE cb.nro_asiento = rp_bamde.nro_asiento;
   
   IF SQL%NOTFOUND THEN
      
      INSERT INTO cb_asientos
         (cod_oficina, nro_asiento, cod_usuario, fecha, cod_modulo, cod_modalidad, tot_control,
          actualizado, reversado, cod_ofi_origen, ofi_integrada, confirmado, fec_valor)
      VALUES
         (rp_bamde.cod_oficina, rp_bamde.nro_asiento, substr(user,1,10) , rp_bamde.fecha,
          2, 21, rp_bamde.mto_mon_local, 'N','N',rp_bamde.cod_oficina, 'N', 'S', rp_bamde.fecha);
   END IF;
   -- Inserto el detalle.
   INSERT INTO cb_asientos_det
      (fecha, cod_oficina, nro_asiento, nro_linea, cod_rubro, tip_movimiento, mto_mon_rubro,
       mto_mon_local, descripcion, referencia, protegido, actualizado, val_cotizacion,
       distribuido, ref_movimiento, fec_valor)
   VALUES
      (rp_bamde.fecha, rp_bamde.cod_oficina, rp_bamde.nro_asiento, rp_bamde.nro_linea,
       rp_bamde.cod_rubro, rp_bamde.tip_movimiento, rp_bamde.mto_mon_rubro,
       rp_bamde.mto_mon_local, rp_bamde.descripcion, rp_bamde.referencia, rp_bamde.protegido,
       rp_bamde.actualizado, rp_bamde.val_cotizacion, rp_bamde.distribuido,
       rp_bamde.ref_movimiento, rp_bamde.fec_valor);
EXCEPTION
   WHEN OTHERS THEN
      raise_application_error(-20000,
                              'Ins.Cb_asientos_det ' || rp_bamde.nro_asiento || '-' ||
                               rp_bamde.referencia || '-' || SQLERRM);
END;

/* Reversa los asientos de Depositos Internos. */
PROCEDURE PR_REV_DEP_INTERNOS IS
   -- Variables.
   r_bamde            cb_asientos_det%ROWTYPE;
   v_fec_actual       ge_calendarios.fec_actual%type := pag_cal.fu_obt_fec_actual(2);
   v_nro_asiento      cb_asientos.nro_asiento%type   := 0;
   v_nro_asi_anterior cb_asientos.nro_asiento%type   := 0;
   v_fecha            cb_asientos.fecha%type;
   v_est_proceso      ba_modulos.estado%type;
   v_cod_modulo       ge_modalidades.cod_modulo%type := 2;
   v_existe           NUMBER(18) := 0;
   
   -- Cursores.
   CURSOR c_reverso(p_fecha cb_asientos.fecha%type) IS
      SELECT cb.*
        FROM cb_asientos_det_his cb 
       WHERE cb.fecha = p_fecha
         AND cb.referencia = 'DEP.INT'
       ORDER BY cb.nro_asiento;
   
BEGIN
   pag_cal.pr_obt_dat_calendar(v_cod_modulo);   
   -- Valida que el modulo de contabilidad ese cerrado.
   v_est_proceso := pae_cnf.fu_obt_est_modulo(v_cod_modulo);
   IF nvl(v_est_proceso,2) <> 2 THEN
      raise_application_error(-20000,'El modulo '||to_char(v_cod_modulo)||' debe estar abierto para ejercutar el proceso');
   END IF;
   
   -- Elimina asientos anteriores.
   DELETE cb_asientos_det cb WHERE cb.fecha = v_fec_actual AND cb.referencia = 'DEP.INT';
   DELETE cb_asientos ca WHERE NOT EXISTS (SELECT 1 FROM cb_asientos_det cb WHERE cb.nro_asiento = ca.nro_asiento);
   -- Obtener el ultimo numero de asiento y actualizar el parametro.
   SELECT MAX(nro_asiento)
     INTO v_nro_asiento
     FROM cb_asientos;
   IF v_nro_asiento IS NULL THEN
      SELECT MAX(nro_asiento)
        INTO v_nro_asiento
        FROM cb_asientos_his;
   END IF;
   prg_act_par_dinamico('SIG_NRO_ASIENTO',NULL,NULL,NULL,NULL,(v_nro_asiento + 1));
   
   ---- Reverso movimientos anteriores.
   -- Verifico si existe un reverso en la fecha actual.
   SELECT COUNT(1)
     INTO v_existe
     FROM cb_asientos_det cb 
    WHERE cb.fecha = v_fec_actual 
      AND cb.referencia = 'REV.DEP.INT';
   
   IF v_existe = 0 THEN
      -- Reverso los movimientos generados en el mes.
      SELECT NVL(MAX(FECHA),v_fec_actual)
        INTO v_fecha
        FROM cb_asientos_det_his cb 
       WHERE cb.fecha <  v_fec_actual 
         AND cb.fecha >= pag_cal.G_PRI_DIA_MES
         AND cb.referencia = 'DEP.INT';
         
      IF v_fecha != v_fec_actual THEN
         
         FOR reg IN c_reverso(v_fecha) LOOP                       
            -- Obtengo el numero de asiento.
            IF reg.nro_asiento <> v_nro_asi_anterior THEN
               v_nro_asiento := fug_obt_pardinamico('SIG_NRO_ASIENTO');
               prg_act_par_dinamico('SIG_NRO_ASIENTO',null, null, null, null, (v_nro_asiento + 1));
            END IF;
            --
            v_nro_asi_anterior := reg.nro_asiento;
            
            -- Cargar registro de asientos detalles
            r_bamde.fecha          := v_fec_actual;
            r_bamde.cod_oficina    := reg.cod_oficina;
            r_bamde.nro_asiento    := v_nro_asiento;
            r_bamde.nro_linea      := reg.nro_linea;
            r_bamde.cod_rubro      := reg.cod_rubro;
            r_bamde.tip_movimiento := (case when reg.tip_movimiento = 'D' then 'C' else 'D' end);
            r_bamde.mto_mon_rubro  := reg.mto_mon_rubro;
            r_bamde.mto_mon_local  := reg.mto_mon_local;
            r_bamde.descripcion    := substr('REV. '||reg.descripcion,1,60);
            r_bamde.referencia     := 'REV.DEP.INT';
            r_bamde.protegido      := 'N';
            r_bamde.actualizado    := 'N';
            r_bamde.val_cotizacion := reg.val_cotizacion;
            r_bamde.distribuido    := 'N';
            r_bamde.ref_movimiento := NULL;
            pr_ins_asi_manuales(r_bamde);
            
         END LOOP;
      END IF;
   END IF;
   
END;

/* Genera los Asientos Manuales de Deposito Interno. */
PROCEDURE PR_GEN_MOV_CONTABLES IS
      
      -- Variables.
      r_bamde               cb_asientos_det%ROWTYPE;
      v_cod_modulo          ge_modalidades.cod_modulo%type          := 2;
      v_cod_modalidad       ge_modalidades.cod_modalidad%type       := 21;
      v_cod_ofi_dep_interno ba_oficinas.cod_oficina%type            := fug_obt_pardinamico('COD_OFI_DEP_INTERNOS');
      v_mto_mon_local       cb_asientos_det.mto_mon_local%type;
      v_mto_mon_extranjera  cb_asientos_det.mto_mon_rubro%type;
      v_mto_cotizacion      cb_asientos_det.val_cotizacion%type;
      v_sal_mon_extranjera  cb_asientos_det.mto_mon_rubro%type;
      v_sal_mon_local       cb_asientos_det.mto_mon_local%type;
      v_val_cotizacion      cb_asientos_det.val_cotizacion%type;
      v_referencia          cb_asientos_det.referencia%type;
      v_descripcion         cb_asientos_det.descripcion%type;
      v_cod_mon_local       ba_monedas.cod_moneda%type := pag_gen.FU_OBT_MON_LOCAL;      
      v_cod_mad_padre       ge_modalidades.cod_modalidad%TYPE;
      v_cod_mod_padre       ba_modulos.cod_modulo%TYPE;
      v_fec_actual          cb_asientos_det.fecha%type := pag_cal.FU_OBT_FEC_ACTUAL(2);      
      v_tip_movimiento      ge_tip_asientos.tip_movimiento%TYPE;
      v_mon_rubro           cb_rubros.cod_moneda%TYPE;
      v_des_transaccion     ge_transacciones.descripcion%TYPE;
      v_mto_dep_interno     cb_asientos_det.mto_mon_local%TYPE;
      v_cod_moneda          ba_monedas.cod_moneda%TYPE;
      v_cod_oficina         cb_asientos_det.cod_oficina%TYPE;
      v_cod_ofi_movimiento  cb_asientos_det.cod_oficina%TYPE;
      v_nro_linea           ge_tip_asientos.nro_linea%TYPE;
      v_cod_rubro           cb_rubros.cod_rubro%TYPE; 
      v_cod_tip_asiento     ge_tip_asientos.cod_tip_asiento%TYPE;
      v_cod_tip_asiento2    ge_tip_asientos.cod_tip_asiento%TYPE;
      r_gtasi               ge_tip_asientos%ROWTYPE;
      v_nro_asiento         cb_asientos.nro_asiento%type;
      v_existe              NUMBER;
      v_encontro            VARCHAR2(1);
      v_msj                 VARCHAR2(250);      
      
      -- Cursores.
      CURSOR c_tip_asientos IS
         SELECT *
           FROM ge_tip_asientos
          WHERE cod_tip_asiento IN (v_cod_tip_asiento, v_cod_tip_asiento2)
            AND cod_moneda = v_cod_moneda;
            
      CURSOR c_dep_internos IS
         SELECT cb.*
           FROM cb_sal_dep_internos cb
          WHERE cb.fecha = v_fec_actual
            AND cb.mto_dep_interno <> 0;
      
      -- Procedimiento que obtiene la moneda del rubro.
      PROCEDURE lp_obt_mon_rubro(p_cod_rubro  IN cb_rubros.cod_moneda%TYPE,
                                 p_cod_moneda IN OUT cb_rubros.cod_moneda%TYPE,
                                 p_encontro   IN OUT VARCHAR2) IS
      BEGIN
         SELECT cod_moneda 
           INTO p_cod_moneda 
           FROM cb_rubros 
          WHERE cod_rubro = p_cod_rubro;
      EXCEPTION
         WHEN no_data_found THEN
            IF substr(p_cod_rubro, 14, 2) IN ('99', '00') THEN
               p_cod_moneda := pag_gen.fu_obt_mon_local;
               p_encontro   := 'S';
            ELSIF substr(p_cod_rubro, 14, 2) IN ('01', '98') THEN
               p_cod_moneda := pag_gen.fu_obt_mon_fuerte;
               p_encontro   := 'S';
            ELSE
               p_encontro := 'N';
            END IF;
         WHEN OTHERS THEN
            raise_application_error(-20000, 'Rec. Rubro ' || p_cod_rubro || '-' || SQLERRM);
      END;         
   --
   BEGIN
      
      v_msj := ' Depositos Internos. ';
      -- Verifica que exista movimientos de Dep. Intenos.
      SELECT COUNT(1)
        INTO v_existe
        FROM cb_sal_dep_internos cb
       WHERE cb.fecha = v_fec_actual;
   
      IF v_existe = 0 THEN
         raise_application_error(-20000,' ERROR. NO existen movimientos generados de Dep. Internos en fecha: '||v_fec_actual);
      END IF;
      
      -- Elimino los asientos existentes.
      pr_rev_dep_internos;
      
      -- Genero los movimientos contables.
      FOR reg IN c_dep_internos LOOP
         -- Ve el tipo de asiento.
         BEGIN
            SELECT cod_tip_asiento, descripcion, cod_tip_asiento2
              INTO v_cod_tip_asiento, v_des_transaccion, v_cod_tip_asiento2
              FROM ge_transacciones
             WHERE cod_modulo = v_cod_modulo
               AND cod_modalidad = v_cod_modalidad
               AND cod_transaccion = reg.cod_transaccion
               AND cod_tip_asiento IS NOT NULL;
         EXCEPTION
            WHEN no_data_found THEN
               raise_application_error(-20000,
                                       'Transaccion ' || to_char(v_cod_modulo) || '-' ||
                                        to_char(v_cod_modalidad) || '-' || reg.cod_transaccion || '-' ||' no tiene asiento definido.');
            WHEN OTHERS THEN
               IF SQLCODE <= -20000 THEN
                  RAISE;
               ELSE
                  raise_application_error(-20001, 'Error PR_GEN_MOV_CONTABLES ' || SQLERRM);
               END IF;
         END;
         -- Asignacion de Valores.
         v_cod_moneda         := reg.cod_moneda;         
         v_mto_dep_interno    := ROUND(reg.mto_dep_interno,0);
         v_cod_oficina        := reg.cod_oficina;
         v_cod_ofi_movimiento := reg.cod_oficina;
         -- Verifica la Moneda.
         IF v_cod_moneda = v_cod_mon_local THEN
            v_mto_mon_local      := v_mto_dep_interno;
            v_mto_mon_extranjera := 0;
            v_mto_cotizacion     := 1;        
         ELSE            
            -- se obtiene la cotizacion de cierre
            v_mto_cotizacion := pag_gen.fu_obt_cotizacion(v_cod_moneda, v_fec_actual);
            --
            v_mto_mon_local      := v_mto_dep_interno;
            v_mto_mon_extranjera := round(v_mto_dep_interno/v_mto_cotizacion, 2);
         END IF;
         --         
         IF c_tip_asientos%ISOPEN THEN
            CLOSE c_tip_asientos;
         END IF;
         OPEN c_tip_asientos;
         v_nro_linea := 0;
         LOOP
            FETCH c_tip_asientos
               INTO r_gtasi;
            EXIT WHEN c_tip_asientos%NOTFOUND;
            --
            v_encontro := 'S';
            v_cod_rubro:= r_gtasi.cod_rubro;
            lp_obt_mon_rubro(v_cod_rubro, v_mon_rubro, v_encontro);
            IF v_encontro = 'N' THEN
               v_msj := 'Cuenta inexistente en Plan de Cuentas ' || v_cod_rubro;
               v_mon_rubro := v_cod_mon_local;
            END IF;
            --
            v_nro_asiento := fug_obt_pardinamico('SIG_NRO_ASIENTO');
            prg_act_par_dinamico('SIG_NRO_ASIENTO',null, null, null, null, (v_nro_asiento + 1));
            --
            IF v_mon_rubro = v_cod_mon_local THEN
               v_sal_mon_extranjera := 0;
               v_val_cotizacion     := 1;
            ELSE
               v_sal_mon_extranjera := v_mto_mon_extranjera;
               v_val_cotizacion     := v_mto_cotizacion;
            END IF;
            -- Ve el tipo de movimiento.
            v_tip_movimiento := r_gtasi.tip_movimiento;
            IF v_mto_mon_local > 0 THEN
               v_tip_movimiento := r_gtasi.tip_movimiento;
               v_sal_mon_local  := v_mto_mon_local;
            ELSE
               v_sal_mon_local      := v_mto_mon_local * -1;
               v_sal_mon_extranjera := v_sal_mon_extranjera * -1;
               IF r_gtasi.tip_movimiento = 'C' THEN
                  v_tip_movimiento := 'D';
               ELSE
                  v_tip_movimiento := 'C';
               END IF;
            END IF;
            --
            IF reg.cod_transaccion = 999 THEN
               IF v_tip_movimiento = 'C' THEN
                  v_cod_ofi_movimiento := v_cod_ofi_dep_interno;
               ELSE
                  v_cod_ofi_movimiento := v_cod_oficina;
               END IF;
            ELSIF reg.cod_transaccion = 1999 THEN
               IF v_tip_movimiento = 'D' THEN
                  v_cod_ofi_movimiento := v_cod_ofi_dep_interno;
               ELSE
                  v_cod_ofi_movimiento := v_cod_oficina;
               END IF;
            END IF;
            --
            v_referencia      := 'DEP.INT';
            v_descripcion     := substr(v_des_transaccion, 1, 60);
            v_cod_mod_padre   := v_cod_modulo;
            v_cod_mad_padre   := v_cod_modalidad;
            -----
            IF v_sal_mon_local <> 0 THEN
               v_nro_linea := v_nro_linea + 1;               
               --- Cargar registro de asientos detalles
               r_bamde.fecha          := v_fec_actual;
               r_bamde.cod_oficina    := v_cod_ofi_movimiento;
               r_bamde.nro_asiento    := v_nro_asiento;
               r_bamde.nro_linea      := v_nro_linea;
               r_bamde.cod_rubro      := v_cod_rubro;
               r_bamde.tip_movimiento := v_tip_movimiento;
               r_bamde.mto_mon_rubro  := v_sal_mon_extranjera;
               r_bamde.mto_mon_local  := v_sal_mon_local;
               r_bamde.descripcion    := v_descripcion;
               r_bamde.referencia     := v_referencia;
               r_bamde.protegido      := 'N';
               r_bamde.actualizado    := 'N';
               r_bamde.val_cotizacion := v_val_cotizacion;
               r_bamde.distribuido    := 'N';
               r_bamde.ref_movimiento := NULL;
               pr_ins_asi_manuales(r_bamde);
            END IF;
            -- Genero los movimientos de interoficinas.
            -- Recuperar cuenta contable interoficina
            v_cod_rubro    := fug_obt_pardinamico('COD_RUB_INTEROFICINA', NULL, NULL, v_cod_moneda,v_cod_oficina);
            IF v_cod_ofi_movimiento != v_cod_ofi_dep_interno THEN
               v_cod_rubro := substr(v_cod_rubro, 1, 10) || ltrim(to_char(v_cod_ofi_dep_interno,'000')) || substr(v_cod_rubro, 14, 2);
            ELSE
               v_cod_rubro := substr(v_cod_rubro, 1, 10) || ltrim(to_char(v_cod_oficina,'000')) || substr(v_cod_rubro, 14, 2);
            END IF;
            --- ve moneda de la cuenta --
            v_encontro := 'S';
            lp_obt_mon_rubro(v_cod_rubro, v_cod_moneda, v_encontro);
            IF v_encontro = 'N' THEN
               v_msj := 'Rubro Inexistente-Plan de Ctas.Consol' || v_cod_rubro;
               IF substr(v_cod_rubro, 14, 2) IN ('99', '98') THEN
                  v_cod_moneda := v_cod_mon_local;
               END IF;
            END IF;            
            v_descripcion := substr(TRIM(v_des_transaccion) || '(Inter of)', 1, 60);
            IF v_tip_movimiento = 'C' THEN
               v_tip_movimiento := 'D';
            ELSE
               v_tip_movimiento := 'C';
            END IF;
            IF v_sal_mon_local <> 0 THEN
               v_nro_linea := v_nro_linea + 1;
               --- Cargar registro de asientos detalles
               r_bamde.fecha          := v_fec_actual;
               r_bamde.cod_oficina    := v_cod_ofi_movimiento;
               r_bamde.nro_asiento    := v_nro_asiento;
               r_bamde.nro_linea      := v_nro_linea;
               r_bamde.cod_rubro      := v_cod_rubro;
               r_bamde.tip_movimiento := v_tip_movimiento;
               r_bamde.mto_mon_rubro  := v_sal_mon_extranjera;
               r_bamde.mto_mon_local  := v_sal_mon_local;
               r_bamde.descripcion    := v_descripcion;
               r_bamde.referencia     := v_referencia;
               r_bamde.protegido      := 'N';
               r_bamde.actualizado    := 'N';
               r_bamde.val_cotizacion := v_val_cotizacion;
               r_bamde.distribuido    := 'N';
               r_bamde.ref_movimiento := NULL;
               pr_ins_asi_manuales(r_bamde);
            END IF;
         END LOOP;                  
       END LOOP;
   END;

/* Verifica que exista movimientos ya generados de Dep. Internos para realizar el Inicio de Día. */
PROCEDURE PR_VAL_DEP_INTERNOS IS
-- Variables.
v_fec_actual  cb_asientos_det.fecha%TYPE := pag_cal.fu_obt_fec_actual(2);
v_cod_modulo  ge_modalidades.cod_modulo%type := 2;
v_est_proceso ba_modulos.estado%type;
v_existe      NUMBER(18) := 0;
BEGIN
   
   -- Valida que el modulo de contabilidad ese cerrado.
   v_est_proceso := pae_cnf.fu_obt_est_modulo(v_cod_modulo);
   IF nvl(v_est_proceso,2) <> 4 THEN
      raise_application_error(-20000,'El modulo '||to_char(v_cod_modulo)||' debe estar cerrado para ejercutar el proceso');
   END IF;
   
   -- Obtiene el calendario contable.
   pag_cal.pr_obt_dat_calendar(v_cod_modulo);  
      
   -- Verifico que exista movimientos ya generados de Dep. Internos para realizar el último día del mes.
   IF v_fec_actual = pag_cal.g_ult_dia_mes_habil THEN
   
      SELECT COUNT(1)
        INTO v_existe
        FROM cb_asientos_det cb
       WHERE cb.fecha = v_fec_actual
         AND cb.referencia = 'DEP.INT';
      
      IF v_existe = 0 THEN
         raise_application_error(-20000,' ERROR. NO existen movimientos generados de Dep. Internos. ');
      END IF;
   END IF;
END;

/* Obtiene el saldo promedio de las cuentas operativas por oficina.*/
FUNCTION FU_OBT_MTO_DEP_INTERNOS(P_ANHO        IN GE_CTA_DEP_INTERNOS_DET.ANO%TYPE,
                                 P_MES         IN GE_CTA_DEP_INTERNOS_DET.MES%TYPE,
                                 P_COD_OFICINA IN GE_CUENTAS.COD_OFICINA%TYPE,
                                 P_COD_MONEDA  IN GE_CUENTAS.COD_MONEDA%TYPE)
RETURN NUMBER
AS
v_monto          ge_cta_dep_internos_det.mto_dep_interno%type := 0;
v_fec_actual     cb_asientos_det.fecha%TYPE := pag_cal.FU_OBT_FEC_ACTUAL(2);
v_cod_mon_local  ba_monedas.cod_moneda%TYPE := pag_gen.FU_OBT_MON_LOCAL;  
BEGIN
   
   SELECT NVL(SUM((CASE WHEN cb.tip_saldo = 'P' THEN 
                      (CASE WHEN cb.cod_moneda = v_cod_mon_local THEN
                          cb.sal_acumulado 
                       ELSE
                          NVL(cb.sal_acumulado,0) * pag_gen.fu_obt_cotizacion(cb.cod_moneda, v_fec_actual)
                       END)
                   ELSE 
                      (CASE WHEN cb.cod_moneda = v_cod_mon_local THEN
                          cb.sal_acumulado * (-1) 
                       ELSE
                          (NVL(cb.sal_acumulado,0) * pag_gen.fu_obt_cotizacion(cb.cod_moneda, v_fec_actual)) * (-1)
                       END)
                       
                   END)),0)
     INTO v_monto
     FROM ge_cta_dep_internos_det cb
    WHERE cb.ano = p_anho
      AND cb.mes = p_mes
      AND cb.cod_oficina = p_cod_oficina
      AND cb.cod_moneda = p_cod_moneda;
    
    RETURN v_monto;
    
EXCEPTION
   WHEN OTHERS THEN
      v_monto := 0;
      RETURN v_monto;   
END;

/* Realiza el calculo de los Depositos Internos por Cuenta de Clientes.*/
PROCEDURE PR_GEN_CTA_DEP_INTERNO IS
  -- Variables Generales.
  v_cod_oficina       ba_oficinas.cod_oficina%type;
  v_cod_moneda        ba_monedas.cod_moneda%type;
  v_fec_actual        ge_calendarios.fec_actual%type   := pag_cal.fu_obt_fec_actual(1);
  v_anho              ge_cta_dep_internos_det.ano%type := to_char(v_fec_actual,'yyyy');
  v_mes               ge_cta_dep_internos_det.mes%type := to_char(v_fec_actual,'mm');
  v_cod_transaccion   ge_transacciones.cod_transaccion%type;
  v_can_dia_acumulado cb_sal_promedios_tmp.can_dia_acumulado%type;
  v_can_dia_ini_mes   cb_sal_promedios_tmp.can_dia_acumulado%type;
  v_can_dia_mes       cb_sal_promedios_tmp.can_dia_acumulado%type;
  v_importe           cb_sal_promedios.tot_acu_mon_local%type;
  v_sal_total         cb_sal_promedios_tmp.tot_acumulado%type := 0;
  v_cod_modulo        ge_modalidades.cod_modulo%type          := 2;
  v_cod_modalidad     ge_modalidades.cod_modalidad%type       :=21;
  v_cod_tasa          ge_tas_rangos.cod_tasa%type;
  v_val_tasa          ge_tas_rangos.val_tasa%type;
  v_fec_vigencia      ge_tas_rangos.fec_vigencia%type;
  v_tip_valor         ge_tasas.tip_valor%type;
  v_tipo              ge_tasas.tip_valor%type;
  v_nro_cuenta        ge_movimientos.nro_cuenta%type;
  v_mto_dep_interno   ge_cta_dep_internos_det.mto_dep_interno%type := 0;  
  v_estado            ge_cta_dep_internos_det.estado%type;
  v_cod_ori_fondo     pr_fondos.cod_ori_fondo%type;
  -- Requerimiento: CNFCMFDI-3.
  -- Fecha: 08/09/2015.
  v_mto_dep_mon_local ge_cta_dep_internos_det.mto_dep_mon_local%type := 0;
  v_cod_mon_local     ge_cta_dep_internos_det.cod_moneda%type := pag_gen.fu_obt_mon_local;
  -- Requerimiento: CNFDEEVO-45.
  -- Fecha: 23/06/2016.
  v_cod_sub_modalidad ge_cuentas.cod_sub_modalidad%type;
  v_pla_original     number(18) := 0;
  v_pla_transcurrido      number(18) := 0;
  v_tip_saldo         varchar2(1);
  v_existe            varchar2(1) := 'N';
  rg_datos            ge_cal_tas_pro_ponderada_tmp%rowtype;
  v_val_tas_personalizada ge_tas_rangos.val_tasa%type;

  -- Cursores.
  -- Requerimiento: CNFDEEVO-45.
  -- Fecha: 23/06/2016.
  CURSOR c_cta_activas IS
     SELECT bv.tipo,
            bv.cod_modulo,
            bv.cod_modalidad,
            bv.nro_cuenta,
            bv.cod_oficina,
            bv.cod_moneda,
            bv.pla_original,
            bv.pla_transcurrido,
            bv.estado,
            nvl(bv.monto,0) monto,
            bv.cod_ori_fondo,
            bv.cod_sub_modalidad,
            bv.val_tasa
       FROM ge_cta_dep_internos_tmp bv;


  -- Funciones.
  PROCEDURE LP_INS_GE_DEP_INTERNOS_TMP IS

  v_fec_actual    ge_calendarios.fec_actual%type   := pag_cal.fu_obt_fec_actual(1);
  v_fec_hab_ant   ge_calendarios.fec_anterior%type := pag_cal.fu_obt_fec_ant_hab(v_fec_actual, 1, 1);


  pragma autonomous_transaction;

  BEGIN
     insert into ge_cta_dep_internos_tmp
     (
     SELECT 'A' tipo,
          pr.cod_modulo,
          pr.cod_modalidad,
          pr.nro_cuenta,
          pr.cod_oficina,
          pr.cod_moneda,
          pr.estado,
          nvl((pr.fec_vencimiento - pr.fec_inicio),0) pla_original,
          nvl(( v_fec_actual - pr.fec_inicio),0) pla_transcurrido,
          decode(pr.estado,'C',nvl(pr.sal_capital,0),(nvl(pr.sal_capital,0) + nvl(pr.sal_interes,0) + nvl(pr.sal_int_adelantado,0) - nvl(pr.val_int_devengar,0) - nvl(pr.dev_suspenso,0))) monto,
          pr.cod_ori_fondo cod_ori_fondo,
          pr.cod_sub_modalidad,
          g.cod_tasa,
          g.val_tasa,
          pr.fec_inicio,
          pr.fec_vencimiento,
          pr.mto_capital
     FROM pr_cta_prestamos pr, ge_cta_dep_internos_det g
    WHERE pr.estado NOT IN ('N','I')
      and pr.nro_cuenta = g.nro_cuenta (+)
      and g.fec_ult_proceso(+) = v_fec_hab_ant  
   UNION ALL
   SELECT 'A' tipo,
          ta.cod_modulo,
          ta.cod_modalidad,
          ta.nro_cuenta,
          ta.cod_oficina,
          ta.cod_moneda,
          (CASE WHEN ta.estado = 'B' THEN
              (CASE WHEN ta.dia_mora <= 60 THEN 'N'
                    WHEN ta.dia_mora > 60 AND ta.dia_mora < 91 THEN 'V'
                    WHEN ta.dia_mora > 90 AND ta.dia_mora < 151 THEN 'G'
                    WHEN ta.dia_mora > 150 THEN 'M'
               ELSE
                  'N'
               END)
             WHEN ta.estado = 'P' THEN 'N'
           ELSE
              ta.estado
           END) estado,
          0 pla_original,
          0 pla_transcurrido,
          nvl(ta.sal_procesadora,0) monto,
          null,
          null,
          null,
          null,
          null,
          null,
          null
     FROM ta_cta_tarjetas ta
    WHERE ta.estado <> 'C'
      AND nvl(ta.sal_procesadora,0) >= 0
   UNION ALL
   SELECT 'P' tipo,
          ta.cod_modulo,
          ta.cod_modalidad,
          ta.nro_cuenta,
          ta.cod_oficina,
          ta.cod_moneda,
          (CASE WHEN ta.estado = 'B' THEN
              (CASE WHEN ta.dia_mora <= 60 THEN 'N'
                    WHEN ta.dia_mora > 60 AND ta.dia_mora < 91 THEN 'V'
                    WHEN ta.dia_mora > 90 AND ta.dia_mora < 151 THEN 'G'
                    WHEN ta.dia_mora > 150 THEN 'M'
               ELSE
                  'N'
               END)
             WHEN ta.estado = 'P' THEN 'N'
           ELSE
              ta.estado
           END) estado,
          0 pla_original,
          0 pla_transcurrido,
          nvl(ta.sal_procesadora,0) monto,
          null,
          null,
          null,
          null,
          null,
          null,
          null
     FROM ta_cta_tarjetas ta
    WHERE ta.estado <> 'C'
      AND nvl(ta.sal_procesadora,0) < 0
   UNION ALL
   SELECT 'A' tipo,
          ov.cod_modulo,
          ov.cod_modalidad,
          ov.nro_cuenta,
          ov.cod_oficina,
          ov.cod_moneda,
          ov.estado,
          (CASE WHEN m.cod_modulo = 6 THEN
             (SELECT nvl(MIN(pr.fec_vencimiento - pr.fec_inicio),0)
                FROM pr_cta_prestamos pr
               WHERE pr.nro_cuenta = ov.nro_cta_origen)
           ELSE
              0
           END) pla_original,
          (CASE WHEN m.cod_modulo = 6 THEN
             (SELECT nvl(MIN(pr.fec_vencimiento - pr.fec_inicio),0)
                FROM pr_cta_prestamos pr
               WHERE pr.nro_cuenta = ov.nro_cta_origen)
           ELSE
              0
           END) pla_transcurrido,
          nvl(ov.sal_total,0) monto,
          null,
          null,
          null,
          null,
          null,
          null,
          null
     FROM ov_cta_vencidas ov, ge_cuentas m
    WHERE NVL(ov.sal_total,0) > 0
      AND ov.estado NOT IN ('C','I')
      AND OV.NRO_CTA_ORIGEN = M.NRO_CUENTA
   UNION ALL
   SELECT (CASE WHEN (NVL(cc.sal_total,0) - NVL(cc.sal_bloqueado,0) - NVL(cc.sal_retenido,0)) < 0 THEN 'A' ELSE 'P' END) tipo,
          cc.cod_modulo,
          cc.cod_modalidad,
          cc.nro_cuenta,
          cc.cod_oficina,
          cc.cod_moneda,
          (CASE WHEN cc.estado IN ('I','S') THEN 'N' ELSE cc.estado END) estado,
          0 pla_original,
          0 pla_transcurrido,
          (CASE WHEN (NVL(cc.sal_total,0) - NVL(cc.sal_bloqueado,0) - NVL(cc.sal_retenido,0)) < 0 THEN
             NVL(cc.sal_total,0) - NVL(cc.sal_bloqueado,0) - NVL(cc.sal_retenido,0)
           ELSE
             NVL(cc.sal_total,0) - NVL(cc.sal_retenido,0)
           END) monto,
           null,
           cc.cod_sub_modalidad,
           null,
           null,
           null,
           null,
           null
     FROM cc_cta_corrientes cc
    WHERE cc.estado NOT IN ('A','C','X','P')
   UNION ALL
   SELECT 'P' tipo,
          ah.cod_modulo,
          ah.cod_modalidad,
          ah.nro_cuenta,
          ah.cod_oficina,
          ah.cod_moneda,
          (CASE WHEN ah.estado IN ('I','S') THEN 'N' ELSE ah.estado END) estado,
          0 pla_original,
          0 pla_transcurrido,
          NVL(ah.sal_total,0) - NVL(ah.sal_retenido,0) monto,
          null,
          ah.cod_sub_modalidad,
          null,
          null,
          null,
          null,
          null
     FROM ah_cta_vistas ah
    WHERE ah.estado NOT IN ('A','C','X')
   UNION ALL
   SELECT 'P' tipo,
          ac.cod_modulo,
          ac.cod_modalidad,
          ac.nro_cuenta,
          ac.cod_oficina,
          ac.cod_moneda,
          ac.estado,
          nvl((ac.fec_vencimiento - ac.fec_apertura),0) pla_original,
          nvl((ac.fec_vencimiento - ac.fec_apertura),0) pla_transcurrido,
          (nvl(ac.sal_total,0) - nvl(ac.sal_retenido,0)) monto,
          null,
          null,
          g.cod_tasa,
          g.val_tasa,
          ac.fec_apertura,
          ac.fec_vencimiento,
          null
     FROM Ah_Cta_Certificados ac, ge_cta_dep_internos_det g
    WHERE ac.cod_modalidad = 33
      AND ac.estado NOT IN ('A','C','X','T')
      and ac.nro_cuenta = g.nro_cuenta (+)
      and g.fec_ult_proceso(+) = v_fec_hab_ant
   -- Requerimiento: CNFDICC-3.
   -- Fecha:29/01/2014.
   UNION ALL
   SELECT 'A' tipo,
          ac.cod_modulo,
          ac.cod_modalidad,
          ac.nro_cuenta,
          ac.cod_oficina,
          ac.cod_moneda,
          ac.estado,
          nvl((ac.fec_vencimiento - ac.fec_inicio),0) pla_original,
          nvl((v_fec_actual - ac.fec_inicio),0) pla_transcurrido,
          (nvl(ac.sal_capital,0)) monto,
          null,
          null,
          g.cod_tasa,
          g.val_tasa,
          ac.fec_inicio,
          ac.fec_vencimiento,
          null
     FROM md_cta_documentos ac, ge_cta_dep_internos_det g
    WHERE ac.cod_modalidad in (100,101,102,103,104,105,106,110,114,116,120,122,123,124,125,129,130,132,134,142,144,146)
      AND ac.estado = 'C'
      and ac.nro_cuenta = g.nro_cuenta (+)
      and g.fec_ult_proceso(+) = v_fec_hab_ant  
   UNION ALL
   SELECT 'P' tipo,
          ac.cod_modulo,
          ac.cod_modalidad,
          ac.nro_cuenta,
          ac.cod_oficina,
          ac.cod_moneda,
          ac.estado,
          nvl((ac.fec_vencimiento - ac.fec_inicio),0) pla_original,
          nvl((v_fec_actual - ac.fec_inicio),0) pla_transcurrido,
          (nvl(ac.sal_capital,0)) monto,
          null,
          null,
          null,
          null,
          ac.fec_inicio,
          ac.fec_vencimiento,
          null
     FROM md_cta_documentos ac
    WHERE ac.cod_modalidad in (109,115)
      AND ac.estado = 'C'
    UNION ALL
    --Ahorro Programado--
   SELECT 'P' tipo,
          cm.cod_modulo,
          cm.cod_modalidad,
          cm.nro_cuenta,
          cm.cod_oficina,
          cm.cod_moneda,
          cm.estado,
          nvl(cm.fec_vencimiento-cm.fec_apertura,0) pla_original,
          nvl(cm.fec_vencimiento-cm.fec_apertura,0) pla_transcurrido,
          cm.capital monto,
          null,
          null,
          g.cod_tasa,
          g.val_tasa,
          cm.fec_apertura,
          cm.fec_vencimiento,
          0 capital
     FROM AH_CTA_PLAZOS cm, ge_cta_dep_internos_det g
    WHERE cm.estado  not in ('C','T')
      and cm.nro_cuenta = g.nro_cuenta (+)
      and g.fec_ult_proceso(+) = v_fec_hab_ant);
    commit;

  END;


  FUNCTION FU_OBT_TAS_TIP_FONDOS (P_DOMINIO IN VARCHAR2,P_VALOR IN VARCHAR2)
  RETURN VARCHAR2
  IS
     v_val_maximo ba_cod_referencias.val_maximo%type;
  BEGIN
     SELECT val_maximo
       INTO v_val_maximo
       FROM ba_cod_referencias
      WHERE dominio    = p_dominio
        AND val_minimo = p_valor;

     RETURN v_val_maximo;
  EXCEPTION
     WHEN OTHERS THEN
        v_val_maximo := NULL;
        RETURN v_val_maximo;
  END;
  FUNCTION lf_OBT_COD_TASA (p_cod_transaccion ge_transacciones.cod_transaccion%type,
                            p_cod_modulo      ge_transacciones.cod_modulo%type,
                            p_cod_modalidad   ge_transacciones.cod_modalidad%type)
                            return number is

  v_cod_tasa    ge_tas_rangos.cod_tasa%type;
  BEGIN
    BEGIN
       SELECT cod_tasa
         INTO v_cod_tasa
         FROM ge_transacciones
        WHERE cod_modulo      = p_cod_modulo
          AND cod_modalidad   = p_cod_modalidad
          AND cod_transaccion = p_cod_transaccion;
    EXCEPTION
          WHEN OTHERS THEN
           RAISE_APPLICATION_ERROR(-20001,'Error al Obtener Cod. Tasa '||SQLERRM);
    END;

    return nvl(v_cod_tasa, 777);

   EXCEPTION
     WHEN OTHERS THEN
         return nvl(v_cod_tasa, 777);
   END;

BEGIN
   --SDMODFTP-1 - Modelo FTP (Funds Transfer Princing) - Depósitos Internos
   --Reestructuracion de proceso Depositos Internos
   /*-- Refresh de la vista materializada.
   DBMS_MVIEW.REFRESH ('GV_CTA_DEP_INTERNOS');*/

   -- Elimina registros de la tabla temporal.
   EXECUTE IMMEDIATE ('truncate table ge_tas_rangos_tmp');
   EXECUTE IMMEDIATE ('truncate table ge_cta_dep_internos_tmp');
   EXECUTE IMMEDIATE ('truncate table ge_tas_dep_internos_tmp');
   EXECUTE IMMEDIATE ('truncate table ge_cal_tas_pro_ponderada_tmp');

   --Obtener tasas en tmp para procesamiento
   pag_tdi.pr_ins_ge_tas_rangos_tmp;
   --Obtener Valores para interpolacion
   pag_tdi.pr_act_tas_interpolada;
   --Insertar universo de cuentas para calculo Depositos Internos
   LP_INS_GE_DEP_INTERNOS_TMP;
   --Insertar universo de Cuotas para calculo de TPP (Tasa Promedio Ponderado)
   pag_tdi.pr_ins_tas_pro_ponderada;

   --Obtengo fechas del sistema
   pag_cal.pr_obt_dat_calendar(1);

   -- Calcula los Depositos Internos.
   IF c_cta_activas%isopen THEN
      CLOSE c_cta_activas;
   END IF;

   -- Obtengo los dias acumulados del mes.
   BEGIN
      -- Verifico el primer dia habil del mes.
      IF pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1) = v_fec_actual THEN

         v_can_dia_ini_mes := 0;

         SELECT v_fec_actual - trunc(v_fec_actual,'mm')
           INTO v_can_dia_ini_mes
           FROM dual;

         SELECT pag_cal.g_fec_proxima - v_fec_actual
           INTO v_can_dia_acumulado
           FROM dual;

         v_can_dia_acumulado := nvl(v_can_dia_acumulado,0) + nvl(v_can_dia_ini_mes,0);

      ELSE

         -- Fecha: 20/02/2014.
         -- Desarrollo contingente 3275.
         IF v_fec_actual = pag_cal.G_ULT_DIA_MES_HABIL THEN
            SELECT (last_day(v_fec_actual) - v_fec_actual) + 1
              INTO v_can_dia_acumulado
              FROM dual;
         ELSE
            SELECT pag_cal.g_fec_proxima - v_fec_actual
              INTO v_can_dia_acumulado
              FROM dual;
         END IF;
      END IF;

      SELECT to_char(last_day(v_fec_actual),'dd')
        INTO v_can_dia_mes
        FROM dual;

   EXCEPTION
      WHEN OTHERS THEN
         v_can_dia_acumulado := 1;
         v_can_dia_mes       := 1;
   END;

   -- Calculo el Deposito Interno.
   OPEN c_cta_activas;
   LOOP
      -- Requerimiento: CNFDEEVO-45.
      -- Fecha: 23/06/2016.
      FETCH c_cta_activas INTO v_tip_saldo,v_cod_modulo,v_cod_modalidad,v_nro_cuenta,v_cod_oficina,v_cod_moneda,v_pla_original,v_pla_transcurrido, v_estado,v_importe,v_cod_ori_fondo,v_cod_sub_modalidad, v_val_tasa;
         EXIT WHEN c_cta_activas%notfound;
         -- Genero el Movimiento de Dep. Internos.
         v_sal_total := round((abs(v_importe) * v_can_dia_acumulado),0);
         -- Determino el Codigo de Transaccion.
         IF v_tip_saldo = 'A' THEN
            v_cod_transaccion := 888;
            v_tipo            := v_tip_saldo;
            v_cod_tasa        := lf_obt_cod_tasa(v_cod_transaccion, v_cod_modulo, v_cod_modalidad);
         ELSE
            v_cod_transaccion := 1888;
            v_tipo            := v_tip_saldo;
            v_cod_tasa        := lf_obt_cod_tasa(v_cod_transaccion, v_cod_modulo, v_cod_modalidad);
         END IF;
         -- Si es CDA Vencido se trata como a la Vista.
         IF v_cod_modalidad = 33 and v_estado = 'V' THEN
            v_pla_transcurrido := 0;
         END IF;

         -- Calculo el valor del Dep. Interno.
         ---v_cod_tasa     := NULL;
         ---v_val_tasa     := NULL;
         v_fec_vigencia := NULL;
         v_tip_valor    := NULL;
         --v_tipo         := NULL;
         v_existe       := 'N';

         BEGIN
			---SDMODFTP-1 : Noviembre/2019 - se comenta por que en el cursor ya se recupera el valor de tasa si ya fue creada la cuenta Dep. Internos
            /*-- Requerimiento: CNFDICC-3.
            -- Fecha:29/01/2014.
            IF (v_cod_modulo = 6 OR (v_cod_modalidad = 33 AND v_estado <> 'V') OR (v_cod_modulo = 10 AND v_cod_modalidad not in (109,110))) AND v_val_tasa IS NULL THEN
               BEGIN
                  SELECT v.val_tasa
                    INTO v_val_tasa
                    FROM (
                     SELECT ge.val_tasa
                       FROM ge_cta_dep_internos_det ge
                      WHERE ge.ano = v_anho
                        AND ge.mes = v_mes
                        AND ge.tip_saldo = v_tip_saldo
                        AND ge.nro_cuenta = v_nro_cuenta) v
                   WHERE ROWNUM = 1;
               EXCEPTION
                  WHEN OTHERS THEN
                     BEGIN
                        SELECT v.val_tasa
                          INTO v_val_tasa
                          FROM (
                             SELECT ge.val_tasa
                               FROM ge_cta_dep_internos_det ge
                              WHERE ge.tip_saldo = v_tip_saldo
                                AND ge.nro_cuenta = v_nro_cuenta
                              ORDER BY ge.ano DESC, ge.mes DESC) v
                         WHERE ROWNUM = 1;
                     EXCEPTION
                        WHEN OTHERS THEN
                           v_val_tasa := NULL;
                     END;
               END;
            END IF;*/
            
                 ----buscar si tiene parametrizacion personalizada
                -- obtengo la tasa de calculo del cliente si ya fue calculado.
                BEGIN
                      SELECT fug_con_numero(gc.val_parametro) --DYDMR-9752
                        INTO v_val_tas_personalizada
                        FROM ge_cta_dat_adicionales gc
                       WHERE gc.parametro = 'POR_TAS_DEP_INTERNO'
                         AND gc.nro_cuenta = v_nro_cuenta
                         AND gc.val_parametro IS NOT NULL;

                EXCEPTION
                   WHEN OTHERS THEN
                      v_val_tas_personalizada := NULL;
                END;
            
            if v_val_tas_personalizada is not null then
               v_val_tasa := v_val_tas_personalizada;
            end if;


            -- Obtengo la tasa de la tabla temporal, optimizacion del proceso.
            -- Requerimiento: CNFDICC-3.
            -- Fecha:29/01/2014.
            IF v_val_tasa IS NULL AND v_cod_modulo NOT IN (6,10,15) AND v_cod_modalidad not in (33, 37, 38) THEN
               -- Requerimiento: CNFDEEVO-45.
               -- Fecha: 23/06/2016.
               IF v_cod_sub_modalidad IS NULL THEN
                  BEGIN
                     -- Requerimiento: CNFDEEVO-45.
                     -- Fecha: 23/06/2016.
                     SELECT v.val_tasa
                       INTO v_val_tasa
                       FROM(
                            SELECT gt.plazo,gt.val_tasa
                              FROM ge_tas_dep_internos_tmp gt
                             WHERE gt.cod_modulo = v_cod_modulo
                               AND gt.cod_modalidad = v_cod_modalidad
                               AND gt.cod_oficina = v_cod_oficina
                               AND gt.cod_moneda = v_cod_moneda
                               AND gt.plazo >= v_pla_transcurrido
                               AND gt.tipo = v_tipo
                             ORDER BY gt.plazo) v
                      WHERE ROWNUM = 1;

                      v_existe := 'S';
                    EXCEPTION
                       WHEN OTHERS THEN
                          v_val_tasa := NULL;
                          v_existe := 'N';
                    END;
               ELSE

                   BEGIN
                      -- Requerimiento: CNFDEEVO-45.
                      -- Fecha: 23/06/2016.
                      SELECT v.val_tasa
                        INTO v_val_tasa
                        FROM(
                             SELECT gt.plazo,gt.val_tasa
                               FROM ge_tas_dep_internos_tmp gt
                              WHERE gt.cod_modulo = v_cod_modulo
                                AND gt.cod_modalidad = v_cod_modalidad
                                AND gt.cod_oficina = v_cod_oficina
                                AND gt.cod_moneda = v_cod_moneda
                                AND gt.cod_sub_modalidad = v_cod_sub_modalidad
                                AND gt.plazo >= v_pla_transcurrido
                                AND gt.tipo = v_tipo
                              ORDER BY gt.plazo) v
                       WHERE ROWNUM = 1;

                       v_existe := 'S';
                   EXCEPTION
                      WHEN OTHERS THEN
                         v_val_tasa := NULL;
                         v_existe := 'N';
                   END;
               END IF;
            -- Requerimiento: CNFDICC-3.
            -- Fecha:29/01/2014.
            ELSIF v_val_tasa IS NULL AND v_cod_modulo = 10 AND v_cod_modalidad IN (109,115) THEN
               -- Requerimiento: CNFDEEVO-45.
               -- Fecha: 23/06/2016.
               IF v_cod_sub_modalidad IS NULL THEN

                  BEGIN
                     -- Requerimiento: CNFDEEVO-45.
                     -- Fecha: 23/06/2016.
                     SELECT v.val_tasa
                       INTO v_val_tasa
                       FROM(
                     SELECT gt.plazo,gt.val_tasa
                       FROM ge_tas_dep_internos_tmp gt
                      WHERE gt.cod_modulo = v_cod_modulo
                        AND gt.cod_modalidad = v_cod_modalidad
                        AND gt.cod_oficina = v_cod_oficina
                        AND gt.cod_moneda = v_cod_moneda
                        AND gt.plazo >= v_pla_transcurrido
                        AND gt.tipo = v_tipo
                      ORDER BY gt.plazo) v
                      WHERE ROWNUM = 1;

                      v_existe := 'S';
                  EXCEPTION
                     WHEN OTHERS THEN
                        v_val_tasa := NULL;
                        v_existe := 'N';
                  END;
               ELSE
                  BEGIN
                     -- Requerimiento: CNFDEEVO-45.
                     -- Fecha: 23/06/2016.
                     SELECT v.val_tasa
                       INTO v_val_tasa
                       FROM(
                     SELECT gt.plazo,gt.val_tasa
                       FROM ge_tas_dep_internos_tmp gt
                      WHERE gt.cod_modulo = v_cod_modulo
                        AND gt.cod_modalidad = v_cod_modalidad
                        AND gt.cod_oficina = v_cod_oficina
                        AND gt.cod_moneda = v_cod_moneda
                        AND gt.cod_sub_modalidad = v_cod_sub_modalidad
                        AND gt.plazo >= v_pla_transcurrido
                        AND gt.tipo = v_tipo
                      ORDER BY gt.plazo) v
                      WHERE ROWNUM = 1;

                      v_existe := 'S';
                  EXCEPTION
                     WHEN OTHERS THEN
                        v_val_tasa := NULL;
                        v_existe := 'N';
                  END;
               END IF;
            END IF;

            -- Obtengo la tasa personalizada para la operacion.
            IF v_val_tasa IS NULL THEN

               -- REG-BBVA-CNF_2359_FAFU.01-AJU_PRO_DEP_INTERNOS.docx
               -- 09/01/2014 JF
               -- Determina el Origen de Fondos de los Prestamos otrogados.
               IF v_cod_modulo = 6 THEN
                  IF v_cod_ori_fondo <> fug_obt_pardinamico('COD_ORI_FON_DESEMB', NULL, NULL, v_cod_moneda, NULL, NULL) THEN
                     --Prestamos con Fondos AFD/OTROS.
                     v_cod_tasa := fu_obt_tas_tip_fondos('COD_TAS_DEP_INT_TIP_FONDOS',v_cod_ori_fondo);
                  END IF;
               END IF;


               ---Obtener TPP para operaciones que no tienen tasas asignadas
               IF (v_cod_modulo = 6) or
                  (v_cod_modulo = 3 and v_cod_modalidad = 38) then

                   pag_tdi.pr_cal_tas_pro_ponderada(v_nro_cuenta,
                                                    v_cod_tasa,
                                                    v_val_tasa);

               Else
                   --Obtener Tasa Interpolada - Operaciones no amortizables que aun no tienen tasas asignadas
                   v_val_tasa := pag_tdi.fu_obt_val_tas_interpolada
                                         (v_cod_modulo,
                                          v_cod_modalidad,
                                          v_cod_sub_modalidad,
                                          v_cod_oficina,
                                          v_nro_cuenta,
                                          v_cod_moneda,
                                          v_pla_transcurrido, --p_dia_interpolar
                                          v_cod_tasa,
                                          v_fec_actual,       --p_fec_fin
                                          v_fec_vigencia,     --p_fec_vigencia
                                          null);              --p_cod_persona


               End if;

			   --SDMODFTP-1 : Noviembre/2019 - se comenta por cambios en la obtencion del valor de la tasa
               -- Obtengo la tasa definida para la modalidad.
   /*            BEGIN
                  -- Requerimiento: CNFDEEVO-45.
                  -- Fecha: 23/06/2016.
                  PAG_GEN.PR_OBT_VAL_TASA(P_COD_MODULO => v_cod_modulo,
                                          P_COD_MODALIDAD => v_cod_modalidad,
                                          P_COD_OFICINA => v_cod_oficina,
                                          P_NRO_CUENTA => v_nro_cuenta,
                                          P_COD_MONEDA => v_cod_moneda,
                                          P_MTO_TRANSACCION => v_plazo, --Se indica el plazo de la operación.
                                          P_TAS_PERSONALIZADA => 'N',
                                          P_COD_TASA => v_cod_tasa,
                                          P_COD_TRANSACCION => v_cod_transaccion,
                                          P_FEC_FINAL => v_fec_actual,
                                          P_VAL_TASA => v_val_tasa,
                                          P_FEC_VIGENCIA => v_fec_vigencia,
                                          P_TIP_VALOR => v_tip_valor,
                                          P_TIPO => v_tipo,
                                          P_COD_PERSONA => NULL,
                                          P_COD_SUB_MODALIDAD => v_cod_sub_modalidad);
               EXCEPTION
                  WHEN OTHERS THEN
                     v_cod_tasa := NULL;
                     -- Obtengo la tasa de pizzar definida para fondos propios.
                     -- Requerimiento: CNFDEEVO-45.
                     -- Fecha: 23/06/2016.
                     PAG_GEN.PR_OBT_VAL_TASA(P_COD_MODULO => v_cod_modulo,
                                          P_COD_MODALIDAD => v_cod_modalidad,
                                          P_COD_OFICINA => v_cod_oficina,
                                          P_NRO_CUENTA => v_nro_cuenta,
                                          P_COD_MONEDA => v_cod_moneda,
                                          P_MTO_TRANSACCION => v_plazo, --Se indica el plazo de la operación.
                                          P_TAS_PERSONALIZADA => 'N',
                                          P_COD_TASA => v_cod_tasa,
                                          P_COD_TRANSACCION => v_cod_transaccion,
                                          P_FEC_FINAL => v_fec_actual,
                                          P_VAL_TASA => v_val_tasa,
                                          P_FEC_VIGENCIA => v_fec_vigencia,
                                          P_TIP_VALOR => v_tip_valor,
                                          P_TIPO => v_tipo,
                                          P_COD_PERSONA => NULL,
                                          P_COD_SUB_MODALIDAD => v_cod_sub_modalidad);
               END; */
            END IF;

            -- Inserto en una tabla temporal los datos de las tasas por modulo y modalidad.
            -- Requerimiento: CNFDICC-3.
            -- Fecha:29/01/2014.
            -- Requerimiento: CNFDEEVO-45.
            -- Fecha: 23/06/2016.
            IF v_existe = 'N' AND v_cod_modulo NOT IN (6,10,15) AND v_cod_modalidad not in (33, 37, 38) THEN

               INSERT INTO ge_tas_dep_internos_tmp(cod_modulo, cod_modalidad, cod_oficina, cod_moneda, plazo,
                                                   cod_tasa, cod_transaccion, val_tasa, fec_vigencia, tip_valor,
                                                   tipo, cod_sub_modalidad, pla_transcurrido)
                                           VALUES (v_cod_modulo,v_cod_modalidad,v_cod_oficina,v_cod_moneda,v_pla_original,
                                                   v_cod_tasa,v_cod_transaccion,v_val_tasa,v_fec_vigencia,v_tip_valor,
                                                   v_tipo,v_cod_sub_modalidad, v_pla_transcurrido);
            ELSIF v_existe = 'N' AND v_cod_modulo = 10 AND v_cod_modalidad IN (109,115) THEN

               INSERT INTO ge_tas_dep_internos_tmp(cod_modulo, cod_modalidad, cod_oficina, cod_moneda, plazo,
                                                   cod_tasa, cod_transaccion, val_tasa, fec_vigencia, tip_valor,
                                                   tipo,cod_sub_modalidad, pla_transcurrido)
                                           VALUES (v_cod_modulo,v_cod_modalidad,v_cod_oficina,v_cod_moneda,v_pla_original,
                                                   v_cod_tasa,v_cod_transaccion, v_val_tasa,v_fec_vigencia,v_tip_valor,
                                                   v_tipo,v_cod_sub_modalidad, v_pla_transcurrido);
            END IF;

            -- Calculo el deposito interno.
            v_mto_dep_interno := ROUND(pag_gen.fu_cal_int_simple(abs(v_importe),v_can_dia_acumulado,v_val_tasa),0);
            -- Calculo el valor en Moneda Local.
            -- Requerimiento: CNFCMFDI-3.
            -- Fecha: 08/09/2015.
            IF v_cod_moneda = v_cod_mon_local THEN
               v_mto_dep_mon_local:= ROUND(v_mto_dep_interno,0);
            ELSE
               v_mto_dep_mon_local:= ROUND((v_mto_dep_interno * pag_gen.fu_obt_cotizacion(v_cod_moneda)),0);
            END IF;

            -- Registro en la tabla.
            BEGIN
               UPDATE ge_cta_dep_internos_det
                  SET fec_ult_proceso = v_fec_actual,
                      sal_acumulado = NVL(sal_acumulado,0) + NVL(v_sal_total,0),
                      sal_promedio = NVL(sal_acumulado,0) / NVL(v_can_dia_mes,1),
                      can_dia_acumulados = NVL(can_dia_acumulados,0) + v_can_dia_acumulado,
                      mto_dep_interno = NVL(mto_dep_interno,0) + NVL(v_mto_dep_interno,0),
                      val_tasa = NVL(v_val_tasa,1),
                      cod_oficina = v_cod_oficina,
                      estado = v_estado,
                      cod_tasa = v_cod_tasa,
                      -- Requerimiento: CNFCMFDI-3.
                      -- Fecha: 08/09/2015.
                      mto_dep_mon_local = NVL(mto_dep_mon_local,0) + NVL(v_mto_dep_mon_local,0)
                WHERE ano = v_anho
                  AND mes = v_mes
                  AND tip_saldo = v_tip_saldo
                  AND nro_cuenta = v_nro_cuenta
                  AND val_tasa = v_val_tasa
                  -- Requerimiento: CNFDEEVO-29.
                  -- Fecha: 03/03/2016.
                  AND cod_oficina = v_cod_oficina;

               IF SQL%NOTFOUND THEN
                  -- Requerimiento: CNFCMFDI-3.
                  -- Fecha: 08/09/2015.
                  INSERT INTO ge_cta_dep_internos_det(ano, mes, fec_ult_proceso, tip_saldo, nro_cuenta, estado, cod_oficina, cod_moneda, cod_transaccion,
                                                      sal_acumulado, can_dia_acumulados, val_tasa, mto_dep_interno, sal_promedio, mto_dep_mon_local, cod_tasa)
                       VALUES (v_anho, v_mes, v_fec_actual, v_tip_saldo, v_nro_cuenta, v_estado, v_cod_oficina, v_cod_moneda, v_cod_transaccion, v_sal_total,
                               v_can_dia_acumulado, v_val_tasa, v_mto_dep_interno, 0, v_mto_dep_mon_local, v_cod_tasa);
               END IF;

            EXCEPTION
               WHEN OTHERS THEN
                  raise_application_error(-20000,' ERROR. Tabla cb_sal_cta_dep_internos, nro_cuenta: '||v_nro_cuenta||sqlerrm);
            END;
         EXCEPTION
            WHEN OTHERS THEN
               raise_application_error(-20000,' ERROR. Tasa no definida para la moneda: '||v_cod_moneda||sqlerrm);
         END;
   END LOOP;
   IF c_cta_activas%ROWCOUNT = 0 THEN
      CLOSE c_cta_activas;
         raise_application_error(-20000,' ERROR. No se encontraron registros.'||sqlerrm);
   END IF;
   IF c_cta_activas%ISOPEN THEN
      CLOSE c_cta_activas;
   END IF;
   -- Actualizo el campo saldo acumulado.
   BEGIN
	    UPDATE ge_cta_dep_internos_det cb
			   SET cb.sal_promedio = round((nvl(cb.sal_acumulado,0) / nvl(cb.can_dia_acumulados,1)),0)
		   WHERE cb.ano = v_anho
			   AND cb.mes = v_mes;
   EXCEPTION
      WHEN OTHERS THEN
		     raise_application_error(-20000,' ERROR al actualizar el saldo promedio.');
   END;
--
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    CLOSE c_cta_activas;
    raise_application_error(-20000,' ERROR. No se encontraron registros.');
  WHEN OTHERS THEN
    CLOSE c_cta_activas;
    raise_application_error(-20000,'Error en PRB_GEN_DEP_INTERNOS, Modalidad: '||v_cod_modalidad||', Nro_cuenta: '||v_nro_cuenta||','||sqlerrm);
END;

/* Genera los Asientos Manuales de Deposito Interno por Cuenta de Clientes. */
PROCEDURE PR_GEN_MOV_CTA_CLIENTE IS
      
      -- Variables.
      r_bamde               cb_asientos_det%ROWTYPE;
      v_cod_ofi_dep_interno ba_oficinas.cod_oficina%TYPE := fug_obt_pardinamico('COD_OFI_DEP_INTERNOS');
      v_mto_mon_local       cb_asientos_det.mto_mon_local%TYPE;
      v_mto_mon_extranjera  cb_asientos_det.mto_mon_rubro%TYPE;
      v_mto_cotizacion      cb_asientos_det.val_cotizacion%TYPE;
      v_sal_mon_extranjera  cb_asientos_det.mto_mon_rubro%TYPE;
      v_sal_mon_local       cb_asientos_det.mto_mon_local%TYPE;
      v_val_cotizacion      cb_asientos_det.val_cotizacion%TYPE;
      v_referencia          cb_asientos_det.referencia%TYPE;
      v_descripcion         cb_asientos_det.descripcion%TYPE;
      v_cod_mon_local       ba_monedas.cod_moneda%TYPE := pag_gen.FU_OBT_MON_LOCAL;      
      v_cod_mad_padre       ge_modalidades.cod_modalidad%TYPE;
      v_cod_mod_padre       ba_modulos.cod_modulo%TYPE;
      v_fec_actual          cb_asientos_det.fecha%TYPE := pag_cal.FU_OBT_FEC_ACTUAL(2);      
      v_anho                ge_cta_dep_internos_det.ano%TYPE := to_char(v_fec_actual,'yyyy');
      v_mes                 ge_cta_dep_internos_det.ano%TYPE := to_char(v_fec_actual,'mm');
      v_tip_movimiento      ge_tip_asientos.tip_movimiento%TYPE;
      v_mon_rubro           cb_rubros.cod_moneda%TYPE;
      v_des_transaccion     ge_transacciones.descripcion%TYPE;
      v_mto_dep_interno     cb_asientos_det.mto_mon_local%TYPE := 0;
      v_cod_moneda          ba_monedas.cod_moneda%TYPE;
      v_cod_oficina         cb_asientos_det.cod_oficina%TYPE;
      v_cod_ofi_movimiento  cb_asientos_det.cod_oficina%TYPE;
      v_nro_linea           ge_tip_asientos.nro_linea%TYPE;
      v_cod_rubro           cb_rubros.cod_rubro%TYPE; 
      v_cod_tip_asiento     ge_tip_asientos.cod_tip_asiento%TYPE;
      v_cod_tip_asiento2    ge_tip_asientos.cod_tip_asiento%TYPE;
      v_nro_asiento         cb_asientos.nro_asiento%type;
      -- Requerimiento: CNFCMFDI-3.
      -- Fecha: 08/09/2015.
      v_mto_dep_mon_local   cb_asientos_det.mto_mon_local%TYPE := 0;
      v_existe              NUMBER(18);
      v_encontro            VARCHAR2(1);
      v_msj                 VARCHAR2(250);      
      
      -- Cursores.
      -- Requerimiento: CNFCMFDI-3.
      -- Fecha: 08/09/2015.
      -- Requerimiento: CNFDEEVO-29.
      -- Fecha: 03/03/2016.
      CURSOR c_dep_internos IS
         SELECT gc.cod_modulo, gc.cod_modalidad, cb.tip_saldo, cb.cod_oficina, cb.cod_moneda, 
                NVL(ge.residente,'S') residente, NVL(ge.cod_sec_contable,'N') cod_sec_contable,
                pr.cod_sec_credito, cb.cod_transaccion, cb.estado, sum(cb.mto_dep_interno) mto_dep_interno, sum(cb.mto_dep_mon_local) mto_dep_mon_local
           FROM ge_cta_dep_internos_det cb, ge_clientes ge, ge_cta_clientes gc, pr_cta_prestamos pr
          WHERE cb.ano = v_anho
            AND cb.mes = v_mes
            AND cb.nro_cuenta = gc.nro_cuenta
            AND gc.relacion = 'P'
            AND gc.cod_persona = ge.cod_persona
            AND gc.nro_cuenta = pr.nro_cuenta
            AND cb.mto_dep_interno <> 0
          GROUP BY gc.cod_modulo, gc.cod_modalidad, cb.tip_saldo, cb.cod_oficina, cb.cod_moneda, 
                   NVL(ge.residente,'S'), NVL(ge.cod_sec_contable,'N'), pr.cod_sec_credito, cb.cod_transaccion, cb.estado
         UNION
         SELECT gc.cod_modulo, gc.cod_modalidad, cb.tip_saldo, cb.cod_oficina, cb.cod_moneda, 
                NVL(ge.residente,'S') residente, NVL(ge.cod_sec_contable,'N') cod_sec_contable,
                null, cb.cod_transaccion, cb.estado, sum(cb.mto_dep_interno) mto_dep_interno, sum(cb.mto_dep_mon_local) mto_dep_mon_local
           FROM ge_cta_dep_internos_det cb, ge_clientes ge, ge_cta_clientes gc
          WHERE cb.ano = v_anho
            AND cb.mes = v_mes
            AND cb.nro_cuenta = gc.nro_cuenta
            AND gc.relacion = 'P'
            AND gc.cod_persona = ge.cod_persona
            AND gc.cod_modulo <> 6
            AND cb.mto_dep_interno <> 0
          GROUP BY gc.cod_modulo, gc.cod_modalidad, cb.tip_saldo, cb.cod_oficina, cb.cod_moneda, 
                   NVL(ge.residente,'S'), NVL(ge.cod_sec_contable,'N'), null, cb.cod_transaccion, cb.estado;
      
      -- Procedimiento que obtiene la moneda del rubro.
      PROCEDURE lp_obt_mon_rubro(p_cod_rubro  IN cb_rubros.cod_moneda%TYPE,
                                 p_cod_moneda IN OUT cb_rubros.cod_moneda%TYPE,
                                 p_encontro   IN OUT VARCHAR2) IS
      BEGIN
         SELECT cod_moneda 
           INTO p_cod_moneda 
           FROM cb_rubros 
          WHERE cod_rubro = p_cod_rubro;
      EXCEPTION
         WHEN no_data_found THEN
            IF substr(p_cod_rubro, 14, 2) IN ('99', '00') THEN
               p_cod_moneda := pag_gen.fu_obt_mon_local;
               p_encontro   := 'S';
            ELSIF substr(p_cod_rubro, 14, 2) IN ('01', '98') THEN
               p_cod_moneda := pag_gen.fu_obt_mon_fuerte;
               p_encontro   := 'S';
            ELSE
               p_encontro := 'N';
            END IF;
         WHEN OTHERS THEN
            raise_application_error(-20000, 'Rec. Rubro ' || p_cod_rubro || '-' || SQLERRM);
      END;
      
      -- obtiene el codigo de rubro que corresponde a una cuenta
      PROCEDURE lp_obt_cod_rubro
   (
      p_cod_modulo       IN NUMBER,
      p_cod_modalidad    IN NUMBER,
      p_cod_transaccion  IN NUMBER,
      p_cod_moneda       IN VARCHAR2,
      p_cod_sec_contable IN VARCHAR2,
      p_cod_tip_deudor   IN NUMBER,
      p_residente        IN VARCHAR2,
      p_cod_plazo        IN VARCHAR2,
      p_tip_movimiento   IN VARCHAR2,
      p_cod_rubro        IN OUT VARCHAR2,
      p_est_cuenta       IN VARCHAR2 DEFAULT NULL,
      p_tip_renovacion   IN VARCHAR2 DEFAULT NULL,
      p_cat_automatica   IN NUMBER DEFAULT NULL,
      p_tip_interes      IN VARCHAR2 DEFAULT NULL,
      p_tip_cuenta       IN VARCHAR2 DEFAULT NULL,
      p_cod_sit_contable IN NUMBER DEFAULT NULL,
      p_cod_sec_credito  IN NUMBER DEFAULT NULL
   ) IS
      v_cod_tip_asiento  ge_transacciones.cod_tip_asiento%TYPE;
      v_cod_tip_asiento2 ge_transacciones.cod_tip_asiento2%TYPE;
      v_cod_pro_contable ge_modalidades.cod_pro_contable%TYPE;
      v_ind_deudor       ge_tip_asientos.ind_deudor%TYPE;
      v_ind_plazo        ge_tip_asientos.ind_plazo%TYPE;
      v_ind_producto     ge_tip_asientos.ind_producto%TYPE;
   BEGIN
      /* busco la transaccion que le corresponde */
      SELECT tr.cod_tip_asiento, cod_tip_asiento2, cod_pro_contable
        INTO v_cod_tip_asiento, v_cod_tip_asiento2, v_cod_pro_contable
        FROM ge_modalidades mo, ge_transacciones tr
       WHERE tr.cod_modulo = p_cod_modulo
         AND tr.cod_modalidad = p_cod_modalidad
         AND tr.cod_transaccion = p_cod_transaccion
         AND mo.cod_modulo = p_cod_modulo
         AND mo.cod_modalidad = p_cod_modalidad;
   
      /* busco la cuenta contable que le corresponde */
      SELECT ind_plazo, ind_deudor, cod_rubro, ind_producto
        INTO v_ind_plazo, v_ind_deudor, p_cod_rubro, v_ind_producto
        FROM ge_tip_asientos
       WHERE cod_tip_asiento IN (v_cod_tip_asiento, v_cod_tip_asiento2)
         AND cod_moneda = p_cod_moneda
         AND (cod_sec_contable IS NULL OR cod_sec_contable = p_cod_sec_contable)
         AND (tip_renovacion IS NULL OR tip_renovacion = nvl(p_tip_renovacion, 'A'))
         AND (tip_interes IS NULL OR tip_interes = p_tip_interes)
         AND (tip_cuenta IS NULL OR tip_cuenta = p_tip_cuenta)
         AND (cat_automatica IS NULL OR cat_automatica = p_cat_automatica)
         AND (est_cuenta IS NULL OR est_cuenta = p_est_cuenta)
         AND (ind_residente = 'X' OR ind_residente = p_residente)
         AND (cod_sit_contable = p_cod_sit_contable OR cod_sit_contable IS NULL)
         AND tip_movimiento = p_tip_movimiento
         AND nro_linea =
             (SELECT MIN(nro_linea)
                FROM ge_tip_asientos
               WHERE cod_tip_asiento = v_cod_tip_asiento
                 AND cod_moneda = p_cod_moneda
                 AND (cod_sec_contable IS NULL OR cod_sec_contable = p_cod_sec_contable)
                 AND (tip_renovacion IS NULL OR tip_renovacion = nvl(p_tip_renovacion, 'A'))
                 AND (tip_interes IS NULL OR tip_interes = p_tip_interes)
                 AND (tip_cuenta IS NULL OR tip_cuenta = p_tip_cuenta)
                 AND (cat_automatica IS NULL OR cat_automatica = p_cat_automatica)
                 AND (est_cuenta IS NULL OR est_cuenta = p_est_cuenta)
                 AND (ind_residente = 'X' OR ind_residente = p_residente)
                 AND (cod_sit_contable = p_cod_sit_contable OR cod_sit_contable IS NULL)
                 AND tip_movimiento = p_tip_movimiento);
      IF v_ind_plazo = 'S' THEN
         p_cod_rubro := substr(p_cod_rubro, 1, 2) || p_cod_plazo || substr(p_cod_rubro, 4, 12);
      END IF;
      IF v_ind_deudor = 'S' OR substr(p_cod_rubro, 9, 2) = 'TD' THEN
         p_cod_rubro := substr(p_cod_rubro, 1, 8) || (ltrim(to_char(p_cod_tip_deudor, '00'))) ||
                        substr(p_cod_rubro, 11, 5);
      END IF;
      ---Reemplaza el codigo del producto -----------------------
      IF v_ind_producto = 'S' THEN
         p_cod_rubro := substr(p_cod_rubro, 1, 10) || ltrim(to_char(v_cod_pro_contable, '000')) ||
                        substr(p_cod_rubro, 14, 2);
      END IF;
      IF substr(p_cod_rubro, 11, 3) = 'SEC' THEN
         -- es solo para prestamos, para contabilizar por sector
         p_cod_rubro := substr(p_cod_rubro, 1, 10) ||
                        ltrim(to_char(fup_obt_sec_rubro(p_cod_sec_credito), '000')) ||
                        substr(p_cod_rubro, 14, 2);
      END IF;
   EXCEPTION
      WHEN OTHERS THEN
         p_cod_rubro := NULL;
   END;         
   --
   BEGIN
      
      v_msj := ' Depositos Internos. ';
      -- Verifica que exista movimientos de Dep. Intenos.
      SELECT COUNT(1)
        INTO v_existe
        FROM ge_cta_dep_internos_det cb
       WHERE cb.ano = v_anho
         AND cb.mes = v_mes;
   
      IF v_existe = 0 THEN
         raise_application_error(-20000,' ERROR. NO existen movimientos generados de Dep. Internos en el periodo: '||v_anho||'/'||v_mes);
      END IF;
      
      -- Genero los movimientos contables.
      FOR reg IN c_dep_internos LOOP
         -- Ve el tipo de asiento.
         BEGIN
            SELECT cod_tip_asiento, descripcion, cod_tip_asiento2, tipo
              INTO v_cod_tip_asiento, v_des_transaccion, v_cod_tip_asiento2, v_tip_movimiento
              FROM ge_transacciones
             WHERE cod_modulo = reg.cod_modulo
               AND cod_modalidad = reg.cod_modalidad
               AND cod_transaccion = reg.cod_transaccion
               AND cod_tip_asiento IS NOT NULL;
         EXCEPTION
            WHEN no_data_found THEN
               raise_application_error(-20000,
                                       'Transaccion ' || to_char(reg.cod_modulo) || '-' ||
                                        to_char(reg.cod_modalidad) || '-' || reg.cod_transaccion || '-' ||' no tiene asiento definido.');
            WHEN OTHERS THEN
               IF SQLCODE <= -20000 THEN
                  RAISE;
               ELSE
                  raise_application_error(-20001, 'Error PR_GEN_MOV_CONTABLES ' || SQLERRM);
               END IF;
         END;
         -- Asignacion de Valores.
         v_cod_moneda         := reg.cod_moneda;         
         v_mto_dep_interno    := ROUND(reg.mto_dep_interno,0);
         -- Requerimiento: CNFCMFDI-3.
         -- Fecha: 08/09/2015.
         v_mto_dep_mon_local  := ROUND(reg.mto_dep_mon_local,0);
         v_cod_oficina        := reg.cod_oficina;
         v_cod_ofi_movimiento := reg.cod_oficina;
         -- Verifica la Moneda.
         IF v_cod_moneda = v_cod_mon_local THEN
            v_mto_mon_local      := v_mto_dep_interno;
            v_mto_mon_extranjera := 0;
            v_mto_cotizacion     := 1;        
         ELSE                        
            -- se obtiene la cotizacion de cierre
            -- Requerimiento:CNFCMFDI-3.
            -- Fecha: 08/09/2015.
            -- v_mto_cotizacion := pag_gen.fu_obt_cotizacion(v_cod_moneda, v_fec_actual);
            v_mto_cotizacion     := round(NVL(v_mto_dep_mon_local,0)/NVL(v_mto_dep_interno,0),2);
            --
            -- v_mto_mon_local      := round(nvl(v_mto_dep_interno,0) * nvl(v_mto_cotizacion,0), 0);
            v_mto_mon_local      := round(nvl(v_mto_dep_mon_local,0),0);
            v_mto_mon_extranjera := round(v_mto_dep_interno,2);
         END IF;
         --         
         v_nro_linea := 0;
         --
         -- Ve el tipo de movimiento.
         IF v_mto_mon_local > 0 THEN
            v_sal_mon_local  := v_mto_mon_local;
         ELSE
            v_sal_mon_local      := v_mto_mon_local * -1;
            v_sal_mon_extranjera := v_mto_mon_extranjera * -1;
            IF v_tip_movimiento = 'C' THEN
               v_tip_movimiento := 'D';
            ELSE
               v_tip_movimiento := 'C';
            END IF;
         END IF;
         --
         IF reg.cod_transaccion = 888 THEN
            IF v_tip_movimiento = 'C' THEN
               v_cod_ofi_movimiento := v_cod_ofi_dep_interno;
            ELSE
               v_cod_ofi_movimiento := v_cod_oficina;
            END IF;
         ELSIF reg.cod_transaccion = 1888 THEN
            IF v_tip_movimiento = 'D' THEN
               v_cod_ofi_movimiento := v_cod_ofi_dep_interno;
            ELSE
               v_cod_ofi_movimiento := v_cod_oficina;
            END IF;
         END IF;
         --
         v_encontro := 'S';
         lp_obt_cod_rubro(reg.cod_modulo, reg.cod_modalidad, reg.cod_transaccion, reg.cod_moneda,
                          reg.cod_sec_contable, null, reg.residente, null, v_tip_movimiento,
                          v_cod_rubro, reg.estado, null, null, null, null, null, reg.cod_sec_credito);         
         lp_obt_mon_rubro(v_cod_rubro, v_mon_rubro, v_encontro);
         IF v_encontro = 'N' THEN
            v_msj := 'Cuenta inexistente en Plan de Cuentas ' || v_cod_rubro;
            v_mon_rubro := v_cod_mon_local;
         END IF;
         --
         v_nro_asiento := fug_obt_pardinamico('SIG_NRO_ASIENTO');
         prg_act_par_dinamico('SIG_NRO_ASIENTO',null, null, null, null, (v_nro_asiento + 1));
         --
         IF v_mon_rubro = v_cod_mon_local THEN
            v_sal_mon_extranjera := 0;
            v_val_cotizacion     := 1;
         ELSE
            v_sal_mon_extranjera := v_mto_mon_extranjera;
            v_val_cotizacion     := v_mto_cotizacion;
         END IF;         
         --
         v_referencia      := 'DEP.INT';
         v_descripcion     := substr(v_des_transaccion, 1, 60);
         --
         IF v_sal_mon_local <> 0 THEN
            v_nro_linea := v_nro_linea + 1;               
            -- Cargar registro de asientos detalles
            r_bamde.fecha          := v_fec_actual;
            r_bamde.cod_oficina    := v_cod_ofi_movimiento;
            r_bamde.nro_asiento    := v_nro_asiento;
            r_bamde.nro_linea      := v_nro_linea;
            r_bamde.cod_rubro      := v_cod_rubro;
            r_bamde.tip_movimiento := v_tip_movimiento;
            r_bamde.mto_mon_rubro  := v_sal_mon_extranjera;
            r_bamde.mto_mon_local  := v_sal_mon_local;
            r_bamde.descripcion    := v_descripcion;
            r_bamde.referencia     := v_referencia;
            r_bamde.protegido      := 'N';
            r_bamde.actualizado    := 'N';
            r_bamde.val_cotizacion := v_val_cotizacion;
            r_bamde.distribuido    := 'N';
            r_bamde.ref_movimiento := NULL;
            pr_ins_asi_manuales(r_bamde);
         END IF;
         -- Genero los movimientos de interoficinas.
         -- Recuperar cuenta contable interoficina
         v_cod_rubro    := fug_obt_pardinamico('COD_RUB_INTEROFICINA', NULL, NULL, v_cod_moneda,v_cod_oficina);
         IF v_cod_ofi_movimiento != v_cod_ofi_dep_interno THEN
            v_cod_rubro := substr(v_cod_rubro, 1, 10) || ltrim(to_char(v_cod_ofi_dep_interno,'000')) || substr(v_cod_rubro, 14, 2);
         ELSE
            v_cod_rubro := substr(v_cod_rubro, 1, 10) || ltrim(to_char(v_cod_oficina,'000')) || substr(v_cod_rubro, 14, 2);
         END IF;
         -- ve moneda de la cuenta --
         v_encontro := 'S';
         lp_obt_mon_rubro(v_cod_rubro, v_cod_moneda, v_encontro);
         IF v_encontro = 'N' THEN
            v_msj := 'Rubro Inexistente-Plan de Ctas.Consol' || v_cod_rubro;
            IF substr(v_cod_rubro, 14, 2) IN ('99', '98') THEN
               v_cod_moneda := v_cod_mon_local;
            END IF;
         END IF;            
         v_descripcion := substr(TRIM(v_des_transaccion) || '(Inter of)', 1, 60);
         IF v_tip_movimiento = 'C' THEN
            v_tip_movimiento := 'D';
         ELSE
            v_tip_movimiento := 'C';
         END IF;
         IF v_sal_mon_local <> 0 THEN
            v_nro_linea := v_nro_linea + 1;
            -- Cargar registro de asientos detalles
            r_bamde.fecha          := v_fec_actual;
            r_bamde.cod_oficina    := v_cod_ofi_movimiento;
            r_bamde.nro_asiento    := v_nro_asiento;
            r_bamde.nro_linea      := v_nro_linea;
            r_bamde.cod_rubro      := v_cod_rubro;
            r_bamde.tip_movimiento := v_tip_movimiento;
            r_bamde.mto_mon_rubro  := v_sal_mon_extranjera;
            r_bamde.mto_mon_local  := v_sal_mon_local;
            r_bamde.descripcion    := v_descripcion;
            r_bamde.referencia     := v_referencia;
            r_bamde.protegido      := 'N';
            r_bamde.actualizado    := 'N';
            r_bamde.val_cotizacion := v_val_cotizacion;
            r_bamde.distribuido    := 'N';
            r_bamde.ref_movimiento := NULL;
            pr_ins_asi_manuales(r_bamde);
         END IF; 
         --
         -- Genero el movimiento correspondiente al COAP.        
         v_nro_linea := 0;
         --
         -- Ve el tipo de movimiento.       
         IF reg.cod_transaccion = 888 THEN
            IF v_tip_movimiento = 'C' THEN
               v_cod_ofi_movimiento := v_cod_ofi_dep_interno;
            ELSE
               v_cod_ofi_movimiento := v_cod_oficina;
            END IF;
         ELSIF reg.cod_transaccion = 1888 THEN
            IF v_tip_movimiento = 'D' THEN
               v_cod_ofi_movimiento := v_cod_ofi_dep_interno;
            ELSE
               v_cod_ofi_movimiento := v_cod_oficina;
            END IF;
         END IF;
         --
         v_encontro := 'S';
         lp_obt_cod_rubro(reg.cod_modulo, reg.cod_modalidad, reg.cod_transaccion, reg.cod_moneda,
                          reg.cod_sec_contable, null, reg.residente, null, v_tip_movimiento,
                          v_cod_rubro, reg.estado, null, null, null, null, null, reg.cod_sec_credito);         
         lp_obt_mon_rubro(v_cod_rubro, v_mon_rubro, v_encontro);
         IF v_encontro = 'N' THEN
            v_msj := 'Cuenta inexistente en Plan de Cuentas ' || v_cod_rubro;
            v_mon_rubro := v_cod_mon_local;
         END IF;
         --
         v_nro_asiento := fug_obt_pardinamico('SIG_NRO_ASIENTO');
         prg_act_par_dinamico('SIG_NRO_ASIENTO',null, null, null, null, (v_nro_asiento + 1));
         --
         IF v_mon_rubro = v_cod_mon_local THEN
            v_sal_mon_extranjera := 0;
            v_val_cotizacion     := 1;
         ELSE
            v_sal_mon_extranjera := v_mto_mon_extranjera;
            v_val_cotizacion     := v_mto_cotizacion;
         END IF;         
         --
         v_referencia      := 'DEP.INT';
         v_descripcion     := substr(v_des_transaccion, 1, 60);
         v_cod_mod_padre   := reg.cod_modulo;
         v_cod_mad_padre   := reg.cod_modalidad;
         --
         IF v_sal_mon_local <> 0 THEN
            v_nro_linea := v_nro_linea + 1;               
            -- Cargar registro de asientos detalles
            r_bamde.fecha          := v_fec_actual;
            r_bamde.cod_oficina    := v_cod_ofi_movimiento;
            r_bamde.nro_asiento    := v_nro_asiento;
            r_bamde.nro_linea      := v_nro_linea;
            r_bamde.cod_rubro      := v_cod_rubro;
            r_bamde.tip_movimiento := v_tip_movimiento;
            r_bamde.mto_mon_rubro  := v_sal_mon_extranjera;
            r_bamde.mto_mon_local  := v_sal_mon_local;
            r_bamde.descripcion    := v_descripcion;
            r_bamde.referencia     := v_referencia;
            r_bamde.protegido      := 'N';
            r_bamde.actualizado    := 'N';
            r_bamde.val_cotizacion := v_val_cotizacion;
            r_bamde.distribuido    := 'N';
            r_bamde.ref_movimiento := NULL;
            pr_ins_asi_manuales(r_bamde);
         END IF;
         -- Genero los movimientos de interoficinas.
         -- Recuperar cuenta contable interoficina
         v_cod_rubro    := fug_obt_pardinamico('COD_RUB_INTEROFICINA', NULL, NULL, v_cod_moneda,v_cod_oficina);
         IF v_cod_ofi_movimiento != v_cod_ofi_dep_interno THEN
            v_cod_rubro := substr(v_cod_rubro, 1, 10) || ltrim(to_char(v_cod_ofi_dep_interno,'000')) || substr(v_cod_rubro, 14, 2);
         ELSE
            v_cod_rubro := substr(v_cod_rubro, 1, 10) || ltrim(to_char(v_cod_oficina,'000')) || substr(v_cod_rubro, 14, 2);
         END IF;
         -- ve moneda de la cuenta --
         v_encontro := 'S';
         lp_obt_mon_rubro(v_cod_rubro, v_cod_moneda, v_encontro);
         IF v_encontro = 'N' THEN
            v_msj := 'Rubro Inexistente-Plan de Ctas.Consol' || v_cod_rubro;
            IF substr(v_cod_rubro, 14, 2) IN ('99', '98') THEN
               v_cod_moneda := v_cod_mon_local;
            END IF;
         END IF;            
         v_descripcion := substr(TRIM(v_des_transaccion) || '(Inter of)', 1, 60);
         IF v_tip_movimiento = 'C' THEN
            v_tip_movimiento := 'D';
         ELSE
            v_tip_movimiento := 'C';
         END IF;
         IF v_sal_mon_local <> 0 THEN
            v_nro_linea := v_nro_linea + 1;
            -- Cargar registro de asientos detalles
            r_bamde.fecha          := v_fec_actual;
            r_bamde.cod_oficina    := v_cod_ofi_movimiento;
            r_bamde.nro_asiento    := v_nro_asiento;
            r_bamde.nro_linea      := v_nro_linea;
            r_bamde.cod_rubro      := v_cod_rubro;
            r_bamde.tip_movimiento := v_tip_movimiento;
            r_bamde.mto_mon_rubro  := v_sal_mon_extranjera;
            r_bamde.mto_mon_local  := v_sal_mon_local;
            r_bamde.descripcion    := v_descripcion;
            r_bamde.referencia     := v_referencia;
            r_bamde.protegido      := 'N';
            r_bamde.actualizado    := 'N';
            r_bamde.val_cotizacion := v_val_cotizacion;
            r_bamde.distribuido    := 'N';
            r_bamde.ref_movimiento := NULL;
            pr_ins_asi_manuales(r_bamde);
         END IF;                 
      END LOOP;
   END;
   
end PAB_DEP;
/

