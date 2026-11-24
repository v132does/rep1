create or replace function it.FUJ_VAL_TRANSACCION_210(
      p_nro_operacion in varchar2,   -- Nro de referencia de la operacion
      p_nro_caja in varchar2,        -- Nro de Caja
      p_nro_boleta in varchar2 default null)
return VARCHAR2 is
  -- defino por defecto el modulo y modalidad a utilizar
  v_cod_modulo number(3) := 9;               -- Caja
  v_cod_modalidad number(3) := 91;           -- Caja
  v_cod_transaccion number(3) := 205;        -- Transaccion
  --
  v_cod_oficina number(3);                   -- oficina de la caja
  v_cod_usuario varchar2(10) := upper(user); -- usuario
  --
  v_estado            number(1);             -- estado de la caja
  v_fec_caja          date;                  -- fecha de la caja
  v_sal_actual        number(18,2);          -- saldo actual de la caja en efectivo
  v_sal_cheques        number(18,2);          -- saldo actual de la caja en cheques
  --
  v_msj_salida    varchar2(8000);            -- mensaje final retornado
  v_cod_respuesta varchar2(03) := '000';     -- sin errores
  v_msj_respuesta varchar2(100) := 'OK';     -- MENSAJE sin errores
  -- detalle de campos. Por defecto van los campos en blanco
  v_can_campos    number(3) := 2;        -- cantidad de campos
  v_det_campos    varchar2(8000) :=       -- valor por defecto
              '[' || 'MONTO'    ||'~ ]';
  v_fec_actual date := pag_cal.FU_OBT_FEC_ACTUAL(9);
  v_descripcion cj_cajas.descripcion%type;
  v_cod_moneda    varchar2(3);
  v_cod_ofi_destino number(3);
  v_monto         number(18,2);
begin
 -- Valido la moneda
 if p_nro_boleta is null then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el Nro. de Boleta.';
 end if;

 if v_cod_respuesta = '000' then
    --Traigo los datos de los Valores--
    begin
      select cod_moneda, cod_ofi_destino, monto, o.descripcion
        into v_cod_moneda, v_cod_ofi_destino, v_monto, v_descripcion
        from cj_val_transito a, 
             ba_usuarios b, 
             ba_usuarios c,
             ba_oficinas o
       where b.cod_usuario = a.usu_insercion 
         and c.cod_oficina = a.cod_ofi_destino 
         and a.nro_documento = to_number(p_nro_boleta)
         and o.cod_oficina = a.cod_ofi_destino
         and a.estado = 'E' 
         and c.cod_usuario = user;
        
      if v_cod_respuesta = '000' then -- sino hubo problemas se arma los datos de la cuenta
        v_det_campos := '[' || 'COD_MONEDA' ||'~'||v_cod_moneda|| ']' ||
                        '[' || 'COD_OFI_DESTINO' ||'~'||to_char(v_cod_ofi_destino)|| ']'||
                        '[' || 'DES_OFI_DESTINO' ||'~'||v_descripcion|| ']'||
                        '[' || 'MONTO' ||'~'||ltrim(to_char(v_monto))|| ']';
      end if;
    exception
        when no_data_found then
          v_cod_respuesta := '002';
          v_msj_respuesta := 'ERROR: Nro.de Documento no Existe!';
        when others then
          v_cod_respuesta := '003';
          v_msj_respuesta := sqlerrm;
    end;
 end if;

 if v_cod_respuesta = '000' then -- no hubo errores
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
    elsif v_estado NOT in (1,3,4) then  -- error, la caja ya esta abierta
       v_cod_respuesta := '003'; -- error
       v_msj_respuesta := 'Caja no puede realizar Recepcion de Valores en Transito no se halla abierta';
    elsif v_estado = 2 then -- caja cerrada
       v_det_campos := '[' || 'MONTO'    ||'~'||ltrim(to_char(v_sal_actual))|| ']';
    end if;
 end if;

 /* armo finalmente el mensaje de respuesta */
  v_msj_salida := p_nro_operacion||'~'||
                  v_cod_respuesta||'~'||
                  v_msj_respuesta||'~'||
                  ltrim(to_char(v_can_campos,'000'))||'~'||
                  v_det_campos;

  return(v_msj_salida);
exception
 when others then
     /* si hubo problemas, armo finalmente el mensaje de respuesta */
     v_msj_salida := p_nro_operacion||'~'||
                     '999'||'~'||
                     sqlerrm||'~'||
                     ltrim(to_char(v_can_campos,'000'))||'~'||
                     v_det_campos;
     return(v_msj_salida);
end FUJ_VAL_TRANSACCION_210;
/

