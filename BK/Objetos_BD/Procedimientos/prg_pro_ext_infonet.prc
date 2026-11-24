CREATE OR REPLACE PROCEDURE IT.PRG_PRO_EXT_INFONET (p_reproceso IN VARCHAR2 DEFAULT NULL) IS
   v_fecha         ge_movimientos.fecha%TYPE;
   v_hora          ge_movimientos.hora%TYPE;
   v_cod_usuario   ge_movimientos.cod_usuario%TYPE;
   v_cod_mod_padre ge_movimientos.cod_mod_padre%TYPE;
   v_cod_mad_padre ge_movimientos.cod_mad_padre%TYPE;
   v_cod_tra_padre ge_movimientos.cod_tra_padre%TYPE;
   v_reversado     ge_movimientos.reversado%TYPE;
   v_fec_proceso   ge_mov_inf_cobranzas.fec_pro_extorno%TYPE := trunc(SYSDATE);
   v_actualiza     VARCHAR2(1) := 'N';
   v_det_error     ge_log_ext_infonet.det_error%TYPE;
   v_error         EXCEPTION;
   v_cnt_cobranza  NUMBER(3);
   /*
   || DYDMR-1430 ATM- Sobrante de 100.000 gs 488 Casa Matriz SC 11658
   || Se automatiza el reproceso de los logs con error
   */
   v_ult_fec_proceso DATE;
   v_fec_ant_hab     DATE;
   v_est_modulo      ba_modulos.estado%TYPE;
   vp_cta_debito     VARCHAR2(10);
   vp_bco_debito     VARCHAR2(3);
   vp_cta_credito    VARCHAR2(10);
   vp_bco_credito    VARCHAR2(3);
   vp_operacion      VARCHAR2(2);
   vp_extorno        VARCHAR2(2);
   vp_transaccion    VARCHAR2(15);
   vp_importe        NUMBER(15);
   vp_moneda         VARCHAR2(2);
   vp_fecha          DATE;
   vp_hora           VARCHAR2(8);
   v_hor_referencia  varchar2(8);
   v_fec_log         date        :=trunc(sysdate); --DYDMR-8153
   v_can_dia_rev_bw  number(3) := fug_obt_pardinamico( 'CAN_DIA_REV_BW');
   CURSOR c_reproceso is
   SELECT mensaje
     FROM log_atm tabla
    WHERE substr(mensaje, 29, 2) = '99'
      AND substr(respuesta, 1, 2) NOT IN ('11', '14')
      AND fec_insercion >= v_fec_ant_hab
      AND reprocesado = 'N';
   -- Cursor de Movimientos Extornados
   CURSOR c_extornos IS
      SELECT t.fecha,
             t.hora,
             substr(t.nro_documento, -7) nro_documento,
             t.monto,
             t.mto_comision,
             t.cod_moneda,
             t.cod_operacion,
             to_number(t.nro_documento) nro_doc_infonet,
             t.nro_cta_debito,
             t.cod_bco_debito,
             t.nro_cta_credito,
             t.cod_bco_credito,
             cod_bco_atm,
             nro_atm,
             negocio,
             dat_adicional
        FROM ge_ext_infonet_tmp t
       WHERE /*t.cod_extorno = '99'*/
      -- esta parte se agrega solo para la primera ejecución, luego de esto hay que sacar esto
      -- estos numeros de documento ya se procesaron manualmente por ende no se deben tener en cuenta para el primer proceso
       /*and*/
        to_number(t.nro_documento) NOT IN
       (515759481, 521347917, 524000595, 524001197, 524002454, 524003680, 524004335, 524006916,
        524009264, 524009660, 524010286, 524010890, 524011895, 524012027, 524012414, 526337857,
        529858751, 531546534)
        FOR UPDATE NOWAIT; -- Para bloquear si se ejecuta en forma manual al mismo tiempo
          
   -- Reversion de pago de servicios
   CURSOR c_ext_pag_ser IS
      SELECT to_char(S.NRO_TRANSACCION) nro_transaccion, S.NRO_LOTE, S.NRO_CUENTA
        FROM BW_PAG_SERVICIOS S, LOG_ATM_EXTORNOS E
        WHERE TRUNC(S.FECHA) BETWEEN v_fec_proceso - v_can_dia_rev_bw AND v_fec_proceso 
        AND S.NRO_TRANSACCION = to_char(E.NRO_TRANSACCION)
        AND S.COD_PROVEEDOR = 4
        AND NVL(S.REVERSADO,'N') = 'N'; -- Para bloquear si se ejecuta en forma manual al mismo tiempo
   -------------------------------------------------------------------------------------------
   -- Cursor Infonet Cobranzas
   CURSOR c_cobranzas
   (
      p_nro_documento VARCHAR2,
      p_monto         NUMBER,
      p_cod_moneda    VARCHAR2
   ) IS
      SELECT DISTINCT fecha,
                      hora,
                      cod_usuario,
                      cod_mod_padre,
                      cod_mad_padre,
                      cod_tra_padre,
                      reversado,
                      nro_documento
        FROM (SELECT fecha,
                     hora,
                     cod_usuario,
                     cod_mod_padre,
                     cod_mad_padre,
                     cod_tra_padre,
                     reversado,
                     nro_documento
                FROM cc_movimientos_his g
               WHERE g.nro_documento = to_number(p_nro_documento)
                 AND g.monto = p_monto
                 AND g.cod_moneda = p_cod_moneda
                 AND g.cod_tra_padre IN (996, 227, 238) -- CANOSTDD-2 -- 01/2017 --
                 AND nvl(g.monto, 0) > 0
                 AND g.fecha >= v_fec_ant_hab -- Optimizacion DYDMR-1430 ATM
                 AND NOT EXISTS (SELECT 1
                        FROM cc_movimientos_his e
                       WHERE e.nro_documento = g.nro_documento
                         AND e.cod_moneda = g.cod_moneda
                         AND g.cod_tra_padre IN (996, 227, 238) -- CANOSTDD-2 -- 01/2017 --
                         AND nvl(e.monto, 0) < 0)
                 AND NOT EXISTS (SELECT 1 -- DYDMR-4088 Julio/2016
                       FROM ge_movimientos e
                      WHERE e.nro_documento = g.nro_documento
                        AND e.nro_documento3 = g.nro_documento3
                        AND e.cod_moneda = g.cod_moneda
                        AND nvl(e.monto, 0) < 0)
                 AND NOT EXISTS (SELECT 1 -- DYDMR-4088 Julio/2016
                       FROM ge_movimientos_noc e
                      WHERE e.nro_documento = g.nro_documento
                        AND e.nro_documento3 = g.nro_documento3
                        AND e.cod_moneda = g.cod_moneda
                        AND nvl(e.monto, 0) < 0)
              UNION ALL
              SELECT fecha,
                     hora,
                     cod_usuario,
                     cod_mod_padre,
                     cod_mad_padre,
                     cod_tra_padre,
                     reversado,
                     nro_documento
                FROM ah_movimientos_his g
               WHERE g.nro_documento = to_number(p_nro_documento)
                 AND g.monto = p_monto
                 AND g.cod_moneda = p_cod_moneda
                 AND g.cod_tra_padre IN (996, 227, 238)  -- CANOSTDD-2 -- 01/2017 --
                 AND nvl(g.monto, 0) > 0
                 AND NOT EXISTS (SELECT 1
                        FROM ah_movimientos_his e
                       WHERE e.nro_documento = g.nro_documento
                         AND e.cod_moneda = g.cod_moneda
                         AND g.cod_tra_padre IN (996, 227, 238) -- CANOSTDD-2 -- 01/2017 --
                         AND nvl(e.monto, 0) < 0)
                 AND NOT EXISTS (SELECT 1 -- DYDMR-4088 Julio/2016
                       FROM ge_movimientos e
                      WHERE e.nro_documento = g.nro_documento
                        AND e.nro_documento3 = g.nro_documento3
                        AND e.cod_moneda = g.cod_moneda
                        AND nvl(e.monto, 0) < 0)
                 AND NOT EXISTS (SELECT 1 -- DYDMR-4088 Julio/2016
                       FROM ge_movimientos_noc e
                      WHERE e.nro_documento = g.nro_documento
                        AND e.nro_documento3 = g.nro_documento3
                        AND e.cod_moneda = g.cod_moneda
                        AND nvl(e.monto, 0) < 0)
              UNION ALL
              SELECT fecha,
                     hora,
                     cod_usuario,
                     cod_mod_padre,
                     cod_mad_padre,
                     cod_tra_padre,
                     reversado,
                     nro_documento
                FROM ta_movimientos_his g
               WHERE g.nro_documento = to_number(p_nro_documento)
                 AND g.monto = p_monto
                 AND g.cod_moneda = p_cod_moneda
                 AND g.cod_tra_padre IN (996, 227, 238) -- CANOSTDD-2 -- 01/2017 --
                 AND nvl(g.monto, 0) > 0
                 AND g.fecha >= v_fec_ant_hab -- Optimizacion DYDMR-1430 ATM
                 AND NOT EXISTS (SELECT 1
                        FROM ah_movimientos_his e
                       WHERE e.nro_documento = g.nro_documento
                         AND e.cod_moneda = g.cod_moneda
                         AND g.cod_tra_padre IN (996, 227, 238)  -- CANOSTDD-2 -- 01/2017 --
                         AND nvl(e.monto, 0) < 0)
                 AND NOT EXISTS (SELECT 1 -- DYDMR-4088 Julio/2016
                       FROM ge_movimientos e
                      WHERE e.nro_documento = g.nro_documento
                        AND e.nro_documento3 = g.nro_documento3
                        AND e.cod_moneda = g.cod_moneda
                        AND nvl(e.monto, 0) < 0)
                 AND NOT EXISTS (SELECT 1 -- DYDMR-4088 Julio/2016
                       FROM ge_movimientos_noc e
                      WHERE e.nro_documento = g.nro_documento
                        AND e.nro_documento3 = g.nro_documento3
                        AND e.cod_moneda = g.cod_moneda
                        AND nvl(e.monto, 0) < 0));

   /* DYDMR-4088 Julio/2016 : Reversa Operación Infonet */
   PROCEDURE pl_rev_ope_atm(p_fecha           IN ge_movimientos.fecha%TYPE,
                             p_hora            IN ge_movimientos.hora%TYPE,
                             p_cod_usuario     IN ge_movimientos.cod_usuario%TYPE,
                             p_cod_mod_padre   IN ge_movimientos.cod_mod_padre%TYPE,
                             p_cod_mad_padre   IN ge_movimientos.cod_mad_padre%TYPE,
                             p_cod_tra_padre   IN ge_movimientos.cod_tra_padre%TYPE,
                             p_nro_doc_infonet IN ge_movimientos.nro_documento3%TYPE,
                             p_nro_documento   IN ge_movimientos.nro_documento%TYPE,
                             p_monto           IN ge_movimientos.monto%TYPE,
                             p_cod_moneda      IN ge_movimientos.cod_moneda%TYPE,
                             p_actualiza       IN OUT varchar2,
                             p_det_error       OUT varchar2) IS
     PRAGMA AUTONOMOUS_TRANSACTION;
     v_hor_reversion ge_movimientos.hor_reversion%TYPE := to_char(SYSDATE,'hh24:mi:ss');
     v_actualiza     VARCHAR2(1);
   BEGIN
     BEGIN
       v_actualiza := p_actualiza;

       v_hor_reversion := fug_obt_hor_disponible(p_fecha, v_hor_reversion, p_cod_usuario, 'N');
       --
       prg_rev_operacion(p_fecha,
                         p_hora,
                         p_cod_usuario,
                         p_cod_mod_padre,
                         p_cod_mad_padre,
                         p_cod_tra_padre,
                         USER,
                         v_hor_reversion,
                         'N',
                         'Proceso Extorno ' || p_nro_doc_infonet,
                         p_nro_documento);
         COMMIT;
     EXCEPTION
       WHEN OTHERS THEN
         -- en caso de error de prueba reversión en orden inversa de movimiento
         ROLLBACK;
         BEGIN
           v_hor_reversion := fug_obt_hor_disponible(p_fecha, v_hor_reversion, p_cod_usuario, 'N');
           --
           prg_rev_operacion(p_fecha,
                             p_hora,
                             p_cod_usuario,
                             p_cod_mod_padre,
                             p_cod_mad_padre,
                             p_cod_tra_padre,
                             USER,
                             v_hor_reversion,
                             'N',
                             'Proceso Extorno ' || p_nro_doc_infonet,
                             p_nro_documento,
                             'ASC');
           COMMIT;
         EXCEPTION
           WHEN OTHERS THEN
             p_det_error := SQLERRM;
             p_det_error := substr(p_det_error,1,1000);
             v_actualiza := 'N';
             ROLLBACK;
             INSERT INTO ge_log_ext_infonet
               (fecha,
                hora,
                cod_usuario,
                det_error,
                nro_documento,
                monto,
                cod_moneda)
             VALUES
               (p_fecha,
                p_hora,
                p_cod_usuario,
                p_det_error,
                p_nro_doc_infonet,
                p_monto,
                p_cod_moneda);
             COMMIT; -- se comitea el registro de log
         END;
     END;
     p_actualiza := v_actualiza;
   END;

   /* DYDMR-2764 Julio/2016 : Actualiza Movimiento Infonet Cobranzas */
   PROCEDURE pl_act_inf_cobranzas (p_fecha         IN ge_mov_inf_cobranzas.fecha%TYPE,
                                    p_nro_documento IN ge_mov_inf_cobranzas.nro_documento%TYPE
                                    ) IS
     PRAGMA AUTONOMOUS_TRANSACTION;
     v_fecha ge_mov_inf_cobranzas.fecha%TYPE := NULL;
     v_hora  ge_mov_inf_cobranzas.hora%TYPE := NULL;
   BEGIN
     BEGIN
        -- Busca el Movimiento en Infonet Cobranzas
        SELECT DISTINCT fecha, hora
          INTO v_fecha, v_hora
          FROM ge_mov_inf_cobranzas i
         WHERE i.fecha = p_fecha
           AND i.nro_documento = p_nro_documento
           AND i.reversado = 'N';
           --AND i.liberado = 'S'; -- DYDMR-2764 Julio/2016
     EXCEPTION
           WHEN OTHERS THEN
                v_fecha := NULL;
                v_hora  := NULL;
     END;
     IF v_fecha IS NOT NULL THEN
        UPDATE ge_mov_inf_cobranzas
           SET reversado       = 'S',
           fec_pro_extorno = v_fec_proceso
        WHERE fecha = v_fecha
           AND hora = v_hora
           AND nro_documento = p_nro_documento;
        COMMIT;
      END IF;
   END;

    procedure lp_ins_log_extornos (p_nro_doc_infonet number) is
       PRAGMA AUTONOMOUS_TRANSACTION;
     Begin
       begin
         insert into LOG_ATM_EXTORNOS(NRO_TRANSACCION) values(p_nro_doc_infonet);
         commit;
       exception
         -- si salta error PK es por que ya existe extorno pero fallaron controles iniciales
         -- en se impide que continue el extorno
         when DUP_VAL_ON_INDEX then
           v_actualiza := 'N';
           v_det_error := 'Extorno Duplicado';
         when others then
           v_actualiza := 'N';
           v_det_error := 'Error al querer ingresar el log del Extorno';
       end;
     End lp_ins_log_extornos;

BEGIN
   v_est_modulo := pae_cnf.FU_OBT_EST_MODULO(1);
   IF nvl(v_est_modulo,0) = 2 THEN
      prg_act_log_procesos('PRG_PRO_EXT_INFONET','VERIFICACIONES-INI', v_fec_log, to_char(sysdate,'hh24:mi:ss'), to_char(sysdate,'hh24:mi:ss'));--DYDMR-8153
      IF nvl(p_reproceso,'N') = 'S' THEN
         BEGIN
            SELECT MAX(fec_insercion)
              INTO v_ult_fec_proceso
              FROM log_atm tabla
             WHERE substr(mensaje, 29, 2) = '99'
               AND substr(respuesta, 1, 2) NOT IN ('11', '14')
               AND reprocesado = 'S';
         EXCEPTION
            WHEN OTHERS THEN
               v_ult_fec_proceso := pag_cal.FU_OBT_FEC_ACTUAL(1);
         END;
         IF v_ult_fec_proceso IS NULL THEN
            v_ult_fec_proceso := pag_cal.FU_OBT_FEC_ACTUAL(1);
         END IF;
         v_fec_ant_hab := pag_cal.FU_OBT_FEC_ANT_HAB(trunc(v_ult_fec_proceso),1);
         prg_act_log_procesos('PRG_PRO_EXT_INFONET','VERIFICACIONES-FIN', v_fec_log, to_char(sysdate,'hh24:mi:ss'), to_char(sysdate,'hh24:mi:ss'));--DYDMR-8153
         ---
         prg_act_log_procesos('PRG_PRO_EXT_INFONET','TRUNCATE_TABLE-INI', v_fec_log, to_char(sysdate,'hh24:mi:ss'), to_char(sysdate,'hh24:mi:ss'));--DYDMR-8153
         EXECUTE IMMEDIATE 'truncate table ge_ext_infonet_tmp';
         prg_act_log_procesos('PRG_PRO_EXT_INFONET','TRUNCATE_TABLE-FIN', v_fec_log, to_char(sysdate,'hh24:mi:ss'), to_char(sysdate,'hh24:mi:ss'));--DYDMR-8153

         prg_act_log_procesos('PRG_PRO_EXT_INFONET','C_REPROCESO-INI', v_fec_log, to_char(sysdate,'hh24:mi:ss'), to_char(sysdate,'hh24:mi:ss'));--DYDMR-8153
         FOR i IN c_reproceso LOOP
            vp_cta_debito  := to_char(to_number(substr(i.mensaje, 1, 10)));
            vp_bco_debito  := substr(i.mensaje, 11, 3);
            vp_cta_credito := to_char(to_number(substr(i.mensaje, 14, 10)));
            vp_bco_credito := substr(i.mensaje, 24, 3);
            vp_operacion   := substr(i.mensaje, 27, 2);
            vp_extorno     := substr(i.mensaje, 29, 2);
            vp_transaccion := substr(i.mensaje, 46, 15);
            vp_importe     := to_number(substr(i.mensaje, 61, 15))/100;
            vp_moneda      := substr(i.mensaje, 110, 2);
            BEGIN
               vp_fecha := to_date(substr(i.mensaje, 182, 8), 'ddmmyyyy');
            EXCEPTION
               WHEN OTHERS THEN
                  BEGIN
                     vp_fecha := to_date(substr(i.mensaje, 181, 8), 'ddmmyyyy');
                  EXCEPTION
                     WHEN OTHERS THEN
                        vp_fecha := v_fec_ant_hab;
                  END;
            END;
            BEGIN
               vp_hora := to_char(to_date(substr(i.mensaje, 190, 6), 'hh24miss'), 'hh24:mi:ss');
            EXCEPTION
               WHEN OTHERS THEN
                  BEGIN
                     vp_hora := to_char(to_date(substr(i.mensaje, 189, 6), 'hh24miss'), 'hh24:mi:ss');
                  EXCEPTION
                     WHEN OTHERS THEN
                        vp_hora := substr(i.mensaje, 190, 6);
                  END;
            END;
            IF vp_moneda = '00' THEN
               vp_moneda := 'GS';
            ELSE
               vp_moneda := 'USD';
            END IF;
            BEGIN
               INSERT INTO ge_ext_infonet_tmp (nro_cta_debito, cod_bco_debito, nro_cta_credito, cod_bco_credito,
                                               cod_operacion, cod_extorno, nro_documento, monto,
                                               cod_moneda, fecha, hora)
               VALUES (
               vp_cta_debito,
               vp_bco_debito,
               vp_cta_credito,
               vp_bco_credito,
               vp_operacion,
               vp_extorno,
               vp_transaccion,
               vp_importe,
               vp_moneda,
               vp_fecha,
               vp_hora);
            EXCEPTION
               WHEN OTHERS THEN
                  NULL;
            END;
         END LOOP;
         COMMIT;
         prg_act_log_procesos('PRG_PRO_EXT_INFONET','C_REPROCESO-FIN', v_fec_log, to_char(sysdate,'hh24:mi:ss'), to_char(sysdate,'hh24:mi:ss'));--DYDMR-8153
      ELSE
         --- Proceso manual
         BEGIN
            SELECT MIN(fecha)
              INTO v_ult_fec_proceso
              FROM ge_ext_infonet_tmp tabla;
         EXCEPTION
            WHEN OTHERS THEN
               v_ult_fec_proceso := pag_cal.FU_OBT_FEC_ACTUAL(1);
         END;
         IF v_ult_fec_proceso IS NULL THEN
            v_ult_fec_proceso := pag_cal.FU_OBT_FEC_ACTUAL(1);
         END IF;
         v_fec_ant_hab := pag_cal.FU_OBT_FEC_ANT_HAB(v_ult_fec_proceso,1);
      END IF;

      ---
      prg_act_log_procesos('PRG_PRO_EXT_INFONET','C_EXTORNOS-INI', v_fec_log, to_char(sysdate,'hh24:mi:ss'), to_char(sysdate,'hh24:mi:ss'));--DYDMR-8153
      FOR reg IN c_extornos LOOP
         v_det_error := NULL;
         -- Verifica si el movimento existe y no tiene extorno
         IF reg.cod_operacion <> 72 THEN
            BEGIN
               SELECT DISTINCT fecha,
                               hora,
                               cod_usuario,
                               cod_mod_padre,
                               cod_mad_padre,
                               cod_tra_padre,
                               reversado
                 INTO v_fecha,
                      v_hora,
                      v_cod_usuario,
                      v_cod_mod_padre,
                      v_cod_mad_padre,
                      v_cod_tra_padre,
                      v_reversado
                 FROM (SELECT fecha,
                              hora,
                              cod_usuario,
                              cod_mod_padre,
                              cod_mad_padre,
                              cod_tra_padre,
                              reversado
                         FROM cc_movimientos_his g
                        WHERE g.fec_valor = reg.fecha
                          AND g.nro_documento = to_number(reg.nro_documento)
                          AND g.monto = reg.monto
                          AND g.cod_moneda = reg.cod_moneda
                          AND substr(g.cod_usuario,1,3) = 'ATM'
                          AND g.cod_tra_padre <> 309
                          AND nvl(g.monto, 0) > 0
                          AND g.fecha >= v_fec_ant_hab -- Optimizacion DYDMR-1430 ATM
                          AND NOT EXISTS (SELECT 1
                                 FROM cc_movimientos_his e
                                WHERE e.fec_valor = g.fec_valor
                                  AND e.nro_documento = g.nro_documento
                                  AND e.cod_moneda = g.cod_moneda
                                  AND substr(e.cod_usuario,1,3) = substr(g.cod_usuario,1,3)
                                  AND e.cod_tra_padre <> 309
                                  AND nvl(e.monto, 0) < 0)
                          AND NOT EXISTS (SELECT 1 -- DYDMR-4088 Julio/2016
                                 FROM ge_movimientos e
                                WHERE e.nro_documento = g.nro_documento
                                  AND e.nro_documento3 = g.nro_documento3
                                  AND e.cod_moneda = g.cod_moneda
                                  AND e.cod_tra_padre <> 309
                                  AND nvl(e.monto, 0) < 0)
                           AND NOT EXISTS (SELECT 1 -- DYDMR-4088 Julio/2016
                                 FROM ge_movimientos_noc e
                                WHERE e.nro_documento = g.nro_documento
                                  AND e.nro_documento3 = g.nro_documento3
                                  AND e.cod_moneda = g.cod_moneda
                                  AND e.cod_tra_padre <> 309
                                  AND nvl(e.monto, 0) < 0)
                       UNION ALL
                       SELECT fecha,
                              hora,
                              cod_usuario,
                              cod_mod_padre,
                              cod_mad_padre,
                              cod_tra_padre,
                              reversado
                         FROM ah_movimientos_his g
                        WHERE g.fec_valor = reg.fecha
                          AND g.nro_documento = to_number(reg.nro_documento)
                          AND g.monto = reg.monto
                          AND g.cod_moneda = reg.cod_moneda
                          AND substr(g.cod_usuario,1,3) = 'ATM'
                          AND g.cod_tra_padre <> 309
                          AND nvl(g.monto, 0) > 0
                          AND g.fecha >= v_fec_ant_hab -- Optimizacion DYDMR-1430 ATM
                          AND NOT EXISTS (SELECT 1
                                 FROM ah_movimientos_his e
                                WHERE e.fec_valor = g.fec_valor
                                  AND e.nro_documento = g.nro_documento
                                  AND e.cod_moneda = g.cod_moneda
                                  AND substr(e.cod_usuario,1,3) = substr(g.cod_usuario,1,3)
                                  AND e.cod_tra_padre <> 309
                                  AND nvl(e.monto, 0) < 0)
                          AND NOT EXISTS (SELECT 1 -- DYDMR-4088 Julio/2016
                                 FROM ge_movimientos e
                                WHERE e.nro_documento = g.nro_documento
                                  AND e.nro_documento3 = g.nro_documento3
                                  AND e.cod_moneda = g.cod_moneda
                                  AND e.cod_tra_padre <> 309
                                  AND nvl(e.monto, 0) < 0)
                          AND NOT EXISTS (SELECT 1 -- DYDMR-4088 Julio/2016
                                 FROM ge_movimientos_noc e
                                WHERE e.nro_documento = g.nro_documento
                                  AND e.nro_documento3 = g.nro_documento3
                                  AND e.cod_moneda = g.cod_moneda
                                  AND e.cod_tra_padre <> 309
                                  AND nvl(e.monto, 0) < 0));
               --
               IF nvl(v_reversado, 'N') = 'S' THEN
                  RAISE v_error;
               END IF;
               --
               v_actualiza := 'S';
            EXCEPTION
               WHEN no_data_found THEN
                  v_fecha       := NULL;
                  v_hora        := NULL;
                  v_cod_usuario := NULL;
                  v_actualiza   := 'N';
                  v_det_error   := 'No existe Movimiento para la fecha ' || reg.fecha;
                  INSERT INTO ge_log_ext_infonet
                     (fecha, hora, cod_usuario, det_error, nro_documento, monto, cod_moneda)
                  VALUES
                     (reg.fecha, NULL, NULL, v_det_error, reg.nro_doc_infonet, reg.monto,
                      reg.cod_moneda);
               WHEN v_error THEN
                  NULL;
                  v_actualiza   := 'N'; -- DYDMR-4088 Julio/2016
               WHEN OTHERS THEN
                  raise_application_error(-20000, 'Error al Buscar Movimiento. ' || SQLERRM);
            END;
            -- Si existe el movimiento hace la reversión del mismo.
            IF v_actualiza = 'S' THEN
               -- DYDMR-4088 Julio/2016
               if nvl(p_reproceso, 'N') = 'N' and v_cod_tra_padre in (996, 227, 238, 380, 381, 488) then -- infonet cobrazas
                  v_hor_referencia := substr(reg.hora, 1, 2)||':'||substr(reg.hora,3,2)||':'||substr(reg.hora,5,2);
                  prg_rev_inf_cobranza(v_hor_referencia, v_cod_mod_padre,v_cod_mad_padre,v_cod_tra_padre,
                                       reg.nro_doc_infonet,reg.nro_documento,reg.monto,reg.mto_comision, reg.cod_moneda,
                                       reg.nro_cta_debito, reg.cod_bco_debito, reg.nro_cta_credito, reg.cod_bco_credito, reg.cod_bco_atm, reg.nro_atm,
                                       reg.negocio, reg.dat_adicional, reg.cod_operacion, v_actualiza,v_det_error);
                  if v_det_error is not null then
                     v_actualiza := 'N';
                       INSERT INTO ge_log_ext_infonet
                          (fecha, hora, cod_usuario, det_error, nro_documento, monto, cod_moneda)
                       VALUES
                          (reg.fecha, NULL, user, v_det_error, reg.nro_doc_infonet, reg.monto, reg.cod_moneda);
	                end if;

               else
                  lp_ins_log_extornos(reg.nro_doc_infonet);
                  if nvl(v_actualiza, 'N') = 'S' then
                    pl_rev_ope_atm(v_fecha,v_hora,v_cod_usuario,v_cod_mod_padre,v_cod_mad_padre,v_cod_tra_padre,
                                    reg.nro_doc_infonet,reg.nro_documento,reg.monto,reg.cod_moneda,v_actualiza,v_det_error);
                    if v_det_error is null then
                      declare
                        v_nro_cta_tra ge_cuentas.nro_cuenta%type;
                        v_nro_cta_credito ge_cuentas.nro_cuenta%type;
                        v_nro_cta_debito ge_cuentas.nro_cuenta%type;
                        v_tip_cuenta varchar2(2);
                        v_cod_modulo ge_cuentas.cod_modulo%type;
                        v_cod_modalidad ge_cuentas.cod_modalidad%type;
                        v_cod_sub_modalidad ge_cuentas.cod_sub_modalidad%type := 1;
                        v_nro_cta_transaccional ge_cuentas.nro_cuenta%type;
                        v_nro_secuencia varchar2(1);
                      begin
                        if reg.nro_cta_credito is not null and to_number(reg.cod_bco_credito) = 7  then
                           v_nro_cta_credito := substr('0000000000'||trim(reg.nro_cta_credito),-10);
                           v_tip_cuenta := substr(v_nro_cta_credito,4,1);
                           if v_tip_cuenta in ('1','3') then
                              v_tip_cuenta := '01';
                              v_nro_cta_credito := substr(v_nro_cta_credito,2,2)||v_tip_cuenta||substr(v_nro_cta_credito, -6);
                           elsif v_tip_cuenta in ('2','4') then
                              v_tip_cuenta := '02';
                              v_nro_cta_credito := substr(v_nro_cta_credito,2,2)||v_tip_cuenta||substr(v_nro_cta_credito, -6);
                           end if;
                           begin
                             select cod_modulo, cod_modalidad, cod_sub_modalidad
                               into v_cod_modulo, v_cod_modalidad, v_cod_sub_modalidad
                               from ge_cuentas
                              where nro_cuenta = v_nro_cta_credito;
                           exception
                             when others then
                               v_cod_sub_modalidad := 1;
                           end;
                        end if;
                        if v_cod_sub_modalidad <> 25 then
                          if reg.nro_cta_debito is not null and to_number(reg.cod_bco_debito) = 7  then
                             v_nro_cta_debito := substr('0000000000'||trim(v_nro_cta_debito),-10);
                             v_tip_cuenta := substr(v_nro_cta_debito,4,1);
                             if v_tip_cuenta in ('1','3') then
                                v_tip_cuenta := '01';
                                v_nro_cta_debito := substr(v_nro_cta_debito,2,2)||v_tip_cuenta||substr(v_nro_cta_debito, -6);
                             elsif v_tip_cuenta in ('2','4') then
                                v_tip_cuenta := '02';
                                v_nro_cta_debito := substr(v_nro_cta_debito,2,2)||v_tip_cuenta||substr(v_nro_cta_debito, -6);
                             end if;
                             begin
                                select cod_modulo, cod_modalidad, cod_sub_modalidad
                                  into v_cod_modulo, v_cod_modalidad, v_cod_sub_modalidad
                                  from ge_cuentas
                                 where nro_cuenta = v_nro_cta_credito;
                             exception
                               when others then
                                  v_cod_sub_modalidad := 1;
                             end;
                             if v_cod_sub_modalidad = 25 then
                                v_nro_cta_transaccional := v_nro_cta_debito;
                             end if;
                          end if;
                       else
                          v_nro_cta_transaccional := v_nro_cta_credito;
                       end if;

                       if nvl(v_cod_sub_modalidad,1) = 25 then
                          begin
                             begin
                               select max(nro_secuencia) + 1
                                 into v_nro_secuencia
                                   from ge_mov_dat_adicionales
                                  where fecha = v_fec_proceso
                                    and hora = v_hora
                                    and cod_usuario = user;
                              exception
                                 when others then
                                   v_nro_secuencia := 1;
                              end;
                              insert into ge_mov_dat_adicionales (fecha, fec_valor, cod_usuario, hora, nro_secuencia, hor_referencia,
                                                          cod_modulo, cod_modalidad, nro_cuenta, cod_tra_padre,
                                                          cod_moneda, monto, cod_extorno, nro_documento,
                                                          nro_transaccion, liberado, fec_acreditacion, tip_operacion)
                                                   values(v_fec_proceso, reg.fecha, user, v_hora, nvl(v_nro_secuencia, 1), vp_hora,
                                                          v_cod_modulo, v_cod_modalidad, v_nro_cta_transaccional,v_cod_tra_padre,
                                                          reg.cod_moneda, reg.monto , '99', reg.nro_documento,
                                                          reg.nro_doc_infonet, 'S', v_fec_proceso, 'TRA');
                           exception
                             when others then
                                v_det_error := substr(sqlerrm, 1,4000);
                                insert into ge_mov_dat_adicionales_err (fecha, fec_valor, cod_usuario, hora, nro_secuencia, hor_referencia,
                                                                cod_modulo, cod_modalidad, nro_cuenta, cod_tra_padre,
                                                                cod_moneda, monto, cod_extorno, nro_documento,
                                                                nro_transaccion, liberado, fec_acreditacion, det_error, tip_operacion)
                                                         values(v_fec_proceso, reg.fecha, user, v_hora, nvl(v_nro_secuencia, 1), vp_hora,
                                                                v_cod_modulo, v_cod_modalidad, v_nro_cta_transaccional, v_cod_tra_padre,
                                                                reg.cod_moneda, reg.monto , '99', reg.nro_documento,
                                                                reg.nro_doc_infonet, 'S', v_fec_proceso, v_det_error, 'TRA');
                           end;
                        end if;
                     end;
                  end if;
               end if;
              end if;
            END IF;
         ELSE
            prg_act_log_procesos('PRG_PRO_EXT_INFONET','C_COBRANZAS-INI', v_fec_log, to_char(sysdate,'hh24:mi:ss'), to_char(sysdate,'hh24:mi:ss'));--DYDMR-8153
            v_cnt_cobranza := 0;
            FOR c IN c_cobranzas(reg.nro_documento, reg.monto, reg.cod_moneda) LOOP
               --
               IF nvl(c.reversado, 'N') = 'N' THEN
                  v_actualiza := 'S';
                  -- DYDMR-4088 Julio/2016
                  v_hor_referencia := substr(reg.hora, 1, 2)||':'||substr(reg.hora,3,2)||':'||substr(reg.hora,5,2);
                  prg_rev_inf_cobranza(v_hor_referencia,c.cod_mod_padre,c.cod_mad_padre,c.cod_tra_padre,
                                       reg.nro_doc_infonet,c.nro_documento,reg.monto, reg.mto_comision, reg.cod_moneda,
                                       reg.nro_cta_debito, reg.cod_bco_debito, reg.nro_cta_credito, reg.cod_bco_credito, reg.cod_bco_atm, reg.nro_atm, reg.negocio, reg.dat_adicional,
                                       reg.cod_operacion, v_actualiza,v_det_error);

                  if v_det_error is not null then
                     v_actualiza := 'N';
                       INSERT INTO ge_log_ext_infonet
                          (fecha, hora, cod_usuario, det_error, nro_documento, monto, cod_moneda)
                       VALUES
                          (reg.fecha, NULL, user, v_det_error, reg.nro_doc_infonet, reg.monto, reg.cod_moneda);
                  end if;
                  -- Actualiza Movimiento Infonet Cobranzas
                  IF nvl(v_actualiza, 'S') = 'S' THEN
                     v_cnt_cobranza := v_cnt_cobranza + 1;
                     pl_act_inf_cobranzas(reg.fecha,reg.nro_doc_infonet);
                  END IF;
               END IF;
               v_actualiza := 'N';
            END LOOP;
            prg_act_log_procesos('PRG_PRO_EXT_INFONET','C_COBRANZAS-FIN', v_fec_log, to_char(sysdate,'hh24:mi:ss'), to_char(sysdate,'hh24:mi:ss'));--DYDMR-8153
            IF v_cnt_cobranza = 0 THEN
              BEGIN
                UPDATE GE_MOV_INF_COBRANZAS
                   SET REVERSADO = 'S'
                 WHERE NRO_DOCUMENTO = reg.nro_doc_infonet
                   and liberado = 'N'
                   and reversado = 'N';

                if sql%found then
                    v_cnt_cobranza := v_cnt_cobranza + 1;
                end if;
               END;
             END IF;

             IF v_cnt_cobranza = 0 and v_det_error is null then
               v_det_error := 'No existe Movimiento para la fecha ' || reg.fecha;
               INSERT INTO ge_log_ext_infonet
                  (fecha, hora, cod_usuario, det_error, nro_documento, monto, cod_moneda)
               VALUES
                  (reg.fecha, NULL, NULL, v_det_error, reg.nro_doc_infonet, reg.monto, reg.cod_moneda);
            END IF;
         END IF;
      END LOOP;
      prg_act_log_procesos('PRG_PRO_EXT_INFONET','C_EXTORNOS-FIN', v_fec_log, to_char(sysdate,'hh24:mi:ss'), to_char(sysdate,'hh24:mi:ss'));--DYDMR-8153

      prg_act_log_procesos('PRG_PRO_EXT_INFONET','GRABA_MODIFICACIONES-INI', v_fec_log, to_char(sysdate,'hh24:mi:ss'), to_char(sysdate,'hh24:mi:ss'));--DYDMR-8153
      
      FOR e IN c_ext_pag_ser LOOP
        begin
          update bw_pag_servicios
             set reversado = 'S'
           where nro_transaccion = e.nro_transaccion
             and nro_lote = e.nro_lote
             and nro_cuenta = e.nro_cuenta;
        exception
          when others then
             prg_act_log_procesos('PRG_PRO_EXT_INFONET','No se puede reversar el pago de Servicio: '||e.nro_transaccion, v_fec_log, to_char(sysdate,'hh24:mi:ss'), to_char(sysdate,'hh24:mi:ss'));--DYDMR-8153
        end;
     end loop;   
      -- Graba las modificaciones.
      IF nvl(p_reproceso,'N') = 'S' THEN
         UPDATE log_atm
            SET reprocesado = 'S'
          WHERE substr(mensaje, 29, 2) = '99'
            AND substr(respuesta, 1, 2) NOT IN ('11', '14')
            AND fec_insercion >= v_fec_ant_hab
            AND reprocesado = 'N';
         COMMIT;
      END IF;
      prg_act_log_procesos('PRG_PRO_EXT_INFONET','GRABA_MODIFICACIONES-FIN', v_fec_log, to_char(sysdate,'hh24:mi:ss'), to_char(sysdate,'hh24:mi:ss'));--DYDMR-8153
   END IF;
EXCEPTION
   WHEN OTHERS THEN
      raise_application_error(-20000, 'Error al procesar Extornos Bancard: ' || SQLERRM);
END prg_pro_ext_infonet;
/

