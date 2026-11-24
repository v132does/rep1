create or replace function it.FUJ_VAL_TRANSACCION_131(
      p_nro_operacion in varchar2,            -- Nro de referencia de la operacion
      p_nro_caja in varchar2,                 -- Nro de Caja
      p_nro_boleta in varchar2,               -- Nro de boleta de deposito
      p_nro_cheque in varchar2  default null, -- Nro de cheque 
      p_nro_cuenta in varchar2  default null) -- Nro de cuenta del cli      
return VARCHAR2 is
  -- Datos de la transaccion
  v_cod_modulo number(3)      := 9;      -- Caja
  v_cod_modalidad number(3)   := 91;     -- Caja
  v_cod_transaccion number(4) := 131;    -- transaccion
  v_cod_usuario varchar2(10) := upper(user); --usuario
  -- Datos de la caja
  v_fec_actual        date := pag_cal.fu_obt_fec_actual(v_cod_modulo); -- fecha de hoy
  v_cod_oficina       number(3);         -- Codigo de oficina
  v_estado            number(1);         -- estado de la caja
  v_fec_caja          date;              -- fecha de la caja
  v_sal_actual        number(18,2);      -- saldo actual de la caja en efectivo
  v_sal_cheques        number(18,2);     -- saldo actual de la caja en cheques
  --
  v_denominacion      varchar2(200);     -- Nombre de la cuenta
  v_cod_mon_cta       varchar2(3);       -- moneda de la cuenta
  v_est_cuenta        varchar2(1);       -- estado de la cuenta
  v_tip_cuenta        number(3);         -- tipo de cuenta(modalidad)
  v_est_cheque        varchar2(01);      -- estado del cheque  
  v_nro_cheque        number(8);         -- para contener el nro de cheque
  -- Datos de salida
  v_msj_salida    varchar2(8000);        -- mensaje final retornado
  v_cod_respuesta varchar2(03) := '000'; -- sin errores
  v_msj_respuesta varchar2(100) := '  '; -- sin errores
  -- Datos de campos a devolver
  v_can_campos    number(3) := 2;        -- cantidad de campos
  v_det_campos    varchar2(8000) :=      -- valores devueltos por defecto
           '[' || 'COD_MONEDA' ||'~ ]' ||
           '[' || 'IMP_TOTAL' ||'~ ]'  ||
           '[' || 'IMP_DETALLE' ||'~ ]'||
           '[' || 'DIF_CHEQUE' ||'~ ]';
  -- datos del movimiento
  v_imp_total   number(18,2) := 0;
  v_imp_detalle number(18,2) := 0;
  v_cod_moneda  varchar2(3);

begin
 -- Valido la moneda
 if p_nro_boleta is null then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el Nro. de Boleta de Extraccion.';
 else
    -- obtengo datos de la operacion de deposito -------------------------
    begin
        select a.cod_moneda Moneda, nvl(a.monto,0), nvl(a.tot_detallado,0)
          into v_cod_moneda, v_imp_total, v_imp_detalle
          from cj_movimientos a
         where a.estado = 'N' -- estado normal
           and a.tip_monto in ('C') -- tipo cheque ntro.bco
           and a.tipo = 'D' -- ingreso a la caja
           ---and a.cod_usuario = v_cod_usuario -- ingresado por el usuario
           and a.nro_caja = to_number(p_nro_caja)
           and a.nro_documento = to_number(p_nro_boleta)
           and nvl(monto,0) > nvl(tot_detallado,0) -- que no fue totalmente detallado
           and rownum = 1;  -- por si hay duplicaciones
        if v_imp_total <= v_imp_detalle then
           v_cod_respuesta := '002';
           v_msj_respuesta := 'ERROR: Boleta ya fue totalmente detallada!';
        else
           if v_cod_respuesta = '000' then -- sino hubo problemas se arma los datos de la cuenta
              v_det_campos := '[' || 'COD_MONEDA' ||'~'||v_cod_moneda|| ']' ||
                              '[' || 'IMP_TOTAL' ||'~'||to_char(v_imp_total)|| ']'||
                              '[' || 'IMP_DETALLE' ||'~'||to_char(v_imp_detalle)|| ']'||
                              '[' || 'DIF_CHEQUE' ||'~'||to_char(v_imp_total-v_imp_detalle)||']';

           end if;
        end if;
    exception
      when no_data_found then
        v_cod_respuesta := '002';
        v_msj_respuesta := 'ERROR: Boleta no registrada en el sistema o ya fue detallada!';
      when too_many_rows then
        v_cod_respuesta := '003';
        v_msj_respuesta := 'ERROR: Boleta duplicada!';
      when others then
        v_cod_respuesta := '003';
        v_msj_respuesta := sqlerrm;
    end;
    -- obtengo datos de la cuenta  ------------------------------------------
    if v_cod_respuesta = '000' and p_nro_cuenta is not null then   
        begin
          select denominacion, cod_moneda, estado, cod_modalidad
            into v_denominacion, v_cod_mon_cta, v_est_cuenta, v_tip_cuenta
            from ge_cuentas a
           where a.nro_cuenta = p_nro_cuenta;
          if v_tip_cuenta not in (41,42,43,44) then
            v_cod_respuesta := '003';
            v_msj_respuesta := 'ERROR: Tipo de cuenta no permite pago de Cheques';  
          elsif v_cod_mon_cta <> v_cod_moneda then
            v_cod_respuesta := '004';
            v_msj_respuesta := 'ERROR: Moneda del Cheque no corresponde al del Deposito';  
          else
            -- Verifico la duplicacion del registro
            prj_val_duplicacion(p_nro_caja,
                                v_cod_transaccion,
                                v_cod_moneda,
                                p_nro_cheque,
                                v_cod_respuesta,
                                v_msj_respuesta);      
          end if;
          if v_cod_respuesta = '000' then -- sino hubo problemas se arma los datos de la cuenta
            v_det_campos := v_det_campos ||
                            '[' || 'DES_CUENTA' ||'~'||v_denominacion|| ']' || 
                            '[' || 'COD_MONEDA2' ||'~'||v_cod_moneda|| ']';
          end if;
        exception
          when no_data_found then
            v_cod_respuesta := '002';
            v_msj_respuesta := 'ERROR: Nro de cuenta '||p_nro_cuenta||' no existe!';  
          when others then
            v_cod_respuesta := '003';
            v_msj_respuesta := sqlerrm;
        end;
        if v_cod_respuesta = '000' THEN -- sino hubo errores veo el cheque
            v_est_cheque := pac_che.fu_obt_est_che(p_nro_cuenta,
                                                   p_nro_cheque,
                                                   v_msj_respuesta);
            -- verifico el estado del cheque
            if v_msj_respuesta is null then
                if v_est_cheque <> 'O' and v_est_cuenta not in ('P','C') then
                   v_msj_respuesta := 'El cheque '||p_nro_cheque||' de la cuenta '||p_nro_cuenta||' no tiene Orden de NO Pagar';
                end if;
            end if;
            if v_msj_respuesta is not null then
              v_cod_respuesta := '009';  
            end if;   
        end if;
    end if;
    ---
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
                  nvl(v_msj_respuesta,'  ')||'~'||
                  ltrim(to_char(v_can_campos,'000'))||'~'||
                  v_det_campos;
  return(v_msj_salida);
end FUJ_VAL_TRANSACCION_131;
/

