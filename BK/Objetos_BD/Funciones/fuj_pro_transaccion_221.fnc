create or replace function it.FUJ_PRO_TRANSACCION_221(
      p_nro_operacion in varchar2,   -- Nro de referencia de la operacion
      p_nro_caja in varchar2,        -- Nro de Caja
      p_tip_busqueda in varchar2,
      p_dat_busqueda in varchar2,
      p_nro_referencia in varchar2 default null,
      p_cod_moneda     in varchar2 default null,
      p_nro_documento  in varchar2 default null)
return LONG is
  -- Datos de la transaccion
  v_cod_modulo number(3)      := 9;      -- Caja
  v_cod_modalidad number(3)   := 91;     -- Caja
  v_cod_transaccion number(4) := 221;    -- transaccion
  v_cod_usuario varchar2(10) := upper(user); --usuario
  v_cod_moneda  varchar2(4);
  v_cot_compra  ge_cotizaciones.val_conversion%type;
  v_cot_venta   ge_cotizaciones.val_conversion%type;
  v_monto       number(18,2);
  v_mto_equ_local number(18,2);

  -- Datos de la caja
  v_fec_actual        date := pag_cal.fu_obt_fec_actual(v_cod_modulo); -- fecha de hoy
  v_cod_oficina       number(3);         -- Codigo de oficina
  v_estado            number(1);         -- estado de la caja
  v_fec_caja          date;              -- fecha de la caja
  v_sal_actual        number(18,2);      -- saldo actual de la caja en efectivo
  v_sal_cheques       number(18,2);     -- saldo actual de la caja en cheques
  -- Datos de salida
  v_msj_salida        long;        -- mensaje final retornado
  v_cod_respuesta     varchar2(03) := '000'; -- sin errores
  v_msj_respuesta     long := 'OK'; -- sin errores
  -- Datos de campos a devolver
  v_can_campos        number(3) := 4;        -- cantidad de campos
  v_det_campos        long ;      -- valores devueltos por defecto
                     
  --Datos anexos
  v_val_posibles     varchar2(4000);
  v_det_libranzas    long;
  v_cod_tra_cargo1   number(6);
  v_mon_local        varchar2(5) := pag_gen.fu_obt_mon_local;
  v_mad_operacion    number(5);
  v_tip_ope_cpra     number(5);
  v_tip_ope_vta      number(5);
  v_mto_cargo1       number(18,2);  
  v_mto_venta        number(18,2);
  v_can1             number(18);
  v_nro_referencia   varchar2(20);
  v_hora             ge_movimientos.hora%type := to_char(sysdate,'hh24:mi:ss');
  v_nro_operacion    number;
  v_cod_mad_padre    ge_modalidades.cod_modalidad%TYPE;
--
begin
  if p_nro_referencia is null then
     v_cod_respuesta := '001'; -- error
     v_msj_respuesta := 'ERROR: Ingrese la Referencia a pagar.';
  elsif p_cod_moneda is null then
     v_cod_respuesta := '002'; -- error
     v_msj_respuesta := 'ERROR: Ingrese la Moneda.';
  else
     if p_nro_documento is null then
       v_cod_respuesta := '003';
       v_msj_respuesta := 'ERROR: Ingrese la C.I. del Beneficiario';
     end if;
  end if;

  if v_cod_respuesta = '000' then
     --validar los datos ingresados
     v_msj_salida:= FUJ_VAL_TRANSACCION_221(p_nro_operacion, p_nro_caja, p_tip_busqueda,
                         p_dat_busqueda, p_nro_referencia, p_cod_moneda, p_nro_documento);
                        
     if v_msj_salida NOT LIKE '%~OK~%' THEN
        return v_msj_salida;
     END IF;
  end if;

  if v_cod_respuesta = '000' then -- sino hubo problemas, veo la caja
     -- Obtengo los datos de la caja ---------------------------------------
     prj_obt_datos_caja(p_nro_caja,
                        p_cod_moneda,
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
        v_msj_respuesta := 'Caja no fue habilitada el día de hoy';                
     end if;
  end if; 

  if v_cod_respuesta = '000' then -- sino hubo problemas, realizar el pago
     prl_con_transferencia(p_nro_referencia, v_cod_oficina, v_hora, p_cod_moneda, p_nro_caja, 'E', p_nro_documento, v_nro_operacion,v_cod_mad_padre);
  end if;
  if v_cod_respuesta = '000' then
    v_cod_respuesta := 'IMP';
    v_msj_respuesta := 'Operación Confirmada. Comprobante impreso.'||'~'||
                       fuj_imp_comprobante_221(v_nro_operacion, v_cod_oficina, p_nro_caja,v_cod_mad_padre);
  end if;
  v_msj_salida := p_nro_operacion||'~'||
                  v_cod_respuesta||'~'||
                  nvl(v_msj_respuesta,'OK');
  return(v_msj_salida);
exception
    when others then
       v_cod_respuesta := '999';
       v_msj_salida := p_nro_operacion||'~'||
                 v_cod_respuesta||'~'||
                 /*'!'||*/SQLERRM;
    return(v_msj_salida);  
end FUJ_PRO_TRANSACCION_221;
/

