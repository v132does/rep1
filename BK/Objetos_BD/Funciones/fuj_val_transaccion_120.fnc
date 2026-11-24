create or replace function it.FUJ_VAL_TRANSACCION_120(
      p_nro_operacion   in varchar2,   -- Nro de referencia de la operacion
      p_nro_caja        in varchar2,        -- Nro de Caja
      p_cod_tra_padre   in varchar2, -- Codigo de transaccion
      p_hora            in varchar2 default null) -- hora de la transaccion a reimprimir
return VARCHAR2 is
  -- defino por defecto el modulo y modalidad a utilizar
  v_cod_modulo number(3) := 9;        -- Caja
  v_cod_modalidad number(3) := 91;    -- Caja
  v_cod_transaccion number(4) := 120; -- cod de transaccion
  v_cod_usuario varchar2(10) := upper(user); --usuario
  --
  v_cod_oficina number(3);                   -- oficina de la caja

  v_estado            number(1);             -- estado de la caja
  v_fec_caja          date;                  -- fecha de la caja
  v_sal_actual        number(18,2);          -- saldo actual de la caja en efectivo
  v_sal_cheques       number(18,2);          -- saldo actual de la caja en cheques
  --
  v_msj_salida    varchar2(8000);        -- mensaje final retornado
  v_cod_respuesta varchar2(03) := '000'; -- sin errores
  v_msj_respuesta varchar2(1000) := 'OK'; -- sin errores
  v_can_campos    number(3) := 0;        -- cantidad de campos
  v_det_campos    varchar2(8000) := null;
  -- Contenedor de la lista de valores a devolver
  v_val_posibles  varchar2(3000) := null;
  -- Datos del movimiento
  --v_nro_documento varchar2(10); *** Modificado por JCLG ***
  v_nro_documento number(15);
  v_nro_cuenta    varchar2(15);
  v_denominacion  varchar2(100);
  v_cod_moneda    varchar2(3);
  v_monto         varchar2(18);
begin
  if p_hora is null then
    -- Obtengo el select de la lista de valores para la Hora
    v_val_posibles  := fuj_obt_val_posibles(v_cod_transaccion,'HORA');
    -- reemplazo el codigo de transaccion en el select
    v_val_posibles := replace(v_val_posibles,'&COD_TRANS',p_cod_tra_padre);
    -- reemplazo el nro de caja en el select
    v_val_posibles := replace(v_val_posibles,'&NRO_CAJA',p_nro_caja);
    /* se devuelve los valores posibles para el codigo de transaccion a imprimir
    Datos a devolver por campo: [Nombre_campo~Valor_defecto~Valores_Posibles] */
    begin
      v_can_campos := 1;
      Select '[' || 'DES_TRA_PADRE' ||'~'||descripcion|| ']'
        into v_det_campos
        from ge_transacciones
       where cod_modulo = v_cod_modulo
         and cod_modalidad = v_cod_modalidad
         and cod_transaccion = to_number(p_cod_tra_padre);

    exception
      when no_data_found then
        v_cod_respuesta := '002';
        v_msj_respuesta := 'No existe Transaccion definida en el Sistema';
        v_det_campos := '[' || 'DES_TRA_PADRE' ||'~'||' '|| ']';
      when others then
        v_cod_respuesta := '003';
        v_msj_respuesta := sqlerrm;
        v_det_campos := '[' || 'DES_TRA_PADRE' ||'~'||' '|| ']';
    end;
    if v_cod_respuesta = '000' then
      v_det_campos := v_det_campos ||
                      '[' ||
                      'HORA~X~'||
                      fuj_pro_val_posibles(v_val_posibles) ||
                      ']';
      v_can_campos := v_can_campos + 1;
    end if;
  else
    -- obtengo datos de la operacion ------------------------------------
    begin
      v_can_campos := 5;
      select b.nro_documento, b.nro_cuenta, a.denominacion, b.cod_moneda,
             b.monto
        into v_nro_documento, v_nro_cuenta, v_denominacion, v_cod_moneda,
             v_monto
        from ge_cuentas a, cj_movimientos b
       where a.nro_cuenta(+) = b.nro_cuenta
         and b.nro_caja = to_number(p_nro_caja)
         and b.hora = p_hora
         and b.cod_tra_padre = to_number(p_cod_tra_padre)
         and b.estado = 'N' -- normal
         and b.nro_secuencia = 1
         and b.cod_usuario = v_cod_usuario
         and exists (select 0
                         from ge_movimientos
                         where hora = b.hora
                         and cod_usuario = b.cod_usuario
                         and emi_aviso ='S') --comprobante manual
         and exists(select 0
                    from ge_aut_pedidos
                    where fecha =b.fecha
                    and hora = b.hora
                    and cod_usuario = b.cod_usuario
                    and respuesta ='A');
      -- Obtengo los datos de la caja ---------------------------------------
      prj_obt_datos_caja(p_nro_caja,
                         v_cod_moneda,
                         v_cod_oficina,
                         v_fec_caja,
                         v_estado,
                         v_sal_actual,
                         v_sal_cheques);
      if v_estado in (0,2) then  -- error, la caja no esta abierta
         v_cod_respuesta := '003'; -- error
         v_msj_respuesta := 'Caja aun no fue abierta en esta Moneda';
      elsif v_estado in (1,3,4) then -- caja
         v_det_campos := '[' || 'NRO_DOCUMENTO' ||'~'||to_char(v_nro_documento)|| ']' ||
                         '[' || 'NRO_CUENTA' ||'~'||v_nro_cuenta|| ']' ||
                         '[' || 'DES_CUENTA' ||'~'||v_denominacion|| ']' ||
                         '[' || 'COD_MONEDA' ||'~'||v_cod_moneda|| ']' ||
                         '[' || 'MONTO' ||'~'||v_monto|| ']';
      end if;
    exception
      when no_data_found then
        v_cod_respuesta := '002';
        v_msj_respuesta := 'No existe movimiento registrado en esta Caja';
        v_det_campos := '[' || 'NRO_DOCUMENTO' ||'~ ]'||
                        '[' || 'NRO_CUENTA' ||'~ ]' ||
                        '[' || 'DES_CUENTA' ||'~ ]' ||
                        '[' || 'COD_MONEDA' ||'~ ]' ||
                        '[' || 'MONTO' ||'~ ]';
      when others then
        v_cod_respuesta := '003';
        v_msj_respuesta := sqlerrm;
        v_det_campos := '[' || 'NRO_DOCUMENTO' ||'~ ]'||
                        '[' || 'NRO_CUENTA' ||'~ ]' ||
                        '[' || 'DES_CUENTA' ||'~ ]' ||
                        '[' || 'COD_MONEDA' ||'~ ]' ||
                        '[' || 'MONTO' ||'~ ]';
    end;

  end if;
 /* falta armar el mensaje de respuesta */
  v_msj_salida := p_nro_operacion||'~'||
                  v_cod_respuesta||'~'||
                  v_msj_respuesta||'~'||
                  ltrim(to_char(v_can_campos,'000'))||'~'||
                  v_det_campos;
  return(v_msj_salida);
end FUJ_VAL_TRANSACCION_120;
/

