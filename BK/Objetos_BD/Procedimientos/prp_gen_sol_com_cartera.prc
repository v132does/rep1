CREATE OR REPLACE PROCEDURE IT.prp_gen_sol_com_cartera(p_cod_persona         in ba_personas.cod_persona%TYPE,
                                                        p_mto_solicitado      in number,
                                                        p_can_cuotas          in number,
                                                        p_cod_canal           in number default null,
                                                        p_cod_moneda          in varchar2 default pag_gen.FU_OBT_MON_LOCAL,
                                                        p_cod_modalidad       in number,
                                                        p_grabar              in varchar2 default 'S', -- Definir si grabara o no los datos en las tablas                                                        
                                                        p_mto_consolidado     in number,
                                                        p_clave               in number,
                                                        p_can_meses           in number,
                                                        p_solicitud           in out pr_solicitudes.nro_solicitud%TYPE,
                                                        p_cuotas              out pr_sol_cuotas.mto_capital%TYPE,
                                                        p_cod_error           out number,
                                                        p_msj_error           out varchar2) is
  --i NUMBER(3);
  ---------------------------------------------------------------------------
  g_lugar     VARCHAR2(250);
  g_msj_error VARCHAR2(4000);
  g_cod_error NUMBER(3) DEFAULT 0;
  -------------Nuevas Variables requeridas para pre-aprobado-----------------
  v_tip_persona          varchar2(1);
  v_tip_monto            varchar2(1) := 'N';
  v_cod_rub_economico    pr_solicitudes.cod_rub_economico%type;
  v_cod_pla_pre_aprobado pr_pre_aprobados.cod_pla_pre_aprobado%TYPE;
  v_cod_mod_default      ge_modalidades.cod_modalidad%TYPE := p_cod_modalidad;--fug_obt_pardinamico('PRE_MAD_PRE_APROBADOS');
  v_ori_fondo            number := 1;
  v_cod_banca            number; -- código de banca del cliente 
  v_tip_destino          varchar2(1); -- Destino del crédito  
  v_cod_campana          number; -- código de campaña  
  v_cod_usu_promotor     varchar2(10);
  v_cod_usu_oficial      varchar2(10);
  v_cod_departamento     number(3) := null; -- Se obtiene de los datos del cliente o en su defecto de la oficina
  v_cod_dep_parametro    number(3) := 18; -- Departamento de Parámetros
  v_tip_documento        number(1) := 1;
  v_cod_sec_credito      number(3) := 606;--701 -- Valor por default para el sector del crédito 701 - CONSUMO. 
  v_per_gracia           number(8);
  v_per_vencimiento      number(4) := 30;
  v_descripcion          varchar2(500); -- descripción de la operación
  v_nro_cuenta           varchar2(15);
  v_cantidad             number(3);
  v_cod_garantia         pr_gar_tipos.cod_garantia%type;
  ------------------ Variables del procedimiento -----------------------------
  v_dummy               NUMBER(9);
  v_cod_modulo          NUMBER(3) := 6; -- prestamos
  v_fec_actual          DATE := pag_cal.fu_obt_fec_actual(v_cod_modulo);
  v_cod_oficina         NUMBER(3) := fug_obt_ofi_usuario(user);
  v_mon_local           VARCHAR2(3) := pag_gen.fu_obt_mon_local;
  v_cotizacion          ge_cotizaciones.val_conversion%TYPE := pag_gen.fu_obt_cotizacion(nvl(pag_gen.FU_OBT_MON_LOCAL,
                                                                                             pag_gen.FU_OBT_MON_LOCAL));
  v_lugar               VARCHAR2(200) := NULL;
  v_exo_impuestos       VARCHAR2(1) := 'N';
  v_tot_prestamo        NUMBER(18, 2) := 0; -- total del prestamo
  v_mto_interes         NUMBER(18, 2) := 0; -- total de interes
  v_mto_cargo           NUMBER(18, 2) := 0;
  v_fec_inicio          DATE := v_fec_actual;
  p_fec_pri_vencimiento date := PAG_CAL.FU_OBT_FEC_SIG_HAB(nvl(add_months(v_fec_inicio, p_can_meses),v_fec_actual),61);--otro parametro
  v_fec_vencimiento     date := ADD_MONTHS(P_FEC_PRI_VENCIMIENTO,
                                           p_can_cuotas - 1);
  --P_FEC_PRI_VENCIMIENTO DATE := add_months(v_fec_inicio, 1);
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
  v_mto_seg_cancelacion NUMBER(18, 2);
  v_imp_cargo           NUMBER(18, 2);
  ----variables para calculo de seguro------------------
  v_tas_seguro     NUMBER(18, 4);
  v_mto_tot_seguro NUMBER(18, 4);
  -- control del redondeo ----------------------------------------------------
  v_redondeo             NUMBER(2) := 0; -- redondeo a cero para moneda local
  v_can_dia_pri_vcto     number;
  v_can_dia_min_pri_vcto number;
  v_mto_cuota            number := 0;
  v_desembolsar          NUMBER(18, 2);
  v_mto_aumento  number;
  v_recalculo    varchar2(1) := 'N';
  v_tae          number;
  v_tan          number;
  v_tas_efectiva cr_piz_plazos.tas_efectiva%TYPE;
  v_mto_adm_anterior number;
  v_act_gas_anterior varchar2(1) := 'N';
  v_fin_max          varchar2(1) := 'N';
  v_existe_tc     varchar2(1);
  
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
  ------------------ rutinas internas del procedimiento-----------------------
  PROCEDURE pr_val_tasa IS
    CURSOR pizarras IS
      SELECT a.tas_interes, a.tas_minima, a.tas_maxima, a.tas_efectiva
        FROM cr_piz_montos b, cr_piz_plazos a
       WHERE a.cod_modulo = v_cod_modulo
         AND a.cod_modalidad = nvl(p_cod_modalidad, v_cod_mod_default)
         AND a.cod_moneda = nvl(pag_gen.FU_OBT_MON_LOCAL, pag_gen.FU_OBT_MON_LOCAL)
         AND b.cod_modulo = a.cod_modulo
         AND b.cod_modalidad = a.cod_modalidad
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
       AND cod_modalidad = nvl(v_cod_mod_default, v_cod_mod_default);
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
     WHERE cod_moneda = nvl(pag_gen.FU_OBT_MON_LOCAL, pag_gen.FU_OBT_MON_LOCAL);
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
    
      If v_can_meses <
         nvl(fug_obt_pardinamico('PRE_PER_GRACIA_MIN',
                                 v_cod_modulo,
                                 nvl(v_cod_mod_default, v_cod_mod_default),
                                 nvl(pag_gen.FU_OBT_MON_LOCAL, pag_gen.FU_OBT_MON_LOCAL)),
             0) then
        g_cod_error := 8;
        g_lugar     := 'Valida Dias de Gracia';
        g_msj_error := 'Periodo de gracia ' || v_can_meses ||
                       ' no debe ser menor a ' ||
                       nvl(fug_obt_pardinamico('PRE_PER_GRACIA_MIN',
                                               v_cod_modulo,
                                               nvl(v_cod_mod_default,
                                                   v_cod_mod_default),
                                               nvl(pag_gen.FU_OBT_MON_LOCAL,
                                                   pag_gen.FU_OBT_MON_LOCAL)),
                           0);
      end if;
      If nvl(pap_sim.g_cod_error, '000') = '000' and
         v_can_meses >
         nvl(fug_obt_pardinamico('PRE_PER_GRACIA_MAX',
                                 v_cod_modulo,
                                 nvl(v_cod_mod_default, v_cod_mod_default),
                                 nvl(pag_gen.FU_OBT_MON_LOCAL, pag_gen.FU_OBT_MON_LOCAL)),
             0) then
        g_cod_error := 8;
        g_lugar     := 'Valida Dias de Gracia';
        g_msj_error := 'Periodo de gracia ' || v_can_meses ||
                       ' no debe ser mayor a ' ||
                       nvl(fug_obt_pardinamico('PRE_PER_GRACIA_MAX',
                                               v_cod_modulo,
                                               nvl(v_cod_mod_default,
                                                   v_cod_mod_default),
                                               nvl(pag_gen.FU_OBT_MON_LOCAL,
                                                   pag_gen.FU_OBT_MON_LOCAL)),
                           0);
      
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
         AND tr.cod_modalidad = nvl(v_cod_mod_default, v_cod_mod_default)
         AND tr.cod_transaccion = ww_cdtrans
         AND tr.tipo = 'D'
         AND tr.cod_tasa IS NOT NULL
         AND tr.cod_tasa = ta.cod_tasa
         AND EXISTS
       (SELECT 0
                FROM ge_transacciones_det
               WHERE cod_modulo = v_cod_modulo
                 AND cod_modalidad = nvl(v_cod_mod_default, v_cod_mod_default)
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
           (f1.cod_modalidad = nvl(v_cod_mod_default, v_cod_mod_default)))
       AND (f1.cod_modulo IS NULL OR (f1.cod_modulo = v_cod_modulo))
       AND (f1.cod_moneda IS NULL OR
           (f1.cod_moneda = nvl(pag_gen.FU_OBT_MON_LOCAL, pag_gen.FU_OBT_MON_LOCAL)))
       AND (f1.cod_oficina IS NULL OR (f1.cod_oficina = v_cod_oficina))
       AND f1.nro_cuenta IS NULL
       AND f1.fec_vigencia =
           (SELECT MAX(fec_vigencia)
              FROM ge_tas_fechas f2
             WHERE f1.cod_tasa = f2.cod_tasa
               AND (f2.cod_modalidad IS NULL OR
                   (f2.cod_modalidad =
                   nvl(v_cod_mod_default, v_cod_mod_default)))
               AND (f2.cod_modulo IS NULL OR (f2.cod_modulo = v_cod_modulo))
               AND (f2.cod_moneda IS NULL OR
                   (f2.cod_moneda =
                   nvl(pag_gen.FU_OBT_MON_LOCAL, pag_gen.FU_OBT_MON_LOCAL)))
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
         AND (tr.cod_modalidad = nvl(v_cod_mod_default, v_cod_mod_default) OR
             tr.cod_modalidad IS NULL)
         AND (tr.cod_moneda = nvl(pag_gen.FU_OBT_MON_LOCAL, pag_gen.FU_OBT_MON_LOCAL) OR
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
                     nvl(v_cod_mod_default, v_cod_mod_default) OR
                     tra.cod_modalidad IS NULL)
                 AND (tra.cod_moneda =
                     nvl(pag_gen.FU_OBT_MON_LOCAL, pag_gen.FU_OBT_MON_LOCAL) OR
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
  
    IF v_cod_transaccion in (737, 1271) AND v_tip_persona = 'J' and
       nvl(fug_obt_pardinamico('PRE_SEG_DIF_JURIDICAS',
                               v_cod_modulo,
                               nvl(v_cod_mod_default, v_cod_mod_default),
                               nvl(pag_gen.FU_OBT_MON_LOCAL, pag_gen.FU_OBT_MON_LOCAL)),
           'N') = 'S' THEN
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
           AND TR.COD_MODALIDAD = nvl(v_cod_mod_default, v_cod_mod_default)
           AND TR.COD_TRANSACCION = v_cod_transaccion
           AND TR.TIPO = 'D'
           AND v_cod_Tasa = TA.COD_TASA
           AND DT.COD_MODULO = v_cod_modulo
           AND DT.COD_MODALIDAD = nvl(v_cod_mod_default, v_cod_mod_default)
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
      if nvl(g_cod_error, '000') = '000' then
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
        v_cod_mon_cargo := nvl(pag_gen.FU_OBT_MON_LOCAL, pag_gen.FU_OBT_MON_LOCAL);
      END IF;
      --:VAL_TASA := WW_VLDETAS;
    
    ELSE
      --- en caso de que sean valores ----------------
      v_cod_mon_cargo := nvl(pag_gen.FU_OBT_MON_LOCAL, pag_gen.FU_OBT_MON_LOCAL);
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
         AND a.cod_modalidad = nvl(v_cod_mod_default, v_cod_mod_default)
         AND ((nvl(v_exo_impuestos, 'N') = 'N') OR
             (nvl(v_exo_impuestos, 'N') = 'S' AND
             nvl(b.obligatorio, 'N') = 'N'))
         and (((nvl(fug_obt_pardinamico('PRE_SEG_DIF_JURIDICAS',
                                        v_cod_modulo,
                                        nvl(v_cod_mod_default,
                                            v_cod_mod_default),
                                        nvl(pag_gen.FU_OBT_MON_LOCAL,
                                            pag_gen.FU_OBT_MON_LOCAL)),
                    'N') = 'S' and
             (cod_ent_seguro is not null and v_tip_persona != 'F' and
             cod_ent_seguro = nvl(fug_obt_pardinamico('PRE_COD_ENT_PER_JURIDICAS',
                                                          v_cod_modulo,
                                                          nvl(v_cod_mod_default,
                                                              v_cod_mod_default),
                                                          null),
                                      '99999')) or
             (nvl(fug_obt_pardinamico('PRE_SEG_DIF_JURIDICAS',
                                         v_cod_modulo,
                                         nvl(v_cod_mod_default,
                                             v_cod_mod_default),
                                         nvl(pag_gen.FU_OBT_MON_LOCAL,
                                             pag_gen.FU_OBT_MON_LOCAL)),
                     'N') = 'N' AND
             cod_ent_seguro <> nvl(fug_obt_pardinamico('PRE_COD_ENT_PER_JURIDICAS',
                                                           v_cod_modulo,
                                                           nvl(v_cod_mod_default,
                                                               v_cod_mod_default),
                                                           null),
                                       '9999'))) or
             (v_tip_persona = 'F' and
             cod_ent_seguro <> nvl(fug_obt_pardinamico('PRE_COD_ENT_PER_JURIDICAS',
                                                          v_cod_modulo,
                                                          nvl(v_cod_mod_default,
                                                              v_cod_mod_default),
                                                          null),
                                      '99999')) or cod_ent_seguro is null) or
             nvl(fug_obt_pardinamico('PRE_SEG_DIF_JURIDICAS',
                                      v_cod_modulo,
                                      nvl(v_cod_mod_default, v_cod_mod_default),
                                      nvl(pag_gen.FU_OBT_MON_LOCAL,
                                          pag_gen.FU_OBT_MON_LOCAL)),
                  'N') = 'N')
       ORDER BY 1;
  
  BEGIN
    if p_recalculo = 'N' then
      --Add DA-7311 Maximización de tasas - CarolinaV. 04.12.2022
      DELETE FROM pr_sol_cargos WHERE NRO_SOLICITUD = v_nro_solicitud;
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
               v_cod_transaccion =
               nvl(fug_obt_pardinamico('PRE_TRA_MTO_CONSOLIDADO',
                                       v_cod_modulo,
                                       nvl(v_cod_mod_default, v_cod_mod_default),
                                       nvl(pag_gen.FU_OBT_MON_LOCAL,
                                           pag_gen.FU_OBT_MON_LOCAL),
                                       null),
                   0) then
              null;
            else
              INSERT INTO pr_sol_cargos
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
        update pr_sol_cargos a
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
    ww_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                                       V_cod_modulo,
                                       nvl(v_cod_mod_default,
                                           v_cod_mod_default),
                                       nvl(pag_gen.FU_OBT_MON_LOCAL,
                                           pag_gen.FU_OBT_MON_LOCAL),
                                       v_cod_oficina);
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
        v_val_cuota := fup_obt_val_cuota(nvl(v_cod_mod_default,
                                             v_cod_mod_default),
                                         nvl(pag_gen.FU_OBT_MON_LOCAL,
                                             pag_gen.FU_OBT_MON_LOCAL),
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
      DELETE FROM pr_sol_cuotas WHERE nro_solicitud = v_nro_solicitud;
    
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
        insert into pr_sol_cuotas
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
      UPDATE pr_sol_cuotas
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
      ww_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                                         V_cod_modulo,
                                         v_cod_mod_default,
                                         pag_gen.FU_OBT_MON_LOCAL,
                                         v_cod_oficina);
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
                                           pag_gen.FU_OBT_MON_LOCAL,
                                           v_tot_prestamo - nvl(ww_ttrefue,0),
                                           p_can_cuotas - nvl(ww_ctrefue,0),
                                           v_val_tasa,
                                           v_fec_inicio,
                                           p_fec_pri_vencimiento);
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
        DELETE FROM pr_sol_cuotas WHERE nro_solicitud = v_nro_solicitud;

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
          insert into pr_sol_cuotas
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
        UPDATE pr_sol_cuotas
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
                             p_dias      IN NUMBER) RETURN NUMBER IS
    v_mto_seguro NUMBER := 0;
  
  BEGIN
    IF fug_obt_parentes(p_cod_ente, 'COD_TAS_SEG_DESEMPLEO') = p_cod_tasa THEN
      v_mto_seguro := round((p_monto * p_val_tasa / 100) * p_dia_plazo /
                            p_dias,
                            -3);
    
    ELSIF fug_obt_parentes(p_cod_ente, 'COD_TAS_SEG_CANCELACION') =
          p_cod_tasa THEN
      v_mto_seguro := (p_monto * p_val_tasa / 100) * p_dia_plazo / 365;
    
    END IF;
  
    RETURN v_mto_seguro;
  
  END;

  -- Calculo de los cargos ----------------------------------------------------
  PROCEDURE pr_cal_cargos(p_recalculo varchar2 default 'N') IS
    ww_dfcargos       NUMBER(18, 2);
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
    v_can_salario     number := nvl(fug_obt_pardinamico('PRE_CAN_SAL_MIN_COMISION'),
                                    5);
    v_can_jor_minimo  number := fug_obt_pardinamico('PRE_CAN_JOR_MINIMOS');
    v_plazo           number;
    --
    v_mto_max_gas_adm      number := fug_obt_pardinamico('MTO_MAX_COM_ADM',
                                                         null,
                                                         null,
                                                         nvl(pag_gen.FU_OBT_MON_LOCAL,
                                                             pag_gen.FU_OBT_MON_LOCAL),
                                                         null);
    v_mto_gas_admistrativo number;
    v_actualizar varchar2(1) default 'S';
  
    CURSOR cargos IS
      SELECT cod_transaccion,
             cod_tasa,
             cod_ent_seguro,
             val_tasa,
             monto,
             cod_moneda,
             mto_mon_prestamo
        FROM pr_sol_cargos
       WHERE nro_solicitud = v_nro_solicitud
         FOR UPDATE OF monto
       ORDER BY decode(cod_transaccion, 709, 1, 710, 2, cod_transaccion);
  BEGIN
    --- Calculo cada uno de los cargos en la moneda del cargo y en la de la simulacion ---
    --- cero los totales de cargo de tipo valor y el total general de cargos -------------
    v_ttvalor              := 0;
    v_mto_cargo            := 0;
    v_cod_tra_ajuste       := NULL;
    v_mto_gas_admistrativo := pag_gen.fu_con_mon_a_moneda(pag_gen.fu_obt_mon_local,
                                                          nvl(pag_gen.FU_OBT_MON_LOCAL,
                                                              pag_gen.FU_OBT_MON_LOCAL),
                                                          fug_obt_pardinamico('MTO_TAE',
                                                                              6));
    FOR cc IN cargos LOOP
      v_mto_equivalente := 0;
      -- para realizar ajustes si es necesario----------
      IF v_cod_tra_ajuste IS NULL THEN
        v_cod_tra_ajuste := cc.cod_transaccion;
      END IF;
      -- obtengo los datos de la tasa-----------------
      IF cc.cod_transaccion in (737, 1271) AND v_tip_persona = 'J' and
         nvl(fug_obt_pardinamico('PRE_SEG_DIF_JURIDICAS',
                                 v_cod_modulo,
                                 nvl(v_cod_mod_default, v_cod_mod_default),
                                 nvl(pag_gen.FU_OBT_MON_LOCAL, pag_gen.FU_OBT_MON_LOCAL)),
             'N') = 'S' THEN
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
             AND TR.COD_MODALIDAD = nvl(v_cod_mod_default, v_cod_mod_default)
             AND TR.COD_TRANSACCION = cc.cod_transaccion
             AND TR.TIPO = 'D'
             AND v_cod_Tasa = TA.COD_TASA
             AND DT.COD_MODULO = v_cod_modulo
             AND DT.COD_MODALIDAD = nvl(v_cod_mod_default, v_cod_mod_default)
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
                                                           v_dias),
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
                                                           v_dias),
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
          v_plazo := round((v_dia_plazo / 30), 0);
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
              v_imp_cargo       := 0;
       
         if cc.cod_transaccion = '709' then  -- 1era. modificacion DA-6139
          v_imp_cargo       := NVL(v_imp_cargo, 0) +
                    trunc(p_mto_solicitado * v_plazo *
                       cc.val_tasa / 100,
                      v_redondeo); 
         else 
          v_imp_cargo       := NVL(v_imp_cargo, 0) +
                     ROUND(p_mto_solicitado * v_plazo *
                       cc.val_tasa / 100,
                       v_redondeo);      
         end if;
       
              v_mto_equivalente := v_imp_cargo; -- + ROUND(v_imp_cargo * 10/100,v_redondeo);
            
            end if;
          ELSE
            IF cc.cod_ent_seguro IS NOT NULL THEN
              v_imp_cargo       := 0;
              v_imp_cargo       := NVL(v_imp_cargo, 0) +
                                   ROUND(p_mto_solicitado * v_plazo *
                                         cc.val_tasa / 100,
                                         v_redondeo);
              v_mto_equivalente := v_imp_cargo; -- + ROUND(v_imp_cargo * 10/100,v_redondeo);
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
        elsif cc.cod_transaccion =
              nvl(fug_obt_pardinamico('PRE_TRA_MTO_CONSOLIDADO',
                                      v_cod_modulo,
                                      nvl(v_cod_mod_default, v_cod_mod_default),
                                      nvl(pag_gen.FU_OBT_MON_LOCAL,
                                          pag_gen.FU_OBT_MON_LOCAL)),
                  0) then
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
        elsif cc.cod_transaccion =
              nvl(fug_obt_pardinamico('PRE_TRA_MTO_CONSOLIDADO',
                                      v_cod_modulo,
                                      nvl(v_cod_mod_default, v_cod_mod_default),
                                      nvl(pag_gen.FU_OBT_MON_LOCAL,
                                          pag_gen.FU_OBT_MON_LOCAL)),
                  0) then
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
        elsif cc.cod_transaccion =
              nvl(fug_obt_pardinamico('PRE_TRA_MTO_CONSOLIDADO',
                                      v_cod_modulo,
                                      nvl(v_cod_mod_default, v_cod_mod_default),
                                      nvl(pag_gen.FU_OBT_MON_LOCAL,
                                          pag_gen.FU_OBT_MON_LOCAL)),
                  0) then
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
              from pr_sol_cargos a
             where a.nro_solicitud = v_nro_solicitud
               and a.cod_transaccion = 704;
          exception 
            when no_data_found then
              v_mto_adm_anterior := v_mto_equivalente;
          end;
        end if;
        --
      END IF;
      if cc.cod_transaccion =
         nvl(fug_obt_pardinamico('PRE_TRA_MTO_CONSOLIDADO',
                                 v_cod_modulo,
                                 nvl(v_cod_mod_default, v_cod_mod_default),
                                 nvl(pag_gen.FU_OBT_MON_LOCAL, pag_gen.FU_OBT_MON_LOCAL)),
             0) then
        v_imp_cargo       := 0;
        v_imp_cargo       := p_mto_consolidado;
        v_mto_equivalente := p_mto_consolidado; --v_imp_cargo + ROUND(v_imp_cargo * 10/100,v_redondeo);
      end if;
    
      if cc.cod_transaccion =
         nvl(fug_obt_pardinamico('PRE_TRA_MTO_CONSOLIDADO',
                                 v_cod_modulo,
                                 nvl(v_cod_mod_default, v_cod_mod_default),
                                 nvl(pag_gen.FU_OBT_MON_LOCAL, pag_gen.FU_OBT_MON_LOCAL)),
             0) then
        v_monto := p_mto_consolidado;
      else
        v_monto := NULL;
        --- Acumular el total de cargos (Si el tipo es Valor viene directamente aqui -------
        v_mto_cargo := nvl(v_mto_cargo, 0) + nvl(v_mto_equivalente, 0);
        ------------------------------------------------------------------------------------
      end if;
    
      IF v_tpvlpor IN ('I', 'P') THEN
        /* solo si es porcentaje */
        IF cc.cod_moneda = nvl(pag_gen.FU_OBT_MON_LOCAL, pag_gen.FU_OBT_MON_LOCAL) THEN
          -- moneda del cargo es igual a la moneda de la simulacion ----------------------
          v_monto := v_mto_equivalente;
        ELSE
          -- monedas diferentes, se divide por la cotiz. de la moneda de la simulacion ---
          v_monto := round(v_mto_equivalente * v_cotizacion, v_redondeo);
        END IF;
      END IF;
      if nvl(v_actualizar,'S') = 'S' then
        UPDATE pr_sol_cargos
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
        from pr_sol_cargos a
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
      FROM pr_sol_cuotas sc
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
      from pr_sol_cuotas dp
      where dp.nro_solicitud = p_nro_sol;
      
   EXCEPTION 
    WHEN OTHERS THEN 
      g_cod_error := '111';
      g_lugar     := 'Total prestamo ';
      g_msj_error := 'Error consultar sol_cuotas' || SQLERRM;
   END;
   
   /* Verificamos el total de las cuotas en contra partida con el total de la 
      Solicitud */
      
   if abs(v_tot_prestamo - v_tot_cuota_solicitud) between 1 and 2  then 
     
    v_mon_ajuste := (v_tot_prestamo - v_tot_cuota_solicitud);
    
    
    begin
    Select max(nro_cuota) 
       into v_nro_cuota
     from pr_sol_cuotas 
     where nro_solicitud = p_nro_sol; 
    exception
      when others then 
      g_cod_error := '112';
      g_lugar     := 'Total prestamo ';
      g_msj_error := 'Error consultar' || SQLERRM;
    end;               
    
    begin
    --ajustamos la ultima cuota 
    Update pr_sol_cuotas a
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

BEGIN
  Begin
    pre_ini_aplicacion;
  END;
  pre_cam_for_numerico(',.');
  v_valor_aum := nvl(fug_obt_pardinamico('VAL_INI_AUMTASA', null, null, p_cod_moneda, null ),0) ;
  g_msj_error := ' ';
  g_cod_error := null;
  --- Veo el tipo de redondeo de los calculos ------------------------------------------
  v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                                    6,
                                    nvl(v_cod_mod_default, v_cod_mod_default),
                                    nvl(pag_gen.FU_OBT_MON_LOCAL,
                                        pag_gen.FU_OBT_MON_LOCAL));
 
  -- valido el código del cliente-------------------------------------------
  if nvl(g_cod_error, '000') = '000' then
    PR_VAL_COD_PERSONA;
  end if;
  -- Valido el codigo de la modalidad que recibo----------------------------
  if nvl(g_cod_error, '000') = '000' then
    pr_val_cod_modalidad;
  end if;

  -- valido la moneda-------------------------------------------------------
  if nvl(g_cod_error, '000') = '000' then
    pr_val_cod_moneda;
  end if;

  -- valido el monto -------------------------------------------------------
  IF nvl(g_cod_error, '000') = '000' and nvl(p_mto_solicitado, 0) <= 0 THEN
    g_cod_error := '005';
    g_lugar     := 'Valida Monto Ingresado';
    g_msj_error := 'Ingrese Monto del Credito';
  END IF;

  v_tot_prestamo := p_mto_solicitado;

  -- valido el tipo de monto -----------------------------------------------
  IF nvl(g_cod_error, '000') = '000' and
     nvl(v_tip_monto, 'X') NOT IN ('B', 'N') THEN
    g_cod_error := '006';
    g_lugar     := 'Valida Tipo Monto';
    g_msj_error := 'Tipo de Monto debe ser B-Bruto o N-Neto';
  END IF;

  -- valido la cantidad de cuotas ------------------------------------------
  IF nvl(g_cod_error, '000') = '000' and nvl(p_can_cuotas, 0) < 1 THEN
    g_cod_error := '007';
    g_lugar     := 'Valida Cantidad Cuotas';
    g_msj_error := 'Ingrese la cantidad de cuotas';
  END IF;
  ----desde aqui

  V_CAN_DIA_PRI_VCTO     := fug_obt_pardinamico('CAN_DIA_PRI_VCTO',
                                                6,
                                                nvl(v_cod_mod_default,
                                                    v_cod_mod_default),
                                                nvl(pag_gen.FU_OBT_MON_LOCAL,
                                                    pag_gen.FU_OBT_MON_LOCAL),
                                                v_cod_oficina);
  v_can_dia_min_pri_vcto := fug_obt_pardinamico('CAN_DIA_MIN_PRI_VENCIMIENTO',
                                                6,
                                                nvl(v_cod_mod_default,
                                                    v_cod_mod_default),
                                                nvl(pag_gen.FU_OBT_MON_LOCAL,
                                                    pag_gen.FU_OBT_MON_LOCAL),
                                                v_cod_oficina);
  if v_can_dia_min_pri_vcto is null then
    v_can_dia_min_pri_vcto := 15;
  end if;
  ---
  IF nvl(g_cod_error, '000') = '000' and p_fec_pri_vencimiento IS NULL THEN
    g_cod_error := '008';
    g_lugar     := 'Valida Primer vencimiento';
    g_msj_error := 'Ingrese Primer Vencimiento del Prestamo.';
  END IF;
  -- Valido la fecha del primer vencimiento --------------------------------
  IF nvl(g_cod_error, '000') = '000' and
     p_fec_pri_vencimiento <= v_fec_actual AND
     nvl(v_cod_mod_default, v_cod_mod_default) <> 660 THEN
    g_cod_error := '009';
    g_lugar     := 'Valida Primer vencimiento';
    g_msj_error := 'Primer Vencimiento debe ser posterior a la fecha de Hoy';
  END IF;

  -- Controla los dias del primer vencimiento...
  IF nvl(g_cod_error, '000') = '000' and
     ((p_fec_pri_vencimiento - v_fec_actual) > v_can_dia_pri_vcto) THEN
    g_cod_error := '010';
    g_lugar     := 'Valida Primer vencimiento';
    g_msj_error := 'Primer Vencimiento no debe ser posterior a los ' ||
                   v_can_dia_pri_vcto || ' dias.';
  END IF;

  -- Controla los dias del primer vencimiento...
  IF nvl(g_cod_error, '000') = '000' and
     ((p_fec_pri_vencimiento - v_fec_actual) < v_can_dia_min_pri_vcto) THEN
    g_cod_error := '010';
    g_lugar     := 'Valida Primer Vencimiento';
    g_msj_error := 'Primer Vencimiento no debe ser menor a los ' ||
                   v_can_dia_min_pri_vcto || ' dias.';
  END IF;

  IF nvl(g_cod_error, '000') = '000' and
     nvl(fug_obt_pardinamico('PRE_MOD_AFD',
                             6,
                             nvl(v_cod_mod_default, v_cod_mod_default),
                             nvl(pag_gen.FU_OBT_MON_LOCAL, pag_gen.FU_OBT_MON_LOCAL)),
         'N') = 'S' then
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
  IF nvl(g_cod_error, '000') = '000' and v_tip_persona is null THEN
    g_cod_error := '009';
    g_lugar     := 'Valida Tipo Persona';
    g_msj_error := 'Ingrese el tipo de persona';
  END IF;
  -- valido el tipo de persona  --------------------------------------------
  IF nvl(g_cod_error, '000') = '000' and v_tip_persona is not null and
     v_tip_persona not in ('F', 'J') THEN
    g_cod_error := '010';
    g_lugar     := 'Valida Tipo Persona';
    g_msj_error := 'Valor incorrecto. (Tipo F-Fisica/ J-Juridica)';
  END IF;

  v_dia_plazo   := add_months(p_fec_pri_vencimiento, p_can_cuotas - 1) -
                   v_fec_inicio;
  v_per_gracia  := P_FEC_PRI_VENCIMIENTO - v_fec_inicio;
  v_per_capital := 30;

  -- Valido la tasa de interes -----------DA-7311------
  IF nvl(g_cod_error, '000') = '000' and nvl(v_max_tasa,'N') <> 'S' then
    pr_val_tasa;
  end if;
  v_nro_solicitud := null;
  --- Recupero secuencia negativa para solicitud auxiliar
  IF nvl(g_cod_error, '000') = '000' then
    -- asigno el número de la solicitud -----------------------------------------
    if p_grabar = 'S' then
      select s_nro_sol_prestamos.nextval into v_nro_solicitud from dual;
    else
      --- Recupero secuencia negativa para solicitud auxiliar
      select s_nro_sol_negativo.nextval into v_nro_solicitud from dual;
    end if;
    --------------------------------------------------------------------------
    -----------------------------------------------------------------------
    ---------- Obtengo el Rubro de la tabla de pre-aprobados------------------
    BEGIN
        v_cod_rub_economico := '930900';
    END;
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
         est_verificacion)
      values
        (v_nro_solicitud,
         nvl(v_descripcion, 'COMPRA DE CARTERA.'),
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
         nvl(v_cod_mod_default, v_cod_mod_default),
         nvl(pag_gen.FU_OBT_MON_LOCAL, pag_gen.FU_OBT_MON_LOCAL),
         v_cod_oficina,
         P_FEC_PRI_VENCIMIENTO,
         v_cod_sec_credito,
         nvl(v_cod_departamento, v_cod_dep_parametro),
         v_tip_documento,
         v_exo_impuestos,
         v_cod_usu_promotor,
         p_cod_canal,
         v_cod_campana,
         '5',
         v_cod_banca,
         'A',
         v_ori_fondo,
         100,
         NVL(v_cod_rub_economico, '930900'),
         'S',
         decode(nvl(v_cod_mod_default, v_cod_mod_default), 660, 'N', 'S'));
    
    EXCEPTION
      WHEN OTHERS THEN
        g_cod_error := '019';
        g_lugar     := 'Inserta Propuesta';
        g_msj_error := 'Error al insertar la propuesta. ' || SQLERRM;
    END;
  
  END IF;
  <<recalculo>>
  If nvl(v_max_tasa,'N') = 'S' then
     delete from PR_SOL_CARGOS c  where c.nro_solicitud = nvl(p_solicitud, v_nro_solicitud);
     delete from pr_sol_cuotas cu where cu.nro_solicitud = nvl(p_solicitud, v_nro_solicitud);
     delete from PR_SOL_TASAS t   where t.nro_solicitud = nvl(p_solicitud, v_nro_solicitud);
     delete from pr_sol_garantias g where g.nro_solicitud = nvl(p_solicitud, v_nro_solicitud);
     delete from pr_sol_destinos o  where o.nro_solicitud = nvl(p_solicitud, v_nro_solicitud);
  End if;
  -- genero los cargos por defecto
  IF nvl(g_cod_error, '000') = '000' THEN
    pr_gen_cargos(v_recalculo);
  END IF;

  -- generar cuotas --------------------------------------------------------
  IF nvl(g_cod_error, '000') = '000' THEN
    pr_gen_cuo_iguales('N');
  END IF;

  -- Calculo los cargos ----------------------------------------------------
  IF nvl(g_cod_error, '000') = '000' THEN
    pr_cal_cargos(v_recalculo);
  END IF;

  -- verifico el tipo de prestamo
  IF nvl(g_cod_error, '000') = '000' THEN
    IF v_tip_monto = 'B' THEN
      v_tot_prestamo := p_mto_solicitado;
    ELSE
      select sum(nvl(a.monto, 0))
        into v_mto_cargo
        from pr_sol_cargos a
       where a.nro_solicitud = v_nro_solicitud
         and a.cod_transaccion !=
             nvl(fug_obt_pardinamico('PRE_TRA_MTO_CONSOLIDADO',
                                     v_cod_modulo,
                                     nvl(v_cod_mod_default, v_cod_mod_default),
                                     nvl(pag_gen.FU_OBT_MON_LOCAL,
                                         pag_gen.FU_OBT_MON_LOCAL),
                                     null),
                 0);
    
      --- monto ingresado es el neto -----------------------------------------------------
      v_por_ajuste := (p_mto_solicitado - (nvl(v_mto_cargo, 0) - v_ttvalor)) * 100 /
                      (p_mto_solicitado + v_ttvalor);
    
      --- calculo del nuevo capital (monto bruto -----------------------------------------
      v_tot_prestamo := round((p_mto_solicitado * 100 / v_por_ajuste),
                              v_redondeo);
    
      --- Vuelvo a generar las cuotas y calcular los cargos ------------------------------
      IF nvl(g_cod_error, '000') = '000' then
        pr_gen_cuo_iguales('S');
      END IF;
    
      -- recalculo los cargos ------------------------------------------------------------
      IF nvl(g_cod_error, '000') = '000' then
        pr_cal_cargos(v_recalculo);
      END IF;
    
      WHILE NVL(v_TOT_PRESTAMO, 0) - NVL(v_MTO_CARGO, 0) <>
            p_mto_solicitado LOOP
        v_por_ajuste := p_mto_solicitado -
                        (NVL(v_TOT_PRESTAMO, 0) - NVL(v_MTO_CARGO, 0));
        if v_por_ajuste Between -2 And 2 then--rodri
          --para evitar que se cuelgue el proceso
          v_TOT_PRESTAMO := p_mto_solicitado + NVL(v_MTO_CARGO, 0);
        else
          v_TOT_PRESTAMO := v_TOT_PRESTAMO + v_POR_AJUSTE;
        
          --- Vuelvo a generar las cuotas y calcular los cargos ------------------------------
          IF nvl(g_cod_error, '000') = '000' then
            pr_gen_cuo_iguales('S');
          END IF;
        
          -- recalculo los cargos ------------------------------------------------------------
          IF nvl(g_cod_error, '000') = '000' then
            pr_cal_cargos(v_recalculo);
          END IF;
        
        end if;
      END LOOP;
    
      -- actualizo el total del prestamo -------------------------------------------------
      IF nvl(g_cod_error, '000') = '000' then
        UPDATE pr_solicitudes
           SET tot_prestamo = v_tot_prestamo, estado = 'L'
         WHERE nro_solicitud = v_nro_solicitud;
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
           decode(nvl(v_cod_mod_default, v_cod_mod_default),
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
             decode(nvl(v_cod_mod_default, v_cod_mod_default),
                    660,
                    s.tip_des_especifico,
                    3),
             decode(nvl(v_cod_mod_default, v_cod_mod_default),
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
           decode(nvl(v_cod_mod_default, v_cod_mod_default),
                  660,
                  round(p_mto_solicitado / v_cantidad, 2),
                  v_tot_prestamo));
      exception
        when others then
          g_cod_error := '027';
          g_lugar     := 'Inserta PR_SOL_GARANTIAS ';
          g_msj_error := 'Error al insesrtar garantias ' || SQLERRM;
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
            g_msj_error := 'Error al insesrtar garantias ' || SQLERRM;
        end;
      END LOOP;
    END IF;
  
  /*Para calcular la diferencia de la solicitud*/
  pr_cal_dif_montos(v_nro_solicitud) ;
  
    -- finalmente inserto la cuota 0 ------------------------------------------------------
    begin
      INSERT INTO PR_SOL_CUOTAS
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
        g_msj_error := 'Error al insesrtar cuotas ' || SQLERRM;
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
        g_msj_error := 'Error al insesrtar Tasas ' || SQLERRM;
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
    
    If nvl(v_max_tasa,'N') <> 'X'   AND (p_mto_solicitado between pag_gen.FU_OBT_VAL_MINIMO and pag_gen.FU_OBT_VAL_MAXIMO ) 
      AND nvl(fug_obt_pardinamico('VAL_INI_AUMTASA', null, null, p_cod_moneda, null ),0) <> 0 then
       v_max_tasa := 'S';       
    else
       v_max_tasa := 'N';
    End if;
    
    --Controla que no maximize ambos, Tasa y Cargos
    if instr(fug_obt_pardinamico('MAD_VAL_TAE_GAS_ADM'),','||v_cod_mod_default||',') > 0
      and p_mto_solicitado <= fug_obt_pardinamico('MTO_SOL_MAX_ADM',6,v_cod_mod_default,p_cod_moneda) then
        v_max_cargos := 'S' ;
    else
        v_max_cargos := 'N';
    end if;
   
    If nvl(v_max_cargos,'N') = 'S' and nvl(v_max_tasa,'N') = 'S' then
       g_cod_error := '037';
       g_lugar := 'Max. de tasa y cargos se solapan';
       g_msj_error := 'Ajustar los parámetros de max. tasa y cargos'||sqlerrm;
    end if;
      
    IF nvl(g_cod_error, '000') = '000' THEN
      If nvl(v_max_tasa,'X') = 'S'  then
         begin
           pas_bcp.pr_obt_tas_prestamo(v_nro_solicitud, null, v_tae, v_tan);
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
    if instr(fug_obt_pardinamico('MAD_VAL_TAE_GAS_ADM'),','||v_cod_mod_default||',') > 0
      and p_mto_solicitado <= fug_obt_pardinamico('MTO_SOL_MAX_ADM',6,v_cod_mod_default,p_cod_moneda) then
      pas_bcp.pr_obt_tas_prestamo(v_nro_solicitud, null, v_tae, v_tan);
      if nvl(v_tas_efectiva, 0) <> 0 then
        if v_tae > nvl(v_tas_efectiva, 0) then
          if nvl(v_mto_adm_anterior,0) > 0 then
            begin
              update pr_sol_cargos a
                 set a.monto = v_mto_adm_anterior,
                     a.mto_mon_prestamo = v_mto_adm_anterior
               where a.nro_solicitud = v_nro_solicitud
                 and a.cod_transaccion = 704;
            end;
          else
            v_fin_max := 'S';
          end if;
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
              v_mto_aumento := nvl(fug_obt_pardinamico('MTO_AUM_GAS_ADM', null, null, p_cod_moneda, null ),0);
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
      if v_mto_aumento > 100 then
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
    if instr(fug_obt_pardinamico('MAD_VAL_TAE_GAS_ADM'),','||v_cod_mod_default||',') > 0
      and p_mto_solicitado <= fug_obt_pardinamico('MTO_SOL_MAX_ADM',6,v_cod_mod_default,p_cod_moneda) and (v_rec_tae = 'S') then
      -- borro la cuota 0 por si existe
      DELETE FROM pr_sol_cuotas WHERE nro_solicitud = v_nro_solicitud and nro_cuota = 0 ;
      begin
        INSERT INTO PR_SOL_CUOTAS
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
          g_msj_error := 'Error al insesrtar cuotas ' || SQLERRM;
    END;
    --
    pr_cal_dif_montos(v_nro_solicitud);
    end if;
   End if;  
  End if;
  --
  IF nvl(g_cod_error,'000') = '000' then 
     pas_bcp.pr_obt_tas_prestamo(v_nro_solicitud, null, v_tae, v_tan);
     If nvl(v_tae,0) > nvl(v_tas_efectiva, 0)  Then
        g_cod_error := '052';
        g_lugar     := 'Supera TAE';
        g_msj_error := 'Valor obtenido :'||v_tae||' valor pizzarra:'||v_tas_efectiva;
     end if;           
   end if;  

  IF nvl(g_cod_error, '000') = '000' THEN
    p_solicitud := v_nro_solicitud;
    p_cuotas    := fu_obt_mto_cuota(v_nro_solicitud);
    p_cod_error := g_cod_error;
    p_msj_error := g_msj_error;
    PRG_INS_LOG_PROGRAMAS('PRP_GEN_SOL_COM_CARTERA',
                          'MTO. SOL '||p_mto_solicitado||
                          ' CANT. CUO '||p_can_cuotas||
                          ' MONEDA '||p_cod_moneda||
                          ' MODALIDAD '||p_cod_modalidad,
                          p_cod_persona, null);
  ELSE
    p_cod_error := g_cod_error;
    p_msj_error := g_msj_error;
  END IF;

end;
/
