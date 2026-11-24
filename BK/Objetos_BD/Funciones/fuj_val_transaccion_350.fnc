create or replace function it.FUJ_VAL_TRANSACCION_350(
      p_nro_operacion in varchar2,   -- Nro de referencia de la operacion
      p_nro_caj_origen in varchar2,        -- Nro de Caja
      p_nro_boleta in varchar2 default null,      -- Nro de la boleta de deposito
      p_nro_cuenta in varchar2,      -- Nro de cuenta del cliente
      p_nro_caj_afecta  in varchar2 default null,  -- N¿mero de Caja a la que debe Afectar
      p_tot_deposito in number default null -- total del deposito
      )
return VARCHAR2 is
  -- Datos de la transaccion
  v_cod_modulo number(3)      := 9;      -- Caja
  v_cod_modalidad number(3)   := 91;     -- Caja
  v_cod_transaccion number(4) := 350;    -- transaccion
  v_cod_usuario varchar2(10) := upper(user); --usuario
  --
  p_nro_caja    varchar2(3);
  -- Datos de la caja
  v_fec_actual        date := pag_cal.fu_obt_fec_actual(v_cod_modulo); -- fecha de hoy
  v_cod_oficina       number(3);         -- Codigo de oficina
  v_estado            number(1);         -- estado de la caja
  v_fec_caja          date;              -- fecha de la caja
  v_sal_actual        number(18,2);      -- saldo actual de la caja en efectivo
  v_sal_cheques        number(18,2);     -- saldo actual de la caja en cheques
  -- Datos de la cuenta
  v_denominacion      varchar2(200);     -- Nombre de la cuenta
  v_cod_moneda        varchar2(3);       -- moneda de la cuenta
  v_est_cuenta        varchar2(1);       -- estado de la cuenta
  v_cod_mad_cuenta        number(3);         -- tipo de cuenta(modalidad)
  v_cod_mod_cuenta    number(3);         -- modulo de cuenta
  v_capital           number(18,2);      -- para contener el capital
  v_fec_apertura      date;              -- fecha de apertura
  v_est_certificado   varchar2(01);      -- estado del cda
  v_est_ahorro        varchar2(01);      -- estado del cta_ahorro
  -- Datos de salida
  v_msj_salida    varchar2(8000);        -- mensaje final retornado
  v_cod_respuesta varchar2(03) := '000'; -- sin errores
  v_msj_respuesta varchar2(100) := 'OK'; -- sin errores
  -- Datos de campos a devolver
  v_can_campos    number(3) := 4;        -- cantidad de campos
  v_det_campos    varchar2(8000) :=      -- valores devueltos por defecto
           '[' || 'DES_CUENTA' ||'~ ]' ||
           '[' || 'COD_MONEDA' ||'~ ]' ||
           '[' || 'IMP_CARGO' ||'~ ]'||
           '[' || 'TOT_EFECTIVO' ||'~ ]';
  -- ingreso
  v_mto_efectivo   number := nvl(to_number(p_tot_deposito),0); -- importe del deposito en efectivo
  -- datos calculados
  v_tot_cargo         number := 0;   -- monto del cargo + impuesto
  v_tot_efectivo       number := 0;   -- capital + cargos
  v_cod_tas_cargo     number;
  v_val_tas_cargo     number;
  v_val_cargo         number;
  v_cod_tra_impuesto  number;
  v_cod_tas_impuesto  number;
  v_val_tas_impuesto  number;
  v_val_impuesto      number;
  v_saldo             number;
  --
  v_nro_caj_afecta cj_cajas.nro_caja%type;
  v_des_caj_afecta cj_cajas.descripcion%type;
  v_tie_oficina    varchar2(1) := 'N';
  v_cod_persona       ba_personas.cod_persona%type;--CROCLIJUD-5	 
  v_cod_cau_judicial  ge_causales.cod_causa%type := fug_obt_pardinamico('COD_CAU_DEM_JUDICIAL'); 
begin
 -- Valido la moneda
 if p_nro_boleta is null then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el Nro. de Boleta.';
 elsif p_nro_cuenta is null then  -- valido la cuenta
    v_cod_respuesta := '002'; -- error
    v_msj_respuesta := 'ERROR: Ingrese la Cuenta del cliente.';
 elsif p_nro_caj_afecta is not null and nvl(fuj_obt_tip_caja(p_nro_caj_afecta),'x') <> 'P' then
    v_cod_respuesta := '003'; -- error
    v_msj_respuesta := 'ERROR: Ingrese un Nro. de Caja v¿lido.';
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
                   v_msj_respuesta := 'Debe ingresar un N¿mero de Caja v¿lido.';
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
    -- obtengo datos de la cuenta  ------------------------------------------
    begin
      select substr(replace(denominacion,'~','N'),1,45), cod_moneda, estado, cod_modalidad, cod_modulo
        into v_denominacion, v_cod_moneda, v_est_cuenta, v_cod_mad_cuenta,
             v_cod_mod_cuenta
        from ge_cuentas a
       where a.nro_cuenta = p_nro_cuenta;

       ---Verifica si el Cliente o un Vinculado a la Cuenta est¿ inhibido y la causa es por Demanda Judicial --CROCLIJUD-5
       v_cod_persona := fug_obt_cli_principal(p_nro_cuenta);
       if fug_obt_inhibicion(v_cod_cau_judicial,v_cod_persona, p_nro_cuenta) Then
             v_cod_respuesta := '007';
             v_msj_respuesta := 'ERROR: Cliente Principal o Vinc. a la Cuenta con Demanda Judicial. Consulte con el asesor Jur¿dico';
       End If;

      if v_cod_respuesta = '000' then -- sino hubo problemas se arma los datos de la cuenta
        v_det_campos := '[' || 'DES_CUENTA' ||'~'||v_denominacion|| ']' ||
                        '[' || 'COD_MONEDA' ||'~'||v_cod_moneda|| ']';
      end if;
      if v_cod_mad_cuenta not in (31,33,34,35,41) then
        v_cod_respuesta := '003';
        v_msj_respuesta := 'ERROR: Tipo de cuenta no permite Depositos';
      else
        -- si es cda, se verifica que el monto corresponda al capital
        if v_cod_mad_cuenta in (33,34,35) and NVL(v_mto_efectivo,0) > 0 THEN  -- is not null then
            select nvl(capital,0) - nvl(sal_total,0),fec_apertura,est_certificado, estado
              into v_capital,v_fec_apertura, v_est_certificado, v_est_ahorro
              from ah_cta_certificados
             where nro_cuenta = p_nro_cuenta;
            if v_mto_efectivo <> v_capital then
            --if nvl(v_mto_efectivo,0)+nvl(v_mto_cheque,0) <> v_capital then --VER CON AGUS EFECTIVO Y CHEQUE
               v_cod_respuesta := '003';
               v_msj_respuesta := 'ERROR: Monto ingresado no corresponde al Capital.';
            elsif v_fec_apertura <> v_fec_actual then
               v_cod_respuesta := '003';
               v_msj_respuesta := 'ERROR: Fecha de Apertura no corresponde a Hoy.';
            elsif v_est_ahorro <> 'A' AND v_est_certificado <> 'C' then
               v_cod_respuesta := '003';
               v_msj_respuesta := 'ERROR: Carton debe ser cargado previamente.';
            end if;
        elsif v_cod_mad_cuenta = 41 then--si es cta cte verifica el saldo
            select nvl(sal_total,0) - nvl(sal_retenido,0) - nvl(sal_bloqueado,0)
              into v_saldo
              from cc_cta_corrientes
             where nro_cuenta = p_nro_cuenta;
        end if;
        If p_nro_boleta is not null then
          if v_cod_respuesta = '000' then
            -- Verifico la duplicacion del registro
            prj_val_duplicacion(p_nro_caja,
                                v_cod_transaccion,
                                v_cod_moneda,
                                p_nro_boleta,
                                v_cod_respuesta,
                                v_msj_respuesta);
          end if;
        End if;
        if v_cod_respuesta = '000' then
           v_msj_respuesta := fuj_ver_impedimentos(p_nro_cuenta,
                                                   v_cod_mad_cuenta,
                                                   v_cod_transaccion,
                                                   v_est_cuenta,
                                                   'C'); -- 'C'== CREDITO
           if v_msj_respuesta is not null then
              if v_cod_mad_cuenta = 41 and v_msj_respuesta like 'Cuenta esta pendiente de Cancelacion' then
                 --si la cuenta tiene saldo negativo puede recibir dep¿sitos
                 if v_saldo > 0 then
                    v_cod_respuesta := '004';  -- la cuenta tiene impedimentos
                 end if;
              else
                 v_cod_respuesta := '004';  -- la cuenta tiene impedimentos
              end if;
           end if;
        end if;
      end if;
      if v_cod_respuesta = '000' then -- sino hubo problemas se arma los datos de la cuenta
        v_det_campos := '[' || 'DES_CUENTA' ||'~'||v_denominacion|| ']' ||
                        '[' || 'COD_MONEDA' ||'~'||v_cod_moneda|| ']';
      end if;
      if p_tot_deposito <= 0 then
         v_cod_respuesta := '002'; -- error
         v_msj_respuesta := 'ERROR: Ingrese correctamente el Total de Deposito.';
      elsif v_mto_efectivo > 0 and v_mto_efectivo > p_tot_deposito then
         v_cod_respuesta := '002'; -- error
         v_msj_respuesta := 'ERROR: Total Efectivo ya supera al total de Deposito.';
      end if;
    exception
      when no_data_found then
        v_cod_respuesta := '002';
        v_msj_respuesta := 'Nro de cuenta no existe!';
      when others then
        v_cod_respuesta := '003';
        v_msj_respuesta := sqlerrm;
    end;
    if v_cod_respuesta = '000' and p_nro_caja is not null then -- sino hubo problemas, veo la caja
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
     -- veo el monto del cargo e impuesto, si se ingres¿ el capital
     if v_cod_respuesta = '000' and v_mto_efectivo is not null then
         -- totalizo el cargo
         v_tot_cargo := nvl(v_val_cargo,0) + nvl(v_val_impuesto,0);
        if v_cod_mad_cuenta in (33,34,35)  then
           -- si es a plazo, el cargo es aparte, sino se extrae del monto
           v_tot_efectivo := nvl(v_mto_efectivo,0) + v_tot_cargo;
        else
           v_tot_efectivo := v_mto_efectivo;
        end if;
         -- se ingreso el capital, calculo el cargo y total depositado
         v_can_campos := 4;
         v_det_campos := v_det_campos ||
            '[' || 'IMP_CARGO'  ||'~'||ltrim(to_char(v_tot_cargo))|| ']' ||
            '[' || 'TOT_EFECTIVO' ||'~'||ltrim(to_char(v_tot_efectivo))|| ']';
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
  end if;
  v_msj_salida := p_nro_operacion||'~'||
                  v_cod_respuesta||'~'||
                  nvl(v_msj_respuesta,'OK')||'~'||
                  ltrim(to_char(v_can_campos,'000'))||'~'||
                  v_det_campos;
  return(v_msj_salida);
exception
   when others then
      v_msj_salida := p_nro_operacion||'~'||'999'||'~!'||sqlerrm;
      return(v_msj_salida);

end FUJ_VAL_TRANSACCION_350;
/

