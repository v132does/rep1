create or replace procedure it.PRX_GEN_UTI_OVERNIGHT
is
   v_fecha date := pag_cal.fu_obt_fec_actual(8);
   cursor c_depositos is
   select c.nro_cuenta, c.cod_moneda, c.cod_oficina, nvl(b.ind_grupo,'N') ind_grupo,
          a.cod_modulo, a.cod_modalidad, sum(c.mto_interes) mto_interes
   from   cc_cta_bancarias a, ge_bancos b, cx_dep_overnight c
   where  a.cod_banco = b.cod_banco
   and    a.nro_cuenta = c.nro_cuenta
   group by c.nro_cuenta, c.cod_moneda, c.cod_oficina, nvl(b.ind_grupo,'N'), a.cod_modulo, a.cod_modalidad;

   v_cod_transaccion  ge_transacciones.cod_transaccion%type;
   r_gmovi            ge_movimientos%rowtype;
   v_hora             ge_movimientos.hora%type := fug_ini_hora(sysdate,'hh24:mi:ss');
   v_nro_secuencia    ge_movimientos.nro_secuencia%type := 0;
   v_max_fecha        date;
   v_ofi_matriz       ba_oficinas.cod_oficina%type := FUN_OBT_OFI_MATRIZ;
   v_fec_hasta        date;
begin
   begin pre_ini_aplicacion;pae_cnf.g_cod_modulo:=1;end;

   begin
      select max(fecha)
      into   v_max_fecha
      from   xv_dep_overnight;
   exception
       when no_data_found then
          v_max_fecha := null;
       when others then
          raise_application_error(-20000, 'ERROR. Obt.Max.Fecha '||sqlerrm);
   end;

   v_fec_hasta := v_fecha; --add_months(v_fecha,-1);
   v_fec_hasta :=  last_day(to_date('01/'||to_char(v_fec_hasta,'MM/YYYY'),'DD/MM/YYYY'));
   v_fec_hasta := pag_cal.FU_OBT_FEC_HABIL(v_fec_hasta,-1,null);
   v_hora      := fug_obt_hor_disponible(v_fecha,v_hora,user,'N');
   if v_max_fecha is not null and
      pag_cal.FU_OBT_FEC_SIG_HAB(v_max_fecha,v_ofi_matriz,1) = v_fec_hasta then
      -- Solo debe correr si es el ultimo dia habil
      for i in c_depositos loop
         v_cod_transaccion := null;

         if nvl(i.ind_grupo,'N') = 'S' then
            v_cod_transaccion := fug_obt_pardinamico('COD_TRA_BCO_GRUPO',
                                                      i.cod_modulo,
                                                      i.cod_modalidad,
                                                      i.cod_moneda,
                                                      i.cod_oficina);
         else
            v_cod_transaccion := fug_obt_pardinamico('COD_TRA_BCO_NO_GRUPO',
                                                      i.cod_modulo,
                                                      i.cod_modalidad,
                                                      i.cod_moneda,
                                                      i.cod_oficina);
         end if;

         if v_cod_transaccion is not null then
            r_gmovi.cod_usuario     := user;
            r_gmovi.hora            := v_hora;
            r_gmovi.fecha           := v_fecha;
            -- Aumento la secuencia
            v_nro_secuencia         := v_nro_secuencia + 1;
            r_gmovi.nro_secuencia   := v_nro_secuencia;
            --
            r_gmovi.cod_modulo      := i.cod_modulo;
            r_gmovi.cod_modalidad   := i.cod_modalidad;
            r_gmovi.nro_cuenta      := i.nro_cuenta;
            r_gmovi.cod_moneda      := i.cod_moneda;
            r_gmovi.fec_valor       := v_fecha;
            r_gmovi.cod_tra_padre   := v_cod_transaccion;
            r_gmovi.cod_mod_padre   := i.cod_modulo;
            r_gmovi.cod_mad_padre   := i.cod_modalidad;
            r_gmovi.cod_oficina     := i.cod_oficina;
            r_gmovi.cod_transaccion := v_cod_transaccion;
            r_gmovi.monto           := i.mto_interes;
            r_gmovi.nro_documento   := i.nro_cuenta;
            r_gmovi.nro_documento2  := null;
            r_gmovi.cod_ofi_origen  := i.cod_oficina;
            r_gmovi.emi_aviso       := 'N';
            r_gmovi.concepto        := 'UTI.DEP.OVERNIGHT CTA.'||i.nro_cuenta;
            r_gmovi.estado          := 'N';
            r_gmovi.reversado       := 'N';
            r_gmovi.cod_rubro       := null;
            r_gmovi.cod_tasa        := null;
            r_gmovi.val_tasa        := null;
            r_gmovi.tip_mov_rubro   := null;--'C';
            r_gmovi.cod_persona     := null;
            r_gmovi.referencia      := i.nro_cuenta;

            PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi);
         else
            raise_application_error(-20000, 'ERROR. No se encontro Transaccion Utilidad '
                                   ||'por Deposito Overnight para Cta '||i.nro_cuenta);
         end if;
      end loop;

      -- transferir al historico
      insert into cx_dep_overnight_his
            (fecha,monto,val_tasa,mto_interes,nro_cuenta,cod_moneda,cod_oficina)
      select fecha,monto,val_tasa,mto_interes,nro_cuenta,cod_moneda,cod_oficina
      from   cx_dep_overnight;

      -- borrar los trasnferidos al historico
      delete cx_dep_overnight;
   end if;
EXCEPTION
 WHEN OTHERS THEN
    raise_application_error(-20000, 'ERROR. Uilidades por Depositos Overnight '||SQLERRM);
end;
/

