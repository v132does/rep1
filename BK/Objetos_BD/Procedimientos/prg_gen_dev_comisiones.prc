create or replace procedure it.PRG_GEN_DEV_COMISIONES
is
   v_fec_actual date := pag_cal.FU_OBT_FEC_ACTUAL(1);
   v_redondeo          number(5);
   v_cotizacion        ge_cotizaciones.val_conversion%type;
   v_tot_mon_local     NUMBER;
   v_mon_local         ba_monedas.cod_moneda%type :=  pag_gen.fu_obt_mon_local;
   --- Movimientos del día
   cursor rg_movi is
   select a.*
   from   ge_movimientos a, ge_transacciones b
   where  a.cod_modulo = b.cod_modulo
   and    a.cod_modalidad = b.cod_modalidad
   and    a.cod_transaccion = b.cod_transaccion
   and    b.cod_tip_asi_resultado is not null
   and    a.fecha = v_fec_actual
   and    a.estado = 'N'
   and    a.fec_fin_retencion is not null;
begin
   begin pre_ini_aplicacion;pae_cnf.g_cod_modulo:=1;end;
   for i in rg_movi loop
      if i.reversado = 'N' then
         if v_mon_local = i.cod_moneda then
            v_cotizacion    := 0;
            v_redondeo      := 0;
            v_tot_mon_local := 0;
         else
            v_cotizacion := pag_gen.FU_OBT_COTIZACION(i.cod_moneda,v_fec_actual);
            v_redondeo   := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',7,i.cod_modalidad,v_mon_local);
            v_tot_mon_local := ROUND(NVL(v_cotizacion,0) * i.monto,v_redondeo);
         end if;
         insert into ge_mov_diferidos (
         cod_mov_diferido,fecha,hora,cod_usuario,nro_secuencia,
         monto,mto_equ_local,cod_moneda,nro_cuenta,
         cod_modulo,cod_modalidad,cod_transaccion,concepto,
         fec_inicio,fec_vencimiento,estado,
         mto_dev_anterior,mto_dev_actual,mto_dev_acumulado,can_dia_actual,can_dia_anterior,
         cod_oficina,fec_ult_proceso)
         values (
         S_COD_MOV_DIFERIDO.NEXTVAL,i.fecha,i.hora,i.cod_usuario,i.nro_secuencia,
         i.monto,nvl(i.mto_equ_local,v_tot_mon_local),i.cod_moneda,i.referencia,
         i.cod_modulo,i.cod_modalidad,i.cod_transaccion,i.concepto,
         i.fecha,i.fec_fin_retencion,'N',
         0,0,0,0,0,
         i.cod_oficina,i.fecha);
      elsif i.reversado = 'S' then
         update ge_mov_diferidos m
         set    m.estado = 'R'
               ,m.fec_ult_proceso = i.fecha
               ,m.mto_dev_acumulado = mto_dev_acumulado * -1
               ,m.can_dia_actual = 0
         where  m.fecha = i.fec_valor
         and    m.hora = i.hor_reversion
         and    m.cod_usuario = i.cod_usuario
         and    m.nro_secuencia = i.nro_secuencia;
      end if;
   end loop;
end;
/

