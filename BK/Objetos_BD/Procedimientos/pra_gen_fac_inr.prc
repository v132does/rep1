CREATE OR REPLACE PROCEDURE IT.PRA_GEN_FAC_INR
 (P_FECHA         IN DATE default null,
  p_cod_persona   in ge_inr_retenciones.cod_persona%type default null,
  p_nro_cuenta    in ge_inr_retenciones.nro_cuenta%type default null,
  p_nro_fac_generado   in out ge_inr_retenciones.nro_cuenta%type)IS
--- Variables de corte de control
   v_cod_persona  cb_lib_compras.cod_persona%type;
   v_nro_tim_fac  cb_lib_compras.nro_timbrado%type;
   v_fec_vig_tim  date;
   rv_blven       cb_lib_compras%rowtype;
   rv_blvde       cb_lib_compras_det%rowtype;
   rv_blcom       cb_lib_compras%rowtype;
   rv_blcde       cb_lib_compras_det%rowtype;
   v_nro_factura  cb_lib_compras.nro_factura%type;
   v_nro_fac_inr   cb_lib_compras.Nro_Factura%type;
   v_fec_proceso  date;
   v_nro_lin_fac  number(8);  -- Nro. de Lineas que puede tener una factura
   v_nro_linea    number(8);  -- Cantidad de lineas impresas de la factura
   v_cod_oficina  number(3);
   v_tip_compra   cb_lib_compras.tipo%type;
   v_cod_mon_factura varchar2(5);
   v_pun_expedicion number(3); -- Punto de Expedicion del comprobante
   v_lugar varchar2(1000) := null;
   v_cod_ofi_hacienda ba_oficinas.cod_oficina%type;
   v_borrado          NUMBER := 0; --bandera para borrar cabecera cb_lib_compras_tmp
   v_max_cuota        cb_lib_compras.can_cuota%type := 0;
   v_auxiliar         cb_lib_compras.can_cuota%type := 0;
   v_cod_ofi_cambio   number := to_number(nvl(fug_obt_pardinamico('COD_OFI_POS_CAMBIOS'),'1'));
   v_mensaje          varchar2(100);
   --- Cursor de movimientos de la persona por factura
   cursor c_facturas is
    -- cursor c_compras
     select nvl(v.cod_persona,0)cod_persona, v.fecha, v.hora, v.cod_usuario, v.nro_secuencia, v.cod_ofi_origen,
            v.tip_comprobante, v.tip_compra tip_factura,
            v.cod_mod_padre, v.cod_mad_padre, v.cod_tra_padre,
            v.descripcion,
            v.cod_moneda, v.mto_exento, v.mto_exento_gs, v.mto_gravado_5, v.mto_gra_5_gs,
            v.mto_gravado_10, v.mto_gra_10_gs, v.impuesto_5, v.impuesto_5_gs,
            v.impuesto_10, v.impuesto_10_gs, v.cotizacion, nvl(c.cod_oficina,v.cod_ofi_origen) cod_oficina, v.nom_completo,
            v.nro_doc_persona nro_documento, p.tipo, v.nro_cuenta,
            v.nro_documento nro_recibo, v.rowid fila, v.aju_impuesto_5, v.aju_impuesto_10,
            v.cod_moneda cod_mon_factura,
            v.can_cuota, v.cod_modulo,v.cod_modalidad,v.cod_transaccion, 'C' tip_operacion,p.tip_iva, /*DYDMR-5605 NAF 03/2017*/
            v.referencia
       from cb_lib_compras_det_tmp v,
            ge_clientes c,
            ba_personas p
      where nvl(v.reversado,'N') = 'N'
        and nvl(v.tip_comprobante,'X') = 'I'  -- CNFNORMA-18/RABP/10-2016: Debe incluir operaciones de cambio
        and c.cod_persona(+) =  v.cod_persona
        and p.cod_persona(+)  = v.cod_persona
        --- Verificar si tiene parámetros
        and v.cod_persona  = nvl(p_cod_persona,v.cod_persona)
        and v.nro_cuenta   = nvl(p_nro_cuenta,v.nro_cuenta)
        and v.fecha        = nvl(p_fecha,v.fecha)
        and v.error is null  -- solo tomas los que no tienen error
     order by nom_completo, cod_persona, cod_mon_factura, fecha, hora, tip_operacion;
     
 TYPE cursor1_type IS TABLE OF c_facturas%ROWTYPE;
   reg cursor1_type;
BEGIN
   -- Registrar el nombre en action
   DBMS_APPLICATION_INFO.SET_ACTION('PRA_GEN_FAC_INR');
   DBMS_APPLICATION_INFO.SET_CLIENT_INFO('PRA_GEN_FAC_INR, Iniciando');
   Begin pre_ini_aplicacion;pae_cnf.G_COD_MODULO:=1;end;
   v_cod_persona := '.';
   v_tip_compra  := '.';
   v_cod_mon_factura := '.';
   v_nro_lin_fac := 1;   -- esta es la cantidad de lineas por factura que se puede imprimir
   v_nro_linea   := 0;
   v_fec_proceso := pag_cal.fu_obt_fec_actual(1);   
   OPEN c_facturas;
    LOOP
      FETCH c_facturas BULK COLLECT INTO reg LIMIT 2500;
      FOR i IN 1 .. reg.count LOOP  
         -- Monitoreo del avance cada 100 registros o al final
        IF MOD(i, 100) = 0 OR i = reg.COUNT THEN
            v_mensaje := 'Procesando registro' || i || ' de ' || reg.COUNT;
            DBMS_APPLICATION_INFO.SET_CLIENT_INFO(v_mensaje);
        END IF;
      v_lugar := reg(i).cod_persona;
      --30/06/2010: No procesar los registros marcados
      --con tipo comprobante ='X', corresponden a Iva s/Interes vencido ya cobrado y facturado.
        -- Factura Compra --
        if reg(i).tip_operacion = 'C' then
          --- Corte de control --
          if nvl(v_cod_persona,'-1') <> nvl(reg(i).cod_persona,'-1')
          or nvl(v_tip_compra,'.') <> nvl(reg(i).tip_factura,'.')
          or nvl(v_cod_mon_factura,'.') <> nvl(reg(i).cod_mon_factura,'.')
          or v_nro_linea + 1 > v_nro_lin_fac then
             v_cod_oficina := reg(i).cod_oficina; -- Modificado 05/03/2010 por ICL - para que tome oficina del cliente
             --- Insertar cabecera para la factura --
             v_cod_ofi_hacienda :=fug_obt_pardinamico('COD_OFI_HACIENDA', null, null, null, v_cod_oficina);
             if v_cod_ofi_hacienda is null then
               raise_application_error(-20000, 'No se ha definido el parametro COD_OFI_HACIENDA para la oficina '||v_cod_oficina);
             end if;

             v_pun_expedicion := pab_iva.fu_obt_pun_expedicion('I'); -- Punto de expedicion diferente para Compras --
             pab_iva.pr_obt_nro_factura(v_cod_ofi_cambio, v_fec_proceso, 'I', v_nro_factura, v_nro_tim_fac, v_fec_vig_tim);

             rv_blcom.nro_factura      := lpad(v_cod_ofi_hacienda,3,'0')||
                                              '-'||lpad(v_pun_expedicion,3,'0')||
                                              '-'||lpad(to_char(v_nro_factura),7,'0');
             v_nro_fac_inr         := rv_blcom.nro_factura;
             rv_blcom.fecha            := v_fec_proceso;
             rv_blcom.tipo             := reg(i).tip_factura;
             if reg(i).cod_persona is not null then
               rv_blcom.cod_persona    := reg(i).cod_persona;
               rv_blcom.raz_social     := reg(i).nom_completo;
               rv_blcom.nro_documento  := reg(i).nro_documento;
             else
               rv_blcom.cod_persona    := null;
               rv_blcom.raz_social     := 'SIN NOMBRE';
               rv_blcom.nro_documento  := 'X';
             end if;
             rv_blcom.mto_exento       := reg(i).mto_exento;
             rv_blcom.mto_gravado_10   := reg(i).mto_gravado_10;
             rv_blcom.impuesto_10      := reg(i).impuesto_10;
             rv_blcom.mto_gravado_5    := reg(i).mto_gravado_5;
             rv_blcom.impuesto_5       := reg(i).impuesto_5;
             rv_blcom.nro_timbrado     := v_nro_tim_fac;
             rv_blcom.cod_ofi_origen   := reg(i).cod_ofi_origen;
             rv_blcom.cod_ent_proveedor:= 999;
             rv_blcom.fec_pago         := v_fec_proceso;
             rv_blcom.can_cuota        := 0;  -- Cuota cero porque siempre es contado en Operacion de Cambio
             rv_blcom.tip_origen       := reg(i).tip_comprobante;
             --- Insertamos datos cabecera ---
             prb_ins_lib_compras(rv_blcom);


             --- Insertar detalle para la factura --
             rv_blcde.nro_factura        := rv_blcom.nro_factura;
             rv_blcde.cod_persona        := rv_blcom.cod_persona;
             rv_blcde.nro_timbrado       := rv_blcom.nro_timbrado;
             rv_blcde.fecha              := rv_blcom.fecha;
             rv_blcde.hora               := reg(i).hora;
             rv_blcde.cod_usuario        := reg(i).cod_usuario;
             rv_blcde.nro_secuencia      := reg(i).nro_secuencia;
             rv_blcde.cod_oficina        := reg(i).cod_oficina;
             rv_blcde.cod_moneda         := reg(i).cod_mon_factura;
             rv_blcde.mto_operacion_me   := reg(i).mto_exento;
             rv_blcde.cotizacion         := reg(i).cotizacion;
             rv_blcde.cod_mon_operacion  := reg(i).cod_moneda;
             rv_blcde.fec_vig_timbrado   := v_fec_vig_tim;
             rv_blcde.cod_mod_padre      := reg(i).cod_mod_padre;
             rv_blcde.cod_mad_padre      := reg(i).cod_mad_padre;
             rv_blcde.cod_modulo         := reg(i).cod_modulo;
             rv_blcde.cod_modalidad      := reg(i).cod_modalidad;
             rv_blcde.cod_tra_padre      := reg(i).cod_tra_padre;
             rv_blcde.cod_transaccion     := reg(i).cod_transaccion;
             rv_blcde.tip_comprobante    := 'I';
             rv_blcde.nro_cuenta         := reg(i).nro_cuenta;
             --- Insertamos datos detalle ---
             pab_iva.PR_INS_LIB_COM_DET(rv_blcde);

             update ge_inr_retenciones r
                set r.nro_factura = rv_blcom.nro_factura,
                    r.nro_timbrado = rv_blcom.nro_timbrado,
                    r.fec_vig_timbrado = v_fec_vig_tim
              where r.nro_cuenta = reg(i).nro_cuenta
                and r.nro_cupon = reg(i).referencia;

             --- Eliminar factura del temporal
              delete cb_lib_compras_det_tmp
               where rowid = reg(i).fila;
            end if;

      end if;
     end loop;
     EXIT WHEN c_facturas%NOTFOUND;
    END LOOP;
    close c_facturas; 
    -- Dejar null la acción para que no quede en memoria 
    DBMS_APPLICATION_INFO.SET_ACTION(NULL);
    DBMS_APPLICATION_INFO.SET_CLIENT_INFO(NULL); 
 p_nro_fac_generado := v_nro_fac_inr;
 
exception
   when others then
    -- Dejar null la acción para que no quede en memoria 
    DBMS_APPLICATION_INFO.SET_ACTION(NULL);
    DBMS_APPLICATION_INFO.SET_CLIENT_INFO(NULL); 
    raise_application_error(-20033,v_lugar||sqlerrm);
END;
/
