CREATE OR REPLACE FUNCTION IT.FUJ_VAL_TRANSACCION_203 (
      p_nro_operacion in varchar2,   -- Nro de referencia de la operacion
      p_nro_caja in varchar2,        -- Nro de Caja
      p_cod_moneda in varchar2,      -- Codigo de moneda
      p_sal_cajero in varchar2,      -- Saldo del Cajero en efectivo
      p_sal_cheques in varchar2 default null)     -- Saldo del Cajero en cheques
return VARCHAR2 is
  -- defino por defecto el modulo y modalidad a utilizar
  v_cod_modulo number(3) := 9;               -- Caja
  v_cod_modalidad number(3) := 91;           -- Caja
  v_cod_transaccion number(3) := 203;        -- Transaccion
  --
  v_cod_oficina number(3);                   -- oficina de la caja
  v_cod_usuario varchar2(10) := upper(user); -- usuario
  --
  v_estado            number(1);             -- estado de la caja
  v_fec_caja          date;                  -- fecha de la caja
  v_sal_actual        number(18,2);          -- saldo actual de la caja en efectivo
  v_sal_cheques        number(18,2);          -- saldo actual de la caja en cheques
  v_che_no_detallados  number(5) := 0;
  --
  v_msj_salida    varchar2(8000);            -- mensaje final retornado
  v_cod_respuesta varchar2(03) := '000';     -- sin errores
  v_msj_respuesta varchar2(100) := 'OK';     -- MENSAJE sin errores
  -- detalle de campos. Por defecto van los campos en blanco
  v_can_campos    number(3) := 10;        -- cantidad de campos
  v_det_campos    varchar2(8000) :=       -- valor por defecto
              '[' || 'CAN_EGRESOS'    ||'~ ]' ||
              '[' || 'CAN_INGRESOS'   ||'~ ]' ||
              '[' || 'CHE_DETALLADOS' ||'~ ]' ||
              '[' || 'CHE_DIFERENCIA' ||'~ ]' ||
              '[' || 'CHE_INGRESOS'   ||'~ ]' ||
              '[' || 'EFE_DIFERENCIA' ||'~ ]' ||
              '[' || 'EGR_EFECTIVO'   ||'~ ]' ||
              '[' || 'ING_EFECTIVO'   ||'~ ]' ||
              '[' || 'SAL_ANTERIOR'   ||'~ ]' ||
              '[' || 'SAL_EFECTIVO'   ||'~ ]' ||
              '[' || 'SAL_ANT_CHE'    ||'~ ]' ||
              '[' || 'SAL_CHEQUES'    ||'~ ]' ||
              '[' || 'DIF_CHEQUES'    ||'~ ]' ||
              '[' || 'CHE_ING_NBC'    ||'~ ]' ||
              '[' || 'CHE_DET_NBC'    ||'~ ]' ||
              '[' || 'CHE_DIF_NBC'    ||'~ ]' ;

begin
 -- Valido la moneda y el monto actual en caja
 if p_cod_moneda is null then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese la moneda a arquear.';
 elsif p_sal_cajero is null then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese Saldo Actual en Efectivo.';
/* elsif p_sal_cheques is null then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese Saldo Actual en Cheques.';
*/ else
    -- Valido la moneda ingresada
    prj_val_moneda(p_cod_moneda, v_cod_respuesta,v_msj_respuesta);
 end if;
 if v_cod_respuesta = '000' then -- no hubo errores
     -- Valido que se hayan detallado todos los cheques
     Begin
        select COUNT(*)
          into v_che_no_detallados
          from cj_movimientos
         where tip_monto in ('C', 'O', 'T')
           and cod_tra_padre in (352,372)
           and nro_caja = to_number(p_nro_caja)
           and cod_moneda = p_cod_moneda
           and estado = 'N'
           and nvl(tot_detallado,0) != nvl(monto,0);
        If v_che_no_detallados != 0 Then
           v_cod_respuesta := '002';
           v_msj_respuesta := 'Error: No se han detallado todos los depósitos.';
        End If;
     End;
 End If;
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
           select '[' || 'CAN_EGRESOS'    ||'~'||ltrim(to_char(can_creditos))|| ']' ||
                  '[' || 'CAN_INGRESOS'   ||'~'||ltrim(to_char(can_debitos))|| ']' ||
                  '[' || 'CHE_DETALLADOS' ||'~'||ltrim(to_char(det_che_otr_bco))|| ']' ||
                  '[' || 'CHE_DIFERENCIA' ||'~'||ltrim(to_char(tot_che_otr_bco-(det_che_otr_bco)))|| ']' ||
                  '[' || 'CHE_INGRESOS'   ||'~'||ltrim(to_char(tot_che_otr_bco))|| ']' ||
                  '[' || 'EFE_DIFERENCIA' ||'~'||ltrim(to_char(to_number(p_sal_cajero)-sal_actual))|| ']' ||
                  '[' || 'EGR_EFECTIVO'   ||'~'||ltrim(to_char(tot_creditos))|| ']' ||
                  '[' || 'ING_EFECTIVO'   ||'~'||ltrim(to_char(tot_debitos))|| ']' ||
                  '[' || 'SAL_ANTERIOR'   ||'~'||ltrim(to_char(mto_apertura))|| ']' ||
                  '[' || 'SAL_EFECTIVO'   ||'~'||ltrim(to_char(sal_actual))|| ']' ||
                  '[' || 'SAL_ANT_CHE'   ||'~'||ltrim(to_char(ini_che_otr_bco))|| ']' ||
                  '[' || 'SAL_CHEQUES'   ||'~'||ltrim(to_char(sal_che_otr_bco))|| ']' ||
                  '[' || 'DIF_CHEQUES' ||'~'||ltrim(to_char(to_number(p_sal_cheques)-sal_che_otr_bco))|| ']'||
                  '[' || 'CHE_DET_NBC' ||'~'||ltrim(to_char(det_che_nue_bco))|| ']' ||
                  '[' || 'CHE_DIF_NBC' ||'~'||ltrim(to_char(tot_che_nue_bco-(det_che_nue_bco)))|| ']' ||
                  '[' || 'CHE_ING_NBC'   ||'~'||ltrim(to_char(tot_che_nue_bco))|| ']'

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
end FUJ_VAL_TRANSACCION_203;
/

