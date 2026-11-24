create or replace procedure it.prx_act_fia_comisiones
(p_cod_fianza in number default null, 
 p_nro_cuota in number default null, 
 p_monto in number default null) is
v_saldo  number;
cursor c_cobros is
       select nro_documento cod_fianza, nro_documento2 nro_cuota, monto
         from ge_movimientos a
        where cod_mod_padre = 8
          and cod_mad_padre in (87,88,89)
          and estado = 'N'
          and reversado = 'N'
          and cod_tra_padre = 580
          and exists (select 0 from cx_fia_comisiones x
                       where x.cod_fianza = a.nro_documento
                         and x.nro_cuota = a.nro_documento2
                         and x.estado in ('A','V')
                         and x.saldo > 0)
          and cod_transaccion = 580; 
begin
   if p_cod_fianza is null then
      -- es una actualizacion masiva
      for cb in c_cobros loop
          prx_act_fia_comisiones(cb.cod_fianza, cb.nro_cuota, cb.monto);
      end loop;
   else
       update cx_fia_comisiones
          set fec_ult_pago = pag_cal.FU_OBT_FEC_ACTUAL(8),
              saldo = nvl(saldo,0) - nvl(p_monto,0)
        where cod_fianza = p_cod_fianza
          and nro_cuota = p_nro_cuota
        returning saldo into  v_saldo;
       if v_saldo = 0 then
         update cx_fia_comisiones
            set estado = 'P'
          where cod_fianza = p_cod_fianza
            and nro_cuota = p_nro_cuota;
       end if;
       if sql%notfound then
          raise_application_error(-20000,'No se puede actualizar la fianza: '||p_cod_fianza||' Cuota: '||p_nro_cuota);
       
       end if;
   end if;
end;
/

