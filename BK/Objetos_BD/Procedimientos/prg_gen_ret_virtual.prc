create or replace procedure IT.PRG_GEN_RET_VIRTUAL(P_FECHA IN GE_RET_PROVEEDORES.FEC_PAGO%TYPE DEFAULT NULL,
                                                   P_NRO_LOTE IN GE_RET_VIR_PROVEEDORES.NRO_LOTE%TYPE DEFAULT NULL) is
  --Objetos tipo listas
  ret_vir_lista     typ_jsonlist; -- definición del objeto principal tipo lista.
  ret_vir_det_lista typ_jsonlist; -- definición del bloque detalle tipo lista.
  --Objetos tipo únicos
  ret_virtual     typ_json; -- definición del objeto principal tipo único.
  ret_detalle     typ_json; -- definición del objeto del bloque detalle tipo único.
  ret_transaccion typ_json; -- definición del objeto del bloque transacción tipo único.
  ret_retencion   typ_json; -- definición del objeto del bloque retención tipo único.
  ret_informado   typ_json; -- definición del objeto del bloque informado tipo único.
  ret_atributo    typ_json; -- definición del objeto del bloque atributo tipo único.
  --Variables
  v_por_retencion number(3) := 0;
  v_nro_lote      ge_ret_vir_proveedores.nro_lote%type := 0;
  v_existe        varchar2(1) := 'N';
  v_genera_dat    varchar2(1) := 'N';
  v_nom_archivo   varchar2(100);
  --Variables p/ generar archivo.
  v_arc_resultado clob;
  v_directorio    varchar2(100) := fug_obt_pardinamico('DIR_REP_FTP'); 
  c_cantidad      CONSTANT BINARY_INTEGER := 32767;
  v_buffer        VARCHAR2(32767);
  v_chr10         PLS_INTEGER;
  v_clob_tam      PLS_INTEGER;
  v_archivo       utl_file.file_type;
  v_posicion      PLS_INTEGER := 1;
  --Variables para FTP
  g_ip            VARCHAR2(100) := fug_obt_pardinamico('DIR_SVR_REP_ARCHIVOS');
  g_port          VARCHAR2(100) := fug_obt_pardinamico('PUERTO_FTP');
  g_user          VARCHAR2(100) := fug_obt_pardinamico('USU_FTP_REP_ARCHIVOS');
  g_pass          VARCHAR2(100) := fug_obt_pardinamico('PAS_FTP_REP_ARCHIVOS');
  g_dir_carpeta   VARCHAR2(100) := fug_obt_pardinamico('DIR_CAR_TESAKA');
  v_respuesta     VARCHAR2(4000);
  v_hini_ftp      ge_ra_log_ftp.hor_inicio%type;
  v_hfin_ftp      ge_ra_log_ftp.hor_fin%type;
  --parámetro principal
  v_fec_pago varchar2(10) := to_char(NVL(P_FECHA,fug_obt_fec_anterior(1)),'dd/mm/yyyy');
  v_fec_nro  varchar2(10) := to_char(NVL(P_FECHA,fug_obt_fec_anterior(1)),'RRMMDD');
  --irp
  v_por_ret_irp number(3) := 0;
  v_obs  varchar2(2000);
  --Cursor Principal del procedimiento de Retenciones Virtuales--
  Cursor retenciones is
    Select rp.nro_factura,
           to_char(rp.fec_pago, 'dd/mm/yyyy') fec_pago,
           pas_cri.fu_obt_mon_iso(rp.cod_moneda) moneda,
           to_char(rp.fec_pago, 'YYYY-MM-DD') fecha,
           decode(rp.mto_renta, 0, 'false', 'true') retencionRenta,
           decode(rp.mto_renta, 0, '', 'RENTA_PERSONAL_REGISTRADO.'||nvl((substr((fug_obt_parentes(rp.cod_proveedor,'CON_RET_IRP')),2,1)),2)) conceptoRenta,
           v_por_retencion ivaPorcentaje5,
           v_por_retencion ivaPorcentaje10,
           0 rentaCabezasBase,
           0 rentaCabezasCantidad,
           0 rentaToneladasBase,
           0 rentaToneladasCantidad,
           decode(rp.mto_renta, 0, 0,to_number(nvl(fug_obt_parentes(rp.cod_proveedor,'POR_RET_IRP'),v_por_ret_irp))) rentaPorcentaje,
           decode(rp.monto_retencion, null, 'false', 'true') retencionIva,
           decode(rp.monto_retencion, null, '', 'IVA.1') conceptoIva,
           p.nom_completo nombre,
           'CONTRIBUYENTE' situacion,
           substr(pc.ruc, 1, instr(pc.ruc, '-') - 1) ruc,
           to_char(FUE_OBT_RUC_DIG_VERIFICADOR(substr(pc.ruc,
                                                      1,
                                                      instr(pc.ruc, '-') - 1))) dv,
           FUE_OBT_DIR_PRINCIPA(p.cod_persona) domicilio,
           rp.cod_proveedor,
           rp.importe,
           rp.cod_moneda,
           rp.nro_retencion,
           rp.monto_retencion,
           rp.monto_iva,
           round(rp.cotizacion) tipoCambio,
           rp.mto_renta,
           rp.mto_ret_renta,
           rp.nro_timbrado,
           rp.fec_vig_timbrado,
           p.cod_persona,
           pc.timbrado nro_tim_factura
      From ge_ret_proveedores rp,
           ba_personas        p,
           pv_compras         pc
     Where to_char(rp.fec_pago, 'dd/mm/yyyy') = v_fec_pago
       and (FUE_OBT_PER_ENTE(rp.cod_proveedor)) = p.cod_persona
       and rp.cod_proveedor = pc.cod_ent_proveedor
       and rp.fec_pago = pc.fec_pago
       and rp.nro_factura = pc.nro_factura
       and rp.estado = 'N'
       and pc.tot_impuesto > 0 
       and rp.nro_factura not in
           (select rv.nro_factura
              from ge_ret_vir_proveedores rv
             where rv.cod_proveedor = rp.cod_proveedor
               and rv.nro_factura = rp.nro_factura
               and rv.fec_pago = rp.fec_pago)
      Order by pc.cod_compra;

  --Cursor secundario para armar los datos de la transaccion y el detalle para cada linea de compra.
  Cursor detalle(p_nro_factura in varchar2, p_fec_pago in date, p_cod_proveedor in number, p_nro_timbrado in number) is
    Select cd.cantidad cantidad,
           to_char(round(cd.tip_impuesto, 0)) tasaAplica,
           round(cd.val_unitario, 2) precioUnitario,
           fug_eli_acentos(cd.descripcion) descripcion,
           cc.nro_factura numeroComprobanteVenta,
           decode(cc.tip_venta, 'CO', 'CONTADO', 'CR', 'CREDITO') condicionCompra,
           decode(cc.tip_venta, 'CO', 0, 'CR', 1) cuotas,
           decode(cc.tip_comprobante, 'F', 1, 'T', 5, null) tipoComprobante,
           to_char(cc.fecha, 'YYYY-MM-DD') fecha,
           substr(cc.timbrado,1,8) numeroTimbrado
      From pv_compras cc, pv_compras_det cd
     Where cc.nro_factura = p_nro_factura
       and to_char(cc.fec_pago, 'dd/mm/yyyy') =
           to_char(p_fec_pago, 'dd/mm/yyyy')
       and cc.cod_ent_proveedor = p_cod_proveedor
       and cc.timbrado = p_nro_timbrado    
       and cc.cod_compra = cd.cod_compra;

  -- Cursor para re-procesar por Lotes
  Cursor lotes is
    Select rp.nro_factura,
           to_char(rp.fec_pago, 'dd/mm/yyyy') fec_pago,
           pas_cri.fu_obt_mon_iso(rp.cod_moneda) moneda,
           to_char(rp.fec_pago, 'YYYY-MM-DD') fecha,
           decode(rp.mto_renta, 0, 'false', 'true') retencionRenta,
           decode(rp.mto_renta, 0, '', 'RENTA_PERSONAL_REGISTRADO.'||nvl((substr((fug_obt_parentes(rp.cod_proveedor,'CON_RET_IRP')),2,1)),2)) conceptoRenta,
           v_por_retencion ivaPorcentaje5,
           v_por_retencion ivaPorcentaje10,
           0 rentaCabezasBase,
           0 rentaCabezasCantidad,
           0 rentaToneladasBase,
           0 rentaToneladasCantidad,
           decode(rp.mto_renta,0, '',to_number(nvl(fug_obt_parentes(rp.cod_proveedor,'POR_RET_IRP'),v_por_ret_irp))) rentaPorcentaje,
           decode(rp.monto_retencion, null, 'false', 'true') retencionIva,
           decode(rp.monto_retencion, null, '', 'IVA.1') conceptoIva,
           p.nom_completo nombre,
           'CONTRIBUYENTE' situacion,
           substr(pc.ruc, 1, instr(pc.ruc, '-') - 1) ruc,
           
           to_char(FUE_OBT_RUC_DIG_VERIFICADOR(substr(pc.ruc,
                                                      1,
                                                      instr(pc.ruc, '-') - 1))) dv,
           FUE_OBT_DIR_PRINCIPA(p.cod_persona) domicilio,
           rp.cod_proveedor,
           rp.importe,
           rp.cod_moneda,
           rp.nro_retencion,
           rp.monto_retencion,
           rp.monto_iva,
           round(rp.cotizacion) tipoCambio,
           rp.mto_renta,
           rp.mto_ret_renta,
           rp.nro_timbrado,
           rp.fec_vig_timbrado,
           p.cod_persona,
           pc.timbrado nro_tim_factura
      From ge_ret_vir_proveedores rp,
           ba_personas            p,
           pv_compras             pc
     Where to_char(rp.fec_pago, 'dd/mm/yyyy') = v_fec_pago
       and (FUE_OBT_PER_ENTE(rp.cod_proveedor)) = p.cod_persona
       and rp.cod_proveedor = pc.cod_ent_proveedor
       and rp.fec_pago = pc.fec_pago
       and rp.nro_factura = pc.nro_factura
       and rp.nro_lote = P_NRO_LOTE
       Order by pc.cod_compra;

  -- Función para transformar dato a boolean.
  FUNCTION lf_boolean(p_valor varchar2) RETURN BOOLEAN IS
  BEGIN
    if p_valor = 'true' then
      RETURN TRUE;
    else
      RETURN FALSE;
    end If;
  
  END;
  --        

Begin
  --Obtiene el porcentaje de Retenciones una sola vez.
  v_por_retencion := fug_obt_pardinamico('POR_RET_PROVEEDOR'); --iva
  v_por_ret_irp   := fug_obt_pardinamico('POR_RET_IRP_PROVEEDOR'); --irp
  --Genera Nro. Lote.
  Begin
    select s_ret_vir_nro_lote.nextval 
      into v_nro_lote 
      from dual;
    exception
    when others then
      v_nro_lote := null;
  End; 
  Begin
    select to_number(v_fec_nro ||v_nro_lote)
      into v_nro_lote
      from dual;
  exception
    when others then
      v_nro_lote := to_number(v_fec_nro);
  End;
  --Inicializa el objeto Principal del tipo lista.
  ret_vir_lista := typ_jsonlist();

  If P_NRO_LOTE IS NULL THEN   --Si no es un reproceso. 
    
    For ret in retenciones Loop     
      
      v_genera_dat := 'S';  --Si existen datos a generar.
      
      --Inicializa el objeto del tipo lista del bloque detalle.
      ret_vir_det_lista := typ_jsonlist();
      
      For det in detalle(ret.nro_factura,to_date(ret.fec_pago, 'dd/mm/yyyy'),ret.cod_proveedor,ret.nro_tim_factura) Loop
        --Arma los datos del bloque detalle para cada linea.
        --Inicializa el objeto
        ret_detalle := typ_json();
        -- Agrega campos
        ret_detalle.put('cantidad', det.cantidad);
        ret_detalle.put('tasaAplica', det.tasaAplica);
        ret_detalle.put('precioUnitario', det.precioUnitario);
        ret_detalle.put('descripcion', det.descripcion);
        --Agrega una linea para el bloque detalle del tipo lista.
        ret_vir_det_lista.append(ret_detalle.to_typ_jsonvalue);
      
        --Arma los datos del bloque transacci¿n.
        --Inicializa el objeto
        ret_transaccion := typ_json();
        -- Agrega campos
        ret_transaccion.put('numeroComprobanteVenta', det.numeroComprobanteVenta);
        ret_transaccion.put('condicionCompra', det.condicionCompra);
        If det.condicioncompra = 'CREDITO' then
           ret_transaccion.put('cuotas', det.cuotas);
        End If;
        ret_transaccion.put('tipoComprobante', det.tipoComprobante);
        ret_transaccion.put('fecha', det.fecha);
        ret_transaccion.put('numeroTimbrado', det.numeroTimbrado);
      End Loop;
    
      --Arma los datos del bloque retención. 
      --Inicializa el objeto
      ret_retencion := typ_json();
      -- Agrega campos
      ret_retencion.put('fecha', ret.fecha);
      ret_retencion.put('moneda', ret.moneda);
      If ret.moneda <> 'PYG' then
        ret_retencion.put('tipoCambio', ret.tipoCambio);
      End If;
      ret_retencion.put('retencionRenta', lf_boolean(ret.retencionRenta));
      ret_retencion.put('conceptoRenta', ret.conceptoRenta);
      ret_retencion.put('ivaPorcentaje5', ret.ivaPorcentaje5);
      ret_retencion.put('ivaPorcentaje10', ret.ivaPorcentaje10);
      ret_retencion.put('rentaCabezasBase', ret.rentaCabezasBase);
      ret_retencion.put('rentaCabezasCantidad', ret.rentaCabezasCantidad);
      ret_retencion.put('rentaToneladasBase', ret.rentaToneladasBase);
      ret_retencion.put('rentaToneladasCantidad',ret.rentaToneladasCantidad);
      ret_retencion.put('rentaPorcentaje', ret.rentaPorcentaje);
      ret_retencion.put('retencionIva', lf_boolean(ret.retencionIva));
      ret_retencion.put('conceptoIva', ret.conceptoIva);
    
      --Arma los datos del bloque informado.
      --Inicializa el objeto
      ret_informado := typ_json();
      -- Agrega campos
      ret_informado.put('situacion', ret.situacion);
      ret_informado.put('nombre', ret.nombre);
      ret_informado.put('ruc', ret.ruc);
      ret_informado.put('dv', ret.dv);
      ret_informado.put('domicilio', ret.domicilio);
      ret_informado.put('tipoIdentificacion', '');
      ret_informado.put('identificacion', '');
      ret_informado.put('direccion', '');
      ret_informado.put('correoElectronico', '');
      ret_informado.put('pais', '');
      ret_informado.put('telefono', '');
    
      --Arma los datos del bloque atributo.
      --Inicializa el objeto
      ret_atributo := typ_json();
      -- Agrega campos
      ret_atributo.put('fechaCreacion', to_char(sysdate, 'YYYY-MM-DD'));
      ret_atributo.put('fechaHoraCreacion',to_char(sysdate, 'YYYY-MM-DD HH:MM:SS'));
    
      --Arma los datos completos de todos los bloques del objeto final.
      --Inicializa el objeto
      ret_virtual := typ_json();
      -- Agrega campos
      ret_virtual.put('detalle', ret_vir_det_lista);
      ret_virtual.put('retencion', ret_retencion);
      ret_virtual.put('informado', ret_informado);
      ret_virtual.put('transaccion', ret_transaccion);
      ret_virtual.put('atributos', ret_atributo);
    
      --Agrega otra linea al objeto final.
      ret_vir_lista.append(ret_virtual.to_typ_jsonvalue);
    
      -- Insertar en la tabla de retenciones virtuales ya procesadas.
      insert into ge_ret_vir_proveedores
        (cod_proveedor,
         fec_pago,
         nro_factura,
         importe,
         cod_moneda,
         nro_retencion,
         monto_iva,
         monto_retencion,
         estado,
         cotizacion,
         mto_renta,
         mto_ret_renta,
         usu_insercion,
         fec_insercion,
         fec_cam_estado,
         nro_timbrado,
         fec_vig_timbrado,
         nro_lote,
         nro_ret_tesaka)
      values
        (ret.cod_proveedor,
         to_date(ret.fec_pago, 'dd/mm/yyyy'),
         ret.nro_factura,
         ret.importe,
         ret.cod_moneda,
         ret.nro_retencion,
         ret.monto_iva,
         ret.monto_retencion,
         'G',
         ret.tipoCambio,
         ret.mto_renta,
         ret.mto_ret_renta,
         SUBSTR(USER, 1, 10),
         sysdate,
         null,
         ret.nro_timbrado,
         ret.fec_vig_timbrado,
         v_nro_lote,
         null);
    End Loop;
    
  Else  --Si se reprocesa el archivo por Nro de Lote.
    --Verifica que el Nro Lote exista.
    Begin
      Select 'S'
        Into v_existe
        From ge_ret_vir_proveedores r
       Where r.nro_lote = P_NRO_LOTE;
    Exception
      When no_data_found then
        v_existe := 'N';
        raise_application_error(-20001,'No existe el Nro. Lote: ' || P_NRO_LOTE || ' ' ||SQLERRM);
      When too_many_rows then
        v_existe := 'S';
      When others then
        v_existe := 'N';
        raise_application_error(-20001, 'Error al verificar Nro. Lote: ' || P_NRO_LOTE || ' ' || SQLERRM);
    End;
    
    If v_existe = 'S' then
      For lot in lotes Loop
        
        v_genera_dat := 'S'; --Si existen datos a generar.
        
        --Inicializa el objeto del tipo lista del bloque detalle.
        ret_vir_det_lista := typ_jsonlist();
        
        For det in detalle(lot.nro_factura,to_date(lot.fec_pago, 'dd/mm/yyyy'),lot.cod_proveedor,lot.nro_tim_factura) Loop
          --Arma los datos del bloque detalle para cada linea.
          --Inicializa el objeto
          ret_detalle := typ_json();
          -- Agrega campos
          ret_detalle.put('cantidad', det.cantidad);
          ret_detalle.put('tasaAplica', det.tasaAplica);
          ret_detalle.put('precioUnitario', det.precioUnitario);
          ret_detalle.put('descripcion', det.descripcion);
          --Agrega una linea para el bloque detalle del tipo lista.
          ret_vir_det_lista.append(ret_detalle.to_typ_jsonvalue);
        
          --Arma los datos del bloque transacción.
          --Inicializa el objeto
          ret_transaccion := typ_json();
          -- Agrega campos
          ret_transaccion.put('numeroComprobanteVenta',det.numeroComprobanteVenta);
          ret_transaccion.put('condicionCompra', det.condicionCompra);
          If det.condicioncompra = 'CREDITO' then
            ret_transaccion.put('cuotas', det.cuotas);
          End If;
          ret_transaccion.put('tipoComprobante', det.tipoComprobante);
          ret_transaccion.put('fecha', det.fecha);
          ret_transaccion.put('numeroTimbrado', det.numeroTimbrado);
        End Loop;
      
        --Arma los datos del bloque retención. 
        --Inicializa el objeto
        ret_retencion := typ_json();
        -- Agrega campos
        ret_retencion.put('fecha', lot.fecha);
        ret_retencion.put('moneda', lot.moneda);
        If lot.moneda <> 'PYG' then
          ret_retencion.put('tipoCambio', lot.tipoCambio);
        End If;
        ret_retencion.put('retencionRenta', lf_boolean(lot.retencionRenta));
        ret_retencion.put('conceptoRenta', lot.conceptoRenta);
        ret_retencion.put('ivaPorcentaje5', lot.ivaPorcentaje5);
        ret_retencion.put('ivaPorcentaje10', lot.ivaPorcentaje10);
        ret_retencion.put('rentaCabezasBase', lot.rentaCabezasBase);
        ret_retencion.put('rentaCabezasCantidad', lot.rentaCabezasCantidad);
        ret_retencion.put('rentaToneladasBase', lot.rentaToneladasBase);
        ret_retencion.put('rentaToneladasCantidad',lot.rentaToneladasCantidad);
        ret_retencion.put('rentaPorcentaje', lot.rentaPorcentaje);
        ret_retencion.put('retencionIva', lf_boolean(lot.retencionIva));
        ret_retencion.put('conceptoIva', lot.conceptoIva);
      
        --Arma los datos del bloque informado.
        --Inicializa el objeto
        ret_informado := typ_json();
        -- Agrega campos
        ret_informado.put('situacion', lot.situacion);
        ret_informado.put('nombre', lot.nombre);
        ret_informado.put('ruc', lot.ruc);
        ret_informado.put('dv', lot.dv);
        ret_informado.put('domicilio', lot.domicilio);
        ret_informado.put('tipoIdentificacion', '');
        ret_informado.put('identificacion', '');
        ret_informado.put('direccion', '');
        ret_informado.put('correoElectronico', '');
        ret_informado.put('pais', '');
        ret_informado.put('telefono', '');
      
        --Arma los datos del bloque atributo.
        --Inicializa el objeto
        ret_atributo := typ_json();
        -- Agrega campos
        ret_atributo.put('fechaCreacion', to_char(sysdate, 'YYYY-MM-DD'));
        ret_atributo.put('fechaHoraCreacion',to_char(sysdate, 'YYYY-MM-DD HH:MM:SS'));
      
        --Arma los datos completos de todos los bloques del objeto final.
        --Inicializa el objeto
        ret_virtual := typ_json();
        -- Agrega campos
        ret_virtual.put('detalle', ret_vir_det_lista);
        ret_virtual.put('retencion', ret_retencion);
        ret_virtual.put('informado', ret_informado);
        ret_virtual.put('transaccion', ret_transaccion);
        ret_virtual.put('atributos', ret_atributo);
      
        --Agrega otra linea al objeto final.
        ret_vir_lista.append(ret_virtual.to_typ_jsonvalue);
      End Loop;
    End If;
  End If;
 
  If v_genera_dat = 'S' then -- Solo si genera datos debe generar el archivo.

    -- Convierte a CLOB para generar el archivo.
    v_arc_resultado := empty_clob();
    dbms_lob.createtemporary(v_arc_resultado, true);
    ret_vir_lista.to_clob(v_arc_resultado, true);
    
    --Genera Nombre del Archivo
    If v_existe <> 'S' then
      v_nom_archivo := 'retenciones_' || v_nro_lote || '_' ||v_fec_nro||'.txt';
    Else
      v_nom_archivo := 'reproceso_ret_' || P_NRO_LOTE || '_' ||v_fec_nro||'.txt';
    End IF;
  
    -- Genera el archivo
    v_clob_tam := DBMS_LOB.GETLENGTH(v_arc_resultado);
    -- verificar conexiones abiertas anteriormente
    IF UTL_FILE.IS_OPEN(v_archivo) THEN
       UTL_FILE.FCLOSE(v_archivo);
	   UTL_FILE.FCLOSE_ALL;
    END IF;
    v_archivo  := UTL_FILE.FOPEN(v_directorio,v_nom_archivo,'W',c_cantidad);
    WHILE v_posicion < v_clob_tam LOOP
      v_buffer := DBMS_LOB.SUBSTR(v_arc_resultado, c_cantidad, v_posicion);
      EXIT WHEN v_buffer IS NULL;
      v_chr10 := INSTR(v_buffer, CHR(10), -1);
      IF v_chr10 != 0 THEN
        v_buffer := SUBSTR(v_buffer, 1, v_chr10 - 1);
      END IF;
      UTL_FILE.PUT_LINE(v_archivo, v_buffer, TRUE);
      v_posicion := v_posicion + LEAST(LENGTH(v_buffer) + 1, c_cantidad);
    END LOOP;
    UTL_FILE.FCLOSE(v_archivo);
  
    -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
    v_hini_ftp  := to_char(sysdate, 'hh24:mi:ss');
    v_respuesta := pa_file_ftp.fu_put_ascii(g_ip,
                                            g_port,
                                            g_user,
                                            g_pass,
                                            v_directorio,
                                            v_nom_archivo,
                                            g_dir_carpeta || v_nom_archivo);
    v_hfin_ftp  := to_char(sysdate, 'hh24:mi:ss');
    If v_respuesta <> 'OK' Then
      -- ERROR AL ENVIAR ARCHIVO POR FTP
      -- Insertamos el error del envio al directorio compartido
      INSERT INTO ge_ra_log_ftp
        (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
      VALUES
        (SYSDATE,
         'retenciones_' || v_nro_lote || '_' ||v_fec_nro|| '.txt',
         v_respuesta,
         v_hini_ftp,
         v_hfin_ftp);
      COMMIT;
    End If;      
  End IF;  
 exception
  when others then
       UTL_FILE.FCLOSE(v_archivo);
	     UTL_FILE.FCLOSE_ALL; 
       v_obs :=substr(trim(SQLERRM || ' ' ||'-'||' '||v_respuesta),1,400);      
       it.pag_cie.PR_AT_INS_LOG(153,1,'PRG_GEN_RET_VIRTUAL', v_obs, it.pag_cie.c_log_ERROR,'OUT',SYSDATE);             
End PRG_GEN_RET_VIRTUAL;

