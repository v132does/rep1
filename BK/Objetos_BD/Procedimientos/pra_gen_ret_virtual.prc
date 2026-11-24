create or replace procedure IT.PRA_GEN_RET_VIRTUAL(P_FECHA    IN ge_inr_retenciones.FEC_PAGO%TYPE DEFAULT NULL,
                                                   P_NRO_LOTE IN GE_RET_VIR_CLIENTES.NRO_LOTE%TYPE DEFAULT NULL) is
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
  v_nro_lote           GE_RET_VIR_CLIENTES.nro_lote%type := 0;
  v_existe             varchar2(1) := 'N';
  v_genera_dat         varchar2(1) := 'N';
  v_nom_archivo        varchar2(100);
  v_rem_mail           varchar2(3000) := fug_obt_pardinamico('DIR_MAIL_ARC_RETENCION');  
  --Variables p/ generar archivo.
  v_arc_resultado clob;
  v_directorio    varchar2(100) := fug_obt_pardinamico('DIR_REP_FTP');
  c_cantidad CONSTANT BINARY_INTEGER := 32767;
  v_buffer   VARCHAR2(32767);
  v_chr10    PLS_INTEGER;
  v_clob_tam PLS_INTEGER;
  v_archivo  utl_file.file_type;
  v_posicion PLS_INTEGER := 1;
  --Variables para FTP
  g_ip          VARCHAR2(100) := fug_obt_pardinamico('DIR_SVR_REP_ARCHIVOS');
  g_port        VARCHAR2(100) := fug_obt_pardinamico('PUERTO_FTP');
  g_user        VARCHAR2(100) := fug_obt_pardinamico('USU_FTP_REP_ARCHIVOS');
  g_pass        VARCHAR2(100) := fug_obt_pardinamico('PAS_FTP_REP_ARCHIVOS');
  g_dir_carpeta VARCHAR2(100) := fug_obt_pardinamico('DIR_CAR_RET_CLI_TESAKA');
  v_respuesta   VARCHAR2(4000);
  v_hini_ftp    ge_ra_log_ftp.hor_inicio%type;
  v_hfin_ftp    ge_ra_log_ftp.hor_fin%type;
  --parámetro principal
  v_fec_pago varchar2(10) := to_char(NVL(P_FECHA, fug_obt_fec_anterior(1)), 'dd/mm/yyyy');
  v_fec_nro  varchar2(10) := to_char(NVL(P_FECHA, fug_obt_fec_anterior(1)),'RRMMDD');
 --Variables de logs 
  v_obs      varchar(2000);

  --Cursor Principal del procedimiento de Retenciones Virtuales--
  Cursor retenciones is
    Select rp.nro_factura,
           to_char(rp.fec_pago, 'dd/mm/yyyy') fec_pago,
           rp.fec_retencion,
           pas_cri.fu_obt_mon_iso(rp.cod_moneda) moneda,
           to_char(rp.fec_pago, 'YYYY-MM-DD') fecha,
           decode(rp.mto_renta, 0, 'false', 'true') retencionRenta,
           'RENTA_NO_RESIDENTE.13' conceptoRenta,
           0 ivaPorcentaje5,
           0 ivaPorcentaje10,
           0 rentaCabezasBase,
           0 rentaCabezasCantidad,
           0 rentaToneladasBase,
           0 rentaToneladasCantidad,
           rp.por_retencion rentaPorcentaje,
           'false' retencionIva,
           decode(rp.mto_retencion, null, '', 'Pago Intereses') conceptoIva,
           p.nom_completo nombre,
           'NO_RESIDENTE' situacion,
           p.nro_documento identificacion,
           FUE_OBT_DIR_PRINCIPA(p.cod_persona) direccion,
           rp.cod_persona,
           rp.nro_cuenta,
           rp.mto_factura importe,
           rp.cod_moneda,
           rp.cod_retencion,
           rp.mto_retencion monto_retencion,
           0 monto_iva,
           round(rp.cotizacion) tipoCambio,
           rp.mto_renta,
           rp.mto_ret_renta,
           rp.nro_timbrado,
           rp.fec_vig_timbrado,
           pc.nro_timbrado nro_tim_factura,
           nvl(m.dir_correo, v_rem_mail) dir_correo,
           pai.cod_pai_iso pais
      From ge_inr_retenciones rp, ba_personas p, cb_lib_compras pc,
           ba_mails m, ba_direcciones dir, ba_paises pai
     Where to_char(rp.fec_retencion, 'dd/mm/yyyy') = v_fec_pago
       and rp.cod_persona = p.cod_persona
       and rp.cod_persona = pc.cod_persona
       and rp.fec_retencion = pc.fecha
       and rp.nro_factura = pc.nro_factura
       and rp.estado in ('G', 'I')
       and pc.mto_exento > 0
       and p.cod_persona = m.cod_persona(+)
       and m.principal = 'S'
       and p.cod_persona = dir.cod_persona(+)
       and dir.principal = 'S'
       and dir.cod_pais = pai.cod_pais
     Order by pc.nro_factura;

  --Cursor secundario para armar los datos de la transaccion y el detalle para cada linea de compra.
  Cursor detalle(p_nro_factura   in varchar2,
                 p_fec_pago      in date,
                 p_cod_persona   in cb_lib_compras.cod_persona%type,
                 p_nro_timbrado  in cb_lib_compras.nro_timbrado%type) is
    Select 1 cantidad,
           '0' tasaAplica,
           round(cc.mto_exento, 2) precioUnitario,
           'Pago de intereses' descripcion,
           cc.nro_factura numeroComprobanteVenta,
           'CONTADO' condicionCompra,
           0 cuotas,
           decode(cd.tip_comprobante, 'F', 1, 'I', 5, null) tipoComprobante,
           to_char(cc.fecha, 'YYYY-MM-DD') fecha,
           substr(cc.nro_timbrado, 1, 8) numeroTimbrado
      From cb_lib_compras cc, cb_lib_compras_det cd
     Where cc.nro_factura = p_nro_factura
       and to_char(cc.fecha, 'dd/mm/yyyy') =
           to_char(p_fec_pago, 'dd/mm/yyyy')
       and cc.cod_persona = p_cod_persona
       and cc.nro_timbrado = p_nro_timbrado
       and cc.cod_persona = cd.cod_persona
       and cc.nro_factura = cd.nro_factura;

  -- Cursor para re-procesar por Lotes
  Cursor lotes is
    Select rp.nro_factura,
           to_char(rp.fec_pago, 'dd/mm/yyyy') fec_pago,
           pas_cri.fu_obt_mon_iso(rp.cod_moneda) moneda,
           to_char(rp.fec_pago, 'YYYY-MM-DD') fecha,
           decode(rp.mto_renta, 0, 'false', 'true') retencionRenta,
           'RENTA_NO_RESIDENTE.13' conceptoRenta,
           0 ivaPorcentaje5,
           0 ivaPorcentaje10,
           0 rentaCabezasBase,
           0 rentaCabezasCantidad,
           0 rentaToneladasBase,
           0 rentaToneladasCantidad,
           15 rentaPorcentaje,
           'false' retencionIva,
           decode(rp.mto_retencion, null, '', 'Pago Intereses') conceptoIva,
           p.nom_completo nombre,
           'NO_RESIDENTE' situacion,
           p.nro_documento identificacion,
           FUE_OBT_DIR_PRINCIPA(p.cod_persona) direccion,
           rp.cod_persona,
           rp.imp_factura,
           rp.cod_moneda,
           rp.cod_retencion,
           rp.mto_retencion,
           rp.mto_iva,
           round(rp.cotizacion) tipoCambio,
           rp.mto_renta,
           rp.mto_ret_renta,
           rp.nro_timbrado,
           rp.fec_vig_timbrado,
           pc.nro_timbrado nro_tim_factura,
           nvl(m.dir_correo, v_rem_mail) dir_correo,
           pai.cod_pai_iso pais
      From GE_RET_VIR_CLIENTES rp, ba_personas p, cb_lib_compras pc,
           ba_mails m, ba_direcciones dir, ba_paises pai
     Where to_char(rp.fec_pago, 'dd/mm/yyyy') = v_fec_pago
       and rp.cod_persona = p.cod_persona
       and rp.cod_persona = pc.cod_persona
       and rp.fec_pago = pc.fec_pago
       and rp.nro_factura = pc.nro_factura
       and rp.nro_lote = P_NRO_LOTE
       and p.cod_persona = m.cod_persona(+)
       and m.principal = 'S'
       and p.cod_persona = dir.cod_persona(+)
       and dir.principal = 'S'
       and dir.cod_pais = pai.cod_pais
     Order by pc.nro_factura;

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
  --Genera Nro. Lote.
  Begin
    select s_ret_vir_nro_lote.nextval into v_nro_lote from dual;
  exception
    when others then
      v_nro_lote := null;
  End;
  Begin
    select to_number(v_fec_nro || v_nro_lote) into v_nro_lote from dual;
  exception
    when others then
      v_nro_lote := to_number(v_fec_nro);
  End;
  --Inicializa el objeto Principal del tipo lista.
  ret_vir_lista := typ_jsonlist();

  If P_NRO_LOTE IS NULL THEN
    --Si no es un reproceso.
  
    For ret in retenciones Loop
    
      v_genera_dat := 'S'; --Si existen datos a generar.
    
      --Inicializa el objeto del tipo lista del bloque detalle.
      ret_vir_det_lista := typ_jsonlist();
    
      For det in detalle(ret.nro_factura,
                         to_date(ret.fec_pago, 'dd/mm/yyyy'),
                         ret.cod_persona,
                         ret.nro_tim_factura) Loop
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
        ret_transaccion.put('numeroComprobanteVenta',
                            det.numeroComprobanteVenta);
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
      ret_retencion.put('rentaToneladasCantidad',
                        ret.rentaToneladasCantidad);
      ret_retencion.put('rentaPorcentaje', ret.rentaPorcentaje);
      ret_retencion.put('retencionIva',lf_boolean('false'));
      ret_retencion.put('conceptoIva', '');
    
      --Arma los datos del bloque informado.
      --Inicializa el objeto
      ret_informado := typ_json();
      -- Agrega campos
      ret_informado.put('situacion', ret.situacion);
      ret_informado.put('nombre', ret.nombre);
      ret_informado.put('ruc', '');
      ret_informado.put('dv', '');
      ret_informado.put('domicilio', '');
      ret_informado.put('tipoIdentificacion', 'IDENTIFICACION_TRIBUTARIA');
      ret_informado.put('identificacion', ret.identificacion);
      ret_informado.put('direccion', ret.direccion);
      ret_informado.put('correoElectronico', ret.dir_correo);
      ret_informado.put('pais', ret.pais);
      ret_informado.put('telefono', '');
    
      --Arma los datos del bloque atributo.
      --Inicializa el objeto
      ret_atributo := typ_json();
      -- Agrega campos
      ret_atributo.put('fechaCreacion', to_char(sysdate, 'YYYY-MM-DD'));
      ret_atributo.put('fechaHoraCreacion',
                       to_char(sysdate, 'YYYY-MM-DD HH:MM:SS'));
    
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
      insert into GE_RET_VIR_CLIENTES
        (cod_persona,
         fec_pago,
         nro_factura,
         imp_factura,
         cod_moneda,
         cod_retencion,
         mto_iva,
         mto_retencion,
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
        (ret.cod_persona,
         to_date(ret.fec_pago, 'dd/mm/yyyy'),
         ret.nro_factura,
         ret.importe,
         ret.cod_moneda,
         ret.cod_retencion,
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
    
      update ge_inr_retenciones r
         set r.estado = 'V'
       where r.cod_persona = ret.cod_persona
         and r.nro_cuenta = ret.nro_cuenta
         and r.fec_retencion = ret.fec_retencion;
    
    End Loop;
  
  Else
    --Si se reprocesa el archivo por Nro de Lote.
    --Verifica que el Nro Lote exista.
    Begin
      Select 'S'
        Into v_existe
        From GE_RET_VIR_CLIENTES r
       Where r.nro_lote = P_NRO_LOTE;
    Exception
      When no_data_found then
        v_existe := 'N';
        raise_application_error(-20001,
                                'No existe el Nro. Lote: ' || P_NRO_LOTE || ' ' ||
                                SQLERRM);
      When too_many_rows then
        v_existe := 'S';
      When others then
        v_existe := 'N';
        raise_application_error(-20001,
                                'Error al verificar Nro. Lote: ' ||
                                P_NRO_LOTE || ' ' || SQLERRM);
    End;
  
    If v_existe = 'S' then
      For lot in lotes Loop
      
        v_genera_dat := 'S'; --Si existen datos a generar.
      
        --Inicializa el objeto del tipo lista del bloque detalle.
        ret_vir_det_lista := typ_jsonlist();
      
        For det in detalle(lot.nro_factura,
                           to_date(lot.fec_pago, 'dd/mm/yyyy'),
                           lot.cod_persona,
                           lot.nro_tim_factura) Loop
          --Arma los datos del bloque detalle para cada linea.
          --Inicializa el objeto
          ret_detalle := typ_json();
          -- Agrega campos
          ret_detalle.put('cantidad', det.cantidad);
          ret_detalle.put('tasaAplica',det.tasaAplica);
          ret_detalle.put('precioUnitario', det.precioUnitario);
          ret_detalle.put('descripcion', det.descripcion);
          --Agrega una linea para el bloque detalle del tipo lista.
          ret_vir_det_lista.append(ret_detalle.to_typ_jsonvalue);
        
          --Arma los datos del bloque transacción.
          --Inicializa el objeto
          ret_transaccion := typ_json();
          -- Agrega campos
          ret_transaccion.put('numeroComprobanteVenta',
                              det.numeroComprobanteVenta);
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
        ret_retencion.put('rentaToneladasCantidad',
                          lot.rentaToneladasCantidad);
        ret_retencion.put('rentaPorcentaje', lot.rentaPorcentaje);
        ret_retencion.put('retencionIva', lf_boolean('false'));
        ret_retencion.put('conceptoIva', '');
      
        --Arma los datos del bloque informado.
        --Inicializa el objeto
        ret_informado := typ_json();
        -- Agrega campos
        ret_informado.put('situacion', lot.situacion);
        ret_informado.put('nombre', lot.nombre);
        ret_informado.put('ruc', '');
        ret_informado.put('dv', '');
        ret_informado.put('domicilio', '');
        ret_informado.put('tipoIdentificacion', 'IDENTIFICACION_TRIBUTARIA');
        ret_informado.put('identificacion', lot.identificacion);
        ret_informado.put('direccion', lot.direccion);
        ret_informado.put('correoElectronico', lot.dir_correo);
        ret_informado.put('pais', lot.pais);
        ret_informado.put('telefono', '');
      
        --Arma los datos del bloque atributo.
        --Inicializa el objeto
        ret_atributo := typ_json();
        -- Agrega campos
        ret_atributo.put('fechaCreacion', to_char(sysdate, 'YYYY-MM-DD'));
        ret_atributo.put('fechaHoraCreacion',
                         to_char(sysdate, 'YYYY-MM-DD HH:MM:SS'));
      
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

  If v_genera_dat = 'S' then
    -- Solo si genera datos debe generar el archivo y enviar al Ramail.
  
    -- Convierte a CLOB para generar el archivo.
    v_arc_resultado := empty_clob();
    dbms_lob.createtemporary(v_arc_resultado, true);
    ret_vir_lista.to_clob(v_arc_resultado, true);
  
    --Genera Nombre del Archivo
    If v_existe <> 'S' then
      v_nom_archivo := 'retenciones_inr_' || v_nro_lote || '_' || v_fec_nro ||
                       '.txt';
    Else
      v_nom_archivo := 'reproceso_ret_inr' || P_NRO_LOTE || '_' || v_fec_nro ||
                       '.txt';
    End IF;
  
    -- Genera el archivo
    v_clob_tam := DBMS_LOB.GETLENGTH(v_arc_resultado);
    v_archivo  := UTL_FILE.FOPEN(v_directorio,
                                 v_nom_archivo,
                                 'W',
                                 c_cantidad);
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
         'retenciones_inr' || v_nro_lote || '_' || v_fec_nro || '.txt',
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
       it.pag_cie.PR_AT_INS_LOG(152,1,'PRA_GEN_RET_VIRTUAL', v_obs, it.pag_cie.c_log_ERROR,'OUT',SYSDATE);             
End PRA_GEN_RET_VIRTUAL;

