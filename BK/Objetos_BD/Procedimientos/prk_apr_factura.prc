CREATE OR REPLACE PROCEDURE IT.PRK_APR_FACTURA (p_cod_compra in number, p_nro_factura in varchar2, p_fecha in date, p_hora in varchar2) is
  --- Variables
  rv_art            af_articulos%rowtype;
  v_hora            ge_movimientos.hora%type;
  v_nro_secuencia   ge_movimientos.nro_secuencia%type;
  v_fec_actual      ge_movimientos.fecha%type;
  v_cod_mon_local   ba_monedas.cod_moneda%type;
  v_val_compra      pv_compras_det.val_total%type;
  v_cod_ofi_origen  pv_compras.cod_ofi_origen%type := fug_obt_ofi_usuario(user);
  v_ofi_suministro  ba_oficinas.cod_oficina%type := FUG_OBT_PARDINAMICO('OFI_SUMINISTRO');
  v_area_suministro ba_areas.cod_area%type := FUG_OBT_PARDINAMICO('AREA_SUMINISTRO');
  v_val_neto        pv_compras_det.mto_neto%type;
  v_val_impuesto    pv_compras_det.val_impuesto%type;
  v_cotizacion      ge_cotizaciones.val_conversion%type;
  v_redondeo        NUMBER(5);
  v_cod_mod_padre ge_movimientos.cod_mod_padre%type; /*09/12/2013 PN DI: Cod de módulo padre del detalle de la facturación*/
  v_cod_mad_padre ge_movimientos.cod_mad_padre%type; /*09/12/2013 PN DI: Cod de modalidad padre del detalle de la facturación*/
  v_cod_tra_padre ge_movimientos.cod_tra_padre%type; /*09/12/2013 PN DI: Cod de transaccion padre del detalle de la facturación*/

  --- Cursor de bienes de la factura
   cursor c_bienes is
   select e.cod_persona, c.fecha, c.nro_factura, c.nom_proveedor,
          c.tip_venta, c.ruc, e.descripcion raz_social, cod_moneda,
          d.mto_neto val_total, d.tip_impuesto, c.iva_incluido,
          d.cantidad, d.cod_articulo, d.cod_oficina, d.cod_area,
          d.descripcion, c.cod_ent_proveedor, c.tip_comprobante,
          d.cod_modulo, d.cod_modalidad, d.cod_transaccion,
          d.nro_linea, d.mto_neto, d.transaccion_iva, d.val_impuesto, c.cod_compra,
          d.val_compra tot_compra
     from pv_compras c, pv_compras_det d, ge_entes e
    where c.cod_compra = d.cod_compra
      and c.estado = 'I'
      and e.cod_ente = c.cod_ent_proveedor
      and c.cod_compra = p_cod_compra  -- CB. 21/10/2013. SPI 1876.
      and not exists (select 0 from pv_com_oficinas x
                       where x.cod_compra = d.cod_compra
                         and x.nro_linea = d.nro_linea)
      for update nowait;

   --- Cursor de oficinas del bien
   cursor c_oficinas is
   select e.cod_persona, c.fecha, c.nro_factura, c.nom_proveedor,
          c.tip_venta, c.ruc, e.descripcion raz_social, cod_moneda,
          o.val_total,
          d.tip_impuesto, c.iva_incluido,o.cantidad, d.cod_articulo,
          o.cod_oficina, o.cod_area, d.descripcion, c.cod_ent_proveedor,
          c.tip_comprobante, d.cod_modulo, d.cod_modalidad, d.cod_transaccion,
          d.nro_linea, o.val_total mto_neto,
          d.transaccion_iva, d.val_impuesto, c.cod_compra
     from pv_compras c, pv_compras_det d, ge_entes e,
          pv_com_oficinas o
    where c.cod_compra = d.cod_compra
      and c.estado = 'I'
      and e.cod_ente = c.cod_ent_proveedor
      and c.cod_compra = p_cod_compra  -- CB. 21/10/2013. SPI 1876.
      and d.cod_compra = o.cod_compra
      and d.nro_linea = o.nro_linea
      for update nowait;

   --- Cursor para generar IVA--
	-- Ajuste JIRA 2735 -16-01-2012
   cursor c_iva is
   select e.cod_persona, c.fecha, c.nro_factura, c.nom_proveedor,
          c.tip_venta, c.ruc, e.descripcion raz_social, cod_moneda,
          c.cod_ent_proveedor, c.tip_comprobante,
          d.cod_modulo, d.cod_modalidad, d.transaccion_iva,
          sum(d.val_impuesto) val_impuesto, d.tip_impuesto,
          d.val_compra tot_compra,c.iva_incluido
     from pv_compras c, pv_compras_det d, ge_entes e
    where c.cod_compra = d.cod_compra
      and c.estado = 'I'
      and e.cod_ente = c.cod_ent_proveedor
      and c.cod_compra = p_cod_compra  -- CB. 21/10/2013. SPI 1876.
   group by e.cod_persona, c.fecha, c.nro_factura, c.nom_proveedor,
            c.tip_venta, c.ruc, e.descripcion, cod_moneda,
            c.cod_ent_proveedor, c.tip_comprobante, d.cod_modulo,
            d.cod_modalidad, d.transaccion_iva, d.tip_impuesto, d.val_compra, c.iva_incluido;

   --Cursor para generar registro adicional por el total de la factura
   cursor c_tot_factura is
   select e.cod_persona, c.fecha, c.nro_factura, c.nom_proveedor,
          c.tip_venta, c.ruc, e.descripcion raz_social, cod_moneda,
          c.tot_compra val_total, d.tip_impuesto, c.iva_incluido,
          d.cantidad, d.cod_articulo, d.cod_oficina, d.cod_area,
          'Fact: '||c.nro_factura||' '||c.nom_proveedor descripcion,
          c.cod_ent_proveedor, c.tip_comprobante,
          decode(d.cod_articulo,null,28,13) cod_modulo,
          decode(d.cod_articulo,null,281,131) cod_modalidad,
          2891 cod_transaccion,
          d.nro_linea, d.mto_neto, d.transaccion_iva, d.val_impuesto,
          c.cod_compra
     from pv_compras c, pv_compras_det d, ge_entes e
    where c.cod_compra = d.cod_compra
      and c.estado = 'I'
      and e.cod_ente = c.cod_ent_proveedor
      and c.cod_compra = p_cod_compra  -- CB. 21/10/2013. SPI 1876.
      and rownum = 1
   for update nowait;

  v_cod_modulo    ba_modulos.cod_modulo%type;
  v_cod_modalidad ge_modalidades.cod_modalidad%type;

BEGIN
     BEGIN PRE_INI_APLICACION;PAE_CNF.G_COD_MODULO:=1;END;
        --- Inicializar variables para generar movimientos con la misma hora
         v_fec_actual    := p_fecha;
         v_hora          := p_hora;
         v_nro_secuencia := 0;
         v_cod_mon_local := pag_gen.FU_OBT_MON_LOCAL;
         v_redondeo      := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',null,null,v_cod_mon_local);

         --Cursor para generar total de la factura
         /*09/12/2013 PN DI: Cambie el bloque de generación de Movimientos del total de la factura con el fin de guardar las transacciones /
                             padres y en base a la misma se generen los demás movimientos */
         for tot in c_tot_factura loop
             -- movimientos directos por la transaccion
             if v_nro_secuencia  = 999 then
                v_hora          := pag_gen.fu_obt_sig_segundo(v_hora);
                v_nro_secuencia := 0;
             end if;

             --Para pasar como parametro al grabar el iva
             v_cod_modulo := tot.cod_modulo;
             v_cod_modalidad := tot.cod_modalidad;
-------------------------------------------------------------------------------------------------------------------
             declare
             -- Datos para generar el movimiento
                v_fec_actual        date         := pag_cal.fu_obt_fec_actual(13); -- fecha de hoy
                v_hor_actual        varchar2(08) := to_char(sysdate,'HH24:MI:SS'); -- Hora actual
                v_cod_usuario       varchar2(10) := upper(user);                   -- usuario
                r_gmovi             ge_movimientos%rowtype;
                ---
                v_impuesto          pv_compras_det.val_impuesto%type;
                v_val_compra        af_bienes.val_compra%type;
                v_val_unitario      af_bienes.val_compra%type;
                ---
                begin
                   --- Obtengo el maximo nro. de secuencia
                   --- para evitar error de PK en GE_MOVIMIENTOS
                   ---
                   v_hor_actual := nvl(p_hora, to_char(sysdate,'HH24:MI:SS'));
                   v_nro_secuencia := nvl(v_nro_secuencia,0);
                   ---
                   ---AP 2870 29-05-2012 V.V.
                   v_cotizacion := nvl(pag_gen.fu_obt_cotizacion( tot.cod_moneda, v_fec_actual),1);
                   ---------------------------
                   --- INSERTAR MOVIMIENTO ---
                   ---------------------------
                   -- Aumento la secuencia
                   if v_nro_secuencia  = 999 then
                      v_hor_actual    := pag_gen.fu_obt_sig_segundo(v_hor_actual);
                      v_nro_secuencia := 0;
                   end if;
                   v_nro_secuencia := nvl(v_nro_secuencia,0) + 1;
                   -- Genero el movimiento x el monto sin el impuesto
                   r_gmovi.cod_modulo      := tot.cod_modulo;
                   r_gmovi.cod_modalidad   := tot.cod_modalidad ;
                   r_gmovi.cod_oficina     := v_cod_ofi_origen;
                   r_gmovi.nro_cuenta      := null;
                   r_gmovi.cod_moneda      := tot.cod_moneda;
                   r_gmovi.cod_usuario     := v_cod_usuario;
                   r_gmovi.hora            := v_hor_actual;
                   r_gmovi.fecha           := v_fec_actual;
                   r_gmovi.nro_secuencia   := v_nro_secuencia;
                   --
                   r_gmovi.fec_valor       := v_fec_actual;
                   r_gmovi.cod_tra_padre   := 2801;
                   r_gmovi.cod_mod_padre   := tot.cod_modulo;
                   r_gmovi.cod_mad_padre   := tot.cod_modalidad;
                   -- 09/09/2013 PN DI: Para unificar las transacciones Padres --
                   v_cod_tra_padre := 2801;
                   v_cod_mod_padre := tot.cod_modulo;
                   v_cod_mad_padre := tot.cod_modalidad;

                   r_gmovi.cod_transaccion := tot.cod_transaccion;
                   r_gmovi.monto           := nvl(tot.val_total,0);
                   r_gmovi.nro_documento   := tot.nro_linea;
                  -- DYDMR-7799 - Incidencia SAU - ITGF - Incidencia al Reversar las facturas de proveedores
                  r_gmovi.nro_documento2   := tot.cod_compra;
                  r_gmovi.nro_documento3   := tot.cod_ent_proveedor;
                  --
                   r_gmovi.cod_tasa        := null;
                   r_gmovi.val_tasa        := null;
                  /* dydmr-1808 fm 15/06/2015
                   if tot.cod_moneda <> v_cod_mon_local then
                      r_gmovi.mto_equ_local   := round((nvl(tot.val_total,0) * v_cotizacion),v_redondeo);
                      r_gmovi.cotizacion      := v_cotizacion;
                   else*/
                      r_gmovi.mto_equ_local   := null;
                      r_gmovi.cotizacion      := null;
                   --end if;
                   r_gmovi.cod_ofi_origen  := v_cod_ofi_origen;
                   r_gmovi.emi_aviso       := 'N';
                   r_gmovi.concepto        := substr(tot.descripcion,1,35);
                   r_gmovi.estado          := 'N';
                   r_gmovi.reversado       := 'N';
                   r_gmovi.nro_caja        := null;
                   r_gmovi.cod_rubro       := NULL;

                   PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, 'N'); -- no es nocturno
                end;
-------------------------------------------------------------------------------------------------------------------
         end loop;


         for det in c_oficinas loop
             if det.cod_articulo is not null then
                --- Obtener parametros del Articulo
                prf_obt_articulo(det.cod_articulo, rv_art);
                ---
                if nvl(rv_art.ind_act_fijo,'N') = 'S' or
                   nvl(rv_art.ind_suministro,'N') = 'S' then
                   --- Siempre se convierte a moneda local los valores
                   v_val_compra := nvl(det.val_total,0);
                   v_val_neto   := nvl(det.mto_neto,0);
                   v_val_impuesto := nvl(det.val_impuesto,0);

                   /*09/12/2013 PN DI: Se envían la transacción padre como parámetro al procedimiento PRF_GEN_BIEN,
                                       con el fin de que se genereren los movimientos de bienes con la misma*/
                   PRF_GEN_BIEN(det.fecha ,
                                det.cod_ent_proveedor,
                                det.tip_comprobante ,
                                det.nro_factura,
                                det.cantidad,
                                det.cod_articulo,
                                det.cod_oficina,
                                det.cod_area,
                                v_val_compra,
                                v_val_neto,--det.mto_neto,
                                v_val_impuesto,--det.val_impuesto,
                                det.cod_moneda,--v_cod_mon_local,
                                det.descripcion,
                                det.transaccion_iva,
                                v_hora,
                                v_nro_secuencia,
                                det.tip_venta,
                                det.cod_compra,
                                v_cod_mod_padre,
                                v_cod_mad_padre,
                                v_cod_tra_padre);
                end if;
                ---
                --- Actualizar Articulo
                ---

                if det.cod_oficina = v_ofi_suministro and det.cod_area = v_area_suministro then
                   Update af_articulos
                      set can_total = nvl(can_total,0) + det.cantidad,
                          fec_ult_movimiento = v_fec_actual,
                          hor_ult_movimiento = v_hora
                    where  cod_articulo = det.cod_articulo;
                    if sql%notfound then
                       raise_application_error(-20000,'El articulo no fue actualizado');
                    end if;
                else
                    Update af_articulos
                       set fec_ult_movimiento = v_fec_actual,
                           hor_ult_movimiento = v_hora
                     where cod_articulo = det.cod_articulo;
                     if sql%notfound then
                        raise_application_error(-20000,'El articulo no fue actualizado');
                     end if;
                end if;
             else
                 -- Movimientos directos por la transaccion
------------------------------------------------------------------------------------------------------------------------
                 declare
                 -- Datos para generar el movimiento
                   v_fec_actual        date         := pag_cal.fu_obt_fec_actual(13); -- fecha de hoy
                   v_hor_actual        varchar2(08) := to_char(sysdate,'HH24:MI:SS'); -- Hora actual
                   v_cod_usuario       varchar2(10) := upper(user);                   -- usuario
                   r_gmovi             ge_movimientos%rowtype;
                   ---
                   v_impuesto          pv_compras_det.val_impuesto%type;
                   v_val_compra        af_bienes.val_compra%type;
                   v_val_unitario      af_bienes.val_compra%type;
                   ---
                 begin
                 --- Obtengo el maximo nro. de secuencia
                 --- Para evitar error de PK en GE_MOVIMIENTOS
                 ---
                     v_hor_actual := nvl(p_hora, to_char(sysdate,'HH24:MI:SS'));
                     v_nro_secuencia := nvl(v_nro_secuencia,0);
                     ---
                     ---AP 2870 29-05-2012 V.V.
                     v_cotizacion := nvl(pag_gen.fu_obt_cotizacion( det.cod_moneda, v_fec_actual),1);
                     ---------------------------
                     --- INSERTAR MOVIMIENTO ---
                     ---------------------------
                     -- Aumento la secuencia
                     if v_nro_secuencia  = 999 then
                        v_hor_actual    := pag_gen.fu_obt_sig_segundo(v_hor_actual);
                        v_nro_secuencia := 0;
                     end if;
                     v_nro_secuencia := nvl(v_nro_secuencia,0) + 1;
                     -- Genero el movimiento x el monto sin el impuesto
                     r_gmovi.cod_modulo      := det.cod_modulo;
                     r_gmovi.cod_modalidad   := det.cod_modalidad;
                     r_gmovi.cod_oficina     := det.cod_oficina;
                     r_gmovi.nro_cuenta      := null;
                     r_gmovi.cod_moneda      := det.cod_moneda;
                     r_gmovi.cod_usuario     := v_cod_usuario;
                     r_gmovi.hora            := v_hor_actual;
                     r_gmovi.fecha           := v_fec_actual;
                     r_gmovi.nro_secuencia   := v_nro_secuencia;
                     --
                     r_gmovi.fec_valor       := v_fec_actual;
                     
                     -- 09/09/2013 PN DI: Para unificar las transacciones Padres --
                     r_gmovi.cod_tra_padre   := v_cod_tra_padre;--2801;
                     r_gmovi.cod_mod_padre   := v_cod_mod_padre;--det.cod_modulo;
                     r_gmovi.cod_mad_padre   := v_cod_mad_padre;--det.cod_modalidad;
                     r_gmovi.cod_transaccion := det.cod_transaccion;
                     r_gmovi.monto           := nvl(det.val_total,0);
                     r_gmovi.nro_documento   := det.nro_linea;
                     -- DYDMR-7799 - Incidencia SAU - ITGF - Incidencia al Reversar las facturas de proveedores
                     r_gmovi.nro_documento2   := det.cod_compra;
                     r_gmovi.nro_documento3   := det.cod_ent_proveedor;
                     --                     
                     r_gmovi.cod_tasa        := null;
                     r_gmovi.val_tasa        := det.tip_impuesto; -- Ajuste JIRA 2735 -16-01-2012
                     /*if det.cod_moneda <> v_cod_mon_local then
                        r_gmovi.mto_equ_local   := round((nvl(det.val_total,0) * v_cotizacion),v_redondeo);
                        r_gmovi.cotizacion      := v_cotizacion;
                     else*/
                        r_gmovi.mto_equ_local   := null;
                        r_gmovi.cotizacion      := null;
                     --end if;
                     r_gmovi.cod_ofi_origen  := v_cod_ofi_origen;
                     r_gmovi.emi_aviso       := 'N';
                     r_gmovi.concepto        := det.descripcion;
                     r_gmovi.estado          := 'N';
                     r_gmovi.reversado       := 'N';
                     r_gmovi.nro_caja        := null;
                     r_gmovi.cod_rubro       := NULL;

                     PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, 'N'); -- no es nocturno
                 end;
------------------------------------------------------------------------------------------------------------------------
             end if;
         end loop;



         --Cursor para generar iva, una sola linea
         for det in c_iva loop
             if v_nro_secuencia  = 999 then
                v_hora           := pag_gen.fu_obt_sig_segundo(v_hora);
                v_nro_secuencia := 0;
             end if;
--------------------------------------------------------------------------------------------------------------------
             declare
               -- Datos para generar el movimiento
                v_fec_actual        date         := pag_cal.fu_obt_fec_actual(13); -- fecha de hoy
                v_hor_actual        varchar2(08); -- Hora actual
                v_cod_usuario       varchar2(10) := upper(user);                   -- usuario
                r_gmovi             ge_movimientos%rowtype;
                ---
                v_impuesto          pv_compras_det.val_impuesto%type;
                v_val_compra        af_bienes.val_compra%type;
                v_val_unitario      af_bienes.val_compra%type;
                v_mto_impuesto      number;
                ---
                 begin
                    --- Obtengo el maximo nro. de secuencia
                    --- para evitar error de PK en GE_MOVIMIENTOS
                    ---
                    v_hor_actual := nvl(p_hora, to_char(sysdate,'HH24:MI:SS'));
                    v_nro_secuencia := nvl(v_nro_secuencia,0);
                    ---
                    ---AP 2870 29-05-2012 V.V.
                    v_cotizacion := nvl(pag_gen.fu_obt_cotizacion( det.cod_moneda, v_fec_actual),1);
                    ---------------------------
                    --- INSERTAR MOVIMIENTO ---
                    ---------------------------
                    --- IVA
                    v_impuesto := 0;
                    ---
                    v_impuesto := det.val_impuesto;
                    ---
                    if v_impuesto > 0 then
                       -- Aumento la secuencia
                       if v_nro_secuencia  = 999 then
                          v_hor_actual    := pag_gen.fu_obt_sig_segundo(v_hor_actual);
                          v_nro_secuencia := 0;
                       end if;
                       v_nro_secuencia := nvl(v_nro_secuencia,0) + 1;
                       -- Genero el movimiento
                       r_gmovi.cod_modulo      := v_cod_modulo;
                       r_gmovi.cod_modalidad   := v_cod_modalidad;
                       r_gmovi.cod_oficina     := v_cod_ofi_origen;
                       r_gmovi.nro_cuenta      := null;
                       r_gmovi.cod_moneda      := det.cod_moneda;
                       r_gmovi.cod_usuario     := v_cod_usuario;
                       r_gmovi.hora            := v_hor_actual;
                       r_gmovi.fecha           := v_fec_actual;
                       r_gmovi.nro_secuencia   := v_nro_secuencia;
                       --
                       r_gmovi.fec_valor       := v_fec_actual;
                       -- 09/09/2013 PN DI: Para unificar las transacciones Padres --
                       r_gmovi.cod_tra_padre   := v_cod_tra_padre;--2801;
                       r_gmovi.cod_mod_padre   := v_cod_mod_padre;--v_cod_modulo;
                       r_gmovi.cod_mad_padre   := v_cod_mad_padre;--v_cod_modalidad;
                       r_gmovi.cod_transaccion := det.transaccion_iva;
                       r_gmovi.monto           := nvl(v_impuesto,0);
                       r_gmovi.nro_documento   := null;
                       r_gmovi.cod_tasa        := null;
                       r_gmovi.val_tasa        := det.tip_impuesto;-- Ajuste JIRA 2735 -16-01-2012
                       /*if det.cod_moneda <> v_cod_mon_local then
                          v_mto_impuesto := fuk_cal_impuesto(det.tot_compra,det.tip_impuesto,det.iva_incluido, null);
                          r_gmovi.mto_equ_local   := round(( nvl(v_mto_impuesto,0)  * v_cotizacion),v_redondeo);
                          r_gmovi.cotizacion      := v_cotizacion;
                       else*/
                          r_gmovi.mto_equ_local   := null;
                          r_gmovi.cotizacion      := null;
                       --end if;
                       if fug_obt_tip_implementacion = 1 then
                          r_gmovi.cod_ofi_origen  := v_cod_ofi_origen;
                       else
                          r_gmovi.cod_ofi_origen  := 1;
                       end if;
                       r_gmovi.emi_aviso       := 'N';
                       r_gmovi.concepto        := substr('IVA s/'||det.nro_factura||' '||det.nom_proveedor,1,35);
                       r_gmovi.estado          := 'N';
                       r_gmovi.reversado       := 'N';
                       r_gmovi.nro_caja        := null;
                       r_gmovi.cod_rubro       := NULL;

                       PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, 'N'); -- no es nocturno
                    end if;
                 end;
--------------------------------------------------------------------------------------------------------------------
         end loop;

         --- Cursor de bienes sin oficinas detalladas
         for reg in c_bienes loop
            if reg.cod_articulo is not null then
               --- Obtener parametros del Articulo
               prf_obt_articulo(reg.cod_articulo, rv_art);
               ---
               if nvl(rv_art.ind_act_fijo,'N') = 'S' or nvl(rv_art.ind_suministro,'N') = 'S' then
                  v_val_compra := nvl(reg.val_total,0);
                  v_val_neto   := nvl(reg.mto_neto,0);
                  v_val_impuesto := nvl(reg.val_impuesto,0);
                   /*09/12/2013 PN DI: Se envían la transacción padre como parámetro al procedimiento PRF_GEN_BIEN,
                                       con el fin de que se genereren los movimientos de bienes con la misma*/

                  PRF_GEN_BIEN(reg.fecha ,
                               reg.cod_ent_proveedor,
                               reg.tip_comprobante ,
                               reg.nro_factura,
                               reg.cantidad,
                               reg.cod_articulo,
                               reg.cod_oficina,
                               reg.cod_area,
                               v_val_compra,
                               v_val_neto,--det.mto_neto,
                               v_val_impuesto,--det.val_impuesto,
                               reg.cod_moneda,--v_cod_mon_local,
                               reg.descripcion,
                               reg.transaccion_iva,
                               v_hora,
                               v_nro_secuencia,
                               reg.tip_venta,
                               reg.cod_compra,
                               v_cod_mod_padre,
                               v_cod_mad_padre,
                               v_cod_tra_padre);
               end if;
               ---
               --- Actualizar Articulo
               ---
               if reg.cod_oficina = v_ofi_suministro and reg.cod_area = v_area_suministro then
                  Update af_articulos
                     set can_total = nvl(can_total,0) + reg.cantidad,
                         fec_ult_movimiento = v_fec_actual,
                         hor_ult_movimiento = v_hora
                   where cod_articulo = reg.cod_articulo;
                   if sql%notfound then
                      raise_application_error(-20000,'El articulo no fue actualizado');
                   end if;
               else
                   Update af_articulos
                      set fec_ult_movimiento = v_fec_actual,
                          hor_ult_movimiento = v_hora
                    where cod_articulo = reg.cod_articulo;
                    if sql%notfound then
                       raise_application_error(-20000,'El articulo no fue actualizado');
                    end if;
               end if;
            else
               -- sin articulo
               -- movimientos directos por la transaccion
------------------------------------------------------------------------------------------------------------------
               declare
               -- Datos para generar el movimiento
               v_fec_actual        date         := pag_cal.fu_obt_fec_actual(13); -- fecha de hoy
               v_hor_actual        varchar2(08) := to_char(sysdate,'HH24:MI:SS'); -- Hora actual
               v_cod_usuario       varchar2(10) := upper(user);                   -- usuario
               r_gmovi             ge_movimientos%rowtype;
               ---
               v_impuesto          pv_compras_det.val_impuesto%type;
               v_val_compra        af_bienes.val_compra%type;
               v_val_unitario      af_bienes.val_compra%type;
               ---
               begin
                  --- Obtengo el maximo nro. de secuencia
                  --- para evitar error de PK en GE_MOVIMIENTOS
                  ---
                  v_hor_actual := nvl(p_hora, to_char(sysdate,'HH24:MI:SS'));
                  v_nro_secuencia := nvl(v_nro_secuencia,0);
                  ---
                  ---AP 2870 29-05-2012 V.V.
                  v_cotizacion := nvl(pag_gen.fu_obt_cotizacion( reg.cod_moneda, v_fec_actual),1);
                  ---------------------------
                  --- INSERTAR MOVIMIENTO ---
                  ---------------------------
                  -- Aumento la secuencia
                  if v_nro_secuencia  = 999 then
                     v_hor_actual    := pag_gen.fu_obt_sig_segundo(v_hor_actual);
                     v_nro_secuencia := 0;
                  end if;
                  v_nro_secuencia := nvl(v_nro_secuencia,0) + 1;
                  -- Genero el movimiento x el monto sin el impuesto
                  r_gmovi.cod_modulo      := reg.cod_modulo;
                  r_gmovi.cod_modalidad   := reg.cod_modalidad;
                  r_gmovi.cod_oficina     := reg.cod_oficina;
                  r_gmovi.nro_cuenta      := null;
                  r_gmovi.cod_moneda      := reg.cod_moneda;
                  r_gmovi.cod_usuario     := v_cod_usuario;
                  r_gmovi.hora            := v_hor_actual;
                  r_gmovi.fecha           := v_fec_actual;
                  r_gmovi.nro_secuencia   := v_nro_secuencia;
                  --
                  r_gmovi.fec_valor       := v_fec_actual;
                  -- 09/09/2013 PN DI: Para unificar las transacciones Padres --
                  /*r_gmovi.cod_tra_padre   := 2801;
                  r_gmovi.cod_mod_padre   := reg.cod_modulo;
                  r_gmovi.cod_mad_padre   := reg.cod_modalidad;*/
                  r_gmovi.cod_tra_padre   := v_cod_tra_padre;
                  r_gmovi.cod_mod_padre   := v_cod_mod_padre;
                  r_gmovi.cod_mad_padre   := v_cod_mad_padre;

                  r_gmovi.cod_transaccion := reg.cod_transaccion;
                  r_gmovi.monto           := nvl(reg.val_total,0);
                  r_gmovi.nro_documento   := reg.nro_linea;
                  -- DYDMR-7799 - Incidencia SAU - ITGF - Incidencia al Reversar las facturas de proveedores
                  r_gmovi.nro_documento2   := reg.cod_compra;
                  r_gmovi.nro_documento3   := reg.cod_ent_proveedor;
                  --
                  r_gmovi.cod_tasa        := null;
                  r_gmovi.val_tasa        := null;
                 /* if reg.cod_moneda <> v_cod_mon_local then
                     if nvl(reg.tip_impuesto,0) = 0 then
                        r_gmovi.mto_equ_local   := round((nvl(reg.val_total,0) * v_cotizacion),v_redondeo);
                     else
                        r_gmovi.mto_equ_local   := round(((nvl(reg.tot_compra,0) * 100) / (reg.tip_impuesto + 100) * v_cotizacion),v_redondeo);
                     end if;
                     r_gmovi.cotizacion      := v_cotizacion;
                  else*/
                     r_gmovi.mto_equ_local   := null;
                     r_gmovi.cotizacion      := null;
                  --end if;
                  r_gmovi.cod_ofi_origen  := v_cod_ofi_origen;
                  r_gmovi.emi_aviso       := 'N';
                  r_gmovi.concepto        := reg.descripcion;
                  r_gmovi.estado          := 'N';
                  r_gmovi.reversado       := 'N';
                  r_gmovi.nro_caja        := null;
                  r_gmovi.cod_rubro       := NULL;

                  PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, 'N'); -- no es nocturno
                 end;
------------------------------------------------------------------------------------------------------------------
            end if;
         end loop;
EXCEPTION
  WHEN OTHERS THEN
    IF sqlcode = -54 THEN
      RAISE_APPLICATION_ERROR(-20001,'Reg. para Aprobación de Fact.: '||p_nro_factura||' se encuentra bloqueado por otro usuario. Vuelva a intentarlo.');
    ELSIF sqlcode = -20000 then
      RAISE;
    ELSE
      RAISE_APPLICATION_ERROR('-20002', 'Error en PRK_APR_FACTURA. Nro.Fact. '||p_nro_factura||' Fecha: '||p_fecha||' Hora: '||p_hora);
    END IF;
END PRK_APR_FACTURA;
/

