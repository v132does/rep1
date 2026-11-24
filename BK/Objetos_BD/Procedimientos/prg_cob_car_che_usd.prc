CREATE OR REPLACE PROCEDURE IT.PRG_COB_CAR_CHE_USD
 (P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE default null
  ,P_COD_TRANSACCION IN GE_TRANSACCIONES.COD_TRANSACCION%TYPE DEFAULT null
  ,P_NRO_CHEQUE IN GE_CHE_CUSTODIAS.NRO_CHEQUE%TYPE DEFAULT NULL
  ,P_NRO_BOLETA IN GE_CHE_CUSTODIAS.NRO_BOLETA%TYPE DEFAULT NULL
  ,P_CAN_CHEQUES IN NUMBER DEFAULT 1
 )
 IS
-- VARIABLES
v_cod_usuario ba_usuarios.cod_usuario%type;
v_hora ge_movimientos.hora%type;
v_cod_transaccion ge_transacciones.cod_transaccion%type;
v_cod_mod_padre ba_modulos.cod_modulo%type;
v_cod_mad_padre varchar2(240);
v_nro_secuencia ge_movimientos.nro_secuencia%type;
r_gmovi ge_movimientos%rowtype;
v_existe varchar2(1) := 'N';
v_estado ge_movimientos.estado%type;
v_tipo ge_tasas.tipo%type;
v_nro_cuenta ah_cta_vistas.nro_cuenta%type;
v_tas_personalizada ah_cta_vistas.tas_personalizada%type;
v_cod_moneda ah_cta_vistas.cod_moneda%type;
v_cod_mon_local ba_monedas.cod_moneda%type := pag_gen.fu_obt_mon_local;
v_cod_modulo ge_calendarios.cod_modulo%type;
v_exi_tra_prohibida char(1);
v_cod_tasa_ah ah_cta_vistas.cod_tasa%type;
v_cod_modalidad ah_cta_vistas.cod_modalidad%type;
v_cod_oficina ah_cta_vistas.cod_oficina%type;
v_tip_valor ge_tasas.tip_valor%type;
v_fec_vigencia ge_tas_fechas.fec_vigencia%type;
v_val_tas_global ge_tas_fechas.val_tasa%type;
v_fec_final ge_tas_fechas.fec_vigencia%type;
v_fecha ge_movimientos.fecha%type;
v_imp_debito number(18, 2) := 0;
v_msj_error varchar2(1000);
v_concepto  varchar2(1000);
v_val_tasa GE_TAS_FECHAS.VAL_TASA%TYPE;
v_monto number(18, 2) := 0;
v_mto_cargo number(18, 2) := 0;
v_sal_disponible ah_cta_vistas.sal_total%type;
v_nro_documento ge_movimientos.nro_documento%type := 0;
v_redondeo number(4) := 0;
v_procesa char(1) := 'N';
v_cotizacion          ge_cotizaciones.val_conversion%type;
--Agregado para Controlar que cobre lo que pueda--
v_tot_cobros     number(18,2);
v_tot_disponible number(18,2);
v_mto_cobrar     number(18,2);
v_mto_imp_cobrar number(18,2) := 0;
v_mto_car_cobrar number(18,2) := 0;
v_mto_sin_cobrar number(18,2);
v_mto_sin_cob_cargo number(18,2) := 0;
v_mto_sin_cob_impuesto number(18,2) := 0;
v_nro_sec_cargo number;
--------------------------------------------------
--- Variables para desglose de cargos
v_mto_fin_cargo       pr_cuotas.val_recargo%type;
v_car_desglose        pr_cuotas.val_recargo%type;
v_porcen              number;


--- Cursor de transacciones detalles del cargo
cursor c_des_cargos is
   select t.cod_tra_hijo, t.cod_mod_hijo, t.cod_mad_hijo, a.cod_tasa
   from ge_transacciones_det t, ge_transacciones a
   where t.cod_transaccion = P_COD_TRANSACCION
   and t.cod_modulo      = v_cod_modulo
   and t.cod_modalidad   = v_cod_modalidad
   and t.cod_tra_hijo    = a.cod_transaccion
   and t.cod_mod_hijo    = a.cod_modulo
   and t.cod_mad_hijo    = a.cod_modalidad
   and t.cod_tra_hijo   <> p_cod_transaccion
   and a.cod_tasa   is not null;

BEGIN
   /*Obtener datos de la cuenta */
   PAG_CTA.PR_OBT_CUENTA(p_nro_cuenta);
   if pag_cta.fu_obt_cod_error() <> 0 then
      v_msj_error := 'Cta.'||p_nro_cuenta||'-'||pag_cta.g_cod_error||'-'||pag_cta.g_msj_error;
   end if;
   ---
   v_nro_documento := p_nro_boleta;
   ---
   v_estado := pag_cta.g_ctas.estado;
   v_cod_modulo := pag_cta.g_ctas.cod_modulo;
   v_cod_oficina := pag_cta.g_ctas.cod_oficina;
   v_cod_modalidad := pag_cta.g_ctas.cod_modalidad;
   v_cod_mod_padre := pag_cta.g_ctas.cod_modulo;
   v_cod_mad_padre := pag_cta.g_ctas.cod_modalidad;
   v_nro_cuenta := pag_cta.G_CTAS.nro_cuenta;
   v_cod_moneda := pag_cta.g_ctas.cod_moneda; -- Asigno la Moneda de la cuenta a la que debo debitar
   v_fecha := pag_cal.FU_OBT_FEC_ACTUAL(v_cod_modulo);
   v_hora := fug_ini_hora(sysdate,'HH24:MI:SS');
   v_nro_secuencia := nvl(pae_cnf.G_NRO_SECUENCIA,0);
   v_cod_usuario := user;

   v_tas_personalizada := nvl(pag_cta.g_ctas.tas_personalizada,'N');
   v_cod_tasa_ah := null;

   /* Si NO es una cuenta con transaccion prohibida se procesa dicha cuenta */
   IF v_msj_error IS NULL THEN -- 1)
      --principal de cuenta
      v_fec_final := v_fecha;
      v_cod_transaccion := P_COD_TRANSACCION; -- Trans.Cobro del Cargo CHQUSD
      v_tip_valor := ' ';

      v_cod_tasa_ah := null;
      --busca_valor_de_tasa_a_aplicar;
      PAG_GEN.PR_OBT_VAL_TASA(v_cod_modulo,v_cod_modalidad,v_cod_oficina,
                                 v_nro_cuenta, v_cod_moneda,0,
                                 v_tas_personalizada, v_cod_tasa_ah,v_cod_transaccion,v_fec_final,
                                 v_val_tas_global,v_fec_vigencia,v_tip_valor,v_tipo);
      v_val_tas_global := v_val_tas_global * P_CAN_CHEQUES;
      IF v_exi_tra_prohibida = 'S' THEN
         v_mto_cargo := 0;
      ELSE
         v_mto_cargo := v_val_tas_global;
      END IF;

      IF v_cod_tasa_ah  IS NULL THEN
         v_mto_cargo := 0;
      END IF;
      v_imp_debito := nvl(v_mto_cargo,0);
      v_val_tasa := v_val_tas_global;
      v_monto := 0;
      v_cotizacion := pag_gen.fu_obt_cotizacion(v_cod_moneda, v_fecha);

      -- VERIFICAR SI SE DEBE REALIZAR EL DESGLOSE DE CARGOS
      if nvl(v_val_tasa,0) > 0 then
         --Traer la Disponibilidad de la Cuenta--
         pag_cta.pr_ver_operacion(P_NRO_CUENTA,
                               P_COD_TRANSACCION,
                               v_cod_mod_padre,
                               v_cod_mad_padre,
                               'D',
                               v_cod_moneda,
                               v_mto_fin_cargo,
                               v_cod_oficina,
                               -- out
                               pag_cta.g_ctas.cod_modulo,
                               pag_cta.g_ctas.cod_modalidad,
                               v_estado,
                               v_sal_disponible,
                               v_procesa,
                               503);
         v_tot_disponible := v_sal_disponible;
         v_tot_cobros := 0;
         ----------------------------------------
         v_redondeo := 0;
         v_mto_fin_cargo := nvl(v_imp_debito,0);
         v_cod_mod_padre := v_cod_modulo;
         v_cod_mad_padre := v_cod_modalidad;
         v_nro_secuencia := v_nro_secuencia + 1;
         v_nro_sec_cargo := v_nro_secuencia;
         for adi in c_des_cargos loop --- Desglose de cargos para el IVA
            v_car_desglose  := 0;
            --- Calcular monto del desglose
            pag_gen.pr_obt_val_tasa(adi.cod_mod_hijo,---  Modulo
            adi.cod_mad_hijo,------------  Modalidad
            v_cod_oficina,---------------  Oficina
            null,------------------------  Nro de cuenta
            v_cod_moneda,----------------  Moneda
            v_imp_debito,----------------  Monto de la transaccion
            'N',-------------------------  Tasa personalizada
            adi.cod_tasa,----------------  Código de Tasa
            adi.cod_tra_hijo,------------  Código de Transacción
            v_fecha,---------------------  fecha final
            v_val_tasa,------------------  Valor de la tasa
            v_fec_vigencia,--------------  Fecha de Vigencia
            v_tip_valor,-----------------  Tip_valor
            v_tipo);---------------------  Tipo
            --- Calcular monto
            if nvl(v_imp_debito,0) <> 0 and adi.cod_tasa is not null and v_val_tasa is not null then
               if v_tip_valor = 'V' then
                  v_car_desglose := nvl(v_val_tasa,0);
               else
                  v_porcen := /*nvl(v_val_tasa,0) + */100; -- Porque el cargo es sin iva, debe ser mas iva.
                  if v_cod_moneda  = v_cod_mon_local  then
                     v_car_desglose := round(nvl(v_imp_debito,0) *
                                       nvl(v_val_tasa,0)/v_porcen,0);
                  else
                     v_car_desglose := round(nvl(v_imp_debito,0) *
                                       nvl(v_val_tasa,0)/v_porcen,2);
                  End If;
               end if;
            else
               v_car_desglose := 0;
            end if;
            ---
            if v_car_desglose <> 0 then
               --v_nro_documento := v_nro_documento + 1;
               v_nro_secuencia := v_nro_secuencia + 1;
               r_gmovi.nro_secuencia      := v_nro_secuencia;
               r_gmovi.cod_usuario        := v_cod_usuario;
               r_gmovi.hora               := v_hora;
               r_gmovi.fecha              := V_fecha;
               r_gmovi.cod_modulo         := v_cod_modulo;
               r_gmovi.cod_modalidad      := v_cod_modalidad;
               r_gmovi.cod_oficina        := v_cod_oficina;
               r_gmovi.nro_cuenta         := null;--v_nro_cuenta;
               r_gmovi.cod_moneda         := v_cod_moneda;
               r_gmovi.est_cuenta         := 'C';
               r_gmovi.cod_tra_padre      := P_COD_TRANSACCION;
               r_gmovi.cod_transaccion    := adi.cod_tra_hijo;
               r_gmovi.concepto           := 'Desglose de Cargo Chq USD';
               r_gmovi.monto              := v_car_desglose;
               --if v_cod_moneda <> v_cod_mon_local then
               --   r_gmovi.cotizacion         := v_cotizacion;
               --   r_gmovi.mto_equ_local      := round(trunc(v_car_desglose,2)*v_cotizacion,0);
               --else
                  r_gmovi.cotizacion         := null;
                  r_gmovi.mto_equ_local      := null;
               --end if;
               r_gmovi.fec_valor          := v_fecha;
               r_gmovi.emi_aviso          := 'S';
               r_gmovi.reversado          := 'N';
               r_gmovi.protegido          := 'N';
               r_gmovi.estado             := 'N';
               r_gmovi.cod_ofi_origen     := v_cod_oficina;
               r_gmovi.cod_mod_padre      := v_cod_modulo;
               r_gmovi.cod_mad_padre      := v_cod_modalidad;
               r_gmovi.nro_documento      := v_nro_documento;
               r_gmovi.val_tasa           := v_val_tasa;
               -- Requerimiento: CNFINCCC-3.
               -- Fecha: 17/10/2014.
               r_gmovi.referencia         := P_NRO_CUENTA;
               v_mto_imp_cobrar := nvl(v_mto_imp_cobrar,0) + nvl(v_car_desglose,0);
               if v_tot_disponible > 0 then
                  v_mto_cobrar := v_car_desglose;
                 /*FM DYDMR-1808  19/06/2015*/ 
                  if v_tot_disponible >= v_mto_cobrar + v_imp_debito then
                     pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
                     v_mto_fin_cargo := v_mto_fin_cargo + nvl(v_mto_cobrar,0);
                     v_tot_cobros := nvl(v_tot_cobros,0) + nvl(v_mto_cobrar,0);
                     v_tot_disponible := nvl(v_tot_disponible,0) - nvl(v_mto_cobrar,0);
                  else --AP: SC-12499 ITGF - Error en calculo de IVA en CARGOS CHEQ N/PLAZA M/E
                     if v_cod_moneda  = v_cod_mon_local  then
                        v_car_desglose := round(nvl(v_tot_disponible/((v_val_tasa/100)+1),0) * nvl(v_val_tasa,0)/v_porcen,0);
                     else
                        v_car_desglose := round(nvl(v_tot_disponible/((v_val_tasa/100)+1),0) * nvl(v_val_tasa,0)/v_porcen,2);
                     end If;
                     r_gmovi.monto  := v_car_desglose;
                     v_mto_cobrar   := v_car_desglose;
                     pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
                     v_mto_fin_cargo := v_mto_fin_cargo + nvl(v_mto_cobrar,0);
                     v_tot_cobros := nvl(v_tot_cobros,0) + nvl(v_mto_cobrar,0);
                     v_tot_disponible := nvl(v_tot_disponible,0) - nvl(v_mto_cobrar,0);
                  end if;
               end if;
               -- Requerimiento: CNFINCCC-3.
               -- Fecha: 17/10/2014.
               r_gmovi.referencia         := NULL;
            end if;
         end loop;
         --v_nro_secuencia := v_nro_secuencia + 1;
         r_gmovi.nro_secuencia      := v_nro_sec_cargo;
         r_gmovi.cod_usuario        := v_cod_usuario;
         r_gmovi.hora               := v_hora;
         r_gmovi.fecha              := v_fecha;
         r_gmovi.cod_modulo         := v_cod_modulo;
         r_gmovi.cod_modalidad      := v_cod_modalidad;
         r_gmovi.cod_oficina        := v_cod_oficina;
         r_gmovi.nro_cuenta         := null;--v_nro_cuenta;
         r_gmovi.cod_moneda         := v_cod_moneda;
         r_gmovi.est_cuenta         := 'C';
         r_gmovi.cod_tra_padre      := p_cod_transaccion;
         r_gmovi.cod_transaccion    := p_cod_transaccion;
         r_gmovi.concepto           := 'Cargos';
         r_gmovi.monto              := nvl(v_imp_debito,0);
         --if v_cod_moneda <> v_cod_mon_local then
         --   r_gmovi.cotizacion         := v_cotizacion;
         --   r_gmovi.mto_equ_local      := round(trunc(nvl(v_imp_debito,0),2)*v_cotizacion,0);
         --else
            r_gmovi.cotizacion         := null;
            r_gmovi.mto_equ_local      := null;
         --end if;
         r_gmovi.fec_valor          := v_fecha;
         r_gmovi.emi_aviso          := 'S';
         r_gmovi.reversado          := 'N';
         r_gmovi.protegido          := 'N';
         r_gmovi.estado             := 'N';
         r_gmovi.cod_ofi_origen     := v_cod_oficina;
         r_gmovi.cod_mod_padre      := v_cod_modulo;
         r_gmovi.cod_mad_padre      := v_cod_modalidad;
         r_gmovi.nro_documento      := v_nro_documento;
         r_gmovi.val_tasa           := v_val_tasa;
         -- Requerimiento: CNFINCCC-3.
         -- Fecha: 17/10/2014.
         r_gmovi.referencia         := P_NRO_CUENTA;
         --pag_gen.pr_ins_ge_movimiento(r_gmovi);
         v_mto_car_cobrar := nvl(v_mto_car_cobrar,0) + nvl(v_imp_debito,0);
         if v_tot_disponible > 0 then
            v_mto_cobrar := nvl(v_imp_debito,0);
            if v_tot_disponible >= nvl(v_mto_cobrar,0) then
               pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
               v_tot_cobros := nvl(v_tot_cobros,0) + nvl(v_mto_cobrar,0);
               v_tot_disponible := nvl(v_tot_disponible,0) - nvl(v_mto_cobrar,0);
            elsif v_tot_disponible > 0 and v_tot_disponible < nvl(v_mto_cobrar,0) then
               v_mto_cobrar := v_tot_disponible;
               --recargar el monto--
               r_gmovi.monto := nvl(v_mto_cobrar,0);
               if v_cod_moneda <> v_cod_mon_local then
                  r_gmovi.cotizacion         := v_cotizacion;
                  r_gmovi.mto_equ_local      := round(trunc(nvl(v_mto_cobrar,0),2)*v_cotizacion,0);
               else
                  r_gmovi.cotizacion         := null;
                  r_gmovi.mto_equ_local      := null;
               end if;
               pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
               v_tot_cobros := nvl(v_tot_cobros,0) + nvl(v_mto_cobrar,0);
               v_tot_disponible := nvl(v_tot_disponible,0) - nvl(v_mto_cobrar,0);
            end if;
         end if;
         -- Requerimiento: CNFINCCC-3.
         -- Fecha: 17/10/2014.
         r_gmovi.referencia := NULL;
      end if;

      v_mto_fin_cargo := v_tot_cobros;
      IF nvl(v_mto_car_cobrar,0) + nvl(v_mto_imp_cobrar,0) > v_mto_fin_cargo then
         v_mto_sin_cobrar := (nvl(v_mto_car_cobrar,0) + nvl(v_mto_imp_cobrar,0)) - nvl(v_mto_fin_cargo,0);
         v_msj_error := 'SAL.INSUF.';
         if v_mto_sin_cobrar = (nvl(v_mto_car_cobrar,0) + nvl(v_mto_imp_cobrar,0)) then
            v_mto_sin_cob_cargo := nvl(v_mto_car_cobrar,0);
            v_mto_sin_cob_impuesto := nvl(v_mto_imp_cobrar,0);
         elsif v_mto_sin_cobrar > 0 then
            --El impuesto siempre se cobra--
            v_mto_sin_cob_cargo := nvl(v_mto_car_cobrar,0) - (nvl(v_mto_fin_cargo,0) - nvl(v_mto_imp_cobrar,0));
         end if;
         --ELSE -- Saldo insuficiente
         --   -- recalculo para cobrarle hasta el monto disponible
         --   if v_cod_moneda = v_cod_mon_local then
         --      v_redondeo := 0;
         --   else
         --      v_redondeo := 2;
         --   end if;
         --   v_mto_fin_cargo := round(v_sal_disponible * v_mto_fin_cargo / v_imp_debito, v_redondeo);
         --   v_monto := v_sal_disponible - v_mto_fin_cargo;
         --   --v_imp_debito := nvl(v_mto_fin_cargo,0) + nvl(v_monto, 0);
         --END IF;
      END IF;

      --- v_concepto := 'COB. CARGO DEPOS. CHEQ.USD';
      --v_est_movimiento := 'N';
      IF v_msj_error IS NOT NULL THEN --4) Control de error x Saldo Insuficiente
         --v_est_movimiento := 'E';
         IF v_existe = 'N' THEN
            --- Si hay problema para debitar por falta de saldo
           -- RI : 02/02/2010 : Si la cuenta esta inactiva y no tiene saldo no se graba mov.pendiente
           If  v_sal_disponible = 0 and v_estado = 'I' then
               null;
           else
           IF P_NRO_CHEQUE is not null THEN
               v_concepto := 'COB.CARGO CHQ N° '||P_NRO_CHEQUE||' MONEDA '||v_cod_moneda;
           ELSIF P_NRO_BOLETA is not null THEN
               v_concepto := 'COB.CARGO CHQ N°  '||P_NRO_BOLETA||' MONEDA '||v_cod_moneda;
           ELSIF P_NRO_CHEQUE is null and P_NRO_BOLETA is null THEN
               v_concepto := 'COB.CARGO DEPOS.CHEQ.USD';
           END IF;
            v_concepto := SUBSTR(v_concepto,1,35);
            Insert into Ge_Mov_Pendientes
            (nro_cuenta,Fecha,Cod_modulo,Cod_modalidad,Cod_transaccion,
             Cod_mod_padre,Cod_mad_padre,Cod_tra_padre,Monto,Hora,Cod_usuario,
             Cod_moneda,Cod_oficina,Estado,Cod_ofi_origen,
             Concepto,
             Val_tasa,Nro_documento, Car_manual, saldo )
            Values
            (v_nro_cuenta,v_Fecha,v_cod_modulo,v_cod_modalidad,p_cod_transaccion,
             v_cod_modulo,v_cod_modalidad,150,(nvl(v_mto_sin_cob_cargo,0)+nvl(v_mto_sin_cob_impuesto,0)),
             v_hora,v_cod_usuario,
             v_cod_moneda,v_cod_oficina,'I',v_cod_oficina,
             v_concepto,
             v_val_tasa,v_nro_documento, 'S', 
             (nvl(v_mto_sin_cob_cargo,0)+nvl(v_mto_sin_cob_impuesto,0)));
           End if;  
          END IF;
      end if;
      if nvl(v_mto_fin_cargo,0) > 0 then
         -- Si no hay problemas con la verificacion, Cobro el cargo
         if v_nro_secuencia > 990 then
            v_hora := pag_gen.fu_obt_sig_segundo(v_hora);
            v_nro_secuencia := 1;
         end if;
         IF P_NRO_CHEQUE is not null THEN
             v_concepto := 'CARGO P/CHEQUE NRO. '||P_NRO_CHEQUE||' EN MONEDA '||v_cod_moneda||'.';
         ELSIF P_NRO_BOLETA is not null THEN
             v_concepto := 'CARGO P/BOLETA NRO. '||P_NRO_BOLETA||' EN MONEDA '||v_cod_moneda||
                           '-'||P_CAN_CHEQUES||' CHEQUES';
         ELSIF P_NRO_CHEQUE is null and P_NRO_BOLETA is null THEN
             v_concepto := 'COBRO DE CARGOS';
         END IF;
         v_concepto := SUBSTR(v_concepto,1,35);
         --v_nro_secuencia := v_nro_secuencia + 1;
         PAG_CTA.PR_ACT_OPERACION(P_NRO_CUENTA,
                             v_hora,
                             'D',
                             v_cod_moneda,
                             v_mto_fin_cargo,
                             v_cod_transaccion,   --transaccion padre
                             503,   --transaccion hijo
                             V_NRO_DOCUMENTO, -- nro_documento
                             NULL,   --cotizacion
                             v_cod_oficina,
                             v_cod_modulo,
                             v_cod_modalidad,
                             NULL,  --cod_tasa
                             NULL,  --val_tasa
                             v_concepto,
                             'S',   --emi_aviso
                             v_nro_secuencia,
                             v_fecha);
--INICIO 28/12/2007 TERCERIZACION
         if pag_cta.g_cod_error <> 0 then
              raise_application_error(-20000,'No pudo debitar de la cuenta '||P_NRO_CUENTA|| ' por '||pag_cta.g_msj_error);
         end if;
--INICIO 28/12/2007 TERCERIZACION
      END IF;-- Fin Mvto en GE_MOVIMIENTOS
   END IF;--si sal-promedio < minimo
   pae_cnf.G_NRO_SECUENCIA := v_nro_secuencia;
END; -- PRG_COB_CAR_CHE_USD
/

