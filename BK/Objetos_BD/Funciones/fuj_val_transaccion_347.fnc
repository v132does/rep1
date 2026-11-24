create or replace function it.FUJ_VAL_TRANSACCION_347(
      p_nro_operacion in varchar2,   -- Nro de referencia de la operacion
      p_nro_caja in varchar2,        -- Nro de Caja
      p_cod_ente in number,
      --p_nro_documento in varchar2 default null,
      p_orden in number default null) -- Nro de Cedula
return VARCHAR2 is
  -- defino por defecto el modulo y modalidad a utilizar
  v_cod_modulo number(3)      := 9;    -- Caja
  v_cod_modalidad number(3)   := 91;   -- Caja
  v_cod_transaccion number(4) := 347;  -- transaccion
  v_cod_usuario varchar2(10) := upper(user); --usuario
  -- Datos de la caja
  v_fec_actual        date := pag_cal.fu_obt_fec_actual(v_cod_modulo); -- fecha de hoy
  v_hor_actual        varchar2(08) := to_char(sysdate,'HH24:MI:SS');   -- Hora actual
  v_cod_oficina       number(3);         -- Codigo de oficina
  v_estado            number(1);         -- estado de la caja
  v_fec_caja          date;              -- fecha de la caja
  v_sal_actual        number(18,2);      -- saldo actual de la caja en efectivo
  v_sal_cheques       number(18,2);      -- saldo actual de la caja en cheques
  -- Datos de salida
  v_msj_salida    varchar2(20000);        -- mensaje final retornado
  v_cod_respuesta varchar2(03) := '000'; -- sin errores
  v_msj_respuesta varchar2(1000) := 'Operacion Confirmada'; -- sin errores
  -- datos de la operacion convertidos
  v_tipo          varchar2(01) := 'D';  -- Debito para la caja (ingreso)
  v_tip_monto     varchar2(01) := 'O';  -- Cheq. Otros Bancos
  v_nro_secuencia number(3) := 0;  -- secuencia del mov.
  -- datos de la lista
  v_can_campos    number(3) := 1;        -- cantidad de campos
  v_det_campos    varchar2(20000) := null;
  v_val_posibles  varchar2(20000) := null;
  -- datos del pago
  v_fec_pago      varchar2(10); -- fecha de pago
  v_mto_pago      number;       -- monto del pago
  v_fec_ingreso   varchar2(10); -- fecha de ingreso
  v_des_proveedor varchar2(300); -- descripción del proveedor
  v_cod_moneda    varchar2(3);  -- codigo de la moneda
  v_nro_factura   varchar2(20); -- nro. de la factura
  v_concepto      varchar2(300);
  v_nro_doc_beneficiario varchar2(20); -- nro. de documento Beneficiario
begin
 -- Inicializacion de la aplicacion y el modulo
 BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=v_cod_modulo; END;
 -- Valido el ente
 if p_cod_ente is null then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el Codigo del Ente Pagador.'; 
/*elsif p_nro_documento is null then
    begin
       select fuj_des_campo('DES_ENTE',descripcion)
         into v_det_campos
         from ge_entes
        where cod_ente = p_cod_ente;
    exception
       when no_data_found then
         v_cod_respuesta := '011'; -- error
         v_msj_respuesta := 'ERROR: Ente Pagador no existe';          
    end; 
    -- Obtengo el select de la lista de valores para el documento
        -- Obtengo el select de la lista de valores para el documento
        v_val_posibles  := replace(fuj_obt_val_posibles(v_cod_transaccion,'NRO_DOC_BENEFICIARIO'),'&COD_ENTE',p_cod_ente);
        -- cargo la lista de valores
        v_val_posibles := fuj_pro_val_posibles(v_val_posibles);
        --
        v_det_campos := v_det_campos||fuj_des_campo('NRO_DOC_BENEFICIARIO',null,v_val_posibles); */    
 elsif p_orden is null then
    begin
       select fuj_des_campo('DES_ENTE',descripcion)
         into v_det_campos
         from ge_entes
        where cod_ente = p_cod_ente;
    exception
       when no_data_found then
         v_cod_respuesta := '011'; -- error
         v_msj_respuesta := 'ERROR: Ente Pagador no existe';          
    end; 
        
    if v_cod_respuesta = '000' THEN       
        -- Obtengo el select de la lista de valores para el documento
        v_val_posibles  := replace(fuj_obt_val_posibles(v_cod_transaccion,'NRO_ORDEN'),'&COD_ENTE',p_cod_ente);
        --v_val_posibles  := replace(v_val_posibles,'&NRO_COD_BENEFICIARIO',p_nro_documento);        
        -- cargo la lista de valores
        v_val_posibles := fuj_pro_val_posibles(v_val_posibles);
        --
        v_det_campos := v_det_campos||fuj_des_campo('NRO_ORDEN',null,v_val_posibles); 
    end if;
 else
    begin
       SELECT to_char(fec_pago,'dd/mm/yyyy'), monto, cod_moneda, nro_doc_beneficiario,
              to_char(fec_ingreso,'dd/mm/yyyy'), replace(substr(beneficiario,1,35),chr(39),' '), nro_factura, concepto
       INTO   v_fec_pago, v_mto_pago, v_cod_moneda, v_nro_doc_beneficiario,
              v_fec_ingreso, v_des_proveedor, v_nro_factura, v_concepto
       FROM   ge_pag_proveedores
       WHERE  estado IN ('C','R')
       AND    for_pago = 'E'
       AND    nro_orden = p_orden
       and    cod_ente  = p_cod_ente
       AND  ((fug_obt_parentes(p_cod_ente, 'PAG_FAC_ATRASADA') ='S' AND trunc(nvl(fec_pago,sysdate)) <= trunc(sysdate)) OR
             (fug_obt_parentes(p_cod_ente, 'PAG_FAC_ATRASADA') ='N' AND trunc(nvl(fec_pago,sysdate)) = trunc(sysdate)))
	   AND FUG_OBT_OFI_USUARIO(COD_USU_OPERADOR) = FUG_OBT_OFI_USUARIO(USER)
       AND FUE_OBT_PER_ENTE(P_COD_ENTE) not in (select cod_persona 
                                               from ge_par_generales);
    exception
       when no_data_found then
          v_cod_respuesta := '002'; -- error
          v_msj_respuesta := 'ERROR: No se encontraron datos para el pago.';
       when others then
          v_cod_respuesta := '003'; -- error
          v_msj_respuesta := 'ERROR: '|| sqlerrm;
    end;
    if v_cod_respuesta = '000' THEN
      if v_mto_pago is not null then
         v_cod_respuesta := '000';
         -- Valido la moneda ingresada
         prj_val_moneda(v_cod_moneda, v_cod_respuesta,v_msj_respuesta);
      else
         v_cod_respuesta := '004'; -- error
         v_msj_respuesta := 'ERROR: Sin monto para el pago.';
      end if;
    end if;
 end if;
 if v_cod_respuesta = '000' and p_orden is not null then -- sin errores
       -- Obtengo los datos de la caja ---------------------------------------
       prj_obt_datos_caja(p_nro_caja,
                          v_cod_moneda,
                          v_cod_oficina,
                          v_fec_caja,
                          v_estado,
                          v_sal_actual,
                          v_sal_cheques);
       if v_estado = -1 then
          v_cod_respuesta := '006'; -- error, no existe registro de caja
          v_msj_respuesta := 'Caja inexistente!!';
       elsif v_estado in (0,2) then
          v_cod_respuesta := '004'; -- error
          v_msj_respuesta := 'Realice la Apertura de Caja previamente';
       elsif v_fec_caja <> v_fec_actual then
          v_cod_respuesta := '005'; -- error
          v_msj_respuesta := 'Caja no fue habilitada el dia de hoy';
       end if;
    if v_cod_respuesta = '000' then
       v_msj_respuesta := fuj_val_importe(v_tipo, 'E',v_cod_moneda,v_mto_pago);
       if v_msj_respuesta is not null then
          v_cod_respuesta := '005';  -- error
       end if;
    end if;
 end if;
 -- mensaje final sino hubo errores
 if v_cod_respuesta = '000' and p_orden is not null then -- sino hubo problemas, se carga mensaje por defecto
   v_msj_respuesta := 'Ok';
   v_det_campos := fuj_des_campo('FEC_PAGO',v_fec_pago,NULL,'D') ||
                   fuj_des_campo('COD_MONEDA',v_cod_moneda,NULL,'D') ||
                   fuj_des_campo('MONTO',v_mto_pago,NULL,'D') ||
                   fuj_des_campo('FEC_INGRESO',v_fec_ingreso,NULL,'D') ||
                   fuj_des_campo('NRO_FACTURA',v_nro_factura,NULL,'D') ||
                   fuj_des_campo('NRO_DOC_BENEFICIARIO',v_nro_doc_beneficiario)||
                   fuj_des_campo('BENEFICIARIO',v_des_proveedor,NULL,'D')||
                   fuj_des_campo('CONCEPTO',v_concepto) ;
 end if;
 /* falta armar el mensaje de respuesta */
v_msj_salida := p_nro_operacion||'~'||
                v_cod_respuesta||'~'||
                nvl(v_msj_respuesta,'OK')||'~'||
                ltrim(to_char(v_can_campos,'000'))||'~'||
                v_det_campos;
 return(v_msj_salida);
end FUJ_VAL_TRANSACCION_347;
/

