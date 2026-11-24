create or replace function it.FUJ_VAL_TRANSACCION_224(
      p_nro_operacion in varchar2,   -- Nro de referencia de la operacion
      p_nro_caj_actual in varchar2, 
      p_nro_caja in varchar2,        -- Nro de Caja
      p_nro_boleta in varchar2 default null,
      p_cod_moneda in varchar2 default null,      -- Codigo de moneda
     -- p_tip_operacion in varchar2 default 'N',-- No recibe mas como parametro la operacion, solo se 
                                                  -- va usar para el ingreso del sobrante. 30/08/2011 VV. 
      p_monto in number default null)  --Nro. de Caja Destino--
return VARCHAR2 is
  -- defino por defecto el modulo y modalidad a utilizar
  v_cod_modulo number(3) := 9;               -- Caja
  v_cod_modalidad number(3) := 91;           -- Caja
  v_cod_transaccion number(3) := 224;        -- Transaccion
  --
  v_cod_oficina number(3);                   -- oficina de la caja
  v_cod_usuario varchar2(10) := upper(user); -- usuario
  --
  v_estado            number(1);             -- estado de la caja
  v_fec_caja          date;                  -- fecha de la caja
  v_sal_actual        number(18,2);          -- saldo actual de la caja en efectivo
  v_sal_cheques        number(18,2);          -- saldo actual de la caja en cheques
  --
  v_tip_operacion  VARCHAR2(1) := 'N';       -- Solo va a permitir cargar un nuevo sobrante. Remplaza al parametro.
  v_msj_salida    varchar2(8000);            -- mensaje final retornado
  v_cod_respuesta varchar2(03) := '000';     -- sin errores
  v_msj_respuesta varchar2(100) := 'OK';     -- MENSAJE sin errores
  -- detalle de campos. Por defecto van los campos en blanco
  v_can_campos    number(3) := 2;        -- cantidad de campos
  v_det_campos    varchar2(8000) :=       -- valor por defecto
              '[' || 'MONTO'    ||'~ ]';
  v_fec_actual date := pag_cal.FU_OBT_FEC_ACTUAL(9);
  v_descripcion cj_cajas.descripcion%type;

begin
 -- Valido la moneda
 if p_nro_boleta is null then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el Nro.de Boleta.';
 elsif p_cod_moneda is null then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese la Moneda.';
 elsif v_tip_operacion is null then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el Tipo.';
 else
    prj_val_moneda(p_cod_moneda, v_cod_respuesta,v_msj_respuesta);
 end if;
 --Valido la Caja de Destino--
 if v_tip_operacion is null then
    if v_cod_respuesta = '000' then
           v_det_campos := '[' ||
                            'TIP_OPERACION~X~'||
                            fuj_pro_val_posibles(fuj_obt_val_posibles(v_cod_transaccion,'TIP_OPERACION')) ||
                            ']';
    end if;
 else
    v_descripcion := fue_obt_des_refcodes('TIP_FAL_SOB_CAJA',v_tip_operacion);
    if v_cod_respuesta = '000' then -- sino hubo problemas se arma los datos de la cuenta
       v_det_campos := '[' || 'DES_OPERACION' ||'~'||v_descripcion|| ']';
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
                       v_sal_cheques,
                       'N'); -- para que no valide el responsable de la caja
    if v_estado = -1 then
        v_cod_respuesta := '006'; -- error, no existe registro de caja
        v_msj_respuesta := 'Caja inexistente!!';
    elsif v_estado NOT in (1,3,4) then  -- error, la caja ya esta abierta
       v_cod_respuesta := '003'; -- error
       v_msj_respuesta := 'Caja no puede realizar Operacion no se halla abierta';
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
end FUJ_VAL_TRANSACCION_224;
/

