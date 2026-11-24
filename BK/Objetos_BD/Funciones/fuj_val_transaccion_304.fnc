create or replace function it.FUJ_VAL_TRANSACCION_304(
      p_nro_operacion   in varchar2,  -- Nro de referencia de la operacion
      p_nro_caj_origen  in varchar2,  -- Nro de Caja
      p_nro_cheque      in varchar2,  -- Nro de cheque
      p_nro_cuenta      in varchar2  default null, -- Nro de cuenta del cliente
      p_nro_caj_afecta  in varchar2 default null)  -- Número de Caja a la que debe Afectar
return VARCHAR2 is
  p_nro_caja varchar2(3);
  -- Datos de la transaccion
  v_cod_modulo number(3)      := 9;      -- Caja
  v_cod_modalidad number(3)   := 91;     -- Caja
  v_cod_transaccion number(4) := 304;    -- transaccion
  v_cod_usuario varchar2(10) := upper(user); --usuario
  -- Datos de la caja
  v_fec_actual        date := pag_cal.fu_obt_fec_actual(v_cod_modulo); -- fecha de hoy
  v_cod_oficina       number(3);         -- Codigo de oficina
  v_estado            number(1);         -- estado de la caja
  v_fec_caja          date;              -- fecha de la caja
  v_sal_actual        number(18,2);      -- saldo actual de la caja en efectivo
  v_sal_cheques        number(18,2);     -- saldo actual de la caja en cheques
  -- Datos de la cuenta
  v_nro_cuenta        varchar2(20);      -- contiene el nro de cuenta
  v_denominacion      varchar2(200);     -- Nombre de la cuenta
  v_cod_moneda        varchar2(3);       -- moneda de la cuenta
  v_est_cuenta        varchar2(1);       -- estado de la cuenta
  v_tip_cuenta        number(3);         -- tipo de cuenta(modalidad)
  v_est_cheque        varchar2(01);      -- estado del cheque
  v_nro_cheque        number(8);         -- para contener el nro de cheque
  -- Datos de salida
  v_msj_salida    varchar2(8000);        -- mensaje final retornado
  v_cod_respuesta varchar2(03) := '000'; -- sin errores
  v_msj_respuesta varchar2(100) := 'OK'; -- sin errores
  -- Datos de campos a devolver
  v_can_campos    number(3) := 2;        -- cantidad de campos
  v_det_campos    varchar2(4000) :=      -- valores devueltos por defecto
           '[' || 'DES_CUENTA' ||'~ ]' ||
           '[' || 'COD_MONEDA' ||'~ ]';
  v_nro_caj_afecta cj_cajas.nro_caja%type;
  v_des_caj_afecta cj_cajas.descripcion%type;
  v_tie_oficina    varchar2(1) := 'N';
begin
 -- Valido la moneda
 if p_nro_cheque is null then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el Nro. de Cheque a pagar.';
 elsif p_nro_caj_afecta is not null and nvl(fuj_obt_tip_caja(p_nro_caj_afecta),'x') <> 'P' then
    v_cod_respuesta := '003'; -- error
    v_msj_respuesta := 'ERROR: Ingrese un Nro. de Caja válido.';
 else
   if v_cod_respuesta = '000' then -- sino hubo problemas, veo la caja
       --
       v_cod_oficina := fuj_obt_cod_oficina(p_nro_caj_origen);
       --
       if v_cod_respuesta = '000' then
         begin
           select c.nro_caja, c.descripcion, 'S'
             into v_nro_caj_afecta, v_des_caj_afecta,v_tie_oficina
             from cj_cajas c
            where c.tipo = 'P'
              and c.cod_oficina = v_cod_oficina;
         exception
           when no_data_found then
             if p_nro_caj_afecta is not null then
               -- Sino tiene caja prosegur en su oficina, verifica que la caja ingresada sea correcta.
               v_nro_caj_afecta := p_nro_caj_afecta;
               --
               begin
                 select descripcion
                   into v_des_caj_afecta
                   from cj_cajas 
                  where tipo = 'P'
                    and nro_caja = v_nro_caj_afecta;
               exception
                 when no_data_found then
                   v_cod_respuesta := '004';
                   v_msj_respuesta := 'Debe ingresar un Número de Caja válido.';
                 when others then
                   v_cod_respuesta := '004';
                   v_msj_respuesta := substr(sqlerrm,1,100);  
               end;
             end if;
           when others then
              v_cod_respuesta := '005';
              v_msj_respuesta := substr(sqlerrm,1,100);       
         end;
       end if;
       p_nro_caja := v_nro_caj_afecta;
   end if;
   --
   if v_cod_respuesta = '000' then
     if length(p_nro_cheque) > 8 then
         -- se leyo directamente el cheque a traves de la lectora
         v_can_campos := 4;        -- cantidad de campos
         -- formato: "C 2800E016101070079E07961910A"
         --          "C 1700E000700213425E04866772A"
         if  substr(p_nro_cheque,3,2) <> substr(pag_gen.fu_obt_cod_entidad,3,2) then
             v_cod_respuesta := '002'; -- error
             v_msj_respuesta := 'ERROR: Cheque no pertenece al Banco. ';
             v_det_campos := '[' || 'NRO_CHEQUE' ||'~ ]'||
                             '[' || 'NRO_CUENTA' ||'~ ]'||
                             '[' || 'DES_CUENTA' ||'~ ]' ||
                             '[' || 'COD_MONEDA' ||'~ ]';
         else
             v_nro_cuenta := to_number(substr(p_nro_cheque,13,7)); -- tomo el nro de cuenta
             v_nro_cheque := substr(p_nro_cheque,21,8); -- tomo el nro de cheque
             v_det_campos := '[' || 'NRO_CHEQUE' ||'~'||ltrim(to_char(v_nro_cheque))|| ']' ||     -- valores devueltos por defecto
                             '[' || 'NRO_CUENTA' ||'~'||v_nro_cuenta||']';
         end if;
     --elsif p_nro_cuenta is null then
     --    v_cod_respuesta := '002'; -- error
     --    v_msj_respuesta := 'ERROR: Ingrese la Cuenta Corriente del cliente.';
     else
         -- asigno directamente los datos de parametros, es un ingreso manual
         v_nro_cheque := p_nro_cheque;
         v_nro_cuenta := p_nro_cuenta;
     end if;
   end if;
 end if;
 -- sino tiene errores
 if v_cod_respuesta = '000' and v_nro_cuenta is not null then
    -- obtengo datos de la cuenta  ------------------------------------------
    begin
      select substr(replace(denominacion,'~','N'),1,50), cod_moneda, estado, cod_modalidad
        into v_denominacion, v_cod_moneda, v_est_cuenta, v_tip_cuenta
        from ge_cuentas a
       where a.nro_cuenta = v_nro_cuenta;
    if v_tip_cuenta not in (41,42,43,44,45) then
      v_cod_respuesta := '003';
      v_msj_respuesta := 'ERROR: Tipo de cuenta no permite pago de Cheques';
    else
    --
    v_det_campos := '[' || 'DES_CUENTA' ||'~'||v_denominacion|| ']' ||
                    '[' || 'COD_MONEDA' ||'~'||v_cod_moneda|| ']';
      -- Verifico la duplicacion del registro
        prj_val_duplicacion(p_nro_caja,
                            v_cod_transaccion,
                            v_cod_moneda,
                            v_nro_cheque,
                            v_cod_respuesta,
                            v_msj_respuesta);
        if v_cod_respuesta = '000' then
           v_msj_respuesta := fuj_ver_impedimentos(v_nro_cuenta,
                                                   v_tip_cuenta,
                                                   v_cod_transaccion,
                                                   v_est_cuenta,
                                                  'D'); -- 'D'== debito en cuenta
           if v_msj_respuesta is not null then
              v_cod_respuesta := '004';  -- la cuenta tiene impedimentos
           end if;
        end if;
      end if;
    exception
      when no_data_found then
        v_cod_respuesta := '002';
        v_msj_respuesta := 'ERROR: Nro de cuenta '||v_nro_cuenta||' no existe!';
      when others then
        v_cod_respuesta := '003';
        v_msj_respuesta := sqlerrm;
    end;
    if v_cod_respuesta = '000' THEN -- sino hubo errores veo el cheque
      v_est_cheque := pac_che.fu_obt_est_che(v_nro_cuenta,
                                             v_nro_cheque,
                                             v_msj_respuesta);
      -- verifico el estado del cheque
      if v_msj_respuesta is null then
          if v_est_cheque = 'A' then
              v_msj_respuesta := 'El cheque '||v_nro_cheque||' de la cuenta '||v_nro_cuenta||' ha sido anulado';
          elsif v_est_cheque = 'P' then
             v_msj_respuesta := 'El cheque '||v_nro_cheque||' de la cuenta '||v_nro_cuenta||' ya fue pagado';
          elsif v_est_cheque = 'S' then
             v_msj_respuesta := 'El cheque '||v_nro_cheque||' de la cuenta '||v_nro_cuenta||' no se ha Entregado';
          elsif v_est_cheque = 'O'  then
             v_msj_respuesta := 'El cheque '||v_nro_cheque||' de la cuenta '||v_nro_cuenta||' tiene Orden de NO Pagar';
          elsif v_est_cheque not in ('E','C','G') then
             v_msj_respuesta := 'El cheque '||v_nro_cheque||' de la cuenta '||v_nro_cuenta||' con estado incorrecto.';
          end if;
      end if;
      if v_msj_respuesta is not null then
        v_cod_respuesta := '009';
      end if;
    end if;
    --
    if v_cod_moneda is not null and p_nro_caja is not null then
       -- Obtengo los datos de la caja ---------------------------------------
       prj_obt_datos_caja(p_nro_caja,
                          v_cod_moneda,
                          v_cod_oficina,
                          v_fec_caja,
                          v_estado,
                          v_sal_actual,
                          v_sal_cheques,
                          'N');
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
  --
  if v_cod_respuesta = '000' then -- sino hubo problemas se arma los datos de la cuenta
    if v_tie_oficina = 'S' then
     v_det_campos := v_det_campos||fuj_des_campo('NRO_CAJ_AFECTA',v_nro_caj_afecta,null,'D');
   else
     v_det_campos := v_det_campos||fuj_des_campo('NRO_CAJ_AFECTA',v_nro_caj_afecta,null,'O');
   end if;
    v_det_campos := v_det_campos||'[' || 'DES_CAJ_AFECTA'    ||'~'||ltrim(v_des_caj_afecta)|| ']';
  end if;
  v_msj_salida := p_nro_operacion||'~'||
                  v_cod_respuesta||'~'||
                  nvl(v_msj_respuesta,'OK')||'~'||
                  ltrim(to_char(v_can_campos,'000'))||'~'||
                  v_det_campos;
  if v_cod_respuesta = '000' and v_nro_cuenta is not null then
     -- dejo en el campo de importe
     v_msj_salida := v_msj_salida||'5'; -- indicador del campo importe
  end if;
  return(v_msj_salida);
end FUJ_VAL_TRANSACCION_304;
/

