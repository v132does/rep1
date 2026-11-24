create or replace function it.FUJ_VAL_TRANSACCION_204(
      p_nro_operacion in varchar2,   -- Nro de referencia de la operacion
      p_nro_caja in varchar2,        -- Nro de Caja
      p_nro_boleta in varchar2 default null,
      p_cod_moneda in varchar2 default null,      -- Codigo de moneda
      p_nro_caj_destino in varchar2 default null)  --Nro. de Caja Destino--
return VARCHAR2 is
  -- defino por defecto el modulo y modalidad a utilizar
  v_cod_modulo number(3) := 9;               -- Caja
  v_cod_modalidad number(3) := 91;           -- Caja
  v_cod_transaccion number(3) := 204;        -- Transaccion
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
              '[' || 'MTO_TRANSFERENCIA'    ||'~ ]';
  v_fec_actual date := pag_cal.FU_OBT_FEC_ACTUAL(9);
  v_descripcion cj_cajas.descripcion%type;
begin
 -- Valido la moneda
 if p_nro_boleta is not null then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: No debe Ingresar el Nro.de Boleta.';
 elsif p_cod_moneda is null then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese la moneda.';
 else
    prj_val_moneda(p_cod_moneda, v_cod_respuesta,v_msj_respuesta);
 end if;
 --Valido la Caja de Destino--
 if p_nro_caj_destino is null then
    if v_cod_respuesta = '000' then
           v_det_campos := '[' ||
                            'NRO_CAJ_DESTINO~X~'||
                            fuj_pro_val_posibles(replace(fuj_obt_val_posibles(v_cod_transaccion,'NRO_CAJ_DESTINO'),'&COD_MONEDA',p_cod_moneda)) ||
                            ']';
    end if;
 else
    begin
     select substr(f.descripcion||'-'||b.cod_usuario||'-'||e.nombre,1,50)
       into v_descripcion
       from cj_controles a, cj_cajas b, ba_usuarios d, ba_usuarios e, ba_oficinas f
      where a.nro_caja = p_nro_caj_destino
        and a.cod_moneda = p_cod_moneda
        and a.fecha = v_fec_actual
        and a.estado in (1,3)
        and b.nro_caja = a.nro_caja
        --and b.tipo IN ('H','T') anulado solo para pruebas
        --and b.cod_usuario <> user --Marcada p/ que los Tesoreros puedan ver su otra caja--
        and d.cod_usuario = user
        and d.cod_oficina = b.cod_oficina
        and e.cod_usuario = b.cod_usuario
        and f.cod_oficina = b.cod_oficina
      order by a.nro_caja;
    exception
      when no_data_found then
        v_cod_respuesta := '002';
        v_msj_respuesta := 'ERROR: Caja Destino no Existe o No Abierta en la Moneda!';
      when others then
        v_cod_respuesta := '003';
        v_msj_respuesta := sqlerrm;
    end;
    if v_cod_respuesta = '000' then -- sino hubo problemas se arma los datos de la cuenta
       v_det_campos := '[' || 'DES_CAJ_DESTINO' ||'~'||v_descripcion|| ']';
    end if;
    if p_nro_caja = p_nro_caj_destino then
       v_cod_respuesta := '002';
       v_msj_respuesta := 'ERROR: Nro de Caja de Destino no puede ser igual a la de Origen!';
    end if;
    If p_nro_boleta is not null then
       if v_cod_respuesta = '000' then
          -- Verifico la duplicacion del registro
          prj_val_duplicacion(p_nro_caja,
                              v_cod_transaccion,
                              p_cod_moneda,
                              p_nro_boleta,
                              v_cod_respuesta,
                              v_msj_respuesta);
       end if;
    End if;
 end if;

 if v_cod_respuesta = '000' then -- no hubo errores
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
    elsif v_estado NOT in (1,3,4) then  -- error, la caja ya esta abierta
       v_cod_respuesta := '003'; -- error
       v_msj_respuesta := 'Caja no puede realizar Transferencia no se halla abierta';
    elsif v_estado = 2 then -- caja cerrada
       v_det_campos := '[' || 'MTO_TRANSFERENCIA'    ||'~'||ltrim(to_char(v_sal_actual))|| ']';
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
end FUJ_VAL_TRANSACCION_204;
/

