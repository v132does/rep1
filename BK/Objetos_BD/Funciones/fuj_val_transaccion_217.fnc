CREATE OR REPLACE FUNCTION IT.FUJ_VAL_TRANSACCION_217 (
      p_nro_operacion in varchar2,   -- Nro de referencia de la operacion
      p_nro_caja in varchar2,        -- Nro de Caja
      p_nro_boleta in varchar2)      -- nro de boleta a detallar    
return VARCHAR2 is
  -- Datos de la transaccion
  v_cod_modulo number(3)      := 9;      -- Caja
  v_cod_modalidad number(3)   := 91;     -- Caja
  v_cod_transaccion number(4) := 217;    -- transaccion
  v_cod_usuario varchar2(10) := upper(user); --usuario
  -- Datos de la caja
  v_fec_actual        date := pag_cal.fu_obt_fec_actual(v_cod_modulo); -- fecha de hoy
  v_cod_oficina       number(3);         -- Codigo de oficina
  v_estado            number(1);         -- estado de la caja
  v_fec_caja          date;              -- fecha de la caja
  v_sal_actual        number(18,2);      -- saldo actual de la caja en efectivo
  v_sal_cheques        number(18,2);     -- saldo actual de la caja en cheques
  -- Datos de la cuenta
  v_nro_cuenta        varchar2(20);      -- contenedor de la cuenta  
  v_denominacion      varchar2(200);     -- Nombre de la cuenta
  v_cod_moneda        varchar2(3);       -- moneda de la cuenta
  v_est_cuenta        varchar2(1);       -- estado de la cuenta
  v_tip_cuenta        number(3);         -- tipo de cuenta(modalidad)
  v_tot_deposito      number(18,2);
  -- Datos de salida
  v_msj_salida    varchar2(8000);        -- mensaje final retornado
  v_cod_respuesta varchar2(03) := '000'; -- sin errores
  v_msj_respuesta varchar2(100) := 'OK'; -- sin errores
  -- Datos de campos a devolver
  v_can_campos    number(3) := 2;        -- cantidad de campos
  v_det_campos    varchar2(8000) :=      -- valores devueltos por defecto
           '[' || 'NRO_CUENTA' ||'~ ]' || 
           '[' || 'DES_CUENTA' ||'~ ]' || 
           '[' || 'TOT_DEPOSITO' ||'~ ]' ||            
           '[' || 'COD_MONEDA' ||'~ ]';     
begin
 -- Valido la moneda 
 if p_nro_boleta is null then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el Nro. de Boleta.';
 else 
    begin 
     select a.nro_cuenta, a.monto, substr(replace(b.denominacion,'~','N'),1,45), a.cod_moneda, b.estado, b.cod_modalidad
       into v_nro_cuenta, v_tot_deposito, v_denominacion, v_cod_moneda, v_est_cuenta, v_tip_cuenta
       from ge_cuentas b,cj_movimientos a
      where a.estado = 'N'
        and a.tip_monto in ('O', 'T','S')
        and a.cod_tra_padre  in (215,395)
        and a.tipo = 'D'
        and a.nro_caja = to_number(p_nro_caja)
        and a.nro_documento = to_number(p_nro_boleta) 
        and b.nro_cuenta(+) = a.nro_cuenta
        and exists (select 0 from cj_cajas d
                     where d.nro_caja = a.nro_caja
                       and d.tipo = 'A'
        );
    exception
       when no_data_found then
           v_cod_respuesta := '001'; -- error
           v_msj_respuesta := 'ERROR: Boleta no registrada en esta Caja. Verifique.';   
       when others then
           v_cod_respuesta := '001'; -- error
           v_msj_respuesta := 'ERROR: en lectura de la Boleta '||sqlerrm;              
    end;
    -- obtengo datos de la cuenta  ------------------------------------------
    if v_cod_respuesta = '000' then -- sino hubo problemas 
        -- Verifico la duplicacion del registro
        prj_val_duplicacion(p_nro_caja,
                            v_cod_transaccion,
                            v_cod_moneda,
                            p_nro_boleta,
                            v_cod_respuesta,
                            v_msj_respuesta);
        if v_cod_respuesta = '000' then                     
           v_msj_respuesta := fuj_ver_impedimentos(v_nro_cuenta,
                                                   v_tip_cuenta,
                                                   v_cod_transaccion,
                                                   v_est_cuenta,
                                                   'C'); -- 'C'== CREDITO
           if v_msj_respuesta is not null then
              v_cod_respuesta := '004';  -- la cuenta tiene impedimentos
           end if;   
        end if;
    end if;
    if v_cod_respuesta = '000' then -- sino hubo problemas se arma los datos de la cuenta
        v_det_campos := '[' || 'DES_CUENTA' ||'~'||v_denominacion|| ']' || 
                        '[' || 'COD_MONEDA' ||'~'||v_cod_moneda|| ']' || 
                        '[' || 'NRO_CUENTA' ||'~'||v_nro_cuenta|| ']'|| 
                        '[' || 'TOT_DEPOSITO' ||'~'||v_tot_deposito|| ']' ;
    end if;
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
end FUJ_VAL_TRANSACCION_217;
/
