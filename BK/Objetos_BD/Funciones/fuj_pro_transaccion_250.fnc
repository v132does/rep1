create or replace function it.fuj_pro_transaccion_250(
      p_nro_operacion in varchar2,     -- Nro de referencia de la operacion
      p_nro_caja in varchar2,          -- Nro de Caja
      p_nro_boleta in varchar2 default null, -- Nro de la boleta
      --p_nombre in varchar2,            -- Nombre
      p_nro_documento in varchar2,     -- Nro de Documento
      p_nro_tarjeta  in varchar2,      -- Nro de cuenta del cliente
      p_tot_pago     in number,
      p_mto_efectivo in varchar2 default null, -- importe en efectivo
      p_che_ntr_bco in number default null, -- importe en cheque ntro bco
      p_tip_retencion in number default null,  --tipo de retencion
      p_mto_cheque in varchar2 default null -- importe en cheque
      )        -- Importe del deposito en cheques (plaza local)
return VARCHAR2 is
  -- defino por defecto el modulo y modalidad a utilizar
  v_cod_modulo number(3)      := 9;    -- Caja
  v_cod_modalidad number(3)   := 91;   -- Caja
  v_cod_transaccion number(4) := 250;  -- transaccion
  v_cod_usuario varchar2(10) := upper(user); --usuario
  -- Datos de la caja
  v_cod_mon_local     varchar2(4) := pag_gen.fu_obt_mon_local;
  v_fec_actual        date := pag_cal.fu_obt_fec_actual(v_cod_modulo); -- fecha de hoy
  v_hor_actual        varchar2(08) := to_char(sysdate,'HH24:MI:SS');   -- Hora actual
  v_cod_oficina       number(3);         -- Codigo de oficina
  v_estado            number(1);         -- estado de la caja
  v_fec_caja          date;              -- fecha de la caja
  v_sal_actual        number(18,2);          -- saldo actual de la caja en efectivo
  v_sal_cheques        number(18,2);          -- saldo actual de la caja en cheques
  -- Datos de la cuenta
  v_nro_cuenta        varchar2(15);      -- Numero de la cuenta
  v_denominacion      varchar2(200);     -- Nombre de la cuenta
  v_cod_moneda        varchar2(3);       -- moneda de la cuenta
  v_est_cuenta        varchar2(1);       -- estado de la cuenta
  v_tip_cuenta        number(3);         -- tipo de cuenta(modalidad)
  -- Datos de salida
  v_msj_salida    varchar2(8000);        -- mensaje final retornado
  v_cod_respuesta varchar2(03) := '000'; -- sin errores
  v_msj_respuesta varchar2(1000) := 'Operacion Confirmada'; -- sin errores
  -- datos de la operacion convertidos
  v_tipo          varchar2(01) := 'D';  -- Debito para la caja (ingreso)
  v_tip_monto     varchar2(01) := 'O';  -- Cheq. Otros Bancos
  v_mto_cheque       number := nvl(to_number(p_mto_cheque),0); -- importe del deposito en cheques
  v_mto_efectivo     number := nvl(to_number(p_mto_efectivo),0); -- importe del deposito en efectivo
  v_nro_secuencia number(3) := 0;  -- secuencia del mov.
  v_tot_cheques   number := nvl(v_mto_cheque,0);  -- total en cheques
  v_dia_mora number := 0;

  v_nro_boleta   number  := to_number(p_nro_boleta); --Numbero de boleta
  v_cod_persona  ba_personas.cod_persona%type; /**CROCLIJUD-5**/
  v_cod_cau_judicial	ge_causales.cod_causa%type := fug_obt_pardinamico('COD_CAU_DEM_JUDICIAL'); 

  --para la retención de cheques
  v_cod_tra_cheque       ge_movimientos.cod_transaccion%type;
         -- C.D. Fase III--
  v_tip_operacion  ge_mov_autorizaciones.tip_operacion%type := 'O';-- Todos Tipos Operacional
  v_est_movimiento ge_movimientos.estado%type;
  v_nro_pedido	   ge_mov_autorizaciones.nro_pedido%type;
  v_tot_monto      ge_movimientos.monto%type;
  v_est_cobro      ge_movimientos.estado%type;
  v_procesadora    ta_tipos.cod_ent_procesadora%TYPE;
  

  -- Procedimiento interno para generar movimiento y act. de control de caja
  procedure lp_gen_transaccion (p_estado varchar2) is
  begin
      -- Actualizo el control de caja
      if p_estado <> 'P' then
        update cj_controles
           set tot_che_otr_bco = nvl(tot_che_otr_bco,0) + nvl(v_tot_cheques,0),
               sal_che_otr_bco = nvl(sal_che_otr_bco,0) + nvl(v_tot_cheques,0),
               tot_che_nue_bco = nvl(tot_che_nue_bco,0) + nvl(p_che_ntr_bco,0),
               sal_actual = nvl(sal_actual,0) + nvl(v_mto_efectivo,0),
               tot_debitos = nvl(tot_debitos,0) + nvl(v_mto_efectivo,0),
               can_debitos = nvl(can_debitos,0) + decode(v_mto_efectivo,0,0,1),
               estado = 1 -- abierto
         where nro_caja = to_number(p_nro_caja)
           and cod_moneda = v_cod_moneda
           and fecha = v_fec_caja;
       end if;
      v_nro_secuencia := 0;
      if v_mto_efectivo > 0 then
        -- genero el movimiento por el efectivo
        v_nro_secuencia := v_nro_secuencia + 1;
        insert into cj_movimientos
           (fecha, hora, cod_usuario, nro_secuencia,
            cod_tra_padre, cod_mod_padre, cod_mad_padre,
            cod_oficina, cod_moneda, nro_caja,
            nro_documento, nro_cuenta, monto, tip_monto, tipo, estado)-- C.D.Fase III
        values
           (v_fec_actual, v_hor_actual, v_cod_usuario, v_nro_secuencia, -- secuencia 1
            v_cod_transaccion, v_cod_modulo, v_cod_modalidad,
            v_cod_oficina, v_cod_moneda, to_number(p_nro_caja),
            v_nro_boleta, v_nro_cuenta, v_mto_efectivo,'E' /* efectivo */, v_tipo, p_estado);  --es debito
      end if;
      if p_che_ntr_bco > 0 then
        -- genero el movimiento por el deposito ntro bacno
        v_nro_secuencia := v_nro_secuencia + 1;
        insert into cj_movimientos
           (fecha, hora, cod_usuario, nro_secuencia,
            cod_tra_padre, cod_mod_padre, cod_mad_padre,
            cod_oficina, cod_moneda, nro_caja,
            nro_documento, nro_cuenta, monto, tip_monto, tipo, estado)-- C.D.Fase III
        values
           (v_fec_actual, v_hor_actual, v_cod_usuario, v_nro_secuencia, -- secuencia 2
            v_cod_transaccion, v_cod_modulo, v_cod_modalidad,
            v_cod_oficina, v_cod_moneda, to_number(p_nro_caja),
            v_nro_boleta, v_nro_cuenta, p_che_ntr_bco,'C' /* cheq.ntro bco */, v_tipo, p_estado); /* es debito */
        end if;
      if v_mto_cheque > 0 then
        -- genero el movimiento por el deposito en cheques (local - otros bcos )
        if v_cod_tra_cheque = 607 then --24hs
          v_tip_monto := 'O';
        elsif v_cod_tra_cheque = 610 then --48hs
          v_tip_monto := 'T';
        elsif v_cod_tra_cheque = 632 then --72hs
          v_tip_monto := 'S';
        elsif v_cod_tra_cheque = 632 and v_cod_moneda <> v_cod_mon_local then --72hs
          v_tip_monto := 'X';
        end if;
        v_nro_secuencia := v_nro_secuencia + 1;
        insert into cj_movimientos
           (fecha, hora, cod_usuario, nro_secuencia,
            cod_tra_padre, cod_mod_padre, cod_mad_padre,
            cod_oficina, cod_moneda, nro_caja,
            nro_documento, nro_cuenta, monto, tip_monto, tipo, estado)-- C.D.Fase III
        values
           (v_fec_actual, v_hor_actual, v_cod_usuario, v_nro_secuencia, -- secuencia 2
            v_cod_transaccion, v_cod_modulo, v_cod_modalidad,
            v_cod_oficina, v_cod_moneda, to_number(p_nro_caja),
            v_nro_boleta, v_nro_cuenta, v_mto_cheque,v_tip_monto /* cheq.otros bcos */, v_tipo, p_estado); /* es debito */
        end if;
  end lp_gen_transaccion;
     -- C.D.Fase III--
  procedure lp_act_can_impresion is

  begin
    update cj_movimientos c
       set c.can_impresion = nvl(c.can_impresion, 0) + 1
     where c.fecha = v_fec_actual
       and c.cod_usuario = v_cod_usuario
       and c.hora = v_hor_actual
       and c.cod_tra_padre = v_cod_transaccion;
  exception
    when no_data_found then
      v_cod_respuesta := '006'; -- error
      v_msj_respuesta := 'ERROR: Al actualizar movimiento de Caja.';
    when others then
      v_cod_respuesta := '006'; -- error
      v_msj_respuesta := 'ERROR: Al actualizar movimiento de Caja.';
  end lp_act_can_impresion;
  -- 
  
begin
 -- Inicializacion de la aplicacion y el modulo
 BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=v_cod_modulo; END;
 -- Valido la moneda
 /*if p_nro_boleta is null then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el Nro. de Boleta.';
 els*/if p_nro_tarjeta is null then  -- valido la cuenta
    v_cod_respuesta := '002'; -- error
    v_msj_respuesta := 'ERROR: Ingrese la Tarjeta del cliente.';
 elsif v_mto_cheque is null or v_mto_cheque < 0 then
    v_cod_respuesta := '003'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el importe en Cheques a Depositar.';
 elsif v_mto_efectivo is null or v_mto_efectivo < 0 then
    v_cod_respuesta := '003'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el importe en Efectivo a Depositar.';
 elsif nvl(p_che_ntr_bco,0) is null or nvl(p_che_ntr_bco,0) < 0 then
    v_cod_respuesta := '003'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el importe en Cheques Ntro. Banco.';
 elsif v_mto_cheque = 0 and v_mto_efectivo = 0 and nvl(p_che_ntr_bco,0) = 0 then
    v_cod_respuesta := '003'; -- error
    v_msj_respuesta := 'ERROR: Ingrese por lo menos uno de los importes.';
 elsif (v_mto_cheque > 0 or nvl(p_che_ntr_bco,0) > 0 ) and v_nro_boleta is null then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el Nro. de Boleta.';
 elsif nvl(p_tot_pago,0) <> nvl(v_mto_cheque,0)+nvl(v_mto_efectivo,0)+nvl(p_che_ntr_bco,0) then
    v_cod_respuesta := '003'; -- error
    v_msj_respuesta := 'ERROR: Total pagado no coincide con lo detallado.';
 else
    -- obtengo datos de la cuenta  ------------------------------------------
    begin
      select a.nom_embozar, c.cod_moneda, 'N', c.cod_modalidad, c.nro_cuenta, c.dia_mora
        into v_denominacion, v_cod_moneda, v_est_cuenta, v_tip_cuenta, v_nro_cuenta, v_dia_mora
        from ta_cta_tarjetas c, ta_tarjetas a, ba_personas b
       where c.nro_cuenta = a.nro_cuenta
         AND a.cod_persona = b.cod_persona
         AND b.nro_documento = p_nro_documento
         and a.nro_tarjeta = p_nro_tarjeta;

        If v_nro_boleta is not null then
          -- Verifico la duplicacion del registro
          prj_val_duplicacion(p_nro_caja,
                              v_cod_transaccion,
                              v_cod_moneda,
                              v_nro_boleta,
                              v_cod_respuesta,
                              v_msj_respuesta);
        End if;
        if v_cod_respuesta = '000' then
           v_msj_respuesta := fuj_ver_impedimentos(v_nro_cuenta,
                                                   v_tip_cuenta,
                                                   v_cod_transaccion,
                                                   v_est_cuenta,
                                                  'C'); -- 'C'== CREDITO
           if v_msj_respuesta is not null then
              v_cod_respuesta := '004';  -- la cuenta tiene impedimentos
           end if;
        end if;
        dbms_output.put_line('1)Respuesta '||v_cod_respuesta);
    exception
      when no_data_found then
        v_cod_respuesta := '002';
        v_msj_respuesta := 'ERROR: Nro de cuenta no existe!';
      when others then
        v_cod_respuesta := '003';
        v_msj_respuesta := 'ERROR' || sqlerrm;
    end;

    dbms_output.put_line('2)Respuesta '||v_cod_respuesta);

    /**CROCLIJUD-5**/
    v_cod_persona := fug_obt_cli_principal(v_nro_cuenta);
      
	 if fug_obt_inhibicion(v_cod_cau_judicial,v_cod_persona, v_nro_cuenta) Then
      v_cod_respuesta := '007';
      v_msj_respuesta := 'ERROR: Cliente Principal o Vinc. a la Cuenta con Demanda Judicial. Consulte con el asesor Jurídico';
   End If;

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
    if v_cod_respuesta = '000' then
       if nvl(p_tip_retencion,1) = 1 then
         v_tip_monto := 'O'; --- Cheques
       elsif p_tip_retencion = 2 then
         v_tip_monto := 'T'; --- Cheques
       elsif p_tip_retencion = 3 then
         v_tip_monto := 'S'; --- Cheques
       end if;
       -- verifico los decimales del importe en cheques
       v_msj_respuesta := fuj_val_importe(v_tipo, v_tip_monto,v_cod_moneda,v_mto_cheque,v_cod_transaccion,v_nro_cuenta);
       if v_msj_respuesta is null then -- valido el efectivo
          v_msj_respuesta := fuj_val_importe(v_tipo, 'E',v_cod_moneda,v_mto_efectivo,v_cod_transaccion,v_nro_cuenta);
       end if;
       if v_msj_respuesta is not null then
          v_cod_respuesta := '005';  -- error
       else
          If v_nro_boleta is null and
             nvl(p_che_ntr_bco,0)= 0 and
             v_mto_cheque = 0 then
            select S_NRO_COB_TARJETA.nextval into v_nro_boleta from dual;
          End if;
            -- Verifico el Monto Riesgo. C.D.Fase III --
                PAG_RIE.PR_OPE_RIESGO( v_fec_actual,
                                       v_hor_actual,
                                       v_cod_usuario,
                                       v_cod_transaccion, -- transacción padre 
                                       v_cod_modulo,    -- Módulo
                                       v_cod_modalidad, -- Modalidad
                                       v_nro_cuenta,            -- Nro_cuenta
                                       null,            -- Persona
                                       v_tip_operacion, -- Tip_operacion 
                                       p_tot_pago,--v_tot_monto,     -- Monto Total
                                       null,            -- Número de Documento
                                       v_cod_moneda,    -- Moneda
                                       null,            -- Cotización   
                                       v_nro_pedido); 
                 if nvl(v_nro_pedido,0) > 0 then
                     pag_cta.pr_set_est_movimiento('P');
                 else
                    pag_cta.pr_set_est_movimiento('N');
                 end if; 
    
          -- Asigno el nro de caja a los movimientos
          pag_cta.pr_nro_caja(to_number(p_nro_caja));
          
          -- Acualizo la cuenta con el efectivo depositado
          v_nro_secuencia := 0;
          if v_mto_efectivo > 0 then
             pag_cta.pr_act_operacion(v_nro_cuenta,
                                      v_hor_actual,
                                     'C', -- Débito
                                      v_cod_moneda,
                                      v_mto_efectivo,
                                      v_cod_transaccion,
                                      690, -- trans. hijo de efectivo
                                      v_nro_boleta,
                                      null, -- cotizacion
                                      v_cod_oficina,
                                      v_cod_modulo,
                                      v_cod_modalidad,
                                      null, -- tasa
                                      null, -- valor de tasa
                                      'Pago Efectivo Tarj:'||p_nro_tarjeta, --concepto
                                      'N', -- emitir aviso
                                      v_nro_secuencia, -- nro de secuencia
                                      v_fec_actual);
            /* Si se genera un Pedido de Autorización, el estado debe insertar en S.-- C.D.Fase III*/                          
             if nvl(v_nro_pedido,0) = 0 then 
                v_est_cobro := 'C';
             else
                v_est_cobro := 'S'; -- solicitado .
             end if;                         
             pat_val.G_PROCESO := 'FUJ_PRO_TRANSACCION_250';
             --Obtengo la procesadora de la cuenta TC
             v_procesadora:= fut_obt_procesadora(v_nro_cuenta);

             IF v_procesadora = fug_obt_pardinamico('COD_ENT_GLOBAL') THEN
               INSERT INTO ta_cobros_gp
                 (nro_cuenta, nro_tarjeta, nro_cta_debito, fec_proceso, monto, estado, fec_valor, observacion,
                  hora, cod_usuario, dia_mora, tipo, canal)
               VALUES 
                 (v_nro_cuenta, p_nro_tarjeta, null, v_fec_actual, v_mto_efectivo, 'C', v_fec_actual, 'Pago en Efectivo x Caja',
                  v_hor_actual, v_cod_usuario, v_dia_mora, 'P', 'C');  
             ELSE
               INSERT INTO ta_cobros
                 (nro_cuenta, nro_tarjeta, nro_cta_debito, fec_proceso, monto, estado, fec_valor, observacion,
                  hora, cod_usuario, dia_mora, est_envio) -- DYDMR-2936 ITGF - Pago de Tarjeta Duplicados SC - 25203
               VALUES 
                   (v_nro_cuenta, p_nro_tarjeta, null, v_fec_actual, v_mto_efectivo, v_est_cobro, v_fec_actual, 'Pago en Efectivo x Caja',
                    v_hor_actual, v_cod_usuario, v_dia_mora, 'P');
             END IF;
               
               -- DYDMR-2936 ITGF - Pago de Tarjeta Duplicados SC - 25203
               /*DYDMR-3016 SE QUITA LA VALIDACIÓN DE CAJA HUMANA DEBIDO A QUE LOS CAJEROS INGRESAN
               MOVIMIENTOS DE TAS MANUALMENTE POR LA TRANSACCION 250, ESTOS NO ESTAN SIENDO ENVIADOS A BANCARD */
            -- if fuj_obt_tip_caja(p_nro_caja) = 'H' then
              /* declare
                 v_cod_envio ge_par_web_servicios.cod_envio%type;
               begin
                 select S_COD_ENVIO.NEXTVAL into v_cod_envio from dual;
                 insert into ge_par_web_servicios
                  (cod_envio,
                   fecha,
                   cod_servicio,
                   estado,
                   dat_enviados,
                   cod_programa)
                 values
                  (v_cod_envio,
                   v_fec_actual,
                   '000002', --codigo para el servicio de pago de tarjetas
                   'P',
                   'cardNumber='||p_nro_tarjeta||'&'||'amount='||v_mto_efectivo, --cardNumber=NRO_TARJETA&amount=MONTO
                   'FUJ_PRO_TRANSACCION_250');
               end;*/
            -- end if;
          end if;
          if nvl(p_che_ntr_bco,0) > 0 then
             pag_cta.pr_act_operacion(v_nro_cuenta,
                                      v_hor_actual,
                                     'C', -- credito
                                      v_cod_moneda,
                                      p_che_ntr_bco,
                                      v_cod_transaccion,
                                      606, -- trans. hijo cheq ntro bco
                                      v_nro_boleta,
                                      null, -- cotizacion
                                      v_cod_oficina,
                                      v_cod_modulo,
                                      v_cod_modalidad,
                                      null, -- tasa
                                      null, -- valor de tasa
                                      'Pago Efectivo Tarj:'||p_nro_tarjeta, --concepto
                                      'N', -- emitir aviso
                                      v_nro_secuencia, -- nro de secuencia
                                      v_fec_actual);

/*             insert into ta_cobros
              (nro_cuenta, nro_tarjeta, nro_cta_debito, fec_proceso, monto, estado, fec_valor, observacion,
               hora, cod_usuario, dia_mora)
             values
              (v_nro_cuenta, p_nro_tarjeta, null, v_fec_actual, p_che_ntr_bco, 'C', v_fec_actual, 'Pago Cheq.ntro.bco x Caja',
               v_hor_actual, v_cod_usuario, v_dia_mora);*/
          end if;

          -- Actualizo la cuenta con el cheque depositado plaza local sino hubo errores
          if (nvl(pag_cta.g_cod_error,0)= 0 or v_mto_efectivo = 0) and v_mto_cheque > 0 then
              --depende del tipo de retención
             if nvl(p_tip_retencion,1) = 1 then
               v_cod_tra_cheque := 607; --- Cheques
             elsif p_tip_retencion = 2 then
               v_cod_tra_cheque := 610; --- Cheques
             elsif p_tip_retencion = 3 then
               v_cod_tra_cheque := 632; --- Cheques
             end if;
             pag_cta.pr_act_operacion(v_nro_cuenta,
                                      v_hor_actual,
                                     'C', -- Débito
                                      v_cod_moneda,
                                      v_mto_cheque,
                                      v_cod_transaccion,
                                      v_cod_tra_cheque, -- trans. hijo de cheq.otros bcos
                                      v_nro_boleta,
                                      null, -- cotizacion
                                      v_cod_oficina,
                                      v_cod_modulo,
                                      v_cod_modalidad,
                                      null, -- tasa
                                      null, -- valor de tasa
                                      'Pago Cheque Tarj:'||p_nro_tarjeta, --concepto
                                      'N', -- emitir aviso
                                      v_nro_secuencia, -- nro de secuencia
                                      v_fec_actual);
/*            --agregado por solicitud de operaciones 11/02/2005 para envio de cheques como efectivo--
            insert into ta_cobros
              (nro_cuenta, nro_tarjeta, nro_cta_debito, fec_proceso, monto, estado, fec_valor, observacion,
               hora, cod_usuario, dia_mora)
             values
              (v_nro_cuenta, p_nro_tarjeta, null, v_fec_actual, v_mto_cheque, 'C', v_fec_actual, 'Pago en Cheque x Caja',
               v_hor_actual, v_cod_usuario, v_dia_mora);*/
          end if;
         if pag_cta.g_cod_error <> 0 then
            -- actualizacion con problemas
            v_cod_respuesta := ltrim(to_char(pag_cta.g_cod_error,'000'));
            v_msj_respuesta := pag_cta.g_msj_error;
         else -- genero la transaccion en caja
            if nvl(v_nro_pedido,0) > 0 then -- C.D.Fase III
              lp_gen_transaccion('P');
            else
              lp_gen_transaccion('N');
            end if;
         end if;
      end if;
    end if;
 end if;
 -- mensaje final sino hubo errores
 if v_cod_respuesta = '000' then -- sino hubo problemas, se carga mensaje por defecto
   IF nvl(v_nro_pedido,0) = 0 then
      lp_act_can_impresion; -- C.D.Fase III--
      v_msj_respuesta := 'Operacion confirmada. Comprobante ha sido impreso'||'~'||
      fuj_imp_comprobante_250(v_nro_boleta,
                              v_cod_oficina,
                              p_nro_caja);
      v_cod_respuesta := 'IMP';
    else
       v_msj_respuesta := 'Se ha generado el Pedido de Autorización Nro.:'||v_nro_pedido; 
    end if;
/*       -- veo si se detallo el cheque
     if p_cod_banco is not null and p_nro_cheque is not null and
        p_mto_chq_des is not null then
        -- se detallo el cheque, se procesa el detalle del mismo
        v_msj_salida := fuj_pro_transaccion_355(p_nro_operacion,
                                                p_nro_caja,
                                                p_nro_boleta,
                                                p_cod_banco,
                                                p_nro_cheque,
                                                p_mto_chq_des);
        return (v_msj_salida); -- retorna directamente el mensaje
     end if;*/
 end if;
 /* falta armar el mensaje de respuesta */
 v_msj_salida := p_nro_operacion||'~'||
                 v_cod_respuesta||'~'||
                 nvl(v_msj_respuesta,'Operacion confirmada');
 return(v_msj_salida);
 exception
    when others then
       v_cod_respuesta := '999';
       v_msj_salida := p_nro_operacion||'~'||
                 v_cod_respuesta||'~'||
                 nvl(v_msj_respuesta,SQLERRM);
       return(v_msj_salida);
end FUJ_PRO_TRANSACCION_250;
/

