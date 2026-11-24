create or replace function it.FUJ_PRO_TRANSACCION_203(
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
  v_fec_actual        date := pag_cal.fu_obt_fec_actual(v_cod_modulo); -- fecha de hoy
  v_hor_actual        varchar2(08) := to_char(sysdate,'HH24:MI:SS');   -- Hora actual
  v_estado            number(1);             -- estado de la caja
  v_fec_caja          date;                  -- fecha de la caja
  v_sal_actual        number(18,2);          -- saldo actual de la caja en efectivo
  v_sal_cheques        number(18,2);         -- saldo actual de la caja en cheques
  --
  v_msj_salida    varchar2(8000);            -- mensaje final retornado
  v_cod_respuesta varchar2(03) := '000';     -- sin errores
  v_msj_respuesta varchar2(100) := 'Operacion confirmada'; -- sin errores
  -- Procedimiento interno para generar movimiento de apertura
  procedure lp_gen_transaccion  is
  begin
      -- Actualizo como arqueada la caja
      update cj_controles 
         set estado = 4,  -- con arqueo
             mto_cierre = to_number(p_sal_cajero),
             cod_usu_actual = v_cod_usuario
       where nro_caja = to_number(p_nro_caja)
         and cod_moneda = p_cod_moneda
         and fecha = v_fec_caja;
      -- genero el movimiento por arqueo
      insert into cj_movimientos
         (fecha, hora, cod_usuario, nro_secuencia, 
          cod_tra_padre, cod_mod_padre, cod_mad_padre, 
          cod_oficina, cod_moneda, nro_caja, 
          monto, tip_monto, tipo)
      values
         (v_fec_actual, v_hor_actual, v_cod_usuario, 1,
          v_cod_transaccion, v_cod_modulo, v_cod_modalidad, 
          v_cod_oficina, p_cod_moneda, to_number(p_nro_caja),
          to_number(p_sal_cajero),'E' /* efectivo */, 'N'); /* no es debito ni credito */
      -- genero el movimiento por arqueo
      if p_sal_cheques is not null then
      insert into cj_movimientos
         (fecha, hora, cod_usuario, nro_secuencia, 
          cod_tra_padre, cod_mod_padre, cod_mad_padre, 
          cod_oficina, cod_moneda, nro_caja, 
          monto, tip_monto, tipo)
      values
         (v_fec_actual, v_hor_actual, v_cod_usuario, 2,
          v_cod_transaccion, v_cod_modulo, v_cod_modalidad, 
          v_cod_oficina, p_cod_moneda, to_number(p_nro_caja),
          to_number(p_sal_cheques),'O' /* cheques */, 'N'); /* no es debito ni credito */
      end if;    
  end lp_gen_transaccion;
begin
 -- Inicializacion de la aplicacion y el modulo
 BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=v_cod_modulo; END;
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
 if v_cod_respuesta = '000' then -- sin errores 
    -- Obtengo los datos de la caja ---------------------------------------
    prj_obt_datos_caja(p_nro_caja,
                       p_cod_moneda,
                       v_cod_oficina,
                       v_fec_caja,
                       v_estado,
                       v_sal_actual,
                       v_sal_cheques);
    if v_estado = -1 then
       v_cod_respuesta := '006'; -- error, no existe registro de caja
       v_msj_respuesta := 'Caja inexistente!!';                         
    elsif v_estado in (0,2) then  -- error, la caja no esta abierta
       v_cod_respuesta := '003'; -- error
       v_msj_respuesta := 'Caja aun no fue abierta en esta Moneda';         
    elsif v_estado in (1,3,4) then -- caja 
       -- procedo a realizar el arqueo
       lp_gen_transaccion();
    end if;
 end if;                        
 /* armo finalmente el mensaje de respuesta */    
  v_msj_salida := p_nro_operacion||'~'||
                  v_cod_respuesta||'~'||
                  v_msj_respuesta;
  return(v_msj_salida);
exception
 when others then 
     /* armo finalmente el mensaje de respuesta */    
     v_msj_salida := p_nro_operacion||'~'||
                     '999'||'~'||
                     sqlerrm;
     return(v_msj_salida);
end FUJ_PRO_TRANSACCION_203;
/

