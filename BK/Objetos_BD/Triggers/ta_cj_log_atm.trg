CREATE OR REPLACE TRIGGER IT.ta_cj_log_atm
   AFTER INSERT ON "IT"."CJ_LOG_ATM"
   FOR EACH ROW
DECLARE
   v_exi_movi        VARCHAR2(1) := 'N';
   v_gru_reversiones ge_par_dinamicos.val_parametro%TYPE := fug_obt_pardinamico('CJ_GRU_TRA_ATM_REVERSIONES');
   v_fec_proceso     ge_movimientos.fecha%TYPE := pag_cal.fu_obt_fec_actual(3);
   v_fec_anterior    ge_movimientos.fecha%TYPE := pag_cal.fu_obt_fec_ant_hab(v_fec_proceso, NULL, 4);
BEGIN

   IF inserting THEN

      IF substr(:new.respuesta, 1, 2) <> '00' AND :new.cod_extorno = '99' AND
         :new.cod_operacion NOT IN ('02', '06') THEN

         BEGIN
            SELECT DISTINCT 'S'
              INTO v_exi_movi
              FROM ge_movimientos a
             WHERE a.nro_documento = :new.nro_transaccion
               AND (fup_exi_gru_transac(v_gru_reversiones, a.cod_tra_padre, a.cod_mod_padre,
                                        a.cod_mad_padre) = 'S')
               AND NOT EXISTS (SELECT DISTINCT 'S'
                      FROM ge_movimientos
                     WHERE nro_documento = a.nro_documento
                       AND monto < 0
                       AND (fup_exi_gru_transac(v_gru_reversiones, cod_tra_padre,
                                                cod_mod_padre, cod_mad_padre) = 'S'))
               AND NOT EXISTS
             (SELECT DISTINCT 'S'
                      FROM ge_movimientos_noc
                     WHERE nro_documento = a.nro_documento
                       AND monto < 0
                       AND (fup_exi_gru_transac(v_gru_reversiones, cod_tra_padre, cod_mod_padre,
                                                cod_mad_padre) = 'S'));

         EXCEPTION
            WHEN no_data_found THEN
               BEGIN
                  SELECT DISTINCT 'S'
                    INTO v_exi_movi
                    FROM ge_movimientos_noc a
                   WHERE a.nro_documento = :new.nro_transaccion
                     AND (fup_exi_gru_transac(v_gru_reversiones, a.cod_tra_padre, a.cod_mod_padre,
                                              a.cod_mad_padre) = 'S')
                     AND NOT EXISTS
                   (SELECT DISTINCT 'S'
                            FROM ge_movimientos_noc
                           WHERE nro_documento = a.nro_documento
                             AND monto < 0
                             AND (fup_exi_gru_transac(v_gru_reversiones, cod_tra_padre, cod_mod_padre,
                                                      cod_mad_padre) = 'S'))
                     AND NOT EXISTS
                   (SELECT DISTINCT 'S'
                            FROM ge_movimientos
                           WHERE nro_documento = a.nro_documento
                             AND monto < 0
                             AND (fup_exi_gru_transac(v_gru_reversiones, cod_tra_padre, cod_mod_padre,
                                                      cod_mad_padre) = 'S'));
               EXCEPTION
                  WHEN no_data_found THEN
                     BEGIN
                        SELECT DISTINCT 'S'
                          INTO v_exi_movi
                          FROM gv_movimientos a
                         WHERE a.nro_documento = :new.nro_transaccion
                           AND a.fecha BETWEEN v_fec_anterior AND v_fec_proceso
                           AND (fup_exi_gru_transac(v_gru_reversiones, a.cod_tra_padre,
                                                    a.cod_mod_padre, a.cod_mad_padre) = 'S')
                           AND NOT EXISTS
                         (SELECT DISTINCT 'S'
                                  FROM ge_movimientos_noc
                                 WHERE nro_documento = a.nro_documento
                                   AND monto < 0
                                   AND (fup_exi_gru_transac(v_gru_reversiones, cod_tra_padre,
                                                            cod_mod_padre, cod_mad_padre) = 'S'))
                           AND NOT EXISTS
                         (SELECT DISTINCT 'S'
                                  FROM ge_movimientos
                                 WHERE nro_documento = a.nro_documento
                                   AND monto < 0
                                   AND (fup_exi_gru_transac(v_gru_reversiones, cod_tra_padre,
                                                            cod_mod_padre, cod_mad_padre) = 'S'))
                           AND NOT EXISTS
                         (SELECT DISTINCT 'S'
                                  FROM gv_movimientos
                                 WHERE nro_documento = a.nro_documento
                                   AND monto < 0
                                   AND fecha BETWEEN v_fec_anterior AND v_fec_proceso
                                   AND (fup_exi_gru_transac(v_gru_reversiones, cod_tra_padre,
                                                            cod_mod_padre, cod_mad_padre) = 'S'));
                     EXCEPTION
                        WHEN no_data_found THEN
                           v_exi_movi := 'N';
                     END;
               END;
         END;
         IF v_exi_movi = 'S' THEN
            INSERT INTO cj_tra_atm_rev_sin_pro
               (fec_sistema, pedido, respuesta, msj_error, nro_transaccion)
            VALUES
               (:new.fec_sistema, :new.pedido, :new.respuesta, nvl(:new.msj_error, 'EN CIERRE'),
                :new.nro_transaccion);
         END IF;
      END IF;
   END IF;
   ---
END;
/

