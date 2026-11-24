create or replace procedure it.prb_cua_142 is
--Concilia cuentas de la 142 cámara extranjera
 v_fec_anterior date := pag_cal.FU_OBT_FEC_ANTERIOR(1)-1;
 v_fec_max        date;
 v_fec          date;
 
   --Concilia por nro_documento, moneda, monto
   cursor c_cuadre_doc is
   select * from cb_cua_142_det_tmp x
   where x.tip_mov='C' 
   and exists(select 1 from cb_cua_142_det_tmp c
   where c.monto=x.monto
   and c.cod_moneda=x.cod_moneda
   and c.nro_documento=x.nro_documento
   and c.mov_cuadre is null)
   and x.mov_cuadre is null
   for update of mov_cuadre
   order by fecha;
   --Concilia por nro_cuenta, moneda, monto
   cursor c_cuadre_Cta is
   select * from cb_cua_142_det_tmp x
   where x.tip_mov='C' 
   and exists(select 1 from cb_cua_142_det_tmp c
   where c.monto=x.monto
   and c.cod_moneda=x.cod_moneda
   and c.nro_cuenta=x.nro_cuenta
   and c.mov_cuadre is null)
   and x.mov_cuadre is null
   for update of mov_cuadre
   order by fecha;
   --Concilia por total de documento y cuenta
   cursor c_cuadre_tot is
   select * from cb_cua_142_det_tmp x
   where x.tip_mov='C' 
   and x.mov_cuadre is null
   for update of mov_cuadre
   order by fecha;
   --Concilia directo por monto y cuenta, pero al credito
   cursor c_cuadre_deb is
   select t.nro_cuenta, t.nro_documento, t.cod_moneda, sum(t.monto) monto, max(t.fecha) fecha
   from cb_cua_142_det_tmp t
   where t.mov_cuadre is null
   and t.tip_mov='D'
   group by t.nro_cuenta, t.nro_documento, t.cod_moneda;

   v_cuadre          number(10);
   v_fecha           cb_cua_142_det_tmp.fecha%type;
   v_hora            cb_cua_142_det_tmp.hora%type;
   v_cod_usuario     cb_cua_142_det_tmp.cod_usuario%type;
   v_nro_secuencia   cb_cua_142_det_tmp.nro_secuencia%type;
   v_tot_monto       cb_cua_142_det_tmp.monto%type;
begin

   select max(fecha) into v_fec_max from cb_cua_142_det_tmp;
   
   execute immediate 'truncate table cb_cua_142_det_tmp';
   
   if v_fec_max is null then
   v_fec:= v_fec_anterior;
   else
   v_fec:=v_fec_max;
   end if;
  --se insertan los datos del día anterior  
  insert into cb_cua_142_det_tmp 
   select distinct d.fecha, d.cod_usuario, d.hora, d.nro_secuencia,  d.nro_cuenta,
   d.monto, d.cod_moneda, d.mto_equ_local, d.cotizacion, d.cod_oficina, d.cod_ofi_origen, d.cod_banco, d.concepto, d.nro_documento, 
   d.cod_transaccion, d.cod_modulo, d.cod_modalidad, d.nro_documento4, d.cod_retencion, e.nro_asiento, e.nro_linea, e.descripcion, e.tip_movimiento tip_mov, 0 mov_cuadre
    from cb_asi_automaticos_det e, gv_movimientos d
   where e.fecha >v_fec
   and e.cod_rubro = '221101420200105'
   and e.FECHA=d.fecha
   and d.REVERSADO='N'
   and d.NRO_DOCUMENTO4=e.ref_movimiento;
   
   update cb_cua_142_det_tmp
      set mov_cuadre = null
    where mov_cuadre is not null
      and mov_cuadre not in (9999999997,9999999998,9999999999);
   v_cuadre := 1;
   --- Cuadro directo por cheque y nro.
   for reg in c_cuadre_doc loop
      --- Buscar movimiento de dèbito que le corresponda
      begin
         select fecha, hora, cod_usuario, nro_secuencia
           into v_fecha, v_hora, v_cod_usuario, v_nro_secuencia
           from cb_cua_142_det_tmp x
          where tip_mov='D'
            and monto= reg.monto
            and cod_moneda=reg.cod_moneda
            and x.cod_ofi_origen = reg.cod_oficina
            and mov_cuadre is null
            and rownum=1
            and x.nro_documento=reg.nro_documento;
      --- Si existe movimiento, actualizar mov_cuadre del dèbito
      update cb_cua_142_det_tmp
         set mov_cuadre = v_cuadre
       where fecha = v_fecha
         and hora = v_hora
         and cod_usuario = v_cod_usuario
         and nro_secuencia = v_nro_secuencia
         and monto = reg.monto
         and cod_moneda = reg.cod_moneda
         and cod_ofi_origen = reg.cod_oficina
         and nro_documento=reg.nro_documento
         and tip_mov='D'
         and rownum=1
         and mov_cuadre is null;
      --- Actualizar mov_cuadre del crédito
      update cb_cua_142_det_tmp
         set mov_cuadre = v_cuadre
       where current of c_cuadre_doc;
      v_cuadre := v_cuadre + 1;
      exception
         when no_data_found then null;
         when too_many_rows then null;
      end;
   end loop;

   --- Cuadro por total de documento y cuenta
   for reg in c_cuadre_tot loop
      --- Buscar movimiento de dèbito que le corresponda
       select nvl(sum(x.monto),0)
         into v_tot_monto
         from cb_cua_142_det_tmp x
        where tip_mov='D'
          and cod_moneda=reg.cod_moneda
          and mov_cuadre is null
          and x.nro_documento=reg.nro_documento
          and x.nro_cuenta=reg.nro_cuenta;
      --- Si existe movimiento, actualizar mov_cuadre del dèbito
      if v_tot_monto = reg.monto then
        update cb_cua_142_det_tmp
           set mov_cuadre = v_cuadre
         where cod_moneda = reg.cod_moneda
           and nro_cuenta=reg.nro_cuenta
           and nro_documento=reg.nro_documento
           and tip_mov='D'
           and mov_cuadre is null;
        --- Actualizar mov_cuadre del crédito
        update cb_cua_142_det_tmp
           set mov_cuadre = v_cuadre
         where current of c_cuadre_tot;
        v_cuadre := v_cuadre + 1;
      end if;
   end loop;
   --- Cuadro directo por monto y cuenta
   for reg in c_cuadre_cta loop
      --- Buscar movimiento de dèbito que le corresponda
      begin
         select fecha, hora, cod_usuario, nro_secuencia
           into v_fecha, v_hora, v_cod_usuario, v_nro_secuencia
           from cb_cua_142_det_tmp x
          where tip_mov='D'
            and monto= reg.monto
            and cod_moneda=reg.cod_moneda
            and mov_cuadre is null
            and x.nro_cuenta=reg.nro_cuenta
                and to_date(to_char(x.fecha,'ddmmyyyy')||' '||x.hora, 'ddmmyyyy hh24:mi:ss') =
                (select min(to_date(to_char(fecha,'ddmmyyyy')||' '||hora, 'ddmmyyyy hh24:mi:ss'))
                   from cb_cua_142_det_tmp y
                  where y.tip_mov=x.tip_mov
                    and y.monto=x.monto
                    and y.cod_moneda=x.cod_moneda
                    and y.nro_cuenta=x.nro_cuenta
                    and y.mov_cuadre is null
                    and y.fecha >= reg.fecha);
      --- Si existe movimiento, actualizar mov_cuadre del dèbito
      update cb_cua_142_det_tmp
         set mov_cuadre = v_cuadre
       where fecha = v_fecha
         and hora = v_hora
         and cod_usuario = v_cod_usuario
         and nro_secuencia = v_nro_secuencia
         and monto = reg.monto
         and cod_moneda = reg.cod_moneda
         and nro_cuenta=reg.nro_cuenta
         and tip_mov='D'
         and rownum=1
         and mov_cuadre is null;
      --- Actualizar mov_cuadre del crédito
      update cb_cua_142_det_tmp
         set mov_cuadre = v_cuadre
       where current of c_cuadre_cta;
      v_cuadre := v_cuadre + 1;
      exception
         when no_data_found then null;
         when too_many_rows then null;
      end;
   end loop;
   --- Cuadro directo por monto y cuenta, pero al credito
   for reg in c_cuadre_deb loop
      --- Buscar movimiento de dèbito que le corresponda
      begin
         select fecha, hora, cod_usuario, nro_secuencia
           into v_fecha, v_hora, v_cod_usuario, v_nro_secuencia
           from cb_cua_142_det_tmp x
          where tip_mov='C'
            and monto= reg.monto
            and cod_moneda=reg.cod_moneda
            and mov_cuadre is null
            and x.nro_cuenta=reg.nro_cuenta
                and to_date(to_char(x.fecha,'ddmmyyyy')||' '||x.hora, 'ddmmyyyy hh24:mi:ss') =
                (select min(to_date(to_char(fecha,'ddmmyyyy')||' '||hora, 'ddmmyyyy hh24:mi:ss'))
                   from cb_cua_142_det_tmp y
                  where y.tip_mov=x.tip_mov
                    and y.monto=x.monto
                    and y.cod_moneda=x.cod_moneda
                    and y.nro_cuenta=x.nro_cuenta
                    and y.mov_cuadre is null
                    and y.fecha <= reg.fecha);
      --- Si existe movimiento, actualizar mov_cuadre del dèbito
      update cb_cua_142_det_tmp
         set mov_cuadre = v_cuadre
       where fecha = v_fecha
         and hora = v_hora
         and cod_usuario = v_cod_usuario
         and nro_secuencia = v_nro_secuencia
         and monto = reg.monto
         and cod_moneda = reg.cod_moneda
         and nro_cuenta=reg.nro_cuenta
         and tip_mov='C'
         and rownum=1
         and mov_cuadre is null;
      --- Actualizar mov_cuadre del crédito
      update cb_cua_142_det_tmp
         set mov_cuadre = v_cuadre
       where nro_cuenta = reg.nro_cuenta
         and cod_moneda= reg.cod_moneda
         and tip_mov='D'
         and mov_cuadre is null
         and nro_documento = reg.nro_documento;
      v_cuadre := v_cuadre + 1;
      exception
         when no_data_found then null;
         when too_many_rows then null;
      end;
   end loop;
   
end prb_cua_142;
/

