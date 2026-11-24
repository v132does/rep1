CREATE OR REPLACE PROCEDURE IT.PRV_GEN_VALUACIONES
 IS

/* Obtener datos de la clasificacion de la operacion vencida. */
PROCEDURE LP_OBT_CLASIFICACION
 (P_NRO_CUENTA IN OV_CTA_VENCIDAS.NRO_CUENTA%TYPE
 ,RP_GCOPE IN OUT GE_CLA_OPERACIONES%ROWTYPE
 );
/* Obtener datos de la valuacion de la operacion vencida. */
PROCEDURE LP_OBT_VALUACION
 (P_NRO_CUENTA IN OV_CTA_VENCIDAS.NRO_CUENTA%TYPE
 ,RP_VVALU IN OUT OV_VALUACIONES%ROWTYPE
 );
/* Actualizar o generar registro de valuacion. */
PROCEDURE LP_ACT_VALUACION
 (P_NRO_CUENTA IN OV_CTA_VENCIDAS.NRO_CUENTA%TYPE
 ,P_FECHA IN OV_VALUACIONES.FECHA%TYPE
 ,P_COTIZACION IN NUMBER
 ,RP_VVALU IN OV_VALUACIONES%ROWTYPE
 ,RP_VCVEN IN OV_CTA_VENCIDAS%ROWTYPE
 ,RP_GCOPE IN GE_CLA_OPERACIONES%ROWTYPE
 );
   --- Este proceso debe ejecutarse luego del:
   --- cálculo de cambio de estado de la operación vencida
   --- clasificación de riesgos y previsiones
   --- cálculo de garantías computables
   ---
   v_cam_situacion      varchar2(1);
   v_fecha              ge_movimientos.fecha%type;
   v_hora               ge_movimientos.hora%type;
   v_nro_secuencia      ge_movimientos.nro_secuencia%type;
   v_cod_mon_local      ba_monedas.cod_moneda%type;
   v_cotizacion         ge_cotizaciones.val_conversion%type;
   r_VVALU              ov_valuaciones%rowtype;
   r_pvalc              ov_valuaciones%rowtype;
   r_gcope              ge_cla_operaciones%rowtype;
   r_gmovi              ge_movimientos%rowtype;
   --- Variables del cobro.
   v_mto_capital        ge_movimientos.monto%type;
   v_mto_prevision      ge_movimientos.monto%type;
   v_mto_ori_capital    ge_movimientos.monto%type;
   v_mto_ori_prevision  ge_movimientos.monto%type;
   v_tot_acumulado      ov_valuaciones.tot_val_saldo%type;
   v_dif_capital        ov_valuaciones.tot_val_saldo%type;
   v_dif_prevision      ov_valuaciones.tot_val_saldo%type;
   v_pag_capital        ov_valuaciones.tot_val_saldo%type;
   v_pag_prevision      ov_valuaciones.tot_val_saldo%type;
   --- Cancelados en el dia se procesa para reconcer la valuación en suspenso por
   --- diferencia de cambio
   cursor c_pre_valuar is
   select *
     from OV_CTA_VENCIDAS p
    where cod_moneda <> v_cod_mon_local
      and ((estado not in ('C','I'))
            or (estado = 'C' and fec_cam_estado = v_fecha));

/* Obtener datos de la clasificación y previsión de la operación vencida. */
PROCEDURE LP_OBT_CLASIFICACION
 (P_NRO_CUENTA IN OV_CTA_VENCIDAS.NRO_CUENTA%TYPE
 ,RP_GCOPE IN OUT GE_CLA_OPERACIONES%ROWTYPE
 )
 IS
BEGIN
   begin
   -- Resolución N°37
   select nro_cuenta, cod_persona, cod_estado, round(cat_automatica), dia_atraso
     into rp_gcope.nro_cuenta, rp_gcope.cod_persona, rp_gcope.cod_estado,
          rp_gcope.cat_automatica, rp_gcope.dia_atraso
     from ge_cla_operaciones
    where nro_cuenta = p_nro_cuenta;
   exception
      when others then
        rp_gcope  := null;
        select cod_persona
          into rp_gcope.cod_persona
          from ge_cta_clientes
         where nro_cuenta = p_nro_cuenta
           and relacion = 'P';
   end;
   ----
   if fug_obt_tip_implementacion <> 3 then
      select nvl(cat_riesgo,1)
        into rp_gcope.cat_automatica
        from ge_clientes
       where cod_persona = rp_gcope.cod_persona;
   else --- Para 3
      select fup_obt_categoria(g.cat_automatica , g.cat_subjetiva)
        into rp_gcope.cat_automatica
        from ge_clientes g
       where cod_persona = rp_gcope.cod_persona;
   end if;
   ---- Recuperar el valor de la previsión del ov_previsiones
   select nvl(sum(p1.monto),0)
     into rp_gcope.tot_prevision
     from ov_previsiones p1
    where p1.nro_cuenta = p_nro_cuenta
      and p1.fecha = (select max(p2.fecha)
                        from ov_previsiones p2
                       where p2.nro_cuenta = p1.nro_cuenta);
exception
   when no_data_found then
      raise_application_error(-20000,
      'No existe clasificacion para cuenta '||p_nro_cuenta);
END;
/* Obtener datos de la valuación de la operacion vencida. */
PROCEDURE LP_OBT_VALUACION
 (P_NRO_CUENTA IN OV_CTA_VENCIDAS.NRO_CUENTA%TYPE
 ,RP_VVALU IN OUT OV_VALUACIONES%ROWTYPE
 )
 IS
BEGIN
   -- Resolución N°37
   select ov.nro_cuenta, ov.fecha, ov.estado, ov.sal_total, ov.tot_gar_computables,
          ov.tot_prevision, round(ov.cat_automatica) cat_automatica, ov.cotizacion, ov.cot_anterior, ov.tot_val_saldo,
          ov.tot_val_garantia, ov.tot_val_prevision, ov.tot_valuacion
     into rp_vvalu.nro_cuenta, rp_vvalu.fecha, rp_vvalu.estado, rp_vvalu.sal_total, rp_vvalu.tot_gar_computables,
          rp_vvalu.tot_prevision, rp_vvalu.cat_automatica, rp_vvalu.cotizacion, rp_vvalu.cot_anterior, rp_vvalu.tot_val_saldo,
          rp_vvalu.tot_val_garantia, rp_vvalu.tot_val_prevision, rp_vvalu.tot_valuacion
     from ov_valuaciones ov
    where ov.nro_cuenta = p_nro_cuenta;

    if rp_vvalu.estado = 'C' then
       rp_vvalu := null;
    end if;
exception
   when no_data_found then
      rp_VVALU := null;
END;
/* Actualizar o generar registro de valuacion. */
PROCEDURE LP_ACT_VALUACION
 (P_NRO_CUENTA IN OV_CTA_VENCIDAS.NRO_CUENTA%TYPE
 ,P_FECHA IN OV_VALUACIONES.FECHA%TYPE
 ,P_COTIZACION IN NUMBER
 ,RP_VVALU IN OV_VALUACIONES%ROWTYPE
 ,RP_VCVEN IN OV_CTA_VENCIDAS%ROWTYPE
 ,RP_GCOPE IN GE_CLA_OPERACIONES%ROWTYPE
 )
 IS
BEGIN
   update OV_VALUACIONES
      set fecha                = p_fecha,
          estado               = rp_vcven.estado,
          sal_total            = nvl(rp_vcven.sal_total,0),
          tot_gar_computables  = nvl(rp_gcope.tot_gar_computables,0),
          tot_prevision        = nvl(rp_gcope.tot_prevision,0),
          cat_automatica       = rp_gcope.cat_automatica,
          cot_anterior         = rp_vvalu.cot_anterior,
          cotizacion           = p_cotizacion,
          tot_val_saldo        = nvl(rp_vvalu.tot_val_saldo,0),
          tot_val_garantia     = nvl(rp_vvalu.tot_val_garantia,0),
          tot_val_prevision    = nvl(rp_vvalu.tot_val_prevision,0),
          tot_valuacion        = nvl(rp_vvalu.tot_valuacion,0)
    where nro_cuenta = p_nro_cuenta;
   if sql%notfound then
      insert into OV_VALUACIONES
         (nro_cuenta, fecha, estado,
          sal_total,
          tot_gar_computables, tot_prevision, cat_automatica, cotizacion,
          tot_val_saldo,
          tot_val_garantia, tot_val_prevision, tot_valuacion)
      values
          (p_nro_cuenta, p_fecha, rp_vcven.estado,
           nvl(rp_vcven.sal_total,0),
           nvl(rp_gcope.tot_gar_computables,0), nvl(rp_gcope.tot_prevision,0), rp_gcope.cat_automatica, p_cotizacion,
           nvl(rp_vvalu.tot_val_saldo,0),
           nvl(rp_vvalu.tot_val_garantia,0), nvl(rp_vvalu.tot_val_prevision,0), nvl(rp_vvalu.tot_valuacion,0));
   end if;
END;
PROCEDURE LP_OBT_MTO_COBRADO (P_NRO_CUENTA IN VARCHAR2,
                              P_COTIZACION IN NUMBER,
                              P_MTO_CAPITAL IN OUT NUMBER,
                              P_MTO_PREVISION IN OUT NUMBER,
                              P_MTO_ORI_CAPITAL    IN OUT NUMBER,
                              P_MTO_ORI_PREVISION  IN OUT NUMBER) IS
BEGIN
  ---
  --- Capital
  ---
  SELECT nvl(ROUND(sum(case when cod_transaccion in (801, 805, 820,821,822,823) then
             NVL(MONTO,0) * NVL(COTIZACION, P_COTIZACION) else 0 end),0),0) mto_capital,
         nvl(ROUND(sum(case when cod_transaccion in (731, 7731) then
             decode(cod_transaccion, 731, 1, 7731, 1, 0) * NVL(MONTO,0) * NVL(COTIZACION, P_COTIZACION) else 0 end),0),0) mto_prevision,
         nvl(ROUND(sum(case when cod_transaccion in (801, 805, 820,821,822,823) then
             NVL(MONTO,0) else 0 end),0),0) mto_capital,
         nvl(ROUND(sum(case when cod_transaccion in (731, 7731) then
             decode(cod_transaccion, 731, 1, 7731, 1, 0) * NVL(MONTO,0) else 0 end),0),0) mto_prevision
    INTO P_MTO_CAPITAL, P_MTO_PREVISION, P_MTO_ORI_CAPITAL, P_MTO_ORI_PREVISION
    FROM GE_MOVIMIENTOS
   WHERE NRO_CUENTA = P_NRO_CUENTA
     AND REVERSADO = 'N'
     AND COD_TRA_PADRE IN (359, 139, 731, 7731);

END LP_OBT_MTO_COBRADO;

BEGIN
   pag_cal.pr_obt_dat_calendar(15);
   v_cod_mon_local := pag_gen.fu_obt_mon_local;
   v_fecha         := pag_cal.G_FEC_ACTUAL;
   v_hora          := fug_ini_hora(v_fecha);
   v_nro_secuencia := 0;
   --- Paso al historico las valuaciones actuales
   insert into OV_VALUACIONES_his
   select * from OV_VALUACIONES v
    where fecha = pag_cal.G_FEC_ANTERIOR;
   --- OBS: Se hace toda a las transacciones 152 y 153 para asentar solo el neto
   --- previsiones, a devengar y suspenso son contrarios a capital e interes por
   --- eso se pone la inversa las ganancias y perdidas
   for cta in c_pre_valuar loop
      --- Recuperar datos de la clasificacion
      lp_obt_clasificacion(cta.nro_cuenta, r_gcope);
      --- Recuperar datos de la valuacion
      r_pvalc         := null;
      v_tot_acumulado := 0;
      lp_obt_valuacion(cta.nro_cuenta, r_VVALU);
      --
      v_tot_acumulado := nvl(r_vvalu.sal_total,0) - nvl(r_vvalu.tot_prevision,0);
      --- Recuperar cotizacion de la moneda
      v_cotizacion := pag_gen.fu_obt_cotizacion(cta.cod_moneda, v_fecha);
      --- Obtiene el mto cobrado.
      LP_OBT_MTO_COBRADO(cta.nro_cuenta, nvl(r_vvalu.cotizacion,v_cotizacion), v_mto_capital, v_mto_prevision, v_mto_ori_capital, v_mto_ori_prevision);
      ---
      --- Verificar si corresponde valuar
      if nvl(cta.sal_total,-1)               <> nvl(r_VVALU.sal_total,-1)
      or nvl(r_gcope.tot_prevision,-1)       <> nvl(r_VVALU.tot_prevision,-1)
      or cta.estado                          <> r_VVALU.estado
      or r_gcope.cat_automatica              <> r_VVALU.cat_automatica
      or nvl(v_cotizacion,-1)                <> nvl(r_VVALU.cotizacion,v_cotizacion) then
         --- Existe cambio de valores
         --- Cargar datos por defecto de movimientos
         r_gmovi.fecha          := v_fecha;
         r_gmovi.hora           := v_hora;
         r_gmovi.cod_usuario    := user;
         r_gmovi.nro_cuenta     := cta.nro_cuenta;
         r_gmovi.fec_valor      := v_fecha;
         r_gmovi.cod_oficina    := cta.cod_oficina;
         r_gmovi.cod_ofi_origen := cta.cod_oficina;
         r_gmovi.estado         := 'N';
         r_gmovi.reversado      := 'N';
         r_gmovi.emi_aviso      := 'N';
         r_gmovi.cod_tra_padre  := 150;
         r_gmovi.cod_mod_padre  := cta.cod_modulo;
         r_gmovi.cod_mad_padre  := cta.cod_modalidad;
         r_gmovi.cod_modulo     := cta.cod_modulo;
         r_gmovi.cod_modalidad  := cta.cod_modalidad;
         IF v_nro_secuencia + 25 > 999 THEN
          v_nro_secuencia := 0;
          v_hora          := fug_ini_hora(v_fecha);
          r_gmovi.hora    := v_hora;
         END IF;
         ---------------------------------------
         --- Procesar CAPITAL (151,152,153)
         ---------------------------------------
         v_pag_capital   := 0;
         v_dif_capital   := 0;
         v_cam_situacion := 'N';
         If (nvl(r_VVALU.estado,'A') not in ('A','C') or nvl(r_VVALU.cat_automatica,1) not in (1,2)) and
            (nvl(cta.estado,'A') in ('A','C') and nvl(r_gcope.cat_automatica,1) in (1,2)) then
            v_cam_situacion := 'S';
         End if;
         ---
         if cta.estado <> 'C' then
            v_dif_capital := round((nvl(cta.sal_total,0)* v_cotizacion) - ((nvl(r_vvalu.sal_total,cta.sal_total)*nvl(r_vvalu.cotizacion,v_cotizacion)) - v_mto_capital),0);
         else
            v_dif_capital := round((nvl(r_vvalu.sal_total,0)* v_cotizacion) - ((nvl(r_vvalu.sal_total,cta.sal_total)*nvl(r_vvalu.cotizacion,v_cotizacion))),0);
         end if;
         if nvl(r_vvalu.sal_total,0) <> 0 and nvl(v_mto_ori_capital, 0) <> 0 and nvl(v_tot_acumulado,0) <> 0 then
            --- Obtiene la Cancelación Parcial del Capital.
            v_pag_capital := round(nvl(r_vvalu.tot_valuacion, 0) * nvl(v_mto_ori_capital, 0) / nvl(v_tot_acumulado,0),0);
            if v_pag_capital < 0 then
               v_pag_capital := 0;
            end if;
         end if;
         --
         if cta.estado = 'C' then
            v_pag_capital := 0;
         end if;
         -- Genero el movimiento por el pago.
         if nvl(v_pag_capital,0) <> 0 then
            -- Acredito Ganancia.
            v_nro_secuencia         := v_nro_secuencia + 1;
            r_gmovi.nro_secuencia   := v_nro_secuencia;
            r_gmovi.concepto        := 'Ganancia por Pago - Cap';
            r_gmovi.est_cuenta      := 'C';
            r_gmovi.nro_documento2  := r_gcope.cat_automatica;
            r_gmovi.monto           := nvl(v_pag_capital,0);
            r_gmovi.cod_moneda      := v_cod_mon_local;
            r_gmovi.mto_equ_local   := null;
            r_gmovi.cod_transaccion := 152;
            pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
            -- Debito valuación.
            v_nro_secuencia         := v_nro_secuencia + 1;
            r_gmovi.nro_secuencia   := v_nro_secuencia;
            r_gmovi.concepto        := 'Desafectación por Pago - Cap';
            If cta.estado = 'C' Then
               r_gmovi.est_cuenta      := nvl(r_vvalu.estado,cta.estado);
            else
               r_gmovi.est_cuenta      := cta.estado;
            end if;
            r_gmovi.nro_documento2  := r_gcope.cat_automatica;
            r_gmovi.monto           := nvl(v_pag_capital,0) * (-1);
            r_gmovi.cod_moneda      := v_cod_mon_local;
            r_gmovi.mto_equ_local   := null;
            r_gmovi.cod_transaccion := 152;
            pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
         end if;
         --
         if v_dif_capital <> 0 or cta.estado = 'C' or v_cam_situacion = 'S' then
            if v_dif_capital > 0 then
               -- Acredito Ganancia.
               v_nro_secuencia         := v_nro_secuencia + 1;
               r_gmovi.nro_secuencia   := v_nro_secuencia;
               r_gmovi.concepto        := 'Ganancia por dif. de cambio - Cap';
               If cta.estado = 'C' Then
                  r_gmovi.est_cuenta      := nvl(r_vvalu.estado,cta.estado);
               else
                  r_gmovi.est_cuenta      := cta.estado;
               end if;
               r_gmovi.nro_documento2  := r_gcope.cat_automatica;
               r_gmovi.monto           := v_dif_capital;
               r_gmovi.cod_moneda      := v_cod_mon_local;
               r_gmovi.mto_equ_local   := null;
               r_gmovi.cod_transaccion := 152;
               pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
               -- Verifica si se canceló o se cambió de estado debe reconocer la ganancia.
               if (nvl(r_VVALU.tot_val_saldo,0) > 0 or cta.estado = 'C') and
                 (v_cam_situacion = 'S' or cta.estado = 'C') then
                v_nro_secuencia         := v_nro_secuencia + 1;
                r_gmovi.nro_secuencia   := v_nro_secuencia;
                r_gmovi.concepto        := 'Desafectacion ganancia x Cap';
                r_gmovi.cod_moneda      := v_cod_mon_local;
                r_gmovi.est_cuenta      := nvl(r_vvalu.estado,cta.estado);
                r_gmovi.nro_documento2  := nvl(r_vvalu.cat_automatica,r_gcope.cat_automatica);
                If cta.estado = 'C' then
                   r_gmovi.monto := (nvl(r_vvalu.tot_val_saldo,0) + v_dif_capital) * -1;
                Else
                   r_gmovi.monto := (nvl(r_vvalu.tot_val_saldo,0) * -1);
                End if;
                r_gmovi.mto_equ_local   := null;
                r_gmovi.cod_transaccion := 152;
                pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
                -- Afecta a cartera por el mismo importe.
                v_nro_secuencia         := v_nro_secuencia + 1;
                r_gmovi.nro_secuencia   := v_nro_secuencia;
                r_gmovi.concepto        := 'Act. por dif. de cambio - Cap';
                r_gmovi.est_cuenta      := cta.estado;
                r_gmovi.nro_documento2  := r_gcope.cat_automatica;
                r_gmovi.cod_transaccion := 152; -- Cartera
                r_gmovi.cod_moneda      := v_cod_mon_local;
                If cta.estado = 'C' then
                   r_gmovi.monto := (nvl(r_vvalu.tot_val_saldo,0) + v_dif_capital);
                Else
                   r_gmovi.monto := (nvl(r_vvalu.tot_val_saldo,0));
                End if;
                r_gmovi.mto_equ_local   := null;
                pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
               end if;
            elsif v_dif_capital < 0 then
               if nvl(r_vvalu.tot_val_saldo,0) > 0 then
                  if abs(v_dif_capital) > nvl(r_vvalu.tot_val_saldo,0) then
                    -- Desafectar ganancia y el resto va a perdida
                    v_nro_secuencia         := v_nro_secuencia + 1;
                    r_gmovi.nro_secuencia   := v_nro_secuencia;
                    r_gmovi.concepto        := 'Desafectacion ganancia - Cap';
                    r_gmovi.cod_moneda      := v_cod_mon_local;
                    If cta.estado = 'C' Then
                      r_gmovi.est_cuenta      := nvl(r_vvalu.estado,cta.estado);
                    else
                      r_gmovi.est_cuenta      := cta.estado;
                    end if;
                    r_gmovi.nro_documento2  := nvl(r_vvalu.cat_automatica,r_gcope.cat_automatica);
                    r_gmovi.monto           := (nvl(r_vvalu.tot_val_saldo,0)*-1);
                    r_gmovi.mto_equ_local   := null;
                    r_gmovi.cod_transaccion := 152;
                    pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
                    ----
                    v_nro_secuencia         := v_nro_secuencia + 1;
                    r_gmovi.nro_secuencia   := v_nro_secuencia;
                    r_gmovi.concepto        := 'Perdida por dif. de cambio - Cap';
                    If cta.estado = 'C' Then
                      r_gmovi.est_cuenta      := nvl(r_vvalu.estado,cta.estado);
                    else
                      r_gmovi.est_cuenta      := cta.estado;
                    end if;
                    r_gmovi.nro_documento2  := r_gcope.cat_automatica;
                    r_gmovi.monto           := abs(nvl(v_dif_capital,0)) - abs(nvl(r_vvalu.tot_val_saldo,0));
                    r_gmovi.cod_moneda      := v_cod_mon_local;
                    r_gmovi.mto_equ_local   := null;
                    r_gmovi.cod_transaccion := 153;  -- Perdida
                    pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
                  else
                    --- Si es menor al monto valuado debe desafectar
                    v_nro_secuencia         := v_nro_secuencia + 1;
                    r_gmovi.nro_secuencia   := v_nro_secuencia;
                    r_gmovi.concepto        := 'Desafectacion ganancia - Cap';
                    r_gmovi.cod_moneda      := v_cod_mon_local;
                    If cta.estado = 'C' Then
                      r_gmovi.est_cuenta      := nvl(r_vvalu.estado,cta.estado);
                    else
                      r_gmovi.est_cuenta      := cta.estado;
                    end if;
                    r_gmovi.nro_documento2  := nvl(r_vvalu.cat_automatica,r_gcope.cat_automatica);
                    r_gmovi.monto           := (nvl(v_dif_capital,0));
                    r_gmovi.mto_equ_local   := null;
                    r_gmovi.cod_transaccion := 152;
                    pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
                  end if;
                  --- Verifica si se canceló o se cambió de estado debe reconocer la ganancia.
                  if nvl(v_dif_capital,0) + nvl(r_vvalu.tot_val_saldo,0) > 0 and
                     (v_cam_situacion = 'S' or cta.estado = 'C') then
                    v_nro_secuencia         := v_nro_secuencia + 1;
                    r_gmovi.nro_secuencia   := v_nro_secuencia;
                    r_gmovi.concepto        := 'Desafectacion ganancia x Cap';
                    r_gmovi.cod_moneda      := v_cod_mon_local;
                    r_gmovi.est_cuenta      := nvl(r_vvalu.estado,cta.estado);
                    r_gmovi.nro_documento2  := nvl(r_vvalu.cat_automatica,r_gcope.cat_automatica);
                    r_gmovi.monto           := ((nvl(v_dif_capital,0) + nvl(r_vvalu.tot_val_saldo,0)) * -1);
                    r_gmovi.mto_equ_local   := null;
                    r_gmovi.cod_transaccion := 152;
                    pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
                    --- Afecta a cartera por el mismo importe.
                    v_nro_secuencia         := v_nro_secuencia + 1;
                    r_gmovi.nro_secuencia   := v_nro_secuencia;
                    r_gmovi.concepto        := 'Act. por dif. de cambio - Cap';
                    r_gmovi.est_cuenta      := cta.estado;
                    r_gmovi.nro_documento2  := r_gcope.cat_automatica;
                    r_gmovi.cod_transaccion := 152; -- Cartera
                    r_gmovi.cod_moneda      := v_cod_mon_local;
                    r_gmovi.monto           := (nvl(v_dif_capital,0) + nvl(r_VVALU.tot_val_saldo,0));
                    r_gmovi.mto_equ_local   := null;
                    pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
                  end if;
               else --- Todo a perdida
                  v_nro_secuencia         := v_nro_secuencia + 1;
                  r_gmovi.nro_secuencia   := v_nro_secuencia;
                  r_gmovi.concepto        := 'Perdida por dif. de cambio - Cap';
                  If cta.estado = 'C' Then
                    r_gmovi.est_cuenta      := nvl(r_VVALU.estado,cta.estado);
                  else
                    r_gmovi.est_cuenta      := cta.estado;
                  end if;
                  r_gmovi.nro_documento2  := r_gcope.cat_automatica;
                  r_gmovi.monto           := abs(v_dif_capital);
                  r_gmovi.cod_moneda      := v_cod_mon_local;
                  r_gmovi.mto_equ_local   := null;
                  r_gmovi.cod_transaccion := 153;
                  pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
               end if;
            else --- NO TUVO DIFERENCIA DE COTIZACION...
              --- Verifica si se canceló o se cambió de estado debe reconocer la ganancia.
              if nvl(r_vvalu.tot_val_saldo,0) > 0 and
                 (v_cam_situacion = 'S' or cta.estado = 'C') then
                v_nro_secuencia         := v_nro_secuencia + 1;
                r_gmovi.nro_secuencia   := v_nro_secuencia;
                r_gmovi.concepto        := 'Desafectacion ganancia x Cap';
                r_gmovi.cod_moneda      := v_cod_mon_local;
                r_gmovi.est_cuenta      := nvl(r_vvalu.estado,cta.estado);
                r_gmovi.nro_documento2  := nvl(r_vvalu.cat_automatica,r_gcope.cat_automatica);
                r_gmovi.monto           := (nvl(r_vvalu.tot_val_saldo,0) * -1);
                r_gmovi.mto_equ_local   := null;
                r_gmovi.cod_transaccion := 152;
                pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
                --- Afecta a cartera por el mismo importe.
                v_nro_secuencia         := v_nro_secuencia + 1;
                r_gmovi.nro_secuencia   := v_nro_secuencia;
                r_gmovi.concepto        := 'Act. por dif. de cambio - Cap';
                r_gmovi.est_cuenta      := cta.estado;
                r_gmovi.nro_documento2  := r_gcope.cat_automatica;
                r_gmovi.cod_transaccion := 152; -- Cartera
                r_gmovi.cod_moneda      := v_cod_mon_local;
                r_gmovi.monto           := (nvl(r_vvalu.tot_val_saldo,0));
                r_gmovi.mto_equ_local   := null;
                pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
              end if;
            end if;
            if (nvl(cta.estado,'A') in ('A','C') and
                nvl(r_gcope.cat_automatica,1) in (1,2) ) or
                cta.estado = 'C' then
               --- No es necesario acumular el saldo cuando va todo a pérdida o
               --- son cuentas que generan directamente ganancia o pérdida
               r_pvalc.tot_val_saldo := 0;
            else --- Acumular saldos solo para cuentas a valuar en suspenso
               r_pvalc.tot_val_saldo := nvl(r_vvalu.tot_val_saldo,0) + (nvl(v_dif_capital,0) - nvl(v_pag_capital,0));
               if r_pvalc.tot_val_saldo < 0 then
                  r_pvalc.tot_val_saldo := 0;
               end if;
            end if;
            --- Generar movimiento por la cartera por la diferencia de cotizacion.
            if v_dif_capital != 0 then
              v_nro_secuencia         := v_nro_secuencia + 1;
              r_gmovi.nro_secuencia   := v_nro_secuencia;
              r_gmovi.monto           := 0;
              r_gmovi.cod_moneda      := cta.cod_moneda;
              r_gmovi.mto_equ_local   := nvl(v_dif_capital,0);
              r_gmovi.concepto        := 'Act. por dif. de cambio - Cap';
              r_gmovi.est_cuenta      := nvl(r_VVALU.estado,cta.estado);
              r_gmovi.nro_documento2  := r_gcope.cat_automatica;
              r_gmovi.cod_transaccion := 151; -- Cartera
              pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
            end if;
         end if;
         ----------------------------------------------------
         --- Procesar PREVISIONES (166,167,168)
         ----------------------------------------------------
         v_pag_prevision := 0;
         v_dif_prevision := 0;
         v_cam_situacion := 'N';
         If (nvl(r_vvalu.estado,'A') not in ('A','C') or nvl(r_vvalu.cat_automatica,1) not in (1,2)) and
            (nvl(cta.estado,'A') in ('A','C') and nvl(r_gcope.cat_automatica,1) in (1,2)) then
            v_cam_situacion := 'S';
         End if;
         ---
         if cta.estado <> 'C' then
            v_dif_prevision := round((nvl(r_gcope.tot_prevision,0) * (v_cotizacion - nvl(r_vvalu.cotizacion,v_cotizacion))),0);
         else
            v_dif_prevision := round((nvl(r_vvalu.tot_prevision,0) * (v_cotizacion - nvl(r_vvalu.cotizacion,v_cotizacion))),0);
         end if;
         if (nvl(r_vvalu.tot_prevision, 0) = 0 and nvl(r_gcope.tot_prevision,0) != 0) or
            (nvl(r_vvalu.tot_prevision, 0) != 0 and nvl(r_gcope.tot_prevision,0) = 0) then
            --- no previsiono antes y ahora esta previsionando... o estaba previsionando y ahora deja de previsionar.
            --- por lo tanto no debe procesar.
            v_dif_prevision := 0;
         End if;
         -- Obtiene el monto de desafectación de Previsiones.
         if nvl(r_vvalu.tot_prevision,0) <> 0 and  nvl(v_mto_ori_prevision, 0) <> 0 and nvl(v_tot_acumulado,0) <> 0 then
            v_pag_prevision := round(nvl(r_vvalu.tot_valuacion, 0) * nvl(v_mto_ori_prevision, 0) / nvl(v_tot_acumulado,0),0);
            if v_pag_prevision < 0 then
               v_pag_prevision := 0;
            end if;
         end if;
         -- Obtiene el monto de constitución de Previsiones.
         if v_pag_prevision = 0 and nvl(r_gcope.tot_prevision,0) > nvl(r_vvalu.tot_prevision,0)
         and nvl(r_gcope.tot_prevision,0) <> 0 and nvl(v_tot_acumulado,0) <> 0 then
            v_mto_ori_prevision := nvl(r_vvalu.tot_prevision,0) - nvl(r_gcope.tot_prevision,0);
            if v_mto_ori_prevision <> 0 then
               v_pag_prevision := round(nvl(r_vvalu.tot_valuacion, 0) * nvl(v_mto_ori_prevision, 0) / nvl(v_tot_acumulado,0),0);
            end if;
         end if;
         --
         if cta.estado = 'C' then --DYDMR-3560(ALV-2016) solo si la cuenta se encuentra en estado CANCELADO no debe generar los movimientos de desafectación o constitución de previsiones
            v_pag_prevision := 0;
         end if;
         --
         if nvl(v_pag_prevision,0) <> 0 then
            if nvl(v_pag_prevision,0) > 0 then
               -- Acredito Valuación.
               v_nro_secuencia         := v_nro_secuencia + 1;
               r_gmovi.nro_secuencia   := v_nro_secuencia;
               r_gmovi.concepto        := 'Disminución - Pre';
               If cta.estado = 'C' Then
                  r_gmovi.est_cuenta      := nvl(r_vvalu.estado,cta.estado);
               else
                  r_gmovi.est_cuenta      := cta.estado;
               end if;
               r_gmovi.nro_documento2  := r_gcope.cat_automatica;
               r_gmovi.monto           := v_pag_prevision;
               r_gmovi.cod_moneda      := v_cod_mon_local;
               r_gmovi.mto_equ_local   := null;
               r_gmovi.cod_transaccion := 152;
               pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
               -- Debito Perdida.
               v_nro_secuencia         := v_nro_secuencia + 1;
               r_gmovi.nro_secuencia   := v_nro_secuencia;
               r_gmovi.concepto        := 'Disminución - Pre';
               If cta.estado = 'C' Then
                  r_gmovi.est_cuenta      := nvl(r_vvalu.estado,cta.estado);
               else
                  r_gmovi.est_cuenta      := cta.estado;
               end if;
               r_gmovi.nro_documento2  := r_gcope.cat_automatica;
               r_gmovi.monto           := v_pag_prevision;
               r_gmovi.cod_moneda      := v_cod_mon_local;
               r_gmovi.mto_equ_local   := null;
               r_gmovi.cod_transaccion := 153;
               pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
            elsif nvl(v_pag_prevision,0) < 0 and nvl(r_gcope.tot_prevision,0) <= nvl(r_vvalu.tot_prevision,0) then
               -- Acredito valuación.
               v_nro_secuencia         := v_nro_secuencia + 1;
               r_gmovi.nro_secuencia   := v_nro_secuencia;
               r_gmovi.concepto        := 'Disminución - Pre';
               If cta.estado = 'C' Then
                  r_gmovi.est_cuenta      := nvl(r_vvalu.estado,cta.estado);
               else
                  r_gmovi.est_cuenta      := cta.estado;
               end if;
               r_gmovi.nro_documento2  := r_gcope.cat_automatica;
               r_gmovi.monto           := abs(nvl(v_pag_prevision,0));
               r_gmovi.cod_moneda      := v_cod_mon_local;
               r_gmovi.mto_equ_local   := null;
               r_gmovi.cod_transaccion := 152;
               pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
               -- Debito Pérdida.
               v_nro_secuencia         := v_nro_secuencia + 1;
               r_gmovi.nro_secuencia   := v_nro_secuencia;
               r_gmovi.concepto        := 'Disminución - Pre';
               If cta.estado = 'C' Then
                  r_gmovi.est_cuenta      := nvl(r_vvalu.estado,cta.estado);
               else
                  r_gmovi.est_cuenta      := cta.estado;
               end if;
               r_gmovi.nro_documento2  := r_gcope.cat_automatica;
               r_gmovi.monto           := abs(nvl(v_pag_prevision,0));
               r_gmovi.cod_moneda      := v_cod_mon_local;
               r_gmovi.mto_equ_local   := null;
               r_gmovi.cod_transaccion := 153;
               pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
            elsif nvl(v_pag_prevision,0) < 0 and nvl(r_gcope.tot_prevision,0) > nvl(r_vvalu.tot_prevision,0) then
               -- Debito Valuación.
               v_nro_secuencia         := v_nro_secuencia + 1;
               r_gmovi.nro_secuencia   := v_nro_secuencia;
               r_gmovi.concepto        := 'Aumenta - Pre';
               If cta.estado = 'C' Then
                  r_gmovi.est_cuenta      := nvl(r_vvalu.estado,cta.estado);
               else
                  r_gmovi.est_cuenta      := cta.estado;
               end if;
               r_gmovi.nro_documento2  := r_gcope.cat_automatica;
               r_gmovi.monto           := nvl(v_pag_prevision,0);
               r_gmovi.cod_moneda      := v_cod_mon_local;
               r_gmovi.mto_equ_local   := null;
               r_gmovi.cod_transaccion := 152;
               pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
               -- Acredito Ganancia.
               v_nro_secuencia         := v_nro_secuencia + 1;
               r_gmovi.nro_secuencia   := v_nro_secuencia;
               r_gmovi.concepto        := 'Aumenta - Pre';
               r_gmovi.est_cuenta      := 'C';
               r_gmovi.nro_documento2  := r_gcope.cat_automatica;
               r_gmovi.monto           := nvl(v_pag_prevision,0) * (-1);
               r_gmovi.cod_moneda      := v_cod_mon_local;
               r_gmovi.mto_equ_local   := null;
               r_gmovi.cod_transaccion := 152;
               pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
            end if;
         end if;

         --- DYDMR-3925 DM 28-06-2016
         v_dif_prevision := v_dif_prevision * (-1);
         if v_dif_prevision <> 0 or cta.estado = 'C' or v_cam_situacion = 'S' then
            if v_dif_prevision > 0 then
              ---
              if abs(v_dif_prevision) > (nvl(r_vvalu.tot_val_prevision,0) - nvl(v_pag_prevision,0)) then
                    --- Desafectar ganancia y el resto va a perdida
                    v_nro_secuencia         := v_nro_secuencia + 1;
                    r_gmovi.nro_secuencia   := v_nro_secuencia;
                    r_gmovi.concepto        := 'Desafectacion ganancia - Pre';
                    r_gmovi.cod_moneda      := v_cod_mon_local;
                    If cta.estado = 'C' Then
                      r_gmovi.est_cuenta      := nvl(r_vvalu.estado,cta.estado);
                    else
                      r_gmovi.est_cuenta      := cta.estado;
                    end if;
                    r_gmovi.nro_documento2  := nvl(r_vvalu.cat_automatica,r_gcope.cat_automatica);
                    r_gmovi.monto           := ((nvl(r_vvalu.tot_val_prevision,0) - nvl(v_pag_prevision,0)));
                    r_gmovi.mto_equ_local   := null;
                    r_gmovi.cod_transaccion := 152;
                    pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
                    ----
                    v_nro_secuencia         := v_nro_secuencia + 1;
                    r_gmovi.nro_secuencia   := v_nro_secuencia;
                    r_gmovi.concepto        := 'Perdida por dif. de cambio - Pre';
                    If cta.estado = 'C' Then
                      r_gmovi.est_cuenta      := nvl(r_vvalu.estado,cta.estado);
                    else
                      r_gmovi.est_cuenta      := cta.estado;
                    end if;
                    r_gmovi.nro_documento2  := r_gcope.cat_automatica;
                    r_gmovi.monto           := (nvl(v_dif_prevision,0) - (nvl(r_vvalu.tot_val_prevision,0) - nvl(v_pag_prevision,0)))*-1;
                    r_gmovi.cod_moneda      := v_cod_mon_local;
                    r_gmovi.mto_equ_local   := null;
                    r_gmovi.cod_transaccion := 153;  --- Perdida
                    pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
                  else
                    --- Si es menor al monto valuado debe desafectar
                    v_nro_secuencia         := v_nro_secuencia + 1;
                    r_gmovi.nro_secuencia   := v_nro_secuencia;
                    r_gmovi.concepto        := 'Desafectacion ganancia - Pre';
                    r_gmovi.cod_moneda      := v_cod_mon_local;
                    If cta.estado = 'C' Then
                      r_gmovi.est_cuenta      := nvl(r_vvalu.estado,cta.estado);
                    else
                      r_gmovi.est_cuenta      := cta.estado;
                    end if;
                    r_gmovi.nro_documento2  := nvl(r_vvalu.cat_automatica,r_gcope.cat_automatica);
                    r_gmovi.monto           := (nvl(v_dif_prevision,0));
                    r_gmovi.mto_equ_local   := null;
                    r_gmovi.cod_transaccion := 152;
                    pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
                  end if;

 /*              v_nro_secuencia         := v_nro_secuencia + 1;
               r_gmovi.nro_secuencia   := v_nro_secuencia;
               r_gmovi.concepto        := 'Ganancia por dif. de cambio - Pre';
               If cta.estado = 'C' Then
                  r_gmovi.est_cuenta      := nvl(r_vvalu.estado,cta.estado);
               else
                  r_gmovi.est_cuenta      := cta.estado;
               end if;
               r_gmovi.nro_documento2  := r_gcope.cat_automatica;
               r_gmovi.monto           := v_dif_prevision;
               r_gmovi.cod_moneda      := v_cod_mon_local;
               r_gmovi.mto_equ_local   := null;
               r_gmovi.cod_transaccion := 152;
               pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
 */
               --- Verifica si se cancelo o se cambio de estado debe reconocer la ganancia.
               if (nvl(r_vvalu.tot_val_prevision,0) > 0 or cta.estado = 'C') and
                 (v_cam_situacion = 'S' or cta.estado = 'C') then
                v_nro_secuencia         := v_nro_secuencia + 1;
                r_gmovi.nro_secuencia   := v_nro_secuencia;
                r_gmovi.concepto        := 'Actualiza Valuacion - Pre.';
                r_gmovi.cod_moneda      := v_cod_mon_local;
                r_gmovi.est_cuenta      := nvl(r_vvalu.estado,cta.estado);
                r_gmovi.nro_documento2  := nvl(r_vvalu.cat_automatica,r_gcope.cat_automatica);
                r_gmovi.monto           := nvl(r_vvalu.tot_val_prevision,0);
                r_gmovi.mto_equ_local   := null;
                r_gmovi.cod_transaccion := 152;
                pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
                --- Afecta a cartera por el mismo importe.
                v_nro_secuencia         := v_nro_secuencia + 1;
                r_gmovi.nro_secuencia   := v_nro_secuencia;
                r_gmovi.concepto        := 'Act. por dif. de cambio - Pre';
                r_gmovi.est_cuenta      := cta.estado;
                r_gmovi.nro_documento2  := r_gcope.cat_automatica;
                r_gmovi.cod_transaccion := 152; -- Cartera
                r_gmovi.cod_moneda      := v_cod_mon_local;
                If cta.estado = 'C' then
                   r_gmovi.monto := (nvl(r_vvalu.tot_val_prevision,0) + v_dif_prevision) * (-1);
                Else
                   r_gmovi.monto := (nvl(r_vvalu.tot_val_prevision,0)) * (-1);
                End if;
                r_gmovi.mto_equ_local   := null;
                pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
               end if;
            elsif v_dif_prevision < 0 then
               if nvl(r_vvalu.tot_val_prevision,0) > 0 then
                  if abs(v_dif_prevision) > nvl(r_vvalu.tot_val_prevision,0) then
                    --- Desafectar ganancia y el resto va a perdida
                    v_nro_secuencia         := v_nro_secuencia + 1;
                    r_gmovi.nro_secuencia   := v_nro_secuencia;
                    r_gmovi.concepto        := 'Desafectacion ganancia - Pre';
                    r_gmovi.cod_moneda      := v_cod_mon_local;
                    If cta.estado = 'C' Then
                      r_gmovi.est_cuenta      := nvl(r_vvalu.estado,cta.estado);
                    else
                      r_gmovi.est_cuenta      := cta.estado;
                    end if;
                    r_gmovi.nro_documento2  := nvl(r_vvalu.cat_automatica,r_gcope.cat_automatica);
                    r_gmovi.monto           := (nvl(r_vvalu.tot_val_prevision,0)*-1);
                    r_gmovi.mto_equ_local   := null;
                    r_gmovi.cod_transaccion := 152;
                    pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
                    ----
                    v_nro_secuencia         := v_nro_secuencia + 1;
                    r_gmovi.nro_secuencia   := v_nro_secuencia;
                    r_gmovi.concepto        := 'Perdida por dif. de cambio - Pre';
                    If cta.estado = 'C' Then
                      r_gmovi.est_cuenta      := nvl(r_vvalu.estado,cta.estado);
                    else
                      r_gmovi.est_cuenta      := cta.estado;
                    end if;
                    r_gmovi.nro_documento2  := r_gcope.cat_automatica;
                    r_gmovi.monto           := abs(nvl(v_dif_prevision,0)) - abs(nvl(r_vvalu.tot_val_prevision,0));
                    r_gmovi.cod_moneda      := v_cod_mon_local;
                    r_gmovi.mto_equ_local   := null;
                    r_gmovi.cod_transaccion := 153;  --- Perdida
                    pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
                  else
                    --- Si es menor al monto valuado debe desafectar
                    v_nro_secuencia         := v_nro_secuencia + 1;
                    r_gmovi.nro_secuencia   := v_nro_secuencia;
                    r_gmovi.concepto        := 'Desafectacion ganancia - Pre';
                    r_gmovi.cod_moneda      := v_cod_mon_local;
                    If cta.estado = 'C' Then
                      r_gmovi.est_cuenta      := nvl(r_vvalu.estado,cta.estado);
                    else
                      r_gmovi.est_cuenta      := cta.estado;
                    end if;
                    r_gmovi.nro_documento2  := nvl(r_vvalu.cat_automatica,r_gcope.cat_automatica);
                    r_gmovi.monto           := (nvl(v_dif_prevision,0));
                    r_gmovi.mto_equ_local   := null;
                    r_gmovi.cod_transaccion := 152;
                    pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
                  end if;
                  --- Verifica si se cancelo o se cambio de estado debe reconocer la ganancia.
                  if nvl(v_dif_prevision,0) + nvl(r_vvalu.tot_val_prevision,0) > 0 and
                     (v_cam_situacion = 'S' or cta.estado = 'C') then
                    v_nro_secuencia         := v_nro_secuencia + 1;
                    r_gmovi.nro_secuencia   := v_nro_secuencia;
                    r_gmovi.concepto        := 'Desafectacion ganancia x Pre';
                    r_gmovi.cod_moneda      := v_cod_mon_local;
                    r_gmovi.est_cuenta      := nvl(r_vvalu.estado,cta.estado);
                    r_gmovi.nro_documento2  := nvl(r_vvalu.cat_automatica,r_gcope.cat_automatica);
                    r_gmovi.monto           := (nvl(v_dif_prevision,0) + nvl(r_vvalu.tot_val_prevision,0));
                    r_gmovi.mto_equ_local   := null;
                    r_gmovi.cod_transaccion := 152;
                    pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
                    --- Afecta a cartera por el mismo importe.
                    v_nro_secuencia         := v_nro_secuencia + 1;
                    r_gmovi.nro_secuencia   := v_nro_secuencia;
                    r_gmovi.concepto        := 'Act. por dif. de cambio - Pre';
                    r_gmovi.est_cuenta      := cta.estado;
                    r_gmovi.nro_documento2  := r_gcope.cat_automatica;
                    r_gmovi.cod_transaccion := 152; -- Cartera
                    r_gmovi.cod_moneda      := v_cod_mon_local;
                    r_gmovi.monto           := (nvl(v_dif_prevision,0) + nvl(r_vvalu.tot_val_prevision,0)) * (-1);
                    r_gmovi.mto_equ_local   := null;
                    pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
                  end if;
               else --- Todo a perdida
                  v_nro_secuencia         := v_nro_secuencia + 1;
                  r_gmovi.nro_secuencia   := v_nro_secuencia;
                  r_gmovi.concepto        := 'Perdida por dif. de cambio - Pre';
                  If cta.estado = 'C' Then
                    r_gmovi.est_cuenta      := nvl(r_vvalu.estado,cta.estado);
                  else
                    r_gmovi.est_cuenta      := cta.estado;
                  end if;
                  r_gmovi.nro_documento2  := r_gcope.cat_automatica;
                  r_gmovi.monto           := abs(v_dif_prevision);
                  r_gmovi.cod_moneda      := v_cod_mon_local;
                  r_gmovi.mto_equ_local   := null;
                  r_gmovi.cod_transaccion := 153;
                  pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
               end if;
            else --- NO TUVO DIFERENCIA DE COTIZACION...
              --- Verifica si se cancelo o se cambio de estado debe reconocer la ganancia.
              if nvl(r_vvalu.tot_val_prevision,0) > 0 and
                 (v_cam_situacion = 'S' or cta.estado = 'C') then
                v_nro_secuencia         := v_nro_secuencia + 1;
                r_gmovi.nro_secuencia   := v_nro_secuencia;
                r_gmovi.concepto        := 'Actualiza Valuacion - Pre.';
                r_gmovi.cod_moneda      := v_cod_mon_local;
                r_gmovi.est_cuenta      := nvl(r_vvalu.estado,cta.estado);
                r_gmovi.nro_documento2  := nvl(r_vvalu.cat_automatica,r_gcope.cat_automatica);
                r_gmovi.monto           := nvl(r_vvalu.tot_val_prevision,0);
                r_gmovi.mto_equ_local   := null;
                r_gmovi.cod_transaccion := 152;
                pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
                --- Afecta a cartera por el mismo importe.
                v_nro_secuencia         := v_nro_secuencia + 1;
                r_gmovi.nro_secuencia   := v_nro_secuencia;
                r_gmovi.concepto        := 'Act. por dif. de cambio - Pre';
                r_gmovi.est_cuenta      := cta.estado;
                r_gmovi.nro_documento2  := r_gcope.cat_automatica;
                r_gmovi.cod_transaccion := 152; -- Cartera
                r_gmovi.cod_moneda      := v_cod_mon_local;
                r_gmovi.monto           := (nvl(r_vvalu.tot_val_prevision,0)) * (-1);
                r_gmovi.mto_equ_local   := null;
                pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
              end if;
            end if;
            v_dif_prevision := v_dif_prevision * (-1);
            if (nvl(cta.estado,'A') in ('A','C') and
                nvl(r_gcope.cat_automatica,1) in (1,2) ) or
                cta.estado = 'C' then
               --- No es necesario acumular el saldo cuando va todo a perdida o
               --- son cuentas que generan directamente ganancia o perdida
               r_pvalc.tot_val_prevision := 0;
            else --- Acumular saldos solo para cuentas a valuar en suspenso
               r_pvalc.tot_val_prevision := nvl(r_vvalu.tot_val_prevision,0) + (nvl(v_dif_prevision,0) - nvl(v_pag_prevision,0));
               if r_pvalc.tot_val_prevision < 0 then
                  r_pvalc.tot_val_prevision := 0;
               end if;
            end if;
            --- Generar movimiento por la cartera por la diferencia de cotizacion.
            if nvl(v_dif_prevision,0) != 0 then
              v_nro_secuencia         := v_nro_secuencia + 1;
              r_gmovi.nro_secuencia   := v_nro_secuencia;
              r_gmovi.monto           := 0;
              r_gmovi.cod_moneda      := cta.cod_moneda;
              r_gmovi.mto_equ_local   := nvl(v_dif_prevision,0);
              r_gmovi.concepto        := 'Act. por dif. de cambio - Pre';
              r_gmovi.est_cuenta      := nvl(r_vvalu.estado,cta.estado);
              r_gmovi.nro_documento2  := r_gcope.cat_automatica;
              r_gmovi.cod_transaccion := 166; -- Cartera
              pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
            end if;
         end if;
         --- Actualizar valuaciones
         r_pvalc.cot_anterior := r_vvalu.cotizacion;
         -- Se realiza el calculo neteado de la valuación.
         r_pvalc.tot_valuacion := nvl(r_vvalu.tot_valuacion,0) +
                                  ((nvl(v_dif_capital,0) - nvl(v_pag_capital,0)) - (nvl(v_dif_prevision,0) - nvl(v_pag_prevision,0)));
         if r_pvalc.tot_valuacion < 0 or
            (nvl(cta.estado,'A') in ('A','C') and
                nvl(r_gcope.cat_automatica,1) in (1,2) ) or
                cta.estado = 'C' then
            r_pvalc.tot_valuacion := 0;
            r_pvalc.tot_val_saldo := 0;
            r_pvalc.tot_val_prevision := 0;
         end if;
         -- Actualizo la tabla ov_valuaciones.
         lp_act_valuacion(cta.nro_cuenta, v_fecha, v_cotizacion, r_pvalc, cta, r_gcope);
       end if;
   end loop;
END;
/
