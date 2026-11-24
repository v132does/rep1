CREATE OR REPLACE PROCEDURE IT.PRP_GEN_ATM_SIMULACION( p_cod_persona         in varchar2, -- codigo de la persona,
                                                       p_cod_modalidad       in number, -- tipo de credito
                                                       p_cod_moneda          in varchar2, -- moneda
                                                       p_monto               in number, -- monto del credito
                                                       p_can_cuotas          in number, -- nro de cuotas
                                                       p_tip_monto           in varchar2 default 'N', -- tipo de monto B-BRUTO o N-NETO
                                                       p_fec_inicio          in date default null, -- inicio del credito
                                                       p_fec_pri_vencimiento in date default null, -- primer vencimiento
                                                       p_val_tasa            in number default null, -- valor de la tasa
                                                       p_cod_canal           in number default null, -- codigo del canal
                                                       p_cod_campana         in number  default null,   -- código de campaña
                                                       p_descripcion         in varchar2 default null, -- descripcion de la oper.
                                                       p_nro_cta_debito      in varchar2,
                                                   v_mensaje             out varchar2 ) is
  -------------------- Variables del procedimiento -----------------------------
  v_dummy      number(9);
  v_cod_modulo number(3) := 6; -- prestamos
  --v_cod_usuario       varchar2(10)   := upper(user); --usuario
  v_fec_actual date := pag_cal.fu_obt_fec_actual(v_cod_modulo); -- fecha de hoy
  --v_hor_actual        varchar2(08)   := to_char(sysdate,'HH24:MI:SS');   -- Hora actual
  v_cod_oficina         number(3); -- Codigo de oficina
  v_mon_local           varchar2(3) := pag_gen.fu_obt_mon_local;
  v_cotizacion          ge_cotizaciones.val_conversion%type := pag_gen.fu_obt_cotizacion(p_cod_moneda);
  v_lugar               varchar2(200) := null;
  v_exo_impuestos       varchar2(1) := 'N';
  v_cod_usu_oficial     varchar2(10);
  v_tot_prestamo        number(18, 2) := 0; -- total del prestamo
  v_mto_interes         number(18, 2) := 0; -- total de interes
  v_mto_cargo           number(18, 2) := 0;
  v_fec_inicio          date := nvl(p_fec_inicio, v_fec_actual);
  v_fec_pri_vencimiento date := nvl(p_fec_pri_vencimiento,
                                    add_months(v_fec_inicio, 1));
  --v_fec_vencimiento   date   := ADD_MONTHS(V_FEC_PRI_VENCIMIENTO, p_can_cuotas-1);
  v_fec_pri_vencimiento_ori date := add_months(v_fec_inicio,1);
  v_cod_sec_credito   number(3) := 1; -- ver que valor tendra
  v_cod_departamento  number(3) := null; -- Se obtiene de los datos del cliente o en su defecto de la oficina
  v_cod_dep_parametro number(3) := null; -- Departamento de Parametros
  v_tip_interes       varchar2(1) := 'V';
  v_tip_amortizacion  varchar2(1) := 'P';
  v_aju_ult_cuota     varchar2(1) := 'N';
  v_tip_aju_fecha     varchar2(1) := 'E';
  v_aju_gracia        varchar2(1) := 'N';
  v_tip_documento     number(1) := 1;
  v_tipo              varchar2(1) := 'A';
  v_cod_usu_promotor  varchar2(10);
  v_val_tasa          number := p_val_tasa;
  v_dia_plazo         number(8);
  v_per_gracia        number(8);
  --v_per_vencimiento   number(4) :=30;
  v_per_capital    pr_solicitudes.per_vto_capital%type;
  v_nro_simulacion pr_simulaciones.nro_simulacion%type;
  v_por_ajuste     number;
  v_ttvalor        number(18, 2);
  --
  v_cod_campana    cr_campanas.cod_campana%type;

  --v_nro_cuenta        varchar2(15);
  --v_cantidad          number(3);
  -- Datos de los cargos -----------------------------------------------------
  v_cod_transaccion number(4);
  v_cod_tas_cargo   number(4);
  v_val_tas_cargo   number;
  v_cod_mon_cargo   varchar2(3);
  v_tpvlpor         varchar2(1);
  v_aplicar         varchar2(3);
  v_tpdetas         varchar2(1);
  v_val_cargo       number(18, 2);
  v_cod_ent_seguro  number(6);
  v_nmtrans         ge_transacciones.descripcion%type;
  v_obligatorio     ge_transacciones_det.obligatorio%type;
  v_afecta          ge_transacciones.afecta%type;
  -- control del redondeo ----------------------------------------------------
  v_redondeo       number(2) := 0; -- redondeo a cero para moneda local
  v_limite         number := 10; -- limite superior para ajustes de cuotas iguales en moneda local
  v_ori_fondo      number;
  v_val_car_minimo number;
  --v_cod_rub_economico  pr_solicitudes.cod_rub_economico%type;
  v_por_ori_fondo pr_solicitudes.por_ori_fondo%type;
  --v_ind_evaluacion     pr_solicitudes.ind_evaluacion%type := 'S';
  --v_tip_destino        pr_solicitudes.tip_destino%type;
  v_nro_cta_debito pr_solicitudes.nro_cta_debito%type;
  v_deb_automatico pr_solicitudes.deb_automatico%type;
  v_min_monto      ge_pro_pre_aprobados.min_monto%type;
  v_max_monto      ge_pro_pre_aprobados.max_monto%type;
  v_max_plazo      ge_pro_pre_aprobados.max_plazo%type;
  v_min_plazo      ge_pro_pre_aprobados.min_plazo%type;

  rg_aprobados     ge_pro_pre_aprobados%rowtype;
  salir            exception;
  -- PCCFPPTC-1 - Flexibilidad en módulo Preaprobados de Consumo y TDC en el Core  -- 10/2016 --
  v_cod_sub_modalidad pr_solicitudes.cod_sub_modalidad%type; --:= nvl(p_cod_sub_modalidad,nvl(fug_obt_pardinamico('COD_SUB_MAD_PRE_APR',6,p_cod_modalidad),10));
  --
  v_user           ba_usuarios.cod_usuario%type := USER;
  v_usu_atm        ba_usuarios.cod_usuario%type := 'ATM';  -- ATM
  v_usu_hb         ba_usuarios.cod_usuario%type := 'HBANK';  -- HBANK

  -- PCCFPPTC-1 - Flexibilidad en módulo Preaprobados de Consumo y TDC en el Core  -- 10/2016 --
  v_monto          pr_simulaciones.monto%type;
  v_plazo          pr_simulaciones.can_cuotas%type;
  v_cuota          pr_simulaciones.monto%type;
  v_cod_moneda     pr_simulaciones.cod_moneda%type;
  v_tas_desembolso pr_simulaciones.tot_interes%type;
  v_tot_interes    pr_simulaciones.tot_interes%type;
  v_tot_cargos     pr_simulaciones.tot_cargos%type;
  v_cuo_minima     pr_simulaciones.monto%type;
  --v_tip_monto      pr_simulaciones.tip_monto%type;
  v_tip_monto      varchar2(100);
  v_mto_edilicio   pr_simulaciones.mto_edilicio%type;
  --v_tip_intere     pr_simulaciones.tip_interes%type;
  v_tip_intere     ba_cod_referencias.significado%type;
  --
  v_especial       varchar2(1):='N';
  v_cuo_total  number(18, 2) := 0;
  v_cargo      number(18, 2) := 0;
  ------------------ rutinas internas del procedimiento-----------------------

  PROCEDURE PR_VAL_TASA IS
    Cursor pizarras is
      select a.tas_interes, a.tas_minima, a.tas_maxima
        from cr_piz_montos b, cr_piz_plazos a
       where a.cod_modulo = v_cod_modulo
         and a.cod_modalidad = p_cod_modalidad
         and a.cod_moneda = p_cod_moneda
         and b.cod_modulo = a.cod_modulo
         and b.cod_modalidad = a.cod_modalidad
         and b.cod_moneda = a.cod_moneda
         and b.mto_desde = a.mto_desde
         and a.cod_sub_modalidad = v_cod_sub_modalidad  -- PCCFPPTC-1 - Flexibilidad en módulo Preaprobados de Consumo y TDC en el Core  -- 10/2016 --
         and p_monto between b.mto_desde and b.mto_hasta
         and v_dia_plazo between a.plz_desde and a.plz_hasta;
    v_tas_interes number;
    v_tas_minima  number;
    v_tas_maxima  number;
  BEGIN
    v_lugar := 'obtener_tasas de pizarras';
    open pizarras;
    fetch pizarras
      into v_tas_interes, v_tas_minima, v_tas_maxima;
    close pizarras;
    if v_val_tasa is null then
      v_val_tasa := v_tas_interes;
    else
      -- valido la tasa ingresada---
      IF NOT v_val_tasa BETWEEN v_tas_minima and v_tas_maxima then
        RAISE_APPLICATION_ERROR(-20000,
                                'ERROR. Tasa fuera de Rango. Verifique la Pizarra');
      END IF;
    end if;
  END;
  -- Verificacion del codigo del cliente--------------------------------------
  PROCEDURE PR_VAL_COD_PERSONA is
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
      -- Comentado por Ingrid Larrain 01/07/2004 y modificado para casos de generacion
      -- de solicitud
      BEGIN
        select gen.cod_ofi_matriz, 'N', ciu.cod_departamento
          into v_cod_oficina, v_exo_impuestos, v_cod_departamento
          from ge_par_generales gen, ba_oficinas ofi, ba_ciudades ciu
         where gen.cod_ofi_matriz = ofi.cod_oficina
           and ofi.cod_ciudad = ciu.cod_ciudad
           and ofi.cod_pais = ciu.cod_pais;
      END;
      ---    RAISE_APPLICATION_ERROR(-20000,'ERROR. Cliente no esta definido en el Sistema');
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20000, 'fu_val_cod_persona ' || sqlerrm);
  END;
  -- Validacion del tipo de credito---------------------------------------------
  PROCEDURE PR_VAL_COD_MODALIDAD IS
  BEGIN
    SELECT 0
      INTO v_dummy
      FROM GE_MODALIDADES
     WHERE COD_MODULO = v_cod_modulo
       AND COD_MODALIDAD = P_COD_MODALIDAD;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20000,
                              'ERROR. Tipo de Prestamo no habilitado');
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20000,
                              'ERROR: Validar Modalidad ' || SQLERRM);
  END;
  -- Validacion del codigo de la moneda-----------------------------------------
  PROCEDURE PR_VAL_COD_MONEDA IS
  BEGIN
    SELECT 0 INTO v_dummy FROM BA_MONEDAS WHERE COD_MONEDA = p_cod_moneda;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20000,
                              'ERROR. Codigo de Moneda inexistente');
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20000, 'ERROR: Valida moneda ' || SQLERRM);
  END;
  -- Procedimiento para obtener el tipo de tasa --------------------------------
  PROCEDURE PR_OBT_TIPO_DE_TASA(WW_CDTRANS     IN NUMBER,
                                WW_NMTRANS     IN OUT VARCHAR2,
                                WW_CDDETAS     IN OUT NUMBER,
                                WW_APLICAR     IN OUT VARCHAR2,
                                WW_TPVLPOR     IN OUT VARCHAR2,
                                WW_TPDETAS     IN OUT VARCHAR2,
                                WW_OBLIGATORIO IN OUT VARCHAR2,
                                WW_AFECTA      IN OUT VARCHAR2) IS
  BEGIN
    v_lugar := 'OBTENER TIPO DE TASA ';
    --- 1. Busco la tasa asociada a la transaccion ingresada ---
    SELECT initcap(TR.DESCRIPCION),
           TR.COD_TASA,
           TA.APLICAR,
           TA.TIP_VALOR,
           TA.TIPO,
           DT.OBLIGATORIO,
           TR.AFECTA
      INTO WW_NMTRANS,
           WW_CDDETAS,
           WW_APLICAR,
           WW_TPVLPOR,
           WW_TPDETAS,
           WW_OBLIGATORIO,
           WW_AFECTA
      FROM GE_TRANSACCIONES_DET DT, GE_TRANSACCIONES TR, GE_TASAS TA
     WHERE TR.COD_MODULO = v_cod_modulo
       AND TR.COD_MODALIDAD = p_cod_modalidad
       AND TR.COD_TRANSACCION = WW_CDTRANS
       AND TR.TIPO = 'D'
       AND TR.COD_TASA IS NOT NULL
       AND TR.COD_TASA = TA.COD_TASA
       AND DT.COD_MODULO = v_cod_modulo
       AND DT.COD_MODALIDAD = p_cod_modalidad
       AND DT.COD_TRANSACCION = 358 /* transaccion de desembolso de prestamos */
       AND DT.COD_MOD_HIJO = TR.COD_MODULO
       AND DT.COD_MAD_HIJO = TR.COD_MODALIDAD
       AND DT.COD_TRA_HIJO = TR.COD_TRANSACCION;
    --- 2. Si es la trans. 735 o 736, cobro de seguros por tasa, la tasa es nula ---
    /*IF WW_CDTRANS IN (735,736) THEN
       if fug_obt_tip_implementacion <> 2 then
          ww_APLICAR := 'CA';
       else
          ww_APLICAR := 'CI';
       end if;
       WW_TPVLPOR := 'I';
       WW_TPDETAS := 'F';
       WW_CDDETAS := NULL;
    END IF; ver!*/
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20000,
                              'ERROR: Cargo no definido para Prestamos ');
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20000, 'ERROR: OBT_TIPO_TASA ' || sqlerrm);
  END;
  -- Funcion que obtiene el valor de la tasa fija ------------------------------
  FUNCTION FU_OBT_VALOR_DE_TASA_FIJA(WW_CDDETAS IN NUMBER,
                                     WW_FCINICI IN DATE) RETURN NUMBER IS
    WW_VLDETAS NUMBER(15, 2);
    --para probar como esta en el form
    V_FEC_VIGENCIA date;
    V_TIP_VALOR    ge_tasas.tip_valor%type;
    V_TIPO         ge_tasas.tipo%type;
    V_COD_TASA     ge_tasas.cod_tasa%type := WW_CDDETAS;
  BEGIN
    v_lugar := 'OBTENER VALOR DE TASA FIJA ';
    -- tasa fija, buscar en tasa por fecha ---
    pag_gen.PR_OBT_VAL_TASA(v_cod_modulo,
                            p_cod_modalidad,
                            v_cod_oficina,
                            null,
                            p_cod_moneda, --5
                            null,
                            'S',
                            V_COD_TASA,
                            null,
                            v_fec_inicio, --10
                            WW_VLDETAS,
                            V_FEC_VIGENCIA,
                            V_TIP_VALOR,
                            V_TIPO,
                            p_cod_persona, --15
                            v_cod_sub_modalidad       -- PCCFPPTC-1 - Flexibilidad en módulo Preaprobados de Consumo y TDC en el Core  -- 10/2016 --
                            );

    v_val_car_minimo := pag_gen.fu_obt_val_minimo;
    RETURN ww_vldetas;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RETURN NULL;
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20000, 'obt_tasa_fija ' || sqlerrm);
  END;
  -- Funcion que devuelve el valor de la tasa, si es variable ------------------
  FUNCTION FU_OBT_VALOR_DE_TASA_VARIABLE(WW_CDDETAS IN NUMBER,
                                         WW_VLMONTO IN NUMBER,
                                         WW_FCINICI IN DATE) RETURN NUMBER IS
    ww_vldetas NUMBER(15, 2);
    --para probar como esta en el form
    V_FEC_VIGENCIA date;
    V_TIP_VALOR    ge_tasas.tip_valor%type;
    V_TIPO         ge_tasas.tipo%type;
    V_COD_TASA     ge_tasas.cod_tasa%type := WW_CDDETAS;
  BEGIN
    v_lugar := 'OBTENER VALOR DE TASA VARIABLE ';
    -- tasa variable, buscar en tabla de tasas variables ---
    pag_gen.PR_OBT_VAL_TASA(v_cod_modulo,
                            p_cod_modalidad,
                            v_cod_oficina,
                            null,
                            p_cod_moneda,
                            WW_VLMONTO,
                            'S',
                            V_COD_TASA,
                            null,
                            v_fec_inicio,
                            ww_vldetas,
                            V_FEC_VIGENCIA,
                            v_tip_valor,
                            v_tipo,
                            p_cod_persona,
                            v_cod_sub_modalidad   -- PCCFPPTC-1 - Flexibilidad en módulo Preaprobados de Consumo y TDC en el Core  -- 10/2016 --
                            );
    v_val_car_minimo := pag_gen.FU_OBT_VAL_MINIMO;
    IF ww_vldetas is null then
      RAISE_APPLICATION_ERROR(-20000,
                              'No existe Valor para la Tasa ' ||
                              to_char(ww_cddetas) || ' y el Monto ' ||
                              to_char(ww_vlmonto) || ' Fecha ' ||
                              to_char(ww_fcinici, 'DD/MM/YYYY'));
    END IF;
    RETURN ww_vldetas;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RETURN NULL;
    WHEN OTHERS THEN
      if sqlcode <= -20000 then
        raise;
      else
        RAISE_APPLICATION_ERROR(-20000, 'obt_tasa_variable ' || sqlerrm);
      end if;
  END;
  -- Verificacion del codigo de tasa--------------------------------------------
  PROCEDURE PR_OBT_DATOS_CARGO IS
  BEGIN
    if v_cod_ent_seguro is not null then
      --- veo que tasa de seguro tiene el ente asegurador
      v_cod_tas_cargo := fug_obt_parentes(v_cod_ent_seguro,
                                          'COD_TAS_SEGURO'); --'COD_TAS_SEG_SEGURO' ver!
      --- Ahora, busco el codigo de tasa que corresponde al plazo
      v_cod_tas_cargo := FU_OBT_VALOR_DE_TASA_VARIABLE(v_cod_tas_cargo,
                                                       nvl(v_dia_plazo, 0),
                                                       v_fec_inicio);
    end if;
    -- obtengo los datos de la tasa-----------------
    PR_OBT_TIPO_DE_TASA(v_cod_transaccion,
                        v_nmtrans,
                        v_cod_tas_cargo,
                        v_aplicar,
                        v_tpvlpor,
                        v_tpdetas,
                        v_obligatorio,
                        v_afecta);
    --- la tasa es de tipo  valor ---
    IF v_tpdetas = 'F' THEN
      --- tipo de tasa fijo      ---
      v_val_tas_cargo := FU_OBT_VALOR_DE_TASA_FIJA(v_cod_tas_cargo,
                                                   v_fec_inicio);
    ELSE
      --- tipo de tasa variable  ---
      if v_aplicar in ('PI', 'PC', 'PT', 'PL', 'CP', 'IP', 'TP') then
        if v_aplicar in ('PI', 'PC', 'PT', 'PL') then
          --- El primer rango es por plazo
          v_val_tas_cargo := FU_OBT_VALOR_DE_TASA_VARIABLE(v_cod_tas_cargo,
                                                           v_dia_plazo,
                                                           v_fec_inicio);
        else
          --- tipo de tasa variable  ---
          v_val_tas_cargo := FU_OBT_VALOR_DE_TASA_VARIABLE(v_cod_tas_cargo,
                                                           nvl(v_tot_prestamo,
                                                               p_monto),
                                                           v_fec_inicio);
        end if;
        if v_aplicar IN ('CP', 'IP', 'TP') then
          -- aplicar al capital y plazo, busco ahora el valor por plazo
          v_val_tas_cargo := FU_OBT_VALOR_DE_TASA_VARIABLE(v_val_tas_cargo,
                                                           v_dia_plazo,
                                                           v_fec_inicio);
        elsif v_aplicar in ('PC', 'PT', 'PI') then
          v_val_tas_cargo := FU_OBT_VALOR_DE_TASA_VARIABLE(v_val_tas_cargo,
                                                           nvl(v_tot_prestamo,
                                                               p_monto),
                                                           v_fec_inicio);
        end if;
      else
        v_val_tas_cargo := FU_OBT_VALOR_DE_TASA_VARIABLE(v_cod_tas_cargo,
                                                         nvl(v_tot_prestamo,
                                                             p_monto),
                                                         v_fec_inicio);
      end if;
    END IF;
    IF V_TPVLPOR IN ('I', 'P') OR V_COD_TRANSACCION IN (735, 736) THEN
      --- porcentajes  o transacciones de seguros  ---
      v_cod_mon_cargo := v_mon_local;
    ELSE
      --- en caso de que sean valores ----------------
      v_cod_mon_cargo := p_cod_moneda;
      v_val_cargo     := v_val_tas_cargo;
      v_val_tas_cargo := null;
    END IF;
  END;

  -- Carga de cargos de la propuesta-------------------------------------------
  PROCEDURE PR_GEN_CARGOS IS
    v_cod_tip_canal ge_tip_canales.cod_tip_canal%type;
    --
    CURSOR cargos is
      Select decode(a.cod_transaccion, 709, 1, 710, 2, a.cod_transaccion) orden, -- solo para ordenamiento
             a.cod_transaccion,
             a.cod_ent_seguro,
             nvl(b.obligatorio, 'N') obligator
        from ge_sol_cargos a, ge_transacciones_det b
       where a.cod_transaccion = b.cod_tra_hijo(+)
         and a.cod_modulo = b.cod_mod_hijo(+)
         and a.cod_modalidad = b.cod_mad_hijo(+)
         and a.cod_modulo = v_cod_modulo
         and a.cod_modalidad = p_cod_modalidad
         and a.cod_modulo = b.cod_modulo
         and a.cod_modalidad = b.cod_modalidad
         and ((NVL(v_exo_impuestos, 'N') = 'N') or
             (NVL(v_exo_impuestos, 'N') = 'S' and
             nvl(b.obligatorio, 'N') = 'N'))
         and (a.cod_canal = p_cod_canal or
             (a.cod_canal is null and not exists
              (Select '1' from ge_sol_cargos where cod_canal = p_cod_canal)))
         and (a.cod_tip_canal = v_cod_tip_canal or
             (a.cod_tip_canal is null and not exists
              (select '1'
                  from ge_sol_cargos
                 where cod_tip_canal = v_cod_tip_canal)))
         and (a.cod_campana = v_cod_campana or
             (a.cod_campana is null and not exists
              (Select '1'
                  from ge_sol_cargos
                 where cod_campana = v_cod_campana)))
       order by 1;
  BEGIN
    If p_cod_canal is not null Then
      Select cod_tip_canal
        into v_cod_tip_canal
        from ge_canales
       where cod_canal = p_cod_canal;
    End If;
    FOR cc in cargos loop
      v_cod_transaccion := cc.cod_transaccion;
      v_cod_ent_seguro  := cc.cod_ent_seguro;
      v_val_tas_cargo   := null;
      v_val_cargo       := null;
      v_cod_tas_cargo   := null;
      v_cod_mon_cargo   := null;
      pr_obt_datos_cargo;
      --If cc.obligator = 'S' or nvl(v_val_cargo,0) != 0 Then
      if nvl(instr(v_cod_transaccion,fug_obt_pardinamico('TRA_IVA_DESEMBOLSO',v_cod_modulo,p_cod_modalidad)),0) = 0 then
      insert into pr_sim_cargos
        (nro_simulacion,
         cod_transaccion,
         val_tasa,
         monto,
         cod_tasa,
         cod_ent_seguro,
         cod_moneda,
         mto_equivalente)
      values
        (v_nro_simulacion,
         v_cod_transaccion,
         v_val_tas_cargo,
         v_val_cargo,
         v_cod_tas_cargo,
         cc.cod_ent_seguro,
         v_cod_mon_cargo,
         null);
      --End If;
      end if;
    end loop;
  END;
  -- Generacion de cuotas -----------------------------------------------------
  PROCEDURE PR_GEN_CUOTAS IS
    WW_DIAVENC         VARCHAR2(02);
    WW_FRANCES         NUMBER;
    WW_TASADIV         NUMBER := v_val_tasa / 36500 *
                                 30.416666666666666666666666666667; --ver!
    WW_VLSALAN         NUMBER(18, 2) := v_tot_prestamo;
    WW_TTCUOTA         NUMBER(18, 2) := NULL;
    WW_DFCUOTA         NUMBER(18, 2);
    WW_TTCAPIT         NUMBER(18, 2) := 0;
    WW_TTREFUE         NUMBER(18, 2) := 0;
    WW_REFREAL         NUMBER(18, 2) := 0;
    WW_CTREFUE         NUMBER(6) := 0;
    WW_NRO             NUMBER(6) := 0;
    WW_VECES           NUMBER(3) := 0;
    V_VAL_INT_ORIGINAL NUMBER(18, 2) := 0;
    --
    V_FEC_VTO_HABIL    DATE;
    V_FEC_VTO_EXACTO   DATE;
    V_SAL_CAP_ANTERIOR NUMBER(18, 2);
    --V_DIA_PERIORO      NUMBER(6);
    V_DIA_INTERES      NUMBER(6);
    V_VAL_INTERES      NUMBER(18, 2);
    V_TTCUOTA          NUMBER(18, 2);
    V_DIA_PERIODO      NUMBER(8);
    V_MTO_CAPITAL      NUMBER(18, 2);
    v_fec_ven_anterior date;
    v_val_cuota        number(18, 2);
    v_dias             number;
  BEGIN
    -- dia de vencimiento
    ww_diavenc := TO_CHAR(V_FEC_PRI_VENCIMIENTO, 'DD');
    ------------------------------------------------------------------------
    LOOP
      v_fec_ven_anterior := v_fec_inicio;
      ww_veces           := NVL(ww_veces, 0) + 1;
      --- calculo del valor del metodo frances ----------------------------- ver!
      --if ww_tasadiv = 0 and p_can_cuotas = 1 then ver!
      if (power((1 + WW_TASADIV), (p_can_cuotas - WW_CTREFUE)) - 1) > 0 then
        --ww_frances := nvl(v_tot_prestamo,0); ver!
        ww_frances := ((NVL(V_TOT_PRESTAMO, 0) - NVL(ww_ttrefue, 0)) *
                      ww_tasadiv) /
                      (power((1 + ww_tasadiv), (p_can_cuotas - ww_ctrefue)) - 1);
      else
        ww_frances := ((NVL(v_tot_prestamo, 0) - NVL(WW_TTREFUE, 0))) /
                      ((p_can_cuotas - WW_CTREFUE));
        /*ww_frances := ((NVL(V_TOT_PRESTAMO,0)-NVL(ww_ttrefue,0))* ww_tasadiv) /
        (power((1 + ww_tasadiv),(p_can_cuotas-ww_ctrefue)) - 1); ver!*/
      end if;
      v_val_cuota := round((WW_FRANCES * power(1 + WW_TASADIV, (0))),
                           v_redondeo) +
                     round(WW_VLSALAN * WW_TASADIV, v_redondeo);
      --- Veo el monto fijo de cuota si es de tipo Prestamos flexibles -----
      ----------------------------------------------------------------------
      v_mto_interes := 0;
      ww_vlsalan    := v_tot_prestamo;
      ww_ttcapit    := 0;
      ww_refreal    := 0;
      ww_nro        := 0; /* acumulador de cuotas calculadas automaticamente, sin refuerzo */
      -- borro las cuotas si existen
      delete from pr_sim_cuotas
      where nro_simulacion = v_nro_simulacion;

      FOR CUOTA IN 1 .. p_can_cuotas LOOP

        if cuota = 1 then
          V_FEC_VTO_HABIL  := V_FEC_PRI_VENCIMIENTO;
          V_FEC_VTO_EXACTO := V_FEC_PRI_VENCIMIENTO;
        else
          V_FEC_VTO_HABIL  := add_months(V_FEC_PRI_VENCIMIENTO, (cuota - 1));
          V_FEC_VTO_EXACTO := v_fec_pri_vencimiento + (((cuota - 1) * 30));
        end if;
        --V_FEC_VTO_HABIL := ADD_MONTHS(V_FEC_PRI_VENCIMIENTO, cuota -1); ver!
        --V_FEC_VTO_EXACTO := V_FEC_PRI_VENCIMIENTO + ((cuota -1) * 30);
        v_dias             := V_FEC_VTO_HABIL - v_fec_ven_anterior;
        V_SAL_CAP_ANTERIOR := ww_vlsalan;
        V_DIA_PERIODO      := v_dias;
        V_DIA_INTERES      := v_dias;
        V_VAL_INTERES      := ROUND((ww_vlsalan * ww_tasadiv /
                                    30.416666666666666666666666666667 *
                                    V_DIAS),
                                    v_redondeo);
        /*IF CUOTA = 1 AND ABS(30 - (V_FEC_PRI_VENCIMIENTO - V_FEC_INICIO)) > 2 THEN
           \* se hace el calculo del interes por el plazo del periodo de gracia *\
           V_DIA_PERIODO := V_FEC_PRI_VENCIMIENTO - V_FEC_INICIO;
           V_DIA_INTERES := V_FEC_PRI_VENCIMIENTO - V_FEC_INICIO;
           V_VAL_INTERES := ROUND((ww_vlsalan * ww_tasadiv / 30.416666666666666666666666666667 * V_DIAS),v_redondeo);
           v_val_cuota   := null;
        ELSE --ver!
           if fug_obt_tip_implementacion in (1,7,9) then
              V_DIA_PERIODO := V_FEC_VTO_HABIL - v_fec_ven_anterior;
              V_DIA_INTERES := V_FEC_VTO_HABIL - v_fec_ven_anterior;
              V_VAL_INTERES := ROUND((ww_vlsalan * ww_tasadiv),v_redondeo);
           else
              V_DIA_PERIODO := 30;
              V_DIA_INTERES := 30;
              V_VAL_INTERES := ROUND((ww_vlsalan * ww_tasadiv),v_redondeo);
           end if;
        END IF;*/
        IF V_VAL_INT_ORIGINAL > 0 THEN
          /* es una cuota con refuerzo */
          IF p_tip_monto = 'N' THEN
            -- NETO
            V_MTO_CAPITAL := V_MTO_CAPITAL;
          ELSE
            V_MTO_CAPITAL := nvl(V_VAL_INT_ORIGINAL, 0) -
                             nvl(V_MTO_INTERES, 0);
          END IF;
          ww_refreal := NVL(ww_refreal, 0) + NVL(V_MTO_CAPITAL, 0);
          --v_val_cuota := null;
        ELSE
          ww_nro := ww_nro + 1;
          /*if v_val_cuota is not null and fug_obt_tip_implementacion in (1,7,9) then
             V_MTO_CAPITAL := v_val_cuota - V_VAL_INTERES;
          else
             V_MTO_CAPITAL := ROUND((ww_frances * power((1 + ww_tasadiv), (ww_nro - 1))),v_redondeo);
          end if;
          v_val_cuota := V_MTO_CAPITAL + V_VAL_INTERES;*/
          if cuota = 1 and
             abs(30 - (v_fec_pri_vencimiento - v_fec_inicio)) > 2 then
            V_MTO_CAPITAL := round(WW_FRANCES *
                                   power((1 + WW_TASADIV), (WW_NRO - 1)),
                                   v_redondeo);
          else
            V_MTO_CAPITAL := v_val_cuota - V_VAL_INTERES;
          end if;
        END IF;
        V_VAL_INT_ORIGINAL := NVL(V_VAL_INT_ORIGINAL, 0);
        V_TTCUOTA          := NVL(V_MTO_CAPITAL, 0) + NVL(V_VAL_INTERES, 0);
        ww_dfcuota         := NVL(ww_ttcuota, V_TTCUOTA) -
                              NVL(V_TTCUOTA, 0);
        -- ajuste de cuotas para que sean iguales solo se hace en guaranies
        IF (ABS(ww_dfcuota) BETWEEN 0.001 AND v_limite) THEN
          V_VAL_INTERES := V_VAL_INTERES + ww_dfcuota;
          V_TTCUOTA     := V_TTCUOTA + ww_dfcuota;
        END IF;
        if V_VAL_INT_ORIGINAL = 0 then
          WW_TTCUOTA := V_TTCUOTA;
        end if;
        --ww_ttcuota := V_TTCUOTA;
        ww_vlsalan         := NVL(ww_vlsalan, 0) - V_MTO_CAPITAL;
        ww_ttcapit         := NVL(ww_ttcapit, 0) + NVL(V_MTO_CAPITAL, 0);
        V_MTO_INTERES      := V_MTO_INTERES + NVL(V_VAL_INTERES, 0);
        v_fec_ven_anterior := V_FEC_VTO_HABIL;
        if p_cod_modalidad = 660 then
          V_DIA_PERIODO := 1;
          V_DIA_INTERES := 1;
        end if;
        -- inserto el registro en la tabla de simulacion de cuotas
        insert into pr_sim_cuotas
          (nro_simulacion,
           nro_cuota,
           mto_capital,
           fec_vencimiento,
           per_dias,
           sal_anterior,
           mto_interes,
           mto_refuerzo)
        values
          (v_nro_simulacion,
           cuota,
           nvl(v_mto_capital, 0),
           v_fec_vto_habil,
           v_dia_periodo,
           ww_vlsalan,
           nvl(v_val_interes, 0),
           0);

      END LOOP;
      --- veo si se necesita ajustar la ultima cuota de capital ------
      --IF NVL(:PR_SOL_CUOTAS.NRO_CUOTA,-1) <> :PR_SOLICITUDES.SC_CTCUOTA THEN
      --  PREVIOUS_RECORD;
      --END IF;
      IF ABS(NVL(ww_refreal, 0) - NVL(ww_ttrefue, 0)) < 10 OR ww_veces > 12 OR
         p_tip_monto = 'N' THEN
        EXIT;
      END IF;
    END LOOP;
    ww_dfcuota := nvl(v_tot_prestamo, 0) - nvl(ww_ttcapit, 0);
    IF ww_dfcuota <> 0 THEN
      V_MTO_CAPITAL := nvl(V_MTO_CAPITAL, 0) + ww_dfcuota;
      IF NVL(V_VAL_INTERES, 0) >= ww_dfcuota and abs(WW_DFCUOTA) <= -1 /* solo se ajusta si existe interes*/
         and nvl(V_VAL_INTERES, 0) > 0 THEN
        V_VAL_INTERES := nvl(V_VAL_INTERES, 0) - ww_dfcuota;
        V_MTO_INTERES := nvl(V_MTO_INTERES, 0) - ww_dfcuota;
      ELSE
        V_TTCUOTA := NVL(V_MTO_CAPITAL, 0) + NVL(V_VAL_INTERES, 0);
      END IF;
      -- Actualizo la ultima cuota
      update pr_sim_cuotas
         set mto_capital = nvl(v_mto_capital, 0),
             mto_interes = nvl(v_val_interes, 0)
       where nro_simulacion = v_nro_simulacion
         and nro_cuota = p_can_cuotas; -- ultima cuota
    END IF;
    -- vencimiento final del prestamo es igual al de la ult.cuota--
    update pr_simulaciones
       set TOT_INTERES = V_MTO_INTERES
     where nro_simulacion = v_nro_simulacion;
    ----------------------------------------------------------------
  EXCEPTION
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20000, 'GENERACION_CUOTAS ' || SQLERRM);
  END;

   -- Generacion de cuotas Especiales -----------------------------------------------------
  PROCEDURE PR_GEN_CUOTAS_ESP(P_ESPECIAL IN VARCHAR2) IS
    WW_DIAVENC         VARCHAR2(02);
    WW_FRANCES         NUMBER;
    WW_TASADIV         NUMBER := v_val_tasa / 36500 *
                                 30.416666666666666666666666666667; --ver!
    WW_VLSALAN         NUMBER(18, 2) := v_tot_prestamo;
    WW_TTCUOTA         NUMBER(18, 2) := NULL;
    WW_DFCUOTA         NUMBER(18, 2);
    WW_TTCAPIT         NUMBER(18, 2) := 0;
    WW_TTREFUE         NUMBER(18, 2) := 0;
    WW_REFREAL         NUMBER(18, 2) := 0;
    WW_CTREFUE         NUMBER(6) := 0;
    WW_NRO             NUMBER(6) := 0;
    WW_VECES           NUMBER(3) := 0;
    V_VAL_INT_ORIGINAL NUMBER(18, 2) := 0;
    --
    V_FEC_VTO_HABIL    DATE;
    V_FEC_VTO_EXACTO   DATE;
    V_SAL_CAP_ANTERIOR NUMBER(18, 2);
    --V_DIA_PERIORO      NUMBER(6);
    V_DIA_INTERES      NUMBER(6);
    V_VAL_INTERES      NUMBER(18, 2);
    V_TTCUOTA          NUMBER(18, 2);
    V_DIA_PERIODO      NUMBER(8);
    V_MTO_CAPITAL      NUMBER(18, 2);
    v_fec_ven_anterior date;
    v_val_cuota        number(18, 2);
    v_dias             number;
    v_can_cuotas       number(10):=0;
  BEGIN
    -- dia de vencimiento
    ww_diavenc := TO_CHAR(V_FEC_PRI_VENCIMIENTO, 'DD');
    ------------------------------------------------------------------------
    LOOP
      v_fec_ven_anterior := v_fec_inicio;
      ww_veces           := NVL(ww_veces, 0) + 1;
      --- calculo del valor del metodo frances ----------------------------- ver!
      --if ww_tasadiv = 0 and p_can_cuotas = 1 then ver!
       if P_ESPECIAL='S' then
         v_can_cuotas:= p_can_cuotas -1;
       else
         v_can_cuotas:= p_can_cuotas;
       end if;

      if (power((1 + WW_TASADIV), (v_can_cuotas/*p_can_cuotas*/ - WW_CTREFUE)) - 1) > 0 then
        --ww_frances := nvl(v_tot_prestamo,0); ver!
        ww_frances := ((NVL(V_TOT_PRESTAMO, 0) - NVL(ww_ttrefue, 0)) *
                      ww_tasadiv) /
                      (power((1 + ww_tasadiv), (v_can_cuotas/*p_can_cuotas*/ - ww_ctrefue)) - 1);
      else
        ww_frances := ((NVL(v_tot_prestamo, 0) - NVL(WW_TTREFUE, 0))) /
                      ((v_can_cuotas/*p_can_cuotas*/ - WW_CTREFUE));
        /*ww_frances := ((NVL(V_TOT_PRESTAMO,0)-NVL(ww_ttrefue,0))* ww_tasadiv) /
        (power((1 + ww_tasadiv),(p_can_cuotas-ww_ctrefue)) - 1); ver!*/
      end if;
      v_val_cuota := round((WW_FRANCES * power(1 + WW_TASADIV, (0))),
                           v_redondeo) +
                     round(WW_VLSALAN * WW_TASADIV, v_redondeo);
      --- Veo el monto fijo de cuota si es de tipo Prestamos flexibles -----
      ----------------------------------------------------------------------
      v_mto_interes := 0;
      ww_vlsalan    := v_tot_prestamo;
      ww_ttcapit    := 0;
      ww_refreal    := 0;
      ww_nro        := 0; /* acumulador de cuotas calculadas automaticamente, sin refuerzo */
      -- borro las cuotas si existen
      delete from pr_sim_cuotas
      where nro_simulacion = v_nro_simulacion;

      FOR CUOTA IN 1 .. p_can_cuotas LOOP

        if cuota = 1 then
          V_FEC_VTO_HABIL  := V_FEC_PRI_VENCIMIENTO;
          V_FEC_VTO_EXACTO := V_FEC_PRI_VENCIMIENTO;
        else
          V_FEC_VTO_HABIL  := add_months(V_FEC_PRI_VENCIMIENTO, (cuota - 1));
          V_FEC_VTO_EXACTO := v_fec_pri_vencimiento + (((cuota - 1) * 30));
        end if;
        --V_FEC_VTO_HABIL := ADD_MONTHS(V_FEC_PRI_VENCIMIENTO, cuota -1); ver!
        --V_FEC_VTO_EXACTO := V_FEC_PRI_VENCIMIENTO + ((cuota -1) * 30);
        v_dias             := V_FEC_VTO_HABIL - v_fec_ven_anterior;
        V_SAL_CAP_ANTERIOR := ww_vlsalan;
        V_DIA_PERIODO      := v_dias;
        V_DIA_INTERES      := v_dias;
        V_VAL_INTERES      := ROUND((ww_vlsalan * ww_tasadiv /
                                    30.416666666666666666666666666667 *
                                    V_DIAS),
                                    v_redondeo);
        /*IF CUOTA = 1 AND ABS(30 - (V_FEC_PRI_VENCIMIENTO - V_FEC_INICIO)) > 2 THEN
           \* se hace el calculo del interes por el plazo del periodo de gracia *\
           V_DIA_PERIODO := V_FEC_PRI_VENCIMIENTO - V_FEC_INICIO;
           V_DIA_INTERES := V_FEC_PRI_VENCIMIENTO - V_FEC_INICIO;
           V_VAL_INTERES := ROUND((ww_vlsalan * ww_tasadiv / 30.416666666666666666666666666667 * V_DIAS),v_redondeo);
           v_val_cuota   := null;
        ELSE --ver!
           if fug_obt_tip_implementacion in (1,7,9) then
              V_DIA_PERIODO := V_FEC_VTO_HABIL - v_fec_ven_anterior;
              V_DIA_INTERES := V_FEC_VTO_HABIL - v_fec_ven_anterior;
              V_VAL_INTERES := ROUND((ww_vlsalan * ww_tasadiv),v_redondeo);
           else
              V_DIA_PERIODO := 30;
              V_DIA_INTERES := 30;
              V_VAL_INTERES := ROUND((ww_vlsalan * ww_tasadiv),v_redondeo);
           end if;
        END IF;*/
        IF V_VAL_INT_ORIGINAL > 0 THEN
          /* es una cuota con refuerzo */
          IF p_tip_monto = 'N' THEN
            -- NETO
            V_MTO_CAPITAL := V_MTO_CAPITAL;
          ELSE
            V_MTO_CAPITAL := nvl(V_VAL_INT_ORIGINAL, 0) -
                             nvl(V_MTO_INTERES, 0);
          END IF;
          ww_refreal := NVL(ww_refreal, 0) + NVL(V_MTO_CAPITAL, 0);
          --v_val_cuota := null;
        ELSE
          ww_nro := ww_nro + 1;
          /*if v_val_cuota is not null and fug_obt_tip_implementacion in (1,7,9) then
             V_MTO_CAPITAL := v_val_cuota - V_VAL_INTERES;
          else
             V_MTO_CAPITAL := ROUND((ww_frances * power((1 + ww_tasadiv), (ww_nro - 1))),v_redondeo);
          end if;
          v_val_cuota := V_MTO_CAPITAL + V_VAL_INTERES;*/
          if cuota = 1 and P_ESPECIAL='S' then
              V_MTO_CAPITAL := 0;
          elsif cuota = 2/*1*/  and abs(30 - (v_fec_pri_vencimiento - v_fec_inicio)) > 2 then
            V_MTO_CAPITAL := round(WW_FRANCES *
                                   power((1 + WW_TASADIV), (1/*WW_NRO*/ - 1)),
                                   v_redondeo);
          else
            V_MTO_CAPITAL := v_val_cuota - V_VAL_INTERES;
          end if;
        END IF;
        V_VAL_INT_ORIGINAL := NVL(V_VAL_INT_ORIGINAL, 0);
        V_TTCUOTA          := NVL(V_MTO_CAPITAL, 0) + NVL(V_VAL_INTERES, 0);
        ww_dfcuota         := NVL(ww_ttcuota, V_TTCUOTA) -
                              NVL(V_TTCUOTA, 0);
        -- ajuste de cuotas para que sean iguales solo se hace en guaranies
        IF (ABS(ww_dfcuota) BETWEEN 0.001 AND v_limite) THEN
          V_VAL_INTERES := V_VAL_INTERES + ww_dfcuota;
          V_TTCUOTA     := V_TTCUOTA + ww_dfcuota;
        END IF;
        if V_VAL_INT_ORIGINAL = 0 then
          WW_TTCUOTA := V_TTCUOTA;
        end if;
        --ww_ttcuota := V_TTCUOTA;
        ww_vlsalan         := NVL(ww_vlsalan, 0) - V_MTO_CAPITAL;
        ww_ttcapit         := NVL(ww_ttcapit, 0) + NVL(V_MTO_CAPITAL, 0);
        V_MTO_INTERES      := V_MTO_INTERES + NVL(V_VAL_INTERES, 0);
        v_fec_ven_anterior := V_FEC_VTO_HABIL;
        if p_cod_modalidad = 660 then
          V_DIA_PERIODO := 1;
          V_DIA_INTERES := 1;
        end if;
        -- inserto el registro en la tabla de simulacion de cuotas
        insert into pr_sim_cuotas
          (nro_simulacion,
           nro_cuota,
           mto_capital,
           fec_vencimiento,
           per_dias,
           sal_anterior,
           mto_interes,
           mto_refuerzo)
        values
          (v_nro_simulacion,
           cuota,
           nvl(v_mto_capital, 0),
           v_fec_vto_habil,
           v_dia_periodo,
           ww_vlsalan,
           nvl(v_val_interes, 0),
           0);

      END LOOP;
      --- veo si se necesita ajustar la ultima cuota de capital ------
      --IF NVL(:PR_SOL_CUOTAS.NRO_CUOTA,-1) <> :PR_SOLICITUDES.SC_CTCUOTA THEN
      --  PREVIOUS_RECORD;
      --END IF;
      IF ABS(NVL(ww_refreal, 0) - NVL(ww_ttrefue, 0)) < 10 OR ww_veces > 12 OR
         p_tip_monto = 'N' THEN
        EXIT;
      END IF;
    END LOOP;
    ww_dfcuota := nvl(v_tot_prestamo, 0) - nvl(ww_ttcapit, 0);
    IF ww_dfcuota <> 0 THEN
      V_MTO_CAPITAL := nvl(V_MTO_CAPITAL, 0) + ww_dfcuota;
      IF NVL(V_VAL_INTERES, 0) >= ww_dfcuota and abs(WW_DFCUOTA) <= -1 /* solo se ajusta si existe interes*/
         and nvl(V_VAL_INTERES, 0) > 0 THEN
        V_VAL_INTERES := nvl(V_VAL_INTERES, 0) - ww_dfcuota;
        V_MTO_INTERES := nvl(V_MTO_INTERES, 0) - ww_dfcuota;
      ELSE
        V_TTCUOTA := NVL(V_MTO_CAPITAL, 0) + NVL(V_VAL_INTERES, 0);
      END IF;
      -- Actualizo la ultima cuota
      update pr_sim_cuotas
         set mto_capital = nvl(v_mto_capital, 0),
             mto_interes = nvl(v_val_interes, 0)
       where nro_simulacion = v_nro_simulacion
         and nro_cuota = p_can_cuotas; -- ultima cuota
    END IF;
    -- vencimiento final del prestamo es igual al de la ult.cuota--
    update pr_simulaciones
       set TOT_INTERES = V_MTO_INTERES
     where nro_simulacion = v_nro_simulacion;
    ----------------------------------------------------------------
  EXCEPTION
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20000, 'GENERACION_CUOTAS ' || SQLERRM);
  END;


  -- Calculo de los cargos ----------------------------------------------------
  PROCEDURE PR_CAL_CARGOS IS
    ww_dfcargos       number(18, 2);
    v_mto_equivalente number(18, 2);
    v_cod_tra_ajuste  number(4);
    v_monto           number(18, 2);
    cursor cargos is
      select cod_transaccion,
             cod_tasa,
             cod_ent_seguro,
             val_tasa,
             monto,
             cod_moneda,
             MTO_EQUIVALENTE mto_mon_prestamo
        from pr_sim_cargos
       where nro_simulacion = v_nro_simulacion
         for update of monto
       order by decode(cod_transaccion, 709, 1, 710, 2, cod_transaccion);
  BEGIN
    --- Calculo cada uno de los cargos en la moneda del cargo y en la de la simulacion ---
    --- cero los totales de cargo de tipo valor y el total general de cargos -------------
    V_TTVALOR        := 0;
    V_MTO_CARGO      := 0;
    v_cod_tra_ajuste := null;
    for cc in cargos loop
      v_mto_equivalente := 0;
      -- para realizar ajustes si es necesario----------
      if v_cod_tra_ajuste is null then
        v_cod_tra_ajuste := cc.cod_transaccion;
      end if;
      -- obtengo los datos de la tasa-----------------
      PR_OBT_TIPO_DE_TASA(cc.cod_transaccion,
                          v_nmtrans,
                          cc.cod_tasa,
                          v_aplicar,
                          v_tpvlpor,
                          v_tpdetas,
                          v_obligatorio,
                          v_afecta);
      v_val_tas_cargo := FU_OBT_VALOR_DE_TASA_FIJA(cc.cod_tasa,
                                                   v_fec_inicio);
      IF cc.COD_TRANSACCION IS NOT NULL AND
         (cc.COD_MONEDA IS NULL OR
         (v_TPVLPOR = 'V' AND nvl(cc.MONTO, 0) = 0)) THEN
        RAISE_APPLICATION_ERROR(-20000,
                                'Valores nulos en Cargos. Verificar la Trans. ' ||
                                to_char(cc.cod_transaccion));
      END IF;
      IF v_TPVLPOR = 'P' THEN
        v_MTO_EQUIVALENTE := 0;
        --- la tasa es un porcentaje-----------------------------------------------------
        --IF v_APLICAR IN ('CI','IN','PI','IP','PT','TP') THEN ver!
        IF v_aplicar in ('CI', 'IN') then
          --- aplicable al interes -----------------------------------------------------
          v_MTO_EQUIVALENTE := ROUND(v_MTO_INTERES * /* v_DIA_PLAZO * */
                                     cc.val_tasa / 100,
                                     v_redondeo);
          --v_MTO_EQUIVALENTE :=  ROUND(v_MTO_INTERES * v_DIA_PLAZO * cc.val_tasa / 36500,v_redondeo);
        ELSIF v_APLICAR IN ('PI', 'IP', 'PT', 'TP') then
          v_mto_equivalente := round(v_mto_interes * v_dia_plazo *
                                     cc.val_tasa / 36500,
                                     v_redondeo);
        END IF;
        --IF v_APLICAR IN ('CA','CI','PC','CP','PT','TP') THEN
        IF v_APLICAR IN ('CA', 'CI', 'CP') THEN
          --- es aplicable al capital --------------------------------------------------
          v_MTO_EQUIVALENTE := NVL(v_MTO_EQUIVALENTE, 0) +
                               ROUND(v_TOT_PRESTAMO * /*v_DIA_PLAZO **/
                                     cc.val_tasa / 100,
                                     v_redondeo);
          --ROUND(v_TOT_PRESTAMO * v_DIA_PLAZO * cc.val_tasa / 36500,v_redondeo);
        ELSIF v_aplicar in ('PC', 'PT', 'TP') then
          v_mto_equivalente := nvl(v_mto_equivalente, 0) +
                               round(v_tot_prestamo * v_dia_plazo / 36500,
                                     v_redondeo);
        END IF;
        if nvl(v_mto_equivalente, 0) <= nvl(v_val_car_minimo, 0) then
          v_mto_equivalente := nvl(v_val_car_minimo, 0);
        end if;
      ELSIF v_TPVLPOR = 'I' THEN
        v_MTO_EQUIVALENTE := 0;
        ---v_cod_tra_ajuste  := cc.cod_transaccion; --siempre se ajusta si ha y impuesto
        --- la tasa es un impuesto ------------------------------------------------------
        IF v_APLICAR IN ('CI', 'IN', 'PI', 'IP', 'PT', 'TP') THEN
          --- aplicable al interes -----------------------------------------------------
          IF v_DIA_PLAZO < 365 THEN
            v_MTO_EQUIVALENTE := ROUND(v_MTO_INTERES * v_DIA_PLAZO *
                                       cc.val_tasa / 36500,
                                       v_redondeo);
          ELSE
            v_MTO_EQUIVALENTE := ROUND(v_MTO_INTERES * cc.val_tasa / 100,
                                       v_redondeo);
          END IF;
        END IF;
        IF v_APLICAR IN ('CA', 'CI', 'PC', 'CP', 'PT', 'TP') THEN
          --- es aplicable al capital --------------------------------------------------
          IF CC.COD_ENT_SEGURO IS NOT NULL THEN
            --- es un seguro ----------------------------------------------------------
            v_MTO_EQUIVALENTE := NVL(v_MTO_EQUIVALENTE, 0) +
                                 ROUND(v_TOT_PRESTAMO * cc.val_tasa / 100,
                                       v_redondeo);
          ELSE
            --- es un impuesto sobre el capital ---------------------------------------
            IF v_DIA_PLAZO < 365 THEN
              v_MTO_EQUIVALENTE := NVL(v_MTO_EQUIVALENTE, 0) +
                                   ROUND(v_TOT_PRESTAMO * v_DIA_PLAZO *
                                         cc.val_tasa / 36500,
                                         v_redondeo);
            ELSE
              v_MTO_EQUIVALENTE := NVL(v_MTO_EQUIVALENTE, 0) +
                                   ROUND(v_TOT_PRESTAMO * cc.val_tasa / 100,
                                         v_redondeo);
            END IF;
          END IF;
        END IF;
      ELSIF v_TPVLPOR = 'V' THEN
        --- es un monto valor -----------------------------------------------------------
        v_mto_equivalente := cc.monto;
        v_TTVALOR         := NVL(v_TTVALOR, 0) + NVL(v_MTO_EQUIVALENTE, 0);
      END IF;
      --- Acumular el total de cargos (Si el tipo es Valor viene directamente aqui -------
      if nvl(v_afecta, 'Z') <> 'G' then
        v_MTO_CARGO := NVL(v_MTO_CARGO, 0) + NVL(v_MTO_EQUIVALENTE, 0);
      end if;
      ------------------------------------------------------------------------------------
      v_monto := null;
      IF V_TPVLPOR IN ('I', 'P') THEN
        /* solo si es porcentaje */
        IF CC.COD_MONEDA = P_COD_MONEDA THEN
          -- moneda del cargo es igual a la moneda de la simulacion ----------------------
          V_MONTO := V_MTO_EQUIVALENTE;
        ELSE
          -- monedas diferentes, se divide por la cotiz. de la moneda de la simulacion ---
          V_MONTO := ROUND(V_MTO_EQUIVALENTE * v_cotizacion, v_redondeo);
        END IF;
      END IF;

      update pr_sim_cargos
         set MTO_EQUIVALENTE = NVL(v_MTO_EQUIVALENTE, 0),
             monto           = nvl(v_monto, monto)
       where current of cargos;

    END LOOP;
    IF v_MTO_CARGO >= v_TOT_PRESTAMO THEN
      RAISE_APPLICATION_ERROR(-20000,
                              'ERROR. Total de Cargos ' || v_MTO_CARGO ||
                              ' es superior al Total del Préstamo ' ||
                              v_TOT_PRESTAMO);
    ELSE
      IF P_TIP_MONTO = 'N' AND V_TOT_PRESTAMO <> P_MONTO THEN
        --- ya estoy en el ultimo calculo de cargos netos, veo si hay ajuste --------
        IF NVL(V_TOT_PRESTAMO, 0) - NVL(V_MTO_CARGO, 0) <> P_MONTO THEN
          -- es necesario un ajuste en el cargo del impuesto o primer cargo      ---
          ww_dfcargos := P_MONTO -
                         (NVL(V_TOT_PRESTAMO, 0) - NVL(V_MTO_CARGO, 0));
          for cc in cargos loop
            if cc.cod_transaccion = 704 then
              v_mto_equivalente := NVL(V_MTO_EQUIVALENTE, 0) - ww_dfcargos;
              v_mto_cargo       := NVL(V_MTO_CARGO, 0) - ww_dfcargos;
              update pr_sim_cargos
                 set MTO_EQUIVALENTE = NVL(MTO_EQUIVALENTE, 0) -
                                       nvl(ww_dfcargos, 0),
                     monto           = decode(cod_moneda,
                                              p_cod_moneda,
                                              NVL(MTO_EQUIVALENTE, 0) -
                                              nvl(ww_dfcargos, 0),
                                              decode(cod_moneda,
                                                     v_mon_local,
                                                     round(((NVL(MTO_EQUIVALENTE,
                                                                 0) -
                                                           nvl(ww_dfcargos,
                                                                 0)) *
                                                           v_cotizacion),
                                                           v_redondeo),
                                                     round(((NVL(MTO_EQUIVALENTE,
                                                                 0) -
                                                           nvl(ww_dfcargos,
                                                                 0)) *
                                                           v_cotizacion),
                                                           v_redondeo)))
               where nro_simulacion = v_nro_simulacion
                 and cod_transaccion = cc.cod_transaccion;
            end if;
          end loop;
        END IF;
      END IF;
    END IF;

    -- actualizo el total de cargos
    update pr_simulaciones
       set tot_cargos = v_mto_cargo
     where nro_simulacion = v_nro_simulacion;

  EXCEPTION
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20000, 'CALCULAR_CARGOS ' || SQLERRM);
  END;

  PROCEDURE PR_VAL_MTO_PLAZO IS
    v_cuota pr_cuotas.nro_cuota%type;
    v_monto pr_cta_prestamos.monto%type;
  BEGIN
  if nvl(v_especial,'N')='N' then
   if p_can_cuotas > rg_aprobados.max_plazo then
      v_mensaje := 'La cantidad de cuotas no puede ser    mayor a '||
      trim(to_char(rg_aprobados.max_plazo,'99G999G999G990','NLS_NUMERIC_CHARACTERS = ''.,'''));
      raise salir;
    elsif p_can_cuotas < rg_aprobados.min_plazo then
      v_mensaje := 'La cantidad de cuotas no puede ser    menor a '||
      trim(to_char(rg_aprobados.min_plazo,'99G999G999G990','NLS_NUMERIC_CHARACTERS = ''.,'''));
      raise salir;
    end if;
     -- obtenemos el plazo minimo en base a definiciones de plazos
    IF p_monto < rg_aprobados.min_monto then
       v_mensaje := 'Monto no puede ser menor al minimo    establecido '||
       trim(to_char(rg_aprobados.min_monto,'99G999G999G990','NLS_NUMERIC_CHARACTERS = ''.,'''));
       raise salir;
    ELSIF p_monto > rg_aprobados.max_monto then
       v_mensaje := 'Monto no puede ser mayor al maximo    establecido '||
       trim(to_char(rg_aprobados.max_monto,'99G999G999G990','NLS_NUMERIC_CHARACTERS = ''.,'''));
       raise salir;
    ELSIF (p_monto > rg_aprobados.min_monto and p_monto <= rg_aprobados.plz_12_meses)
          and (p_can_cuotas >= rg_aprobados.min_plazo and p_can_cuotas <= rg_aprobados.max_plazo) THEN
       v_cuota := p_can_cuotas;
       v_monto := p_monto;
    ELSIF (p_monto > rg_aprobados.plz_12_meses and p_monto <= rg_aprobados.plz_18_meses)
          and ( p_can_cuotas > 12 and p_can_cuotas <= rg_aprobados.max_plazo) THEN
       v_cuota := p_can_cuotas;
       v_monto := p_monto;
    ELSIF (p_monto > rg_aprobados.plz_18_meses and p_monto <= rg_aprobados.plz_24_meses)
          and ( p_can_cuotas > 18 and p_can_cuotas <= rg_aprobados.max_plazo) THEN
       v_cuota := p_can_cuotas;
       v_monto := p_monto;
    ELSIF (p_monto > rg_aprobados.plz_24_meses and p_monto <= rg_aprobados.plz_30_meses)
          and ( p_can_cuotas > 24 and p_can_cuotas <= rg_aprobados.max_plazo) THEN
       v_cuota := p_can_cuotas;
       v_monto := p_monto;
    ELSIF (p_monto > rg_aprobados.plz_30_meses and p_monto <= rg_aprobados.plz_36_meses)
          and ( p_can_cuotas > 30 and p_can_cuotas <= rg_aprobados.max_plazo) THEN
       v_cuota := p_can_cuotas;
       v_monto := p_monto;
    ELSIF (p_monto > rg_aprobados.plz_36_meses and p_monto <= rg_aprobados.plz_42_meses)
          and ( p_can_cuotas > 36 and p_can_cuotas <= rg_aprobados.max_plazo) THEN
       v_cuota := p_can_cuotas;
       v_monto := p_monto;
    ELSIF (p_monto > rg_aprobados.plz_42_meses and p_monto <= rg_aprobados.plz_48_meses)
          and ( p_can_cuotas > 42 and p_can_cuotas <= rg_aprobados.max_plazo) THEN
       v_cuota := p_can_cuotas;
       v_monto := p_monto;
    ELSIF (p_monto > rg_aprobados.plz_48_meses and p_monto <= rg_aprobados.plz_54_meses)
          and ( p_can_cuotas > 48 and p_can_cuotas <= rg_aprobados.max_plazo) THEN
       v_cuota := p_can_cuotas;
       v_monto := p_monto;
    ELSIF (p_monto > rg_aprobados.plz_54_meses and p_monto <= rg_aprobados.plz_60_meses)
          and ( p_can_cuotas > 54 and p_can_cuotas <= rg_aprobados.max_plazo) THEN
       v_cuota := p_can_cuotas;
       v_monto := p_monto;
    ELSIF p_monto > rg_aprobados.plz_60_meses THEN
       v_mensaje := 'Monto no puede ser mayor al maximo    establecido '||
       trim(to_char(rg_aprobados.plz_60_meses,'99G999G999G990','NLS_NUMERIC_CHARACTERS = ''.,'''));
       raise salir;
    ELSE
        IF (p_monto > rg_aprobados.min_monto and p_monto <= rg_aprobados.plz_12_meses) THEN
           v_cuota := rg_aprobados.min_plazo;
           v_monto := p_monto;
           v_mensaje := 'Ya supera su capacidad de pago. Para  el monto selccionado la cantidad de   cuotas debe ser mayor a '||v_cuota;
           raise salir;
        ELSIF (p_monto > rg_aprobados.plz_12_meses and p_monto <= rg_aprobados.plz_18_meses) THEN
           v_cuota := 13;
           v_monto := p_monto;
           v_mensaje := 'Ya supera su capacidad de pago. Para  el monto selccionado la cantidad de   cuotas debe ser mayor a '||v_cuota;
           raise salir;
        ELSIF (p_monto > rg_aprobados.plz_18_meses and p_monto <= rg_aprobados.plz_24_meses) THEN
           v_cuota := 19;
           v_monto := p_monto;
           v_mensaje := 'Ya supera su capacidad de pago. Para  el monto selccionado la cantidad de   cuotas debe ser mayor a '||v_cuota;
           raise salir;
        ELSIF (p_monto > rg_aprobados.plz_24_meses and p_monto <= rg_aprobados.plz_30_meses) THEN
           v_cuota := 25;
           v_monto := p_monto;
           v_mensaje := 'Ya supera su capacidad de pago. Para  el monto selccionado la cantidad de   cuotas debe ser mayor a '||v_cuota;
           raise salir;
        ELSIF (p_monto > rg_aprobados.plz_30_meses and p_monto <= rg_aprobados.plz_36_meses) THEN
           v_cuota := 31;
           v_monto := p_monto;
           v_mensaje := 'Ya supera su capacidad de pago. Para  el monto selccionado la cantidad de   cuotas debe ser mayor a '||v_cuota;
           raise salir;
        ELSIF (p_monto > rg_aprobados.plz_36_meses and p_monto <= rg_aprobados.plz_42_meses) THEN
           v_cuota := 37;
           v_monto := p_monto;
           v_mensaje := 'Ya supera su capacidad de pago. Para  el monto selccionado la cantidad de   cuotas debe ser mayor a '||v_cuota;
           raise salir;
        ELSIF (p_monto > rg_aprobados.plz_42_meses and p_monto <= rg_aprobados.plz_48_meses) THEN
           v_cuota := 43;
           v_monto := p_monto;
           v_mensaje := 'Ya supera su capacidad de pago. Para  el monto selccionado la cantidad de   cuotas debe ser mayor a '||v_cuota;
           raise salir;
        ELSIF (p_monto > rg_aprobados.plz_48_meses and p_monto <= rg_aprobados.plz_54_meses) THEN
           v_cuota := 49;
           v_monto := p_monto;
           v_mensaje := 'Ya supera su capacidad de pago. Para  el monto selccionado la cantidad de   cuotas debe ser mayor a '||v_cuota;
           raise salir;
        ELSIF (p_monto > rg_aprobados.plz_54_meses and p_monto <= rg_aprobados.plz_60_meses) THEN
           v_cuota := 55;
           v_monto := p_monto;
           v_mensaje := 'Ya supera su capacidad de pago. Para  el monto selccionado la cantidad de   cuotas debe ser mayor a '||v_cuota;
           raise salir;
        END IF;
    END IF;

   ELSE
      --CORRESPONDE A UN PRESTAMO ESPECIAL, FECHA DE PRIMERA CUOTA CAMBIADA
    if p_can_cuotas > (rg_aprobados.max_plazo)+1 then
      v_mensaje := 'La cantidad de cuotas no puede ser    mayor a '||
      trim(to_char(rg_aprobados.max_plazo,'99G999G999G990','NLS_NUMERIC_CHARACTERS = ''.,'''));
      raise salir;
    elsif p_can_cuotas < rg_aprobados.min_plazo then
      v_mensaje := 'La cantidad de cuotas no puede ser    menor a '||
      trim(to_char(rg_aprobados.min_plazo,'99G999G999G990','NLS_NUMERIC_CHARACTERS = ''.,'''));
      raise salir;
    end if;
    ---
      -- obtenemos el plazo minimo en base a definiciones de plazos
    IF p_monto < rg_aprobados.min_monto then
       v_mensaje := 'Monto no puede ser menor al minimo    establecido '||
       trim(to_char(rg_aprobados.min_monto,'99G999G999G990','NLS_NUMERIC_CHARACTERS = ''.,'''));
       raise salir;
    ELSIF p_monto > rg_aprobados.max_monto then
       v_mensaje := 'Monto no puede ser mayor al maximo    establecido '||
       trim(to_char(rg_aprobados.max_monto,'99G999G999G990','NLS_NUMERIC_CHARACTERS = ''.,'''));
       raise salir;
    ELSIF (p_monto > rg_aprobados.min_monto and p_monto <= rg_aprobados.plz_12_meses)
          and (p_can_cuotas >= rg_aprobados.min_plazo and p_can_cuotas <= rg_aprobados.max_plazo+1) THEN
       v_cuota := p_can_cuotas;
       v_monto := p_monto;
    ELSIF (p_monto > rg_aprobados.plz_12_meses and p_monto <= rg_aprobados.plz_18_meses)
          and ( p_can_cuotas > 12 and p_can_cuotas <= rg_aprobados.max_plazo+1) THEN
       v_cuota := p_can_cuotas;
       v_monto := p_monto;
    ELSIF (p_monto > rg_aprobados.plz_18_meses and p_monto <= rg_aprobados.plz_24_meses)
          and ( p_can_cuotas > 18 and p_can_cuotas <= rg_aprobados.max_plazo+1) THEN
       v_cuota := p_can_cuotas;
       v_monto := p_monto;
    ELSIF (p_monto > rg_aprobados.plz_24_meses and p_monto <= rg_aprobados.plz_30_meses)
          and ( p_can_cuotas > 24 and p_can_cuotas <= rg_aprobados.max_plazo+1) THEN
       v_cuota := p_can_cuotas;
       v_monto := p_monto;
    ELSIF (p_monto > rg_aprobados.plz_30_meses and p_monto <= rg_aprobados.plz_36_meses)
          and ( p_can_cuotas > 30 and p_can_cuotas <= rg_aprobados.max_plazo+1) THEN
       v_cuota := p_can_cuotas;
       v_monto := p_monto;
    ELSIF (p_monto > rg_aprobados.plz_36_meses and p_monto <= rg_aprobados.plz_42_meses)
          and ( p_can_cuotas > 36 and p_can_cuotas <= rg_aprobados.max_plazo+1) THEN
       v_cuota := p_can_cuotas;
       v_monto := p_monto;
    ELSIF (p_monto > rg_aprobados.plz_42_meses and p_monto <= rg_aprobados.plz_48_meses)
          and ( p_can_cuotas > 42 and p_can_cuotas <= rg_aprobados.max_plazo) THEN
       v_cuota := p_can_cuotas;
       v_monto := p_monto;
    ELSIF (p_monto > rg_aprobados.plz_48_meses and p_monto <= rg_aprobados.plz_54_meses)
          and ( p_can_cuotas > 48 and p_can_cuotas <= rg_aprobados.max_plazo+1) THEN
       v_cuota := p_can_cuotas;
       v_monto := p_monto;
    ELSIF (p_monto > rg_aprobados.plz_54_meses and p_monto <= rg_aprobados.plz_60_meses)
          and ( p_can_cuotas > 54 and p_can_cuotas <= rg_aprobados.max_plazo+1) THEN
       v_cuota := p_can_cuotas;
       v_monto := p_monto;
    ELSIF p_monto > rg_aprobados.plz_60_meses THEN
       v_mensaje := 'Monto no puede ser mayor al maximo    establecido '||
       trim(to_char(rg_aprobados.plz_60_meses,'99G999G999G990','NLS_NUMERIC_CHARACTERS = ''.,'''));
       raise salir;
    ELSE
        IF (p_monto > rg_aprobados.min_monto and p_monto <= rg_aprobados.plz_12_meses) THEN
           v_cuota := rg_aprobados.min_plazo;
           v_monto := p_monto;
           v_mensaje := 'Ya supera su capacidad de pago. Para  el monto selccionado la cantidad de   cuotas debe ser mayor a '||v_cuota;
           raise salir;
        ELSIF (p_monto > rg_aprobados.plz_12_meses and p_monto <= rg_aprobados.plz_18_meses) THEN
           v_cuota := 13;
           v_monto := p_monto;
           v_mensaje := 'Ya supera su capacidad de pago. Para  el monto selccionado la cantidad de   cuotas debe ser mayor a '||v_cuota;
           raise salir;
        ELSIF (p_monto > rg_aprobados.plz_18_meses and p_monto <= rg_aprobados.plz_24_meses) THEN
           v_cuota := 19;
           v_monto := p_monto;
           v_mensaje := 'Ya supera su capacidad de pago. Para  el monto selccionado la cantidad de   cuotas debe ser mayor a '||v_cuota;
           raise salir;
        ELSIF (p_monto > rg_aprobados.plz_24_meses and p_monto <= rg_aprobados.plz_30_meses) THEN
           v_cuota := 25;
           v_monto := p_monto;
           v_mensaje := 'Ya supera su capacidad de pago. Para  el monto selccionado la cantidad de   cuotas debe ser mayor a '||v_cuota;
           raise salir;
        ELSIF (p_monto > rg_aprobados.plz_30_meses and p_monto <= rg_aprobados.plz_36_meses) THEN
           v_cuota := 31;
           v_monto := p_monto;
           v_mensaje := 'Ya supera su capacidad de pago. Para  el monto selccionado la cantidad de   cuotas debe ser mayor a '||v_cuota;
           raise salir;
        ELSIF (p_monto > rg_aprobados.plz_36_meses and p_monto <= rg_aprobados.plz_42_meses) THEN
           v_cuota := 37;
           v_monto := p_monto;
           v_mensaje := 'Ya supera su capacidad de pago. Para  el monto selccionado la cantidad de   cuotas debe ser mayor a '||v_cuota;
           raise salir;
        ELSIF (p_monto > rg_aprobados.plz_42_meses and p_monto <= rg_aprobados.plz_48_meses) THEN
           v_cuota := 43;
           v_monto := p_monto;
           v_mensaje := 'Ya supera su capacidad de pago. Para  el monto selccionado la cantidad de   cuotas debe ser mayor a '||v_cuota;
           raise salir;
        ELSIF (p_monto > rg_aprobados.plz_48_meses and p_monto <= rg_aprobados.plz_54_meses) THEN
           v_cuota := 49;
           v_monto := p_monto;
           v_mensaje := 'Ya supera su capacidad de pago. Para  el monto selccionado la cantidad de   cuotas debe ser mayor a '||v_cuota;
           raise salir;
        ELSIF (p_monto > rg_aprobados.plz_54_meses and p_monto <= rg_aprobados.plz_60_meses) THEN
           v_cuota := 55;
           v_monto := p_monto;
           v_mensaje := 'Ya supera su capacidad de pago. Para  el monto selccionado la cantidad de   cuotas debe ser mayor a '||v_cuota;
           raise salir;
        END IF;
    END IF;
    end if;

  END;
  -- DDEVOLUT-1234 - Validamos el monto maximo pre aprobado contra las cuotas-----------------------------------------------------
  PROCEDURE PR_VAL_MTO_MAX_CUOTA IS
    BEGIN
      FOR cuo IN pag_pre.gc_sim_cuotas( v_nro_simulacion ) LOOP
        v_cargo := pag_pre.fu_obt_mto_cargo(v_nro_simulacion, cuo.nro_cuota - 1);
        v_cuo_total :=  nvl(cuo.mto_cuota, 0) + nvl(v_cargo, 0);
         IF nvl(rg_aprobados.mto_max_cuota,0) <  v_cuo_total THEN
            v_mensaje := 'Se sobrepasó el monto máximo de cuota pre-aprobada - Mto. Cuota: '|| v_cuo_total||
             ', Mto. Máximo: '|| rg_aprobados.mto_max_cuota ||
             ', Nro. Cuota: ' || cuo.nro_cuota;                 
            raise salir;
         END IF;
      END LOOP;
  END;
  
  -- INICIO DEL PROCEDIMIENTO PRINCIPAL----------------------------------------
begin
  v_mensaje := null;
  -- BSEVOCORE-367 log en bw_bitacora para seguimiento de errores de calculo de comision 
  paw_uti.pr_insertarbitacora( p_cod_persona,
                               '999',
                               p_cod_persona,
                               100,
                               null,
                               'PRP_GEN_ATM_SIMULACION: ' || p_cod_persona || ',' || p_cod_modalidad || ',' ||
                                p_cod_moneda || ',' || p_monto || ',' || p_can_cuotas || ',' || p_tip_monto || ',' || 
                                p_fec_inicio || ',' || p_fec_pri_vencimiento || ',' || p_val_tasa || ',' || p_cod_canal || ',' || 
                                p_cod_campana || ',' || p_descripcion || ',' || p_nro_cta_debito || ',' || v_mensaje,
                               'INF');                            
  --Verificamos si es normal especial
  v_especial:='N';
  if v_fec_pri_vencimiento_ori <> v_fec_pri_vencimiento then
    v_especial:='S';
  end if;

  --verificar que no exceda el monto maximo de y cantidad de cuotas definidas
  BEGIN
    select a.mto_max_cuota,a.plz_12_meses,a.plz_18_meses,a.plz_24_meses,a.plz_30_meses,a.plz_36_meses,
           a.plz_42_meses,a.plz_48_meses,a.plz_54_meses,a.plz_60_meses,a.min_plazo, a.max_plazo, a.min_monto, a.max_monto
           ,/*nvl(a.max_monto, 0), nvl(a.min_monto, 0),
           a.max_plazo, a.min_plazo,*/
           a.cod_campana,
           a.cod_sub_modalidad  -- PCCFPPTC-1 -- 10/2016 --
      into rg_aprobados.mto_max_cuota,rg_aprobados.plz_12_meses,rg_aprobados.plz_18_meses,rg_aprobados.plz_24_meses,rg_aprobados.plz_30_meses,rg_aprobados.plz_36_meses,
           rg_aprobados.plz_42_meses,rg_aprobados.plz_48_meses,rg_aprobados.plz_54_meses,rg_aprobados.plz_60_meses,rg_aprobados.min_plazo, rg_aprobados.max_plazo,
           rg_aprobados.min_monto, rg_aprobados.max_monto
           ,/*nvl(a.max_monto, 0), nvl(a.min_monto, 0),
           a.max_plazo, a.min_plazo,*/
           rg_aprobados.cod_campana
           /*v_max_monto, v_min_monto,
           v_max_plazo, v_min_plazo,
           v_cod_campana*/
           , rg_aprobados.cod_sub_modalidad -- PCCFPPTC-1 -- 10/2016 --
      from ge_pro_pre_aprobados a
     where a.cod_persona = p_cod_persona
       and a.estado = 'V'
       and a.cod_modulo = 6
       and a.cod_modalidad = p_cod_modalidad -- PCCFPPTC-1 -- 10/2016 --
       and nvl(fug_obt_pardinamico('MOD_PRE_APR_ATM_WEB',a.cod_modulo,a.cod_modalidad),'N') = 'S'
       and (v_user = v_usu_hb and nvl(a.ind_hab_hb,'N') = 'S' or -- HBANK
            substr(v_user,1,3) = v_usu_atm and nvl(a.ind_hab_atm,'N') = 'S')  -- ATM
       and a.nro_solicitud is null
       and ( a.cod_campana in( select distinct c.cod_campana
                                 from cr_campanas c
                                where v_fec_actual >= c.fec_inicio
                                  and ( v_fec_actual <= c.fec_vencimiento or c.fec_vencimiento is null )
                                   )
             or a.cod_campana is null )
       and a.lote = ( select max(x.lote)
                        from ge_pro_pre_aprobados x
                       where x.cod_persona = a.cod_persona
                         and x.estado = 'V'
                         and x.cod_modulo = a.cod_modulo
                         and x.cod_modalidad = p_cod_modalidad
                         and fug_obt_pardinamico('MOD_PRE_APR_ATM_WEB',a.cod_modulo,a.cod_modalidad) = 'S'
                         and (v_user = v_usu_hb and nvl(a.ind_hab_hb,'N') = 'S' or  -- HBANK
                              substr(v_user,1,3) = v_usu_atm and nvl(a.ind_hab_atm,'N') = 'S') -- ATM
                         and x.nro_solicitud is null
                         and ( x.cod_campana = a.cod_campana
                               or x.cod_campana is null ) )
       and rownum = 1;

   v_cod_sub_modalidad:= nvl(rg_aprobados.cod_sub_modalidad,nvl(fug_obt_pardinamico('COD_SUB_MAD_PRE_APR',6,p_cod_modalidad),10));

    -- obtenemos el plazo minimo en base a definiciones de plazos
        IF nvl(rg_aprobados.plz_12_meses, 0) > 0 AND rg_aprobados.max_plazo >= 12 THEN
           rg_aprobados.min_plazo := 12;
        ELSIF nvl(rg_aprobados.plz_18_meses, 0) > 0 AND rg_aprobados.max_plazo >= 18 THEN
           rg_aprobados.min_plazo := 18;
        ELSIF nvl(rg_aprobados.plz_24_meses, 0) > 0 AND rg_aprobados.max_plazo >= 24 THEN
           rg_aprobados.min_plazo := 24;
        ELSIF nvl(rg_aprobados.plz_30_meses, 0) > 0 AND rg_aprobados.max_plazo >= 30 THEN
           rg_aprobados.min_plazo := 30;
        ELSIF nvl(rg_aprobados.plz_36_meses, 0) > 0 AND rg_aprobados.max_plazo >= 36 THEN
           rg_aprobados.min_plazo := 36;
        ELSIF nvl(rg_aprobados.plz_42_meses, 0) > 0 AND rg_aprobados.max_plazo >= 42 THEN
           rg_aprobados.min_plazo := 42;
        ELSIF nvl(rg_aprobados.plz_48_meses, 0) > 0 AND rg_aprobados.max_plazo >= 48 THEN
           rg_aprobados.min_plazo := 48;
        ELSIF nvl(rg_aprobados.plz_54_meses, 0) > 0 AND rg_aprobados.max_plazo >= 54 THEN
           rg_aprobados.min_plazo := 54;
        ELSIF nvl(rg_aprobados.plz_60_meses, 0) > 0 AND rg_aprobados.max_plazo >= 60 THEN
           rg_aprobados.min_plazo := 60;
        END IF;
    -- obtenemos el monto maximo en base a definiciones de plazos
        IF rg_aprobados.plz_60_meses IS NOT NULL and rg_aprobados.max_plazo >= 60 THEN
           rg_aprobados.max_monto := rg_aprobados.plz_60_meses;
        ELSIF rg_aprobados.plz_54_meses IS NOT NULL and rg_aprobados.max_plazo >= 54 THEN
           rg_aprobados.max_monto := rg_aprobados.plz_54_meses;
        ELSIF rg_aprobados.plz_48_meses IS NOT NULL and rg_aprobados.max_plazo >= 48 THEN
           rg_aprobados.max_monto := rg_aprobados.plz_48_meses;
        ELSIF rg_aprobados.plz_42_meses IS NOT NULL and rg_aprobados.max_plazo >= 42 THEN
           rg_aprobados.max_monto := rg_aprobados.plz_42_meses;
        ELSIF rg_aprobados.plz_36_meses IS NOT NULL and rg_aprobados.max_plazo >= 36 THEN
           rg_aprobados.max_monto := rg_aprobados.plz_36_meses;
        ELSIF rg_aprobados.plz_30_meses IS NOT NULL and rg_aprobados.max_plazo >= 30 THEN
           rg_aprobados.max_monto := rg_aprobados.plz_30_meses;
        ELSIF rg_aprobados.plz_24_meses IS NOT NULL and rg_aprobados.max_plazo >= 24 THEN
           rg_aprobados.max_monto := rg_aprobados.plz_24_meses;
        ELSIF rg_aprobados.plz_18_meses IS NOT NULL and rg_aprobados.max_plazo >= 18 THEN
           rg_aprobados.max_monto := rg_aprobados.plz_18_meses;
        ELSIF rg_aprobados.plz_12_meses IS NOT NULL and rg_aprobados.max_plazo >= 12 THEN
           rg_aprobados.max_monto := rg_aprobados.plz_12_meses;
        END IF;
    --procedimiento para verificar
    PR_VAL_MTO_PLAZO;
    /*if p_monto > v_max_monto then
      v_mensaje := 'Monto no puede ser mayor al maximo establecido '||
      trim(to_char(v_max_monto,'99G999G999G990','NLS_NUMERIC_CHARACTERS = ''.,'''));
      raise salir;
\*
      raise_application_error(-20000,
                              'Monto no puede ser mayor al maximo establecido ' ||
                              v_max_monto);
*\
    elsif p_monto < v_min_monto then
      v_mensaje := 'Monto no puede ser menor al minimo establecido '||
      trim(to_char(v_min_monto,'99G999G999G990','NLS_NUMERIC_CHARACTERS = ''.,'''));
      raise salir;
\*
      raise_application_error(-20000,
                              'Monto no puede ser menor al minimo establecido ' ||
                              v_min_monto);
*\
    elsif p_can_cuotas > v_max_plazo then
      v_mensaje := 'La cantidad de cuotas no puede ser mayor a '||
      trim(to_char(v_max_plazo,'99G999G999G990','NLS_NUMERIC_CHARACTERS = ''.,'''));
      raise salir;
\*
      raise_application_error(-20000,
                              'La cantidad de cuotas no puede ser mayor a ' ||
                              v_max_plazo);
*\
    elsif p_can_cuotas < v_min_plazo then
      v_mensaje := 'La cantidad de cuotas no puede ser menor a  '||
      trim(to_char(v_min_plazo,'99G999G999G990','NLS_NUMERIC_CHARACTERS = ''.,'''));
      raise salir;
\*
      raise_application_error(-20000,
                              'La cantidad de cuotas no puede ser menor a ' ||
                              v_min_plazo);
*\
    end if;*/
  EXCEPTION
    when no_data_found then
      null; --si no encuentra no es cliente pre-aprobado
  END;
  --- Veo el tipo de redondeo de los calculos ------------------------------------------
  IF P_COD_MONEDA <> V_MON_LOCAL THEN
    v_limite := 0.05;
  END IF;
  v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                                    6,
                                    p_cod_modalidad,
                                    p_cod_moneda);
  -- Valido el codigo del cliente-------------------------------------------
  PR_VAL_COD_PERSONA;
  -- Valido el codigo de la modalidad que recibo----------------------------
  PR_VAL_COD_MODALIDAD;
  -- valido la moneda-------------------------------------------------------
  PR_VAL_COD_MONEDA;
  -- valido el monto -------------------------------------------------------
  IF NVL(p_monto, 0) <= 0 THEN
    RAISE_APPLICATION_ERROR(-20000, 'ERROR. Ingrese Monto del Credito');
  END IF;
  v_tot_prestamo := p_monto;
  -- valido el tipo de monto -----------------------------------------------
  IF nvl(p_tip_monto, 'X') not in ('B', 'N') then
    RAISE_APPLICATION_ERROR(-20000,
                            'ERROR. Tipo de Monto debe ser B-Bruto o N-Neto');
  END IF;
  -- valido la cantidad de cuotas ------------------------------------------
  IF nvl(p_can_cuotas, 0) < 1 then
    RAISE_APPLICATION_ERROR(-20000, 'ERROR. Ingrese la cantidad de cuotas');
  END IF;
  -- Valido la fecha del primer vencimiento --------------------------------
  IF v_fec_pri_vencimiento <= v_fec_actual and p_cod_modalidad <> 660 THEN
    RAISE_APPLICATION_ERROR(-20000,
                            'ERROR. Primer Vencimiento debe ser posterior a la fecha de Hoy');
  END IF;
  -- Cargo los datos por defecto de la tabla de parametros -----------------
  declare
    x_val_tasa number;
  Begin
    Select tip_interes,
           tip_amortizacion,
           aju_ult_cuota,
           tip_aju_fecha,
           aju_gracia,
           cod_sec_credito,
           cod_departamento,
           tip_documento,
           tipo,
           val_tasa
      into v_tip_interes,
           v_tip_amortizacion,
           v_aju_ult_cuota,
           v_tip_aju_fecha,
           v_aju_gracia,
           v_cod_sec_credito,
           v_cod_dep_parametro,
           v_tip_documento,
           v_tipo,
           x_val_tasa
      from pr_sol_parametros
     where cod_modulo = v_cod_modulo
       and cod_modalidad = p_cod_modalidad
       and (cod_canal = p_cod_canal or cod_canal is null)
       and (cod_campana = v_cod_campana or cod_campana is null);
    -- si se habilito la tasa de interes por defecto, se carga
    if nvl(x_val_tasa, 0) > 0 and p_val_tasa is null then
      v_val_tasa := x_val_tasa;
    end if;
  exception
    when no_data_found then
      v_tip_interes       := 'V';
      v_tip_amortizacion  := 'P';
      v_aju_ult_cuota     := 'N';
      v_tip_aju_fecha     := 'E';
      v_aju_gracia        := 'N';
      v_cod_sec_credito   := 1;
      v_tip_documento     := 1;
      v_tipo              := 'A';
      v_cod_dep_parametro := 3;
  end;
  --
  v_dia_plazo   := ADD_MONTHS(v_fec_pri_vencimiento, p_can_cuotas - 1) -
                   v_fec_inicio;
  v_per_gracia  := v_fec_pri_vencimiento - v_fec_inicio;
  v_per_capital := 30;

  -- Valido la tasa de interes ---------------------------------------------
  PR_VAL_TASA;
  -- Asigno el nro de la simulacion -----------------------------------------
  IF v_nro_simulacion IS NULL THEN
    --- genero el siguiente numero de simulacion -------------------------------
    SELECT S_NRO_SIMULACION.NEXTVAL INTO v_nro_simulacion FROM DUAL;
  END IF;

  ---- Origen de Fondos
  if p_cod_moneda IS NOT NULL and p_cod_modalidad is not null THEN
    v_ori_fondo := nvl(FUP_OBT_ORI_FON_MODALIDAD(p_cod_modalidad,
                                                 p_cod_moneda),
                       0);
  end if;

  if v_ori_fondo = 0 then
    v_ori_fondo     := fug_obt_pardinamico('COD_ORI_FON_DESEMB',
                                           v_cod_modulo,
                                           p_cod_modalidad,
                                           p_cod_moneda,
                                           v_cod_oficina);
    v_por_ori_fondo := 100;
  end if;

  if p_nro_cta_debito is not null then
    --verificar que corresponda al cliente
    declare
      v_existe number := 0;
    begin
      select count(ct.NRO_CUENTA)
        into v_existe
        from ge_cuentas ct, GE_CTA_CLIENTES cl
       where ct.ESTADO in ('I', 'N', 'A', 'X', 'S')
         and ct.NRO_CUENTA = cl.NRO_CUENTA
         and cl.COD_PERSONA = p_cod_persona
         and cl.nro_cuenta = p_nro_cta_debito
         and cl.relacion = 'P'
         and ct.cod_modulo in (3, 4)
         and ct.cod_modalidad in (31, 41)
         and ct.cod_moneda = p_cod_moneda;
      if v_existe = 0 then
        raise_application_error(-20000,
                                'Nro. de cuenta debito no corresponde al cliente: ' ||
                                p_cod_persona);
      else
        v_nro_cta_debito := p_nro_cta_debito;
        v_deb_automatico := 'S';
      end if;
    exception
      when no_data_found then
        raise_application_error(-20000,
                                'Nro. de cuenta debito no corresponde al cliente: ' ||
                                p_cod_persona);
    end;
  end if;

  -- inserto el registro en la tabla de simulaciones ------------------------
  begin
    insert into pr_simulaciones
      (nro_simulacion,
       descripcion,
       monto,
       can_cuotas,
       tip_amortizacion,
       val_tasa,
       tot_interes,
       per_vto_capital,
       cod_persona,
       fec_inicio,
       tip_monto,
       tot_prestamo,
       cod_modulo,
       cod_modalidad,
       cod_sub_modalidad,
       cod_moneda,
       fec_pri_vencimiento,
       tip_renovacion,
       nro_cuenta,
       iva_desglose)
    values
      (v_nro_simulacion,
       nvl(p_descripcion, '.'),
       p_monto,
       p_can_cuotas,
       v_tip_amortizacion,
       v_val_tasa,
       v_mto_interes,
       v_per_capital,
       p_cod_persona,
       v_fec_inicio,
       p_tip_monto,
       v_tot_prestamo,
       v_cod_modulo,
       p_cod_modalidad,
       v_cod_sub_modalidad,
       p_cod_moneda,
       v_fec_pri_vencimiento,
       'A',
       v_nro_cta_debito,
       'S');

  exception
    when others then
      --dbms_output.put_line('Pr_solicitudes '||sqlerrm);
      raise_application_error(-20001, 'Insert PR_SIMULACIONES ' || sqlerrm);
  end;
  -- genero los cargos por defecto
  PR_GEN_CARGOS;
  -- generar cuotas --------------------------------------------------------
  --Si es especial llamamos a otro proceso
   if v_especial ='N' then
      PR_GEN_CUOTAS;
   else
      PR_GEN_CUOTAS_ESP(v_especial);
   end if;
  -- Calculo los cargos ----------------------------------------------------
  PR_CAL_CARGOS;
  -- verifico el tipo de prestamo
  if p_tip_monto = 'B' then
    v_tot_prestamo := p_monto;
  ELSE
    --- monto ingresado es el neto -----------------------------------------------------
    --- factor =(monto neto - cargos en %) * 100 / (monto neto + cargos fijos en monto)-
    v_por_ajuste := (P_MONTO - (V_MTO_CARGO - V_TTVALOR)) * 100 /
                    (P_MONTO + V_TTVALOR);
    --- calculo del nuevo capital (monto bruto -----------------------------------------
    V_TOT_PRESTAMO := ROUND((P_MONTO * 100 / v_por_ajuste), v_redondeo);
    --- Vuelvo a generar las cuotas y calcular los cargos ------------------------------
    PR_GEN_CUOTAS;
    -- recalculo los cargos ------------------------------------------------------------
    PR_CAL_CARGOS;
    -- actualizo el total -------------------------------------------------
    update pr_simulaciones
       set tot_prestamo = v_tot_prestamo
     where nro_simulacion = v_nro_simulacion;

  END IF;
  -- finalmente inserto la cuota 0 ------------------------------------------------------
  begin
    insert into pr_sim_cuotas
      (nro_simulacion,
       nro_cuota,
       fec_vencimiento,
       mto_interes,
       mto_refuerzo,
       mto_capital,
       sal_anterior,
       per_dias)
    values
      (v_nro_simulacion, 0, V_FEC_INICIO, 0, 0, 0, V_TOT_PRESTAMO, 0);
  EXCEPTION
    WHEN OTHERS THEN
      raise_application_error(-20001,
                              'Error al insertar cuotas ' || sqlerrm);
  END;
  --Ajustamos el valor del TAE(Simulacion)
  PRP_AJU_VAL_TAE(v_nro_simulacion,'SI',v_dia_plazo);
  --Ajustamos el valor del TAE(Simulacion)
  PRP_VER_VAL_TAE(v_nro_simulacion,'SI',v_dia_plazo);
  --DDEVOLUT-1234 - Validamos el monto maximo pre aprobado contra las cuotas
  PR_VAL_MTO_MAX_CUOTA;
  -- PCCFPPTC-1 - Flexibilidad en módulo Preaprobados de Consumo y TDC en el Core  -- 10/2016 --
   pag_pre.pr_obt_dat_simulacion( v_nro_simulacion,
                                  v_monto,
                                  v_plazo,
                                  v_cuota,
                                  v_cod_moneda,
                                  v_val_tasa,
                                  v_fec_pri_vencimiento,
                                  v_tas_desembolso,
                                  v_fec_inicio,
                                  v_cotizacion,
                                  v_tot_interes,
                                  v_tot_cargos,v_tip_monto,v_mto_edilicio,v_tip_intere );

  v_cuo_minima := nvl(fug_obt_pardinamico('MTO_MIN_CUO_PRE_APR',6,68,v_cod_moneda),0) ;
   --DDEVOLUT-1242 - Se suma el cargo a la cuota para la validacion
   if v_especial ='N' then
       v_cargo := pag_pre.fu_obt_mto_cargo(v_nro_simulacion, 1);
   else
       v_cargo := pag_pre.fu_obt_mto_cargo(v_nro_simulacion, 2);
   end if;
  v_cuota := nvl(v_cuota,0) + nvl(v_cargo,0);
  if nvl(v_cuota,0) < v_cuo_minima then
   v_mensaje :='El importe de la cuota no puede ser    menor a '||
      trim(to_char(v_cuo_minima,'99G999G999G990','NLS_NUMERIC_CHARACTERS = ''.,'''));
      raise salir;
  end if;
  --

EXCEPTION
  WHEN SALIR THEN
    NULL;
  WHEN OTHERS THEN
    if sqlcode <= -20000 then
      raise;
    else
      raise_application_error(-20000, 'Nro.Propuesta: ' ||v_nro_simulacion||'-'|| sqlerrm);
    end if;
end PRP_GEN_ATM_SIMULACION;
/

