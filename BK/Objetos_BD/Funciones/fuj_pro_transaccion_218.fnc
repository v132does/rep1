CREATE OR REPLACE FUNCTION IT.FUJ_PRO_TRANSACCION_218
 (P_NRO_OPERACION   IN VARCHAR2,
 P_NRO_CAJA        IN NUMBER,
 P_COD_TELEGRAMA    IN NUMBER,
 p_mto_efectivo in number default null, --total efectivo
 p_nro_che_nstro in varchar2 default null,  --nro cheq ntro bco
 p_mto_che_nstro in number default null, --total cheq nstro bco
 -- Agregado para detalle de cheques, si es uno solo,(de despliegue x defecto)
 p_tip_retencion in number default null, --retencion
 p_nro_cheque    in varchar2 DEFAULT NULL,  -- numero de cheque
 p_mto_cheque    in number default null,  -- total de cheq 24 hs
 p_cod_banco     in varchar2 DEFAULT NULL)  -- codigo del banco
 RETURN long IS
  -- defino por defecto el modulo y modalidad a utilizar
  v_cod_modulo      number(3)      := 9;    -- Caja
  v_cod_modalidad   number(3)      := 91;   -- Caja
  v_cod_transaccion number(4)      := 218;  -- transaccion
  v_cod_usuario     varchar2(10);--   := upper(user); --usuario

  -- Datos de la caja
  v_fec_actual        date         := pag_cal.fu_obt_fec_actual(v_cod_modulo); -- fecha de hoy
  v_hor_actual        varchar2(08) := to_char(sysdate,'HH24:MI:SS');   -- Hora actual
  v_cod_oficina       number(3);         -- Codigo de oficina
  v_estado            number(1);         -- estado de la caja
  v_fec_caja          date;              -- fecha de la caja
  v_sal_actual        number(18,2);      -- saldo actual de la caja en efectivo
  v_sal_cheques       number(18,2);      -- saldo actual de la caja en cheques
  -- Datos de la cuenta
  v_cod_moneda        varchar2(3);       -- moneda de la cuenta

  -- Datos de salida
  v_msj_salida    varchar2(8000);                          -- mensaje final retornado
  v_cod_respuesta varchar2(03) := '000';                   -- sin errores
  v_msj_respuesta varchar2(4000) := 'Operacion Confirmada'; -- sin errores

  -- datos de la operacion convertidos
  v_tipo          varchar2(01) := 'D' ;     -- 'C' credito para la caja (egreso) o vice versa
  v_tip_monto     varchar2(01) := 'O';       -- E efectivo / O cheque otros Bcos
  v_nro_secuencia number(3) := 0;           -- secuencia del mov.

  -- datos que se cargan en la pantalla
  v_sal_multa     number(18,2) :=0;
  v_mto_cobrado   number(18,2) := nvl(p_mto_efectivo,0) + nvl(p_mto_cheque,0) + nvl(p_mto_che_nstro,0);
  -- datos fijos de la cuenta de credito
  v_nro_cta_mjt          varchar2(15) := '1020448'; -- cuenta del ministerio de just. trabajo

  v_ubi_banco      ge_bancos.ubicacion%type;
  v_des_banco      ge_bancos.descripcion%type;
  v_cod_tra_cheque ge_movimientos.cod_transaccion%type;
  v_cta_cheque     cc_chequeras.nro_cuenta%type;
  v_mon_fuerte     ge_movimientos.cod_moneda%type := pag_gen.FU_OBT_MON_FUERTE;
  v_cli_frecuente  cr_inf_fondos.cli_frecuente%type;
  v_cod_persona    ge_cta_clientes.cod_persona%type;
  -- Procedimiento interno para generar movimiento y act. de control de caja
  procedure lp_gen_transaccion  is
  begin
      -- Actualizo el control de caja
       update cj_controles
         set tot_che_otr_bco = nvl(tot_che_otr_bco,0) + nvl(p_mto_cheque,0),
             sal_che_otr_bco = nvl(sal_che_otr_bco,0) + nvl(p_mto_cheque,0),
             tot_che_nue_bco = nvl(tot_che_nue_bco,0) + nvl(p_mto_che_nstro,0),
             sal_actual = nvl(sal_actual,0) + nvl(p_mto_efectivo,0),
             tot_debitos = nvl(tot_debitos,0) + nvl(p_mto_efectivo,0),
             can_debitos = nvl(can_debitos,0) + decode(p_mto_efectivo,0,0,1),
             estado = 1 -- abierto
       where nro_caja = to_number(p_nro_caja)
         and cod_moneda = v_cod_moneda
         and fecha = v_fec_caja;

      v_nro_secuencia := 0;

      if p_mto_efectivo > 0 then
        -- genero el movimiento por el efectivo
        v_nro_secuencia := v_nro_secuencia + 1;
        insert into cj_movimientos
           (nro_cuenta,fecha, hora, cod_usuario, nro_secuencia,
            cod_tra_padre, cod_mod_padre, cod_mad_padre,
            cod_oficina, cod_moneda, nro_caja,
            nro_documento, monto, tip_monto, tipo)
        values
           (v_nro_cta_mjt, v_fec_actual, v_hor_actual, v_cod_usuario, v_nro_secuencia,
            v_cod_transaccion,v_cod_modulo, v_cod_modalidad,
            v_cod_oficina, v_cod_moneda, to_number(p_nro_caja),
            p_cod_telegrama, p_mto_efectivo,'E', v_tipo);  -- es debito
      end if;
      if p_mto_che_nstro > 0 then
        -- genero el movimiento por el deposito en cheques nstro bco (local)
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
            p_cod_telegrama, v_nro_cta_mjt, p_mto_che_nstro,'C' /* cheq.nuestro bcos */, v_tipo); /* es debito */
      end if;
      if p_mto_cheque > 0 then
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
            p_cod_telegrama, v_nro_cta_mjt, p_mto_cheque,v_tip_monto /* cheq.otros bcos */, v_tipo); /* es debito */
      end if;
  end lp_gen_transaccion;
---------------- INICIO DEL PROCESO PRINCIPAL ------------------

----
Begin
 -- Inicializacion de la aplicacion y el modulo
 Begin PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=v_cod_modulo; End;
 -- Valido la moneda
 if p_cod_telegrama is null then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el Numero de Telegrama.';
 end if;

 if v_cod_respuesta = '000' then
   --validar los datos ingresados
   v_msj_salida:= FUJ_VAL_TRANSACCION_218(p_nro_operacion, p_nro_caja, p_cod_telegrama,
                                          p_mto_efectivo, p_nro_che_nstro, p_mto_che_nstro,
                                          p_tip_retencion, p_nro_cheque, p_mto_cheque, p_cod_banco);
   if v_msj_salida NOT LIKE '%~OK~%' THEN
      return v_msj_salida;
   END IF;
 end if;

 if v_cod_respuesta = '000' then -- sino hubo problemas, verifico el servicio
    begin
      Select cod_moneda
        into v_cod_moneda
        from ba_personas b, ge_telegramas a
       where a.cod_telegrama = p_cod_telegrama
         and a.cod_persona = b.cod_persona;
      select sum(nvl(b.sal_multa,0))
        into v_sal_multa
        from cc_che_devueltos b, ge_telegramas_det a
       where a.nro_cuenta = b.nro_cuenta
         and a.nro_cheque = b.nro_cheque
         and a.fecha = b.fecha
         and a.hora = b.hora
         and a.cod_telegrama = p_cod_telegrama;
      if v_sal_multa <= 0 then
         v_cod_respuesta := '002';
          v_msj_respuesta := 'Telegrama no registra Multa Pendiente';
      end if;
      if v_sal_multa  <> v_mto_cobrado then
         v_cod_respuesta := '004'; -- error
         v_msj_respuesta := 'ERROR: Monto Total no suma Detalles.';
      end if;
      if v_cod_moneda <> pag_gen.FU_OBT_MON_LOCAL then
          -- cambio la cuenta si es usd
          v_nro_cta_mjt := '7030562';
      end if;
    exception
       when no_data_found then
          v_cod_respuesta := '002';
          v_msj_respuesta := 'Telegrama no identificado';
       when others then
          v_cod_respuesta := '003';
          v_msj_respuesta := sqlerrm;
    end;
    if v_cod_respuesta = '000' then
       -- Obtengo los datos de la caja --
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
          v_msj_respuesta := 'Realice la Apertura de Caja previamente.';
       elsif v_fec_caja <> v_fec_actual then
          v_cod_respuesta := '005'; -- error
          v_msj_respuesta := 'Caja no fue habilitada el dia de hoy';
       end if;
    end if;
 end if;

 if v_cod_respuesta = '000' then
   if p_cod_banco is not null /*and p_nro_cheque is not null*/ then
      --determinar si el banco es local o extranjero
      begin
        select ubicacion, descripcion
          into v_ubi_banco, v_des_banco
         from ge_bancos
         where cod_banco = p_cod_banco
           and estado = 'A';
         if p_cod_banco = fug_obt_cod_banco then -- no puede ser nuestro bco
            v_cod_respuesta := '099'; -- error
            v_msj_respuesta := 'ERROR: El Cheque no puede ser de Nuestro Bco';
         end if;
      exception
         when no_data_found then
           v_cod_respuesta := '094'; -- error
           v_msj_respuesta := 'ERROR: Codigo de Banco inexistente.';
         when others then
           v_cod_respuesta := '090'; -- error
           v_msj_respuesta := 'ERROR: Codigo de Banco invalido.';
      end;
   end if;
 end if;
 --- Insertar el cobro del servicio
 v_cod_usuario   := upper(user);
 --dependiendo de la forma de cobro, se acredita a la cuenta...
 if v_cod_respuesta = '000' then -- sino hubo ERROR se arma los datos para grabar
   -- Asigno el nro de caja a los movimientos
   pag_cta.pr_nro_caja(to_number(p_nro_caja));

   -- si es efectivo
   if p_mto_efectivo > 0 then
      -- PROCESAR_CREDITO_AHORRO_VISTA y PROCESAR_CREDITO_CTA_CORRIENTE
      pag_cta.pr_act_operacion( v_nro_cta_mjt,
                         v_hor_actual,
                         'C',
                         v_cod_moneda,           ---ver
                         p_mto_efectivo,
                         v_cod_transaccion,  ---ver
                         690, --trans.hijo. depósito en efectivo
                         p_cod_telegrama,
                         null,
                         v_cod_oficina,
                         9,
                         91,
                         NULL,
                         NULL,
                         'Credito p/Cobro de Multa',
                         'S',
                         v_nro_secuencia,
                         v_fec_actual,
                         NULL,
                         NULL );
      If pag_cta.fu_obt_cod_error() <> 0 THEN
         v_cod_respuesta := '011';
         v_msj_respuesta := 'Efec. '||pag_cta.fu_obt_msj_error();
      End if;
   end if;
 end if;
 if v_cod_respuesta = '000' then -- sino hubo ERROR se arma los datos para grabar
   --si es cheque nstro banco
   if p_mto_che_nstro > 0 then
       v_nro_secuencia := nvl(v_nro_secuencia,0) + 1;
       pag_cta.pr_act_operacion(v_nro_cta_mjt,
                                v_hor_actual,
                               'C', -- credito
                                v_cod_moneda,
                                p_mto_che_nstro,
                                v_cod_transaccion,
                                606, -- trans. hijo de cheq.nuestro bco
                                p_cod_telegrama,
                                null, -- cotizacion
                                v_cod_oficina,
                                9,
                                91,
                                null, -- tasa
                                null, -- valor de tasa
                                'Cobro de Multa en Chq./Ntro', --concepto
                                'S', -- emitir aviso
                                v_nro_secuencia, -- nro de secuencia
                                v_fec_actual);
       IF PAG_CTA.FU_OBT_COD_ERROR() <> 0 THEN
         v_cod_respuesta := '033';
         v_msj_respuesta := 'Cred.Cheq. '||pag_cta.fu_obt_msj_error();
      END IF;
   end if;
 end if;
 if v_cod_respuesta = '000' then -- sino hubo ERROR se arma los datos para grabar
   if p_mto_cheque > 0 then
         --depende del tipo de retención
      if nvl(p_tip_retencion,1) = 1 then
         v_cod_tra_cheque := 607; --- Cheques
         v_tip_monto := 'O';
      elsif p_tip_retencion = 2 then
         v_cod_tra_cheque := 610; --- Cheques
         v_tip_monto := 'T';
      elsif p_tip_retencion = 3 then
         v_cod_tra_cheque := 632; --- Cheques
         v_tip_monto := 'S';
      end if;

      v_nro_secuencia := nvl(v_nro_secuencia,0) + 1;
      pag_cta.pr_act_operacion(v_nro_cta_mjt,
                                v_hor_actual,
                               'C', -- credito
                                v_cod_moneda,
                                p_mto_cheque,
                                v_cod_transaccion,
                                v_cod_tra_cheque, -- trans. hijo de cheq.otros bcos
                                p_cod_telegrama,
                                null, -- cotizacion
                                v_cod_oficina,
                                9,
                                91,
                                null, -- tasa
                                null, -- valor de tasa
                                'Cobro de Multa en Che.Otr.Bco', --concepto
                                'N', -- emitir aviso
                                v_nro_secuencia, -- nro de secuencia
                                v_fec_actual);
       IF PAG_CTA.FU_OBT_COD_ERROR() <> 0 THEN
         v_cod_respuesta := '023';
         v_msj_respuesta := 'Cred.Cheq. '||pag_cta.fu_obt_msj_error();
      END IF;
   end if;
 end if;--rta 000, cheq otros bancos

 if v_cod_respuesta = '000' then -- sino hubo ERROR se arma los datos para grabar
   -- actualizo los montos cobrados en cheques
   update ge_telegramas_det a
      set mto_pagado  = (select nvl(b.sal_multa,0)
                           from cc_che_devueltos b
                          where a.nro_cuenta = b.nro_cuenta
                            and a.nro_cheque = b.nro_cheque
                            and a.fecha = b.fecha
                            and a.hora = b.hora)
    where a.cod_telegrama = p_cod_telegrama;
   -- actualizo el monto como cobrado
   update cc_che_devueltos b
      set sal_multa = 0
    where exists (select 0 from ge_telegramas_det a
                   where a.nro_cuenta = b.nro_cuenta
                     and a.nro_cheque = b.nro_cheque
                     and a.fecha = b.fecha
                     and a.hora = b.hora
                     and a.cod_telegrama = p_cod_telegrama);
   --actualizar caja
   lp_gen_transaccion;
 end if;

    if v_cod_respuesta = '000' then
       if p_cod_banco is not null and p_nro_cheque is not null and p_mto_cheque > 0 then
          --si el banco es local -> 133
           if v_ubi_banco = 'L' then
              --solo si la retención es > 1
              if p_tip_retencion > 1 then
                 v_msj_salida := fuj_pro_transaccion_133(p_nro_operacion,
                                                      p_nro_caja,
                                                      p_cod_telegrama,
                                                      p_tip_retencion,
                                                      p_cod_banco,
                                                      p_nro_cheque,
                                                      p_mto_cheque);
                 --return (v_msj_salida); -- retorna directamente el mensaje
                 if v_msj_salida NOT LIKE '%~000~%' THEN
                    return v_msj_salida;
                 END IF;
              end if;
          else  --si es extranjero -> 134,
             v_msj_salida := fuj_pro_transaccion_134(p_nro_operacion,
                                                  p_nro_caja,
                                                  p_cod_telegrama,
                                                  p_cod_banco,
                                                  v_des_banco,
                                                  p_nro_cheque,
                                                  p_mto_cheque);
             --return (v_msj_salida); -- retorna directamente el mensaje
             if v_msj_salida NOT LIKE '%~000~%' THEN
                return v_msj_salida;
             END IF;
          end if;
       end if;
    end if;
	--CROEFEBCO-28: Mejoras en la Operativa de Efectivo, cometado porque el cheque se debe detallar por la 355 pasandole Nro. de Serie
   /*if v_cod_respuesta = '000' then
       --cheque ntro banco
       if nvl(p_mto_che_nstro,0) > 0 and nvl(p_nro_che_nstro,0) > 0  then
           --busco la cuenta de cc_chequeras
          begin
            select nro_cuenta
            into v_cta_cheque
            from cc_chequeras
            where p_nro_che_nstro between nro_che_inicial and nro_che_final;
          exception
            when too_many_rows then
              v_cod_respuesta := '066'; -- error
              v_msj_respuesta := 'ERROR: Varios cheques encontrados';
            when others then
              v_cod_respuesta := '067'; -- error
              v_msj_respuesta := 'ERROR: Recuperar Cheque '||sqlerrm;
          end;
          if v_cod_respuesta = '000' then
              -- se detallo el cheque, se procesa el detalle del mismo
              v_msj_salida := fuj_pro_transaccion_355(p_nro_operacion,
                                                   p_nro_caja,
                                                   p_cod_telegrama,
                                                   p_nro_che_nstro,
                                                   v_cta_cheque, --cuenta
                                                   p_mto_che_nstro,
                                                   pag_gen.FU_OBT_SIG_SEGUNDO(pag_gen.FU_OBT_SIG_SEGUNDO(v_hor_actual)));
              --return (v_msj_salida); -- retorna directamente el mensaje
              if v_msj_salida NOT LIKE '%~000~%' THEN
                 return v_msj_salida;
              END IF;
          end if;
       end if;
   end if;*/
   begin
     select cod_persona into v_cod_persona
     from ge_cta_clientes
     where nro_cuenta = v_cta_cheque
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
   -- mensaje final sino hubo errores
   --imprimir comprobante
   if v_cod_respuesta = '000' then
      --si la operación es superior avisar q se imprima la declaración x gestión
      if pal_Cam.FU_CON_MON_A_MONEDA(v_cod_moneda,v_mon_fuerte,v_mto_cobrado) >= fug_obt_pardinamico('OPE_SUP_MON_FUERTE') then
        if v_cli_frecuente = 'N' then
         v_cod_respuesta := 'IMP';
         v_msj_respuesta := 'Operación Confirmada. Comprobante y Decl.Jurada impresos. Oper.Nro. '||p_cod_telegrama||'~'||
                          fuj_imp_comprobante_218(p_cod_telegrama, v_cod_oficina, p_nro_caja)||
                          fuj_imp_dec_jurada_40(v_fec_actual, v_hor_actual, user, 1);
        else
          v_cod_respuesta := 'IMP';
          v_msj_respuesta := 'Operación Confirmada. Comprobante impreso.'||'~'||
                               fuj_imp_comprobante_218(p_cod_telegrama, v_cod_oficina, p_nro_caja);
        end if;
      else
         v_cod_respuesta := 'IMP';
         v_msj_respuesta := 'Operación Confirmada. Comprobante impreso.'||'~'||
                               fuj_imp_comprobante_218(p_cod_telegrama, v_cod_oficina, p_nro_caja);
      end if;
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
end FUJ_PRO_TRANSACCION_218;
/

