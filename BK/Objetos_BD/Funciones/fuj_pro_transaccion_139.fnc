CREATE OR REPLACE FUNCTION IT.FUJ_PRO_TRANSACCION_139
 (P_NRO_OPERACION IN VARCHAR2
 ,P_NRO_CAJA IN VARCHAR2
 ,P_NRO_DOCUMENTO IN VARCHAR2
 ,P_NRO_CUENTA IN VARCHAR2
 ,P_EFECTIVO IN NUMBER
 ,P_CHQ_NBCO IN NUMBER
 )
 RETURN VARCHAR2
 IS 
  -- defino por defecto el modulo y modalidad a utilizar
  v_cod_modulo        number(3) := 9;                         -- modulo Caja
  v_cod_modalidad     number(3) := 91;                 -- modalidad Caja
  v_cod_transaccion   number(4) := 139;            -- cod de transaccion
  v_cod_usuario       varchar2(10) := upper(user); --usuario

  -- Datos de la caja
  v_fec_actual        date         := pag_cal.fu_obt_fec_actual(v_cod_modulo); -- fecha de hoy
  v_hor_actual        varchar2(08) := to_char(sysdate,'HH24:MI:SS');   -- Hora actual
  v_cod_oficina       number(3);         -- Codigo de oficina
  v_estado            number(1);         -- estado de la caja
  v_fec_caja          date;              -- fecha de la caja
  v_sal_actual        number(18,2);      -- saldo actual de la caja en efectivo
  v_sal_cheques       number(18,2);      -- saldo actual de la caja en cheques
  v_dia_mora          pr_cta_prestamos.dia_atraso%type;

  -- Datos de salida
  v_msj_salida        varchar2(8000);                          -- mensaje final retornado
  v_cod_respuesta     varchar2(03) := '000';                   -- sin errores
  v_msj_respuesta     varchar2(2000) := 'Operacion Confirmada'; -- sin errores
  v_error             number;

  -- datos de la operacion convertidos
  v_tipo              varchar2(01) := 'D' ;     -- 'C' credito para la caja (egreso) o vice versa
  v_tip_monto         varchar2(01) := 'O';       -- E efectivo / O cheque otros Bcos
  v_nro_secuencia     number(3) := 0;           -- secuencia del mov.

  -- datos que se cargan en la pantalla
  v_mto_cobrado       number(18,2) := nvl(to_number(p_efectivo),0) + nvl(to_number(P_CHQ_NBCO),0); --+ nvl(to_number(p_chq_nbco),0)  ;
  v_mto_chq_obco      number(18,2) := 0;--nvl(to_number(P_CHQ_NBCO),0);
  v_mto_chq_nbco      number(18,2) := nvl(to_number(p_chq_nbco),0);
  v_mto_efectivo      number(18,2) := nvl(to_number(p_efectivo),0);

  --v_mon_local         varchar2(3) := pag_gen.fu_obt_mon_local; -- moneda local
  v_nro_documento     cj_movimientos.nro_documento%type;

  r_gmovi             ge_movimientos%rowtype;
  --v_mod_cobro         number(3) := 6 ; ---- modulo del préstamo
  --v_mad_cobro         number(3);       ---- modalidad del préstamo

  --- para operaciones pendientes
  v_hora                varchar2(8) :=null;  --- para recuperar hora de oper.pendiente
  v_tot_a_cobrar        number(18,2);
  v_tot_cre_cta         number(18,2);
  v_tot_cre_cta_con     number(18,2);
  v_capital             number(18,2);      -- Capital (no se despliega )
  v_moratorio           number(18,2);      -- Mora s/Interés (DESPLIEGA : Mora s/interés )
  v_impuesto            number(18,2);      -- Total impuesto (DESPLIEGA : ley 125/91)
  v_cargos              number(18,2);      -- Total cargo (DESPLIEGA : Cargo + IVA )
  v_car_iva             number(18,2);
  v_iva                 number(18,2);      -- Total cargo IVA  (no desp)
  v_punitorio           number(18,2);      -- Total monto punitorio (DESPLIEGA : Punitorio)

  v_cod_tran_pend       number(4);    --- transaccion operacion pend.(efect 740 - cheq 607)
  v_monto_efectivo      number(18,2) :=0; --- importe pagado operacion pendiente efectivo
  v_monto_cheque        number(18,2) :=0; --- importe pagado operacion pendiente cheque
  v_monto_cheque_n      number(18,2) :=0;
  r_opeven              ov_cta_vencidas%rowtype;
  v_cod_tra_chq_retomada ge_movimientos.cod_transaccion%type;
  v_cod_mon_local        varchar2(4) := pag_gen.fu_obt_mon_local;
  v_mov_existente number := 0;
  v_cod_persona         ba_personas.cod_persona%type;
    /*-- C.D Fase 4 -*/ 
  v_tip_operacion   ge_mov_autorizaciones.tip_operacion%type := 'O';-- Todos Tipos Operacional
  v_est_movimiento  ge_movimientos.estado%type;
  v_nro_pedido		  ge_mov_autorizaciones.nro_pedido%type;
  v_hor_circuito    ge_mov_autorizaciones.hora%type;
  
  
  cursor movimientos is --trae todos los mov.
    select cod_transaccion, monto, nro_documento
      from ge_movimientos
     where cod_tra_padre = v_cod_transaccion
       and fecha         = v_fec_actual
---       and estado        = 'J'
       and hora          = v_hora
       and cod_ofi_origen = v_cod_oficina
       and reversado = 'N';

-- Procedimiento interno para generar movimiento y act. de control de caja
procedure lp_gen_transaccion (p_estado varchar2 ) is -- C.D.Fase 4
  begin
      -- Actualizo el control de caja
     if p_estado <> 'P' then
       update cj_controles
         set tot_che_otr_bco = nvl(tot_che_otr_bco,0) + nvl(v_mto_chq_obco,0),
             sal_che_otr_bco = nvl(sal_che_otr_bco,0) + nvl(v_mto_chq_obco,0),
             tot_che_nue_bco = nvl(tot_che_nue_bco,0) + nvl(v_mto_chq_nbco,0),
             sal_actual = nvl(sal_actual,0) + nvl(v_mto_efectivo,0),
             tot_debitos = nvl(tot_debitos,0) + nvl(v_mto_efectivo,0),
             can_debitos = nvl(can_debitos,0) + decode(v_mto_efectivo,0,0,1),
             estado = 1 -- abierto
       where nro_caja = to_number(p_nro_caja)
         and cod_moneda = r_opeven.cod_moneda
         and fecha = v_fec_caja;
     end if;

       v_nro_secuencia := 0;
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
            nro_documento, monto, tip_monto, tipo, estado)
        values
           (p_nro_cuenta, v_fec_actual, v_hor_actual, v_cod_usuario, v_nro_secuencia,
            v_cod_transaccion,
            v_cod_modulo,
            v_cod_modalidad,
            v_cod_oficina, r_opeven.cod_moneda, to_number(p_nro_caja),
            v_nro_documento, v_mto_efectivo,'E', v_tipo, p_estado);  -- es debito -- C.D.Fase 4
      end if;
      if v_mto_chq_obco > 0 then
        -- genero el movimiento por el deposito en cheques (local - otros bcos )
        if v_cod_tra_chq_retomada = 607 then --24hs
          v_tip_monto := 'O';
        elsif v_cod_tra_chq_retomada = 610 then --48hs
          v_tip_monto := 'T';
        elsif v_cod_tra_chq_retomada = 632 then --72hs
          v_tip_monto := 'S';
        elsif v_cod_tra_chq_retomada = 632 and r_opeven.cod_moneda <> v_cod_mon_local then --72hs
          v_tip_monto := 'X';
        end if;
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
            v_cod_modulo,
            v_cod_modalidad,
            v_cod_oficina, r_opeven.cod_moneda, to_number(p_nro_caja),
            v_nro_documento, v_mto_chq_obco ,v_tip_monto , v_tipo, p_estado); -- es debito -- C.D.Fase 4
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
            v_cod_modulo,
            v_cod_modalidad,
            v_cod_oficina, r_opeven.cod_moneda, to_number(p_nro_caja),
            v_nro_documento, v_mto_chq_nbco ,'C' , v_tipo, p_estado); -- es debito -- C.D.Fase 4
       end if;
  end lp_gen_transaccion;
  
   --Actualización cantidad de impresión-- C.D.Fase 4
  procedure lp_act_can_impresion is

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
  
  
---------------- INICIO DEL PROCESO PRINCIPAL ------------------
Begin
 -- Inicializacion de la aplicacion y el modulo
 Begin PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=v_cod_modulo; End;
 -- Valido la moneda
 if p_nro_cuenta is null then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el Nro. de Cuenta.';
 elsif v_mto_cobrado is null or v_mto_cobrado <= 0 then --efect + cheq(algo debe tener p/pasar x caja)
    v_cod_respuesta := '003'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el importe Pagado.';
 else
    if v_cod_respuesta = '000' then -- sino hubo problemas, veo la caja
       -- obtengo datos de la cuenta  --
       begin
         pav_ove.PR_OBT_DAT_OPE_VENCIDA(p_nro_cuenta,r_opeven);
       exception
        when others then
          v_cod_respuesta := '002';
          v_msj_respuesta := 'ERROR: Al buscar la cuenta '||sqlerrm;
       end;
       if v_cod_respuesta = '000' then
         -- Obtengo los datos de la caja --
          prj_obt_datos_caja(p_nro_caja,
                              r_opeven.cod_moneda,
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
       /** CROCLIJUD-5 **/
    v_cod_persona := FUG_OBT_CLI_PRINCIPAL(p_nro_cuenta);
    If FUG_OBT_INHIBICION(fug_obt_pardinamico('COD_CAU_DEM_JUDICIAL'),v_cod_persona,p_nro_cuenta) Then
      v_cod_respuesta := '004';
      v_msj_respuesta := 'ERROR. Cliente Principal. o Vinc. a la Cuenta con Demanda Judicial.Consulte con el asesor Jurídico';
    End If;
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
      PRJ_OBT_PEND_VENCIDAS(p_nro_cuenta,
            v_fec_actual,
            v_hora,
            v_capital,
            v_moratorio,
            v_impuesto,
            v_cargos,
            v_iva,
            v_punitorio,
            v_tot_cre_cta,
            v_tot_cre_cta_con,
            v_cod_respuesta,
            v_msj_respuesta);

        if to_number(v_cod_respuesta) = 0 then
          v_cod_respuesta :='000';
        end if;
      --recuperar datos del movimiento
      for reg in movimientos loop
         v_mov_existente := v_mov_existente + 1;
         if reg.nro_documento is not null then
           v_nro_documento := reg.nro_documento;
         end if;
         if reg.cod_transaccion = 740 then --efectivo
           v_monto_efectivo := reg.monto;
         elsif reg.cod_transaccion in (607, 610, 632) then --retencion 1,2,3
           v_monto_cheque   := reg.monto;
           v_cod_tra_chq_retomada := reg.cod_transaccion;
         elsif reg.cod_transaccion = 606 then
           v_monto_cheque_n   := reg.monto;
         end if;
      end loop;
      --si no recuperó nada dar error
      if v_mov_existente <= 0 then
        v_cod_respuesta := '066'; -- error
        v_msj_respuesta := 'No encuentra movimiento a retomar o está en otra oficina';
      end if;

      v_tot_a_cobrar:= nvl(v_capital,0) + nvl(v_moratorio,0) +
                       nvl(v_punitorio,0) + nvl(v_impuesto,0) +
                       nvl(v_cargos,0) /*+ nvl(v_iva,0) */;

      if nvl(v_monto_efectivo,0) <> nvl(P_EFECTIVO,0) or
       nvl(v_monto_cheque_n,0)   <> nvl(P_CHQ_NBCO,0) then
         v_cod_respuesta := '010';
         v_msj_respuesta := 'Montos detallados no coinciden con los especificados en operaciones';
      end if;

      v_mto_efectivo := v_monto_efectivo;
      v_mto_chq_nbco := v_monto_cheque_n;
      v_mto_chq_obco := v_monto_cheque;
    else  ---- transaccion 139 normal
       if v_cod_respuesta = '000' Then
         --- Inicializo el numero de documento
         begin
            v_nro_documento := fug_obt_lla_pardinamico('NRO_RECIBO', r_opeven.cod_modulo, r_opeven.cod_modalidad, r_opeven.cod_moneda, v_cod_oficina)+1;
            prg_act_par_dinamico('NRO_RECIBO',r_opeven.cod_modulo, r_opeven.cod_modalidad, r_opeven.cod_moneda, v_cod_oficina, v_nro_documento);
         exception
            when others then
                 if sqlcode <= -20000 then
                    v_cod_respuesta := '004';
                    v_msj_respuesta := 'Error: '||sqlerrm;
                 end if;
         end;
       end if;
      --el usuario es el user
      v_cod_usuario   := upper(user);
      if v_cod_respuesta = '000' then -- sino hubo ERROR se arma los datos de la cuenta
         pav_ove.PR_OBT_DEU_OPE_VENCIDA (p_nro_cuenta,
                                   v_fec_actual,
                                   v_mto_cobrado,
                                   v_error,
                                   v_msj_respuesta,
                                   v_capital,
                                   v_moratorio,
                                   v_punitorio,
                                   v_impuesto,
                                   v_cargos,--v_tot_cargo,
                                   v_car_iva,
                                   v_dia_mora,
                                   139);
         if v_error is null then
           v_cod_respuesta :='000';
         else
           v_cod_respuesta :='020';
         end if;
         v_tot_a_cobrar:= nvl(v_capital,0) + nvl(v_moratorio,0) +
                          nvl(v_punitorio,0) + nvl(v_impuesto,0) +
                          nvl(v_cargos,0) + nvl(v_iva,0) ;

         if nvl(v_mto_cobrado,0)+nvl(v_tot_cre_cta,0)+nvl(v_tot_cre_cta_con,0)
           > v_tot_a_cobrar then
            v_cod_respuesta := '009';
            v_msj_respuesta := 'Monto a pagar supera el detallado';
         end if;
       end if; -- fin sino hubo error para sacar datos de cobros

    end if;--transaccion
    if v_cod_respuesta = '000' then
      -- verifico los decimales del importe en cheques
      v_msj_respuesta := fuj_val_importe(v_tipo, v_tip_monto,r_opeven.cod_moneda,v_mto_chq_obco);
      if v_msj_respuesta is null then -- valido el efectivo
        v_msj_respuesta := fuj_val_importe(v_tipo, 'E',r_opeven.cod_moneda,v_mto_efectivo);
      end if;
      if v_msj_respuesta is not null then
        v_cod_respuesta := '007';  -- error
      else
        -- Asigno el nro de caja a los movimientos
        pag_cta.pr_nro_caja(to_number(p_nro_caja));
        /* C.D.Fase 4 - 03/10/2014 */
         if v_hora is null then -- si no es una operación retomada
           v_hor_circuito := v_hor_actual;
         else
            v_hor_circuito:= v_hora; -- Si es una operación retomada debe tomar la hora del movimiento Principal de ge_movimientos
         end if;
            
        PAG_RIE.PR_OPE_RIESGO( v_fec_actual,
                               v_hor_circuito,
                               v_cod_usuario,
                               v_cod_transaccion, -- transacción padre 
                               v_cod_modulo,      -- Módulo
                               v_cod_modalidad,   -- Modalidad
                               p_nro_cuenta,      -- Nro_cuenta
                               v_cod_persona,     -- Persona
                               v_tip_operacion,   -- Tip_operacion 
                               v_mto_cobrado,     -- Monto Cobrado
                               v_nro_documento,   -- Número de Documento
                               r_opeven.cod_moneda,  -- Moneda
                               null,              -- Cotización                       
                               v_nro_pedido); 
        
          If nvl(v_nro_pedido,0) > 0 then
            v_est_movimiento := 'P';
          else
            v_est_movimiento := 'N';
          end if;
        
        if v_hora is null then --- transaccion 360 normal ---
           v_nro_secuencia := nvl(v_nro_secuencia,0);
           -- Actualiza la operacion en la base --- cuota prestamo
           pav_ove.pr_cob_ope_vencida(p_nro_cuenta,
                                      v_mto_cobrado,
                                      v_cod_oficina,
                                      'Cobro Operacion Vencida',
                                      v_fec_actual,
                                      v_hor_actual,
                                      v_nro_secuencia,
                                      v_cod_transaccion,
                                      v_cod_modulo,
                                      v_cod_modalidad,
                                      v_nro_documento,
                                      v_est_movimiento);-- C.D.Fase 4
           -- genero movimiento por el cobro en efectivo --
           if v_mto_efectivo  > 0 then
              v_nro_secuencia := nvl(v_nro_secuencia,0) + 1;

              r_gmovi.cod_usuario     := v_cod_usuario;
              r_gmovi.hora            := v_hor_actual;
              r_gmovi.fecha           := v_fec_actual;
              r_gmovi.nro_secuencia   := v_nro_secuencia;
              r_gmovi.cod_modulo      := r_opeven.cod_modulo;
              r_gmovi.cod_modalidad   := r_opeven.cod_modalidad;
              r_gmovi.cod_oficina     := r_opeven.cod_oficina;
              r_gmovi.cod_moneda      := r_opeven.cod_moneda;
              r_gmovi.fec_valor       := v_fec_actual;
              r_gmovi.cod_tra_padre   := v_cod_transaccion;
              r_gmovi.cod_mod_padre   := v_cod_modulo;
              r_gmovi.cod_mad_padre   := v_cod_modalidad;
              r_gmovi.nro_caja        := to_number(p_nro_caja);
              r_gmovi.cod_transaccion := 740; --- Efectivo
              r_gmovi.monto           := v_mto_efectivo;
              r_gmovi.nro_documento   := v_nro_documento;
              r_gmovi.cod_ofi_origen  := v_cod_oficina;
              r_gmovi.emi_aviso       := 'N';
              r_gmovi.concepto        := 'Cobro Op.Vencida :'||p_nro_cuenta;
              --------------------------------------------
              -- C.D.Fase 4
             -- r_gmovi.estado          := 'N';
              r_gmovi.estado          := v_est_movimiento;
              --------------------------------------------
              r_gmovi.reversado       := 'N';
              r_gmovi.cod_rubro       := NULL;
              r_gmovi.nro_cuenta      := NULL;
              r_gmovi.tip_mov_rubro   := 'D';
              PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi);
           end if;
           -- genero movimiento por el cobro en cheque --
           if v_mto_chq_obco > 0 then
              v_nro_secuencia := v_nro_secuencia + 1;

              r_gmovi.cod_usuario     := v_cod_usuario;
              r_gmovi.hora            := v_hor_actual;
              r_gmovi.fecha           := v_fec_actual;
              r_gmovi.nro_secuencia   := v_nro_secuencia;
              r_gmovi.cod_modulo      := r_opeven.cod_modulo;
              r_gmovi.cod_modalidad   := r_opeven.cod_modalidad;
              r_gmovi.cod_oficina     := r_opeven.cod_oficina;
              r_gmovi.cod_moneda      := r_opeven.cod_moneda;
              r_gmovi.fec_valor       := v_fec_actual;
              r_gmovi.cod_tra_padre   := v_cod_transaccion;
              r_gmovi.cod_mod_padre   := v_cod_modulo;
              r_gmovi.cod_mad_padre   := v_cod_modalidad;
              r_gmovi.nro_caja        := to_number(p_nro_caja);
              r_gmovi.cod_transaccion := 607; --- Cheques
              r_gmovi.monto           := v_mto_chq_obco;
              r_gmovi.nro_documento   := v_nro_documento;
              r_gmovi.cod_ofi_origen  := v_cod_oficina;
              r_gmovi.emi_aviso       := 'N';
              r_gmovi.concepto        := 'Cobro Op.Vencida :'||p_nro_cuenta;
              r_gmovi.estado          := 'N';
              r_gmovi.reversado       := 'N';
              r_gmovi.cod_rubro       := NULL;
              r_gmovi.nro_cuenta      := NULL;
              r_gmovi.tip_mov_rubro   := 'D';
              ---- Recuperar datos de la retencion
              pag_cta.PR_OBT_RETENCION(v_fec_actual,p_nro_cuenta,
                      r_opeven.cod_modulo, r_opeven.cod_modalidad, 607,
                      r_opeven.cod_moneda,r_gmovi.cod_retencion, r_gmovi.fec_fin_retencion);
              PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi);
           end if;
           if v_mto_chq_nbco > 0 then
              v_nro_secuencia := v_nro_secuencia + 1;

              r_gmovi.cod_usuario     := v_cod_usuario;
              r_gmovi.hora            := v_hor_actual;
              r_gmovi.fecha           := v_fec_actual;
              r_gmovi.nro_secuencia   := v_nro_secuencia;
              r_gmovi.cod_modulo      := r_opeven.cod_modulo;
              r_gmovi.cod_modalidad   := r_opeven.cod_modalidad;
              r_gmovi.cod_oficina     := r_opeven.cod_oficina;
              r_gmovi.cod_moneda      := r_opeven.cod_moneda;
              r_gmovi.fec_valor       := v_fec_actual;
              r_gmovi.cod_tra_padre   := v_cod_transaccion;
              r_gmovi.cod_mod_padre   := v_cod_modulo;
              r_gmovi.cod_mad_padre   := v_cod_modalidad;
              r_gmovi.nro_caja        := to_number(p_nro_caja);
              r_gmovi.cod_transaccion := 606; --- Cheques
              r_gmovi.monto           := v_mto_chq_nbco;
              r_gmovi.nro_documento   := v_nro_documento;
              r_gmovi.cod_ofi_origen  := v_cod_oficina;
              r_gmovi.emi_aviso       := 'N';
              r_gmovi.concepto        := 'Cobro Op.Vencida :'||p_nro_cuenta;
              -------------------------------------
              -- C.D.Fase 4
              --r_gmovi.estado          := 'N';
              r_gmovi.estado          := v_est_movimiento;
              -------------------------------------
              r_gmovi.reversado       := 'N';
              r_gmovi.cod_rubro       := NULL;
              r_gmovi.nro_cuenta      := NULL;
              r_gmovi.tip_mov_rubro   := 'D';
              ---- Recuperar datos de la retencion
              pag_cta.PR_OBT_RETENCION(v_fec_actual,p_nro_cuenta,
                      r_opeven.cod_modulo, r_opeven.cod_modalidad, 606,
                      r_opeven.cod_moneda,r_gmovi.cod_retencion, r_gmovi.fec_fin_retencion);
              PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi);
           end if;
        else   --- retoma operaciones pendientes
          --cargamos como actual la hora del mov.
           v_hor_actual              := v_hora;
           r_gmovi.cod_retencion     := null;
           r_gmovi.fec_fin_retencion := null;
           if v_mto_chq_obco > 0 then
              pag_cta.PR_OBT_RETENCION(v_fec_actual,p_nro_cuenta,
                      r_opeven.cod_modulo, r_opeven.cod_modalidad, v_cod_tra_chq_retomada,
                      r_opeven.cod_moneda,r_gmovi.cod_retencion, r_gmovi.fec_fin_retencion);
             --actualizar el movimiento
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
                      r_opeven.cod_modulo, r_opeven.cod_modalidad, 606,
                      r_opeven.cod_moneda,r_gmovi.cod_retencion, r_gmovi.fec_fin_retencion);
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
         /* -- C.D.Fase 4, si es una operación retomada y no genera un pedido de autorización debe 
            actualizar el estado en movimientos */ 
          if nvl(v_nro_pedido,0) = 0 then 
             begin
               update ge_movimientos
                    set estado            = 'N',
                        nro_caja          = to_number(p_nro_caja),
                        cod_oficina       = r_opeven.cod_oficina,
                        nro_documento     = v_nro_documento
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
          /* Si se genera un Pedido de Autorización no actualiza CJ_CONTROLES,
            CJ_MOVIMIENTOS queda con estado Pendiente. C.D.Fase 4 - 03/10/2014 */
           if nvl(v_nro_pedido,0) > 0 then 
             lp_gen_transaccion('P');
           else
             lp_gen_transaccion('N');
           end if;
             
        end if;
     end if;
  end if;
end if;
 -- mensaje final sino hubo errores
 if v_cod_respuesta = '000' then -- sino hubo problemas, se carga mensaje por defecto
   if nvl(v_nro_pedido,0) > 0 then -- c.D.Fase 4
     v_msj_respuesta:= 'Se ha generado el Pedido de Autorización Nro:'||v_nro_pedido;
   else
     if nvl(v_mto_chq_obco,0) = 0 then
       v_msj_respuesta := 'Operacion confirmada';
     end if;
   end if;
 end if;
 if v_cod_respuesta = '000' then -- sino hubo problemas, se carga mensaje por defecto
    -- IMPRESION DEL COMPROBANTE DE PAGO
    if nvl(v_nro_pedido,0)= 0 then -- C.D.Fase 4
      if (nvl(v_mto_chq_obco,0) = 0 or (nvl(v_mto_chq_obco,0)>0 and v_cod_tra_chq_retomada= 607)) and nvl(v_mto_chq_nbco,0) = 0 then
         v_cod_respuesta := 'IMP'; -- para indicar que esta ok y se puede imprimir
          lp_act_can_impresion;-- C.D.Fase 4
         v_msj_respuesta := 'Operacion Confirmada. Comprobante de Pago ha sido impreso.'||'~'||
         fuj_imp_transaccion_139(v_cod_oficina, -- oficina
                                 v_nro_documento,
                                 p_nro_caja, -- Caja
                                 r_opeven.cod_moneda, -- Moneda
                                 p_nro_cuenta, -- cuenta
                                 v_fec_actual,
                                 v_hor_actual -- hora
                                 );
      else
        if v_cod_tra_chq_retomada = 607 then --24hs
           v_msj_respuesta := 'Operacion confirmada - '||v_nro_documento;
        else
           v_msj_respuesta := 'Operacion confirmada - Boleta a desglosar: '||v_nro_documento;
        end if;
      end if;
     else
       v_msj_respuesta:= 'Se ha generado el Pedido de Autorización Nro:'||v_nro_pedido;  
     end if; -- Fin agregado C.D.Fase 4
 end if;


 /* falta armar el mensaje de respuesta */
 v_msj_salida := p_nro_operacion||'~'||
                 v_cod_respuesta||'~'||
                 nvl(v_msj_respuesta,'Operacion confirmada');
 return(v_msj_salida);
end;
/

