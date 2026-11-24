CREATE OR REPLACE FUNCTION IT.FUJ_PRO_TRANSACCION_102
 (P_NRO_OPERACION IN VARCHAR2
 ,P_NRO_CAJA IN Varchar2
 ,P_NRO_COMPROBANTE IN NUMBER default null --nro de comprobante manual
 ,P_NRO_DOCUMENTO IN VARCHAR2
 ,P_NRO_CUENTA IN VARCHAR2
/* ,P_EFECTIVO IN VARCHAR2
 ,P_CHQ_OBCO IN Varchar2 default null
 ,p_tip_retencion IN Varchar2 default null
 ,P_CHQ_NBCO IN Varchar2 default null
 -- Agregado para detalle de cheques, si es uno solo
 ,p_cod_banco  in varchar2 DEFAULT NULL     -- codigo del banco
 ,p_nro_cheque in varchar2 DEFAULT NULL     -- numero de cheque
 ,p_mto_cheque in varchar2 DEFAULT NULL     -- monto del cheque
 ,p_cod_ofi_camara in number default null*/
 )
 RETURN Varchar2
 IS
  -- defino por defecto el modulo y modalidad a utilizar
  v_cod_modulo      number(3)      := 9;    -- Caja
  v_cod_modalidad   number(3)      := 91;   -- Caja
  v_cod_transaccion number(4)      := 102;  -- transaccion
  v_cod_usuario     varchar2(10);--   := upper(user); --usuario

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
  v_cod_moneda        varchar2(3);       -- moneda de la cuenta
  v_est_cuenta        varchar2(1);       -- estado de la cuenta

  -- Datos de salida
  v_msj_salida    varchar2(12000);                           -- mensaje final retornado
  v_cod_respuesta varchar2(03) := '000';                     -- sin errores
  v_msj_respuesta long := 'Operacion Confirmada'; -- sin errores

  -- datos de la operacion convertidos
  v_tipo          varchar2(01) := 'D' ;     -- 'C' credito para la caja (egreso) o vice versa
  v_tip_monto     varchar2(01) := 'O';       -- E efectivo / O cheque otros Bcos
  v_nro_secuencia number(3) := 0;           -- secuencia del mov.

  -- datos que se cargan en la pantalla
  v_mto_cobrado   number(18,2) ;--:= nvl(to_number(p_efectivo),0)+ nvl(to_number(p_chq_obco),0) + nvl(to_number(p_chq_nbco),0)  ;
  v_mto_chq_obco  number(18,2) ;--:= nvl(to_number(p_chq_obco),0);
  v_mto_chq_nbco  number(18,2) ;--:= nvl(to_number(p_chq_nbco),0);
  v_mto_efectivo  number(18,2) ;--:= nvl(to_number(p_efectivo),0);

  v_nro_documento cj_movimientos.nro_documento%type;
  v_nro_factura   cj_movimientos.nro_documento%type;

  r_gmovi         ge_movimientos%rowtype;
  v_mod_cobro     number(3) := 10 ; ---- modulo del prestamo
  v_mad_cobro     number(3);       ---- modalidad del prestamo

  --- para operaciones pendientes
  v_hora                varchar2(8) :=null;  --- para recuperar hora de oper.pendiente
  v_cod_tran_pend       number(4);     --- transaccion efectivo o cheque
  v_tot_capital         number(18,2);
  v_tot_interes         number(18,2);
  v_tot_cap_int         number(18,2);
  v_tot_a_cobrar        number(18,2);
  v_tot_cre_cta         number(18,2);
  v_tot_cre_cta_con     number(18,2);
  --emision de comprobante automatico
  v_emi_aviso ge_movimientos.emi_aviso%type := 'S';
  v_nro_comprobante     ge_movimientos.nro_documento%type := P_NRO_DOCUMENTO;

  v_monto_efectivo number(18,2) :=0; --- importe pagado operacion pendiente efectivo
  v_monto_cheque   number(18,2) :=0; --- importe pagado operacion pendiente cheque
  v_monto_cheque_n number(18,2) :=0;
  v_cod_tra_cheque       ge_movimientos.cod_transaccion%type;
  v_cod_tra_chq_retomada ge_movimientos.cod_transaccion%type;

  cursor c_cobros is
    select cod_transaccion, monto
      From ge_movimientos
     Where cod_tra_padre = v_cod_transaccion
       And fecha         = v_fec_actual
       And estado        = 'J'
       And hora          = v_hora;

  cursor c_mto_cobrados is
    select cod_transaccion, monto
      from ge_movimientos
     where cod_tra_padre = v_cod_transaccion
       and fecha         = v_fec_actual
       and hora          = v_hora;

  -- Procedimiento interno para generar movimiento y act. de control de caja
  procedure lp_gen_transaccion  is
  begin
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
            nro_documento, monto, tip_monto, tipo)
        values
           (p_nro_cuenta, v_fec_actual, v_hor_actual, v_cod_usuario, v_nro_secuencia,
            v_cod_transaccion,
            decode(nvl(v_hora,'X'),'X', v_cod_modulo, v_mod_cobro), --ve si retoma
            decode(nvl(v_hora,'X'),'X', v_cod_modalidad, v_mad_cobro),--ve si retoma
            v_cod_oficina, v_cod_moneda, to_number(p_nro_caja),
            nvl(v_nro_documento, v_nro_factura), v_mto_efectivo,'E', v_tipo);  -- es debito
      end if;
      if v_mto_chq_obco > 0 then
        if nvl(v_cod_tra_cheque,v_cod_tra_chq_retomada) = 607 then --24hs
          v_tip_monto := 'O';
        elsif nvl(v_cod_tra_cheque,v_cod_tra_chq_retomada) = 610 then --48hs
          v_tip_monto := 'T';
        elsif nvl(v_cod_tra_cheque,v_cod_tra_chq_retomada) = 632 then --72hs
          v_tip_monto := 'S';
        elsif nvl(v_cod_tra_cheque,v_cod_tra_chq_retomada) = 632 /*and  r_opeven.cod_moneda <> v_cod_mon_local*/ then --72hs
          v_tip_monto := 'X';
        end if;
        -- genero el movimiento por el deposito en cheques (local - otros bcos )
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
            v_cod_transaccion,
            decode(nvl(v_hora,'X'),'X', v_cod_modulo, v_mod_cobro), --ve si retoma
            decode(nvl(v_hora,'X'),'X', v_cod_modalidad, v_mad_cobro),--ve si retoma
            v_cod_oficina, v_cod_moneda, to_number(p_nro_caja),
            nvl(v_nro_documento, v_nro_factura), v_mto_chq_obco ,v_tip_monto , v_tipo); -- es debito
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
              nro_documento, monto, tip_monto, tipo)
          values
             (p_nro_cuenta, v_fec_actual, v_hor_actual, v_cod_usuario, v_nro_secuencia,
              v_cod_transaccion,
              decode(nvl(v_hora,'X'),'X', v_cod_modulo, v_mod_cobro), --ve si retoma
              decode(nvl(v_hora,'X'),'X', v_cod_modalidad, v_mad_cobro),--ve si retoma
              v_cod_oficina, v_cod_moneda, to_number(p_nro_caja),
              nvl(v_nro_documento, v_nro_factura), v_mto_chq_nbco ,'C' , v_tipo);
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
 /*elsif v_mto_cobrado is null or v_mto_cobrado <= 0 then
    v_cod_respuesta := '003'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el importe Pagado.';*/
 else
    if v_cod_respuesta = '000' then -- sino hubo problemas, veo la caja
       BEGIN
        Select p.cod_moneda, p.estado, p.cod_modulo, p.cod_modalidad, p.cod_oficina
          into v_cod_moneda, v_est_cuenta, v_mod_cobro, v_mad_cobro, v_cod_ofi_cta
          from ge_cuentas p
         where p.nro_cuenta = p_nro_cuenta;
        if v_mod_cobro <> 10  then
          v_cod_respuesta := '003';
          v_msj_respuesta := 'ERROR: Cuenta no es de Mesa de Dinero';
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
            v_msj_respuesta := 'Caja no esta habilitada para esta Operacion';
         elsif v_fec_caja <> v_fec_actual then
            v_cod_respuesta := '005'; -- error
            v_msj_respuesta := 'Caja no fue habilitada el dia de hoy';
         end if;
       end if;
    end if;
    ----- aqui veo si viene de retomar pendiente o no -----
    if v_cod_respuesta = '000' then
       prj_ver_pen_caja(p_nro_cuenta,
                        v_cod_transaccion,
                        v_fec_actual,
                        v_cod_usuario,
                        v_hora,
                        v_cod_tran_pend,
                        v_cod_respuesta,
                        v_msj_respuesta);
    end if;
    if v_cod_respuesta = '001' then  ---- debe retomar hay pendientes 'J'
        v_cod_respuesta := '000';
        For c In c_mto_cobrados Loop
          If c.cod_transaccion = 801 Then
            v_tot_capital := c.monto;
          Elsif c.cod_transaccion = 802 Then
            v_tot_interes := c.monto;
          End If;
        End Loop;
        --- Recuperar formas de cobro
        Begin
          select nvl(sum(decode(cod_transaccion,503,nvl(monto,0),0)),0),
                 nvl(sum(decode(cod_transaccion,842,nvl(monto,0),0)),0)
            into v_tot_cre_cta, v_tot_cre_cta_con
            from ge_movimientos
           where fecha = v_fec_actual
             and hora = v_hora
             and cod_transaccion in (503,842);
        End;

        v_tot_cap_int  := nvl(v_tot_capital,0) +
                          nvl(v_tot_interes,0);

        v_tot_a_cobrar:= nvl(v_tot_cap_int,0);

        /*if nvl(v_mto_cobrado,0)+nvl(v_tot_cre_cta,0)+nvl(v_tot_cre_cta_con,0)
          <> v_tot_a_cobrar then
             v_cod_respuesta := '008';
             v_msj_respuesta := 'No coinciden los montos a cobrar';
        end if;*/

        -- busca las operaciones pendientes para actualizar
        for reg in c_cobros loop
            if reg.cod_transaccion = 740 then
                v_monto_efectivo := reg.monto;
            elsif reg.cod_transaccion in (607, 610, 632) then --retencion 1,2,3
              v_monto_cheque   := reg.monto;
              v_cod_tra_chq_retomada := reg.cod_transaccion;
            elsif reg.cod_transaccion = 606 then
              v_monto_cheque_n   := reg.monto;
            end if;
        end loop;

        /*if nvl(v_monto_efectivo,0) <> nvl(P_EFECTIVO,0) or
           nvl(v_monto_cheque_n,0) <> nvl(P_CHQ_NBCO,0) or
           nvl(v_monto_cheque,0)   <> nvl(P_CHQ_OBCO,0) then
           v_cod_respuesta := '010';
           v_msj_respuesta := 'Montos detallados no coinciden con los especificados en operaciones';
        end if;*/

        v_mto_efectivo := v_monto_efectivo;
        v_mto_chq_nbco := v_monto_cheque_n;
        v_mto_chq_obco := v_monto_cheque;

     else  ---- transaccion 102 normal
        --el usuario es el user
        v_cod_usuario   := upper(user);
        declare
           x_cod_modalidad   number(4);
        Begin --- Busco la minima cuota a pagar
          select cod_modalidad
            into x_cod_modalidad
            from md_cta_documentos
           where nro_cuenta = p_nro_cuenta;

        Exception
            when no_data_found then
               v_cod_respuesta := '009'; -- error, no existe cuota a pagar
               v_msj_respuesta := 'No encuentra cuota minima a pagar';
            when others then
               v_cod_respuesta := '010'; -- error, no existe cuota a pagar
               v_msj_respuesta := 'Error al buscar cuota minima';
        End;
        if v_cod_respuesta = '000' then -- sino hubo ERROR se arma los datos de la cuenta
           pam_doc.pr_obt_mto_venta(p_nro_cuenta, v_mto_cobrado,
                            v_tot_capital, v_tot_interes);
          v_tot_a_cobrar:= nvl(v_tot_capital,0) +
                           nvl(v_tot_interes,0);

          if nvl(v_mto_cobrado,0)+nvl(v_tot_cre_cta,0)+nvl(v_tot_cre_cta_con,0)
             > v_tot_a_cobrar then
             v_cod_respuesta := '009';
             v_msj_respuesta := 'Monto a pagar supera el detallado';
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
      -- solo si no ingreso comprobante manual
      if v_nro_comprobante is not null then
         v_nro_documento := p_nro_comprobante;
         v_emi_aviso := 'N'; --indica comprobante manual en los movimientos
      else
         begin
            if nvl(v_tot_capital,0) + nvl(v_tot_interes,0) > 0 then
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
    end if;
    /*if v_cod_respuesta = '000' then
        if nvl(v_mto_chq_obco,0) = 0 and p_cod_banco is not null then
          v_cod_respuesta := '006'; -- error
          v_msj_respuesta := 'No posee montos en cheque. No puede detallar.';
        end if;
    end if;*/
    if v_cod_respuesta = '000' then
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
             pam_doc.pr_vta_documento(p_nro_cuenta,
                           v_mto_cobrado,
                           v_cod_oficina, --- oficina origen
                           'Venta de Documento '||p_nro_cuenta,
                           v_fec_actual,
                           v_hor_actual,
                           v_nro_secuencia,
                           v_cod_transaccion,
                           v_cod_modulo,
                           v_cod_modalidad,
									0);--mto_garantia

             -- genero movimiento por el cobro en efectivo --
             if v_mto_efectivo  > 0 then
                v_nro_secuencia := nvl(v_nro_secuencia,0) + 1;

                r_gmovi.cod_usuario     := v_cod_usuario;
                r_gmovi.hora            := v_hor_actual;
                r_gmovi.fecha           := v_fec_actual;
                r_gmovi.nro_secuencia   := v_nro_secuencia;
                r_gmovi.cod_modulo      := v_mod_cobro;
                r_gmovi.cod_modalidad   := v_mad_cobro;
                r_gmovi.cod_oficina     := v_cod_ofi_cta;
                r_gmovi.cod_moneda      := v_cod_moneda;
                r_gmovi.fec_valor       := v_fec_actual;
                r_gmovi.cod_tra_padre   := v_cod_transaccion;
                r_gmovi.cod_mod_padre   := v_cod_modulo;
                r_gmovi.cod_mad_padre   := v_cod_modalidad;
                r_gmovi.nro_caja        := to_number(p_nro_caja);
                r_gmovi.cod_transaccion := 740; --- Efectivo
                r_gmovi.monto           := v_mto_efectivo;
                r_gmovi.nro_documento   := v_nro_documento;
                r_gmovi.nro_documento2  := v_nro_factura;
                r_gmovi.cod_ofi_origen  := v_cod_oficina;
                r_gmovi.emi_aviso       := v_emi_aviso;
                r_gmovi.concepto        := 'Venta de Documento '||p_nro_cuenta;
                r_gmovi.estado          := 'N';
                r_gmovi.reversado       := 'N';
                r_gmovi.cod_rubro       := NULL;
                r_gmovi.nro_cuenta      := NULL;
                r_gmovi.tip_mov_rubro   := NULL;
                PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi);
             end if;
             -- genero movimiento por el cobro en cheque --
             if v_mto_chq_obco > 0 Then
                /*if nvl(p_tip_retencion,1) = 1 then
                  v_cod_tra_cheque := 607; --- Cheques
                elsif p_tip_retencion = 2 then
                  v_cod_tra_cheque := 610; --- Cheques
                elsif p_tip_retencion = 3 then
                  v_cod_tra_cheque := 632; --- Cheques
                end if;*/

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
                r_gmovi.cod_tra_padre   := v_cod_transaccion;
                r_gmovi.cod_mod_padre   := v_cod_modulo;
                r_gmovi.cod_mad_padre   := v_cod_modalidad;
                r_gmovi.nro_caja        := to_number(p_nro_caja);
                r_gmovi.cod_transaccion := v_cod_tra_cheque; --- Cheques
                r_gmovi.monto           := v_mto_chq_obco;
                r_gmovi.nro_documento   := v_nro_documento;
                r_gmovi.nro_documento2  := v_nro_factura;
                r_gmovi.cod_ofi_origen  := v_cod_oficina;
                r_gmovi.emi_aviso       := v_emi_aviso;
                r_gmovi.concepto        := 'Venta de Documento '||p_nro_cuenta;
                r_gmovi.estado          := 'N';
                r_gmovi.reversado       := 'N';
                r_gmovi.cod_rubro       := NULL;
                r_gmovi.nro_cuenta      := NULL;
                r_gmovi.tip_mov_rubro   := NULL;
                ---- Recuperar datos de la retencion
                pag_cta.PR_OBT_RETENCION(v_fec_actual,p_nro_cuenta,
                        v_mod_cobro, v_mad_cobro, v_cod_tra_cheque, v_cod_moneda,
                        r_gmovi.cod_retencion, r_gmovi.fec_fin_retencion);
                PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi);
             end if;
             if v_mto_chq_nbco > 0 Then
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
                r_gmovi.cod_tra_padre   := v_cod_transaccion;
                r_gmovi.cod_mod_padre   := v_cod_modulo;
                r_gmovi.cod_mad_padre   := v_cod_modalidad;
                r_gmovi.nro_caja        := to_number(p_nro_caja);
                r_gmovi.cod_transaccion := 606; --- Cheques
                r_gmovi.monto           := v_mto_chq_nbco;
                r_gmovi.nro_documento   := v_nro_documento;
                r_gmovi.nro_documento2  := v_nro_factura;
                r_gmovi.cod_ofi_origen  := v_cod_oficina;
                r_gmovi.emi_aviso       := v_emi_aviso;
                r_gmovi.concepto        := 'Venta de Documento '||p_nro_cuenta;
                r_gmovi.estado          := 'N';
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
                    where cod_tra_padre   = v_cod_transaccion
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
               --actualizar el movimiento
               begin
                  update ge_movimientos
                     set cod_retencion     = r_gmovi.cod_retencion,
                         fec_fin_retencion = r_gmovi.fec_fin_retencion
                  where cod_tra_padre   = v_cod_transaccion
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
                    emi_aviso         = v_emi_aviso
                where cod_tra_padre   = v_cod_transaccion
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
          end if;
          --**
          if v_cod_respuesta ='000' then
             lp_gen_transaccion();
             --actualizar los movimientos para no emitir comprobante
             --solo si el comprobante es manual
             if p_nro_comprobante is not null then
                begin
                   update ge_movimientos
                   set emi_aviso         = v_emi_aviso
                   where cod_tra_padre   = v_cod_transaccion
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
             End If;
          End If;
       end if;
    end if;
 end if;
 -- mensaje final sino hubo errores
 if v_cod_respuesta = '000' then -- sino hubo problemas, se carga mensaje por defecto
    if nvl(v_mto_chq_obco,0) = 0 then
      v_msj_respuesta := 'Operacion confirmada.';
    end if;
 end if;
 if v_cod_respuesta = '000' then -- sino hubo problemas, se carga mensaje por defecto
    -- IMPRESION DEL COMPROBANTE DE PAGO
    if (nvl(v_mto_chq_obco,0) = 0 or (nvl(v_mto_chq_obco,0)>0 and nvl(v_cod_tra_cheque,v_cod_tra_chq_retomada)= 607)) and nvl(v_mto_chq_nbco,0) = 0  then
       v_cod_respuesta := 'IMP'; -- para indicar que esta ok y se puede imprimir
       v_msj_respuesta := 'Operacion Confirmada. Comprobante de Pago ha sido impreso.'||'~'||
       fuj_imp_transaccion_102(v_cod_oficina, -- oficina
                               v_nro_documento,
                               p_nro_caja, -- Caja
                               r_gmovi.cod_moneda, -- Moneda
                               p_nro_cuenta, -- cuenta
                               v_fec_actual,
                               v_hor_actual -- hora
                               );
    else
       if nvl(v_cod_tra_cheque,v_cod_tra_chq_retomada) = 607 then --24hs
         v_msj_respuesta := 'Operacion confirmada - '||v_nro_documento;
       else
         v_msj_respuesta := 'Operacion confirmada - '||v_nro_documento;
       end if;

       /*if p_cod_banco is not null and p_nro_cheque is not null and
          p_mto_cheque is not null and
          nvl(v_cod_tra_cheque,v_cod_tra_chq_retomada) <> 607 then --24hs
          -- se detallo el cheque, se procesa el detalle del mismo
          v_msj_salida := fuj_pro_transaccion_133(p_nro_operacion,
                                               p_nro_caja,
                                               v_nro_documento,
                                               p_tip_retencion,
                                               p_cod_banco,
                                               p_nro_cheque,
                                               p_mto_cheque,
                                               p_cod_ofi_camara);
          if v_msj_salida NOT LIKE '%~000~%'  then
             return (v_msj_salida); -- retorna directamente el mensaje
          end if;
       end if;*/
    end if;
 end if;

 /* falta armar el mensaje de respuesta */
 v_msj_salida := p_nro_operacion||'~'||
                 v_cod_respuesta||'~'||
                 nvl(v_msj_respuesta,'Operacion confirmada');
 return(v_msj_salida);
end FUJ_PRO_TRANSACCION_102;
/

