CREATE OR REPLACE PROCEDURE IT.PRB_GEN_REP_REC IS
   -- Procedimiento que genera los recibos para las Facturas a Crédito
   v_fec_proceso  date := add_months( pag_cal.fu_obt_fec_actual(1),-1);
   v_fec_actual   date := pag_cal.fu_obt_fec_actual(1);
   v_nro_lin_rec  number(8):= fug_obt_pardinamico('NRO_LIN_RECIBOS');  -- Nro. de Lineas que puede tener una factura
   v_nro_linea    number(8);  -- Cantidad de lineas impresas de la factura
   v_nro_recibo   number;
   v_cod_persona  ba_personas.cod_persona%type;
   v_cod_mon_local   ba_monedas.cod_moneda%type := pag_gen.fu_obt_mon_local;
   v_cotizacion      ge_cotizaciones.val_conversion%type;
   v_nro_item     cb_recibos_det.nro_item%type;
   v_fec_desde  ge_calendarios.fec_actual%type;
   v_fec_hasta  ge_calendarios.fec_actual%type;
   v_mto_factura      cb_recibos_det.monto%type;
   v_nro_timbrado   cb_lib_ventas.nro_timbrado%type;
   v_nro_factura    cb_lib_ventas.nro_factura%type;
   v_cod_moneda  ba_monedas.cod_moneda%type;
  cursor cu_facturas is
    --Facturas por Desembolso
    select v.fecha, d.fecha fec_movimiento, d.hora hor_movimiento, d.cod_usuario usu_movimiento,
           v.nro_timbrado, v.nro_factura, v.cod_persona, d.cod_mod_padre, d.cod_mad_padre,
           d.cod_tra_padre, v.cod_oficina, v.cod_moneda, d.nro_cuenta, d.cotizacion,
           decode(p.cod_moneda, v_cod_mon_local, (nvl(p.mto_capital,0)- nvl(p.monto,0)), (nvl(p.mto_capital,0)- nvl(p.monto,0)) * d.cotizacion) monto
      from cb_lib_ventas v, cb_lib_ventas_det d, pr_cta_prestamos p
     where v.fecha between v_fec_desde and v_fec_hasta
       and v.tip_comprobante = 'F'
       and v.tip_venta = 'CR'
       and d.cod_tra_padre = 358
       and d.nro_cuenta = p.nro_cuenta
       and v.nro_timbrado= d.nro_timbrado
       and v.nro_factura = d.nro_factura
       and not exists (select 1 from cb_recibos rc, cb_recibos_det rd
                        where rc.cod_mod_padre = 6
                          and rc.cod_tra_padre = 358
                          and rd.nro_cuenta =  d.nro_cuenta
                          and rd.nro_timbrado = v.nro_timbrado
                          and rd.nro_factura = v.nro_factura
                          and rc.nro_recibo = rd.nro_recibo
                          and nvl(rc.anulado, 'N') <> 'S')
     group by v.fecha, d.fecha, d.hora, d.cod_usuario,
              v.nro_timbrado, v.nro_factura, v.cod_persona, d.cod_mod_padre, d.cod_mad_padre,
              d.cod_tra_padre, v.cod_oficina, v.cod_moneda, d.nro_cuenta, d.cotizacion,
              p.cod_moneda, p.mto_capital, p.monto
     order by v.cod_persona, v.fecha,d.fecha, d.hora,d.cod_usuario;

  cursor cu_mov_int_ven is
    select fecha, hora, cod_usuario, nro_secuencia, cod_oficina,
           cod_mod_padre, cod_mad_padre, cod_tra_padre,
           cod_modulo, cod_modalidad, cod_transaccion,
           decode(d.cod_moneda, v_cod_mon_local, monto, mto_equ_local) monto, d.mto_equ_local,
           d.nro_cuenta, d.nro_documento3, fug_obt_cli_principal(d.nro_cuenta) cod_persona
      from pr_movimientos_his d
     where d.fecha between v_fec_desde and v_fec_hasta
       and cod_mod_padre = 6
       and cod_tra_padre in (360,362,359,364)
       and cod_transaccion in (708, 802)
       and nvl(reversado,'N') = 'N'
       and not exists (select 1 from cb_recibos rc, cb_recibos_det rd
                    where rd.nro_cuenta = d.nro_cuenta
                      and rc.cod_mod_padre = 6
                      and rc.cod_tra_padre in (360,362,359,364)
                      and rc.nro_recibo = rd.nro_recibo
                      and rd.fec_movimiento = d.fecha
                      and rd.hor_movimiento = d.hora
                      and rd.usu_movimiento = d.cod_usuario
                      and nvl(rc.anulado, 'N') <> 'S')
      order by 16,1,2,3;

  cursor cu_rec_anulados is
    -- Recibos a Anular por Notas de Créditos Generadas.
    select distinct r.nro_recibo
      from cb_lib_ventas v, cb_recibos r, cb_recibos_det d
     where v.fecha between v_fec_desde and v_fec_hasta
       and v.tip_comprobante = 'N'
       and v.tip_venta = 'CR'
       and r.cod_tra_padre <> 2510
       and nvl(r.anulado, 'N') <> 'S'
       and r.nro_recibo = d.nro_recibo
       and v.nro_tim_referencia = d.nro_timbrado
       and v.nro_fac_referencia = d.nro_factura;

   TYPE cursor1_type IS TABLE OF cu_facturas%ROWTYPE;
   reg cursor1_type;

   TYPE cursor2_type IS TABLE OF cu_mov_int_ven%ROWTYPE;
   riv cursor2_type;

BEGIN
   PAG_CAL.PR_OBT_DAT_CALENDAR(PAA_DEV.G_COD_MODULO);
   v_fec_desde  :=  trunc(v_fec_proceso, 'mm');
   v_fec_hasta  :=  trunc(last_day(v_fec_proceso));
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
             v_cotizacion := fug_obt_cotizacion(reg(i).cod_moneda, v_fec_actual);
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
                                      v_fec_actual,
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

    v_cod_persona := null;
    v_nro_linea := null;
    OPEN cu_mov_int_ven;
    LOOP
      FETCH cu_mov_int_ven BULK COLLECT INTO riv LIMIT 2500;
      FOR i IN 1 .. riv.count LOOP
          if riv(i).cod_transaccion = 708 then
            begin
               select distinct c.nro_factura, c.nro_timbrado, c.cod_moneda
                 into v_nro_factura, v_nro_timbrado, v_cod_moneda
                 from cb_lib_ventas c, cb_lib_ventas_det dv
                where c.cod_persona = riv(i).cod_persona
                  and c.nro_timbrado = dv.nro_timbrado
                  and c.nro_factura = dv.nro_factura
                  and dv.cod_mod_padre = 6
                  and dv.cod_mad_padre = riv(i).cod_mad_padre
                  and dv.cod_tra_padre = 391
                  and dv.cod_transaccion = 710
                  and dv.nro_cuenta = riv(i).nro_cuenta
                  and dv.nro_documento = riv(i).nro_documento3
                  and c.nro_timbrado = dv.nro_timbrado
                  and c.nro_factura = dv.nro_factura
                  and rownum = 1
                order by nro_factura desc;
            exception
              when others then
                v_nro_factura := null;
                v_nro_timbrado := null;
                v_cod_moneda := null;
            end;
          else
            begin
               select distinct c.nro_factura, c.nro_timbrado, c.cod_moneda
                 into v_nro_factura, v_nro_timbrado, v_cod_moneda
                 from cb_lib_ventas c, cb_lib_ventas_det dv
                where c.cod_persona = riv(i).cod_persona
                  and c.nro_timbrado = dv.nro_timbrado
                  and c.nro_factura = dv.nro_factura
                  and dv.cod_mod_padre = 6
                  and dv.cod_mad_padre = riv(i).cod_mad_padre
                  and dv.cod_tra_padre = 358
                  and dv.cod_transaccion = 709
                  and dv.nro_cuenta = riv(i).nro_cuenta
                  and c.nro_timbrado = dv.nro_timbrado
                  and c.nro_factura = dv.nro_factura
                  and rownum = 1
                order by nro_factura desc;
            exception
              when others then
                v_nro_factura := null;
                v_nro_timbrado := null;
                v_cod_moneda := null;
            end;
          end if;
          if v_nro_factura is not null then
            if v_cod_moneda <> v_cod_mon_local then
               v_cotizacion := fug_obt_cotizacion(v_cod_moneda, v_fec_actual);
            else
               v_cotizacion := null;
            end if;

            if riv(i).cod_transaccion = 708 then
              if riv(i).fecha = v_fec_actual then
                begin
                  select decode(d.cod_moneda, v_cod_mon_local, monto, mto_equ_local) + riv(i).monto
                    into v_mto_factura
                    from ge_movimientos d
                   where fecha = riv(i).fecha
                     and hora = riv(i).hora
                     and cod_usuario = riv(i).cod_usuario
                     and nro_secuencia = ( select nvl(max(b.nro_secuencia), 0)
                                             from ge_movimientos b
                                            where b.fecha = d.fecha
                                              and b.hora = d.hora
                                              and b.cod_usuario = d.cod_usuario
                                              and b.nro_secuencia < riv(i).nro_secuencia);
                exception
                  when others then
                    v_mto_factura := 0;
                end;
              else
                begin
                  select decode(d.cod_moneda, v_cod_mon_local, monto, mto_equ_local) + riv(i).monto
                    into v_mto_factura
                    from pr_movimientos_his d
                   where fecha = riv(i).fecha
                     and hora = riv(i).hora
                     and cod_usuario = riv(i).cod_usuario
                     and nro_secuencia = ( select nvl(max(b.nro_secuencia), 0)
                                             from pr_movimientos_his b
                                            where b.fecha = d.fecha
                                              and b.hora = d.hora
                                              and b.cod_usuario = d.cod_usuario
                                              and b.nro_secuencia < riv(i).nro_secuencia);
                exception
                  when others then
                    v_mto_factura := 0;
                end;
              end if;
            else
              v_mto_factura := nvl(riv(i).monto,0);
            end if;

            if nvl(v_cod_persona,'-1') <> nvl(riv(i).cod_persona,'-1')
               or v_nro_linea + 1 > v_nro_lin_rec then
               v_nro_recibo := fug_obt_lla_pardinamico('NRO_REC_FAC_CRE', riv(i).cod_mod_padre,
                                                         riv(i).cod_mad_padre, 'GS', riv(i).cod_oficina)+1;
               prg_act_par_dinamico('NRO_REC_FAC_CRE',riv(i).cod_mod_padre, riv(i).cod_mad_padre, 'GS', riv(i).cod_oficina, v_nro_recibo);


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
                                            v_fec_actual,
                                            riv(i).cod_persona,
                                            riv(i).cod_mod_padre,
                                            riv(i).cod_mad_padre,
                                            riv(i).cod_tra_padre,
                                            riv(i).cod_oficina,
                                            v_cod_moneda,
                                            v_cotizacion,
                                            'N');
                 exception
                   when others then
                      raise_application_error(-20002,'No se puede insertar la cabecera del Recibo. '||sqlerrm);
                 end;
                 v_cod_persona :=  riv(i).cod_persona;
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
                                             cod_modulo,
                                             cod_modalidad,
                                             cod_transaccion,
                                             nro_cuenta,
                                             monto,
                                             fec_movimiento,
                                             hor_movimiento,
                                             usu_movimiento,
                                             sec_movimiento )
                                    values ( v_nro_recibo,
                                             v_nro_item,
                                             v_nro_timbrado,
                                             v_nro_factura,
                                             riv(i).cod_modulo,
                                             riv(i).cod_modalidad,
                                             riv(i).cod_transaccion,
                                             riv(i).nro_cuenta,
                                             v_mto_factura,
                                             riv(i).fecha,
                                             riv(i).hora,
                                             riv(i).cod_usuario,
                                             riv(i).nro_secuencia );
              exception
                when others then
                  raise_application_error(-20002,'No se puede insertar el detalle del Recibo. '||sqlerrm);
              end;
          end if;
      end loop;
      EXIT WHEN cu_mov_int_ven%NOTFOUND;
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
    raise_application_error(-20001,'Error al Generar los recibos. '||sqlerrm);
END;
/

