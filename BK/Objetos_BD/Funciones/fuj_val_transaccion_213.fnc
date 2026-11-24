create or replace function it.FUJ_VAL_TRANSACCION_213(
      p_nro_operacion in varchar2,   -- Nro de referencia de la operacion
      p_nro_caja in varchar2,        -- Nro de Caja
      p_nro_boleta in varchar2,      -- Nro de la boleta
      p_cod_moneda  in varchar2,     -- codigo de la moneda
      p_mto_efectivo in varchar2 default null,    -- importe en efectivo
      p_concepto    in varchar2 default null)     -- concepto de la operacion
return VARCHAR2 is
  -- defino por defecto el modulo y modalidad a utilizar
  v_cod_modulo number(3)      := 9;    -- Caja
  v_cod_modalidad number(3)   := 91;   -- Caja
  v_cod_transaccion number(4) := 213;  -- transaccion
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
  v_tipo          varchar2(01) := 'C';  -- Crédito para la caja (egreso)
  v_tip_monto     varchar2(01) := 'O';  -- Cheq. Otros Bancos
  v_mto_efectivo  number := nvl(to_number(p_mto_efectivo),0); -- importe  en efectivo
  v_nro_secuencia number(3) := 0;  -- secuencia del mov.
  -- datos de la lista
  v_can_campos    number(3) := 1;        -- cantidad de campos
  v_det_campos    varchar2(8000) := null;
  v_val_posibles  varchar2(3000) := null;

begin
 -- Inicializacion de la aplicacion y el modulo
 BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=v_cod_modulo; END;
 -- Valido la moneda
 if p_nro_boleta is null then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el Nro. de Boleta.';
 elsif p_cod_moneda is null then
    v_cod_respuesta := '002'; -- error
    v_msj_respuesta := 'ERROR: Ingrese la Moneda de la Operacion.';
 elsif v_mto_efectivo < 0 then
    v_cod_respuesta := '003'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el importe en Efectivo.';
 else
    -- Valido la moneda ingresada
    prj_val_moneda(p_cod_moneda, v_cod_respuesta,v_msj_respuesta);
 end if;
 if v_cod_respuesta = '000' then -- sin errores
    -- Verifico la duplicacion del registro
    prj_val_duplicacion(p_nro_caja,
                        v_cod_transaccion,
                        p_cod_moneda,
                        p_nro_boleta,
                        v_cod_respuesta,
                        v_msj_respuesta);
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
          v_msj_respuesta := 'Caja no fue habilitada el dia de hoy';
       end if;
    end if;
    if v_cod_respuesta = '000' then
       --Verifico los decimales del importe en Efectivo
       v_msj_respuesta := fuj_val_importe(v_tipo, 'E',p_cod_moneda,v_mto_efectivo);
       if v_msj_respuesta is not null then
          v_cod_respuesta := '005';  -- error
       end if;
    end if;
 end if;
 -- mensaje final sino hubo errores
 if v_cod_respuesta = '000' then -- sino hubo problemas, se carga mensaje por defecto
    v_msj_respuesta := 'Ok';
 end if;
 /* falta armar el mensaje de respuesta */
v_msj_salida := p_nro_operacion||'~'||
                v_cod_respuesta||'~'||
                nvl(v_msj_respuesta,'OK')||'~'||
                ltrim(to_char(v_can_campos,'000'))||'~'||
                v_det_campos;
 return(v_msj_salida);
end FUJ_VAL_TRANSACCION_213;
/

