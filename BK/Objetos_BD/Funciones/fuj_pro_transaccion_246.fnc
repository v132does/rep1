CREATE OR REPLACE FUNCTION IT.FUJ_PRO_TRANSACCION_246
 (p_nro_operacion in varchar2,   -- Nro de referencia de la operacion
  p_nro_caja in varchar2,        -- Nro de Caja
  p_nro_ope_pendiente in number, -- operacion pendiente retomada
  p_cod_retencion in number,     -- Código de Retención
  --para detalle de cheques
  p_cod_banco    in number default null, --codigo de banco
  p_nro_cheque   in number default null, --nro de cheque
  --Agregado para detalle de cheque nuestro bco
  p_nro_che_ntro in number default null)

 RETURN LONG
 IS
  -- defino por defecto el modulo y modalidad a utilizar
  v_cod_modulo        number(3) := 9;    -- Caja
  v_cod_modalidad     number(3) := 91;   -- Caja
  v_cod_transaccion   number(4) := 246;  -- transaccion
  v_cod_usuario       varchar2(10) := upper(user); --usuario
  -- Datos de la caja
  v_fec_actual        date := pag_cal.fu_obt_fec_actual(v_cod_modulo); -- fecha de hoy
  v_cod_oficina       number(3);         -- Codigo de oficina
  v_estado            number(1);         -- estado de la caja
  v_fec_caja          date;              -- fecha de la caja
  v_sal_actual        number(18,2);      -- saldo actual de la caja en efectivo
  v_sal_cheques       number(18,2);      -- saldo actual de la caja en cheques
  -- Datos de salida
  v_msj_salida        long;        -- mensaje final retornado
  v_cod_respuesta     varchar2(03) := '000'; -- sin errores
  v_msj_respuesta     long := ''; -- sin errores
  --Datos de la operacion
  v_afe_posicion       lc_tip_operaciones.afe_posicion%type;
  v_afe_limite         lc_tip_operaciones.afe_limite%type;
  v_afe_che_viajero    lc_tip_operaciones.afe_che_viajero%type;
  v_caja               lc_tip_operaciones.caja%type;
  v_tip_valor          lc_tip_operaciones.tip_valor%type;
  v_cod_mod_origen     lc_tip_operaciones.cod_mod_origen%type;
  v_cod_mad_operacion  lc_tip_operaciones.cod_modalidad%type;
  v_cod_tra_operacion  lc_tip_operaciones.cod_transaccion%type;
  v_cod_mad_hijo       lc_tip_operaciones.cod_mad_hijo%type;
  v_afe_cod_transaccion lc_tip_operaciones.afe_cod_transaccion%type;
  v_cod_tra_cargo1     lc_tip_operaciones.cod_tra_cargo1%type;
  v_cod_tra_cargo2     lc_tip_operaciones.cod_tra_cargo2%type;
  v_cod_tra_cargo3     lc_tip_operaciones.cod_tra_cargo3%type;
  v_cotizacion         ge_cotizaciones.val_conversion%type;
  v_cot_mon_fuerte     ge_cotizaciones.val_conversion%type;
  v_nombre             ba_personas.nom_completo%type;
  v_equivalente        number;
  v_mto_cargo          number;
  v_mto_cargo1         number;
  v_mto_cargo2         number;
  v_mto_cargo3         number;
  v_total              number;
  v_cod_tasa           number;
  v_val_tasa           number;
  v_cod_tasa1          number;
  v_val_tasa1          number;
  v_cod_tasa2          number;
  v_val_tasa2          number;
  v_cod_tasa3          number;
  v_val_tasa3          number;
   v_cod_moneda_lim     ba_monedas.cod_moneda%type;
  v_mto_lim            number(18,2);
  v_mov_mto_cargo      ge_movimientos.monto%type;
  v_mov_cod_tra_cargo  ge_movimientos.cod_transaccion%type;
  v_mov_cod_tasa       number;
  v_mov_val_tasa       number;
  v_tra_impuesto       ge_movimientos.cod_transaccion%type;
  v_impuesto           ge_movimientos.monto%type;
  v_des_cargo          ge_transacciones.descripcion%type;
  v_hora               ge_movimientos.hora%type := to_char(sysdate,'hh24:mi:ss');
  v_nro_secuencia      ge_movimientos.nro_secuencia%type:=0;
  r_gmovi              ge_movimientos%rowtype;
  v_mon_local          ge_movimientos.cod_moneda%type := pag_gen.FU_OBT_MON_LOCAL;
  v_mon_fuerte         ge_movimientos.cod_moneda%type := pag_gen.FU_OBT_MON_FUERTE;
  v_cta_cambios        lc_cta_cambios.nro_cuenta%type;
  v_lim_utilizado      lc_cta_cambios.mto_limite%type;
  v_cod_retencion      ge_movimientos.cod_retencion%type;
  v_fec_fin_retencion  date;
  v_cod_persona        ba_personas.cod_persona%type;
  v_tip_aplicacion     lc_tip_ope_oficinas.tip_aplicacion%type;
  v_cod_rubro          lc_tip_ope_oficinas.cod_rubro%type;
  v_cod_tip_referencia lc_tip_ope_oficinas.cod_tip_referencia%type;
  v_nro_referencia     lc_tip_referencias.sig_numero%type;
  v_est_cta_cambios    lc_cta_cambios.estado%type;
  v_cod_ofi_cta_cambios lc_cta_cambios.cod_oficina%type;
  v_nro_documento      ba_personas.nro_documento%type;
  v_efectivo           ge_movimientos.monto%type;
  v_cod_moneda         ba_monedas.cod_moneda%type;
  v_importe            ge_movimientos.monto%type;
  v_tip_mov_rubro      ge_movimientos.tip_mov_rubro%type;
  v_cod_tip_operacion  lc_tip_operaciones.cod_tip_operacion%type;
  v_cod_ope_bcp        lc_tip_operaciones.cod_tip_ope_bcp%type;
  v_cheque             lc_ope_pendientes.cta_ref_contra2%type;
  v_cta_cliente        lc_ope_pendientes.cta_ref_contra3%type;
  v_mto_cta_cliente    lc_ope_pendientes.mto_contra3%type;
  v_cta_contable       lc_ope_pendientes.cta_ref_contra4%type;
  v_mto_cta_contable   lc_ope_pendientes.mto_contra4%type;
  v_cod_banco          ge_bancos.cod_banco%type;
  v_nro_cheque         lc_ope_pendientes.nro_cheque%type;
  v_cta_referencia     lc_ope_pendientes.cta_referencia%type;
  v_tipo               ge_movimientos.tip_mov_rubro%type;
  v_cod_mod_cuenta     ge_cuentas.cod_modulo%type;
  v_cod_mad_cuenta     ge_cuentas.cod_modalidad%type;
  v_est_cuenta         ge_cuentas.estado%type;
  v_sal_disp_cuenta    lc_cta_cambios.mto_limite%type;
  v_procesa            VARCHAR2(1);
  v_cod_autorizacion   ge_autorizaciones.cod_autorizacion%type;
  v_cod_usu_autorizador ba_usuarios.cod_usuario%type;
  v_rango              ge_movimientos.monto%type;
  v_est_mvto           ge_movimientos.estado%type :='N';--mvto. principal
  v_est_mvto_resto     ge_movimientos.estado%type :='N';--otros movimientos
  v_msj                varchar2(500);
  v_aut_cotizacion     varchar2(1):='N';
  v_aut_limite         varchar2(1):='N';
  v_cot_vigente        ge_cotizaciones.val_conversion%type;
  v_tip_monto          varchar2(1):='Z';--no afecta cj_movimientos
  v_mto_cheque         number;
  v_che_ntro_bco       number;
  v_des_operacion      lc_tip_operaciones.descripcion%type;
  v_imp_transferencia  ge_movimientos.monto%type:=0;--impuesto x transf entre cuentas
  v_cod_tra_cheque     ge_movimientos.cod_tra_padre%type;
  v_ubi_banco          ge_bancos.ubicacion%type;
  v_des_banco          ge_bancos.descripcion%type;
  v_cta_cheque         cc_chequeras.nro_cuenta%type;
  v_tip_retencion      ge_movimientos.cod_retencion%type;
  v_cod_ret_pendiente  lc_ope_pendientes.cod_retencion%type;
  v_est_ant_cta_cliente ge_cuentas.estado%type;
  v_imp_transf_equ ge_movimientos.monto%type;
  v_margen number;
  v_monto number;
  v_redondeo_ml number(05);
  v_cli_frecuente varchar2(1) := 'N';
  v_msj_limite         varchar2(500);
  v_msj_monto          varchar2(500);
  v_aut_monto          varchar2(1)  := 'N';
  v_dias_ret           number(18,2);
  v_usu_ins_mesa       varchar2(20);
  v_msj_lim_var        VARCHAR2(2000);
  v_aut_lim_var        varchar2(1):='N';
  v_mto_calculado      number;
  v_cta_formularios    cj_acu_imp_transacciones.nro_cuenta%type;
  -- Procedimiento interno para generar movimiento y act. de control de caja
  procedure lp_gen_transaccion
    (p_tip_movimiento in varchar2,
     p_tip_monto      in varchar2,
     p_cod_moneda     in varchar2,
     p_importe        in number,
     p_nro_secuencia  in number)   is
  v_mto_cheque        number(18,2) := 0;
  v_mto_che_ntro_bco  number(18,2) := 0;
  v_mto_efectivo      number(18,2) := 0;
  v_cta_cam_global     lc_cta_cambios.nro_cuenta%type;
  begin
    -- evaluo el tipo de valor
    if p_tip_monto = 'E' then
      v_mto_efectivo := p_importe;
    elsif p_tip_monto ='C' then
      v_mto_che_ntro_bco := p_importe;
    else
      v_mto_cheque   := p_importe;
    end if;
    if p_tip_movimiento = 'D' then  -- compra
      -- sumar a los saldos  -- Actualizo el control de caja
      update cj_controles
         set tot_che_otr_bco = nvl(tot_che_otr_bco,0) + nvl(v_mto_cheque,0),
             tot_che_nue_bco = nvl(tot_che_nue_bco,0) + nvl(v_mto_che_ntro_bco,0),
             sal_che_otr_bco = nvl(sal_che_otr_bco,0) + nvl(v_mto_cheque,0),
             sal_actual = nvl(sal_actual,0) + nvl(v_mto_efectivo,0),
             tot_debitos = nvl(tot_debitos,0) + nvl(v_mto_efectivo,0),
             can_debitos = nvl(can_debitos,0) + decode(v_mto_efectivo,0,0,1),
             estado = 1 -- abierto
       where nro_caja = to_number(p_nro_caja)
         and cod_moneda = p_cod_moneda
         and fecha = v_fec_caja;
     else
      -- se resta del saldo del cajero -- Actualizo el control de caja
      update cj_controles
         set sal_actual = nvl(sal_actual,0) - nvl(v_mto_efectivo,0),
             tot_creditos = nvl(tot_creditos,0) + nvl(v_mto_efectivo,0),
             can_creditos = nvl(can_creditos,0) + 1,
             estado = 1 -- abierto
       where nro_caja = to_number(p_nro_caja)
         and cod_moneda = p_cod_moneda
         and fecha = v_fec_caja;
     end if;

     -- genero el movimiento por la operacion compra/venta
     --WA:10/09/2013 insertamos el Nro de Cuenta de Cambios, si es Cheque Otros Bancos y no es cta bolsa
     v_cta_cam_global:= FUG_OBT_PARDINAMICO('CTA_CAM_CLI_TEMPORAL');
     if p_tip_monto in ('T','S','O') and v_cta_cambios is not null
        and v_cta_cambios <> v_cta_cam_global then
        insert into cj_movimientos
               (fecha, hora, cod_usuario, nro_secuencia,
                cod_tra_padre, cod_mod_padre, cod_mad_padre,
                cod_oficina, cod_moneda, nro_caja,
                nro_documento,  monto, tip_monto, tipo,nro_cuenta)
            values
               (v_fec_actual, v_hora, v_cod_usuario, p_nro_secuencia,
                v_cod_transaccion, v_cod_modulo, v_cod_modalidad,
                v_cod_oficina, p_cod_moneda, to_number(p_nro_caja),
                p_nro_ope_pendiente, p_importe,
                p_tip_monto, p_tip_movimiento, v_cta_cambios); /* es D-ebito o C-redito */
                /*E-fectivo/C-heq Ntro.Bco /O-Cheq.Otr.Bco(1) /T-Otr.Bco Tarde(2) /S-Otr.Bco(3) PLoc /X-Otr.Bco(3) PExt*/

     else
      --Lo que hacia Antes
           insert into cj_movimientos
               (fecha, hora, cod_usuario, nro_secuencia,
                cod_tra_padre, cod_mod_padre, cod_mad_padre,
                cod_oficina, cod_moneda, nro_caja,
                nro_documento,  monto, tip_monto, tipo)
            values
               (v_fec_actual, v_hora, v_cod_usuario, p_nro_secuencia,
                v_cod_transaccion, v_cod_modulo, v_cod_modalidad,
                v_cod_oficina, p_cod_moneda, to_number(p_nro_caja),
                p_nro_ope_pendiente, p_importe,
                p_tip_monto, p_tip_movimiento); /* es D-ebito o C-redito */
                /*E-fectivo/C-heq Ntro.Bco /O-Cheq.Otr.Bco(1) /T-Otr.Bco Tarde(2) /S-Otr.Bco(3) PLoc /X-Otr.Bco(3) PExt*/
      end if;
  end lp_gen_transaccion;

    -- Agregado en fecha 30/10/2013 por usuario XPY0057
    -- Llama al procedimiento almacenado que controla si el monto
    -- de la operación de compra alcanza o supera el límite
    -- de valor de riesgo permitido. -- CNFLIMVAR-65 --
    PROCEDURE lp_controlar_limites_var IS
        v_cod_error NUMBER(2,0);
        v_estado    ge_movimientos.estado%type;
    BEGIN
        v_msj_respuesta := 'CONTROLAR LIMITES VAR';

        pal_var.pr_wrap_con_pos_cambio (
            USER, -- usuario que realiza la operación
            v_cod_oficina , -- código de oficina
            v_cod_moneda, -- moneda
            v_importe, -- importe
            v_cotizacion, -- cotizacion
            v_cod_tip_operacion, -- tipo operacion
            v_cod_mad_operacion, -- modalidad
            'CON',
            v_fec_actual,
            v_hora,
            'N', -- indica si es operación de homebanking
            'C', -- generar autorización
            v_estado,  -- estado del movimiento para Autorizacion por Limites VaR
            v_cod_error,
            v_msj_lim_var -- mensaje de retorno
        );

        if v_cod_error is not null then
        IF v_cod_error = 0 THEN
            IF nvl(v_estado,'-') = 'X' THEN  -- pendiente de autorización
                v_est_mvto := 'X';
                v_cod_respuesta := '000';
                v_aut_lim_var := 'S';
                v_est_mvto_resto := 'P';
                v_msj_respuesta := v_msj_lim_var;
            END IF;
        ELSE
            v_cod_respuesta := '999';
            v_msj_respuesta := v_msj_lim_var;
        END IF;
        END IF;

    EXCEPTION
        WHEN OTHERS THEN
             v_cod_respuesta := '998';
             v_msj_respuesta := v_msj_respuesta||': '||SQLERRM;
    END;


/*inicia proceso principal*/
begin
   if p_nro_ope_pendiente is null then
      v_cod_respuesta := '001'; -- error
      v_msj_respuesta := 'ERROR: Ingrese el Tipo de operacion pendiente a retomar.';
   else
      --busca la operacion pendiente
      begin
         select a.cod_tip_operacion, a.cod_tip_ope_bcp,
                monto, cotizacion, a.mto_equ_local,
                a.mto_cargo1, a.mto_cargo2, a.mto_cargo3,
                a.mto_contra1, mto_contra2, mto_contra3, mto_contra4,
                cta_ref_contra3, cta_ref_contra4,
                decode(nvl(a.cod_persona,'xx'),'xx',a.concepto,substr(b.nom_completo,1,35)),
                a.cod_persona, substr(a.nro_documento,1,15),
                a.cod_moneda, a.cod_tra_cargo1, a.cod_tra_cargo2, a.cod_tra_cargo3,
                A.nro_cuenta, to_number(nro_cta_bancaria), nro_cheque, e.cod_modalidad,
                a.cta_referencia, e.descripcion, a.mto_contra5, a.cod_retencion,trim(a.usu_insercion)
           into v_cod_tip_operacion, v_cod_ope_bcp,
                v_importe, v_cotizacion, v_equivalente,
                v_mto_cargo1, v_mto_cargo2, v_mto_cargo3,
                v_efectivo, v_cheque, v_mto_cta_cliente, v_mto_cta_contable,
                v_cta_cliente, v_cta_contable,
                v_nombre, v_cod_persona, v_nro_documento,
                v_cod_moneda, v_cod_tra_cargo1, v_cod_tra_cargo2, v_cod_tra_cargo3,
                v_cta_cambios, v_cod_banco, v_nro_cheque, v_cod_mad_operacion,
                v_cta_referencia, v_des_operacion, v_che_ntro_bco, v_cod_ret_pendiente,v_usu_ins_mesa
           from lc_tip_operaciones e, ba_monedas c, ba_personas b, lc_ope_pendientes a
          where nro_operacion = p_nro_ope_pendiente
            and b.cod_persona(+) = a.cod_persona
            and c.cod_moneda = a.cod_moneda
            and e.cod_tip_operacion = a.cod_tip_operacion
            and e.cod_tip_operacion <> 27 --venta de cheque se retoma x gf
            and (e.caja = 'S' or a.mto_contra1 > 0 or a.mto_contra2 > 0 or a.mto_contra5 >0)
            and (nvl(a.mto_contra2,0) = 0 or --pago cheque gcia se detalla x gf,pero pago si se retoma aca
                (nvl(a.mto_contra2,0) > 0 and e.cod_modalidad =72))
            and a.liquidado = 'N'
            and (a.cod_tip_operacion not in (30,16) or --compra/venta d cta si posee algo para pasar x caja
                (a.cod_tip_operacion in (30,16) and (a.mto_contra2 >0 or a.mto_contra2>0 or a.mto_contra1>0 or a.mto_contra5>0)));
         --determina el tipo de mvto
         if v_cod_mad_operacion = 71 then
            v_tipo := 'D';
         else
            v_tipo := 'C';
         end if;
         v_redondeo_ml := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',7,v_cod_mad_operacion,v_mon_local);
      exception
         when too_many_rows then
            v_cod_respuesta := '001'; -- error
            v_msj_respuesta := 'ERROR: Varias Operaciones Pendientes';
         when no_data_found then
            v_cod_respuesta := '002'; -- error
            v_msj_respuesta := 'ERROR: No existe la Operacion Pendiente '||p_nro_ope_pendiente;
      end;
   end if;

   if v_cod_respuesta = '000' then
      -- Obtengo los datos de la caja x moneda local------------------
      prj_obt_datos_caja(p_nro_caja,
                       pag_gen.fu_obt_mon_local,
                       v_cod_oficina,
                       v_fec_caja,
                       v_estado,
                       v_sal_actual,
                       v_sal_cheques);
      if v_estado = -1 then
         v_cod_respuesta := '006'; -- error, no existe registro de caja
         v_msj_respuesta := 'Caja inexistente!!';
      elsif v_estado in (0,2) then
         v_cod_respuesta := '007'; -- error
         v_msj_respuesta := 'Caja no esta habilitada para esta Operacion en '||pag_gen.fu_obt_mon_local;
      elsif v_fec_caja <> v_fec_actual then
         v_cod_respuesta := '008'; -- error
         v_msj_respuesta := 'Caja no fue habilitada el dia de hoy';
      end if;
   end if;
   if v_cod_respuesta = '000' then
      -- Obtengo los datos de la caja en la moneda de la operacion----------
      prj_obt_datos_caja(p_nro_caja,
                       v_cod_moneda,
                       v_cod_oficina,
                       v_fec_caja,
                       v_estado,
                       v_sal_actual,
                       v_sal_cheques);
      if v_estado = -1 then
         v_cod_respuesta := '009'; -- error, no existe registro de caja
         v_msj_respuesta := 'Caja inexistente!!';
      elsif v_estado in (0,2) then
         v_cod_respuesta := '010'; -- error
         v_msj_respuesta := 'Caja no esta habilitada para esta Operacion en '||v_cod_moneda;
      elsif v_fec_caja <> v_fec_actual then
         v_cod_respuesta := '011'; -- error
         v_msj_respuesta := 'Caja no fue habilitada el dia de hoy';
      end if;
   end if;

   if v_cod_respuesta = '000' then
      --recuperar los datos de la operacion
      begin
         select afe_posicion, afe_limite, afe_che_viajero,
                caja, tip_valor, cod_mod_origen,
                cod_transaccion, cod_mad_hijo, afe_cod_transaccion,
                cod_tra_cargo1, cod_tra_cargo2, cod_tra_cargo3,
                tip_aplicacion, cod_rubro, cod_tip_referencia
           into v_afe_posicion, v_afe_limite, v_afe_che_viajero,
                v_caja, v_tip_valor, v_cod_mod_origen,
                v_cod_tra_operacion, v_cod_mad_hijo, v_afe_cod_transaccion,
                v_cod_tra_cargo1, v_cod_tra_cargo2, v_cod_tra_cargo3,
                v_tip_aplicacion, v_cod_rubro, v_cod_tip_referencia
           from lc_tip_ope_oficinas b, lc_tip_operaciones a
          where b.cod_tip_operacion = a.cod_tip_operacion
            and b.cod_moneda = v_cod_moneda
            and b.cod_oficina = v_cod_oficina
            and a.cod_tip_operacion = v_cod_tip_operacion
            and nivel = 1
            and cod_modalidad in (71,72);
      exception
         when too_many_rows then
            v_cod_respuesta := '001'; -- error
            v_msj_respuesta := 'ERROR: Varios registros encontrados para la operacion '||'v_cod_tip_operacion'||' en Moneda '||v_cod_moneda;
         when no_data_found then
            v_cod_respuesta := '012';
            v_msj_respuesta := 'Tipo de Operacion no valido.';
      end;
   end if;
   
   ---Verifica Monto Superior USD (Solo Clientes - Venta Efectivo)
   if v_cod_persona is not null and v_cod_tip_operacion = 26 then
     --Valida el monto y tipo de Persona
      if fuj_val_mto_max_efe_cam(v_cod_persona,
                                 pal_cam.FU_CON_MON_A_MONEDA(v_cod_moneda,pag_gen.fu_obt_mon_fuerte, v_importe, v_cotizacion )
                                 ) = 'N' then
         v_cod_respuesta := '003'; -- error
         v_msj_respuesta := '! Operacion Supera Monto Efectivo, debe ser ingresada como Depósito en Cta.';
      end if;
   end if;


         --///se puede modificar el monto de la operacion al incluir el impuesto x transf en la compra////
         --verificar si afecta cta cliente y se puede realizar la operacion
         if v_cod_respuesta = '000' then
              --wa:16/12/2013 Mensaje de Error sino se cargò la Cta
                if v_cta_cliente is  null and nvl(v_mto_cta_cliente,0) >0 then
                    v_cod_respuesta := '087';
                    v_msj_respuesta := 'Cuenta no especificado';
                end if;


            IF v_tip_aplicacion = 'C' THEN --AFECTA CLIENTE

               if v_cod_mad_operacion = 71 then --compra
                  --ver si hay transferencia entre cuentas, se debe cobrar impuesto
                   if v_cta_cliente is not null and nvl(v_mto_cta_cliente,0) >0 then
                     prg_ver_cob_cargos(v_cta_referencia,--cuenta de debito en la compra
                                 v_cta_cliente,--cta credito
                                 7, 71,
                                 v_cod_oficina,
                                 v_cod_moneda,
                                 v_importe,
                                 'Cambios. Compra '||v_cta_referencia,
                                 p_nro_ope_pendiente,
                                 v_fec_actual,
                                 v_hora,
                                 v_imp_transferencia,
                                 v_nro_secuencia,
                                 'N');--procesar
                     --se suma el impuesto al importe de la operacion
                     if v_imp_transferencia > 0 then
                        v_importe := v_importe + nvl(v_imp_transferencia,0);
                        v_equivalente := v_equivalente + round(v_imp_transferencia * v_cotizacion,v_redondeo_ml);
                        v_imp_transf_equ := round(v_imp_transferencia * v_cotizacion,v_redondeo_ml);
                        --setear estado a pendiente
                        v_est_mvto       := 'P';
                        v_est_mvto_resto := 'P';
                     end if;
                  end if;
               else --venta
                  --ver si hay transferencia entre cuentas, se debe cobrar impuesto
                   if v_cta_cliente is not null and nvl(v_mto_cta_cliente,0) >0 then
                     prg_ver_cob_cargos(v_cta_cliente,--cuenta de debito en la compra
                                 v_cta_referencia,--cta credito
                                 7, 72,
                                 v_cod_oficina,
                                 v_mon_local,
                                 v_mto_cta_cliente,
                                 'Cambios. Venta '||v_cta_referencia,
                                 p_nro_ope_pendiente,
                                 v_fec_actual,
                                 v_hora,
                                 v_imp_transferencia,
                                 v_nro_secuencia,
                                 'N');--procesar
                     --se suma el impuesto al importe de la operacion
                     if v_imp_transferencia > 0 then
                        --setear estado a pendiente
                        v_est_mvto       := 'P';
                        v_est_mvto_resto := 'P';
                     end if;
                  end if;
               end if;
               --Verifica la Operacion, credito/debito en cuenta

               pag_cta.pr_ver_operacion(v_cta_referencia,
                                     v_cod_tra_operacion,
                                     7,        -- cod_mod_padre
                                     v_cod_mad_operacion,     -- cod_mod_hijo
                                     v_tipo,                          -- Tipo Credito
                                     v_cod_moneda,   -- Moneda de la Cta. de Debito(Moneda de la Oper.)
                                     v_importe,
                                     v_cod_oficina,        -- cod_ofi_origen
                                     v_cod_mod_cuenta,
                                     v_cod_mad_cuenta,
                                     v_est_cuenta,    -- toma el estado de la cuenta,estado nuevo
                                     v_sal_disp_cuenta,-- sal_disponible
                                     v_procesa);      -- procesa (s/n              -- procesa (s/n)
               if v_procesa = 'N' then
                  v_cod_respuesta := '016';
                  v_msj_respuesta := pag_cta.fu_obt_cod_error()||' - '|| pag_cta.fu_obt_msj_error();
               end if;
            end if;--afecta cta
         end if;

         if v_cod_respuesta = '000' then
            --controles basicos
            if nvl(v_importe,0) <= 0 or nvl(v_cotizacion,0) <= 0 or nvl(v_equivalente,0) <= 0 or
               nvl(v_efectivo,0) < 0 or nvl(v_cheque,0) < 0 or nvl(v_mto_cta_cliente,0) < 0 or
               nvl(v_mto_cta_contable,0) < 0 or nvl(v_mto_cargo1,0) < 0 or
               nvl(v_mto_cargo2,0) < 0 or nvl(v_mto_cargo3,0) < 0 or nvl(v_che_ntro_bco,0) < 0 then
               v_cod_respuesta := '003'; -- error
               v_msj_respuesta := 'ERROR: Datos inconsistentes en la Operacion '||p_nro_ope_pendiente;
            end if;
            if v_cod_respuesta = '000' then
               --obtener margen de modificacion del equivalente
               v_margen := fug_obt_pardinamico('MAR_MON_LOCAL');
               --verificar el equivalente,redondeado xq en la pendiente se redondea
               if round((v_importe * v_cotizacion),v_redondeo_ml) > (v_equivalente + NVL(v_margen,0))
               or round((v_importe * v_cotizacion),v_redondeo_ml) < (v_equivalente - NVL(v_margen,0)) then
                  v_cod_respuesta := '004'; -- error
                  v_msj_respuesta := 'ERROR: Importe equivalente debe encontrase en el rango '
                                      ||TO_CHAR(round((v_importe * v_cotizacion),v_redondeo_ml) + NVL(v_margen,0)) ||'...'
                                      ||TO_CHAR(round((v_importe * v_cotizacion),v_redondeo_ml) - NVL(v_margen,0));
               end if;

               /*if round((v_importe * v_cotizacion),0) <> v_equivalente then
                  v_cod_respuesta := '004'; -- error
                  v_msj_respuesta := 'ERROR: Calculo del Equivalente mal grabado '||p_nro_ope_pendiente;
               end if;*/
            end if;
            if v_cod_respuesta = '000' then
               --si es compra se restan los cargos, si es venta se suman
               if v_cod_mad_operacion = 71 then
                  v_total := v_equivalente - (nvl(v_mto_cargo1,0) + nvl(v_mto_cargo2,0) + nvl(v_mto_cargo3,0));
               elsif v_cod_mad_operacion = 72 then
                  v_total := v_equivalente + (nvl(v_mto_cargo1,0) + nvl(v_mto_cargo2,0) + nvl(v_mto_cargo3,0));
               end if;
               --total = suma de formas de pago/ cobro
               if nvl(v_efectivo,0) + nvl(v_cheque,0) + nvl(v_mto_cta_cliente,0)
                + nvl(v_mto_cta_contable,0) + nvl(v_che_ntro_bco,0) <> (v_total - nvl(v_imp_transf_equ,0)) then
                   v_cod_respuesta := '005'; -- error
                   if v_cod_mad_operacion = 71 then
                      v_msj_respuesta := 'ERROR: Total no coincide con el detalle de forma de pago '||v_total||'*'||V_IMPORTE||'*'||V_EQUIVALENTE;
                   else
                      v_msj_respuesta := 'ERROR: Total no coincide con el detalle de forma de cobro ';
                   end if;
               end if;
               --si es compra no debe tener montos en cheque
               if v_cod_mad_operacion = 71 then
                  if  nvl(v_cheque,0) > 0 or nvl(v_che_ntro_bco,0) > 0 then
                    v_cod_respuesta := '016';
                    v_msj_respuesta := 'ERROR: La Operacion no permite monto en cheque';
                  end if;
               end if;
            end if;
         end if;

         --recupera las tasas de los cargos para los movimientos
         if v_cod_respuesta = '000' then
            --cargo 1
            if v_cod_tra_cargo1 is not null and v_mto_cargo1 is not null then
               begin
                  --si la cta de cambios no es la bolsa y no tiene persona identificada, llamar x nro cuenta, sino x persona
                  if v_cta_cambios <> fug_obt_pardinamico('CTA_CAM_CLI_TEMPORAL',NULL,NULL,NULL,v_cod_oficina)
                   or v_cod_persona is null then
                      pal_cam.pr_obt_cargos(v_cod_tra_cargo1, v_cod_mad_operacion, v_cod_moneda,
                         v_importe, v_equivalente, v_cod_oficina, v_cta_cambios, null,
                         v_des_cargo, v_mto_cargo, v_cod_tasa1, v_val_tasa1);
                  elsif v_cod_persona is not null then
                      pal_cam.pr_obt_cargos(v_cod_tra_cargo1, v_cod_mad_operacion, v_cod_moneda,
                         v_importe, v_equivalente, v_cod_oficina, null, v_cod_persona,
                         v_des_cargo, v_mto_cargo, v_cod_tasa1, v_val_tasa1);
                  end if;
               exception
                  when others then
                     v_cod_respuesta := '013';
                     v_msj_respuesta := 'Error Cargos1 '||substr(sqlerrm,1,400);
               end;
            end if;
            if v_cod_respuesta = '000' then
               --cargo 2
               if v_cod_tra_cargo2 is not null and v_mto_cargo2 is not null then
                  begin
                      --si la cta de cambios no es la bolsa y no tiene persona identificada, llamar x nro cuenta, sino x persona
                      if v_cta_cambios <> fug_obt_pardinamico('CTA_CAM_CLI_TEMPORAL',NULL,NULL,NULL,v_cod_oficina)
                       or v_cod_persona is null then

                         pal_cam.pr_obt_cargos(v_cod_tra_cargo2, v_cod_mad_operacion, v_cod_moneda,
                            v_importe, v_equivalente, v_cod_oficina, v_cta_cambios, null,
                            v_des_cargo, v_mto_cargo, v_cod_tasa2, v_val_tasa2);
                      elsif v_cod_persona is not null then
                         pal_cam.pr_obt_cargos(v_cod_tra_cargo1, v_cod_mad_operacion, v_cod_moneda,
                           v_importe, v_equivalente, v_cod_oficina, null, v_cod_persona,
                           v_des_cargo, v_mto_cargo, v_cod_tasa1, v_val_tasa1);
                      end if;
                  exception
                     when others then
                        v_cod_respuesta := '014';
                        v_msj_respuesta := 'Error Cargos2 '||substr(sqlerrm,1,400);
                  end;
               end if;
            end if;
            if v_cod_respuesta = '000' then
               --cargo 3
               if v_cod_tra_cargo3 is not null and v_mto_cargo3 is not null then
                  begin
                      --si la cta de cambios no es la bolsa y no tiene persona identificada, llamar x nro cuenta, sino x persona
                      if v_cta_cambios <> fug_obt_pardinamico('CTA_CAM_CLI_TEMPORAL',NULL,NULL,NULL,v_cod_oficina)
                       or v_cod_persona is null then
                         pal_cam.pr_obt_cargos(v_cod_tra_cargo3, v_cod_mad_operacion, v_cod_moneda,
                            v_importe, v_equivalente, v_cod_oficina, v_cta_cambios, null,
                            v_des_cargo, v_mto_cargo, v_cod_tasa3, v_val_tasa3);
                      elsif v_cod_persona is not null then
                         pal_cam.pr_obt_cargos(v_cod_tra_cargo1, v_cod_mad_operacion, v_cod_moneda,
                                           v_importe, v_equivalente, v_cod_oficina, null, v_cod_persona,
                                           v_des_cargo, v_mto_cargo, v_cod_tasa1, v_val_tasa1);
                      end if;
                  exception
                     when others then
                        v_cod_respuesta := '015';
                        v_msj_respuesta := 'Error Cargos3 '||substr(sqlerrm,1,400);
                  end;
               end if;
            end if;
         end if;

         if v_cod_respuesta = '000' then
            -- Inicializacion de la aplicacion y el modulo
            BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=v_cod_modulo; END;
            --asigno nro_referencia, se utiliza secuencia para evitar bloqueos
            v_nro_referencia:=fue_obt_sig_secuencia('S_NRO_REF_'||lpad(v_cod_tip_referencia,3,0)||'');
         end if;

         --verifica si debe pedir autorizacion x cotizacion fuera de rango
         if v_cod_respuesta = '000' then
            if v_cod_mad_operacion = 71 then --compra
               v_cot_vigente := pal_cam.FU_OBT_COT_COMPRA(v_cod_moneda);
            elsif v_cod_mad_operacion = 72 then --venta
               v_cot_vigente := pal_cam.FU_OBT_COT_VENTA(v_cod_moneda);
            else
               v_cod_respuesta := '013';
               v_msj_respuesta := 'Modalidad '||v_cod_mad_operacion||' no permitida.';
            end if;
         end if;
   --wa:04/07/2014 Se valida para que si es Compra Cheque C/O/Bcos.
   -- se valide que el Nro no quede en 999--Al Grabar
      if v_cod_respuesta = '000' then
         if v_cod_tip_operacion = 18 then
              if nvl(p_nro_cheque,v_nro_cheque) = '999' then
                 v_cod_respuesta := '028'; -- error, no existe registro de caja
                 v_msj_respuesta := 'ERROR: Nro.Cheque No puede ser.: '||nvl(p_nro_cheque,v_nro_cheque);
              end if;
         end if;
      end if;

         --wa:05/09/2013 se levanta por la implemtación de Cuenta Limite de Cambios

         if v_cod_respuesta = '000' then
            --wa:18/09/2013 Se verifica puntos acorde al que cargó la operación en Mesa
            --ya que el cajero solo recupera y liquida
            v_rango :=FUG_OBT_PUN_COTIZACION(v_usu_ins_mesa/*v_cod_usuario*/,v_cod_moneda,v_cod_oficina,v_cod_mad_operacion);
           if v_cotizacion > (nvl(v_cot_vigente,0) + nvl(v_rango,0)) or
               v_cotizacion < (nvl(v_cot_vigente,0) - nvl(v_rango,0)) then
                v_aut_cotizacion := 'S';
                v_est_mvto := 'X';
                v_msj :='Necesita autorizacion por cotizacion '||to_char(v_cotizacion)||' fuera de rango. Sobre la cotiz. base de '
                         ||v_cot_vigente||'. '||v_des_operacion||' Nro. '||p_nro_ope_pendiente||'. ';
            end if;
         end if;

         --verifica si debe pedir autorizacion por sobrepasar limite
         if v_cod_respuesta = '000' then
            --recuperar datos de la cta de cambios
            pag_cta.pr_obt_cuenta(v_cta_cambios);
            v_est_cta_cambios := pag_cta.g_ctas.estado;
            v_cod_ofi_cta_cambios := pag_cta.g_ctas.cod_oficina;
            if pag_cta.fu_obt_cod_error() <> 0 then
               v_cod_respuesta := '014';
               v_msj_respuesta := 'Recup.Cta.Cambios '||v_cta_cambios||'-'||pag_cta.fu_obt_msj_error();
            end if;
            if v_cod_respuesta = '000' then
               --solo si afecta limite
               if v_afe_limite <> 'S' THEN
                  v_lim_utilizado := 0;
                  v_afe_limite:='N';
               else
                  --04/09/2013 WA: Solo debe Afectar si es Cheque Otro Banco
                  --Si hay cheques o es Compra y esta parametrizado
                  --o es Vta Otras Transferencias (134)
                  if nvl(v_cheque,0)> 0 or v_cod_mad_operacion=71 or
                     (v_cod_mad_operacion=72 and v_cod_tip_operacion= 135) then
                    --Solo si es Compra Cheque Cargo Otros Bancos puede ser EUR/USD
                    --sino siempre es en GS.
                    if v_cod_mad_operacion=71 or (v_cod_mad_operacion=72 and v_cod_tip_operacion= 135) then
                      v_cod_moneda_lim:=v_cod_moneda ;
                      v_mto_lim:=  v_importe;
                    elsif v_cod_mad_operacion=72 and v_cod_moneda <> v_mon_fuerte
                       and nvl(v_cheque,0) > 0 then
                      --WA:16/12/2013 Para Otras Monedas, si paga cheque
                       v_mto_lim:=  v_importe;
                       v_cod_moneda_lim:=v_cod_moneda;
                    else
                       v_mto_lim:=  v_cheque;
                       v_cod_moneda_lim:=v_mon_local;
                    end if;
                    --si moneda de la operacion diferente al limite convertir
                    if v_cod_moneda_lim= v_mon_local then
                       v_lim_utilizado:=round(v_mto_lim/v_cotizacion);
                    elsif v_cod_moneda_lim <> v_mon_fuerte then
                      --v_lim_utilizado:=pal_cam.FU_CON_MON_A_MONEDA(v_cod_moneda,v_mon_fuerte,v_importe,v_cotizacion);
                      v_lim_utilizado:=pal_cam.FU_CON_MON_A_MONEDA(v_cod_moneda_lim,v_mon_fuerte,v_mto_lim,v_cotizacion);
                    else
                      v_lim_utilizado:= v_mto_lim;
                    end if;
                  else
                     --Sino hay cheque otro banco no hay riesgo.
                     v_afe_limite:='N';
                     v_lim_utilizado := 0;
                     --Cambiamos a que no afecta
                  end if;
                 --wa:05/09/2013 se levanta por la implemtación de Cuenta Limite de Cambios

                 if nvl(pag_cta.g_ctas.sal_disponible,0) - v_lim_utilizado < 0 then --si se va a neg supero el limite
                     v_aut_limite := 'S';
                     v_msj_limite := v_msj_limite || 'Necesita autorizacion por superar el limite de '||pag_cta.g_ctas.sal_total||' '
                              ||v_mon_fuerte||' de la cta. de cambios '||v_cta_cambios||'. '||v_des_operacion||' Nro. '
                              ||p_nro_ope_pendiente||' de '||v_mto_lim||' '||v_cod_moneda||'.';
                  end if;

               end if;
            end if;
         end if;

         --> Verificar si necesita autorizacion por superar monto permitido de operaciones de cambios en el día.-
         If v_cod_respuesta = '000' Then
           if v_cod_moneda != v_mon_fuerte then
             v_monto := pal_cam.FU_CON_MON_A_MONEDA(V_COD_MONEDA, V_MON_FUERTE, V_IMPORTE, V_COTIZACION);
           else
             v_monto := V_IMPORTE;
           end if;
           if v_monto > fug_obt_mto_maximo(USER, V_MON_FUERTE,7) then
             v_aut_monto := 'S';
             v_est_mvto  := 'X';
             v_msj_monto := v_msj_monto||'Necesita autorizacion por superar con USD '||v_monto||' al limite de USD '||fug_obt_mto_maximo(USER, V_MON_FUERTE,7)
                                       ||' establecido al Usuario '||USER||' para operaciones de Cambios en el Día.'||'~'||'!';
            end if;
          End If;

         if v_cod_respuesta = '000' then
            if v_aut_cotizacion ='S' or v_aut_limite ='S' or v_aut_monto = 'S' or v_aut_lim_var = 'S' then
               v_est_mvto_resto :='P';
            end if;
         end if;

           --OBTENER DATOS DEL BCO
         if v_cod_respuesta = '000' then
            if nvl(p_cod_banco,v_cod_banco) <> 0 then--and nvl(p_nro_cheque,v_nro_cheque) <> 0 then
               --determinar si el banco es local o extranjero
               begin
                 select ubicacion, descripcion
                   into v_ubi_banco, v_des_banco
                  from ge_bancos
                  where cod_banco = nvl(p_cod_banco,v_cod_banco)
                    and estado = 'A';
                    --and cod_banco <> fug_obt_cod_banco;  se abre para cheq nstro bco
                  if v_cod_tip_operacion = 18 then --compra de cheque
                     if nvl(p_cod_banco,v_cod_banco) = fug_obt_cod_banco then -- no puede ser nuestro bco
                        v_cod_respuesta := '001'; -- error
                        v_msj_respuesta := 'ERROR: No se puede Comprar Cheque de Nuestro Bco';
                     end if;
                  end if;
               exception
                  when no_data_found then
                    v_cod_respuesta := '001'; -- error
                    v_msj_respuesta := 'ERROR: Codigo de Banco inexistente.';
                  when others then
                    v_cod_respuesta := '001'; -- error
                    v_msj_respuesta := 'ERROR: Codigo de Banco invalido.';
               end;
               if v_cod_tip_operacion = 18 then --compra de cheque
                 if NVL(v_ubi_banco,'L') = 'L' then --si no cargo banco se asume local
                    If p_cod_retencion = 1 Then
                       v_tip_monto             := 'O';--cheque para afectar cj_movimientos
                       v_cod_tra_cheque        := 607;
                    ElsIf p_cod_retencion = 2 Then
                       v_tip_monto             := 'T';--cheque para afectar cj_movimientos
                       v_cod_tra_cheque        := 610;
                    Elsif p_cod_retencion = 3 Then
                       v_tip_monto             := 'S';--cheque para afectar cj_movimientos
                       v_cod_tra_cheque        := 632;
                    else
                       raise_application_error(-20000,'Debe definir una retención válida para el tipo de operación');
                    End IF;
                 else
                    v_tip_monto      := 'X'; --plaza ext.
                    v_cod_tra_cheque := 633;
                 end if;
                 --obtiene retención
                 PAG_CTA.PR_OBT_RETENCION(V_FEC_ACTUAL        ,
                                          NULL                ,
                                          7                   ,
                                          V_COD_MAD_OPERACION ,
                                          V_COD_TRA_CHEQUE    ,
                                          V_COD_MONEDA        ,
                                          V_COD_RETENCION     ,
                                          V_FEC_FIN_RETENCION );

               end if;
            end if;
         end if;

        -- Agregado en fecha 30/10/2013 por MS
        -- CNFLIMVAR-65 --
           BEGIN
              IF v_cod_respuesta = '000' THEN
                  lp_controlar_limites_var();
              END IF;
          --EXCEPTION
          --    WHEN OTHERS THEN
          --        RAISE;
          END;
          --

          --

         --genera movimiento principal //tener en cuenta si es compra o venta
         if v_cod_respuesta = '000' then
           r_gmovi.cod_usuario     := user;
           r_gmovi.hora            := v_hora;
           r_gmovi.fecha           := v_fec_actual;
           r_gmovi.fec_valor       := v_fec_actual;
           r_gmovi.cod_tra_padre   := v_cod_tra_operacion;
           r_gmovi.cod_mod_padre   := 7;
           r_gmovi.cod_mad_padre   := v_cod_mad_operacion;
           r_gmovi.cod_modulo      := 7;
           r_gmovi.cod_modalidad   := v_cod_mad_operacion;
           r_gmovi.cod_oficina     := v_COD_OFICINA;
           r_gmovi.nro_cuenta      := null;
           r_gmovi.cod_rubro       := null;
           --CROEFEBCO-28: Mejoras en la Operativa de Efectivo
       if v_cod_tip_operacion <> 12 Then
              r_gmovi.cod_transaccion := v_cod_tra_operacion;
           Else
              r_gmovi.cod_transaccion := 606;
           End IF;
           r_gmovi.NRO_DOCUMENTO4  := v_cod_transaccion;--transac.de caja para poder autorizar
           r_gmovi.cod_persona     := v_cod_persona;

           IF v_tip_aplicacion in ('C','A') THEN --AFECTA CLIENTE
              --- Recuperar datosde la cuenta en el registro global g_ctas
              pag_cta.pr_obt_cuenta(v_cta_referencia);
              v_est_ant_cta_cliente   := pag_cta.g_ctas.estado;
              r_gmovi.cod_modulo      := v_cod_mod_cuenta;
              r_gmovi.cod_modalidad   := v_cod_mad_cuenta;
              r_gmovi.cod_oficina     := pag_cta.g_ctas.cod_oficina;
              r_gmovi.nro_cuenta      := v_cta_referencia;
              if v_cod_mad_operacion = 71 then
                 r_gmovi.cod_transaccion := 503; --debito cta
              else
                r_gmovi.cod_transaccion  := 602; --credito cta
              end if;
           elsif v_tip_aplicacion in ('B'/*,'A'*/) then --afecta cta.ctable, cta.corresponsal
              r_gmovi.cod_rubro    := v_cta_referencia;
           end if;
           --compra de cheque registra banco y nro cheque
           if v_cod_tip_operacion in (18,28) then --compra de cheque, venta cheque corresponsal
              r_gmovi.NRO_DOCUMENTO3  := nvl(p_nro_cheque,v_nro_cheque);
              r_gmovi.cod_banco       := nvl(p_cod_banco,v_cod_banco);
              if v_cod_tip_operacion = 18 then
                 if NVL(v_ubi_banco,'L') = 'L' then --si no cargo banco se asume local
                    If p_cod_retencion = 1 Then
                       v_tip_monto             := 'O';--cheque para afectar cj_movimientos
                       r_gmovi.cod_transaccion := 607;
                    ElsIf p_cod_retencion = 2 Then
                       v_tip_monto             := 'T';--cheque para afectar cj_movimientos
                       r_gmovi.cod_transaccion := 610;
                    Elsif p_cod_retencion = 3 Then
                       v_tip_monto             := 'S';--cheque para afectar cj_movimientos
                       r_gmovi.cod_transaccion := 632;
                    else
                       raise_application_error(-20000,'Debe definir una retención válida para el tipo de operación');
                    End IF;
                    IF v_tip_monto NOT IN ('Z') THEN --no afecta
                       v_msj_respuesta := fuj_val_importe('D', v_tip_monto, v_cod_moneda, v_importe, 245);
                       IF v_msj_respuesta IS NOT NULL THEN
                          v_cod_respuesta := '005';  -- error
                       END IF;
                    END IF;
                 else
                    v_tip_monto := 'X'; --plaza ext.
                    r_gmovi.cod_transaccion := 633;
                 end if;

                 if v_cod_retencion is null then
                   --obtiene retencion
                   begin
                   pag_cta.PR_OBT_RETENCION(v_fec_actual, null,7,v_cod_mad_operacion,r_gmovi.cod_transaccion,
                                          v_cod_moneda,v_COD_RETENCION, v_FEC_FIN_RETENCION);
                   exception
                      when others then
                         v_tip_retencion := null;
                   end;
                   --WA:Para Cheque Cargo otros que no sean de USD, se aplica logica de formulario
                   if v_cod_tip_operacion in (18)
                      and v_cod_moneda <> v_mon_fuerte
                      and v_tip_retencion is null then
                       begin
                        pag_cta.PR_OBT_RETENCION(v_fec_actual, null,7,v_cod_mad_operacion,r_gmovi.cod_transaccion,
                                          v_cod_moneda,v_COD_RETENCION, v_FEC_FIN_RETENCION);
                       exception
                          when others then
                           v_tip_retencion := null;
                       end;

                   end if;
                   v_tip_retencion := v_cod_retencion;
                 end if;
                 --r_gmovi.cod_retencion     := v_cod_retencion;
                 r_gmovi.cod_retencion     := p_cod_retencion;
                 r_gmovi.fec_fin_retencion := v_fec_fin_retencion;
              end if;
           elsif v_cod_tip_operacion in (11,26,111, 226) then --compra/vta efectivo
              v_tip_monto := 'E'; --efectivo
           ElsIf v_cod_tip_operacion in (12) then --CROEFEBCO-28: Mejoras en la Operativa de Efectivo: Compra de Cheque C/N/B
              v_tip_monto := 'C';
           end if;
           r_gmovi.tip_mov_rubro   := v_tipo; -- D/C
           r_gmovi.nro_caja        := p_nro_caja;
           r_gmovi.NRO_DOCUMENTO2  := v_nro_referencia;
           r_gmovi.COD_REF_CAMBIO  := v_cod_tip_referencia;

           v_nro_secuencia         := v_nro_secuencia + 1;
           r_gmovi.nro_secuencia   := v_nro_secuencia;
           r_gmovi.cod_moneda      := v_cod_moneda;
           r_gmovi.monto           := v_IMPORTE;
           r_gmovi.nro_documento   := p_nro_ope_pendiente;
           r_gmovi.cod_ofi_origen  := v_cod_oficina;
           r_gmovi.emi_aviso       := 'N';
           r_gmovi.concepto        := v_nombre;
           if v_aut_cotizacion = 'S' or nvl(v_aut_monto,'N') = 'S' or v_aut_lim_var = 'S' then
              r_gmovi.estado       := v_est_mvto;
           else
              r_gmovi.estado       := v_est_mvto_resto; --es P si alguno pide aut,sino es N
           end if;
           r_gmovi.reversado       := 'N';
           r_gmovi.cotizacion      := v_cotizacion;
           r_gmovi.mto_equ_local   := v_equivalente; --round(v_IMPORTE * v_COTIZACION,0);
           r_gmovi.cod_bco_central := v_cod_ope_bcp;
           r_gmovi.cod_tip_ope_cambio:= v_cod_tip_operacion;

           -- verifico los decimales del importe y autorizacion -- solo por el credito
           --si es venta se hace x el principal, si es compra se hace x la forma de pago
           if v_cod_mad_operacion = 72 and v_tip_aplicacion <> 'C' then --venta
              if v_tip_monto not in ('Z') then --no afecta
                 v_msj_respuesta := fuj_val_importe(r_gmovi.tip_mov_rubro,v_tip_monto,r_gmovi.cod_moneda,r_gmovi.monto,245);
                 if v_msj_respuesta is not null then
                    v_cod_respuesta := '005';  -- error
                 end if;
              end if;
           end if;

           if v_cod_respuesta = '000' then
              PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi);
              --
              if v_tip_monto not in ('Z') then --no afecta
                 lp_gen_transaccion(r_gmovi.tip_mov_rubro,
                                    v_tip_monto, --  Efectivo / Cheque
                                    r_gmovi.cod_moneda,
                                    r_gmovi.monto,
                                    r_gmovi.nro_secuencia);
              end if;
           end if;
         end if;
         r_gmovi.cod_tip_ope_cambio := null;
         r_gmovi.cod_rubro          := null;
         r_gmovi.nro_cuenta         := null;
         r_gmovi.tip_mov_rubro      := null;
         r_gmovi.cod_banco          := null;
         r_gmovi.nro_documento3     := null;
         r_gmovi.nro_documento2     := null;
         r_gmovi.cod_transaccion    := v_cod_tra_operacion;
         r_gmovi.cod_retencion      := null;
         r_gmovi.fec_fin_retencion  := null;
         v_cod_retencion            := null;
         v_fec_fin_retencion        := null;


         --actualiza la posicion si corresponde
         if v_cod_respuesta = '000' then
           if v_est_mvto_resto = 'N' and v_est_mvto_resto = 'N' then --si no es pendiente ninguno
              PAL_CAM.PR_ACT_POSICIONES(v_cod_tip_operacion,v_cod_moneda,pal_cam.fu_obt_ofi_cambio(v_cod_oficina),
                                  v_importe,v_equivalente /*round(v_IMPORTE * v_COTIZACION,0)*/,v_cod_ope_bcp);
           end if;
         end if;

         --actualizacion de limite, solo si afecta recupera retencion
         if v_cod_respuesta = '000' then
            begin
             --WA:04/09/2013 Solo si hay cheques cargo otro, hay riesgo
             --O si es Compra Cheque Cargo Otros Bancos
            if nvl(v_cheque,0) > 0  or v_cod_mad_operacion=71 then

                select estado, cod_oficina
                  into v_est_cta_cambios, v_cod_ofi_cta_cambios
                  from lc_cta_cambios
                 where nro_cuenta = v_cta_cambios
                   for update of estado nowait;
                update lc_cta_cambios
                   set mto_utilizado = nvl(mto_utilizado,0) + nvl(v_lim_utilizado,0),
                       fec_ult_movimiento = v_fec_actual,
                       estado = decode(estado,'A','N',estado),
                       fec_cam_estado =decode(estado,'A',v_fec_actual,fec_cam_estado)
                 where lc_cta_cambios.nro_cuenta = v_cta_cambios;
                IF v_afe_limite = 'S' THEN --solo si afecta limite
                    --WA:11/09/2013 Si es venta y paga en cheque o es Cpra cheque cargo Otros
                   if v_cod_mad_operacion=71  or nvl(v_cheque,0) > 0 then
                       if nvl(nvl(v_cod_ret_pendiente,p_cod_retencion), 1) = 1 then
                         v_cod_tra_cheque := 607; --- Cheques
                      elsif nvl(nvl(v_cod_ret_pendiente,p_cod_retencion), 1) = 2 then
                         v_cod_tra_cheque := 610; --- Cheques
                      elsif nvl(nvl(v_cod_ret_pendiente,p_cod_retencion), 1) = 3 then
                         v_cod_tra_cheque := 632; --- Cheques
                       end if;
                      --obtiene retencion
                     if v_cod_mad_operacion=71 then
                                --WA:04/09/2013
                                --Verificamos si tiene Retención personalizada por Operación
                                v_dias_ret:= 99;
                                begin
                                  select a.val_maximo
                                    into v_dias_ret
                                    from BA_COD_REFERENCIAS a
                                     where a.dominio like 'CAN_DIA_RET_OPE'
                                     and a.val_minimo= to_number(v_cod_tip_operacion);
                                exception
                                  when no_data_found then
                                     v_dias_ret:=99;
                                  when others then
                                     v_dias_ret:=99;
                                end;
                                  --WA:5/12/2013 Si operación de Compra Otr Transf. O vta Otra Transf
                                  --Se toma la retención que cargò mesa, sino operativ anterior
                                if v_cod_tip_operacion='134' and v_cod_ret_pendiente is not null then
                                      --***** Entra 100 por Cheque, no se buesca personalizada
                                       v_COD_RETENCION:= v_cod_ret_pendiente;
                                       v_FEC_FIN_RETENCION:= pag_cal.fu_obt_fec_fin_ret(pag_cal.fu_obt_fec_actual(7),
                                                                             v_cod_oficina,
                                                                             v_COD_RETENCION);
                                elsif v_dias_ret <> 99 THEN
                                   --Le asigamos lo parametrizado
                                   v_COD_RETENCION:= v_dias_ret;
                                   v_FEC_FIN_RETENCION:= pag_cal.fu_obt_fec_fin_ret(pag_cal.fu_obt_fec_actual(7),
                                                                             v_cod_oficina,
                                                                             v_dias_ret);
                                else
                                  --obtiene retencion -Operativa Normal
                                   pag_cta.PR_OBT_RETENCION(v_fec_actual, null,7,v_cod_mad_operacion,v_cod_tra_cheque,
                                          v_cod_moneda,v_COD_RETENCION, v_FEC_FIN_RETENCION);
                                end if;
                     ELSE
                        --WA:5/12/2013 Si operación de Compra Otr Transf. O vta Otra Transf
                        --Se toma la retención que cargò mesa, sino operativ anterior
                        if v_cod_tip_operacion='135' and v_cod_ret_pendiente is not null then
                            --***** Entra 100 por Cheque, no se buesca personalizada
                             v_COD_RETENCION:= v_cod_ret_pendiente;
                             v_FEC_FIN_RETENCION:= pag_cal.fu_obt_fec_fin_ret(pag_cal.fu_obt_fec_actual(7),
                                                                             v_cod_oficina,
                                                                             v_COD_RETENCION);
                        else
                            --***** Entra 100 por Cheque, no se buesca personalizada
                            pag_cta.pr_obt_retencion(v_fec_actual, null, 7, v_cod_mad_operacion, v_cod_tra_cheque ,
                                     v_mon_local, v_COD_RETENCION, v_FEC_FIN_RETENCION);
                        end if;
                     END IF;
                 end if;
                end if;
             else
               --No hay riesgo, se guarda CERO
               v_lim_utilizado:=0;
             end if;
              --genera movimientos
              v_nro_secuencia         := v_nro_secuencia + 1;
              r_gmovi.nro_secuencia   := v_nro_secuencia;
              r_gmovi.cod_modulo      := 7;
              r_gmovi.cod_modalidad   := 70;
              r_gmovi.cod_oficina     := v_cod_ofi_cta_cambios;
              r_gmovi.cod_moneda      := v_mon_fuerte;
              r_gmovi.cod_transaccion := 760;
              r_gmovi.monto           := v_lim_utilizado;
              r_gmovi.nro_documento   := p_nro_ope_pendiente;
              if v_cod_persona is not null then --persona existente
                 r_gmovi.NRO_DOCUMENTO2  := v_cod_persona;
              else
                --el doc. es varchar2(20) en ba_personas
                 r_gmovi.NRO_DOCUMENTO3  := to_number(v_nro_documento);
              end if;
              r_gmovi.cod_ofi_origen  := v_cod_oficina;
              r_gmovi.emi_aviso       := 'N';
              r_gmovi.concepto        := nvl(v_nombre,'Operacion Cambios Limite');
              if v_afe_limite = 'S' and v_aut_limite = 'S' then
                 r_gmovi.estado       := 'X';
              else
                 r_gmovi.estado       := v_est_mvto_resto;
              end if;
              r_gmovi.reversado       := 'N';
              r_gmovi.cod_rubro       := NULL;
              r_gmovi.nro_cuenta      := v_cta_cambios;
              r_gmovi.tip_mov_rubro   := null;
              --WA:17/12/203 Para dolar se deja normal
              if v_cod_moneda= v_mon_fuerte then
                 v_cot_mon_fuerte:= v_cotizacion;
                 r_gmovi.cotizacion:= v_cotizacion;--cotizacion del limite en la moneda fuerte
              else
                  BEGIN
                       SELECT VAL_CONVERSION
                         INTO v_cot_mon_fuerte
                          FROM GE_COTIZACIONES
                         WHERE COD_MONEDA = v_mon_fuerte
                           AND FECHA <= PAG_CAL.FU_OBT_FEC_ACTUAL(7)
                            AND ROWNUM=1
                           ORDER BY FECHA DESC;
                  EXCEPTION
                   WHEN NO_DATA_FOUND THEN
                     v_cot_mon_fuerte:=0;
                   WHEN OTHERS THEN
                     v_cot_mon_fuerte:=0;
                  END;
                  r_gmovi.cotizacion:= v_cot_mon_fuerte;--cotizacion del limite en la moneda fuerte
              end if;
              --********************************

              r_gmovi.mto_equ_local   := v_equivalente;--round(NVL(v_lim_utilizado,0)* v_cotizacion,v_redondeo_ml);
              r_gmovi.cod_bco_central := v_cod_ope_bcp;
              --r_gmovi.COD_RETENCION   := v_COD_RETENCION;
              r_gmovi.COD_RETENCION   := p_COD_RETENCION;
              r_gmovi.FEC_FIN_RETENCION:= v_FEC_FIN_RETENCION;
              r_gmovi.cod_tip_ope_cambio:= null;
              PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi);
              r_gmovi.NRO_DOCUMENTO3  :=null;
              --movimiento x el cambio de estado de la cuenta si corresponde
              if v_est_cta_cambios = 'A' then
                v_nro_secuencia := v_nro_secuencia + 1;
                r_gmovi.nro_secuencia  := v_nro_secuencia;
                r_gmovi.cod_modulo      := 7;
                r_gmovi.cod_modalidad   := 70;
                r_gmovi.cod_oficina     := v_cod_ofi_cta_cambios;
                r_gmovi.cod_moneda      := v_mon_fuerte;
                r_gmovi.fec_valor       := v_fec_actual;
                r_gmovi.cod_tra_padre   := 401;
                r_gmovi.cod_mod_padre   := 7;
                r_gmovi.cod_mad_padre   := 70;
                r_gmovi.cod_transaccion := 401;
                r_gmovi.monto           := null;
                r_gmovi.nro_documento   := null;
                r_gmovi.NRO_DOCUMENTO2  := null;
                r_gmovi.cod_ofi_origen  := v_cod_oficina;
                r_gmovi.emi_aviso       := 'N';
                r_gmovi.concepto        := 'Cambio de Estado ';
                r_gmovi.estado          := 'N';
                r_gmovi.est_cuenta      := 'N';
                r_gmovi.reversado       := 'N';
                r_gmovi.cod_rubro       := NULL;
                r_gmovi.nro_cuenta      := v_cta_cambios;
                r_gmovi.tip_mov_rubro   := null;
                r_gmovi.cotizacion      := null;
                r_gmovi.mto_equ_local   := null;
                r_gmovi.cod_bco_central := null;
                r_gmovi.COD_RETENCION   := null;
                r_gmovi.FEC_FIN_RETENCION :=null;
                r_gmovi.COD_REF_CAMBIO   := null;
                r_gmovi.cod_tip_ope_cambio := null;
                PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi);
              end if;
            EXCEPTION
              WHEN OTHERS THEN
                v_cod_respuesta := '018';
                v_msj_respuesta := 'Actualiza limite. '||sqlerrm;
            END;
         end if;--limite
         v_cod_retencion := null;
         v_fec_fin_retencion := null;

         r_gmovi.nro_cuenta       := null;
         r_gmovi.est_cuenta       := null;
         r_gmovi.COD_RETENCION    := null;
         r_gmovi.FEC_FIN_RETENCION:= null;
         r_gmovi.cotizacion       := null;
         r_gmovi.mto_equ_local    := null;
         r_gmovi.cod_bco_central  := null;
         r_gmovi.NRO_DOCUMENTO2   := v_nro_referencia;
         r_gmovi.COD_REF_CAMBIO   := v_cod_tip_referencia;
         r_gmovi.cod_modulo       := 7;
         r_gmovi.cod_mod_padre    := 7;
         r_gmovi.cod_modalidad    := v_cod_mad_operacion;
         r_gmovi.cod_oficina      := v_cod_oficina;
         r_gmovi.cod_tra_padre    := v_cod_tra_operacion;
         r_gmovi.cod_mad_padre    := v_cod_mad_operacion;

         -- si necesita autorizacion generar el registro
         if v_cod_respuesta = '000' then
            --> Genera Autorización por Exceder el Límite de la Cuenta de Cambios
            IF v_aut_cotizacion ='S' /*or v_aut_limite ='S'*/ THEN
               --monto se convierte a moneda fuerte
               if v_cod_moneda <> v_mon_fuerte then
                 v_monto:=pal_cam.FU_CON_MON_A_MONEDA(v_cod_moneda,v_mon_fuerte,v_importe,v_cotizacion);--para q busque la correspondiente
               else
                 v_monto:= v_importe;
               end if;
               begin
                 INSERT INTO GE_AUT_PEDIDOS
                   (COD_USU_AUTORIZADOR,
                   FECHA,HORA,COD_USUARIO, MENSAJE,ESTADO,RESPUESTA,mto_mon_fuerte,tip_autorizacion)
                 VALUES
                   (pag_aut.fu_obt_usu_autorizador(v_cod_tra_operacion,7,v_cod_mad_operacion,
                   v_cod_oficina,null),
                   v_fec_actual,v_HORA,v_cod_usuario, v_msj,'S','P',v_monto,'C');
                   --en el trigger se envia mail al autorizador
               exception
                  when others then
                      v_cod_respuesta := '019';
                      v_msj_respuesta := 'Ins.Pedido Aut. '||substr(sqlerrm,1,400);
               end;
            END IF;


             --> Inserta Autorizacion por Superar el Límite de la Cuenta de Cambios.-
             -->wa:19/09/2013 se debe insertar el registro con tipo="L"
            IF v_cod_respuesta = '000' and v_aut_limite = 'S' THEN
               --monto se convierte a moneda fuerte
               if v_cod_moneda <> v_mon_fuerte then
                 --wa:19/09/2013 Se debe enviar solo lo que se retiene(v_mto_lim)
                 v_monto := pal_cam.FU_CON_MON_A_MONEDA(v_cod_moneda,v_mon_fuerte,v_mto_lim/*p_importe*/,V_cotizacion);--para q busque la correspondiente
               else
                 v_monto:= v_mto_lim;--p_importe;
               end if;
               begin
                 INSERT INTO GE_AUT_PEDIDOS (COD_USU_AUTORIZADOR,
                                            FECHA               ,
                                            HORA                ,
                                            COD_USUARIO         ,
                                            MENSAJE             ,
                                            ESTADO              ,
                                            RESPUESTA           ,
                                            MTO_MON_FUERTE      ,
                                            TIP_AUTORIZACION    )
                                      VALUES(pag_aut.fu_obt_usu_autorizador(v_cod_tra_operacion,7,v_cod_mad_operacion,v_cod_oficina,null),
                                            v_fec_actual        ,
                                            v_hora              ,
                                            v_cod_usuario       ,
                                            v_msj_limite        ,
                                            'S'                 ,
                                            'P'                 ,
                                            v_monto             ,
                                            'L'                 );

               exception
                  when others then
                      v_cod_respuesta := '017';
                      v_msj_respuesta := 'Ins.Pedido Aut. '||substr(sqlerrm,1,400);
               end;
            END IF;


         end if;

         --> Genera Autorizacion Por Superar Monto Prestablecido para el Usuario.-
         IF v_cod_respuesta = '000' and v_aut_monto = 'S' THEN
           if v_cod_moneda <> v_mon_fuerte then
             v_monto := pal_cam.FU_CON_MON_A_MONEDA(v_cod_moneda,
                                                    v_mon_fuerte ,
                                                    v_importe    ,
                                                    v_cotizacion);
           else
             v_monto := v_importe;
           end if;
           begin
             INSERT INTO GE_AUT_PEDIDOS (COD_USU_AUTORIZADOR,
                                        FECHA               ,
                                        HORA                ,
                                        COD_USUARIO         ,
                                        MENSAJE             ,
                                        ESTADO              ,
                                        RESPUESTA           ,
                                        MTO_MON_FUERTE      ,
                                        TIP_AUTORIZACION    )
                                  VALUES(pag_aut.fu_obt_usu_autorizador(v_cod_tra_operacion,7,v_cod_mad_operacion,v_cod_oficina,null),
                                        v_fec_actual        ,
                                        v_hora              ,
                                        v_cod_usuario       ,
                                        v_msj_monto         ,
                                        'S'                 ,
                                        'P'                 ,
                                        v_monto             ,
                                        'M'                 );
           exception
              when others then
                  v_cod_respuesta := '019';
                  v_msj_respuesta := 'Ins.Pedido Aut. Monto '||substr(sqlerrm,1,400);
           end;
         end if;

         --> Inserta Autorizacion por Límites VaR.-
         IF v_cod_respuesta = '000' and v_aut_lim_var = 'S' THEN
                --monto se convierte a moneda fuerte
               if v_cod_moneda <> v_mon_fuerte then
                 v_monto := pal_cam.FU_CON_MON_A_MONEDA(v_cod_moneda,v_mon_fuerte,v_monto,v_cotizacion);--para q busque la correspondiente
               else
                 v_monto:= v_importe;
               end if;
               begin
                 INSERT INTO GE_AUT_PEDIDOS (COD_USU_AUTORIZADOR,
                                            FECHA               ,
                                            HORA                ,
                                            COD_USUARIO         ,
                                            MENSAJE             ,
                                            ESTADO              ,
                                            RESPUESTA           ,
                                            MTO_MON_FUERTE      ,
                                            TIP_AUTORIZACION    )
                                      VALUES(pag_aut.fu_obt_usu_autorizador(v_cod_tra_operacion,7,v_cod_mad_operacion,v_cod_oficina,null),
                                            v_fec_actual        ,
                                            v_hora              ,
                                            v_cod_usuario       ,
                                            v_msj_lim_var||' Tipo operación: '||v_cod_tip_operacion||' - Nro. '||p_nro_operacion,
                                            'S'                 ,
                                            'P'                 ,
                                            v_monto             ,
                                            'V'                 ); -- limites var
                   --en el trigger se envia mail al autorizador
               exception
                  when others then
                      v_cod_respuesta := '017';
                      v_msj_respuesta := 'Ins.Pedido Aut. '||substr(sqlerrm,1,400);
               end;
         END IF;

         --gastos
         if v_cod_respuesta = '000' then
            if nvl(v_mto_cargo1,0) > 0 or  nvl(v_mto_cargo2,0) > 0 or nvl(v_mto_cargo3,0)>0 then
                --movimiento x cada uno de los 3 cargos posibles
               for i in 1..3 loop
                  if i =1 THEN    /* Por valor del gasto 1 */
                    v_mov_mto_cargo    := v_mto_cargo1;
                    v_mov_cod_tra_cargo:= v_cod_tra_cargo1;
                    v_mov_cod_tasa     := v_cod_tasa1;
                    v_mov_val_tasa     := v_val_tasa1;
                  elsif i = 2 THEN      /* Por valor del gasto 2 */
                    v_mov_mto_cargo    := v_mto_cargo2;
                    v_mov_cod_tra_cargo:= v_cod_tra_cargo2;
                    v_mov_cod_tasa     := v_cod_tasa2;
                    v_mov_val_tasa     := v_val_tasa2;
                  elsif i = 3  THEN      /* Por valor del gasto 3 */
                    v_mov_mto_cargo    := v_mto_cargo3;
                    v_mov_cod_tra_cargo:= v_cod_tra_cargo3;
                    v_mov_cod_tasa     := v_cod_tasa3;
                    v_mov_val_tasa     := v_val_tasa3;
                  end if;
                 if v_mov_cod_tra_cargo is not null and nvl(v_mov_mto_cargo,0) > 0 then
                     --verificar si tienen impuestos asociados
                     pal_cam.pr_obt_impuestos(v_mov_cod_tra_cargo, v_cod_mad_operacion, v_mov_mto_cargo,
                          v_cod_oficina, v_tra_impuesto, v_impuesto, v_cod_tasa, v_val_tasa);
                     if v_impuesto is not null then
                        --se desglosa el impuesto para los movimientos
                        v_mov_mto_cargo := v_mov_mto_cargo - v_impuesto;
                     end if;
                 end if;
                  if v_mov_cod_tra_cargo is not null and nvl(v_mov_mto_cargo,0) > 0 then
                      -- Aumento la secuencia
                     v_nro_secuencia         := v_nro_secuencia + 1;
                     r_gmovi.nro_secuencia   := v_nro_secuencia;
                     r_gmovi.cod_oficina     := v_cod_oficina;
                     r_gmovi.cod_moneda      := v_mon_local;
                     r_gmovi.cod_transaccion := v_mov_cod_tra_cargo;
                     r_gmovi.monto           := v_mov_mto_cargo;
                     r_gmovi.nro_documento   := p_nro_ope_pendiente;
                     r_gmovi.cod_ofi_origen  := v_cod_oficina;
                     r_gmovi.emi_aviso       := 'N';
                     r_gmovi.concepto        := 'Cargos de Cambios';
                     r_gmovi.estado          := v_est_mvto_resto;
                     r_gmovi.reversado       := 'N';
                     r_gmovi.COD_TASA        := v_mov_cod_tasa;
                     r_gmovi.VAL_TASA        := v_mov_val_tasa;
                     r_gmovi.tip_mov_rubro   := null;
                     r_gmovi.cod_tip_ope_cambio:=null;
                     PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi);
                      -- genero movimiento x el impuesto
                      if v_impuesto is not null then
                       v_nro_secuencia         := v_nro_secuencia + 1;
                       r_gmovi.nro_secuencia   := v_nro_secuencia;
                       r_gmovi.cod_transaccion := v_tra_impuesto;
                       r_gmovi.monto           := v_impuesto;
                       r_gmovi.COD_TASA        := v_cod_tasa;
                       r_gmovi.VAL_TASA        := v_val_tasa;
                       r_gmovi.concepto        := 'Impuesto Cargos de Cambios';
                       PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi);
                     END IF;
                  end if;
              end loop;
               r_gmovi.COD_TASA := NULL;
               r_gmovi.VAL_TASA := NULL;

            end if;
         end if;
         --actualiza saldo de la cuenta cliente (CTA DE ARRIBA)
         if v_cod_respuesta = '000' then
            if v_cod_mad_operacion =71 and v_tip_aplicacion ='C' then
               --si hay impuesto
               if v_imp_transferencia > 0 then
                    prg_ver_cob_cargos(v_cta_referencia,--cuenta de debito en la compra
                       v_cta_cliente,--cta credito
                      7, 71,
                      v_cod_oficina,
                      v_cod_moneda,
                      v_importe - v_imp_transferencia,--para q calcule sobre el original
                      'Cambios. Compra '||v_cta_referencia,
                      p_nro_ope_pendiente,
                      v_fec_actual,
                      v_hora,
                      v_imp_transferencia,
                      v_nro_secuencia,
                      'S',--procesar
                      v_cotizacion,
                      v_est_mvto_resto);
               end if;
               --es compra y se debita de cuenta
               if v_est_mvto = 'N' then
                   --actualiza sal_total,ver 2ult param(autorizacion y fec_ult_movimiento)
                  PAG_CTA.PR_ACT_SAL_CTA(v_cta_referencia,v_cod_mad_cuenta,'D',
                                         v_fec_actual,v_hora,v_importe,0,0,null,'N');
                  if pag_cta.fu_obt_cod_error() <> 0 then
                     v_cod_respuesta := '020';
                     v_msj_respuesta := 'Act.Sal. '||pag_cta.fu_obt_msj_error();
                  end if;
                  --actualiza estado de la cta si corresponde
                  IF ((v_sal_disp_cuenta - v_importe)= 0 and v_est_cuenta ='P') or v_est_cuenta ='I' then
                      if v_est_ant_cta_cliente ='I' then  --ACTUALIZAR ESTADO A 'N'
                         pag_cta.pr_set_variables(v_cod_usuario, v_fec_actual,
                                                v_cod_tra_operacion,
                                                'N',--estado mvto
                                                'N',--reversado
                                                v_nro_secuencia,
                                                'N', -- estado pasa a N
                                                v_cod_oficina,
                                               7,
                                               v_cod_mad_operacion);
                         PAG_CTA.PR_ACT_ESTADO(v_cta_referencia,'N',v_fec_actual,v_hora,null,'S');--procesar
                      ELSE --SI ERA P PASA A 'C'
                        pag_cta.pr_set_variables(v_cod_usuario, v_fec_actual,
                                                 v_cod_tra_operacion,
                                                 'N',--estado mvto
                                                 'N',--reversado
                                                 v_nro_secuencia,
                                                 'C', -- estado pasa a c
                                                 v_cod_oficina,
                                                 7,
                                                 v_cod_mad_operacion);
                        PAG_CTA.PR_ACT_ESTADO(v_cta_referencia,'C',v_fec_actual,v_hora,null,'S');
                      END IF;
                     v_nro_secuencia := v_nro_secuencia + 1;
                      IF PAG_CTA.FU_OBT_COD_ERROR() <> 0 THEN
                        v_cod_respuesta := '021';
                        v_msj_respuesta := 'Act.Sal. '||pag_cta.fu_obt_msj_error();
                      END IF;
                  end if;
               else--si es pendiente bloquea saldo
                   --actualiza sal_total y sal_bloqueado
                  PAG_CTA.PR_ACT_SAL_CTA(v_cta_referencia,v_cod_mad_cuenta,'C',--credito para q sume el bloqueado
                                         v_fec_actual,v_hora,0,0,v_importe,null,'N');
                  if pag_cta.fu_obt_cod_error() <> 0 then
                     v_cod_respuesta := '022';
                     v_msj_respuesta := 'Bloq.Sal. '||pag_cta.fu_obt_msj_error();
                  end if;
               end if;--estado mvto
            elsif v_cod_mad_operacion =72 and v_tip_aplicacion ='C' then  --venta
               --ojo si es P o N actualiza saldo credito, si es X no hace nada (se actualiza en la aprobacion)
               --si es X ver de actualizar en la aprobacion
               IF v_est_mvto ='N' then --si tiene aut.x limite o si es normal
                  --actualiza sal_total,ver 2ult param(autorizacion y fec_ult_movimiento)
                  PAG_CTA.PR_ACT_SAL_CTA(v_cta_referencia,v_cod_mad_cuenta,'C',
                                       v_fec_actual,v_hora,v_importe,0,0,null,'N');
                   IF PAG_CTA.FU_OBT_COD_ERROR() <> 0 THEN
                     v_cod_respuesta := '023';
                     v_msj_respuesta := 'Act.Sal. '||pag_cta.fu_obt_msj_error();
                  END IF;
                  --actualiza estado de la cta si corresponde
                  IF v_est_ant_cta_cliente in ('I','A') THEN
                     --ACTUALIZAR ESTADO A 'N'
                     pag_cta.pr_set_variables(v_cod_usuario, v_fec_actual,
                                                 v_cod_tra_operacion,
                                                 'N',--estado mvto
                                                 'N',--reversado
                                                 v_nro_secuencia,
                                                 'N', -- estado pasa a c
                                                 v_cod_oficina,
                                                 7,
                                                 v_cod_mad_operacion);
                     PAG_CTA.PR_ACT_ESTADO(v_cta_referencia,'N',v_fec_actual,v_hora,null,'S');
                     v_nro_secuencia := v_nro_secuencia + 1;
                     IF PAG_CTA.FU_OBT_COD_ERROR() <> 0 THEN
                        v_cod_respuesta := '024';
                        v_msj_respuesta := 'Act.Est. '||pag_cta.fu_obt_msj_error();
                     END IF;
                  END IF;
               END IF;--estado N
            end if;--compra / venta
         end if;

         --movimientos x las formas de cobro/pago
         if v_cod_respuesta = '000' then
            --compra
            if v_cod_mad_operacion =71 then
               if v_cta_cliente is not null and nvl(v_mto_cta_cliente,0) >0 then
                   --si el movimiento es pendiente en la aprobacion se acredita a la/s cuenta/s
                  --entonces solo genera el movimiento, sino acredita
                  --recuperar datos de la cta de cliente a acreditar
                  pag_cta.pr_obt_cuenta(v_cta_cliente);
                   if v_est_mvto_resto ='P' then
                     --generar movimiento
                     v_nro_secuencia := v_nro_secuencia + 1;
                     r_gmovi.nro_secuencia   := v_nro_secuencia;
                     r_gmovi.cod_modulo      := pag_cta.g_ctas.cod_modulo;
                     r_gmovi.cod_modalidad   := pag_cta.g_ctas.cod_modalidad;
                     r_gmovi.cod_oficina     := pag_cta.g_ctas.cod_oficina;
                     r_gmovi.cod_moneda      := v_mon_local;
                     r_gmovi.fec_valor       := v_fec_actual;
                     r_gmovi.cod_tra_padre   := v_cod_tra_operacion;--:AUXILIAR.SCR_CDTRAN1
                     r_gmovi.cod_mad_padre   := v_cod_mad_operacion;
                     r_gmovi.cod_mod_padre   := 7;
                     r_gmovi.cod_transaccion := 602; --credito cta cliente
                     r_gmovi.monto           := v_mto_cta_cliente;
                     r_gmovi.nro_documento   := p_nro_ope_pendiente;
                     r_gmovi.NRO_DOCUMENTO2  := v_nro_referencia;
                     r_gmovi.cod_ofi_origen  := v_cod_oficina;
                     r_gmovi.emi_aviso       := 'N';
                     r_gmovi.concepto        := 'Operacion de Cambios-Credito Cta';
                     r_gmovi.estado          := 'P';
                     r_gmovi.est_cuenta      := null;
                     r_gmovi.reversado       := 'N';
                     r_gmovi.cod_rubro       := null;
                     r_gmovi.nro_cuenta      := v_cta_cliente;
                     r_gmovi.tip_mov_rubro   := null;
                     r_gmovi.cotizacion      := null; --pago es en moneda local
                     r_gmovi.mto_equ_local   := null;--r_gmovi.monto * v_cotizacion;
                     r_gmovi.cod_tip_ope_cambio := 3;
                     r_gmovi.COD_RETENCION   := null;
                     r_gmovi.FEC_FIN_RETENCION := null;
                     PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi);
                  else
                     -- Actualiza la Cuenta Credito / Destino
                     pag_cta.pr_act_operacion(v_cta_cliente,
                                             v_hora,--HORA
                                             'C',
                                             pag_cta.g_ctas.cod_moneda, --Moneda de la Operacion
                                             v_mto_cta_cliente,
                                             v_cod_tra_operacion,  -- COD_TRA_PADRE (Compra divisas en efectivo)
                                             602,  -- COD_TRA_HIJO CREDITO CUENTA CLIENTE
                                             p_nro_ope_pendiente, --nro_documento
                                             null,       --COTIZACION, los pagos son en moneda local
                                             v_cod_oficina,      --cod_ofi_origen
                                             7,                --cod_mod_padre
                                             v_cod_mad_operacion,--o abmc.modalidad       --cod_mad_padre
                                             null,                       --cod_tasa
                                             null,                       --val_tasa
                                             'Operacion de Cambios-Credito Cta',
                                             'S',                        --emi_aviso
                                             v_nro_secuencia,
                                             v_fec_actual);
                     if pag_cta.fu_obt_cod_error() <> 0 then
                        v_cod_respuesta := '024';
                        v_msj_respuesta := 'Credito. '||pag_cta.fu_obt_msj_error();
                     end if;
                     --actualizar el movimiento con el tip_ope_cambio
                     begin
                        update ge_movimientos
                           set cod_tip_ope_cambio = 3,
                               nro_documento2 = v_nro_referencia,
                               cod_ref_cambio = v_cod_tip_referencia
                         where fecha =v_fec_actual
                           and hora = v_hora
                           and cod_usuario =v_cod_usuario
                           and nro_cuenta = v_cta_cliente
                           and cod_tra_padre = v_cod_tra_operacion
                           and cod_mod_padre = 7
                           and cod_mad_padre = v_cod_mad_operacion
                           and cod_modulo = pag_cta.g_ctas.cod_modulo
                           and cod_modalidad = pag_cta.g_ctas.cod_modalidad
                           and cod_moneda =v_mon_local
                           and monto = v_mto_cta_cliente;
                     exception
                        when others then
                           v_cod_respuesta := '025';
                           v_msj_respuesta := 'Act.Mvto.Credito. '||substr(sqlerrm,1,400);
                     end;
                  end if;
               end if;--cta cliente
            else  --venta -- debito en cuenta
                --ojo aca debe generar movimiento pendiente nomas todavia
               if v_cta_cliente is not null and nvl(v_mto_cta_cliente,0) > 0 then
                  if v_tip_aplicacion ='C' then --afecta cuenta cliente
                     --si hay impuesto
                     if v_imp_transferencia > 0 then
                        prg_ver_cob_cargos(v_cta_cliente,--cta debito
                                 v_cta_referencia,--cuenta de credito en la venta
                                 7, 72,
                                 v_cod_oficina,
                                 v_mon_local,
                                 v_mto_cta_cliente,
                                 'Cambios. Venta '||v_cta_referencia,
                                 p_nro_ope_pendiente,
                                 v_fec_actual,
                                 v_hora,
                                 v_imp_transferencia,
                                 v_nro_secuencia,
                                 'S',--procesar
                                 null,--cotizacion
                                 v_est_mvto_resto);--estado del mov.
                     end if;
                  end if;

                   --si el movimiento es pendiente se retoma en caja ya se debita a la/s cuenta/s
                   --entonces solo genera el movimiento, sino debita
                   if v_est_mvto_resto = 'P' then
                     --Verifica la Operacion
                     pag_cta.pr_ver_operacion(v_cta_cliente,
                                           v_cod_tra_operacion,
                                           7,        -- cod_mod_padre
                                           v_cod_mad_operacion,     -- cod_mod_hijo
                                           v_tipo,                          -- Tipo Credito
                                           v_mon_local,   -- Moneda de la Cta. de Debito(Moneda de la Oper.)
                                           v_mto_cta_cliente + nvl(v_imp_transferencia,0),
                                           v_cod_oficina,        -- cod_ofi_origen
                                           v_cod_mod_cuenta,
                                           v_cod_mad_cuenta,
                                           v_est_cuenta,    -- toma el estado de la cuenta
                                           v_sal_disp_cuenta,-- sal_disponible
                                           v_procesa);      -- procesa (s/n              -- procesa (s/n)
                     if v_procesa = 'N' then
                        v_cod_respuesta := '026';
                        v_msj_respuesta := pag_cta.fu_obt_cod_error()||' - '|| pag_cta.fu_obt_msj_error();
                     end if;
                     if v_cod_respuesta = '000' then
                        --recupera datos de la cuenta cliente a debitar
                        pag_cta.pr_obt_cuenta(v_cta_cliente);
                        --generar movimiento
                        v_nro_secuencia := v_nro_secuencia + 1;
                        r_gmovi.nro_secuencia   := v_nro_secuencia;
                        r_gmovi.cod_modulo      := pag_cta.g_ctas.cod_modulo;
                        r_gmovi.cod_modalidad   := pag_cta.g_ctas.cod_modalidad;
                        r_gmovi.cod_oficina     := pag_cta.g_ctas.cod_oficina;
                        r_gmovi.cod_moneda      := v_mon_local;
                        r_gmovi.fec_valor       := v_fec_actual;
                        r_gmovi.cod_tra_padre   := v_cod_tra_operacion;
                        r_gmovi.cod_mod_padre   := 7;
                        r_gmovi.cod_mad_padre   := v_cod_mad_operacion;
                        r_gmovi.cod_transaccion := 503; --debito cta cliente
                        r_gmovi.monto           := v_mto_cta_cliente + nvl(v_imp_transferencia,0);
                        r_gmovi.nro_documento   := p_nro_ope_pendiente;
                        r_gmovi.NRO_DOCUMENTO2  := v_nro_referencia;
                        r_gmovi.cod_ofi_origen  := v_cod_oficina;
                        r_gmovi.emi_aviso       := 'N';
                        r_gmovi.concepto        := 'Operacion de Cambios-Debito Cta';
                        r_gmovi.estado          := v_est_mvto_resto;
                        r_gmovi.est_cuenta      := null;
                        r_gmovi.reversado       := 'N';
                        r_gmovi.cod_rubro       := null;
                        r_gmovi.nro_cuenta      := v_cta_cliente;
                        r_gmovi.tip_mov_rubro   := null;
                        r_gmovi.cotizacion      := null; --pago es en moneda local
                        r_gmovi.mto_equ_local   := null;--r_gmovi.monto * v_cotizacion;
                        r_gmovi.cod_tip_ope_cambio := 8;
                        r_gmovi.COD_RETENCION   := null;
                        r_gmovi.FEC_FIN_RETENCION := null;
                        PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi);
                        --bloquea el saldo hasta q se confirme en la autorizacion
                        PAG_CTA.PR_ACT_SAL_CTA(v_cta_cliente,pag_cta.g_ctas.cod_modalidad,'C',
                                          v_fec_actual,v_hora,0,0,v_mto_cta_cliente + nvl(v_imp_transferencia,0),null,'N');
                        if pag_cta.fu_obt_cod_error() <> 0 then
                           v_cod_respuesta := '027';
                           v_msj_respuesta := 'Bloq.Sal. '||pag_cta.fu_obt_msj_error();
                        end if;
                     end if;
                  else
                     -- Actualiza la Cuenta Debito / Destino
                     pag_cta.pr_act_operacion(v_cta_cliente,
                                             v_hora,--HORA
                                             'D',
                                             v_mon_local, --Moneda de la Operacion
                                             v_mto_cta_cliente + nvl(v_imp_transferencia,0),
                                             v_cod_tra_operacion,  -- COD_TRA_PADRE (venta divisas en efectivo)
                                             503,  -- COD_TRA_HIJO CREDITO CUENTA CLIENTE
                                             p_nro_ope_pendiente, --nro_documento --antes era en nro_documento2
                                             null,       --COTIZACION, los pagos son en moneda local
                                             v_cod_oficina,      --cod_ofi_origen
                                             7,                --cod_mod_padre
                                             v_cod_mad_operacion,--o abmc.modalidad       --cod_mad_padre
                                             null,                       --cod_tasa
                                             null,                       --val_tasa
                                             'Operacion de Cambios.Deb. Cta',
                                             'S',                        --emi_aviso
                                             v_nro_secuencia,
                                             v_fec_actual);
                     --actualizar el movimiento con el tip_ope_cambio
                     begin
                        update ge_movimientos
                           set cod_tip_ope_cambio = 8,
                               nro_documento2 = v_nro_referencia,
                               cod_ref_cambio = v_cod_tip_referencia
                         where fecha = v_fec_actual
                           and hora = v_hora
                           and cod_usuario = v_cod_usuario
                           and nro_cuenta = v_cta_cliente
                           and cod_tra_padre = v_cod_tra_operacion
                           and cod_mod_padre = 7
                           and cod_mad_padre = v_cod_mad_operacion
                           and cod_modulo = pag_cta.g_ctas.cod_modulo
                           and cod_modalidad = pag_cta.g_ctas.cod_modalidad
                           and cod_moneda = v_mon_local
                           and monto = v_mto_cta_cliente + nvl(v_imp_transferencia,0);
                     exception
                        when others then
                            v_cod_respuesta := '028';
                            v_msj_respuesta := 'Act.Mvto.Deb. '||pag_cta.fu_obt_msj_error();
                     end;
                     --x si da error el package
                      if pag_cta.fu_obt_cod_error() <> 0 then
                         v_cod_respuesta := '029';
                         v_msj_respuesta := 'Act.Sal. '||pag_cta.fu_obt_msj_error();
                      end if;
                  end if;--estado normal
               end if;--cta cliente
            end if;--compra/venta
           r_gmovi.cod_modulo     := 7;
           r_gmovi.cod_modalidad  := v_cod_mad_operacion;
           r_gmovi.cod_oficina    := v_COD_OFICINA;
           r_gmovi.nro_cuenta     := null;
           r_gmovi.est_cuenta     := null;
         end if;

         --pago / cobro contra cuenta contable
         if v_cod_respuesta = '000' then
            if v_cta_contable is not null and nvl(v_mto_cta_contable,0) > 0 then
               v_nro_secuencia := v_nro_secuencia + 1;
               r_gmovi.nro_secuencia   := v_nro_secuencia;
               r_gmovi.cod_modulo      := 7;
               r_gmovi.cod_modalidad   := v_cod_mad_operacion;
               r_gmovi.cod_oficina     := v_cod_oficina;
               r_gmovi.cod_moneda      := v_mon_local;
               r_gmovi.fec_valor       := v_fec_actual;
               r_gmovi.cod_tra_padre   := v_cod_tra_operacion;
               r_gmovi.cod_mod_padre   := 7;
               r_gmovi.cod_mad_padre   := v_cod_mad_operacion;
               if v_cod_mad_operacion =71 then
                  r_gmovi.cod_tip_ope_cambio := 4;
                  r_gmovi.cod_transaccion    := 741; --credito cta contable
                  r_gmovi.tip_mov_rubro      := 'C';
                  r_gmovi.concepto           := 'Operacion de Cambios-Cred. Ctble';
               else
                  r_gmovi.cod_tip_ope_cambio := 9;
                  r_gmovi.cod_transaccion    := 842; --debito cta contable
                  r_gmovi.tip_mov_rubro      := 'D';
                  r_gmovi.concepto           := 'Operacion de Cambios-Deb. Ctble';
               end if;
               r_gmovi.monto           := v_mto_cta_contable;
               r_gmovi.nro_documento   := p_nro_ope_pendiente;
               r_gmovi.NRO_DOCUMENTO2  := v_nro_referencia;
               r_gmovi.cod_ofi_origen  := v_cod_oficina;
               r_gmovi.emi_aviso       := 'N';
               r_gmovi.estado          := v_est_mvto_resto;
               r_gmovi.est_cuenta      := null;
               r_gmovi.reversado       := 'N';
               r_gmovi.cod_rubro       := v_cta_contable;
               r_gmovi.nro_cuenta      := null;
               r_gmovi.cotizacion      := null; --pago es en moneda local
               r_gmovi.mto_equ_local   := null;--r_gmovi.monto * v_cotizacion;
               r_gmovi.COD_RETENCION   := null;
               r_gmovi.FEC_FIN_RETENCION := null;
               PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi);
            elsif v_mto_cta_contable > 0 and v_cta_contable is null then
               v_cod_respuesta := '001';
               v_msj_respuesta := 'Falta Rubro Contable en Operación Pendiente Retomada.';
            end if;--cta cble
         end if;

         --movimiento x el efectivo
         if v_cod_respuesta = '000' then
            if nvl(v_efectivo,0) > 0 then
               v_nro_secuencia         := v_nro_secuencia + 1;
               r_gmovi.nro_secuencia   := v_nro_secuencia;
               r_gmovi.cod_oficina     := v_cod_oficina;
               r_gmovi.cod_moneda      := v_mon_local;
               if v_cod_mad_operacion =71 then
                 r_gmovi.cod_tip_ope_cambio := 1;
                 r_gmovi.cod_transaccion    := 740;
                 v_tip_mov_rubro            := 'C';
               else
                 r_gmovi.cod_tip_ope_cambio := 6;
                 r_gmovi.cod_transaccion    := 840;
                 v_tip_mov_rubro            := 'D';
               end if;
               r_gmovi.monto           := v_efectivo;
               r_gmovi.nro_documento   := p_nro_ope_pendiente;
               r_gmovi.cod_ofi_origen  := v_cod_oficina;
               r_gmovi.emi_aviso       := 'N';
               r_gmovi.concepto        := 'Operacion de Cambios Caja';
               r_gmovi.estado          := v_est_mvto_resto;
               r_gmovi.reversado       := 'N';
               r_gmovi.cod_rubro       := NULL;
               r_gmovi.tip_mov_rubro   := null;
               r_gmovi.cod_tasa        := null;
               r_gmovi.val_tasa        := null;
               r_gmovi.cod_bco_central := v_cod_ope_bcp;

               -- verifico los decimales del importe y autorizacion -- solo por el credito
               --si es venta se hace x el principal, si es compra se hace x la forma de pago
               if v_cod_mad_operacion = 71 then --compra
                 v_msj_respuesta := fuj_val_importe(v_tip_mov_rubro,'E',v_mon_local,r_gmovi.monto,245);
                 if v_msj_respuesta is not null then
                    v_cod_respuesta := '005';  -- error
                 end if;
               end if;

               if v_cod_respuesta = '000' then
                  PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi);
                  lp_gen_transaccion(v_tip_mov_rubro,
                                     'E', -- fijo Efectivo
                                     r_gmovi.cod_moneda,
                                     r_gmovi.monto,
                                     r_gmovi.nro_secuencia);
               end if;
            end if;
         end if;

         --movimiento x pago en cheque si hubiera, otro banco
         if v_cod_respuesta = '000' then
           if nvl(v_cheque,0) > 0 then --si hay monto cheque, otro bco
               v_COD_RETENCION := null;
               v_FEC_FIN_RETENCION:= null;
               v_cod_ret_pendiente := p_cod_retencion;
                --depende del tipo de retencion, la q trajo de la operacion o la q recupero
                if nvl(v_cod_ret_pendiente,1) = 1 then
                   v_cod_tra_cheque := 607; --- Cheques
                   v_tip_monto := 'O';
                elsif v_cod_ret_pendiente = 2 then
                   v_cod_tra_cheque := 610; --- Cheques
                   v_tip_monto := 'T';
                elsif v_cod_ret_pendiente = 3 then
                   v_cod_tra_cheque := 632; --- Cheques
                   v_tip_monto := 'S';
                end if;
               if v_tip_monto not in ('Z') then --no afecta
                   v_msj_respuesta := fuj_val_importe('D',v_tip_monto,v_mon_local,v_cheque,245);
                   if v_msj_respuesta is not null then
                      v_cod_respuesta := '005';  -- error
                   end if;
                end if;     
               --obtiene retencion
               pag_cta.pr_obt_retencion(v_fec_actual, null, 7, v_cod_mad_operacion, v_cod_tra_cheque ,
                                 v_mon_local, v_COD_RETENCION, v_FEC_FIN_RETENCION);

                if pag_cta.fu_obt_cod_error() <> 0 then
                   v_cod_respuesta := '030';
                   v_msj_respuesta := 'Ret.Chq '||pag_cta.fu_obt_msj_error();
                end if;

               v_nro_secuencia := v_nro_secuencia + 1;
               r_gmovi.nro_secuencia   := v_nro_secuencia;
               r_gmovi.cod_oficina     := v_cod_oficina;
               r_gmovi.cod_moneda      := v_mon_local;
               r_gmovi.fec_valor       := v_fec_actual;
               r_gmovi.cod_tra_padre   := v_cod_tra_operacion;
               r_gmovi.cod_mod_padre   := 7;
               r_gmovi.cod_mad_padre   := v_cod_mad_operacion;
               r_gmovi.cod_transaccion := v_cod_tra_cheque; --- Cheques: 607,610,632
               r_gmovi.monto           := v_cheque;
               r_gmovi.nro_documento   := p_nro_ope_pendiente;
               r_gmovi.NRO_DOCUMENTO2  := v_nro_referencia;
               r_gmovi.cod_ofi_origen  := v_cod_oficina;
               r_gmovi.emi_aviso       := 'N';
               r_gmovi.concepto        := 'Operacion de Cambios ';
               r_gmovi.estado          := v_est_mvto_resto;--'J'; --- Pendiente de pasar por caja
               r_gmovi.reversado       := 'N';
               r_gmovi.cod_rubro       := NULL;
               r_gmovi.nro_cuenta      := null;
               r_gmovi.tip_mov_rubro   := null;--o D
               r_gmovi.cotizacion      := null;--v_cotizacion;forma de pago siempre en gs
               r_gmovi.mto_equ_local   := null;--r_gmovi.monto * v_cotizacion;
               --r_gmovi.COD_RETENCION   := v_COD_RETENCION;
               r_gmovi.COD_RETENCION   := p_COD_RETENCION;
               r_gmovi.FEC_FIN_RETENCION  := v_FEC_FIN_RETENCION;
               r_gmovi.cod_tip_ope_cambio := 7;
               PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi);
               lp_gen_transaccion('D',--mvto deb
                                  v_tip_monto, -- cheque
                                  r_gmovi.cod_moneda,
                                  r_gmovi.monto,
                                  r_gmovi.nro_secuencia);

            end if;
         end if;

         --movimiento x pago en cheque si hubiera, nuestro banco
         if v_cod_respuesta = '000' then
           if nvl(v_che_ntro_bco,0) > 0 then --si hay monto cheque, nuestro bco
               v_COD_RETENCION := null;
               v_FEC_FIN_RETENCION:= null;
               --obtiene retencion
               pag_cta.pr_obt_retencion(v_fec_actual, null, 7, v_cod_mad_operacion, 606,
                                 v_mon_local, v_COD_RETENCION, v_FEC_FIN_RETENCION);

                if pag_cta.fu_obt_cod_error() <> 0 then
                   v_cod_respuesta := '030';
                   v_msj_respuesta := 'Ret.Chq.Ntro. '||pag_cta.fu_obt_msj_error();
                end if;

               v_nro_secuencia := v_nro_secuencia + 1;
               r_gmovi.nro_secuencia   := v_nro_secuencia;
               r_gmovi.cod_oficina     := v_cod_oficina;
               r_gmovi.cod_moneda      := v_mon_local;
               r_gmovi.fec_valor       := v_fec_actual;
               r_gmovi.cod_tra_padre   := v_cod_tra_operacion;
               r_gmovi.cod_mod_padre   := 7;
               r_gmovi.cod_mad_padre   := v_cod_mad_operacion;
               r_gmovi.cod_transaccion := 606; --- Cheques
               r_gmovi.monto           := v_che_ntro_bco;
               r_gmovi.nro_documento   := p_nro_ope_pendiente;
               r_gmovi.NRO_DOCUMENTO2  := v_nro_referencia;
               r_gmovi.cod_ofi_origen  := v_cod_oficina;
               r_gmovi.emi_aviso       := 'N';
               r_gmovi.concepto        := 'Operacion de Cambios ';
               r_gmovi.estado          := v_est_mvto_resto;--'J'; --- Pendiente de pasar por caja
               r_gmovi.reversado       := 'N';
               r_gmovi.cod_rubro       := NULL;
               r_gmovi.nro_cuenta      := null;
               r_gmovi.tip_mov_rubro   := null;--o D
               r_gmovi.cotizacion      := null;--v_cotizacion;forma de pago siempre en gs
               r_gmovi.mto_equ_local   := null;--r_gmovi.monto * v_cotizacion;
               --r_gmovi.COD_RETENCION   := v_COD_RETENCION;
               r_gmovi.COD_RETENCION   := p_COD_RETENCION;
               r_gmovi.FEC_FIN_RETENCION  := v_FEC_FIN_RETENCION;
               r_gmovi.cod_tip_ope_cambio := 7;
               PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi);
               lp_gen_transaccion('D',--mvto deb
                                  'C', -- cheque
                                  r_gmovi.cod_moneda,
                                  r_gmovi.monto,
                                  r_gmovi.nro_secuencia);

            end if;
         end if;

         -- se actualiza el movimiento pendiente, para q no se pueda volver a retomar
         if v_cod_respuesta = '000' then
            update lc_ope_pendientes
               set liquidado ='S',
                   cod_usu_liquidacion = v_cod_usuario,
                   fec_liquidacion = to_date(to_char(v_fec_actual,'dd/mm/yyyy')||v_hora,'dd/mm/yyyy hh24:mi:ss')
             where nro_operacion = p_nro_ope_pendiente;
         end if;

         --actualizar los movimientos q no generaron nro de caja, con dicho nro
         if v_cod_respuesta = '000' then
            update ge_movimientos
                set nro_caja = p_nro_caja
              where fecha       = r_gmovi.fecha
               and cod_usuario = r_gmovi.cod_usuario
               and hora        = r_gmovi.hora
               and nro_caja is null;
         end if;


         if v_cod_respuesta = '000' then -- sino hubo problemas, se carga mensaje por defecto
          -- CRO-JM-03/2015: CROGEFIT-3
           begin
             begin
               select a.nro_cuenta
                 into v_cta_formularios
                from ge_cta_clientes a
                 where a.nro_cuenta = v_cta_referencia
                 and   a.relacion = 'P'
                group by a.nro_cuenta;
             exception
               when others then
                v_cta_formularios := null;
             end;
             if v_cta_formularios is null then
                if v_cta_cliente is null then
                  v_cta_formularios := v_cta_cambios;
                else
                  v_cta_formularios := v_cta_cliente;
                end if;
             end if;
           end;
            if v_est_mvto_resto <> 'P' then --normal
               -- veo si se detallo el cheque, sino se debe entrar despues a detallar
               --puede ser compra de cheque, o una venta q se cobra en cheque
               --si cargo en caja banco y cheque, o en la pendiente habia cargado (si es compra cargo en la pendiente)
               if nvl(p_cod_banco,v_cod_banco) <> 0 and nvl(p_nro_cheque,v_nro_cheque) <> 0 then
                  --cheques otros bancos
                   --si es compra se envia el monto de la operacion
                   if v_cod_mad_operacion = 71 then
                      v_mto_cheque := v_importe;
                      If v_cod_tip_operacion = 18 Then
                         v_cod_retencion := p_cod_retencion;
                      Else
                         v_cod_retencion := v_tip_retencion;--de compra
                      End If;
                   else
                      v_mto_cheque := v_cheque;
                   end if;
                   if nvl(p_cod_banco,v_cod_banco) =  fug_obt_cod_banco then --
                      v_cod_respuesta := '001'; -- error
                      v_msj_respuesta := 'ERROR: Banco no puede ser '||nvl(p_cod_banco,v_cod_banco);
                   end if;
                   if v_cod_respuesta = '000' then
                      if v_mto_cheque > 0 then
                         if nvl(p_nro_cheque,v_nro_cheque) > 0 and
                            (nvl(p_cod_banco,v_cod_banco) >= 0 or v_des_banco is not null) then
                             --si el banco es local -> 133
                             if v_ubi_banco = 'L' then
                                if v_cod_retencion >= 1 then--retencion 1 se detalla automaticamente
                                  v_msj_salida := fuj_pro_transaccion_133(p_nro_operacion,
                                                                       p_nro_caja,
                                                                       p_nro_ope_pendiente,
                                                                       v_cod_retencion,
                                                                       nvl(p_cod_banco,v_cod_banco),
                                                                       nvl(p_nro_cheque,v_nro_cheque),
                                                                       v_mto_cheque);
                                  --return (v_msj_salida); -- retorna directamente el mensaje
                                  if v_msj_salida NOT LIKE '%~000~%' THEN
                                     return v_msj_salida;
                                  END IF;
                                end if;
                             else  --si es extranjero -> 134
                                v_msj_salida := fuj_pro_transaccion_134(p_nro_operacion,
                                                                     p_nro_caja,
                                                                     p_nro_ope_pendiente,
                                                                     nvl(p_cod_banco,v_cod_banco),
                                                                     v_des_banco,
                                                                     nvl(p_nro_cheque,v_nro_cheque),
                                                                     v_mto_cheque);
                                --return (v_msj_salida); -- retorna directamente el mensaje
                                if v_msj_salida NOT LIKE '%~000~%' THEN
                                   return v_msj_salida;
                                END IF;
                             end if;
                          else
                             -- no se cargaron los datos del cheque para detallar
                             v_cod_respuesta := '001'; -- error
                             v_msj_respuesta := 'ERROR: Faltan los datos del Cheque';
                          end if;
                      end if;
                   else
                     --salir
                     v_msj_salida := p_nro_operacion||'~'||
                                     v_cod_respuesta||'~'||
                                     v_msj_respuesta;
                   end if;
               end if;
               if v_cod_respuesta = '000' then
                  --cheque ntro banco
                   --solo venta puede tener cheque nuestro bco
                   if nvl(v_che_ntro_bco,0) > 0 and nvl(p_nro_che_ntro,0) > 0 and v_cod_mad_operacion = 72 then
                      --busco la cuenta de cc_chequeras
                      begin
                        select nro_cuenta
                        into v_cta_cheque
                        from cc_chequeras
                        where p_nro_che_ntro between nro_che_inicial and nro_che_final;
                      exception
                        when too_many_rows then
                          v_cod_respuesta := '001'; -- error
                          v_msj_respuesta := 'ERROR: Varios cheques encontrados';
                        when others then
                          v_cod_respuesta := '001'; -- error
                          v_msj_respuesta := 'ERROR: Recuperar Cheque '||sqlerrm;
                      end;
                      if v_cod_respuesta = '000' then
                         -- se detallo el cheque, se procesa el detalle del mismo
                         v_msj_salida := fuj_pro_transaccion_355(p_nro_operacion,
                                                             p_nro_caja,
                                                             p_nro_ope_pendiente,
                                                             p_nro_che_ntro,
                                                             v_cta_cheque, --cuenta
                                                             v_che_ntro_bco,
                                                             null,
                                                             pag_gen.FU_OBT_SIG_SEGUNDO(pag_gen.FU_OBT_SIG_SEGUNDO(v_hora)));
                         if v_msj_salida NOT LIKE '%~000~%' THEN
                           return v_msj_salida;
                         END IF;
                      else
                         --salir
                         v_msj_salida := p_nro_operacion||'~'||
                                         v_cod_respuesta||'~'||
                                         v_msj_respuesta;
                      end if;
                   end if;
               else
                  --salir
                   v_msj_salida := p_nro_operacion||'~'||
                                   v_cod_respuesta||'~'||
                                   v_msj_respuesta;
               end if;
               --imprimir comprobante de operaciones
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
               if v_cod_respuesta = '000' then
                  v_cod_respuesta := 'IMP';
                  --si la operacion es superior tambien debe imprimir la declaracion jurada
--                  if pal_cam.FU_CON_MON_A_MONEDA(v_cod_moneda,v_mon_fuerte,v_importe,v_cotizacion) >= fug_obt_pardinamico('OPE_SUP_MON_FUERTE') then
               -- CRO-JM-03/2015: CROGEFIT-3
                 if fuj_ver_imp_formulario(v_cta_formularios,
                                           nvl(v_cod_persona, fue_obt_cod_persona(v_nro_documento)),
                                           pag_gen.fu_con_mon_a_moneda(v_cod_moneda,                      -- moneda origen
                                                                       pag_gen.fu_obt_mon_fuerte, -- moneda dolar
                                                                       v_importe),            --el equivalente en GS
                                           v_cod_transaccion,
                                           v_mto_calculado) then
                    if v_cli_frecuente = 'N' then -- Solo si no es cliente frecuente imprime.  V.O. 25/11/2009
                     v_msj_respuesta := 'Operacion Confirmada. Comprobante y Decl.Jurada impresos.'||'~'||
                                        fuj_imp_comprobante_245(p_nro_ope_pendiente, v_cod_oficina, p_nro_caja)||
                                        fuj_imp_dec_jurada_40(v_fec_actual, v_hora, user, 1,
                                                              v_mto_calculado, v_cod_transaccion,p_nro_ope_pendiente,
                                                              v_cod_tra_operacion, 7,v_cod_mad_operacion,v_cod_mad_operacion);-- para este caso enviamos más parámetros porque se trata de una operacion pendiente


                         -- CRO-JM-03/2015: CROGEFIT-3 insertamos en la tabla como ya impreso:
                            prj_ins_form_transacciones(v_cta_formularios,
                                               nvl(v_cod_persona, fue_obt_cod_persona(v_nro_documento)),
                                               v_cod_modulo,
                                               v_cod_transaccion,
                                               USER,
                                               v_fec_actual,
                                               v_hora,
                                               pag_gen.fu_obt_mon_fuerte,
                                               pag_gen.fu_con_mon_a_moneda(v_cod_moneda,              -- moneda origen
                                                                           pag_gen.fu_obt_mon_fuerte, -- moneda dolar
                                                                           v_importe),
                                               'S');
                     -- retorno de la rutina de impresion
                     v_msj_salida := p_nro_operacion||'~'||
                                     v_cod_respuesta||'~'||
                                     v_msj_respuesta;
                    else
                      v_msj_respuesta := 'Operacion Confirmada. Comprobante de operacion impreso.'||'~'||
                                        fuj_imp_comprobante_245(p_nro_ope_pendiente, v_cod_oficina, p_nro_caja);
                     -- retorno de la rutina de impresion
                     v_msj_salida := p_nro_operacion||'~'||
                                     v_cod_respuesta||'~'||
                                     v_msj_respuesta;
                     -- CRO-JM-03/2015: CROGEFIT-3 insertamos en la tabla como no impreso aún:
                        prj_ins_form_transacciones(v_cta_formularios,
                                                   nvl(v_cod_persona, fue_obt_cod_persona(v_nro_documento)),
                                                    v_cod_modulo,
                                                    v_cod_transaccion,
                                                    USER,
                                                    v_fec_actual,
                                                    v_hora,
                                                    pag_gen.fu_obt_mon_fuerte,
                                                    pag_gen.fu_con_mon_a_moneda(v_cod_moneda,              -- moneda origen
                                                                                pag_gen.fu_obt_mon_fuerte, -- moneda dolar
                                                                                v_importe),
                                                    'N');
                    end if;
                  else
                     v_msj_respuesta := 'Operacion Confirmada. Comprobante de operacion impreso.'||'~'||
                                        fuj_imp_comprobante_245(p_nro_ope_pendiente, v_cod_oficina, p_nro_caja);
                     -- retorno de la rutina de impresion
                     v_msj_salida := p_nro_operacion||'~'||
                                     v_cod_respuesta||'~'||
                                     v_msj_respuesta;
                      -- CRO-JM-03/2015: CROGEFIT-3 insertamos en la tabla como no impreso aún:
                      prj_ins_form_transacciones(v_cta_formularios,
                                         nvl(v_cod_persona, fue_obt_cod_persona(v_nro_documento)),
                                         v_cod_modulo,
                                         v_cod_transaccion,
                                         USER,
                                         v_fec_actual,
                                         v_hora,
                                         pag_gen.fu_obt_mon_fuerte,
                                         pag_gen.fu_con_mon_a_moneda(v_cod_moneda,              -- moneda origen
                                                                     pag_gen.fu_obt_mon_fuerte, -- moneda dolar
                                                                     v_importe),
                                         'N');
                  end if;
               end if;
            ELSE --pendiente
                   -- CRO-JM-03/2015: CROGEFIT-3 insertamos en la tabla como no impreso aún:
                        prj_ins_form_transacciones(v_cta_formularios,
                                                   nvl(v_cod_persona, fue_obt_cod_persona(v_nro_documento)),
                                                    v_cod_modulo,
                                                    v_cod_transaccion,
                                                    USER,
                                                    v_fec_actual,
                                                    v_hora,
                                                    pag_gen.fu_obt_mon_fuerte,
                                                    pag_gen.fu_con_mon_a_moneda(v_cod_moneda,              -- moneda origen
                                                                                pag_gen.fu_obt_mon_fuerte, -- moneda dolar
                                                                                v_importe),
                                                    'N');
               IF v_aut_lim_var = 'S' THEN
                   v_msj_respuesta := v_msj_lim_var;
               ELSE
                   v_msj_respuesta := 'Operacion confirmada.Requiere Autorizacion';
               END IF;
               v_msj_salida := p_nro_operacion||'~'||
                               v_cod_respuesta||'~'||'!'||
                               nvl(v_msj_respuesta,'Operacion confirmada');
            end if;
         ELSE --ERROR
            v_msj_salida := p_nro_operacion||'~'||
                            v_cod_respuesta||'~'||
                            nvl(v_msj_respuesta,SQLERRM);
         end if;
        return(v_msj_salida);
exception
   when others then
     v_cod_respuesta := '999';
     v_msj_salida := p_nro_operacion||'~'||
                     v_cod_respuesta||'~'||
                     nvl(v_msj_respuesta,SQLERRM);
     return(v_msj_salida);
end;
/
