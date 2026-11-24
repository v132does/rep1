create or replace function it.FUJ_PRO_TRANSACCION_350(
      p_nro_operacion in varchar2,   -- Nro de referencia de la operacion
      p_nro_caj_origen in varchar2,        -- Nro de Caja
      p_nro_boleta in varchar2 default null,      -- Nro de la boleta
      p_nro_cuenta in varchar2,      -- Nro de cuenta del cliente
      p_nro_caj_afecta  in varchar2 default null, -- N¿mero de Caja a la que debe Afectar
      p_tot_deposito in number      -- total de deposito
      )
return long is
  -- defino por defecto el modulo y modalidad a utilizar
  p_nro_caja varchar2(3);
  v_cod_modulo number(3)      := 9;    -- Caja
  v_cod_modalidad number(3)   := 91;   -- Caja
  v_cod_transaccion number(4) := 350;  -- transaccion
  v_cod_usuario varchar2(10) := upper(user); --usuario
  -- Datos de la caja
  v_fec_actual        date := pag_cal.fu_obt_fec_actual(v_cod_modulo); -- fecha de hoy
  v_hor_actual        varchar2(08) := to_char(sysdate,'HH24:MI:SS');   -- Hora actual
  v_cod_oficina       number(3);         -- Codigo de oficina
  v_estado            number(1);         -- estado de la caja
  v_fec_caja          date;              -- fecha de la caja
  v_sal_actual        number(18,2);      -- saldo actual de la caja en efectivo
  v_sal_cheques        number(18,2);     -- saldo actual de la caja en cheques
  -- Datos de la cuenta
  v_denominacion      varchar2(200);     -- Nombre de la cuenta
  v_cod_moneda        varchar2(3);       -- moneda de la cuenta
  v_est_cuenta        varchar2(1);       -- estado de la cuenta
  v_cod_mod_cuenta    number(4);         -- modulo de la cuenta
  v_cod_mad_cuenta    number(4);         -- modalidad de la cuenta
  v_cod_ofi_cuenta    number(4);         -- oficina de la cuenta
  v_capital           number(18,2);      -- capital de cda
  v_fec_apertura      date;              -- fecha de apertura
  v_est_certificado   varchar2(01);      -- estado del cda
  v_est_ahorro        varchar2(01);      -- estado del cta_ahorro
  -- Datos de salida
  v_msj_salida    long;        -- mensaje final retornado
  v_cod_respuesta varchar2(03) := '000'; -- sin errores
  v_msj_respuesta varchar2(4000) := null; -- sin errores
  -- datos de la operacion convertidos
  v_tipo          varchar2(01) := 'D';  -- Debito para la caja (ingreso)
  v_mto_efectivo  number := nvl(to_number(p_tot_deposito),0); -- importe del deposito en efectivo
  v_nro_secuencia number(3) := 0;  -- secuencia del mov.
  v_tot_deposito  number(18,2);  -- total de deposito
  v_tot_en_usd    number;
  v_nro_boleta    number := to_number(p_nro_boleta); --Numbero de boleta
  --
  -- datos calculados
  r_gmovi             ge_movimientos%rowtype;
  v_cod_tra_cargo     number := 598; -- transaccion por cargo
  v_tot_cargo         number := 0;   -- monto del cargo + impuesto
  v_tot_efectivo      number := p_tot_deposito;   -- deposito en efectivo + cargos
  v_cod_tas_cargo     number;
  v_val_tas_cargo     number;
  v_val_cargo         number;
  v_cod_tra_impuesto  number;
  v_cod_tas_impuesto  number;
  v_val_tas_impuesto  number;
  v_val_impuesto      number;
  v_can_cupones       number;
  v_saldo             number;
  v_cod_persona ba_personas.cod_persona%type;
  v_mon_sup_mov number(18,2);
  v_men_res_imp varchar2(4000);
  v_cli_frecuente cr_inf_fondos.cli_frecuente%type;
  --
  v_nro_caj_afecta cj_cajas.nro_caja%type;
  v_des_caj_afecta cj_cajas.descripcion%type;
  v_cod_cau_judicial  ge_causales.cod_causa%type := fug_obt_pardinamico('COD_CAU_DEM_JUDICIAL');
  v_mto_calculado     number;
  v_cod_tra_car_me     number := 5068; -- transaccion por cargo deposito moneda extranjera.
  -- Procedimiento interno para generar movimiento y act. de control de caja
  procedure lp_gen_transaccion  is
  begin
      -- Actualizo el control de caja
      update cj_controles
         set --tot_che_nue_bco = nvl(tot_che_nue_bco,0) + nvl(v_mto_cheque,0),
             sal_actual = nvl(sal_actual,0) + nvl(v_tot_efectivo,0),
             tot_debitos = nvl(tot_debitos,0) + nvl(v_tot_efectivo,0),
             can_debitos = nvl(can_debitos,0) + decode(v_mto_efectivo,0,0,1) +
                                                decode(v_tot_cargo,0,0,1),
             estado = 1 -- abierto
       where nro_caja = to_number(p_nro_caja)
         and cod_moneda = v_cod_moneda
         and fecha = v_fec_caja;
      v_nro_secuencia := 0;
      if v_mto_efectivo > 0 then
        -- genero el movimiento por el efectivo
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
            v_nro_boleta, p_nro_cuenta, v_mto_efectivo,'E' /* efectivo */, v_tipo);  --es debito
      end if;

      if v_tot_cargo > 0 then
        -- genero el movimiento por el cargo
        v_nro_secuencia := v_nro_secuencia + 1;
        insert into cj_movimientos
           (fecha, hora, cod_usuario, nro_secuencia,
            cod_tra_padre, cod_mod_padre, cod_mad_padre,
            cod_oficina, cod_moneda, nro_caja,
            nro_documento, nro_cuenta, monto, tip_monto, tipo)
        values
           (v_fec_actual, v_hor_actual, v_cod_usuario, v_nro_secuencia, -- secuencia 3
            v_cod_tra_cargo, v_cod_mod_cuenta, v_cod_mad_cuenta,
            v_cod_oficina, v_cod_moneda, to_number(p_nro_caja),
            v_nro_boleta, p_nro_cuenta, v_tot_cargo,'E' /* efectivo */, v_tipo);  --es debito
      end if;

      if v_mto_efectivo > 0 then
        -- Recupera los datos de la Caja Origen
        prj_obt_datos_caja(p_nro_caj_origen,
                           v_cod_moneda,
                           v_cod_oficina,
                           v_fec_caja,
                           v_estado,
                           v_sal_actual,
                           v_sal_cheques,
                           'N');
        -- genero el movimiento por el efectivo para la Caja Origen
        v_nro_secuencia := v_nro_secuencia + 1;
        insert into cj_movimientos
           (fecha, hora, cod_usuario, nro_secuencia,
            cod_tra_padre, cod_mod_padre, cod_mad_padre,
            cod_oficina, cod_moneda, nro_caja,
            nro_documento, nro_cuenta, monto, tip_monto, tipo)
        values
           (v_fec_actual, v_hor_actual, v_cod_usuario, v_nro_secuencia, -- secuencia 1
            v_cod_transaccion, v_cod_modulo, v_cod_modalidad,
            v_cod_oficina, v_cod_moneda, to_number(p_nro_caj_origen),
            v_nro_boleta, p_nro_cuenta, v_mto_efectivo,'E' /* efectivo */, 'N');  --No Afecta Saldo
      end if;
  end lp_gen_transaccion;
  --
begin
  -- Inicializacion de la aplicacion y el modulo
  BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=v_cod_modulo; END;
  -- Valido la moneda
  if p_nro_cuenta is null then  -- valido la cuenta
    v_cod_respuesta := '002'; -- error
    v_msj_respuesta := 'ERROR: Ingrese la Cuenta del cliente.';
  elsif v_mto_efectivo is null or v_mto_efectivo < 0 then
    v_cod_respuesta := '003'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el importe en Efectivo a Depositar.';
  elsif nvl(p_tot_deposito,0) <> nvl(v_mto_efectivo,0) then
    v_cod_respuesta := '003'; -- error
    v_msj_respuesta := 'ERROR: Total Depositado no coincide con los Detalles.';
  elsif p_nro_caj_afecta is not null and nvl(fuj_obt_tip_caja(p_nro_caj_afecta),'x') <> 'P' then
    v_cod_respuesta := '004'; -- error
    v_msj_respuesta := 'ERROR: Ingrese un Nro. de Caja v¿lido.';
  else
    if v_cod_respuesta = '000' then -- sino hubo problemas, veo la caja
       --
       v_cod_oficina := fuj_obt_cod_oficina(p_nro_caj_origen);
       --
       if v_cod_respuesta = '000' then
         begin
           select c.nro_caja, c.descripcion
             into v_nro_caj_afecta, v_des_caj_afecta
             from cj_cajas c
            where c.tipo = 'P'
              and c.cod_oficina = v_cod_oficina;
         exception
           when no_data_found then
             if p_nro_caj_afecta is not null then
               -- Sino tiene caja prosegur en su oficina, verifica que la caja ingresada sea correcta.
               v_nro_caj_afecta := p_nro_caj_afecta;
               --
               begin
                 select descripcion
                   into v_des_caj_afecta
                   from cj_cajas
                  where tipo = 'P'
                    and nro_caja = v_nro_caj_afecta;
               exception
                 when no_data_found then
                   v_cod_respuesta := '004';
                   v_msj_respuesta := 'Debe ingresar un N¿mero de Caja v¿lido.';
                 when others then
                   v_cod_respuesta := '004';
                   v_msj_respuesta := substr(sqlerrm,1,100);
               end;
             end if;
           when others then
              v_cod_respuesta := '005';
              v_msj_respuesta := substr(sqlerrm,1,100);
         end;
       end if;
       p_nro_caja := v_nro_caj_afecta;
    end if;
    -- obtengo datos de la cuenta  ------------------------------------------
    begin
      select a.denominacion, a.cod_moneda, a.estado, a.cod_modalidad, a.cod_modulo,
             a.cod_oficina, c.cod_persona
        into v_denominacion, v_cod_moneda, v_est_cuenta, v_cod_mad_cuenta,
             v_cod_mod_cuenta, v_cod_ofi_cuenta, v_cod_persona
         from ge_cuentas a ,ge_cta_clientes c
         where a.nro_cuenta = p_nro_cuenta
         and a.nro_cuenta = c.nro_cuenta
         and c.relacion = 'P';
      if v_cod_mad_cuenta not in (31,32,33,34,41) then
        v_cod_respuesta := '003';
        v_msj_respuesta := 'ERROR: Tipo de cuenta no permite Depositos';
      else
        -- si es cda, se verifica que el monto corresponda al capital
        if v_cod_mad_cuenta in (33,34,35) then
            select nvl(capital,0) - nvl(sal_total,0),fec_apertura,est_certificado, estado
              into v_capital,v_fec_apertura, v_est_certificado, v_est_ahorro
              from ah_cta_certificados
             where nro_cuenta = p_nro_cuenta;
            if v_fec_apertura <> v_fec_actual then
               v_cod_respuesta := '003';
               v_msj_respuesta := 'ERROR: Fecha de Apertura no corresponde a Hoy.';
            elsif v_est_ahorro <> 'A' AND v_est_certificado <> 'C' then
               v_cod_respuesta := '003';
               v_msj_respuesta := 'ERROR: Carton debe ser cargado previamente.';
            else
               select count(*)
                 into v_can_cupones
                 from ah_cupones
                where nro_cuenta = p_nro_cuenta
                  and estado <> 'C'
                  and rownum = 1;
               if nvl(v_can_cupones,0) > 0 then
                  v_cod_respuesta := '003';
                  v_msj_respuesta := 'ERROR: Cupones deben ser cargado previamente.';
               end if;
            end if;
        elsif v_cod_mad_cuenta = 41 then--si es cta cte verifica el saldo
            select nvl(sal_total,0) - nvl(sal_retenido,0) - nvl(sal_bloqueado,0)
              into v_saldo
              from cc_cta_corrientes
             where nro_cuenta = p_nro_cuenta;
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
        if v_cod_respuesta = '000' then
           v_msj_respuesta := fuj_ver_impedimentos(p_nro_cuenta,
                                                   v_cod_mad_cuenta,
                                                   v_cod_transaccion,
                                                   v_est_cuenta,
                                                  'C'); -- 'C'== CREDITO
           if v_msj_respuesta is not null then
              if v_cod_mad_cuenta = 41 and v_msj_respuesta like 'Cuenta esta pendiente de Cancelacion' then
                 --si la cuenta tiene saldo negativo puede recibir dep¿sitos
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
     ---Verifica si el Cliente o un Vinculado a la Cuenta est¿ inhibido y la causa es por Demanda Judicial --CROCLIJUD-5
     if fug_obt_inhibicion(v_cod_cau_judicial,v_cod_persona, p_nro_cuenta) Then
        v_cod_respuesta := '007';
        v_msj_respuesta := 'ERROR: Cliente Principal o Vinc. a la Cuenta con Demanda Judicial. Consulte con el asesor Jur¿dico';
     End If;
    if v_cod_respuesta = '000' then -- sino hubo problemas, veo la caja
       -- Obtengo los datos de la caja ---------------------------------------
       prj_obt_datos_caja(p_nro_caja,
                          v_cod_moneda,
                          v_cod_oficina,
                          v_fec_caja,
                          v_estado,
                          v_sal_actual,
                          v_sal_cheques,
                          'N');
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
       v_msj_respuesta := fuj_val_importe(v_tipo, 'E',v_cod_moneda,v_mto_efectivo);

       if v_msj_respuesta is not null then
          v_cod_respuesta := '005';  -- error
       else
          -- Asigno el nro de caja a los movimientos
          pag_cta.pr_nro_caja(to_number(p_nro_caja));
          -- Acualizo la cuenta con el efectivo depositado
          v_nro_secuencia := 0;
          if v_mto_efectivo > 0 then
             -- busco el monto del cargo y el impuesto antes de generar el movimiento
              prj_obt_cargo(v_cod_oficina,
                            p_nro_cuenta,
                            v_cod_moneda,
                            v_mto_efectivo,
                            v_cod_mod_cuenta,
                            v_cod_mad_cuenta,
                            v_cod_tra_car_me, -- cargo por deposito en m/e
                            v_cod_tas_cargo,
                            v_val_tas_cargo,
                            v_val_cargo,
                            v_cod_tra_impuesto,
                            v_cod_tas_impuesto,
                            v_val_tas_impuesto,
                            v_val_impuesto);
             -- actualizo la cuenta
             v_nro_secuencia := nvl(v_nro_secuencia,0) + 1;

             --Si no se cargo un nro de boleta y si es solo efectivo, se asigna uno
             If v_nro_boleta is null then
               select S_NRO_DEPOSITO.nextval into v_nro_boleta from dual;
             End if;

             pag_cta.pr_act_operacion(p_nro_cuenta,
                                      v_hor_actual,
                                     'C', -- credito
                                      v_cod_moneda,
                                      v_mto_efectivo,
                                      v_cod_transaccion,
                                      1690, -- trans. hijo de efectivo
                                      v_nro_boleta,
                                      null, -- cotizacion
                                      v_cod_oficina,
                                      v_cod_modulo,
                                      v_cod_modalidad,
                                      null, -- tasa
                                      null, -- valor de tasa
                                      'Deposito en Efectivo', --concepto
                                      'N', -- emitir aviso
                                      v_nro_secuencia, -- nro de secuencia
                                      v_fec_actual);
          end if;

         if pag_cta.g_cod_error <> 0 then
            -- actualizacion con problemas
            v_cod_respuesta := ltrim(to_char(pag_cta.g_cod_error,'000'));
            v_msj_respuesta := pag_cta.g_msj_error;
            /**/
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
               r_gmovi.nro_cuenta      := p_nro_cuenta;
               r_gmovi.cod_moneda      := v_cod_moneda;
               r_gmovi.fec_valor       := v_fec_actual;
               r_gmovi.cod_tra_padre   := v_cod_tra_car_me;
               r_gmovi.cod_mod_padre   := v_cod_mod_cuenta;
               r_gmovi.cod_mad_padre   := v_cod_mad_cuenta;
               r_gmovi.cod_transaccion := v_cod_tra_car_me; 
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
               r_gmovi.nro_cuenta      := p_nro_cuenta;
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
              pag_cta.pr_act_sal_cta(p_nro_cuenta,
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
           /**/
         end if;
      end if;
    end if;
  end if;
  if v_cod_respuesta = '000' then
    -- inserto registro del movimiento
    lp_gen_transaccion();
  end if;

  -- mensaje final sino hubo errores
  if v_cod_respuesta = '000' then -- sino hubo problemas, se carga mensaje por defecto
    v_msj_respuesta := 'Operacion confirmada. Comprobante ha sido impreso';

    /*prg_obt_tot_operaciones( v_cod_persona, '3', v_cod_modalidad, v_mon_sup_mov,
                            v_fec_actual, v_men_res_imp, v_hor_actual, v_nro_boleta);*/
    --
      --determinar si la boleta de deposito es >= 10.000
      v_tot_deposito := nvl(v_mto_efectivo,0);
      v_tot_en_usd   := pag_gen.FU_CON_MON_A_MONEDA(v_cod_moneda, -- moneda origen
                                     pag_gen.FU_OBT_MON_FUERTE, -- moneda dolar
                                     v_tot_deposito);

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
    --La boleta de deposito es > 10.000
    --if v_tot_en_usd >= fug_obt_pardinamico('OPE_SUP_MON_FUERTE') then
  -- CRO-JM-03/2015: CROGEFIT-3
   if fuj_ver_imp_formulario(p_nro_cuenta,
                             v_cod_persona,
                             pag_gen.fu_con_mon_a_moneda(v_cod_moneda,              -- moneda origen
                                                         pag_gen.fu_obt_mon_fuerte, -- moneda dolar
                                                         v_tot_deposito),
                             v_cod_transaccion,
                             v_mto_calculado) then
       If p_nro_boleta is not  null then
          v_msj_respuesta := 'Operacion confirmada. Comprobante ha sido impreso';
       end if;
       -- paso el monto minimo a informar. Generar el informe de operaciones > a USD 10000
       if v_cli_frecuente = 'N' then
         v_msj_respuesta := v_msj_respuesta||'~'|| fuj_imp_dec_jurada_40(v_fec_actual, v_hor_actual, user, null, v_mto_calculado, v_cod_transaccion);
         -- CRO-JM-03/2015: CROGEFIT-3 insertamos en la tabla como ya impreso:
            prj_ins_form_transacciones(p_nro_cuenta,
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
           -- retorno de la rutina de impresion
              v_cod_respuesta := 'IMP';
              v_msj_salida := p_nro_operacion||'~'||
                              v_cod_respuesta||'~'||
                              v_msj_respuesta;
             return (v_msj_salida);
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
                                        pag_gen.fu_con_mon_a_moneda(v_cod_moneda,              -- moneda origen
                                                                   pag_gen.fu_obt_mon_fuerte, -- moneda dolar
                                                                   v_tot_deposito),
                                        'N');
       end if;
    --La suma de varias boletas de deposito es >= 10.000
    elsif v_mon_sup_mov > fug_obt_pardinamico('OPE_SUP_MON_FUERTE') and v_cli_frecuente = 'N' then
       If p_nro_boleta is not  null then
          v_msj_respuesta := 'Operacion confirmada. Comprobante ha sido impreso';
       end if;
       -- paso el monto minimo a informar. Generar el informe de operaciones > a USD 10000
       v_msj_respuesta := v_msj_respuesta||'~'||v_men_res_imp;

       -- CRO-JM-03/2015: CROGEFIT-3 insertamos en la tabla como ya impreso:
            prj_ins_form_transacciones(p_nro_cuenta,
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

       -- retorno de la rutina de impresion
        v_cod_respuesta := 'IMP';
        v_msj_salida := p_nro_operacion||'~'||
                        v_cod_respuesta||'~'||
                        v_msj_respuesta;
       return (v_msj_salida);
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
                                       pag_gen.fu_con_mon_a_moneda(v_cod_moneda,              -- moneda origen
                                                                  pag_gen.fu_obt_mon_fuerte, -- moneda dolar
                                                                  v_tot_deposito),
                                        'N');       
    end if;

 End if;
 v_msj_respuesta := nvl(fuj_obt_nota(p_nro_cuenta),v_msj_respuesta);
 -- falta armar el mensaje de respuesta
 v_msj_salida := p_nro_operacion||'~'||
                 v_cod_respuesta||'~'||
                 nvl(v_msj_respuesta,'Operacion confirmada');
 return(v_msj_salida);
 exception
    when others then
       v_cod_respuesta := '999';
       v_msj_salida := p_nro_operacion||'~'||
                 v_cod_respuesta||'~'||
                 '!'||nvl(v_msj_respuesta,SQLERRM);
       return(v_msj_salida);
end FUJ_PRO_TRANSACCION_350;
/

