CREATE OR REPLACE PROCEDURE IT.prj_act_atm_extornos IS
   v_fec_actual   ta_cal_cierres.fec_cierre%TYPE := pag_cal.fu_obt_fec_actual(3);
   v_fec_anterior ta_cal_cierres.fec_cierre%TYPE := pag_cal.fu_obt_fec_ant_hab(pag_cal.fu_obt_fec_actual(3),
                                                                               NULL, 1);
   v_respuesta    VARCHAR2(2000);
   CURSOR c_mov_atm IS
      SELECT c.fec_sistema, c.pedido, c.respuesta, c.nro_transaccion
        FROM cj_tra_atm_rev_sin_pro c
       WHERE c.procesado = 'N'
       AND trunc(c.fec_sistema) between v_fec_anterior and v_fec_actual;
BEGIN
   FOR atm IN c_mov_atm LOOP
      -- inserto movimiento
      v_respuesta := fuj_pro_tra_atm(atm.pedido);
      UPDATE cj_tra_atm_rev_sin_pro
         SET procesado = 'S'
       WHERE nro_transaccion = atm.nro_transaccion
         AND procesado = 'N'
         AND fec_sistema = atm.fec_sistema;
   END LOOP;
END;
/

