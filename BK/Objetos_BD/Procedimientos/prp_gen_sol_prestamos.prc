CREATE OR REPLACE PROCEDURE it.prp_gen_sol_prestamos(p_cod_persona         in ba_personas.cod_persona%TYPE,
                                                        p_mto_solicitado      in number,
                                                        p_can_cuotas          in number,
                                                        p_fec_pri_vencimiento in date,
                                                        p_cod_canal           in number default null,
                                                        p_cod_moneda          in varchar2 default 'GS',
                                                        p_cod_modalidad       in number,
                                                        p_cod_submodalidad    in number default 1,
                                                        p_grabar              in varchar2 default 'S', -- Definir si grabara o no los datos en las tablas
                                                        p_mto_consolidado     in number,
                                                        p_clave               in number,
                                                        p_solicitud           in out pr_solicitudes.nro_solicitud%TYPE,
                                                        p_cuotas              out pr_sol_cuotas.mto_capital%TYPE,
                                                        p_tasa                in cr_piz_plazos.tas_efectiva%TYPE default null,
                                                        p_cod_error           out number,
                                                        p_msj_error           out varchar2) is
  --i NUMBER(3);
   v_dias_interes VARCHAR2(4000);
   v_auxiliar1 VARCHAR2(4000);  
  ---------------------------------------------------------------------------
  g_lugar     VARCHAR2(250);
  g_msj_error VARCHAR2(4000);
  g_cod_error NUMBER(3);--DEFAULT 0;
  -------------Nuevas Variables requeridas para pre-aprobado-----------------
  v_tip_persona          varchar2(1);
  v_tip_monto            varchar2(1) := 'N';
  v_cod_rub_economico    pr_solicitudes.cod_rub_economico%type;
  v_cod_pla_pre_aprobado pr_pre_aprobados.cod_pla_pre_aprobado%TYPE;
  v_cod_mod_default      ge_modalidades.cod_modalidad%TYPE := p_cod_modalidad;-- fug_obt_pardinamico('PRE_MAD_PRE_APROBADOS');
  v_cod_sub_mod_default  ge_modalidades.cod_modalidad%TYPE;-- := fu_obt_cod_submodalidad(6,p_cod_modalidad); --fug_obt_pardinamico('PRE_SUBMAD_PRE_APROBADOS');
  v_ori_fondo            number := 1;
  v_cod_banca            number; -- código de banca del cliente
  v_tip_destino          varchar2(1); -- Destino del crédito
  v_cod_campana          number := fug_obt_pardinamico('PRE_DIG_COD_CAMPANA',6,P_COD_MODALIDAD);--fug_obt_pardinamico('PRE_APR_ONB_CAMPANA'); -- código de campaña
  v_cod_usu_promotor     varchar2(10);
  v_cod_usu_oficial      varchar2(10);
  v_cod_departamento     number(3) := null; -- Se obtiene de los datos del cliente o en su defecto de la oficina
  v_cod_dep_parametro    number(3) := 18; -- Departamento de Parámetros
  v_tip_documento        number(1) := 1;
  v_cod_sec_credito      number(3) := 701; -- Valor por default para el sector del crédito 701 - CONSUMO.
  v_per_gracia           number(8);
  v_per_vencimiento      number(4) := 30;
  v_descripcion          varchar2(500) := fug_obt_des_modalidad(p_cod_modalidad); -- descripción de la operación
  v_nro_cuenta           varchar2(15);
  v_cantidad             number(3);
  v_cod_garantia         pr_gar_tipos.cod_garantia%type;
  ------------------ Variables del procedimiento -----------------------------
  v_dummy               NUMBER(9);
  v_cod_modulo          NUMBER(3) := 6; -- prestamos
  v_fec_actual          DATE := pag_cal.fu_obt_fec_actual(v_cod_modulo);
  v_cod_oficina         NUMBER(3) := fug_obt_ofi_usuario(user);
  v_mon_local           VARCHAR2(3) := pag_gen.fu_obt_mon_local;
  v_cotizacion          ge_cotizaciones.val_conversion%TYPE := pag_gen.fu_obt_cotizacion(v_mon_local);
  v_lugar               VARCHAR2(200) := NULL;
  v_exo_impuestos       VARCHAR2(1) := 'N';
  v_tot_prestamo        NUMBER(18, 2) := 0; -- total del prestamo
  v_mto_interes         NUMBER(18, 2) := 0; -- total de interes
  v_mto_cargo           NUMBER(18, 2) := 0;
  v_fec_inicio          DATE := v_fec_actual;
  v_fec_pri_vencimiento date := nvl(p_fec_pri_vencimiento,
                                    add_months(v_fec_inicio, 1));
  v_fec_vencimiento     date := ADD_MONTHS(V_FEC_PRI_VENCIMIENTO,
                                           p_can_cuotas - 1);
  --v_fec_pri_vencimiento DATE := add_months(v_fec_inicio, 1);
  v_tip_amortizacion VARCHAR2(1) := 'P';
  v_val_tasa         NUMBER;
  v_dia_plazo        NUMBER(8);
  v_per_capital      pr_solicitudes.per_vto_capital%TYPE;
  v_nro_solicitud    NUMBER(10);
  v_por_ajuste       NUMBER;
  v_ttvalor          NUMBER(18, 2);
  -- Datos de los cargos -----------------------------------------------------
  v_cod_transaccion     NUMBER(4);
  v_cod_tas_cargo       NUMBER(4);
  v_val_tas_cargo       NUMBER;
  v_cod_mon_cargo       VARCHAR2(3);
  v_tpvlpor             VARCHAR2(1);
  v_aplicar             VARCHAR2(3);
  v_tpdetas             VARCHAR2(1);
  v_val_cargo           NUMBER(18, 2);
  v_cod_ent_seguro      NUMBER(6);
  --v_mto_seg_cancelacion NUMBER(18, 2);
  v_imp_cargo           NUMBER(18, 2);
  ----variables para calculo de seguro------------------
  v_tas_seguro     NUMBER(18, 4);
  v_mto_tot_seguro NUMBER(18, 4);
  -- control del redondeo ----------------------------------------------------
  v_redondeo             NUMBER(2) := 0; -- redondeo a cero para moneda local
  v_can_dia_pri_vcto     number;
  v_can_dia_min_pri_vcto number;
  --v_mto_cuota            number := 0;
  --v_desembolsar          NUMBER(18, 2);
  v_mto_aumento  number;
  v_recalculo    varchar2(1) := 'N';
  v_tae          number;
  v_tan          number;
  v_tas_efectiva cr_piz_plazos.tas_efectiva%TYPE;
  v_mto_adm_anterior number;
  v_act_gas_anterior varchar2(1) := 'N';
  v_fin_max          varchar2(1) := 'N';
  --v_existe_tc     varchar2(1);

  v_rec_tae          varchar2(1) := 'N'; --variable para saber si se esta recalculando gasto_adm y llevando el TAE al tope
  -----variables de maximización tasa----DA-7311 CarolinaV. 04.12.2022
  v_valor_tasa pr_sol_tasas.val_tasa%TYPE;
  v_fec_vigencia ge_tas_fechas.fec_vigencia%TYPE;
  v_codi_tasa ge_tasas.cod_tasa%TYPE;
  v_tipo_valor ge_tasas.tip_valor%TYPE;
  v_tipo ge_tasas.tipo%TYPE;
  v_max_tasa varchar2(1)   := 'N';
  v_max_cargos varchar2(1) := 'N';
  v_tasa_back pr_sol_tasas.val_tasa%TYPE;
  v_valor_aum pr_sol_tasas.val_tasa%TYPE;
  v_bandera varchar2(1) ;
  v_tas_interes cr_piz_plazos.tas_interes%TYPE;
  v_tas_minima  cr_piz_plazos.tas_minima%TYPE;
  v_tas_maxima  cr_piz_plazos.tas_maxima%TYPE;
  v_mto_new_solicitado pr_solicitudes.monto%type;
  v_mto_max_aumento number := nvl(fug_obt_pardinamico('MTO_MAX_AUM_RECALCULO'),20); -- uenp-1117
  -- PCON-327 optimizar proceso
  v_pre_tra_mto_consolidado ge_par_dinamicos.val_parametro%type;
  v_mad_val_tae_gas_adm ge_par_dinamicos.val_parametro%type := instr(fug_obt_pardinamico('MAD_VAL_TAE_GAS_ADM'),','||v_cod_mod_default||',');
  v_mto_sol_max_adm ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('MTO_SOL_MAX_ADM',6,v_cod_mod_default,p_cod_moneda);
  v_pre_mod_afd ge_par_dinamicos.val_parametro%type := nvl(fug_obt_pardinamico('PRE_MOD_AFD',6,v_cod_mod_default,v_mon_local),'N');
  v_pre_per_gracia_min ge_par_dinamicos.val_parametro%type := nvl(fug_obt_pardinamico('PRE_PER_GRACIA_MIN',
                                                                  v_cod_modulo,
                                                                  v_cod_mod_default,
                                                                  v_mon_local),
                                                                  0);

  v_pre_per_gracia_max ge_par_dinamicos.val_parametro%type := nvl(fug_obt_pardinamico('PRE_PER_GRACIA_MAX',
                                                                  v_cod_modulo,
                                                                  v_cod_mod_default,
                                                                  v_mon_local),
                                                                  0);

  v_pre_seg_dif_juridicas ge_par_dinamicos.val_parametro%type := nvl(fug_obt_pardinamico('PRE_SEG_DIF_JURIDICAS',
                                                                     v_cod_modulo,
                                                                     v_cod_mod_default,
                                                                     v_mon_local),
                                                                     'N');

  v_val_ini_aumtasa ge_par_dinamicos.val_parametro%type := to_number(nvl(fug_obt_pardinamico('VAL_INI_AUMTASA',null,null, p_cod_moneda, null),0),'999G999D999999', 'NLS_NUMERIC_CHARACTERS='',.''');

  v_pre_cod_ent_per_juridicas ge_par_dinamicos.val_parametro%type := nvl(fug_obt_pardinamico('PRE_COD_ENT_PER_JURIDICAS',
                                                                         v_cod_modulo,
                                                                         v_cod_mod_default,
                                                                         null),
                                                                         '99999');
  v_can_salario     number := nvl(fug_obt_pardinamico('PRE_CAN_SAL_MIN_COMISION'),5);
  v_can_jor_minimo  number := fug_obt_pardinamico('PRE_CAN_JOR_MINIMOS');
  v_mto_max_gas_adm number := fug_obt_pardinamico('MTO_MAX_COM_ADM',
                                                   null,
                                                   null,
                                                   v_mon_local,
                                                   null);
  v_mto_gas_admistrativo number := pag_gen.fu_con_mon_a_moneda(v_mon_local,
                                                               v_mon_local,
                                                               fug_obt_pardinamico('MTO_TAE',6));

  v_pre_fac_pri_apl_seguros ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('PRE_FAC_PRI_APL_SEGUROS');
  v_mto_aum_gas_adm ge_par_dinamicos.val_parametro%type := nvl(fug_obt_pardinamico('MTO_AUM_GAS_ADM', null, null, p_cod_moneda, null ),0);
  v_min_val number := pag_gen.fu_obt_val_minimo;
  v_max_val number := pag_gen.fu_obt_val_maximo;
  ------Todo acerca de Linea ------
  v_nro_linea        pr_lineas.nro_linea%TYPE;
  v_cod_mon_linea    pr_lineas.cod_moneda%TYPE;
  v_mto_linea        pr_lineas.monto%TYPE;
  v_sal_linea        pr_lineas.monto%TYPE;
  v_sal_lin_mad      pr_lineas.monto%TYPE;
  v_fec_vto_lin      pr_lineas.fec_vencimiento%TYPE;
  v_ind_lin_mad      varchar2(1);
  v_mto_lin_aplicado pr_lineas.mto_aplicado%TYPE;
  v_con_iteracciones          NUMBER := 0;
  v_max_iteraciones           NUMBER := nvl(fug_obt_pardinamico('VAL_MAX_ITERA'), 5000);
  v_max_dif_permitida         NUMBER := nvl(fug_obt_pardinamico('VAL_MAX_DIFER'), 3);
  v_dif_loop                  NUMBER := 0;
  v_mod_control2     ge_par_dinamicos.val_parametro%type:= nvl(fug_obt_pardinamico('COD_MOD_CONTROL','6',p_cod_modalidad),0); -- para evitar harcode
  v_mod_control3     ge_par_dinamicos.val_parametro%type:= nvl(fug_obt_pardinamico('COD_MOD_CHE_ROGA'),'668'); -- che roga
  v_mto_min_maximizar number := NVL(fug_obt_pardinamico('MTO_MIN_MAXIMIZAR',null,v_cod_mod_default,v_mon_local, null),0);
  v_cuo_min_maximizar number := NVL(fug_obt_pardinamico('CUO_MIN_MAXIMIZAR',null,v_cod_mod_default,null, null),0);

  ------------------ rutinas internas del procedimiento-----------------------

  cursor sol_destino(p_nro_cuenta varchar2) is
    select sd.tip_des_especifico, sd.monto
      from pr_sol_destinos sd, pr_cta_prestamos cp
     where cp.nro_solicitud = sd.nro_solicitud
       and cp.nro_cuenta = p_nro_cuenta;

  cursor sol_garantia(p_nro_cuenta varchar2) is
    select nro_garantia, cod_garantia
      from pr_sol_garantias g, pr_cta_prestamos p
     where g.nro_solicitud = p.nro_solicitud
       and p.nro_cuenta = p_nro_cuenta;
   procedure pr_obt_rub_y_sec_credito_per(p_cod_persona       in  ba_personas.cod_persona%type,
                                         p_cod_rub_economico out pr_rub_economicos.cod_rub_economico%type,
                                         p_cod_sec_credito   out pr_rub_economicos.referencia%type) is
    v_rub_prim ba_personas.cod_rub_primario%type;
    v_existe   number;
  begin
    p_cod_rub_economico := null;
    p_cod_sec_credito   := null;

    begin
      select p.cod_rub_primario
        into v_rub_prim
        from ba_personas p
       where p.cod_persona = p_cod_persona;

      if v_rub_prim is not null then
        select count(1)
          into v_existe
          from pr_rub_economicos r
         where r.cod_rub_economico = v_rub_prim;

        if v_existe = 1 then
          p_cod_rub_economico := v_rub_prim;
        else
          p_cod_rub_economico := '749911';
        end if;
      else
        p_cod_rub_economico := '749911';
      end if;
    exception
      when no_data_found then
        p_cod_rub_economico := '749900';
    end;

    begin
      select r.referencia
        into p_cod_sec_credito
        from pr_rub_economicos r
       where r.cod_rub_economico = p_cod_rub_economico;
    exception
      when no_data_found then
        p_cod_sec_credito := null;
    end;

    p_cod_sec_credito := nvl(p_cod_sec_credito, 701);
  end;    
  ----
  /* ---------------------------------------------------------------------------
   NUEVO: Validación y ajuste final de consistencia cabecera vs cargos (TMP)
  --------------------------------------------------------------------------- */
   /* Recuperar TAN - Res. 012022 */
  FUNCTION fu_obt_val_tir(p_inicial   IN NUMBER,
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

  FUNCTION fu_obt_tir_ade(p_inicial   IN NUMBER,
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
  FUNCTION fu_obt_tir(P_INICIAL   IN NUMBER,
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
  FUNCTION fu_obt_tir_esp(p_inicial   IN NUMBER,
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
    -- Sexta fase. Presicion 7 decimales
    v_salir := 'N';
    v_tir   := v_valor;
    WHILE v_salir = 'N' LOOP
      v_tir_ant   := v_tir;
      v_tir       := v_tir + 0.0000001;
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
    --v_valor := v_valor * 100;
    -- New formula
    v_valor := round(((POWER(1 + v_valor, 1 / 365) - 1) * 365) * 100, 2);
    
    RETURN round(v_valor, 4);
  END;
    /* Obtener tasa efectiva. */
  FUNCTION fu_obt_tae(p_tasa IN NUMBER, p_periodo_capit IN NUMBER)
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
  
  PROCEDURE pr_obt_tas_prestamo(p_nro_solicitud IN pr_cta_prestamos.nro_solicitud%TYPE,
                                p_nro_cuenta    IN pr_cta_prestamos.nro_cuenta%TYPE,
                                p_val_tae       IN OUT NUMBER,
                                p_val_tan       IN OUT NUMBER) IS

    v_cta_recalendarizada VARCHAR2(1);
    v_tip_implementacion ge_par_generales.tip_implementacion%type := fug_obt_tip_implementacion;
    v_tot_periodo         number;
    v_num_tae             varchar2(4000);
    v_aux_tae             varchar2(4000);
    v_por_top_gsto        number;
    v_ex_tir              number(1);
    v_gastos_esp          number := 0;
    
    
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
    v_numero            CLOB;
    v_plz_numero        VARCHAR2(4000);
    v_auxiliar          CLOB;
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
             fec_vto_exacto,
             dia_periodo
        FROM pr_sol_cuo_tmp
       WHERE nro_solicitud = p_nro_solicitud
         AND p_nro_cuenta IS NULL
         AND nro_cuota > 0
      UNION ALL
      SELECT a.nro_cuota,
             nvl(a.mto_capital, 0) + nvl(a.mto_int_documentado, 0) +
             nvl(a.mto_interes, 0) val_cuota,
             nvl(a.mto_capital, 0) + nvl(a.mto_int_documentado, 0) mto_capital,
             nvl(a.mto_interes, 0) mto_interes,
             nvl(a.mto_int_documentado, 0) mto_int_documentado,
             trunc(a.fec_vencimiento - v_fec_inicio) dias,
             trunc(a.fec_vencimiento -
                   decode(a.nro_cuota,
                          1,
                          v_fec_inicio,
                          pas_bcp.fu_obt_vto_ant_cuo(a.nro_cuenta, a.nro_cuota))) dia_interes,
             trunc(a.fec_vencimiento),
             c.dia_periodo
         FROM pr_cuotas a, pr_cta_prestamos b, pr_sol_cuotas c
       WHERE a.nro_cuenta = p_nro_cuenta
         AND p_nro_solicitud IS NULL
         and b.nro_cuenta = a.nro_cuenta
         and c.nro_solicitud = b.nro_solicitud
         and c.nro_cuota = a.nro_cuota
         AND a.nro_cuota > 0
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
                   when b.cod_modalidad not in (613,648) then
                    to_number(nvl(avg(trunc(fec_vto_habil - v_fec_inicio)),
                                  0))
                   else
                    max(b.per_vto_capital)
                 end dias
            into v_dia_plazo
            FROM pr_sol_cuo_tmp a, pr_solicitudes b
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
    
    FUNCTION lf_obt_tir_des_documentos
   (
      p_inicial   IN NUMBER,
      p_can_items IN NUMBER,
      p_numeros   IN VARCHAR2
    )RETURN NUMBER IS
      v_valor     NUMBER;
      v_tir       NUMBER;
      v_tir_ant   NUMBER;
      v_resultado NUMBER;
      v_salir     VARCHAR2(1);
      pos         NUMBER(5);
      pos_hasta   NUMBER(5);
      TYPE t_vector IS TABLE OF NUMBER(24, 12) INDEX BY BINARY_INTEGER;
      mi_vector t_vector;
      mi_dias   t_vector;
      v_nro number(10,6);
      v_nro1 float;
      v_dias number:=0;
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
      ------------------
      pos := 1;
      FOR i IN 1 .. p_can_items LOOP
         pos_hasta := instr(v_dias_interes, '#', pos, 1);
         IF pos_hasta > 0 THEN
            FOR x IN 1 .. p_can_items LOOP
               pos_hasta := instr(v_dias_interes, '#', pos, 1);
               mi_dias(x) := substr(v_dias_interes, pos, pos_hasta - pos);
               pos := instr(v_dias_interes, '#', pos, 1) + 1;
            END LOOP;
            EXIT; -- Sale del ciclo si es que ya cargo todo.
         ELSE
            mi_dias(i) := v_dias_interes;
         END IF;
         pos := pos + 13;
      END LOOP;      
      ------------------
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
            v_dias := to_number(mi_dias(i));
            v_nro:=(power((1 + v_tir), v_dias));
            v_nro1 := (mi_vector(i) / (power((1 + v_tir), v_dias)));
            v_resultado := v_resultado + (mi_vector(i) / (power((1 + v_tir), v_dias)));
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
            v_dias := to_number(mi_dias(i)); 
            v_nro:=(power((1 + v_tir), v_dias));
            v_nro1 := (mi_vector(i) / (power((1 + v_tir), v_dias)));
            v_resultado := v_resultado + (mi_vector(i) / (power((1 + v_tir), v_dias)));
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
            v_dias := to_number(mi_dias(i));      
            v_nro:=(power((1 + v_tir), v_dias));
            v_nro1 := (mi_vector(i) / (power((1 + v_tir), v_dias)));
            v_resultado := v_resultado + (mi_vector(i) / (power((1 + v_tir), v_dias)));
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
            v_dias := to_number(mi_dias(i));
            v_nro:=(power((1 + v_tir), v_dias));
            v_nro1 := (mi_vector(i) / (power((1 + v_tir), v_dias)));          
            v_resultado := v_resultado + (mi_vector(i) / (power((1 + v_tir), v_dias)));
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
            v_dias := to_number(mi_dias(i));  
            v_nro:=(power((1 + v_tir), v_dias));
            v_nro1 := (mi_vector(i) / (power((1 + v_tir), v_dias)));
            v_resultado := v_resultado + (mi_vector(i) / (power((1 + v_tir), v_dias)));
         END LOOP;
         IF v_resultado <= p_inicial THEN
            v_valor := v_tir_ant;
            v_salir := 'S';
         END IF;
      END LOOP;
     -- Sexta fase. Presicion 7 decimales
      v_salir := 'N';
      v_tir   := v_valor;
      WHILE v_salir = 'N' LOOP
         v_tir_ant   := v_tir;
         v_tir       := v_tir + 0.0000001;
         v_resultado := 0;
         FOR i IN 1 .. p_can_items LOOP
            v_dias := to_number(mi_dias(i));  
            v_nro:=(power((1 + v_tir), v_dias));
            v_nro1 := (mi_vector(i) / (power((1 + v_tir), v_dias)));
            v_resultado := v_resultado + (mi_vector(i) / (power((1 + v_tir), v_dias)));
         END LOOP;
         IF v_resultado <= p_inicial THEN
            v_valor := v_tir_ant;
            v_salir := 'S';
         END IF;
      END LOOP;
      ----------------------------
      -- Calcular el valor final
      ----------------------------
      -- original
     -- v_valor := v_valor  * 100 ;
      -- nuevo
      v_valor := v_valor * 365 * 100;
      return round(v_valor, 4);
   END; --lf_obt_tir_des_documentos
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
      v_gastos_imp2       NUMBER;
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
                          round(nvl(car.mto_mon_prestamo, 0) /** 100 / -- no debe sacar el IVA Decreto N° 6225/2026
                                (100 + fug_obt_val_tasa(s.cod_modulo,
                                                        s.cod_modalidad,
                                                        s.cod_oficina,
                                                        NULL,
                                                        s.cod_moneda,
                                                        0,
                                                        'N',
                                                        NULL,
                                                        d.cod_tra_hijo,
                                                        s.fec_inicio))*/,
                                v_redondeo)))
          INTO v_gastos_imp
          FROM ge_transacciones_det d,
               ge_transacciones     t,
               pr_sol_car_tmp        car,
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
        --- Obtiene los gastos que constituyen interes para pre y mini.
        /*SELECT nvl(max(car.mto_mon_prestamo), 0)
          INTO v_gastos_imp2
          FROM pr_sol_car_tmp car
         WHERE car.nro_solicitud = p_nro_solicitud
           AND EXISTS (SELECT 1
                  FROM ge_gru_transacciones_det gt
                 WHERE gt.cod_transaccion = car.cod_transaccion
                   AND gt.cod_gru_transaccion = v_par_car_tae);*/
        --- Obtiene los gastos que no constituyen interes.
        --- Obtiene el total de gastos y a este le resta los que si constituyen interes.
        SELECT SUM(nvl(car.mto_mon_prestamo, 0)) - nvl(v_gastos_imp, 0)
          INTO v_gastos
          FROM pr_sol_car_tmp car
         WHERE car.nro_solicitud = p_nro_solicitud;
        select a.monto -- debe tomar neto Decreto N° 6225/2026
          into v_mto_solicitado
          from pr_solicitudes a
         where a.nro_solicitud = p_nro_solicitud;

      ELSE
        v_gastos         := 0;
        v_gastos_imp     := 0;
        v_mto_solicitado := 0;
      END IF;
      
      ---
      v_aux_mto_imputable   := round(v_mto_solicitado * v_por_top_gsto / 100, 0);
      /*if p_cod_modalidad = v_mod_control2 then
         p_mto_car_imputable   := nvl(v_gastos_imp2, 0);
      else*/
         p_mto_car_imputable   := nvl(v_gastos_imp, 0);
    --  end if;
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
              -- no debe sacar el IVA Decreto N° 6225/2026
             /*IF p_cod_modalidad <> v_mod_control2 then
              v_mto_lim_cargo := round((v_mto_lim_cargo / 1.1), v_redondeo);
              END IF;*/
              IF v_aux_mto_imputable < v_mto_lim_cargo THEN
                v_mto_lim_cargo := v_aux_mto_imputable;
              END IF;
              -- total del prestamo
              v_mto_desembolso := nvl(v_mto_solicitado,0) + nvl(v_gastos,0) + nvl(p_mto_car_imputable,0);
              
              if v_mto_desembolso > v_mto_lim_prestamo then
                 p_mto_car_imputable := v_gastos_imp;
              else
                if v_aux_mto_imputable < v_gastos_imp then 
                   p_mto_car_imputable := greatest(v_gastos_imp - v_aux_mto_imputable,0);
                else
                   p_mto_car_imputable := greatest(p_mto_car_imputable - v_mto_lim_cargo,0);
                end if;
              end if;
              /*IF p_mto_car_imputable > v_mto_lim_cargo THEN
                p_mto_car_imputable := p_mto_car_imputable -
                                       v_mto_lim_cargo;
              ELSE
                IF v_gastos_imp = p_mto_car_imputable or p_cod_modalidad = v_mod_control2  THEN
                  -- Quiere decir que no se vio afectado por el 15%.
                  p_mto_car_imputable := 0;
                END IF;
              END IF;*/
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
        FROM pr_sol_cuo_tmp
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
                FROM pr_sol_cuo_tmp
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
      ELSIF ((v_sal_minimo / 30) * 5) < (p_saldo * (v_por_top_gsto/100)) THEN
        v_cargo := v_cargo - ((v_sal_minimo / 30) * 5);
      ELSE
        v_cargo := v_cargo - (p_saldo * (v_por_top_gsto/100));
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
    v_por_top_gsto := nvl(to_number(fug_obt_pardinamico('POR_TOP_GAS_ADM')),25);
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
      -- agregado para che roga o cualquier modalidad de calculo especial
      if v_gastos_imp = 0 and p_cod_modalidad = v_mod_control3 then
        begin
          select round(mto_mon_prestamo / 1.1, 0)
            into v_gastos_esp
            from pr_sol_cargos car
           where car.nro_solicitud = v_nro_sol_prestamo
             and car.cod_transaccion = 704; -- gastos administrativos
        exception
          when no_data_found then
            v_gastos_esp := 0;
          when others then
            v_gastos_esp := 0;
        end;
      end if;
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
         -- v_numero     := cuo.val_cuota;
          v_numero     := TO_CLOB(TO_CHAR(cuo.val_cuota));
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
                    FROM pr_sol_cuo_tmp c, pr_solicitudes s
                   WHERE s.nro_solicitud = p_nro_solicitud
                     AND c.nro_solicitud = s.nro_solicitud
                     AND c.nro_cuota > 0;
                ELSE
                  SELECT AVG(trunc(x.fec_vencimiento -
                                   pas_bcp.fu_obt_vto_ant_cuo(x.nro_cuenta,
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
                        FROM pr_sol_cuo_tmp
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
                  if v_tip_amortizacion = 'F' then
                     v_val_inicial := nvl(v_val_inicial,0) + (cuo.mto_capital - cuo.mto_int_documentado);
                  else
                     v_val_inicial := nvl(cuo.mto_capital, 0) -
                                   (cuo.mto_interes +
                                    cuo.mto_int_documentado);
                  end if;
                end if;
              END IF;
              --v_val_inicial := cuo.mto_capital - cuo.mto_int_documentado - v_mto_gasto;
              if v_tipo = 'D' then
                  v_auxiliar := v_auxiliar || TRIM(to_char(cuo.mto_capital + cuo.mto_interes)) || '#';
                  v_numero := v_auxiliar;
                  v_auxiliar1 := v_auxiliar1 || TRIM(to_char(cuo.dia_interes))||'#';
                  v_dias_interes := v_auxiliar1;
               else 
                  v_auxiliar     := TRIM(to_char(cuo.val_cuota)) || '#';
                  v_plz_auxiliar := round(cuo.dias, 4);
                  v_numero     := v_auxiliar;
              end if;
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
              for k in 1.. cuo.dia_periodo loop
                    v_tot_periodo := nvl(v_tot_periodo,0) + 1;
                 if k = cuo.dia_periodo then
                       v_auxiliar     := v_auxiliar ||
                                TRIM(to_char(cuo.mto_capital +
                                             cuo.mto_interes +
                                             cuo.mto_int_documentado)) || '#';
                 else
                      v_auxiliar := v_auxiliar || '0' || '#';
                 end if;
              end loop;
                      v_aux_tae := v_aux_tae || TRIM(to_char(cuo.mto_capital + cuo.mto_interes +
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
                                   nvl(nullif(v_gastos_imp, 0), v_gastos_esp);
                                   --nvl(v_gastos_imp, 0);
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
            v_num_tae := v_aux_tae;
          END IF;
          --- Hace los calculos de TIR, TAN y TAE
          DECLARE
            v_tir     NUMBER;
            v_tan     NUMBER;
            v_tan_desc NUMBER;
            v_tae     NUMBER;
            v_dias1   NUMBER(4);
            v_inicial NUMBER(18, 2);
            v_numero1 CLOB;
            v_numero2 CLOB;
          BEGIN
            v_dias1   := v_dias;
            v_numero1 := v_numero;
            v_numero2 := v_plz_numero;
            v_inicial := v_val_inicial;
            IF v_inicial > 0 THEN
              IF v_tip_amortizacion = 'P' AND v_can_cuotas = cuo.nro_cuota THEN
                -- Si es tipo price en la ultima cuota calcula el tir.
                /*v_tan := round(pas_bcp.fu_obt_tir(v_inicial,
                                                  v_can_cuotas,
                                                  v_numero1),
                               4);*/
               -- v_tae := pas_bcp.fu_obt_tae(v_tan, v_dias);
                v_tan := round(pas_bcp.fu_obt_tir(v_inicial, v_tot_periodo, v_numero1),4);
                v_tae := round(pas_bcp.fu_obt_val_tir(v_inicial, v_can_cuotas, v_num_tae, v_numero2),4); 
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
                     v_tan := round(fu_obt_tir_esp(v_inicial, -- ver si corresponde
                                                          v_can_cuotas,
                                                          v_numero1,
                                                          v_numero2),
                                   4);

                  elsif v_tipo = 'D' then
                   /* v_tan := round(pas_bcp.fu_obt_tir_ade(v_inicial,
                                                          1,
                                                          v_numero1,
                                                          v_numero2),
                                   4);*/
                    if v_can_cuotas = cuo.nro_cuota then
                       v_tan:= round(lf_obt_tir_des_documentos(v_inicial, v_can_cuotas, v_numero1),4);
                    end if;
                  end if;
                end if;
                -- formula (((1+(23,77%*1/365))^(365/1))-1)
                v_tan_desc := v_tan / 100;
                v_tae := round((power((1 + (v_tan_desc * (1 / 365))), (365 / 1)) - 1) * 100, 4);
                
                --v_tae := round(pas_bcp.fu_obt_tae(v_tan, v_dias),4);
                --v_tae := round(pas_bcp.fu_obt_val_tir(v_inicial, v_can_cuotas, v_num_tae, v_numero2),4);
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
     /* IF v_tip_interes = 'A' AND v_tipo = 'D' THEN
        p_val_tan := round(v_acum_tan / v_contador, 2);
        v_dias    := lf_plz_int_adelantado(p_nro_solicitud, p_nro_cuenta);
        --p_val_tae := round(pas_bcp.fu_obt_tae(p_val_tan, v_dias),2);
        p_val_tae := round(fug_obt_tae_ade(p_val_tan, v_dias), 2);
      END IF;*/
      /*
      IF v_tip_interes = 'A' AND v_tipo = 'D' THEN
         -- Si es un descuento obtiene el tae con el promedio de dias.
         -- p_val_tae := round(pas_bcp.fu_obt_tae(p_val_tan, v_dias), 2);
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
               p_val_tan := pas_bcp.fu_obt_tan(p_val_tan, v_dias);
               if v_tip_interes = 'A' then
                 p_val_tae := pas_bcp.fu_obt_tae_ade(p_val_tan, v_dias);
               else
                 p_val_tae := pas_bcp.fu_obt_tae(p_val_tan, v_dias);
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
  
  ------------------ rutinas internas del procedimiento-----------------------
  PROCEDURE pr_val_tasa IS
    CURSOR pizarras IS
      SELECT nvl(p_tasa,a.tas_interes), nvl(p_tasa,a.tas_minima), a.tas_maxima, a.tas_efectiva
        FROM cr_piz_montos b, cr_piz_plazos a
       WHERE a.cod_modulo = v_cod_modulo
         AND a.cod_modalidad = nvl(p_cod_modalidad, v_cod_mod_default)
         AND a.cod_moneda = v_mon_local
         AND b.cod_modulo = a.cod_modulo
         AND b.cod_modalidad = a.cod_modalidad
         AND a.cod_sub_modalidad = b.cod_sub_modalidad
         AND b.cod_sub_modalidad = v_cod_sub_mod_default
         AND b.cod_moneda = a.cod_moneda
         AND b.mto_desde = a.mto_desde
         AND p_mto_solicitado BETWEEN b.mto_desde AND b.mto_hasta
         AND v_dia_plazo BETWEEN a.plz_desde AND a.plz_hasta;
  BEGIN
    v_lugar := 'obtener_tasas de pizarras';
    OPEN pizarras;
    FETCH pizarras
      INTO v_tas_interes, v_tas_minima, v_tas_maxima, v_tas_efectiva;
    CLOSE pizarras;
    IF v_val_tasa IS NULL THEN
      v_val_tasa := nvl(v_tas_interes, 32);
    ELSE
      -- valido la tasa ingresada---
      IF NOT v_val_tasa BETWEEN v_tas_minima AND v_tas_maxima THEN
        g_cod_error := '009';
        g_lugar     := 'Valida Tasa ingresada';
        g_msj_error := 'Tasa fuera de Rango. Verifique la Pizarra';
      END IF;
    END IF;
  END;
  PROCEDURE pr_val_cod_persona is
  BEGIN
    v_lugar := 'OBTENER_CLIENTE ';
    SELECT EXO_IMPUESTOS,
           COD_USU_OFICIAL,
           COD_USU_PROMOTOR,
           COD_OFICINA,
           COD_DEPARTAMENTO
      INTO v_exo_impuestos,
           v_cod_usu_oficial,
           v_cod_usu_promotor,
           v_cod_oficina,
           v_cod_departamento
      FROM BA_PERSONAS B, GE_CLIENTES G
     WHERE B.COD_PERSONA = G.COD_PERSONA
       AND G.COD_PERSONA = P_COD_PERSONA;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      BEGIN
        select gen.cod_ofi_matriz, 'N', ciu.cod_departamento
          into v_cod_oficina, v_exo_impuestos, v_cod_departamento
          from ge_par_generales gen, ba_oficinas ofi, ba_ciudades ciu
         where gen.cod_ofi_matriz = ofi.cod_oficina
           and ofi.cod_ciudad = ciu.cod_ciudad
           and ofi.cod_pais = ciu.cod_pais;
      END;
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20000, 'fu_val_cod_persona ' || sqlerrm);
  END;
  -- Validacion del tipo de credito--------------------------------------------
  PROCEDURE pr_val_cod_modalidad IS
  BEGIN
    SELECT 0
      INTO v_dummy
      FROM ge_modalidades
     WHERE cod_modulo = v_cod_modulo
       AND cod_modalidad = v_cod_mod_default;
  EXCEPTION
    WHEN no_data_found THEN
      g_cod_error := '001';
      g_lugar     := 'Valida Modalidad';
      g_msj_error := 'Tipo de Prestamo no habilitado';
    WHEN OTHERS THEN
      g_cod_error := '002';
      g_lugar     := 'Valida Modalidad';
      g_msj_error := 'Error al validar Modalidad ' || SQLERRM;
  END;

  -- Validacion del codigo de la moneda-----------------------------------------
  PROCEDURE pr_val_cod_moneda IS
  BEGIN
    SELECT 0
      INTO v_dummy
      FROM ba_monedas
     WHERE cod_moneda = v_mon_local;
  EXCEPTION
    WHEN no_data_found THEN
      g_cod_error := '003';
      g_lugar     := 'Valida Moneda';
      g_msj_error := 'Codigo de Moneda inexistente';
    WHEN OTHERS THEN
      g_cod_error := '004';
      g_lugar     := 'Valida Moneda';
      g_msj_error := 'Error al validar moneda ' || SQLERRM;
  END;

  PROCEDURE pp_val_dias_gracia IS
    v_can_meses number := 0;
  BEGIN
    If p_fec_pri_vencimiento is not null then

      v_can_meses := trunc(MONTHS_BETWEEN(p_fec_pri_vencimiento,
                                          v_fec_actual));

      If v_can_meses < v_pre_per_gracia_min then
        g_cod_error := 8;
        g_lugar     := 'Valida Dias de Gracia';
        g_msj_error := 'Periodo de gracia ' || v_can_meses ||
                       ' no debe ser menor a ' || v_pre_per_gracia_min;
      end if;
      If nvl(pap_sim.g_cod_error, '000') = '000' and
         v_can_meses > v_pre_per_gracia_max then
        g_cod_error := 8;
        g_lugar     := 'Valida Dias de Gracia';
        g_msj_error := 'Periodo de gracia ' || v_can_meses ||
                       ' no debe ser mayor a ' ||v_pre_per_gracia_max;

      end if;
    end if;
  END;
  -- Procedimiento para obtener el tipo de tasa --------------------------------
  PROCEDURE pr_obt_tipo_de_tasa(ww_cdtrans IN NUMBER,
                                ww_cddetas IN OUT NUMBER,
                                ww_aplicar IN OUT VARCHAR2,
                                ww_tpvlpor IN OUT VARCHAR2,
                                ww_tpdetas IN OUT VARCHAR2) IS
  BEGIN
    v_lugar := 'OBTENER TIPO DE TASA ';
    --- 1. Busco la tasa asociada a la transaccion ingresada ---
    IF ww_cddetas is null THEN
      SELECT tr.cod_tasa, ta.aplicar, ta.tip_valor, ta.tipo
        INTO ww_cddetas, ww_aplicar, ww_tpvlpor, ww_tpdetas
        FROM ge_transacciones tr, ge_tasas ta
       WHERE tr.cod_modulo = v_cod_modulo
         AND tr.cod_modalidad = v_cod_mod_default
         AND tr.cod_transaccion = ww_cdtrans
         AND tr.tipo = 'D'
         AND tr.cod_tasa IS NOT NULL
         AND tr.cod_tasa = ta.cod_tasa
         AND EXISTS
       (SELECT 0
                FROM ge_transacciones_det
               WHERE cod_modulo = v_cod_modulo
                 AND cod_modalidad = v_cod_mod_default
                 AND cod_transaccion = 358 /* transaccion de desembolso de prestamos */
                 AND cod_mod_hijo = tr.cod_modulo
                 AND cod_mad_hijo = tr.cod_modalidad
                 AND cod_tra_hijo = tr.cod_transaccion);
    ELSE
      SELECT ta.aplicar, ta.tip_valor, ta.tipo
        INTO ww_aplicar, ww_tpvlpor, ww_tpdetas
        FROM ge_tasas ta
       WHERE ta.cod_tasa IS NOT NULL
         AND ta.cod_tasa = ww_cddetas;
    END IF;

  EXCEPTION
    WHEN no_data_found THEN
      g_cod_error := '010';
      g_lugar     := 'Valida Cargo definido';
      g_msj_error := 'Cargo no definido para Prestamos';
    WHEN OTHERS THEN
      g_cod_error := '011';
      g_lugar     := 'Valida Cargo definido';
      g_msj_error := 'Error al obtener tipo de tasa ' || SQLERRM;
  END;

  -- Funcion que obtiene el valor de la tasa fija ------------------------------
  FUNCTION fu_obt_valor_de_tasa_fija(ww_cddetas IN NUMBER,
                                     ww_fcinici IN DATE) RETURN NUMBER IS
    ww_vldetas ge_tas_fechas.val_tasa%type;
  BEGIN
    v_lugar := 'OBTENER VALOR DE TASA FIJA ';
    -- tasa fija, buscar en tasa por fecha ---
    SELECT val_tasa
      INTO ww_vldetas
      FROM ge_tas_fechas f1
     WHERE f1.cod_tasa = ww_cddetas
       AND (f1.cod_modalidad IS NULL OR
           (f1.cod_modalidad = v_cod_mod_default))
       AND (f1.cod_modulo IS NULL OR (f1.cod_modulo = v_cod_modulo))
       AND (f1.cod_moneda IS NULL OR
           (f1.cod_moneda = v_mon_local))
       AND (f1.cod_oficina IS NULL OR (f1.cod_oficina = v_cod_oficina))
       AND f1.nro_cuenta IS NULL
       AND f1.fec_vigencia =
           (SELECT MAX(fec_vigencia)
              FROM ge_tas_fechas f2
             WHERE f1.cod_tasa = f2.cod_tasa
               AND (f2.cod_modalidad IS NULL OR
                   (f2.cod_modalidad =
                   v_cod_mod_default))
               AND (f2.cod_modulo IS NULL OR (f2.cod_modulo = v_cod_modulo))
               AND (f2.cod_moneda IS NULL OR
                   (f2.cod_moneda =
                    v_mon_local))
               AND (f2.cod_oficina IS NULL OR
                   (f2.cod_oficina = v_cod_oficina))
               AND f2.fec_vigencia <= ww_fcinici
               AND f2.nro_cuenta IS NULL);
    RETURN ww_vldetas;
  EXCEPTION
    WHEN no_data_found THEN
      RETURN NULL;
    WHEN OTHERS THEN
      g_cod_error := '012';
      g_lugar     := 'Valida Tasa Fija';
      g_msj_error := 'Error al obtener la tasa_fija ' || SQLERRM;
  END;

  -- Funcion que devuelve el valor de la tasa, si es variable ------------------
  FUNCTION fu_obt_valor_de_tasa_variable(ww_cddetas IN NUMBER,
                                         ww_vlmonto IN NUMBER,
                                         ww_fcinici IN DATE) RETURN NUMBER IS
    ww_vldetas NUMBER(15, 4);
    CURSOR tv IS
      SELECT tr.val_tasa
        FROM ge_tasas t, ge_tas_rangos tr
       WHERE t.cod_tasa = tr.cod_tasa
         AND t.cod_tasa = ww_cddetas
         AND (tr.cod_modulo = v_cod_modulo OR tr.cod_modulo IS NULL)
         AND (tr.cod_modalidad = v_cod_mod_default OR
             tr.cod_modalidad IS NULL)
         AND (tr.cod_moneda = v_mon_local OR
             tr.cod_moneda IS NULL)
         AND (tr.cod_oficina = v_cod_oficina OR tr.cod_oficina IS NULL)
         AND tr.val_hasta >= ww_vlmonto
         AND tr.nro_cuenta IS NULL
         AND tr.fec_vigencia =
             (SELECT MAX(tra.fec_vigencia)
                FROM ge_tas_rangos tra
               WHERE tra.cod_tasa = ww_cddetas
                 AND (tra.cod_modulo = v_cod_modulo OR
                     tra.cod_modulo IS NULL)
                 AND (tra.cod_modalidad =
                     v_cod_mod_default OR
                     tra.cod_modalidad IS NULL)
                 AND (tra.cod_moneda =
                     v_mon_local OR
                     tra.cod_moneda IS NULL)
                 AND (tra.cod_oficina = v_cod_oficina OR
                     tra.cod_oficina IS NULL)
                 AND tra.val_hasta >= ww_vlmonto
                 AND tra.nro_cuenta IS NULL
                 AND tra.fec_vigencia <= ww_fcinici)
       ORDER BY val_hasta;
  BEGIN
    v_lugar := 'OBTENER VALOR DE TASA VARIABLE ';
    -- tasa variable, buscar en tabla de tasas variables ---
    OPEN tv;
    FETCH tv
      INTO ww_vldetas;
    CLOSE tv;
    IF ww_vldetas IS NULL THEN
      g_cod_error := '013';
      g_lugar     := 'Valida Tasa Variable';
      g_msj_error := 'No existe Valor para la Tasa ' || to_char(ww_cddetas) ||
                     ' y el Monto ' || to_char(ww_vlmonto) || ' Fecha ' ||
                     to_char(ww_fcinici, 'DD/MM/YYYY');
    END IF;
    RETURN ww_vldetas;
  EXCEPTION
    WHEN no_data_found THEN
      RETURN NULL;
    WHEN OTHERS THEN
      g_cod_error := '005';
      g_lugar     := 'Valida Cantidad Cuotas';
      g_msj_error := 'Ingrese la cantidad de cuotas';
  END;
  -- Verificacion del codigo de tasa--------------------------------------------
  PROCEDURE pr_obt_datos_cargo(p_cod_seguro in varchar2) IS
    v_cod_Tasa        number(15);
    v_des_transaccion varchar2(35);
    v_obligatorio     varchar2(2);
    v_afecta          varchar2(5);
  BEGIN

    IF v_cod_transaccion in (737, 1271) AND v_tip_persona = 'J' and v_pre_seg_dif_juridicas = 'S' THEN
      --Traer valor de la tasa del seguro
      v_cod_Tasa := fug_obt_parentes(p_cod_seguro, 'COD_TAS_JURIDICA');
      if v_cod_tasa is not null then
        SELECT initcap(TR.DESCRIPCION),
               TA.COD_TASA,
               TA.APLICAR,
               TA.TIP_VALOR,
               TA.TIPO,
               DT.OBLIGATORIO,
               TR.AFECTA
          INTO v_des_transaccion,
               v_cod_tas_cargo,
               v_aplicar,
               v_tpvlpor,
               v_tpdetas,
               v_obligatorio,
               v_afecta
          FROM GE_TRANSACCIONES_DET DT, GE_TRANSACCIONES TR, GE_TASAS TA
         WHERE TR.COD_MODULO = v_cod_modulo
           AND TR.COD_MODALIDAD = v_cod_mod_default
           AND TR.COD_TRANSACCION = v_cod_transaccion
           AND TR.TIPO = 'D'
           AND v_cod_Tasa = TA.COD_TASA
           AND DT.COD_MODULO = v_cod_modulo
           AND DT.COD_MODALIDAD = v_cod_mod_default
           AND DT.COD_TRANSACCION = 358 /* transaccion de desembolso de prestamos */
           AND DT.COD_MOD_HIJO = TR.COD_MODULO
           AND DT.COD_MAD_HIJO = TR.COD_MODALIDAD
           AND DT.COD_TRA_HIJO = TR.COD_TRANSACCION;
      else
        g_cod_error := '030';
        g_lugar     := 'Busca datos tasa Per.Juridica';
        g_msj_error := 'No se encuentra definida la tasa para Seguro de Personas Juridicas. ' ||
                       SQLERRM;
      end if;

    ELSE
      if g_cod_error = '000' then
        -- obtengo los datos de la tasa-----------------
        pr_obt_tipo_de_tasa(v_cod_transaccion,
                            v_cod_tas_cargo,
                            v_aplicar,
                            v_tpvlpor,
                            v_tpdetas);
      END IF;
    END IF;
    --- la tasa es de tipo  valor ---
    IF v_tpdetas = 'F' THEN
      --- tipo de tasa fijo      ---
      v_val_tas_cargo := fu_obt_valor_de_tasa_fija(v_cod_tas_cargo,
                                                   v_fec_inicio);
    ELSE
      --- tipo de tasa variable  ---
      IF v_aplicar IN ('PI', 'PC', 'PT', 'PL', 'CP', 'IP', 'TP') THEN
        IF v_aplicar IN ('PI', 'PC', 'PT', 'PL') THEN
          --- El primer rango es por plazo
          v_val_tas_cargo := fu_obt_valor_de_tasa_variable(v_cod_tas_cargo,
                                                           v_dia_plazo,
                                                           v_fec_inicio);
        ELSE
          --- tipo de tasa variable  ---
          v_val_tas_cargo := fu_obt_valor_de_tasa_variable(v_cod_tas_cargo,
                                                           nvl(v_tot_prestamo,
                                                               p_mto_solicitado),
                                                           v_fec_inicio);
        END IF;
        IF v_aplicar IN ('CP', 'IP', 'TP') THEN
          -- aplicar al capital y plazo, busco ahora el valor por plazo
          v_val_tas_cargo := fu_obt_valor_de_tasa_variable(v_val_tas_cargo,
                                                           v_dia_plazo,
                                                           v_fec_inicio);

        END IF;
      ELSE
        if v_tpvlpor = 'V' then
          v_imp_cargo := fu_obt_valor_de_tasa_variable(v_cod_tas_cargo,
                                                       nvl(v_tot_prestamo,
                                                           p_mto_solicitado),
                                                       v_fec_inicio);

          v_val_tas_cargo := v_imp_cargo +
                             ROUND(v_imp_cargo * 10 / 100, v_redondeo);
        else
          v_val_tas_cargo := fu_obt_valor_de_tasa_variable(v_cod_tas_cargo,
                                                           nvl(v_tot_prestamo,
                                                               p_mto_solicitado),
                                                           v_fec_inicio);
        end if;
      END IF;

    END IF;
    IF v_tpvlpor IN ('I', 'P', 'F') OR
       v_cod_transaccion IN (735, 736, 1270, 2) THEN
      --- porcentajes  o transacciones de seguros  ---
      --v_cod_mon_cargo := v_mon_local;
      IF V_TPVLPOR = 'I' THEN
        v_cod_mon_cargo := v_mon_local;
      ELSE
        v_cod_mon_cargo := v_mon_local;
      END IF;
      --:VAL_TASA := WW_VLDETAS;

    ELSE
      --- en caso de que sean valores ----------------
      v_cod_mon_cargo := v_mon_local;
      v_val_cargo     := v_val_tas_cargo;
      v_val_tas_cargo := NULL;
    END IF;
  END;

  -- Carga de cargos de la propuesta-------------------------------------------
  PROCEDURE pr_gen_cargos(p_recalculo varchar2 default 'N') IS
    CURSOR cargos IS
      SELECT DISTINCT decode(a.cod_transaccion,
                             709,
                             1,
                             710,
                             2,
                             a.cod_transaccion) orden, -- solo para ordenamiento
                      a.cod_transaccion,
                      a.cod_ent_seguro,
                      nvl(b.obligatorio, 'N') obligator
        FROM ge_sol_cargos a, ge_transacciones_det b
       WHERE a.cod_transaccion = b.cod_tra_hijo(+)
         AND a.cod_modulo = b.cod_mod_hijo(+)
         AND a.cod_modalidad = b.cod_mad_hijo(+)
         AND a.cod_modulo = v_cod_modulo
         AND a.cod_modalidad = v_cod_mod_default
         AND ((nvl(v_exo_impuestos, 'N') = 'N') OR
             (nvl(v_exo_impuestos, 'N') = 'S' AND
             nvl(b.obligatorio, 'N') = 'N')) -- aca
         and (((v_pre_seg_dif_juridicas = 'S' and
             (cod_ent_seguro is not null and v_tip_persona != 'F' and
             cod_ent_seguro = v_pre_cod_ent_per_juridicas) or
             ( v_pre_seg_dif_juridicas = 'N' AND
             cod_ent_seguro <> v_pre_cod_ent_per_juridicas)) or
             (v_tip_persona = 'F' and
             cod_ent_seguro <> v_pre_cod_ent_per_juridicas) or cod_ent_seguro is null) or
             v_pre_seg_dif_juridicas = 'N')
       ORDER BY 1;

  BEGIN
    if p_recalculo = 'N' then
      --Add DA-7311 Maximización de tasas - CarolinaV. 04.12.2022
      DELETE FROM pr_sol_car_tmp WHERE NRO_SOLICITUD = v_nro_solicitud;
      --------------------------------------------------------
      FOR cc IN cargos LOOP
        v_cod_transaccion := cc.cod_transaccion;
        v_cod_ent_seguro  := cc.cod_ent_seguro;
        v_val_tas_cargo   := NULL;
        v_val_cargo       := NULL;
        v_cod_tas_cargo   := NULL;
        v_cod_mon_cargo   := NULL;
        pr_obt_datos_cargo(cc.cod_ent_seguro);
        IF cc.obligator = 'S' OR nvl(v_val_cargo, 0) != 0 OR
           nvl(v_val_tas_cargo, 0) != 0 THEN
          IF cc.cod_transaccion in (737, 1271) THEN
            --Calculo de seguro total simulando
            v_tas_seguro := v_val_tas_cargo;
          END IF;

          BEGIN
            if nvl(p_mto_consolidado, 0) = 0 and
               v_cod_transaccion = v_pre_tra_mto_consolidado then
              null;
            else
              INSERT INTO pr_sol_car_tmp
                (nro_solicitud,
                 cod_transaccion,
                 fec_tasa,
                 val_tasa,
                 monto,
                 cod_tasa,
                 cod_ent_seguro,
                 cod_moneda,
                 mto_mon_prestamo)
              VALUES
                (v_nro_solicitud,
                 v_cod_transaccion,
                 v_fec_inicio,
                 v_val_tas_cargo,
                 v_val_cargo,
                 v_cod_tas_cargo,
                 cc.cod_ent_seguro,
                 v_cod_mon_cargo,
                 0);
            end if;
          EXCEPTION
            WHEN OTHERS THEN
              g_cod_error := '020';
              g_lugar     := 'Inserta Cargos';
              g_msj_error := 'Error al insertar los cargos. ' || SQLERRM;
          END;
        END IF;
      END LOOP;
    else
      begin
        update pr_sol_car_tmp a
           set a.monto = a.monto + v_mto_aumento,
               a.mto_mon_prestamo = a.mto_mon_prestamo + v_mto_aumento
         where a.nro_solicitud = v_nro_solicitud
           and a.cod_transaccion = 704;
      end;
    end if;
  END;

  -- Generacion de cuotas -----------------------------------------------------
  PROCEDURE pr_gen_cuotas(ww_neto IN VARCHAR2) IS
    ww_frances         NUMBER;
    ww_tasadiv         NUMBER := v_val_tasa / 36500;
    ww_vlsalan         NUMBER(18, 2) := v_tot_prestamo;
    ww_ttcuota         NUMBER(18, 2) := NULL;
    ww_dfcuota         NUMBER(18, 2);
    ww_ttcapit         NUMBER(18, 2) := 0;
    ww_ttrefue         NUMBER(18, 2) := 0;
    ww_refreal         NUMBER(18, 2) := 0;
    ww_ctrefue         NUMBER(6) := 0;
    ww_nro             NUMBER(6) := 0;
    ww_veces           NUMBER(3) := 0;
    v_val_int_original NUMBER(18, 2) := 0;
    --
    v_fec_vto_habil     DATE;
    v_fec_vto_exacto    DATE;
    v_fec_vto_habil_ant DATE;
    v_fec_vcto          DATE;
    v_sal_cap_anterior  NUMBER(18, 2);
    v_dia_interes       NUMBER(6);
    v_val_interes       NUMBER(18, 2);
    v_ttcuota           NUMBER(18, 2);
    v_dia_periodo       NUMBER(8);
    v_mto_capital       NUMBER(18, 2);
    v_ven_fijo          VARCHAR2(1) := 'S';
    v_per_interes       NUMBER := 30;
    v_val_cuota         NUMBER;
    ww_redondeo         number(2) := 0; -- redondeo a cero para moneda local
    ww_limite           number := 10; -- limite superior para ajustes de cuotas iguales en moneda local
    v_dias              number;
    v_fec_ven_anterior  date;
    v_mto_seguro        number(18, 2) := 0;

  BEGIN
    --- Veo el tipo de redondeo de los calculos ------------------------------------------
    ww_redondeo := v_redondeo;
    If ww_redondeo != 0 then
      ww_limite := 0.05;
    else
      ww_limite := 1;
    End If;

    If v_ven_fijo is null then
      v_ven_fijo := 'S';
    End if;
    ---
    if v_per_interes = 30 and v_ven_fijo = 'S' then
      v_dias := 30.416666666666666666666666666667;
    else
      v_dias := v_per_interes;
    end if;

    LOOP
      v_fec_ven_anterior := v_fec_inicio;
      ww_veces           := NVL(ww_veces, 0) + 1;

      --- calculo del valor del metodo frances -----------------------------
      IF (power((1 + (ww_tasadiv * v_dias)), (p_can_cuotas - ww_ctrefue)) - 1) > 0 THEN
        ww_frances := round(((NVL(v_tot_prestamo, 0) - NVL(ww_ctrefue, 0)) *
                            ww_tasadiv * v_dias) /
                            (power((1 + (ww_tasadiv * v_dias)),
                                   (p_can_cuotas - ww_ctrefue)) - 1),
                            ww_redondeo);
      ELSE
        --- Para los casos en que la tasa = 0 para que no de division por cero.
        ww_frances := ((NVL(v_tot_prestamo, 0) - NVL(ww_ttrefue, 0))) /
                      ((p_can_cuotas - ww_ctrefue));
      END IF;

      ------------------------
      v_val_cuota := ROUND((ww_frances *
                           power((1 + (ww_tasadiv * v_dias)), (0))),
                           ww_redondeo) +
                     ROUND((ww_vlsalan * ww_tasadiv * (v_dias)),
                           ww_redondeo);

      if v_per_interes = 30 and (v_ven_fijo = 'S' or ww_ctrefue > 0) then
        v_val_cuota := fup_obt_val_cuota(v_cod_mod_default,
                                         v_mon_local,
                                         v_tot_prestamo - nvl(ww_ttrefue, 0),
                                         p_can_cuotas - nvl(ww_ctrefue, 0),
                                         v_val_tasa,
                                         v_fec_inicio,
                                         p_fec_pri_vencimiento);
      end if;
      ------------------------

      --- Veo el monto fijo de cuota si es de tipo Prestamos flexibles -----
      ----------------------------------------------------------------------
      v_mto_interes    := 0;
      ww_vlsalan       := V_TOT_PRESTAMO;
      ww_ttcapit       := 0;
      ww_refreal       := 0;
      v_mto_tot_seguro := 0;
      ww_nro           := 0; /* acumulador de cuotas calculadas automaticamente, sin refuerzo */

      -- borro las cuotas si existen
      DELETE FROM pr_sol_cuo_tmp WHERE nro_solicitud = v_nro_solicitud;

      FOR cuota IN 1 .. p_can_cuotas LOOP
        if cuota = 1 then
          v_fec_vto_habil  := p_fec_pri_vencimiento;
          v_fec_vto_exacto := p_fec_pri_vencimiento;
        else
          if v_per_interes / 30 = trunc(v_per_interes / 30) then
            -- Sumo 1 mes...
            If v_ven_fijo = 'S' then
              v_fec_vcto := ADD_MONTHS(p_fec_pri_vencimiento,
                                       (cuota - 1) *
                                       trunc(v_per_interes / 30));
            Else
              v_fec_vcto := p_fec_pri_vencimiento +
                            (((cuota - 1) * v_per_interes));
            End if;
            V_FEC_VTO_HABIL_ANT := v_fec_vcto;
            V_FEC_VTO_HABIL     := v_fec_vcto;
          else
            V_FEC_VTO_HABIL := p_fec_pri_vencimiento +
                               (((cuota - 1) * v_per_interes));
          end if;
          V_FEC_VTO_EXACTO := p_fec_pri_vencimiento +
                              (((cuota - 1) * v_per_interes));
        end if;
        v_dias             := V_FEC_VTO_HABIL - v_fec_ven_anterior;
        V_SAL_CAP_ANTERIOR := ww_vlsalan;
        V_DIA_PERIODO      := v_dias;
        V_DIA_INTERES      := v_dias;
        V_VAL_INTERES      := ROUND((ww_vlsalan * ww_tasadiv * v_dias),
                                    ww_redondeo);

        IF v_val_int_original > 0 THEN
          /* es una cuota con refuerzo */
          IF ww_neto = 'S' THEN
            V_MTO_CAPITAL := V_MTO_CAPITAL;
          ELSE
            V_MTO_CAPITAL := V_VAL_INT_ORIGINAL - V_VAL_INTERES;
          END IF;
          ww_refreal  := NVL(ww_refreal, 0) + NVL(V_MTO_CAPITAL, 0);
          v_val_cuota := null;
        ELSE
          ww_nro := ww_nro + 1;
          IF CUOTA = 1 AND
             ABS(v_per_interes - (p_fec_pri_vencimiento - v_fec_inicio)) > 2 THEN
            V_MTO_CAPITAL := ROUND((ww_frances *
                                   power((1 + (ww_tasadiv * v_dias)),
                                          (ww_nro - 1))),
                                   ww_redondeo);
          ELSE
            V_MTO_CAPITAL := v_val_cuota - V_VAL_INTERES;
          END IF;
        END IF;
        V_VAL_INT_ORIGINAL := NVL(V_VAL_INT_ORIGINAL, 0);
        V_TTCUOTA          := NVL(V_MTO_CAPITAL, 0) + NVL(V_VAL_INTERES, 0);
        ww_dfcuota         := NVL(ww_ttcuota, V_TTCUOTA) -
                              NVL(V_TTCUOTA, 0);
        -- ajuste de cuotas para que sean iguales solo se hace si esta dentro del limite
        IF (ABS(ww_dfcuota) BETWEEN 0.001 AND ww_limite) THEN
          V_VAL_INTERES := V_VAL_INTERES + ww_dfcuota;
          V_TTCUOTA     := V_TTCUOTA + ww_dfcuota;
        END IF;

        --Agregado para calculo de seguro por saldo de capital
        IF CUOTA = 1 then
          v_mto_seguro := ROUND(v_tot_prestamo * (v_tas_seguro / 1000) / 30 *
                                V_DIA_INTERES,
                                ww_redondeo);
        ELSE
          v_mto_seguro := ROUND(ww_vlsalan * (v_tas_seguro / 1000) / 30 *
                                V_DIA_INTERES,
                                ww_redondeo);
        END IF;

        v_mto_tot_seguro := nvl(v_mto_tot_seguro, 0) + nvl(v_mto_seguro, 0);

        ww_ttcuota         := V_TTCUOTA;
        ww_vlsalan         := NVL(ww_vlsalan, 0) - V_MTO_CAPITAL;
        ww_ttcapit         := NVL(ww_ttcapit, 0) + NVL(V_MTO_CAPITAL, 0);
        V_MTO_INTERES      := V_MTO_INTERES + NVL(V_VAL_INTERES, 0);
        v_fec_ven_anterior := V_FEC_VTO_HABIL;
        IF NVL(V_MTO_CAPITAL, 0) < 0 or NVL(V_VAL_INTERES, 0) < 0 THEN
          g_cod_error := '014';
          g_lugar     := 'Valida montos negativos';
          g_msj_error := 'Capital o Interes no puede quedar en negativo. Verifique';
        END IF;
        -- inserto el registro en la tabla de cuotas
        insert into pr_sol_cuo_tmp
          (nro_solicitud,
           nro_cuota,
           mto_capital,
           fec_vto_habil,
           fec_vto_exacto,
           val_interes,
           sal_capital,
           sal_cap_anterior,
           dia_periodo,
           dia_transcurridos,
           dia_interes,
           tip_calculo,
           val_int_original,
           val_int_adelantado)
        values
          (v_nro_solicitud,
           cuota,
           nvl(v_mto_capital, 0),
           v_fec_vto_habil,
           v_fec_vto_exacto,
           nvl(v_val_interes, 0),
           ww_vlsalan,
           ww_vlsalan + v_mto_capital,
           v_dia_periodo,
           v_dia_periodo,
           v_dia_interes,
           'V',
           v_val_int_original,
           0);

      END LOOP;

      IF abs(nvl(ww_refreal, 0) - nvl(ww_ttrefue, 0)) < 10 OR ww_veces > 12 OR
         v_tip_monto = 'N' THEN
        EXIT;
      END IF;

    END LOOP;

    ww_dfcuota := nvl(V_TOT_PRESTAMO, 0) - NVL(ww_ttcapit, 0);
    IF ww_dfcuota <> 0 THEN
      V_MTO_CAPITAL := V_MTO_CAPITAL + ww_dfcuota;
      IF NVL(V_VAL_INTERES, 0) >= ww_dfcuota and abs(ww_dfcuota) <= 1 THEN
        /* solo se ajusta si existe interes*/
        V_VAL_INTERES := NVL(V_VAL_INTERES, 0) - ww_dfcuota;
        V_MTO_INTERES := V_MTO_INTERES - ww_dfcuota;
      ELSE
        V_TTCUOTA := NVL(V_MTO_CAPITAL, 0) + NVL(V_VAL_INTERES, 0);
      END IF;
      -- Actualizo la ultima cuota
      UPDATE pr_sol_cuo_tmp
         set mto_capital = nvl(v_mto_capital, 0),
             val_interes = nvl(v_val_interes, 0)
       WHERE nro_solicitud = v_nro_solicitud
         AND nro_cuota = p_can_cuotas; -- ultima cuota
    END IF;
    -- vencimiento final del prestamo es igual al de la ult.cuota--
    UPDATE pr_solicitudes
       SET fec_vencimiento = V_FEC_VTO_HABIL, mto_interes = V_MTO_INTERES
     WHERE nro_solicitud = v_nro_solicitud;

    ---------------------------------------------------------
  EXCEPTION
    WHEN OTHERS THEN
      g_cod_error := '015';
      g_lugar     := 'Valida Genera Cuotas';
      g_msj_error := 'Error en generar cuotas. ' || SQLERRM;
  END;
  -----------------------------------------------------------
  PROCEDURE pr_gen_cuo_iguales(ww_neto IN VARCHAR2) IS
      ww_frances         NUMBER;
      ww_tasadiv         NUMBER := v_val_tasa / 36500;
      ww_vlsalan         NUMBER(18, 2) := v_tot_prestamo;
      ww_ttcuota         NUMBER(18, 2) := NULL;
      ww_dfcuota         NUMBER(18, 2);
      ww_ttcapit         NUMBER(18, 2) := 0;
      ww_ttrefue         NUMBER(18, 2) := 0;
      ww_refreal         NUMBER(18, 2) := 0;
      ww_ctrefue         NUMBER(6) := 0;
      ww_nro             NUMBER(6) := 0;
      ww_veces           NUMBER(3) := 0;
      v_val_int_original NUMBER(18, 2) := 0;
      --
      v_fec_vto_habil     DATE;
      v_fec_vto_exacto    DATE;
      v_fec_vto_habil_ant DATE;
      v_fec_vcto          DATE;
      v_sal_cap_anterior  NUMBER(18, 2);
      v_dia_interes       NUMBER(6);
      v_val_interes       NUMBER(18, 2);
      v_ttcuota           NUMBER(18, 2);
      v_dia_periodo       NUMBER(8);
      v_mto_capital       NUMBER(18, 2);
      v_ven_fijo          VARCHAR2(1) := 'S';
      v_per_interes       NUMBER := 30;
      v_val_cuota         NUMBER;
      ww_redondeo         number(2) := 0; -- redondeo a cero para moneda local
      ww_limite           number := 10; -- limite superior para ajustes de cuotas iguales en moneda local
      v_dias              number;
      v_fec_ven_anterior  date;
      v_mto_seguro        number(18,2) := 0;
      --DA-887 cuotas iguales
      v_int_per_gracia    number(18,2):= 0;
      v_dia_cal_frances   number;

    BEGIN
      --- Veo el tipo de redondeo de los calculos ------------------------------------------
      ww_redondeo := v_redondeo;

      If ww_redondeo != 0 then
        ww_limite := 0.05;
      else
        ww_limite := 1;
      End If;

      If v_ven_fijo is null then
        v_ven_fijo := 'S';
      End if;
      ---
      v_dia_cal_frances := 30.416666666666666666666666666667;
      LOOP
        v_fec_ven_anterior := v_fec_inicio;
        ww_veces           := NVL(ww_veces, 0) + 1;

        v_dias :=  p_fec_pri_Vencimiento - v_fec_inicio;

        --- calculo del valor del metodo frances -----------------------------
        IF (power((1 + (ww_tasadiv * v_dias)), (p_can_cuotas - ww_ctrefue)) - 1) > 0 THEN

          ww_frances := round((v_val_tasa/36500*v_dia_cal_frances*
                           power((1+v_val_tasa/36500*v_dia_cal_frances),(p_can_cuotas- ww_ctrefue)))
                            *(nvl(v_tot_prestamo,0)- NVL( ww_ttrefue, 0 ))/
                            ((power((1+v_val_tasa/36500*v_dia_cal_frances),(p_can_cuotas- ww_ctrefue)))-1), ww_redondeo);


        ELSE
          --- Para los casos en que la tasa = 0 para que no de division por cero.
          ww_frances := ((NVL(v_tot_prestamo, 0) - NVL(ww_ttrefue, 0))) /
                        ((p_can_cuotas - ww_ctrefue));
        END IF;

        ------------------------
        v_val_cuota := ROUND((ww_frances * power((1 + (ww_tasadiv * v_dias)), (0))),ww_redondeo) +
                       ROUND((ww_vlsalan * ww_tasadiv * (v_dias)),ww_redondeo);

        if v_per_interes = 30 and (v_ven_fijo = 'S' or ww_ctrefue > 0) then
          v_val_cuota := fup_obt_val_cuota(v_cod_mod_default,
                                           v_mon_local,
                                           v_tot_prestamo - nvl(ww_ttrefue,0),
                                           p_can_cuotas - nvl(ww_ctrefue,0),
                                           v_val_tasa,
                                           v_fec_inicio,
                                           p_fec_pri_vencimiento,
                                           v_dia_cal_frances);
        end if;
        ------------------------

        --- Veo el monto fijo de cuota si es de tipo Prestamos flexibles -----
        ----------------------------------------------------------------------
        v_mto_interes := 0;
        ww_vlsalan    := V_TOT_PRESTAMO;
        ww_ttcapit    := 0;
        ww_refreal    := 0;
        v_mto_tot_seguro := 0;
        ww_nro        := 0; /* acumulador de cuotas calculadas automaticamente, sin refuerzo */

        -- borro las cuotas si existen
        DELETE FROM pr_sol_cuo_tmp WHERE nro_solicitud = v_nro_solicitud;

        FOR cuota IN 1 .. p_can_cuotas LOOP
          if cuota = 1 then
            v_fec_vto_habil  := p_fec_pri_vencimiento;
            v_fec_vto_exacto := p_fec_pri_vencimiento;
          else
            if v_per_interes = 30 then
              -- Sumo 1 mes...
              If v_ven_fijo = 'S' then
                v_fec_vcto := ADD_MONTHS(p_fec_pri_vencimiento, (cuota - 1));
              Else
                v_fec_vcto := p_fec_pri_vencimiento +
                              (((cuota - 1) * v_dias));
              End if;
              V_FEC_VTO_HABIL_ANT := v_fec_vcto;
              V_FEC_VTO_HABIL     := v_fec_vcto;
            else
              V_FEC_VTO_HABIL := p_fec_pri_vencimiento +
                                 (((cuota - 1) * v_dias));
            end if;
            V_FEC_VTO_EXACTO := p_fec_pri_vencimiento +
                                (((cuota - 1) * v_dias));
          end if;
          V_SAL_CAP_ANTERIOR := ww_vlsalan;

          IF CUOTA = 1 AND
             ABS(to_char(last_day(p_fec_pri_vencimiento),'dd') - (p_fec_pri_vencimiento - v_fec_inicio)) > 1 THEN
            /* se hace el calculo del interes por el plazo del periodo de gracia */
            V_DIA_PERIODO := p_fec_pri_vencimiento - v_fec_inicio;
            V_DIA_INTERES := p_fec_pri_vencimiento - v_fec_inicio;
            v_int_per_gracia :=ROUND((ww_vlsalan * ww_tasadiv * (v_dias - to_char(last_day(p_fec_pri_vencimiento),'dd'))),--V_DIA_INTERES),
                                   ww_redondeo);
            v_int_per_gracia := round(v_int_per_gracia/p_can_cuotas,ww_redondeo);
             --calcula la porci??e interes solo por 30 dias
            V_VAL_INTERES := ROUND((ww_vlsalan * ww_tasadiv * to_char(last_day(p_fec_pri_vencimiento),'dd')),--V_DIA_INTERES),
                                   ww_redondeo);
            --debe sumar el v_int_per_gracia para el monto final de todas las cuotas
            v_val_cuota   := null;
          ELSE
              V_DIA_PERIODO :=  V_FEC_VTO_HABIL - v_Fec_ven_anterior;
              V_DIA_INTERES :=  V_FEC_VTO_HABIL - v_Fec_ven_anterior;
              V_VAL_INTERES := ROUND((ww_vlsalan * ww_tasadiv * V_DIA_INTERES),ww_redondeo);
          END IF;

          IF v_val_int_original > 0 THEN
            /* es una cuota con refuerzo */
            IF ww_neto = 'S' THEN
              V_MTO_CAPITAL := V_MTO_CAPITAL;
            ELSE
              V_MTO_CAPITAL := V_VAL_INT_ORIGINAL - V_VAL_INTERES;
            END IF;
            ww_refreal  := NVL(ww_refreal, 0) + NVL(V_MTO_CAPITAL, 0);
            v_val_cuota := null;
          ELSE
            ww_nro := ww_nro + 1;
            if v_val_cuota is not null and fug_obt_tip_entidad != 'F' then
              V_MTO_CAPITAL := v_val_cuota - V_VAL_INTERES;
            else
              V_MTO_CAPITAL := ww_frances - V_VAL_INTERES;
            end if;
            v_val_cuota := V_MTO_CAPITAL + V_VAL_INTERES;

             if ww_frances > V_VAL_INTERES then
               V_MTO_CAPITAL := ww_frances - V_VAL_INTERES;
             else
               V_MTO_CAPITAL :=0;
             end if;

          END IF;
          V_VAL_INT_ORIGINAL := NVL(V_VAL_INT_ORIGINAL, 0);
          V_TTCUOTA          := NVL(V_MTO_CAPITAL, 0) +
                                NVL(V_VAL_INTERES, 0);
          ww_dfcuota         := NVL(ww_ttcuota, V_TTCUOTA) -
                                NVL(V_TTCUOTA, 0);
          -- ajuste de cuotas para que sean iguales solo se hace si esta dentro del limite
          IF (ABS(ww_dfcuota) BETWEEN 0.001 AND ww_limite) THEN
            V_VAL_INTERES := V_VAL_INTERES + ww_dfcuota;
            V_TTCUOTA     := V_TTCUOTA + ww_dfcuota;
          END IF;

          --Agregado para calculo de seguro por saldo de capital
          IF CUOTA = 1 then
             v_mto_seguro :=  ROUND(v_tot_prestamo * (v_tas_seguro/1000)/30*V_DIA_INTERES,ww_redondeo);
          ELSE
             v_mto_seguro :=  ROUND(ww_vlsalan * (v_tas_seguro/1000)/30*V_DIA_INTERES,ww_redondeo);
          END IF;

          v_mto_tot_seguro := nvl(v_mto_tot_seguro,0) + nvl(v_mto_seguro,0);


          ww_ttcuota         := V_TTCUOTA;
          ww_vlsalan         := NVL(ww_vlsalan, 0) - V_MTO_CAPITAL;
          ww_ttcapit         := NVL(ww_ttcapit, 0) + NVL(V_MTO_CAPITAL, 0);
          V_MTO_INTERES      := V_MTO_INTERES + NVL(V_VAL_INTERES, 0)+nvl(v_int_per_gracia,0);
          v_fec_ven_anterior := V_FEC_VTO_HABIL;
          IF NVL(V_MTO_CAPITAL, 0) < 0 or NVL(V_VAL_INTERES, 0) < 0 THEN
            g_cod_error := '014';
            g_lugar     := 'Valida montos negativos';
            g_msj_error := 'Capital o Interes no puede quedar en negativo. Verifique';
          END IF;
          -- inserto el registro en la tabla de cuotas
          insert into pr_sol_cuo_tmp
          (nro_solicitud,
           nro_cuota,
           mto_capital,
           fec_vto_habil,
           fec_vto_exacto,
           val_interes,
           sal_capital,
           sal_cap_anterior,
           dia_periodo,
           dia_transcurridos,
           dia_interes,
           tip_calculo,
           val_int_original,
           val_int_adelantado)
        values
          (v_nro_solicitud,
           cuota,
           nvl(v_mto_capital, 0),
           v_fec_vto_habil,
           v_fec_vto_exacto,
           nvl(v_val_interes, 0) + nvl(v_int_per_gracia,0),
           ww_vlsalan,
           ww_vlsalan + v_mto_capital,
           v_dia_periodo,
           v_dia_periodo,
           v_dia_interes,
           'V',
           v_val_int_original,
           0);

        END LOOP;

        IF abs(nvl(ww_refreal, 0) - nvl(ww_ttrefue, 0)) < 10 OR
           ww_veces > 12 OR v_tip_monto = 'N' THEN
          EXIT;
        END IF;

      END LOOP;

      ww_dfcuota := nvl(V_TOT_PRESTAMO, 0) - NVL(ww_ttcapit, 0);
      IF ww_dfcuota <> 0 THEN
        IF NVL(V_VAL_INTERES, 0) >= ww_dfcuota and abs(ww_dfcuota) <= 1 THEN
          /* solo se ajusta si existe interes*/
          V_VAL_INTERES := NVL(V_VAL_INTERES, 0) - ww_dfcuota;
          V_MTO_INTERES := V_MTO_INTERES - ww_dfcuota;
        ELSE
          null;
          if ww_dfcuota < 0 then
            V_MTO_CAPITAL := V_MTO_CAPITAL + ww_dfcuota;
          else
            V_MTO_CAPITAL := V_MTO_CAPITAL + ww_dfcuota;
          end if;
          V_TTCUOTA := NVL(V_MTO_CAPITAL, 0) + NVL(V_VAL_INTERES, 0) + nvl(v_int_per_gracia,0);
        END IF;
        -- Actualizo la ultima cuota
        UPDATE pr_sol_cuo_tmp
           SET mto_capital = nvl(v_mto_capital, 0),
               val_interes = nvl(v_val_interes, 0) + nvl(v_int_per_gracia,0)
         WHERE nro_solicitud = v_nro_solicitud
           AND nro_cuota = p_can_cuotas; -- ultima cuota
      END IF;
      -- vencimiento final del prestamo es igual al de la ult.cuota--
      UPDATE pr_solicitudes
         SET fec_vencimiento = V_FEC_VTO_HABIL, mto_interes = V_MTO_INTERES
       WHERE nro_solicitud = v_nro_solicitud;

      ---------------------------------------------------------
    EXCEPTION
      WHEN OTHERS THEN
        g_cod_error := '015';
        g_lugar     := 'Valida Genera Cuotas';
        g_msj_error := 'Error en generar cuotas. ' || SQLERRM;
    END;

  FUNCTION fu_cal_mto_seguro(p_cod_tasa  IN NUMBER,
                             p_cod_ente  IN NUMBER,
                             p_monto     IN NUMBER,
                             p_val_tasa  IN NUMBER,
                             p_dia_plazo IN NUMBER,
                             p_dias      IN NUMBER,
                             p_cod_transaccion IN NUMBER) RETURN NUMBER IS
    v_mto_seguro NUMBER := 0;
    v_fac_cal_seguro NUMBER := 0;

  BEGIN
    IF fug_obt_parentes(p_cod_ente, 'COD_TAS_SEG_DESEMPLEO') = p_cod_tasa THEN
      IF p_cod_transaccion = 1270 THEN
        IF (p_dia_plazo / p_dias) < 6 THEN
          v_mto_seguro := round((((p_monto * p_val_tasa / 100) * p_can_cuotas)/12),
                            -3);
        ELSE
          v_fac_cal_seguro := v_pre_fac_pri_apl_seguros;
          v_mto_seguro := round((v_fac_cal_seguro * p_monto * p_val_tasa / 100) / 12,
                            -3);
        END IF;

      ELSE
         v_mto_seguro := round((p_monto * p_val_tasa / 100) * p_dia_plazo /
                            p_dias,
                            -3);
       END IF;
    ELSIF fug_obt_parentes(p_cod_ente, 'COD_TAS_SEG_CANCELACION') =
          p_cod_tasa THEN
      v_mto_seguro := (p_monto * p_val_tasa / 100) * p_dia_plazo / 365;

    END IF;

    RETURN v_mto_seguro;

  END;

  -- Calculo de los cargos ----------------------------------------------------
  PROCEDURE pr_cal_cargos(p_recalculo varchar2 default 'N') IS
    --ww_dfcargos       NUMBER(18, 2);
    v_mto_equivalente NUMBER(18, 2);
    v_cod_tra_ajuste  NUMBER(4);
    v_monto           NUMBER(18, 2);
    v_per_interes     NUMBER := 30;
    v_dias            NUMBER;
    v_ven_fijo        VARCHAR2(1) := 'S';
    v_jor_minimo      NUMBER(18, 2);
    v_cod_Tasa        NUMBER(18, 4);
    v_des_transaccion varchar2(35);
    v_obligatorio     varchar2(2);
    v_afecta          varchar2(5);
    v_sal_minimo      number(18, 2) := fuh_obt_sal_minimo;
    v_plazo           number;
    /*v_can_salario     number := nvl(fug_obt_pardinamico('PRE_CAN_SAL_MIN_COMISION'),
                                    5);
    v_can_jor_minimo  number := fug_obt_pardinamico('PRE_CAN_JOR_MINIMOS');
    --
    v_mto_max_gas_adm      number := fug_obt_pardinamico('MTO_MAX_COM_ADM',
                                                         null,
                                                         null,
                                                         v_mon_local,
                                                         null);
    v_mto_gas_admistrativo number;*/
    v_actualizar varchar2(1) default 'S';
    v_fac_cal_seguro NUMBER;

    CURSOR cargos IS
      SELECT cod_transaccion,
             cod_tasa,
             cod_ent_seguro,
             val_tasa,
             monto,
             cod_moneda,
             mto_mon_prestamo
        FROM pr_sol_car_tmp
       WHERE nro_solicitud = v_nro_solicitud
         FOR UPDATE OF monto
       ORDER BY decode(cod_transaccion, 709, 1, 710, 2, cod_transaccion);
  BEGIN
    --- Calculo cada uno de los cargos en la moneda del cargo y en la de la simulacion ---
    --- cero los totales de cargo de tipo valor y el total general de cargos -------------
    v_ttvalor              := 0;
    v_mto_cargo            := 0;
    v_cod_tra_ajuste       := NULL;
    /*v_mto_gas_admistrativo := pag_gen.fu_con_mon_a_moneda(v_mon_local,
                                                          v_mon_local,
                                                          fug_obt_pardinamico('MTO_TAE',
                                                                              6));*/
    FOR cc IN cargos LOOP
      v_mto_equivalente := 0;
      -- para realizar ajustes si es necesario----------
      IF v_cod_tra_ajuste IS NULL THEN
        v_cod_tra_ajuste := cc.cod_transaccion;
      END IF;
      -- obtengo los datos de la tasa-----------------
      IF cc.cod_transaccion in (737, 1271) AND v_tip_persona = 'J' and v_pre_seg_dif_juridicas = 'S' THEN
        --Traer valor de la tasa del seguro
        v_cod_Tasa := fug_obt_parentes(cc.cod_ent_seguro,
                                       'COD_TAS_JURIDICA');
        if v_cod_tasa is not null then
          SELECT initcap(TR.DESCRIPCION),
                 TA.COD_TASA,
                 TA.APLICAR,
                 TA.TIP_VALOR,
                 TA.TIPO,
                 DT.OBLIGATORIO,
                 TR.AFECTA
            INTO v_des_transaccion,
                 v_cod_tas_cargo,
                 v_aplicar,
                 v_tpvlpor,
                 v_tpdetas,
                 v_obligatorio,
                 v_afecta
            FROM GE_TRANSACCIONES_DET DT, GE_TRANSACCIONES TR, GE_TASAS TA
           WHERE TR.COD_MODULO = v_cod_modulo
             AND TR.COD_MODALIDAD = v_cod_mod_default
             AND TR.COD_TRANSACCION = cc.cod_transaccion
             AND TR.TIPO = 'D'
             AND v_cod_Tasa = TA.COD_TASA
             AND DT.COD_MODULO = v_cod_modulo
             AND DT.COD_MODALIDAD = v_cod_mod_default
             AND DT.COD_TRANSACCION = 358 /* transaccion de desembolso de prestamos */
             AND DT.COD_MOD_HIJO = TR.COD_MODULO
             AND DT.COD_MAD_HIJO = TR.COD_MODALIDAD
             AND DT.COD_TRA_HIJO = TR.COD_TRANSACCION;
        else
          g_cod_error := '030';
          g_lugar     := 'Busca datos tasa Per.Juridica';
          g_msj_error := 'No se encuentra definida la tasa para Seguro de Personas Juridicas. ' ||
                         SQLERRM;
        end if;

      ELSE
        pr_obt_tipo_de_tasa(cc.cod_transaccion,
                            cc.cod_tasa,
                            v_aplicar,
                            v_tpvlpor,
                            v_tpdetas);
      END IF;
      IF cc.cod_transaccion IS NOT NULL AND
         (cc.cod_moneda IS NULL OR
         (v_tpvlpor = 'V' AND nvl(cc.monto, 0) = 0)) THEN
        g_cod_error := '016';
        g_lugar     := 'Valida Calculo Cargos';
        g_msj_error := 'Valores nulos en Cargos. Verificar la Trans. ' ||
                       to_char(cc.cod_transaccion);
      END IF;
      IF v_tpvlpor = 'P' THEN
        v_mto_equivalente := 0;
        --- la tasa es un porcentaje-----------------------------------------------------
        IF v_aplicar IN ('CI', 'IN', 'PI', 'IP', 'PT', 'TP') THEN
          --- aplicable al interes -----------------------------------------------------
          IF cc.cod_ent_seguro IS NOT NULL and
             cc.cod_transaccion in (1270, 1271) THEN
            If v_ven_fijo is null then
              v_ven_fijo := 'S';
            End if;
            ---
            if v_per_interes = 30 and v_ven_fijo = 'S' then
              v_dias := 30.416666666666666666666666666667;
            else
              v_dias := v_per_interes;
            end if;
            if cc.cod_transaccion = 1271 then
              v_tas_seguro      := cc.val_tasa;
              v_mto_equivalente := round(v_mto_tot_seguro, v_redondeo);
            else
              v_mto_equivalente := round(fu_cal_mto_seguro(cc.cod_tasa,
                                                           cc.cod_ent_seguro,
                                                           v_mto_interes,
                                                           cc.val_tasa,
                                                           v_dia_plazo,
                                                           v_dias,
                                                           cc.cod_transaccion),
                                         v_redondeo);
            end if;
          ELSE
            v_mto_equivalente := round(v_mto_interes * cc.val_tasa / 100,
                                       v_redondeo);
          END IF;
        END IF;
        IF v_aplicar IN ('CA', 'CI', 'PC', 'CP', 'PT', 'TP') THEN
          -- puede ser un par_ente con el codigo de ente y transaccion
          IF cc.cod_ent_seguro IS NOT NULL and
             cc.cod_transaccion in (1270, 1271) THEN
            If v_ven_fijo is null then
              v_ven_fijo := 'S';
            End if;
            ---
            if v_per_interes = 30 and v_ven_fijo = 'S' then
              v_dias := 30.416666666666666666666666666667;
            else
              v_dias := v_per_interes;
            end if;
            if cc.cod_transaccion = 1271 then
              v_tas_seguro      := cc.val_tasa;
              v_mto_equivalente := round(v_mto_tot_seguro, v_redondeo);
            else
              v_mto_equivalente := round(fu_cal_mto_seguro(cc.cod_tasa,
                                                           cc.cod_ent_seguro,
                                                           v_tot_prestamo,
                                                           cc.val_tasa,
                                                           v_dia_plazo,
                                                           v_dias,
                                                           cc.cod_transaccion),
                                         v_redondeo);
            end if;
          ELSE
            --- es aplicable al capital --------------------------------------------------
            if cc.cod_transaccion = 737 then
              v_tas_seguro      := cc.val_tasa;
              v_mto_equivalente := round(v_mto_tot_seguro, v_redondeo);
            else
              v_mto_equivalente := nvl(v_mto_equivalente, 0) +
                                   round(v_tot_prestamo * cc.val_tasa / 100,
                                         v_redondeo);
            end if;
          END IF;
        END IF;

        IF v_aplicar = 'MO' THEN
          --- es aplicable al monto de la operacion -------------------------------------------
            if v_per_interes = 30 and v_ven_fijo = 'S' then
              v_dias := 30.416666666666666666666666666667;
            else
              v_dias := v_per_interes;
            end if;
          ---
          v_plazo := round((v_dia_plazo / nvl(v_dias, 30.416666666666666666666666666667)), 0);
          IF cc.cod_ent_seguro IS NOT NULL and
             cc.cod_transaccion in (1270, 1271) THEN
            If v_ven_fijo is null then
              v_ven_fijo := 'S';
            End if;

            if cc.cod_transaccion = 1271 then
              v_tas_seguro      := cc.val_tasa;
              v_mto_equivalente := round(v_mto_tot_seguro, v_redondeo);
            else
              v_imp_cargo       := 0;

               if cc.cod_transaccion = '709' then  -- 1era. modificacion DA-6139
                v_imp_cargo       := NVL(v_imp_cargo, 0) +
                          trunc(p_mto_solicitado * v_plazo *
                             cc.val_tasa / 100,
                            v_redondeo);
               else
                 IF cc.cod_transaccion = 1270 THEN
                    IF (p_can_cuotas) < 6 THEN
                      v_imp_cargo  := NVL(v_imp_cargo, 0) +
                                      ROUND(((p_mto_solicitado * p_can_cuotas *
                                      cc.val_tasa / 100) / 12),
                                      v_redondeo);
                    ELSE
                      v_fac_cal_seguro := v_pre_fac_pri_apl_seguros;
                      v_imp_cargo  := NVL(v_imp_cargo, 0) +
                                      round((v_fac_cal_seguro * p_mto_solicitado * cc.val_tasa / 100) / 12,
                                        v_redondeo);
                    END IF;
                 ELSE

                      v_imp_cargo  := NVL(v_imp_cargo, 0) +
                                      ROUND(p_mto_solicitado * v_plazo *
                                      cc.val_tasa / 100,
                                      v_redondeo);
                 END IF;
               end if;

                    v_mto_equivalente := v_imp_cargo; -- + ROUND(v_imp_cargo * 10/100,v_redondeo);

            end if;
          ELSE
            IF cc.cod_ent_seguro IS NOT NULL THEN
              IF cc.cod_transaccion = 736 THEN
                 -- CEIL redondea hacia arriba al siguiente entero PCON-544
                 v_plazo := CEIL((v_dia_plazo / nvl(v_dias, 30.416666666666666666666666666667))); 
                 v_imp_cargo       := 0;
                 v_imp_cargo       := NVL(v_imp_cargo, 0) +
                                       ROUND(p_mto_solicitado * ((v_plazo/*p_can_cuotas*/+1)/2) *
                                             cc.val_tasa / 100,
                                             v_redondeo);
                 v_mto_equivalente := v_imp_cargo;

              ELSE
                  v_imp_cargo       := 0;
                  v_imp_cargo       := NVL(v_imp_cargo, 0) +
                                       ROUND(p_mto_solicitado * v_plazo *
                                             cc.val_tasa / 100,
                                             v_redondeo);
                  v_mto_equivalente := v_imp_cargo; -- + ROUND(v_imp_cargo * 10/100,v_redondeo);
              END IF;
            ELSE
              v_imp_cargo       := 0;
              v_imp_cargo       := NVL(v_imp_cargo, 0) +
                                   ROUND(p_mto_solicitado * cc.val_tasa / 100,
                                         v_redondeo);
              v_mto_equivalente := v_imp_cargo; -- + ROUND(v_imp_cargo * 10/100,v_redondeo);
            END IF;
          END IF;
        END IF;

        IF cc.cod_transaccion in (737, 1271) THEN
          v_tas_seguro := cc.val_tasa;
        END IF;
        if cc.cod_transaccion in (1) and
           (p_mto_solicitado <= v_sal_minimo * NVL(v_can_salario, 0)) then
          v_jor_minimo := round(v_sal_minimo / 26 * v_can_jor_minimo, 0);
          if v_mto_equivalente > v_jor_minimo then
            v_imp_cargo       := 0;
            v_imp_cargo       := v_jor_minimo;
            v_mto_equivalente := v_imp_cargo;
          end if;
        elsif cc.cod_transaccion = v_pre_tra_mto_consolidado then
          v_imp_cargo       := 0;
          v_imp_cargo       := p_mto_consolidado;
          v_mto_equivalente := p_mto_consolidado; --v_imp_cargo + ROUND(v_imp_cargo * 10/100,v_redondeo);
        end if;

      ELSIF v_tpvlpor = 'I' THEN
        v_mto_equivalente := 0;
        --- la tasa es un impuesto ------------------------------------------------------
        IF v_aplicar IN ('CI', 'IN', 'PI', 'IP', 'PT', 'TP') THEN
          --- aplicable al interes -----------------------------------------------------
          IF v_dia_plazo < 365 THEN
            v_mto_equivalente := round(v_mto_interes * v_dia_plazo *
                                       cc.val_tasa / 36500,
                                       v_redondeo);
          ELSE
            v_mto_equivalente := round(v_mto_interes * cc.val_tasa / 100,
                                       v_redondeo);
          END IF;
        END IF;
        IF v_aplicar IN ('CA', 'CI', 'PC', 'CP', 'PT', 'TP') THEN
          --- es aplicable al capital --------------------------------------------------
          IF cc.cod_ent_seguro IS NOT NULL THEN
            --- es un seguro ----------------------------------------------------------
            v_mto_equivalente := nvl(v_mto_equivalente, 0) +
                                 round(v_tot_prestamo * cc.val_tasa / 100,
                                       v_redondeo);

          ELSE
            --- es un impuesto sobre el capital ---------------------------------------
            IF v_dia_plazo < 365 THEN
              v_mto_equivalente := nvl(v_mto_equivalente, 0) +
                                   round(v_tot_prestamo * v_dia_plazo *
                                         cc.val_tasa / 36500,
                                         v_redondeo);
            ELSE
              v_mto_equivalente := nvl(v_mto_equivalente, 0) +
                                   round(v_tot_prestamo * cc.val_tasa / 100,
                                         v_redondeo);
            END IF;
          END IF;
        END IF;
        if cc.cod_transaccion in (1) and
           (p_mto_solicitado <= v_sal_minimo * NVL(v_can_salario, 0)) then
          v_jor_minimo := round(v_sal_minimo / 26 * v_can_jor_minimo, 0);
          if v_mto_equivalente > v_jor_minimo then
            v_mto_equivalente := v_jor_minimo;
          end if;
        elsif cc.cod_transaccion = v_pre_tra_mto_consolidado then
          v_imp_cargo       := 0;
          v_imp_cargo       := p_mto_consolidado;
          v_mto_equivalente := p_mto_consolidado; --v_imp_cargo + ROUND(v_imp_cargo * 10/100,v_redondeo);
        end if;
      ELSIF v_tpvlpor = 'V' THEN
        --- es un monto valor -----------------------------------------------------------

        v_mto_equivalente := cc.monto;

        if cc.cod_transaccion in (1) and
           (p_mto_solicitado <= v_sal_minimo * NVL(v_can_salario, 0)) then
          v_jor_minimo := round(v_sal_minimo / 26 * v_can_jor_minimo, 0);
          if v_mto_equivalente > v_jor_minimo then
            v_mto_equivalente := v_jor_minimo;
          end if;
        elsif cc.cod_transaccion = v_pre_tra_mto_consolidado then
          v_imp_cargo       := 0;
          v_imp_cargo       := p_mto_consolidado;
          v_mto_equivalente := p_mto_consolidado; --v_imp_cargo + ROUND(v_imp_cargo * 10/100,v_redondeo);
        end if;

        v_ttvalor := nvl(v_ttvalor, 0) + nvl(v_mto_equivalente, 0);

      ELSIF v_tpvlpor = 'T' THEN
        v_plazo         := round((v_dia_plazo / 30), 0);
        v_val_tas_cargo := fu_obt_valor_de_tasa_variable(cc.cod_tasa,
                                                         p_mto_solicitado,
                                                         v_fec_inicio);
        --Volvemos a obtener el tipo de tasa
        pr_obt_tipo_de_tasa(cc.cod_transaccion,
                            v_val_tas_cargo,
                            v_aplicar,
                            v_tpvlpor,
                            v_tpdetas);
        IF v_tpvlpor = 'P' THEN
          v_val_tas_cargo   := fu_obt_valor_de_tasa_variable(v_val_tas_cargo,
                                                             v_plazo,
                                                             v_fec_inicio);
          v_mto_equivalente := nvl(v_mto_equivalente, 0) +
                               round(nvl(p_mto_solicitado,v_tot_prestamo) * v_val_tas_cargo / 100,
                                     v_redondeo);
        ELSIF v_tpvlpor = 'V' THEN
          v_val_tas_cargo   := fu_obt_valor_de_tasa_variable(v_val_tas_cargo,
                                                             v_plazo,
                                                             v_fec_inicio);
          v_mto_equivalente := nvl(v_mto_equivalente, 0) + v_val_tas_cargo;
        END IF;
        --
        IF v_mto_max_gas_adm > 0 THEN
          IF nvl(v_tot_prestamo, p_mto_solicitado) <=
             v_mto_gas_admistrativo THEN
            IF v_mto_equivalente > v_mto_max_gas_adm THEN
              v_mto_equivalente := v_mto_max_gas_adm;
            END IF;
          END IF;
        END IF;
        if p_recalculo = 'S' and cc.cod_transaccion = '704' then
          v_actualizar := 'N';
          begin
            select a.monto - v_mto_aumento
              into v_mto_adm_anterior
              from pr_sol_car_tmp a
             where a.nro_solicitud = v_nro_solicitud
               and a.cod_transaccion = 704;
          exception
            when no_data_found then
              v_mto_adm_anterior := v_mto_equivalente;
          end;
        end if;
        --
      END IF;
      if cc.cod_transaccion = v_pre_tra_mto_consolidado then
        v_imp_cargo       := 0;
        v_imp_cargo       := p_mto_consolidado;
        v_mto_equivalente := p_mto_consolidado; --v_imp_cargo + ROUND(v_imp_cargo * 10/100,v_redondeo);
      end if;

      if cc.cod_transaccion = v_pre_tra_mto_consolidado then
        v_monto := p_mto_consolidado;
      else
        v_monto := NULL;
        --- Acumular el total de cargos (Si el tipo es Valor viene directamente aqui -------
        v_mto_cargo := nvl(v_mto_cargo, 0) + nvl(v_mto_equivalente, 0);
        ------------------------------------------------------------------------------------
      end if;

      IF v_tpvlpor IN ('I', 'P') THEN
        /* solo si es porcentaje */
        IF cc.cod_moneda = v_mon_local THEN
          -- moneda del cargo es igual a la moneda de la simulacion ----------------------
          v_monto := v_mto_equivalente;
        ELSE
          -- monedas diferentes, se divide por la cotiz. de la moneda de la simulacion ---
          v_monto := round(v_mto_equivalente * v_cotizacion, v_redondeo);
        END IF;
      END IF;
      if nvl(v_actualizar,'S') = 'S' then
        UPDATE pr_sol_car_tmp
           SET mto_mon_prestamo = nvl(v_mto_equivalente, 0),
               monto            = nvl(v_monto, monto)
       WHERE CURRENT OF cargos;
      end if;
    END LOOP;
    IF v_mto_cargo >= v_tot_prestamo THEN
      g_cod_error := '017';
      g_lugar     := 'Valida Sumatoria de Cargos';
      g_msj_error := 'Total de Cargos ' || v_mto_cargo ||
                     ' es superior al Total del Prestamo ' ||
                     v_tot_prestamo;
    ELSE
      IF v_tip_monto = 'N' AND v_tot_prestamo <> p_mto_solicitado THEN
        --- ya estoy en el ultimo calculo de cargos netos, veo si hay ajuste --------
        null;
      END IF;
    END IF;
    begin
      select nvl(sum(a.monto),0)
        into v_mto_cargo
        from pr_sol_car_tmp a
       where a.nro_solicitud = v_nro_solicitud;
    end;
    -- actualizo el total de cargos de  la solicitud
    UPDATE pr_solicitudes
       SET mto_cargo = v_mto_cargo
     WHERE nro_solicitud = v_nro_solicitud;
  EXCEPTION
    WHEN OTHERS THEN
      g_cod_error := '018';
      g_lugar     := 'Valida Calculo Cargos';
      g_msj_error := 'Error al calcular cargos ' || SQLERRM;
  END;

  ------------------------ Elimna solicitud en Pendiente de Liquidación ----------------
  PROCEDURE pr_eli_solicitudes IS
    v_elimina varchar2(1) := 'N';
  BEGIN
    BEGIN
      SELECT 'S'
        INTO v_elimina
        FROM pr_solicitudes s
       WHERE s.nro_solicitud = nvl(p_solicitud, v_nro_solicitud)
         AND s.estado = 'L';
    EXCEPTION
      WHEN no_data_found THEN
        v_elimina := 'N';
    END;
    IF nvl(v_elimina, 'N') = 'S' THEN
      DELETE FROM pr_sol_tasas WHERE nro_solicitud = nvl(p_solicitud, v_nro_solicitud);
      DELETE FROM Pr_Sol_Garantias WHERE nro_solicitud = nvl(p_solicitud, v_nro_solicitud);
      DELETE FROM pr_sol_destinos WHERE nro_solicitud = nvl(p_solicitud, v_nro_solicitud);
      DELETE FROM pr_sol_cargos WHERE nro_solicitud = nvl(p_solicitud, v_nro_solicitud);
      DELETE FROM pr_sol_cuotas WHERE nro_solicitud = nvl(p_solicitud, v_nro_solicitud);
      DELETE FROM pr_solicitudes WHERE nro_solicitud = nvl(p_solicitud, v_nro_solicitud);
      DELETE FROM ba_tab_dat_adicionales
       WHERE tab_relacion = 'PR_SOLICITUDES'
         and parametro = 'CLA_PRE_APROBADO'
         AND referencia = nvl(p_solicitud, v_nro_solicitud);
     /* update it.pr_pre_aprobados a
           set a.nro_solicitud = null
       where a.cod_persona = p_cod_persona
          and a.nro_solicitud = nvl(p_solicitud, v_nro_solicitud)
          and a.estado in ('G');*/
    ELSE
      g_cod_error := '020';
      g_lugar     := 'Verifica Estado de Solicitud.';
      g_msj_error := 'Solicitud ' || nvl(p_solicitud, v_nro_solicitud) ||
                     ' no puede ser elimnado ' || SQLERRM;
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      g_cod_error := '019';
      g_lugar     := 'Elimina Solicitud ' || nvl(p_solicitud, v_nro_solicitud);
      g_msj_error := 'Error al eliminar solicitudes ' || SQLERRM;
  END;
  ---------Proceso que almacena dato adicional ----------------------------------------
  PROCEDURE pr_ins_clave IS
  BEGIN
    insert into ba_tab_dat_adicionales
      (tab_relacion, referencia, parametro, val_parametro)
    values
      ('PR_SOLICITUDES', v_nro_solicitud, 'CLA_PRE_APROBADO', p_clave);

  EXCEPTION
    WHEN OTHERS THEN
      g_cod_error := '021';
      g_lugar     := 'Inserta Datos Adicionales ' || v_nro_solicitud;
      g_msj_error := 'Error al insertar datos adicionales ' || SQLERRM;
  END;
  ------- Funcion que retorna el monto de la cuota -----------------------
  FUNCTION fu_obt_mto_cuota(p_nro_sol in pr_solicitudes.nro_solicitud%TYPE)
    return number is
    v_cuo_sol number;
  BEGIN
    SELECT (sc.mto_capital + sc.val_interes)
      INTO v_cuo_sol
      FROM pr_sol_cuo_tmp sc
     WHERE sc.nro_solicitud = p_nro_sol
       AND sc.nro_cuota = 1;
    RETURN v_cuo_sol;
  EXCEPTION
    WHEN OTHERS THEN
      g_cod_error := '033';
      g_lugar     := 'Obtiene Cuota ';
      g_msj_error := 'Error al buscar cuota de la solicitud ' || SQLERRM;
  END;

 procedure pr_cal_dif_montos (p_nro_sol in pr_solicitudes.nro_solicitud%TYPE)
   is

   v_tot_prestamo         pr_solicitudes.tot_prestamo%type;
   v_tot_cuota_solicitud  pr_sol_cuotas.mto_capital%type;
   v_mon_ajuste           pr_solicitudes.monto%type;
   v_nro_cuota            pr_sol_cuotas.nro_cuota%type;

 BEGIN
   BEGIN
     Select tot_prestamo
      into  v_tot_prestamo
      from pr_solicitudes p
      where p.nro_solicitud = p_nro_sol;
   EXCEPTION
     when others then
      g_cod_error := '110';
      g_lugar     := 'Total prestamo ';
      g_msj_error := 'Error consultar solicitudes' || SQLERRM;

   END;

   BEGIN

     Select sum(dp.mto_capital)
      into v_tot_cuota_solicitud
      from pr_sol_cuo_tmp dp
      where dp.nro_solicitud = p_nro_sol;

   EXCEPTION
    WHEN OTHERS THEN
      g_cod_error := '111';
      g_lugar     := 'Total prestamo ';
      g_msj_error := 'Error consultar sol_cuotas' || SQLERRM;
   END;

   /* Verificamos el total de las cuotas en contra partida con el total de la
      Solicitud */

   if abs(v_tot_prestamo - v_tot_cuota_solicitud) <= v_max_dif_permitida then -- between 1 and 2  then

    v_mon_ajuste := (v_tot_prestamo - v_tot_cuota_solicitud);


    begin
    Select max(nro_cuota)
       into v_nro_cuota
     from pr_sol_cuo_tmp
     where nro_solicitud = p_nro_sol;
    exception
      when others then
      g_cod_error := '112';
      g_lugar     := 'Total prestamo ';
      g_msj_error := 'Error consultar' || SQLERRM;
    end;

    begin
    --ajustamos la ultima cuota
    Update pr_sol_cuo_tmp a
       set a.mto_capital = a.mto_capital + v_mon_ajuste
     where a.nro_solicitud = p_nro_sol
       and a.nro_cuota = v_nro_cuota;
    exception
      when others then
      g_cod_error := '113';
      g_lugar     := 'Error a actualizar la ultima cuota ';
      g_msj_error := 'Error al actualizar la ultima cuota ' || SQLERRM;
    end;

   end if;




 EXCEPTION
    WHEN OTHERS THEN
      g_cod_error := '033';
      g_lugar     := 'Obtiene Cuota ';
      g_msj_error := 'Error al buscar cuota de la solicitud ' || SQLERRM;
 END;
 -- obtiene sub-modalidad
  function fu_obt_cod_submodalidad(p_cod_modulo    in ge_modalidades.cod_modulo%type,
                                      p_cod_modalidad in ge_modalidades.cod_modalidad%type,
                                      p_cod_submodalidad in ge_sub_modalidades.cod_sub_modalidad%type)
    return varchar2 is
    v_cod_sub_modalidad ge_sub_modalidades.cod_sub_modalidad%type;

  begin
    select cod_sub_modalidad
      into v_cod_sub_modalidad
      from ge_sub_modalidades
     where cod_modulo = p_cod_modulo
     and cod_sub_modalidad = p_cod_submodalidad
       and cod_modalidad = p_cod_modalidad;
    return v_cod_sub_modalidad;
  exception
    when too_many_rows then
      select min(cod_sub_modalidad)
        into v_cod_sub_modalidad
        from ge_sub_modalidades
       where cod_modulo = p_cod_modulo
         and cod_modalidad = p_cod_modalidad;
      return v_cod_sub_modalidad;
    when no_data_found then
      return 1;
    when others then
      return 1;
  end;

  FUNCTION FU_PASAR_A_MONEDA
     (p_cod_moneda IN VARCHAR2, p_importe IN NUMBER, p_mon_destino IN VARCHAR2)
  RETURN NUMBER IS
  BEGIN
    return (pag_gen.FU_CON_MON_A_MONEDA(p_cod_moneda, p_mon_destino, p_importe));
  END;
  
  procedure pr_ins_cargos_tmp(p_nro_sol in pr_solicitudes.nro_solicitud%type) is
  begin
    insert into pr_sol_cargos c
      (c.nro_solicitud,
       c.cod_transaccion,
       c.fec_tasa,
       c.val_tasa,
       c.monto,
       c.cod_tasa,
       c.cod_ent_seguro,
       c.cod_moneda,
       c.mto_mon_prestamo)
      (select * from pr_sol_car_tmp where nro_solicitud = p_nro_sol);
  exception
    when others then
      g_cod_error := '021';
      g_lugar     := 'Inserta cargos de la temporal ' || v_nro_solicitud;
      g_msj_error := 'Error al insertar cargos ' || sqlerrm;
  end;
  
  procedure pr_ins_cuotas_tmp(p_nro_sol in pr_solicitudes.nro_solicitud%type) is
  begin
    insert into pr_sol_cuotas cc
      (cc.nro_solicitud,
       cc.nro_cuota,
       cc.mto_capital,
       cc.fec_vto_habil,
       cc.fec_vto_exacto,
       cc.val_interes,
       cc.sal_capital,
       cc.sal_cap_anterior,
       cc.dia_periodo,
       cc.dia_transcurridos,
       cc.dia_interes,
       cc.tip_calculo,
       cc.val_int_original,
       cc.val_int_adelantado,
       cc.val_iva_interes,
       cc.val_seguro)
      (select * from pr_sol_cuo_tmp where nro_solicitud = p_nro_sol);
  exception
    when others then
      g_cod_error := '021';
      g_lugar     := 'Inserta cuotas de la temporal ' || v_nro_solicitud;
      g_msj_error := 'Error al insertar cuotas ' || sqlerrm;
  end;
BEGIN
  BEGIN
    pre_ini_aplicacion;
  END;
  -- Se replica mini prestamo. 
  -- No maximizar cargos para condiciones especificas: montos < 500k y cuota = 1
  if p_mto_solicitado < v_mto_min_maximizar and p_can_cuotas = v_cuo_min_maximizar then
     v_mad_val_tae_gas_adm := 0;
  end if;
  v_cod_sub_mod_default := fu_obt_cod_submodalidad(6,p_cod_modalidad,p_cod_submodalidad);  --fug_obt_pardinamico('PRE_SUBMAD_PRE_APROBADOS');
  pre_cam_for_numerico(',.');
  v_valor_aum := nvl(fug_obt_pardinamico('VAL_INI_AUMTASA', null, null, p_cod_moneda, null ),0) ;
  g_msj_error := 'PROCESO CONCLUIDO CON EXITO';
  g_cod_error := '000';
  --- Veo el tipo de redondeo de los calculos ------------------------------------------
  v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                                    6,
                                    v_cod_mod_default,
                                    v_mon_local);

  v_pre_tra_mto_consolidado :=   nvl(fug_obt_pardinamico('PRE_TRA_MTO_CONSOLIDADO',
                                     v_cod_modulo,
                                     v_cod_mod_default,
                                     v_mon_local,
                                     null),
                                   0);
  ------ Verificamos si no tiene solicitud en la nebulosa------------------------------
  /*IF p_solicitud is null THEN
    BEGIN
      SELECT a.nro_solicitud
        INTO v_nro_solicitud
        FROM pr_pre_aprobados a
       WHERE a.cod_persona = p_cod_persona
         AND a.cod_modalidad = nvl(v_cod_mod_default, p_cod_modalidad)
         AND a.estado in ('C', 'G')
         AND a.nro_solicitud is not null;
    EXCEPTION
      WHEN no_data_found THEN
        v_nro_solicitud := null;
      WHEN too_many_rows THEN
        SELECT max(a.nro_solicitud)
          INTO v_nro_solicitud
          FROM pr_pre_aprobados a
         WHERE a.cod_persona = p_cod_persona
           AND a.cod_modalidad = nvl(v_cod_mod_default, p_cod_modalidad)
           AND a.estado in ('C', 'G')
           AND a.nro_solicitud is not null;
      WHEN OTHERS THEN
        v_nro_solicitud := null;
    END;
  END IF;*/
  ------ Verificamos si no tiene solicitud Pendiente de liquidacion ------------------------------ rodrigo
  -- PCON-337 sacamos esta logica por error 422 desde servicio
 /* if p_solicitud is null then
    begin
      select a.nro_solicitud
        into v_nro_solicitud
        from pr_solicitudes a
       where a.cod_persona = p_cod_persona
         and a.cod_modalidad = nvl(v_cod_mod_default, p_cod_modalidad)
         and a.estado in ('L');
    exception
      when no_data_found then
        v_nro_solicitud := null;
      when too_many_rows then
        select max(a.nro_solicitud)
          into v_nro_solicitud
          from pr_solicitudes a
         where a.cod_persona = p_cod_persona
           and a.cod_modalidad = nvl(v_cod_mod_default, p_cod_modalidad)
           and a.estado in ('L');
      when others then
        v_nro_solicitud := null;
    end;
  end if;
  -- eliminamos la solicitud del cliente -------------------------------------------
  IF nvl(g_cod_error, '000') = '000' THEN
    IF nvl(p_solicitud, v_nro_solicitud) is not null THEN
      pr_eli_solicitudes;
    END IF;
  END IF;*/
   --------------------Control cuenta con oferta de tarjeta vigente---------------------
 /* IF nvl(g_cod_error, '000') = '000' THEN
       BEGIN
             Select 'S'
               into v_existe_tc
               from ta_lin_pre_aprobado t
              where t.estado = 'A'
                and t.cod_persona = p_cod_persona;
           EXCEPTION
             WHEN no_data_found THEN
               v_existe_tc := 'N';
             WHEN OTHERS THEN
               g_cod_error := '011';
               g_lugar     := 'Consulta estado Tarjeta';
               g_msj_error := 'Error al consultar estado tarjeta ' || SQLERRM;
           END;

           if nvl(v_existe_tc, 'N') = 'S' then
                   g_cod_error := '013';
                   g_lugar     := 'Persona posee una Linea de credito activa';
                   g_msj_error := 'Persona posee una Linea de credito activa ';

             UPDATE pr_pre_aprobados pp
                SET pp.estado = 'V', pp.fec_fin_oferta = trunc(sysdate)
              WHERE pp.cod_persona = p_cod_persona
                and pp.estado in ('C', 'G');

            end if;
END IF;*/
  -- valido el código del cliente-------------------------------------------
  if g_cod_error = '000' then
    PR_VAL_COD_PERSONA;
  end if;
  -- Valido el codigo de la modalidad que recibo----------------------------
  if g_cod_error = '000' then
    pr_val_cod_modalidad;
  end if;

  -- valido la moneda-------------------------------------------------------
  if g_cod_error = '000' then
    pr_val_cod_moneda;
  end if;

  -- valido el monto -------------------------------------------------------
  IF g_cod_error = '000' and nvl(p_mto_solicitado, 0) <= 0 THEN
    g_cod_error := '005';
    g_lugar     := 'Valida Monto Ingresado';
    g_msj_error := 'Ingrese Monto del Credito';
  END IF;

  v_tot_prestamo := p_mto_solicitado;

  -- valido el tipo de monto -----------------------------------------------
  IF g_cod_error = '000' and
     nvl(v_tip_monto, 'X') NOT IN ('B', 'N') THEN
    g_cod_error := '006';
    g_lugar     := 'Valida Tipo Monto';
    g_msj_error := 'Tipo de Monto debe ser B-Bruto o N-Neto';
  END IF;

  -- valido la cantidad de cuotas ------------------------------------------
  IF g_cod_error = '000' and nvl(p_can_cuotas, 0) < 1 THEN
    g_cod_error := '007';
    g_lugar     := 'Valida Cantidad Cuotas';
    g_msj_error := 'Ingrese la cantidad de cuotas';
  END IF;
  ----desde aqui

  V_CAN_DIA_PRI_VCTO     := fug_obt_pardinamico('CAN_DIA_PRI_VCTO',
                                                6,
                                                v_cod_mod_default,
                                                v_mon_local,
                                                v_cod_oficina);
  v_can_dia_min_pri_vcto := fug_obt_pardinamico('CAN_DIA_MIN_PRI_VENCIMIENTO',
                                                6,
                                                v_cod_mod_default,
                                                v_mon_local,
                                                v_cod_oficina);
  if v_can_dia_min_pri_vcto is null then
    v_can_dia_min_pri_vcto := 15;
  end if;
  ---
  IF g_cod_error = '000' and p_fec_pri_vencimiento IS NULL THEN
    g_cod_error := '008';
    g_lugar     := 'Valida Primer vencimiento';
    g_msj_error := 'Ingrese Primer Vencimiento del Prestamo.';
  END IF;
  -- Valido la fecha del primer vencimiento --------------------------------
  IF g_cod_error = '000' and
     p_fec_pri_vencimiento <= v_fec_actual AND
     v_cod_mod_default <> 660 THEN
    g_cod_error := '009';
    g_lugar     := 'Valida Primer vencimiento';
    g_msj_error := 'Primer Vencimiento debe ser posterior a la fecha de Hoy';
  END IF;

  -- Controla los dias del primer vencimiento...
  IF g_cod_error = '000' and
     ((p_fec_pri_vencimiento - v_fec_actual) > v_can_dia_pri_vcto) THEN
    g_cod_error := '010';
    g_lugar     := 'Valida Primer vencimiento';
    g_msj_error := 'Primer Vencimiento no debe ser posterior a los ' ||
                   v_can_dia_pri_vcto || ' dias.';
  END IF;

  -- Controla los dias del primer vencimiento...
  IF g_cod_error = '000' and
     ((p_fec_pri_vencimiento - v_fec_actual) < v_can_dia_min_pri_vcto) THEN
    g_cod_error := '010';
    g_lugar     := 'Valida Primer Vencimiento';
    g_msj_error := 'Primer Vencimiento no debe ser menor a los ' ||
                   v_can_dia_min_pri_vcto || ' dias.';
  END IF;

  IF g_cod_error = '000' and v_pre_mod_afd = 'S' then
    pp_val_dias_gracia;
  end if;

  -- valido el tipo de persona  --------------------------------------------
  BEGIN
    SELECT pe.tipo
      INTO v_tip_persona
      FROM ba_personas pe
     WHERE pe.cod_persona = p_cod_persona;
  EXCEPTION
    WHEN no_data_found THEN
      v_tip_persona := null;
  END;
  --------------------------------------------------------------------------
  IF g_cod_error = '000' and v_tip_persona is null THEN
    g_cod_error := '009';
    g_lugar     := 'Valida Tipo Persona';
    g_msj_error := 'Ingrese el tipo de persona';
  END IF;
  -- valido el tipo de persona  --------------------------------------------
  IF g_cod_error = '000' and v_tip_persona is not null and
     v_tip_persona not in ('F', 'J') THEN
    g_cod_error := '010';
    g_lugar     := 'Valida Tipo Persona';
    g_msj_error := 'Valor incorrecto. (Tipo F-Fisica/ J-Juridica)';
  END IF;

  v_dia_plazo   := add_months(p_fec_pri_vencimiento, p_can_cuotas - 1) -
                   v_fec_inicio;
  v_per_gracia  := v_fec_pri_vencimiento - v_fec_inicio;
  v_per_capital := 30;

  -- Valido la tasa de interes -----------DA-7311------
  IF g_cod_error = '000' and nvl(v_max_tasa,'N') <> 'S' then
    pr_val_tasa;
  end if;
  v_nro_solicitud := null;
  ----------- Obtendremos la Linea de Crédito para asociar a la solicitud ------------------
  IF nvl(fug_obt_pardinamico('PRE_VER_MAD_LIN_PER', 6, p_cod_modalidad), 'N') = 'S' THEN
      BEGIN
        SELECT MAX(nro_linea)
          INTO v_nro_linea
           FROM pr_lineas
          WHERE cod_persona = p_cod_persona
            AND estado = 'A';
      EXCEPTION
        WHEN no_data_found THEN
          g_cod_error := '089';
          g_lugar     := 'Valida Linea de la Persona';
          g_msj_error := 'Linea no encontrada para la persona '||p_cod_persona||'. Modalidad '||p_cod_modalidad||' obligatoria para Linea.';
      END;
     ------ Verificamos si no tiene solicitud Pendiente de liquidacion ------------------------------
      if p_solicitud is null then
        begin
          select a.nro_solicitud, a.mto_lin_aplicado
            into v_nro_solicitud, v_mto_lin_aplicado
            from pr_solicitudes a
           where a.cod_persona = p_cod_persona
             and a.cod_modalidad = nvl(v_cod_mod_default, p_cod_modalidad)
             and a.estado in ('L');
        exception
          when no_data_found then
            v_nro_solicitud := null;
          when too_many_rows then
            select a.nro_solicitud, a.mto_lin_aplicado
              into v_nro_solicitud, v_mto_lin_aplicado
              from pr_solicitudes a
             where a.cod_persona = p_cod_persona
               and a.cod_modalidad = nvl(v_cod_mod_default, p_cod_modalidad)
               and a.estado in ('L')
                order by a.nro_solicitud desc
                fetch first 1 row only;
          when others then
            v_nro_solicitud := null;
        end;
      end if;
      -- eliminamos la solicitud del cliente -------------------------------------------
      IF nvl(g_cod_error, '000') = '000' THEN
        IF nvl(p_solicitud, v_nro_solicitud) is not null THEN
          pr_eli_solicitudes;
          pap_gar.PR_ACT_MAD_LIMITE(v_nro_linea, 1, (v_mto_lin_aplicado * -1), 6, p_cod_modalidad);
          pap_gar.PR_ACT_TIP_LIMITE(v_nro_linea, 1, (v_mto_lin_aplicado * -1));
          pap_gar.PR_ACT_LIN_APLICADO(v_nro_linea, (v_mto_lin_aplicado * -1)); 
        END IF;
      END IF;
      ----Obtenemos los datos de la Linea
      BEGIN
        SELECT LIN.COD_MONEDA, LIN.MONTO, LIN.MONTO-NVL(LIN.MTO_APLICADO,0) sal_linea, MAD.MTO_LIMITE-NVL(MAD.MTO_APLICADO,0) sal_lin_mad, LIN.FEC_VENCIMIENTO,
                CASE
                   WHEN MAD.Cod_Modalidad = p_cod_modalidad THEN
                     'S'
                   ELSE
                     'N'
                   END ind_mad_par
          INTO v_cod_mon_linea, v_mto_linea, v_sal_linea, v_sal_lin_mad, v_fec_vto_lin, v_ind_lin_mad
           FROM PR_LIN_TIP_GAR_MAD MAD,
                PR_LIN_TIP_GARANTIAS PLI,
                PR_LINEAS LIN
          WHERE LIN.NRO_LINEA = v_nro_linea
            AND LIN.NRO_LINEA = PLI.NRO_LINEA
            AND LIN.ESTADO = 'A'
            AND PLI.NRO_LINEA  = MAD.NRO_LINEA(+)
            AND PLI.COD_GARANTIA = MAD.COD_GARANTIA(+)
            and (mad.cod_modalidad(+) is not null and
                 mad.cod_modalidad(+) = p_cod_modalidad)
            and mad.cod_modulo(+) = 6;
      EXCEPTION
        WHEN no_data_found THEN
            g_cod_error := '090';
            g_lugar     := 'Valida datos de la Linea';
            g_msj_error := 'Linea no encontrada '||v_nro_linea||'. Modalidad '||p_cod_modalidad||' obligatoria para Linea.';
      END;
      -----hacemos las validaciones de la Linea --------------------
      /*IF p_mto_solicitado < FU_PASAR_A_MONEDA(v_cod_mon_linea, v_sal_linea, p_cod_moneda) THEN
        IF nvl(v_ind_lin_mad, 'N') > 'S' THEN
          IF p_mto_solicitado > FU_PASAR_A_MONEDA(v_cod_mon_linea, v_sal_lin_mad, p_cod_moneda) THEN
             g_cod_error := '091';
             g_lugar     := 'Valida datos de la Linea';
             g_msj_error := 'Monto a aplicar para la modalidad '||p_cod_modalidad||' no debe superar el monto de la línea parametrizada para el producto.';
          END IF;
        END IF;
      ELSE
         g_cod_error := '091';
         g_lugar     := 'Valida datos de la Linea';
         g_msj_error := 'Monto a aplicar no debe superar el monto de la línea.';
      END IF;*/
      ------
      IF v_fec_actual > v_fec_vto_lin THEN
         g_cod_error := '091';
         g_lugar     := 'Valida datos de la Linea';
         g_msj_error := 'Linea se encuentra vencida. Fecha de Vto. '||v_fec_vto_lin||'. Fecha actual '||v_fec_actual||'.';
      END IF;
  END IF;
  --- Recupero secuencia negativa para solicitud auxiliar
  IF g_cod_error = '000' then
    -- asigno el número de la solicitud -----------------------------------------
    if p_grabar = 'S' then
      select s_nro_sol_prestamos.nextval into v_nro_solicitud from dual;
    else
      --- Recupero secuencia negativa para solicitud auxiliar
      select s_nro_sol_negativo.nextval into v_nro_solicitud from dual;
    end if;
    --------------------------------------------------------------------------
    -----------------------------------------------------------------------
  /*  BEGIN
      SELECT a.cod_pla_pre_aprobado
        INTO v_cod_pla_pre_aprobado
        FROM pr_pre_aprobados a
       WHERE a.cod_persona = p_cod_persona
         AND a.estado in ('G', 'C');
    EXCEPTION
      WHEN no_data_found THEN
        g_cod_error := '037';
        g_lugar     := 'Valida Rubro Economico';
        g_msj_error := 'Cliente no posee oferta de pre-aprobado vigente)';
      WHEN too_many_rows THEN
        SELECT a.cod_pla_pre_aprobado
          INTO v_cod_pla_pre_aprobado
          FROM pr_pre_aprobados a
         WHERE a.cod_persona = p_cod_persona
           AND a.estado in ('G', 'C')
           AND a.fec_ini_oferta =
               (SELECT MAX(b.fec_ini_oferta)
                  FROM pr_pre_aprobados b
                 WHERE b.cod_persona = a.cod_persona
                   AND b.estado in ('G', 'C'));
    END;*/
    IF P_cod_modalidad IN (992, 994) THEN
      pr_obt_rub_y_sec_credito_per(P_cod_persona,
                                   v_cod_rub_economico,
                                   v_cod_sec_credito);
      v_tip_destino := '5';
    ELSE
     ---------- Obtengo el Rubro de la tabla de pre-aprobados------------------
      BEGIN
        SELECT cod_rub_economico
          INTO v_cod_rub_economico
          FROM (
            SELECT pa.cod_rub_economico
              FROM pr_pre_aprobados pa
             WHERE pa.cod_persona = p_cod_persona
               AND pa.estado IN ('G', 'C')
             ORDER BY pa.fec_ini_oferta DESC
          )
         WHERE ROWNUM = 1;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          v_cod_rub_economico := NULL;
      END;
    END IF;

    -- inserto el registro en la tabla de solicitudes ------------------------
    BEGIN

    -- Obtengo el tipo destino en caso de ser nulo ---------------------------
    if v_tip_destino is null then
      v_tip_destino := fup_obt_tip_destino(p_cod_persona,p_cod_modalidad,p_cod_moneda,v_tot_prestamo-v_mto_interes,null,p_mto_solicitado,p_can_cuotas);
    end if;

      insert into pr_solicitudes
        (nro_solicitud,
         descripcion,
         monto,
         tip_amortizacion,
         dia_plazo,
         fec_vencimiento,
         mto_interes,
         per_vto_capital,
         per_gracia,
         cod_persona,
         fec_inicio,
         tip_monto,
         tot_prestamo,
         cod_modulo,
         cod_modalidad,
         cod_sub_modalidad,
         cod_moneda,
         cod_oficina,
         fec_pri_vencimiento,
         cod_sec_credito,
         cod_departamento,
         tip_documento,
         exo_impuesto,
         cod_usu_promotor,
         cod_canal,
         cod_campana,
         tip_destino,
         cod_banca,
         tip_renovacion,
         cod_ori_fondo,
         por_ori_fondo,
         cod_rub_economico,
         estado,
         est_verificacion,
         nro_linea)
      values
        (v_nro_solicitud,
         nvl(v_descripcion, 'PROMO PRE-APROBADO.'),
         p_mto_solicitado,
         v_tip_amortizacion,
         v_dia_plazo,
         v_fec_vencimiento,
         v_mto_interes,
         v_per_capital,
         v_per_gracia,
         p_cod_persona,
         v_fec_inicio,
         v_tip_monto,
         v_tot_prestamo,
         v_cod_modulo,
         v_cod_mod_default,
         v_cod_sub_mod_default,
         v_mon_local,
         v_cod_oficina,
         v_fec_pri_vencimiento,
         v_cod_sec_credito,
         nvl(v_cod_departamento, v_cod_dep_parametro),
         v_tip_documento,
         v_exo_impuestos,
         v_cod_usu_promotor,
         p_cod_canal,
         v_cod_campana,
         v_tip_destino,
         v_cod_banca,
         'A',
         v_ori_fondo,
         100,
         NVL(v_cod_rub_economico, 970108),
         'S',
         decode(v_cod_mod_default, 660, 'N', 'S'),
         v_nro_linea);

    EXCEPTION
      WHEN OTHERS THEN
        g_cod_error := '019';
        g_lugar     := 'Inserta Propuesta';
        g_msj_error := 'Error al insertar la propuesta. ' || SQLERRM;
    END;

  END IF;
  <<recalculo>>
  If nvl(v_max_tasa,'N') = 'S' then
     delete from pr_sol_car_tmp c  where c.nro_solicitud = nvl(p_solicitud, v_nro_solicitud);
     delete from pr_sol_cuo_tmp cu where cu.nro_solicitud = nvl(p_solicitud, v_nro_solicitud);
     delete from PR_SOL_TASAS t   where t.nro_solicitud = nvl(p_solicitud, v_nro_solicitud);
     delete from pr_sol_garantias g where g.nro_solicitud = nvl(p_solicitud, v_nro_solicitud);
     delete from pr_sol_destinos o  where o.nro_solicitud = nvl(p_solicitud, v_nro_solicitud);
  End if;
  -- genero los cargos por defecto
  IF g_cod_error = '000' THEN
    pr_gen_cargos(v_recalculo);
  END IF;

  -- generar cuotas --------------------------------------------------------
  IF g_cod_error = '000' THEN
    pr_gen_cuo_iguales('N');
  END IF;

  -- Calculo los cargos ----------------------------------------------------
  IF g_cod_error = '000' THEN
    pr_cal_cargos(v_recalculo);
  END IF;

  -- verifico el tipo de prestamo
  IF g_cod_error = '000' THEN
    IF v_tip_monto = 'B' THEN
      v_tot_prestamo := p_mto_solicitado;
    ELSE
      select sum(nvl(a.monto, 0))
        into v_mto_cargo
        from pr_sol_car_tmp a
       where a.nro_solicitud = v_nro_solicitud
         and a.cod_transaccion != v_pre_tra_mto_consolidado;


      --- monto ingresado es el neto -----------------------------------------------------
      if p_mto_solicitado < v_mto_cargo then
      v_mto_new_solicitado := v_mto_cargo;

      v_por_ajuste := (v_mto_new_solicitado - (nvl(p_mto_solicitado, 0) - v_ttvalor)) * 100 /
                      (v_mto_new_solicitado + v_ttvalor);
      else
      v_por_ajuste := (p_mto_solicitado - (nvl(v_mto_cargo, 0) - v_ttvalor)) * 100 /
                      (p_mto_solicitado + v_ttvalor);
      end if;
      --- calculo del nuevo capital (monto bruto -----------------------------------------
      v_tot_prestamo := round((p_mto_solicitado * 100 / v_por_ajuste),
                              v_redondeo);

      --- Vuelvo a generar las cuotas y calcular los cargos ------------------------------
      IF g_cod_error = '000' then
        pr_gen_cuo_iguales('S');
      END IF;

      -- recalculo los cargos ------------------------------------------------------------
      IF g_cod_error = '000' then
        pr_cal_cargos(v_recalculo);
      END IF;

    -- Bucle para ajustar el tot_prestamo hasta que el neto sea igual al solicitado
    WHILE ABS(NVL(v_TOT_PRESTAMO,0) - NVL(v_MTO_CARGO,0) - p_mto_solicitado) > v_max_dif_permitida LOOP
       v_con_iteracciones := v_con_iteracciones + 1;

       -- Si excede iteraciones permitidas, ajusto forzadamente
       if v_con_iteracciones > v_max_iteraciones then
          v_TOT_PRESTAMO := p_mto_solicitado + NVL(v_MTO_CARGO,0);
          EXIT;
       end if;

       -- Calculo el neto actual y cuánto me falta o sobra
       v_dif_loop := NVL(v_TOT_PRESTAMO,0) - NVL(v_MTO_CARGO,0);
       v_por_ajuste    := p_mto_solicitado - v_dif_loop;

       -- Si está muy cerca, fuerzo el ajuste exacto
       IF ABS(v_por_ajuste) <= 1 THEN
          v_TOT_PRESTAMO := p_mto_solicitado + NVL(v_MTO_CARGO,0);
       else
          -- Ajuste directo: si v_por_ajuste >0 suma, si <0 resta
          v_TOT_PRESTAMO := v_TOT_PRESTAMO + v_POR_AJUSTE;
       END IF;

          --- Vuelvo a generar las cuotas y calcular los cargos ------------------------------
          IF g_cod_error = '000' then
            pr_gen_cuo_iguales('S');
          END IF;

          -- recalculo los cargos ------------------------------------------------------------
          IF g_cod_error = '000' then
            pr_cal_cargos(v_recalculo);
          END IF;

      END LOOP;

    -- actualizo el total del prestamo -------------------------------------------------
    IF g_cod_error = '000' then
       -- Ajuste defensivo final antes de persistir
       v_dif_loop := NVL(v_TOT_PRESTAMO,0) - NVL(v_MTO_CARGO,0);
       v_por_ajuste    := p_mto_solicitado - v_dif_loop;

       IF ABS(v_por_ajuste) <= v_max_dif_permitida THEN
          UPDATE pr_solicitudes
             SET tot_prestamo = v_TOT_PRESTAMO + v_por_ajuste, -- ajusta por si sobra/falta poco
                 estado       = 'L'
           WHERE nro_solicitud = v_nro_solicitud;
       ELSE
          p_cod_error := '023';
          p_msj_error := 'Monto final fuera de rango aceptable. Diferencia: ' || v_por_ajuste;
          RETURN;
       END IF;
    END IF;


      ------------------------------------------------------------------------------------
    END IF;
    if v_recalculo = 'N' then
    -- Busca la cantidad de registros en pr_sol_destinos para calcular un promedio con el monto del cheque.
    begin
      select count(*)
        into v_cantidad
        from pr_sol_destinos sd, pr_cta_prestamos cp
       where cp.nro_solicitud = sd.nro_solicitud
         and cp.nro_cuenta = v_nro_cuenta;
    exception
      when others then
        g_cod_error := '023';
        g_lugar     := 'Buscar datos de la tabla pr_sol_destinos ';
        g_msj_error := 'Error al buscar destinos ' || SQLERRM;
    end;
    --
    if v_cantidad = 0 then
      v_cantidad := 1;
      begin
        insert into pr_sol_destinos
          (nro_solicitud, tip_des_especifico, monto)
        values
          (v_nro_solicitud,
           3,
           decode(v_cod_mod_default,
                  660,
                  round(p_mto_solicitado / v_cantidad, 2),
                  v_tot_prestamo));
      exception
        when others then
          g_cod_error := '024';
          g_lugar     := 'Inserta PR_SOL_DESTINOS ';
          g_msj_error := 'Error al insertar destinos ' || SQLERRM;
      end;
    else
      --Inserta en PR_SOL_DESTINOS
      for s in sol_destino(v_nro_cuenta) loop
        begin
          insert into pr_sol_destinos
            (nro_solicitud, tip_des_especifico, monto)
          values
            (v_nro_solicitud,
             decode(v_cod_mod_default,
                    660,
                    s.tip_des_especifico,
                    3),
             decode(v_cod_mod_default,
                    660,
                    round(p_mto_solicitado / v_cantidad, 2),
                    v_tot_prestamo));
        exception
          when others then
            g_cod_error := '025';
            g_lugar     := 'Inserta PR_SOL_DESTINOS ';
            g_msj_error := 'Error al insertar destinos ' || SQLERRM;
        end;
      end loop;
    end if;
    -- Busca la cantidad de registros en pr_sol_garantias para calcular un promedio con el monto del cheque.
    v_cantidad := 0;
    begin
      select count(*)
        into v_cantidad
        from pr_sol_garantias g, pr_cta_prestamos cp
       where cp.nro_solicitud = g.nro_solicitud
         and cp.nro_cuenta = v_nro_cuenta;
    exception
      when others then
        g_cod_error := '026';
        g_lugar     := 'Busca PR_SOL_GARANTIAS ';
        g_msj_error := 'Error al buscar garantias ' || SQLERRM;
    end;
    IF v_cantidad = 0 THEN
      v_cantidad := 1;
      -- Obtiene el código de garantía "A Sola Firma".
      begin
        select cod_garantia
          into v_cod_garantia
          from pr_gar_tipos
         where descripcion like '%SOLA%FIRMA%';
        -- Se inserta la garantía
        insert into pr_sol_garantias
          (nro_solicitud, cod_garantia, mto_aplicado)
        values
          (v_nro_solicitud,
           v_cod_garantia,
           decode(v_cod_mod_default,
                  660,
                  round(p_mto_solicitado / v_cantidad, 2),
                  v_tot_prestamo));
      exception
        when others then
          g_cod_error := '027';
          g_lugar     := 'Inserta PR_SOL_GARANTIAS ';
          g_msj_error := 'Error al insertar garantias ' || SQLERRM;
      end;
    ELSE
      -- Inserta en PR_SOL_GARANTIAS
      FOR g in sol_garantia(v_nro_cuenta) loop
        begin
          insert into pr_sol_garantias
            (nro_solicitud, nro_garantia, cod_garantia, mto_aplicado)
          values
            (v_nro_solicitud,
             g.nro_garantia,
             g.cod_garantia,
             round(p_mto_solicitado / v_cantidad, 2));

        exception
          when others then
            g_cod_error := '028';
            g_lugar     := 'Inserta PR_SOL_GARANTIAS ';
            g_msj_error := 'Error al insertar garantias ' || SQLERRM;
        end;
      END LOOP;
    END IF;

  /*Para calcular la diferencia de la solicitud*/
  pr_cal_dif_montos(v_nro_solicitud) ;

    -- finalmente inserto la cuota 0 ------------------------------------------------------
    begin
      INSERT INTO pr_sol_cuo_tmp
        (NRO_SOLICITUD,
         NRO_CUOTA,
         FEC_VTO_EXACTO,
         FEC_VTO_HABIL,
         VAL_INTERES,
         VAL_INT_ADELANTADO,
         MTO_CAPITAL,
         SAL_CAPITAL,
         DIA_TRANSCURRIDOS,
         DIA_INTERES,
         DIA_PERIODO)
      VALUES
        (V_NRO_SOLICITUD,
         0,
         V_FEC_INICIO,
         V_FEC_INICIO,
         0,
         0,
         0,
         V_TOT_PRESTAMO,
         0,
         0,
         0);
    EXCEPTION
      WHEN OTHERS THEN
        g_cod_error := '029';
        g_lugar     := 'Inserta PR_SOL_CUOTAS ';
        g_msj_error := 'Error al insertar cuotas ' || SQLERRM;
    END;
    -- inserto el registro de la tasa ----------------------------------------------------
    begin
      INSERT INTO PR_SOL_TASAS
        (NRO_SOLICITUD, FEC_VIGENCIA, VAL_TASA, TIP_COBRO, PER_VENCIMIENTO)
      VALUES
        (V_NRO_SOLICITUD, V_FEC_INICIO, V_VAL_TASA, 'V', v_per_vencimiento);
    EXCEPTION
      WHEN OTHERS THEN
        g_cod_error := '030';
        g_lugar     := 'Inserta PR_SOL_TASAS ';
        g_msj_error := 'Error al insertar Tasas ' || SQLERRM;
    END;
    end if;

   --Maximizacion de tasa DA - 7311 Carolina V.
    v_codi_tasa := 351;
    begin
      pag_gen.pr_obt_val_tasa(v_cod_modulo, p_cod_modalidad, v_cod_oficina,
       null , p_cod_moneda, p_mto_solicitado, 'S', v_codi_tasa /*out*/, null ,v_fec_actual,
       v_valor_tasa /*out*/, v_fec_vigencia/*out*/,v_tipo_valor /*out*/,v_tipo/*out*/, null);
    exception
     when others then
      v_max_tasa := 'X';
    End;

    If nvl(v_max_tasa,'N') <> 'X'   AND (p_mto_solicitado between v_min_val and v_max_val )
      AND v_val_ini_aumtasa <> 0 then
       v_max_tasa := 'S';
    else
       v_max_tasa := 'N';
    End if;

    --Controla que no maximize ambos, Tasa y Cargos
    if v_mad_val_tae_gas_adm > 0
      and p_mto_solicitado <= v_mto_sol_max_adm then
        v_max_cargos := 'S' ;
    else
        v_max_cargos := 'N';
    end if;

    If nvl(v_max_cargos,'N') = 'S' and nvl(v_max_tasa,'N') = 'S' then
       g_cod_error := '037';
       g_lugar := 'Max. de tasa y cargos se solapan';
       g_msj_error := 'Ajustar los parámetros de max. tasa y cargos'||sqlerrm;
    end if;

    IF g_cod_error = '000' THEN
      If nvl(v_max_tasa,'X') = 'S'  then
         begin
         --pas_bcp.pr_obt_tas_prestamo(v_nro_solicitud, null, v_tae, v_tan);
           pr_obt_tas_prestamo(v_nro_solicitud, null, v_tae, v_tan);
         exception
           when others then
             g_cod_error    := '036';
             g_lugar        := 'Busca la TAE';
             g_msj_error    := 'Error al buscar la TAE ' || sqlerrm;
             v_tas_efectiva := 0;
         end;
         If  nvl(v_tas_efectiva, 0) <> 0 then
           If nvl(v_tae,0) > nvl(v_tas_efectiva, 0) and nvl(v_tasa_back,0) > 0 then
               v_val_tasa := nvl(v_tasa_back,0);
               v_valor_aum := round( (v_valor_aum / 2 ) , 3);
               If( nvl(v_val_tasa + v_valor_aum,0) between nvl(v_tas_minima,0) and nvl(v_tas_maxima,0) ) then
                v_val_tasa := v_val_tasa + v_valor_aum;
                v_bandera := 'N';
                goto recalculo;
               End if;
           elsif nvl(v_tae,0) < nvl(v_tas_efectiva, 0) then
              IF nvl(v_bandera,'S') = 'S' then
                v_tasa_back := v_val_tasa;
                If( nvl(v_val_tasa + v_valor_aum,0) between nvl(v_tas_minima,0) and nvl(v_tas_maxima,0) ) then
                 v_val_tasa := v_val_tasa + v_valor_aum;
                 goto recalculo;
                End if;
              end if;
           end if;
         end if;
      end if;
      --Fin de maximización de tasa DA-7311
    --
    -- Maximización de cargos
    if v_mad_val_tae_gas_adm > 0
      and p_mto_solicitado <= v_mto_sol_max_adm then
      --pas_bcp.pr_obt_tas_prestamo(v_nro_solicitud, null, v_tae, v_tan);
      pr_obt_tas_prestamo(v_nro_solicitud, null, v_tae, v_tan);
      if nvl(v_tas_efectiva, 0) <> 0 then
        if v_tae > nvl(v_tas_efectiva, 0) then
          if nvl(v_mto_adm_anterior,0) > 0 then
            -- Agregado por PCON-989
            -- Se da de baja el proceso interno pr_val_consistencia
            declare
              v_dif_rollback NUMBER;
            begin
              -- 1. Identificar cuánto estamos reduciendo del cargo
              select a.monto - v_mto_adm_anterior
                into v_dif_rollback
                from pr_sol_car_tmp a
               where a.nro_solicitud = v_nro_solicitud
                 and a.cod_transaccion = 704;

              -- 2. Retroceder el cargo en la tabla temporal
              update pr_sol_car_tmp a
                 set a.monto = v_mto_adm_anterior,
                     a.mto_mon_prestamo = v_mto_adm_anterior
               where a.nro_solicitud = v_nro_solicitud
                 and a.cod_transaccion = 704;

              -- 3. Efecto dominó: Sincronizar Cabecera y Cuotas
              IF v_tip_monto = 'N' THEN
                -- Disminuimos el capital total a financiar por la misma diferencia
                v_tot_prestamo := v_tot_prestamo - v_dif_rollback;

                update pr_solicitudes s
                   set s.mto_cargo = (select nvl(sum(monto),0) from pr_sol_car_tmp where nro_solicitud = s.nro_solicitud),
                       s.tot_prestamo = v_tot_prestamo
                 where s.nro_solicitud = v_nro_solicitud;

                -- Regenerar las cuotas para que la suma del capital cuadre con el nuevo v_tot_prestamo
                pr_gen_cuo_iguales('S');
              ELSE
                -- Si es Bruto, el total no cambia, solo actualizamos el cargo en cabecera
                update pr_solicitudes s
                   set s.mto_cargo = (select nvl(sum(monto),0) from pr_sol_car_tmp where nro_solicitud = s.nro_solicitud)
                 where s.nro_solicitud = v_nro_solicitud;
              END IF;
            end;
          else
            v_fin_max := 'S';
          end if;
          -- Fin PCON-989
          if v_rec_tae = 'N' then
            g_cod_error := '040';
            g_lugar     := 'Controla TAE';
            g_msj_error := 'TAE de la propuesta supera el limite. Verificar Propuesta';
            end if;
          v_act_gas_anterior := 'S';
          goto seguir;
        else
          if (v_tas_efectiva - v_tae) >= 0.02 then
            if nvl(v_mto_aumento,0) = 0 then
              v_mto_aumento := v_mto_aum_gas_adm;
            end if;
            if v_mto_aumento > 0 then
              v_recalculo := 'S';
              v_rec_tae   := 'S';
              goto recalculo;
            end if;
          else
            v_fin_max := 'S';
          end if;
        end if;
      end if;
    end if;
    <<seguir>>
    if nvl(v_act_gas_anterior,'N') = 'S' and nvl(v_fin_max,'N') = 'N' then
      v_mto_aumento := round((v_mto_aumento / 2),0);
      if v_mto_aumento > v_mto_max_aumento then -- uenp-1117
        v_recalculo := 'S';
        goto recalculo;
      else
        v_act_gas_anterior := 'N';
        v_fin_max := 'S';
        goto recalculo;
      end if;
    end if;
    --
    begin
      update pr_sol_garantias a
      set a.mto_aplicado = V_TOT_PRESTAMO
      where a.nro_solicitud = v_nro_solicitud;
    end;
    if v_mad_val_tae_gas_adm > 0
      and p_mto_solicitado <= v_mto_sol_max_adm and (v_rec_tae = 'S') then
      -- borro la cuota 0 por si existe
      DELETE FROM pr_sol_cuo_tmp WHERE nro_solicitud = v_nro_solicitud and nro_cuota = 0 ;
      begin
        INSERT INTO pr_sol_cuo_tmp
          (NRO_SOLICITUD,
           NRO_CUOTA,
           FEC_VTO_EXACTO,
           FEC_VTO_HABIL,
           VAL_INTERES,
           VAL_INT_ADELANTADO,
           MTO_CAPITAL,
           SAL_CAPITAL,
           DIA_TRANSCURRIDOS,
           DIA_INTERES,
           DIA_PERIODO)
        VALUES
          (V_NRO_SOLICITUD,
           0,
           V_FEC_INICIO,
           V_FEC_INICIO,
           0,
           0,
           0,
           V_TOT_PRESTAMO,
           0,
           0,
           0);
      EXCEPTION
        WHEN OTHERS THEN
          g_cod_error := '039';
          g_lugar     := 'Inserta cuota 0 PR_SOL_CUOTAS ';
          g_msj_error := 'Error al insertar cuotas ' || SQLERRM;
    END;
    --
    pr_cal_dif_montos(v_nro_solicitud);
    end if;
   ----- Actualizamos las planillas del pre-aprobado -------------------------------------
  /*  BEGIN
      update pr_pre_aprobados a
         set a.nro_solicitud = v_nro_solicitud, a.estado = 'G'
       where a.cod_persona = p_cod_persona
         and a.cod_pla_pre_aprobado = v_cod_pla_pre_aprobado
         and a.estado IN ('C', 'G');
    EXCEPTION
      WHEN OTHERS THEN
        g_cod_error := '031';
        g_lugar     := 'Actualiza pr_pre_aprobados ';
        g_msj_error := 'Error al actualizar pr_pre_aprobados ' || SQLERRM;
    END;*/
   End if;
  End if;

  -- Inserto la Clave.----------------------------------
  IF g_cod_error = '000' THEN
    pr_ins_clave;
  END IF;
  IF g_cod_error = '000' then
    -- pas_bcp.pr_obt_tas_prestamo(v_nro_solicitud, null, v_tae, v_tan);
     pr_obt_tas_prestamo(v_nro_solicitud, null, v_tae, v_tan);
     If nvl(v_tae,0) > nvl(v_tas_efectiva, 0)  Then
        g_cod_error := '052';
        g_lugar     := 'Supera TAE. ';
        g_msj_error := g_lugar||' Valor obtenido :'||v_tae||' valor pizzarra:'||v_tas_efectiva;
     end if;
   end if;
  -- Inserto de las tmp a la matriz
  IF g_cod_error = '000' THEN
     pr_ins_cargos_tmp(v_nro_solicitud);
  END IF;
  
  IF g_cod_error = '000' THEN
     pr_ins_cuotas_tmp(v_nro_solicitud);
  END IF;
  
  IF g_cod_error = '000' THEN
    p_solicitud := v_nro_solicitud;
    p_cuotas    := fu_obt_mto_cuota(v_nro_solicitud);
    p_cod_error := g_cod_error;
    p_msj_error := g_msj_error;
    PRG_INS_LOG_PROGRAMAS('PRP_GEN_SOL_PRESTAMOS',
                          'MTO. SOL '||p_mto_solicitado||
                          ' CANT. CUO '||p_can_cuotas||
                          ' MONEDA '||p_cod_moneda||
                          ' MODALIDAD '||p_cod_modalidad||
                          ' SOLICITUD '||v_nro_solicitud,
                          p_cod_persona, null);
  commit;
  ELSE
    p_cod_error := g_cod_error;
    p_msj_error := g_msj_error;
    PRG_INS_LOG_PROGRAMAS('PRP_GEN_SOL_PRESTAMOS',
                          'MTO. SOL '||p_mto_solicitado||
                          ' CANT. CUO '||p_can_cuotas||
                          ' MONEDA '||p_cod_moneda||
                          ' MODALIDAD '||p_cod_modalidad||
                          ' SOLICITUD '||v_nro_solicitud||
                          ' ERROR '||p_cod_error||
                          ' - '||p_msj_error,
                          p_cod_persona, null);
    p_solicitud := null;
    p_cuotas    := null;
  END IF;

end;
/
