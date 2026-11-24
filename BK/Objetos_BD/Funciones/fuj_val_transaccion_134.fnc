create or replace function it.FUJ_VAL_TRANSACCION_134(
      p_nro_operacion in varchar2,   -- Nro de referencia de la operacion
      p_nro_caja in varchar2,        -- Nro de Caja
      p_nro_boleta in varchar2,      -- Nro de boleta de deposito
      p_cod_banco  in number default null)
return VARCHAR2 is
  -- Datos de la transaccion
  v_cod_modulo number(3)      := 9;      -- Caja
  v_cod_modalidad number(3)   := 91;     -- Caja
  v_cod_transaccion number(4) := 134;    -- transaccion
  v_cod_usuario varchar2(10) := upper(user); --usuario
  -- Datos de la caja
  v_fec_actual        date := pag_cal.fu_obt_fec_actual(v_cod_modulo); -- fecha de hoy
  v_cod_oficina       number(3);         -- Codigo de oficina
  v_estado            number(1);         -- estado de la caja
  v_fec_caja          date;              -- fecha de la caja
  v_sal_actual        number(18,2);      -- saldo actual de la caja en efectivo
  v_sal_cheques        number(18,2);     -- saldo actual de la caja en cheques
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
           and a.tip_monto in ('X') -- tipo cheque otros bcos plaza extranjera
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
    if v_cod_respuesta = '000' then -- sino hubo problemas, veo la caja
      if p_cod_banco is not null then
         --if p_cod_banco <> 999 then
           begin
             select '[' || 'DES_BANCO' ||'~'||descripcion|| ']'
               into v_det_campos
              from ge_bancos
              where cod_banco = p_cod_banco
                and ubicacion = 'E'
                and estado = 'A';
           exception
              when no_data_found then
                v_cod_respuesta := '001'; -- error
                v_msj_respuesta := 'ERROR: Codigo de Banco invalido.';
              when others then
                v_cod_respuesta := '001'; -- error
                v_msj_respuesta := 'ERROR: Codigo de Banco invalido.';
           end;
        --end if;
      end if;
    end if;
  end if;
  v_msj_salida := p_nro_operacion||'~'||
                  v_cod_respuesta||'~'||
                  nvl(v_msj_respuesta,'  ')||'~'||
                  ltrim(to_char(v_can_campos,'000'))||'~'||
                  v_det_campos;
  return(v_msj_salida);
end FUJ_VAL_TRANSACCION_134;
/

