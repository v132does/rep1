CREATE OR REPLACE PROCEDURE IT.PRP_OBT_TAS_PRE_TAE
 (P_NRO_SOLICITUD IN PR_CTA_PRESTAMOS.NRO_SOLICITUD%TYPE
 ,P_VAL_TAE IN OUT NUMBER
 ,P_VAL_TAN IN OUT NUMBER
 )
 IS
v_es_solicitud varchar2(1):='N';
/* Obtener gastos del prestamo. */
PROCEDURE LP_OBT_GAS_PRESTAMOS
 (P_NRO_SOLICITUD IN PR_SOLICITUDES.NRO_SOLICITUD%TYPE
 ,P_COD_MONEDA IN GE_CUENTAS.COD_MONEDA%TYPE
 ,P_MTO_DESEMBOLSO IN PR_SOLICITUDES.MONTO%TYPE
 ,P_MTO_CAR_IMPUTABLE IN OUT NUMBER
 ,P_MTO_CAR_NOIMPUTABLE IN OUT NUMBER
 ,P_ES_SOLICITUD IN VARCHAR2
 );
/* Obtener dias. */
FUNCTION LF_OBT_DIAS
 (P_NRO_SOLICITUD IN PR_CTA_PRESTAMOS.NRO_SOLICITUD%TYPE
 ,P_NRO_CUOTA IN PR_CUOTAS.NRO_CUOTA%TYPE
 ,P_ES_SOLICITUD IN VARCHAR2
 )
 RETURN NUMBER;
/* Obtener datos del prestamo. */
PROCEDURE LP_OBT_DAT_PRESTAMO
 (P_NRO_SOLICITUD IN GE_CUENTAS.NRO_CUENTA%TYPE
 ,P_COD_MONEDA IN OUT PR_SOLICITUDES.COD_MONEDA%TYPE
 ,P_MTO_CAPITAL IN OUT PR_SOLICITUDES.MONTO%TYPE
 ,P_TIP_INTERES IN OUT PR_SOLICITUDES.TIP_INTERES%TYPE
 ,P_FEC_INICIO IN OUT DATE
 ,P_FEC_VENCIMIENTO IN OUT DATE
 ,P_VAL_TASA IN OUT NUMBER
 ,P_TIP_AMORTIZACION IN OUT VARCHAR2
 ,P_CAN_CUOTAS IN OUT NUMBER
 ,P_MTO_DESEMBOLSO IN OUT PR_SOLICITUDES.MONTO%TYPE
 ,P_ES_SOLICITUD IN VARCHAR2
 );
   v_acum_tan number;
   v_acum_tae number;
   v_contador number;
   v_gastos_imp  number;
   v_gastos_noi  number;
   v_avg_dia     number;
   v_dif_cuotas  number;
    v_min_cuota   number;
   v_dif_permitida number := 1000;
    v_per_capital number;
   v_dias        number;
   v_dias_cuota  number;
   v_tot_dias    number;
   v_mto_gasto   number(18,2);
   v_cod_moneda      ge_cuentas.cod_moneda%type;
   v_mto_capital     pr_cta_prestamos.mto_capital%type;
   v_mto_desembolso  pr_cta_prestamos.monto%type;
   v_sal_capital     pr_cta_prestamos.mto_capital%type;
   v_fec_inicio      pr_cta_prestamos.fec_inicio%type;
   v_fec_vencimiento pr_solicitudes.fec_vencimiento%type;
   v_fec_vto_cuota_ant   pr_sol_cuotas.fec_vto_exacto%type;
   v_can_cuotas      number;
   v_numero          varchar2(3000);
   v_auxiliar        varchar2(3000);
   v_val_inicial     pr_cta_prestamos.mto_capital%type;
   v_tip_interes     pr_solicitudes.tip_interes%type;
   v_val_tas_pactada number;
   v_tip_amortizacion varchar2(1);

   v_redondeo        number(2) := 0;
   v_cod_modulo        number(3) := 0;
   v_cod_modalidad     number(3) := 0;
   v_cod_sub_modalidad number(3) := 0;

   v_aux1              number := 0;
   v_aux2              number := 0;

   v_aux_tir           number := 0;
   v_aux_vna           number := 0;
   v_aux_val_tasa      number := 0;
   v_aux_mto_cargo     number := 0;
    v_aux_aju_tae       varchar2(1) := 'N';
   v_val_tas_iva       number := 0;
   v_aux_mto_tae_1     number := 0;
   v_aux_mto_tae_2     number := 0;

   --- Cursor de cuotas
   cursor c_cuotas is
   select nro_cuota,
          nvl(mto_capital,0)+nvl(val_int_adelantado,0)+nvl(val_interes,0) val_cuota,
          nvl(mto_capital,0) mto_capital,
          nvl(val_interes,0) mto_interes,
          nvl(val_int_adelantado,0) mto_int_documentado,
          trunc(fec_vto_exacto - v_fec_inicio) dias,
          dia_interes,
          fec_vto_exacto
     from pr_sol_cuotas
    where nro_solicitud = p_nro_solicitud
      and nro_cuota > 0
   union all
   select nro_cuota,
          nvl(mto_capital,0) + nvl(mto_interes,0) val_cuota,
          nvl(mto_capital,0) mto_capital,
          nvl(mto_interes,0) mto_interes,
          0 mto_int_documentado,
          trunc(fec_vencimiento - v_fec_inicio) dias,
          per_dias,
          fec_vencimiento
     from pr_sim_cuotas
    where nro_simulacion = p_nro_solicitud
      and nro_cuota > 0

    order by 1;

/* Obtener gastos del prestamo. */
PROCEDURE LP_OBT_GAS_PRESTAMOS
 (P_NRO_SOLICITUD IN PR_SOLICITUDES.NRO_SOLICITUD%TYPE
 ,P_COD_MONEDA IN GE_CUENTAS.COD_MONEDA%TYPE
 ,P_MTO_DESEMBOLSO IN PR_SOLICITUDES.MONTO%TYPE
 ,P_MTO_CAR_IMPUTABLE IN OUT NUMBER
 ,P_MTO_CAR_NOIMPUTABLE IN OUT NUMBER
 ,P_ES_SOLICITUD IN VARCHAR2
 )
 IS
  V_PAR_CAR_TAE VARCHAR2(30);
  v_gastos       number;
  v_gastos_imp   number;

  v_mto_lim_prestamo number;
  v_mto_lim_cargo    number;
  v_redondeo         number := 0;
BEGIN
   v_gastos := 0;

   v_par_car_tae := fug_obt_pardinamico('GRU_CAR_TAE');
   v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', 6, null, p_cod_moneda);--agregué modalidad y moneda

   if p_nro_solicitud is not null then
       --- Obtiene los gastos que constituyen interes.
       IF P_ES_SOLICITUD ='S' THEN
         select sum(
                 decode(cod_tra_hijo, null, nvl(car.mto_mon_prestamo,0),
                        round(nvl(car.mto_mon_prestamo,0) * 100/(100+FUG_OBT_VAL_TASA(s.cod_modulo,s.cod_modalidad,s.cod_oficina,null,s.cod_oficina
                         ,0,'N',null,d.cod_tra_hijo,s.fec_inicio)), v_redondeo))
                         )
            into v_gastos_imp
            from GE_TRANSACCIONES_DET d, ge_transacciones t, pr_sol_cargos car, pr_solicitudes s
           where t.cod_transaccion = car.cod_transaccion
             and t.cod_modulo = s.cod_modulo
             and t.cod_modalidad = s.cod_modalidad
             and d.cod_transaccion(+) = t.cod_transaccion
             and d.cod_modulo(+) = t.cod_modulo
             and d.cod_modalidad(+) = t.cod_modalidad
             --- and d.cod_tra_hijo(+) = 517 Se asume que si tiene transaccion hijo este es impuesto.

             and car.nro_solicitud = s.nro_solicitud
             and s.nro_solicitud = p_nro_solicitud
             and exists --- Solo gastos imputables como interes.
                (select 1 from ge_gru_transacciones_det gt
                  where gt.cod_transaccion = car.cod_transaccion
                    and gt.cod_modulo = s.cod_modulo
                    and gt.cod_modalidad = s.cod_modalidad
                    and gt.cod_gru_transaccion = v_par_car_tae);

          --- Obtiene los gastos que no constituyen interes.
            --- Obtiene el total de gastos y a este le resta los que si constituyen interes.
            select sum(nvl(car.mto_mon_prestamo,0)) - nvl(v_gastos_imp,0)
              into v_gastos
              from pr_sol_cargos car
             where car.nro_solicitud = p_nro_solicitud;


          ELSE
              --para simulaciones

                 select sum(
                   decode(cod_tra_hijo, null, nvl(car.monto,0),
                          round(nvl(car.monto,0) * 100/(100+FUG_OBT_VAL_TASA(s.cod_modulo,s.cod_modalidad,31,null,31
                           ,0,'N',null,d.cod_tra_hijo,s.fec_inicio)), v_redondeo))
                           )
                    into v_gastos_imp
              from GE_TRANSACCIONES_DET d, ge_transacciones t, pr_sim_cargos car, pr_simulaciones s
             where t.cod_transaccion = car.cod_transaccion
               and t.cod_modulo = s.cod_modulo
               and t.cod_modalidad = s.cod_modalidad
               and d.cod_transaccion(+) = t.cod_transaccion
               and d.cod_modulo(+) = t.cod_modulo
               and d.cod_modalidad(+) = t.cod_modalidad
               --- and d.cod_tra_hijo(+) = 517 Se asume que si tiene transaccion hijo este es impuesto.

               and car.nro_simulacion = s.nro_simulacion
               and s.nro_simulacion = p_nro_solicitud
               and exists --- Solo gastos imputables como interes.
                  (select 1 from ge_gru_transacciones_det gt
                    where gt.cod_transaccion = car.cod_transaccion
                      and gt.cod_modulo = s.cod_modulo
                      and gt.cod_modalidad = s.cod_modalidad
                      and gt.cod_gru_transaccion = v_par_car_tae);


           select sum(nvl(car.monto,0)) - nvl(v_gastos_imp,0)
           into v_gastos
              from pr_sim_cargos car
             where car.nro_simulacion = p_nro_solicitud;
          END IF;

   else
      v_gastos := 0;
      v_gastos_imp := 0;
      v_aux_val_tasa := 0;
      v_aux_mto_cargo :=0;
   end if;
   ---
   P_MTO_CAR_IMPUTABLE   := nvl(v_gastos_imp,0);
   P_MTO_CAR_NOIMPUTABLE := nvl(v_gastos,0);
   ---
   /* Debe hacer todas las comparaciones para verificar si esl gasto es imputable o no. */
   If P_MTO_CAR_IMPUTABLE > 0 then
      -- Se convierte a la moneda el monto limite para considerar como gastos no imputables...
      v_mto_lim_prestamo := pag_gen.fu_con_mon_a_moneda(pag_gen.fu_obt_mon_local, p_cod_moneda, fug_obt_pardinamico('MTO_TAE', 6));

      If nvl(v_mto_lim_prestamo, 0) > 0 then
         -- Solo si el prestamo es menor o igual al limite puede que no sea imputable el cargo.
         If p_mto_desembolso <= v_mto_lim_prestamo then
            -- Si es menor o igual al limite (5.400.000) entonces verifica si el cargo no supera el 15%
            If p_mto_car_imputable > round(p_mto_desembolso*0.15, v_redondeo) Then
               -- Si el cargo es mayor al 15% se debe considerar como imputable solo el 15%
               p_mto_car_imputable := p_mto_car_imputable - round(p_mto_desembolso*0.15, v_redondeo);
            End If;
            -- Si sigue siendo mayor a cero.
            If p_mto_car_imputable > 0 Then
              -- Si el cargo es menor o igual al 15% debe verificar que no supere el
              -- Se convierte a la moneda el monto limite para considerar como gastos no imputables...
              v_mto_lim_cargo := pag_gen.fu_con_mon_a_moneda(pag_gen.fu_obt_mon_local, p_cod_moneda, fug_obt_pardinamico('IMP_MIN_GAS', 6));

              If P_MTO_CAR_IMPUTABLE > v_mto_lim_cargo then
                 p_mto_car_imputable := p_mto_car_imputable - v_mto_lim_cargo;
              Else
                 If v_gastos_imp = p_mto_car_imputable then
                    -- Quiere decir que no se vió afectado por el 15%.
                    p_mto_car_imputable := 0;
                 End if;
              End if;
            End if;
         End If;
      End if;
   End if;
END;
/* Obtener dias. */
FUNCTION LF_OBT_DIAS
 (P_NRO_SOLICITUD IN PR_CTA_PRESTAMOS.NRO_SOLICITUD%TYPE
 ,P_NRO_CUOTA IN PR_CUOTAS.NRO_CUOTA%TYPE
 ,P_ES_SOLICITUD IN VARCHAR2
 )
 RETURN NUMBER
 IS
v_dias  pr_sol_cuotas.dia_interes%type;
BEGIN
IF P_ES_SOLICITUD ='S' THEN
  select dia_interes
     into v_dias
     from pr_sol_cuotas
    where nro_solicitud = p_nro_solicitud
      and nro_cuota = p_nro_cuota;
ELSE
    select per_dias dia_interes
    into v_dias
     from pr_sim_cuotas
    where nro_simulacion = p_nro_solicitud
      and nro_cuota = p_nro_cuota;
END IF;
    return v_dias;
exception
   when no_data_found then
      raise_application_error(-20000,
      'Sol.Cuotas no registrada');
END;
/* Obtener datos del prestamo. */
PROCEDURE LP_OBT_DAT_PRESTAMO
 (P_NRO_SOLICITUD IN GE_CUENTAS.NRO_CUENTA%TYPE
 ,P_COD_MONEDA IN OUT PR_SOLICITUDES.COD_MONEDA%TYPE
 ,P_MTO_CAPITAL IN OUT PR_SOLICITUDES.MONTO%TYPE
 ,P_TIP_INTERES IN OUT PR_SOLICITUDES.TIP_INTERES%TYPE
 ,P_FEC_INICIO IN OUT DATE
 ,P_FEC_VENCIMIENTO IN OUT DATE
 ,P_VAL_TASA        IN OUT NUMBER
 ,P_TIP_AMORTIZACION IN OUT VARCHAR2
 ,P_CAN_CUOTAS IN OUT NUMBER
 ,P_MTO_DESEMBOLSO IN OUT PR_SOLICITUDES.MONTO%TYPE
 ,P_ES_SOLICITUD IN VARCHAR2
 )
 IS
BEGIN

if P_ES_SOLICITUD='S' THEN
   select a.cod_moneda, a.tot_prestamo, a.tip_interes, a.fec_inicio, a.fec_vencimiento, b.val_tasa,
          a.tip_amortizacion, can_cuotas, a.tot_desembolsar,a.cod_modulo,a.cod_modalidad,a.cod_sub_modalidad
     into p_cod_moneda, p_mto_capital, p_tip_interes, p_fec_inicio, p_fec_vencimiento, p_val_tasa,
          p_tip_amortizacion, p_can_cuotas, p_mto_desembolso,v_cod_modulo,v_cod_modalidad,v_cod_sub_modalidad
     from pr_sol_tasas b, pr_solicitudes a, (Select count(*) can_cuotas
                                               from pr_sol_cuotas
                                              where nro_cuota > 0
                                                and nro_solicitud = p_nro_solicitud)
    where a.nro_solicitud = p_nro_solicitud
      and a.nro_solicitud = b.nro_solicitud;
   --Para simulaciones
ELSE
  select a.cod_moneda, a.tot_prestamo, a.tip_interes, a.fec_inicio, ADD_MONTHS(a.fec_inicio ,a.can_cuotas) as fec_vencimiento, a.val_tasa,
          a.tip_amortizacion, a.can_cuotas, a.tot_prestamo,a.cod_modulo,a.cod_modalidad,a.cod_sub_modalidad

    into p_cod_moneda, p_mto_capital, p_tip_interes, p_fec_inicio, p_fec_vencimiento, p_val_tasa,
          p_tip_amortizacion, p_can_cuotas, p_mto_desembolso,v_cod_modulo,v_cod_modalidad,v_cod_sub_modalidad

     from pr_simulaciones a, (Select count(*) can_cuotas
                                               from pr_sim_cuotas
                                              where nro_cuota > 0
                                                and nro_simulacion= p_nro_solicitud)

    where a.nro_simulacion = p_nro_solicitud;

END IF;
 exception
   when no_data_found then
      raise_application_error(-20000,
      'Solicitud '||p_nro_solicitud||' no registrado');
END;

--******* Proceso Principal *************************************+
BEGIN
   v_contador := 0;
   v_acum_tan := 0;
   v_acum_tae := 0;
   v_es_solicitud:='N';
   --Verificamos si es una solicitud
      begin
         select 'S'
          into v_es_solicitud
           from pr_solicitudes a
             where a.nro_solicitud= P_NRO_SOLICITUD;
      exception
        when no_data_found then
            v_es_solicitud:='N';
        when others then
            v_es_solicitud:='N';
      end;
   --- Obtener datos del prestamos
   v_tip_interes:='V'; --SOLO PARA HB
   lp_obt_dat_prestamo(p_nro_solicitud,  v_cod_moneda, v_mto_capital,
                       v_tip_interes, v_fec_inicio, v_fec_vencimiento, v_val_tas_pactada,
                       v_tip_amortizacion, v_can_cuotas, v_mto_desembolso,v_es_solicitud);
   v_tip_interes:='V'; --SOLO PARA HB
   lp_obt_gas_prestamos(p_nro_solicitud, v_cod_moneda, v_mto_desembolso, v_gastos_imp, v_gastos_noi,v_es_solicitud);
   v_sal_capital := v_mto_capital;
   v_fec_vto_cuota_ant := v_fec_inicio;
   v_redondeo := 0;
   if v_cod_moneda = pag_gen.fu_obt_mon_local then
      v_dif_permitida := 1000;
   else
      v_dif_permitida := 10;
      v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', 6, null, v_cod_moneda);
   end if;
   for cuo in c_cuotas loop
      /*  El calculo de los prestamos se realizara en dos grupos:
          Descuentos de cheques y documentos
          Otros tipos de prestamos
          Para los prestamos que no son de tipo Desc. de documento, se
          toma siempre como valor inicial el saldo de capital y como
          valor final el mismo saldo mas el interes por cada cuota,
          siendo la cantidad de dias tambien la que corresponde a dicha
          cuota
          La diferencia fundamental radica en los dias que se consideran
          para el calculo: para cada cuota de los prestamos de tipo
          Descuento, siempre se toman los dias desde el inicio del
          prestamo, para el resto de los casos, se toma unicamente
          los dias que corresponden a cada cuota */
      IF cuo.nro_cuota > 0 THEN
         v_numero := cuo.val_cuota;

         If v_tip_interes != 'A' then
           IF cuo.nro_cuota = 1 THEN
              -- Verifica si es realmente price o no.
              If v_tip_amortizacion = 'P' then
                -- Si es price, si los plazos son fijos debe calcular diferente.
                  If p_nro_solicitud is not null then


                    IF v_es_solicitud='S' THEN
                        Select avg(dia_interes), min(s.per_vto_capital),
                            avg(nvl(mto_capital,0)+nvl(val_interes,0)+nvl(val_int_adelantado,0)) -
                            min(nvl(mto_capital,0)+nvl(val_interes,0)+nvl(val_int_adelantado,0)),
                            min(nvl(mto_capital,0)+nvl(val_interes,0)+nvl(val_int_adelantado,0))
                       into v_avg_dia, v_per_capital, v_dif_cuotas, v_min_cuota
                       from pr_sol_cuotas c, pr_solicitudes s
                      where s.nro_solicitud = p_nro_solicitud
                        and c.nro_solicitud = s.nro_solicitud
                        and c.nro_cuota > 0;

                     ELSE
                        Select avg(per_dias), min(s.per_vto_capital),
                            avg(nvl(mto_capital,0)+nvl(mto_interes,0)) -
                            min(nvl(mto_capital,0)+nvl(mto_interes,0)),
                            min(nvl(mto_capital,0)+nvl(mto_interes,0))
                       into v_avg_dia, v_per_capital, v_dif_cuotas, v_min_cuota
                       from pr_sim_cuotas c, pr_simulaciones s
                      where s.nro_simulacion = p_nro_solicitud
                        and c.nro_simulacion = s.nro_simulacion
                        and c.nro_cuota > 0;


                     END IF;

                  End If;
                  If abs(v_avg_dia - v_per_capital) > 1 or abs(v_dif_cuotas) > v_dif_permitida or v_can_cuotas = 1 then
                     -- Si la diferencia en dias entre el periodo de interes y el de capital
                    -- se considera que no es periodico por lo tanto no es price.
                    If abs(cuo.dia_interes - v_per_capital) > 2 or abs(v_dif_cuotas) > v_dif_permitida or v_can_cuotas = 1 then
                          v_tip_amortizacion := 'F';
                     End if;
                   End if;
              End If;
           end if;
         Else
           -- Si es adelantado...
           v_tot_dias    := nvl(v_tot_dias,0) + cuo.dia_interes;
           v_dias_cuota  := cuo.fec_vto_exacto-v_fec_vto_cuota_ant;
           If fug_obt_tip_implementacion = 3 then -- FA.
             v_mto_gasto   := round(v_gastos_imp/v_can_cuotas, v_redondeo);
           Else
              --MDPACTAE-27
              If v_aux_aju_tae = 'N' then --Si no necesita ajustar monto del cargo realiza calculo normal.
                 v_mto_gasto := round(v_gastos_imp*(nvl(cuo.mto_capital,0)/v_mto_capital ), v_redondeo);
              Else
                  --APLICA FORMULA DE CONTROL obteniedo el TIR y VNA primero - No debe prorratear el gasto
                  Begin
                     Select +power(v_aux1,(1/(365/cuo.dia_interes)))
                       Into V_AUX2
                       from dual;
                  Exception
                     When others then
                        v_aux2 := null;
                  End;
                     v_aux_tir     := +(-v_aux2+1)*100; --TIR
                     v_aux_vna     := Round(nvl(cuo.mto_capital,0)/((v_aux_tir/100)+1),v_redondeo); --VNA
                     v_aux_mto_tae_1 := Round(((nvl(cuo.mto_capital,0)-nvl(cuo.mto_int_documentado,0))-v_aux_vna)*100/(100+v_val_tas_iva),v_redondeo);--Mto sin IVA.
                     If v_aux_aju_tae = 'M' then
                        --Si el monto del cargo es menor al calculo máximo del TAE aplica formula por distribución.
                        v_mto_gasto := Round(v_aux_mto_tae_1 * v_gastos_imp /(v_aux_mto_tae_2*100/(100+v_val_tas_iva)),v_redondeo);
                     Else
                        --Si el monto del cargo es mayor al calculo máximo del TAE aplica formula directa del monto calculado.
                        v_mto_gasto := v_aux_mto_tae_1 ;
                     End IF;
            End IF;

           End if;
           v_val_inicial := cuo.mto_capital - cuo.mto_int_documentado - v_mto_gasto;
           v_numero      := cuo.val_cuota - cuo.mto_int_documentado;
           v_dias        := cuo.dias;
         End If;
         --
         if v_tip_interes != 'A' then
            v_dias        := cuo.dia_interes;
            If v_tip_amortizacion = 'P' then
               -- Si sigue siendo price.
               -- Adiciona los gastos a la cuota 1
               IF cuo.nro_cuota = 1 THEN
                   IF fug_obt_tip_implementacion = 2 then
                     v_val_inicial := v_sal_capital - (v_gastos_imp*2);
                  else
                     v_val_inicial := v_sal_capital - v_gastos_imp;
                  end if;
                  v_dias        := v_per_capital;
               End If;
               -- Debe cargar las cuotas en el auxiliar.
               v_auxiliar := v_auxiliar||trim(to_char(cuo.mto_capital + cuo.mto_interes + cuo.mto_int_documentado))||'#';
            Else
               -- Sino es price.
               IF cuo.nro_cuota = 1 THEN
                  -- Adiciona los gastos a la cuota 1
                  v_val_inicial := v_sal_capital - v_gastos_imp;
               Else
                  v_val_inicial := v_sal_capital;
               END IF;
               v_auxiliar    := v_sal_capital + cuo.mto_interes + cuo.mto_int_documentado;
            End if;
            v_numero      := v_auxiliar;
         end if;
         --- Hace los calculos de TIR, TAN y TAE
         DECLARE
            v_tir       number;
            v_tan       number;
            v_tae       number;
            v_dias1     number(4);
            v_inicial   number(18,2);
            v_numero1   varchar2(3000);
         BEGIN
            v_dias1    := v_dias;
            v_numero1  := v_numero;
            v_inicial  := v_val_inicial;
            if v_inicial > 0 then
               If v_tip_amortizacion = 'P' and v_can_cuotas = cuo.nro_cuota then
                  -- Si es tipo price en la última cuota calcula el tir.
                  v_tir := pas_bcp.fu_obt_tir(v_inicial,
                                              v_can_cuotas,
                                              v_numero1);
               Elsif v_tip_amortizacion != 'P' then
                  v_tir := pas_bcp.fu_obt_tir(v_inicial,
                                              1 ,
                                              v_numero1);
               End if;
               -- para pruebas se comenta y se asigna la tasa
               v_tan := pas_bcp.fu_obt_tas_anual(v_tir, v_dias );
               --
               /*
               -- Comentado JIRA 1173 - rabf - 11/06/2012
               -- No aplica para la normativa. Se vuelve al cálculo original.
               v_tan := v_val_tas_pactada;
               */
               v_tae := pas_bcp.fu_obt_tae(v_tan, v_dias);
               -- Corrección para que tome el promedio de días para realizar el calculo.DYDMR-6355
               IF v_tip_amortizacion = 'P' and v_can_cuotas = cuo.nro_cuota then
                  v_tan := pas_bcp.fu_obt_tas_anual(v_tir, v_avg_dia);
                  v_tae := pas_bcp.fu_obt_tae(v_tan, v_avg_dia);
               END IF;
            else
               v_tir := 0;
               v_tan := 0;
               v_tae := 0;
            end if;
            v_acum_tan := nvl(v_acum_tan,0) + nvl(v_tan,0);
            v_acum_tae := nvl(v_acum_tae,0) + nvl(v_tae,0);
         END;
         v_sal_capital := v_sal_capital - cuo.mto_capital;
         v_fec_vto_cuota_ant := cuo.fec_vto_exacto;
         v_contador    := v_contador + 1;
         If v_tip_amortizacion = 'P' then
            -- Si es tipo price cera el acumulado porque solo sirve el ultimo calculado y ya no debe calcular el promedio del tan.
            If v_can_cuotas <> cuo.nro_cuota then
               v_acum_tan := 0;
            Else
               v_contador := 1;
            End if;
         End If;
      end if;
   end loop;
   If v_tip_interes = 'A' then
      v_dias := v_tot_dias/v_contador;
   End if;
   --- Calcular tasa promedio
   p_val_tan := round(v_acum_tan / v_contador,2);
   if fug_obt_tip_implementacion <> 3 and p_val_tan < v_val_tas_pactada then
      p_val_tan := v_val_tas_pactada;
   end if;
   If v_tip_interes = 'A' then
      -- Si es un descuento obtiene el tae con el promedio de días.
      p_val_tae := round(pas_bcp.fu_obt_tae(p_val_tan, v_dias),2);
   Else
      If v_tip_amortizacion = 'P' then
         -- Si los días son fijos halla el tae de acuerdo a esto no por promedio.
         If fug_obt_tip_implementacion <> 3 and v_gastos_imp = 0 then
            p_val_tan := v_val_tas_pactada;
         end if;
         -- Corrección para que tome el promedio de días para realizar el calculo.DYDMR-6355
         p_val_tae := pas_bcp.fu_obt_tae(p_val_tan, v_avg_dia);
      Else
         -- Si los días no son fijos o es flexible debe halla por promedio.
         p_val_tae := round(v_acum_tae / v_contador,2);
      End if;
   End if;
END;
/

