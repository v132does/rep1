CREATE OR REPLACE FUNCTION IT.FUJ_PRO_TRANSACCION_215
 (P_NRO_OPERACION   IN VARCHAR2,
 P_NRO_CAJA        IN VARCHAR2,
 P_COD_SERVICIO    IN VARCHAR2,
 P_REFERENCIA1     IN VARCHAR2 default null,
 P_REFERENCIA2     IN VARCHAR2 default null,
 p_mto_total       in number default null,  -- total a cobrar
 p_mto_efectivo    in number default null, --total efectivo
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
-- RI : 07/04/2010 : La transaccion no debe ser fija, depende del servicio que se procesa
  v_cod_transaccion ge_transacciones.cod_transaccion%type;
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
  v_cod_error         varchar2(200);

  -- Datos de salida
  v_msj_salida    varchar2(8000);                          -- mensaje final retornado
  v_cod_respuesta varchar2(03) := '000';                   -- sin errores
  v_msj_respuesta varchar2(4000) := 'Operacion Confirmada'; -- sin errores

  -- datos de la operacion convertidos
  v_tipo          varchar2(01) := 'D' ;     -- 'C' credito para la caja (egreso) o vice versa
  v_tip_monto     varchar2(01) := 'O';       -- E efectivo / O cheque otros Bcos
  v_nro_secuencia number(3) := 0;           -- secuencia del mov.

  -- datos que se cargan en la pantalla
  v_mto_total     number(18,2) := nvl(to_number(p_mto_total),0);
  v_mto_cobrado   number(18,2) := nvl(p_mto_efectivo,0) + nvl(p_mto_cheque,0) + nvl(p_mto_che_nstro,0);

  -- para obtener servicio
  v_nro_operacion  ge_cob_servicios.nro_operacion%type;


  r_par            ge_cob_ser_parametros%rowtype;
  r_cobro          ge_cob_servicios%rowtype;
  v_ubi_banco      ge_bancos.ubicacion%type;
  v_des_banco      ge_bancos.descripcion%type;
  v_cod_tra_cheque ge_movimientos.cod_transaccion%type;
  v_cta_cheque      cc_chequeras.nro_cuenta%type;
  v_mon_fuerte         ge_movimientos.cod_moneda%type := pag_gen.FU_OBT_MON_FUERTE;
  v_error  number;
  
  v_cli_frecuente  cr_inf_fondos.cli_frecuente%type;  
  v_cod_tra_formularios varchar(200) :=  substr(fug_obt_pardinamico('COD_TRA_FORMULARIOS'),1,200);
  v_imp_dec_jurada boolean := false;

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
           (r_par.nro_cuenta, v_fec_actual, v_hor_actual, v_cod_usuario, v_nro_secuencia,
            v_cod_transaccion,v_cod_modulo, v_cod_modalidad,
            v_cod_oficina, v_cod_moneda, to_number(p_nro_caja),
            v_nro_operacion, p_mto_efectivo,'E', v_tipo);  -- es debito
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
            v_nro_operacion, r_par.nro_cuenta, p_mto_che_nstro,'C' /* cheq.nuestro bcos */, v_tipo); /* es debito */
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
            v_nro_operacion, r_par.nro_cuenta, p_mto_cheque,v_tip_monto /* cheq.otros bcos */, v_tipo); /* es debito */
      end if;
  end lp_gen_transaccion;
---------------- INICIO DEL PROCESO PRINCIPAL ------------------

--- TODO LO QUE TIENE QUE HACER
/*
 VALIDAR FORMATOS    -- ok
 VALIDAR NRO DOCUMENTO --ok
 VERIFICAR SI YA FUE GRABADO  ---ok
 VALIDAR ESTADO CAJA --ok
 GENERAR NRO DOCUMENTO --ok
 GENERAR MOVIMIENTOS : (EFECTIVO, CHEQUE )
 GENERAR RETENCION SI ES CHEQUE
 ACTUALIZAR CTA. CREDITO
 ACTUALIZAR CONTROL CAJA
 INSERTAR REGISTRO EN GE_COB_SERVICIOS
*/
----
Begin
 -- Inicializacion de la aplicacion y el modulo
 Begin PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=v_cod_modulo; End;
 -- Valido la moneda
 if p_cod_servicio is null then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el Código de Servicio.';
 elsif v_mto_cobrado is null or v_mto_cobrado <= 0 then
    v_cod_respuesta := '003'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el importe.';
 elsif v_mto_total  <> v_mto_cobrado then
    v_cod_respuesta := '004'; -- error
    v_msj_respuesta := 'ERROR: Monto Total no suma Detalles.';
 elsif p_referencia1 is null and p_referencia2 is null then
    v_cod_respuesta := '005'; -- error
    v_msj_respuesta := 'ERROR: Ingrese Referencia';
 end if;

 if v_cod_respuesta = '000' then
   --validar los datos ingresados
   v_msj_salida:= FUJ_VAL_TRANSACCION_215(p_nro_operacion, p_nro_caja, p_cod_servicio,
         p_referencia1, p_referencia2, p_mto_total, p_mto_efectivo, p_nro_che_nstro, p_mto_che_nstro,
         p_tip_retencion, p_nro_cheque, p_mto_cheque, p_cod_banco);
   if v_msj_salida NOT LIKE '%~OK~%' THEN
      return v_msj_salida;
   END IF;
 end if;

 if v_cod_respuesta = '000' then -- sino hubo problemas, verifico el servicio
    Begin
     Select s.* into r_par
       from ge_cob_ser_parametros s
      where s.cod_servicio = p_cod_servicio
        and s.hab_caja = 'S';
     v_cod_transaccion := r_par.cod_transaccion;
    exception
         when no_data_found then
           v_cod_respuesta := '002';
           v_msj_respuesta := 'ERROR: Servicio no existe!';
         when others then
           v_cod_respuesta := '003';
           v_msj_respuesta := 'ERROR' || sqlerrm;
    end;
    if v_cod_respuesta = '000' then
       --inicializar variables de error
       pag_ser.pr_ini_variables;
       --obtener datos del servicio
       pag_ser.pr_obt_servicio( p_cod_servicio);
       if pag_ser.fu_obt_error(v_error,v_msj_respuesta) then
         v_cod_respuesta :='055';
       else
         v_cod_respuesta :='000';
       end if;
       if v_cod_respuesta = '000' then
          v_cod_moneda := pag_ser.g_cod_moneda;
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
            v_msj_respuesta := 'Realice la Apertura de Caja previamente';
         elsif v_fec_caja <> v_fec_actual then
            v_cod_respuesta := '005'; -- error
            v_msj_respuesta := 'Caja no fue habilitada el dia de hoy';
         end if;
      end if;
    end if;
 end if;

 if v_cod_respuesta = '000' Then
  --- Validar formatos de los 2 campos
   pag_Ser.lp_val_referencia(p_referencia1,r_par.For_Campo1,r_par.val_campo1);
   if pag_ser.fu_obt_error(v_error,v_msj_respuesta) then
      v_cod_respuesta :='001';
   else
      v_cod_respuesta :='000';
   end if;
   if v_cod_respuesta = '000' Then
      if p_referencia2 is not null and r_par.eti_campo2 is not null then
         pag_Ser.lp_val_referencia(p_referencia2,r_par.For_Campo2,r_par.val_campo2);
         if pag_ser.fu_obt_error(v_cod_error,v_msj_respuesta) then
            v_cod_respuesta :='002';
         else
            v_cod_respuesta :='000';
         end if;
      end if;
   end if;
   --- Validar nro de documento de los 2 campos
   if v_cod_respuesta = '000' Then
      if p_referencia1 is not null then
        if pag_ser.lf_ya_fue_grabado(p_cod_servicio,p_referencia1,1) = 'S' then
         v_cod_respuesta := '010';
         v_msj_respuesta := 'Documento 1 ya fue grabado';
        end if;
      end if;

      if p_referencia2 is not null then
        if pag_ser.lf_ya_fue_grabado(p_cod_servicio,p_referencia2,1) = 'S' then
         v_cod_respuesta := '010';
         v_msj_respuesta := 'Documento 2 ya fue grabado';
        end if;
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
 if v_cod_respuesta = '000' then
   --- genero el numero de operacion
    BEGIN
      select nvl( max( nro_operacion ), 0 ) + 1
        into v_nro_operacion
        from ge_cob_servicios
       where cod_servicio = p_cod_servicio
         and tip_cobro = 'C';
    EXCEPTION
      when others then
        v_nro_operacion := 1;
    END;
  
 end if;

 --- Insertar el cobro del servicio
 v_cod_usuario   := upper(user);
 --- cargar los datos en r_cobro antes de pasarle como parametro
 r_cobro.cod_servicio      := p_cod_servicio;
 r_cobro.tip_cobro         := 'C';
 r_cobro.nro_operacion     := v_nro_operacion;
 r_cobro.fecha             := v_fec_actual;
 r_cobro.hora              := v_hor_actual;
 r_cobro.referencia1       := p_referencia1;
 r_cobro.referencia2       := p_referencia2;
 r_cobro.monto             := p_mto_total;
 r_cobro.cod_moneda        := v_cod_moneda;
 r_cobro.mto_efectivo      := p_mto_efectivo;
 r_cobro.mto_che_nue_banco := p_mto_che_nstro;
 r_cobro.mto_che_otr_banco := p_mto_cheque;
 r_cobro.nro_caja          := to_number(p_nro_caja);
 r_cobro.cod_ofi_origen    := v_cod_oficina;
 r_cobro.cod_usuario       := v_cod_usuario;
 r_cobro.estado            := 'P';

 --insertar el cobro en ge_cob_servicios
 if v_cod_respuesta = '000' then -- sino hubo ERROR se arma los datos para grabar
   pag_Ser.pr_ins_cobro( r_cobro, v_cod_transaccion, 'C' );
   if pag_ser.fu_obt_error(v_error,v_msj_respuesta) then
      v_cod_respuesta :='071';
   else
      v_cod_respuesta :='000';
   end if;
 end if;
 -- Procesar Resumen de Servicio,ya no,se usa sólo para remisión
 -- fin sino hubo error para procesar
 --dependiendo de la forma de cobro, se acredita a la cuenta...
 if v_cod_respuesta = '000' then -- sino hubo ERROR se arma los datos para grabar
   -- Asigno el nro de caja a los movimientos
   pag_cta.pr_nro_caja(to_number(p_nro_caja));

   -- si es efectivo
   if p_mto_efectivo > 0 then
      -- PROCESAR_CREDITO_AHORRO_VISTA y PROCESAR_CREDITO_CTA_CORRIENTE
      pag_cta.pr_act_operacion( r_par.nro_cuenta,
                         v_hor_actual,
                         'C',
                         v_cod_moneda,           ---ver
                         p_mto_efectivo,
                         v_cod_transaccion,  ---ver
                         690, --trans.hijo. depósito en efectivo
                         v_nro_operacion,
                         null,
                         r_par.cod_oficina,
                         r_par.cod_modulo,
                         r_par.cod_modalidad,
                         NULL,
                         NULL,
                         'Credito p/ Cobros en Caja',
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
       pag_cta.pr_act_operacion(r_par.nro_cuenta,
                                v_hor_actual,
                               'C', -- credito
                                v_cod_moneda,
                                p_mto_che_nstro,
                                v_cod_transaccion,
                                606, -- trans. hijo de cheq.nuestro bco
                                v_nro_operacion,
                                null, -- cotizacion
                                r_par.cod_oficina,
                                r_par.cod_modulo,
                                r_par.cod_modalidad,
                                null, -- tasa
                                null, -- valor de tasa
                                'Cobro en caja Chq.Nstro.Bco.', --concepto
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
      pag_cta.pr_act_operacion(r_par.nro_cuenta,
                                v_hor_actual,
                               'C', -- credito
                                v_cod_moneda,
                                p_mto_cheque,
                                v_cod_transaccion,
                                v_cod_tra_cheque, -- trans. hijo de cheq.otros bcos
                                v_nro_operacion,
                                null, -- cotizacion
                                r_par.cod_oficina,
                                r_par.cod_modulo,
                                r_par.cod_modalidad,
                                null, -- tasa
                                null, -- valor de tasa
                                'Cobro en caja Cheq.Pl.Local-24 Hs.', --concepto
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
                                                      v_nro_operacion,
                                                      p_tip_retencion,
                                                      p_cod_banco,
                                                      p_nro_cheque,
                                                      p_mto_cheque);

                 if v_msj_salida NOT LIKE '%~000~%' THEN
                    return v_msj_salida;
                 END IF;
              end if;
          else  --si es extranjero -> 134,
             v_msj_salida := fuj_pro_transaccion_134(p_nro_operacion,
                                                  p_nro_caja,
                                                  v_nro_operacion,
                                                  p_cod_banco,
                                                  v_des_banco,
                                                  p_nro_cheque,
                                                  p_mto_cheque);

             if v_msj_salida NOT LIKE '%~000~%' THEN
                return v_msj_salida;
             END IF;
          end if;
       end if;
    end if;

   if v_cod_respuesta = '000' then
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
                                                   v_nro_operacion,
                                                   p_nro_che_nstro,
                                                   v_cta_cheque, --cuenta
                                                   p_mto_che_nstro,
                                                   null, --CROEFEBCO-28: Mejoras en la Operativa de Efectivo
                                                   pag_gen.FU_OBT_SIG_SEGUNDO(pag_gen.FU_OBT_SIG_SEGUNDO(v_hor_actual)));

              if v_msj_salida NOT LIKE '%~000~%' THEN
                 return v_msj_salida;
              END IF;
          end if;
       end if;
   end if;
   begin
     select nvl(cli_frecuente,'N')
       into v_cli_frecuente
       from cr_inf_fondos
      where cod_persona = r_par.cod_persona;
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
   
   -- verificamos si la transaccion está parametrizada:
   v_imp_dec_jurada := (instr(','|| v_cod_tra_formularios ||',',',' || 215 || ',') > 0);   
   if v_cod_respuesta = '000' then    
      --si la operación es superior avisar q se imprima la declaración x gestión
      if pal_Cam.FU_CON_MON_A_MONEDA(v_cod_moneda,v_mon_fuerte,v_mto_cobrado) >= fug_obt_pardinamico('OPE_SUP_MON_FUERTE')
        and v_imp_dec_jurada then
         v_cod_respuesta := 'IMP';
         if v_cli_frecuente = 'N' then
           v_msj_respuesta := 'Operación Confirmada. Comprobante y Decl.Jurada impresos. Oper.Nro. '||v_nro_operacion||'~'||
                            fuj_imp_comprobante_215(v_nro_operacion, v_cod_oficina, p_nro_caja)||
                            fuj_imp_dec_jurada_40(v_fec_actual, v_hor_actual, user, 1);
         else
           v_cod_respuesta := 'IMP';
           v_msj_respuesta := 'Operación Confirmada. Comprobante impreso.'||'~'||
                               fuj_imp_comprobante_215(v_nro_operacion, v_cod_oficina, p_nro_caja);
         end if;
      else
         v_cod_respuesta := 'IMP';
         v_msj_respuesta := 'Operación Confirmada. Comprobante impreso.'||'~'||
                               fuj_imp_comprobante_215(v_nro_operacion, v_cod_oficina, p_nro_caja);
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
end FUJ_PRO_TRANSACCION_215;
/

