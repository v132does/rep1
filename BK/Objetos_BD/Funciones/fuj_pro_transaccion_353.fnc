create or replace function it.FUJ_PRO_TRANSACCION_353(
      p_nro_operacion in varchar2,   -- Nro de referencia de la operacion
      p_nro_caja in varchar2,        -- Nro de Caja
      --p_nro_boleta in varchar2,      -- Nro de la boleta
      p_nro_cuenta in varchar2,      -- Nro de cuenta del cliente
      P_importe in varchar2)         -- Importe de la extraccion
return VARCHAR2 is
  -- defino por defecto el modulo y modalidad a utilizar
  v_cod_modulo number(3)      := 9;    --- Caja
  v_cod_modalidad number(3)   := 91;   -- Caja
  v_cod_transaccion number(4) := 353;  -- transaccion
  v_cod_usuario varchar2(10) := upper(user); --usuario
  v_cargos      number(18,2);
  -- Datos de la caja
  v_fec_actual        date := pag_cal.fu_obt_fec_actual(v_cod_modulo); -- fecha de hoy
  v_hor_actual        varchar2(08) := to_char(sysdate,'HH24:MI:SS');   -- Hora actual
  v_cod_oficina       number(3);         -- Codigo de oficina
  v_estado            number(1);         -- estado de la caja
  v_fec_caja          date;              -- fecha de la caja
  v_sal_actual        number(18,2);          -- saldo actual de la caja en efectivo
  v_sal_cheques        number(18,2);          -- saldo actual de la caja en cheques
  -- Datos de la cuenta
  v_denominacion      varchar2(200);     -- Nombre de la cuenta
  v_cod_moneda        varchar2(3);       -- moneda de la cuenta
  v_est_cuenta        varchar2(1);       -- estado de la cuenta
  v_tip_cuenta        number(3);         -- tipo de cuenta(modalidad)
  v_cod_mod_cuenta    number(4);         -- modulo de la cuenta
  -- Datos de salida
  v_msj_salida    varchar2(8000);        -- mensaje final retornado
  v_cod_respuesta varchar2(03) := '000'; -- sin errores
  v_msj_respuesta varchar2(5000) := 'Operacion Confirmada'; -- sin errores
  -- datos de la operacion convertidos
  v_tipo          varchar2(01) := 'C';  -- credito para la caja (egreso)
  v_tip_monto     varchar2(01) := 'E';  -- efectivo
  v_importe       number := to_number(p_importe); -- importe de la extraccion
  v_nro_secuencia number(3) := 0;  -- secuencia del mov.
  --Datos de los cargos
  V_COD_TAS_CARGO     GE_MOVIMIENTOS.COD_TASA%TYPE;
  V_VAL_TAS_CARGO     GE_MOVIMIENTOS.VAL_TASA%TYPE;
  V_VAL_CARGO         GE_MOVIMIENTOS.VAL_TASA%TYPE;
  V_COD_TRA_IMPUESTO  GE_MOVIMIENTOS.COD_TRANSACCION%TYPE;
  V_COD_TAS_IMPUESTO  GE_MOVIMIENTOS.COD_TASA%TYPE;
  V_VAL_TAS_IMPUESTO  GE_MOVIMIENTOS.VAL_TASA%TYPE;
  V_VAL_IMPUESTO      GE_MOVIMIENTOS.VAL_TASA%TYPE;
  --
  v_cod_mod_cta ge_cuentas.cod_modulo%type;
  v_cod_mad_cta ge_cuentas.cod_modalidad%type;
  v_nvo_estado  ge_cuentas.estado%type;
  v_sal_disp    ge_cuentas.sal_contable%type;
  v_procesa     varchar2(1) := 'N';
  p_nro_boleta  number(10);
  -- FB:07.10.2009 Agregado p/ cobro de comisiones a ctas AV del segmento 26, pago de nóminas
  v_cod_seg_cliente   ge_clientes.cod_seg_cliente%type;
     /*CROCLIJUD-5*/
  v_cod_persona        ba_personas.cod_persona%type;
  v_cod_cau_judicial   ge_causales.cod_causa%type := fug_obt_pardinamico('COD_CAU_DEM_JUDICIAL');
     /* C.D. Fase III*/
  v_tip_operacion   ge_mov_autorizaciones.tip_operacion%type := 'O';-- Todos Tipos Operacional
  v_est_movimiento  ge_movimientos.estado%type;
  v_nro_pedido      ge_mov_autorizaciones.nro_pedido%type;
  --Notificaciones Fase 3
  v_ret             NUMBER(3) := 0;
  --Cobro comision extraccion ME
  v_cod_tra_cargo     number := 5078;-- transaccion por cargo
  v_pro_cargo         varchar2(1) := 'N';
  v_afe_debito       varchar2(1) default 'N'; -- BSEVOCORE-147
  
  v_cod_tra_hijo     ge_transacciones.cod_transaccion%TYPE;
  -- Procedimiento interno para generar movimiento y act. de control de caja
  procedure lp_gen_transaccion (p_estado varchar2)  is
  begin
      -- Actualizo el control de caja
      if p_estado <> 'P' then -- C.D.Fase III
        update cj_controles
           set sal_actual = nvl(sal_actual,0) - nvl(v_importe,0),
               tot_creditos = nvl(tot_creditos,0) + nvl(v_importe,0),
               can_creditos = nvl(can_creditos,0) + 1,
               estado = 1 -- abierto
         where nro_caja = to_number(p_nro_caja)
           and cod_moneda = v_cod_moneda
           and fecha = v_fec_caja;
       end if;
      -- genero el movimiento por la extraccion
      insert into cj_movimientos
         (fecha, hora, cod_usuario, nro_secuencia,
          cod_tra_padre, cod_mod_padre, cod_mad_padre,
          cod_oficina, cod_moneda, nro_caja,
          nro_documento, nro_cuenta, monto, tip_monto, tipo, estado,-- C.D.Fase III
          nro_ref_externo) --> CRO-FACPOD: Para Almacenar la respuesta de la Aplicación Externa.-
      values
         (v_fec_actual, v_hor_actual, v_cod_usuario, 1,
          v_cod_transaccion, v_cod_modulo, v_cod_modalidad,
          v_cod_oficina, v_cod_moneda, to_number(p_nro_caja),
          p_nro_boleta, p_nro_cuenta, v_importe,v_tip_monto /* efectivo */, v_tipo, p_estado, /* es debito */
          p_nro_operacion);
  end lp_gen_transaccion;
  --
  procedure lp_act_can_impresion is -- C.D.Fase III--

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
 --if p_nro_boleta is null then
 --   v_cod_respuesta := '001'; -- error
 --   v_msj_respuesta := 'ERROR: Ingrese el Nro. de Boleta.';
 --els
 if p_nro_cuenta is null then  -- valido la cuenta
    v_cod_respuesta := '002'; -- error
    v_msj_respuesta := 'ERROR: Ingrese la Cuenta del cliente.';
 elsif v_importe is null or v_importe <= 0 then
    v_cod_respuesta := '003'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el importe de la Extraccion';
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
      select denominacion, cod_moneda, estado, cod_modalidad,cod_modulo
        into v_denominacion, v_cod_moneda, v_est_cuenta, v_tip_cuenta,v_cod_mod_cuenta
        from ge_cuentas a
       where a.nro_cuenta = p_nro_cuenta;
      if v_tip_cuenta not in (31,334,41) then
        v_cod_respuesta := '003';
        v_msj_respuesta := 'ERROR: Tipo de cuenta no permite extracciones';
      else
        -- Verifica a que segmento corresponde el cliente de la cuenta de ahorro
        begin
          select cod_seg_cliente
            into v_cod_seg_cliente
           from ge_clientes i, ge_cta_clientes a
          where i.cod_persona = a.cod_persona
            and a.nro_cuenta = p_nro_cuenta;
        exception
           when others then
                v_cod_seg_cliente := null;
        end;
        -- Verifico la duplicacion del registro
        prj_val_duplicacion(p_nro_caja,
                            v_cod_transaccion,
                            v_cod_moneda,
                            999999, --p_nro_boleta, -- no se controla porque el numero es automatico
                            v_cod_respuesta,
                            v_msj_respuesta);
        if v_cod_respuesta = '000' then
           v_msj_respuesta := fuj_ver_impedimentos(p_nro_cuenta,
                                                   v_tip_cuenta,
                                                   v_cod_transaccion,
                                                   v_est_cuenta,
                                                   'D'); -- 'D'== DEBITO EN CUENTA
           if v_msj_respuesta is not null then
              v_cod_respuesta := '004';  -- la cuenta tiene impedimentos
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
    if v_cod_respuesta = '000' then
       ---Verifica si el Cliente o un Vinculado a la Cuenta está inhibido y la causa es por Demanda Judicial --CROCLIJUD-5
       v_cod_persona := fug_obt_cli_principal(p_nro_cuenta);
       if fug_obt_inhibicion(v_cod_cau_judicial,v_cod_persona,p_nro_cuenta) Then
          v_cod_respuesta := '003';
          v_msj_respuesta := 'ERROR: Cliente Principal. o Vinc. a la Cuenta con Demanda Judicial.Consulte con el asesor Jurídico' ;
       End If;
       -- Verifica si el Cliente o la Cta. tiene Inhibición que no permita realizar débito BSEVOCORE-147
       v_afe_debito  := fug_obt_val_parcausal('AFE_DEB_CUENTA',v_cod_persona, p_nro_cuenta);
       if nvl(v_afe_debito,'N') = 'S' then
         v_cod_respuesta := '003';
          v_msj_respuesta := 'ERROR: Inhibición del Cliente Principal o Vinculados a la Cuenta no permite realizar Débito' ;
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
       elsif v_sal_actual < v_importe then
          v_cod_respuesta := '006'; -- error
          v_msj_respuesta := 'Caja no tiene saldo para esta Operacion';
       end if;
    end if;
    if v_cod_respuesta = '000' then
       -- verifico los decimales del importe
       v_msj_respuesta := fuj_val_importe(v_tipo, v_tip_monto,v_cod_moneda,v_importe,v_cod_transaccion,p_nro_cuenta);
       if v_msj_respuesta is not null then
          v_cod_respuesta := '005';  -- error
       else
          --Se cobra cargos por la operacion si corresponde
          /*if v_cod_seg_cliente = 26 then
              prg_obt_car_extraccion (p_nro_cuenta,
                                      V_COD_TAS_CARGO,
                                      V_VAL_TAS_CARGO,
                                      V_VAL_CARGO,
                                      V_COD_TRA_IMPUESTO,
                                      V_COD_TAS_IMPUESTO,
                                      V_VAL_TAS_IMPUESTO,
                                      V_VAL_IMPUESTO) ;
          end if;*/
    -- busco el monto del cargo y el impuesto antes de generar el movimiento
            PRJ_OBT_CAR_EXTRACCION( v_cod_oficina,
                                    p_nro_cuenta,
                                    v_cod_moneda,
                                    p_importe,
                                    v_cod_mod_cuenta,
                                    v_tip_cuenta,
                                    v_cod_tra_cargo, -- cargo por extracción en m/e
                                    v_cod_tas_cargo,
                                    v_val_tas_cargo,
                                    v_val_cargo,
                                    v_cod_tra_impuesto,
                                    v_cod_tas_impuesto,
                                    v_val_tas_impuesto,
                                    v_val_impuesto);

          v_cargos := nvl(v_val_cargo,0) + nvl(v_val_impuesto,0);
          --Verificar la operacion
          pag_cta.pr_ver_operacion(p_nro_cuenta,
                                   v_cod_transaccion,
                                   v_cod_modulo,
                                   v_cod_modalidad,
                                   'D',
                                   v_cod_moneda,
                                   nvl(v_importe,0),--Controla solo el importe de extraccion
                                   v_cod_oficina,
                                   v_cod_mod_cta,
                                   v_cod_mad_cta,
                                   v_nvo_estado,
                                   v_sal_disp,
                                   v_procesa);

          If v_procesa = 'N' then
            v_cod_respuesta := ltrim(to_char(pag_cta.g_cod_error,'000'));
            v_msj_respuesta := pag_cta.g_msj_error;
          else
            -- Asigno el nro de caja a los movimientos
            pag_cta.pr_nro_caja(to_number(p_nro_caja));
            -- Verifico el Monto Riesgo. C.D.Fase III --
             PAG_RIE.PR_OPE_RIESGO( v_fec_actual,
                                 v_hor_actual,
                                 v_cod_usuario,
                                 v_cod_transaccion, -- transacción padre
                                 v_cod_modulo,      -- Módulo
                                 v_cod_modalidad,   -- Modalidad
                                 p_nro_cuenta,      -- Nro_cuenta
                                 null,-- v_cod_persona,     -- Persona
                                 v_tip_operacion,   -- Tip_operacion
                                 v_importe,         -- Monto
                                  null,              -- Número de Documento
                                  v_cod_moneda,      -- Moneda
                                  null,              -- Cotización
                                  v_nro_pedido);
           if nvl(v_nro_pedido,0) > 0 then
             v_est_movimiento := 'P';
             pag_cta.pr_set_est_movimiento('P');-- Para que vaya a Saldo Bloqueado si se genera un Circuito de WK
           else
             v_est_movimiento := 'N';
           end if;

            -- busco el sgte nro de boleta
            select s_nro_extraccion.nextval into p_nro_boleta from dual;
            --Modalidad de la Cuenta
            IF v_tip_cuenta = 41 THEN
              v_cod_tra_hijo := 490;
            ELSE
              v_cod_tra_hijo := 590;
            END IF;
            -- Actualiza la operacion en la base
            pag_cta.pr_act_operacion(p_nro_cuenta,
                                     v_hor_actual,
                                     'D', -- debito a la cuenta del cliente
                                     v_cod_moneda,
                                     v_importe,
                                     v_cod_transaccion,
                                     v_cod_tra_hijo,--590, -- trans. hijo
                                     p_nro_boleta,
                                     null, -- cotizacion
                                     v_cod_oficina,
                                     v_cod_modulo,
                                     v_cod_modalidad,
                                     null, -- tasa
                                     null, -- valor de tasa
                                     'Extraccion en Efectivo', --concepto
                                     'N', -- emitir aviso
                                     v_nro_secuencia, -- nro de secuencia
                                     v_fec_actual,null,null, null, v_est_movimiento); -- C.D.Fase III
            if pag_cta.g_cod_error <> 0 then
               -- actualizacion con problemas
               v_cod_respuesta := ltrim(to_char(pag_cta.g_cod_error,'000'));
               v_msj_respuesta := pag_cta.g_msj_error;
            else -- genero la transaccion en caja
              if v_val_cargo > 0 then
                --Verificar la operación para el cobro de cargo
                pag_cta.pr_ver_operacion(p_nro_cuenta,
                                         v_cod_transaccion,
                                         v_cod_modulo,
                                         v_cod_modalidad,
                                         'D',
                                         v_cod_moneda,
                                         nvl(v_cargos,0),
                                         v_cod_oficina,
                                         v_cod_mod_cta,
                                         v_cod_mad_cta,
                                         v_nvo_estado,
                                         v_sal_disp,
                                         v_pro_cargo);

                If v_pro_cargo = 'N' then
                  --Inserta en ge_mov_pendiente para su posterior cobro.
                  Insert into Ge_Mov_Pendientes
                    (nro_cuenta,
                     Fecha,
                     Cod_modulo,
                     Cod_modalidad,
                     Cod_transaccion,
                     Cod_mod_padre,
                     Cod_mad_padre,
                     Cod_tra_padre,
                     Monto,
                     Hora,
                     Cod_usuario,
                     Cod_moneda,
                     Cod_oficina,
                     Estado,
                     Cod_ofi_origen,
                     Concepto,
                     cod_tasa,
                     Val_tasa,
                     Nro_documento,
                     Car_manual,
                     saldo)
                  Values
                    (p_nro_cuenta,
                     v_fec_actual,
                     v_cod_mod_cuenta,
                     v_tip_cuenta,
                     v_cod_tra_cargo,
                     v_cod_mod_cuenta,
                     v_tip_cuenta,
                     v_cod_tra_cargo,
                     v_cargos,
                     v_hor_actual,
                     USER,
                     v_cod_moneda,
                     v_cod_oficina,
                     'I',
                     v_cod_oficina,
                     'Cargo por Extracción en M/E',
                     V_COD_TAS_CARGO, -- tasa
                     V_VAL_TAS_CARGO, -- valor de tasa
                     p_nro_boleta,
                     'N',
                     v_cargos);
                else
                      pag_cta.pr_act_operacion(p_nro_cuenta,
                                           v_hor_actual,
                                           'D', -- debito a la cuenta del cliente
                                           v_cod_moneda,
                                           v_val_cargo,
                                           v_cod_tra_cargo,
                                           v_cod_tra_cargo,-- trans. hijo
                                           p_nro_boleta,
                                           null, -- cotizacion
                                           v_cod_oficina,
                                           v_cod_mod_cuenta,
                                           v_tip_cuenta,
                                           V_COD_TAS_CARGO, -- tasa
                                           V_VAL_TAS_CARGO, -- valor de tasa
                                           'Cargo por Extraccion en M/E', --concepto
                                           'N', -- emitir aviso
                                           v_nro_secuencia, -- nro de secuencia
                                           v_fec_actual, null, null, null, v_est_movimiento);-- C.D.Fase III
                      if pag_cta.g_cod_error <> 0 then
                        -- actualizacion con problemas
                        v_cod_respuesta := ltrim(to_char(pag_cta.g_cod_error,'000'));
                        v_msj_respuesta := pag_cta.g_msj_error;
                      else
                        if v_val_impuesto > 0 then
                          pag_cta.pr_act_operacion(p_nro_cuenta,
                                               v_hor_actual,
                                               'D', -- debito a la cuenta del cliente
                                               v_cod_moneda,
                                               v_val_impuesto,
                                               V_COD_TRA_IMPUESTO,
                                               V_COD_TRA_IMPUESTO, -- trans. hijo
                                               p_nro_boleta,
                                               null, -- cotizacion
                                               v_cod_oficina,
                                               v_cod_mod_cuenta,
                                               v_tip_cuenta,
                                               V_COD_TAS_IMPUESTO, -- tasa
                                               V_VAL_TAS_IMPUESTO, -- valor de tasa
                                               'IVA s/Cargo por Extraccion en M/E', --concepto
                                               'N', -- emitir aviso
                                               v_nro_secuencia, -- nro de secuencia
                                               v_fec_actual, null, null, null, v_est_movimiento); -- C.D Fase III
                          if pag_cta.g_cod_error <> 0 then
                             -- actualizacion con problemas
                             v_cod_respuesta := ltrim(to_char(pag_cta.g_cod_error,'000'));
                             v_msj_respuesta := pag_cta.g_msj_error;
                          End if;
                        End if;
                      End if;
                 End If;
              End if;
              /* Si se genera Pedido de Autorización no debe actualizar CJ_CONTROLES */
              if nvl(v_nro_pedido,0) > 0 then
                 lp_gen_transaccion('P');
              else
                 lp_gen_transaccion('N');
               end if;
            End if;
          end if;
         -----*
         ---EXTRACCION NO IMPRIME DECL.JURADA, SOLO BOLETA
         /*if v_cod_respuesta = '000' then

            if pag_gen.FU_CON_MON_A_MONEDA(v_cod_moneda, -- moneda origen
                                           pag_gen.FU_OBT_MON_FUERTE, -- moneda dolar
                                           v_importe) >= fug_obt_pardinamico('OPE_SUP_MON_FUERTE') then
               -- paso el monto minimo a informar. Generar el informe de operaciones > a USD 10000
               v_cod_respuesta := 'IMP'; -- para indicar que esta ok y se puede imprimir
               v_msj_respuesta := 'Operacion Confirmada. Comprobante de Pago ha sido impreso.'||'~'||
               fuj_imp_dec_jurada(v_fec_actual, v_hor_actual, user);
               -- retorno de la rutina de impresion
                v_msj_salida := p_nro_operacion||'~'||
                                v_cod_respuesta||'~'||
                                v_msj_respuesta;
                return(v_msj_salida);
            end if;
         end if;
*/     -----*

       end if;
    end if;
  end if; --> Condicion de cuenta migrada
 end if;

 -- mensaje final sino hubo errores
 if v_cod_respuesta = '000' then -- sino hubo problemas, se carga mensaje por defecto
   /*Si se genera un Pedido de Aut. no debe imprimir el comprobante,
      al autorizar, se reimprime el comprobante*/
   if nvl(v_nro_pedido,0) = 0 then
      lp_act_can_impresion; -- C.D.Fase III--
      v_msj_respuesta := 'Operacion confirmada. Comprobante ha sido impreso'||'~'||
      fuj_imp_comprobante_353(p_nro_boleta,
                              v_cod_oficina,
                              p_nro_caja);
      v_cod_respuesta := 'IMP';
    else
      v_msj_respuesta := 'Se ha generado el Pedido de Autorización Nro.:'||v_nro_pedido;
    end if;
    --Notificaciones Fase 3
    v_ret := paw_not.fu_not_deb_caja(p_nro_cuenta,p_importe,v_cod_moneda,v_fec_actual);
 end if;
 /* falta armar el mensaje de respuesta */
 v_msj_salida := p_nro_operacion||'~'||
                 v_cod_respuesta||'~'||
                 nvl(v_msj_respuesta,'Operacion confirmada');
 return(v_msj_salida);
end FUJ_PRO_TRANSACCION_353;
/
