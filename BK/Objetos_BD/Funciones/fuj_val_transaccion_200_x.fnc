create or replace function it.FUJ_VAL_TRANSACCION_200_X(
      p_nro_operacion   in varchar2,   -- Nro de referencia de la operacion
      p_nro_caja        in varchar2,        -- Nro de Caja
      p_cod_usuario     in varchar2,
      p_cod_tra_padre   in varchar2 default null, -- Codigo de transaccion
      p_nro_documento   in varchar2 default null, -- Nro de boleta.
      p_hora            in varchar2 default null) -- hora de la transaccion a reversar


return VARCHAR2 is
  -- defino por defecto el modulo y modalidad a utilizar
  v_cod_modulo number(3) := 9;        -- Caja
  v_cod_modalidad number(3) := 91;    -- Caja
  v_cod_transaccion number(4) := 200; -- cod de transaccion
  v_cod_usuario varchar2(10) := upper(user); --usuario
  --
  v_cod_oficina number(3);                   -- oficina de la caja

  --Comentado por JCLG porque fue declarado y no utilizado
  --v_fec_actual        date := pag_cal.fu_obt_fec_actual(v_cod_modulo); -- fecha de hoy
  --v_hor_actual        varchar2(08) := to_char(sysdate,'HH24:MI:SS');   -- Hora actual

  v_estado            number(1);             -- estado de la caja
  v_fec_caja          date;                  -- fecha de la caja
  v_sal_actual        number(18,2);          -- saldo actual de la caja en efectivo
  v_sal_cheques       number(18,2);          -- saldo actual de la caja en cheques
  v_nro_caja          cj_cajas.nro_caja%type;
  --
  v_msj_salida    varchar2(8000);        -- mensaje final retornado
  v_cod_respuesta varchar2(03) := '000'; -- sin errores
  v_msj_respuesta varchar2(4000) := 'OK'; -- sin errores
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
  v_hora          ge_movimientos.hora%type;
begin
  if p_cod_usuario is not null then
    begin
      select nro_caja into v_nro_caja
        from cj_cajas
       where cod_usuario = p_cod_usuario
       and estado = 'A';
    exception
       when no_data_found then
        v_cod_respuesta := '001';
        v_msj_respuesta := 'No existe el Usuario de caja';
        v_det_campos := '[' || 'COD_USUARIO' ||'~'||' '|| ']';
    end;
  end if;
  if p_cod_tra_padre is null then
    -- Obtengo el select de la lista de valores para la transaccion
    v_val_posibles  := fuj_obt_val_posibles(v_cod_transaccion,'COD_TRA_PADRE');
    -- reemplazo el codigo de usuario en el select
    v_val_posibles := replace(v_val_posibles,'&COD_USUARIO',p_cod_usuario);
    /* se devuelve los valores posibles para el codigo de transaccion a reversar
    Datos a devolver por campo: [Nombre_campo~Valor_defecto~Valores_Posibles]
    */
    v_det_campos := v_det_campos ||
                     '[' ||
                      'COD_TRA_PADRE~X~'||
                      fuj_pro_val_posibles(v_val_posibles) ||
                      ']';
  elsif p_nro_documento is null /*and p_hora is null*/ then
    -- Obtengo el select de la lista de valores para el documento
    v_val_posibles  := fuj_obt_val_posibles(v_cod_transaccion,'NRO_DOCUMENTO');
    -- reemplazo el codigo de transaccion en el select
    v_val_posibles := replace(v_val_posibles,'&COD_TRANS',p_cod_tra_padre);
    -- reemplazo el nro de caja en el select
    v_val_posibles := replace(v_val_posibles,'&NRO_CAJA',v_nro_caja);
    /* se devuelve los valores posibles para el codigo de transaccion a reversar
    Datos a devolver por campo: [Nombre_campo~Valor_defecto~Valores_Posibles]
    */
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
                      'NRO_DOCUMENTO~X~'||
                      fuj_pro_val_posibles(v_val_posibles) ||
                      ']';
      v_can_campos := v_can_campos + 1;
      -- Obtengo el select de la lista de valores para el documento
      v_val_posibles  := fuj_obt_val_posibles(v_cod_transaccion,'HORA');
      -- reemplazo el codigo de transaccion en el select
      v_val_posibles := replace(v_val_posibles,'&COD_TRANS',p_cod_tra_padre);
      -- reemplazo el nro de caja en el select
      v_val_posibles := replace(v_val_posibles,'&NRO_CAJA',v_nro_caja);
      v_val_posibles := replace(v_val_posibles,'&NRO_DOCUMENTO',p_nro_documento);

      v_det_campos := v_det_campos ||
                      '[' ||
                      'HORA~X~'||
                      fuj_pro_val_posibles(v_val_posibles) ||
                      ']';
      v_can_campos := v_can_campos + 1;
    end if;

  elsif p_nro_documento is not null and p_hora is null then
      select max(hora)
        into v_hora
        from ge_cuentas a, cj_movimientos b, cj_cajas c
       where a.nro_cuenta(+) = b.nro_cuenta
         and b.nro_caja = c.nro_caja
         and c.cod_usuario = p_cod_usuario
--         and b.nro_caja = to_number(p_nro_caja)
         and b.cod_tra_padre = to_number(p_cod_tra_padre)
         and b.nro_documento = p_nro_documento
         and b.estado = 'N' -- normal
         -- and b.nro_secuencia = 1
         -- and b.cod_usuario = v_cod_usuario --cualquier usuario
         and ((b.cod_tra_padre <> 250) or
              (b.cod_tra_padre  = 250 and exists (select 1
                                                    from ta_cobros x
                                                    where x.fec_proceso = b.fecha
                                                      and x.cod_usuario = b.cod_usuario
                                                      and x.hora = b.hora
                                                      and x.nro_cuenta = b.nro_cuenta
                                                      and x.estado in ('P','C')
                                                      and x.est_envio = 'P')));
    -- Obtengo el select de la lista de valores para el documento
    v_val_posibles  := fuj_obt_val_posibles(v_cod_transaccion,'HORA');
    -- reemplazo el codigo de transaccion en el select
    v_val_posibles := replace(v_val_posibles,'&COD_TRANS',p_cod_tra_padre);
    -- reemplazo el nro de caja en el select
    v_val_posibles := replace(v_val_posibles,'&NRO_CAJA',v_nro_caja);
    v_val_posibles := replace(v_val_posibles,'&NRO_DOCUMENTO',p_nro_documento);
    if v_cod_respuesta = '000' then
      v_det_campos := v_det_campos ||
                      '[' ||
                      'HORA~'||nvl(v_hora,'X')||'~'||
                      fuj_pro_val_posibles(v_val_posibles) ||
                      ']';
      v_can_campos := v_can_campos + 1;
    end if;

  elsif p_hora is null then
    -- Obtengo el select de la lista de valores para la Hora
    v_val_posibles  := fuj_obt_val_posibles(v_cod_transaccion,'HORA');
    -- reemplazo el codigo de transaccion en el select
    v_val_posibles := replace(v_val_posibles,'&COD_TRANS',p_cod_tra_padre);
    -- reemplazo el nro de caja en el select
    v_val_posibles := replace(v_val_posibles,'&NRO_CAJA',v_nro_caja);
    /* se devuelve los valores posibles para el codigo de transaccion a reversar
    Datos a devolver por campo: [Nombre_campo~Valor_defecto~Valores_Posibles]
    */
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
             sum(b.monto)
        into v_nro_documento, v_nro_cuenta, v_denominacion, v_cod_moneda,
             v_monto
        from ge_cuentas a, cj_movimientos b, cj_cajas c
       where a.nro_cuenta(+) = b.nro_cuenta
         and b.nro_caja = c.nro_caja
         and c.cod_usuario = p_cod_usuario
--         and b.nro_caja = to_number(p_nro_caja)
         and b.hora = p_hora
         and b.cod_tra_padre = to_number(p_cod_tra_padre)
         and b.estado = 'N' -- normal
         -- and b.nro_secuencia = 1
         -- and b.cod_usuario = v_cod_usuario
         and ((b.cod_tra_padre <> 250) or
              (b.cod_tra_padre  = 250 and exists (select 1
                                                    from ta_cobros x
                                                    where x.fec_proceso = b.fecha
                                                      and x.cod_usuario = b.cod_usuario
                                                      and x.hora = b.hora
                                                      and x.nro_cuenta = b.nro_cuenta
                                                      and x.estado in ('P','C')
                                                      and x.est_envio = 'P')))
          and rownum <=1
        group by b.nro_documento, b.nro_cuenta, a.denominacion, b.cod_moneda, b.nro_secuencia
        order by b.nro_secuencia;
      -- Obtengo los datos de la caja ---------------------------------------
      prj_obt_datos_caja(v_nro_caja,
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
end FUJ_VAL_TRANSACCION_200_X;
/

