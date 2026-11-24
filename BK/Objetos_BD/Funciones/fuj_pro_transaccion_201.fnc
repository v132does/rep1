create or replace function it.FUJ_PRO_TRANSACCION_201(
      p_nro_operacion in varchar2,   -- Nro de referencia de la operacion
      p_nro_caja in varchar2,        -- Nro de Caja
      p_cod_moneda in varchar2,      -- Codigo de moneda
      p_mto_apertura in varchar2 default null,    -- Monto de apertura en efectivo
      p_mto_cheques  in varchar2 default null)    -- Monto inicial en cheques
return VARCHAR2 is
  -- defino por defecto el modulo y modalidad a utilizar
  v_cod_modulo number(3) := 9;               -- Caja
  v_cod_modalidad number(3) := 91;           -- Caja
  v_cod_transaccion number(3) := 201;        -- Transaccion de apertura
  --
  v_cod_oficina number(3);                   -- oficina de la caja
  v_cod_usuario varchar2(10) := upper(user); -- usuario
  --
  v_mto_max_permitido number(18,2);          -- monto maximo permitido
  v_fec_actual        date := pag_cal.fu_obt_fec_actual(v_cod_modulo); -- fecha de hoy
  v_hor_actual        varchar2(08) := to_char(sysdate,'HH24:MI:SS');   -- Hora actual
  v_estado            number(1);             -- estado de la caja
  v_fec_caja          date;                  -- fecha de la caja
  v_sal_actual        number(18,2);          -- saldo actual de la caja en efectivo
  v_sal_cheques        number(18,2);         -- saldo actual de la caja en cheques
  v_mto_apertura      number(18,2) := to_number(p_mto_apertura); 
  --
  v_msj_salida    varchar2(8000);            -- mensaje final retornado
  v_cod_respuesta varchar2(03) := '000';     -- sin errores
  v_msj_respuesta varchar2(100) := 'Operacion confirmada'; -- sin errores
  
  v_est_modulo    ba_modulos.estado%TYPE;
  -- Procedimiento interno para generar movimiento de apertura
  procedure lp_gen_transaccion(p_tipo in number)  is
  begin
  if p_tipo = 3 then -- re-apertura
      -- Actualizo nada mas la caja como reabierta
      update cj_controles 
         set estado = 3,  -- reabierta
             cod_usu_actual = v_cod_usuario
       where nro_caja = to_number(p_nro_caja)
         and cod_moneda = p_cod_moneda
         and fecha = v_fec_caja;
  else
      -- inserto registro para fecha de hoy
      insert into cj_controles
            (nro_caja, cod_moneda, fecha, 
             mto_apertura,
             sal_actual,
             ini_che_otr_bco, 
             sal_che_otr_bco,
             estado, 
             cod_usu_actual)
      values
            (p_nro_caja, p_cod_moneda, v_fec_actual,
             v_mto_apertura,
             v_mto_apertura,
             to_number(p_mto_cheques),
             to_number(p_mto_cheques),
             1, -- abierta
             v_cod_usuario);  
  end if;
  -- genero el movimiento de apertura por el efectivo
  insert into cj_movimientos
         (fecha, hora, cod_usuario, nro_secuencia, 
          cod_tra_padre, cod_mod_padre, cod_mad_padre, 
          cod_oficina, cod_moneda, nro_caja, 
          monto, tip_monto, tipo)
      values
         (v_fec_actual, v_hor_actual, v_cod_usuario, 1, -- 1=secuencia
          v_cod_transaccion, v_cod_modulo, v_cod_modalidad, 
          v_cod_oficina, p_cod_moneda, to_number(p_nro_caja),
          v_mto_apertura,'E' /* efectivo */, 'N'); /* no es debito */
  -- genero el movimiento de apertura por los cheques
/*  insert into cj_movimientos
         (fecha, hora, cod_usuario, nro_secuencia, 
          cod_tra_padre, cod_mod_padre, cod_mad_padre, 
          cod_oficina, cod_moneda, nro_caja, 
          monto, tip_monto, tipo)
      values
         (v_fec_actual, v_hor_actual, v_cod_usuario, 2, -- 2=secuencia
          v_cod_transaccion, v_cod_modulo, v_cod_modalidad, 
          v_cod_oficina, p_cod_moneda, to_number(p_nro_caja),*/
 --         to_number(p_mto_cheques),'O' /* cheques otros bcos */, 'N'); /* no es debito */          
  -- fin del proceso
  end lp_gen_transaccion;
begin
 -- Inicializacion de la aplicacion y el modulo
 BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=v_cod_modulo; END;
 
 v_est_modulo := PAE_CNF.FU_OBT_EST_MODULO(v_cod_modulo); --Estado Modulo
 -- Valido la moneda 
 if p_cod_moneda is null then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese la moneda.';
/* elsif p_mto_apertura is null then  -- Valido el monto de apertura en efectivo
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese Monto de Apertura en Efectivo.';
*//* elsif p_mto_cheques is null then  -- Valido el monto de apertura en cheques
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese Monto de Apertura en Cheques';    
*/ else   
    -- Valido la moneda ingresada
    prj_val_moneda(p_cod_moneda, v_cod_respuesta,v_msj_respuesta);
 end if;   
 if v_cod_respuesta = '000' then -- sin errores 
    -- obtengo el maximo monto permitido de operar para este usuario-------
    v_mto_max_permitido := fuj_obt_max_limite(v_cod_usuario, p_cod_moneda);  
    if v_mto_max_permitido < 0 then
       v_cod_respuesta := '002'; -- error
       v_msj_respuesta := 'Cajero no puede operar en esta moneda.';
    else
      --Validar estado del modulo
      IF v_est_modulo <> 2 THEN
        v_cod_respuesta := '004'; -- con error
        v_msj_respuesta := 'Cierre Operativo del dia anterior aun no ha finalizado. No se puede aperturar Caja.';
      END IF;   
      if v_cod_respuesta = '000' then
          -- Obtengo los datos de la caja ---------------------------------------
          prj_obt_datos_caja(p_nro_caja,
                             p_cod_moneda,
                             v_cod_oficina,
                             v_fec_caja,
                             v_estado,
                             v_sal_actual,
                             v_sal_cheques);
          -- para que tome el saldo anterior como monto de apertura                   
          v_mto_apertura := nvl(v_sal_actual,0);                         
          if v_estado = -1 then
              v_cod_respuesta := '006'; -- error, no existe registro de caja
              v_msj_respuesta := 'Caja inexistente!!';  
          elsif v_estado in (1,3,4) then  -- error, la caja ya esta abierta
             v_cod_respuesta := '003'; -- error
             v_msj_respuesta := 'Caja no puede ser abierta porque se halla';         
             if v_estado = 1 then
                v_msj_respuesta := v_msj_respuesta || ' abierta.';
             elsif v_estado = 3 then
                v_msj_respuesta := v_msj_respuesta || ' re-abierta.';
             elsif v_estado = 4 then
                v_msj_respuesta := v_msj_respuesta || ' arqueo.';
             end if;
          elsif v_estado = 2 then -- caja cerrada
           
             if nvl(v_sal_actual,0) <> v_mto_apertura then
                v_cod_respuesta := '004'; -- con error
                v_msj_respuesta := 'Monto de apertura en Efectivo no coincide con el Monto de Cierre.';
             /*elsif nvl(v_sal_cheques,0) <> nvl(to_number(p_mto_cheques),0) then
                v_cod_respuesta := '004'; -- con error
                v_msj_respuesta := 'Monto de apertura en Cheques no coincide con el Monto de Cierre.';
            */ else          
                if v_fec_caja = v_fec_actual then
                   -- re apertura de la caja
                   lp_gen_transaccion(3);         
                else
                   -- apertura normal de caja
                   lp_gen_transaccion(1);
               end if;
            end if;               
          elsif v_estado = 0 then -- sin ningun registro
            -- primera apertura de caja
            lp_gen_transaccion(1);
          end if;
      end if;

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
end FUJ_PRO_TRANSACCION_201;
/
