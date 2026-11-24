create or replace function it.FUJ_PRO_TRANSACCION_371(
      p_nro_operacion in varchar2, -- Nro de referencia de la operación
      p_nro_caja in varchar2,      -- Nro de Caja
      p_nro_boleta in number,      -- Nro de la boleta de depósito
      p_cod_ente in number,
      p_depositante in number default null,
      p_cod_moneda in varchar2 default pag_gen.fu_obt_mon_local,
      p_nro_cuenta in varchar2 default null,
      p_nro_cheque in number default null,
      p_serie in varchar2 default null,
      p_tot_deposito in number default null,
      p_mto_efectivo in number default null,
      p_mto_cheques in number default null,
      p_ref_pago in varchar2 default null,
      p_det_mto_cheque in number default null
      )
return long is
  --- defino por defecto el modulo y modalidad a utilizar
  v_cod_modulo       number(3) := 9;    -- Caja
  v_cod_modalidad    number(3) := 91;   -- Caja
  v_cod_transaccion  number(4) := 371;  -- transaccion
  v_cod_usuario      varchar2(10) := upper(user); --usuario
  -- Datos de la caja
  v_fec_actual       date := pag_cal.fu_obt_fec_actual(v_cod_modulo); -- fecha de hoy
  v_hor_actual       varchar2(08) := to_char(sysdate,'HH24:MI:SS');   -- Hora actual
  v_cod_oficina      number(3);         -- Codigo de oficina
  v_estado           number(1);         -- estado de la caja
  v_fec_caja         date;              -- fecha de la caja
  v_sal_actual       number(18,2);          -- saldo actual de la caja en efectivo
  v_sal_cheques      number(18,2);          -- saldo actual de la caja en cheques
  -- Datos de la cuenta
  v_nro_cuenta       ge_cuentas.nro_cuenta%type;
  v_denominacion     varchar2(200);     -- Nombre de la cuenta
  v_cod_moneda       varchar2(3);       -- moneda de la cuenta
  v_est_cuenta       varchar2(1);       -- estado de la cuenta
  v_cod_mod_cuenta   number(4);         -- modulo de la cuenta
  v_cod_mad_cuenta   number(4);         -- modalidad de la cuenta
  v_cod_ofi_cuenta   number(4);         -- oficina de la cuenta
--  v_capital          number(18,2);      -- capital de cda
 -- v_fec_apertura     date;              -- fecha de apertura
--  v_est_certificado  varchar2(01);      -- estado del cda
  v_cli_frecuente    varchar2(1) := 'N';
  -- Datos de salida
  v_msj_salida       long;        -- mensaje final retornado
  v_cod_respuesta    varchar2(03) := '000'; -- sin errores
  v_msj_respuesta    varchar2(4000) := null; -- sin errores
  -- datos de la operacion convertidos
  v_tipo             varchar2(01) := 'D';  -- Debito para la caja (ingreso)
  v_tip_monto        varchar2(01) := 'C';  -- Cheq. nuestro banco
  v_mto_cheque       number := nvl(to_number(p_mto_cheques),0); -- importe del deposito en cheques
  v_mto_efectivo     number := nvl(to_number(p_mto_efectivo),0); -- importe del deposito en efectivo
  v_nro_secuencia    number(3) := 0;  -- secuencia del mov.
  v_tot_deposito     number(18,2);  -- total de deposito
  v_tot_en_usd       number;
  v_nro_boleta       number := to_number(p_nro_boleta); --Numbero de boleta
  --
  -- datos calculados
  r_gmovi             ge_movimientos%rowtype;
  v_cod_tra_cargo     number := 598; -- transaccion por cargo
  v_tot_cargo         number := 0;   -- monto del cargo + impuesto
  v_tot_efectivo      number := 0;   -- deposito en efectivo + cargos
  v_cod_tas_cargo     number;
  v_val_tas_cargo     number;
  v_val_cargo         number;
  v_cod_tra_impuesto  number;
  v_cod_tas_impuesto  number;
  v_val_tas_impuesto  number;
  v_val_impuesto      number;
--  v_can_cupones       number;
  v_saldo             number;
  v_cod_persona       ba_personas.cod_persona%type;
--  v_mon_sup_mov       number(18,2);
 -- v_men_res_imp       varchar2(4000);
  v_cod_cau_judicial  ge_causales.cod_causa%type := fug_obt_pardinamico('COD_CAU_DEM_JUDICIAL');
   -- C.D. Fase III--
  v_tip_operacion   ge_mov_autorizaciones.tip_operacion%type := 'O';-- Todos Tipos Operacional
  v_est_movimiento  ge_movimientos.estado%type;
  v_nro_pedido    ge_mov_autorizaciones.nro_pedido%type;
  v_tot_total       ge_movimientos.monto%type; -- Total Monto Depositado
  v_det_cheque      varchar2(1) := 'N';
  v_existe          varchar2(1) := 'N';
  
  v_mto_calculado   number;-- declaracion jurada FIT
  v_impreso         varchar(1)  := 'N'; -- declaracion jurada FIT -> "N" solo insertará, "S" insertará e imprimirá.

  -- Procedimiento interno para generar movimiento y act. de control de caja
  procedure lp_gen_transaccion (p_estado varchar2)  is
  begin
      -- Actualizo el control de caja
      if p_estado <> 'P' then -- C.D.Fase III
        update cj_controles
           set tot_che_nue_bco = nvl(tot_che_nue_bco,0) + nvl(v_mto_cheque,0),
               sal_actual = nvl(sal_actual,0) + nvl(v_tot_efectivo,0),
               tot_debitos = nvl(tot_debitos,0) + nvl(v_tot_efectivo,0),
               can_debitos = nvl(can_debitos,0) + decode(v_mto_efectivo,0,0,1) +
                                                  decode(v_tot_cargo,0,0,1),
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
      if v_mto_cheque > 0 then
        -- genero el movimiento por el deposito en cheques (local)
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
            v_nro_boleta, v_nro_cuenta, v_mto_cheque,v_tip_monto /* cheq.nuestro bcos */, v_tipo, p_estado); /* es debito */
      end if;
      if v_tot_cargo > 0 then
        -- genero el movimiento por el cargo
        v_nro_secuencia := v_nro_secuencia + 1;
        insert into cj_movimientos
           (fecha, hora, cod_usuario, nro_secuencia,
            cod_tra_padre, cod_mod_padre, cod_mad_padre,
            cod_oficina, cod_moneda, nro_caja,
            nro_documento, nro_cuenta, monto, tip_monto, tipo, estado)-- C.D.Fase III
        values
           (v_fec_actual, v_hor_actual, v_cod_usuario, v_nro_secuencia, -- secuencia 3
            v_cod_tra_cargo, v_cod_mod_cuenta, v_cod_mad_cuenta,
            v_cod_oficina, v_cod_moneda, to_number(p_nro_caja),
            v_nro_boleta, v_nro_cuenta, v_tot_cargo,'E' /* efectivo */, v_tipo, p_estado);  --es debito
      end if;
      
      -- Registro del movimiento en ge_rec_movimientos
      insert into ge_rec_movimientos
         (cod_ente, fec_operacion, hora, 
          depositante, nro_cta_credito, cod_moneda, 
          tot_deposito, mto_efectivo, mto_che_cnb, 
          mto_che_cob, estado, ref_pago, 
          nro_operacion, cod_oficina)
      values
         (p_cod_ente, v_fec_actual, v_hor_actual,
          p_depositante, v_nro_cuenta, p_cod_moneda,
          p_tot_deposito, p_mto_efectivo, p_mto_cheques,
          0, 'N', p_ref_pago,
          p_nro_boleta, v_cod_oficina);
      
  end lp_gen_transaccion;
  --
  procedure lp_act_can_impresion is  -- C.D.Fase III--

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

 if p_nro_boleta is null then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el Nro. de Boleta.';
 elsif p_cod_ente is null then  -- valido la cuenta
    v_cod_respuesta := '002'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el código de Ente Recaudador.';
 elsif v_mto_cheque is null or v_mto_cheque < 0 then
    v_cod_respuesta := '003'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el importe en Cheques a Depositar.';
 elsif v_mto_efectivo is null or v_mto_efectivo < 0 then
    v_cod_respuesta := '003'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el importe en Efectivo a Depositar.';
 elsif v_mto_cheque = 0 and v_mto_efectivo = 0  then
    v_cod_respuesta := '003'; -- error
    v_msj_respuesta := 'ERROR: Ingrese por lo menos uno de los importes.';
 elsif v_mto_cheque > 0 and v_nro_boleta is null then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el Nro. de Boleta.';
 elsif nvl(p_tot_deposito,0) <> nvl(v_mto_cheque,0) + nvl(v_mto_efectivo,0) then
    v_cod_respuesta := '003'; -- error
    v_msj_respuesta := 'ERROR: Total Depositado no coincide con los Detalles.';
 elsif nvl(v_mto_cheque,0) > 0 and nvl(p_det_mto_cheque,0) = 0 then
    v_cod_respuesta := '003'; -- error
    v_msj_respuesta := 'ERROR: Se debe ingresar le Monto para el Detalle de Cheques.';
 elsif nvl(v_mto_cheque,0) > 0 and nvl(p_det_mto_cheque,0) > 0
   and p_nro_cheque is null then
    v_cod_respuesta := '003'; -- error
    v_msj_respuesta := 'ERROR: Se debe ingresar el Número del Cheque.';
 elsif nvl(v_mto_cheque,0) > 0 and nvl(p_det_mto_cheque,0) > 0
   and p_nro_cuenta is null then
    v_cod_respuesta := '003'; -- error
    v_msj_respuesta := 'ERROR: Se debe ingresar el Número de Cuenta.';
 elsif nvl(v_mto_cheque,0) > 0 and nvl(p_det_mto_cheque,0) > 0
   and p_serie is null then
    v_cod_respuesta := '003'; -- error
    v_msj_respuesta := 'ERROR: Se debe ingresar la serie del Cheque.';
 else
     -- Validación de parámetros del Ente.
    if p_cod_moneda is not null then
      if p_cod_moneda = pag_gen.fu_obt_mon_local then
        v_nro_cuenta  := fug_obt_parentes(p_cod_ente,'NRO_CTA_CRE_GS');
        if v_nro_cuenta is null then
          v_cod_respuesta := 010;
          v_msj_respuesta := 'Número de Cuenta no definido para la Moneda '||p_cod_moneda||'.';
        end if;
      else
        v_nro_cuenta := fug_obt_parentes(p_cod_ente,'NRO_CTA_CRE_USD');
        if v_nro_cuenta is null then
          v_cod_respuesta := 011;
          v_msj_respuesta := 'Número de Cuenta no definido para la Moneda '||p_cod_moneda||'.';
        end if;
      end if;
        
    end if;
    -- obtengo datos de la cuenta  ------------------------------------------
    begin
      select a.denominacion, a.cod_moneda, a.estado, a.cod_modalidad, a.cod_modulo,
             a.cod_oficina, c.cod_persona
        into v_denominacion, v_cod_moneda, v_est_cuenta, v_cod_mad_cuenta,
             v_cod_mod_cuenta, v_cod_ofi_cuenta, v_cod_persona
         from ge_cuentas a ,ge_cta_clientes c
         where a.nro_cuenta = v_nro_cuenta
         and a.nro_cuenta = c.nro_cuenta
         and c.relacion = 'P';
     
     if v_cod_moneda != p_cod_moneda then
       v_cod_respuesta := '003';
       v_msj_respuesta := 'ERROR: Moneda de la Cuenta no corresponde a la Moneda de la Operación.';
     end if;
     ---Verifica si el Cliente o un Vinculado a la Cuenta está inhibido y la causa es por Demanda Judicial --CROCLIJUD-5
     if fug_obt_inhibicion(v_cod_cau_judicial,v_cod_persona, v_nro_cuenta) Then
           v_cod_respuesta := '007';
           v_msj_respuesta := 'ERROR: Cliente Principal o Vinc. a la Cuenta con Demanda Judicial. Consulte con el asesor Jurídico';
     End If;

      if v_cod_mad_cuenta not in (31,41) then
        v_cod_respuesta := '003';
        v_msj_respuesta := 'ERROR: Tipo de cuenta no permite Depositos';
      else
        if v_cod_mad_cuenta = 41 then--si es cta cte verifica el saldo
            select nvl(sal_total,0) - nvl(sal_retenido,0) - nvl(sal_bloqueado,0)
              into v_saldo
              from cc_cta_corrientes
             where nro_cuenta = v_nro_cuenta;
        end if;
        If v_nro_boleta is not null then
          -- Verifico la duplicacion del registro
          prj_val_duplicacion(p_nro_caja,
                              v_cod_transaccion,
                              v_cod_moneda,
                              v_nro_boleta,
                              v_cod_respuesta,
                              v_msj_respuesta);
        End if;
        --
        if v_msj_respuesta = 'Documento ya ingresado al sistema.' and p_det_mto_cheque > 0 then
          begin
            select distinct 'S'
              into v_existe
              from cc_che_pagados a
             where a.nro_cheque = p_nro_cheque
               and a.nro_cuenta = p_nro_cuenta
               and a.fecha = v_fec_actual;
          exception
            when no_data_found then
              v_existe := 'N';
            when others then
              v_existe := 'N';
          end;
          if nvl(v_existe,'N') = 'S' then
            v_cod_respuesta := '005';
          else
            v_cod_respuesta := '000';
            v_msj_respuesta := null;
            begin
              Select a.estado
                into v_est_movimiento
                from cj_movimientos a
               where nro_caja = p_nro_caja
                 and cod_tra_padre = v_cod_transaccion
                 and cod_moneda = v_cod_moneda
                 and nro_documento = p_nro_boleta
                 and estado IN ('N','P')
                 and rownum = 1;
            exception
              when others then
                v_est_movimiento := 'N';
            end;
            --          
            v_det_cheque := 'S';
            goto detalle;
          end if;
        end if;
        --
        if v_cod_respuesta = '000' then
           v_msj_respuesta := fuj_ver_impedimentos(v_nro_cuenta,
                                                   v_cod_mad_cuenta,
                                                   v_cod_transaccion,
                                                   v_est_cuenta,
                                                  'C'); -- 'C'== CREDITO
           if v_msj_respuesta is not null then
              if v_cod_mad_cuenta = 41 and v_msj_respuesta like 'Cuenta esta pendiente de Cancelacion' then
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
      if FUG_OBT_INHIBICION(v_cod_persona,fug_obt_pardinamico('COD_CAU_DEM_JUDICIAL')) Then
         v_cod_respuesta := '004';
         v_msj_respuesta := 'ERROR. Persona con Demanda Judicial. Consulte con el asesor Jurídico';
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
       -- verifico los decimales del importe en cheques
       v_msj_respuesta := fuj_val_importe(v_tipo, v_tip_monto,v_cod_moneda,v_mto_cheque);
       if v_msj_respuesta is null then -- valido el efectivo
          v_msj_respuesta := fuj_val_importe(v_tipo, 'E',v_cod_moneda,v_mto_efectivo);
       end if;

       if v_msj_respuesta is not null then
          v_cod_respuesta := '005';  -- error
       else
          -- Asigno el nro de caja a los movimientos
          pag_cta.pr_nro_caja(to_number(p_nro_caja));
          -- Verifico el Monto de Riesgo -- C.D Fase III
          v_tot_total :=  nvl(v_mto_efectivo,0) + nvl(v_mto_cheque,0);
          IF nvl(pae_cnf.G_PROGRAMA,'X') <> ('CMDEPNBC') THEN -- Para que no afecte los programas en ITGF
            PAG_RIE.PR_OPE_RIESGO( v_fec_actual,
                                   v_hor_actual,
                                   v_cod_usuario,
                                   v_cod_transaccion, -- transacción padre
                                   v_cod_modulo,      -- Módulo
                                   v_cod_modalidad,   -- Modalidad
                                   v_nro_cuenta,      -- Nro_cuenta
                                   v_cod_persona,     -- Persona
                                   v_tip_operacion,   -- Tip_operacion
                                   v_tot_total,       -- Monto(Total de Depósito)
                                    null,             -- Número de Documento
                                    v_cod_moneda,     -- Moneda
                                    null,             -- Cotización
                                    v_nro_pedido);
          END IF;
           if v_nro_pedido > 0 then
             v_est_movimiento := 'P';
             pag_cta.pr_set_est_movimiento('P');
           else
             v_est_movimiento := 'N';
              pag_cta.pr_set_est_movimiento('N');
           end if;

          -- Acualizo la cuenta con el efectivo depositado
          v_nro_secuencia := 0;
          if v_mto_efectivo > 0 then
             --Si no se cargo un nro de boleta y si es solo efectivo, se asigna uno
             If v_nro_boleta is null and v_mto_cheque = 0 then
               select S_NRO_DEPOSITO.nextval into v_nro_boleta from dual;
             End if;
             pag_cta.pr_act_operacion(v_nro_cuenta,
                                      v_hor_actual,
                                     'C', -- credito
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
                                      'Deposito en Efectivo - Serv. Rec. en Ventanilla', --concepto
                                      'N', -- emitir aviso
                                      v_nro_secuencia, -- nro de secuencia
                                      v_fec_actual/*,null, null, null, v_est_movimiento*/);
          end if;
          -- Actualizo la cuenta con el cheque depositado plaza local sino hubo errores
          if (nvl(pag_cta.g_cod_error,0)= 0 or v_mto_efectivo = 0) and v_mto_cheque > 0 then
--             v_nro_secuencia := nvl(v_nro_secuencia,0) + 1;
             pag_cta.pr_act_operacion(v_nro_cuenta,
                                      v_hor_actual,
                                     'C', -- credito
                                      v_cod_moneda,
                                      v_mto_cheque,
                                      v_cod_transaccion,
                                      606, -- trans. hijo de cheq.nuestro bco
                                      v_nro_boleta,
                                      null, -- cotizacion
                                      v_cod_oficina,
                                      v_cod_modulo,
                                      v_cod_modalidad,
                                      null, -- tasa
                                      null, -- valor de tasa
                                      --'Deposito en Cheq.Bco.BBVA - Serv. Rec. en Ventanilla', --concepto
                                      'Deposito en Cheq.Bco.GNB - Serv. Rec. en Ventanilla', --concepto
                                      'N', -- emitir aviso
                                      v_nro_secuencia, -- nro de secuencia
                                      v_fec_actual/*, null, null,null, v_est_movimiento*/);
         end if;
         if pag_cta.g_cod_error <> 0 then
            -- actualizacion con problemas
            v_cod_respuesta := ltrim(to_char(pag_cta.g_cod_error,'000'));
            v_msj_respuesta := pag_cta.g_msj_error;
         else -- genero la transaccion en caja
            -- totalizo el cargo + impuesto
            v_tot_cargo := nvl(v_val_cargo,0) + nvl(v_val_impuesto,0);
            if v_cod_mad_cuenta in (33,34,35)  then
               -- si es a plazo, el cargo es aparte, sino se extrae del monto
               v_tot_efectivo := nvl(v_mto_efectivo,0) + v_tot_cargo;
            else
               v_tot_efectivo := v_mto_efectivo;
            end if;
            if v_val_cargo > 0 then
               -- existe cargo, se genera movimiento
               v_nro_secuencia := nvl(v_nro_secuencia,0) + 1;
               r_gmovi.cod_usuario     := user;
               r_gmovi.hora            := v_hor_actual;
               r_gmovi.fecha           := v_fec_actual;
               r_gmovi.nro_secuencia   := v_nro_secuencia;
               --
               r_gmovi.cod_modulo      := v_cod_mod_cuenta;
               r_gmovi.cod_modalidad   := v_cod_mad_cuenta;
               r_gmovi.cod_oficina     := v_cod_ofi_cuenta;
               r_gmovi.nro_cuenta      := v_nro_cuenta;
               r_gmovi.cod_moneda      := v_cod_moneda;
               r_gmovi.fec_valor       := v_fec_actual;
               r_gmovi.cod_tra_padre   := v_cod_tra_cargo;
               r_gmovi.cod_mod_padre   := v_cod_mod_cuenta;
               r_gmovi.cod_mad_padre   := v_cod_mad_cuenta;
               r_gmovi.cod_transaccion := v_cod_tra_cargo;
               r_gmovi.monto           := v_val_cargo;
               r_gmovi.nro_documento   := null;
               r_gmovi.cod_ofi_origen  := v_cod_oficina;
               r_gmovi.emi_aviso       := 'N';
               r_gmovi.concepto        := 'Cargo por Deposito en M/E';
               r_gmovi.estado          := 'N';
               r_gmovi.reversado       := 'N';
               r_gmovi.cod_tasa        := v_cod_tas_cargo;
               r_gmovi.val_tasa        := v_val_tas_cargo;
               r_gmovi.cod_rubro       := null;
               r_gmovi.nro_caja        := to_number(p_nro_caja);
               -- inserto el registro de movimientos
               PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi);
            end if;
            if v_val_impuesto > 0 then
               -- existe impuesto, se genera movimiento
               v_nro_secuencia := nvl(v_nro_secuencia,0) + 1;
               r_gmovi.cod_usuario     := user;
               r_gmovi.hora            := v_hor_actual;
               r_gmovi.fecha           := v_fec_actual;
               r_gmovi.nro_secuencia   := v_nro_secuencia;
               --
               r_gmovi.cod_modulo      := v_cod_mod_cuenta;
               r_gmovi.cod_modalidad   := v_cod_mad_cuenta;
               r_gmovi.cod_oficina     := v_cod_ofi_cuenta;
               r_gmovi.nro_cuenta      := v_nro_cuenta;
               r_gmovi.cod_moneda      := v_cod_moneda;
               r_gmovi.fec_valor       := v_fec_actual;
               r_gmovi.cod_tra_padre   := v_cod_tra_impuesto;
               r_gmovi.cod_mod_padre   := v_cod_mod_cuenta;
               r_gmovi.cod_mad_padre   := v_cod_mad_cuenta;
               r_gmovi.cod_transaccion := v_cod_tra_impuesto;
               r_gmovi.monto           := v_val_impuesto;
               r_gmovi.nro_documento   := null;
               r_gmovi.cod_ofi_origen  := v_cod_oficina;
               r_gmovi.emi_aviso       := 'N';
               r_gmovi.concepto        := 'IVA s/Cargo por Deposito en M/E';
               r_gmovi.estado          := 'N';
               r_gmovi.reversado       := 'N';
               r_gmovi.cod_tasa        := v_cod_tas_impuesto;
               r_gmovi.val_tasa        := v_val_tas_impuesto;
               r_gmovi.cod_rubro       := null;
               r_gmovi.nro_caja        := to_number(p_nro_caja);
               -- inserto el registro de movimientos
               PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi);
           end if;
           if v_tot_cargo > 0 and v_cod_mad_cuenta in (31,41)  then
              pag_cta.pr_act_sal_cta(v_nro_cuenta,
                                     v_cod_mad_cuenta,
                                     'D', -- DEBITO
                                     v_fec_actual,
                                     v_hor_actual,
                                     v_tot_cargo,
                                     0,
                                     0,
                                     'N',
                                     'N');
              v_tot_cargo := 0;
           end if;
           -- inserto registro del movimiento
           /* Si se genera un Pedido de Autorización no actualiza CJ_CONTROLES,
            CJ_MOVIMIENTOS queda con estado P. C.D.Fase III*/
           if nvl(v_nro_pedido,0) > 0 then
              lp_gen_transaccion('P');
           else
              lp_gen_transaccion('N');
            end if;
           -- actualizo la hora del mov de generacion contable de cupones
           if v_cod_mad_cuenta in (33,34,35) then
               update ge_movimientos
                  set hora = v_hor_actual
                where fecha = v_fec_actual
                  and hora <> v_hor_actual
                  and cod_usuario = user
                  and nro_cuenta = v_nro_cuenta
                  and cod_tra_padre = 400
                  and cod_transaccion = 400
                  and reversado = 'N'
                  and cod_moneda = v_cod_moneda
                  and monto > 0;
           end if;
           -- Inserta detalle.
           if v_cod_respuesta = '000' and p_nro_cheque is not null 
             and p_nro_cuenta is not null and p_serie is not null then
             v_msj_salida := fuj_pro_tra_det_355(p_nro_operacion,
                                                     p_nro_caja,
                                                     p_nro_boleta,
                                                     p_nro_cheque,
                                                     p_nro_cuenta,
                                                     p_det_mto_cheque,
                                                     p_serie,
                                                     v_hor_actual,
                                                     v_est_movimiento);

             v_cod_respuesta := '005';
             v_msj_respuesta := v_msj_salida;
             return (v_msj_salida);
             if v_msj_salida NOT LIKE '%~000~%' THEN
               return v_msj_salida;
             end if;
           end if;
         end if;
         --
      end if;
    end if;
 end if;

 -- mensaje final sino hubo errores
 if v_cod_respuesta = '000' then -- sino hubo problemas, se carga mensaje por defecto
   if nvl(v_nro_pedido,0) = 0 then --C.D.Fase III
    v_msj_respuesta := 'Operacion confirmada.';

   else
    v_msj_respuesta:= 'Se ha generado el Pedido de Autorización Nro:'||v_nro_pedido;
   end if;
    -- Se definió si se genera un Pedido de Autorización igual imprima la declaración Jurada (FIT)
      --determinar si la boleta de deposito es >= 10.000
      v_tot_deposito := nvl(v_mto_efectivo,0)+ nvl(v_mto_cheque,0);
      v_tot_en_usd   := pag_gen.FU_CON_MON_A_MONEDA(v_cod_moneda, -- moneda origen
                                     pag_gen.FU_OBT_MON_FUERTE, -- moneda dolar
                                     v_tot_deposito);
                                     
                                     
       if fuj_ver_imp_formulario(nvl(p_nro_cuenta,v_nro_cuenta),
                                 v_cod_persona,
                                 v_tot_en_usd,
                                 v_cod_transaccion,
                                 v_mto_calculado) then                               
         --La boleta de deposito es > 10.000
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
         
         If not (v_mto_cheque = 0 and  p_nro_boleta is null) then
            v_msj_respuesta := 'Operacion confirmada. Comprobante ha sido impreso';
         end if;

         if v_cli_frecuente = 'N' then -- Solo si no es cliente frecuente imprime.  V.O. 25/11/2009
            v_cod_respuesta := 'IMP';--Se cambia de lugar para emitir mensaje al guardar la operación y limpiar pantalla --C.D.Fase III
            -- paso el monto minimo a informar. Generar el informe de operaciones > a USD 10000
            -- Impresión declaración jurada--
            if nvl(v_nro_pedido,0) > 0 then -- C.D.Fase III
              v_msj_respuesta := 'Se ha generado el Pedido de Autorización nro.'||
                                  v_nro_pedido||'-'||
                                  'Comprobante y Decl.Jurada impresos.'||'~'||
                                  fuj_imp_dec_jurada_40(v_fec_actual, v_hor_actual, user);
            else
               v_msj_respuesta := 'Operacion Confirmada. Decl.Jurada y Comprobante impresos.'||'~'||
                                  fuj_imp_dec_jurada_40(v_fec_actual, v_hor_actual, user);
            end if;
            v_impreso := 'S';/*insertar e imprimir*/
         else
           if nvl(v_nro_pedido,0) > 0 then -- C.D.Fase III
             v_msj_respuesta:= 'Se ha generado el Pedido de Autorización Nro:'||v_nro_pedido;
           else
             v_msj_respuesta := 'Operacion confirmada. Comprobante ha sido impreso';
           end if;
           v_impreso := 'N';/*insertar y NO imprimir*/
         end if;
         
       -- retorno de la rutina de impresion
        v_msj_salida := p_nro_operacion||'~'||
                         v_cod_respuesta||'~'||
                         v_msj_respuesta;


        prj_ins_form_transacciones(nvl(p_nro_cuenta,v_nro_cuenta),
                                  v_cod_persona,
                                  v_cod_mod_cuenta,
                                  v_cod_transaccion,
                                  USER,
                                  v_fec_actual,
                                  v_hor_actual,
                                  pag_gen.fu_obt_mon_fuerte,                                 
                                  v_tot_en_usd,
                                  v_impreso);                 


         return (v_msj_salida);
      else
         prj_ins_form_transacciones(nvl(p_nro_cuenta,v_nro_cuenta),
                                  v_cod_persona,
                                  v_cod_mod_cuenta,
                                  v_cod_transaccion,
                                  USER,
                                  v_fec_actual,
                                  v_hor_actual,
                                  pag_gen.fu_obt_mon_fuerte,                                 
                                  v_tot_en_usd,
                                  v_impreso);     
      end if;
      
      
 End if;
 <<detalle>>
      if v_det_cheque = 'S' then
           v_msj_salida := fuj_pro_tra_det_355(p_nro_operacion,
                                               p_nro_caja,
                                               p_nro_boleta,
                                               p_nro_cheque,
                                               p_nro_cuenta,
                                               p_det_mto_cheque,
                                               p_serie,
                                               v_hor_actual,
                                               v_est_movimiento);
           v_cod_respuesta := '005';
           v_msj_respuesta := v_msj_salida;
           return (v_msj_salida);
           if v_msj_salida NOT LIKE '%~000~%' THEN
             return v_msj_salida;
           end if;
      end if;
 v_msj_respuesta := nvl(fuj_obt_nota(v_nro_cuenta),v_msj_respuesta);
 /* falta armar el mensaje de respuesta */
 v_msj_salida := p_nro_operacion||'~'||
                 v_cod_respuesta||'~'||
                 nvl(v_msj_respuesta,'Operacion confirmada');
 return(v_msj_salida);
 exception
    when others then
       v_cod_respuesta := '999';
       if upper(v_msj_respuesta) like '%OPERACION CONFIRMADA%' then
          v_msj_respuesta := null; --Para que utilice el sqlerrm  26/03/2010
       end if;
       v_msj_salida := p_nro_operacion||'~'||
                 v_cod_respuesta||'~'||
                 '!'||v_msj_respuesta||'-'||SQLERRM;
       return(v_msj_salida);
end FUJ_PRO_TRANSACCION_371;
/

