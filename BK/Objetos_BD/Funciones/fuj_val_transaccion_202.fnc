CREATE OR REPLACE FUNCTION IT.FUJ_VAL_TRANSACCION_202 (
      p_nro_operacion in varchar2,   -- Nro de referencia de la operacion
      p_nro_caja in varchar2,        -- Nro de Caja
      p_cod_moneda in varchar2,       -- Codigo de moneda
      p_sal_cajero in varchar2 default null)     -- Saldo del Cajero en efectivo
return VARCHAR2 is
  -- defino por defecto el modulo y modalidad a utilizar
  v_cod_modulo number(3) := 9;               -- Caja
  v_cod_modalidad number(3) := 91;           -- Caja
  v_cod_transaccion number(3) := 202;        -- Transaccion
  --
  v_cod_oficina number(3);                   -- oficina de la caja
  v_cod_usuario varchar2(10) := upper(user); -- usuario
  --
  v_estado            number(1);             -- estado de la caja
  v_fec_caja          date;                  -- fecha de la caja
  v_sal_actual        number(18,2);          -- saldo actual de la caja en efectivo
  v_sal_cheques        number(18,2);          -- saldo actual de la caja en cheques
  --
  v_msj_salida    varchar2(8000);            -- mensaje final retornado
  v_cod_respuesta varchar2(03) := '000';     -- sin errores
  v_msj_respuesta varchar2(100) := 'OK';     -- MENSAJE sin errores
  -- detalle de campos. Por defecto van los campos en blanco
  v_can_campos    number(3) := 11;        -- cantidad de campos
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
              '[' || 'SAL_CAJERO'     ||'~ ]' ||
              '[' || 'CHE_DET_NBC'    ||'~ ]' ||
              '[' || 'CHE_DIF_NBC'    ||'~ ]' ||
              '[' || 'CHE_ING_NBC'    ||'~ ]';
  v_can_pendientes number;
  v_can_reversar   number;
  v_can_caja       number;
  v_fecha          date;

begin
 -- Valido la moneda
 if p_cod_moneda is null then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese la moneda.';
 else
    -- Valido la moneda ingresada
    prj_val_moneda(p_cod_moneda, v_cod_respuesta,v_msj_respuesta);
 end if;
  -- Ajuste JIRA 3389 --
  -- Para obtener fecha de Caja
  begin
    select FECHA
       into v_fecha
       from CJ_CONTROLES B
      where B.NRO_CAJA   = p_nro_caja
        and B.COD_MONEDA = p_cod_moneda
        and B.FECHA <= pag_cal.FU_OBT_FEC_ACTUAL(9)
        and b.estado <> 2
     order by FECHA desc;
  exception
    when others then
       v_cod_respuesta := '007';
       v_msj_respuesta := sqlerrm;
  end;

  begin
    select COUNT(1)
      into v_can_pendientes
      from ge_mov_autorizaciones g, ge_movimientos m
     where g.fecha = v_fecha
       and g.fecha = m.fecha
       and g.hora  = m.hora
       and g.cod_usuario = m.cod_usuario
       and g.cod_tra_padre = m.cod_tra_padre
       and g.cod_mod_padre = m.cod_mod_padre
       and g.cod_mad_padre = m.cod_mad_padre
       and m.nro_caja = p_nro_caja
       and g.estado = 'S';
  exception
    when others then
       v_cod_respuesta := '008';
       v_msj_respuesta := sqlerrm;
  end;
  begin
    select COUNT(1)
      into v_can_reversar
      from ge_aut_reversiones g, ge_movimientos m
     where g.fecha = v_fecha
       and g.fecha = m.fecha
       and g.hora  = m.hora
       and g.cod_usuario = m.cod_usuario
       and g.cod_tra_padre = m.cod_tra_padre
       and g.cod_mod_padre = m.cod_mod_padre
       and g.cod_mad_padre = m.cod_mad_padre
       and m.nro_caja = p_nro_caja
       and g.estado = 'S';
  exception
    when others then
       v_cod_respuesta := '009';
       v_msj_respuesta := sqlerrm;
  end;
  begin
    select COUNT(1)
      into v_can_caja
      from ge_aut_reversiones g, cj_movimientos m
     where g.fecha = v_fecha
       and g.fecha = m.fecha
       and g.hora  = m.hora
       and g.cod_usuario = m.cod_usuario
       and g.nro_documento = m.nro_documento
       and m.nro_caja = p_nro_caja
       and g.estado = 'S';
    exception
      when others then
         v_cod_respuesta := '010';
         v_msj_respuesta := sqlerrm;
    end;
    IF nvl(v_can_pendientes,0) + nvl(v_can_reversar,0) + nvl(v_can_caja,0) > 0 then
       v_cod_respuesta := '011'; -- error
       v_msj_respuesta := 'Existen movimientos Pendientes de Caja sin autorizar.';
    end if;

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
    elsif p_sal_cajero is not null and to_number(p_sal_cajero) <> v_sal_actual then
       v_cod_respuesta := '003'; -- error
       v_msj_respuesta := 'Saldo del Cajero no corresponde.';


/*    elsif p_sal_cajero is not null and to_number(p_sal_cajero) <> 0 then
       v_cod_respuesta := '003'; -- error
       v_msj_respuesta := 'No puede cerrar con Saldo su Caja.';  */
/*    elsif v_estado <> 4 then -- error no esta arqueada
       v_cod_respuesta := '004'; -- error
       v_msj_respuesta := 'Caja aun no fue arqueada en esta Moneda';
*/    else -- no tiene problemas para el cierre
       -- Armo los detalles de los campos: [NOM_CAMPO~VALOR~VALORES POSIBLES]
       begin
           select '[' || 'CAN_EGRESOS'    ||'~'||ltrim(to_char(can_creditos))|| ']' ||
                  '[' || 'CAN_INGRESOS'   ||'~'||ltrim(to_char(can_debitos))|| ']' ||
                  '[' || 'CHE_DETALLADOS' ||'~'||ltrim(to_char(det_che_otr_bco))|| ']' ||
                  '[' || 'CHE_DIFERENCIA' ||'~'||ltrim(to_char(tot_che_otr_bco-(det_che_otr_bco)))|| ']' ||
                  '[' || 'CHE_INGRESOS'   ||'~'||ltrim(to_char(tot_che_otr_bco))|| ']' ||
                  '[' || 'EFE_DIFERENCIA' ||'~'||ltrim(to_char(nvl(sal_actual,0)-sal_actual))|| ']' ||
                  '[' || 'EGR_EFECTIVO'   ||'~'||ltrim(to_char(tot_creditos))|| ']' ||
                  '[' || 'ING_EFECTIVO'   ||'~'||ltrim(to_char(tot_debitos))|| ']' ||
                  '[' || 'SAL_ANTERIOR'   ||'~'||ltrim(to_char(mto_apertura))|| ']' ||
                  '[' || 'SAL_EFECTIVO'   ||'~'||ltrim(to_char(sal_actual))|| ']' ||
                  '[' || 'SAL_ANT_CHE'   ||'~'||ltrim(to_char(ini_che_otr_bco))|| ']' ||
                  '[' || 'SAL_CHEQUES'   ||'~'||ltrim(to_char(sal_che_otr_bco))|| ']' ||
                  '[' || 'SAL_CAJERO'   ||'~'||ltrim(to_char(nvl(sal_actual,0)))|| ']' ||
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
             v_cod_respuesta := '005';
             v_msj_respuesta := 'No existe control de Caja para '||p_cod_moneda;
          when others then
             v_cod_respuesta := '006';
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
end FUJ_VAL_TRANSACCION_202;
/

