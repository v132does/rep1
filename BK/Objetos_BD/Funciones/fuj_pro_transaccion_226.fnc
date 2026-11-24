CREATE OR REPLACE FUNCTION IT.FUJ_PRO_TRANSACCION_226 (
      p_nro_operacion in varchar2,              --Nro de referencia de la operacion
      p_nro_caja      in varchar2,              --Nro de Caja
      p_nro_ticket    in varchar2,              --Campo1
      p_mto_total     in number default null)   --Total a cobrar

 RETURN long IS

  -- Datos del Movimiento
  v_cod_modulo      number(3)      := 9;                -- Caja
  v_cod_modalidad   number(3)      := 91;               -- Caja
  v_cod_transaccion number(4)      := 226;              -- transaccion
  v_cod_usuario     varchar2(10)   := upper(user);      -- usuario
  v_fec_actual      date           := pag_cal.fu_obt_fec_actual(v_cod_modulo); -- fecha de hoy
  v_hor_actual      varchar2(08)   := to_char(sysdate,'HH24:MI:SS');           -- Hora actual
  v_nro_secuencia   number(3)      := 0;                -- secuencia del mov.

  -- Datos de la caja*
  v_cod_moneda        varchar2(3);       -- moneda de la cuenta
  v_cod_oficina       number(3);         -- Codigo de oficina
  v_fec_caja          date;              -- fecha de la caja
  v_estado            number(1);         -- estado de la caja
  v_sal_actual        number(18,2);      -- saldo actual de la caja en efectivo
  v_sal_cheques       number(18,2);      -- saldo actual de la caja en cheques

  -- Datos de salida
  v_msj_salida    varchar2(8000);                          -- mensaje final retornado
  v_cod_respuesta varchar2(03) := '000';                   -- sin errores
  v_msj_respuesta varchar2(4000) := NULL;

  -- para obtener servicio
  v_mon_fuerte         ge_movimientos.cod_moneda%type := pag_gen.FU_OBT_MON_FUERTE;

  -- Cobro Por Servicio CPS
  r_par               ge_cob_ser_parametros%rowtype; --Variable de todo un registro de parametro de CPS
  r_cobro             ge_cob_servicios%rowtype;      --Variable de todo un registros de CPS
  v_cod_servicio      number(3) := fug_obt_pardinamico('COD_SER_SOFIA_TLE'); -- este es el nro del servicio
  v_cod_error         varchar2(200); -- Control de error del paquete se CPS
  v_ruc_agente1       varchar2(100);
  v_nom_agente1       varchar2(100);
  v_tip_agente1       varchar2(5);
  v_ruc_agente2       varchar2(100);
  v_nom_agente2       varchar2(100);
  v_tip_agente2       varchar2(5);
  v_tic_mto_total     number;
  v_nro_operacion     ge_cob_servicios.nro_operacion%type;
  v_cli_frecuente     cr_inf_fondos.cli_frecuente%type;
  
  v_cod_tra_formularios varchar(200) :=  substr(fug_obt_pardinamico('COD_TRA_FORMULARIOS'),1,200);
  v_imp_dec_jurada boolean := false;

  -- Procedimiento interno para generar movimiento y act. de control de caja
  procedure lp_gen_transaccion is
  begin
     -- Actualizo el control de caja
     update cj_controles
        set sal_actual = nvl(sal_actual,0) + nvl(p_mto_total,0),
            tot_debitos = nvl(tot_debitos,0) + nvl(p_mto_total,0),
            can_debitos = nvl(can_debitos,0) + decode(p_mto_total,0,0,1),
            estado = 1 -- abierto
      where nro_caja = to_number(p_nro_caja)
        and cod_moneda = v_cod_moneda
        and fecha = v_fec_caja;

     v_nro_secuencia := 0;

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
         v_nro_operacion, p_mto_total,'E','D');
  end lp_gen_transaccion;
---------------- INICIO DEL PROCESO PRINCIPAL ------------------
Begin
 -- Inicializacion de la aplicacion y el modulo
  Begin PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=v_cod_modulo; End;

  --validar los datos ingresados
  v_msj_salida:= FUJ_VAL_TRANSACCION_226(p_nro_operacion, p_nro_caja, p_nro_ticket, p_mto_total);
  if v_msj_salida NOT LIKE '%~OK~%' THEN
     return v_msj_salida;
  else
     if nvl(p_mto_total,0) <= 0 then
           v_cod_respuesta := '003';
           v_msj_respuesta := 'ERROR: Ingrese el monto total del ticket';

     end if;
  end if;


  if v_cod_respuesta = '000' then -- sino hubo problemas, verifico el servicio
     Begin
       Select s.*
         into r_par
         from ge_cob_ser_parametros s
        where s.cod_servicio = v_cod_servicio;
     exception
        when no_data_found then
           v_cod_respuesta := '006';
           v_msj_respuesta := 'ERROR: Servicio '||v_cod_servicio||' no existe. Debe ser definido!';
        when others then
           v_cod_respuesta := '007';
           v_msj_respuesta := 'ERROR' || sqlerrm;
     end;
     if v_cod_respuesta = '000' then
        --inicializar variables de error
        pag_ser.pr_ini_variables;
        --obtener datos del servicio
        pag_ser.pr_obt_servicio( v_cod_servicio);
        if pag_ser.fu_obt_error(v_cod_error,v_msj_respuesta) then
          v_cod_respuesta :='008';
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
             v_cod_respuesta := '011'; -- error, no existe registro de caja
             v_msj_respuesta := 'Caja inexistente!!';
          elsif v_estado in (0,2) then
             v_cod_respuesta := '012'; -- error
             v_msj_respuesta := 'Realice la Apertura de Caja previamente';
          elsif v_fec_caja <> v_fec_actual then
             v_cod_respuesta   := '013'; -- error
             v_msj_respuesta := 'Caja no fue habilitada el dia de hoy';
          end if;
       end if;
     end if;
  end if;

  if v_cod_respuesta = '000' Then
   --- Validar formatos de campos
    if p_nro_ticket is null or r_par.eti_campo1 is null then
       -- Valido el Formato de
       v_cod_respuesta := '016';
       v_msj_respuesta := 'No se Ingreso el Nro de Boleta o no tiene definido el formato';
    else
       pag_Ser.lp_val_referencia(p_nro_ticket,r_par.For_Campo1,r_par.val_campo1);
       if pag_ser.fu_obt_error(v_cod_error,v_msj_respuesta) then
          v_cod_respuesta :='017';
       else
          v_cod_respuesta :='000';
       end if;
    end if;
  end if;

  if v_cod_respuesta = '000' then
    --- genero el numero de operacion
    v_nro_operacion := fue_obt_sig_secuencia('S_NRO_OPE_SOFIA');
  end if;

  if v_cod_respuesta = '000' then
      -- verifico los datos
      v_msj_respuesta := pag_dna.fu_pro_dna_ticket(r_par.tip_servicio,
                                                   'Q',
                                                   trim(to_char(to_number(p_nro_caja),'000')),
                                                   v_nro_operacion,
                                                   p_nro_ticket,
                                                   v_ruc_agente1,
                                                   v_nom_agente1,
                                                   v_tip_agente1,
                                                   v_ruc_agente2,
                                                   v_nom_agente2,
                                                   v_tip_agente2,
                                                   v_tic_mto_total);
      if v_msj_respuesta not like '00-%' then
         -- hay error
         v_cod_respuesta := '063';
      else
         if nvl(p_mto_total,0) <> nvl(v_tic_mto_total,0) then
            v_cod_respuesta := '064';
            v_msj_respuesta := 'Monto Total no coincide con el monto del Ticket: ' || to_char(v_tic_mto_total);
         end if;
      end if;
  end if;

  --- cargar los datos en r_cobro antes de pasarle como parametro
  r_cobro.cod_servicio      := v_cod_servicio;
  r_cobro.tip_cobro         := 'C';
  r_cobro.nro_operacion     := v_nro_operacion;
  r_cobro.fecha             := v_fec_actual;
  r_cobro.hora              := v_hor_actual;
  r_cobro.referencia1       := p_nro_ticket;
  r_cobro.referencia2       := null;
  r_cobro.monto             := p_mto_total;
  r_cobro.cod_moneda        := v_cod_moneda;
  r_cobro.mto_efectivo      := p_mto_total;
  r_cobro.mto_che_nue_banco := 0;
  r_cobro.mto_che_otr_banco := 0;
  r_cobro.nro_caja          := to_number(p_nro_caja);
  r_cobro.cod_ofi_origen    := v_cod_oficina;
  r_cobro.cod_usuario       := v_cod_usuario;
  r_cobro.estado            := 'P';
  r_cobro.referencia3       := substr(v_nom_agente1,1,50);
  r_cobro.referencia4       := substr(v_nom_agente2,1,50);

  --insertar el cobro en ge_cob_servicios
  if v_cod_respuesta = '000' then -- sino hubo ERROR se arma los datos para grabar
    pag_Ser.pr_ins_cobro( r_cobro, v_cod_transaccion, 'C' );
    if pag_ser.fu_obt_error(v_cod_error,v_msj_respuesta) then
       v_cod_respuesta :='091';
    else
       v_cod_respuesta :='000';
    end if;
  end if;

  --dependiendo de la forma de cobro, se acredita a la cuenta...
  if v_cod_respuesta = '000' then --R000 -1
    -- Asigno el nro de caja a los movimientos y estado (P)endiente
    pag_cta.pr_nro_caja(to_number(p_nro_caja));
    --pag_cta.PR_SET_EST_MOVIMIENTO('P');

    v_nro_secuencia := nvl(v_nro_secuencia,0) + 1;
    -- Procesar credito por Efectivo en Ahorro o Cta Cte
    pag_cta.pr_act_operacion( r_par.nro_cuenta,
                              v_hor_actual,
                              'C', --Tipo credito
                              v_cod_moneda,
                              p_mto_total,
                              v_cod_transaccion,
                              690, --trans.hijo. depósito en efectivo
                              v_nro_operacion,
                              null, -- Cotizacion
                              v_cod_oficina,
                              v_cod_modulo,
                              v_cod_modalidad,
                              null, -- Tasa
                              null, -- Valor de tasa
                              'Boleta: '||p_nro_ticket,
                              'S', -- Emitir aviso
                              v_nro_secuencia,
                              v_fec_actual,
                              null,
                              null );
    If pag_cta.fu_obt_cod_error() <> 0 then
       v_cod_respuesta := '021';
       v_msj_respuesta := 'Efec. '||pag_cta.fu_obt_msj_error();
    End if;
  end if;

  -- Sino hubo ERROR o Grabo todos
  if v_cod_respuesta = '000' then
    -- Actualizar y crear los mvtos de Caja
    lp_gen_transaccion;
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
  
  -- Se elimina el llamado de la de la linea 188 y se inserta en este lugar
  -- Si no hubo Error Confirmamos la transacción en Aduanas - DYDMR-612 - MyR-RABP-12_08_2014
  if v_cod_respuesta = '000' then -- sino hubo ERROR
     v_msj_respuesta := pag_dna.fu_pro_dna_ticket(r_par.tip_servicio,
                                                  'E',
                                                  trim(to_char(to_number(p_nro_caja),'000')),
                                                  v_nro_operacion,
                                                  p_nro_ticket,
                                                  v_ruc_agente1,
                                                  v_nom_agente1,
                                                  v_tip_agente1,
                                                  v_ruc_agente2,
                                                  v_nom_agente2,
                                                  v_tip_agente2,
                                                  v_tic_mto_total);
     if v_msj_respuesta not like '00-%' then
        -- hay error
        v_cod_respuesta := '094';
     end if;
  end if;

  --imprimir comprobante
  -- verificamos si la transaccion está parametrizada:
   v_imp_dec_jurada := (instr(','|| v_cod_tra_formularios ||',',',' || 226 || ',') > 0);
  if v_cod_respuesta = '000' then
     --si la operación es superior avisar q se imprima la declaración x gestión
     if pal_Cam.FU_CON_MON_A_MONEDA(v_cod_moneda,v_mon_fuerte,p_mto_total) >= fug_obt_pardinamico('OPE_SUP_MON_FUERTE')
       and v_imp_dec_jurada then
        v_cod_respuesta := 'IMP';
        if v_cli_frecuente = 'N' then
          v_msj_respuesta := 'Operación Confirmada. Comprobante y Decl.Jurada impresos. Oper.Nro. '||v_nro_operacion||'~'||
                             fuj_imp_comprobante_226(v_nro_operacion, v_cod_oficina, p_nro_caja)||
                             fuj_imp_dec_jurada_40(v_fec_actual, v_hor_actual, user, 2);
        else
          v_cod_respuesta := 'IMP';
          v_msj_respuesta := 'Operación Confirmada. Comprobante impreso.'||'~'||
                              fuj_imp_comprobante_226(v_nro_operacion, v_cod_oficina, p_nro_caja);
        end if;
     else
        v_cod_respuesta := 'IMP';
        v_msj_respuesta := 'Operación Confirmada. Comprobante impreso.'||'~'||
                           fuj_imp_comprobante_226(v_nro_operacion, v_cod_oficina, p_nro_caja);
     end if;
  end if;

  /* falta armar el mensaje de respuesta */ -- DYDMR-612 - MyR-RABP-12_08_2014
  if v_cod_respuesta in ('000','IMP') then
      v_msj_salida := p_nro_operacion||'~'||
                      v_cod_respuesta||'~'||
                      nvl(v_msj_respuesta,'Operacion Confirmada');
  else
      v_msj_salida := p_nro_operacion||'~'||
                      v_cod_respuesta||'~'||
                      nvl(v_msj_respuesta,'Operacion con Error - Reintente');             
  end if;
  
  return(v_msj_salida);
exception
   when others then
     v_cod_respuesta := '999';
     v_msj_salida := p_nro_operacion||'~'||
                     v_cod_respuesta||'~'||
                     nvl(v_msj_respuesta,SQLERRM);
     return(v_msj_salida);
end FUJ_PRO_TRANSACCION_226;
/

