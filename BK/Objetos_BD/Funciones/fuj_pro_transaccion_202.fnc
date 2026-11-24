CREATE OR REPLACE FUNCTION IT.FUJ_PRO_TRANSACCION_202 (
      p_nro_operacion in varchar2,   -- Nro de referencia de la operacion
      p_nro_caja in varchar2,        -- Nro de Caja
      p_cod_moneda in varchar2,      -- Moneda de cierre
      p_sal_cajero in varchar2)      -- Saldo del Cajero en efectivo
return VARCHAR2 is
  -- defino por defecto el modulo y modalidad a utilizar
  v_cod_modulo number(3) := 9;               -- Caja
  v_cod_modalidad number(3) := 91;           -- Caja
  v_cod_transaccion number(3) := 202;        -- Transaccion
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
  v_sal_cajero         number(18,2) := to_number(p_sal_cajero); -- saldo del cajero
  --
  v_msj_salida    varchar2(8000);            -- mensaje final retornado
  v_cod_respuesta varchar2(03) := '000';     -- sin errores
  v_msj_respuesta varchar2(100) := 'Operacion confirmada'; -- sin errores
  v_pendiente     varchar2(1);
  v_pendiente_dos varchar2(1) ;
  v_can_aut_pendientes number := 0;
  -- Procedimiento interno para generar movimiento de cierre
  procedure lp_gen_transaccion  is
  begin
      -- Actualizo como cerrada la caja
      update cj_controles
         set estado = 2,  -- cerrado
             mto_cierre = v_sal_cajero
       where nro_caja = to_number(p_nro_caja)
         and cod_moneda = p_cod_moneda
         and fecha = v_fec_caja;
      -- genero el movimiento por el efectivo
      insert into cj_movimientos
         (fecha, hora, cod_usuario, nro_secuencia,
          cod_tra_padre, cod_mod_padre, cod_mad_padre,
          cod_oficina, cod_moneda, nro_caja,
          monto, tip_monto, tipo)
      values
         (v_fec_actual, v_hor_actual, v_cod_usuario, 1,
          v_cod_transaccion, v_cod_modulo, v_cod_modalidad,
          v_cod_oficina, p_cod_moneda, to_number(p_nro_caja),
          to_number(v_sal_cajero),'E' /* efectivo */, 'N'); /* no es debito ni credito */
      -- genero el movimiento por cheques
      if v_sal_cheques <> 0 then
        insert into cj_movimientos
           (fecha, hora, cod_usuario, nro_secuencia,
            cod_tra_padre, cod_mod_padre, cod_mad_padre,
            cod_oficina, cod_moneda, nro_caja,
            monto, tip_monto, tipo)
        values
           (v_fec_actual, v_hor_actual, v_cod_usuario, 2,
            v_cod_transaccion, v_cod_modulo, v_cod_modalidad,
            v_cod_oficina, p_cod_moneda, to_number(p_nro_caja),
            to_number(v_sal_cheques),'O' /* cheq otr/bcos */, 'N'); /* no es debito ni credito */
      end if;

  end lp_gen_transaccion;
begin
 -- Inicializacion de la aplicacion y el modulo
 BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=v_cod_modulo; END;
 -- Valido la moneda y el monto de cierre
 if p_cod_moneda is null then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese la moneda.';
 elsif p_sal_cajero is null then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese Saldo Actual en Efectivo.';
 else
    -- Valido la moneda ingresada
    prj_val_moneda(p_cod_moneda, v_cod_respuesta,v_msj_respuesta);
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

     if fuj_obt_tip_caja(p_nro_caja) = 'P' then
        -- Para cajas de tipo prosegur verifica si existen Movimientos en Transito pendientes de Aprobación.
        begin
          select distinct 'S'
            into v_pendiente
            from cj_val_transito
           where estado = 'X'
             and cod_moneda = p_cod_moneda
             and nro_caj_afecta = p_nro_caja; -- Número de Caja 31 es caja Prosegur. Desde esa caja se hacen las Aprobaciones.
        exception
          when no_data_found then
            v_pendiente := 'N';
          when others then
            v_cod_respuesta := '002';
            v_msj_respuesta := 'ERROR: al buscar Valores en Tránsito. '||sqlerrm;
        end;
     elsif fuj_obt_tip_caja(p_nro_caja) = 'S' then
        -- Para cajas del tipo Autoservicios verifica que no tenga saldo al cierre.
        If v_sal_actual > 0 then
           v_cod_respuesta := '002';
           v_msj_respuesta := 'ERROR: Caja de Autoservicios no puede quedar con saldo al Cierre.';
        End if;
     else
        --Las cajas que no son de Tipo Prosegur tampoco pueden cerrar si existen Movimientos en transito pendientes de Aprobación
        begin
          select distinct 'S'
            into v_pendiente
            from cj_val_transito
           where estado = 'X'
             and cod_moneda = p_cod_moneda
             and nro_caja = p_nro_caja;
        exception
          when no_data_found then
            v_pendiente := 'N';
          when others then
            v_cod_respuesta := '002';
            v_msj_respuesta := 'ERROR: al buscar Valores en Tránsito. '||sqlerrm;
        end;
        -- BSEVOCORE-771 PARAMETRIZAR CONTROL TRANSACCIONES 204 Y 212 (JSS)
        begin
          select distinct 'S'
            into v_pendiente_dos
            from cj_val_transito
           where estado = 'N' --Enviado
             and cod_moneda = p_cod_moneda
             and nro_caj_proceso = p_nro_caja;
        exception
          when no_data_found then
            v_pendiente_dos := 'N';
          when others then
            v_cod_respuesta := '002';
            v_msj_respuesta := 'ERROR: al buscar Valores en Tránsito. '||sqlerrm;
        end; -- FIN BSEVOCORE -771
     end if;
     --
     if v_cod_respuesta = '000' then -- no hubo errores
        select count(*)
          into v_can_aut_pendientes
          from ge_movimientos
         where nro_caja = to_number(p_nro_caja)
           and (cod_usuario = v_cod_usuario or fuj_obt_tip_caja(p_nro_caja) = 'P')
           and estado = 'X'
           and reversado = 'N'
           and cod_tra_padre <> 355;-- CROAPARS-1 No incluir los pedidos de autorización por sobregiro 05/2015 V.V. 
     end if;
     -- busco el monto de cierre ------------------------------------------
     if v_estado = -1 then
        v_cod_respuesta := '006'; -- error, no existe registro de caja
        v_msj_respuesta := 'Caja inexistente!!';
     elsif v_estado in (0,2) then  -- error, la caja no esta abierta
        v_cod_respuesta := '003'; -- error
        v_msj_respuesta := 'Caja aun no fue abierta en esta Moneda';
  /*    elsif v_estado <> 4 then -- error no esta arqueada
         v_cod_respuesta := '004'; -- error
         v_msj_respuesta := 'Caja aun no fue arqueada en esta Moneda';
  */ elsif v_sal_cajero <> v_sal_actual then
        v_cod_respuesta := '005'; -- error
        v_msj_respuesta := 'Monto del cierre no coincide con el Saldo Actual.';
  /*    elsif v_sal_cajero <> 0 then
         v_cod_respuesta := '005'; -- error
         v_msj_respuesta := 'No puede cerrar con Saldo su Caja.'; */
     elsif nvl(v_pendiente,'N') = 'S' then
        v_cod_respuesta := '006'; -- error
        v_msj_respuesta := 'ERROR: Existen Valores en Tránsito Pendientes de Aprobación.';
     elsif nvl(v_pendiente_dos,'N') = 'S' then
        v_cod_respuesta := '006'; -- error
        v_msj_respuesta := 'ERROR: Existen Valores de la Transaccion 204 Pendientes de Aprobación.';
     elsif v_can_aut_pendientes > 0 then
        v_cod_respuesta := '007'; -- error
        v_msj_respuesta := 'ERROR: Tiene Autorizaciones Solicitadas pendientes de Autorizacion.';
     else -- no tiene problemas para el cierre
         declare
            v_dif_che_nue number;
            v_dif_che_otr number;
         begin
           select nvl(tot_che_nue_bco,0) - nvl(det_che_nue_bco,0),
                  nvl(tot_che_otr_bco,0) - nvl(det_che_otr_bco,0)
             into v_dif_che_nue, v_dif_che_otr
             from cj_controles
           where nro_caja = to_number(p_nro_caja)
             and cod_moneda = p_cod_moneda
             and fecha = v_fec_caja;
           if v_dif_che_nue <> 0 or v_dif_che_otr <> 0 then
              v_cod_respuesta := '005'; -- error
              v_msj_respuesta := 'Cheques deben ser totalmente detallados';
           end if;
         exception
            when others then
               v_cod_respuesta := '005'; -- error
               v_msj_respuesta := 'Error al buscar datos de la Caja '||sqlerrm;
         end;
         if v_cod_respuesta = '000' then -- no hubo errores
            -- procedo a realizar el cierre
            lp_gen_transaccion();
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
end FUJ_PRO_TRANSACCION_202;
/

