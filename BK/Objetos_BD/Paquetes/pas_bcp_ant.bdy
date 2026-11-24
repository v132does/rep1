CREATE OR REPLACE PACKAGE BODY IT.PAS_BCP_ANT IS
  /* Recuperar TAN - Res. 012022 */
  FUNCTION FU_OBT_VAL_TIR(p_inicial   IN NUMBER,
                          p_can_items IN NUMBER,
                          p_numeros   IN VARCHAR2,
                          p_plazos    IN VARCHAR2) RETURN NUMBER IS
    v_valor     NUMBER;
    v_tir       NUMBER;
    v_tir_ant   NUMBER;
    v_resultado NUMBER;
    v_salir     VARCHAR2(1);
    pos         NUMBER(5);
    pos_hasta   NUMBER(5);
    TYPE t_vector IS TABLE OF NUMBER(24, 12) INDEX BY BINARY_INTEGER;
    mi_vector     t_vector;
    mi_plz_vector t_vector;
  BEGIN
    -----------------------------------------------
    -- Cargar el vector con los valores recibidos
    -----------------------------------------------
    pos := 1;
    FOR i IN 1 .. p_can_items LOOP
      pos_hasta := instr(p_numeros, '#', pos, 1);
      IF pos_hasta > 0 THEN
        FOR x IN 1 .. p_can_items LOOP
          pos_hasta := instr(p_numeros, '#', pos, 1);
          mi_vector(x) := substr(p_numeros, pos, pos_hasta - pos);
          pos := instr(p_numeros, '#', pos, 1) + 1;
        END LOOP;
        EXIT; -- Sale del ciclo si es que ya cargo todo.
      ELSE
        mi_vector(i) := p_numeros;
      END IF;
      pos := pos + 13;
    END LOOP;
    --
    pos := 1;
    FOR i IN 1 .. p_can_items LOOP
      pos_hasta := instr(p_plazos, '#', pos, 1);
      IF pos_hasta > 0 THEN
        FOR x IN 1 .. p_can_items LOOP
          pos_hasta := instr(p_plazos, '#', pos, 1);
          mi_plz_vector(x) := substr(p_plazos, pos, pos_hasta - pos);
          pos := instr(p_plazos, '#', pos, 1) + 1;
        END LOOP;
        EXIT; -- Sale del ciclo si es que ya cargo todo.
      ELSE
        mi_plz_vector(i) := p_plazos;
      END IF;
      pos := pos + 13;
    END LOOP;
    ----------------------------------
    -- Iniciar el proceso de calculo
    ----------------------------------
    -- Primera fase - Presicion 2 decimales
    v_salir := 'N';
    v_tir   := 0;
    WHILE v_salir = 'N' LOOP
      v_tir_ant   := v_tir;
      v_tir       := v_tir + 0.01;
      v_resultado := 0;
      FOR i IN 1 .. p_can_items LOOP
        v_resultado := v_resultado +
                       (mi_vector(i) /
                       (power((1 + v_tir), mi_plz_vector(i))));
      END LOOP;
      IF v_resultado <= p_inicial THEN
        v_valor := v_tir_ant;
        v_salir := 'S';
      END IF;
    END LOOP;
    -- Segunda fase. Presicion 3 decimales
    v_salir := 'N';
    v_tir   := v_valor;
    WHILE v_salir = 'N' LOOP
      v_tir_ant   := v_tir;
      v_tir       := v_tir + 0.001;
      v_resultado := 0;
      FOR i IN 1 .. p_can_items LOOP
        v_resultado := v_resultado +
                       (mi_vector(i) /
                       (power((1 + v_tir), mi_plz_vector(i))));
      END LOOP;
      IF v_resultado <= p_inicial THEN
        v_valor := v_tir_ant;
        v_salir := 'S';
      END IF;
    END LOOP;
    -- Tercera fase. Presicion 4 decimales
    v_salir := 'N';
    v_tir   := v_valor;
    WHILE v_salir = 'N' LOOP
      v_tir_ant   := v_tir;
      v_tir       := v_tir + 0.0001;
      v_resultado := 0;
      FOR i IN 1 .. p_can_items LOOP
        v_resultado := v_resultado +
                       (mi_vector(i) /
                       (power((1 + v_tir), mi_plz_vector(i))));
      END LOOP;
      IF v_resultado <= p_inicial THEN
        v_valor := v_tir_ant;
        v_salir := 'S';
      END IF;
    END LOOP;
    -- Cuarta fase. Presicion 5 decimales
    v_salir := 'N';
    v_tir   := v_valor;
    WHILE v_salir = 'N' LOOP
      v_tir_ant   := v_tir;
      v_tir       := v_tir + 0.00001;
      v_resultado := 0;
      FOR i IN 1 .. p_can_items LOOP
        v_resultado := v_resultado +
                       (mi_vector(i) /
                       (power((1 + v_tir), mi_plz_vector(i))));
      END LOOP;
      IF v_resultado <= p_inicial THEN
        v_valor := v_tir_ant;
        v_salir := 'S';
      END IF;
    END LOOP;
    -- Quinta fase. Presicion 6 decimales
    v_salir := 'N';
    v_tir   := v_valor;
    WHILE v_salir = 'N' LOOP
      v_tir_ant   := v_tir;
      v_tir       := v_tir + 0.000001;
      v_resultado := 0;
      FOR i IN 1 .. p_can_items LOOP
        v_resultado := v_resultado +
                       (mi_vector(i) /
                       (power((1 + v_tir), mi_plz_vector(i))));
      END LOOP;
      IF v_resultado <= p_inicial THEN
        v_valor := v_tir_ant;
        v_salir := 'S';
      END IF;
    END LOOP;
    ----------------------------
    -- Calcular el valor final
    ----------------------------
    v_valor := v_valor * 100;
    RETURN round(v_valor, 4);
  END;

  FUNCTION FU_OBT_TIR_ADE(p_inicial   IN NUMBER,
                          p_can_items IN NUMBER,
                          p_numeros   IN VARCHAR2,
                          p_dias      IN NUMBER) RETURN NUMBER IS
    v_valor     NUMBER;
    v_tir       NUMBER;
    v_tir_ant   NUMBER;
    v_resultado NUMBER;
    v_salir     VARCHAR2(1);
    pos         NUMBER(5);
    pos_hasta   NUMBER(5);
    TYPE t_vector IS TABLE OF NUMBER(24, 12) INDEX BY BINARY_INTEGER;
    mi_vector t_vector;
  BEGIN
    -----------------------------------------------
    -- Cargar el vector con los valores recibidos
    -----------------------------------------------
    pos := 1;
    FOR i IN 1 .. p_can_items LOOP
      pos_hasta := instr(p_numeros, '#', pos, 1);
      IF pos_hasta > 0 THEN
        FOR x IN 1 .. p_can_items LOOP
          pos_hasta := instr(p_numeros, '#', pos, 1);
          mi_vector(x) := substr(p_numeros, pos, pos_hasta - pos);
          pos := instr(p_numeros, '#', pos, 1) + 1;
        END LOOP;
        EXIT; -- Sale del ciclo si es que ya cargo todo.
      ELSE
        mi_vector(i) := p_numeros;
      END IF;
      pos := pos + 13;
    END LOOP;
    ----------------------------------
    -- Iniciar el proceso de calculo
    ----------------------------------
    -- Primera fase - Presicion 2 decimales
    v_salir := 'N';
    v_tir   := 0;
    WHILE v_salir = 'N' LOOP
      v_tir_ant   := v_tir;
      v_tir       := v_tir + 0.01;
      v_resultado := 0;
      FOR i IN 1 .. p_can_items LOOP
        v_resultado := v_resultado +
                       (mi_vector(i) / (power((1 + v_tir), i)));
      END LOOP;
      IF v_resultado <= p_inicial THEN
        v_valor := v_tir_ant;
        v_salir := 'S';
      END IF;
    END LOOP;
    -- Segunda fase. Presicion 3 decimales
    v_salir := 'N';
    v_tir   := v_valor;
    WHILE v_salir = 'N' LOOP
      v_tir_ant   := v_tir;
      v_tir       := v_tir + 0.001;
      v_resultado := 0;
      FOR i IN 1 .. p_can_items LOOP
        v_resultado := v_resultado +
                       (mi_vector(i) / (power((1 + v_tir), i)));
      END LOOP;
      IF v_resultado <= p_inicial THEN
        v_valor := v_tir_ant;
        v_salir := 'S';
      END IF;
    END LOOP;
    -- Tercera fase. Presicion 4 decimales
    v_salir := 'N';
    v_tir   := v_valor;
    WHILE v_salir = 'N' LOOP
      v_tir_ant   := v_tir;
      v_tir       := v_tir + 0.0001;
      v_resultado := 0;
      FOR i IN 1 .. p_can_items LOOP
        v_resultado := v_resultado +
                       (mi_vector(i) / (power((1 + v_tir), i)));
      END LOOP;
      IF v_resultado <= p_inicial THEN
        v_valor := v_tir_ant;
        v_salir := 'S';
      END IF;
    END LOOP;
    -- Cuarta fase. Presicion 5 decimales
    v_salir := 'N';
    v_tir   := v_valor;
    WHILE v_salir = 'N' LOOP
      v_tir_ant   := v_tir;
      v_tir       := v_tir + 0.00001;
      v_resultado := 0;
      FOR i IN 1 .. p_can_items LOOP
        v_resultado := v_resultado +
                       (mi_vector(i) / (power((1 + v_tir), i)));
      END LOOP;
      IF v_resultado <= p_inicial THEN
        v_valor := v_tir_ant;
        v_salir := 'S';
      END IF;
    END LOOP;
    -- Quinta fase. Presicion 6 decimales
    v_salir := 'N';
    v_tir   := v_valor;
    WHILE v_salir = 'N' LOOP
      v_tir_ant   := v_tir;
      v_tir       := v_tir + 0.000001;
      v_resultado := 0;
      FOR i IN 1 .. p_can_items LOOP
        v_resultado := v_resultado +
                       (mi_vector(i) / (power((1 + v_tir), i)));
      END LOOP;
      IF v_resultado <= p_inicial THEN
        v_valor := v_tir_ant;
        v_salir := 'S';
      END IF;
    END LOOP;
    ----------------------------
    -- Calcular el valor final
    ----------------------------
    v_valor := v_valor * 365 / p_dias * 100;
    RETURN round(v_valor, 4);
  END;

  /* Recuperar TIR */
  FUNCTION FU_OBT_TIR(P_INICIAL   IN NUMBER,
                      P_CAN_ITEMS IN NUMBER,
                      P_NUMEROS   IN VARCHAR2) RETURN NUMBER IS
    v_valor     number;
    v_tir       number;
    v_tir_ant   number;
    v_resultado number;
    v_salir     varchar2(1);
    pos         number(5);
    pos_hasta   number(5);
    type t_vector is table of number(24, 12) index by binary_integer;
    mi_vector t_vector;
  BEGIN
    -----------------------------------------------
    -- Cargar el vector con los valores recibidos
    -----------------------------------------------
    pos := 1;
    for i in 1 .. p_can_items loop
      pos_hasta := instr(p_numeros, '#', pos, 1);
      If pos_hasta > 0 then
        for x in 1 .. p_can_items loop
          pos_hasta := instr(p_numeros, '#', pos, 1);
          mi_vector(x) := substr(p_numeros, pos, pos_hasta - pos);
          pos := instr(p_numeros, '#', pos, 1) + 1;
        end loop;
        exit; -- Sale del ciclo si es que ya cargo todo.
      Else
        mi_vector(i) := p_numeros;
      End If;
      pos := pos + 13;
    end loop;
    ----------------------------------
    -- Iniciar el proceso de calculo
    ----------------------------------
    -- Primera fase - Presicion 2 decimales
    v_salir := 'N';
    v_tir   := 0;
    while v_salir = 'N' loop
      v_tir_ant   := v_tir;
      v_tir       := v_tir + 0.01;
      v_resultado := 0;
      for i in 1 .. p_can_items loop
        v_resultado := v_resultado +
                       (mi_vector(i) / (power((1 + v_tir), i)));
      end loop;
      if v_resultado <= p_inicial then
        v_valor := v_tir_ant;
        v_salir := 'S';
      end if;
    end loop;
    -- Segunda fase. Presicion 3 decimales
    v_salir := 'N';
    v_tir   := v_valor;
    while v_salir = 'N' loop
      v_tir_ant   := v_tir;
      v_tir       := v_tir + 0.001;
      v_resultado := 0;
      for i in 1 .. p_can_items loop
        v_resultado := v_resultado +
                       (mi_vector(i) / (power((1 + v_tir), i)));
      end loop;
      if v_resultado <= p_inicial then
        v_valor := v_tir_ant;
        v_salir := 'S';
      end if;
    end loop;
    -- Tercera fase. Presicion 4 decimales
    v_salir := 'N';
    v_tir   := v_valor;
    while v_salir = 'N' loop
      v_tir_ant   := v_tir;
      v_tir       := v_tir + 0.0001;
      v_resultado := 0;
      for i in 1 .. p_can_items loop
        v_resultado := v_resultado +
                       (mi_vector(i) / (power((1 + v_tir), i)));
      end loop;
      if v_resultado <= p_inicial then
        v_valor := v_tir_ant;
        v_salir := 'S';
      end if;
    end loop;
    -- Cuarta fase. Presicion 5 decimales
    v_salir := 'N';
    v_tir   := v_valor;
    while v_salir = 'N' loop
      v_tir_ant   := v_tir;
      v_tir       := v_tir + 0.00001;
      v_resultado := 0;
      for i in 1 .. p_can_items loop
        v_resultado := v_resultado +
                       (mi_vector(i) / (power((1 + v_tir), i)));
      end loop;
      if v_resultado <= p_inicial then
        v_valor := v_tir_ant;
        v_salir := 'S';
      end if;
    end loop;
    -- Quinta fase. Presicion 6 decimales
    v_salir := 'N';
    v_tir   := v_valor;
    while v_salir = 'N' loop
      v_tir_ant   := v_tir;
      v_tir       := v_tir + 0.000001;
      v_resultado := 0;
      for i in 1 .. p_can_items loop
        v_resultado := v_resultado +
                       (mi_vector(i) / (power((1 + v_tir), i)));
      end loop;
      if v_resultado <= p_inicial then
        v_valor := v_tir_ant;
        v_salir := 'S';
      end if;
    end loop;
    ----------------------------
    -- Calcular el valor final
    ----------------------------
    v_valor := v_valor * 365 / 30 * 100;
    return round(v_valor, 4);
  END;

  /* Obtener tasa efectiva. */
  FUNCTION FU_OBT_TAE(p_tasa IN NUMBER, p_periodo_capit IN NUMBER)
    RETURN NUMBER IS
    --v_tae  NUMBER(21, 10);
    v_tae  NUMBER;
    v_tae1 NUMBER(21, 10);
    v_tae2 NUMBER(21, 10);
  BEGIN
    v_tae1 := 1 + (((p_tasa) * p_periodo_capit) / 36500);
    v_tae2 := 365 / p_periodo_capit;
    v_tae  := ((power(v_tae1, v_tae2) - 1) * 100);
    RETURN round(v_tae, 4);
  END;

  /* Obtener tasa Nominal. */
  FUNCTION FU_OBT_TAN(p_tasa IN NUMBER, p_periodo_capit IN NUMBER)
    RETURN NUMBER IS
    v_tae  NUMBER(21, 6);
    v_tae1 NUMBER(21, 6);
    v_tae2 NUMBER(21, 6);
  BEGIN
    v_tae1 := 1 + ((p_tasa * p_periodo_capit) / 36500);
    v_tae2 := 365 / p_periodo_capit;
    v_tae  := (power(v_tae1, v_tae2) - 1) * 100;
    RETURN round(v_tae, 4);
  END;

  /* Obtener tasa anual. */
  FUNCTION FU_OBT_TAS_ANUAL(P_TIR IN NUMBER, P_PERIODO_CAPIT IN NUMBER)
    RETURN NUMBER IS
    v_tan number;
  BEGIN
    v_tan := (p_tir * 365) / p_periodo_capit;
    return round(v_tan, 4);
  END;
  /* Obtener tasa efectiva y nominal de prestamo */
  PROCEDURE PR_OBT_TAS_PRESTAMO(p_nro_solicitud IN pr_cta_prestamos.nro_solicitud%TYPE,
                                p_nro_cuenta    IN pr_cta_prestamos.nro_cuenta%TYPE,
                                p_val_tae       IN OUT NUMBER,
                                p_val_tan       IN OUT NUMBER) IS
  
    v_cta_recalendarizada VARCHAR2(1);
    FUNCTION lf_plz_int_adelantado(p_nro_solicitud IN pr_cta_prestamos.nro_solicitud%TYPE,
                                   p_nro_cuenta    IN pr_cta_prestamos.nro_cuenta%TYPE)
      RETURN NUMBER;
  
    /* Obtener gastos del prestamo. */
    PROCEDURE lp_obt_gas_prestamos(p_nro_solicitud       IN pr_solicitudes.nro_solicitud%TYPE,
                                   p_nro_cuenta          IN pr_cta_prestamos.nro_cuenta%TYPE,
                                   p_cod_moneda          IN ge_cuentas.cod_moneda%TYPE,
                                   p_mto_desembolso      IN pr_solicitudes.monto%TYPE,
                                   p_mto_car_imputable   IN OUT NUMBER,
                                   p_mto_car_noimputable IN OUT NUMBER);
    /* Obtener dias. */
    FUNCTION lf_obt_dias(p_nro_solicitud IN pr_cta_prestamos.nro_solicitud%TYPE,
                         p_nro_cuota     IN pr_cuotas.nro_cuota%TYPE)
      RETURN NUMBER;
  
    /* Obtener datos del prestamo. */
    PROCEDURE lp_obt_dat_prestamo(p_nro_solicitud    IN ge_cuentas.nro_cuenta%TYPE,
                                  p_nro_cuenta       IN pr_cta_prestamos.nro_cuenta%TYPE,
                                  p_cod_moneda       IN OUT pr_solicitudes.cod_moneda%TYPE,
                                  p_mto_capital      IN OUT pr_solicitudes.monto%TYPE,
                                  p_tip_interes      IN OUT pr_solicitudes.tip_interes%TYPE,
                                  p_fec_inicio       IN OUT DATE,
                                  p_fec_vencimiento  IN OUT DATE,
                                  p_val_tasa         IN OUT NUMBER,
                                  p_tip_amortizacion IN OUT VARCHAR2,
                                  p_can_cuotas       IN OUT NUMBER,
                                  p_mto_desembolso   IN OUT pr_solicitudes.monto%TYPE,
                                  p_solicitud        IN OUT pr_solicitudes.nro_solicitud%TYPE,
                                  p_tipo             IN OUT pr_solicitudes.tipo%type);
  
    v_cod_moneda        ge_cuentas.cod_moneda%TYPE;
    v_mto_capital       pr_cta_prestamos.mto_capital%TYPE;
    v_mto_desembolso    pr_cta_prestamos.monto%TYPE;
    v_sal_capital       pr_cta_prestamos.mto_capital%TYPE;
    v_fec_inicio        pr_cta_prestamos.fec_inicio%TYPE;
    v_fec_vencimiento   pr_solicitudes.fec_vencimiento%TYPE;
    v_fec_vto_cuota_ant pr_sol_cuotas.fec_vto_exacto%TYPE;
    v_val_inicial       pr_cta_prestamos.mto_capital%TYPE;
    v_tip_interes       pr_solicitudes.tip_interes%TYPE;
    v_nro_solicitud     pr_solicitudes.nro_solicitud%TYPE;
    v_nro_sol_prestamo  pr_solicitudes.nro_solicitud%TYPE;
    v_nro_cuenta        pr_cta_prestamos.nro_cuenta%type;
    v_es_ia             VARCHAR2(1) := 'N';
    v_acum_tan          NUMBER;
    v_acum_tae          NUMBER;
    v_contador          NUMBER;
    v_gastos_imp        NUMBER;
    v_gastos_noi        NUMBER;
    v_avg_dia           NUMBER;
    v_dif_cuotas        NUMBER;
    v_dif_permitida     NUMBER := 1000;
    v_per_capital       NUMBER;
    v_dias              NUMBER;
    v_dias_cuota        NUMBER;
    v_pri_cuota         NUMBER;
    v_min_cuota         NUMBER;
    v_tot_dias          NUMBER;
    v_mto_gasto         NUMBER(18, 2);
    v_plazo             NUMBER;
    v_can_cuotas        NUMBER;
    v_val_tas_pactada   NUMBER;
    v_redondeo          NUMBER(2) := 0;
    v_periodo           NUMBER := 30;
    v_tip_amortizacion  VARCHAR2(1);
    v_tipo              varchar2(1);
    v_sale              VARCHAR2(1) := 'N';
    v_numero            VARCHAR2(4000);
    v_plz_numero        VARCHAR2(4000);
    v_auxiliar          VARCHAR2(4000);
    v_plz_auxiliar      VARCHAR2(4000);
    v_mto_max_gastos    NUMBER;
    v_mto_lim_prestamo  NUMBER;
    v_dis_gasto         number;
  
    --- Cursor de cuotas
    CURSOR c_cuotas IS
      SELECT nro_cuota,
             nvl(mto_capital, 0) + nvl(val_interes, 0) val_cuota,
             nvl(mto_capital, 0) mto_capital,
             nvl(val_interes, 0) mto_interes,
             nvl(val_int_adelantado, 0) mto_int_documentado,
             trunc(fec_vto_habil - v_fec_inicio) dias,
             dia_interes,
             fec_vto_exacto
        FROM pr_sol_cuotas
       WHERE nro_solicitud = p_nro_solicitud
         AND p_nro_cuenta IS NULL
         AND nro_cuota > 0
      UNION ALL
      SELECT nro_cuota,
             nvl(mto_capital, 0) + nvl(mto_int_documentado, 0) +
             nvl(mto_interes, 0) val_cuota,
             nvl(mto_capital, 0) + nvl(mto_int_documentado, 0) mto_capital,
             nvl(mto_interes, 0) mto_interes,
             nvl(mto_int_documentado, 0) mto_int_documentado,
             trunc(fec_vencimiento - v_fec_inicio) dias,
             trunc(fec_vencimiento -
                   decode(nro_cuota,
                          1,
                          v_fec_inicio,
                          PAS_BCP_ANT.fu_obt_vto_ant_cuo(nro_cuenta,
                                                         nro_cuota))) dia_interes,
             trunc(fec_vencimiento)
        FROM pr_cuotas
       WHERE nro_cuenta = p_nro_cuenta
         AND p_nro_solicitud IS NULL
         AND nro_cuota > 0
       ORDER BY 1;
  
    /*Plazo promedio Int. Adelantado */
    function lf_plz_int_adelantado(p_nro_solicitud IN pr_cta_prestamos.nro_solicitud%TYPE,
                                   p_nro_cuenta    IN pr_cta_prestamos.nro_cuenta%TYPE)
      return number is
      v_dia_plazo number;
    begin
      if p_nro_solicitud is not null then
        begin
          SELECT case
                   when b.cod_modalidad not in (613, 648) then
                    to_number(nvl(avg(trunc(fec_vto_habil - v_fec_inicio)),
                                  0))
                   else
                    max(b.per_vto_capital)
                 end dias
            into v_dia_plazo
            FROM pr_sol_cuotas a, pr_solicitudes b
           WHERE a.nro_solicitud = p_nro_solicitud
             and b.nro_solicitud = a.nro_solicitud
             AND p_nro_cuenta IS NULL
             AND nro_cuota > 0
           group by b.cod_modalidad;
        exception
          when no_data_found then
            return 0;
        end;
      elsif p_nro_cuenta is not null then
        begin
          SELECT nvl(avg(trunc(fec_vencimiento - v_fec_inicio)), 0) dias
            into v_dia_plazo
            FROM pr_cuotas
           WHERE nro_cuenta = p_nro_cuenta
             AND p_nro_solicitud IS NULL
             AND nro_cuota > 0;
        exception
          when no_data_found then
            return 0;
        end;
      end if;
      return v_dia_plazo;
    exception
      when others then
        return 0;
    end;
  
    /* Obtener gastos del prestamo. */
    PROCEDURE lp_obt_gas_prestamos(p_nro_solicitud       IN pr_solicitudes.nro_solicitud%TYPE,
                                   p_nro_cuenta          IN pr_cta_prestamos.nro_cuenta%TYPE,
                                   p_cod_moneda          IN ge_cuentas.cod_moneda%TYPE,
                                   p_mto_desembolso      IN pr_solicitudes.monto%TYPE,
                                   p_mto_car_imputable   IN OUT NUMBER,
                                   p_mto_car_noimputable IN OUT NUMBER) IS
    
      v_fec_actual  DATE;
      v_par_car_tae VARCHAR2(30);
      --V_PAR_MIN_GAS VARCHAR2(30);
      v_gastos            NUMBER;
      v_gastos_imp        NUMBER;
      v_mto_solicitado    number;
      v_aux_mto_imputable number;
    
      v_mto_lim_prestamo NUMBER;
      v_mto_lim_cargo    NUMBER;
      v_mto_desembolso   NUMBER;
      v_redondeo         NUMBER := 0;
    BEGIN
      v_gastos      := 0;
      v_fec_actual  := pag_cal.fu_obt_fec_actual(4);
      v_par_car_tae := fug_obt_pardinamico('GRU_CAR_TAE');
      IF p_cod_moneda != pag_gen.fu_obt_mon_local THEN
        v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                                          NULL,
                                          NULL,
                                          p_cod_moneda);
      END IF;
      IF p_nro_solicitud IS NOT NULL THEN
        --- Obtiene los gastos que constituyen interes.
        SELECT SUM(decode(cod_tra_hijo,
                          NULL,
                          nvl(car.mto_mon_prestamo, 0),
                          round(nvl(car.mto_mon_prestamo, 0) * 100 /
                                (100 + fug_obt_val_tasa(s.cod_modulo,
                                                        s.cod_modalidad,
                                                        s.cod_oficina,
                                                        NULL,
                                                        s.cod_moneda,
                                                        0,
                                                        'N',
                                                        NULL,
                                                        d.cod_tra_hijo,
                                                        s.fec_inicio)),
                                v_redondeo)))
          INTO v_gastos_imp
          FROM ge_transacciones_det d,
               ge_transacciones     t,
               pr_sol_cargos        car,
               pr_solicitudes       s
         WHERE t.cod_transaccion = car.cod_transaccion
           AND t.cod_modulo = s.cod_modulo
           AND t.cod_modalidad = s.cod_modalidad
           AND d.cod_transaccion(+) = t.cod_transaccion
           AND d.cod_modulo(+) = t.cod_modulo
           AND d.cod_modalidad(+) = t.cod_modalidad
           AND car.nro_solicitud = s.nro_solicitud
           AND s.nro_solicitud = p_nro_solicitud
           AND EXISTS --- Solo gastos imputables como interes.
         (SELECT 1
                  FROM ge_gru_transacciones_det gt
                 WHERE gt.cod_transaccion = car.cod_transaccion
                   AND gt.cod_modulo = s.cod_modulo
                   AND gt.cod_modalidad = s.cod_modalidad
                   AND gt.cod_gru_transaccion = v_par_car_tae);
      
        --- Obtiene los gastos que no constituyen interes.
        --- Obtiene el total de gastos y a este le resta los que si constituyen interes.
        SELECT SUM(nvl(car.mto_mon_prestamo, 0)) - nvl(v_gastos_imp, 0)
          INTO v_gastos
          FROM pr_sol_cargos car
         WHERE car.nro_solicitud = p_nro_solicitud;
        select a.monto
          into v_mto_solicitado
          from pr_solicitudes a
         where a.nro_solicitud = p_nro_solicitud;
      
      ELSE
        v_gastos         := 0;
        v_gastos_imp     := 0;
        v_mto_solicitado := 0;
      END IF;
      ---
      v_aux_mto_imputable   := round(v_mto_solicitado * 15 / 100, 0);
      p_mto_car_imputable   := nvl(v_gastos_imp, 0);
      p_mto_car_noimputable := nvl(v_gastos, 0);
      ---
      /* Debe hacer todas las comparaciones para verificar si esl gasto es imputable o no. */
      IF p_mto_car_imputable > 0 THEN
        -- Se convierte a la moneda el monto limite para considerar como gastos no imputables...
        v_mto_lim_prestamo := pag_gen.fu_con_mon_a_moneda(pag_gen.fu_obt_mon_local,
                                                          p_cod_moneda,
                                                          fug_obt_pardinamico('MTO_TAE',
                                                                              6));
      
        IF nvl(v_mto_lim_prestamo, 0) > 0 THEN
          -- Solo si el prestamo es menor o igual al limite puede que no sea imputable el cargo.
          IF p_mto_desembolso <= v_mto_lim_prestamo THEN
            -- Si es menor o igual al limite (5.400.000) entonces verifica si el cargo no supera el 15%
            /*IF nvl(p_mto_desembolso,0) > 0 then
              IF p_mto_car_imputable > round(p_mto_desembolso * 0.15, v_redondeo) THEN
                 -- Si el cargo es mayor al 15% se debe considerar como imputable solo el 15%
                 p_mto_car_imputable := p_mto_car_imputable -
                                        round(p_mto_desembolso * 0.15, v_redondeo);
              END IF;
            --ELSE
            END IF;*/
            -- Si sigue siendo mayor a cero.
            IF p_mto_car_imputable > 0 THEN
              -- Si el cargo es menor o igual al 15% debe verificar que no supere el
              -- Se convierte a la moneda el monto limite para considerar como gastos no imputables...
              v_mto_lim_cargo := pag_gen.fu_con_mon_a_moneda(pag_gen.fu_obt_mon_local,
                                                             p_cod_moneda,
                                                             fug_obt_pardinamico('IMP_MIN_GAS',
                                                                                 6));
            
              v_mto_lim_cargo := round((v_mto_lim_cargo / 1.1), v_redondeo);
              IF v_aux_mto_imputable < v_mto_lim_cargo THEN
                v_mto_lim_cargo := v_aux_mto_imputable;
              END IF;
              IF p_mto_car_imputable > v_mto_lim_cargo THEN
                p_mto_car_imputable := p_mto_car_imputable -
                                       v_mto_lim_cargo;
              ELSE
                IF v_gastos_imp = p_mto_car_imputable THEN
                  -- Quiere decir que no se vio afectado por el 15%.
                  p_mto_car_imputable := 0;
                END IF;
              END IF;
            END IF;
            --END IF;
          END IF;
        END IF;
      END IF;
    END;
    /* Obtener dias. */
    FUNCTION lf_obt_dias(p_nro_solicitud IN pr_cta_prestamos.nro_solicitud%TYPE,
                         p_nro_cuota     IN pr_cuotas.nro_cuota%TYPE)
      RETURN NUMBER IS
      v_dias pr_sol_cuotas.dia_interes%TYPE;
    BEGIN
      SELECT dia_interes
        INTO v_dias
        FROM pr_sol_cuotas
       WHERE nro_solicitud = p_nro_solicitud
         AND nro_cuota = p_nro_cuota;
      RETURN v_dias;
    EXCEPTION
      WHEN no_data_found THEN
        raise_application_error(-20000, 'Sol.Cuotas no registrada');
    END;
    /* Obtener datos del prestamo. */
    PROCEDURE lp_obt_dat_prestamo(p_nro_solicitud    IN ge_cuentas.nro_cuenta%TYPE,
                                  p_nro_cuenta       IN pr_cta_prestamos.nro_cuenta%TYPE,
                                  p_cod_moneda       IN OUT pr_solicitudes.cod_moneda%TYPE,
                                  p_mto_capital      IN OUT pr_solicitudes.monto%TYPE,
                                  p_tip_interes      IN OUT pr_solicitudes.tip_interes%TYPE,
                                  p_fec_inicio       IN OUT DATE,
                                  p_fec_vencimiento  IN OUT DATE,
                                  p_val_tasa         IN OUT NUMBER,
                                  p_tip_amortizacion IN OUT VARCHAR2,
                                  p_can_cuotas       IN OUT NUMBER,
                                  p_mto_desembolso   IN OUT pr_solicitudes.monto%TYPE,
                                  p_solicitud        IN OUT pr_solicitudes.nro_solicitud%TYPE,
                                  p_tipo             IN OUT pr_solicitudes.tipo%type) IS
    BEGIN
      SELECT a.cod_moneda,
             a.tot_prestamo,
             a.tip_interes,
             a.fec_inicio,
             a.fec_vencimiento,
             b.val_tasa,
             a.tip_amortizacion,
             can_cuotas,
             a.tot_desembolsar,
             a.nro_solicitud,
             a.tipo
        INTO p_cod_moneda,
             p_mto_capital,
             p_tip_interes,
             p_fec_inicio,
             p_fec_vencimiento,
             p_val_tasa,
             p_tip_amortizacion,
             p_can_cuotas,
             p_mto_desembolso,
             p_solicitud,
             p_tipo
        FROM pr_sol_tasas b,
             pr_solicitudes a,
             (SELECT COUNT(*) can_cuotas
                FROM pr_sol_cuotas
               WHERE nro_cuota > 0
                 AND nro_solicitud = p_nro_solicitud)
       WHERE a.nro_solicitud = p_nro_solicitud
         AND a.nro_solicitud = b.nro_solicitud
         AND p_nro_cuenta IS NULL
      UNION ALL
      SELECT a.cod_moneda,
             a.mto_capital,
             a.tip_interes,
             a.fec_inicio,
             a.fec_vencimiento,
             a.val_tasa,
             nvl(b.tip_amortizacion, 'F') tip_amortizacion,
             a.can_cuotas,
             a.mto_capital,
             a.nro_solicitud,
             a.tipo
        FROM pr_solicitudes b, pr_cta_prestamos a
       WHERE a.nro_cuenta = p_nro_cuenta
         AND p_nro_solicitud IS NULL
         AND a.nro_solicitud = b.nro_solicitud(+);
    EXCEPTION
      WHEN no_data_found THEN
        raise_application_error(-20000,
                                'Solicitud ' || p_nro_solicitud ||
                                ' no registrado');
    END;
    PROCEDURE fu_obt_tir_adelantado(p_interes    IN NUMBER,
                                    p_cargo      IN NUMBER,
                                    p_saldo      IN NUMBER,
                                    p_nro_cuota  IN NUMBER,
                                    p_cod_moneda IN VARCHAR2,
                                    p_tir        OUT NUMBER) IS
      v_sal_minimo NUMBER;
      v_cargo      NUMBER;
    
    BEGIN
      SELECT PAG_GEN.FU_CON_MON_A_MONEDA(PAG_GEN.FU_OBT_MON_LOCAL,
                                         p_cod_moneda,
                                         sal_min_vigente)
        INTO v_sal_minimo
        FROM pr_parametros;
      v_cargo := round(p_cargo + (p_cargo / 10));
      --Si Capital es mayor a 5 salarios se toma la totalidad del cargo
      IF p_saldo > (v_sal_minimo * 5) THEN
        v_cargo := v_cargo;
        --Si 5 Jornales actuales es menor al 15% del capital
      ELSIF ((v_sal_minimo / 30) * 5) < (p_saldo * 0.15) THEN
        v_cargo := v_cargo - ((v_sal_minimo / 30) * 5);
      ELSE
        v_cargo := v_cargo - (p_saldo * 0.15);
      END IF;
      IF v_cargo < 0 THEN
        v_cargo := 0;
      END IF;
      IF p_nro_cuota = 1 THEN
        p_tir := round((p_interes + v_cargo) / (p_saldo / 100), 2);
      ELSE
        p_tir := round(p_interes / (p_saldo / 100), 2);
      END IF;
    END;
  BEGIN
    v_contador := 0;
    v_acum_tan := 0;
    v_acum_tae := 0;
    -- Para int. adelantado prestamos que no sean de descuento.
    --Si corresponde a una cta. recalendarizada toma el tae informado en el informe de tasas semanal
    BEGIN
      SELECT t.val_parametro, x.val_tas_efectiva, x.val_tas_nominal
        INTO v_cta_recalendarizada, p_val_tae, p_val_tan
        FROM ge_cta_dat_adicionales t, sb_tas_ape_semanales x
       WHERE t.nro_cuenta = p_nro_cuenta
         AND t.parametro IN ('PRE_CTA_RECALENDARIZADA')
         AND t.nro_cuenta = x.nro_cuenta;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        v_cta_recalendarizada := NULL;
    END;
  
    IF v_cta_recalendarizada IS NULL THEN
      IF p_nro_cuenta IS NOT NULL THEN
        BEGIN
          SELECT a.tip_interes, a.tipo, b.nro_solicitud
            INTO v_tip_interes, v_tipo, v_nro_sol_prestamo
            FROM pr_solicitudes b, pr_cta_prestamos a
           WHERE a.nro_cuenta = p_nro_cuenta
             AND p_nro_solicitud IS NULL
             AND a.nro_solicitud = b.nro_solicitud(+);
          IF v_tip_interes = 'A' AND v_tipo <> 'D' THEN
            v_es_ia := 'S';
          END IF;
        EXCEPTION
          WHEN no_data_found THEN
            NULL;
          WHEN OTHERS THEN
            NULL;
        END;
      END IF;
      IF v_es_ia = 'S' AND p_nro_cuenta IS NOT NULL THEN
        v_nro_cuenta := NULL;
      ELSIF v_es_ia = 'N' THEN
        v_nro_sol_prestamo := p_nro_solicitud;
        v_nro_cuenta       := p_nro_cuenta;
      END IF;
    
      --- Obtener datos del prestamos
      lp_obt_dat_prestamo(v_nro_sol_prestamo,
                          v_nro_cuenta,
                          v_cod_moneda,
                          v_mto_capital,
                          v_tip_interes,
                          v_fec_inicio,
                          v_fec_vencimiento,
                          v_val_tas_pactada,
                          v_tip_amortizacion,
                          v_can_cuotas,
                          v_mto_desembolso,
                          v_nro_solicitud,
                          v_tipo);
      lp_obt_gas_prestamos(v_nro_sol_prestamo,
                           v_nro_cuenta,
                           v_cod_moneda,
                           v_mto_desembolso,
                           v_gastos_imp,
                           v_gastos_noi);
      v_sal_capital       := v_mto_capital;
      v_plazo             := v_fec_vencimiento - v_fec_inicio;
      v_fec_vto_cuota_ant := v_fec_inicio;
      v_sale              := 'N';
      v_redondeo          := 0;
      IF v_cod_moneda = pag_gen.fu_obt_mon_local THEN
        v_dif_permitida := 1000;
      ELSE
        v_dif_permitida := 10;
        v_redondeo      := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                                               NULL,
                                               NULL,
                                               v_cod_moneda);
      END IF;
      -- Obtiene el monto maximo de cobro de comision permitido fuera de TAE.
      v_mto_max_gastos   := NVL(fug_obt_pardinamico('MTO_MAX_COM_ADM',
                                                    NULL,
                                                    NULL,
                                                    v_cod_moneda),
                                0);
      v_mto_max_gastos   := (v_mto_max_gastos / 1.1);
      v_mto_lim_prestamo := pag_gen.fu_con_mon_a_moneda(pag_gen.fu_obt_mon_local,
                                                        v_cod_moneda,
                                                        fug_obt_pardinamico('MTO_TAE',
                                                                            6));
      --
      FOR cuo IN c_cuotas LOOP
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
          v_numero     := cuo.val_cuota;
          v_plz_numero := cuo.dias;
        
          IF v_tip_interes != 'A' OR
             (v_tip_interes = 'A' AND v_tipo <> 'D') THEN
            IF cuo.nro_cuota = 1 THEN
              -- Verifica si es realmente price o no.
              IF v_tip_amortizacion = 'P' THEN
                -- Si es price, si los plazos son fijos debe calcular diferente.
                IF p_nro_solicitud IS NOT NULL THEN
                  SELECT AVG(dia_interes),
                         MIN(s.per_vto_capital),
                         AVG(nvl(mto_capital, 0) + nvl(val_interes, 0) +
                             nvl(val_int_adelantado, 0)) -
                         MIN(nvl(mto_capital, 0) + nvl(val_interes, 0) +
                             nvl(val_int_adelantado, 0)),
                         MIN(nvl(mto_capital, 0) + nvl(val_interes, 0) +
                             nvl(val_int_adelantado, 0))
                    INTO v_avg_dia,
                         v_per_capital,
                         v_dif_cuotas,
                         v_min_cuota
                    FROM pr_sol_cuotas c, pr_solicitudes s
                   WHERE s.nro_solicitud = p_nro_solicitud
                     AND c.nro_solicitud = s.nro_solicitud
                     AND c.nro_cuota > 0;
                ELSE
                  SELECT AVG(trunc(x.fec_vencimiento -
                                   PAS_BCP_ANT.fu_obt_vto_ant_cuo(x.nro_cuenta,
                                                                  x.nro_cuota))),
                         MIN(c.per_vto_capital),
                         AVG(nvl(x.mto_capital, 0) + nvl(x.mto_interes, 0) +
                             nvl(x.mto_int_documentado, 0)) -
                         MIN(nvl(x.mto_capital, 0) + nvl(x.mto_interes, 0) +
                             nvl(x.mto_int_documentado, 0)),
                         MIN(nvl(x.mto_capital, 0) + nvl(x.mto_interes, 0) +
                             nvl(x.mto_int_documentado, 0))
                    INTO v_avg_dia,
                         v_per_capital,
                         v_dif_cuotas,
                         v_min_cuota
                    FROM pr_cuotas x, pr_cta_prestamos c
                   WHERE c.nro_cuenta = p_nro_cuenta
                     AND x.nro_cuenta = c.nro_cuenta
                     AND x.nro_cuota > 0;
                END IF;
                IF abs(v_avg_dia - v_per_capital) > 1 OR
                   abs(v_dif_cuotas) > v_dif_permitida OR v_can_cuotas = 1 THEN
                  -- Si la diferencia en dias entre el periodo de interes y el de capital
                  -- se considera que no es periodico por lo tanto no es price.
                  IF abs(cuo.dia_interes - v_per_capital) > 2 OR
                     (abs(v_dif_cuotas) > v_dif_permitida and
                      v_tip_amortizacion <> 'P') OR v_can_cuotas = 1 THEN
                    v_tip_amortizacion := 'F';
                  END IF;
                END IF;
                IF v_tip_implementacion = 2 AND v_tip_amortizacion = 'P' THEN
                  --- Verificar el importe de la primera cuota y del promedio de cuotas
                  BEGIN
                    IF p_nro_solicitud IS NOT NULL THEN
                      SELECT nvl(mto_capital, 0) + nvl(val_interes, 0) +
                             nvl(val_int_adelantado, 0)
                        INTO v_pri_cuota
                        FROM pr_sol_cuotas
                       WHERE nro_solicitud = p_nro_solicitud
                         AND nro_cuota = 1;
                    ELSE
                      SELECT nvl(mto_capital, 0) + nvl(mto_interes, 0) +
                             nvl(mto_int_documentado, 0)
                        INTO v_pri_cuota
                        FROM pr_cuotas
                       WHERE nro_cuenta = p_nro_cuenta
                         AND nro_cuota = 1;
                    END IF;
                  END;
                  --- Para 2 siempre que halla diferencia entra la primera cuota y la minima
                  --- el calculo del tae sera siempre sobre promedio, no se toma en cuenta los
                  --- parametros de diferencia
                  IF v_pri_cuota > v_min_cuota THEN
                    v_tip_amortizacion := 'F';
                  END IF;
                END IF;
              END IF;
            END IF;
          ELSE
            -- Si es adelantado...
            v_tot_dias   := nvl(v_tot_dias, 0) + cuo.dias;
            v_dias_cuota := nvl(v_dias_cuota, 0) +
                            (cuo.fec_vto_exacto - v_fec_vto_cuota_ant);
            IF v_tip_implementacion = 3 THEN
              -- FA.
              v_mto_gasto := round(v_gastos_imp / v_can_cuotas, v_redondeo);
            ELSE
              v_mto_gasto := round(v_gastos_imp *
                                   (nvl(cuo.mto_capital, 0) / v_mto_capital),
                                   v_redondeo);
            END IF;
            IF v_tip_interes != 'A' OR
               (v_tip_interes = 'A' AND v_tipo <> 'D') THEN
              v_val_inicial  := NVL(v_val_inicial, 0) + cuo.mto_capital -
                                cuo.mto_int_documentado - v_mto_gasto;
              v_auxiliar     := v_auxiliar || TRIM(to_char(cuo.val_cuota)) || '#';
              v_plz_auxiliar := v_plz_auxiliar || round(cuo.dias / 365, 4) || '#';
            ELSE
              IF nvl(v_gastos_imp, 0) <> 0 AND
                 nvl(v_gastos_imp, 0) > nvl(v_mto_max_gastos, 0) AND
                 NVL(v_mto_desembolso, 0) <= NVL(v_mto_lim_prestamo, 0) THEN
                v_dis_gasto   := (nvl(v_gastos_imp, 0) -
                                 nvl(v_mto_max_gastos, 0));
                v_val_inicial := nvl(cuo.mto_capital, 0) -
                                 (cuo.mto_interes + cuo.mto_int_documentado) -
                                 ((nvl(v_dis_gasto, 0) / v_can_cuotas));
              ELSIF nvl(v_gastos_imp, 0) <> 0 AND
                    nvl(v_gastos_imp, 0) > nvl(v_mto_max_gastos, 0) AND
                    NVL(v_mto_desembolso, 0) > NVL(v_mto_lim_prestamo, 0) THEN
                v_dis_gasto   := (nvl(v_gastos_imp, 0));
                v_val_inicial := nvl(cuo.mto_capital, 0) -
                                 (cuo.mto_interes + cuo.mto_int_documentado) -
                                 ((nvl(v_dis_gasto, 0) / v_can_cuotas));
              ELSE
                if nvl(v_gastos_imp, 0) <> 0 then
                  v_dis_gasto   := (nvl(v_gastos_imp, 0));
                  v_val_inicial := nvl(cuo.mto_capital, 0) -
                                   (cuo.mto_interes +
                                    cuo.mto_int_documentado) -
                                   ((nvl(v_dis_gasto, 0) / v_can_cuotas));
                else
                  v_dis_gasto   := (nvl(v_gastos_imp, 0));
                  v_val_inicial := nvl(cuo.mto_capital, 0) -
                                   (cuo.mto_interes +
                                    cuo.mto_int_documentado);
                end if;
              END IF;
              --v_val_inicial := cuo.mto_capital - cuo.mto_int_documentado - v_mto_gasto;
              v_auxiliar     := TRIM(to_char(cuo.val_cuota)) || '#';
              v_plz_auxiliar := round(cuo.dias, 4);
            END IF;
          
            v_numero     := v_auxiliar;
            v_plz_numero := v_plz_auxiliar;
            --v_dias        := cuo.dias;
            if v_tipo = 'D' then
              --v_dias := lf_plz_int_adelantado(p_nro_solicitud, p_nro_cuenta);
              v_dias := cuo.dias;
            else
              v_dias := cuo.dias;
            end if;
          END IF;
          --
          IF v_tip_interes != 'A' OR
             (v_tip_interes = 'A' AND v_tipo <> 'D') THEN
            v_dias := cuo.dia_interes;
            IF v_tip_amortizacion = 'P' THEN
              -- Si sigue siendo price.
              -- Adiciona los gastos a la cuota 1
              IF cuo.nro_cuota = 1 THEN
                IF v_tip_implementacion = 2 THEN
                  v_val_inicial := v_sal_capital - (v_gastos_imp * 2);
                ELSE
                  IF nvl(v_gastos_imp, 0) <> 0 AND
                     nvl(v_gastos_imp, 0) > nvl(v_mto_max_gastos, 0) AND
                     NVL(v_mto_desembolso, 0) <= NVL(v_mto_lim_prestamo, 0) THEN
                    v_val_inicial := v_sal_capital - (nvl(v_gastos_imp, 0) /*- nvl(v_mto_max_gastos,0)*/
                                     );
                  ELSIF nvl(v_gastos_imp, 0) <> 0 AND
                        nvl(v_gastos_imp, 0) > nvl(v_mto_max_gastos, 0) AND
                        NVL(v_mto_desembolso, 0) >
                        NVL(v_mto_lim_prestamo, 0) THEN
                    v_val_inicial := v_sal_capital - (nvl(v_gastos_imp, 0));
                  ELSE
                    v_val_inicial := v_sal_capital - v_gastos_imp;
                  END IF;
                END IF;
                v_dias := v_per_capital;
              END IF;
              -- Debe cargar las cuotas en el auxiliar.
              v_auxiliar     := v_auxiliar ||
                                TRIM(to_char(cuo.mto_capital +
                                             cuo.mto_interes +
                                             cuo.mto_int_documentado)) || '#';
              v_plz_auxiliar := v_plz_auxiliar || round(cuo.dias / 365, 4) || '#';
            ELSE
              -- Sino es price.
              IF cuo.nro_cuota = 1 THEN
                -- Adiciona los gastos a la cuota 1
                IF nvl(v_gastos_imp, 0) <> 0 AND
                   nvl(v_gastos_imp, 0) > nvl(v_mto_max_gastos, 0) AND
                   NVL(v_mto_desembolso, 0) <= NVL(v_mto_lim_prestamo, 0) THEN
                  v_val_inicial := nvl(v_sal_capital, 0) -
                                   (nvl(v_gastos_imp, 0) /*- nvl(v_mto_max_gastos,0)*/);
                ELSIF nvl(v_gastos_imp, 0) <> 0 AND
                      nvl(v_gastos_imp, 0) > nvl(v_mto_max_gastos, 0) AND
                      NVL(v_mto_desembolso, 0) > NVL(v_mto_lim_prestamo, 0) THEN
                  v_val_inicial := nvl(v_sal_capital, 0) -
                                   (nvl(v_gastos_imp, 0));
                ELSE
                  v_val_inicial := nvl(v_sal_capital, 0) -
                                   nvl(v_gastos_imp, 0);
                END IF;
              ELSE
                --v_val_inicial := v_sal_capital;
                if v_tip_interes = 'A' and v_tipo = 'D' then
                  v_val_inicial := nvl(cuo.mto_capital, 0) -
                                   (cuo.mto_interes +
                                    cuo.mto_int_documentado) -
                                   ((nvl(v_dis_gasto, 0) / v_can_cuotas));
                end if;
              END IF;
              v_auxiliar     := v_auxiliar ||
                                TRIM(to_char(cuo.mto_capital +
                                             cuo.mto_interes +
                                             cuo.mto_int_documentado)) || '#';
              v_plz_auxiliar := v_plz_auxiliar || round(cuo.dias / 365, 4) || '#';
            END IF;
            v_numero     := v_auxiliar;
            v_plz_numero := v_plz_auxiliar;
          END IF;
          --- Hace los calculos de TIR, TAN y TAE
          DECLARE
            v_tir     NUMBER;
            v_tan     NUMBER;
            v_tae     NUMBER;
            v_dias1   NUMBER(4);
            v_inicial NUMBER(18, 2);
            v_numero1 VARCHAR2(4000);
            v_numero2 VARCHAR2(4000);
          BEGIN
            v_dias1   := v_dias;
            v_numero1 := v_numero;
            v_numero2 := v_plz_numero;
            v_inicial := v_val_inicial;
            IF v_inicial > 0 THEN
              IF v_tip_amortizacion = 'P' AND v_can_cuotas = cuo.nro_cuota THEN
                -- Si es tipo price en la ultima cuota calcula el tir.
                v_tan := round(PAS_BCP_ANT.fu_obt_tir(v_inicial,
                                                      v_can_cuotas,
                                                      v_numero1),
                               4);
                v_tae := PAS_BCP_ANT.fu_obt_tae(v_tan, v_dias);
              ELSIF v_tip_amortizacion != 'P' THEN
                if v_tip_interes = 'A' AND v_tipo <> 'D' then
                  v_dias := abs(cuo.fec_vto_exacto - v_fec_vto_cuota_ant);
                  fu_obt_tir_adelantado(cuo.mto_int_documentado,
                                        v_gastos_imp,
                                        v_sal_capital,
                                        cuo.nro_cuota,
                                        v_cod_moneda,
                                        v_tir);
                else
                  if v_can_cuotas = cuo.nro_cuota and v_tipo <> 'D' then
                    v_tan := round(PAS_BCP_ANT.fu_obt_val_tir(v_inicial,
                                                              v_can_cuotas,
                                                              v_numero1,
                                                              v_numero2),
                                   4);
                  elsif v_tipo = 'D' then
                    v_tan := round(PAS_BCP_ANT.fu_obt_tir_ade(v_inicial,
                                                              1,
                                                              v_numero1,
                                                              v_numero2),
                                   4);
                  end if;
                end if;
                v_tae := PAS_BCP_ANT.fu_obt_tae(v_tan, v_dias);
              END IF;
            ELSE
              v_tir := 0;
              v_tan := 0;
              v_tae := 0;
            END IF;
            v_acum_tan := nvl(v_acum_tan, 0) + nvl(v_tan, 0);
            v_acum_tae := nvl(v_acum_tae, 0) + nvl(v_tae, 0);
          END;
          v_sal_capital       := v_sal_capital - cuo.mto_capital;
          v_fec_vto_cuota_ant := cuo.fec_vto_exacto;
          v_contador          := v_contador + 1;
          IF v_tip_amortizacion = 'P' or
             (v_tip_amortizacion != 'P' and v_tip_interes <> 'A') THEN
            -- Si es tipo price cera el acumulado porque solo sirve el ultimo calculado y ya no debe calcular el promedio del tan.
            IF v_can_cuotas <> cuo.nro_cuota THEN
              v_acum_tan := 0;
            ELSE
              v_contador := 1;
            END IF;
          END IF;
        END IF;
      END LOOP;
      IF v_tip_interes = 'A' AND v_tipo = 'D' THEN
        v_dias := v_tot_dias / v_contador;
      END IF;
      IF v_dias > 365 THEN
        --- Agregado el 23/06/08 Juan Silvero de BCP dijo que el sistema de tasas no acepta periodo > 365
        v_dias := 365;
      END IF;
      --- Calcular tasa promedio
      p_val_tan := round(v_acum_tan / v_contador, 2);
      IF v_tip_implementacion NOT IN (2, 3) AND
         p_val_tan < v_val_tas_pactada THEN
        p_val_tan := v_val_tas_pactada;
      END IF;
    
      p_val_tan := round(v_acum_tan, 2);
      p_val_tae := round(v_acum_tae, 2);
      IF v_tip_interes = 'A' AND v_tipo = 'D' THEN
        p_val_tan := round(v_acum_tan / v_contador, 2);
        v_dias    := lf_plz_int_adelantado(p_nro_solicitud, p_nro_cuenta);
        --p_val_tae := round(PAS_BCP_ANT.fu_obt_tae(p_val_tan, v_dias),2);
        p_val_tae := round(fug_obt_tae_ade(p_val_tan, v_dias), 2);
      END IF;
      /*
      IF v_tip_interes = 'A' AND v_tipo = 'D' THEN
         -- Si es un descuento obtiene el tae con el promedio de dias.
         -- p_val_tae := round(PAS_BCP_ANT.fu_obt_tae(p_val_tan, v_dias), 2);
          p_val_tan := round(v_acum_tan, 2);
          p_val_tae := round(v_acum_tae, 2);
      ELSE
         IF v_tip_amortizacion = 'P' THEN
            -- Si los dias son fijos halla el tae de acuerdo a esto no por promedio.
            IF v_tip_implementacion NOT IN (2, 3) AND v_gastos_imp = 0 THEN
               p_val_tan := v_val_tas_pactada;
            END IF;
            IF v_dias <> v_periodo THEN
               v_dias := v_periodo;
            END IF;
            IF v_tip_implementacion NOT IN (2, 3) AND v_gastos_imp = 0 THEN
               p_val_tan := PAS_BCP_ANT.fu_obt_tan(p_val_tan, v_dias);
               if v_tip_interes = 'A' then
                 p_val_tae := PAS_BCP_ANT.fu_obt_tae_ade(p_val_tan, v_dias);
               else
                 p_val_tae := PAS_BCP_ANT.fu_obt_tae(p_val_tan, v_dias);
               end if;
            else
               p_val_tae := round(v_acum_tae / v_contador, 2);
            end if;
         ELSE
            -- Si los dias no son fijos o es flexible debe halla por promedio.
            p_val_tae := round(v_acum_tae / v_contador, 2);
         END IF;
      END IF;*/
    END IF;
    --p_val_tae := 10;
  END;

  /* Generar los registros de la tabla sb_estratifacion_dep el ultimo día. */
  
  ------- FIN PROCEDIMIENTO PARA LISTADO DE ESTRATIFICACION -------;
  /* Buscar moneda fuerte */
  FUNCTION FU_OBT_MON_FUERTE RETURN VARCHAR2 IS
  
    V_MON_FUERTE GE_PAR_GENERALES.COD_MON_FUERTE%TYPE;
  BEGIN
  
    SELECT cod_mon_fuerte
      INTO v_mon_fuerte
      FROM ge_par_generales
     WHERE ROWNUM = 1;
    RETURN v_mon_fuerte;
  
  EXCEPTION
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20000, 'ERROR al buscar moneda fuerte');
  END;
  /* Permite generar las tablas de liquidez */

  /* Genera los depositoos en casa matriz y dependencias. */
  
  /* Obtener fecha de vencimiento anterior del prestamos. */
  FUNCTION FU_OBT_VTO_ANT_CUO(P_NRO_CUENTA IN PR_CTA_PRESTAMOS.NRO_CUENTA%TYPE,
                              P_NRO_CUOTA  IN PR_CUOTAS.NRO_CUOTA%TYPE)
    RETURN DATE IS
    v_fec_vto pr_cuotas.fec_vencimiento%type;
  BEGIN
    select fec_vencimiento
      into v_fec_vto
      from pr_cuotas
     where nro_cuenta = p_nro_cuenta
       and nro_cuota = p_nro_cuota - 1;
    return v_fec_vto;
  END;
  /* Genera las aperturas y calcula las tasas correspondientes. */

  /* Obtener devengado total de CDA. */

  /* Obtener devengado de Ahorro a la Vista. */

   
  
END PAS_BCP_ANT;
/
