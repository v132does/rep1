CREATE OR REPLACE FUNCTION IT.FUJ_PRO_TRANSACCION_352 (
      p_nro_operacion in varchar2,   -- Nro de referencia de la operacion
      p_nro_caja    in varchar2,     -- Nro de Caja
      --p_nro_boleta  in varchar2,      -- Nro de la boleta
      p_nro_cuenta  in varchar2,      -- Nro de cuenta del cliente
      p_tot_deposito in number,       -- total de deposito
      p_mto_che_24  in number,  -- Importe del deposito en cheques (plaza local - Ret 1)
      p_mto_che_48  in number,  -- importe cheq. plaza local Ret 2
      p_mto_che_72  in number,  -- importe de cheq con Ret 3
      p_hora in varchar2 default null)  --Hora para confirmación de Cheq.Favor
return VARCHAR2 is
  -- defino por defecto el modulo y modalidad a utilizar
  v_cod_modulo        number(3)    := 9;    -- Caja
  v_cod_modalidad     number(3)    := 91;   -- Caja
  v_cod_transaccion   number(4)    := 352;  -- transaccion
  v_cod_usuario       varchar2(10) := upper(user); --usuario
  -- Datos de la caja
  v_fec_actual        date := pag_cal.fu_obt_fec_actual(v_cod_modulo); -- fecha de hoy
  v_hor_actual        varchar2(08) := nvl(p_hora,to_char(sysdate,'HH24:MI:SS'));   -- Hora actual
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
  -- Datos de salida
  v_msj_salida        varchar2(8000);        -- mensaje final retornado
  v_cod_respuesta     varchar2(03) := '000'; -- sin errores
  v_msj_respuesta     varchar2(5000) := 'Operacion Confirmada'; -- sin errores
  -- datos de la operacion convertidos
  v_tipo              varchar2(01) := 'D';  -- Debito para la caja (ingreso)
  v_tip_monto         varchar2(01) := 'O';  -- Cheq. Otros Bancos
  v_mto_che_24        number       := nvl(p_mto_che_24,0); -- importe del deposito en cheques Ret 1
  v_mto_che_48        number       := nvl(p_mto_che_48,0); -- importe del deposito en cheques Ret 2
  v_mto_che_72        number       := nvl(p_mto_che_72,0); -- importe del deposito en cheques Ret 3
  v_nro_secuencia     number(3)    := 0;  -- secuencia del mov.
  v_tot_cheques       number       := nvl(v_mto_che_24,0)+ nvl(v_mto_che_48,0)+nvl(v_mto_che_72,0);  -- total en cheques
  v_tot_deposito      number(18,2);  -- total de deposito
  v_saldo             number;
  v_cod_persona       ba_personas.cod_persona%type;
   -- C.D. Fase III--
  v_tip_operacion   ge_mov_autorizaciones.tip_operacion%type := 'O';-- Todos Tipos Operacional
  v_est_movimiento  ge_movimientos.estado%type;
  v_nro_pedido      ge_mov_autorizaciones.nro_pedido%type;
  v_mto_calculado number;
  p_nro_boleta  number(10);
  v_existe_cheque   varchar2(1) := 'N';
  --
  -- Procedimiento interno para generar movimiento y act. de control de caja
  procedure lp_gen_transaccion (p_estado varchar2) is
  begin
      -- Actualizo el control de caja
      if p_estado <> 'P' then -- C.D.Fase III
        update cj_controles
           set tot_che_otr_bco = nvl(tot_che_otr_bco,0) + nvl(v_tot_cheques,0),
               sal_che_otr_bco = nvl(sal_che_otr_bco,0) + nvl(v_tot_cheques,0),
               estado = 1 -- abierto
         where nro_caja = to_number(p_nro_caja)
           and cod_moneda = v_cod_moneda
           and fecha = v_fec_caja;
       end if;
      v_nro_secuencia := 0;
      if v_mto_che_24 > 0 then
        -- genero el movimiento por el deposito en cheques (local - Ret 1.)
        v_nro_secuencia := v_nro_secuencia + 1;
        insert into cj_movimientos
           (fecha, hora, cod_usuario, nro_secuencia,
            cod_tra_padre, cod_mod_padre, cod_mad_padre,
            cod_oficina, cod_moneda, nro_caja,
            nro_documento, nro_cuenta, monto, tip_monto, tipo, estado ) -- C.D.Fase III
        values
           (v_fec_actual, v_hor_actual, v_cod_usuario, v_nro_secuencia, -- secuencia 1
            v_cod_transaccion, v_cod_modulo, v_cod_modalidad,
            v_cod_oficina, v_cod_moneda, to_number(p_nro_caja),
            p_nro_boleta, p_nro_cuenta, v_mto_che_24,v_tip_monto /* cheq.otros bcos */, v_tipo, p_estado); /* es debito */
      end if;
      if v_mto_che_48 > 0 then
        -- genero el movimiento por el deposito en cheques (local - Ret 2.)
        v_nro_secuencia := v_nro_secuencia + 1;
        insert into cj_movimientos
           (fecha, hora, cod_usuario, nro_secuencia,
            cod_tra_padre, cod_mod_padre, cod_mad_padre,
            cod_oficina, cod_moneda, nro_caja,
            nro_documento, nro_cuenta, monto, tip_monto, tipo, estado )-- C.D Fase III
        values
           (v_fec_actual, v_hor_actual, v_cod_usuario, v_nro_secuencia, -- secuencia 2
            v_cod_transaccion, v_cod_modulo, v_cod_modalidad,
            v_cod_oficina, v_cod_moneda, to_number(p_nro_caja),
            p_nro_boleta, p_nro_cuenta, v_mto_che_48,'T' /* cheq.otros bcos */, v_tipo, p_estado); /* es debito */
        end if;
      if v_mto_che_72 > 0 then
        -- genero el movimiento por el deposito en cheques (local - Ret 3.)
        v_nro_secuencia := v_nro_secuencia + 1;
        insert into cj_movimientos
           (fecha, hora, cod_usuario, nro_secuencia,
            cod_tra_padre, cod_mod_padre, cod_mad_padre,
            cod_oficina, cod_moneda, nro_caja,
            nro_documento, nro_cuenta, monto, tip_monto, tipo, estado ) -- C.D Fase III
        values
           (v_fec_actual, v_hor_actual, v_cod_usuario, v_nro_secuencia, -- secuencia 2
            v_cod_transaccion, v_cod_modulo, v_cod_modalidad,
            v_cod_oficina, v_cod_moneda, to_number(p_nro_caja),
            p_nro_boleta, p_nro_cuenta, v_mto_che_72,'S' /* cheq.otros bcos */, v_tipo, p_estado); /* es debito */
        end if;
      --Valida si existe un cheque pre cargado en cj_dep_chq_atm_reg --TED
      begin 
        select 'S' into v_existe_cheque from cj_dep_chq_atm_reg o
        where o.monto_cheque = v_tot_cheques
          and o.nro_cuenta = p_nro_cuenta
          and o.est_cheque in ('I');
        exception 
          when others then 
            v_existe_cheque := 'N';
        end;
       if v_existe_cheque = 'S' then   
            --Se actualiza el estado del movimiento de tabla de cheques recibidos en el TED.
            begin 
              update cj_dep_chq_atm_reg o
              set o.est_cheque = 'D',
                  o.fecha = v_fec_actual,
                  o.hora = v_hor_actual,
                  o.cod_usuario = v_cod_usuario,
                  o.nro_secuencia = v_nro_secuencia
              where o.monto_cheque = v_tot_cheques
                and o.est_cheque in ('I');
              exception 
                when others then 
                  null;
             end;
            end if;
  end lp_gen_transaccion;
  --
begin
 -- Inicializacion de la aplicacion y el modulo
 BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=v_cod_modulo; END;
 -- Valido la moneda
 /*if p_nro_boleta is null then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el Nro. de Boleta.';*/

 if p_nro_cuenta is null then  -- valido la cuenta
    v_cod_respuesta := '002'; -- error
    v_msj_respuesta := 'ERROR: Ingrese la Cuenta del cliente.';
 elsif v_mto_che_24 is null or v_mto_che_24 < 0 then
    v_cod_respuesta := '003'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el importe en Cheques de Plaza Local - Retención 1 a Depositar.';
 elsif v_mto_che_48 is null or v_mto_che_48 < 0 then
    v_cod_respuesta := '003'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el importe en Cheques de Plaza Local - Retención 2 a Depositar.';
 elsif v_mto_che_24 = 0 and v_mto_che_48 = 0 and v_mto_che_72 = 0 then
    v_cod_respuesta := '003'; -- error
    v_msj_respuesta := 'ERROR: Ingrese por lo menos uno de los importes.';
 elsif nvl(p_tot_deposito,0) <> nvl(v_mto_che_24,0) + nvl(v_mto_che_48,0) + nvl(v_mto_che_72,0)then
    v_cod_respuesta := '003'; -- error
    v_msj_respuesta := 'ERROR: Total Depositado no coincide con los Detalles.';
-- elsif v_mto_che_24 > 0 and  v_hor_actual > '14:00:00' then
--    v_cod_respuesta := '003'; -- error
--    v_msj_respuesta := 'ERROR: No puede ingresar cheques con Retencion 1 a partir de las 14:00 Hs.';
 else
  ---
  if p_nro_cuenta is not null then  -- valido la cuenta si es migrada
     v_msj_respuesta := fug_obt_nro_cta_bt(p_nro_cuenta);
     if v_msj_respuesta is not null then
        v_cod_respuesta := '012'; -- error
     end if;
  end if;
   
  if v_cod_respuesta = '000' then
    -- obtengo datos de la cuenta  ------------------------------------------
    begin
      select denominacion, cod_moneda, estado, cod_modalidad
        into v_denominacion, v_cod_moneda, v_est_cuenta, v_tip_cuenta
        from ge_cuentas a
       where a.nro_cuenta = p_nro_cuenta;
      if v_tip_cuenta not in (31,32,33,34,41,334) then
        v_cod_respuesta := '003';
        v_msj_respuesta := 'ERROR: Tipo de cuenta no permite Depositos';
      --elsif v_cod_moneda <> pag_gen.FU_OBT_MON_LOCAL() then
      --  v_cod_respuesta := '003';
      --  v_msj_respuesta := 'ERROR: Solo puede ingresar depositos en moneda local.';
      else
        -- Verifico la duplicacion del registro
        prj_val_duplicacion(p_nro_caja,
                            v_cod_transaccion,
                            v_cod_moneda,
                            999999, --p_nro_boleta, -- no se controla porque el numero es automatico
                            v_cod_respuesta,
                            v_msj_respuesta);

        if v_cod_respuesta = '000' then
           if v_tip_cuenta = 41 then--si es cta cte verifica el saldo
               select nvl(sal_total,0) - nvl(sal_retenido,0) - nvl(sal_bloqueado,0)
                 into v_saldo
                 from cc_cta_corrientes
                where nro_cuenta = p_nro_cuenta;
           end if;
        end if;
        if v_cod_respuesta = '000' then
           v_msj_respuesta := fuj_ver_impedimentos(p_nro_cuenta,
                                                   v_tip_cuenta,
                                                   v_cod_transaccion,
                                                   v_est_cuenta,
                                                  'C'); -- 'C'== CREDITO
           if v_msj_respuesta is not null then
              if v_tip_cuenta = 41 and v_msj_respuesta like 'Cuenta esta pendiente de Cancelacion' then
                 --si la cuenta tiene saldo negativo puede recibir depósitos
                 if v_saldo > 0 then
                    v_cod_respuesta := '004';  -- la cuenta tiene impedimentos
                 end if;
              else
                 v_cod_respuesta := '004';  -- la cuenta tiene impedimentos
              end if;
           end if;
        end if;
      end if;
    exception
      when no_data_found then
        v_cod_respuesta := '002';
        v_msj_respuesta := 'ERROR: Nro de cuenta no existe!';
      when others then
        v_cod_respuesta := '003';
        v_msj_respuesta := 'ERROR' || sqlerrm;
    end;
     /** CROCLIJUD-5 **/
    v_cod_persona := FUG_OBT_CLI_PRINCIPAL(p_nro_cuenta);
    If FUG_OBT_INHIBICION(fug_obt_pardinamico('COD_CAU_DEM_JUDICIAL'),v_cod_persona,p_nro_cuenta) Then
      v_cod_respuesta := '004';
      v_msj_respuesta := 'ERROR. Cliente Principal. o Vinc. a la Cuenta con Demanda Judicial.Consulte con el asesor Jurídico';
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
       -- verifico los decimales del importe en cheques - Ret 1
       v_msj_respuesta := fuj_val_importe(v_tipo, v_tip_monto,v_cod_moneda,v_mto_che_24,v_cod_transaccion, p_nro_cuenta);
       if v_msj_respuesta is null then -- valido los decimales del importe en cheques - Ret 2
          v_msj_respuesta := fuj_val_importe(v_tipo, 'T',v_cod_moneda,v_mto_che_48, v_cod_transaccion, p_nro_cuenta);
       end if;
       if v_msj_respuesta is null then -- valido los decimales del importe en cheques - Ret 3
          v_msj_respuesta := fuj_val_importe(v_tipo, 'S',v_cod_moneda,v_mto_che_72,v_cod_transaccion, p_nro_cuenta);
       end if;
       if v_msj_respuesta is not null then
          v_cod_respuesta := '005';  -- error
       else
         -- Asigno el nro de caja a los movimientos
         pag_cta.pr_nro_caja(to_number(p_nro_caja));

         -- Verifico el Monto de Riesgo -- C.D Fase III
         IF nvl(pae_cnf.G_PROGRAMA,'X') not in ( 'CMDEPCON') Then --> CRO-JM: Custodia de Cheques, No deben generar autorización por control dual
            PAG_RIE.PR_OPE_RIESGO( v_fec_actual,
                                   v_hor_actual,
                                   v_cod_usuario,
                                   v_cod_transaccion, -- transacción padre
                                   v_cod_modulo,      -- Módulo
                                   v_cod_modalidad,   -- Modalidad
                                   p_nro_cuenta,      -- Nro_cuenta
                                   v_cod_persona,     -- Persona
                                   v_tip_operacion,   -- Tip_operacion
                                   v_tot_cheques,     -- Monto(Total de Cheques)
                                   null,              -- Número de Documento
                                   v_cod_moneda,      -- Moneda
                                   null,              -- Cotización
                                   v_nro_pedido);
           End IF;
           if v_nro_pedido > 0 then
             v_est_movimiento := 'P';
              pag_cta.pr_set_est_movimiento('P');
           else
             v_est_movimiento := 'N';
           end if;

              -- busco el sgte nro de boleta
            select s_nro_bol_deposito.nextval into p_nro_boleta from dual;

         -- Actualizo la cuenta con el cheque depositado plaza local 24 hs. sino hubo errores
         v_nro_secuencia := 0;
         if v_mto_che_24 > 0 then
             pag_cta.pr_act_operacion(p_nro_cuenta,
                                      v_hor_actual,
                                     'C', -- credito
                                      v_cod_moneda,
                                      v_mto_che_24,
                                      v_cod_transaccion,
                                      607, -- trans. hijo de cheq.otros bcos
                                      p_nro_boleta,
                                      null, -- cotizacion
                                      v_cod_oficina,
                                      v_cod_modulo,
                                      v_cod_modalidad,
                                      null, -- tasa
                                      null, -- valor de tasa
                                      'Deposito en Cheq.Pl. Local - 0Hs.', --concepto
                                      'N', -- emitir aviso
                                      v_nro_secuencia, -- nro de secuencia
                                      v_fec_actual ,
                                      null,
                                      null,
                                      null,
                                      v_est_movimiento); -- C.D.Fase III
         end if;
         -- Actualizo la cuenta con el cheque depositado plaza local Ret 2 sino hubo errores
         if (nvl(pag_cta.g_cod_error,0)= 0 or v_mto_che_48 = 0) and v_mto_che_48 > 0 then
             pag_cta.pr_act_operacion(p_nro_cuenta,
                                      v_hor_actual,
                                     'C', -- credito
                                      v_cod_moneda,
                                      v_mto_che_48,
                                      v_cod_transaccion,
                                      610, -- trans. hijo de cheq.otros bcos
                                      p_nro_boleta,
                                      null, -- cotizacion
                                      v_cod_oficina,
                                      v_cod_modulo,
                                      v_cod_modalidad,
                                      null, -- tasa
                                      null, -- valor de tasa
                                      'Deposito en Cheq.Pl. Local - 24Hs.', --concepto
                                      'N', -- emitir aviso
                                      v_nro_secuencia, -- nro de secuencia
                                      v_fec_actual,
                                      null, null, null, v_est_movimiento); -- C.D.Fase III
         end if;
         -- Actualizo la cuenta con el cheque depositado plaza local Ret 3 sino hubo errores
         if (nvl(pag_cta.g_cod_error,0)= 0 or (v_mto_che_24 = 0 and v_mto_che_48=0) ) and v_mto_che_72 > 0 then
             pag_cta.pr_act_operacion(p_nro_cuenta,
                                      v_hor_actual,
                                     'C', -- credito
                                      v_cod_moneda,
                                      v_mto_che_72,
                                      v_cod_transaccion,
                                      632, -- trans. hijo de cheq.otros bcos
                                      p_nro_boleta,
                                      null, -- cotizacion
                                      v_cod_oficina,
                                      v_cod_modulo,
                                      v_cod_modalidad,
                                      null, -- tasa
                                      null, -- valor de tasa
                                      'Deposito en Cheq.Pl. Local - 48Hs.', --concepto
                                      'N', -- emitir aviso
                                      v_nro_secuencia, -- nro de secuencia
                                      v_fec_actual,
                                      null, null, null, v_est_movimiento); -- C.D.Fase III
         end if;

         if pag_cta.g_cod_error <> 0 then
            -- actualizacion con problemas
            v_cod_respuesta := ltrim(to_char(pag_cta.g_cod_error,'000'));
            v_msj_respuesta := pag_cta.g_msj_error;
         else -- genero la transaccion en caja
           -- C.D.Fase III --
           if nvl(v_nro_pedido,0) > 0 then
              lp_gen_transaccion('P');
           else
              lp_gen_transaccion('N');
           end if;
         end if;
         --
         if v_cod_respuesta = '000' then
           /* Se define con Usuario imprima el comprobante FIT, si se genera un Pedido de Autorización*/
              -- sumo el total de deposito
              v_tot_deposito := nvl(v_tot_cheques,0);
         -- CRO-JM-03/2015: CROGEFIT-3
        /*if pag_gen.FU_CON_MON_A_MONEDA(v_cod_moneda, -- moneda origen
                                             pag_gen.FU_OBT_MON_FUERTE, -- moneda dolar
                                             v_tot_deposito) >= fug_obt_pardinamico('OPE_SUP_MON_FUERTE') then*/
                if fuj_ver_imp_formulario(p_nro_cuenta,
                                          v_cod_persona,
                                          pag_gen.fu_con_mon_a_moneda(v_cod_moneda, -- moneda origen
                                                                      pag_gen.fu_obt_mon_fuerte, -- moneda dolar
                                                                      v_tot_deposito),
                                          v_cod_transaccion,
                                          v_mto_calculado) and
                                         nvl(pae_cnf.G_PROGRAMA,'X') <> ( 'CMDEPCON') then
                 -- paso el monto minimo a informar. Generar el informe de operaciones > a USD 10000
                 v_cod_respuesta := 'IMP'; -- para indicar que esta ok y se puede imprimir
                 if nvl(v_nro_pedido,0) > 0 then -- C.D.Fase III
                   v_msj_respuesta := 'Se ha generado el Pedido de Autorización Nro.'|| v_nro_pedido||'-'||'Decl.Jurada y Comprobante impresos.'||'~'||
                   fuj_imp_dec_jurada_40(v_fec_actual, v_hor_actual, user, 1, v_mto_calculado, v_cod_transaccion)/*||
                 fuj_imp_comprobante_351(p_nro_boleta, v_cod_oficina, p_nro_caja)*/;
                 else
                   v_msj_respuesta := 'Operacion Confirmada. Decl.Jurada y Comprobante impresos.'||'~'||
                   fuj_imp_dec_jurada_40(v_fec_actual, v_hor_actual, user, 1, v_mto_calculado, v_cod_transaccion)/*||
                 fuj_imp_comprobante_351(p_nro_boleta, v_cod_oficina, p_nro_caja)*/;
                 end if;
                 -- CRO-JM-03/2015: CROGEFIT-3 insertamos en la tabla como ya impreso:
                      prj_ins_form_transacciones(p_nro_cuenta,
                                                 v_cod_persona,
                                                 v_cod_modulo,
                                                 v_cod_transaccion,
                                                 USER,
                                                 v_fec_actual,
                                                 v_hor_actual,
                                                 pag_gen.fu_obt_mon_fuerte,
                                                 pag_gen.fu_con_mon_a_moneda(v_cod_moneda, -- moneda origen
                                                                             pag_gen.fu_obt_mon_fuerte, -- moneda dolar
                                                                             v_tot_deposito),
                                                 'S');

               else
                 -- CRO-JM-03/2015: CROGEFIT-3 insertamos en la tabla como ya impreso:
                      prj_ins_form_transacciones(p_nro_cuenta,
                                                 v_cod_persona,
                                                 v_cod_modulo,
                                                 v_cod_transaccion,
                                                 USER,
                                                 v_fec_actual,
                                                 v_hor_actual,
                                                 pag_gen.fu_obt_mon_fuerte,
                                                 pag_gen.fu_con_mon_a_moneda(v_cod_moneda, -- moneda origen
                                                                             pag_gen.fu_obt_mon_fuerte, -- moneda dolar
                                                                             v_tot_deposito),
                                                 'N');
              end if;
         end if;
      end if;
    end if;
  end if; --> Condicion de cuenta migrad
 end if;
 if v_cod_respuesta = '000' then
       v_cod_respuesta := 'IMP'; -- para indicar que esta ok y se puede imprimir
       v_msj_respuesta := 'Operacion Confirmada. Comprobante ha sido impreso.'||'~'||
       fuj_imp_comprobante_352(p_nro_boleta, v_cod_oficina,p_nro_caja);
       -- retorno de la rutina de impresion
        v_msj_salida := p_nro_boleta||'~'||
                        v_cod_respuesta||'~'||
                        v_msj_respuesta;
 end if;   

 pag_cta.pr_nro_caja(null);
 /* falta armar el mensaje de respuesta */
 v_msj_salida := p_nro_operacion||'~'||
                 v_cod_respuesta||'~'||
                 nvl(v_msj_respuesta,nvl(v_msj_salida,'Con error'));
 return(v_msj_salida);

 exception
    when others then
       v_cod_respuesta := '999';
       v_msj_salida := p_nro_boleta||'~'||
                 v_cod_respuesta||'~'||
                 nvl(v_msj_respuesta,SQLERRM);
       return(v_msj_salida);
end FUJ_PRO_TRANSACCION_352;
/
