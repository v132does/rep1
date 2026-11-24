CREATE OR REPLACE PROCEDURE IT.PRC_GEN_VALUACIONES
 IS

/* Obtener datos de la clasificacion de la cta cte. */
PROCEDURE LP_OBT_CLASIFICACION
 (P_NRO_CUENTA IN CC_CTA_CORRIENTES.NRO_CUENTA%TYPE
 ,RP_GCOPE IN OUT GE_CLA_OPERACIONES%ROWTYPE
 );
/* Obtener datos de la valuacion de la cta cte. */
PROCEDURE LP_OBT_VALUACION
 (P_NRO_CUENTA IN CC_CTA_CORRIENTES.NRO_CUENTA%TYPE
 ,RP_PVALU IN OUT CC_VALUACIONES%ROWTYPE
 );
/* Actualizar o generar registro de valuacion. */
PROCEDURE LP_ACT_VALUACION
 (P_NRO_CUENTA IN CC_CTA_CORRIENTES.NRO_CUENTA%TYPE
 ,P_FECHA IN CC_VALUACIONES.FECHA%TYPE
 ,P_COTIZACION IN NUMBER
 ,RP_PVALU IN CC_VALUACIONES%ROWTYPE
 ,RP_PCPRE IN CC_CTA_CORRIENTES%ROWTYPE
 ,RP_GCOPE IN GE_CLA_OPERACIONES%ROWTYPE
 );
 
   --Esto se saco del esquema de prestamos, ver cuando ejecutar para ctas ctes
   --- Este proceso debe ejecutarse luego del:
   --- calculo de cambio de estado del prestamo/cta cte
   --- clasificacion de riesgos y previsiones
   --- calculo de garantias computables
   ---   
   v_fecha              ge_movimientos.fecha%type;
   v_fec_anterior       ge_movimientos.fecha%type;
   v_hora               ge_movimientos.hora%type;
   v_nro_secuencia      ge_movimientos.nro_secuencia%type;
   v_cod_mon_local      ba_monedas.cod_moneda%type;
   v_cotizacion         ge_cotizaciones.val_conversion%type;
   v_dif_capital        cc_valuaciones.tot_valuacion%type;
   v_dif_prevision      cc_valuaciones.tot_val_prevision%type;
   r_pvalu              cc_valuaciones%rowtype;
   r_pvalc              cc_valuaciones%rowtype;
   r_gcope              ge_cla_operaciones%rowtype;
   r_gmovi              ge_movimientos%rowtype;
   v_mto_ori_capital    ge_movimientos.monto%type;
   v_mto_ori_prevision  ge_movimientos.monto%type;   
   v_tot_acumulado      cc_valuaciones.tot_valuacion%type;
   v_pag_capital        cc_valuaciones.tot_valuacion%type;
   v_pag_prevision      cc_valuaciones.tot_valuacion%type;
   v_sal_total          cc_cta_corrientes.sal_total%type;
   v_sin_sobregiro      varchar2(1);
   v_cam_situacion      varchar2(1);
   v_redondeo_ml        number(5);   
   --- Cancelados en el dia se procesa para reconcer la valuacion en suspenso por
   --- diferencia de cambio
   cursor c_cta_valuar is
   select cc.*
     from cc_cta_corrientes cc
    where cc.cod_moneda <> v_cod_mon_local
      and (nvl(cc.sal_total,0) - nvl(cc.sal_retenido,0) - nvl(cc.sal_bloqueado,0) < 0  --en sobregiro
           or (nvl(cc.sal_total,0) - nvl(cc.sal_retenido,0) - nvl(cc.sal_bloqueado,0) >= 0 --ya no esta en sobregiro
               and exists (Select '1'
                      from cc_sobregiros ccs
                       where ccs.nro_cuenta = cc.nro_cuenta
                         and ccs.fecha = v_fec_anterior)));

/* Obtener datos de la clasificacion y prevision de la cuenta. */
PROCEDURE LP_OBT_CLASIFICACION
 (P_NRO_CUENTA IN CC_CTA_CORRIENTES.NRO_CUENTA%TYPE
 ,RP_GCOPE IN OUT GE_CLA_OPERACIONES%ROWTYPE
 )
 IS
BEGIN
   begin
   -- Resolución N°37
   select nro_cuenta, cod_persona, cod_estado, round(cat_automatica), dia_atraso
     into rp_gcope.nro_cuenta, rp_gcope.cod_persona, rp_gcope.cod_estado, rp_gcope.cat_automatica, rp_gcope.dia_atraso
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
   ---- Obtiene la cantidad de dias que esta sobregirada la cuenta.
   begin
     select can_dias, sit_deuda
       into rp_gcope.dia_atraso, rp_gcope.cod_estado
       from cc_sobregiros_res
      where nro_cuenta = p_nro_cuenta;
   exception
      when no_data_found then
         --ya no esta en sobregiro
         rp_gcope.dia_atraso := 0;
         rp_gcope.cod_estado := 'N';
   end;
   ---- Recuperar el valor de la prevision del cc_previsiones
   select nvl(sum(cc.monto),0)
     into rp_gcope.tot_prevision
     from cc_previsiones cc
    where cc.nro_cuenta = p_nro_cuenta
      and cc.fecha = (select max(cp.fecha)
                        from cc_previsiones cp
                       where cp.nro_cuenta = cc.nro_cuenta);
exception
   when no_data_found then
      raise_application_error(-20000,
      'No existe clasificacion para cuenta '||p_nro_cuenta);
END;
/* Obtener datos de la valuaci?n del cr?dito. */
PROCEDURE LP_OBT_VALUACION
 (P_NRO_CUENTA IN CC_CTA_CORRIENTES.NRO_CUENTA%TYPE
 ,RP_PVALU IN OUT CC_VALUACIONES%ROWTYPE
 )
 IS
BEGIN
   -- Resolución N°37
   select cv.nro_cuenta,cv.fecha,cv.estado,cv.sal_total,cv.sal_retenido,round(cv.cat_automatica) cat_automatica,
          cv.situacion,cv.cotizacion,cv.cot_anterior,cv.tot_valuacion, cv.tot_prevision, cv.tot_val_prevision, cv.tot_val_general
     into rp_pvalu.nro_cuenta,rp_pvalu.fecha,rp_pvalu.estado,rp_pvalu.sal_total,rp_pvalu.sal_retenido,rp_pvalu.cat_automatica,
          rp_pvalu.situacion,rp_pvalu.cotizacion,rp_pvalu.cot_anterior,rp_pvalu.tot_valuacion,
          rp_pvalu.tot_prevision, rp_pvalu.tot_val_prevision, rp_pvalu.tot_val_general
     from cc_valuaciones cv
    where cv.nro_cuenta = p_nro_cuenta;
    
    if rp_pvalu.estado = 'C' then
       rp_pvalu := null;   
    end if;
exception
   when no_data_found then
      rp_pvalu := null;
END;

/* Actualizar o generar registro de valuacion. */
PROCEDURE LP_ACT_VALUACION
 (P_NRO_CUENTA IN CC_CTA_CORRIENTES.NRO_CUENTA%TYPE
 ,P_FECHA IN CC_VALUACIONES.FECHA%TYPE
 ,P_COTIZACION IN NUMBER
 ,RP_PVALU IN CC_VALUACIONES%ROWTYPE
 ,RP_PCPRE IN CC_CTA_CORRIENTES%ROWTYPE
 ,RP_GCOPE IN GE_CLA_OPERACIONES%ROWTYPE
 )
 IS
BEGIN
   update cc_valuaciones
      set fecha                = p_fecha,
          estado               = rp_pcpre.estado,
          cat_automatica       = rp_gcope.cat_automatica,
          situacion            = rp_gcope.cod_estado,
          cot_anterior         = rp_pvalu.cot_anterior,
          cotizacion           = p_cotizacion,
          sal_total            = (nvl(rp_pcpre.sal_total,0) - nvl(rp_pcpre.sal_bloqueado,0) - nvl(rp_pcpre.sal_retenido,0)), 
          sal_retenido         = nvl(rp_pcpre.sal_retenido,0),
          tot_valuacion        = nvl(rp_pvalu.tot_valuacion,0),
          tot_prevision        = nvl(rp_gcope.tot_prevision,0),
          tot_val_prevision    = nvl(rp_pvalu.tot_val_prevision,0),
          tot_val_general      = nvl(rp_pvalu.tot_val_general,0)
    where nro_cuenta = p_nro_cuenta;
   if sql%notfound then
      insert into cc_valuaciones
         (nro_cuenta, fecha, estado,
          cat_automatica, situacion, cotizacion,
          sal_total, sal_retenido,
          tot_valuacion, tot_prevision, tot_val_prevision, tot_val_general)
      values
          (p_nro_cuenta, p_fecha, rp_pcpre.estado,
           rp_gcope.cat_automatica, rp_gcope.cod_estado, p_cotizacion,
           (nvl(rp_pcpre.sal_total,0) - nvl(rp_pcpre.sal_bloqueado,0) - nvl(rp_pcpre.sal_retenido,0)),
           (nvl(rp_pcpre.sal_retenido,0)),
           (nvl(rp_pvalu.tot_valuacion,0)),
           (nvl(rp_gcope.tot_prevision,0)),
           (nvl(rp_pvalu.tot_val_prevision,0)),
           (nvl(rp_pvalu.tot_val_general,0))
           );
   end if;
END;

--Obtener la situación del sobregiro.
FUNCTION LF_OBT_EST_SOBREGIRO(P_NRO_CUENTA IN CC_CTA_CORRIENTES.NRO_CUENTA%TYPE)
RETURN VARCHAR2
AS
v_sit_deuda cc_sobregiros_res.sit_deuda%type;
BEGIN
      select csr.sit_deuda
        into v_sit_deuda
       from cc_sobregiros_res csr
       where csr.nro_cuenta = P_NRO_CUENTA;
       
       return v_sit_deuda;
    
EXCEPTION
  WHEN OTHERS THEN
     RETURN null;
END;

--PROCESO PRINCIPAL.
BEGIN
   pag_cal.pr_obt_dat_calendar(4);
   v_cod_mon_local := pag_gen.fu_obt_mon_local;
   v_fecha         := pag_cal.G_FEC_ACTUAL;
   v_fec_anterior  := pag_cal.g_fec_anterior;

   --v_hora          := fug_ini_hora(sysdate,'hh24:mi:ss');
   v_hora := to_char(sysdate,'hh24:mi:ss');
   v_hora := fug_obt_hor_disponible(v_fecha,v_hora,user,'N');
   v_nro_secuencia := 0;
   v_redondeo_ml   := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',4,41,v_cod_mon_local);
   --- Paso al histórico las valuaciones actuales
   insert into cc_valuaciones_his
      select *
        from cc_valuaciones v
       where fecha = pag_cal.G_FEC_ANTERIOR;
   --- OBS: Se hace toda a las transacciones 152 y 153 para asentar solo el neto
   --- previsiones, a devengar y suspenso son contrarios a capital e interes por
   --- eso se pone la inversa las ganancias y pérdidas(esto es para préstamosbdextrqa)
   for cta in c_cta_valuar loop
      --Asigno el estado de la cuenta.
      cta.estado := nvl(LF_OBT_EST_SOBREGIRO(cta.nro_cuenta),cta.estado);
      --- Recuperar datos de la clasificacion
      lp_obt_clasificacion(cta.nro_cuenta, r_gcope);
      --- Recuperar datos de la valuacion
      r_pvalc         := null;      
      v_tot_acumulado := 0;
      lp_obt_valuacion(cta.nro_cuenta, r_pvalu);
      v_tot_acumulado := abs(nvl(r_pvalu.sal_total,0)) - nvl(r_pvalu.tot_prevision,0);
      --- Recuperar cotizacion de la moneda
      v_cotizacion := fug_obt_cotizacion(cta.cod_moneda, v_fecha);
      -- Verificar si corresponde valuar
      if nvl(cta.sal_total,-1)    <> nvl(r_pvalu.sal_total,-1)
      or r_gcope.cod_estado <> r_pvalu.situacion
      --
      or r_gcope.cat_automatica   <> r_pvalu.cat_automatica
         --- Si nunca proceso la cotizacion es igual a la contabilizada no es necesario hacer
      or nvl(v_cotizacion,-1)     <> nvl(r_pvalu.cotizacion,v_cotizacion) then
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
         r_gmovi.cod_tra_padre  := 155; 
         r_gmovi.cod_mod_padre  := cta.cod_modulo;
         r_gmovi.cod_mad_padre  := cta.cod_modalidad;
         r_gmovi.cod_modulo     := cta.cod_modulo;
         r_gmovi.cod_modalidad  := cta.cod_modalidad;

         --si ya no esta en sobregiro, se debe comportar como una cancelacion
         if nvl(cta.sal_total,0) - nvl(cta.sal_retenido,0) - nvl(cta.sal_bloqueado,0) >= 0 then
            v_sin_sobregiro := 'S';
         else
            v_sin_sobregiro := 'N';
         end if;
         
         --- Procesar  (151,152,153)
         v_pag_capital := 0;
         v_dif_capital := 0;
         v_cam_situacion := 'N';
         if nvl(cta.sal_total,0) - nvl(cta.sal_retenido,0) - nvl(cta.sal_bloqueado,0) > 0 then
            v_sal_total := 0;
         else
            v_sal_total := abs(nvl(cta.sal_total,0) - nvl(cta.sal_retenido,0) - nvl(cta.sal_bloqueado,0));
         end if;
         --si valuo en suspenso y cambia de situacion
         If (nvl(r_pvalu.situacion,'S') not in ('S','C') or nvl(r_pvalu.cat_automatica,1) not in (1,2)) and
            (nvl(r_gcope.cod_estado,'S') in ('S','C') and nvl(r_gcope.cat_automatica,1) in (1,2)) then
            v_cam_situacion := 'S';
         End if;
         ---
         if cta.estado <> 'C' then 
            v_dif_capital := round(v_sal_total * (v_cotizacion - nvl(r_pvalu.cotizacion,v_cotizacion)),v_redondeo_ml);
         else
            v_dif_capital := round(abs(nvl(r_pvalu.sal_total,0)) * (v_cotizacion - nvl(r_pvalu.cotizacion,v_cotizacion)),v_redondeo_ml);
         end if;
         -- Obtengo el importe del depósito realizado.
         if nvl(r_pvalu.sal_total,0) <> 0 and nvl(cta.sal_total,0) < 0 and nvl(v_tot_acumulado,0) <> 0 then
            v_mto_ori_capital := nvl(cta.sal_total,0) - nvl(r_pvalu.sal_total,0);
            v_pag_capital := round(nvl(r_pvalu.tot_val_general, 0) * nvl(v_mto_ori_capital, 0) / abs(nvl(v_tot_acumulado,0)),v_redondeo_ml);
            if v_pag_capital < 0 then
               v_pag_capital := 0;
            end if;
         end if;
         if v_sin_sobregiro = 'S' then
            v_pag_capital := 0;
         end if;
         -- Genero el movimiento por el pago
         if nvl(v_pag_capital,0) <> 0 then
            -- Acredito Ganancia.
            v_nro_secuencia         := v_nro_secuencia + 1;
            r_gmovi.nro_secuencia   := v_nro_secuencia;
            r_gmovi.concepto        := 'Deposito - Cta Cte';
            r_gmovi.est_cuenta      := 'C';
            r_gmovi.nro_documento2  := r_gcope.cat_automatica;
            r_gmovi.monto           := nvl(v_pag_capital,0);
            r_gmovi.cod_moneda      := v_cod_mon_local;
            r_gmovi.mto_equ_local   := null; 
            r_gmovi.cod_transaccion := 152;
            pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
            -- Debito valuacion.
            v_nro_secuencia         := v_nro_secuencia + 1;
            r_gmovi.nro_secuencia   := v_nro_secuencia;
            r_gmovi.concepto        := 'Desaf. por Deposito - Cta Cte';
            if cta.estado = 'C' or v_sin_sobregiro = 'S' then
               r_gmovi.est_cuenta      := nvl(r_pvalu.situacion,cta.estado);                  
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
         if v_dif_capital <> 0 or cta.estado = 'C' or v_sin_sobregiro = 'S' or v_cam_situacion = 'S' then
            if v_dif_capital > 0 then 
               v_nro_secuencia       := v_nro_secuencia + 1;
               r_gmovi.nro_secuencia := v_nro_secuencia;
               r_gmovi.concepto        := 'Ganancia por dif. de cambio';
               If cta.estado = 'C' or v_sin_sobregiro = 'S' Then
                  r_gmovi.est_cuenta      := nvl(r_pvalu.situacion,cta.estado);                  
               else
                  r_gmovi.est_cuenta      := cta.estado;
               end if;
               r_gmovi.nro_documento2  := r_gcope.cat_automatica;
               r_gmovi.monto           := v_dif_capital;
               r_gmovi.cod_moneda      := v_cod_mon_local;
               r_gmovi.mto_equ_local   := null; 
               r_gmovi.cod_transaccion := 152;
               pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
               --- Verifica si se cancelo o se cambio de estado debe reconocer la ganancia.
               if (nvl(r_pvalu.tot_valuacion,0) > 0 or cta.estado = 'C' or v_sin_sobregiro = 'S') and
                 (v_cam_situacion = 'S' or cta.estado = 'C' or v_sin_sobregiro = 'S') then
                v_nro_secuencia         := v_nro_secuencia + 1;
                r_gmovi.nro_secuencia   := v_nro_secuencia;
                r_gmovi.concepto        := 'Desafectacion ganancia';
                r_gmovi.cod_moneda      := v_cod_mon_local;
                If cta.estado = 'C' or v_sin_sobregiro = 'S' Then
                  r_gmovi.est_cuenta      := nvl(r_pvalu.situacion,cta.estado);
                else
                   r_gmovi.est_cuenta      := cta.estado;
                end if;
                r_gmovi.nro_documento2  := nvl(r_pvalu.cat_automatica,r_gcope.cat_automatica);
                If cta.estado = 'C' or v_sin_sobregiro = 'S' then
                   r_gmovi.monto := (nvl(r_pvalu.tot_valuacion,0) + v_dif_capital) * -1;
                Else
                   r_gmovi.monto := (nvl(r_pvalu.tot_valuacion,0) * -1);
                End if;                
                r_gmovi.mto_equ_local   := null;
                r_gmovi.cod_transaccion := 152;
                pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
                --- Afecta a cartera por el mismo importe.
                v_nro_secuencia         := v_nro_secuencia + 1;
                r_gmovi.nro_secuencia   := v_nro_secuencia;
                r_gmovi.concepto        := 'Act. por dif. de cambio';
                r_gmovi.est_cuenta      := cta.estado;
                r_gmovi.nro_documento2  := r_gcope.cat_automatica;
                r_gmovi.cod_transaccion := 152; -- Cartera
                r_gmovi.cod_moneda      := v_cod_mon_local;
                If cta.estado = 'C' or v_sin_sobregiro = 'S' then
                   r_gmovi.monto := (nvl(r_pvalu.tot_valuacion,0) + v_dif_capital);
                Else
                   r_gmovi.monto := (nvl(r_pvalu.tot_valuacion,0));
                End if;                
                r_gmovi.mto_equ_local   := null;
                pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
               end if;               
            elsif v_dif_capital < 0 then
               if nvl(r_pvalu.tot_valuacion,0) > 0 then
                  if abs(v_dif_capital) > nvl(r_pvalu.tot_valuacion,0) then
                    --- Desafectar ganancia y el resto va a perdida
                    v_nro_secuencia         := v_nro_secuencia + 1;
                    r_gmovi.nro_secuencia   := v_nro_secuencia;
                    r_gmovi.concepto        := 'Desafectacion ganancia ';
                    r_gmovi.cod_moneda      := v_cod_mon_local;
                    If cta.estado = 'C' or v_sin_sobregiro = 'S' Then
                      r_gmovi.est_cuenta      := nvl(r_pvalu.situacion,cta.estado);
                    else
                      r_gmovi.est_cuenta      := cta.estado;
                    end if;
                    r_gmovi.nro_documento2  := nvl(r_pvalu.cat_automatica,r_gcope.cat_automatica);
                    r_gmovi.monto           := (nvl(r_pvalu.tot_valuacion,0)*-1);
                    r_gmovi.mto_equ_local   := null;
                    r_gmovi.cod_transaccion := 152;
                    pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
                    ----
                    v_nro_secuencia         := v_nro_secuencia + 1;
                    r_gmovi.nro_secuencia   := v_nro_secuencia;
                    r_gmovi.concepto        := 'Perdida por dif. de cambio';
                    If cta.estado = 'C' or v_sin_sobregiro = 'S' Then
                      r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
                    else
                      r_gmovi.est_cuenta      := cta.estado;
                    end if;
                    r_gmovi.nro_documento2  := r_gcope.cat_automatica;
                    r_gmovi.monto           := abs(nvl(v_dif_capital,0)) - abs(nvl(r_pvalu.tot_valuacion,0));
                    r_gmovi.cod_moneda      := v_cod_mon_local;
                    r_gmovi.mto_equ_local   := null;
                    r_gmovi.cod_transaccion := 153;  --- Perdida
                    pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
                  else
                    --- Si es menor al monto valuado debe desafectar 
                    v_nro_secuencia         := v_nro_secuencia + 1;
                    r_gmovi.nro_secuencia   := v_nro_secuencia;
                    r_gmovi.concepto        := 'Desafectacion ganancia';
                    r_gmovi.cod_moneda      := v_cod_mon_local;
                    If cta.estado = 'C' or v_sin_sobregiro = 'S' Then
                      r_gmovi.est_cuenta      := nvl(r_pvalu.situacion,cta.estado);
                    else
                      r_gmovi.est_cuenta      := cta.estado;
                    end if;
                    r_gmovi.nro_documento2  := nvl(r_pvalu.cat_automatica,r_gcope.cat_automatica);
                    r_gmovi.monto           := (nvl(v_dif_capital,0));
                    r_gmovi.mto_equ_local   := null;
                    r_gmovi.cod_transaccion := 152;
                    pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');                     
                  end if;
                  --- Verifica si se cancelo o se cambio de estado debe reconocer la ganancia.
                  if nvl(v_dif_capital,0) + nvl(r_pvalu.tot_valuacion,0) > 0 and
                     (v_cam_situacion = 'S' or cta.estado = 'C' or v_sin_sobregiro = 'S') then
                    v_nro_secuencia         := v_nro_secuencia + 1;
                    r_gmovi.nro_secuencia   := v_nro_secuencia;
                    r_gmovi.concepto        := 'Desafectacion ganancia';
                    r_gmovi.cod_moneda      := v_cod_mon_local;
                    If cta.estado = 'C' Then
                       r_gmovi.est_cuenta      := nvl(r_pvalu.situacion,cta.estado);
                    else
                       r_gmovi.est_cuenta      := cta.estado;
                    end if;
                    r_gmovi.nro_documento2  := nvl(r_pvalu.cat_automatica,r_gcope.cat_automatica);
                    r_gmovi.monto           := ((nvl(v_dif_capital,0) + nvl(r_pvalu.tot_valuacion,0)) * -1);
                    r_gmovi.mto_equ_local   := null;
                    r_gmovi.cod_transaccion := 152;
                    pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
                    --- Afecta a cartera por el mismo importe.
                    v_nro_secuencia         := v_nro_secuencia + 1;
                    r_gmovi.nro_secuencia   := v_nro_secuencia;
                    r_gmovi.concepto        := 'Act. por dif. de cambio';
                    r_gmovi.est_cuenta      := cta.estado;
                    r_gmovi.nro_documento2  := r_gcope.cat_automatica;
                    r_gmovi.cod_transaccion := 152; -- Cartera
                    r_gmovi.cod_moneda      := v_cod_mon_local;
                    r_gmovi.monto           := (nvl(v_dif_capital,0) + nvl(r_pvalu.tot_valuacion,0));
                    r_gmovi.mto_equ_local   := null;
                    pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
                  end if;
               else --- Todo a perdida
                  v_nro_secuencia         := v_nro_secuencia + 1;
                  r_gmovi.nro_secuencia   := v_nro_secuencia;
                  r_gmovi.concepto        := 'Perdida por dif. de cambio';
                  If cta.estado = 'C' or v_sin_sobregiro = 'S' Then
                    r_gmovi.est_cuenta      := nvl(r_pvalu.situacion,cta.estado);
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
              --- Verifica si se cancelo o se cambio de estado debe reconocer la ganancia.
              if nvl(r_pvalu.tot_valuacion,0) > 0 and
                 (v_cam_situacion = 'S' or cta.estado = 'C' or v_sin_sobregiro = 'S') then
                v_nro_secuencia         := v_nro_secuencia + 1;
                r_gmovi.nro_secuencia   := v_nro_secuencia;
                r_gmovi.concepto        := 'Desafectacion ganancia';
                r_gmovi.cod_moneda      := v_cod_mon_local;
                If cta.estado = 'C' or v_sin_sobregiro = 'S' Then
                   r_gmovi.est_cuenta      := nvl(r_pvalu.situacion,cta.estado);
                else
                   r_gmovi.est_cuenta      := cta.estado;
                end if;
                r_gmovi.nro_documento2  := nvl(r_pvalu.cat_automatica,r_gcope.cat_automatica);
                r_gmovi.monto           := (nvl(r_pvalu.tot_valuacion,0) * -1);
                r_gmovi.mto_equ_local   := null;
                r_gmovi.cod_transaccion := 152;
                pag_gen.pr_ins_ge_movimiento(r_gmovi,'N'); 
                --- Afecta a cartera por el mismo importe.
                v_nro_secuencia         := v_nro_secuencia + 1;
                r_gmovi.nro_secuencia   := v_nro_secuencia;
                r_gmovi.concepto        := 'Act. por dif. de cambio';
                r_gmovi.est_cuenta      := cta.estado;
                r_gmovi.nro_documento2  := r_gcope.cat_automatica;
                r_gmovi.cod_transaccion := 152; -- Cartera
                r_gmovi.cod_moneda      := v_cod_mon_local;
                r_gmovi.monto           := (nvl(r_pvalu.tot_valuacion,0));
                r_gmovi.mto_equ_local   := null;
                pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
              end if;
            end if;
            if (nvl(r_gcope.cod_estado,'S') in ('S','C') and
                nvl(r_gcope.cat_automatica,1) in (1,2) ) or
                cta.estado = 'C' or v_sin_sobregiro = 'S' then
               --- No es necesario acumular el saldo cuando va todo a perdida o
               --- son cuentas que generan directamente ganancia o perdida
               r_pvalc.tot_valuacion := 0;
            else --- Acumular saldos solo para cuentas a valuar en suspenso
               r_pvalc.tot_valuacion := nvl(r_pvalu.tot_valuacion,0) + (nvl(v_dif_capital,0) - nvl(v_pag_capital,0));
            end if;
            --- Generar movimiento por la cartera por la diferencia de cotizacion.
            if nvl(v_dif_capital,0) != 0 then
              v_nro_secuencia         := v_nro_secuencia + 1;
              r_gmovi.nro_secuencia   := v_nro_secuencia;
              r_gmovi.monto           := 0;
              r_gmovi.cod_moneda      := cta.cod_moneda;
              r_gmovi.mto_equ_local   := nvl(v_dif_capital,0);
              r_gmovi.concepto        := 'Act. por dif. de cambio';
              r_gmovi.est_cuenta      := nvl(r_pvalu.situacion,cta.estado);
              r_gmovi.nro_documento2  := r_gcope.cat_automatica;
              r_gmovi.cod_transaccion := 151; -- Cartera
              pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
            end if;
         else
            r_pvalc.tot_valuacion := nvl(r_pvalu.tot_valuacion,0);
         end if;
         ----------------------------------------------------
         --- Procesar PREVISIONES (166,167,168)
         ----------------------------------------------------
         v_pag_prevision := 0;
         v_dif_prevision := 0;
         v_cam_situacion := 'N';
         If (nvl(r_pvalu.situacion,'S') not in ('S','C') or nvl(r_pvalu.cat_automatica,1) not in (1,2)) and
            (nvl(r_gcope.cod_estado,'S') in ('S','C') and nvl(r_gcope.cat_automatica,1) in (1,2)) then
            v_cam_situacion := 'S';
         End if;
         ---         
         if cta.estado <> 'C' then
            v_dif_prevision := round((nvl(r_gcope.tot_prevision,0) * (v_cotizacion - nvl(r_pvalu.cotizacion,v_cotizacion))),v_redondeo_ml);
         else
            v_dif_prevision := round((nvl(r_pvalu.tot_prevision,0) * (v_cotizacion - nvl(r_pvalu.cotizacion,v_cotizacion))),v_redondeo_ml);
         end if;
         --
         if (nvl(r_pvalu.tot_prevision, 0) != 0 and nvl(r_gcope.tot_prevision,0) = 0) then
            v_dif_prevision := 0;
         end if;
         -- Obtengo el importe de desafectación de Previsiones.
         v_mto_ori_prevision := nvl(r_gcope.tot_prevision,0) - nvl(r_pvalu.tot_prevision,0);
         if v_mto_ori_prevision < 0 then
            v_mto_ori_prevision := abs(v_mto_ori_prevision);
         else
            v_mto_ori_prevision := 0;
         end if;
         --
         if nvl(r_pvalu.tot_prevision,0) <> 0 and  nvl(v_mto_ori_prevision, 0) <> 0 and nvl(v_tot_acumulado,0) <> 0 then
            v_pag_prevision := round(nvl(r_pvalu.tot_val_general, 0) * nvl(v_mto_ori_prevision, 0) / nvl(v_tot_acumulado,0),v_redondeo_ml);
         end if;
         -- Obtiene el monto de constitución de Previsiones.
         if v_pag_prevision = 0 and nvl(r_gcope.tot_prevision,0) > nvl(r_pvalu.tot_prevision,0) 
         and nvl(r_gcope.tot_prevision,0) <> 0 and nvl(v_tot_acumulado,0) <> 0 then
            v_mto_ori_prevision := nvl(r_pvalu.tot_prevision,0) - nvl(r_gcope.tot_prevision,0);
            if v_mto_ori_prevision <> 0 then               
               v_pag_prevision := round(nvl(r_pvalu.tot_val_general, 0) * nvl(v_mto_ori_prevision, 0) / nvl(v_tot_acumulado,0),v_redondeo_ml);               
            end if;
         end if; 
         if v_sin_sobregiro = 'S' then
            v_pag_prevision := 0;
         end if;
         -- Genero el movimiento por el aumento o disminución de la previsión.
         if nvl(v_pag_prevision,0) <> 0 then
            if nvl(v_pag_prevision,0) > 0 then
               -- Acredito Valuación.
               v_nro_secuencia         := v_nro_secuencia + 1;
               r_gmovi.nro_secuencia   := v_nro_secuencia;
               r_gmovi.concepto        := 'Disminución Prev. Cta. Cte.';
               If cta.estado = 'C' or v_sin_sobregiro = 'S' Then
                  r_gmovi.est_cuenta      := nvl(r_pvalu.situacion,cta.estado);                  
               else
                  r_gmovi.est_cuenta      := cta.estado;
               end if;
               r_gmovi.nro_documento2  := r_gcope.cat_automatica;
               r_gmovi.monto           := v_pag_prevision;
               r_gmovi.cod_moneda      := v_cod_mon_local;
               r_gmovi.mto_equ_local   := null;
               r_gmovi.cod_transaccion := 9152;
               pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
               -- Debito Pérdida.
               v_nro_secuencia         := v_nro_secuencia + 1;
               r_gmovi.nro_secuencia   := v_nro_secuencia;
               r_gmovi.concepto        := 'Disminución Prev. Cta. Cte.';
               If cta.estado = 'C' or v_sin_sobregiro = 'S' Then
                  r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
               else
                  r_gmovi.est_cuenta      := cta.estado;
               end if;
               r_gmovi.nro_documento2  := r_gcope.cat_automatica;
               r_gmovi.monto           := v_pag_prevision;
               r_gmovi.cod_moneda      := v_cod_mon_local;
               r_gmovi.mto_equ_local   := null;
               r_gmovi.cod_transaccion := 9153;
               pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
            elsif nvl(v_pag_prevision,0) < 0 and nvl(r_gcope.tot_prevision,0) <= nvl(r_pvalu.tot_prevision,0) then
               -- Acredito valuación.
               v_nro_secuencia         := v_nro_secuencia + 1;
               r_gmovi.nro_secuencia   := v_nro_secuencia;
               r_gmovi.concepto        := 'Disminución Prev. Cta. Cte.';
               If cta.estado = 'C' or v_sin_sobregiro = 'S' Then
                  r_gmovi.est_cuenta      := nvl(r_pvalu.situacion,cta.estado);                  
               else
                  r_gmovi.est_cuenta      := cta.estado;
               end if;
               r_gmovi.nro_documento2  := r_gcope.cat_automatica;
               r_gmovi.monto           := abs(nvl(v_pag_prevision,0));
               r_gmovi.cod_moneda      := v_cod_mon_local;
               r_gmovi.mto_equ_local   := null;
               r_gmovi.cod_transaccion := 9152;
               pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
               -- Debito Pérdida.
               v_nro_secuencia         := v_nro_secuencia + 1;
               r_gmovi.nro_secuencia   := v_nro_secuencia;
               r_gmovi.concepto        := 'Disminución Prev. Cta. Cte.';
               If cta.estado = 'C' or v_sin_sobregiro = 'S' Then
                  r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
               else
                  r_gmovi.est_cuenta      := cta.estado;
               end if;
               r_gmovi.nro_documento2  := r_gcope.cat_automatica;
               r_gmovi.monto           := abs(nvl(v_pag_prevision,0));
               r_gmovi.cod_moneda      := v_cod_mon_local;
               r_gmovi.mto_equ_local   := null;
               r_gmovi.cod_transaccion := 9153;
               pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
            elsif nvl(v_pag_prevision,0) < 0 and nvl(r_gcope.tot_prevision,0) > nvl(r_pvalu.tot_prevision,0) then 
               -- Debito Valuación.
               v_nro_secuencia         := v_nro_secuencia + 1;
               r_gmovi.nro_secuencia   := v_nro_secuencia;
               r_gmovi.concepto        := 'Aumento Prev. Cta. Cte.';
               If cta.estado = 'C' or v_sin_sobregiro = 'S' Then
                  r_gmovi.est_cuenta      := nvl(r_pvalu.situacion,cta.estado);                  
               else
                  r_gmovi.est_cuenta      := cta.estado;
               end if;
               r_gmovi.nro_documento2  := r_gcope.cat_automatica;
               r_gmovi.monto           := nvl(v_pag_prevision,0);
               r_gmovi.cod_moneda      := v_cod_mon_local;
               r_gmovi.mto_equ_local   := null;
               r_gmovi.cod_transaccion := 9152;
               pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
               -- Acredito Ganancia.
               v_nro_secuencia         := v_nro_secuencia + 1;
               r_gmovi.nro_secuencia   := v_nro_secuencia;
               r_gmovi.concepto        := 'Aumento Prev. Cta. Cte.';
               r_gmovi.est_cuenta      := 'C';
               r_gmovi.nro_documento2  := r_gcope.cat_automatica;
               r_gmovi.monto           := nvl(v_pag_prevision,0) * (-1);
               r_gmovi.cod_moneda      := v_cod_mon_local;
               r_gmovi.mto_equ_local   := null;
               r_gmovi.cod_transaccion := 9152;
               pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
            end if;
         end if;
         --
         v_dif_prevision :=  v_dif_prevision * (-1);
         if v_dif_prevision <> 0 or cta.estado = 'C' or v_sin_sobregiro = 'S' or v_cam_situacion = 'S' then
            if v_dif_prevision > 0 then 
               v_nro_secuencia       := v_nro_secuencia + 1;
               r_gmovi.nro_secuencia := v_nro_secuencia;
               r_gmovi.concepto        := 'Ganancia por dif. de cambio';
               If cta.estado = 'C' or v_sin_sobregiro = 'S' Then
                  r_gmovi.est_cuenta      := nvl(r_pvalu.situacion,cta.estado);                  
               else
                  r_gmovi.est_cuenta      := cta.estado;
               end if;
               r_gmovi.nro_documento2  := r_gcope.cat_automatica;
               r_gmovi.monto           := v_dif_prevision;
               r_gmovi.cod_moneda      := v_cod_mon_local;
               r_gmovi.mto_equ_local   := null; 
               r_gmovi.cod_transaccion := 9152;
               pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
               --- Verifica si se canceló o se cambió de estado debe reconocer la ganancia.
               if (nvl(r_pvalu.tot_val_prevision,0) > 0 or cta.estado = 'C' or v_sin_sobregiro = 'S') and
                 (v_cam_situacion = 'S' or cta.estado = 'C' or v_sin_sobregiro = 'S') then
                v_nro_secuencia         := v_nro_secuencia + 1;
                r_gmovi.nro_secuencia   := v_nro_secuencia;
                r_gmovi.concepto        := 'Actualiza Valuacion - Pre.';
                r_gmovi.cod_moneda      := v_cod_mon_local;
                r_gmovi.est_cuenta      := nvl(r_pvalu.situacion,cta.estado);                                                 
                r_gmovi.nro_documento2  := nvl(r_pvalu.cat_automatica,r_gcope.cat_automatica);
                r_gmovi.monto := nvl(r_pvalu.tot_val_prevision,0);
                r_gmovi.mto_equ_local   := null;
                r_gmovi.cod_transaccion := 9152;
                pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
                --- Afecta a resultado por el mismo importe.
                v_nro_secuencia         := v_nro_secuencia + 1;
                r_gmovi.nro_secuencia   := v_nro_secuencia;
                r_gmovi.concepto        := 'Act. por dif. de cambio';
                r_gmovi.est_cuenta      := cta.estado;
                r_gmovi.nro_documento2  := r_gcope.cat_automatica;
                r_gmovi.cod_transaccion := 9152; -- Cartera
                r_gmovi.cod_moneda      := v_cod_mon_local;
                If cta.estado = 'C' or v_sin_sobregiro = 'S' then
                   r_gmovi.monto := (nvl(r_pvalu.tot_val_prevision,0) + v_dif_prevision) * (-1);
                Else
                   r_gmovi.monto := (nvl(r_pvalu.tot_val_prevision,0)) * (-1);
                End if;                
                r_gmovi.mto_equ_local   := null;
                pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
               end if;               
            elsif v_dif_prevision < 0 then
               if nvl(r_pvalu.tot_val_prevision,0) > 0 then
                  if abs(v_dif_prevision) > nvl(r_pvalu.tot_val_prevision,0) then
                    --- Desafectar ganancia y el resto va a pérdida
                    v_nro_secuencia         := v_nro_secuencia + 1;
                    r_gmovi.nro_secuencia   := v_nro_secuencia;
                    r_gmovi.concepto        := 'Desafectacion ganancia ';
                    r_gmovi.cod_moneda      := v_cod_mon_local;
                    If cta.estado = 'C' or v_sin_sobregiro = 'S' Then
                      r_gmovi.est_cuenta      := nvl(r_pvalu.situacion,cta.estado);
                    else
                      r_gmovi.est_cuenta      := cta.estado;
                    end if;
                    r_gmovi.nro_documento2  := nvl(r_pvalu.cat_automatica,r_gcope.cat_automatica);
                    r_gmovi.monto           := (nvl(r_pvalu.tot_val_prevision,0)*-1);
                    r_gmovi.mto_equ_local   := null;
                    r_gmovi.cod_transaccion := 9152;
                    pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
                    ----
                    v_nro_secuencia         := v_nro_secuencia + 1;
                    r_gmovi.nro_secuencia   := v_nro_secuencia;
                    r_gmovi.concepto        := 'Perdida por dif. de cambio';
                    If cta.estado = 'C' or v_sin_sobregiro = 'S' Then
                      r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
                    else
                      r_gmovi.est_cuenta      := cta.estado;
                    end if;
                    r_gmovi.nro_documento2  := r_gcope.cat_automatica;
                    r_gmovi.monto           := abs(nvl(v_dif_prevision,0)) - abs(nvl(r_pvalu.tot_val_prevision,0));
                    r_gmovi.cod_moneda      := v_cod_mon_local;
                    r_gmovi.mto_equ_local   := null;
                    r_gmovi.cod_transaccion := 9153;  --- Perdida
                    pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
                  else
                    --- Si es menor al monto valuado debe desafectar 
                    v_nro_secuencia         := v_nro_secuencia + 1;
                    r_gmovi.nro_secuencia   := v_nro_secuencia;
                    r_gmovi.concepto        := 'Desafectacion ganancia';
                    r_gmovi.cod_moneda      := v_cod_mon_local;
                    If cta.estado = 'C' or v_sin_sobregiro = 'S' Then
                      r_gmovi.est_cuenta      := nvl(r_pvalu.situacion,cta.estado);
                    else
                      r_gmovi.est_cuenta      := cta.estado;
                    end if;
                    r_gmovi.nro_documento2  := nvl(r_pvalu.cat_automatica,r_gcope.cat_automatica);
                    r_gmovi.monto           := (nvl(v_dif_prevision,0));
                    r_gmovi.mto_equ_local   := null;
                    r_gmovi.cod_transaccion := 9152;
                    pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');                     
                  end if;
                  --- Verifica si se canceló o se cambió de estado debe reconocer la ganancia.
                  if nvl(v_dif_prevision,0) + nvl(r_pvalu.tot_val_prevision,0) > 0 and
                     (v_cam_situacion = 'S' or cta.estado = 'C' or v_sin_sobregiro = 'S') then
                    v_nro_secuencia         := v_nro_secuencia + 1;
                    r_gmovi.nro_secuencia   := v_nro_secuencia;
                    r_gmovi.concepto        := 'Desafectacion ganancia';
                    r_gmovi.cod_moneda      := v_cod_mon_local;
                    r_gmovi.est_cuenta      := nvl(r_pvalu.situacion,cta.estado);
                    r_gmovi.nro_documento2  := nvl(r_pvalu.cat_automatica,r_gcope.cat_automatica);
                    r_gmovi.monto           := (nvl(v_dif_prevision,0) + nvl(r_pvalu.tot_val_prevision,0));
                    r_gmovi.mto_equ_local   := null;
                    r_gmovi.cod_transaccion := 9152;
                    pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
                    --- Afecta a cartera por el mismo importe.
                    v_nro_secuencia         := v_nro_secuencia + 1;
                    r_gmovi.nro_secuencia   := v_nro_secuencia;
                    r_gmovi.concepto        := 'Act. por dif. de cambio';
                    r_gmovi.est_cuenta      := cta.estado;
                    r_gmovi.nro_documento2  := r_gcope.cat_automatica;
                    r_gmovi.cod_transaccion := 9152; -- Cartera
                    r_gmovi.cod_moneda      := v_cod_mon_local;
                    r_gmovi.monto        := (nvl(v_dif_prevision,0) + nvl(r_pvalu.tot_val_prevision,0)) * (-1);
                    r_gmovi.mto_equ_local   := null;
                    pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
                  end if;
               else --- Todo a perdida
                  v_nro_secuencia         := v_nro_secuencia + 1;
                  r_gmovi.nro_secuencia   := v_nro_secuencia;
                  r_gmovi.concepto        := 'Perdida por dif. de cambio';
                  If cta.estado = 'C' or v_sin_sobregiro = 'S' Then
                    r_gmovi.est_cuenta      := nvl(r_pvalu.situacion,cta.estado);
                  else
                    r_gmovi.est_cuenta      := cta.estado;
                  end if;
                  r_gmovi.nro_documento2  := r_gcope.cat_automatica;
                  r_gmovi.monto           := abs(v_dif_prevision);
                  r_gmovi.cod_moneda      := v_cod_mon_local;
                  r_gmovi.mto_equ_local   := null; 
                  r_gmovi.cod_transaccion := 9153;
                  pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
               end if;
            else --- NO TUVO DIFERENCIA DE COTIZACION...
              --- Verifica si se canceló o se cambió de estado debe reconocer la ganancia.
              if nvl(r_pvalu.tot_val_prevision,0) > 0 and
                 (v_cam_situacion = 'S' or cta.estado = 'C' or v_sin_sobregiro = 'S') then
                v_nro_secuencia         := v_nro_secuencia + 1;
                r_gmovi.nro_secuencia   := v_nro_secuencia;
                r_gmovi.concepto        := 'Actualiza Valuacion - Pre.';
                r_gmovi.cod_moneda      := v_cod_mon_local;
                r_gmovi.est_cuenta      := nvl(r_pvalu.situacion,cta.estado);
                r_gmovi.nro_documento2  := nvl(r_pvalu.cat_automatica,r_gcope.cat_automatica);
                r_gmovi.monto           := nvl(r_pvalu.tot_val_prevision,0);
                r_gmovi.mto_equ_local   := null;
                r_gmovi.cod_transaccion := 9152;
                pag_gen.pr_ins_ge_movimiento(r_gmovi,'N'); 
                --- Afecta a cartera por el mismo importe.
                v_nro_secuencia         := v_nro_secuencia + 1;
                r_gmovi.nro_secuencia   := v_nro_secuencia;
                r_gmovi.concepto        := 'Act. por dif. de cambio';
                r_gmovi.est_cuenta      := cta.estado;
                r_gmovi.nro_documento2  := r_gcope.cat_automatica;
                r_gmovi.cod_transaccion := 9152; -- Cartera
                r_gmovi.cod_moneda      := v_cod_mon_local;
                r_gmovi.monto           := (nvl(r_pvalu.tot_val_prevision,0)) * (-1);
                r_gmovi.mto_equ_local   := null;
                pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
              end if;
            end if;
            v_dif_prevision := nvl(v_dif_prevision,0) * (-1);
            if (nvl(r_gcope.cod_estado,'S') in ('S','C') and
                nvl(r_gcope.cat_automatica,1) in (1,2) ) or
                cta.estado = 'C' or v_sin_sobregiro = 'S' then
               --- No es necesario acumular el saldo cuando va todo a perdida o
               --- son cuentas que generan directamente ganancia o perdida
               r_pvalc.tot_val_prevision := 0;
            else --- Acumular saldos solo para cuentas a valuar en suspenso
                  r_pvalc.tot_val_prevision := nvl(r_pvalu.tot_val_prevision,0) + (nvl(v_dif_prevision,0) - nvl(v_pag_prevision,0));
            end if;
            --- Generar movimiento por la cartera por la diferencia de cotización.
            if v_dif_prevision != 0 then
              v_nro_secuencia         := v_nro_secuencia + 1;
              r_gmovi.nro_secuencia   := v_nro_secuencia;
              r_gmovi.monto           := 0;
              r_gmovi.cod_moneda      := cta.cod_moneda;
              r_gmovi.mto_equ_local   := v_dif_prevision;
              r_gmovi.concepto        := 'Act. por dif. de cambio';
              r_gmovi.est_cuenta      := nvl(r_pvalu.situacion,cta.estado);
              r_gmovi.nro_documento2  := r_gcope.cat_automatica;
              r_gmovi.cod_transaccion := 166; -- Cartera
              pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
            end if;
         else 
            r_pvalc.tot_val_prevision := nvl(r_pvalu.tot_val_prevision,0);
         end if;
 
         --- Actualizar valuaciones
         r_pvalc.cot_anterior := r_pvalu.cotizacion;
         -- Obtengo el saldo neto de las valuación.
         r_pvalc.tot_val_general := nvl(r_pvalu.tot_val_general,0) + 
                                  ((nvl(v_dif_capital,0) - nvl(v_pag_capital,0)) - (nvl(v_dif_prevision,0) - nvl(v_pag_prevision,0)));
         if r_pvalc.tot_val_general < 0 or
            (nvl(r_gcope.cod_estado,'S') in ('S','C') and
                nvl(r_gcope.cat_automatica,1) in (1,2) ) or
                cta.estado = 'C' or v_sin_sobregiro = 'S' then
            r_pvalc.tot_val_general := 0;
            r_pvalc.tot_valuacion := 0;
            r_pvalc.tot_val_prevision := 0;
         end if;
         -- Actualizo la tabla cc_valuaciones.
         lp_act_valuacion(cta.nro_cuenta, v_fecha, v_cotizacion, r_pvalc, cta, r_gcope);
         if v_nro_secuencia + 18 > 999 then
            --v_hora          := pag_gen.fu_obt_sig_segundo(v_hora);
            v_hora := fug_obt_hor_disponible(v_fecha,v_hora,user,'N');
            v_nro_secuencia := 0;
         end if;
      end if;
   end loop;
END;
/

