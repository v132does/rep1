CREATE OR REPLACE PROCEDURE IT.PRP_GEN_VALUACIONES
 IS
 
   TYPE t_usu_secuencia IS TABLE OF NUMBER INDEX BY VARCHAR2(50);
   TYPE t_usu_hora      IS TABLE OF GE_MOVIMIENTOS.HORA%TYPE INDEX BY VARCHAR2(30);

   v_usu_secuencia t_usu_secuencia;
   v_usu_hora      t_usu_hora;
   v_can_user      NUMBER;
   v_usuario       VARCHAR2(30);
   
/* Obtener siguiente secuecia */  
PROCEDURE LP_OBT_SECUENCIA (
    P_USUARIO IN VARCHAR2,
    P_SEC OUT NUMBER,
    P_HORA OUT GE_MOVIMIENTOS.HORA%TYPE
 );

/* Obtener datos de la clasificacion del prestamo. */
PROCEDURE LP_OBT_CLASIFICACION
 (P_NRO_CUENTA IN PR_CTA_PRESTAMOS.NRO_CUENTA%TYPE
 ,RP_GCOPE IN OUT GE_CLA_OPERACIONES%ROWTYPE
 );
 
/* Obtener datos de la valuacion del credito. */
PROCEDURE LP_OBT_VALUACION
 (P_NRO_CUENTA IN PR_CTA_PRESTAMOS.NRO_CUENTA%TYPE
 ,RP_PVALU IN OUT PR_VALUACIONES%ROWTYPE
 );
 
/* Actualizar o generar registro de valuacion. */
PROCEDURE LP_ACT_VALUACION
 (P_NRO_CUENTA IN PR_CTA_PRESTAMOS.NRO_CUENTA%TYPE
 ,P_FECHA IN PR_VALUACIONES.FECHA%TYPE
 ,P_COTIZACION IN NUMBER
 ,RP_PVALU IN PR_VALUACIONES%ROWTYPE
 ,RP_PCPRE IN PR_CTA_PRESTAMOS%ROWTYPE
 ,RP_GCOPE IN GE_CLA_OPERACIONES%ROWTYPE
 );
   --- Este proceso debe ejecutarse luego del:
   --- calculo de cambio de estado del prestamo
   --- clasificacion de riesgos y previsiones
   --- calculo de garantias computables
   ---
   v_cam_situacion varchar2(1);
   v_fecha         ge_movimientos.fecha%type;
   v_cod_mon_local ba_monedas.cod_moneda%type;
   v_cotizacion    ge_cotizaciones.val_conversion%type;
   r_pvalu         pr_valuaciones%rowtype;
   r_pvalc         pr_valuaciones%rowtype;
   r_gcope         ge_cla_operaciones%rowtype;
   r_gmovi         ge_movimientos%rowtype;
   --- Variables del cobro.
   v_mto_capital            ge_movimientos.monto%type;
   v_mto_interes            ge_movimientos.monto%type;
   v_mto_int_adelantado     ge_movimientos.monto%type;
   v_mto_suspenso           ge_movimientos.monto%type;
   v_mto_devengar           ge_movimientos.monto%type;
   v_mto_prevision          ge_movimientos.monto%type;
   v_mto_ori_capital        ge_movimientos.monto%type;
   v_mto_ori_interes        ge_movimientos.monto%type;
   v_mto_ori_int_adelantado ge_movimientos.monto%type;
   v_mto_ori_suspenso       ge_movimientos.monto%type;
   v_mto_ori_devengar       ge_movimientos.monto%type;
   v_mto_ori_prevision      ge_movimientos.monto%type;
   v_tot_acumulado          pr_valuaciones.tot_val_capital%type;
   v_dif_capital            pr_valuaciones.tot_val_capital%type;
   v_dif_interes            pr_valuaciones.tot_val_interes%type;
   v_dif_int_adelantado     pr_valuaciones.tot_val_int_ade%type;
   v_dif_suspenso           pr_valuaciones.tot_val_suspenso%type;
   v_dif_devengar           pr_valuaciones.tot_val_int_devengar%type;
   v_dif_prevision          pr_valuaciones.tot_val_prevision%type;
   v_pag_capital            pr_valuaciones.tot_val_capital%type;
   v_pag_interes            pr_valuaciones.tot_val_capital%type;
   v_pag_int_adelantado     pr_valuaciones.tot_val_capital%type;
   v_pag_suspenso           pr_valuaciones.tot_val_capital%type;
   v_pag_devengar           pr_valuaciones.tot_val_capital%type;
   v_pag_prevision          pr_valuaciones.tot_val_capital%type;
   v_redondeo_ml            number(5);
   -- Variables para seguimiento de progreso 
   v_total_registros        NUMBER := 0;
   v_total_procesado        NUMBER := 0;
   --- Cancelados en el dia se procesa para reconcer la valuacion en suspenso por
   --- diferencia de cambio
   cursor c_pre_valuar is
   select *
     from pr_cta_prestamos p
    where cod_moneda <> v_cod_mon_local
      and ((estado not in ('N','I'))
            or (estado = 'N' and fec_cancelacion = v_fecha));
            
   TYPE t_pre_valuar IS TABLE OF c_pre_valuar%ROWTYPE;
   v_pre_valuar t_pre_valuar;
   cta          c_pre_valuar%ROWTYPE;

/*Control centralizado de secuencia y hora */
PROCEDURE LP_OBT_SECUENCIA (
  P_USUARIO IN VARCHAR2,
  P_SEC OUT NUMBER,
  P_HORA OUT GE_MOVIMIENTOS.HORA%TYPE
) IS
BEGIN
  IF NOT v_usu_secuencia.EXISTS(P_USUARIO) THEN
     v_usu_secuencia(P_USUARIO) := 0;
     v_usu_hora(P_USUARIO)      := PAG_CIE.FU_OBT_HORA(P_USUARIO, 'S_HOR_MOVCIERRE','E');
  END IF;
  -- Reinicia a 1 si alcanza o supera los 995
  IF v_usu_secuencia(P_USUARIO) >= 995 THEN
     v_usu_hora(P_USUARIO)      := PAG_CIE.FU_OBT_HORA(P_USUARIO, 'S_HOR_MOVCIERRE','E');
     v_usu_secuencia(P_USUARIO) := 1;
  ELSE
     v_usu_secuencia(P_USUARIO) := v_usu_secuencia(P_USUARIO) + 1;
  END IF;

  P_SEC  := v_usu_secuencia(P_USUARIO);
  P_HORA := v_usu_hora(P_USUARIO);
END LP_OBT_SECUENCIA;
/* Obtener datos de la clasificacion y prevision del prestamo. */
PROCEDURE LP_OBT_CLASIFICACION
 (P_NRO_CUENTA IN PR_CTA_PRESTAMOS.NRO_CUENTA%TYPE
 ,RP_GCOPE IN OUT GE_CLA_OPERACIONES%ROWTYPE
 )
 IS
BEGIN
   begin
   -- Resolución N°37
   select nro_cuenta, cod_persona, cod_estado, round(NVL(cat_automatica,1)), dia_atraso
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
   ---- Recuperar el valor de la prevision del pr_previsiones
   select nvl(sum(p1.monto),0)
     into rp_gcope.tot_prevision
     from pr_previsiones p1
    where p1.nro_cuenta = p_nro_cuenta
      and p1.fecha = (select max(p2.fecha)
                        from pr_previsiones p2
                       where p2.nro_cuenta = p1.nro_cuenta);
exception
   when no_data_found then
      raise_application_error(-20000,
      'No existe clasificacion para cuenta '||p_nro_cuenta);
END;
/* Obtener datos de la valuacion del credito. */
PROCEDURE LP_OBT_VALUACION
 (P_NRO_CUENTA IN PR_CTA_PRESTAMOS.NRO_CUENTA%TYPE
 ,RP_PVALU IN OUT PR_VALUACIONES%ROWTYPE
 )
 IS
BEGIN
     -- Resolución N°37
     select pv.nro_cuenta, pv.fecha, pv.estado, pv.tipo, pv.tip_interes, pv.tip_renovacion, pv.tip_documento,
            pv.sal_capital, pv.sal_interes, pv.sal_int_adelantado, pv.dev_no_cobrado, pv.tot_gar_computables,
            pv.tot_prevision, round(pv.cat_automatica) cat_automatica, pv.cotizacion, pv.tot_val_capital,
            pv.tot_val_interes, pv.tot_val_int_ade, pv.tot_val_devengado, pv.tot_val_garantia, pv.tot_val_prevision,
            pv.dev_suspenso, pv.tot_val_suspenso, pv.cot_anterior, pv.val_int_devengar, pv.tot_val_int_devengar, pv.tot_valuacion
       into rp_pvalu.nro_cuenta, rp_pvalu.fecha, rp_pvalu.estado, rp_pvalu.tipo, rp_pvalu.tip_interes, rp_pvalu.tip_renovacion,
            rp_pvalu.tip_documento, rp_pvalu.sal_capital, rp_pvalu.sal_interes, rp_pvalu.sal_int_adelantado, rp_pvalu.dev_no_cobrado,
            rp_pvalu.tot_gar_computables, rp_pvalu.tot_prevision, rp_pvalu.cat_automatica, rp_pvalu.cotizacion, rp_pvalu.tot_val_capital,
            rp_pvalu.tot_val_interes, rp_pvalu.tot_val_int_ade, rp_pvalu.tot_val_devengado, rp_pvalu.tot_val_garantia, rp_pvalu.tot_val_prevision,
            rp_pvalu.dev_suspenso, rp_pvalu.tot_val_suspenso, rp_pvalu.cot_anterior, rp_pvalu.val_int_devengar, rp_pvalu.tot_val_int_devengar,
            rp_pvalu.tot_valuacion
       from pr_valuaciones pv
      where pv.nro_cuenta = p_nro_cuenta;

     if rp_pvalu.estado = 'N' then
        rp_pvalu := null;
     end if;
exception
   when no_data_found then
      rp_pvalu := null;
END;
/* Actualizar o generar registro de valuacion. */
PROCEDURE LP_ACT_VALUACION
 (P_NRO_CUENTA IN PR_CTA_PRESTAMOS.NRO_CUENTA%TYPE
 ,P_FECHA IN PR_VALUACIONES.FECHA%TYPE
 ,P_COTIZACION IN NUMBER
 ,RP_PVALU IN PR_VALUACIONES%ROWTYPE
 ,RP_PCPRE IN PR_CTA_PRESTAMOS%ROWTYPE
 ,RP_GCOPE IN GE_CLA_OPERACIONES%ROWTYPE
 )
 IS
BEGIN
       MERGE INTO pr_valuaciones v
      USING (SELECT p_nro_cuenta AS nro_cuenta FROM dual) src
         ON (v.nro_cuenta = src.nro_cuenta)
    WHEN MATCHED THEN
         UPDATE SET
            fecha                = p_fecha,
            estado               = rp_pcpre.estado,
            tipo                 = rp_pcpre.tipo,
            tip_interes          = rp_pcpre.tip_interes,
            tip_renovacion       = rp_pcpre.tip_renovacion,
            tip_documento        = rp_pcpre.tip_documento,
            sal_capital          = NVL(rp_pcpre.sal_capital, 0),
            sal_interes          = NVL(rp_pcpre.sal_interes, 0),
            sal_int_adelantado   = NVL(rp_pcpre.sal_int_adelantado, 0),
            dev_no_cobrado       = NVL(rp_pcpre.dev_no_cobrado, 0),
            dev_suspenso         = NVL(rp_pcpre.dev_suspenso, 0),
            val_int_devengar     = NVL(rp_pcpre.val_int_devengar, 0),
            tot_gar_computables  = NVL(rp_gcope.tot_gar_computables, 0),
            tot_prevision        = NVL(rp_gcope.tot_prevision, 0),
            cat_automatica       = rp_gcope.cat_automatica,
            cot_anterior         = rp_pvalu.cot_anterior,
            cotizacion           = p_cotizacion,
            tot_val_capital      = NVL(rp_pvalu.tot_val_capital, 0),
            tot_val_interes      = NVL(rp_pvalu.tot_val_interes, 0),
            tot_val_int_ade      = NVL(rp_pvalu.tot_val_int_ade, 0),
            tot_val_devengado    = NVL(rp_pvalu.tot_val_devengado, 0),
            tot_val_int_devengar = NVL(rp_pvalu.tot_val_int_devengar, 0),
            tot_val_suspenso     = NVL(rp_pvalu.tot_val_suspenso, 0),
            tot_val_garantia     = NVL(rp_pvalu.tot_val_garantia, 0),
            tot_val_prevision    = NVL(rp_pvalu.tot_val_prevision, 0),
            tot_valuacion        = NVL(rp_pvalu.tot_valuacion, 0)
      WHEN NOT MATCHED THEN
         INSERT (
            nro_cuenta, fecha, estado, tipo, tip_interes, tip_renovacion, tip_documento,
            sal_capital, sal_interes, sal_int_adelantado, dev_no_cobrado,
            val_int_devengar, dev_suspenso, tot_gar_computables, tot_prevision, 
            cat_automatica, cotizacion, tot_val_capital, tot_val_interes, 
            tot_val_int_ade, tot_val_devengado, tot_val_int_devengar, tot_val_suspenso,
            tot_val_garantia, tot_val_prevision, tot_valuacion
         ) VALUES (
            p_nro_cuenta, p_fecha, rp_pcpre.estado, rp_pcpre.tipo, rp_pcpre.tip_interes,
            rp_pcpre.tip_renovacion, rp_pcpre.tip_documento, NVL(rp_pcpre.sal_capital, 0),
            NVL(rp_pcpre.sal_interes, 0), NVL(rp_pcpre.sal_int_adelantado, 0), NVL(rp_pcpre.dev_no_cobrado, 0),
            NVL(rp_pcpre.val_int_devengar, 0), NVL(rp_pcpre.dev_suspenso, 0),
            NVL(rp_gcope.tot_gar_computables, 0), NVL(rp_gcope.tot_prevision, 0), rp_gcope.cat_automatica, p_cotizacion,
            NVL(rp_pvalu.tot_val_capital, 0), NVL(rp_pvalu.tot_val_interes, 0), NVL(rp_pvalu.tot_val_int_ade, 0),
            NVL(rp_pvalu.tot_val_devengado, 0), NVL(rp_pvalu.tot_val_int_devengar, 0), NVL(rp_pvalu.tot_val_suspenso, 0),
            NVL(rp_pvalu.tot_val_garantia, 0), NVL(rp_pvalu.tot_val_prevision, 0), NVL(rp_pvalu.tot_valuacion, 0)
         );
END;

BEGIN
   it.pag_cie.PR_AT_INS_LOG(11,351,'PRP_GEN_VALUACIONES', 'Inicio...', it.pag_cie.c_log_TRACE,'OUT',SYSDATE);
   DBMS_APPLICATION_INFO.SET_ACTION('PRP_GEN_VALUACIONES');
   DBMS_APPLICATION_INFO.SET_CLIENT_INFO('PRP_GEN_VALUACIONES, Iniciando');
   pag_cal.pr_obt_dat_calendar(6);
   v_cod_mon_local := pag_gen.fu_obt_mon_local;
   v_fecha         := pag_cal.G_FEC_ACTUAL;
   v_redondeo_ml   := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',6,null,v_cod_mon_local);
--
   BEGIN
     SELECT COUNT(*)
       INTO v_can_user
       FROM ba_cod_referencias
       WHERE dominio     = 'USU_MOV_CIERRE'
         AND abreviatura = 'MOVCIERRE';
     EXCEPTION
       WHEN OTHERS THEN
         v_can_user := 1;
   END;
   --Obtiene el total de registros a procesar
   BEGIN
     SELECT COUNT(*)
       INTO v_total_registros
       FROM pr_cta_prestamos p
      WHERE cod_moneda <> v_cod_mon_local   
        AND ((estado NOT IN ('N','I'))
              OR (estado = 'N' AND fec_cancelacion = v_fecha));
    END;
   --- Paso al historico las valuaciones actuales
   insert into pr_valuaciones_his
   select * from pr_valuaciones v
    where fecha = pag_cal.G_FEC_ANTERIOR;
    
    DBMS_APPLICATION_INFO.SET_CLIENT_INFO('PRP_GEN_VALUACIONES: ' || v_total_registros || ' regs');
  --- Procesamiento masivo por lotes con BULK COLLECT
   OPEN c_pre_valuar;
   LOOP
      FETCH c_pre_valuar BULK COLLECT INTO v_pre_valuar LIMIT 1000;
      EXIT WHEN v_pre_valuar.COUNT = 0;
      
      FOR i IN 1 .. v_pre_valuar.COUNT LOOP
         cta := v_pre_valuar(i);
         v_total_procesado := v_total_procesado + 1;
         IF MOD(v_total_procesado, 1000) = 0 AND v_total_registros > 0 THEN
            DBMS_APPLICATION_INFO.SET_CLIENT_INFO(
            'Procesado: ' || v_total_procesado || ' de ' || v_total_registros || 
            ' (' || ROUND((v_total_procesado / v_total_registros) * 100, 1) || '%)');
         END IF;
      --- Recuperar datos de la clasificacion
      lp_obt_clasificacion(cta.nro_cuenta, r_gcope);
      --- Recuperar datos de la valuacion
      r_pvalc         := null;
      v_tot_acumulado := 0;
      lp_obt_valuacion(cta.nro_cuenta, r_pvalu);
      --
      v_tot_acumulado := (nvl(r_pvalu.sal_capital,0) + nvl(r_pvalu.sal_interes,0) + nvl(r_pvalu.sal_int_adelantado,0)) -
                          nvl(r_pvalu.tot_prevision,0) - nvl(r_pvalu.dev_suspenso,0) - nvl(r_pvalu.val_int_devengar,0);
      --- Recuperar cotizacion de la moneda
      v_cotizacion := pag_gen.fu_obt_cotizacion(cta.cod_moneda, v_fecha);
      if r_pvalu.cotizacion is null then
         -- No existia antes un registro de esta cuenta, busca si el desembolso se hizo
         -- a una cotizacion determinada...
         Select nvl(max(cotizacion), v_cotizacion)
           into v_cotizacion
           from ge_movimientos
          where nro_cuenta = cta.nro_cuenta
            and cod_tra_padre = 358
            and cotizacion is not null;
         --
      end if;      
      -- Obtiene el importe cobrado de capital.
      v_mto_capital := round((nvl(r_pvalu.sal_capital,0)-nvl(cta.sal_capital,0)),2);
      IF NVL(v_mto_capital,0) <= 0 THEN
         v_mto_capital     := 0;
         v_mto_ori_capital := 0;
      ELSE
         v_mto_ori_capital := NVL(v_mto_capital,0);
         v_mto_capital     := round((NVL(v_mto_capital,0) * nvl(r_pvalu.cotizacion,v_cotizacion)),v_redondeo_ml);
      END IF;
      -- Obtiene el importe cobrado de interes.
      v_mto_interes := round((nvl(r_pvalu.sal_interes,0)-nvl(cta.sal_interes,0)),2);
      IF NVL(v_mto_interes,0) <= 0 THEN
         v_mto_interes     := 0;
         v_mto_ori_interes := 0;
      ELSE
         v_mto_ori_interes := NVL(v_mto_interes,0);
         v_mto_interes     := round((NVL(v_mto_interes,0) * nvl(r_pvalu.cotizacion,v_cotizacion)),v_redondeo_ml);
      END IF;
      -- Obtiene el importe cobrado de interes adelantado.
      v_mto_int_adelantado := round((nvl(r_pvalu.sal_int_adelantado,0)-nvl(cta.sal_int_adelantado,0)),2);
      IF NVL(v_mto_int_adelantado,0) <= 0 THEN
         v_mto_int_adelantado     := 0;
         v_mto_ori_int_adelantado := 0;
      ELSE
         v_mto_ori_int_adelantado := NVL(v_mto_int_adelantado,0);
         v_mto_int_adelantado     := round((NVL(v_mto_int_adelantado,0) * nvl(r_pvalu.cotizacion,v_cotizacion)),v_redondeo_ml);
      END IF;
      -- Obtiene el importe desafectado de previsiones.
      v_mto_prevision := round((nvl(r_pvalu.tot_prevision,0)-nvl(r_gcope.tot_prevision,0)),2);
      IF NVL(v_mto_prevision,0) <= 0 THEN
         v_mto_prevision     := 0;
         v_mto_ori_prevision := 0;
      ELSE
         v_mto_ori_prevision := NVL(v_mto_prevision,0);
         v_mto_prevision     := round((NVL(v_mto_prevision,0) * nvl(r_pvalu.cotizacion,v_cotizacion)),v_redondeo_ml);
      END IF;
      -- Obtiene el importe desafectado de interes a devengar.
      IF round((nvl(cta.dev_suspenso,0)-nvl(r_pvalu.dev_suspenso,0)),2) > 0 AND nvl(r_pvalu.tot_val_suspenso,0) > 0 AND nvl(cta.dev_suspenso,0) <> 0 THEN
         v_mto_devengar := round((nvl(cta.val_int_devengar,0)-nvl(r_pvalu.val_int_devengar,0)),2);
         IF NVL(v_mto_devengar,0) >= 0 THEN
            v_mto_devengar     := 0;
            v_mto_ori_devengar := 0;
         ELSE
            v_mto_ori_devengar := NVL(v_mto_devengar,0);
            v_mto_devengar     := round((NVL(v_mto_devengar,0) * nvl(r_pvalu.cotizacion,v_cotizacion)),v_redondeo_ml);
         END IF;
      ELSIF round((nvl(cta.dev_suspenso,0)-nvl(r_pvalu.dev_suspenso,0)),2) < 0 AND nvl(r_pvalu.tot_val_suspenso,0) > 0 AND nvl(cta.dev_suspenso,0) <> 0 THEN
         v_mto_devengar := round((nvl(cta.val_int_devengar,0)-nvl(r_pvalu.val_int_devengar,0)),2);
         IF NVL(v_mto_devengar,0) >= 0 THEN
            v_mto_devengar     := 0;
            v_mto_ori_devengar := 0;
         ELSE
            v_mto_ori_devengar := NVL(v_mto_devengar,0);
            v_mto_devengar     := round((NVL(v_mto_devengar,0) * nvl(r_pvalu.cotizacion,v_cotizacion)),v_redondeo_ml);
         END IF;
      ELSE
         v_mto_devengar     := 0;
         v_mto_ori_devengar := 0;
      END IF;
      --
      IF round((nvl(cta.dev_suspenso,0)-nvl(r_pvalu.dev_suspenso,0)),2) < 0 AND nvl(r_pvalu.tot_val_suspenso,0) > 0 AND nvl(cta.dev_suspenso,0) <> 0 THEN
         v_mto_ori_suspenso := round((nvl(cta.dev_suspenso,0)-nvl(r_pvalu.dev_suspenso,0)),2);
         v_mto_suspenso     := round((NVL(v_mto_ori_suspenso,0) * nvl(r_pvalu.cotizacion,v_cotizacion)),v_redondeo_ml);
      ELSE
         v_mto_ori_suspenso := 0;
         v_mto_suspenso     := 0;
      END IF;
      --- Verificar si corresponde valuar
      if nvl(cta.sal_capital,-1)             <> nvl(r_pvalu.sal_capital,-1)
      or nvl(cta.sal_interes,-1)             <> nvl(r_pvalu.sal_interes,-1)
      or nvl(cta.sal_int_adelantado,-1)      <> nvl(r_pvalu.sal_int_adelantado,-1)
      or nvl(cta.dev_suspenso,-1)            <> nvl(r_pvalu.dev_suspenso,-1)
      or nvl(cta.val_int_devengar,-1)        <> nvl(r_pvalu.val_int_devengar,-1)
      or nvl(r_gcope.tot_prevision,-1)       <> nvl(r_pvalu.tot_prevision,-1)
      or cta.estado                          <> r_pvalu.estado
      or r_gcope.cat_automatica              <> r_pvalu.cat_automatica
         --- Si nunca proceso la cotizacion es igual a la contabilizada no es necesario hacer
         --- Ejemplo desembolsos
      or nvl(v_cotizacion,-1)                <> nvl(r_pvalu.cotizacion,v_cotizacion) then
                
           v_usuario  := PAG_CIE.FU_OBT_MOV_USER('MOVCIERRE','USU_MOV_CIERRE',V_CAN_USER,'S_USU_MOVCIERRE');          
         --- Existe cambio de valores
         --- Cargar datos por defecto de movimientos
         r_gmovi.fecha          := v_fecha;  
         r_gmovi.cod_usuario    := v_usuario;
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
         ---------------------------------------
         --- Procesar CAPITAL (151,152,153)
         ---------------------------------------
         v_pag_capital   := 0;
         v_dif_capital   := 0;
         v_cam_situacion := 'N';
         If (nvl(r_pvalu.estado,'A') not in ('A','C') or nvl(r_pvalu.cat_automatica,1) not in (1,2)) and
            (nvl(cta.estado,'A') in ('A','C') and nvl(r_gcope.cat_automatica,1) in (1,2)) then
            v_cam_situacion := 'S';
         End if;
         ---
         if cta.estado <> 'N' then
            v_dif_capital := round((nvl(cta.sal_capital,0)*v_cotizacion) - ((nvl(r_pvalu.sal_capital,cta.sal_capital)*nvl(r_pvalu.cotizacion,v_cotizacion)) - v_mto_capital),v_redondeo_ml);
         else
            v_dif_capital := round((nvl(r_pvalu.sal_capital,0)*v_cotizacion) - ((nvl(r_pvalu.sal_capital,cta.sal_capital)*nvl(r_pvalu.cotizacion,v_cotizacion))),v_redondeo_ml);
         end if;
         -- Obtiene el pago del día de la cuenta.
         if nvl(r_pvalu.sal_capital,0) <> 0 and nvl(v_mto_ori_capital, 0) <> 0 and nvl(v_tot_acumulado,0) <> 0 then
            v_pag_capital := round(nvl(r_pvalu.tot_valuacion, 0) * nvl(v_mto_ori_capital, 0) / nvl(v_tot_acumulado,0),v_redondeo_ml);
            if v_pag_capital < 0 then
               v_pag_capital := 0;
            end if;
         end if;
         --
         if cta.estado = 'N' then
            v_pag_capital := 0;
         end if;
         --
         if nvl(v_pag_capital,0) <> 0 then
            -- Acredito Ganancia.             
            LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora); 
            r_gmovi.concepto        := 'Ganancia por Pago - Cap';
            r_gmovi.est_cuenta      := 'N';
            r_gmovi.nro_documento2  := r_gcope.cat_automatica;
            r_gmovi.monto           := nvl(v_pag_capital,0);
            r_gmovi.cod_moneda      := v_cod_mon_local;
            r_gmovi.mto_equ_local   := null;
            r_gmovi.cod_transaccion := 152;
            pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
            -- Desafecta Valuación.                         
            LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora); 
            r_gmovi.concepto        := 'Desaf. Valuacion por Pago - Cap';
            If cta.estado = 'N' Then
               r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
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
         if v_dif_capital <> 0 or cta.estado = 'N' or v_cam_situacion = 'S' then
            if v_dif_capital > 0 then
                
               LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora); 
               r_gmovi.concepto        := 'Ganancia por dif. de cambio - Cap Dia';
               If cta.estado = 'N' Then
                  r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
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
               -- Fecha: 30/05/2014 - MIS
               -- REG-BBVA-CNF_2301_FAFU.01-AJU_PRO_VALUACION.docx
               if (nvl(r_pvalu.tot_val_capital,0) - nvl(v_pag_capital,0)) > 0 and (v_cam_situacion = 'S' or cta.estado = 'N') then                 
                LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora); 
                r_gmovi.concepto        := 'Desafectacion ganancia x Cap Acu_1';
                r_gmovi.cod_moneda      := v_cod_mon_local;
                If cta.estado = 'N' Then
                   r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
                else
                   r_gmovi.est_cuenta      := cta.estado;
                end if;
                r_gmovi.nro_documento2  := nvl(r_pvalu.cat_automatica,r_gcope.cat_automatica);
                If cta.estado = 'N' then
                   r_gmovi.monto := ((nvl(r_pvalu.tot_val_capital,0) - nvl(v_pag_capital,0)) + v_dif_capital) * -1;
                Else
                   r_gmovi.monto := ((nvl(r_pvalu.tot_val_capital,0) - nvl(v_pag_capital,0)) * -1);
                End if;
                r_gmovi.mto_equ_local   := null;
                r_gmovi.cod_transaccion := 152;
                pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
                --- Afecta a cartera por el mismo importe.                 
                LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora); 
                r_gmovi.concepto        := 'Act. por dif. de cambio - Cap Acu_1';
                r_gmovi.est_cuenta      := cta.estado;
                r_gmovi.nro_documento2  := r_gcope.cat_automatica;
                r_gmovi.cod_transaccion := 152; -- Cartera
                r_gmovi.cod_moneda      := v_cod_mon_local;
                If cta.estado = 'N' then
                   r_gmovi.monto := ((nvl(r_pvalu.tot_val_capital,0) - nvl(v_pag_capital,0)) + v_dif_capital);
                Else
                   r_gmovi.monto := (nvl(r_pvalu.tot_val_capital,0) - nvl(v_pag_capital,0));
                End if;
                r_gmovi.mto_equ_local   := null;
                pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
               end if;
            elsif v_dif_capital < 0 then
               -- Fecha: 30/05/2014 - MIS
               -- REG-BBVA-CNF_2301_FAFU.01-AJU_PRO_VALUACION.docx
               if (nvl(r_pvalu.tot_val_capital,0) - nvl(v_pag_capital,0)) > 0 then
                  if abs(v_dif_capital) > (nvl(r_pvalu.tot_val_capital,0) - nvl(v_pag_capital,0)) then
                    --- Desafectar ganancia y el resto va a perdida                     
                    LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora); 
                    r_gmovi.concepto        := 'Desafectacion ganancia - Cap Dia';
                    r_gmovi.cod_moneda      := v_cod_mon_local;
                    If cta.estado = 'N' Then
                      r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
                    else
                      r_gmovi.est_cuenta      := cta.estado;
                    end if;
                    r_gmovi.nro_documento2  := nvl(r_pvalu.cat_automatica,r_gcope.cat_automatica);
                    r_gmovi.monto           := ((nvl(r_pvalu.tot_val_capital,0) - nvl(v_pag_capital,0))*-1);
                    r_gmovi.mto_equ_local   := null;
                    r_gmovi.cod_transaccion := 152;
                    pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
                    ----                                         
                    LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora); 
                    r_gmovi.concepto        := 'Perdida por dif. de cambio - Cap Dia';
                    If cta.estado = 'N' Then
                      r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
                    else
                      r_gmovi.est_cuenta      := cta.estado;
                    end if;
                    r_gmovi.nro_documento2  := r_gcope.cat_automatica;
                    r_gmovi.monto           := round(abs(nvl(v_dif_capital,0)) - abs((nvl(r_pvalu.tot_val_capital,0) - nvl(v_pag_capital,0))),v_redondeo_ml);
                    r_gmovi.cod_moneda      := v_cod_mon_local;
                    r_gmovi.mto_equ_local   := null;
                    r_gmovi.cod_transaccion := 153;  --- Perdida
                    pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
                  else
                    --- Si es menor al monto valuado debe desafectar                     
                    LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora); 
                    r_gmovi.concepto        := 'Desafectacion ganancia - Cap Dia';
                    r_gmovi.cod_moneda      := v_cod_mon_local;
                    If cta.estado = 'N' Then
                      r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
                    else
                      r_gmovi.est_cuenta      := cta.estado;
                    end if;
                    r_gmovi.nro_documento2  := nvl(r_pvalu.cat_automatica,r_gcope.cat_automatica);
                    r_gmovi.monto           := (nvl(v_dif_capital,0));
                    r_gmovi.mto_equ_local   := null;
                    r_gmovi.cod_transaccion := 152;
                    pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
                  end if;
                  --- Verifica si se canceló o se cambió de estado debe reconocer la ganancia.
                  -- Fecha: 30/05/2014 - MIS
                  -- REG-BBVA-CNF_2301_FAFU.01-AJU_PRO_VALUACION.docx
                  if nvl(v_dif_capital,0) + (nvl(r_pvalu.tot_val_capital,0) - nvl(v_pag_capital,0)) > 0 and
                     (v_cam_situacion = 'S' or cta.estado = 'N') then                     
                    LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora); 
                    r_gmovi.concepto        := 'Desafectacion ganancia x Cap Acu_2';
                    r_gmovi.cod_moneda      := v_cod_mon_local;
                    If cta.estado = 'N' Then
                       r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
                    else
                       r_gmovi.est_cuenta      := cta.estado;
                    end if;
                    r_gmovi.nro_documento2  := nvl(r_pvalu.cat_automatica,r_gcope.cat_automatica);
                    r_gmovi.monto           := ((nvl(v_dif_capital,0) + (nvl(r_pvalu.tot_val_capital,0) - nvl(v_pag_capital,0))) * -1);
                    r_gmovi.mto_equ_local   := null;
                    r_gmovi.cod_transaccion := 152;
                    pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
                    --- Afecta a cartera por el mismo importe.                     
                    LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora); 
                    r_gmovi.concepto        := 'Act. por dif. de cambio - Cap';
                    r_gmovi.est_cuenta      := cta.estado;
                    r_gmovi.nro_documento2  := r_gcope.cat_automatica;
                    r_gmovi.cod_transaccion := 152; -- Cartera
                    r_gmovi.cod_moneda      := v_cod_mon_local;
                    r_gmovi.monto           := (nvl(v_dif_capital,0) + (nvl(r_pvalu.tot_val_capital,0) - nvl(v_pag_capital,0)));
                    r_gmovi.mto_equ_local   := null;
                    pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
                  end if;
               else --- Todo a perdida                   
                  LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora);  
                  r_gmovi.concepto        := 'Perdida por dif. de cambio - Cap';
                  If cta.estado = 'N' Then
                    r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
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
              -- Fecha: 30/05/2014 - MIS
              -- REG-BBVA-CNF_2301_FAFU.01-AJU_PRO_VALUACION.docx
              if (nvl(r_pvalu.tot_val_capital,0) - nvl(v_pag_capital,0)) > 0 and
                 (v_cam_situacion = 'S' or cta.estado = 'N') then                 
                LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora);  
                r_gmovi.concepto        := 'Desafectacion ganancia x Cap Acu_3';
                r_gmovi.cod_moneda      := v_cod_mon_local;
                If cta.estado = 'N' Then
                   r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
                else
                   r_gmovi.est_cuenta      := cta.estado;
                end if;
                r_gmovi.nro_documento2  := nvl(r_pvalu.cat_automatica,r_gcope.cat_automatica);
                r_gmovi.monto           := ((nvl(r_pvalu.tot_val_capital,0) - nvl(v_pag_capital,0)) * -1);
                r_gmovi.mto_equ_local   := null;
                r_gmovi.cod_transaccion := 152;
                pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
                --- Afecta a cartera por el mismo importe.                 
                LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora); 
                r_gmovi.concepto        := 'Act. por dif. de cambio - Cap Acu_3';
                r_gmovi.est_cuenta      := cta.estado;
                r_gmovi.nro_documento2  := r_gcope.cat_automatica;
                r_gmovi.cod_transaccion := 152; -- Cartera
                r_gmovi.cod_moneda      := v_cod_mon_local;
                r_gmovi.monto           := ((nvl(r_pvalu.tot_val_capital,0) - nvl(v_pag_capital,0)));
                r_gmovi.mto_equ_local   := null;
                pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
              end if;
            end if;
            if (nvl(cta.estado,'A') in ('A','C') and
                nvl(r_gcope.cat_automatica,1) in (1,2) ) or
                cta.estado = 'N' then
               --- No es necesario acumular el saldo cuando va todo a pérdida o
               --- son cuentas que generan directamente ganancia o pérdida
               r_pvalc.tot_val_capital := 0;
            else --- Acumular saldos solo para cuentas a valuar en suspenso
               r_pvalc.tot_val_capital := nvl(r_pvalu.tot_val_capital,0) + (nvl(v_dif_capital,0) - nvl(v_pag_capital,0));
            end if;
            --- Generar movimiento por la cartera por la diferencia de cotizacion.
            if v_dif_capital != 0 then               
              LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora);  
              r_gmovi.monto           := 0;
              r_gmovi.cod_moneda      := cta.cod_moneda;
              r_gmovi.mto_equ_local   := v_dif_capital;
              r_gmovi.concepto        := 'Act. por dif. de cambio - Cap Dia';
              r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
              r_gmovi.nro_documento2  := r_gcope.cat_automatica;
              r_gmovi.cod_transaccion := 151; -- Cartera
              pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
            end if;
         else
            r_pvalc.tot_val_capital := (nvl(r_pvalu.tot_val_capital,0) - nvl(v_pag_capital,0));
         end if;
         ---------------------------------------
         --- Procesar INTERES (154,155,156)
         ---------------------------------------
         v_pag_interes   := 0;
         v_dif_interes   := 0;
         v_cam_situacion := 'N';
         If (nvl(r_pvalu.estado,'A') not in ('A','C') or nvl(r_pvalu.cat_automatica,1) not in (1,2)) and
            (nvl(cta.estado,'A') in ('A','C') and nvl(r_gcope.cat_automatica,1) in (1,2)) then
            v_cam_situacion := 'S';
         End if;
         ---
         if cta.estado <> 'N' then
            v_dif_interes := round((nvl(cta.sal_interes,0)*v_cotizacion) - ((nvl(r_pvalu.sal_interes,cta.sal_interes)*nvl(r_pvalu.cotizacion,v_cotizacion)) - v_mto_interes),v_redondeo_ml);
         else
            v_dif_interes := round((nvl(r_pvalu.sal_interes,0)*v_cotizacion) - ((nvl(r_pvalu.sal_interes,cta.sal_interes)*nvl(r_pvalu.cotizacion,v_cotizacion))),v_redondeo_ml);
         end if;
         if nvl(r_pvalu.sal_interes,0) <> 0 and nvl(v_mto_ori_interes, 0) <> 0 and nvl(v_tot_acumulado,0) <> 0 then
            v_pag_interes := round(nvl(r_pvalu.tot_valuacion, 0) * nvl(v_mto_ori_interes, 0) / nvl(v_tot_acumulado,0),v_redondeo_ml);
            if v_pag_interes < 0 then
               v_pag_interes := 0;
            end if;
         end if;
         --
         if cta.estado = 'N' then
            v_pag_interes := 0;
         end if;
         --
         if nvl(v_pag_interes,0) <> 0 then
            -- Acredito Ganancia.             
            LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora); 
            r_gmovi.concepto        := 'Ganancia por pago - Int';
            r_gmovi.est_cuenta      := 'N';
            r_gmovi.nro_documento2  := r_gcope.cat_automatica;
            r_gmovi.monto           := nvl(v_pag_interes,0);
            r_gmovi.cod_moneda      := v_cod_mon_local;
            r_gmovi.mto_equ_local   := null;
            r_gmovi.cod_transaccion := 152;
            pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
            -- Desafectación de valuación.                    
            LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora); 
            r_gmovi.concepto        := 'Desaf. Valuación por pago - Int';
            If cta.estado = 'N' Then
               r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
            else
               r_gmovi.est_cuenta      := cta.estado;
            end if;
            r_gmovi.nro_documento2  := r_gcope.cat_automatica;
            r_gmovi.monto           := nvl(v_pag_interes,0) * (-1);
            r_gmovi.cod_moneda      := v_cod_mon_local;
            r_gmovi.mto_equ_local   := null;
            r_gmovi.cod_transaccion := 152;
            pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
         end if;
         --
         if v_dif_interes <> 0 or cta.estado = 'N' or v_cam_situacion = 'S' then
            if v_dif_interes > 0 then                
               LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora); 
               r_gmovi.concepto        := 'Ganancia por dif. de cambio - Int Dia';
               If cta.estado = 'N' Then
                  r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
               else
                  r_gmovi.est_cuenta      := cta.estado;
               end if;
               r_gmovi.nro_documento2  := r_gcope.cat_automatica;
               r_gmovi.monto           := v_dif_interes;
               r_gmovi.cod_moneda      := v_cod_mon_local;
               r_gmovi.mto_equ_local   := null;
               r_gmovi.cod_transaccion := 152;
               pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
               --- Verifica si se cancelo o se cambio de estado debe reconocer la ganancia.
               -- Fecha: 30/05/2014 - MIS
               -- REG-BBVA-CNF_2301_FAFU.01-AJU_PRO_VALUACION.docx
               if (nvl(r_pvalu.tot_val_interes,0) - nvl(v_pag_interes,0)) > 0 and (v_cam_situacion = 'S' or cta.estado = 'N') then                 
                LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora); 
                r_gmovi.concepto        := 'Desafectacion ganancia x Int Acu_1';
                r_gmovi.cod_moneda      := v_cod_mon_local;
                If cta.estado = 'N' Then
                   r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
                else
                   r_gmovi.est_cuenta      := cta.estado;
                end if;
                r_gmovi.nro_documento2  := nvl(r_pvalu.cat_automatica,r_gcope.cat_automatica);
                If cta.estado = 'N' then
                   r_gmovi.monto := ((nvl(r_pvalu.tot_val_interes,0) - nvl(v_pag_interes,0)) + v_dif_interes) * -1;
                Else
                   r_gmovi.monto := ((nvl(r_pvalu.tot_val_interes,0) - nvl(v_pag_interes,0)) * -1);
                End if;
                r_gmovi.mto_equ_local   := null;
                r_gmovi.cod_transaccion := 152;
                pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
                --- Afecta a cartera por el mismo importe.                 
                LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora); 
                r_gmovi.concepto        := 'Act. por dif. de cambio - Int Acu_1';
                r_gmovi.est_cuenta      := cta.estado;
                r_gmovi.nro_documento2  := r_gcope.cat_automatica;
                r_gmovi.cod_transaccion := 152; -- Cartera
                r_gmovi.cod_moneda      := v_cod_mon_local;
                If cta.estado = 'N' then
                   r_gmovi.monto := ((nvl(r_pvalu.tot_val_interes,0) - nvl(v_pag_interes,0)) + v_dif_interes);
                Else
                   r_gmovi.monto := ((nvl(r_pvalu.tot_val_interes,0) - nvl(v_pag_interes,0)));
                End if;
                r_gmovi.mto_equ_local   := null;
                pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
               end if;
            elsif v_dif_interes < 0 then
               -- Fecha: 30/05/2014 - MIS
               -- REG-BBVA-CNF_2301_FAFU.01-AJU_PRO_VALUACION.docx
               if (nvl(r_pvalu.tot_val_interes,0) - nvl(v_pag_interes,0)) > 0 then
                  if abs(v_dif_interes) > (nvl(r_pvalu.tot_val_interes,0) - nvl(v_pag_interes,0)) then
                    --- Desafectar ganancia y el resto va a perdida                     
                    LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora); 
                    r_gmovi.concepto        := 'Desafectacion ganancia - Int Dia';
                    r_gmovi.cod_moneda      := v_cod_mon_local;
                    If cta.estado = 'N' Then
                      r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
                    else
                      r_gmovi.est_cuenta      := cta.estado;
                    end if;
                    r_gmovi.nro_documento2  := nvl(r_pvalu.cat_automatica,r_gcope.cat_automatica);
                    r_gmovi.monto           := ((nvl(r_pvalu.tot_val_interes,0) - nvl(v_pag_interes,0))*-1);
                    r_gmovi.mto_equ_local   := null;
                    r_gmovi.cod_transaccion := 152;
                    pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
                    ----                     
                    LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora); 
                    r_gmovi.concepto        := 'Perdida por dif. de cambio - Int Dia';
                    If cta.estado = 'N' Then
                      r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
                    else
                      r_gmovi.est_cuenta      := cta.estado;
                    end if;
                    r_gmovi.nro_documento2  := r_gcope.cat_automatica;
                    r_gmovi.monto           := abs(nvl(v_dif_interes,0)) - abs((nvl(r_pvalu.tot_val_interes,0) - nvl(v_pag_interes,0)));
                    r_gmovi.cod_moneda      := v_cod_mon_local;
                    r_gmovi.mto_equ_local   := null;
                    r_gmovi.cod_transaccion := 153;  --- Perdida
                    pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
                  else
                    --- Si es menor al monto valuado debe desafectar                     
                    LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora); 
                    r_gmovi.concepto        := 'Desafectacion ganancia - Int Dia';
                    r_gmovi.cod_moneda      := v_cod_mon_local;
                    If cta.estado = 'N' Then
                      r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
                    else
                      r_gmovi.est_cuenta      := cta.estado;
                    end if;
                    r_gmovi.nro_documento2  := nvl(r_pvalu.cat_automatica,r_gcope.cat_automatica);
                    r_gmovi.monto           := (nvl(v_dif_interes,0));
                    r_gmovi.mto_equ_local   := null;
                    r_gmovi.cod_transaccion := 152;
                    pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
                  end if;
                  --- Verifica si se cancelo o se cambio de estado debe reconocer la ganancia.
                  if nvl(v_dif_interes,0) + (nvl(r_pvalu.tot_val_interes,0) - nvl(v_pag_interes,0)) > 0 and
                     (v_cam_situacion = 'S' or cta.estado = 'N') then                     
                    LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora);  
                    r_gmovi.concepto        := 'Desafectacion ganancia x Int Acu_2';
                    r_gmovi.cod_moneda      := v_cod_mon_local;
                    If cta.estado = 'N' Then
                       r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
                    else
                       r_gmovi.est_cuenta      := cta.estado;
                    end if;
                    r_gmovi.nro_documento2  := nvl(r_pvalu.cat_automatica,r_gcope.cat_automatica);
                    r_gmovi.monto           := ((nvl(v_dif_interes,0) + (nvl(r_pvalu.tot_val_interes,0) - nvl(v_pag_interes,0))) * -1);
                    r_gmovi.mto_equ_local   := null;
                    r_gmovi.cod_transaccion := 152;
                    pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
                    --- Afecta a cartera por el mismo importe.                     
                    LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora);  
                    r_gmovi.concepto        := 'Act. por dif. de cambio - Int Acu_2';
                    r_gmovi.est_cuenta      := cta.estado;
                    r_gmovi.nro_documento2  := r_gcope.cat_automatica;
                    r_gmovi.cod_transaccion := 152; -- Cartera
                    r_gmovi.cod_moneda      := v_cod_mon_local;
                    r_gmovi.monto           := (nvl(v_dif_interes,0) + (nvl(r_pvalu.tot_val_interes,0) - nvl(v_pag_interes,0)));
                    r_gmovi.mto_equ_local   := null;
                    pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
                  end if;
               else --- Todo a perdida                   
                  LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora); 
                  r_gmovi.concepto        := 'Perdida por dif. de cambio - Int Acu_2';
                  If cta.estado = 'N' Then
                    r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
                  else
                    r_gmovi.est_cuenta      := cta.estado;
                  end if;
                  r_gmovi.nro_documento2  := r_gcope.cat_automatica;
                  r_gmovi.monto           := abs(v_dif_interes);
                  r_gmovi.cod_moneda      := v_cod_mon_local;
                  r_gmovi.mto_equ_local   := null; --r_gmovi.monto;
                  r_gmovi.cod_transaccion := 153;
                  pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
               end if;
            else --- NO TUVO DIFERENCIA DE COTIZACION...
              --- Verifica si se canceló o se cambió de estado debe reconocer la ganancia.
              -- Fecha: 30/05/2014 - MIS
              -- REG-BBVA-CNF_2301_FAFU.01-AJU_PRO_VALUACION.docx
              if (nvl(r_pvalu.tot_val_interes,0) - nvl(v_pag_interes,0)) > 0 and
                 (v_cam_situacion = 'S' or cta.estado = 'N') then                 
                LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora);  
                r_gmovi.concepto        := 'Desafectacion ganancia x Int Acu_3';
                r_gmovi.cod_moneda      := v_cod_mon_local;
                If cta.estado = 'N' Then
                   r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
                else
                   r_gmovi.est_cuenta      := cta.estado;
                end if;
                r_gmovi.nro_documento2  := nvl(r_pvalu.cat_automatica,r_gcope.cat_automatica);
                r_gmovi.monto           := ((nvl(r_pvalu.tot_val_interes,0) - nvl(v_pag_interes,0)) * -1);
                r_gmovi.mto_equ_local   := null;
                r_gmovi.cod_transaccion := 152;
                pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
                --- Afecta a cartera por el mismo importe.                 
                LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora);  
                r_gmovi.concepto        := 'Act. por dif. de cambio - Int Acu_3';
                r_gmovi.est_cuenta      := cta.estado;
                r_gmovi.nro_documento2  := r_gcope.cat_automatica;
                r_gmovi.cod_transaccion := 152; -- Cartera
                r_gmovi.cod_moneda      := v_cod_mon_local;
                r_gmovi.monto           := ((nvl(r_pvalu.tot_val_interes,0) - nvl(v_pag_interes,0)));
                r_gmovi.mto_equ_local   := null;
                pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
              end if;
            end if;
            if (nvl(cta.estado,'A') in ('A','C') and
                nvl(r_gcope.cat_automatica,1) in (1,2) ) or
                cta.estado = 'N' then
               --- No es necesario acumular el saldo cuando va todo a pérdida o
               --- son cuentas que generan directamente ganancia o pérdida
               r_pvalc.tot_val_interes := 0;
            else --- Acumular saldos solo para cuentas a valuar en suspenso
               r_pvalc.tot_val_interes := nvl(r_pvalu.tot_val_interes,0) + (nvl(v_dif_interes,0) - nvl(v_pag_interes,0));
            end if;
            --- Generar movimiento por la cartera por la diferencia de cotizacion.
            if v_dif_interes != 0 then               
              LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora); 
              r_gmovi.monto           := 0;
              r_gmovi.cod_moneda      := cta.cod_moneda;
              r_gmovi.mto_equ_local   := v_dif_interes;
              r_gmovi.concepto        := 'Act. por dif. de cambio - int Dia';
              r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
              r_gmovi.nro_documento2  := r_gcope.cat_automatica;
              r_gmovi.cod_transaccion := 154; -- Cartera
              pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
            end if;
         else
            r_pvalc.tot_val_interes := (nvl(r_pvalu.tot_val_interes,0) - nvl(v_pag_interes,0));
         end if;
         ------------------------------------------------
         --- Procesar INTERES ADELANTADO (157,158,159)
         ------------------------------------------------
         v_pag_int_adelantado := 0;
         v_dif_int_adelantado := 0;
         v_cam_situacion := 'N';
         If (nvl(r_pvalu.estado,'A') not in ('A','C') or nvl(r_pvalu.cat_automatica,1) not in (1,2)) and
            (nvl(cta.estado,'A') in ('A','C') and nvl(r_gcope.cat_automatica,1) in (1,2)) then
            v_cam_situacion := 'S';
         End if;
         ---
         if cta.estado <> 'N' then
            v_dif_int_adelantado := round((nvl(cta.sal_int_adelantado,0)*v_cotizacion) - ((nvl(r_pvalu.sal_int_adelantado,cta.sal_int_adelantado)*nvl(r_pvalu.cotizacion,v_cotizacion)) - v_mto_int_adelantado),v_redondeo_ml);
         else
            v_dif_int_adelantado := round((nvl(r_pvalu.sal_int_adelantado,0)*v_cotizacion) - ((nvl(r_pvalu.sal_int_adelantado,cta.sal_int_adelantado)*nvl(r_pvalu.cotizacion,v_cotizacion))),v_redondeo_ml);
         end if;
         --
         if nvl(r_pvalu.sal_int_adelantado,0) <> 0 and nvl(v_mto_ori_int_adelantado, 0) <> 0 and nvl(v_tot_acumulado,0) <> 0 then
            v_pag_int_adelantado := round(nvl(r_pvalu.tot_valuacion, 0) * nvl(v_mto_ori_int_adelantado, 0) / nvl(v_tot_acumulado,0),v_redondeo_ml);
            if v_pag_int_adelantado < 0 then
               v_pag_int_adelantado := 0;
            end if;
         end if;
         --
         if cta.estado = 'N' then
            v_pag_int_adelantado := 0;
         end if;
         --
         if nvl(v_pag_int_adelantado,0) <> 0 then
            -- Acredito Ganancia.             
            LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora);  
            r_gmovi.concepto        := 'Ganancia por pago - IAd';
            r_gmovi.est_cuenta      := 'N';
            r_gmovi.nro_documento2  := r_gcope.cat_automatica;
            r_gmovi.monto           := nvl(v_pag_int_adelantado,0);
            r_gmovi.cod_moneda      := v_cod_mon_local;
            r_gmovi.mto_equ_local   := null;
            r_gmovi.cod_transaccion := 152;
            pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
            -- Desafectación de Valuación.             
            LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora); 
            r_gmovi.concepto        := 'Desaf. Valuación por pago - IAd';
            If cta.estado = 'N' Then
               r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
            else
               r_gmovi.est_cuenta      := cta.estado;
            end if;
            r_gmovi.nro_documento2  := r_gcope.cat_automatica;
            r_gmovi.monto           := nvl(v_pag_int_adelantado,0) * (-1);
            r_gmovi.cod_moneda      := v_cod_mon_local;
            r_gmovi.mto_equ_local   := null;
            r_gmovi.cod_transaccion := 152;
            pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
         end if;
         --
         if v_dif_int_adelantado <> 0 or cta.estado = 'N' or v_cam_situacion = 'S' then
            if v_dif_int_adelantado > 0 then                
               LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora);  
               r_gmovi.concepto        := 'Ganancia por dif. de cambio - IAd Dia';
               If cta.estado = 'N' Then
                  r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
               else
                  r_gmovi.est_cuenta      := cta.estado;
               end if;
               r_gmovi.nro_documento2  := r_gcope.cat_automatica;
               r_gmovi.monto           := v_dif_int_adelantado;
               r_gmovi.cod_moneda      := v_cod_mon_local;
               r_gmovi.mto_equ_local   := null;
               r_gmovi.cod_transaccion := 152;
               pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
               --- Verifica si se cancelo o se cambio de estado debe reconocer la ganancia.
               -- Fecha: 30/05/2014 - MIS
               -- REG-BBVA-CNF_2301_FAFU.01-AJU_PRO_VALUACION.docx
               if (nvl(r_pvalu.tot_val_int_ade,0) - nvl(v_pag_int_adelantado,0)) > 0 and (v_cam_situacion = 'S' or cta.estado = 'N') and
                 (v_cam_situacion = 'S' or cta.estado = 'N') then                 
                LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora);  
                r_gmovi.concepto        := 'Desafectacion ganancia x IAd Acu_1';
                r_gmovi.cod_moneda      := v_cod_mon_local;
                If cta.estado = 'N' Then
                   r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
                else
                   r_gmovi.est_cuenta      := cta.estado;
                end if;
                r_gmovi.nro_documento2  := nvl(r_pvalu.cat_automatica,r_gcope.cat_automatica);
                If cta.estado = 'N' then
                   r_gmovi.monto := ((nvl(r_pvalu.tot_val_int_ade,0) - nvl(v_pag_int_adelantado,0)) + v_dif_int_adelantado) * -1;
                Else
                   r_gmovi.monto := ((nvl(r_pvalu.tot_val_int_ade,0) - nvl(v_pag_int_adelantado,0)) * -1);
                End if;
                r_gmovi.mto_equ_local   := null;
                r_gmovi.cod_transaccion := 152;
                pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
                --- Afecta a cartera por el mismo importe.                 
                LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora); 
                r_gmovi.concepto        := 'Act. por dif. de cambio - IAd Acu_1';
                r_gmovi.est_cuenta      := cta.estado;
                r_gmovi.nro_documento2  := r_gcope.cat_automatica;
                r_gmovi.cod_transaccion := 152; -- Cartera
                r_gmovi.cod_moneda      := v_cod_mon_local;
                If cta.estado = 'N' then
                   r_gmovi.monto := ((nvl(r_pvalu.tot_val_int_ade,0) - nvl(v_pag_int_adelantado,0)) + v_dif_int_adelantado);
                Else
                   r_gmovi.monto := ((nvl(r_pvalu.tot_val_int_ade,0) - nvl(v_pag_int_adelantado,0)));
                End if;
                r_gmovi.mto_equ_local   := null;
                pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
               end if;
            elsif v_dif_int_adelantado < 0 then
               -- Fecha: 30/05/2014 - MIS
               -- REG-BBVA-CNF_2301_FAFU.01-AJU_PRO_VALUACION.docx
               if (nvl(r_pvalu.tot_val_int_ade,0) - nvl(v_pag_int_adelantado,0)) > 0 then
                  if abs(v_dif_int_adelantado) > (nvl(r_pvalu.tot_val_int_ade,0) - nvl(v_pag_int_adelantado,0)) then
                    --- Desafectar ganancia y el resto va a perdida                     
                    LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora); 
                    r_gmovi.concepto        := 'Desafectacion ganancia - IAd Dia';
                    r_gmovi.cod_moneda      := v_cod_mon_local;
                    r_gmovi.est_cuenta      := cta.estado;
                    r_gmovi.nro_documento2  := nvl(r_pvalu.cat_automatica,r_gcope.cat_automatica);
                    r_gmovi.monto           := ((nvl(r_pvalu.tot_val_int_ade,0) - nvl(v_pag_int_adelantado,0))*-1);
                    r_gmovi.mto_equ_local   := null;
                    r_gmovi.cod_transaccion := 152;
                    pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
                    ----                                         
                    LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora);  
                    r_gmovi.concepto        := 'Perdida por dif. de cambio - IAd Dia';
                    If cta.estado = 'N' Then
                      r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
                    else
                      r_gmovi.est_cuenta      := cta.estado;
                    end if;
                    r_gmovi.nro_documento2  := r_gcope.cat_automatica;
                    r_gmovi.monto           := abs(nvl(v_dif_int_adelantado,0)) - abs((nvl(r_pvalu.tot_val_int_ade,0) - nvl(v_pag_int_adelantado,0)));
                    r_gmovi.cod_moneda      := v_cod_mon_local;
                    r_gmovi.mto_equ_local   := null;
                    r_gmovi.cod_transaccion := 153;  --- Perdida
                    pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
                  else
                    --- Si es menor al monto valuado debe desafectar                
                    LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora);  
                    r_gmovi.concepto        := 'Desafectacion ganancia - IAd Dia';
                    r_gmovi.cod_moneda      := v_cod_mon_local;
                    If cta.estado = 'N' Then
                      r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
                    else
                      r_gmovi.est_cuenta      := cta.estado;
                    end if;
                    r_gmovi.nro_documento2  := nvl(r_pvalu.cat_automatica,r_gcope.cat_automatica);
                    r_gmovi.monto           := (nvl(v_dif_int_adelantado,0));
                    r_gmovi.mto_equ_local   := null;
                    r_gmovi.cod_transaccion := 152;
                    pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
                  end if;
                  --- Verifica si se cancelo o se cambio de estado debe reconocer la ganancia.
                  if nvl(v_dif_int_adelantado,0) + (nvl(r_pvalu.tot_val_int_ade,0) - nvl(v_pag_int_adelantado,0)) > 0 and
                     (v_cam_situacion = 'S' or cta.estado = 'N') then                
                    LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora); 
                    r_gmovi.concepto        := 'Desafectacion ganancia x IAd Acu_2';
                    r_gmovi.cod_moneda      := v_cod_mon_local;
                    If cta.estado = 'N' Then
                       r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
                    else
                       r_gmovi.est_cuenta      := cta.estado;
                    end if;
                    r_gmovi.nro_documento2  := nvl(r_pvalu.cat_automatica,r_gcope.cat_automatica);
                    r_gmovi.monto           := ((nvl(v_dif_int_adelantado,0) + (nvl(r_pvalu.tot_val_int_ade,0) - nvl(v_pag_int_adelantado,0))) * -1);
                    r_gmovi.mto_equ_local   := null;
                    r_gmovi.cod_transaccion := 152;
                    pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
                    --- Afecta a cartera por el mismo importe.                     
                    LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora);  
                    r_gmovi.concepto        := 'Act. por dif. de cambio - IAd Acu_2';
                    r_gmovi.est_cuenta      := cta.estado;
                    r_gmovi.nro_documento2  := r_gcope.cat_automatica;
                    r_gmovi.cod_transaccion := 152; -- Cartera
                    r_gmovi.cod_moneda      := v_cod_mon_local;
                    r_gmovi.monto           := (nvl(v_dif_int_adelantado,0) + (nvl(r_pvalu.tot_val_int_ade,0) - nvl(v_pag_int_adelantado,0)));
                    r_gmovi.mto_equ_local   := null;
                    pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
                  end if;
               else --- Todo a perdida                   
                  LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora); 
                  r_gmovi.concepto        := 'Perdida por dif. de cambio - IAd Acu_2';
                  If cta.estado = 'N' Then
                    r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
                  else
                    r_gmovi.est_cuenta      := cta.estado;
                  end if;
                  r_gmovi.nro_documento2  := r_gcope.cat_automatica;
                  r_gmovi.monto           := abs(v_dif_int_adelantado);
                  r_gmovi.cod_moneda      := v_cod_mon_local;
                  r_gmovi.mto_equ_local   := null;
                  r_gmovi.cod_transaccion := 153;
                  pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
               end if;
            else --- NO TUVO DIFERENCIA DE COTIZACION...
              --- Verifica si se canceló o se cambió de estado debe reconocer la ganancia.
              -- Fecha: 30/05/2014 - MIS
              -- REG-BBVA-CNF_2301_FAFU.01-AJU_PRO_VALUACION.docx
              if (nvl(r_pvalu.tot_val_int_ade,0) - nvl(v_pag_int_adelantado,0)) > 0 and
                 (v_cam_situacion = 'S' or cta.estado = 'N') then                  
                LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora);  
                r_gmovi.concepto        := 'Desafectacion ganancia x IAd Acu_3';
                r_gmovi.cod_moneda      := v_cod_mon_local;
                If cta.estado = 'N' Then
                   r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
                else
                   r_gmovi.est_cuenta      := cta.estado;
                end if;
                r_gmovi.nro_documento2  := nvl(r_pvalu.cat_automatica,r_gcope.cat_automatica);
                r_gmovi.monto           := ((nvl(r_pvalu.tot_val_int_ade,0) - nvl(v_pag_int_adelantado,0)) * -1);
                r_gmovi.mto_equ_local   := null;
                r_gmovi.cod_transaccion := 152;
                pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
                --- Afecta a cartera por el mismo importe.                   
                LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora); 
                r_gmovi.concepto        := 'Act. por dif. de cambio - IAd Acu_3';
                r_gmovi.est_cuenta      := cta.estado;
                r_gmovi.nro_documento2  := r_gcope.cat_automatica;
                r_gmovi.cod_transaccion := 152; -- Cartera
                r_gmovi.cod_moneda      := v_cod_mon_local;
                r_gmovi.monto           := (nvl(r_pvalu.tot_val_int_ade,0) - nvl(v_pag_int_adelantado,0));
                r_gmovi.mto_equ_local   := null;
                pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
              end if;
            end if;
            if (nvl(cta.estado,'A') in ('A','C') and
                nvl(r_gcope.cat_automatica,1) in (1,2) ) or
                cta.estado = 'N' then
               --- No es necesario acumular el saldo cuando va todo a perdida o
               --- son cuentas que generan directamente ganancia o perdida
               r_pvalc.tot_val_int_ade := 0;
            else --- Acumular saldos solo para cuentas a valuar en suspenso
               r_pvalc.tot_val_int_ade := nvl(r_pvalu.tot_val_int_ade,0) + (nvl(v_dif_int_adelantado,0) - nvl(v_pag_int_adelantado,0));
            end if;
            --- Generar movimiento por la cartera por la diferencia de cotizacion.
            if v_dif_int_adelantado != 0 then                   
              LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora); 
              r_gmovi.monto           := 0;
              r_gmovi.cod_moneda      := cta.cod_moneda;
              r_gmovi.mto_equ_local   := v_dif_int_adelantado;
              r_gmovi.concepto        := 'Act. por dif. de cambio - IAd Dia';
              r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
              r_gmovi.nro_documento2  := r_gcope.cat_automatica;
              r_gmovi.cod_transaccion := 157; -- Cartera
              pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
            end if;
         else
            r_pvalc.tot_val_int_ade := (nvl(r_pvalu.tot_val_int_ade,0) - nvl(v_pag_int_adelantado,0));
         end if;
         ----------------------------------------------------
         --- Procesar INTERES A DEVENGAR (160,161,162)
         ----------------------------------------------------
         v_pag_devengar      := 0;
         v_dif_devengar      := 0;
         v_cam_situacion     := 'N';
         If (nvl(r_pvalu.estado,'A') not in ('A','C') or nvl(r_pvalu.cat_automatica,1) not in (1,2)) and
            (nvl(cta.estado,'A') in ('A','C') and nvl(r_gcope.cat_automatica,1) in (1,2)) then
            v_cam_situacion := 'S';
         End if;
         ---
         if cta.estado <> 'N' then
            v_dif_devengar := round((nvl(cta.val_int_devengar,0) * (v_cotizacion - nvl(r_pvalu.cotizacion,v_cotizacion))),v_redondeo_ml);
         else
            v_dif_devengar := round((nvl(r_pvalu.val_int_devengar,0) * (v_cotizacion - nvl(r_pvalu.cotizacion,v_cotizacion))),v_redondeo_ml);
         end if;
         if nvl(r_pvalu.val_int_devengar,0) <> 0 and nvl(v_mto_ori_devengar, 0) <> 0 and nvl(r_pvalu.tot_val_int_devengar,0) <> 0 then
            v_pag_devengar := round(nvl(v_mto_ori_devengar, 0) * nvl(r_pvalu.tot_val_int_devengar, 0) / nvl(r_pvalu.val_int_devengar,0),v_redondeo_ml);
         end if;
         --
         if cta.estado = 'N' then
            v_pag_devengar := 0;
         end if;
         --
         v_dif_devengar := nvl(v_dif_devengar,0) * (-1);
         if v_dif_devengar <> 0 or cta.estado = 'N' or v_cam_situacion = 'S' then
            if v_dif_devengar > 0 then
               if v_dif_devengar > nvl(r_pvalu.tot_val_int_devengar,0) then                    
                  LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora); 
                  r_gmovi.concepto        := 'Ganancia por dif. de cambio - Ade Acu_1';
                  If cta.estado = 'N' Then
                     r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
                  else
                     r_gmovi.est_cuenta      := cta.estado;
                  end if;
                  r_gmovi.nro_documento2     := r_gcope.cat_automatica;
                  r_gmovi.monto              := nvl(r_pvalu.tot_val_int_devengar,0);
                  r_gmovi.cod_moneda         := v_cod_mon_local;
                  r_gmovi.mto_equ_local      := null;
                  r_gmovi.cod_transaccion    := 152;
                  pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
                  --                   
                  LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora);
                  r_gmovi.concepto           := 'Ganancia por dif. de cambio - Ade Acu_1';
                  -- Fecha: 06/08/2014.
                  -- Requerimiento: DYDMR-791.
                  r_gmovi.est_cuenta      := 'N';
                  r_gmovi.nro_documento2  := r_gcope.cat_automatica;
                  r_gmovi.monto           := nvl(v_dif_devengar,0) - nvl(r_pvalu.tot_val_int_devengar,0);
                  r_gmovi.cod_moneda      := v_cod_mon_local;
                  r_gmovi.mto_equ_local   := null;
                  r_gmovi.cod_transaccion := 152;
                  pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
               else                    
                  LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora); 
                  r_gmovi.concepto        := 'Ganancia por dif. de cambio - Ade Acu_1';
                  If cta.estado = 'N' Then
                     r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
                  else
                     r_gmovi.est_cuenta      := cta.estado;
                  end if;
                  r_gmovi.nro_documento2  := r_gcope.cat_automatica;
                  r_gmovi.monto           := NVL(v_dif_devengar,0);
                  r_gmovi.cod_moneda      := v_cod_mon_local;
                  r_gmovi.mto_equ_local   := null;
                  r_gmovi.cod_transaccion := 152;
                  pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
               end if;
               --- Verifica si se canceló o se cambió de estado debe reconocer la ganancia.
               if nvl(r_pvalu.tot_val_int_devengar,0) > 0 and -- BBVASOP-1464.
                 (v_cam_situacion = 'S' or cta.estado = 'N') then             
                LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora); 
                r_gmovi.concepto        := 'Actualiza Valuacion x Ade Acu_2';
                r_gmovi.cod_moneda      := v_cod_mon_local;
                If cta.estado = 'N' Then
                   r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
                else
                   r_gmovi.est_cuenta      := cta.estado;
                end if;
                r_gmovi.nro_documento2  := nvl(r_pvalu.cat_automatica,r_gcope.cat_automatica);
                If cta.estado = 'N' then
                   -- Si está cancelando debe reconocer todo como ganancia...
                   r_gmovi.monto := (nvl(r_pvalu.tot_val_int_devengar,0) + v_dif_devengar);
                Else
                   r_gmovi.monto := (nvl(r_pvalu.tot_val_int_devengar,0));
                End if;
                r_gmovi.mto_equ_local   := null;
                r_gmovi.cod_transaccion := 152;
                pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
                --- Afecta a cartera por el mismo importe.                  
                LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora); 
                r_gmovi.concepto        := 'Act. por dif. de cambio - Ade Acu_2';
                r_gmovi.est_cuenta      := cta.estado;
                r_gmovi.nro_documento2  := r_gcope.cat_automatica;
                r_gmovi.cod_transaccion := 152; -- Cartera
                r_gmovi.cod_moneda      := v_cod_mon_local;
                If cta.estado = 'N' then
                   -- Si está cancelando debe reconocer todo como ganancia...
                   r_gmovi.monto := (nvl(r_pvalu.tot_val_int_devengar,0) + v_dif_devengar) * (-1);
                Else
                   r_gmovi.monto := (nvl(r_pvalu.tot_val_int_devengar,0)) * (-1);
                End if;
                r_gmovi.mto_equ_local   := null;
                pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
               end if;
            elsif v_dif_devengar < 0 then
               if nvl(r_pvalu.tot_val_int_devengar,0) > 0 then
                  -- Fecha: 16/09/2015.
                  -- Requerimiento: DYDMR-2253.
                  if (nvl(v_cotizacion,-1) - nvl(r_pvalu.cotizacion,v_cotizacion)) > 0 then
                  ---Disminuyo Valuación en Suspenso. EP                   
                  LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora); 
                  r_gmovi.concepto        := 'Desafectacion ganancia - Ade Acu_3';
                  r_gmovi.cod_moneda      := v_cod_mon_local;
                  If cta.estado = 'N' Then
                    r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
                  else
                    r_gmovi.est_cuenta      := cta.estado;
                  end if;
                  r_gmovi.nro_documento2  := nvl(r_pvalu.cat_automatica,r_gcope.cat_automatica);
                  r_gmovi.monto           := (nvl(v_dif_devengar,0));
                  r_gmovi.mto_equ_local   := null;
                  r_gmovi.cod_transaccion := 152;
                  pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');

                  else

                  if abs(v_dif_devengar) > nvl(r_pvalu.tot_val_int_devengar,0) then
                    --- Desafectar ganancia y el resto va a perdida  
                    LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora); 
                    r_gmovi.concepto        := 'Desafectacion ganancia - Ade Acu_3';
                    r_gmovi.cod_moneda      := v_cod_mon_local;
                    If cta.estado = 'N' Then
                      r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
                    else
                      r_gmovi.est_cuenta      := cta.estado;
                    end if;
                    r_gmovi.nro_documento2  := nvl(r_pvalu.cat_automatica,r_gcope.cat_automatica);
                    r_gmovi.monto           := (nvl(r_pvalu.tot_val_int_devengar,0)*-1);
                    r_gmovi.mto_equ_local   := null;
                    r_gmovi.cod_transaccion := 152;

                    pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
                    ----  
                    LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora); 
                    r_gmovi.concepto        := 'Perdida por dif. de cambio - Ade Acu_3';
                    If cta.estado = 'N' Then
                      r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
                    else
                      r_gmovi.est_cuenta      := cta.estado;
                    end if;
                    r_gmovi.nro_documento2  := r_gcope.cat_automatica;
                    r_gmovi.monto           := abs(nvl(v_dif_devengar,0)) - abs(nvl(r_pvalu.tot_val_int_devengar,0));
                    r_gmovi.cod_moneda      := v_cod_mon_local;
                    r_gmovi.mto_equ_local   := null;
                    r_gmovi.cod_transaccion := 153;  --- Perdida
                    pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
                  else
                    --- Si es menor al monto valuado debe desafectar   
                    LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora); 
                    r_gmovi.concepto        := 'Desafectacion ganancia - Ade Acu_3';
                    r_gmovi.cod_moneda      := v_cod_mon_local;
                    If cta.estado = 'N' Then
                      r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
                    else
                      r_gmovi.est_cuenta      := cta.estado;
                    end if;
                    r_gmovi.nro_documento2  := nvl(r_pvalu.cat_automatica,r_gcope.cat_automatica);
                    r_gmovi.monto           := (nvl(v_dif_devengar,0));
                    r_gmovi.mto_equ_local   := null;
                    r_gmovi.cod_transaccion := 152;
                    pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
                  end if;
                  end if;
                  --- Verifica si se cancelo o se cambio de estado debe reconocer la ganancia.
                  if nvl(v_dif_devengar,0) + nvl(r_pvalu.tot_val_int_devengar,0) > 0 and
                     (v_cam_situacion = 'S' or cta.estado = 'N') then  
                    LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora); 
                    r_gmovi.concepto        := 'Desafectacion ganancia x Ade Acu_4';
                    r_gmovi.cod_moneda      := v_cod_mon_local;
                    If cta.estado = 'N' Then
                      r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
                    else
                      r_gmovi.est_cuenta      := cta.estado;
                    end if;
                    r_gmovi.nro_documento2  := nvl(r_pvalu.cat_automatica,r_gcope.cat_automatica);
                    r_gmovi.monto           := (nvl(v_dif_devengar,0) + nvl(r_pvalu.tot_val_int_devengar,0));
                    r_gmovi.mto_equ_local   := null;
                    r_gmovi.cod_transaccion := 152;
                    pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
                    --- Afecta a cartera por el mismo importe. 
                    LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora); 
                    r_gmovi.concepto        := 'Act. por dif. de cambio - Ade Acu_4';
                    r_gmovi.est_cuenta      := cta.estado;
                    r_gmovi.nro_documento2  := r_gcope.cat_automatica;
                    r_gmovi.cod_transaccion := 152; -- Cartera
                    r_gmovi.cod_moneda      := v_cod_mon_local;
                    r_gmovi.monto           := (nvl(v_dif_devengar,0) + nvl(r_pvalu.tot_val_int_devengar,0)) * (-1);
                    r_gmovi.mto_equ_local   := null;
                    pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
                  end if;
               -- Fecha: 06/08/2014.
               -- Requerimiento: DYDMR-791.
               elsif nvl(r_pvalu.tot_val_int_devengar,0) = 0 and (nvl(v_cotizacion,-1) - nvl(r_pvalu.cotizacion,v_cotizacion)) > 0 then
                  --- Desafectación de la valuación por cambio de estado y aumento de la cotización.                   
                  LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora); 
                  r_gmovi.concepto        := 'Desafectacion ganancia - Ade Est';
                  r_gmovi.cod_moneda      := v_cod_mon_local;
                  If cta.estado = 'N' Then
                    r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
                  else
                    r_gmovi.est_cuenta      := cta.estado;
                  end if;
                  r_gmovi.nro_documento2  := nvl(r_pvalu.cat_automatica,r_gcope.cat_automatica);
                  r_gmovi.monto           := (nvl(v_dif_devengar,0));
                  r_gmovi.mto_equ_local   := null;
                  r_gmovi.cod_transaccion := 152;
                  pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
               else --- Todo a perdida
                  LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora); 
                  r_gmovi.concepto        := 'Perdida por dif. de cambio - Ade Acu_4';
                  If cta.estado = 'N' Then
                    r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
                  else
                    r_gmovi.est_cuenta      := cta.estado;
                  end if;
                  r_gmovi.nro_documento2  := r_gcope.cat_automatica;
                  r_gmovi.monto           := abs(v_dif_devengar);
                  r_gmovi.cod_moneda      := v_cod_mon_local;
                  r_gmovi.mto_equ_local   := null;
                  r_gmovi.cod_transaccion := 153;
                  pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
               end if;
            else --- NO TUVO DIFERENCIA DE COTIZACION...
              --- Verifica si se cancelo o se cambio de estado debe reconocer la ganancia.
              if nvl(r_pvalu.tot_val_int_devengar,0) > 0 and
                 (v_cam_situacion = 'S' or cta.estado = 'N') then 
                LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora); 
                r_gmovi.concepto        := 'Acredita Valuacion x Ade Acu_5';
                r_gmovi.cod_moneda      := v_cod_mon_local;
                If cta.estado = 'N' Then
                   r_gmovi.est_cuenta   := nvl(r_pvalu.estado,cta.estado);
                else
                   r_gmovi.est_cuenta   := cta.estado;
                end if;
                r_gmovi.nro_documento2  := nvl(r_pvalu.cat_automatica,r_gcope.cat_automatica);
                r_gmovi.monto           := nvl(r_pvalu.tot_val_int_devengar,0);
                r_gmovi.mto_equ_local   := null;
                r_gmovi.cod_transaccion := 152;
                pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
                --- Afecta a cartera por el mismo importe.  
                LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora);  
                r_gmovi.concepto        := 'Act. por dif. de cambio - Ade Acu_5';
                r_gmovi.est_cuenta      := cta.estado;
                r_gmovi.nro_documento2  := r_gcope.cat_automatica;
                r_gmovi.cod_transaccion := 152; -- Cartera
                r_gmovi.cod_moneda      := v_cod_mon_local;
                r_gmovi.monto           := (nvl(r_pvalu.tot_val_int_devengar,0)) * (-1);
                r_gmovi.mto_equ_local   := null;
                pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
              end if;
            end if;
            v_dif_devengar := nvl(v_dif_devengar,0) * (-1);
            if (nvl(cta.estado,'A') in ('A','C') and
                nvl(r_gcope.cat_automatica,1) in (1,2) ) or
                cta.estado = 'N' then
               --- No es necesario acumular el saldo cuando va todo a perdida o
               --- son cuentas que generan directamente ganancia o perdida
               r_pvalc.tot_val_int_devengar := 0;
            else --- Acumular saldos solo para cuentas a valuar en suspenso
               r_pvalc.tot_val_int_devengar := nvl(r_pvalu.tot_val_int_devengar,0) + (nvl(v_dif_devengar,0) + nvl(v_pag_devengar,0));
            end if;
            --- Generar movimiento por la cartera por la diferencia de cotizacion.
            if v_dif_devengar != 0 then
              LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora); 
              r_gmovi.monto           := 0;
              r_gmovi.cod_moneda      := cta.cod_moneda;
              r_gmovi.mto_equ_local   := v_dif_devengar;
              r_gmovi.concepto        := 'Act. por dif. de cambio - Ade Dia';
              r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
              r_gmovi.nro_documento2  := r_gcope.cat_automatica;
              r_gmovi.cod_transaccion := 160; -- Cartera
              pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
            end if;
         else
            r_pvalc.tot_val_int_devengar := nvl(r_pvalu.tot_val_int_devengar,0);
         end if;
         ----------------------------------------------------
         --- Procesar PREVISIONES (166,167,168)
         ----------------------------------------------------
         v_pag_prevision := 0;
         v_dif_prevision := 0;
         v_cam_situacion := 'N';
         If (nvl(r_pvalu.estado,'A') not in ('A','C') or nvl(r_pvalu.cat_automatica,1) not in (1,2)) and
            (nvl(cta.estado,'A') in ('A','C') and nvl(r_gcope.cat_automatica,1) in (1,2)) then
            v_cam_situacion := 'S';
         End if;
         ---
         if cta.estado <> 'N' then
            v_dif_prevision := round((nvl(r_gcope.tot_prevision,0) * (v_cotizacion - nvl(r_pvalu.cotizacion,v_cotizacion))),v_redondeo_ml);
         else
            v_dif_prevision := round((nvl(r_pvalu.tot_prevision,0) * (v_cotizacion - nvl(r_pvalu.cotizacion,v_cotizacion))),v_redondeo_ml);
         end if;
         if (nvl(r_pvalu.tot_prevision, 0) = 0 and nvl(r_gcope.tot_prevision,0) != 0) or
            (nvl(r_pvalu.tot_prevision, 0) != 0 and nvl(r_gcope.tot_prevision,0) = 0 and
             nvl(r_gcope.tot_prevision,0) + nvl(cta.sal_interes,0) + nvl(cta.sal_int_adelantado, 0) != 0) then
            --- no previsiono antes y ahora esta previsionando... o estaba previsionando y ahora deja de previsionar.
            --- por lo tanto no debe procesar.
            v_dif_prevision := 0;
         End if;
         if nvl(r_pvalu.tot_prevision,0) <> 0 and  nvl(v_mto_ori_prevision, 0) <> 0 and nvl(v_tot_acumulado,0) <> 0 then
            v_pag_prevision := round(nvl(r_pvalu.tot_valuacion, 0) * nvl(v_mto_ori_prevision, 0) / nvl(v_tot_acumulado,0),v_redondeo_ml);
            if v_pag_prevision < 0 then
               v_pag_prevision := 0;
            end if;
         end if;
         if v_pag_prevision = 0 and nvl(r_gcope.tot_prevision,0) > nvl(r_pvalu.tot_prevision,0)
         and nvl(r_gcope.tot_prevision,0) <> 0 and nvl(v_tot_acumulado,0) <> 0 then
            v_mto_ori_prevision := nvl(r_pvalu.tot_prevision,0) - nvl(r_gcope.tot_prevision,0);
            if v_mto_ori_prevision <> 0 then
               v_pag_prevision := round(nvl(r_pvalu.tot_valuacion, 0) * nvl(v_mto_ori_prevision, 0) / nvl(v_tot_acumulado,0),v_redondeo_ml);
            end if;
         end if;
         --
         if cta.estado = 'N' then
            v_pag_prevision := 0;
         end if;
         --
         if nvl(v_pag_prevision,0) <> 0 then
            if nvl(v_pag_prevision,0) > 0 then
               -- Acredito Valuación.    
               LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora);  
               r_gmovi.concepto        := 'Disminución. - Pre';
               If cta.estado = 'N' Then
                  r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
               else
                  r_gmovi.est_cuenta      := cta.estado;
               end if;
               r_gmovi.nro_documento2  := r_gcope.cat_automatica;
               r_gmovi.monto           := nvl(v_pag_prevision,0);
               r_gmovi.cod_moneda      := v_cod_mon_local;
               r_gmovi.mto_equ_local   := null;
               r_gmovi.cod_transaccion := 9152;
               pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
               -- Debito Pérdida.
               LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora); 
               r_gmovi.concepto        := 'Disminución. - Pre';
               If cta.estado = 'N' Then
                  r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
               else
                  r_gmovi.est_cuenta      := cta.estado;
               end if;
               r_gmovi.nro_documento2  := r_gcope.cat_automatica;
               r_gmovi.monto           := nvl(v_pag_prevision,0);
               r_gmovi.cod_moneda      := v_cod_mon_local;
               r_gmovi.mto_equ_local   := null;
               r_gmovi.cod_transaccion := 9153;
               pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
            elsif nvl(v_pag_prevision,0) < 0 and nvl(r_gcope.tot_prevision,0) <= nvl(r_pvalu.tot_prevision,0) then
               -- Acredito valuación. 
               LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora); 
               r_gmovi.concepto        := 'Disminución - Pre';
               If cta.estado = 'N' Then
                  r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
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
               LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora); 
               r_gmovi.concepto        := 'Disminución - Pre';
               If cta.estado = 'N' Then
                  r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
               else
                  r_gmovi.est_cuenta      := cta.estado;
               end if;
               r_gmovi.nro_documento2  := r_gcope.cat_automatica;
               r_gmovi.monto           := abs(nvl(v_pag_prevision,0));
               r_gmovi.cod_moneda      := v_cod_mon_local;
               r_gmovi.mto_equ_local   := null;
               r_gmovi.cod_transaccion := 9153;  --- Perdida
               pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
            elsif nvl(v_pag_prevision,0) < 0 and nvl(r_gcope.tot_prevision,0) > nvl(r_pvalu.tot_prevision,0) then
               -- Debito Valuación.
               LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora); 
               r_gmovi.concepto        := 'Aumenta - Pre';
               If cta.estado = 'N' Then
                  r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
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
               LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora); 
               r_gmovi.concepto        := 'Aumenta - Pre';
               r_gmovi.est_cuenta      := 'N';
               r_gmovi.nro_documento2  := r_gcope.cat_automatica;
               r_gmovi.monto           := nvl(v_pag_prevision,0) * (-1);
               r_gmovi.cod_moneda      := v_cod_mon_local;
               r_gmovi.mto_equ_local   := null;
               r_gmovi.cod_transaccion := 9152;
               pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
            end if;
         end if;
         --
         v_dif_prevision := nvl(v_dif_prevision,0) * (-1);
         if v_dif_prevision <> 0 or cta.estado = 'N' or v_cam_situacion = 'S' then
            if v_dif_prevision > 0 then
               if v_dif_prevision > (nvl(r_pvalu.tot_val_prevision,0) - nvl(v_pag_prevision,0)) then                  
                   
                  LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora); 
                  r_gmovi.concepto        := 'Ganancia por dif. de cambio - Pre Dia';
                  If cta.estado = 'N' Then
                     r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
                  else
                     r_gmovi.est_cuenta      := cta.estado;
                  end if;
                  r_gmovi.nro_documento2  := r_gcope.cat_automatica;
                  r_gmovi.monto           := (nvl(r_pvalu.tot_val_prevision,0) - nvl(v_pag_prevision,0));
                  r_gmovi.cod_moneda      := v_cod_mon_local;
                  r_gmovi.mto_equ_local   := null;
                  r_gmovi.cod_transaccion := 9152;
                  pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
                  -- 
                  LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora);  
                  r_gmovi.concepto        := 'Ganancia por dif. de cambio - Pre Dia';
                  r_gmovi.est_cuenta      := 'N';
                  r_gmovi.nro_documento2  := r_gcope.cat_automatica;
                  r_gmovi.monto           := nvl(v_dif_prevision,0) - (nvl(r_pvalu.tot_val_prevision,0) - nvl(v_pag_prevision,0));
                  r_gmovi.cod_moneda      := v_cod_mon_local;
                  r_gmovi.mto_equ_local   := null;
                  r_gmovi.cod_transaccion := 9152;
                  pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
               else                  
                   
                  LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora); 
                  r_gmovi.concepto        := 'Ganancia por dif. de cambio - Pre Dia';
                  If cta.estado = 'N' Then
                     r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
                  else
                     r_gmovi.est_cuenta      := cta.estado;
                  end if;
                  r_gmovi.nro_documento2  := r_gcope.cat_automatica;
                  r_gmovi.monto           := v_dif_prevision;
                  r_gmovi.cod_moneda      := v_cod_mon_local;
                  r_gmovi.mto_equ_local   := null;
                  r_gmovi.cod_transaccion := 9152;
                  pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
               end if;
               --- Verifica si se canceló o se cambió de estado debe reconocer la ganancia.
               if (nvl(r_pvalu.tot_val_prevision,0) - nvl(v_pag_prevision,0)) > 0 and --BBVASOP-1464.
                 (v_cam_situacion = 'S' or cta.estado = 'N') then
                LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora); 
                r_gmovi.concepto        := 'Actualiza Valuacion x Pre Acu_1';
                r_gmovi.cod_moneda      := v_cod_mon_local;
                r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
                r_gmovi.nro_documento2  := nvl(r_pvalu.cat_automatica,r_gcope.cat_automatica);
                If cta.estado = 'N' then
                   r_gmovi.monto := ((nvl(r_pvalu.tot_val_prevision,0) - nvl(v_pag_prevision,0)) + v_dif_prevision);
                Else
                   r_gmovi.monto := ((nvl(r_pvalu.tot_val_prevision,0) - nvl(v_pag_prevision,0)));
                End if;
                r_gmovi.mto_equ_local   := null;
                r_gmovi.cod_transaccion := 9152;
                pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
                --- Afecta a cartera por el mismo importe.
                LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora);  
                r_gmovi.concepto        := 'Act. por dif. de cambio - Pre Acu_1';
                r_gmovi.est_cuenta      := cta.estado;
                r_gmovi.nro_documento2  := r_gcope.cat_automatica;
                r_gmovi.cod_transaccion := 9152; -- Cartera
                r_gmovi.cod_moneda      := v_cod_mon_local;
                If cta.estado = 'N' then
                   r_gmovi.monto := ((nvl(r_pvalu.tot_val_prevision,0) - nvl(v_pag_prevision,0)) + v_dif_prevision) * (-1);
                Else
                   r_gmovi.monto := ((nvl(r_pvalu.tot_val_prevision,0) - nvl(v_pag_prevision,0))) * (-1);
                End if;
                r_gmovi.mto_equ_local   := null;
                pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
               end if;
            elsif v_dif_prevision < 0 then
               if (nvl(r_pvalu.tot_val_prevision,0) - nvl(v_pag_prevision,0)) > 0 then
                -- Fecha: 16/09/2015.
                -- Requerimiento: DYDMR-2253.
                if (nvl(v_cotizacion,-1) - nvl(r_pvalu.cotizacion,v_cotizacion)) > 0 then
                  ---Disminuyo Valuación en Suspenso. EP
                  LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora); 
                  r_gmovi.concepto        := 'Desafectacion ganancia - Pre Acu_2';
                  r_gmovi.cod_moneda      := v_cod_mon_local;
                  If cta.estado = 'N' Then
                    r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
                  else
                    r_gmovi.est_cuenta      := cta.estado;
                  end if;
                  r_gmovi.nro_documento2  := nvl(r_pvalu.cat_automatica,r_gcope.cat_automatica);
                  r_gmovi.monto           := (nvl(v_dif_prevision,0));
                  r_gmovi.mto_equ_local   := null;
                  r_gmovi.cod_transaccion := 152;
                  pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');

                else

                  if abs(v_dif_prevision) > (nvl(r_pvalu.tot_val_prevision,0) - nvl(v_pag_prevision,0)) then
                    --- Desafectar ganancia y el resto va a perdida 
                    LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora); 
                    r_gmovi.concepto        := 'Desafectacion ganancia - Pre Acu_2';
                    r_gmovi.cod_moneda      := v_cod_mon_local;
                    If cta.estado = 'N' Then
                      r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
                    else
                      r_gmovi.est_cuenta      := cta.estado;
                    end if;
                    r_gmovi.nro_documento2  := nvl(r_pvalu.cat_automatica,r_gcope.cat_automatica);
                    r_gmovi.monto           := ((nvl(r_pvalu.tot_val_prevision,0) - nvl(v_pag_prevision,0))*-1);
                    r_gmovi.mto_equ_local   := null;
                    r_gmovi.cod_transaccion := 9152;
                    pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
                    ---- 
                    LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora); 
                    r_gmovi.concepto        := 'Perdida por dif. de cambio - Pre Acu_2';
                    If cta.estado = 'N' Then
                      r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
                    else
                      r_gmovi.est_cuenta      := cta.estado;
                    end if;
                    r_gmovi.nro_documento2  := r_gcope.cat_automatica;
                    r_gmovi.monto           := abs(nvl(v_dif_prevision,0)) - abs((nvl(r_pvalu.tot_val_prevision,0) - nvl(v_pag_prevision,0)));
                    r_gmovi.cod_moneda      := v_cod_mon_local;
                    r_gmovi.mto_equ_local   := null;
                    r_gmovi.cod_transaccion := 9153;  --- Perdida
                    pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
                  else
                    --- Si es menor al monto valuado debe desafectar
                    LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora); 
                    r_gmovi.concepto        := 'Desafectacion ganancia - Pre Acu_2';
                    r_gmovi.cod_moneda      := v_cod_mon_local;
                    If cta.estado = 'N' Then
                      r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
                    else
                      r_gmovi.est_cuenta      := cta.estado;
                    end if;
                    r_gmovi.nro_documento2  := nvl(r_pvalu.cat_automatica,r_gcope.cat_automatica);
                    r_gmovi.monto           := (nvl(v_dif_prevision,0));
                    r_gmovi.mto_equ_local   := null;
                    r_gmovi.cod_transaccion := 9152;
                    pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
                  end if;
                end if;
                  --- Verifica si se cancelo o se cambio de estado debe reconocer la ganancia.
                  if nvl(v_dif_prevision,0) + (nvl(r_pvalu.tot_val_prevision,0) - nvl(v_pag_prevision,0)) > 0 and
                     (v_cam_situacion = 'S' or cta.estado = 'N') then
                    LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora);  
                    r_gmovi.concepto        := 'Desafectacion ganancia x Pre Acu_3';
                    r_gmovi.cod_moneda      := v_cod_mon_local;
                    r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
                    r_gmovi.nro_documento2  := nvl(r_pvalu.cat_automatica,r_gcope.cat_automatica);
                    r_gmovi.monto           := (nvl(v_dif_prevision,0) + (nvl(r_pvalu.tot_val_prevision,0) - nvl(v_pag_prevision,0)));
                    r_gmovi.mto_equ_local   := null;
                    r_gmovi.cod_transaccion := 9152;
                    pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
                    --- Afecta a cartera por el mismo importe. 
                    LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora);  
                    r_gmovi.concepto        := 'Act. por dif. de cambio - Pre Acu_3';
                    r_gmovi.est_cuenta      := cta.estado;
                    r_gmovi.nro_documento2  := r_gcope.cat_automatica;
                    r_gmovi.cod_transaccion := 9152; -- Cartera
                    r_gmovi.cod_moneda      := v_cod_mon_local;
                    r_gmovi.monto           := (nvl(v_dif_prevision,0) + (nvl(r_pvalu.tot_val_prevision,0) - nvl(v_pag_prevision,0))) * (-1);
                    r_gmovi.mto_equ_local   := null;
                    pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
                  end if;
               -- Fecha: 06/08/2014.
               -- Requerimiento: DYDMR-791.
               elsif (nvl(r_pvalu.tot_val_prevision,0) - nvl(v_pag_prevision,0)) = 0 and (nvl(v_cotizacion,-1) - nvl(r_pvalu.cotizacion,v_cotizacion)) > 0 then
                  --- Desafectación de la valuación por cambio de estado y aumento de la cotización.  
                  LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora); 
                  r_gmovi.concepto        := 'Desafectacion ganancia - Pre Est';
                  r_gmovi.cod_moneda      := v_cod_mon_local;
                  If cta.estado = 'N' Then
                     r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
                  else
                     r_gmovi.est_cuenta      := cta.estado;
                  end if;
                  r_gmovi.nro_documento2  := nvl(r_pvalu.cat_automatica,r_gcope.cat_automatica);
                  r_gmovi.monto           := (nvl(v_dif_prevision,0));
                  r_gmovi.mto_equ_local   := null;
                  r_gmovi.cod_transaccion := 9152;
                  pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
               else --- Todo a perdida 
                  LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora);
                  r_gmovi.concepto        := 'Perdida por dif. de cambio - Pre Acu_3';
                  If cta.estado = 'N' Then
                    r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
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
              if (nvl(r_pvalu.tot_val_prevision,0) - nvl(v_pag_prevision,0)) > 0 and
                 (v_cam_situacion = 'S' or cta.estado = 'N') then
                LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora); 
                r_gmovi.concepto        := 'Actualiza valuacion x Pre Acu_4';
                r_gmovi.cod_moneda      := v_cod_mon_local;
                r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
                r_gmovi.nro_documento2  := nvl(r_pvalu.cat_automatica,r_gcope.cat_automatica);
                r_gmovi.monto           := (nvl(r_pvalu.tot_val_prevision,0) - nvl(v_pag_prevision,0));
                r_gmovi.mto_equ_local   := null;
                r_gmovi.cod_transaccion := 9152;
                pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
                --- Afecta a cartera por el mismo importe. 
                LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora); 
                r_gmovi.concepto        := 'Act. por dif. de cambio - Pre Acu_4';
                r_gmovi.est_cuenta      := cta.estado;
                r_gmovi.nro_documento2  := r_gcope.cat_automatica;
                r_gmovi.cod_transaccion := 9152; -- Cartera
                r_gmovi.cod_moneda      := v_cod_mon_local;
                r_gmovi.monto           := ((nvl(r_pvalu.tot_val_prevision,0) - nvl(v_pag_prevision,0))) * (-1);
                r_gmovi.mto_equ_local   := null;
                pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
              end if;
            end if;
            v_dif_prevision := nvl(v_dif_prevision,0) * (-1);
            if (nvl(cta.estado,'A') in ('A','C') and
                nvl(r_gcope.cat_automatica,1) in (1,2) ) or
                cta.estado = 'N' then
               --- No es necesario acumular el saldo cuando va todo a pérdida o
               --- son cuentas que generan directamente ganancia o pérdida
               r_pvalc.tot_val_prevision := 0;
            else --- Acumular saldos solo para cuentas a valuar en suspenso
               r_pvalc.tot_val_prevision := nvl(r_pvalu.tot_val_prevision,0) + (nvl(v_dif_prevision,0) - nvl(v_pag_prevision,0));
            end if;
            --- Generar movimiento por la cartera por la diferencia de cotizacion.
            if v_dif_prevision != 0 then 
              LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora); 
              r_gmovi.monto           := 0;
              r_gmovi.cod_moneda      := cta.cod_moneda;
              r_gmovi.mto_equ_local   := v_dif_prevision;
              r_gmovi.concepto        := 'Act. por dif. de cambio - Pre Dia';
              r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
              r_gmovi.nro_documento2  := r_gcope.cat_automatica;
              r_gmovi.cod_transaccion := 166; -- Cartera
              pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
            end if;
         else
            r_pvalc.tot_val_prevision := (nvl(r_pvalu.tot_val_prevision,0) - nvl(v_pag_prevision,0));
         end if;
         ----------------------------------------------------
         --- Procesar DEVENGADO EN SUSPENSO (169,170,171) ---
         ----------------------------------------------------
         v_pag_suspenso := 0;
         v_dif_suspenso := 0;
         v_cam_situacion := 'N';
         If (nvl(r_pvalu.estado,'A') not in ('A','C') or nvl(r_pvalu.cat_automatica,1) not in (1,2)) and
            (nvl(cta.estado,'A') in ('A','C') and nvl(r_gcope.cat_automatica,1) in (1,2)) then
            v_cam_situacion := 'S';
         End if;
         --
         if cta.estado <> 'N' then
            v_dif_suspenso := round((nvl(cta.dev_suspenso,0)* (v_cotizacion - nvl(r_pvalu.cotizacion,v_cotizacion))),v_redondeo_ml);
         else
            v_dif_suspenso := round((nvl(r_pvalu.dev_suspenso,0)* (v_cotizacion - nvl(r_pvalu.cotizacion,v_cotizacion))),v_redondeo_ml);
         end if;
         --
         if nvl(v_pag_devengar,0) <> 0 then
            v_pag_suspenso := nvl(v_pag_devengar,0) * (-1);
         end if;
         --
         if cta.estado = 'N' then
            v_pag_suspenso := 0;
         end if;
         --
         if nvl(v_mto_ori_suspenso,0) <> 0 then
            -- Calcula el valor.
            if nvl(r_pvalu.tot_val_suspenso,0) <> 0 and nvl(v_mto_ori_suspenso, 0) <> 0 and nvl(r_pvalu.dev_suspenso,0) <> 0 then
               v_mto_suspenso := round(nvl(r_pvalu.tot_val_suspenso, 0) * nvl(v_mto_ori_suspenso, 0) / nvl(r_pvalu.dev_suspenso,0),v_redondeo_ml);
            else
               v_mto_suspenso := 0;
            end if;
            -- Acredito Ganancia.
            LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora); 
            r_gmovi.concepto        := 'Ganancia por Pago - Susp';
            r_gmovi.est_cuenta      := 'N';
            r_gmovi.nro_documento2  := r_gcope.cat_automatica;
            r_gmovi.monto           := nvl(v_mto_suspenso,0);
            r_gmovi.cod_moneda      := v_cod_mon_local;
            r_gmovi.mto_equ_local   := null;
            r_gmovi.cod_transaccion := 152;
            pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
            --
            -- Desafecta Valuación.   
            LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora); 
            r_gmovi.concepto        := 'Desaf. Valuacion por Pago - Susp';
            If cta.estado = 'N' Then
               r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
            else
               r_gmovi.est_cuenta      := cta.estado;
            end if;
            r_gmovi.nro_documento2  := r_gcope.cat_automatica;
            r_gmovi.monto           := nvl(v_mto_suspenso,0) * (-1);
            r_gmovi.cod_moneda      := v_cod_mon_local;
            r_gmovi.mto_equ_local   := null;
            r_gmovi.cod_transaccion := 152;
            pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
         end if;
         --
         v_dif_suspenso := nvl(v_dif_suspenso,0) * (-1);
         if v_dif_suspenso <> 0 or cta.estado = 'N' or v_cam_situacion = 'S' then
            if v_dif_suspenso > 0 then
               if v_dif_suspenso > nvl(r_pvalu.tot_val_suspenso,0) then   
                  LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora); 
                  r_gmovi.concepto        := 'Ganancia por dif. de cambio - DSu Dia';
                  If cta.estado = 'N' Then
                     r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
                  else
                     r_gmovi.est_cuenta      := cta.estado;
                  end if;
                  r_gmovi.nro_documento2  := r_gcope.cat_automatica;
                  r_gmovi.monto           := nvl(r_pvalu.tot_val_suspenso,0);
                  r_gmovi.cod_moneda      := v_cod_mon_local;
                  r_gmovi.mto_equ_local   := null;
                  r_gmovi.cod_transaccion := 152;
                  pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
                  --                  
                  LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora); 
                  r_gmovi.concepto        := 'Ganancia por dif. de cambio - DSu Dia';
                  r_gmovi.est_cuenta      := 'N';
                  r_gmovi.nro_documento2  := r_gcope.cat_automatica;
                  r_gmovi.monto           := nvl(v_dif_suspenso,0) - nvl(r_pvalu.tot_val_suspenso,0);
                  r_gmovi.cod_moneda      := v_cod_mon_local;
                  r_gmovi.mto_equ_local   := null;
                  r_gmovi.cod_transaccion := 152;
                  pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
               else
                  LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora); 
                  r_gmovi.concepto        := 'Ganancia por dif. de cambio - DSu Dia';
                  If cta.estado = 'N' Then
                     r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
                  else
                     r_gmovi.est_cuenta      := cta.estado;
                  end if;
                  r_gmovi.nro_documento2  := r_gcope.cat_automatica;
                  r_gmovi.monto           := v_dif_suspenso;
                  r_gmovi.cod_moneda      := v_cod_mon_local;
                  r_gmovi.mto_equ_local   := null;
                  r_gmovi.cod_transaccion := 152;
                  pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
               end if;
               --- Verifica si se canceló o se cambió de estado debe reconocer la ganancia.
               if nvl(r_pvalu.tot_val_suspenso,0) > 0 and --BBVASOP-1464.
                 (v_cam_situacion = 'S' or cta.estado = 'N') then   
                LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora);  
                r_gmovi.concepto        := 'Actualiza Valuacion x DSu Acu_1';
                r_gmovi.cod_moneda      := v_cod_mon_local;
                If cta.estado = 'N' Then
                   r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
                else
                   r_gmovi.est_cuenta      := cta.estado;
                end if;
                r_gmovi.nro_documento2  := nvl(r_pvalu.cat_automatica,r_gcope.cat_automatica);
                If cta.estado = 'N' then
                   r_gmovi.monto := (nvl(r_pvalu.tot_val_suspenso,0) + v_dif_suspenso);
                Else
                   r_gmovi.monto := (nvl(r_pvalu.tot_val_suspenso,0));
                End if;
                r_gmovi.mto_equ_local   := null;
                r_gmovi.cod_transaccion := 152;
                pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
                --- Afecta a cartera por el mismo importe.  
                LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora); 
                r_gmovi.concepto        := 'Act. por dif. de cambio - DSu Acu_1';
                r_gmovi.est_cuenta      := cta.estado;
                r_gmovi.nro_documento2  := r_gcope.cat_automatica;
                r_gmovi.cod_transaccion := 152; -- Cartera
                r_gmovi.cod_moneda      := v_cod_mon_local;
                If cta.estado = 'N' then
                   r_gmovi.monto := (nvl(r_pvalu.tot_val_suspenso,0) + v_dif_suspenso) * (-1);
                Else
                   r_gmovi.monto := (nvl(r_pvalu.tot_val_suspenso,0)) * (-1);
                End if;
                r_gmovi.mto_equ_local   := null;
                pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
               end if;
            elsif v_dif_suspenso < 0 then
               if nvl(r_pvalu.tot_val_suspenso,0) > 0 then
                -- Fecha: 16/09/2015.
                -- Requerimiento: DYDMR-2253.
                if (nvl(v_cotizacion,-1) - nvl(r_pvalu.cotizacion,v_cotizacion)) > 0 then
                  ---Disminuyo Valuación en Suspenso. EP 
                  LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora); 
                  r_gmovi.concepto        := 'Desafectacion ganancia - DSu Acu_2';
                  r_gmovi.cod_moneda      := v_cod_mon_local;
                  If cta.estado = 'N' Then
                    r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
                  else
                    r_gmovi.est_cuenta      := cta.estado;
                  end if;
                  r_gmovi.nro_documento2  := nvl(r_pvalu.cat_automatica,r_gcope.cat_automatica);
                  r_gmovi.monto           := (nvl(v_dif_suspenso,0));
                  r_gmovi.mto_equ_local   := null;
                  r_gmovi.cod_transaccion := 152;
                  pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');

                else

                  if abs(v_dif_suspenso) > nvl(r_pvalu.tot_val_suspenso,0) then
                    --- Desafectar ganancia y el resto va a perdida   
                    LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora);  
                    r_gmovi.concepto        := 'Desafectacion ganancia - DSu Acu_2';
                    r_gmovi.cod_moneda      := v_cod_mon_local;
                    If cta.estado = 'N' Then
                      r_gmovi.est_cuenta    := nvl(r_pvalu.estado,cta.estado);
                    else
                      r_gmovi.est_cuenta    := cta.estado;
                    end if;
                    r_gmovi.nro_documento2  := nvl(r_pvalu.cat_automatica,r_gcope.cat_automatica);
                    r_gmovi.monto           := (nvl(r_pvalu.tot_val_suspenso,0)*-1);
                    r_gmovi.mto_equ_local   := null;
                    r_gmovi.cod_transaccion := 152;
                    pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
                    ----       
                    LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora);  
                    r_gmovi.concepto        := 'Perdida por dif. de cambio - DSu Acu_2';
                    If cta.estado = 'N' Then
                      r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
                    else
                      r_gmovi.est_cuenta      := cta.estado;
                    end if;
                    r_gmovi.nro_documento2  := r_gcope.cat_automatica;
                    r_gmovi.monto           := abs(nvl(v_dif_suspenso,0)) - abs(nvl(r_pvalu.tot_val_suspenso,0));
                    r_gmovi.cod_moneda      := v_cod_mon_local;
                    r_gmovi.mto_equ_local   := null;
                    r_gmovi.cod_transaccion := 153;  --- Perdida
                    pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
                  else
                    --- Si es menor al monto valuado debe desafectar  
                    LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora); 
                    r_gmovi.concepto        := 'Desafectacion ganancia - DSu Acu_2';
                    r_gmovi.cod_moneda      := v_cod_mon_local;
                    If cta.estado = 'N' Then
                      r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
                    else
                      r_gmovi.est_cuenta      := cta.estado;
                    end if;
                    r_gmovi.nro_documento2  := nvl(r_pvalu.cat_automatica,r_gcope.cat_automatica);
                    r_gmovi.monto           := (nvl(v_dif_suspenso,0));
                    r_gmovi.mto_equ_local   := null;
                    r_gmovi.cod_transaccion := 152;
                    pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
                  end if;
                 end if;
                  --- Verifica si se cancelo o se cambio de estado debe reconocer la ganancia.
                  if nvl(v_dif_suspenso,0) + nvl(r_pvalu.tot_val_suspenso,0) > 0 and
                     (v_cam_situacion = 'S' or cta.estado = 'N') then                    
                     
                    LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora); 
                    r_gmovi.concepto        := 'Desafectacion ganancia x DSu Acu_3';
                    r_gmovi.cod_moneda      := v_cod_mon_local;
                    If cta.estado = 'N' Then
                       r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
                    else
                       r_gmovi.est_cuenta      := cta.estado;
                    end if;
                    r_gmovi.nro_documento2  := nvl(r_pvalu.cat_automatica,r_gcope.cat_automatica);
                    r_gmovi.monto           := (nvl(v_dif_suspenso,0) + nvl(r_pvalu.tot_val_suspenso,0));
                    r_gmovi.mto_equ_local   := null;
                    r_gmovi.cod_transaccion := 152;
                    pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
                    --- Afecta a cartera por el mismo importe. 
                    LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora); 
                    r_gmovi.concepto        := 'Act. por dif. de cambio - DSu Acu_3';
                    r_gmovi.est_cuenta      := cta.estado;
                    r_gmovi.nro_documento2  := r_gcope.cat_automatica;
                    r_gmovi.cod_transaccion := 152; -- Cartera
                    r_gmovi.cod_moneda      := v_cod_mon_local;
                    r_gmovi.monto           := (nvl(v_dif_suspenso,0) + nvl(r_pvalu.tot_val_suspenso,0)) * (-1);
                    r_gmovi.mto_equ_local   := null;
                    pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
                  end if;
               -- Fecha: 06/08/2014.
               -- Requerimiento: DYDMR-791.
               elsif nvl(r_pvalu.tot_val_suspenso,0) = 0 and (nvl(v_cotizacion,-1) - nvl(r_pvalu.cotizacion,v_cotizacion)) > 0 then
                  --- Desafectación de la valuación por cambio de estado y aumento de la cotización. 
                  LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora); 
                  r_gmovi.concepto        := 'Desafectacion ganancia - DSu Est';
                  r_gmovi.cod_moneda      := v_cod_mon_local;
                  If cta.estado = 'N' Then
                     r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
                  else
                     r_gmovi.est_cuenta      := cta.estado;
                  end if;
                  r_gmovi.nro_documento2  := nvl(r_pvalu.cat_automatica,r_gcope.cat_automatica);
                  r_gmovi.monto           := (nvl(v_dif_suspenso,0));
                  r_gmovi.mto_equ_local   := null;
                  r_gmovi.cod_transaccion := 152;
                  pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
               else --- Todo a perdida  
                  LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora); 
                  r_gmovi.concepto        := 'Perdida por dif. de cambio - DSu Acu_3';
                  If cta.estado = 'N' Then
                    r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
                  else
                    r_gmovi.est_cuenta      := cta.estado;
                  end if;
                  r_gmovi.nro_documento2  := r_gcope.cat_automatica;
                  r_gmovi.monto           := abs(v_dif_suspenso);
                  r_gmovi.cod_moneda      := v_cod_mon_local;
                  r_gmovi.mto_equ_local   := null;
                  r_gmovi.cod_transaccion := 153;
                  pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
               end if;
            else --- NO TUVO DIFERENCIA DE COTIZACION...
              --- Verifica si se cancelo o se cambio de estado debe reconocer la ganancia.
              if nvl(r_pvalu.tot_val_suspenso,0) > 0 and
                 (v_cam_situacion = 'S' or cta.estado = 'N') then  
                LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora);  
                r_gmovi.concepto        := 'Actualizo Valuacion x DSu Acu_4';
                r_gmovi.cod_moneda      := v_cod_mon_local;
                If cta.estado = 'N' Then
                   r_gmovi.est_cuenta   := nvl(r_pvalu.estado,cta.estado);
                else
                   r_gmovi.est_cuenta   := cta.estado;
                end if;
                r_gmovi.nro_documento2  := nvl(r_pvalu.cat_automatica,r_gcope.cat_automatica);
                r_gmovi.monto           := nvl(r_pvalu.tot_val_suspenso,0);
                r_gmovi.mto_equ_local   := null;
                r_gmovi.cod_transaccion := 152;
                pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
                --- Afecta a cartera por el mismo importe.   
                LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora);  
                r_gmovi.concepto        := 'Act. por dif. de cambio - DSu Acu_4';
                r_gmovi.est_cuenta      := cta.estado;
                r_gmovi.nro_documento2  := r_gcope.cat_automatica;
                r_gmovi.cod_transaccion := 152; -- Cartera
                r_gmovi.cod_moneda      := v_cod_mon_local;
                r_gmovi.monto           := (nvl(r_pvalu.tot_val_suspenso,0)) * (-1);
                r_gmovi.mto_equ_local   := null;
                pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
              end if;
            end if;
            v_dif_suspenso := nvl(v_dif_suspenso,0) * (-1);
            if (nvl(cta.estado,'A') in ('A','C') and
                nvl(r_gcope.cat_automatica,1) in (1,2) ) or
                cta.estado = 'N' then
               --- No es necesario acumular el saldo cuando va todo a perdida o
               --- son cuentas que generan directamente ganancia o perdida
               r_pvalc.tot_val_suspenso := 0;
            else --- Acumular saldos solo para cuentas a valuar en suspenso
               r_pvalc.tot_val_suspenso := nvl(r_pvalu.tot_val_suspenso,0) + (nvl(v_dif_suspenso,0) + nvl(v_pag_suspenso,0) + nvl(v_mto_suspenso,0));
            end if;
            --- Generar movimiento por la cartera por la diferencia de cotizacion.
            if v_dif_suspenso != 0 then 
              LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora); 
              r_gmovi.monto           := 0;
              r_gmovi.cod_moneda      := cta.cod_moneda;
              r_gmovi.mto_equ_local   := v_dif_suspenso;
              r_gmovi.concepto        := 'Act. por dif. de cambio - DSu Dia';
              r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
              r_gmovi.nro_documento2  := r_gcope.cat_automatica;
              r_gmovi.cod_transaccion := 170; -- Cartera
              pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
            end if;
         else
            r_pvalc.tot_val_suspenso := nvl(r_pvalu.tot_val_suspenso,0) + nvl(v_mto_suspenso,0);
         end if;
         --- Actualizar valuaciones
         r_pvalc.cot_anterior := r_pvalu.cotizacion;
         -- Obtengo el saldo neto de la valuación.
         r_pvalc.tot_valuacion := nvl(r_pvalu.tot_valuacion,0) +
                                  (((case when r_pvalc.tot_val_capital < 0 then
                                            nvl(r_pvalu.tot_val_capital,0) * (-1)
                                         else
                                            (nvl(v_dif_capital,0) - nvl(v_pag_capital,0))
                                         end) +
                                    (case when r_pvalc.tot_val_interes < 0 then
                                            nvl(r_pvalu.tot_val_interes,0) * (-1)
                                         else
                                            (nvl(v_dif_interes,0) - nvl(v_pag_interes,0))
                                         end) +
                                    (case when r_pvalc.tot_val_int_ade < 0 then
                                            nvl(r_pvalu.tot_val_int_ade,0) * (-1)
                                         else
                                            (nvl(v_dif_int_adelantado,0) - nvl(v_pag_int_adelantado,0))
                                         end)) -
                                    (case when r_pvalc.tot_val_int_devengar < 0 then
                                            nvl(r_pvalu.tot_val_int_devengar,0) * (-1)
                                         else
                                            (nvl(v_dif_devengar,0) + nvl(v_pag_devengar,0))
                                         end) -
                                    (case when r_pvalc.tot_val_prevision < 0 then
                                            nvl(r_pvalu.tot_val_prevision,0) * (-1)
                                         else
                                            (nvl(v_dif_prevision,0) - nvl(v_pag_prevision,0))
                                         end) -
                                    (case when r_pvalc.tot_val_suspenso < 0 then
                                            nvl(r_pvalu.tot_val_suspenso,0) * (-1)
                                         else
                                            (nvl(v_dif_suspenso,0) + nvl(v_pag_suspenso,0) + nvl(v_mto_suspenso,0))
                                         end));
         if r_pvalc.tot_valuacion < 0 or
            (nvl(cta.estado,'A') in ('A','C') and nvl(r_gcope.cat_automatica,1) in (1,2) ) or
                cta.estado = 'N'then
            -- Genero los movimientos si tienen saldo positivo los acumulados.
            -- Capital.
            if NVL(r_pvalc.tot_val_capital,0) > 0 then
               -- Acredito Ganancia. 
               LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora); 
               r_gmovi.concepto        := 'Ganancia Tot. Acumulado - Cap';
               r_gmovi.est_cuenta      := 'N';
               r_gmovi.nro_documento2  := r_gcope.cat_automatica;
               r_gmovi.monto           := nvl(r_pvalc.tot_val_capital,0);
               r_gmovi.cod_moneda      := v_cod_mon_local;
               r_gmovi.mto_equ_local   := null;
               r_gmovi.cod_transaccion := 152;
               pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
               -- Desafecta Valuación.  
               LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora); 
               r_gmovi.concepto        := 'Desaf. Valuacion Tot. Acumulado - Cap';
               If cta.estado = 'N' Then
                  r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
               else
                  r_gmovi.est_cuenta      := cta.estado;
               end if;
               r_gmovi.nro_documento2  := r_gcope.cat_automatica;
               r_gmovi.monto           := nvl(r_pvalc.tot_val_capital,0) * (-1);
               r_gmovi.cod_moneda      := v_cod_mon_local;
               r_gmovi.mto_equ_local   := null;
               r_gmovi.cod_transaccion := 152;
               pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
            end if;
            -- Interes.
            if NVL(r_pvalc.tot_val_interes,0) > 0 then
               -- Acredito Ganancia.
               LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora); 
               r_gmovi.concepto        := 'Ganancia Tot. Acumulado - Int';
               r_gmovi.est_cuenta      := 'N';
               r_gmovi.nro_documento2  := r_gcope.cat_automatica;
               r_gmovi.monto           := nvl(r_pvalc.tot_val_interes,0);
               r_gmovi.cod_moneda      := v_cod_mon_local;
               r_gmovi.mto_equ_local   := null;
               r_gmovi.cod_transaccion := 152;
               pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
               -- Desafectación de valuación.  
               LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora);  
               r_gmovi.concepto        := 'Desaf. Valuación Tot. Acumulado - Int';
               If cta.estado = 'N' Then
                  r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
               else
                  r_gmovi.est_cuenta      := cta.estado;
               end if;
               r_gmovi.nro_documento2  := r_gcope.cat_automatica;
               r_gmovi.monto           := nvl(r_pvalc.tot_val_interes,0) * (-1);
               r_gmovi.cod_moneda      := v_cod_mon_local;
               r_gmovi.mto_equ_local   := null;
               r_gmovi.cod_transaccion := 152;
               pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
            end if;
            -- Interes Adelantado.
            if NVL(r_pvalc.tot_val_int_ade,0) > 0 then
               -- Acredito Ganancia. 
               LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora);  
               r_gmovi.concepto        := 'Ganancia Tot. Acumulado - IAd';
               r_gmovi.est_cuenta      := 'N';
               r_gmovi.nro_documento2  := r_gcope.cat_automatica;
               r_gmovi.monto           := nvl(r_pvalc.tot_val_int_ade,0);
               r_gmovi.cod_moneda      := v_cod_mon_local;
               r_gmovi.mto_equ_local   := null;
               r_gmovi.cod_transaccion := 152;
               pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
               -- Desafectación de Valuación. 
               LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora); 
               r_gmovi.concepto        := 'Desaf. Valuación Tot. Acumulado - IAd';
               If cta.estado = 'N' Then
                  r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
               else
                  r_gmovi.est_cuenta      := cta.estado;
               end if;
               r_gmovi.nro_documento2  := r_gcope.cat_automatica;
               r_gmovi.monto           := nvl(r_pvalc.tot_val_int_ade,0) * (-1);
               r_gmovi.cod_moneda      := v_cod_mon_local;
               r_gmovi.mto_equ_local   := null;
               r_gmovi.cod_transaccion := 152;
               pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
            end if;
            -- Interes a Devengar.
            if NVL(r_pvalc.tot_val_int_devengar,0) > 0 then
               -- Desafectar ganancia y el resto va a perdida 
               LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora); 
               r_gmovi.concepto        := 'Desaf. ganancia Tot. Acumulado - Ade';
               r_gmovi.cod_moneda      := v_cod_mon_local;
               If cta.estado = 'N' Then
                  r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
               else
                  r_gmovi.est_cuenta      := cta.estado;
               end if;
               r_gmovi.nro_documento2  := nvl(r_pvalu.cat_automatica,r_gcope.cat_automatica);
               r_gmovi.monto           := nvl(r_pvalc.tot_val_int_devengar,0);
               r_gmovi.mto_equ_local   := null;
               r_gmovi.cod_transaccion := 152;
               pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
               --             
               LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora);  
               r_gmovi.concepto        := 'Perdida Tot. Acumulado - Ade';
               If cta.estado = 'N' Then
                  r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
               else
                  r_gmovi.est_cuenta      := cta.estado;
               end if;
               r_gmovi.nro_documento2  := r_gcope.cat_automatica;
               r_gmovi.monto           := nvl(r_pvalc.tot_val_int_devengar,0);
               r_gmovi.cod_moneda      := v_cod_mon_local;
               r_gmovi.mto_equ_local   := null;
               r_gmovi.cod_transaccion := 153;  --- Perdida
               pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
            end if;
            -- Previsión.
            if NVL(r_pvalc.tot_val_prevision,0) >0 then
               -- Acredito Valuación. 
               LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora); 
               r_gmovi.concepto        := 'Desaf. Ganancia Tot. Acumulado - Pre';
               If cta.estado = 'N' Then
                  r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
               else
                  r_gmovi.est_cuenta      := cta.estado;
               end if;
               r_gmovi.nro_documento2  := r_gcope.cat_automatica;
               r_gmovi.monto           := nvl(r_pvalc.tot_val_prevision,0);
               r_gmovi.cod_moneda      := v_cod_mon_local;
               r_gmovi.mto_equ_local   := null;
               r_gmovi.cod_transaccion := 9152;
               pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
               -- Debito Pérdida.
               LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora); 
               r_gmovi.concepto        := 'Perdida Tot. Acumulado - Pre';
               If cta.estado = 'N' Then
                  r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
               else
                  r_gmovi.est_cuenta      := cta.estado;
               end if;
               r_gmovi.nro_documento2  := r_gcope.cat_automatica;
               r_gmovi.monto           := nvl(r_pvalc.tot_val_prevision,0);
               r_gmovi.cod_moneda      := v_cod_mon_local;
               r_gmovi.mto_equ_local   := null;
               r_gmovi.cod_transaccion := 9153;
               pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
            end if;
            -- Suspenso.
            if NVL(r_pvalc.tot_val_suspenso,0) > 0 then
               -- Desafectar ganancia y el resto va a perdida.
               LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora); 
               r_gmovi.concepto        := 'Desaf. Ganancia Tot. Acumulado - DSu';
               r_gmovi.cod_moneda      := v_cod_mon_local;
               If cta.estado = 'N' Then
                  r_gmovi.est_cuenta    := nvl(r_pvalu.estado,cta.estado);
               else
                  r_gmovi.est_cuenta    := cta.estado;
               end if;
               r_gmovi.nro_documento2  := nvl(r_pvalu.cat_automatica,r_gcope.cat_automatica);
               r_gmovi.monto           := nvl(r_pvalc.tot_val_suspenso,0);
               r_gmovi.mto_equ_local   := null;
               r_gmovi.cod_transaccion := 152;
               pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
               --               
               LP_OBT_SECUENCIA(v_usuario, r_gmovi.nro_secuencia, r_gmovi.hora);  
               r_gmovi.concepto        := 'Perdida Tot. Acumulado - DSu';
               If cta.estado = 'N' Then
                  r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
               else
                  r_gmovi.est_cuenta      := cta.estado;
               end if;
               r_gmovi.nro_documento2  := r_gcope.cat_automatica;
               r_gmovi.monto           := nvl(r_pvalc.tot_val_suspenso,0);
               r_gmovi.cod_moneda      := v_cod_mon_local;
               r_gmovi.mto_equ_local   := null;
               r_gmovi.cod_transaccion := 153;  --- Perdida
               pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
            end if;

            -- Actualizo los acumulados.
            r_pvalc.tot_valuacion := 0;
            r_pvalc.tot_val_capital := 0;
            r_pvalc.tot_val_interes := 0;
            r_pvalc.tot_val_int_ade := 0;
            r_pvalc.tot_val_int_devengar := 0;
            r_pvalc.tot_val_suspenso := 0;
            r_pvalc.tot_val_prevision := 0;
         end if;
         --
         if r_pvalc.tot_val_capital < 0 then
            r_pvalc.tot_val_capital := 0;
         end if;
         if r_pvalc.tot_val_interes < 0 then
            r_pvalc.tot_val_interes := 0;
         end if;
         if r_pvalc.tot_val_int_ade < 0 then
            r_pvalc.tot_val_int_ade := 0;
         end if;
         if r_pvalc.tot_val_int_devengar < 0 then
            r_pvalc.tot_val_int_devengar := 0;
         end if;
         if r_pvalc.tot_val_prevision < 0 then
            r_pvalc.tot_val_prevision := 0;
         end if;
         if r_pvalc.tot_val_suspenso < 0 then
            r_pvalc.tot_val_suspenso := 0;
         end if;
         -- Actualizo la tabla pr_valuaciones.
         lp_act_valuacion(cta.nro_cuenta, v_fecha, v_cotizacion, r_pvalc, cta, r_gcope);        
      end if;
   end loop;
  end loop;
  CLOSE c_pre_valuar; 
   -- LIMPIAR la salida
   DBMS_APPLICATION_INFO.SET_ACTION(NULL);
   DBMS_APPLICATION_INFO.SET_CLIENT_INFO(NULL);
   it.pag_cie.PR_AT_INS_LOG(11, 351, 'PRP_GEN_VALUACIONES', 'FIN! Total: '||v_total_procesado, it.pag_cie.c_log_TRACE, 'OUT', SYSDATE);
END;
