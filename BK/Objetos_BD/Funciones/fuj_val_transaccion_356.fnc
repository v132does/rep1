create or replace function it.FUJ_VAL_TRANSACCION_356(
      p_nro_operacion   in varchar2,      -- Nro de referencia de la operacion
      p_nro_caja        in varchar2,      -- Nro de Caja
      p_cod_modalidad       in varchar2,      -- Modalidad de Ahorro
      p_serie           in varchar2,      -- Nro de serie del CDA
      p_nro_certificado in varchar2,      -- Nro del certificado
      p_cod_moneda      in varchar2 default null)  -- moneda
return VARCHAR2 is
  -- Datos de la transaccion
  v_cod_modulo number(3)      := 9;      -- Caja
  v_cod_modalidad number(3)   := 91;     -- Caja
  v_cod_transaccion number(4) := 356;    -- transaccion
  v_cod_usuario varchar2(10) := upper(user); --usuario
  -- Datos de la caja
  v_fec_actual        date := pag_cal.fu_obt_fec_actual(v_cod_modulo); -- fecha de hoy
  v_cod_oficina       number(3);         -- Codigo de oficina
  v_estado            number(1);         -- estado de la caja
  v_fec_caja          date;              -- fecha de la caja
  v_sal_actual        number(18,2);      -- saldo actual de la caja en efectivo
  v_sal_cheques       number(18,2);      -- saldo actual de la caja en cheques
  -- Datos de la cuenta
  v_nro_cuenta        varchar2(20);      -- numero de cuenta
  v_denominacion      varchar2(200);     -- Nombre de la cuenta
  v_beneficiario      varchar2(100);     -- Nombre del Beneficiario
  v_fec_vencimiento   varchar2(10);      -- Fecha de vencto. en formato char
  v_cod_moneda        varchar2(3);       -- moneda de la cuenta
  v_est_cuenta        varchar2(1);       -- estado de la cuenta
  v_est_certificado   varchar2(1);       -- estado del certificado
  v_tip_cuenta        number(3);         -- tipo de cuenta(modalidad)
  v_sal_cda           number(18,2);      -- saldo a retirar
  v_capital           number(18,2);      -- capital
  -- Datos de salida
  v_msj_salida    varchar2(8000);        -- mensaje final retornado
  v_cod_respuesta varchar2(03) := '000'; -- sin errores
  v_msj_respuesta varchar2(100) := 'OK'; -- sin errores
  -- Datos de campos a devolver
  v_can_campos    number(3) := 6;        -- cantidad de campos
  v_det_campos    varchar2(8000) :=      -- valores devueltos por defecto
           '[' || 'NRO_CUENTA' ||'~ ]' ||
           '[' || 'DES_CUENTA' ||'~ ]' ||
           '[' || 'BENEFICIARIO' ||'~ ]' ||
           '[' || 'FEC_VENCTO' ||'~ ]' ||
           '[' || 'COD_MONEDA' ||'~ ]' ||
           '[' || 'IMP_EFECTIVO' ||'~ ]';
begin
 -- Valido los datos recibidos
 if p_cod_modalidad is null then
     v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese la Modalidad de Ahorro';
 elsif p_serie is null then
    v_cod_respuesta := '002'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el Nro. de la Serie.';
 elsif p_nro_certificado is null then  -- valido la cuenta
    v_cod_respuesta := '003'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el Numero del Certificado.';
 else
    -- obtengo datos de la cuenta  ------------------------------------------
    begin
      Select nro_cuenta, denominacion, cod_moneda, estado, cod_modalidad,
             substr(replace(beneficiario,chr(10),' '),1,68), to_char(fec_vencimiento,'dd/mm/yyyy'),
             est_certificado, nvl(sal_total,0) - nvl(sal_retenido,0) - nvl(sal_bloqueado,0),
             capital
        into v_nro_cuenta, v_denominacion, v_cod_moneda, v_est_cuenta,
             v_tip_cuenta, v_beneficiario, v_fec_vencimiento,
             v_est_certificado, v_sal_cda, v_capital
        from ah_cta_certificados
       where serie = p_serie
         and nro_certificado = to_number(p_nro_certificado)
         and cod_moneda = nvl(p_cod_moneda,cod_moneda)
         and cod_modalidad = p_cod_modalidad
         and estado not in ('A', 'T');
      -- solo se paga el capital
      --if v_sal_cda > v_capital    then
      --   v_sal_cda := v_capital;
      --end if;
      -- Resto los cupones vencidos
      select nvl(v_sal_cda,0) - nvl(sum(mto_interes),0)
        into v_sal_cda
        from ah_cupones
       where nro_cuenta = v_nro_cuenta
         and estado = 'V';
      if v_est_cuenta = 'B' then
        v_cod_respuesta := '003';
        v_msj_respuesta := 'ERROR: Cuenta bloqueada. No se puede pagar';
      elsif v_est_cuenta not in ('V','P','S') then
        v_cod_respuesta := '003';
        v_msj_respuesta := 'ERROR: Cuenta no esta vencida. No se puede pagar.';
      elsif v_est_certificado not in ('V') then
        v_cod_respuesta := '004';
        v_msj_respuesta := 'ERROR: Documento no se halla vencido. No se puede pagar.';
      else
        -- Verifico la duplicacion del registro
        prj_val_duplicacion(p_nro_caja,
                            v_cod_transaccion,
                            v_cod_moneda,
                            p_nro_certificado,
                            v_cod_respuesta,
                            v_msj_respuesta);
        if v_cod_respuesta = '000' then
           v_msj_respuesta := fuj_ver_impedimentos(v_nro_cuenta,
                                                   v_tip_cuenta,
                                                   v_cod_transaccion,
                                                   v_est_cuenta,
                                                  'D'); -- 'D'== debito en cuenta
           if v_msj_respuesta is not null then
              v_cod_respuesta := '005';  -- la cuenta tiene impedimentos
           end if;
        end if;
      end if;
      if v_cod_respuesta = '000' then -- sino hubo problemas se arma los datos de la cuenta
        v_det_campos := '[' || 'NRO_CUENTA' ||'~'||v_nro_cuenta|| ']'||
                        '[' || 'DES_CUENTA' ||'~'||v_denominacion|| ']' ||
                        '[' || 'BENEFICIARIO' ||'~'||v_beneficiario|| ']'  ||
                        '[' || 'FEC_VENCTO' ||'~'||v_fec_vencimiento|| ']'  ||
                        '[' || 'COD_MONEDA' ||'~'||v_cod_moneda|| ']' ||
                        '[' || 'IMP_EFECTIVO'    ||'~'||ltrim(to_char(v_sal_cda))|| '~X]';
      end if;
      if v_sal_cda = 0 and v_cod_respuesta = '000' then
        v_cod_respuesta := '003';
        v_msj_respuesta := 'ERROR: Capital bloqueado!.';
      end if;   
    exception
      when no_data_found then
        v_cod_respuesta := '002';
        v_msj_respuesta := 'ERROR: Nro de Documento no existe!';
      when others then
        v_cod_respuesta := '003';
        v_msj_respuesta := sqlerrm;
    end;
    if v_cod_respuesta = '000' then -- sino hubo problemas, veo la caja
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
     end if;
  end if;
  v_msj_salida := p_nro_operacion||'~'||
                  v_cod_respuesta||'~'||
                  nvl(v_msj_respuesta,'OK')||'~'||
                  ltrim(to_char(v_can_campos,'000'))||'~'||
                  v_det_campos;
  return(v_msj_salida);
end FUJ_VAL_TRANSACCION_356;
/

