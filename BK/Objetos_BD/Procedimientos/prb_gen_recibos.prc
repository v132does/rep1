CREATE OR REPLACE PROCEDURE IT.PRB_GEN_RECIBOS (P_COD_PERSONA   IN VARCHAR2 DEFAULT NULL,
                                             P_NRO_CUENTA    IN VARCHAR2 DEFAULT NULL,
                                             P_FECHA         IN DATE     DEFAULT NULL,
                                             P_HORA          IN VARCHAR2 DEFAULT NULL,
                                             P_COD_USUARIO   IN VARCHAR2 DEFAULT NULL) IS
   -- Procedimiento que genera los recibos para las Facturas a Crédito
   v_fec_proceso  date := pag_cal.fu_obt_fec_actual(1);
   v_nro_lin_rec   number(8):= fug_obt_pardinamico('NRO_LIN_RECIBOS');  -- Nro. de Lineas que puede tener una factura
   v_nro_linea     number(8);  -- Cantidad de lineas impresas de la factura
   v_nro_recibo    number;
   v_cod_persona   ba_personas.cod_persona%type;
   v_cod_mon_local ba_monedas.cod_moneda%type := pag_gen.fu_obt_mon_local;
   v_cotizacion    ge_cotizaciones.val_conversion%type;
   v_nro_item      cb_recibos_det.nro_item%type;
   v_fec_desde     ge_calendarios.fec_actual%type;
   v_fec_hasta     ge_calendarios.fec_actual%type;
  cursor cu_facturas is
    --Facturas por Desembolso
    select a.fecha, a.fec_movimiento, a.hor_movimiento, a.usu_movimiento,
           a.nro_timbrado, a.nro_factura, a.cod_persona, a.cod_mod_padre, a.cod_mad_padre,
           a.cod_tra_padre, a.cod_oficina, a.cod_moneda, a.nro_cuenta, a.cotizacion,'N' tip_recibo,
           a.monto
      from cb_fac_recibos a
     where a.fecha between v_fec_desde and v_fec_hasta
       and a.cod_tra_padre = 358 -- Desembolsos
       and (p_cod_persona is null or a.cod_persona = p_cod_persona)
       and p_nro_cuenta is null
       and (p_fecha is null or a.fecha = p_fecha)
       and (p_hora is null or a.hor_movimiento = p_hora)
       and (p_cod_usuario is null or a.usu_movimiento = p_cod_usuario)
       and not exists (select 1 from cb_recibos rc, cb_recibos_det rd
                        where --rc.cod_mod_padre = 6 and  --Comentado para operaciones de Caja
                          rc.cod_tra_padre = 358
                          and rd.nro_cuenta =  a.nro_cuenta
                          and rd.nro_timbrado = a.nro_timbrado
                          and rd.nro_factura = a.nro_factura
                          and rc.nro_recibo = rd.nro_recibo
                          --and nvl(rc.anulado, 'N') <> 'S' --Comentado porque los recibos si se anulan, no se debe volver a generarse
                          )
     group by a.fecha, a.fec_movimiento, a.hor_movimiento, a.usu_movimiento,
              a.nro_timbrado, a.nro_factura, a.cod_persona, a.cod_mod_padre, a.cod_mad_padre,
              a.cod_tra_padre, a.cod_oficina, a.cod_moneda, a.nro_cuenta, a.cotizacion,
              a.cod_moneda, a.monto
---DYDMR-8587 Incidencia SAU - ITGF - Moneda Incorrecta de Recibo de Dinero
---NO se debe emitir recibo por factura aun no cobrada
union -- Facturas no cobradas al cliente.
    select pag_cal.fu_obt_fec_actual(1) fecha,
           a.fecha fec_movimiento,
           a.hora hor_movimiento,
           a.cod_usuario usu_movimiento,
           c.nro_timbrado,
           c.nro_factura,
           c.cod_persona,
           a.cod_mod_padre,
           a.cod_mad_padre,
           a.cod_tra_padre,
           a.cod_oficina,
           c.cod_moneda,
           a.nro_cuenta,
           c.cotizacion,
           'N' tip_recibo,
           sum(round((a.monto * decode(nvl(a.cotizacion,1),0,1,nvl(a.cotizacion,1))),0)) monto
      from pr_movimientos_his a,
           pr_cuotas          b,
           cb_fac_recibos     c
     where a.fecha between v_fec_desde and v_fec_hasta
       and (p_cod_persona is null or c.cod_persona = p_cod_persona)
       and (p_nro_cuenta is null or c.nro_cuenta = p_nro_cuenta)
       and a.cod_transaccion in (708,802) -- cobros de facturas ya emitidas.
       and nvl(a.reversado,'N') = 'N'
       and a.estado = 'N'
       and b.nro_cuenta = a.nro_cuenta
       and b.nro_cuota = a.nro_documento3
       and c.nro_cuenta = a.nro_cuenta
       and ((c.nro_cuota is not null and c.nro_cuota = a.nro_documento3)
               or c.nro_cuota is null) --DYDMR-10261
       and c.cod_transaccion = 710 -- Facturas emitidas pero no cobradas.
       --DYDMR-9154 Incidencia SAU - ITGF - Generación de Recibos
       and (c.fec_movimiento = pag_cal.fu_obt_fec_habil(b.fec_vencimiento,1,a.cod_oficina)
            or c.fec_movimiento = pag_cal.FU_OBT_FEC_SIG_HAB(b.fec_vencimiento,a.cod_oficina)
            or c.fec_movimiento = pag_cal.FU_OBT_FEC_ANT_HAB(b.fec_vencimiento,a.cod_oficina))
       --- Cobros de Facturas emitidas en el vto. de cuota
       and ((c.cod_tra_padre = 391 and c.fec_movimiento <= a.fecha)--se reemplaza el "!=" por ">=" --DYDMR-8957
                                     --ya que se puede generar el recibo en el mismo dia inclusive--dydmr-9761
           --- Cobros de Facturas Actuales
            or (c.cod_tra_padre != 391 and c.fec_movimiento = a.fecha))
       and not exists (select 1 from cb_recibos rc, cb_recibos_det rd
                            where nro_cuenta = b.nro_cuenta
                              --and cod_mod_padre = 6  --Comentado para operaciones de Caja
                              and cod_tra_padre in (360,362,359,364)
                              and rc.nro_recibo = rd.nro_recibo
                              and rd.fec_movimiento = a.fecha
                              and rd.hor_movimiento = a.hora
                              and rd.usu_movimiento = a.cod_usuario
                              --and nvl(rc.anulado, 'N') <> 'S' --Comentado porque los recibos si se anulan, no se debe volver a generarse
                              )
     group by pag_cal.fu_obt_fec_actual(1), a.fecha, a.hora, a.cod_usuario,
           c.nro_timbrado, c.nro_factura, c.cod_persona, a.cod_mod_padre,
           a.cod_mad_padre, a.cod_tra_padre, a.cod_oficina, c.cod_moneda,
           a.nro_cuenta, c.cotizacion

---DYDMR-8587 Incidencia SAU - ITGF - Moneda Incorrecta de Recibo de Dinero
---NO se debe emitir recibo por factura aun no cobrada
    union
    select a.fecha,
           a.fecha fec_movimiento,
           a.hora hor_movimiento,
           a.cod_usuario usu_movimiento,
           c.nro_timbrado,
           c.nro_factura,
           c.cod_persona,
           a.cod_mod_padre,
           a.cod_mad_padre,
           a.cod_tra_padre,
           a.cod_oficina,
           c.cod_moneda,
           a.nro_cuenta,
           c.cotizacion,
           'N' tip_recibo, 
           sum(round((a.monto * decode(nvl(a.cotizacion,1),0,1,nvl(a.cotizacion,1))),0)) monto
      from ge_movimientos a,
           pr_cuotas      b,
           cb_fac_recibos c
     where a.cod_transaccion in (708,802) -- cobros de facturas ya emitidas.
       and (p_cod_persona is null or c.cod_persona = p_cod_persona)
       and (p_nro_cuenta is null or c.nro_cuenta = p_nro_cuenta)
       and nvl(a.reversado,'N') = 'N'
       and a.estado = 'N'
       and b.nro_cuenta = a.nro_cuenta
       and b.nro_cuota = a.nro_documento3 -- nro. de cuota
       and c.nro_cuenta = a.nro_cuenta
       and ((c.nro_cuota is not null and c.nro_cuota = a.nro_documento3)
               or c.nro_cuota is null) --DYDMR-10261
       and c.cod_transaccion = 710 -- Facturas emitidas pero no cobradas.
       and c.cod_tra_padre = 391
       and c.fec_movimiento = pag_cal.fu_obt_fec_habil(b.fec_vencimiento,1,a.cod_oficina) -- en la fecha de vto de cuota se emitió la factura.
       --- Cobros de Facturas emitidas en el vto. de cuota
       and ((c.cod_tra_padre = 391 and c.fec_movimiento <= a.fecha)--se reemplaza el "!=" por ">="  --DYDMR-8957
                                     --ya que se puede generar el recibo en el mismo dia inclusive--dydmr-9761
           ---Cobros de Facturas Actuales
            or (c.cod_tra_padre != 391 and c.fec_movimiento = a.fecha))     
       and not exists (select 1 from cb_recibos rc, cb_recibos_det rd
                            where nro_cuenta = b.nro_cuenta
                              --and cod_mod_padre = 6 --Comentado para operaciones de Caja
                              and cod_tra_padre in (360,362,359,364)
                              and rc.nro_recibo = rd.nro_recibo
                              and rd.fec_movimiento = a.fecha
                              and rd.hor_movimiento = a.hora
                              and rd.usu_movimiento = a.cod_usuario
                              --and nvl(rc.anulado, 'N') <> 'S' --Comentado porque los recibos si se anulan, no se debe volver a generarse
                              )
     group by pag_cal.fu_obt_fec_actual(1), a.fecha, a.hora, a.cod_usuario,
           c.nro_timbrado, c.nro_factura, c.cod_persona, a.cod_mod_padre,
           a.cod_mad_padre, a.cod_tra_padre, a.cod_oficina, c.cod_moneda,
           a.nro_cuenta, c.cotizacion
     union 
   --DYDMR-8326 - Incidencia SAU - ITGF - factura generadas     
   --Facturas CR en desembolso cuyos cobro de cuota no cobran iva por que ya fue facturado en el desemb
  select h.fecha,
           h.fecha fec_movimiento,
           h.hora hor_movimiento,
           h.cod_usuario usu_movimiento,
           c.nro_timbrado,
           c.nro_factura,
           c.cod_persona,
           h.cod_mod_padre,
           h.cod_mad_padre,
           h.cod_tra_padre,
           h.cod_oficina,
           c.cod_moneda,
           h.nro_cuenta,
           c.cotizacion,
           'C' tip_recibo,
           --Si la moneda del cobro es GS va directo el monto, caso contrario se calcula el monto por la cotizacion inicial
           sum(round(decode(h.cod_moneda,'GS',h.monto,h.monto * nvl(c.cotizacion,1)))) monto
      from pr_movimientos_his h,
           pr_cuotas      b,
           cb_fac_recibos c
     where
         ---Datos del Cobro Actual
         h.fecha between v_fec_desde and v_fec_hasta
         and h.cod_transaccion in (802) -- cobros de facturas ya emitidas.
         and (p_cod_persona is null or c.cod_persona = p_cod_persona)
         and (p_nro_cuenta is null or c.nro_cuenta = p_nro_cuenta)         
         and nvl(h.reversado,'N') = 'N'
         and h.estado = 'N'
         and b.nro_cuenta = h.nro_cuenta
         and b.nro_cuota = h.nro_documento3
         and ((c.nro_cuota is not null and c.nro_cuota = h.nro_documento3)
               or c.nro_cuota is null) --DYDMR-10261
         ---Datos de relación recibo Factura
         and c.nro_cuenta = h.nro_cuenta
         and c.cod_transaccion = 709 -- Facturas emitidas pero no cobradas.
         and c.cod_tra_padre = 358
         and not exists (select 1 from cb_recibos rc, cb_recibos_det rd
                              where nro_cuenta = b.nro_cuenta
                                --and cod_mod_padre = h.cod_mod_padre  --Comentado para operaciones de Caja
                                and cod_tra_padre = h.cod_tra_padre
                                and rc.nro_recibo = rd.nro_recibo
                                and rd.fec_movimiento = h.fecha
                                and rd.hor_movimiento = h.hora
                                and rd.usu_movimiento = h.cod_usuario
                                and nvl(rc.anulado, 'N') <> 'S')
        /* and not exists (select 1 from cb_fac_recibos e
                              where e.nro_cuenta = h.nro_cuenta
                                --and e.cod_mod_padre = h.cod_mod_padre --Comentado para operaciones de Caja
                                and e.cod_tra_padre = h.cod_tra_padre
                                and e.fec_movimiento = h.fecha
                                and e.hor_movimiento = h.hora
                                and e.usu_movimiento = h.cod_usuario)  */                              
       group by pag_cal.fu_obt_fec_actual(1), h.fecha, h.hora, h.cod_usuario,
             c.nro_timbrado, c.nro_factura, c.cod_persona, h.cod_mod_padre,
             h.cod_mad_padre, h.cod_tra_padre, h.cod_oficina, c.cod_moneda,
             h.nro_cuenta, c.cotizacion                
       order by 7, 1,2, 3,4;

  cursor cu_rec_anulados is
    -- Recibos a Anular por Notas de Créditos Generadas.
    select distinct r.nro_recibo
      from cb_lib_ventas v, cb_recibos r, cb_recibos_det d
     where (p_fecha is null and v.fecha between v_fec_desde and v_fec_hasta)
       and v.tip_comprobante = 'N'
       and v.tip_venta = 'CR'
       and r.cod_tra_padre <> 2510
       and nvl(r.anulado, 'N') <> 'S'
       and r.nro_recibo = d.nro_recibo
       and v.nro_tim_referencia = d.nro_timbrado
       and v.nro_fac_referencia = d.nro_factura;

   TYPE cursor1_type IS TABLE OF cu_facturas%ROWTYPE;
   reg cursor1_type;

BEGIN
   PAG_CAL.PR_OBT_DAT_CALENDAR(PAA_DEV.G_COD_MODULO);
   v_fec_desde  :=  pag_cal.G_PRI_DIA_MES_HABIL;
   v_fec_hasta  :=  pag_cal.G_ULT_DIA_MES_HABIL;
   v_nro_item            := 0;
   --RECIBOS POR DESEMBOLSOS
   OPEN cu_facturas;
    LOOP
      FETCH cu_facturas BULK COLLECT INTO reg LIMIT 2500;
      FOR i IN 1 .. reg.count LOOP
        if nvl(v_cod_persona,'-1') <> nvl(reg(i).cod_persona,'-1')
           or v_nro_linea + 1 > v_nro_lin_rec then

           v_nro_recibo := fug_obt_lla_pardinamico('NRO_REC_FAC_CRE', reg(i).cod_mod_padre,
                                                   reg(i).cod_mad_padre, reg(i).cod_moneda, reg(i).cod_oficina)+1;
           prg_act_par_dinamico('NRO_REC_FAC_CRE',reg(i).cod_mod_padre, reg(i).cod_mad_padre, reg(i).cod_moneda, reg(i).cod_oficina, v_nro_recibo);


           if reg(i).cod_moneda <> v_cod_mon_local then
             --DYDMR-8326 - Incidencia SAU - ITGF - factura generadas
             if reg(i).tip_recibo = 'C' then ---Tipo de Recibo por factura a cuota
                v_cotizacion := reg(i).cotizacion;
             else ---Tipo de Recibo cobro Normal 
                v_cotizacion := fug_obt_cotizacion(reg(i).cod_moneda, v_fec_proceso); 
             end if;
             
           else
             v_cotizacion := null;
           end if;
           begin
             insert into cb_recibos ( nro_recibo,
                                      fecha,
                                      cod_persona,
                                      cod_mod_padre,
                                      cod_mad_padre,
                                      cod_tra_padre,
                                      cod_oficina,
                                      cod_moneda,
                                      cotizacion,
                                      anulado)
                             values ( v_nro_recibo,
                                      v_fec_proceso,
                                      reg(i).cod_persona,
                                      reg(i).cod_mod_padre,
                                      reg(i).cod_mad_padre,
                                      reg(i).cod_tra_padre,
                                      reg(i).cod_oficina,
                                      reg(i).cod_moneda,
                                      v_cotizacion,
                                      'N');
           exception
             when others then
                raise_application_error(-20001,'No se puede insertar la cabecera del Recibo. '||sqlerrm);
           end;

           v_cod_persona :=  reg(i).cod_persona;
           v_nro_linea := 0;
           v_nro_item := 0;
        end if;

        begin
          v_nro_item := nvl(v_nro_item, 0) + 1;
          v_nro_linea := nvl(v_nro_linea, 0) + 1;
          insert into cb_recibos_det ( nro_recibo,
                                       nro_item,
                                       nro_timbrado,
                                       nro_factura,
                                       nro_cuenta,
                                       monto,
                                       fec_movimiento,
                                       hor_movimiento,
                                       usu_movimiento )
                              values ( v_nro_recibo,
                                       v_nro_item,
                                       reg(i).nro_timbrado,
                                       reg(i).nro_factura,
                                       reg(i).nro_cuenta,
                                       reg(i).monto,
                                       reg(i).fec_movimiento,
                                       reg(i).hor_movimiento,
                                       reg(i).usu_movimiento );
        exception
          when others then
                raise_application_error(-20001,'No se puede insertar el detalle del Recibo. '||sqlerrm);
        end;
      end loop;
      EXIT WHEN cu_facturas%NOTFOUND;
    END LOOP;

   for r in cu_rec_anulados loop
      begin
        update cb_recibos
           set anulado = 'S'
         where nro_recibo = r.nro_recibo;
      exception
        when others then
          raise_application_error(-20002,'No se puede anular el Recibo. '||sqlerrm);
      end;
    end loop;
EXCEPTION

  WHEN OTHERS THEN
    raise_application_error(-20001,'Error al Generar Recibos, PRB_GEN_RECIBOS '||sqlerrm);
END;
/
