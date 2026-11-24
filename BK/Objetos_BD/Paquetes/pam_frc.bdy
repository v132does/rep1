CREATE OR REPLACE PACKAGE BODY IT.PAM_FRC IS

  C_COD_MODULO      CONSTANT NUMBER := 10;
  C_COD_PERSONA_BCP CONSTANT NUMBER := 8282047;
  C_COD_MOD_FLI     CONSTANT NUMBER := 138;
  C_COD_MOD_REPO_ON CONSTANT NUMBER := 139;
  C_COD_MOD_TPREPO  CONSTANT NUMBER := 140;
  C_COD_OFICINA_DEF CONSTANT NUMBER := 61;
  C_MAX_REINT_NRO   CONSTANT NUMBER := 50; -- skip si nro ya existe en ge_cuentas/md_cta_documentos
  C_COD_PROG        CONSTANT VARCHAR2(30) := 'IT.PAM_FRC';
  C_TRA_PADRE       CONSTANT NUMBER := 102;
  C_TRA_CAMBIO_EST  CONSTANT NUMBER := 401;
  C_TRA_SIPAP_ALTA  CONSTANT NUMBER := 815;
  C_TRA_SIPAP_BAJA  CONSTANT NUMBER := 816;
  C_TRA_ALTA_ACU    CONSTANT NUMBER := 818;
  C_TRA_ALTA_COSTO  CONSTANT NUMBER := 819;
  C_TRA_BAJA_ACU    CONSTANT NUMBER := 820;
  C_TRA_COSTO_RES   CONSTANT NUMBER := 822;
  C_TRA_CES_GAR     CONSTANT NUMBER := 823;
  C_TRA_LIB_GAR     CONSTANT NUMBER := 824;
  C_RUBRO_SIPAP     CONSTANT VARCHAR2(15) := '150102570200799';
  -- Errores contables
  C_ERR_PARAM_CAT    CONSTANT NUMBER := 709;
  C_ERR_CERRAR_ASI   CONSTANT NUMBER := 710;

  g_cod_error NUMBER(4) := 0;
  g_msj_error VARCHAR2(1000);

  TYPE t_parseo_dato_cuenta IS RECORD (
    dato   t_dat_cuenta_fli_repo,
    bloque VARCHAR2(20),
    amt    NUMBER,
    repo   NUMBER
  );

  ---------------------------------------------------------------------------
  PROCEDURE lf_limpiar_error IS
  BEGIN
    g_cod_error := 0;
    g_msj_error := NULL;
  END lf_limpiar_error;

  ---------------------------------------------------------------------------
  PROCEDURE lf_set_error (
    p_cod_error IN NUMBER,
    p_msj_error IN VARCHAR2
  ) IS
  BEGIN
    g_cod_error := p_cod_error;
    g_msj_error := SUBSTR(p_msj_error, 1, 1000);
  END lf_set_error;

  ---------------------------------------------------------------------------
  PROCEDURE lf_log_blando (p_det IN VARCHAR2) IS
  BEGIN
    PRG_INS_LOG_ERRORES(
      P_COD_PROGRAMA => C_COD_PROG,
      P_DET_ERROR    => SUBSTR(p_det, 1, 4000)
    );
  EXCEPTION
    WHEN OTHERS THEN
      NULL;
  END lf_log_blando;

  ---------------------------------------------------------------------------
  FUNCTION lf_obt_denominacion_bcp RETURN VARCHAR2 IS
    v_nom ba_personas.nom_completo%TYPE;
  BEGIN
    SELECT p.nom_completo
      INTO v_nom
      FROM ba_personas p
     WHERE p.cod_persona = C_COD_PERSONA_BCP;
    RETURN v_nom;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RETURN 'BANCO CENTRAL DEL PARAGUAY';
  END lf_obt_denominacion_bcp;

  ---------------------------------------------------------------------------
  FUNCTION lf_parse_deal (
    p_valor   IN VARCHAR2,
    p_cod_iso OUT VARCHAR2
  ) RETURN NUMBER IS
    v_num_txt VARCHAR2(80);
    v_num     NUMBER;
  BEGIN
    p_cod_iso := NULL;
    IF p_valor IS NULL OR p_valor NOT LIKE ':DEAL//%' THEN
      RETURN NULL;
    END IF;

    p_cod_iso := REGEXP_SUBSTR(p_valor, '^:DEAL//([A-Z]{3})', 1, 1, NULL, 1);
    v_num_txt := REGEXP_SUBSTR(p_valor, '^:DEAL//[A-Z]{3}([0-9]+([,\.][0-9]+)?)', 1, 1, NULL, 1);
    IF v_num_txt IS NULL THEN
      RETURN NULL;
    END IF;

    v_num_txt := REPLACE(TRIM(v_num_txt), ',', '.');
    v_num := TO_NUMBER(v_num_txt, '999999999999999D999999', 'NLS_NUMERIC_CHARACTERS=.,');
    RETURN v_num;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END lf_parse_deal;

  ---------------------------------------------------------------------------
  FUNCTION lf_parse_fec_swift (p_valor IN VARCHAR2) RETURN DATE IS
    v_fec VARCHAR2(8);
  BEGIN
    IF p_valor IS NULL THEN
      RETURN NULL;
    ELSIF p_valor LIKE ':SETT//%' THEN
      v_fec := SUBSTR(p_valor, 8, 8);
    ELSIF p_valor LIKE ':TERM//%' THEN
      v_fec := SUBSTR(p_valor, 8, 8);
    ELSE
      RETURN NULL;
    END IF;
    RETURN TO_DATE(v_fec, 'YYYYMMDD');
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END lf_parse_fec_swift;

  ---------------------------------------------------------------------------
  FUNCTION lf_parse_tasa (p_valor IN VARCHAR2) RETURN NUMBER IS
    v_txt VARCHAR2(40);
  BEGIN
    IF p_valor IS NULL OR p_valor NOT LIKE ':REPO//%' THEN
      RETURN NULL;
    END IF;
    v_txt := REPLACE(TRIM(SUBSTR(p_valor, 8)), ',', '.');
    RETURN TO_NUMBER(v_txt, '999D999999', 'NLS_NUMERIC_CHARACTERS=.,');
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END lf_parse_tasa;

  ---------------------------------------------------------------------------
  FUNCTION lf_map_moneda_iso (p_iso IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    IF p_iso IS NULL THEN
      RETURN NULL;
    END IF;
    IF p_iso = pas_snp.g_cod_mon_iso_local THEN
      RETURN pas_snp.g_cod_mon_local;
    END IF;
    RETURN p_iso;
  END lf_map_moneda_iso;

  ---------------------------------------------------------------------------
  FUNCTION lf_obt_ref_547 (p_ref_543 IN VARCHAR2) RETURN VARCHAR2 IS
    v_ref_547 ge_snp_mensajes.nro_referencia%TYPE;
  BEGIN
    SELECT g.nro_referencia
      INTO v_ref_547
      FROM ge_snp_mensajes g
     WHERE g.cod_msj_swift  = 547
       AND g.nro_ref_externa = p_ref_543
       AND ROWNUM = 1;
    RETURN v_ref_547;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RETURN NULL;
  END lf_obt_ref_547;

  ---------------------------------------------------------------------------
  FUNCTION lf_cnt_cta_estado (
    p_ref_543       IN VARCHAR2,
    p_cod_modalidad IN NUMBER,
    p_estado        IN VARCHAR2
  ) RETURN NUMBER IS
    v_cnt NUMBER;
  BEGIN
    SELECT COUNT(*)
      INTO v_cnt
      FROM md_cta_documentos d
     WHERE d.cod_modulo    = C_COD_MODULO
       AND d.cod_modalidad = p_cod_modalidad
       AND d.nro_documento = p_ref_543
       AND d.estado        = p_estado;
    RETURN v_cnt;
  END lf_cnt_cta_estado;

  ---------------------------------------------------------------------------
  PROCEDURE pp_procesar_campo (
    p_campo  IN VARCHAR2,
    p_valor  IN VARCHAR2,
    p_parseo IN OUT t_parseo_dato_cuenta
  ) IS
    v_cod_iso VARCHAR2(3);
    v_deal    NUMBER;
  BEGIN
    IF p_campo = '16R' THEN
      p_parseo.bloque := TRIM(p_valor);
    ELSIF p_campo = '16S' THEN
      p_parseo.bloque := NULL;
    ELSIF p_campo = '19A' AND p_valor LIKE ':DEAL//%' THEN
      v_deal := lf_parse_deal(p_valor, v_cod_iso);
      IF p_parseo.bloque = 'AMT' THEN
        p_parseo.amt := v_deal;
        IF p_parseo.dato.cod_moneda IS NULL AND v_cod_iso IS NOT NULL THEN
          p_parseo.dato.cod_moneda := lf_map_moneda_iso(v_cod_iso);
        END IF;
      ELSIF p_parseo.bloque = 'REPO' THEN
        p_parseo.repo := v_deal;
      END IF;
    ELSIF p_campo = '98A' THEN
      IF p_valor LIKE ':SETT//%' AND p_parseo.dato.fec_inicio IS NULL THEN
        p_parseo.dato.fec_inicio := lf_parse_fec_swift(p_valor);
      ELSIF p_parseo.bloque = 'REPO' AND p_valor LIKE ':TERM//%' THEN
        p_parseo.dato.fec_vencimiento := lf_parse_fec_swift(p_valor);
      END IF;
    ELSIF p_campo = '92A'
          AND p_parseo.bloque = 'REPO'
          AND p_valor LIKE ':REPO//%' THEN
      p_parseo.dato.tasa := lf_parse_tasa(p_valor);
    END IF;
  END pp_procesar_campo;

  ---------------------------------------------------------------------------
  FUNCTION fu_obt_dat_cuenta (
    p_nro_referencia IN VARCHAR2
  ) RETURN t_dat_cuenta_fli_repo IS
    v_parseo  t_parseo_dato_cuenta;
    v_cnt_snp NUMBER;
    v_cod_msj VARCHAR2(10);
  BEGIN
    SELECT COUNT(*)
      INTO v_cnt_snp
      FROM sb_snp_mensajes s
     WHERE s.nro_referencia = p_nro_referencia;

    IF v_cnt_snp > 0 THEN
      FOR r IN (
        SELECT s.campo, s.valor
          FROM sb_snp_mensajes s
         WHERE s.nro_referencia = p_nro_referencia
         ORDER BY s.orden
      ) LOOP
        pp_procesar_campo(r.campo, r.valor, v_parseo);
      END LOOP;
    ELSE
      -- Mismo procesamiento: sb_snp aún no persistido (trigger post ge_snp_mensajes).
      v_cod_msj := 'MT' || REGEXP_SUBSTR(p_nro_referencia, '/([0-9]+)$', 1, 1, NULL, 1);
      IF v_cod_msj <> 'MT' THEN
        FOR r IN (
          SELECT s.campo, s.valor
            FROM sb_snp_mensajes_tmp s
           WHERE s.cod_mensaje = v_cod_msj
           ORDER BY s.orden
        ) LOOP
          pp_procesar_campo(r.campo, r.valor, v_parseo);
        END LOOP;
      END IF;
    END IF;

    v_parseo.dato.monto       := v_parseo.amt;
    v_parseo.dato.deal_total  := v_parseo.repo;
    v_parseo.dato.mto_interes := GREATEST(NVL(v_parseo.repo, 0) - NVL(v_parseo.amt, 0), 0);

    RETURN v_parseo.dato;
  END fu_obt_dat_cuenta;

  ---------------------------------------------------------------------------
  -- Verifica si ya existe en md_cta_documentos/ge_cuentas para que no salte la PK
  FUNCTION lf_nro_cuenta_ocupado (
    p_nro_cuenta IN VARCHAR2
  ) RETURN BOOLEAN IS
    v_dummy NUMBER;
  BEGIN
    SELECT 1
      INTO v_dummy
      FROM dual
     WHERE EXISTS (
             SELECT 1
               FROM ge_cuentas g
              WHERE g.nro_cuenta = p_nro_cuenta
           )
        OR EXISTS (
             SELECT 1
               FROM md_cta_documentos d
              WHERE d.nro_cuenta = p_nro_cuenta
           );
    RETURN TRUE;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RETURN FALSE;
  END lf_nro_cuenta_ocupado;

  ---------------------------------------------------------------------------
  -- Una pedida a fug_obt_sig_nro_cuenta en TX autonoma
  -- Cada llamada es autonoma propia: permite reintentar en loop sin romper TX.
  FUNCTION lf_pedir_sig_nro_cuenta (
    p_cod_modalidad IN NUMBER,
    p_cod_moneda    IN VARCHAR2
  ) RETURN VARCHAR2 IS
    PRAGMA AUTONOMOUS_TRANSACTION;
    v_nro_cuenta VARCHAR2(30);
  BEGIN
    v_nro_cuenta := fug_obt_sig_nro_cuenta(
      C_COD_MODULO,
      p_cod_modalidad,
      C_COD_OFICINA_DEF,
      p_cod_moneda,
      C_COD_PERSONA_BCP
    );
    -- fug_obt_sig_nro_cuenta ya hace COMMIT (cierra esta TX autonoma).
    RETURN v_nro_cuenta;
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      RAISE;
  END lf_pedir_sig_nro_cuenta;

  ---------------------------------------------------------------------------
  -- Siguiente nro libre: si el de la semilla ya existe, pide el siguiente
  -- (hasta C_MAX_REINT_NRO). Evita error 702 por choque con cuentas ajenas.
  FUNCTION lf_obt_sig_nro_cuenta (
    p_cod_modalidad IN NUMBER,
    p_cod_moneda    IN VARCHAR2
  ) RETURN VARCHAR2 IS
    v_nro_cuenta VARCHAR2(30);
    v_saltados   NUMBER := 0;
  BEGIN
    FOR i IN 1 .. C_MAX_REINT_NRO LOOP
      v_nro_cuenta := lf_pedir_sig_nro_cuenta(p_cod_modalidad, p_cod_moneda);
      IF NOT lf_nro_cuenta_ocupado(v_nro_cuenta) THEN
        IF v_saltados > 0 THEN
          lf_log_blando(
            'LF_OBT_SIG_NRO_CUENTA: saltados=' || v_saltados
              || ' | libre=' || v_nro_cuenta
              || ' | mod=' || p_cod_modalidad
          );
        END IF;
        RETURN v_nro_cuenta;
      END IF;
      v_saltados := v_saltados + 1;
    END LOOP;

    RAISE_APPLICATION_ERROR(
      -20021,
      'PAM_FRC: sin nro_cuenta libre tras '
        || C_MAX_REINT_NRO
        || ' intentos | mod='
        || p_cod_modalidad
        || ' | ultimo='
        || v_nro_cuenta
    );
  END lf_obt_sig_nro_cuenta;

  ---------------------------------------------------------------------------
  PROCEDURE pp_ins_cabecera_cta (
    p_ref_543       IN VARCHAR2,
    p_cod_modalidad IN NUMBER,
    p_dat           IN t_dat_cuenta_fli_repo,
    p_nro_cuenta    OUT VARCHAR2
  ) IS
    v_denominacion VARCHAR2(200);
  BEGIN
    p_nro_cuenta   := NULL;
    v_denominacion := lf_obt_denominacion_bcp();

    p_nro_cuenta := lf_obt_sig_nro_cuenta(
      p_cod_modalidad,
      p_dat.cod_moneda
    );

    INSERT INTO md_cta_documentos (
      cod_modulo, nro_cuenta, cod_modalidad, cod_oficina, cod_moneda,
      cod_persona, nro_documento, denominacion, fec_inicio, fec_vencimiento,
      fec_ven_repo, monto, val_tasa, cantidad, estado, mto_interes, sal_interes,
      val_presente, sal_val_presente, sal_disponible, nro_cta_repo
    ) VALUES (
      C_COD_MODULO, p_nro_cuenta, p_cod_modalidad, C_COD_OFICINA_DEF, p_dat.cod_moneda,
      C_COD_PERSONA_BCP, p_ref_543, v_denominacion,
      p_dat.fec_inicio, p_dat.fec_vencimiento, p_dat.fec_vencimiento,
      p_dat.monto, NVL(p_dat.tasa, 0), 0, 'S', p_dat.mto_interes, p_dat.mto_interes,
      p_dat.monto, p_dat.monto, p_dat.monto, NULL
    );
  END pp_ins_cabecera_cta;

  ---------------------------------------------------------------------------
  PROCEDURE pp_act_estado_cta (
    p_ref_543       IN VARCHAR2,
    p_cod_modalidad IN NUMBER,
    p_estado_desde  IN VARCHAR2,
    p_estado_hasta  IN VARCHAR2,
    p_fecha         IN DATE,
    p_hora          IN ge_movimientos.hora%TYPE,
    p_nro_secuencia IN OUT NUMBER
  ) IS
    v_nro_cuenta  md_cta_documentos.nro_cuenta%TYPE;
    v_cod_moneda  md_cta_documentos.cod_moneda%TYPE;
    v_cod_oficina md_cta_documentos.cod_oficina%TYPE;
    r_movimiento  ge_movimientos%ROWTYPE;
  BEGIN
    UPDATE md_cta_documentos d
       SET d.estado           = p_estado_hasta,
           d.val_int_devengar = NULL,
           d.fec_cancelacion  = CASE
                                   WHEN p_estado_hasta = 'N'
                                     THEN TO_CHAR(pag_cal.fu_obt_fec_actual(10), 'DD/MM/YYYY')
                                   ELSE d.fec_cancelacion
                                 END
     WHERE d.cod_modulo    = C_COD_MODULO
       AND d.cod_modalidad = p_cod_modalidad
       AND d.nro_documento = p_ref_543
       AND d.estado        = p_estado_desde;

    IF SQL%ROWCOUNT = 0 THEN
      lf_set_error(
        703,
        'PP_ACT_ESTADO_CTA: transicion invalida'
          || ' | ref_543=' || p_ref_543
          || ' | mod=' || p_cod_modalidad
          || ' | ' || p_estado_desde || '->' || p_estado_hasta
      );
      RETURN;
    END IF;

    SELECT d.nro_cuenta, d.cod_moneda, d.cod_oficina
      INTO v_nro_cuenta, v_cod_moneda, v_cod_oficina
      FROM md_cta_documentos d
     WHERE d.cod_modulo    = C_COD_MODULO
       AND d.cod_modalidad = p_cod_modalidad
       AND d.nro_documento = p_ref_543
       AND d.estado        = p_estado_hasta
       AND ROWNUM = 1;

    -- Movimiento 401: corresponde al cambio de estado de la cuenta (no genera asientos)
    p_nro_secuencia := NVL(p_nro_secuencia, 0) + 1;
    r_movimiento := NULL;
    r_movimiento.fecha           := p_fecha;
    r_movimiento.hora            := p_hora;
    r_movimiento.cod_usuario     := SUBSTR(USER, 1, 10);
    r_movimiento.nro_secuencia   := p_nro_secuencia;
    r_movimiento.fec_valor       := p_fecha;
    r_movimiento.nro_cuenta      := v_nro_cuenta;
    r_movimiento.cod_moneda      := NVL(v_cod_moneda, 'GS');
    r_movimiento.cod_oficina     := NVL(v_cod_oficina, C_COD_OFICINA_DEF);
    r_movimiento.estado          := 'N';
    r_movimiento.est_cuenta      := p_estado_hasta;
    r_movimiento.cod_ofi_origen  := NVL(v_cod_oficina, C_COD_OFICINA_DEF);
    r_movimiento.concepto        := 'Cambio de Estado';
    r_movimiento.reversado       := 'N';
    r_movimiento.emi_aviso       := 'N';
    r_movimiento.protegido       := 'N';
    r_movimiento.cod_tra_padre   := C_TRA_PADRE;
    r_movimiento.cod_mod_padre   := C_COD_MODULO;
    r_movimiento.cod_mad_padre   := p_cod_modalidad;
    r_movimiento.cod_transaccion := C_TRA_CAMBIO_EST;
    r_movimiento.cod_modulo      := C_COD_MODULO;
    r_movimiento.cod_modalidad   := p_cod_modalidad;
    r_movimiento.nro_documento   := v_nro_cuenta;
    pag_gen.pr_ins_ge_movimiento(r_movimiento);
  EXCEPTION
    WHEN OTHERS THEN
      lf_set_error(
        C_ERR_PARAM_CAT,
        'PP_ACT_ESTADO_CTA: ' || SQLERRM
          || ' | ref_543=' || p_ref_543
          || ' | ' || p_estado_desde || '->' || p_estado_hasta
      );
  END pp_act_estado_cta;

  ---------------------------------------------------------------------------
  PROCEDURE pp_ins_geo_cta_clientes (
    p_cod_modulo    IN NUMBER,
    p_cod_modalidad IN NUMBER,
    p_nro_cuenta    IN VARCHAR2,
    p_cod_persona   IN NUMBER
  ) IS
  BEGIN
    INSERT INTO ge_cta_clientes (
      cod_persona, nro_cuenta, dig_verificador, cod_oficina,
      cod_modulo, cod_modalidad, relacion
    ) VALUES (
      p_cod_persona, p_nro_cuenta, 0, C_COD_OFICINA_DEF,
      p_cod_modulo, p_cod_modalidad, 'P'
    );
  END pp_ins_geo_cta_clientes;

  ---------------------------------------------------------------------------
  PROCEDURE pr_pro_cta_alta (
    p_nro_referencia IN VARCHAR2,
    p_ref_543        IN VARCHAR2,
    p_tip_producto   IN VARCHAR2 DEFAULT NULL,
    p_fecha          IN DATE,
    p_hora           IN ge_movimientos.hora%TYPE,
    p_nro_secuencia  IN OUT NUMBER
  ) IS
    v_cod_modalidad NUMBER;
    v_ref_547       VARCHAR2(60);
    v_dat           t_dat_cuenta_fli_repo;
    v_nro_cuenta    md_cta_documentos.nro_cuenta%TYPE;
    v_cnt_e         NUMBER;
    v_cnt_s         NUMBER;
  BEGIN
    IF NVL(UPPER(TRIM(p_tip_producto)), 'ILF') = 'TPREPO' THEN
      v_cod_modalidad := C_COD_MOD_TPREPO;
    ELSE
      v_cod_modalidad := C_COD_MOD_FLI;
    END IF;

    v_cnt_e := lf_cnt_cta_estado(p_ref_543, v_cod_modalidad, 'E');
    IF v_cnt_e > 1 THEN
      lf_set_error(
        707,
        'PR_PRO_CTA_ALTA: multiples cuentas en E'
          || ' | ref_543=' || p_ref_543
          || ' | mod=' || v_cod_modalidad
      );
      RETURN;
    END IF;
    IF v_cnt_e = 1 THEN
      RETURN;
    END IF;

    v_cnt_s := lf_cnt_cta_estado(p_ref_543, v_cod_modalidad, 'S');
    IF v_cnt_s = 1 THEN
      pp_act_estado_cta(
        p_ref_543, v_cod_modalidad, 'S', 'E',
        p_fecha, p_hora, p_nro_secuencia
      );
      IF g_cod_error <> 0 THEN
        RETURN;
      END IF;
      RETURN;
    END IF;
    IF v_cnt_s > 1 THEN
      lf_set_error(
        707,
        'PR_PRO_CTA_ALTA: multiples cuentas en S'
          || ' | ref_543=' || p_ref_543
          || ' | mod=' || v_cod_modalidad
      );
      RETURN;
    END IF;

    IF lf_cnt_cta_estado(p_ref_543, v_cod_modalidad, 'N') > 0 THEN
      lf_set_error(
        702,
        'PR_PRO_CTA_ALTA: cuenta cerrada para ref_543'
          || ' | ref_543=' || p_ref_543
          || ' | mod=' || v_cod_modalidad
      );
      RETURN;
    END IF;

    v_ref_547 := lf_obt_ref_547(p_ref_543);
    IF v_ref_547 IS NULL THEN
      lf_set_error(
        705,
        'PR_PRO_CTA_ALTA: MT547 no encontrado'
          || ' | ref_543=' || p_ref_543
          || ' | nro_ref_506=' || p_nro_referencia
      );
      RETURN;
    END IF;

    v_dat := fu_obt_dat_cuenta(v_ref_547);

    IF v_dat.cod_moneda IS NULL OR v_dat.cod_moneda <> 'GS' THEN
      lf_log_blando(
        'PR_PRO_CTA_ALTA skip moneda'
          || ' | ref_543=' || p_ref_543
          || ' | ref_547=' || v_ref_547
          || ' | moneda=' || NVL(v_dat.cod_moneda, '(null)')
      );
      RETURN;
    END IF;

    IF v_dat.monto IS NULL OR v_dat.fec_vencimiento IS NULL THEN
      lf_set_error(
        707,
        'PR_PRO_CTA_ALTA: datos cabecera incompletos'
          || ' | ref_547=' || v_ref_547
          || ' | monto=' || NVL(TO_CHAR(v_dat.monto), '(null)')
          || ' | fec_venc=' || NVL(TO_CHAR(v_dat.fec_vencimiento, 'YYYYMMDD'), '(null)')
      );
      RETURN;
    END IF;

    IF NVL(v_dat.mto_interes, 0) < 0 THEN
      lf_log_blando(
        'PR_PRO_CTA_ALTA: mto_interes negativo'
          || ' | ref_547=' || v_ref_547
          || ' | interes=' || v_dat.mto_interes
      );
      lf_set_error(707, 'PR_PRO_CTA_ALTA: mto_interes invalido | ref_547=' || v_ref_547);
      RETURN;
    END IF;

    pp_ins_cabecera_cta(
      p_ref_543       => p_ref_543,
      p_cod_modalidad => v_cod_modalidad,
      p_dat           => v_dat,
      p_nro_cuenta    => v_nro_cuenta
    );

    pp_ins_geo_cta_clientes(
      p_cod_modulo    => C_COD_MODULO,
      p_cod_modalidad => v_cod_modalidad,
      p_nro_cuenta    => v_nro_cuenta,
      p_cod_persona   => C_COD_PERSONA_BCP
    );

    pp_act_estado_cta(
      p_ref_543, v_cod_modalidad, 'S', 'E',
      p_fecha, p_hora, p_nro_secuencia
    );

    IF g_cod_error <> 0 THEN
      RETURN;
    END IF;

  EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
      lf_set_error(
        702,
        'PR_PRO_CTA_ALTA: duplicado'
          || ' | ref_543=' || p_ref_543
          || ' | mod=' || v_cod_modalidad
          || ' | ' || SQLERRM
      );
  END pr_pro_cta_alta;

  ---------------------------------------------------------------------------
  PROCEDURE pr_pro_cta_conversion (
    p_nro_referencia IN VARCHAR2,
    p_ref_543        IN VARCHAR2,
    p_fecha          IN DATE,
    p_hora           IN ge_movimientos.hora%TYPE,
    p_nro_secuencia  IN OUT NUMBER
  ) IS
    v_dat         t_dat_cuenta_fli_repo;
    v_nro_cuenta  md_cta_documentos.nro_cuenta%TYPE;
    v_nro_cta_138 md_cta_documentos.nro_cuenta%TYPE;
  BEGIN
    IF lf_cnt_cta_estado(p_ref_543, C_COD_MOD_REPO_ON, 'E') = 1 THEN
      RETURN;
    END IF;
    IF lf_cnt_cta_estado(p_ref_543, C_COD_MOD_REPO_ON, 'S') = 1 THEN
      pp_act_estado_cta(
        p_ref_543, C_COD_MOD_REPO_ON, 'S', 'E',
        p_fecha, p_hora, p_nro_secuencia
      );
      RETURN;
    END IF;

    BEGIN
      SELECT d.nro_cuenta
        INTO v_nro_cta_138
        FROM md_cta_documentos d
       WHERE d.cod_modulo    = C_COD_MODULO
         AND d.cod_modalidad = C_COD_MOD_FLI
         AND d.nro_documento = p_ref_543
         AND d.estado        = 'E';
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        lf_set_error(
          706,
          'PR_PRO_CTA_CONVERSION: sin cuenta 138 en E'
            || ' | ref_543=' || p_ref_543
            || ' | nro_ref_546=' || p_nro_referencia
        );
        RETURN;
      WHEN TOO_MANY_ROWS THEN
        lf_set_error(
          704,
          'PR_PRO_CTA_CONVERSION: multiples cuentas 138 en E'
            || ' | ref_543=' || p_ref_543
        );
        RETURN;
    END;

    v_dat := fu_obt_dat_cuenta(p_nro_referencia);

    IF v_dat.cod_moneda IS NULL OR v_dat.cod_moneda <> 'GS' THEN
      lf_log_blando(
        'PR_PRO_CTA_CONVERSION skip moneda'
          || ' | ref_543=' || p_ref_543
          || ' | moneda=' || NVL(v_dat.cod_moneda, '(null)')
      );
      RETURN;
    END IF;

    IF v_dat.monto IS NULL OR v_dat.fec_vencimiento IS NULL THEN
      lf_set_error(
        707,
        'PR_PRO_CTA_CONVERSION: datos cabecera incompletos'
          || ' | nro_ref_546=' || p_nro_referencia
      );
      RETURN;
    END IF;

    pp_act_estado_cta(
      p_ref_543, C_COD_MOD_FLI, 'E', 'N',
      p_fecha, p_hora, p_nro_secuencia
    );
    IF g_cod_error <> 0 THEN
      RETURN;
    END IF;

    pp_ins_cabecera_cta(
      p_ref_543       => p_ref_543,
      p_cod_modalidad => C_COD_MOD_REPO_ON,
      p_dat           => v_dat,
      p_nro_cuenta    => v_nro_cuenta
    );

    UPDATE md_cta_documentos d
       SET d.nro_cta_repo = v_nro_cta_138
     WHERE d.cod_modulo    = C_COD_MODULO
       AND d.cod_modalidad = C_COD_MOD_REPO_ON
       AND d.nro_documento = p_ref_543
       AND d.nro_cuenta    = v_nro_cuenta
       AND d.estado        = 'S';

    pp_ins_geo_cta_clientes(
      p_cod_modulo    => C_COD_MODULO,
      p_cod_modalidad => C_COD_MOD_REPO_ON,
      p_nro_cuenta    => v_nro_cuenta,
      p_cod_persona   => C_COD_PERSONA_BCP
    );

    pp_act_estado_cta(
      p_ref_543, C_COD_MOD_REPO_ON, 'S', 'E',
      p_fecha, p_hora, p_nro_secuencia
    );

  EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
      lf_set_error(
        702,
        'PR_PRO_CTA_CONVERSION: duplicado'
          || ' | ref_543=' || p_ref_543
          || ' | ' || SQLERRM
      );
  END pr_pro_cta_conversion;

  ---------------------------------------------------------------------------
  PROCEDURE pr_pro_cta_cancelacion (
    p_nro_referencia IN VARCHAR2,
    p_ref_543        IN VARCHAR2,
    p_fecha          IN DATE,
    p_hora           IN ge_movimientos.hora%TYPE,
    p_nro_secuencia  IN OUT NUMBER,
    p_nro_cuenta     OUT md_cta_documentos.nro_cuenta%TYPE,
    p_cod_modalidad  OUT NUMBER
  ) IS
    v_cod_modalidad NUMBER;
    v_nro_cuenta    md_cta_documentos.nro_cuenta%TYPE;
    v_cnt_e         NUMBER;
    v_cnt_n         NUMBER;
  BEGIN
    p_nro_cuenta    := NULL;
    p_cod_modalidad := NULL;

    SELECT COUNT(*)
      INTO v_cnt_e
      FROM md_cta_documentos d
     WHERE d.cod_modulo    = C_COD_MODULO
       AND d.cod_modalidad IN (C_COD_MOD_FLI, C_COD_MOD_REPO_ON, C_COD_MOD_TPREPO)
       AND d.nro_documento = p_ref_543
       AND d.estado        = 'E';

    IF v_cnt_e = 0 THEN
      SELECT COUNT(*)
        INTO v_cnt_n
        FROM md_cta_documentos d
       WHERE d.cod_modulo    = C_COD_MODULO
         AND d.cod_modalidad IN (C_COD_MOD_FLI, C_COD_MOD_REPO_ON, C_COD_MOD_TPREPO)
         AND d.nro_documento = p_ref_543
         AND d.estado        = 'N';
      IF v_cnt_n > 0 THEN
        RETURN;
      END IF;
      lf_set_error(
        707,
        'PR_PRO_CTA_CANCELACION: sin cuenta vigente'
          || ' | ref_543=' || p_ref_543
          || ' | nro_ref_545=' || p_nro_referencia
      );
      RETURN;
    END IF;

    IF v_cnt_e > 1 THEN
      lf_set_error(
        704,
        'PR_PRO_CTA_CANCELACION: multiples cuentas en E'
          || ' | ref_543=' || p_ref_543
      );
      RETURN;
    END IF;

    BEGIN
      SELECT d.cod_modalidad, d.nro_cuenta
        INTO v_cod_modalidad, v_nro_cuenta
        FROM md_cta_documentos d
       WHERE d.cod_modulo    = C_COD_MODULO
         AND d.cod_modalidad IN (C_COD_MOD_FLI, C_COD_MOD_REPO_ON, C_COD_MOD_TPREPO)
         AND d.nro_documento = p_ref_543
         AND d.estado        = 'E';
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        RETURN;
    END;

    pp_act_estado_cta(
      p_ref_543, v_cod_modalidad, 'E', 'N',
      p_fecha, p_hora, p_nro_secuencia
    );
    IF g_cod_error <> 0 THEN
      RETURN;
    END IF;

    -- Cuenta/modalidad cerradas en esta pasada (evitar SELECT ambiguo sobre varias N).
    p_nro_cuenta    := v_nro_cuenta;
    p_cod_modalidad := v_cod_modalidad;
  END pr_pro_cta_cancelacion;

  ---------------------------------------------------------------------------
  FUNCTION fu_obt_cod_error RETURN NUMBER IS
  BEGIN
    RETURN g_cod_error;
  END fu_obt_cod_error;

  ---------------------------------------------------------------------------
  FUNCTION fu_obt_msj_error RETURN VARCHAR2 IS
  BEGIN
    RETURN g_msj_error;
  END fu_obt_msj_error;

  ---------------------------------------------------------------------------
  FUNCTION fu_res_ref_543 (
    p_cod_msj_swift   IN VARCHAR2,
    p_nro_referencia  IN VARCHAR2,
    p_ref_543         IN VARCHAR2 DEFAULT NULL,
    p_msj_swift       IN CLOB DEFAULT NULL
  ) RETURN VARCHAR2 IS
    C_PAT_REF_543 CONSTANT VARCHAR2(32) := '^R[0-9A-Z]+/543$';
    v_ref         VARCHAR2(60);

    -------------------------------------------------------------------------
    FUNCTION lf_norm_txt (p_val IN VARCHAR2) RETURN VARCHAR2 IS
    BEGIN
      IF p_val IS NULL THEN
        RETURN NULL;
      END IF;
      RETURN REGEXP_REPLACE(TRIM(p_val), '[[:cntrl:]]', '');
    END lf_norm_txt;

    -------------------------------------------------------------------------
    FUNCTION lf_ver_ref_543 (p_val IN VARCHAR2) RETURN BOOLEAN IS
    BEGIN
      RETURN lf_norm_txt(p_val) IS NOT NULL
         AND REGEXP_LIKE(lf_norm_txt(p_val), C_PAT_REF_543);
    END lf_ver_ref_543;

    -------------------------------------------------------------------------
    FUNCTION lf_obt_msj_swift (
      p_nro_ref IN VARCHAR2,
      p_cod_msj IN VARCHAR2
    ) RETURN CLOB IS
      v_msj CLOB;
    BEGIN
      SELECT NVL(m.msj_swi_original, TO_CLOB(m.msj_swift))
        INTO v_msj
        FROM ge_snp_mensajes m
       WHERE m.nro_referencia = p_nro_ref
         AND m.cod_msj_swift  = TO_NUMBER(p_cod_msj)
         AND ROWNUM = 1;
      RETURN v_msj;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        RETURN NULL;
    END lf_obt_msj_swift;

    -------------------------------------------------------------------------
    FUNCTION lf_obt_val_campo_msj (
      p_msj     IN CLOB,
      p_patron  IN VARCHAR2
    ) RETURN VARCHAR2 IS
    BEGIN
      IF p_msj IS NULL THEN
        RETURN NULL;
      END IF;
      RETURN lf_norm_txt(REGEXP_SUBSTR(p_msj, p_patron, 1, 1, NULL, 1));
    END lf_obt_val_campo_msj;

    -------------------------------------------------------------------------
    FUNCTION lf_obt_ref_comm_546 (p_nro_ref_546 IN VARCHAR2) RETURN VARCHAR2 IS
      v_msj  CLOB;
      v_comm VARCHAR2(60);
    BEGIN
      v_msj := lf_obt_msj_swift(p_nro_ref_546, '546');
      IF v_msj IS NULL AND p_msj_swift IS NOT NULL THEN
        v_msj := p_msj_swift;
      END IF;
      v_comm := lf_obt_val_campo_msj(v_msj, '20C::COMM//([^*:\r\n]+)');
      IF lf_ver_ref_543(v_comm) THEN
        RETURN lf_norm_txt(v_comm);
      END IF;
      IF p_msj_swift IS NOT NULL THEN
        v_comm := lf_obt_val_campo_msj(p_msj_swift, '20C::COMM//([^*:\r\n]+)');
        IF lf_ver_ref_543(v_comm) THEN
          RETURN lf_norm_txt(v_comm);
        END IF;
      END IF;
      RETURN NULL;
    END lf_obt_ref_comm_546;

    -------------------------------------------------------------------------
    FUNCTION lf_obt_ref_prev_desde_542 (p_nro_ref_542 IN VARCHAR2) RETURN VARCHAR2 IS
      v_msj_542 CLOB;
      v_prev    VARCHAR2(60);
    BEGIN
      IF p_nro_ref_542 IS NULL
         OR NOT REGEXP_LIKE(TRIM(p_nro_ref_542), '^\d+$') THEN
        RETURN NULL;
      END IF;

      BEGIN
        SELECT t.msj_swift
          INTO v_msj_542
          FROM ge_snp_transferencias t
         WHERE t.nro_referencia = TO_NUMBER(TRIM(p_nro_ref_542))
           AND t.cod_msj_swift  = 542
           AND ROWNUM = 1;

        v_prev := lf_obt_val_campo_msj(v_msj_542, '20C::PREV//([^*:\r\n]+)');
        IF lf_ver_ref_543(v_prev) THEN
          RETURN TRIM(v_prev);
        END IF;
      EXCEPTION
        WHEN OTHERS THEN NULL;
      END;

      RETURN NULL;
    END lf_obt_ref_prev_desde_542;

    -------------------------------------------------------------------------
    FUNCTION lf_obt_ref_prev_546 (p_nro_ref_546 IN VARCHAR2) RETURN VARCHAR2 IS
      v_msj       CLOB;
      v_msj_542   CLOB;
      v_link      VARCHAR2(10);
      v_rela_542  VARCHAR2(60);
      v_prev      VARCHAR2(60);
    BEGIN
      v_msj := lf_obt_msj_swift(p_nro_ref_546, '546');
      IF v_msj IS NULL AND p_msj_swift IS NOT NULL THEN
        v_msj := p_msj_swift;
      END IF;
      IF v_msj IS NULL THEN
        RETURN NULL;
      END IF;

      v_link := lf_obt_val_campo_msj(v_msj, '13A::LINK//([0-9]+)');
      IF v_link <> '542' THEN
        RETURN NULL;
      END IF;

      v_rela_542 := lf_obt_val_campo_msj(v_msj, '20C::RELA//([^*:\r\n]+)');

      BEGIN
        SELECT TRIM(SUBSTR(s.valor, 8))
          INTO v_prev
          FROM sb_snp_mensajes s
         WHERE s.nro_referencia = v_rela_542
           AND s.campo = '20C'
           AND INSTR(s.valor, 'PREV') > 0
           AND ROWNUM = 1;
        IF lf_ver_ref_543(v_prev) THEN
          RETURN v_prev;
        END IF;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN NULL;
      END;

      BEGIN
        SELECT t.msj_swift
          INTO v_msj_542
          FROM ge_snp_transferencias t
         WHERE t.nro_referencia = v_rela_542
           AND t.cod_msj_swift  = '542'
           AND ROWNUM = 1;

        v_prev := lf_obt_val_campo_msj(v_msj_542, '20C::PREV//([^*:\r\n]+)');
        IF lf_ver_ref_543(v_prev) THEN
          RETURN TRIM(v_prev);
        END IF;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN NULL;
      END;

      RETURN NULL;
    END lf_obt_ref_prev_546;

  BEGIN
    IF p_cod_msj_swift IS NULL OR p_nro_referencia IS NULL THEN
      RETURN NULL;
    END IF;

    IF p_cod_msj_swift = '546' THEN
      v_ref := lf_obt_ref_comm_546(p_nro_referencia);
      IF lf_ver_ref_543(v_ref) THEN
        RETURN v_ref;
      END IF;
      v_ref := lf_obt_ref_prev_546(p_nro_referencia);
      IF lf_ver_ref_543(v_ref) THEN
        RETURN v_ref;
      END IF;
      IF REGEXP_LIKE(TRIM(NVL(p_ref_543, 'x')), '^\d+$') THEN
        v_ref := lf_obt_ref_prev_desde_542(p_ref_543);
        IF lf_ver_ref_543(v_ref) THEN
          RETURN v_ref;
        END IF;
      END IF;
      RETURN NULL;
    END IF;

    IF p_cod_msj_swift IN ('506', '545')
       AND lf_ver_ref_543(p_ref_543) THEN
      RETURN TRIM(p_ref_543);
    END IF;

    RETURN NULL;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END fu_res_ref_543;

  ---------------------------------------------------------------------------
  PROCEDURE pr_pro_cta_msj_recibido (
    p_cod_msj_swift  IN VARCHAR2,
    p_nro_referencia IN VARCHAR2,
    p_ref_543        IN VARCHAR2 DEFAULT NULL,
    p_tip_producto   IN VARCHAR2 DEFAULT NULL,
    p_msj_swift      IN CLOB DEFAULT NULL
  ) IS
    v_ref_543       VARCHAR2(60);
    v_fecha         DATE := pag_cal.fu_obt_fec_actual(C_COD_MODULO);
    v_hora          ge_movimientos.hora%TYPE := TO_CHAR(SYSDATE, 'HH24:MI:SS');
    v_nro_secuencia NUMBER := 0;
    v_nro_cuenta    md_cta_documentos.nro_cuenta%TYPE;
    v_cod_modalidad NUMBER;
  BEGIN
    lf_limpiar_error;

    IF p_cod_msj_swift IS NULL OR p_nro_referencia IS NULL THEN
      lf_set_error(
        701,
        'PR_PRO_CTA_MSJ_RECIBIDO: parametros invalidos'
          || ' | mt=' || NVL(p_cod_msj_swift, '(null)')
          || ' | nro_ref=' || NVL(p_nro_referencia, '(null)')
      );
      RETURN;
    END IF;

    IF p_cod_msj_swift NOT IN ('506', '546', '545') THEN
      RETURN;
    END IF;

    v_ref_543 := fu_res_ref_543(
      p_cod_msj_swift  => p_cod_msj_swift,
      p_nro_referencia => p_nro_referencia,
      p_ref_543        => p_ref_543,
      p_msj_swift      => p_msj_swift
    );

    IF v_ref_543 IS NULL THEN
      lf_set_error(
        701,
        'PR_PRO_CTA_MSJ_RECIBIDO: ref_543 no resuelto'
          || ' | mt=' || p_cod_msj_swift
          || ' | nro_ref=' || p_nro_referencia
          || ' | p_hint=' || NVL(p_ref_543, '(null)')
      );
      RETURN;
    END IF;

    CASE p_cod_msj_swift
      WHEN '506' THEN
        pr_pro_cta_alta(
          p_nro_referencia => p_nro_referencia,
          p_ref_543        => v_ref_543,
          p_tip_producto   => p_tip_producto,
          p_fecha          => v_fecha,
          p_hora           => v_hora,
          p_nro_secuencia  => v_nro_secuencia
        );
      WHEN '546' THEN
        pr_pro_cta_conversion(
          p_nro_referencia => p_nro_referencia,
          p_ref_543        => v_ref_543,
          p_fecha          => v_fecha,
          p_hora           => v_hora,
          p_nro_secuencia  => v_nro_secuencia
        );
      WHEN '545' THEN
        pr_pro_cta_cancelacion(
          p_nro_referencia => p_nro_referencia,
          p_ref_543        => v_ref_543,
          p_fecha          => v_fecha,
          p_hora           => v_hora,
          p_nro_secuencia  => v_nro_secuencia,
          p_nro_cuenta     => v_nro_cuenta,
          p_cod_modalidad  => v_cod_modalidad
        );
    END CASE;

    -- Contabilizacion en la misma TX; continua fecha/hora/secuencia del 401.
    -- 545: solo si cancelacion devolvio modalidad (cerro E->N ahora); 
    IF g_cod_error = 0
       AND (p_cod_msj_swift <> '545' OR v_cod_modalidad IS NOT NULL) THEN
      BEGIN
        pr_pro_con_msj_recibido(
          p_cod_msj_swift  => p_cod_msj_swift,
          p_nro_referencia => p_nro_referencia,
          p_ref_543        => v_ref_543,
          p_fecha          => v_fecha,
          p_hora           => v_hora,
          p_nro_secuencia  => v_nro_secuencia,
          p_nro_cuenta     => v_nro_cuenta,
          p_cod_modalidad  => v_cod_modalidad
        );
      EXCEPTION
        WHEN OTHERS THEN
          IF g_cod_error = 0 THEN
            lf_set_error(
              C_ERR_PARAM_CAT,
              'PR_PRO_CTA_MSJ_RECIBIDO: error contabilizando'
                || ' | mt=' || p_cod_msj_swift
                || ' | ' || SQLERRM
            );
          END IF;
      END;
    END IF;
  END pr_pro_cta_msj_recibido;

  ---------------------------------------------------------------------------
  -- Contabilizacion — API publica
  ---------------------------------------------------------------------------

  -- Monto a asentar en baja/alta DEAL: FLI=capital; REPO=capital+interes
  FUNCTION fu_obt_monto_baja (
    p_cod_modalidad IN NUMBER,
    p_monto_capital IN NUMBER,
    p_monto_interes IN NUMBER DEFAULT 0
  ) RETURN NUMBER IS
  BEGIN
    IF p_cod_modalidad = 138 THEN
      RETURN NVL(p_monto_capital, 0);
    END IF;
    RETURN NVL(p_monto_capital, 0) + NVL(p_monto_interes, 0);
  END fu_obt_monto_baja;

  ---------------------------------------------------------------------------
  -- Inserta un movimiento
  ---------------------------------------------------------------------------
  PROCEDURE pp_ins_movimiento (
    p_movimiento      IN OUT ge_movimientos%ROWTYPE,
    p_fecha           IN DATE,
    p_hora            IN VARCHAR2,
    p_secuencia       IN OUT NUMBER,
    p_cod_modalidad   IN NUMBER,
    p_nro_cuenta      IN VARCHAR2,
    p_cod_moneda      IN VARCHAR2,
    p_cod_transaccion IN NUMBER,
    p_monto           IN NUMBER,
    p_concepto        IN VARCHAR2,
    p_cod_rubro       IN VARCHAR2 DEFAULT NULL,
    p_tip_mov_rubro   IN VARCHAR2 DEFAULT NULL,
    p_cod_mad_padre   IN NUMBER DEFAULT NULL
  ) IS
  BEGIN
    IF NVL(p_monto, 0) <= 0 THEN
      RETURN;
    END IF;

    p_secuencia := NVL(p_secuencia, 0) + 1;
    p_movimiento := NULL;
    p_movimiento.fecha           := p_fecha;
    p_movimiento.hora            := p_hora;
    p_movimiento.cod_usuario     := SUBSTR(USER, 1, 10);
    p_movimiento.nro_secuencia   := p_secuencia;
    p_movimiento.fec_valor       := p_fecha;
    p_movimiento.monto           := p_monto;
    p_movimiento.nro_cuenta      := p_nro_cuenta;
    p_movimiento.cod_moneda      := NVL(p_cod_moneda, 'GS');
    p_movimiento.cod_oficina     := C_COD_OFICINA_DEF;
    p_movimiento.estado          := 'N';
    p_movimiento.cod_ofi_origen  := C_COD_OFICINA_DEF;
    p_movimiento.concepto        := SUBSTR(p_concepto, 1, 100);
    IF p_cod_rubro IS NOT NULL THEN
      p_movimiento.cod_rubro := p_cod_rubro;
    END IF;
    p_movimiento.reversado       := 'N';
    p_movimiento.emi_aviso       := 'N';
    p_movimiento.protegido       := 'N';
    p_movimiento.cod_tra_padre   := C_TRA_PADRE;
    p_movimiento.cod_mod_padre   := C_COD_MODULO;
    p_movimiento.cod_mad_padre   := NVL(p_cod_mad_padre, p_cod_modalidad);
    p_movimiento.cod_transaccion := p_cod_transaccion;
    p_movimiento.cod_modulo      := C_COD_MODULO;
    p_movimiento.cod_modalidad   := p_cod_modalidad;
    p_movimiento.mto_equ_local   := p_monto;
    p_movimiento.cotizacion      := 1;
    IF p_tip_mov_rubro IS NOT NULL THEN
      p_movimiento.tip_mov_rubro := p_tip_mov_rubro;
    END IF;

    pag_gen.pr_ins_ge_movimiento(p_movimiento);
  EXCEPTION
    WHEN OTHERS THEN
      lf_set_error(
        C_ERR_PARAM_CAT,
        'PP_INS_MOVIMIENTO: ' || SQLERRM
          || ' | tra=' || p_cod_transaccion
          || ' | cta=' || p_nro_cuenta
      );
  END pp_ins_movimiento;

  -- Inserta movs de alta producto: 815+818; en REPO tambien 819 (interes)
  PROCEDURE pr_ins_mov_alta_producto (
    p_nro_cuenta       IN VARCHAR2,
    p_cod_modalidad    IN NUMBER,
    p_monto            IN NUMBER,
    p_mto_interes      IN NUMBER DEFAULT 0,
    p_cod_moneda       IN VARCHAR2 DEFAULT 'GS',
    p_fecha_movimiento IN DATE DEFAULT NULL,
    p_hora_movimiento  IN ge_movimientos.hora%TYPE DEFAULT NULL,
    p_nro_secuencia    IN OUT NUMBER
  ) IS
    r_movimiento ge_movimientos%ROWTYPE;
    v_fecha      DATE;
    v_hora       ge_movimientos.hora%TYPE;
    v_moneda     VARCHAR2(3);
    v_monto_alta NUMBER;
  BEGIN
    lf_limpiar_error;

    IF p_nro_cuenta IS NULL OR p_cod_modalidad IS NULL THEN
      lf_set_error(C_ERR_PARAM_CAT, 'PR_INS_MOV_ALTA_PRODUCTO: cuenta/modalidad nulos');
      RETURN;
    END IF;

    v_fecha := NVL(p_fecha_movimiento, pag_cal.fu_obt_fec_actual(C_COD_MODULO));
    v_hora := NVL(p_hora_movimiento, TO_CHAR(SYSDATE, 'HH24:MI:SS'));
    v_moneda := NVL(p_cod_moneda, 'GS');
    p_nro_secuencia := NVL(p_nro_secuencia, 0);
    -- 818: FLI capital; REPO capital + interés (misma regla que baja)
    v_monto_alta := fu_obt_monto_baja(
                      p_cod_modalidad,
                      p_monto,
                      p_mto_interes
                    );

    -- 815 SIPAP detallado (capital)
    pp_ins_movimiento(
      p_movimiento      => r_movimiento,
      p_fecha           => v_fecha,
      p_hora            => v_hora,
      p_secuencia       => p_nro_secuencia,
      p_cod_modalidad   => p_cod_modalidad,
      p_nro_cuenta      => p_nro_cuenta,
      p_cod_moneda      => v_moneda,
      p_cod_transaccion => C_TRA_SIPAP_ALTA,
      p_monto           => p_monto,
      p_concepto        => 'LIQUIDACION SIPAP ALTA',
      p_cod_rubro       => C_RUBRO_SIPAP,
      p_tip_mov_rubro   => 'D',
      p_cod_mad_padre   => p_cod_modalidad
    );
    IF g_cod_error <> 0 THEN
      RETURN;
    END IF;

    -- 818 ALTA ACUERDO DEAL (capital; +interés en REPO)
    pp_ins_movimiento(
      p_movimiento      => r_movimiento,
      p_fecha           => v_fecha,
      p_hora            => v_hora,
      p_secuencia       => p_nro_secuencia,
      p_cod_modalidad   => p_cod_modalidad,
      p_nro_cuenta      => p_nro_cuenta,
      p_cod_moneda      => v_moneda,
      p_cod_transaccion => C_TRA_ALTA_ACU,
      p_monto           => v_monto_alta,
      p_concepto        => 'ALTA ACUERDO DEAL',
      p_cod_mad_padre   => p_cod_modalidad
    );
    IF g_cod_error <> 0 THEN
      RETURN;
    END IF;

    -- 819 solo REPO O/N / Tripartito con interes > 0 (FLI nunca)
    IF p_cod_modalidad IN (C_COD_MOD_REPO_ON, C_COD_MOD_TPREPO)
       AND NVL(p_mto_interes, 0) > 0 THEN
      pp_ins_movimiento(
        p_movimiento      => r_movimiento,
        p_fecha           => v_fecha,
        p_hora            => v_hora,
        p_secuencia       => p_nro_secuencia,
        p_cod_modalidad   => p_cod_modalidad,
        p_nro_cuenta      => p_nro_cuenta,
        p_cod_moneda      => v_moneda,
        p_cod_transaccion => C_TRA_ALTA_COSTO,
        p_monto           => p_mto_interes,
        p_concepto        => 'ALTA INTERES',
        p_cod_mad_padre   => p_cod_modalidad
      );
    END IF;

  END pr_ins_mov_alta_producto;

  -- Inserta movs de baja producto: 816+820; en REPO tambien 822 (interes a resultado)
  PROCEDURE pr_ins_mov_baja_producto (
    p_nro_cuenta       IN VARCHAR2,
    p_cod_modalidad    IN NUMBER,
    p_monto            IN NUMBER,
    p_mto_interes      IN NUMBER DEFAULT 0,
    p_cod_moneda       IN VARCHAR2 DEFAULT 'GS',
    p_fecha_movimiento IN DATE DEFAULT NULL,
    p_hora_movimiento  IN ge_movimientos.hora%TYPE DEFAULT NULL,
    p_nro_secuencia    IN OUT NUMBER
  ) IS
    r_movimiento ge_movimientos%ROWTYPE;
    v_fecha      DATE;
    v_hora       ge_movimientos.hora%TYPE;
    v_moneda     VARCHAR2(3);
    v_monto_baja NUMBER;
  BEGIN
    lf_limpiar_error;

    IF p_nro_cuenta IS NULL OR p_cod_modalidad IS NULL THEN
      lf_set_error(C_ERR_PARAM_CAT, 'PR_INS_MOV_BAJA_PRODUCTO: cuenta/modalidad nulos');
      RETURN;
    END IF;

    v_fecha := NVL(p_fecha_movimiento, pag_cal.fu_obt_fec_actual(C_COD_MODULO));
    v_hora := NVL(p_hora_movimiento, TO_CHAR(SYSDATE, 'HH24:MI:SS'));
    v_moneda := NVL(p_cod_moneda, 'GS');
    p_nro_secuencia := NVL(p_nro_secuencia, 0);
    v_monto_baja := fu_obt_monto_baja(
                      p_cod_modalidad,
                      p_monto,
                      p_mto_interes
                    );

    -- 816 SIPAP detallado: 138 capital; 139/140 capital + interés
    pp_ins_movimiento(
      p_movimiento      => r_movimiento,
      p_fecha           => v_fecha,
      p_hora            => v_hora,
      p_secuencia       => p_nro_secuencia,
      p_cod_modalidad   => p_cod_modalidad,
      p_nro_cuenta      => p_nro_cuenta,
      p_cod_moneda      => v_moneda,
      p_cod_transaccion => C_TRA_SIPAP_BAJA,
      p_monto           => v_monto_baja,
      p_concepto        => 'LIQUIDACION SIPAP BAJA',
      p_cod_rubro       => C_RUBRO_SIPAP,
      p_tip_mov_rubro   => 'C',
      p_cod_mad_padre   => p_cod_modalidad
    );
    IF g_cod_error <> 0 THEN
      RETURN;
    END IF;

    -- 820 BAJA ACUERDO DEAL
    pp_ins_movimiento(
      p_movimiento      => r_movimiento,
      p_fecha           => v_fecha,
      p_hora            => v_hora,
      p_secuencia       => p_nro_secuencia,
      p_cod_modalidad   => p_cod_modalidad,
      p_nro_cuenta      => p_nro_cuenta,
      p_cod_moneda      => v_moneda,
      p_cod_transaccion => C_TRA_BAJA_ACU,
      p_monto           => v_monto_baja,
      p_concepto        => 'BAJA ACUERDO DEAL',
      p_cod_mad_padre   => p_cod_modalidad
    );
    IF g_cod_error <> 0 THEN
      RETURN;
    END IF;

    -- 822 solo REPO O/N / Tripartito con interés > 0 (FLI nunca)
    IF p_cod_modalidad IN (C_COD_MOD_REPO_ON, C_COD_MOD_TPREPO)
       AND NVL(p_mto_interes, 0) > 0 THEN
      pp_ins_movimiento(
        p_movimiento      => r_movimiento,
        p_fecha           => v_fecha,
        p_hora            => v_hora,
        p_secuencia       => p_nro_secuencia,
        p_cod_modalidad   => p_cod_modalidad,
        p_nro_cuenta      => p_nro_cuenta,
        p_cod_moneda      => v_moneda,
        p_cod_transaccion => C_TRA_COSTO_RES,
        p_monto           => p_mto_interes,
        p_concepto        => 'BAJA INTERES',
        p_cod_mad_padre   => p_cod_modalidad
      );
    END IF;

  END pr_ins_mov_baja_producto;

  -- Inserta un mov de garantia por titulo: 823 cesion (alta) o 824 liberacion (baja)
  PROCEDURE pr_ins_mov_garantia (
    p_nro_cuenta       IN VARCHAR2,
    p_cod_modalidad    IN NUMBER,
    p_monto            IN NUMBER,
    p_cod_moneda       IN VARCHAR2 DEFAULT 'GS',
    p_cod_modalidad_pd IN NUMBER,
    p_es_alta          IN VARCHAR2,
    p_fecha_movimiento IN DATE DEFAULT NULL,
    p_hora_movimiento  IN ge_movimientos.hora%TYPE DEFAULT NULL,
    p_nro_secuencia    IN OUT NUMBER
  ) IS
    r_movimiento      ge_movimientos%ROWTYPE;
    v_fecha           DATE;
    v_hora            ge_movimientos.hora%TYPE;
    v_cod_transaccion NUMBER;
    v_concepto        VARCHAR2(100);
    v_moneda          VARCHAR2(3);
  BEGIN
    lf_limpiar_error;

    IF p_nro_cuenta IS NULL
       OR p_cod_modalidad IS NULL
       OR p_cod_modalidad_pd IS NULL
       OR NVL(p_monto, 0) <= 0 THEN
      lf_set_error(
        C_ERR_PARAM_CAT,
        'PR_INS_MOV_GARANTIA: cuenta/modalidad/monto invalidos'
          || ' | cta=' || p_nro_cuenta
      );
      RETURN;
    END IF;

    IF p_es_alta = 'S' THEN
      v_cod_transaccion := C_TRA_CES_GAR;
      v_concepto        := 'ALTA GARANTIA';
    ELSIF p_es_alta = 'N' THEN
      v_cod_transaccion := C_TRA_LIB_GAR;
      v_concepto        := 'BAJA GARANTIA';
    ELSE
      lf_set_error(
        C_ERR_PARAM_CAT,
        'PR_INS_MOV_GARANTIA: p_es_alta debe ser S o N | valor=' || p_es_alta
      );
      RETURN;
    END IF;

    v_fecha  := NVL(p_fecha_movimiento, pag_cal.fu_obt_fec_actual(C_COD_MODULO));
    v_hora   := NVL(p_hora_movimiento, TO_CHAR(SYSDATE, 'HH24:MI:SS'));
    v_moneda := NVL(p_cod_moneda, 'GS');
    p_nro_secuencia := NVL(p_nro_secuencia, 0);

    pp_ins_movimiento(
      p_movimiento      => r_movimiento,
      p_fecha           => v_fecha,
      p_hora            => v_hora,
      p_secuencia       => p_nro_secuencia,
      p_cod_modalidad   => p_cod_modalidad,
      p_nro_cuenta      => p_nro_cuenta,
      p_cod_moneda      => v_moneda,
      p_cod_transaccion => v_cod_transaccion,
      p_monto           => p_monto,
      p_concepto        => v_concepto,
      p_cod_mad_padre   => p_cod_modalidad_pd
    );
  END pr_ins_mov_garantia;

  -- Orquestacion: resuelve titulos de sb_snp_fli y llama la API por cada uno.
  PROCEDURE pp_pro_garantias_ref (
    p_ref_543          IN VARCHAR2,
    p_cod_modalidad_pd IN NUMBER,
    p_es_alta          IN VARCHAR2,
    p_fecha_movimiento IN DATE,
    p_hora_movimiento  IN ge_movimientos.hora%TYPE,
    p_nro_secuencia    IN OUT NUMBER
  ) IS
    v_ins NUMBER := 0;
  BEGIN
    IF p_ref_543 IS NULL OR p_cod_modalidad_pd IS NULL THEN
      RETURN;
    END IF;

    FOR r_garantia IN (
      SELECT f.nro_cuenta,
             f.monto,
             d.cod_modalidad,
             d.cod_moneda
        FROM sb_snp_fli f
        JOIN md_cta_documentos d
          ON d.cod_modulo = C_COD_MODULO
         AND d.nro_cuenta = f.nro_cuenta
       WHERE f.nro_ref_externa = p_ref_543
         -- Alta 823: no liquidados (L). Baja 824: no vendidos (N); L sí (p.ej. tras MT548).
         AND (
               (p_es_alta = 'S' AND NVL(f.situacion, ' ') <> 'L')
            OR (p_es_alta = 'N' AND NVL(f.situacion, ' ') <> 'N')
             )
         AND NVL(f.monto, 0) > 0
         AND d.cod_modalidad IN (101, 105, 106, 123, 125, 129)
    ) LOOP
      pr_ins_mov_garantia(
        p_nro_cuenta       => TO_CHAR(r_garantia.nro_cuenta),
        p_cod_modalidad    => r_garantia.cod_modalidad,
        p_monto            => r_garantia.monto,
        p_cod_moneda       => NVL(r_garantia.cod_moneda, 'GS'),
        p_cod_modalidad_pd => p_cod_modalidad_pd,
        p_es_alta          => p_es_alta,
        p_fecha_movimiento => p_fecha_movimiento,
        p_hora_movimiento  => p_hora_movimiento,
        p_nro_secuencia    => p_nro_secuencia
      );
      IF g_cod_error <> 0 THEN
        RETURN;
      END IF;
      v_ins := v_ins + 1;
    END LOOP;

    -- Alta 506 / baja 545: debe haber al menos un titulo elegible en sb_snp_fli.
    IF v_ins = 0 THEN
      lf_set_error(
        C_ERR_PARAM_CAT,
        'PP_PRO_GARANTIAS_REF: sin titulos para '
          || CASE WHEN p_es_alta = 'S' THEN 'alta' ELSE 'baja' END
          || ' | ref_543=' || p_ref_543
      );
      RETURN;
    END IF;
  END pp_pro_garantias_ref;

  -- Obtiene cuenta producto (nro, montos, moneda) por ref_543 + modalidad + estado
  PROCEDURE pr_obt_cta_producto (
    p_ref_543           IN VARCHAR2,
    p_cod_modalidad     IN NUMBER,
    p_estado            IN VARCHAR2,
    p_nro_cuenta        OUT md_cta_documentos.nro_cuenta%TYPE,
    p_monto             OUT md_cta_documentos.monto%TYPE,
    p_mto_interes       OUT md_cta_documentos.mto_interes%TYPE,
    p_cod_moneda        OUT md_cta_documentos.cod_moneda%TYPE
  ) IS
  BEGIN
    p_nro_cuenta  := NULL;
    p_monto       := NULL;
    p_mto_interes := NULL;
    p_cod_moneda  := NULL;

    SELECT d.nro_cuenta,
           d.monto,
           d.mto_interes,
           d.cod_moneda
      INTO p_nro_cuenta,
           p_monto,
           p_mto_interes,
           p_cod_moneda
      FROM md_cta_documentos d
     WHERE d.cod_modulo = C_COD_MODULO
       AND d.cod_modalidad = p_cod_modalidad
       AND d.nro_documento = p_ref_543
       AND d.estado = p_estado;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      lf_set_error(
        C_ERR_PARAM_CAT,
        'PR_OBT_CTA_PRODUCTO: cuenta no encontrada'
          || ' | ref_543=' || p_ref_543
          || ' | mod=' || p_cod_modalidad
          || ' | estado=' || p_estado
      );
    WHEN TOO_MANY_ROWS THEN
      lf_set_error(
        C_ERR_PARAM_CAT,
        'PR_OBT_CTA_PRODUCTO: multiples cuentas'
          || ' | ref_543=' || p_ref_543
          || ' | mod=' || p_cod_modalidad
          || ' | estado=' || p_estado
      );
  END pr_obt_cta_producto;

  -- Orquesta contabilizacion post-operativa segun MT: 506 alta, 545 baja, 546 conversion
  PROCEDURE pr_pro_con_msj_recibido (
    p_cod_msj_swift  IN VARCHAR2,
    p_nro_referencia IN VARCHAR2,
    p_ref_543        IN VARCHAR2 DEFAULT NULL,
    p_fecha          IN DATE DEFAULT NULL,
    p_hora           IN ge_movimientos.hora%TYPE DEFAULT NULL,
    p_nro_secuencia  IN OUT NUMBER,
    p_nro_cuenta     IN VARCHAR2 DEFAULT NULL,
    p_cod_modalidad  IN NUMBER DEFAULT NULL
  ) IS
    v_fecha          DATE := NVL(p_fecha, pag_cal.fu_obt_fec_actual(C_COD_MODULO));
    v_hora           ge_movimientos.hora%TYPE := NVL(p_hora, TO_CHAR(SYSDATE, 'HH24:MI:SS'));
    v_secuencia      NUMBER := NVL(p_nro_secuencia, 0);
    v_nro_cta_138    md_cta_documentos.nro_cuenta%TYPE;
    v_nro_cta_139    md_cta_documentos.nro_cuenta%TYPE;
    v_nro_cta_prod   md_cta_documentos.nro_cuenta%TYPE;
    v_cod_modalidad  md_cta_documentos.cod_modalidad%TYPE;
    v_monto          md_cta_documentos.monto%TYPE;
    v_mto_interes    md_cta_documentos.mto_interes%TYPE;
    v_cod_moneda     md_cta_documentos.cod_moneda%TYPE;
  BEGIN
    IF p_cod_msj_swift IS NULL OR p_ref_543 IS NULL THEN
      lf_set_error(
        C_ERR_PARAM_CAT,
        'PR_PRO_CON_MSJ_RECIBIDO: mensaje/ref_543 nulos'
      );
      RETURN;
    END IF;

    CASE p_cod_msj_swift
      WHEN '506' THEN
        -- La operativa dejó la cuenta producto vigente en estado E.
        SELECT d.cod_modalidad
          INTO v_cod_modalidad
          FROM md_cta_documentos d
         WHERE d.cod_modulo = C_COD_MODULO
           AND d.nro_documento = p_ref_543
           AND d.cod_modalidad IN (C_COD_MOD_FLI, C_COD_MOD_TPREPO)
           AND d.estado = 'E';

        pr_obt_cta_producto(
          p_ref_543       => p_ref_543,
          p_cod_modalidad => v_cod_modalidad,
          p_estado        => 'E',
          p_nro_cuenta    => v_nro_cta_prod,
          p_monto         => v_monto,
          p_mto_interes   => v_mto_interes,
          p_cod_moneda    => v_cod_moneda
        );
        IF g_cod_error <> 0 THEN
          RETURN;
        END IF;
        pr_ins_mov_alta_producto(
          p_nro_cuenta       => v_nro_cta_prod,
          p_cod_modalidad    => v_cod_modalidad,
          p_monto            => v_monto,
          p_mto_interes      => v_mto_interes,
          p_cod_moneda       => v_cod_moneda,
          p_fecha_movimiento => v_fecha,
          p_hora_movimiento  => v_hora,
          p_nro_secuencia    => v_secuencia
        );
        IF g_cod_error <> 0 THEN
          RETURN;
        END IF;
        pp_pro_garantias_ref(
          p_ref_543          => p_ref_543,
          p_cod_modalidad_pd => v_cod_modalidad,
          p_es_alta          => 'S',
          p_fecha_movimiento => v_fecha,
          p_hora_movimiento  => v_hora,
          p_nro_secuencia    => v_secuencia
        );

      WHEN '545' THEN
        -- Preferir cuenta/modalidad que cerro la operativa (API / post-conversion).
        IF p_cod_modalidad IS NULL THEN
          lf_set_error(
            C_ERR_PARAM_CAT,
            'PR_PRO_CON_MSJ_RECIBIDO: 545 requiere p_cod_modalidad'
              || ' | ref_543=' || p_ref_543
          );
          RETURN;
        END IF;
        v_cod_modalidad := p_cod_modalidad;

        pr_obt_cta_producto(
          p_ref_543       => p_ref_543,
          p_cod_modalidad => v_cod_modalidad,
          p_estado        => 'N',
          p_nro_cuenta    => v_nro_cta_prod,
          p_monto         => v_monto,
          p_mto_interes   => v_mto_interes,
          p_cod_moneda    => v_cod_moneda
        );
        IF g_cod_error <> 0 THEN
          RETURN;
        END IF;
        IF p_nro_cuenta IS NOT NULL AND p_nro_cuenta <> v_nro_cta_prod THEN
          lf_set_error(
            C_ERR_PARAM_CAT,
            'PR_PRO_CON_MSJ_RECIBIDO: 545 cuenta no coincide'
              || ' | ref_543=' || p_ref_543
              || ' | cta_param=' || p_nro_cuenta
              || ' | cta_doc=' || v_nro_cta_prod
          );
          RETURN;
        END IF;
        pr_ins_mov_baja_producto(
          p_nro_cuenta       => v_nro_cta_prod,
          p_cod_modalidad    => v_cod_modalidad,
          p_monto            => v_monto,
          p_mto_interes      => v_mto_interes,
          p_cod_moneda       => v_cod_moneda,
          p_fecha_movimiento => v_fecha,
          p_hora_movimiento  => v_hora,
          p_nro_secuencia    => v_secuencia
        );
        IF g_cod_error <> 0 THEN
          RETURN;
        END IF;
        pp_pro_garantias_ref(
          p_ref_543          => p_ref_543,
          p_cod_modalidad_pd => v_cod_modalidad,
          p_es_alta          => 'N',
          p_fecha_movimiento => v_fecha,
          p_hora_movimiento  => v_hora,
          p_nro_secuencia    => v_secuencia
        );

      WHEN '546' THEN
        -- Conversion: solo producto (baja 138 + alta 139). Sin 823/824: el colateral no se mueve.
        pr_obt_cta_producto(
          p_ref_543       => p_ref_543,
          p_cod_modalidad => C_COD_MOD_FLI,
          p_estado        => 'N',
          p_nro_cuenta    => v_nro_cta_138,
          p_monto         => v_monto,
          p_mto_interes   => v_mto_interes,
          p_cod_moneda    => v_cod_moneda
        );
        IF g_cod_error <> 0 THEN
          RETURN;
        END IF;
        pr_ins_mov_baja_producto(
          p_nro_cuenta       => v_nro_cta_138,
          p_cod_modalidad    => C_COD_MOD_FLI,
          p_monto            => v_monto,
          p_mto_interes      => v_mto_interes,
          p_cod_moneda       => v_cod_moneda,
          p_fecha_movimiento => v_fecha,
          p_hora_movimiento  => v_hora,
          p_nro_secuencia    => v_secuencia
        );
        IF g_cod_error <> 0 THEN
          RETURN;
        END IF;

        pr_obt_cta_producto(
          p_ref_543       => p_ref_543,
          p_cod_modalidad => C_COD_MOD_REPO_ON,
          p_estado        => 'E',
          p_nro_cuenta    => v_nro_cta_139,
          p_monto         => v_monto,
          p_mto_interes   => v_mto_interes,
          p_cod_moneda    => v_cod_moneda
        );
        IF g_cod_error <> 0 THEN
          RETURN;
        END IF;
        pr_ins_mov_alta_producto(
          p_nro_cuenta       => v_nro_cta_139,
          p_cod_modalidad    => C_COD_MOD_REPO_ON,
          p_monto            => v_monto,
          p_mto_interes      => v_mto_interes,
          p_cod_moneda       => v_cod_moneda,
          p_fecha_movimiento => v_fecha,
          p_hora_movimiento  => v_hora,
          p_nro_secuencia    => v_secuencia
        );

      ELSE
        lf_set_error(
          C_ERR_PARAM_CAT,
          'PR_PRO_CON_MSJ_RECIBIDO: MT no soportado | mt=' || p_cod_msj_swift
        );
    END CASE;

    p_nro_secuencia := v_secuencia;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      lf_set_error(
        C_ERR_PARAM_CAT,
        'PR_PRO_CON_MSJ_RECIBIDO: cuenta producto no encontrada'
          || ' | mt=' || p_cod_msj_swift
          || ' | ref_543=' || p_ref_543
      );
    WHEN TOO_MANY_ROWS THEN
      lf_set_error(
        C_ERR_PARAM_CAT,
        'PR_PRO_CON_MSJ_RECIBIDO: multiples cuentas producto'
          || ' | mt=' || p_cod_msj_swift
          || ' | ref_543=' || p_ref_543
      );
    WHEN OTHERS THEN
      IF g_cod_error = 0 THEN
        lf_set_error(
          C_ERR_PARAM_CAT,
          'PR_PRO_CON_MSJ_RECIBIDO: ' || SQLERRM
            || ' | mt=' || p_cod_msj_swift
            || ' | ref_543=' || p_ref_543
        );
      END IF;
  END pr_pro_con_msj_recibido;

END PAM_FRC;
/
