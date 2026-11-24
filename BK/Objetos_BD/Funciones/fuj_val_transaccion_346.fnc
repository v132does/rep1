CREATE OR REPLACE FUNCTION IT."FUJ_VAL_TRANSACCION_346" (
      p_nro_operacion in varchar2,   -- Nro de referencia de la operacion
      p_nro_caja      in varchar2,   -- Nro de Caja
      p_cod_ente      in varchar2,   -- Codigo de Ente
      p_orden         in varchar2)
return VARCHAR2 is
  -- defino por defecto el modulo y modalidad a utilizar
  v_cod_modulo number(3)      := 9;    -- Caja
  v_cod_modalidad number(3)   := 91;   -- Caja
  v_cod_transaccion number(4) := 346;  -- transaccion
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
  v_msj_salida    varchar2(8000);        -- mensaje final retornado
  v_cod_respuesta varchar2(03) := '000'; -- sin errores
  v_msj_respuesta varchar2(1000) := 'Operacion Confirmada'; -- sin errores
  -- datos de la operacion convertidos
  v_tipo          varchar2(01) := 'D';  -- Debito para la caja (ingreso)
  v_tip_monto     varchar2(01) := 'O';  -- Cheq. Otros Bancos
  v_nro_secuencia number(3) := 0;  -- secuencia del mov.
  -- datos de la lista
  v_can_campos    number(3) := 1;        -- cantidad de campos
  v_det_campos    varchar2(8000) := null;
  v_val_posibles  varchar2(3000) := null;
  -- datos del pago
  v_fec_pago      varchar2(10); -- fecha de pago
  v_mto_pago      number;       -- monto del pago
  v_fec_ingreso   varchar2(10); -- fecha de ingreso
  v_des_proveedor varchar2(35); -- descripcion del proveedor
  v_cod_moneda    varchar2(3);  -- codigo de la moneda
  v_nro_factura   varchar2(20); -- nro. de la factura
  v_concepto      varchar2(300);
  v_des_ente      ge_entes.descripcion%type;
begin
 -- Inicializacion de la aplicacion y el modulo
 BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=v_cod_modulo; END;
 -- Valido la moneda
 if p_orden is null then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el nro. de orden de pago al Proveedor.';
 elsif p_cod_ente is null then
    v_cod_respuesta := '007'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el Codigo del Ente.';
 elsif p_orden is not null and v_mto_pago is null then
    begin
       select to_char(p.fec_pago,'dd/mm/yyyy'), p.monto, p.cod_moneda,
              to_char(p.fec_ingreso,'dd/mm/yyyy'), replace(substr(p.beneficiario,1,35),chr(39),' '), 
              p.nro_factura, p.concepto, e.descripcion
         into v_fec_pago, v_mto_pago, v_cod_moneda,
              v_fec_ingreso, v_des_proveedor, v_nro_factura, v_concepto, v_des_ente
         from ge_pag_proveedores p,
              ge_entes e
        where p.cod_ente = e.cod_ente
          and p.estado in ('C','R')
          and p.for_pago = 'E'
          and p.nro_orden = p_orden
          and p.cod_ente = p_cod_ente
          and fug_obt_parentes(p.cod_ente, 'ORD_PAG_PROVEEDOR') = 'S';
--          and fug_obt_ofi_usuario(p.cod_usu_operador) = fug_obt_ofi_usuario(user);
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
 if v_cod_respuesta = '000' then -- sin errores
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
 if v_cod_respuesta = '000' then -- sino hubo problemas, se carga mensaje por defecto
   v_msj_respuesta := 'Ok';
   v_det_campos := fuj_des_campo('FEC_PAGO',v_fec_pago,NULL,'D') ||
                   fuj_des_campo('COD_MONEDA',v_cod_moneda,NULL,'D') ||
                   fuj_des_campo('MONTO',v_mto_pago,NULL,'D') ||
                   fuj_des_campo('FEC_INGRESO',v_fec_ingreso,NULL,'D') ||
                   fuj_des_campo('NRO_FACTURA',v_nro_factura,NULL,'D') ||
                   fuj_des_campo('BENEFICIARIO',v_des_proveedor,NULL,'D')||
                   fuj_des_campo('CONCEPTO',v_concepto)||
                   fuj_des_campo('DES_ENTE',v_des_ente) ;
 end if;
 /* falta armar el mensaje de respuesta */
 v_msj_salida := p_nro_operacion||'~'||
                v_cod_respuesta||'~'||
                nvl(v_msj_respuesta,'OK')||'~'||
                ltrim(to_char(v_can_campos,'000'))||'~'||
                v_det_campos;
 return(v_msj_salida);
end FUJ_VAL_TRANSACCION_346;
/

