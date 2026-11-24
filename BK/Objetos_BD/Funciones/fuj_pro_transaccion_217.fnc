CREATE OR REPLACE FUNCTION IT.FUJ_PRO_TRANSACCION_217 (
      p_nro_operacion in varchar2,   -- Nro de referencia de la operacion
      p_nro_caja    in varchar2,        -- Nro de Caja
      p_nro_boleta  in varchar2,      -- Nro de la boleta
      p_mto_che_24  in number,  -- Importe del deposito en cheques (plaza local - 24 Hs.)
      p_mto_che_48  in number,  -- importe cheq. plaza local 48 Hs
      p_mto_che_72  in number)  -- importe de cheq con 72 hs de retencion m/l
return VARCHAR2 is
  -- defino por defecto el modulo y modalidad a utilizar
  v_cod_modulo        number(3)    := 9;    -- Caja
  v_cod_modalidad     number(3)    := 91;   -- Caja
  v_cod_transaccion   number(4)    := 352;  -- transaccion
  v_cod_usuario       varchar2(10) := upper(user); --usuario
  -- Datos de la caja
  v_fec_actual        date := pag_cal.fu_obt_fec_actual(v_cod_modulo); -- fecha de hoy
  v_hor_actual        varchar2(08) := to_char(sysdate,'HH24:MI:SS');   -- Hora actual
  v_cod_oficina       number(3);         -- Codigo de oficina
  v_estado            number(1);         -- estado de la caja
  v_fec_caja          date;              -- fecha de la caja
  v_sal_actual        number(18,2);          -- saldo actual de la caja en efectivo
  v_sal_cheques       number(18,2);          -- saldo actual de la caja en cheques
  -- Datos de la cuenta
  v_nro_cuenta        varchar2(20);
  v_denominacion      varchar2(200);     -- Nombre de la cuenta
  v_cod_moneda        varchar2(3);       -- moneda de la cuenta
  v_est_cuenta        varchar2(1);       -- estado de la cuenta
  v_tip_cuenta        number(3);         -- tipo de cuenta(modalidad)
  v_cod_usu_operacion varchar2(20);
  v_hor_operacion     varchar2(10);
  v_fec_operacion     date;
  v_cod_tra_padre     number(6);
  v_rowid             varchar2(100);
  -- Datos de salida
  v_msj_salida        varchar2(8000);        -- mensaje final retornado
  v_cod_respuesta     varchar2(03) := '000'; -- sin errores
  v_msj_respuesta     varchar2(4000) := 'Operacion Confirmada'; -- sin errores
  -- datos de la operacion convertidos
  v_tipo              varchar2(01) := 'D';  -- Debito para la caja (ingreso)
  v_tip_monto         varchar2(01) := 'O';  -- Cheq. Otros Bancos
  v_mto_che_24        number       := nvl(p_mto_che_24,0); -- importe del deposito en cheques 0 hs
  v_mto_che_48        number       := nvl(p_mto_che_48,0); -- importe del deposito en cheques 24 hs
  v_mto_che_72        number       := nvl(p_mto_che_72,0); -- importe del deposito en cheques 48 hs
  v_nro_secuencia     number(3)    := 0;  -- secuencia del mov.
  v_tot_cheques       number       := nvl(v_mto_che_24,0)+ nvl(v_mto_che_48,0)+nvl(v_mto_che_72,0);  -- total en cheques
  v_tot_deposito      number(18,2);  -- total de deposito
  v_cod_persona       ge_cta_clientes.cod_persona%type;
  v_cli_frecuente     cr_inf_fondos.cli_frecuente%type;
  v_mto_calculado     number;
  --
  v_cod_tra_cre       ge_transacciones.cod_transaccion%type;
  v_mod_cta_cre       ge_movimientos.cod_modulo%TYPE;
  v_mad_cta_cre       ge_movimientos.cod_modalidad%TYPE;
  v_mon_cta_cre       ge_movimientos.cod_moneda%TYPE;
  v_ofi_cta_cre       ge_movimientos.cod_oficina%TYPE;
  vp_cta_credito      cc_cta_cajeros.nro_cuenta%TYPE;
  v_est_cta_cre       ge_cuentas.estado%TYPE;
  r_gmovi               ge_movimientos%ROWTYPE;
  --
  -- Procedimiento interno para generar movimiento y act. de control de caja
  procedure lp_gen_transaccion  is
  begin
      -- Actualizo el control de caja
/*    NO HACE FALTA, YA QUE YA ESTA ESTE MONTO EN EL SALDO
      update cj_controles
         set tot_che_otr_bco = nvl(tot_che_otr_bco,0) + nvl(v_tot_cheques,0),
             sal_che_otr_bco = nvl(sal_che_otr_bco,0) + nvl(v_tot_cheques,0),
             estado = 1 -- abierto
       where nro_caja = to_number(p_nro_caja)
         and cod_moneda = v_cod_moneda
         and fecha = v_fec_caja;
      v_nro_secuencia := 0;*/
      -- actualizo el movimento anterior como reversado
      update cj_movimientos
         set estado = 'R'  -- reversado
       where rowid = v_rowid;
      if v_mto_che_24 > 0 then
        -- genero el movimiento por el deposito en cheques (local - 24 hs.)
        v_nro_secuencia := v_nro_secuencia + 1;
        insert into cj_movimientos
           (fecha, hora, cod_usuario, nro_secuencia,
            cod_tra_padre, cod_mod_padre, cod_mad_padre,
            cod_oficina, cod_moneda, nro_caja,
            nro_documento, nro_cuenta, monto, tip_monto, tipo)
        values
           (v_fec_actual, v_hor_actual, v_cod_usuario, v_nro_secuencia, -- secuencia 1
            v_cod_transaccion, v_cod_modulo, v_cod_modalidad,
            v_cod_oficina, v_cod_moneda, to_number(p_nro_caja),
            p_nro_boleta, v_nro_cuenta, v_mto_che_24,v_tip_monto /* cheq.otros bcos */, v_tipo); /* es debito */
      end if;
      if v_mto_che_48 > 0 then
        -- genero el movimiento por el deposito en cheques (local - 48 hs.)
        v_nro_secuencia := v_nro_secuencia + 1;
        insert into cj_movimientos
           (fecha, hora, cod_usuario, nro_secuencia,
            cod_tra_padre, cod_mod_padre, cod_mad_padre,
            cod_oficina, cod_moneda, nro_caja,
            nro_documento, nro_cuenta, monto, tip_monto, tipo)
        values
           (v_fec_actual, v_hor_actual, v_cod_usuario, v_nro_secuencia, -- secuencia 2
            v_cod_transaccion, v_cod_modulo, v_cod_modalidad,
            v_cod_oficina, v_cod_moneda, to_number(p_nro_caja),
            p_nro_boleta, v_nro_cuenta, v_mto_che_48,'T' /* cheq.otros bcos */, v_tipo); /* es debito */
        end if;
      if v_mto_che_72 > 0 then
        -- genero el movimiento por el deposito en cheques (local - 72 hs.)
        v_nro_secuencia := v_nro_secuencia + 1;
        insert into cj_movimientos
           (fecha, hora, cod_usuario, nro_secuencia,
            cod_tra_padre, cod_mod_padre, cod_mad_padre,
            cod_oficina, cod_moneda, nro_caja,
            nro_documento, nro_cuenta, monto, tip_monto, tipo)
        values
           (v_fec_actual, v_hor_actual, v_cod_usuario, v_nro_secuencia, -- secuencia 2
            v_cod_transaccion, v_cod_modulo, v_cod_modalidad,
            v_cod_oficina, v_cod_moneda, to_number(p_nro_caja),
            p_nro_boleta, v_nro_cuenta, v_mto_che_72,'S' /* cheq.otros bcos */, v_tipo); /* es debito */
        end if;

  end lp_gen_transaccion;
  --
begin
 -- Inicializacion de la aplicacion y el modulo
 BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=v_cod_modulo; END;
 -- Valido la moneda
 if p_nro_boleta is null then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el Nro. de Boleta.';
 elsif v_mto_che_24 is null or v_mto_che_24 < 0 then
    v_cod_respuesta := '003'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el importe en Cheques de Plaza Local - 0 Hs. a Depositar.';
 elsif v_mto_che_48 is null or v_mto_che_48 < 0 then
    v_cod_respuesta := '003'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el importe en Cheques de Plaza Local - 24 Hs. a Depositar.';
 elsif v_mto_che_24 = 0 and v_mto_che_48 = 0 and v_mto_che_72 = 0 then
    v_cod_respuesta := '003'; -- error
    v_msj_respuesta := 'ERROR: Ingrese por lo menos uno de los importes.';
 else
    begin
     select a.nro_cuenta, a.monto, substr(replace(b.denominacion,'~','N'),1,45), a.cod_moneda, b.estado, b.cod_modalidad,
            a.cod_usuario, a.hora, a.fecha, a.cod_tra_padre, a.rowid
       into v_nro_cuenta, v_tot_deposito, v_denominacion, v_cod_moneda, v_est_cuenta, v_tip_cuenta,
            v_cod_usu_operacion, v_hor_operacion, v_fec_operacion, v_cod_tra_padre,
            v_rowid
       from ge_cuentas b,cj_movimientos a
      where a.estado = 'N'
        and a.tip_monto in ('O', 'T','S')
        and a.cod_tra_padre  in (215,395)
        and a.tipo = 'D'
        and a.nro_caja = to_number(p_nro_caja)
        and a.nro_documento = to_number(p_nro_boleta)
        and b.nro_cuenta(+) = a.nro_cuenta
        and exists (select 0 from cj_cajas d
                     where d.nro_caja = a.nro_caja
                       and d.tipo = 'A'
        );
    exception
       when no_data_found then
           v_cod_respuesta := '001'; -- error
           v_msj_respuesta := 'ERROR: Boleta no registrada en esta Caja. Verifique.';
       when others then
           v_cod_respuesta := '001'; -- error
           v_msj_respuesta := 'ERROR: en lectura de la Boleta '||sqlerrm;
    end;
    if nvl(v_tot_deposito,0) <> nvl(v_mto_che_24,0) + nvl(v_mto_che_48,0) + nvl(v_mto_che_72,0)then
       v_cod_respuesta := '003'; -- error
       v_msj_respuesta := 'ERROR: Total Depositado no coincide con los Detalles.';
    end if;
    if v_cod_respuesta = '000' then -- sino hubo problemas, veo la caja
        -- Verifico la duplicacion del registro
        prj_val_duplicacion(p_nro_caja,
                            v_cod_transaccion,
                            v_cod_moneda,
                            p_nro_boleta,
                            v_cod_respuesta,
                            v_msj_respuesta);
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
    end if;
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
       -- reverso el movimiento anterior ingresado en el autoservicio
       prg_rev_operacion(v_fec_operacion,
                         v_hor_operacion,
                         v_cod_usu_operacion,
                         v_cod_modulo,
                         v_cod_modalidad,
                         v_cod_tra_padre,
                         v_cod_usuario,
                         v_hor_actual,
                         'N',
                         'Detalle de la boleta'); -- No es nocturno
       v_hor_actual := pag_gen.FU_OBT_SIG_SEGUNDO(v_hor_actual);
       -- verifico los decimales del importe en cheques - 24 hs
       v_msj_respuesta := fuj_val_importe(v_tipo, v_tip_monto,v_cod_moneda,v_mto_che_24);
       if v_msj_respuesta is null then -- valido los decimales del importe en cheques - 48 hs
          v_msj_respuesta := fuj_val_importe(v_tipo, 'T',v_cod_moneda,v_mto_che_48);
       end if;
       if v_msj_respuesta is not null then
          v_cod_respuesta := '005';  -- error
       else
         -- Asigno el nro de caja a los movimientos
         pag_cta.pr_nro_caja(to_number(p_nro_caja));
         -- Actualizo la cuenta con el cheque depositado plaza local 0 hs. sino hubo errores
         v_nro_secuencia := 0;
         if v_mto_che_24 > 0 then
             pag_cta.pr_act_operacion(v_nro_cuenta,
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
                                      'Deposito en Cheq.Pl. Local-0 Hs.', --concepto
                                      'N', -- emitir aviso
                                      v_nro_secuencia, -- nro de secuencia
                                      v_fec_actual);
         end if;
         -- Actualizo la cuenta con el cheque depositado plaza local 24 hs. sino hubo errores
         if (nvl(pag_cta.g_cod_error,0)= 0 or v_mto_che_48 = 0) and v_mto_che_48 > 0 then
             pag_cta.pr_act_operacion(v_nro_cuenta,
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
                                      'Deposito en Cheq.Pl. Local-24 Hs.', --concepto
                                      'N', -- emitir aviso
                                      v_nro_secuencia, -- nro de secuencia
                                      v_fec_actual);
         end if;
         -- Actualizo la cuenta con el cheque depositado plaza local 48 hs. sino hubo errores
         if (nvl(pag_cta.g_cod_error,0)= 0 or (v_mto_che_24 = 0 and v_mto_che_48=0) ) and v_mto_che_72 > 0 then
             pag_cta.pr_act_operacion(v_nro_cuenta,
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
                                      'Deposito en Cheq.Pl. Local-48 Hs.', --concepto
                                      'N', -- emitir aviso
                                      v_nro_secuencia, -- nro de secuencia
                                      v_fec_actual);
         end if;

         if pag_cta.g_cod_error <> 0 then
            -- actualizacion con problemas
            v_cod_respuesta := ltrim(to_char(pag_cta.g_cod_error,'000'));
            v_msj_respuesta := pag_cta.g_msj_error;
         else -- genero la transaccion en caja
           lp_gen_transaccion();
         end if;        
         -------FSOP-28642 
         IF v_cod_respuesta = '000' AND nvl(pag_cta.g_cod_error, 0) =  0 then
           --debe verificar la cuenta bancaria
            BEGIN
              SELECT nro_cuenta
                INTO vp_cta_credito
                FROM cc_cta_cajeros
               WHERE nro_caja = p_nro_caja
                 AND cod_moneda = v_cod_moneda
                 AND cod_oficina  = v_cod_oficina;
            EXCEPTION
              WHEN no_data_found THEN
                 v_cod_respuesta :='006';  -- error
                 v_msj_respuesta := 'Cuenta Cajero Inexistente';
            END;
           --Obtener datos de la Cuenta
           BEGIN
             SELECT cod_modulo, cod_modalidad, cod_oficina
               INTO v_mod_cta_cre, v_mad_cta_cre, v_ofi_cta_cre
               FROM ge_cuentas
              WHERE nro_cuenta = vp_cta_credito;
              
              pag_cta.pr_obt_cuenta(vp_cta_credito);
              v_est_cta_cre := pag_cta.fu_obt_est_cuenta;
           END;
            --Cuenta Bancaria
            IF v_mod_cta_cre = 4 then 
               --Actualizar saldo retenido
                UPDATE cc_cta_bancarias
                   SET sal_retenido = nvl(sal_retenido, 0) - v_tot_cheques,
                       sal_total    = nvl(sal_total, 0) - v_tot_cheques,
                       estado       = decode(estado, 'I', 'N', estado)
                 WHERE nro_cuenta   = vp_cta_credito;
            END IF;
              
            IF v_est_cta_cre = 'I' THEN
              -- Debo cambiar el estado de la cuenta
              v_nro_secuencia         := v_nro_secuencia + 1;
              r_gmovi.nro_secuencia   := v_nro_secuencia;
              r_gmovi.monto           := NULL;
              r_gmovi.est_cuenta      := 'N';
              r_gmovi.cod_tra_padre   := 425;
              r_gmovi.cod_transaccion := 425;
              pag_gen.pr_ins_ge_movimiento(r_gmovi);
            END IF;
         END IF;
         ---Hasta aqui FSOP-28642 
         begin
           select cod_persona into v_cod_persona
             from ge_cta_clientes
            where nro_cuenta = v_nro_cuenta
              and relacion = 'P';
         exception
           when no_data_found then
             v_cod_persona := null;
           when others then
             v_cod_persona := null;
         end;

         begin
            select nvl(cli_frecuente,'N')
              into v_cli_frecuente
              from cr_inf_fondos
             where cod_persona = v_cod_persona;
          exception
            when no_data_found then
              null;
            when others then
              null;
          end;
          if v_cli_frecuente is null then
            v_cli_frecuente := 'N';
          end if;
         --
         if v_cod_respuesta = '000' then
            -- sumo el total de deposito
            v_tot_deposito := nvl(v_tot_cheques,0);
            /*if pag_gen.FU_CON_MON_A_MONEDA(v_cod_moneda, -- moneda origen
                                           pag_gen.FU_OBT_MON_FUERTE, -- moneda dolar
                                           v_tot_deposito) >= fug_obt_pardinamico('OPE_SUP_MON_FUERTE') then*/
          -- CRO-JM-03/2015: CROGEFIT-3
            if fuj_ver_imp_formulario(v_nro_cuenta,
                                      v_cod_persona,
                                      pag_gen.fu_con_mon_a_moneda(v_cod_moneda,              -- moneda origen
                                                                  pag_gen.fu_obt_mon_fuerte, -- moneda dolar
                                                                  v_tot_deposito),
                                      v_cod_transaccion,
                                      v_mto_calculado) then
               -- paso el monto minimo a informar. Generar el informe de operaciones > a USD 10000
               v_cod_respuesta := 'IMP'; -- para indicar que esta ok y se puede imprimir
               if v_cli_frecuente = 'N' then
                 v_msj_respuesta := 'Operacion Confirmada. Decl.Jurada y Comprobante impresos.'||'~'||
                 fuj_imp_dec_jurada_40(v_fec_actual, v_hor_actual, user, null, v_mto_calculado, v_cod_transaccion)/*||
                 fuj_imp_comprobante_351(p_nro_boleta, v_cod_oficina, p_nro_caja)*/;
                  -- CRO-JM-03/2015: CROGEFIT-3 insertamos en la tabla como ya impreso:
                        prj_ins_form_transacciones(v_nro_cuenta,
                                                   v_cod_persona,
                                                    v_cod_modulo,
                                                    v_cod_transaccion,
                                                    USER,
                                                    v_fec_actual,
                                                    v_hor_actual,
                                                    pag_gen.fu_obt_mon_fuerte,
                                                    pag_gen.fu_con_mon_a_moneda(v_cod_moneda,              -- moneda origen
                                                                               pag_gen.fu_obt_mon_fuerte, -- moneda dolar
                                                                               v_tot_deposito),
                                                    'S');
               else
                 v_msj_respuesta := 'Operacion Confirmada.';
                  -- CRO-JM-03/2015: CROGEFIT-3 insertamos en la tabla como ya impreso:
                        prj_ins_form_transacciones(v_nro_cuenta,
                                                   v_cod_persona,
                                                    v_cod_modulo,
                                                    v_cod_transaccion,
                                                    USER,
                                                    v_fec_actual,
                                                    v_hor_actual,
                                                    pag_gen.fu_obt_mon_fuerte,
                                                    pag_gen.fu_con_mon_a_moneda(v_cod_moneda,              -- moneda origen
                                                                               pag_gen.fu_obt_mon_fuerte, -- moneda dolar
                                                                               v_tot_deposito),
                                                    'N');
               end if;
               -- retorno de la rutina de impresion
                  v_msj_salida := p_nro_operacion||'~'||
                                  v_cod_respuesta||'~'||
                                  v_msj_respuesta;
                  return(v_msj_salida);
            /*else--solo comprobante
               v_cod_respuesta := 'IMP'; -- para indicar que esta ok y se puede imprimir
               v_msj_respuesta := 'Operacion Confirmada. Comprobante ha sido impreso.'||'~'||
               fuj_imp_comprobante_351(p_nro_boleta, v_cod_oficina, p_nro_caja);
               -- retorno de la rutina de impresion
                v_msj_salida := p_nro_operacion||'~'||
                                v_cod_respuesta||'~'||
                                v_msj_respuesta;*/
            else
               -- CRO-JM-03/2015: CROGEFIT-3 insertamos en la tabla como ya impreso:
                        prj_ins_form_transacciones(v_nro_cuenta,
                                                   v_cod_persona,
                                                    v_cod_modulo,
                                                    v_cod_transaccion,
                                                    USER,
                                                    v_fec_actual,
                                                    v_hor_actual,
                                                    pag_gen.fu_obt_mon_fuerte,
                                                    pag_gen.fu_con_mon_a_moneda(v_cod_moneda,              -- moneda origen
                                                                               pag_gen.fu_obt_mon_fuerte, -- moneda dolar
                                                                               v_tot_deposito),
                                                    'N');
            end if;
         end if;
      end if;
    end if;
 end if;
 -- mensaje final sino hubo errores
 if v_cod_respuesta = '000' then -- sino hubo problemas, se carga mensaje por defecto
    v_msj_respuesta := 'Operacion confirmada';
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
end FUJ_PRO_TRANSACCION_217;
/
