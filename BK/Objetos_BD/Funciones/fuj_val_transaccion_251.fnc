create or replace function it.FUJ_VAL_TRANSACCION_251(
      p_nro_operacion in varchar2,   -- Nro de referencia de la operacion
      p_nro_caja in varchar2,        -- Nro de Caja
      p_nro_boleta in varchar2 default null,    -- Nro de boleta
      --p_nombre in varchar2 default null,  -- Nombre
      p_nro_documento in varchar2 default null, -- Nro de Cedula
      p_nro_tarjeta in varchar2 DEFAULT NULL, -- Nro de Tarjeta
      --p_cod_comercio in varchar2 default null,
      p_can_cuotas in varchar2 default null,
      p_imp_efectivo in varchar2 default null)   
return VARCHAR2 is
  -- defino por defecto el modulo y modalidad a utilizar
  v_cod_modulo number(3)      := 9;    -- Caja
  v_cod_modalidad number(3)   := 91; -- Caja
  v_cod_transaccion number(4) := 250; -- cod de transaccion
  v_cod_usuario varchar2(10)  := upper(user); --usuario
  v_importe       number := to_number(p_imp_efectivo); -- importe de la extraccion  
  -- Datos de la caja
  v_fec_actual        date := pag_cal.fu_obt_fec_actual(v_cod_modulo); -- fecha de hoy
  v_hor_actual        varchar2(08) := to_char(sysdate,'HH24:MI:SS');   -- Hora actual
  v_cod_oficina       number(3);         -- Codigo de oficina
  v_estado            number(1);         -- estado de la caja
  v_fec_caja          date;              -- fecha de la caja
  v_sal_actual        number(18,2);          -- saldo actual de la caja en efectivo
  v_sal_cheques       number(18,2);          -- saldo actual de la caja en cheques
  -- Datos de la cuenta
  v_denominacion      varchar2(200);     -- Nombre de la cuenta
  v_cod_moneda        varchar2(3);       -- moneda de la cuenta
  v_est_cuenta        varchar2(1);       -- estado de la cuenta
  v_tip_cuenta        number(3);         -- tipo de cuenta(modalidad)
  --
  v_can_campos    number(3) := 0;        -- cantidad de campos
  v_det_campos    varchar2(8000) := null;
  v_msj_salida    varchar2(8000);        -- mensaje final retornado
  v_cod_respuesta varchar2(03) := '000'; -- sin errores
  v_msj_respuesta varchar2(100) := 'OK'; -- sin errores
  v_val_posibles  varchar2(3000);
  --Datos de los cargos
  v_nro_cuenta       ta_tarjetas.nro_cuenta%type;
  v_cod_tra_cargo    ge_movimientos.cod_transaccion%type:= 1779; -- Solo para pruebas
  v_cod_tas_cargo    ge_movimientos.cod_tasa%type;
  v_val_tas_cargo    ge_movimientos.val_tasa%type;
  v_val_cargo        ge_movimientos.val_tasa%type;
  v_cod_tra_impuesto ge_movimientos.cod_transaccion%type;
  v_cod_tas_impuesto ge_movimientos.cod_tasa%type;
  v_val_tas_impuesto ge_movimientos.val_tasa%type;
  v_val_impuesto     ge_movimientos.val_tasa%type;   
  v_procesa           varchar2(1) := 'N';    
  v_cod_seg_cliente  ge_clientes.cod_seg_cliente%type;
  v_cargo            number;
  v_total            number;
  v_sal_disponible   number;
  
  
  function lp_obt_sal_disponible(p_nro_cuenta in varchar2)

  return number is
    v_sal_dis_return number default 0;
    begin
      select (nvl(lin_credito,0) - (nvl(sal_facturar,0) + nvl(sal_facturado,0) 
             + nvl(sal_financiado,0))) sal_disponible
        into v_sal_dis_return
        from ta_cta_tarjetas
       where nro_cuenta = p_nro_cuenta;
      return v_sal_dis_return;
    exception
      when no_data_found then
        v_cod_respuesta := '002';
        v_msj_respuesta := 'ERROR: Nro de cuenta no existe!';
      when others then
        v_cod_respuesta := '003';
        v_msj_respuesta := 'ERROR al obt. el saldo disponible ' || sqlerrm;
    end;
begin
  /* este proceso esta incompleto */
  /* se devuelve los valores posibles de acuerdo al numero de CI */
  v_can_campos := 1;
 -- Valido la moneda
 /*if p_nro_boleta is null then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el Nro. de Boleta de Extraccion.';
/* elsif p_nro_documento is null and p_nombre is not null and p_nro_tarjeta is null then
    -- Obtengo el select de la lista de valores para el documento
    v_val_posibles  := fuj_obt_val_posibles(v_cod_transaccion,'NRO_DOCUMENTO');
    v_val_posibles := replace(v_val_posibles,'&NOMBRE',REPLACE(REPLACE(p_nombre, '  ', ' '), ' ', '%')||'%');
    if v_cod_respuesta = '000' then
       v_det_campos := v_det_campos ||
                       '[NRO_DOCUMENTO'||'~'||'X'||'~'||
                       fuj_pro_val_posibles(v_val_posibles) ||
                       ']';
    end if;*/
 if p_nro_tarjeta is null then  -- valido la cuenta
    /* se devuelve los valores posibles para el codigo de transaccion a reversar
    Datos a devolver por campo: [Nombre_campo~Valor_defecto~Valores_Posibles]
    */
    if v_cod_respuesta = '000' then
       v_det_campos := '[' ||
                        'NRO_TARJETA~X~'||
                        fuj_pro_val_posibles(replace(fuj_obt_val_posibles(v_cod_transaccion,'NRO_TARJETA'),'&'||'NRO_DOCUMENTO',p_nro_documento)) ||
                        ']'||
                        '[' || 'CARGO' ||'~ ]'||
                        '[' || 'TOTAL' ||'~ ]'; 
    end if;
 else
    -- obtengo datos de la cuenta  ------------------------------------------
    begin
      select a.nom_embozar, c.cod_moneda, c.estado, 
             c.cod_modalidad, c.nro_cuenta
        into v_denominacion, v_cod_moneda, v_est_cuenta, 
             v_tip_cuenta, v_nro_cuenta
        from ta_cta_tarjetas c, ta_tarjetas a
       where a.nro_cuenta = c.nro_cuenta
         and a.nro_tarjeta = p_nro_tarjeta;

      If p_nro_boleta is not null then
        -- Verifico la duplicacion del registro
        prj_val_duplicacion(p_nro_caja,
                            v_cod_transaccion,
                            v_cod_moneda,
                            p_nro_boleta,
                            v_cod_respuesta,
                            v_msj_respuesta);
      End if;
      if v_cod_respuesta = '000' then
         v_msj_respuesta := fuj_ver_impedimentos(p_nro_tarjeta,
                                                 v_tip_cuenta,
                                                 v_cod_transaccion,
                                                 v_est_cuenta,
                                                'D'); -- 'D'== debito en cuenta
         if v_msj_respuesta is not null then
            --RI : 18/01/10 : Se permite adelando sobre cuentas canceladas
            if  v_msj_respuesta = 'Cuenta Cancelada' then
               v_cod_respuesta := '000';
            else   
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
        v_msj_respuesta := 'ERROR: Nro de Tarjeta no existe!';
      when too_many_rows then
        v_cod_respuesta := '003';
        v_msj_respuesta := 'ERROR: Existe más de una tarjeta con este nro!';
      when others then
        v_cod_respuesta := '008';
        v_msj_respuesta := 'ERROR al obtener datos de la cuenta ' ||sqlerrm;
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
     -- veo el monto del cargo e impuesto, si se ingresó el monto a extraer
     if v_cod_respuesta = '000' and v_importe is not null then
       begin
         select nro_cuenta
           into v_nro_cuenta
           from ta_tarjetas
          where nro_tarjeta = p_nro_tarjeta;
       exception
         when others then
           v_cod_respuesta := '006'; -- error
           v_msj_respuesta := 'Error al Buscar la Cuenta de la Tarjeta. '||sqlerrm;           
       end;
       --
       v_sal_disponible := lp_obt_sal_disponible(v_nro_cuenta);
       if v_importe > (v_sal_disponible * 1.1) then -- saldo disponible mas 10%
         v_cod_respuesta := '007'; 
         v_msj_respuesta := 'ERROR: Monto supera al Saldo Disponible.';
       end if;
       --
       
       if v_cod_respuesta = '000' then
         prg_obt_cargos(v_cod_oficina,
                         v_nro_cuenta,
                         v_cod_moneda,
                         p_imp_efectivo,
                         5, -- Módulo Tarjeta
                         v_tip_cuenta, -- Modalidad Tarjeta
                         v_cod_tra_cargo,--Transaccion para el cobro de cargos por extraccion 
                         v_cod_tas_cargo,
                         v_val_tas_cargo,
                         v_val_cargo,
                         v_cod_tra_impuesto,
                         v_cod_tas_impuesto,
                         v_val_tas_impuesto,
                         v_val_impuesto);
         --
         if p_can_cuotas > 1 then
           v_cargo  := nvl(V_VAL_CARGO,0)+ nvl(V_VAL_IMPUESTO,0);
           v_total  := v_importe - nvl(v_cargo,0);
         else
           v_total  := v_importe;
         end if;
         v_can_campos := 4;
         v_det_campos := v_det_campos ||
            '[' || 'CARGO'  ||'~'||ltrim(to_char(v_cargo))|| ']'||
            '[' || 'TOTAL'  ||'~'||ltrim(to_char(v_total))|| ']';
       end if;
     end if;
  end if;
  v_msj_salida := p_nro_operacion||'~'||
                  v_cod_respuesta||'~'||
                  nvl(v_msj_respuesta,'OK')||'~'||
                  ltrim(to_char(v_can_campos,'000'))||'~'||
                  v_det_campos;
  return(v_msj_salida);
end FUJ_VAL_TRANSACCION_251;
/

