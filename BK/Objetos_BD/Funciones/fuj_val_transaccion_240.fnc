CREATE OR REPLACE FUNCTION IT.FUJ_VAL_TRANSACCION_240
 (P_NRO_OPERACION IN varchar2
 ,P_NRO_CAJA IN varchar2
 ,P_COD_MONEDA IN varchar2
 )
 RETURN VARCHAR2
 IS

 -- defino por defecto el modulo y modalidad a utilizar
  v_cod_modulo number(3) := 9;               -- Caja
  v_cod_modalidad number(3) := 91;           -- Caja
  v_cod_transaccion number(3) := 240;        -- Transaccion
  --
  v_cod_oficina number(3);                   -- oficina de la caja
  v_cod_usuario varchar2(10) := upper(user); -- usuario
  --
  v_estado            number(1);             -- estado de la caja
  v_fec_caja          date;                  -- fecha de la caja
  v_sal_actual        number(18,2);          -- saldo actual de la caja en efectivo
  v_sal_cheques       number(18,2);          -- saldo actual de la caja en cheques
  v_che_no_detallados number(5) := 0;
  --
  v_msj_salida    varchar2(8000);            -- mensaje final retornado
  v_cod_respuesta varchar2(03) := '000';     -- sin errores
  v_msj_respuesta varchar2(100) := 'OK';     -- MENSAJE sin errores
  -- detalle de campos. Por defecto van los campos en blanco
  v_can_campos    number(3) := 10;        -- cantidad de campos
  v_det_campos    varchar2(8000) :=       -- valor por defecto
              '[' || 'MTO_EFECTIVO' ||'~ ]'||
              '[' || 'MTO_CHEQUE'   ||'~ ]';
begin
 -- Valido la moneda y el monto actual en caja
 if p_cod_moneda is null then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese la moneda que desea ajustar.';
    -- Valido la moneda ingresada
    prj_val_moneda(p_cod_moneda, v_cod_respuesta,v_msj_respuesta);
 end if;
 -- Valido que se hayan detallado todos los cheques
 Begin
    select COUNT(*)
      into v_che_no_detallados
      from cj_movimientos
     where tip_monto in ('C', 'O')
       and cod_tra_padre in (351,371)
       and nro_caja = to_number(p_nro_caja)
       and cod_moneda = p_cod_moneda
       and estado = 'N'
       and nvl(tot_detallado,0) != nvl(monto,0);
    If v_che_no_detallados != 0 Then
       v_cod_respuesta := '002';
       v_msj_respuesta := 'Error: No se han detallado todos los depósitos.';
    End If;
 End;
 --
 if v_cod_respuesta = '000' then -- no hubo errores
      -- Obtengo los datos de la caja ---------------------------------------
      prj_obt_datos_caja(p_nro_caja,
                         p_cod_moneda,
                         v_cod_oficina,
                         v_fec_caja,
                         v_estado,
                         v_sal_actual,
                         v_sal_cheques);
      if v_estado in (0,2) then  -- error, la caja no esta abierta
         v_cod_respuesta := '003'; -- error
         v_msj_respuesta := 'Caja aun no fue abierta en esta Moneda';
      elsif v_estado in (1,3,4) then -- caja
         -- Armo los detalles de los campos: [NOM_CAMPO~VALOR~VALORES POSIBLES]
         begin
           select '[' || 'MTO_EFECTIVO' ||'~'||ltrim(to_char(sal_actual * -1))|| ']' ||
                  '[' || 'MTO_CHEQUE' ||'~'||ltrim(to_char(sal_che_otr_bco * -1))|| ']'
             into v_det_campos
             from cj_controles
            where nro_caja = to_number(p_nro_caja)
              and cod_moneda = p_cod_moneda
              and fecha = v_fec_caja;
         exception
            when no_data_found then
               v_cod_respuesta := '002';
               v_msj_respuesta := 'No existe control de Caja para '||p_cod_moneda;
            when others then
               v_cod_respuesta := '003';
               v_msj_respuesta := sqlerrm;
         end;
      end if;
 end if;
 /* armo finalmente el mensaje de respuesta */
  v_msj_salida := p_nro_operacion||'~'||
                  v_cod_respuesta||'~'||
                  v_msj_respuesta||'~'||
                  ltrim(to_char(v_can_campos,'000'))||'~'||
                  v_det_campos;

  return(v_msj_salida);
exception
 when others then
     /* armo finalmente el mensaje de respuesta */
     v_msj_salida := p_nro_operacion||'~'||
                     '999'||'~'||
                     sqlerrm||'~'||
                     ltrim(to_char(v_can_campos,'000'))||'~'||
                     v_det_campos;
     return(v_msj_salida);
end FUJ_VAL_TRANSACCION_240;
/

