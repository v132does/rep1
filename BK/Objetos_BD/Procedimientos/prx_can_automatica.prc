create or replace procedure it.prx_can_automatica is
/* proceso que cancela en forma automatica las operaciones de cci no utilizadas al vencimiento (15 dias de vencido */
v_fec_actual date := pag_cal.FU_OBT_FEC_ACTUAL(8);
v_nro_secuencia  number := 0;
r_gmovi ge_movimientos%rowtype;
v_cod_tra_padre number(5) := 380;
v_hora varchar2(8) := fug_ini_hora(sysdate,'HH24:MI:SS');
   cursor cuentas is
      select c.cod_oficina,c.cod_moneda,c.nro_cuenta,c.saldo saldo,c.cod_modulo, c.cod_modalidad, c.mto_prepago,
             c.estado  
      from cx_cta_importaciones c
      where c.fec_vencimiento <= v_fec_actual - 15
       and c.estado = 'A' -- APROBADO, no utilizado
      union
      select c.cod_oficina,c.cod_moneda,c.nro_cuenta,c.saldo saldo,c.cod_modulo, c.cod_modalidad, 0 mto_prepago,
             c.estado
      from cx_cta_exportaciones c
      where c.fec_vencimiento <= v_fec_actual - 15
       and c.estado = 'A' -- APROBADO, no utilizado      
      union
      select c.cod_oficina,c.cod_moneda,c.nro_cuenta,c.saldo saldo,c.cod_modulo, c.cod_modalidad, 0 mto_prepago,
             c.estado
      from cx_cta_cobranzas c
      where c.fec_vencimiento <= v_fec_actual - 15
       and c.estado = 'A' -- APROBADO, no utilizado        
      union
      select c.cod_oficina,c.cod_moneda,c.nro_cuenta,monto saldo,c.cod_modulo, c.cod_modalidad, 0 mto_prepago,
             c.estado
       from cx_fianzas c
       where c.fec_vencimiento <= v_fec_actual
        and c.estado <> 'C';  
       
begin
   for r1 in cuentas loop
    -- borro las transacciones prohibidas
  	 Delete from GE_TRA_PROHIBIDAS
  	  where NRO_CUENTA = r1.nro_cuenta;
    --- GENERAR MOVIMIENTOS
       v_nro_secuencia        := v_nro_secuencia + 1;
       r_gmovi.nro_secuencia  := v_nro_secuencia;
       r_gmovi.cod_usuario    := user;
       r_gmovi.hora           := v_hora;
       r_gmovi.fecha          := v_fec_actual;
       r_gmovi.nro_cuenta     := r1.nro_cuenta;
       r_gmovi.cod_modulo     := r1.cod_modulo;
       r_gmovi.cod_modalidad  := r1.cod_modalidad;
       r_gmovi.cod_oficina    := r1.cod_oficina;       
       --if r1.con_aladi = 'S' then
          r_gmovi.cod_transaccion := 378; --normal
       --else
       --   r_gmovi.cod_transaccion := 379; --Normal
       --end if;
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
       r_gmovi.concepto       := 'Canc.Autom :  '|| r1.nro_cuenta;
       r_gmovi.emi_aviso      := 'S';
       r_gmovi.monto          := r1.saldo;
       r_gmovi.cotizacion     := null;
       r_gmovi.cod_causa      := null;
       pag_gen.pr_ins_ge_movimiento(r_gmovi);
       -- si hay prepago  
		 	 --generar movimiento x monto prepago si tiene
       if nvl(r1.mto_prepago,0) > 0 then
          v_nro_secuencia        := v_nro_secuencia + 1;
          r_gmovi.nro_secuencia  := v_nro_secuencia;  
          r_gmovi.cod_transaccion := 875; 
          r_gmovi.monto          := r1.mto_prepago * -1; 
          r_gmovi.concepto       := 'Cancelación monto prepago';
          pag_gen.pr_ins_ge_movimiento(r_gmovi);      
       end if;--prepago
       -- cambio de estado
       v_nro_secuencia        := v_nro_secuencia + 1;
       r_gmovi.nro_secuencia  := v_nro_secuencia;  
       r_gmovi.cod_transaccion := 401; 
       r_gmovi.monto          := null; 
       r_gmovi.est_cuenta     := 'C';
       r_gmovi.concepto       := 'Cambio de estado: Cancelación';
       r_gmovi.cod_causa      := fug_obt_pardinamico('COD_CAU_CAN_AUTOMATICA',r1.cod_modulo, r1.cod_modalidad,r1.cod_moneda,r1.cod_oficina);
        
       pag_gen.pr_ins_ge_movimiento(r_gmovi);    
       if r_gmovi.cod_transaccion = 401 and r_gmovi.cod_modalidad not in (88,89) then --fianzas no tiene reversión
       	  PRG_GEN_NOV_CUENTA(v_fec_actual, v_hora, user,
       	                     r1.nro_cuenta,r1.cod_modulo,
       	                     r1.cod_modalidad, r1.estado, 'C',
       	                     null);
       end if;             
       if r1.cod_modalidad = 81 then
           -- actualizacion del estado
           update cx_cta_importaciones
            set estado = 'C',
                fec_cancelacion = v_fec_actual,
            		cod_cau_cancelacion = r_gmovi.cod_causa,
            		saldo = 0
          where nro_cuenta = r1.nro_cuenta;
       elsif r1.cod_modalidad = 82 then
           -- actualizacion del estado
           update cx_cta_exportaciones
            set estado = 'C',
                fec_cancelacion = v_fec_actual,
            		cod_cau_cancelacion = r_gmovi.cod_causa,
            		saldo = 0
          where nro_cuenta = r1.nro_cuenta; 
       elsif r1.cod_modalidad in (83,84) then
           -- actualizacion del estado
           update cx_cta_cobranzas
            set estado = 'C',
                fec_cancelacion = v_fec_actual,
            		cod_cau_cancelacion = r_gmovi.cod_causa,
            		saldo = 0
          where nro_cuenta = r1.nro_cuenta;           
       elsif r1.cod_modalidad in (88,89) then
           -- actualizacion del estado
           update cx_fianzas
            set estado = 'C',
                fec_cancelacion = v_fec_actual,
            		cod_cau_cancelacion = r_gmovi.cod_causa
          where nro_cuenta = r1.nro_cuenta;        
          
       end if;
   end loop;
end;
/

