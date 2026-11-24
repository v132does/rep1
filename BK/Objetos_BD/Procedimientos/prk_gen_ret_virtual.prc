create or replace procedure it.PRK_GEN_RET_VIRTUAL is

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
  v_genera_dat    varchar2(1) := 'N';
  v_nom_archivo   varchar2(100);
  -- Variables para FTP
  v_ip          VARCHAR2(100) := fug_obt_pardinamico('DIR_SVR_REP_ARCHIVOS');
  v_port        VARCHAR2(100) := fug_obt_pardinamico('PUERTO_FTP');
  v_user        VARCHAR2(100) := fug_obt_pardinamico('USU_FTP_REP_ARCHIVOS');
  v_pass        VARCHAR2(100) := fug_obt_pardinamico('PAS_FTP_REP_ARCHIVOS');    
  v_dir_carpeta varchar2(100)  := fug_obt_pardinamico('DIR_CAR_TESAKA');
  v_respuesta   VARCHAR2(4000);
  v_hini_ftp    ge_ra_log_ftp.hor_inicio%type;
  v_hfin_ftp    ge_ra_log_ftp.hor_fin%type;
  --Variables p/ generar archivo.
  v_arc_resultado clob;
  v_directorio varchar2(100) := fug_obt_pardinamico('PRV_DIR_ARC_RETENCION');
  c_cantidad   CONSTANT BINARY_INTEGER := 32767;
  v_buffer     VARCHAR2(32767);
  v_chr10      PLS_INTEGER;
  v_clob_tam   PLS_INTEGER;
  v_archivo    utl_file.file_type;
  v_posicion                 PLS_INTEGER := 1;
  v_tip_doc_informado        VARCHAR2(50);
  v_nro_doc_informado        VARCHAR2(20);
  v_tip_identificacion       VARCHAR2(50);
  --parámetro principal
  v_fec_pago varchar2(10)    := to_char(pag_cal.fu_obt_fec_anterior(1),'dd/mm/yyyy');
  v_fec_nro  varchar2(10)    := to_char(pag_cal.fu_obt_fec_anterior(1),'RRMMDD');
  v_fecha    date            := pag_cal.fu_obt_fec_anterior(1);
  v_hor_ini                  varchar2(8);
  v_hor_fin                  varchar2(8);
  --v_error                    varchar(2000);
  --v_mensaje                  varchar(2000);
  v_obs                      varchar(2000);
  --Cursor Principal del procedimiento de Retenciones Virtuales--
  Cursor retenciones is
    Select pc.cod_compra ,
           to_char(rp.fec_pago, 'dd/mm/yyyy') fec_pago,
           pas_cri.fu_obt_mon_iso(rp.cod_moneda) moneda,
           to_CHAR(rp.fec_pago, 'YYYY-MM-DD') fecha,
           'false' retencionRenta,
           '' conceptoRenta,
           v_por_retencion ivaPorcentaje5,
           v_por_retencion ivaPorcentaje10,
           0 rentaCabezasBase,
           0 rentaCabezasCantidad,
           0 rentaToneladasBase,
           0 rentaToneladasCantidad,
           0 rentaPorcentaje,
           decode(rp.monto_retencion, null, 'false', 'true') retencionIva,
           decode(rp.monto_retencion, null, '', 'IVA.1') conceptoIva,
           p.nom_completo nombre,
           'contribuyente' situacion,
           substr(pc.ruc, 1, instr(pc.ruc, '-') - 1) ruc,
           to_char(FUE_OBT_RUC_DIG_VERIFICADOR(substr(pc.ruc,
                                                      1,
                                                      instr(pc.ruc, '-') - 1))) dv,
           FUE_OBT_DIR_PRINCIPA(p.cod_persona) domicilio,
           '' direccion,
           '' telefono,
           ''  pais,
           ''  identificacion,
           null tipoidentificacion,
           '' correoelectronico,
           rp.cod_proveedor,
           pc.mto_mon_pago mto_pago,
           rp.cod_moneda,
           to_char(rp.nro_retencion) nro_retencion,
           rp.monto_retencion,
           rp.monto_retencion mto_ret_iva,
           rp.monto_iva,
           round(rp.cotizacion) tipoCambio,
           0 as mto_renta,
           0 as mto_ret_renta,
           p.cod_persona,
           pc.timbrado nro_tim_factura,
           0 cuotas,
           pc.nro_factura NumeroComprobanteVenta
     From ge_ret_proveedores rp,
           ba_personas        p,
           pv_compras         pc
     Where rp.fec_pago = to_date(v_fec_pago,'dd/mm/yyyy')
       and (FUG_OBT_PER_ENTE(rp.cod_proveedor)) = p.cod_persona
       and rp.cod_proveedor = pc.cod_ent_proveedor
       and pc.estado ='P'
       and rp.nro_factura = pc.nro_factura
       and rp.estado = 'N'
       and nvl(rp.est_ret_virtual,-1)  <> 'G'
       and pc.tot_impuesto > 0
       and rp.cod_moneda is not null
      Order by rp.nro_retencion;

  --Cursor secundario para armar los datos de la transaccion y el detalle para cada linea de compra.
  Cursor detalle(p_cod_compra in number) is
    Select cd.cantidad cantidad,
           to_char(round(cd.tip_impuesto, 0)) tasaAplica,
           round(cd.val_unitario, 2) precioUnitario,
           fue_obt_dat_valido(cd.descripcion) descripcion,
           cc.nro_factura numeroComprobanteVenta,
           decode(cc.tip_venta, 'CO', 'CONTADO', 'CR', 'CREDITO') condicionCompra,
           decode(cc.tip_venta, 'CO',0,'CR',1) cuotas,
           decode(cc.tip_comprobante, 'F', 1, 'T', 5, null) tipoComprobante,
           to_char(cc.fecha, 'YYYY-MM-DD') fecha,
           substr(cc.timbrado,1,8) numeroTimbrado
      From pv_compras cc, pv_compras_det cd
     Where cc.cod_compra = p_cod_compra
       and cc.cod_compra = cd.cod_compra;

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
PROCEDURE lp_ins_log(p_cod_proceso varchar2, p_hor_ini varchar2, p_hor_fin varchar2)
 is pragma autonomous_transaction;
  begin
    insert into ge_log_procesos(fecha,cod_programa,cod_proceso,observacion,hor_inicio,hor_fin)
    values(v_fecha,'PRK_GEN_RET_VIRTUAL',p_cod_proceso, v_obs, p_hor_ini, p_hor_fin);
    commit;
  exception
    when others then null;
  end; 
Begin
  --Obtiene el porcentaje de Retenciones una sola vez.
  v_por_retencion := fug_obt_pardinamico('POR_RET_PROVEEDOR');
  v_hor_ini := to_char(sysdate,'hh24:mi:ss');
  --Inicializa el objeto Principal del tipo lista.
  ret_vir_lista := typ_jsonlist();
  For ret in retenciones Loop
      v_genera_dat := 'S';  --Si existen datos a generar.
      --Inicializa el objeto del tipo lista del bloque detalle.
      ret_vir_det_lista := typ_jsonlist();
      For det in detalle(ret.cod_compra) Loop
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
        ret_transaccion.put('numeroComprobanteVenta', det.numeroComprobanteVenta);
        ret_transaccion.put('condicionCompra', det.condicionCompra);
        If det.condicioncompra = 'CREDITO' then
           ret_transaccion.put('cuotas', ret.cuotas);
        End If;
        ret_transaccion.put('tipoComprobante', det.tipoComprobante);
        ret_transaccion.put('fecha', det.fecha);
        if ret.situacion = 'contribuyente' then
            ret_transaccion.put('numeroTimbrado', det.numeroTimbrado);
        else
            ret_transaccion.put('numeroTimbrado', '0');
        end if;

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
      ret_informado.put('tipoIdentificacion', v_tip_identificacion);
      ret_informado.put('identificacion', ret.identificacion);
      ret_informado.put('direccion', ret.direccion);
      ret_informado.put('correoElectronico', ret.correoelectronico);
      ret_informado.put('pais', ret.pais);
      ret_informado.put('telefono', ret.telefono);
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

      v_nro_doc_informado := ret.ruc;
      v_tip_doc_informado := 'RUC';
    BEGIN
      update ge_ret_proveedores
         set est_ret_virtual ='G',
             fec_ret_virtual =  to_date(v_fec_pago,'dd/mm/yyyy')
       where cod_proveedor = ret.cod_proveedor
         and nro_factura = ret.numeroComprobanteVenta
         and fec_pago = to_date(ret.fec_pago,'dd/mm/yyyy');
    EXCEPTION
      when others then
       RAISE_APPLICATION_ERROR(-20001, 'ERROR. al act. factura '||ret.numeroComprobanteVenta ||sqlerrm);
    END;
    End Loop;

 If v_genera_dat = 'S' then -- Solo si genera datos debe generar el archivo y enviar.
    -- Convierte a CLOB para generar el archivo.
    v_arc_resultado := empty_clob();
    dbms_lob.createtemporary(v_arc_resultado, true);
    ret_vir_lista.to_clob(v_arc_resultado, true);
    --Genera Nombre del Archivo
     v_nom_archivo := 'retenciones_'||v_fec_nro||'.txt';
    -- Genera el archivo
    v_clob_tam := DBMS_LOB.GETLENGTH(v_arc_resultado);
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
    v_respuesta := pa_file_ftp.fu_put_ascii(v_ip,
                                            v_port,
                                            v_user,
                                            v_pass,
                                            v_directorio,
                                            v_nom_archivo,
                                            v_dir_carpeta || v_nom_archivo);
    v_hfin_ftp  := to_char(sysdate, 'hh24:mi:ss');
    If v_respuesta <> 'OK' Then
      -- ERROR AL ENVIAR ARCHIVO POR FTP
      -- Insertamos el error del envio al directorio compartido
      INSERT INTO ge_ra_log_ftp
        (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
      VALUES
        (SYSDATE,
         v_nom_archivo,
         v_respuesta,
         v_hini_ftp,
         v_hfin_ftp);
      COMMIT;      
    End If;    
  End IF;  
 exception
  when others then
       v_hor_fin := to_char(sysdate,'hh24:mi:ss'); 
       v_obs :=substr(trim(SQLERRM || ' ' ||'-'||' '||v_respuesta),1,400);     
       lp_ins_log('PRK_GEN_RET_VIRTUAL',v_hor_ini,v_hor_fin);
       IF SQLERRM < -20001 then
          raise_application_error(-20001, 'PRK_GEN_RET_VIRTUAL: '||sqlerrm);
       ELSE
         raise;
       END IF;
End;
/
