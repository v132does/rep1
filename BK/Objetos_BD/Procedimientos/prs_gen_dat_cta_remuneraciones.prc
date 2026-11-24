CREATE OR REPLACE PROCEDURE IT.PRS_GEN_DAT_CTA_REMUNERACIONES(P_MES      VARCHAR2,
                                                           P_ANO      VARCHAR2) IS
--- Proceso de Generación de Datos de Cuentas de Remuneración
--- Definición de variables de entorno
   v_fec_inicio                 date;
   v_fec_fin                    date;
   --v_cod_per_entidad            ge_par_generales.cod_persona%TYPE;
   v_cod_mon_local              ba_monedas.cod_moneda%TYPE := pag_gen.fu_obt_mon_local;
   v_cod_gru_tra_pag_elec       ge_gru_transacciones.cod_gru_transaccion%TYPE := fug_obt_pardinamico('COD_GRU_TRA_PAG_ELECTRONICOS');
   v_can_tot_cuenta             sb_dat_remuneraciones.can_tot_cuenta%TYPE;
   v_sal_tot_cuenta             sb_dat_remuneraciones.sal_tot_cuenta%TYPE;
   v_can_tot_ente               sb_dat_remuneraciones.can_tot_ente%TYPE;
   v_can_tot_cliente            sb_dat_remuneraciones.can_tot_cliente%TYPE;
   v_can_tot_ext_sin_costo      sb_dat_remuneraciones.can_tot_ext_sin_costo%TYPE;
   v_can_ext_sin_cos_prom       sb_dat_remuneraciones.can_ext_sin_cos_prom%TYPE;
   v_can_tot_extraccion         sb_dat_remuneraciones.can_tot_extraccion%TYPE;
   v_nro_tot_pag_electronico    sb_dat_remuneraciones.nro_tot_pag_electronico%TYPE;
   v_cos_min_exc_uso_atm        sb_dat_remuneraciones.cos_min_exc_uso_atm%TYPE;
   v_cos_max_exc_uso_atm        sb_dat_remuneraciones.cos_max_exc_uso_atm%TYPE;
   v_cos_exc_uso_atm_prom       sb_dat_remuneraciones.cos_exc_uso_atm_prom%TYPE;
   v_can_max_tra_atm_sin_costo  sb_dat_remuneraciones.can_max_tra_atm_sin_costo%TYPE;
   v_can_min_tra_atm_sin_costo  sb_dat_remuneraciones.can_min_tra_atm_sin_costo%TYPE;
   v_can_tra_atm_sin_cos_prom   sb_dat_remuneraciones.can_tra_atm_sin_cos_prom%TYPE;

BEGIN
   v_fec_inicio := to_date('01/'||p_mes||'/'||p_ano,'dd/mm/yyyy');
   v_fec_fin    := last_day(v_fec_inicio);
   --SD-Resoluciones Nro 128-130-131 SDRESOLUCI-3 - Resolucion 131 Cuentas de pago de remuneraciones
   /*BEGIN
     SELECT cod_persona
       INTO v_cod_per_entidad
       FROM ge_par_generales;
   END;*/
   --Cantidad de Cuentas Remuneraciones
   BEGIN
      SELECT COUNT(ctas.nro_cuenta)
        INTO v_can_tot_cuenta
        FROM (SELECT t.nro_cuenta
                FROM ge_pag_sueldos t
               WHERE t.fec_proceso BETWEEN v_fec_inicio AND v_fec_fin
                 AND t.nro_cuenta IS NOT NULL
                 AND t.procesado = 'S'
                 AND t.tipo = 'C'
                 AND t.monto > 0
                --SD-Resoluciones Nro 128-130-131 SDRESOLUCI-3 - Resolucion 131 Cuentas de pago de remuneraciones
               /*  AND NOT EXISTS (SELECT 0
                                   FROM ge_entes e, ba_personas pe
                                  WHERE e.cod_persona = pe.cod_persona
                                    AND pe.cod_persona = v_cod_per_entidad
                                    AND e.cod_ente = t.cod_ente)*/
               GROUP BY T.NRO_CUENTA) ctas,
             ge_cta_clientes c,
             ba_personas p
       WHERE ctas.nro_cuenta = c.nro_cuenta
         AND c.relacion = 'P'
         AND c.cod_persona = p.cod_persona
         AND p.tipo = 'F';
   EXCEPTION
     WHEN OTHERS THEN
       v_can_tot_cuenta := 0;
   END;  
   --Saldo de Cuentas Remuneraciones
   BEGIN
      SELECT SUM(saldo)
        INTO v_sal_tot_cuenta 
        FROM (SELECT ctas.nro_cuenta, 
                     ROUND(DECODE(ctas.cod_moneda, v_cod_mon_local, 1, NVL(fug_obt_cotizacion(ctas.cod_moneda, v_fec_fin), 1)) * NVL(s.sal_fin_mes, v.sal_fin_mes)) saldo 
                FROM (SELECT t.nro_cuenta, t.cod_moneda
                        FROM ge_pag_sueldos t
                       WHERE t.fec_proceso BETWEEN v_fec_inicio AND v_fec_fin
                         AND t.nro_cuenta IS NOT NULL
                         AND t.procesado = 'S'
                         AND t.tipo = 'C'
                         AND t.monto > 0
                         --SD-Resoluciones Nro 128-130-131 SDRESOLUCI-3 - Resolucion 131 Cuentas de pago de remuneraciones
                         /*AND NOT EXISTS (SELECT 0
                                           FROM ge_entes e, ba_personas pe
                                          WHERE e.cod_persona = pe.cod_persona
                                            AND pe.cod_persona = v_cod_per_entidad
                                            AND e.cod_ente = t.cod_ente)*/
                       GROUP BY T.NRO_CUENTA, t.cod_moneda) ctas, 
                     ge_cta_clientes c,ba_personas p, cc_sal_mensuales s, ah_sal_mensuales v
               WHERE ctas.nro_cuenta = c.nro_cuenta
                 AND c.relacion      = 'P'
                 AND c.cod_persona   = p.cod_persona
                 AND p.tipo          = 'F' 
                 AND s.nro_cuenta(+) = ctas.nro_cuenta
                 AND s.ano(+)        = p_ano
                 AND s.mes(+)        = p_mes
                 AND v.nro_cuenta(+) = ctas.nro_cuenta
                 AND v.ano(+)        = p_ano
                 AND v.mes(+)        = p_mes); 
   EXCEPTION
     WHEN OTHERS THEN
       v_sal_tot_cuenta := 0;                   
   END;
   --Cantidad de Entes Pago Remuneraciones
   BEGIN
     SELECT COUNT(DISTINCT cod_per_ente) 
       INTO v_can_tot_ente
       FROM (SELECT ctas.cod_ente, e.cod_persona cod_per_ente
               FROM (SELECT t.nro_cuenta, t.cod_ente
                       FROM ge_pag_sueldos t
                      WHERE t.fec_proceso BETWEEN v_fec_inicio AND v_fec_fin
                        AND t.nro_cuenta IS NOT NULL
                        AND t.procesado = 'S'
                        AND t.tipo = 'C'
                        AND t.monto > 0
                        --SD-Resoluciones Nro 128-130-131 SDRESOLUCI-3 - Resolucion 131 Cuentas de pago de remuneraciones
                        /*AND NOT EXISTS (SELECT 0
                                          FROM ge_entes e, ba_personas pe
                                         WHERE e.cod_persona = pe.cod_persona
                                           AND pe.cod_persona = v_cod_per_entidad
                                           AND e.cod_ente = t.cod_ente)*/
                      GROUP BY t.nro_cuenta, t.cod_ente) ctas,
                   ge_cta_clientes c,
                   ba_personas p,
                   ge_entes e
             WHERE ctas.nro_cuenta = c.nro_cuenta
               AND c.relacion = 'P'
               AND c.cod_persona = p.cod_persona
               AND p.tipo = 'F'
               AND e.cod_ente = ctas.cod_ente
             GROUP BY ctas.cod_ente, e.cod_persona);
   EXCEPTION
     WHEN OTHERS THEN
       v_can_tot_ente := 0;            
   END;
   --Cantidad de Clientes Pago Remuneraciones
   BEGIN
     SELECT COUNT(DISTINCT c.cod_persona) 
       INTO v_can_tot_cliente
       FROM (SELECT t.nro_cuenta
               FROM ge_pag_sueldos t
              WHERE t.fec_proceso BETWEEN v_fec_inicio AND v_fec_fin
                AND t.nro_cuenta IS NOT NULL
                AND t.procesado = 'S'
                AND t.tipo = 'C'
                AND t.monto > 0
                --SD-Resoluciones Nro 128-130-131 SDRESOLUCI-3 - Resolucion 131 Cuentas de pago de remuneraciones
                /*AND NOT EXISTS (SELECT 0
                                  FROM ge_entes e, ba_personas pe
                                 WHERE e.cod_persona = pe.cod_persona
                                   AND pe.cod_persona = v_cod_per_entidad
                                   AND e.cod_ente = t.cod_ente)*/
              GROUP BY t.nro_cuenta) ctas,
           ge_cta_clientes c,
           ba_personas p
     WHERE ctas.nro_cuenta = c.nro_cuenta
       AND c.relacion = 'P'
       AND c.cod_persona = p.cod_persona
       AND p.tipo = 'F';
   EXCEPTION
     WHEN OTHERS THEN
       v_can_tot_cliente := 0;            
   END;
   -- Cantidad de Extracciones sin Costo
   BEGIN
     SELECT SUM(can_ext_pro_atm_sin_cos+can_ext_otr_atm_sin_cos) 
       INTO v_can_tot_ext_sin_costo
       FROM(SELECT nro_cuenta, 
                   cod_ente, 
                   can_max_ext_pro_atm, 
                   can_ext_pro_atm, 
                   CASE WHEN can_max_ext_pro_atm >= can_ext_pro_atm THEN can_ext_pro_atm else can_max_ext_pro_atm END can_ext_pro_atm_sin_cos,
                   can_max_ext_otr_atm,
                   can_ext_otr_atm,
                   CASE WHEN can_max_ext_otr_atm >= can_ext_otr_atm THEN can_ext_otr_atm else can_max_ext_otr_atm END can_ext_otr_atm_sin_cos
              FROM (
            SELECT nro_cuenta, 
                   cod_ente, 
                   fug_obt_can_permitidas(nro_cuenta, cod_tas_pro_atm, 'CAN_MAX_EXT_PRO_ATM') can_max_ext_pro_atm, 
                   SUM(can_ext_pro_atm) can_ext_pro_atm, 
                   fug_obt_can_permitidas(nro_cuenta, cod_tas_otr_atm, 'CAN_MAX_EXT_OTR_ATM') can_max_ext_otr_atm,
                   SUM(can_ext_otr_atm) can_ext_otr_atm 
              FROM (
            SELECT ctas.nro_cuenta,
                   fug_obt_ent_pag_sue(ctas.nro_cuenta) cod_ente,
                   NVL(DECODE(m.cod_banco, 7, 1, 0), 0) can_ext_pro_atm,
                   NVL(DECODE(m.cod_banco, 7, 0, 1), 0) can_ext_otr_atm,
                   (SELECT s.cod_tas_limite FROM ge_mov_sin_costo s WHERE s.cod_gru_transaccion = 51) cod_tas_pro_atm,
                   (SELECT s.cod_tas_limite FROM ge_mov_sin_costo s WHERE s.cod_gru_transaccion = 52) cod_tas_otr_atm
              FROM (SELECT t.nro_cuenta
                      FROM ge_pag_sueldos t
                     WHERE t.fec_proceso BETWEEN v_fec_inicio AND v_fec_fin
                       AND t.nro_cuenta IS NOT NULL
                       AND t.procesado = 'S'
                       AND t.tipo = 'C'
                       AND t.monto > 0
                       --SD-Resoluciones Nro 128-130-131 SDRESOLUCI-3 - Resolucion 131 Cuentas de pago de remuneraciones
                       /*AND NOT EXISTS (SELECT 0
                                         FROM ge_entes e, ba_personas pe
                                        WHERE e.cod_persona = pe.cod_persona
                                          AND pe.cod_persona = v_cod_per_entidad
                                          AND e.cod_ente = t.cod_ente)*/
                     GROUP BY t.nro_cuenta) ctas, ge_cta_clientes c, ba_personas p, 
                     (SELECT h.nro_cuenta, h.cod_banco
                        FROM cc_movimientos_his h
                       WHERE h.fecha BETWEEN v_fec_inicio AND v_fec_fin  
                         AND h.cod_tra_padre IN (382, 375)
                         AND h.reversado = 'N'
                       UNION ALL
                      SELECT a.nro_cuenta, a.cod_banco
                        FROM ah_movimientos_his a
                       WHERE a.fecha BETWEEN v_fec_inicio AND v_fec_fin  
                         AND a.cod_tra_padre IN (382, 375)
                         AND a.reversado = 'N') m
             WHERE ctas.nro_cuenta = c.nro_cuenta
               AND c.relacion    = 'P'
               AND c.cod_persona = p.cod_persona
               AND p.tipo        = 'F' 
               AND m.nro_cuenta  = ctas.nro_cuenta) 
             GROUP BY nro_cuenta, cod_ente, cod_tas_pro_atm, cod_tas_otr_atm));  
   EXCEPTION
     WHEN OTHERS THEN
       v_can_tot_ext_sin_costo := 0;
   END;
   --Promedio de extracciones sin costo
   BEGIN
     SELECT ROUND((SUM(can_ext_pro_atm_sin_cos+can_ext_otr_atm_sin_cos))/COUNT(*)) 
       INTO v_can_ext_sin_cos_prom
       FROM(SELECT nro_cuenta, 
                   cod_ente, 
                   can_max_ext_pro_atm, 
                   can_ext_pro_atm, 
                   CASE WHEN can_max_ext_pro_atm >= can_ext_pro_atm THEN can_ext_pro_atm else can_max_ext_pro_atm END can_ext_pro_atm_sin_cos,
                   can_max_ext_otr_atm,
                   can_ext_otr_atm,
                   CASE WHEN can_max_ext_otr_atm >= can_ext_otr_atm THEN can_ext_otr_atm else can_max_ext_otr_atm END can_ext_otr_atm_sin_cos
              FROM (
            SELECT nro_cuenta, 
                   cod_ente, 
                   fug_obt_can_permitidas(nro_cuenta, cod_tas_pro_atm, 'CAN_MAX_EXT_PRO_ATM') can_max_ext_pro_atm, 
                   SUM(can_ext_pro_atm) can_ext_pro_atm, 
                   fug_obt_can_permitidas(nro_cuenta, cod_tas_otr_atm, 'CAN_MAX_EXT_OTR_ATM') can_max_ext_otr_atm,
                   SUM(can_ext_otr_atm) can_ext_otr_atm 
              FROM (
            SELECT ctas.nro_cuenta,
                   fug_obt_ent_pag_sue(ctas.nro_cuenta) cod_ente,
                   NVL(DECODE(m.cod_banco, 7, 1, 0), 0) can_ext_pro_atm,
                   NVL(DECODE(m.cod_banco, 7, 0, 1), 0) can_ext_otr_atm,
                   (SELECT s.cod_tas_limite FROM ge_mov_sin_costo s WHERE s.cod_gru_transaccion = 51) cod_tas_pro_atm,
                   (SELECT s.cod_tas_limite FROM ge_mov_sin_costo s WHERE s.cod_gru_transaccion = 52) cod_tas_otr_atm
              FROM (SELECT t.nro_cuenta
                      FROM ge_pag_sueldos t
                     WHERE t.fec_proceso BETWEEN v_fec_inicio AND v_fec_fin
                       AND t.nro_cuenta IS NOT NULL
                       AND t.procesado = 'S'
                       AND t.tipo = 'C'
                       AND t.monto > 0
                       --SD-Resoluciones Nro 128-130-131 SDRESOLUCI-3 - Resolucion 131 Cuentas de pago de remuneraciones
                       /*AND NOT EXISTS (SELECT 0
                                         FROM ge_entes e, ba_personas pe
                                        WHERE e.cod_persona = pe.cod_persona
                                          AND pe.cod_persona = v_cod_per_entidad
                                          AND e.cod_ente = t.cod_ente)*/
                     GROUP BY t.nro_cuenta) ctas, ge_cta_clientes c, ba_personas p, 
                     (SELECT h.nro_cuenta, h.cod_banco
                        FROM cc_movimientos_his h
                       WHERE h.fecha BETWEEN v_fec_inicio AND v_fec_fin  
                         AND h.cod_tra_padre IN (382, 375)
                         AND h.reversado = 'N'
                       UNION ALL
                      SELECT a.nro_cuenta, a.cod_banco
                        FROM ah_movimientos_his a
                       WHERE a.fecha BETWEEN v_fec_inicio AND v_fec_fin  
                         AND a.cod_tra_padre IN (382, 375)
                         AND a.reversado = 'N') m
             WHERE ctas.nro_cuenta = c.nro_cuenta
               AND c.relacion    = 'P'
               AND c.cod_persona = p.cod_persona
               AND p.tipo        = 'F' 
               AND m.nro_cuenta  = ctas.nro_cuenta) 
             GROUP BY nro_cuenta, cod_ente, cod_tas_pro_atm, cod_tas_otr_atm));  
   EXCEPTION
     WHEN OTHERS THEN
       v_can_ext_sin_cos_prom := 0;
   END;
   --Número de extracciones de cuentas Remuneraciones
   BEGIN
     SELECT COUNT(*)
       INTO v_can_tot_extraccion
       FROM (SELECT t.nro_cuenta
               FROM ge_pag_sueldos t
              WHERE t.fec_proceso BETWEEN v_fec_inicio AND v_fec_fin
                AND t.nro_cuenta IS NOT NULL
                AND t.procesado = 'S'
                AND t.tipo = 'C'
                AND t.monto > 0
                --SD-Resoluciones Nro 128-130-131 SDRESOLUCI-3 - Resolucion 131 Cuentas de pago de remuneraciones
                /*AND NOT EXISTS (SELECT 0
                                  FROM ge_entes e, ba_personas pe
                                 WHERE e.cod_persona = pe.cod_persona
                                   AND pe.cod_persona = v_cod_per_entidad
                                   AND e.cod_ente = t.cod_ente)*/
              GROUP BY t.nro_cuenta) ctas, ge_cta_clientes c, ba_personas p,
            (SELECT h.nro_cuenta, h.cod_banco
               FROM cc_movimientos_his h
              WHERE h.fecha BETWEEN v_fec_inicio AND v_fec_fin 
                AND h.cod_tra_padre IN (382, 375)
                AND h.reversado = 'N'
              UNION ALL
             SELECT a.nro_cuenta, a.cod_banco
               FROM ah_movimientos_his a
              WHERE a.fecha BETWEEN v_fec_inicio AND v_fec_fin 
                AND a.cod_tra_padre IN (382, 375)
                AND a.reversado = 'N') m
     WHERE ctas.nro_cuenta = c.nro_cuenta
       AND c.relacion    = 'P'
       AND c.cod_persona = p.cod_persona
       AND p.tipo        = 'F'
       AND m.nro_cuenta  = ctas.nro_cuenta;  
   EXCEPTION
     WHEN OTHERS THEN
       v_can_tot_extraccion := 0;
   END; 
   --Número de pagos electrónicos
   BEGIN
     SELECT COUNT(*)
       INTO v_nro_tot_pag_electronico
       FROM (SELECT t.nro_cuenta
               FROM ge_pag_sueldos t
              WHERE t.fec_proceso BETWEEN v_fec_inicio AND v_fec_fin
                AND t.nro_cuenta IS NOT NULL
                AND t.procesado = 'S'
                AND t.tipo = 'C'
                AND t.monto > 0
                --SD-Resoluciones Nro 128-130-131 SDRESOLUCI-3 - Resolucion 131 Cuentas de pago de remuneraciones
                /*AND NOT EXISTS (SELECT 0
                                  FROM ge_entes e, ba_personas pe
                                 WHERE e.cod_persona = pe.cod_persona
                                   AND pe.cod_persona = v_cod_per_entidad
                                   AND e.cod_ente = t.cod_ente)*/
              GROUP BY t.nro_cuenta) ctas, ge_cta_clientes c, ba_personas p, 
            (SELECT h.nro_cuenta, h.cod_banco, h.cod_mod_padre, h.cod_mad_padre, h.cod_tra_padre
               FROM cc_movimientos_his h
              WHERE h.fecha BETWEEN v_fec_inicio AND v_fec_fin  
                AND h.reversado = 'N'
              UNION ALL
             SELECT a.nro_cuenta, a.cod_banco, a.cod_mod_padre, a.cod_mad_padre, a.cod_tra_padre
               FROM ah_movimientos_his a
              WHERE a.fecha BETWEEN v_fec_inicio AND v_fec_fin  
                AND a.reversado = 'N') m, ge_gru_transacciones_det d
      WHERE ctas.nro_cuenta = c.nro_cuenta
        AND c.relacion = 'P'
        AND c.cod_persona = p.cod_persona
        AND p.tipo        = 'F'
        AND m.nro_cuenta = ctas.nro_cuenta
        AND d.cod_gru_transaccion = v_cod_gru_tra_pag_elec
        AND d.cod_modulo = m.cod_mod_padre
        AND d.cod_modalidad = m.cod_mad_padre
        AND d.cod_transaccion = m.cod_tra_padre; 
   EXCEPTION
     WHEN OTHERS THEN
       v_nro_tot_pag_electronico := 0;
   END; 
   -- Costo por Exceso de uso de ATM
   BEGIN
     SELECT MIN(min_cargo), MAX(max_cargo)
       INTO v_cos_min_exc_uso_atm, v_cos_max_exc_uso_atm
       FROM (SELECT t.cod_ente, MAX(t.val_tasa) max_cargo, MIN(t.val_tasa) min_cargo
               FROM ge_tas_fechas t
              WHERE t.cod_tasa in ( 158, 159, 160, 161 )
                AND t.cod_moneda = v_cod_mon_local
                AND t.fec_vigencia <= v_fec_fin
                AND t.val_tasa > 0
                AND t.nro_cuenta IS NULL
              GROUP BY t.cod_ente);
   EXCEPTION
     WHEN OTHERS THEN
       v_cos_min_exc_uso_atm := 0;
       v_cos_max_exc_uso_atm := 0;
   END;
   v_cos_exc_uso_atm_prom := (v_cos_max_exc_uso_atm + v_cos_min_exc_uso_atm)/2;
   -- Cantidad de Transacciones ATM sin costo
   BEGIN
     SELECT 0, MAX(can_max_tra_atm), ROUND(SUM(can_max_tra_atm)/COUNT(*))
       INTO v_can_min_tra_atm_sin_costo, v_can_max_tra_atm_sin_costo, v_can_tra_atm_sin_cos_prom                
       FROM( 
       SELECT cod_ente, CASE WHEN can_max_ext_atm >= can_max_con_atm AND can_max_ext_atm >= can_max_con_ext_atm THEN can_max_ext_atm 
                      WHEN can_max_con_atm > can_max_ext_atm AND can_max_con_atm >= can_max_con_ext_atm THEN can_max_con_atm
                      WHEN can_max_con_ext_atm > can_max_ext_atm AND can_max_con_ext_atm > can_max_con_atm THEN can_max_con_ext_atm
                      ELSE can_max_ext_atm END can_max_tra_atm
            FROM(
          SELECT cod_ente, (can_max_ext_otr_atm+can_max_ext_pro_atm) can_max_ext_atm, (can_max_con_pro_atm+can_max_con_otr_atm) can_max_con_atm, 
                 can_max_con_ext_atm 
            FROM(     
          SELECT ctas.cod_ente, 
                 NVL(fug_obt_parentes(ctas.cod_ente, 'CAN_MAX_EXT_OTR_ATM'), 0) can_max_ext_otr_atm, 
                 NVL(fug_obt_parentes(ctas.cod_ente, 'CAN_MAX_EXT_PRO_ATM'), 0) can_max_ext_pro_atm,
                 NVL(fug_obt_parentes(ctas.cod_ente, 'CAN_MAX_CON_PRO_ATM'), 0) can_max_con_pro_atm,
                 NVL(fug_obt_parentes(ctas.cod_ente, 'CAN_MAX_CON_OTR_ATM'), 0) can_max_con_otr_atm,
                 TO_NUMBER(NVL(fug_obt_parentes(ctas.cod_ente, 'CAN_MAX_CON_EXT_ATM'), 0)) can_max_con_ext_atm
            FROM (SELECT t.cod_ente, t.nro_cuenta
                    FROM ge_pag_sueldos t
                   WHERE t.fec_proceso BETWEEN v_fec_inicio AND v_fec_fin
                     AND t.nro_cuenta IS NOT NULL
                     AND t.procesado = 'S'
                     AND t.tipo = 'C'
                     AND t.monto > 0
                     --SD-Resoluciones Nro 128-130-131 SDRESOLUCI-3 - Resolucion 131 Cuentas de pago de remuneraciones
                     /*AND NOT EXISTS (SELECT 0
                                       FROM ge_entes e, ba_personas pe
                                      WHERE e.cod_persona = pe.cod_persona
                                        AND pe.cod_persona = v_cod_per_entidad
                                        AND e.cod_ente = t.cod_ente)*/
                   GROUP BY t.cod_ente, t.nro_cuenta) ctas,
                 ge_cta_clientes c,
                 ba_personas p
           WHERE ctas.nro_cuenta = c.nro_cuenta
             AND c.relacion = 'P'
             AND c.cod_persona = p.cod_persona
             AND p.tipo = 'F'
           GROUP BY ctas.cod_ente)
           WHERE can_max_ext_otr_atm < 999
             AND can_max_ext_pro_atm < 999
             AND can_max_con_pro_atm < 999
             AND can_max_con_otr_atm < 999
             AND can_max_con_ext_atm < 999));                              
   EXCEPTION 
     WHEN OTHERS THEN
       v_can_min_tra_atm_sin_costo := 0;
       v_can_max_tra_atm_sin_costo := 0;
       v_can_tra_atm_sin_cos_prom  := 0;
   END;
   -- Inserción en la tabla de datos de remuneraciones
   BEGIN
     INSERT INTO sb_dat_remuneraciones(mes, ano, can_tot_cuenta, sal_tot_cuenta, can_tot_ente, can_tot_cliente, 
                                       can_ext_sin_cos_prom, can_tot_extraccion, nro_tot_pag_electronico, 
                                       cos_min_exc_uso_atm, cos_max_exc_uso_atm, cos_exc_uso_atm_prom, 
                                       can_max_tra_atm_sin_costo, can_min_tra_atm_sin_costo, 
                                       can_tra_atm_sin_cos_prom, can_tot_ext_sin_costo)
                         VALUES(p_mes, p_ano, v_can_tot_cuenta, v_sal_tot_cuenta, v_can_tot_ente, v_can_tot_cliente,
                                v_can_ext_sin_cos_prom, v_can_tot_extraccion, v_nro_tot_pag_electronico, 
                                v_cos_min_exc_uso_atm, v_cos_max_exc_uso_atm, v_cos_exc_uso_atm_prom,
                                v_can_max_tra_atm_sin_costo, v_can_min_tra_atm_sin_costo, 
                                v_can_tra_atm_sin_cos_prom, v_can_tot_ext_sin_costo);
   EXCEPTION
     WHEN OTHERS THEN
       RAISE_APPLICATION_ERROR(-20001, 'Error al insertar los datos en la tabla de datos de remuneraciones. - '||sqlerrm);
   END;                                                
END;
/

