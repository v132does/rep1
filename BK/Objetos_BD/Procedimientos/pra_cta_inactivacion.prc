CREATE OR REPLACE PROCEDURE IT.PRA_CTA_INACTIVACION
  /* Permite inactivar cuentas de ahorros a la vista o cuentas corrientes */
 IS
   v_hora          ge_movimientos.hora%type;
   v_fecha         ge_calendarios.fec_actual%type;
   v_nro_secuencia ge_movimientos.nro_secuencia%type;
   v_fculmov       cc_cta_corrientes.fec_ult_movimiento%type;
   --- Cursor de ahorros a inactivar
CURSOR c_ina_ctas IS
   select nro_cuenta, estado
     from ah_cta_vistas
    where estado = 'N'
      and nvl(cta_combinada,'N') = 'N'
      and fec_ult_movimiento + to_number(fug_obt_pardinamico('DIA_INA_AV', cod_modulo, cod_modalidad, cod_moneda, cod_oficina)) <= v_fecha;
   --- Cursor de cta cte a inactivar
CURSOR c_ina_ctas_ctes IS
   select nro_cuenta, estado
     from cc_cta_corrientes
    where estado = 'N'
      --and nvl(cta_combinada,'N') = 'N'
      and fec_ult_movimiento + to_number(fug_obt_pardinamico('DIA_INA_CTA_CTE', cod_modulo, cod_modalidad, cod_moneda, cod_oficina)) <= v_fecha;
  --- Cursor de cta combinada a inactivar
CURSOR ah_comb is
   select nro_cuenta, estado, cod_modulo, cod_modalidad, cod_moneda, cod_oficina
     from ah_cta_vistas
    where estado = 'N'
      and nvl(cta_combinada,'N') = 'S'
      and fec_ult_movimiento + to_number(fug_obt_pardinamico('DIA_INA_AV', cod_modulo, cod_modalidad, cod_moneda, cod_oficina)) <= v_fecha;
BEGIN
   -- Ahorro a la vista
   v_fecha         := pag_cal.fu_obt_fec_actual(3);
   v_hora          := fug_ini_hora(sysdate,'HH24:MI:SS');
   v_nro_secuencia := 0;
   for r_ina in c_ina_ctas loop
      pag_cta.pr_obt_cuenta(r_ina.nro_cuenta);
      pag_cta.PR_SET_VARIABLES(user, v_fecha, 420, 'N', 'N', v_nro_secuencia, 'I', pag_cta.g_ctas.cod_oficina, 
                               pag_cta.g_ctas.cod_modulo, pag_cta.g_ctas.cod_modalidad);
      pag_cta.pr_act_estado(r_ina.nro_cuenta, 'I', v_fecha,v_hora, null);
         v_nro_secuencia := v_nro_secuencia + 1; --BBVASOP-1387
      if v_nro_secuencia > 990 then
         v_nro_secuencia := 0;
         v_hora := pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);
      end if; 
   end loop;
   --Ctas. Combinadas
   for r_ina_comb in ah_comb loop
      begin
          select fec_ult_movimiento
            into v_fculmov
            from cc_cta_corrientes
           where nro_cuenta =
                             (select nro_cta_cte
                                from cc_cta_combinadas
                               where nro_cta_ahorro = r_ina_comb.nro_cuenta);
      exception
        when no_data_found then
          null;
        when too_many_rows then
          null;
      end;
      If v_fculmov+to_number(fug_obt_pardinamico('DIA_INA_AV', r_ina_comb.cod_modulo, 
                                                r_ina_comb.cod_modalidad, 
                                                r_ina_comb.cod_moneda, r_ina_comb.cod_oficina)) <= v_fecha THEN
        pag_cta.pr_obt_cuenta(r_ina_comb.nro_cuenta);
        pag_cta.PR_SET_VARIABLES(user, v_fecha, 420, 'N', 'N', v_nro_secuencia, 'I', pag_cta.g_ctas.cod_oficina, 
                               pag_cta.g_ctas.cod_modulo, pag_cta.g_ctas.cod_modalidad);        
        pag_cta.pr_act_estado(r_ina_comb.nro_cuenta, 'I', v_fecha, v_hora, null);
          v_nro_secuencia := v_nro_secuencia + 1;
       if v_nro_secuencia > 990 then
          v_nro_secuencia := 0;
          v_hora := pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);
       end if;
      End if;
   end loop;
   --Ctas. Corrientes
   v_fecha         := pag_cal.fu_obt_fec_actual(4);
   for r_ina_cte in c_ina_ctas_ctes loop
      pag_cta.pr_obt_cuenta(r_ina_cte.nro_cuenta);
      pag_cta.PR_SET_VARIABLES(user, v_fecha, 420, 'N', 'N', v_nro_secuencia, 'I', pag_cta.g_ctas.cod_oficina, 
                               pag_cta.g_ctas.cod_modulo, pag_cta.g_ctas.cod_modalidad);      
      pag_cta.pr_act_estado(r_ina_cte.nro_cuenta, 'I', v_fecha, v_hora, null);
         v_nro_secuencia := v_nro_secuencia + 1;
      if v_nro_secuencia > 990 then
         v_nro_secuencia := 0;
         v_hora := pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);
      end if;
   end loop;
END;
/

