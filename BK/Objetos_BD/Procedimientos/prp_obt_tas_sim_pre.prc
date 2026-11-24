create or replace procedure it.prp_obt_tas_sim_pre
 (P_NRO_SIMULACION IN PR_SIMULACIONES.NRO_SIMULACION%TYPE
 ,P_VAL_TAE IN OUT NUMBER
 ,P_VAL_TAN IN OUT NUMBER
 )
 IS

/* Obtener gastos del prestamo. */
PROCEDURE LF_OBT_GAS_SIMULACION
 (P_NRO_SIMULACION IN PR_SIMULACIONES.NRO_SIMULACION%TYPE
 ,P_COD_MONEDA IN GE_CUENTAS.COD_MONEDA%TYPE
 ,P_MTO_DESEMBOLSO IN PR_SIMULACIONES.MONTO%TYPE 
 ,P_MTO_CAR_IMPUTABLE IN OUT NUMBER
 ,P_MTO_CAR_NOIMPUTABLE IN OUT NUMBER
 );
 RETURN NUMBER;
/* Obtener datos del prestamo. */
PROCEDURE LP_OBT_DAT_SIMULACION
 (P_NRO_SIMULACION IN GE_CUENTAS.NRO_CUENTA%TYPE
 ,P_COD_MONEDA IN OUT PR_SIMULACIONES.COD_MONEDA%TYPE
 ,P_MTO_CAPITAL IN OUT PR_SIMULACIONES.MONTO%TYPE
 ,P_TIP_INTERES IN OUT PR_SIMULACIONES.TIP_INTERES%TYPE
 ,P_FEC_INICIO IN OUT DATE
 ,P_FEC_VENCIMIENTO IN OUT DATE 
 ,P_COD_MODALIDAD IN OUT PR_SOLICITUDES.COD_MODALIDAD%TYPE
 ,P_VAL_TASA IN OUT NUMBER
 ,P_TIP_AMORTIZACION IN OUT VARCHAR2
 ,P_CAN_CUOTAS IN OUT NUMBER
 ,P_MTO_DESEMBOLSO IN OUT PR_SIMULACIONES.MONTO%TYPE 
 );
   v_acum_tan number;
   v_acum_tae number;
   v_contador number;
   v_gastos_imp   number;
   v_gastos_noi   number;
   v_avg_dia     number;
   v_tot_refuerzo number;
 	 v_per_capital number;
   v_dias     number;
   v_dias_cuota number;
   v_tot_dias   number;
   v_mto_gasto  number(18,2);
   v_cod_moneda      ge_cuentas.cod_moneda%type;
   v_mto_capital     pr_cta_prestamos.mto_capital%type;
   v_mto_desembolso  pr_cta_prestamos.monto%type;
   v_sal_capital     pr_cta_prestamos.mto_capital%type;
   v_fec_inicio      pr_cta_prestamos.fec_inicio%type;
   v_fec_vencimiento   Pr_Sim_Cuotas.fec_vencimiento%type;
   v_fec_vto_cuota_ant pr_sim_cuotas.fec_vencimiento%type;
   v_cod_modalidad   ge_modalidades.cod_modalidad%type;
   v_plazo           number;
   v_can_cuotas      number;
   v_numero          varchar2(3000); -- pr_cuotas.mto_capital%type;
   v_auxiliar        varchar2(3000);
   v_val_inicial     pr_cta_prestamos.mto_capital%type;
   v_tip_interes     PR_SIMULACIONES.tip_interes%type;
   v_val_tas_pactada number;
   v_tip_amortizacion varchar2(1);
   v_tipo             varchar2(1);
   v_sale varchar2(1) := 'N';
   v_redondeo         number(5);
   
   --- Cursor de cuotas
   cursor c_cuotas is
   select sim.nro_cuota,
          nvl(sim.mto_capital,0)+nvl(sim.mto_interes,0) val_cuota,
          nvl(sim.mto_capital,0) mto_capital, decode(tip_interes, 'A', 0, sim.mto_interes) mto_interes,
          decode(tip_interes, 'A', sim.mto_interes, 0) mto_int_documentado,
          decode(tip_interes, 'A', per_dias, trunc(sim.fec_vencimiento - v_fec_inicio)) dias,
          per_dias dia_interes,
          fec_vencimiento
     from pr_simulaciones s, pr_sim_cuotas sim
    where s.nro_simulacion = sim.nro_simulacion
      and sim.nro_simulacion = p_nro_simulacion
      and sim.nro_cuota > 0
    order by 1;

/* Obtener gastos del prestamo. */
PROCEDURE LF_OBT_GAS_SIMULACION
 (P_NRO_SIMULACION IN PR_SIMULACIONES.NRO_SIMULACION%TYPE
 ,P_COD_MONEDA IN GE_CUENTAS.COD_MONEDA%TYPE
 ,P_MTO_DESEMBOLSO IN PR_SIMULACIONES.MONTO%TYPE
 ,P_MTO_CAR_IMPUTABLE IN OUT NUMBER
 ,P_MTO_CAR_NOIMPUTABLE IN OUT NUMBER
 )
 IS

  V_FEC_ACTUAL DATE;
  V_PAR_CAR_TAE VARCHAR2(30);
  V_PAR_MIN_GAS VARCHAR2(30);
  v_gastos       number;
  v_gastos_imp   number;
  
  v_mto_lim_prestamo number;
  v_mto_lim_cargo    number;
  v_mto_desembolso   number;
  v_ofi_origen       number;
  v_redondeo_ml number(1);
BEGIN
   Begin
     -- Obtiene la oficina de Casa Matriz.
     Select cod_ofi_matriz 
       into v_ofi_origen
       from ge_par_generales;
   end;
     
   v_gastos := 0;
   v_fec_actual := pag_cal.fu_obt_fec_actual(4);
   v_par_car_tae := fug_obt_pardinamico('GRU_CAR_TAE');
   v_redondeo_ml := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', 6, v_cod_modalidad, pag_gen.fu_obt_mon_local);
   if P_NRO_SIMULACION is not null then
      --- Obtiene los gastos que constituyen interes.
      select sum(
             decode(cod_tra_hijo, null, nvl(car.mto_equivalente,0),
                    round(nvl(car.mto_equivalente,0) * 100/(100+FUG_OBT_VAL_TASA(s.cod_modulo,s.cod_modalidad,v_ofi_origen,null,s.cod_moneda
                     ,0,'N',null,d.cod_tra_hijo,s.fec_inicio)),v_redondeo_ml))
                     )
        into v_gastos_imp
        from GE_TRANSACCIONES_DET d, ge_transacciones t, pr_sim_cargos car, PR_SIMULACIONES s
       where t.cod_transaccion = car.cod_transaccion
         and t.cod_modulo = s.cod_modulo
         and t.cod_modalidad = s.cod_modalidad

         and d.cod_transaccion(+) = t.cod_transaccion
         and d.cod_modulo(+) = t.cod_modulo
         and d.cod_modalidad(+) = t.cod_modalidad
         -- and d.cod_tra_hijo(+) = 517, Se asume que si el cargo tiene hijo es impuesto.
         and car.NRO_SIMULACION = s.NRO_SIMULACION
         and s.NRO_SIMULACION = P_NRO_SIMULACION
         and exists --- Solo gastos imputables como interes.
            (select 1 from ge_gru_transacciones_det gt
              where gt.cod_transaccion = car.cod_transaccion
                and gt.cod_gru_transaccion = v_par_car_tae);
                
      --- Obtiene los gastos que no constituyen interes.      
      --- Obtiene el total de gastos y a este le resta los que si constituyen interes.
      select sum(nvl(car.mto_equivalente,0)) - nvl(v_gastos_imp,0)
        into v_gastos
        from pr_sim_cargos car
       where car.NRO_SIMULACION = P_NRO_SIMULACION;
                
   else
      v_gastos := 0;
      v_gastos_imp := 0;
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
                    -- Quiere decir que no se vio afectado por el 15%.
                    p_mto_car_imputable := 0;
                 End if;
              End if;
            End if;
         End If;
      End if;
   End if;
END;

/* Obtener datos del prestamo. */
PROCEDURE LP_OBT_DAT_SIMULACION
 (P_NRO_SIMULACION IN GE_CUENTAS.NRO_CUENTA%TYPE
 ,P_COD_MONEDA IN OUT PR_SIMULACIONES.COD_MONEDA%TYPE
 ,P_MTO_CAPITAL IN OUT PR_SIMULACIONES.MONTO%TYPE
 ,P_TIP_INTERES IN OUT PR_SIMULACIONES.TIP_INTERES%TYPE
 ,P_FEC_INICIO IN OUT DATE
 ,P_FEC_VENCIMIENTO IN OUT DATE
 ,P_COD_MODALIDAD IN OUT PR_SOLICITUDES.COD_MODALIDAD%TYPE
 ,P_VAL_TASA IN OUT NUMBER
 ,P_TIP_AMORTIZACION IN OUT VARCHAR2
 ,P_CAN_CUOTAS IN OUT NUMBER
 ,P_MTO_DESEMBOLSO IN OUT PR_SIMULACIONES.MONTO%TYPE 
 )
 IS
BEGIN
   select p.cod_moneda, p.tot_prestamo, tip_interes, p.fec_inicio,ct.fec_vencimiento,
          cod_modalidad,p.val_tasa,p.tip_amortizacion,can_cuotas,p.monto 
     into p_cod_moneda, p_mto_capital, p_tip_interes, p_fec_inicio,p_fec_vencimiento,
          p_cod_modalidad,p_val_tasa,p_tip_amortizacion, p_can_cuotas,p_mto_desembolso
     from pr_simulaciones p, pr_sim_cuotas ct
    where p.nro_simulacion = p_nro_simulacion
      and p.nro_simulacion = ct.nro_simulacion
      and ct.fec_vencimiento = (select max(ct1.fec_vencimiento)
                                  from pr_sim_cuotas ct1
                                 where ct1.nro_simulacion = p.nro_simulacion)
    group by p.cod_moneda, p.tot_prestamo, tip_interes, p.fec_inicio,ct.fec_vencimiento,cod_modalidad,val_tasa,p.tip_amortizacion,can_cuotas,p.monto ;
exception
   when no_data_found then
      raise_application_error(-20000,
      'Simulacion '||p_nro_simulacion||' no registrado');
END;
BEGIN
   v_contador := 0;
   v_acum_tan := 0;
   v_acum_tae := 0;
   --- Obtener datos del prestamos
   LP_OBT_DAT_SIMULACION(P_NRO_SIMULACION, v_cod_moneda, v_mto_capital,
                       v_tip_interes, v_fec_inicio, v_fec_vencimiento,v_cod_modalidad, v_val_tas_pactada,
                       v_tip_amortizacion, v_can_cuotas, v_mto_desembolso);

   v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', 6, v_cod_modalidad, v_cod_moneda);
   
   LF_OBT_GAS_SIMULACION(P_NRO_SIMULACION,v_cod_moneda, v_mto_desembolso, v_gastos_imp, v_gastos_noi);
   v_sal_capital := v_mto_capital;
   v_plazo       := v_fec_vencimiento - v_fec_inicio;
   v_fec_vto_cuota_ant := v_fec_inicio;
   v_sale := 'N';

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
                If P_NRO_SIMULACION is not null then
                   Select avg(sim.per_dias), min(s.per_vto_capital),
                          sum(mto_refuerzo)
                     into v_avg_dia, v_per_capital, v_tot_refuerzo
                     from pr_simulaciones s, pr_sim_cuotas sim
                    where s.nro_simulacion = sim.nro_simulacion
                      and sim.NRO_SIMULACION = P_NRO_SIMULACION
                      and sim.nro_cuota > 0;
                End If;
                If abs(v_avg_dia - v_per_capital) > 1 or  v_tot_refuerzo > 0 or v_can_cuotas = 1 then
      						-- Si la diferencia en dias entre el periodo de interes y el de capital 
      						-- se considera que no es periodico por lo tanto no es price.
      						If abs(cuo.dia_interes - v_per_capital) > 2 or v_tot_refuerzo > 0 or v_can_cuotas = 1 then
        						  v_tip_amortizacion := 'F';
      						End if;
      					End if;
              End If;
           end if;
         Else
           -- Si es adelantado...
           v_tot_dias    := nvl(v_tot_dias,0) + cuo.dia_interes;
           v_dias_cuota  := cuo.fec_vencimiento-v_fec_vto_cuota_ant;
           If fug_obt_tip_implementacion = 3 then -- FA.
             v_mto_gasto   := round(v_gastos_imp/v_can_cuotas,v_redondeo);
           Else
             v_mto_gasto   := round(v_gastos_imp*((nvl(cuo.mto_capital,0)+nvl(cuo.mto_int_documentado,0))/v_mto_capital ),v_redondeo);
           End if;
           v_val_inicial := cuo.mto_capital - v_mto_gasto;
           v_numero      := cuo.val_cuota;
           v_dias        := cuo.dias;
         End If;
         -- 
         if v_tip_interes != 'A' then
            v_dias        := cuo.dia_interes;
            If v_tip_amortizacion = 'P' then
               -- Si sigue siendo price.
               -- Adiciona los gastos a la cuota 1
               IF cuo.nro_cuota = 1 THEN
                  v_val_inicial := v_sal_capital - v_gastos_imp;
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
                  -- En la ultima cuota calcula el tir.
                  v_tir := pas_bcp.fu_obt_tir(v_inicial,
                                              v_can_cuotas,
                                              v_numero1);
               Elsif v_tip_amortizacion != 'P' then
                  v_tir := pas_bcp.fu_obt_tir(v_inicial,
                                              1 ,
                                              v_numero1);
               End if;
               v_tan := pas_bcp.fu_obt_tas_anual(v_tir, v_dias );
               v_tae := pas_bcp.fu_obt_tae(v_tan, v_dias);
            else
               v_tir := 0;
               v_tan := 0;
               v_tae := 0;
            end if;
            v_acum_tan := nvl(v_acum_tan,0) + nvl(v_tan,0);
            v_acum_tae := nvl(v_acum_tae,0) + nvl(v_tae,0);
         END;
         v_sal_capital := v_sal_capital - cuo.mto_capital;
         v_fec_vto_cuota_ant := cuo.fec_vencimiento;
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
   --- Calcular tasa promedio
   p_val_tan := round(v_acum_tan / v_contador,2);
   if p_val_tan < v_val_tas_pactada then
      p_val_tan := v_val_tas_pactada;
   end if;
   If v_tip_interes = 'A' then
      -- Si es un descuento obtiene el tae con el promedio de dias.
      p_val_tae := round(pas_bcp.fu_obt_tae(p_val_tan, (v_tot_dias/v_contador)),2);
   Else
      If v_tip_amortizacion = 'P' then
         -- Si los dias son fijos halla el tae de acuerdo a esto no por promedio.
         if v_gastos_imp = 0 then
            p_val_tan := v_val_tas_pactada;
         end if;            
         p_val_tae := pas_bcp.fu_obt_tae(p_val_tan, v_dias);
      Else
         -- Si los dias no son fijos o es flexible debe halla por promedio.
         p_val_tae := round(v_acum_tae / v_contador,2);
      End if;
   End if;
END;
/

