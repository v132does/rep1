CREATE OR REPLACE PROCEDURE IT.PRC_TRA_CTA_COM_FIN
 IS
 /* Transferencia de fondos automatica de Cuentas combinadas de cuentas corrientes a ahorros. Se ejecuta
    al fin de dia, y toma todo el saldo de la cuentas corrientes combinadas y lo transfiere a la cta.
    de ahorro relacionada */
   v_nro_cta_cte    cc_cta_combinadas.nro_cta_cte%type;
   r_gcale          ge_calendarios%rowtype;
   v_cantidad       number(05);
   v_nro_secuencia  ge_movimientos.nro_secuencia%type;
   v_hora           ge_movimientos.hora%type;
   v_reversado      ge_movimientos.reversado%type;
   v_traspas        varchar2(01);
   v_monto          ge_movimientos.monto%type;
   v_cod_usuario    ge_movimientos.cod_usuario%type;
   v_hor_ant        ge_movimientos.hora%type;
   v_fila           varchar2(100);
   r_gmovi          ge_movimientos%rowtype;
   v_ant_programa   pae_cnf.G_PROGRAMA%type;
   v_mto_recibido   number(18,2);
   v_nro_cta_debito ge_cuentas.nro_cuenta%type;
   --- Cursor de cuentas corrientes
   cursor c_ctasctes is
   select cod_modulo, cod_modalidad, cod_oficina, nro_cuenta,
          cod_moneda, sal_total, sal_retenido, sal_bloqueado,
          fec_ult_movimiento
     from cc_cta_corrientes
    where cta_combinada = 'S'
      and estado not in ('X','A','C','P','T','D')
      --and cod_sub_modalidad not in (2,3) -- paquetes no hace transferencia, a pedido del BBVA
      --ajuste JIRA 1614 - rabf 07/feb/2013
      and nvl(fug_obt_pardinamico('COD_SUB_MAD_TRA_CTACOMB',
          cod_modulo, cod_modalidad, cod_moneda, cod_oficina, cod_sub_modalidad), 'S') = 'S'
      -- rabf 27/mar/2013
      and nvl(sal_total,0) - nvl(sal_bloqueado,0) - nvl(sal_retenido,0) > 0
      for update of sal_total;
   --- Cursor de cuentas combinadas
   cursor c_ctascomb is
   select co.nro_cta_ahorro, co.nro_cta_cte, ah.cod_modulo, ah.cod_modalidad,
          ah.cod_oficina, ah.cod_moneda, ah.estado,
          nvl(co.sal_minimo,FUG_OBT_SAL_MIN_TRASPASO(v_nro_cta_cte)) sal_minimo
     from  ah_cta_vistas ah, cc_cta_combinadas co
    where nro_cta_cte = v_nro_cta_cte
      and ah.nro_cuenta = co.nro_cta_ahorro
      -- PCC-PAQ_TRA_AUT_CUE PCCPTACU-2  (S= Sin transferencia automática de cta. combinada)
      and ((nvl(fug_obt_paradicional(co.nro_cta_ahorro,'SIN_TRA_CTA_COMBINADA'),'x') != 'S')
          and (nvl(fug_obt_paradicional(co.nro_cta_cte,'SIN_TRA_CTA_COMBINADA'),'x') != 'S'));

BEGIN
   --- Recuperar datos del calendario del modulo
   r_gcale         := pag_cal.fu_obt_reg_cal(4);
   v_cantidad      := 0;
   --v_hora          := fug_ini_hora(SYSDATE,'HH24:MI:SS');
   v_hora := to_char(sysdate,'HH24:MI:SS');
   v_hora := fug_obt_hor_disponible(r_gcale.fec_actual,v_hora,user,'N');
   v_nro_secuencia := 0;
   --inicilizar programa para que no se actualicen las tablas _noc
   v_ant_programa     := pae_cnf.G_PROGRAMA;
   pae_cnf.G_PROGRAMA := 'PRC_TRA_CTA_COM_FIN';
   for cta in c_ctasctes loop
      if v_nro_secuencia > 900 then
         v_nro_secuencia := 0;
         --v_hora := pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);
         v_hora := fug_obt_hor_disponible(r_gcale.fec_actual,v_hora,user,'N');
      end if;
      v_reversado     := 'N';
      v_traspas       := 'N';
      v_nro_cta_cte   := cta.nro_cuenta;
      for com in c_ctascomb loop
         -- veo que monto se recibio a la mañana--------------------
         begin
              select nvl(monto,0), cod_usuario, hora, rowid
                 into v_mto_recibido, v_cod_usuario, v_hor_ant, v_fila
                 from ge_movimientos
                where nro_cuenta      = cta.nro_cuenta
                  and cod_tra_padre   = 310
                  and cod_transaccion = 602
                  and reversado = 'N';
         exception
            when others then
               v_mto_recibido := 0;
               v_cod_usuario  := null;
               v_hor_ant := null;
               v_fila := null;
         end;
         --Busco la Cta. de ahorros de Debito en el movimiento asociado--
         --JIRA DYDMR-1203--
         begin
              select nro_cuenta
                 into v_nro_cta_debito
                 from ge_movimientos
                where cod_tra_padre   = 310
                  and cod_transaccion = 503
                  and monto = v_mto_recibido
                  and cod_usuario = v_cod_usuario
                  and hora = v_hor_ant
                  and reversado = 'N';
         exception
            when others then
               v_nro_cta_debito := null;
         end;
         ------------------------------------------
         -- calculo el monto que deberia traspasarse----------------
         v_monto := round(nvl(cta.sal_total,0) - nvl(com.sal_minimo,0) - nvl(cta.sal_retenido,0) - nvl(cta.sal_bloqueado,0),fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',cta.cod_modulo,cta.cod_modalidad,cta.cod_moneda,cta.cod_oficina,null));
         if v_monto = v_mto_recibido and v_fila is not null and (v_nro_cta_debito = com.nro_cta_ahorro) then
            -- no hay necesidad de traspaso mañanero, se debe reversar
            v_traspas   := 'N';
            v_reversado := 'S';
         elsif v_monto > 0 then
            v_traspas   := 'S';
            v_reversado := 'N';
         else
            v_traspas   := 'N';
            v_reversado := 'N';
         end if;
         ---------
         if v_traspas = 'N' and v_reversado = 'S' then
            --- Realizar la reversion del traspaso de inicio del dia
            BEGIN
              -- monto a reversar es el monto recibido
              v_monto := v_mto_recibido * -1;
              --- Reversar 602
              update ge_movimientos
                 set reversado         = 'S',
                     cod_usu_reversion = user,
                     hor_reversion     = v_hora
               where rowid = v_fila;
              --- Insertar registro por la reversion
              r_gmovi.cod_usuario       := user;
              r_gmovi.hora              := v_hora;
              r_gmovi.fecha             := r_gcale.fec_actual;
              r_gmovi.concepto          := 'TRANSF. FIN DE DIA';
              v_nro_secuencia           := v_nro_secuencia + 1;
              r_gmovi.nro_secuencia     := v_nro_secuencia;
              r_gmovi.monto             := v_monto;
              r_gmovi.cod_usu_reversion := v_cod_usuario;
              r_gmovi.hor_reversion     := v_hor_ant;
              r_gmovi.reversado         := 'S';
              SELECT cod_modulo, cod_modalidad, cod_oficina, nro_cuenta,
                     cod_moneda, cod_tra_padre, cod_transaccion, fecha,
                     fec_valor, estado, emi_aviso, cod_ofi_origen,
                     cod_mod_padre, cod_mad_padre
                into r_gmovi.cod_modulo, r_gmovi.cod_modalidad, r_gmovi.cod_oficina, r_gmovi.nro_cuenta,
                     r_gmovi.cod_moneda, r_gmovi.cod_tra_padre, r_gmovi.cod_transaccion, r_gmovi.fecha,
                     r_gmovi.fec_valor, r_gmovi.estado, r_gmovi.emi_aviso, r_gmovi.cod_ofi_origen,
                     r_gmovi.cod_mod_padre, r_gmovi.cod_mad_padre
                from ge_movimientos
               where rowid = v_fila;
              pag_gen.pr_ins_ge_movimiento(r_gmovi);
              --- Reversar la 503
              update ge_movimientos
                 set reversado         = 'S',
                     cod_usu_reversion = user,
                     hor_reversion     = v_hora
               where nro_cuenta  = com.nro_cta_ahorro
                 and cod_usuario = v_cod_usuario
                 and cod_tra_padre = 310
                 and cod_transaccion = 503
                 and hora        = v_hor_ant;
              --- Insertar registro por la reversion
              r_gmovi.cod_usuario       := user;
              r_gmovi.hora              := v_hora;
              r_gmovi.fecha             := r_gcale.fec_actual;
              r_gmovi.concepto          := 'TRANSF. FIN DE DIA';
              v_nro_secuencia           := v_nro_secuencia + 1;
              r_gmovi.nro_secuencia     := v_nro_secuencia;
              r_gmovi.monto             := v_monto;
              r_gmovi.cod_usu_reversion := v_cod_usuario;
              r_gmovi.hor_reversion     := v_hor_ant;
              select cod_modulo, cod_modalidad, cod_oficina, nro_cuenta,
                     cod_moneda, cod_tra_padre, cod_transaccion, fecha,
                     fec_valor, estado, emi_aviso, cod_ofi_origen,
                     cod_mod_padre, cod_mad_padre
                into r_gmovi.cod_modulo, r_gmovi.cod_modalidad, r_gmovi.cod_oficina, r_gmovi.nro_cuenta,
                     r_gmovi.cod_moneda, r_gmovi.cod_tra_padre, r_gmovi.cod_transaccion, r_gmovi.fecha,
                     r_gmovi.fec_valor, r_gmovi.estado, r_gmovi.emi_aviso, r_gmovi.cod_ofi_origen,
                     r_gmovi.cod_mod_padre, r_gmovi.cod_mad_padre
                from ge_movimientos
               where nro_cuenta  = com.nro_cta_ahorro
                 and cod_usuario = v_cod_usuario
                 and cod_tra_padre = 310
                 and cod_transaccion = 503
                 and hora        = v_hor_ant;
              pag_gen.pr_ins_ge_movimiento(r_gmovi);
              --- Actualizar saldos
              UPDATE ah_cta_vistas
                 SET sal_total = nvl(sal_total,0) - nvl(v_monto,0)
               where nro_cuenta = com.nro_cta_ahorro;
              UPDATE cc_cta_corrientes
                 SET sal_total = nvl(sal_total,0) + nvl(v_monto,0)
              WHERE CURRENT OF c_ctasctes;
            EXCEPTION
               when no_data_found then
                       null;
               when too_many_rows then
                  raise_application_error(-20000,
                  'Cta.Cte. '||cta.nro_cuenta||' o Cta.Aho. '||com.nro_cta_ahorro||' duplicada.');
            END;
         END IF;
         IF v_traspas = 'S' AND v_reversado = 'N' THEN
            -- se realiza el traspaso
            v_monto := round(nvl(cta.sal_total,0) - nvl(com.sal_minimo,0) - nvl(cta.sal_retenido,0) - nvl(cta.sal_bloqueado,0),fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',cta.cod_modulo,cta.cod_modalidad,cta.cod_moneda,cta.cod_oficina,null));
            IF nvl(v_monto,0) > 0 THEN
               update ah_cta_vistas
                  set sal_total = nvl(sal_total,0) + nvl(v_monto,0)
                where nro_cuenta = com.nro_cta_ahorro
                  and estado not in ('C','T','X');
               IF SQL%FOUND THEN
                  --- Esta rutina verifica si la cuenta esta con estado 'A', en cuyo caso
                  -- se modifica su estado a 'N'.-----------------------
                  if com.estado = 'A' then
                     update ah_cta_vistas
                        set estado = 'N', fec_cam_estado = r_gcale.fec_actual
                      where nro_cuenta = com.nro_cta_ahorro;
                     -- Inserto la novedad de cambio de estado
                     pag_cta.PR_OBT_CUENTA(com.nro_cta_ahorro);
                     insert into ge_cuentas_nov
                        (fecha, hora, cod_usuario,
                         nro_cuenta, nro_detalle,
                         cod_modulo, cod_modalidad,
                         est_anterior, est_actual, fec_cam_est_ant,
                         fec_ult_mov_ant, hor_ult_mov_ant, fec_ult_cap_ant )
                     values
                        (r_gcale.fec_actual, v_hora, user,
                         com.nro_cta_ahorro, null,
                         com.cod_modulo, com.cod_modalidad,
                         'A', 'N', r_gcale.fec_actual,
                         pag_cta.g_ctas.fec_ult_movimiento, pag_cta.g_ctas.hor_ult_movimiento, pag_cta.g_ctas.fec_ult_capitalizacion);
                     --------------------------------------------------------------
                     r_gmovi.cod_usuario     := user;
                     r_gmovi.hora            := v_hora;
                     r_gmovi.fecha           := r_gcale.fec_actual;
                     r_gmovi.cod_modulo      := com.cod_modulo;
                     r_gmovi.cod_modalidad   := com.cod_modalidad;
                     r_gmovi.cod_oficina     := com.cod_oficina;
                     r_gmovi.nro_cuenta      := com.nro_cta_ahorro;
                     r_gmovi.cod_moneda      := cta.cod_moneda;
                     r_gmovi.cod_tra_padre   := 310;
                     r_gmovi.cod_mod_padre   := com.cod_modulo;
                     r_gmovi.cod_mad_padre   := com.cod_modalidad;
                     r_gmovi.fec_valor       := r_gcale.fec_actual;
                     r_gmovi.reversado       := 'N';
                     r_gmovi.cod_usu_reversion := null;
                     r_gmovi.hor_reversion     := null;
                     r_gmovi.protegido       := 'N';
                     r_gmovi.estado          := 'N';
                     r_gmovi.cod_ofi_origen  := cta.cod_oficina;
                     r_gmovi.concepto        := 'CAMBIO DE ESTADO';
                     v_nro_secuencia         := v_nro_secuencia + 1;
                     r_gmovi.nro_secuencia   := v_nro_secuencia;
                     r_gmovi.emi_aviso       := 'N';
                     r_gmovi.cod_transaccion := 425;
                     r_gmovi.monto           := null;
                     r_gmovi.est_cuenta      := 'N';
                     pag_gen.pr_ins_ge_movimiento(r_gmovi);
                  end if;
                  ------------------------------------------------------
                  update cc_cta_corrientes
                     set sal_total = nvl(sal_total,0) - nvl(v_monto,0)
                   where current of c_ctasctes;
                  --- Generar movimientos Debito de Cta.Cte.
                  r_gmovi.cod_usuario     := user;
                  r_gmovi.hora            := v_hora;
                  r_gmovi.fecha           := r_gcale.fec_actual;
                  r_gmovi.cod_modulo      := cta.cod_modulo;
                  r_gmovi.cod_modalidad   := cta.cod_modalidad;
                  r_gmovi.cod_oficina     := cta.cod_oficina;
                  r_gmovi.nro_cuenta      := cta.nro_cuenta;
                  r_gmovi.cod_moneda      := cta.cod_moneda;
                  r_gmovi.cod_tra_padre   := 310;
                  r_gmovi.cod_mod_padre   := cta.cod_modulo;
                  r_gmovi.cod_mad_padre   := cta.cod_modalidad;
                  r_gmovi.fec_valor       := r_gcale.fec_actual;
                  r_gmovi.reversado       := 'N';
                  r_gmovi.cod_usu_reversion := null;
                  r_gmovi.hor_reversion     := null;
                  r_gmovi.protegido       := 'N';
                  r_gmovi.estado          := 'N';
                  r_gmovi.cod_ofi_origen  := com.cod_oficina;
                  r_gmovi.concepto        := 'TRANSF. FIN DE DIA';
                  v_nro_secuencia         := v_nro_secuencia + 1;
                  r_gmovi.nro_secuencia   := v_nro_secuencia;
                  r_gmovi.emi_aviso       := 'N';
                  r_gmovi.cod_transaccion := 503;
                  r_gmovi.monto           := v_monto;
                  pag_gen.pr_ins_ge_movimiento(r_gmovi);
                  --- Generar movimiento por el Credito al AV
                  r_gmovi.cod_usuario     := user;
                  r_gmovi.hora            := v_hora;
                  r_gmovi.fecha           := r_gcale.fec_actual;
                  r_gmovi.cod_modulo      := com.cod_modulo;
                  r_gmovi.cod_modalidad   := com.cod_modalidad;
                  r_gmovi.cod_oficina     := com.cod_oficina;
                  r_gmovi.nro_cuenta      := com.nro_cta_ahorro;
                  r_gmovi.cod_moneda      := cta.cod_moneda;
                  r_gmovi.cod_tra_padre   := 310;
                  r_gmovi.cod_mod_padre   := cta.cod_modulo;
                  r_gmovi.cod_mad_padre   := cta.cod_modalidad;
                  r_gmovi.fec_valor       := r_gcale.fec_actual;
                  r_gmovi.reversado       := 'N';
                  r_gmovi.cod_usu_reversion := null;
                  r_gmovi.hor_reversion     := null;
                  r_gmovi.protegido       := 'N';
                  r_gmovi.estado          := 'N';
                  r_gmovi.cod_ofi_origen  := com.cod_oficina;
                  r_gmovi.concepto        := 'TRANSF. FIN DE DIA';
                  v_nro_secuencia         := v_nro_secuencia + 1;
                  r_gmovi.nro_secuencia   := v_nro_secuencia;
                  r_gmovi.emi_aviso       := 'N';
                  r_gmovi.cod_transaccion := 602;
                  r_gmovi.monto           := v_monto;
                  pag_gen.pr_ins_ge_movimiento(r_gmovi);
               END IF;
            END IF;
         END IF;
      end loop;
      v_cantidad := v_cantidad + 1;

   end loop;
   --vuelve a asignar el programa con el que entró
   pae_cnf.G_PROGRAMA := v_ant_programa;
   if v_cantidad = 0 then
      raise_application_error(-20000, 'No existen Cuentas combinadas. Favor verificar!');
   end if;
EXCEPTION
WHEN OTHERS THEN
  NULL;
END;
/

