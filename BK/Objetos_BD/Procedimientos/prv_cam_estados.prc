CREATE OR REPLACE PROCEDURE IT.PRV_CAM_ESTADOS
 IS
--- Operaciones Vencidas que pueden cambiar de situacion
   cursor mae_cur is
   select p.cod_modulo, p.cod_modalidad, p.cod_oficina, p.nro_cuenta,
          p.estado, p.fec_cam_estado,
          fup_obt_categoria(cli.cat_automatica,cli.cat_subjetiva) categoria
     from ge_clientes cli, ge_cta_clientes ccl, ov_cta_vencidas p
    where p.nro_cuenta = ccl.nro_cuenta
      and ccl.cod_persona = cli.cod_persona
      and ccl.relacion = 'P'
      and p.estado not in('C','I')
   order by p.nro_cuenta;
   v_fec_inicio     ge_calendarios.fec_actual%type;
   v_hora           ge_movimientos.hora%type;
   v_nro_secuencia  ge_movimientos.nro_secuencia%type;
BEGIN
   -- Obtener fecha calendario
   pag_cal.PR_OBT_DAT_CALENDAR(15);
   v_fec_inicio    := pag_cal.g_fec_actual;
   v_hora          := fug_ini_hora(sysdate,'HH24:MI:SS');
   v_hora          := fug_obt_hor_disponible(v_fec_inicio,v_hora,user,'N');  -- DYDMR-8168 Abr/2018
   --v_hora          := pag_gen.fu_obt_sig_segundo(v_hora);
   v_nro_secuencia := 0;
   for m1 in mae_cur loop
      --- Procesando Operaciones Vencidas
      if v_nro_secuencia + 10 > 999 then
         --- Reiniciar secuencia y hora
         v_nro_secuencia := 0;
         --v_hora          := pag_gen.fu_obt_sig_segundo(v_hora);
         v_hora := fug_obt_hor_disponible(v_fec_inicio,v_hora,user,'N');
      end if;
      pav_mes.pr_cam_situacion (m1.cod_modulo,
                                m1.cod_modalidad,
                                m1.cod_oficina,
                                m1.nro_cuenta,
                                m1.categoria,
                                v_fec_inicio,
                                v_hora,
                                v_nro_secuencia);
   end loop;
END;
/

