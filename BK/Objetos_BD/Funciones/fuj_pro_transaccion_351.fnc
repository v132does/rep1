CREATE OR REPLACE FUNCTION IT.FUJ_PRO_TRANSACCION_351 (
      p_nro_operacion in varchar2,   -- Nro de referencia de la operacion
      p_nro_caja in varchar2,        -- Nro de Caja
      p_nro_boleta in varchar2 default null,      -- Nro de la boleta
      p_nro_cuenta in varchar2,      -- Nro de cuenta del cliente
      p_tot_deposito in number,      -- total de deposito
      p_mto_efectivo in varchar2,  -- importe en efectivo
      p_mto_cheque in varchar2  default null)     -- Importe del deposito en cheques ntro bco
return long is
  --- defino por defecto el modulo y modalidad a utilizar
  v_cod_modulo       number(3)      := 9;    -- Caja
  v_cod_modalidad    number(3)   := 91;   -- Caja
  v_cod_transaccion  number(4) := 351;  -- transaccion
  v_cod_usuario      varchar2(10) := upper(user); --usuario
  -- Datos de la caja
  v_fec_actual       date := pag_cal.fu_obt_fec_actual(v_cod_modulo); -- fecha de hoy
  v_hor_actual       varchar2(08) :=  to_char(sysdate,'HH24:MI:SS');   -- Hora actual
  v_cod_oficina      number(3);         -- Codigo de oficina
  v_estado           number(1);         -- estado de la caja
  v_fec_caja         date;              -- fecha de la caja
  v_sal_actual       number(18,2);          -- saldo actual de la caja en efectivo
  v_sal_cheques      number(18,2);          -- saldo actual de la caja en cheques
  -- Datos de la cuenta
  v_denominacion     varchar2(200);     -- Nombre de la cuenta
  v_cod_moneda       varchar2(3);       -- moneda de la cuenta
  v_est_cuenta       varchar2(1);       -- estado de la cuenta
  v_cod_mod_cuenta   number(4);         -- modulo de la cuenta
  v_cod_mad_cuenta   number(4);         -- modalidad de la cuenta
  v_cod_ofi_cuenta   number(4);         -- oficina de la cuenta
  v_capital          number(18,2);      -- capital de cda
  v_fec_apertura     date;              -- fecha de apertura
  v_est_certificado  varchar2(01);      -- estado del cda
  v_est_ahorro       varchar2(01);      -- estado del cta_ahorro
  v_cli_frecuente    varchar2(1) := 'N';
  -- Datos de salida
  v_msj_salida       long;        -- mensaje final retornado
  v_cod_respuesta    varchar2(03) := '000'; -- sin errores
  v_msj_respuesta    varchar2(4000) := null; -- sin errores
  -- datos de la operacion convertidos
  v_tipo             varchar2(01) := 'D';  -- Debito para la caja (ingreso)
  v_tip_monto        varchar2(01) := 'C';  -- Cheq. nuestro banco
  --DYDMR-2403 ITGF -Deposito de Cheque en Custodia - Error Conversión de Carácter a Número Numérico o de Valor SC 20293
  --v_mto_cheque       number := nvl(to_number(p_mto_cheque),0); -- importe del deposito en cheques
  --v_mto_efectivo     number := nvl(to_number(p_mto_efectivo),0); -- importe del deposito en efectivo
  v_mto_cheque       number := fug_con_numero(nvl(p_mto_cheque,0));-- importe del deposito en cheques
  v_mto_efectivo     number := fug_con_numero(nvl(p_mto_efectivo,0));-- importe del deposito en efectivo
  v_nro_secuencia    number(3) := 0;  -- secuencia del mov.
  v_tot_deposito     number(18,2);  -- total de deposito
  v_tot_en_usd       number;
  v_nro_boleta       number := to_number(p_nro_boleta); --Numbero de boleta
  --
  -- datos calculados
  r_gmovi             ge_movimientos%rowtype;
  v_cod_tra_cargo     number := 5068;--598; -- transaccion por cargo
  v_tot_cargo         number := 0;   -- monto del cargo + impuesto
  v_tot_efectivo      number := 0;   -- deposito en efectivo + cargos
  v_cod_tas_cargo     number;
  v_val_tas_cargo     number;
  v_val_cargo         number;
  v_cod_tra_impuesto  number;
  v_cod_tas_impuesto  number;
  v_val_tas_impuesto  number;
  v_val_impuesto      number;
  v_can_cupones       number;
  v_saldo             number;
  v_cod_persona       ba_personas.cod_persona%type;
  v_mon_sup_mov       number(18,2);
  v_men_res_imp       varchar2(4000);
  v_cod_cau_judicial  ge_causales.cod_causa%type := fug_obt_pardinamico('COD_CAU_DEM_JUDICIAL');
   -- C.D. Fase III--
  v_tip_operacion   ge_mov_autorizaciones.tip_operacion%type := 'O';-- Todos Tipos Operacional
  v_est_movimiento  ge_movimientos.estado%type;
  v_nro_pedido    ge_mov_autorizaciones.nro_pedido%type;
  v_tot_total       ge_movimientos.monto%type; -- Total Monto Depositado
  v_mto_calculado   number;  --CRO-JM-03/2015: CROGEFIT-3
  v_ctr_dup_dep     varchar2(1):= fug_obt_pardinamico( 'TIE_CON_DUP_TRA_351');
  v_exi_dup_dep     varchar2(1) := 'N';
  v_existe_cheque   varchar2(1) := 'N';
  --
  v_mto_superior   varchar2(1) := 'N';
  ---Limite Umbral
  v_mto_loa        ge_movimientos.monto%type;
  v_mto_acumulado  ge_movimientos.monto%type;
  v_mto_total      ge_movimientos.monto%type;
  v_dep_umbral     varchar2(1) := 'S';
  
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
            nro_documento, nro_cuenta, monto, tip_monto, tipo, estado, nro_ref_externo)-- C.D.Fase III
            --> CRO-FACPOD: Para Almacenar la respuesta de la Aplicación Externa.-
        values
           (v_fec_actual, v_hor_actual, v_cod_usuario, v_nro_secuencia, -- secuencia 1
            v_cod_transaccion, v_cod_modulo, v_cod_modalidad,
            v_cod_oficina, v_cod_moneda, to_number(p_nro_caja),
            v_nro_boleta, p_nro_cuenta, v_mto_efectivo,'E' /* efectivo */, v_tipo, p_estado, p_nro_operacion);  --es debito
      end if;
      if v_mto_cheque > 0 then
        -- genero el movimiento por el deposito en cheques (local)
        v_nro_secuencia := v_nro_secuencia + 1;
        insert into cj_movimientos
           (fecha, hora, cod_usuario, nro_secuencia,
            cod_tra_padre, cod_mod_padre, cod_mad_padre,
            cod_oficina, cod_moneda, nro_caja,
            nro_documento, nro_cuenta, monto, tip_monto, tipo, estado, -- C.D.Fase III
            nro_ref_externo) --> CRO-FACPOD: Para Almacenar la respuesta de la Aplicación Externa.-
        values
           (v_fec_actual, v_hor_actual, v_cod_usuario, v_nro_secuencia, -- secuencia 2
            v_cod_transaccion, v_cod_modulo, v_cod_modalidad,
            v_cod_oficina, v_cod_moneda, to_number(p_nro_caja),
            v_nro_boleta, p_nro_cuenta, v_mto_cheque,v_tip_monto /* cheq.nuestro bcos */, v_tipo, p_estado,
            p_nro_operacion); /* es debito */
      end if;
      if v_tot_cargo > 0 then
        -- genero el movimiento por el cargo
        v_nro_secuencia := v_nro_secuencia + 1;
        insert into cj_movimientos
           (fecha, hora, cod_usuario, nro_secuencia,
            cod_tra_padre, cod_mod_padre, cod_mad_padre,
            cod_oficina, cod_moneda, nro_caja,
            nro_documento, nro_cuenta, monto, tip_monto, tipo, estado, -- C.D.Fase III
            --> CRO-FACPOD: Para Almacenar la respuesta de la Aplicación Externa.-
            nro_ref_externo)
        values
           (v_fec_actual, v_hor_actual, v_cod_usuario, v_nro_secuencia, -- secuencia 3
            v_cod_tra_cargo, v_cod_mod_cuenta, v_cod_mad_cuenta,
            v_cod_oficina, v_cod_moneda, to_number(p_nro_caja),
            v_nro_boleta, p_nro_cuenta, v_tot_cargo,'E' /* efectivo */, v_tipo, p_estado, --es debito
            p_nro_operacion);
      end if;
      
     
      if v_existe_cheque = 'S' then   
      --Se actualiza el estado del movimiento de tabla de cheques recibidos en el TED.
      begin 
        update cj_dep_chq_atm_reg o
        set o.est_cheque = 'D',
            o.fecha = v_fec_actual,
            o.hora = v_hor_actual,
            o.cod_usuario = v_cod_usuario,
            o.nro_secuencia = v_nro_secuencia
        where o.nro_transaccion = p_nro_boleta
          and o.est_cheque in ('I')
          and o.cod_banco in (39,46); --Bancos 39--Vision 46--Ueno
        exception 
          when others then 
            null;
       end;
      end if;
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
  --funcion para validar moneda y parametro de Umbral
  function lf_val_lim_umbral(p_cod_moneda varchar2) return varchar2 is
    v_retorno      varchar2(1) := 'N';
    v_val_limite   ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('CJ_VAL_USD_CAJA');
    Cursor c_monedas is
      select b.val_minimo cod_moneda
        from ba_cod_referencias b
       where dominio = 'COD_MON_UMBRAL'
         and activo = 'S';  
  begin
    if v_val_limite = 'S' then
      --Monedas configuradas para control de umbral
      FOR reg IN c_monedas LOOP
        if reg.cod_moneda = p_cod_moneda then
          v_retorno := 'S';
        end if;
      END LOOP;
    else
      v_retorno := 'N';
    end if;
    
    return v_retorno;    
  end lf_val_lim_umbral;
  --procedimiento interno: inserta pedido de autorizacion umbral
  procedure lp_ins_pedido_umbral is 
  begin
    insert into ge_aut_umbral(nro_cuenta,cod_persona,fecha,hora,cod_usuario,monto_loa,monto_acumulado,monto_total,estado,cod_moneda,monto_operacion) 
    values (p_nro_cuenta, v_cod_persona, v_fec_actual, v_hor_actual, v_cod_usuario, v_mto_loa, v_mto_acumulado, v_mto_total, 'S',v_cod_moneda,p_mto_efectivo);                             
  exception
    when others then
      v_cod_respuesta := '006'; -- error
      v_msj_respuesta := 'ERROR: Al insertar autorizacion umbral.';
  end lp_ins_pedido_umbral;
  --
begin
 -- Inicializacion de la aplicacion y el modulo
 BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=v_cod_modulo; END;
 -- Valido la moneda
 /*if p_nro_boleta is null then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el Nro. de Boleta.';
 els*/
 if p_nro_cuenta is null then  -- valido la cuenta
    v_cod_respuesta := '002'; -- error
    v_msj_respuesta := 'ERROR: Ingrese la Cuenta del cliente.';
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
 else
  ---
  if p_nro_cuenta is not null then  -- valido la cuenta si es migrada
     v_msj_respuesta := fug_obt_nro_cta_bt(p_nro_cuenta);
     if v_msj_respuesta is not null then
        v_cod_respuesta := '012'; -- error
     end if;
  end if;
   --Valida si existe un cheque pre cargado en cj_dep_chq_atm_reg --TED
      begin 
        select 'S' into v_existe_cheque from cj_dep_chq_atm_reg o
        where o.nro_transaccion = p_nro_boleta
          and o.nro_cuenta = p_nro_cuenta
          and o.est_cheque in ('I')
          and o.cod_banco in (39,46);
        exception 
          when others then 
            v_existe_cheque := 'N';
        end;
  if v_cod_respuesta = '000' then   
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

     ---Verifica si el Cliente o un Vinculado a la Cuenta está inhibido y la causa es por Demanda Judicial --CROCLIJUD-5
     if fug_obt_inhibicion(v_cod_cau_judicial,v_cod_persona, p_nro_cuenta) Then
           v_cod_respuesta := '007';
           v_msj_respuesta := 'ERROR: Cliente Principal o Vinc. a la Cuenta con Demanda Judicial. Consulte con el asesor Jurídico';
     End If;
      /*select denominacion, cod_moneda, estado, cod_modalidad, cod_modulo,
             cod_oficina
        into v_denominacion, v_cod_moneda, v_est_cuenta, v_cod_mad_cuenta,
             v_cod_mod_cuenta, v_cod_ofi_cuenta
        from ge_cuentas a
       where a.nro_cuenta = p_nro_cuenta;*/
      if v_cod_mad_cuenta not in (31,32,33,34,35,41,334) then
        v_cod_respuesta := '003';
        v_msj_respuesta := 'ERROR: Tipo de cuenta no permite Depositos';
      else
        -- si es cda, se verifica que el monto corresponda al capital
        if v_cod_mad_cuenta in (33,34,35) then
            select nvl(capital,0) - nvl(sal_total,0),fec_apertura,est_certificado, estado
              into v_capital,v_fec_apertura, v_est_certificado, v_est_ahorro
              from ah_cta_certificados
             where nro_cuenta = p_nro_cuenta;
            if nvl(v_mto_efectivo,0)+nvl(v_mto_cheque,0) <> v_capital then
               v_cod_respuesta := '003';
               v_msj_respuesta := 'ERROR: *Monto ingresado no corresponde al Capital.';
            elsif v_fec_apertura <> v_fec_actual then
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
        --DYDMR-2057: ITGF - Detalle Duplicado Cta Cte 0101285359 SC 15321
        IF nvl(v_ctr_dup_dep, 'N') = 'S' then
           BEGIN
             BEGIN
               select distinct 'S'
                 into v_exi_dup_dep 
                 from ah_retenciones
                where nro_cuenta = p_nro_cuenta
                  and nro_documento = v_nro_boleta
                  and cod_moneda = v_cod_moneda
                  and fec_final = v_fec_actual;
             EXCEPTION
               WHEN no_data_found THEN
                  v_exi_dup_dep := 'N';
              END;
 	 	             
             if nvl(v_exi_dup_dep, 'N') = 'S' then
 	 	            v_cod_respuesta := '003';
 	 	            v_msj_respuesta := 'ERROR: Ya existe una operación registrada con la Boleta Nro.: ' ||v_nro_boleta|| '. Fecha: '||to_char(v_fec_actual,'dd/mm/yyyy');
 	 	         end if;
 	 	       END;
        END IF;    
            
        if v_cod_respuesta = '000' then
           v_msj_respuesta := fuj_ver_impedimentos(p_nro_cuenta,
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
    
    --Validar limite efectivo (umbral)
    if v_cod_respuesta = '000' and
       nvl(p_mto_efectivo,0) > 0 and
       lf_val_lim_umbral(v_cod_moneda) = 'S' then
       --obtener datos loa/umbral
       prg_obt_val_deposito(p_nro_cuenta    => p_nro_cuenta,
                            p_cod_moneda    => v_cod_moneda,
                            p_monto         => p_mto_efectivo,
                            p_mto_loa       => v_mto_loa,
                            p_mto_acumulado => v_mto_acumulado,
                            p_mto_total     => v_mto_total,
                            p_deposita      => v_dep_umbral);   
        if v_dep_umbral = 'N' then
          --genera pedido de autorizacion
         lp_ins_pedido_umbral; 
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
          IF nvl(pae_cnf.G_PROGRAMA,'X') <> ('CMDEPNBC') and -- Para que no afecte los programas en ITGF
             v_dep_umbral <> 'N' THEN --no genera autorizacion de riesgo para umbral 
            PAG_RIE.PR_OPE_RIESGO( v_fec_actual,
                                   v_hor_actual,
                                   v_cod_usuario,
                                   v_cod_transaccion, -- transacción padre
                                   v_cod_modulo,      -- Módulo
                                   v_cod_modalidad,   -- Modalidad
                                   p_nro_cuenta,      -- Nro_cuenta
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

          -- verifico el monto limite de operación por monedas
         if (nvl(v_mto_efectivo,0) + nvl(v_mto_cheque,0)) >
             nvl(fug_obt_pardinamico('OPE_SUP_MON_DEPOSITO',null,null,v_cod_moneda),0) and
             v_dep_umbral <> 'N' then             
             v_est_movimiento := 'P';
             pag_cta.pr_set_est_movimiento('P');
             v_mto_superior:='S';
         end if;          

         --Movimiento Pendiente por sobrepasar umbral
         if v_dep_umbral = 'N' then
           v_est_movimiento := 'P';
           pag_cta.pr_set_est_movimiento('P');
         end if;

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
                          v_cod_tra_cargo, -- cargo por deposito en m/e
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
             If v_nro_boleta is null and v_mto_cheque = 0 then
               select S_NRO_DEPOSITO.nextval into v_nro_boleta from dual;
             End if;
             pag_cta.pr_act_operacion(p_nro_cuenta,
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
                                      'Deposito en Efectivo', --concepto
                                      'N', -- emitir aviso
                                      v_nro_secuencia, -- nro de secuencia
                                      v_fec_actual/*,null, null, null, v_est_movimiento*/);
          end if;
          -- Actualizo la cuenta con el cheque depositado plaza local sino hubo errores
          if (nvl(pag_cta.g_cod_error,0)= 0 or v_mto_efectivo = 0) and v_mto_cheque > 0 then
             v_nro_secuencia := nvl(v_nro_secuencia,0) + 1;
             pag_cta.pr_act_operacion(p_nro_cuenta,
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
                                      --'Deposito en Cheq.Bco.BBVA', --concepto
                                      fug_obt_nom_entidad,
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
               r_gmovi.nro_cuenta      := p_nro_cuenta;
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
               r_gmovi.estado          := v_est_movimiento;--'N';
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
               r_gmovi.estado          := v_est_movimiento;--'N';
               r_gmovi.reversado       := 'N';
               r_gmovi.cod_tasa        := v_cod_tas_impuesto;
               r_gmovi.val_tasa        := v_val_tas_impuesto;
               r_gmovi.cod_rubro       := null;
               r_gmovi.nro_caja        := to_number(p_nro_caja);
               -- inserto el registro de movimientos
               PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi);
           end if;
           if v_tot_cargo > 0 and v_cod_mad_cuenta in (31,41,334) then
             
             ---//----
             if  v_est_movimiento = 'N'  then
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
                                                
              else
                pag_cta.pr_act_sal_cta(p_nro_cuenta,
                                         v_cod_mad_cuenta,
                                         'D', -- DEBITO
                                         v_fec_actual,
                                         v_hor_actual,
                                         0,
                                         0,
                                         (v_tot_cargo*-1),
                                         'N',
                                         'N');--null;
              end if;
              v_tot_cargo := 0;  
           end if;
           -- inserto registro del movimiento
           /* Si se genera un Pedido de Autorización no actualiza CJ_CONTROLES,
            CJ_MOVIMIENTOS queda con estado P. C.D.Fase III*/
           if nvl(v_nro_pedido,0) > 0 or v_est_movimiento = 'P' then
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
                  and nro_cuenta = p_nro_cuenta
                  and cod_tra_padre = 400
                  and cod_transaccion = 400
                  and reversado = 'N'
                  and cod_moneda = v_cod_moneda
                  and monto > 0;
           end if;
         end if;
         --
      end if;
    end if;
  end if; --> Condicion de cuenta migrada
 end if;
 -- mensaje final sino hubo errores
 if v_cod_respuesta = '000' then -- sino hubo problemas, se carga mensaje por defecto
   if nvl(v_nro_pedido,0) = 0 and v_mto_superior ='N' and --C.D.Fase III
      v_dep_umbral <> 'N' then
    v_msj_respuesta := 'Operacion confirmada. Comprobante ha sido impreso';

    /*prg_obt_tot_operaciones( v_cod_persona, '3', v_cod_modalidad, v_mon_sup_mov,
    --prg_obt_tot_operaciones(v_cod_persona, v_cod_mod_cuenta, v_cod_modalidad, v_mon_sup_mov,
                            v_fec_actual, v_men_res_imp, v_hor_actual, v_nro_boleta);*/

      If v_mto_cheque = 0 and p_nro_boleta is null then
        lp_act_can_impresion; -- C.D.Fase III--
        v_msj_respuesta := 'Operacion confirmada. Comprobante ha sido impreso'||'~'||
         fuj_imp_comprobante_351(v_nro_boleta,
                                 v_cod_oficina,
                                 p_nro_caja);
          v_cod_respuesta := 'IMP';
      end if;
   ELSIF nvl(v_nro_pedido,0) = 0 and v_mto_superior ='S' then --C.D.Fase III
     v_msj_respuesta:= '! Se debe Autorizar por Monto Mayor al Limite de Caja- Nro.Operación: '||v_nro_boleta;
   elsif v_dep_umbral = 'N' then
     v_msj_respuesta:= '! Solicitar Autorización a Cumplimiento por Umbral. - Nro.Operación: '||v_nro_boleta;
   else
     v_msj_respuesta:= 'Se ha generado el Pedido de Autorización Nro:'||v_nro_pedido;
   end if;
    -- Se definió si se genera un Pedido de Autorización igual imprima la declaración Jurada (FIT)
      --determinar si la boleta de deposito es >= 10.000
      v_tot_deposito := nvl(v_mto_efectivo,0)+ nvl(v_mto_cheque,0);
      v_tot_en_usd   := pag_gen.FU_CON_MON_A_MONEDA(v_cod_moneda, -- moneda origen
                                     pag_gen.FU_OBT_MON_FUERTE, -- moneda dolar
                                     v_tot_deposito);
      --La boleta de deposito es > 10.000
      --if v_tot_en_usd >= fug_obt_pardinamico('OPE_SUP_MON_FUERTE') then
      --CRO-JM-03/2015: CROGEFIT-3 Validacion de formularios F.I.T
      if fuj_ver_imp_formulario(p_nro_cuenta,
                                 v_cod_persona,
                                 pag_gen.fu_con_mon_a_moneda(v_cod_moneda,              -- moneda origen
                                                             pag_gen.fu_obt_mon_fuerte, -- moneda dolar
                                                             v_tot_deposito),
                                 v_cod_transaccion,
                                 v_mto_calculado) and
                                 nvl(pae_cnf.G_PROGRAMA,'X') <> ('CMDEPNBC') then
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
       /* v_msj_respuesta := v_msj_respuesta||'~'||
              --fuj_imp_dec_jurada(v_fec_actual, v_hor_actual, user);
              fuj_imp_dec_jurada_40(v_fec_actual, v_hor_actual, user);*/
              v_msj_respuesta := 'Se ha generado el Pedido de Autorización nro.'||v_nro_pedido||'-'||'Comprobante y Decl.Jurada impresos.'||'~'||
              fuj_imp_dec_jurada_40(v_fec_actual, v_hor_actual, user, null, v_mto_calculado, v_cod_transaccion);
            else
               v_msj_respuesta := 'Operacion Confirmada. Decl.Jurada y Comprobante impresos.'||'~'||
                                  fuj_imp_dec_jurada_40(v_fec_actual, v_hor_actual, user, null, v_mto_calculado, v_cod_transaccion);
            end if;
            -- CRO-JM-03/2015: CROGEFIT-3 insertamos en la tabla como ya impreso:
                    prj_ins_form_transacciones(p_nro_cuenta,
                                               v_cod_persona,
                                                v_cod_mod_cuenta,
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
           if nvl(v_nro_pedido,0) > 0 then -- C.D.Fase III
             v_msj_respuesta:= 'Se ha generado el Pedido de Autorización Nro:'||v_nro_pedido;
           else
             v_msj_respuesta := 'Operacion confirmada. Comprobante ha sido impreso';
           end if;
               -- CRO-JM-03/2015: CROGEFIT-3 Insertamos en CJ_ACU_IMP_FORMULARIOS como no impreso por ser cli. frecuente:
                    prj_ins_form_transacciones(p_nro_cuenta,
                                               v_cod_persona,
                                                v_cod_mod_cuenta,
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


         return (v_msj_salida);
      --La suma de varias boletas de deposito es >= 10.000
      /*elsif v_mon_sup_mov > fug_obt_pardinamico('OPE_SUP_MON_FUERTE') then
         If not (v_mto_cheque = 0 and  p_nro_boleta is null) then
            v_msj_respuesta := 'Operacion confirmada. Comprobante ha sido impreso';
         end if;
         -- paso el monto minimo a informar. Generar el informe de operaciones > a USD 10000
         v_msj_respuesta := v_msj_respuesta||'~'||v_men_res_imp;

         -- retorno de la rutina de impresion
          v_cod_respuesta := 'IMP';
          v_msj_salida := p_nro_operacion||'~'||
                          v_cod_respuesta||'~'||
                          v_msj_respuesta;
         return (v_msj_salida);*/
         else
        -- CRO-JM-03/2015: CROGEFIT-3 Insertamos en CJ_ACU_IMP_FORMULARIOS como no impreso aún:
                    prj_ins_form_transacciones(p_nro_cuenta,
                                               v_cod_persona,
                                                v_cod_mod_cuenta,
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

 if v_msj_respuesta is null then
    v_msj_respuesta := nvl(fuj_obt_nota(p_nro_cuenta),v_msj_respuesta);
 end if;
 /* falta armar el mensaje de respuesta */
 v_msj_salida := p_nro_operacion||'~'||
                 v_cod_respuesta||'~'||
                 nvl(v_msj_respuesta,'Operacion confirmada');
 return(v_msj_salida);
 exception
    when others then
/*       v_cod_respuesta := '999';
       v_msj_salida := p_nro_operacion||'~'||
                 v_cod_respuesta||'~'||
                 '!'||nvl(v_msj_respuesta,SQLERRM);
       return(v_msj_salida);*/
       v_cod_respuesta := '999';
       if upper(v_msj_respuesta) like '%OPERACION CONFIRMADA%' then
          v_msj_respuesta := null; --Para que utilice el sqlerrm  26/03/2010
       end if;
       v_msj_salida := p_nro_operacion||'~'||
                 v_cod_respuesta||'~'||
                 '!'||v_msj_respuesta||'-'||SQLERRM;
       return(v_msj_salida);
end FUJ_PRO_TRANSACCION_351;
/
