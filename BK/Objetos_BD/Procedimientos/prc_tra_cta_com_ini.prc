CREATE OR REPLACE PROCEDURE it.PRC_TRA_CTA_COM_INI
 IS
 /* Transferencia de fondos automatica de Cuentas combinadas de ahorros a cuentas corrientes. Se ejecuta
    al Inicio de dia, y toma todo el saldo de la cuentas de ahorros combinadas y lo transfiere a la cta.
    corriente relacionada */
v_nro_cta_ahorro cc_cta_combinadas.nro_cta_ahorro%type;
v_rol_referencia varchar2(15) := 'inicio';
v_lugar      VARCHAR2(300);
   --- Cursor de cuentas de ahorros
   cursor c_ahorros is
   select cod_modulo, cod_modalidad, cod_oficina, nro_cuenta,
          cod_moneda, nvl(sal_total,0)-nvl(sal_bloqueado,0)-nvl(sal_retenido,0) disponible
     from ah_cta_vistas
    where cta_combinada = 'S'
      and estado not in ('C','P','T','D','A','X')
      --and cod_sub_modalidad not in (2,3) -- paquetes no hace transferencia, a pedido del BBVA
      --ajuste JIRA 1614 - rabf 07/feb/2013
      and nvl(fug_obt_pardinamico('COD_SUB_MAD_TRA_CTACOMB',
          cod_modulo, cod_modalidad, cod_moneda, cod_oficina, cod_sub_modalidad), 'S') = 'S'
      -- rabf 27/mar/2013
      and nvl(sal_total,0)-nvl(sal_bloqueado,0)-nvl(sal_retenido,0) > 0
      for update of sal_total;
   --- Cursor de cuentas combinadas
   cursor c_ctas_combinadas is
   select co.nro_cta_cte, cc.cod_modulo, cc.cod_modalidad,
          cc.cod_oficina, cc.estado
     from  cc_cta_corrientes cc, cc_cta_combinadas co
    where nro_cta_ahorro = v_nro_cta_ahorro
      and co.nro_cta_cte = cc.nro_cuenta
      -- PCC-PAQ_TRA_AUT_CUE PCCPTACU-2  (S= Sin transferencia automática de cta. combinada)
      and ((nvl(fug_obt_paradicional(co.nro_cta_ahorro,'SIN_TRA_CTA_COMBINADA'),'x') != 'S')
          and (nvl(fug_obt_paradicional(co.nro_cta_cte,'SIN_TRA_CTA_COMBINADA'),'x') != 'S'));
   --- Variables auxiliares
   v_fecha          ge_movimientos.fecha%type;
   v_hora           ge_movimientos.hora%type;
   v_nro_secuencia  ge_movimientos.nro_secuencia%type  := 0;
   v_cantidad       number(05);
   v_estado         ge_cuentas.estado%type;
   r_gmovi          ge_movimientos%rowtype;
   v_ant_programa   pae_cnf.G_PROGRAMA%type;
 procedure pr_rev_est_modulo is
  begin
    prg_rol_savepoint(v_rol_referencia);
    UPDATE ba_modulos SET estado = 1 WHERE cod_modulo = 3;
    COMMIT;
  end;
BEGIN
   v_cantidad := 0;
   v_fecha    := pag_cal.fu_obt_fec_actual(4);
   v_hora := fug_ini_hora(SYSDATE,'HH24:MI:SS');
   --inicilizar programa para que no se actualicen las tablas _noc
   v_ant_programa     := pae_cnf.G_PROGRAMA;
   pae_cnf.G_PROGRAMA := 'PRC_TRA_CTA_COM_INI';
    --Pone estado del modulo en inhabilitado para ATM
   v_lugar := 'Pone estado del modulo en inhabilitado para ATM';
   UPDATE ba_modulos SET estado = 6 WHERE cod_modulo = 3;
   COMMIT;
   prg_cre_savepoint(v_rol_referencia);
   for cta in c_ahorros loop
      if v_nro_secuencia > 900 then
         v_nro_secuencia := 0;
         v_hora := pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);
      end if;
      v_nro_cta_ahorro := cta.nro_cuenta;
      for r_cccom in c_ctas_combinadas loop
         --- Recuperar estado on line de la cuenta corriente, para poder  --
         --- generar o no el movimiento por cambio de estado de la --
         --- Cuenta que es la transaccion 425                      --
         -----------------------------------------------------------
         v_estado := r_cccom.estado;
         -----------------------------------------------------------
         update cc_cta_corrientes
            set sal_total  = nvl(sal_total,0) + nvl(cta.disponible,0)
          where nro_cuenta = r_cccom.nro_cta_cte
            and estado not in ('C','T','X');
         if sql%found then
            --- Generar movimiento del debito sobre el AV
            r_gmovi.cod_usuario     := user;
            r_gmovi.hora            := v_hora;
            r_gmovi.fecha           := v_fecha;
            r_gmovi.cod_modulo      := cta.cod_modulo;
            r_gmovi.cod_modalidad   := cta.cod_modalidad;
            r_gmovi.cod_oficina     := cta.cod_oficina;
            r_gmovi.nro_cuenta      := cta.nro_cuenta;
            r_gmovi.cod_moneda      := cta.cod_moneda;
            r_gmovi.cod_tra_padre   := 310;
            r_gmovi.cod_mod_padre   := cta.cod_modulo;
            r_gmovi.cod_mad_padre   := cta.cod_modalidad;
            r_gmovi.fec_valor       := v_fecha;
            r_gmovi.reversado       := 'N';
            r_gmovi.protegido       := 'N';
            r_gmovi.estado          := 'N';
            r_gmovi.cod_ofi_origen  := cta.cod_oficina;
            r_gmovi.concepto        := 'TRANSF. INICIO DE DIA';
            v_nro_secuencia         := v_nro_secuencia + 1;
            r_gmovi.nro_secuencia   := v_nro_secuencia;
            r_gmovi.emi_aviso       := 'N';
            r_gmovi.cod_transaccion := 503;
            r_gmovi.monto           := round(cta.disponible,fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',cta.cod_modulo,cta.cod_modalidad,cta.cod_moneda,null,null));
            pag_gen.pr_ins_ge_movimiento(r_gmovi);
            --- Generar movimiento del credito sobre la CC
            r_gmovi.cod_usuario     := user;
            r_gmovi.hora            := v_hora;
            r_gmovi.fecha           := v_fecha;
            r_gmovi.cod_modulo      := r_cccom.cod_modulo;
            r_gmovi.cod_modalidad   := r_cccom.cod_modalidad;
            r_gmovi.cod_oficina     := r_cccom.cod_oficina;
            r_gmovi.nro_cuenta      := r_cccom.nro_cta_cte;
            r_gmovi.cod_moneda      := cta.cod_moneda;
            r_gmovi.cod_tra_padre   := 310;
            r_gmovi.cod_mod_padre   := cta.cod_modulo;
            r_gmovi.cod_mad_padre   := cta.cod_modalidad;
            r_gmovi.fec_valor       := v_fecha;
            r_gmovi.reversado       := 'N';
            r_gmovi.protegido       := 'N';
            r_gmovi.estado          := 'N';
            r_gmovi.cod_ofi_origen  := cta.cod_oficina;
            r_gmovi.concepto        := 'TRANSF. INICIO DE DIA';
            v_nro_secuencia         := v_nro_secuencia + 1;
            r_gmovi.nro_secuencia   := v_nro_secuencia;
            r_gmovi.emi_aviso       := 'N';
            r_gmovi.cod_transaccion := 602;
            r_gmovi.monto           := cta.disponible;
            pag_gen.pr_ins_ge_movimiento(r_gmovi);
            --- Generar movimiento para que grabe la transaccion 425
            --- por cambio de estado si el estado de la transaccion sea 'A'
            --- (Abierto falta Depositar).                                            --
            ------------------------------------------------------------
            if v_estado = 'A' then
               -- cambio el estado de la cuenta
               update cc_cta_corrientes
                  set estado = 'N'
                where nro_cuenta = r_cccom.nro_cta_cte;
               -- Inserto la novedad de cambio de estado
               pag_cta.PR_OBT_CUENTA(r_cccom.nro_cta_cte);
               insert into ge_cuentas_nov
                  (fecha, hora, cod_usuario, nro_cuenta, nro_detalle, cod_modulo, cod_modalidad, est_anterior, est_actual,
                   fec_cam_est_ant, fec_ult_mov_ant, hor_ult_mov_ant, fec_ult_cap_ant )
               values
                  (v_fecha, v_hora, user, r_cccom.nro_cta_cte, null, r_cccom.cod_modulo, r_cccom.cod_modalidad, 'A', 'N', 
                   v_fecha, pag_cta.g_ctas.fec_ult_movimiento, pag_cta.g_ctas.hor_ult_movimiento, pag_cta.g_ctas.fec_ult_capitalizacion);                
               -- genero el movimiento por cambio de estado
               r_gmovi.cod_usuario     := user;
               r_gmovi.hora            := v_hora;
               r_gmovi.fecha           := v_fecha;
               r_gmovi.cod_modulo      := r_cccom.cod_modulo;
               r_gmovi.cod_modalidad   := r_cccom.cod_modalidad;
               r_gmovi.cod_oficina     := r_cccom.cod_oficina;
               r_gmovi.nro_cuenta      := r_cccom.nro_cta_cte;
               r_gmovi.cod_moneda      := cta.cod_moneda;
               r_gmovi.cod_tra_padre   := 310;
               r_gmovi.cod_mod_padre   := r_cccom.cod_modulo;
               r_gmovi.cod_mad_padre   := r_cccom.cod_modalidad;
               r_gmovi.fec_valor       := v_fecha;
               r_gmovi.reversado       := 'N';
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
            ------------------------------------------------------------
            UPDATE ah_cta_vistas
               set sal_total = nvl(sal_total,0) - nvl(cta.disponible,0)
             WHERE CURRENT OF c_ahorros;
         END IF;
      end loop;
      v_cantidad := v_cantidad + 1;
   end loop;
   --vuelve a asignar el programa con el que entró
   pae_cnf.G_PROGRAMA := v_ant_programa;
  /* if v_cantidad = 0 then
      raise_application_error(-20000,'No existen cuentas Combinadas a procesar. Verifique!!');
   end if;*/
EXCEPTION
   WHEN OTHERS THEN
      v_lugar := 'Rehabilitar estado del modulo si hay error para ATM';
      pr_rev_est_modulo;
      raise_application_error(-20000, v_lugar || ' ' || SQLERRM);
END;
/
