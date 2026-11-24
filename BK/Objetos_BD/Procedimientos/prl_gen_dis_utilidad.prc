CREATE OR REPLACE PROCEDURE IT.PRL_GEN_DIS_UTILIDAD
 IS

   -- Proceso de distribución de utilidad por trading de acuerdo al volumen de operaciones por cliente.
   v_fec_actual        ge_calendarios.fec_actual%type := pag_cal.fu_obt_fec_actual(2);
   v_cod_mon_local     ba_monedas.cod_moneda%type     := pag_gen.fu_obt_mon_local;
   v_monto             ge_movimientos.monto%type      := 0;
   v_sal_total         ge_movimientos.monto%type      := 0;
   v_anho              lc_res_ope_clientes.ano%type   := to_char(v_fec_actual,'yyyy');   
   v_mes               lc_res_ope_clientes.mes%type   := to_char(v_fec_actual,'mm');
   v_por_participacion lc_res_ope_clientes.por_participacion%type := 0;
   v_est_proceso       ba_modulos.estado%type;
   v_cod_entidad       ge_par_generales.cod_persona%type;
   
   -- Cursores.
   CURSOR c_res_ope_clientes IS
    SELECT a.cod_persona, a.mto_vol_operaciones, a.rowid
      FROM lc_res_ope_clientes a
     WHERE a.ano = v_anho
       AND a.mes = v_mes;   
       
   -- Procedimientos.
   PROCEDURE lp_ins_asi_manuales(rp_bamde IN cb_asi_futuros_det%ROWTYPE) IS
   BEGIN
      -- Inserto en la cabecera.
      UPDATE cb_asi_futuros cb
         SET cb.tot_control = cb.tot_control + rp_bamde.mto_mon_local
       WHERE cb.fecha = rp_bamde.fecha
         AND cb.cod_oficina = rp_bamde.cod_oficina
         AND cb.nro_asiento = rp_bamde.nro_asiento;
   
      IF SQL%NOTFOUND THEN
      
         INSERT INTO cb_asi_futuros
            (fecha, cod_oficina, nro_asiento, cod_usuario, cod_modulo, cod_modalidad, cod_cargo, tot_control)
         VALUES
            (rp_bamde.fecha, rp_bamde.cod_oficina, rp_bamde.nro_asiento, substr(user,1,10), 2, 21,  
             null, rp_bamde.mto_mon_local);
      END IF;
      
      -- Inserto el detalle.
      INSERT INTO cb_asi_futuros_det
         (fecha, cod_oficina, nro_asiento, nro_linea, cod_rubro, tip_movimiento, mto_mon_local, descripcion, mto_mon_rubro, val_cotizacion, referencia)
      VALUES
         (rp_bamde.fecha, rp_bamde.cod_oficina, rp_bamde.nro_asiento, rp_bamde.nro_linea, rp_bamde.cod_rubro, 
          rp_bamde.tip_movimiento, rp_bamde.mto_mon_local, rp_bamde.descripcion, rp_bamde.mto_mon_rubro, rp_bamde.val_cotizacion,  rp_bamde.referencia);
      
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000,
                                 'Ins.cb_asi_futuros_det ' || rp_bamde.nro_asiento || '-' ||
                                  rp_bamde.referencia || '-' || SQLERRM);
   END;
   
   PROCEDURE lp_rev_asi_trading IS
      -- Variables.
      v_rub_ganancia      ge_movimientos.cod_rubro%type   := fug_obt_pardinamico('LCA_RUB_GAN_TRADING'); 
      v_rub_perdida       ge_movimientos.cod_rubro%type   := fug_obt_pardinamico('LCA_RUB_PER_TRADING');
      v_rub_consolidacion ge_movimientos.cod_rubro%type   := fug_obt_pardinamico('LCA_RUB_CON_TRADING');
      v_cod_ofi_trading   ge_movimientos.cod_oficina%type := fug_obt_pardinamico('LCA_COD_OFI_UTILIDAD');
      v_sal_rub_ganancia  ge_movimientos.monto%type := 0;
      v_sal_rub_perdida   ge_movimientos.monto%type := 0;
      v_nro_asiento       cb_asientos.nro_asiento%type;
      v_nro_linea         cb_asi_futuros_det.nro_linea%TYPE := 0;
      r_bamde             cb_asi_futuros_det%ROWTYPE;
      
   BEGIN
      
      -- Obtengo el saldo de los rubros contables.
      BEGIN
         SELECT (nvl(sal_mon_loc_ant,0)+nvl(deb_mon_local,0)-nvl(cre_mon_local,0)) * -1
           INTO v_sal_rub_ganancia
           FROM cb_sal_oficinas cb
          WHERE cb.cod_rubro = v_rub_ganancia
            AND cb.cod_oficina = v_cod_ofi_trading;
      EXCEPTION
         WHEN OTHERS THEN
            v_sal_rub_ganancia := 0;
      END;
      
      BEGIN
         SELECT (nvl(sal_mon_loc_ant,0)+nvl(deb_mon_local,0)-nvl(cre_mon_local,0))
           INTO v_sal_rub_perdida
           FROM cb_sal_oficinas cb
          WHERE cb.cod_rubro = v_rub_perdida
            AND cb.cod_oficina = v_cod_ofi_trading;
      EXCEPTION
         WHEN OTHERS THEN
            v_sal_rub_perdida := 0;
      END;
      
      -- Obtengo el saldo por diferencia de la utilidad generada por trading.
      v_sal_total := nvl(v_sal_rub_ganancia,0) - nvl(v_sal_rub_perdida,0);
      
      IF v_sal_total <> 0 THEN
      
         -- Se genera el asiento de consolidación de utilidad de trading.
         v_nro_asiento := fub_obt_sig_nro_asi_futuro(v_cod_ofi_trading, v_fec_actual);        
         --
         v_nro_linea := v_nro_linea + 1;               
         -- Cargar registro de asientos detalles
         r_bamde.fecha          := v_fec_actual;
         r_bamde.cod_oficina    := v_cod_ofi_trading;
         r_bamde.nro_asiento    := v_nro_asiento;
         r_bamde.nro_linea      := v_nro_linea;
         r_bamde.cod_rubro      := v_rub_ganancia;
         r_bamde.tip_movimiento := 'D';
         r_bamde.mto_mon_rubro  := 0;
         r_bamde.mto_mon_local  := v_sal_rub_ganancia;
         r_bamde.descripcion    := 'REV. TRADING';
         r_bamde.referencia     := 'REV.TRADING';
         r_bamde.protegido      := 'N';
         r_bamde.actualizado    := 'N';
         r_bamde.val_cotizacion := NULL;
         r_bamde.distribuido    := 'N';
         r_bamde.ref_movimiento := NULL;
         lp_ins_asi_manuales(r_bamde);
         --
         v_nro_linea := v_nro_linea + 1;               
         -- Cargar registro de asientos detalles
         r_bamde.fecha          := v_fec_actual;
         r_bamde.cod_oficina    := v_cod_ofi_trading;

         r_bamde.nro_asiento    := v_nro_asiento;
         r_bamde.nro_linea      := v_nro_linea;
         r_bamde.cod_rubro      := v_rub_perdida;
         r_bamde.tip_movimiento := 'C';
         r_bamde.mto_mon_rubro  := 0;
         r_bamde.mto_mon_local  := v_sal_rub_perdida;
         r_bamde.descripcion    := 'REV. TRADING';
         r_bamde.referencia     := 'REV.TRADING';
         r_bamde.protegido      := 'N';
         r_bamde.actualizado    := 'N';
         r_bamde.val_cotizacion := NULL;
         r_bamde.distribuido    := 'N';
         r_bamde.ref_movimiento := NULL;
         lp_ins_asi_manuales(r_bamde);
         --
         v_nro_linea := v_nro_linea + 1;               
         -- Cargar registro de asientos detalles
         r_bamde.fecha          := v_fec_actual;
         r_bamde.cod_oficina    := v_cod_ofi_trading;

         r_bamde.nro_asiento    := v_nro_asiento;
         r_bamde.nro_linea      := v_nro_linea;
         r_bamde.cod_rubro      := v_rub_consolidacion;
         r_bamde.tip_movimiento := (CASE WHEN v_sal_total > 0 THEN 'C' ELSE 'D' END);
         r_bamde.mto_mon_rubro  := 0;
         r_bamde.mto_mon_local  := ABS(v_sal_total);
         r_bamde.descripcion    := 'REV. TRADING';
         r_bamde.referencia     := 'REV.TRADING';
         r_bamde.protegido      := 'N';
         r_bamde.actualizado    := 'N';
         r_bamde.val_cotizacion := NULL;
         r_bamde.distribuido    := 'N';
         r_bamde.ref_movimiento := NULL;
         lp_ins_asi_manuales(r_bamde);
      END IF;
            
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000,'Error en LP_REV_ASI_TRADING '||sqlerrm);
   END;
   
   PROCEDURE lp_gen_asi_trading IS
      -- Variables.
      v_rub_consolidacion ge_movimientos.cod_rubro%type   := fug_obt_pardinamico('LCA_RUB_CON_TRADING');
      v_rub_perdida       ge_movimientos.cod_rubro%type   := fug_obt_pardinamico('LCA_RUB_RES_TRADING');
      v_rub_destino       ge_movimientos.cod_rubro%type;
      v_cod_rubro         ge_movimientos.cod_rubro%type;
      v_cod_ofi_trading   ge_movimientos.cod_oficina%type := fug_obt_pardinamico('LCA_COD_OFI_UTILIDAD');
      v_cod_ofi_cliente   ge_movimientos.cod_oficina%type;
      v_sal_trading       ge_movimientos.monto%type := 0;
      v_nro_asiento       cb_asientos.nro_asiento%type;
      v_nro_linea         cb_asi_futuros_det.nro_linea%TYPE := 0;
      v_tip_movimiento    ge_tip_asientos.tip_movimiento%TYPE;
      r_bamde             cb_asi_futuros_det%ROWTYPE;
      
      -- Cursores.
      CURSOR c_cta_clientes IS
         SELECT lc.cod_persona, lc.por_participacion
           FROM lc_res_ope_clientes lc, ge_clientes g 
          WHERE lc.ano = v_anho
            AND lc.mes = v_mes
            AND lc.por_participacion <> 0
            AND lc.cod_persona = g.cod_persona;          
      
   BEGIN
      
      -- Obtengo el saldo por diferencia de la utilidad generada por trading.
      v_sal_trading := abs(nvl(v_sal_total,0));
      
      -- Obtengo el rubro de acuerdo a la utilidad generada por trading.
      IF nvl(v_sal_total,0) < 0 THEN
         v_rub_destino    := v_rub_perdida;
         v_tip_movimiento := 'D';
      ELSE
         v_rub_destino    := v_rub_consolidacion;
         v_tip_movimiento := 'C';
      END IF;
      
      FOR reg IN c_cta_clientes LOOP
         
         -- Cálculo el monto de participación del cliente y la sucursal correspondiente.
         v_monto := round(nvl(((abs(nvl(v_sal_total,0)) * nvl(reg.por_participacion,0)) / 100),0),0);
         --
         v_cod_ofi_cliente := fug_obt_ofi_cliente(reg.cod_persona);
         
         /* Genero el asiento de contabilización. */                  
         IF v_monto <> 0 THEN
         
            /* Movimiento que afecta el rubro transitorio.*/
            -- Se genera el asiento de consolidación de utilidad de trading.
            v_nro_asiento := fub_obt_sig_nro_asi_futuro(v_cod_ofi_trading, v_fec_actual);
            --
            
            v_nro_linea := v_nro_linea + 1;               
            -- Cargar registro de asientos detalles
            r_bamde.fecha          := v_fec_actual;
            r_bamde.cod_oficina    := v_cod_ofi_trading;
            r_bamde.nro_asiento    := v_nro_asiento;
            r_bamde.nro_linea      := v_nro_linea;
            r_bamde.cod_rubro      := v_rub_consolidacion;

            r_bamde.tip_movimiento := (CASE WHEN v_tip_movimiento = 'C' THEN 'D' ELSE 'C' END);
            r_bamde.mto_mon_rubro  := 0;
            r_bamde.mto_mon_local  := v_monto;
            r_bamde.descripcion    := 'TRADING';
            r_bamde.referencia     := 'TRADING';
            r_bamde.protegido      := 'N';
            r_bamde.actualizado    := 'N';
            r_bamde.val_cotizacion := NULL;
            r_bamde.distribuido    := 'N';
            r_bamde.ref_movimiento := NULL;
            lp_ins_asi_manuales(r_bamde);
            
            --  
            -- Recuperar cuenta contable interoficina
            v_cod_rubro    := fug_obt_pardinamico('COD_RUB_INTEROFICINA', NULL, NULL, v_cod_mon_local,v_cod_ofi_trading);
            v_cod_rubro := substr(v_cod_rubro, 1, 10) || ltrim(to_char(v_cod_ofi_cliente,'000')) || substr(v_cod_rubro, 14, 2);
                      
            v_nro_linea := v_nro_linea + 1;               
            -- Cargar registro de asientos detalles
            r_bamde.fecha          := v_fec_actual;
            r_bamde.cod_oficina    := v_cod_ofi_trading;
            r_bamde.nro_asiento    := v_nro_asiento;
            r_bamde.nro_linea      := v_nro_linea;

            r_bamde.cod_rubro      := v_cod_rubro; -- Interoficina

            r_bamde.tip_movimiento := v_tip_movimiento;
            r_bamde.mto_mon_rubro  := 0;
            r_bamde.mto_mon_local  := v_monto;
            r_bamde.descripcion    := 'TRADING INTEROF.';
            r_bamde.referencia     := 'TRADING';
            r_bamde.protegido      := 'N';
            r_bamde.actualizado    := 'N';
            r_bamde.val_cotizacion := NULL;
            r_bamde.distribuido    := 'N';
            r_bamde.ref_movimiento := NULL;
            lp_ins_asi_manuales(r_bamde);
            
            /* Movimiento que afecta la oficina del cliente.*/            
            
            -- Se genera el asiento de consolidación de utilidad de trading.
            v_nro_asiento := fub_obt_sig_nro_asi_futuro(v_cod_ofi_cliente, v_fec_actual);
            --            
            -- Recuperar cuenta contable interoficina
            v_cod_rubro    := fug_obt_pardinamico('COD_RUB_INTEROFICINA', NULL, NULL, v_cod_mon_local,v_cod_ofi_trading);
            v_cod_rubro := substr(v_cod_rubro, 1, 10) || ltrim(to_char(v_cod_ofi_trading,'000')) || substr(v_cod_rubro, 14, 2);
            
            v_nro_linea := v_nro_linea + 1;               
            -- Cargar registro de asientos detalles
            r_bamde.fecha          := v_fec_actual;
            r_bamde.cod_oficina    := v_cod_ofi_cliente;
            r_bamde.nro_asiento    := v_nro_asiento;
            r_bamde.nro_linea      := v_nro_linea;

            r_bamde.cod_rubro      := v_cod_rubro; -- Interoficina

            r_bamde.tip_movimiento := (CASE WHEN v_tip_movimiento = 'C' THEN 'D' ELSE 'C' END);
            r_bamde.mto_mon_rubro  := 0;
            r_bamde.mto_mon_local  := v_monto;
            r_bamde.descripcion    := 'TRADING INTEROF.';
            r_bamde.referencia     := 'TRADING';
            r_bamde.protegido      := 'N';
            r_bamde.actualizado    := 'N';
            r_bamde.val_cotizacion := NULL;
            r_bamde.distribuido    := 'N';
            r_bamde.ref_movimiento := NULL;
            lp_ins_asi_manuales(r_bamde);
            
            --            
            v_nro_linea := v_nro_linea + 1;               
            -- Cargar registro de asientos detalles
            r_bamde.fecha          := v_fec_actual;
            r_bamde.cod_oficina    := v_cod_ofi_cliente;
            r_bamde.nro_asiento    := v_nro_asiento;
            r_bamde.nro_linea      := v_nro_linea;

            r_bamde.cod_rubro      := v_rub_destino;

            r_bamde.tip_movimiento := v_tip_movimiento;
            r_bamde.mto_mon_rubro  := 0;
            r_bamde.mto_mon_local  := v_monto;
            r_bamde.descripcion    := reg.cod_persona;
            r_bamde.referencia     := 'TRADING';
            r_bamde.protegido      := 'N';
            r_bamde.actualizado    := 'N';
            r_bamde.val_cotizacion := NULL;
            r_bamde.distribuido    := 'N';
            r_bamde.ref_movimiento := NULL;
            lp_ins_asi_manuales(r_bamde);
         END IF;         
         
         -- Actualizo el saldo de utilidad de trading a distribuir.
         v_sal_trading := nvl(v_sal_trading,0) - nvl(v_monto,0);
         
      END LOOP;
      
      -- Genero los movimientos correspondientes de la entidad.
      IF v_sal_trading <> 0 THEN
         IF nvl(v_sal_total,0) < 0 THEN
            /* Movimiento que afecta el rubro transitorio.*/
            -- Se genera el asiento de consolidación de utilidad de trading.
            v_nro_asiento := fub_obt_sig_nro_asi_futuro(v_cod_ofi_trading, v_fec_actual);
            --
            
            v_nro_linea := v_nro_linea + 1;               
            -- Cargar registro de asientos detalles
            r_bamde.fecha          := v_fec_actual;
            r_bamde.cod_oficina    := v_cod_ofi_trading;
            r_bamde.nro_asiento    := v_nro_asiento;
            r_bamde.nro_linea      := v_nro_linea;
            r_bamde.cod_rubro      := v_rub_consolidacion;

            r_bamde.tip_movimiento := (CASE WHEN v_tip_movimiento = 'C' THEN 'D' ELSE 'C' END);
            r_bamde.mto_mon_rubro  := 0;
            r_bamde.mto_mon_local  := NVL(v_sal_trading,0);
            r_bamde.descripcion    := v_cod_entidad;
            r_bamde.referencia     := 'TRADING';
            r_bamde.protegido      := 'N';
            r_bamde.actualizado    := 'N';
            r_bamde.val_cotizacion := NULL;
            r_bamde.distribuido    := 'N';
            r_bamde.ref_movimiento := NULL;
            lp_ins_asi_manuales(r_bamde);
            
            --  
            v_nro_linea := v_nro_linea + 1;               
            -- Cargar registro de asientos detalles
            r_bamde.fecha          := v_fec_actual;
            r_bamde.cod_oficina    := v_cod_ofi_trading;
            r_bamde.nro_asiento    := v_nro_asiento;
            r_bamde.nro_linea      := v_nro_linea;

            r_bamde.cod_rubro      := v_rub_destino;

            r_bamde.tip_movimiento := v_tip_movimiento;
            r_bamde.mto_mon_rubro  := 0;
            r_bamde.mto_mon_local  := NVL(v_sal_trading,0);
            r_bamde.descripcion    := v_cod_entidad;
            r_bamde.referencia     := 'TRADING';
            r_bamde.protegido      := 'N';
            r_bamde.actualizado    := 'N';
            r_bamde.val_cotizacion := NULL;
            r_bamde.distribuido    := 'N';
            r_bamde.ref_movimiento := NULL;
            lp_ins_asi_manuales(r_bamde);   
         END IF;         
      END IF;
      
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000,'Error en LP_GEN_ASI_TRADING '||sqlerrm);
   END;

BEGIN

   -- Controlar si el módulo 2 se encuentra cerrado (debe utilizar balance cerrado)
   v_est_proceso := PAE_CNF.fu_obt_est_modulo(2);
   if nvl(v_est_proceso,4) <> 4 then
      raise_application_error(-20000,'El modulo 2 debe estar cerrado para generar los movimientos');
   end if;
    
   -- Obtengo el cod_persona de la entidad
   BEGIN
      SELECT ge.cod_persona
        INTO v_cod_entidad
        FROM ge_par_generales ge
       WHERE rownum = 1;            
   EXCEPTION
      WHEN OTHERS THEN
         v_cod_entidad := NULL;
   END;
   
   -- Obtengo el valor total de las operaciones de cambios del mes.
   BEGIN
      SELECT nvl(sum(a.mto_vol_operaciones),0)
        INTO v_monto
        FROM lc_res_ope_clientes a
       WHERE a.ano = v_anho
         AND a.mes = v_mes;
   EXCEPTION
      WHEN OTHERS THEN
         v_monto := 0;
   END;         
    
   -- Cálculo el porcentaje de participación de los clientes.
   IF v_monto > 0 THEN
            
      FOR reg IN c_res_ope_clientes LOOP
         BEGIN
            -- Obtengo el porcentaje de participación.
            v_por_participacion := round(nvl(((reg.mto_vol_operaciones * 100)/v_monto),0),5);   
      
            -- Actualizo el campo de porcentaje de participación.
            UPDATE lc_res_ope_clientes
               SET por_participacion = v_por_participacion
             WHERE rowid = reg.rowid;
         EXCEPTION
           WHEN OTHERS THEN
              NULL;
         END;
            
      END LOOP;
   END IF;
   
   -- Realizo el apunte contable de unificacion de saldos de resultados por trading.
   lp_rev_asi_trading;
   
   -- Genero los asientos de distribución de trading por cliente.
   lp_gen_asi_trading;
   
   -- Requerimiento: CNFAPDDG-3.
   -- Fecha: 26/05/2015.
   -- Realiza la reapertura de contabilidad.
   -- prb_reapertura;
   
EXCEPTION
   WHEN OTHERS THEN
      raise_application_error(-20000,'Error en PRL_GEN_DIS_UTILIDAD '||sqlerrm);
END;
/

