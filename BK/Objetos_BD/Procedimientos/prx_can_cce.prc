create or replace procedure it.prx_can_cce(p_nro_cuenta in varchar2) is
/* proceso que cancela en forma automatica la Carta de Crédito de Exportación */
v_fec_actual date := pag_cal.FU_OBT_FEC_ACTUAL(8);
v_nro_secuencia  number := 0;
r_gmovi ge_movimientos%rowtype;
v_cod_tra_padre number(5) := 380;
v_hora varchar2(8) := fug_ini_hora(sysdate,'HH24:MI:SS');
   cursor cuentas is
      select c.con_aladi,c.cod_oficina,c.cod_moneda,
             c.nro_cuenta,c.saldo saldo,c.cod_modulo,
             c.cod_modalidad, sal_mto_utilizado, c.estado
        from cx_cta_exportaciones c, (select nro_cuenta, sum(saldo) sal_mto_utilizado
                                       from cx_embarques 
                                       group by nro_cuenta) x 
       where c.nro_cuenta = p_nro_cuenta
         and c.estado in ('U','A') -- UTILIZADA O APROBADA
         and c.saldo > 0
         and x.nro_cuenta(+) = c.nro_cuenta;
begin
   for r1 in cuentas loop
    -- borro las transacciones prohibidas
  	 Delete from GE_TRA_PROHIBIDAS
  	  where NRO_CUENTA = r1.nro_cuenta;

    --- GENERAR MOVIMIENTOS
       r_gmovi.cod_usuario    := user;
       r_gmovi.hora           := v_hora;
       r_gmovi.fecha          := v_fec_actual;
       r_gmovi.nro_cuenta     := r1.nro_cuenta;
       r_gmovi.cod_modulo     := r1.cod_modulo;
       r_gmovi.cod_modalidad  := r1.cod_modalidad;
       r_gmovi.cod_oficina    := r1.cod_oficina;

       r_gmovi.cod_moneda     := r1.cod_moneda;
       r_gmovi.est_cuenta     := null;
       r_gmovi.cod_tra_padre  := v_cod_tra_padre;
       r_gmovi.cod_mod_padre  := r1.cod_modulo;
       r_gmovi.cod_mad_padre  := r1.cod_modalidad;
       r_gmovi.fec_valor      := v_fec_actual;
       r_gmovi.reversado      := 'N';
       r_gmovi.protegido      := 'N';
       r_gmovi.estado         := 'N';
       r_gmovi.cod_ofi_origen := r1.cod_oficina;
       r_gmovi.nro_documento  := r1.nro_cuenta;

       r_gmovi.emi_aviso      := 'S';

       r_gmovi.cotizacion     := null;
       r_gmovi.cod_causa      := null;
       IF nvl(r1.saldo,0) - nvl(r1.sal_mto_utilizado,0) > 0 THEN
           v_nro_secuencia        := v_nro_secuencia + 1;
           r_gmovi.nro_secuencia  := v_nro_secuencia;       
           r_gmovi.cod_transaccion := 378;        
           r_gmovi.monto          := nvl(r1.saldo,0) - nvl(r1.sal_mto_utilizado,0);       
           r_gmovi.concepto       := 'Canc.Autom. CC:  '|| r1.nro_cuenta;       
           pag_gen.pr_ins_ge_movimiento(r_gmovi);
       end if;
		 	 --generar movimiento x monto del saldo del mto utilizado
       if nvl(r1.sal_mto_utilizado,0) > 0 then
          v_nro_secuencia        := v_nro_secuencia + 1;
          r_gmovi.nro_secuencia  := v_nro_secuencia;
          r_gmovi.cod_transaccion := 379;
          r_gmovi.monto          := r1.sal_mto_utilizado;
          r_gmovi.concepto       := 'Cancelac. Saldo Mto.Utilizado';
          pag_gen.pr_ins_ge_movimiento(r_gmovi);
       end if;--saldo mto utilizado
        -- cambio de estado
        v_nro_secuencia        := v_nro_secuencia + 1;
        r_gmovi.nro_secuencia  := v_nro_secuencia;
        r_gmovi.cod_transaccion := 401;
        r_gmovi.monto          := null;
        r_gmovi.est_cuenta     := 'C';
        r_gmovi.concepto       := 'Cambio de estado: Cancelación';
        r_gmovi.cod_causa      := fug_obt_pardinamico('COD_CAU_CAN_AUTOMATICA',r1.cod_modulo, r1.cod_modalidad,r1.cod_moneda,r1.cod_oficina);
        pag_gen.pr_ins_ge_movimiento(r_gmovi);
  		  PRG_GEN_NOV_CUENTA(v_fec_actual, v_hora, user,
                  r1.nro_cuenta,r1.cod_modulo,
                  r1.cod_modalidad, r1.estado, 'C',
                  null);
       -- actualizacion de embarques y cuotas
       update cx_embarques 
          set saldo = 0,
              estado = 'C' -- cancelado            
        where nro_cuenta = r1.nro_cuenta
          and saldo > 0
          and estado not in ('P');
       update cx_cuotas
          set saldo = 0,
              estado = 'C' -- cancelado            
        where nro_cuenta = r1.nro_cuenta
          and saldo > 0
          and estado not in ('P');        
 
       -- actualizacion del estado
       update cx_cta_exportaciones
          set estado = 'C',
              fec_cancelacion = v_fec_actual,
        		  cod_cau_cancelacion = r_gmovi.cod_causa,
        	  	saldo = 0
        where nro_cuenta = r1.nro_cuenta;
    end loop;
end;
/

