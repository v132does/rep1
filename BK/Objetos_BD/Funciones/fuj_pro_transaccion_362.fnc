CREATE OR REPLACE FUNCTION IT.FUJ_PRO_TRANSACCION_362
 (P_NRO_OPERACION IN VARCHAR2
 ,P_NRO_CAJA IN VARCHAR2
 ,P_NRO_COMPROBANTE IN NUMBER default null --nro de comprobante manual
 ,P_NRO_CUENTA IN VARCHAR2
 )
 RETURN  LONG
 IS
Begin
declare

-- defino por defecto el modulo y modalidad a utilizar
  v_cod_modulo      number(3)      := 9;    -- Caja
  v_cod_modalidad   number(3)      := 91;   -- Caja
  v_cod_transaccion number(4)      := 362;  -- transaccion
  v_cod_usuario     varchar2(10);--   := upper(user); --usuario
  v_cod_persona     ba_personas.cod_persona%type;
  -- Datos de la caja
  v_fec_actual        date         := pag_cal.fu_obt_fec_actual(v_cod_modulo); -- fecha de hoy
  v_hor_actual        varchar2(08) := to_char(sysdate,'HH24:MI:SS');   -- Hora actual
  v_cod_oficina       number(3);         -- Codigo de oficina
  v_cod_ofi_cta       number(3);
  v_estado            number(1);         -- estado de la caja
  v_fec_caja          date;              -- fecha de la caja
  v_sal_actual        number(18,2);      -- saldo actual de la caja en efectivo
  v_sal_cheques       number(18,2);      -- saldo actual de la caja en cheques
  -- Datos de la cuenta
  v_nro_cuenta        varchar2(20);      -- numero de cuenta
  v_cod_moneda        varchar2(3);       -- moneda de la cuenta
  v_cod_mon_local     varchar2(4) := pag_gen.fu_obt_mon_local;
  v_est_cuenta        varchar2(1);       -- estado de la cuenta
  -- Datos de la cuenta de préstamo
  v_denominacion       varchar2(100);     -- Nombre de la cuenta
  v_mto_cobrado        number(18,2);      -- Mto cobrado (no se despliega)
  v_tip_cuenta         number(3);         -- modalidad cta
  v_nro_cuota_desde    number(3);         -- nro. cuota a pagar desde
  v_nro_cuota_hasta    number(3);         -- nro. cuota a pagar hasta
  v_can_tot_cuotas     number(3);
  -- Datos de salida
  v_msj_salida    long;--varchar2(8000);                          -- mensaje final retornado
  v_cod_respuesta varchar2(03) := '000';                   -- sin errores
  v_msj_respuesta long := 'Operacion Confirmada'; -- sin errores

  -- datos de la operacion convertidos
  v_tipo          varchar2(01) := 'D' ;     -- 'D' para la caja (ingreso)
  v_tip_monto     varchar2(01) := 'O';       -- E efectivo / O cheque otros Bcos
  v_nro_secuencia number(3) := 0;           -- secuencia del mov.

  v_mon_local     varchar2(3) := pag_gen.fu_obt_mon_local; -- moneda local
  v_nro_documento cj_movimientos.nro_documento%type;
--  v_nro_factura   cj_movimientos.nro_documento%type;
  v_nro_factura   cb_lib_ventas.nro_factura%type;  --RI: 02/07/2010
  v_venc          number;  

  v_mod_cobro     number(3) := 6 ; ---- modulo del préstamo
  v_mad_cobro     number(3);       ---- modalidad del préstamo

  --- para operaciones pendientes
  v_hora                varchar2(8) :=null;  --- para recuperar hora de oper.pendiente
  v_cod_tran_pend       number(4);     --- transaccion efectivo o cheque
  v_nro_cuota           number(3);
  v_tot_capital         number(18,2);
  v_tot_interes         number(18,2);
  v_tot_int_adelantado  number(18,2);
  v_tot_mora            number(18,2);
  v_tot_mora_interes    number(18,2);
  v_tot_mora_int_adel   number(18,2);
  v_tot_impuesto        number(18,2);
  v_tot_cargo           number(18,2);
  v_tot_cargo_iva       number(18,2);
  v_tot_int_descontado  number(18,2);
  v_tot_iva_descontado  number(18,2);
  v_tot_seg_descontado  number(18,2);
  v_tot_punitorio       number(18,2);
  v_tot_cap_int         number(18,2);
  v_tot_mora_cap        number(18,2);
  v_tot_a_cobrar        number(18,2);
  v_tot_deb_cta         number(18,2);
  v_tot_deb_cta_con     number(18,2);

  v_mto_efectivo        number(18,2);
  v_mto_cheque          number(18,2);
  v_mto_cheque_ntro     number(18,2);
  v_cod_retencion       ge_movimientos.cod_retencion%type;
  v_fec_fin_retencion   ge_movimientos.fec_fin_retencion%type;
  v_existe              varchar2(1);
  v_cuo_desde           number(3);
  --emisión de comprobante automático
  v_emi_aviso ge_movimientos.emi_aviso%type := 'S';
  --para la retención de cheques
  v_cod_tra_chq_retomada ge_movimientos.cod_transaccion%type;

  cursor c_cobros is
   select cod_transaccion, monto, nro_documento --
     from ge_movimientos
    where cod_tra_padre = v_cod_transaccion
      and fecha         = v_fec_actual
      and hora          = v_hora
      and cod_usuario   = v_cod_usuario
      and reversado     = 'N'
      and estado        = 'J' ;

  -- Procedimiento interno para generar movimiento y act. de control de caja
  procedure lp_gen_transaccion  is
  begin
      -- Actualizo el control de caja y movim. caja
      update cj_controles
      set tot_che_otr_bco = nvl(tot_che_otr_bco,0) + nvl(v_mto_cheque,0),
          sal_che_otr_bco = nvl(sal_che_otr_bco,0) + nvl(v_mto_cheque,0),
          tot_che_nue_bco = nvl(tot_che_nue_bco,0) + nvl(v_mto_cheque_ntro,0),
          sal_actual = nvl(sal_actual,0) + nvl(v_mto_efectivo,0),
          tot_debitos = nvl(tot_debitos,0) + nvl(v_mto_efectivo,0),
          can_debitos = nvl(can_debitos,0) + decode(v_mto_efectivo,0,0,1),
          estado = 1 -- abierto
      where nro_caja   = to_number(p_nro_caja)
      and cod_moneda = v_cod_moneda
      and fecha      = v_fec_caja;

      v_nro_secuencia := 0;

      -- genero el movimiento por el pago de la cuota (cheque y/o efectivo)
		--insertar cj_movimientos
      if v_mto_efectivo > 0 then
        --genero el movimiento por el efectivo
		  v_nro_secuencia := v_nro_secuencia + 1;
		  insert into cj_movimientos
           (nro_cuenta,fecha, hora, cod_usuario, nro_secuencia,
            cod_tra_padre, cod_mod_padre, cod_mad_padre,
            cod_oficina, cod_moneda, nro_caja,
            nro_documento, monto, tip_monto, tipo)
        values
           (p_nro_cuenta,v_fec_actual, v_hor_actual, v_cod_usuario, v_nro_secuencia,
            v_cod_transaccion, v_cod_modulo, v_cod_modalidad,
            v_cod_oficina, v_cod_moneda, to_number(p_nro_caja),
            --nvl(v_nro_documento,v_nro_factura), 
            v_nro_documento, --RI: 01/07/2010: Se graba solo nro. recibo            
            v_mto_efectivo,'E', v_tipo);  -- es debito
      end if;
      --
      if v_mto_cheque > 0 then
        -- genero el movimiento por el deposito en cheques (local - otros bcos )
        /*
        if v_cod_tra_chq_retomada = 607 then --24hs
          v_tip_monto := 'O';
        elsif v_cod_tra_chq_retomada = 610 then --48hs
          v_tip_monto := 'T';
        elsif v_cod_tra_chq_retomada = 632 and v_cod_moneda <> v_cod_mon_local then --72hs
          v_tip_monto := 'X';
        elsif v_cod_tra_chq_retomada = 632 then --72hs
          v_tip_monto := 'S'; 
        end if;
        */
        --
        v_nro_secuencia := v_nro_secuencia + 1;
        insert into cj_movimientos
           (nro_cuenta, fecha, hora, cod_usuario, nro_secuencia,
            cod_tra_padre,
            cod_mod_padre,
            cod_mad_padre,
            cod_oficina, cod_moneda, nro_caja,
            nro_documento, monto, tip_monto, tipo)
        values
           (p_nro_cuenta, v_fec_actual, v_hor_actual, v_cod_usuario, v_nro_secuencia,
            v_cod_transaccion,v_cod_modulo, v_cod_modalidad,
            v_cod_oficina, v_cod_moneda, to_number(p_nro_caja),
            --nvl(v_nro_documento, v_nro_factura), 
            v_nro_documento,   --RI: 01/07/2010: Se graba solo nro. recibo 
            v_mto_cheque ,v_tip_monto , v_tipo); -- es debito
           v_cuo_desde := v_nro_cuota_desde;
           loop
               Begin
                    update pr_cob_cuo_otr_bco a
                       set a.nro_boleta  = v_nro_documento
                     where a.nro_cuenta  = p_nro_cuenta
                       and a.nro_cuota   = v_cuo_desde
                       and a.fec_proceso = v_fec_actual
                       and a.estado      = 'C';
               
                     exit when v_cuo_desde = v_nro_cuota_hasta;
                     v_cuo_desde := v_cuo_desde + 1;
               End;
           End Loop;  
      end if;
      --
      if v_mto_cheque_ntro > 0 then
        -- genero el movimiento por el deposito en cheques (local - otros bcos )
        v_nro_secuencia := v_nro_secuencia + 1;
        insert into cj_movimientos
           (nro_cuenta,fecha, hora, cod_usuario, nro_secuencia,
            cod_tra_padre, cod_mod_padre, cod_mad_padre,
            cod_oficina, cod_moneda, nro_caja,
            nro_documento, monto, tip_monto, tipo)
        values
           (p_nro_cuenta,v_fec_actual, v_hor_actual, v_cod_usuario, v_nro_secuencia,
            v_cod_transaccion, v_cod_modulo, v_cod_modalidad,
            v_cod_oficina, v_cod_moneda, to_number(p_nro_caja),
            --nvl(v_nro_documento,v_nro_factura), 
            v_nro_documento, --RI: 02/07/2010: Se graba solo nro. recibo            
            v_mto_cheque_ntro ,'C' , v_tipo); -- es debito
      end if;
  end lp_gen_transaccion;


---------------- INICIO DEL PROCESO PRINCIPAL ------------------
Begin
 -- Inicializacion de la aplicacion y el modulo
 Begin PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=v_cod_modulo; End;
 -- Valido la moneda
 if p_nro_cuenta is null then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el Nro. de Cuenta.';
 else
    -- obtengo datos de la cuenta  prestamo --
    begin
      Select p.cod_moneda, p.estado, p.cod_modulo, p.cod_modalidad, p.cod_oficina,
             c.cod_persona
        into v_cod_moneda, v_est_cuenta, v_mod_cobro, v_mad_cobro, v_cod_ofi_cta,
             v_cod_persona
        from ge_cta_clientes c, ge_cuentas p
       where p.nro_cuenta = p_nro_cuenta
         and c.nro_cuenta = p_nro_cuenta
         and c.relacion   = 'P';

	  exception--datos prestamo
      when no_data_found then
        v_cod_respuesta := '002';
        v_msj_respuesta := 'ERROR: Nro de Documento no existe!';
      when others then
        v_cod_respuesta := '003';
        v_msj_respuesta := 'ERROR' || sqlerrm;
    end;

    if v_cod_respuesta = '000' then -- sino hubo problemas, veo la caja
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
    --verificar comprobante
    if v_cod_respuesta = '000' then
      If p_nro_comprobante is not null then
        -- Verifico la duplicacion del registro
        prj_val_duplicacion(p_nro_caja,
                            v_cod_transaccion,
                            v_cod_moneda,
                            p_nro_comprobante,
                            v_cod_respuesta,
                            v_msj_respuesta);
      End if;
    end if;
    if v_mod_cobro <> 6  then
      v_cod_respuesta := '003';
      v_msj_respuesta := 'ERROR: Cuenta no es de Préstamo !';
    end if;
    v_cod_modulo    := v_mod_cobro; --modulo y modalidad de la operación y no de la caja xq se retoma
    v_cod_modalidad := v_mad_cobro;
    ----- aqui veo si viene de retomar pendiente o no -----

    prj_ver_pen_caja(p_nro_cuenta,
                     v_cod_transaccion,--359
                     v_fec_actual,
                     v_cod_usuario,
                     v_hora,
                     v_cod_tran_pend,
                     v_cod_respuesta,
                     v_msj_respuesta);
    --cargamos como actual la hora del mov.
    v_hor_actual := v_hora;
    if v_cod_usuario is null then
      --no se retoma, tonces el usuario es el cajero
      v_cod_usuario := upper(user);
    end if;
    if v_cod_respuesta = '000' then  ---- ERROR no esta pend.
       v_cod_respuesta := '008';
       v_msj_respuesta := 'NO existen pendientes para esta Cta.!';
    else--retoma de operaciones
       v_cod_respuesta := '000';
       for reg in c_cobros loop
          if reg.cod_transaccion = 740 then
              v_mto_efectivo := reg.monto;
          elsif reg.cod_transaccion in (607, 610, 632) then
              v_mto_cheque   := reg.monto;
              v_cod_tra_chq_retomada := reg.cod_transaccion;
          elsif reg.cod_transaccion = 606 then
             v_mto_cheque_ntro   := reg.monto;
          end if;
       end loop;
    end if;
    --- Recupero montos a detallar
    v_cod_respuesta := '000';
    if v_cod_tra_chq_retomada is not null Then
        pag_cta.PR_OBT_RETENCION(v_fec_actual,
                                 p_nro_cuenta,
                                 v_mod_cobro, 
                                 v_mad_cobro, 
                                 v_cod_tra_chq_retomada, 
                                 v_cod_moneda,
                                 v_cod_retencion, 
                                 v_fec_fin_retencion);
    End IF;
    prj_obt_dat_pend(p_nro_cuenta,
                    v_nro_cuota_desde,
                    v_nro_cuota_hasta,
                    nvl(v_fec_fin_retencion,v_fec_actual),
                    v_hora,
                    v_tot_capital,
                    v_tot_interes,
                    v_tot_int_adelantado,
                    v_tot_mora,
                    v_tot_mora_interes,
                    v_tot_mora_int_adel,
                    v_tot_impuesto,
                    v_tot_cargo,
                    v_tot_cargo_iva,
                    v_tot_int_descontado,
                    v_tot_iva_descontado,
                    v_tot_seg_descontado,
                    v_tot_punitorio,
                    v_tot_deb_cta,
                    v_tot_deb_cta_con,
                    v_cod_transaccion,
                    v_cod_respuesta,
                    v_msj_respuesta);
    v_tot_cap_int  := nvl(v_tot_capital,0) +
                      nvl(v_tot_interes,0) +
                      nvl(v_tot_int_adelantado,0);
    v_tot_mora_cap := nvl(v_tot_mora,0) +
                      nvl(v_tot_mora_int_adel,0);

    v_tot_a_cobrar:= nvl(v_tot_cap_int,0) +
                   nvl(v_tot_mora_interes,0) +
                   nvl(v_tot_mora_cap,0) +
                   nvl(v_tot_punitorio,0) +
                   nvl(v_tot_impuesto,0) +
                   nvl(v_tot_cargo,0) - nvl(v_tot_iva_descontado,0) ;
    --- Verificar montos a cobrar contra detallado
    if nvl(v_tot_deb_cta,0)+nvl(v_tot_deb_cta_con,0)+nvl(v_mto_efectivo,0)+nvl(v_mto_cheque,0)+nvl(v_mto_cheque_ntro,0)
        <> nvl(v_tot_a_cobrar,0) then
        v_cod_respuesta := '005';
        v_msj_respuesta := 'Monto a cobrar y detallar no coinciden';
    end if;
    if v_cod_respuesta = '000' Then
      --- Inicializo el numero de documento
      -- sólo si no ingresó comprobante manual
      if p_nro_comprobante is not null then
         v_nro_documento := p_nro_comprobante;
         v_emi_aviso := 'N'; --indica comprobante manual en los movimientos
      else
         begin
            if nvl(v_tot_capital,0) + nvl(v_tot_interes,0) + nvl(v_tot_int_adelantado,0) > 0 then
               v_nro_documento := fug_obt_lla_pardinamico('NRO_RECIBO', v_mod_cobro, v_mad_cobro, v_cod_moneda, v_cod_oficina)+1;
               prg_act_par_dinamico('NRO_RECIBO',v_mod_cobro, v_mad_cobro, v_cod_moneda, v_cod_oficina, v_nro_documento);
            end if;
         exception
            when others then
                 if sqlcode <= -20000 then
                    v_cod_respuesta := '004';
                    v_msj_respuesta := 'Error: '||sqlerrm;
                 end if;
         end;
      end if;

      --VC 27-08-2010 la factura se genera en el cierre de mes, si el cliente solicita se debe sacar a requerimiento
      --ya no se genera en los cobros
      --PAB_IVA.PR_GEN_LIB_VTA_TMP(v_cod_persona, v_fec_actual, v_hora,v_cod_usuario);
      --v_nro_factura := PAB_IVA.FU_GEN_FACTURA(v_cod_persona, v_fec_actual, v_hora, v_cod_usuario);
      
      --RI : 01/07/2010: La factura se genera desde el PAB_IVA      
      /*if nvl(v_tot_mora,0) + nvl(v_tot_mora_interes,0) +
         nvl(v_tot_mora_int_adel,0) + nvl(v_tot_punitorio,0) +
         nvl(v_tot_impuesto,0) + nvl(v_tot_cargo,0) > 0 then
         v_nro_factura := fug_obt_lla_pardinamico('NRO_FACTURA', v_mod_cobro, v_mad_cobro, v_cod_moneda, v_cod_oficina)+1;
         prg_act_par_dinamico('NRO_FACTURA',v_mod_cobro, v_mad_cobro, v_cod_moneda, v_cod_oficina, v_nro_factura);
      end if;*/
    end if;
    if v_cod_respuesta = '000' then
      if nvl(v_mto_cheque,0) > 0 then 
         --Asignar Código de Transacción p/ Cheques
        if v_cod_tra_chq_retomada = 607 then --24hs
          v_tip_monto := 'O';
        elsif v_cod_tra_chq_retomada = 610 then --48hs
          v_tip_monto := 'T';
        --elsif v_cod_tra_chq_retomada = 632 and v_cod_moneda <> v_cod_mon_local then --72hs
        --  v_tip_monto := 'X';
        elsif v_cod_tra_chq_retomada = 632 then --72hs
          v_tip_monto := 'S'; 
        end if;
         --
       end if;       
       -- verifico los decimales del importe en cheques
       if v_mto_cheque is not null then
         v_msj_respuesta := fuj_val_importe(v_tipo, v_tip_monto,v_cod_moneda,v_mto_cheque, null, p_nro_cuenta);
       end if;
       if v_mto_cheque_ntro is not null then
         v_msj_respuesta := fuj_val_importe(v_tipo, 'C',v_cod_moneda,v_mto_cheque_ntro, null, p_nro_cuenta);
       end if;
       if v_msj_respuesta is null then -- valido el efectivo
          if v_mto_efectivo is not null then
            v_msj_respuesta := fuj_val_importe(v_tipo, 'E',v_cod_moneda,v_mto_efectivo);
          end if;
       end if;
       if v_msj_respuesta is not null then
          v_cod_respuesta := '005';  -- error
       else
          -- Actualizo en ge_mov , la caja y estado
          begin
             update ge_movimientos
				     set  estado            = 'N',
                  nro_caja          = to_number(p_nro_caja),
                  cod_mod_padre     = v_cod_modulo,
                  cod_mad_padre     = v_cod_modalidad,
                  cod_oficina       = v_cod_ofi_cta,
                  nro_documento     = v_nro_documento,
                  --nro_documento2    = v_nro_factura, --RI
                  referencia        = v_nro_factura,
                  emi_aviso         = v_emi_aviso
             where cod_tra_padre = v_cod_transaccion
             and fecha           = v_fec_actual
             and hora            = v_hora --la hora del mov.
             and cod_usuario     = v_cod_usuario
             and reversado       = 'N'
             and estado          = 'J';
          exception
             when no_data_found then
                v_cod_respuesta := '002';
                v_msj_respuesta := 'No encontro ge_movimientos pendientes :'||sqlerrm;
             when others then
                v_cod_respuesta := '999';
                v_msj_respuesta := 'ERROR AL ACT.GE_MOVIMIENTOS PENDIENTES:'||SQLERRM;
          end;
          begin
           --  AP 922 - Act. ofi_origen. Caso: Cobro registrado en ofi. <> a ofi. de la caja donde se liquida la operacion.                  
           update ge_movimientos
              set cod_ofi_origen  = v_cod_oficina
            where fecha           = v_fec_actual
              and hora            = v_hora
              and cod_usuario     = v_cod_usuario
              and reversado       = 'N'
              and cod_ofi_origen  <> v_cod_oficina;
          exception
            when others then
             v_cod_respuesta := '999';
             v_msj_respuesta := 'Error al Act. mov.pendientes - Ofi.Origen :'||SQLERRM;
          end;       
          v_cod_retencion     := null;
          v_fec_fin_retencion := null;
          if v_mto_cheque > 0 then
             pag_cta.PR_OBT_RETENCION(v_fec_actual,p_nro_cuenta,
                     v_mod_cobro, v_mad_cobro, v_cod_tra_chq_retomada , v_cod_moneda,
                     v_cod_retencion, v_fec_fin_retencion);
            begin
              update ge_movimientos t
    				     set  cod_retencion     = v_cod_retencion,
                      fec_fin_retencion = v_fec_fin_retencion
                 where cod_tra_padre = v_cod_transaccion
                 and fecha           = v_fec_actual
                 and hora            = v_hora --la hora del mov.
                 and cod_usuario     = v_cod_usuario
                 and reversado       = 'N'
                 --and estado          = 'J'
                 and estado          = 'N' --Debe ser "N" porque ya se actualizo más arriba, Fec.: 02/08/2010
                 and t.cod_transaccion = v_cod_tra_chq_retomada;--607
            exception
              when no_data_found then
                v_cod_respuesta := '002';
                v_msj_respuesta := 'No encontro ge_movimientos pendientes :'||sqlerrm;
              when others then
                v_cod_respuesta := '999';
                v_msj_respuesta := 'ERROR AL ACT.GE_MOVIMIENTOS PENDIENTES:'||SQLERRM;
            end;
          end if;

          v_cod_retencion     := null;
          v_fec_fin_retencion := null;
          if v_mto_cheque_ntro > 0 then
             pag_cta.PR_OBT_RETENCION(v_fec_actual,p_nro_cuenta,
                     v_mod_cobro, v_mad_cobro, 606, v_cod_moneda,
                     v_cod_retencion, v_fec_fin_retencion);
             begin
              update ge_movimientos t
    				     set  cod_retencion     = v_cod_retencion,
                      fec_fin_retencion = v_fec_fin_retencion
                 where cod_tra_padre = v_cod_transaccion
                 and fecha           = v_fec_actual
                 and hora            = v_hora --la hora del mov.
                 and cod_usuario     = v_cod_usuario
                 and reversado       = 'N'
                 and estado          = 'J'
                 and t.cod_transaccion = 606;
            exception
              when no_data_found then
                v_cod_respuesta := '002';
                v_msj_respuesta := 'No encontro ge_movimientos pendientes :'||sqlerrm;
              when others then
                v_cod_respuesta := '999';
                v_msj_respuesta := 'ERROR AL ACT.GE_MOVIMIENTOS PENDIENTES:'||SQLERRM;
            end;
          end if;

          if pag_cta.g_cod_error <> 0 then
             -- actualizacion con problemas
             v_cod_respuesta := ltrim(to_char(pag_cta.g_cod_error,'000'));
             v_msj_respuesta := pag_cta.g_msj_error;
          else -- genero la transaccion en caja
             lp_gen_transaccion();--
              --actualizar los movimientos para no emitir comprobante
              --sólo si el comprobante es manual
              if p_nro_comprobante is not null then
                 begin
                    update ge_movimientos
                    set emi_aviso         = v_emi_aviso
                    where cod_tra_padre   = v_cod_transaccion
                      and fecha           = v_fec_actual
                      and hora            = v_hora
                      and cod_usuario     = v_cod_usuario
                      and reversado       = 'N';
                 exception
                    when no_data_found then
                     v_cod_respuesta := '022';
                     v_msj_respuesta := 'No encontro ge_movimientos:'||sqlerrm;
                    when others then
                     v_cod_respuesta := '999';
                     v_msj_respuesta := 'Error al Act. movim.:'||SQLERRM;
                 end;          
              end if;
          end if;
       end if;
    end if;
 end if;
 -- mensaje final sino hubo errores
 if v_cod_respuesta = '000' then -- sino hubo problemas, se carga mensaje por defecto
    if nvl(v_mto_cheque,0) = 0 then
       if p_nro_comprobante is not null then
         v_msj_respuesta := 'Operacion Confirmada. No se imprimirá el Comprobante Manual';
       else
         v_msj_respuesta := 'Operacion confirmada';
       end if;
    else
       v_msj_respuesta := 'Operacion confirmada - Boleta a desglosar: '||v_nro_documento;
    end if;
 end if;

 if v_cod_respuesta = '000' then -- sino hubo problemas, se carga mensaje por defecto
    --IMPRESION DEL COMPROBANTE DE PAGO,si no hay cheque y el comp. no es manual
    if nvl(v_mto_cheque,0) = 0 and p_nro_comprobante is null then
       v_cod_respuesta := 'IMP'; -- para indicar que esta ok y se puede imprimir
       v_msj_respuesta := 'Operacion Confirmada. Comprobante de Pago ha sido impreso.'||'~'||
       fuj_imp_transaccion_360(v_cod_oficina, -- oficina
                               v_nro_documento, -- P.V. nvl(v_nro_documento,v_nro_factura),
                               v_nro_factura,
                               p_nro_caja, -- Caja
                               v_cod_moneda, -- Moneda
                               p_nro_cuenta, -- cuenta
                               v_fec_actual,
                               v_hora); -- hora
    else
       if p_nro_comprobante is null then
          if v_cod_tra_chq_retomada = 607 then --24hs
             v_msj_respuesta := 'Operacion confirmada - '||nvl(v_nro_documento, v_nro_factura);
          else
             v_msj_respuesta := 'Operacion confirmada - Boleta a desglosar: '||nvl(v_nro_documento, v_nro_factura);
          end if;
       end if;
    end if;
 end if;

 /* falta armar el mensaje de respuesta */
 v_msj_salida := p_nro_operacion||'~'||
                 v_cod_respuesta||'~'||
                 nvl(v_msj_respuesta,'Operacion confirmada');
 return(v_msj_salida);
end;
end FUJ_PRO_TRANSACCION_362;
/

