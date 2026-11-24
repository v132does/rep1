CREATE OR REPLACE FUNCTION IT.FUJ_PRO_TRANSACCION_361
 (P_NRO_OPERACION IN VARCHAR2
 ,P_NRO_CAJA IN VARCHAR2
 ,P_NRO_COMPROBANTE IN NUMBER default null --nro de comprobante manual
 ,P_NRO_DOCUMENTO IN VARCHAR2
 ,P_NRO_CUENTA IN VARCHAR2
 ,P_NRO_CUOTA_DESDE IN NUMBER default null
 ,P_NRO_CUOTA_HASTA IN NUMBER default null
 ,P_IMP_CHE_24 in number default null
 ,P_IMP_CHE_48 in number default null
 ,P_IMP_CHE_72 in number default null
 )
 RETURN  VARCHAR2
 IS
  -- defino por defecto el modulo y modalidad a utilizar
  v_cod_modulo      number(3)      := 9;    -- Caja
  v_cod_modalidad   number(3)      := 91;   -- Caja
  v_cod_transaccion number(4)      := 361;  -- transaccion
  v_cod_tra_padre   number(4)      := 360;  -- Transaccion Padre
  v_cod_usuario     varchar2(10);--   := upper(user); --usuario
  v_cod_persona     ba_personas.cod_persona%type;

  -- Datos de la caja
  v_cod_mon_local     varchar2(4) := pag_gen.fu_obt_mon_local;
  v_fec_actual        date         := pag_cal.fu_obt_fec_actual(v_cod_modulo); -- fecha de hoy
  v_hor_actual        varchar2(08) := to_char(sysdate,'HH24:MI:SS');--nvl(p_hora,to_char(sysdate,'HH24:MI:SS'));   -- Hora actual
  v_cod_oficina       number(3);         -- Codigo de oficina
  v_cod_ofi_cta       number(3);
  v_estado            number(1);         -- estado de la caja
  v_fec_caja          date;              -- fecha de la caja
  v_sal_actual        number(18,2);      -- saldo actual de la caja en efectivo
  v_sal_cheques       number(18,2);      -- saldo actual de la caja en cheques
  v_dia_mora          pr_cta_prestamos.dia_atraso%type;
  -- Datos de la cuenta
  v_nro_cuenta        varchar2(20);      -- numero de cuenta
  v_cod_moneda        varchar2(3);       -- moneda de la cuenta
  v_est_cuenta        varchar2(1);       -- estado de la cuenta
  v_ope_retomada      varchar2(1) := 'N';

  -- Datos de salida
  v_msj_salida    varchar2(8000);                          -- mensaje final retornado
  v_cod_respuesta varchar2(03) := '000';                   -- sin errores
  v_msj_respuesta varchar2(8000) := 'Operacion Confirmada'; -- sin errores

  -- datos de la operacion convertidos
  v_tipo          varchar2(01) := 'D' ;     -- 'C' credito para la caja (egreso) o vice versa
  v_tip_monto     varchar2(01) := 'O';       -- E efectivo / O cheque otros Bcos
  v_nro_secuencia number(3) := 0;           -- secuencia del mov.

  -- datos que se cargan en la pantalla
--  v_mto_cobrado   number(18,2) := nvl(to_number(p_chq_obco),0);
  v_mto_chq_obco  number(18,2) := null;
  v_mto_chq_nbco  number(18,2) := 0;--nvl(to_number(p_chq_nbco),0);
  v_mto_efectivo  number(18,2) := 0;--nvl(to_number(p_efectivo),0);

  v_mon_local     varchar2(3) := pag_gen.fu_obt_mon_local; -- moneda local
  v_nro_documento cj_movimientos.nro_documento%type;
  --v_nro_factura   cj_movimientos.nro_documento%type;
  v_nro_factura   cb_lib_ventas.nro_factura%type;  --RI: 01/07/2010

  r_gmovi         ge_movimientos%rowtype;
  v_mod_cobro     number(3) := 6 ; ---- modulo del préstamo
  v_mad_cobro     number(3);       ---- modalidad del préstamo

  --- para operaciones pendientes
  v_hora                varchar2(8) :=null;  --- para recuperar hora de oper.pendiente
  v_cod_tran_pend       number(4);     --- transaccion efectivo o cheque
  v_nro_cuota_desde     number(3);
  v_nro_cuota_hasta     number(3);
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
  v_tot_cre_cta         number(18,2);
  v_tot_cre_cta_con     number(18,2);
  v_existe              varchar2(1);
  --emisión de comprobante automático
  v_emi_aviso ge_movimientos.emi_aviso%type := 'S';

  v_monto_efectivo number(18,2) :=0; --- importe pagado operacion pendiente efectivo
  v_monto_cheque   number(18,2) :=0; --- importe pagado operacion pendiente cheque
  v_monto_cheque_n number(18,2) :=0; --- importe pagado operacion pendiente cheque

  --para la retención de cheques
  v_cod_tra_cheque       ge_movimientos.cod_transaccion%type;
  v_cod_tra_chq_retomada ge_movimientos.cod_transaccion%type;
--  v_tip_mto_chq          cj_movimientos.tip_monto%type;

  -- C.D Fase III -- 
  v_tot_monto       ge_movimientos.monto%type;
  v_tip_operacion   ge_mov_autorizaciones.tip_operacion%type := 'O';-- Todos Tipos Operacional
  v_est_movimiento  ge_movimientos.estado%type;
  v_nro_pedido      ge_mov_autorizaciones.nro_pedido%type;
  v_est_estado      ge_movimientos.estado%type;
  v_aux             ge_movimientos.estado%type;

  --CRO-HO-CROCPCCB-11/08/15 Variables que se utilizaran para almacenar datos de la retención y en base a eso calcular el monto a cobrar
  v_cod_retencion       ge_movimientos.cod_retencion%type;
  v_fec_fin_retencion   ge_movimientos.fec_fin_retencion%type;
  v_cuo_desde           number(3);

  cursor c_cobros is select cod_transaccion, monto from
     ge_movimientos where
      cod_tra_padre = v_cod_tra_padre  and
      fecha         = v_fec_actual  and
      estado        = 'J'  and
      hora          = v_hora;

  -- Procedimiento interno para generar movimiento y act. de control de caja
  procedure lp_gen_transaccion (p_estado varchar2) is
  begin
      if p_estado <> 'P' then
      -- Actualizo el control de caja
       update cj_controles
         set tot_che_otr_bco = nvl(tot_che_otr_bco,0) + nvl(v_mto_chq_obco,0),
             sal_che_otr_bco = nvl(sal_che_otr_bco,0) + nvl(v_mto_chq_obco,0),
             tot_che_nue_bco = nvl(tot_che_nue_bco,0) + nvl(v_mto_chq_nbco,0),
             sal_actual = nvl(sal_actual,0) + nvl(v_mto_efectivo,0),
             tot_debitos = nvl(tot_debitos,0) + nvl(v_mto_efectivo,0),
             can_debitos = nvl(can_debitos,0) + decode(v_mto_efectivo,0,0,1),
             estado = 1 -- abierto
       where nro_caja = to_number(p_nro_caja)
         and cod_moneda = v_cod_moneda
         and fecha = v_fec_caja;
      end if;
       v_nro_secuencia := 0;

       --si retoma operacion tiene q pasarle modulo y modalidad de la operacion
       --solo si retoma el usuario es el del mov. sino es el user
      -- genero el movimiento por el pago de la cuota (cheque y/o efectivo)
      if v_mto_efectivo > 0 then
        -- genero el movimiento por el efectivo
        v_nro_secuencia := v_nro_secuencia + 1;
        insert into cj_movimientos
           (nro_cuenta,fecha, hora, cod_usuario, nro_secuencia,
            cod_tra_padre,
            cod_mod_padre,
            cod_mad_padre,
            cod_oficina, cod_moneda, nro_caja,
            nro_documento, monto, tip_monto, tipo,estado )-- C.D Fase III
        values
           (p_nro_cuenta, v_fec_actual, v_hor_actual, v_cod_usuario, v_nro_secuencia,
            v_cod_transaccion,
            decode(nvl(v_hora,'X'),'X', v_cod_modulo, v_mod_cobro), --ve si retoma
            decode(nvl(v_hora,'X'),'X', v_cod_modalidad, v_mad_cobro),--ve si retoma
            v_cod_oficina, v_cod_moneda, to_number(p_nro_caja),
            --nvl(v_nro_documento, v_nro_factura), 
            v_nro_documento, --RI: 01/07/2010: Se graba solo nro. recibo
            v_mto_efectivo,'E', v_tipo,p_estado);  -- es debito
      end if;
      if v_mto_chq_obco > 0 then
        v_nro_secuencia := v_nro_secuencia + 1;
        insert into cj_movimientos
           (nro_cuenta, fecha, hora, cod_usuario, nro_secuencia,
            cod_tra_padre,
            cod_mod_padre,
            cod_mad_padre,
            cod_oficina, cod_moneda, nro_caja,
            nro_documento, monto, tip_monto, tipo, estado)
        values
           (p_nro_cuenta, v_fec_actual, v_hor_actual, v_cod_usuario, v_nro_secuencia,
            v_cod_transaccion,
            decode(nvl(v_hora,'X'),'X', v_cod_modulo, v_mod_cobro), --ve si retoma
            decode(nvl(v_hora,'X'),'X', v_cod_modalidad, v_mad_cobro),--ve si retoma
            v_cod_oficina, v_cod_moneda, to_number(p_nro_caja),
            --nvl(v_nro_documento, v_nro_factura), 
            v_nro_documento, --RI: 01/07/2010: Se graba solo nro. recibo
            v_mto_chq_obco ,v_tip_monto , v_tipo, p_estado); -- es debito
      end if;
      if v_mto_chq_nbco > 0 then
        -- genero el movimiento por el deposito en cheques (local - ntro bco )
        v_nro_secuencia := v_nro_secuencia + 1;
        insert into cj_movimientos
           (nro_cuenta, fecha, hora, cod_usuario, nro_secuencia,
            cod_tra_padre,
            cod_mod_padre,
            cod_mad_padre,
            cod_oficina, cod_moneda, nro_caja,
            nro_documento, monto, tip_monto, tipo, estado)
        values
           (p_nro_cuenta, v_fec_actual, v_hor_actual, v_cod_usuario, v_nro_secuencia,
            v_cod_transaccion,
            decode(nvl(v_hora,'X'),'X', v_cod_modulo, v_mod_cobro), --ve si retoma
            decode(nvl(v_hora,'X'),'X', v_cod_modalidad, v_mad_cobro),--ve si retoma
            v_cod_oficina, v_cod_moneda, to_number(p_nro_caja),
            --nvl(v_nro_documento, v_nro_factura), 
            v_nro_documento, --RI: 01/07/2010: Se graba solo nro. recibo
            v_mto_chq_nbco ,'C' , v_tipo, p_estado); -- es debito
       end if;
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
  
---------------- INICIO DEL PROCESO PRINCIPAL ------------------
Begin
 -- Inicializacion de la aplicacion y el modulo
 Begin PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=v_cod_modulo; End;
 if ( nvl(p_imp_che_24,0) <> 0 and  nvl(p_imp_che_48,0) <> 0 ) or 
     ( nvl(p_imp_che_24,0) <> 0 and  nvl(p_imp_che_72,0) <> 0 ) or
       ( nvl(p_imp_che_48,0) <> 0 and  nvl(p_imp_che_24,0) <> 0 ) or
        ( nvl(p_imp_che_48,0) <> 0 and  nvl(p_imp_che_72,0) <> 0 ) then
          v_cod_respuesta := '012'; 
          v_msj_respuesta := 'ERROR: Ingrese un sólo campo de retención.';
 end if;
 -- Valido que se ingrese uno de los campos de retencion
 if nvl(p_imp_che_24,0) + nvl(p_imp_che_48,0) + nvl(p_imp_che_72,0) = 0 then
    v_cod_respuesta := '011'; -- error
    v_msj_respuesta := 'ERROR: Ingrese un valor en uno de los campos de retención.';
 end if;
 if p_nro_cuenta is null then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el Nro. de Cuenta.';
 else
    ----- aqui veo si viene de retomar pendiente o no -----
    if v_cod_respuesta = '000' then
       prj_ver_pen_caja(p_nro_cuenta,
                        v_cod_tra_padre,
                        v_fec_actual,
                        v_cod_usuario,
                        v_hora,
                        v_cod_tran_pend,
                        v_cod_respuesta,
                        v_msj_respuesta);
    end if;
    if v_cod_respuesta <> '001' then  ---- debe retomar hay pendientes 'J'
      /*if v_mto_cobrado is null or v_mto_cobrado <= 0 then
         v_cod_respuesta := '003'; -- error
         v_msj_respuesta := 'ERROR: Ingrese el importe Pagado.';
      els*/
      if p_nro_cuota_desde is null or p_nro_cuota_hasta is null then
         v_cod_respuesta := '004'; -- error
         v_msj_respuesta := 'ERROR: Ingrese cuota a pagar.';
      elsif p_nro_cuota_desde > p_nro_cuota_hasta then
         v_cod_respuesta := '004'; -- error
         v_msj_respuesta := 'ERROR: Cuota desde debe ser menor al hasta.';
      end if;
    else
       v_ope_retomada  := 'S';
       v_cod_respuesta := '000';
    end if;
    if v_cod_respuesta = '000' then -- sino hubo problemas, veo la caja
       BEGIN
        Select p.cod_moneda, p.estado, p.cod_modulo, p.cod_modalidad, p.cod_oficina,
               c.cod_persona
          into v_cod_moneda, v_est_cuenta, v_mod_cobro, v_mad_cobro, v_cod_ofi_cta,
               v_cod_persona
          from ge_cta_clientes c, ge_cuentas p
         where p.nro_cuenta = p_nro_cuenta
           and c.nro_cuenta = p_nro_cuenta
           and c.relacion   = 'P';
        if v_mod_cobro <> 6  then
          v_cod_respuesta := '003';
          v_msj_respuesta := 'ERROR: Cuenta no es de Préstamo';
        end if;
       exception--select pr_cta_prestamo
            when no_data_found then
              v_cod_respuesta := '002';
              v_msj_respuesta := 'ERROR: Nro de Documento no existe!';
            when others then
              v_cod_respuesta := '003';
              v_msj_respuesta := 'ERROR' || sqlerrm;
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
            v_msj_respuesta := 'Realice la Apertura de Caja previamente';
         elsif v_fec_caja <> v_fec_actual then
            v_cod_respuesta := '005'; -- error
            v_msj_respuesta := 'Caja no fue habilitada el dia de hoy';
         end if;
       end if;
    end if;
    ----- aqui veo si viene de retomar pendiente o no -----
    if v_cod_respuesta = '000' then
       prj_ver_pen_caja(p_nro_cuenta,
                        v_cod_tra_padre,
                        v_fec_actual,
                        v_cod_usuario,
                        v_hora,
                        v_cod_tran_pend,
                        v_cod_respuesta,
                        v_msj_respuesta);
    end if;
    if v_cod_respuesta = '001' then  ---- debe retomar hay pendientes 'J'
       v_cod_respuesta := '000';
       
       --CRO-HO-CROCPCCB-11/08/15 se agrega un control de tipos de retencion y se obtiene la fecha final de retencion
       
       if nvl(p_imp_che_24,0) > 0 then 
        v_cod_tra_cheque := 607;
       elsif nvl(p_imp_che_48,0) > 0 then
        v_cod_tra_cheque := 610;
       elsif nvl(p_imp_che_72,0) > 0 then
        v_cod_tra_cheque := 632;
       end if;
       
       pag_cta.PR_OBT_RETENCION(v_fec_actual         ,
                                p_nro_cuenta         ,
                                6        						 , 
                                v_mad_cobro          , 
                                v_cod_tra_cheque     , 
                                v_cod_moneda         ,
                                v_cod_retencion      , 
                                v_fec_fin_retencion	);
       
       v_nro_cuota_desde := p_nro_cuota_Desde;
       v_nro_cuota_hasta := p_nro_cuota_hasta;

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
                        v_tot_cre_cta,
                        v_tot_cre_cta_con,
                        v_cod_tra_padre,
                        v_cod_respuesta,
                        v_msj_respuesta);

        v_tot_cap_int  := nvl(v_tot_capital,0) +
                          nvl(v_tot_interes,0)+
                          nvl(v_tot_int_adelantado,0);

        v_tot_mora_cap := nvl(v_tot_mora,0) + nvl(v_tot_mora_int_adel,0);

        v_tot_a_cobrar:= nvl(v_tot_cap_int,0) +
                       nvl(v_tot_mora_interes,0) +
                       nvl(v_tot_mora_cap,0) +
                       nvl(v_tot_punitorio,0) +
                       nvl(v_tot_impuesto,0) +
                       nvl(v_tot_cargo,0) ;
        
        -- busca las operaciones pendientes para actualizar
        for reg in c_cobros loop
            if reg.cod_transaccion = 740 then
                v_monto_efectivo := reg.monto;
            elsif reg.cod_transaccion in (607, 610, 632) then
                v_monto_cheque   := reg.monto;
                v_cod_tra_chq_retomada := reg.cod_transaccion;
            elsif reg.cod_transaccion = 606 then
                v_monto_cheque_n   := reg.monto;
            end if;
        end loop;
        if v_ope_retomada = 'N' then
          null;
        else
           v_mto_efectivo := v_monto_efectivo;
           v_mto_chq_nbco := v_monto_cheque_n;
           v_mto_chq_obco := v_monto_cheque;
        end if;
     else  ---- transaccion 360 normal
        --el usuario es el user
        v_cod_usuario   := upper(user);
        declare
           x_nro_cuota_desde number(7);
           x_nro_cuota_hasta number(7);
           x_cod_modalidad   number(4);
        Begin --- Busco la minima cuota a pagar
          select cod_modalidad
            into x_cod_modalidad
            from pr_cta_prestamos
           where nro_cuenta = p_nro_cuenta;
          if fup_obt_tip_descuento(x_cod_modalidad) in ('F','C','D') then
            Select min(c.nro_cuota), max(c.nro_cuota)
            into x_nro_cuota_desde, x_nro_cuota_hasta
            from pr_cuotas c
            where c.nro_cuenta = p_nro_cuenta
            and c.estado     <> 'N';
            if p_nro_cuota_desde < x_nro_cuota_desde then
               v_cod_respuesta := '009'; -- error, no existe cuota a pagar
               v_msj_respuesta := 'Cuota desde no corresponde';
            elsif p_nro_cuota_desde > x_nro_cuota_hasta then
               v_cod_respuesta := '009'; -- error, no existe cuota a pagar
               v_msj_respuesta := 'Cuotas hasta no corresponde';
            end if;
          else
            Select c.nro_cuota
            into v_nro_cuota_desde
            from pr_cuotas c
            where c.nro_cuenta = p_nro_cuenta
            and c.estado     <> 'N'
            and c.nro_cuota between p_nro_cuota_desde and p_nro_cuota_hasta
            and c.nro_cuota  = ( select min(c1.nro_cuota)
                                 from pr_cuotas c1
                                 where c1.nro_cuenta = p_nro_cuenta
                                 and c1.nro_cuota <> 0
                                 and c1.estado <> 'N') ;
          end if;
        Exception
            when no_data_found then
               v_cod_respuesta := '009'; -- error, no existe cuota a pagar
               v_msj_respuesta := 'No encuentra cuota minima a pagar';
            when others then
               v_cod_respuesta := '010'; -- error, no existe cuota a pagar
               v_msj_respuesta := 'Error al buscar cuota minima';
        End;
        
        --CRO-HO-CROCPCCB-11/08/15 se agrega un control de tipos de retencion y se obtiene la fecha final de retencion
          if nvl(p_imp_che_24,0) > 0 then 
            v_cod_tra_cheque := 607;
          elsif nvl(p_imp_che_48,0) > 0 then
            v_cod_tra_cheque := 610;
          elsif nvl(p_imp_che_72,0) > 0 then
            v_cod_tra_cheque := 632;
          end if;
        pag_cta.PR_OBT_RETENCION(v_fec_actual         ,
                                 p_nro_cuenta         ,
                                 6        						, 
                                 v_mad_cobro          , 
                                 v_cod_tra_cheque     , 
                                 v_cod_moneda         ,
                                 v_cod_retencion      , 
                                 v_fec_fin_retencion	);
        
        if v_cod_respuesta = '000' then -- sino hubo ERROR se arma los datos de la cuenta
          pap_pre.PR_INI_AUTORIZACION;
          pap_pre.PR_OBT_DEU_PRESTAMO(p_nro_cuenta,
                                 v_fec_actual,--CRO-HO-CROCPCCB-11/08/15 se cambia v_fec_actual por v_fec_fin_retencion
                                 p_nro_cuota_desde,
                                 p_nro_cuota_hasta,
                                 v_cod_oficina,
                                 null, --debe calcular toda la deuda por las cuotas
                                 v_cod_respuesta,
                                 v_msj_respuesta,
                                 v_tot_capital,
                                 v_tot_interes,
                                 v_tot_int_adelantado,
                                 v_tot_mora,
                                 v_tot_mora_interes,
                                 v_tot_mora_int_adel,
                                 v_tot_punitorio,
                                 v_tot_impuesto,
                                 v_tot_cargo,
                                 v_tot_cargo_iva,
                                 v_tot_int_descontado,
                                 v_dia_mora,
                                 360,  --- cod_tra_padre
                                 'N'); --- cancela
          
          if to_number(v_cod_respuesta) = 0 then
             v_cod_respuesta :='000';
          elsif to_number(v_cod_respuesta) = 25 then
             v_cod_respuesta :='025';
          end if;
          v_tot_a_cobrar:= nvl(v_tot_capital,0) +
                           nvl(v_tot_interes,0) +
                           nvl(v_tot_int_adelantado,0) +
                           nvl(v_tot_mora,0) +
                           nvl(v_tot_mora_interes,0) +
                           nvl(v_tot_mora_int_adel,0) +
                           nvl(v_tot_punitorio,0) +
                           nvl(v_tot_impuesto,0) +
                           nvl(v_tot_cargo,0);
          
          v_mto_chq_obco := v_tot_a_cobrar; --el total es con cheque otros bancos
          
        
           /** C.D.Fase III**/
             PAG_RIE.PR_OPE_RIESGO( v_fec_actual,
                                    v_hor_actual,
                                    v_cod_usuario,
                                    v_cod_transaccion, -- transacción padre 
                                    v_cod_modulo,      -- Módulo
                                    v_cod_modalidad,   -- Modalidad
                                    p_nro_cuenta,      -- Nro_cuenta
                                    v_cod_persona,     -- Persona
                                    v_tip_operacion,   -- Tip_operacion 
                                    v_mto_chq_obco,       -- Monto
                                    null,              -- Número de Documento
                                    v_cod_moneda,      -- Moneda
                                    null,              -- Cotización                       
                                    v_nro_pedido);
                             
                             
             if v_nro_pedido > 0 then
                v_est_movimiento := 'P';
              else
                v_est_movimiento := 'N';
             end if;
          
        end if; -- fin sino hubo error para sacar datos de cobros

        if v_cod_respuesta = '000' then
           -- Verifico la duplicacion del registro de la cuota
           prj_val_duplicacion(p_nro_caja,
                            v_cod_transaccion,
                            v_cod_moneda,
                            v_nro_documento,
                            v_cod_respuesta,
                            v_msj_respuesta);
        end if;
    end if;--transaccion
    
    if v_cod_respuesta = '000' Then
      --- Inicializo el numero de documento
      -- sólo si no ingresó comprobante manual
      if p_nro_comprobante is not null then
         v_nro_documento := p_nro_comprobante;
         v_emi_aviso := 'N'; --indica comprobante manual en los movimientos
      else
         begin
          --OJO CONFIRMAR!!! los montos contra los q controla
            if nvl(v_tot_capital,0) + nvl(v_tot_interes,0) + nvl(v_tot_int_adelantado,0) +
               nvl(v_tot_mora,0) + nvl(v_tot_mora_interes,0) + nvl(v_tot_mora_int_adel,0) +
               nvl(v_tot_punitorio,0) + nvl(v_tot_impuesto,0) + nvl(v_tot_cargo,0)> 0 then
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
      if v_cod_respuesta = '000' and v_ope_retomada = 'N' then --CRO-HO-CROCPCCB-10/08/15 si la respuesta es 0, se carga en la tabla PR_COB_CUO_OTR_BCO
        v_cuo_desde := P_NRO_CUOTA_DESDE;
        loop
          Begin
              insert into PR_COB_CUO_OTR_BCO
                           (nro_cuenta,
                             nro_cuota,
                             fec_cobro,
                             fec_proceso,
                             estado,
                             nro_boleta,
                             nro_cheque)
                    values
                           (p_nro_cuenta,
                            v_cuo_desde,
                            v_fec_fin_retencion,
                            v_fec_actual,
                            'C',
                            v_nro_documento,
                            null);
           End;
         exit when v_cuo_desde = p_nro_cuota_hasta;
         v_cuo_desde := v_cuo_desde + 1;
        End Loop;
      ElsIf v_cod_respuesta = '000' and v_ope_retomada = 'S' then
           v_cuo_desde := v_nro_cuota_desde;
           loop
               Begin
                    update pr_cob_cuo_otr_bco a
                       set a.nro_boleta  = v_nro_documento,
                           a.nro_cheque  = null
                     where a.nro_cuenta  = p_nro_cuenta
                       and a.nro_cuota   = v_cuo_desde
                       and a.fec_proceso = v_fec_actual
                       and a.estado      = 'C';
               
                     exit when v_cuo_desde = v_nro_cuota_hasta;
                     v_cuo_desde := v_cuo_desde + 1;
               End;
           End Loop;
      end if;
      --RI : 01/07/2010: La factura se genera desde el PAB_IVA
      /*if nvl(v_tot_mora,0) + nvl(v_tot_mora_interes,0) +
         nvl(v_tot_mora_int_adel,0) + nvl(v_tot_punitorio,0) +
         nvl(v_tot_impuesto,0) + nvl(v_tot_cargo,0) > 0 then
         v_nro_factura := fug_obt_lla_pardinamico('NRO_FACTURA', v_mod_cobro, v_mad_cobro, v_cod_moneda, v_cod_oficina)+1;
         prg_act_par_dinamico('NRO_FACTURA',v_mod_cobro, v_mad_cobro, v_cod_moneda, v_cod_oficina, v_nro_factura);
      end if;*/
       /*RI: 01/07/2010 :
       Invocar a la generacion de factura y libro de ventas por los ivas cobrados sobre interes,punitorio,moratorio,
       y cargos. Si se cobra iva de interes vencido de mes anterior se debe generar un recibo referenciando 
       a la factura crédito generada en el cierre de fin de mes.
      */       

      --VC 27-08-2010 la factura se genera en el cierre de mes, si el cliente solicita se debe sacar a requerimiento
      --ya no se genera en los cobros
      /*Begin
         PAB_IVA.PR_GEN_LIB_VTA_TMP(v_cod_persona, v_fec_actual, v_hor_Actual,v_cod_usuario);
         v_nro_factura := PAB_IVA.FU_GEN_FACTURA(v_cod_persona, v_Fec_actual, v_hor_actual,v_cod_usuario);
      exception
          when others then
               if sqlcode <= -20000 then
                  v_cod_respuesta := '004';
                  v_msj_respuesta := 'Error: '||sqlerrm;
               end if;
      end;*/      
    end if;

    if v_cod_respuesta = '000' then
      if nvl(v_tot_a_cobrar,0) > 0 and v_ope_retomada = 'N' then --siempre el total será en cheque porque esta opción de caja es sólo para cheque
        
         --Asignar Código de Transacción p/ Cheques
         if nvl(p_imp_che_24,0) > 0 then 
          v_cod_tra_cheque := 607;
         elsif nvl(p_imp_che_48,0) > 0 then
          v_cod_tra_cheque := 610;
         elsif nvl(p_imp_che_72,0) > 0 then
          v_cod_tra_cheque := 632;
         end if;
         if nvl(v_cod_tra_cheque,v_cod_tra_chq_retomada) = 607 then --24hs
           v_tip_monto := 'O';
         elsif nvl(v_cod_tra_cheque,v_cod_tra_chq_retomada) = 610 then --48hs
           v_tip_monto := 'T';
         elsif nvl(v_cod_tra_cheque,v_cod_tra_chq_retomada) = 632 then --72hs
           v_tip_monto := 'S';
         --elsif nvl(v_cod_tra_cheque,v_cod_tra_chq_retomada) = 632 and v_cod_moneda <> v_cod_mon_local then --72hs
         --  v_tip_monto := 'X';
         end if;
         --
       Elsif nvl(v_tot_a_cobrar,0) > 0 and v_ope_retomada = 'S' then --CRO-HO-CROCPCCB cuando se retoma una operacion de IT en caja se asigna el valor al campo
         
         if nvl(v_cod_tra_cheque,v_cod_tra_chq_retomada) = 607 then --24hs
           v_tip_monto := 'O';
         elsif nvl(v_cod_tra_cheque,v_cod_tra_chq_retomada) = 610 then --48hs
           v_tip_monto := 'T';
         elsif nvl(v_cod_tra_cheque,v_cod_tra_chq_retomada) = 632 then --72hs
           v_tip_monto := 'S';
         end if;
       
       end if; 
       -- verifico los decimales del importe en cheques
       v_msj_respuesta := fuj_val_importe(v_tipo, v_tip_monto,v_cod_moneda,v_mto_chq_obco);
       if v_msj_respuesta is null then -- valido el efectivo
          v_msj_respuesta := fuj_val_importe(v_tipo, 'E',v_cod_moneda,v_mto_efectivo);
       end if;
       if v_msj_respuesta is not null then
          v_cod_respuesta := '007';  -- error
       else
          -- Asigno el nro de caja a los movimientos
          pag_cta.pr_nro_caja(to_number(p_nro_caja));

          if v_hora is null then --- transaccion 360 normal ---
             v_nro_secuencia := nvl(v_nro_secuencia,0) + 1;
             -- Actualiza la operacion en la base --- cuota prestamo
            -- C.D Fase III--
             if v_est_movimiento = 'P' Then 
                v_aux := 'S';
             else
                v_aux := 'N' ;
             end if;
             /*pap_pre.pr_cob_prestamo(p_nro_cuenta,
                                   v_mto_chq_obco,
                                   v_aux,--'N',
                                   v_cod_oficina,
                                   p_nro_cuota_desde,
                                   p_nro_cuota_hasta,
                                   'Pago de Cuota', --concepto
                                   v_fec_actual,
                                   v_hor_actual,
                                   v_nro_secuencia,
                                   v_cod_tra_padre,
                                   v_cod_modulo,
                                   v_cod_modalidad,
                                   'N', 
                                   null,
                                   null,
                                   v_est_movimiento );-- C.D Fase III*/ --CRO-HO-CROCPCCB-12/08/15 se inactiva el bloque segun AT: CROAPARS-39

             -- genero movimiento por el cobro en cheque --
             if v_mto_chq_obco > 0 then
                v_nro_secuencia := v_nro_secuencia + 1;
                r_gmovi.cod_usuario     := v_cod_usuario;
                r_gmovi.hora            := v_hor_actual;
                r_gmovi.fecha           := v_fec_actual;
                r_gmovi.nro_secuencia   := v_nro_secuencia;
                r_gmovi.cod_modulo      := v_mod_cobro;
                r_gmovi.cod_modalidad   := v_mad_cobro;
                r_gmovi.cod_oficina     := v_cod_ofi_cta;
                r_gmovi.cod_moneda      := v_cod_moneda;
                r_gmovi.fec_valor       := v_fec_actual;
                r_gmovi.cod_tra_padre   := v_cod_tra_padre;
                r_gmovi.cod_mod_padre   := v_cod_modulo;
                r_gmovi.cod_mad_padre   := v_cod_modalidad;
                r_gmovi.nro_caja        := to_number(p_nro_caja);
                r_gmovi.cod_transaccion := v_cod_tra_cheque;
                r_gmovi.monto           := v_mto_chq_obco;
                r_gmovi.nro_documento   := v_nro_documento;
                --r_gmovi.nro_documento2  := v_nro_factura; --RI
                r_gmovi.referencia      := v_nro_factura; --RI
                r_gmovi.cod_ofi_origen  := v_cod_oficina;
                r_gmovi.emi_aviso       := v_emi_aviso;
                r_gmovi.concepto        := 'Cobro Prest :'||p_nro_cuenta;
                --r_gmovi.estado          := 'N';
                r_gmovi.estado          := v_est_movimiento; -- C.D Fase III
                r_gmovi.reversado       := 'N';
                r_gmovi.cod_rubro       := NULL;
                --r_gmovi.nro_cuenta      := NULL;
                r_gmovi.nro_cuenta      := p_nro_cuenta; --CRO-HO-CROCPCCB
                r_gmovi.tip_mov_rubro   := NULL;
                
                ---- Recuperar datos de la retencion
                pag_cta.PR_OBT_RETENCION(v_fec_actual,p_nro_cuenta,
                        v_mod_cobro, v_mad_cobro, r_gmovi.cod_transaccion, v_cod_moneda,
                        r_gmovi.cod_retencion, r_gmovi.fec_fin_retencion);
                PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi);
             end if;
             if v_mto_chq_nbco > 0 then
                v_nro_secuencia := v_nro_secuencia + 1;

                r_gmovi.cod_usuario     := v_cod_usuario;
                r_gmovi.hora            := v_hor_actual;
                r_gmovi.fecha           := v_fec_actual;
                r_gmovi.nro_secuencia   := v_nro_secuencia;
                r_gmovi.cod_modulo      := v_mod_cobro;
                r_gmovi.cod_modalidad   := v_mad_cobro;
                r_gmovi.cod_oficina     := v_cod_ofi_cta;
                r_gmovi.cod_moneda      := v_cod_moneda;
                r_gmovi.fec_valor       := v_fec_actual;
                r_gmovi.cod_tra_padre   := v_cod_tra_padre;
                r_gmovi.cod_mod_padre   := v_cod_modulo;
                r_gmovi.cod_mad_padre   := v_cod_modalidad;
                r_gmovi.nro_caja        := to_number(p_nro_caja);
                r_gmovi.cod_transaccion := 606; --- Cheques
                r_gmovi.monto           := v_mto_chq_nbco;
                r_gmovi.nro_documento   := v_nro_documento;
                --r_gmovi.nro_documento2  := v_nro_factura; --RI
                r_gmovi.referencia      := v_nro_factura; --RI
                r_gmovi.cod_ofi_origen  := v_cod_oficina;
                r_gmovi.emi_aviso       := v_emi_aviso;
                r_gmovi.concepto        := 'Cobro Prest :'||p_nro_cuenta;
                --r_gmovi.estado          := 'N';
                r_gmovi.estado          := v_est_movimiento; -- C.D Fase III
                r_gmovi.reversado       := 'N';
                r_gmovi.cod_rubro       := NULL;
                r_gmovi.nro_cuenta      := NULL;
                r_gmovi.tip_mov_rubro   := NULL;
                ---- Recuperar datos de la retencion
                pag_cta.PR_OBT_RETENCION(v_fec_actual,p_nro_cuenta,
                        v_mod_cobro, v_mad_cobro, 606, v_cod_moneda,
                        r_gmovi.cod_retencion, r_gmovi.fec_fin_retencion);
                PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi);
             end if;
          else   --- retoma operaciones pendientes
            --cargamos como actual la hora del mov.
             v_hor_actual              := v_hora;
             r_gmovi.cod_retencion     := null;
             r_gmovi.fec_fin_retencion := null;
             if v_mto_chq_obco > 0 then
                pag_cta.PR_OBT_RETENCION(v_fec_actual,p_nro_cuenta,
                        v_mod_cobro, v_mad_cobro, v_cod_tra_chq_retomada, v_cod_moneda,
                        r_gmovi.cod_retencion, r_gmovi.fec_fin_retencion);
                begin
                  update ge_movimientos
                  set cod_retencion     = r_gmovi.cod_retencion,
                      fec_fin_retencion = r_gmovi.fec_fin_retencion
                  where cod_tra_padre   = v_cod_tra_padre
                    and fecha           = v_fec_actual
                    and hora            = v_hora
                    and estado          = 'J'
                    and cod_transaccion = v_cod_tra_chq_retomada;--607;
               exception
                  when no_data_found then
                   v_cod_respuesta := '002';
                   v_msj_respuesta := 'No encontro ge_movimientos pendientes :'||sqlerrm;
                  when others then
                   v_cod_respuesta := '999';
                   v_msj_respuesta := 'Error al Act. movim.pendientes :'||SQLERRM;
               end;
             end if;
             if v_mto_chq_nbco > 0 then
                pag_cta.PR_OBT_RETENCION(v_fec_actual,p_nro_cuenta,
                        v_mod_cobro, v_mad_cobro, 606, v_cod_moneda,
                        r_gmovi.cod_retencion, r_gmovi.fec_fin_retencion);
                begin
                  update ge_movimientos
                  set cod_retencion     = r_gmovi.cod_retencion,
                      fec_fin_retencion = r_gmovi.fec_fin_retencion
                  where cod_tra_padre   = v_cod_tra_padre
                    and fecha           = v_fec_actual
                    and hora            = v_hora
                    and estado          = 'J'
                    and cod_transaccion = 606;
               exception
                  when no_data_found then
                   v_cod_respuesta := '002';
                   v_msj_respuesta := 'No encontro ge_movimientos pendientes :'||sqlerrm;
                  when others then
                   v_cod_respuesta := '999';
                   v_msj_respuesta := 'Error al Act. movim.pendientes :'||SQLERRM;
               end;
             end if;
          end if;

          if pag_cta.g_cod_error <> 0 then
             -- actualizacion con problemas
             v_cod_respuesta := ltrim(to_char(pag_cta.g_cod_error,'000'));
             v_msj_respuesta := pag_cta.g_msj_error;
          else -- genero la transaccion en caja
             --actualizar el movimiento
             begin
                update ge_movimientos
                set estado            = 'N',
                    nro_caja          = to_number(p_nro_caja),
                    cod_mod_padre     = v_mod_cobro,
                    cod_mad_padre     = v_mad_cobro,
                    cod_oficina       = v_cod_ofi_cta,
                    nro_documento     = v_nro_documento,
                    nro_documento2    = v_nro_factura,
                    emi_aviso         = v_emi_aviso
                where cod_tra_padre   = v_cod_tra_padre
                  and fecha           = v_fec_actual
                  and hora            = v_hora
                  and estado          = 'J';
             exception
                when no_data_found then
                 v_cod_respuesta := '002';
                 v_msj_respuesta := 'No encontro ge_movimientos pendientes :'||sqlerrm;
                when others then
                 v_cod_respuesta := '999';
                 v_msj_respuesta := 'Error al Act. movim.pendientes :'||SQLERRM;
             end;
             --***
          end if;

          if v_cod_respuesta ='000' then
            -- C.Fase III -- Dejar pendiente en cj_movimientos
             if nvl(v_nro_pedido,0) > 0 then
                lp_gen_transaccion('P');
             else
                lp_gen_transaccion('N');
             end if;
             --actualizar los movimientos para no emitir comprobante
             --sólo si el comprobante es manual
             if p_nro_comprobante is not null then
                begin
                   update ge_movimientos
                   set emi_aviso         = v_emi_aviso
                   where cod_tra_padre   = v_cod_tra_padre
                     and fecha           = v_fec_actual
                     and hora            = v_hora;
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
    if nvl(v_mto_chq_obco,0) = 0 then
       if p_nro_comprobante is not null then
         v_msj_respuesta := 'Operacion Confirmada. No se imprimirá el Comprobante Manual';
       else
         if nvl(v_nro_pedido,0) = 0 then
           v_msj_respuesta := 'Operacion confirmada 3';
         else
            v_msj_respuesta := 'Se creó la Solicitud de Autorización: '||v_nro_pedido; 
         end if;
       end if;
    end if;
    if nvl(v_nro_pedido,0) > 0 then
      v_msj_respuesta := 'Se creó la Solicitud de Autorización: '||v_nro_pedido;
    end if;
 end if;
 
 v_cod_respuesta := 'IMP'; -- para indicar que esta ok y se puede imprimir
 v_msj_respuesta := 'Operacion Confirmada. Comprobante de Pago ha sido impreso.'||'~'||
 fuj_imp_transaccion_360(v_cod_oficina, -- oficina
                         v_nro_documento,
                         v_nro_factura,
                         p_nro_caja, -- Caja
                         v_cod_moneda, -- Moneda
                         p_nro_cuenta, -- cuenta
                         v_fec_actual,
                         v_hor_actual -- hora
                         );
 
 pag_cta.pr_nro_caja(null);
 /* falta armar el mensaje de respuesta */
 v_msj_salida := p_nro_operacion||'~'||
                 v_cod_respuesta||'~'||
                 nvl(v_msj_respuesta,nvl(v_msj_salida,'Con error'));
 return(v_msj_salida);
exception
   when others then
      pag_cta.pr_nro_caja(null);
      v_msj_salida := p_nro_operacion||'~'||'999'||'~!'||sqlerrm;
      return(v_msj_salida);
end FUJ_PRO_TRANSACCION_361;
/
