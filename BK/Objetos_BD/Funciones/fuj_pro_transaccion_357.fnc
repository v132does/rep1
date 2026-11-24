CREATE OR REPLACE FUNCTION IT.FUJ_PRO_TRANSACCION_357 (
      p_nro_operacion in varchar2,   -- Nro de referencia de la operacion
      p_nro_caja in varchar2,        -- Nro de Caja
      p_cod_modalidad   in varchar2, -- Modalidad de Ahorro
      p_serie           in varchar2, -- Nro de serie del CDA
      p_nro_certificado in varchar2, -- Nro del certificado
      p_cod_moneda      in varchar2 default null,  -- moneda
      p_nro_cupon       in varchar2, -- Nro del cupon
      p_imp_pagar in varchar2 default null,
      P_importe in varchar2 default null)         -- Importe del cupon
return VARCHAR2 is
  -- defino por defecto el modulo y modalidad a utilizar
  v_cod_modulo number(3)      := 9;    -- Caja
  v_cod_modalidad number(3)   := 91;   -- Caja
  v_cod_transaccion number(4) := 357;  -- transaccion
  v_cod_usuario varchar2(10) := upper(user); --usuario
  -- Datos de la caja
  v_fec_actual        date := pag_cal.fu_obt_fec_actual(v_cod_modulo); -- fecha de hoy
  v_hor_actual        varchar2(08) := to_char(sysdate,'HH24:MI:SS');   -- Hora actual
  v_cod_oficina       number(3);         -- Codigo de oficina
  v_estado            number(1);         -- estado de la caja
  v_fec_caja          date;              -- fecha de la caja
  v_sal_actual        number(18,2);      -- saldo actual de la caja en efectivo
  v_sal_cheques       number(18,2);      -- saldo actual de la caja en cheques
  -- Datos de la cuenta
  v_nro_cuenta        varchar2(20);      -- numero de cuenta
  v_fec_vencimiento   varchar2(10);      -- Fecha de vencto. en formato char
  v_cod_moneda        varchar2(3);       -- moneda de la cuenta
  v_est_cuenta        varchar2(1);       -- estado de la cuenta
  v_est_certificado   varchar2(1);       -- estado del certificado
  v_tip_cuenta        number(3);         -- tipo de cuenta(modalidad)
  v_capital           number(18,2);      -- capital de la cuenta
  v_sal_disponible    number(18,2);      -- saldo disponible
  v_mto_interes       number(18,2);      -- Monto del Interes
  v_est_cupon         varchar2(1);       -- estado del cupon
  v_bloqueado         varchar2(1);       -- indica si el cupon esta bloqueado
  -- Datos de salida
  v_msj_salida    varchar2(4000);        -- mensaje final retornado
  v_cod_respuesta varchar2(03) := '000'; -- sin errores
  v_msj_respuesta varchar2(4000) := 'Operacion Confirmada'; -- sin errores
  -- datos de la operacion convertidos
  v_tipo          varchar2(01) := 'C';  -- credito para la caja (egreso)
  v_tip_monto     varchar2(01) := 'E';  -- efectivo
  v_importe       number := to_number(p_importe); -- importe de la extraccion
  v_nro_secuencia number(3) := 0;  -- secuencia del mov.
  v_mto_retencion   ge_movimientos.monto%type := 0;
  v_cod_mod_retencion number(3) := 3;    -- Caja
  v_cod_mad_retencion number(3) := 33;   -- Caja
  v_cod_tra_retencion number(4) := 9603;  -- transaccion
  v_mto_a_pagar       number := to_number(p_imp_pagar); -- Monto Real a Pagar (con retencion)
  v_mto_cal_pagar     number; -- Monto Calculado a Pagar
  v_mto_ret_calculado number; -- importe retencion calculado
  --
  -- Procedimiento interno para generar movimiento y act. de control de caja
  procedure lp_gen_transaccion(p_tip_movimiento varchar2)  is
  
  begin
    if p_tip_movimiento = 'P' then
      -- Actualizo el control de caja
      update cj_controles
         set sal_actual = nvl(sal_actual,0) - nvl(v_importe,0),
             tot_creditos = nvl(tot_creditos,0) + nvl(v_importe,0),
             can_creditos = nvl(can_creditos,0) + 1,
             estado = 1 -- abierto
       where nro_caja = to_number(p_nro_caja)
         and cod_moneda = v_cod_moneda
         and fecha = v_fec_caja;
      -- genero el movimiento por la extraccion
      insert into cj_movimientos
         (fecha, hora, cod_usuario, nro_secuencia,
          cod_tra_padre, cod_mod_padre, cod_mad_padre,
          cod_oficina, cod_moneda, nro_caja,
          nro_documento, nro_cuenta, monto, tip_monto, tipo, nro_ref_externo) --> CRO-FACPOD: Para Almacenar la respuesta de la Aplicación Externa.-
      values
         (v_fec_actual, v_hor_actual, v_cod_usuario, 1,
          v_cod_transaccion, v_cod_modulo, v_cod_modalidad,
          v_cod_oficina, v_cod_moneda, to_number(p_nro_caja),
          p_nro_cupon, v_nro_cuenta, v_importe,v_tip_monto /* efectivo */, v_tipo, /* es debito */
          p_nro_operacion);
    else 
      -- Actualizo el control de caja
      update cj_controles
         set sal_actual = nvl(sal_actual,0) + nvl(v_mto_retencion,0),
             tot_debitos = nvl(tot_debitos,0) + nvl(v_mto_retencion,0),
             can_debitos = nvl(can_debitos,0) + 1,
             estado = 1 -- abierto
       where nro_caja = to_number(p_nro_caja)
         and cod_moneda = v_cod_moneda
         and fecha = v_fec_caja;
      -- genero el movimiento por la extraccion
      insert into cj_movimientos
         (fecha, hora, cod_usuario, nro_secuencia,
          cod_tra_padre, cod_mod_padre, cod_mad_padre,
          cod_oficina, cod_moneda, nro_caja,
          nro_documento, nro_cuenta, monto, tip_monto, tipo, nro_ref_externo) --> CRO-FACPOD: Para Almacenar la respuesta de la Aplicación Externa.-
      values
         (v_fec_actual, v_hor_actual, v_cod_usuario, 2,
          v_cod_transaccion, v_cod_modulo, v_cod_modalidad,
          v_cod_oficina, v_cod_moneda, to_number(p_nro_caja),
          p_nro_cupon, v_nro_cuenta, v_mto_retencion, 'E'/*v_tip_monto*/ /* efectivo */, 'D'/*v_tipo*/, /* es debito */
          p_nro_operacion);
    end if;
  end lp_gen_transaccion;
  --
begin
 -- Inicializacion de la aplicacion y el modulo
 BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=v_cod_modulo; END;
 -- DYDMR-1780 - ITGF - Pago de Cupones - Tasa Fuera de Rango de Pizzarra SC 15120 - EGC19052015
 PAE_CNF.G_PROGRAMA := 'FUJ_PRO_TRANSACCION_357';
 -- Valido la moneda
 if p_cod_modalidad is null then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese la Modalidad.';
 elsif p_nro_cupon is null then
    v_cod_respuesta := '002'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el Nro. de Cupon.';
 elsif p_serie is null then  -- valido la serie
    v_cod_respuesta := '003'; -- error
    v_msj_respuesta := 'ERROR: Ingrese la Serie del Certificado.';
 elsif p_nro_certificado is null then  -- valido el nro de certificado
    v_cod_respuesta := '004'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el Numero del Certificado.';
 elsif v_importe <= 0 then
    v_cod_respuesta := '005'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el importe correcto del Cupon.';
 else
    -- obtengo datos de la cuenta  ------------------------------------------
    begin
      Select nro_cuenta, cod_moneda, estado, cod_modalidad,
             to_char(fec_vencimiento,'dd/mm/yyyy'),
             est_certificado,capital,
             nvl(sal_total,0)-nvl(sal_retenido,0)-nvl(sal_bloqueado,0)
        into v_nro_cuenta, v_cod_moneda, v_est_cuenta,
             v_tip_cuenta, v_fec_vencimiento,
             v_est_certificado,v_capital, v_sal_disponible
        from ah_cta_certificados
       where serie = p_serie
         and cod_modalidad = p_cod_modalidad
         and nro_certificado = to_number(p_nro_certificado)
         and cod_moneda = nvl(p_cod_moneda, cod_moneda)
         and estado not in ('A', 'T');
      if v_est_cuenta in ('A','T','C','D') then
        v_cod_respuesta := '003';
        v_msj_respuesta := 'ERROR: Cuenta no esta activa. Verifique!';
      else
        -- Verifico los datos del cupon
        begin
           select estado, to_char(fec_vencimiento,'dd/mm/yyyy'), mto_interes,bloqueado
             into v_est_cupon, v_fec_vencimiento, v_mto_interes, v_bloqueado
             from ah_cupones a
            where a.nro_cuenta = v_nro_cuenta
              and a.nro_cupon = to_number(p_nro_cupon);
           -- veo si vino nulo el campo importe es porque es solo desplegable
           if p_importe is null then
              v_importe := v_mto_interes;
           end if;
           if v_bloqueado = 'S' then
              v_cod_respuesta := '002';
              v_msj_respuesta := 'ERROR: Nro de Cupon esta bloqueado!';
           end if;
           if v_est_cupon = 'P' THEN
              v_cod_respuesta := '002';
              v_msj_respuesta := 'ERROR: Nro.de Cupon ya ha sido pagado!';
           elsif v_est_cupon <> 'V' then
              v_cod_respuesta := '002';
              v_msj_respuesta := 'ERROR: Nro de Cupon no esta vencido!';
           /*elsif v_importe <> v_mto_interes then -- Modificado para que permita pagos parciales en CDA
              v_cod_respuesta := '003';
              v_msj_respuesta := 'ERROR: El Importe del Documento no corresponde.';*/
           end if;

        exception
          when no_data_found then
            v_cod_respuesta := '002';
            v_msj_respuesta := 'ERROR: Nro de Cupon no existe para este Documento!';
          when others then
            v_cod_respuesta := '003';
            v_msj_respuesta := sqlerrm;
        end;
        if v_cod_respuesta = '000' then
          -- Verifico la duplicacion del registro
          prj_val_duplicacion(p_nro_caja,
                              v_cod_transaccion,
                              v_cod_moneda,
                              p_nro_cupon,
                              v_cod_respuesta,
                              v_msj_respuesta);
          if v_cod_respuesta = '000' then
             v_msj_respuesta := fuj_ver_impedimentos(v_nro_cuenta,
                                                     v_tip_cuenta,
                                                     v_cod_transaccion,
                                                     v_est_cuenta,
                                                     'D'); -- 'D'== DEBITO EN CUENTA
             if v_msj_respuesta is not null then
                v_cod_respuesta := '004';  -- la cuenta tiene impedimentos
             end if;
          end if;
        end if;
      end if;
    exception
      when no_data_found then
        v_cod_respuesta := '002';
        v_msj_respuesta := 'ERROR: Nro de Documento no existe!';
      when others then
        v_cod_respuesta := '003';
        v_msj_respuesta := 'ERROR' || sqlerrm;
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
       elsif v_sal_actual < v_importe then
          v_cod_respuesta := '006'; -- error
          v_msj_respuesta := 'Caja no tiene saldo para esta Operacion';
       end if;
    end if;
  if v_cod_respuesta = '000' then
     v_mto_ret_calculado := paa_ret.fu_obt_inr_ret_cda(v_nro_cuenta,
                                                       p_cod_modalidad,
                                                       p_serie,
                                                       p_nro_certificado,
                                                       p_cod_moneda,
                                                       p_nro_cupon,
                                                       v_fec_caja);   

     v_mto_cal_pagar := nvl(v_importe,0) - nvl(v_mto_ret_calculado,0);
     
     If v_mto_a_pagar <>  v_mto_cal_pagar then
       v_cod_respuesta := '006';
       v_msj_respuesta := 'Operación tiene retención, favor corrija monto a Pagar :'||v_mto_cal_pagar;
     end if;

  end if;

  if v_cod_respuesta = '000' then
       -- verifico los decimales del importe
       v_msj_respuesta := fuj_val_importe(v_tipo, v_tip_monto,v_cod_moneda,v_importe);
       if v_msj_respuesta is not null then
          v_cod_respuesta := '005';  -- error
       else
          -- Asigno el nro de caja a los movimientos
          pag_cta.pr_nro_caja(to_number(p_nro_caja));
          -- Actualiza la operacion en la base
          pag_cta.pr_act_operacion(v_nro_cuenta,
                                   v_hor_actual,
                                   'D', -- debito a la cuenta del cliente
                                   v_cod_moneda,
                                   v_importe,
                                   v_cod_transaccion,
                                   591, -- trans. hijo
                                   p_nro_cupon,
                                   null, -- cotizacion
                                   v_cod_oficina,
                                   v_cod_modulo,
                                   v_cod_modalidad,
                                   null, -- tasa
                                   null, -- valor de tasa
                                   'Pago de Cupon', --concepto
                                   'N', -- emitir aviso
                                   v_nro_secuencia, -- nro de secuencia
                                   v_fec_actual);
          if pag_cta.g_cod_error <> 0 then
             -- actualizacion con problemas
             v_cod_respuesta := ltrim(to_char(pag_cta.g_cod_error,'000'));
             v_msj_respuesta := pag_cta.g_msj_error;
          else -- genero la transaccion en caja
             lp_gen_transaccion('P');
          end if;
       end if;
    end if;
 end if;

  --generación de retencion: IMPUESTO NO RESIDENTES
  -- Se retira el llamado al procedimiento @tcasco PBC-125 - FSOP-36667
  /*paa_ret.pr_gen_inr_ret_cda(v_fec_caja, 
                             v_nro_cuenta,  
                             v_cod_transaccion, 
                             v_cod_modulo,
                             v_cod_modalidad,
                             591 ,
                             v_hor_actual ,
                             v_nro_secuencia, 
                             v_mto_retencion);*/

  if v_mto_retencion > 0 then
     lp_gen_transaccion('R');
  end if;
-- mensaje final sino hubo errores
 if v_cod_respuesta = '000' and v_mto_retencion <> 0 then -- sino hubo problemas, se carga mensaje por defecto
      v_cod_respuesta := 'IMP';
      v_msj_respuesta := 'Operacion confirmada. Comprobante ha sido impreso'||'~'||
      fuj_imp_comprobante_357(v_nro_cuenta,
                              v_fec_caja,
                              v_hor_actual,
                              v_cod_usuario);

 end if;
 /* falta armar el mensaje de respuesta */
 v_msj_salida := p_nro_operacion||'~'||
                 v_cod_respuesta||'~'||
                 nvl(v_msj_respuesta,'Operacion confirmada');
                 
                 
                 
 return(v_msj_salida);

exception
 when others then
     /* armo finalmente el mensaje de respuesta */
     v_msj_salida := p_nro_operacion||'~'||
                     '999'||'~'||
                     sqlerrm;
     return(v_msj_salida);
end FUJ_PRO_TRANSACCION_357;
/
