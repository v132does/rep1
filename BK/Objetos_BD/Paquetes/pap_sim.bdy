create or replace package body it.pap_sim is

  -- Private type declarations

  v_fec_actual date := pag_cal.fu_obt_fec_actual(6);
  v_tae number;
  v_tan number;
  v_tas_minima   cr_piz_plazos.tas_minima%TYPE;
  v_tas_maxima   cr_piz_plazos.tas_maxima%TYPE;
  v_tas_interes  cr_piz_plazos.tas_interes%TYPE;
  v_tas_efectiva cr_piz_plazos.tas_efectiva%TYPE;
  v_tas_efec     cr_piz_plazos.tas_efectiva%TYPE; 
  v_val_tasa     pr_sol_tasas.val_tasa%TYPE;
  v_mto_aumento  number;
  v_recalculo    varchar2(1) := 'N';
  v_mto_adm_anterior number;
  v_act_gas_anterior varchar2(1) := 'N';
  v_fin_max          varchar2(1) := 'N';
  -----variables de maximización de tasa DA-7202
  v_valor_tasa pr_sol_tasas.val_tasa%TYPE;
  v_fec_vigencia ge_tas_fechas.fec_vigencia%TYPE;
  v_codi_tasa ge_tasas.cod_tasa%TYPE;
  v_tipo_valor ge_tasas.tip_valor%TYPE;
  v_tipo ge_tasas.tipo%TYPE;
  v_max_tasa varchar2(1)   := 'N';
  v_max_gastos varchar2(1) := 'N';
  v_tasa_back pr_sol_tasas.val_tasa%TYPE;
  v_bandera varchar2(1) ;
  v_tasa_mod varchar2(1);
  v_si_maximiza varchar2(1) default 'N';


PROCEDURE pr_sim_pre_consumo(p_cod_modalidad  in number,
                              p_cod_moneda     in varchar2,
                              p_tip_monto      in varchar2,
                              p_mto_solicitado in number,
                              p_can_cuotas     in number,
                              p_fec_pri_vencimiento in date,
                              p_solicitud      out typ_consolicitud,
                              p_cargos         out typ_listaconcargo,
                              p_cuotas         out typ_listaconcuota,
                              p_tip_persona    in varchar2,
                              p_mto_consolidado in number)
    is
    i NUMBER(3);
    ------------------ Variables del procedimiento -----------------------------
    v_dummy               NUMBER(9);
    v_cod_modulo          NUMBER(3) := 6; -- prestamos
    v_fec_actual          DATE := pag_cal.fu_obt_fec_actual(v_cod_modulo);
    v_cod_oficina         NUMBER(3):= fug_obt_ofi_usuario(user);
    v_mon_local           VARCHAR2(3) := pag_gen.fu_obt_mon_local;
    v_cotizacion          ge_cotizaciones.val_conversion%TYPE := pag_gen.fu_obt_cotizacion(p_cod_moneda);
    v_lugar               VARCHAR2(200) := NULL;
    v_exo_impuestos       VARCHAR2(1) := 'N';
    v_tot_prestamo        NUMBER(18, 2) := 0; -- total del prestamo
    v_mto_interes         NUMBER(18, 2) := 0; -- total de interes
    v_mto_cargo           NUMBER(18, 2) := 0;
    v_fec_inicio          DATE := v_fec_actual;
    --v_fec_pri_vencimiento DATE := add_months(v_fec_inicio, 1);
    v_tip_amortizacion    VARCHAR2(1) := 'P';
    v_val_tasa            NUMBER;
    v_dia_plazo           NUMBER(8);
    v_per_capital         pr_solicitudes.per_vto_capital%TYPE;
    v_nro_solicitud       NUMBER(10);
    v_por_ajuste          NUMBER;
    v_ttvalor             NUMBER(18, 2);
    -- Datos de los cargos -----------------------------------------------------
    v_cod_transaccion NUMBER(4);
    v_cod_tas_cargo   NUMBER(4);
    v_val_tas_cargo   NUMBER;
    v_cod_mon_cargo   VARCHAR2(3);
    v_tpvlpor         VARCHAR2(1);
    v_aplicar         VARCHAR2(3);
    v_tpdetas         VARCHAR2(1);
    v_val_cargo       NUMBER(18, 2);
    v_cod_ent_seguro  NUMBER(6);
    v_consolicitud    typ_consolicitud  := typ_consolicitud();
    v_consolcargos    typ_listaconcargo := typ_listaconcargo();
    v_consolcuotas    typ_listaconcuota := typ_listaconcuota();
    v_mto_seg_cancelacion NUMBER(18,2);
    v_imp_cargo           NUMBER(18, 2);
    ----variables para calculo de seguro------------------
    v_tas_seguro      NUMBER(18,4);
    v_mto_tot_seguro   NUMBER(18,4);
    -- control del redondeo ----------------------------------------------------
    v_redondeo  NUMBER(2) := 0; -- redondeo a cero para moneda local
    v_can_dia_pri_vcto    number;
    v_can_dia_min_pri_vcto number;
    v_mto_cuota number := 0;
    v_desembolsar NUMBER(18, 2);
    ---Max tasa DA 7202
    v_valor_aum pr_sol_tasas.val_tasa%TYPE := to_number(nvl(fug_obt_pardinamico('VAL_INI_AUMTASA',null,null, p_cod_moneda, null),0),'999G999D999999', 'NLS_NUMERIC_CHARACTERS='',.''');

    ------------------ rutinas internas del procedimiento-----------------------
    PROCEDURE pr_val_tasa IS
      CURSOR pizarras IS
        SELECT a.tas_interes, a.tas_minima, a.tas_maxima, tas_efectiva
          FROM cr_piz_montos b, cr_piz_plazos a
         WHERE a.cod_modulo = v_cod_modulo
           AND a.cod_modalidad = p_cod_modalidad
           AND a.cod_moneda = p_cod_moneda
           AND b.cod_modulo = a.cod_modulo
           AND b.cod_modalidad = a.cod_modalidad
           AND b.cod_moneda = a.cod_moneda
           AND b.mto_desde = a.mto_desde
           AND p_mto_solicitado BETWEEN b.mto_desde AND b.mto_hasta
           AND v_dia_plazo BETWEEN a.plz_desde AND a.plz_hasta;
      v_tas_interes NUMBER; 
    BEGIN
      v_lugar := 'obtener_tasas de pizarras';
      OPEN pizarras;
      FETCH pizarras
        INTO v_tas_interes, v_tas_minima, v_tas_maxima, v_tas_efectiva;
      CLOSE pizarras;
      IF v_val_tasa IS NULL THEN
        v_val_tasa := nvl(v_tas_interes,32);
      ELSE
        -- valido la tasa ingresada---
       IF NOT v_val_tasa BETWEEN v_tas_minima AND v_tas_maxima THEN
          g_cod_error := '009';
          g_lugar     := 'Valida Tasa ingresada';
          g_msj_error := 'Tasa fuera de Rango. Verifique la Pizarra';
        END IF;
      END IF;
    END;

    -- Validacion del tipo de credito--------------------------------------------
    PROCEDURE pr_val_cod_modalidad IS
    BEGIN
      SELECT 0
        INTO v_dummy
        FROM ge_modalidades
       WHERE cod_modulo = v_cod_modulo
         AND cod_modalidad = p_cod_modalidad;
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
       WHERE cod_moneda = p_cod_moneda;
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

           If v_can_meses < nvl(fug_obt_pardinamico('PRE_PER_GRACIA_MIN',
                                             v_cod_modulo,
                                             p_cod_modalidad,
                                             p_cod_moneda),
                         0) then
             g_cod_error := 8;
             g_lugar     := 'Valida Dias de Gracia';
             g_msj_error := 'Periodo de gracia ' || v_can_meses ||
                ' no debe ser menor a ' ||
                nvl(fug_obt_pardinamico('PRE_PER_GRACIA_MIN',
                                        v_cod_modulo,
                                             p_cod_modalidad,
                                             p_cod_moneda),
                    0);
           end if;
           If nvl(pap_sim.g_cod_error,'000') ='000' and v_can_meses > nvl(fug_obt_pardinamico('PRE_PER_GRACIA_MAX',
                                             v_cod_modulo,
                                             p_cod_modalidad,
                                             p_cod_moneda),
                         0) then
              g_cod_error := 8;
              g_lugar     := 'Valida Dias de Gracia';
              g_msj_error :='Periodo de gracia ' || v_can_meses ||
                ' no debe ser mayor a ' ||
                nvl(fug_obt_pardinamico('PRE_PER_GRACIA_MAX',
                                        v_cod_modulo,
                                             p_cod_modalidad,
                                             p_cod_moneda),
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
      if ww_cddetas is null then
      --- 1. Busco la tasa asociada a la transaccion ingresada ---
      SELECT tr.cod_tasa, ta.aplicar, ta.tip_valor, ta.tipo
        INTO ww_cddetas, ww_aplicar, ww_tpvlpor, ww_tpdetas
        FROM ge_transacciones tr, ge_tasas ta
       WHERE tr.cod_modulo = v_cod_modulo
         AND tr.cod_modalidad = p_cod_modalidad
         AND tr.cod_transaccion = ww_cdtrans
         AND tr.tipo = 'D'
         AND tr.cod_tasa IS NOT NULL
         AND tr.cod_tasa = ta.cod_tasa
         AND EXISTS (SELECT 0
                FROM ge_transacciones_det
               WHERE cod_modulo = v_cod_modulo
                 AND cod_modalidad = p_cod_modalidad
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
             (f1.cod_modalidad = p_cod_modalidad))
         AND (f1.cod_modulo IS NULL OR (f1.cod_modulo = v_cod_modulo))
         AND (f1.cod_moneda IS NULL OR (f1.cod_moneda = p_cod_moneda))
         AND (f1.cod_oficina IS NULL OR (f1.cod_oficina = v_cod_oficina))
         AND f1.nro_cuenta IS NULL
         AND f1.fec_vigencia =
             (SELECT MAX(fec_vigencia)
                FROM ge_tas_fechas f2
               WHERE f1.cod_tasa = f2.cod_tasa
                 AND (f2.cod_modalidad IS NULL OR
                     (f2.cod_modalidad = p_cod_modalidad))
                 AND (f2.cod_modulo IS NULL OR
                     (f2.cod_modulo = v_cod_modulo))
                 AND (f2.cod_moneda IS NULL OR
                     (f2.cod_moneda = p_cod_moneda))
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
           AND (tr.cod_modalidad = p_cod_modalidad OR
               tr.cod_modalidad IS NULL)
           AND (tr.cod_moneda = p_cod_moneda OR tr.cod_moneda IS NULL)
           AND (tr.cod_oficina = v_cod_oficina OR tr.cod_oficina IS NULL)
           AND tr.val_hasta >= ww_vlmonto
           AND tr.nro_cuenta IS NULL
           AND tr.fec_vigencia =
               (SELECT MAX(tra.fec_vigencia)
                  FROM ge_tas_rangos tra
                 WHERE tra.cod_tasa = ww_cddetas
                   AND (tra.cod_modulo = v_cod_modulo OR
                       tra.cod_modulo IS NULL)
                   AND (tra.cod_modalidad = p_cod_modalidad OR
                       tra.cod_modalidad IS NULL)
                   AND (tra.cod_moneda = p_cod_moneda OR
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
        g_msj_error := 'No existe Valor para la Tasa ' ||
                       to_char(ww_cddetas) || ' y el Monto ' ||
                       to_char(ww_vlmonto) || ' Fecha ' ||
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
      v_cod_Tasa number(15);
      v_des_transaccion varchar2(35);
      v_obligatorio  varchar2(2);
      v_afecta varchar2(5);
    BEGIN

     IF v_cod_transaccion in(737,1271) AND p_tip_persona = 'J' and nvl(fug_obt_pardinamico('PRE_SEG_DIF_JURIDICAS',v_cod_modulo, p_cod_modalidad,p_cod_moneda), 'N')='S' THEN
    --Traer valor de la tasa del seguro
       v_cod_Tasa  := fug_obt_parentes(p_cod_seguro,'COD_TAS_JURIDICA');
       if  v_cod_tasa is not null then
         SELECT initcap(TR.DESCRIPCION),TA.COD_TASA,TA.APLICAR,TA.TIP_VALOR,TA.TIPO, DT.OBLIGATORIO, TR.AFECTA
          INTO v_des_transaccion,v_cod_tas_cargo,v_aplicar,v_tpvlpor,v_tpdetas,v_obligatorio,v_afecta
          FROM GE_TRANSACCIONES_DET DT, GE_TRANSACCIONES TR, GE_TASAS TA
         WHERE TR.COD_MODULO = v_cod_modulo
           AND TR.COD_MODALIDAD = p_cod_modalidad
           AND TR.COD_TRANSACCION = v_cod_transaccion
           AND TR.TIPO = 'D'
           AND v_cod_Tasa = TA.COD_TASA
           AND DT.COD_MODULO = v_cod_modulo
           AND DT.COD_MODALIDAD = p_cod_modalidad
           AND DT.COD_TRANSACCION = 358 /* transaccion de desembolso de prestamos */
           AND DT.COD_MOD_HIJO = TR.COD_MODULO
           AND DT.COD_MAD_HIJO = TR.COD_MODALIDAD
           AND DT.COD_TRA_HIJO = TR.COD_TRANSACCION;
       else
          g_cod_error := '030';
          g_lugar     := 'Busca datos tasa Per.Juridica';
          g_msj_error := 'No se encuentra definida la tasa para Seguro de Personas Juridicas. ' || SQLERRM;
       end if;

   ELSE
     if nvl(g_cod_error,'000') = '000' then
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

            v_val_tas_cargo := v_imp_cargo + ROUND(v_imp_cargo * 10/100,v_redondeo);
          else
            v_val_tas_cargo := fu_obt_valor_de_tasa_variable(v_cod_tas_cargo,
                                                     nvl(v_tot_prestamo,
                                                     p_mto_solicitado),
                                                     v_fec_inicio);
          end if;
        END IF;

      END IF;
      IF v_tpvlpor IN ('I', 'P', 'F') OR v_cod_transaccion IN (735, 736, 1270,2) THEN
        --- porcentajes  o transacciones de seguros  ---
        --v_cod_mon_cargo := v_mon_local;
        IF V_TPVLPOR = 'I' THEN
          v_cod_mon_cargo := v_mon_local;
        ELSE
          v_cod_mon_cargo := p_cod_moneda;
        END IF;
        --:VAL_TASA := WW_VLDETAS;

      ELSE
        --- en caso de que sean valores ----------------
        v_cod_mon_cargo := p_cod_moneda;
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
           AND a.cod_modalidad = p_cod_modalidad
           AND ((nvl(v_exo_impuestos, 'N') = 'N') OR
               (nvl(v_exo_impuestos, 'N') = 'S' AND
               nvl(b.obligatorio, 'N') = 'N'))
           and ((( nvl(fug_obt_pardinamico('PRE_SEG_DIF_JURIDICAS',v_cod_modulo, p_cod_modalidad,p_cod_moneda), 'N')= 'S' and (cod_ent_seguro is not null
           and p_tip_persona!= 'F'
           and cod_ent_seguro = nvl(fug_obt_pardinamico('PRE_COD_ENT_PER_JURIDICAS',v_cod_modulo, p_cod_modalidad,null),'99999'))
            or (nvl(fug_obt_pardinamico('PRE_SEG_DIF_JURIDICAS',v_cod_modulo, p_cod_modalidad,p_cod_moneda), 'N')='N'
          AND cod_ent_seguro <> nvl(fug_obt_pardinamico('PRE_COD_ENT_PER_JURIDICAS',v_cod_modulo, p_cod_modalidad,null),'9999')))
           or (p_tip_persona = 'F' and  cod_ent_seguro <> nvl(fug_obt_pardinamico('PRE_COD_ENT_PER_JURIDICAS',v_cod_modulo, p_cod_modalidad,null),'99999'))
           or cod_ent_seguro is null)
           or nvl(fug_obt_pardinamico('PRE_SEG_DIF_JURIDICAS',v_cod_modulo, p_cod_modalidad,p_cod_moneda), 'N')= 'N')
         ORDER BY 1;

    BEGIN
      if p_recalculo = 'N' then
        --   Borro los cargos por si ya se genero, DA 7202   -----
        DELETE FROM pr_sol_cargos_tmp WHERE nro_solicitud = v_nro_solicitud;
        ----------------------------------------------------------
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
               IF cc.cod_transaccion in(737,1271) THEN
                  --Calculo de seguro total simulando
                  v_tas_seguro := v_val_tas_cargo;
               END IF;

            BEGIN
             if nvl(p_mto_consolidado,0) = 0 and v_cod_transaccion = nvl(fug_obt_pardinamico('PRE_TRA_MTO_CONSOLIDADO',
                                        v_cod_modulo,
                                        p_cod_modalidad,
                                        p_cod_moneda,
                                        null),0) then
              null;
             else
              INSERT INTO pr_sol_cargos_tmp
                (nro_solicitud,
                 cod_transaccion,
                 val_tasa,
                 monto,
                 cod_tasa,
                 cod_ent_seguro,
                 cod_moneda,
                 mto_mon_prestamo)
              VALUES
                (v_nro_solicitud,
                 v_cod_transaccion,
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
          update pr_sol_cargos_tmp a
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
      v_mto_seguro        number(18,2) := 0;

    BEGIN
      --- Veo el tipo de redondeo de los calculos ------------------------------------------
      ww_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                                         V_cod_modulo,
                                         p_cod_modalidad,
                                         p_cod_moneda,
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
          ww_frances := round(( ( NVL( v_tot_prestamo, 0 ) - NVL( ww_ctrefue, 0 ) ) * ww_tasadiv * v_dias ) /
                  ( power( ( 1 + ( ww_tasadiv * v_dias ) ),( p_can_cuotas - ww_ctrefue ) ) - 1 ), ww_redondeo);
        ELSE
          --- Para los casos en que la tasa = 0 para que no de division por cero.
          ww_frances := ((NVL(v_tot_prestamo, 0) - NVL(ww_ttrefue, 0))) /
                        ((p_can_cuotas - ww_ctrefue));
        END IF;

        ------------------------
        v_val_cuota := ROUND((ww_frances * power((1 + (ww_tasadiv * v_dias)), (0))),ww_redondeo) +
                       ROUND((ww_vlsalan * ww_tasadiv * (v_dias)),ww_redondeo);

        if v_per_interes = 30 and (v_ven_fijo = 'S' or ww_ctrefue > 0) then
          v_val_cuota := fup_obt_val_cuota(p_cod_modalidad,
                                           p_cod_moneda,
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
        DELETE FROM pr_sol_cuotas_tmp WHERE nro_solicitud = v_nro_solicitud;

        FOR cuota IN 1 .. p_can_cuotas LOOP
          if cuota = 1 then
            v_fec_vto_habil  := p_fec_pri_vencimiento;
            v_fec_vto_exacto := p_fec_pri_vencimiento;
          else
            if v_per_interes/30 = trunc(v_per_interes/30) then
              -- Sumo 1 mes...
              If v_ven_fijo = 'S' then
                v_fec_vcto := ADD_MONTHS(p_fec_pri_vencimiento, (cuota - 1)*trunc(v_per_interes/30));
              Else
                v_fec_vcto := p_fec_pri_vencimiento + (((cuota - 1) * v_per_interes));
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
          v_dias := V_FEC_VTO_HABIL - v_fec_ven_anterior;
          V_SAL_CAP_ANTERIOR := ww_vlsalan;
          V_DIA_PERIODO := v_dias;
          V_DIA_INTERES := v_dias;
          V_VAL_INTERES := ROUND((ww_vlsalan * ww_tasadiv * v_dias),ww_redondeo);

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
            IF CUOTA = 1 AND ABS(v_per_interes - (p_fec_pri_vencimiento - v_fec_inicio)) > 2 THEN
              V_MTO_CAPITAL := ROUND((ww_frances * power((1 + (ww_tasadiv * v_dias)), (ww_nro - 1))),ww_redondeo);
             ELSE
              V_MTO_CAPITAL := v_val_cuota - V_VAL_INTERES;
             END IF;
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
          V_MTO_INTERES      := V_MTO_INTERES + NVL(V_VAL_INTERES, 0);
          v_fec_ven_anterior := V_FEC_VTO_HABIL;
          IF NVL(V_MTO_CAPITAL, 0) < 0 or NVL(V_VAL_INTERES, 0) < 0 THEN
            g_cod_error := '014';
            g_lugar     := 'Valida montos negativos';
            g_msj_error := 'Capital o Interes no puede quedar en negativo. Verifique';
          END IF;
          -- inserto el registro en la tabla de cuotas
          INSERT INTO pr_sol_cuotas_tmp
            (nro_solicitud,
             nro_cuota,
             fec_vencimiento,
             mto_capital,
             mto_interes,
             dia_periodo)
          VALUES
            (v_nro_solicitud,
             cuota,
             v_fec_vto_habil,
             nvl(v_mto_capital, 0),
             nvl(v_val_interes, 0),
             v_dia_periodo);

        END LOOP;

        IF abs(nvl(ww_refreal, 0) - nvl(ww_ttrefue, 0)) < 10 OR
           ww_veces > 12 OR p_tip_monto = 'N' THEN
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
        UPDATE pr_sol_cuotas_tmp
           SET mto_capital = nvl(v_mto_capital, 0),
               mto_interes = nvl(v_val_interes, 0)
         WHERE nro_solicitud = v_nro_solicitud
           AND nro_cuota = p_can_cuotas; -- ultima cuota
      END IF;
      -- vencimiento final del prestamo es igual al de la ult.cuota--
      UPDATE pr_solicitudes_tmp
         SET tot_interes = v_mto_interes
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
                               p_dias      IN NUMBER)
      RETURN NUMBER IS
      v_mto_seguro NUMBER := 0;

    BEGIN
      IF fug_obt_parentes(p_cod_ente,'COD_TAS_SEG_DESEMPLEO') = p_cod_tasa THEN
        v_mto_seguro := round((p_monto * p_val_tasa / 100) * p_dia_plazo / p_dias,-3);

      ELSIF fug_obt_parentes(p_cod_ente,'COD_TAS_SEG_CANCELACION') = p_cod_tasa THEN
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
      v_obligatorio  varchar2(2);
      v_afecta varchar2(5);
      v_sal_minimo  number(18,2) := fuh_obt_sal_minimo;
      v_can_salario number := nvl(fug_obt_pardinamico('PRE_CAN_SAL_MIN_COMISION'),5);
      v_can_jor_minimo number := fug_obt_pardinamico('PRE_CAN_JOR_MINIMOS');
      v_plazo number;
      -----------------
      v_mto_max_gas_adm number := fug_obt_pardinamico('MTO_MAX_COM_ADM',null,null, nvl(p_cod_moneda, pag_gen.FU_OBT_MON_LOCAL),null);
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
          FROM pr_sol_cargos_tmp
         WHERE nro_solicitud = v_nro_solicitud
           FOR UPDATE OF monto
         ORDER BY decode(cod_transaccion, 709, 1, 710, 2, cod_transaccion);
    BEGIN
      --- Calculo cada uno de los cargos en la moneda del cargo y en la de la simulacion ---
      --- cero los totales de cargo de tipo valor y el total general de cargos -------------
      v_ttvalor        := 0;
      v_mto_cargo      := 0;
      v_cod_tra_ajuste := NULL;
      v_mto_gas_admistrativo := pag_gen.fu_con_mon_a_moneda(pag_gen.fu_obt_mon_local, nvl(p_cod_moneda, pag_gen.FU_OBT_MON_LOCAL), fug_obt_pardinamico('MTO_TAE', 6));
      FOR cc IN cargos LOOP
        v_mto_equivalente := 0;
        -- para realizar ajustes si es necesario----------
        IF v_cod_tra_ajuste IS NULL THEN
          v_cod_tra_ajuste := cc.cod_transaccion;
        END IF;
        -- obtengo los datos de la tasa-----------------
      IF cc.cod_transaccion in(737,1271) AND p_tip_persona = 'J' and nvl(fug_obt_pardinamico('PRE_SEG_DIF_JURIDICAS',v_cod_modulo, p_cod_modalidad,p_cod_moneda), 'N')='S' THEN
    --Traer valor de la tasa del seguro
       v_cod_Tasa  := fug_obt_parentes( cc.cod_ent_seguro,'COD_TAS_JURIDICA');
       if  v_cod_tasa is not null then
         SELECT initcap(TR.DESCRIPCION),TA.COD_TASA,TA.APLICAR,TA.TIP_VALOR,TA.TIPO, DT.OBLIGATORIO, TR.AFECTA
          INTO v_des_transaccion,v_cod_tas_cargo,v_aplicar,v_tpvlpor,v_tpdetas,v_obligatorio,v_afecta
          FROM GE_TRANSACCIONES_DET DT, GE_TRANSACCIONES TR, GE_TASAS TA
         WHERE TR.COD_MODULO = v_cod_modulo
           AND TR.COD_MODALIDAD = p_cod_modalidad
           AND TR.COD_TRANSACCION = cc.cod_transaccion
           AND TR.TIPO = 'D'
           AND v_cod_Tasa = TA.COD_TASA
           AND DT.COD_MODULO = v_cod_modulo
           AND DT.COD_MODALIDAD = p_cod_modalidad
           AND DT.COD_TRANSACCION = 358 /* transaccion de desembolso de prestamos */
           AND DT.COD_MOD_HIJO = TR.COD_MODULO
           AND DT.COD_MAD_HIJO = TR.COD_MODALIDAD
           AND DT.COD_TRA_HIJO = TR.COD_TRANSACCION;
       else
          g_cod_error := '030';
          g_lugar     := 'Busca datos tasa Per.Juridica';
          g_msj_error := 'No se encuentra definida la tasa para Seguro de Personas Juridicas. ' || SQLERRM;
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
            IF cc.cod_ent_seguro IS NOT NULL and cc.cod_transaccion in (1270,1271) THEN
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
                 v_tas_seguro := cc.val_tasa;
                 v_mto_equivalente := round(v_mto_tot_seguro,v_redondeo);
              else
                   v_mto_equivalente := round(fu_cal_mto_seguro(cc.cod_tasa,
                                                           cc.cod_ent_seguro,
                                                           v_mto_interes,
                                                           cc.val_tasa,
                                                           v_dia_plazo,
                                                           v_dias),v_redondeo);
              end if;
             ELSE
               v_mto_equivalente := round(v_mto_interes * cc.val_tasa / 100,
                                       v_redondeo);
             END IF;
          END IF;
          IF v_aplicar IN ('CA', 'CI', 'PC', 'CP', 'PT', 'TP') THEN
            -- puede ser un par_ente con el codigo de ente y transaccion
            IF cc.cod_ent_seguro IS NOT NULL and cc.cod_transaccion in (1270,1271) THEN
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
                 v_tas_seguro := cc.val_tasa;
                 v_mto_equivalente := round(v_mto_tot_seguro,v_redondeo);
              else
                   v_mto_equivalente := round(fu_cal_mto_seguro(cc.cod_tasa,
                                                           cc.cod_ent_seguro,
                                                           v_tot_prestamo,
                                                           cc.val_tasa,
                                                           v_dia_plazo,
                                                           v_dias),v_redondeo);
              end if;
             ELSE
               --- es aplicable al capital --------------------------------------------------
                if cc.cod_transaccion = 737 then
                   v_tas_seguro := cc.val_tasa;
                   v_mto_equivalente := round(v_mto_tot_seguro,v_redondeo);
                else
                   v_mto_equivalente := nvl(v_mto_equivalente, 0) +
                                   round(v_tot_prestamo * cc.val_tasa / 100,
                                         v_redondeo);
                end if;
             END IF;
          END IF;

          IF v_aplicar = 'MO' THEN
             --- es aplicable al monto de la operacion -------------------------------------------
             v_plazo := round((v_dia_plazo / 30),0);
             IF cc.cod_ent_seguro IS NOT NULL and cc.cod_transaccion in (1270,1271) THEN
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
                 v_tas_seguro := cc.val_tasa;
                 v_mto_equivalente := round(v_mto_tot_seguro,v_redondeo);
              else
                 v_imp_cargo := 0;
                 v_imp_cargo :=   NVL(v_imp_cargo,0) + ROUND(p_mto_solicitado * v_plazo * cc.val_tasa / 100,v_redondeo);
                 v_mto_equivalente := v_imp_cargo;-- + ROUND(v_imp_cargo * 10/100,v_redondeo);
                 /*v_mto_equivalente := round(fu_cal_mto_seguro(cc.cod_tasa,
                                                           cc.cod_ent_seguro,
                                                           p_mto_solicitado,
                                                           cc.val_tasa,
                                                           v_dia_plazo,
                                                           v_dias),v_redondeo);*/
              end if;
             ELSE
               IF cc.cod_ent_seguro IS NOT NULL THEN
                 v_imp_cargo := 0;
                 v_imp_cargo :=   NVL(v_imp_cargo,0) + ROUND(p_mto_solicitado * v_plazo * cc.val_tasa / 100,v_redondeo);
                 v_mto_equivalente := v_imp_cargo;-- + ROUND(v_imp_cargo * 10/100,v_redondeo);
               ELSE
                 v_imp_cargo := 0;
                 v_imp_cargo :=   NVL(v_imp_cargo,0) + ROUND(p_mto_solicitado * cc.val_tasa / 100,v_redondeo);
                 v_mto_equivalente := v_imp_cargo;-- + ROUND(v_imp_cargo * 10/100,v_redondeo);
               END IF;
             END IF;
          END IF;

          IF cc.cod_transaccion in(737,1271) THEN
             v_tas_seguro := cc.val_tasa;
          END IF;
          if cc.cod_transaccion in(1) and  (p_mto_solicitado <= v_sal_minimo*NVL(v_can_salario,0))then
               v_jor_minimo:= round(v_sal_minimo/26 * v_can_jor_minimo,0);
             if v_mto_equivalente > v_jor_minimo  then
               v_imp_cargo := 0;
               v_imp_cargo :=   v_jor_minimo;
               v_mto_equivalente := v_imp_cargo;
             end if;
          elsif cc.cod_transaccion = nvl(fug_obt_pardinamico('PRE_TRA_MTO_CONSOLIDADO',
                                      v_cod_modulo,
                                      p_cod_modalidad,
                                      p_cod_moneda),0) then
               v_imp_cargo := 0;
               v_imp_cargo :=  p_mto_consolidado;
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
          if cc.cod_transaccion in(1) and  (p_mto_solicitado <= v_sal_minimo*NVL(v_can_salario,0))then
               v_jor_minimo:= round(v_sal_minimo/26 * v_can_jor_minimo,0);
             if v_mto_equivalente > v_jor_minimo  then
                v_mto_equivalente := v_jor_minimo;
             end if;
          elsif cc.cod_transaccion = nvl(fug_obt_pardinamico('PRE_TRA_MTO_CONSOLIDADO',
                                      v_cod_modulo,
                                      p_cod_modalidad,
                                      p_cod_moneda),0) then
            v_imp_cargo := 0;
            v_imp_cargo :=  p_mto_consolidado;
            v_mto_equivalente := p_mto_consolidado; --v_imp_cargo + ROUND(v_imp_cargo * 10/100,v_redondeo);
          end if;
        ELSIF v_tpvlpor = 'V' THEN
          --- es un monto valor -----------------------------------------------------------

          v_mto_equivalente := cc.monto;

        if cc.cod_transaccion in(1) and  (p_mto_solicitado <= v_sal_minimo*NVL(v_can_salario,0))then
               v_jor_minimo:= round(v_sal_minimo/26 * v_can_jor_minimo,0);
             if v_mto_equivalente > v_jor_minimo  then
                v_mto_equivalente := v_jor_minimo;
             end if;
        elsif cc.cod_transaccion = nvl(fug_obt_pardinamico('PRE_TRA_MTO_CONSOLIDADO',
                                                           v_cod_modulo,
                                                           p_cod_modalidad,
                                                           p_cod_moneda),0) then
               v_imp_cargo := 0;
               v_imp_cargo :=  p_mto_consolidado;
               v_mto_equivalente := p_mto_consolidado; --v_imp_cargo + ROUND(v_imp_cargo * 10/100,v_redondeo);
        end if;


          v_ttvalor         := nvl(v_ttvalor, 0) +
                               nvl(v_mto_equivalente, 0);


        ELSIF v_tpvlpor = 'T' THEN
        v_plazo := round((v_dia_plazo / 30), 0);
        v_val_tas_cargo := fu_obt_valor_de_tasa_variable(cc.cod_tasa,
                                                         nvl(v_tot_prestamo, p_mto_solicitado),
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
          IF nvl(v_tot_prestamo, p_mto_solicitado) <= v_mto_gas_admistrativo THEN
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
              from pr_sol_cargos_tmp a
             where a.nro_solicitud = v_nro_solicitud
               and a.cod_transaccion = 704;
          exception 
            when no_data_found then
              v_mto_adm_anterior := v_mto_equivalente;
          end;
        end if;
        --
        END IF;
        if cc.cod_transaccion = nvl(fug_obt_pardinamico('PRE_TRA_MTO_CONSOLIDADO',
                                                           v_cod_modulo,
                                                           p_cod_modalidad,
                                                           p_cod_moneda),0) then
               v_imp_cargo := 0;
               v_imp_cargo :=  p_mto_consolidado;
               v_mto_equivalente := p_mto_consolidado; --v_imp_cargo + ROUND(v_imp_cargo * 10/100,v_redondeo);
        end if;

        if cc.cod_transaccion = nvl(fug_obt_pardinamico('PRE_TRA_MTO_CONSOLIDADO',
                                                           v_cod_modulo,
                                                           p_cod_modalidad,
                                                           p_cod_moneda),0) then
        v_monto := p_mto_consolidado;
        else
        v_monto := NULL;
        --- Acumular el total de cargos (Si el tipo es Valor viene directamente aqui -------
        v_mto_cargo := nvl(v_mto_cargo, 0) + nvl(v_mto_equivalente, 0);
        ------------------------------------------------------------------------------------
        end if;

        IF v_tpvlpor IN ('I', 'P') THEN
          /* solo si es porcentaje */
          IF cc.cod_moneda = p_cod_moneda THEN
            -- moneda del cargo es igual a la moneda de la simulacion ----------------------
             v_monto := v_mto_equivalente;
          ELSE
            -- monedas diferentes, se divide por la cotiz. de la moneda de la simulacion ---
             v_monto := round(v_mto_equivalente * v_cotizacion, v_redondeo);
          END IF;
        END IF;
        if nvl(v_actualizar,'S') = 'S' then
          UPDATE pr_sol_cargos_tmp
             SET mto_mon_prestamo = nvl(v_mto_equivalente, 0),
                 monto            = nvl(v_monto, monto)
           WHERE CURRENT OF cargos;
        end if;
      END LOOP;
      IF v_mto_cargo >= v_tot_prestamo THEN
        g_cod_error := '017';
        g_lugar     := 'Valida Sumatoria de Cargos';
        g_msj_error := 'Total de Cargos ' || v_mto_cargo ||
                       ' es superior al Total del Prestamo ' || v_tot_prestamo;
      ELSE
        IF p_tip_monto = 'N' AND v_tot_prestamo <> p_mto_solicitado THEN
          --- ya estoy en el ultimo calculo de cargos netos, veo si hay ajuste --------
          /*IF nvl(v_tot_prestamo, 0) - nvl(v_mto_cargo, 0) <>
             p_mto_solicitado THEN
            -- es necesario un ajuste en el cargo del impuesto o primer cargo      ---
            ww_dfcargos       := p_mto_solicitado - (nvl(v_tot_prestamo, 0) -
                                 nvl(v_mto_cargo, 0));
            v_mto_cargo       := nvl(v_mto_cargo, 0) - ww_dfcargos;
            UPDATE pr_sol_cargos_tmp
               SET mto_mon_prestamo = nvl(mto_mon_prestamo, 0) -
                                      nvl(ww_dfcargos, 0),
                   monto            = decode(cod_moneda,
                                             p_cod_moneda,
                                             nvl(mto_mon_prestamo, 0) -
                                             nvl(ww_dfcargos, 0),
                                             decode(cod_moneda,
                                                    v_mon_local,
                                                    round(((nvl(mto_mon_prestamo,
                                                                0) -
                                                          nvl(ww_dfcargos, 0)) *
                                                          v_cotizacion),
                                                          v_redondeo),
                                                    round(((nvl(mto_mon_prestamo,
                                                                0) -
                                                          nvl(ww_dfcargos, 0)) *
                                                          v_cotizacion),
                                                          v_redondeo)))
             WHERE nro_solicitud = v_nro_solicitud
               AND cod_transaccion = v_cod_tra_ajuste;
          END IF;*/ null;
        END IF;
      END IF;
      begin
        select nvl(sum(a.monto),0)
          into v_mto_cargo
          from pr_sol_cargos_tmp a
         where a.nro_solicitud = v_nro_solicitud;
      end;
      -- actualizo el total de cargos de  la solicitud
      UPDATE pr_solicitudes_tmp
         SET tot_cargos = v_mto_cargo
       WHERE nro_solicitud = v_nro_solicitud;
    EXCEPTION
      WHEN OTHERS THEN
        g_cod_error := '018';
        g_lugar     := 'Valida Calculo Cargos';
        g_msj_error := 'Error al calcular cargos ' || SQLERRM;
    END;

    FUNCTION fu_obt_dat_simulacion(p_nro_solicitud in number) return typ_consolicitud
      IS
      v_can_detalles   NUMBER(10);
      datosSolicitud   typ_conSolicitud     := typ_conSolicitud();

      CURSOR sim IS
        SELECT *
          FROM pr_solicitudes_tmp a
         WHERE a.nro_solicitud = p_nro_solicitud;

    BEGIN
      --v_can_detalles := 0;
      FOR a IN sim LOOP
        datosSolicitud.codigoerror           := '000';
        datosSolicitud.nombrerespuesta       := 'Sin Error';
        datosSolicitud.descripcionrespuesta  := 'Proceso culminado con exito';
        datosSolicitud.nrosolicitud          := a.nro_solicitud;
        datosSolicitud.descripcion           := a.descripcion;
        datosSolicitud.monto                 := a.monto;
        datosSolicitud.diaplazo              := a.dia_plazo;
        datosSolicitud.fecvencimiento        := a.fec_vencimiento;
        datosSolicitud.codpersona            := a.cod_persona;
        datosSolicitud.fecinicio             := a.fec_inicio;
        datosSolicitud.totprestamo           := a.tot_prestamo;
        datosSolicitud.codmodulo             := a.cod_modulo;
        datosSolicitud.codmodalidad          := a.cod_modalidad;
        datosSolicitud.desmodalidad          := fug_obt_des_modal(a.cod_modulo,a.cod_modalidad);
        datosSolicitud.codmoneda             := a.cod_moneda;
        datosSolicitud.codoficina            := a.cod_oficina;
        datosSolicitud.fecprivencimiento     := a.fec_pri_vencimiento;
        datosSolicitud.valtasa               := a.val_tasa;
        datosSolicitud.cancuotas             := a.can_cuotas;
        datosSolicitud.totcargos             := a.tot_cargos;
        datosSolicitud.totinteres            := a.tot_interes;
        --datosSolicitud.listaconcargo       := fu_obt_dat_sim_cargos(p_nro_solicitud);
        --datosSolicitud.typ_consolicitud    := null;
      END LOOP;
        --listaCheques.extend;
        --v_can_detalles := v_can_detalles + 1;
        --listaCheques(listaCheques.count) := detalleCheque;

    return datosSolicitud;

  end;

    FUNCTION fu_obt_dat_sim_cargos(p_nro_solicitud in number) return typ_listaconcargo
      IS
      datosCargo       typ_conCargo         := typ_conCargo();
      datosSolCargos   typ_listaConCargo    := typ_listaConCargo();
      v_can_cargos     number               := 0;
      CURSOR sim_car IS
        SELECT *
          FROM pr_sol_cargos_tmp a
         WHERE a.nro_solicitud = p_nro_solicitud;
    BEGIN
      FOR b IN sim_car LOOP
        datosCargo.nroSolicitud   := b.nro_solicitud;
        datosCargo.codTransaccion := b.cod_transaccion;
        datosCargo.desTransaccion := fug_obt_des_transaccion(6,p_cod_modalidad,b.cod_transaccion);
        datosCargo.valTasa        := nvl(b.val_tasa,0);
        datosCargo.monto          := nvl(b.monto,0);
        datosCargo.codTasa        := b.cod_tasa;
        datosCargo.codEntSeguro   := b.cod_ent_seguro;
        datosCargo.codMoneda      := b.cod_moneda;
        datosCargo.mtoMonPrestamo := b.mto_mon_prestamo;
        --v_det_cargos.typ_concargo
        datosSolCargos.extend;
        v_can_cargos := v_can_cargos + 1;
        datosSolCargos(datosSolCargos.count):= datosCargo;
      END LOOP;
    return datosSolCargos;
  end;

    FUNCTION fu_obt_dat_sim_cuotas(p_nro_solicitud in number) return typ_listaconcuota
      IS
      datosCuota       typ_conCuota         := typ_conCuota();
      datosSolCuotas   typ_listaConCuota    := typ_listaConCuota();
      v_can_cuotas     number               := 0;
      CURSOR sim_cuo IS
        SELECT *
          FROM pr_sol_cuotas_tmp a
         WHERE a.nro_solicitud = p_nro_solicitud;
    BEGIN
      FOR c IN sim_cuo LOOP
        datosCuota.nroSolicitud     := c.nro_solicitud;
        datosCuota.nroCuota         := c.nro_cuota;
        datosCuota.fecVencimiento   := c.fec_vencimiento;
        datosCuota.mtoCapital       := c.mto_capital;
        datosCuota.mtoInteres       := c.mto_interes;
        datosCuota.diaPeriodo       := c.dia_periodo;
        --v_det_cargos.typ_concargo
        datosSolCuotas.extend;
        v_can_cuotas := v_can_cuotas + 1;
        datosSolCuotas(datosSolCuotas.count):= datosCuota;
      END LOOP;
    return datosSolCuotas;
  end;
  BEGIN   
    v_max_tasa   := 'N';
    v_max_gastos := 'N';
    v_tasa_back  :=  0;
    v_bandera    := null;
    v_tasa_mod   := null;
    v_si_maximiza:= 'N';
    g_msj_error := ' ';
    g_cod_error := 0;
    --- Veo el tipo de redondeo de los calculos ------------------------------------------
    v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                                      6,
                                      p_cod_modalidad,
                                      p_cod_moneda);
    -- Valido el codigo de la modalidad que recibo----------------------------
    if nvl(g_cod_error,'000') = '000' then
      pr_val_cod_modalidad;
    end if;

    -- valido la moneda-------------------------------------------------------
    if nvl(g_cod_error,'000') = '000' then
      pr_val_cod_moneda;
    end if;

    -- valido el monto -------------------------------------------------------
    IF nvl(g_cod_error,'000') = '000' and nvl(p_mto_solicitado, 0) <= 0 THEN
      g_cod_error := '005';
      g_lugar     := 'Valida Monto Ingresado';
      g_msj_error := 'Ingrese Monto del Credito';
    END IF;

    v_tot_prestamo := p_mto_solicitado;

    -- valido el tipo de monto -----------------------------------------------
    IF nvl(g_cod_error,'000') = '000' and nvl(p_tip_monto, 'X') NOT IN ('B', 'N') THEN
      g_cod_error := '006';
      g_lugar     := 'Valida Tipo Monto';
      g_msj_error := 'Tipo de Monto debe ser B-Bruto o N-Neto';
    END IF;

    -- valido la cantidad de cuotas ------------------------------------------
    IF nvl(g_cod_error,'000') = '000' and nvl(p_can_cuotas, 0) < 1 THEN
      g_cod_error := '007';
      g_lugar     := 'Valida Cantidad Cuotas';
      g_msj_error := 'Ingrese la cantidad de cuotas';
    END IF;
  ----desde aqui

  V_CAN_DIA_PRI_VCTO :=  fug_obt_pardinamico('CAN_DIA_PRI_VCTO',
                                 6,
                                 p_cod_modalidad,
                                 p_cod_moneda,
                                 v_cod_oficina);
  v_can_dia_min_pri_vcto :=  fug_obt_pardinamico('CAN_DIA_MIN_PRI_VENCIMIENTO',
                                 6,
                                 p_cod_modalidad,
                                 p_cod_moneda,
                                 v_cod_oficina);
  if v_can_dia_min_pri_vcto is null then
    v_can_dia_min_pri_vcto := 15;
  end if;
  ---
  IF nvl(g_cod_error,'000') = '000' and p_fec_pri_vencimiento IS NULL THEN
      g_cod_error := '008';
      g_lugar     := 'Valida Primer vencimiento';
      g_msj_error := 'Ingrese Primer Vencimiento del Prestamo.';
  END IF;
    -- Valido la fecha del primer vencimiento --------------------------------
  IF nvl(g_cod_error,'000') = '000' and p_fec_pri_vencimiento <= v_fec_actual AND p_cod_modalidad <> 660 THEN
      g_cod_error := '009';
      g_lugar     := 'Valida Primer vencimiento';
      g_msj_error := 'Primer Vencimiento debe ser posterior a la fecha de Hoy';
   END IF;

  -- Controla los dias del primer vencimiento...
  IF nvl(g_cod_error,'000') = '000' and ((p_fec_pri_vencimiento - v_fec_actual) > v_can_dia_pri_vcto) THEN
      g_cod_error := '010';
      g_lugar     := 'Valida Primer vencimiento';
      g_msj_error := 'Primer Vencimiento no debe ser posterior a los '||v_can_dia_pri_vcto||' dias.';
  END IF;

  -- Controla los dias del primer vencimiento...
  IF nvl(g_cod_error,'000') = '000' and ((p_fec_pri_vencimiento - v_fec_actual) < v_can_dia_min_pri_vcto) THEN
      g_cod_error := '010';
      g_lugar     := 'Valida Primer Vencimiento';
      g_msj_error := 'Primer Vencimiento no debe ser menor a los '||v_can_dia_min_pri_vcto||' dias.';
  END IF;

  IF nvl(g_cod_error,'000') = '000' and nvl(fug_obt_pardinamico('PRE_MOD_AFD',6, p_cod_modalidad,p_cod_moneda), 'N')= 'S'then
    pp_val_dias_gracia;
  end if;



    ---hasta aqui

    -- valido el tipo de persona  --------------------------------------------
    IF nvl(g_cod_error,'000') = '000' and p_tip_persona is null THEN
      g_cod_error := '009';
      g_lugar     := 'Valida Tipo Persona';
      g_msj_error := 'Ingrese el tipo de persona';
    END IF;
    -- valido el tipo de persona  --------------------------------------------
    IF nvl(g_cod_error,'000') = '000' and p_tip_persona is not null
      and p_tip_persona not in ('F','J') THEN
      g_cod_error := '010';
      g_lugar     := 'Valida Tipo Persona';
      g_msj_error := 'Valor incorrecto. (Tipo F-Fisica/ J-Juridica)';
    END IF;

    v_dia_plazo   := add_months(p_fec_pri_vencimiento, p_can_cuotas - 1) -
                     v_fec_inicio;

    v_per_capital := 30;

    
    -- Valido la tasa de interes And agregado DA 7202---------------------------------------------
    IF nvl(g_cod_error,'000') = '000' and nvl(v_max_tasa,'N') = 'N' then
      pr_val_tasa;
    end if;

    
    --- Recupero secuencia negativa para solicitud auxiliar
    IF nvl(g_cod_error,'000') = '000' then     
        SELECT s_nro_sol_tmp.nextval
          INTO v_nro_solicitud
          FROM dual;

        -- inserto el registro en la tabla de solicitudes ------------------------
        BEGIN
          INSERT INTO pr_solicitudes_tmp
            (nro_solicitud,
             descripcion,
             monto,
             dia_plazo,
             fec_vencimiento,
             fec_inicio,
             tip_monto,
             tot_prestamo,
             cod_modulo,
             cod_modalidad,
             cod_moneda,
             cod_oficina,
             fec_pri_vencimiento,
             val_tasa,
             can_cuotas,
             tip_amortizacion)
           VALUES
            (v_nro_solicitud,
             'CONSUMO',
             p_mto_solicitado,
             v_dia_plazo,
             v_fec_inicio + v_dia_plazo,
             v_fec_inicio,
             p_tip_monto,
             v_tot_prestamo,
             v_cod_modulo,
             p_cod_modalidad,
             p_cod_moneda,
             v_cod_oficina,
             p_fec_pri_vencimiento,
             v_val_tasa,
             p_can_cuotas,
             v_tip_amortizacion/* price */);

        EXCEPTION
          WHEN OTHERS THEN
            g_cod_error := '019';
            g_lugar     := 'Inserta Propuesta';
            g_msj_error := 'Error al insertar la propuesta. ' || SQLERRM;
        END;
    END IF;
    <<recalculo>>
    -- genero los cargos por defecto
    IF nvl(g_cod_error,'000') = '000' THEN
      pr_gen_cargos(v_recalculo);
    END IF;

    -- generar cuotas --------------------------------------------------------
    IF nvl(g_cod_error,'000') = '000' THEN
      pr_gen_cuotas('N');
    END IF;    
    
    -- Calculo los cargos ----------------------------------------------------
    IF nvl(g_cod_error,'000') = '000' THEN
      pr_cal_cargos(v_recalculo);
    END IF;

    -- verifico el tipo de prestamo
    IF nvl(g_cod_error,'000') = '000' THEN
    IF p_tip_monto = 'B' THEN
      v_tot_prestamo := p_mto_solicitado;
    ELSE
      select sum(nvl(a.monto,0))
        into v_mto_cargo
        from pr_sol_cargos_tmp a
       where a.nro_solicitud = v_nro_solicitud
         and a.cod_transaccion != nvl(fug_obt_pardinamico('PRE_TRA_MTO_CONSOLIDADO',
                                      v_cod_modulo,
                                      p_cod_modalidad,
                                      p_cod_moneda,
                                      null),0);

      --- monto ingresado es el neto -----------------------------------------------------
      v_por_ajuste := (p_mto_solicitado - (v_mto_cargo - v_ttvalor)) * 100 /
                      (p_mto_solicitado + v_ttvalor);

      --- calculo del nuevo capital (monto bruto -----------------------------------------
      v_tot_prestamo := round((p_mto_solicitado * 100 / v_por_ajuste),
                              v_redondeo);

      --- Vuelvo a generar las cuotas y calcular los cargos ------------------------------
      IF nvl(g_cod_error,'000') = '000' then
        pr_gen_cuotas('S');
      END IF;

      -- recalculo los cargos ------------------------------------------------------------
      IF nvl(g_cod_error,'000') = '000' then
        pr_cal_cargos(v_recalculo);
      END IF;

      WHILE NVL(v_TOT_PRESTAMO,0)-NVL(v_MTO_CARGO,0) <> p_mto_solicitado LOOP
        v_por_ajuste := p_mto_solicitado - (NVL(v_TOT_PRESTAMO,0)-NVL(v_MTO_CARGO,0));
        if v_por_ajuste = 1 then --para evitar que se cuelgue el proceso
          v_TOT_PRESTAMO := p_mto_solicitado + NVL(v_MTO_CARGO,0);
          --- Vuelvo a generar las cuotas ------------------------------
          IF nvl(g_cod_error,'000') = '000' then
            pr_gen_cuotas('S');
          END IF;
          
        else
          v_TOT_PRESTAMO := v_TOT_PRESTAMO + v_POR_AJUSTE;

          --- Vuelvo a generar las cuotas y calcular los cargos ------------------------------
          IF nvl(g_cod_error,'000') = '000' then
            pr_gen_cuotas('S');
          END IF;

          -- recalculo los cargos ------------------------------------------------------------
          IF nvl(g_cod_error,'000') = '000' then
            pr_cal_cargos(v_recalculo);
          END IF;

        end if;
      END LOOP;

      -- actualizo el total del prestamo -------------------------------------------------
      IF nvl(g_cod_error,'000') = '000' then
        UPDATE pr_solicitudes_tmp
           SET tot_prestamo = v_tot_prestamo
         WHERE nro_solicitud = v_nro_solicitud;
      END IF;
      ------------------------------------------------------------------------------------
    END IF;
    END IF;
    
    --maximización de tasa DA 7202
    IF nvl(g_cod_error,'000') = '000' then
    v_codi_tasa := 351; 
    begin
       pag_gen.pr_obt_val_tasa(v_cod_modulo, p_cod_modalidad, v_cod_oficina,
       null , p_cod_moneda, p_mto_solicitado, 'S', v_codi_tasa /*out*/, null ,v_fec_actual,         
       v_valor_tasa /*out*/, v_fec_vigencia/*out*/, v_tipo_valor /*out*/, v_tipo/*out*/, null);               
    exception
     when others then
      v_max_tasa := 'X';
    End;   
    if instr(fug_obt_pardinamico('MAD_VAL_TAE_GAS_ADM'),','||p_cod_modalidad||',') > 0
        and p_mto_solicitado <= fug_obt_pardinamico('MTO_SOL_MAX_ADM',6,p_cod_modalidad,p_cod_moneda) then
        v_max_gastos := 'S';
    Else
       v_max_gastos := 'N';
    End if;
    
    If nvl(v_max_tasa,'N') <> 'X' AND (p_mto_solicitado between pag_gen.FU_OBT_VAL_MINIMO and pag_gen.FU_OBT_VAL_MAXIMO ) 
    AND to_number(nvl(fug_obt_pardinamico('VAL_INI_AUMTASA',null,null, p_cod_moneda, null),0),'999G999D999999', 'NLS_NUMERIC_CHARACTERS='',.''') <> 0 then
	      v_max_tasa := 'S';       
    else
        v_max_tasa := 'N';
    End if;

    If nvl(v_max_tasa,'N') = 'S' and nvl(v_max_gastos,'N') = 'S' THEN 
        g_cod_error := '025';
        g_lugar     := 'Maximizacion de tasas y de gastos';
        g_msj_error := 'Verifique los montos definidos para la maximización de tasas y comisiones, dichos montos no deben solaparse.';
    end if; 
    
   
    IF nvl(g_cod_error,'000') = '000' then  
      If nvl(v_max_tasa,'X') = 'S' then
       pap_sim.pr_obt_tas_tmp(v_nro_solicitud, null, v_tae, v_tan);          
       If  nvl(v_tas_efectiva, 0) <> 0 then
         If nvl(v_tae,0) > nvl(v_tas_efectiva, 0) and nvl(v_tasa_back,0) > 0  then 
             v_val_tasa := nvl(v_tasa_back,0);                 
             v_valor_aum := round( (v_valor_aum / 2 ) , 3);	
             If( nvl(v_val_tasa + v_valor_aum,0) between nvl(v_tas_minima,0) and nvl(v_tas_maxima,0) ) then 		 
               v_val_tasa := v_val_tasa + v_valor_aum;
               v_bandera := 'N';
               BEGIN
                update pr_solicitudes_tmp a
                   set a.val_tasa = v_val_tasa
                where a.nro_solicitud = v_nro_solicitud;
               END;
               goto recalculo;
             end if;
         elsif nvl(v_tae,0) < nvl(v_tas_efectiva, 0) then
            IF nvl(v_bandera,'S') = 'S' then
              v_tasa_back := v_val_tasa;
              If( nvl(v_val_tasa + v_valor_aum,0) between nvl(v_tas_minima,0) and nvl(v_tas_maxima,0) ) then 	
               v_val_tasa := v_val_tasa + v_valor_aum;
                BEGIN
                  update pr_solicitudes_tmp a
                     set a.val_tasa = v_val_tasa
                  where a.nro_solicitud = v_nro_solicitud;
                END;
                goto recalculo;
              end if;
            end if;
          end if;
       end if;
     end if;--Fin de max_tasa = 'S'
    End if;--Fin de gcod_error = 000
    End if;   
    
    
    -- Maximización de cargos
    IF nvl(g_cod_error,'000') = '000' then 
     if nvl(v_max_gastos, 'N') = 'S' then
      if instr(fug_obt_pardinamico('MAD_VAL_TAE_GAS_ADM'),','||p_cod_modalidad||',') > 0
        and p_mto_solicitado <= fug_obt_pardinamico('MTO_SOL_MAX_ADM',6,p_cod_modalidad,p_cod_moneda) then
        pap_sim.pr_obt_tas_tmp(v_nro_solicitud, null, v_tae, v_tan);
        if nvl(v_tas_efectiva, 0) <> 0 then
          if v_tae > nvl(v_tas_efectiva, 0) then
            if nvl(v_mto_adm_anterior,0) > 0 then
              begin
                update pr_sol_cargos_tmp a
                   set a.monto = v_mto_adm_anterior,
                       a.mto_mon_prestamo = v_mto_adm_anterior
                 where a.nro_solicitud = v_nro_solicitud
                   and a.cod_transaccion = 704;
              end;
            else
              v_fin_max := 'S';
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
    end if;--Fin de vmax_gastos = 'S'
    End if; --Fin de nvl(g_cod_error,'000') = '000' then 
    --
    /*
    begin
      update pr_sol_garantias a
      set a.mto_aplicado = V_TOT_PRESTAMO
      where a.nro_solicitud = v_nro_solicitud;
    end;
    */
    
   IF nvl(g_cod_error,'000') = '000' then 
     pap_sim.pr_obt_tas_tmp(v_nro_solicitud, null, v_tae, v_tan);
      If nvl(v_tae,0) > nvl(v_tas_efectiva, 0)  Then
        g_cod_error := '052';
        g_lugar     := 'Supera TAE';
        g_msj_error := 'Valor obtenido :'||v_tae||' valor pizzarra:'||v_tas_efectiva;
      end if;           
    end if;        
    
    -- Obtengo datos de solicitud
    IF nvl(g_cod_error,'000') = '000' then
      v_consolicitud := fu_obt_dat_simulacion(v_nro_solicitud);
      v_consolcargos := fu_obt_dat_sim_cargos(v_nro_solicitud);
      v_consolcuotas := fu_obt_dat_sim_cuotas(v_nro_solicitud);
    else
      v_consolicitud.codigoerror          := g_cod_error;
      v_consolicitud.nombrerespuesta      := g_lugar;
      v_consolicitud.descripcionrespuesta := g_msj_error;
      v_consolicitud.nrosolicitud         := null;
      v_consolicitud.descripcion          := null;
      v_consolicitud.monto                := null;
      v_consolicitud.diaplazo             := null;
      v_consolicitud.fecvencimiento       := null;
      v_consolicitud.codpersona           := null;
      v_consolicitud.fecinicio            := null;
      v_consolicitud.totprestamo          := null;
      v_consolicitud.codmodulo            := null;
      v_consolicitud.codmodalidad         := null;
      v_consolicitud.codmoneda            := null;
      v_consolicitud.codoficina           := null;
      v_consolicitud.fecprivencimiento    := null;
      v_consolicitud.valtasa              := null;
      v_consolicitud.cancuotas            := null;
      --v_consolicitud.typ_consolicitud
    end if;

    p_solicitud := v_consolicitud;
    p_cargos    := v_consolcargos;
    p_cuotas    := v_consolcuotas;

  end;

  -- Validacion de los cheque--------------
    PROCEDURE pr_val_cheques(p_nro_cheque in number,
                             p_monto in number,
                             p_fec_emision in date,
                             p_fec_vencimiento in date,
                             p_dias number) IS
       --v_fec_actual          DATE := '31/03/2020';--pag_cal.fu_obt_fec_actual(v_cod_modulo);
       ---v_dias        number(5);
    BEGIN


      --Ver si se debe validar ingreso de nro_cheque
      /*if p_nro_cheque is null then
         g_cod_error := 3;
         g_lugar := 'Valida Nro. Cheque';
         g_msj_error := 'Ingrese numero de Cheque';
      end if;*/
      if nvl(p_monto,0) <= 0 then
         g_cod_error := 3;
         g_lugar := 'Valida monto cheque';
         g_msj_error := 'Monto invalido. Cheque: '||p_nro_cheque;
      end if;

      if pap_sim.g_cod_error = 0 then
        if p_Fec_emision is null then
           g_cod_error := 3;
           g_lugar := 'Valida Fecha Emision';
           g_msj_error :='Debe ingresar la fecha de emision del cheque';
        else
         if p_fec_emision > v_fec_actual then
             g_cod_error := 3;
             g_lugar := 'Valida Fecha emision';
             g_msj_error := 'Fecha de emision no puede ser mayor a la actual. Cheque: '||p_nro_cheque||' Fecha: '||v_fec_actual;
         end if;
        end if;
      end if;

      if pap_sim.g_cod_error = 0 then
        if p_fec_vencimiento is null then
             g_cod_error := 3;
             g_lugar := 'Valida Fecha vencimiento';
             g_msj_error := 'Debe ingresar la fecha de vencimiento del cheque';
        else
            if p_fec_vencimiento <= v_fec_actual then
               g_cod_error := 3;
               g_lugar := 'Valida Fecha vencimiento';
               g_msj_error := 'Fecha de vencimiento menor o igual a la actual. Cheque: '||p_nro_cheque||' Fecha: '||v_fec_actual;
            end if;
        end if;
      end if;
      If p_fec_vencimiento - p_fec_emision > p_dias Then
         g_cod_error := 3;
         g_lugar := 'Valida Fecha vencimiento';
         g_msj_error :='El vencimiento no puede ser mayor a la emision en mas de '||p_dias||' dias';
       End if;
    END;
   procedure pr_sim_pre_descuento(p_tip_persona          in varchar2 default 1, --1-Fisica, 2- Juridica
                                  p_cod_modalidad        in number,
                                  p_cod_moneda           in varchar2,
                                  p_monto                in number,
                                  p_can_documento        in number,
                                  p_val_tasa             in number,
                                  p_cod_ent_seguro       in number,
                                  p_cod_persona          in varchar2,
                                  p_tas_impositiva       in number default 10,
                                  p_chequesdet           in typ_cheques,
                                  p_fec_inicio           in date,
                                  p_fec_pri_vencimiento  in date,
                                  p_cod_tasa             in number,
                                  p_fec_vencimiento      in  date,
                                  p_descripcion          in varchar2,
                                  p_cod_oficina          in number,
                                  p_tip_monto            in varchar2 default 'B',
                                  p_solicitud            out typ_dessolicitud,
                                  p_cuotas out typ_listadescuota,
                                  p_cargos out typ_listadescargo) IS

     v_dummy               NUMBER(9);
     v_tot_prestamo        NUMBER(18, 2) := 0; -- total del prestamo
     v_dia_plazo           NUMBER(8);
     v_cod_modulo          NUMBER(3) := 6; -- prestamos
     v_cod_oficina         NUMBER(3):= fug_obt_ofi_usuario(user);
     v_mon_local           VARCHAR2(3) := pag_gen.fu_obt_mon_local;
     v_cotizacion          ge_cotizaciones.val_conversion%TYPE := pag_gen.fu_obt_cotizacion(p_cod_moneda);
     v_lugar               VARCHAR2(200) := NULL;
     v_exo_impuestos       VARCHAR2(1) := 'N';
     v_val_tasa            NUMBER(18,2):= p_val_tasa;
     v_nro_solicitud       NUMBER(10);
     v_fec_inicio          DATE := nvl(p_Fec_inicio,v_fec_actual);
     -- Datos de los cargos -----------------------------------------------------
     v_cod_transaccion NUMBER(4);
     v_cod_tas_cargo   NUMBER(4);
     v_cod_Tas_seguro  NUMBER(4);
     v_val_Tas_seguro  NUMBER(18,4);
     v_val_tas_tpm  NUMBER(18,4);
     v_cod_tas_tpm     NUMBER(4);
     v_val_tas_cargo   NUMBER(18,4);
     v_cod_mon_cargo   VARCHAR2(3);
     v_tpvlpor         VARCHAR2(1);
     v_aplicar         VARCHAR2(3);
     v_tpdetas         VARCHAR2(1);
     v_val_cargo       NUMBER(18, 4);
     v_cod_ent_seguro  NUMBER(6);
     v_cuotas          typ_descuotas;
     v_cargos          typ_listadescargo;
     v_des_transaccion VARCHAR2(120);
     -- control del redondeo ----------------------------------------------------
     v_redondeo  NUMBER(2) := 0; -- redondeo a cero para moneda local
     v_descripcion      VARCHAR2(100) := nvl(p_descripcion,fug_obt_des_modal(v_cod_modulo,p_cod_modalidad));
     v_tot_cargos  number(20);
     v_tip_interes varchar2(1) := 'A';
     v_tip_amortizacion varchar2(1) := 'F';
     v_vto_capital number(10);
     v_mto_interes number(20,4);
     v_cuo_final typ_listadescuota;
     v_solicitud typ_dessolicitud  := typ_dessolicitud();
     v_tot_cargo number(18,4);
     V_TTVALOR   number(18,2);
     v_desembolsar number(18,2);
     v_tas_impositiva number(10) := NVL(p_tas_impositiva,10);
     v_cod_moneda     varchar2(3);
     v_tot_monto      number(18,2);
     v_tip_persona    varchar2(8);
     V_FEC_PRI_VENCIMIENTO DATE := P_FEC_PRI_VENCIMIENTO;
     v_FEC_VENCIMIENTO date;
     listaCheques  TYP_LISTACHEQUES;
     v_vto_hab_cheques varchar2(1);
     V_CAN_DIA_PRI_VCTO number;
     v_tas_seguro      NUMBER(18,4);
     v_mto_tot_seguro   NUMBER(18,4);
     v_tot_che_futuro  NUMBER(18,4);
     v_car_tipvalor        number :=0; -- para los cargos de tipo valor
    -- V_DIA_PLAZO        number;

     v_ent_seguro number(7):= p_cod_ent_seguro;--nvl(p_cod_ent_seguro,3400);--Si no se ingresa el ente se asigna a PANAL
     -----Max tasa DA 7202
     v_valor_aum pr_sol_tasas.val_tasa%TYPE := to_number(nvl(fug_obt_pardinamico('VAL_INI_AUMTASA',null,null, p_cod_moneda, null),0),'999G999D999999', 'NLS_NUMERIC_CHARACTERS='',.''');
     ------------------ rutinas internas del procedimiento-----------------------

    -- Validacion del tipo de credito---------------------------------------------
    PROCEDURE pr_val_parametros(p_tip_persona          in varchar2, --1-Fisica, 2- Juridica
                                p_cod_modalidad        in number,
                                p_cod_moneda           in varchar2,
                                p_monto                in number,
                                p_can_documento        in number,
                                p_val_tasa             in number,
                                p_tas_impositiva       in number,
                                p_ent_seguro           in varchar2) IS

    v_exi_ente varchar2(1);
    BEGIN

      g_msj_error := ' ';
      g_cod_error := 0;
      g_lugar     := ' ';
      --Ver si se debe validar ingreso de nro_cheque
     if pap_sim.g_cod_error = 0 then
       if p_tip_persona is null then
          g_cod_error := 1;
          g_lugar := 'Valida Tipo de persona';
          g_msj_error := 'Debe ingresar Tipo de Persona ';
       end if;
        if pap_sim.g_cod_error = 0 then
           if p_tip_persona not in('1','2') then
              g_cod_error := 2;
              g_lugar := 'Valida Tipo de persona';
              g_msj_error := 'Tipo de persona no corresponde (Fisica= 1, Juridica= 2';
           end if;
        end if;
       end if;

     if pap_sim.g_cod_error = 0 then
       if p_cod_modalidad is null then
          g_cod_error := 3;
          g_lugar := 'Valida Modalidad';
          g_msj_error := 'Debe ingresar Modalidad del Prestamo ';
       end if;
     end if;
     if pap_sim.g_cod_error = 0 then
       if p_cod_moneda is null then
         g_cod_error := 4;
         g_lugar := 'Valida Moneda';
         g_msj_error := 'Ingrese Moneda del prestamo';
       end if;
     end if;
     --No validar monto, asignar de acuerdo a monto de cheques
     /*if pap_sim.g_cod_error = 0 then
       if nvl(p_monto,0) <= 0 then
         g_cod_error := 4;
         g_lugar := 'Valida Monto';
         g_msj_error := 'Monto del Prestamo invalido.';
       end if;
     end if;*/

     if pap_sim.g_cod_error = 0 then
         if p_can_documento is null then
             g_cod_error := 5;
             g_lugar := 'Valida Cantidad Documentos';
             g_msj_error := 'Debe ingresar cantidad de Documentos';
         end if;
     end if;

     /*IF nvl(pap_sim.g_cod_error,0) = 0 and p_fec_pri_vencimiento IS NULL THEN
        g_cod_error := 6;
        g_lugar     := 'Valida Primer vencimiento';
        g_msj_error := 'Ingrese Primer Vencimiento del Prestamo.';
     END IF;*/
    -- Valido la fecha del primer vencimiento --------------------------------
     IF nvl(pap_sim.g_cod_error,0) = 0 and p_fec_pri_vencimiento <= v_fec_actual AND p_cod_modalidad <> 660 THEN
        g_cod_error := 7;
        g_lugar     := 'Valida Primer vencimiento';
        g_msj_error := 'Primer Vencimiento debe ser posterior a la fecha de Hoy';
     END IF;

   -- Controla los dias del primer vencimiento...
     IF nvl(pap_sim.g_cod_error,0) = 0 and (p_fec_pri_vencimiento - v_fec_actual) > v_can_dia_pri_vcto THEN
        g_cod_error := 8;
        g_lugar     := 'Valida Primer vencimiento';
        g_msj_error := 'Primer Vencimiento no debe ser posterior a los '||v_can_dia_pri_vcto||' dias.';
     END IF;


     if pap_sim.g_cod_error = 0 then
       if p_ent_seguro is null and p_tip_persona = 1 then
          g_cod_error := 9;
          g_lugar := 'Valida Ente de Seguro';
          g_msj_error := 'Debe ingresar el Ente del seguro ';
       elsif p_tip_persona = 1 then
         begin
          select 'S'
            into v_exi_ente
            from ge_entes e
           where e.tipo = 'SE'
             and e.cod_ente= p_ent_seguro;
         exception
            when no_data_found then
                g_cod_error := 6;
                g_lugar := 'Valida Ente de Seguro';
                g_msj_error := 'Ente de seguro inexistente';
         end;
       end if;
     end if;
      /*if pap_sim.g_cod_error = 0 then
         if p_val_tasa is null then
             g_cod_error := 6;
             g_lugar := 'Valida Tasa';
             g_msj_error := 'Ingrese valor de tasa para la Operacion';
         end if;
      end if;*/

        /*if pap_sim.g_cod_error = 0 then
          if p_tas_impositiva is null then
             g_cod_error := 8;
             g_lugar := 'Valida Tasa Impositiva';
             g_msj_error := 'Debe ingresar Tasa Impositiva ';
          end if;
       end if;*/
       /* IF pap_sim.g_cod_error = 0 then
          IF (p_chequesdet IS NULL) THEN
             g_cod_error := 8;
             g_lugar := 'Valida Detalle de Cheques';
             g_msj_error := 'No existe detalle de Cheques';
           END IF;
        END IF;  */

    END;
    PROCEDURE pr_val_tasa IS
      CURSOR pizarras IS
        SELECT a.tas_interes, a.tas_minima, a.tas_maxima, a.tas_efectiva
          FROM cr_piz_montos b, cr_piz_plazos a
         WHERE a.cod_modulo = v_cod_modulo
           AND a.cod_modalidad = p_cod_modalidad
           AND a.cod_moneda = p_cod_moneda
           AND b.cod_modulo = a.cod_modulo
           AND b.cod_modalidad = a.cod_modalidad
           AND b.cod_moneda = a.cod_moneda
           AND b.mto_desde = a.mto_desde
           AND p_monto BETWEEN b.mto_desde AND b.mto_hasta
           AND v_dia_plazo BETWEEN a.plz_desde AND a.plz_hasta;

    BEGIN
      v_lugar := 'obtener_tasas de pizarras';
      OPEN pizarras;
      FETCH pizarras
        INTO v_tas_interes, v_tas_minima, v_tas_maxima, v_tas_efec;
      CLOSE pizarras;
      IF v_val_tasa IS NULL THEN
        v_val_tasa := nvl(v_tas_interes,32);
      ELSE    
        -- valido la tasa ingresada---        
        IF (NOT v_val_tasa BETWEEN nvl(v_tas_minima,0) AND nvl(v_tas_maxima,0))
          or v_val_tasa = 0 THEN
           g_cod_error := 1;
           g_lugar := 'Valida Tasa ingresada';
           g_msj_error := 'Tasa fuera de Rango. Valor min.:'||nvl(v_tas_minima,0)||' max:'||nvl(v_tas_maxima,0);
        END IF;
      END IF;
    END;
     /* Obtener tasas de pizarra. */
  /* PROCEDURE pr_obt_tas_pizarra
   (
      p_cod_modulo         IN ge_cuentas.cod_modulo%TYPE,
      p_cod_modalidad      IN ge_cuentas.cod_modalidad%TYPE,
      p_cod_moneda         IN ge_cuentas.cod_moneda%TYPE,
      p_plazo              IN NUMBER,
      p_monto              IN ge_cuentas.sal_promedio%TYPE
      p_tip_capitalizacion IN cr_piz_plazos.tip_capitalizacion%TYPE,
      p_tas_minima         IN OUT ge_tas_fechas.val_tasa%TYPE,
      p_tas_maxima         IN OUT ge_tas_fechas.val_tasa%TYPE,
      p_tas_interes        IN OUT ge_tas_fechas.val_tasa%TYPE,
      p_tas_efectiva       IN OUT cr_piz_plazos.tas_efectiva%TYPE
   ) IS
   v_tas_minima            ge_tas_fechas.val_tasa%TYPE;
   v_tas_maxima            ge_tas_fechas.val_tasa%TYPE;
   v_tas_interes           ge_tas_fechas.val_tasa%TYPE;
   v_tas_efectiva          cr_piz_plazos.tas_efectiva%TYPE;

   v_val_tasa              ge_tas_fechas.val_tasa%TYPE;
   BEGIN
      SELECT tas_minima, tas_maxima, tas_interes, tas_efectiva
        INTO v_tas_minima, v_tas_maxima, v_val_tasa, v_tas_efectiva
        FROM cr_piz_plazos b, cr_piz_montos a
       WHERE b.cod_moneda = p_cod_moneda
         AND b.cod_modulo = p_cod_modulo
         AND b.cod_modalidad = p_cod_modalidad
         AND p_plazo BETWEEN b.plz_desde AND b.plz_hasta
         AND p_monto BETWEEN a.mto_desde AND a.mto_hasta
         --AND nvl(b.tip_capitalizacion, nvl(p_tip_capitalizacion, 0)) = nvl(p_tip_capitalizacion, 0)
         AND a.cod_moneda = p_cod_moneda
         AND a.cod_modulo = p_cod_modulo
         AND a.cod_modalidad = p_cod_modalidad
         AND a.mto_desde = b.mto_desde;
   EXCEPTION
      WHEN no_data_found THEN
         -- se ponen los valores a cero para que no se corte la grabacion
         p_tas_minima   := 0;
         p_tas_maxima   := 0;
         p_tas_interes  := 0;
         p_tas_efectiva := 0;
      WHEN too_many_rows THEN
         --- Existe especificacion para nulos y tipo de capitalizacion
         BEGIN
            SELECT tas_minima, tas_maxima, tas_interes, tas_efectiva
              INTO v_tas_minima, v_tas_maxima, v_val_tasa, v_tas_efectiva
              FROM cr_piz_montos a, cr_piz_plazos b
             WHERE b.cod_moneda = p_cod_moneda
               AND b.cod_modulo = p_cod_modulo
               AND b.cod_modalidad = p_cod_modalidad
               AND p_plazo BETWEEN b.plz_desde AND b.plz_hasta
               AND p_monto BETWEEN a.mto_desde AND a.mto_hasta
               AND b.tip_capitalizacion IS NULL
               AND a.cod_moneda = p_cod_moneda
               AND a.cod_modulo = p_cod_modulo
               AND a.cod_modalidad = p_cod_modalidad
               AND a.mto_desde = b.mto_desde;
         EXCEPTION
            WHEN no_data_found THEN
               raise_application_error(-20000, 'Tasa de pizarra no definida ');
            WHEN too_many_rows THEN
               raise_application_error(-20000, 'Existe mas de una pizarra definida');
         END;
      WHEN OTHERS THEN
         IF SQLCODE <= -20000 THEN
            RAISE;
         ELSE
            raise_application_error(-20000, 'Obt. Tasa Pizarra ' || SQLERRM);
         END IF;
   END;*/
     -- Validacion del tipo de credito---------------------------------------------
    PROCEDURE pr_val_cod_modalidad IS
    BEGIN
      SELECT 0
        INTO v_dummy
        FROM ge_modalidades
       WHERE cod_modulo = v_cod_modulo
         AND cod_modalidad = p_cod_modalidad
         and FUP_OBT_TIP_DESCUENTO(cod_modalidad) in ('F','C','D');
    EXCEPTION
      WHEN no_data_found THEN
           g_cod_error := 6;
           g_lugar := 'Valida Modalidad';
           g_msj_error := 'Tipo de Prestamo no habilitado. Modalidad: '||p_cod_modalidad;
      WHEN OTHERS THEN
         g_cod_error := 7;
         g_lugar := 'Valida Modalidad';
         g_msj_error := 'Error al validar Modalidad ' || SQLERRM;
    END;
      -- Validacion del codigo de la moneda-----------------------------------------
    FUNCTION fu_val_cod_moneda(p_cod_moneda in varchar2) return varchar2 IS
    BEGIN
      SELECT cod_moneda
        INTO v_cod_moneda
        FROM ba_monedas
       WHERE cod_moneda = p_cod_moneda;
       return v_cod_moneda;
    EXCEPTION
      WHEN no_data_found THEN
        begin
          select cod_moneda
            into v_cod_moneda
            from ba_monedas m
           where m.cod_mon_iso = p_cod_moneda;
           return v_cod_moneda;
        exception
           when no_data_found then
              begin
                 select cod_moneda
                   into v_cod_moneda
                   from ba_monedas m
                  where m.cod_mon_bco_central = p_cod_moneda;
                  return v_cod_moneda;
              exception
                 when no_data_found then
                      g_cod_error := 8;
                      g_lugar := 'Valida Moneda';
                      g_msj_error := 'Codigo de Moneda inexistente';
             end;
         end;
         return null;
      WHEN OTHERS THEN
          g_cod_error := 9;
          g_lugar := 'Valida Moneda';
          g_msj_error := 'Error al validar moneda ' || SQLERRM;
    END;

    PROCEDURE pp_val_dias_gracia IS
      v_can_meses number := 0;
    BEGIN
       If p_fec_pri_vencimiento is not null then

          v_can_meses := trunc(MONTHS_BETWEEN(p_fec_pri_vencimiento,
                                        v_fec_actual));

           If v_can_meses < nvl(fug_obt_pardinamico('PRE_PER_GRACIA_MIN',
                                             v_cod_modulo,
                                             p_cod_modalidad,
                                             p_cod_moneda),
                         0) then
             g_cod_error := 8;
             g_lugar     := 'Valida Dias de Gracia';
             g_msj_error := 'Periodo de gracia ' || v_can_meses ||
                ' no debe ser menor a ' ||
                nvl(fug_obt_pardinamico('PRE_PER_GRACIA_MIN',
                                        v_cod_modulo,
                                             p_cod_modalidad,
                                             p_cod_moneda),
                    0);
           end if;
           If pap_sim.g_cod_error = 0 and v_can_meses > nvl(fug_obt_pardinamico('PRE_PER_GRACIA_MAX',
                                             v_cod_modulo,
                                             p_cod_modalidad,
                                             p_cod_moneda),
                         0) then
              g_cod_error := 8;
              g_lugar     := 'Valida Dias de Gracia';
              g_msj_error :='Periodo de gracia ' || v_can_meses ||
                ' no debe ser mayor a ' ||
                nvl(fug_obt_pardinamico('PRE_PER_GRACIA_MAX',
                                        v_cod_modulo,
                                             p_cod_modalidad,
                                             p_cod_moneda),
                    0);

            end if;
       end if;
     END;
    PROCEDURE PR_CAL_MTO_TOT_PRESTAMO(V_MTO_CARGO IN NUMBER,
                                      V_TTVALOR  IN NUMBER,
                                      P_TOT_PRESTAMO OUT NUMBER) IS
     V_PORCENTAJE_AJUSTE NUMBER;
     v_redondeo number(2) := 0;
    BEGIN
       --- Veo el tipo de redondeo de los calculos ------------------------------------------
       v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', v_cod_modulo, p_cod_modalidad, v_cod_moneda, p_cod_oficina);

    IF P_TIP_MONTO = 'B' THEN
       --- tipo de monto es bruto ---------------------------------------------------------
       v_TOT_PRESTAMO := P_MONTO;
    ELSE
       --- monto ingresado es el neto -----------------------------------------------------
       V_PORCENTAJE_AJUSTE := (P_MONTO - (V_MTO_CARGO - V_TTVALOR)) * 100 /
                               (P_MONTO + v_TTVALOR);
       --- calculo del nuevo capital (monto bruto -----------------------------------------
       v_TOT_PRESTAMO := ROUND((P_MONTO * 100 / V_PORCENTAJE_AJUSTE),v_redondeo);
       ------------------------------------------------------------------------------------
       ------DESDE AQUI
      /* IF P_TIP_MONTO = 'N' AND v_TOT_PRESTAMO <> P_MONTO THEN
         --- Realizo el ajuste --------
         IF NVL(v_TOT_PRESTAMO,0)-NVL(V_MTO_CARGO,0) <> P_MONTO THEN
            -- es necesario un ajuste en la ultima cuota      ---
            GO_BLOCK('PR_SOL_CUOTAS');
            LAST_RECORD;
            LOOP
              WW_PORCENTAJE_AJUSTE := :PR_SOLICITUDES.MONTO - (NVL(:TOT_PRESTAMO,0)-NVL(:MTO_CARGO,0));
             -- IF get_block_property('PR_SOL_CUOTAS',STATUS) <> 'CHANGED' THEN
                 :PR_SOL_CUOTAS.MTO_CAPITAL := :PR_SOL_CUOTAS.MTO_CAPITAL + WW_PORCENTAJE_AJUSTE;
                 :PR_SOL_CUOTAS.SC_CAPIDOC := :PR_SOL_CUOTAS.SC_CAPIDOC + WW_PORCENTAJE_AJUSTE;

                 :tmp.monto                        := :PR_SOL_CUOTAS.SC_CAPIDOC + NVL(:PR_SOL_CUOTAS.VAL_INT_ADELANTADO,0);
                 :SC_VLTOTAL                       := :tmp.monto;

            --  END IF;
              :SC_TTCUOTA := NVL(:MTO_CAPITAL,0)+NVL(:PR_SOL_CUOTAS.VAL_INTERES,0)+nvl(:pr_sol_cuotas.val_int_adelantado,0);
              :TOT_PRESTAMO := round(:TOT_PRESTAMO + WW_PORCENTAJE_AJUSTE,ww_redondeo);
              EXIT WHEN :SYSTEM.LAST_RECORD = 'TRUE';
              NEXT_RECORD;
            END LOOP;
            FIRST_RECORD;
         END IF;
         :SC_VLGARAN := :MTO_APLICADO;
         IF NVL(:PR_SOLICITUDES.TIP_INTERES,'V') = 'V' THEN
            :PR_SOLICITUDES.SC_A_DESEMB := NVL(:TOT_PRESTAMO,0) - NVL(:MTO_CARGO,0);
         ELSE
            :PR_SOLICITUDES.SC_A_DESEMB := NVL(:TOT_PRESTAMO,0) - NVL(:MTO_CARGO,0);
         END IF;
       END IF;  */
       ------HASTA AQUI
    END IF;
    P_TOT_PRESTAMO:= v_TOT_PRESTAMO;
END;


    FUNCTION FP_OBT_TASA(P_TASA IN varchar2) RETURN VARCHAR2 IS
    V_RETORNO VARCHAR2(1):= 'N';
    BEGIN
       SELECT 'S'
         INTO v_retorno
         FROM ge_tasas
        WHERE cod_tasa = (replace(p_tasa,',','.'));
        RETURN v_retorno;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
         RETURN 'N';
      WHEN OTHERS THEN
         RETURN 'N';
    END;

    function FU_OBT_NOM_SEGURO(p_transaccion in varchar2,
                                p_cod_ente in varchar2)RETURN VARCHAR2 IS
    v_tipo VARCHAR2(3);
    v_nom_seguro ge_entes.descripcion%type;
    BEGIN
        IF p_transaccion IN (701,735) THEN
           -- cargos de escribania ---
           v_tipo := 'ES';
        ELSE
           --- cargos de seguros -----
           v_tipo := 'SE';
        END IF;
        SELECT SUBSTR(DESCRIPCION,1,20)
          INTO v_nom_seguro
         FROM GE_ENTES
        WHERE COD_ENTE = p_cod_ente
          AND TIPO     = v_tipo;

          RETURN v_nom_seguro;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        IF v_tipo = 'SE' THEN
           g_cod_error := 7;
           g_lugar := 'Valida Seguro definido';
           g_msj_error := 'No se encuentra el Seguro.';
        ELSE
           g_cod_error := 8;
           g_lugar := 'Valida Escribania definido';
           g_msj_error := 'Escribania no existe.';
        END IF;
      WHEN OTHERS THEN
         g_cod_error := 9;
           g_lugar := 'Valida Seguro/Escribania';
           g_msj_error := 'ERROR: FU_OBT_NOM_SEGURO ' || SQLERRM;
    END;
     -- Carga de cargos de la propuesta-------------------------------------------
    function fu_obt_cargos return typ_listadescargo IS
      CURSOR cargos IS
        SELECT DISTINCT decode(a.cod_transaccion,
                               709,
                               1,
                               710,
                               2,
                               a.cod_transaccion) orden, -- solo para ordenamiento
                        a.cod_transaccion,
                        fug_obt_des_transaccion(a.cod_modulo,a.cod_modalidad,a.cod_transaccion)des_transaccion,
                        a.cod_ent_seguro,
                        nvl(b.obligatorio, 'N') obligator
          FROM ge_sol_cargos a, ge_transacciones_det b
         WHERE a.cod_transaccion = b.cod_tra_hijo(+)
           AND a.cod_modulo = b.cod_mod_hijo(+)
           AND a.cod_modalidad = b.cod_mad_hijo(+)
           AND a.cod_modulo = v_cod_modulo
           AND a.cod_modalidad = p_cod_modalidad
           --and a.cod_transaccion not in(736)
           AND ((nvl(v_exo_impuestos, 'N') = 'N') OR
               (nvl(v_exo_impuestos, 'N') = 'S' AND
               nvl(b.obligatorio, 'N') = 'N'))
         ORDER BY 1;

      detalleCargos typ_descargo := typ_descargo;
      listaCargos typ_listadescargo := typ_listadesCargo();
      v_retorno typ_listadescargo := typ_listadescargo();
      v_can_cargos number(10);

  BEGIN
    v_can_cargos:= 0;
      FOR cc IN cargos LOOP
           detalleCargos.COD_TRANSACCION:= cc.cod_transaccion;
           detalleCargos.DES_TRANSACCION:= cc.des_transaccion;
           detalleCargos.COD_ENT_SEGURO := cc.cod_ent_seguro;

           IF detalleCargos.COD_TRANSACCION IN (701,702,735,736,737) THEN
             --- es un seguro -------------------
             IF detalleCargos.COD_ENT_SEGURO IS NULL THEN
                  g_cod_error := 10;
                  g_lugar := 'Valida Seguro/Escribania';
                  g_msj_error := 'Definir el Codigo del Seguro / Escribania(Cargos).';
             END IF;
          END IF;
          if pap_sim.g_cod_error ='000' then
          /* pr_obt_tipo_de_tasa(cc.cod_transaccion IN NUMBER,
                               v_des_transaccion IN OUT VARCHAR2,
                               ww_cddetas IN OUT NUMBER,
                               ww_aplicar IN OUT VARCHAR2,
                               ww_tpvlpor IN OUT VARCHAR2,
                               ww_tpdetas IN OUT VARCHAR2)*/

           if detalleCargos.COD_TRANSACCION IN (701,702,735,736,737) THEN
              detalleCargos.NOM_SEGURO := FU_OBT_NOM_SEGURO(detalleCargos.COD_TRANSACCION,detalleCargos.COD_ENT_SEGURO);
           end if;
           listacargos.extend;
           v_can_cargos := v_can_cargos + 1;
           listacargos(listaCargos.count):= detalleCargos;
           else
             exit;
           end if;
      end loop;

      v_retorno := listacargos;

    RETURN v_retorno;
  END;

  FUNCTION fu_carCuotas(p_can_documento  in number,
                        p_cheques in typ_cheques)return typ_descuotas IS

      detallecuota typ_descuota := typ_descuota;
      listaCuotas typ_listadescuota := typ_listadesCuota();
      v_detalleCheque typ_cheques:= p_cheques;
      v_retorno typ_descuotas := typ_descuotas;

      v_cdtrans   number(10) := 607;
      v_nrcuota   number(10) := 0;
      v_cdreten   number(10);
      v_can_cuotas  number(10);
      v_fec_deposito date;
      v_fec_vto_che_anterior date;
      v_dias number(5) := fug_obt_pardinamico('DIA_DES_CHEQUES', 6, p_cod_modalidad, p_cod_moneda, p_cod_oficina);
   begin
    for i in 1.. v_detalleCheque.listacheques.Count loop
      --Valida datos de cheques ingresadosp_cod_oficina
       pap_sim.pr_val_cheques(v_detalleCheque.listacheques(i).NRO_CHEQUE,
                              v_detalleCheque.listacheques(i).MONTO,
                              v_detalleCheque.listacheques(i).FEC_EMISION,
                              v_detalleCheque.listacheques(i).FEC_VENCIMIENTO,
                              v_dias);
      if pap_sim.g_cod_error = 0 then
          v_nrcuota   := v_nrcuota + 1;
        --cargar la cuota
        detallecuota.NRO_CUOTA := v_nrcuota;
        --Ver si se puede usar paquetes de la BD o debe ser totalmente independiente
           pag_cta.pr_obt_retencion (v_detalleCheque.listacheques(i).FEC_VENCIMIENTO, -- Fecha de la transaccion
                                             null,          -- Numero de cuenta
                                             6,             -- Modulo de la transaccion
                                             p_cod_modalidad,             -- Modalidad de la transaccion
                                             v_cdtrans,     -- Transaccion
                                             v_cod_moneda,    -- Moneda
                                             v_cdreten,     -- Codigo de retencion
                                             v_fec_deposito);

        if nvl(v_vto_hab_cheques,'N') = 'S' then
           detallecuota.FEC_VTO_HABIL := pag_cal.fu_obt_fec_habil(v_fec_deposito,1,p_cod_oficina);
        else
           detallecuota.FEC_VTO_HABIL := v_fec_deposito;
        end if;
        detallecuota.MTO_CAPITAL := v_detalleCheque.listacheques(i).MONTO;
        detallecuota.VAL_INT_ORIGINAL := v_detalleCheque.listacheques(i).MONTO;
        detallecuota.COD_BANCO        := v_detalleCheque.listacheques(i).COD_BANCO;
        detallecuota.NRO_CHEQUE       := v_detalleCheque.listacheques(i).NRO_CHEQUE;
        detallecuota.CTA_LIBRADORA    := v_detalleCheque.listacheques(i).CTA_LIBRADORA;
        detallecuota.FEC_EMISION      := v_detalleCheque.listacheques(i).FEC_EMISION;
        detallecuota.FEC_DEPOSITO     := v_fec_deposito;

          if detallecuota.NRO_CUOTA  = 1 then
            V_FEC_PRI_VENCIMIENTO := detallecuota.FEC_VTO_HABIL ;
          else
            if detallecuota.FEC_VTO_HABIL < v_FEC_VENCIMIENTO then
              V_FEC_PRI_VENCIMIENTO := detallecuota.FEC_VTO_HABIL;
            end if;
          end if;

              -- Controla los dias del primer vencimiento...
         IF nvl(pap_sim.g_cod_error,0) = 0 and (V_FEC_PRI_VENCIMIENTO - v_fec_actual) > v_can_dia_pri_vcto THEN
            g_cod_error := 8;
            g_lugar     := 'Valida Primer vencimiento';
            g_msj_error := 'Primer Vencimiento no debe ser posterior a los '||v_can_dia_pri_vcto||' dias.';
         END IF;

          if detallecuota.FEC_VTO_HABIL < v_fec_vto_che_anterior then
              g_cod_error := 1;
              g_lugar     := 'Valida vencimiento del cheque';
              g_msj_error := 'Las fechas de Vencimientos deben estar ordenadas por Cuotas ';
          end if;
         v_fec_vto_che_anterior := detallecuota.FEC_VTO_HABIL;

         listacuotas.extend;
         listacuotas(listaCuotas.count):= detallecuota;
      else
         exit;
       end if;
       if nvl(v_FEC_VENCIMIENTO,p_fec_inicio) < detallecuota.FEC_VTO_HABIL then
          v_FEC_VENCIMIENTO := detallecuota.FEC_VTO_HABIL;
       end if;
    end loop;

    v_retorno.listadescuotas := listaCuotas;
    --v_FEC_VENCIMIENTO := detallecuota.FEC_VTO_HABIL;
    v_dia_plazo := v_FEC_VENCIMIENTO - v_fec_inicio;
    RETURN v_retorno;
  END;


      -- Procedimiento para obtener el tipo de tasa --------------------------------
    PROCEDURE pr_obt_tipo_de_tasa(ww_cdtrans IN NUMBER,
                                  ww_destran OUT VARCHAR2,
                                  ww_cddetas IN OUT NUMBER,
                                  ww_aplicar IN OUT VARCHAR2,
                                  ww_tpvlpor IN OUT VARCHAR2,
                                  ww_tpdetas IN OUT VARCHAR2) IS
    BEGIN
      v_lugar := 'OBTENER TIPO DE TASA ';
      --- 1. Busco la tasa asociada a la transaccion ingresada ---
      SELECT initcap(TR.DESCRIPCION), tr.cod_tasa, ta.aplicar, ta.tip_valor, ta.tipo
        INTO ww_destran,ww_cddetas, ww_aplicar, ww_tpvlpor, ww_tpdetas
        FROM ge_transacciones tr, ge_tasas ta
       WHERE tr.cod_modulo = v_cod_modulo
         AND tr.cod_modalidad = p_cod_modalidad
         AND tr.cod_transaccion = ww_cdtrans
         AND tr.tipo = 'D'
         AND tr.cod_tasa IS NOT NULL
         AND tr.cod_tasa = ta.cod_tasa
         AND EXISTS (SELECT 0
                FROM ge_transacciones_det
               WHERE cod_modulo = v_cod_modulo
                 AND cod_modalidad = p_cod_modalidad
                 AND cod_transaccion = 358 /* transaccion de desembolso de prestamos */
                 AND cod_mod_hijo = tr.cod_modulo
                 AND cod_mad_hijo = tr.cod_modalidad
                 AND cod_tra_hijo = tr.cod_transaccion);

    EXCEPTION
      WHEN no_data_found THEN
         g_cod_error := 11;
         g_lugar := 'Valida Cargos';
         g_msj_error := 'Cargo no definido para Prestamos. '||ww_cdtrans;
      WHEN OTHERS THEN
         g_cod_error := 12;
         g_lugar := 'Valida Cargos';
         g_msj_error := 'ERROR: OBT_TIPO_TASA ' || SQLERRM;
    END;

    -- Funcion que obtiene el valor de la tasa fija ------------------------------
    FUNCTION fu_obt_valor_de_tasa_fija(ww_cddetas IN NUMBER,
                                       ww_fcinici IN DATE) RETURN NUMBER IS
      ww_vldetas NUMBER(15, 2);
    BEGIN
      v_lugar := 'OBTENER VALOR DE TASA FIJA ';
      -- tasa fija, buscar en tasa por fecha ---
      SELECT val_tasa
        INTO ww_vldetas
        FROM ge_tas_fechas f1
       WHERE f1.cod_tasa = ww_cddetas
         AND (f1.cod_modalidad IS NULL OR
             (f1.cod_modalidad = p_cod_modalidad))
         AND (f1.cod_modulo IS NULL OR (f1.cod_modulo = v_cod_modulo))
         AND (f1.cod_moneda IS NULL OR (f1.cod_moneda = v_cod_moneda))
         AND (f1.cod_oficina IS NULL OR (f1.cod_oficina = v_cod_oficina))
         AND f1.nro_cuenta IS NULL
         AND f1.fec_vigencia =
             (SELECT MAX(fec_vigencia)
                FROM ge_tas_fechas f2
               WHERE f1.cod_tasa = f2.cod_tasa
                 AND (f2.cod_modalidad IS NULL OR
                     (f2.cod_modalidad = p_cod_modalidad))
                 AND (f2.cod_modulo IS NULL OR
                     (f2.cod_modulo = v_cod_modulo))
                 AND (f2.cod_moneda IS NULL OR
                     (f2.cod_moneda = v_cod_moneda))
                 AND (f2.cod_oficina IS NULL OR
                     (f2.cod_oficina = v_cod_oficina))
                 AND f2.fec_vigencia <= ww_fcinici
                 AND f2.nro_cuenta IS NULL);
      RETURN ww_vldetas;
    EXCEPTION
      WHEN no_data_found THEN
        RETURN NULL;
      WHEN OTHERS THEN
         g_cod_error := 12;
         g_lugar := 'Valida Cargos';
         g_msj_error := 'ERROR: OBT_TASA_FIJA ' || SQLERRM;
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
           AND (tr.cod_modalidad = p_cod_modalidad OR
               tr.cod_modalidad IS NULL)
           AND (tr.cod_moneda = v_cod_moneda OR tr.cod_moneda IS NULL)
           AND (tr.cod_oficina = v_cod_oficina OR tr.cod_oficina IS NULL)
           AND tr.val_hasta >= ww_vlmonto
           AND tr.nro_cuenta IS NULL
           AND tr.fec_vigencia =
               (SELECT MAX(tra.fec_vigencia)
                  FROM ge_tas_rangos tra
                 WHERE tra.cod_tasa = ww_cddetas
                   AND (tra.cod_modulo = v_cod_modulo OR
                       tra.cod_modulo IS NULL)
                   AND (tra.cod_modalidad = p_cod_modalidad OR
                       tra.cod_modalidad IS NULL)
                   AND (tra.cod_moneda = v_cod_moneda OR
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
          g_cod_error := 12;
          g_lugar := 'Valida Cargos';
          g_msj_error := 'No existe Valor para la Tasa ' ||
                                to_char(ww_cddetas) || ' y el Monto ' ||
                                to_char(ww_vlmonto) || ' Fecha ' ||
                                to_char(ww_fcinici, 'DD/MM/YYYY');
      END IF;
      RETURN ww_vldetas;
    EXCEPTION
      WHEN no_data_found THEN
        RETURN NULL;
      WHEN OTHERS THEN
        IF SQLCODE <= -20000 THEN
          RAISE;
        ELSE
          raise_application_error(-20000, 'obt_tasa_variable ' || SQLERRM);
        END IF;
    END;

     -- Verificacion del codigo de tasa--------------------------------------------
    PROCEDURE pr_obt_datos_cargo(p_cargos IN OUT typ_listadescargo ) IS
    --declare
    v_cancargos NUMBER:= p_cargos.count;
    detalleCargos typ_descargo := typ_descargo;
    listaCargos typ_listadescargo := typ_listadesCargo();
    v_retorno typ_listadescargo := typ_listadescargo();
    v_can_cargos number(10) := 0;
    v_mto_mon_prestamo number(18,4);
    v_cotizac          number(18,2);

    BEGIN
    for x in 1 .. v_cancargos loop
       v_val_cargo:= 0;
       v_cod_mon_cargo:= 0;
      -- obtengo los datos de la tasa-----------------
      pr_obt_tipo_de_tasa(p_cargos(x).cod_transaccion ,
                          v_des_transaccion,
                          v_cod_tas_cargo,
                          v_aplicar,
                          v_tpvlpor,
                          v_tpdetas);

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
                                                                 p_monto),
                                                             v_fec_inicio);
          END IF;

          IF FP_OBT_TASA(v_val_tas_cargo)= 'S' AND v_tpvlpor NOT IN('P','V') THEN
            IF v_aplicar IN ('CP', 'IP', 'TP') THEN
            -- aplicar al capital y plazo, busco ahora el valor por plazo
               v_val_tas_cargo := fu_obt_valor_de_tasa_variable(v_val_tas_cargo,
                                                             v_dia_plazo,
                                                             v_fec_inicio);
            ELSE
                v_val_tas_cargo := fu_obt_valor_de_tasa_variable(v_val_tas_cargo,
                                                             nvl(v_tot_prestamo,
                                                                 p_monto),
                                                             v_fec_inicio);
            END IF;
          END IF;

        ELSE
          v_val_tas_cargo := fu_obt_valor_de_tasa_variable(v_cod_tas_cargo,
                                                           nvl(v_tot_prestamo,
                                                               p_monto),
                                                           v_fec_inicio);
        END IF;

      END IF;
      IF v_tpvlpor IN ('I', 'P') THEN
        --- porcentajes  o transacciones de seguros  ---
        v_cod_mon_cargo := v_mon_local;

         if v_tpvlpor = 'I' then
            v_cod_mon_cargo := v_mon_local;
         else
            v_cod_mon_cargo := v_cod_moneda;
         end if;
      ELSE

         IF v_val_tas_cargo IS NOT NULL THEN
            v_cod_mon_cargo := v_cod_moneda;
            v_val_cargo := v_val_tas_cargo;
         END IF;
          /* solo si es valor */
         IF v_cod_mon_cargo = v_cod_moneda THEN
            -- moneda del cargo es igual a la moneda de la simulacion ----------------------
            v_mto_mon_prestamo := v_val_cargo;
         ELSE
            IF v_cod_moneda = v_mon_local THEN
               v_cotizac := null;
            END IF;
          -- monedas diferentes, se divide por la cotiz. de la moneda de la simulacion ---
           v_mto_mon_prestamo := pag_gen.fu_con_mon_a_moneda(v_cod_mon_cargo,
                                                        v_cod_moneda,
                                                        v_val_cargo,
                                                        V_COTIZAC);
         END IF;
         v_val_tas_cargo:= NULL;
      END IF;
      IF v_cod_mon_cargo IS NULL THEN
         v_cod_mon_cargo := V_cod_moneda;
      END IF;

       detalleCargos.COD_TRANSACCION:= p_cargos(x).cod_transaccion;
       detalleCargos.DES_TRANSACCION:= p_cargos(x).des_transaccion;
       detalleCargos.COD_ENT_SEGURO := p_cargos(x).cod_ent_seguro;
       detalleCargos.NOM_SEGURO := p_cargos(x).NOM_SEGURO;
       detalleCargos.val_tasa:= v_val_tas_cargo;
       detalleCargos.COD_MONEDA := v_cod_mon_cargo;
       detalleCargos.MONTO      := v_val_cargo;
       detalleCargos.MTO_MON_PRESTAMO := v_mto_mon_prestamo;
       detalleCargos.COD_TASA         :=v_cod_tas_cargo;
       detalleCargos.FEC_TASA         := null;


       listacargos.extend;
       v_can_cargos := v_can_cargos + 1;
       listacargos(listaCargos.count):= detalleCargos;
      end loop;
      --v_retorno := listacargos;
       p_cargos := listacargos;
    END;

    -- Calculo de los cargos ----------------------------------------------------
    PROCEDURE pr_cal_cargos(p_tot_prestamo  in number,
                            p_mto_interes in number,
                            p_desembolsar out number,
                            p_tot_cargo out number,
                            p_ttvalor  out number,
                            p_cargos in out typ_listadescargo) IS

      ww_dfcargos       NUMBER(18, 2);
      v_mto_equivalente NUMBER(18, 2);
      v_cod_tra_ajuste  NUMBER(4);
      v_monto           NUMBER(18, 2);
      v_can_cargos      number(10) := p_cargos.count;
      --V_DIA_PLAZO      NUMBER(18);
      v_ttvalor        NUMBER(18, 2);
      v_mto_cargo      NUMBER(18, 2);
      v_mto_mon_prestamo  NUMBER(18, 2);
      v_des_transaccion  VARCHAR2(120);
      v_dfcargos         NUMBER(18, 2);
      V_A_DESEMB          NUMBER(18, 2);
      detalleCargos typ_descargo := typ_descargo;
      listaCargos typ_listadescargo := typ_listadesCargo();
      v_retorno typ_listadescargo := typ_listadescargo();

    BEGIN
      --- Calculo cada uno de los cargos en la moneda del cargo y en la de la simulacion ---
      --- cero los totales de cargo de tipo valor y el total general de cargos -------------
      v_ttvalor        := 0;
      v_mto_cargo      := 0;
      v_cod_tra_ajuste := NULL;
      --V_DIA_PLAZO := v_fec_vencimiento - v_fec_actual;
      FOR cc IN 1 .. v_can_cargos LOOP
        v_mto_mon_prestamo := 0;

        -- obtengo los datos de la tasa-----------------
        pr_obt_tipo_de_tasa(p_cargos(cc).cod_transaccion,
                            v_des_transaccion,
                            p_cargos(cc).cod_tasa,
                            v_aplicar,
                            v_tpvlpor,
                            v_tpdetas);

        IF v_tpvlpor = 'P' THEN
          v_mto_mon_prestamo := 0;
          --- la tasa es un porcentaje-----------------------------------------------------
          IF v_aplicar IN ('CI', 'IN', 'PI', 'IP', 'PT', 'TP') THEN
            --- aplicable al interes -----------------------------------------------------

             if p_cargos(cc).cod_transaccion in(736,737) then
                ---v_tas_seguro := cc.val_tasa;
                v_mto_mon_prestamo := round(v_mto_tot_seguro,v_redondeo);
             else
                v_mto_mon_prestamo := round(v_mto_interes * p_cargos(cc).val_tasa / 100,
                                       v_redondeo);
             end if;



          END IF;
          IF v_aplicar IN ('CA', 'CI', 'PC', 'CP', 'PT', 'TP') THEN
             IF NVL(fug_obt_pardinamico('PRE_CAR_SEG_CAPITAL', v_cod_modulo, p_cod_modalidad, null), 'N') = 'S'
                AND NVL(fug_obt_pardinamico('PRE_MAD_CHE_COM', v_cod_modulo, p_cod_modalidad, null), 'N') = 'N' THEN
                if p_cargos(cc).cod_transaccion in(736,737) then
                ---v_tas_seguro := cc.val_tasa;
                   v_mto_mon_prestamo := round(v_mto_tot_seguro,v_redondeo);
                else
                   v_mto_mon_prestamo := ROUND(((p_monto  * p_cargos(cc).VAL_TASA * v_DIA_PLAZO) / 30)/1000,v_redondeo);
                end if;
             ELSIF v_aplicar = 'CA' AND NVL(fug_obt_pardinamico('PRE_MAD_CHE_COM', v_cod_modulo, p_cod_modalidad, null), 'N') = 'S' THEN
                 if p_cargos(cc).cod_transaccion in(736,737) then
                ---v_tas_seguro := cc.val_tasa;
                    v_mto_mon_prestamo := round(v_mto_tot_seguro,v_redondeo);
                 else
                    v_mto_mon_prestamo := ROUND(((p_monto * p_cargos(cc).VAL_TASA) / 100) ,v_redondeo);
                 end if;
             ELSE
                if p_cargos(cc).cod_transaccion in(736,737) then
                ---v_tas_seguro := cc.val_tasa;
                   v_mto_mon_prestamo := round(v_mto_tot_seguro,v_redondeo);
                else
                   v_mto_mon_prestamo := NVL(v_mto_mon_prestamo,0) +
                             ROUND(p_tot_prestamo * p_cargos(cc).VAL_TASA / 100,v_redondeo);
                end if;
             END IF;
           END IF;

           IF v_aplicar = 'MO' then
             --v_imp_cargo := 0;
              v_mto_mon_prestamo :=   NVL(v_mto_mon_prestamo,0) + ROUND(p_monto * p_cargos(cc).VAL_TASA/ 100,v_redondeo);
               --v_mto_mon_prestamo := v_imp_cargo + ROUND(p_cargos(cc).VAL_TASA * 10/100,v_redondeo);
           END IF;

            IF p_cargos(cc).COD_MONEDA = V_COD_MONEDA THEN
               -- moneda del cargo es igual a la moneda de la simulacion ----------------------
              V_MONTO := v_mto_mon_prestamo;
            ELSE
               -- monedas diferentes, se divide por la cotiz. de la moneda de la simulacion ---
              V_MONTO := ROUND(v_mto_mon_prestamo * v_cotizacion,v_redondeo);
            END IF;

        ELSIF v_tpvlpor = 'I' THEN
          v_mto_mon_prestamo := 0;
          --- la tasa es un impuesto ------------------------------------------------------
          IF v_aplicar IN ('CI','IN','PI','IP','PT','TP') THEN
            --- aplicable al interes -----------------------------------------------------
            IF v_dia_plazo < 365 THEN
              v_mto_mon_prestamo := round(v_mto_interes * v_dia_plazo *
                                         p_cargos(cc).val_tasa / 36500,
                                         v_redondeo);
            ELSE
              v_mto_mon_prestamo := round(v_mto_interes * p_cargos(cc).val_tasa / 100,
                                         v_redondeo);
            END IF;
          END IF;
          IF v_aplicar IN ('CA','CI','PC','CP','PT','TP') THEN
            --- es aplicable al capital --------------------------------------------------
            IF p_cargos(cc).cod_ent_seguro IS NOT NULL THEN
              --- es un seguro ----------------------------------------------------------

              IF nvl(fug_obt_pardinamico('PRE_CAR_SEG_CAPITAL'), 'N') = 'S' THEN
                 v_mto_mon_prestamo := ROUND(((P_MONTO  * p_cargos(cc).val_tasa * v_dia_plazo) / 30)/1000,v_redondeo);
               ELSE
                 v_mto_mon_prestamo := NVL(v_mto_mon_prestamo,0) +
                             ROUND(p_tot_prestamo * p_cargos(cc).val_tasa/ 100,v_redondeo);
              END IF;
            ELSE
              --- es un impuesto sobre el capital ---------------------------------------
              IF v_dia_plazo < 365 THEN
                v_mto_mon_prestamo := nvl(v_mto_mon_prestamo, 0) +
                                     round(p_tot_prestamo * v_dia_plazo *
                                           p_cargos(cc).val_tasa / 36500,
                                           v_redondeo);
              ELSE
                v_mto_mon_prestamo := nvl(v_mto_mon_prestamo, 0) +
                                     round(p_tot_prestamo * p_cargos(cc).val_tasa / 100,
                                           v_redondeo);
              END IF;
            END IF;
          END IF;

           IF v_aplicar = 'MO' then
             --v_imp_cargo := 0;
              v_mto_mon_prestamo :=   NVL(v_mto_mon_prestamo,0) + ROUND(p_monto * p_cargos(cc).VAL_TASA/ 100,v_redondeo);
               --v_mto_mon_prestamo := v_imp_cargo + ROUND(p_cargos(cc).VAL_TASA * 10/100,v_redondeo);
           END IF;

          IF p_cargos(cc).COD_MONEDA = V_COD_MONEDA THEN
               -- moneda del cargo es igual a la moneda de la simulacion ----------------------
              V_MONTO := v_mto_mon_prestamo;
          ELSE
               -- monedas diferentes, se divide por la cotiz. de la moneda de la simulacion ---
              V_MONTO := ROUND(v_mto_mon_prestamo * v_cotizacion,v_redondeo);
          END IF;
        ELSIF v_tpvlpor = 'V' THEN
          --- es un monto valor -----------------------------------------------------------

          v_ttvalor         := nvl(v_ttvalor, 0) +
                               nvl(p_cargos(cc).mto_mon_prestamo, 0);
          v_mto_mon_prestamo:= p_cargos(cc).mto_mon_prestamo;
          v_monto:= p_cargos(cc).mto_mon_prestamo;
          v_car_tipvalor := nvl(v_monto,0);
        END IF;

       detalleCargos.COD_TRANSACCION:= p_cargos(cc).cod_transaccion;
       detalleCargos.DES_TRANSACCION:= p_cargos(cc).des_transaccion;
       detalleCargos.COD_ENT_SEGURO := p_cargos(cc).cod_ent_seguro;
       detalleCargos.NOM_SEGURO     := p_cargos(cc).NOM_SEGURO;

       detalleCargos.val_tasa       := p_cargos(cc).val_tasa;
       detalleCargos.COD_MONEDA     := p_cargos(cc).cod_moneda;
       detalleCargos.COD_TASA       :=p_cargos(cc).cod_tasa;
       detalleCargos.FEC_TASA       := p_cargos(cc).fec_tasa;
       detalleCargos.MONTO          := V_MONTO;
       detalleCargos.MTO_MON_PRESTAMO := v_mto_mon_prestamo;
       listacargos.extend;
       v_can_cargos := v_can_cargos + 1;
       listacargos(listaCargos.count):= detalleCargos;

        --- Acumular el total de cargos (Si el tipo es Valor viene directamente aqui -------
        v_mto_cargo := nvl(v_mto_cargo, 0) + nvl(v_mto_mon_prestamo, 0);
        ------------------------------------------------------------------------------------
      END LOOP;

       -- := listacargos;
      IF v_mto_cargo >= p_tot_prestamo THEN
        raise_application_error(-20000,
                                'ERROR. Total de Cargos ' || v_mto_cargo ||
                                ' es superior al Total del Prestamo ' ||
                                v_tot_prestamo);
      ELSE
        /*IF p_tip_monto = 'N' AND p_tot_prestamo <> p_monto THEN
          --- ya estoy en el ultimo calculo de cargos netos, veo si hay ajuste --------
          IF nvl(p_tot_prestamo, 0) - nvl(v_mto_cargo, 0) <>
             p_monto THEN
            -- es necesario un ajuste en el cargo del impuesto o primer cargo      ---
            v_dfcargos       := p_monto - (nvl(p_tot_prestamo, 0) -
                                 nvl(v_mto_cargo, 0));
            v_mto_mon_prestamo := NVL(v_mto_mon_prestamo,0) - v_dfcargos;

            v_mto_cargo       := nvl(v_mto_cargo, 0) - v_dfcargos;
          END IF;
        END IF;*/
         V_A_DESEMB := NVL(p_tot_prestamo,0) - NVL(v_mto_cargo,0);
         IF V_TIP_INTERES = 'A' THEN /* interes adelantado */
           V_A_DESEMB := NVL(V_A_DESEMB,0) - NVL(V_MTO_INTERES,0);
         END IF;
          p_cargos := listacargos;
          p_ttvalor:= v_ttvalor;
          p_desembolsar := V_A_DESEMB;
          p_tot_cargo  := v_mto_cargo;
      END IF;


    EXCEPTION
      WHEN OTHERS THEN
        raise_application_error(-20000, 'CALCULAR_CARGOS ' || SQLERRM);
    END;
    --Procedimiento para calcular el cargo por cuota DA-886
    PROCEDURE pr_cal_car_cuo(p_tot_cuota in number,
                             p_int_cuota in number,
                             p_cargos    in typ_listadescargo,
                             p_can_cuota in number,
                             p_car_cuota out number) IS

      v_monto           NUMBER(18, 2);
      v_can_cargos      number(10) := p_cargos.count;
      v_ttvalor         NUMBER(18, 2);
      v_mto_cargo       NUMBER(18, 2);
      v_mon_car_uni     NUMBER(18, 2);
      v_des_transaccion VARCHAR2(120);
      V_A_DESEMB        NUMBER(18, 2);
      detalleCargos     typ_descargo := typ_descargo;
      listaCargos       typ_listadescargo := typ_listadesCargo();
      v_retorno         typ_listadescargo := typ_listadescargo();
      v_cod_tasa        ge_tasas.cod_tasa%type;
      v_mto_interes     NUMBER(18, 2) := p_int_cuota;
    BEGIN
      --- Calculo cada uno de los cargos en la moneda del cargo y en la de la simulacion ---
      --- cero los totales de cargo de tipo valor y el total general de cargos -------------
      v_ttvalor   := 0;
      v_mto_cargo := 0;
      FOR cc IN 1 .. v_can_cargos LOOP
        --monto de cargo de la cuota (valor por cargo)
        v_mon_car_uni := 0;

        -- obtengo los datos de la tasa-----------------
        pr_obt_tipo_de_tasa(p_cargos(cc).cod_transaccion,
                            v_des_transaccion,
                            v_cod_tasa,
                            v_aplicar,
                            v_tpvlpor,
                            v_tpdetas);

        IF v_tpvlpor = 'P' THEN
          v_mon_car_uni := 0;
          --- la tasa es un porcentaje-----------------------------------------------------
          IF v_aplicar IN ('CI', 'IN', 'PI', 'IP', 'PT', 'TP') THEN
            --- aplicable al interes -----------------------------------------------------

            if p_cargos(cc).cod_transaccion not in (736, 737) then
              v_mon_car_uni := round(v_mto_interes * p_cargos(cc).val_tasa / 100,
                                     v_redondeo);
            end if;

          END IF;
          IF v_aplicar IN ('CA', 'CI', 'PC', 'CP', 'PT', 'TP') THEN
            IF NVL(fug_obt_pardinamico('PRE_CAR_SEG_CAPITAL',
                                       v_cod_modulo,
                                       p_cod_modalidad,
                                       null),
                   'N') = 'S' AND NVL(fug_obt_pardinamico('PRE_MAD_CHE_COM',
                                                          v_cod_modulo,
                                                          p_cod_modalidad,
                                                          null),
                                      'N') = 'N' THEN
              if p_cargos(cc).cod_transaccion not in (736, 737) then
                v_mon_car_uni := ROUND(((p_tot_cuota * p_cargos(cc).VAL_TASA *
                                       v_DIA_PLAZO) / 30) / 1000,
                                       v_redondeo);
              end if;
            ELSIF v_aplicar = 'CA' AND NVL(fug_obt_pardinamico('PRE_MAD_CHE_COM',
                                                               v_cod_modulo,
                                                               p_cod_modalidad,
                                                               null),
                                           'N') = 'S' THEN
              if p_cargos(cc).cod_transaccion not in (736, 737) then
                v_mon_car_uni := ROUND(((p_tot_cuota * p_cargos(cc).VAL_TASA) / 100),
                                       v_redondeo);
              end if;
            ELSE
              if p_cargos(cc).cod_transaccion not in (736, 737) then
                v_mon_car_uni := NVL(v_mon_car_uni, 0) +
                                 ROUND(p_tot_cuota * p_cargos(cc).VAL_TASA / 100,
                                       v_redondeo);
              end if;
            END IF;
          END IF;

          IF v_aplicar = 'MO' then
            v_mon_car_uni := NVL(v_mon_car_uni, 0) +
                             ROUND(p_tot_cuota * p_cargos(cc).VAL_TASA / 100,
                                   v_redondeo);
          END IF;

          IF p_cargos(cc).COD_MONEDA = V_COD_MONEDA THEN
            -- moneda del cargo es igual a la moneda de la simulacion ----------------------
            V_MONTO := v_mon_car_uni;
          ELSE
            -- monedas diferentes, se divide por la cotiz. de la moneda de la simulacion ---
            V_MONTO := ROUND(v_mon_car_uni * v_cotizacion, v_redondeo);
          END IF;

        ELSIF v_tpvlpor = 'I' THEN
          v_mon_car_uni := 0;
          --- la tasa es un impuesto ------------------------------------------------------
          IF v_aplicar IN ('CI', 'IN', 'PI', 'IP', 'PT', 'TP') THEN
            --- aplicable al interes -----------------------------------------------------
            IF v_dia_plazo < 365 THEN
              v_mon_car_uni := round(v_mto_interes * v_dia_plazo * p_cargos(cc).val_tasa /
                                     36500,
                                     v_redondeo);
            ELSE
              v_mon_car_uni := round(v_mto_interes * p_cargos(cc).val_tasa / 100,
                                     v_redondeo);
            END IF;
          END IF;
          IF v_aplicar IN ('CA', 'CI', 'PC', 'CP', 'PT', 'TP') THEN
            --- es aplicable al capital --------------------------------------------------
            IF p_cargos(cc).cod_ent_seguro IS NOT NULL THEN
              --- es un seguro ----------------------------------------------------------

              IF nvl(fug_obt_pardinamico('PRE_CAR_SEG_CAPITAL'), 'N') = 'S' THEN
                v_mon_car_uni := ROUND(((P_tot_cuota * p_cargos(cc).val_tasa *
                                       v_dia_plazo) / 30) / 1000,
                                       v_redondeo);
              ELSE
                v_mon_car_uni := NVL(v_mon_car_uni, 0) +
                                 ROUND(p_tot_cuota * p_cargos(cc).val_tasa / 100,
                                       v_redondeo);
              END IF;
            ELSE
              --- es un impuesto sobre el capital ---------------------------------------
              IF v_dia_plazo < 365 THEN
                v_mon_car_uni := nvl(v_mon_car_uni, 0) +
                                 round(p_tot_cuota * v_dia_plazo * p_cargos(cc).val_tasa /
                                       36500,
                                       v_redondeo);
              ELSE
                v_mon_car_uni := nvl(v_mon_car_uni, 0) +
                                 round(p_tot_cuota * p_cargos(cc).val_tasa / 100,
                                       v_redondeo);
              END IF;
            END IF;
          END IF;

          IF v_aplicar = 'MO' then
            --v_imp_cargo := 0;
            v_mon_car_uni := NVL(v_mon_car_uni, 0) +
                             ROUND(p_tot_cuota * p_cargos(cc).VAL_TASA / 100,
                                   v_redondeo);
            --v_mto_mon_prestamo := v_imp_cargo + ROUND(p_cargos(cc).VAL_TASA * 10/100,v_redondeo);
          END IF;

          IF p_cargos(cc).COD_MONEDA = V_COD_MONEDA THEN
            -- moneda del cargo es igual a la moneda de la simulacion ----------------------
            V_MONTO := v_mon_car_uni;
          ELSE
            -- monedas diferentes, se divide por la cotiz. de la moneda de la simulacion ---
            V_MONTO := ROUND(v_mon_car_uni * v_cotizacion, v_redondeo);
          END IF;
        ELSIF v_tpvlpor = 'V' THEN --si es del tipo V, no afecta por cuota
          --- es un monto valor -----------------------------------------------------------
          v_ttvalor     := nvl(v_ttvalor, 0) / p_can_cuota;
          v_mon_car_uni := 0;--p_cargos(cc).mto_mon_prestamo;--p_tot_cuota;
          v_monto       := v_mon_car_uni;
        END IF;

        listacargos.extend;
        v_can_cargos := v_can_cargos + 1;
        listacargos(listaCargos.count) := detalleCargos;

        --- Acumular el total de cargos (Si el tipo es Valor viene directamente aqui -------
        v_mto_cargo := nvl(v_mto_cargo, 0) + nvl(v_mon_car_uni, 0);
        ------------------------------------------------------------------------------------
      END LOOP;

      IF v_mto_cargo >= p_tot_cuota THEN
        raise_application_error(-20000,
                                'ERROR. Cargo ' || v_mto_cargo ||
                                ' es superior a la cuota ' || p_tot_cuota);
      ELSE
        p_car_cuota := v_mto_cargo;
      END IF;

    EXCEPTION
      WHEN OTHERS THEN
        raise_application_error(-20000, 'PR_CAL_CAR_CUO ' || SQLERRM);
    END;


   --GENERAR CUOTAS---
    FUNCTION fu_gen_cuotas(WW_NETO IN VARCHAR2,
                            p_val_tasa IN NUMBER,
                            p_tot_prestamo IN NUMBER,
                            p_can_cuotas IN NUMBER,
                            p_DIA_PLAZO  IN NUMBER,
                            p_NRO_SOLICITUD IN NUMBER,
                            p_FEC_INICIO    IN DATE,
                            p_FEC_PRI_VENCIMIENTO IN DATE,
                            p_TIP_INTERES IN VARCHAR2,
                            p_MTO_CAPITAL IN NUMBER,
                            p_cuotas IN typ_descuotas) RETURN typ_listadescuota IS

      WW_DIAVENC VARCHAR2(02);
      WW_FRANCES NUMBER;
      WW_TASADIV NUMBER := p_val_tasa / 36500;
      WW_VLSALAN NUMBER(18,2) := p_tot_prestamo;
      WW_TTCUOTA NUMBER(18,2) := NULL;
      WW_DFCUOTA NUMBER(18);
      WW_TTCAPIT NUMBER(18) := 0;
      WW_TTREFUE NUMBER(18) := 0;
      WW_REFREAL NUMBER(18) := 0;
      WW_CTREFUE NUMBER(6)  := 0;
      WW_NRO     NUMBER(6)  := 0;
      WW_VECES   NUMBER(3)  := 0;
      ww_sgtvenc  DATE       := p_FEC_PRI_VENCIMIENTO;
      ww_existe  varchar2(01) := 'N';
      ww_diasplz NUMBER(9);
      v_SC_CTCUOTA number(10):= p_can_cuotas;

      v_PER_VTO_CAPITAL number(20);
      V_FEC_VTO_HABIL   date;
      V_VAL_INT_ORIGINAL number(20);
      V_MTO_CAPITAL      number(20);
      V_FEC_VTO_EXACTO   date;
      V_DIA_PERIODO      number(10);
      V_SAL_CAP_ANTERIOR  number(20);
      V_VAL_INTERES       number(20);
      V_VAL_INT_ADELANTADO number(20);
      V_SC_TTCUOTA         number(20);
      V_SC_CAPIDOC         number(20);
      v_detalle                 typ_descuota := typ_descuota;
      v_detalleCuota typ_descuotas:= p_cuotas;
      v_retorno            typ_listadescuota := typ_listadescuota();
      v_listacuotas typ_listadescuota := typ_listadescuota();
      v_tot_mto_cheque number(18,2):= 0;
      v_fec_vto_anterior date;
      v_mto_cheques    number(18,2) := 0;
      v_tas_seguro     number(18,2);
      v_mto_seguro        number(18,2) := 0;

      V_NRO_CUOTA   number(10);
      V_DIA_INTERES number(10);
      v_detcuotas typ_descuota;
      v_can  NUMBER(3) :=  0;
      v_val_tasa number(20,4);
      v_fec_vigencia date;
      v_tip_valor varchar2(10);
      v_tipo      varchar2(10);
      v_cod_tasa  number(10);
      v_dias      number(18,2):=0;
BEGIN


--- genero las cuotas del sistema --------------------------------------
v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', v_cod_modulo, p_cod_modalidad, v_cod_moneda, p_cod_oficina);

ww_diavenc  := TO_CHAR(p_fec_pri_vencimiento,'DD');
v_PER_VTO_CAPITAL := TRUNC((V_FEC_VENCIMIENTO - P_FEC_INICIO));
v_mto_tot_seguro := 0;
v_mto_seguro:=0;

IF p_TIP_INTERES = 'A' THEN /* interes adelantado */
 --CREAR PROCESO DE VERIFICACION pr_ver_dat_cuotas;
  v_MTO_INTERES := 0;
  ww_vlsalan  := P_TOT_PRESTAMO;
  v_mto_cheques  := 0;
  ww_ttcapit  := 0;
  ww_refreal  := 0;
  v_mto_tot_seguro := 0;
  v_mto_seguro:=0;
  v_fec_vto_anterior:= null;
  ww_nro      := 0;  /* acumulador de cuotas calculadas automaticamente, sin refuerzo */
  ww_diasplz  := ceil(P_DIA_PLAZO / v_SC_CTCUOTA);
  ww_ttcuota  := round(p_TOT_PRESTAMO / v_SC_CTCUOTA, v_redondeo);

    v_fec_vto_anterior := P_FEC_INICIO;


    pag_gen.pr_obt_val_tasa(v_cod_modulo, p_cod_modalidad,
                          null, null, v_cod_moneda,
                          null, 'N', v_cod_tasa, 709, --Transaccion
                          trunc(sysdate), v_val_tasa, v_fec_vigencia, v_tip_valor, v_tipo);

  FOR CUOTA IN 1..v_SC_CTCUOTA LOOP
    v_detalle := typ_descuota();
        --  Se recalculan los intereses
        -- v_detalle.NRO_SOLICITUD      := p_NRO_SOLICITUD;
         v_detalle.NRO_CUOTA          := CUOTA;
         v_detalle.FEC_VTO_HABIL      := v_detalleCuota.listadescuotas(cuota).FEC_VTO_HABIL;
         v_detalle.FEC_VTO_EXACTO     := v_detalleCuota.listadescuotas(cuota).FEC_VTO_HABIL;
         v_detalle.DIA_PERIODO        := v_detalleCuota.listadescuotas(cuota).FEC_VTO_HABIL - p_FEC_INICIO;
         v_detalle.DIA_INTERES        := v_detalle.DIA_PERIODO;
         v_detalle.SAL_CAP_ANTERIOR   := ww_vlsalan;
         v_detalle.VAL_INT_ORIGINAL   := v_detalleCuota.listadescuotas(cuota).VAL_INT_ORIGINAL;
         v_detalle.MTO_CAPITAL        := NVL(v_detalleCuota.listadescuotas(cuota).VAL_INT_ORIGINAL,0);

         --if pag_gen.fu_obt_cod_entidad = '9999' then
        --    v_detalle.VAL_INT_ADELANTADO := Round(((v_detalle.MTO_CAPITAL * (p_val_tasa)*v_detalle.DIA_PERIODO)/3000), v_redondeo);
        -- else
            v_detalle.VAL_INT_ADELANTADO := Round(v_detalleCuota.listadescuotas(cuota).VAL_INT_ORIGINAL * ww_tasadiv * v_detalle.DIA_PERIODO, v_redondeo);
         --end if;
          v_detalle.VAL_CUOTA         := NVL( v_detalle.VAL_INT_ORIGINAL,0);

        --Calculo de impuesto del interes
          v_detalle.MTO_IVA_INTERES := round(nvl( v_detalle.VAL_INT_ADELANTADO,0) * (v_val_tasa / 100), v_redondeo);

        --Calculo de seguro

        if v_cod_Tas_seguro > 0 then
          if to_char(v_detalle.FEC_VTO_HABIL,'MM') <> to_char(v_fec_vto_anterior,'MM') or v_detalle.NRO_CUOTA = 1 then
             v_tot_mto_cheque := v_detalle.SAL_CAP_ANTERIOR;
          else
             v_tot_mto_cheque := 0;
          end if;

          v_dias := months_between(to_date(01||'/'||to_char(v_detalle.FEC_VTO_HABIL,'MM/YYYY'),'DD/MM/YYYY'),to_date(01||'/'||to_char(v_fec_vto_anterior,'MM/YYYY'),'DD/MM/YYYY'));
          --round(months_between(v_detalle.FEC_VTO_HABIL,v_fec_vto_anterior),'MM');
          v_detalle.MTO_SEGURO := round((v_tot_mto_cheque *v_val_tas_seguro/1000)*v_dias, v_redondeo);
        ---v_detalle.MTO_SEGURO := round((v_tot_mto_cheque * v_val_tas_seguro/1000)/power((1+v_val_tas_tpm/36500),v_detalle.DIA_PERIODO), v_redondeo);
        --v_detalle.MTO_IVA_SEGURO:= round(v_detalle.MTO_SEGURO * v_tas_impositiva/100,v_redondeo);

        v_mto_seguro:= v_detalle.MTO_SEGURO;--+ v_detalle.MTO_IVA_SEGURO;
        v_mto_tot_seguro := nvl(v_mto_tot_seguro,0) + nvl(v_mto_seguro,0);

        v_fec_vto_anterior := v_detalle.FEC_VTO_HABIL;

        v_detalle.FEC_SEGURO := last_day(v_detalle.FEC_VTO_HABIL);
        end if;
        --Fin calculo de seguro

         ww_vlsalan                        := NVL(ww_vlsalan,0) - v_detalleCuota.listadescuotas(cuota).MTO_CAPITAL;
         ww_sgtvenc                        := v_detalleCuota.listadescuotas(cuota).FEC_VTO_HABIL + ww_diasplz;
         v_MTO_INTERES                     := nvl(v_MTO_INTERES,0) + NVL(v_detalle.VAL_INT_ADELANTADO,0);
         v_detalle.COD_BANCO               := v_detalleCuota.listadescuotas(cuota).cod_banco;
         v_detalle.NRO_CHEQUE              := v_detalleCuota.listadescuotas(cuota).nro_cheque;
         v_detalle.CTA_LIBRADORA           := v_detalleCuota.listadescuotas(cuota).cta_libradora;
         v_detalle.COD_MONEDA              := v_detalleCuota.listadescuotas(cuota).cod_moneda;
         v_detalle.FEC_EMISION             := v_detalleCuota.listadescuotas(cuota).fec_emision;

         v_mto_cheques                     := v_mto_cheques + v_detalle.MTO_CAPITAL;

         v_listacuotas.extend;
         v_listacuotas(v_listacuotas.count):= v_detalle;

      IF NVL(v_detalle.VAL_INT_ORIGINAL,0) = 0 THEN
         ww_existe := 'S'; /* indica que existen cuotas con cero */
      END IF;
  END LOOP;
  v_detalle.VAL_INT_ORIGINAL := NVL(v_detalle.VAL_INT_ORIGINAL,0) + ww_vlsalan;
  v_detalle.MTO_CAPITAL      := NVL(v_detalle.VAL_INT_ORIGINAL,0);
  v_detalle.VAL_CUOTA        := NVL(v_detalle.VAL_INT_ORIGINAL,0);

 ELSE
 ww_tasadiv := ww_tasadiv * 30;
 LOOP
  ww_veces := NVL(ww_veces,0)  + 1;
  --- calculo del valor del metodo frances -----------------------------
  ww_frances := ((NVL(P_TOT_PRESTAMO,0)-NVL(ww_ttrefue,0))* ww_tasadiv) /
                (power((1 + ww_tasadiv),(v_sc_ctcuota-ww_ctrefue)) - 1);
  ----------------------------------------------------------------------
  v_MTO_INTERES := 0;
  ww_vlsalan  := P_TOT_PRESTAMO;
  ww_ttcapit  := 0;
  ww_refreal  := 0;
  v_mto_seguro := 0;
  v_mto_tot_seguro := 0;
  ww_nro      := 0;  /* acumulador de cuotas calculadas automaticamente, sin refuerzo */

  FOR CUOTA IN 1..v_SC_CTCUOTA LOOP
       -- detalleCuotas.NRO_SOLICITUD    := p_NRO_SOLICITUD;
      v_detalle := typ_Descuota;

      v_detalle.NRO_CUOTA        := cuota;
      v_detalle.FEC_VTO_HABIL    := ADD_MONTHS(p_FEC_PRI_VENCIMIENTO, cuota -1);
      v_detalle.FEC_VTO_EXACTO   := P_FEC_PRI_VENCIMIENTO + ((cuota -1) * 30);
      v_detalle.DIA_PERIODO      := 30;
      v_detalle.DIA_INTERES      := 30;
      v_detalle.SAL_CAP_ANTERIOR := ww_vlsalan;
      v_detalle.VAL_INTERES := CEIL(ww_vlsalan * ww_tasadiv);
        IF v_detalle.VAL_INT_ORIGINAL > 0 THEN  /* es una cuota con refuerzo */
           IF ww_neto = 'S' THEN
              v_detalle.MTO_CAPITAL := v_detalle.MTO_CAPITAL;
           ELSE
              v_detalle.MTO_CAPITAL := v_detalle.VAL_INT_ORIGINAL - v_detalle.VAL_INTERES;
           END IF;
           ww_refreal := NVL(ww_refreal,0) + NVL(p_MTO_CAPITAL,0);
        ELSE
           ww_nro := ww_nro + 1;
           v_detalle.MTO_CAPITAL   := ROUND(ww_frances * power((1 + ww_tasadiv), (ww_nro - 1)), v_redondeo);
        END IF;
        v_detalle.VAL_INT_ORIGINAL := NVL(v_detalle.VAL_INT_ORIGINAL,0);
        v_detalle.VAL_CUOTA        := NVL(v_detalle.MTO_CAPITAL,0) + NVL(v_detalle.VAL_INTERES,0);
        ww_dfcuota                 :=  NVL(ww_ttcuota,v_detalle.VAL_CUOTA) - NVL(v_detalle.VAL_CUOTA,0);
        IF ABS(ww_dfcuota) BETWEEN 1 AND 5 THEN
           v_detalle.VAL_INTERES   := v_detalle.VAL_INTERES + ww_dfcuota;
           v_detalle.VAL_CUOTA     := v_detalle.VAL_CUOTA + ww_dfcuota;
        END IF;
        ww_ttcuota                  := v_detalle.VAL_CUOTA;
        ww_vlsalan                  := NVL(ww_vlsalan,0) - v_detalle.MTO_CAPITAL;
        ww_ttcapit                  := NVL(ww_ttcapit,0) + NVL(v_detalle.MTO_CAPITAL,0);
        v_MTO_INTERES               := v_MTO_INTERES + NVL(v_detalle.VAL_INTERES,0);

        v_listacuotas.extend;
        v_listacuotas(v_listacuotas.count) := v_detalle;
  END LOOP;

  IF ABS(NVL(ww_refreal,0) - NVL(ww_ttrefue,0)) < 10 OR ww_veces > 12 OR ww_neto = 'S' THEN
     EXIT;
  END IF;

 END LOOP;
 ww_dfcuota := p_TOT_PRESTAMO - ww_ttcapit;
 IF ww_dfcuota <> 0 THEN
    v_detalle.MTO_CAPITAL  := v_detalle.MTO_CAPITAL + ww_dfcuota;
    v_detalle.VAL_INTERES  := v_detalle.VAL_INTERES - ww_dfcuota;
    v_MTO_INTERES := v_MTO_INTERES - ww_dfcuota;
 END IF;

END IF;

 --v_retorno.listadescuotas := v_listacuotas;
   v_retorno:= v_listacuotas;
 RETURN v_retorno;


----------------------------------------------------------------
IF p_TIP_INTERES = 'A' AND ww_existe = 'S' THEN
   raise_application_error(-20000,'Existen cuotas con valor 0(cero). Verifique!!!');
END IF;
EXCEPTION
  WHEN OTHERS THEN
      raise_application_error(-20000,'Error al generar cuotas!'||sqlerrm);
END;
   --FIN GENERACION CUOTAS BRUTO

--GENERAR CUOTAS NETO---
    FUNCTION fu_gen_cuotas_neto(WW_NETO IN VARCHAR2,
                            p_val_tasa IN NUMBER,
                            p_tot_prestamo IN NUMBER,
                            p_can_cuotas IN NUMBER,
                            p_DIA_PLAZO  IN NUMBER,
                            p_NRO_SOLICITUD IN NUMBER,
                            p_FEC_INICIO    IN DATE,
                            p_FEC_PRI_VENCIMIENTO IN DATE,
                            p_TIP_INTERES IN VARCHAR2,
                            p_MTO_CAPITAL IN NUMBER,
                            P_MTO_CARGO  IN NUMBER,
                            p_cargo  in typ_listadescargo,
                            p_cuotas IN typ_descuotas,
                            p_cheques in typ_cheques,
                            p_tot_che_futuro in out Number) RETURN typ_listadescuota IS

      WW_DIAVENC VARCHAR2(02);
      WW_FRANCES NUMBER;
      WW_TASADIV NUMBER := p_val_tasa / 36500;
      WW_VLSALAN NUMBER(18,2) := v_tot_prestamo;
      WW_TTCUOTA NUMBER(18,2) := NULL;
      v_mto_cargo  NUMBER(18,2) := NULL;
      WW_DFCUOTA NUMBER(18);
      WW_TTCAPIT NUMBER(18) := 0;
      WW_TTREFUE NUMBER(18) := 0;
      WW_REFREAL NUMBER(18) := 0;
      WW_CTREFUE NUMBER(6)  := 0;
      WW_NRO     NUMBER(6)  := 0;
      WW_VECES   NUMBER(3)  := 0;
      ww_sgtvenc  DATE       := p_FEC_PRI_VENCIMIENTO;
      ww_existe  varchar2(01) := 'N';
      ww_diasplz NUMBER(9);
      v_SC_CTCUOTA number(10):= p_can_cuotas;

      v_PER_VTO_CAPITAL number(20);
      V_FEC_VTO_HABIL   date;
      V_VAL_INT_ORIGINAL number(20);
      V_MTO_CAPITAL      number(20);
      V_FEC_VTO_EXACTO   date;
      V_DIA_PERIODO      number(10);
      V_SAL_CAP_ANTERIOR  number(20);
      V_VAL_INTERES       number(20);
      V_VAL_INT_ADELANTADO number(20);
      V_SC_TTCUOTA         number(20);
      V_SC_CAPIDOC         number(20);
      v_detalle                 typ_descuota := typ_descuota;
      v_detalleCuota typ_descuotas:= p_cuotas;
      v_det_cheque typ_cheques := p_cheques;
      v_retorno            typ_listadescuota := typ_listadescuota();
      v_listacuotas typ_listadescuota := typ_listadescuota();
      v_tot_mto_cheque number(18,2):= 0;
      v_fec_vto_anterior date;
      v_mto_cheques    number(18,2) := 0;
      v_tas_seguro     number(18,2);
      v_mto_seguro     number(18,2) := 0;
      v_val_futuro     number(18,2) := 0;
      v_val_fut_che    number(18,2) := 0;

      V_NRO_CUOTA   number(10);
      V_DIA_INTERES number(10);
      v_detcuotas typ_descuota;
      v_can  NUMBER(3) :=  0;
      v_val_tasa number(20,4);
      v_fec_vigencia date;
      v_tip_valor varchar2(10);
      v_tipo      varchar2(10);
      v_cod_tasa  number(10);
      v_dias      number(18,2):=0;
      --Variables para el calculo de Seguro DA-886
      v_mto_car_cuota number(18,2):=0;
      v_tot_che_futuro number(18,2):=0;
      v_sal_che_futuro number(18,2):=0;
BEGIN


--- genero las cuotas del sistema --------------------------------------
v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', v_cod_modulo, p_cod_modalidad, v_cod_moneda, p_cod_oficina);

ww_diavenc  := TO_CHAR(p_fec_pri_vencimiento,'DD');
v_PER_VTO_CAPITAL := TRUNC((V_FEC_VENCIMIENTO - P_FEC_INICIO));
v_mto_tot_seguro := 0;
v_mto_seguro:=0;

IF P_TIP_INTERES = 'A' THEN /* interes adelantado */
 --CREAR PROCESO DE VERIFICACION pr_ver_dat_cuotas;
  v_MTO_INTERES := 0;
  ww_vlsalan  := v_tot_prestamo;
  v_mto_cheques  := 0;
  ww_ttcapit  := 0;
  ww_refreal  := 0;
  v_mto_tot_seguro := 0;
  v_mto_seguro:=0;
  v_fec_vto_anterior:= null;
  ww_nro      := 0;  /* acumulador de cuotas calculadas automaticamente, sin refuerzo */
  ww_diasplz  := ceil(P_DIA_PLAZO / v_SC_CTCUOTA);
  ww_ttcuota  := round(v_tot_prestamo / v_SC_CTCUOTA, v_redondeo);
  v_mto_cargo := round(P_MTO_CARGO / v_SC_CTCUOTA, v_redondeo);

  v_sal_che_futuro := p_tot_che_futuro;
  v_fec_vto_anterior := P_FEC_INICIO;


    pag_gen.pr_obt_val_tasa(v_cod_modulo, p_cod_modalidad,
                          null, null, v_cod_moneda,
                          null, 'N', v_cod_tasa, 709, --Transaccion
                          trunc(sysdate), v_val_tasa, v_fec_vigencia, v_tip_valor, v_tipo);

  FOR CUOTA IN 1..v_SC_CTCUOTA LOOP
    v_detalle := typ_descuota();
        --  Se recalculan los intereses
        -- v_detalle.NRO_SOLICITUD      := p_NRO_SOLICITUD;
         v_detalle.NRO_CUOTA          := CUOTA;
         v_detalle.FEC_VTO_HABIL      := v_detalleCuota.listadescuotas(cuota).FEC_VTO_HABIL;
         v_detalle.FEC_VTO_EXACTO     := v_detalleCuota.listadescuotas(cuota).FEC_VTO_HABIL;
         v_detalle.DIA_PERIODO        := v_detalleCuota.listadescuotas(cuota).FEC_VTO_HABIL - p_FEC_INICIO;
         v_detalle.DIA_INTERES        := v_detalle.DIA_PERIODO;
         v_detalle.SAL_CAP_ANTERIOR   := ww_vlsalan;
         v_val_fut_che := 0;
         v_detalle.VAL_INT_ORIGINAL   := v_detalleCuota.listadescuotas(cuota).VAL_INT_ORIGINAL;
         --v_detalle.MTO_CAPITAL        := NVL(v_detalleCuota.listadescuotas(cuota).VAL_INT_ORIGINAL,0);

         --if pag_gen.fu_obt_cod_entidad = '9999' then
        --    v_detalle.VAL_INT_ADELANTADO := Round(((v_detalle.MTO_CAPITAL * (p_val_tasa)*v_detalle.DIA_PERIODO)/3000), v_redondeo);
        -- else
          v_val_futuro := round( v_detalle.VAL_INT_ORIGINAL *(1+ ww_tasadiv*NVL(v_detalle.DIA_PERIODO,0)) , v_redondeo);

          v_detalle.VAL_INT_ADELANTADO := Round(v_val_futuro * ww_tasadiv * v_detalle.DIA_PERIODO, v_redondeo);
         --end if;
         if v_tot_prestamo <> P_MONTO then
            v_detalle.MTO_CAPITAL        := NVL(v_detalleCuota.listadescuotas(cuota).VAL_INT_ORIGINAL,0) + v_mto_cargo;
            v_detalle.VAL_CUOTA         := NVL( v_detalle.VAL_INT_ORIGINAL,0)+ v_mto_cargo + v_detalle.VAL_INT_ADELANTADO ;
         else
            v_detalle.MTO_CAPITAL        := NVL(v_detalleCuota.listadescuotas(cuota).VAL_INT_ORIGINAL,0);
            v_detalle.VAL_CUOTA         := NVL( v_detalle.VAL_INT_ORIGINAL,0) + v_detalle.VAL_INT_ADELANTADO;
         end if;

        --Calculo de impuesto del interes
          v_detalle.MTO_IVA_INTERES := round(nvl( v_detalle.VAL_INT_ADELANTADO,0) * (v_val_tasa / 100), v_redondeo);

           if v_detalle.NRO_CUOTA = 1 then --solo para a primera cuota
             if to_char(v_detalle.FEC_VTO_HABIL,'MM') = to_char(v_fec_vto_anterior,'MM') then
               if v_SC_CTCUOTA = 1 then /*si tiene una sola cuota y el documento *
                                        vence el mismo mes de inicio NO se calcula seguro*/
                 v_dias := 0;
               else
                 v_dias := months_between(to_date(01||'/'||to_char(v_det_cheque.listacheques(cuota+1).FEC_VENCIMIENTO,'MM/YYYY'),'DD/MM/YYYY'),to_date(01||'/'||to_char(v_det_cheque.listacheques(cuota).FEC_VENCIMIENTO,'MM/YYYY'),'DD/MM/YYYY'));
               end if;
             else
                v_dias := months_between(to_date(01||'/'||to_char(v_detalle.FEC_VTO_HABIL,'MM/YYYY'),'DD/MM/YYYY'),to_date(01||'/'||to_char(p_fec_inicio,'MM/YYYY'),'DD/MM/YYYY'));
             end if;
          else

            if to_char(v_detalle.FEC_VTO_HABIL,'MM') = to_char(v_fec_vto_anterior,'MM') and v_fec_vto_anterior = P_FEC_INICIO then
              v_dias := to_date(v_detalle.FEC_VTO_HABIL,'DD/MM/YYYY') - to_date(v_fec_vto_anterior,'DD/MM/YYYY') ;
            else
              if to_char(v_det_cheque.listacheques(1).FEC_VENCIMIENTO,'MM') = to_char(P_FEC_INICIO,'MM') and
                v_detalle.nro_cuota <> v_SC_CTCUOTA then
                v_dias := months_between(to_date(01||'/'||to_char(v_det_cheque.listacheques(cuota+1).FEC_VENCIMIENTO,'MM/YYYY'),'DD/MM/YYYY'),to_date(01||'/'||to_char(v_det_cheque.listacheques(cuota).FEC_VENCIMIENTO,'MM/YYYY'),'DD/MM/YYYY'));
              else
                v_dias := months_between(to_date(01||'/'||to_char(v_detalle.FEC_VTO_HABIL,'MM/YYYY'),'DD/MM/YYYY'),to_date(01||'/'||to_char(v_fec_vto_anterior,'MM/YYYY'),'DD/MM/YYYY'));
              end if;
           end if;
          end if;


         v_fec_vto_anterior                := v_detalle.FEC_VTO_HABIL;
         ww_vlsalan                        := NVL(ww_vlsalan,0) - v_detalleCuota.listadescuotas(cuota).MTO_CAPITAL;
         ww_sgtvenc                        := v_detalleCuota.listadescuotas(cuota).FEC_VTO_HABIL + ww_diasplz;
         v_MTO_INTERES                     := nvl(v_MTO_INTERES,0) + NVL(v_detalle.VAL_INT_ADELANTADO,0);
         v_detalle.COD_BANCO               := v_detalleCuota.listadescuotas(cuota).cod_banco;
         v_detalle.NRO_CHEQUE              := v_detalleCuota.listadescuotas(cuota).nro_cheque;
         v_detalle.CTA_LIBRADORA           := v_detalleCuota.listadescuotas(cuota).cta_libradora;
         v_detalle.COD_MONEDA              := v_detalleCuota.listadescuotas(cuota).cod_moneda;
         v_detalle.FEC_EMISION             := v_detalleCuota.listadescuotas(cuota).fec_emision;
         v_mto_cheques                     := v_mto_cheques + v_detalle.MTO_CAPITAL;

         --Calculo de seguro DA-886
         --1 Obtener cargo por cuota DA-886
         pr_cal_car_cuo(v_detalle.MTO_CAPITAL, v_detalle.VAL_INT_ADELANTADO, p_cargo, v_SC_CTCUOTA,v_mto_car_cuota);
        --Valor futuro del cheque Capital + Interes + cargos
         v_val_fut_che := nvl(v_val_fut_che, 0) + v_detalle.VAL_CUOTA + v_mto_car_cuota;
         v_detalle.val_cuota := nvl(v_val_fut_che,0);
         v_detalle.MTO_CAPITAL := nvl(v_val_fut_che,0) - nvl(v_detalle.VAL_INT_ADELANTADO,0);

         if nvl(p_tot_che_futuro,0) = 0 then --solo entra en una llamada para que no se dupliquen valores
            v_tot_che_futuro := v_tot_che_futuro + v_val_fut_che;
         else --si no es cero es porque ya tiene el valor acumulado
           if cuota = 1 and to_char(v_det_cheque.listacheques(cuota).FEC_VENCIMIENTO,'MM') = to_char(P_FEC_INICIO,'MM') then
             v_sal_che_futuro := v_sal_che_futuro - v_val_fut_che;
           elsif to_char(v_det_cheque.listacheques(1).FEC_VENCIMIENTO,'MM') = to_char(P_FEC_INICIO,'MM') then
             v_sal_che_futuro := v_sal_che_futuro - v_val_fut_che;
           end if;
           --si no es la ultima cuota o si tiene una sola cuota
            v_detalle.MTO_SEGURO := round((v_sal_che_futuro * v_val_tas_seguro/1000)*v_dias, v_redondeo);
            v_mto_tot_seguro := nvl(v_mto_tot_seguro,0) + nvl(v_detalle.MTO_SEGURO,0);
            v_detalle.FEC_SEGURO := last_day(v_detalle.FEC_VTO_HABIL);
            v_detalle.val_cuota := v_detalle.val_cuota +  v_detalle.MTO_SEGURO ;
            v_detalle.MTO_CAPITAL := v_detalle.MTO_CAPITAL + v_detalle.MTO_SEGURO ;
            if to_char(v_det_cheque.listacheques(1).FEC_VENCIMIENTO,'MM') != to_char(P_FEC_INICIO,'MM') then
               v_sal_che_futuro := v_sal_che_futuro - v_val_fut_che;
            end if;
            if cuota = v_SC_CTCUOTA then
              v_detalle.val_cuota := v_detalle.val_cuota +  nvl(v_car_tipvalor,0);
              v_detalle.MTO_CAPITAL := v_detalle.MTO_CAPITAL + nvl(v_car_tipvalor,0);
            end if;

         end if;
         --fin calculo de seguro DA-886

         v_listacuotas.extend;
         v_listacuotas(v_listacuotas.count):= v_detalle;

      IF NVL(v_detalle.VAL_INT_ORIGINAL,0) = 0 THEN
         ww_existe := 'S'; /* indica que existen cuotas con cero */
      END IF;
  END LOOP;
  p_tot_che_futuro := v_tot_che_futuro;
  v_detalle.VAL_INT_ORIGINAL := NVL(v_detalle.VAL_INT_ORIGINAL,0) + ww_vlsalan;
  if v_tot_prestamo <> P_MONTO then
     v_detalle.MTO_CAPITAL      := NVL(v_detalle.VAL_INT_ORIGINAL,0)+ v_mto_cargo;
     v_detalle.VAL_CUOTA        := NVL(v_detalle.VAL_INT_ORIGINAL,0)+ v_mto_cargo + v_detalle.VAL_INT_ADELANTADO ;
  else
     v_detalle.MTO_CAPITAL      := NVL(v_detalle.VAL_INT_ORIGINAL,0);
     v_detalle.VAL_CUOTA        := NVL(v_detalle.VAL_INT_ORIGINAL,0)+ v_detalle.VAL_INT_ADELANTADO;
  end if;
 ELSE
 ww_tasadiv := ww_tasadiv * 30;
 LOOP
  ww_veces := NVL(ww_veces,0)  + 1;
  --- calculo del valor del metodo frances -----------------------------
  ww_frances := ((NVL(P_TOT_PRESTAMO,0)-NVL(ww_ttrefue,0))* ww_tasadiv) /
                (power((1 + ww_tasadiv),(v_sc_ctcuota-ww_ctrefue)) - 1);
  ----------------------------------------------------------------------
  v_MTO_INTERES := 0;
  ww_vlsalan  := P_TOT_PRESTAMO;
  ww_ttcapit  := 0;
  ww_refreal  := 0;
  v_mto_seguro := 0;
  v_mto_tot_seguro := 0;
  ww_nro      := 0;  /* acumulador de cuotas calculadas automaticamente, sin refuerzo */

  FOR CUOTA IN 1..v_SC_CTCUOTA LOOP
       -- detalleCuotas.NRO_SOLICITUD    := p_NRO_SOLICITUD;
      v_detalle := typ_Descuota;

      v_detalle.NRO_CUOTA        := cuota;
      v_detalle.FEC_VTO_HABIL    := ADD_MONTHS(p_FEC_PRI_VENCIMIENTO, cuota -1);
      v_detalle.FEC_VTO_EXACTO   := P_FEC_PRI_VENCIMIENTO + ((cuota -1) * 30);
      v_detalle.DIA_PERIODO      := 30;
      v_detalle.DIA_INTERES      := 30;
      v_detalle.SAL_CAP_ANTERIOR := ww_vlsalan;
      v_detalle.VAL_INTERES := CEIL(ww_vlsalan * ww_tasadiv);
        IF v_detalle.VAL_INT_ORIGINAL > 0 THEN  /* es una cuota con refuerzo */
           IF ww_neto = 'S' THEN
              v_detalle.MTO_CAPITAL := v_detalle.MTO_CAPITAL;
           ELSE
              v_detalle.MTO_CAPITAL := v_detalle.VAL_INT_ORIGINAL - v_detalle.VAL_INTERES;
           END IF;
           ww_refreal := NVL(ww_refreal,0) + NVL(p_MTO_CAPITAL,0);
        ELSE
           ww_nro := ww_nro + 1;
           v_detalle.MTO_CAPITAL   := ROUND(ww_frances * power((1 + ww_tasadiv), (ww_nro - 1)), v_redondeo);
        END IF;
        v_detalle.VAL_INT_ORIGINAL := NVL(v_detalle.VAL_INT_ORIGINAL,0);
        v_detalle.VAL_CUOTA        := NVL(v_detalle.MTO_CAPITAL,0) + NVL(v_detalle.VAL_INTERES,0);
        ww_dfcuota                 :=  NVL(ww_ttcuota,v_detalle.VAL_CUOTA) - NVL(v_detalle.VAL_CUOTA,0);
        IF ABS(ww_dfcuota) BETWEEN 1 AND 5 THEN
           v_detalle.VAL_INTERES   := v_detalle.VAL_INTERES + ww_dfcuota;
           v_detalle.VAL_CUOTA     := v_detalle.VAL_CUOTA + ww_dfcuota;
        END IF;
        ww_ttcuota                  := v_detalle.VAL_CUOTA;
        ww_vlsalan                  := NVL(ww_vlsalan,0) - v_detalle.MTO_CAPITAL;
        ww_ttcapit                  := NVL(ww_ttcapit,0) + NVL(v_detalle.MTO_CAPITAL,0);
        v_MTO_INTERES               := v_MTO_INTERES + NVL(v_detalle.VAL_INTERES,0);


        v_listacuotas.extend;
        v_listacuotas(v_listacuotas.count) := v_detalle;
  END LOOP;

  IF ABS(NVL(ww_refreal,0) - NVL(ww_ttrefue,0)) < 10 OR ww_veces > 12 OR ww_neto = 'S' THEN
     EXIT;
  END IF;

 END LOOP;
 ww_dfcuota := p_TOT_PRESTAMO - ww_ttcapit;
 IF ww_dfcuota <> 0 THEN
    v_detalle.MTO_CAPITAL  := v_detalle.MTO_CAPITAL + ww_dfcuota;
    v_detalle.VAL_INTERES  := v_detalle.VAL_INTERES - ww_dfcuota;
    v_MTO_INTERES := v_MTO_INTERES - ww_dfcuota;
 END IF;

END IF;

 --v_retorno.listadescuotas := v_listacuotas;
   v_retorno:= v_listacuotas;
 RETURN v_retorno;

----------------------------------------------------------------
IF p_TIP_INTERES = 'A' AND ww_existe = 'S' THEN
   raise_application_error(-20000,'Existen cuotas con valor 0(cero). Verifique!!!');
END IF;
EXCEPTION
  WHEN OTHERS THEN
      raise_application_error(-20000,'Error al generar cuotas!'||sqlerrm);
END;
   --FIN GENERACION CUOTAS NETO

PROCEDURE pr_val_montos(p_solicitud in out typ_dessolicitud,
                        p_cargos in out typ_listadescargo,
                        p_cuotas in out typ_listadescuota
                        ) IS
  v_tot_capital number := 0;
  v_tot_interes number := 0;
  v_iva_interes number := 0;
  v_tot_seguro  number := 0;
  v_car_iva     number := 0;
  v_car_seg     number := 0;
  v_margen      number := 10;
  v_mensaje     varchar2(1000);
  v_cod_tasa    number(10);
  v_val_tasa    number(20,4);
  v_fec_vigencia date;
  v_tip_valor   varchar2(10);
  v_tipo        varchar2(10);
  v_tot_cap_prop number := 0;
BEGIN
  -- cuotas
  for k in 1.. p_cuotas.count loop
    v_tot_capital := nvl(v_tot_capital,0) + p_cuotas(k).mto_capital;
    v_tot_interes := nvl(v_tot_interes,0) + p_cuotas(k).val_int_adelantado;
    v_tot_seguro  := nvl(v_tot_seguro,0) + p_cuotas(k).mto_seguro;
  end loop;
  -- cargos
  for x in 1.. p_cargos.count loop
    if p_cargos(x).cod_transaccion = 709 then
      v_car_iva := p_cargos(x).monto;
    elsif p_cargos(x).cod_transaccion = 736 then
      v_car_seg := p_cargos(x).monto;
    end if;
  end loop;
  -- Control Solicitud.
  if p_tip_monto = 'N' then
    v_tot_cap_prop := (p_solicitud.tot_prestamo - p_solicitud.tot_interes);
    if v_tot_cap_prop != v_tot_capital then
      if (v_tot_capital - v_tot_cap_prop) = 1 then
        for k in 1.. p_cuotas.count loop
          if k = 1 then
            p_cuotas(k).mto_capital := p_cuotas(k).mto_capital -1;
            p_cuotas(k).val_cuota := p_cuotas(k).val_cuota -1;
          end if;
        end loop;
      elsif (v_tot_cap_prop - v_tot_capital) = 1 then
        for k in 1.. p_cuotas.count loop
          if k = 1 then
            p_cuotas(k).mto_capital := p_cuotas(k).mto_capital +1;
            p_cuotas(k).val_cuota := p_cuotas(k).val_cuota +1;
          end if;
        end loop;
      end if;
    end if;
  end if;
  if p_solicitud.tot_interes != v_tot_interes then
    if abs(p_solicitud.tot_interes - v_tot_interes) <= v_margen then
      p_solicitud.tot_interes := v_tot_interes;
    end if;
  end if;
  pag_gen.pr_obt_val_tasa(v_cod_modulo, p_cod_modalidad,
                          null, null, v_cod_moneda,
                          null, 'N', v_cod_tasa, 709, --Transaccion
                          trunc(sysdate), v_val_tasa, v_fec_vigencia, v_tip_valor, v_tipo);

  v_iva_interes := round(nvl( p_solicitud.tot_interes,0) * (v_val_tasa / 100), v_redondeo);
  --
  -- Control Cargos
  if v_car_iva != v_iva_interes then
    if abs(v_car_iva - v_iva_interes) <= v_margen then
      v_car_iva := v_iva_interes;
      for x in 1.. p_cargos.count loop
        if p_cargos(x).cod_transaccion = 709 then
          p_cargos(x).monto := v_car_iva;
        end if;
      end loop;
    end if;
  end if;

  if v_car_seg != v_tot_seguro then
    if abs(v_car_seg - v_tot_seguro) <= v_margen then
      v_car_seg := v_tot_seguro;
      for x in 1.. p_cargos.count loop
        if p_cargos(x).cod_transaccion = 736 then
          p_cargos(x).monto := v_car_seg;
        end if;
      end loop;
    end if;
  end if;
EXCEPTION
  WHEN OTHERS THEN null;
END;

  BEGIN
    v_max_tasa  := 'N';
    v_max_gastos:= 'N';
    v_tasa_back := 0;
    v_bandera   := null;
    v_tasa_mod  := null;
    g_msj_error := ' ';
    g_cod_error := 0;
    V_CAN_DIA_PRI_VCTO :=  fug_obt_pardinamico('CAN_DIA_PRI_VCTO',
                                 6,
                                 p_cod_modalidad,
                                 p_cod_moneda,
                                 v_cod_oficina);


  IF p_fec_pri_vencimiento IS NULL THEN
     V_FEC_PRI_VENCIMIENTO := v_fec_actual + 30;
  END IF;
  
 
  --Validacion de campos obligatorios

   pr_val_parametros(p_tip_persona,
                     p_cod_modalidad,
                     p_cod_moneda,
                     p_monto,
                     p_can_documento,
                     v_val_tasa,
                     p_tas_impositiva,
                     p_cod_ent_seguro);

  IF nvl(g_cod_error,'000') = '000' and nvl(fug_obt_pardinamico('PRE_MOD_AFD',6, p_cod_modalidad,p_cod_moneda), 'N')= 'S'then
    pp_val_dias_gracia;
  end if;

  -- Recupera tasa de seguro
   if v_ent_seguro is null then
      g_cod_error := '1';
      g_lugar := 'Verificacion Ente Seguro';
      g_msj_error := 'Debe ingresar Codigo de Ente de Seguro.';
   end if;
   if pap_sim.g_cod_error = 0 then
      v_cod_Tas_seguro  := fug_obt_parentes(v_ent_seguro,'COD_TAS_SEG_DESCUENTO');
      v_cod_tas_tpm   := fug_obt_parentes(v_ent_seguro,'COD_TAS_TPM_SEG_DESCUENTO');

      if v_cod_Tas_seguro is not null then
         v_val_tas_seguro := fug_obt_valtas_rango(v_cod_Tas_seguro, v_cod_modulo,p_cod_modalidad,
                                         p_cod_moneda,p_cod_oficina,
                                         p_fec_vencimiento- v_fec_inicio,
                                         v_fec_actual);
         if v_val_tas_seguro is null then
            g_cod_error := '2';
            g_lugar := 'Verificacion Valor Tasa Seguro';
            g_msj_error := 'No encuentra valor de la tasa del seguro de vida. Verifique';
         end if;
      else
          g_cod_error := '3';
          g_lugar := 'Verificacion Tasa Seguro';
          g_msj_error := 'No encuentra codigo de la tasa del seguro de vida. Verifique';
      end if;
      if pap_sim.g_cod_error = 0 then
      if  v_cod_tas_tpm is not null then
         v_val_tas_tpm:=fug_obt_valtas_rango(v_cod_tas_tpm, v_cod_modulo,p_cod_modalidad,
                                         p_cod_moneda,p_cod_oficina,
                                         p_fec_vencimiento- v_fec_inicio,
                                         v_fec_actual);
         if v_cod_tas_tpm is null then
            g_cod_error := '4';
            g_lugar := 'Verificacion Valor Tasa TPM';
            g_msj_error := 'No encuentra valor de la tasa TPM. Verifique';
         end if;
       else
          g_cod_error := '5';
          g_lugar := 'Verificacion Tasa TPM';
          g_msj_error := 'No encuentra codigo de la tasa TPM. Verifique';
       end if;
       end if;
   end if;


  listaCheques := p_chequesdet.listacheques;

    if pap_sim.g_cod_error = 0 then
        -- Valido el codigo de la modalidad que recibo----------------------------
        pr_val_cod_modalidad;

        -- valido la moneda-------------------------------------------------------
        if pap_sim.g_cod_error = 0 then
          v_cod_moneda:= fu_val_cod_moneda(upper(p_cod_moneda));
          v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', v_cod_modulo, p_cod_modalidad, v_cod_moneda, p_cod_oficina);
        end if;
        if pap_sim.g_cod_error = 0 then
           v_vto_hab_cheques := fug_obt_pardinamico('VTO_HAB_CHEQUES',v_cod_modulo, p_cod_modalidad, v_cod_moneda, p_cod_oficina);
        end if;
        if pap_sim.g_cod_error = 0 then
           if p_can_documento <> p_chequesdet.listacheques.count then
              g_cod_error := '19';
              g_lugar := 'Verificacion de Cantidad de Documentos';
              g_msj_error := 'Cantidad de documentos no coincide con detalle de Cheques. Verifique!';
           end if;
        end if;        
 
        if pap_sim.g_cod_error = 0 then
         --DA 7202 para volver aqui al hacer Max. tasa
         <<recalc>>
           IF (p_chequesdet IS NOT NULL) THEN
                 IF nvl(p_monto, 0) <= 0 THEN
                    g_cod_error := 1;
                    g_lugar := 'Valida Monto ingresado';
                    g_msj_error := 'Ingrese Monto del Credito';
                 END IF;
              if pap_sim.g_cod_error = 0 then
                 IF nvl(p_can_documento, 0) <= 0 THEN
                    g_cod_error := 1;
                    g_lugar := 'Valida Cantidad de Documentos';
                    g_msj_error := 'Ingrese Cantidad de Documentos.';
                 END IF;
              end if;
              if pap_sim.g_cod_error = 0 then
                IF V_FEC_PRI_VENCIMIENTO IS NULL THEN
                  V_FEC_PRI_VENCIMIENTO := v_fec_actual + 30;
                END IF;
              end if;
               if pap_sim.g_cod_error = 0 then
                 v_cuotas := fu_carCuotas(p_can_documento,
                                        p_chequesdet);
               end if;
              --RECALCULAR CUOTAS
            if pap_sim.g_cod_error = 0 then
             -- raise_application_error(-20000,'v_fec_vencimiento '||v_fec_vencimiento);
              v_dia_plazo    := p_fec_vencimiento - v_fec_inicio;
              v_tot_prestamo := p_monto;
               --informacion de tasas de las pizarras
              pr_val_tasa;
              ---Valido que la tasa v_val_tasa ingresada sea distinta o igual a la pizarra DA 7202
              If nvl(v_si_maximiza,'N') = 'N' then
                if nvl(v_val_tasa,0) <> nvl(v_tas_interes,0)  then
                  v_tasa_mod := 'S';
                Else
                  v_tasa_mod := 'N';
                End if;  
               End if;            
             end if;
              --Cargos por defecto
              if pap_sim.g_cod_error = 0 then
                 v_cargos := fu_obt_cargos;
              end if;
               --When validate cod_transaccion
              if pap_sim.g_cod_error = 0 then
                 pr_obt_datos_cargo(v_cargos);
              end if;
               --GENERAR CUOTAS
             /* if pap_sim.g_cod_error = 0 then
                 v_cuotas := fu_carCuotas(p_can_documento,
                                        p_chequesdet);
              end if;*/
              if pap_sim.g_cod_error = 0 then
                if p_tip_monto = 'B' then
                 v_cuo_final:= fu_gen_cuotas('N',
                                              v_val_tasa,
                                              p_monto,
                                              p_can_documento,
                                              v_dia_plazo,
                                              v_nro_solicitud,
                                              v_fec_inicio,
                                              V_FEC_PRI_VENCIMIENTO,
                                              'A' ,
                                              p_monto,
                                              v_cuotas);
                else
                   v_cuo_final:= fu_gen_cuotas_neto('S',
                                              v_val_tasa,
                                              p_monto,
                                              p_can_documento,
                                              v_dia_plazo,
                                              v_nro_solicitud,
                                              v_fec_inicio,
                                              V_FEC_PRI_VENCIMIENTO,
                                              'A' ,
                                              p_monto,
                                              v_tot_cargo,
                                              v_cargos,
                                              v_cuotas,
                                              p_chequesdet,
                                              v_tot_che_futuro);
                end if;

             end if;
             if pap_sim.g_cod_error = 0 then

               pr_cal_cargos(v_tot_prestamo,
                             v_mto_interes,
                             v_desembolsar,
                             v_tot_cargo,
                             v_ttvalor,
                             v_cargos) ;
             end if;
             if pap_sim.g_cod_error = 0 then
                 if nvl(v_max_tasa,'N') = 'N' then ---add DA 7202
                  SELECT s_nro_sol_tmp.nextval INTO v_nro_solicitud FROM dual;
                 End if;
                 --SELECT s_nro_sim_descuento.nextval INTO v_nro_solicitud FROM dual; Comentado DA 7202

                  v_solicitud.nro_solicitud:= v_nro_solicitud;
                  v_solicitud.cod_persona:= p_cod_persona;
                  v_solicitud.cod_modulo := v_cod_modulo;
                  v_solicitud.cod_modalidad:= p_cod_modalidad;
                  v_solicitud.des_modalidad:= fug_obt_des_modal(v_cod_modulo,p_cod_modalidad);
                  v_solicitud.cod_moneda:= v_cod_moneda;
                  v_solicitud.monto:= p_monto;
                  v_solicitud.cod_oficina:=p_cod_oficina;
                  v_solicitud.fec_inicio:= nvl(p_fec_inicio,v_fec_actual);
                  v_solicitud.can_documento:=p_can_documento;
                  v_solicitud.fec_pri_vencimiento:= V_FEC_PRI_VENCIMIENTO;
                  v_solicitud.cod_tasa:= p_cod_tasa;
                  v_solicitud.val_tasa:= v_val_tasa;
                  v_solicitud.plazo := v_dia_plazo;
                  v_solicitud.fec_vencimiento:=v_fec_vencimiento;
                  v_solicitud.descripcion:= NVL(p_descripcion,'Simulacion de Descuento de Cheques');

                 -- v_solicitud.listaDescuotas:=v_cuo_final;
            end if;
            if pap_sim.g_cod_error = 0 then
                 IF nvl(p_tip_monto,'B') = 'N' THEN

                    pr_cal_cargos(v_tot_prestamo,
                                           v_mto_interes,
                                           v_desembolsar,
                                           v_tot_cargo,
                                           v_ttvalor,
                                           v_cargos) ;

                    v_cuo_final:= fu_gen_cuotas_neto('S',
                                              v_val_tasa,
                                              p_monto,
                                              p_can_documento,
                                              v_dia_plazo,
                                              v_nro_solicitud,
                                              v_fec_inicio,
                                              V_FEC_PRI_VENCIMIENTO,
                                              'A' ,
                                              p_monto,
                                              v_tot_cargo,
                                              v_cargos,
                                              v_cuotas,
                                              p_chequesdet,
                                              v_tot_che_futuro);

/*                             pr_cal_cargos(v_tot_prestamo,
                                           v_mto_interes,
                                           v_desembolsar,
                                           v_tot_cargo,
                                           v_ttvalor,
                                           v_cargos) ;*/
             /*PR_CAL_MTO_TOT_PRESTAMO(v_tot_cargo,
                                      V_TTVALOR,
                                      v_tot_prestamo);*/
 /*              v_cuo_final:= fu_gen_cuotas_neto('S',
                                              v_val_tasa,
                                              p_monto,
                                              p_can_documento,
                                              v_dia_plazo,
                                              v_nro_solicitud,
                                              v_fec_inicio,
                                              V_FEC_PRI_VENCIMIENTO,
                                              'A' ,
                                              p_monto,
                                              v_tot_cargo,
                                              v_cargos,
                                              v_cuotas,
                                              v_tot_che_futuro);
             pr_cal_cargos(v_tot_prestamo,
                                           v_mto_interes,
                                           v_desembolsar,
                                           v_tot_cargo,
                                           v_ttvalor,
                                           v_cargos) ;

               v_cuo_final:= fu_gen_cuotas_neto('S',
                                              v_val_tasa,
                                              p_monto,
                                              p_can_documento,
                                              v_dia_plazo,
                                              v_nro_solicitud,
                                              v_fec_inicio,
                                              V_FEC_PRI_VENCIMIENTO,
                                              'A' ,
                                              p_monto,
                                              v_tot_cargo,
                                              v_cargos,
                                              v_cuotas,
                                              v_tot_che_futuro);   */
                     pr_cal_cargos(v_tot_prestamo,
                                           v_mto_interes,
                                           v_desembolsar,
                                           v_tot_cargo,
                                           v_ttvalor,
                                           v_cargos) ;
           END IF;
         end if;
         v_solicitud.tot_interes:= V_MTO_INTERES;
         v_solicitud.tot_Cargos:= v_tot_cargo;
         if p_tip_monto = 'B' then
            v_solicitud.tot_a_desembolsar:= p_monto - ( v_solicitud.tot_interes + v_solicitud.tot_Cargos);
            v_solicitud.tot_prestamo := p_monto;
         else
            v_solicitud.tot_a_desembolsar:= p_monto;
            v_solicitud.tot_prestamo := p_monto + v_solicitud.tot_Cargos + v_solicitud.tot_interes;
            --v_solicitud.monto:= v_solicitud.tot_prestamo;
         end if;
         v_solicitud.error := g_cod_error;
         v_solicitud.nombrerespuesta := g_lugar;
         v_solicitud.descripcionrespuesta:= g_msj_error;

      pr_val_montos(v_solicitud, v_cargos, v_cuo_final);

      if pap_sim.g_cod_error = 0 then
         p_cuotas:= v_cuo_final;
         p_cargos:= v_cargos;
         p_solicitud:= v_solicitud;
      end if;

      --Agrega las tablas temporales DA-7202
      If nvl(pap_sim.g_cod_error,0) = 0 then   
         If nvl(v_max_tasa,'N') = 'N'  then
          BEGIN
            INSERT INTO pr_solicitudes_tmp
              (nro_solicitud,
               descripcion,
               monto,
               dia_plazo,
               fec_vencimiento,
               fec_inicio,
               tip_monto,
               tot_prestamo,
               cod_modulo,
               cod_modalidad,
               cod_moneda,
               cod_oficina,
               fec_pri_vencimiento,
               val_tasa,
               can_cuotas,
               tip_amortizacion,
               tot_interes,
               tot_cargos)
            VALUES
              (v_nro_solicitud,
               'DESC. DE CHEQ.',
               p_monto,
               v_dia_plazo,
               v_fec_inicio + v_dia_plazo,
               v_fec_inicio,
               p_tip_monto,
               v_tot_prestamo,
               v_cod_modulo,
               p_cod_modalidad,
               p_cod_moneda,
               nvl(p_cod_oficina,v_cod_oficina),
               V_FEC_PRI_VENCIMIENTO,
               v_val_tasa,
               p_can_documento,
               v_tip_amortizacion,
               V_MTO_INTERES,
               v_tot_cargo);
          EXCEPTION
            WHEN OTHERS THEN
              g_cod_error := '020';
              g_lugar     := 'Inserta pr_solicitudes_tmp';
              g_msj_error := 'Error al insertar pr_solicitudes_tmp ' ||SQLERRM;                             
          END;
        ELSE
           BEGIN
             UPDATE pr_solicitudes_tmp p
                SET p.monto        = p_monto,
                    p.tot_prestamo = v_tot_prestamo,
                    p.val_tasa     = v_val_tasa,
                    p.tot_interes  = V_MTO_INTERES,
                    p.tot_cargos   = v_tot_cargo
              WHERE p.nro_solicitud = v_nro_solicitud;
           EXCEPTION
             WHEN OTHERS THEN
               g_cod_error := '021';
               g_lugar     := 'Error al actualizar';
               g_msj_error := 'Error al actualizar pr_solicitud_tmp' ||SQLERRM;                              
           END;
         END IF;
       END IF;
               
       If nvl(pap_sim.g_cod_error,0) = 0 then   
        If nvl(v_max_tasa,'N') = 'N'  then
          for a in 1 .. p_cargos.count loop
             begin
               INSERT INTO pr_sol_cargos_tmp
                 (nro_solicitud,
                  cod_transaccion,
                  val_tasa,
                  monto,
                  cod_tasa,
                  cod_ent_seguro,
                  cod_moneda,
                  mto_mon_prestamo)
               VALUES
                 (v_nro_solicitud,
                  p_cargos       (a).cod_Transaccion,
                  p_cargos       (a).val_tasa,
                  p_cargos       (a).monto,
                  p_cargos       (a).cod_tasa,
                  v_ent_seguro,
                  p_cargos       (a).cod_moneda,
                  p_cargos       (a).MTO_MON_PRESTAMO);
             EXCEPTION
               WHEN OTHERS THEN
                 g_cod_error := '022';
                 g_lugar     := 'Inserta Cargos';
                 g_msj_error := 'Error al insertar los cargos. ' || SQLERRM;
             END;
            End loop;
          Else
            for a in 1 .. p_cargos.count loop
              Begin
                update pr_sol_cargos_tmp t
                   set t.val_tasa         = p_cargos(a).val_tasa,
                       t.monto            = p_cargos(a).monto,
                       t.mto_mon_prestamo = p_cargos(a).MTO_MON_PRESTAMO
                 where t.nro_solicitud = v_nro_solicitud
                   and cod_transaccion = p_cargos(a).cod_transaccion
                   and cod_tasa = p_cargos(a).cod_tasa;
              exception
                when others then
                  g_cod_error := '023';
                  g_lugar     := 'Actualiza pr_sol_cargos_tmp';
                  g_msj_error := 'Error al actualizar los pr_sol_cargos_tmp. ' || SQLERRM;                                
              END;
             end loop;                
           End if;
        End if;
               
         --Inserta las cuotas temporales
       If nvl(pap_sim.g_cod_error,0) = 0 then   
         If nvl(v_max_tasa,'N') = 'N'  then
          for x in 1 .. p_cuotas.count loop       
           begin     
            INSERT INTO pr_sol_cuotas_tmp
             (nro_solicitud,
              nro_cuota,
              fec_vencimiento,
              mto_capital ,
              mto_interes,
              dia_periodo)
             VALUES
              (v_nro_solicitud,
               p_cuotas(x).nro_cuota,
               to_char(p_cuotas(x).FEC_VTO_HABIL,'DD/MM/YYYY'),
               nvl(p_cuotas(x).MTO_CAPITAL , 0),
               nvl(p_cuotas(x).VAL_INT_ADELANTADO, 0),
               p_cuotas(x).DIA_PERIODO);
            Exception
             when others then
              g_cod_error := '024';
              g_lugar     := 'Inserta Cuotas';
              g_msj_error := 'Error al insertar las cuotas ' || SQLERRM;
            end;
           END LOOP;
          Else
             for x in 1 .. p_cuotas.count loop 
              begin
                update pr_sol_cuotas_tmp t
                   set t.mto_capital = nvl(p_cuotas(x).MTO_CAPITAL - p_cuotas(x).VAL_INT_ADELANTADO,0),
                       t.mto_interes = nvl(p_cuotas(x).VAL_INT_ADELANTADO, 0)
                 where t.nro_solicitud = v_nro_solicitud
                   and t.nro_cuota = p_cuotas(x).nro_cuota;
              exception
                when others then
                  g_cod_error := '025';
                  g_lugar     := 'Actualiza pr_sol_cuotas_tmp';
                  g_msj_error := 'Error al actualizar pr_sol_cuotas_tmp ' ||SQLERRM;                                 
              end;
            end loop;
          End if;
       End if;
       --maximiza tasas DA-7202
       If nvl(pap_sim.g_cod_error,0) = 0 then       
        v_codi_tasa := 351; 
        begin
          pag_gen.pr_obt_val_tasa(v_cod_modulo, p_cod_modalidad, v_cod_oficina,
          null , p_cod_moneda, p_monto, 'S',  v_codi_tasa /*out*/, null ,v_fec_actual,          
          v_valor_tasa /*out*/, v_fec_vigencia/*out*/,  v_tipo_valor /*out*/,v_tipo/*out*/, null);        
        exception 
         when others then
          v_max_tasa := 'X';
        End;
        
        If nvl(v_max_tasa,'N') <> 'X' AND (p_monto between pag_gen.FU_OBT_VAL_MINIMO and pag_gen.FU_OBT_VAL_MAXIMO )
        AND to_number(nvl(fug_obt_pardinamico('VAL_INI_AUMTASA',null,null, p_cod_moneda, null),0),'999G999D999999', 'NLS_NUMERIC_CHARACTERS='',.''') <> 0 and nvl(v_tasa_mod,'N') <> 'S' then
           v_max_tasa := 'S';       
        else
           v_max_tasa := 'N';
        End if;
       
        If nvl(v_max_tasa,'X') = 'S'  then
           begin
             pap_sim.pr_obt_tas_tmp(v_nro_solicitud, null, v_tae, v_tan);
           exception
             when others then
               g_cod_error := '026';
               g_lugar     := 'Busca la TAE';
               g_msj_error := 'Error al buscar la TAE ' || sqlerrm;
               v_tas_efec  := 0;
           end;
           If  nvl(v_tas_efec, 0) <> 0 then 
               If nvl(v_tae,0) > nvl(v_tas_efec, 0) and nvl(v_tasa_back,0) > 0 then
                 v_val_tasa := nvl(v_tasa_back,0);                 
                 v_valor_aum := round( (v_valor_aum / 2 ) , 3);
                 If( nvl(v_val_tasa + v_valor_aum,0) between nvl(v_tas_minima,0) and nvl(v_tas_maxima,0) ) then 	 
                    v_val_tasa := v_val_tasa + v_valor_aum;
                    v_bandera := 'N';
                    v_si_maximiza := 'S';
                    goto recalc;
                 end if;
               elsif nvl(v_tae,0) < nvl(v_tas_efec, 0) then
                IF nvl(v_bandera,'S') = 'S' then
                  v_tasa_back := v_val_tasa;
                  If ( nvl( v_val_tasa + v_valor_aum,0) between nvl(v_tas_minima,0) and nvl(v_tas_maxima,0) ) then
                     v_val_tasa := v_val_tasa + v_valor_aum;
                     v_si_maximiza := 'S';
                     goto recalc;
                  end if;
                end if;
               end if;
           end if; 
         end if;
        End if;  --Fin cod_error = 000
         ----Fin DA -7202 Maximiza tasa
     else
       g_cod_error := '19';
       g_lugar := 'Verifica Detalle Cheques';
       g_msj_error := 'No se encuentra el detalle de cheques.';
     end if;
    end if;
   end if;
   
    IF nvl(g_cod_error,'000') = '000' then 
       pap_sim.pr_obt_tas_tmp(v_nro_solicitud, null, v_tae, v_tan);
       If nvl(v_tae,0) > nvl(v_tas_efec, 0)  Then
          g_cod_error := '052';
          g_lugar     := 'Supera TAE';
          g_msj_error := 'Valor obtenido :'||v_tae||' valor pizzarra:'||v_tas_efec;
       end if;           
    end if;    
   v_solicitud.error := g_cod_error;
   v_solicitud.nombrerespuesta := g_lugar;
   v_solicitud.descripcionrespuesta:= g_msj_error;
   p_solicitud:= v_solicitud;

 EXCEPTION
    WHEN OTHERS THEN
       g_cod_error := '19';
       g_lugar := 'Genera propuesta';
       g_msj_error := 'Error al generar la propuesta'||sqlerrm;
       v_solicitud.error := g_cod_error;
       v_solicitud.nombrerespuesta := g_lugar;
       v_solicitud.descripcionrespuesta:= g_msj_error;
       p_solicitud:= v_solicitud;
 END;

 -- Prestamos con periodo de gracia y cuotas iguales.
 PROCEDURE pr_sim_cuo_iguales(p_cod_modalidad  in number,
                              p_cod_moneda     in varchar2,
                              p_tip_monto      in varchar2,
                              p_mto_solicitado in number,
                              p_can_cuotas     in number,
                              p_fec_pri_vencimiento in date,
                              p_solicitud      out typ_consolicitud,
                              p_cargos         out typ_listaconcargo,
                              p_cuotas         out typ_listaconcuota,
                              p_tip_persona    in varchar2,
                              p_mto_consolidado in number)
    is
    i NUMBER(3);
    ------------------ Variables del procedimiento -----------------------------
    v_dummy               NUMBER(9);
    v_cod_modulo          NUMBER(3) := 6; -- prestamos
    v_fec_actual          DATE := pag_cal.fu_obt_fec_actual(v_cod_modulo);
    v_cod_oficina         NUMBER(3):= fug_obt_ofi_usuario(user);
    v_mon_local           VARCHAR2(3) := pag_gen.fu_obt_mon_local;
    v_cotizacion          ge_cotizaciones.val_conversion%TYPE := pag_gen.fu_obt_cotizacion(p_cod_moneda);
    v_lugar               VARCHAR2(200) := NULL;
    v_exo_impuestos       VARCHAR2(1) := 'N';
    v_tot_prestamo        NUMBER(18, 2) := 0; -- total del prestamo
    v_mto_interes         NUMBER(18, 2) := 0; -- total de interes
    v_mto_cargo           NUMBER(18, 2) := 0;
    v_fec_inicio          DATE := v_fec_actual;
    --v_fec_pri_vencimiento DATE := add_months(v_fec_inicio, 1);
    v_tip_amortizacion    VARCHAR2(1) := 'P';
    v_val_tasa            NUMBER;
    v_dia_plazo           NUMBER(8);
    v_per_capital         pr_solicitudes.per_vto_capital%TYPE;
    v_nro_solicitud       NUMBER(10);
    v_por_ajuste          NUMBER;
    v_ttvalor             NUMBER(18, 2);
    -- Datos de los cargos -----------------------------------------------------
    v_cod_transaccion NUMBER(4);
    v_cod_tas_cargo   NUMBER(4);
    v_val_tas_cargo   NUMBER;
    v_cod_mon_cargo   VARCHAR2(3);
    v_tpvlpor         VARCHAR2(1);
    v_aplicar         VARCHAR2(3);
    v_tpdetas         VARCHAR2(1);
    v_val_cargo       NUMBER(18, 2);
    v_cod_ent_seguro  NUMBER(6);
    v_consolicitud    typ_consolicitud  := typ_consolicitud();
    v_consolcargos    typ_listaconcargo := typ_listaconcargo();
    v_consolcuotas    typ_listaconcuota := typ_listaconcuota();
    v_mto_seg_cancelacion NUMBER(18,2);
    v_imp_cargo           NUMBER(18, 2);
    ----variables para calculo de seguro------------------
    v_tas_seguro      NUMBER(18,4);
    v_mto_tot_seguro   NUMBER(18,4);
    -- control del redondeo ----------------------------------------------------
    v_redondeo  NUMBER(2) := 0; -- redondeo a cero para moneda local
    v_can_dia_pri_vcto    number;
    v_mto_cuota number := 0;
    v_desembolsar NUMBER(18, 2);
    -----Max Tasa ---- DA 7202 --- 
    v_valor_aum pr_sol_tasas.val_tasa%TYPE := to_number(nvl(fug_obt_pardinamico('VAL_INI_AUMTASA',null,null, p_cod_moneda, null),0),'999G999D999999', 'NLS_NUMERIC_CHARACTERS='',.''');
    ------------------ rutinas internas del procedimiento-----------------------
    PROCEDURE pr_val_tasa IS
      CURSOR pizarras IS
        SELECT a.tas_interes, a.tas_minima, a.tas_maxima, a.tas_efectiva
          FROM cr_piz_montos b, cr_piz_plazos a
         WHERE a.cod_modulo = v_cod_modulo
           AND a.cod_modalidad = p_cod_modalidad
           AND a.cod_moneda = p_cod_moneda
           AND b.cod_modulo = a.cod_modulo
           AND b.cod_modalidad = a.cod_modalidad
           AND b.cod_moneda = a.cod_moneda
           AND b.mto_desde = a.mto_desde
           AND p_mto_solicitado BETWEEN b.mto_desde AND b.mto_hasta
           AND v_dia_plazo BETWEEN a.plz_desde AND a.plz_hasta;
      v_tas_interes NUMBER;

    BEGIN
      v_lugar := 'obtener_tasas de pizarras';
      OPEN pizarras;
      FETCH pizarras
        INTO v_tas_interes, v_tas_minima, v_tas_maxima,v_tas_efec;
      CLOSE pizarras;
      IF v_val_tasa IS NULL THEN
        v_val_tasa := nvl(v_tas_interes,32);
      ELSE
        -- valido la tasa ingresada---
        IF NOT v_val_tasa BETWEEN v_tas_minima AND v_tas_maxima THEN
          g_cod_error := '009';
          g_lugar     := 'Valida Tasa ingresada';
          g_msj_error := 'Tasa fuera de Rango. Verifique la Pizarra';
        END IF;
      END IF;
    END;

    -- Validacion del tipo de credito--------------------------------------------
    PROCEDURE pr_val_cod_modalidad IS
    BEGIN
      SELECT 0
        INTO v_dummy
        FROM ge_modalidades
       WHERE cod_modulo = v_cod_modulo
         AND cod_modalidad = p_cod_modalidad;
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
       WHERE cod_moneda = p_cod_moneda;
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

           If v_can_meses < nvl(fug_obt_pardinamico('PRE_PER_GRACIA_MIN',
                                             v_cod_modulo,
                                             p_cod_modalidad,
                                             p_cod_moneda),
                         0) then
             g_cod_error := 8;
             g_lugar     := 'Valida Dias de Gracia';
             g_msj_error := 'Periodo de gracia ' || v_can_meses ||
                ' no debe ser menor a ' ||
                nvl(fug_obt_pardinamico('PRE_PER_GRACIA_MIN',
                                        v_cod_modulo,
                                             p_cod_modalidad,
                                             p_cod_moneda),
                    0);
           end if;
           If nvl(pap_sim.g_cod_error,'000') ='000' and v_can_meses > nvl(fug_obt_pardinamico('PRE_PER_GRACIA_MAX',
                                             v_cod_modulo,
                                             p_cod_modalidad,
                                             p_cod_moneda),
                         0) then
              g_cod_error := 8;
              g_lugar     := 'Valida Dias de Gracia';
              g_msj_error :='Periodo de gracia ' || v_can_meses ||
                ' no debe ser mayor a ' ||
                nvl(fug_obt_pardinamico('PRE_PER_GRACIA_MAX',
                                        v_cod_modulo,
                                             p_cod_modalidad,
                                             p_cod_moneda),
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
     if ww_cddetas is null then 
      --- 1. Busco la tasa asociada a la transaccion ingresada ---
      SELECT tr.cod_tasa, ta.aplicar, ta.tip_valor, ta.tipo
        INTO ww_cddetas, ww_aplicar, ww_tpvlpor, ww_tpdetas
        FROM ge_transacciones tr, ge_tasas ta
       WHERE tr.cod_modulo = v_cod_modulo
         AND tr.cod_modalidad = p_cod_modalidad
         AND tr.cod_transaccion = ww_cdtrans
         AND tr.tipo = 'D'
         AND tr.cod_tasa IS NOT NULL
         AND tr.cod_tasa = ta.cod_tasa
         AND EXISTS (SELECT 0
                FROM ge_transacciones_det
               WHERE cod_modulo = v_cod_modulo
                 AND cod_modalidad = p_cod_modalidad
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
             (f1.cod_modalidad = p_cod_modalidad))
         AND (f1.cod_modulo IS NULL OR (f1.cod_modulo = v_cod_modulo))
         AND (f1.cod_moneda IS NULL OR (f1.cod_moneda = p_cod_moneda))
         AND (f1.cod_oficina IS NULL OR (f1.cod_oficina = v_cod_oficina))
         AND f1.nro_cuenta IS NULL
         AND f1.fec_vigencia =
             (SELECT MAX(fec_vigencia)
                FROM ge_tas_fechas f2
               WHERE f1.cod_tasa = f2.cod_tasa
                 AND (f2.cod_modalidad IS NULL OR
                     (f2.cod_modalidad = p_cod_modalidad))
                 AND (f2.cod_modulo IS NULL OR
                     (f2.cod_modulo = v_cod_modulo))
                 AND (f2.cod_moneda IS NULL OR
                     (f2.cod_moneda = p_cod_moneda))
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
           AND (tr.cod_modalidad = p_cod_modalidad OR
               tr.cod_modalidad IS NULL)
           AND (tr.cod_moneda = p_cod_moneda OR tr.cod_moneda IS NULL)
           AND (tr.cod_oficina = v_cod_oficina OR tr.cod_oficina IS NULL)
           AND tr.val_hasta >= ww_vlmonto
           AND tr.nro_cuenta IS NULL
           AND tr.fec_vigencia =
               (SELECT MAX(tra.fec_vigencia)
                  FROM ge_tas_rangos tra
                 WHERE tra.cod_tasa = ww_cddetas
                   AND (tra.cod_modulo = v_cod_modulo OR
                       tra.cod_modulo IS NULL)
                   AND (tra.cod_modalidad = p_cod_modalidad OR
                       tra.cod_modalidad IS NULL)
                   AND (tra.cod_moneda = p_cod_moneda OR
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
        g_msj_error := 'No existe Valor para la Tasa ' ||
                       to_char(ww_cddetas) || ' y el Monto ' ||
                       to_char(ww_vlmonto) || ' Fecha ' ||
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
      v_cod_Tasa number(15);
      v_des_transaccion varchar2(35);
      v_obligatorio  varchar2(2);
      v_afecta varchar2(5);
    BEGIN

     IF v_cod_transaccion in(737,1271) AND p_tip_persona = 'J' and nvl(fug_obt_pardinamico('PRE_SEG_DIF_JURIDICAS',v_cod_modulo, p_cod_modalidad,p_cod_moneda), 'N')='S' THEN
    --Traer valor de la tasa del seguro
       v_cod_Tasa  := fug_obt_parentes(p_cod_seguro,'COD_TAS_JURIDICA');
       if  v_cod_tasa is not null then
         SELECT initcap(TR.DESCRIPCION),TA.COD_TASA,TA.APLICAR,TA.TIP_VALOR,TA.TIPO, DT.OBLIGATORIO, TR.AFECTA
          INTO v_des_transaccion,v_cod_tas_cargo,v_aplicar,v_tpvlpor,v_tpdetas,v_obligatorio,v_afecta
          FROM GE_TRANSACCIONES_DET DT, GE_TRANSACCIONES TR, GE_TASAS TA
         WHERE TR.COD_MODULO = v_cod_modulo
           AND TR.COD_MODALIDAD = p_cod_modalidad
           AND TR.COD_TRANSACCION = v_cod_transaccion
           AND TR.TIPO = 'D'
           AND v_cod_Tasa = TA.COD_TASA
           AND DT.COD_MODULO = v_cod_modulo
           AND DT.COD_MODALIDAD = p_cod_modalidad
           AND DT.COD_TRANSACCION = 358 /* transaccion de desembolso de prestamos */
           AND DT.COD_MOD_HIJO = TR.COD_MODULO
           AND DT.COD_MAD_HIJO = TR.COD_MODALIDAD
           AND DT.COD_TRA_HIJO = TR.COD_TRANSACCION;
       else
          g_cod_error := '030';
          g_lugar     := 'Busca datos tasa Per.Juridica';
          g_msj_error := 'No se encuentra definida la tasa para Seguro de Personas Juridicas. ' || SQLERRM;
       end if;

   ELSE
     if nvl(g_cod_error,'000') = '000' then
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

            v_val_tas_cargo := v_imp_cargo + ROUND(v_imp_cargo * 10/100,v_redondeo);
          else
            v_val_tas_cargo := fu_obt_valor_de_tasa_variable(v_cod_tas_cargo,
                                                     nvl(v_tot_prestamo,
                                                     p_mto_solicitado),
                                                     v_fec_inicio);
          end if;
        END IF;

      END IF;
      IF v_tpvlpor IN ('I', 'P', 'F') OR v_cod_transaccion IN (735, 736, 1270,2) THEN
        --- porcentajes  o transacciones de seguros  ---
        --v_cod_mon_cargo := v_mon_local;
        IF V_TPVLPOR = 'I' THEN
          v_cod_mon_cargo := v_mon_local;
        ELSE
          v_cod_mon_cargo := p_cod_moneda;
        END IF;
        --:VAL_TASA := WW_VLDETAS;

      ELSE
        --- en caso de que sean valores ----------------
        v_cod_mon_cargo := p_cod_moneda;
        v_val_cargo     := v_val_tas_cargo;
        v_val_tas_cargo := NULL;
      END IF;
    END;

    -- Carga de cargos de la propuesta-------------------------------------------
    PROCEDURE pr_gen_cargos IS
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
           AND a.cod_modalidad = p_cod_modalidad
           AND ((nvl(v_exo_impuestos, 'N') = 'N') OR
               (nvl(v_exo_impuestos, 'N') = 'S' AND
               nvl(b.obligatorio, 'N') = 'N'))
           and ((( nvl(fug_obt_pardinamico('PRE_SEG_DIF_JURIDICAS',v_cod_modulo, p_cod_modalidad,p_cod_moneda), 'N')= 'S' and (cod_ent_seguro is not null
           and p_tip_persona!= 'F'
           and cod_ent_seguro = nvl(fug_obt_pardinamico('PRE_COD_ENT_PER_JURIDICAS',v_cod_modulo, p_cod_modalidad,null),'99999'))
            or (nvl(fug_obt_pardinamico('PRE_SEG_DIF_JURIDICAS',v_cod_modulo, p_cod_modalidad,p_cod_moneda), 'N')='N'
          AND cod_ent_seguro <> nvl(fug_obt_pardinamico('PRE_COD_ENT_PER_JURIDICAS',v_cod_modulo, p_cod_modalidad,null),'9999')))
           or (p_tip_persona = 'F' and  cod_ent_seguro <> nvl(fug_obt_pardinamico('PRE_COD_ENT_PER_JURIDICAS',v_cod_modulo, p_cod_modalidad,null),'99999'))
           or cod_ent_seguro is null)
           or nvl(fug_obt_pardinamico('PRE_SEG_DIF_JURIDICAS',v_cod_modulo, p_cod_modalidad,p_cod_moneda), 'N')= 'N')
         ORDER BY 1;

    BEGIN
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
             IF cc.cod_transaccion in(737,1271) THEN
                --Calculo de seguro total simulando
                v_tas_seguro := v_val_tas_cargo;
             END IF;

          BEGIN
           if nvl(p_mto_consolidado,0) = 0 and v_cod_transaccion = nvl(fug_obt_pardinamico('PRE_TRA_MTO_CONSOLIDADO',
                                      v_cod_modulo,
                                      p_cod_modalidad,
                                      p_cod_moneda,
                                      null),0) then
            null;
           else
            INSERT INTO pr_sol_cargos_tmp
              (nro_solicitud,
               cod_transaccion,
               val_tasa,
               monto,
               cod_tasa,
               cod_ent_seguro,
               cod_moneda,
               mto_mon_prestamo)
            VALUES
              (v_nro_solicitud,
               v_cod_transaccion,
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
      v_mto_seguro        number(18,2) := 0;
      --DA-887 cuotas iguales
      v_int_per_gracia    number(18,2):= 0;
      v_dia_cal_frances   number;

    BEGIN
      --- Veo el tipo de redondeo de los calculos ------------------------------------------
      ww_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                                         V_cod_modulo,
                                         p_cod_modalidad,
                                         p_cod_moneda,
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
      /*if v_per_interes = 30 and v_ven_fijo = 'S' then
        v_dias := 30.416666666666666666666666666667;
      else
        v_dias := v_per_interes;
      end if;*/
      v_dia_cal_frances := 30.416666666666666666666666666667;
      LOOP
        v_fec_ven_anterior := v_fec_inicio;
        ww_veces           := NVL(ww_veces, 0) + 1;

        v_dias :=  p_fec_pri_Vencimiento - v_fec_inicio;

        --- calculo del valor del metodo frances -----------------------------
        IF (power((1 + (ww_tasadiv * v_dias)), (p_can_cuotas - ww_ctrefue)) - 1) > 0 THEN
          /*ww_frances := ((NVL(nvl(v_tot_prestamo, p_mto_solicitado), 0) -
                        NVL(ww_ttrefue, 0)) * ww_tasadiv * v_dias) /
                        (power((1 + (ww_tasadiv * v_dias)),
                               (p_can_cuotas - ww_ctrefue)) - 1);*/

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
          v_val_cuota := fup_obt_val_cuota(p_cod_modalidad,
                                           p_cod_moneda,
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
        DELETE FROM pr_sol_cuotas_tmp WHERE nro_solicitud = v_nro_solicitud;

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

            /*v_int_per_gracia :=ROUND((ww_vlsalan * ww_tasadiv * (v_dias - 30)),--V_DIA_INTERES),
                                   ww_redondeo);*/
            v_int_per_gracia :=ROUND((ww_vlsalan * ww_tasadiv * (v_dias - to_char(last_day(p_fec_pri_vencimiento),'dd'))),--V_DIA_INTERES),
                                   ww_redondeo);
            v_int_per_gracia := round(v_int_per_gracia/p_can_cuotas,ww_redondeo);

            /*V_VAL_INTERES := ROUND((ww_vlsalan * ww_tasadiv * (v_dias - 30)),--V_DIA_INTERES),
                                   ww_redondeo);*/

             --calcula la porci??e interes solo por 30 dias
            V_VAL_INTERES := ROUND((ww_vlsalan * ww_tasadiv * to_char(last_day(p_fec_pri_vencimiento),'dd')),--V_DIA_INTERES),
                                   ww_redondeo);

            --debe sumar el v_int_per_gracia para el monto final de todas las cuotas
            v_val_cuota   := null;
          ELSE
            /*if fug_obt_tip_entidad != 'F' then
              V_DIA_PERIODO := V_FEC_VTO_HABIL - v_Fec_ven_anterior;
              V_DIA_INTERES := V_FEC_VTO_HABIL - v_Fec_ven_anterior;
              V_VAL_INTERES := ROUND((ww_vlsalan * ww_tasadiv *
                                     v_dias),--v_dia_interes),
                                     ww_redondeo);
            else*/
              V_DIA_PERIODO :=  V_FEC_VTO_HABIL - v_Fec_ven_anterior;
              V_DIA_INTERES :=  V_FEC_VTO_HABIL - v_Fec_ven_anterior;
              V_VAL_INTERES := ROUND((ww_vlsalan * ww_tasadiv * V_DIA_INTERES),ww_redondeo);
              ---V_VAL_INTERES := ROUND((ww_vlsalan * ww_tasadiv * v_dias),
                     ---                ww_redondeo);
           --- end if;
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
              /*V_MTO_CAPITAL := ROUND((ww_frances *
                                     power((1 + (ww_tasadiv * v_dias)),
                                            (ww_nro - 1))),
                                     ww_redondeo);*/
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
          INSERT INTO pr_sol_cuotas_tmp
            (nro_solicitud,
             nro_cuota,
             fec_vencimiento,
             mto_capital,
             mto_interes,
             dia_periodo)
          VALUES
            (v_nro_solicitud,
             cuota,
             v_fec_vto_habil,
             nvl(v_mto_capital, 0),
             nvl(v_val_interes, 0)+ nvl(v_int_per_gracia,0),
             v_dia_periodo);

        END LOOP;

        IF abs(nvl(ww_refreal, 0) - nvl(ww_ttrefue, 0)) < 10 OR
           ww_veces > 12 OR p_tip_monto = 'N' THEN
          EXIT;
        END IF;

      END LOOP;

      ww_dfcuota := nvl(V_TOT_PRESTAMO, 0) - NVL(ww_ttcapit, 0);
      IF ww_dfcuota <> 0 THEN
        --V_MTO_CAPITAL := V_MTO_CAPITAL + ww_dfcuota;
        IF NVL(V_VAL_INTERES, 0) >= ww_dfcuota and abs(ww_dfcuota) <= 1 THEN
          /* solo se ajusta si existe interes*/
          V_VAL_INTERES := NVL(V_VAL_INTERES, 0) - ww_dfcuota;
          V_MTO_INTERES := V_MTO_INTERES - ww_dfcuota;
        ELSE
          null;
          if ww_dfcuota < 0 then
            V_MTO_CAPITAL := V_MTO_CAPITAL + ww_dfcuota;
            --V_VAL_INTERES := NVL(V_VAL_INTERES, 0) - ww_dfcuota;
            --V_MTO_INTERES := V_MTO_INTERES - ww_dfcuota;
          else
            V_MTO_CAPITAL := V_MTO_CAPITAL + ww_dfcuota;
            --V_VAL_INTERES := NVL(V_VAL_INTERES, 0) + ww_dfcuota;
            --V_MTO_INTERES := V_MTO_INTERES + ww_dfcuota;
          end if;
          V_TTCUOTA := NVL(V_MTO_CAPITAL, 0) + NVL(V_VAL_INTERES, 0) + nvl(v_int_per_gracia,0);
        END IF;
        -- Actualizo la ultima cuota
        UPDATE pr_sol_cuotas_tmp
           SET mto_capital = nvl(v_mto_capital, 0),
               mto_interes = nvl(v_val_interes, 0) + nvl(v_int_per_gracia,0)
         WHERE nro_solicitud = v_nro_solicitud
           AND nro_cuota = p_can_cuotas; -- ultima cuota
      END IF;
      -- vencimiento final del prestamo es igual al de la ult.cuota--
      UPDATE pr_solicitudes_tmp
         SET tot_interes = v_mto_interes
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
                               p_dias      IN NUMBER)
      RETURN NUMBER IS
      v_mto_seguro NUMBER := 0;

    BEGIN
      IF fug_obt_parentes(p_cod_ente,'COD_TAS_SEG_DESEMPLEO') = p_cod_tasa THEN
        v_mto_seguro := round((p_monto * p_val_tasa / 100) * p_dia_plazo / p_dias,-3);

      ELSIF fug_obt_parentes(p_cod_ente,'COD_TAS_SEG_CANCELACION') = p_cod_tasa THEN
        v_mto_seguro := (p_monto * p_val_tasa / 100) * p_dia_plazo / 365;

      END IF;

      RETURN v_mto_seguro;

    END;

    -- Calculo de los cargos ----------------------------------------------------
    PROCEDURE pr_cal_cargos IS
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
      v_obligatorio  varchar2(2);
      v_afecta varchar2(5);
      v_sal_minimo  number(18,2) := fuh_obt_sal_minimo;
      v_can_salario number := nvl(fug_obt_pardinamico('PRE_CAN_SAL_MIN_COMISION'),5);
      v_can_jor_minimo number := fug_obt_pardinamico('PRE_CAN_JOR_MINIMOS');
      v_plazo number;
      -----------------DA 7202
      v_mto_max_gas_adm number := fug_obt_pardinamico('MTO_MAX_COM_ADM',null,null, nvl(p_cod_moneda, pag_gen.FU_OBT_MON_LOCAL),null);
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
          FROM pr_sol_cargos_tmp
         WHERE nro_solicitud = v_nro_solicitud
           FOR UPDATE OF monto
         ORDER BY decode(cod_transaccion, 709, 1, 710, 2, cod_transaccion);
    BEGIN
      --- Calculo cada uno de los cargos en la moneda del cargo y en la de la simulacion ---
      --- cero los totales de cargo de tipo valor y el total general de cargos -------------
      v_ttvalor        := 0;
      v_mto_cargo      := 0;
      v_cod_tra_ajuste := NULL;
      ----DA 7202 
      v_mto_gas_admistrativo := pag_gen.fu_con_mon_a_moneda(pag_gen.fu_obt_mon_local, nvl(p_cod_moneda, pag_gen.FU_OBT_MON_LOCAL), fug_obt_pardinamico('MTO_TAE', 6));
      
      FOR cc IN cargos LOOP
        v_mto_equivalente := 0;
        -- para realizar ajustes si es necesario----------
        IF v_cod_tra_ajuste IS NULL THEN
          v_cod_tra_ajuste := cc.cod_transaccion;
        END IF;
        -- obtengo los datos de la tasa-----------------
      IF cc.cod_transaccion in(737,1271) AND p_tip_persona = 'J' and nvl(fug_obt_pardinamico('PRE_SEG_DIF_JURIDICAS',v_cod_modulo, p_cod_modalidad,p_cod_moneda), 'N')='S' THEN
    --Traer valor de la tasa del seguro
       v_cod_Tasa  := fug_obt_parentes( cc.cod_ent_seguro,'COD_TAS_JURIDICA');
       if  v_cod_tasa is not null then
         SELECT initcap(TR.DESCRIPCION),TA.COD_TASA,TA.APLICAR,TA.TIP_VALOR,TA.TIPO, DT.OBLIGATORIO, TR.AFECTA
          INTO v_des_transaccion,v_cod_tas_cargo,v_aplicar,v_tpvlpor,v_tpdetas,v_obligatorio,v_afecta
          FROM GE_TRANSACCIONES_DET DT, GE_TRANSACCIONES TR, GE_TASAS TA
         WHERE TR.COD_MODULO = v_cod_modulo
           AND TR.COD_MODALIDAD = p_cod_modalidad
           AND TR.COD_TRANSACCION = cc.cod_transaccion
           AND TR.TIPO = 'D'
           AND v_cod_Tasa = TA.COD_TASA
           AND DT.COD_MODULO = v_cod_modulo
           AND DT.COD_MODALIDAD = p_cod_modalidad
           AND DT.COD_TRANSACCION = 358 /* transaccion de desembolso de prestamos */
           AND DT.COD_MOD_HIJO = TR.COD_MODULO
           AND DT.COD_MAD_HIJO = TR.COD_MODALIDAD
           AND DT.COD_TRA_HIJO = TR.COD_TRANSACCION;
       else
          g_cod_error := '030';
          g_lugar     := 'Busca datos tasa Per.Juridica';
          g_msj_error := 'No se encuentra definida la tasa para Seguro de Personas Juridicas. ' || SQLERRM;
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
            IF cc.cod_ent_seguro IS NOT NULL and cc.cod_transaccion in (1270,1271) THEN
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
                 v_tas_seguro := cc.val_tasa;
                 v_mto_equivalente := round(v_mto_tot_seguro,v_redondeo);
              else
                   v_mto_equivalente := round(fu_cal_mto_seguro(cc.cod_tasa,
                                                           cc.cod_ent_seguro,
                                                           v_mto_interes,
                                                           cc.val_tasa,
                                                           v_dia_plazo,
                                                           v_dias),v_redondeo);
              end if;
             ELSE
               v_mto_equivalente := round(v_mto_interes * cc.val_tasa / 100,
                                       v_redondeo);
             END IF;
          END IF;
          IF v_aplicar IN ('CA', 'CI', 'PC', 'CP', 'PT', 'TP') THEN
            -- puede ser un par_ente con el codigo de ente y transaccion
            IF cc.cod_ent_seguro IS NOT NULL and cc.cod_transaccion in (1270,1271) THEN
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
                 v_tas_seguro := cc.val_tasa;
                 v_mto_equivalente := round(v_mto_tot_seguro,v_redondeo);
              else
                   v_mto_equivalente := round(fu_cal_mto_seguro(cc.cod_tasa,
                                                           cc.cod_ent_seguro,
                                                           v_tot_prestamo,
                                                           cc.val_tasa,
                                                           v_dia_plazo,
                                                           v_dias),v_redondeo);
              end if;
             ELSE
               --- es aplicable al capital --------------------------------------------------
                if cc.cod_transaccion = 737 then
                   v_tas_seguro := cc.val_tasa;
                   v_mto_equivalente := round(v_mto_tot_seguro,v_redondeo);
                else
                   v_mto_equivalente := nvl(v_mto_equivalente, 0) +
                                   round(v_tot_prestamo * cc.val_tasa / 100,
                                         v_redondeo);
                end if;
             END IF;
          END IF;

          IF v_aplicar = 'MO' THEN
             --- es aplicable al monto de la operacion -------------------------------------------
             v_plazo := round((v_dia_plazo / 30),0);
             IF cc.cod_ent_seguro IS NOT NULL and cc.cod_transaccion in (1270,1271) THEN
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
                 v_tas_seguro := cc.val_tasa;
                 v_mto_equivalente := round(v_mto_tot_seguro,v_redondeo);
              else
                 v_imp_cargo := 0;
                 v_imp_cargo :=   NVL(v_imp_cargo,0) + ROUND(p_mto_solicitado * v_plazo * cc.val_tasa / 100,v_redondeo);
                 v_mto_equivalente := v_imp_cargo;-- + ROUND(v_imp_cargo * 10/100,v_redondeo);
                   /*v_mto_equivalente := round(fu_cal_mto_seguro(cc.cod_tasa,
                                                           cc.cod_ent_seguro,
                                                           p_mto_solicitado,
                                                           cc.val_tasa,
                                                           v_dia_plazo,
                                                           v_dias),v_redondeo);*/
              end if;
             ELSE
               IF cc.cod_ent_seguro IS NOT NULL THEN
                 v_imp_cargo := 0;
                 v_imp_cargo :=   NVL(v_imp_cargo,0) + ROUND(p_mto_solicitado * v_plazo * cc.val_tasa / 100,v_redondeo);
                 v_mto_equivalente := v_imp_cargo;-- + ROUND(v_imp_cargo * 10/100,v_redondeo);
               ELSE
                 v_imp_cargo := 0;
                 v_imp_cargo :=   NVL(v_imp_cargo,0) + ROUND(p_mto_solicitado * cc.val_tasa / 100,v_redondeo);
                 v_mto_equivalente := v_imp_cargo;-- + ROUND(v_imp_cargo * 10/100,v_redondeo);
               END IF;
             END IF;
          END IF;

          IF cc.cod_transaccion in(737,1271) THEN
             v_tas_seguro := cc.val_tasa;
          END IF;
          if cc.cod_transaccion in(1) and  (p_mto_solicitado <= v_sal_minimo*NVL(v_can_salario,0))then
               v_jor_minimo:= round(v_sal_minimo/26 * v_can_jor_minimo,0);
             if v_mto_equivalente > v_jor_minimo  then
               v_imp_cargo := 0;
               v_imp_cargo :=   v_jor_minimo;
               v_mto_equivalente := v_imp_cargo;-- + ROUND(v_imp_cargo * 10/100,v_redondeo);
             end if;
          elsif cc.cod_transaccion = nvl(fug_obt_pardinamico('PRE_TRA_MTO_CONSOLIDADO',
                                      v_cod_modulo,
                                      p_cod_modalidad,
                                      p_cod_moneda),0) then
               v_imp_cargo := 0;
               v_imp_cargo :=  p_mto_consolidado;
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
          if cc.cod_transaccion in(1) and  (p_mto_solicitado <= v_sal_minimo*NVL(v_can_salario,0))then
               v_jor_minimo:= round(v_sal_minimo/26 * v_can_jor_minimo,0);
             if v_mto_equivalente > v_jor_minimo  then
                v_mto_equivalente := v_jor_minimo;
             end if;
          elsif cc.cod_transaccion = nvl(fug_obt_pardinamico('PRE_TRA_MTO_CONSOLIDADO',
                                      v_cod_modulo,
                                      p_cod_modalidad,
                                      p_cod_moneda),0) then
            v_imp_cargo := 0;
            v_imp_cargo :=  p_mto_consolidado;
            v_mto_equivalente := p_mto_consolidado; --v_imp_cargo + ROUND(v_imp_cargo * 10/100,v_redondeo);
          end if;
        ELSIF v_tpvlpor = 'V' THEN
          --- es un monto valor -----------------------------------------------------------

          v_mto_equivalente := cc.monto;

        if cc.cod_transaccion in(1) and  (p_mto_solicitado <= v_sal_minimo*NVL(v_can_salario,0))then
               v_jor_minimo:= round(v_sal_minimo/26 * v_can_jor_minimo,0);
             if v_mto_equivalente > v_jor_minimo  then
                v_mto_equivalente := v_jor_minimo;
             end if;
        elsif cc.cod_transaccion = nvl(fug_obt_pardinamico('PRE_TRA_MTO_CONSOLIDADO',
                                                           v_cod_modulo,
                                                           p_cod_modalidad,
                                                           p_cod_moneda),0) then
               v_imp_cargo := 0;
               v_imp_cargo :=  p_mto_consolidado;
               v_mto_equivalente := p_mto_consolidado; --v_imp_cargo + ROUND(v_imp_cargo * 10/100,v_redondeo);
        end if;


          v_ttvalor         := nvl(v_ttvalor, 0) +
                               nvl(v_mto_equivalente, 0);
       ELSIF v_tpvlpor = 'T' THEN
        v_plazo := round((v_dia_plazo / 30), 0);
        v_val_tas_cargo := fu_obt_valor_de_tasa_variable(cc.cod_tasa,
                                                         nvl(v_tot_prestamo, p_mto_solicitado),
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
        ----Desde aca DA 7202, para que no sea muy alto el valor del cargo, copiado de pr_sim_pre_consumo
        IF v_mto_max_gas_adm > 0 THEN
          IF nvl(v_tot_prestamo, p_mto_solicitado) <= v_mto_gas_admistrativo THEN
             IF v_mto_equivalente > v_mto_max_gas_adm THEN
                v_mto_equivalente := v_mto_max_gas_adm;
             END IF;
          END IF;
        END IF;       
        --------------------------------------------------------------------------------
        END IF;
        if cc.cod_transaccion = nvl(fug_obt_pardinamico('PRE_TRA_MTO_CONSOLIDADO',
                                                           v_cod_modulo,
                                                           p_cod_modalidad,
                                                           p_cod_moneda),0) then
               v_imp_cargo := 0;
               v_imp_cargo :=  p_mto_consolidado;
               v_mto_equivalente := p_mto_consolidado; --v_imp_cargo + ROUND(v_imp_cargo * 10/100,v_redondeo);
        end if;

        if cc.cod_transaccion = nvl(fug_obt_pardinamico('PRE_TRA_MTO_CONSOLIDADO',
                                                           v_cod_modulo,
                                                           p_cod_modalidad,
                                                           p_cod_moneda),0) then
        v_monto := p_mto_consolidado;
        else
        v_monto := NULL;
        --- Acumular el total de cargos (Si el tipo es Valor viene directamente aqui -------
        v_mto_cargo := nvl(v_mto_cargo, 0) + nvl(v_mto_equivalente, 0);
        ------------------------------------------------------------------------------------
        end if;

        IF v_tpvlpor IN ('I', 'P') THEN
          /* solo si es porcentaje */
          IF cc.cod_moneda = p_cod_moneda THEN
            -- moneda del cargo es igual a la moneda de la simulacion ----------------------
             v_monto := v_mto_equivalente;
          ELSE
            -- monedas diferentes, se divide por la cotiz. de la moneda de la simulacion ---
             v_monto := round(v_mto_equivalente * v_cotizacion, v_redondeo);
          END IF;
        END IF;
        UPDATE pr_sol_cargos_tmp
           SET mto_mon_prestamo = nvl(v_mto_equivalente, 0),
               monto            = nvl(v_monto, monto)
         WHERE CURRENT OF cargos;
      END LOOP;
      IF v_mto_cargo >= v_tot_prestamo THEN
        g_cod_error := '017';
        g_lugar     := 'Valida Sumatoria de Cargos';
        g_msj_error := 'Total de Cargos ' || v_mto_cargo ||
                       ' es superior al Total del Prestamo ' || v_tot_prestamo;
      ELSE
        IF p_tip_monto = 'N' AND v_tot_prestamo <> p_mto_solicitado THEN
          --- ya estoy en el ultimo calculo de cargos netos, veo si hay ajuste --------
          /*IF nvl(v_tot_prestamo, 0) - nvl(v_mto_cargo, 0) <>
             p_mto_solicitado THEN
            -- es necesario un ajuste en el cargo del impuesto o primer cargo      ---
            ww_dfcargos       := p_mto_solicitado - (nvl(v_tot_prestamo, 0) -
                                 nvl(v_mto_cargo, 0));
            v_mto_cargo       := nvl(v_mto_cargo, 0) - ww_dfcargos;
            UPDATE pr_sol_cargos_tmp
               SET mto_mon_prestamo = nvl(mto_mon_prestamo, 0) -
                                      nvl(ww_dfcargos, 0),
                   monto            = decode(cod_moneda,
                                             p_cod_moneda,
                                             nvl(mto_mon_prestamo, 0) -
                                             nvl(ww_dfcargos, 0),
                                             decode(cod_moneda,
                                                    v_mon_local,
                                                    round(((nvl(mto_mon_prestamo,
                                                                0) -
                                                          nvl(ww_dfcargos, 0)) *
                                                          v_cotizacion),
                                                          v_redondeo),
                                                    round(((nvl(mto_mon_prestamo,
                                                                0) -
                                                          nvl(ww_dfcargos, 0)) *
                                                          v_cotizacion),
                                                          v_redondeo)))
             WHERE nro_solicitud = v_nro_solicitud
               AND cod_transaccion = v_cod_tra_ajuste;
          END IF;*/ null;
        END IF;
      END IF;
      -- actualizo el total de cargos de  la solicitud
      UPDATE pr_solicitudes_tmp
         SET tot_cargos = v_mto_cargo
       WHERE nro_solicitud = v_nro_solicitud;
    EXCEPTION
      WHEN OTHERS THEN
        g_cod_error := '018';
        g_lugar     := 'Valida Calculo Cargos';
        g_msj_error := 'Error al calcular cargos ' || SQLERRM;
    END;

    FUNCTION fu_obt_dat_simulacion(p_nro_solicitud in number) return typ_consolicitud
      IS
      v_can_detalles   NUMBER(10);
      datosSolicitud   typ_conSolicitud     := typ_conSolicitud();

      CURSOR sim IS
        SELECT *
          FROM pr_solicitudes_tmp a
         WHERE a.nro_solicitud = p_nro_solicitud;

    BEGIN
      --v_can_detalles := 0;
      FOR a IN sim LOOP
        datosSolicitud.codigoerror           := '000';
        datosSolicitud.nombrerespuesta       := 'Sin Error';
        datosSolicitud.descripcionrespuesta  := 'Proceso culminado con exito';
        datosSolicitud.nrosolicitud          := a.nro_solicitud;
        datosSolicitud.descripcion           := a.descripcion;
        datosSolicitud.monto                 := a.monto;
        datosSolicitud.diaplazo              := a.dia_plazo;
        datosSolicitud.fecvencimiento        := a.fec_vencimiento;
        datosSolicitud.codpersona            := a.cod_persona;
        datosSolicitud.fecinicio             := a.fec_inicio;
        datosSolicitud.totprestamo           := a.tot_prestamo;
        datosSolicitud.codmodulo             := a.cod_modulo;
        datosSolicitud.codmodalidad          := a.cod_modalidad;
        datosSolicitud.desmodalidad          := fug_obt_des_modal(a.cod_modulo,a.cod_modalidad);
        datosSolicitud.codmoneda             := a.cod_moneda;
        datosSolicitud.codoficina            := a.cod_oficina;
        datosSolicitud.fecprivencimiento     := a.fec_pri_vencimiento;
        datosSolicitud.valtasa               := a.val_tasa;
        datosSolicitud.cancuotas             := a.can_cuotas;
        datosSolicitud.totcargos             := a.tot_cargos;
        datosSolicitud.totinteres            := a.tot_interes;
        --datosSolicitud.listaconcargo       := fu_obt_dat_sim_cargos(p_nro_solicitud);
        --datosSolicitud.typ_consolicitud    := null;
      END LOOP;
        --listaCheques.extend;
        --v_can_detalles := v_can_detalles + 1;
        --listaCheques(listaCheques.count) := detalleCheque;

    return datosSolicitud;

  end;

    FUNCTION fu_obt_dat_sim_cargos(p_nro_solicitud in number) return typ_listaconcargo
      IS
      datosCargo       typ_conCargo         := typ_conCargo();
      datosSolCargos   typ_listaConCargo    := typ_listaConCargo();
      v_can_cargos     number               := 0;
      CURSOR sim_car IS
        SELECT *
          FROM pr_sol_cargos_tmp a
         WHERE a.nro_solicitud = p_nro_solicitud;
    BEGIN
      FOR b IN sim_car LOOP
        datosCargo.nroSolicitud   := b.nro_solicitud;
        datosCargo.codTransaccion := b.cod_transaccion;
        datosCargo.desTransaccion := fug_obt_des_transaccion(6,p_cod_modalidad,b.cod_transaccion);
        datosCargo.valTasa        := nvl(b.val_tasa,0);
        datosCargo.monto          := nvl(b.monto,0);
        datosCargo.codTasa        := b.cod_tasa;
        datosCargo.codEntSeguro   := b.cod_ent_seguro;
        datosCargo.codMoneda      := b.cod_moneda;
        datosCargo.mtoMonPrestamo := b.mto_mon_prestamo;
        --v_det_cargos.typ_concargo
        datosSolCargos.extend;
        v_can_cargos := v_can_cargos + 1;
        datosSolCargos(datosSolCargos.count):= datosCargo;
      END LOOP;
    return datosSolCargos;
  end;

    FUNCTION fu_obt_dat_sim_cuotas(p_nro_solicitud in number) return typ_listaconcuota
      IS
      datosCuota       typ_conCuota         := typ_conCuota();
      datosSolCuotas   typ_listaConCuota    := typ_listaConCuota();
      v_can_cuotas     number               := 0;
      CURSOR sim_cuo IS
        SELECT *
          FROM pr_sol_cuotas_tmp a
         WHERE a.nro_solicitud = p_nro_solicitud;
    BEGIN
      FOR c IN sim_cuo LOOP
        datosCuota.nroSolicitud     := c.nro_solicitud;
        datosCuota.nroCuota         := c.nro_cuota;
        datosCuota.fecVencimiento   := c.fec_vencimiento;
        datosCuota.mtoCapital       := c.mto_capital;
        datosCuota.mtoInteres       := c.mto_interes;
        datosCuota.diaPeriodo       := c.dia_periodo;
        --v_det_cargos.typ_concargo
        datosSolCuotas.extend;
        v_can_cuotas := v_can_cuotas + 1;
        datosSolCuotas(datosSolCuotas.count):= datosCuota;
      END LOOP;
    return datosSolCuotas;
  end;
  BEGIN
    v_max_tasa  := 'N';
    v_max_gastos:= 'N';
    v_tasa_back := 0;
    v_bandera   := null;
    v_tasa_mod  := null;
    g_msj_error := ' ';
    g_cod_error := 0;
    --- Veo el tipo de redondeo de los calculos ------------------------------------------
    v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                                      6,
                                      p_cod_modalidad,
                                      p_cod_moneda);
    -- Valido el codigo de la modalidad que recibo----------------------------
    if nvl(g_cod_error,'000') = '000' then
      pr_val_cod_modalidad;
    end if;

    -- valido la moneda-------------------------------------------------------
    if nvl(g_cod_error,'000') = '000' then
      pr_val_cod_moneda;
    end if;

    -- valido el monto -------------------------------------------------------
    IF nvl(g_cod_error,'000') = '000' and nvl(p_mto_solicitado, 0) <= 0 THEN
      g_cod_error := '005';
      g_lugar     := 'Valida Monto Ingresado';
      g_msj_error := 'Ingrese Monto del Credito';
    END IF;

    v_tot_prestamo := p_mto_solicitado;

    -- valido el tipo de monto -----------------------------------------------
    IF nvl(g_cod_error,'000') = '000' and nvl(p_tip_monto, 'X') NOT IN ('B', 'N') THEN
      g_cod_error := '006';
      g_lugar     := 'Valida Tipo Monto';
      g_msj_error := 'Tipo de Monto debe ser B-Bruto o N-Neto';
    END IF;

    -- valido la cantidad de cuotas ------------------------------------------
    IF nvl(g_cod_error,'000') = '000' and nvl(p_can_cuotas, 0) < 1 THEN
      g_cod_error := '007';
      g_lugar     := 'Valida Cantidad Cuotas';
      g_msj_error := 'Ingrese la cantidad de cuotas';
    END IF;
  ----desde aqui

  V_CAN_DIA_PRI_VCTO :=  fug_obt_pardinamico('CAN_DIA_PRI_VCTO',
                                 6,
                                 p_cod_modalidad,
                                 p_cod_moneda,
                                 v_cod_oficina);
  ---
  IF nvl(g_cod_error,'000') = '000' and p_fec_pri_vencimiento IS NULL THEN
      g_cod_error := '008';
      g_lugar     := 'Valida Primer vencimiento';
      g_msj_error := 'Ingrese Primer Vencimiento del Prestamo.';
  END IF;
    -- Valido la fecha del primer vencimiento --------------------------------
  IF nvl(g_cod_error,'000') = '000' and p_fec_pri_vencimiento <= v_fec_actual AND p_cod_modalidad <> 660 THEN
      g_cod_error := '009';
      g_lugar     := 'Valida Primer vencimiento';
      g_msj_error := 'Primer Vencimiento debe ser posterior a la fecha de Hoy';
   END IF;

  -- Controla los dias del primer vencimiento...
  IF nvl(g_cod_error,'000') = '000' and ((p_fec_pri_vencimiento - v_fec_actual) > v_can_dia_pri_vcto) THEN
      g_cod_error := '010';
      g_lugar     := 'Valida Primer vencimiento';
      g_msj_error := 'Primer Vencimiento no debe ser posterior a los '||v_can_dia_pri_vcto||' dias.';
  END IF;
  IF nvl(g_cod_error,'000') = '000' and nvl(fug_obt_pardinamico('PRE_MOD_AFD',6, p_cod_modalidad,p_cod_moneda), 'N')= 'S'then
    pp_val_dias_gracia;
  end if;


    ---hasta aqui

    -- valido el tipo de persona  --------------------------------------------
    IF nvl(g_cod_error,'000') = '000' and p_tip_persona is null THEN
      g_cod_error := '009';
      g_lugar     := 'Valida Tipo Persona';
      g_msj_error := 'Ingrese el tipo de persona';
    END IF;
    -- valido el tipo de persona  --------------------------------------------
    IF nvl(g_cod_error,'000') = '000' and p_tip_persona is not null
      and p_tip_persona not in ('F','J') THEN
      g_cod_error := '010';
      g_lugar     := 'Valida Tipo Persona';
      g_msj_error := 'Valor incorrecto. (Tipo F-Fisica/ J-Juridica)';
    END IF;

    v_dia_plazo   := add_months(p_fec_pri_vencimiento, p_can_cuotas - 1) -
                     v_fec_inicio;

    v_per_capital := 30;

    -- Valido la tasa de interes ---------------------------------------------
    IF nvl(g_cod_error,'000') = '000' then
      pr_val_tasa;
    end if;
    <<volver>>

    --- Recupero secuencia negativa para solicitud auxiliar
    IF nvl(g_cod_error,'000') = '000' then
     If nvl(v_max_tasa,'N') = 'N' then --DA 7202
        SELECT s_nro_sol_tmp.nextval INTO v_nro_solicitud FROM dual;
        -- inserto el registro en la tabla de solicitudes ------------------------
        BEGIN
          INSERT INTO pr_solicitudes_tmp
            (nro_solicitud,
             descripcion,
             monto,
             dia_plazo,
             fec_vencimiento,
             fec_inicio,
             tip_monto,
             tot_prestamo,
             cod_modulo,
             cod_modalidad,
             cod_moneda,
             cod_oficina,
             fec_pri_vencimiento,
             val_tasa,
             can_cuotas,
             tip_amortizacion)
          VALUES
            (v_nro_solicitud,
             'CONSUMO',
             p_mto_solicitado,
             v_dia_plazo,
             v_fec_inicio + v_dia_plazo,
             v_fec_inicio,
             p_tip_monto,
             v_tot_prestamo,
             v_cod_modulo,
             p_cod_modalidad,
             p_cod_moneda,
             v_cod_oficina,
             p_fec_pri_vencimiento,
             v_val_tasa,
             p_can_cuotas,
             v_tip_amortizacion /* price */);      
        EXCEPTION
          WHEN OTHERS THEN
            g_cod_error := '019';
            g_lugar     := 'Inserta Propuesta';
            g_msj_error := 'Error al insertar la propuesta. ' || SQLERRM;
        END;
      Else
         ---Si vmax_tasa = 'S' es decir que ya esta pasando 2 veces por aca, y debe actualizar
         BEGIN
           UPDATE pr_solicitudes_tmp p
              SET p.monto        = p_mto_solicitado,
                  p.tot_prestamo = v_tot_prestamo,
                  p.val_tasa     = v_val_tasa
            WHERE p.nro_solicitud = v_nro_solicitud;
         EXCEPTION
           WHEN OTHERS THEN
             g_cod_error := '035';
             g_lugar     := 'Error al actualizar';
             g_msj_error := 'Error al actualizar pr_solicitud_tmp' ||SQLERRM;
         END;
       End if;

    END IF;

    -- borro los cargos por si ya se genero, vuelve a pasar por aca DA - 7202 
    DELETE FROM pr_sol_cargos_tmp WHERE nro_solicitud = v_nro_solicitud;
    -- genero los cargos por defecto
    IF nvl(g_cod_error,'000') = '000' THEN
      pr_gen_cargos;
    END IF;

    -- borro las cuotas por si ya se genero, vuelve a pasar por aca DA - 7202
    DELETE FROM pr_sol_cuotas_tmp WHERE nro_solicitud = v_nro_solicitud;
    -- generar cuotas --------------------------------------------------------
    IF nvl(g_cod_error,'000') = '000' THEN
      pr_gen_cuotas('N');
    END IF;

    -- Calculo los cargos ----------------------------------------------------
    IF nvl(g_cod_error,'000') = '000' THEN
      pr_cal_cargos;
    END IF;

    -- verifico el tipo de prestamo
    IF nvl(g_cod_error,'000') = '000' THEN
    IF p_tip_monto = 'B' THEN
      v_tot_prestamo := p_mto_solicitado;
    ELSE
      select sum(nvl(a.monto,0))
        into v_mto_cargo
        from pr_sol_cargos_tmp a
       where a.nro_solicitud = v_nro_solicitud
         and a.cod_transaccion != nvl(fug_obt_pardinamico('PRE_TRA_MTO_CONSOLIDADO',
                                      v_cod_modulo,
                                      p_cod_modalidad,
                                      p_cod_moneda,
                                      null),0);

      --- monto ingresado es el neto -----------------------------------------------------
      v_por_ajuste := (p_mto_solicitado - (v_mto_cargo - v_ttvalor)) * 100 /
                      (p_mto_solicitado + v_ttvalor);

      --- calculo del nuevo capital (monto bruto -----------------------------------------
      v_tot_prestamo := round((p_mto_solicitado * 100 / v_por_ajuste),
                              v_redondeo);

      --- Vuelvo a generar las cuotas y calcular los cargos ------------------------------
      IF nvl(g_cod_error,'000') = '000' then
        pr_gen_cuotas('S');
      END IF;

      -- recalculo los cargos ------------------------------------------------------------
      IF nvl(g_cod_error,'000') = '000' then
        pr_cal_cargos;
      END IF;

      WHILE NVL(v_TOT_PRESTAMO,0)-NVL(v_MTO_CARGO,0) <> p_mto_solicitado LOOP
        v_por_ajuste := p_mto_solicitado - (NVL(v_TOT_PRESTAMO,0)-NVL(v_MTO_CARGO,0));
        if v_por_ajuste = 1 then --para evitar que se cuelgue el proceso
          v_TOT_PRESTAMO := p_mto_solicitado + NVL(v_MTO_CARGO,0);
        else
          v_TOT_PRESTAMO := v_TOT_PRESTAMO + v_POR_AJUSTE;

          --- Vuelvo a generar las cuotas y calcular los cargos ------------------------------
          IF nvl(g_cod_error,'000') = '000' then
            pr_gen_cuotas('S');
          END IF;

          -- recalculo los cargos ------------------------------------------------------------
          IF nvl(g_cod_error,'000') = '000' then
            pr_cal_cargos;
          END IF;

        end if;
      END LOOP;

      -- actualizo el total del prestamo -------------------------------------------------
      IF nvl(g_cod_error,'000') = '000' then
        UPDATE pr_solicitudes_tmp
           SET tot_prestamo = v_tot_prestamo
         WHERE nro_solicitud = v_nro_solicitud;
      END IF;
      
      --Maximizacion de tasa DA 7202 Carolina V.
      v_codi_tasa := 351; 
      begin
         pag_gen.pr_obt_val_tasa(v_cod_modulo, p_cod_modalidad, v_cod_oficina,
         null , p_cod_moneda, p_mto_solicitado, 'S', v_codi_tasa /*out*/, null ,v_fec_actual,          
         v_valor_tasa /*out*/, v_fec_vigencia/*out*/, v_tipo_valor /*out*/,v_tipo/*out*/, null); 
      exception 
        when others then
         v_max_tasa := 'X';
      End;
      If nvl(v_max_tasa,'N') <> 'X'   AND (p_mto_solicitado between pag_gen.FU_OBT_VAL_MINIMO and pag_gen.FU_OBT_VAL_MAXIMO ) 
      AND to_number(nvl(fug_obt_pardinamico('VAL_INI_AUMTASA',null,null, p_cod_moneda, null),0),'999G999D999999', 'NLS_NUMERIC_CHARACTERS='',.''') <> 0 then
         v_max_tasa := 'S';       
      else
         v_max_tasa := 'N';
      End if;
    
      If nvl(v_max_tasa,'X') = 'S'  then
         begin
           pap_sim.pr_obt_tas_tmp(v_nro_solicitud, null, v_tae, v_tan);
         exception
           when others then
             g_cod_error := '036';
             g_lugar     := 'Busca la TAE';
             g_msj_error := 'Error al buscar la TAE ' || sqlerrm;
             v_tas_efec  := 0;
         end;
         If  nvl(v_tas_efec, 0) <> 0 then 
           If nvl(v_tae,0) > nvl(v_tas_efec, 0) and nvl(v_tasa_back,0) > 0 then           
               v_val_tasa := nvl(v_tasa_back,0);                 
               v_valor_aum := round( (v_valor_aum / 2 ) , 3);	
               If( nvl(v_val_tasa + v_valor_aum,0) between nvl(v_tas_minima,0) and nvl(v_tas_maxima,0) ) then 	 	 
                 v_val_tasa := v_val_tasa + v_valor_aum;
                 v_bandera := 'N';
                 goto volver;
               End if;
           elsif nvl(v_tae,0) < nvl(v_tas_efec, 0) then
              IF nvl(v_bandera,'S') = 'S' then
                v_tasa_back := v_val_tasa;
                If( nvl(v_val_tasa + v_valor_aum,0) between nvl(v_tas_minima,0) and nvl(v_tas_maxima,0) ) then 	 
                  v_val_tasa := v_val_tasa + v_valor_aum;
                  goto volver;
                End if;
              end if;
           end if;
          end if;
        End if; -------  Max de tasa ---------
      End if;  --Fin de tipo de prestamo
    END IF;--Fin nvl(g_cod_error,'000') = '000' 
    
    IF nvl(g_cod_error,'000') = '000' then 
     pap_sim.pr_obt_tas_tmp(v_nro_solicitud, null, v_tae, v_tan);
      If nvl(v_tae,0) > nvl(v_tas_efec, 0)  Then
        g_cod_error := '052';
        g_lugar     := 'Supera TAE';
        g_msj_error := 'Valor obtenido :'||v_tae||' valor pizzarra:'||v_tas_efec;
      end if;           
    end if;      
    -- Obtengo datos de solicitud
    IF nvl(g_cod_error,'000') = '000' then
      v_consolicitud := fu_obt_dat_simulacion(v_nro_solicitud);
      v_consolcargos := fu_obt_dat_sim_cargos(v_nro_solicitud);
      v_consolcuotas := fu_obt_dat_sim_cuotas(v_nro_solicitud);
    else
      v_consolicitud.codigoerror          := g_cod_error;
      v_consolicitud.nombrerespuesta      := g_lugar;
      v_consolicitud.descripcionrespuesta := g_msj_error;
      v_consolicitud.nrosolicitud         := null;
      v_consolicitud.descripcion          := null;
      v_consolicitud.monto                := null;
      v_consolicitud.diaplazo             := null;
      v_consolicitud.fecvencimiento       := null;
      v_consolicitud.codpersona           := null;
      v_consolicitud.fecinicio            := null;
      v_consolicitud.totprestamo          := null;
      v_consolicitud.codmodulo            := null;
      v_consolicitud.codmodalidad         := null;
      v_consolicitud.codmoneda            := null;
      v_consolicitud.codoficina           := null;
      v_consolicitud.fecprivencimiento    := null;
      v_consolicitud.valtasa              := null;
      v_consolicitud.cancuotas            := null;
      --v_consolicitud.typ_consolicitud
    end if;

    p_solicitud := v_consolicitud;
    p_cargos    := v_consolcargos;
    p_cuotas    := v_consolcuotas;

  end;
  PROCEDURE pr_obt_tas_tmp
   (
      p_nro_solicitud IN pr_cta_prestamos.nro_solicitud%TYPE,
      p_nro_cuenta    IN pr_cta_prestamos.nro_cuenta%TYPE,
      p_val_tae       IN OUT NUMBER,
      p_val_tan       IN OUT NUMBER
   ) IS
      v_cta_recalendarizada VARCHAR2(1);
      v_tip_implementacion ge_par_generales.tip_implementacion%type := fug_obt_tip_implementacion;
      
      FUNCTION lf_plz_int_adelantado
      (
         p_nro_solicitud IN pr_cta_prestamos.nro_solicitud%TYPE,
         p_nro_cuenta     IN pr_cta_prestamos.nro_cuenta%TYPE
      ) RETURN NUMBER;
      
      /* Obtener gastos del prestamo. */
      PROCEDURE lp_obt_gas_prestamos
      (
         p_nro_solicitud       IN pr_solicitudes.nro_solicitud%TYPE,
         p_nro_cuenta          IN pr_cta_prestamos.nro_cuenta%TYPE,
         p_cod_moneda          IN ge_cuentas.cod_moneda%TYPE,
         p_mto_desembolso      IN pr_solicitudes.monto%TYPE,
         p_mto_car_imputable   IN OUT NUMBER,
         p_mto_car_noimputable IN OUT NUMBER
      );
      /* Obtener dias. */
      FUNCTION lf_obt_dias
      (
         p_nro_solicitud IN pr_cta_prestamos.nro_solicitud%TYPE,
         p_nro_cuota     IN pr_cuotas.nro_cuota%TYPE
      ) RETURN NUMBER;
      /* Obtener datos del prestamo. */
      PROCEDURE lp_obt_dat_prestamo
      (
         p_nro_solicitud    IN ge_cuentas.nro_cuenta%TYPE,
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
         p_tipo             IN OUT pr_solicitudes.tipo%type
      );
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
      v_numero            VARCHAR2(3000);
      v_plz_numero        VARCHAR2(3000);
      v_auxiliar          VARCHAR2(3000);
      v_plz_auxiliar      VARCHAR2(3000);
      v_mto_max_gastos    NUMBER;
      v_mto_lim_prestamo  NUMBER;
      v_dis_gasto         number;

      --- Cursor de cuotas
      CURSOR c_cuotas IS
         SELECT nro_cuota,
                nvl(cuo.mto_capital, 0) + nvl(cuo.mto_interes, 0) val_cuota,
                nvl(cuo.mto_capital, 0) mto_capital,
                nvl(cuo.mto_interes, 0) mto_interes,
                --nvl(val_int_adelantado, 0) mto_int_documentado,
                0 mto_int_documentado,
                trunc(cuo.fec_vencimiento/*fec_vto_habil*/ - v_fec_inicio) dias,
                dia_periodo,--dia_interes,
                trunc(cuo.fec_vencimiento) fec_vto_exacto,
                sol.cod_modalidad
           FROM pr_sol_cuotas_tmp cuo,
           pr_solicitudes_tmp sol
          WHERE cuo.nro_solicitud = p_nro_solicitud
            AND p_nro_cuenta IS NULL
            AND nro_cuota > 0
            and sol.nro_solicitud = cuo.nro_solicitud
         UNION ALL
         SELECT nro_cuota,
                nvl(mto_capital, 0) + nvl(mto_int_documentado, 0) + nvl(mto_interes, 0) val_cuota,
                nvl(mto_capital, 0) + nvl(mto_int_documentado, 0) mto_capital,
                nvl(mto_interes, 0) mto_interes,
                nvl(mto_int_documentado, 0) mto_int_documentado,
                trunc(fec_vencimiento - v_fec_inicio) dias,
                trunc(fec_vencimiento -
                      decode(nro_cuota, 1, v_fec_inicio,
                             pas_bcp.fu_obt_vto_ant_cuo(nro_cuenta, nro_cuota))) dia_interes,
                trunc(fec_vencimiento),
                null cod_modalidad
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
            SELECT nvl(avg(trunc(fec_vencimiento - v_fec_inicio)),0) dias
               into v_dia_plazo
               FROM pr_sol_cuotas_tmp
              WHERE nro_solicitud = p_nro_solicitud
                AND p_nro_cuenta IS NULL
                AND nro_cuota > 0;
          exception
            when no_data_found then
              return 0;
          end;
        elsif p_nro_cuenta is not null then
          begin
           SELECT nvl(avg(trunc(fec_vencimiento - v_fec_inicio)),0) dias
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
      PROCEDURE lp_obt_gas_prestamos
      (
         p_nro_solicitud       IN pr_solicitudes.nro_solicitud%TYPE,
         p_nro_cuenta          IN pr_cta_prestamos.nro_cuenta%TYPE,
         p_cod_moneda          IN ge_cuentas.cod_moneda%TYPE,
         p_mto_desembolso      IN pr_solicitudes.monto%TYPE,
         p_mto_car_imputable   IN OUT NUMBER,
         p_mto_car_noimputable IN OUT NUMBER
      ) IS

         v_fec_actual  DATE;
         v_par_car_tae VARCHAR2(30);
         --V_PAR_MIN_GAS VARCHAR2(30);
         v_gastos     NUMBER;
         v_gastos_imp NUMBER;

         v_mto_lim_prestamo NUMBER;
         v_mto_lim_cargo    NUMBER;
         v_mto_desembolso   NUMBER;
         v_redondeo         NUMBER := 0;
      BEGIN
         v_gastos      := 0;
         v_fec_actual  := pag_cal.fu_obt_fec_actual(4);
         v_par_car_tae := fug_obt_pardinamico('GRU_CAR_TAE');
         IF p_cod_moneda != pag_gen.fu_obt_mon_local THEN
            v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', NULL, NULL, p_cod_moneda);
         END IF;
         IF p_nro_solicitud IS NOT NULL THEN
            --- Obtiene los gastos que constituyen interes.
            SELECT SUM(decode(cod_tra_hijo, NULL, nvl(car.mto_mon_prestamo, 0),
                              round(nvl(car.mto_mon_prestamo, 0) * 100 /
                                     (100 +
                                      fug_obt_val_tasa(s.cod_modulo, s.cod_modalidad, s.cod_oficina,
                                                       NULL, s.cod_moneda, 0, 'N', NULL,
                                                       d.cod_tra_hijo, s.fec_inicio)), v_redondeo)))
              INTO v_gastos_imp
              FROM ge_transacciones_det d, ge_transacciones t, pr_sol_cargos_tmp car, pr_solicitudes_tmp s
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
              FROM pr_sol_cargos_tmp car
             WHERE car.nro_solicitud = p_nro_solicitud;

         ELSE
            v_gastos     := 0;
            v_gastos_imp := 0;
         END IF;
         ---
         p_mto_car_imputable   := nvl(v_gastos_imp, 0);
         p_mto_car_noimputable := nvl(v_gastos, 0);
         ---
         /* Debe hacer todas las comparaciones para verificar si esl gasto es imputable o no. */
         IF p_mto_car_imputable > 0 THEN
            -- Se convierte a la moneda el monto limite para considerar como gastos no imputables...
            v_mto_lim_prestamo := pag_gen.fu_con_mon_a_moneda(pag_gen.fu_obt_mon_local, p_cod_moneda,
                                                              fug_obt_pardinamico('MTO_TAE', 6));

            IF nvl(v_mto_lim_prestamo, 0) > 0 THEN
               -- Solo si el prestamo es menor o igual al limite puede que no sea imputable el cargo.
               IF p_mto_desembolso <= v_mto_lim_prestamo THEN
                  -- Si es menor o igual al limite (5.400.000) entonces verifica si el cargo no supera el 15%
                  IF p_mto_car_imputable > round(p_mto_desembolso * 0.15, v_redondeo) THEN
                     -- Si el cargo es mayor al 15% se debe considerar como imputable solo el 15%
                     p_mto_car_imputable := p_mto_car_imputable -
                                            round(p_mto_desembolso * 0.15, v_redondeo);
                  END IF;
                  -- Si sigue siendo mayor a cero.
                  IF p_mto_car_imputable > 0 THEN
                     -- Si el cargo es menor o igual al 15% debe verificar que no supere el
                     -- Se convierte a la moneda el monto limite para considerar como gastos no imputables...
                     v_mto_lim_cargo := pag_gen.fu_con_mon_a_moneda(pag_gen.fu_obt_mon_local,
                                                                    p_cod_moneda,
                                                                    fug_obt_pardinamico('IMP_MIN_GAS',
                                                                                         6));

                     v_mto_lim_cargo := round((v_mto_lim_cargo / 1.1),v_redondeo);
                     IF p_mto_car_imputable > v_mto_lim_cargo THEN
                        p_mto_car_imputable := p_mto_car_imputable - v_mto_lim_cargo;
                     ELSE
                        IF v_gastos_imp = p_mto_car_imputable THEN
                           -- Quiere decir que no se vio afectado por el 15%.
                           p_mto_car_imputable := 0;
                        END IF;
                     END IF;
                  END IF;
               END IF;
            END IF;
         END IF;
      END;
      /* Obtener dias. */
      FUNCTION lf_obt_dias
      (
         p_nro_solicitud IN pr_cta_prestamos.nro_solicitud%TYPE,
         p_nro_cuota     IN pr_cuotas.nro_cuota%TYPE
      ) RETURN NUMBER IS
         v_dias pr_sol_cuotas.dia_interes%TYPE;
      BEGIN
         SELECT dia_periodo
           INTO v_dias
           FROM pr_sol_cuotas_tmp
          WHERE nro_solicitud = p_nro_solicitud
            AND nro_cuota = p_nro_cuota;
         RETURN v_dias;
      EXCEPTION
         WHEN no_data_found THEN
            raise_application_error(-20000, 'Sol.Cuotas no registrada');
      END;
      /* Obtener datos del prestamo. */
      PROCEDURE lp_obt_dat_prestamo
      (
         p_nro_solicitud    IN ge_cuentas.nro_cuenta%TYPE,
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
         p_tipo             IN OUT pr_solicitudes.tipo%type
      ) IS
      BEGIN
         SELECT a.cod_moneda,
                a.tot_prestamo,
                decode(a.cod_modalidad,613,'A',62,'A',608,'A','V') tip_interes,
                a.fec_inicio,
                a.fec_vencimiento,
                a.val_tasa,
                a.tip_amortizacion,
                x.can_cuotas,
                case when a.tip_monto = 'N' then 
                  (a.monto + a.tot_cargos)
                else
                  (a.monto - a.tot_cargos - a.tot_interes) 
                end tot_desembolsar,
                a.nro_solicitud,
                case when a.cod_modalidad in (608) then 'D' else 'A' end tipo
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
           FROM pr_solicitudes_tmp a,
                (SELECT COUNT(*) can_cuotas
                   FROM pr_sol_cuotas_tmp
                  WHERE nro_cuota > 0
                    AND nro_solicitud = p_nro_solicitud) x
          WHERE a.nro_solicitud = p_nro_solicitud
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
                case when a.cod_modalidad in (608) then 'D' else 'A' end tipo
           FROM pr_solicitudes_tmp b, pr_cta_prestamos a
          WHERE a.nro_cuenta = p_nro_cuenta
            AND p_nro_solicitud IS NULL
            AND a.nro_solicitud = b.nro_solicitud(+);
      EXCEPTION
         WHEN no_data_found THEN
            raise_application_error(-20000, 'Solicitud ' || p_nro_solicitud || ' no registrado');
      END;
      PROCEDURE fu_obt_tir_adelantado
      (
         p_interes   IN NUMBER,
         p_cargo     IN NUMBER,
         p_saldo     IN NUMBER,
         p_nro_cuota IN NUMBER,
         p_cod_moneda IN VARCHAR2,
         p_tir       OUT NUMBER
      ) IS
         v_sal_minimo NUMBER;
         v_cargo      NUMBER;

      BEGIN
         SELECT PAG_GEN.FU_CON_MON_A_MONEDA(PAG_GEN.FU_OBT_MON_LOCAL,p_cod_moneda,sal_min_vigente) INTO v_sal_minimo FROM pr_parametros;
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
              FROM pr_solicitudes_tmp b, pr_cta_prestamos a
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
         v_nro_cuenta    := p_nro_cuenta;
      END IF;

      --- Obtener datos del prestamos
      lp_obt_dat_prestamo(v_nro_sol_prestamo, v_nro_cuenta, v_cod_moneda, v_mto_capital, v_tip_interes,
                          v_fec_inicio, v_fec_vencimiento, v_val_tas_pactada, v_tip_amortizacion,
                          v_can_cuotas, v_mto_desembolso, v_nro_solicitud, v_tipo);
      lp_obt_gas_prestamos(v_nro_sol_prestamo, v_nro_cuenta, v_cod_moneda, v_mto_desembolso,
                           v_gastos_imp, v_gastos_noi);
      v_sal_capital       := v_mto_capital;
      v_plazo             := v_fec_vencimiento - v_fec_inicio;
      v_fec_vto_cuota_ant := v_fec_inicio;
      v_sale              := 'N';
      v_redondeo          := 0;
      IF v_cod_moneda = pag_gen.fu_obt_mon_local THEN
         v_dif_permitida := 1000;
      ELSE
         v_dif_permitida := 10;
         v_redondeo      := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', NULL, NULL, v_cod_moneda);
      END IF;
      -- Obtiene el monto maximo de cobro de comision permitido fuera de TAE.
      v_mto_max_gastos   := NVL(fug_obt_pardinamico('MTO_MAX_COM_ADM', NULL, NULL, v_cod_moneda),0);
      v_mto_max_gastos   := (v_mto_max_gastos / 1.1);
      v_mto_lim_prestamo := pag_gen.fu_con_mon_a_moneda(pag_gen.fu_obt_mon_local, v_cod_moneda,
                                                              fug_obt_pardinamico('MTO_TAE', 6));
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
            v_numero := cuo.val_cuota;
            v_plz_numero := cuo.dias;

            IF v_tip_interes != 'A' OR (v_tip_interes = 'A' AND v_tipo <> 'D') THEN
               IF cuo.nro_cuota = 1 THEN
                  -- Verifica si es realmente price o no.
                  IF v_tip_amortizacion = 'P' THEN
                     -- Si es price, si los plazos son fijos debe calcular diferente.
                     IF p_nro_solicitud IS NOT NULL THEN
                        SELECT AVG(dia_periodo),
                               MIN(s.per_vto_capital),
                               AVG(nvl(mto_capital, 0) + nvl(c.mto_interes, 0) ) -
                               MIN(nvl(mto_capital, 0) + nvl(c.mto_interes, 0) ),
                               MIN(nvl(mto_capital, 0) + nvl(c.mto_interes, 0) )
                          INTO v_avg_dia, v_per_capital, v_dif_cuotas, v_min_cuota
                          FROM pr_sol_cuotas_tmp c, pr_solicitudes s
                         WHERE s.nro_solicitud = p_nro_solicitud
                           AND c.nro_solicitud = s.nro_solicitud
                           AND c.nro_cuota > 0;
                     ELSE
                        SELECT AVG(trunc(x.fec_vencimiento -
                                         pas_bcp.fu_obt_vto_ant_cuo(x.nro_cuenta, x.nro_cuota))),
                               MIN(c.per_vto_capital),
                               AVG(nvl(x.mto_capital, 0) + nvl(x.mto_interes, 0) +
                                   nvl(x.mto_int_documentado, 0)) -
                               MIN(nvl(x.mto_capital, 0) + nvl(x.mto_interes, 0) +
                                   nvl(x.mto_int_documentado, 0)),
                               MIN(nvl(x.mto_capital, 0) + nvl(x.mto_interes, 0) +
                                   nvl(x.mto_int_documentado, 0))
                          INTO v_avg_dia, v_per_capital, v_dif_cuotas, v_min_cuota
                          FROM pr_cuotas x, pr_cta_prestamos c
                         WHERE c.nro_cuenta = p_nro_cuenta
                           AND x.nro_cuenta = c.nro_cuenta
                           AND x.nro_cuota > 0;
                     END IF;
                     IF abs(v_avg_dia - v_per_capital) > 1 OR abs(v_dif_cuotas) > v_dif_permitida OR
                        v_can_cuotas = 1 THEN
                        -- Si la diferencia en dias entre el periodo de interes y el de capital
                        -- se considera que no es periodico por lo tanto no es price.
                        IF abs(cuo.dia_periodo - v_per_capital) > 2 OR
                           (abs(v_dif_cuotas) > v_dif_permitida and v_tip_amortizacion <> 'P') OR v_can_cuotas = 1 THEN
                           v_tip_amortizacion := 'F';
                        END IF;
                     END IF;
                     IF v_tip_implementacion = 2 AND v_tip_amortizacion = 'P' THEN
                        --- Verificar el importe de la primera cuota y del promedio de cuotas
                        BEGIN
                           IF p_nro_solicitud IS NOT NULL THEN
                              SELECT nvl(mto_capital, 0) + nvl(mto_interes, 0) 
                                INTO v_pri_cuota
                                FROM pr_sol_cuotas_tmp
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
               v_dias_cuota := nvl(v_dias_cuota, 0) + (cuo.fec_vto_exacto - v_fec_vto_cuota_ant);
               IF v_tip_implementacion = 3 THEN
                  -- FA.
                  v_mto_gasto := round(v_gastos_imp / v_can_cuotas, v_redondeo);
               ELSE
                  v_mto_gasto := round(v_gastos_imp * (nvl(cuo.mto_capital, 0) / v_mto_capital),
                                       v_redondeo);
               END IF;
               IF v_tip_interes != 'A' OR (v_tip_interes = 'A' AND v_tipo <> 'D')THEN
                 v_val_inicial := NVL(v_val_inicial,0) + cuo.mto_capital - cuo.mto_int_documentado - v_mto_gasto;
                 v_auxiliar := v_auxiliar || TRIM(to_char(cuo.val_cuota)) || '#';
                 v_plz_auxiliar := v_plz_auxiliar || round(cuo.dias/365,4) || '#';
               ELSE
                 IF nvl(v_gastos_imp,0) <> 0 AND nvl(v_gastos_imp,0) > nvl(v_mto_max_gastos,0)
                    AND NVL(v_mto_desembolso,0) <= NVL(v_mto_lim_prestamo,0) THEN
                    v_dis_gasto := (nvl(v_gastos_imp,0) - nvl(v_mto_max_gastos,0));
                    v_val_inicial := nvl(cuo.mto_capital,0) - ( cuo.mto_interes + cuo.mto_int_documentado) - ((nvl(v_dis_gasto,0) / v_can_cuotas));
                 ELSIF nvl(v_gastos_imp,0) <> 0 AND nvl(v_gastos_imp,0) > nvl(v_mto_max_gastos,0)
                    AND NVL(v_mto_desembolso,0) > NVL(v_mto_lim_prestamo,0) THEN
                    v_dis_gasto := (nvl(v_gastos_imp,0));
                    v_val_inicial := nvl(cuo.mto_capital,0) - ( cuo.mto_interes + cuo.mto_int_documentado) - ((nvl(v_dis_gasto,0) / v_can_cuotas));
                 ELSE
                    if nvl(v_gastos_imp,0) <> 0 then
                      v_dis_gasto := (nvl(v_gastos_imp,0));
                      v_val_inicial := nvl(cuo.mto_capital,0) - ( cuo.mto_interes + cuo.mto_int_documentado) - ((nvl(v_dis_gasto,0) / v_can_cuotas));
                    else
                      v_dis_gasto := (nvl(v_gastos_imp,0));
                      v_val_inicial := nvl(cuo.mto_capital,0) - ( cuo.mto_interes + cuo.mto_int_documentado);
                    end if;
                    If cuo.cod_modalidad in ('608','62','621') then
                       v_val_inicial := v_val_inicial + cuo.mto_interes;
                    end if;
                    
                 END IF;
                 --v_val_inicial := cuo.mto_capital - cuo.mto_int_documentado - v_mto_gasto;
                 v_auxiliar := TRIM(to_char(cuo.val_cuota)) || '#';
                 v_plz_auxiliar := round(cuo.dias,4);
               END IF;
               
               v_numero      := v_auxiliar;
               v_plz_numero  := v_plz_auxiliar;
               --v_dias        := cuo.dias;
               if v_tipo = 'D'  then
                 --v_dias := lf_plz_int_adelantado(p_nro_solicitud, p_nro_cuenta);
                 v_dias := cuo.dias;
               else
                 v_dias := cuo.dias;
               end if;
            END IF;
            --
            IF v_tip_interes != 'A' OR (v_tip_interes = 'A' AND v_tipo <> 'D')THEN
               v_dias := cuo.dia_periodo;
               IF v_tip_amortizacion = 'P' THEN
                  -- Si sigue siendo price.
                  -- Adiciona los gastos a la cuota 1
                  IF cuo.nro_cuota = 1 THEN
                     IF v_tip_implementacion = 2 THEN
                        v_val_inicial := v_sal_capital - (v_gastos_imp * 2);
                     ELSE
                        IF nvl(v_gastos_imp,0) <> 0 AND nvl(v_gastos_imp,0) > nvl(v_mto_max_gastos,0)
                           AND NVL(v_mto_desembolso,0) <= NVL(v_mto_lim_prestamo,0) THEN
                           v_val_inicial := v_sal_capital - (nvl(v_gastos_imp,0) /*- nvl(v_mto_max_gastos,0)*/);
                        ELSIF nvl(v_gastos_imp,0) <> 0 AND nvl(v_gastos_imp,0) > nvl(v_mto_max_gastos,0)
                           AND NVL(v_mto_desembolso,0) > NVL(v_mto_lim_prestamo,0) THEN
                           v_val_inicial := v_sal_capital - (nvl(v_gastos_imp,0));
                        ELSE
                           v_val_inicial := v_sal_capital - v_gastos_imp;
                        END IF;
                     END IF;
                     v_dias := v_per_capital;
                  END IF;
                  -- Debe cargar las cuotas en el auxiliar.
                  v_auxiliar := v_auxiliar || TRIM(to_char(cuo.mto_capital + cuo.mto_interes +
                                                           cuo.mto_int_documentado)) || '#';
                  v_plz_auxiliar := v_plz_auxiliar || round(cuo.dias/365,4) || '#';
               ELSE
                  -- Sino es price.
                  IF cuo.nro_cuota = 1 THEN
                     -- Adiciona los gastos a la cuota 1
                     IF nvl(v_gastos_imp,0) <> 0 AND nvl(v_gastos_imp,0) > nvl(v_mto_max_gastos,0)
                        AND NVL(v_mto_desembolso,0) <= NVL(v_mto_lim_prestamo,0) THEN
                        v_val_inicial := nvl(v_sal_capital,0) - (nvl(v_gastos_imp,0) /*- nvl(v_mto_max_gastos,0)*/);
                     ELSIF nvl(v_gastos_imp,0) <> 0 AND nvl(v_gastos_imp,0) > nvl(v_mto_max_gastos,0)
                        AND NVL(v_mto_desembolso,0) > NVL(v_mto_lim_prestamo,0) THEN
                        v_val_inicial := nvl(v_sal_capital,0) - (nvl(v_gastos_imp,0));
                     ELSE
                        v_val_inicial := nvl(v_sal_capital,0) - nvl(v_gastos_imp,0);
                     END IF;
                  ELSE
                     --v_val_inicial := v_sal_capital;
                     if v_tip_interes = 'A' and v_tipo = 'D' then
                       v_val_inicial := nvl(cuo.mto_capital,0) - ( cuo.mto_interes + cuo.mto_int_documentado) - ((nvl(v_dis_gasto,0) / v_can_cuotas));
                     end if;
                  END IF;
                  v_auxiliar := v_auxiliar ||  TRIM(to_char(cuo.mto_capital + cuo.mto_interes + cuo.mto_int_documentado)) || '#';
                  v_plz_auxiliar := v_plz_auxiliar || round(cuo.dias/365,4) || '#';
               END IF;
               v_numero := v_auxiliar;
               v_plz_numero := v_plz_auxiliar;
            END IF;
            --- Hace los calculos de TIR, TAN y TAE
            DECLARE
               v_tir     NUMBER;
               v_tan     NUMBER;
               v_tae     NUMBER;
               v_dias1   NUMBER(4);
               v_inicial NUMBER(18, 2);
               v_numero1 VARCHAR2(3000);
               v_numero2 VARCHAR2(3000);
            BEGIN
               v_dias1   := v_dias;
               v_numero1 := v_numero;
               v_numero2 := v_plz_numero;
               v_inicial := v_val_inicial;
               IF v_inicial > 0 THEN
                  IF v_tip_amortizacion = 'P' AND v_can_cuotas = cuo.nro_cuota THEN
                     -- Si es tipo price en la ultima cuota calcula el tir.
                     v_tan := round(pas_bcp.fu_obt_tir(v_inicial, v_can_cuotas, v_numero1),4);
                     v_tae := pas_bcp.fu_obt_tae(v_tan, v_dias);
                  ELSIF v_tip_amortizacion != 'P' THEN
                     if v_tip_interes = 'A' AND v_tipo <> 'D' then
                        v_dias := abs(cuo.fec_vto_exacto - v_fec_vto_cuota_ant);
                        fu_obt_tir_adelantado(cuo.mto_int_documentado,v_gastos_imp,v_sal_capital,cuo.nro_cuota,v_cod_moneda,v_tir);
                     else
                        if v_can_cuotas = cuo.nro_cuota and v_tipo <> 'D' then
                          v_tan := round(pas_bcp.fu_obt_val_tir(v_inicial, v_can_cuotas, v_numero1, v_numero2),4);
                        elsif v_tipo = 'D' then
                          v_tan := round(pas_bcp.fu_obt_tir_ade(v_inicial, 1, v_numero1, v_numero2),4); 
                        end if;
                     end if;
                     v_tae := pas_bcp.fu_obt_tae(v_tan, v_dias);
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
            IF v_tip_amortizacion = 'P' or (v_tip_amortizacion != 'P' and v_tip_interes <> 'A')  THEN
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
      IF v_tip_implementacion NOT IN (2, 3) AND p_val_tan < v_val_tas_pactada THEN
         p_val_tan := v_val_tas_pactada;
      END IF;
      
      p_val_tan := round(v_acum_tan, 2);
      p_val_tae := round(v_acum_tae, 2);
      IF v_tip_interes = 'A' AND v_tipo = 'D' THEN
        p_val_tan := round(v_acum_tan / v_contador, 2);
        v_dias := lf_plz_int_adelantado(p_nro_solicitud, p_nro_cuenta);
        --p_val_tae := round(pas_bcp.fu_obt_tae(p_val_tan, v_dias),2);
        p_val_tae := round(fug_obt_tae_ade(p_val_tan, v_dias),2);
      END IF;
      END IF;
   END;

end pap_sim;
/

