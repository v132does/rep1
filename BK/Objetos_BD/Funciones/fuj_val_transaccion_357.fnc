CREATE OR REPLACE FUNCTION IT."FUJ_VAL_TRANSACCION_357" (
      p_nro_operacion   in varchar2,      -- Nro de referencia de la operacion
      p_nro_caja        in varchar2,      -- Nro de Caja
      p_cod_modalidad   in varchar2,      -- Modalidad de Ahorro
      p_serie           in varchar2,      -- Nro de serie del certificado
      p_nro_certificado in varchar2,      -- Nro del certificado
      p_cod_moneda      in varchar2 default null,  -- moneda      
      p_nro_cupon       in varchar2,
      p_imp_pagar in varchar2 default null,
      p_importe in varchar2 default null)      -- Nro del cupon
return VARCHAR2 is
  -- Datos de la transaccion
  v_cod_modulo number(3)      := 9;      -- Caja
  v_cod_modalidad number(3)   := 91;     -- Caja
  v_cod_transaccion number(4) := 357;    -- transaccion
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
  v_beneficiario      varchar2(200);     -- Nombre del Beneficiario
  v_fec_vencimiento   varchar2(10);      -- Fecha de vencto. en formato char
  v_cod_moneda        varchar2(3);       -- moneda de la cuenta
  v_est_cuenta        varchar2(1);       -- estado de la cuenta
  v_est_certificado   varchar2(1);       -- estado del certificado
  v_est_cupon         varchar2(1);       -- estado del cupon
  v_bloqueado         varchar2(1);       -- indica si el cupon esta bloqueado
  v_tip_cuenta        number(3);         -- tipo de cuenta(modalidad)
  v_sal_cupon         number(18,2);      -- monto del cupon
  v_mto_a_pagar       number := to_number(p_imp_pagar); -- Monto Real a Pagar (con retencion)
  v_mto_cal_pagar     number; -- Monto Calculado a Pagar
  v_mto_ret_calculado number; -- importe retencion calculado 
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
           '[' || 'COD_MONEDA' ||'~ ]'||
           '[' || 'IMP_EFECTIVO' ||'~ ]'||
           '[' || 'MTO_RETENCION' ||'~ ]'||
           '[' || 'MTO_NETO' ||'~ ]';
begin
 -- Valido los datos recibidos
 if p_cod_modalidad is null then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese la Modalidad.';
 elsif p_serie is null then
    v_cod_respuesta := '002'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el Nro. de la Serie.';
 elsif p_nro_certificado is null then  -- valido la cuenta
    v_cod_respuesta := '003'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el Numero del Certificado.';
 elsif p_imp_pagar is null then  -- monto a Pagar 
    v_cod_respuesta := '004'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el Monto a Pagar.';
 else
    -- obtengo datos de la cuenta  ------------------------------------------
    begin
      Select nro_cuenta, denominacion, cod_moneda, estado, cod_modalidad,
             substr(replace(beneficiario,chr(10),' '),1,68), est_certificado
        into v_nro_cuenta, v_denominacion, v_cod_moneda, v_est_cuenta,
             v_tip_cuenta, v_beneficiario, v_est_certificado
        from ah_cta_certificados
       where serie = p_serie
         and cod_modalidad = p_cod_modalidad
         and nro_certificado = to_number(p_nro_certificado)
         and cod_moneda = nvl(p_cod_moneda,cod_moneda)
         and estado not in ('A', 'T');
      if v_est_cuenta in ('A','T','C','D') then
        v_cod_respuesta := '003';
        v_msj_respuesta := 'ERROR: Cuenta no esta activa. Verifique!';
      else
        -- Verifico los datos del cupon
        begin
           select estado, to_char(fec_vencimiento,'dd/mm/yyyy'),bloqueado,
                  a.mto_interes
             into v_est_cupon, v_fec_vencimiento, v_bloqueado, 
                  v_sal_cupon
             from ah_cupones a
            where a.nro_cuenta = v_nro_cuenta
              and a.nro_cupon = to_number(p_nro_cupon);
           if v_est_cupon = 'P' THEN
              v_cod_respuesta := '002';
              v_msj_respuesta := 'ERROR: Nro.de Cupon ya ha sido pagado!';
           elsif v_bloqueado = 'S' then
              v_cod_respuesta := '002';
              v_msj_respuesta := 'ERROR: Nro de Cupon esta bloqueado!';
           elsif v_est_cupon <> 'V' then
              v_cod_respuesta := '002';
              v_msj_respuesta := 'ERROR: Nro de Cupon no esta vencido!';
           end if;
        exception
          when no_data_found then
            v_cod_respuesta := '002';
            v_msj_respuesta := 'ERROR: Nro de Cupon no existe para este Documento!';
          when others then
            v_cod_respuesta := '003';
            v_msj_respuesta := sqlerrm;
        end;
        if v_cod_respuesta = '000' then
          -- Verifico la duplicacion del registro
          prj_val_duplicacion(p_nro_caja,
                              v_cod_transaccion,
                              v_cod_moneda,
                              p_nro_cupon,
                              v_cod_respuesta,
                              v_msj_respuesta);
        end if;
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
     if v_cod_respuesta = '000' then
         v_mto_ret_calculado := paa_ret.fu_obt_inr_ret_cda(v_nro_cuenta,
                                                           p_cod_modalidad,
                                                           p_serie,
                                                           p_nro_certificado,
                                                           p_cod_moneda,
                                                           p_nro_cupon,
                                                           v_fec_actual);   

         v_mto_cal_pagar := v_sal_cupon - nvl(v_mto_ret_calculado,0);
         
         If v_mto_a_pagar <>  v_mto_cal_pagar then
           v_cod_respuesta := '006';
           v_msj_respuesta :=  'Operación tiene retención, favor corrija monto a Pagar :'||abs(v_mto_cal_pagar);
         end if;

      end if;
      
      if v_cod_respuesta = '000' then -- sino hubo problemas se arma los datos de la cuenta
        v_det_campos := '[' || 'NRO_CUENTA' ||'~'||v_nro_cuenta|| ']'||
                        '[' || 'DES_CUENTA' ||'~'||v_denominacion|| ']' ||
                        '[' || 'BENEFICIARIO' ||'~'||v_beneficiario|| ']'  ||
                        '[' || 'FEC_VENCTO' ||'~'||v_fec_vencimiento|| ']'  ||
                        '[' || 'COD_MONEDA' ||'~'||v_cod_moneda|| ']'||
                        '[' || 'IMP_EFECTIVO'||'~'||ltrim(to_char(v_sal_cupon))|| ']'||
                        '[' || 'IMP_RETENCION' ||'~'||ltrim(to_char(v_mto_ret_calculado))|| ']'||
                        '[' || 'IMP_NETO' ||'~'||ltrim(to_char(v_mto_cal_pagar))||'~X]' ;
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
end FUJ_VAL_TRANSACCION_357;
/

