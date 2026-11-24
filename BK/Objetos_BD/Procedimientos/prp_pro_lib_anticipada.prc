CREATE OR REPLACE PROCEDURE IT.prp_pro_lib_anticipada IS
   v_fec_actual DATE := pag_cal.fu_obt_fec_actual(4);

   CURSOR c_ah_ret_x_cuenta IS
      SELECT a.nro_cuenta, a.nro_documento, a.cod_retencion, a.fec_final
        FROM ah_retenciones a, cc_lib_ant_cheques c
       WHERE a.nro_cuenta = c.nro_cuenta
         AND a.nro_documento = c.nro_documento
         AND a.cod_retencion = c.cod_retencion
         AND a.fec_final = c.fec_final
         AND a.cod_modulo = 4
         AND a.fec_final <= v_fec_actual
         AND a.lib_anticipada = 'S'
         AND c.estado = 'D'
            --- No considerar operaciones de tas no confirmadas
         AND NOT EXISTS (SELECT 1
                FROM cj_movimientos c
               WHERE c.fecha = a.fec_inicio
                 AND c.cod_usuario = a.cod_usuario
                 AND c.estado = 'X'
                 AND c.nro_cuenta = a.nro_cuenta
                 AND c.cod_moneda = a.cod_moneda
                 AND c.nro_documento = a.nro_documento
                 AND c.monto = a.monto)
       ORDER BY a.nro_cuenta, a.nro_documento, a.cod_retencion, a.fec_final;
   v_hora          ge_movimientos.hora%TYPE;
   v_nro_secuencia ge_movimientos.nro_secuencia%TYPE := 0;

BEGIN
   v_hora := to_char(SYSDATE, 'HH24:MI:SS');
   v_hora := fug_obt_hor_disponible(v_fec_actual, v_hora, USER, 'N');
   FOR i IN c_ah_ret_x_cuenta LOOP
      IF v_nro_secuencia > 990 THEN
         v_hora          := pag_gen.fu_obt_sig_segundo(v_hora);
         v_nro_secuencia := -999;
      END IF;
      prc_can_pre_lib_anticipada(i.nro_cuenta, i.nro_documento, i.cod_retencion, i.fec_final,
                                 v_hora, v_nro_secuencia);
   END LOOP;
END prp_pro_lib_anticipada;
/

