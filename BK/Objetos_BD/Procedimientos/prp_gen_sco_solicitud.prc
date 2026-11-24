CREATE OR REPLACE PROCEDURE IT.PRP_GEN_SCO_SOLICITUD
  (p_cod_persona         in varchar2,
   p_tip_monto           in varchar2 default 'N', -- B-BRUTO o N-NETO
   p_ind_val_scoring     in varchar2 default 'N', -- indica si se validará el scoring
   p_ant_nro_solicitud   in varchar2,    -- Nro de Solicitud "padre"
   p_nro_solicitud       in varchar2,    -- Nro de Solicitud a reutilizar (mto_reconducido)
   p_nvo_nro_solicitud   out varchar2,   -- Retorna el nro de solicitud creado
   p_sco_dic_final       out varchar2,   -- Retorna el resultado del scoring
   p_sco_error           out varchar2,   -- Retorna el error del scoring
   p_mto_reconducido     in out number ) is -- Retorna el monto reconducido.
-- SDHSCORM-1
--------------------- Variables del procedimiento -----------------------------
v_nmtrans           ge_transacciones.descripcion%type;
v_obligatorio       ge_transacciones_det.obligatorio%type;
v_afecta            ge_transacciones.afecta%type;
v_por_ori_fondo     pr_solicitudes.por_ori_fondo%type;
v_nro_cta_debito    pr_solicitudes.nro_cta_debito%type;
v_deb_automatico    pr_solicitudes.deb_automatico%type := 'N';
v_per_capital       pr_solicitudes.per_vto_capital%type;
v_tip_destino       pr_solicitudes.tip_destino%type;
v_cod_rol           ba_roles.cod_rol%TYPE;

v_ind_evaluacion    pr_solicitudes.ind_evaluacion%type := 'S';
v_cod_moneda        ba_monedas.cod_moneda%type := 'GS';
v_cotizacion        ge_cotizaciones.val_conversion%type := pag_gen.fu_obt_cotizacion(v_cod_moneda);

v_lugar             varchar2(200):= null;
v_descripcion       varchar2(100):= nvl(FUE_OBT_SIG_REFCODES('COD_DESTINO','29'), 'SCORING MULTIPRODUCTO');
v_mon_local         varchar2(3)  := pag_gen.fu_obt_mon_local;
v_tip_interes       varchar2(1)  := 'V';
v_tip_amortizacion  varchar2(1)  := 'P';
v_exo_impuestos     varchar2(1)  := 'N';
v_tipo              varchar2(1)  := 'A';
v_tot_prestamo      number(18,2) := 0;
v_mto_interes       number(18,2) := 0;
v_mto_cargo         number(18,2) := 0;
v_limite            number(6,2)  := 10;
v_per_vencimiento   number(4)    := 30;
v_cod_modulo        number(3)    := 6;
v_cod_sec_credito   number(3)    := 1;
v_cod_dep_parametro number(3)    := 3;
v_redondeo          number(2)    := 0;
v_red_mon_local     number(2)    := 0;
v_tip_documento     number(1)    := 2;
v_cod_departamento  number(3)    := null;
v_error             varchar2(4000);
v_cod_usu_promotor  varchar2(10);
v_cod_usu_oficial   varchar2(10);
v_cod_mon_cargo     varchar2(3);
v_aplicar           varchar2(3);
v_tpvlpor           varchar2(1);
v_tpdetas           varchar2(1);
v_existe            varchar2(1);
v_ttvalor           number(18,2);
v_val_cargo         number(18,2);
v_nro_solicitud     number(10);
v_dia_plazo         number(8);
v_per_gracia        number(8);
v_cod_ent_seguro    number(6);
v_cod_transaccion   number(4);
v_cod_tas_cargo     number(4);
v_cod_oficina       number(3);
v_nro_intento       number(3);
v_val_tasa          number;
v_por_ajuste        number;
v_val_tas_cargo     number;
v_ori_fondo         number;
v_val_car_minimo    number;

v_cod_rub_economico varchar2(6) := fug_obt_pardinamico('SCO_MUL_COD_RUB_ECO', 6);
v_cod_modalidad     number  := fug_obt_pardinamico('SCO_MUL_COD_MODALIDAD', 6);
v_cod_sub_modalidad number  := fug_obt_pardinamico('SCO_MUL_COD_SUB_MODALIDAD', 6);
v_monto             number  := fug_obt_pardinamico('SCO_MUL_MONTO', 6);
v_can_cuotas        number  := fug_obt_pardinamico('SCO_MUL_CAN_CUOTAS', 6);
v_cod_canal         number  := fug_obt_pardinamico('SCO_MUL_CANAL', 6);
v_cod_campana       number  := fug_obt_pardinamico('SCO_MUL_CAMPANA', 6);
v_tip_des_especifico number := fug_obt_pardinamico('SCO_MUL_TIP_DES_ESP', 6);
v_cod_destino        number := fug_obt_pardinamico('SCO_MUL_TIP_DESTINO', 6);

v_fec_actual        date 	 := pag_cal.fu_obt_fec_actual(v_cod_modulo);
v_fec_inicio        date   := v_fec_actual;
v_fec_pri_vto       date   := add_months(v_fec_inicio,1);
v_fec_vencimiento   date   := add_months(v_fec_pri_vto, v_can_cuotas-1);

PROCEDURE LP_ELI_SOLICITUDES IS
BEGIN
   DELETE FROM ba_tab_dat_adicionales
    WHERE tab_relacion = 'PR_SOLICITUDES' AND referencia = p_nro_solicitud AND parametro = 'SCO_MUL_NRO_SOL_ORI';
   DELETE FROM pr_sol_cuotas
    WHERE nro_solicitud = p_nro_solicitud;
   DELETE FROM pr_sol_cargos
    WHERE nro_solicitud = p_nro_solicitud;
   DELETE FROM pr_sol_garantias
    WHERE nro_solicitud = p_nro_solicitud;
   DELETE FROM pr_sol_tasas
    WHERE nro_solicitud = p_nro_solicitud;
   DELETE FROM pr_sol_destinos
    WHERE nro_solicitud = p_nro_solicitud;
   DELETE FROM pr_sol_gestiones
    WHERE nro_solicitud = p_nro_solicitud;
   DELETE FROM pr_solicitudes
    WHERE nro_solicitud = p_nro_solicitud;
EXCEPTION
   WHEN others THEN
      raise_application_error(-20000,'ERROR-LP_ELI_SOLICITUDES - '||sqlerrm);
END;

PROCEDURE LP_VAL_TASA IS
   CURSOR pizarras IS
      SELECT a.tas_interes, a.tas_minima, a.tas_maxima
        FROM cr_piz_montos b, cr_piz_plazos a
       WHERE a.cod_modulo = v_cod_modulo
         AND a.cod_modalidad = v_cod_modalidad
         AND a.cod_moneda = v_cod_moneda
         AND b.cod_modulo = a.cod_modulo
         AND b.cod_modalidad = a.cod_modalidad
         AND b.cod_moneda = a.cod_moneda
         AND b.mto_desde = a.mto_desde
         AND a.cod_sub_modalidad = v_cod_sub_modalidad
         AND v_monto between b.mto_desde AND b.mto_hasta
         AND v_dia_plazo between a.plz_desde AND a.plz_hasta;
   v_tas_interes number;
   v_tas_minima  number;
   v_tas_maxima  number;
BEGIN
   v_lugar := 'obtener_tasas de pizarras';
	 OPEN pizarras;
	 FETCH pizarras into v_tas_interes, v_tas_minima, v_tas_maxima;
	 CLOSE pizarras;
   IF v_val_tasa is null THEN
      v_val_tasa := v_tas_interes;
   ELSE
      -- valido la tasa ingresada---
      IF NOT v_val_tasa BETWEEN v_tas_minima AND v_tas_maxima then
         raise_application_error(-20000,'ERROR. Tasa fuera de Rango. Verifique la Pizarra');
      END IF;
   END IF;
END;

-- Verificacion del codigo del cliente--------------------------------------
PROCEDURE LP_VAL_COD_PERSONA is
BEGIN
   v_lugar := 'OBTENER_CLIENTE ';
	 SELECT exo_impuestos, cod_usu_oficial, cod_usu_promotor,
          cod_oficina, cod_departamento
	   INTO v_exo_impuestos, v_cod_usu_oficial, v_cod_usu_promotor,
          v_cod_oficina, v_cod_departamento
	   FROM ba_personas b, ge_clientes g
	  WHERE b.cod_persona = g.cod_persona
	    AND g.cod_persona = p_cod_persona;
EXCEPTION
   WHEN no_data_found THEN
      BEGIN
         SELECT gen.cod_ofi_matriz, 'N', ciu.cod_departamento
           INTO v_cod_oficina, v_exo_impuestos, v_cod_departamento
           FROM ge_par_generales gen, ba_oficinas ofi, ba_ciudades ciu
          WHERE gen.cod_ofi_matriz = ofi.cod_oficina
            AND ofi.cod_ciudad = ciu.cod_ciudad
            AND ofi.cod_pais   = ciu.cod_pais;
      END;
   WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20000,'LP_VAL_COD_PERSONA '||sqlerrm);
END;

-- Validacion del tipo de credito---------------------------------------------
PROCEDURE LP_VAL_COD_MODALIDAD IS
BEGIN
   SELECT 'S' INTO v_existe
     FROM ge_modalidades
    WHERE cod_modulo = v_cod_modulo
      AND cod_modalidad = v_cod_modalidad;
EXCEPTION
   WHEN no_data_found THEN
      raise_application_error(-20000,'ERROR. Tipo de Prestamo no habilitado');
   WHEN OTHERS THEN
      raise_application_error(-20000,'ERROR: Validar Modalidad '||SQLERRM);
END;

-- Validacion del codigo de la moneda-----------------------------------------
PROCEDURE LP_VAL_COD_MONEDA IS
BEGIN
   SELECT 'S' INTO v_existe
     FROM ba_monedas
    WHERE cod_moneda = v_cod_moneda;
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20000,'ERROR. Codigo de Moneda inexistente');
   WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20000,'ERROR: Valida moneda '||SQLERRM);
END;

-- Procedimiento para obtener el tipo de tasa --------------------------------
PROCEDURE LP_OBT_TIP_TASA
  (WW_CDTRANS IN NUMBER,  WW_NMTRANS IN OUT VARCHAR2,  WW_CDDETAS IN OUT NUMBER,
   WW_APLICAR IN OUT VARCHAR2, WW_TPVLPOR IN OUT VARCHAR2, WW_TPDETAS IN OUT VARCHAR2,
   WW_OBLIGATORIO IN OUT VARCHAR2, WW_AFECTA IN OUT VARCHAR2) IS
BEGIN
   v_lugar := 'OBTENER TIPO DE TASA ';
   SELECT initcap(TR.DESCRIPCION),TR.COD_TASA,TA.APLICAR,TA.TIP_VALOR,TA.TIPO, DT.OBLIGATORIO, TR.AFECTA
     INTO WW_NMTRANS,WW_CDDETAS,WW_APLICAR,WW_TPVLPOR,WW_TPDETAS, WW_OBLIGATORIO, WW_AFECTA
     FROM GE_TRANSACCIONES_DET DT, GE_TRANSACCIONES TR, GE_TASAS TA
    WHERE TR.COD_MODULO = v_cod_modulo
      AND TR.COD_MODALIDAD = v_cod_modalidad
      AND TR.COD_TRANSACCION = WW_CDTRANS
      AND TR.TIPO = 'D'
      AND TR.COD_TASA IS NOT NULL
      AND TR.COD_TASA = TA.COD_TASA
      AND DT.COD_MODULO = v_cod_modulo
      AND DT.COD_MODALIDAD = v_cod_modalidad
      AND DT.COD_TRANSACCION = 358
      AND DT.COD_MOD_HIJO = TR.COD_MODULO
      AND DT.COD_MAD_HIJO = TR.COD_MODALIDAD
      AND DT.COD_TRA_HIJO = TR.COD_TRANSACCION;
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20000,'ERROR: Cargo no definido para Prestamos. Transaccion ' || WW_CDTRANS );
   WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20000,'ERROR: OBT_TIPO_TASA '||sqlerrm);
END;

-- Funcion que obtiene el valor de la tasa fija ------------------------------
FUNCTION LF_OBT_VAL_TAS_FIJA (WW_CDDETAS IN NUMBER) RETURN NUMBER IS
   ww_vldetas     number(15,2);
   v_fec_vigencia date;
   v_tip_valor    ge_tasas.tip_valor%type;
   v_tipo         ge_tasas.tipo%type;
   v_cod_tasa     ge_tasas.cod_tasa%type := ww_cddetas;
BEGIN
   v_lugar := 'OBTENER VALOR DE TASA FIJA ';
   pag_gen.pr_obt_val_tasa(v_cod_modulo,
                           v_cod_modalidad,
                           v_cod_oficina,
                           null,
                           v_cod_moneda,--5
                           null,
                           'S',
                           v_cod_tasa,
                           null,
                           v_fec_inicio,--10
                           ww_vldetas,
                           v_fec_vigencia,
                           v_tip_valor,
                           v_tipo,
                           p_cod_persona,--15
                           v_cod_sub_modalidad);
   v_val_car_minimo := pag_gen.fu_obt_val_minimo;
   RETURN ww_vldetas;
EXCEPTION
   WHEN no_data_found THEN
      return null;
   WHEN others THEN
      raise_application_error(-20000,'obt_tasa_fija '||sqlerrm);
END;

-- Funcion que devuelve el valor de la tasa, si es variable ------------------
FUNCTION LF_OBT_VAL_TAS_VARIABLE (WW_CDDETAS IN NUMBER, WW_VLMONTO IN NUMBER, WW_FCINICI IN DATE) RETURN NUMBER IS
   ww_vldetas     number(15,2);
   v_fec_vigencia date;
   v_tip_valor    ge_tasas.tip_valor%type;
   v_tipo         ge_tasas.tipo%type;
   v_cod_tasa     ge_tasas.cod_tasa%type := ww_cddetas;

BEGIN
   v_lugar := 'OBTENER VALOR DE TASA VARIABLE ';
   pag_gen.pr_obt_val_tasa(v_cod_modulo,
                           v_cod_modalidad,
                           v_cod_oficina,
                           null,
                           v_cod_moneda,
                           ww_vlmonto,
                           's',
                           v_cod_tasa,
                           null,
                           v_fec_inicio,
                           ww_vldetas,
                           v_fec_vigencia,
                           v_tip_valor,
                           v_tipo,
                           p_cod_persona,
                           v_cod_sub_modalidad
                           );
   v_val_car_minimo := pag_gen.fu_obt_val_minimo;
   IF ww_vldetas is null THEN
   	  raise_application_error(-20000,'No existe Valor para la Tasa '||to_char(ww_cddetas)||' y el Monto '||to_char(ww_vlmonto)||
   	          ' Fecha '||to_char(ww_fcinici,'DD/MM/YYYY'));
   END IF;
   RETURN ww_vldetas;
EXCEPTION
   WHEN no_data_found THEN
      return null;
   WHEN others THEN
      IF sqlcode <= -20000 THEN
         raise;
      ELSE
         raise_application_error(-20000,'obt_tasa_variable '||sqlerrm);
      END IF;
END;

-- Verificacion del codigo de tasa--------------------------------------------
PROCEDURE LP_OBT_DAT_CARGO IS
BEGIN
   IF v_cod_ent_seguro is not null THEN
      --- veo que tasa de seguro tiene el ente asegurador
      v_cod_tas_cargo := fug_obt_parentes(v_cod_ent_seguro,'COD_TAS_SEGURO');--'COD_TAS_SEG_SEGURO' ver!
      --- Ahora, busco el codigo de tasa que corresponde al plazo
      v_cod_tas_cargo := lf_obt_val_tas_variable(v_cod_tas_cargo, nvl(v_dia_plazo,0), v_fec_inicio);
   END IF;
   -- obtengo los datos de la tasa-----------------
   lp_obt_tip_tasa(v_cod_transaccion,v_nmtrans,v_cod_tas_cargo,
                       v_aplicar,v_tpvlpor,v_tpdetas,v_obligatorio, v_afecta);
   --- la tasa es de tipo  valor ---
   IF v_tpdetas= 'F' THEN
      --- tipo de tasa fijo      ---
      v_val_tas_cargo := lf_obt_val_tas_fija(v_cod_tas_cargo);
   ELSE
      --- tipo de tasa variable  ---
      if v_aplicar in ('PI','PC','PT','PL','CP','IP','TP') then
      	  if v_aplicar in ('PI','PC','PT','PL') then
            --- El primer rango es por plazo
             v_val_tas_cargo := lf_obt_val_tas_variable(v_cod_tas_cargo,v_dia_plazo,v_fec_inicio);
          else
             --- tipo de tasa variable  ---
             v_val_tas_cargo := lf_obt_val_tas_variable(v_cod_tas_cargo,nvl(v_tot_prestamo,v_monto),v_fec_inicio);
          end if;
          if v_aplicar IN ('CP','IP','TP') then -- aplicar al capital y plazo, busco ahora el valor por plazo
             v_val_tas_cargo := lf_obt_val_tas_variable(v_val_tas_cargo, v_dia_plazo,v_fec_inicio);
          elsif v_aplicar in ('PC','PT','PI') then
             v_val_tas_cargo := lf_obt_val_tas_variable(v_val_tas_cargo,nvl(v_tot_prestamo,v_monto),v_fec_inicio);
          end if;
      else
         v_val_tas_cargo := lf_obt_val_tas_variable(v_cod_tas_cargo,nvl(v_tot_prestamo,v_monto),v_fec_inicio);
      end if;
   END IF;
   IF v_tpvlpor IN ('I','P') OR v_cod_transaccion IN (735,736) THEN
      --- porcentajes  o transacciones de seguros  ---
      v_cod_mon_cargo :=v_mon_local;
   ELSE
      --- en caso de que sean valores ----------------
      v_cod_mon_cargo := v_cod_moneda;
      v_val_cargo := v_val_tas_cargo;
      v_val_tas_cargo := null;
   END IF;
END;

-- Carga de cargos de la propuesta-------------------------------------------
PROCEDURE LP_GEN_CARGOS IS
v_cod_tip_canal ge_tip_canales.cod_tip_canal%type;

CURSOR cargos is
   SELECT decode(a.cod_transaccion,709,1,710,2,a.cod_transaccion) orden,  -- solo para ordenamiento
          a.cod_transaccion, a.cod_ent_seguro, nvl(b.obligatorio,'N') obligator
     FROM ge_sol_cargos a, ge_transacciones_det b
    WHERE a.cod_transaccion = b.cod_tra_hijo (+)
      AND a.cod_modulo = b.cod_mod_hijo (+)
      AND a.cod_modalidad = b.cod_mad_hijo (+)
      AND a.cod_modulo = v_cod_modulo
      AND a.cod_modalidad = v_cod_modalidad
      AND ((NVL(v_exo_impuestos,'N') = 'N') or
           (NVL(v_exo_impuestos,'N') = 'S' AND nvl(b.obligatorio,'N') = 'N'))
      AND (a.cod_canal = v_cod_canal or (a.cod_canal is  null AND not exists (Select '1' from ge_sol_cargos where cod_canal = v_cod_canal)))
      AND (a.cod_tip_canal = v_cod_tip_canal or (a.cod_tip_canal is null AND not exists (select '1' from ge_sol_cargos where cod_tip_canal = v_cod_tip_canal)))
      AND (a.cod_campana = v_cod_campana or (a.cod_campana is null AND not exists (Select '1' from ge_sol_cargos where cod_campana = v_cod_campana)))
    ORDER BY 1;
BEGIN
   IF v_cod_canal is not null THEN
      SELECT cod_tip_canal
        INTO v_cod_tip_canal
        FROM ge_canales
       WHERE cod_canal = v_cod_canal;
   END IF;
   FOR cc IN cargos LOOP
      v_cod_transaccion := cc.cod_transaccion;
      v_cod_ent_seguro  := cc.cod_ent_seguro;
      v_val_tas_cargo   := null;
      v_val_cargo       := null;
      v_cod_tas_cargo   := null;
      v_cod_mon_cargo   := null;
      lp_obt_dat_cargo;

      INSERT INTO pr_sol_cargos (nro_solicitud, cod_transaccion, fec_tasa, val_tasa,
                monto, cod_tasa, cod_ent_seguro, cod_moneda, mto_mon_prestamo)
      VALUES (v_nro_solicitud,v_cod_transaccion,v_fec_inicio, v_val_tas_cargo,
              v_val_cargo, v_cod_tas_cargo, cc.cod_ent_seguro,v_cod_mon_cargo,null);
   END LOOP;
END;
-- Generacion de cuotas -----------------------------------------------------
PROCEDURE LP_GEN_CUOTAS  IS
   ww_frances NUMBER;
   ww_tasadiv NUMBER := v_val_tasa / 36500 * 30.416666666666666666666666666667; --ver!
   ww_vlsalan NUMBER(18,2) := v_tot_prestamo;
   ww_ttcuota NUMBER(18,2) := NULL;
   ww_dfcuota NUMBER(18,2);
   ww_ttcapit NUMBER(18,2) := 0;
   ww_ttrefue NUMBER(18,2) := 0;
   ww_refreal NUMBER(18,2) := 0;
   ww_ctrefue NUMBER(6)  := 0;
   ww_nro     NUMBER(6)  := 0;
   ww_veces   NUMBER(3)  := 0;
   v_val_int_original NUMBER(18,2) :=0;
   --
   v_fec_vto_habil    DATE;
   v_fec_vto_exacto       DATE;
   v_sal_cap_anterior NUMBER(18,2);
   v_dia_interes      NUMBER(6);
   v_val_interes      NUMBER(18,2);
   v_ttcuota          NUMBER(18,2);
   v_dia_periodo      NUMBER(8);
   v_mto_capital      NUMBER(18,2);
   v_fec_ven_anterior date;
   v_val_cuota        number(18,2);
   v_dias             number;
BEGIN
   LOOP
      v_fec_ven_anterior := v_fec_inicio;
      ww_veces := NVL(ww_veces,0)  + 1;
      IF (power((1+WW_TASADIV),(v_can_cuotas-WW_CTREFUE))-1) > 0 THEN
         ww_frances := ((NVL(V_TOT_PRESTAMO,0)-NVL(ww_ttrefue,0))* ww_tasadiv) /
                   (power((1 + ww_tasadiv),(v_can_cuotas-ww_ctrefue)) - 1);
      ELSE
         ww_frances := ((NVL(v_tot_prestamo,0)-NVL(WW_TTREFUE,0)))/
                      ((v_can_cuotas-WW_CTREFUE));
      END IF;
      v_val_cuota := round((WW_FRANCES * power(1 + WW_TASADIV, (0))),v_redondeo) +
                     round(WW_VLSALAN * WW_TASADIV, v_redondeo);
      v_val_cuota := fup_obt_val_cuota(v_cod_modalidad, v_cod_moneda, v_tot_prestamo - nvl(ww_ttrefue,0),
                                 v_can_cuotas - nvl(ww_ctrefue,0), v_val_tasa, v_fec_inicio, v_fec_pri_vto);
      --- Veo el monto fijo de cuota si es de tipo Prestamos flexibles -----
      v_mto_interes := 0;
      ww_vlsalan  := v_tot_prestamo;
      ww_ttcapit  := 0;
      ww_refreal  := 0;
      ww_nro      := 0;  /* acumulador de cuotas calculadas automaticamente, sin refuerzo */
      -- borro las cuotas si existen
      DELETE FROM pr_sol_cuotas WHERE nro_solicitud = v_nro_solicitud;
      FOR CUOTA IN 1..v_can_cuotas LOOP
         IF cuota = 1 THEN
            v_fec_vto_habil := v_fec_pri_vto;
            v_fec_vto_exacto := v_fec_pri_vto;
         ELSE
            v_fec_vto_habil := add_months(v_fec_pri_vto,(cuota-1));
            v_fec_vto_exacto := v_fec_pri_vto + (((cuota-1)*30));
         END IF;
         v_dias := v_fec_vto_habil - v_fec_ven_anterior;
         v_sal_cap_anterior := ww_vlsalan;
         v_dia_periodo      := v_dias;
         v_dia_interes      := v_dias;
         v_val_interes      := round((ww_vlsalan * ww_tasadiv / 30.416666666666666666666666666667 * v_dias),v_redondeo);
         IF v_val_int_original > 0 THEN  /* es una cuota con refuerzo */
            IF p_tip_monto = 'N' THEN  -- NETO
               v_mto_capital := v_mto_capital;
            ELSE
               v_mto_capital := nvl(v_val_int_original,0) - nvl(v_mto_interes,0);
            END IF;
            ww_refreal := nvl(ww_refreal,0) + nvl(v_mto_capital,0);
         ELSE
           ww_nro := ww_nro + 1;
           IF cuota = 1 AND abs(30 - (v_fec_pri_vto - v_fec_inicio)) > 2 THEN
              V_MTO_CAPITAL := round(WW_FRANCES * power((1 + WW_TASADIV),(WW_NRO -1)),v_redondeo);
           ELSE
              V_MTO_CAPITAL := v_val_cuota - V_VAL_INTERES;
           END IF;
         END IF;
         v_val_int_original := nvl(v_val_int_original,0);
         v_ttcuota := nvl(v_mto_capital,0) + nvl(v_val_interes,0);
         ww_dfcuota :=  nvl(ww_ttcuota,v_ttcuota) - nvl(v_ttcuota,0);
         -- ajuste de cuotas para que sean iguales solo se hace en guaranies
         IF (ABS(ww_dfcuota) BETWEEN 0.001 AND v_limite)  THEN
            V_VAL_INTERES := V_VAL_INTERES + ww_dfcuota;
            V_TTCUOTA := V_TTCUOTA + ww_dfcuota;
         END IF;
         IF v_val_int_original = 0 THEN
           ww_ttcuota := v_ttcuota;
         END IF;
         ww_vlsalan := NVL(ww_vlsalan,0) - V_MTO_CAPITAL;
         ww_ttcapit := NVL(ww_ttcapit,0) + NVL(V_MTO_CAPITAL,0);
         v_mto_interes := v_mto_interes + nvl(v_val_interes,0);
         v_fec_ven_anterior := v_fec_vto_habil;
         -- inserto el registro en la tabla de cuotas
         INSERT INTO pr_sol_cuotas
               (nro_solicitud, nro_cuota, mto_capital, fec_vto_habil,
                fec_vto_exacto, val_interes, sal_capital, sal_cap_anterior,
                dia_periodo, dia_transcurridos, dia_interes, tip_calculo,
                val_int_original, val_int_adelantado)
          VALUES
               (v_nro_solicitud, cuota, nvl(v_mto_capital,0), v_fec_vto_habil,
                v_fec_vto_exacto, nvl(v_val_interes,0), ww_vlsalan, ww_vlsalan + v_mto_capital,
                v_dia_periodo, v_dia_periodo, v_dia_interes, 'V',
                v_val_int_original, 0 );
      END LOOP;
      --- veo si se necesita ajustar la ultima cuota de capital ------
      IF ABS(NVL(ww_refreal,0) - NVL(ww_ttrefue,0)) < 10 OR ww_veces > 12 OR p_tip_monto = 'N' THEN
         EXIT;
      END IF;
   END LOOP;
   ww_dfcuota := nvl(v_tot_prestamo,0) - nvl(ww_ttcapit,0);
   IF ww_dfcuota <> 0 THEN
      v_mto_capital := nvl(v_mto_capital,0) + ww_dfcuota;
      IF NVL(v_val_interes,0) >= ww_dfcuota AND abs(ww_dfcuota) <= -1 /* solo se ajusta si existe interes*/
         AND nvl(v_val_interes,0) > 0 THEN
         v_val_interes := nvl(v_val_interes,0) - ww_dfcuota;
         v_mto_interes := nvl(v_mto_interes,0) - ww_dfcuota;
      ELSE
         v_ttcuota := nvl(v_mto_capital,0) + nvl(v_val_interes,0);
      END IF;
      -- Actualizo la ultima cuota
      UPDATE pr_sol_cuotas
         SET mto_capital = nvl(v_mto_capital,0),
             val_interes = nvl(v_val_interes,0)
       WHERE nro_solicitud = v_nro_solicitud
         AND nro_cuota = v_can_cuotas; -- ultima cuota
   END IF;
   -- vencimiento final del prestamo es igual al de la ult.cuota--
   UPDATE pr_solicitudes
      SET fec_vencimiento = v_fec_vto_habil,
          mto_interes     = v_mto_interes
    WHERE nro_solicitud = v_nro_solicitud;
EXCEPTION
   WHEN others THEN
      raise_application_error(-20000,'GENERACION_CUOTAS '||sqlerrm);
END;

-- Calculo de los cargos ----------------------------------------------------
PROCEDURE LP_CAL_CARGOS IS
   ww_dfcargos number(18,2);
   v_mto_equivalente number(18,2);
   v_cod_tra_ajuste  number(4);
   v_mto_aux         number(18,2);
   CURSOR cargos IS
      SELECT cod_transaccion, cod_tasa, cod_ent_seguro,val_tasa, monto,cod_moneda, mto_mon_prestamo
        FROM pr_sol_cargos
       WHERE nro_solicitud = v_nro_solicitud
         FOR UPDATE OF monto
       ORDER BY decode(cod_transaccion,709,1,710,2,cod_transaccion);
BEGIN
   --- Calculo cada uno de los cargos en la moneda del cargo y en la de la simulacion ---
   --- cero los totales de cargo de tipo valor y el total general de cargos -------------
   v_ttvalor := 0;
   v_mto_cargo := 0;
   v_cod_tra_ajuste := null;
   FOR cc IN cargos LOOP
      v_mto_equivalente := 0;
      -- para realizar ajustes si es necesario----------
      IF v_cod_tra_ajuste is null THEN
         v_cod_tra_ajuste := cc.cod_transaccion;
      END IF;
      -- obtengo los datos de la tasa-----------------
      lp_obt_tip_tasa(cc.cod_transaccion,v_nmtrans,cc.cod_tasa,
                          v_aplicar,v_tpvlpor,v_tpdetas,v_obligatorio, v_afecta);
      v_val_tas_cargo := lf_obt_val_tas_fija(cc.cod_tasa);
      IF cc.cod_transaccion is not null AND (cc.COD_MONEDA is null OR (v_tpvlpor = 'V' AND nvl(cc.monto,0) = 0)) THEN
         raise_application_error(-20000,'Valores nulos en Cargos. Verificar la Trans. '||to_char(cc.cod_transaccion));
      END IF;
      IF v_tpvlpor = 'P' THEN
         v_mto_equivalente := 0;
         --- la tasa es un porcentaje-----------------------------------------------------
         IF v_aplicar in ('CI','IN') then
            --- aplicable al interes -----------------------------------------------------
            v_mto_equivalente :=  round(v_mto_interes */* v_dia_plazo * */cc.val_tasa / 100,v_redondeo);
         ELSIF v_aplicar IN ('PI','IP','PT','TP') then
           v_mto_equivalente := round(v_mto_interes * v_dia_plazo * cc.val_tasa / 36500,v_redondeo);
         END IF;
         IF v_aplicar IN ('CA','CI','CP') THEN
           --- es aplicable al capital --------------------------------------------------
           v_mto_equivalente :=  nvl(v_mto_equivalente,0) +
                           ROUND(v_tot_prestamo * /*v_DIA_PLAZO **/ cc.val_tasa / 100,v_redondeo);
                           --ROUND(v_TOT_PRESTAMO * v_DIA_PLAZO * cc.val_tasa / 36500,v_redondeo);
         ELSIF v_aplicar in ('PC','PT','TP') THEN
           v_mto_equivalente := nvl(v_mto_equivalente,0) +
                                round(v_tot_prestamo * v_dia_plazo / 36500,v_redondeo);
         END IF;
         if nvl(v_mto_equivalente,0) <= nvl(v_val_car_minimo,0) then
            v_mto_equivalente := nvl(v_val_car_minimo,0);
         end if;
      ELSIF v_tpvlpor = 'I' THEN
         v_mto_equivalente := 0;
         --- la tasa es un impuesto ------------------------------------------------------
         IF v_aplicar IN ('CI','IN','PI','IP','PT','TP') THEN
            --- aplicable al interes -----------------------------------------------------
            IF v_dia_plazo < 365 THEN
               v_mto_equivalente :=  round(v_mto_interes * v_dia_plazo * cc.val_tasa / 36500,v_redondeo);
            ELSE
               v_mto_equivalente :=  round(v_mto_interes * cc.val_tasa / 100,v_redondeo);
            END IF;
         END IF;
         IF v_aplicar IN  ('CA','CI','PC','CP','PT','TP') THEN
            --- es aplicable al capital --------------------------------------------------
            IF cc.cod_ent_seguro IS NOT NULL THEN
               --- es un seguro ----------------------------------------------------------
               v_mto_equivalente := nvl(v_mto_equivalente,0) +
                             round(v_tot_prestamo * cc.val_tasa / 100,v_redondeo);
            ELSE
               --- es un impuesto sobre el capital ---------------------------------------
               IF v_dia_plazo < 365 THEN
                  v_mto_equivalente := nvl(v_mto_equivalente,0) +
                                round(v_tot_prestamo * v_dia_plazo * cc.val_tasa / 36500,v_redondeo);
               ELSE
                  v_mto_equivalente := nvl(v_mto_equivalente,0) +
                                round(v_tot_prestamo * cc.val_tasa / 100,v_redondeo);
               END IF;
            END IF;
         END IF;
      ELSIF v_TPVLPOR = 'V' THEN
         --- es un monto valor -----------------------------------------------------------
         v_mto_equivalente := cc.monto;
         v_ttvalor := nvl(v_ttvalor,0) + nvl(v_mto_equivalente,0);
      END IF;
      --- Acumular el total de cargos (Si el tipo es Valor viene directamente aqui -------
      IF nvl(v_afecta,'Z') <> 'G' THEN
         v_mto_cargo := nvl(v_mto_cargo,0) + nvl(v_mto_equivalente,0);
      END IF;
      ------------------------------------------------------------------------------------
      v_mto_aux := null;
      IF v_tpvlpor IN ('I','P') THEN  /* solo si es porcentaje */
         IF cc.cod_moneda = v_cod_moneda THEN
           -- moneda del cargo es igual a la moneda de la simulacion ----------------------
           v_mto_aux := v_mto_equivalente;
         ELSE
            -- monedas diferentes, se divide por la cotiz. de la moneda de la simulacion ---
            v_red_mon_local :=  fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',6,v_cod_modalidad,v_mon_local);
            /*
            || PCCLIANC-4
            || El Monto del Cargo debe ser sin decimales
            || Siempre es en moneda local
            */
            v_mto_aux := round(v_mto_equivalente * v_cotizacion,/*v_redondeo*/v_red_mon_local);
         END IF;
      END IF;
      UPDATE pr_sol_cargos
         SET mto_mon_prestamo = NVL(v_mto_equivalente,0),
             monto            = nvl(v_mto_aux,monto)
       WHERE current of cargos;
   END LOOP;
   IF v_mto_cargo >= v_tot_prestamo THEN
      raise_application_error(-20000,'ERROR. Total de Cargos '||v_MTO_CARGO||' es superior al Total del Préstamo '||v_TOT_PRESTAMO);
   ELSE
      IF p_tip_monto = 'N' AND v_tot_prestamo <> v_monto THEN
         --- ya estoy en el ultimo calculo de cargos netos, veo si hay ajuste --------
         IF nvl(v_tot_prestamo,0)-nvl(v_mto_cargo,0) <> v_monto THEN
            -- es necesario un ajuste en el cargo del impuesto o primer cargo      ---
            ww_dfcargos := v_monto - (nvl(v_tot_prestamo,0)-nvl(v_mto_cargo,0));
            FOR cc IN cargos LOOP
               IF cc.cod_transaccion = 704 THEN
                  v_mto_equivalente := NVL(V_MTO_EQUIVALENTE,0) - ww_dfcargos;
                  v_mto_cargo       := NVL(V_MTO_CARGO,0) - ww_dfcargos;
                  UPDATE pr_sol_cargos
                     SET mto_mon_prestamo =  NVL(mto_mon_prestamo,0) - nvl(ww_dfcargos,0),
                         monto =  decode(cod_moneda,v_cod_moneda,NVL(mto_mon_prestamo,0) - nvl(ww_dfcargos,0),
                                       decode(cod_moneda,v_mon_local,
                                       round(((NVL(mto_mon_prestamo,0) - nvl(ww_dfcargos,0)) * v_cotizacion),v_redondeo),
                                       round(((NVL(mto_mon_prestamo,0) - nvl(ww_dfcargos,0)) * v_cotizacion),v_redondeo)))
                   WHERE nro_solicitud = v_nro_solicitud
                     AND cod_transaccion = cc.cod_transaccion;
               END IF;
            END LOOP;
         END IF;
      END IF;
   END IF;
   -- actualizo el total de cargos de  la solicitud
   UPDATE pr_solicitudes
      SET mto_cargo = v_mto_cargo
    WHERE nro_solicitud = v_nro_solicitud;
EXCEPTION
  WHEN others THEN
     raise_application_error(-20000,'CALCULAR_CARGOS '||SQLERRM);
END;

-- INICIO DEL PROCEDIMIENTO PRINCIPAL----------------------------------------
BEGIN
   --- Veo el tipo de redondeo de los calculos ------------------------------------------
   IF v_cod_moneda <> v_mon_local THEN
      v_limite   := 0.05;
   END IF;
   v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',v_cod_modulo,v_cod_modalidad,v_cod_moneda);
   -- Valido el codigo del cliente-------------------------------------------
   lp_val_cod_persona;
   -- valido el codigo de la modalidad que recibo----------------------------
   lp_val_cod_modalidad;
   -- valido la moneda-------------------------------------------------------
   lp_val_cod_moneda;
   IF p_nro_solicitud is not null THEN
      IF p_mto_reconducido > 0 THEN
         v_tot_prestamo := p_mto_reconducido;
         v_monto := p_mto_reconducido;  
      ELSE
         v_tot_prestamo := v_monto;
      END IF;
      v_nro_solicitud := p_nro_solicitud;
      lp_eli_solicitudes;
   ELSE
      v_tot_prestamo :=  v_monto;
      select s_nro_solicitud.nextval INTO v_nro_solicitud FROM dual;
   END IF;
   -- valido el monto -------------------------------------------------------
   IF NVL(v_tot_prestamo,0) <= 0 THEN
      raise_application_error(-20000,'ERROR. Ingrese Monto del Credito');
   END IF;
   -- valido el tipo de monto -----------------------------------------------
   IF nvl(p_tip_monto,'X') not in ('B','N') then
      raise_application_error(-20000,'ERROR. Tipo de Monto debe ser B-Bruto o N-Neto');
   END IF;
   -- valido la cantidad de cuotas ------------------------------------------
   IF nvl(v_can_cuotas,0) < 1 then
      raise_application_error(-20000,'ERROR. Ingrese la cantidad de cuotas');
   END IF;
   -- Valido la fecha del primer vencimiento --------------------------------
   IF v_fec_pri_vto <= v_fec_actual and v_cod_modalidad <> 660 THEN
      raise_application_error(-20000,'ERROR. Primer Vencimiento debe ser posterior a la fecha de Hoy');
   END IF;
   --
   v_dia_plazo := ADD_MONTHS(v_fec_pri_vto,v_can_cuotas-1) - v_fec_inicio;
   v_per_gracia := v_fec_pri_vto - v_fec_inicio;
   v_per_capital := 30;
   -- Valido la tasa de interes ---------------------------------------------
   LP_VAL_TASA;

   ---- Origen de Fondos
   IF v_cod_moneda IS NOT NULL AND v_cod_modalidad is not null THEN
		  v_ori_fondo := nvl(FUP_OBT_ORI_FON_MODALIDAD(v_cod_modalidad,v_cod_moneda),0);
	 END IF;

	 IF v_ori_fondo = 0 THEN
      v_ori_fondo := fug_obt_pardinamico('COD_ORI_FON_DESEMB', v_cod_modulo,v_cod_modalidad,v_cod_moneda, v_cod_oficina );
      v_por_ori_fondo := 100;
	 END IF;

   IF v_tip_destino is null THEN
      v_tip_destino := fup_obt_tip_destino(p_cod_persona, v_cod_modalidad, v_cod_moneda, 0,
                                           v_mto_interes, v_monto, v_dia_plazo, p_tip_monto);
   END IF;

   BEGIN
      SELECT referencia
        INTO v_cod_sec_credito
        FROM pr_rub_economicos
       WHERE cod_rub_economico = v_cod_rub_economico
         AND nvl(fup_obt_sec_rubro(referencia), 'N') <> 'N';
   EXCEPTION
      WHEN others THEN
         v_cod_sec_credito := '702';
   END;

   -- inserto el registro en la tabla de solicitudes ------------------------
   BEGIN
      v_cod_oficina := FUG_OBT_OFI_OFICIAL(p_cod_persona);

      INSERT INTO pr_solicitudes (nro_solicitud, descripcion, monto, tip_amortizacion,
           dia_plazo, fec_vencimiento, mto_interes, per_vto_capital, per_gracia, cod_persona,
           fec_inicio, tip_monto, tot_prestamo, cod_modulo, cod_modalidad, cod_sub_modalidad,
           cod_moneda, cod_oficina, fec_pri_vencimiento, cod_sec_credito,
           cod_departamento,  tip_documento, exo_impuesto,
           cod_usu_promotor, cod_canal, cod_campana, tip_destino,
           cod_banca, tip_renovacion, cod_ori_fondo, cod_rub_economico, por_ori_fondo, cod_destino,
           ind_evaluacion, nro_cta_debito, deb_automatico, tip_interes, est_verificacion, val_presupuesto)
      VALUES (v_nro_solicitud, nvl(v_descripcion,'.'), v_monto, v_tip_amortizacion,
           v_dia_plazo, v_fec_vencimiento, v_mto_interes, v_per_capital, v_per_gracia, p_cod_persona,
           v_fec_inicio, p_tip_monto, v_tot_prestamo, v_cod_modulo, v_cod_modalidad, v_cod_sub_modalidad,
           v_cod_moneda, v_cod_oficina, v_fec_pri_vto, v_cod_sec_credito,
           nvl(v_cod_departamento, v_cod_dep_parametro), v_tip_documento, v_exo_impuestos,
           v_cod_usu_promotor, v_cod_canal, v_cod_campana, v_tip_destino,
           null /*cod_banca*/, 'A', v_ori_fondo, v_cod_rub_economico, v_por_ori_fondo, v_cod_destino,
           v_ind_evaluacion, v_nro_cta_debito, v_deb_automatico, v_tip_interes, 'S', v_tot_prestamo);
   EXCEPTION
      WHEN others THEN
       raise_application_error(-20001,'Insert PR_SOLICITUDES '||sqlerrm);
   END;
   -- genero los cargos por defecto
   LP_GEN_CARGOS;
   -- generar cuotas --------------------------------------------------------
   LP_GEN_CUOTAS;
   -- Calculo los cargos ----------------------------------------------------
   LP_CAL_CARGOS;
   -- verifico el tipo de prestamo
   IF p_tip_monto = 'B' THEN
      UPDATE pr_solicitudes
         SET tot_prestamo = v_tot_prestamo,
             mto_cargo = v_mto_cargo,
             tot_desembolsar = v_tot_prestamo - v_mto_cargo
       WHERE nro_solicitud = v_nro_solicitud;
   ELSE
      --- monto ingresado es el neto -----------------------------------------------------
      v_por_ajuste := (v_monto - (V_MTO_CARGO -V_TTVALOR)) * 100 / (v_monto + V_TTVALOR);
      --- calculo del nuevo capital (monto bruto -----------------------------------------
      v_tot_prestamo := ROUND((v_monto * 100 / v_por_ajuste),v_redondeo);
      --- Vuelvo a generar las cuotas y calcular los cargos ------------------------------
      LP_GEN_CUOTAS;
      -- recalculo los cargos ------------------------------------------------------------
      LP_CAL_CARGOS;
      -- actualizo el total del prestamo -------------------------------------------------
      UPDATE pr_solicitudes
         SET tot_prestamo = v_tot_prestamo/*,
             est_verificacion = 'N'*/
       WHERE nro_solicitud = v_nro_solicitud;


   END IF;
   -- finalmente inserto la cuota 0 ------------------------------------------------------
   BEGIN
      INSERT INTO pr_sol_cuotas
             (nro_solicitud,nro_cuota,fec_vto_exacto,fec_vto_habil,val_interes,val_int_adelantado,
              mto_capital,sal_capital,dia_transcurridos,dia_interes,dia_periodo)
      VALUES (v_nro_solicitud,0,v_fec_inicio,v_fec_inicio,0,0,0,v_tot_prestamo,0,0,0);
   EXCEPTION
      WHEN others THEN
         raise_application_error(-20001,'Error al insertar cuota 0 '||sqlerrm);
   END;
   -- inserto el registro de la tasa ----------------------------------------------------
   BEGIN
      INSERT INTO pr_sol_tasas
             (nro_solicitud, fec_vigencia, val_tasa, tip_cobro, per_vencimiento)
      VALUES
            (v_nro_solicitud,v_fec_inicio,v_val_tasa,'V',v_per_vencimiento);
   EXCEPTION
      WHEN others THEN
         raise_application_error(-20002,'Error al insertar el registro de tasas '||sqlerrm);
   END;
   -- inserto el registro de la garantía --------------------------------------------------
   BEGIN
      INSERT INTO pr_sol_garantias (nro_solicitud, cod_garantia, mto_aplicado)
      VALUES (v_nro_solicitud, 1,v_tot_prestamo);
   EXCEPTION
      WHEN others THEN
         raise_application_error(-20003,'Error al insertar el registro de garantia '||sqlerrm);
   END;
   -- inserto el registro del destino ----------------------------------------------------
   BEGIN
      INSERT INTO pr_sol_destinos (nro_solicitud, tip_des_especifico, monto)
       VALUES (v_nro_solicitud, v_tip_des_especifico, v_tot_prestamo);
   EXCEPTION
      WHEN others THEN
         raise_application_error(-20003,'Error al insertar el registro de destino '||sqlerrm);
   END;
   -- inserto el dato adicional de nro_solicitud padre ----------------------------------------------------
   BEGIN
      INSERT INTO ba_tab_dat_adicionales (tab_relacion, referencia, parametro, val_parametro)
       VALUES ('PR_SOLICITUDES', v_nro_solicitud, 'SCO_MUL_NRO_SOL_ORI', p_ant_nro_solicitud);
   EXCEPTION
      WHEN others THEN
         raise_application_error(-20003,'Error al insertar dato adicional '||sqlerrm);
   END;

   IF nvl(p_ind_val_scoring, 'N') = 'S' THEN
      par_per.pr_gen_rie_evaluaciones(v_nro_solicitud, v_nro_intento, v_error, v_cod_modulo, v_cod_modalidad);
      BEGIN
         SELECT a.dic_final, a.mto_reconducido
           INTO p_sco_dic_final, p_mto_reconducido
           FROM ge_dat_rie_evaluaciones a
          WHERE a.nro_solicitud = v_nro_solicitud
            AND a.nro_intento = v_nro_intento
            AND a.cod_modulo = v_cod_modulo
            AND a.cod_modalidad = v_cod_modalidad;
      EXCEPTION
         WHEN others THEN
            p_sco_dic_final   := 'X';
            p_mto_reconducido := 0;
      END;
      -- Descontar los llamados automáticos
      IF fug_val_usu_rol('ROL_DPTO_COM_EVALUACION', USER) THEN
         v_cod_rol := fug_obt_pardinamico('ROL_DPTO_COM_EVALUACION');
      END IF;

      IF fug_val_usu_rol('ROL_DPTO_RIE_EVALUACION', USER) THEN
         v_cod_rol := fug_obt_pardinamico('ROL_DPTO_RIE_EVALUACION');
      END IF;
      BEGIN
         UPDATE ge_dat_rie_eva_intentos
            SET can_intentos = can_intentos - 1
          WHERE nro_solicitud = v_nro_solicitud
            AND cod_rol = v_cod_rol
            AND cod_modulo = v_cod_modulo
            AND cod_modalidad = v_cod_modalidad;
      EXCEPTION
         WHEN others THEN
            null;
      END;
   END IF;
   p_nvo_nro_solicitud := v_nro_solicitud;
   p_sco_error         := v_error;

   BEGIN
      -- vuelvo a dejar no-verificado -------------------------------------------------
      UPDATE pr_solicitudes
         SET est_verificacion = 'N'
       WHERE nro_solicitud = v_nro_solicitud;
   EXCEPTION
      WHEN others THEN
         raise_application_error(-20003,'Error al actualizar est_verificacion '||sqlerrm);
   END;

EXCEPTION
   WHEN others THEN
      IF sqlcode <= -20000 THEN
         raise;
      ELSE
         raise_application_error(-20000,'Error en PRP_GEN_SCO_SOLICITUD '||sqlerrm);
      END IF;
END PRP_GEN_SCO_SOLICITUD;
/

