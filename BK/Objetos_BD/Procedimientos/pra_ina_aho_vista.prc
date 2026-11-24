CREATE OR REPLACE PROCEDURE IT.PRA_INA_AHO_VISTA 
 IS
   v_dia_inactivar number(5);
   v_hora          ge_movimientos.hora%type;
   v_fecha         ge_calendarios.fec_actual%type;
   v_nro_secuencia ge_movimientos.nro_secuencia%type;
   --- Cursor de ahorros a inactivar
CURSOR c_ina_ctas IS
   select nro_cuenta, estado
     from ah_cta_vistas
    where estado = 'N'
      and fec_ult_movimiento + v_dia_inactivar <= v_fecha;
   --- Cursor de cta cte a inactivar
CURSOR c_ina_ctas_ctes IS
   select nro_cuenta, estado
     from cc_cta_corrientes
    where estado = 'N'
      and fec_ult_movimiento + v_dia_inactivar <= v_fecha;
BEGIN
   -- Ahorro a la vista
   v_dia_inactivar := fug_obt_pardinamico('DIA_INA_AV', 3, 31);
   v_fecha         := pag_cal.fu_obt_fec_actual(3);
   v_hora          := to_char(sysdate,'HH24:MI:SS');
   v_hora          := fug_obt_hor_disponible(v_fecha,v_hora,user,'N');
   v_nro_secuencia := 0;

   for r_ina in c_ina_ctas loop
      pag_cta.pr_obt_cuenta(r_ina.nro_cuenta);
      pag_cta.PR_SET_VARIABLES(user, v_fecha, 420, 'N', 'N', v_nro_secuencia, 'I');
      pag_cta.pr_act_estado(r_ina.nro_cuenta, 'I', v_fecha,v_hora, null);
      v_nro_secuencia := v_nro_secuencia + 1;
      IF v_nro_secuencia = 999 THEN
         v_hora := FUG_OBT_HOR_DISPONIBLE(v_fecha,v_hora,user,'N');
         v_nro_secuencia := 1;
      END IF;
   end loop;
   --Ctas. Corrientes
   v_dia_inactivar := fug_obt_pardinamico('DIA_INA_CTA_CTE', 4, 41);
   v_fecha         := pag_cal.fu_obt_fec_actual(4);
   for r_ina_cte in c_ina_ctas_ctes loop
      pag_cta.pr_obt_cuenta(r_ina_cte.nro_cuenta);
      pag_cta.PR_SET_VARIABLES(user, v_fecha, 420, 'N', 'N', v_nro_secuencia, 'I');
      pag_cta.pr_act_estado(r_ina_cte.nro_cuenta, 'I', v_fecha, v_hora, null);
      v_nro_secuencia := v_nro_secuencia + 1;
      IF v_nro_secuencia = 999 THEN
         v_hora := FUG_OBT_HOR_DISPONIBLE(v_fecha,v_hora,user,'N');
         v_nro_secuencia := 1;
      END IF;

   end loop;
END;
/
