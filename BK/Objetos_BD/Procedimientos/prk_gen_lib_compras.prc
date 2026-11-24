create or replace procedure it.PRK_GEN_LIB_COMPRAS (p_fec_proceso in date default null) is
   --- Variables auxiliares
   rv_lib           cb_lib_compras%rowtype;
   v_cod_mon_local  ba_monedas.cod_moneda%type;
   v_fec_actual     ge_calendarios.fec_actual%type;
   v_val_compra     pv_compras_det.val_total%type;
   v_val_neto       cb_lib_compras.mto_exento%type;
   v_val_impuesto   cb_lib_compras.mto_gravado_10%type;
   v_redondeo       number;
   v_cotizacion     ge_cotizaciones.val_conversion%type;
   v_total_5        pv_compras_det.val_total%type;
   v_total_10       pv_compras_det.val_total%type;
   --- Cursor de compras ingresadas
  cursor c_compras is
   select e.cod_persona, c.fecha, c.nro_factura, c.timbrado, c.nom_proveedor,
          c.tip_venta, c.ruc, e.descripcion raz_social, c.cod_moneda,
          sum(d.val_total) val_total, c.iva_incluido,
          sum(decode(d.tip_impuesto,5,(d.val_impuesto),0)) val_impuesto_5,
          sum(decode(d.tip_impuesto,10,(d.val_impuesto),0)) val_impuesto_10,
          sum(decode(d.tip_impuesto,5,(d.mto_neto),0)) mto_neto_5,
          sum(decode(d.tip_impuesto,10,(d.mto_neto),0)) mto_neto_10,
          sum(decode(d.tip_impuesto,0,(d.mto_neto),0)) mto_neto_exento,
          nvl(c.cod_ofi_origen,11) cod_ofi_origen, c.cod_ent_proveedor,
          c.fec_cam_estado fec_pago, c.cod_compra, c.tip_comprobante,
          c.nro_ref_factura, c.nro_ref_timbrado
     from pv_compras c, pv_compras_det d, ge_entes e
    where c.cod_compra = d.cod_compra
      and nvl(c.tip_comprobante,'B') in ('F','T','P') -- Facturas
      and c.estado = 'A'
      and e.cod_ente = c.cod_ent_proveedor
      --and trunc(c.fec_insercion)= trunc(sysdate)
      and c.cod_ent_proveedor <> 9999 --Proveedor generico
      and trunc(c.fec_cam_estado) = v_fec_actual
      and not exists (select 1
                        from cb_lib_compras l
                       where l.nro_factura = c.nro_factura
                         and l.fecha = c.fecha
                         and l.cod_ent_proveedor = c.cod_ent_proveedor )
     group by e.cod_persona, c.fecha, c.nro_factura, c.timbrado, c.nom_proveedor,
              c.tip_venta, c.ruc, e.descripcion, c.cod_moneda, c.iva_incluido,
              nvl(c.cod_ofi_origen,11), c.cod_ent_proveedor, c.fec_cam_estado,c.cod_compra,c.tip_comprobante,
              c.nro_ref_factura, c.nro_ref_timbrado
   union all
   select e.cod_persona, c.fecha, c.nro_factura, c.timbrado, c.nom_proveedor,
          c.tip_venta, c.ruc, e.descripcion raz_social, c.cod_moneda,
          sum(d.val_total) val_total, c.iva_incluido,
          sum(decode(d.tip_impuesto,5,(d.val_impuesto),0)) val_impuesto_5,
          sum(decode(d.tip_impuesto,10,(d.val_impuesto),0)) val_impuesto_10,
          sum(decode(d.tip_impuesto,5,(d.mto_neto),0)) mto_neto_5,
          sum(decode(d.tip_impuesto,10,(d.mto_neto),0)) mto_neto_10,
          sum(decode(d.tip_impuesto,0,(d.mto_neto),0)) mto_neto_exento,
          nvl(c.cod_ofi_origen,11) cod_ofi_origen, c.cod_ent_proveedor,
          c.fec_cam_estado fec_pago,c.cod_compra, c.tip_comprobante,
          c.nro_ref_factura, c.nro_ref_timbrado
     from pv_compras c, pv_compras_det d, ge_entes e
    where c.cod_compra = d.cod_compra
      and nvl(c.tip_comprobante,'B') in ('F','T','P') -- Facturas
      and c.estado = 'P'
      --and trunc(c.fec_insercion)= trunc(sysdate)
      and e.cod_ente = c.cod_ent_proveedor
      and c.cod_ent_proveedor <> 9999 --Proveedor generico
      and trunc(c.fec_cam_estado) = v_fec_actual
      and not exists (select 1
                        from cb_lib_compras l
                       where l.nro_factura = c.nro_factura
                         and l.fecha = c.fecha
                         and l.cod_ent_proveedor = c.cod_ent_proveedor )
     group by e.cod_persona, c.fecha, c.nro_factura, c.timbrado, c.nom_proveedor,
              c.tip_venta, c.ruc, e.descripcion, c.cod_moneda, c.iva_incluido,
              nvl(c.cod_ofi_origen,11), c.cod_ent_proveedor, c.fec_cam_estado,c.cod_compra,c.tip_comprobante,
              c.nro_ref_factura, c.nro_ref_timbrado
   union all
   select e.cod_persona, c.fecha, c.nro_factura, c.timbrado, c.nom_proveedor,
          c.tip_venta, c.ruc, c.nom_proveedor raz_social, c.cod_moneda,
          sum(d.val_total) val_total, c.iva_incluido,
          sum(decode(d.tip_impuesto,5,(d.val_impuesto),0)) val_impuesto_5,
          sum(decode(d.tip_impuesto,10,(d.val_impuesto),0)) val_impuesto_10,
          sum(decode(d.tip_impuesto,5,(d.mto_neto),0)) mto_neto_5,
          sum(decode(d.tip_impuesto,10,(d.mto_neto),0)) mto_neto_10,
          sum(decode(d.tip_impuesto,0,(d.mto_neto),0)) mto_neto_exento,
          nvl(c.cod_ofi_origen,11) cod_ofi_origen, c.cod_ent_proveedor,
          c.fec_cam_estado fec_pago,c.cod_compra, c.tip_comprobante,
          c.nro_ref_factura, c.nro_ref_timbrado
     from pv_compras c, pv_compras_det d, ge_entes e
    where c.cod_compra = d.cod_compra
      and nvl(c.tip_comprobante,'B') in ('F','T','P') -- Facturas
      and c.estado = 'A'
      --and trunc(c.fec_insercion)= trunc(sysdate)
      and e.cod_ente = c.cod_ent_proveedor
      and c.cod_ent_proveedor = 9999 --Proveedor generico
      and trunc(c.fec_cam_estado) = v_fec_actual
      and not exists (select 1
                        from cb_lib_compras l
                       where l.nro_factura = c.nro_factura
                         and l.fecha = c.fecha
                         and l.cod_ent_proveedor = c.cod_ent_proveedor )
     group by e.cod_persona, c.fecha, c.nro_factura, c.timbrado, c.nom_proveedor,
              c.tip_venta, c.ruc, e.descripcion, c.cod_moneda, c.iva_incluido,
              nvl(c.cod_ofi_origen,11), c.cod_ent_proveedor, c.fec_cam_estado,c.cod_compra,c.tip_comprobante,
              c.nro_ref_factura, c.nro_ref_timbrado;

begin
   v_cod_mon_local := pag_gen.FU_OBT_MON_LOCAL;
   v_fec_actual    := nvl(p_fec_proceso,pag_cal.FU_OBT_FEC_ACTUAL(28));
  /*
  En caso que deba existir una opcion de reproceso se debe evaluar cual seria
  el esquema porque hoy dia no es aplicable porque al final del dia todas las facturas
  aprobadas deben ir al libro IVA COMPRAS    JCLG
  */
   --- Eliminar libro de compras de la fecha para reprocesos
   --delete cb_lib_compras where fec_cam_estado = v_fec_actual;

   ---
   for reg in c_compras loop
      --- Inicializar variables de monto
      rv_lib.mto_exento     := 0;
      rv_lib.mto_gravado_5  := 0;
      rv_lib.impuesto_5     := 0;
      rv_lib.mto_gravado_10 := 0;
      rv_lib.impuesto_10    := 0;
      ---
      if reg.cod_moneda <> v_cod_mon_local then
         v_redondeo:= fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', null/*modulo*/,null/*modalidad*/,reg.cod_moneda,null/*oficina*/);
         begin
            SELECT distinct c.cotizacion
            into v_cotizacion
              FROM ge_movimientos c
             WHERE c.cod_modulo = 28
               AND c.cod_tra_padre = 2801
               AND c.cod_moneda = pag_gen.fu_obt_mon_fuerte
               AND substr(c.concepto, 7, 15) = reg.nro_factura
               AND nro_documento2 = reg.cod_compra;
         exception
           when no_data_found then
               v_cotizacion:=  pag_gen.FU_OBT_COTIZACION(reg.cod_moneda,v_fec_actual);
         end;

       v_val_compra := nvl(pag_gen.FU_CON_MON_A_MONEDA(reg.cod_moneda, v_cod_mon_local, nvl(reg.val_total,0),v_cotizacion/* pag_gen.FU_OBT_COTIZACION(reg.cod_moneda,v_fec_actual)*/),0);
      else
         v_val_compra := nvl(reg.val_total,0);
      end if;
      --- Insertar la Factura en libro Compras IVA
      rv_lib.fecha             := reg.fecha;
      rv_lib.nro_factura       := reg.nro_factura;
      rv_lib.nro_timbrado      := reg.timbrado;
      rv_lib.tipo              := reg.tip_venta;
      rv_lib.cod_persona       := reg.cod_persona;
      v_val_impuesto := reg.val_impuesto_5 + reg.val_impuesto_10;
      v_val_neto := reg.mto_neto_exento + reg.mto_neto_5 + reg.mto_neto_10;
      rv_lib.mto_gravado_5  := reg.mto_neto_5;
      rv_lib.impuesto_5     := reg.val_impuesto_5;
      rv_lib.mto_gravado_10 := reg.mto_neto_10;
      rv_lib.impuesto_10    := reg.val_impuesto_10;
      rv_lib.mto_exento      := reg.mto_neto_exento;
      rv_lib.nro_documento     := reg.ruc;
      rv_lib.raz_social        := reg.raz_social;
      rv_lib.cod_ofi_origen    := reg.cod_ofi_origen;
      rv_lib.cod_ent_proveedor := reg.cod_ent_proveedor;
      rv_lib.tip_comprobante   := reg.tip_comprobante;
      rv_lib.nro_ref_factura:= reg.nro_ref_factura;
      rv_lib.nro_ref_timbrado:= reg.nro_ref_timbrado;

      if reg.cod_moneda <> v_cod_mon_local then
         rv_lib.mto_gravado_5  := round(rv_lib.mto_gravado_5*v_cotizacion, 0);
         rv_lib.impuesto_5     := round(rv_lib.impuesto_5*v_cotizacion, 0);
         v_total_5             := rv_lib.mto_gravado_5 + rv_lib.impuesto_5 ;
         rv_lib.impuesto_5     := fuk_cal_impuesto(v_total_5,5,reg.iva_incluido, 0);
         rv_lib.mto_gravado_5  := round(v_total_5 - rv_lib.impuesto_5,0);
        ---
         rv_lib.mto_gravado_10 := round(rv_lib.mto_gravado_10*v_cotizacion, 0);
         rv_lib.impuesto_10    := round(rv_lib.impuesto_10*v_cotizacion, 0);
         v_total_10            := rv_lib.mto_gravado_10 + rv_lib.impuesto_10;
         rv_lib.impuesto_10    := fuk_cal_impuesto(v_total_10,10,reg.iva_incluido,0);
         rv_lib.mto_gravado_10 := v_total_10 - rv_lib.impuesto_10;
        ---
         rv_lib.mto_exento     := round(rv_lib.mto_exento*v_cotizacion, 0);
      end if;
      rv_lib.fec_pago       := reg.fec_pago;
      ---
      PRB_INS_LIB_COMPRAS (rv_lib);
   end loop;
exception
   when others then
      if sqlcode <= -20000 then
         raise;
      else
         raise_application_error(-20001,'Error al generarse el Libro de Compras. '||sqlerrm);
      end if;
end PRK_GEN_LIB_COMPRAS;
/

