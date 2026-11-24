create or replace function it.FUJ_VAL_TRANSACCION_352(
      p_nro_operacion in varchar2,   -- Nro de referencia de la operacion
      p_nro_caja in varchar2,        -- Nro de Caja
     -- p_nro_boleta in varchar2,      -- Nro de la boleta de deposito
      p_nro_cuenta in varchar2,      -- Nro de cuenta del cliente
      p_tot_deposito in number default null,  -- total de deposito
      p_tot_che_24hs in number default null,
      p_tot_che_48hs in number default null,
      p_tot_che_72hs in number default null)  -- total de cheques 24 hs     
return VARCHAR2 is
  -- Datos de la transaccion
  v_cod_modulo number(3)      := 9;      -- Caja
  v_cod_modalidad number(3)   := 91;     -- Caja
  v_cod_transaccion number(4) := 352;    -- transaccion
  v_cod_usuario varchar2(10) := upper(user); --usuario
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
  v_tip_cuenta        number(3);         -- tipo de cuenta(modalidad)
  -- Datos de salida
  v_msj_salida    varchar2(8000);        -- mensaje final retornado
  v_cod_respuesta varchar2(03) := '000'; -- sin errores
  v_msj_respuesta varchar2(100) := 'OK'; -- sin errores --
  -- Datos de campos a devolver
  v_can_campos    number(3) := 2;        -- cantidad de campos
  v_det_campos    varchar2(8000) :=      -- valores devueltos por defecto
           '[' || 'DES_CUENTA' ||'~ ]' || 
           '[' || 'COD_MONEDA' ||'~ ]';   
  v_saldo number;  
  /*CROCLIJUD-5*/
  v_cod_persona        ba_personas.cod_persona%type;
  v_cod_cau_judicial	 ge_causales.cod_causa%type := fug_obt_pardinamico('COD_CAU_DEM_JUDICIAL');
  --v_msj_ret24h    varchar2(20);
  v_msj_ret48h    varchar2(20);
  v_msj_ret72h    varchar2(20);
  v_mto_che_ret_cero cj_movimientos.monto%type;
  v_cod_mon_local ba_monedas.cod_moneda%type;
begin
 -- Valido la moneda 
 v_cod_mon_local := pag_gen.FU_OBT_MON_LOCAL;
 /*if p_nro_boleta is null then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el Nro. de Boleta.';*/
 if p_nro_cuenta is null then  -- valido la cuenta
    v_cod_respuesta := '002'; -- error
    v_msj_respuesta := 'ERROR: Ingrese la Cuenta del cliente.';
 else
  ---
  if p_nro_cuenta is not null then  -- valido la cuenta si es migrada
     v_msj_respuesta := fug_obt_nro_cta_bt(p_nro_cuenta);
     if v_msj_respuesta is not null then
        v_cod_respuesta := '012'; -- error
     end if;
  end if;
  if v_cod_respuesta = '000' then
    -- obtengo datos de la cuenta  ------------------------------------------
    v_cod_respuesta := '000';
    v_msj_respuesta := 'OK'; 
    begin
      select substr(replace(denominacion,'~','N'),1,45), cod_moneda, estado, cod_modalidad
        into v_denominacion, v_cod_moneda, v_est_cuenta, v_tip_cuenta
        from ge_cuentas a
       where a.nro_cuenta = p_nro_cuenta;
       
      ---Verifica si el Cliente o un Vinculado a la Cuenta est? inhibido y la causa es por Demanda Judicial --CROCLIJUD-5
       v_cod_persona := fug_obt_cli_principal(p_nro_cuenta);
       if fug_obt_inhibicion(v_cod_cau_judicial,v_cod_persona,p_nro_cuenta) Then
          v_cod_respuesta := '005';
          v_msj_respuesta := 'ERROR: Cliente Principal. o Vinc. a la Cuenta con Demanda Judicial.Consulte con el asesor Jur?dico' ;
       End If;
       
      if v_tip_cuenta not in (31,32,33,34,41,334) then
        v_cod_respuesta := '003';
        v_msj_respuesta := 'ERROR: Tipo de cuenta no permite Depositos';  
     -- elsif v_cod_moneda <> pag_gen.FU_OBT_MON_LOCAL() then
     --   v_cod_respuesta := '003';
     --   v_msj_respuesta := 'ERROR: Solo puede ingresar depositos en moneda local.';  
      else
        -- Verifico la duplicacion del registro
        prj_val_duplicacion(p_nro_caja,
                            v_cod_transaccion,
                            v_cod_moneda,
                            999, --p_nro_boleta, no se controla porque se genera
                            v_cod_respuesta,
                            v_msj_respuesta);

        if v_cod_respuesta = '000' then                                                 
           if v_tip_cuenta = 41 then--si es cta cte verifica el saldo
               select nvl(sal_total,0) - nvl(sal_retenido,0) - nvl(sal_bloqueado,0)
                 into v_saldo
                 from cc_cta_corrientes
                where nro_cuenta = p_nro_cuenta;
           end if;
        end if;                            
        if v_cod_respuesta = '000' then                     
           v_msj_respuesta := fuj_ver_impedimentos(p_nro_cuenta,
                                                   v_tip_cuenta,
                                                   v_cod_transaccion,
                                                   v_est_cuenta,
                                                   'C'); -- 'C'== CREDITO
           if v_msj_respuesta is not null then
              if v_tip_cuenta = 41 and v_msj_respuesta like 'Cuenta esta pendiente de Cancelacion' then
                 --si la cuenta tiene saldo negativo puede recibir dep?sitos	
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
      --Se verifican para que no supere monto de total--
      if p_tot_deposito <= 0 then 
         v_cod_respuesta := '002'; -- error
         v_msj_respuesta := 'ERROR: Ingrese correctamente el Total de Deposito.';
      elsif p_tot_che_24hs > p_tot_deposito then
         v_cod_respuesta := '002'; -- error
         v_msj_respuesta := 'ERROR: Total de Cheques no puede ser mayor al Total depositado.';
      elsif p_tot_che_48hs > p_tot_deposito then
         v_cod_respuesta := '002'; -- error
         v_msj_respuesta := 'ERROR: Total de Cheques no puede ser mayor al Total depositado.';
      elsif p_tot_che_72hs > p_tot_deposito then
         v_cod_respuesta := '002'; -- error
         v_msj_respuesta := 'ERROR: Total de Cheques no puede ser mayor al Total depositado.';           
      end if;
      --Despliegue Mensaje Cheque Alto Valor / CORETRCH-1-Truncamiento / rpavon--
      v_msj_ret48h := null;
      v_msj_ret72h := null;
      if v_cod_moneda = v_cod_mon_local then
         v_mto_che_ret_cero := to_number(fug_obt_pardinamico('MTO_CHE_RET_CERO',null,null,v_cod_moneda));
         if nvl(p_tot_che_48hs,0) >= v_mto_che_ret_cero then
            v_msj_ret48h := 'Alto Valor,verificar';
         end if;
         if nvl(p_tot_che_72hs,0) >= v_mto_che_ret_cero then
            v_msj_ret72h := 'Alto Valor,verificar';
         end if;
      end if;
      v_det_campos := v_det_campos||'[' || 'MSJ_CHE_48' ||'~'||v_msj_ret48h||']'||
                                    '[' || 'MSJ_CHE_72' ||'~'||v_msj_ret72h||']';
      -----------------------------------------------------------------------------
    exception
      when no_data_found then
        v_cod_respuesta := '002';
        v_msj_respuesta := 'Nro de cuenta no existe!';  
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
   end if; --> Condicion de cuenta migrada
  end if;         
  v_msj_salida := p_nro_operacion||'~'||
                  v_cod_respuesta||'~'||
                  nvl(v_msj_respuesta,'OK')||'~'||
                  ltrim(to_char(v_can_campos,'000'))||'~'||
                  v_det_campos;
  return(v_msj_salida);
end FUJ_VAL_TRANSACCION_352;

 
/
