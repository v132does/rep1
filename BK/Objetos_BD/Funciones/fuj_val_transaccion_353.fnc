CREATE OR REPLACE FUNCTION IT.FUJ_VAL_TRANSACCION_353 (
      p_nro_operacion in varchar2,   -- Nro de referencia de la operacion
      p_nro_caja in varchar2,        -- Nro de Caja
      --p_nro_boleta in varchar2,      -- Nro de la boleta de deposito
      p_nro_cuenta in varchar2,      -- Nro de cuenta del cliente 
      p_imp_efectivo in varchar2 default null)     -- Importe de la extraccion)      
return VARCHAR2 is
  -- Datos de la transaccion
  v_cod_modulo number(3)      := 9;      -- Caja
  v_cod_modalidad number(3)   := 91;     -- Caja
  v_cod_transaccion number(4) := 353;    -- transaccion
  v_cod_usuario varchar2(10) := upper(user); --usuario
  v_importe       number := to_number(p_imp_efectivo); -- importe de la extraccion
  v_cargo         number;
  v_total         number;
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
  v_msj_respuesta varchar2(100) := 'OK'; -- sin errores
  -- Datos de campos a devolver
  v_can_campos    number(3) := 4;        -- cantidad de campos
  v_det_campos    varchar2(8000) :=      -- valores devueltos por defecto
           '[' || 'DES_CUENTA' ||'~ ]' || 
           '[' || 'COD_MONEDA' ||'~ ]'||
           '[' || 'CARGO' ||'~ ]'||
           '[' || 'TOTAL' ||'~ ]';                         
  --Datos de los cargos
  V_COD_TAS_CARGO     GE_MOVIMIENTOS.COD_TASA%TYPE;
  V_VAL_TAS_CARGO     GE_MOVIMIENTOS.VAL_TASA%TYPE;
  V_VAL_CARGO         GE_MOVIMIENTOS.VAL_TASA%TYPE;
  V_COD_TRA_IMPUESTO  GE_MOVIMIENTOS.COD_TRANSACCION%TYPE;
  V_COD_TAS_IMPUESTO  GE_MOVIMIENTOS.COD_TASA%TYPE;
  V_VAL_TAS_IMPUESTO  GE_MOVIMIENTOS.VAL_TASA%TYPE;
  V_VAL_IMPUESTO      GE_MOVIMIENTOS.VAL_TASA%TYPE; 
  v_cod_mod_cta       ge_cuentas.cod_modulo%type;
  v_cod_mad_cta       ge_cuentas.cod_modalidad%type;  
  v_nvo_estado        ge_cuentas.estado%type; 
  v_sal_disp          ge_cuentas.sal_contable%type;
  v_procesa           varchar2(1) := 'N';   
  -- FB:07.10.2009 Agregado p/ cobro de comisiones a ctas AV del segmento 26, pago de nóminas
  v_cod_seg_cliente   ge_clientes.cod_seg_cliente%type;  
   /*CROCLIJUD-5*/
  v_cod_persona        ba_personas.cod_persona%type;
  v_cod_cau_judicial	 ge_causales.cod_causa%type := fug_obt_pardinamico('COD_CAU_DEM_JUDICIAL');
  v_afe_debito         varchar2(1) default 'N';
begin
 -- Valido la moneda 
/* if p_nro_boleta is null then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el Nro. de Boleta de Extraccion.';
 els*/if p_nro_cuenta is null then  -- valido la cuenta
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
    begin
      select substr(replace(denominacion,'~','N'),1,45), cod_moneda, estado, cod_modalidad
        into v_denominacion, v_cod_moneda, v_est_cuenta, v_tip_cuenta
        from ge_cuentas a
       where a.nro_cuenta = p_nro_cuenta;
      if v_tip_cuenta not in (31,334,41) then
        v_cod_respuesta := '003';
        v_msj_respuesta := 'ERROR: Tipo de cuenta no permite Extracciones';  
      else
        -- Verifica a que segmento corresponde el cliente de la cuenta de ahorro
        begin
          select cod_seg_cliente
            into v_cod_seg_cliente
           from ge_clientes i, ge_cta_clientes a
          where i.cod_persona = a.cod_persona
            and a.nro_cuenta = p_nro_cuenta;
        exception
           when others then
                v_cod_seg_cliente := null;
        end;      
        -- Verifico la duplicacion del registro
        prj_val_duplicacion(p_nro_caja,
                            v_cod_transaccion,
                            v_cod_moneda,
                            999, --p_nro_boleta, no se controla porque se genera
                            v_cod_respuesta,
                            v_msj_respuesta);      
        if v_cod_respuesta = '000' then         
           v_msj_respuesta := fuj_ver_impedimentos(p_nro_cuenta,
                                                   v_tip_cuenta,
                                                   v_cod_transaccion,
                                                   v_est_cuenta,
                                                  'D'); -- 'D'== debito en cuenta
           if v_msj_respuesta is not null then
              v_cod_respuesta := '004';  -- la cuenta tiene impedimentos
           end if;
        end if;   
      end if;
      if v_cod_respuesta = '000' then -- sino hubo problemas se arma los datos de la cuenta
        v_det_campos := '[' || 'DES_CUENTA' ||'~'||v_denominacion|| ']' || 
                        '[' || 'COD_MONEDA' ||'~'||v_cod_moneda|| ']';
      end if;
    exception
      when no_data_found then
        v_cod_respuesta := '002';
        v_msj_respuesta := 'ERROR: Nro de cuenta no existe!';  
      when others then
        v_cod_respuesta := '003';
        v_msj_respuesta := sqlerrm;
    end;
    if v_cod_respuesta = '000' then  
       ---Verifica si el Cliente o un Vinculado a la Cuenta está inhibido y la causa es por Demanda Judicial --CROCLIJUD-5
       v_cod_persona := fug_obt_cli_principal(p_nro_cuenta);
       if fug_obt_inhibicion(v_cod_cau_judicial,v_cod_persona,p_nro_cuenta) Then
          v_cod_respuesta := '003';
          v_msj_respuesta := 'ERROR: Cliente Principal. o Vinc. a la Cuenta con Demanda Judicial.Consulte con el asesor Jurídico' ;
       end if;
       -- Verifica si el Cliente o la Cta. tiene Inhibición que no permita realizar débito BSEVOCORE-147
       v_afe_debito  := fug_obt_val_parcausal('AFE_DEB_CUENTA',v_cod_persona, p_nro_cuenta);
       if nvl(v_afe_debito,'N') = 'S' then
         v_cod_respuesta := '003';
         v_msj_respuesta := 'ERROR: Inhibición del Cliente Principal o Vinculados a la Cuenta no permite realizar Débito' ;
       end if;

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
       -- veo el monto del cargo e impuesto, si se ingresó el monto a extraer
       if v_cod_respuesta = '000' and v_importe is not null then
         -- busco el monto del cargo y el impuesto si la cuenta corresponde al segmento de pago de nomina(26)
/*         if nvl(v_cod_seg_cliente,0) = 26 then
            prg_obt_car_extraccion (p_nro_cuenta,
                                    V_COD_TAS_CARGO,
                                    V_VAL_TAS_CARGO,
                                    V_VAL_CARGO,
                                    V_COD_TRA_IMPUESTO,
                                    V_COD_TAS_IMPUESTO,
                                    V_VAL_TAS_IMPUESTO,
                                    V_VAL_IMPUESTO) ;
         end if;*/
         v_cargo  := nvl(V_VAL_CARGO,0)+ nvl(V_VAL_IMPUESTO,0);
         v_total  := v_importe + nvl(v_cargo,0);
         v_can_campos := 4;
         v_det_campos := v_det_campos ||
            '[' || 'CARGO'  ||'~'||ltrim(to_char(v_cargo))|| ']'||
            '[' || 'TOTAL'  ||'~'||ltrim(to_char(v_total))|| ']';
         --Verificar la operacion
         pag_cta.pr_ver_operacion(p_nro_cuenta,
                                  v_cod_transaccion,
                                  v_cod_modulo,
                                  v_cod_modalidad,
                                  'D',
                                  v_cod_moneda,
                                  v_importe+v_cargo,
                                  v_cod_oficina,
                                  v_cod_mod_cta,
                                  v_cod_mad_cta,
                                  v_nvo_estado,
                                  v_sal_disp,
                                  v_procesa);
                                   
         If v_procesa = 'N' then
           v_cod_respuesta := ltrim(to_char(pag_cta.g_cod_error,'000'));
           v_msj_respuesta := pag_cta.g_msj_error;
         End if;
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
end FUJ_VAL_TRANSACCION_353;
/
