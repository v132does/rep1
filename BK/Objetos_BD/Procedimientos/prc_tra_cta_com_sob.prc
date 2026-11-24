CREATE OR REPLACE PROCEDURE IT.PRC_TRA_CTA_COM_SOB
 IS
 /* Transferencia de fondos automatica de Cuentas combinadas de cajas de ahorros con saldo y cuenta
    corriente en sobregiro */
   v_nro_cta_cte    cc_cta_combinadas.nro_cta_cte%type;
   v_cod_mon_local  ba_monedas.cod_moneda%type;
   r_gcale          ge_calendarios%rowtype;
   v_cantidad       number(05);
   v_nro_secuencia  ge_movimientos.nro_secuencia%type;
   v_hora           ge_movimientos.hora%type;
   v_reversado      ge_movimientos.reversado%type;
   v_traspas        varchar2(01);
   v_dummy          varchar2(01);
   v_monto          ge_movimientos.monto%type;
   v_cod_usuario    ge_movimientos.cod_usuario%type;
   v_hor_ant        ge_movimientos.hora%type;
   v_fila           varchar2(100);
   r_gmovi          ge_movimientos%rowtype;
   v_ant_programa   pae_cnf.G_PROGRAMA%type;
   v_mto_recibido   number(18,2);
   --- Cursor de cuentas corrientes
   cursor c_ctasctes is
   select a.cod_modulo, a.cod_modalidad, a.cod_oficina, a.nro_cuenta,
          a.cod_moneda, abs(nvl(a.sal_total,0) - nvl(a.sal_retenido,0) - nvl(a.sal_bloqueado,0)) sal_cta_cte,
          nvl(c.sal_total,0) - nvl(c.sal_bloqueado,0) - nvl(c.sal_retenido,0) sal_cta_ahorro,
          c.nro_cuenta nro_cta_ahorro, c.cod_modulo cod_mod_ahorro,
          c.cod_modalidad cod_mad_ahorro, c.cod_oficina cod_ofi_ahorro
     from  ah_cta_vistas c, cc_cta_combinadas b, cc_cta_corrientes a
    where a.cta_combinada = 'S'
      and a.estado not in ('X','A','C','P','T','D')
      and nvl(a.sal_total,0) - nvl(a.sal_retenido,0) - nvl(a.sal_bloqueado,0) < 0
      and b.nro_cta_cte = a.nro_cuenta
      and c.nro_cuenta = b.nro_cta_ahorro
      and nvl(c.sal_total,0) - nvl(c.sal_retenido,0) - nvl(c.sal_bloqueado,0) > 0
      for update of a.sal_total;

BEGIN
   ---Leo la mon. local para verific. si se traspasa o no el retenido--
   v_cod_mon_local := pag_gen.fu_obt_mon_local;
   --- Recuperar datos del calendario del modulo
   r_gcale         := pag_cal.fu_obt_reg_cal(4);
   v_cantidad      := 0;
   v_hora          := fug_ini_hora(SYSDATE,'HH24:MI:SS');
   v_nro_secuencia := 0;
   --inicilizar programa para que no se actualicen las tablas _noc
   v_ant_programa     := pae_cnf.G_PROGRAMA;
   pae_cnf.G_PROGRAMA := 'PRC_TRA_CTA_COM_SOB';
   for cta in c_ctasctes loop
      if v_nro_secuencia > 900 then
         v_nro_secuencia := 0;
         v_hora := pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);
      end if;
      v_reversado     := 'N';
      v_traspas       := 'N';
      v_nro_cta_cte   := cta.nro_cuenta;
         -- veo que monto se recibio a la mañana--------------------
/*         begin
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
         end;*/
         -- calculo el monto que deberia traspasarse----------------
         if nvl(cta.sal_cta_cte,0) > nvl(cta.sal_cta_ahorro,0) then
            v_monto := nvl(cta.sal_cta_ahorro,0);
         else
            v_monto := nvl(cta.sal_cta_cte,0);
         end if;
            IF nvl(v_monto,0) > 0 THEN
               update ah_cta_vistas
                  set sal_total = nvl(sal_total,0) - nvl(v_monto,0)
                where nro_cuenta = cta.nro_cta_ahorro
                  and estado not in ('C','T','X');
               IF SQL%FOUND THEN
                  update cc_cta_corrientes
                     set sal_total = nvl(sal_total,0) + nvl(v_monto,0)
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
                  r_gmovi.cod_ofi_origen  := cta.cod_oficina;
                  r_gmovi.concepto        := 'COBERTURA SOBREGIRO';
                  v_nro_secuencia         := v_nro_secuencia + 1;
                  r_gmovi.nro_secuencia   := v_nro_secuencia;
                  r_gmovi.emi_aviso       := 'N';
                  r_gmovi.cod_transaccion := 602;
                  r_gmovi.monto           := v_monto;
                  pag_gen.pr_ins_ge_movimiento(r_gmovi);
                  --- Generar movimiento por el Credito al AV
                  r_gmovi.cod_usuario     := user;
                  r_gmovi.hora            := v_hora;
                  r_gmovi.fecha           := r_gcale.fec_actual;
                  r_gmovi.cod_modulo      := cta.cod_mod_ahorro;
                  r_gmovi.cod_modalidad   := cta.cod_mad_ahorro;
                  r_gmovi.cod_oficina     := cta.cod_ofi_ahorro;
                  r_gmovi.nro_cuenta      := cta.nro_cta_ahorro;
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
                  r_gmovi.cod_ofi_origen  := cta.cod_oficina;
                  r_gmovi.concepto        := 'COBERTURA SOBREGIRO';
                  v_nro_secuencia         := v_nro_secuencia + 1;
                  r_gmovi.nro_secuencia   := v_nro_secuencia;
                  r_gmovi.emi_aviso       := 'N';
                  r_gmovi.cod_transaccion := 503;
                  r_gmovi.monto           := v_monto;
                  pag_gen.pr_ins_ge_movimiento(r_gmovi);
               END IF;
            END IF;

      v_cantidad := v_cantidad + 1;
   end loop;
   --vuelve a asignar el programa con el que entró
   pae_cnf.G_PROGRAMA := v_ant_programa;
   --Se quito la validación de cantidad de registros procesados --16/02/2010
   /*
   if v_cantidad = 0 then
      raise_application_error(-20000, 'No existen Cuentas combinadas. Favor verificar!');
   end if;
   */
END;
/

