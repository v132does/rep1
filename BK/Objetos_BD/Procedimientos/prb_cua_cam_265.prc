CREATE OR REPLACE PROCEDURE IT."PRB_CUA_CAM_265" is
--- Proceso de cuadre de cámara extranjera 265 (USD).
--- Realizado por Ingrid L. 27/04/2010.
   v_fec_anterior date := pag_cal.FU_OBT_FEC_ANTERIOR(1);
   cursor c_cuadre is
   select * from cb_cuadra_265_tmp
   where tip_mov = 'C'
   and mov_cuadre is null
   and fecha=v_fec_anterior
   for update of mov_cuadre
   order by fecha;

   cursor c_cuadre_doc is
   select * from cb_cuadra_265_tmp x
   where x.tip_mov='C'
   and exists(select 1 from cb_cuadra_265_tmp c
   where c.monto=x.monto
   and c.cod_moneda=x.cod_moneda
   and c.nro_documento=x.nro_documento
   and c.mov_cuadre is null)
   and x.mov_cuadre is null
   and fecha=v_fec_anterior
   for update of mov_cuadre
   order by fecha;

   v_cuadre          number(4);
   v_fecha           cb_cuadra_265_tmp.fecha%type;
   v_hora            cb_cuadra_265_tmp.hora%type;
   v_cod_usuario     cb_cuadra_265_tmp.cod_usuario%type;
   v_nro_secuencia   cb_cuadra_265_tmp.nro_secuencia%type;

   ---nuevo bloque
v_count number:=0;
cursor gv_mov_cbasi is
select distinct d.fecha, d.cod_usuario, d.hora, d.nro_secuencia,
    t.monto, d.cod_moneda, decode(t.cod_moneda,'GS',t.monto,round(t.monto*d.COTIZACION,0)) mto_equ_local, d.cotizacion,
    d.cod_oficina, d.cod_ofi_origen, d.cod_banco, d.concepto, t.nro_documento,
    d.cod_transaccion, d.cod_modulo, d.cod_modalidad, d.nro_documento4, d.COD_RETENCION, e.nro_asiento, e.nro_linea, e.descripcion, 'D' tipo, null mvto
    from gv_movimientos d, cb_asi_automaticos_det e, cj_movimientos_his t, gv_movimientos v
    where d.fecha = v_fec_anterior
    and d.COD_TRANSACCION=906
    and e.fecha=d.FECHA
    and d.reversado='N'
    and e.ref_movimiento=d.NRO_DOCUMENTO4
    and t.FECHA=pag_cal.FU_OBT_FEC_ANT_HAB(d.FECHA,t.COD_OFICINA)
    and t.NRO_CAJA=d.NRO_CAJA
    and t.COD_OFICINA=d.COD_OFI_origen
    and t.estado='N'
    and t.COD_MONEDA=d.COD_MONEDA
    and t.cod_tra_padre = 133
    AND NVL(D.NRO_CUENTA,-1)=NVL(V.NRO_CUENTA,-1)
    and t.nro_doc_referencia=v.NRO_DOCUMENTO
    and v.FECHA=t.fecha
    and v.COD_USUARIO=t.cod_usuario
    and v.NRO_CAJA=t.nro_caja
    and t.monto > 0
    and v.cod_transaccion in (610,632)
    and v.REVERSADO='N'
    and d.MONTO=v.MONTO
    and d.COD_MONEDA=v.COD_MONEDA
    and e.cod_rubro='150102570202505'
    order by 4,5,13;
   ---

begin
   -- INSERTA DETALLES PARA EL CUADRE
   delete cb_cuadra_265_tmp
   where fecha = v_fec_anterior;
   -- Detalle de envios a cámara
    insert into cb_cuadra_265_tmp
    select distinct d.fecha, d.cod_usuario, d.hora, d.nro_secuencia,
    d.monto, d.cod_moneda, d.mto_equ_local, d.cotizacion, d.cod_oficina, d.cod_ofi_origen, d.cod_banco, d.concepto, d.nro_documento,
    d.cod_transaccion, d.cod_modulo, d.cod_modalidad, d.nro_documento4, d.cod_retencion, e.nro_asiento, e.nro_linea, e.descripcion, 'C' tip_mov, 0 mvto
    from gv_movimientos d, cb_asi_automaticos_det e
    where d.fecha = v_fec_anterior
    and d.cod_transaccion =185
    and d.cod_modalidad = 41
    and d.cod_modulo=4
    and d.reversado='N'
    and e.fecha=d.FECHA
    and e.ref_movimiento=d.NRO_DOCUMENTO4
    and e.cod_rubro='150102570202505';

    --DETALLE DE DEPOSITOS
    insert into cb_cuadra_265_tmp
    select distinct d.fecha, d.cod_usuario, d.hora, d.nro_secuencia,
    t.monto, d.cod_moneda, decode(t.cod_moneda,'GS',t.monto,round(t.monto*d.COTIZACION,0)) mto_equ_local,
    d.cotizacion, d.cod_oficina, d.cod_ofi_origen, d.cod_banco, d.concepto, t.nro_documento,
    d.cod_transaccion, d.cod_modulo, d.cod_modalidad, d.nro_documento4, d.cod_retencion, e.nro_asiento, e.nro_linea, e.descripcion, 'D', null mvto
    from gv_movimientos d, cb_asi_automaticos_det e, cj_movimientos_his t
    where d.fecha = v_fec_anterior
    and nvl(d.cod_retencion,0) > 0
    and e.fecha=d.FECHA
    and d.reversado='N'
    and e.ref_movimiento=d.NRO_DOCUMENTO4
    and t.FECHA=d.FECHA
    and t.NRO_CAJA=d.NRO_CAJA
    and t.cod_usuario = d.cod_usuario
    and t.COD_OFICINA=d.COD_OFI_origen
    and t.estado='N'
    and t.COD_MONEDA=d.COD_MONEDA
    and t.cod_tra_padre = 133
    and t.nro_doc_referencia=d.NRO_DOCUMENTO
    and t.monto > 0
    and d.cod_transaccion in (607,610,632)
    and e.cod_rubro='150102570202505';

/*    --DETALLE 906
    insert into cb_cuadra_265_tmp
    select distinct d.fecha, d.cod_usuario, d.hora, d.nro_secuencia,
    t.monto, d.cod_moneda, decode(t.cod_moneda,'GS',t.monto,round(t.monto*d.COTIZACION,0)) mto_equ_local, d.cotizacion,
    d.cod_oficina, d.cod_ofi_origen, d.cod_banco, d.concepto, t.nro_documento,
    d.cod_transaccion, d.cod_modulo, d.cod_modalidad, d.nro_documento4, d.COD_RETENCION, e.nro_asiento, e.nro_linea, e.descripcion, 'D' tipo, null mvto
    from gv_movimientos d, cb_asi_automaticos_det e, cj_movimientos_his t, gv_movimientos v
    where d.fecha = v_fec_anterior
    and d.COD_TRANSACCION=906
    and e.fecha=d.FECHA
    and d.reversado='N'
    and e.ref_movimiento=d.NRO_DOCUMENTO4
    and t.FECHA=pag_cal.FU_OBT_FEC_ANT_HAB(d.FECHA,t.COD_OFICINA)
    and t.NRO_CAJA=d.NRO_CAJA
    and t.COD_OFICINA=d.COD_OFI_origen
    and t.estado='N'
    and t.COD_MONEDA=d.COD_MONEDA
    and t.cod_tra_padre = 133
    AND NVL(D.NRO_CUENTA,-1)=NVL(V.NRO_CUENTA,-1)
    and t.nro_doc_referencia=v.NRO_DOCUMENTO
    and v.FECHA=t.fecha
    and v.COD_USUARIO=t.cod_usuario
    and v.NRO_CAJA=t.nro_caja
    and t.monto > 0
    and v.cod_transaccion in (610,632)
    and v.REVERSADO='N'
    and d.MONTO=v.MONTO
    and d.COD_MONEDA=v.COD_MONEDA
    and e.cod_rubro='150102570202505';*/



----bloqu nuevo
  begin
      for rec in gv_mov_cbasi loop
         select count(*) into v_count from  cb_cuadra_265_tmp where nro_documento=rec.nro_documento and monto=rec.monto and cod_transaccion=906;
         if v_count = 0 then
            insert into cb_cuadra_265_tmp(
            FECHA,COD_USUARIO,HORA,NRO_SECUENCIA,MONTO,COD_MONEDA,MTO_EQU_LOCAL,COTIZACION,COD_OFICINA,
            COD_OFI_ORIGEN,COD_BANCO,CONCEPTO,NRO_DOCUMENTO,COD_TRANSACCION,COD_MODULO,COD_MODALIDAD,
            NRO_DOCUMENTO4,COD_RETENCION,NRO_ASIENTO,NRO_LINEA,DESCRIPCION,TIP_MOV,MOV_CUADRE
            )
            values(rec.fecha,rec.cod_usuario,rec.hora,
            rec.nro_secuencia,rec.monto,rec.cod_moneda,rec.mto_equ_local,rec.cotizacion,
            rec.cod_oficina,rec.cod_ofi_origen,rec.cod_banco,rec.concepto,
            rec.nro_documento,rec.cod_transaccion,rec.cod_modulo,rec.cod_modalidad,
            rec.nro_documento4,rec.cod_retencion,rec.nro_asiento,rec.nro_linea,rec.descripcion,'D',null);
         end if;
      end loop;

  exception when OTHERS then
            null;
  end;
----





   -- REALIZA EL CUADRE
   update cb_cuadra_265_tmp
      set mov_cuadre = null
    where mov_cuadre is not null
      and mov_cuadre not in (99997,99998,99999)
      and fecha = v_fec_anterior;
   v_cuadre := 1;
   --- Cuadro directo por cheque y nro.
   for reg in c_cuadre_doc loop
      --- Buscar movimiento de dèbito que le corresponda
      begin
         select fecha, hora, cod_usuario, nro_secuencia
           into v_fecha, v_hora, v_cod_usuario, v_nro_secuencia
           from cb_cuadra_265_tmp x
          where tip_mov='D'
            and monto= reg.monto
            and cod_moneda=reg.cod_moneda
            and x.cod_ofi_origen = reg.cod_oficina
            and mov_cuadre is null
            and fecha=v_fec_anterior
            and rownum=1
            and x.nro_documento=reg.nro_documento;
      --- Si existe movimiento, actualizar mov_cuadre del dèbito
      update cb_cuadra_265_tmp
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
         and fecha=v_fec_anterior
         and mov_cuadre is null;
      --- Actualizar mov_cuadre del crédito
      update cb_cuadra_265_tmp
         set mov_cuadre = v_cuadre
       where current of c_cuadre_doc;
      v_cuadre := v_cuadre + 1;
      exception
         when no_data_found then null;
         when too_many_rows then null;
      end;
   end loop;

   -- Cuadro el resto
   for reg in c_cuadre loop
      --- Buscar movimiento de dèbito que le corresponda
      begin
         select fecha, hora, cod_usuario, nro_secuencia
           into v_fecha, v_hora, v_cod_usuario, v_nro_secuencia
           from cb_cuadra_265_tmp x
          where tip_mov='D'
            and monto= reg.monto
            and cod_moneda=reg.cod_moneda
            and x.cod_ofi_origen = reg.cod_oficina
            and mov_cuadre is null
            and fecha=v_fec_anterior
            and rownum=1
            and to_date(to_char(fecha,'ddmmyyyy')||' '||hora, 'ddmmyyyy hh24:mi:ss') =
                (select min(to_date(to_char(fecha,'ddmmyyyy')||' '||hora, 'ddmmyyyy hh24:mi:ss'))
                   from cb_cuadra_265_tmp y
                  where y.tip_mov=x.tip_mov
                    and y.monto=x.monto
                    and y.cod_moneda=y.cod_moneda
                    and x.cod_ofi_origen = y.cod_ofi_origen
                    and y.mov_cuadre is null
                    and y.fecha = reg.fecha);
      --- Si existe movimiento, actualizar mov_cuadre del dèbito
      update cb_cuadra_265_tmp
         set mov_cuadre = v_cuadre
       where fecha = v_fecha
         and hora = v_hora
         and cod_usuario = v_cod_usuario
         and nro_secuencia = v_nro_secuencia
         and monto = reg.monto
         and cod_moneda = reg.cod_moneda
         and cod_ofi_origen = reg.cod_oficina
         and tip_mov='D'
         and rownum=1
         and fecha=v_fec_anterior
         and mov_cuadre is null;
      --- Actualizar mov_cuadre del crédito
      update cb_cuadra_265_tmp
         set mov_cuadre = v_cuadre
       where current of c_cuadre;
      v_cuadre := v_cuadre + 1;
      exception
         when no_data_found then null;
         when too_many_rows then null;
      end;
   end loop;
end;
/

